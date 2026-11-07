import { Prisma, type PrismaClient } from '../../generated/prisma/client.js';
import { raiseMedalLevelsIn, type RaisedMedalLevel } from './medal-awards.js';
import {
  isRequirementMetric,
  levelByRequirements,
  REQUIREMENT_METRICS,
  type MedalCode,
  type MedalRequirement,
  type RequirementMetricCode,
} from './medals.catalogue.js';

/**
 * D300 (owner 2026-11-07 «مدرسة المحتوى», CONVENTIONS §10.111): multi-requirement medals — a level is reached when the
 * person has ALL of its `medal_level_requirements` at once. The medal's metric is `ALL_REQUIREMENTS`: its value is the
 * level the requirements reach (each level's `threshold` is its number), so the D291 machinery raises it unchanged
 * (`raiseMedalLevelsIn`: never lowered, notified, audited).
 *
 * The requirement metrics are a content creator's (`creator_members`, D285 / D295); nobody else is ever evaluated, so a
 * non-creator never earns or progresses, and a former creator keeps the level reached (levels never go down):
 *  - CREATOR_FOLLOWERS: followers now whose account is ACTIVE (exactly the profile's `followerCount`, D121);
 *  - CREATOR_LIKES: all-time likes on the creator's posts and reels from OTHER accounts that are ACTIVE now — posts
 *    later deleted or removed by moderation too (owner 2026-11-07: «لا» to leaving them out; their rows stay);
 *  - CREATOR_VIEWS: all-time §11.4 views of the creator's posts and reels (once per viewer and rolling 24 h) from OTHER
 *    accounts that are ACTIVE now, deleted or removed ones too — summed from `post_views.counted_views`
 *    (`posts.view_count` cannot tell who viewed; rows before D300 count once: a lower bound, owner-accepted).
 * All owner-decided 2026-11-07 (creators only; levels kept when the membership ends; posts AND reels).
 *
 * Why a sweeper and not the events: follows, likes and views are the hottest writes of the app, and the exact numbers
 * (ACTIVE accounts only, never self) are counts over every follower and like of the creator — up to millions of rows —
 * which no single follow, like or view should pay for; a denormalised counter could not follow accounts that are
 * suspended or deleted later either. So the levels are raised by `sweepRequirementMedals` every
 * `MEDAL_CREATOR_SWEEP_INTERVAL_SECONDS` (default 10 minutes) with a cheap pre-filter: three indexed aggregates per
 * creator give UPPER bounds (all follows, the posts' `like_count` and `view_count` sums); only creators whose
 * bounds reach their next level are counted exactly. Also at once where it is cheap and rare: when a person becomes a
 * creator (`activateCreatorIn`), and for history by `medals-admin backfill` (exact, no pre-filter).
 *
 * No Nest dependencies: shared by the API, the CLI and the tests.
 */

type Db = Pick<PrismaClient | Prisma.TransactionClient, '$queryRaw'>;
type Tx = Prisma.TransactionClient;

/** A creator's three requirement values. */
export type RequirementValues = Readonly<Record<RequirementMetricCode, number>>;

/** A level of a multi-requirement medal. */
export interface RequirementLevelDef {
  readonly level: number;
  readonly requirements: readonly MedalRequirement[];
}

/** A multi-requirement medal (metric `ALL_REQUIREMENTS`, not retired) with its levels, lowest first. */
export interface RequirementMedalDef {
  readonly code: MedalCode;
  readonly levels: readonly RequirementLevelDef[];
}

/** People per transaction of a sweep or a backfill. */
const CHUNK = 200;

export const ZERO_REQUIREMENT_VALUES: RequirementValues = {
  CREATOR_FOLLOWERS: 0,
  CREATOR_LIKES: 0,
  CREATOR_VIEWS: 0,
};

/** Every multi-requirement medal that is not retired, with its levels and their requirements. */
export async function requirementMedalsIn(db: Db): Promise<RequirementMedalDef[]> {
  const rows = await db.$queryRaw<
    { code: MedalCode; level: number; metric: string | null; threshold: bigint | null }[]
  >`
    SELECT m.code, l.level::int AS level, r.metric::text AS metric, r.threshold
      FROM medals m
      JOIN medal_levels l ON l.medal_code = m.code
      LEFT JOIN medal_level_requirements r ON r.medal_code = l.medal_code AND r.level = l.level
     WHERE m.metric = 'ALL_REQUIREMENTS'::"MedalMetric" AND NOT m.retired
     ORDER BY m.sort_order, m.code, l.level, r.metric`;
  const medals = new Map<MedalCode, Map<number, MedalRequirement[]>>();
  for (const r of rows) {
    const levels = medals.get(r.code) ?? new Map<number, MedalRequirement[]>();
    const reqs = levels.get(r.level) ?? [];
    if (r.metric !== null && r.threshold !== null && isRequirementMetric(r.metric)) {
      reqs.push({ metric: r.metric, threshold: Number(r.threshold) });
    }
    levels.set(r.level, reqs);
    medals.set(r.code, levels);
  }
  return [...medals].map(([code, levels]) => ({
    code,
    levels: [...levels]
      .sort((a, b) => a[0] - b[0])
      .map(([level, requirements]) => ({ level, requirements: sortRequirements(requirements) })),
  }));
}

