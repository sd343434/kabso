import { Inject, Injectable } from '@nestjs/common';
import { BackgroundTasks } from '../../common/background/background-tasks.js';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { RateLimitService } from '../../common/rate-limit/rate-limit.service.js';
import { Clock } from '../../common/time/clock.js';
import { zodErrorToDetails } from '../../common/validation/zod-validation.pipe.js';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import type { DmMessageKind, Prisma } from '../../generated/prisma/client.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { stockOf } from '../gifts/gift-catalogue.js';
import { giftArtDto, GiftsService } from '../gifts/gifts.service.js';
import type { LuckyRegionInput } from '../gifts/lucky-gifts.service.js';
import { luckyResultDto, type AuditedWin, type LuckyGiftResultDto } from '../gifts/lucky-odds.js';
import { uuidv7 } from '../levels/uuidv7.js';
import { maskBlockedWords } from '../live/live-blocked-words.js';
import { LiveGiftsService } from '../live/live-gifts.service.js';
import type { UserSummaryDto } from '../live/live-rooms.service.js';
import { isUuid } from '../live/live.schemas.js';
import { MediaService, type MediaAssetDto } from '../media/media.service.js';
import { USER_SUMMARY_SELECT, userSummary, type PageDto } from '../posts/post-views.js';
import { SocialCursorCodec } from '../posts/social-cursor.js';
import { blockedEitherWayIn, lockUserPairIn } from '../social/pair-lock.js';
import { UsersService, violatedUniqueIndex } from '../users/users.service.js';
import { WalletService } from '../wallet/wallet.service.js';
import { DmPush } from './dm-push.js';
import { allowedInRequest, decideDm, pairOf, type DmDecision, type DmFacts } from './dm-rules.js';
import {
  dmGiftSendSchema,
  dmReadSchema,
  dmSendSchema,
  type DmConversationsQuery,
  type DmDeleteMessageQuery,
  type DmMessagesQuery,
} from './dm.schemas.js';

// ---- Response shapes (openapi v1.40-social, D155) -----------------------------------------------

export interface DmGiftDto {
  giftCode: string;
  assetKey: string;
  animationKey: string | null;
  imageUrl: string | null;
  animationUrl: string | null;
  animationBytes: number | null;
  unitPrice: number;
  quantity: number;
  totalCoins: number;
  lucky: { coinsWon: number; topMultiplier: number | null } | null;
}

export interface DmMessageDto {
  id: string;
  conversationId: string;
  senderId: string;
  mine: boolean;
  kind: DmMessageKind;
  text: string | null;
  token: string | null;
  media: MediaAssetDto | null;
  gift: DmGiftDto | null;
  read: boolean;
  createdAt: string;
  expiresAt: string;
}

export type DmConversationStatus = 'ACCEPTED' | 'REQUEST_RECEIVED' | 'REQUEST_SENT';

export interface DmConversationDto {
  id: string;
  peer: UserSummaryDto;
  status: DmConversationStatus;
  muted: boolean;
  unreadCount: number;
  lastMessage: DmMessageDto | null;
  lastActivityAt: string;
  peerReadAt: string | null;
  canSend: boolean;
  requestMessagesLeft: number | null;
}

export interface DmMessagePageDto extends PageDto<DmMessageDto> {
  conversation: DmConversationDto;
}

export interface DmUnreadDto {
  messages: number;
  conversations: number;
  requests: number;
}

export interface DmPeerDto {
  user: UserSummaryDto;
  conversation: DmConversationDto | null;
  canMessage: boolean;
  reason: 'NOT_ALLOWED' | 'REQUEST_LIMIT' | null;
  /** The caller's next message would be a message request. */
  asRequest: boolean;
}

export interface DmSendResultDto {
  message: DmMessageDto;
  conversation: DmConversationDto;
}

export interface DmGiftResultDto extends DmSendResultDto {
  coins: number;
  bagQuantity: number;
  luckyResult?: LuckyGiftResultDto;
}

// ---- Rows ------------------------------------------------------------------------------------------

const MESSAGE_INCLUDE = {
  media: true,
  gift: {
    include: {
      gift: {
        select: {
          assetKey: true,
          animationKey: true,
          imageObjectKey: true,
          animationObjectKey: true,
          animationBytes: true,
        },
      },
      luckyDraw: {
        select: {
          draws: true,
          wins: true,
          unitPrice: true,
          downgraded: true,
          coinsWon: true,
          topMultiplier: true,
        },
      },
    },
  },
} as const satisfies Prisma.DmMessageInclude;
type MessageRow = Prisma.DmMessageGetPayload<{ include: typeof MESSAGE_INCLUDE }>;

type ParticipantRow = Prisma.DmParticipantGetPayload<object>;

/** The cap of every unread count (the badge shows "99+"). */
const UNREAD_CAP = 99;
/** The server's blocked words are re-read at most this often. */
const BLOCKED_WORDS_TTL_MS = 60_000;

