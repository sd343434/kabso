/**
 * D297 follow-up (owner 2026-11-06: «قم بتوليد 300 ألف مهمة لصانع المحتوى و300 ألف مهمة للمضيف، بحيث يعطي النظام المهام حسب
 * المستوى وتدريجياً»; the level: «مستوى الشخص للجاذبية»; CONVENTIONS §10.110.1): a deterministic procedural catalogue of
 * Task Center tasks for content creators (audience CREATORS) and hosts (audience HOSTS) — never materialised as rows.
 *
 * A generated task is an ENTRY (one metric and one period of one audience; its `task_definitions` template row is
 * `G_CR_<METRIC>_<D|W>` / `G_HO_<METRIC>_<D|W>`) × a CHARM LEVEL 0…100 (the person's own `ATTRACTIVENESS` level; none = 0)
 * × a difficulty STEP 0…12 (×0.5 … ×2, geometric) × a WORDING variant 0…14 (5 openings × 3 endings, ar/en). Its code
 * is `G.<CR|HO>.<METRIC>.<D|W>.<level>.<step>.<variant>` (stored in `task_assignments.variant`; claims stay keyed by the
 * template code and the period start, so they pay once per period as every task). 16 entries × 101 × 13 × 15 = 315 120
 * tasks per audience.
 *
 * The level curve: target = t0 × (t60 / t0)^(level / 60) × the step's factor (rounded — from 100 to two significant
 * digits —, ≥ 1, ≤ the entry's max): smooth
 * and rising with every level (band 1's value at level 0, band 4's at level 60, on to level 100). The reward rises
 * linearly from r0 (level 0) to r60 (level 60), then stays, × the step's factor kept within ¾ … 1½; a coin-valued
 * task never pays more than 0.1 cherry a coin (D188's ≈ 1 % of the value); the daily and monthly caps bound a single
 * reward and still apply at the claim. Pure rules only (no Nest, no database): the API, `task-admin` and the tests.
 */
import type { TaskMetric } from './programs-rules.js';

export type GenAudience = 'CREATORS' | 'HOSTS';
export type GenPeriod = 'DAILY' | 'WEEKLY';

/** The charm levels the curve distinguishes (higher levels use level 100's values). */
export const GEN_LEVEL_MAX = 100;
/** The level at which an entry reaches its "band 4" target and reward. */
export const GEN_LEVEL_PIVOT = 60;
/** Difficulty steps: factor 2^((step − 6) / 6), 0.5 … 2. */
export const GEN_STEPS = 13;
export const GEN_DEFAULT_STEP = 6;
/** How many weekly generated tasks a person gets (owner: creators 6, hosts 4). */
export const GEN_WEEKLY_COUNT: Readonly<Record<GenAudience, number>> = { CREATORS: 6, HOSTS: 4 };
/** A coin-valued task pays at most this many cherries per coin (D188: ≈ 1 % of the coins' value). */
export const GEN_CHERRIES_PER_COIN = 0.1;

/** One metric and one period of one audience (a template row). */
export interface GenEntry {
  readonly audience: GenAudience;
  readonly metric: TaskMetric;
  readonly period: GenPeriod;
  /** Target at level 0 and at level 60 (the curve goes on to level 100). */
  readonly t0: number;
  readonly t60: number;
  /** Reward (cherries) at level 0 and from level 60. */
  readonly r0: number;
  readonly r60: number;
  /** The highest sensible target (days in a week…). */
  readonly max?: number;
  /** The target is a coin value (the reward ≤ 0.1 cherry a coin). */
  readonly coinValued?: boolean;
}

const e = (
  audience: GenAudience,
  metric: TaskMetric,
  period: GenPeriod,
  t0: number,
  t60: number,
  r0: number,
  r60: number,
  extra: { max?: number; coinValued?: boolean } = {},
): GenEntry => ({ audience, metric, period, t0, t60, r0, r60, ...extra });

/**
 * The catalogue's entries. Daily values mirror the creator / host pool templates (band 1 → band 4), weekly ones the
 * weekly host tasks' two ladders (production 180 000 → 250 000; audience or money 220 000 → 430 000).
 */
