import { AuditAction } from '../../common/audit/audit.service.js';
import type { Prisma, PrismaClient, SpecialUsernameSource } from '../../generated/prisma/client.js';
import { uuidv7 } from '../levels/uuidv7.js';
import { lockName, lockUser } from '../premium-usernames/premium-username-ops.js';
import { isValidUsername } from './username.js';

/**
 * The special-username layer «يوزر مميز» (v1.54-social, D185, CONVENTIONS §10.48.1), shared by the API, the
 * `recharge-admin` / `username-admin` CLIs and the tests (no Nest dependencies).
 *
 * `user_profiles.username` always means the username shown now: while a special username is ACTIVE it is the
 * special one, and the person's own (base) username is kept in `special_usernames.base_username` — reserved for
 * them and never returned in public payloads. Ending it (expiry, revocation, a recharge agent's suspension) puts
 * the base username back and keeps the special one reserved for the person (GRACE) for the grace period, then
 * releases it; a `coin` + digits name is never released. Writes take the same name/user advisory locks as the
 * premium usernames (D146), so the two never race.
 */

type Tx = Prisma.TransactionClient;
type Db = Pick<
  Tx,
  '$queryRaw' | 'specialUsername' | 'userProfile' | 'pendingRegistration' | 'premiumUsernameLease'
>;

/** `coin` + digits (also with `.` / `_` inside): the recharge agents' names, reserved for the system. */
export function isCoinName(name: string): boolean {
  return /^coin[0-9]+$/.test(name.toLowerCase().replace(/[._]/g, ''));
}

/** Why a grant was refused (the CLI prints it; the API never grants from user input). */
export class SpecialUsernameError extends Error {
  constructor(
    readonly reason: 'INVALID' | 'TAKEN' | 'PREMIUM_ACTIVE' | 'NOT_ACTIVE',
    message: string,
  ) {
    super(message);
  }
}

export interface SpecialUsernameRow {
  id: string;
  userId: string;
  username: string;
  baseUsername: string;
  source: SpecialUsernameSource;
  status: 'ACTIVE' | 'GRACE' | 'ENDED';
  locked: boolean;
  grantedAt: Date;
  expiresAt: Date | null;
  graceUntil: Date | null;
}

/** The person's ACTIVE special username, if any. */
export function activeSpecialOf(
  db: Pick<Tx, 'specialUsername'>,
  userId: string,
): Promise<SpecialUsernameRow | null> {
  return db.specialUsername.findFirst({ where: { userId, status: 'ACTIVE' } });
}

/**
 * The user (other than `exceptUserId`) a special-username row holds `name` for: as an ACTIVE special or base
 * username, a special one in GRACE, or any `coin` name ever given.
 */
export async function specialHolderOf(
  db: Pick<Tx, 'specialUsername'>,
  name: string,
  exceptUserId: string | null = null,
): Promise<string | null> {
  const row = await db.specialUsername.findFirst({
    where: {
      ...(exceptUserId ? { userId: { not: exceptUserId } } : {}),
      OR: [
        { status: 'ACTIVE', baseUsername: name },
        { status: { in: ['ACTIVE', 'GRACE'] }, username: name },
        ...(isCoinName(name) ? [{ username: name }] : []),
      ],
    },
    select: { userId: true },
  });
  return row?.userId ?? null;
}

/**
 * The user a username leads to: the account whose shown username it is, else the person whose base username it
 * is (behind an ACTIVE special one) or whose special one it was (GRACE) — so old mentions and links still
 * resolve. Null when none.
 */
export async function resolveUserIdByUsername(
  db: Pick<Tx, 'userProfile' | 'specialUsername'>,
  name: string,
): Promise<string | null> {
  if (!isValidUsername(name)) return null;
  const profile = await db.userProfile.findUnique({ where: { username: name }, select: { userId: true } });
  if (profile) return profile.userId;
  const row = await db.specialUsername.findFirst({
    where: {
      OR: [
        { status: 'ACTIVE', baseUsername: name },
        { status: 'GRACE', username: name },
      ],
    },
    orderBy: { grantedAt: 'desc' },
    select: { userId: true },
  });
  return row?.userId ?? null;
}

