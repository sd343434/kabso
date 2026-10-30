import { Injectable } from '@nestjs/common';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { zodErrorToDetails } from '../../common/validation/zod-validation.pipe.js';
import type { Prisma } from '../../generated/prisma/client.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import type { UserSummaryDto } from '../live/live-rooms.service.js';
import { isUuid } from '../live/live.schemas.js';
import { Notifier } from '../notifications/notifier.js';
import { UsersService } from '../users/users.service.js';
import type { LikeStateDto } from './post-interactions.service.js';
import {
  MENTION_USER_SELECT,
  mentionedByName,
  USER_SUMMARY_SELECT,
  userSummary,
  visiblePostWhere,
  type PageDto,
} from './post-views.js';
import { createCommentSchema, type PageQuery } from './posts.schemas.js';
import { PostsService } from './posts.service.js';
import { parseMentions } from './text-entities.js';

type Tx = Prisma.TransactionClient;

/** `Comment` (openapi v1.5-social). */
export interface CommentDto {
  id: string;
  postId: string;
  author: UserSummaryDto;
  text: string;
  createdAt: string;
  likeCount: number;
  viewerHasLiked: boolean;
  replyCount: number;
  parentId: string | null;
  mentions: UserSummaryDto[];
  pinned: boolean;
  canDelete: boolean;
}

/**
 * Comments a viewer may see (CONVENTIONS §11.5, §11.7): not deleted, on a post the viewer may
 * see, by an ACTIVE author with no block either way with the viewer.
 */
function visibleCommentWhere(viewerId: string): Prisma.CommentWhereInput {
  return {
    deletedAt: null,
    post: visiblePostWhere(viewerId),
    author: {
      status: 'ACTIVE',
      blocking: { none: { blockedId: viewerId } },
      blockedBy: { none: { blockerId: viewerId } },
    },
  };
}

function include(viewerId: string) {
  return {
    author: { select: USER_SUMMARY_SELECT },
    post: { select: { authorId: true } },
    mentions: { where: { user: { status: 'ACTIVE' } }, include: { user: { select: MENTION_USER_SELECT } } },
    likes: { where: { userId: viewerId }, select: { userId: true }, take: 1 },
  } satisfies Prisma.CommentInclude;
}

type CommentRow = Prisma.CommentGetPayload<{ include: ReturnType<typeof include> }>;

/**
 * Comments and one level of replies (CONVENTIONS §11.5): create, list, delete, like and pin.
 * Counters (`posts.comment_count`, `comments.reply_count`, `comments.like_count`) change in the
 * same transaction as their rows.
 */
