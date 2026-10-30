import { AuditAction } from '../../common/audit/audit.service.js';
import type { Prisma, PrismaClient, RechargeStockReason } from '../../generated/prisma/client.js';
import { uuidv7 } from '../levels/uuidv7.js';
import { agentCode, topUpPrice, type PriceTier } from './recharge-rules.js';

/**
 * Recharge agents (v1.54-social, D185, CONVENTIONS §10.48): the team's decisions and the stock ledger, shared by
 * the API, the `recharge-admin` CLI and the tests (no Nest dependencies). Every change writes its audit row in
 * the caller's transaction.
 */

type Tx = Prisma.TransactionClient;

/** A refused admin action (the CLI prints the message and exits 1; nothing changed). */
export class RechargeAdminError extends Error {}

/** The private prefix of an application's pictures (never public, §11.1). */
export function privateKeyOf(applicationId: string, which: 'photo' | 'selfie'): string {
  return `private/recharge-agents/${applicationId}/${which}.webp`;
}

/**
 * Changes an agent's stock by `delta` with its ledger row, inside the caller's transaction. A debit is one
 * conditional UPDATE (`stock ≥ coins`; the row lock serializes concurrent sales): null — nothing changed —
 * when the stock does not cover it.
 */
export async function moveStockIn(
  tx: Tx,
  agentUserId: string,
  delta: bigint,
  reason: RechargeStockReason,
  referenceId: string,
  now: Date,
): Promise<bigint | null> {
  if (delta === 0n) throw new RangeError('A stock change is not 0');
  const rows =
    delta > 0n
      ? await tx.$queryRaw<{ stock: bigint }[]>`
          UPDATE recharge_agents SET stock_coins = stock_coins + ${delta}, updated_at = now()
           WHERE user_id = ${agentUserId}::uuid RETURNING stock_coins AS stock`
      : await tx.$queryRaw<{ stock: bigint }[]>`
          UPDATE recharge_agents SET stock_coins = stock_coins + ${delta}, updated_at = now()
           WHERE user_id = ${agentUserId}::uuid AND stock_coins >= ${-delta} RETURNING stock_coins AS stock`;
  const row = rows[0];
  if (!row) return null;
  await tx.rechargeStockEntry.create({
    data: { id: uuidv7(), agentUserId, delta, balanceAfter: row.stock, reason, referenceId, createdAt: now },
  });
  return row.stock;
}

async function audit(
  tx: Tx,
  action: AuditAction,
  targetType: string,
  targetId: string,
  metadata: Prisma.InputJsonValue,
  actorUserId: string | null = null,
): Promise<void> {
  await tx.auditLog.create({ data: { actorUserId, action, targetType, targetId, metadata } });
}

/** `recharge-admin approve`: a PENDING application becomes an APPROVED agent waiting for the first top-up. */
export async function approveApplicationIn(
  tx: Tx,
  applicationId: string,
  now: Date,
): Promise<{ userId: string }> {
  const [app] = await tx.$queryRaw<
    { id: string; user_id: string; status: string; locations: unknown; payment_methods: unknown }[]
  >`SELECT id::text AS id, user_id::text AS user_id, status::text AS status, locations, payment_methods
      FROM recharge_agent_applications WHERE id = ${applicationId}::uuid FOR UPDATE`;
  if (!app) throw new RechargeAdminError(`No application ${applicationId}.`);
  if (app.status !== 'PENDING')
    throw new RechargeAdminError(`The application is ${app.status}, not PENDING.`);
  const user = await tx.user.findUnique({ where: { id: app.user_id }, select: { status: true } });
  if (user?.status !== 'ACTIVE') throw new RechargeAdminError('The applicant account is not ACTIVE.');
  if ((await tx.rechargeAgent.count({ where: { userId: app.user_id } })) > 0) {
    throw new RechargeAdminError('The applicant is already an agent.');
  }
  const locations = (app.locations ?? []) as { country: string; cities: string[] }[];
  const methods = (app.payment_methods ?? []) as { country: string; type: string }[];
  const paymentTypes: Record<string, string[]> = {};
  for (const m of methods) {
    const list = (paymentTypes[m.country] ??= []);
    if (!list.includes(m.type)) list.push(m.type);
  }
  await tx.rechargeAgentApplication.update({
    where: { id: app.id },
    data: { status: 'APPROVED', decidedAt: now },
  });
  await tx.rechargeAgent.create({
    data: {
      userId: app.user_id,
      applicationId: app.id,
      status: 'APPROVED',
      countries: locations.map((l) => l.country),
      locations: locations,
      paymentTypes: paymentTypes,
      approvedAt: now,
    },
  });
  // A person who becomes an agent stops being anyone's employee.
  await tx.rechargeEmployee.updateMany({
    where: { employeeUserId: app.user_id, removedAt: null },
    data: { removedAt: now },
  });
  await audit(tx, AuditAction.RECHARGE_APPLICATION_APPROVE, 'recharge_application', app.id, {
    user: app.user_id,
    via: 'cli',
  });
  return { userId: app.user_id };
}

