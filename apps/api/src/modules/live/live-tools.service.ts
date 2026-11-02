import { createHmac, hkdfSync, randomInt } from 'node:crypto';
import { Inject, Injectable, Logger } from '@nestjs/common';
import { z } from 'zod';
import { AuditAction, AuditService } from '../../common/audit/audit.service.js';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { Clock } from '../../common/time/clock.js';
import { zodErrorToDetails } from '../../common/validation/zod-validation.pipe.js';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import { Prisma } from '../../generated/prisma/client.js';
import { safeErrorLog } from '../../logging/redact-text.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { UsersService, violatedUniqueIndex } from '../users/users.service.js';
import { LIVE_TX_OPTIONS, type RequestMeta } from './live-rooms.service.js';
import { isUuid } from './live.schemas.js';
import { LIVE_MEDIA_PROVIDER, type LiveMediaProvider } from './media/live-media.provider.js';

/**
 * v1.45-live (DRAFT, D201, CONVENTIONS §10.63): the host's live tools «كاميرتان», «موسيقى» and «التسجيل».
 *
 * **Second camera.** A second device of the SAME account publishes a second camera into the host's
 * LIVE SOLO video live. On the main device the host creates a 6-digit code (single use, valid
 * `LIVE_SECOND_CAMERA_CODE_SECONDS`, only its HMAC stored, one open code per live); the second device
 * redeems it and gets a media token for identity `cam2:<hostUserId>` that may publish the camera and
 * the microphone only, subscribes to nothing and publishes no data. One second camera per live; none
 * during a PK (refused, and ended by the reconciliation when a PK starts). The webhook never counts
 * `cam2:` as a viewer; it leaves → the camera ended; the live ends → ended.
 *
 * **Music rights.** The one-time notice «تأكد أنك تملك حقوق تشغيل الموسيقى…» accepted, stored once.
 *
 * **Recording.** The clip is recorded on the host's phone (nothing reaches the server); the host
 * tells the room it records so viewers see «يتم التسجيل»: a participant attribute on the host, with an
 * end time at most {@link RECORDING_MAX_SECONDS} (+1) seconds away, so it clears itself.
 */

/** Media identity of a host's second camera. */
export const SECOND_CAMERA_PREFIX = 'cam2:';

export function secondCameraIdentity(hostUserId: string): string {
  return `${SECOND_CAMERA_PREFIX}${hostUserId}`;
}

/** The host user id of a `cam2:<uuid>` identity, else null. */
export function hostOfSecondCamera(identity: string): string | null {
  if (!identity.startsWith(SECOND_CAMERA_PREFIX)) return null;
  const id = identity.slice(SECOND_CAMERA_PREFIX.length);
  return isUuid(id) ? id.toLowerCase() : null;
}

/** Participant attribute on the `cam2:` participant: `HOST` or `SECOND`, the default main feed. */
export const ATTR_MAIN_FEED = 'kabso.mainFeed';
/** Participant attribute on the host: the ISO time a clip recording ends (absent: not recording). */
export const ATTR_RECORDING_UNTIL = 'kabso.recordingUntil';

export const SECOND_CAMERA_TOKEN_TTL_SECONDS = 600;
/**
 * D243: a second camera that left (`LEFT`) and joins again within this time is the same device
 * reconnecting (LiveKit's full reconnect: a new session with the same identity, the old one's
 * `participant_left` arriving first) — its camera is kept, not removed.
 */
export const SECOND_CAMERA_REJOIN_SECONDS = 60;
export const RECORDING_MAX_SECONDS = 60;
/** The music-rights notice's text version (§10.63); a new text gets a new version. */
export const MUSIC_NOTICE_VERSION = 1;

export const SECOND_CAMERA_CODE_DIGITS = 6;

export const redeemSecondCameraSchema = z.object({ code: z.string().regex(/^[0-9]{6}$/) }).strict();
export const secondCameraMainSchema = z.object({ main: z.enum(['HOST', 'SECOND']) }).strict();
export const recordingSchema = z.object({ active: z.boolean() }).strict();
export const musicRightsSchema = z.object({ noticeVersion: z.literal(MUSIC_NOTICE_VERSION) }).strict();

export type SecondCameraMain = 'HOST' | 'SECOND';

