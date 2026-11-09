import { auditBy, CLI_VIA, type AdminVia } from '../../common/audit/admin-actor.js';
import { AuditAction } from '../../common/audit/audit.service.js';
import type { Gift, Prisma } from '../../generated/prisma/client.js';
import {
  addGiftIn,
  giftInUse,
  giftUsageIn,
  setGiftEnabledIn,
  updateGiftIn,
  type GiftFields,
  type GiftUsage,
} from './gift-catalogue.js';
import { badgeSettingsOf, badgeText } from './item-badges.js';

type Tx = Prisma.TransactionClient;

/**
 * The gift catalogue's audited changes, shared by `gift-admin add|update|enable|disable` and the admin panel
 * (v1.65-social, D197, CONVENTIONS §10.60.4): the catalogue rules of gift-catalogue.ts plus the audit row, written
 * in the caller's transaction with `via` and the actor. A field problem throws `GiftFieldsError` (nothing changes).
 */

/** A gift's fields for an audit row; v1.79-live (D289): the badges as text (`CODE@end`, priority order). */
export function giftAuditFields(fields: Partial<GiftFields>): Prisma.InputJsonObject {
  const { badges, ...plain } = fields;
  return { ...plain, ...(badges !== undefined ? { badges: badgeText(badges) } : {}) };
}

/** Adds a gift; false when the code exists (nothing changes, no audit row). */
export async function addGiftByAdminIn(
  tx: Tx,
  code: string,
  fields: GiftFields,
  by: AdminVia = CLI_VIA,
  reason: string | null = null,
  now = new Date(),
): Promise<boolean> {
  const created = await addGiftIn(tx, code, fields, now);
  if (created) {
    await tx.auditLog.create({
      data: {
        ...auditBy(by),
        action: AuditAction.GIFT_ADD,
        targetType: 'gift',
        targetId: code,
        metadata: { ...giftAuditFields(fields), ...(reason ? { reason } : {}), via: by.via },
      },
    });
  }
  return created;
}

/** Changes some fields; the changed keys (empty = nothing changed), or null when there is no such gift. */
export async function updateGiftByAdminIn(
  tx: Tx,
  code: string,
  fields: Partial<GiftFields>,
  by: AdminVia = CLI_VIA,
  reason: string | null = null,
  now = new Date(),
): Promise<string[] | null> {
  const result = await updateGiftIn(tx, code, fields, now);
  if (!result) return null;
  const changes: Record<string, { from: string | number | null; to: string | number | null }> = {};
  for (const key of Object.keys(fields) as (keyof GiftFields)[]) {
    if (key === 'badges') continue;
    if (result.before[key] !== result.after[key]) {
      changes[key] = { from: result.before[key], to: result.after[key] };
    }
  }
  // v1.79-live (D289): the set compared as text; the legacy `badge` flag may change it too.
  if (fields.badges !== undefined || fields.badge !== undefined) {
    const from = badgeText(badgeSettingsOf(result.before));
    const to = badgeText(badgeSettingsOf(result.after));
    if (from !== to) changes.badges = { from, to };
    if (result.before.badge !== result.after.badge) {
      changes.badge = { from: result.before.badge, to: result.after.badge };
    }
  }
  if (Object.keys(changes).length > 0) {
    await tx.auditLog.create({
      data: {
        ...auditBy(by),
        action: AuditAction.GIFT_UPDATE,
        targetType: 'gift',
        targetId: code,
        metadata: { changes, ...(reason ? { reason } : {}), via: by.via },
      },
    });
  }
  return Object.keys(changes);
}

/** Enables or disables; whether it changed, or null when there is no such gift. */
export async function setGiftEnabledByAdminIn(
  tx: Tx,
  code: string,
  enabled: boolean,
  by: AdminVia = CLI_VIA,
  reason: string | null = null,
): Promise<boolean | null> {
  const result = await setGiftEnabledIn(tx, code, enabled);
  if (result) {
    await tx.auditLog.create({
      data: {
        ...auditBy(by),
        action: enabled ? AuditAction.GIFT_ENABLE : AuditAction.GIFT_DISABLE,
        targetType: 'gift',
        targetId: code,
        metadata: {
          before: enabled ? 'disabled' : 'enabled',
          after: enabled ? 'enabled' : 'disabled',
          ...(reason ? { reason } : {}),
          via: by.via,
        },
      },
    });
  }
  return result;
}