async function nameTakenByOther(db: Db, name: string, userId: string, now: Date): Promise<boolean> {
  const [profiles, pending, leases] = await Promise.all([
    db.userProfile.count({ where: { username: name, userId: { not: userId } } }),
    db.pendingRegistration.count({ where: { username: name, expiresAt: { gt: now } } }),
    db.premiumUsernameLease.count({
      where: {
        userId: { not: userId },
        OR: [
          { username: name, status: { in: ['ACTIVE', 'GRACE'] } },
          { regularUsername: name, status: 'ACTIVE' },
        ],
      },
    }),
  ]);
  if (profiles + pending + leases > 0) return true;
  return (await specialHolderOf(db, name, userId)) !== null;
}

/**
 * Gives `userId` the special username `name` (ACTIVE, shown everywhere at once): the base username is the one
 * shown now (or, replacing another special one, that one's base). `expiresAt` null = permanent. A `coin` name
 * only for RECHARGE_AGENT. Refused while the person rents a premium username (D146) and when `name` is anyone
 * else's shown, base, special, pending, premium or held name. The person's own GRACE row for `name` comes back.
 */
export async function grantSpecialIn(
  tx: Tx,
  userId: string,
  name: string,
  opts: {
    source: SpecialUsernameSource;
    expiresAt: Date | null;
    reason: string | null;
    actorUserId?: string | null;
    via: 'cli' | 'system';
  },
  now: Date,
  graceDays: number,
): Promise<SpecialUsernameRow> {
  if (!isValidUsername(name) || name.length > 30)
    throw new SpecialUsernameError('INVALID', `${name} is not a username.`);
  if (isCoinName(name) && opts.source !== 'RECHARGE_AGENT') {
    throw new SpecialUsernameError('INVALID', 'coin + digits names are reserved for recharge agents.');
  }
  await lockUser(tx, userId);
  await lockName(tx, name);
  const lease = await tx.premiumUsernameLease.findFirst({
    where: { userId, status: 'ACTIVE' },
    select: { id: true },
  });
  if (lease) {
    throw new SpecialUsernameError('PREMIUM_ACTIVE', 'The user rents a premium username; end it first.');
  }
  const profile = await tx.userProfile.findUniqueOrThrow({ where: { userId }, select: { username: true } });
  const current = await activeSpecialOf(tx, userId);
  if (current?.username === name) {
    return tx.specialUsername.update({
      where: { id: current.id },
      data: { expiresAt: opts.expiresAt, source: opts.source, reason: opts.reason },
    });
  }
  const base = current ? current.baseUsername : profile.username;
  if (base === name) throw new SpecialUsernameError('INVALID', 'That is the user’s own username.');
  if (await nameTakenByOther(tx, name, userId, now)) {
    throw new SpecialUsernameError('TAKEN', `${name} is used or held by another account.`);
  }
  if (current) await endRowIn(tx, current, 'REPLACED', now, graceDays);
  const own = await tx.specialUsername.findFirst({
    where: { userId, username: name, status: { in: ['GRACE', 'ENDED'] } },
    orderBy: { grantedAt: 'desc' },
  });
  const row = own
    ? await tx.specialUsername.update({
        where: { id: own.id },
        data: {
          status: 'ACTIVE',
          baseUsername: base,
          source: opts.source,
          locked: true,
          grantedAt: now,
          expiresAt: opts.expiresAt,
          graceUntil: null,
          endedAt: null,
          endReason: null,
          reason: opts.reason,
        },
      })
    : await tx.specialUsername.create({
        data: {
          id: uuidv7(),
          userId,
          username: name,
          baseUsername: base,
          source: opts.source,
          locked: true,
          grantedAt: now,
          expiresAt: opts.expiresAt,
          reason: opts.reason,
        },
      });
  await tx.userProfile.update({ where: { userId }, data: { username: name, premiumTier: null } });
  await tx.auditLog.create({
    data: {
      actorUserId: opts.actorUserId ?? null,
      action: AuditAction.SPECIAL_USERNAME_GRANT,
      targetType: 'user',
      targetId: userId,
      metadata: {
        special: name,
        base,
        source: opts.source,
        expiresAt: opts.expiresAt?.toISOString() ?? null,
        reason: opts.reason,
        via: opts.via,
      },
    },
  });
  return row;
}