export interface SecondCameraStateDto {
  /** NONE, CODE (an open code), PAIRED (redeemed, not in the media session yet), CONNECTED. */
  status: 'NONE' | 'CODE' | 'PAIRED' | 'CONNECTED';
  codeExpiresAt: string | null;
  main: SecondCameraMain;
  /** Whether a code may be created now (false: `unavailableReason`). */
  available: boolean;
  unavailableReason: 'NOT_LIVE' | 'NOT_SOLO' | 'PK' | null;
  /** The media identity the second camera publishes as. */
  identity: string;
}

export interface SecondCameraCodeDto {
  code: string;
  expiresAt: string;
  ttlSeconds: number;
}

export interface SecondCameraAccessDto {
  roomId: string;
  hostUserId: string;
  url: string;
  token: string;
  expiresAt: string;
  identity: string;
  main: SecondCameraMain;
}

export interface LiveRecordingDto {
  active: boolean;
  until: string | null;
  maxSeconds: number;
}

export interface MusicRightsDto {
  accepted: boolean;
  acceptedAt: string | null;
  noticeVersion: number;
}

type EndReason = 'REVOKED' | 'EXPIRED' | 'LEFT' | 'ROOM_ENDED' | 'PK';

interface OwnRoom {
  id: string;
  status: string;
  mode: string;
  hostUserId: string;
}

@Injectable()
export class LiveToolsService {
  private readonly logger = new Logger(LiveToolsService.name);
  private readonly codeKey: Buffer;

  constructor(
    private readonly prisma: PrismaService,
    private readonly users: UsersService,
    private readonly audit: AuditService,
    private readonly clock: Clock,
    @Inject(LIVE_MEDIA_PROVIDER) private readonly media: LiveMediaProvider,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
  ) {
    this.codeKey = Buffer.from(hkdfSync('sha256', config.live.guestKey, '', 'live-second-camera/v1', 32));
  }

  /** The code's HMAC, bound to the account (another account's identical code never matches). */
  codeHash(hostUserId: string, code: string): string {
    return createHmac('sha256', this.codeKey).update(`${hostUserId.toLowerCase()}:${code}`).digest('hex');
  }

  // ---- shared checks -----------------------------------------------------------------------------

  private async ownRoom(callerId: string, roomId: string): Promise<OwnRoom> {
    if (!isUuid(roomId)) throw new AppException(ErrorCode.NOT_FOUND);
    const room = await this.prisma.liveRoom.findFirst({
      where: { id: roomId.toLowerCase(), hostUserId: callerId },
      select: { id: true, status: true, mode: true, hostUserId: true },
    });
    if (!room) throw new AppException(ErrorCode.NOT_FOUND);
    return room;
  }

  private async inPk(db: Prisma.TransactionClient | PrismaService, roomId: string): Promise<boolean> {
    const [row] = await db.$queryRaw<{ pk: boolean }[]>`
      SELECT EXISTS (SELECT 1 FROM pk_matches
                      WHERE status <> 'CLOSED' AND (room_a_id = ${roomId}::uuid OR room_b_id = ${roomId}::uuid)) AS pk`;
    return row?.pk === true;
  }

  /** Why the room cannot take a second camera now, or null. */
  private async unavailable(room: OwnRoom): Promise<SecondCameraStateDto['unavailableReason']> {
    if (room.status !== 'LIVE') return 'NOT_LIVE';
    if (room.mode !== 'SOLO') return 'NOT_SOLO';
    if (await this.inPk(this.prisma, room.id)) return 'PK';
    return null;
  }

  private async endRows(
    db: Prisma.TransactionClient | PrismaService,
    where: Prisma.LiveSecondCameraWhereInput,
    reason: EndReason,
  ): Promise<{ id: string; roomId: string; hostUserId: string; redeemed: boolean }[]> {
    const rows = await db.liveSecondCamera.findMany({
      where: { ...where, endedAt: null },
      select: { id: true, roomId: true, hostUserId: true, redeemedAt: true },
    });
    if (rows.length === 0) return [];
    await db.liveSecondCamera.updateMany({
      where: { id: { in: rows.map((r) => r.id) }, endedAt: null },
      data: { endedAt: this.clock.now(), endReason: reason },
    });
    return rows.map((r) => ({
      id: r.id,
      roomId: r.roomId,
      hostUserId: r.hostUserId,
      redeemed: r.redeemedAt !== null,
    }));
  }

