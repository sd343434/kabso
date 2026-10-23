import { createHash } from 'node:crypto';
import { Injectable } from '@nestjs/common';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { zodErrorToDetails } from '../../common/validation/zod-validation.pipe.js';
import { Prisma } from '../../generated/prisma/client.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import type { UserSummaryDto } from '../live/live-rooms.service.js';
import { isUuid } from '../live/live.schemas.js';
import { MediaService, type MediaAssetDto } from '../media/media.service.js';
import { Notifier } from '../notifications/notifier.js';
import { USER_SUMMARY_SELECT, userSummary, type PageDto } from '../posts/post-views.js';
import type { PageQuery } from '../posts/posts.schemas.js';
import { canonical, PostsService } from '../posts/posts.service.js';
import { parseMentions } from '../posts/text-entities.js';
import { UsersService, violatedUniqueIndex } from '../users/users.service.js';
import { createStorySchema, MAX_STORY_MENTIONS } from './stories.schemas.js';

/** `Story` (openapi v1.5-social, CP-008). */
export interface StoryDto {
  id: string;
  author: UserSummaryDto;
  media: MediaAssetDto;
  text: string;
  mentions: UserSummaryDto[];
  createdAt: string;
  expiresAt: string;
  viewerHasSeen: boolean;
  isSelf: boolean;
  viewCount: number | null;
}

/** `StoryTrayItem`. */
export interface StoryTrayItemDto {
  user: UserSummaryDto;
  storyCount: number;
  hasUnseen: boolean;
  latestAt: string;
}

/** A story lasts 24 hours (§11.9). */
export const STORY_TTL_MS = 24 * 3600_000;
/** The author sees who saw a story until 48 hours after posting. */
export const VIEWERS_WINDOW_MS = 48 * 3600_000;
/** `GET /users/{username}/stories` is not paged: at most this many (a day's limit is far lower). */
const MAX_ACTIVE = 100;
const IDEMPOTENCY_MS = 24 * 3600_000;

function include(viewerId: string) {
  return {
    author: { select: USER_SUMMARY_SELECT },
    mediaAsset: true,
    mentions: { where: { user: { status: 'ACTIVE' } }, include: { user: { select: USER_SUMMARY_SELECT } } },
    views: { where: { viewerId }, select: { viewerId: true }, take: 1 },
  } satisfies Prisma.StoryInclude;
}
type StoryRow = Prisma.StoryGetPayload<{ include: ReturnType<typeof include> }>;

/**
 * Stories a viewer may see (§11.9, the post rule of §11.2): not deleted or removed; the author
 * ACTIVE with no block either way; the viewer's own, or a public author's, or a followed one's.
 * "Active" (not expired) is added by the callers that need it.
 */
export function visibleStoryWhere(viewerId: string): Prisma.StoryWhereInput {
  return {
    deletedAt: null,
    removedAt: null,
    author: {
      status: 'ACTIVE',
      blocking: { none: { blockedId: viewerId } },
      blockedBy: { none: { blockerId: viewerId } },
    },
    OR: [
      { authorId: viewerId },
      {
        author: {
          OR: [
            { settings: { is: null } },
            { settings: { is: { isPrivate: false } } },
            { followers: { some: { followerId: viewerId } } },
          ],
        },
      },
    ],
  };
}

/**
 * Photo stories (CP-008, CONVENTIONS §11.9): post (idempotent), delete, the tray, a user's
 * active stories, one story, seen, viewers (author, 48 h) and the archive. Visible at once (no
 * moderation hold, D91); reports and the 24-hour expiry are the safety net.
 */
