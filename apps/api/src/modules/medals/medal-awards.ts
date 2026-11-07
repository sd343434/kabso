import type { Prisma, PrismaClient } from '../../generated/prisma/client.js';
import { AuditAction } from '../../common/audit/audit.service.js';
import type { MedalCode, MedalMetricCode } from './medals.catalogue.js';
import { sweepRequirementMedals } from './medal-requirements.js';

type Tx = Prisma.TransactionClient;

/** One person's value of a medal metric (lives, hours, the charm level, 0/1, bullet messages). */
export interface MedalMetricValue {
  readonly userId: string;
  readonly value: number;
}

/** A medal whose level went up (`from` null: earned now). */
export interface RaisedMedalLevel {
  readonly userId: string;
  readonly medalCode: MedalCode;
  readonly from: number | null;
  readonly to: number;
}

/**
 * Raises the medal levels of every medal on `metric` for each person's current `value`, inside the caller's
 * transaction (CP-018 awards, v1.81-live D291 levels, CONVENTIONS §10.21 / §10.104). For each medal it takes the
 * highest level of `medal_levels` whose threshold the value reaches; a person without the medal earns it at that level,
 * one who holds a lower level moves up, and a level is **never lowered** (`WHERE user_medals.level < EXCLUDED.level`;
 * a lower value, a raised threshold or a repeated call change nothing). Set-based: one statement for the whole batch
 * (a sweeper batch of hundreds of hosts stays cheap). Each change gets, unless switched off:
 * - a `MEDAL_AWARDED` notification with `medal_level` = the new level (1 = earned; more = a level-up);
 * - an audit row `medals.level_up` when a level above 1 is reached (system; target the user).
 * Shared by the API and `medals-admin` (no Nest dependencies). Returns the changes.
 *
 * D300 (§10.111): `medalCode` limits the raise to one medal of the metric (each multi-requirement medal on
 * `ALL_REQUIREMENTS` has its own value per person); `details` adds each person's requirement values to the audit rows.
 */
export async function raiseMedalLevelsIn(
  tx: Tx,
  metric: MedalMetricCode,
  values: readonly MedalMetricValue[],
  options: {
    readonly at?: Date;
    readonly notify?: boolean;
    readonly via?: string;
    readonly medalCode?: MedalCode;
    readonly details?: ReadonlyMap<string, Readonly<Record<string, number>>>;
  } = {},
): Promise<RaisedMedalLevel[]> {
  const wanted = values.filter((v) => Number.isFinite(v.value) && v.value > 0);
  if (wanted.length === 0) return [];
  const at = options.at ?? new Date();
  const rows = await tx.$queryRaw<
    { user_id: string; medal_code: MedalCode; level: number; from_level: number | null }[]
  >`
    WITH v AS (
      SELECT DISTINCT ON (t.user_id) t.user_id, t.value
        FROM unnest(${wanted.map((w) => w.userId)}::uuid[], ${wanted.map((w) => w.value)}::float8[]) AS t(user_id, value)
       ORDER BY t.user_id, t.value DESC
    ), reached AS (
      SELECT v.user_id, l.medal_code, max(l.level)::int AS level
        FROM v
        JOIN medal_levels l ON l.threshold <= v.value
        JOIN medals m ON m.code = l.medal_code AND m.metric = ${metric}::"MedalMetric" AND NOT m.retired
                     AND (${options.medalCode ?? null}::text IS NULL OR m.code = ${options.medalCode ?? null}::text)
       GROUP BY v.user_id, l.medal_code
    ), prev AS (
      SELECT u.user_id, u.medal_code, u.level::int AS level
        FROM user_medals u JOIN reached r ON r.user_id = u.user_id AND r.medal_code = u.medal_code
    ), up AS (
      INSERT INTO user_medals (user_id, medal_code, awarded_at, level, level_reached_at)
      SELECT r.user_id, r.medal_code, ${at.toISOString()}::timestamptz, r.level, ${at.toISOString()}::timestamptz
        FROM reached r
      ON CONFLICT (user_id, medal_code) DO UPDATE
        SET level = EXCLUDED.level, level_reached_at = EXCLUDED.level_reached_at
        WHERE user_medals.level < EXCLUDED.level
      RETURNING user_id, medal_code, level::int AS level
    )
    SELECT up.user_id::text AS user_id, up.medal_code, up.level, prev.level AS from_level
      FROM up LEFT JOIN prev ON prev.user_id = up.user_id AND prev.medal_code = up.medal_code
     ORDER BY up.user_id, up.medal_code`;
  const raised: RaisedMedalLevel[] = rows.map((r) => ({
    userId: r.user_id,
    medalCode: r.medal_code,
    from: r.from_level,
    to: r.level,
  }));
  if (raised.length === 0) return raised;
  if (options.notify !== false) {
    await tx.notification.createMany({
      data: raised.map((r) => ({
        recipientId: r.userId,
        type: 'MEDAL_AWARDED' as const,
        medalCode: r.medalCode,
        medalLevel: r.to,
        createdAt: at,
        updatedAt: at,
      })),
    });
  }
  const byUser = new Map(wanted.map((w) => [w.userId, w.value]));
  const levelUps = raised.filter((r) => r.to > 1);
  if (levelUps.length > 0) {
    await tx.auditLog.createMany({
      data: levelUps.map((r) => ({
        actorUserId: null,
        action: AuditAction.MEDALS_LEVEL_UP,
        targetType: 'user',
        targetId: r.userId,
        metadata: {
          medalCode: r.medalCode,
          from: r.from,
          to: r.to,
          metric,
          value: byUser.get(r.userId) ?? null,
          ...(options.details?.has(r.userId) ? { requirements: { ...options.details.get(r.userId) } } : {}),
          via: options.via ?? 'event',
        },
        createdAt: at,
      })),
    });
  }
  return raised;
}

