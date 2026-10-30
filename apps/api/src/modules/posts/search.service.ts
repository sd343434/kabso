import { randomUUID } from 'node:crypto';
import { Injectable } from '@nestjs/common';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { Prisma } from '../../generated/prisma/client.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import type { UserSummaryDto } from '../live/live-rooms.service.js';
import { FeedService, TRENDING_WEIGHTS } from './feed.service.js';
import { PostViews, visiblePostSql, type PageDto, type PostDto } from './post-views.js';
import type { HashtagPostsQuery, SearchQuery } from './posts.schemas.js';
import { PostsService } from './posts.service.js';
import { isValidHashtag, normalizeHashtag } from './text-entities.js';

/** `Hashtag` (openapi v1.5-social). */
export interface HashtagDto {
  tag: string;
  postCount: number;
}

export type SearchPageDto =
  | ({ type: 'users' } & PageDto<UserSummaryDto>)
  | ({ type: 'hashtags' } & PageDto<HashtagDto>)
  | ({ type: 'posts' } & PageDto<PostDto>);

/** Hashtag `top`: the trending score over 30 days (CONVENTIONS §11.6), at most 500 ranked ids. */
const TAG_TOP_WINDOW_DAYS = 30;
const TAG_TOP_SIZE = 500;
/** Ranked search lists are paged by offset; deeper pages are not served. */
const MAX_SEARCH_OFFSET = 500;
const MAX_QUERY_WORDS = 8;

/** Escapes LIKE wildcards (`\` is the escape character). */
function likePrefix(q: string): string {
  return `${q.replace(/[\\%_]/g, (c) => `\\${c}`)}%`;
}

