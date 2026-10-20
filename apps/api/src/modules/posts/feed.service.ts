import { randomUUID } from 'node:crypto';
import { Inject, Injectable } from '@nestjs/common';
import type { Redis } from 'ioredis';
import { AppException } from '../../common/errors/app-exception.js';
import { Prisma } from '../../generated/prisma/client.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { REDIS } from '../../redis/redis.module.js';
import type { UserSummaryDto } from '../live/live-rooms.service.js';
import {
  PostViews,
  userSummary,
  USER_SUMMARY_SELECT,
  visiblePostWhere,
  type PageDto,
  type PostDto,
} from './post-views.js';
import type { FeedQuery, PageQuery } from './posts.schemas.js';
import { PostsService } from './posts.service.js';

/** Trending (CONVENTIONS §11.3): window, snapshot size and lifetime, author spread. */
const TRENDING_WINDOW_HOURS = 7 * 24;
const TRENDING_CANDIDATES = 2000;
const TRENDING_SNAPSHOT_SIZE = 500;
const TRENDING_SNAPSHOT_SECONDS = 600;
const TRENDING_SPREAD = { window: 10, perAuthor: 2 } as const;
/**
 * Score weights: `(likes + 2·comments + 3·shares + 2·saves + 1) / (hours + 2)^1.5`. Server-side
 * constants until ranking moves to its own service (M5); changing them is not a contract change.
 */
export const TRENDING_WEIGHTS = { like: 1, comment: 2, share: 3, save: 2, gravity: 1.5 } as const;

/**
 * At most `perAuthor` posts by one author in any `window` consecutive entries, keeping the ranked
 * order otherwise (a post that does not fit waits for the first place where it does).
 */
export function spreadAuthors<T extends { authorId: string }>(ranked: readonly T[], limit: number): T[] {
  const out: T[] = [];
  const waiting = [...ranked];
  while (out.length < limit && waiting.length > 0) {
    const recent = out.slice(-(TRENDING_SPREAD.window - 1));
    const index = waiting.findIndex(
      (c) => recent.filter((r) => r.authorId === c.authorId).length < TRENDING_SPREAD.perAuthor,
    );
    if (index < 0) break;
    out.push(waiting.splice(index, 1)[0]!);
  }
  return out;
}

/** SQL: post `p` (author `a`, settings `s`) is visible to `viewer` in feeds (§11.2, §11.7). */
function feedVisibleSql(viewer: string): Prisma.Sql {
  return Prisma.sql`
    p.status = 'PUBLISHED'::post_status AND p.deleted_at IS NULL
    AND (p.moderation = 'VISIBLE'::post_moderation
         OR (p.author_id = ${viewer}::uuid AND p.moderation <> 'REMOVED'::post_moderation))
    AND a.status = 'ACTIVE'::user_status
    AND NOT EXISTS (SELECT 1 FROM user_blocks b
                     WHERE (b.blocker_id = a.id AND b.blocked_id = ${viewer}::uuid)
                        OR (b.blocker_id = ${viewer}::uuid AND b.blocked_id = a.id))
    AND (p.author_id = ${viewer}::uuid OR COALESCE(s.is_private, false) = false
         OR EXISTS (SELECT 1 FROM follows f2 WHERE f2.follower_id = ${viewer}::uuid AND f2.followee_id = a.id))
    AND NOT EXISTS (SELECT 1 FROM user_mutes m WHERE m.muter_id = ${viewer}::uuid AND m.muted_id = a.id)
    AND NOT EXISTS (SELECT 1 FROM post_hides h WHERE h.user_id = ${viewer}::uuid AND h.post_id = p.id)`;
}

