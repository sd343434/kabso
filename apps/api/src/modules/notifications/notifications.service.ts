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
import { AGENCY_NOTIFICATION_TYPES } from './notifier.js';

/** `NotificationTarget` (openapi v1.5-social, CP-009). */
export interface NotificationTargetDto {
  type:
    | 'POST'
    | 'COMMENT'
    | 'STORY'
    | 'USER'
    | 'FAMILY'
    | 'MEDAL'
    | 'PREMIUM_USERNAME'
    | 'BAG_ITEM'
    | 'RECHARGE_SALE'
    | 'RECHARGE_ORDER'
    | 'AGENCY'
    | 'ACCOUNT_RESTRICTION'
    | 'BALANCE_ADJUSTMENT'
    | 'LIVE_MODERATION'
    | 'LIVE_ROOM'
    | 'REPORT';
  id: string;
  postId: string | null;
  thumbUrl: string | null;
  text: string | null;
  /** LIVE_SCHEDULED_SOON only (v1.14-live): the planned start. */
  startsAt?: string;
  /** v1.28-live (D146) PREMIUM_USERNAME only: the period's end (EXPIRING) or the grace's (EXPIRED). */
  endsAt?: string;
  /** v1.48-social (D171) BAG_ITEM only: the item's category. */
  bagCategory?: string;
  /** v1.54-social (D185) RECHARGE_SALE only: the coins bought. v1.69-social (D204) RECHARGE_ORDER: the order's coins. */
  coins?: number;
  /** v1.69-social (D204) RECHARGE_ORDER only: the latest event (`CREATED`, `DETAILS_SENT`, `PAID`, …) and the status. */
  orderEvent?: string;
  orderStatus?: string;
  /** v1.70-social (D206) AGENCY only: the activated hosts reached and the hosts needed (probation types). */
  activatedHosts?: number;
  requiredHosts?: number;
  /** v1.72-social (D208) ACCOUNT_RESTRICTION only: what was switched off (LOCK, CHAT_MUTE …); `endsAt` its end. */
  restriction?: string;
  /** v1.72-social (D208) BALANCE_ADJUSTMENT only: COINS or CHERRIES and the signed amount. */
  currency?: 'COINS' | 'CHERRIES';
  amount?: number;
  /**
   * v1.60-live (D250) LIVE_MODERATION only: what the team did (END, NO_LIVE, SUSPEND, DEVICE_BAN), the full reason
   * (`text` is its excerpt), `endsAt` the ban's end (absent when it is permanent: `permanent` true) and the live.
   */
  moderation?: 'END' | 'WARN' | 'NO_LIVE' | 'SUSPEND' | 'DEVICE_BAN';
  reason?: string;
  permanent?: boolean;
  roomId?: string;
  /** v1.68-live (D273) LIVE_ROOM only (LIVE_STAFF_REPORT): the live is still on air (`text` is the host's name). */
  live?: boolean;
  /**
   * v1.78-live (D288) REPORT only (STAFF_REPORT_NEW): what the newest report is about (POST, USER, LIVE_ROOM …) and
   * whether it is still open. Never the reporter, the reason or the note.
   */
  reportTargetType?: string;
  reportOpen?: boolean;
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
  // v1.48-social (D171): actor the sender; target the bag item (no post, comment or story).
  'BAG_ITEM_RECEIVED',
  // v1.47-social (D175): actor the requester / the private account that accepted.
  'FOLLOW_REQUEST',
  'FOLLOW_REQUEST_ACCEPTED',
  // v1.54-social (D185): actor the seller (target the sale) / the host or agent who asked (no target).
  'RECHARGE_COINS_RECEIVED',
  'RECHARGE_CHERRY_REQUEST',
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
      // v1.76-social (D218): a moderator removed the caller's profile cover (system, no target).
      { type: 'COVER_REMOVED' },
      // v1.60-social (D191): a moderator warned the caller (system; the post or comment when there is one).
      { type: 'MODERATION_WARNING' },
      // v1.66-social (D198): the caller's data export is ready (system, no target).
      { type: 'DATA_EXPORT_READY' },
      // v1.69-social (D204): a recharge order the caller takes part in (system; the order is the target).
      { type: 'RECHARGE_ORDER_UPDATE', rechargeOrderId: { not: null } },
      // v1.70-social (D206): the caller's agency (owner) or the agency that released the caller (system).
      { type: { in: [...AGENCY_NOTIFICATION_TYPES] } },
      // v1.72-social (D208): the team's lock / restriction, its early end, a balance adjustment, a profile edit.
      {
        type: {
          in: [
            'ACCOUNT_RESTRICTED',
            'ACCOUNT_RESTRICTION_LIFTED',
            'BALANCE_ADJUSTED',
            'PROFILE_EDITED_BY_TEAM',
          ],
        },
      },
      // v1.73-social (D209): the caller's application «كن مضيفاً مع الإدارة» was decided (system, no target).
      { type: { in: ['HOST_APPLICATION_APPROVED', 'HOST_APPLICATION_REJECTED'] } },
      // v1.74-social (D217): the team voided a referral and took its credited cherries back (system, no target).
      { type: 'REFERRAL_REWARD_REVERSED' },
      // v1.60-live (D250): the team acted on the caller's live from the panel (system; the action is the target).
      { type: 'LIVE_MODERATED', liveModerationId: { not: null } },
      // v1.68-live (D273): a report on a live the caller looks after as «فريق كابسو» (system; the live is the target).
      { type: 'LIVE_STAFF_REPORT', liveRoomId: { not: null } },
      // v1.78-live (D288): a new report in the shared queue (system; the newest report is the target).
      { type: 'STAFF_REPORT_NEW', reportId: { not: null } },
      // v1.80-kyc (D227): the identity check's result (system, no target).
      { type: { in: ['KYC_APPROVED', 'KYC_DECLINED', 'KYC_IN_REVIEW'] } },
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
    bagItem: { select: { category: true } },
    rechargeSale: { select: { coins: true } },
    rechargeOrder: { select: { coins: true, status: true } },
    agency: { select: { name: true } },
    accountRestriction: { select: { kind: true, endsAt: true, reason: true } },
    balanceAdjustment: { select: { currency: true, delta: true } },
    liveModeration: { select: { kind: true, reason: true, endsAt: true, roomId: true } },
    liveRoom: {
      select: {
        id: true,
        status: true,
        host: { select: { profile: { select: { displayName: true, avatarUrl: true } } } },
      },
    },
    report: { select: { id: true, targetType: true, status: true } },
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
    // v1.48-social (D171): the bag item someone sent (the app opens the bag).
    if (row.bagItemCode !== null && row.bagItem) {
      return {
        type: 'BAG_ITEM',
        id: row.bagItemCode,
        postId: null,
        thumbUrl: null,
        text: null,
        bagCategory: row.bagItem.category,
      };
    }
    // v1.54-social (D185): coins bought from a recharge agent (the app opens the wallet).
    if (row.rechargeSaleId !== null && row.rechargeSale) {
      return {
        type: 'RECHARGE_SALE',
        id: row.rechargeSaleId,
        postId: null,
        thumbUrl: null,
        text: null,
        coins: Number(row.rechargeSale.coins),
      };
    }
    // v1.69-social (D204): a recharge order the person takes part in (the app opens the order's chat).
    if (row.rechargeOrderId !== null && row.rechargeOrder) {
      return {
        type: 'RECHARGE_ORDER',
        id: row.rechargeOrderId,
        postId: null,
        thumbUrl: null,
        text: null,
        coins: Number(row.rechargeOrder.coins),
        orderEvent: row.rechargeOrderEvent ?? 'UPDATED',
        orderStatus: row.rechargeOrder.status,
      };
    }
    // v1.70-social (D206): the agency (the app opens «الوكالة»), its name and the probation's numbers.
    if (row.agencyId !== null) {
      return {
        type: 'AGENCY',
        id: row.agencyId,
        postId: null,
        thumbUrl: null,
        text: excerpt(row.agency?.name),
        ...(row.agencyActivated !== null ? { activatedHosts: row.agencyActivated } : {}),
        ...(row.agencyRequired !== null ? { requiredHosts: row.agencyRequired } : {}),
      };
    }
    // v1.72-social (D208): the team's lock or restriction (its end and reason) and a balance adjustment.
    if (row.accountRestrictionId !== null && row.accountRestriction) {
      return {
        type: 'ACCOUNT_RESTRICTION',
        id: row.accountRestrictionId,
        postId: null,
        thumbUrl: null,
        text: excerpt(row.accountRestriction.reason),
        restriction: row.accountRestriction.kind,
        endsAt: row.accountRestriction.endsAt.toISOString(),
      };
    }
    // v1.78-live (D288): the newest report of the shared queue — its kind and whether it is open, nothing else.
    if (row.reportId !== null && row.report) {
      return {
        type: 'REPORT',
        id: row.report.id,
        postId: null,
        thumbUrl: null,
        text: null,
        reportTargetType: row.report.targetType,
        reportOpen: row.report.status === 'OPEN',
      };
    }
    // v1.68-live (D273): the live a staff member is alerted about — the host's name and picture only.
    if (row.liveRoomId !== null && row.liveRoom) {
      return {
        type: 'LIVE_ROOM',
        id: row.liveRoom.id,
        postId: null,
        thumbUrl: row.liveRoom.host.profile?.avatarUrl ?? null,
        text: excerpt(row.liveRoom.host.profile?.displayName ?? null),
        roomId: row.liveRoom.id,
        live: row.liveRoom.status === 'LIVE',
      };
    }
    // v1.60-live (D250): the team's action on the live, with the reason and the ban's end.
    if (row.liveModerationId !== null && row.liveModeration && row.liveModeration.kind !== 'DISMISS') {
      const m = row.liveModeration;
      const timed = m.kind !== 'END' && m.kind !== 'WARN';
      return {
        type: 'LIVE_MODERATION',
        id: row.liveModerationId,
        postId: null,
        thumbUrl: null,
        text: excerpt(m.reason),
        moderation: m.kind as 'END' | 'WARN' | 'NO_LIVE' | 'SUSPEND' | 'DEVICE_BAN',
        reason: m.reason,
        roomId: m.roomId,
        ...(m.endsAt ? { endsAt: m.endsAt.toISOString() } : {}),
        ...(timed && m.endsAt === null ? { permanent: true } : {}),
      };
    }
    if (row.balanceAdjustmentId !== null && row.balanceAdjustment) {
      return {
        type: 'BALANCE_ADJUSTMENT',
        id: row.balanceAdjustmentId,
        postId: null,
        thumbUrl: null,
        text: null,
        currency: row.balanceAdjustment.currency === 'CHERRIES' ? 'CHERRIES' : 'COINS',
        amount: Number(row.balanceAdjustment.delta),
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
