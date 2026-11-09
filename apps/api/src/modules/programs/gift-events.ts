/**
 * v1.97-social (D303, owner 2026-11-07, CONVENTIONS §10.114): gift events «فعاليات الهدايا». An event of metric
 * `EVENT_GIFTS` scores only its own gifts (`event_gifts`: points per coin and per gift) sent in its window, on one or
 * more typed boards (`event_boards`), each with a qualification minimum and prize bundles per rank range. Created and
 * edited from the admin panel and from the app's staff tools (capability `events.manage`) through the same rules here;
 * frozen and paid automatically at the end by the events sweeper (unless held), once per result and winner.
 */
import { z } from 'zod';
import { auditBy, type AdminVia } from '../../common/audit/admin-actor.js';
import { AuditAction } from '../../common/audit/audit.service.js';
import { Prisma, type Event } from '../../generated/prisma/client.js';
import { addItemTimeIn, catalogueItemIn, lockItemHoldersIn } from '../bag/bag-grants.js';
import { creditEventPrizeCherriesIn } from '../economy/cherry-ledger.js';
import { grantStockIn } from '../gifts/gift-catalogue.js';
import { creditIn } from '../wallet/wallet-ledger.js';
import { EVENT_TONES, EventAdminError } from './event-admin-rules.js';
import { EVENT_LEADERBOARD_MAX } from './programs-rules.js';

type Tx = Prisma.TransactionClient;

const DAY_MS = 86_400_000;

/**
 * The board kinds (CHECK `event_boards_kind`): SENDERS «ترتيب الداعمين» (who sent the event gifts), RECEIVERS «ترتيب
 * المضيفين» (approved hosts and content-creator members who received them — the D303 follow-up overrides D295 for gift
 * events), CREATORS «صناع المحتوى» (creator members who
 * received them), AGENCIES «الوكالات» (the receiving host's agency at the time of the gift; the prize to its owner) and CP
 * (the event gifts two partners sent each other while a couple; both partners win the bundle).
 */
export const EVENT_BOARD_KINDS = ['SENDERS', 'RECEIVERS', 'CREATORS', 'AGENCIES', 'CP'] as const;
export type EventBoardKind = (typeof EVENT_BOARD_KINDS)[number];

/**
 * v1.97-social (D303 follow-up): `BADGE` — an event badge «وسام فعالية» with its own picture, for N days. v1.101-social
 * (D325): `GIFT_PIECES` — free pieces of one of the event's own exclusive gifts in the winner's gift bag.
 */
export const PRIZE_ITEM_TYPES = [
  'COINS',
  'CHERRIES',
  'CP_MONEY',
  'BAG_ITEM',
  'VIP',
  'BADGE',
  'GIFT_PIECES',
] as const;

/** v1.101-social (D325, §10.127): the event's lifecycle, recurrence, scoring method and counted gifts. */
export const EVENT_STATUSES = ['DRAFT', 'PUBLISHED'] as const;
export type EventLifecycle = (typeof EVENT_STATUSES)[number];
export const EVENT_RECURRENCES = ['NONE', 'WEEKLY', 'MONTHLY'] as const;
export type EventRecurrence = (typeof EVENT_RECURRENCES)[number];
/** COINS: points = the coins of each counted gift; MULTIPLIER: each event gift its own points per coin (a decimal). */
export const EVENT_SCORINGS = ['COINS', 'MULTIPLIER'] as const;
export type EventScoring = (typeof EVENT_SCORINGS)[number];
/** EVENT_GIFTS: only the event's gifts score; ALL_GIFTS: every gift (a gift not listed counts its coins × 1). */
export const EVENT_COUNTED_GIFTS = ['EVENT_GIFTS', 'ALL_GIFTS'] as const;
export type EventCountedGifts = (typeof EVENT_COUNTED_GIFTS)[number];
/** v1.101-social (D325): who an event is for (visibility and the start notification). */
export const EVENT_AUDIENCES = ['EVERYONE', 'HOSTS', 'CREATORS', 'AGENCIES', 'CP'] as const;
export type EventAudience = (typeof EVENT_AUDIENCES)[number];
/**
 * The boards show the top 20 (owner, D325), the caller's own place pinned below. v1.102-social (D334): «عدد المعروضين»
 * per board (`event_boards.shown`, 1–100; this default), D303's boards included.
 */
export const EVENT_BOARD_SHOWN = 20;
export const EVENT_BOARD_SHOWN_MAX = 100;
export type PrizeItemType = (typeof PRIZE_ITEM_TYPES)[number];

/**
 * Owner (D303 follow-ups, decided): the money a board gives — RECEIVERS (hosts and creators) and CREATORS win
 * CHERRIES; SENDERS win COINS; AGENCIES either (chosen per line); CP lines carry `CP_MONEY` — two amounts set by the
 * event's creator, cherries for a partner who is an approved host or creator and coins for a partner who is not
 * (the role read at payout time; never converted). Items, medals and VIP on every board.
 */
export const BOARD_MONEY_ALLOWED: Readonly<Record<EventBoardKind, readonly string[]>> = {
  SENDERS: ['COINS'],
  RECEIVERS: ['CHERRIES'],
  CREATORS: ['CHERRIES'],
  AGENCIES: ['COINS', 'CHERRIES'],
  CP: ['CP_MONEY'],
};
const MONEY_TYPES = ['COINS', 'CHERRIES', 'CP_MONEY'];

/** Limits (§10.114.1). */
export const GIFT_EVENT_LIMITS = {
  gifts: 12,
  boards: EVENT_BOARD_KINDS.length,
  prizeLines: 20,
  itemsPerLine: 6,
  maxAmount: 100_000_000,
  maxDays: 365,
  maxPointsPerCoin: 1000,
  maxPointsPerGift: 1_000_000,
  maxMinPoints: 1_000_000_000_000,
  /** The longest event (days) and how far ahead it may start (days). */
  maxLengthDays: 92,
  maxLeadDays: 365,
  /** v1.101-social (D325): milestones per event, pieces of an exclusive gift per prize line. */
  milestones: 10,
  maxGiftPieces: 100_000,
} as const;

export type PrizeItem =
  | { readonly type: 'COINS'; readonly amount: number }
  | { readonly type: 'CHERRIES'; readonly amount: number }
  | { readonly type: 'CP_MONEY'; readonly cherries: number; readonly coins: number }
  /** `days` null = permanent «دائم» (owner, D303 follow-up). */
  | { readonly type: 'BAG_ITEM'; readonly itemCode: string; readonly days: number | null }
  | { readonly type: 'VIP'; readonly tierCode: string; readonly days: number }
  | {
      readonly type: 'BADGE';
      readonly badgeCode: string;
      readonly level: number;
      readonly days: number | null;
    }
  /** v1.101-social (D325): `count` free pieces of the event's exclusive gift `giftCode` in the gift bag. */
  | { readonly type: 'GIFT_PIECES'; readonly giftCode: string; readonly count: number };

/** v1.101-social (D325): every prize item may carry its display picture on the event page (an uploaded `prize`). */
export type PrizeItemWithDisplay = PrizeItem & { readonly displayKey?: string | null };

export interface PrizeLine {
  readonly rankFrom: number;
  readonly rankTo: number;
  readonly items: readonly PrizeItem[];
}

/** An event badge's code (CHECK `event_badges_shape`). */
export const EVENT_BADGE_CODE = /^[a-z0-9_]{2,40}$/;
/** The uploaded event art per slot (CHECK `events_art_keys`, `event_badges_shape`; `event-media.ts` writes them). */
export const EVENT_ART_KEYS = {
  background: /^media\/events\/bg\/[0-9a-f-]{36}(\.anim)?\.(webp|mp4|mov)$/,
  poster: /^media\/events\/bg\/[0-9a-f-]{36}\.webp$/,
  // v1.101-social (D325): an animated (WebP) or Lottie title; an alpha-MP4 overlay.
  title: /^media\/events\/title\/[0-9a-f-]{36}((\.anim)?\.webp|\.json)$/,
  overlay: /^media\/events\/overlay\/[0-9a-f-]{36}\.(svga|json|mp4)$/,
  badge: /^media\/events\/badge\/[0-9a-f-]{36}\.webp$/,
  /** v1.101-social (D325): a prize's display picture on the event page. */
  prize: /^media\/events\/prize\/[0-9a-f-]{36}\.webp$/,
} as const;

const amount = z.number().int().min(1).max(GIFT_EVENT_LIMITS.maxAmount);
const days = z.number().int().min(1).max(GIFT_EVENT_LIMITS.maxDays);
const code = z
  .string()
  .trim()
  .regex(/^[A-Za-z0-9_.-]{1,40}$/);

/** v1.101-social (D325): the optional display picture of a prize item (an uploaded `prize`). */
const displayKey = z.string().regex(EVENT_ART_KEYS.prize).nullable().optional();

