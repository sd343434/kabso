import { Inject, Injectable, Logger, type OnModuleDestroy, type OnModuleInit } from '@nestjs/common';
import { z } from 'zod';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import type { ContentLanguage } from '../../common/http/content-language.js';
import { Clock } from '../../common/time/clock.js';
import { zodErrorToDetails } from '../../common/validation/zod-validation.pipe.js';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import { Prisma, type Event, type EventMetric, type ProgramAudience } from '../../generated/prisma/client.js';
import { safeErrorLog } from '../../logging/redact-text.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import type { UserSummaryDto } from '../live/live-rooms.service.js';
import { isUuid } from '../live/live.schemas.js';
import { USER_SUMMARY_SELECT, userSummary } from '../posts/post-views.js';
import { giftArtUrl } from '../gifts/gift-art.js';
import { StorageSettingsStore } from '../storage-settings/storage-settings.store.js';
import { creditIn } from '../wallet/wallet-ledger.js';
import {
  boardRankedSql,
  bundleCoins,
  bundleForRank,
  EVENT_BOARD_KINDS,
  freezeGiftEventIn,
  parseBundle,
  parsePrizeLines,
  payGiftEventIn,
  type BoardRow,
  type EventBoardKind,
  type PrizeItem,
} from './gift-events.js';
import { EVENT_LEADERBOARD_MAX, parseEventPrizes, prizeForRank, type EventPrize } from './programs-rules.js';

type Tx = Prisma.TransactionClient;

const DAY_MS = 86_400_000;
/** Ended events stay listed (permanent and regional tabs) this long. */
const ENDED_VISIBLE_MS = 30 * DAY_MS;
/** At most this many events in one list. */
const EVENTS_LIST_MAX = 200;

export const EVENT_TABS = ['CALENDAR', 'PERMANENT', 'REGIONAL'] as const;
export type EventTab = (typeof EVENT_TABS)[number];

export const eventsQuerySchema = z.strictObject({
  tab: z.enum(EVENT_TABS).default('CALENDAR'),
  month: z
    .string()
    .regex(/^\d{4}-(0[1-9]|1[0-2])$/)
    .optional(),
});

export type EventStatus = 'UPCOMING' | 'RUNNING' | 'ENDED';

/** v1.97-social (D303): `getEventLeaderboard?board=` (a gift event's board; a D166 event takes none). */
export const leaderboardQuerySchema = z.strictObject({ board: z.enum(EVENT_BOARD_KINDS).optional() });

/** `EventPrizeItem` (v1.97-social, D303): one item of a prize bundle, with what the app shows. */
export interface EventPrizeItemDto {
  type: PrizeItem['type'];
  /** COINS / CHERRIES: how many; null otherwise. */
  amount: number | null;
  /** BAG_ITEM / VIP: for how many days; null otherwise. */
  days: number | null;
  /** BAG_ITEM: the item code; VIP: the tier code; null otherwise. */
  code: string | null;
  /** The item's or tier's name in the requested language (null when gone from the catalogue). */
  name: string | null;
  /** BAG_ITEM: its bag category (AVATAR_FRAME, ENTRY_EFFECT …); VIP: `VIP`; null otherwise. */
  category: string | null;
  /** BAG_ITEM: the app's asset key; VIP: the tier's still (asset path or https URL); null otherwise. */
  assetKey: string | null;
  /** VIP: the tier colour `#RRGGBB`; null otherwise. */
  color: string | null;
  /** v1.97-social (D303 follow-up) BADGE: the medal level and that level's uploaded art (512 × 512, transparent). */
  imageUrl?: string | null;
  level?: number;
  /** v1.97-social (D303 follow-up) CP_MONEY: cherries for a host / creator partner, coins for another (payout time). */
  cherries?: number;
  coins?: number;
}

/** `EventPrizeLine`. */
export interface EventPrizeLineDto {
  rankFrom: number;
  rankTo: number;
  items: EventPrizeItemDto[];
}

/** `EventBoard` (v1.97-social, D303). */
export interface EventBoardDto {
  kind: EventBoardKind;
  /** The qualification minimum: below it no prize. */
  minPoints: number;
  prizes: EventPrizeLineDto[];
}

/** `EventGift` (v1.97-social, D303): one gift of a gift event and its points. */
export interface EventGiftDto {
  code: string;
  name: string;
  priceCoins: number;
  assetKey: string;
  imageUrl: string | null;
  pointsPerCoin: number;
  pointsPerGift: number;
  /** The points one gift of this kind earns per recipient (`priceCoins × pointsPerCoin + pointsPerGift`). */
  pointsEach: number;
}