function notFound(): AppException {
  return new AppException(ErrorCode.NOT_FOUND);
}

interface Recipient {
  readonly id: string;
  readonly username: string;
}

/** What one message carries (exactly the field of its kind). */
interface MessageContent {
  readonly kind: DmMessageKind;
  readonly text: string | null;
  readonly token: string | null;
  readonly mediaId: string | null;
  readonly giftId: string | null;
}

/**
 * Direct messages (D155, CONVENTIONS §11.13): one conversation per pair, created by the first
 * message; message requests for strangers; the privacy setting; receipts and unread counts; gifts
 * through the live gift pipeline; every message lives `DM_RETENTION_HOURS` (the sweeper deletes it).
 * Every write between two people runs under the pair's lock (the same one follow and block use), so
 * a message never slips past a concurrent block, and the request limit is exact.
 */
@Injectable()
export class DmService {
  private readonly cursors: SocialCursorCodec;
  private serverWords: { at: number; words: string[] } | null = null;

  constructor(
    private readonly prisma: PrismaService,
    private readonly users: UsersService,
    private readonly media: MediaService,
    private readonly gifts: GiftsService,
    private readonly liveGifts: LiveGiftsService,
    private readonly wallet: WalletService,
    private readonly limiter: RateLimitService,
    private readonly clock: Clock,
    private readonly background: BackgroundTasks,
    private readonly push: DmPush,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
  ) {
    this.cursors = new SocialCursorCodec(config.social.cursorKey);
  }

  private get retentionMs(): number {
    return this.config.dm.retentionHours * 3600 * 1000;
  }

  // ---- DTOs -----------------------------------------------------------------------------------

  private messageDto(row: MessageRow, callerId: string, peerReadAt: Date | null): DmMessageDto {
    const gift = row.gift;
    return {
      id: row.id,
      conversationId: row.conversationId,
      senderId: row.senderId,
      mine: row.senderId === callerId,
      kind: row.kind,
      text: row.text,
      token: row.token,
      media: row.media ? this.media.toDto(row.media) : null,
      gift: gift
        ? {
            giftCode: gift.giftCode,
            assetKey: gift.gift.assetKey,
            animationKey: gift.gift.animationKey,
            ...giftArtDto(gift.gift, this.gifts.publicBaseUrl),
            unitPrice: gift.unitPrice,
            quantity: gift.quantity,
            totalCoins: Number(gift.totalCoins),
            lucky: gift.luckyDraw
              ? { coinsWon: Number(gift.luckyDraw.coinsWon), topMultiplier: gift.luckyDraw.topMultiplier }
              : null,
          }
        : null,
      read: row.senderId === callerId && peerReadAt !== null && row.createdAt <= peerReadAt,
      createdAt: row.createdAt.toISOString(),
      expiresAt: row.expiresAt.toISOString(),
    };
  }

  /** The facts of `senderId` writing to `recipientId` (see {@link decideDm}). */
  private async factsIn(
    db: Pick<Prisma.TransactionClient, 'privacySettings' | 'follow' | 'dmParticipant'>,
    senderId: string,
    recipientId: string,
  ): Promise<DmFacts> {
    const [privacy, follows, parts] = await Promise.all([
      db.privacySettings.findUnique({ where: { userId: recipientId }, select: { whoCanMessage: true } }),
      db.follow.count({ where: { followerId: recipientId, followeeId: senderId } }),
      db.dmParticipant.findMany({
        where: {
          OR: [
            { userId: recipientId, peerId: senderId },
            { userId: senderId, peerId: recipientId },
          ],
        },
      }),
    ]);
    const theirs = parts.find((p) => p.userId === recipientId) ?? null;
    const mine = parts.find((p) => p.userId === senderId) ?? null;
    return {
      recipientWho: privacy?.whoCanMessage ?? 'EVERYONE',
      recipientFollowsSender: follows > 0,
      recipientHasSent: theirs?.hasSent ?? false,
      recipientStatus: theirs?.status ?? null,
      senderRequestSent: mine?.requestSent ?? 0,
    };
  }

  private decide(facts: DmFacts): DmDecision {
    return decideDm(facts, this.config.dm.requestMaxMessages);
  }