export const prizeItemSchema = z.discriminatedUnion('type', [
  z.strictObject({ type: z.literal('COINS'), amount, displayKey }),
  z.strictObject({ type: z.literal('CHERRIES'), amount, displayKey }),
  z
    .strictObject({
      type: z.literal('CP_MONEY'),
      cherries: z.number().int().min(0).max(GIFT_EVENT_LIMITS.maxAmount),
      coins: z.number().int().min(0).max(GIFT_EVENT_LIMITS.maxAmount),
      displayKey,
    })
    .refine((v) => v.cherries > 0 || v.coins > 0, { message: 'cherries or coins above 0' }),
  // Owner (D303 follow-up): an item or a medal may be permanent («دائم»: `days: null`); VIP stays days-only (a
  // membership always ends: `vip_memberships.expires_at` is required).
  z.strictObject({ type: z.literal('BAG_ITEM'), itemCode: code, days: days.nullable(), displayKey }),
  z.strictObject({ type: z.literal('VIP'), tierCode: code, days, displayKey }),
  z.strictObject({
    type: z.literal('BADGE'),
    badgeCode: z.string().regex(EVENT_BADGE_CODE),
    level: z.number().int().min(1).max(10).default(1),
    days: days.nullable(),
    displayKey,
  }),
  // v1.101-social (D325): free pieces of the event's own exclusive gift (owner 1b: pieces in the bag, never bought).
  z.strictObject({
    type: z.literal('GIFT_PIECES'),
    giftCode: code,
    count: z.number().int().min(1).max(GIFT_EVENT_LIMITS.maxGiftPieces),
    displayKey,
  }),
]);

export const prizeLineSchema = z.strictObject({
  rankFrom: z.number().int().min(1).max(EVENT_LEADERBOARD_MAX),
  rankTo: z.number().int().min(1).max(EVENT_LEADERBOARD_MAX),
  items: z.array(prizeItemSchema).min(1).max(GIFT_EVENT_LIMITS.itemsPerLine),
});

const isoInstant = z.iso.datetime({ offset: true });
const text = (max: number) => z.string().trim().max(max);

/** v1.101-social (D325): a milestone «مرحلة» — a board's points threshold and the bundle each entrant reaching it gets. */
export const milestoneSchema = z.strictObject({
  board: z.enum(EVENT_BOARD_KINDS).default('SENDERS'),
  points: z.number().int().min(1).max(GIFT_EVENT_LIMITS.maxMinPoints),
  prizes: z.array(prizeItemSchema).min(1).max(GIFT_EVENT_LIMITS.itemsPerLine),
});
export type MilestoneInput = z.infer<typeof milestoneSchema>;

/** v1.101-social (D325): a points multiplier with at most two decimals (1, 1.2, 1.5 …). */
const multiplier = z
  .number()
  .min(0)
  .max(GIFT_EVENT_LIMITS.maxPointsPerCoin)
  .refine((v) => Math.abs(Math.round(v * 100) - v * 100) < 1e-6, {
    message: 'at most two decimals',
    params: { issue: 'invalid_value' },
  });

/** `GiftEventInput` (openapi): the body of a create or a full edit, from the panel and from the app. */
export const giftEventInputSchema = z
  .strictObject({
    titleAr: text(120).min(1),
    titleEn: text(120).min(1),
    rulesAr: text(4000).default(''),
    rulesEn: text(4000).default(''),
    summaryAr: text(80).nullable().optional(),
    summaryEn: text(80).nullable().optional(),
    tone: z.enum(EVENT_TONES).nullable().optional(),
    bannerUrl: z
      .url({ protocol: /^https$/ })
      .max(2048)
      .nullable()
      .optional(),
    /**
     * v1.101-social (D325): DRAFT (dates and the rest may wait) or PUBLISHED (the default, as D303's body always was).
     * A draft's dates may be null; a published event needs a start, and an end unless permanent.
     */
    status: z.enum(EVENT_STATUSES).default('PUBLISHED'),
    startsAt: isoInstant.nullable(),
    endsAt: isoInstant.nullable(),
    /** v1.101-social (D325): no end (a recurring event that restarts until ended, or a board ended with «end»). */
    permanent: z.boolean().default(false),
    recurrence: z.enum(EVENT_RECURRENCES).default('NONE'),
    scoring: z.enum(EVENT_SCORINGS).default('MULTIPLIER'),
    countedGifts: z.enum(EVENT_COUNTED_GIFTS).default('EVENT_GIFTS'),
    timeZone: z.string().trim().min(1).max(64).nullable().optional(),
    audience: z.enum(EVENT_AUDIENCES).default('EVERYONE'),
    /** v1.101-social (D325): the Live home banner (a `banner` upload's media id), made a banner at publish. */
    bannerMediaId: z.uuid().nullable().optional(),
    regions: z
      .array(z.string().regex(/^[A-Za-z]{2}$/))
      .max(50)
      .default([]),
    featured: z.boolean().default(false),
    /** D303 follow-ups: the page art (uploaded event media, the published specs), null for none. */
    backgroundKey: z.string().regex(EVENT_ART_KEYS.background).nullable().optional(),
    backgroundPosterKey: z.string().regex(EVENT_ART_KEYS.poster).nullable().optional(),
    titleKey: z.string().regex(EVENT_ART_KEYS.title).nullable().optional(),
    overlayKey: z.string().regex(EVENT_ART_KEYS.overlay).nullable().optional(),
    gifts: z
      .array(
        z.strictObject({
          giftCode: code,
          // v1.101-social (D325, owner «method 2»): the points multiplier per coin, a decimal (×1.2, ×1.5).
          pointsPerCoin: multiplier.default(1),
          pointsPerGift: z.number().int().min(0).max(GIFT_EVENT_LIMITS.maxPointsPerGift).default(0),
        }),
      )
      .max(GIFT_EVENT_LIMITS.gifts)
      .default([]),
    boards: z
      .array(
        z.strictObject({
          kind: z.enum(EVENT_BOARD_KINDS),
          minPoints: z.number().int().min(0).max(GIFT_EVENT_LIMITS.maxMinPoints).default(0),
          prizes: z.array(prizeLineSchema).max(GIFT_EVENT_LIMITS.prizeLines).default([]),
          /**
           * v1.102-social (D334): «عدد المعروضين» — how many places the board lists (1–100). Absent: kept on an edit, 20
           * on a new board. A display setting: it may change while the event runs.
           */
          shown: z.number().int().min(1).max(EVENT_BOARD_SHOWN_MAX).optional(),
        }),
      )
      .max(GIFT_EVENT_LIMITS.boards)
      .default([]),
    /** v1.101-social (D325): optional milestones «مراحل». */
    milestones: z.array(milestoneSchema).max(GIFT_EVENT_LIMITS.milestones).default([]),
    reason: z.string().trim().min(3).max(500),
  })
  // D303's shape stays a 400 for a published body: at least one event gift (unless every gift counts) and one board;
  // a draft may hold none yet (v1.101-social, D325).
  .superRefine((v, ctx) => {
    if (v.status !== 'PUBLISHED') return;
    if (v.countedGifts === 'EVENT_GIFTS' && v.gifts.length === 0) {
      ctx.addIssue({
        code: 'too_small',
        origin: 'array',
        minimum: 1,
        inclusive: true,
        path: ['gifts'],
        message: 'at least one event gift',
      });
    }
    if (v.boards.length === 0) {
      ctx.addIssue({
        code: 'too_small',
        origin: 'array',
        minimum: 1,
        inclusive: true,
        path: ['boards'],
        message: 'at least one board',
      });
    }
  });
export type GiftEventInput = z.infer<typeof giftEventInputSchema>;

/** Whether `zone` is an IANA time zone this runtime knows. */
export function isTimeZone(zone: string): boolean {
  try {
    new Intl.DateTimeFormat('en', { timeZone: zone });
    return /^[A-Za-z_]+(\/[A-Za-z0-9_+-]+){0,2}$/.test(zone);
  } catch {
    return false;
  }
}

/** The problems of the prize lines (ordered, not overlapping, ranks within 1…100). Empty when fine. */
export function prizeLineProblems(lines: readonly PrizeLine[]): string[] {
  const problems: string[] = [];
  let last = 0;
  for (const line of lines) {
    if (line.rankTo < line.rankFrom)
      problems.push(`Ranks ${line.rankFrom}–${line.rankTo}: the end is before the start.`);
    else if (line.rankFrom <= last)
      problems.push(`Ranks ${line.rankFrom}–${line.rankTo} overlap or are out of order.`);
    last = Math.max(last, line.rankTo);
    if (bundleProblem(line.items)) {
      problems.push(`Ranks ${line.rankFrom}–${line.rankTo}: an item is listed twice.`);
    }
  }
  return problems;
}

/** An item listed twice in one bundle (the same money, item, medal or gift). */
function bundleProblem(items: readonly PrizeItem[]): boolean {
  const kinds = items.map((i) =>
    i.type === 'BAG_ITEM'
      ? `B:${i.itemCode}`
      : i.type === 'BADGE'
        ? `M:${i.badgeCode}`
        : i.type === 'GIFT_PIECES'
          ? `G:${i.giftCode}`
          : i.type,
  );
  return new Set(kinds).size !== kinds.length;
}

/** The prize bundle of `rank` (empty when no line covers it). */
export function bundleForRank(lines: readonly PrizeLine[], rank: number): readonly PrizeItem[] {
  return lines.find((l) => rank >= l.rankFrom && rank <= l.rankTo)?.items ?? [];
}

/** The coins of a bundle (the `prizeCoins` older apps read). */
export function bundleCoins(items: readonly PrizeItem[]): number {
  return items.reduce((sum, i) => (i.type === 'COINS' ? sum + i.amount : sum), 0);
}

/** Parses stored prize lines (`event_boards.prizes`); invalid stored data reads as none. */
export function parsePrizeLines(value: unknown): PrizeLine[] {
  const parsed = z.array(prizeLineSchema).safeParse(value);
  return parsed.success ? parsed.data : [];
}

/** Parses a stored bundle (`event_results.prize`, `event_milestones.prizes`). */
export function parseBundle(value: unknown): PrizeItem[] {
  const parsed = z.array(prizeItemSchema).safeParse(value);
  return parsed.success ? parsed.data : [];
}