export const GEN_ENTRIES: readonly GenEntry[] = [
  // ---- Content creators, daily
  e('CREATORS', 'REELS', 'DAILY', 1, 2, 4_000, 10_000),
  e('CREATORS', 'POSTS', 'DAILY', 1, 3, 2_000, 6_000),
  e('CREATORS', 'STORIES', 'DAILY', 1, 5, 2_000, 6_000),
  e('CREATORS', 'REEL_VIEWS_RECEIVED', 'DAILY', 100, 1_000, 3_000, 8_000),
  e('CREATORS', 'LIKES_RECEIVED', 'DAILY', 20, 200, 3_000, 8_000),
  e('CREATORS', 'COMMENT_REPLIES', 'DAILY', 3, 20, 2_000, 6_000),
  e('CREATORS', 'NEW_FOLLOWERS', 'DAILY', 2, 10, 2_000, 6_000),
  e('CREATORS', 'SHARES_RECEIVED', 'DAILY', 1, 5, 2_000, 6_000),
  // ---- Content creators, weekly
  e('CREATORS', 'REELS', 'WEEKLY', 5, 10, 180_000, 250_000),
  e('CREATORS', 'POSTS', 'WEEKLY', 5, 10, 180_000, 250_000),
  e('CREATORS', 'STORIES', 'WEEKLY', 5, 10, 180_000, 250_000),
  e('CREATORS', 'REEL_VIEWS_RECEIVED', 'WEEKLY', 5_000, 10_000, 180_000, 250_000),
  e('CREATORS', 'LIKES_RECEIVED', 'WEEKLY', 200, 400, 220_000, 430_000),
  e('CREATORS', 'COMMENT_REPLIES', 'WEEKLY', 20, 40, 180_000, 250_000),
  e('CREATORS', 'NEW_FOLLOWERS', 'WEEKLY', 50, 100, 220_000, 430_000),
  e('CREATORS', 'SHARES_RECEIVED', 'WEEKLY', 20, 40, 220_000, 430_000),
  // ---- Hosts, daily
  e('HOSTS', 'HOST_LIVE_MINUTES', 'DAILY', 60, 120, 4_000, 10_000, { max: 1_440 }),
  e('HOSTS', 'HOST_LIVE_DAYS', 'DAILY', 1, 1, 2_000, 4_000, { max: 1 }),
  e('HOSTS', 'HOST_GUESTS', 'DAILY', 1, 3, 2_000, 6_000),
  e('HOSTS', 'PK_BATTLES', 'DAILY', 1, 5, 2_000, 6_000),
  e('HOSTS', 'PK_WINS', 'DAILY', 1, 3, 3_000, 8_000),
  e('HOSTS', 'HOST_GIFTS_RECEIVED', 'DAILY', 3, 20, 3_000, 8_000),
  e('HOSTS', 'HOST_GIFT_COINS', 'DAILY', 100_000, 1_000_000, 10_000, 60_000, { coinValued: true }),
  e('HOSTS', 'NEW_FOLLOWERS', 'DAILY', 2, 10, 2_000, 6_000),
  // ---- Hosts, weekly
  e('HOSTS', 'HOST_LIVE_MINUTES', 'WEEKLY', 300, 600, 180_000, 250_000, { max: 10_080 }),
  e('HOSTS', 'HOST_LIVE_DAYS', 'WEEKLY', 3, 6, 180_000, 250_000, { max: 7 }),
  e('HOSTS', 'HOST_GUESTS', 'WEEKLY', 5, 15, 180_000, 250_000),
  e('HOSTS', 'PK_BATTLES', 'WEEKLY', 5, 15, 180_000, 250_000),
  e('HOSTS', 'PK_WINS', 'WEEKLY', 3, 8, 180_000, 250_000),
  e('HOSTS', 'HOST_GIFTS_RECEIVED', 'WEEKLY', 20, 100, 220_000, 430_000),
  e('HOSTS', 'HOST_GIFT_COINS', 'WEEKLY', 2_500_000, 5_000_000, 220_000, 430_000, { coinValued: true }),
  e('HOSTS', 'NEW_FOLLOWERS', 'WEEKLY', 30, 100, 180_000, 250_000),
];

const AUD = { CREATORS: 'CR', HOSTS: 'HO' } as const;
const PER = { DAILY: 'D', WEEKLY: 'W' } as const;

