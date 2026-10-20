import { Injectable } from '@nestjs/common';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { zodErrorToDetails } from '../../common/validation/zod-validation.pipe.js';
import type { Prisma } from '../../generated/prisma/client.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import type { UserSummaryDto } from '../live/live-rooms.service.js';
import { isUuid } from '../live/live.schemas.js';
import { USER_SUMMARY_SELECT, userSummary, visiblePostWhere, type PageDto } from './post-views.js';
import { recordViewsSchema, type PageQuery } from './posts.schemas.js';
import { PostsService } from './posts.service.js';

type Tx = Prisma.TransactionClient;

/** A view counts once per user, post and rolling 24 hours, after ≥ 1 s on screen (§11.4). */
const VIEW_WINDOW_MS = 24 * 3600_000;
const MIN_WATCHED_MS = 1000;

export interface LikeStateDto {
  liked: boolean;
  likeCount: number | null;
}

/**
 * Likes, saves, reposts, outside shares and views (CONVENTIONS §11.2–§11.4). Each toggle writes
 * its row and the post's counter in one transaction; the row's primary key makes a repeat (or a
 * concurrent duplicate) a no-op, so counters never drift from the rows.
 */
@Injectable()
export class PostInteractionsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly posts: PostsService,
  ) {}

  /** A published post the viewer may see, locked FOR SHARE in `tx` (deletes wait), else 404. */
  private async visiblePublished(tx: Tx, viewerId: string, postId: string) {
    if (!isUuid(postId)) throw new AppException(ErrorCode.NOT_FOUND);
    const post = await tx.post.findFirst({
      where: { AND: [{ id: postId.toLowerCase() }, visiblePostWhere(viewerId)] },
      select: { id: true, authorId: true, hideLikeCount: true, author: { select: { settings: true } } },
    });
    if (!post) throw new AppException(ErrorCode.NOT_FOUND);
    await tx.$queryRaw`SELECT 1 FROM posts WHERE id = ${post.id}::uuid FOR SHARE`;
    return post;
  }

  // ---------------------------------------------------------------------------------------------
  // Likes

  async like(userId: string, postId: string, liked: boolean): Promise<LikeStateDto> {
    return this.prisma.$transaction(async (tx) => {
      const post = await this.visiblePublished(tx, userId, postId);
      const changed = liked
        ? (await tx.postLike.createMany({ data: [{ postId: post.id, userId }], skipDuplicates: true })).count
        : (await tx.postLike.deleteMany({ where: { postId: post.id, userId } })).count;
      const { likeCount } = changed
        ? await tx.post.update({
            where: { id: post.id },
            data: { likeCount: { increment: liked ? 1 : -1 } },
            select: { likeCount: true },
          })
        : await tx.post.findUniqueOrThrow({ where: { id: post.id }, select: { likeCount: true } });
      return { liked, likeCount: post.hideLikeCount && post.authorId !== userId ? null : likeCount };
    });
  }

  /**
   * `GET /posts/{postId}/likes`, newest first: ACTIVE likers with no block either way with the
   * viewer. A hidden like count makes the list the author's only (403 for everyone else).
   */
  async likers(viewerId: string, postId: string, query: PageQuery): Promise<PageDto<UserSummaryDto>> {
    const post = await this.visiblePublished(this.prisma, viewerId, postId);
    if (post.hideLikeCount && post.authorId !== viewerId) throw new AppException(ErrorCode.AUTH_FORBIDDEN);
    const scope = `likers:${post.id}:${viewerId}`;
    const after = this.posts.decode(query.cursor, scope);
    const rows = await this.prisma.postLike.findMany({
      where: {
        postId: post.id,
        user: {
          status: 'ACTIVE',
          blocking: { none: { blockedId: viewerId } },
          blockedBy: { none: { blockerId: viewerId } },
        },
        ...(after
          ? { OR: [{ createdAt: { lt: after.at } }, { createdAt: after.at, userId: { lt: after.id } }] }
          : {}),
      },
      orderBy: [{ createdAt: 'desc' }, { userId: 'desc' }],
      take: query.limit + 1,
      select: { createdAt: true, userId: true, user: { select: USER_SUMMARY_SELECT } },
    });
    const hasMore = rows.length > query.limit;
    const pageRows = rows.slice(0, query.limit);
    const last = pageRows[pageRows.length - 1];
    return {
      data: pageRows.map((r) => userSummary(r.user)),
      page: {
        hasMore,
        nextCursor:
          hasMore && last ? this.posts.cursors.encode(scope, { at: last.createdAt, id: last.userId }) : null,
      },
    };
  }

  // ---------------------------------------------------------------------------------------------
  // Saves

  async save(userId: string, postId: string, saved: boolean): Promise<{ saved: boolean }> {
    await this.prisma.$transaction(async (tx) => {
      const post = await this.visiblePublished(tx, userId, postId);
      const changed = saved
        ? (await tx.postSave.createMany({ data: [{ postId: post.id, userId }], skipDuplicates: true })).count
        : (await tx.postSave.deleteMany({ where: { postId: post.id, userId } })).count;
      if (changed) {
        await tx.post.update({ where: { id: post.id }, data: { saveCount: { increment: saved ? 1 : -1 } } });
      }
    });
    return { saved };
  }

  // ---------------------------------------------------------------------------------------------
  // Reposts

  /** Reposts a visible public post by someone else (own or private → 400 `postId`). */
  async repost(
    userId: string,
    postId: string,
    reposted: boolean,
  ): Promise<{ reposted: boolean; repostCount: number }> {
    return this.prisma.$transaction(async (tx) => {
      const post = await this.visiblePublished(tx, userId, postId);
      let changed: number;
      if (reposted) {
        if (post.authorId === userId || post.author.settings?.isPrivate) {
          throw AppException.validation([{ field: 'postId', issue: 'invalid_value' }]);
        }
        changed = (
          await tx.postRepost.createMany({ data: [{ postId: post.id, userId }], skipDuplicates: true })
        ).count;
      } else {
        changed = (await tx.postRepost.deleteMany({ where: { postId: post.id, userId } })).count;
      }
      const { repostCount } = changed
        ? await tx.post.update({
            where: { id: post.id },
            data: { repostCount: { increment: reposted ? 1 : -1 } },
            select: { repostCount: true },
          })
        : await tx.post.findUniqueOrThrow({ where: { id: post.id }, select: { repostCount: true } });
      return { reposted, repostCount };
    });
  }

  // ---------------------------------------------------------------------------------------------
  // Shares and views

  /** Counts an outside share once per user, post and UTC day. */
  async share(userId: string, postId: string): Promise<{ shareCount: number }> {
    return this.prisma.$transaction(async (tx) => {
      const post = await this.visiblePublished(tx, userId, postId);
      const day = new Date(new Date().toISOString().slice(0, 10));
      const { count } = await tx.postShareEvent.createMany({
        data: [{ postId: post.id, userId, day }],
        skipDuplicates: true,
      });
      const { shareCount } = count
        ? await tx.post.update({
            where: { id: post.id },
            data: { shareCount: { increment: 1 } },
            select: { shareCount: true },
          })
        : await tx.post.findUniqueOrThrow({ where: { id: post.id }, select: { shareCount: true } });
      return { shareCount };
    });
  }

  /**
   * `POST /views` (best effort): counts the items watched ≥ 1 s of posts the caller may see and
   * did not write, once per rolling 24 hours. Everything else is ignored silently.
   */
  async recordViews(userId: string, body: unknown): Promise<void> {
    const parsed = recordViewsSchema.safeParse(body ?? {});
    if (!parsed.success) throw AppException.validation(zodErrorToDetails(parsed.error));
    const ids = [
      ...new Set(
        parsed.data.items.filter((i) => i.watchedMs >= MIN_WATCHED_MS).map((i) => i.postId.toLowerCase()),
      ),
    ];
    if (ids.length === 0) return;
    const visible = await this.prisma.post.findMany({
      where: { AND: [{ id: { in: ids } }, { authorId: { not: userId } }, visiblePostWhere(userId)] },
      select: { id: true },
    });
    if (visible.length === 0) return;
    const now = new Date();
    const cutoff = new Date(now.getTime() - VIEW_WINDOW_MS);
    await this.prisma.$transaction(async (tx) => {
      // A row is inserted, or moved forward when its last counted view is ≥ 24 h old; only those
      // rows (RETURNING) add to the post's count. Sorted ids keep lock order deterministic.
      const counted = await tx.$queryRaw<{ post_id: string }[]>`
        INSERT INTO post_views (post_id, user_id, viewed_at)
        SELECT unnest(${visible.map((v) => v.id).sort()}::uuid[]), ${userId}::uuid, ${now}
        ON CONFLICT (post_id, user_id) DO UPDATE SET viewed_at = EXCLUDED.viewed_at
         WHERE post_views.viewed_at <= ${cutoff}
        RETURNING post_id::text AS post_id`;
      if (counted.length > 0) {
        await tx.post.updateMany({
          where: { id: { in: counted.map((c) => c.post_id) } },
          data: { viewCount: { increment: 1 } },
        });
      }
    });
  }
}
