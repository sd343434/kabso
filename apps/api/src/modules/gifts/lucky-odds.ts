/**
 * v1.27-live (D132, CONVENTIONS §10.27): the arithmetic of lucky gifts, as pure functions shared by
 * the configuration check (the server refuses to start on an invalid table), the API and the CLI.
 *
 * v1.30-live (D148, owner 2026-10-28): the table is configured as the chance of each multiplier
 * `m_i` in draws per million, `c_i` (`LUCKY_GIFT_CHANCES_PER_MILLION`; the D132 "shares of the
 * return" are gone), plus the per-sender guarantee ("pity"): after `N` losing draws in a row the
 * sender's next draw pays at least `×P`. The expected return of one draw, guarantee included, is
 * exact ({@link expectedReturnWithPity}) and must not exceed the configured return `R`, which is
 * also the daily protection's ceiling.
 */

/** Draws are integers in [0, LUCKY_CHANCE_SCALE): chances are "per million". */
export const LUCKY_CHANCE_SCALE = 1_000_000;
/** 100 % in basis points. */
export const BPS = 10_000;
export const LUCKY_MAX_OUTCOMES = 32;
export const LUCKY_MAX_MULTIPLIER = 10_000;
/** D148: the guarantee comes after at most this many losing draws in a row. */
export const LUCKY_MAX_PITY_AFTER = 1_000;

export interface LuckyOutcome {
  readonly multiplier: number;
  readonly chancePerMillion: number;
}

/** The validated table the server draws from. */
export interface LuckyTable {
  /** The configured return to senders (RTP), basis points (8500 = 85 %). */
  readonly rtpBps: number;
  /** The share of a lucky gift's value counted for recipients, scores and boards (1000 = 10 %). */
  readonly hostShareBps: number;
  /** Ascending by multiplier, every chance ≥ 1. */
  readonly outcomes: readonly LuckyOutcome[];
  readonly noWinChancePerMillion: number;
  /** D148: the per-sender guarantee, or null (off). */
  readonly pity: PityRule | null;
}

/**
 * D148 (owner, option B): after `after` losing draws in a row by one sender (any room, any session)
 * that sender's next draw pays at least `multiplier` (a draw that wins more pays what it won).
 */
export interface PityRule {
  readonly after: number;
  readonly multiplier: number;
}

/**
 * A percentage with at most two decimals ("85", "85.5", "10.25") as basis points, or null when the
 * text is not one.
 */
export function percentToBps(raw: string): number | null {
  const match = /^(0|[1-9][0-9]{0,2})(?:\.([0-9]{1,2}))?$/.exec(raw.trim());
  if (!match) return null;
  const whole = Number(match[1]);
  const fraction = Number((match[2] ?? '').padEnd(2, '0'));
  return whole * 100 + fraction;
}

/**
 * The table for `rtpBps`, `hostShareBps`, `multipliers`, their `chances` per million and the
 * guarantee `pity` (null: off), or every problem with them (CONVENTIONS §10.27 lists the rules;
 * the server refuses to start on any).
 */
export function luckyTable(
  rtpBps: number,
  hostShareBps: number,
  multipliers: readonly number[],
  chances: readonly number[],
  pity: PityRule | null,
): LuckyTable | string[] {
  const problems: string[] = [];
  if (!Number.isInteger(rtpBps) || rtpBps < 100 || rtpBps > 9_900) {
    problems.push('the return (RTP) must be 1–99 %');
  }
  if (!Number.isInteger(hostShareBps) || hostShareBps < 0 || hostShareBps > BPS) {
    problems.push('the host share must be 0–100 %');
  }
  if (problems.length === 0 && rtpBps + hostShareBps > BPS) {
    problems.push(
      'the return plus the host share must not pass 100 % (the platform would pay out more than it takes)',
    );
  }
  if (
    multipliers.length < 1 ||
    multipliers.length > LUCKY_MAX_OUTCOMES ||
    multipliers.some(
      (m, i) =>
        !Number.isInteger(m) || m < 2 || m > LUCKY_MAX_MULTIPLIER || (i > 0 && m <= multipliers[i - 1]!),
    )
  ) {
    problems.push(
      `the multipliers must be 1–${String(LUCKY_MAX_OUTCOMES)} strictly ascending whole numbers 2–${String(LUCKY_MAX_MULTIPLIER)}`,
    );
  }
  if (
    chances.length !== multipliers.length ||
    chances.some((c) => !Number.isInteger(c) || c < 1 || c >= LUCKY_CHANCE_SCALE)
  ) {
    problems.push('the chances must be whole numbers ≥ 1 per million, one per multiplier');
  } else if (chances.reduce((a, b) => a + b, 0) > LUCKY_CHANCE_SCALE) {
    problems.push('the winning chances add up to more than 100 %');
  }
  if (
    pity !== null &&
    (!Number.isInteger(pity.after) ||
      pity.after < 1 ||
      pity.after > LUCKY_MAX_PITY_AFTER ||
      !multipliers.includes(pity.multiplier))
  ) {
    problems.push(
      `the guarantee must come after 1–${String(LUCKY_MAX_PITY_AFTER)} losing draws and pay one of the multipliers`,
    );
  }
  if (problems.length > 0) return problems;
  const outcomes = multipliers.map((multiplier, i) => ({ multiplier, chancePerMillion: chances[i]! }));
  const total = outcomes.reduce((a, o) => a + o.chancePerMillion, 0);
  const table: LuckyTable = Object.freeze({
    rtpBps,
    hostShareBps,
    outcomes: Object.freeze(outcomes.map((o) => Object.freeze(o))),
    noWinChancePerMillion: LUCKY_CHANCE_SCALE - total,
    pity: pity === null ? null : Object.freeze({ ...pity }),
  });
  if (expectedReturnWithPity(table) > rtpBps / BPS) {
    problems.push(
      `the chances return ${(expectedReturnWithPity(table) * 100).toFixed(4)} % with the guarantee, more than the configured ${String(rtpBps / 100)} % (the daily protection would cut wins every day)`,
    );
    return problems;
  }
  return table;
}