/** Feeds and the post lists of interactions: Following, Trending, saved, a user's reposts. */
@Injectable()
export class FeedService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly posts: PostsService,
    private readonly views: PostViews,
    @Inject(REDIS) private readonly redis: Redis,
  ) {}

  feed(viewerId: string, query: FeedQuery): Promise<PageDto<PostDto>> {
    return query.tab === 'following' ? this.following(viewerId, query) : this.trending(viewerId, query);
  }

  /**
   * Following: posts and reposts of followed accounts, newest entry first; a post appears once
   * (its newest entry; a repost entry carries `repostedBy`). Muted and hidden are left out.
   */
  private async following(viewerId: string, query: FeedQuery): Promise<PageDto<PostDto>> {
    const scope = `feed-following:${viewerId}`;
    const after = this.posts.decode(query.cursor, scope);
    const rows = await this.prisma.$queryRaw<{ post_id: string; at: Date; reposter_id: string | null }[]>`
      WITH entries AS (
        SELECT p.id AS post_id, p.published_at AS at, NULL::uuid AS reposter_id
          FROM follows f JOIN posts p ON p.author_id = f.followee_id
         WHERE f.follower_id = ${viewerId}::uuid
           AND p.status = 'PUBLISHED'::post_status AND p.deleted_at IS NULL
        UNION ALL
        SELECT r.post_id, r.created_at, r.user_id
          FROM follows f
          JOIN post_reposts r ON r.user_id = f.followee_id
          JOIN users ru ON ru.id = r.user_id AND ru.status = 'ACTIVE'::user_status
         WHERE f.follower_id = ${viewerId}::uuid
           AND NOT EXISTS (SELECT 1 FROM user_mutes m
                            WHERE m.muter_id = ${viewerId}::uuid AND m.muted_id = r.user_id)
      ), newest AS (
        SELECT DISTINCT ON (post_id) post_id, at, reposter_id
          FROM entries ORDER BY post_id, at DESC, reposter_id NULLS FIRST
      )
      SELECT n.post_id::text AS post_id, n.at, n.reposter_id::text AS reposter_id
        FROM newest n
        JOIN posts p ON p.id = n.post_id
        JOIN users a ON a.id = p.author_id
        LEFT JOIN user_settings s ON s.user_id = a.id
       WHERE ${feedVisibleSql(viewerId)}
         ${after ? Prisma.sql`AND (n.at, n.post_id) < (${after.at}, ${after.id}::uuid)` : Prisma.empty}
       ORDER BY n.at DESC, n.post_id DESC
       LIMIT ${query.limit + 1}`;
    const hasMore = rows.length > query.limit;
    const pageRows = rows.slice(0, query.limit);
    const reposters = await this.summaries(pageRows.flatMap((r) => (r.reposter_id ? [r.reposter_id] : [])));
    const repostedBy = new Map(
      pageRows.flatMap((r) => {
        const by = r.reposter_id ? reposters.get(r.reposter_id) : undefined;
        return by ? [[r.post_id, by] as const] : [];
      }),
    );
    const last = pageRows[pageRows.length - 1];
    return {
      data: await this.views.load(
        viewerId,
        pageRows.map((r) => r.post_id),
        repostedBy,
      ),
      page: {
        hasMore,
        nextCursor:
          hasMore && last ? this.posts.cursors.encode(scope, { at: last.at, id: last.post_id }) : null,
      },
    };
  }

  /**
   * Trending: the first page ranks and freezes up to 500 ids for 10 minutes (in Redis, per
   * caller); later pages read that snapshot by offset, so they never repeat or skip. Posts that
   * stopped being visible since are left out of the page.
   */
  private async trending(viewerId: string, query: FeedQuery): Promise<PageDto<PostDto>> {
    const scope = `feed-trending:${viewerId}`;
    const after = this.posts.decode(query.cursor, scope);
    let snapshotId: string;
    let createdAt: Date;
    let ids: string[];
    const offset = after?.n ?? 0;
    if (after) {
      snapshotId = after.id;
      createdAt = after.at;
      const stored = await this.redis.get(this.snapshotKey(viewerId, snapshotId));
      if (stored === null) throw AppException.validation([{ field: 'cursor', issue: 'invalid_value' }]);
      ids = JSON.parse(stored) as string[];
    } else {
      snapshotId = randomUUID();
      createdAt = new Date();
      ids = await this.rankTrending(viewerId);
      await this.redis.set(
        this.snapshotKey(viewerId, snapshotId),
        JSON.stringify(ids),
        'EX',
        TRENDING_SNAPSHOT_SECONDS,
      );
    }
    const slice = ids.slice(offset, offset + query.limit);
    const visible = new Set(
      (
        await this.prisma.post.findMany({
          where: { AND: [{ id: { in: slice } }, visiblePostWhere(viewerId)] },
          select: { id: true },
        })
      ).map((p) => p.id),
    );
    const next = offset + slice.length;
    const hasMore = next < ids.length;
    return {
      data: await this.views.load(
        viewerId,
        slice.filter((id) => visible.has(id)),
      ),
      page: {
        hasMore,
        nextCursor: hasMore
          ? this.posts.cursors.encode(scope, { at: createdAt, id: snapshotId, n: next })
          : null,
      },
    };
  }

  private snapshotKey(viewerId: string, snapshotId: string): string {
    return `social:trending:${viewerId}:${snapshotId}`;
  }

  /** Ranked ids of visible public posts of the last 7 days, not the caller's, spread by author. */
  async rankTrending(viewerId: string): Promise<string[]> {
    const w = TRENDING_WEIGHTS;
    const rows = await this.prisma.$queryRaw<{ id: string; author_id: string }[]>`
      SELECT p.id::text AS id, p.author_id::text AS author_id
        FROM posts p
        JOIN users a ON a.id = p.author_id
        LEFT JOIN user_settings s ON s.user_id = a.id
       WHERE ${feedVisibleSql(viewerId)}
         AND p.moderation = 'VISIBLE'::post_moderation
         AND COALESCE(s.is_private, false) = false
         AND p.author_id <> ${viewerId}::uuid
         AND p.published_at >= now() - make_interval(hours => ${TRENDING_WINDOW_HOURS}::int)
       ORDER BY (${w.like}::float8 * p.like_count + ${w.comment}::float8 * p.comment_count
                 + ${w.share}::float8 * p.share_count + ${w.save}::float8 * p.save_count + 1)
                / power(GREATEST(EXTRACT(EPOCH FROM (now() - p.published_at)), 0) / 3600 + 2, ${w.gravity}::float8) DESC,
                p.published_at DESC, p.id DESC
       LIMIT ${TRENDING_CANDIDATES}`;
    return spreadAuthors(
      rows.map((r) => ({ id: r.id, authorId: r.author_id })),
      TRENDING_SNAPSHOT_SIZE,
    ).map((r) => r.id);
  }

  /** `GET /me/saved`: newest save first; posts no longer visible are skipped. */
  async saved(viewerId: string, query: PageQuery): Promise<PageDto<PostDto>> {
    const scope = `saved:${viewerId}`;
    const after = this.posts.decode(query.cursor, scope);
    const rows = await this.prisma.postSave.findMany({
      where: {
        userId: viewerId,
        post: visiblePostWhere(viewerId),
        ...(after
          ? { OR: [{ createdAt: { lt: after.at } }, { createdAt: after.at, postId: { lt: after.id } }] }
          : {}),
      },
      orderBy: [{ createdAt: 'desc' }, { postId: 'desc' }],
      take: query.limit + 1,
      select: { postId: true, createdAt: true },
    });
    return this.posts.page(
      viewerId,
      rows.map((r) => ({ id: r.postId, at: r.createdAt })),
      query.limit,
      (r) => this.posts.cursors.encode(scope, { at: r.at, id: r.id }),
    );
  }

  /** `GET /users/{username}/reposts`: newest repost first, each with `repostedBy`. */
  async userReposts(viewerId: string, username: string, query: PageQuery): Promise<PageDto<PostDto>> {
    const userId = await this.posts.readableAuthor(viewerId, username);
    const scope = `user-reposts:${userId}:${viewerId}`;
    const after = this.posts.decode(query.cursor, scope);
    const rows = await this.prisma.postRepost.findMany({
      where: {
        userId,
        post: visiblePostWhere(viewerId),
        ...(after
          ? { OR: [{ createdAt: { lt: after.at } }, { createdAt: after.at, postId: { lt: after.id } }] }
          : {}),
      },
      orderBy: [{ createdAt: 'desc' }, { postId: 'desc' }],
      take: query.limit + 1,
      select: { postId: true, createdAt: true },
    });
    const hasMore = rows.length > query.limit;
    const pageRows = rows.slice(0, query.limit);
    const by = (await this.summaries([userId])).get(userId)!;
    const last = pageRows[pageRows.length - 1];
    return {
      data: await this.views.load(
        viewerId,
        pageRows.map((r) => r.postId),
        new Map(pageRows.map((r) => [r.postId, by])),
      ),
      page: {
        hasMore,
        nextCursor:
          hasMore && last ? this.posts.cursors.encode(scope, { at: last.createdAt, id: last.postId }) : null,
      },
    };
  }

  private async summaries(ids: readonly string[]): Promise<Map<string, UserSummaryDto>> {
    if (ids.length === 0) return new Map();
    const users = await this.prisma.user.findMany({
      where: { id: { in: [...new Set(ids)] } },
      select: USER_SUMMARY_SELECT,
    });
    return new Map(users.map((u) => [u.id, userSummary(u)]));
  }
}