/** `recharge-admin reject`: a PENDING application is refused with a reason (the person may apply again). */
export async function rejectApplicationIn(
  tx: Tx,
  applicationId: string,
  reason: string,
  now: Date,
): Promise<void> {
  const done = await tx.rechargeAgentApplication.updateMany({
    where: { id: applicationId, status: 'PENDING' },
    data: { status: 'REJECTED', decidedAt: now, rejectReason: reason },
  });
  if (done.count === 0) throw new RechargeAdminError(`No PENDING application ${applicationId}.`);
  await audit(tx, AuditAction.RECHARGE_APPLICATION_REJECT, 'recharge_application', applicationId, {
    reason,
    via: 'cli',
  });
}

export interface TopUpResult {
  readonly topupId: string;
  readonly first: boolean;
  /** The code given now (the first top-up) or before. */
  readonly code: string | null;
  readonly stock: bigint;
  readonly tier: string;
  readonly minorPerMillion: number;
  readonly expectedMinor: bigint;
}

/**
 * `recharge-admin topup`: records a wholesale top-up paid outside the app with the owner's price tier. The
 * first one must be at least `activationMinCoins` and activates the agent with the next code from the counter
 * row (updated in this transaction: in order, no gaps, never twice). A suspended agent cannot be topped up.
 */
export async function topUpIn(
  tx: Tx,
  agentUserId: string,
  coins: bigint,
  paidMinor: bigint,
  note: string | null,
  rules: { activationMinCoins: number; priceTiers: readonly PriceTier[]; currency: string },
  now: Date,
): Promise<TopUpResult> {
  if (coins <= 0n || coins > 1_000_000_000_000n)
    throw new RechargeAdminError('Coins must be 1 … 1 000 000 000 000.');
  const [agent] = await tx.$queryRaw<{ status: string; code: string | null }[]>`
    SELECT status::text AS status, code FROM recharge_agents WHERE user_id = ${agentUserId}::uuid FOR UPDATE`;
  if (!agent) throw new RechargeAdminError('Not an agent.');
  if (agent.status === 'SUSPENDED') throw new RechargeAdminError('The agent is SUSPENDED; reinstate first.');
  const first = agent.code === null;
  if (first && coins < BigInt(rules.activationMinCoins)) {
    throw new RechargeAdminError(
      `The first top-up must be at least ${String(rules.activationMinCoins)} coins (it activates the agent).`,
    );
  }
  const price = topUpPrice(coins, rules.priceTiers);
  if (paidMinor !== price.expectedMinor && (note ?? '') === '') {
    throw new RechargeAdminError(
      `The tier ${price.tier} price is ${String(price.expectedMinor)} minor units; a different amount needs --note.`,
    );
  }
  const topupId = uuidv7();
  await tx.rechargeTopup.create({
    data: {
      id: topupId,
      agentUserId,
      coins,
      tier: price.tier,
      pricePerMillionMinor: price.minorPerMillion,
      expectedMinor: price.expectedMinor,
      paidMinor,
      currency: rules.currency,
      first,
      note,
      createdAt: now,
    },
  });
  let code = agent.code;
  if (first) {
    const [counter] = await tx.$queryRaw<{ n: number }[]>`
      INSERT INTO recharge_agent_counter (id, last_number) VALUES (1, 1)
      ON CONFLICT (id) DO UPDATE SET last_number = recharge_agent_counter.last_number + 1
      RETURNING last_number AS n`;
    if (!counter) throw new Error('recharge_agent_counter row missing');
    code = agentCode(counter.n);
    await tx.rechargeAgent.update({
      where: { userId: agentUserId },
      data: { status: 'ACTIVE', code, codeNumber: counter.n, activatedAt: now },
    });
    await audit(tx, AuditAction.RECHARGE_ACTIVATE, 'recharge_agent', agentUserId, { code, via: 'cli' });
  }
  const stock = await moveStockIn(tx, agentUserId, coins, 'TOPUP', topupId, now);
  await audit(tx, AuditAction.RECHARGE_TOPUP, 'recharge_topup', topupId, {
    agent: agentUserId,
    coins: Number(coins),
    tier: price.tier,
    minorPerMillion: price.minorPerMillion,
    expectedMinor: Number(price.expectedMinor),
    paidMinor: Number(paidMinor),
    currency: rules.currency,
    first,
    note,
    via: 'cli',
  });
  return {
    topupId,
    first,
    code,
    stock: stock!,
    tier: price.tier,
    minorPerMillion: price.minorPerMillion,
    expectedMinor: price.expectedMinor,
  };
}

