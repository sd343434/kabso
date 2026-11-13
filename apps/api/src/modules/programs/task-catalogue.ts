/**
 * D281 (owner, contract v1.86-social, CONVENTIONS §10.41.4): the Task Center's generated catalogue — more than
 * 100 000 different tasks from the pool templates × parameters (an amount ladder per metric, a time window of
 * the day, a gift or a gift category) — and the smart per-person assignment that reads the person's own
 * activity. Rewards keep the Task Center's rules (D184 / D188: free actions a symbolic reward, money tasks
 * about 1 % of their coin value; the daily and monthly caps); they are separate from the host targets'
 * profit-share rewards (host-target-engine.ts). Pure rules only; unit-tested in task-catalogue.spec.ts.
 */
import {
  catalogueWindows,
  isAllDay,
  windowLabel,
  windowLabelAr,
  type CatalogueGift,
  type TargetWindow,
  ALL_DAY,
} from './host-target-engine.js';
import {
  audienceOffered,
  seedOf,
  taskRoleOf,
  type TaskAudience,
  type TaskMetric,
  type TaskPoolBand,
} from './programs-rules.js';

/** D281: the task metrics that take a gift (`subject` = a gift code) or a category (`subject` = its code). */
export const GIFT_SUBJECT_METRICS: readonly TaskMetric[] = ['GIFT_COUNT_SENT'];
export const CATEGORY_SUBJECT_METRICS: readonly TaskMetric[] = ['CATEGORY_GIFTS_SENT'];

/**
 * The metrics whose reward follows a coin value (D188: about 1 % of it): the coin metrics, and the gift / category
 * counts (count × the gift's price, or the category's cheapest price).
 */
export const COIN_VALUED_METRICS: readonly TaskMetric[] = [
  'GIFT_COINS_SENT',
  'HOST_GIFT_COINS',
  'HOST_LUCKY_COINS',
  'GIFT_COUNT_SENT',
  'CATEGORY_GIFTS_SENT',
];

/** The host targets' metrics: since D281 the targets engine owns them, never the Task Center catalogue. */
export const TARGET_METRICS: readonly TaskMetric[] = ['HOST_GIFT_CHERRIES', 'HOST_LUCKY_CHERRIES'];

/** Counts (actions): 40 steps. */
export const TASK_COUNT_LADDER: readonly number[] = [
  1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 12, 14, 15, 16, 18, 20, 25, 30, 35, 40, 45, 50, 60, 70, 75, 80, 90, 100, 120,
  150, 200, 250, 300, 400, 500, 600, 750, 800, 900, 1_000,
];
/** Minutes: 24 steps. */
export const TASK_MINUTES_LADDER: readonly number[] = [
  5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 60, 75, 90, 100, 120, 150, 180, 210, 240, 270, 300, 360, 420, 480,
];
/** Hearts: 25 steps. */
export const TASK_TAPS_LADDER: readonly number[] = [
  10, 20, 30, 40, 50, 60, 75, 80, 100, 120, 150, 200, 250, 300, 400, 500, 600, 750, 800, 1_000, 1_200, 1_500,
  2_000, 2_500, 3_000,
];
/** Coin values: 15 «round» steps per decade from 100 to 9 000 000 (75 steps). */
export const TASK_COIN_LADDER: readonly number[] = (() => {
  const out: number[] = [];
  for (let d = 100; d <= 1_000_000; d *= 10) {
    for (const m of [1, 1.2, 1.5, 1.8, 2, 2.5, 3, 3.5, 4, 4.5, 5, 6, 7, 8, 9]) out.push(Math.round(m * d));
  }
  return out;
})();
/** «Join a family»: done or not. */
export const TASK_ONCE_LADDER: readonly number[] = [1];

export function taskLadderOf(metric: TaskMetric): readonly number[] {
  switch (metric) {
    case 'WATCH_MINUTES':
    case 'HOST_LIVE_MINUTES':
      return TASK_MINUTES_LADDER;
    // v1.94-social (D297): views and likes received run in the hundreds, like hearts.
    case 'LIVE_TAPS':
    case 'REEL_VIEWS_RECEIVED':
    case 'LIKES_RECEIVED':
      return TASK_TAPS_LADDER;
    case 'GIFT_COINS_SENT':
    case 'HOST_GIFT_COINS':
    case 'HOST_LUCKY_COINS':
      return TASK_COIN_LADDER;
    case 'FAMILY_JOIN':
      return TASK_ONCE_LADDER;
    default:
      return TASK_COUNT_LADDER;
  }
}