/** The exact expected return of `table`, in basis points: Σ c_i × m_i / 100. */
export function expectedReturnBps(table: Pick<LuckyTable, 'outcomes'>): number {
  return table.outcomes.reduce((a, o) => a + o.chancePerMillion * o.multiplier, 0) / 100;
}

/**
 * D148: the exact expected return of one draw (a fraction, 0.85 = 85 %), the guarantee included.
 * A sender's losing streak `k` is a Markov chain: from `k < N` a draw loses with `q` (the no-win
 * chance) → `k + 1`, else → 0; at `k = N` the draw is guaranteed (pays `max(drawn, P)`) → 0. Its
 * stationary law is `π_k ∝ q^k` (k = 0 … N), so a draw is guaranteed with `π_N = q^N / Σ_{k≤N} q^k`
 * and returns `(1 − π_N) × Σ p_i m_i + π_N × (Σ_{m_i ≥ P} p_i m_i + P × (q + Σ_{m_i < P} p_i))`.
 */
export function expectedReturnWithPity(table: Pick<LuckyTable, 'outcomes' | 'pity'>): number {
  const p = (c: number) => c / LUCKY_CHANCE_SCALE;
  const base = table.outcomes.reduce((a, o) => a + p(o.chancePerMillion) * o.multiplier, 0);
  const pity = table.pity;
  if (pity === null) return base;
  const q = 1 - table.outcomes.reduce((a, o) => a + p(o.chancePerMillion), 0);
  let sum = 0;
  let qk = 1;
  for (let k = 0; k <= pity.after; k += 1) {
    sum += qk;
    if (k < pity.after) qk *= q;
  }
  const guaranteedShare = qk / sum;
  const below = table.outcomes
    .filter((o) => o.multiplier < pity.multiplier)
    .reduce((a, o) => a + p(o.chancePerMillion), 0);
  const above = table.outcomes
    .filter((o) => o.multiplier >= pity.multiplier)
    .reduce((a, o) => a + p(o.chancePerMillion) * o.multiplier, 0);
  const guaranteedReturn = above + pity.multiplier * (q + below);
  return (1 - guaranteedShare) * base + guaranteedShare * guaranteedReturn;
}

/** A source of uniform integers in [0, maxExclusive); production: `crypto.randomInt` (lucky-rng.ts). */
export interface LuckyRng {
  int(maxExclusive: number): number;
}

/** The multiplier a uniform draw `r` in [0, 10^6) lands on, or 0 (no win). */
export function outcomeOf(table: Pick<LuckyTable, 'outcomes'>, r: number): number {
  let edge = 0;
  for (const o of table.outcomes) {
    edge += o.chancePerMillion;
    if (r < edge) return o.multiplier;
  }
  return 0;
}

/** Draws `draws` times; returns only the winning draws, `[index, multiplier]`, in draw order. */
export function drawWinners(
  table: Pick<LuckyTable, 'outcomes'>,
  draws: number,
  rng: LuckyRng,
): [number, number][] {
  const winners: [number, number][] = [];
  for (let i = 0; i < draws; i += 1) {
    const m = outcomeOf(table, rng.int(LUCKY_CHANCE_SCALE));
    if (m > 0) winners.push([i, m]);
  }
  return winners;
}

/**
 * The daily budget still available: `floor(spend × R_bps / 10^4) − paid`, never below 0 (a lower
 * return configured during a day can leave the day already above its new budget).
 */
export function budgetLeft(spend: bigint, paid: bigint, rtpBps: number): bigint {
  const left = (spend * BigInt(rtpBps)) / BigInt(BPS) - paid;
  return left > 0n ? left : 0n;
}

/**
 * One draw as audited: `[index, drawn multiplier, paid multiplier]`. Paid below drawn: cut by the
 * daily protection (0: nothing); paid above drawn (drawn 0 or a smaller win): the D148 guarantee.
 */
export type AuditedWin = [number, number, number];

export interface CappedWins {
  readonly wins: AuditedWin[];
  readonly coinsWon: bigint;
  /** Draws paid less than they were due (or nothing) because of the daily protection. */
  readonly downgraded: number;
  readonly budgetAfter: bigint;
}