  /**
   * The DTOs of the caller's conversations `mine` (their own participant rows), in that order:
   * the peer, the peer's side, the last visible message, the unread count and whether the caller
   * may send now. Peers that are gone (not ACTIVE) are dropped.
   */
  private async conversationDtos(
    callerId: string,
    mine: readonly ParticipantRow[],
  ): Promise<DmConversationDto[]> {
    if (mine.length === 0) return [];
    const now = this.clock.now();
    const ids = mine.map((p) => p.conversationId);
    const peerIds = [...new Set(mine.map((p) => p.peerId))];
    const [theirs, people, stats, privacy, follows] = await Promise.all([
      this.prisma.dmParticipant.findMany({ where: { conversationId: { in: ids }, userId: { in: peerIds } } }),
      this.prisma.user.findMany({
        where: { id: { in: peerIds }, status: 'ACTIVE' },
        select: USER_SUMMARY_SELECT,
      }),
      this.prisma.$queryRaw<{ cid: string; last_id: string | null; unread: number }[]>`
        SELECT p.conversation_id::text AS cid,
               (SELECT m.id::text FROM dm_messages m
                 WHERE m.conversation_id = p.conversation_id AND m.expires_at > ${now}::timestamptz
                   AND (p.cleared_at IS NULL OR m.created_at > p.cleared_at)
                   AND NOT EXISTS (SELECT 1 FROM dm_message_hides h WHERE h.message_id = m.id AND h.user_id = p.user_id)
                 ORDER BY m.created_at DESC, m.id DESC LIMIT 1) AS last_id,
               (SELECT count(*)::int FROM (
                  SELECT 1 FROM dm_messages m
                   WHERE m.conversation_id = p.conversation_id AND m.recipient_id = p.user_id
                     AND m.expires_at > ${now}::timestamptz
                     AND (p.read_at IS NULL OR m.created_at > p.read_at)
                     AND (p.cleared_at IS NULL OR m.created_at > p.cleared_at)
                     AND NOT EXISTS (SELECT 1 FROM dm_message_hides h WHERE h.message_id = m.id AND h.user_id = p.user_id)
                   LIMIT ${UNREAD_CAP}) x) AS unread
          FROM dm_participants p
         WHERE p.user_id = ${callerId}::uuid AND p.conversation_id = ANY(${ids}::uuid[])`,
      this.prisma.privacySettings.findMany({
        where: { userId: { in: peerIds } },
        select: { userId: true, whoCanMessage: true },
      }),
      this.prisma.follow.findMany({
        where: { followerId: { in: peerIds }, followeeId: callerId },
        select: { followerId: true },
      }),
    ]);
    const lastIds = stats.map((s) => s.last_id).filter((id): id is string => id !== null);
    const lastRows =
      lastIds.length === 0
        ? []
        : await this.prisma.dmMessage.findMany({ where: { id: { in: lastIds } }, include: MESSAGE_INCLUDE });
    const theirOf = new Map(theirs.map((t) => [t.conversationId, t]));
    const personOf = new Map(people.map((u) => [u.id, userSummary(u)]));
    const statOf = new Map(stats.map((s) => [s.cid, s]));
    const lastOf = new Map(lastRows.map((r) => [r.id, r]));
    const whoOf = new Map(privacy.map((p) => [p.userId, p.whoCanMessage]));
    const followers = new Set(follows.map((f) => f.followerId));
    const out: DmConversationDto[] = [];
    for (const p of mine) {
      const peer = personOf.get(p.peerId);
      if (!peer) continue;
      const their = theirOf.get(p.conversationId) ?? null;
      const stat = statOf.get(p.conversationId);
      const last = stat?.last_id ? (lastOf.get(stat.last_id) ?? null) : null;
      const decision = this.decide({
        recipientWho: whoOf.get(p.peerId) ?? 'EVERYONE',
        recipientFollowsSender: followers.has(p.peerId),
        recipientHasSent: their?.hasSent ?? false,
        recipientStatus: their?.status ?? null,
        senderRequestSent: p.requestSent,
      });
      const status: DmConversationStatus =
        p.status === 'REQUEST'
          ? 'REQUEST_RECEIVED'
          : their?.status === 'REQUEST'
            ? 'REQUEST_SENT'
            : 'ACCEPTED';
      const peerReadAt = their?.readAt ?? null;
      out.push({
        id: p.conversationId,
        peer,
        status,
        muted: p.muted,
        unreadCount: Math.min(UNREAD_CAP, stat?.unread ?? 0),
        lastMessage: last ? this.messageDto(last, callerId, peerReadAt) : null,
        lastActivityAt: p.lastMessageAt.toISOString(),
        peerReadAt: peerReadAt?.toISOString() ?? null,
        canSend: decision.allowed,
        requestMessagesLeft:
          status === 'REQUEST_SENT' ? Math.max(0, this.config.dm.requestMaxMessages - p.requestSent) : null,
      });
    }
    return out;
  }

  /** The caller's side of a conversation they can open (peer ACTIVE, no block either way), else 404. */
  private async access(callerId: string, conversationId: string): Promise<ParticipantRow> {
    if (!isUuid(conversationId)) throw notFound();
    const row = await this.prisma.dmParticipant.findFirst({
      where: {
        conversationId: conversationId.toLowerCase(),
        userId: callerId,
        peer: {
          status: 'ACTIVE',
          blocking: { none: { blockedId: callerId } },
          blockedBy: { none: { blockerId: callerId } },
        },
      },
    });
    if (!row) throw notFound();
    return row;
  }