  private async kick(roomId: string, identity: string): Promise<void> {
    try {
      await this.media.removeParticipant(roomId, identity);
    } catch (err) {
      this.logger.warn(
        { error: safeErrorLog(err) },
        'Could not remove the second camera from the media session',
      );
    }
  }

  // ---- second camera -----------------------------------------------------------------------------

  /** `GET /live/rooms/{roomId}/second-camera` (the host, from either device). */
  async state(callerId: string, roomId: string): Promise<SecondCameraStateDto> {
    const room = await this.ownRoom(callerId, roomId);
    const reason = await this.unavailable(room);
    const rows = await this.prisma.liveSecondCamera.findMany({
      where: { roomId: room.id, endedAt: null },
      select: { redeemedAt: true, connectedAt: true, expiresAt: true, mainFeed: true },
    });
    const now = this.clock.now();
    const camera = rows.find((r) => r.redeemedAt !== null);
    const code = rows.find((r) => r.redeemedAt === null && r.expiresAt > now);
    return {
      status: camera ? (camera.connectedAt ? 'CONNECTED' : 'PAIRED') : code ? 'CODE' : 'NONE',
      codeExpiresAt: !camera && code ? code.expiresAt.toISOString() : null,
      main: camera?.mainFeed ?? 'HOST',
      available: reason === null,
      unavailableReason: reason,
      identity: secondCameraIdentity(room.hostUserId),
    };
  }

  /**
   * `POST /live/rooms/{roomId}/second-camera/codes`: a new code (an open one is replaced). Refused
   * while the live has a second camera, outside a LIVE SOLO video live and during a PK.
   */
  async createCode(callerId: string, roomId: string, meta: RequestMeta): Promise<SecondCameraCodeDto> {
    if (!this.config.live.hostingEnabled) throw new AppException(ErrorCode.LIVE_HOSTING_UNAVAILABLE);
    const room = await this.ownRoom(callerId, roomId);
    if ((await this.unavailable(room)) !== null) throw new AppException(ErrorCode.SECOND_CAMERA_UNAVAILABLE);
    const ttl = this.config.live.secondCameraCodeSeconds;
    for (let attempt = 0; ; attempt += 1) {
      const code = String(randomInt(0, 10 ** SECOND_CAMERA_CODE_DIGITS)).padStart(
        SECOND_CAMERA_CODE_DIGITS,
        '0',
      );
      const now = this.clock.now();
      const expiresAt = new Date(now.getTime() + ttl * 1000);
      try {
        await this.prisma.$transaction(async (tx) => {
          await tx.$queryRaw`SELECT id FROM live_rooms WHERE id = ${room.id}::uuid FOR UPDATE`;
          const camera = await tx.liveSecondCamera.count({
            where: { roomId: room.id, endedAt: null, redeemedAt: { not: null } },
          });
          if (camera > 0) throw new AppException(ErrorCode.SECOND_CAMERA_BUSY);
          await this.endRows(tx, { roomId: room.id, redeemedAt: null }, 'REVOKED');
          await tx.liveSecondCamera.create({
            data: {
              roomId: room.id,
              hostUserId: callerId,
              codeHash: this.codeHash(callerId, code),
              createdAt: now,
              expiresAt,
            },
          });
          await this.audit.recordIn(tx, {
            action: AuditAction.LIVE_SECOND_CAMERA_CODE,
            actorUserId: callerId,
            targetType: 'live_room',
            targetId: room.id,
            metadata: { ttlSeconds: ttl },
            ip: meta.ip,
            requestId: meta.requestId,
          });
        }, LIVE_TX_OPTIONS);
        return { code, expiresAt: expiresAt.toISOString(), ttlSeconds: ttl };
      } catch (err) {
        // Two code requests at once: the room lock orders them; a unique clash is retried once.
        if (violatedUniqueIndex(err) !== null && attempt < 1) continue;
        throw err;
      }
    }
  }

  private async refuse(
    callerId: string,
    reason: 'unknown' | 'expired' | 'used' | 'unavailable' | 'busy',
    roomId: string | null,
    meta: RequestMeta,
  ): Promise<void> {
    await this.audit.record({
      action: AuditAction.LIVE_SECOND_CAMERA_REFUSED,
      actorUserId: callerId,
      targetType: roomId ? 'live_room' : 'user',
      targetId: roomId ?? callerId,
      metadata: { reason },
      ip: meta.ip,
      requestId: meta.requestId,
    });
  }

