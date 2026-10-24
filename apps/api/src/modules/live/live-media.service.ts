import { createHmac, hkdfSync } from 'node:crypto';
import { Inject, Injectable, Logger, type OnModuleDestroy, type OnModuleInit } from '@nestjs/common';
import { AuditAction, AuditService } from '../../common/audit/audit.service.js';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { Clock } from '../../common/time/clock.js';
import { zodErrorToDetails } from '../../common/validation/zod-validation.pipe.js';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import { Prisma } from '../../generated/prisma/client.js';
import { safeErrorLog } from '../../logging/redact-text.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { USER_SUMMARY_SELECT, userSummary } from '../posts/post-views.js';
import { SocialCursorCodec } from '../posts/social-cursor.js';
import { UsersService } from '../users/users.service.js';
import {
  LiveRoomsService,
  LIVE_TX_OPTIONS,
  type RequestMeta,
  type RoomInfoEdit,
  type UserSummaryDto,
} from './live-rooms.service.js';
import { LiveCategoriesService } from './live-categories.service.js';
import { LiveChatService } from './live-chat.service.js';
import { LiveRoomMetadataService } from './live-metadata.service.js';
import { hostSources, LiveSeatsService, seatPermission } from './live-seats.service.js';
import {
  isSeatedMode,
  isUuid,
  liveMediaTokenSchema,
  seatCountFits,
  updateLiveRoomSchema,
} from './live.schemas.js';
import {
  LIVE_MEDIA_PROVIDER,
  type LiveMediaProvider,
  type LiveMediaSource,
} from './media/live-media.provider.js';

/** `LiveMediaAccess` (openapi v1.6-live, CP-010). */
export interface LiveMediaAccessDto {
  url: string;
  token: string;
  expiresAt: string;
  /** CP-011: SPEAKER is a seated guest. */
  role: 'HOST' | 'VIEWER' | 'SPEAKER';
  identity: string;
  guestNumber: number | null;
}

/** `LiveViewer`. */
export interface LiveViewerDto {
  kind: 'USER' | 'GUEST';
  user: UserSummaryDto | null;
  guestNumber: number | null;
  joinedAt: string;
}

/** A media token works for 10 minutes to join (§10.8). */
export const MEDIA_TOKEN_TTL_SECONDS = 600;
const GUEST_PREFIX = 'guest:';
const VIEWER_PAGE_MAX = 50;

/** The guest id of a `guest:<uuid>` identity, else null. */
export function guestIdOf(identity: string): string | null {
  if (!identity.startsWith(GUEST_PREFIX)) return null;
  const id = identity.slice(GUEST_PREFIX.length);
  return isUuid(id) ? id.toLowerCase() : null;
}

/**
 * Live video (CP-010, CONVENTIONS §10.8) on top of the v1.3 rooms: media tokens for hosts,
 * viewers and guests, presence from the media server's signed webhook (`live_room_viewers`,
 * `viewer_count`), the host's viewer list and guests switch, closing media sessions when rooms
 * end, and the hosting permission (`live_hosts`). Media-server calls that only clean up are best
 * effort: the sweeper's reconciliation ({@link reconcile}) repeats them.
 */