  private async conversationDto(callerId: string, conversationId: string): Promise<DmConversationDto> {
    const row = await this.prisma.dmParticipant.findUniqueOrThrow({
      where: { conversationId_userId: { conversationId, userId: callerId } },
    });
    const [dto] = await this.conversationDtos(callerId, [row]);
    if (!dto) throw notFound();
    return dto;
  }

  // ---- Reads ------------------------------------------------------------------------------------

  /** `GET /dm/conversations`: INBOX (accepted, sent requests) or REQUESTS, newest message first. */
  async list(callerId: string, query: DmConversationsQuery): Promise<PageDto<DmConversationDto>> {
    const scope = `dm-list:${query.box}:${callerId}`;
    let after = null;
    if (query.cursor !== undefined) {
      after = this.cursors.decode(query.cursor, scope);
      if (!after) throw AppException.validation([{ field: 'cursor', issue: 'invalid_value' }]);
    }
    const status = query.box === 'REQUESTS' ? 'REQUEST' : 'ACCEPTED';
    const rows = await this.prisma.$queryRaw<{ conversation_id: string }[]>`
      SELECT p.conversation_id::text AS conversation_id
        FROM dm_participants p
        JOIN users u ON u.id = p.peer_id AND u.status = 'ACTIVE'::user_status
       WHERE p.user_id = ${callerId}::uuid
         AND p.status = ${status}::dm_participant_status
         AND (p.cleared_at IS NULL OR p.last_message_at > p.cleared_at)
         AND NOT EXISTS (SELECT 1 FROM user_blocks b
                          WHERE (b.blocker_id = p.user_id AND b.blocked_id = p.peer_id)
                             OR (b.blocker_id = p.peer_id AND b.blocked_id = p.user_id))
         AND (${after === null} OR (p.last_message_at, p.conversation_id)
                                   < (${after?.at ?? new Date(0)}::timestamptz, ${after?.id ?? '00000000-0000-0000-0000-000000000000'}::uuid))
       ORDER BY p.last_message_at DESC, p.conversation_id DESC
       LIMIT ${query.limit + 1}`;
    const hasMore = rows.length > query.limit;
    const ids = rows.slice(0, query.limit).map((r) => r.conversation_id);
    const parts = await this.prisma.dmParticipant.findMany({
      where: { userId: callerId, conversationId: { in: ids } },
    });
    const byId = new Map(parts.map((p) => [p.conversationId, p]));
    const ordered = ids.map((id) => byId.get(id)).filter((p): p is ParticipantRow => p !== undefined);
    const last = ordered[ordered.length - 1];
    return {
      data: await this.conversationDtos(callerId, ordered),
      page: {
        hasMore,
        nextCursor:
          hasMore && last
            ? this.cursors.encode(scope, { at: last.lastMessageAt, id: last.conversationId })
            : null,
      },
    };
  }

  /** `GET /dm/unread`: the badge (accepted, not muted), conversations with unread, requests. */
  async unread(callerId: string): Promise<DmUnreadDto> {
    const now = this.clock.now();
    const since = new Date(now.getTime() - this.retentionMs);
    const [row] = await this.prisma.$queryRaw<
      { messages: number; conversations: number; requests: number }[]
    >`
      SELECT COALESCE(sum(t.u) FILTER (WHERE t.status = 'ACCEPTED' AND NOT t.muted), 0)::int AS messages,
             count(*) FILTER (WHERE t.status = 'ACCEPTED' AND NOT t.muted AND t.u > 0)::int AS conversations,
             count(*) FILTER (WHERE t.status = 'REQUEST' AND t.u > 0)::int AS requests
        FROM (
          SELECT p.status::text AS status, p.muted,
                 (SELECT count(*) FROM (
                    SELECT 1 FROM dm_messages m
                     WHERE m.conversation_id = p.conversation_id AND m.recipient_id = p.user_id
                       AND m.expires_at > ${now}::timestamptz
                       AND (p.read_at IS NULL OR m.created_at > p.read_at)
                       AND (p.cleared_at IS NULL OR m.created_at > p.cleared_at)
                       AND NOT EXISTS (SELECT 1 FROM dm_message_hides h WHERE h.message_id = m.id AND h.user_id = p.user_id)
                     LIMIT ${UNREAD_CAP}) x) AS u
            FROM dm_participants p
            JOIN users u ON u.id = p.peer_id AND u.status = 'ACTIVE'::user_status
           WHERE p.user_id = ${callerId}::uuid
             AND p.last_message_at > ${since}::timestamptz
             AND NOT EXISTS (SELECT 1 FROM user_blocks b
                              WHERE (b.blocker_id = p.user_id AND b.blocked_id = p.peer_id)
                                 OR (b.blocker_id = p.peer_id AND b.blocked_id = p.user_id))) t`;
    return {
      messages: Math.min(UNREAD_CAP, row?.messages ?? 0),
      conversations: Math.min(UNREAD_CAP, row?.conversations ?? 0),
      requests: Math.min(UNREAD_CAP, row?.requests ?? 0),
    };
  }