/** Every prize item of the input (boards and milestones). */
function allItems(input: GiftEventInput): PrizeItemWithDisplay[] {
  return [
    ...input.boards.flatMap((b) => b.prizes.flatMap((l) => l.items)),
    ...input.milestones.flatMap((m) => m.prizes),
  ];
}

/** The first day of the next period after `from` (WEEKLY: 7 days, MONTHLY: a calendar month, in `zone`). */
export async function nextPeriodStartIn(
  tx: Tx,
  recurrence: Exclude<EventRecurrence, 'NONE'>,
  from: Date,
  zone: string,
): Promise<Date> {
  const step = recurrence === 'WEEKLY' ? '1 week' : '1 month';
  const [row] = await tx.$queryRaw<{ at: Date }[]>`
    SELECT ((${from}::timestamptz AT TIME ZONE ${zone}::text) + ${step}::interval) AT TIME ZONE ${zone}::text AS at`;
  return row!.at;
}

/** The window of the current period of a published event: its own dates (NONE) or the recurring period. */
export function currentWindow(e: Event): { period: number; from: Date; to: Date | null } | null {
  if (e.startsAt === null) return null;
  if (e.recurrence === 'NONE' || e.periodStartsAt === null || e.periodEndsAt === null) {
    return { period: 0, from: e.startsAt, to: e.endsAt };
  }
  return { period: e.period, from: e.periodStartsAt, to: e.periodEndsAt };
}

/**
 * Cross-field rules, pure (dates, duplicates, prize lines). A DRAFT is checked only for what it already holds (dates
 * may be null, gifts and boards may be empty); a PUBLISHED event is checked in full. Throws {@link EventAdminError}.
 */
export function checkGiftEventShape(
  input: GiftEventInput,
  now: Date,
): { startsAt: Date | null; endsAt: Date | null } {
  const published = input.status === 'PUBLISHED';
  const startsAt = input.startsAt ? new Date(input.startsAt) : null;
  const endsAt = input.endsAt ? new Date(input.endsAt) : null;
  if (published && startsAt === null) throw new EventAdminError('Set the start date before publishing.');
  if (published && endsAt === null && !input.permanent) {
    throw new EventAdminError('Set the end date, or make the event permanent, before publishing.');
  }
  if (input.permanent && endsAt !== null) throw new EventAdminError('A permanent event has no end date.');
  if (startsAt && endsAt) {
    if (endsAt <= startsAt) throw new EventAdminError('The end must be after the start.');
    if (
      input.recurrence === 'NONE' &&
      endsAt.getTime() - startsAt.getTime() > GIFT_EVENT_LIMITS.maxLengthDays * DAY_MS
    ) {
      throw new EventAdminError(`An event lasts at most ${GIFT_EVENT_LIMITS.maxLengthDays} days.`);
    }
    if (input.recurrence !== 'NONE') {
      const minimum = input.recurrence === 'WEEKLY' ? 7 * DAY_MS : 28 * DAY_MS;
      if (endsAt.getTime() - startsAt.getTime() < minimum) {
        throw new EventAdminError('A recurring event lasts at least one whole period.');
      }
    }
  }
  if (startsAt && startsAt.getTime() > now.getTime() + GIFT_EVENT_LIMITS.maxLeadDays * DAY_MS) {
    throw new EventAdminError(`An event starts at most ${GIFT_EVENT_LIMITS.maxLeadDays} days ahead.`);
  }
  const video = input.backgroundKey ? /\.(mp4|mov)$/.test(input.backgroundKey) : false;
  if (video !== Boolean(input.backgroundPosterKey)) {
    throw new EventAdminError(
      video ? 'A video background needs its poster picture.' : 'A poster goes with a video background only.',
    );
  }
  if (input.timeZone && !isTimeZone(input.timeZone)) {
    throw new EventAdminError(`Unknown time zone ${input.timeZone}.`);
  }
  const gifts = input.gifts.map((g) => g.giftCode);
  if (new Set(gifts).size !== gifts.length) throw new EventAdminError('A gift is listed twice.');
  if (published && input.countedGifts === 'EVENT_GIFTS' && gifts.length === 0) {
    throw new EventAdminError('Add the event gifts (or count all gifts) before publishing.');
  }
  for (const g of input.gifts) {
    if (input.scoring === 'MULTIPLIER' && g.pointsPerCoin === 0 && g.pointsPerGift === 0) {
      throw new EventAdminError(`Gift ${g.giftCode} gives no points.`);
    }
  }
  if (published && input.boards.length === 0)
    throw new EventAdminError('Add at least one board before publishing.');
  const kinds = input.boards.map((b) => b.kind);
  if (new Set(kinds).size !== kinds.length) throw new EventAdminError('A board is listed twice.');
  const moneyOf = (kind: EventBoardKind, items: readonly PrizeItem[], where: string) => {
    // Owner (D303 follow-ups): the money of each board — hosts / creators / CP couples win cherries, supporters
    // coins, agencies either (chosen per line); items, medals, VIP and gift pieces on every board.
    const allowed = BOARD_MONEY_ALLOWED[kind];
    const wrong = items.find((i) => MONEY_TYPES.includes(i.type) && !allowed.includes(i.type));
    if (wrong) {
      throw new EventAdminError(
        `${where}: this board's money is ${allowed.join(' or ')}, not ${wrong.type}.`,
      );
    }
  };
  for (const b of input.boards) {
    const problems = prizeLineProblems(b.prizes);
    if (problems.length > 0) throw new EventAdminError(`${b.kind}: ${problems.join(' ')}`);
    moneyOf(
      b.kind,
      b.prizes.flatMap((l) => l.items),
      b.kind,
    );
  }
  const steps = input.milestones.map((m) => `${m.board}:${String(m.points)}`);
  if (new Set(steps).size !== steps.length) throw new EventAdminError('A milestone is listed twice.');
  for (const m of input.milestones) {
    if (published && !kinds.includes(m.board)) {
      throw new EventAdminError(
        `The milestone of ${String(m.points)} points counts a board the event does not have.`,
      );
    }
    if (bundleProblem(m.prizes))
      throw new EventAdminError(`Milestone ${String(m.points)}: an item is listed twice.`);
    moneyOf(m.board, m.prizes, `Milestone ${String(m.points)}`);
  }
  return { startsAt, endsAt };
}

/** The catalogue checks (gifts, bag items, VIP tiers, medals, the event's own gifts). Throws {@link EventAdminError}. */
async function checkCatalogueIn(tx: Tx, input: GiftEventInput, eventId: string | null): Promise<void> {
  const giftCodes = input.gifts.map((g) => g.giftCode);
  const gifts = await tx.gift.findMany({
    where: { code: { in: giftCodes } },
    select: { code: true, eventId: true },
  });
  const missingGift = giftCodes.find((c) => !gifts.some((g) => g.code === c));
  if (missingGift) throw new EventAdminError(`No gift ${missingGift}.`);
  // v1.101-social (D325): another event's exclusive gift never scores here.
  const foreign = gifts.find((g) => g.eventId !== null && g.eventId !== eventId);
  if (foreign) throw new EventAdminError(`Gift ${foreign.code} belongs to another event.`);
  const items = allItems(input);
  const pieceCodes = [...new Set(items.flatMap((i) => (i.type === 'GIFT_PIECES' ? [i.giftCode] : [])))];
  if (pieceCodes.length > 0) {
    const own = await tx.gift.findMany({
      where: { code: { in: pieceCodes } },
      select: { code: true, eventId: true },
    });
    const notOwn = pieceCodes.find(
      (c) => !own.some((g) => g.code === c && g.eventId !== null && g.eventId === eventId),
    );
    if (notOwn) {
      throw new EventAdminError(
        `Gift pieces are of the event's own exclusive gifts only (${notOwn} is not one).`,
      );
    }
  }
  const bagCodes = [...new Set(items.flatMap((i) => (i.type === 'BAG_ITEM' ? [i.itemCode] : [])))];
  if (bagCodes.length > 0) {
    const found = await tx.bagItem.findMany({
      where: { code: { in: bagCodes } },
      select: { code: true, storeItem: { select: { eventId: true } } },
    });
    const missing = bagCodes.find((c) => !found.some((f) => f.code === c));
    if (missing) throw new EventAdminError(`No bag item ${missing}.`);
    const other = found.find((f) => f.storeItem?.eventId && f.storeItem.eventId !== eventId);
    if (other) throw new EventAdminError(`Item ${other.code} is another event's exclusive prize.`);
  }
  const badgeCodes = [...new Set(items.flatMap((i) => (i.type === 'BADGE' ? [i.badgeCode] : [])))];
  if (badgeCodes.length > 0) {
    const found = await tx.eventBadgeLevel.findMany({
      where: { badgeCode: { in: badgeCodes } },
      select: { badgeCode: true, level: true },
    });
    const missing = items
      .flatMap((i) => (i.type === 'BADGE' ? [i] : []))
      .find((i) => !found.some((f) => f.badgeCode === i.badgeCode && f.level === i.level));
    if (missing)
      throw new EventAdminError(`No event medal ${missing.badgeCode} level ${String(missing.level)}.`);
    const unknown = badgeCodes.find((c) => !found.some((f) => f.badgeCode === c));
    if (unknown) throw new EventAdminError(`No event medal ${unknown}.`);
  }
  const tierCodes = [...new Set(items.flatMap((i) => (i.type === 'VIP' ? [i.tierCode] : [])))];
  if (tierCodes.length > 0) {
    const found = await tx.vipTier.findMany({ where: { code: { in: tierCodes } }, select: { code: true } });
    const missing = tierCodes.find((c) => !found.some((f) => f.code === c));
    if (missing) throw new EventAdminError(`No VIP tier ${missing}.`);
  }
  if (input.bannerMediaId) {
    const media = await tx.mediaAsset.findUnique({
      where: { id: input.bannerMediaId },
      select: { kind: true, homeBanner: { select: { id: true, eventId: true } } },
    });
    if (media?.kind !== 'HOME_BANNER') throw new EventAdminError('Upload the event banner first.');
    if (media.homeBanner && media.homeBanner.eventId !== eventId) {
      throw new EventAdminError('That banner picture belongs to another banner.');
    }
  }
}