/** The `task_definitions` template row of an entry, e.g. `G_CR_REELS_D`. */
export function genTemplateCode(entry: Pick<GenEntry, 'audience' | 'metric' | 'period'>): string {
  return `G_${AUD[entry.audience]}_${entry.metric}_${PER[entry.period]}`;
}

/** Template codes are reserved for the generator: never offered as fixed tasks. */
export function isGenTemplateCode(code: string): boolean {
  return /^G_(CR|HO)_[A-Z_]+_[DW]$/.test(code);
}

/** The entry of a template code, or undefined. */
export function genEntryOf(code: string): GenEntry | undefined {
  return GEN_ENTRIES.find((x) => genTemplateCode(x) === code);
}

/** A generated task's code: `G.<CR|HO>.<METRIC>.<D|W>.<level>.<step>.<variant>`. */
export function genVariantCode(entry: GenEntry, level: number, step: number, variant: number): string {
  return `G.${AUD[entry.audience]}.${entry.metric}.${PER[entry.period]}.${String(level)}.${String(step)}.${String(variant)}`;
}

/** The level the curve reads: the charm level, whole, 0 … 100 (none = 0). */
export function genLevel(charmLevel: number | null | undefined): number {
  const l = Math.floor(charmLevel ?? 0);
  return Math.min(GEN_LEVEL_MAX, Math.max(0, Number.isFinite(l) ? l : 0));
}

export function genStepFactor(step: number): number {
  return 2 ** ((step - GEN_DEFAULT_STEP) / 6);
}

/** Below 100 a whole number; from 100 two significant digits (413 519 → 410 000): readable, still rising. */
function nice(x: number): number {
  if (x < 100) return Math.round(x);
  const unit = 10 ** (Math.floor(Math.log10(x)) - 1);
  return Math.round(x / unit) * unit;
}

/** The target of an entry at a level and step (rises with the level, never falls). */
export function genTarget(entry: GenEntry, level: number, step: number): number {
  const l = genLevel(level);
  const curve = entry.t0 * (entry.t60 / entry.t0) ** (l / GEN_LEVEL_PIVOT);
  const t = Math.max(1, nice(curve * genStepFactor(step)));
  return entry.max === undefined ? t : Math.min(entry.max, t);
}

/** The caps that bound one reward (the claim applies them again with what was already earned). */
export interface GenCaps {
  readonly dailyCherries: number;
  /** 0 = no monthly cap. */
  readonly monthlyCherries: number;
}

/** The reward of an entry at a level and step (cherries, rising with the level, within the rules and caps). */
export function genReward(entry: GenEntry, level: number, step: number, caps?: GenCaps): number {
  const l = genLevel(level);
  const base = entry.r0 + ((entry.r60 - entry.r0) * Math.min(l, GEN_LEVEL_PIVOT)) / GEN_LEVEL_PIVOT;
  const factor = Math.min(1.5, Math.max(0.75, genStepFactor(step)));
  let r = Math.max(10, Math.round((base * factor) / 10) * 10);
  if (entry.coinValued) r = Math.min(r, Math.floor(genTarget(entry, l, step) * GEN_CHERRIES_PER_COIN));
  if (caps) {
    if (entry.period === 'DAILY') r = Math.min(r, caps.dailyCherries);
    else if (caps.monthlyCherries > 0) r = Math.min(r, caps.monthlyCherries);
  }
  return Math.max(1, r);
}

// ---- Wording: 5 openings × 3 endings, then the metric's phrase and the period ---------------------------------

const LEADS: readonly (readonly [string, string])[] = [
  ['مهمتك', 'Your task'],
  ['تحدّي', 'Challenge'],
  ['هدفك', 'Your goal'],
  ['انطلق', 'Go for it'],
  ['خطوة جديدة', 'Next step'],
];
const TAILS: readonly (readonly [string, string])[] = [
  ['', ''],
  [' وارتقِ بمستواك', ' and level up'],
  [' — أنت قادر', ' — you can do it'],
];
export const GEN_VARIANTS = LEADS.length * TAILS.length;

