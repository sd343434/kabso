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
  activeVipOf,
  hostAgentCodeOf,
  rechargeAgentCodeOf,
  USER_SUMMARY_SELECT,
  userSummary,
} from '../posts/post-views.js';
import { UsersService, violatedUniqueIndex } from '../users/users.service.js';
import {
  LiveRoomsService,
  LIVE_TX_OPTIONS,
  type RoomRow,
  type UserSummaryDto,
} from './live-rooms.service.js';
import { isUuid, parseLiveChatSend, type LiveChatKind } from './live.schemas.js';
import { maskBlockedWords } from './live-blocked-words.js';
import { LiveBlockedWordsService } from './live-blocked-words.service.js';
import {
  LiveChatBadgesService,
  NO_BADGES,
  type LiveChatAuthorBadgesDto,
} from './live-chat-badges.service.js';
import { LIVE_MEDIA_PROVIDER, type LiveMediaProvider } from './media/live-media.provider.js';
import { assertNotRestricted } from '../users/account-control.js';
import { storeWearOf, wearHasEntrance } from '../store/store-rules.js';
import { assertNotStaffTarget, isLimitedStaff, refuseWatchStaff, watchStaffAmong } from './live-staff.js';
import { vipLivePerkIn, vipPinValue } from '../vip/vip-live-perks.js';
import { programWindowsIn } from '../programs/programs-time.js';
import { liveChatPinSchema } from './live.schemas.js';
import { zodErrorToDetails } from '../../common/validation/zod-validation.pipe.js';

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
  /**
   * v1.68-live (D273, §10.96.6): the author is «فريق كابسو» now (a watch role): the app shows the team's tag instead of
   * levels, family, VIP and the CP bubble (`authorBadges` is then empty). Read live, so a revoked role drops it.
   */
  authorStaff: boolean;
}

/**
 * v1.132-social (D379, §10.169): `LiveChatPin` — a VIP member's own message pinned at the top of the live's chat
 * «تثبيت رسالتك أعلى الدردشة» until `until` (apps hide it then, or on `chat-unpin` / the message's `chat-delete`).
 */
export interface LiveChatPinDto {
  id: string;
  roomId: string;
  messageId: string;
  author: UserSummaryDto;
  /** The text as pinned (the host's blocked words masked again). */
  text: string;
  pinnedAt: string;
  until: string;
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
/**
 * At most one "joined" line per this interval per room; extras are dropped. Owner D96: one a second;
 * owner D212 («دخول الأشخاص … كل واحد برسالة»): every join is its own line, so up to 5 a second —
 * only a burst above that (a raid, a big host going live) loses lines (§10.69).
 */
export const LIVE_CHAT_JOIN_INTERVAL_MS = 200;
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
  | {
      readonly type: 'join';
      readonly user: UserSummaryDto;
      readonly cp: LiveJoinCpDto | null;
      /**
       * v1.47-live (D212): the joiner's gender for the line's grammar («دخل» / «دخلت») — only when
       * they show it on their profile (D175: private by default); else null (a neutral line).
       */
      readonly gender: 'MALE' | 'FEMALE' | null;
      /**
       * v1.132-social (D379, §10.169): the joiner holds HOST_GREETING «تحية المضيف الآلية» — the HOST's app (only the
       * host's) shows the «VIP دخل البث» card with «رحّب»; every other app ignores it. Always sent (false otherwise).
       */
      readonly hostGreeting: boolean;
    }
  | { readonly type: 'chat-state'; readonly enabled: boolean }
  /** v1.132-social (D379, §10.169): a pin shows (it replaces none: one at a time) / was taken down early. */
  | { readonly type: 'chat-pin'; readonly pin: LiveChatPinDto }
  | { readonly type: 'chat-unpin'; readonly id: string }
  /**
   * v1.72-live (D283, §10.96.10): a limited Kabso Team account entered VISIBLY as «فريق كابسو» (never a hidden
   * watch): the apps play the team's entry car once; no chat line (D273).
   */
  | { readonly type: 'staff-join'; readonly user: UserSummaryDto };

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

