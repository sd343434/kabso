import { Inject, Injectable, Logger, type OnModuleDestroy, type OnModuleInit } from '@nestjs/common';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { RateLimitService } from '../../common/rate-limit/rate-limit.service.js';
import { Clock } from '../../common/time/clock.js';
import type { Prisma } from '../../generated/prisma/client.js';
import { safeErrorLog } from '../../logging/redact-text.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { cpChatBubbleOf, cpEntranceOf, type LiveJoinCpDto } from '../cp-space/cp-privileges.js';
import { MediaService, type MediaAssetDto, type MediaKind } from '../media/media.service.js';
import {
  hostAgentCodeOf,
  rechargeAgentCodeOf,
  USER_SUMMARY_SELECT,
  userSummary,
} from '../posts/post-views.js';
import { UsersService, violatedUniqueIndex } from '../users/users.service.js';
import { LiveRoomsService, type RoomRow, type UserSummaryDto } from './live-rooms.service.js';
import { isUuid, parseLiveChatSend, type LiveChatKind } from './live.schemas.js';
import { maskBlockedWords } from './live-blocked-words.js';
import { LiveBlockedWordsService } from './live-blocked-words.service.js';
import {
  LiveChatBadgesService,
  NO_BADGES,
  type LiveChatAuthorBadgesDto,
} from './live-chat-badges.service.js';
import { LIVE_MEDIA_PROVIDER, type LiveMediaProvider } from './media/live-media.provider.js';

// ---- Response shapes (openapi v1.9-live, CP-013) -----------------------------------------------

export type LiveChatAuthorRole = 'HOST' | 'MODERATOR' | 'SPEAKER' | 'VIEWER';

