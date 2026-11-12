import { auditBy, type AdminVia } from '../../common/audit/admin-actor.js';
import { AuditAction } from '../../common/audit/audit.service.js';
import type { Prisma } from '../../generated/prisma/client.js';
import { Notifier } from '../notifications/notifier.js';
import { blockedEitherWayIn } from '../social/pair-lock.js';
import { vipHoldsPerkIn } from '../vip/vip-perks.js';
import { ANIMATED_AVATAR_PERK, type AnimatedAvatarDto } from './profile-edit.service.js';

/**
 * v1.136-social (D384, CONVENTIONS §10.173.4): the VIP animated picture «صورة متحركة» [ownerId] shows to [viewerId] now,
 * or null — only while the owner has a clip, holds an active VIP with the ANIMATED_AVATAR perk (inherited, D258: it
 * disappears when the membership ends and comes back on renewal, the clip being kept) and neither of the two blocked
 * the other. The caller leaves out limited Kabso Team accounts (their picture is the team's).
 */
export async function shownAnimatedAvatarIn(
  db: Prisma.TransactionClient,
  ownerId: string,
  viewerId: string,
  now: Date,
): Promise<AnimatedAvatarDto | null> {
  const row = await db.userProfile.findUnique({
    where: { userId: ownerId },
    select: {
      animatedAvatarUrl: true,
      animatedAvatarStillUrl: true,
      animatedAvatarMedia: { select: { width: true, height: true } },
    },
  });
  if (!row?.animatedAvatarUrl || !row.animatedAvatarStillUrl || !row.animatedAvatarMedia) return null;
  if (ownerId !== viewerId && (await blockedEitherWayIn(db, ownerId, viewerId))) return null;
  if (!(await vipHoldsPerkIn(db, ownerId, ANIMATED_AVATAR_PERK, now))) return null;
  return {
    url: row.animatedAvatarUrl,
    stillUrl: row.animatedAvatarStillUrl,
    width: row.animatedAvatarMedia.width,
    height: row.animatedAvatarMedia.height,
  };
}

/** What the panel's «حذف الصورة المتحركة» did. */
export type AdminAnimatedAvatarRemoval =
  | { readonly outcome: 'unknown_user' }
  | { readonly outcome: 'none'; readonly userId: string }
  | { readonly outcome: 'removed'; readonly userId: string; readonly objectKeys: string[] };

/**
 * v1.136-social (D384, CONVENTIONS §10.173.5): removes a user's VIP animated picture for moderation, inside the caller's
 * transaction — the rules of `removeCoverByAdminIn`: the profile's three columns are cleared, the `ANIMATED_AVATAR` asset
 * row is deleted (its object keys are returned so the caller deletes the files after commit), the user gets an
 * `ANIMATED_AVATAR_REMOVED` notification (system) and `admin.animated_avatar.remove` is audited with the reason. Any
 * status but DELETED counts. A user without a clip changes nothing.
 */
export async function removeAnimatedAvatarByAdminIn(
  tx: Prisma.TransactionClient,
  userId: string,
  reason: string,
  by: AdminVia,
): Promise<AdminAnimatedAvatarRemoval> {
  const [row] = await tx.$queryRaw<{ user_id: string; media_id: string | null }[]>`
    SELECT p.user_id::text AS user_id, p.animated_avatar_media_id::text AS media_id
      FROM user_profiles p JOIN users u ON u.id = p.user_id
     WHERE p.user_id = ${userId}::uuid AND u.status <> 'DELETED'::user_status
       FOR UPDATE OF p`;
  if (!row) return { outcome: 'unknown_user' };
  if (row.media_id === null) return { outcome: 'none', userId: row.user_id };
  await tx.userProfile.update({
    where: { userId: row.user_id },
    data: { animatedAvatarMediaId: null, animatedAvatarUrl: null, animatedAvatarStillUrl: null },
  });
  const gone = await tx.mediaAsset.delete({
    where: { id: row.media_id },
    select: { largeKey: true, thumbKey: true },
  });
  await new Notifier().system(tx, { type: 'ANIMATED_AVATAR_REMOVED', recipientId: row.user_id });
  await tx.auditLog.create({
    data: {
      ...auditBy(by),
      action: AuditAction.ADMIN_ANIMATED_AVATAR_REMOVE,
      targetType: 'user',
      targetId: row.user_id,
      metadata: { reason, via: by.via },
    },
  });
  return { outcome: 'removed', userId: row.user_id, objectKeys: [gone.largeKey, gone.thumbKey] };
}
