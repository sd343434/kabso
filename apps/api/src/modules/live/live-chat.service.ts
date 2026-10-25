import { Inject, Injectable, Logger } from '@nestjs/common';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { RateLimitService } from '../../common/rate-limit/rate-limit.service.js';
import { Clock } from '../../common/time/clock.js';
import { zodErrorToDetails } from '../../common/validation/zod-validation.pipe.js';
import type { Prisma } from '../../generated/prisma/client.js';
import { safeErrorLog } from '../../logging/redact-text.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { USER_SUMMARY_SELECT, userSummary } from '../posts/post-views.js';
import { UsersService, violatedUniqueIndex } from '../users/users.service.js';
import { LiveRoomsService, type RoomRow, type UserSummaryDto } from './live-rooms.service.js';
import { isUuid, liveChatSendSchema } from './live.schemas.js';
import { maskBlockedWords } from './live-blocked-words.js';
import { LiveBlockedWordsService } from './live-blocked-words.service.js';
import { LIVE_MEDIA_PROVIDER, type LiveMediaProvider } from './media/live-media.provider.js';

// ---- Response shapes (openapi v1.9-live, CP-013) -----------------------------------------------

export type LiveChatAuthorRole = 'HOST' | 'MODERATOR' | 'SPEAKER' | 'VIEWER';

/** `LiveChatMessage`. */
export interface LiveChatMessageDto {
  id: string;
  roomId: string;
  author: UserSummaryDto;
  authorRole: LiveChatAuthorRole;
  text: string;
  createdAt: string;
}

/** `LiveChatMute`. */
export interface LiveChatMuteDto {
  user: UserSummaryDto;
  mutedAt: string;
}

/** The media data topic of every chat data message (CONVENTIONS §10.11). */
export const LIVE_CHAT_TOPIC = 'chat';
/** `GET …/chat` returns at most the last 50 messages (owner D96). */
export const LIVE_CHAT_LIST_MAX = 50;
/** Counting rule: at most one message a second per user and room (CONVENTIONS §7, §10.11). */
export const LIVE_CHAT_SEND_INTERVAL_MS = 1_000;
/** At most one "joined" line a second per room; extras are dropped (owner D96). */
export const LIVE_CHAT_JOIN_INTERVAL_MS = 1_000;

/** The data messages of topic `chat` (CONVENTIONS §10.11). */
export type LiveChatData =
  | { readonly type: 'chat'; readonly message: LiveChatMessageDto }
  | { readonly type: 'chat-delete'; readonly id: string }
  | { readonly type: 'join'; readonly user: UserSummaryDto }
  | { readonly type: 'chat-state'; readonly enabled: boolean };

const MESSAGE_INCLUDE = { user: { select: USER_SUMMARY_SELECT } } as const;
type MessageRow = Prisma.LiveChatMessageGetPayload<{ include: typeof MESSAGE_INCLUDE }>;

function toDto(row: MessageRow): LiveChatMessageDto {
  return {
    id: row.id,
    roomId: row.roomId,
    author: userSummary(row.user),
    authorRole: row.authorRole,
    text: row.text,
    createdAt: row.createdAt.toISOString(),
  };
}

function forbidden(): AppException {
  return new AppException(ErrorCode.AUTH_FORBIDDEN);
}

function notFound(): AppException {
  return new AppException(ErrorCode.NOT_FOUND);
}

/**
 * Live room chat (CP-013, D96, CONVENTIONS §10.11): sending (checks, idempotent retry by
 * `clientId`, the 1-a-second counting rule), the last 50 messages, delete, chat mutes, the host's
 * chat switch, "joined" lines, and the hooks the reports queue uses.
 *
 * Every line reaches the room as a reliable media data message on topic `chat`, sent by the server
 * after the change committed (apps never publish data). Delivery is best effort like the seat
 * effects (a room that is not open on the media server answers with an error, logged and
 * ignored), and messages of one room are sent one after another in the order they were committed
 * in this instance.
 */
@Injectable()
export class LiveChatService {
  private readonly logger = new Logger(LiveChatService.name);
  /** Room → the tail of its broadcast chain (send order per room). */
  private readonly queues = new Map<string, Promise<void>>();

  constructor(
    private readonly prisma: PrismaService,
    private readonly rooms: LiveRoomsService,
    private readonly users: UsersService,
    private readonly limiter: RateLimitService,
    private readonly clock: Clock,
    @Inject(LIVE_MEDIA_PROVIDER) private readonly media: LiveMediaProvider,
    private readonly blockedWords: LiveBlockedWordsService,
  ) {}