const PHRASES: Readonly<Partial<Record<TaskMetric, readonly [string, string]>>> = {
  REELS: ['انشر مقاطع ريلز', 'publish reels'],
  POSTS: ['انشر منشورات', 'publish posts'],
  STORIES: ['انشر قصصاً', 'publish stories'],
  REEL_VIEWS_RECEIVED: ['اجمع مشاهدات على ريلزك', 'get views on your reels'],
  LIKES_RECEIVED: ['اجمع إعجابات على محتواك', 'get likes on your content'],
  COMMENT_REPLIES: ['ردّ على تعليقات متابعيك', 'reply to your followers’ comments'],
  NEW_FOLLOWERS: ['اكسب متابعين جدداً', 'gain new followers'],
  SHARES_RECEIVED: ['اجعلهم يشاركون محتواك', 'get your content shared'],
  HOST_LIVE_MINUTES: ['ابثّ مباشرة (بالدقائق)', 'go live (minutes)'],
  HOST_LIVE_DAYS: ['ابثّ في أيام مختلفة', 'go live on different days'],
  HOST_GUESTS: ['اقبل ضيوفاً على المقاعد', 'accept guests on seats'],
  PK_BATTLES: ['ادخل معارك PK', 'enter PK battles'],
  PK_WINS: ['اربح معارك PK', 'win PK battles'],
  HOST_GIFTS_RECEIVED: ['استقبل هدايا', 'receive gifts'],
  HOST_GIFT_COINS: ['استقبل هدايا (بالعملات)', 'receive gifts (coins)'],
};

/** Where the daily wording differs (one live day is «today»). */
const DAILY_PHRASES: Readonly<Partial<Record<TaskMetric, readonly [string, string]>>> = {
  HOST_LIVE_DAYS: ['ابثّ 10 دقائق على الأقل', 'go live for 10 minutes or more'],
};

/** A generated task's name, e.g. «هدفك: انشر مقاطع ريلز اليوم» / "Your goal: publish reels today". */
export function genName(entry: GenEntry, variant: number): { ar: string; en: string } {
  const v = ((variant % GEN_VARIANTS) + GEN_VARIANTS) % GEN_VARIANTS;
  const [leadAr, leadEn] = LEADS[Math.floor(v / TAILS.length)]!;
  const [tailAr, tailEn] = TAILS[v % TAILS.length]!;
  const [ar, en] = (entry.period === 'DAILY' ? DAILY_PHRASES[entry.metric] : undefined) ??
    PHRASES[entry.metric] ?? [entry.metric, entry.metric];
  const [perAr, perEn] = entry.period === 'DAILY' ? ['اليوم', 'today'] : ['هذا الأسبوع', 'this week'];
  return { ar: `${leadAr}: ${ar} ${perAr}${tailAr}`, en: `${leadEn}: ${en} ${perEn}${tailEn}` };
}

// ---- The catalogue's size and contents (never stored) ----------------------------------------------------------

export function genEntriesOf(audience: GenAudience): GenEntry[] {
  return GEN_ENTRIES.filter((x) => x.audience === audience);
}

/** How many distinct generated tasks an audience has (entries × levels × steps × variants). */
export function genCatalogueCount(audience: GenAudience): number {
  return genEntriesOf(audience).length * (GEN_LEVEL_MAX + 1) * GEN_STEPS * GEN_VARIANTS;
}

/** One generated task with its values. */
export interface GenTask {
  readonly code: string;
  readonly template: string;
  readonly entry: GenEntry;
  readonly level: number;
  readonly step: number;
  readonly variant: number;
  readonly target: number;
  readonly rewardCherries: number;
  readonly nameAr: string;
  readonly nameEn: string;
}

export function genTask(
  entry: GenEntry,
  level: number,
  step: number,
  variant: number,
  caps?: GenCaps,
): GenTask {
  const l = genLevel(level);
  const names = genName(entry, variant);
  return {
    code: genVariantCode(entry, l, step, variant),
    template: genTemplateCode(entry),
    entry,
    level: l,
    step,
    variant,
    target: genTarget(entry, l, step),
    rewardCherries: genReward(entry, l, step, caps),
    nameAr: names.ar,
    nameEn: names.en,
  };
}

