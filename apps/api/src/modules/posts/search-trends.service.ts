import { createHmac, hkdfSync } from 'node:crypto';
import { Inject, Injectable, Logger, type OnModuleDestroy, type OnModuleInit } from '@nestjs/common';
import type { Redis } from 'ioredis';
import { Clock } from '../../common/time/clock.js';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import { safeErrorLog } from '../../logging/redact-text.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { REDIS } from '../../redis/redis.module.js';
import { visiblePostSql } from './post-views.js';
import type { HashtagDto } from './search.service.js';
import {
  containsBlockedWord,
  hourOf,
  normalizeSearchTerm,
  SEARCH_TREND_RETENTION_DAYS,
  SEARCHER_DEDUPE_DAYS,
  TRENDING_SEARCH_COUNT,
  trendingTag,
  type TrendingTag,
} from './search-trends.js';

/** `TrendingSearch` (openapi v1.29-live). */
export interface TrendingSearchDto {
  term: string;
  tag: TrendingTag | null;
}

const HOUR = 3600_000;
/** The global list is cached this long (it is the same for everyone). */
const TRENDING_CACHE_SECONDS = 60;
const TRENDING_CACHE_KEY = 'search:trending:v1';
/** Ranked candidates read before the blocked-word filter. */
const TRENDING_CANDIDATES = 60;
/** Trending hashtags: posts of the last 7 days, at least 3 posts by at least 2 authors. */
const TAG_WINDOW_DAYS = 7;
const TAG_MIN_POSTS = 3;
const TAG_MIN_AUTHORS = 2;
/** Sweeper batch (rows per DELETE). */
const SWEEP_BATCH = 5000;

/**
 * Search trends (v1.29-live, D147, CONVENTIONS §11.11): counts submitted searches without storing
 * who searched (each person counts once per term per 7 days, deduplicated by an HMAC key in Redis
 * that expires), lists the top terms people search (`GET /search/trending`) and the hashtags of the
 * week (`GET /search/trending-hashtags`). Owns `search_terms`, `search_term_counts` and
 * `search_blocked_words`.
 */
