/**
 * Pure rules of the Me hub's programs (v1.44-social, D166, CONVENTIONS §10.41), shared by the API and
 * the admin CLIs (no Nest dependencies) and unit-tested in programs-rules.spec.ts.
 */

/** The check-in cycle: every 7th day in a row adds the streak bonus. */
export const CHECK_IN_CYCLE_DAYS = 7;

/** A live counts for the «watch a live» task after this much watching in it. */
export const WATCH_LIVE_MIN_MS = 15_000;

/** An event's leaderboard shows (and freezes) at most this many people. */
export const EVENT_LEADERBOARD_MAX = 100;

/** The task metrics (`task_definitions.metric`, CHECK `task_definitions_shape`). D176 adds the
 * daily pool's metrics after the D166 ones (CONVENTIONS §10.41.1). */
export const TASK_METRICS = [
  'WATCH_LIVES',
  'FOLLOWS',
  'LIVE_CHAT_MESSAGES',
  'GIFT_SENDS',
  'HOST_LIVE_MINUTES',
  'HOST_GIFT_COINS',
  // v1.50-social (D176)
  'WATCH_MINUTES',
  'AUDIO_ROOMS',
  'LIVE_TAPS',
  'NEW_HOST_GIFTS',
  'POSTS',
  'REELS',
  'STORIES',
  'POST_COMMENTS',
  'DM_FRIENDS',
  'DM_VOICE_MESSAGES',
  'HOST_GIFTS_RECEIVED',
  'HOST_GUESTS',
  // v1.57-social (D188): the coin value of the paid gifts the caller sent (stored gift rows).
  'GIFT_COINS_SENT',
] as const;

/**
 * v1.57-social (D188): the metrics whose target is a coin value (gifts sent or received, from the
 * stored gift rows), so `task-admin` shows the target's retail value next to it.
 */
export const COIN_VALUE_METRICS: readonly TaskMetric[] = ['GIFT_COINS_SENT', 'HOST_GIFT_COINS'];

/** A host counts as new for «ادعم مضيفاً جديداً» this many days after the hosting permission. */
export const NEW_HOST_DAYS = 30;
export type TaskMetric = (typeof TASK_METRICS)[number];

export function isTaskMetric(value: string): value is TaskMetric {
  return (TASK_METRICS as readonly string[]).includes(value);
}

/** The place (1…7) of the check-in that makes `streak` days in a row. */
export function checkInCycleDay(streak: number): number {
  return ((Math.max(1, streak) - 1) % CHECK_IN_CYCLE_DAYS) + 1;
}

/** A check-in's coins before the daily cap: the base, plus the bonus on the 7th day of a cycle. */
export function checkInReward(streak: number, base: number, bonus: number): number {
  return base + (checkInCycleDay(streak) === CHECK_IN_CYCLE_DAYS ? bonus : 0);
}

/** What a reward pays under the daily cap: all of it, what is left of the cap, or 0. */
export function cappedReward(reward: number, cap: number, alreadyToday: number): number {
  return Math.max(0, Math.min(reward, cap - alreadyToday));
}

/**
 * v1.57-social (D188): the monthly task-cherry cap — `capMinor` minor units of the payout currency at
 * `CHERRY_PAYOUT_RATE` (`rateCherries` cherries = `rateMinor` minor units), floored; 0 = no monthly cap.
 * Owner: $5 at $1.10 per 1 000 000 → 4 545 454.
 */
export function monthlyCapCherries(capMinor: number, rateCherries: number, rateMinor: number): number {
  if (capMinor <= 0) return 0;
  return Number((BigInt(capMinor) * BigInt(rateCherries)) / BigInt(rateMinor));
}

/**
 * v1.57-social (D188): what a claim pays under both caps — the daily cap (daily tasks only, null for a
 * weekly task) and the monthly cap (0 = none), daily and weekly together. `cap` says which cap stopped
 * it when it pays 0 (the monthly one first: it is the one that lasts).
 */
export function cappedTaskReward(
  reward: number,
  daily: { cap: number; earned: number } | null,
  monthly: { cap: number; earned: number },
): { pay: number; cap: 'MONTHLY' | 'DAILY' | null } {
  let pay = reward;
  if (monthly.cap > 0) {
    pay = cappedReward(pay, monthly.cap, monthly.earned);
    if (pay === 0) return { pay, cap: 'MONTHLY' };
  }
  if (daily) {
    pay = cappedReward(pay, daily.cap, daily.earned);
    if (pay === 0) return { pay, cap: 'DAILY' };
  }
  return { pay, cap: null };
}

