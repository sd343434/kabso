import { Inject, Injectable, Logger } from '@nestjs/common';
import { AuditAction, AuditService } from '../../common/audit/audit.service.js';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { Clock } from '../../common/time/clock.js';
import { zodErrorToDetails } from '../../common/validation/zod-validation.pipe.js';
import { Prisma } from '../../generated/prisma/client.js';
import { safeErrorLog } from '../../logging/redact-text.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { USER_SUMMARY_SELECT, userSummary } from '../posts/post-views.js';
import { UsersService } from '../users/users.service.js';
import {
  LiveRoomsService,
  LIVE_TX_OPTIONS,
  type RequestMeta,
  type RoomRow,
  type UserSummaryDto,
} from './live-rooms.service.js';
import { closeVisits, recountViewers } from './live-audience.js';
import { LiveSeatsService } from './live-seats.service.js';
import { releaseUserIn, type ReleasedUser } from './live-seats.store.js';
import { liveKickBodySchema } from './live.schemas.js';
import { LIVE_MEDIA_PROVIDER, type LiveMediaProvider } from './media/live-media.provider.js';

// ---- Response shapes (openapi v1.20-live, D105) ------------------------------------------------

/** `LiveKick`. */
export interface LiveKickDto {
  user: UserSummaryDto;
  kickedAt: string;
}

/** The media data topic of kick data messages (CONVENTIONS §10.20). */
export const LIVE_KICK_TOPIC = 'kick';

/** The data message of topic `kick`. */
export interface LiveKickData {
  readonly type: 'kick';
  readonly user: UserSummaryDto;
  readonly by: UserSummaryDto;
  readonly at: string;
}

function forbidden(): AppException {
  return new AppException(ErrorCode.AUTH_FORBIDDEN);
}

function notFound(): AppException {
  return new AppException(ErrorCode.NOT_FOUND);
}

/**
 * Kicking someone out of a live (owner D105, CONVENTIONS §10.20). The host and the room's
 * moderators kick a signed-in person out of one live: a `live_room_kicks` row, and in the same
 * transaction the person loses their seat, pending request, invitation and moderator role
 * ({@link releaseUserIn}) and their media-session row. After the commit, best effort: the seat
 * changes reach the media server, the room gets a `kick` data message, and the person is removed
 * from the media session. The kick itself is enforced by the media token, the join webhook, chat,
 * bullets, taps and seat requests (`LIVE_KICKED`, mostly through {@link RoomRow.kicked}); it belongs to this room, so it ends with the live.
 */
@Injectable()
export class LiveKicksService {
  private readonly logger = new Logger(LiveKicksService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly rooms: LiveRoomsService,
    private readonly users: UsersService,
    private readonly audit: AuditService,
    private readonly clock: Clock,
    private readonly seats: LiveSeatsService,
    @Inject(LIVE_MEDIA_PROVIDER) private readonly media: LiveMediaProvider,
  ) {}

  private async isModerator(
    db: Prisma.TransactionClient | PrismaService,
    roomId: string,
    userId: string,
  ): Promise<boolean> {
    return (await db.liveRoomModerator.count({ where: { roomId, userId } })) > 0;
  }

  /** The caller's privilege in the room: HOST, MODERATOR or none (→ 403). */
  private async privilege(
    db: Prisma.TransactionClient | PrismaService,
    row: { id: string; host_user_id: string },
    callerId: string,
  ): Promise<'HOST' | 'MODERATOR'> {
    if (callerId === row.host_user_id) return 'HOST';
    if (await this.isModerator(db, row.id, callerId)) return 'MODERATOR';
    throw forbidden();
  }

  private async summaryOf(userId: string): Promise<UserSummaryDto> {
    const user = await this.prisma.user.findUniqueOrThrow({
      where: { id: userId },
      select: USER_SUMMARY_SELECT,
    });
    return userSummary(user);
  }

