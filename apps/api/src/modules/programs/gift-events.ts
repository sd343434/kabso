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
import { creditIn } from '../wallet/wallet-ledger.js';
import { EVENT_TONES, EventAdminError } from './event-admin-rules.js';
import { EVENT_LEADERBOARD_MAX } from './programs-rules.js';

type Tx = Prisma.TransactionClient;

const DAY_MS = 86_400_000;

/**
 * The board kinds (CHECK `event_boards_kind`): SENDERS «ترتيب الداعمين» (who sent the event gifts), RECEIVERS «ترتيب
 * المضيفين» (who received them — never a content-creator member, D295), CREATORS «صناع المحتوى» (creator members who
 * received them), AGENCIES «الوكالات» (the receiving host's agency at the time of the gift; the prize to its owner) and CP
 * (the event gifts two partners sent each other while a couple; both partners win the bundle).
 */
export const EVENT_BOARD_KINDS = ['SENDERS', 'RECEIVERS', 'CREATORS', 'AGENCIES', 'CP'] as const;
export type EventBoardKind = (typeof EVENT_BOARD_KINDS)[number];

/** v1.97-social (D303 follow-up): `BADGE` — an event badge «وسام فعالية» with its own picture, for N days. */
export const PRIZE_ITEM_TYPES = ['COINS', 'CHERRIES', 'CP_MONEY', 'BAG_ITEM', 'VIP', 'BADGE'] as const;
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
    };

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
  title: /^media\/events\/title\/[0-9a-f-]{36}\.webp$/,
  overlay: /^media\/events\/overlay\/[0-9a-f-]{36}\.(svga|json)$/,
  badge: /^media\/events\/badge\/[0-9a-f-]{36}\.webp$/,
} as const;

const amount = z.number().int().min(1).max(GIFT_EVENT_LIMITS.maxAmount);
const days = z.number().int().min(1).max(GIFT_EVENT_LIMITS.maxDays);
const code = z
  .string()
  .trim()
  .regex(/^[A-Za-z0-9_.-]{1,40}$/);

export const prizeItemSchema = z.discriminatedUnion('type', [
  z.strictObject({ type: z.literal('COINS'), amount }),
  z.strictObject({ type: z.literal('CHERRIES'), amount }),
  z
    .strictObject({
      type: z.literal('CP_MONEY'),
      cherries: z.number().int().min(0).max(GIFT_EVENT_LIMITS.maxAmount),
      coins: z.number().int().min(0).max(GIFT_EVENT_LIMITS.maxAmount),
    })
    .refine((v) => v.cherries > 0 || v.coins > 0, { message: 'cherries or coins above 0' }),
  // Owner (D303 follow-up): an item or a medal may be permanent («دائم»: `days: null`); VIP stays days-only (a
  // membership always ends: `vip_memberships.expires_at` is required).
  z.strictObject({ type: z.literal('BAG_ITEM'), itemCode: code, days: days.nullable() }),
  z.strictObject({ type: z.literal('VIP'), tierCode: code, days }),
  z.strictObject({
    type: z.literal('BADGE'),
    badgeCode: z.string().regex(EVENT_BADGE_CODE),
    level: z.number().int().min(1).max(10).default(1),
    days: days.nullable(),
  }),
]);

export const prizeLineSchema = z.strictObject({
  rankFrom: z.number().int().min(1).max(EVENT_LEADERBOARD_MAX),
  rankTo: z.number().int().min(1).max(EVENT_LEADERBOARD_MAX),
  items: z.array(prizeItemSchema).min(1).max(GIFT_EVENT_LIMITS.itemsPerLine),
});

const isoInstant = z.iso.datetime({ offset: true });
const text = (max: number) => z.string().trim().max(max);

/** `GiftEventInput` (openapi): the body of a create or a full edit, from the panel and from the app. */
export const giftEventInputSchema = z.strictObject({
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
  startsAt: isoInstant,
  endsAt: isoInstant,
  timeZone: z.string().trim().min(1).max(64).nullable().optional(),
  audience: z.enum(['EVERYONE', 'HOSTS', 'CREATORS']).default('EVERYONE'),
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
        pointsPerCoin: z.number().int().min(0).max(GIFT_EVENT_LIMITS.maxPointsPerCoin).default(1),
        pointsPerGift: z.number().int().min(0).max(GIFT_EVENT_LIMITS.maxPointsPerGift).default(0),
      }),
    )
    .min(1)
    .max(GIFT_EVENT_LIMITS.gifts),
  boards: z
    .array(
      z.strictObject({
        kind: z.enum(EVENT_BOARD_KINDS),
        minPoints: z.number().int().min(0).max(GIFT_EVENT_LIMITS.maxMinPoints).default(0),
        prizes: z.array(prizeLineSchema).max(GIFT_EVENT_LIMITS.prizeLines).default([]),
      }),
    )
    .min(1)
    .max(GIFT_EVENT_LIMITS.boards),
  reason: z.string().trim().min(3).max(500),
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
    const kinds = line.items.map((i) =>
      i.type === 'BAG_ITEM' ? `B:${i.itemCode}` : i.type === 'BADGE' ? `M:${i.badgeCode}` : i.type,
    );
    if (new Set(kinds).size !== kinds.length) {
      problems.push(`Ranks ${line.rankFrom}–${line.rankTo}: an item is listed twice.`);
    }
  }
  return problems;
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