/** `LiveChatMessage` (`kind`, `media`, `expiresAt`: CP-017). */
export interface LiveChatMessageDto {
  id: string;
  roomId: string;
  author: UserSummaryDto;
  authorRole: LiveChatAuthorRole;
  kind: LiveChatKind;
  /** Empty for VOICE and IMAGE. */
  text: string;
  /** The clip or picture of a VOICE or IMAGE message (null for TEXT, and once it expired). */
  media: MediaAssetDto | null;
  /** VOICE and IMAGE: 60 s after sending, when apps hide it; null for TEXT. */
  expiresAt: string | null;
  createdAt: string;
  /** v1.24-live (CP-021): the author's couple had the Exclusive Chat Bubble when it was sent. */
  cpBubble: boolean;
  /** v1.24.4-live (D119): the author's level and family badges now (cached up to 30 s). */
  authorBadges: LiveChatAuthorBadgesDto;
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
/** CP-017 (owner D104): voice clips and images vanish 60 s after sending. */
export const LIVE_CHAT_MEDIA_TTL_MS = 60_000;
/** The asset kind a VOICE or IMAGE message takes (CONVENTIONS §11.1). */
const MEDIA_KIND_OF: Readonly<Record<'VOICE' | 'IMAGE', MediaKind>> = {
  VOICE: 'LIVE_CHAT_VOICE',
  IMAGE: 'LIVE_CHAT_IMAGE',
};
/** Expired-media sweep: assets per batch and batches per run. */
const MEDIA_SWEEP_BATCH = 200;
const MEDIA_SWEEP_MAX_BATCHES = 20;

/** The data messages of topic `chat` (CONVENTIONS §10.11). */
export type LiveChatData =
  | { readonly type: 'chat'; readonly message: LiveChatMessageDto }
  | { readonly type: 'chat-delete'; readonly id: string }
  | { readonly type: 'join'; readonly user: UserSummaryDto; readonly cp: LiveJoinCpDto | null }
  | { readonly type: 'chat-state'; readonly enabled: boolean };

const MESSAGE_INCLUDE = { user: { select: USER_SUMMARY_SELECT }, media: true } as const;
type MessageRow = Prisma.LiveChatMessageGetPayload<{ include: typeof MESSAGE_INCLUDE }>;

/** Messages a read may still return: TEXT, or VOICE / IMAGE before they expire (CP-017). */
function notExpired(now: Date): Prisma.LiveChatMessageWhereInput {
  return { OR: [{ expiresAt: null }, { expiresAt: { gt: now } }] };
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
export class LiveChatService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(LiveChatService.name);
  /** Room → the tail of its broadcast chain (send order per room). */
  private readonly queues = new Map<string, Promise<void>>();
  private sweepTimer: NodeJS.Timeout | undefined;
  private sweepInFlight: Promise<unknown> | null = null;
  private stopped = false;

  constructor(
    private readonly prisma: PrismaService,
    private readonly rooms: LiveRoomsService,
    private readonly users: UsersService,
    private readonly limiter: RateLimitService,
    private readonly clock: Clock,
    @Inject(LIVE_MEDIA_PROVIDER) private readonly media: LiveMediaProvider,
    private readonly blockedWords: LiveBlockedWordsService,
    private readonly assets: MediaService,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
    private readonly badges: LiveChatBadgesService,
  ) {}

  onModuleInit(): void {
    if (this.config.live.sweepIntervalSeconds > 0) this.scheduleSweep();
  }

  async onModuleDestroy(): Promise<void> {
    this.stopped = true;
    if (this.sweepTimer) clearTimeout(this.sweepTimer);
    await this.sweepInFlight?.catch(() => undefined);
  }

  /** CP-017: the expired-media sweep at the live sweeper's cadence; one run at a time. */
  private scheduleSweep(): void {
    if (this.stopped) return;
    this.sweepTimer = setTimeout(() => {
      this.sweepInFlight = this.sweepExpiredMedia()
        .catch((err: unknown) => {
          this.logger.error({ error: safeErrorLog(err) }, 'Live chat media sweep failed');
        })
        .finally(() => {
          this.sweepInFlight = null;
          this.scheduleSweep();
        });
    }, this.config.live.sweepIntervalSeconds * 1000);
    this.sweepTimer.unref();
  }

  private toDto(row: MessageRow, authorBadges: LiveChatAuthorBadgesDto): LiveChatMessageDto {
    return {
      id: row.id,
      roomId: row.roomId,
      author: userSummary(row.user),
      authorRole: row.authorRole,
      kind: row.kind,
      text: row.text,
      media: row.media ? this.assets.toDto(row.media) : null,
      expiresAt: row.expiresAt?.toISOString() ?? null,
      createdAt: row.createdAt.toISOString(),
      cpBubble: row.cpBubble,
      authorBadges,
    };
  }

  /** One message with its author's badges (D119). */
  private async withBadges(row: MessageRow): Promise<LiveChatMessageDto> {
    return this.toDto(row, await this.badges.one(row.userId));
  }

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
   * by the same sender → the first message (`created` false, nothing sent again), not kicked out
   * of this live (403 LIVE_KICKED, v1.20-live), the caller in the room (403 LIVE_CHAT_NOT_IN_ROOM), not muted (403 LIVE_CHAT_MUTED), the chat on (409
   * LIVE_CHAT_CLOSED; the host may still send), and the counting rule (429 with `Retry-After`).
   * CP-017: a VOICE or IMAGE message then takes the caller's unattached `LIVE_CHAT_VOICE` /
   * `LIVE_CHAT_IMAGE` asset (else 400 `mediaId` / `invalid_value`) and expires 60 s later.
   */
  async send(
    callerId: string,
    roomId: string,
    body: unknown,
  ): Promise<{ created: boolean; message: LiveChatMessageDto }> {
    const row = await this.rooms.visibleRow(roomId, callerId);
    if (row.status !== 'LIVE') throw new AppException(ErrorCode.LIVE_ROOM_ENDED);
    const parsed = parseLiveChatSend(body);
    if (!parsed.success) throw AppException.validation(parsed.details);
    const input = parsed.data;
    const clientId = input.clientId.toLowerCase();

    const first = await this.byClientId(callerId, clientId);
    if (first) return { created: false, message: await this.withBadges(first) };

    const isHost = callerId === row.host_user_id;
    if (!isHost) {
      // v1.20-live (D105, §10.20): kicked out of this live.
      if (row.kicked) throw new AppException(ErrorCode.LIVE_KICKED);
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
      if (stored) return { created: false, message: await this.withBadges(stored) };
      throw new AppException(ErrorCode.RATE_LIMITED, undefined, undefined, {
        'Retry-After': String(Math.max(1, Math.ceil(waitMs / 1000))),
      });
    }

    const authorRole = await this.roleOf(row, callerId);
    // v1.24-live (CP-021, §10.24): the Exclusive Chat Bubble of the author's couple.
    const cpBubble = await cpChatBubbleOf(this.prisma, callerId);
    let created: MessageRow;
    try {
      if (input.kind === 'TEXT') {
        // CP-016 B: the host's blocked words are masked before the message is stored or sent.
        const shown = maskBlockedWords(input.text, await this.blockedWords.wordsOf(row.host_user_id));
        created = await this.prisma.liveChatMessage.create({
          data: {
            roomId: row.id,
            userId: callerId,
            clientId,
            text: shown,
            authorRole,
            cpBubble,
            createdAt: now,
          },
          include: MESSAGE_INCLUDE,
        });
      } else {
        const { kind, mediaId } = input;
        created = await this.prisma.$transaction(async (tx) => {
          const claimed = await this.assets.claimAssetsIn(tx, callerId, [mediaId], MEDIA_KIND_OF[kind]);
          if (!claimed) throw AppException.validation([{ field: 'mediaId', issue: 'invalid_value' }]);
          return tx.liveChatMessage.create({
            data: {
              roomId: row.id,
              userId: callerId,
              clientId,
              kind,
              text: '',
              mediaId: mediaId.toLowerCase(),
              expiresAt: new Date(now.getTime() + LIVE_CHAT_MEDIA_TTL_MS),
              authorRole,
              cpBubble,
              createdAt: now,
            },
            include: MESSAGE_INCLUDE,
          });
        });
      }
    } catch (err) {
      // A concurrent request with the same clientId won: answer with its message.
      if (violatedUniqueIndex(err) !== null) {
        const raced = await this.byClientId(callerId, clientId);
        if (raced) return { created: false, message: await this.withBadges(raced) };
      }
      throw err;
    }
    const message = await this.withBadges(created);
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
   * `GET /live/rooms/{roomId}/chat`: the last 50 messages, oldest first, without deleted ones,
   * expired voice clips and images (CP-017) or those of inactive accounts; a signed-in reader gets none from someone they blocked or who
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
        ...notExpired(this.clock.now()),
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
    const badges = await this.badges.of(rows.map((r) => r.userId));
    return { data: rows.reverse().map((r) => this.toDto(r, badges.get(r.userId) ?? NO_BADGES)) };
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
      const user = await this.prisma.user.findUnique({ where: { id: userId }, select: USER_SUMMARY_SELECT });
      if (!user) return;
      // v1.54-social (D185, §10.48): an ACTIVE recharge agent's join (its entrance bar) is never dropped;
      // v1.58-social (D189, §10.52): nor a host agent's.
      const agent = rechargeAgentCodeOf(user) !== null || hostAgentCodeOf(user) !== null;
      const waitMs = await this.limiter.interval(
        'live:chat:join',
        roomId,
        this.clock.now().getTime(),
        LIVE_CHAT_JOIN_INTERVAL_MS,
      );
      if (waitMs > 0 && !agent) return;
      // v1.24-live (CP-021, §10.24): the couple's Entrance Effect ("X ❤ Y entered").
      const cp = await cpEntranceOf(this.prisma, userId);
      await this.broadcast(roomId, { type: 'join', user: userSummary(user), cp });
    } catch (err) {
      this.logger.warn({ error: safeErrorLog(err) }, 'Could not announce a join in the live chat');
    }
  }

