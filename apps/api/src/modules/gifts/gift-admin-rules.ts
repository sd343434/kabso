import { auditBy, CLI_VIA, type AdminVia } from '../../common/audit/admin-actor.js';
import { AuditAction } from '../../common/audit/audit.service.js';
import type { Prisma } from '../../generated/prisma/client.js';
import { addGiftIn, setGiftEnabledIn, updateGiftIn, type GiftFields } from './gift-catalogue.js';

type Tx = Prisma.TransactionClient;

/**
 * The gift catalogue's audited changes, shared by `gift-admin add|update|enable|disable` and the admin panel
 * (v1.65-social, D197, CONVENTIONS §10.60.4): the catalogue rules of gift-catalogue.ts plus the audit row, written
 * in the caller's transaction with `via` and the actor. A field problem throws `GiftFieldsError` (nothing changes).
 */

/** Adds a gift; false when the code exists (nothing changes, no audit row). */
export async function addGiftByAdminIn(
  tx: Tx,
  code: string,
  fields: GiftFields,
  by: AdminVia = CLI_VIA,
  reason: string | null = null,
): Promise<boolean> {
  const created = await addGiftIn(tx, code, fields);
  if (created) {
    await tx.auditLog.create({
      data: {
        ...auditBy(by),
        action: AuditAction.GIFT_ADD,
        targetType: 'gift',
        targetId: code,
        metadata: { ...fields, ...(reason ? { reason } : {}), via: by.via },
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
): Promise<string[] | null> {
  const result = await updateGiftIn(tx, code, fields);
  if (!result) return null;
  const changes: Record<string, { from: string | number | null; to: string | number | null }> = {};
  for (const key of Object.keys(fields) as (keyof GiftFields)[]) {
    if (result.before[key] !== result.after[key]) {
      changes[key] = { from: result.before[key], to: result.after[key] };
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