function rowFields(input: GiftEventInput, startsAt: Date | null, endsAt: Date | null) {
  return {
    titleAr: input.titleAr,
    titleEn: input.titleEn,
    rulesAr: input.rulesAr,
    rulesEn: input.rulesEn,
    summaryAr: input.summaryAr || null,
    summaryEn: input.summaryEn || null,
    tone: input.tone ?? null,
    bannerUrl: input.bannerUrl ?? null,
    startsAt,
    endsAt,
    permanent: input.permanent,
    timeZone: input.timeZone ?? null,
    audience: input.audience,
    regions: [...new Set(input.regions.map((r) => r.toUpperCase()))],
    featured: input.featured,
    backgroundKey: input.backgroundKey ?? null,
    backgroundPosterKey: input.backgroundPosterKey ?? null,
    titleKey: input.titleKey ?? null,
    overlayKey: input.overlayKey ?? null,
    recurrence: input.recurrence,
    scoring: input.scoring,
    countedGifts: input.countedGifts,
    bannerMediaId: input.bannerMediaId ?? null,
  };
}

async function writeStructureIn(tx: Tx, eventId: string, input: GiftEventInput): Promise<void> {
  // v1.102-social (D334): a board's «عدد المعروضين» the body leaves out stays what it was.
  const shownBefore = new Map(
    (await tx.eventBoard.findMany({ where: { eventId }, select: { kind: true, shown: true } })).map((b) => [
      b.kind,
      b.shown,
    ]),
  );
  await tx.eventGift.deleteMany({ where: { eventId } });
  await tx.eventBoard.deleteMany({ where: { eventId } });
  await tx.eventMilestone.deleteMany({ where: { eventId } });
  await tx.eventGift.createMany({
    data: input.gifts.map((g, i) => ({
      eventId,
      giftCode: g.giftCode,
      pointsPerCoin: new Prisma.Decimal(g.pointsPerCoin.toFixed(2)),
      pointsPerGift: g.pointsPerGift,
      sortOrder: i,
    })),
  });
  await tx.eventBoard.createMany({
    data: input.boards.map((b, i) => ({
      eventId,
      kind: b.kind,
      minPoints: BigInt(b.minPoints),
      prizes: b.prizes.map((l) => ({
        rankFrom: l.rankFrom,
        rankTo: l.rankTo,
        items: l.items.map((x) => ({ ...x })),
      })),
      sortOrder: i,
      shown: b.shown ?? shownBefore.get(b.kind) ?? EVENT_BOARD_SHOWN,
    })),
  });
  await tx.eventMilestone.createMany({
    data: [...input.milestones]
      .sort((a, b) => (a.board === b.board ? a.points - b.points : a.board < b.board ? -1 : 1))
      .map((m, i) => ({
        eventId,
        board: m.board,
        points: BigInt(m.points),
        prizes: m.prizes.map((x) => ({ ...x })),
        sortOrder: i,
      })),
  });
}

/** The stored event structure as comparable text (the running-event lock). */
async function structureOf(tx: Tx, eventId: string): Promise<string> {
  const [gifts, boards, milestones] = await Promise.all([
    tx.eventGift.findMany({ where: { eventId }, orderBy: { sortOrder: 'asc' } }),
    tx.eventBoard.findMany({ where: { eventId }, orderBy: { sortOrder: 'asc' } }),
    tx.eventMilestone.findMany({ where: { eventId }, orderBy: { sortOrder: 'asc' } }),
  ]);
  return JSON.stringify([
    gifts.map((g) => [g.giftCode, Number(g.pointsPerCoin), g.pointsPerGift]),
    boards.map((b) => [b.kind, Number(b.minPoints), parsePrizeLines(b.prizes)]),
    milestones.map((m) => [m.board, Number(m.points), parseBundle(m.prizes)]).sort(),
  ]);
}

function structureOfInput(input: GiftEventInput): string {
  const norm = (v: unknown) => JSON.parse(JSON.stringify(v)) as unknown;
  return JSON.stringify([
    input.gifts.map((g) => [g.giftCode, Number(g.pointsPerCoin.toFixed(2)), g.pointsPerGift]),
    input.boards.map((b) => [b.kind, b.minPoints, norm(parsePrizeLines(b.prizes))]),
    input.milestones.map((m) => [m.board, m.points, norm(parseBundle(m.prizes))]).sort(),
  ]);
}

function auditMeta(input: GiftEventInput, by: AdminVia) {
  return {
    metric: 'EVENT_GIFTS',
    status: input.status,
    audience: input.audience,
    startsAt: input.startsAt,
    endsAt: input.endsAt,
    permanent: input.permanent,
    timeZone: input.timeZone ?? null,
    recurrence: input.recurrence,
    scoring: input.scoring,
    countedGifts: input.countedGifts,
    gifts: input.gifts.map((g) => `${g.giftCode}:${String(g.pointsPerCoin)}/${String(g.pointsPerGift)}`),
    boards: input.boards.map((b) => ({
      kind: b.kind,
      minPoints: b.minPoints,
      lines: b.prizes.length,
      ...(b.shown !== undefined ? { shown: b.shown } : {}),
    })),
    milestones: input.milestones.map((m) => `${m.board}:${String(m.points)}`),
    reason: input.reason,
    via: by.via,
  };
}

/**
 * The steps of publishing (in the caller's transaction, the event row written): the first period of a recurring event,
 * the publish time, and the Live home banner made from the event's banner picture (once; any audience since D334).
 */
async function publishStepsIn(tx: Tx, eventId: string, now: Date): Promise<void> {
  const e = await tx.event.findUniqueOrThrow({ where: { id: eventId } });
  if (e.publishedAt === null) {
    await tx.event.update({ where: { id: eventId }, data: { publishedAt: now } });
  }
  await syncEventBannerIn(tx, e);
}

/**
 * The first period of a recurring event about to be published (CHECK `events_v2_shape`: a published recurring event
 * knows its current period), else none. Written with the row, before it starts (the period never moves once running).
 */
async function firstPeriodIn(
  tx: Tx,
  input: GiftEventInput,
  startsAt: Date | null,
  endsAt: Date | null,
  zone: string,
): Promise<{ period: number; periodStartsAt: Date | null; periodEndsAt: Date | null }> {
  if (input.status !== 'PUBLISHED' || input.recurrence === 'NONE' || startsAt === null) {
    return { period: 0, periodStartsAt: null, periodEndsAt: null };
  }
  const first = await nextPeriodStartIn(tx, input.recurrence, startsAt, input.timeZone ?? zone);
  return {
    period: 0,
    periodStartsAt: startsAt,
    periodEndsAt: endsAt !== null && endsAt < first ? endsAt : first,
  };
}

/**
 * v1.101-social (D325): the event's Live home banner — one HOME banner opening the event, from its banner picture, shown
 * from its start to its end. A new picture replaces it. v1.102-social (D334, owner): an event of ANY audience may have
 * one; `GET /home/banners` lists it to that event's audience only (`HomeService.listBanners`).
 */
export async function syncEventBannerIn(tx: Tx, e: Event): Promise<void> {
  if (e.status !== 'PUBLISHED' || e.bannerMediaId === null || e.startsAt === null) {
    return;
  }
  const existing = await tx.homeBanner.findFirst({ where: { eventId: e.id, placement: 'HOME' } });
  const window = { startsAt: e.startsAt, endsAt: e.endsAt };
  if (existing && existing.mediaId === e.bannerMediaId) {
    await tx.homeBanner.update({ where: { id: existing.id }, data: window });
    return;
  }
  const media = await tx.mediaAsset.findUnique({ where: { id: e.bannerMediaId } });
  if (!media) return;
  if (existing) await tx.homeBanner.delete({ where: { id: existing.id } });
  await tx.homeBanner.create({
    data: {
      mediaId: media.id,
      placement: 'HOME',
      link: `/events/${e.id}`,
      eventId: e.id,
      kind: media.durationMs !== null ? 'ANIMATED' : 'IMAGE',
      sortOrder: 0,
      enabled: true,
      ...window,
    },
  });
}

/** Creates an EVENT_GIFTS event (panel `POST /admin/gift-events`, app `POST /staff/gift-events`), audited. */
export async function createGiftEventIn(
  tx: Tx,
  input: GiftEventInput,
  now: Date,
  by: AdminVia,
  zone = 'UTC',
): Promise<{ id: string; status: EventLifecycle }> {
  const { startsAt, endsAt } = checkGiftEventShape(input, now);
  if (input.status === 'PUBLISHED' && endsAt !== null && endsAt <= now) {
    throw new EventAdminError('The end is in the past.');
  }
  await checkCatalogueIn(tx, input, null);
  const row = await tx.event.create({
    data: {
      ...rowFields(input, startsAt, endsAt),
      ...(await firstPeriodIn(tx, input, startsAt, endsAt, zone)),
      status: input.status,
      metric: 'EVENT_GIFTS',
      prizes: [],
      createdById: by.actorUserId,
      // A published event's start is announced by the sweeper; a draft's at its publish.
      startNotifiedAt: null,
    },
    select: { id: true },
  });
  await writeStructureIn(tx, row.id, input);
  if (input.status === 'PUBLISHED') await publishStepsIn(tx, row.id, now);
  await tx.auditLog.create({
    data: {
      ...auditBy(by),
      action: AuditAction.EVENT_CREATE,
      targetType: 'event',
      targetId: row.id,
      metadata: auditMeta(input, by),
    },
  });
  return { id: row.id, status: input.status };
}

