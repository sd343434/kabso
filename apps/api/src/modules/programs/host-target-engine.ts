/**
 * D281 (owner, contract v1.71-live, CONVENTIONS §10.62.2): the smart daily targets of a host — a generated
 * catalogue of more than 100 000 targets (templates × parameters), three targets a day at three levels
 * (easy / medium / hard) chosen from the host's own data, and a reward that is a share of the PLATFORM
 * PROFIT the target produced, paid in locked task cherries. Pure rules only (no Nest, no database), shared
 * by the API, the admin panel service and the unit tests (host-target-engine.spec.ts).
 */
import { seedOf } from './programs-rules.js';

// ---- Levels, kinds, windows ---------------------------------------------------------------------

export const TARGET_LEVELS = ['EASY', 'MEDIUM', 'HARD'] as const;
export type TargetLevel = (typeof TARGET_LEVELS)[number];

/**
 * What a target counts (all from stored data, in the target's window of the host's Riyadh day; senders
 * ACTIVE; the host's own sends count only for lucky gifts, as in D277):
 * - GIFT_CHERRIES  cherries credited for gifts OUTSIDE the lucky category from other people («هدف الهدايا»);
 * - LUCKY_CHERRIES cherries credited for lucky gifts, the host's own sends included («هدف هدايا الحظ»);
 * - GIFT_COUNT     how many of ONE gift (`subject` = its code) were received («استقبل 100 هدية من المحارب»);
 * - CATEGORY_COUNT how many gifts of one category (`subject` = the category code) were received;
 * - SUPPORTERS     different people who sent the host a gift;
 * - GIFT_SENDS     gifts received (quantity), any gift;
 * - COMBO          the biggest combo of one send streak (a sender's same gift again and again) received;
 * - GIFT_COMBO     the same, of ONE gift (`subject`).
 */
export const TARGET_KINDS = [
  'GIFT_CHERRIES',
  'LUCKY_CHERRIES',
  'GIFT_COUNT',
  'CATEGORY_COUNT',
  'SUPPORTERS',
  'GIFT_SENDS',
  'COMBO',
  'GIFT_COMBO',
] as const;
export type TargetKind = (typeof TARGET_KINDS)[number];

/** The kinds measured in cherries (their amount is a cherry amount, the reward follows it directly). */
export const VALUE_KINDS: readonly TargetKind[] = ['GIFT_CHERRIES', 'LUCKY_CHERRIES'];
/** The kinds about one gift (`subject` = a gift code). */
export const GIFT_KINDS: readonly TargetKind[] = ['GIFT_COUNT', 'GIFT_COMBO'];

/** Minutes of the host's day: [from, to), 0 ≤ from < to ≤ 1440. */
export interface TargetWindow {
  readonly from: number;
  readonly to: number;
}
export const ALL_DAY: TargetWindow = { from: 0, to: 1440 };
/** The window lengths (hours) of the catalogue; every start hour that fits in the day. */
export const WINDOW_HOURS = [1, 2, 3, 4, 5, 6, 8] as const;

/** Every window of the catalogue: the whole day first, then each length at each start hour. */
export function catalogueWindows(): TargetWindow[] {
  const out: TargetWindow[] = [ALL_DAY];
  for (const h of WINDOW_HOURS) {
    for (let start = 0; start + h <= 24; start++) out.push({ from: start * 60, to: (start + h) * 60 });
  }
  return out;
}

export function isAllDay(w: TargetWindow): boolean {
  return w.from === 0 && w.to === 1440;
}

/** `20:00–24:00`. */
export function windowLabel(w: TargetWindow): string {
  const hm = (m: number) =>
    `${String(Math.floor(m / 60)).padStart(2, '0')}:${String(m % 60).padStart(2, '0')}`;
  return `${hm(w.from)}–${hm(w.to)}`;
}

/**
 * «من 20:00 إلى 24:00»: the Arabic window names each hour on its own (two LTR numbers joined by a dash would be
 * shown in the reverse order inside Arabic text).
 */
export function windowLabelAr(w: TargetWindow): string {
  const [from, to] = windowLabel(w).split('–');
  return `من ${from!} إلى ${to!}`;
}

// ---- Amount ladders -----------------------------------------------------------------------------

const MANTISSAS = [1, 1.2, 1.5, 1.8, 2, 2.5, 3, 3.5, 4, 4.5, 5, 6, 7, 8, 9];

/** Cherry amounts: 15 «round» steps per decade from 1 000 to 900 000 000 (90 steps). */
export const CHERRY_LADDER: readonly number[] = (() => {
  const out: number[] = [];
  for (let d = 1_000; d <= 100_000_000; d *= 10) for (const m of MANTISSAS) out.push(Math.round(m * d));
  return out;
})();

/** Gift counts (one gift, a category, all gifts): 40 steps from 1 to 10 000. */
export const COUNT_LADDER: readonly number[] = [
  1, 2, 3, 4, 5, 6, 8, 10, 12, 15, 20, 25, 30, 40, 50, 60, 75, 80, 100, 120, 150, 200, 250, 300, 400, 500,
  600, 750, 800, 1_000, 1_200, 1_500, 2_000, 2_500, 3_000, 4_000, 5_000, 6_000, 7_500, 10_000,
];

/** Different supporters: 20 steps. */
export const SUPPORTER_LADDER: readonly number[] = [
  1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 12, 15, 20, 25, 30, 40, 50, 60, 75, 100,
];

/** Combo sizes (the gift apps' customary numbers): 20 steps. */
export const COMBO_LADDER: readonly number[] = [
  5, 10, 20, 30, 50, 66, 88, 99, 100, 188, 199, 288, 300, 520, 666, 999, 1_314, 1_999, 3_344, 9_999,
];