/** `EventSummary` (openapi v1.44-social, D166). */
export interface EventSummaryDto {
  id: string;
  title: string;
  bannerUrl: string | null;
  startsAt: string;
  endsAt: string | null;
  status: EventStatus;
  metric: EventMetric;
  audience: ProgramAudience;
  permanent: boolean;
  featured: boolean;
  regions: string[];
  /** v1.50-social (D176): the calendar bar's second line (a short prize line), null when none. */
  summary: string | null;
  /** v1.50-social (D176): the calendar bar's tone, null = a hue from the id. */
  tone: EventTone | null;
}

/** v1.50-social (D176): Kabso hues for an event's calendar bar (`events.tone`). */
export type EventTone = 'RED' | 'GOLD' | 'TEAL' | 'BLUE' | 'PINK' | 'AMBER';

/** `EventList`. */
export interface EventListDto {
  tab: EventTab;
  /** The calendar month (`YYYY-MM`), null for the other tabs. */
  month: string | null;
  timeZone: string;
  /** The caller's country (the regional tab), null when not set. */
  country: string | null;
  data: EventSummaryDto[];
}

/** `EventDetail`. */
export interface EventDetailDto extends EventSummaryDto {
  rules: string;
  prizes: EventPrize[];
  /** v1.97-social (D303): the IANA zone the app shows the dates in (the event's own, else the server's). */
  timeZone: string;
  /** v1.97-social (D303 follow-ups, §10.114.9): the page art uploaded for the event (null parts: none). */
  art: {
    background: { kind: 'IMAGE' | 'ANIMATED' | 'VIDEO'; url: string; posterUrl: string | null } | null;
    titleUrl: string | null;
    overlay: { format: 'SVGA' | 'LOTTIE'; url: string } | null;
  };
  /** v1.97-social (D303): an EVENT_GIFTS event's gifts and boards (empty for the other metrics). */
  gifts: EventGiftDto[];
  boards: EventBoardDto[];
  /** When the leaderboard was frozen (after the end), the payout time, and when prizes were paid. */
  frozenAt: string | null;
  payoutDueAt: string | null;
  paidAt: string | null;
}

/** `EventLeaderboardEntry`. */
export interface EventLeaderboardEntryDto {
  rank: number;
  /** The person; AGENCIES: the agency's owner; CP: the first partner (`partner` the second). */
  user: UserSummaryDto;
  score: number;
  prizeCoins: number;
  /** v1.97-social (D303, gift events): CP — the second partner; AGENCIES — the agency. Absent otherwise. */
  partner?: UserSummaryDto;
  agency?: { id: string; name: string | null };
  /** v1.97-social (D303, gift events): the score reaches the board's minimum, and the bundle of this rank. */
  qualified?: boolean;
  prize?: EventPrizeItemDto[];
}

/** `EventLeaderboard`. */
export interface EventLeaderboardDto {
  eventId: string;
  metric: EventMetric;
  /** True once the board is frozen (the final results). */
  final: boolean;
  data: EventLeaderboardEntryDto[];
  /** The caller's own place: rank null when not on the board. */
  me: {
    rank: number | null;
    score: number;
    prizeCoins: number;
    /** v1.97-social (D303, gift events): qualified, and the points still missing to reach the minimum. */
    qualified?: boolean;
    pointsToQualify?: number;
    prize?: EventPrizeItemDto[];
  };
  /** v1.97-social (D303): the board shown (null for a D166 event) and its minimum. */
  board?: EventBoardKind | null;
  minPoints?: number;
}

export interface EventsSweepResult {
  readonly frozen: number;
  readonly paid: number;
}

interface RankRow {
  user_id: string;
  score: bigint;
  rank: bigint;
}

/**
 * Every person's score for `metric` in [from, to) (column `user_id`, `score` > 0), from the tables the
 * popularity board, the data center and the creator center already read — no new counting path.
 * Counterparts (gift senders, followers) must be ACTIVE.
 */
