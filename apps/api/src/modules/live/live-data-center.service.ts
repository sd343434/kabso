import { Inject, Injectable, Logger, type OnModuleDestroy, type OnModuleInit } from '@nestjs/common';
import { z } from 'zod';
import { AppException } from '../../common/errors/app-exception.js';
import { Clock } from '../../common/time/clock.js';
import { zodErrorToDetails } from '../../common/validation/zod-validation.pipe.js';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import { Prisma } from '../../generated/prisma/client.js';
import { safeErrorLog } from '../../logging/redact-text.js';
import { PrismaService } from '../../prisma/prisma.service.js';

/** `LiveStatsPeriod`: today by hour, the last 7 or 30 days by day, the last 12 months by month. */
export const LIVE_STATS_PERIODS = ['DAY', 'WEEK', 'MONTH', 'YEAR'] as const;
export type LiveStatsPeriod = (typeof LIVE_STATS_PERIODS)[number];

/** Ended lives summarised per summariser batch. */
export const LIVE_SUMMARY_BATCH = 200;

/** `LiveStatsTotals`. */
export interface LiveStatsTotalsDto {
  lives: number;
  liveSeconds: number;
  giftCount: number;
  giftCoins: number;
  /** The host's share of the gifts they received (display only; payouts are D149). */
  earningsCoins: number;
  newFollowers: number;
  uniqueViewers: number;
  peakViewers: number;
}

/** `LiveStatsBucket`: one hour, day or month (local time, `LIVE_RANKINGS_TIME_ZONE`). */
export interface LiveStatsBucketDto {
  /** The bucket's start, local wall time `YYYY-MM-DDTHH:mm`. */
  start: string;
  liveSeconds: number;
  earningsCoins: number;
  newFollowers: number;
}

/** `LiveStatsHeatCell`: lives started on that weekday (1 Monday … 7 Sunday) and hour (0–23). */
export interface LiveStatsHeatCellDto {
  weekday: number;
  hour: number;
  lives: number;
  viewers: number;
}

/** `MyLiveStats` (v1.35-live, D154d, CONVENTIONS §10.36). */
export interface MyLiveStatsDto {
  period: LiveStatsPeriod;
  timeZone: string;
  /** The period: [from, to), as instants. */
  from: string;
  to: string;
  totals: LiveStatsTotalsDto;
  series: LiveStatsBucketDto[];
  heatmap: LiveStatsHeatCellDto[];
}

const querySchema = z.strictObject({ period: z.string().pipe(z.enum(LIVE_STATS_PERIODS)) });

/** The bucket unit and how far back each period starts (local time). */
const PERIOD_SHAPE: Readonly<Record<LiveStatsPeriod, { unit: 'hour' | 'day' | 'month'; back: string }>> = {
  DAY: { unit: 'hour', back: '0 days' },
  WEEK: { unit: 'day', back: '6 days' },
  MONTH: { unit: 'day', back: '29 days' },
  YEAR: { unit: 'month', back: '11 months' },
};

/**
 * The host's data center «مركز البيانات» (D154d, CONVENTIONS §10.36). Every ended live is summarised
 * once into `live_summaries` (the summariser runs on the live sweeper's interval and for the caller
 * before each read, so lives ended through any path — the host, the heartbeat timeout, a suspension,
 * an admin — and lives from before D154d are covered). `GET /live/stats/me?period=` aggregates the
 * caller's summaries of the period (by the live's start, in `LIVE_RANKINGS_TIME_ZONE`) with the
 * follows they received in it. The live running now counts once it ends.
 */