export function ladderOf(kind: TargetKind): readonly number[] {
  switch (kind) {
    case 'GIFT_CHERRIES':
    case 'LUCKY_CHERRIES':
      return CHERRY_LADDER;
    case 'SUPPORTERS':
      return SUPPORTER_LADDER;
    case 'COMBO':
    case 'GIFT_COMBO':
      return COMBO_LADDER;
    default:
      return COUNT_LADDER;
  }
}

/** The ladder step nearest to `value` from above (the last step when `value` is beyond it). */
export function snapUp(ladder: readonly number[], value: number): number {
  for (const step of ladder) if (step >= value) return step;
  return ladder[ladder.length - 1]!;
}

/** The index of `value` in `ladder` (the nearest step at or above). */
export function ladderIndex(ladder: readonly number[], value: number): number {
  const i = ladder.findIndex((s) => s >= value);
  return i < 0 ? ladder.length - 1 : i;
}

// ---- The catalogue ------------------------------------------------------------------------------

/** A gift of the enabled catalogue as the targets see it. */
export interface CatalogueGift {
  readonly code: string;
  readonly category: string;
  readonly priceCoins: number;
  readonly nameAr: string;
  readonly nameEn: string;
  /** True for a gift of the lucky category. */
  readonly lucky: boolean;
}

/** One target of the catalogue. */
export interface CatalogueTarget {
  readonly code: string;
  readonly kind: TargetKind;
  /** A gift code (GIFT_COUNT, GIFT_COMBO), a category code (CATEGORY_COUNT), else null. */
  readonly subject: string | null;
  readonly amount: number;
  readonly window: TargetWindow;
}

/** The stable code of a target: `T.<kind>.<subject|*>.<amount>.<from>-<to>`. */
export function targetCode(t: Omit<CatalogueTarget, 'code'>): string {
  return `T.${t.kind}.${t.subject ?? '*'}.${String(t.amount)}.${String(t.window.from)}-${String(t.window.to)}`;
}

/** Parses a target code (null when malformed). */
export function parseTargetCode(code: string): Omit<CatalogueTarget, 'code'> | null {
  const m = /^T\.([A-Z_]+)\.([^.]+)\.(\d{1,10})\.(\d{1,4})-(\d{1,4})$/.exec(code);
  if (!m || !(TARGET_KINDS as readonly string[]).includes(m[1]!)) return null;
  const from = Number(m[4]);
  const to = Number(m[5]);
  if (!(from >= 0 && from < to && to <= 1440)) return null;
  return {
    kind: m[1] as TargetKind,
    subject: m[2] === '*' ? null : m[2]!,
    amount: Number(m[3]),
    window: { from, to },
  };
}

/** The gifts a count target may name: paid gifts (price > 0). */
function countableGifts(gifts: readonly CatalogueGift[]): CatalogueGift[] {
  return gifts.filter((g) => g.priceCoins > 0);
}

function categoriesOf(gifts: readonly CatalogueGift[]): string[] {
  return [...new Set(countableGifts(gifts).map((g) => g.category))].sort();
}

/**
 * Every target of the catalogue for the enabled `gifts`, generated (templates × parameters): a kind × its
 * amount ladder × each window × (one gift / one category). Deterministic order. The catalogue follows the
 * gift catalogue: a gift added or switched off adds or removes its targets at the next read.
 */
export function* enumerateTargets(gifts: readonly CatalogueGift[]): Generator<CatalogueTarget> {
  const windows = catalogueWindows();
  const giftCodes = countableGifts(gifts)
    .map((g) => g.code)
    .sort();
  const categories = categoriesOf(gifts);
  for (const kind of TARGET_KINDS) {
    const subjects: (string | null)[] = GIFT_KINDS.includes(kind)
      ? giftCodes
      : kind === 'CATEGORY_COUNT'
        ? categories
        : [null];
    for (const subject of subjects) {
      for (const amount of ladderOf(kind)) {
        for (const window of windows) {
          const t = { kind, subject, amount, window };
          yield { code: targetCode(t), ...t };
        }
      }
    }
  }
}

/** How many targets each kind has for `gifts` (the panel's catalogue stats; = what enumerateTargets yields). */
export function catalogueStats(gifts: readonly CatalogueGift[]): {
  total: number;
  windows: number;
  gifts: number;
  categories: number;
  byKind: Record<TargetKind, number>;
} {
  const windows = catalogueWindows().length;
  const giftCount = countableGifts(gifts).length;
  const categories = categoriesOf(gifts).length;
  const byKind = {} as Record<TargetKind, number>;
  let total = 0;
  for (const kind of TARGET_KINDS) {
    const subjects = GIFT_KINDS.includes(kind) ? giftCount : kind === 'CATEGORY_COUNT' ? categories : 1;
    byKind[kind] = subjects * ladderOf(kind).length * windows;
    total += byKind[kind];
  }
  return { total, windows, gifts: giftCount, categories, byKind };
}

/** A version of the gift side of the catalogue (it changes when a gift is added, switched off or repriced). */
export function catalogueVersion(gifts: readonly CatalogueGift[]): string {
  const key = countableGifts(gifts)
    .map((g) => `${g.code}:${g.category}:${String(g.priceCoins)}`)
    .sort()
    .join(',');
  return seedOf(key).toString(16).padStart(8, '0');
}

// ---- Economics: platform profit and the reward ---------------------------------------------------