  /**
   * `POST /live/second-camera/redeem` on the second device: the code of the SAME account, unexpired
   * and unused, for the account's LIVE SOLO video live with no second camera and no PK. Unknown,
   * expired, used and other-account codes get one answer (`SECOND_CAMERA_CODE_INVALID`).
   */
  async redeem(callerId: string, body: unknown, meta: RequestMeta): Promise<SecondCameraAccessDto> {
    if (!this.config.live.hostingEnabled) throw new AppException(ErrorCode.LIVE_HOSTING_UNAVAILABLE);
    const parsed = redeemSecondCameraSchema.safeParse(body ?? {});
    if (!parsed.success) throw AppException.validation(zodErrorToDetails(parsed.error));
    const hash = this.codeHash(callerId, parsed.data.code);
    const row = await this.prisma.liveSecondCamera.findFirst({
      where: { hostUserId: callerId, codeHash: hash },
      orderBy: { createdAt: 'desc' },
      select: {
        id: true,
        roomId: true,
        expiresAt: true,
        redeemedAt: true,
        endedAt: true,
        endReason: true,
        room: { select: { status: true, mode: true, hostUserId: true } },
      },
    });
    const now = this.clock.now();
    if (!row) {
      await this.refuse(callerId, 'unknown', null, meta);
      throw new AppException(ErrorCode.SECOND_CAMERA_CODE_INVALID);
    }
    if (row.redeemedAt !== null || (row.endedAt !== null && row.endReason !== 'EXPIRED')) {
      await this.refuse(callerId, 'used', row.roomId, meta);
      throw new AppException(ErrorCode.SECOND_CAMERA_CODE_INVALID);
    }
    if (row.endedAt !== null || row.expiresAt <= now) {
      await this.endRows(this.prisma, { id: row.id }, 'EXPIRED');
      await this.refuse(callerId, 'expired', row.roomId, meta);
      throw new AppException(ErrorCode.SECOND_CAMERA_CODE_INVALID);
    }
    const room: OwnRoom = { id: row.roomId, ...row.room };
    if ((await this.unavailable(room)) !== null) {
      await this.endRows(this.prisma, { id: row.id }, row.room.status === 'LIVE' ? 'PK' : 'ROOM_ENDED');
      await this.refuse(callerId, 'unavailable', row.roomId, meta);
      throw new AppException(ErrorCode.SECOND_CAMERA_UNAVAILABLE);
    }
    // A new pairing starts with the host's camera as the main feed.
    const main: SecondCameraMain = 'HOST';
    try {
      await this.prisma.$transaction(async (tx) => {
        const taken = await tx.liveSecondCamera.updateMany({
          where: { id: row.id, redeemedAt: null, endedAt: null, expiresAt: { gt: now } },
          data: { redeemedAt: now },
        });
        if (taken.count === 0) throw new AppException(ErrorCode.SECOND_CAMERA_CODE_INVALID);
        await this.audit.recordIn(tx, {
          action: AuditAction.LIVE_SECOND_CAMERA_REDEEM,
          actorUserId: callerId,
          targetType: 'live_room',
          targetId: row.roomId,
          metadata: {},
          ip: meta.ip,
          requestId: meta.requestId,
        });
      }, LIVE_TX_OPTIONS);
    } catch (err) {
      if (violatedUniqueIndex(err) !== null) {
        await this.refuse(callerId, 'busy', row.roomId, meta);
        throw new AppException(ErrorCode.SECOND_CAMERA_BUSY);
      }
      if (err instanceof AppException) await this.refuse(callerId, 'used', row.roomId, meta);
      throw err;
    }
    const me = await this.users.getMe(callerId);
    const identity = secondCameraIdentity(callerId);
    const token = await this.media.issueToken({
      room: row.roomId,
      identity,
      name: me?.displayName || me?.username || '',
      publish: true,
      sources: ['camera', 'microphone'],
      subscribe: false,
      attributes: { [ATTR_MAIN_FEED]: main },
      ttlSeconds: SECOND_CAMERA_TOKEN_TTL_SECONDS,
    });
    return {
      roomId: row.roomId,
      hostUserId: callerId,
      url: this.media.url,
      token,
      expiresAt: new Date(now.getTime() + SECOND_CAMERA_TOKEN_TTL_SECONDS * 1000).toISOString(),
      identity,
      main,
    };
  }