  // ---- Reports (CONVENTIONS §11.7) --------------------------------------------------------------

  /**
   * A message `reporterId` could read (§10.11): not deleted nor expired (CP-017), in a room they
   * may see, by an active author with no block either way; else 404. Returns its id and author.
   */
  async readableMessage(messageId: string, reporterId: string): Promise<{ id: string; userId: string }> {
    const message = await this.prisma.liveChatMessage.findFirst({
      where: {
        id: messageId,
        deletedAt: null,
        ...notExpired(this.clock.now()),
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

  // ---- CP-017: expired voice clips and images --------------------------------------------------

  /**
   * Deletes the assets of VOICE and IMAGE messages that expired (`expires_at` ≤ now): their
   * objects, then their rows (the message keeps its row, with `media_id` NULL, and is no longer
   * returned). Bounded batches; a storage failure stops the run and the next one retries.
   */
  async sweepExpiredMedia(now: Date = this.clock.now()): Promise<number> {
    let removed = 0;
    for (let batch = 0; batch < MEDIA_SWEEP_MAX_BATCHES; batch += 1) {
      const expired = await this.prisma.liveChatMessage.findMany({
        where: { mediaId: { not: null }, expiresAt: { lte: now } },
        orderBy: { expiresAt: 'asc' },
        take: MEDIA_SWEEP_BATCH,
        select: { media: { select: { id: true, largeKey: true, thumbKey: true } } },
      });
      const assets = expired.flatMap((m) => (m.media ? [m.media] : []));
      if (assets.length === 0) break;
      removed += await this.assets.purgeAssets(assets);
      if (expired.length < MEDIA_SWEEP_BATCH) break;
    }
    return removed;
  }
}