/**
 * Live medals for the hosts of rooms that just ended, inside the ending transaction (every path: the host, a
 * timeout, the sweeper, a suspension, an admin): `LIVES_HOSTED` (ended lives — FIRST_LIVE) and `LIVE_HOURS` (hours of
 * all ended lives — LIVE_HOURS_10 / LIVE_HOURS_100), each raised to the level those totals reach (D291). One query for
 * the totals of every host of the batch, one statement per metric.
 */
export async function awardLiveMedalsForRoomsIn(
  tx: Tx,
  roomIds: readonly string[],
  at: Date = new Date(),
): Promise<void> {
  if (roomIds.length === 0) return;
  const totals = await tx.$queryRaw<{ id: string; lives: number; hours: number }[]>`
    WITH hosts AS (
      SELECT DISTINCT host_user_id FROM live_rooms
       WHERE id = ANY(${[...new Set(roomIds)]}::uuid[]) AND status = 'ENDED'
    )
    SELECT r.host_user_id::text AS id, count(*)::int AS lives,
           (sum(extract(epoch FROM (r.ended_at - r.started_at))) / 3600)::float8 AS hours
      FROM live_rooms r JOIN hosts h ON h.host_user_id = r.host_user_id
     WHERE r.status = 'ENDED' AND r.ended_at IS NOT NULL
     GROUP BY r.host_user_id`;
  if (totals.length === 0) return;
  await raiseMedalLevelsIn(
    tx,
    'LIVES_HOSTED',
    totals.map((t) => ({ userId: t.id, value: t.lives })),
    { at },
  );
  await raiseMedalLevelsIn(
    tx,
    'LIVE_HOURS',
    totals.map((t) => ({ userId: t.id, value: t.hours })),
    { at },
  );
}

/** Charm medals for a user whose charm level is now `level` (inside the level change). */
export async function awardCharmMedalsIn(tx: Tx, userId: string, level: number | null): Promise<void> {
  if (level === null) return;
  await raiseMedalLevelsIn(tx, 'CHARM_LEVEL', [{ userId, value: level }]);
}

