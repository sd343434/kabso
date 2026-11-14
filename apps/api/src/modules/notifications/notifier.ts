import { Injectable } from '@nestjs/common';
import type { NotificationType, Prisma } from '../../generated/prisma/client.js';

type Tx = Prisma.TransactionClient;

/** What a notification points at (CONVENTIONS §11.10): one of post / comment (+ its post) / story. */
export interface NotificationTargetRef {
  readonly postId?: string;
  readonly commentId?: string;
  readonly storyId?: string;
  /** v1.21-live (CP-018): the family of FAMILY_JOIN_ACCEPTED / FAMILY_JOIN_DECLINED. */
  readonly familyId?: string;
  /** v1.28-live (D146): the premium username lease of PREMIUM_USERNAME_EXPIRING / _EXPIRED. */
  readonly premiumLeaseId?: string;
  /** v1.48-social (D171): the bag item of BAG_ITEM_RECEIVED. */
  readonly bagItemCode?: string;
  /** v1.54-social (D185): the sale of RECHARGE_COINS_RECEIVED. */
  readonly rechargeSaleId?: string;
}
// v1.69-social (D204): RECHARGE_ORDER_UPDATE rows are written by `recharge-order-core.notifyOrderIn` (one unread row
// per order and recipient, the latest event in `recharge_order_event`).

/** v1.70-social (D206, §10.65): the agency's system notifications (target AGENCY). */
export const AGENCY_NOTIFICATION_TYPES = [
  'AGENCY_OPENED',
  'AGENCY_PROBATION_REMINDER',
  'AGENCY_PROBATION_PASSED',
  'AGENCY_CLOSED',
  'AGENCY_HOST_RELEASED',
] as const satisfies readonly NotificationType[];
export type AgencyNotificationType = (typeof AGENCY_NOTIFICATION_TYPES)[number];

/** Types without an actor: always on, never grouped, never hidden with their target. */
export const SYSTEM_TYPES: readonly NotificationType[] = [
  'POST_PUBLISHED',
  'CONTENT_REMOVED',
  'PREMIUM_USERNAME_EXPIRING',
  'PREMIUM_USERNAME_EXPIRED',
  // v1.47-social (D175): a moderator removed the profile photo.
  'AVATAR_REMOVED',
  // v1.76-social (D218): a moderator removed the profile cover.
  'COVER_REMOVED',
  // v1.136-social (D384): a moderator removed the VIP animated picture.
  'ANIMATED_AVATAR_REMOVED',
  // v1.138-social (D386): the team verified / otherwise reviewed the account category (no target).
  'CATEGORY_VERIFIED',
  'CATEGORY_REVIEWED',
  // v1.60-social (D191): a moderator warned the person (from the panel's report queue).
  'MODERATION_WARNING',
  // v1.66-social (D198): the data export «تنزيل بياناتي» is ready.
  'DATA_EXPORT_READY',
  // v1.69-social (D204): a recharge order changed or got a message (`recharge-order-core.notifyOrderIn`).
  'RECHARGE_ORDER_UPDATE',
  // v1.70-social (D206): «افتح وكالة» — opened, probation reminder / passed, closed, a host released.
  ...AGENCY_NOTIFICATION_TYPES,
  // v1.72-social (D208): the team's account controls.
  'ACCOUNT_RESTRICTED',
  'ACCOUNT_RESTRICTION_LIFTED',
  'BALANCE_ADJUSTED',
  'PROFILE_EDITED_BY_TEAM',
  // v1.73-social (D209): «كن مضيفاً مع الإدارة» — the team approved / rejected the application (no target).
  'HOST_APPLICATION_APPROVED',
  'HOST_APPLICATION_REJECTED',
  // v1.74-social (D217): the team voided a referral and took its credited cherries back (no target).
  'REFERRAL_REWARD_REVERSED',
  // v1.80-kyc (D227): the identity check «تأكيد الهوية» was approved / declined / sent to review (no target).
  'KYC_APPROVED',
  'KYC_DECLINED',
  'KYC_IN_REVIEW',
  // v1.60-live (D250): the team acted on the person's live from the panel (target the action, with the reason).
  'LIVE_MODERATED',
  // v1.68-live (D273): a report on a live the staff member looks after (target the live).
  'LIVE_STAFF_REPORT',
  // v1.78-live (D288): a new report in the shared queue (target the report).
  'STAFF_REPORT_NEW',
  // v1.89-social (D290): a level-raise request decided (to the staff member) / the supporter's level raised.
  'LEVEL_RAISE_APPROVED',
  'LEVEL_RAISE_REJECTED',
  'LEVEL_RAISED',
  // v1.95-social (D301): a new item in «صندوق المؤسس» (to the app owners only; target the item).
  'OWNER_FEEDBACK_NEW',
  // D301 follow-up: the app owner's official announcement, to everyone (a background fan-out).
  'OWNER_ANNOUNCEMENT',
  // v1.97-social (D303): a prize of an event board was paid (target the event).
  'EVENT_PRIZE_WON',
  // v1.101-social (D325): an event for the person's audience started (target the event).
  'EVENT_STARTED',
  // v1.141-social (D390): «برنامج سفراء Kabso» — the application decided, a level up, a monthly reward (no target).
  'AMBASSADOR_APPLICATION_APPROVED',
  'AMBASSADOR_APPLICATION_REJECTED',
  'AMBASSADOR_LEVEL_UP',
  'AMBASSADOR_REWARD_GRANTED',
  'AMBASSADOR_MEMBERSHIP_ENDED',
];