/** A `cherries:minor` payout rate (`CHERRY_PAYOUT_RATE`), or null when malformed. */
export function parsePayoutRate(raw: string): { cherries: number; minor: number } | null {
  const m = /^([1-9][0-9]{0,12}):([1-9][0-9]{0,6})$/.exec(raw.trim());
  return m ? { cherries: Number(m[1]), minor: Number(m[2]) } : null;
}

/** v1.57-social (D188): `cherries` in US dollars at the payout rate (for `task-admin`), e.g. `$0.0011`. */
export function cherriesUsd(cherries: number, rate: { cherries: number; minor: number }): string {
  return usd((cherries * rate.minor) / rate.cherries / 100);
}

/** v1.57-social (D188): `coins` at the retail price (`COIN_RETAIL_USD_PER_MILLION`), e.g. `$1.25`. */
export function coinsUsd(coins: number, usdPerMillion: number): string {
  return usd((coins * usdPerMillion) / 1_000_000);
}

/** Dollars with cents from $1, else 3 significant digits (rewards are small: `$0.0011`). */
function usd(value: number): string {
  if (value === 0) return '$0';
  if (value >= 1) return `$${value.toFixed(2)}`;
  return `$${Number(value.toPrecision(3)).toString()}`;
}

/** The SVIP tier (0 = none) that `spent` coins reach with the ascending `thresholds`. */
export function svipTierFor(spent: number, thresholds: readonly number[]): number {
  let tier = 0;
  for (const [i, t] of thresholds.entries()) if (spent >= t) tier = i + 1;
  return tier;
}

/** One prize line of an event: ranks `rankFrom`…`rankTo` each get `coins`. */
export interface EventPrize {
  readonly rankFrom: number;
  readonly rankTo: number;
  readonly coins: number;
}

/**
 * Parses an event's prizes (`events.prizes`): ranks 1…100, lines in order and not overlapping, coins
 * 1 … 10^8. Returns null when the value is not such a list.
 */
export function parseEventPrizes(value: unknown): EventPrize[] | null {
  if (!Array.isArray(value) || value.length > EVENT_LEADERBOARD_MAX) return null;
  const out: EventPrize[] = [];
  for (const item of value as unknown[]) {
    if (typeof item !== 'object' || item === null) return null;
    const { rankFrom, rankTo, coins } = item as Record<string, unknown>;
    if (
      !Number.isInteger(rankFrom) ||
      !Number.isInteger(rankTo) ||
      !Number.isInteger(coins) ||
      (rankFrom as number) < 1 ||
      (rankTo as number) < (rankFrom as number) ||
      (rankTo as number) > EVENT_LEADERBOARD_MAX ||
      (coins as number) < 1 ||
      (coins as number) > 100_000_000
    ) {
      return null;
    }
    const prev = out.at(-1);
    if (prev && (rankFrom as number) <= prev.rankTo) return null;
    out.push({ rankFrom: rankFrom as number, rankTo: rankTo as number, coins: coins as number });
  }
  return out;
}

/**
 * Parses the CLI's prize text: `1:5000,2:3000,3-10:500` (a rank or a range, then the coins each).
 * Null when it is malformed.
 */
export function parsePrizeText(text: string): EventPrize[] | null {
  if (text.trim() === '') return [];
  const lines = text.split(',').map((part) => {
    const m = /^\s*(\d{1,3})(?:\s*-\s*(\d{1,3}))?\s*:\s*(\d{1,9})\s*$/.exec(part);
    return m ? { rankFrom: Number(m[1]), rankTo: Number(m[2] ?? m[1]), coins: Number(m[3]) } : null;
  });
  if (lines.some((l) => l === null)) return null;
  return parseEventPrizes(lines);
}

/** The coins rank `rank` wins (0 when no line covers it). */
export function prizeForRank(prizes: readonly EventPrize[], rank: number): number {
  return prizes.find((p) => rank >= p.rankFrom && rank <= p.rankTo)?.coins ?? 0;
}

/**
 * A default task (the values seeded by migration 20261214100000_me_programs; v1.53-social, D184: the
 * reward in cherries). v1.57-social (D188, owner): rebalanced by migration
 * 20261231130000_task_rewards_rebalance — free actions a symbolic 300 cherries, «send gifts» a coin value
 * sent (10 000 coins → 1 000 cherries), the weekly host tasks 10 hours live → 30 000 and 5 000 000 coins
 * received → 50 000.
 */
