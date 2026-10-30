import { Prisma } from '../../generated/prisma/client.js';
import {
  addMonths,
  monthKey,
  nextRank,
  qualifiedRank,
  qualifiesAsAgent,
  type AgencyRankValue,
  type RankRules,
} from './economy-math.js';

type Db = Pick<Prisma.TransactionClient, '$queryRaw' | '$executeRaw'>;

/** The rules of the active-host test (owner: ≥ 7 live days and ≥ 10 live hours in the last 30 days). */
export interface ActivityRules {
  readonly activeHostMinDays: number;
  readonly activeHostMinHours: number;
  readonly activeHostWindowDays: number;
}

export interface HostActivity {
  readonly agencyId: string;
  readonly hostUserId: string;
  /** Days (in the time zone) with live time in the window. */
  readonly liveDays: number;
  /** Seconds live in the window (a live in progress up to its last heartbeat). */
  readonly liveSeconds: number;
  readonly active: boolean;
}

const DAY_MS = 86_400_000;

/**
 * The live activity of the ACTIVE hosts of `agencyIds` (all agencies when null) in the rolling window
 * ending `now`, from `live_rooms` (the host's own lives: started, ended or last heartbeat). A host whose
 * account is not ACTIVE is never an active host.
 */
export async function hostActivity(
  db: Db,
  agencyIds: readonly string[] | null,
  now: Date,
  rules: ActivityRules,
  timeZone: string,
  hostIds: readonly string[] | null = null,
): Promise<HostActivity[]> {
  const from = new Date(now.getTime() - rules.activeHostWindowDays * DAY_MS);
  const agencyFilter =
    agencyIds === null ? Prisma.empty : Prisma.sql`AND ah.agency_id = ANY(${[...agencyIds]}::uuid[])`;
  const hostFilter =
    hostIds === null ? Prisma.empty : Prisma.sql`AND ah.host_user_id = ANY(${[...hostIds]}::uuid[])`;
  const rows = await db.$queryRaw<
    { agency_id: string; host_user_id: string; user_active: boolean; secs: number; days: number }[]
  >`
    WITH h AS (
      SELECT ah.agency_id, ah.host_user_id, (u.status = 'ACTIVE') AS user_active
        FROM agency_hosts ah JOIN users u ON u.id = ah.host_user_id
       WHERE ah.status = 'ACTIVE' ${agencyFilter} ${hostFilter}),
    s AS (
      SELECT h.agency_id, h.host_user_id,
             GREATEST(r.started_at, ${from}::timestamptz) AS s,
             LEAST(COALESCE(r.ended_at, r.last_heartbeat_at), ${now}::timestamptz) AS e
        FROM h JOIN live_rooms r ON r.host_user_id = h.host_user_id
       WHERE r.started_at < ${now}::timestamptz
         AND COALESCE(r.ended_at, r.last_heartbeat_at) > ${from}::timestamptz),
    secs AS (
      SELECT agency_id, host_user_id, sum(extract(epoch FROM e - s)) AS secs
        FROM s WHERE e > s GROUP BY agency_id, host_user_id),
    days AS (
      SELECT s.agency_id, s.host_user_id, count(DISTINCT d) AS days
        FROM s, generate_series((s.s AT TIME ZONE ${timeZone}::text)::date::timestamp,
                                ((s.e - interval '1 millisecond') AT TIME ZONE ${timeZone}::text)::date::timestamp,
                                interval '1 day') AS d
       WHERE s.e > s.s
       GROUP BY s.agency_id, s.host_user_id)
    SELECT h.agency_id::text AS agency_id, h.host_user_id::text AS host_user_id, h.user_active,
           COALESCE(floor(secs.secs), 0)::int AS secs, COALESCE(days.days, 0)::int AS days
      FROM h
      LEFT JOIN secs ON secs.agency_id = h.agency_id AND secs.host_user_id = h.host_user_id
      LEFT JOIN days ON days.agency_id = h.agency_id AND days.host_user_id = h.host_user_id`;
  return rows.map((r) => ({
    agencyId: r.agency_id,
    hostUserId: r.host_user_id,
    liveDays: r.days,
    liveSeconds: r.secs,
    active: r.user_active && r.days >= rules.activeHostMinDays && r.secs >= rules.activeHostMinHours * 3600,
  }));
}

export interface AgencyStanding {
  readonly agencyId: string;
  readonly activeHosts: number;
  readonly monthHostCherries: bigint;
  readonly previousMonthHostCherries: bigint;
  readonly selfQualifies: boolean;
  readonly qualifiedSubAgencies: number;
  readonly qualified: AgencyRankValue;
}

/**
 * Where agencies stand now: active hosts, their hosts' cherries this and last month, whether each
 * qualifies as an agent (≥ 5 active hosts, or ≥ 200 000 000 cherries in the current or the last month —
 * the owner's exception) and the rank it qualifies for (ADMIN: an agent with ≥ 3 sub-agencies that
 * qualify as agents, each by the same test).
 */
