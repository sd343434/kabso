import { auditBy, CLI_VIA, type AdminVia } from '../../common/audit/admin-actor.js';
import { AuditAction } from '../../common/audit/audit.service.js';
import type {
  Prisma,
  PrismaClient,
  RechargeOrder,
  RechargeOrderMessageKind,
  RechargeOrderRole,
} from '../../generated/prisma/client.js';
import { uuidv7 } from '../levels/uuidv7.js';
import { creditIn } from '../wallet/wallet-ledger.js';
import { recordRechargeIn, type RechargeCreditRules } from './recharge-badges.js';
import { referralRechargeIn } from '../referrals/referral-core.js';
import { moveStockIn, RechargeAdminError } from './recharge-core.js';
import type { DisputeOutcome, OrderStatus } from './recharge-order-rules.js';

/**
 * Recharge orders with escrow «طلبات الشحن» (v1.69-social, D204, CONVENTIONS §10.64): the coin movements and the
 * state changes, shared by the API, the panel, the `recharge-admin` CLI, the sweeper and the tests (no Nest
 * dependencies). Every function runs inside the caller's transaction, after {@link lockOrderIn}: the order row lock
 * serializes confirm, dispute, cancel, expiry and an admin's decision, so exactly one of them moves the coins.
 */

type Tx = Prisma.TransactionClient;

/** The private prefix of an order's pictures (never public, §11.1). */
export function orderImageKey(orderId: string, messageId: string): string {
  return `private/recharge-orders/${orderId}/${messageId}.webp`;
}

/** The order row locked for this transaction (FOR UPDATE), or null. */
export async function lockOrderIn(tx: Tx, orderId: string): Promise<RechargeOrder | null> {
  const [row] = await tx.$queryRaw<{ id: string }[]>`
    SELECT id::text AS id FROM recharge_orders WHERE id = ${orderId}::uuid FOR UPDATE`;
  if (!row) return null;
  return tx.rechargeOrder.findUnique({ where: { id: orderId } });
}

export async function messageIn(
  tx: Tx,
  input: {
    orderId: string;
    role: RechargeOrderRole;
    kind: RechargeOrderMessageKind;
    authorUserId?: string | null;
    text?: string | null;
    method?: string | null;
    imageKey?: string | null;
    event?: string | null;
    id?: string;
    now: Date;
  },
): Promise<string> {
  const id = input.id ?? uuidv7();
  await tx.rechargeOrderMessage.create({
    data: {
      id,
      orderId: input.orderId,
      authorUserId: input.authorUserId ?? null,
      role: input.role,
      kind: input.kind,
      text: input.text ?? null,
      method: input.method ?? null,
      imageKey: input.imageKey ?? null,
      event: input.event ?? null,
      createdAt: input.now,
    },
  });
  return id;
}

/** A system line of the chat («أرسل الوكيل معلومات الدفع» …), the event's key in `event`. */
export function systemLineIn(
  tx: Tx,
  orderId: string,
  event: string,
  now: Date,
  text: string | null = null,
): Promise<string> {
  return messageIn(tx, { orderId, role: 'SYSTEM', kind: 'SYSTEM', event, text, now });
}

/**
 * The people who serve the agent's orders: the agent and the employees on shift now are notified; every active
 * employee may read the order (only on shift may they act).
 */
export async function agentSideIn(tx: Tx | PrismaClient, agentUserId: string): Promise<string[]> {
  const rows = await tx.rechargeEmployee.findMany({
    where: { agentUserId, removedAt: null },
    select: { employeeUserId: true },
  });
  return [agentUserId, ...rows.map((r) => r.employeeUserId)];
}

/**
 * One unread `RECHARGE_ORDER_UPDATE` per order and recipient (the latest event moves it up and pushes again); never
 * to an account that is not ACTIVE. System notifications: no actor, so a block between the two sides never hides
 * an order's state (the order itself is the evidence).
 */