export interface DefaultTask {
  readonly code: string;
  readonly period: 'DAILY' | 'WEEKLY';
  readonly metric: TaskMetric;
  readonly target: number;
  readonly rewardCherries: number;
  readonly audience: 'EVERYONE' | 'HOSTS';
  readonly nameAr: string;
  readonly nameEn: string;
  readonly sortOrder: number;
}

/**
 * The default tasks (owner 2026-10-29, the reference's tasks adapted to Kabso; CP-024 T7/T8 for hosts).
 * Migration 20261214100000_me_programs seeds the same rows; `task-admin seed-defaults` adds any that are
 * missing (it never changes an existing row).
 */
export const DEFAULT_TASKS: readonly DefaultTask[] = [
  {
    code: 'WATCH_LIVE',
    period: 'DAILY',
    metric: 'WATCH_LIVES',
    target: 1,
    rewardCherries: 300,
    audience: 'EVERYONE',
    nameAr: 'شاهد بثاً لمدة 15 ثانية',
    nameEn: 'Watch a live for 15 seconds',
    sortOrder: 10,
  },
  {
    code: 'FOLLOW_USERS',
    period: 'DAILY',
    metric: 'FOLLOWS',
    target: 10,
    rewardCherries: 300,
    audience: 'EVERYONE',
    nameAr: 'تابع مستخدمين آخرين',
    nameEn: 'Follow other users',
    sortOrder: 20,
  },
  {
    code: 'LIVE_CHAT',
    period: 'DAILY',
    metric: 'LIVE_CHAT_MESSAGES',
    target: 10,
    rewardCherries: 300,
    audience: 'EVERYONE',
    nameAr: 'دردش في غرفة بث',
    nameEn: 'Chat in a live room',
    sortOrder: 30,
  },
  {
    code: 'SEND_GIFTS',
    period: 'DAILY',
    metric: 'GIFT_COINS_SENT',
    target: 10_000,
    rewardCherries: 1_000,
    audience: 'EVERYONE',
    nameAr: 'أرسل هدايا بقيمة 10,000 عملة',
    nameEn: 'Send gifts worth 10,000 coins',
    sortOrder: 40,
  },
  {
    code: 'HOST_LIVE_MINUTES',
    period: 'WEEKLY',
    metric: 'HOST_LIVE_MINUTES',
    target: 600,
    rewardCherries: 30_000,
    audience: 'HOSTS',
    nameAr: 'ابثّ 10 ساعات هذا الأسبوع',
    nameEn: 'Go live for 10 hours this week',
    sortOrder: 50,
  },
  {
    code: 'HOST_GIFT_COINS',
    period: 'WEEKLY',
    metric: 'HOST_GIFT_COINS',
    target: 5_000_000,
    rewardCherries: 50_000,
    audience: 'HOSTS',
    nameAr: 'استقبل هدايا بقيمة 5,000,000 عملة هذا الأسبوع',
    nameEn: 'Receive gifts worth 5,000,000 coins this week',
    sortOrder: 60,
  },
];

// ---- The daily task pool (v1.50-social, D176, CONVENTIONS §10.41.1) ---------------------------

/** The level bands (`task_pool_bands.band`); a pool template has one target and reward per band. */
export const TASK_POOL_BANDS = 4;

/** What a pool template groups under, so a day's tasks vary (at most one per group, then two). */
export const TASK_POOL_GROUPS = ['WATCH', 'LIVE', 'SOCIAL', 'GIFT', 'CONTENT', 'MESSAGE', 'HOST'] as const;
export type TaskPoolGroup = (typeof TASK_POOL_GROUPS)[number];

/** One level band (`task_pool_bands`): from `minLevel` (the higher of Support and Charm). */
export interface TaskPoolBand {
  readonly band: number;
  readonly minLevel: number;
  /** Tasks a person in the band gets each day. */
  readonly dailyCount: number;
  /** Of those, how many are host tasks for a person with the hosting permission. */
  readonly hostCount: number;
  readonly nameAr: string;
  readonly nameEn: string;
}

/** The default bands (owner-changeable with `task-admin band`). */
export const DEFAULT_TASK_POOL_BANDS: readonly TaskPoolBand[] = [
  { band: 1, minLevel: 0, dailyCount: 6, hostCount: 2, nameAr: 'مبتدئ', nameEn: 'Starter' },
  { band: 2, minLevel: 10, dailyCount: 7, hostCount: 2, nameAr: 'نشيط', nameEn: 'Active' },
  { band: 3, minLevel: 30, dailyCount: 7, hostCount: 2, nameAr: 'متقدّم', nameEn: 'Advanced' },
  { band: 4, minLevel: 60, dailyCount: 8, hostCount: 3, nameAr: 'نخبة', nameEn: 'Elite' },
];