/** FIRST_FAMILY for people who created or joined a family (inside that change). */
export async function awardFamilyMedalsIn(tx: Tx, userIds: readonly string[], at?: Date): Promise<void> {
  await raiseMedalLevelsIn(
    tx,
    'FAMILY_JOINED',
    userIds.map((userId) => ({ userId, value: 1 })),
    { at },
  );
}

/** FIRST_CP for both partners of a couple just formed (inside that change). */
export async function awardCoupleMedalsIn(tx: Tx, userIds: readonly string[], at?: Date): Promise<void> {
  await raiseMedalLevelsIn(
    tx,
    'CP_FORMED',
    userIds.map((userId) => ({ userId, value: 1 })),
    { at },
  );
}

/** Bullet medals for a sender after a bullet message (inside the send): their bullet messages so far. */
export async function awardBulletMedalsIn(tx: Tx, userId: string, at?: Date): Promise<void> {
  const [row] = await tx.$queryRaw<{ n: number }[]>`
    SELECT count(*)::int AS n FROM live_bullets WHERE user_id = ${userId}::uuid`;
  await raiseMedalLevelsIn(tx, 'BULLETS_SENT', [{ userId, value: row?.n ?? 0 }], { at });
}

/**
 * D291 «ملوك الثروة»: adds a gift send's coin value to the sender's GIFTS_SENT_COINS total and raises the medal, inside
 * the send's own transaction — so exactly once per send (a retried send with the same `clientId` never reaches it, and a
 * failed send rolls it back). Owner: «اي هدية مرسلة لاي مستخدم الا هدايا فئة الحظ» — every gift path calls it (a live,
 * video or audio; a direct conversation; a CP gift); the callers skip lucky gifts. Returns the new total.
 */
export async function addGiftsSentIn(
  tx: Tx,
  userId: string,
  coins: bigint,
  at: Date = new Date(),
): Promise<bigint> {
  return addMetricTotalIn(tx, 'GIFTS_SENT_COINS', userId, coins, at);
}

/**
 * D291 «سيد الحظ» (owner: «يتم احتساب من مجموع هدايا الحظ التي قام بإرسالها»): adds a LUCKY send's coin value (never the
 * winnings) to the sender's LUCKY_GIFTS_SENT_COINS total and raises the medal, in the send's own transaction — once per
 * send. Every lucky path calls it (a live; a direct conversation). Returns the new total.
 */
export async function addLuckyGiftsSentIn(
  tx: Tx,
  userId: string,
  coins: bigint,
  at: Date = new Date(),
): Promise<bigint> {
  return addMetricTotalIn(tx, 'LUCKY_GIFTS_SENT_COINS', userId, coins, at);
}

/** A running metric total (`medal_metric_totals`, BIGINT) plus `coins`, then the medal levels it reaches. */
async function addMetricTotalIn(
  tx: Tx,
  metric: 'GIFTS_SENT_COINS' | 'LUCKY_GIFTS_SENT_COINS',
  userId: string,
  coins: bigint,
  at: Date,
): Promise<bigint> {
  if (coins <= 0n) return 0n;
  const [row] = await tx.$queryRaw<{ value: bigint }[]>`
    INSERT INTO medal_metric_totals (user_id, metric, value, updated_at)
    VALUES (${userId}::uuid, ${metric}::"MedalMetric", ${coins}, ${at.toISOString()}::timestamptz)
    ON CONFLICT (user_id, metric) DO UPDATE
      SET value = medal_metric_totals.value + EXCLUDED.value, updated_at = EXCLUDED.updated_at
    RETURNING value`;
  const total = row?.value ?? coins;
  await raiseMedalLevelsIn(tx, metric, [{ userId, value: Number(total) }], { at });
  return total;
}