/** v1.102-social (D338): what «حذف» did — DELETED (the row is gone) or ARCHIVED (kept for history, off and hidden). */
export interface GiftRemoval {
  readonly result: 'DELETED' | 'ARCHIVED';
  /** The gift before (its uploaded files are removed after the commit when DELETED). */
  readonly before: Gift;
  readonly usage: GiftUsage;
  /** ARCHIVED only: false when it was archived already (nothing written). */
  readonly changed: boolean;
}

/**
 * v1.102-social (D338, CONVENTIONS §10.131) «حذف», shared by the panel and `gift-admin delete`: the gift row is locked,
 * then — nothing ever used it ({@link giftUsageIn} all 0) — DELETED for real (audit `gift.delete` with the gift before);
 * otherwise ARCHIVED: `archived_at` set and `enabled` false (audit `gift.archive` with the usage and whether it was on),
 * so it leaves the catalogue, the bag's send choices, the panel's normal list and the pickers while every row that
 * points at it keeps working as history. Archived already: ARCHIVED, nothing written. Null when there is no such gift.
 * Deleting the uploaded files is the caller's step after the commit (only when DELETED).
 */
export async function removeGiftByAdminIn(
  tx: Tx,
  code: string,
  by: AdminVia = CLI_VIA,
  reason: string | null = null,
  now = new Date(),
): Promise<GiftRemoval | null> {
  const locked = await tx.$queryRaw<
    { code: string }[]
  >`SELECT code FROM gifts WHERE code = ${code} FOR UPDATE`;
  if (locked.length === 0) return null;
  const before = await tx.gift.findUniqueOrThrow({ where: { code } });
  const usage = await giftUsageIn(tx, code);
  const meta = { usage: { ...usage }, ...(reason ? { reason } : {}), via: by.via };
  if (!giftInUse(usage)) {
    await tx.gift.delete({ where: { code } });
    await tx.auditLog.create({
      data: {
        ...auditBy(by),
        action: AuditAction.GIFT_DELETE,
        targetType: 'gift',
        targetId: code,
        metadata: {
          ...meta,
          case: 'deleted',
          before: {
            ...giftAuditFields({
              category: before.category,
              nameAr: before.nameAr,
              nameEn: before.nameEn,
              priceCoins: before.priceCoins,
              assetKey: before.assetKey,
              animationKey: before.animationKey,
            }),
            enabled: before.enabled,
            imageObjectKey: before.imageObjectKey,
            animationObjectKey: before.animationObjectKey,
            audioObjectKey: before.audioObjectKey,
            ownerUserId: before.ownerUserId,
            eventId: before.eventId,
          },
        },
      },
    });
    return { result: 'DELETED', before, usage, changed: true };
  }
  if (before.archivedAt !== null) return { result: 'ARCHIVED', before, usage, changed: false };
  await tx.gift.update({ where: { code }, data: { archivedAt: now, enabled: false } });
  await tx.auditLog.create({
    data: {
      ...auditBy(by),
      action: AuditAction.GIFT_ARCHIVE,
      targetType: 'gift',
      targetId: code,
      metadata: { ...meta, case: 'archived', wasEnabled: before.enabled },
    },
  });
  return { result: 'ARCHIVED', before, usage, changed: true };
}

/**
 * v1.102-social (D338) «استعادة»: an archived gift back in the panel's list and the catalogue — `archived_at` cleared and
 * the gift switched on (audit `gift.restore`). Not archived: false, nothing written. Null when there is no such gift.
 */
export async function restoreGiftByAdminIn(
  tx: Tx,
  code: string,
  by: AdminVia = CLI_VIA,
  reason: string | null = null,
): Promise<boolean | null> {
  const locked = await tx.$queryRaw<{ archived: boolean }[]>`
    SELECT archived_at IS NOT NULL AS archived FROM gifts WHERE code = ${code} FOR UPDATE`;
  if (locked.length === 0) return null;
  if (!locked[0]!.archived) return false;
  await tx.gift.update({ where: { code }, data: { archivedAt: null, enabled: true } });
  await tx.auditLog.create({
    data: {
      ...auditBy(by),
      action: AuditAction.GIFT_RESTORE,
      targetType: 'gift',
      targetId: code,
      metadata: { ...(reason ? { reason } : {}), via: by.via },
    },
  });
  return true;
}