function scoresSql(metric: EventMetric, from: Date, to: Date): Prisma.Sql {
  switch (metric) {
    case 'GIFT_COINS_RECEIVED':
      return Prisma.sql`
        SELECT gr.user_id, sum(gr.coins)::bigint AS score
          FROM live_gift_recipients gr
          JOIN live_gifts g ON g.id = gr.gift_id AND g.sender_id <> gr.user_id
          JOIN users s ON s.id = g.sender_id AND s.status = 'ACTIVE'
         WHERE g.created_at >= ${from}::timestamptz AND g.created_at < ${to}::timestamptz
         GROUP BY gr.user_id`;
    case 'GIFT_COINS_SENT':
      return Prisma.sql`
        SELECT gr.sender_id AS user_id, sum(gr.coins)::bigint AS score
          FROM (SELECT g.sender_id, r.coins
                  FROM live_gifts g
                  JOIN live_gift_recipients r ON r.gift_id = g.id AND r.user_id <> g.sender_id
                 WHERE g.created_at >= ${from}::timestamptz AND g.created_at < ${to}::timestamptz) gr
         GROUP BY gr.sender_id`;
    case 'LIVE_MINUTES':
      return Prisma.sql`
        SELECT r.host_user_id AS user_id,
               floor(sum(GREATEST(0, extract(epoch FROM (
                 LEAST(COALESCE(r.ended_at, r.last_heartbeat_at), ${to}::timestamptz)
                 - GREATEST(r.started_at, ${from}::timestamptz))))) / 60)::bigint AS score
          FROM live_rooms r
         WHERE r.started_at < ${to}::timestamptz AND COALESCE(r.ended_at, r.last_heartbeat_at) > ${from}::timestamptz
         GROUP BY r.host_user_id`;
    case 'TAPS_RECEIVED':
      return Prisma.sql`
        SELECT r.host_user_id AS user_id, sum(t.counted)::bigint AS score
          FROM live_room_tappers t
          JOIN live_rooms r ON r.id = t.room_id AND t.user_id <> r.host_user_id
         WHERE r.started_at >= ${from}::timestamptz AND r.started_at < ${to}::timestamptz
         GROUP BY r.host_user_id`;
    case 'NEW_FOLLOWERS':
      return Prisma.sql`
        SELECT f.followee_id AS user_id, count(*)::bigint AS score
          FROM follows f
          JOIN users u ON u.id = f.follower_id AND u.status = 'ACTIVE'
         WHERE f.created_at >= ${from}::timestamptz AND f.created_at < ${to}::timestamptz
         GROUP BY f.followee_id`;
    case 'EVENT_GIFTS':
      // v1.97-social (D303): ranked per board (`gift-events.boardRankedSql`), never as one board.
      return Prisma.sql`SELECT NULL::uuid AS user_id, 0::bigint AS score WHERE false`;
  }
}

/** The ranked board of `event` up to `to` (ACTIVE people, the event's audience and regions). */
function rankedSql(event: Event, to: Date): Prisma.Sql {
  const hostsOnly = event.audience === 'HOSTS';
  const regions = event.regions.map((r) => r.trim());
  return Prisma.sql`
    WITH s AS (${scoresSql(event.metric, event.startsAt, to)})
    SELECT s.user_id::text AS user_id, s.score,
           row_number() OVER (ORDER BY s.score DESC, s.user_id) AS rank
      FROM s
      JOIN users u ON u.id = s.user_id AND u.status = 'ACTIVE'
      JOIN user_profiles p ON p.user_id = s.user_id
     WHERE s.score > 0
       -- D295 (owner, int16): a content creator is not a host for host-only events (neither their own CREATOR
       -- permission nor the membership counts); creators get their own events later.
       AND (${!hostsOnly} OR (EXISTS (SELECT 1 FROM live_hosts h
                                       WHERE h.user_id = s.user_id AND h.source <> 'CREATOR'::live_host_source)
                              AND NOT EXISTS (SELECT 1 FROM creator_members cm WHERE cm.user_id = s.user_id)))
       AND (${regions.length === 0} OR p.country_code = ANY(string_to_array(${regions.join(',')}::text, ',')))`;
}

/**
 * The Event Center «مركز الفعاليات» (v1.44-social, D166, CP-024 §2 approved with defaults, CONVENTIONS
 * §10.41). Events are created by the team (`event-admin` CLI); each ranks people by one metric over its
 * dates. After the end the sweeper freezes the top 100 into `event_results` and, after the review window
 * (`EVENT_PRIZE_REVIEW_HOURS`, unless `event-admin hold`), pays every prize once (`EVENT_PRIZE`,
 * reference = the result row) to ACTIVE winners; others forfeit.
 */