/**
 * The economy constants the profit uses (all from the configuration): `CHERRIES_PER_COIN`,
 * `GIFT_HOST_SHARE_PERCENTS` / `LUCKY_GIFT_HOST_SHARE_PERCENT` (bps), `LUCKY_GIFT_RTP_PERCENT` (bps),
 * `COIN_RETAIL_USD_PER_MILLION` (as cents per 1 000 000 coins) and `CHERRY_PAYOUT_RATE` (`rateCherries`
 * cherries = `rateMinor` cents).
 */
export interface ProfitEconomy {
  readonly cherriesPerCoin: number;
  readonly coinCentsPerMillion: number;
  readonly rateCherries: number;
  readonly rateMinor: number;
  readonly luckyRtpBps: number;
  readonly luckyHostShareBps: number;
  /** The host share of a non-lucky gift by category (unknown categories: `POPULAR`). */
  readonly hostShareBps: Readonly<Record<string, number>>;
}

/**
 * Money in one exact unit: micro-cents × `rateCherries` (so both a coin and a cherry are whole numbers):
 * a coin is `coinCentsPerMillion × rateCherries` units, a cherry `rateMinor × 1 000 000` units.
 */
export function coinUnits(e: ProfitEconomy): bigint {
  return BigInt(e.coinCentsPerMillion) * BigInt(e.rateCherries);
}
export function cherryUnits(e: ProfitEconomy): bigint {
  return BigInt(e.rateMinor) * 1_000_000n;
}

/** What one send (one recipient's part) did for the platform. */
export interface SendMoney {
  /** True for a lucky gift. */
  readonly lucky: boolean;
  /** The recipient's coin value of the send (`live_gift_recipients.coins`). */
  readonly coins: bigint;
  /** The part of it paid with coins (a gift from the bag or a free quip: 0). */
  readonly chargedCoins: bigint;
  /** The cherries the ledger credited the recipient for it (net of reversals). */
  readonly hostCherries: bigint;
}

/**
 * The platform's profit of sends, in money units ({@link coinUnits}):
 * - a normal gift: the coins paid (revenue) − the host's cherries at their payout value;
 * - a lucky gift: the coins paid − the expected payout to the sender (RTP × the coin value) − the host's
 *   cherries.
 * It may be negative (a gift from the bag pays the host but earned nothing now).
 */
export function platformProfitUnits(sends: readonly SendMoney[], e: ProfitEconomy): bigint {
  const coin = coinUnits(e);
  const cherry = cherryUnits(e);
  let total = 0n;
  for (const s of sends) {
    let units = s.chargedCoins * coin - s.hostCherries * cherry;
    if (s.lucky) units -= (s.coins * BigInt(e.luckyRtpBps) * coin) / 10_000n;
    total += units;
  }
  return total;
}

/** Money units as US dollars (a number for display and tests). */
export function unitsUsd(units: bigint, e: ProfitEconomy): number {
  // units / rateCherries = micro-cents.
  return Number(units) / e.rateCherries / 1_000_000 / 100;
}

/** The host share (bps) of a gift of `category` (lucky: the lucky share). */
export function shareBpsOf(e: ProfitEconomy, category: string, lucky: boolean): number {
  if (lucky) return e.luckyHostShareBps;
  return e.hostShareBps[category] ?? e.hostShareBps.POPULAR ?? 6_500;
}

/** The highest share of a non-lucky gift (the cautious one: fewer coins behind the same cherries). */
export function maxNormalShareBps(e: ProfitEconomy): number {
  return Math.max(...Object.values(e.hostShareBps));
}

/**
 * The profit (money units) that a target's NOMINAL amount stands for — what the platform earns when the target
 * is just reached:
 * - GIFT_CHERRIES `amount` cherries: the coins behind them at the highest normal host share, less the cherries;
 * - LUCKY_CHERRIES: the coins behind them at the lucky share, less the expected payout and the cherries;
 * - every count kind: `expectedCoins` (the coin value behind the count, set at assignment from the gift's price
 *   or the host's own value per unit) as a normal gift at `shareBps` — or lucky when `lucky`.
 * Never below 0.
 */
export function expectedProfitUnits(
  kind: TargetKind,
  amount: number,
  expectedCoins: number,
  e: ProfitEconomy,
  opts: { lucky?: boolean; shareBps?: number } = {},
): bigint {
  const coin = coinUnits(e);
  const cherry = cherryUnits(e);
  const cpc = BigInt(e.cherriesPerCoin);
  let units: bigint;
  if (kind === 'GIFT_CHERRIES' || kind === 'LUCKY_CHERRIES') {
    const lucky = kind === 'LUCKY_CHERRIES';
    const share = BigInt(lucky ? e.luckyHostShareBps : maxNormalShareBps(e));
    if (share === 0n) return 0n;
    const c = BigInt(amount);
    // coins = c × 10 000 / (cpc × share) — kept exact by scaling everything by (cpc × share).
    const scale = cpc * share;
    let scaled = c * 10_000n * coin - c * scale * cherry;
    // The expected payout (RTP × the coin value), scaled the same way.
    if (lucky) scaled -= c * BigInt(e.luckyRtpBps) * coin;
    units = scaled / scale;
  } else {
    const coins = BigInt(Math.max(0, Math.floor(expectedCoins)));
    const lucky = opts.lucky === true;
    const share = BigInt(opts.shareBps ?? (lucky ? e.luckyHostShareBps : maxNormalShareBps(e)));
    const hostCherries = (coins * cpc * share) / 10_000n;
    units = platformProfitUnits([{ lucky, coins, chargedCoins: coins, hostCherries }], e);
  }
  return units > 0n ? units : 0n;
}

