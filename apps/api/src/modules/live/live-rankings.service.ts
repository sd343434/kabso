import { Inject, Injectable } from '@nestjs/common';
import { z } from 'zod';
import { AppException } from '../../common/errors/app-exception.js';
import { Clock } from '../../common/time/clock.js';
import { zodErrorToDetails } from '../../common/validation/zod-validation.pipe.js';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import type { UserSummaryDto } from './live-rooms.service.js';

/** The boards' periods (CP-016 A, CONVENTIONS §10.15). */
export const LIVE_RANKING_PERIODS = ['HOUR', 'DAY', 'WEEK'] as const;
export type LiveRankingPeriod = (typeof LIVE_RANKING_PERIODS)[number];

/** At most this many hosts on a board. */
export const LIVE_RANKING_MAX = 50;
/** Hourly rows older than this are removed by the sweeper (a week plus margin). */
export const LIVE_RANKING_RETENTION_MS = 15 * 24 * 3600_000;

export const liveRankingsQuerySchema = z.strictObject({
  period: z.enum(LIVE_RANKING_PERIODS).default('HOUR'),
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
  period: LiveRankingPeriod;
  startsAt: string;
  endsAt: string;
  data: LiveRankingEntryDto[];
  /** The caller's own row (a host); rank null with 0 points. Absent for guests and non-hosts. */
  me?: { rank: number | null; points: number };
}

const INTERVAL: Readonly<Record<LiveRankingPeriod, string>> = { HOUR: 'hour', DAY: 'day', WEEK: 'week' };

/**
 * The popularity boards (CP-016 A, D99): hosts ranked by the points their lives received in the
 * current hour, day or week — one region for everyone (owner D99). Points come from
 * `live_host_points_hourly`, written with the taps that counted. Day and week start at midnight
 * and on Monday in LIVE_RANKINGS_TIME_ZONE.
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
    const { period } = parsed.data;
    const now = this.clock.now();
    const { start, end } = await this.window(period, now);

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
        SELECT host_user_id, SUM(points) AS points
          FROM live_host_points_hourly
         WHERE hour_start >= ${start}::timestamptz AND hour_start < ${end}::timestamptz
         GROUP BY host_user_id
        HAVING SUM(points) > 0)
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
       LIMIT ${LIVE_RANKING_MAX}`;

    const result: LiveRankingsDto = {
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
    if (callerId !== null && (await this.prisma.liveHost.count({ where: { userId: callerId } })) > 0) {
      const [me] = await this.prisma.$queryRaw<{ points: bigint | null; ahead: bigint }[]>`
        WITH w AS (
          SELECT h.host_user_id, SUM(h.points) AS points
            FROM live_host_points_hourly h JOIN users u ON u.id = h.host_user_id AND u.status = 'ACTIVE'
           WHERE h.hour_start >= ${start}::timestamptz AND h.hour_start < ${end}::timestamptz
           GROUP BY h.host_user_id)
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

  /** Removes hourly rows older than 15 days (bounded; runs after each stale-room sweep). */
  async sweepRetention(now: Date = this.clock.now()): Promise<number> {
    const cutoff = new Date(now.getTime() - LIVE_RANKING_RETENTION_MS);
    return this.prisma.$executeRaw`
      DELETE FROM live_host_points_hourly
       WHERE (host_user_id, hour_start) IN (
         SELECT host_user_id, hour_start FROM live_host_points_hourly
          WHERE hour_start < ${cutoff}::timestamptz
          LIMIT 5000)`;
  }
}