@Injectable()
export class LiveMediaService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(LiveMediaService.name);
  private readonly guestKey: Buffer;
  private readonly cursors: SocialCursorCodec;
  private reconcileTimer: NodeJS.Timeout | undefined;
  private reconcileInFlight: Promise<unknown> | null = null;

  constructor(
    private readonly prisma: PrismaService,
    private readonly rooms: LiveRoomsService,
    private readonly users: UsersService,
    private readonly audit: AuditService,
    private readonly clock: Clock,
    private readonly seats: LiveSeatsService,
    private readonly chat: LiveChatService,
    private readonly categories: LiveCategoriesService,
    private readonly metadata: LiveRoomMetadataService,
    @Inject(LIVE_MEDIA_PROVIDER) private readonly media: LiveMediaProvider,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
  ) {
    this.guestKey = Buffer.from(hkdfSync('sha256', config.live.guestKey, '', 'live-guest/v1', 32));
    this.cursors = new SocialCursorCodec(config.social.cursorKey);
  }

  onModuleInit(): void {
    if (this.config.live.sweepIntervalSeconds > 0 && this.config.live.livekit !== null)
      this.scheduleReconcile();
  }

  async onModuleDestroy(): Promise<void> {
    if (this.reconcileTimer) clearTimeout(this.reconcileTimer);
    await this.reconcileInFlight?.catch(() => undefined);
  }

  /** Runs {@link reconcile} at the stale-room sweeper's cadence; one run at a time. */
  private scheduleReconcile(): void {
    this.reconcileTimer = setTimeout(() => {
      this.reconcileInFlight = this.reconcile()
        .catch((err: unknown) => {
          this.logger.warn({ error: safeErrorLog(err) }, 'Live media reconciliation failed');
        })
        .finally(() => {
          this.reconcileInFlight = null;
          this.scheduleReconcile();
        });
    }, this.config.live.sweepIntervalSeconds * 1000);
    this.reconcileTimer.unref();
  }

  /** 1000–9999, stable for a guest id and revealing nothing about it (§10.8). */
  guestNumber(guestId: string): number {
    const mac = createHmac('sha256', this.guestKey).update(guestId.toLowerCase()).digest();
    return 1000 + (mac.readUInt32BE(0) % 9000);
  }

  // ---- Media access ----------------------------------------------------------------------------

  /** `POST /live/rooms/{roomId}/media-token`; `callerId` null is a guest. */
  async mediaToken(callerId: string | null, roomId: string, body: unknown): Promise<LiveMediaAccessDto> {
    if (!this.config.live.hostingEnabled) throw new AppException(ErrorCode.LIVE_HOSTING_UNAVAILABLE);
    const parsed = liveMediaTokenSchema.safeParse(body ?? {});
    if (!parsed.success) throw AppException.validation(zodErrorToDetails(parsed.error));
    const guestId = callerId === null ? parsed.data.guestId?.toLowerCase() : undefined;
    if (callerId === null && guestId === undefined) {
      throw AppException.validation([{ field: 'guestId', issue: 'required' }]);
    }
    const row = await this.rooms.visibleRow(roomId, callerId);
    if (row.status !== 'LIVE') throw new AppException(ErrorCode.LIVE_ROOM_ENDED);
    if (guestId !== undefined && !row.allow_guests) throw new AppException(ErrorCode.LIVE_GUESTS_NOT_ALLOWED);

    const isHost = callerId !== null && callerId === row.host_user_id;
    let identity: string;
    let name: string;
    let guestNumber: number | null = null;
    if (guestId !== undefined) {
      identity = `${GUEST_PREFIX}${guestId}`;
      guestNumber = this.guestNumber(guestId);
      name = `Guest ${guestNumber}`;
    } else {
      identity = callerId!;
      const me = await this.users.getMe(callerId!);
      name = me?.displayName || me?.username || '';
    }
    // CP-011: the host publishes per mode (AUDIO: microphone only); a seated guest is a SPEAKER
    // with the seat's sources (§10.9); everyone else watches.
    let role: LiveMediaAccessDto['role'] = 'VIEWER';
    let sources: LiveMediaSource[] = [];
    if (isHost) {
      role = 'HOST';
      sources = hostSources(row.mode);
    } else if (callerId !== null && isSeatedMode(row.mode)) {
      const seat = await this.seats.seatOfUser(row.id, callerId);
      if (seat) {
        role = 'SPEAKER';
        sources = [...seatPermission(row.mode, seat.mutedByHost).sources];
      }
    }
    const token = await this.media.issueToken({
      room: row.id,
      identity,
      name,
      publish: role !== 'VIEWER',
      ...(role !== 'VIEWER' ? { sources } : {}),
      ttlSeconds: MEDIA_TOKEN_TTL_SECONDS,
    });
    return {
      url: this.media.url,
      token,
      expiresAt: new Date(this.clock.now().getTime() + MEDIA_TOKEN_TTL_SECONDS * 1000).toISOString(),
      role,
      identity,
      guestNumber,
    };
  }

  // ---- Host controls ---------------------------------------------------------------------------

  /** The host's LIVE room (else 404 for others, 409 when ended). */
  private async hostLiveRoom(
    hostId: string,
    roomId: string,
  ): Promise<{ id: string; allowGuests: boolean; chatEnabled: boolean }> {
    if (!isUuid(roomId)) throw new AppException(ErrorCode.NOT_FOUND);
    const room = await this.prisma.liveRoom.findFirst({
      where: { id: roomId.toLowerCase(), hostUserId: hostId },
      select: { id: true, status: true, allowGuests: true, chatEnabled: true },
    });
    if (!room) throw new AppException(ErrorCode.NOT_FOUND);
    return room;
  }

  /**
   * `PATCH /live/rooms/{roomId}`: the guests switch (off removes connected guests at once) and,
   * CP-011, the seat count (an allowed count for the room's mode, else 400; below an occupied seat
   * → 409 LIVE_SEAT_UNAVAILABLE) and the theme. The seat change is applied first, so a refused
   * change leaves everything as it was. CP-013: `chatEnabled` turns the room chat off or on
   * (audited; a `chat-state` data message when it changed). CP-014: `title`, `categorySlug` and
   * `topic` edit the live (an unknown or inactive category → 400 before anything is applied); a
   * real change moves the room info version, which is written into the media room's metadata at
   * once (§10.12).
   */
  async updateRoom(hostId: string, roomId: string, body: unknown, meta: RequestMeta): Promise<string> {
    const parsed = updateLiveRoomSchema.safeParse(body ?? {}, { reportInput: true });
    if (!parsed.success) throw AppException.validation(zodErrorToDetails(parsed.error));
    const room = await this.hostLiveRoom(hostId, roomId);
    const row = await this.rooms.visibleRow(room.id, hostId);
    if (row.status !== 'LIVE') throw new AppException(ErrorCode.LIVE_ROOM_ENDED);
    const { allowGuests, seatCount, theme, chatEnabled, title, categorySlug, topic } = parsed.data;
    if (seatCount !== undefined && !seatCountFits(row.mode, seatCount)) {
      throw AppException.validation([{ field: 'seatCount', issue: 'invalid_value' }]);
    }
    let category: RoomInfoEdit['category'];
    if (categorySlug === null) category = null;
    else if (categorySlug !== undefined) {
      const id = await this.categories.findActiveId(categorySlug);
      if (!id) throw AppException.validation([{ field: 'categorySlug', issue: 'invalid_value' }]);
      category = { id, slug: categorySlug };
    }
    if (seatCount !== undefined || theme !== undefined) {
      await this.seats.updateSettings(room.id, { seatCount, theme });
    }
    if (title !== undefined || category !== undefined || topic !== undefined) {
      const version = await this.rooms.editInfo(
        hostId,
        room.id,
        {
          ...(title !== undefined ? { title } : {}),
          ...(category !== undefined ? { category } : {}),
          ...(topic !== undefined ? { topic } : {}),
        },
        meta,
      );
      if (version !== null) await this.metadata.infoChanged(room.id);
    }
    if (chatEnabled !== undefined && chatEnabled !== room.chatEnabled) {
      const changed = await this.prisma.$transaction(async (tx) => {
        const updated = await tx.liveRoom.updateMany({
          where: { id: room.id, chatEnabled: !chatEnabled },
          data: { chatEnabled },
        });
        if (updated.count === 0) return false;
        await this.audit.recordIn(tx, {
          action: AuditAction.LIVE_ROOM_CHAT,
          actorUserId: hostId,
          targetType: 'live_room',
          targetId: room.id,
          metadata: { chatEnabled },
          ip: meta.ip,
          requestId: meta.requestId,
        });
        return true;
      }, LIVE_TX_OPTIONS);
      if (changed) await this.chat.stateChanged(room.id, chatEnabled);
    }
    if (allowGuests === undefined) return room.id;
    if (allowGuests !== room.allowGuests) {
      await this.prisma.$transaction(async (tx) => {
        await tx.liveRoom.update({ where: { id: room.id }, data: { allowGuests } });
        await this.audit.recordIn(tx, {
          action: AuditAction.LIVE_ROOM_GUESTS,
          actorUserId: hostId,
          targetType: 'live_room',
          targetId: room.id,
          metadata: { allowGuests },
          ip: meta.ip,
          requestId: meta.requestId,
        });
      }, LIVE_TX_OPTIONS);
    }
    if (!allowGuests) await this.removeGuests(room.id);
    return room.id;
  }

  /** Disconnects every guest of a room (connected per the server or per our rows). */
  private async removeGuests(roomId: string): Promise<void> {
    const rows = await this.prisma.liveRoomViewer.findMany({
      where: { roomId, guestId: { not: null } },
      select: { identity: true },
    });
    let connected: string[] = [];
    try {
      connected = await this.media.listIdentities(roomId);
    } catch (err) {
      this.logger.warn({ error: safeErrorLog(err) }, 'Could not list media participants');
    }
    const guests = new Set([
      ...rows.map((r) => r.identity),
      ...connected.filter((i) => guestIdOf(i) !== null),
    ]);
    for (const identity of guests) {
      try {
        await this.media.removeParticipant(roomId, identity);
      } catch (err) {
        this.logger.warn({ error: safeErrorLog(err) }, 'Could not remove a guest from the media session');
      }
    }
    await this.prisma.liveRoomViewer.deleteMany({ where: { roomId, guestId: { not: null } } });
    await this.recount(this.prisma, roomId);
  }

  /** `GET /live/rooms/{roomId}/viewers` (host only): connected now, newest first. */
  async viewers(
    hostId: string,
    roomId: string,
    query: { cursor?: string; limit: number },
  ): Promise<{ data: LiveViewerDto[]; page: { nextCursor: string | null; hasMore: boolean } }> {
    const room = await this.hostLiveRoom(hostId, roomId);
    const scope = `live-viewers:${room.id}`;
    let after: { at: Date; identity: string } | null = null;
    if (query.cursor !== undefined) {
      const position = this.cursors.decode(query.cursor, scope);
      if (!position) throw AppException.validation([{ field: 'cursor', issue: 'invalid_value' }]);
      after = { at: position.at, identity: position.n === 1 ? `${GUEST_PREFIX}${position.id}` : position.id };
    }
    const limit = Math.min(query.limit, VIEWER_PAGE_MAX);
    const rows = await this.prisma.liveRoomViewer.findMany({
      where: {
        roomId: room.id,
        room: { status: 'LIVE' },
        OR: [{ guestId: { not: null } }, { user: { status: 'ACTIVE' } }],
        ...(after
          ? {
              AND: [
                {
                  OR: [
                    { joinedAt: { lt: after.at } },
                    { joinedAt: after.at, identity: { lt: after.identity } },
                  ],
                },
              ],
            }
          : {}),
      },
      orderBy: [{ joinedAt: 'desc' }, { identity: 'desc' }],
      take: limit + 1,
      include: { user: { select: USER_SUMMARY_SELECT } },
    });
    const hasMore = rows.length > limit;
    const page = rows.slice(0, limit);
    const last = page.at(-1);
    return {
      data: page.map((r) => ({
        kind: r.guestId ? 'GUEST' : 'USER',
        user: r.user ? userSummary(r.user) : null,
        guestNumber: r.guestId ? this.guestNumber(r.guestId) : null,
        joinedAt: r.joinedAt.toISOString(),
      })),
      page: {
        hasMore,
        nextCursor:
          hasMore && last
            ? this.cursors.encode(scope, {
                at: last.joinedAt,
                id: last.guestId ?? last.userId!,
                n: last.guestId ? 1 : 0,
              })
            : null,
      },
    };
  }

  // ---- Presence --------------------------------------------------------------------------------

  /** `viewer_count` = connected identities other than the host (the host has no row). */
  private async recount(db: Prisma.TransactionClient | PrismaService, roomId: string): Promise<void> {
    await db.$executeRaw`
      UPDATE live_rooms
         SET viewer_count = (SELECT count(*) FROM live_room_viewers v WHERE v.room_id = ${roomId}::uuid)
       WHERE id = ${roomId}::uuid`;
  }

  /**
   * `POST /internal/livekit/webhook`: a signed media-server event. A join is recorded only for a
   * LIVE room and an allowed identity (a guest while guests are allowed, an ACTIVE user with no
   * block); anyone else is disconnected. Leaves and finished rooms remove rows. Idempotent.
   */
  async webhook(rawBody: string, authorization: string | undefined): Promise<void> {
    let event;
    try {
      event = await this.media.parseWebhook(rawBody, authorization);
    } catch {
      throw new AppException(ErrorCode.AUTH_UNAUTHENTICATED);
    }
    if (event.kind === 'ignored' || !isUuid(event.room)) return;
    const roomId = event.room.toLowerCase();
    if (event.kind === 'room_finished') {
      await this.prisma.liveRoomViewer.deleteMany({ where: { roomId } });
      await this.recount(this.prisma, roomId);
      return;
    }
    if (event.kind === 'left') {
      await this.prisma.liveRoomViewer.deleteMany({ where: { roomId, identity: event.identity } });
      await this.recount(this.prisma, roomId);
      // CP-011: leaving the media session ends the user's seat, request and invitation.
      if (isUuid(event.identity)) await this.seats.onLeft(roomId, event.identity.toLowerCase());
      return;
    }
    await this.onJoined(roomId, event.identity);
  }

  /**
   * A participant is in the room's media session (the `participant_joined` webhook, or found by
   * reconciliation when that webhook was missed): recorded as a viewer when allowed, else
   * disconnected. Idempotent.
   */
  private async onJoined(roomId: string, identity: string): Promise<void> {
    const room = await this.prisma.liveRoom.findUnique({
      where: { id: roomId },
      select: { status: true, hostUserId: true, allowGuests: true },
    });
    const guestId = guestIdOf(identity);
    const userId = guestId === null && isUuid(identity) ? identity.toLowerCase() : null;
    if (!room || room.status !== 'LIVE' || (guestId === null && userId === null)) {
      await this.kick(roomId, identity);
      return;
    }
    if (userId === room.hostUserId) return; // the host is not a viewer
    if (guestId !== null && !room.allowGuests) {
      await this.kick(roomId, identity);
      return;
    }
    if (userId !== null) {
      const [allowed] = await this.prisma.$queryRaw<{ ok: boolean }[]>`
        SELECT EXISTS (SELECT 1 FROM users WHERE id = ${userId}::uuid AND status = 'ACTIVE'::user_status)
           AND NOT EXISTS (SELECT 1 FROM user_blocks b
                            WHERE (b.blocker_id = ${userId}::uuid AND b.blocked_id = ${room.hostUserId}::uuid)
                               OR (b.blocker_id = ${room.hostUserId}::uuid AND b.blocked_id = ${userId}::uuid)) AS ok`;
      if (!allowed?.ok) {
        await this.kick(roomId, identity);
        return;
      }
    }
    const recorded = await this.prisma.liveRoomViewer.createMany({
      data: [{ roomId, identity, userId, guestId, joinedAt: this.clock.now() }],
      skipDuplicates: true,
    });
    await this.recount(this.prisma, roomId);
    // CP-011: a seated user who (re)joins gets their seat's permission.
    if (userId !== null) await this.seats.onJoined(roomId, userId);
    // CP-013: a "joined" line for a signed-in viewer who just came in (guests are not announced;
    // a repeated webhook for someone already recorded is not a new join).
    if (userId !== null && recorded.count > 0) await this.chat.announceJoin(roomId, userId);
  }

  private async kick(roomId: string, identity: string): Promise<void> {
    try {
      await this.media.removeParticipant(roomId, identity);
    } catch (err) {
      this.logger.warn({ error: safeErrorLog(err) }, 'Could not remove a participant from the media session');
    }
  }

  // ---- Ending ----------------------------------------------------------------------------------

  /** Closes a room's media session for everyone and clears its presence (best effort). */
  async closeMedia(roomId: string): Promise<void> {
    try {
      await this.media.closeRoom(roomId);
    } catch (err) {
      this.logger.warn(
        { error: safeErrorLog(err) },
        'Could not close the media session; the sweeper retries',
      );
    }
    await this.prisma.liveRoomViewer.deleteMany({ where: { roomId } });
  }

  /**
   * Sweeper step (§10.8): closes media sessions whose room is no longer LIVE (timeouts,
   * suspensions, missed closes), drops presence rows of ended rooms, and aligns LIVE rooms'
   * presence with the server. Returns the number of sessions closed.
   */
  async reconcile(): Promise<number> {
    if (this.config.live.livekit === null) return 0;
    // CP-011: invitations past their 60 seconds (they already read as none).
    await this.seats.expireInvites();
    await this.prisma.$executeRaw`
      DELETE FROM live_room_viewers v USING live_rooms r
       WHERE r.id = v.room_id AND r.status <> 'LIVE'`;
    const open = await this.media.listRooms();
    const ids = open.filter(isUuid).map((id) => id.toLowerCase());
    const live = new Set(
      (
        await this.prisma.liveRoom.findMany({
          where: { id: { in: ids }, status: 'LIVE' },
          select: { id: true },
        })
      ).map((r) => r.id),
    );
    let closed = 0;
    for (const name of open) {
      if (!live.has(name.toLowerCase())) {
        await this.closeMedia(name);
        closed += 1;
        continue;
      }
      const connected = new Set(await this.media.listIdentities(name));
      const rows = await this.prisma.liveRoomViewer.findMany({
        where: { roomId: name },
        select: { identity: true },
      });
      const gone = rows.map((r) => r.identity).filter((i) => !connected.has(i));
      // Joins whose webhook was missed are recorded (or refused) like the webhook would.
      const recorded = new Set(rows.map((r) => r.identity));
      for (const identity of connected) {
        if (!recorded.has(identity)) await this.onJoined(name.toLowerCase(), identity);
      }
      if (gone.length > 0) {
        await this.prisma.liveRoomViewer.deleteMany({ where: { roomId: name, identity: { in: gone } } });
        await this.recount(this.prisma, name);
        // CP-011: a seated user who is gone loses the seat (as with a `participant_left` webhook).
        for (const identity of gone)
          if (isUuid(identity)) await this.seats.onLeft(name, identity.toLowerCase());
      }
      // CP-011: re-apply seat permissions and the seat version a failed call may have missed.
      try {
        await this.seats.reconcileRoom(name.toLowerCase());
      } catch (err) {
        this.logger.warn({ error: safeErrorLog(err) }, 'Could not reconcile the seats of a media room');
      }
    }
    return closed;
  }

  // ---- Hosting permission ----------------------------------------------------------------------

  /** `PUT /admin/live/hosts/{username}` (LIVE_HOSTS): idempotent; audited when it changes. */
  async grantHost(adminId: string, username: string, meta: RequestMeta): Promise<void> {
    const user = await this.users.findActivePublicUser(username);
    if (!user) throw new AppException(ErrorCode.NOT_FOUND);
    await this.prisma.$transaction(async (tx) => {
      const created = await tx.liveHost.createMany({
        data: [{ userId: user.id, source: 'ADMIN', grantedById: adminId }],
        skipDuplicates: true,
      });
      if (created.count > 0) {
        await this.audit.recordIn(tx, {
          action: AuditAction.LIVE_HOST_GRANT,
          actorUserId: adminId,
          targetType: 'user',
          targetId: user.id,
          metadata: { source: 'ADMIN' },
          ip: meta.ip,
          requestId: meta.requestId,
        });
      }
    });
  }

  /** `DELETE /admin/live/hosts/{username}`: also ends the user's LIVE room (`ADMIN`). */
  async revokeHost(adminId: string, username: string, meta: RequestMeta): Promise<void> {
    const user = await this.users.findActivePublicUser(username);
    if (!user) throw new AppException(ErrorCode.NOT_FOUND);
    const ended = await this.prisma.$transaction(async (tx) => {
      const removed = await tx.liveHost.deleteMany({ where: { userId: user.id } });
      const rooms = await this.rooms.endByAdminIn(tx, { hostUserId: user.id });
      if (removed.count > 0 || rooms.length > 0) {
        await this.audit.recordIn(tx, {
          action: AuditAction.LIVE_HOST_REVOKE,
          actorUserId: adminId,
          targetType: 'user',
          targetId: user.id,
          metadata: { endedRooms: rooms.length },
          ip: meta.ip,
          requestId: meta.requestId,
        });
      }
      return rooms;
    }, LIVE_TX_OPTIONS);
    for (const roomId of ended) await this.closeMedia(roomId);
  }
}