/** Cherries worth `pctBps` of `profitUnits` (floored; 0 for no profit). */
export function rewardCherriesFor(profitUnits: bigint, pctBps: number, e: ProfitEconomy): number {
  if (profitUnits <= 0n || pctBps <= 0) return 0;
  return Number((profitUnits * BigInt(pctBps)) / (10_000n * cherryUnits(e)));
}

/**
 * What a completed target pays (owner's guard): the reward shown (from the nominal amount) but never more than
 * `pctBps` of the profit ACTUALLY counted by the target (its gifts of the day, in its window).
 */
export function cappedTargetReward(
  shownReward: number,
  actualProfitUnits: bigint,
  pctBps: number,
  e: ProfitEconomy,
): number {
  return Math.max(0, Math.min(shownReward, rewardCherriesFor(actualProfitUnits, pctBps, e)));
}

// ---- Tuning (the owner's knobs) ------------------------------------------------------------------

export interface TargetTuning {
  /** The percentile of the host's recent active days each level aims at (easy ≈ a typical day). */
  readonly easyPercentile: number;
  readonly mediumPercentile: number;
  readonly hardPercentile: number;
  /** The reward: a share of the platform profit, basis points (owner: 1.5 % / 2.5 % / 4 %). */
  readonly easyRewardBps: number;
  readonly mediumRewardBps: number;
  readonly hardRewardBps: number;
  /** A target (same code) is not given again within this many days. */
  readonly noRepeatDays: number;
  /** The days of history read (and the days the completion rate looks back: half of it). */
  readonly historyDays: number;
  /** The most the completion rate moves the percentiles (points). */
  readonly completionShift: number;
}

export const DEFAULT_TARGET_TUNING: TargetTuning = {
  easyPercentile: 50,
  mediumPercentile: 75,
  hardPercentile: 90,
  easyRewardBps: 150,
  mediumRewardBps: 250,
  hardRewardBps: 400,
  noRepeatDays: 7,
  historyDays: 30,
  completionShift: 10,
};

export function rewardBpsOf(level: TargetLevel, t: TargetTuning): number {
  return level === 'EASY' ? t.easyRewardBps : level === 'MEDIUM' ? t.mediumRewardBps : t.hardRewardBps;
}

export function percentileOf(level: TargetLevel, t: TargetTuning): number {
  return level === 'EASY' ? t.easyPercentile : level === 'MEDIUM' ? t.mediumPercentile : t.hardPercentile;
}

/** The p-th percentile (0–100) of `values` by linear interpolation (0 for none). */
export function percentile(values: readonly number[], p: number): number {
  if (values.length === 0) return 0;
  const sorted = [...values].sort((a, b) => a - b);
  const rank = (Math.min(100, Math.max(0, p)) / 100) * (sorted.length - 1);
  const lo = Math.floor(rank);
  const hi = Math.ceil(rank);
  return sorted[lo]! + (sorted[hi]! - sorted[lo]!) * (rank - lo);
}

/**
 * The completion-rate adjustment (points added to every level's percentile): with at least 3 targets in the
 * look-back, (rate − 0.5) × 2 × `shift` — a host who always finishes gets +shift (harder), one who never does
 * −shift (easier); fewer targets: 0.
 */
export function completionAdjustment(completed: number, assigned: number, shift: number): number {
  if (assigned < 3) return 0;
  const rate = Math.min(1, Math.max(0, completed / assigned));
  return Math.round((rate - 0.5) * 2 * shift);
}

// ---- The host's data and the assignment -----------------------------------------------------------

/** One recent day of the host (their Riyadh day), from stored data. */
export interface HostDay {
  readonly day: string;
  readonly giftCherries: number;
  readonly luckyCherries: number;
  readonly giftCoins: number;
  readonly luckyCoins: number;
  readonly sends: number;
  readonly supporters: number;
  readonly maxCombo: number;
  readonly liveMinutes: number;
  /** Cherries (gifts + lucky) per hour of the day (24 numbers). */
  readonly hourCherries: readonly number[];
  /** Gifts received by gift code (quantity). */
  readonly giftQty: Readonly<Record<string, number>>;
}

/** What the assignment reads about a host. */
export interface HostProfile {
  readonly band: number;
  /** Days with something to learn from (live minutes or gifts), newest first, within `historyDays`. */
  readonly days: readonly HostDay[];
  /** Live minutes per hour of the day over the history (the host's usual time). */
  readonly liveHourMinutes: readonly number[];
  /** Average different viewers per live over the history. */
  readonly avgViewers: number;
  /** Targets assigned / completed in the completion look-back. */
  readonly recentAssigned: number;
  readonly recentCompleted: number;
  /** Target codes given in the last `noRepeatDays` days. */
  readonly recentCodes: readonly string[];
}

/** One chosen target with the reasons («لماذا هذا الهدف») the panel shows. */
export interface TargetPick {
  readonly level: TargetLevel;
  readonly target: CatalogueTarget;
  /** The coin value behind the target (count kinds; the cherries' coins for value kinds). */
  readonly expectedCoins: number;
  readonly rewardBps: number;
  readonly rewardCherries: number;
  readonly reason: TargetReason;
}

export interface TargetReason {
  readonly newHost: boolean;
  readonly band: number;
  readonly activeDays: number;
  readonly percentile: number;
  readonly basePercentile: number;
  readonly completionRate: number | null;
  readonly adjustment: number;
  /** The host's value at that percentile, before snapping to the catalogue. */
  readonly basis: number;
  readonly avg7: number;
  readonly avg30: number;
  readonly best: number;
  readonly why: string;
  readonly whyAr: string;
}

