import type { CherryLedgerReason, Prisma } from '../../generated/prisma/client.js';
import { uuidv7 } from '../levels/uuidv7.js';
import {
  agencyCommissionPaid,
  agencyRateBps,
  commissionOf,
  dateValue,
  giftCherries,
  monthKey,
  addMonths,
  parentCommissionPaid,
  taskCherryLock,
  type AgencyRankValue,
  type EconomyRules,
  type TaskCherryLock,
} from './economy-math.js';

/**
 * The cherry ledger (v1.52-social, D179, CONVENTIONS §10.46): every change of a cherry balance is a
 * `cherry_ledger` row written with the balance in the same transaction. Shared by the API and the
 * `economy-admin` CLI (no Nest dependencies).
 *
 * Lock order (no deadlock between sends, reversals and withdrawals): the `agency_months` rows of a send
 * (sorted by agency), then the `cherry_wallets` rows (sorted by user), each in one statement.
 */

type Tx = Prisma.TransactionClient;

interface Movement {
  readonly userId: string;
  readonly reason: CherryLedgerReason;
  readonly delta: bigint;
}

/**
 * Applies the movements of one reference: the balances in one sorted upsert, then one ledger row per
 * (user, reason) — `(user, reason, reference)` is unique, so a second application fails and rolls the
 * caller's transaction back. Movements of the same user and reason must be merged by the caller.
 */
async function applyMovementsIn(
  tx: Tx,
  movements: readonly Movement[],
  referenceId: string,
  at: Date,
): Promise<void> {
  const moves = movements.filter((m) => m.delta !== 0n);
  if (moves.length === 0) return;
  const perUser = new Map<string, bigint>();
  for (const m of moves) perUser.set(m.userId, (perUser.get(m.userId) ?? 0n) + m.delta);
  const ids = [...perUser.keys()].sort();
  const rows = await tx.$queryRaw<{ user_id: string; cherries: bigint }[]>`
    INSERT INTO cherry_wallets (user_id, cherries, updated_at)
    SELECT t.u, t.d, now()
      FROM unnest(${ids}::uuid[], ${ids.map((id) => perUser.get(id)!.toString())}::bigint[]) AS t(u, d)
     ORDER BY t.u
    ON CONFLICT (user_id) DO UPDATE SET cherries = cherry_wallets.cherries + EXCLUDED.cherries, updated_at = now()
    RETURNING user_id::text AS user_id, cherries`;
  const after = new Map(rows.map((r) => [r.user_id, r.cherries]));
  // balance_after of each row: the final balance minus the user's later rows (in the given order).
  const remaining = new Map(after);
  const data: Prisma.CherryLedgerEntryCreateManyInput[] = [];
  for (let i = moves.length - 1; i >= 0; i--) {
    const m = moves[i]!;
    const balance = remaining.get(m.userId)!;
    data.unshift({
      id: uuidv7(),
      userId: m.userId,
      delta: m.delta,
      balanceAfter: balance,
      reason: m.reason,
      referenceId,
      createdAt: at,
    });
    remaining.set(m.userId, balance - m.delta);
  }
  await tx.cherryLedgerEntry.createMany({ data });
}

/** Merges movements of the same user and reason. */
function merged(movements: readonly Movement[]): Movement[] {
  const map = new Map<string, Movement>();
  for (const m of movements) {
    const key = `${m.userId}|${m.reason}`;
    const prev = map.get(key);
    map.set(key, prev ? { ...prev, delta: prev.delta + m.delta } : m);
  }
  return [...map.values()];
}

/** What a send credited (the response of `creditGiftCherriesIn`; tests and logs). */
export interface GiftCherryCredit {
  readonly recipients: readonly { userId: string; cherries: bigint }[];
  readonly commissions: readonly { userId: string; reason: CherryLedgerReason; cherries: bigint }[];
}

/**
 * Inside a gift send's transaction (live and direct-conversation sends, after the send's rows exist):
 * credits each recipient floor(coins × the send's stored share × CHERRIES_PER_COIN) cherries
 * (`GIFT_RECEIVED`), and — for a recipient who is an agency's ACTIVE host — records the host's cherries
 * for the agency's month and pays, on top, the agency's commission (`AGENCY_COMMISSION`, 15 % or 16 %)
 * and its parent's (`PARENT_COMMISSION`, 3 %) when they are due. All in the send's transaction and
 * idempotent with it (a replayed send never reaches this; a second call fails on the ledger's unique key).
 */