/** A pool template as the catalogue sees it (a `task_definitions` row with `pool`). */
export interface TaskTemplate {
  readonly code: string;
  readonly metric: TaskMetric;
  readonly group: string;
  readonly audience: TaskAudience;
  readonly bandTargets: readonly number[];
  readonly bandRewards: readonly number[];
  readonly sortOrder: number;
  readonly nameAr: string;
  readonly nameEn: string;
}

/** One generated task. */
export interface TaskVariant {
  readonly code: string;
  readonly template: string;
  readonly subject: string | null;
  readonly amount: number;
  readonly window: TargetWindow;
}

/** `K.<template>.<subject|*>.<amount>.<from>-<to>`. */
export function variantCode(v: Omit<TaskVariant, 'code'>): string {
  return `K.${v.template}.${v.subject ?? '*'}.${String(v.amount)}.${String(v.window.from)}-${String(v.window.to)}`;
}

/** The templates the catalogue generates from: enabled pool rows, never the host targets' metrics. */
export function catalogueTemplates(templates: readonly TaskTemplate[]): TaskTemplate[] {
  return templates.filter((t) => !TARGET_METRICS.includes(t.metric));
}

function subjectsOf(metric: TaskMetric, gifts: readonly CatalogueGift[]): (string | null)[] {
  const paid = gifts.filter((g) => g.priceCoins > 0 && !g.lucky);
  if (GIFT_SUBJECT_METRICS.includes(metric)) return paid.map((g) => g.code).sort();
  if (CATEGORY_SUBJECT_METRICS.includes(metric)) return [...new Set(paid.map((g) => g.category))].sort();
  return [null];
}

/** Every task of the catalogue (deterministic order). */
export function* enumerateTasks(
  templates: readonly TaskTemplate[],
  gifts: readonly CatalogueGift[],
): Generator<TaskVariant> {
  const windows = catalogueWindows();
  for (const t of [...catalogueTemplates(templates)].sort((a, b) => (a.code < b.code ? -1 : 1))) {
    for (const subject of subjectsOf(t.metric, gifts)) {
      for (const amount of taskLadderOf(t.metric)) {
        for (const window of windows) {
          const v = { template: t.code, subject, amount, window };
          yield { code: variantCode(v), ...v };
        }
      }
    }
  }
}

/** The catalogue's size per template (= what enumerateTasks yields). */
export function taskCatalogueStats(
  templates: readonly TaskTemplate[],
  gifts: readonly CatalogueGift[],
): { total: number; templates: number; byTemplate: Record<string, number> } {
  const windows = catalogueWindows().length;
  const byTemplate: Record<string, number> = {};
  let total = 0;
  const list = catalogueTemplates(templates);
  for (const t of list) {
    const n = subjectsOf(t.metric, gifts).length * taskLadderOf(t.metric).length * windows;
    byTemplate[t.code] = n;
    total += n;
  }
  return { total, templates: list.length, byTemplate };
}

/** The template's target and reward in `band` (1…4); the first band that offers it when this one does not. */
function bandValues(t: TaskTemplate, band: number): { target: number; reward: number } {
  const i = band - 1;
  if ((t.bandTargets[i] ?? 0) > 0 && (t.bandRewards[i] ?? 0) > 0)
    return { target: t.bandTargets[i]!, reward: t.bandRewards[i]! };
  for (let k = 0; k < t.bandTargets.length; k++) {
    if ((t.bandTargets[k] ?? 0) > 0 && (t.bandRewards[k] ?? 0) > 0)
      return { target: t.bandTargets[k]!, reward: t.bandRewards[k]! };
  }
  return { target: 0, reward: 0 };
}

/**
 * The reward of a generated task (the Task Center's rules, D188): a coin-valued task pays the template's rate
 * per coin of `coinValue` (= the amount for coin metrics, count × price for a gift) — never more than twice the
 * band's reward; any other task pays the band's reward scaled by amount / the band's target, kept within half
 * and twice the band's reward (free actions stay symbolic). At least 1. The daily and monthly caps apply at
 * the claim as before.
 */
