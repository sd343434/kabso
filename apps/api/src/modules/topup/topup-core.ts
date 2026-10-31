import type { Prisma, TopupCaseKind, TopupOrder } from '../../generated/prisma/client.js';
import { AuditAction } from '../../common/audit/audit.service.js';
import { uuidv7 } from '../levels/uuidv7.js';
import { recordRechargeIn, type RechargeBadgeRules } from '../recharge/recharge-badges.js';
import { creditIn, reverseTopupIn } from '../wallet/wallet-ledger.js';
import { fifoAttribution, GIFT_SPEND_REASONS, targetReversal } from './topup-rules.js';

/**
 * Card top-ups' database steps (v1.59-social, D190, CONVENTIONS §10.53), each inside the caller's transaction.
 * Shared by the API (webhook) and the `payments-admin` CLI (no Nest dependencies). Every change writes an
 * audit_logs row in the same transaction; webhook steps have no actor.
 */

type Tx = Prisma.TransactionClient;

/** Locks and reads an order (the row lock serializes every event of one purchase). */
export async function lockOrderIn(tx: Tx, orderId: string): Promise<TopupOrder | null> {
  const rows = await tx.$queryRaw<{ id: string }[]>`
    SELECT id::text AS id FROM topup_orders WHERE id = ${orderId}::uuid FOR UPDATE`;
  if (rows.length === 0) return null;
  return tx.topupOrder.findUnique({ where: { id: orderId } });
}

/**
 * Brings the coins taken back in line with what the order owes now (refunds, an early-fraud warning, a dispute):
 * takes the difference back (`CARD_TOPUP_REVERSAL`, the balance may go below 0) or gives it back
 * (`CARD_TOPUP_RESTORE`, a won dispute). `referenceId` — the Stripe event id, or the CLI's own id — makes each step
 * happen once. Nothing before the coins were credited. Returns the change (> 0 taken, < 0 given back).
 */
export async function reconcileOrderIn(
  tx: Tx,
  order: TopupOrder,
  referenceId: string,
  now: Date,
  actorUserId: string | null = null,
): Promise<bigint> {
  if (order.creditedAt === null) return 0n;
  const target = targetReversal({
    coins: order.coins,
    amountMinor: order.amountMinor,
    refundedMinor: order.refundedMinor,
    fraudWarning: order.fraudWarningAt !== null,
    disputeStatus: order.disputeStatus,
    disputeAmountMinor: order.disputeAmountMinor,
  });
  const delta = target - order.coinsReversed;
  if (delta === 0n) return 0n;
  const change =
    delta > 0n
      ? await reverseTopupIn(tx, order.userId, delta, referenceId)
      : await creditIn(tx, order.userId, -delta, 'CARD_TOPUP_RESTORE', referenceId);
  await tx.topupOrder.update({ where: { id: order.id }, data: { coinsReversed: target, updatedAt: now } });
  await tx.auditLog.create({
    data: {
      actorUserId,
      action: delta > 0n ? AuditAction.TOPUP_REVERSE : AuditAction.TOPUP_RESTORE,
      targetType: 'topup_order',
      targetId: order.id,
      metadata: {
        user: order.userId,
        coins: Number(delta > 0n ? delta : -delta),
        coinsReversed: Number(target),
        balance: Number(change.coins),
        reference: referenceId,
      },
    },
  });
  return delta;
}

/**
 * Credits a paid order's coins exactly once (`CARD_TOPUP`, reference: the order — a second credit of the same order
 * fails on the ledger's unique key) and counts them for the daily recharge badges (D187 hook, `WEBSITE_TOPUP`).
 * Then applies any reversal that arrived before the payment was confirmed. False when already credited.
 */
export async function creditOrderIn(
  tx: Tx,
  order: TopupOrder,
  now: Date,
  badges: RechargeBadgeRules,
  referenceId: string,
  paymentMethodType: string | null,
): Promise<boolean> {
  if (order.creditedAt !== null) return false;
  const change = await creditIn(tx, order.userId, order.coins, 'CARD_TOPUP', order.id);
  await recordRechargeIn(
    tx,
    { userId: order.userId, coins: order.coins, source: 'WEBSITE_TOPUP', now },
    badges,
  );
  const updated = await tx.topupOrder.update({
    where: { id: order.id },
    data: { status: 'PAID', creditedAt: now, paymentMethodType, updatedAt: now },
  });
  await tx.auditLog.create({
    data: {
      action: AuditAction.TOPUP_CREDIT,
      targetType: 'topup_order',
      targetId: order.id,
      metadata: {
        user: order.userId,
        coins: Number(order.coins),
        amountMinor: order.amountMinor,
        currency: order.currency,
        balance: Number(change.coins),
        reference: referenceId,
      },
    },
  });
  await reconcileOrderIn(tx, updated, `${referenceId}:after-credit`.slice(0, 64), now);
  return true;
}