export async function agencyStandings(
  db: Db,
  now: Date,
  rules: ActivityRules & RankRules,
  timeZone: string,
  only: readonly string[] | null = null,
): Promise<Map<string, AgencyStanding>> {
  const month = monthKey(now, timeZone);
  const previous = addMonths(month, -1);
  // `only`: these agencies and their sub-agencies (an agency's dashboard), else every agency.
  const scope =
    only === null
      ? Prisma.empty
      : Prisma.sql`WHERE id = ANY(${[...only]}::uuid[]) OR parent_agency_id = ANY(${[...only]}::uuid[])`;
  const agencies = await db.$queryRaw<{ id: string; parent_id: string | null }[]>`
    SELECT id::text AS id, parent_agency_id::text AS parent_id FROM agencies ${scope}`;
  const ids = only === null ? null : agencies.map((a) => a.id);
  const activity = await hostActivity(db, ids, now, rules, timeZone);
  const monthScope = ids === null ? Prisma.empty : Prisma.sql`AND agency_id = ANY(${ids}::uuid[])`;
  const months = await db.$queryRaw<{ agency_id: string; month: string; host_cherries: bigint }[]>`
    SELECT agency_id::text AS agency_id, to_char(month, 'YYYY-MM-DD') AS month, host_cherries
      FROM agency_months WHERE month IN (${month}::date, ${previous}::date) ${monthScope}`;
  const active = new Map<string, number>();
  for (const a of activity) if (a.active) active.set(a.agencyId, (active.get(a.agencyId) ?? 0) + 1);
  const cur = new Map<string, bigint>();
  const prev = new Map<string, bigint>();
  for (const m of months) (m.month === month ? cur : prev).set(m.agency_id, m.host_cherries);
  const self = new Map<string, boolean>();
  for (const a of agencies) {
    const c = cur.get(a.id) ?? 0n;
    const p = prev.get(a.id) ?? 0n;
    self.set(a.id, qualifiesAsAgent(active.get(a.id) ?? 0, c > p ? c : p, rules));
  }
  const subs = new Map<string, number>();
  for (const a of agencies) {
    if (a.parent_id !== null && self.get(a.id)) subs.set(a.parent_id, (subs.get(a.parent_id) ?? 0) + 1);
  }
  const out = new Map<string, AgencyStanding>();
  for (const a of agencies) {
    const q = self.get(a.id)!;
    const n = subs.get(a.id) ?? 0;
    out.set(a.id, {
      agencyId: a.id,
      activeHosts: active.get(a.id) ?? 0,
      monthHostCherries: cur.get(a.id) ?? 0n,
      previousMonthHostCherries: prev.get(a.id) ?? 0n,
      selfQualifies: q,
      qualifiedSubAgencies: n,
      qualified: qualifiedRank(q, n, rules),
    });
  }
  return out;
}

export interface RankChange {
  readonly agencyId: string;
  readonly from: AgencyRankValue;
  readonly to: AgencyRankValue;
  readonly monthStart: boolean;
}

/**
 * The rank evaluation (the sweeper every AGENCY_SWEEP_INTERVAL_SECONDS, and `economy-admin
 * agency-evaluate`). The first run in a month (in the time zone) is the month-start evaluation of every
 * agency past its grace: the rank becomes what it qualifies for, up or down, and is kept to the end of
 * the month. Every other run only promotes. Idempotent: running it again changes nothing.
 */
export async function evaluateAgencyRanks(
  db: Db,
  now: Date,
  rules: ActivityRules & RankRules,
  timeZone: string,
): Promise<RankChange[]> {
  const month = monthKey(now, timeZone);
  const standings = await agencyStandings(db, now, rules, timeZone);
  const agencies = await db.$queryRaw<
    { id: string; rank: AgencyRankValue; rank_month: string | null; evaluate_from: string }[]
  >`
    SELECT id::text AS id, rank::text AS rank, to_char(rank_month, 'YYYY-MM-DD') AS rank_month,
           to_char(evaluate_from, 'YYYY-MM-DD') AS evaluate_from
      FROM agencies ORDER BY id`;
  const changes: RankChange[] = [];
  for (const a of agencies) {
    const standing = standings.get(a.id);
    if (!standing) continue;
    const monthStart = a.evaluate_from <= month && (a.rank_month === null || a.rank_month < month);
    const to = nextRank(a.rank, standing.qualified, monthStart);
    if (to === a.rank && !monthStart) continue;
    await db.$executeRaw`
      UPDATE agencies
         SET rank = ${to}::agency_rank,
             rank_month = CASE WHEN ${monthStart} THEN ${month}::date ELSE rank_month END,
             updated_at = now()
       WHERE id = ${a.id}::uuid`;
    if (to !== a.rank) changes.push({ agencyId: a.id, from: a.rank, to, monthStart });
  }
  return changes;
}