@Injectable()
export class SearchTrendsService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(SearchTrendsService.name);
  private readonly dedupeKey: Buffer;
  private sweepTimer: NodeJS.Timeout | undefined;
  private sweepInFlight: Promise<void> | null = null;

  constructor(
    private readonly prisma: PrismaService,
    private readonly clock: Clock,
    @Inject(REDIS) private readonly redis: Redis,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
  ) {
    this.dedupeKey = Buffer.from(
      hkdfSync('sha256', config.rateLimitKeySecret, 'kabso', 'search-searcher/v1', 32),
    );
  }

  onModuleInit(): void {
    if (this.config.searchTrends.sweepIntervalSeconds > 0) this.scheduleSweep();
  }

  async onModuleDestroy(): Promise<void> {
    if (this.sweepTimer) clearTimeout(this.sweepTimer);
    await this.sweepInFlight?.catch(() => undefined);
  }

  /**
   * `POST /search/queries`: counts [raw] once for [userId] per 7 days. Terms that are not counted
   * (too short, numbers, emails, links) are accepted and dropped. Only the term and an hourly count
   * are stored; the dedupe key is an HMAC of the user and the term that expires in Redis.
   */
  async record(userId: string, raw: string): Promise<void> {
    const term = normalizeSearchTerm(raw);
    if (term === null) return;
    const digest = createHmac('sha256', this.dedupeKey).update(`${userId}\u0000${term}`).digest('base64url');
    const key = `search:seen:${digest}`;
    const fresh = await this.redis.set(key, '1', 'EX', SEARCHER_DEDUPE_DAYS * 86400, 'NX');
    if (fresh !== 'OK') return;
    const now = this.clock.now();
    try {
      await this.prisma.$executeRaw`
        WITH t AS (
          INSERT INTO search_terms (id, term, first_seen_at)
          VALUES (gen_random_uuid(), ${term}, ${now})
          ON CONFLICT (term) DO UPDATE SET term = EXCLUDED.term
          RETURNING id)
        INSERT INTO search_term_counts (term_id, hour, searchers)
        SELECT id, ${hourOf(now)}, 1 FROM t
        ON CONFLICT (term_id, hour) DO UPDATE SET searchers = search_term_counts.searchers + 1`;
    } catch (err) {
      // Not counted: let the person count on a later search.
      await this.redis.del(key).catch(() => undefined);
      throw err;
    }
  }

  private async blockedWords(): Promise<string[]> {
    const rows = await this.prisma.searchBlockedWord.findMany({ select: { word: true } });
    return rows.map((r) => r.word);
  }

  /**
   * `GET /search/trending`: up to 6 terms searched by at least `SEARCH_TRENDING_MIN_SEARCHERS`
   * people in the last 7 days, most searchers first (then the last 24 h, then the term); never a
   * hidden term or one with a blocked word. The same list for everyone, cached 60 s.
   */
  async trending(): Promise<{ data: TrendingSearchDto[] }> {
    const cached = await this.redis.get(TRENDING_CACHE_KEY);
    if (cached !== null) return { data: JSON.parse(cached) as TrendingSearchDto[] };
    const data = await this.computeTrending(this.clock.now());
    await this.redis.set(TRENDING_CACHE_KEY, JSON.stringify(data), 'EX', TRENDING_CACHE_SECONDS);
    return { data };
  }

  /** Drops the cached list (the admin CLI's changes and tests). */
  async invalidate(): Promise<void> {
    await this.redis.del(TRENDING_CACHE_KEY);
  }

  async computeTrending(now: Date): Promise<TrendingSearchDto[]> {
    const h0 = hourOf(now).getTime();
    const weekFrom = new Date(h0 - (7 * 24 - 1) * HOUR);
    const dayFrom = new Date(h0 - 23 * HOUR);
    const prevFrom = new Date(h0 - 47 * HOUR);
    const rows = await this.prisma.$queryRaw<
      { term: string; first_seen_at: Date; week: number; day: number; prev: number }[]
    >`
      SELECT t.term, t.first_seen_at,
             sum(c.searchers)::int AS week,
             COALESCE(sum(c.searchers) FILTER (WHERE c.hour >= ${dayFrom}), 0)::int AS day,
             COALESCE(sum(c.searchers) FILTER (WHERE c.hour >= ${prevFrom} AND c.hour < ${dayFrom}), 0)::int AS prev
        FROM search_terms t
        JOIN search_term_counts c ON c.term_id = t.id
       WHERE t.hidden_at IS NULL AND c.hour >= ${weekFrom} AND c.hour <= ${new Date(h0)}
       GROUP BY t.id, t.term, t.first_seen_at
      HAVING sum(c.searchers) >= ${this.config.searchTrends.minSearchers}
       ORDER BY week DESC, day DESC, t.term ASC
       LIMIT ${TRENDING_CANDIDATES}`;
    const blocked = await this.blockedWords();
    return rows
      .filter((r) => !containsBlockedWord(r.term, blocked))
      .slice(0, TRENDING_SEARCH_COUNT)
      .map((r) => ({
        term: r.term,
        tag: trendingTag({ firstSeenAt: r.first_seen_at, day: r.day, previousDay: r.prev }, now),
      }));
  }

  /**
   * `GET /search/trending-hashtags`: hashtags of posts published in the last 7 days that
   * [viewerId] can see, at least 3 posts by at least 2 authors, most posts first (then the newest
   * post, then the tag); never a tag with a blocked word. `postCount` counts those 7 days only.
   */
  async trendingHashtags(viewerId: string, limit: number): Promise<{ data: HashtagDto[] }> {
    const from = new Date(this.clock.now().getTime() - TAG_WINDOW_DAYS * 24 * HOUR);
    const rows = await this.prisma.$queryRaw<{ tag: string; n: number }[]>`
      SELECT h.tag, count(DISTINCT p.id)::int AS n
        FROM post_hashtags ph
        JOIN hashtags h ON h.id = ph.hashtag_id
        JOIN posts p ON p.id = ph.post_id
        JOIN users a ON a.id = p.author_id
        LEFT JOIN user_settings s ON s.user_id = a.id
       WHERE p.published_at >= ${from}
         AND ${visiblePostSql(viewerId, { excludeMuted: false, excludeHidden: true })}
       GROUP BY h.tag
      HAVING count(DISTINCT p.id) >= ${TAG_MIN_POSTS} AND count(DISTINCT p.author_id) >= ${TAG_MIN_AUTHORS}
       ORDER BY n DESC, max(p.published_at) DESC, h.tag ASC
       LIMIT ${limit + TRENDING_CANDIDATES}`;
    const blocked = await this.blockedWords();
    return {
      data: rows
        .filter((r) => !containsBlockedWord(r.tag, blocked))
        .slice(0, limit)
        .map((r) => ({ tag: r.tag, postCount: r.n })),
    };
  }

  /**
   * Retention: counts older than 14 days, then terms that are not hidden and have no counts left
   * (first seen 14+ days ago), in bounded batches.
   */
  async sweep(now: Date = this.clock.now()): Promise<{ counts: number; terms: number }> {
    const before = new Date(now.getTime() - SEARCH_TREND_RETENTION_DAYS * 24 * HOUR);
    let counts = 0;
    for (;;) {
      const n = await this.prisma.$executeRaw`
        DELETE FROM search_term_counts
         WHERE (term_id, hour) IN (SELECT term_id, hour FROM search_term_counts
                                    WHERE hour < ${before} LIMIT ${SWEEP_BATCH})`;
      counts += n;
      if (n < SWEEP_BATCH) break;
    }
    let terms = 0;
    for (;;) {
      const n = await this.prisma.$executeRaw`
        DELETE FROM search_terms
         WHERE id IN (SELECT t.id FROM search_terms t
                       WHERE t.hidden_at IS NULL AND t.first_seen_at < ${before}
                         AND NOT EXISTS (SELECT 1 FROM search_term_counts c WHERE c.term_id = t.id)
                       LIMIT ${SWEEP_BATCH})`;
      terms += n;
      if (n < SWEEP_BATCH) break;
    }
    return { counts, terms };
  }

  private scheduleSweep(): void {
    this.sweepTimer = setTimeout(() => {
      this.sweepInFlight = this.sweep()
        .then(() => undefined)
        .catch((err: unknown) => {
          this.logger.error({ error: safeErrorLog(err) }, 'Search trends sweep failed');
        })
        .finally(() => {
          this.sweepInFlight = null;
          this.scheduleSweep();
        });
    }, this.config.searchTrends.sweepIntervalSeconds * 1000);
    this.sweepTimer.unref();
  }
}
