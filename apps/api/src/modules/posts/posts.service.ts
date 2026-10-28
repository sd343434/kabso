import { createHash } from 'node:crypto';
import { Inject, Injectable, Logger, type OnModuleDestroy, type OnModuleInit } from '@nestjs/common';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { zodErrorToDetails } from '../../common/validation/zod-validation.pipe.js';
import type { Prisma } from '../../generated/prisma/client.js';
import { safeErrorLog } from '../../logging/redact-text.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { isUuid } from '../live/live.schemas.js';
import { MediaService } from '../media/media.service.js';
import { Notifier } from '../notifications/notifier.js';
import { UsersService, violatedUniqueIndex } from '../users/users.service.js';
import { PostViews, visiblePostWhere, type PageDto, type PostDto } from './post-views.js';
import {
  createPostSchema,
  updatePostSchema,
  type CreatePostInput,
  type MyPostsQuery,
  type PageQuery,
  type UpdatePostInput,
} from './posts.schemas.js';
import { SocialCursorCodec } from './social-cursor.js';
import { parseHashtags, parseMentions } from './text-entities.js';

/** At most 3 pinned posts per user (§11.2). */
export const MAX_PINS = 3;
/** Scheduling window (§11.2). */
const MIN_SCHEDULE_MS = 5 * 60_000;
const MAX_SCHEDULE_MS = 30 * 24 * 3600_000;
/** An Idempotency-Key is remembered for 24 hours (§11.2). */
const IDEMPOTENCY_MS = 24 * 3600_000;

type Tx = Prisma.TransactionClient;

/**
 * v1.41-social (D162, §11.14): whether claimed media of these kinds fit the format — a reel is
 * exactly one REEL_VIDEO; a post is photos only (≤ 10, by schema) or exactly one POST_VIDEO.
 */
export function mediaShapeAllowed(format: 'POST' | 'REEL', kinds: readonly string[]): boolean {
  if (format === 'REEL') return kinds.length === 1 && kinds[0] === 'REEL_VIDEO';
  if (kinds.some((k) => k === 'POST_VIDEO')) return kinds.length === 1;
  return kinds.every((k) => k === 'POST_IMAGE');
}

/** JSON with sorted object keys: the request hash does not depend on key order. */
export function canonical(value: unknown): string {
  if (Array.isArray(value)) return `[${value.map(canonical).join(',')}]`;
  if (value && typeof value === 'object') {
    return `{${Object.keys(value)
      .sort()
      .filter((k) => (value as Record<string, unknown>)[k] !== undefined)
      .map((k) => `${JSON.stringify(k)}:${canonical((value as Record<string, unknown>)[k])}`)
      .join(',')}}`;
  }
  return JSON.stringify(value);
}

/**
 * Posts (CONVENTIONS §11.2): create (with drafts, scheduling and idempotency), read, edit,
 * delete, pins and the profile grid. Every write that touches more than one row runs in one
 * transaction; the author's row is locked (FOR SHARE) so a suspension cannot interleave.
 */