  /** `DELETE /live/rooms/{roomId}/second-camera`: ends the open code and the second camera (either device). */
  async end(callerId: string, roomId: string, meta: RequestMeta): Promise<void> {
    const room = await this.ownRoom(callerId, roomId);
    const ended = await this.prisma.$transaction(async (tx) => {
      const rows = await this.endRows(tx, { roomId: room.id }, 'REVOKED');
      if (rows.length > 0) {
        await this.audit.recordIn(tx, {
          action: AuditAction.LIVE_SECOND_CAMERA_END,
          actorUserId: callerId,
          targetType: 'live_room',
          targetId: room.id,
          metadata: { reason: 'REVOKED', camera: rows.some((r) => r.redeemed) },
          ip: meta.ip,
          requestId: meta.requestId,
        });
      }
      return rows;
    }, LIVE_TX_OPTIONS);
    if (ended.some((r) => r.redeemed)) await this.kick(room.id, secondCameraIdentity(room.hostUserId));
  }

  /** `PUT /live/rooms/{roomId}/second-camera/main`: the feed viewers see full screen by default. */
  async setMain(
    callerId: string,
    roomId: string,
    body: unknown,
    meta: RequestMeta,
  ): Promise<SecondCameraStateDto> {
    const parsed = secondCameraMainSchema.safeParse(body ?? {});
    if (!parsed.success) throw AppException.validation(zodErrorToDetails(parsed.error));
    const room = await this.ownRoom(callerId, roomId);
    const main = parsed.data.main;
    const changed = await this.prisma.$transaction(async (tx) => {
      const camera = await tx.liveSecondCamera.findFirst({
        where: { roomId: room.id, endedAt: null, redeemedAt: { not: null } },
        select: { id: true, mainFeed: true },
      });
      if (!camera) throw new AppException(ErrorCode.SECOND_CAMERA_UNAVAILABLE);
      if (camera.mainFeed === main) return false;
      await tx.liveSecondCamera.update({ where: { id: camera.id }, data: { mainFeed: main } });
      await this.audit.recordIn(tx, {
        action: AuditAction.LIVE_SECOND_CAMERA_MAIN,
        actorUserId: callerId,
        targetType: 'live_room',
        targetId: room.id,
        metadata: { main },
        ip: meta.ip,
        requestId: meta.requestId,
      });
      return true;
    }, LIVE_TX_OPTIONS);
    if (changed) {
      try {
        await this.media.setParticipantAttributes(room.id, secondCameraIdentity(room.hostUserId), {
          [ATTR_MAIN_FEED]: main,
        });
      } catch (err) {
        this.logger.warn({ error: safeErrorLog(err) }, 'Could not set the main feed on the second camera');
      }
    }
    return this.state(callerId, room.id);
  }

  // ---- the media session (webhook, reconciliation, room end) ----------------------------------

  /**
   * A `cam2:` identity joined: kept only when it is this live's host's redeemed second camera, the live
   * is LIVE and SOLO and not in a PK; otherwise removed. Never a viewer.
   */
  async onJoined(roomId: string, identity: string): Promise<void> {
    const hostId = hostOfSecondCamera(identity);
    const room = await this.prisma.liveRoom.findUnique({
      where: { id: roomId },
      select: { id: true, status: true, mode: true, hostUserId: true },
    });
    let camera =
      room && hostId === room.hostUserId
        ? await this.prisma.liveSecondCamera.findFirst({
            where: { roomId, hostUserId: hostId, endedAt: null, redeemedAt: { not: null } },
            select: { id: true, connectedAt: true },
          })
        : null;
    if (room && hostId === room.hostUserId && !camera && (await this.unavailable(room)) === null) {
      camera = await this.rejoin(roomId, hostId);
    }
    if (!room || !camera || (await this.unavailable(room)) !== null) {
      await this.kick(roomId, identity);
      return;
    }
    if (camera.connectedAt === null) {
      await this.prisma.liveSecondCamera.updateMany({
        where: { id: camera.id, connectedAt: null, endedAt: null },
        data: { connectedAt: this.clock.now() },
      });
    }
  }