export interface SettledDraws extends CappedWins {
  /** D148: draws the guarantee paid (paid above drawn). */
  readonly guaranteed: number;
  /** D148: the sender's losing draws in a row after this send. */
  readonly lossesAfter: number;
}

/** The largest of `ascending` ≤ `due` whose coins fit in `left`, or 0. */
function largestFitting(ascending: readonly number[], due: number, unit: bigint, left: bigint): number {
  for (let i = ascending.length - 1; i >= 0; i -= 1) {
    const m = ascending[i]!;
    if (m <= due && BigInt(m) * unit <= left) return m;
  }
  return 0;
}

/**
 * Settles the `draws` of one send in draw order (§10.27, D148). A draw is due its drawn multiplier
 * (0 when it lost) — or at least `pity.multiplier` when the sender already lost `pity.after` draws
 * in a row (`lossesBefore`, then counted on through the send). The daily protection then pays the
 * largest multiplier ≤ the due one that fits in `budget`, or 0. A draw that paid something resets
 * the streak; one that paid 0 (a loss, or a win or guarantee the budget could not pay) extends it,
 * so a guarantee that did not fit stays due on the next draw.
 */
export function settleDraws(
  winners: readonly (readonly [number, number])[],
  draws: number,
  unitPrice: number,
  multipliers: readonly number[],
  budget: bigint,
  pity: PityRule | null,
  lossesBefore: number,
): SettledDraws {
  const ascending = [...multipliers].sort((a, b) => a - b);
  const unit = BigInt(unitPrice);
  const drawn = new Map<number, number>(winners.map(([i, m]) => [i, m]));
  let left = budget;
  let coinsWon = 0n;
  let downgraded = 0;
  let guaranteed = 0;
  let losses = lossesBefore;
  const wins: AuditedWin[] = [];
  for (let index = 0; index < draws; index += 1) {
    const m = drawn.get(index) ?? 0;
    const due = pity !== null && losses >= pity.after && m < pity.multiplier ? pity.multiplier : m;
    if (due === 0) {
      losses += 1;
      continue;
    }
    const paid = largestFitting(ascending, due, unit, left);
    if (paid !== due) downgraded += 1;
    if (paid > 0) {
      const coins = BigInt(paid) * unit;
      left -= coins;
      coinsWon += coins;
      losses = 0;
      if (paid > m) guaranteed += 1;
    } else {
      losses += 1;
    }
    wins.push([index, m, paid]);
  }
  return { wins, coinsWon, downgraded, budgetAfter: left, guaranteed, lossesAfter: losses };
}

/**
 * The daily protection alone (no guarantee): pays the winning draws in draw order while they fit
 * in `budget`; a draw that does not fit pays the largest smaller multiplier that fits, or 0.
 */
export function capWins(
  winners: readonly (readonly [number, number])[],
  unitPrice: number,
  multipliers: readonly number[],
  budget: bigint,
): CappedWins {
  const draws = winners.reduce((a, [i]) => Math.max(a, i + 1), 0);
  const settled = settleDraws(winners, draws, unitPrice, multipliers, budget, null, 0);
  return {
    wins: settled.wins,
    coinsWon: settled.coinsWon,
    downgraded: settled.downgraded,
    budgetAfter: settled.budgetAfter,
  };
}

/** `LuckyGiftWin`. */
export interface LuckyGiftWinDto {
  multiplier: number;
  count: number;
  coins: number;
}

/** `LuckyGiftResult` (openapi v1.27-live). */
export interface LuckyGiftResultDto {
  draws: number;
  wins: LuckyGiftWinDto[];
  coinsWon: number;
  topMultiplier: number | null;
  downgraded: number;
  /** D148: a draw of this send was paid by the guarantee (the app labels the win «ضمان»). */
  guaranteed: boolean;
}

/** The response of a lucky send from its audited draws. */
export function luckyResultDto(
  draws: number,
  wins: readonly AuditedWin[],
  unitPrice: number,
  downgraded: number,
): LuckyGiftResultDto {
  const counts = new Map<number, number>();
  for (const [, , paid] of wins) if (paid > 0) counts.set(paid, (counts.get(paid) ?? 0) + 1);
  const list = [...counts.entries()]
    .sort((a, b) => a[0] - b[0])
    .map(([multiplier, count]) => ({ multiplier, count, coins: multiplier * unitPrice * count }));
  return {
    draws,
    wins: list,
    coinsWon: list.reduce((a, w) => a + w.coins, 0),
    topMultiplier: list.length === 0 ? null : list.at(-1)!.multiplier,
    downgraded,
    guaranteed: wins.some(([, drawn, paid]) => paid > drawn),
  };
}

/** `floor(value × bps / 10^4)`: the share of a value that is counted (host share 10 %). */
export function shareOf(value: number, bps: number): number {
  // BigInt: value × bps can pass 2^53 (a send's score points × 10 000).
  return Number((BigInt(value) * BigInt(bps)) / BigInt(BPS));
}