export async function creditGiftCherriesIn(
  tx: Tx,
  giftId: string,
  now: Date,
  rules: EconomyRules,
  timeZone: string,
): Promise<GiftCherryCredit> {
  const rows = await tx.$queryRaw<{ user_id: string; coins: bigint; share_bps: number }[]>`
    SELECT gr.user_id::text AS user_id, gr.coins, g.host_share_bps AS share_bps
      FROM live_gift_recipients gr
      JOIN live_gifts g ON g.id = gr.gift_id
     WHERE gr.gift_id = ${giftId}::uuid
     ORDER BY gr.user_id`;
  const recipients = rows
    .map((r) => ({ userId: r.user_id, cherries: giftCherries(r.coins, r.share_bps, rules.cherriesPerCoin) }))
    .filter((r) => r.cherries > 0n);
  if (recipients.length === 0) return { recipients: [], commissions: [] };

  const links = await tx.$queryRaw<
    {
      link_id: string;
      host_user_id: string;
      agency_id: string;
      eligible: boolean;
      rank: AgencyRankValue;
      owner_id: string;
      parent_id: string | null;
      parent_rank: AgencyRankValue | null;
      parent_owner_id: string | null;
    }[]
  >`
    SELECT ah.id::text AS link_id, ah.host_user_id::text AS host_user_id, a.id::text AS agency_id,
           ah.commission_eligible AS eligible, a.rank::text AS rank, a.owner_user_id::text AS owner_id,
           p.id::text AS parent_id, p.rank::text AS parent_rank, p.owner_user_id::text AS parent_owner_id
      FROM agency_hosts ah
      JOIN agencies a ON a.id = ah.agency_id
      LEFT JOIN agencies p ON p.id = a.parent_agency_id
     WHERE ah.status = 'ACTIVE' AND ah.host_user_id = ANY(${recipients.map((r) => r.userId)}::uuid[])`;

  const movements: Movement[] = recipients.map((r) => ({
    userId: r.userId,
    reason: 'GIFT_RECEIVED',
    delta: r.cherries,
  }));
  if (links.length > 0) {
    const month = monthKey(now, timeZone);
    const previous = addMonths(month, -1);
    const agencyIds = [...new Set(links.map((l) => l.agency_id))];
    const prevRows = await tx.$queryRaw<{ agency_id: string; host_cherries: bigint }[]>`
      SELECT agency_id::text AS agency_id, host_cherries FROM agency_months
       WHERE month = ${previous}::date AND agency_id = ANY(${agencyIds}::uuid[])`;
    const prevTotals = new Map(prevRows.map((r) => [r.agency_id, r.host_cherries]));
    const byHost = new Map(recipients.map((r) => [r.userId, r.cherries]));
    const totals = new Map<string, { host: bigint; commission: bigint; parent: bigint }>();
    const add = (agencyId: string, part: 'host' | 'commission' | 'parent', value: bigint) => {
      const t = totals.get(agencyId) ?? { host: 0n, commission: 0n, parent: 0n };
      t[part] += value;
      totals.set(agencyId, t);
    };
    const earnings: Prisma.AgencyEarningCreateManyInput[] = [];
    for (const l of links) {
      const hostCherries = byHost.get(l.host_user_id)!;
      // The agency's own owner never earns on a send to themselves as someone else's host (an owner cannot
      // be a host: join refuses it), so no self-commission check is needed here.
      const rate = agencyCommissionPaid(l.rank, l.eligible)
        ? agencyRateBps(prevTotals.get(l.agency_id) ?? 0n, rules)
        : 0;
      const commission = commissionOf(hostCherries, rate);
      const parentRate =
        l.parent_id !== null && parentCommissionPaid(l.parent_rank) ? rules.parentCommissionBps : 0;
      const parent = commissionOf(hostCherries, parentRate);
      earnings.push({
        id: uuidv7(),
        giftId,
        agencyId: l.agency_id,
        agencyHostId: l.link_id,
        hostUserId: l.host_user_id,
        hostCherries,
        rateBps: rate,
        commission,
        parentAgencyId: l.parent_id,
        parentRateBps: parentRate,
        parentCommission: parent,
        month: dateValue(month),
        createdAt: now,
      });
      add(l.agency_id, 'host', hostCherries);
      add(l.agency_id, 'commission', commission);
      if (l.parent_id !== null && parent > 0n) add(l.parent_id, 'parent', parent);
      if (commission > 0n)
        movements.push({ userId: l.owner_id, reason: 'AGENCY_COMMISSION', delta: commission });
      if (parent > 0n)
        movements.push({ userId: l.parent_owner_id!, reason: 'PARENT_COMMISSION', delta: parent });
    }
    await tx.agencyEarning.createMany({ data: earnings });
    await addAgencyMonthsIn(tx, month, totals);
  }
  const all = merged(movements);
  await applyMovementsIn(tx, all, giftId, now);
  return {
    recipients,
    commissions: all
      .filter((m) => m.reason !== 'GIFT_RECEIVED')
      .map((m) => ({ userId: m.userId, reason: m.reason, cherries: m.delta })),
  };
}