  /** The ACTIVE account `username` the caller may see (404), never the caller (400 `field`). */
  private async recipient(callerId: string, username: string, field: string): Promise<Recipient> {
    const user = await this.users.findActivePublicUser(username.trim().toLowerCase());
    if (user?.id === callerId) throw AppException.validation([{ field, issue: 'invalid_value' }]);
    if (!user) throw notFound();
    const blocked = await this.prisma.userBlock.count({
      where: {
        OR: [
          { blockerId: callerId, blockedId: user.id },
          { blockerId: user.id, blockedId: callerId },
        ],
      },
    });
    if (blocked > 0) throw notFound();
    return { id: user.id, username: user.username };
  }

  /** `GET /dm/peers/{username}`. */
  async peer(callerId: string, username: string): Promise<DmPeerDto> {
    const to = await this.recipient(callerId, username, 'username');
    const [user, mine, facts] = await Promise.all([
      this.prisma.user.findUniqueOrThrow({ where: { id: to.id }, select: USER_SUMMARY_SELECT }),
      this.prisma.dmParticipant.findFirst({ where: { userId: callerId, peerId: to.id } }),
      this.factsIn(this.prisma, callerId, to.id),
    ]);
    const decision = this.decide(facts);
    const [conversation] = mine ? await this.conversationDtos(callerId, [mine]) : [];
    return {
      user: userSummary(user),
      conversation: conversation ?? null,
      canMessage: decision.allowed,
      reason: decision.reason,
      asRequest: decision.asRequest,
    };
  }

  /** `GET /dm/conversations/{id}/messages`: newest first, what the caller can still read. */
  async messages(
    callerId: string,
    conversationId: string,
    query: DmMessagesQuery,
  ): Promise<DmMessagePageDto> {
    const mine = await this.access(callerId, conversationId);
    const scope = `dm-messages:${mine.conversationId}:${callerId}`;
    let after = null;
    if (query.cursor !== undefined) {
      after = this.cursors.decode(query.cursor, scope);
      if (!after) throw AppException.validation([{ field: 'cursor', issue: 'invalid_value' }]);
    }
    const now = this.clock.now();
    const [rows, conversation] = await Promise.all([
      this.prisma.dmMessage.findMany({
        where: {
          conversationId: mine.conversationId,
          expiresAt: { gt: now },
          hides: { none: { userId: callerId } },
          ...(mine.clearedAt ? { createdAt: { gt: mine.clearedAt } } : {}),
          ...(after
            ? { OR: [{ createdAt: { lt: after.at } }, { createdAt: after.at, id: { lt: after.id } }] }
            : {}),
        },
        orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
        take: query.limit + 1,
        include: MESSAGE_INCLUDE,
      }),
      this.conversationDto(callerId, mine.conversationId),
    ]);
    const hasMore = rows.length > query.limit;
    const page = rows.slice(0, query.limit);
    const last = page[page.length - 1];
    const peerReadAt = conversation.peerReadAt === null ? null : new Date(conversation.peerReadAt);
    return {
      data: page.map((r) => this.messageDto(r, callerId, peerReadAt)),
      page: {
        hasMore,
        nextCursor: hasMore && last ? this.cursors.encode(scope, { at: last.createdAt, id: last.id }) : null,
      },
      conversation,
    };
  }

  // ---- Sending ----------------------------------------------------------------------------------

  /** The server's blocked words (§11.11) and the recipient's own live blocked words (§10.14). */
  private async blockedWordsFor(recipientId: string): Promise<string[]> {
    const nowMs = Date.now();
    if (this.serverWords === null || nowMs - this.serverWords.at > BLOCKED_WORDS_TTL_MS) {
      const rows = await this.prisma.searchBlockedWord.findMany({ select: { word: true } });
      this.serverWords = { at: nowMs, words: rows.map((r) => r.word) };
    }
    const host = await this.prisma.liveHost.findUnique({
      where: { userId: recipientId },
      select: { blockedWords: true },
    });
    return [...this.serverWords.words, ...(host?.blockedWords ?? [])];
  }

  /**
   * Under the pair's lock: 404 on a block either way, then the privacy and request rules for a
   * message of `kind` (403 `DM_NOT_ALLOWED`, `DM_REQUEST_TEXT_ONLY`, `DM_REQUEST_LIMIT`; a request
   * counts in `dm:request`, 429). Returns whether it is a request.
   */
  private async gateIn(
    tx: Prisma.TransactionClient,
    senderId: string,
    to: Recipient,
    kind: string,
  ): Promise<boolean> {
    await lockUserPairIn(tx, senderId, to.id);
    if (await blockedEitherWayIn(tx, senderId, to.id)) throw notFound();
    const recipient = await tx.user.findFirst({
      where: { id: to.id, status: 'ACTIVE' },
      select: { id: true },
    });
    if (!recipient) throw notFound();
    const decision = this.decide(await this.factsIn(tx, senderId, to.id));
    this.assertDecision(decision, kind);
    if (decision.asRequest) {
      await this.limiter.consume('dm:request', senderId, this.config.rateLimits.dmRequestUser);
    }
    return decision.asRequest;
  }

