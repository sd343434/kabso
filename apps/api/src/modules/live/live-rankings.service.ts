import { Inject, Injectable } from '@nestjs/common';
import { Prisma } from '../../generated/prisma/client.js';
import { z } from 'zod';
import { AppException } from '../../common/errors/app-exception.js';
import { Clock } from '../../common/time/clock.js';
import { zodErrorToDetails } from '../../common/validation/zod-validation.pipe.js';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import type { UserSummaryDto } from './live-rooms.service.js';
import { GAME_SPEND_HOURLY_RETENTION_MS, MONTHLY_RETENTION_MS } from './game-ticket-spends.js';

/**
 * The boards' periods (CP-016 A, CONVENTIONS §10.15). v1.87-live (D314, §10.119): and MONTH «هذا الشهر», YEAR «هذه
 * السنة» — local calendar months and years in LIVE_RANKINGS_TIME_ZONE, like the day and the week.
 */
export const LIVE_RANKING_PERIODS = ['HOUR', 'DAY', 'WEEK', 'MONTH', 'YEAR'] as const;
export type LiveRankingPeriod = (typeof LIVE_RANKING_PERIODS)[number];

/** At most this many hosts on a board. */
export const LIVE_RANKING_MAX = 50;
/** Hourly rows older than this are removed by the sweeper (a week plus margin). */
export const LIVE_RANKING_RETENTION_MS = 15 * 24 * 3600_000;

/**
 * v1.88-live (D315, §10.120): which board — POPULARITY «ترتيب الشعبية» (hosts by points, CP-016 A) or GAMES «مجنون
 * اللعب» (players by game tickets spent).
 */
export const LIVE_RANKING_BOARDS = ['POPULARITY', 'GAMES', 'RICH'] as const;
/** v1.90-live (D320, §10.124, owner): «الأغنى» lists the top 20 (the other boards 50). */
export const LIVE_RICH_MAX = 20;
export type LiveRankingBoard = (typeof LIVE_RANKING_BOARDS)[number];

export const liveRankingsQuerySchema = z.strictObject({
  period: z.enum(LIVE_RANKING_PERIODS).default('HOUR'),
  board: z.enum(LIVE_RANKING_BOARDS).default('POPULARITY'),
});

/** `LiveRankingEntry`. */
export interface LiveRankingEntryDto {
  rank: number;
  host: UserSummaryDto;
  points: number;
  /** The host's live now, if any (cards show LIVE and open it). */
  liveRoom: { id: string; title: string; coverUrl: string | null } | null;
}

/** `LiveRankings`. */
export interface LiveRankingsDto {
  /** v1.88-live (D315): the board (POPULARITY: `host` / `points`; GAMES: the player / tickets spent). */
  board: LiveRankingBoard;
  period: LiveRankingPeriod;
  startsAt: string;
  endsAt: string;
  data: LiveRankingEntryDto[];
  /** The caller's own row (a host); rank null with 0 points. Absent for guests and non-hosts. */
  me?: { rank: number | null; points: number };
}

const INTERVAL: Readonly<Record<LiveRankingPeriod, string>> = {
  HOUR: 'hour',
  DAY: 'day',
  WEEK: 'week',
  MONTH: 'month',
  YEAR: 'year',
};

/**
 * Where a board's amounts are read: HOUR / DAY / WEEK sum the hourly rows (kept 15 days); MONTH / YEAR the local-month
 * rollups (D314: at most 12 rows per person for a year, never the hourly rows).
 */
const SOURCES: Readonly<
  Record<LiveRankingBoard, { hourly: Prisma.Sql; monthly: Prisma.Sql; who: Prisma.Sql; amount: Prisma.Sql }>
> = {
  POPULARITY: {
    hourly: Prisma.sql`live_host_points_hourly`,
    monthly: Prisma.sql`live_host_points_monthly`,
    who: Prisma.sql`host_user_id`,
    amount: Prisma.sql`points`,
  },
  GAMES: {
    hourly: Prisma.sql`game_ticket_spends_hourly`,
    monthly: Prisma.sql`game_ticket_spends_monthly`,
    who: Prisma.sql`user_id`,
    amount: Prisma.sql`tickets`,
  },
  // v1.90-live (D320, §10.124): «الأغنى» — the coin value of the gifts each user sent.
  RICH: {
    hourly: Prisma.sql`gift_coins_sent_hourly`,
    monthly: Prisma.sql`gift_coins_sent_monthly`,
    who: Prisma.sql`user_id`,
    amount: Prisma.sql`coins`,
  },
};