/**
 * A full edit of an EVENT_GIFTS event. A DRAFT: anything (with `status: PUBLISHED` it is published — every rule then
 * applies). PUBLISHED before its start: anything but back to a draft (`unpublish` does that). Once it runs: only the
 * texts, banner, art, calendar style, «رائج» and a later end (gifts, boards, prizes, milestones, start, audience,
 * regions, recurrence, scoring and counted gifts stay; else 409); once ended nothing (409).
 */
export async function updateGiftEventIn(
  tx: Tx,
  eventId: string,
  input: GiftEventInput,
  now: Date,
  by: AdminVia,
  zone = 'UTC',
): Promise<{ id: string; status: EventLifecycle }> {
  const [locked] = await tx.$queryRaw<{ id: string }[]>`
    SELECT id::text AS id FROM events WHERE id = ${eventId}::uuid FOR UPDATE`;
  const event = locked ? await tx.event.findUnique({ where: { id: eventId } }) : null;
  if (!event) throw new EventAdminError(`No event ${eventId}.`);
  if (event.metric !== 'EVENT_GIFTS') throw new EventAdminError('Only gift events are edited here.');
  if (event.frozenAt !== null || (event.endsAt !== null && event.endsAt <= now)) {
    throw new EventAdminError('This event has ended; it can no longer change.');
  }
  if (event.status === 'PUBLISHED' && input.status === 'DRAFT') {
    throw new EventAdminError(
      'A published event goes back to a draft only with «unpublish», before its start.',
    );
  }
  const { startsAt, endsAt } = checkGiftEventShape(input, now);
  if (input.status === 'PUBLISHED' && endsAt !== null && endsAt <= now) {
    throw new EventAdminError('The end is in the past.');
  }
  await checkCatalogueIn(tx, input, eventId);
  const running = event.status === 'PUBLISHED' && event.startsAt !== null && event.startsAt <= now;
  if (running) {
    const regions = [...new Set(input.regions.map((r) => r.toUpperCase()))];
    if (
      (await structureOf(tx, eventId)) !== structureOfInput(input) ||
      startsAt?.getTime() !== event.startsAt!.getTime() ||
      input.audience !== event.audience ||
      input.recurrence !== event.recurrence ||
      input.scoring !== event.scoring ||
      input.countedGifts !== event.countedGifts ||
      input.permanent !== event.permanent ||
      JSON.stringify(regions) !== JSON.stringify(event.regions.map((r) => r.trim()))
    ) {
      throw new EventAdminError(
        'The event has started: its gifts, boards, prizes, milestones, start, audience, regions, recurrence and ' +
          'scoring can no longer change.',
      );
    }
    if (event.endsAt !== null && (endsAt === null || endsAt < event.endsAt)) {
      throw new EventAdminError('The event has started: its end can only move later.');
    }
  }
  await tx.event.update({
    where: { id: eventId },
    data: {
      ...rowFields(input, startsAt, endsAt),
      ...(running ? {} : await firstPeriodIn(tx, input, startsAt, endsAt, zone)),
      status: input.status,
    },
  });
  if (!running) await writeStructureIn(tx, eventId, input);
  else {
    // v1.102-social (D334): «عدد المعروضين» is a display setting — it may change while the event runs.
    for (const b of input.boards) {
      if (b.shown === undefined) continue;
      await tx.eventBoard.updateMany({ where: { eventId, kind: b.kind }, data: { shown: b.shown } });
    }
  }
  if (input.status === 'PUBLISHED') {
    if (!running) await publishStepsIn(tx, eventId, now);
    else {
      // A later end of a running recurring event: the current period may now run to its full length.
      const e = await tx.event.findUniqueOrThrow({ where: { id: eventId } });
      if (e.recurrence !== 'NONE' && e.periodStartsAt !== null) {
        const full = await nextPeriodStartIn(
          tx,
          e.recurrence as Exclude<EventRecurrence, 'NONE'>,
          e.periodStartsAt,
          e.timeZone ?? zone,
        );
        await tx.event.update({
          where: { id: eventId },
          data: { periodEndsAt: e.endsAt !== null && e.endsAt < full ? e.endsAt : full },
        });
      }
      await syncEventBannerIn(tx, e);
    }
  }
  await tx.auditLog.create({
    data: {
      ...auditBy(by),
      action: AuditAction.EVENT_UPDATE,
      targetType: 'event',
      targetId: eventId,
      metadata: { ...auditMeta(input, by), running },
    },
  });
  return { id: eventId, status: input.status };
}

/** The stored event as its `GiftEventInput` (the publish / unpublish commands re-run the edit rules on it). */
export async function inputOfIn(tx: Tx, eventId: string, reason: string): Promise<GiftEventInput> {
  const e = await tx.event.findUnique({
    where: { id: eventId },
    include: {
      gifts: { orderBy: { sortOrder: 'asc' } },
      boards: { orderBy: { sortOrder: 'asc' } },
      milestones: { orderBy: { sortOrder: 'asc' } },
    },
  });
  if (!e || e.metric !== 'EVENT_GIFTS') throw new EventAdminError(`No gift event ${eventId}.`);
  return giftEventInputSchema.parse({
    titleAr: e.titleAr,
    titleEn: e.titleEn,
    rulesAr: e.rulesAr,
    rulesEn: e.rulesEn,
    summaryAr: e.summaryAr,
    summaryEn: e.summaryEn,
    tone: e.tone,
    bannerUrl: e.bannerUrl,
    status: e.status,
    startsAt: e.startsAt?.toISOString() ?? null,
    endsAt: e.endsAt?.toISOString() ?? null,
    permanent: e.permanent,
    recurrence: e.recurrence,
    scoring: e.scoring,
    countedGifts: e.countedGifts,
    timeZone: e.timeZone,
    audience: e.audience,
    bannerMediaId: e.bannerMediaId,
    regions: e.regions.map((r) => r.trim()),
    featured: e.featured,
    backgroundKey: e.backgroundKey,
    backgroundPosterKey: e.backgroundPosterKey,
    titleKey: e.titleKey,
    overlayKey: e.overlayKey,
    gifts: e.gifts.map((g) => ({
      giftCode: g.giftCode,
      pointsPerCoin: Number(g.pointsPerCoin),
      pointsPerGift: g.pointsPerGift,
    })),
    boards: e.boards.map((b) => ({
      kind: b.kind,
      minPoints: Number(b.minPoints),
      prizes: parsePrizeLines(b.prizes),
      shown: b.shown,
    })),
    milestones: e.milestones.map((m) => ({
      board: m.board,
      points: Number(m.points),
      prizes: parseBundle(m.prizes),
    })),
    reason,
  });
}

export type EventLifecycleCommand = 'publish' | 'unpublish' | 'discard';

/**
 * v1.101-social (D325): «نشر» publishes a draft (every rule of a published event, then its first period and banner);
 * «إلغاء النشر» takes a published event that has not started back to a draft (its banner removed); «حذف المسودة»
 * deletes a draft and its own unsent gifts and unheld items. Audited `event.publish` / `event.unpublish` /
 * `event.discard`.
 */
export async function lifecycleIn(
  tx: Tx,
  eventId: string,
  command: EventLifecycleCommand,
  reason: string,
  now: Date,
  by: AdminVia,
  zone = 'UTC',
): Promise<{ id: string; status: EventLifecycle | 'DELETED' }> {
  const [locked] = await tx.$queryRaw<{ id: string }[]>`
    SELECT id::text AS id FROM events WHERE id = ${eventId}::uuid FOR UPDATE`;
  const e = locked ? await tx.event.findUnique({ where: { id: eventId } }) : null;
  if (!e || e.metric !== 'EVENT_GIFTS') throw new EventAdminError(`No gift event ${eventId}.`);
  const audit = (action: string, metadata: Record<string, unknown>) =>
    tx.auditLog.create({
      data: {
        ...auditBy(by),
        action,
        targetType: 'event',
        targetId: eventId,
        metadata: { ...metadata, reason, via: by.via },
      },
    });
  if (command === 'publish') {
    if (e.status === 'PUBLISHED') throw new EventAdminError('The event is already published.');
    // The panel's reason may be shorter than an edit's (1 character); the edit's audit keeps it in full.
    const input = {
      ...(await inputOfIn(tx, eventId, reason.trim().length >= 3 ? reason : `${reason.trim()} (publish)`)),
      status: 'PUBLISHED' as const,
    };
    await updateGiftEventIn(tx, eventId, input, now, by, zone);
    await audit('event.publish', { startsAt: input.startsAt, endsAt: input.endsAt });
    return { id: eventId, status: 'PUBLISHED' };
  }
  if (command === 'unpublish') {
    if (e.status !== 'PUBLISHED') throw new EventAdminError('The event is a draft already.');
    if (e.startsAt !== null && e.startsAt <= now) {
      throw new EventAdminError('The event has started; end it or hold its payout instead.');
    }
    // The banner made from the event's picture goes; the picture stays with the draft (re-made at the next publish).
    await tx.homeBanner.deleteMany({ where: { eventId, placement: 'HOME' } });
    await tx.event.update({
      where: { id: eventId },
      data: { status: 'DRAFT', periodStartsAt: null, periodEndsAt: null, period: 0, startNotifiedAt: null },
    });
    await audit('event.unpublish', {});
    return { id: eventId, status: 'DRAFT' };
  }
  if (e.status !== 'DRAFT') throw new EventAdminError('Only a draft is deleted; a published event is ended.');
  const ownGifts = await tx.gift.findMany({ where: { eventId }, select: { code: true } });
  const codes = ownGifts.map((g) => g.code);
  const used =
    codes.length === 0
      ? 0
      : (await tx.liveGift.count({ where: { giftCode: { in: codes } } })) +
        (await tx.userGiftStock.count({ where: { giftCode: { in: codes }, quantity: { gt: 0 } } }));
  const ownItems = await tx.storeItem.findMany({ where: { eventId }, select: { id: true, bagCode: true } });
  const held =
    ownItems.length === 0
      ? 0
      : await tx.userBagItem.count({ where: { itemCode: { in: ownItems.map((i) => i.bagCode) } } });
  if (used > 0 || held > 0)
    throw new EventAdminError('Its gifts or items are in use; they cannot be deleted.');
  await tx.eventGift.deleteMany({ where: { eventId } });
  await tx.userGiftStock.deleteMany({ where: { giftCode: { in: codes } } });
  await tx.gift.deleteMany({ where: { eventId } });
  for (const i of ownItems) {
    await tx.storeItem.delete({ where: { id: i.id } });
    await tx.bagItem.delete({ where: { code: i.bagCode } });
  }
  await tx.homeBanner.deleteMany({ where: { eventId } });
  await tx.event.delete({ where: { id: eventId } });
  await audit('event.discard', { gifts: codes, items: ownItems.map((i) => i.bagCode) });
  return { id: eventId, status: 'DELETED' };
}

