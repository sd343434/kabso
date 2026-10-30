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
import { creditIn } from '../wallet/wallet-ledger.js';
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
}

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
  /** When the leaderboard was frozen (after the end), the payout time, and when prizes were paid. */
  frozenAt: string | null;
  payoutDueAt: string | null;
  paidAt: string | null;
}

/** `EventLeaderboardEntry`. */
export interface EventLeaderboardEntryDto {
  rank: number;
  user: UserSummaryDto;
  score: number;
  prizeCoins: number;
}

/** `EventLeaderboard`. */
export interface EventLeaderboardDto {
  eventId: string;
  metric: EventMetric;
  /** True once the board is frozen (the final results). */
  final: boolean;
  data: EventLeaderboardEntryDto[];
  /** The caller's own place: rank null when not on the board. */
  me: { rank: number | null; score: number; prizeCoins: number };
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
       AND (${!hostsOnly} OR EXISTS (SELECT 1 FROM live_hosts h WHERE h.user_id = s.user_id))
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
    return {
      ...this.summary(e, this.clock.now(), lang),
      rules: lang === 'ar' ? e.rulesAr : e.rulesEn,
      prizes: parseEventPrizes(e.prizes) ?? [],
      frozenAt: e.frozenAt?.toISOString() ?? null,
      payoutDueAt: e.payoutDueAt?.toISOString() ?? null,
      paidAt: e.paidAt?.toISOString() ?? null,
    };
  }

  /**
   * `GET /events/{eventId}/leaderboard`: the top 100 (live until the event is frozen, then the final
   * results) and the caller's own place. People the caller blocked or who blocked the caller are left
   * out of the list (their ranks stay, so the ranks match the prizes).
   */
  async leaderboard(me: string, eventId: string): Promise<EventLeaderboardDto> {
    const e = await this.eventOr404(eventId);
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