@Injectable()
export class PostsService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(PostsService.name);
  readonly cursors: SocialCursorCodec;
  private publishTimer: NodeJS.Timeout | undefined;
  private publishInFlight: Promise<void> | null = null;

  constructor(
    private readonly prisma: PrismaService,
    private readonly media: MediaService,
    private readonly users: UsersService,
    private readonly views: PostViews,
    private readonly notifier: Notifier,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
  ) {
    this.cursors = new SocialCursorCodec(config.social.cursorKey);
  }

  onModuleInit(): void {
    if (this.config.social.publishIntervalSeconds > 0) this.schedulePublisher();
  }

  async onModuleDestroy(): Promise<void> {
    if (this.publishTimer) clearTimeout(this.publishTimer);
    await this.publishInFlight?.catch(() => undefined);
  }

  // ---------------------------------------------------------------------------------------------
  // Create

  /** `POST /posts`. `idempotencyKey` is a validated UUID (the controller requires it). */
  async create(authorId: string, idempotencyKey: string, body: unknown): Promise<PostDto> {
    const parsed = createPostSchema.safeParse(body ?? {});
    if (!parsed.success) throw AppException.validation(zodErrorToDetails(parsed.error));
    const input = parsed.data;
    const key = idempotencyKey.toLowerCase();
    const requestHash = createHash('sha256').update(canonical(input)).digest('hex');

    const replay = await this.findIdempotent(authorId, key, requestHash);
    if (replay) return replay;
    this.checkCreateRules(input);

    try {
      const id = await this.prisma.$transaction(async (tx) => {
        if (!(await this.users.lockActiveById(tx, authorId))) {
          throw new AppException(ErrorCode.AUTH_UNAUTHENTICATED);
        }
        // A key older than 24 h may be reused: release it first.
        await tx.post.updateMany({
          where: { authorId, idempotencyKey: key, createdAt: { lt: new Date(Date.now() - IDEMPOTENCY_MS) } },
          data: { idempotencyKey: null, requestHash: null },
        });
        const mediaIds = input.mediaIds ?? [];
        const format = input.format ?? 'POST';
        // v1.41-social (D162): a reel is one REEL_VIDEO; a post is 1–10 photos or one POST_VIDEO.
        const assets = await this.media.claimAssetsIn(
          tx,
          authorId,
          mediaIds,
          format === 'REEL' ? ['REEL_VIDEO'] : ['POST_IMAGE', 'POST_VIDEO'],
        );
        if (
          !assets ||
          !mediaShapeAllowed(
            format,
            assets.map((a) => a.kind),
          )
        ) {
          throw AppException.validation([{ field: 'mediaIds', issue: 'invalid_value' }]);
        }
        const privacy = await tx.privacySettings.findUnique({ where: { userId: authorId } });
        const status = input.status ?? 'PUBLISHED';
        const now = new Date();
        const post = await tx.post.create({
          data: {
            authorId,
            text: input.text ?? '',
            format,
            location: input.location ?? null,
            status,
            // CP-006 Q2: until a moderation provider exists, posts with images (D162: or a video,
            // reels included) are PENDING (visible to their author only); text-only posts are VISIBLE.
            moderation: assets.length > 0 ? 'PENDING' : 'VISIBLE',
            publishAt: status === 'SCHEDULED' ? new Date(input.publishAt!) : null,
            publishedAt: status === 'PUBLISHED' ? now : null,
            commentsEnabled: input.settings?.commentsEnabled ?? true,
            whoCanComment: input.settings?.whoCanComment ?? privacy?.defaultWhoCanComment ?? 'EVERYONE',
            hideLikeCount: input.settings?.hideLikeCount ?? false,
            idempotencyKey: key,
            requestHash,
          },
        });
        if (assets.length > 0) {
          await tx.postMedia.createMany({
            data: assets.map((a, position) => ({ postId: post.id, mediaAssetId: a.id, position })),
          });
        }
        await this.writeEntities(tx, post.id, authorId, post.text);
        if (status === 'PUBLISHED') await this.notifyMentions(tx, post.id, authorId);
        return post.id;
      });
      return this.views.one(authorId, id);
    } catch (err) {
      // A concurrent request with the same key won the race: replay its result.
      if (violatedUniqueIndex(err) !== null) {
        const raced = await this.findIdempotent(authorId, key, requestHash);
        if (raced) return raced;
      }
      throw err;
    }
  }

  private async findIdempotent(authorId: string, key: string, requestHash: string): Promise<PostDto | null> {
    const existing = await this.prisma.post.findFirst({
      where: { authorId, idempotencyKey: key, createdAt: { gte: new Date(Date.now() - IDEMPOTENCY_MS) } },
      select: { id: true, requestHash: true, deletedAt: true },
    });
    if (!existing) return null;
    if (existing.requestHash !== requestHash) throw new AppException(ErrorCode.IDEMPOTENCY_CONFLICT);
    if (existing.deletedAt) throw new AppException(ErrorCode.NOT_FOUND);
    return this.views.one(authorId, existing.id);
  }

  private checkCreateRules(input: CreatePostInput): void {
    const hasMedia = (input.mediaIds?.length ?? 0) > 0;
    if (input.format === 'REEL' && !hasMedia) {
      throw AppException.validation([{ field: 'mediaIds', issue: 'required' }]);
    }
    if (!hasMedia && (input.text ?? '') === '') {
      throw AppException.validation([{ field: 'text', issue: 'required' }]);
    }
    this.checkSchedule(input.status ?? 'PUBLISHED', input.publishAt);
  }

  private checkSchedule(status: string, publishAt: string | undefined): void {
    if (status !== 'SCHEDULED') {
      if (publishAt !== undefined)
        throw AppException.validation([{ field: 'publishAt', issue: 'unknown_field' }]);
      return;
    }
    if (publishAt === undefined) throw AppException.validation([{ field: 'publishAt', issue: 'required' }]);
    const at = new Date(publishAt).getTime();
    const now = Date.now();
    if (at < now + MIN_SCHEDULE_MS)
      throw AppException.validation([{ field: 'publishAt', issue: 'too_small' }]);
    if (at > now + MAX_SCHEDULE_MS) throw AppException.validation([{ field: 'publishAt', issue: 'too_big' }]);
  }

  /**
   * Stores the hashtags and linked mentions of `text` (CONVENTIONS §11.6). A mention links only an
   * ACTIVE user with no block either way whose `whoCanMention` allows the author.
   */
  async writeEntities(tx: Tx, postId: string, authorId: string, text: string): Promise<void> {
    await tx.postHashtag.deleteMany({ where: { postId } });
    await tx.postMention.deleteMany({ where: { postId } });
    const tags = parseHashtags(text);
    if (tags.length > 0) {
      await tx.hashtag.createMany({ data: tags.map((tag) => ({ tag })), skipDuplicates: true });
      const rows = await tx.hashtag.findMany({ where: { tag: { in: tags } }, select: { id: true } });
      await tx.postHashtag.createMany({ data: rows.map((h) => ({ postId, hashtagId: h.id })) });
    }
    const userIds = await this.mentionableUserIds(tx, authorId, parseMentions(text));
    if (userIds.length > 0) {
      await tx.postMention.createMany({ data: userIds.map((userId) => ({ postId, userId })) });
    }
  }

  /**
   * MENTION for each user a published post links (§11.10); once per user and post, so an edit
   * notifies only the newly mentioned.
   */
  private async notifyMentions(tx: Tx, postId: string, authorId: string): Promise<void> {
    const mentions = await tx.postMention.findMany({ where: { postId }, select: { userId: true } });
    for (const m of mentions) {
      await this.notifier.notify(tx, { type: 'MENTION', recipientId: m.userId, actorId: authorId, postId });
    }
  }

  /** The ids of `usernames` that `authorId` may mention (§11.6). */
  async mentionableUserIds(db: Tx, authorId: string, usernames: readonly string[]): Promise<string[]> {
    if (usernames.length === 0) return [];
    const rows = await db.$queryRaw<{ id: string }[]>`
      SELECT u.id::text AS id
        FROM user_profiles p
        JOIN users u ON u.id = p.user_id AND u.status = 'ACTIVE'::user_status
        LEFT JOIN privacy_settings ps ON ps.user_id = u.id
       WHERE p.username = ANY(${[...usernames]}::text[])
         AND NOT EXISTS (SELECT 1 FROM user_blocks b
                          WHERE (b.blocker_id = u.id AND b.blocked_id = ${authorId}::uuid)
                             OR (b.blocker_id = ${authorId}::uuid AND b.blocked_id = u.id))
         AND (u.id = ${authorId}::uuid
              OR COALESCE(ps.who_can_mention, 'EVERYONE'::who_can_mention) = 'EVERYONE'::who_can_mention
              OR (ps.who_can_mention = 'FOLLOWING'::who_can_mention
                  AND EXISTS (SELECT 1 FROM follows f WHERE f.follower_id = u.id AND f.followee_id = ${authorId}::uuid)))`;
    return rows.map((r) => r.id);
  }

  // ---------------------------------------------------------------------------------------------
  // Read

  /** A post the viewer may see (drafts and scheduled posts only for their author), else 404. */
  async findVisibleId(viewerId: string, postId: string, db: Tx = this.prisma): Promise<string> {
    if (!isUuid(postId)) throw new AppException(ErrorCode.NOT_FOUND);
    const id = postId.toLowerCase();
    const row = await db.post.findFirst({
      where: {
        id,
        OR: [
          visiblePostWhere(viewerId),
          { authorId: viewerId, deletedAt: null, status: { not: 'PUBLISHED' } },
        ],
      },
      select: { id: true },
    });
    if (!row) throw new AppException(ErrorCode.NOT_FOUND);
    return row.id;
  }

  /** `GET /posts/{postId}`. */
  async get(viewerId: string, postId: string): Promise<PostDto> {
    return this.views.one(viewerId, await this.findVisibleId(viewerId, postId));
  }

  // ---------------------------------------------------------------------------------------------
  // Edit and delete

  /** The caller's own, not deleted post locked FOR UPDATE, else 404 (whoever else asks). */
  private async lockOwn(tx: Tx, authorId: string, postId: string) {
    if (!isUuid(postId)) throw new AppException(ErrorCode.NOT_FOUND);
    const rows = await tx.$queryRaw<{ id: string }[]>`
      SELECT id::text AS id FROM posts
       WHERE id = ${postId.toLowerCase()}::uuid AND author_id = ${authorId}::uuid
         AND deleted_at IS NULL AND moderation <> 'REMOVED'::post_moderation
       FOR UPDATE`;
    if (rows.length === 0) throw new AppException(ErrorCode.NOT_FOUND);
    return tx.post.findUniqueOrThrow({
      where: { id: rows[0]!.id },
      include: { media: { select: { position: true } } },
    });
  }

  /** `PATCH /posts/{postId}` (author only). */
  async update(authorId: string, postId: string, body: unknown): Promise<PostDto> {
    const parsed = updatePostSchema.safeParse(body ?? {});
    if (!parsed.success) throw AppException.validation(zodErrorToDetails(parsed.error));
    const input: UpdatePostInput = parsed.data;
    const id = await this.prisma.$transaction(async (tx) => {
      if (!(await this.users.lockActiveById(tx, authorId)))
        throw new AppException(ErrorCode.AUTH_UNAUTHENTICATED);
      const post = await this.lockOwn(tx, authorId, postId);
      const nextStatus = input.status ?? post.status;
      const allowed: Record<string, readonly string[]> = {
        DRAFT: ['DRAFT', 'PUBLISHED', 'SCHEDULED'],
        SCHEDULED: ['SCHEDULED', 'DRAFT', 'PUBLISHED'],
        PUBLISHED: ['PUBLISHED'],
      };
      if (!allowed[post.status]!.includes(nextStatus)) {
        throw AppException.validation([{ field: 'status', issue: 'invalid_value' }]);
      }
      if (nextStatus === 'SCHEDULED') {
        this.checkSchedule('SCHEDULED', input.publishAt ?? post.publishAt?.toISOString());
      } else if (input.publishAt !== undefined) {
        throw AppException.validation([{ field: 'publishAt', issue: 'unknown_field' }]);
      }
      const text = input.text ?? post.text;
      if (text === '' && post.media.length === 0)
        throw AppException.validation([{ field: 'text', issue: 'required' }]);
      const now = new Date();
      const textChanged = input.text !== undefined && input.text !== post.text;
      await tx.post.update({
        where: { id: post.id },
        data: {
          text,
          ...(input.location !== undefined ? { location: input.location } : {}),
          status: nextStatus,
          publishAt:
            nextStatus === 'SCHEDULED' ? new Date(input.publishAt ?? post.publishAt!.toISOString()) : null,
          ...(nextStatus === 'PUBLISHED' && post.status !== 'PUBLISHED' ? { publishedAt: now } : {}),
          ...(textChanged && post.status === 'PUBLISHED' ? { editedAt: now } : {}),
          ...(input.settings?.commentsEnabled !== undefined
            ? { commentsEnabled: input.settings.commentsEnabled }
            : {}),
          ...(input.settings?.whoCanComment !== undefined
            ? { whoCanComment: input.settings.whoCanComment }
            : {}),
          ...(input.settings?.hideLikeCount !== undefined
            ? { hideLikeCount: input.settings.hideLikeCount }
            : {}),
        },
      });
      if (textChanged) await this.writeEntities(tx, post.id, authorId, text);
      if (nextStatus === 'PUBLISHED' && (textChanged || post.status !== 'PUBLISHED')) {
        await this.notifyMentions(tx, post.id, authorId);
      }
      return post.id;
    });
    return this.views.one(authorId, id);
  }

  /** `DELETE /posts/{postId}` (author only): soft delete; leaves every list at once. */
  async delete(authorId: string, postId: string): Promise<void> {
    await this.prisma.$transaction(async (tx) => {
      const post = await this.lockOwn(tx, authorId, postId);
      await tx.post.update({ where: { id: post.id }, data: { deletedAt: new Date() } });
      await tx.postPin.deleteMany({ where: { postId: post.id } });
    });
  }

  // ---------------------------------------------------------------------------------------------
  // Pins

  /** `PUT /posts/{postId}/pin`: the caller's published post; at most 3 (409). Idempotent. */
  async pin(authorId: string, postId: string): Promise<PostDto> {
    const id = await this.prisma.$transaction(async (tx) => {
      // Serializes the caller's pin changes, so two concurrent pins cannot make a fourth.
      await tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtext('kabso:pins'), hashtext(${authorId}::text))`;
      const post = await this.lockOwn(tx, authorId, postId);
      if (post.status !== 'PUBLISHED') throw new AppException(ErrorCode.NOT_FOUND);
      const already = await tx.postPin.findUnique({ where: { postId: post.id } });
      if (!already) {
        const count = await tx.postPin.count({ where: { userId: authorId, post: { deletedAt: null } } });
        if (count >= MAX_PINS) throw new AppException(ErrorCode.PIN_LIMIT_REACHED);
        await tx.postPin.create({ data: { postId: post.id, userId: authorId } });
      }
      return post.id;
    });
    return this.views.one(authorId, id);
  }

  /** `DELETE /posts/{postId}/pin`. Idempotent. */
  async unpin(authorId: string, postId: string): Promise<PostDto> {
    const id = await this.prisma.$transaction(async (tx) => {
      const post = await this.lockOwn(tx, authorId, postId);
      await tx.postPin.deleteMany({ where: { postId: post.id } });
      return post.id;
    });
    return this.views.one(authorId, id);
  }

  // ---------------------------------------------------------------------------------------------
  // Lists

  /** `GET /me/posts?status=DRAFT|SCHEDULED`: drafts newest first, scheduled soonest first. */
  async listMine(authorId: string, query: MyPostsQuery): Promise<PageDto<PostDto>> {
    const scope = `me-posts:${query.status}:${authorId}`;
    const after = this.decode(query.cursor, scope);
    const draft = query.status === 'DRAFT';
    const rows = await this.prisma.post.findMany({
      where: {
        authorId,
        deletedAt: null,
        status: query.status,
        ...(after
          ? draft
            ? { OR: [{ createdAt: { lt: after.at } }, { createdAt: after.at, id: { lt: after.id } }] }
            : { OR: [{ publishAt: { gt: after.at } }, { publishAt: after.at, id: { gt: after.id } }] }
          : {}),
      },
      orderBy: draft ? [{ createdAt: 'desc' }, { id: 'desc' }] : [{ publishAt: 'asc' }, { id: 'asc' }],
      take: query.limit + 1,
      select: { id: true, createdAt: true, publishAt: true },
    });
    return this.page(authorId, rows, query.limit, (r) =>
      this.cursors.encode(scope, { at: draft ? r.createdAt : r.publishAt!, id: r.id }),
    );
  }

  /**
   * Whether `viewerId` may see `username`'s posts: the profile exists and is ACTIVE, no block
   * either way, and the account is public or followed by the viewer (or is the viewer). Else 404.
   */
  async readableAuthor(viewerId: string, username: string): Promise<string> {
    const user = await this.users.findActivePublicUser(username);
    if (!user) throw new AppException(ErrorCode.NOT_FOUND);
    if (user.id === viewerId) return user.id;
    const [blocks, follows] = await Promise.all([
      this.prisma.userBlock.count({
        where: {
          OR: [
            { blockerId: viewerId, blockedId: user.id },
            { blockerId: user.id, blockedId: viewerId },
          ],
        },
      }),
      user.isPrivate ? this.prisma.follow.count({ where: { followerId: viewerId, followeeId: user.id } }) : 1,
    ]);
    if (blocks > 0 || follows === 0) throw new AppException(ErrorCode.NOT_FOUND);
    return user.id;
  }

  /**
   * `GET /users/{username}/posts`: pinned posts first (newest pin first, first page only), then
   * the other published posts newest first.
   */
  async listUserPosts(viewerId: string, username: string, query: PageQuery): Promise<PageDto<PostDto>> {
    const authorId = await this.readableAuthor(viewerId, username);
    const scope = `user-posts:${authorId}:${viewerId}`;
    const after = this.decode(query.cursor, scope);
    const visible: Prisma.PostWhereInput = { AND: [visiblePostWhere(viewerId), { authorId }] };
    let pinned: string[] = [];
    if (!after) {
      const pins = await this.prisma.postPin.findMany({
        where: { userId: authorId, post: visible },
        orderBy: { pinnedAt: 'desc' },
        take: MAX_PINS,
        select: { postId: true },
      });
      pinned = pins.map((p) => p.postId);
    }
    const rows = await this.prisma.post.findMany({
      where: {
        AND: [
          visible,
          { pin: { is: null } },
          after
            ? { OR: [{ publishedAt: { lt: after.at } }, { publishedAt: after.at, id: { lt: after.id } }] }
            : {},
        ],
      },
      orderBy: [{ publishedAt: 'desc' }, { id: 'desc' }],
      take: Math.max(query.limit - pinned.length, 1) + 1,
      select: { id: true, publishedAt: true },
    });
    const room = Math.max(query.limit - pinned.length, 1);
    const hasMore = rows.length > room;
    const pageRows = rows.slice(0, room);
    const last = pageRows[pageRows.length - 1];
    const data = await this.views.load(viewerId, [...pinned, ...pageRows.map((r) => r.id)]);
    return {
      data,
      page: {
        hasMore,
        nextCursor:
          hasMore && last ? this.cursors.encode(scope, { at: last.publishedAt!, id: last.id }) : null,
      },
    };
  }

  /** Decodes `cursor` for `scope`; a bad cursor is 400 `cursor` / `invalid_value`. */
  decode(cursor: string | undefined, scope: string) {
    if (cursor === undefined) return null;
    const position = this.cursors.decode(cursor, scope);
    if (!position) throw AppException.validation([{ field: 'cursor', issue: 'invalid_value' }]);
    return position;
  }

  /** One page from `limit + 1` rows (the extra row only says whether more exist). */
  async page<R extends { id: string }>(
    viewerId: string,
    rows: readonly R[],
    limit: number,
    cursorOf: (row: R) => string,
  ): Promise<PageDto<PostDto>> {
    const hasMore = rows.length > limit;
    const pageRows = rows.slice(0, limit);
    const last = pageRows[pageRows.length - 1];
    return {
      data: await this.views.load(
        viewerId,
        pageRows.map((r) => r.id),
      ),
      page: { hasMore, nextCursor: hasMore && last ? cursorOf(last) : null },
    };
  }

  // ---------------------------------------------------------------------------------------------
  // Scheduled publishing

  /**
   * Publishes every due scheduled post (publishedAt = its publishAt), telling each author
   * (POST_PUBLISHED) and the users it mentions in the same transaction. Returns how many.
   */
  async publishDue(now: Date = new Date()): Promise<number> {
    return this.prisma.$transaction(async (tx) => {
      const published = await tx.$queryRaw<{ id: string; author_id: string }[]>`
        UPDATE posts SET status = 'PUBLISHED'::post_status, published_at = publish_at, updated_at = now()
         WHERE id IN (SELECT id FROM posts
                       WHERE status = 'SCHEDULED'::post_status AND deleted_at IS NULL AND publish_at <= ${now}
                       ORDER BY publish_at LIMIT 500 FOR UPDATE SKIP LOCKED)
        RETURNING id::text AS id, author_id::text AS author_id`;
      for (const post of published) {
        await this.notifier.system(tx, {
          type: 'POST_PUBLISHED',
          recipientId: post.author_id,
          postId: post.id,
        });
        await this.notifyMentions(tx, post.id, post.author_id);
      }
      return published.length;
    });
  }

  private schedulePublisher(): void {
    this.publishTimer = setTimeout(() => {
      this.publishInFlight = this.publishDue()
        .then(() => undefined)
        .catch((err: unknown) => {
          this.logger.error({ error: safeErrorLog(err) }, 'Scheduled publishing failed');
        })
        .finally(() => {
          this.publishInFlight = null;
          this.schedulePublisher();
        });
    }, this.config.social.publishIntervalSeconds * 1000);
    this.publishTimer.unref();
  }
}
