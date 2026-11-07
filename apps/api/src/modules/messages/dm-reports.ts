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
  /** v1.93-social (D296): the whole conversation as it was when reported (null once purged). */
  thread?: DmThreadSnapshot | null;
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

// ---- v1.93-social (D296, CONVENTIONS §10.109.5): the whole conversation frozen with the report ----------------------

/**
 * Owner (2026-11-06, «مثل طريقة نزاع وكيل الشحن»): a DM report — or a person reported from the conversation — keeps every
 * message of that conversation that still exists when the report is filed (D155 deletes messages 24 h after they are
 * sent, so that is everything retained), as the recharge dispute keeps its whole chat. Bounded: the newest
 * {@link DM_REPORT_THREAD_MAX_MESSAGES} messages, and a copy of the newest {@link DM_REPORT_THREAD_MAX_FILES} pictures /
 * voice clips (`reports/dm/<reportId>/<messageId>.<ext>`). Later messages are never added. Cleared with the rest of the
 * snapshot 30 days after resolution.
 */
export const DM_REPORT_THREAD_MAX_MESSAGES = 300;
export const DM_REPORT_THREAD_MAX_FILES = 20;

/** One message of the frozen conversation (`reports.dm_snapshot.thread.messages[]`). */
export interface DmThreadMessage {
  id: string;
  senderId: string;
  kind: string;
  text: string | null;
  token: string | null;
  sentAt: string;
  /** The report's own copy of the file, or null (none, beyond the cap, or the copy failed). */
  mediaKey: string | null;
  /** A picture or voice clip whose file was not copied (beyond {@link DM_REPORT_THREAD_MAX_FILES}). */
  mediaMissing: boolean;
  giftCode: string | null;
  quantity: number | null;
  /** The reported message itself (DM_MESSAGE reports). */
  reported: boolean;
}

/** `reports.dm_snapshot.thread`. */
export interface DmThreadSnapshot {
  conversationId: string;
  capturedAt: string;
  /** Messages that existed at the time (before the cap). */
  total: number;
  /** More than {@link DM_REPORT_THREAD_MAX_MESSAGES} existed: the oldest were left out. */
  truncated: boolean;
  /** Oldest first. */
  messages: DmThreadMessage[];
}

/** A message read for the thread, with its file to copy. */
export interface DmThreadRow {
  message: Omit<DmThreadMessage, 'mediaKey' | 'mediaMissing' | 'reported'>;
  media: { key: string; extension: 'webp' | 'm4a'; contentType: string } | null;
}

/** Every message of `conversationId` that still exists at `now` (newest {@link DM_REPORT_THREAD_MAX_MESSAGES}), oldest first. */
export async function dmThreadRowsOf(
  db: Db,
  conversationId: string,
  now: Date,
): Promise<{ rows: DmThreadRow[]; total: number }> {
  const where = { conversationId, expiresAt: { gt: now } };
  const [total, newest] = await Promise.all([
    db.dmMessage.count({ where }),
    db.dmMessage.findMany({
      where,
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
      take: DM_REPORT_THREAD_MAX_MESSAGES,
      include: {
        media: { select: { largeKey: true, kind: true } },
        gift: { select: { giftCode: true, quantity: true } },
      },
    }),
  ]);
  const rows = newest.reverse().map((m): DmThreadRow => {
    const voice = m.media?.kind === 'DM_VOICE';
    return {
      message: {
        id: m.id,
        senderId: m.senderId,
        kind: m.kind,
        text: m.text,
        token: m.token,
        sentAt: m.createdAt.toISOString(),
        giftCode: m.gift?.giftCode ?? null,
        quantity: m.gift?.quantity ?? null,
      },
      media: m.media
        ? {
            key: m.media.largeKey,
            extension: voice ? 'm4a' : 'webp',
            contentType: voice ? 'audio/mp4' : 'image/webp',
          }
        : null,
    };
  });
  return { rows, total };
}

/** Every file a stored snapshot holds (the reported message's copy and the thread's). */
export function dmSnapshotObjectKeys(raw: unknown): string[] {
  if (typeof raw !== 'object' || raw === null) return [];
  const s = raw as { mediaKey?: unknown; thread?: { messages?: unknown } | null };
  const keys = new Set<string>();
  if (typeof s.mediaKey === 'string' && s.mediaKey !== '') keys.add(s.mediaKey);
  const messages = Array.isArray(s.thread?.messages) ? (s.thread.messages as unknown[]) : [];
  for (const m of messages) {
    const k = (m as { mediaKey?: unknown } | null)?.mediaKey;
    if (typeof k === 'string' && k !== '') keys.add(k);
  }
  return [...keys];
}

/** `DmReportThreadMessage` (staff view only). */
export interface DmThreadMessageDto {
  id: string;
  sender: string | null;
  /** Sent by the reported person (the DM's sender, or the reported user). */
  fromReported: boolean;
  kind: string;
  text: string | null;
  token: string | null;
  sentAt: string;
  mediaUrl: string | null;
  mediaMissing: boolean;
  giftCode: string | null;
  quantity: number | null;
  reported: boolean;
}

/** `DmReportThread` (staff view only). */
export interface DmThreadDto {
  capturedAt: string;
  total: number;
  truncated: boolean;
  messages: DmThreadMessageDto[];
}

/** The staff view of a stored thread (null when there is none, or it was purged). */
export function dmThreadDto(
  raw: unknown,
  publicBaseUrl: string | undefined,
  usernames: ReadonlyMap<string, string>,
  reportedUserId: string | null,
): DmThreadDto | null {
  if (typeof raw !== 'object' || raw === null) return null;
  const t = (raw as { thread?: unknown }).thread;
  if (typeof t !== 'object' || t === null) return null;
  const th = t as Partial<DmThreadSnapshot>;
  const str = (v: unknown): string | null => (typeof v === 'string' ? v : null);
  const messages = Array.isArray(th.messages) ? th.messages : [];
  return {
    capturedAt: str(th.capturedAt) ?? new Date(0).toISOString(),
    total: typeof th.total === 'number' ? th.total : messages.length,
    truncated: th.truncated === true,
    messages: messages.map((m) => ({
      id: str(m.id) ?? '',
      sender: usernames.get(str(m.senderId) ?? '') ?? null,
      fromReported: reportedUserId !== null && m.senderId === reportedUserId,
      kind: str(m.kind) ?? 'TEXT',
      text: str(m.text),
      token: str(m.token),
      sentAt: str(m.sentAt) ?? new Date(0).toISOString(),
      mediaUrl: m.mediaKey ? `${publicBaseUrl ?? ''}/${m.mediaKey}` : null,
      mediaMissing: m.mediaMissing === true,
      giftCode: str(m.giftCode),
      quantity: typeof m.quantity === 'number' ? m.quantity : null,
      reported: m.reported === true,
    })),
  };
}
