import { Inject, Injectable, Logger, type OnModuleDestroy, type OnModuleInit } from '@nestjs/common';
import { AppException } from '../../common/errors/app-exception.js';
import { zodErrorToDetails } from '../../common/validation/zod-validation.pipe.js';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import type { NotificationType, Prisma } from '../../generated/prisma/client.js';
import { safeErrorLog } from '../../logging/redact-text.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import type { UserSummaryDto } from '../live/live-rooms.service.js';
import { MediaService } from '../media/media.service.js';
import { USER_SUMMARY_SELECT, userSummary, visiblePostWhere, type PageDto } from '../posts/post-views.js';
import type { PageQuery } from '../posts/posts.schemas.js';
import { SocialCursorCodec } from '../posts/social-cursor.js';
import { PushTokensService } from '../push/push-tokens.service.js';
import { visibleStoryWhere } from '../stories/stories.service.js';
import { markReadSchema, updateNotificationSettingsSchema } from './notifications.schemas.js';

/** `NotificationTarget` (openapi v1.5-social, CP-009). */
export interface NotificationTargetDto {
  type: 'POST' | 'COMMENT' | 'STORY' | 'USER' | 'FAMILY' | 'MEDAL' | 'PREMIUM_USERNAME';
  id: string;
  postId: string | null;
  thumbUrl: string | null;
  text: string | null;
  /** LIVE_SCHEDULED_SOON only (v1.14-live): the planned start. */
  startsAt?: string;
  /** v1.28-live (D146) PREMIUM_USERNAME only: the period's end (EXPIRING) or the grace's (EXPIRED). */
  endsAt?: string;
}

/** `Notification`. */
export interface NotificationDto {
  id: string;
  type: NotificationType;
  actors: UserSummaryDto[];
  actorCount: number;
  target: NotificationTargetDto | null;
  createdAt: string;
  read: boolean;
}

/** `NotificationSettings`. */
export interface NotificationSettingsDto {
  likes: boolean;
  comments: boolean;
  mentions: boolean;
  follows: boolean;
  reposts: boolean;
  /** v1.14-live (CP-016 C): reminders of lives scheduled by hosts you follow. */
  lives: boolean;
  /** v1.30-live (D152): pushes of new family chat messages. */
  messages: boolean;
}

/** Retention (owner, D92): latest activity older than this is deleted. */
export const NOTIFICATION_RETENTION_MS = 30 * 24 * 3600_000;
/** The badge shows "99+" (§11.10). */
const MAX_UNREAD = 99;
const MAX_ACTORS = 3;
const EXCERPT = 80;
const SWEEP_BATCH = 5000;
const DEFAULT_SETTINGS: NotificationSettingsDto = {
  likes: true,
  comments: true,
  mentions: true,
  follows: true,
  reposts: true,
  lives: true,
  messages: true,
};
const ACTOR_TYPES: NotificationType[] = [
  'LIKE_POST',
  'LIKE_COMMENT',
  'COMMENT',
  'REPLY',
  'MENTION',
  'FOLLOW',
  'REPOST',
  // CP-016 C: actor the host; target the scheduled live (no post, comment or story).
  'LIVE_SCHEDULED_SOON',
  // v1.21-live (CP-018): actor the other person (CP) or the leader / deputy who answered (family).
  'CP_REQUEST',
  'CP_ACCEPTED',
  'FAMILY_JOIN_ACCEPTED',
  'FAMILY_JOIN_DECLINED',
  // v1.47-social (D175): actor the requester / the private account that accepted.
  'FOLLOW_REQUEST',
  'FOLLOW_REQUEST_ACCEPTED',
];
/** v1.21-live (CP-018): the actor types whose target is the actor (USER), like FOLLOW. */
const USER_TARGET_TYPES: ReadonlySet<NotificationType> = new Set([
  'FOLLOW',
  'CP_REQUEST',
  'CP_ACCEPTED',
  // v1.47-social (D175).
  'FOLLOW_REQUEST',
  'FOLLOW_REQUEST_ACCEPTED',
]);