/** Adds (or, negative, subtracts) month totals per agency in one sorted upsert. */
async function addAgencyMonthsIn(
  tx: Tx,
  month: string,
  totals: ReadonlyMap<string, { host: bigint; commission: bigint; parent: bigint }>,
): Promise<void> {
  if (totals.size === 0) return;
  const ids = [...totals.keys()].sort();
  const col = (part: 'host' | 'commission' | 'parent') => ids.map((id) => totals.get(id)![part].toString());
  await tx.$executeRaw`
    INSERT INTO agency_months (agency_id, month, host_cherries, commission, parent_commission)
    SELECT t.a, ${month}::date, t.h, t.c, t.p
      FROM unnest(${ids}::uuid[], ${col('host')}::bigint[], ${col('commission')}::bigint[], ${col('parent')}::bigint[])
           AS t(a, h, c, p)
     ORDER BY t.a
    ON CONFLICT (agency_id, month) DO UPDATE
       SET host_cherries = agency_months.host_cherries + EXCLUDED.host_cherries,
           commission = agency_months.commission + EXCLUDED.commission,
           parent_commission = agency_months.parent_commission + EXCLUDED.parent_commission`;
}

const MIRROR: Readonly<Partial<Record<CherryLedgerReason, CherryLedgerReason>>> = {
  GIFT_RECEIVED: 'GIFT_REVERSAL',
  AGENCY_COMMISSION: 'AGENCY_COMMISSION_REVERSAL',
  PARENT_COMMISSION: 'PARENT_COMMISSION_REVERSAL',
};

export interface GiftReversal {
  /** False: the send was reversed before (nothing changed). */
  readonly reversed: boolean;
  readonly rows: number;
  readonly cherries: bigint;
}

/**
 * An admin reversal of a send's cherries (fraud, a refunded payment): mirrors every credit the send gave
 * — the recipients' `GIFT_RECEIVED` and the agencies' commissions — as `GIFT_REVERSAL`,
 * `AGENCY_COMMISSION_REVERSAL`, `PARENT_COMMISSION_REVERSAL` rows, marks the agency rows reversed and takes
 * them out of the agencies' month totals. A balance may go below 0 (cherries already withdrawn: a debt).
 * Once only: a second call changes nothing. The sender's coins and points are not touched.
 */
export async function reverseGiftCherriesIn(tx: Tx, giftId: string, now: Date): Promise<GiftReversal> {
  const credits = await tx.cherryLedgerEntry.findMany({
    where: {
      referenceId: giftId,
      reason: { in: ['GIFT_RECEIVED', 'AGENCY_COMMISSION', 'PARENT_COMMISSION'] },
    },
    select: { userId: true, reason: true, delta: true },
    orderBy: [{ userId: 'asc' }, { reason: 'asc' }],
  });
  const done = await tx.cherryLedgerEntry.count({
    where: {
      referenceId: giftId,
      reason: { in: ['GIFT_REVERSAL', 'AGENCY_COMMISSION_REVERSAL', 'PARENT_COMMISSION_REVERSAL'] },
    },
  });
  if (credits.length === 0 || done > 0) return { reversed: false, rows: 0, cherries: 0n };
  const earnings = await tx.$queryRaw<
    {
      agency_id: string;
      parent_agency_id: string | null;
      month: string;
      host: bigint;
      commission: bigint;
      parent: bigint;
    }[]
  >`
    UPDATE agency_earnings SET reversed_at = ${now}
     WHERE gift_id = ${giftId}::uuid AND reversed_at IS NULL
    RETURNING agency_id::text AS agency_id, parent_agency_id::text AS parent_agency_id,
              to_char(month, 'YYYY-MM-DD') AS month, host_cherries AS host, commission,
              parent_commission AS parent`;
  const perMonth = new Map<string, Map<string, { host: bigint; commission: bigint; parent: bigint }>>();
  const sub = (month: string, agencyId: string, part: 'host' | 'commission' | 'parent', value: bigint) => {
    const m = perMonth.get(month) ?? new Map<string, { host: bigint; commission: bigint; parent: bigint }>();
    const t = m.get(agencyId) ?? { host: 0n, commission: 0n, parent: 0n };
    t[part] -= value;
    m.set(agencyId, t);
    perMonth.set(month, m);
  };
  for (const e of earnings) {
    sub(e.month, e.agency_id, 'host', e.host);
    sub(e.month, e.agency_id, 'commission', e.commission);
    if (e.parent_agency_id !== null && e.parent > 0n) sub(e.month, e.parent_agency_id, 'parent', e.parent);
  }
  // Plain UPDATEs in (month, agency) order (an upsert would check the negative proposed row).
  for (const month of [...perMonth.keys()].sort()) {
    const m = perMonth.get(month)!;
    for (const agencyId of [...m.keys()].sort()) {
      const t = m.get(agencyId)!;
      await tx.$executeRaw`
        UPDATE agency_months
           SET host_cherries = GREATEST(0, host_cherries + ${t.host}),
               commission = GREATEST(0, commission + ${t.commission}),
               parent_commission = GREATEST(0, parent_commission + ${t.parent})
         WHERE agency_id = ${agencyId}::uuid AND month = ${month}::date`;
    }
  }
  const movements = credits.map((c) => ({ userId: c.userId, reason: MIRROR[c.reason]!, delta: -c.delta }));
  await applyMovementsIn(tx, movements, giftId, now);
  return { reversed: true, rows: movements.length, cherries: credits.reduce((s, c) => s + c.delta, 0n) };
}

