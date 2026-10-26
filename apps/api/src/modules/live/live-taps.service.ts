import { Injectable } from '@nestjs/common';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { Clock } from '../../common/time/clock.js';
import { zodErrorToDetails } from '../../common/validation/zod-validation.pipe.js';
import type { Prisma } from '../../generated/prisma/client.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { isAvailable, loadCategory } from '../levels/level-catalog.js';
import { LevelProgressService } from '../levels/level-progress.service.js';
import { USER_SUMMARY_SELECT, userSummary } from '../posts/post-views.js';
import { LiveRoomMetadataService } from './live-metadata.service.js';
import {
  LiveRoomsService,
  LIVE_TX_OPTIONS,
  setLiveStatementTimeout,
  type LiveScoreDto,
  type UserSummaryDto,
} from './live-rooms.service.js';
import {
  acceptedTaps,
  charmPointsFor,
  LIVE_CONTRIBUTORS_MAX,
  POINTS_PER_TAP,
  TAPS_PER_CHARM_POINT,
} from './live-taps.js';
import { liveTapsRequestSchema } from './live.schemas.js';
import { UsersService } from '../users/users.service.js';

/** `LiveTapsResult` (CP-012). */
export interface LiveTapsResultDto {
  accepted: number;
  score: LiveScoreDto;
}

/** `LiveContributor` (CP-014). */
export interface LiveContributorDto {
  user: UserSummaryDto;
  points: number;
}

/** `LiveContributorStanding` (v1.20-live, D105): one person's points and place in a live. */
export interface LiveContributorStandingDto {
  user: UserSummaryDto;
  points: number;
  /** Place in the Contribution list as the reader sees it; null with 0 points. */
  rank: number | null;
}

/**
 * Live taps and the room score (CP-012, D95, CONVENTIONS §10.10).
 *
 * One transaction per batch: the room row is locked (`FOR NO KEY UPDATE`, so batches of one room
 * are serialized and a concurrent end wins or waits), the caller's `live_room_tappers` row is read
 * under `FOR UPDATE`, the counting rules ({@link acceptedTaps}) decide how many taps count, and
 * the caller's row, the room's `live_room_scores` row and `live_rooms.score` (the total the
 * `popular` tab orders by) are updated together. Concurrent batches therefore never pass the
 * 10-a-second or 10 000-a-live limits. After the commit the score goes into the media room's
 * metadata, at most once every 2 seconds per room ({@link LiveRoomMetadataService}).
 *
 * CP-016 D (D101, §10.18): in the same transaction the batch gives the host charm points
 * ({@link charmPointsFor}); a level change raises the room's info version so apps read it again.
 */