async function endRowIn(
  tx: Tx,
  row: SpecialUsernameRow,
  reason: string,
  now: Date,
  graceDays: number,
): Promise<void> {
  await tx.specialUsername.update({
    where: { id: row.id },
    data: {
      status: 'GRACE',
      endedAt: now,
      endReason: reason,
      // A `coin` name is never released (grace without an end).
      graceUntil: isCoinName(row.username) ? null : new Date(now.getTime() + graceDays * 86_400_000),
    },
  });
}

/**
 * Ends the person's ACTIVE special username: the base username is shown again at once and the special one stays
 * reserved for them (GRACE). False when there was none.
 */
export async function endSpecialIn(
  tx: Tx,
  userId: string,
  reason: 'EXPIRED' | 'REVOKED' | 'SUSPENDED',
  now: Date,
  graceDays: number,
  audit: { actorUserId?: string | null; via: 'cli' | 'system' | 'sweeper'; note?: string | null },
): Promise<boolean> {
  await lockUser(tx, userId);
  const row = await activeSpecialOf(tx, userId);
  if (!row) return false;
  await lockName(tx, row.baseUsername);
  await endRowIn(tx, row, reason, now, graceDays);
  await tx.userProfile.update({ where: { userId }, data: { username: row.baseUsername } });
  await tx.auditLog.create({
    data: {
      actorUserId: audit.actorUserId ?? null,
      action: AuditAction.SPECIAL_USERNAME_END,
      targetType: 'user',
      targetId: userId,
      metadata: {
        special: row.username,
        base: row.baseUsername,
        reason,
        via: audit.via,
        note: audit.note ?? null,
      },
    },
  });
  return true;
}

/**
 * Brings the person's latest special username of `source` back (an agent reinstated): ACTIVE again with the
 * shown username as the base. False when there is none in GRACE.
 */
export async function restoreSpecialIn(
  tx: Tx,
  userId: string,
  source: SpecialUsernameSource,
  now: Date,
  graceDays: number,
): Promise<boolean> {
  const row = await tx.specialUsername.findFirst({
    where: { userId, source, status: 'GRACE' },
    orderBy: { grantedAt: 'desc' },
  });
  if (!row) return false;
  await grantSpecialIn(
    tx,
    userId,
    row.username,
    { source, expiresAt: row.expiresAt, reason: row.reason, via: 'system' },
    now,
    graceDays,
  );
  return true;
}

/**
 * The sweeper's step: ACTIVE special usernames past `expires_at` end (the base username is shown again); GRACE
 * ones past `grace_until` are released (ENDED). Returns the rows changed.
 */
export async function sweepSpecialUsernames(
  prisma: PrismaClient,
  now: Date,
  graceDays: number,
): Promise<number> {
  const due = await prisma.specialUsername.findMany({
    where: { status: 'ACTIVE', expiresAt: { lte: now } },
    select: { userId: true },
    take: 200,
  });
  let changed = 0;
  for (const d of due) {
    const ok = await prisma.$transaction((tx) =>
      endSpecialIn(tx, d.userId, 'EXPIRED', now, graceDays, { via: 'sweeper' }),
    );
    if (ok) changed++;
  }
  const released = await prisma.specialUsername.updateMany({
    where: { status: 'GRACE', graceUntil: { lte: now } },
    data: { status: 'ENDED' },
  });
  return changed + released.count;
}