/**
 * The popularity boards (CP-016 A, D99): hosts ranked by the points their lives received in the
 * current hour, day or week — one region for everyone (owner D99). Points come from
 * `live_host_points_hourly`, written with the taps that counted. Day and week start at midnight
 * and on Monday in LIVE_RANKINGS_TIME_ZONE. v1.87-live (D314): month and year (the 1st and 1 January at midnight in
 * that zone) read `live_host_points_monthly`. v1.88-live (D315): the GAMES board «مجنون اللعب» ranks players by the game
 * tickets they spent, from the same kind of rollups (`game_ticket_spends_hourly` / `_monthly`). v1.90-live (D320): the
 * RICH board «الأغنى» ranks users by the coin value of the gifts they sent (`gift_coins_sent_hourly` / `_monthly`), top 20.
 */
@Injectable()
export class LiveRankingsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly clock: Clock,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
  ) {}

  /** The current window of [period] (UTC instants). */
  private async window(period: LiveRankingPeriod, now: Date): Promise<{ start: Date; end: Date }> {
    const unit = INTERVAL[period];
    const tz = this.config.live.rankingsTimeZone;
    const [w] = await this.prisma.$queryRaw<{ start: Date; end: Date }[]>`
      SELECT (date_trunc(${unit}::text, ${now}::timestamptz AT TIME ZONE ${tz}::text)
                AT TIME ZONE ${tz}::text) AS start,
             ((date_trunc(${unit}::text, ${now}::timestamptz AT TIME ZONE ${tz}::text)
                + ${'1 ' + unit}::interval) AT TIME ZONE ${tz}::text) AS "end"`;
    return { start: w!.start, end: w!.end };
  }

  /**
   * `GET /live/rankings?period=HOUR|DAY|WEEK`: the top 50 hosts by points in the window, highest
   * first (ties by user id). Only ACTIVE hosts with points; a signed-in reader never sees people
   * they blocked or who blocked them. `me` is the caller's exact rank among all hosts.
   */
  async list(callerId: string | null, query: unknown): Promise<LiveRankingsDto> {
    const parsed = liveRankingsQuerySchema.safeParse(query ?? {});
    if (!parsed.success) throw AppException.validation(zodErrorToDetails(parsed.error));
    const { period, board } = parsed.data;
    const now = this.clock.now();
    const { start, end } = await this.window(period, now);
    const src = SOURCES[board];
    const monthly = period === 'MONTH' || period === 'YEAR';
    // The person's amount in the window, one row each (only positive ones are listed).
    const totals = monthly
      ? Prisma.sql`SELECT ${src.who} AS who, SUM(${src.amount}) AS amount FROM ${src.monthly}
                    WHERE month_start >= ${start}::timestamptz AND month_start < ${end}::timestamptz
                    GROUP BY ${src.who}`
      : Prisma.sql`SELECT ${src.who} AS who, SUM(${src.amount}) AS amount FROM ${src.hourly}
                    WHERE hour_start >= ${start}::timestamptz AND hour_start < ${end}::timestamptz
                    GROUP BY ${src.who}`;

    const rows = await this.prisma.$queryRaw<
      {
        host_user_id: string;
        points: bigint;
        username: string;
        display_name: string;
        avatar_url: string | null;
        room_id: string | null;
        room_title: string | null;
        cover_url: string | null;
      }[]
    >`
      WITH w AS (
        SELECT t.who AS host_user_id, t.amount AS points FROM (${totals}) t WHERE t.amount > 0)
      SELECT w.host_user_id::text AS host_user_id, w.points, p.username, p.display_name,
             p.avatar_url, r.id::text AS room_id, r.title AS room_title, r.cover_url
        FROM w
        JOIN users u ON u.id = w.host_user_id AND u.status = 'ACTIVE'
        JOIN user_profiles p ON p.user_id = w.host_user_id
        LEFT JOIN live_rooms r ON r.host_user_id = w.host_user_id AND r.status = 'LIVE'
       WHERE ${callerId}::uuid IS NULL OR NOT EXISTS (
               SELECT 1 FROM user_blocks b
                WHERE (b.blocker_id = ${callerId}::uuid AND b.blocked_id = w.host_user_id)
                   OR (b.blocker_id = w.host_user_id AND b.blocked_id = ${callerId}::uuid))
       ORDER BY w.points DESC, w.host_user_id
       LIMIT ${board === 'RICH' ? LIVE_RICH_MAX : LIVE_RANKING_MAX}`;

    const result: LiveRankingsDto = {
      board,
      period,
      startsAt: start.toISOString(),
      endsAt: end.toISOString(),
      data: rows.map((r, i) => ({
        rank: i + 1,
        host: {
          id: r.host_user_id,
          username: r.username,
          displayName: r.display_name,
          avatarUrl: r.avatar_url,
        },
        points: Number(r.points),
        liveRoom: r.room_id ? { id: r.room_id, title: r.room_title ?? '', coverUrl: r.cover_url } : null,
      })),
    };
    // `me`: a host on the popularity board; any signed-in caller on the GAMES (D315) and RICH (D320) boards.
    const ranked =
      callerId !== null &&
      (board !== 'POPULARITY' || (await this.prisma.liveHost.count({ where: { userId: callerId } })) > 0);
    if (ranked) {
      const [me] = await this.prisma.$queryRaw<{ points: bigint | null; ahead: bigint }[]>`
        WITH w AS (
          SELECT t.who AS host_user_id, t.amount AS points
            FROM (${totals}) t JOIN users u ON u.id = t.who AND u.status = 'ACTIVE')
        SELECT (SELECT points FROM w WHERE host_user_id = ${callerId}::uuid) AS points,
               (SELECT count(*) FROM w
                 WHERE points > COALESCE((SELECT points FROM w WHERE host_user_id = ${callerId}::uuid), 0)
                    OR (points = (SELECT points FROM w WHERE host_user_id = ${callerId}::uuid)
                        AND host_user_id < ${callerId}::uuid)) AS ahead`;
      const points = Number(me?.points ?? 0);
      result.me = { rank: points > 0 ? Number(me!.ahead) + 1 : null, points };
    }
    return result;
  }

  /**
   * Removes hourly rows older than 15 days and (D314 / D315) monthly rows older than 400 days — a year board needs at
   * most the last 12 months (bounded; runs after each stale-room sweep).
   */
  async sweepRetention(now: Date = this.clock.now()): Promise<number> {
    const cutoff = new Date(now.getTime() - LIVE_RANKING_RETENTION_MS);
    const gameCutoff = new Date(now.getTime() - GAME_SPEND_HOURLY_RETENTION_MS);
    const monthCutoff = new Date(now.getTime() - MONTHLY_RETENTION_MS);
    const counts = await Promise.all([
      this.prisma.$executeRaw`
        DELETE FROM live_host_points_hourly
         WHERE (host_user_id, hour_start) IN (
           SELECT host_user_id, hour_start FROM live_host_points_hourly
            WHERE hour_start < ${cutoff}::timestamptz
            LIMIT 5000)`,
      this.prisma.$executeRaw`
        DELETE FROM live_host_points_monthly
         WHERE (host_user_id, month_start) IN (
           SELECT host_user_id, month_start FROM live_host_points_monthly
            WHERE month_start < ${monthCutoff}::timestamptz
            LIMIT 5000)`,
      this.prisma.$executeRaw`
        DELETE FROM game_ticket_spends_hourly
         WHERE (user_id, hour_start) IN (
           SELECT user_id, hour_start FROM game_ticket_spends_hourly
            WHERE hour_start < ${gameCutoff}::timestamptz
            LIMIT 5000)`,
      this.prisma.$executeRaw`
        DELETE FROM gift_coins_sent_hourly
         WHERE (user_id, hour_start) IN (
           SELECT user_id, hour_start FROM gift_coins_sent_hourly
            WHERE hour_start < ${cutoff}::timestamptz
            LIMIT 5000)`,
      this.prisma.$executeRaw`
        DELETE FROM gift_coins_sent_monthly
         WHERE (user_id, month_start) IN (
           SELECT user_id, month_start FROM gift_coins_sent_monthly
            WHERE month_start < ${monthCutoff}::timestamptz
            LIMIT 5000)`,
      this.prisma.$executeRaw`
        DELETE FROM game_ticket_spends_monthly
         WHERE (user_id, month_start) IN (
           SELECT user_id, month_start FROM game_ticket_spends_monthly
            WHERE month_start < ${monthCutoff}::timestamptz
            LIMIT 5000)`,
    ]);
    return counts.reduce((a, b) => a + b, 0);
  }
}