@Injectable()
export class LiveTapsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly rooms: LiveRoomsService,
    private readonly clock: Clock,
    private readonly metadata: LiveRoomMetadataService,
    private readonly levels: LevelProgressService,
    private readonly users: UsersService,
  ) {}

  /**
   * `POST /live/rooms/{roomId}/taps`: body (400) → visible room (404) → LIVE (409) → not kicked out
   * of this live (403 LIVE_KICKED, v1.20-live).
   */
  async tap(callerId: string, roomId: string, body: unknown): Promise<LiveTapsResultDto> {
    const parsed = liveTapsRequestSchema.safeParse(body ?? {}, { reportInput: true });
    if (!parsed.success) throw AppException.validation(zodErrorToDetails(parsed.error));
    const { count } = parsed.data;

    // Blocks, an inactive host and a stale room (ended here) are handled like every room read.
    const visible = await this.rooms.visibleRow(roomId, callerId);
    if (visible.status !== 'LIVE') throw new AppException(ErrorCode.LIVE_ROOM_ENDED);
    // v1.20-live (D105, §10.20): nobody kicked out of this live taps in it.
    if (visible.kicked) throw new AppException(ErrorCode.LIVE_KICKED);
    const id = visible.id;

    const now = this.clock.now();
    const at = now.toISOString();
    const result = await this.prisma.$transaction(async (tx) => {
      await setLiveStatementTimeout(tx);
      const [room] = await tx.$queryRaw<{ host_user_id: string; status: string }[]>`
        SELECT host_user_id::text AS host_user_id, status::text AS status
          FROM live_rooms WHERE id = ${id}::uuid
           FOR NO KEY UPDATE`;
      if (!room) throw new AppException(ErrorCode.NOT_FOUND);
      if (room.status !== 'LIVE') throw new AppException(ErrorCode.LIVE_ROOM_ENDED);

      const [tapper] = await tx.$queryRaw<{ counted: number; last_batch_at: Date | null }[]>`
        SELECT counted, last_batch_at FROM live_room_tappers
         WHERE room_id = ${id}::uuid AND user_id = ${callerId}::uuid
           FOR UPDATE`;
      // v1.23-live: a row without a counted batch belongs to someone who only sent gifts here
      // (their first batch is a first batch).
      const accepted = acceptedTaps({
        count,
        isHost: room.host_user_id === callerId,
        tapper: tapper?.last_batch_at ? { counted: tapper.counted, lastBatchAt: tapper.last_batch_at } : null,
        now,
      });

      let levelChanged = false;
      if (accepted > 0) {
        await tx.$executeRaw`
          INSERT INTO live_room_tappers (room_id, user_id, counted, last_batch_at, points, points_at)
          VALUES (${id}::uuid, ${callerId}::uuid, ${accepted}, ${at}::timestamptz,
                  ${accepted * POINTS_PER_TAP}, ${at}::timestamptz)
          ON CONFLICT (room_id, user_id) DO UPDATE
             SET counted = live_room_tappers.counted + EXCLUDED.counted,
                 last_batch_at = EXCLUDED.last_batch_at,
                 points = live_room_tappers.points + EXCLUDED.points,
                 points_at = EXCLUDED.points_at`;
        await tx.$executeRaw`
          INSERT INTO live_room_scores (room_id, tap_points, support_points, updated_at)
          VALUES (${id}::uuid, ${accepted}, 0, ${at}::timestamptz)
          ON CONFLICT (room_id) DO UPDATE
             SET tap_points = live_room_scores.tap_points + EXCLUDED.tap_points,
                 updated_at = EXCLUDED.updated_at`;
        await tx.$executeRaw`
          UPDATE live_rooms SET score = score + ${accepted} WHERE id = ${id}::uuid`;
        // CP-016 A: the host's points in this UTC hour (the popularity boards).
        await tx.$executeRaw`
          INSERT INTO live_host_points_hourly (host_user_id, hour_start, points)
          VALUES (${room.host_user_id}::uuid, date_trunc('hour', ${at}::timestamptz), ${accepted * POINTS_PER_TAP})
          ON CONFLICT (host_user_id, hour_start) DO UPDATE
             SET points = live_host_points_hourly.points + EXCLUDED.points`;
        levelChanged = await this.creditCharm(tx, {
          roomId: id,
          hostId: room.host_user_id,
          viewerId: callerId,
          countedBefore: tapper?.counted ?? 0,
          accepted,
        });
        if (levelChanged) {
          await tx.$executeRaw`
            UPDATE live_rooms SET info_version = info_version + 1, updated_at = now()
             WHERE id = ${id}::uuid`;
        }
      }

      const [score] = await tx.$queryRaw<{ total: bigint; tap_points: bigint; support_points: bigint }[]>`
        SELECT r.score AS total, COALESCE(sc.tap_points, 0)::bigint AS tap_points,
               COALESCE(sc.support_points, 0)::bigint AS support_points
          FROM live_rooms r LEFT JOIN live_room_scores sc ON sc.room_id = r.id
         WHERE r.id = ${id}::uuid`;
      return {
        levelChanged,
        accepted,
        score: {
          total: Number(score?.total ?? 0),
          tapPoints: Number(score?.tap_points ?? 0),
          supportPoints: Number(score?.support_points ?? 0),
        },
      };
    }, LIVE_TX_OPTIONS);

    if (result.levelChanged) await this.metadata.infoChanged(id);
    if (result.accepted > 0) await this.metadata.scoreChanged(id);
    return { accepted: result.accepted, score: result.score };
  }

  /**
   * CP-016 D (§10.18): the host's charm points for this batch ({@link charmPointsFor}; the 10 000
   * counted taps a live already bound them). Runs after the room row is locked; the levels engine
   * then locks the host's level state (the same order as every other credit: category, then
   * state). Nothing is credited while the charm category is unavailable. Returns whether the
   * host's level changed.
   */
  private async creditCharm(
    tx: Prisma.TransactionClient,
    batch: { roomId: string; hostId: string; viewerId: string; countedBefore: number; accepted: number },
  ): Promise<boolean> {
    const points = charmPointsFor(batch.countedBefore, batch.accepted);
    if (points === 0) return false;

    // A database without the category (never seeded) is the same as an unavailable one.
    const seeded = await tx.levelCategory.findUnique({
      where: { code: 'ATTRACTIVENESS' },
      select: { id: true },
    });
    if (!seeded) return false;
    const category = await loadCategory(tx, 'ATTRACTIVENESS', 'share');
    if (!isAvailable(category)) return false;
    // One ledger row per batch that earns: the source id is the viewer's point count in this live
    // after the batch, which only grows, so a row is never credited twice.
    const reached = Math.floor((batch.countedBefore + batch.accepted) / TAPS_PER_CHARM_POINT);
    const result = await this.levels.apply(tx, category, {
      userId: batch.hostId,
      entryType: 'EARN',
      sourceType: 'LIVE_TAPS',
      pointsDelta: BigInt(points),
      sourceTransactionId: `taps:${batch.roomId}:${batch.viewerId}:${String(reached)}`,
      sourceValue: BigInt(points * TAPS_PER_CHARM_POINT),
    });
    return result.kind === 'applied' && result.state.currentLevel !== result.state.previousLevel;
  }

  /**
   * `GET /live/rooms/{roomId}/contributors` (CP-014, §10.12): the top 50 people by points given to
   * this live, highest first. Points (`live_room_tappers.points`) are the person's counted taps (1
   * each) plus, v1.23-live (CP-020), 100 for every coin of gift value they sent here. Ties: who
   * reached their total first, i.e. the earlier `points_at` (set by every batch that counts and
   * every gift, which is when the current total was reached), then user id. The host (whose taps count
   * 0 anyway), people with 0 points, inactive accounts and, for a signed-in reader, people blocked
   * either way are left out. Anyone who may watch reads it (a guest needs `allowGuests`), also on an
   * ended room; a room the caller may not see → 404.
   */
  async contributors(callerId: string | null, roomId: string): Promise<{ data: LiveContributorDto[] }> {
    const row = await this.rooms.visibleRow(roomId, callerId);
    if (callerId === null && !row.allow_guests) throw new AppException(ErrorCode.LIVE_GUESTS_NOT_ALLOWED);
    const rows = await this.prisma.liveRoomTapper.findMany({
      where: contributorsWhere(row.id, row.host_user_id, callerId),
      orderBy: [{ points: 'desc' }, { pointsAt: 'asc' }, { userId: 'asc' }],
      take: LIVE_CONTRIBUTORS_MAX,
      include: { user: { select: USER_SUMMARY_SELECT } },
    });
    return {
      data: rows.map((r) => ({ user: userSummary(r.user), points: Number(r.points) })),
    };
  }

  /**
   * `GET /live/rooms/{roomId}/contributors/{username}` (v1.20-live, D105, §10.12): one person's
   * points in this live and their place in the Contribution list as {@link contributors} computes
   * it for this reader (the same rows, order and exclusions, without the top-50 cut), so ranks
   * 1 … 50 match the list. 0 points (nothing counted, or the host) → rank null. Same access as the
   * list; an unknown or inactive user, or one blocked either way with a signed-in reader → 404.
   */
  async contributor(
    callerId: string | null,
    roomId: string,
    username: string,
  ): Promise<LiveContributorStandingDto> {
    const row = await this.rooms.visibleRow(roomId, callerId);
    if (callerId === null && !row.allow_guests) throw new AppException(ErrorCode.LIVE_GUESTS_NOT_ALLOWED);
    const target = await this.users.findActivePublicUser(username);
    if (!target) throw new AppException(ErrorCode.NOT_FOUND);
    if (callerId !== null && callerId !== target.id) {
      const blocks = await this.prisma.userBlock.count({
        where: {
          OR: [
            { blockerId: callerId, blockedId: target.id },
            { blockerId: target.id, blockedId: callerId },
          ],
        },
      });
      if (blocks > 0) throw new AppException(ErrorCode.NOT_FOUND);
    }
    const user: UserSummaryDto = {
      id: target.id,
      username: target.username,
      displayName: target.displayName,
      avatarUrl: target.avatarUrl,
    };
    const where = contributorsWhere(row.id, row.host_user_id, callerId);
    const mine = await this.prisma.liveRoomTapper.findFirst({
      where: { AND: [where, { userId: target.id }] },
      select: { points: true, pointsAt: true },
    });
    if (!mine) return { user, points: 0, rank: null };
    const ahead = await this.prisma.liveRoomTapper.count({
      where: {
        AND: [
          where,
          {
            OR: [
              { points: { gt: mine.points } },
              { points: mine.points, pointsAt: { lt: mine.pointsAt } },
              { points: mine.points, pointsAt: mine.pointsAt, userId: { lt: target.id } },
            ],
          },
        ],
      },
    });
    return { user, points: Number(mine.points), rank: ahead + 1 };
  }
}

/**
 * The rows of the Contribution list (CP-014, §10.12) for a reader: points (taps and, v1.23-live,
 * gifts), not the host,
 * ACTIVE accounts and, for a signed-in reader, no block either way.
 */
function contributorsWhere(
  roomId: string,
  hostUserId: string,
  callerId: string | null,
): Prisma.LiveRoomTapperWhereInput {
  return {
    roomId,
    points: { gt: 0 },
    userId: { not: hostUserId },
    user: {
      status: 'ACTIVE',
      ...(callerId === null
        ? {}
        : {
            blocking: { none: { blockedId: callerId } },
            blockedBy: { none: { blockerId: callerId } },
          }),
    },
  };
}
