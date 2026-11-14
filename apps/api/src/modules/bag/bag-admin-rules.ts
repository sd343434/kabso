import { auditBy, CLI_VIA, type AdminVia } from '../../common/audit/admin-actor.js';
import { AuditAction } from '../../common/audit/audit.service.js';
import type { Prisma } from '../../generated/prisma/client.js';
import {
  addItemTimeIn,
  catalogueItemIn,
  lockItemHoldersIn,
  revokeItemIn,
  type AddItemOutcome,
} from './bag-grants.js';
import { BAG_DAY_MS, BAG_MAX_DAYS, HOST_FRAME_CODES } from './bag.catalogue.js';

type Tx = Prisma.TransactionClient;

/** A refused bag change (the CLI prints it and exits 1; the panel answers 409). Nothing changed. */
export class BagAdminError extends Error {}

/**
 * `bag-admin grant|revoke` (CP-019, D107, D171), shared with the admin panel (v1.65-social, D197, CONVENTIONS
 * §10.60.4): frames (`AVATAR_FRAME`) and profile cards (`PROFILE_CARD`). The active-host frames (D186) are refused:
 * they follow the host's activity. Audited in the caller's transaction (`bag.grant` / `bag.revoke`).
 */
function refuseHostFrame(code: string): void {
  if (Object.values<string>(HOST_FRAME_CODES).includes(code)) {
    throw new BagAdminError(
      `${code} follows the host's activity (D186); it is given and taken by the agency evaluation.`,
    );
  }
}

/** Grants `code` for `days` (1–3650) or for ever (null). `permanent` = they own it for ever already (no change). */
export async function grantBagItemByAdminIn(
  tx: Tx,
  userId: string,
  code: string,
  days: number | null,
  by: AdminVia = CLI_VIA,
  reason: string | null = null,
  now: Date = new Date(),
): Promise<AddItemOutcome> {
  refuseHostFrame(code);
  if (days !== null && (!Number.isInteger(days) || days < 1 || days > BAG_MAX_DAYS)) {
    throw new BagAdminError(`Days must be 1–${BAG_MAX_DAYS} or for ever.`);
  }
  const item = await catalogueItemIn(tx, code);
  if (!item) throw new BagAdminError(`No bag item ${code}.`);
  await lockItemHoldersIn(tx, item.code, [userId]);
  const result = await addItemTimeIn(tx, {
    userId,
    item,
    source: 'ADMIN',
    giftedById: null,
    durationMs: days === null ? null : days * BAG_DAY_MS,
    now,
  });
  if (result.kind !== 'permanent') {
    await tx.auditLog.create({
      data: {
        ...auditBy(by),
        action: AuditAction.BAG_GRANT,
        targetType: 'user',
        targetId: userId,
        metadata:
          days === null && result.kind === 'added'
            ? { item: item.code, category: item.category, ...(reason ? { reason } : {}), via: by.via }
            : {
                item: item.code,
                category: item.category,
                via: by.via,
                days,
                extended: result.kind === 'extended',
                ...(reason ? { reason } : {}),
              },
      },
    });
  }
  return result;
}

/** Takes `code` back; refused when the user does not own it. Returns whether it was worn. */
export async function revokeBagItemByAdminIn(
  tx: Tx,
  userId: string,
  code: string,
  by: AdminVia = CLI_VIA,
  reason: string | null = null,
): Promise<{ wasEquipped: boolean }> {
  refuseHostFrame(code);
  const result = await revokeItemIn(tx, userId, code);
  if (!result.owned) throw new BagAdminError(`The user does not own ${code}; nothing changed.`);
  await tx.auditLog.create({
    data: {
      ...auditBy(by),
      action: AuditAction.BAG_REVOKE,
      targetType: 'user',
      targetId: userId,
      metadata: { item: code, wasEquipped: result.wasEquipped, ...(reason ? { reason } : {}), via: by.via },
    },
  });
  return { wasEquipped: result.wasEquipped };
}
