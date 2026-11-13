import { createHmac, hkdfSync, randomBytes } from 'node:crypto';
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
import { vipPerkRankSql } from '../vip/vip-live-perks.js';
import { SocialCursorCodec } from '../posts/social-cursor.js';
import { UsersService } from '../users/users.service.js';
import { isCreatorIn } from '../creator/creator-membership.js';
import {
  LiveRoomsService,
  LIVE_TX_OPTIONS,
  streamerOf,
  type LiveStreamerDto,
  type RequestMeta,
  type RoomInfoEdit,
  type UserSummaryDto,
} from './live-rooms.service.js';
import { LiveCategoriesService } from './live-categories.service.js';
import { closeVisits, closeVisitsOfEndedRooms, openVisit, recountViewers } from './live-audience.js';
import { LiveChatService } from './live-chat.service.js';
import { LiveRoomMetadataService } from './live-metadata.service.js';
import { LivePkService } from './live-pk.service.js';
import { PK_IDENTITY_PREFIX } from './live-pk.js';
import { LivePk4Service } from './live-pk4.service.js';
import { PK4_IDENTITY_PREFIX } from './live-pk4.js';
import { staffRolesOf, WATCH_STAFF_ROLES, watchStaffAmong } from './live-staff.js';
import { LiveStaffAssignmentService } from './live-staff-assignment.service.js';
import { LiveToolsService, SECOND_CAMERA_PREFIX } from './live-tools.service.js';
import { hostSources, LiveSeatsService, seatPermission } from './live-seats.service.js';
import {
  hasGuestSeats,
  isUuid,
  liveMediaTokenSchema,
  seatCountFits,
  updateLiveRoomSchema,
  updateLiveStreamerSchema,
} from './live.schemas.js';
import {
  LIVE_MEDIA_PROVIDER,
  type LiveMediaProvider,
  type LiveMediaSource,
} from './media/live-media.provider.js';
import { recomputeBadgesIn } from '../verification/verification-badges.js';

/** `LiveMediaAccess` (openapi v1.6-live, CP-010). */
export interface LiveMediaAccessDto {
  url: string;
  token: string;
  expiresAt: string;
  /** CP-011: SPEAKER is a seated guest. */
  role: 'HOST' | 'VIEWER' | 'SPEAKER';
  identity: string;
  guestNumber: number | null;
  /**
   * v1.68-live (D273, §10.96.6): the caller is «فريق كابسو» in this live — VISIBLE (listed with the badge, never
   * counted) or HIDDEN (the D250 observer: not listed, not counted, no chat). Absent for everyone else.
   */
  staff?: 'VISIBLE' | 'HIDDEN';
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
/**
 * v1.60-live (D250, §10.91): a staff observer's identity `staff:<adminId>:<nonce>` (a nonce, so the cards' previews and
 * the watch view of the same admin never replace each other). Hidden, subscribe-only, never a viewer.
 */
export const STAFF_IDENTITY_PREFIX = 'staff:';
/** v1.60-live (D250): a staff observer's token joins within 2 minutes (the media server renews a joined session). */
export const STAFF_TOKEN_TTL_SECONDS = 120;
/**
 * v1.64-live (D260, §10.96): a staff member watching VISIBLY, `team:<adminId>:<nonce>` — subscribe-only, NOT hidden,
 * recorded in `live_room_staff_watchers` and listed in the live's viewers with the «فريق كابسو» badge
 * (`LiveViewerPage.staff`), never a viewer (not in `live_room_viewers`, not counted in `viewer_count`, no join line).
 */
export const TEAM_IDENTITY_PREFIX = 'team:';
const TEAM_IDENTITY = /^team:([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}):[0-9a-f]{6,32}$/;

/** v1.64-live (D260): the admin id of a `team:<adminId>:<nonce>` identity, else null. */
export function teamAdminIdOf(identity: string): string | null {
  return TEAM_IDENTITY.exec(identity.toLowerCase())?.[1] ?? null;
}

/** `LiveStaffWatcher` (D260): a staff member watching this live, as the viewer list shows them. */
export interface LiveStaffWatcherDto {
  displayName: string;
  avatarUrl: string | null;
  since: string;
}

/** `AdminLiveMediaAccess` (D250): a hidden observer's access to one media room. */
export interface StaffMediaAccessDto {
  roomId: string;
  url: string;
  token: string;
  identity: string;
  expiresAt: string;
}
/**
 * v1.82-live (D295, §10.108): the admin grant or revoke of a creator's hosting permission is refused — 409
 * ADMIN_ACTION_REFUSED `details[0] = {field: 'user', issue: 'CREATOR'}` (host and creator are exclusive; a creator's
 * permission comes and goes with the membership).
 */
function creatorHostRefused(issue: 'CREATOR'): AppException {
  return new AppException(
    ErrorCode.ADMIN_ACTION_REFUSED,
    'This person is a content creator: the hosting permission follows the creator membership.',
    [{ field: 'user', issue }],
  );
}

const GUEST_PREFIX = 'guest:';
const VIEWER_PAGE_MAX = 50;
/**
 * v1.132-social (D379, §10.169): VIEWER_LIST_PRIORITY «اسمك أعلى قائمة المشاهدين» — at most this many VIP holders lead
 * the first page of the viewer list (the higher tier first); the pages that follow skip them.
 */
export const VIEWER_PRIORITY_MAX = 50;
/** v1.56-live (D213, §10.86): the data message topic of a STREAMER's layout changes. */
export const LIVE_STREAMER_TOPIC = 'streamer';

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
    private readonly pk: LivePkService,
    private readonly pk4: LivePk4Service,
    private readonly tools: LiveToolsService,
    private readonly staffShift: LiveStaffAssignmentService,
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