  /**
   * D243: the camera that left (`LEFT`) at most {@link SECOND_CAMERA_REJOIN_SECONDS} ago is open again
   * — the same device back after a reconnect (only a `cam2:` token of this host, issued by a
   * redemption, can join as it). Never one the host ended, expired or a PK ended; never when another
   * camera was paired meanwhile (one at a time).
   */
  private async rejoin(
    roomId: string,
    hostId: string,
  ): Promise<{ id: string; connectedAt: Date | null } | null> {
    const since = new Date(this.clock.now().getTime() - SECOND_CAMERA_REJOIN_SECONDS * 1000);
    const left = await this.prisma.liveSecondCamera.findFirst({
      where: {
        roomId,
        hostUserId: hostId,
        endReason: 'LEFT',
        redeemedAt: { not: null },
        connectedAt: { not: null },
        endedAt: { gte: since },
      },
      orderBy: { endedAt: 'desc' },
      select: { id: true, connectedAt: true },
    });
    if (!left) return null;
    try {
      const reopened = await this.prisma.liveSecondCamera.updateMany({
        where: { id: left.id, endReason: 'LEFT' },
        data: { endedAt: null, endReason: null },
      });
      return reopened.count === 1 ? left : null;
    } catch {
      // Another camera was paired meanwhile (the one-camera index): this one stays ended.
      return null;
    }
  }

  /**
   * A `cam2:` identity left: its second camera ended (a new code pairs again). D243: not while that
   * identity is still in the media session — a reconnect replaced the old session, whose
   * `participant_left` came after the new one joined.
   */
  async onLeft(roomId: string, identity: string): Promise<void> {
    const hostId = hostOfSecondCamera(identity);
    if (hostId === null) return;
    try {
      if ((await this.media.listIdentities(roomId)).includes(identity)) return;
    } catch (err) {
      // Unknown: ended as before; a rejoin within the grace time opens it again.
      this.logger.warn({ error: safeErrorLog(err) }, 'Could not list the media session');
    }
    const rows = await this.endRows(
      this.prisma,
      { roomId, hostUserId: hostId, redeemedAt: { not: null }, connectedAt: { not: null } },
      'LEFT',
    );
    if (rows.length > 0) {
      await this.audit.record({
        action: AuditAction.LIVE_SECOND_CAMERA_END,
        actorUserId: null,
        targetType: 'live_room',
        targetId: roomId,
        metadata: { reason: 'LEFT', camera: true },
        ip: null,
        requestId: null,
      });
    }
  }

  /** The live's media session closed (the live ended): every code and camera of it ends. */
  async onRoomClosed(roomId: string): Promise<void> {
    if (!isUuid(roomId)) return;
    const rows = await this.endRows(this.prisma, { roomId: roomId.toLowerCase() }, 'ROOM_ENDED');
    if (rows.some((r) => r.redeemed)) {
      await this.audit.record({
        action: AuditAction.LIVE_SECOND_CAMERA_END,
        actorUserId: null,
        targetType: 'live_room',
        targetId: roomId.toLowerCase(),
        metadata: { reason: 'ROOM_ENDED', camera: true },
        ip: null,
        requestId: null,
      });
    }
  }

  /**
   * Reconciliation of one open media room: a connected second camera no longer in the session has
   * left; one in a live now in a PK is ended and removed; a redeemed camera that never joined within its
   * token's lifetime, and a code past its time, expire.
   */
  async reconcileRoom(roomId: string, connected: ReadonlySet<string>): Promise<void> {
    const now = this.clock.now();
    const rows = await this.prisma.liveSecondCamera.findMany({
      where: { roomId, endedAt: null },
      select: { id: true, hostUserId: true, redeemedAt: true, connectedAt: true, expiresAt: true },
    });
    if (rows.length === 0) return;
    const pk = await this.inPk(this.prisma, roomId);
    for (const row of rows) {
      const identity = secondCameraIdentity(row.hostUserId);
      if (row.redeemedAt === null) {
        if (row.expiresAt <= now) await this.endRows(this.prisma, { id: row.id }, 'EXPIRED');
        else if (pk) await this.endRows(this.prisma, { id: row.id }, 'PK');
        continue;
      }
      if (pk) {
        await this.endRows(this.prisma, { id: row.id }, 'PK');
        await this.kick(roomId, identity);
        continue;
      }
      if (row.connectedAt !== null && !connected.has(identity)) {
        await this.endRows(this.prisma, { id: row.id }, 'LEFT');
      } else if (
        row.connectedAt === null &&
        !connected.has(identity) &&
        now.getTime() - row.redeemedAt.getTime() > SECOND_CAMERA_TOKEN_TTL_SECONDS * 1000
      ) {
        await this.endRows(this.prisma, { id: row.id }, 'EXPIRED');
      }
    }
  }