/** Types that join one unread row per target (owner, D92). */
const GROUPED: ReadonlySet<NotificationType> = new Set([
  'LIKE_POST',
  'LIKE_COMMENT',
  'REPOST',
  // v1.127-social (D372, §10.164): «أرسل لك فلان هدية» — one unread row per post; new senders join it. Always on.
  'CONTENT_GIFT_RECEIVED',
]);

/** The settings switch of each actor type (`notification_settings`). */
const SETTING: Readonly<
  Partial<Record<NotificationType, 'likes' | 'comments' | 'mentions' | 'follows' | 'reposts'>>
> = {
  LIKE_POST: 'likes',
  LIKE_COMMENT: 'likes',
  COMMENT: 'comments',
  REPLY: 'comments',
  MENTION: 'mentions',
  FOLLOW: 'follows',
  // v1.47-social (D175): follow requests and their acceptance follow the `follows` switch.
  FOLLOW_REQUEST: 'follows',
  FOLLOW_REQUEST_ACCEPTED: 'follows',
  REPOST: 'reposts',
};

function targetWhere(target: NotificationTargetRef): {
  postId: string | null;
  commentId: string | null;
  storyId: string | null;
} {
  return {
    postId: target.postId ?? null,
    commentId: target.commentId ?? null,
    storyId: target.storyId ?? null,
  };
}

/**
 * Writes in-app notifications (CP-009, CONVENTIONS §11.10) inside the caller's transaction, so a
 * notification exists exactly when its action does. Never to yourself; never across a block
 * either way, from an account the recipient muted (D92), to an account that is not ACTIVE, or for
 * a type the recipient switched off. Likes and reposts on one target join the recipient's unread
 * row for it (serialized by an advisory lock); a mention notifies once per item.
 */