/** The band of `level` (0 = no level yet): the last band whose `minLevel` it reaches. */
export function bandForLevel(level: number, bands: readonly TaskPoolBand[]): TaskPoolBand {
  const sorted = [...bands].sort((a, b) => a.band - b.band);
  let found = sorted[0]!;
  for (const b of sorted) if (level >= b.minLevel) found = b;
  return found;
}

/** A pool template as the assignment sees it. */
export interface PoolTemplate {
  readonly code: string;
  readonly group: string;
  readonly audience: 'EVERYONE' | 'HOSTS';
  /** One per band; 0 = not offered in that band. */
  readonly bandTargets: readonly number[];
  readonly bandRewards: readonly number[];
  readonly sortOrder: number;
}

/** One of a person's tasks for a day. */
export interface PoolPick {
  readonly code: string;
  readonly target: number;
  readonly rewardCherries: number;
  readonly position: number;
}

/** 32-bit FNV-1a of `text` (the seed of a person's day). */
export function seedOf(text: string): number {
  let h = 0x811c9dc5;
  for (let i = 0; i < text.length; i++) {
    h ^= text.charCodeAt(i);
    h = Math.imul(h, 0x01000193) >>> 0;
  }
  return h >>> 0;
}

/** mulberry32: a small deterministic generator in [0, 1). */
function generator(seed: number): () => number {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

/**
 * A person's daily tasks: deterministic for `seed` (the person and the day), from the templates
 * offered in `band` (target > 0). Hosts get up to `band.hostCount` host tasks first; then
 * everyone's tasks fill up to `band.dailyCount`, at most one per group, then at most two (variety),
 * never the same template twice. Shown host tasks first, then in the order picked.
 */
export function assignDailyTasks(
  templates: readonly PoolTemplate[],
  band: TaskPoolBand,
  isHost: boolean,
  seed: number,
): PoolPick[] {
  const i = band.band - 1;
  const offered = [...templates]
    .filter((t) => (t.bandTargets[i] ?? 0) > 0 && (t.bandRewards[i] ?? 0) > 0)
    .filter((t) => t.audience === 'EVERYONE' || isHost)
    .sort((a, b) => a.sortOrder - b.sortOrder || (a.code < b.code ? -1 : a.code > b.code ? 1 : 0));
  // Fisher–Yates with the seeded generator (the input order is fixed first, so the result is too).
  const random = generator(seed);
  for (let k = offered.length - 1; k > 0; k--) {
    const j = Math.floor(random() * (k + 1));
    [offered[k], offered[j]] = [offered[j]!, offered[k]!];
  }
  const picked: PoolTemplate[] = [];
  const perGroup = new Map<string, number>();
  const take = (pool: readonly PoolTemplate[], limit: number, groupMax: number) => {
    for (const t of pool) {
      if (picked.length >= limit) return;
      if (picked.includes(t) || (perGroup.get(t.group) ?? 0) >= groupMax) continue;
      picked.push(t);
      perGroup.set(t.group, (perGroup.get(t.group) ?? 0) + 1);
    }
  };
  const hostPool = offered.filter((t) => t.audience === 'HOSTS');
  const everyonePool = offered.filter((t) => t.audience === 'EVERYONE');
  if (isHost) {
    const hostLimit = Math.min(band.hostCount, band.dailyCount);
    // Host tasks are all one group: vary them by template only.
    for (const t of hostPool) if (picked.length < hostLimit) picked.push(t);
  }
  take(everyonePool, band.dailyCount, 1);
  take(everyonePool, band.dailyCount, 2);
  take(everyonePool, band.dailyCount, Number.MAX_SAFE_INTEGER);
  return picked.map((t, position) => ({
    code: t.code,
    target: t.bandTargets[i]!,
    rewardCherries: t.bandRewards[i]!,
    position,
  }));
}

/** A default pool template (seeded by migration 20261230090000_daily_task_pool). */
export interface DefaultPoolTask {
  readonly code: string;
  readonly metric: TaskMetric;
  readonly group: TaskPoolGroup;
  readonly audience: 'EVERYONE' | 'HOSTS';
  readonly bandTargets: readonly [number, number, number, number];
  readonly bandRewards: readonly [number, number, number, number];
  readonly nameAr: string;
  readonly nameEn: string;
  readonly sortOrder: number;
  /** v1.57-social (D188): false = seeded switched off (default true). */
  readonly enabled?: boolean;
}

/**
 * The default daily pool (owner 2026-10-30: «أريد أن تصنع الكثير من المهام اليومية، ترسل لكل شخص
 * بناءً على مستواه»). Only what the server can count from stored data. Left out: sharing a room (a
 * share is a link copied on the phone), recharging (no purchases, B5), and anything the app would
 * have to report. Rewards were coins (owner 2026-10-30: «العملات فقط»); v1.53-social (D184, owner) pays
 * them in cherries (1 coin = 10 cherries: every reward ×10, migration 20261231110000_task_cherries), then
 * the owner raised them ×300 (migration 20261231120000_task_rewards_raise). v1.57-social (D188, owner:
 * the ×300 came from wrong pricing — 1 000 000 coins = $12.50 retail, 1 000 000 cherries = $1.10 payout):
 * free actions pay a symbolic 300 → 1 000 cherries (band 1 → 4); tasks with money behind them have
 * coin-value targets (gifts sent, gifts received — stored gift rows, never reported) and pay at most
 * about 1 % of that value; «send a gift» (one gift of any price) is switched off (its coin-value form
 * stays for the team). Migration 20261231130000_task_rewards_rebalance. Targets and rewards are per band
 * 1…4; 0 = not offered in that band. Owner-changeable with `task-admin`.
 */
export const DEFAULT_POOL_TASKS: readonly DefaultPoolTask[] = [
  {
    code: 'P_WATCH_LIVES',
    metric: 'WATCH_LIVES',
    group: 'WATCH',
    audience: 'EVERYONE',
    bandTargets: [1, 2, 3, 5],
    bandRewards: [300, 500, 750, 1_000],
    nameAr: 'شاهد بثوثاً لمدة 15 ثانية',
    nameEn: 'Watch lives for 15 seconds',
    sortOrder: 100,
  },
  {
    code: 'P_WATCH_MINUTES',
    metric: 'WATCH_MINUTES',
    group: 'WATCH',
    audience: 'EVERYONE',
    bandTargets: [5, 15, 30, 30],
    bandRewards: [300, 500, 750, 1_000],
    nameAr: 'شاهد البث (بالدقائق)',
    nameEn: 'Watch lives (minutes)',
    sortOrder: 110,
  },
  {
    code: 'P_AUDIO_ROOMS',
    metric: 'AUDIO_ROOMS',
    group: 'WATCH',
    audience: 'EVERYONE',
    bandTargets: [1, 2, 3, 3],
    bandRewards: [300, 500, 750, 1_000],
    nameAr: 'ادخل غرفاً صوتية',
    nameEn: 'Join audio rooms',
    sortOrder: 120,
  },
  {
    code: 'P_LIVE_COMMENTS',
    metric: 'LIVE_CHAT_MESSAGES',
    group: 'LIVE',
    audience: 'EVERYONE',
    bandTargets: [3, 5, 10, 20],
    bandRewards: [300, 500, 750, 1_000],
    nameAr: 'علّق في بث مباشر',
    nameEn: 'Comment in a live',
    sortOrder: 200,
  },
  {
    code: 'P_LIVE_TAPS',
    metric: 'LIVE_TAPS',
    group: 'LIVE',
    audience: 'EVERYONE',
    bandTargets: [20, 50, 100, 200],
    bandRewards: [300, 500, 750, 1_000],
    nameAr: 'أرسل قلوباً في بث مباشر',
    nameEn: 'Send hearts in a live',
    sortOrder: 210,
  },
  {
    code: 'P_FOLLOW',
    metric: 'FOLLOWS',
    group: 'SOCIAL',
    audience: 'EVERYONE',
    bandTargets: [1, 3, 5, 10],
    bandRewards: [300, 500, 750, 1_000],
    nameAr: 'تابع مستخدمين آخرين',
    nameEn: 'Follow other users',
    sortOrder: 300,
  },
  {
    code: 'P_POST_COMMENTS',
    metric: 'POST_COMMENTS',
    group: 'SOCIAL',
    audience: 'EVERYONE',
    bandTargets: [1, 3, 5, 10],
    bandRewards: [300, 500, 750, 1_000],
    nameAr: 'علّق على منشورات الآخرين',
    nameEn: "Comment on others' posts",
    sortOrder: 310,
  },
  {
    code: 'P_SEND_GIFT',
    metric: 'GIFT_COINS_SENT',
    group: 'GIFT',
    audience: 'EVERYONE',
    bandTargets: [1_000, 2_500, 5_000, 10_000],
    bandRewards: [100, 250, 500, 1_000],
    nameAr: 'أرسل هدية (بالعملات)',
    nameEn: 'Send a gift (coins)',
    enabled: false,
    sortOrder: 400,
  },
  {
    code: 'P_SEND_GIFTS',
    metric: 'GIFT_COINS_SENT',
    group: 'GIFT',
    audience: 'EVERYONE',
    bandTargets: [10_000, 25_000, 50_000, 100_000],
    bandRewards: [1_000, 2_500, 5_000, 10_000],
    nameAr: 'أرسل هدايا (بالعملات)',
    nameEn: 'Send gifts (coins)',
    sortOrder: 410,
  },
  {
    code: 'P_NEW_HOST',
    metric: 'NEW_HOST_GIFTS',
    group: 'GIFT',
    audience: 'EVERYONE',
    bandTargets: [1, 1, 1, 2],
    bandRewards: [1_000, 2_000, 3_500, 5_000],
    nameAr: 'ادعم مضيفاً جديداً بهدية',
    nameEn: 'Support a new host with a gift',
    sortOrder: 420,
  },
  {
    code: 'P_POST',
    metric: 'POSTS',
    group: 'CONTENT',
    audience: 'EVERYONE',
    bandTargets: [1, 1, 1, 2],
    bandRewards: [300, 500, 750, 1_000],
    nameAr: 'انشر منشوراً',
    nameEn: 'Share a post',
    sortOrder: 500,
  },
  {
    code: 'P_REEL',
    metric: 'REELS',
    group: 'CONTENT',
    audience: 'EVERYONE',
    bandTargets: [0, 1, 1, 1],
    bandRewards: [0, 500, 750, 1_000],
    nameAr: 'انشر مقطع ريلز',
    nameEn: 'Share a reel',
    sortOrder: 510,
  },
  {
    code: 'P_STORY',
    metric: 'STORIES',
    group: 'CONTENT',
    audience: 'EVERYONE',
    bandTargets: [1, 1, 1, 2],
    bandRewards: [300, 500, 750, 1_000],
    nameAr: 'انشر قصة',
    nameEn: 'Share a story',
    sortOrder: 520,
  },
  {
    code: 'P_DM_FRIEND',
    metric: 'DM_FRIENDS',
    group: 'MESSAGE',
    audience: 'EVERYONE',
    bandTargets: [1, 1, 2, 3],
    bandRewards: [300, 500, 750, 1_000],
    nameAr: 'راسل صديقاً',
    nameEn: 'Message a friend',
    sortOrder: 600,
  },
  {
    code: 'P_DM_VOICE',
    metric: 'DM_VOICE_MESSAGES',
    group: 'MESSAGE',
    audience: 'EVERYONE',
    bandTargets: [1, 1, 1, 2],
    bandRewards: [300, 500, 750, 1_000],
    nameAr: 'أرسل رسالة صوتية',
    nameEn: 'Send a voice message',
    sortOrder: 610,
  },
  {
    code: 'P_HOST_LIVE_30',
    metric: 'HOST_LIVE_MINUTES',
    group: 'HOST',
    audience: 'HOSTS',
    bandTargets: [60, 80, 100, 120],
    bandRewards: [2_000, 3_000, 4_000, 5_000],
    nameAr: 'ابثّ مباشرة (بالدقائق)',
    nameEn: 'Go live (minutes)',
    sortOrder: 700,
  },
  {
    code: 'P_HOST_GIFTS',
    metric: 'HOST_GIFT_COINS',
    group: 'HOST',
    audience: 'HOSTS',
    bandTargets: [100_000, 250_000, 500_000, 1_000_000],
    bandRewards: [5_000, 10_000, 20_000, 30_000],
    nameAr: 'استقبل هدايا في بثك (بالعملات)',
    nameEn: 'Receive gifts in your live (coins)',
    sortOrder: 710,
  },
  {
    code: 'P_HOST_GUEST',
    metric: 'HOST_GUESTS',
    group: 'HOST',
    audience: 'HOSTS',
    bandTargets: [1, 1, 2, 3],
    bandRewards: [1_000, 1_500, 2_000, 3_000],
    nameAr: 'اقبل ضيفاً على مقعد',
    nameEn: 'Accept a guest on a seat',
    sortOrder: 720,
  },
];