  // ---- Delivery --------------------------------------------------------------------------------

  /** Sends `data` to everyone in the room after the data sent before it (best effort). */
  broadcast(roomId: string, data: LiveChatData): Promise<void> {
    const payload = JSON.stringify(data);
    const previous = this.queues.get(roomId) ?? Promise.resolve();
    const next = previous
      .then(() => this.media.broadcastData(roomId, LIVE_CHAT_TOPIC, payload))
      .catch((err: unknown) => {
        this.logger.warn(
          { type: data.type, error: safeErrorLog(err) },
          'Could not send a chat data message to the media room',
        );
      });
    this.queues.set(roomId, next);
    void next.finally(() => {
      if (this.queues.get(roomId) === next) this.queues.delete(roomId);
    });
    return next;
  }

  // ---- Roles -----------------------------------------------------------------------------------

  private async isModerator(roomId: string, userId: string): Promise<boolean> {
    return (await this.prisma.liveRoomModerator.count({ where: { roomId, userId } })) > 0;
  }

  /** The caller's privilege in the room: HOST, MODERATOR or none (→ 403). */
  private async privilege(row: RoomRow, callerId: string): Promise<'HOST' | 'MODERATOR'> {
    if (callerId === row.host_user_id) return 'HOST';
    if (await this.isModerator(row.id, callerId)) return 'MODERATOR';
    throw forbidden();
  }

  /** `authorRole` now: HOST, MODERATOR, SPEAKER (seated) or VIEWER. */
  private async roleOf(row: RoomRow, userId: string): Promise<LiveChatAuthorRole> {
    if (userId === row.host_user_id) return 'HOST';
    if (await this.isModerator(row.id, userId)) return 'MODERATOR';
    const seated = await this.prisma.liveRoomSeat.count({ where: { roomId: row.id, userId } });
    return seated > 0 ? 'SPEAKER' : 'VIEWER';
  }

  /** In the room now: a row in the room's media session (CP-010 `live_room_viewers`). */
  private async inMediaSession(roomId: string, userId: string): Promise<boolean> {
    return (await this.prisma.liveRoomViewer.count({ where: { roomId, userId } })) > 0;
  }

  // ---- Sending ---------------------------------------------------------------------------------

  /**
   * `POST /live/rooms/{roomId}/chat`. Checks in the order of §10.11 after the auth guard: visible
   * room (404), LIVE (409 LIVE_ROOM_ENDED), the body (400), then a retry with the same `clientId`
   * by the same sender → the first message (`created` false, nothing sent again), the caller in
   * the room (403 LIVE_CHAT_NOT_IN_ROOM), not muted (403 LIVE_CHAT_MUTED), the chat on (409
   * LIVE_CHAT_CLOSED; the host may still send), and the counting rule (429 with `Retry-After`).
   */
  async send(
    callerId: string,
    roomId: string,
    body: unknown,
  ): Promise<{ created: boolean; message: LiveChatMessageDto }> {
    const row = await this.rooms.visibleRow(roomId, callerId);
    if (row.status !== 'LIVE') throw new AppException(ErrorCode.LIVE_ROOM_ENDED);
    const parsed = liveChatSendSchema.safeParse(body ?? {}, { reportInput: true });
    if (!parsed.success) throw AppException.validation(zodErrorToDetails(parsed.error));
    const { text } = parsed.data;
    const clientId = parsed.data.clientId.toLowerCase();

    const first = await this.byClientId(callerId, clientId);
    if (first) return { created: false, message: toDto(first) };

    const isHost = callerId === row.host_user_id;
    if (!isHost) {
      if (!(await this.inMediaSession(row.id, callerId))) {
        throw new AppException(ErrorCode.LIVE_CHAT_NOT_IN_ROOM);
      }
      if (row.chat_muted) throw new AppException(ErrorCode.LIVE_CHAT_MUTED);
      if (!row.chat_enabled) throw new AppException(ErrorCode.LIVE_CHAT_CLOSED);
    }
    const now = this.clock.now();
    const waitMs = await this.limiter.interval(
      'live:chat:second',
      `${callerId}:${row.id}`,
      now.getTime(),
      LIVE_CHAT_SEND_INTERVAL_MS,
    );
    if (waitMs > 0) {
      // A concurrent request with the same clientId may have stored it meanwhile: still a retry.
      const stored = await this.byClientId(callerId, clientId);
      if (stored) return { created: false, message: toDto(stored) };
      throw new AppException(ErrorCode.RATE_LIMITED, undefined, undefined, {
        'Retry-After': String(Math.max(1, Math.ceil(waitMs / 1000))),
      });
    }

    // CP-016 B: the host's blocked words are masked before the message is stored or sent.
    const shown = maskBlockedWords(text, await this.blockedWords.wordsOf(row.host_user_id));
    let created: MessageRow;
    try {
      created = await this.prisma.liveChatMessage.create({
        data: {
          roomId: row.id,
          userId: callerId,
          clientId,
          text: shown,
          authorRole: await this.roleOf(row, callerId),
          createdAt: now,
        },
        include: MESSAGE_INCLUDE,
      });
    } catch (err) {
      // A concurrent request with the same clientId won: answer with its message.
      if (violatedUniqueIndex(err) !== null) {
        const raced = await this.byClientId(callerId, clientId);
        if (raced) return { created: false, message: toDto(raced) };
      }
      throw err;
    }
    const message = toDto(created);
    await this.broadcast(row.id, { type: 'chat', message });
    return { created: true, message };
  }