/** New hosts (fewer than this many active days) get the band's defaults. */
export const MIN_HISTORY_DAYS = 3;

/** The band defaults (new hosts): per band 1…4, per level easy / medium / hard. */
export const NEW_HOST_DEFAULTS: Readonly<
  Record<'GIFT_SENDS' | 'SUPPORTERS' | 'GIFT_CHERRIES', readonly (readonly [number, number, number])[]>
> = {
  GIFT_SENDS: [
    [5, 10, 20],
    [10, 25, 50],
    [25, 60, 120],
    [50, 120, 250],
  ],
  SUPPORTERS: [
    [2, 3, 5],
    [3, 5, 8],
    [5, 8, 12],
    [8, 12, 20],
  ],
  GIFT_CHERRIES: [
    [20_000, 60_000, 150_000],
    [60_000, 200_000, 500_000],
    [200_000, 600_000, 1_500_000],
    [600_000, 2_000_000, 5_000_000],
  ],
};

/** mulberry32 (the same generator as the task pool). */
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

/** A candidate kind for today with its daily values (one per active day) and its weight. */
interface Candidate {
  kind: TargetKind;
  subject: string | null;
  window: TargetWindow;
  values: number[];
  weight: number;
  /** Coins per unit of the count (count kinds). */
  unitCoins: number;
  lucky: boolean;
  shareBps: number;
  label: string;
  labelAr: string;
}

const avg = (xs: readonly number[]) => (xs.length === 0 ? 0 : xs.reduce((a, b) => a + b, 0) / xs.length);

/**
 * The window of `hours` hours with the most of `perHour` (ties: the earliest), with its share of the total.
 */
export function busiestWindow(
  perHour: readonly number[],
  hours: number,
): { window: TargetWindow; share: number } {
  const total = perHour.reduce((a, b) => a + b, 0);
  let best = 0;
  let bestSum = -1;
  for (let s = 0; s + hours <= 24; s++) {
    let sum = 0;
    for (let h = s; h < s + hours; h++) sum += perHour[h] ?? 0;
    if (sum > bestSum) {
      bestSum = sum;
      best = s;
    }
  }
  return { window: { from: best * 60, to: (best + hours) * 60 }, share: total > 0 ? bestSum / total : 0 };
}