@Injectable()
export class CommentsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly posts: PostsService,
    private readonly users: UsersService,
    private readonly notifier: Notifier,
  ) {}

  // ---------------------------------------------------------------------------------------------
  // Create

  /** `POST /posts/{postId}/comments`. */
  async create(authorId: string, postId: string, body: unknown): Promise<CommentDto> {
    if (!isUuid(postId)) throw new AppException(ErrorCode.NOT_FOUND);
    const parsed = createCommentSchema.safeParse(body ?? {});
    if (!parsed.success) throw AppException.validation(zodErrorToDetails(parsed.error));
    const input = parsed.data;
    const id = await this.prisma.$transaction(async (tx) => {
      if (!(await this.users.lockActiveById(tx, authorId)))
        throw new AppException(ErrorCode.AUTH_UNAUTHENTICATED);
      const post = await tx.post.findFirst({
        where: { AND: [{ id: postId.toLowerCase() }, visiblePostWhere(authorId)] },
        select: { id: true, authorId: true, commentsEnabled: true, whoCanComment: true },
      });
      if (!post) throw new AppException(ErrorCode.NOT_FOUND);
      // Lock order everywhere: the post, then a comment (no deadlock with delete or pin).
      await tx.$queryRaw`SELECT 1 FROM posts WHERE id = ${post.id}::uuid FOR UPDATE`;
      await this.checkMayComment(tx, authorId, post);
      let parentId: string | null = null;
      let repliedTo: string | null = null;
      if (input.parentId !== undefined) {
        const parent = await tx.comment.findFirst({
          where: {
            AND: [{ id: input.parentId.toLowerCase(), postId: post.id }, visibleCommentWhere(authorId)],
          },
          select: { id: true, parentId: true, authorId: true },
        });
        if (!parent) throw AppException.validation([{ field: 'parentId', issue: 'invalid_value' }]);
        repliedTo = parent.authorId;
        // One level: a reply to a reply attaches to the top-level comment.
        parentId = parent.parentId ?? parent.id;
        await tx.$queryRaw`SELECT 1 FROM comments WHERE id = ${parentId}::uuid AND deleted_at IS NULL FOR UPDATE`;
        const top = await tx.comment.findUnique({ where: { id: parentId }, select: { deletedAt: true } });
        if (!top || top.deletedAt)
          throw AppException.validation([{ field: 'parentId', issue: 'invalid_value' }]);
      }
      const comment = await tx.comment.create({
        data: { postId: post.id, authorId, parentId, text: input.text },
      });
      const mentioned = await this.posts.mentionableUserIds(tx, authorId, parseMentions(input.text));
      if (mentioned.length > 0) {
        await tx.commentMention.createMany({
          data: mentioned.map((userId) => ({ commentId: comment.id, userId })),
        });
      }
      await tx.post.update({ where: { id: post.id }, data: { commentCount: { increment: 1 } } });
      if (parentId)
        await tx.comment.update({ where: { id: parentId }, data: { replyCount: { increment: 1 } } });
      // §11.10: COMMENT to the post's author (top level), REPLY to the author of the comment
      // replied to, MENTION to the others it names (once each).
      const target = { actorId: authorId, postId: post.id, commentId: comment.id };
      const told = new Set([authorId]);
      if (repliedTo === null) {
        await this.notifier.notify(tx, { type: 'COMMENT', recipientId: post.authorId, ...target });
        told.add(post.authorId);
      } else {
        await this.notifier.notify(tx, { type: 'REPLY', recipientId: repliedTo, ...target });
        told.add(repliedTo);
      }
      for (const userId of mentioned) {
        if (!told.has(userId))
          await this.notifier.notify(tx, { type: 'MENTION', recipientId: userId, ...target });
      }
      return comment.id;
    });
    return this.one(authorId, id);
  }

  /** `commentsEnabled` and `whoCanComment` (§11.5); the post's author always may. */
  private async checkMayComment(
    tx: Tx,
    userId: string,
    post: { authorId: string; commentsEnabled: boolean; whoCanComment: string },
  ): Promise<void> {
    if (post.authorId === userId) return;
    if (!post.commentsEnabled || post.whoCanComment === 'NOBODY')
      throw new AppException(ErrorCode.AUTH_FORBIDDEN);
    if (post.whoCanComment === 'FOLLOWERS') {
      const follows = await tx.follow.count({ where: { followerId: userId, followeeId: post.authorId } });
      if (follows === 0) throw new AppException(ErrorCode.AUTH_FORBIDDEN);
    }
  }

  // ---------------------------------------------------------------------------------------------
  // Lists

  /** `GET /posts/{postId}/comments`: the pinned one (first page), then by likes, then newest. */
  async list(viewerId: string, postId: string, query: PageQuery): Promise<PageDto<CommentDto>> {
    if (!isUuid(postId)) throw new AppException(ErrorCode.NOT_FOUND);
    const post = await this.prisma.post.findFirst({
      where: { AND: [{ id: postId.toLowerCase() }, visiblePostWhere(viewerId)] },
      select: { id: true },
    });
    if (!post) throw new AppException(ErrorCode.NOT_FOUND);
    const scope = `comments:${post.id}:${viewerId}`;
    const after = this.posts.decode(query.cursor, scope);
    const base: Prisma.CommentWhereInput = {
      AND: [visibleCommentWhere(viewerId), { postId: post.id, parentId: null }],
    };
    const pinned = after
      ? []
      : await this.prisma.comment.findMany({
          where: { AND: [base, { pinnedAt: { not: null } }] },
          take: 1,
          select: { id: true },
        });
    const room = Math.max(query.limit - pinned.length, 1);
    const rows = await this.prisma.comment.findMany({
      where: {
        AND: [
          base,
          { pinnedAt: null },
          after
            ? {
                OR: [
                  { likeCount: { lt: after.n ?? 0 } },
                  { likeCount: after.n ?? 0, createdAt: { lt: after.at } },
                  { likeCount: after.n ?? 0, createdAt: after.at, id: { lt: after.id } },
                ],
              }
            : {},
        ],
      },
      orderBy: [{ likeCount: 'desc' }, { createdAt: 'desc' }, { id: 'desc' }],
      take: room + 1,
      select: { id: true, likeCount: true, createdAt: true },
    });
    const hasMore = rows.length > room;
    const pageRows = rows.slice(0, room);
    const last = pageRows[pageRows.length - 1];
    return {
      data: await this.load(viewerId, [...pinned.map((p) => p.id), ...pageRows.map((r) => r.id)]),
      page: {
        hasMore,
        nextCursor:
          hasMore && last
            ? this.posts.cursors.encode(scope, { at: last.createdAt, id: last.id, n: last.likeCount })
            : null,
      },
    };
  }

  /** `GET /comments/{commentId}/replies`: oldest first. */
  async replies(viewerId: string, commentId: string, query: PageQuery): Promise<PageDto<CommentDto>> {
    const parent = await this.findVisible(this.prisma, viewerId, commentId);
    if (parent.parentId !== null) throw new AppException(ErrorCode.NOT_FOUND);
    const scope = `replies:${parent.id}:${viewerId}`;
    const after = this.posts.decode(query.cursor, scope);
    const rows = await this.prisma.comment.findMany({
      where: {
        AND: [
          visibleCommentWhere(viewerId),
          { parentId: parent.id },
          after
            ? { OR: [{ createdAt: { gt: after.at } }, { createdAt: after.at, id: { gt: after.id } }] }
            : {},
        ],
      },
      orderBy: [{ createdAt: 'asc' }, { id: 'asc' }],
      take: query.limit + 1,
      select: { id: true, createdAt: true },
    });
    const hasMore = rows.length > query.limit;
    const pageRows = rows.slice(0, query.limit);
    const last = pageRows[pageRows.length - 1];
    return {
      data: await this.load(
        viewerId,
        pageRows.map((r) => r.id),
      ),
      page: {
        hasMore,
        nextCursor:
          hasMore && last ? this.posts.cursors.encode(scope, { at: last.createdAt, id: last.id }) : null,
      },
    };
  }

  // ---------------------------------------------------------------------------------------------
  // Delete, like, pin

  /** A comment the viewer may see, else 404. */
  private async findVisible(db: Tx, viewerId: string, commentId: string) {
    if (!isUuid(commentId)) throw new AppException(ErrorCode.NOT_FOUND);
    const row = await db.comment.findFirst({
      where: { AND: [{ id: commentId.toLowerCase() }, visibleCommentWhere(viewerId)] },
      select: {
        id: true,
        postId: true,
        parentId: true,
        authorId: true,
        post: { select: { authorId: true } },
      },
    });
    if (!row) throw new AppException(ErrorCode.NOT_FOUND);
    return row;
  }

  /** `DELETE /comments/{commentId}`: its author or the post's author; replies go with it. */
  async delete(userId: string, commentId: string): Promise<void> {
    await this.prisma.$transaction(async (tx) => {
      const found = await this.findVisible(tx, userId, commentId);
      if (found.authorId !== userId && found.post.authorId !== userId)
        throw new AppException(ErrorCode.NOT_FOUND);
      if (!(await this.removeIn(tx, found.id))) throw new AppException(ErrorCode.NOT_FOUND);
    });
  }

  /**
   * Soft-deletes a comment with its replies and adjusts the counters, inside `tx`. Lock order:
   * the post, then the comment. Returns false when the comment is already gone. Also used by
   * moderation (REMOVE_TARGET).
   */
  async removeIn(tx: Tx, commentId: string): Promise<boolean> {
    const target = await tx.comment.findUnique({ where: { id: commentId }, select: { postId: true } });
    if (!target) return false;
    await tx.$queryRaw`SELECT 1 FROM posts WHERE id = ${target.postId}::uuid FOR UPDATE`;
    const locked = await tx.$queryRaw<{ id: string; parent_id: string | null }[]>`
      SELECT id::text AS id, parent_id::text AS parent_id FROM comments
       WHERE id = ${commentId}::uuid AND deleted_at IS NULL FOR UPDATE`;
    const row = locked[0];
    if (!row) return false;
    const now = new Date();
    const replies = await tx.comment.updateMany({
      where: { parentId: row.id, deletedAt: null },
      data: { deletedAt: now, pinnedAt: null },
    });
    await tx.comment.update({ where: { id: row.id }, data: { deletedAt: now, pinnedAt: null } });
    await tx.post.update({
      where: { id: target.postId },
      data: { commentCount: { decrement: 1 + replies.count } },
    });
    if (row.parent_id) {
      await tx.comment.update({ where: { id: row.parent_id }, data: { replyCount: { decrement: 1 } } });
    }
    return true;
  }

  /** `PUT`/`DELETE /comments/{commentId}/like` (idempotent). */
  async like(userId: string, commentId: string, liked: boolean): Promise<LikeStateDto> {
    return this.prisma.$transaction(async (tx) => {
      const found = await this.findVisible(tx, userId, commentId);
      // Lock order everywhere: the post, then a comment. The LIKE_COMMENT notification references
      // the post, so taking the comment first would deadlock with a reply being created (§11.10).
      await tx.$queryRaw`SELECT 1 FROM posts WHERE id = ${found.postId}::uuid FOR UPDATE`;
      await tx.$queryRaw`SELECT 1 FROM comments WHERE id = ${found.id}::uuid FOR UPDATE`;
      const changed = liked
        ? (await tx.commentLike.createMany({ data: [{ commentId: found.id, userId }], skipDuplicates: true }))
            .count
        : (await tx.commentLike.deleteMany({ where: { commentId: found.id, userId } })).count;
      const { likeCount } = changed
        ? await tx.comment.update({
            where: { id: found.id },
            data: { likeCount: { increment: liked ? 1 : -1 } },
            select: { likeCount: true },
          })
        : await tx.comment.findUniqueOrThrow({ where: { id: found.id }, select: { likeCount: true } });
      if (changed) {
        const n = {
          type: 'LIKE_COMMENT',
          recipientId: found.authorId,
          actorId: userId,
          postId: found.postId,
          commentId: found.id,
        } as const;
        await (liked ? this.notifier.notify(tx, n) : this.notifier.undo(tx, n));
      }
      return { liked, likeCount };
    });
  }

  /** `PUT /comments/{commentId}/pin`: the post's author; top-level only; replaces the previous pin. */
  async pin(userId: string, commentId: string, pinned: boolean): Promise<CommentDto> {
    const id = await this.prisma.$transaction(async (tx) => {
      const found = await this.findVisible(tx, userId, commentId);
      if (found.post.authorId !== userId) throw new AppException(ErrorCode.NOT_FOUND);
      if (pinned && found.parentId !== null) {
        throw AppException.validation([{ field: 'commentId', issue: 'invalid_value' }]);
      }
      // Serializes pin changes on the post (one pin per post, partial unique index).
      await tx.$queryRaw`SELECT 1 FROM posts WHERE id = ${found.postId}::uuid FOR UPDATE`;
      if (pinned) {
        await tx.comment.updateMany({
          where: { postId: found.postId, pinnedAt: { not: null }, id: { not: found.id } },
          data: { pinnedAt: null },
        });
        await tx.comment.updateMany({
          where: { id: found.id, pinnedAt: null },
          data: { pinnedAt: new Date() },
        });
      } else {
        await tx.comment.update({ where: { id: found.id }, data: { pinnedAt: null } });
      }
      return found.id;
    });
    return this.one(userId, id);
  }

  // ---------------------------------------------------------------------------------------------
  // Views

  private async one(viewerId: string, id: string): Promise<CommentDto> {
    const [dto] = await this.load(viewerId, [id]);
    if (!dto) throw new AppException(ErrorCode.NOT_FOUND);
    return dto;
  }

  private async load(viewerId: string, ids: readonly string[]): Promise<CommentDto[]> {
    if (ids.length === 0) return [];
    const rows = await this.prisma.comment.findMany({
      where: { id: { in: [...ids] } },
      include: include(viewerId),
    });
    const byId = new Map(rows.map((r) => [r.id, r]));
    return ids.flatMap((id) => {
      const row = byId.get(id);
      return row ? [this.toDto(viewerId, row)] : [];
    });
  }

  private toDto(viewerId: string, row: CommentRow): CommentDto {
    const mentioned = mentionedByName(row.mentions);
    return {
      id: row.id,
      postId: row.postId,
      author: userSummary(row.author),
      text: row.text,
      createdAt: row.createdAt.toISOString(),
      likeCount: row.likeCount,
      viewerHasLiked: row.likes.length > 0,
      replyCount: row.replyCount,
      parentId: row.parentId,
      mentions: parseMentions(row.text).flatMap((u) => {
        const user = mentioned.get(u);
        return user ? [user] : [];
      }),
      pinned: row.pinnedAt !== null,
      canDelete: row.authorId === viewerId || row.post.authorId === viewerId,
    };
  }
}
