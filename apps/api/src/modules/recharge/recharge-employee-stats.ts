import type { Prisma, PrismaClient } from '../../generated/prisma/client.js';
import { dayStart } from './recharge-rules.js';

/**
 * What an agent's employee did for the agent (v1.54-social D185 sales; v1.87-social D287 cherry purchases and coin
 * orders, CONVENTIONS §10.100) — today (the economy's zone), in the last 7 and 30 days, as count and coins. Shared by
 * the agent's employees screen and the admin panel's agent detail.
 */
export interface Totals {
  count: number;
  coins: number;
}
export interface SalesStatsDto {
  today: Totals;
  last7Days: Totals;
  last30Days: Totals;
}
export interface EmployeeStatsDto {
  /** Coins sold directly to buyers (D185). */
  sales: SalesStatsDto;
  /** Confirmed cherry purchases they acted on: the coins that went into the agent's stock (by the decision). */
  cherryPurchases: SalesStatsDto;
  /** Completed coin orders they owned: the coins that went to buyers (by the closing time). */
  orders: SalesStatsDto;
}

type Db = Pick<PrismaClient | Prisma.TransactionClient, '$queryRaw'>;
interface Row {
  tc: number;
  tq: bigint;
  c7: number;
  q7: bigint;
  c30: number;
  q30: bigint;
}
const DAY_MS = 86_400_000;

function stats(r: Row | undefined): SalesStatsDto {
  return {
    today: { count: r?.tc ?? 0, coins: Number(r?.tq ?? 0n) },
    last7Days: { count: r?.c7 ?? 0, coins: Number(r?.q7 ?? 0n) },
    last30Days: { count: r?.c30 ?? 0, coins: Number(r?.q30 ?? 0n) },
  };
}

export async function employeeStatsIn(
  db: Db,
  agentUserId: string,
  employeeUserId: string,
  now: Date,
  zone: string,
): Promise<EmployeeStatsDto> {
  const today = dayStart(now, zone);
  const d7 = new Date(now.getTime() - 7 * DAY_MS);
  const d30 = new Date(now.getTime() - 30 * DAY_MS);
  const [[sales], [cherry], [orders]] = await Promise.all([
    db.$queryRaw<Row[]>`
      SELECT count(*) FILTER (WHERE created_at >= ${today})::int AS tc,
             COALESCE(sum(coins) FILTER (WHERE created_at >= ${today}), 0)::bigint AS tq,
             count(*) FILTER (WHERE created_at >= ${d7})::int AS c7,
             COALESCE(sum(coins) FILTER (WHERE created_at >= ${d7}), 0)::bigint AS q7,
             count(*)::int AS c30, COALESCE(sum(coins), 0)::bigint AS q30
        FROM recharge_sales
       WHERE created_at >= ${d30} AND agent_user_id = ${agentUserId}::uuid
         AND seller_user_id = ${employeeUserId}::uuid`,
    db.$queryRaw<Row[]>`
      SELECT count(*) FILTER (WHERE decided_at >= ${today})::int AS tc,
             COALESCE(sum(coins) FILTER (WHERE decided_at >= ${today}), 0)::bigint AS tq,
             count(*) FILTER (WHERE decided_at >= ${d7})::int AS c7,
             COALESCE(sum(coins) FILTER (WHERE decided_at >= ${d7}), 0)::bigint AS q7,
             count(*)::int AS c30, COALESCE(sum(coins), 0)::bigint AS q30
        FROM recharge_cherry_requests
       WHERE acted_by = ${employeeUserId}::uuid AND agent_user_id = ${agentUserId}::uuid
         AND status = 'CONFIRMED' AND decided_at >= ${d30}`,
    db.$queryRaw<Row[]>`
      SELECT count(*) FILTER (WHERE closed_at >= ${today})::int AS tc,
             COALESCE(sum(coins) FILTER (WHERE closed_at >= ${today}), 0)::bigint AS tq,
             count(*) FILTER (WHERE closed_at >= ${d7})::int AS c7,
             COALESCE(sum(coins) FILTER (WHERE closed_at >= ${d7}), 0)::bigint AS q7,
             count(*)::int AS c30, COALESCE(sum(coins), 0)::bigint AS q30
        FROM recharge_orders
       WHERE claimed_by = ${employeeUserId}::uuid AND agent_user_id = ${agentUserId}::uuid
         AND status IN ('COMPLETED', 'COMPLETED_BY_ADMIN') AND closed_at >= ${d30}`,
  ]);
  return { sales: stats(sales), cherryPurchases: stats(cherry), orders: stats(orders) };
}