  private assertDecision(decision: DmDecision, kind: string): void {
    if (decision.reason === 'NOT_ALLOWED') throw new AppException(ErrorCode.DM_NOT_ALLOWED);
    if (decision.asRequest && !allowedInRequest(kind)) throw new AppException(ErrorCode.DM_REQUEST_TEXT_ONLY);
    if (decision.reason === 'REQUEST_LIMIT') throw new AppException(ErrorCode.DM_REQUEST_LIMIT);
  }

  /** The pair's conversation (created now if needed); its last activity moves to `at`. */
  private async conversationIn(
    tx: Prisma.TransactionClient,
    a: string,
    b: string,
    at: Date,
  ): Promise<string> {
    const { low, high } = pairOf(a, b);
    const [row] = await tx.$queryRaw<{ id: string }[]>`
      INSERT INTO dm_conversations (id, user_low_id, user_high_id, created_at, last_message_at)
      VALUES (${uuidv7()}::uuid, ${low}::uuid, ${high}::uuid, ${at}::timestamptz, ${at}::timestamptz)
      ON CONFLICT (user_low_id, user_high_id) DO UPDATE
         SET last_message_at = GREATEST(dm_conversations.last_message_at, EXCLUDED.last_message_at)
      RETURNING id::text AS id`;
    return row!.id;
  }

  /** Both sides' rows and the message, in the send's transaction. */
  private async writeIn(
    tx: Prisma.TransactionClient,
    input: {
      conversationId: string;
      senderId: string;
      recipientId: string;
      clientId: string;
      content: MessageContent;
      asRequest: boolean;
      at: Date;
    },
  ): Promise<string> {
    const { conversationId, senderId, recipientId, at, asRequest } = input;
    await tx.$executeRaw`
      INSERT INTO dm_participants (conversation_id, user_id, peer_id, status, has_sent, request_sent, last_message_at, created_at)
      VALUES (${conversationId}::uuid, ${senderId}::uuid, ${recipientId}::uuid, 'ACCEPTED'::dm_participant_status,
              true, ${asRequest ? 1 : 0}, ${at}::timestamptz, ${at}::timestamptz)
      ON CONFLICT (conversation_id, user_id) DO UPDATE
         SET status = 'ACCEPTED'::dm_participant_status, has_sent = true,
             request_sent = dm_participants.request_sent + ${asRequest ? 1 : 0},
             last_message_at = GREATEST(dm_participants.last_message_at, EXCLUDED.last_message_at)`;
    await tx.$executeRaw`
      INSERT INTO dm_participants (conversation_id, user_id, peer_id, status, last_message_at, created_at)
      VALUES (${conversationId}::uuid, ${recipientId}::uuid, ${senderId}::uuid,
              ${asRequest ? 'REQUEST' : 'ACCEPTED'}::dm_participant_status, ${at}::timestamptz, ${at}::timestamptz)
      ON CONFLICT (conversation_id, user_id) DO UPDATE
         SET status = CASE WHEN ${asRequest} THEN dm_participants.status ELSE 'ACCEPTED'::dm_participant_status END,
             last_message_at = GREATEST(dm_participants.last_message_at, EXCLUDED.last_message_at)`;
    const id = uuidv7();
    const c = input.content;
    await tx.dmMessage.create({
      data: {
        id,
        conversationId,
        senderId,
        recipientId,
        clientId: input.clientId,
        kind: c.kind,
        text: c.text,
        token: c.token,
        mediaId: c.mediaId,
        giftId: c.giftId,
        asRequest,
        createdAt: at,
        expiresAt: new Date(at.getTime() + this.retentionMs),
      },
    });
    return id;
  }

  private byClientId(senderId: string, clientId: string): Promise<MessageRow | null> {
    return this.prisma.dmMessage.findUnique({
      where: { senderId_clientId: { senderId, clientId } },
      include: MESSAGE_INCLUDE,
    });
  }

  private async result(callerId: string, row: MessageRow): Promise<DmSendResultDto> {
    const conversation = await this.conversationDto(callerId, row.conversationId);
    const peerReadAt = conversation.peerReadAt === null ? null : new Date(conversation.peerReadAt);
    return { message: this.messageDto(row, callerId, peerReadAt), conversation };
  }

  private afterSend(
    row: { id: string; conversationId: string; recipientId: string },
    senderId: string,
    push: {
      kind: DmMessageKind;
      text: string | null;
      quantity: number | null;
      asRequest: boolean;
    },
  ): void {
    this.background.run('push.dm', async () => {
      await this.push.newMessage({
        conversationId: row.conversationId,
        messageId: row.id,
        senderId,
        recipientId: row.recipientId,
        ...push,
      });
    });
  }