/**
 * Holds `cherries` for a withdrawal (`WITHDRAWAL_HOLD`, reference: the withdrawal): one conditional UPDATE
 * (the row lock serializes concurrent requests); null — nothing changed — when the balance less `locked`
 * (v1.53-social, D184: task cherries not unlocked yet, §10.46.1) is short.
 */
export async function holdCherriesIn(
  tx: Tx,
  userId: string,
  cherries: bigint,
  withdrawalId: string,
  now: Date,
  locked = 0n,
): Promise<bigint | null> {
  const [row] = await tx.$queryRaw<{ cherries: bigint }[]>`
    UPDATE cherry_wallets SET cherries = cherries - ${cherries}, updated_at = now()
     WHERE user_id = ${userId}::uuid AND cherries - ${locked} >= ${cherries}
    RETURNING cherries`;
  if (!row) return null;
  await tx.cherryLedgerEntry.create({
    data: {
      id: uuidv7(),
      userId,
      delta: -cherries,
      balanceAfter: row.cherries,
      reason: 'WITHDRAWAL_HOLD',
      referenceId: withdrawalId,
      createdAt: now,
    },
  });
  return row.cherries;
}

/** Gives a rejected withdrawal's cherries back (`WITHDRAWAL_REFUND`, once per withdrawal). */
export async function refundCherriesIn(
  tx: Tx,
  userId: string,
  cherries: bigint,
  withdrawalId: string,
  now: Date,
) {
  await applyMovementsIn(tx, [{ userId, reason: 'WITHDRAWAL_REFUND', delta: cherries }], withdrawalId, now);
}

/**
 * v1.53-social (D184, CONVENTIONS §10.41.3): a Task Center reward in the claim's transaction — `cherries`
 * (> 0) as one `TASK_REWARD` row. `reference` is `<task code>@<period start>` (e.g. `P_WATCH_LIVES@2026-10-30`),
 * so the ledger itself allows one credit per person, task and day (or week); a second one fails on
 * `cherry_ledger_reference_once` and rolls the claim back.
 */
export async function creditTaskCherriesIn(
  tx: Tx,
  userId: string,
  cherries: bigint,
  reference: string,
  now: Date,
): Promise<void> {
  await applyMovementsIn(tx, [{ userId, reason: 'TASK_REWARD', delta: cherries }], reference, now);
}

/** The ledger reference of a task reward: one per person, task and period. */
export function taskRewardReference(taskCode: string, periodStart: string): string {
  return `${taskCode}@${periodStart}`;
}

/**
 * v1.53-social (D184, §10.46.1): the person's task-cherry lock now — the sums of their `TASK_REWARD` rows
 * and their gift cherries (GIFT_RECEIVED + GIFT_REVERSAL) through `taskCherryLock` (the owner's $50 rule).
 */
export async function taskCherryLockIn(
  db: Pick<Tx, '$queryRaw'>,
  userId: string,
  rules: { taskCherriesUnlockGiftMinor: number; rateCherries: number; rateMinor: number },
): Promise<TaskCherryLock> {
  const [row] = await db.$queryRaw<{ task: bigint; gift: bigint }[]>`
    SELECT COALESCE(sum(delta) FILTER (WHERE reason = 'TASK_REWARD'), 0)::bigint AS task,
           COALESCE(sum(delta) FILTER (WHERE reason IN ('GIFT_RECEIVED', 'GIFT_REVERSAL')), 0)::bigint AS gift
      FROM cherry_ledger
     WHERE user_id = ${userId}::uuid AND reason IN ('TASK_REWARD', 'GIFT_RECEIVED', 'GIFT_REVERSAL')`;
  return taskCherryLock(
    row?.task ?? 0n,
    row?.gift ?? 0n,
    rules.taskCherriesUnlockGiftMinor,
    rules.rateCherries,
    rules.rateMinor,
  );
}