@Injectable()
export class Notifier {
  /** Records that `actorId` did `type` to `recipientId`'s `target`. */
  async notify(
    tx: Tx,
    input: { type: NotificationType; recipientId: string; actorId: string } & NotificationTargetRef,
  ): Promise<void> {
    const { type, recipientId, actorId } = input;
    if (recipientId === actorId) return;
    const [allowed] = await tx.$queryRaw<{ ok: boolean }[]>`
      SELECT EXISTS (SELECT 1 FROM users WHERE id = ${recipientId}::uuid AND status = 'ACTIVE'::user_status)
         AND NOT EXISTS (SELECT 1 FROM user_blocks b
                          WHERE (b.blocker_id = ${recipientId}::uuid AND b.blocked_id = ${actorId}::uuid)
                             OR (b.blocker_id = ${actorId}::uuid AND b.blocked_id = ${recipientId}::uuid))
         AND NOT EXISTS (SELECT 1 FROM user_mutes m
                          WHERE m.muter_id = ${recipientId}::uuid AND m.muted_id = ${actorId}::uuid) AS ok`;
    if (!allowed?.ok) return;
    const setting = SETTING[type];
    if (setting) {
      const prefs = await tx.notificationSettings.findUnique({ where: { userId: recipientId } });
      if (prefs && !prefs[setting]) return;
    }
    const target = targetWhere(input);
    const now = new Date();
    if (GROUPED.has(type)) {
      const key = `${type}:${input.commentId ?? input.postId ?? input.storyId ?? ''}`;
      await tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtext('kabso:notif'), hashtext(${`${recipientId}:${key}`}))`;
      const open = await tx.notification.findFirst({
        where: { recipientId, groupKey: key, readAt: null },
        select: { id: true },
      });
      if (open) {
        await tx.notificationActor.createMany({
          data: [{ notificationId: open.id, actorId, createdAt: now }],
          skipDuplicates: true,
        });
        await tx.notification.update({ where: { id: open.id }, data: { updatedAt: now } });
        return;
      }
      await tx.notification.create({
        data: {
          recipientId,
          type,
          ...target,
          groupKey: key,
          createdAt: now,
          updatedAt: now,
          actors: { create: [{ actorId, createdAt: now }] },
        },
      });
      return;
    }
    if (type === 'MENTION') {
      const seen = await tx.notification.count({ where: { recipientId, type, ...target } });
      if (seen > 0) return;
    }
    await tx.notification.create({
      data: {
        recipientId,
        type,
        ...target,
        familyId: input.familyId ?? null,
        bagItemCode: input.bagItemCode ?? null,
        rechargeSaleId: input.rechargeSaleId ?? null,
        createdAt: now,
        updatedAt: now,
        actors: { create: [{ actorId, createdAt: now }] },
      },
    });
  }

  /** Takes `actorId`'s part out of `type` on `target` (unlike, un-repost, unfollow); empty rows go. */
  async undo(
    tx: Tx,
    input: { type: NotificationType; recipientId: string; actorId: string } & NotificationTargetRef,
  ): Promise<void> {
    const rows = await tx.notification.findMany({
      where: {
        recipientId: input.recipientId,
        type: input.type,
        ...targetWhere(input),
        actors: { some: { actorId: input.actorId } },
      },
      select: { id: true },
    });
    if (rows.length === 0) return;
    const ids = rows.map((r) => r.id);
    await tx.notificationActor.deleteMany({ where: { notificationId: { in: ids }, actorId: input.actorId } });
    await tx.notification.deleteMany({ where: { id: { in: ids }, actors: { none: {} } } });
  }

  /** A system notification (no actor): a scheduled post went live, or content was removed. */
  async system(
    tx: Tx,
    input: {
      type:
        | 'POST_PUBLISHED'
        | 'CONTENT_REMOVED'
        | 'PREMIUM_USERNAME_EXPIRING'
        | 'PREMIUM_USERNAME_EXPIRED'
        | 'AVATAR_REMOVED'
        | 'COVER_REMOVED'
        // v1.136-social (D384): a moderator removed the VIP animated picture (no target).
        | 'ANIMATED_AVATAR_REMOVED'
        // v1.138-social (D386, §10.175.5): the team verified / otherwise reviewed the category (no target).
        | 'CATEGORY_VERIFIED'
        | 'CATEGORY_REVIEWED'
        | 'MODERATION_WARNING'
        | 'DATA_EXPORT_READY'
        // v1.72-social (D208): the team edited the profile (no target).
        | 'PROFILE_EDITED_BY_TEAM'
        | 'HOST_APPLICATION_APPROVED'
        | 'HOST_APPLICATION_REJECTED'
        | 'REFERRAL_REWARD_REVERSED'
        | 'KYC_APPROVED'
        | 'KYC_DECLINED'
        | 'KYC_IN_REVIEW'
        // v1.141-social (D390, §10.179.9): the ambassadors programme (no target; the app opens the programme).
        | 'AMBASSADOR_APPLICATION_APPROVED'
        | 'AMBASSADOR_APPLICATION_REJECTED'
        | 'AMBASSADOR_LEVEL_UP'
        | 'AMBASSADOR_REWARD_GRANTED'
        | 'AMBASSADOR_MEMBERSHIP_ENDED';
      recipientId: string;
    } & NotificationTargetRef,
  ): Promise<void> {
    const now = new Date();
    await tx.notification.create({
      data: {
        recipientId: input.recipientId,
        type: input.type,
        ...targetWhere(input),
        premiumLeaseId: input.premiumLeaseId ?? null,
        createdAt: now,
        updatedAt: now,
      },
    });
  }

  /**
   * v1.70-social (D206): an agency's system notification (no actor) to its owner or to a released host, with the
   * probation's numbers when there are some. Only to an ACTIVE account.
   */
  /**
   * v1.89-social (D290, §10.103): a level-raise request's result — LEVEL_RAISE_APPROVED / LEVEL_RAISE_REJECTED to the
   * staff member who made it, LEVEL_RAISED to the supporter (approval only). Only to an ACTIVE account.
   */
  async levelRaise(
    tx: Tx,
    input: {
      type: 'LEVEL_RAISE_APPROVED' | 'LEVEL_RAISE_REJECTED' | 'LEVEL_RAISED';
      recipientId: string;
      requestId: string;
    },
  ): Promise<void> {
    const active = await tx.user.count({ where: { id: input.recipientId, status: 'ACTIVE' } });
    if (active === 0) return;
    const now = new Date();
    await tx.notification.create({
      data: {
        recipientId: input.recipientId,
        type: input.type,
        levelRaiseRequestId: input.requestId,
        createdAt: now,
        updatedAt: now,
      },
    });
  }

  /**
   * v1.95-social (D301, §10.112.5): a new item in «صندوق المؤسس» — OWNER_FEEDBACK_NEW to every app owner (an ACTIVE
   * account holding the OWNER panel role), never to anyone else (the reported staff member is never told).
   */
  async ownerFeedback(tx: Tx, feedbackId: string): Promise<number> {
    const owners = await tx.userAdminPermission.findMany({
      where: { permission: 'OWNER', user: { status: 'ACTIVE' } },
      select: { userId: true },
    });
    if (owners.length === 0) return 0;
    const now = new Date();
    await tx.notification.createMany({
      data: owners.map((o) => ({
        recipientId: o.userId,
        type: 'OWNER_FEEDBACK_NEW' as const,
        ownerFeedbackId: feedbackId,
        createdAt: now,
        updatedAt: now,
      })),
    });
    return owners.length;
  }

  async agency(
    tx: Tx,
    input: {
      type: AgencyNotificationType;
      recipientId: string;
      agencyId: string;
      activated?: number | null;
      required?: number | null;
    },
  ): Promise<void> {
    const active = await tx.user.count({ where: { id: input.recipientId, status: 'ACTIVE' } });
    if (active === 0) return;
    const now = new Date();
    await tx.notification.create({
      data: {
        recipientId: input.recipientId,
        type: input.type,
        agencyId: input.agencyId,
        agencyActivated: input.activated ?? null,
        agencyRequired: input.required ?? null,
        createdAt: now,
        updatedAt: now,
      },
    });
  }
}
