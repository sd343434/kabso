import { AuditAction } from '../../common/audit/audit.service.js';
import type { Prisma } from '../../generated/prisma/client.js';
import { Notifier } from '../notifications/notifier.js';
import { isValidUsername } from './username.js';

/** What `profile-admin remove-avatar` did. */
export type AdminAvatarRemoval =
  | { readonly outcome: 'unknown_user' }
  | { readonly outcome: 'no_photo'; readonly userId: string }
  | { readonly outcome: 'removed'; readonly userId: string; readonly objectKeys: string[] };

/**
 * v1.47-social (D175, owner: «أضف أداة إدارية لحذف صورة مخالفة», CONVENTIONS §10.43): removes a user's
 * profile photo for moderation, inside the caller's transaction. The profile goes back to the
 * initial (`avatar_url` and `avatar_media_id` null), the `AVATAR` asset row is deleted (its object
 * keys are returned so the caller deletes the files after commit), the user gets an
 * `AVATAR_REMOVED` notification (system, no actor) and `admin.avatar.remove` is audited with the
 * reason. Any status but DELETED counts (a suspended account's photo can be removed too). A user
 * without a photo changes nothing.
 */
export async function removeAvatarByAdminIn(
  tx: Prisma.TransactionClient,
  username: string,
  reason: string | null,
): Promise<AdminAvatarRemoval> {
  const name = username.trim().toLowerCase();
  if (!isValidUsername(name)) return { outcome: 'unknown_user' };
  const [row] = await tx.$queryRaw<
    { user_id: string; avatar_url: string | null; avatar_media_id: string | null }[]
  >`
    SELECT p.user_id::text AS user_id, p.avatar_url, p.avatar_media_id::text AS avatar_media_id
      FROM user_profiles p JOIN users u ON u.id = p.user_id
     WHERE p.username = ${name} AND u.status <> 'DELETED'::user_status
       FOR UPDATE OF p`;
  if (!row) return { outcome: 'unknown_user' };
  if (row.avatar_url === null && row.avatar_media_id === null)
    return { outcome: 'no_photo', userId: row.user_id };
  await tx.userProfile.update({
    where: { userId: row.user_id },
    data: { avatarUrl: null, avatarMediaId: null },
  });
  let objectKeys: string[] = [];
  if (row.avatar_media_id !== null) {
    const gone = await tx.mediaAsset.delete({
      where: { id: row.avatar_media_id },
      select: { largeKey: true, thumbKey: true },
    });
    objectKeys = [gone.largeKey, gone.thumbKey];
  }
  await new Notifier().system(tx, { type: 'AVATAR_REMOVED', recipientId: row.user_id });
  await tx.auditLog.create({
    data: {
      action: AuditAction.ADMIN_AVATAR_REMOVE,
      targetType: 'user',
      targetId: row.user_id,
      metadata: { username: name, reason, hadAsset: row.avatar_media_id !== null, via: 'cli' },
    },
  });
  return { outcome: 'removed', userId: row.user_id, objectKeys };
}