/** Freezes the buyer from card purchases (once; the first cause is kept). True when newly frozen. */
export async function freezeBuyerIn(
  tx: Tx,
  order: TopupOrder,
  reason: TopupCaseKind,
  now: Date,
): Promise<boolean> {
  const inserted = await tx.$executeRaw`
    INSERT INTO topup_freezes (user_id, order_id, reason, created_at)
    VALUES (${order.userId}::uuid, ${order.id}::uuid, ${reason}::topup_case_kind, ${now})
    ON CONFLICT (user_id) DO NOTHING`;
  if (inserted === 0) return false;
  await tx.auditLog.create({
    data: {
      action: AuditAction.TOPUP_FREEZE,
      targetType: 'user',
      targetId: order.userId,
      metadata: { order: order.id, reason },
    },
  });
  return true;
}

/**
 * After a won dispute: lifts the freeze when none of the buyer's purchases still has coins taken back or an
 * early-fraud warning (a refund keeps the freeze until the team decides). True when lifted.
 */
export async function liftFreezeIfClearIn(tx: Tx, userId: string, now: Date, via: string): Promise<boolean> {
  const freeze = await tx.topupFreeze.findUnique({ where: { userId } });
  if (!freeze) return false;
  const open = await tx.topupOrder.count({
    where: { userId, OR: [{ coinsReversed: { gt: 0n } }, { fraudWarningAt: { not: null } }] },
  });
  if (open > 0) return false;
  await tx.topupFreeze.delete({ where: { userId } });
  await tx.auditLog.create({
    data: {
      action: AuditAction.TOPUP_UNFREEZE,
      targetType: 'user',
      targetId: userId,
      metadata: { via, order: freeze.orderId, at: now.toISOString() },
    },
  });
  return true;
}

/** One gift funded (in part) by the purchase, for the team (internal: recipients included). */
export interface AttributedGift {
  giftId: string;
  reason: string;
  sentAt: string;
  giftCode: string | null;
  place: 'LIVE' | 'DM' | 'UNKNOWN';
  coinsFromPurchase: number;
  totalCoins: number;
  recipients: { userId: string; username: string | null; cherries: number }[];
  /** `economy-admin reverse-gift` already ran for it. */
  cherriesReversed: boolean;
}

export interface Attribution {
  purchasedCoins: number;
  openingBalance: number;
  unspentCoins: number;
  gifts: AttributedGift[];
  otherSpends: { reason: string; referenceId: string; coins: number; at: string }[];
}

/**
 * FIFO attribution of the order's coins (owner rule): what they paid for, with the gifts' recipients and the
 * cherries each got — the case the team decides with `economy-admin reverse-gift`. Host cherries are never taken
 * back automatically.
 */