  private byClientId(userId: string, clientId: string): Promise<MessageRow | null> {
    return this.prisma.liveChatMessage.findUnique({
      where: { userId_clientId: { userId, clientId } },
      include: MESSAGE_INCLUDE,
    });
  }

  // ---- Reading ---------------------------------------------------------------------------------

  /**
   * `GET /live/rooms/{roomId}/chat`: the last 50 messages, oldest first, without deleted ones or
   * those of inactive accounts; a signed-in reader gets none from someone they blocked or who
   * blocked them. Guests need the room's `allowGuests` (403 LIVE_GUESTS_NOT_ALLOWED). Ended rooms
   * too.
   */
  async list(callerId: string | null, roomId: string): Promise<{ data: LiveChatMessageDto[] }> {
    const row = await this.rooms.visibleRow(roomId, callerId);
    if (callerId === null && !row.allow_guests) throw new AppException(ErrorCode.LIVE_GUESTS_NOT_ALLOWED);
    const rows = await this.prisma.liveChatMessage.findMany({
      where: {
        roomId: row.id,
        deletedAt: null,
        user: {
          status: 'ACTIVE',
          ...(callerId === null
            ? {}
            : {
                blocking: { none: { blockedId: callerId } },
                blockedBy: { none: { blockerId: callerId } },
              }),
        },
      },
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
      take: LIVE_CHAT_LIST_MAX,
      include: MESSAGE_INCLUDE,
    });
    return { data: rows.reverse().map(toDto) };
  }

  // ---- Moderation ------------------------------------------------------------------------------

  /**
   * `DELETE /live/rooms/{roomId}/chat/{messageId}`: the author, the host or a moderator (a
   * moderator never deletes the host's or another moderator's message → 403). Visible room and a
   * message of it (404) → LIVE (409) → permission (403) → already deleted (204, nothing sent).
   */
  async remove(callerId: string, roomId: string, messageId: string): Promise<void> {
    const row = await this.rooms.visibleRow(roomId, callerId);
    if (!isUuid(messageId)) throw notFound();
    const message = await this.prisma.liveChatMessage.findFirst({
      where: { id: messageId.toLowerCase(), roomId: row.id },
      select: { id: true, userId: true, deletedAt: true },
    });
    if (!message) throw notFound();
    if (row.status !== 'LIVE') throw new AppException(ErrorCode.LIVE_ROOM_ENDED);
    if (message.userId !== callerId) {
      const privilege = await this.privilege(row, callerId);
      if (
        privilege === 'MODERATOR' &&
        (message.userId === row.host_user_id || (await this.isModerator(row.id, message.userId)))
      ) {
        throw forbidden();
      }
    }
    if (message.deletedAt !== null) return;
    const deleted = await this.prisma.liveChatMessage.updateMany({
      where: { id: message.id, deletedAt: null },
      data: { deletedAt: this.clock.now(), deletedById: callerId },
    });
    if (deleted.count > 0) await this.broadcast(row.id, { type: 'chat-delete', id: message.id });
  }