// ---------------------------------------------------------------------------------------------------------------
// Scoring (from stored sends only: idempotent per send by construction).

/** One ranked entrant of a board. */
export interface BoardRow {
  entrant_key: string;
  user_id: string;
  agency_id: string | null;
  agency_name: string | null;
  couple_id: string | null;
  partner_id: string | null;
  score: bigint;
  rank: bigint;
}

/** The scoring window of a board: [from, to). */
export interface ScoreWindow {
  readonly from: Date;
  readonly to: Date;
}

/**
 * Every recipient row of a counted send in [from, to): the sender, the recipient and its points. v1.101-social (D325):
 * scoring COINS — the coins of the recipient row; MULTIPLIER — an event gift's `floor(coins × points_per_coin) +
 * quantity × points_per_gift` (D303's integers keep their value), a gift not listed (ALL_GIFTS only) its coins × 1.
 * Counted gifts EVENT_GIFTS — only the listed gifts; ALL_GIFTS — every gift. Never a send to oneself; the sender ACTIVE;
 * a send whose cherries the team reversed (`GIFT_REVERSAL`) does not count (§10.114.2); the event's own exclusive gift
 * sent from the bag (prize pieces) never scores (it would turn a prize into points).
 */
function pointsSql(event: Event, w: ScoreWindow): Prisma.Sql {
  const coinsOnly = event.scoring === 'COINS';
  const allGifts = event.countedGifts === 'ALL_GIFTS';
  return Prisma.sql`
    SELECT g.id AS gift_id, g.sender_id, r.user_id AS recipient_id, g.created_at,
           (CASE WHEN ${coinsOnly} OR eg.gift_code IS NULL THEN r.coins
                 ELSE floor(r.coins * eg.points_per_coin) + g.quantity::bigint * eg.points_per_gift END)::bigint AS points
      FROM live_gifts g
      LEFT JOIN event_gifts eg ON eg.event_id = ${event.id}::uuid AND eg.gift_code = g.gift_code
      JOIN live_gift_recipients r ON r.gift_id = g.id AND r.user_id <> g.sender_id
      JOIN users s ON s.id = g.sender_id AND s.status = 'ACTIVE'
     WHERE g.created_at >= ${w.from}::timestamptz AND g.created_at < ${w.to}::timestamptz
       AND (${allGifts} OR eg.gift_code IS NOT NULL)
       AND NOT (g.source = 'BAG'::live_gift_source
                AND EXISTS (SELECT 1 FROM gifts og WHERE og.code = g.gift_code AND og.event_id = ${event.id}::uuid))
       AND NOT EXISTS (SELECT 1 FROM cherry_ledger l
                        WHERE l.reference_id = g.id::text AND l.reason = 'GIFT_REVERSAL'::cherry_ledger_reason)`;
}

function regionSql(column: Prisma.Sql, regions: readonly string[]): Prisma.Sql {
  return Prisma.sql`(${regions.length === 0} OR EXISTS (SELECT 1 FROM user_profiles rp
          WHERE rp.user_id = ${column} AND rp.country_code = ANY(string_to_array(${regions.join(',')}::text, ','))))`;
}

/** The entrants of `kind` with their scores (> 0) in the window, unranked. */
function entrantsSql(event: Event, kind: EventBoardKind, w: ScoreWindow): Prisma.Sql {
  const p = pointsSql(event, w);
  const regions = event.regions.map((r) => r.trim());
  const creator = (col: Prisma.Sql) =>
    Prisma.sql`EXISTS (SELECT 1 FROM creator_members cm WHERE cm.user_id = ${col})`;
  switch (kind) {
    case 'SENDERS':
      return Prisma.sql`
        SELECT p.sender_id::text AS entrant_key, p.sender_id AS user_id, NULL::uuid AS agency_id,
               NULL::text AS agency_name, NULL::uuid AS couple_id, NULL::uuid AS partner_id, sum(p.points)::bigint AS score
          FROM (${p}) p
          JOIN users u ON u.id = p.sender_id AND u.status = 'ACTIVE'
         WHERE ${regionSql(Prisma.sql`p.sender_id`, regions)}
         GROUP BY p.sender_id`;
    case 'RECEIVERS':
    case 'CREATORS':
      // Owner (D303 follow-up, «ان كانت للمضيفين تشمل صناع المحتوى»; overrides D295 for gift events only): the hosts'
      // board counts every approved host — a hosting permission (`live_hosts`, any source) — and every content-creator
      // member; a guest on a seat counts when they are one; people who are neither never enter it. The creators'
      // board is creator members only.
      return Prisma.sql`
        SELECT p.recipient_id::text AS entrant_key, p.recipient_id AS user_id, NULL::uuid AS agency_id,
               NULL::text AS agency_name, NULL::uuid AS couple_id, NULL::uuid AS partner_id, sum(p.points)::bigint AS score
          FROM (${p}) p
          JOIN users u ON u.id = p.recipient_id AND u.status = 'ACTIVE'
         WHERE (${kind === 'CREATORS'} AND ${creator(Prisma.sql`p.recipient_id`)}
                OR ${kind === 'RECEIVERS'} AND (${creator(Prisma.sql`p.recipient_id`)}
                     OR EXISTS (SELECT 1 FROM live_hosts lh WHERE lh.user_id = p.recipient_id)))
           AND ${regionSql(Prisma.sql`p.recipient_id`, regions)}
         GROUP BY p.recipient_id`;
    case 'AGENCIES':
      // The agency the receiving host belonged to at the time of the gift (`agency_earnings`, not reversed); the host
      // ACTIVE; the agency open and not suspended now; ranked as its owner (who wins the prize).
      return Prisma.sql`
        SELECT a.id::text AS entrant_key, a.owner_user_id AS user_id, a.id AS agency_id, a.name::text AS agency_name,
               NULL::uuid AS couple_id, NULL::uuid AS partner_id, sum(p.points)::bigint AS score
          FROM (${p}) p
          JOIN agency_earnings ae ON ae.gift_id = p.gift_id AND ae.host_user_id = p.recipient_id AND ae.reversed_at IS NULL
          JOIN agencies a ON a.id = ae.agency_id AND a.status = 'OPEN' AND a.suspended_at IS NULL
          JOIN users h ON h.id = p.recipient_id AND h.status = 'ACTIVE'
          JOIN users o ON o.id = a.owner_user_id AND o.status = 'ACTIVE'
         WHERE ${regionSql(Prisma.sql`a.owner_user_id`, regions)}
         GROUP BY a.id, a.owner_user_id, a.name`;
    case 'CP':
      // Owner decision: only the event gifts the two partners send each other while they are a couple (a breakup
      // ends further scoring; what they sent before stays). Both partners ACTIVE.
      return Prisma.sql`
        SELECT c.id::text AS entrant_key, c.user_a_id AS user_id, NULL::uuid AS agency_id, NULL::text AS agency_name,
               c.id AS couple_id, c.user_b_id AS partner_id, sum(p.points)::bigint AS score
          FROM (${p}) p
          JOIN cp_couples c ON ((c.user_a_id = p.sender_id AND c.user_b_id = p.recipient_id)
                             OR (c.user_b_id = p.sender_id AND c.user_a_id = p.recipient_id))
                           AND p.created_at >= c.since AND (c.ended_at IS NULL OR p.created_at < c.ended_at)
          JOIN users ua ON ua.id = c.user_a_id AND ua.status = 'ACTIVE'
          JOIN users ub ON ub.id = c.user_b_id AND ub.status = 'ACTIVE'
         WHERE (${regionSql(Prisma.sql`c.user_a_id`, regions)} OR ${regionSql(Prisma.sql`c.user_b_id`, regions)})
         GROUP BY c.id, c.user_a_id, c.user_b_id`;
  }
}