/** Requirements in the order the app and the panel show them (followers, likes, views). */
export function sortRequirements<T extends { readonly metric: string }>(reqs: readonly T[]): T[] {
  const order = (m: string) => {
    const i = (REQUIREMENT_METRICS as readonly string[]).indexOf(m);
    return i < 0 ? REQUIREMENT_METRICS.length : i;
  };
  return [...reqs].sort((a, b) => order(a.metric) - order(b.metric));
}

function onlyCreators(userIds: readonly string[] | null): Prisma.Sql {
  return userIds === null ? Prisma.empty : Prisma.sql`AND cm.user_id = ANY(${[...userIds]}::uuid[])`;
}

/**
 * The EXACT requirement values of every content creator with an ACTIVE account among `userIds` (all creators when
 * null). People who are not creators now are absent from the map.
 */
export async function creatorRequirementValuesIn(
  db: Db,
  userIds: readonly string[] | null,
): Promise<Map<string, RequirementValues>> {
  if (userIds !== null && userIds.length === 0) return new Map();
  const rows = await db.$queryRaw<{ id: string; followers: bigint; likes: bigint; views: bigint }[]>`
    SELECT cm.user_id::text AS id,
           (SELECT count(*) FROM follows f JOIN users fu ON fu.id = f.follower_id
             WHERE f.followee_id = cm.user_id AND fu.status = 'ACTIVE'::user_status)::bigint AS followers,
           (SELECT count(*) FROM posts p
              JOIN post_likes pl ON pl.post_id = p.id
              JOIN users lu ON lu.id = pl.user_id
             WHERE p.author_id = cm.user_id
               AND pl.user_id <> p.author_id AND lu.status = 'ACTIVE'::user_status)::bigint AS likes,
           (SELECT coalesce(sum(pv.counted_views), 0) FROM posts p
              JOIN post_views pv ON pv.post_id = p.id
              JOIN users vu ON vu.id = pv.user_id
             WHERE p.author_id = cm.user_id
               AND pv.user_id <> p.author_id AND vu.status = 'ACTIVE'::user_status)::bigint AS views
      FROM creator_members cm JOIN users u ON u.id = cm.user_id
     WHERE u.status = 'ACTIVE'::user_status ${onlyCreators(userIds)}`;
  return new Map(
    rows.map((r) => [
      r.id,
      {
        CREATOR_FOLLOWERS: Number(r.followers),
        CREATOR_LIKES: Number(r.likes),
        CREATOR_VIEWS: Number(r.views),
      },
    ]),
  );
}

/**
 * UPPER bounds of the requirement values (the sweep's pre-filter): every follow (any account), all the creator's posts'
 * `like_count` and `view_count` sums (self-likes and inactive likers and viewers included) — index lookups per
 * creator. `view_count` ≥ the ACTIVE viewers' `counted_views` (both rise in the same statement).
 */
async function creatorRequirementBoundsIn(
  db: Db,
  userIds: readonly string[],
): Promise<Map<string, RequirementValues>> {
  if (userIds.length === 0) return new Map();
  const rows = await db.$queryRaw<{ id: string; followers: bigint; likes: bigint; views: bigint }[]>`
    SELECT cm.user_id::text AS id,
           (SELECT count(*) FROM follows f WHERE f.followee_id = cm.user_id)::bigint AS followers,
           (SELECT coalesce(sum(p.like_count), 0) FROM posts p WHERE p.author_id = cm.user_id)::bigint AS likes,
           (SELECT coalesce(sum(p.view_count), 0) FROM posts p WHERE p.author_id = cm.user_id)::bigint AS views
      FROM creator_members cm
     WHERE cm.user_id = ANY(${[...userIds]}::uuid[])`;
  return new Map(
    rows.map((r) => [
      r.id,
      {
        CREATOR_FOLLOWERS: Number(r.followers),
        CREATOR_LIKES: Number(r.likes),
        CREATOR_VIEWS: Number(r.views),
      },
    ]),
  );
}

