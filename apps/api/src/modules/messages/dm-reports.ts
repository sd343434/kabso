import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import type { Prisma } from '../../generated/prisma/client.js';

/**
 * Report hooks for direct messages (CONVENTIONS §11.7, §11.13), pure functions the safety module
 * calls with its own Prisma client (no module import cycle). Messages are deleted 24 hours after
 * they were sent, so a report keeps a **snapshot** of the message (and a copy of its file).
 */

type Db = Pick<Prisma.TransactionClient, 'dmMessage'>;

/** What a `DM_MESSAGE` report keeps (`reports.dm_snapshot`). */
export interface DmSnapshot {
  kind: string;
  text: string | null;
  token: string | null;
  senderId: string;
  senderUsername: string | null;
  conversationId: string;
  sentAt: string;
  /** The report's own copy of the picture or voice clip (`reports/dm/<reportId>.<ext>`), or null. */
  mediaKey: string | null;
  giftCode: string | null;
  quantity: number | null;
  /** The retention period after resolution ended: text, token and file were cleared. */
  purged: boolean;
}

/** `DmReportSnapshot` (admin views only). */
export interface DmSnapshotDto {
  kind: string;
  text: string | null;
  token: string | null;
  sender: string | null;
  sentAt: string;
  mediaUrl: string | null;
  giftCode: string | null;
  quantity: number | null;
  purged: boolean;
}

/** How long a resolved report keeps its snapshot (CONVENTIONS §11.13). */
export const DM_REPORT_SNAPSHOT_DAYS = 30;

/** A message as a report needs it: its content and the keys of its file. */
export interface ReportableDmMessage {
  id: string;
  senderId: string;
  snapshot: Omit<DmSnapshot, 'mediaKey' | 'purged'>;
  /** The stored object to copy (picture: the large variant; voice: the clip), or null. */
  media: { key: string; extension: 'webp' | 'm4a'; contentType: string } | null;
}

/**
 * A direct message `readerId` **received** and can still read now: not expired, not deleted for
 * them (cleared or hidden), and no block either way with its sender; else 404.
 */
export async function reportableDmMessage(
  db: Db,
  messageId: string,
  readerId: string,
  now: Date,
): Promise<ReportableDmMessage> {
  const row = await db.dmMessage.findFirst({
    where: {
      id: messageId,
      recipientId: readerId,
      expiresAt: { gt: now },
      hides: { none: { userId: readerId } },
      sender: {
        status: 'ACTIVE',
        blocking: { none: { blockedId: readerId } },
        blockedBy: { none: { blockerId: readerId } },
      },
    },
    include: {
      sender: { select: { profile: { select: { username: true } } } },
      media: { select: { largeKey: true, kind: true } },
      gift: { select: { giftCode: true, quantity: true } },
      conversation: {
        select: { participants: { where: { userId: readerId }, select: { clearedAt: true } } },
      },
    },
  });
  const cleared = row?.conversation.participants[0]?.clearedAt ?? null;
  if (!row || (cleared !== null && row.createdAt <= cleared)) throw new AppException(ErrorCode.NOT_FOUND);
  const voice = row.media?.kind === 'DM_VOICE';
  return {
    id: row.id,
    senderId: row.senderId,
    snapshot: {
      kind: row.kind,
      text: row.text,
      token: row.token,
      senderId: row.senderId,
      senderUsername: row.sender.profile?.username ?? null,
      conversationId: row.conversationId,
      sentAt: row.createdAt.toISOString(),
      giftCode: row.gift?.giftCode ?? null,
      quantity: row.gift?.quantity ?? null,
    },
    media: row.media
      ? {
          key: row.media.largeKey,
          extension: voice ? 'm4a' : 'webp',
          contentType: voice ? 'audio/mp4' : 'image/webp',
        }
      : null,
  };
}

/** Report action `REMOVE_TARGET`, inside the caller's transaction: the message expires now (the sweeper deletes it and its file). */
export async function removeDmMessageIn(
  tx: Prisma.TransactionClient,
  messageId: string,
  at: Date,
): Promise<boolean> {
  // Never before it was sent (CHECK `dm_messages_expiry`).
  const done = await tx.$executeRaw`
    UPDATE dm_messages SET expires_at = GREATEST(created_at, ${at}::timestamptz)
     WHERE id = ${messageId}::uuid AND expires_at > ${at}::timestamptz`;
  return done > 0;
}

/** The admin view of a stored snapshot (tolerates a malformed value: shows what is there). */
export function dmSnapshotDto(raw: unknown, publicBaseUrl: string | undefined): DmSnapshotDto | null {
  if (typeof raw !== 'object' || raw === null) return null;
  const s = raw as Partial<DmSnapshot>;
  const str = (v: unknown): string | null => (typeof v === 'string' ? v : null);
  return {
    kind: str(s.kind) ?? 'TEXT',
    text: str(s.text),
    token: str(s.token),
    sender: str(s.senderUsername),
    sentAt: str(s.sentAt) ?? new Date(0).toISOString(),
    mediaUrl: s.mediaKey ? `${publicBaseUrl ?? ''}/${s.mediaKey}` : null,
    giftCode: str(s.giftCode),
    quantity: typeof s.quantity === 'number' ? s.quantity : null,
    purged: s.purged === true,
  };
}