/** Hashtag pages (§11.6) and prefix search for users, hashtags and posts. */
@Injectable()
export class SearchService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly posts: PostsService,
    private readonly feeds: FeedService,
    private readonly views: PostViews,
  ) {}

  // ---------------------------------------------------------------------------------------------
  // Hashtags

  private async findTag(raw: string): Promise<{ id: string; tag: string }> {
    const tag = normalizeHashtag(raw);
    if (!isValidHashtag(tag)) throw new AppException(ErrorCode.NOT_FOUND);
    const row = await this.prisma.hashtag.findUnique({ where: { tag }, select: { id: true, tag: true } });
    if (!row) throw new AppException(ErrorCode.NOT_FOUND);
    return row;
  }

  /** Visible (to `viewerId`), not hidden posts per hashtag id. */
  private async visibleTagCounts(viewerId: string, tagIds: readonly string[]): Promise<Map<string, number>> {
    if (tagIds.length === 0) return new Map();
    const rows = await this.prisma.$queryRaw<{ hashtag_id: string; n: number }[]>`
      SELECT ph.hashtag_id::text AS hashtag_id, count(*)::int AS n
        FROM post_hashtags ph
        JOIN posts p ON p.id = ph.post_id
        JOIN users a ON a.id = p.author_id
        LEFT JOIN user_settings s ON s.user_id = a.id
       WHERE ph.hashtag_id = ANY(${[...tagIds]}::uuid[])
         AND ${visiblePostSql(viewerId, { excludeMuted: false, excludeHidden: true })}
       GROUP BY ph.hashtag_id`;
    return new Map(rows.map((r) => [r.hashtag_id, r.n]));
  }

  /** `GET /hashtags/{tag}`. */
  async hashtag(viewerId: string, raw: string): Promise<HashtagDto> {
    const tag = await this.findTag(raw);
    const counts = await this.visibleTagCounts(viewerId, [tag.id]);
    return { tag: tag.tag, postCount: counts.get(tag.id) ?? 0 };
  }

  /** `GET /hashtags/{tag}/posts`: `recent` (newest first) or `top` (ranked snapshot). */
  async hashtagPosts(viewerId: string, raw: string, query: HashtagPostsQuery): Promise<PageDto<PostDto>> {
    const tag = await this.findTag(raw);
    if (query.sort === 'top') {
      return this.feeds.rankedPage(viewerId, `tag-top:${tag.id}`, query, () =>
        this.rankTagTop(viewerId, tag.id),
      );
    }
    const scope = `tag-recent:${tag.id}:${viewerId}`;
    const after = this.posts.decode(query.cursor, scope);
    const rows = await this.prisma.$queryRaw<{ id: string; published_at: Date }[]>`
      SELECT p.id::text AS id, p.published_at
        FROM post_hashtags ph
        JOIN posts p ON p.id = ph.post_id
        JOIN users a ON a.id = p.author_id
        LEFT JOIN user_settings s ON s.user_id = a.id
       WHERE ph.hashtag_id = ${tag.id}::uuid
         AND ${visiblePostSql(viewerId, { excludeMuted: false, excludeHidden: true })}
         ${after ? Prisma.sql`AND (p.published_at, p.id) < (${after.at}, ${after.id}::uuid)` : Prisma.empty}
       ORDER BY p.published_at DESC, p.id DESC
       LIMIT ${query.limit + 1}`;
    return this.posts.page(viewerId, rows, query.limit, (r) =>
      this.posts.cursors.encode(scope, { at: r.published_at, id: r.id }),
    );
  }

  private async rankTagTop(viewerId: string, tagId: string): Promise<string[]> {
    const w = TRENDING_WEIGHTS;
    const rows = await this.prisma.$queryRaw<{ id: string }[]>`
      SELECT p.id::text AS id
        FROM post_hashtags ph
        JOIN posts p ON p.id = ph.post_id
        JOIN users a ON a.id = p.author_id
        LEFT JOIN user_settings s ON s.user_id = a.id
       WHERE ph.hashtag_id = ${tagId}::uuid
         AND ${visiblePostSql(viewerId, { excludeMuted: false, excludeHidden: true })}
         AND p.published_at >= now() - make_interval(days => ${TAG_TOP_WINDOW_DAYS}::int)
       ORDER BY (${w.like}::float8 * p.like_count + ${w.comment}::float8 * p.comment_count
                 + ${w.share}::float8 * p.share_count + ${w.save}::float8 * p.save_count + 1)
                / power(GREATEST(EXTRACT(EPOCH FROM (now() - p.published_at)), 0) / 3600 + 2, ${w.gravity}::float8) DESC,
                p.published_at DESC, p.id DESC
       LIMIT ${TAG_TOP_SIZE}`;
    return rows.map((r) => r.id);
  }

  // ---------------------------------------------------------------------------------------------
  // Search

  /**
   * `GET /search` (§11.6): case-insensitive prefix match. Users and hashtags are ranked (exact
   * match first) and paged by offset; posts match caption word prefixes, newest first (keyset).
   * Blocked users and their posts never appear.
   */
  async search(viewerId: string, query: SearchQuery): Promise<SearchPageDto> {
    const q = query.q;
    const scope = `search:${query.type}:${viewerId}:${q}`;
    const after = this.posts.decode(query.cursor, scope);
    if (query.type === 'posts')
      return { type: 'posts', ...(await this.searchPosts(viewerId, q, query.limit, scope, after)) };
    const offset = after?.n ?? 0;
    if (offset >= MAX_SEARCH_OFFSET)
      throw AppException.validation([{ field: 'cursor', issue: 'invalid_value' }]);
    const take = Math.min(query.limit, MAX_SEARCH_OFFSET - offset);
    const pageInfo = (count: number) => {
      const hasMore = count > take && offset + take < MAX_SEARCH_OFFSET;
      return {
        hasMore,
        nextCursor: hasMore
          ? this.posts.cursors.encode(scope, {
              at: after?.at ?? new Date(),
              id: after?.id ?? randomUUID(),
              n: offset + take,
            })
          : null,
      };
    };
    if (query.type === 'users') {
      const rows = await this.searchUsers(viewerId, q, offset, take + 1);
      return { type: 'users', data: rows.slice(0, take), page: pageInfo(rows.length) };
    }
    const rows = await this.searchHashtags(viewerId, q, offset, take + 1);
    return { type: 'hashtags', data: rows.slice(0, take), page: pageInfo(rows.length) };
  }

  private async searchUsers(
    viewerId: string,
    q: string,
    offset: number,
    take: number,
  ): Promise<UserSummaryDto[]> {
    const lower = q.toLowerCase();
    const prefix = likePrefix(lower);
    const rows = await this.prisma.$queryRaw<
      (UserSummaryDto & { tier: UserSummaryDto['premiumTier'] | null })[]
    >`
      SELECT u.id::text AS id, p.username AS "username", p.display_name AS "displayName",
             p.avatar_url AS "avatarUrl", p.premium_tier::text AS "tier"
        FROM user_profiles p
        JOIN users u ON u.id = p.user_id AND u.status = 'ACTIVE'::user_status
       WHERE (p.username LIKE ${prefix} ESCAPE '\\' OR lower(p.display_name) LIKE ${prefix} ESCAPE '\\')
         AND NOT EXISTS (SELECT 1 FROM user_blocks b
                          WHERE (b.blocker_id = u.id AND b.blocked_id = ${viewerId}::uuid)
                             OR (b.blocker_id = ${viewerId}::uuid AND b.blocked_id = u.id))
       ORDER BY (p.username = ${lower} OR lower(p.display_name) = ${lower}) DESC,
                (SELECT count(*) FROM follows f WHERE f.followee_id = u.id) DESC,
                p.username ASC
       OFFSET ${offset} LIMIT ${take}`;
    // v1.28-live (D146): the badge tier only for premium usernames.
    return rows.map(({ tier, ...user }) => (tier ? { ...user, premiumTier: tier } : user));
  }

  private async searchHashtags(
    viewerId: string,
    q: string,
    offset: number,
    take: number,
  ): Promise<HashtagDto[]> {
    const tag = normalizeHashtag(q);
    const rows = await this.prisma.$queryRaw<{ id: string; tag: string }[]>`
      SELECT h.id::text AS id, h.tag
        FROM hashtags h
       WHERE h.tag LIKE ${likePrefix(tag)} ESCAPE '\\'
         -- v1.47-social (D175): only tags of posts the caller may see (a private account's tags stay
         -- hidden from non-followers, like its posts).
         AND EXISTS (SELECT 1 FROM post_hashtags ph
                       JOIN posts p ON p.id = ph.post_id
                       JOIN users a ON a.id = p.author_id
                       LEFT JOIN user_settings s ON s.user_id = a.id
                      WHERE ph.hashtag_id = h.id
                        AND ${visiblePostSql(viewerId, { excludeMuted: false, excludeHidden: false })})
       ORDER BY (h.tag = ${tag}) DESC,
                (SELECT count(*) FROM post_hashtags ph WHERE ph.hashtag_id = h.id) DESC,
                h.tag ASC
       OFFSET ${offset} LIMIT ${take}`;
    const counts = await this.visibleTagCounts(
      viewerId,
      rows.map((r) => r.id),
    );
    return rows.map((r) => ({ tag: r.tag, postCount: counts.get(r.id) ?? 0 }));
  }

  private async searchPosts(
    viewerId: string,
    q: string,
    limit: number,
    scope: string,
    after: { at: Date; id: string } | null,
  ): Promise<PageDto<PostDto>> {
    // Words of letters, marks, digits or `_` only, so the tsquery text cannot carry operators.
    const words = q
      .toLowerCase()
      .split(/[^\p{L}\p{M}\p{N}_]+/u)
      .filter((w) => w.length > 0)
      .slice(0, MAX_QUERY_WORDS);
    if (words.length === 0) return { data: [], page: { hasMore: false, nextCursor: null } };
    const tsquery = words.map((w) => `${w}:*`).join(' & ');
    const rows = await this.prisma.$queryRaw<{ id: string; published_at: Date }[]>`
      SELECT p.id::text AS id, p.published_at
        FROM posts p
        JOIN users a ON a.id = p.author_id
        LEFT JOIN user_settings s ON s.user_id = a.id
       WHERE to_tsvector('simple', p.text) @@ to_tsquery('simple', ${tsquery})
         AND ${visiblePostSql(viewerId, { excludeMuted: false, excludeHidden: false })}
         ${after ? Prisma.sql`AND (p.published_at, p.id) < (${after.at}, ${after.id}::uuid)` : Prisma.empty}
       ORDER BY p.published_at DESC, p.id DESC
       LIMIT ${limit + 1}`;
    return this.posts.page(viewerId, rows, limit, (r) =>
      this.posts.cursors.encode(scope, { at: r.published_at, id: r.id }),
    );
  }
}