@Injectable()
export class StoriesService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly media: MediaService,
    private readonly users: UsersService,
    private readonly posts: PostsService,
    private readonly notifier: Notifier,
  ) {}

  toDto(row: StoryRow, viewerId: string): StoryDto {
    const self = row.authorId === viewerId;
    return {
      id: row.id,
      author: userSummary(row.author),
      media: this.media.toDto(row.mediaAsset),
      text: row.text,
      mentions: row.mentions.map((m) => userSummary(m.user)),
      createdAt: row.createdAt.toISOString(),
      expiresAt: row.expiresAt.toISOString(),
      viewerHasSeen: self || row.views.length > 0,
      isSelf: self,
      viewCount: self ? row.viewCount : null,
    };
  }

  private async one(viewerId: string, id: string): Promise<StoryDto> {
    const row = await this.prisma.story.findUniqueOrThrow({ where: { id }, include: include(viewerId) });
    return this.toDto(row, viewerId);
  }

  // ---------------------------------------------------------------------------------------------
  // Create and delete

  /** `POST /stories`. `idempotencyKey` is a validated UUID (the controller requires it). */
  async create(authorId: string, idempotencyKey: string, body: unknown): Promise<StoryDto> {
    const parsed = createStorySchema.safeParse(body ?? {});
    if (!parsed.success) throw AppException.validation(zodErrorToDetails(parsed.error));
    const input = { mediaId: parsed.data.mediaId.toLowerCase(), text: parsed.data.text ?? '' };
    const key = idempotencyKey.toLowerCase();
    const requestHash = createHash('sha256').update(canonical(input)).digest('hex');
    const replay = await this.findIdempotent(authorId, key, requestHash);
    if (replay) return replay;
    try {
      const id = await this.prisma.$transaction(async (tx) => {
        if (!(await this.users.lockActiveById(tx, authorId))) {
          throw new AppException(ErrorCode.AUTH_UNAUTHENTICATED);
        }
        await tx.story.updateMany({
          where: { authorId, idempotencyKey: key, createdAt: { lt: new Date(Date.now() - IDEMPOTENCY_MS) } },
          data: { idempotencyKey: null, requestHash: null },
        });
        const assets = await this.media.claimAssetsIn(tx, authorId, [input.mediaId], 'STORY_IMAGE');
        if (!assets) throw AppException.validation([{ field: 'mediaId', issue: 'invalid_value' }]);
        const now = new Date();
        const story = await tx.story.create({
          data: {
            authorId,
            mediaAssetId: assets[0]!.id,
            text: input.text,
            createdAt: now,
            expiresAt: new Date(now.getTime() + STORY_TTL_MS),
            idempotencyKey: key,
            requestHash,
          },
        });
        const usernames = parseMentions(input.text).slice(0, MAX_STORY_MENTIONS);
        const userIds = await this.posts.mentionableUserIds(tx, authorId, usernames);
        if (userIds.length > 0) {
          await tx.storyMention.createMany({
            data: userIds.map((userId) => ({ storyId: story.id, userId })),
          });
          for (const userId of userIds) {
            await this.notifier.notify(tx, {
              type: 'MENTION',
              recipientId: userId,
              actorId: authorId,
              storyId: story.id,
            });
          }
        }
        return story.id;
      });
      return this.one(authorId, id);
    } catch (err) {
      if (violatedUniqueIndex(err) !== null) {
        const raced = await this.findIdempotent(authorId, key, requestHash);
        if (raced) return raced;
      }
      throw err;
    }
  }

  private async findIdempotent(authorId: string, key: string, requestHash: string): Promise<StoryDto | null> {
    const existing = await this.prisma.story.findFirst({
      where: { authorId, idempotencyKey: key, createdAt: { gte: new Date(Date.now() - IDEMPOTENCY_MS) } },
      select: { id: true, requestHash: true, deletedAt: true },
    });
    if (!existing) return null;
    if (existing.requestHash !== requestHash) throw new AppException(ErrorCode.IDEMPOTENCY_CONFLICT);
    if (existing.deletedAt) throw new AppException(ErrorCode.NOT_FOUND);
    return this.one(authorId, existing.id);
  }

  /** `DELETE /stories/{storyId}` (author only; anyone else and a second delete → 404). */
  async delete(authorId: string, storyId: string): Promise<void> {
    if (!isUuid(storyId)) throw new AppException(ErrorCode.NOT_FOUND);
    const done = await this.prisma.story.updateMany({
      where: { id: storyId.toLowerCase(), authorId, deletedAt: null },
      data: { deletedAt: new Date() },
    });
    if (done.count === 0) throw new AppException(ErrorCode.NOT_FOUND);
  }

  // ---------------------------------------------------------------------------------------------
  // Read

  /**
   * The id of a story the viewer may see: active, or (for its author) expired but not deleted or
   * removed. Else 404.
   */
  async findVisibleId(viewerId: string, storyId: string): Promise<string> {
    if (!isUuid(storyId)) throw new AppException(ErrorCode.NOT_FOUND);
    const row = await this.prisma.story.findFirst({
      where: {
        AND: [
          { id: storyId.toLowerCase() },
          visibleStoryWhere(viewerId),
          { OR: [{ authorId: viewerId }, { expiresAt: { gt: new Date() } }] },
        ],
      },
      select: { id: true },
    });
    if (!row) throw new AppException(ErrorCode.NOT_FOUND);
    return row.id;
  }

  /** `GET /stories/{storyId}`. */
  async get(viewerId: string, storyId: string): Promise<StoryDto> {
    return this.one(viewerId, await this.findVisibleId(viewerId, storyId));
  }

  /** `GET /users/{username}/stories`: active, oldest first; not visible → 404 (as the grid). */
  async userStories(viewerId: string, username: string): Promise<{ data: StoryDto[] }> {
    const authorId = await this.posts.readableAuthor(viewerId, username);
    const rows = await this.prisma.story.findMany({
      where: { AND: [visibleStoryWhere(viewerId), { authorId, expiresAt: { gt: new Date() } }] },
      orderBy: [{ createdAt: 'asc' }, { id: 'asc' }],
      take: MAX_ACTIVE,
      include: include(viewerId),
    });
    return { data: rows.map((r) => this.toDto(r, viewerId)) };
  }

  /** `GET /me/stories/archive`: the caller's stories, active and expired, newest first. */
  async archive(authorId: string, query: PageQuery): Promise<PageDto<StoryDto>> {
    const scope = `story-archive:${authorId}`;
    const after = this.posts.decode(query.cursor, scope);
    const rows = await this.prisma.story.findMany({
      where: {
        authorId,
        deletedAt: null,
        removedAt: null,
        ...(after
          ? { OR: [{ createdAt: { lt: after.at } }, { createdAt: after.at, id: { lt: after.id } }] }
          : {}),
      },
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
      take: query.limit + 1,
      include: include(authorId),
    });
    const hasMore = rows.length > query.limit;
    const pageRows = rows.slice(0, query.limit);
    const last = pageRows[pageRows.length - 1];
    return {
      data: pageRows.map((r) => this.toDto(r, authorId)),
      page: {
        hasMore,
        nextCursor:
          hasMore && last ? this.posts.cursors.encode(scope, { at: last.createdAt, id: last.id }) : null,
      },
    };
  }

  /**
   * `GET /feed/stories`: the caller's own entry first (when they have an active story), then
   * followed accounts with active stories — unseen first, each group newest first; muted and
   * blocked accounts left out. Keyset over (group, newest story, author id).
   */
  async tray(viewerId: string, query: PageQuery): Promise<PageDto<StoryTrayItemDto>> {
    const scope = `story-tray:${viewerId}`;
    const after = this.posts.decode(query.cursor, scope);
    const keyset = after
      ? Prisma.sql`WHERE r.grp > ${after.n ?? 0}
           OR (r.grp = ${after.n ?? 0} AND (r.latest_at < ${after.at}
               OR (r.latest_at = ${after.at} AND r.author_id < ${after.id}::uuid)))`
      : Prisma.empty;
    const rows = await this.prisma.$queryRaw<
      { author_id: string; story_count: number; latest_at: Date; has_unseen: boolean; grp: number }[]
    >`
      WITH a AS (
        SELECT st.author_id,
               count(*)::int AS story_count,
               max(st.created_at) AS latest_at,
               bool_or(st.author_id <> ${viewerId}::uuid AND NOT EXISTS (
                 SELECT 1 FROM story_views v WHERE v.story_id = st.id AND v.viewer_id = ${viewerId}::uuid)) AS has_unseen
          FROM stories st
          JOIN users u ON u.id = st.author_id AND u.status = 'ACTIVE'::user_status
         WHERE st.deleted_at IS NULL AND st.removed_at IS NULL AND st.expires_at > now()
           AND (st.author_id = ${viewerId}::uuid
                OR EXISTS (SELECT 1 FROM follows f
                            WHERE f.follower_id = ${viewerId}::uuid AND f.followee_id = st.author_id))
           AND NOT EXISTS (SELECT 1 FROM user_blocks b
                            WHERE (b.blocker_id = st.author_id AND b.blocked_id = ${viewerId}::uuid)
                               OR (b.blocker_id = ${viewerId}::uuid AND b.blocked_id = st.author_id))
           AND NOT EXISTS (SELECT 1 FROM user_mutes m
                            WHERE m.muter_id = ${viewerId}::uuid AND m.muted_id = st.author_id)
         GROUP BY st.author_id
      ), r AS (
        SELECT a.*, CASE WHEN a.author_id = ${viewerId}::uuid THEN 0 WHEN a.has_unseen THEN 1 ELSE 2 END AS grp
          FROM a
      )
      SELECT r.author_id::text AS author_id, r.story_count, r.latest_at, r.has_unseen, r.grp
        FROM r
        ${keyset}
       ORDER BY r.grp ASC, r.latest_at DESC, r.author_id DESC
       LIMIT ${query.limit + 1}`;
    const hasMore = rows.length > query.limit;
    const pageRows = rows.slice(0, query.limit);
    const users = await this.prisma.user.findMany({
      where: { id: { in: pageRows.map((r) => r.author_id) } },
      select: USER_SUMMARY_SELECT,
    });
    const byId = new Map(users.map((u) => [u.id, userSummary(u)]));
    const last = pageRows[pageRows.length - 1];
    return {
      data: pageRows.map((r) => ({
        user: byId.get(r.author_id)!,
        storyCount: r.story_count,
        hasUnseen: r.has_unseen,
        latestAt: r.latest_at.toISOString(),
      })),
      page: {
        hasMore,
        nextCursor:
          hasMore && last
            ? this.posts.cursors.encode(scope, { at: last.latest_at, id: last.author_id, n: last.grp })
            : null,
      },
    };
  }

  // ---------------------------------------------------------------------------------------------
  // Seen and viewers

  /** `PUT /stories/{storyId}/seen`: idempotent; the author's own views never count. */
  async markSeen(viewerId: string, storyId: string): Promise<void> {
    if (!isUuid(storyId)) throw new AppException(ErrorCode.NOT_FOUND);
    const story = await this.prisma.story.findFirst({
      where: {
        AND: [{ id: storyId.toLowerCase(), expiresAt: { gt: new Date() } }, visibleStoryWhere(viewerId)],
      },
      select: { id: true, authorId: true },
    });
    if (!story) throw new AppException(ErrorCode.NOT_FOUND);
    if (story.authorId === viewerId) return;
    await this.prisma.$transaction(async (tx) => {
      const added = await tx.storyView.createMany({
        data: [{ storyId: story.id, viewerId }],
        skipDuplicates: true,
      });
      if (added.count > 0) {
        await tx.story.update({ where: { id: story.id }, data: { viewCount: { increment: 1 } } });
      }
    });
  }

  /**
   * `GET /stories/{storyId}/viewers`: the author only, until 48 hours after posting (else 404);
   * newest view first; accounts no longer ACTIVE or blocked either way are left out.
   */
  async viewers(authorId: string, storyId: string, query: PageQuery): Promise<PageDto<UserSummaryDto>> {
    if (!isUuid(storyId)) throw new AppException(ErrorCode.NOT_FOUND);
    const story = await this.prisma.story.findFirst({
      where: {
        id: storyId.toLowerCase(),
        authorId,
        deletedAt: null,
        removedAt: null,
        createdAt: { gt: new Date(Date.now() - VIEWERS_WINDOW_MS) },
      },
      select: { id: true },
    });
    if (!story) throw new AppException(ErrorCode.NOT_FOUND);
    const scope = `story-viewers:${story.id}`;
    const after = this.posts.decode(query.cursor, scope);
    const rows = await this.prisma.storyView.findMany({
      where: {
        storyId: story.id,
        viewer: {
          status: 'ACTIVE',
          blocking: { none: { blockedId: authorId } },
          blockedBy: { none: { blockerId: authorId } },
        },
        ...(after
          ? { OR: [{ seenAt: { lt: after.at } }, { seenAt: after.at, viewerId: { lt: after.id } }] }
          : {}),
      },
      orderBy: [{ seenAt: 'desc' }, { viewerId: 'desc' }],
      take: query.limit + 1,
      select: { seenAt: true, viewerId: true, viewer: { select: USER_SUMMARY_SELECT } },
    });
    const hasMore = rows.length > query.limit;
    const pageRows = rows.slice(0, query.limit);
    const last = pageRows[pageRows.length - 1];
    return {
      data: pageRows.map((r) => userSummary(r.viewer)),
      page: {
        hasMore,
        nextCursor:
          hasMore && last ? this.posts.cursors.encode(scope, { at: last.seenAt, id: last.viewerId }) : null,
      },
    };
  }
}