/** The candidates a host's data supports (only kinds there is history for). */
function candidatesOf(p: HostProfile, gifts: readonly CatalogueGift[], e: ProfitEconomy): Candidate[] {
  const days = p.days;
  const n = days.length;
  const out: Candidate[] = [];
  const giftCherries = days.map((d) => d.giftCherries);
  const luckyCherries = days.map((d) => d.luckyCherries);
  const totalGift = giftCherries.reduce((a, b) => a + b, 0);
  const totalLucky = luckyCherries.reduce((a, b) => a + b, 0);
  const normalShare = maxNormalShareBps(e);
  if (totalGift > 0) {
    out.push({
      kind: 'GIFT_CHERRIES',
      subject: null,
      window: ALL_DAY,
      values: giftCherries,
      weight: 3 * (totalGift / Math.max(1, totalGift + totalLucky)) + 1,
      unitCoins: 0,
      lucky: false,
      shareBps: normalShare,
      label: 'cherries from gifts',
      labelAr: 'كرز الهدايا',
    });
  }
  if (totalLucky > 0) {
    out.push({
      kind: 'LUCKY_CHERRIES',
      subject: null,
      window: ALL_DAY,
      values: luckyCherries,
      weight: 3 * (totalLucky / Math.max(1, totalGift + totalLucky)) + 1,
      unitCoins: 0,
      lucky: true,
      shareBps: e.luckyHostShareBps,
      label: 'cherries from lucky gifts',
      labelAr: 'كرز هدايا الحظ',
    });
  }
  // The usual time of day: when most of the cherries come within ≤ 4 hours, a windowed value target.
  const hourTotals = Array.from({ length: 24 }, (_, h) =>
    days.reduce((a, d) => a + (d.hourCherries[h] ?? 0), 0),
  );
  for (const hours of [2, 3, 4]) {
    const { window, share } = busiestWindow(hourTotals, hours);
    if (share >= 0.6 && totalGift > 0) {
      const from = window.from / 60;
      const values = days.map((d) => {
        let s = 0;
        for (let h = from; h < from + hours; h++) s += d.hourCherries[h] ?? 0;
        // Only the non-lucky part of the window (the hour series holds both): scale by the day's gift share.
        const all = d.giftCherries + d.luckyCherries;
        return all > 0 ? Math.floor((s * d.giftCherries) / all) : 0;
      });
      if (values.some((v) => v > 0)) {
        out.push({
          kind: 'GIFT_CHERRIES',
          subject: null,
          window,
          values,
          weight: 1.5 * share,
          unitCoins: 0,
          lucky: false,
          shareBps: normalShare,
          label: `cherries from gifts ${windowLabel(window)}`,
          labelAr: `كرز الهدايا ${windowLabelAr(window)}`,
        });
        break;
      }
    }
  }
  const sends = days.map((d) => d.sends);
  const coinsAll = days.reduce((a, d) => a + d.giftCoins, 0);
  const sendsAll = sends.reduce((a, b) => a + b, 0);
  const prices = gifts.filter((g) => g.priceCoins > 0 && !g.lucky).map((g) => g.priceCoins);
  const cheapestPrice = prices.length > 0 ? Math.min(...prices) : 1;
  if (sendsAll > 0) {
    out.push({
      kind: 'GIFT_SENDS',
      subject: null,
      window: ALL_DAY,
      values: sends,
      weight: 1,
      unitCoins: Math.max(cheapestPrice, Math.floor(coinsAll / Math.max(1, sendsAll))),
      lucky: false,
      shareBps: normalShare,
      label: 'gifts received',
      labelAr: 'الهدايا المستلمة',
    });
  }
  const supporters = days.map((d) => d.supporters);
  if (avg(supporters) >= 2) {
    const supAll = supporters.reduce((a, b) => a + b, 0);
    out.push({
      kind: 'SUPPORTERS',
      subject: null,
      window: ALL_DAY,
      values: supporters,
      weight: 1 + Math.min(1, p.avgViewers / 50),
      unitCoins: Math.max(cheapestPrice, Math.floor(coinsAll / Math.max(1, supAll))),
      lucky: false,
      shareBps: normalShare,
      label: 'different supporters',
      labelAr: 'داعمون مختلفون',
    });
  }
  const combos = days.map((d) => d.maxCombo);
  if (percentile(combos, 50) >= 5) {
    out.push({
      kind: 'COMBO',
      subject: null,
      window: ALL_DAY,
      values: combos,
      weight: 0.8,
      unitCoins: cheapestPrice,
      lucky: false,
      shareBps: normalShare,
      label: 'a gift combo',
      labelAr: 'كومبو هدايا',
    });
  }
  // The gifts the host usually receives (on ≥ 30 % of active days): a count target of one of them.
  const byCode = new Map(gifts.map((g) => [g.code, g]));
  const usual = new Map<string, number>();
  for (const d of days)
    for (const [code, q] of Object.entries(d.giftQty)) if (q > 0) usual.set(code, (usual.get(code) ?? 0) + 1);
  const usualGifts = [...usual.entries()]
    .filter(
      ([code, k]) =>
        byCode.has(code) && byCode.get(code)!.priceCoins > 0 && k >= Math.max(1, Math.ceil(n * 0.3)),
    )
    .sort((a, b) => b[1] - a[1] || (a[0] < b[0] ? -1 : 1))
    .slice(0, 5);
  for (const [code, k] of usualGifts) {
    const g = byCode.get(code)!;
    out.push({
      kind: 'GIFT_COUNT',
      subject: code,
      window: ALL_DAY,
      values: days.map((d) => d.giftQty[code] ?? 0),
      weight: (1.2 * k) / Math.max(1, n),
      unitCoins: g.priceCoins,
      lucky: g.lucky,
      shareBps: shareBpsOf(e, g.category, g.lucky),
      label: `${g.nameEn} received`,
      labelAr: `استلام ${g.nameAr}`,
    });
  }
  // The category of the gifts they get most (counts by category).
  const catQty = new Map<string, number[]>();
  for (const [i, d] of days.entries()) {
    for (const [code, q] of Object.entries(d.giftQty)) {
      const g = byCode.get(code);
      if (!g || g.priceCoins <= 0) continue;
      const row = catQty.get(g.category) ?? new Array<number>(n).fill(0);
      row[i] = (row[i] ?? 0) + q;
      catQty.set(g.category, row);
    }
  }
  const topCat = [...catQty.entries()].sort(
    (a, b) => b[1].reduce((x, y) => x + y, 0) - a[1].reduce((x, y) => x + y, 0) || (a[0] < b[0] ? -1 : 1),
  )[0];
  if (topCat && topCat[1].filter((v) => v > 0).length >= Math.max(1, Math.ceil(n * 0.3))) {
    const inCat = gifts.filter((g) => g.category === topCat[0] && g.priceCoins > 0);
    const lucky = inCat.every((g) => g.lucky);
    out.push({
      kind: 'CATEGORY_COUNT',
      subject: topCat[0],
      window: ALL_DAY,
      values: topCat[1],
      weight: 0.8,
      unitCoins: Math.max(1, Math.min(...inCat.map((g) => g.priceCoins))),
      lucky,
      shareBps: shareBpsOf(e, topCat[0], lucky),
      label: `gifts of ${topCat[0]}`,
      labelAr: `هدايا فئة ${topCat[0]}`,
    });
  }
  return out;
}

/** The coins behind `amount` of a candidate (value kinds: the cherries' coins at the candidate's share). */
function expectedCoinsOf(
  c: { kind: TargetKind; unitCoins: number; shareBps: number },
  amount: number,
  e: ProfitEconomy,
): number {
  if (c.kind === 'GIFT_CHERRIES' || c.kind === 'LUCKY_CHERRIES') {
    return c.shareBps > 0 ? Math.floor((amount * 10_000) / (e.cherriesPerCoin * c.shareBps)) : 0;
  }
  return amount * c.unitCoins;
}

/**
 * Today's three targets of a host — deterministic for `seed` (the host and the day):
 * 1. New host (fewer than {@link MIN_HISTORY_DAYS} active days): the band's defaults — easy: gifts received,
 *    medium: different supporters, hard: cherries from gifts.
 * 2. Otherwise the candidates the host's data supports (cherries from gifts / lucky gifts, their usual hours,
 *    the gifts and the category they usually get, supporters, combos, gifts received), each with its value on
 *    every recent active day. Each level takes a different kind (the mix): HARD a value kind (cherries — the
 *    biggest share of profit only for real profit), the others drawn by weight (seeded).
 * 3. The amount: the level's percentile of the candidate's daily values (easy 50, medium 75, hard 90 by
 *    default), moved by the completion adjustment, snapped up to the catalogue's ladder, and strictly growing
 *    from easy to hard on the same kind.
 * 4. No repeat: a code given in the last `noRepeatDays` days moves one ladder step (up; easy: down first).
 * 5. The reward: the level's share of the profit the nominal amount stands for ({@link expectedProfitUnits}).
 */