  /**
   * `POST /dm/messages` (CONVENTIONS §11.13). Order after auth and the rate limit: 400 body → a
   * retry with the same `clientId` (200) → 400 `to` (oneself) → 404 → 403 privacy → request rules
   * → 400 `mediaId` → stored; then the push (after the response).
   */
  async send(callerId: string, body: unknown): Promise<{ created: boolean; result: DmSendResultDto }> {
    const parsed = dmSendSchema.safeParse(body ?? {}, { reportInput: true });
    if (!parsed.success) throw AppException.validation(zodErrorToDetails(parsed.error));
    const input = parsed.data;
    const clientId = input.clientId.toLowerCase();
    const first = await this.byClientId(callerId, clientId);
    if (first) return { created: false, result: await this.result(callerId, first) };
    const to = await this.recipient(callerId, input.to, 'to');
    const kind = input.kind;
    const text = kind === 'TEXT' ? maskBlockedWords(input.text!, await this.blockedWordsFor(to.id)) : null;
    let asRequest = false;
    let messageId: string;
    try {
      messageId = await this.prisma.$transaction(async (tx) => {
        asRequest = await this.gateIn(tx, callerId, to, kind);
        let mediaId: string | null = null;
        if (kind === 'IMAGE' || kind === 'VOICE') {
          const claimed = await this.media.claimAssetsIn(
            tx,
            callerId,
            [input.mediaId!],
            kind === 'IMAGE' ? 'DM_IMAGE' : 'DM_VOICE',
          );
          if (claimed === null) throw AppException.validation([{ field: 'mediaId', issue: 'invalid_value' }]);
          mediaId = claimed[0]!.id;
        }
        const at = this.clock.now();
        const conversationId = await this.conversationIn(tx, callerId, to.id, at);
        return this.writeIn(tx, {
          conversationId,
          senderId: callerId,
          recipientId: to.id,
          clientId,
          content: { kind, text, token: kind === 'EMOJI' ? input.token! : null, mediaId, giftId: null },
          asRequest,
          at,
        });
      });
    } catch (err) {
      if ((violatedUniqueIndex(err) ?? '').includes('dm_messages_client_once')) {
        const raced = await this.byClientId(callerId, clientId);
        if (raced) return { created: false, result: await this.result(callerId, raced) };
      }
      throw err;
    }
    const row = await this.prisma.dmMessage.findUniqueOrThrow({
      where: { id: messageId },
      include: MESSAGE_INCLUDE,
    });
    this.afterSend(row, callerId, { kind, text, quantity: null, asRequest });
    return { created: true, result: await this.result(callerId, row) };
  }

  /**
   * `POST /dm/gifts` (CONVENTIONS §11.13): the message rules (privacy, requests; a stranger's gift
   * is a request message) and then the live gift pipeline without a room
   * ({@link LiveGiftsService.sendDirect}); the gift message is written in the send's transaction.
   */
  async sendGift(
    callerId: string,
    body: unknown,
    region: LuckyRegionInput,
  ): Promise<{ created: boolean; result: DmGiftResultDto }> {
    const parsed = dmGiftSendSchema(this.gifts.quantities).safeParse(body ?? {}, { reportInput: true });
    if (!parsed.success) throw AppException.validation(zodErrorToDetails(parsed.error));
    const input = parsed.data;
    const clientId = input.clientId.toLowerCase();
    const first = await this.byClientId(callerId, clientId);
    if (first) return { created: false, result: await this.giftReplay(callerId, first) };
    const to = await this.recipient(callerId, input.to, 'to');
    // The message rules first (contract order); checked again under the lock in the send.
    this.assertDecision(this.decide(await this.factsIn(this.prisma, callerId, to.id)), 'GIFT');
    let asRequest = false;
    let conversationId = '';
    let sent;
    try {
      sent = await this.liveGifts.sendDirect(
        callerId,
        to.id,
        { giftCode: input.giftCode, quantity: input.quantity, source: input.source, clientId },
        region,
        {
          before: async (tx) => {
            asRequest = await this.gateIn(tx, callerId, to, 'GIFT');
            conversationId = await this.conversationIn(tx, callerId, to.id, this.clock.now());
            return conversationId;
          },
          after: async (tx, gift) => {
            return this.writeIn(tx, {
              conversationId,
              senderId: callerId,
              recipientId: to.id,
              clientId,
              content: { kind: 'GIFT', text: null, token: null, mediaId: null, giftId: gift.giftId },
              asRequest,
              at: gift.at,
            });
          },
        },
      );
    } catch (err) {
      const index = violatedUniqueIndex(err) ?? '';
      if (index.includes('dm_messages_client_once') || index.includes('live_gifts_client_once')) {
        const raced = await this.byClientId(callerId, clientId);
        if (raced) return { created: false, result: await this.giftReplay(callerId, raced) };
      }
      throw err;
    }
    const row = await this.prisma.dmMessage.findUniqueOrThrow({
      where: { id: sent.extra },
      include: MESSAGE_INCLUDE,
    });
    this.afterSend(row, callerId, { kind: 'GIFT', text: null, quantity: input.quantity, asRequest });
    return {
      created: true,
      result: {
        ...(await this.result(callerId, row)),
        coins: sent.coins,
        bagQuantity: sent.bagQuantity,
        ...(sent.luckyResult ? { luckyResult: sent.luckyResult } : {}),
      },
    };
  }