/** Whether `values` meet every requirement of `level` (false for a missing level). */
function meets(medal: RequirementMedalDef, level: number, values: RequirementValues): boolean {
  const def = medal.levels.find((l) => l.level === level);
  return (
    !!def && def.requirements.length > 0 && def.requirements.every((r) => values[r.metric] >= r.threshold)
  );
}

/**
 * Raises every multi-requirement medal of the creators among `userIds` to the level their EXACT values reach, inside
 * the caller's transaction (a creator's activation). Returns the changes.
 */
export async function raiseRequirementMedalsIn(
  tx: Tx,
  userIds: readonly string[],
  options: { readonly at?: Date; readonly notify?: boolean; readonly via?: string } = {},
): Promise<RaisedMedalLevel[]> {
  if (userIds.length === 0) return [];
  const medals = await requirementMedalsIn(tx);
  if (medals.length === 0) return [];
  const values = await creatorRequirementValuesIn(tx, userIds);
  return raiseWith(tx, medals, values, options);
}

async function raiseWith(
  tx: Tx,
  medals: readonly RequirementMedalDef[],
  values: ReadonlyMap<string, RequirementValues>,
  options: { readonly at?: Date; readonly notify?: boolean; readonly via?: string },
): Promise<RaisedMedalLevel[]> {
  const raised: RaisedMedalLevel[] = [];
  for (const medal of medals) {
    const reached = [...values].map(([userId, v]) => ({
      userId,
      value: levelByRequirements(medal.levels, v),
    }));
    raised.push(
      ...(await raiseMedalLevelsIn(tx, 'ALL_REQUIREMENTS', reached, {
        ...options,
        medalCode: medal.code,
        details: values,
      })),
    );
  }
  return raised;
}

export interface RequirementSweepResult {
  /** Creators looked at (members with an ACTIVE account below the top level of some medal). */
  readonly candidates: number;
  /** Of them, those whose upper bounds reached their next level and were counted exactly. */
  readonly counted: number;
  readonly raised: readonly RaisedMedalLevel[];
}

/**
 * Raises the multi-requirement medals of every content creator (D300): the sweeper (`prefilter` on: exact counts only
 * for creators whose upper bounds reach their next level) and `medals-admin backfill` (`prefilter` off: every creator
 * counted exactly). Creators at the top level of every such medal are skipped. Each chunk of 200 creators is its own
 * short transaction; idempotent (a level never goes down; a repeat changes nothing).
 */
export async function sweepRequirementMedals(
  prisma: PrismaClient,
  options: {
    readonly at?: Date;
    readonly notify?: boolean;
    readonly via: 'sweep' | 'backfill';
    readonly prefilter: boolean;
  },
): Promise<RequirementSweepResult> {
  const medals = await requirementMedalsIn(prisma);
  if (medals.length === 0) return { candidates: 0, counted: 0, raised: [] };
  const rows = await prisma.$queryRaw<{ id: string; medal_code: string | null; level: number | null }[]>`
    SELECT cm.user_id::text AS id, um.medal_code, um.level::int AS level
      FROM creator_members cm
      JOIN users u ON u.id = cm.user_id AND u.status = 'ACTIVE'::user_status
      LEFT JOIN user_medals um ON um.user_id = cm.user_id AND um.medal_code = ANY(${medals.map((m) => m.code)}::text[])
     ORDER BY cm.user_id`;
  const held = new Map<string, Map<string, number>>();
  for (const r of rows) {
    const mine = held.get(r.id) ?? new Map<string, number>();
    if (r.medal_code !== null && r.level !== null) mine.set(r.medal_code, r.level);
    held.set(r.id, mine);
  }
  const nextOf = (userId: string, medal: RequirementMedalDef) => (held.get(userId)?.get(medal.code) ?? 0) + 1;
  const candidates = [...held.keys()].filter((id) => medals.some((m) => nextOf(id, m) <= m.levels.length));
  const at = options.at ?? new Date();
  const raised: RaisedMedalLevel[] = [];
  let counted = 0;
  for (let i = 0; i < candidates.length; i += CHUNK) {
    let chunk = candidates.slice(i, i + CHUNK);
    if (options.prefilter) {
      const bounds = await creatorRequirementBoundsIn(prisma, chunk);
      chunk = chunk.filter((id) => {
        const b = bounds.get(id);
        return !!b && medals.some((m) => meets(m, nextOf(id, m), b));
      });
    }
    if (chunk.length === 0) continue;
    counted += chunk.length;
    raised.push(
      ...(await prisma.$transaction(async (tx) => {
        const values = await creatorRequirementValuesIn(tx, chunk);
        return raiseWith(tx, medals, values, { at, notify: options.notify, via: options.via });
      })),
    );
  }
  return { candidates: candidates.length, counted, raised };
}