/** The ranked board (score desc, then the entrant key) of the window. */
export function boardRankedSql(event: Event, kind: EventBoardKind, w: ScoreWindow): Prisma.Sql {
  return Prisma.sql`
    SELECT e.entrant_key, e.user_id::text AS user_id, e.agency_id::text AS agency_id, e.agency_name,
           e.couple_id::text AS couple_id, e.partner_id::text AS partner_id, e.score,
           row_number() OVER (ORDER BY e.score DESC, e.entrant_key) AS rank
      FROM (${entrantsSql(event, kind, w)}) e
     WHERE e.score > 0`;
}

// ---------------------------------------------------------------------------------------------------------------
// Freeze and payout.

/**
 * Freezes every board of one period into `event_results` (`period`) and records the period (`event_periods`), in the
 * caller's locked transaction. Returns whether any result won a prize.
 */
async function freezeBoardsIn(
  tx: Tx,
  event: Event,
  period: number,
  w: ScoreWindow,
  now: Date,
): Promise<boolean> {
  const boards = await tx.eventBoard.findMany({
    where: { eventId: event.id },
    orderBy: { sortOrder: 'asc' },
  });
  let anyPrize = false;
  for (const board of boards) {
    const kind = board.kind as EventBoardKind;
    const lines = parsePrizeLines(board.prizes);
    const rows = await tx.$queryRaw<BoardRow[]>`
      SELECT * FROM (${boardRankedSql(event, kind, w)}) b ORDER BY b.rank LIMIT ${EVENT_LEADERBOARD_MAX}`;
    if (rows.length === 0) continue;
    await tx.eventResult.createMany({
      data: rows.map((r) => {
        const qualified = r.score >= board.minPoints;
        const bundle = qualified ? bundleForRank(lines, Number(r.rank)) : [];
        if (bundle.length > 0) anyPrize = true;
        return {
          eventId: event.id,
          period,
          board: kind,
          rank: Number(r.rank),
          userId: r.user_id,
          entrantKey: r.entrant_key,
          agencyId: r.agency_id,
          coupleId: r.couple_id,
          partnerId: r.partner_id,
          score: r.score,
          prizeCoins: bundleCoins(bundle),
          prize: bundle.map((i) => ({ ...i })),
          prizeStatus: bundle.length > 0 ? 'PENDING' : 'NONE',
          createdAt: now,
        };
      }),
    });
  }
  await tx.eventPeriod.create({
    data: { eventId: event.id, period, startsAt: w.from, endsAt: w.to, frozenAt: now },
  });
  return anyPrize;
}

/**
 * Whether results of the event still wait for their payout (a held earlier period) — or, v1.102-social (D334), held
 * milestones: a held event with milestones stays due until its release gives them (`payGiftEventIn`), even when no
 * board line pays anything.
 */
async function pendingLeftIn(tx: Tx, event: Event): Promise<boolean> {
  if ((await tx.eventResult.count({ where: { eventId: event.id, prizeStatus: 'PENDING' } })) > 0) return true;
  return event.payoutHold && (await tx.eventMilestone.count({ where: { eventId: event.id } })) > 0;
}

/**
 * Freezes an ended gift event (in the caller's locked transaction): its last period's boards (a recurring event's
 * current period, cut at the end), once; due at once (owner D303 decision 3: no review window; the hold still stops it).
 */
export async function freezeGiftEventIn(tx: Tx, event: Event, now: Date): Promise<boolean> {
  const w = currentWindow(event);
  if (!w || event.endsAt === null) return false;
  // Milestones reached by the end are given before the boards freeze (unless held: then at the release).
  if (!event.payoutHold)
    await grantMilestonesIn(tx, event, { from: w.from, to: event.endsAt }, w.period, now);
  const anyPrize = await freezeBoardsIn(tx, event, w.period, { from: w.from, to: event.endsAt }, now);
  const settled = !anyPrize && !(await pendingLeftIn(tx, event));
  await tx.event.update({
    where: { id: event.id },
    data: { frozenAt: now, payoutDueAt: now, ...(settled ? { paidAt: now } : { paidAt: null }) },
  });
  return true;
}

/**
 * v1.101-social (D325): a recurring event whose current period ended (and whose series goes on) — the period's boards
 * are frozen and due (paid by the same pass unless held), and the next period starts where it ended (the boards start
 * again from 0; the period's results stay readable as «الفترة السابقة»). Once per period: the caller holds the row lock
 * and the `event_periods` key refuses a second freeze.
 */
export async function rollOverPeriodIn(tx: Tx, event: Event, now: Date, zone: string): Promise<boolean> {
  if (event.recurrence === 'NONE' || event.periodStartsAt === null || event.periodEndsAt === null)
    return false;
  if (event.periodEndsAt > now) return false;
  if (event.endsAt !== null && event.periodEndsAt >= event.endsAt) return false; // the final freeze does it
  const w = { from: event.periodStartsAt, to: event.periodEndsAt };
  if (!event.payoutHold) await grantMilestonesIn(tx, event, w, event.period, now);
  const anyPrize = await freezeBoardsIn(tx, event, event.period, w, now);
  const next = await nextPeriodStartIn(
    tx,
    event.recurrence as Exclude<EventRecurrence, 'NONE'>,
    event.periodEndsAt,
    event.timeZone ?? zone,
  );
  const settled = !anyPrize && !(await pendingLeftIn(tx, event));
  await tx.event.update({
    where: { id: event.id },
    data: {
      period: event.period + 1,
      periodStartsAt: event.periodEndsAt,
      periodEndsAt: event.endsAt !== null && event.endsAt < next ? event.endsAt : next,
      payoutDueAt: now,
      paidAt: settled ? now : null,
    },
  });
  return true;
}

/**
 * v1.101-social (D325, §10.127): gives every milestone reached in the window (in the caller's locked transaction): each
 * entrant of the milestone's board whose score reaches its points gets the bundle once per period (the
 * `event_milestone_grants_once` key; CP: both partners; AGENCIES: the owner), only ACTIVE accounts (the others
 * FORFEITED), with an EVENT_PRIZE_WON notification. Returns how many were given.
 */
export async function grantMilestonesIn(
  tx: Tx,
  event: Event,
  w: ScoreWindow,
  period: number,
  now: Date,
): Promise<number> {
  const milestones = await tx.eventMilestone.findMany({
    where: { eventId: event.id },
    orderBy: [{ board: 'asc' }, { points: 'asc' }],
  });
  if (milestones.length === 0 || w.to <= w.from) return 0;
  let given = 0;
  const boards = [...new Set(milestones.map((m) => m.board as EventBoardKind))];
  for (const kind of boards) {
    const steps = milestones.filter((m) => m.board === kind);
    const lowest = steps[0]!.points;
    const rows = await tx.$queryRaw<BoardRow[]>`
      SELECT * FROM (${boardRankedSql(event, kind, w)}) b WHERE b.score >= ${lowest} ORDER BY b.rank`;
    for (const r of rows) {
      for (const m of steps) {
        if (r.score < m.points) break;
        for (const userId of r.partner_id ? [r.user_id, r.partner_id] : [r.user_id]) {
          const inserted = await tx.$queryRaw<{ id: string; status: string }[]>`
            INSERT INTO event_milestone_grants (id, milestone_id, user_id, period, score, status, created_at)
            SELECT gen_random_uuid(), ${m.id}::uuid, ${userId}::uuid, ${period}, ${r.score},
                   CASE WHEN u.status = 'ACTIVE' THEN 'PAID' ELSE 'FORFEITED' END, ${now}
              FROM users u WHERE u.id = ${userId}::uuid
            ON CONFLICT (milestone_id, user_id, period) DO NOTHING
            RETURNING id::text AS id, status`;
          const grant = inserted[0];
          if (!grant || grant.status !== 'PAID') continue;
          const granted = await grantBundleIn(tx, userId, grant.id, parseBundle(m.prizes), now, event.id);
          await tx.eventMilestoneGrant.update({
            where: { id: grant.id },
            data: { granted: granted as Prisma.InputJsonValue },
          });
          await tx.notification.create({
            data: {
              recipientId: userId,
              type: 'EVENT_PRIZE_WON',
              eventId: event.id,
              createdAt: now,
              updatedAt: now,
            },
          });
          given++;
        }
      }
    }
  }
  if (given > 0) {
    await tx.auditLog.create({
      data: {
        actorUserId: null,
        action: 'event.milestones',
        targetType: 'event',
        targetId: event.id,
        metadata: { period, given, via: 'system' },
      },
    });
  }
  return given;
}