export async function notifyOrderIn(
  tx: Tx,
  orderId: string,
  recipients: readonly string[],
  event: string,
  now: Date,
): Promise<void> {
  for (const recipientId of new Set(recipients)) {
    const [active] = await tx.$queryRaw<{ ok: boolean }[]>`
      SELECT EXISTS (SELECT 1 FROM users WHERE id = ${recipientId}::uuid AND status = 'ACTIVE'::user_status) AS ok`;
    if (!active?.ok) continue;
    await tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtext('kabso:notif'), hashtext(${`${recipientId}:ro:${orderId}`}))`;
    const open = await tx.notification.findFirst({
      where: { recipientId, rechargeOrderId: orderId, readAt: null },
      select: { id: true },
    });
    if (open) {
      await tx.notification.update({
        where: { id: open.id },
        data: { rechargeOrderEvent: event, updatedAt: now },
      });
    } else {
      await tx.notification.create({
        data: {
          recipientId,
          type: 'RECHARGE_ORDER_UPDATE',
          rechargeOrderId: orderId,
          rechargeOrderEvent: event,
          createdAt: now,
          updatedAt: now,
        },
      });
    }
  }
}

/** Every person of the order (the buyer and the agent's side). */
export async function partiesIn(tx: Tx, order: Pick<RechargeOrder, 'buyerUserId' | 'agentUserId'>) {
  return [order.buyerUserId, ...(await agentSideIn(tx, order.agentUserId))];
}

/** Releases the frozen coins back to the agent's stock (ORDER_RELEASE, once per order). */
async function releaseIn(tx: Tx, order: RechargeOrder, now: Date): Promise<bigint> {
  const stock = await moveStockIn(tx, order.agentUserId, order.coins, 'ORDER_RELEASE', order.id, now);
  if (stock === null) throw new Error('The agent row is missing');
  return stock;
}

/** Credits the frozen coins to the buyer (wallet ledger RECHARGE_ORDER, the daily recharge badge). */
async function creditBuyerIn(
  tx: Tx,
  order: RechargeOrder,
  now: Date,
  badges: RechargeCreditRules,
): Promise<bigint> {
  const wallet = await creditIn(tx, order.buyerUserId, order.coins, 'RECHARGE_ORDER', order.id);
  await recordRechargeIn(
    tx,
    { userId: order.buyerUserId, coins: order.coins, source: 'AGENT_SALE', now },
    badges,
  );
  // v1.74-social (D217): the invitee's first recharge pays the inviter a share (held).
  await referralRechargeIn(
    tx,
    { userId: order.buyerUserId, coins: order.coins, reason: 'RECHARGE_ORDER', reference: order.id, now },
    badges.cherriesPerCoin,
  );
  return wallet.coins;
}

/**
 * Ends a REQUESTED / AWAITING_PAYMENT order whose time ran out (the hold goes back), inside the caller's
 * transaction on the locked row. Returns whether it expired now.
 */
export async function expireIfDueIn(tx: Tx, order: RechargeOrder, now: Date): Promise<boolean> {
  if (order.status !== 'REQUESTED' && order.status !== 'AWAITING_PAYMENT') return false;
  if (order.expiresAt === null || order.expiresAt.getTime() > now.getTime()) return false;
  let stockAfter: bigint | null = null;
  if (order.status === 'AWAITING_PAYMENT') stockAfter = await releaseIn(tx, order, now);
  await tx.rechargeOrder.update({
    where: { id: order.id },
    data: { status: 'EXPIRED', heldCoins: 0n, expiresAt: null, closedAt: now, updatedAt: now },
  });
  await systemLineIn(tx, order.id, 'EXPIRED', now);
  await tx.auditLog.create({
    data: {
      action: AuditAction.RECHARGE_ORDER_EXPIRE,
      targetType: 'recharge_order',
      targetId: order.id,
      metadata: {
        before: order.status,
        after: 'EXPIRED',
        released: order.status === 'AWAITING_PAYMENT' ? Number(order.coins) : 0,
        ...(stockAfter === null ? {} : { stockAfter: Number(stockAfter) }),
        via: 'sweeper',
      },
    },
  });
  await notifyOrderIn(tx, order.id, await partiesIn(tx, order), 'EXPIRED', now);
  return true;
}

/** The sweeper's step: every order past its deadline, each in its own transaction (SKIP LOCKED). */
export async function expireDueOrders(prisma: PrismaClient, now: Date, batch = 200): Promise<number> {
  const due = await prisma.rechargeOrder.findMany({
    where: { status: { in: ['REQUESTED', 'AWAITING_PAYMENT'] }, expiresAt: { lte: now } },
    select: { id: true },
    orderBy: { expiresAt: 'asc' },
    take: batch,
  });
  let n = 0;
  for (const { id } of due) {
    const done = await prisma.$transaction(async (tx) => {
      const [row] = await tx.$queryRaw<{ id: string }[]>`
        SELECT id::text AS id FROM recharge_orders WHERE id = ${id}::uuid FOR UPDATE SKIP LOCKED`;
      if (!row) return false;
      const order = await tx.rechargeOrder.findUniqueOrThrow({ where: { id } });
      return expireIfDueIn(tx, order, now);
    });
    if (done) n += 1;
  }
  return n;
}

/** Statuses an action may start from, with the error the caller maps (nothing changed). */
export class OrderStateError extends Error {
  constructor(readonly status: OrderStatus) {
    super(`The order is ${status}.`);
  }
}

/**
 * The agent's «استلمت»: the frozen coins go to the buyer (COMPLETED). Idempotent: an order already COMPLETED returns
 * `false` (nothing moved again).
 */
export async function confirmIn(
  tx: Tx,
  order: RechargeOrder,
  actorUserId: string,
  now: Date,
  badges: RechargeCreditRules,
): Promise<boolean> {
  if (order.status === 'COMPLETED') return false;
  if (order.status !== 'PAID') throw new OrderStateError(order.status);
  const balance = await creditBuyerIn(tx, order, now, badges);
  await tx.rechargeOrder.update({
    where: { id: order.id },
    data: { status: 'COMPLETED', heldCoins: 0n, closedAt: now, closedBy: actorUserId, updatedAt: now },
  });
  await systemLineIn(tx, order.id, 'COMPLETED', now);
  await tx.auditLog.create({
    data: {
      actorUserId,
      action: AuditAction.RECHARGE_ORDER_CONFIRM,
      targetType: 'recharge_order',
      targetId: order.id,
      metadata: {
        before: 'PAID',
        after: 'COMPLETED',
        coins: Number(order.coins),
        buyer: order.buyerUserId,
        agent: order.agentUserId,
        buyerBalance: Number(balance),
      },
    },
  });
  await notifyOrderIn(tx, order.id, await partiesIn(tx, order), 'COMPLETED', now);
  return true;
}

/** A cancellation (buyer before PAID, agent before the details): the hold, if any, goes back to the stock. */
export async function cancelIn(
  tx: Tx,
  order: RechargeOrder,
  by: { userId: string; side: 'BUYER' | 'AGENT' },
  reason: string | null,
  now: Date,
): Promise<void> {
  const allowed: readonly OrderStatus[] =
    by.side === 'BUYER' ? ['REQUESTED', 'AWAITING_PAYMENT'] : ['REQUESTED'];
  if (!allowed.includes(order.status)) throw new OrderStateError(order.status);
  const held = order.status === 'AWAITING_PAYMENT';
  const stockAfter = held ? await releaseIn(tx, order, now) : null;
  await tx.rechargeOrder.update({
    where: { id: order.id },
    data: {
      status: 'CANCELLED',
      heldCoins: 0n,
      expiresAt: null,
      closedAt: now,
      closedBy: by.userId,
      closeReason: reason,
      updatedAt: now,
    },
  });
  await systemLineIn(
    tx,
    order.id,
    by.side === 'BUYER' ? 'CANCELLED_BY_BUYER' : 'CANCELLED_BY_AGENT',
    now,
    reason,
  );
  await tx.auditLog.create({
    data: {
      actorUserId: by.userId,
      action: AuditAction.RECHARGE_ORDER_CANCEL,
      targetType: 'recharge_order',
      targetId: order.id,
      metadata: {
        before: order.status,
        after: 'CANCELLED',
        side: by.side,
        released: held ? Number(order.coins) : 0,
        ...(stockAfter === null ? {} : { stockAfter: Number(stockAfter) }),
      },
    },
  });
  await notifyOrderIn(tx, order.id, await partiesIn(tx, order), 'CANCELLED', now);
}

/**
 * An admin's decision on a DISPUTED order (panel or CLI; the panel asks for the authenticator code first): the frozen
 * coins go to the buyer (COMPLETED_BY_ADMIN) or back to the agent's stock (REFUNDED_TO_AGENT). Idempotent: the same
 * decision again returns `false` (nothing moved); a different one is refused.
 */
export async function resolveDisputeIn(
  tx: Tx,
  orderId: string,
  outcome: DisputeOutcome,
  reason: string,
  now: Date,
  badges: RechargeCreditRules,
  by: AdminVia = CLI_VIA,
): Promise<{ status: OrderStatus; changed: boolean }> {
  const order = await lockOrderIn(tx, orderId);
  if (!order) throw new RechargeAdminError(`No order ${orderId}.`);
  const target: OrderStatus = outcome === 'CREDIT_BUYER' ? 'COMPLETED_BY_ADMIN' : 'REFUNDED_TO_AGENT';
  if (order.status === target) return { status: target, changed: false };
  if (order.status !== 'DISPUTED') {
    throw new RechargeAdminError(`The order is ${order.status}, not DISPUTED.`);
  }
  const balance =
    outcome === 'CREDIT_BUYER'
      ? await creditBuyerIn(tx, order, now, badges)
      : await releaseIn(tx, order, now);
  await tx.rechargeOrder.update({
    where: { id: order.id },
    data: {
      status: target,
      heldCoins: 0n,
      closedAt: now,
      closedBy: by.actorUserId,
      closeReason: reason,
      updatedAt: now,
    },
  });
  await systemLineIn(
    tx,
    order.id,
    outcome === 'CREDIT_BUYER' ? 'RESOLVED_FOR_BUYER' : 'RESOLVED_FOR_AGENT',
    now,
    reason,
  );
  await tx.auditLog.create({
    data: {
      ...auditBy(by),
      action: AuditAction.RECHARGE_ORDER_RESOLVE,
      targetType: 'recharge_order',
      targetId: order.id,
      metadata: {
        before: 'DISPUTED',
        after: target,
        outcome,
        reason,
        coins: Number(order.coins),
        buyer: order.buyerUserId,
        agent: order.agentUserId,
        ...(outcome === 'CREDIT_BUYER' ? { buyerBalance: Number(balance) } : { stockAfter: Number(balance) }),
        via: by.via,
      },
    },
  });
  await notifyOrderIn(tx, order.id, await partiesIn(tx, order), target, now);
  return { status: target, changed: true };
}

/** `recharge-admin set-rate` / the panel: a country's exchange rate (audited with before / after). */
export async function setExchangeRateIn(
  tx: Tx,
  country: string,
  rate: { currency: string; rateMicro: bigint; digits: number },
  reason: string,
  now: Date,
  by: AdminVia = CLI_VIA,
): Promise<void> {
  if (!/^[A-Z]{2}$/.test(country)) throw new RechargeAdminError('The country is two letters (ISO 3166).');
  if (!/^[A-Z]{3}$/.test(rate.currency))
    throw new RechargeAdminError('The currency is three letters (ISO 4217).');
  if (rate.rateMicro <= 0n || rate.rateMicro > 1_000_000_000_000_000n) {
    throw new RechargeAdminError('The rate is positive (units per 1 USD).');
  }
  if (!Number.isInteger(rate.digits) || rate.digits < 0 || rate.digits > 3) {
    throw new RechargeAdminError('The decimals are 0 … 3.');
  }
  const before = await tx.rechargeExchangeRate.findUnique({ where: { country } });
  await tx.rechargeExchangeRate.upsert({
    where: { country },
    create: { country, ...rate, updatedAt: now, updatedBy: by.actorUserId },
    update: { ...rate, updatedAt: now, updatedBy: by.actorUserId },
  });
  await tx.auditLog.create({
    data: {
      ...auditBy(by),
      action: AuditAction.RECHARGE_RATE_SET,
      targetType: 'recharge_exchange_rate',
      targetId: country,
      metadata: {
        before: before
          ? { currency: before.currency, rateMicro: Number(before.rateMicro), digits: before.digits }
          : null,
        after: { currency: rate.currency, rateMicro: Number(rate.rateMicro), digits: rate.digits },
        reason,
        via: by.via,
      },
    },
  });
}

/** `recharge-admin clear-rate` / the panel: the country goes back to USD only. */
export async function clearExchangeRateIn(
  tx: Tx,
  country: string,
  reason: string,
  by: AdminVia = CLI_VIA,
): Promise<void> {
  const before = await tx.rechargeExchangeRate.findUnique({ where: { country } });
  if (!before) throw new RechargeAdminError(`No rate for ${country}.`);
  await tx.rechargeExchangeRate.delete({ where: { country } });
  await tx.auditLog.create({
    data: {
      ...auditBy(by),
      action: AuditAction.RECHARGE_RATE_CLEAR,
      targetType: 'recharge_exchange_rate',
      targetId: country,
      metadata: {
        before: { currency: before.currency, rateMicro: Number(before.rateMicro), digits: before.digits },
        after: null,
        reason,
        via: by.via,
      },
    },
  });
}