  // ---- recording -----------------------------------------------------------------------------

  /**
   * `PUT /live/rooms/{roomId}/recording`: the host's phone records a clip (≤ 60 s) — or stopped. The
   * room's clients show «يتم التسجيل» while the host's `kabso.recordingUntil` is in the future.
   */
  async setRecording(
    callerId: string,
    roomId: string,
    body: unknown,
    meta: RequestMeta,
  ): Promise<LiveRecordingDto> {
    const parsed = recordingSchema.safeParse(body ?? {});
    if (!parsed.success) throw AppException.validation(zodErrorToDetails(parsed.error));
    const room = await this.ownRoom(callerId, roomId);
    if (room.status !== 'LIVE') throw new AppException(ErrorCode.LIVE_ROOM_ENDED);
    // D212: a podcast is voice only too (no camera clip).
    if (room.mode === 'AUDIO' || room.mode === 'PODCAST')
      throw AppException.validation([{ field: 'active', issue: 'invalid_value' }]);
    const active = parsed.data.active;
    const until = active ? new Date(this.clock.now().getTime() + (RECORDING_MAX_SECONDS + 1) * 1000) : null;
    await this.audit.record({
      action: active ? AuditAction.LIVE_RECORDING_START : AuditAction.LIVE_RECORDING_STOP,
      actorUserId: callerId,
      targetType: 'live_room',
      targetId: room.id,
      metadata: {},
      ip: meta.ip,
      requestId: meta.requestId,
    });
    try {
      await this.media.setParticipantAttributes(room.id, room.hostUserId, {
        [ATTR_RECORDING_UNTIL]: until ? until.toISOString() : '',
      });
    } catch (err) {
      this.logger.warn({ error: safeErrorLog(err) }, 'Could not tell the room about the recording');
      throw new AppException(ErrorCode.SERVICE_UNAVAILABLE);
    }
    return { active, until: until ? until.toISOString() : null, maxSeconds: RECORDING_MAX_SECONDS };
  }

  // ---- music rights ----------------------------------------------------------------------------

  /** `GET /me/live-music-rights`. */
  async musicRights(callerId: string): Promise<MusicRightsDto> {
    const row = await this.prisma.liveMusicRightsAcceptance.findUnique({ where: { userId: callerId } });
    return {
      accepted: row !== null && row.noticeVersion >= MUSIC_NOTICE_VERSION,
      acceptedAt: row ? row.acceptedAt.toISOString() : null,
      noticeVersion: MUSIC_NOTICE_VERSION,
    };
  }

  /** `PUT /me/live-music-rights`: the notice accepted (the first acceptance is kept and audited). */
  async acceptMusicRights(callerId: string, body: unknown, meta: RequestMeta): Promise<MusicRightsDto> {
    const parsed = musicRightsSchema.safeParse(body ?? {});
    if (!parsed.success) throw AppException.validation(zodErrorToDetails(parsed.error));
    await this.prisma.$transaction(async (tx) => {
      const inserted = await tx.liveMusicRightsAcceptance.createMany({
        data: [{ userId: callerId, noticeVersion: parsed.data.noticeVersion, acceptedAt: this.clock.now() }],
        skipDuplicates: true,
      });
      if (inserted.count === 1) {
        await this.audit.recordIn(tx, {
          action: AuditAction.LIVE_MUSIC_RIGHTS_ACCEPT,
          actorUserId: callerId,
          targetType: 'user',
          targetId: callerId,
          metadata: { noticeVersion: parsed.data.noticeVersion },
          ip: meta.ip,
          requestId: meta.requestId,
        });
      }
    }, LIVE_TX_OPTIONS);
    return this.musicRights(callerId);
  }
}
