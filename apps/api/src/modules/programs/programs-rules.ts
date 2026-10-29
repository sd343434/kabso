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

/** The task metrics (`task_definitions.metric`, CHECK `task_definitions_shape`). */
export const TASK_METRICS = [
  'WATCH_LIVES',
  'FOLLOWS',
  'LIVE_CHAT_MESSAGES',
  'GIFT_SENDS',
  'HOST_LIVE_MINUTES',
  'HOST_GIFT_COINS',
] as const;
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