export async function attributionIn(tx: Tx, order: TopupOrder): Promise<Attribution> {
  const empty: Attribution = {
    purchasedCoins: Number(order.coins),
    openingBalance: 0,
    unspentCoins: Number(order.coins),
    gifts: [],
    otherSpends: [],
  };
  const credit = await tx.walletLedgerEntry.findUnique({
    where: { reason_referenceId: { reason: 'CARD_TOPUP', referenceId: order.id } },
  });
  if (!credit) return empty;
  const opening = credit.balanceAfter - credit.delta;
  const later = await tx.$queryRaw<
    { id: string; reason: string; delta: bigint; reference_id: string; created_at: Date }[]
  >`
    SELECT id::text AS id, reason::text AS reason, delta, reference_id, created_at
      FROM wallet_ledger
     WHERE user_id = ${order.userId}::uuid AND (created_at, id) > (${credit.createdAt}, ${credit.id}::uuid)
     ORDER BY created_at, id
     LIMIT 20000`;
  const { spends, unspent } = fifoAttribution(
    opening,
    order.coins,
    later.map((r) => ({
      id: r.id,
      reason: r.reason,
      delta: r.delta,
      referenceId: r.reference_id,
      createdAt: r.created_at,
    })),
  );
  const giftSpends = spends.filter((s) => GIFT_SPEND_REASONS.has(s.reason));
  const giftIds = giftSpends.map((s) => s.referenceId);
  const gifts = giftIds.length
    ? await tx.liveGift.findMany({
        where: { id: { in: giftIds } },
        select: { id: true, giftCode: true, roomId: true, dmConversationId: true, totalCoins: true },
      })
    : [];
  const byId = new Map(gifts.map((g) => [g.id, g]));
  const cherryRows = giftIds.length
    ? await tx.cherryLedgerEntry.findMany({
        where: { referenceId: { in: giftIds }, reason: { in: ['GIFT_RECEIVED', 'GIFT_REVERSAL'] } },
        select: { referenceId: true, userId: true, reason: true, delta: true },
      })
    : [];
  const users = [...new Set(cherryRows.map((r) => r.userId))];
  const profiles = users.length
    ? await tx.userProfile.findMany({
        where: { userId: { in: users } },
        select: { userId: true, username: true },
      })
    : [];
  const names = new Map(profiles.map((p) => [p.userId, p.username]));
  return {
    purchasedCoins: Number(order.coins),
    openingBalance: Number(opening),
    unspentCoins: Number(unspent),
    gifts: giftSpends.map((s) => {
      const g = byId.get(s.referenceId);
      const rows = cherryRows.filter((r) => r.referenceId === s.referenceId);
      return {
        giftId: s.referenceId,
        reason: s.reason,
        sentAt: s.at.toISOString(),
        giftCode: g?.giftCode ?? null,
        place: g ? (g.dmConversationId !== null ? 'DM' : 'LIVE') : 'UNKNOWN',
        coinsFromPurchase: Number(s.coins),
        totalCoins: Number(g?.totalCoins ?? s.coins),
        recipients: rows
          .filter((r) => r.reason === 'GIFT_RECEIVED')
          .map((r) => ({
            userId: r.userId,
            username: names.get(r.userId) ?? null,
            cherries: Number(r.delta),
          })),
        cherriesReversed: rows.some((r) => r.reason === 'GIFT_REVERSAL'),
      };
    }),
    otherSpends: spends
      .filter((s) => !GIFT_SPEND_REASONS.has(s.reason))
      .map((s) => ({
        reason: s.reason,
        referenceId: s.referenceId,
        coins: Number(s.coins),
        at: s.at.toISOString(),
      })),
  };
}

/**
 * Opens the admin case of a refund, an early-fraud warning or a dispute (once per Stripe object), with the FIFO
 * attribution. Returns the case id and whether it was created now.
 */
export async function openCaseIn(
  tx: Tx,
  order: TopupOrder,
  kind: TopupCaseKind,
  stripeObjectId: string,
  now: Date,
): Promise<{ id: string; created: boolean }> {
  const existing = await tx.topupCase.findUnique({
    where: { kind_stripeObjectId: { kind, stripeObjectId } },
    select: { id: true },
  });
  if (existing) {
    await tx.topupCase.update({ where: { id: existing.id }, data: { coinsReversed: order.coinsReversed } });
    return { id: existing.id, created: false };
  }
  const attribution = await attributionIn(tx, order);
  const id = uuidv7();
  await tx.topupCase.create({
    data: {
      id,
      orderId: order.id,
      userId: order.userId,
      kind,
      stripeObjectId,
      coinsReversed: order.coinsReversed,
      attribution: attribution as unknown as Prisma.InputJsonObject,
      createdAt: now,
    },
  });
  await tx.auditLog.create({
    data: {
      action: AuditAction.TOPUP_CASE_OPEN,
      targetType: 'topup_case',
      targetId: id,
      metadata: {
        order: order.id,
        user: order.userId,
        kind,
        gifts: attribution.gifts.length,
        coinsReversed: Number(order.coinsReversed),
      },
    },
  });
  return { id, created: true };
}

/** Closes a case (the team's decision, or a won dispute). False when it was already closed. */
export async function closeCaseIn(
  tx: Tx,
  caseId: string,
  now: Date,
  note: string | null,
  outcome: string | null = null,
  actorUserId: string | null = null,
): Promise<boolean> {
  const done = await tx.topupCase.updateMany({
    where: { id: caseId, status: 'OPEN' },
    data: { status: 'CLOSED', closedAt: now, note, ...(outcome ? { outcome } : {}) },
  });
  if (done.count === 0) return false;
  await tx.auditLog.create({
    data: {
      actorUserId,
      action: AuditAction.TOPUP_CASE_CLOSE,
      targetType: 'topup_case',
      targetId: caseId,
      metadata: { note: note ?? '', outcome: outcome ?? '' },
    },
  });
  return true;
}