/** Actors the recipient may see: ACTIVE, no block either way, not muted by the recipient (§11.10). */
function visibleActorWhere(me: string): Prisma.NotificationActorWhereInput {
  return {
    actor: {
      status: 'ACTIVE',
      blocking: { none: { blockedId: me } },
      blockedBy: { none: { blockerId: me } },
      mutedBy: { none: { muterId: me } },
    },
  };
}

/**
 * The caller's notifications that may be shown: system `CONTENT_REMOVED` always; `POST_PUBLISHED`
 * while the post is still there; actor types with at least one visible actor and a live target
 * the caller may see (a removed or deleted post, comment or story drops its notifications).
 */
function visibleNotificationWhere(me: string): Prisma.NotificationWhereInput {
  return {
    recipientId: me,
    OR: [
      { type: 'CONTENT_REMOVED' },
      // v1.21-live (CP-018): a medal the caller earned (system, no actor).
      { type: 'MEDAL_AWARDED' },
      // v1.28-live (D146): the caller's premium username ends soon / ended (system, no actor).
      { type: { in: ['PREMIUM_USERNAME_EXPIRING', 'PREMIUM_USERNAME_EXPIRED'] } },
      // v1.47-social (D175): a moderator removed the caller's profile photo (system, no target).
      { type: 'AVATAR_REMOVED' },
      { type: 'POST_PUBLISHED', post: visiblePostWhere(me) },
      {
        type: { in: ACTOR_TYPES },
        actors: { some: visibleActorWhere(me) },
        OR: [
          { postId: null, commentId: null, storyId: null },
          { commentId: null, postId: { not: null }, post: visiblePostWhere(me) },
          { commentId: { not: null }, comment: { deletedAt: null, post: visiblePostWhere(me) } },
          { storyId: { not: null }, story: visibleStoryWhere(me) },
        ],
      },
    ],
  };
}

function include(me: string) {
  return {
    actors: {
      where: visibleActorWhere(me),
      orderBy: [{ createdAt: 'desc' }, { actorId: 'desc' }],
      take: MAX_ACTORS,
      include: { actor: { select: USER_SUMMARY_SELECT } },
    },
    _count: { select: { actors: { where: visibleActorWhere(me) } } },
    post: {
      select: {
        text: true,
        media: { orderBy: { position: 'asc' }, take: 1, include: { mediaAsset: true } },
      },
    },
    comment: { select: { text: true } },
    story: { select: { text: true, mediaAsset: true } },
    liveSchedule: { select: { title: true, startsAt: true } },
    family: { select: { name: true } },
    premiumLease: { select: { username: true, expiresAt: true, graceUntil: true } },
  } satisfies Prisma.NotificationInclude;
}
type NotificationRow = Prisma.NotificationGetPayload<{ include: ReturnType<typeof include> }>;

/** A one-line excerpt of at most 80 code points; null when empty. */
export function excerpt(text: string | null | undefined): string | null {
  const flat = (text ?? '').replace(/\s+/gu, ' ').trim();
  if (flat === '') return null;
  const points = [...flat];
  return points.length <= EXCERPT
    ? flat
    : `${points
        .slice(0, EXCERPT - 1)
        .join('')
        .trimEnd()}…`;
}

/**
 * In-app notifications (CP-009, CONVENTIONS §11.10): the inbox, the unread count, mark read,
 * per-type settings and the 30-day retention sweeper. Writes go through {@link Notifier}.
 */