  /**
   * `POST /live/rooms/{roomId}/media-token`; `callerId` null is a guest. v1.68-live (D273, §10.96.6): a caller who
   * holds a watch role (OWNER, MODERATION, SUPPORT) and is not the host always joins as «فريق كابسو» — the D260
   * `team:` identity (listed with the badge, never counted, no join line) or, with `staffVisibility: HIDDEN`, the D250
   * `staff:` observer (`lives.watch.hidden`: OWNER, MODERATION; 403 otherwise — v1.76-live, D286: no step-up code any
   * more). Both are subscribe-only and audited `admin.live.watch` with `via: app`, and both are staff work: the shift
   * goes on (§10.96.14).
   */
  async mediaToken(
    callerId: string | null,
    roomId: string,
    body: unknown,
    auth?: { sessionId: string; meta: RequestMeta },
  ): Promise<LiveMediaAccessDto> {
    if (!this.config.live.hostingEnabled) throw new AppException(ErrorCode.LIVE_HOSTING_UNAVAILABLE);
    const parsed = liveMediaTokenSchema.safeParse(body ?? {});
    if (!parsed.success) throw AppException.validation(zodErrorToDetails(parsed.error));
    const guestId = callerId === null ? parsed.data.guestId?.toLowerCase() : undefined;
    if (callerId === null && guestId === undefined) {
      throw AppException.validation([{ field: 'guestId', issue: 'required' }]);
    }
    const row = await this.rooms.visibleRow(roomId, callerId);
    if (row.status !== 'LIVE') throw new AppException(ErrorCode.LIVE_ROOM_ENDED);
    if (callerId !== null && callerId !== row.host_user_id) {
      const roles = await staffRolesOf(this.prisma, callerId);
      if (roles.some((r) => (WATCH_STAFF_ROLES as readonly string[]).includes(r))) {
        return this.staffAppAccess(callerId, row.id, row.host_user_id, roles, parsed.data, auth);
      }
    }
    if (parsed.data.staffVisibility !== undefined) throw new AppException(ErrorCode.AUTH_FORBIDDEN);
    // v1.20-live (D105, §10.20): a signed-in caller kicked out of this live gets no token for it.
    if (callerId !== null && row.kicked) throw new AppException(ErrorCode.LIVE_KICKED);
    if (guestId !== undefined && !row.allow_guests) throw new AppException(ErrorCode.LIVE_GUESTS_NOT_ALLOWED);
    // v1.132-social (D379, §10.169): a VIP room lets in its tier and the ones above (the staff came in above).
    await this.rooms.assertVipEntry(row, callerId);

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
      sources = hostSources(row.mode, row.podcast_video);
    } else if (callerId !== null && hasGuestSeats(row.mode)) {
      const seat = await this.seats.seatOfUser(row.id, callerId);
      if (seat) {
        role = 'SPEAKER';
        sources = [...seatPermission(row.mode, seat.mutedByHost, row.podcast_video).sources];
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

  /**
   * v1.68-live (D273, §10.96.6): «فريق كابسو» entering a live from the app (see {@link mediaToken}). The same identities
   * as the panel's watch (D260 `team:` visible, D250 `staff:` hidden), so the webhook and the viewer list treat them
   * alike; the media token lasts like a viewer's (the app reconnects with a new one).
   */
  private async staffAppAccess(
    userId: string,
    roomId: string,
    hostUserId: string,
    roles: readonly string[],
    input: { staffVisibility?: 'VISIBLE' | 'HIDDEN' | undefined },
    auth: { sessionId: string; meta: RequestMeta } | undefined,
  ): Promise<LiveMediaAccessDto> {
    const hidden = input.staffVisibility === 'HIDDEN';
    if (hidden) {
      // The panel's rule: `lives.watch.hidden` (OWNER, MODERATION). v1.76-live (D286): no step-up code any more.
      if (!roles.includes('OWNER') && !roles.includes('MODERATION'))
        throw new AppException(ErrorCode.AUTH_FORBIDDEN);
    }
    const nonce = randomBytes(6).toString('hex');
    const identity = `${hidden ? STAFF_IDENTITY_PREFIX : TEAM_IDENTITY_PREFIX}${userId}:${nonce}`;
    const token = await this.media.issueToken({
      room: roomId,
      identity,
      name: hidden ? 'Kabso staff' : 'Kabso Team',
      publish: false,
      ...(hidden ? {} : { visible: true }),
      ttlSeconds: MEDIA_TOKEN_TTL_SECONDS,
    });
    await this.audit.record({
      action: AuditAction.ADMIN_LIVE_WATCH,
      actorUserId: userId,
      targetType: 'live_room',
      targetId: roomId,
      metadata: {
        purpose: 'WATCH',
        visibility: hidden ? 'HIDDEN' : 'VISIBLE',
        identity,
        hostUserId,
        via: 'app',
      },
      ip: auth?.meta.ip ?? null,
      requestId: auth?.meta.requestId ?? null,
    });
    // v1.76-live (D286, §10.96.14): entering a live as staff is staff work — the shift goes on (best effort).
    await this.staffShift.staffWorkBestEffort(userId, 'live_join', 'app', {
      ip: auth?.meta.ip ?? null,
      requestId: auth?.meta.requestId ?? null,
    });
    return {
      url: this.media.url,
      token,
      expiresAt: new Date(this.clock.now().getTime() + MEDIA_TOKEN_TTL_SECONDS * 1000).toISOString(),
      role: 'VIEWER',
      identity,
      guestNumber: null,
      staff: hidden ? 'HIDDEN' : 'VISIBLE',
    };
  }

  /**
   * v1.60-live (D250, §10.91): a hidden observer's token for staff in the panel — subscribe only (no publishing, no
   * data), `hidden` so neither the host nor the viewers see it in the participant list, never counted as a viewer
   * (see {@link onJoined}). The panel checks the capability and audits each token; this only issues it for a LIVE room.
   */
  async staffAccess(
    adminId: string,
    roomId: string,
    nonce: string,
    visible = false,
  ): Promise<StaffMediaAccessDto> {
    if (!this.config.live.hostingEnabled) throw new AppException(ErrorCode.LIVE_HOSTING_UNAVAILABLE);
    const room = await this.prisma.liveRoom.findUnique({ where: { id: roomId }, select: { status: true } });
    if (!room) throw new AppException(ErrorCode.NOT_FOUND);
    if (room.status !== 'LIVE') throw new AppException(ErrorCode.LIVE_ROOM_ENDED);
    // v1.64-live (D260): VISIBLE — a `team:` identity, not hidden, listed with the «فريق كابسو» badge.
    const identity = `${visible ? TEAM_IDENTITY_PREFIX : STAFF_IDENTITY_PREFIX}${adminId}:${nonce}`;
    const token = await this.media.issueToken({
      room: roomId,
      identity,
      name: visible ? 'Kabso Team' : 'Kabso staff',
      publish: false,
      ...(visible ? { visible: true } : {}),
      ttlSeconds: STAFF_TOKEN_TTL_SECONDS,
    });
    return {
      roomId,
      url: this.media.url,
      token,
      identity,
      expiresAt: new Date(this.clock.now().getTime() + STAFF_TOKEN_TTL_SECONDS * 1000).toISOString(),
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
    const { allowGuests, seatCount, theme, chatEnabled, title, categorySlug, topic, wishGifts } = parsed.data;
    const { questionsOpen, questionSeconds } = parsed.data;
    if (seatCount !== undefined && !seatCountFits(row.mode, seatCount)) {
      throw AppException.validation([{ field: 'seatCount', issue: 'invalid_value' }]);
    }
    // v1.47-live (D212, §10.69): the hands switch and the question duration are a podcast's only.
    if (row.mode !== 'PODCAST') {
      if (questionsOpen !== undefined) {
        throw AppException.validation([{ field: 'questionsOpen', issue: 'invalid_value' }]);
      }
      if (questionSeconds !== undefined) {
        throw AppException.validation([{ field: 'questionSeconds', issue: 'invalid_value' }]);
      }
    }
    let category: RoomInfoEdit['category'];
    if (categorySlug === null) category = null;
    else if (categorySlug !== undefined) {
      const id = await this.categories.findActiveId(categorySlug);
      if (!id) throw AppException.validation([{ field: 'categorySlug', issue: 'invalid_value' }]);
      category = { id, slug: categorySlug };
    }
    if (seatCount !== undefined || theme !== undefined) {
      // D135: a new theme reaches everyone in the room through `roomInfoVersion`.
      if (await this.seats.updateSettings(room.id, { seatCount, theme })) {
        await this.metadata.infoChanged(room.id);
      }
    }
    // v1.27.3-live (D136): the wish list reaches everyone through `roomInfoVersion`.
    if (wishGifts !== undefined && (await this.rooms.setWishes(hostId, room.id, wishGifts, meta))) {
      await this.metadata.infoChanged(room.id);
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
    if (questionsOpen !== undefined || questionSeconds !== undefined) {
      const changed = await this.prisma.$transaction(async (tx) => {
        const before = await tx.liveRoom.findUniqueOrThrow({
          where: { id: room.id },
          select: { questionsOpen: true, questionSeconds: true },
        });
        const data = {
          ...(questionsOpen !== undefined && questionsOpen !== before.questionsOpen ? { questionsOpen } : {}),
          ...(questionSeconds !== undefined && questionSeconds !== before.questionSeconds
            ? { questionSeconds }
            : {}),
        };
        if (Object.keys(data).length === 0) return false;
        await tx.liveRoom.update({ where: { id: room.id }, data });
        await this.audit.recordIn(tx, {
          action: AuditAction.LIVE_ROOM_PODCAST,
          actorUserId: hostId,
          targetType: 'live_room',
          targetId: room.id,
          metadata: data,
          ip: meta.ip,
          requestId: meta.requestId,
        });
        return true;
      }, LIVE_TX_OPTIONS);
      // Everyone's app re-reads the room (the hand button follows `questionsOpen`).
      if (changed) await this.metadata.infoChanged(room.id);
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

  /**
   * v1.56-live (D213, CONVENTIONS §10.86): `PUT /live/rooms/{roomId}/streamer` — a STREAMER host's
   * screen orientation and camera bubble (shown or hidden, its corner). Host only (others 404, like
   * every host control); not a STREAMER → 409 LIVE_NOT_STREAMER; ended → 409 LIVE_ROOM_ENDED. A real
   * change moves `streamerVersion` (under the row's lock), is written into the media room's metadata
   * and is sent to everyone in the room as a `streamer` data message (topic `streamer`) so viewers
   * re-lay the picture at once. Not audited: a layout, changed often while playing (a rotation).
   */
  async updateStreamer(hostId: string, roomId: string, body: unknown): Promise<LiveStreamerDto> {
    const parsed = updateLiveStreamerSchema.safeParse(body ?? {}, { reportInput: true });
    if (!parsed.success) throw AppException.validation(zodErrorToDetails(parsed.error));
    const room = await this.hostLiveRoom(hostId, roomId);
    const { orientation, cameraOverlay, main } = parsed.data;
    const result = await this.prisma.$transaction(async (tx) => {
      const [row] = await tx.$queryRaw<
        {
          mode: string;
          status: string;
          streamer_orientation: string | null;
          streamer_camera_visible: boolean | null;
          streamer_camera_corner: string | null;
          streamer_main: string | null;
          streamer_version: number;
        }[]
      >`SELECT mode::text AS mode, status::text AS status, streamer_orientation, streamer_camera_visible,
               streamer_camera_corner, streamer_main, streamer_version
          FROM live_rooms WHERE id = ${room.id}::uuid FOR UPDATE`;
      if (!row) throw new AppException(ErrorCode.NOT_FOUND);
      if (row.status !== 'LIVE') throw new AppException(ErrorCode.LIVE_ROOM_ENDED);
      if (row.mode !== 'STREAMER') throw new AppException(ErrorCode.LIVE_NOT_STREAMER);
      const data = {
        ...(orientation !== undefined && orientation !== row.streamer_orientation
          ? { streamerOrientation: orientation }
          : {}),
        ...(cameraOverlay?.visible !== undefined && cameraOverlay.visible !== row.streamer_camera_visible
          ? { streamerCameraVisible: cameraOverlay.visible }
          : {}),
        ...(cameraOverlay?.corner !== undefined && cameraOverlay.corner !== row.streamer_camera_corner
          ? { streamerCameraCorner: cameraOverlay.corner }
          : {}),
        // v1.57-live (D247, §10.88): the screen or the camera as the main picture.
        ...(main !== undefined && main !== (row.streamer_main ?? 'SCREEN') ? { streamerMain: main } : {}),
      };
      if (Object.keys(data).length === 0) return { changed: false, row };
      const updated = await tx.liveRoom.update({
        where: { id: room.id },
        data: { ...data, streamerVersion: { increment: 1 } },
        select: {
          streamerOrientation: true,
          streamerCameraVisible: true,
          streamerCameraCorner: true,
          streamerMain: true,
          streamerVersion: true,
        },
      });
      return {
        changed: true,
        row: {
          mode: row.mode,
          status: row.status,
          streamer_orientation: updated.streamerOrientation,
          streamer_camera_visible: updated.streamerCameraVisible,
          streamer_camera_corner: updated.streamerCameraCorner,
          streamer_main: updated.streamerMain,
          streamer_version: updated.streamerVersion,
        },
      };
    }, LIVE_TX_OPTIONS);
    const streamer = streamerOf(result.row);
    if (!streamer) throw new Error(`live room ${room.id} is a STREAMER without its fields`);
    if (result.changed) {
      await this.metadata.infoChanged(room.id);
      try {
        await this.media.broadcastData(
          room.id,
          LIVE_STREAMER_TOPIC,
          JSON.stringify({ type: 'streamer', roomId: room.id, streamer }),
        );
      } catch (err) {
        // Best effort: the metadata's `streamerVersion` makes every app re-read the room.
        this.logger.warn({ error: safeErrorLog(err) }, 'Could not send the streamer data message');
      }
    }
    return streamer;
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
    await closeVisits(
      this.prisma,
      roomId,
      rows.map((r) => r.identity),
      this.clock.now(),
    );
    await this.prisma.liveRoomViewer.deleteMany({ where: { roomId, guestId: { not: null } } });
    await this.recount(this.prisma, roomId);
  }

  /**
   * `GET /live/rooms/{roomId}/viewers`: connected now, newest first. The host as before (CP-010:
   * their own room, else 404). v1.23.2-live (D109): anyone else who may watch the room too —
   * visible room (404) → a guest needs `allowGuests` (403 LIVE_GUESTS_NOT_ALLOWED) → not kicked
   * out of this live (403 LIVE_KICKED); a signed-in non-host caller never sees a user with a block
   * either way. An ended room → an empty list.
   */
  async viewers(
    callerId: string | null,
    roomId: string,
    query: { cursor?: string; limit: number },
  ): Promise<{
    data: LiveViewerDto[];
    staff: LiveStaffWatcherDto[];
    page: { nextCursor: string | null; hasMore: boolean };
  }> {
    let room: { id: string };
    let hideBlocksOf: string | null = null;
    const own =
      callerId !== null && isUuid(roomId)
        ? await this.prisma.liveRoom.findFirst({
            where: { id: roomId.toLowerCase(), hostUserId: callerId },
            select: { id: true },
          })
        : null;
    if (own) {
      room = own;
    } else {
      const row = await this.rooms.visibleRow(roomId, callerId);
      if (callerId === null && !row.allow_guests) throw new AppException(ErrorCode.LIVE_GUESTS_NOT_ALLOWED);
      if (row.kicked) throw new AppException(ErrorCode.LIVE_KICKED);
      room = { id: row.id };
      hideBlocksOf = callerId;
    }
    const scope = `live-viewers:${room.id}`;
    let after: { at: Date; identity: string } | null = null;
    if (query.cursor !== undefined) {
      const position = this.cursors.decode(query.cursor, scope);
      if (!position) throw AppException.validation([{ field: 'cursor', issue: 'invalid_value' }]);
      after = { at: position.at, identity: position.n === 1 ? `${GUEST_PREFIX}${position.id}` : position.id };
    }
    const limit = Math.min(query.limit, VIEWER_PAGE_MAX);
    // v1.132-social (D379): the VIP holders of VIEWER_LIST_PRIORITY lead the first page; every page skips them.
    const priority = await this.priorityViewers(room.id, hideBlocksOf);
    const skip = priority.map((p) => p.identity);
    const rows = await this.prisma.liveRoomViewer.findMany({
      where: {
        roomId: room.id,
        room: { status: 'LIVE' },
        ...(skip.length > 0 ? { identity: { notIn: skip } } : {}),
        OR: [
          { guestId: { not: null } },
          {
            user: {
              status: 'ACTIVE',
              ...(hideBlocksOf === null
                ? {}
                : {
                    blocking: { none: { blockedId: hideBlocksOf } },
                    blockedBy: { none: { blockerId: hideBlocksOf } },
                  }),
            },
          },
        ],
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
      // v1.64-live (D260): the staff watching visibly, on the first page only.
      staff: after === null ? await this.staffWatchers(room.id) : [],
      data: [...(after === null ? priority : []), ...page].map((r) => ({
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

  /**
   * v1.132-social (D379, §10.169): the signed-in viewers of [roomId] whose active VIP holds VIEWER_LIST_PRIORITY (their
   * tier or a lower one), the higher tier first, then the latest joined; ACTIVE accounts with no block with [reader]
   * either way; at most {@link VIEWER_PRIORITY_MAX}. Nothing else about the list changes (staff, the host, guests).
   */
  private async priorityViewers(roomId: string, reader: string | null) {
    const rank = vipPerkRankSql('VIEWER_LIST_PRIORITY', Prisma.sql`v.user_id`);
    const blocks =
      reader === null
        ? Prisma.empty
        : Prisma.sql`AND NOT EXISTS (SELECT 1 FROM user_blocks b
                       WHERE (b.blocker_id = v.user_id AND b.blocked_id = ${reader}::uuid)
                          OR (b.blocker_id = ${reader}::uuid AND b.blocked_id = v.user_id))`;
    const ranked = await this.prisma.$queryRaw<{ identity: string; rank: number }[]>`
      SELECT * FROM (
        SELECT v.identity, ${rank} AS rank, v.joined_at
          FROM live_room_viewers v JOIN users u ON u.id = v.user_id AND u.status = 'ACTIVE'
          JOIN live_rooms r ON r.id = v.room_id AND r.status = 'LIVE'
         WHERE v.room_id = ${roomId}::uuid AND v.user_id IS NOT NULL ${blocks}) q
       WHERE q.rank IS NOT NULL
       ORDER BY q.rank DESC, q.joined_at DESC, q.identity DESC
       LIMIT ${VIEWER_PRIORITY_MAX}`;
    if (ranked.length === 0) return [];
    const rows = await this.prisma.liveRoomViewer.findMany({
      where: { roomId, identity: { in: ranked.map((r) => r.identity) } },
      include: { user: { select: USER_SUMMARY_SELECT } },
    });
    const byIdentity = new Map(rows.map((r) => [r.identity, r]));
    return ranked.flatMap((r) => {
      const row = byIdentity.get(r.identity);
      return row ? [row] : [];
    });
  }

  /**
   * v1.64-live (D260, §10.96): the staff watching a LIVE room visibly, one entry per staff member (earliest join
   * first), with their panel name and picture — never a user card (no username, no id).
   */
  async staffWatchers(roomId: string): Promise<LiveStaffWatcherDto[]> {
    const rows = await this.prisma.liveRoomStaffWatcher.findMany({
      // v1.68-live (D273, §10.96.6): only who holds a watch role now — a revoked role drops the badge at once.
      where: {
        roomId,
        room: { status: 'LIVE' },
        admin: {
          role: 'ADMIN',
          status: 'ACTIVE',
          adminPermissions: { some: { permission: { in: [...WATCH_STAFF_ROLES] } } },
        },
      },
      orderBy: [{ joinedAt: 'asc' }, { identity: 'asc' }],
      select: {
        adminId: true,
        joinedAt: true,
        admin: { select: { profile: { select: { displayName: true, avatarUrl: true } } } },
      },
      take: 50,
    });
    const seen = new Set<string>();
    const out: LiveStaffWatcherDto[] = [];
    for (const r of rows) {
      if (seen.has(r.adminId)) continue;
      seen.add(r.adminId);
      out.push({
        displayName: r.admin.profile?.displayName ?? 'Kabso',
        avatarUrl: r.admin.profile?.avatarUrl ?? null,
        since: r.joinedAt.toISOString(),
      });
    }
    return out;
  }

  // ---- Presence --------------------------------------------------------------------------------

  /**
   * `viewer_count` = connected identities other than the host (the host has no row); v1.27.6-live
   * (D140) also keeps the peak.
   */
  private async recount(db: Prisma.TransactionClient | PrismaService, roomId: string): Promise<void> {
    await recountViewers(db, roomId);
  }

  /**
   * `POST /internal/livekit/webhook`: a signed media-server event. A join is recorded only for a
   * LIVE room and an allowed identity (a guest while guests are allowed, an ACTIVE user with no
   * block and, v1.20-live, not kicked out of this live); anyone else is disconnected. Leaves and finished rooms remove rows. Idempotent.
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
      await closeVisits(this.prisma, roomId, null, this.clock.now());
      await this.prisma.liveRoomViewer.deleteMany({ where: { roomId } });
      await this.prisma.liveRoomStaffWatcher.deleteMany({ where: { roomId } });
      await this.recount(this.prisma, roomId);
      return;
    }
    if (event.kind === 'left') {
      // v1.43-live (D195): a PK watcher of the other room is never a viewer here; a host leaving
      // their own media session during a PK battle starts the absence time.
      if (event.identity.startsWith(PK_IDENTITY_PREFIX)) return;
      // v1.118-live (D391, §10.180): nor a 4-way PK watcher of another room.
      if (event.identity.startsWith(PK4_IDENTITY_PREFIX)) return;
      // v1.60-live (D250): a staff observer was never recorded.
      if (event.identity.startsWith(STAFF_IDENTITY_PREFIX)) return;
      // v1.64-live (D260): a visible staff watcher is no longer listed (never counted).
      if (event.identity.startsWith(TEAM_IDENTITY_PREFIX)) {
        await this.prisma.liveRoomStaffWatcher.deleteMany({ where: { roomId, identity: event.identity } });
        return;
      }
      // v1.45-live (D201): a host's second camera is never a viewer; it leaving ends the camera.
      if (event.identity.startsWith(SECOND_CAMERA_PREFIX)) {
        await this.tools.onLeft(roomId, event.identity);
        return;
      }
      await this.pk.onHostMedia(roomId, event.identity, false);
      await this.pk4.onHostMedia(roomId, event.identity, false);
      await closeVisits(this.prisma, roomId, [event.identity], this.clock.now());
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
    // v1.43-live (D195, §10.58): a viewer (or the host) of the other room of a PK, watch-only and
    // hidden — allowed while that match runs, never recorded or counted as a viewer of this room.
    if (identity.startsWith(PK_IDENTITY_PREFIX)) {
      if (!room || room.status !== 'LIVE' || !(await this.pk.allowsWatcher(roomId, identity))) {
        await this.kick(roomId, identity);
      }
      return;
    }
    // v1.118-live (D391, §10.180): a watcher of a 4-way PK's other room — the same rule for its four rooms.
    if (identity.startsWith(PK4_IDENTITY_PREFIX)) {
      if (!room || room.status !== 'LIVE' || !(await this.pk4.allowsWatcher(roomId, identity))) {
        await this.kick(roomId, identity);
      }
      return;
    }
    // v1.60-live (D250, §10.91): a staff observer from the panel — hidden, kept while the room is LIVE, never recorded
    // or counted as a viewer, never announced in the chat.
    if (identity.startsWith(STAFF_IDENTITY_PREFIX)) {
      if (!room || room.status !== 'LIVE') await this.kick(roomId, identity);
      return;
    }
    // v1.64-live (D260, §10.96): a staff member watching visibly — listed with the «فريق كابسو» badge while the room
    // is LIVE, never a viewer (no `live_room_viewers` row, not counted, no join line).
    if (identity.startsWith(TEAM_IDENTITY_PREFIX)) {
      const adminId = teamAdminIdOf(identity);
      if (!room || room.status !== 'LIVE' || adminId === null) {
        await this.kick(roomId, identity);
        return;
      }
      const added = await this.prisma.liveRoomStaffWatcher.createMany({
        data: [{ roomId, identity, adminId, joinedAt: this.clock.now() }],
        skipDuplicates: true,
      });
      // v1.72-live (D283): a limited staff account's visible entry plays the team's entry car.
      if (added.count > 0) await this.chat.announceStaffJoin(roomId, adminId);
      return;
    }
    // v1.45-live (D201): the host's second camera — kept or removed, never counted.
    if (identity.startsWith(SECOND_CAMERA_PREFIX)) {
      await this.tools.onJoined(roomId, identity);
      return;
    }
    const guestId = guestIdOf(identity);
    const userId = guestId === null && isUuid(identity) ? identity.toLowerCase() : null;
    if (!room || room.status !== 'LIVE' || (guestId === null && userId === null)) {
      await this.kick(roomId, identity);
      return;
    }
    if (userId === room.hostUserId) {
      // The host is not a viewer; back in the session during a PK battle (D195).
      await this.pk.onHostMedia(roomId, userId, true);
      await this.pk4.onHostMedia(roomId, userId, true);
      return;
    }
    if (guestId !== null && !room.allowGuests) {
      await this.kick(roomId, identity);
      return;
    }
    if (userId !== null) {
      const [allowed] = await this.prisma.$queryRaw<{ ok: boolean }[]>`
        SELECT EXISTS (SELECT 1 FROM users WHERE id = ${userId}::uuid AND status = 'ACTIVE'::user_status)
           AND NOT EXISTS (SELECT 1 FROM live_room_kicks k
                            WHERE k.room_id = ${roomId}::uuid AND k.user_id = ${userId}::uuid)
           AND NOT EXISTS (SELECT 1 FROM user_blocks b
                            WHERE (b.blocker_id = ${userId}::uuid AND b.blocked_id = ${room.hostUserId}::uuid)
                               OR (b.blocker_id = ${room.hostUserId}::uuid AND b.blocked_id = ${userId}::uuid)) AS ok`;
      if (!allowed?.ok) {
        await this.kick(roomId, identity);
        return;
      }
    }
    const now = this.clock.now();
    const recorded = await this.prisma.liveRoomViewer.createMany({
      data: [{ roomId, identity, userId, guestId, joinedAt: now }],
      skipDuplicates: true,
    });
    // v1.27.6-live (D140): the audience record of the live's statistics.
    await openVisit(this.prisma, roomId, identity, userId, now);
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

  /**
   * v1.68-live (D273, §10.96.6): `userId` lost their last watch role (or the account) — their visible watches are no
   * longer listed and every `team:` / `staff:` connection of theirs is disconnected (best effort; the reconciliation
   * repeats it for the visible ones). Returns how many were disconnected.
   */
  async dropStaffPresence(userId: string): Promise<number> {
    const rows = await this.prisma.liveRoomStaffWatcher.findMany({
      where: { adminId: userId },
      select: { roomId: true, identity: true },
    });
    await this.prisma.liveRoomStaffWatcher.deleteMany({ where: { adminId: userId } });
    let n = 0;
    for (const r of rows) {
      await this.kick(r.roomId, r.identity);
      n += 1;
    }
    try {
      const hiddenPrefix = `${STAFF_IDENTITY_PREFIX}${userId}:`;
      for (const room of (await this.media.listRooms()).filter(isUuid)) {
        for (const identity of await this.media.listIdentities(room)) {
          if (identity.toLowerCase().startsWith(hiddenPrefix)) {
            await this.kick(room, identity);
            n += 1;
          }
        }
      }
    } catch (err) {
      this.logger.warn({ error: safeErrorLog(err) }, 'Could not list the media rooms for a staff member');
    }
    return n;
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
    await closeVisits(this.prisma, roomId, null, this.clock.now());
    await this.prisma.liveRoomViewer.deleteMany({ where: { roomId } });
    await this.prisma.liveRoomStaffWatcher.deleteMany({ where: { roomId } });
    // v1.45-live (D201): the live's second-camera code and camera end with it.
    await this.tools.onRoomClosed(roomId);
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
    // v1.47-live (D212): podcast questions whose time is over.
    await this.seats.demoteExpired();
    // v1.132-social (D379): seats kept for someone whose time is over.
    await this.seats.releaseExpiredReservations();
    await closeVisitsOfEndedRooms(this.prisma);
    await this.prisma.$executeRaw`
      DELETE FROM live_room_viewers v USING live_rooms r
       WHERE r.id = v.room_id AND r.status <> 'LIVE'`;
    // v1.64-live (D260): visible staff watchers of ended rooms.
    await this.prisma.$executeRaw`
      DELETE FROM live_room_staff_watchers w USING live_rooms r
       WHERE r.id = w.room_id AND r.status <> 'LIVE'`;
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
      // v1.64-live (D260): visible staff watchers who are gone are no longer listed.
      const team = await this.prisma.liveRoomStaffWatcher.findMany({
        where: { roomId: name.toLowerCase() },
        select: { identity: true },
      });
      const teamGone = team.map((r) => r.identity).filter((i) => !connected.has(i));
      // v1.68-live (D273): a visible staff watcher who no longer holds a watch role is disconnected.
      const holders = await watchStaffAmong(
        this.prisma,
        team.map((r) => teamAdminIdOf(r.identity)).filter((id): id is string => id !== null),
      );
      for (const r of team) {
        const adminId = teamAdminIdOf(r.identity);
        if (adminId !== null && !holders.has(adminId) && connected.has(r.identity)) {
          await this.kick(name.toLowerCase(), r.identity);
          teamGone.push(r.identity);
        }
      }
      if (teamGone.length > 0) {
        await this.prisma.liveRoomStaffWatcher.deleteMany({
          where: { roomId: name.toLowerCase(), identity: { in: teamGone } },
        });
      }
      // Joins whose webhook was missed are recorded (or refused) like the webhook would.
      const recorded = new Set([...rows.map((r) => r.identity), ...team.map((r) => r.identity)]);
      for (const identity of connected) {
        if (!recorded.has(identity)) await this.onJoined(name.toLowerCase(), identity);
      }
      if (gone.length > 0) {
        await closeVisits(this.prisma, name.toLowerCase(), gone, this.clock.now());
        await this.prisma.liveRoomViewer.deleteMany({ where: { roomId: name, identity: { in: gone } } });
        await this.recount(this.prisma, name);
        // CP-011: a seated user who is gone loses the seat (as with a `participant_left` webhook).
        for (const identity of gone)
          if (isUuid(identity)) await this.seats.onLeft(name, identity.toLowerCase());
      }
      // CP-011: re-apply seat permissions and the seat version a failed call may have missed.
      try {
        await this.tools.reconcileRoom(name.toLowerCase(), connected);
      } catch (err) {
        this.logger.warn(
          { error: safeErrorLog(err) },
          'Could not reconcile the second camera of a media room',
        );
      }
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
  async grantHost(
    adminId: string,
    username: string,
    meta: RequestMeta,
    extra: { reason?: string; via?: 'panel' } = {},
  ): Promise<boolean> {
    const user = await this.users.findActivePublicUser(username);
    if (!user) throw new AppException(ErrorCode.NOT_FOUND);
    return this.prisma.$transaction(async (tx) => {
      // v1.82-live (D295, §10.108): a content creator cannot also be a host (their permission comes with the membership).
      if (await isCreatorIn(tx, user.id)) throw creatorHostRefused('CREATOR');
      // CP-016 G: the room number is drawn by the column default; `skipDuplicates` would also
      // skip a (rare) clash on it, so draw again while the host is still missing.
      let created = { count: 0 };
      for (let attempt = 0; attempt < 5 && created.count === 0; attempt += 1) {
        created = await tx.liveHost.createMany({
          data: [{ userId: user.id, source: 'ADMIN', grantedById: adminId }],
          skipDuplicates: true,
        });
        if (created.count === 0 && (await tx.liveHost.count({ where: { userId: user.id } })) > 0) break;
      }
      if (created.count > 0) {
        await this.audit.recordIn(tx, {
          action: AuditAction.LIVE_HOST_GRANT,
          actorUserId: adminId,
          targetType: 'user',
          targetId: user.id,
          metadata: { source: 'ADMIN', ...extra },
          ip: meta.ip,
          requestId: meta.requestId,
        });
      }
      return created.count > 0;
    });
  }

  /**
   * v1.82-live (D295): ends `hostUserId`'s running live (`ADMIN`) and closes its media — after the hosting permission
   * went with a creator membership (revoked by the team or by an agency ban). Returns how many rooms ended.
   */
  async endHostedRooms(hostUserId: string): Promise<number> {
    const rooms = await this.prisma.$transaction(
      (tx) => this.rooms.endByAdminIn(tx, { hostUserId }),
      LIVE_TX_OPTIONS,
    );
    for (const roomId of rooms) await this.closeMedia(roomId);
    return rooms.length;
  }

  /** `DELETE /admin/live/hosts/{username}`: also ends the user's LIVE room (`ADMIN`). */
  async revokeHost(
    adminId: string,
    username: string,
    meta: RequestMeta,
    extra: { reason?: string; via?: 'panel' } = {},
  ): Promise<boolean> {
    const user = await this.users.findActivePublicUser(username);
    if (!user) throw new AppException(ErrorCode.NOT_FOUND);
    const ended = await this.prisma.$transaction(async (tx) => {
      // v1.82-live (D295): a creator's permission ends only with the membership («صناع المحتوى» → revoke).
      const creator = await isCreatorIn(tx, user.id);
      const row = await tx.liveHost.findUnique({ where: { userId: user.id }, select: { source: true } });
      if (creator && row?.source === 'CREATOR') throw creatorHostRefused('CREATOR');
      const removed = await tx.liveHost.deleteMany({ where: { userId: user.id } });
      const rooms = await this.rooms.endByAdminIn(tx, { hostUserId: user.id });
      // D295 (owner: never both; rows from before D295 are resolved by hand): revoking the HOST role of a person who is
      // also a creator leaves them a creator — the membership's permission (CREATOR) is given back at once.
      if (creator && removed.count > 0) {
        let granted = 0;
        for (let attempt = 0; attempt < 5 && granted === 0; attempt += 1) {
          granted = (
            await tx.liveHost.createMany({
              data: [{ userId: user.id, source: 'CREATOR', grantedById: adminId }],
              skipDuplicates: true,
            })
          ).count;
        }
        await this.audit.recordIn(tx, {
          action: AuditAction.LIVE_HOST_GRANT,
          actorUserId: adminId,
          targetType: 'user',
          targetId: user.id,
          metadata: { source: 'CREATOR', resolvedBothRoles: true, ...extra },
          ip: meta.ip,
          requestId: meta.requestId,
        });
      }
      // v1.90-social (D293, §10.105): no longer a host → the blue badge goes at once (unless another applies).
      if (removed.count > 0) await recomputeBadgesIn(tx, [user.id], 'host');
      if (removed.count > 0 || rooms.length > 0) {
        await this.audit.recordIn(tx, {
          action: AuditAction.LIVE_HOST_REVOKE,
          actorUserId: adminId,
          targetType: 'user',
          targetId: user.id,
          metadata: { endedRooms: rooms.length, ...extra },
          ip: meta.ip,
          requestId: meta.requestId,
        });
      }
      return { rooms, removed: removed.count > 0 };
    }, LIVE_TX_OPTIONS);
    for (const roomId of ended.rooms) await this.closeMedia(roomId);
    return ended.removed;
  }
}