/**
 * D300 «لاعب الأحكام» (owner: «عندما يكون نقاط PK تحدي = 1500 / 3000 / 5000 / 20000»): raises the host's DARES_PLAYER
 * level to what their PK points total (`pk_host_records.points`, every PK type) reaches now, in the transaction that
 * wrote the points (`addPkPointsIn`). A total that fell (a refused dare) never lowers a level.
 */
export async function awardPkMedalsIn(tx: Tx, hostId: string, points: number, at?: Date): Promise<void> {
  await raiseMedalLevelsIn(tx, 'PK_POINTS', [{ userId: hostId, value: points }], { at });
}

/**
 * Every person's current value of each medal metric (the backfill's input, D291): hosts' ended lives and hours,
 * charm levels reached, family members, partners of every couple ever formed, bullet senders and their counts.
 */
export async function allMedalMetricValues(
  db: Pick<PrismaClient, '$queryRaw'>,
): Promise<Record<MedalMetricCode, MedalMetricValue[]>> {
  const hosts = await db.$queryRaw<{ id: string; lives: number; hours: number }[]>`
    SELECT host_user_id::text AS id, count(*)::int AS lives,
           (sum(extract(epoch FROM (ended_at - started_at))) / 3600)::float8 AS hours
      FROM live_rooms WHERE status = 'ENDED' AND ended_at IS NOT NULL GROUP BY host_user_id`;
  const charm = await db.$queryRaw<{ id: string; level: number }[]>`
    SELECT s.user_id::text AS id, s.current_level AS level
      FROM user_level_states s JOIN level_categories c ON c.id = s.category_id
     WHERE c.code = 'ATTRACTIVENESS' AND s.current_level IS NOT NULL`;
  const members = await db.$queryRaw<
    { id: string }[]
  >`SELECT DISTINCT user_id::text AS id FROM family_members`;
  const partners = await db.$queryRaw<{ id: string }[]>`
    SELECT user_a_id::text AS id FROM cp_couples UNION SELECT user_b_id::text FROM cp_couples`;
  const senders = await db.$queryRaw<{ id: string; n: number }[]>`
    SELECT user_id::text AS id, count(*)::int AS n FROM live_bullets GROUP BY user_id`;
  // D291 (owner: «اي هدية مرسلة لاي مستخدم الا هدايا فئة الحظ»): every gift sent to anyone — in a live (video or
  // audio, to the host or seat guests), in a direct conversation (both in `live_gifts`), and CP gifts (`cp_gifts`) —
  // lucky gifts excluded. Every row is a completed send (a failed send rolls back; gifts are never refunded).
  const givers = await db.$queryRaw<{ id: string; coins: bigint }[]>`
    SELECT id, sum(coins)::bigint AS coins FROM (
      SELECT lg.sender_id::text AS id, lg.total_coins AS coins
        FROM live_gifts lg JOIN gifts g ON g.code = lg.gift_code
       WHERE g.category <> 'LUCKY' AND lg.total_coins > 0
      UNION ALL
      SELECT sender_id::text, amount::bigint FROM cp_gifts WHERE amount > 0
    ) s GROUP BY id`;
  // D291 «سيد الحظ»: lucky gifts sent (any path, any recipient) at their coin value; the winnings are elsewhere.
  const luckyGivers = await db.$queryRaw<{ id: string; coins: bigint }[]>`
    SELECT lg.sender_id::text AS id, sum(lg.total_coins)::bigint AS coins
      FROM live_gifts lg JOIN gifts g ON g.code = lg.gift_code
     WHERE g.category = 'LUCKY' AND lg.total_coins > 0
     GROUP BY lg.sender_id`;
  const pk = await db.$queryRaw<{ id: string; points: number }[]>`
    SELECT host_id::text AS id, points FROM pk_host_records WHERE points > 0`;
  return {
    LIVES_HOSTED: hosts.map((h) => ({ userId: h.id, value: h.lives })),
    LIVE_HOURS: hosts.map((h) => ({ userId: h.id, value: h.hours })),
    CHARM_LEVEL: charm.map((c) => ({ userId: c.id, value: c.level })),
    FAMILY_JOINED: members.map((m) => ({ userId: m.id, value: 1 })),
    CP_FORMED: partners.map((p) => ({ userId: p.id, value: 1 })),
    BULLETS_SENT: senders.map((s) => ({ userId: s.id, value: s.n })),
    GIFTS_SENT_COINS: givers.map((g) => ({ userId: g.id, value: Number(g.coins) })),
    LUCKY_GIFTS_SENT_COINS: luckyGivers.map((g) => ({ userId: g.id, value: Number(g.coins) })),
    // D300: multi-requirement medals are evaluated per medal by `sweepRequirementMedals` (backfillMedals runs it);
    // their requirement metrics carry no medal of their own.
    ALL_REQUIREMENTS: [],
    CREATOR_FOLLOWERS: [],
    CREATOR_LIKES: [],
    CREATOR_VIEWS: [],
    // D300 «لاعب الأحكام»: every host's PK points now (a negative or zero total reaches nothing).
    PK_POINTS: pk.map((r) => ({ userId: r.id, value: r.points })),
  };
}