  private async giftReplay(callerId: string, row: MessageRow): Promise<DmGiftResultDto> {
    const draw = row.gift?.luckyDraw;
    return {
      ...(await this.result(callerId, row)),
      coins: (await this.wallet.mine(callerId)).coins,
      bagQuantity: row.gift ? await stockOf(this.prisma, callerId, row.gift.giftCode) : 0,
      ...(draw
        ? {
            luckyResult: luckyResultDto(
              draw.draws,
              draw.wins as AuditedWin[],
              draw.unitPrice,
              draw.downgraded,
            ),
          }
        : {}),
    };
  }

  // ---- Other writes -----------------------------------------------------------------------------

  /** `POST /dm/conversations/{id}/read {lastMessageId}`: the read pointer moves forward only. */
  async markRead(callerId: string, conversationId: string, body: unknown): Promise<void> {
    const mine = await this.access(callerId, conversationId);
    const parsed = dmReadSchema.safeParse(body ?? {}, { reportInput: true });
    if (!parsed.success) throw AppException.validation(zodErrorToDetails(parsed.error));
    const message = await this.prisma.dmMessage.findFirst({
      where: {
        id: parsed.data.lastMessageId.toLowerCase(),
        conversationId: mine.conversationId,
        expiresAt: { gt: this.clock.now() },
      },
      select: { createdAt: true },
    });
    if (!message) throw AppException.validation([{ field: 'lastMessageId', issue: 'invalid_value' }]);
    await this.prisma.$executeRaw`
      UPDATE dm_participants SET read_at = GREATEST(COALESCE(read_at, ${message.createdAt}::timestamptz), ${message.createdAt}::timestamptz)
       WHERE conversation_id = ${mine.conversationId}::uuid AND user_id = ${callerId}::uuid`;
  }

  /** `POST /dm/conversations/{id}/accept` (idempotent). */
  async accept(callerId: string, conversationId: string): Promise<void> {
    const mine = await this.access(callerId, conversationId);
    if (mine.status === 'ACCEPTED') return;
    await this.prisma.dmParticipant.update({
      where: { conversationId_userId: { conversationId: mine.conversationId, userId: callerId } },
      data: { status: 'ACCEPTED' },
    });
  }

  /** `DELETE /dm/conversations/{id}`: everything up to now disappears for the caller. */
  async deleteConversation(callerId: string, conversationId: string): Promise<void> {
    const mine = await this.access(callerId, conversationId);
    await this.prisma.dmParticipant.update({
      where: { conversationId_userId: { conversationId: mine.conversationId, userId: callerId } },
      data: { clearedAt: this.clock.now() },
    });
  }

  /** `PUT` / `DELETE /dm/conversations/{id}/mute`. */
  async setMuted(callerId: string, conversationId: string, muted: boolean): Promise<void> {
    const mine = await this.access(callerId, conversationId);
    await this.prisma.dmParticipant.update({
      where: { conversationId_userId: { conversationId: mine.conversationId, userId: callerId } },
      data: { muted },
    });
  }

  /**
   * `DELETE /dm/messages/{id}?scope=`: `me` hides it for the caller; `everyone` — the caller's own,
   * within `DM_DELETE_FOR_EVERYONE_SECONDS` — makes it expire now (the sweeper deletes it and its file).
   */
  async deleteMessage(callerId: string, messageId: string, query: DmDeleteMessageQuery): Promise<void> {
    if (!isUuid(messageId)) throw notFound();
    const now = this.clock.now();
    const row = await this.prisma.dmMessage.findFirst({
      where: {
        id: messageId.toLowerCase(),
        OR: [{ senderId: callerId }, { recipientId: callerId }],
        expiresAt: { gt: now },
      },
      select: { id: true, senderId: true, conversationId: true, createdAt: true },
    });
    if (!row) throw notFound();
    await this.access(callerId, row.conversationId);
    if (query.scope === 'me') {
      await this.prisma.dmMessageHide.createMany({
        data: [{ messageId: row.id, userId: callerId, createdAt: now }],
        skipDuplicates: true,
      });
      return;
    }
    if (row.senderId !== callerId) throw new AppException(ErrorCode.AUTH_FORBIDDEN);
    if (now.getTime() - row.createdAt.getTime() > this.config.dm.deleteForEveryoneSeconds * 1000) {
      throw new AppException(ErrorCode.DM_DELETE_WINDOW_PASSED);
    }
    await this.prisma.dmMessage.updateMany({
      where: { id: row.id, expiresAt: { gt: now } },
      data: { expiresAt: now },
    });
  }
}
