import { auditBy, type AdminVia } from '../../common/audit/admin-actor.js';
import { AuditAction } from '../../common/audit/audit.service.js';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import type { Prisma } from '../../generated/prisma/client.js';

type Tx = Prisma.TransactionClient;
type Db = Pick<Tx, 'deviceBan'>;

/**
 * v1.60-live (D250, CONVENTIONS §10.91; owner 2026-11-02: «… أو حظر جهاز …»): a device banned by the team. The device is
 * D223's `DeviceInfo.deviceKey` as its HMAC (`device_signups.device_hash`, now also `sessions.device_hash`); the panel
 * never sees it — a ban is named by the account it was taken from. While a ban is active (not lifted; `ends_at` NULL =
 * permanent, or in the future) the device cannot sign up (`register`, `registerVerify`), sign in (`login`) or go live,
 * for ANY account; creating a ban ends every session of the device and drops their push tokens.
 *
 * Honest limits (KNOWN_LIMITATIONS): a factory reset (Android) or a reinstall after deleting the Keychain (iOS) gives a
 * new id; a rooted / jailbroken phone can send any key; the website and apps older than D223 send no key at all, so
 * nothing is checked for them. Shared by the panel, the enforcement points and the tests (no Nest dependencies).
 */

/** `sessions.revoked_reason` of the sessions a device ban ends. */
export const DEVICE_BAN_REVOKED_REASON = 'ADMIN_DEVICE_BANNED';

export interface DeviceBanView {
  readonly id: string;
  readonly reason: string;
  readonly endsAt: Date | null;
}

const activeWhere = (now: Date): Prisma.DeviceBanWhereInput => ({
  liftedAt: null,
  OR: [{ endsAt: null }, { endsAt: { gt: now } }],
});

/** The active ban of any of `hashes` (a permanent one first, else the one that ends last), or null. */
export async function activeDeviceBanOf(
  db: Db,
  hashes: readonly (string | null | undefined)[],
  now: Date = new Date(),
): Promise<DeviceBanView | null> {
  const list = [...new Set(hashes.filter((h): h is string => typeof h === 'string' && h.length > 0))];
  if (list.length === 0) return null;
  const rows = await db.deviceBan.findMany({
    where: { deviceHash: { in: list }, ...activeWhere(now) },
    select: { id: true, reason: true, endsAt: true },
  });
  if (rows.length === 0) return null;
  return rows.reduce((best, r) =>
    best.endsAt === null ? best : r.endsAt === null || r.endsAt > best.endsAt ? r : best,
  );
}

/** 403 DEVICE_BANNED `[{until: ISO | 'permanent'}, {reason}]`. */
export function deviceBannedError(ban: DeviceBanView): AppException {
  return new AppException(ErrorCode.DEVICE_BANNED, undefined, [
    { field: 'until', issue: ban.endsAt ? ban.endsAt.toISOString() : 'permanent' },
    { field: 'reason', issue: ban.reason },
  ]);
}

/** Throws {@link deviceBannedError} when the device (null: none sent) is banned now. */
export async function assertDeviceNotBanned(
  db: Db,
  deviceHash: string | null | undefined,
  now: Date = new Date(),
): Promise<void> {
  const ban = await activeDeviceBanOf(db, [deviceHash], now);
  if (ban) throw deviceBannedError(ban);
}

/**
 * The devices seen for `userId`: its sign-up device (D223) and the devices its sessions signed in with (this branch
 * on), newest session first; at most `max`.
 */
export async function devicesOfUserIn(tx: Tx, userId: string, max = 20): Promise<string[]> {
  const rows = await tx.$queryRaw<{ device_hash: string }[]>`
    SELECT device_hash FROM (
      SELECT device_hash, created_at FROM device_signups WHERE user_id = ${userId}::uuid
      UNION ALL
      SELECT device_hash, created_at FROM sessions WHERE user_id = ${userId}::uuid AND device_hash IS NOT NULL
    ) d
    GROUP BY device_hash
    ORDER BY max(created_at) DESC
    LIMIT ${max}`;
  return rows.map((r) => r.device_hash.trim());
}