/**
 * `recharge-admin suspend`: the agent loses selling, the listing and every perk at once (they are derived from
 * the status); open cherry requests are cancelled.
 */
export async function suspendIn(tx: Tx, agentUserId: string, reason: string, now: Date): Promise<void> {
  const done = await tx.rechargeAgent.updateMany({
    where: { userId: agentUserId, status: { not: 'SUSPENDED' } },
    data: { status: 'SUSPENDED', suspendedAt: now, suspendReason: reason, updatedAt: now },
  });
  if (done.count === 0) throw new RechargeAdminError('Not an agent, or already SUSPENDED.');
  const cancelled = await tx.rechargeCherryRequest.updateMany({
    where: { agentUserId, status: 'PENDING' },
    data: { status: 'CANCELLED', decidedAt: now },
  });
  await audit(tx, AuditAction.RECHARGE_SUSPEND, 'recharge_agent', agentUserId, {
    reason,
    cancelledRequests: cancelled.count,
    via: 'cli',
  });
}

/** `recharge-admin reinstate`: back to ACTIVE (or APPROVED when it was never activated). */
export async function reinstateIn(tx: Tx, agentUserId: string, now: Date): Promise<string> {
  const agent = await tx.rechargeAgent.findUnique({ where: { userId: agentUserId } });
  if (agent?.status !== 'SUSPENDED') throw new RechargeAdminError('Not a SUSPENDED agent.');
  const status = agent.code === null ? 'APPROVED' : 'ACTIVE';
  await tx.rechargeAgent.update({
    where: { userId: agentUserId },
    data: { status, suspendedAt: null, suspendReason: null, updatedAt: now },
  });
  await audit(tx, AuditAction.RECHARGE_REINSTATE, 'recharge_agent', agentUserId, { status, via: 'cli' });
  return status;
}

/** `recharge-admin set-cap`: the agent's daily cherry cap (null = the server default). */
export async function setCapIn(tx: Tx, agentUserId: string, cap: bigint | null): Promise<void> {
  const done = await tx.rechargeAgent.updateMany({
    where: { userId: agentUserId },
    data: { dailyCherryCap: cap },
  });
  if (done.count === 0) throw new RechargeAdminError('Not an agent.');
  await audit(tx, AuditAction.RECHARGE_CAP, 'recharge_agent', agentUserId, {
    cap: cap === null ? null : Number(cap),
    via: 'cli',
  });
}

/**
 * The retention step (the sweeper and `recharge-admin purge`): the pictures and personal fields of REJECTED
 * applications decided more than `retentionDays` ago, and of every not-APPROVED application of a deleted
 * account, are deleted; the row keeps its status and dates (`purged_at`). The objects go first (a storage
 * failure throws and the next run retries). Returns how many applications were purged.
 */
export async function purgeApplications(
  prisma: PrismaClient | Tx,
  deleteObjects: (keys: string[]) => Promise<void>,
  now: Date,
  retentionDays: number,
  actor: 'sweeper' | 'cli',
): Promise<number> {
  const before = new Date(now.getTime() - retentionDays * 86_400_000);
  const rows = await prisma.rechargeAgentApplication.findMany({
    where: {
      purgedAt: null,
      OR: [
        { status: 'REJECTED', decidedAt: { lt: before } },
        { status: { not: 'APPROVED' }, user: { deletedAt: { not: null } } },
        { status: 'APPROVED', user: { deletedAt: { not: null } }, agent: null },
      ],
    },
    select: { id: true, photoKey: true, selfieKey: true },
    take: 200,
  });
  if (rows.length === 0) return 0;
  const keys = rows.flatMap((r) => [r.photoKey, r.selfieKey]).filter((k): k is string => k !== null);
  await deleteObjects(keys);
  const ids = rows.map((r) => r.id);
  await prisma.$executeRaw`
    UPDATE recharge_agent_applications
       SET full_name = NULL, phone = NULL, photo_key = NULL, selfie_key = NULL, locations = NULL,
           payment_methods = NULL, purged_at = ${now}
     WHERE id = ANY(${ids}::uuid[])`;
  await prisma.auditLog.create({
    data: {
      action: AuditAction.RECHARGE_PURGE,
      targetType: 'recharge_application',
      targetId: rows[0]!.id,
      metadata: { count: rows.length, ids: rows.map((r) => r.id), via: actor },
    },
  });
  return rows.length;
}