@Injectable()
export class EventsService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger('EventsService');
  private timer: NodeJS.Timeout | undefined;
  private inFlight: Promise<void> | null = null;

  constructor(
    private readonly prisma: PrismaService,
    private readonly clock: Clock,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
    private readonly storageSettings: StorageSettingsStore,
  ) {}

  onModuleInit(): void {
    if (this.config.programs.eventsSweepIntervalSeconds > 0) this.schedule();
  }

  async onModuleDestroy(): Promise<void> {
    if (this.timer) clearTimeout(this.timer);
    await this.inFlight?.catch(() => undefined);
  }

  private schedule(): void {
    this.timer = setTimeout(() => {
      this.inFlight = this.sweep()
        .then((r) => {
          if (r.frozen + r.paid > 0) this.logger.log(r, 'Events swept');
        })
        .catch((err: unknown) => {
          this.logger.error({ error: safeErrorLog(err) }, 'Event sweep failed');
        })
        .finally(() => {
          this.inFlight = null;
          this.schedule();
        });
    }, this.config.programs.eventsSweepIntervalSeconds * 1000);
    this.timer.unref();
  }

  private get zone(): string {
    return this.config.live.rankingsTimeZone;
  }

  private status(e: Event, now: Date): EventStatus {
    if (now < e.startsAt) return 'UPCOMING';
    if (e.endsAt === null || now < e.endsAt) return 'RUNNING';
    return 'ENDED';
  }

  private summary(e: Event, now: Date, lang: ContentLanguage): EventSummaryDto {
    return {
      id: e.id,
      title: lang === 'ar' ? e.titleAr : e.titleEn,
      bannerUrl: e.bannerUrl,
      startsAt: e.startsAt.toISOString(),
      endsAt: e.endsAt?.toISOString() ?? null,
      status: this.status(e, now),
      metric: e.metric,
      audience: e.audience,
      permanent: e.permanent,
      featured: e.featured,
      regions: e.regions.map((r) => r.trim()),
      summary: lang === 'ar' ? e.summaryAr : e.summaryEn,
      tone: e.tone as EventTone | null,
    };
  }

  private async country(me: string): Promise<string | null> {
    const profile = await this.prisma.userProfile.findUnique({
      where: { userId: me },
      select: { countryCode: true },
    });
    return profile?.countryCode ?? null;
  }

  /** `GET /events?tab=CALENDAR|PERMANENT|REGIONAL&month=YYYY-MM`. */
  async list(me: string, query: unknown, lang: ContentLanguage): Promise<EventListDto> {
    const parsed = eventsQuerySchema.safeParse(query ?? {}, { reportInput: true });
    if (!parsed.success) throw AppException.validation(zodErrorToDetails(parsed.error));
    const { tab } = parsed.data;
    const now = this.clock.now();
    const country = await this.country(me);
    // D295 (owner, int16: «تختفي من عنده فعاليات المضيفين»): a content creator does not see host-only events.
    const creator = (await this.prisma.creatorMember.count({ where: { userId: me } })) > 0;
    // v1.97-social (D303): a creators-only event is shown to creator members only.
    const audience = creator
      ? { audience: { not: 'HOSTS' as const } }
      : { audience: { not: 'CREATORS' as const } };
    const visibleSince = new Date(now.getTime() - ENDED_VISIBLE_MS);
    let month: string | null = null;
    let events: Event[] = [];
    if (tab === 'CALENDAR') {
      const tz = this.zone;
      const [w] = await this.prisma.$queryRaw<{ month: string; start: Date; end: Date }[]>`
        WITH m AS (
          SELECT COALESCE(to_date(${parsed.data.month ?? null}::text, 'YYYY-MM'),
                          date_trunc('month', ${now}::timestamptz AT TIME ZONE ${tz}::text)::date) AS d)
        SELECT to_char(m.d, 'YYYY-MM') AS month,
               (m.d::timestamp AT TIME ZONE ${tz}::text) AS start,
               ((m.d + interval '1 month')::timestamp AT TIME ZONE ${tz}::text) AS "end"
          FROM m`;
      month = w!.month;
      events = await this.prisma.event.findMany({
        where: {
          ...audience,
          permanent: false,
          regions: { isEmpty: true },
          startsAt: { lt: w!.end },
          endsAt: { gt: w!.start },
        },
        orderBy: [{ startsAt: 'asc' }, { id: 'asc' }],
        take: EVENTS_LIST_MAX,
      });
    } else if (tab === 'PERMANENT') {
      events = await this.prisma.event.findMany({
        where: {
          ...audience,
          permanent: true,
          OR: [{ endsAt: null }, { endsAt: { gt: visibleSince } }],
          AND: [
            { OR: [{ regions: { isEmpty: true } }, ...(country ? [{ regions: { has: country } }] : [])] },
          ],
        },
        orderBy: [{ startsAt: 'desc' }, { id: 'asc' }],
        take: EVENTS_LIST_MAX,
      });
    } else if (country !== null) {
      events = await this.prisma.event.findMany({
        where: {
          ...audience,
          regions: { has: country },
          OR: [{ endsAt: null }, { endsAt: { gt: visibleSince } }],
        },
        orderBy: [{ startsAt: 'asc' }, { id: 'asc' }],
        take: EVENTS_LIST_MAX,
      });
    }
    return {
      tab,
      month,
      timeZone: this.zone,
      country,
      data: events.map((e) => this.summary(e, now, lang)),
    };
  }

  private async eventOr404(eventId: string): Promise<Event> {
    if (!isUuid(eventId)) throw new AppException(ErrorCode.NOT_FOUND);
    const event = await this.prisma.event.findUnique({ where: { id: eventId.toLowerCase() } });
    if (!event) throw new AppException(ErrorCode.NOT_FOUND);
    return event;
  }

  /** `GET /events/{eventId}`. */
  async detail(eventId: string, lang: ContentLanguage): Promise<EventDetailDto> {
    const e = await this.eventOr404(eventId);
    const gift = e.metric === 'EVENT_GIFTS';
    const [gifts, boards] = gift
      ? await Promise.all([
          this.prisma.eventGift.findMany({
            where: { eventId: e.id },
            orderBy: { sortOrder: 'asc' },
            include: { gift: true },
          }),
          this.prisma.eventBoard.findMany({ where: { eventId: e.id }, orderBy: { sortOrder: 'asc' } }),
        ])
      : [[], []];
    const base = this.storageSettings.current().publicBaseUrl;
    const lines = boards.map((b) => parsePrizeLines(b.prizes));
    const items = await this.itemNames(
      lines.flat().flatMap((l) => l.items),
      lang,
    );
    return {
      ...this.summary(e, this.clock.now(), lang),
      rules: lang === 'ar' ? e.rulesAr : e.rulesEn,
      prizes: parseEventPrizes(e.prizes) ?? [],
      timeZone: e.timeZone ?? this.zone,
      art: this.artOf(e),
      gifts: gifts.map((g) => ({
        code: g.giftCode,
        name: lang === 'ar' ? g.gift.nameAr : g.gift.nameEn,
        priceCoins: g.gift.priceCoins,
        assetKey: g.gift.assetKey,
        imageUrl: giftArtUrl(base, g.gift.imageObjectKey),
        pointsPerCoin: g.pointsPerCoin,
        pointsPerGift: g.pointsPerGift,
        pointsEach: g.gift.priceCoins * g.pointsPerCoin + g.pointsPerGift,
      })),
      boards: boards.map((b, i) => ({
        kind: b.kind as EventBoardKind,
        minPoints: Number(b.minPoints),
        prizes: lines[i]!.map((l) => ({ rankFrom: l.rankFrom, rankTo: l.rankTo, items: l.items.map(items) })),
      })),
      frozenAt: e.frozenAt?.toISOString() ?? null,
      payoutDueAt: e.payoutDueAt?.toISOString() ?? null,
      paidAt: e.paidAt?.toISOString() ?? null,
    };
  }

  /** v1.97-social (D303 follow-ups): an event's page art as URLs. */
  private artOf(e: Event): EventDetailDto['art'] {
    const base = this.storageSettings.current().publicBaseUrl;
    const url = (k: string | null) => giftArtUrl(base, k);
    const bg = e.backgroundKey;
    const bgUrl = url(bg);
    const overlayUrl = url(e.overlayKey);
    return {
      background:
        bg && bgUrl
          ? {
              kind: /\.(mp4|mov)$/.test(bg) ? 'VIDEO' : bg.endsWith('.anim.webp') ? 'ANIMATED' : 'IMAGE',
              url: bgUrl,
              posterUrl: url(e.backgroundPosterKey),
            }
          : null,
      titleUrl: url(e.titleKey),
      overlay:
        e.overlayKey && overlayUrl
          ? { format: e.overlayKey.endsWith('.json') ? 'LOTTIE' : 'SVGA', url: overlayUrl }
          : null,
    };
  }

  /** v1.97-social (D303): a function giving each prize item its display fields (names from the catalogues). */
  private async itemNames(
    all: readonly PrizeItem[],
    lang: ContentLanguage,
  ): Promise<(item: PrizeItem) => EventPrizeItemDto> {
    const bagCodes = [...new Set(all.flatMap((i) => (i.type === 'BAG_ITEM' ? [i.itemCode] : [])))];
    const tierCodes = [...new Set(all.flatMap((i) => (i.type === 'VIP' ? [i.tierCode] : [])))];
    const badgeCodes = [...new Set(all.flatMap((i) => (i.type === 'BADGE' ? [i.badgeCode] : [])))];
    const badges =
      badgeCodes.length > 0
        ? await this.prisma.eventBadge.findMany({
            where: { code: { in: badgeCodes } },
            include: { levels: true },
          })
        : [];
    const [bag, tiers] = await Promise.all([
      bagCodes.length > 0 ? this.prisma.bagItem.findMany({ where: { code: { in: bagCodes } } }) : [],
      tierCodes.length > 0 ? this.prisma.vipTier.findMany({ where: { code: { in: tierCodes } } }) : [],
    ]);
    return (item) => {
      switch (item.type) {
        case 'COINS':
        case 'CHERRIES':
          return {
            type: item.type,
            amount: item.amount,
            days: null,
            code: null,
            name: null,
            category: null,
            assetKey: null,
            color: null,
          };
        case 'BAG_ITEM': {
          const b = bag.find((x) => x.code === item.itemCode);
          return {
            type: item.type,
            amount: null,
            days: item.days,
            code: item.itemCode,
            name: b ? (lang === 'ar' ? b.nameAr : b.nameEn) : null,
            category: b?.category ?? null,
            assetKey: b?.assetKey ?? null,
            color: null,
          };
        }
        case 'VIP': {
          const t = tiers.find((x) => x.code === item.tierCode);
          return {
            type: item.type,
            amount: null,
            days: item.days,
            code: item.tierCode,
            name: t ? (lang === 'ar' ? t.nameAr : t.nameEn) : null,
            category: 'VIP',
            assetKey: t?.badgeStill ?? null,
            color: t?.color ?? null,
          };
        }
        case 'CP_MONEY':
          return {
            type: item.type,
            amount: null,
            days: null,
            code: null,
            name: null,
            category: null,
            assetKey: null,
            color: null,
            cherries: item.cherries,
            coins: item.coins,
          };
        case 'BADGE': {
          const b = badges.find((x) => x.code === item.badgeCode);
          return {
            type: item.type,
            amount: null,
            days: item.days,
            code: item.badgeCode,
            name: b ? (lang === 'ar' ? b.nameAr : b.nameEn) : null,
            category: 'BADGE',
            assetKey: null,
            color: null,
            level: item.level,
            imageUrl: giftArtUrl(
              this.storageSettings.current().publicBaseUrl,
              b?.levels.find((l) => l.level === item.level)?.imageKey ?? null,
            ),
          };
        }
      }
    };
  }

  /**
   * `GET /events/{eventId}/leaderboard`: the top 100 (live until the event is frozen, then the final
   * results) and the caller's own place. People the caller blocked or who blocked the caller are left
   * out of the list (their ranks stay, so the ranks match the prizes).
   */
  async leaderboard(
    me: string,
    eventId: string,
    query: unknown = {},
    lang: ContentLanguage = 'ar',
  ): Promise<EventLeaderboardDto> {
    const parsed = leaderboardQuerySchema.safeParse(query ?? {}, { reportInput: true });
    if (!parsed.success) throw AppException.validation(zodErrorToDetails(parsed.error));
    const e = await this.eventOr404(eventId);
    if (e.metric === 'EVENT_GIFTS') return this.giftLeaderboard(me, e, parsed.data.board, lang);
    if (parsed.data.board !== undefined) {
      throw AppException.validation([{ field: 'board', issue: 'invalid_value' }]);
    }
    const prizes = parseEventPrizes(e.prizes) ?? [];
    const now = this.clock.now();
    let rows: RankRow[];
    let mine: RankRow | undefined;
    if (e.frozenAt !== null) {
      const results = await this.prisma.eventResult.findMany({
        where: { eventId: e.id },
        orderBy: { rank: 'asc' },
        select: { userId: true, score: true, rank: true },
      });
      rows = results.map((r) => ({ user_id: r.userId, score: r.score, rank: BigInt(r.rank) }));
      mine = rows.find((r) => r.user_id === me);
    } else if (now < e.startsAt) {
      rows = [];
    } else {
      const to = e.endsAt !== null && e.endsAt < now ? e.endsAt : now;
      const ranked = rankedSql(e, to);
      rows = await this.prisma.$queryRaw<RankRow[]>`
        SELECT * FROM (${ranked}) b ORDER BY b.rank LIMIT ${EVENT_LEADERBOARD_MAX}`;
      [mine] = await this.prisma.$queryRaw<RankRow[]>`SELECT * FROM (${ranked}) b WHERE b.user_id = ${me}`;
    }
    const blocked = await this.prisma.userBlock.findMany({
      where: { OR: [{ blockerId: me }, { blockedId: me }] },
      select: { blockerId: true, blockedId: true },
    });
    const hidden = new Set(blocked.map((b) => (b.blockerId === me ? b.blockedId : b.blockerId)));
    const shown = rows.filter((r) => !hidden.has(r.user_id));
    const profiles = await this.prisma.user.findMany({
      where: { id: { in: shown.map((r) => r.user_id) } },
      select: USER_SUMMARY_SELECT,
    });
    const byId = new Map(profiles.map((u) => [u.id, u]));
    const myRank = mine ? Number(mine.rank) : null;
    return {
      eventId: e.id,
      metric: e.metric,
      final: e.frozenAt !== null,
      data: shown.flatMap((r) => {
        const u = byId.get(r.user_id);
        if (!u?.profile) return [];
        const rank = Number(r.rank);
        return [
          {
            rank,
            user: userSummary(u),
            score: Number(r.score),
            prizeCoins: prizeForRank(prizes, rank),
          },
        ];
      }),
      me: {
        rank: myRank,
        score: Number(mine?.score ?? 0n),
        prizeCoins: myRank === null ? 0 : prizeForRank(prizes, myRank),
      },
    };
  }

  /**
   * v1.97-social (D303, §10.114.5): one board of a gift event — the top 100 (live until frozen, then the results), the
   * board's minimum, each row's bundle, and the caller's place (SENDERS / RECEIVERS / CREATORS: the caller; AGENCIES:
   * the agency the caller owns; CP: the caller's best couple on the board).
   */
  private async giftLeaderboard(
    me: string,
    e: Event,
    wanted: EventBoardKind | undefined,
    lang: ContentLanguage,
  ): Promise<EventLeaderboardDto> {
    const boards = await this.prisma.eventBoard.findMany({
      where: { eventId: e.id },
      orderBy: { sortOrder: 'asc' },
    });
    const board = wanted === undefined ? boards[0] : boards.find((b) => b.kind === wanted);
    if (!board) throw AppException.validation([{ field: 'board', issue: 'invalid_value' }]);
    const kind = board.kind as EventBoardKind;
    const lines = parsePrizeLines(board.prizes);
    const now = this.clock.now();
    let rows: (BoardRow & { prize?: PrizeItem[] })[];
    let mine: (BoardRow & { prize?: PrizeItem[] }) | undefined;
    const isMine = (r: BoardRow) =>
      kind === 'CP' ? r.user_id === me || r.partner_id === me : r.user_id === me;
    if (e.frozenAt !== null) {
      const results = await this.prisma.eventResult.findMany({
        where: { eventId: e.id, board: kind },
        orderBy: { rank: 'asc' },
      });
      const agencies =
        kind === 'AGENCIES'
          ? await this.prisma.agency.findMany({
              where: { id: { in: results.flatMap((r) => (r.agencyId ? [r.agencyId] : [])) } },
              select: { id: true, name: true },
            })
          : [];
      rows = results.map((r) => ({
        entrant_key: r.entrantKey,
        user_id: r.userId,
        agency_id: r.agencyId,
        agency_name: agencies.find((a) => a.id === r.agencyId)?.name ?? null,
        couple_id: r.coupleId,
        partner_id: r.partnerId,
        score: r.score,
        rank: BigInt(r.rank),
        prize: parseBundle(r.prize),
      }));
      mine = rows.find(isMine);
    } else if (now < e.startsAt) {
      rows = [];
    } else {
      const to = e.endsAt !== null && e.endsAt < now ? e.endsAt : now;
      const ranked = boardRankedSql(e, kind, to);
      rows = await this.prisma.$queryRaw<BoardRow[]>`
        SELECT * FROM (${ranked}) b ORDER BY b.rank LIMIT ${EVENT_LEADERBOARD_MAX}`;
      [mine] = await this.prisma.$queryRaw<BoardRow[]>`
        SELECT * FROM (${ranked}) b
         WHERE b.user_id = ${me} OR (${kind === 'CP'} AND b.partner_id = ${me})
         ORDER BY b.rank LIMIT 1`;
    }
    const blocked = await this.prisma.userBlock.findMany({
      where: { OR: [{ blockerId: me }, { blockedId: me }] },
      select: { blockerId: true, blockedId: true },
    });
    const hidden = new Set(blocked.map((b) => (b.blockerId === me ? b.blockedId : b.blockerId)));
    const shown = rows.filter((r) => !hidden.has(r.user_id) && !(r.partner_id && hidden.has(r.partner_id)));
    const ids = [...new Set(shown.flatMap((r) => (r.partner_id ? [r.user_id, r.partner_id] : [r.user_id])))];
    const profiles = await this.prisma.user.findMany({
      where: { id: { in: ids } },
      select: USER_SUMMARY_SELECT,
    });
    const byId = new Map(profiles.map((u) => [u.id, u]));
    const minPoints = board.minPoints;
    const bundleOf = (r: BoardRow & { prize?: PrizeItem[] }) =>
      r.prize ?? (r.score >= minPoints ? [...bundleForRank(lines, Number(r.rank))] : []);
    const named = await this.itemNames(
      lines.flatMap((l) => l.items).concat(rows.flatMap((r) => r.prize ?? [])),
      lang,
    );
    const myBundle = mine ? bundleOf(mine) : [];
    const myScore = mine?.score ?? 0n;
    return {
      eventId: e.id,
      metric: e.metric,
      final: e.frozenAt !== null,
      board: kind,
      minPoints: Number(minPoints),
      data: shown.flatMap((r) => {
        const u = byId.get(r.user_id);
        if (!u?.profile) return [];
        const p = r.partner_id ? byId.get(r.partner_id) : undefined;
        if (r.partner_id && !p?.profile) return [];
        const bundle = bundleOf(r);
        return [
          {
            rank: Number(r.rank),
            user: userSummary(u),
            score: Number(r.score),
            prizeCoins: bundleCoins(bundle),
            ...(p ? { partner: userSummary(p) } : {}),
            ...(r.agency_id ? { agency: { id: r.agency_id, name: r.agency_name } } : {}),
            qualified: r.score >= minPoints,
            prize: bundle.map(named),
          },
        ];
      }),
      me: {
        rank: mine ? Number(mine.rank) : null,
        score: Number(myScore),
        prizeCoins: bundleCoins(myBundle),
        qualified: mine !== undefined && myScore >= minPoints,
        pointsToQualify: Number(myScore >= minPoints ? 0n : minPoints - myScore),
        prize: myBundle.map(named),
      },
    };
  }

  // ---------------------------------------------------------------------------------------------
  // The sweeper: freeze ended events, then pay prizes after the review window.

  /** One pass: every ended event not frozen yet, then every frozen event whose payout is due. */
  async sweep(): Promise<EventsSweepResult> {
    const now = this.clock.now();
    let frozen = 0;
    let paid = 0;
    const toFreeze = await this.prisma.event.findMany({
      where: { frozenAt: null, endsAt: { lte: now } },
      select: { id: true },
      orderBy: { endsAt: 'asc' },
      take: 50,
    });
    for (const { id } of toFreeze) if (await this.freeze(id, now)) frozen++;
    const toPay = await this.prisma.event.findMany({
      where: { frozenAt: { not: null }, paidAt: null, payoutHold: false, payoutDueAt: { lte: now } },
      select: { id: true },
      orderBy: { payoutDueAt: 'asc' },
      take: 50,
    });
    for (const { id } of toPay) if (await this.payout(id, now)) paid++;
    // D303 follow-up: event badges a day past their end leave the table (they stopped showing at the end).
    await this.prisma.userEventBadge.deleteMany({
      where: { expiresAt: { lt: new Date(now.getTime() - DAY_MS) } },
    });
    return { frozen, paid };
  }

  private async lockEvent(tx: Tx, id: string): Promise<Event | null> {
    const [row] = await tx.$queryRaw<
      { id: string }[]
    >`SELECT id::text AS id FROM events WHERE id = ${id}::uuid FOR UPDATE`;
    if (!row) return null;
    return tx.event.findUnique({ where: { id } });
  }

  /** Freezes the final top 100 of an ended event (once). */
  private async freeze(id: string, now: Date): Promise<boolean> {
    return this.prisma.$transaction(async (tx) => {
      const e = await this.lockEvent(tx, id);
      if (!e || e.frozenAt !== null || e.endsAt === null || e.endsAt > now) return false;
      // v1.97-social (D303): a gift event freezes each of its boards and is due at once (paid automatically).
      if (e.metric === 'EVENT_GIFTS') return freezeGiftEventIn(tx, e, now);
      const prizes = parseEventPrizes(e.prizes) ?? [];
      const ranked = rankedSql(e, e.endsAt);
      const rows = await tx.$queryRaw<RankRow[]>`
        SELECT * FROM (${ranked}) b ORDER BY b.rank LIMIT ${EVENT_LEADERBOARD_MAX}`;
      if (rows.length > 0) {
        await tx.eventResult.createMany({
          data: rows.map((r) => {
            const prizeCoins = prizeForRank(prizes, Number(r.rank));
            return {
              eventId: e.id,
              rank: Number(r.rank),
              userId: r.user_id,
              entrantKey: r.user_id,
              score: r.score,
              prizeCoins,
              prizeStatus: prizeCoins > 0 ? 'PENDING' : 'NONE',
              createdAt: now,
            };
          }),
        });
      }
      const anyPrize = rows.some((r) => prizeForRank(prizes, Number(r.rank)) > 0);
      await tx.event.update({
        where: { id: e.id },
        data: {
          frozenAt: now,
          payoutDueAt: new Date(now.getTime() + this.config.programs.eventPrizeReviewMs),
          // Nothing to pay: settled at once.
          ...(anyPrize ? {} : { paidAt: now }),
        },
      });
      return true;
    });
  }

  /** Pays every pending prize of a frozen event once (ACTIVE winners; the others forfeit). */
  private async payout(id: string, now: Date): Promise<boolean> {
    return this.prisma.$transaction(async (tx) => {
      const e = await this.lockEvent(tx, id);
      if (!e || e.frozenAt === null || e.paidAt !== null || e.payoutHold) return false;
      if (e.payoutDueAt === null || e.payoutDueAt > now) return false;
      if (e.metric === 'EVENT_GIFTS') {
        await payGiftEventIn(tx, e, now);
        return true;
      }
      const pending = await tx.$queryRaw<
        { id: string; user_id: string; prize_coins: number; active: boolean }[]
      >`
        SELECT r.id::text AS id, r.user_id::text AS user_id, r.prize_coins, (u.status = 'ACTIVE') AS active
          FROM event_results r JOIN users u ON u.id = r.user_id
         WHERE r.event_id = ${e.id}::uuid AND r.prize_status = 'PENDING'
         ORDER BY r.rank`;
      for (const r of pending) {
        if (r.active) {
          await creditIn(tx, r.user_id, BigInt(r.prize_coins), 'EVENT_PRIZE', r.id);
          await tx.eventResult.update({ where: { id: r.id }, data: { prizeStatus: 'PAID', paidAt: now } });
        } else {
          await tx.eventResult.update({ where: { id: r.id }, data: { prizeStatus: 'FORFEITED' } });
        }
      }
      await tx.event.update({ where: { id: e.id }, data: { paidAt: now } });
      return true;
    });
  }
}