export function assignHostTargets(
  profile: HostProfile,
  gifts: readonly CatalogueGift[],
  e: ProfitEconomy,
  tuning: TargetTuning,
  seed: number,
): TargetPick[] {
  const random = generator(seed);
  const n = profile.days.length;
  const newHost = n < MIN_HISTORY_DAYS;
  const adjustment = newHost
    ? 0
    : completionAdjustment(profile.recentCompleted, profile.recentAssigned, tuning.completionShift);
  const rate = profile.recentAssigned > 0 ? profile.recentCompleted / profile.recentAssigned : null;
  const recent = new Set(profile.recentCodes);
  const bandIdx = Math.min(3, Math.max(0, profile.band - 1));
  const normalShare = maxNormalShareBps(e);
  const cheapest = gifts.filter((g) => g.priceCoins > 0 && !g.lucky).map((g) => g.priceCoins);
  const cheapestPrice = cheapest.length > 0 ? Math.min(...cheapest) : 1;
  const picks: TargetPick[] = [];
  const used = new Set<string>();

  const finish = (
    level: TargetLevel,
    c: Pick<
      Candidate,
      'kind' | 'subject' | 'window' | 'unitCoins' | 'lucky' | 'shareBps' | 'label' | 'labelAr'
    >,
    basis: number,
    values: readonly number[],
    pct: number,
    minIndex: number,
  ): TargetPick => {
    const ladder = ladderOf(c.kind);
    let i = Math.max(minIndex, ladderIndex(ladder, Math.max(1, basis)));
    i = Math.min(i, ladder.length - 1);
    const codeAt = (k: number) =>
      targetCode({ kind: c.kind, subject: c.subject, amount: ladder[k]!, window: c.window });
    // No repeat: the nearest free step (easy tries one down first, never below the minimum).
    const order = level === 'EASY' ? [0, -1, 1, 2, -2, 3] : [0, 1, 2, -1, 3, 4];
    for (const d of order) {
      const k = i + d;
      if (k < minIndex || k >= ladder.length) continue;
      const code = codeAt(k);
      if (!recent.has(code) && !used.has(code)) {
        i = k;
        break;
      }
    }
    const amount = ladder[i]!;
    const target: CatalogueTarget = {
      code: codeAt(i),
      kind: c.kind,
      subject: c.subject,
      amount,
      window: c.window,
    };
    used.add(target.code);
    const expectedCoins = expectedCoinsOf(c, amount, e);
    const rewardBps = rewardBpsOf(level, tuning);
    const profit = expectedProfitUnits(c.kind, amount, expectedCoins, e, {
      lucky: c.lucky,
      shareBps: c.shareBps,
    });
    const r = (x: number) => Math.round(x);
    const last7 = values.slice(0, 7);
    const reason: TargetReason = {
      newHost,
      band: profile.band,
      activeDays: n,
      percentile: pct,
      basePercentile: percentileOf(level, tuning),
      completionRate: rate === null ? null : Math.round(rate * 100) / 100,
      adjustment,
      basis: r(basis),
      avg7: r(avg(last7)),
      avg30: r(avg(values)),
      best: values.length > 0 ? Math.max(...values) : 0,
      why: newHost
        ? `New host (${String(n)} active days): band ${String(profile.band)} default for ${level.toLowerCase()} — ${c.label}.`
        : `${c.label}: ${level.toLowerCase()} = the ${String(pct)}th percentile of ${String(n)} active days (${String(r(basis))}); ` +
          `7-day average ${String(r(avg(last7)))}, best ${String(values.length > 0 ? Math.max(...values) : 0)}` +
          (adjustment !== 0
            ? `; completion ${String(Math.round((rate ?? 0) * 100))}% → ${adjustment > 0 ? '+' : ''}${String(adjustment)} points`
            : '') +
          '.',
      whyAr: newHost
        ? `مضيف جديد (${String(n)} أيام نشطة): القيمة الافتراضية للشريحة ${String(profile.band)} — ${c.labelAr}.`
        : `${c.labelAr}: المستوى = المئين ${String(pct)} من ${String(n)} يوماً نشطاً (${String(r(basis))})؛ ` +
          `متوسط 7 أيام ${String(r(avg(last7)))}، الأفضل ${String(values.length > 0 ? Math.max(...values) : 0)}` +
          (adjustment !== 0
            ? `؛ نسبة الإنجاز ${String(Math.round((rate ?? 0) * 100))}% ← ${adjustment > 0 ? '+' : ''}${String(adjustment)}`
            : '') +
          '.',
    };
    return {
      level,
      target,
      expectedCoins,
      rewardBps,
      rewardCherries: rewardCherriesFor(profit, rewardBps, e),
      reason,
    };
  };

  if (newHost) {
    const plan: [TargetLevel, 'GIFT_SENDS' | 'SUPPORTERS' | 'GIFT_CHERRIES'][] = [
      ['EASY', 'GIFT_SENDS'],
      ['MEDIUM', 'SUPPORTERS'],
      ['HARD', 'GIFT_CHERRIES'],
    ];
    for (const [li, [level, kind]] of plan.entries()) {
      const basis = NEW_HOST_DEFAULTS[kind][bandIdx]![li]!;
      picks.push(
        finish(
          level,
          {
            kind,
            subject: null,
            window: ALL_DAY,
            unitCoins: cheapestPrice,
            lucky: false,
            shareBps: normalShare,
            label:
              kind === 'GIFT_SENDS'
                ? 'gifts received'
                : kind === 'SUPPORTERS'
                  ? 'different supporters'
                  : 'cherries from gifts',
            labelAr:
              kind === 'GIFT_SENDS'
                ? 'الهدايا المستلمة'
                : kind === 'SUPPORTERS'
                  ? 'داعمون مختلفون'
                  : 'كرز الهدايا',
          },
          basis,
          [],
          percentileOf(level, tuning),
          0,
        ),
      );
    }
    return picks;
  }

  const candidates = candidatesOf(profile, gifts, e);
  // A host with history but no gifts yet (only live minutes): the band defaults as for a new host, scaled to
  // the level, through the same path.
  if (candidates.length === 0) {
    return assignHostTargets({ ...profile, days: [] }, gifts, e, tuning, seed).map((p) => ({
      ...p,
      reason: { ...p.reason, activeDays: n },
    }));
  }
  const drawn: Candidate[] = [];
  const take = (pool: Candidate[]): Candidate | null => {
    const free = pool.filter(
      (c) => !drawn.includes(c) && !drawn.some((d) => d.kind === c.kind && d.subject === c.subject),
    );
    if (free.length === 0) return null;
    const total = free.reduce((a, c) => a + c.weight, 0);
    let x = random() * total;
    for (const c of free) {
      x -= c.weight;
      if (x <= 0) return c;
    }
    return free[free.length - 1]!;
  };
  // HARD: a value kind (cherries); then medium and easy from the rest, preferring kinds not drawn yet.
  const valueCands = candidates.filter((c) => VALUE_KINDS.includes(c.kind));
  const hard = take(valueCands.length > 0 ? valueCands : candidates)!;
  drawn.push(hard);
  const fresh = (c: Candidate) => !drawn.some((d) => d.kind === c.kind);
  const medium = take(candidates.filter(fresh)) ?? take(candidates) ?? hard;
  drawn.push(medium);
  const easy = take(candidates.filter(fresh)) ?? take(candidates) ?? medium;
  const byLevel: [TargetLevel, Candidate][] = [
    ['EASY', easy],
    ['MEDIUM', medium],
    ['HARD', hard],
  ];
  // Strictly growing amounts when two levels share a kind, subject and window.
  const floorFor = new Map<string, number>();
  for (const [level, c] of byLevel) {
    const pct = Math.min(99, Math.max(1, percentileOf(level, tuning) + adjustment));
    const basis = percentile(c.values, pct);
    const key = `${c.kind}|${c.subject ?? ''}|${String(c.window.from)}`;
    const minIndex = floorFor.get(key) ?? 0;
    const pick = finish(level, c, basis, c.values, pct, minIndex);
    floorFor.set(key, ladderIndex(ladderOf(c.kind), pick.target.amount) + 1);
    picks.push(pick);
  }
  return picks;
}