export interface BackfillResult {
  /** Medals earned by this run, by code. */
  readonly awarded: Partial<Record<MedalCode, number>>;
  /** v1.81-live (D291): medals held before whose level this run raised, by code. */
  readonly levelUps: Partial<Record<MedalCode, number>>;
}

/** People per backfill transaction. */
const BACKFILL_CHUNK = 200;

/**
 * Awards every medal earned by past events and raises every level the current totals reach (CP-018 `medals-admin
 * backfill`; v1.81-live D291 levels). Idempotent: running it again changes nothing, and it never lowers a level. The
 * time is now; with `notify` each change also gets a notification. Each chunk of people is its own short
 * transaction. Also run after the panel lowers a threshold, so past activity reaches the new level.
 */
export async function backfillMedals(
  prisma: PrismaClient,
  options: { readonly notify?: boolean } = {},
): Promise<BackfillResult> {
  const awarded: Partial<Record<MedalCode, number>> = {};
  const levelUps: Partial<Record<MedalCode, number>> = {};
  const all = await allMedalMetricValues(prisma);
  for (const [metric, values] of Object.entries(all) as [MedalMetricCode, MedalMetricValue[]][]) {
    for (let i = 0; i < values.length; i += BACKFILL_CHUNK) {
      const chunk = values.slice(i, i + BACKFILL_CHUNK);
      const raised = await prisma.$transaction(async (tx) => {
        // D291: the running totals are set from history (idempotent; corrects any drift).
        if (metric === 'GIFTS_SENT_COINS' || metric === 'LUCKY_GIFTS_SENT_COINS') {
          await tx.$executeRaw`
            INSERT INTO medal_metric_totals (user_id, metric, value)
            SELECT t.user_id, ${metric}::"MedalMetric", t.value
              FROM unnest(${chunk.map((c) => c.userId)}::uuid[], ${chunk.map((c) => BigInt(c.value))}::bigint[])
                AS t(user_id, value)
            ON CONFLICT (user_id, metric) DO UPDATE SET value = EXCLUDED.value, updated_at = now()`;
        }
        return raiseMedalLevelsIn(tx, metric, chunk, { notify: options.notify === true, via: 'backfill' });
      });
      for (const r of raised) {
        const into = r.from === null ? awarded : levelUps;
        into[r.medalCode] = (into[r.medalCode] ?? 0) + 1;
      }
    }
  }
  // D300 (§10.111): every content creator's multi-requirement medals, counted exactly (no pre-filter).
  const creators = await sweepRequirementMedals(prisma, {
    via: 'backfill',
    prefilter: false,
    notify: options.notify === true,
  });
  for (const r of creators.raised) {
    const into = r.from === null ? awarded : levelUps;
    into[r.medalCode] = (into[r.medalCode] ?? 0) + 1;
  }
  return { awarded, levelUps };
}