  /**
   * `POST /live/rooms/{roomId}/kicks`. After the auth guard: visible room (404) → LIVE (409
   * LIVE_ROOM_ENDED) → body (400) → host or moderator (403) → an ACTIVE user (404) → not the
   * caller, not the host, and for a moderator not another moderator (403). Already kicked →
   * `created` false with the first kick (nothing sent or audited again; the media removal is
   * repeated, which is harmless).
   */
  async kick(
    callerId: string,
    roomId: string,
    body: unknown,
    meta: RequestMeta,
  ): Promise<{ created: boolean; kick: LiveKickDto }> {
    const row = await this.rooms.visibleRow(roomId, callerId);
    if (row.status !== 'LIVE') throw new AppException(ErrorCode.LIVE_ROOM_ENDED);
    const parsed = liveKickBodySchema.safeParse(body ?? {}, { reportInput: true });
    if (!parsed.success) throw AppException.validation(zodErrorToDetails(parsed.error));
    await this.privilege(this.prisma, row, callerId);
    const target = await this.users.findActivePublicUser(parsed.data.username);
    if (!target) throw notFound();
    if (target.id === callerId || target.id === row.host_user_id) throw forbidden();

    const now = this.clock.now();
    const outcome = await this.prisma.$transaction(async (tx) => {
      // The room row is locked first (as every seat change does), so a concurrent end, seat change
      // or moderator change is serialized with the kick; the privilege is checked again under it.
      const [room] = await tx.$queryRaw<{ status: string }[]>`
        SELECT status::text AS status FROM live_rooms WHERE id = ${row.id}::uuid FOR UPDATE`;
      if (!room) throw notFound();
      if (room.status !== 'LIVE') throw new AppException(ErrorCode.LIVE_ROOM_ENDED);
      const privilege = await this.privilege(tx, row, callerId);
      if (privilege === 'MODERATOR' && (await this.isModerator(tx, row.id, target.id))) throw forbidden();

      const inserted = await tx.liveRoomKick.createMany({
        data: [{ roomId: row.id, userId: target.id, kickedById: callerId, createdAt: now }],
        skipDuplicates: true,
      });
      if (inserted.count === 0) {
        const first = await tx.liveRoomKick.findUniqueOrThrow({
          where: { roomId_userId: { roomId: row.id, userId: target.id } },
          select: { createdAt: true },
        });
        return { created: false, kickedAt: first.createdAt, released: [] as ReleasedUser[] };
      }
      const released = await releaseUserIn(tx, target.id, now, {
        roomScope: Prisma.sql`r.id = ${row.id}::uuid`,
        moderator: true,
      });
      // v1.27.6-live (D140): the kicked person's visit ends now (the live's statistics).
      await closeVisits(tx, row.id, [target.id], now);
      const left = await tx.liveRoomViewer.deleteMany({ where: { roomId: row.id, identity: target.id } });
      if (left.count > 0) await recountViewers(tx, row.id);
      await this.audit.recordIn(tx, {
        action: AuditAction.LIVE_KICK,
        actorUserId: callerId,
        targetType: 'user',
        targetId: target.id,
        metadata: { roomId: row.id, wasSeated: released.some((r) => r.wasSeated) },
        ip: meta.ip,
        requestId: meta.requestId,
      });
      return { created: true, kickedAt: now, released };
    }, LIVE_TX_OPTIONS);

    const user = await this.summaryOf(target.id);
    if (outcome.created) {
      await this.seats.afterRelease(target.id, outcome.released);
      const data: LiveKickData = {
        type: 'kick',
        user,
        by: await this.summaryOf(callerId),
        at: outcome.kickedAt.toISOString(),
      };
      // Sent before the removal, so the kicked app can still receive it (§10.20).
      try {
        await this.media.broadcastData(row.id, LIVE_KICK_TOPIC, JSON.stringify(data));
      } catch (err) {
        this.logger.warn(
          { error: safeErrorLog(err) },
          'Could not send a kick data message to the media room',
        );
      }
    }
    await this.removeFromMedia(row.id, target.id);
    return { created: outcome.created, kick: { user, kickedAt: outcome.kickedAt.toISOString() } };
  }

  /** Disconnects the kicked identity (best effort; the join webhook refuses it again anyway). */
  private async removeFromMedia(roomId: string, identity: string): Promise<void> {
    try {
      await this.media.removeParticipant(roomId, identity);
    } catch (err) {
      this.logger.warn(
        { error: safeErrorLog(err) },
        'Could not remove a kicked participant from the media session',
      );
    }
  }

  /**
   * `DELETE /live/rooms/{roomId}/kicks/{username}` (host or moderator; idempotent): visible room
   * (404) → LIVE (409) → privilege (403) → the user (404). Audited when a kick was removed.
   */
  async unkick(callerId: string, roomId: string, username: string, meta: RequestMeta): Promise<void> {
    const row = await this.rooms.visibleRow(roomId, callerId);
    if (row.status !== 'LIVE') throw new AppException(ErrorCode.LIVE_ROOM_ENDED);
    await this.privilege(this.prisma, row, callerId);
    const target = await this.users.findActivePublicUser(username);
    if (!target) throw notFound();
    await this.prisma.$transaction(async (tx) => {
      const removed = await tx.liveRoomKick.deleteMany({ where: { roomId: row.id, userId: target.id } });
      if (removed.count === 0) return;
      await this.audit.recordIn(tx, {
        action: AuditAction.LIVE_KICK_UNDO,
        actorUserId: callerId,
        targetType: 'user',
        targetId: target.id,
        metadata: { roomId: row.id },
        ip: meta.ip,
        requestId: meta.requestId,
      });
    }, LIVE_TX_OPTIONS);
  }

  /** `GET /live/rooms/{roomId}/kicks` (host or moderator): newest first, ACTIVE users only. */
  async list(callerId: string, roomId: string): Promise<{ data: LiveKickDto[] }> {
    const row: RoomRow = await this.rooms.visibleRow(roomId, callerId);
    await this.privilege(this.prisma, row, callerId);
    const rows = await this.prisma.liveRoomKick.findMany({
      where: { roomId: row.id, user: { status: 'ACTIVE' } },
      orderBy: [{ createdAt: 'desc' }, { userId: 'desc' }],
      include: { user: { select: USER_SUMMARY_SELECT } },
    });
    return { data: rows.map((r) => ({ user: userSummary(r.user), kickedAt: r.createdAt.toISOString() })) };
  }
}