/** Parses a stored bundle (`event_results.prize`). */
export function parseBundle(value: unknown): PrizeItem[] {
  const parsed = z.array(prizeItemSchema).safeParse(value);
  return parsed.success ? parsed.data : [];
}

/** Cross-field rules, pure (dates, duplicates, prize lines). Throws {@link EventAdminError}. */
export function checkGiftEventShape(input: GiftEventInput, now: Date): { startsAt: Date; endsAt: Date } {
  const startsAt = new Date(input.startsAt);
  const endsAt = new Date(input.endsAt);
  if (endsAt <= startsAt) throw new EventAdminError('The end must be after the start.');
  if (endsAt.getTime() - startsAt.getTime() > GIFT_EVENT_LIMITS.maxLengthDays * DAY_MS) {
    throw new EventAdminError(`An event lasts at most ${GIFT_EVENT_LIMITS.maxLengthDays} days.`);
  }
  if (startsAt.getTime() > now.getTime() + GIFT_EVENT_LIMITS.maxLeadDays * DAY_MS) {
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
  for (const g of input.gifts) {
    if (g.pointsPerCoin === 0 && g.pointsPerGift === 0) {
      throw new EventAdminError(`Gift ${g.giftCode} gives no points.`);
    }
  }
  const kinds = input.boards.map((b) => b.kind);
  if (new Set(kinds).size !== kinds.length) throw new EventAdminError('A board is listed twice.');
  for (const b of input.boards) {
    const problems = prizeLineProblems(b.prizes);
    if (problems.length > 0) throw new EventAdminError(`${b.kind}: ${problems.join(' ')}`);
    // Owner (D303 follow-ups): the money of each board — hosts / creators / CP couples win cherries, supporters
    // coins, agencies either (chosen per line); items, medals and VIP on every board.
    const allowed = BOARD_MONEY_ALLOWED[b.kind];
    const wrong = b.prizes
      .flatMap((l) => l.items)
      .find((i) => MONEY_TYPES.includes(i.type) && !allowed.includes(i.type));
    if (wrong) {
      throw new EventAdminError(
        `${b.kind}: this board's money is ${allowed.join(' or ')}, not ${wrong.type}.`,
      );
    }
  }
  return { startsAt, endsAt };
}

/** The catalogue checks (gifts, bag items, VIP tiers exist). Throws {@link EventAdminError}. */
async function checkCatalogueIn(tx: Tx, input: GiftEventInput): Promise<void> {
  const giftCodes = input.gifts.map((g) => g.giftCode);
  const gifts = await tx.gift.findMany({ where: { code: { in: giftCodes } }, select: { code: true } });
  const missingGift = giftCodes.find((c) => !gifts.some((g) => g.code === c));
  if (missingGift) throw new EventAdminError(`No gift ${missingGift}.`);
  const items = input.boards.flatMap((b) => b.prizes.flatMap((l) => l.items));
  const bagCodes = [...new Set(items.flatMap((i) => (i.type === 'BAG_ITEM' ? [i.itemCode] : [])))];
  if (bagCodes.length > 0) {
    const found = await tx.bagItem.findMany({ where: { code: { in: bagCodes } }, select: { code: true } });
    const missing = bagCodes.find((c) => !found.some((f) => f.code === c));
    if (missing) throw new EventAdminError(`No bag item ${missing}.`);
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
}

function rowFields(input: GiftEventInput, startsAt: Date, endsAt: Date) {
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
    timeZone: input.timeZone ?? null,
    audience: input.audience,
    regions: [...new Set(input.regions.map((r) => r.toUpperCase()))],
    featured: input.featured,
    backgroundKey: input.backgroundKey ?? null,
    backgroundPosterKey: input.backgroundPosterKey ?? null,
    titleKey: input.titleKey ?? null,
    overlayKey: input.overlayKey ?? null,
  };
}

async function writeStructureIn(tx: Tx, eventId: string, input: GiftEventInput): Promise<void> {
  await tx.eventGift.deleteMany({ where: { eventId } });
  await tx.eventBoard.deleteMany({ where: { eventId } });
  await tx.eventGift.createMany({
    data: input.gifts.map((g, i) => ({
      eventId,
      giftCode: g.giftCode,
      pointsPerCoin: g.pointsPerCoin,
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
    })),
  });
}

function auditMeta(input: GiftEventInput, by: AdminVia) {
  return {
    metric: 'EVENT_GIFTS',
    audience: input.audience,
    startsAt: input.startsAt,
    endsAt: input.endsAt,
    timeZone: input.timeZone ?? null,
    gifts: input.gifts.map((g) => `${g.giftCode}:${g.pointsPerCoin}/${g.pointsPerGift}`),
    boards: input.boards.map((b) => ({ kind: b.kind, minPoints: b.minPoints, lines: b.prizes.length })),
    reason: input.reason,
    via: by.via,
  };
}

/** Creates an EVENT_GIFTS event (panel `POST /admin/gift-events`, app `POST /staff/gift-events`), audited. */
export async function createGiftEventIn(
  tx: Tx,
  input: GiftEventInput,
  now: Date,
  by: AdminVia,
): Promise<{ id: string }> {
  const { startsAt, endsAt } = checkGiftEventShape(input, now);
  if (endsAt <= now) throw new EventAdminError('The end is in the past.');
  await checkCatalogueIn(tx, input);
  const row = await tx.event.create({
    data: {
      ...rowFields(input, startsAt, endsAt),
      metric: 'EVENT_GIFTS',
      permanent: false,
      prizes: [],
      createdById: by.actorUserId,
    },
    select: { id: true },
  });
  await writeStructureIn(tx, row.id, input);
  await tx.auditLog.create({
    data: {
      ...auditBy(by),
      action: AuditAction.EVENT_CREATE,
      targetType: 'event',
      targetId: row.id,
      metadata: auditMeta(input, by),
    },
  });
  return row;
}

/**
 * A full edit of an EVENT_GIFTS event. Before its start everything may change; once it runs only the texts, the
 * banner, the calendar style, «رائج» and a later end (the gifts, boards, start, audience and regions must stay as they
 * are); once it ended nothing (409).
 */
export async function updateGiftEventIn(
  tx: Tx,
  eventId: string,
  input: GiftEventInput,
  now: Date,
  by: AdminVia,
): Promise<{ id: string }> {
  const [locked] = await tx.$queryRaw<{ id: string }[]>`
    SELECT id::text AS id FROM events WHERE id = ${eventId}::uuid FOR UPDATE`;
  const event = locked ? await tx.event.findUnique({ where: { id: eventId } }) : null;
  if (!event) throw new EventAdminError(`No event ${eventId}.`);
  if (event.metric !== 'EVENT_GIFTS') throw new EventAdminError('Only gift events are edited here.');
  if (event.frozenAt !== null || (event.endsAt !== null && event.endsAt <= now)) {
    throw new EventAdminError('This event has ended; it can no longer change.');
  }
  const { startsAt, endsAt } = checkGiftEventShape(input, now);
  if (endsAt <= now) throw new EventAdminError('The end is in the past.');
  await checkCatalogueIn(tx, input);
  const running = event.startsAt <= now;
  if (running) {
    const [gifts, boards] = await Promise.all([
      tx.eventGift.findMany({ where: { eventId }, orderBy: { sortOrder: 'asc' } }),
      tx.eventBoard.findMany({ where: { eventId }, orderBy: { sortOrder: 'asc' } }),
    ]);
    const sameGifts =
      JSON.stringify(gifts.map((g) => [g.giftCode, g.pointsPerCoin, g.pointsPerGift])) ===
      JSON.stringify(input.gifts.map((g) => [g.giftCode, g.pointsPerCoin, g.pointsPerGift]));
    const sameBoards =
      JSON.stringify(boards.map((b) => [b.kind, Number(b.minPoints), parsePrizeLines(b.prizes)])) ===
      JSON.stringify(input.boards.map((b) => [b.kind, b.minPoints, b.prizes]));
    const regions = [...new Set(input.regions.map((r) => r.toUpperCase()))];
    if (
      !sameGifts ||
      !sameBoards ||
      startsAt.getTime() !== event.startsAt.getTime() ||
      input.audience !== event.audience ||
      JSON.stringify(regions) !== JSON.stringify(event.regions.map((r) => r.trim()))
    ) {
      throw new EventAdminError(
        'The event has started: its gifts, boards, prizes, start, audience and regions can no longer change.',
      );
    }
    if (event.endsAt !== null && endsAt < event.endsAt) {
      throw new EventAdminError('The event has started: its end can only move later.');
    }
  }
  await tx.event.update({ where: { id: eventId }, data: rowFields(input, startsAt, endsAt) });
  if (!running) await writeStructureIn(tx, eventId, input);
  await tx.auditLog.create({
    data: {
      ...auditBy(by),
      action: AuditAction.EVENT_UPDATE,
      targetType: 'event',
      targetId: eventId,
      metadata: { ...auditMeta(input, by), running },
    },
  });
  return { id: eventId };
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

/**
 * Every recipient row of an event-gift send in [from, to): the sender, the recipient and its points
 * (`coins × points_per_coin + quantity × points_per_gift`). Never a send to oneself; the sender ACTIVE; a send whose
 * cherries the team reversed (`GIFT_REVERSAL`, fraud or a refunded payment) does not count (§10.114.2).
 */
function pointsSql(eventId: string, from: Date, to: Date): Prisma.Sql {
  return Prisma.sql`
    SELECT g.id AS gift_id, g.sender_id, r.user_id AS recipient_id, g.created_at,
           (r.coins * eg.points_per_coin + g.quantity::bigint * eg.points_per_gift)::bigint AS points
      FROM live_gifts g
      JOIN event_gifts eg ON eg.event_id = ${eventId}::uuid AND eg.gift_code = g.gift_code
      JOIN live_gift_recipients r ON r.gift_id = g.id AND r.user_id <> g.sender_id
      JOIN users s ON s.id = g.sender_id AND s.status = 'ACTIVE'
     WHERE g.created_at >= ${from}::timestamptz AND g.created_at < ${to}::timestamptz
       AND NOT EXISTS (SELECT 1 FROM cherry_ledger l
                        WHERE l.reference_id = g.id::text AND l.reason = 'GIFT_REVERSAL'::cherry_ledger_reason)`;
}

function regionSql(column: Prisma.Sql, regions: readonly string[]): Prisma.Sql {
  return Prisma.sql`(${regions.length === 0} OR EXISTS (SELECT 1 FROM user_profiles rp
          WHERE rp.user_id = ${column} AND rp.country_code = ANY(string_to_array(${regions.join(',')}::text, ','))))`;
}

/** The entrants of `kind` with their scores (> 0) in [startsAt, to), unranked. */
function entrantsSql(event: Event, kind: EventBoardKind, to: Date): Prisma.Sql {
  const p = pointsSql(event.id, event.startsAt, to);
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

/** The ranked board (score desc, then the entrant key) up to `to`. */
export function boardRankedSql(event: Event, kind: EventBoardKind, to: Date): Prisma.Sql {
  return Prisma.sql`
    SELECT e.entrant_key, e.user_id::text AS user_id, e.agency_id::text AS agency_id, e.agency_name,
           e.couple_id::text AS couple_id, e.partner_id::text AS partner_id, e.score,
           row_number() OVER (ORDER BY e.score DESC, e.entrant_key) AS rank
      FROM (${entrantsSql(event, kind, to)}) e
     WHERE e.score > 0`;
}

// ---------------------------------------------------------------------------------------------------------------
// Freeze and payout.

/** Freezes every board of an ended gift event into `event_results` (in the caller's locked transaction). */
export async function freezeGiftEventIn(tx: Tx, event: Event, now: Date): Promise<boolean> {
  const boards = await tx.eventBoard.findMany({
    where: { eventId: event.id },
    orderBy: { sortOrder: 'asc' },
  });
  let anyPrize = false;
  for (const board of boards) {
    const kind = board.kind as EventBoardKind;
    const lines = parsePrizeLines(board.prizes);
    const rows = await tx.$queryRaw<BoardRow[]>`
      SELECT * FROM (${boardRankedSql(event, kind, event.endsAt!)}) b ORDER BY b.rank LIMIT ${EVENT_LEADERBOARD_MAX}`;
    if (rows.length === 0) continue;
    await tx.eventResult.createMany({
      data: rows.map((r) => {
        const qualified = r.score >= board.minPoints;
        const bundle = qualified ? bundleForRank(lines, Number(r.rank)) : [];
        if (bundle.length > 0) anyPrize = true;
        return {
          eventId: event.id,
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
  await tx.event.update({
    where: { id: event.id },
    // Owner decision 3: paid automatically at the end (no review window); the hold still stops it.
    data: { frozenAt: now, payoutDueAt: now, ...(anyPrize ? {} : { paidAt: now }) },
  });
  return true;
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
