import { Inject, Injectable } from '@nestjs/common';
import { z } from 'zod';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import { AppException } from '../../common/errors/app-exception.js';
import { Clock } from '../../common/time/clock.js';
import { zodErrorToDetails } from '../../common/validation/zod-validation.pipe.js';
import { Prisma } from '../../generated/prisma/client.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { familyWindow } from '../families/family-views.js';
import { LiveDataCenterService } from '../live/live-data-center.service.js';

/** v1.49-social (D172) adds `THIS_MONTH`: the current calendar month so far (region's zone). */
export const CREATOR_STATS_PERIODS = ['LAST_7_DAYS', 'LAST_30_DAYS', 'ALL_TIME', 'THIS_MONTH'] as const;
export type CreatorStatsPeriod = (typeof CREATOR_STATS_PERIODS)[number];

const PERIOD_DAYS: Record<Exclude<CreatorStatsPeriod, 'THIS_MONTH'>, number | null> = {
  LAST_7_DAYS: 7,
  LAST_30_DAYS: 30,
  ALL_TIME: null,
};
const DAY_MS = 86_400_000;

const querySchema = z.strictObject({ period: z.string().pipe(z.enum(CREATOR_STATS_PERIODS)) });

/** `CreatorContentStats` (openapi v1.43-social, D164). */
export interface CreatorContentStatsDto {
  published: number;
  views: number;
  likes: number;
  comments: number;
  shares: number;
}

/** `CreatorStats` (openapi v1.43-social, D164, CONVENTIONS §10.40). */
export interface CreatorStatsDto {
  period: CreatorStatsPeriod;
  from: string | null;
  to: string;
  /** v1.49-social (D172): `YYYY-MM` of `THIS_MONTH` in the region's zone; null otherwise. */
  month: string | null;
  followers: { total: number; newInPeriod: number | null };
  posts: CreatorContentStatsDto;
  reels: CreatorContentStatsDto;
  live: {
    lives: number;
    liveSeconds: number;
    giftCount: number;
    giftCoins: number;
    earningsCoins: number;
    newFollowers: number;
    peakViewers: number;
  };
}

/** `YYYY-MM` of [at] in [timeZone]. */
export function monthIn(at: Date, timeZone: string): string {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone,
    year: 'numeric',
    month: '2-digit',
  }).formatToParts(at);
  const get = (type: 'year' | 'month') => parts.find((p) => p.type === type)!.value;
  return `${get('year')}-${get('month')}`;
}

const EMPTY_CONTENT: CreatorContentStatsDto = { published: 0, views: 0, likes: 0, comments: 0, shares: 0 };

/**
 * The creator center «مركز صنّاع المحتوى» (v1.43-social, D164, CONVENTIONS §10.40): the caller's own
 * followers, posts, reels and lives over a rolling window, from stored data only — the follows, the
 * posts' counters and the data center's live summaries (§10.36). Nothing is estimated.
 */
@Injectable()
export class CreatorStatsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly clock: Clock,
    private readonly dataCenter: LiveDataCenterService,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
  ) {}

  /** `GET /me/creator-stats?period=LAST_7_DAYS|LAST_30_DAYS|ALL_TIME|THIS_MONTH`. */
  async mine(me: string, query: unknown): Promise<CreatorStatsDto> {
    const parsed = querySchema.safeParse(query ?? {}, { reportInput: true });
    if (!parsed.success) throw AppException.validation(zodErrorToDetails(parsed.error));
    const period = parsed.data.period;
    const now = this.clock.now();
    let from: Date | null;
    let month: string | null = null;
    if (period === 'THIS_MONTH') {
      // The 1st at 00:00 in the region's zone (the families' month, §10.21) until now.
      const tz = this.config.live.rankingsTimeZone;
      from = (await familyWindow(this.prisma, 'month', tz, now)).start;
      month = monthIn(now, tz);
    } else {
      const days = PERIOD_DAYS[period];
      from = days === null ? null : new Date(now.getTime() - days * DAY_MS);
    }
    const fromText = from?.toISOString() ?? null;
    // The caller's lives that ended since the summariser last ran count at once.
    await this.dataCenter.summariseHost(me);

    const since = (column: Prisma.Sql) =>
      fromText === null ? Prisma.sql`true` : Prisma.sql`${column} >= ${fromText}::timestamptz`;
    const [followers, content, live] = await Promise.all([
      this.prisma.$queryRaw<{ total: number; recent: number }[]>`
        SELECT count(*)::int AS total, (count(*) FILTER (WHERE ${since(Prisma.sql`f.created_at`)}))::int AS recent
          FROM follows f
          JOIN users u ON u.id = f.follower_id AND u.status = 'ACTIVE'
         WHERE f.followee_id = ${me}::uuid`,
      this.prisma.$queryRaw<
        {
          format: 'POST' | 'REEL';
          published: number;
          views: bigint;
          likes: bigint;
          comments: bigint;
          shares: bigint;
        }[]
      >`
        SELECT p.format::text AS format, count(*)::int AS published,
               COALESCE(sum(p.view_count), 0)::bigint AS views, COALESCE(sum(p.like_count), 0)::bigint AS likes,
               COALESCE(sum(p.comment_count), 0)::bigint AS comments,
               COALESCE(sum(p.share_count), 0)::bigint AS shares
          FROM posts p
         WHERE p.author_id = ${me}::uuid AND p.status = 'PUBLISHED' AND p.deleted_at IS NULL
           AND p.moderation <> 'REMOVED' AND p.published_at IS NOT NULL
           AND ${since(Prisma.sql`p.published_at`)}
         GROUP BY p.format`,
      this.prisma.$queryRaw<
        {
          lives: number;
          seconds: bigint;
          gifts: bigint;
          gift_coins: bigint;
          earnings: bigint;
          followers: bigint;
          peak: number;
        }[]
      >`
        SELECT count(*)::int AS lives, COALESCE(sum(s.duration_seconds), 0)::bigint AS seconds,
               COALESCE(sum(s.gift_count), 0)::bigint AS gifts, COALESCE(sum(s.gift_coins), 0)::bigint AS gift_coins,
               COALESCE(sum(s.earnings_coins), 0)::bigint AS earnings,
               COALESCE(sum(s.new_followers), 0)::bigint AS followers,
               COALESCE(max(s.peak_viewers), 0)::int AS peak
          FROM live_summaries s
         WHERE s.host_user_id = ${me}::uuid AND ${since(Prisma.sql`s.started_at`)}`,
    ]);

    const byFormat = new Map(content.map((c) => [c.format, c]));
    const contentDto = (format: 'POST' | 'REEL'): CreatorContentStatsDto => {
      const c = byFormat.get(format);
      return c
        ? {
            published: c.published,
            views: Number(c.views),
            likes: Number(c.likes),
            comments: Number(c.comments),
            shares: Number(c.shares),
          }
        : { ...EMPTY_CONTENT };
    };
    const f = followers[0];
    const l = live[0];
    return {
      period,
      from: fromText,
      to: now.toISOString(),
      month,
      followers: { total: f?.total ?? 0, newInPeriod: from === null ? null : (f?.recent ?? 0) },
      posts: contentDto('POST'),
      reels: contentDto('REEL'),
      live: {
        lives: l?.lives ?? 0,
        liveSeconds: Number(l?.seconds ?? 0n),
        giftCount: Number(l?.gifts ?? 0n),
        giftCoins: Number(l?.gift_coins ?? 0n),
        earningsCoins: Number(l?.earnings ?? 0n),
        newFollowers: Number(l?.followers ?? 0n),
        peakViewers: l?.peak ?? 0,
      },
    };
  }
}