/** Every generated code of an audience, in a fixed order (codes only: cheap to count and hash). */
export function* enumerateGenCodes(audience: GenAudience): Generator<string> {
  for (const entry of genEntriesOf(audience)) {
    for (let level = 0; level <= GEN_LEVEL_MAX; level++) {
      for (let step = 0; step < GEN_STEPS; step++) {
        for (let v = 0; v < GEN_VARIANTS; v++) yield genVariantCode(entry, level, step, v);
      }
    }
  }
}

/** The `index`-th generated task of an audience (0 … count − 1), for samples. */
export function genTaskAt(audience: GenAudience, index: number, caps?: GenCaps): GenTask {
  const entries = genEntriesOf(audience);
  const per = (GEN_LEVEL_MAX + 1) * GEN_STEPS * GEN_VARIANTS;
  const i = ((index % (entries.length * per)) + entries.length * per) % (entries.length * per);
  const entry = entries[Math.floor(i / per)]!;
  const rest = i % per;
  const level = Math.floor(rest / (GEN_STEPS * GEN_VARIANTS));
  const step = Math.floor((rest % (GEN_STEPS * GEN_VARIANTS)) / GEN_VARIANTS);
  return genTask(entry, level, step, rest % GEN_VARIANTS, caps);
}

// ---- The assignment ---------------------------------------------------------------------------------------------

function fnv(text: string): number {
  let h = 0x811c9dc5;
  for (let i = 0; i < text.length; i++) {
    h ^= text.charCodeAt(i);
    h = Math.imul(h, 0x01000193) >>> 0;
  }
  return h >>> 0;
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

/** What the assignment reads about the person and the period. */
export interface GenAssignInput {
  readonly audience: GenAudience;
  readonly period: GenPeriod;
  /** The enabled template codes of this audience and period (`task-admin generator on|off`, `set --enabled`). */
  readonly templates: readonly string[];
  readonly userId: string;
  /** The day (`YYYY-MM-DD`) or the ISO week's first day. */
  readonly periodKey: string;
  /** The person's charm level now (none = 0). */
  readonly charmLevel: number;
  readonly count: number;
  /** Metrics another task of the same period already counts (never two tasks for one action). */
  readonly avoidMetrics?: ReadonlySet<string>;
  /** The previous period's generated codes and metrics (variety: not the same task again, its metric last). */
  readonly previousCodes?: ReadonlySet<string>;
  readonly previousMetrics?: ReadonlySet<string>;
  readonly caps?: GenCaps;
}

/**
 * A person's generated tasks of a period, deterministic for the person and the period: the enabled entries in a
 * seeded order (metrics of the previous period last; never one another task of the period counts), the first `count`
 * (one per metric); each at the person's charm level, a step around the middle (5 … 7: the curve does the rising) and
 * a seeded wording — never the previous period's exact task (the wording moves on).
 */
export function assignGenerated(input: GenAssignInput): GenTask[] {
  const random = generator(fnv(`gen:${input.audience}:${input.period}:${input.userId}:${input.periodKey}`));
  const enabled = new Set(input.templates);
  const entries = genEntriesOf(input.audience)
    .filter((x) => x.period === input.period && enabled.has(genTemplateCode(x)))
    .filter((x) => !(input.avoidMetrics?.has(x.metric) ?? false))
    .sort((a, b) => (genTemplateCode(a) < genTemplateCode(b) ? -1 : 1));
  for (let k = entries.length - 1; k > 0; k--) {
    const j = Math.floor(random() * (k + 1));
    [entries[k], entries[j]] = [entries[j]!, entries[k]!];
  }
  const fresh = entries.filter((x) => !(input.previousMetrics?.has(x.metric) ?? false));
  const again = entries.filter((x) => input.previousMetrics?.has(x.metric) ?? false);
  const level = genLevel(input.charmLevel);
  return [...fresh, ...again].slice(0, Math.max(0, input.count)).map((entry) => {
    const step = GEN_DEFAULT_STEP - 1 + Math.floor(random() * 3);
    let variant = Math.floor(random() * GEN_VARIANTS);
    for (
      let k = 0;
      k < GEN_VARIANTS && input.previousCodes?.has(genVariantCode(entry, level, step, variant));
      k++
    ) {
      variant = (variant + 1) % GEN_VARIANTS;
    }
    return genTask(entry, level, step, variant, input.caps);
  });
}