/** The seed of a host's day (the same FNV-1a as the task pool). */
export function targetSeed(hostId: string, day: string): number {
  return seedOf(`targets:${hostId}:${day}`);
}

// ---- Titles ----------------------------------------------------------------------------------------

const groupedEn = (n: number) => n.toLocaleString('en-US');

/**
 * A target's title in Arabic and English, e.g. «استقبل 100 هدية من المحارب», «اجمع 3,000,000 كرزة من الهدايا
 * من 20:00 إلى 24:00» (the Arabic window names each hour on its own: no bidi reordering of «20:00–24:00»).
 */
export function targetTitle(
  t: Omit<CatalogueTarget, 'code'>,
  names: { giftAr?: string; giftEn?: string; categoryAr?: string; categoryEn?: string },
): { ar: string; en: string } {
  const a = groupedEn(t.amount);
  const winAr = isAllDay(t.window) ? '' : ` ${windowLabelAr(t.window)}`;
  const winEn = isAllDay(t.window) ? '' : ` between ${windowLabel(t.window)}`;
  switch (t.kind) {
    case 'GIFT_CHERRIES':
      return { ar: `هدف الهدايا: ${a} كرزة${winAr}`, en: `Gifts target: ${a} cherries${winEn}` };
    case 'LUCKY_CHERRIES':
      return { ar: `هدف هدايا الحظ: ${a} كرزة${winAr}`, en: `Lucky gifts target: ${a} cherries${winEn}` };
    case 'GIFT_COUNT':
      return {
        ar: `استقبل ${a} هدية من ${names.giftAr ?? t.subject ?? ''}${winAr}`,
        en: `Receive ${a} × ${names.giftEn ?? t.subject ?? ''}${winEn}`,
      };
    case 'CATEGORY_COUNT':
      return {
        ar: `استقبل ${a} هدية من فئة ${names.categoryAr ?? t.subject ?? ''}${winAr}`,
        en: `Receive ${a} gifts from ${names.categoryEn ?? t.subject ?? ''}${winEn}`,
      };
    case 'SUPPORTERS':
      return { ar: `${a} داعمين مختلفين${winAr}`, en: `${a} different supporters${winEn}` };
    case 'GIFT_SENDS':
      return { ar: `استقبل ${a} هدية${winAr}`, en: `Receive ${a} gifts${winEn}` };
    case 'COMBO':
      return { ar: `كومبو ${a} هدية في بث واحد${winAr}`, en: `A combo of ${a} gifts in one live${winEn}` };
    case 'GIFT_COMBO':
      return {
        ar: `كومبو ${a} من ${names.giftAr ?? t.subject ?? ''}${winAr}`,
        en: `A combo of ${a} × ${names.giftEn ?? t.subject ?? ''}${winEn}`,
      };
  }
}
