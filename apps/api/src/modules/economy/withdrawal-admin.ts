import { auditBy, CLI_VIA, type AdminVia } from '../../common/audit/admin-actor.js';
import { AuditAction } from '../../common/audit/audit.service.js';
import type { Prisma } from '../../generated/prisma/client.js';
import { refundCherriesIn } from './cherry-ledger.js';

/**
 * Deciding a cherry withdrawal request (v1.52-social, D179, CONVENTIONS §10.46; shared since v1.60-social, D191,
 * §10.54.4): `economy-admin withdrawal-pay|withdrawal-reject` and the admin panel run this one rule. PAID records
 * that the money was sent by hand (the note carries the payment reference); REJECTED gives the held cherries back
 * (`WITHDRAWAL_REFUND`). The row is locked; a request that is no longer PENDING is refused (nothing changed). The
 * audit row is written in the same transaction.
 */
export class WithdrawalAdminError extends Error {}

export interface WithdrawalDecision {
  readonly id: string;
  readonly userId: string;
  readonly cherries: bigint;
  readonly status: 'PAID' | 'REJECTED';
}

export async function decideWithdrawalIn(
  tx: Prisma.TransactionClient,
  withdrawalId: string,
  pay: boolean,
  note: string | null,
  now: Date,
  by: AdminVia = CLI_VIA,
): Promise<WithdrawalDecision> {
  const [w] = await tx.$queryRaw<{ id: string; user_id: string; status: string; cherries: bigint }[]>`
    SELECT id::text AS id, user_id::text AS user_id, status::text AS status, cherries
      FROM cherry_withdrawals WHERE id = ${withdrawalId}::uuid FOR UPDATE`;
  if (!w) throw new WithdrawalAdminError(`No withdrawal ${withdrawalId}.`);
  if (w.status !== 'PENDING')
    throw new WithdrawalAdminError(`Withdrawal ${withdrawalId} is ${w.status}; nothing changed.`);
  const status = pay ? 'PAID' : 'REJECTED';
  await tx.cherryWithdrawal.update({
    where: { id: withdrawalId },
    data: { status, decidedAt: now, decisionNote: note },
  });
  if (!pay) await refundCherriesIn(tx, w.user_id, w.cherries, withdrawalId, now);
  await tx.auditLog.create({
    data: {
      ...auditBy(by),
      action: pay ? AuditAction.CHERRY_WITHDRAWAL_PAY : AuditAction.CHERRY_WITHDRAWAL_REJECT,
      targetType: 'cherry_withdrawal',
      targetId: withdrawalId,
      metadata: {
        user: w.user_id,
        cherries: Number(w.cherries),
        note,
        before: 'PENDING',
        after: status,
        via: by.via,
      },
    },
  });
  return { id: w.id, userId: w.user_id, cherries: w.cherries, status };
}