async function lockVipUser(tx: Tx, userId: string): Promise<void> {
  await tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtext('kabso:vip-user'), hashtext(${userId}))`;
}

/**
 * A VIP prize of `days` on tier `tierCode`: no membership (or ended) — the tier from now; the same tier — the end moves
 * by `days`; a higher tier held — that membership is extended by `days` (a prize never lowers a tier); a lower tier held
 * — the prize tier from now for `days` (as an upgrade). Returns the new end, or null when the tier is gone.
 */
async function grantVipIn(tx: Tx, userId: string, tierCode: string, days: number, now: Date) {
  const tier = await tx.vipTier.findUnique({ where: { code: tierCode } });
  if (!tier) return null;
  await lockVipUser(tx, userId);
  const held = await tx.vipMembership.findUnique({ where: { userId }, include: { tier: true } });
  const length = days * DAY_MS;
  const active = held !== null && held.expiresAt > now;
  if (!active) {
    const expiresAt = new Date(now.getTime() + length);
    await tx.vipMembership.upsert({
      where: { userId },
      create: { userId, tierId: tier.id, startedAt: now, expiresAt },
      update: { tierId: tier.id, startedAt: now, expiresAt, offPerks: [] },
    });
    return { tierCode: tier.code, expiresAt };
  }
  if (held.tierId === tier.id || held.tier.sortOrder > tier.sortOrder) {
    const expiresAt = new Date(held.expiresAt.getTime() + length);
    await tx.vipMembership.update({ where: { userId }, data: { expiresAt } });
    return { tierCode: held.tier.code, expiresAt };
  }
  const expiresAt = new Date(now.getTime() + length);
  await tx.vipMembership.update({ where: { userId }, data: { tierId: tier.id, startedAt: now, expiresAt } });
  return { tierCode: tier.code, expiresAt };
}

/** Gives one winner a bundle (the payout row `payoutId` is the ledger reference). Returns what was given. */
async function grantBundleIn(
  tx: Tx,
  userId: string,
  payoutId: string,
  bundle: readonly PrizeItem[],
  now: Date,
  eventId: string,
): Promise<Record<string, unknown>[]> {
  const granted: Record<string, unknown>[] = [];
  for (const item of bundle) {
    switch (item.type) {
      case 'COINS':
        await creditIn(tx, userId, BigInt(item.amount), 'EVENT_PRIZE', payoutId);
        granted.push({ ...item });
        break;
      case 'CHERRIES':
        await creditEventPrizeCherriesIn(tx, userId, BigInt(item.amount), `EVP:${payoutId}`, now);
        granted.push({ ...item });
        break;
      case 'CP_MONEY': {
        // Owner: a partner who is an approved host or a content creator NOW gets the cherries, else the coins.
        const [role] = await tx.$queryRaw<{ host: boolean }[]>`
          SELECT (EXISTS (SELECT 1 FROM live_hosts h WHERE h.user_id = ${userId}::uuid)
               OR EXISTS (SELECT 1 FROM creator_members c WHERE c.user_id = ${userId}::uuid)) AS host`;
        const host = role?.host === true;
        if (host && item.cherries > 0) {
          await creditEventPrizeCherriesIn(tx, userId, BigInt(item.cherries), `EVP:${payoutId}`, now);
        } else if (!host && item.coins > 0) {
          await creditIn(tx, userId, BigInt(item.coins), 'EVENT_PRIZE', payoutId);
        }
        granted.push({ ...item, paidAs: host ? 'CHERRIES' : 'COINS' });
        break;
      }
      case 'BAG_ITEM': {
        const ref = await catalogueItemIn(tx, item.itemCode);
        if (!ref) {
          granted.push({ ...item, skipped: 'item_gone' });
          break;
        }
        await lockItemHoldersIn(tx, ref.code, [userId]);
        const out = await addItemTimeIn(tx, {
          userId,
          item: ref,
          source: 'EVENT',
          giftedById: null,
          durationMs: item.days === null ? null : item.days * DAY_MS,
          now,
        });
        granted.push({
          ...item,
          outcome: out.kind,
          expiresAt: 'expiresAt' in out ? (out.expiresAt?.toISOString() ?? null) : null,
        });
        break;
      }
      case 'BADGE': {
        const badge = await tx.eventBadgeLevel
          .findUnique({
            where: { badgeCode_level: { badgeCode: item.badgeCode, level: item.level } },
            select: { badgeCode: true },
          })
          .then((l) => (l ? { code: l.badgeCode } : null));
        if (!badge) {
          granted.push({ ...item, skipped: 'badge_gone' });
          break;
        }
        // A medal held now gets the days added (a permanent one stays permanent; a permanent prize makes it permanent);
        // an ended (or no) one starts now. The higher level is kept while it lasts.
        const days = item.days;
        const [row] = await tx.$queryRaw<{ expires_at: Date | null }[]>`
          INSERT INTO user_event_badges (user_id, badge_code, level, expires_at, granted_at, event_id)
          VALUES (${userId}::uuid, ${badge.code}, ${item.level}::smallint,
                  ${days === null ? null : new Date(now.getTime() + days * DAY_MS)}::timestamptz, ${now}, ${eventId}::uuid)
          ON CONFLICT (user_id, badge_code) DO UPDATE
             SET expires_at = CASE
                   WHEN ${days === null} OR user_event_badges.expires_at IS NULL THEN NULL::timestamptz
                   ELSE GREATEST(user_event_badges.expires_at, ${now}::timestamptz)
                        + make_interval(days => ${days ?? 0}::int) END,
                 level = CASE WHEN user_event_badges.expires_at IS NULL OR user_event_badges.expires_at > ${now}::timestamptz
                              THEN GREATEST(user_event_badges.level, EXCLUDED.level) ELSE EXCLUDED.level END,
                 granted_at = ${now}, event_id = EXCLUDED.event_id
          RETURNING expires_at`;
        granted.push({ ...item, expiresAt: row!.expires_at?.toISOString() ?? null });
        break;
      }
      case 'GIFT_PIECES': {
        // v1.101-social (D325): free pieces in the gift bag (a disabled or ended gift may be held; sent from the bag).
        const held = await grantStockIn(tx, userId, item.giftCode, item.count);
        granted.push(held === null ? { ...item, skipped: 'bag_full' } : { ...item, quantity: held });
        break;
      }
      case 'VIP': {
        const vip = await grantVipIn(tx, userId, item.tierCode, item.days, now);
        granted.push(
          vip
            ? { ...item, heldTier: vip.tierCode, expiresAt: vip.expiresAt.toISOString() }
            : { ...item, skipped: 'tier_gone' },
        );
        break;
      }
    }
  }
  return granted;
}

/**
 * Pays every pending result of a frozen gift event (in the caller's locked transaction): each winner once (the
 * `event_prize_payouts_once` key — a CP result pays both partners), only ACTIVE accounts (the others FORFEITED), with an
 * EVENT_PRIZE_WON notification and one `event.payout` audit row. Returns the number of winners paid.
 */
export async function payGiftEventIn(tx: Tx, event: Event, now: Date): Promise<number> {
  // v1.101-social (D325): milestones of the frozen periods not given while held (idempotent: once per key).
  if ((await tx.eventMilestone.count({ where: { eventId: event.id } })) > 0) {
    const periods = await tx.eventPeriod.findMany({
      where: { eventId: event.id },
      orderBy: { period: 'asc' },
    });
    for (const p of periods) {
      await grantMilestonesIn(tx, event, { from: p.startsAt, to: p.endsAt }, p.period, now);
    }
  }
  const pending = await tx.eventResult.findMany({
    where: { eventId: event.id, prizeStatus: 'PENDING' },
    orderBy: [{ board: 'asc' }, { rank: 'asc' }],
  });
  let paid = 0;
  let forfeited = 0;
  for (const r of pending) {
    const bundle = parseBundle(r.prize);
    const winners = r.partnerId ? [r.userId, r.partnerId] : [r.userId];
    let anyPaid = false;
    for (const userId of winners) {
      const done = await tx.eventPrizePayout.findUnique({
        where: { resultId_userId: { resultId: r.id, userId } },
      });
      if (done) {
        anyPaid ||= done.status === 'PAID';
        continue;
      }
      const user = await tx.user.findUnique({ where: { id: userId }, select: { status: true } });
      if (user?.status !== 'ACTIVE') {
        await tx.eventPrizePayout.create({
          data: { resultId: r.id, userId, status: 'FORFEITED', createdAt: now },
        });
        forfeited++;
        continue;
      }
      const payout = await tx.eventPrizePayout.create({
        data: { resultId: r.id, userId, status: 'PAID', createdAt: now },
        select: { id: true },
      });
      const granted = await grantBundleIn(tx, userId, payout.id, bundle, now, event.id);
      await tx.eventPrizePayout.update({
        where: { id: payout.id },
        data: { granted: granted as Prisma.InputJsonValue },
      });
      await tx.notification.create({
        data: {
          recipientId: userId,
          type: 'EVENT_PRIZE_WON',
          eventId: event.id,
          createdAt: now,
          updatedAt: now,
        },
      });
      anyPaid = true;
      paid++;
    }
    await tx.eventResult.update({
      where: { id: r.id },
      data: anyPaid ? { prizeStatus: 'PAID', paidAt: now } : { prizeStatus: 'FORFEITED' },
    });
  }
  await tx.event.update({ where: { id: event.id }, data: { paidAt: now } });
  await tx.auditLog.create({
    data: {
      actorUserId: null,
      action: AuditAction.EVENT_PAYOUT,
      targetType: 'event',
      targetId: event.id,
      metadata: { results: pending.length, paid, forfeited, via: 'system' },
    },
  });
  return paid;
}

/**
 * v1.101-social (D325, §10.127): the Prisma filter of the gifts listed in the gift panel now — every gift that is not an
 * event's own, and an event's own gift only while that event is published and running (owner: sent by everyone during
 * the event; afterwards not buyable — the winners send their pieces from the bag).
 */
export function eventGiftListedWhere(now: Date): Prisma.GiftWhereInput {
  return {
    OR: [
      { eventId: null },
      {
        event: {
          status: 'PUBLISHED',
          frozenAt: null,
          startsAt: { lte: now },
          OR: [{ endsAt: null }, { endsAt: { gt: now } }],
        },
      },
    ],
  };
}

/** Whether an event's own gift may be bought (sent with coins) now: its event published and running. */
export async function eventGiftBuyableIn(
  db: Pick<Tx, 'event'>,
  eventId: string,
  now: Date,
): Promise<boolean> {
  const e = await db.event.findUnique({
    where: { id: eventId },
    select: { status: true, startsAt: true, endsAt: true, frozenAt: true },
  });
  return (
    e !== null &&
    e.status === 'PUBLISHED' &&
    e.frozenAt === null &&
    e.startsAt !== null &&
    e.startsAt <= now &&
    (e.endsAt === null || e.endsAt > now)
  );
}