export function variantReward(t: TaskTemplate, band: number, amount: number, coinValue: number): number {
  const { target, reward } = bandValues(t, band);
  if (target <= 0 || reward <= 0) return 0;
  if (COIN_VALUED_METRICS.includes(t.metric)) {
    return Math.max(1, Math.min(2 * reward, Math.floor((coinValue * reward) / target)));
  }
  const ratio = Math.min(2, Math.max(0.5, amount / target));
  return Math.max(1, Math.round(reward * ratio));
}

/** What the task assignment reads about a person. */
export interface TaskProfile {
  readonly band: TaskPoolBand;
  readonly isHost: boolean;
  /**
   * v1.94-social (D297): a creator-programme member — their band's `creatorCount` CREATOR tasks first, never HOSTS tasks
   * (even with the hosting permission D295 gives them). Absent = not a member.
   */
  readonly isCreator?: boolean;
  /** The person's daily average of each metric over the last 7 days (stored data). */
  readonly dailyAverage: Readonly<Partial<Record<TaskMetric, number>>>;
  /** Tasks assigned / claimed over the last 7 days (the completion rate). */
  readonly recentAssigned: number;
  readonly recentClaimed: number;
  /** Variant codes given in the last `noRepeatDays` days, and yesterday's templates. */
  readonly recentVariants: readonly string[];
  readonly yesterdayTemplates: readonly string[];
  /** Whether the person is in a family now (join vs. family chat). */
  readonly inFamily: boolean;
  /** The gifts the person sent most over the history (codes, most first). */
  readonly favouriteGifts: readonly string[];
  /** Activity (live joins) per hour of the day over the history. */
  readonly activeHours: readonly number[];
}

/** One generated task given to the person today. */
export interface TaskVariantPick {
  readonly template: string;
  readonly variant: TaskVariant;
  readonly target: number;
  readonly rewardCherries: number;
  readonly position: number;
  readonly reason: {
    readonly avg7: number;
    readonly bandTarget: number;
    readonly factor: number;
    readonly completionRate: number | null;
    readonly affinity: number;
    readonly why: string;
  };
}

/** The completion factor of the amounts: 0.7 (never finishes) … 1.3 (always does); 1 with fewer than 5 tasks. */
export function taskCompletionFactor(claimed: number, assigned: number): number {
  if (assigned < 5) return 1;
  const r = Math.min(1, Math.max(0, claimed / assigned));
  return Math.round((0.7 + 0.6 * r) * 100) / 100;
}

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

/** The usual hours (≥ 60 % of the activity within 3 hours), or null. */
export function usualWindow(activeHours: readonly number[]): TargetWindow | null {
  const total = activeHours.reduce((a, b) => a + b, 0);
  if (total < 5) return null;
  let best = -1;
  let start = 0;
  for (let s = 0; s + 3 <= 24; s++) {
    const sum = (activeHours[s] ?? 0) + (activeHours[s + 1] ?? 0) + (activeHours[s + 2] ?? 0);
    if (sum > best) {
      best = sum;
      start = s;
    }
  }
  return best / total >= 0.6 ? { from: start * 60, to: (start + 3) * 60 } : null;
}

const WINDOW_GROUPS = new Set(['WATCH', 'LIVE']);

/**
 * A person's tasks of the day, from the enabled templates of their band (target > 0), deterministic for `seed`:
 * 1. Weights: what the person already does weighs more (1 + 2 × min(1, their 7-day daily average / the band's
 *    target)); a template given yesterday weighs × 0.4 (variety); «join a family» only outside a family and the
 *    family chat only inside one; gift tasks only with gifts in the catalogue. A seeded weighted order
 *    (Efraimidis–Spirakis keys).
 * 2. Selection as D176: hosts get up to the band's host count of host tasks first (v1.94-social, D297: creators
 *    the band's creator count of creator tasks, never host tasks); then at most one per group, then two, up to the
 *    band's daily count; never one template twice.
 * 3. The amount: their 7-day daily average × the completion factor (0.7 … 1.3), or the band's target when they
 *    never do it, kept within half and three times the band's target and snapped up to the metric's ladder; a
 *    gift task names their favourite gift (else a seeded paid gift) and counts that gift; one WATCH/LIVE task may
 *    take their usual 3 hours (half the amount).
 * 4. No repeat: a variant given in the last `noRepeatDays` days moves one ladder step up.
 * 5. The reward: {@link variantReward}.
 */
