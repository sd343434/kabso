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
}

/** Types without an actor: always on, never grouped, never hidden with their target. */
export const SYSTEM_TYPES: readonly NotificationType[] = [
  'POST_PUBLISHED',
  'CONTENT_REMOVED',
  'PREMIUM_USERNAME_EXPIRING',
  'PREMIUM_USERNAME_EXPIRED',
  // v1.47-social (D175): a moderator removed the profile photo.
  'AVATAR_REMOVED',
];

/** Types that join one unread row per target (owner, D92). */
const GROUPED: ReadonlySet<NotificationType> = new Set(['LIKE_POST', 'LIKE_COMMENT', 'REPOST']);

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
        | 'AVATAR_REMOVED';
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
}