  private toDto(
    row: MessageRow,
    authorBadges: LiveChatAuthorBadgesDto,
    authorStaff = false,
  ): LiveChatMessageDto {
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
      cpBubble: authorStaff ? false : row.cpBubble,
      authorBadges: authorStaff ? NO_BADGES : authorBadges,
      authorStaff,
    };
  }

  /** One message with its author's badges (D119) and, D273, whether the author is «فريق كابسو». */
  private async withBadges(row: MessageRow): Promise<LiveChatMessageDto> {
    const staff = await watchStaffAmong(this.prisma, [row.userId]);
    return this.toDto(row, await this.badges.one(row.userId), staff.has(row.userId));
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

  /**
   * In the room now: a row in the room's media session (CP-010 `live_room_viewers`); v1.68-live (D273): or watching it
   * visibly as «فريق كابسو» (`live_room_staff_watchers`). A hidden observer has neither (no chat).
   */
  private async inMediaSession(roomId: string, userId: string): Promise<boolean> {
    if ((await this.prisma.liveRoomViewer.count({ where: { roomId, userId } })) > 0) return true;
    return (await this.prisma.liveRoomStaffWatcher.count({ where: { roomId, adminId: userId } })) > 0;
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
    // v1.72-social (D208, §10.67): the team's restriction of the caller, if any (403 ACCOUNT_RESTRICTED).
    await assertNotRestricted(this.prisma, callerId, 'CHAT_MUTE');

    const isHost = callerId === row.host_user_id;
    if (!isHost) {
      // v1.20-live (D105, §10.20): kicked out of this live.
      if (row.kicked) throw new AppException(ErrorCode.LIVE_KICKED);
      if (!(await this.inMediaSession(row.id, callerId))) {
        // v1.68-live (D273): a hidden staff observer never writes in the chat.
        await refuseWatchStaff(this.prisma, callerId, 'hidden_chat');
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
  async list(
    callerId: string | null,
    roomId: string,
  ): Promise<{ data: LiveChatMessageDto[]; pin: LiveChatPinDto | null }> {
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
    const staff = await watchStaffAmong(
      this.prisma,
      rows.map((r) => r.userId),
    );
    return {
      data: rows.reverse().map((r) => this.toDto(r, badges.get(r.userId) ?? NO_BADGES, staff.has(r.userId))),
      // v1.132-social (D379): the pin showing now (a reader who blocked its author, or was blocked, sees none).
      pin: row.status === 'LIVE' ? await this.currentPin(row.id, callerId) : null,
    };
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
      // v1.68-live (D273, §10.96.7): nobody removes a message of «فريق كابسو».
      await assertNotStaffTarget(this.prisma, message.userId);
    }
    if (message.deletedAt !== null) return;
    const deleted = await this.prisma.liveChatMessage.updateMany({
      where: { id: message.id, deletedAt: null },
      data: { deletedAt: this.clock.now(), deletedById: callerId },
    });
    if (deleted.count > 0) {
      await this.dropPinsOf(this.prisma, message.id, callerId);
      await this.broadcast(row.id, { type: 'chat-delete', id: message.id });
    }
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
    // v1.68-live (D273, §10.96.7): «فريق كابسو» is never chat-muted (lifting an old mute is allowed).
    if (muted) await assertNotStaffTarget(this.prisma, target.id);
    if (muted) {
      await this.prisma.liveChatMute.createMany({
        data: [{ roomId: row.id, userId: target.id, mutedById: callerId, createdAt: this.clock.now() }],
        skipDuplicates: true,
      });
    } else {
      await this.prisma.liveChatMute.deleteMany({ where: { roomId: row.id, userId: target.id } });
    }
  }

  /**
   * v1.68-live (D273, §10.96.6): «فريق كابسو» removes a message from the staff tools (the staff guard checked the role
   * and the step-up; the caller audits it). Any message of the live but one of the team's own (403 STAFF_PROTECTED).
   * Returns the author and whether this call deleted it (already deleted → false, nothing sent).
   */
  async removeAsStaff(
    roomId: string,
    messageId: string,
    actorId: string,
  ): Promise<{ authorId: string; deleted: boolean }> {
    const row = await this.rooms.visibleRow(roomId, actorId);
    if (!isUuid(messageId)) throw notFound();
    const message = await this.prisma.liveChatMessage.findFirst({
      where: { id: messageId.toLowerCase(), roomId: row.id },
      select: { id: true, userId: true, deletedAt: true },
    });
    if (!message) throw notFound();
    if (row.status !== 'LIVE') throw new AppException(ErrorCode.LIVE_ROOM_ENDED);
    if (message.userId !== actorId) await assertNotStaffTarget(this.prisma, message.userId);
    if (message.deletedAt !== null) return { authorId: message.userId, deleted: false };
    const deleted = await this.prisma.liveChatMessage.updateMany({
      where: { id: message.id, deletedAt: null },
      data: { deletedAt: this.clock.now(), deletedById: actorId },
    });
    if (deleted.count > 0) {
      await this.dropPinsOf(this.prisma, message.id, actorId);
      await this.broadcast(row.id, { type: 'chat-delete', id: message.id });
    }
    return { authorId: message.userId, deleted: deleted.count > 0 };
  }

  /**
   * v1.68-live (D273, §10.96.6): «فريق كابسو» mutes (or unmutes) someone in this live's chat from the staff tools.
   * Never the host (409 via the caller) nor the team (403 STAFF_PROTECTED). Returns the person and whether it changed.
   */
  async muteAsStaff(
    roomId: string,
    username: string,
    actorId: string,
    muted: boolean,
  ): Promise<{ userId: string; hostUserId: string; changed: boolean }> {
    const row = await this.rooms.visibleRow(roomId, actorId);
    if (row.status !== 'LIVE') throw new AppException(ErrorCode.LIVE_ROOM_ENDED);
    const target = await this.users.findActivePublicUser(username);
    if (!target) throw notFound();
    if (target.id === row.host_user_id || target.id === actorId) {
      return { userId: target.id, hostUserId: row.host_user_id, changed: false };
    }
    if (muted) await assertNotStaffTarget(this.prisma, target.id);
    if (muted) {
      const out = await this.prisma.liveChatMute.createMany({
        data: [{ roomId: row.id, userId: target.id, mutedById: actorId, createdAt: this.clock.now() }],
        skipDuplicates: true,
      });
      return { userId: target.id, hostUserId: row.host_user_id, changed: out.count > 0 };
    }
    const out = await this.prisma.liveChatMute.deleteMany({ where: { roomId: row.id, userId: target.id } });
    return { userId: target.id, hostUserId: row.host_user_id, changed: out.count > 0 };
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
  /**
   * v1.72-live (D283): a limited Kabso Team account's visible entry (its `team:` identity joined): one `staff-join`
   * (the team entry car in the apps). Never for the OWNER or a hidden watch. Best effort.
   */
  async announceStaffJoin(roomId: string, userId: string): Promise<void> {
    try {
      if (!(await isLimitedStaff(this.prisma, userId))) return;
      const user = await this.prisma.user.findUnique({ where: { id: userId }, select: USER_SUMMARY_SELECT });
      if (!user) return;
      await this.broadcast(roomId, { type: 'staff-join', user: userSummary(user) });
    } catch (err) {
      this.logger.warn({ error: safeErrorLog(err) }, 'Could not announce a staff entry in the live');
    }
  }

  async announceJoin(roomId: string, userId: string): Promise<void> {
    try {
      const user = await this.prisma.user.findUnique({ where: { id: userId }, select: USER_SUMMARY_SELECT });
      if (!user) return;
      const shown = await this.prisma.userProfile.findUnique({
        where: { userId },
        select: { gender: true, showGender: true },
      });
      const gender =
        shown?.showGender === true && (shown.gender === 'MALE' || shown.gender === 'FEMALE')
          ? shown.gender
          : null;
      // v1.54-social (D185, §10.48): an ACTIVE recharge agent's join (its entrance bar) is never dropped;
      // v1.58-social (D189, §10.52): nor a host agent's; D265 (§10.94): nor a VIP member's (their entry car).
      const agent =
        rechargeAgentCodeOf(user) !== null ||
        hostAgentCodeOf(user) !== null ||
        activeVipOf(user, this.clock.now()) !== null ||
        // D270 (§10.98): nor one wearing a store entry banner or car.
        wearHasEntrance(storeWearOf(user.bagItems, this.clock.now()));
      const waitMs = await this.limiter.interval(
        'live:chat:join',
        roomId,
        this.clock.now().getTime(),
        LIVE_CHAT_JOIN_INTERVAL_MS,
      );
      if (waitMs > 0 && !agent) return;
      // v1.24-live (CP-021, §10.24): the couple's Entrance Effect ("X ❤ Y entered").
      const cp = await cpEntranceOf(this.prisma, userId);
      // v1.132-social (D379): the host's greeting card for a member holding HOST_GREETING (never the host's own join).
      const hostGreeting =
        (await vipLivePerkIn(this.prisma, userId, 'HOST_GREETING', this.clock.now())) !== null &&
        !(await this.prisma.liveRoom.count({ where: { id: roomId, hostUserId: userId } }));
      await this.broadcast(roomId, { type: 'join', user: userSummary(user), cp, gender, hostGreeting });
    } catch (err) {
      this.logger.warn({ error: safeErrorLog(err) }, 'Could not announce a join in the live chat');
    }
  }

  // ---- v1.132-social (D379, §10.169): PINNED_MESSAGE «تثبيت رسالتك أعلى الدردشة لثوانٍ» ------------------------

  /** A deleted message's pins are taken down with it (apps drop the pin on its `chat-delete`). */
  private async dropPinsOf(
    db: Pick<Prisma.TransactionClient, 'liveChatPin'>,
    messageId: string,
    actorId: string,
  ): Promise<void> {
    await db.liveChatPin.updateMany({
      where: { messageId, removedAt: null },
      data: { removedAt: this.clock.now(), removedById: actorId },
    });
  }

  /** The pin showing in [roomId] now (not taken down, not over, its message not deleted), as [readerId] may see it. */
  private async currentPin(roomId: string, readerId: string | null): Promise<LiveChatPinDto | null> {
    const pin = await this.prisma.liveChatPin.findFirst({
      where: {
        roomId,
        removedAt: null,
        until: { gt: this.clock.now() },
        message: { deletedAt: null },
        user: {
          status: 'ACTIVE',
          ...(readerId === null
            ? {}
            : {
                blocking: { none: { blockedId: readerId } },
                blockedBy: { none: { blockerId: readerId } },
              }),
        },
      },
      orderBy: { until: 'desc' },
      include: { user: { select: USER_SUMMARY_SELECT } },
    });
    return pin ? this.pinDto(pin) : null;
  }

  private pinDto(pin: {
    id: string;
    roomId: string;
    messageId: string;
    text: string;
    pinnedAt: Date;
    until: Date;
    user: Parameters<typeof userSummary>[0];
  }): LiveChatPinDto {
    return {
      id: pin.id,
      roomId: pin.roomId,
      messageId: pin.messageId,
      author: userSummary(pin.user),
      text: pin.text,
      pinnedAt: pin.pinnedAt.toISOString(),
      until: pin.until.toISOString(),
    };
  }

  /**
   * `POST /live/rooms/{roomId}/chat-pin` `{messageId}`: a VIP member pins their own TEXT message at the top of the
   * live's chat for the perk's `seconds`, at most `count` pins a day (the day of `LIVE_RANKINGS_TIME_ZONE`, every live
   * together). Checks: visible room (404), LIVE (409 LIVE_ROOM_ENDED), the body (400), a message of this live by the
   * caller, TEXT, not deleted (404), kicked out (403 LIVE_KICKED), in the room (403 LIVE_CHAT_NOT_IN_ROOM), muted (403
   * LIVE_CHAT_MUTED), the chat off (409 LIVE_CHAT_CLOSED; the host may still), the team's chat restriction (403
   * ACCOUNT_RESTRICTED), the perk with its value (409 VIP_UNAVAILABLE `perk` `no_perk`), then under the room row's
   * lock: another pin showing (409 LIVE_PIN_BUSY, `Retry-After` its seconds left — «one at a time»: refused, never
   * queued), the day's pins used up (409 VIP_UNAVAILABLE `perk` `used_up`). The text is masked with the host's blocked
   * words again.
   */
  async pin(callerId: string, roomId: string, body: unknown): Promise<LiveChatPinDto> {
    const row = await this.rooms.visibleRow(roomId, callerId);
    if (row.status !== 'LIVE') throw new AppException(ErrorCode.LIVE_ROOM_ENDED);
    const parsed = liveChatPinSchema.safeParse(body ?? {}, { reportInput: true });
    if (!parsed.success) throw AppException.validation(zodErrorToDetails(parsed.error));
    const now = this.clock.now();
    const message = await this.prisma.liveChatMessage.findFirst({
      where: {
        id: parsed.data.messageId.toLowerCase(),
        roomId: row.id,
        userId: callerId,
        kind: 'TEXT',
        deletedAt: null,
      },
      select: { id: true, text: true },
    });
    if (!message) throw notFound();
    if (callerId !== row.host_user_id) {
      if (row.kicked) throw new AppException(ErrorCode.LIVE_KICKED);
      if (!(await this.inMediaSession(row.id, callerId)))
        throw new AppException(ErrorCode.LIVE_CHAT_NOT_IN_ROOM);
      if (row.chat_muted) throw new AppException(ErrorCode.LIVE_CHAT_MUTED);
      if (!row.chat_enabled) throw new AppException(ErrorCode.LIVE_CHAT_CLOSED);
    }
    await assertNotRestricted(this.prisma, callerId, 'CHAT_MUTE');
    const perk = await vipLivePerkIn(this.prisma, callerId, 'PINNED_MESSAGE', now);
    const value = perk ? vipPinValue(perk.value) : null;
    if (!value)
      throw new AppException(ErrorCode.VIP_UNAVAILABLE, undefined, [{ field: 'perk', issue: 'no_perk' }]);
    const text = maskBlockedWords(message.text, await this.blockedWords.wordsOf(row.host_user_id));
    const { day } = await programWindowsIn(this.prisma, now, this.config.live.rankingsTimeZone);
    const created = await this.prisma.$transaction(async (tx) => {
      await tx.$queryRaw`SELECT id FROM live_rooms WHERE id = ${row.id}::uuid FOR UPDATE`;
      const userLock = `kabso:live-pin:${callerId}`;
      await tx.$queryRaw`SELECT pg_advisory_xact_lock(hashtext(${userLock}))`;
      const showing = await tx.liveChatPin.findFirst({
        where: { roomId: row.id, removedAt: null, until: { gt: now }, message: { deletedAt: null } },
        orderBy: { until: 'desc' },
        select: { until: true },
      });
      if (showing) {
        const left = Math.max(1, Math.ceil((showing.until.getTime() - now.getTime()) / 1000));
        throw new AppException(ErrorCode.LIVE_PIN_BUSY, undefined, undefined, {
          'Retry-After': String(left),
        });
      }
      const used = await tx.liveChatPin.count({
        where: { userId: callerId, pinnedAt: { gte: day.start, lt: day.end } },
      });
      if (used >= value.count) {
        throw new AppException(ErrorCode.VIP_UNAVAILABLE, undefined, [{ field: 'perk', issue: 'used_up' }]);
      }
      return tx.liveChatPin.create({
        data: {
          roomId: row.id,
          messageId: message.id,
          userId: callerId,
          text,
          pinnedAt: now,
          until: new Date(now.getTime() + value.seconds * 1000),
        },
        include: { user: { select: USER_SUMMARY_SELECT } },
      });
    }, LIVE_TX_OPTIONS);
    const pin = this.pinDto(created);
    await this.broadcast(row.id, { type: 'chat-pin', pin });
    return pin;
  }

  /**
   * `DELETE /live/rooms/{roomId}/chat-pin`: takes the pin showing down early — its author, the host, or a moderator
   * (never the host's pin nor another moderator's, as with messages); anyone else 403; idempotent (none showing → 204,
   * nothing sent).
   */
  async unpin(callerId: string, roomId: string): Promise<void> {
    const row = await this.rooms.visibleRow(roomId, callerId);
    if (row.status !== 'LIVE') throw new AppException(ErrorCode.LIVE_ROOM_ENDED);
    const now = this.clock.now();
    const pin = await this.prisma.liveChatPin.findFirst({
      where: { roomId: row.id, removedAt: null, until: { gt: now } },
      orderBy: { until: 'desc' },
      select: { id: true, userId: true },
    });
    if (pin?.userId !== callerId) {
      const privilege = await this.privilege(row, callerId);
      if (!pin) return;
      if (
        privilege === 'MODERATOR' &&
        (pin.userId === row.host_user_id || (await this.isModerator(row.id, pin.userId)))
      ) {
        throw forbidden();
      }
    }
    const removed = await this.prisma.liveChatPin.updateMany({
      where: { id: pin.id, removedAt: null },
      data: { removedAt: now, removedById: callerId },
    });
    if (removed.count > 0) await this.broadcast(row.id, { type: 'chat-unpin', id: pin.id });
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
    if (deleted.count > 0) await this.dropPinsOf(tx, messageId, actorId);
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