  /**
   * `PUT` (`muted` true) and `DELETE` (false) `/live/rooms/{roomId}/chat/mutes/{username}`: host or
   * moderator; idempotent. Visible room (404) → LIVE (409) → privilege (403) → the user (404) →
   * nobody acts on the host, a moderator never on a moderator (themselves included) (403).
   */
  async setMuted(callerId: string, roomId: string, username: string, muted: boolean): Promise<void> {
    const row = await this.rooms.visibleRow(roomId, callerId);
    if (row.status !== 'LIVE') throw new AppException(ErrorCode.LIVE_ROOM_ENDED);
    const privilege = await this.privilege(row, callerId);
    const target = await this.users.findActivePublicUser(username);
    if (!target) throw notFound();
    if (target.id === row.host_user_id) throw forbidden();
    if (privilege === 'MODERATOR' && (await this.isModerator(row.id, target.id))) throw forbidden();
    if (muted) {
      await this.prisma.liveChatMute.createMany({
        data: [{ roomId: row.id, userId: target.id, mutedById: callerId, createdAt: this.clock.now() }],
        skipDuplicates: true,
      });
    } else {
      await this.prisma.liveChatMute.deleteMany({ where: { roomId: row.id, userId: target.id } });
    }
  }

  /** `GET /live/rooms/{roomId}/chat/mutes` (host or moderator): newest first. */
  async listMutes(callerId: string, roomId: string): Promise<{ data: LiveChatMuteDto[] }> {
    const row = await this.rooms.visibleRow(roomId, callerId);
    await this.privilege(row, callerId);
    const rows = await this.prisma.liveChatMute.findMany({
      where: { roomId: row.id, user: { status: 'ACTIVE' } },
      orderBy: [{ createdAt: 'desc' }, { userId: 'desc' }],
      include: { user: { select: USER_SUMMARY_SELECT } },
    });
    return { data: rows.map((r) => ({ user: userSummary(r.user), mutedAt: r.createdAt.toISOString() })) };
  }

  /** The host turned the chat off or on (`PATCH`, after the change committed). */
  async stateChanged(roomId: string, enabled: boolean): Promise<void> {
    await this.broadcast(roomId, { type: 'chat-state', enabled });
  }

  // ---- "Joined" lines --------------------------------------------------------------------------

  /**
   * A signed-in viewer joined the room's media session (webhook or reconciliation): one `join`
   * line, at most one a second per room (extras dropped, owner D96). Best effort: a limiter or
   * media failure only drops the line.
   */
  async announceJoin(roomId: string, userId: string): Promise<void> {
    try {
      const waitMs = await this.limiter.interval(
        'live:chat:join',
        roomId,
        this.clock.now().getTime(),
        LIVE_CHAT_JOIN_INTERVAL_MS,
      );
      if (waitMs > 0) return;
      const user = await this.prisma.user.findUnique({ where: { id: userId }, select: USER_SUMMARY_SELECT });
      if (!user) return;
      await this.broadcast(roomId, { type: 'join', user: userSummary(user) });
    } catch (err) {
      this.logger.warn({ error: safeErrorLog(err) }, 'Could not announce a join in the live chat');
    }
  }

  // ---- Reports (CONVENTIONS §11.7) --------------------------------------------------------------

  /**
   * A message `reporterId` could read (§10.11): not deleted, in a room they may see, by an active
   * author with no block either way; else 404. Returns its id and author.
   */
  async readableMessage(messageId: string, reporterId: string): Promise<{ id: string; userId: string }> {
    const message = await this.prisma.liveChatMessage.findFirst({
      where: {
        id: messageId,
        deletedAt: null,
        user: {
          status: 'ACTIVE',
          blocking: { none: { blockedId: reporterId } },
          blockedBy: { none: { blockerId: reporterId } },
        },
      },
      select: { id: true, roomId: true, userId: true },
    });
    if (!message) throw notFound();
    await this.rooms.visibleRow(message.roomId, reporterId);
    return { id: message.id, userId: message.userId };
  }

  /**
   * Report action `REMOVE_TARGET`, inside the caller's transaction: soft-deletes the message.
   * Returns its room when this call deleted it (the caller sends `chat-delete` after the commit
   * with {@link afterRemoved}), else null.
   */
  async removeIn(tx: Prisma.TransactionClient, messageId: string, actorId: string): Promise<string | null> {
    const message = await tx.liveChatMessage.findUnique({
      where: { id: messageId },
      select: { roomId: true, deletedAt: true },
    });
    if (!message || message.deletedAt !== null) return null;
    const deleted = await tx.liveChatMessage.updateMany({
      where: { id: messageId, deletedAt: null },
      data: { deletedAt: this.clock.now(), deletedById: actorId },
    });
    return deleted.count > 0 ? message.roomId : null;
  }

  /** After {@link removeIn} committed: the room's apps drop the line. */
  async afterRemoved(roomId: string, messageId: string): Promise<void> {
    await this.broadcast(roomId, { type: 'chat-delete', id: messageId });
  }
}