export interface BanDevicesInput {
  readonly hashes: readonly string[];
  readonly reason: string;
  /** NULL: permanent. */
  readonly endsAt: Date | null;
  readonly sourceUserId: string;
  readonly liveModerationId?: string | null;
  readonly by: AdminVia;
  readonly now: Date;
}

/**
 * Bans `hashes` inside the caller's transaction: an open ban of the same device is replaced (lifted «replaced»), every
 * session of those devices ends (any account) with its push token, and one audit row records it. Returns the bans
 * created and the sessions ended.
 */
export async function banDevicesIn(
  tx: Tx,
  input: BanDevicesInput,
): Promise<{ banIds: string[]; sessionsEnded: number }> {
  const hashes = [...new Set(input.hashes)];
  if (hashes.length === 0) return { banIds: [], sessionsEnded: 0 };
  for (const hash of hashes) {
    await tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtext('kabso:device-ban'), hashtext(${hash}::text))`;
  }
  await tx.deviceBan.updateMany({
    where: { deviceHash: { in: hashes }, liftedAt: null },
    data: { liftedAt: input.now, liftedById: input.by.actorUserId, liftReason: 'replaced' },
  });
  const banIds: string[] = [];
  for (const hash of hashes) {
    const row = await tx.deviceBan.create({
      data: {
        deviceHash: hash,
        reason: input.reason,
        sourceUserId: input.sourceUserId,
        liveModerationId: input.liveModerationId ?? null,
        createdById: input.by.actorUserId,
        createdAt: input.now,
        endsAt: input.endsAt,
      },
      select: { id: true },
    });
    banIds.push(row.id);
  }
  const sessions = await tx.session.findMany({
    where: { deviceHash: { in: hashes }, revokedAt: null },
    select: { id: true },
  });
  const ids = sessions.map((s) => s.id);
  if (ids.length > 0) {
    await tx.session.updateMany({
      where: { id: { in: ids }, revokedAt: null },
      data: { revokedAt: input.now, revokedReason: DEVICE_BAN_REVOKED_REASON },
    });
    await tx.deviceToken.deleteMany({ where: { sessionId: { in: ids } } });
  }
  await tx.auditLog.create({
    data: {
      ...auditBy(input.by),
      action: AuditAction.DEVICE_BAN_CREATE,
      targetType: 'user',
      targetId: input.sourceUserId,
      metadata: {
        reason: input.reason,
        endsAt: input.endsAt ? input.endsAt.toISOString() : null,
        banIds,
        devices: hashes.length,
        sessionsEnded: ids.length,
        ...(input.liveModerationId ? { liveModerationId: input.liveModerationId } : {}),
        via: input.by.via,
      },
    },
  });
  return { banIds, sessionsEnded: ids.length };
}

/** Why lifting was refused (the panel answers 409 ADMIN_ACTION_REFUSED with the message). */
export class DeviceBanError extends Error {}

/** Lifts an active ban early, inside the caller's transaction (audited). */
export async function liftDeviceBanIn(
  tx: Tx,
  id: string,
  reason: string,
  by: AdminVia,
  now: Date,
): Promise<void> {
  const [row] = await tx.$queryRaw<
    { id: string; ends_at: Date | null; lifted_at: Date | null; source_user_id: string | null }[]
  >`SELECT id::text AS id, ends_at, lifted_at, source_user_id::text AS source_user_id
      FROM device_bans WHERE id = ${id}::uuid FOR UPDATE`;
  if (!row) throw new AppException(ErrorCode.NOT_FOUND);
  if (row.lifted_at !== null || (row.ends_at !== null && row.ends_at <= now)) {
    throw new DeviceBanError('This device ban is no longer active.');
  }
  await tx.deviceBan.update({
    where: { id },
    data: { liftedAt: now, liftedById: by.actorUserId, liftReason: reason },
  });
  await tx.auditLog.create({
    data: {
      ...auditBy(by),
      action: AuditAction.DEVICE_BAN_LIFT,
      targetType: 'device_ban',
      targetId: id,
      metadata: {
        reason,
        sourceUserId: row.source_user_id,
        before: { endsAt: row.ends_at ? row.ends_at.toISOString() : null },
        after: { liftedAt: now.toISOString() },
        via: by.via,
      },
    },
  });
}