export function assignSmartTasks(
  templates: readonly TaskTemplate[],
  profile: TaskProfile,
  gifts: readonly CatalogueGift[],
  seed: number,
): TaskVariantPick[] {
  const random = generator(seed);
  const band = profile.band;
  const paidGifts = gifts
    .filter((g) => g.priceCoins > 0 && !g.lucky)
    .sort((a, b) => (a.code < b.code ? -1 : 1));
  const role = taskRoleOf(profile.isHost, profile.isCreator ?? false);
  const offered = catalogueTemplates(templates)
    .filter((t) => bandValues(t, band.band).target > 0 && (t.bandTargets[band.band - 1] ?? 0) > 0)
    .filter((t) => audienceOffered(t.audience, role))
    .filter((t) => (t.metric === 'FAMILY_JOIN' ? !profile.inFamily : true))
    .filter((t) => (t.metric === 'FAMILY_CHAT_MESSAGES' ? profile.inFamily : true))
    .filter((t) => (subjectsOf(t.metric, gifts).length > 0 ? true : false))
    .sort((a, b) => a.sortOrder - b.sortOrder || (a.code < b.code ? -1 : 1));
  const yesterday = new Set(profile.yesterdayTemplates);
  const affinity = new Map<string, number>();
  const keyed = offered.map((t) => {
    const { target } = bandValues(t, band.band);
    const avg = profile.dailyAverage[t.metric] ?? 0;
    let w = 1 + 2 * Math.min(1, target > 0 ? avg / target : 0);
    if (yesterday.has(t.code)) w *= 0.4;
    affinity.set(t.code, Math.round(w * 100) / 100);
    return { t, key: Math.pow(random(), 1 / w) };
  });
  keyed.sort((a, b) => b.key - a.key);
  const ordered = keyed.map((k) => k.t);
  const picked: TaskTemplate[] = [];
  const perGroup = new Map<string, number>();
  const take = (pool: readonly TaskTemplate[], limit: number, groupMax: number) => {
    for (const t of pool) {
      if (picked.length >= limit) return;
      if (picked.includes(t) || (perGroup.get(t.group) ?? 0) >= groupMax) continue;
      picked.push(t);
      perGroup.set(t.group, (perGroup.get(t.group) ?? 0) + 1);
    }
  };
  const hostPool = ordered.filter((t) => t.audience === 'HOSTS');
  const creatorPool = ordered.filter((t) => t.audience === 'CREATORS');
  let everyone = ordered.filter((t) => t.audience === 'EVERYONE');
  if (role.host) {
    const hostLimit = Math.min(band.hostCount, band.dailyCount);
    for (const t of hostPool) if (picked.length < hostLimit) picked.push(t);
  }
  if (role.creator) {
    // D297: creator tasks first, like host tasks; none of everyone's tasks counting the same action.
    const creatorLimit = Math.min(band.creatorCount, band.dailyCount);
    for (const t of creatorPool) if (picked.length < creatorLimit) picked.push(t);
    const counted = new Set(picked.map((t) => t.metric));
    everyone = everyone.filter((t) => !counted.has(t.metric));
  }
  take(everyone, band.dailyCount, 1);
  take(everyone, band.dailyCount, 2);
  take(everyone, band.dailyCount, Number.MAX_SAFE_INTEGER);

  const factor = taskCompletionFactor(profile.recentClaimed, profile.recentAssigned);
  const rate =
    profile.recentAssigned > 0
      ? Math.round((profile.recentClaimed / profile.recentAssigned) * 100) / 100
      : null;
  const recent = new Set(profile.recentVariants);
  const usual = usualWindow(profile.activeHours);
  let windowUsed = false;
  const byCode = new Map(paidGifts.map((g) => [g.code, g]));
  return picked.map((t, position) => {
    const { target: bandTarget } = bandValues(t, band.band);
    const avg = profile.dailyAverage[t.metric] ?? 0;
    const ladder = taskLadderOf(t.metric);
    let subject: string | null = null;
    let unitPrice = 1;
    if (GIFT_SUBJECT_METRICS.includes(t.metric)) {
      const fav = profile.favouriteGifts.find((c) => byCode.has(c));
      const g = fav ? byCode.get(fav)! : paidGifts[Math.floor(random() * paidGifts.length)]!;
      subject = g.code;
      unitPrice = g.priceCoins;
    } else if (CATEGORY_SUBJECT_METRICS.includes(t.metric)) {
      const cats = [...new Set(paidGifts.map((g) => g.category))].sort();
      const favCat = profile.favouriteGifts.map((c) => byCode.get(c)?.category).find((c) => c !== undefined);
      subject = favCat ?? cats[Math.floor(random() * cats.length)]!;
      unitPrice = Math.min(...paidGifts.filter((g) => g.category === subject).map((g) => g.priceCoins));
    }
    const subjectCoins = subject !== null;
    // The band target of a gift / category template is a coin value: the count is that value in the gift's price.
    const baseTarget = subjectCoins ? Math.max(1, Math.round(bandTarget / unitPrice)) : bandTarget;
    const base = avg > 0 ? avg * factor : baseTarget;
    let wanted = Math.min(baseTarget * 3, Math.max(baseTarget * 0.5, base));
    let window: TargetWindow = ALL_DAY;
    if (usual && !windowUsed && WINDOW_GROUPS.has(t.group) && random() < 0.35) {
      window = usual;
      windowUsed = true;
      wanted = Math.max(1, wanted / 2);
    }
    let i = ladder.findIndex((s) => s >= wanted);
    if (i < 0) i = ladder.length - 1;
    for (let k = i; k < ladder.length; k++) {
      const code = variantCode({ template: t.code, subject, amount: ladder[k]!, window });
      if (!recent.has(code)) {
        i = k;
        break;
      }
    }
    const amount = ladder[i]!;
    const variant: TaskVariant = {
      code: variantCode({ template: t.code, subject, amount, window }),
      template: t.code,
      subject,
      amount,
      window,
    };
    const coinValue = subjectCoins ? amount * unitPrice : amount;
    const rewardCherries = variantReward(t, band.band, amount, coinValue);
    const why =
      avg > 0
        ? `7-day average ${String(Math.round(avg * 10) / 10)}/day × ${String(factor)} → ${String(amount)}`
        : `Not done lately: the band's target ${String(baseTarget)} → ${String(amount)}`;
    return {
      template: t.code,
      variant,
      target: amount,
      rewardCherries,
      position,
      reason: {
        avg7: Math.round(avg * 10) / 10,
        bandTarget: baseTarget,
        factor,
        completionRate: rate,
        affinity: affinity.get(t.code) ?? 1,
        why: isAllDay(window) ? why : `${why} (${windowLabel(window)})`,
      },
    };
  });
}