@Injectable()
export class LiveDataCenterService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(LiveDataCenterService.name);
  private timer: NodeJS.Timeout | undefined;

  constructor(
    private readonly prisma: PrismaService,
    private readonly clock: Clock,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
  ) {}

  onModuleInit(): void {
    const seconds = this.config.live.sweepIntervalSeconds;
    if (seconds > 0) {
      this.timer = setInterval(() => {
        this.summarise().catch((err: unknown) =>
          this.logger.warn({ error: safeErrorLog(err) }, 'Live summaries failed'),
        );
      }, seconds * 1000);
      this.timer.unref();
    }
  }

  onModuleDestroy(): void {
    if (this.timer) clearInterval(this.timer);
  }

  /**
   * Summarises up to `batch` ended lives that have no summary yet (of `hostId` only, when given);
   * idempotent (a live is summarised once). Returns how many were written.
   */
  async summarise(hostId?: string, batch = LIVE_SUMMARY_BATCH): Promise<number> {
    const onlyHost = hostId === undefined ? Prisma.sql`true` : Prisma.sql`r.host_user_id = ${hostId}::uuid`;
    return this.prisma.$executeRaw`
      INSERT INTO live_summaries (room_id, host_user_id, started_at, ended_at, duration_seconds, peak_viewers,
                                  unique_viewers, gift_count, gift_coins, earnings_coins, new_followers, created_at)
      SELECT r.id, r.host_user_id, r.started_at, r.ended_at,
             GREATEST(0, floor(extract(epoch FROM (r.ended_at - r.started_at))))::int,
             GREATEST(COALESCE(r.peak_viewer_count, 0), 0),
             (SELECT count(*) FROM live_room_audience a WHERE a.room_id = r.id)::int,
             COALESCE((SELECT sum(g.quantity) FROM live_gifts g WHERE g.room_id = r.id), 0)::int,
             COALESCE((SELECT sum(g.total_coins) FROM live_gifts g WHERE g.room_id = r.id), 0)::bigint,
             COALESCE((SELECT sum(floor(gr.coins * g.host_share_bps / 10000.0))
                         FROM live_gifts g
                         JOIN live_gift_recipients gr ON gr.gift_id = g.id AND gr.user_id = r.host_user_id
                        WHERE g.room_id = r.id), 0)::bigint,
             (SELECT count(*) FROM follows f JOIN users fu ON fu.id = f.follower_id AND fu.status = 'ACTIVE'
               WHERE f.followee_id = r.host_user_id AND f.created_at >= r.started_at
                 AND f.created_at <= r.ended_at)::int,
             now()
        FROM live_rooms r
       WHERE r.status = 'ENDED' AND r.ended_at IS NOT NULL AND ${onlyHost}
         AND NOT EXISTS (SELECT 1 FROM live_summaries s WHERE s.room_id = r.id)
       ORDER BY r.ended_at
       LIMIT ${batch}
      ON CONFLICT (room_id) DO NOTHING`;
  }

  /** `GET /live/stats/me?period=DAY|WEEK|MONTH|YEAR`: the caller's own data center. */
  async mine(callerId: string, query: unknown): Promise<MyLiveStatsDto> {
    const parsed = querySchema.safeParse(query ?? {}, { reportInput: true });
    if (!parsed.success) throw AppException.validation(zodErrorToDetails(parsed.error));
    const period = parsed.data.period;
    // The caller's lives that ended since the last summariser run count at once.
    while ((await this.summarise(callerId)) === LIVE_SUMMARY_BATCH) {
      // A host with a long history: keep going until every ended live has its summary.
    }
    const tz = this.config.live.rankingsTimeZone;
    const { unit, back } = PERIOD_SHAPE[period];
    const now = this.clock.now().toISOString();
    const [range] = await this.prisma.$queryRaw<{ from: Date; to: Date }[]>`
      SELECT (date_trunc(${unit}, ${now}::timestamptz AT TIME ZONE ${tz}) - ${back}::interval) AT TIME ZONE ${tz}
               AS "from",
             ${now}::timestamptz AS "to"`;
    const from = range!.from.toISOString();
    const to = range!.to.toISOString();
    const inPeriod = Prisma.sql`s.host_user_id = ${callerId}::uuid
      AND s.started_at >= ${from}::timestamptz AND s.started_at < ${to}::timestamptz`;
    const [totals, lives, follows, heat] = await Promise.all([
      this.prisma.$queryRaw<
        {
          lives: number;
          seconds: bigint;
          gifts: bigint;
          coins: bigint;
          earnings: bigint;
          unique: bigint;
          peak: number;
        }[]
      >`
        SELECT count(*)::int AS lives, COALESCE(sum(s.duration_seconds), 0)::bigint AS seconds,
               COALESCE(sum(s.gift_count), 0)::bigint AS gifts, COALESCE(sum(s.gift_coins), 0)::bigint AS coins,
               COALESCE(sum(s.earnings_coins), 0)::bigint AS earnings,
               COALESCE(sum(s.unique_viewers), 0)::bigint AS unique, COALESCE(max(s.peak_viewers), 0)::int AS peak
          FROM live_summaries s WHERE ${inPeriod}`,
      this.prisma.$queryRaw<{ bucket: string; seconds: bigint; earnings: bigint }[]>`
        SELECT to_char(date_trunc(${unit}, s.started_at AT TIME ZONE ${tz}), 'YYYY-MM-DD"T"HH24:MI') AS bucket,
               sum(s.duration_seconds)::bigint AS seconds, sum(s.earnings_coins)::bigint AS earnings
          FROM live_summaries s WHERE ${inPeriod}
         GROUP BY 1`,
      this.prisma.$queryRaw<{ bucket: string; followers: number }[]>`
        SELECT to_char(date_trunc(${unit}, f.created_at AT TIME ZONE ${tz}), 'YYYY-MM-DD"T"HH24:MI') AS bucket,
               count(*)::int AS followers
          FROM follows f JOIN users fu ON fu.id = f.follower_id AND fu.status = 'ACTIVE'
         WHERE f.followee_id = ${callerId}::uuid
           AND f.created_at >= ${from}::timestamptz AND f.created_at < ${to}::timestamptz
         GROUP BY 1`,
      this.prisma.$queryRaw<{ weekday: number; hour: number; lives: number; viewers: bigint }[]>`
        SELECT extract(isodow FROM s.started_at AT TIME ZONE ${tz})::int AS weekday,
               extract(hour FROM s.started_at AT TIME ZONE ${tz})::int AS hour,
               count(*)::int AS lives, sum(s.unique_viewers)::bigint AS viewers
          FROM live_summaries s WHERE ${inPeriod}
         GROUP BY 1, 2
         ORDER BY 1, 2`,
    ]);
    const buckets = await this.prisma.$queryRaw<{ bucket: string }[]>`
      SELECT to_char(b, 'YYYY-MM-DD"T"HH24:MI') AS bucket
        FROM generate_series(${from}::timestamptz AT TIME ZONE ${tz},
                             ${to}::timestamptz AT TIME ZONE ${tz},
                             ${`1 ${unit}`}::interval) AS b
       WHERE date_trunc(${unit}, b) = b`;
    const byLives = new Map(lives.map((l) => [l.bucket, l]));
    const byFollows = new Map(follows.map((f) => [f.bucket, f.followers]));
    const t = totals[0]!;
    return {
      period,
      timeZone: tz,
      from,
      to,
      totals: {
        lives: t.lives,
        liveSeconds: Number(t.seconds),
        giftCount: Number(t.gifts),
        giftCoins: Number(t.coins),
        earningsCoins: Number(t.earnings),
        newFollowers: follows.reduce((n, f) => n + f.followers, 0),
        uniqueViewers: Number(t.unique),
        peakViewers: t.peak,
      },
      series: buckets.map(({ bucket }) => ({
        start: bucket,
        liveSeconds: Number(byLives.get(bucket)?.seconds ?? 0n),
        earningsCoins: Number(byLives.get(bucket)?.earnings ?? 0n),
        newFollowers: byFollows.get(bucket) ?? 0,
      })),
      heatmap: heat.map((h) => ({
        weekday: h.weekday,
        hour: h.hour,
        lives: h.lives,
        viewers: Number(h.viewers),
      })),
    };
  }
}
