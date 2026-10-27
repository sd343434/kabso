/**
 * v1.27-live (D132, CONVENTIONS §10.27): the arithmetic of lucky gifts, as pure functions shared by
 * the configuration check (the server refuses to start on an invalid table), the API and the CLI.
 *
 * The odds come from the return `R` (RTP, basis points) and the share `s_i` (whole percent, Σ = 100)
 * of `R` that each multiplier `m_i` carries: the chance of `m_i` per million draws is
 * `c_i = floor(R_bps × s_i / m_i)`, so `Σ c_i × m_i ≤ R_bps × 100` (equal when nothing rounds), i.e.
 * `Σ p_i × m_i = R` with `p_i = c_i / 10^6`. No win: `10^6 − Σ c_i`.
 */

/** Draws are integers in [0, LUCKY_CHANCE_SCALE): chances are "per million". */
export const LUCKY_CHANCE_SCALE = 1_000_000;
/** 100 % in basis points. */
export const BPS = 10_000;
export const LUCKY_MAX_OUTCOMES = 32;
export const LUCKY_MAX_MULTIPLIER = 10_000;

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
 * The table for `rtpBps`, `hostShareBps`, `multipliers` and `shares`, or every problem with them
 * (CONVENTIONS §10.27 lists the rules; the server refuses to start on any).
 */
export function luckyTable(
  rtpBps: number,
  hostShareBps: number,
  multipliers: readonly number[],
  shares: readonly number[],
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
    shares.length !== multipliers.length ||
    shares.some((s) => !Number.isInteger(s) || s < 1) ||
    shares.reduce((a, b) => a + b, 0) !== 100
  ) {
    problems.push('the return shares must be whole numbers ≥ 1, one per multiplier, summing to 100');
  }
  if (problems.length > 0) return problems;
  const outcomes = multipliers.map((multiplier, i) => ({
    multiplier,
    chancePerMillion: Math.floor((rtpBps * shares[i]!) / multiplier),
  }));
  const zero = outcomes.filter((o) => o.chancePerMillion < 1).map((o) => `×${String(o.multiplier)}`);
  if (zero.length > 0)
    problems.push(`the chance of ${zero.join(', ')} rounds to 0 per million; give it a larger share`);
  const total = outcomes.reduce((a, o) => a + o.chancePerMillion, 0);
  if (total > LUCKY_CHANCE_SCALE) problems.push('the winning chances add up to more than 100 %');
  if (problems.length > 0) return problems;
  return Object.freeze({
    rtpBps,
    hostShareBps,
    outcomes: Object.freeze(outcomes.map((o) => Object.freeze(o))),
    noWinChancePerMillion: LUCKY_CHANCE_SCALE - total,
  });
}

/** The exact expected return of `table`, in basis points: Σ c_i × m_i / 100. */
export function expectedReturnBps(table: Pick<LuckyTable, 'outcomes'>): number {
  return table.outcomes.reduce((a, o) => a + o.chancePerMillion * o.multiplier, 0) / 100;
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

/** One draw as audited: `[index, drawn multiplier, paid multiplier]` (paid 0: nothing). */
export type AuditedWin = [number, number, number];

export interface CappedWins {
  readonly wins: AuditedWin[];
  readonly coinsWon: bigint;
  /** Winning draws paid less than drawn (or nothing). */
  readonly downgraded: number;
  readonly budgetAfter: bigint;
}

/**
 * The daily protection (§10.27): pays the winning draws in draw order while they fit in `budget`;
 * a draw that does not fit pays the largest smaller multiplier of `multipliers` that fits, or 0.
 */
export function capWins(
  winners: readonly (readonly [number, number])[],
  unitPrice: number,
  multipliers: readonly number[],
  budget: bigint,
): CappedWins {
  const ascending = [...multipliers].sort((a, b) => a - b);
  const unit = BigInt(unitPrice);
  let left = budget;
  let coinsWon = 0n;
  let downgraded = 0;
  const wins: AuditedWin[] = [];
  for (const [index, drawn] of winners) {
    let paid = 0;
    for (let i = ascending.length - 1; i >= 0; i -= 1) {
      const m = ascending[i]!;
      if (m <= drawn && BigInt(m) * unit <= left) {
        paid = m;
        break;
      }
    }
    if (paid !== drawn) downgraded += 1;
    if (paid > 0) {
      const coins = BigInt(paid) * unit;
      left -= coins;
      coinsWon += coins;
    }
    wins.push([index, drawn, paid]);
  }
  return { wins, coinsWon, downgraded, budgetAfter: left };
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
  };
}

/** `floor(value × bps / 10^4)`: the share of a value that is counted (host share 10 %). */
export function shareOf(value: number, bps: number): number {
  // BigInt: value × bps can pass 2^53 (a send's score points × 10 000).
  return Number((BigInt(value) * BigInt(bps)) / BigInt(BPS));
}