/** The seed of a person's tasks of a day. */
export function taskSeed(userId: string, day: string): number {
  return seedOf(`tasks:${userId}:${day}`);
}

/**
 * The generated task's name: the template's, with the amount, the gift or category and the window, e.g.
 * «أرسل 10 من الوردة» / «شاهد البث (بالدقائق) · 30 · 20:00–23:00».
 */
export function variantName(
  t: Pick<TaskTemplate, 'metric' | 'nameAr' | 'nameEn'>,
  v: Pick<TaskVariant, 'amount' | 'window' | 'subject'>,
  names: { ar?: string; en?: string },
): { ar: string; en: string } {
  const a = v.amount.toLocaleString('en-US');
  const winAr = isAllDay(v.window) ? '' : ` ${windowLabelAr(v.window)}`;
  const winEn = isAllDay(v.window) ? '' : ` between ${windowLabel(v.window)}`;
  if (GIFT_SUBJECT_METRICS.includes(t.metric)) {
    return {
      ar: `أرسل ${a} من ${names.ar ?? v.subject ?? ''}${winAr}`,
      en: `Send ${a} × ${names.en ?? v.subject ?? ''}${winEn}`,
    };
  }
  if (CATEGORY_SUBJECT_METRICS.includes(t.metric)) {
    return {
      ar: `أرسل ${a} هدية من فئة ${names.ar ?? v.subject ?? ''}${winAr}`,
      en: `Send ${a} gifts from ${names.en ?? v.subject ?? ''}${winEn}`,
    };
  }
  return { ar: `${t.nameAr}${winAr}`, en: `${t.nameEn}${winEn}` };
}