@Injectable()
export class NotificationsService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(NotificationsService.name);
  private readonly cursors: SocialCursorCodec;
  private sweepTimer: NodeJS.Timeout | undefined;
  private sweepInFlight: Promise<void> | null = null;

  constructor(
    private readonly prisma: PrismaService,
    private readonly media: MediaService,
    private readonly pushTokens: PushTokensService,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
  ) {
    this.cursors = new SocialCursorCodec(config.social.cursorKey);
  }

  onModuleInit(): void {
    if (this.config.social.notificationsSweepIntervalSeconds > 0) this.scheduleSweep();
  }

  async onModuleDestroy(): Promise<void> {
    if (this.sweepTimer) clearTimeout(this.sweepTimer);
    await this.sweepInFlight?.catch(() => undefined);
  }

  toDto(row: NotificationRow): NotificationDto {
    const actors = row.actors.map((a) => userSummary(a.actor));
    return {
      id: row.id,
      type: row.type,
      actors,
      actorCount: row._count.actors,
      target: this.target(row, actors),
      createdAt: row.updatedAt.toISOString(),
      read: row.readAt !== null,
    };
  }

  private target(row: NotificationRow, actors: UserSummaryDto[]): NotificationTargetDto | null {
    const removed = row.type === 'CONTENT_REMOVED';
    if (row.commentId !== null) {
      return {
        type: 'COMMENT',
        id: row.commentId,
        postId: row.postId,
        thumbUrl: null,
        text: removed ? null : excerpt(row.comment?.text),
      };
    }
    if (row.storyId !== null) {
      const asset = row.story?.mediaAsset;
      return {
        type: 'STORY',
        id: row.storyId,
        postId: null,
        thumbUrl: !removed && asset ? this.media.toDto(asset).thumbUrl : null,
        text: removed ? null : excerpt(row.story?.text),
      };
    }
    if (row.postId !== null) {
      const asset = row.post?.media[0]?.mediaAsset;
      return {
        type: 'POST',
        id: row.postId,
        postId: null,
        thumbUrl: !removed && asset ? this.media.toDto(asset).thumbUrl : null,
        text: removed ? null : excerpt(row.post?.text),
      };
    }
    // CP-016 C: the host as a USER target (older apps know it), with the slot's title and start.
    const host = actors[0];
    if (row.liveSchedule && host) {
      return {
        type: 'USER',
        id: host.username,
        postId: null,
        thumbUrl: null,
        text: excerpt(row.liveSchedule.title),
        startsAt: row.liveSchedule.startsAt.toISOString(),
      };
    }
    // v1.21-live (CP-018): the family that answered a join request, with its name.
    if (row.familyId !== null) {
      return {
        type: 'FAMILY',
        id: row.familyId,
        postId: null,
        thumbUrl: null,
        text: excerpt(row.family?.name),
      };
    }
    // v1.21-live (CP-018): the medal earned (the app reads its name and icon from GET /medals).
    // v1.28-live (D146): the premium username whose period ends soon or ended.
    if (row.premiumLease) {
      const end =
        row.type === 'PREMIUM_USERNAME_EXPIRED' ? row.premiumLease.graceUntil : row.premiumLease.expiresAt;
      return {
        type: 'PREMIUM_USERNAME',
        id: row.premiumLease.username,
        postId: null,
        thumbUrl: null,
        text: null,
        ...(end ? { endsAt: end.toISOString() } : {}),
      };
    }
    if (row.medalCode !== null) {
      return { type: 'MEDAL', id: row.medalCode, postId: null, thumbUrl: null, text: null };
    }
    const follower = actors[0];
    return USER_TARGET_TYPES.has(row.type) && follower
      ? { type: 'USER', id: follower.username, postId: null, thumbUrl: null, text: null }
      : null;
  }

  // ---------------------------------------------------------------------------------------------
  // Inbox

  /** `GET /notifications`: newest activity first (a group moves up with each new actor). */
  async list(me: string, query: PageQuery): Promise<PageDto<NotificationDto>> {
    const scope = `notifications:${me}`;
    let after = null;
    if (query.cursor !== undefined) {
      after = this.cursors.decode(query.cursor, scope);
      if (!after) throw AppException.validation([{ field: 'cursor', issue: 'invalid_value' }]);
    }
    const rows = await this.prisma.notification.findMany({
      where: {
        AND: [
          visibleNotificationWhere(me),
          after
            ? { OR: [{ updatedAt: { lt: after.at } }, { updatedAt: after.at, id: { lt: after.id } }] }
            : {},
        ],
      },
      orderBy: [{ updatedAt: 'desc' }, { id: 'desc' }],
      take: query.limit + 1,
      include: include(me),
    });
    const hasMore = rows.length > query.limit;
    const pageRows = rows.slice(0, query.limit);
    const last = pageRows[pageRows.length - 1];
    return {
      data: pageRows.map((r) => this.toDto(r)),
      page: {
        hasMore,
        nextCursor: hasMore && last ? this.cursors.encode(scope, { at: last.updatedAt, id: last.id }) : null,
      },
    };
  }

  /**
   * D152: one notification of `me` as the inbox would show it, or null when it is not visible
   * (§11.10: blocks, mutes, inactive actors, removed targets). The push dispatcher's check.
   */
  async visible(me: string, id: string): Promise<NotificationDto | null> {
    const row = await this.prisma.notification.findFirst({
      where: { AND: [visibleNotificationWhere(me), { id }] },
      include: include(me),
    });
    return row ? this.toDto(row) : null;
  }

  /** `GET /notifications/unread-count`: visible unread notifications, capped at 99. */
  async unreadCount(me: string): Promise<{ count: number }> {
    const count = await this.prisma.notification.count({
      where: { AND: [visibleNotificationWhere(me), { readAt: null }] },
      take: MAX_UNREAD,
    });
    return { count: Math.min(count, MAX_UNREAD) };
  }

  /** `POST /notifications/read`: the caller's own `ids` (others are ignored) or `all`; idempotent. */
  async markRead(me: string, body: unknown): Promise<void> {
    const parsed = markReadSchema.safeParse(body ?? {});
    if (!parsed.success) throw AppException.validation(zodErrorToDetails(parsed.error));
    const now = new Date();
    await this.prisma.notification.updateMany({
      where: {
        recipientId: me,
        readAt: null,
        ...('ids' in parsed.data ? { id: { in: parsed.data.ids.map((i) => i.toLowerCase()) } } : {}),
      },
      data: { readAt: now },
    });
  }

  // ---------------------------------------------------------------------------------------------
  // Settings

  /** `GET /me/notification-settings` (all on until the first change). */
  async settings(me: string): Promise<NotificationSettingsDto> {
    const row = await this.prisma.notificationSettings.findUnique({ where: { userId: me } });
    return row ? pickSettings(row) : { ...DEFAULT_SETTINGS };
  }

  /** `PATCH /me/notification-settings`. */
  async updateSettings(me: string, body: unknown): Promise<NotificationSettingsDto> {
    const parsed = updateNotificationSettingsSchema.safeParse(body ?? {});
    if (!parsed.success) throw AppException.validation(zodErrorToDetails(parsed.error));
    const row = await this.prisma.notificationSettings.upsert({
      where: { userId: me },
      create: { userId: me, ...parsed.data },
      update: parsed.data,
    });
    return pickSettings(row);
  }

  // ---------------------------------------------------------------------------------------------
  // Retention

  /** Deletes notifications whose latest activity is older than 30 days (in batches). Returns how many. */
  async sweep(now: Date = new Date()): Promise<number> {
    const cutoff = new Date(now.getTime() - NOTIFICATION_RETENTION_MS);
    let total = 0;
    for (;;) {
      const n = await this.prisma.$executeRaw`
        DELETE FROM notifications
         WHERE id IN (SELECT id FROM notifications WHERE updated_at < ${cutoff} LIMIT ${SWEEP_BATCH})`;
      total += n;
      if (n < SWEEP_BATCH) return total;
    }
  }

  private scheduleSweep(): void {
    this.sweepTimer = setTimeout(() => {
      this.sweepInFlight = this.sweep()
        // D152: push tokens of ended sessions and tokens unseen for 60 days, on the same timer.
        .then(() => this.pushTokens.sweep())
        .then(() => undefined)
        .catch((err: unknown) => {
          this.logger.error({ error: safeErrorLog(err) }, 'Notifications sweep failed');
        })
        .finally(() => {
          this.sweepInFlight = null;
          this.scheduleSweep();
        });
    }, this.config.social.notificationsSweepIntervalSeconds * 1000);
    this.sweepTimer.unref();
  }
}

function pickSettings(row: NotificationSettingsDto): NotificationSettingsDto {
  return {
    likes: row.likes,
    comments: row.comments,
    mentions: row.mentions,
    follows: row.follows,
    reposts: row.reposts,
    lives: row.lives,
    messages: row.messages,
  };
}
