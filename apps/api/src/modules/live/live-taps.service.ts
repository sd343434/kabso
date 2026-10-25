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
  ) {}

  /** `POST /live/rooms/{roomId}/taps`: body (400) → visible room (404) → LIVE (409). */
  async tap(callerId: string, roomId: string, body: unknown): Promise<LiveTapsResultDto> {
    const parsed = liveTapsRequestSchema.safeParse(body ?? {}, { reportInput: true });
    if (!parsed.success) throw AppException.validation(zodErrorToDetails(parsed.error));
    const { count } = parsed.data;

    // Blocks, an inactive host and a stale room (ended here) are handled like every room read.
    const visible = await this.rooms.visibleRow(roomId, callerId);
    if (visible.status !== 'LIVE') throw new AppException(ErrorCode.LIVE_ROOM_ENDED);
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

      const [tapper] = await tx.$queryRaw<{ counted: number; last_batch_at: Date }[]>`
        SELECT counted, last_batch_at FROM live_room_tappers
         WHERE room_id = ${id}::uuid AND user_id = ${callerId}::uuid
           FOR UPDATE`;
      const accepted = acceptedTaps({
        count,
        isHost: room.host_user_id === callerId,
        tapper: tapper ? { counted: tapper.counted, lastBatchAt: tapper.last_batch_at } : null,
        now,
      });

      let levelChanged = false;
      if (accepted > 0) {
        await tx.$executeRaw`
          INSERT INTO live_room_tappers (room_id, user_id, counted, last_batch_at)
          VALUES (${id}::uuid, ${callerId}::uuid, ${accepted}, ${at}::timestamptz)
          ON CONFLICT (room_id, user_id) DO UPDATE
             SET counted = live_room_tappers.counted + EXCLUDED.counted,
                 last_batch_at = EXCLUDED.last_batch_at`;
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
   * this live, highest first. Points are the caller's counted taps (`live_room_tappers.counted`,
   * 1 each); support (L3) is not written yet. Ties: who reached their total first, i.e. the earlier
   * `last_batch_at` (the time of the last batch that counted, which is when the current total was
   * reached: a batch that counts nothing never moves it), then user id. The host (whose taps count
   * 0 anyway), people with 0 points, inactive accounts and, for a signed-in reader, people blocked
   * either way are left out. Anyone who may watch reads it (a guest needs `allowGuests`), also on an
   * ended room; a room the caller may not see → 404.
   */
  async contributors(callerId: string | null, roomId: string): Promise<{ data: LiveContributorDto[] }> {
    const row = await this.rooms.visibleRow(roomId, callerId);
    if (callerId === null && !row.allow_guests) throw new AppException(ErrorCode.LIVE_GUESTS_NOT_ALLOWED);
    const rows = await this.prisma.liveRoomTapper.findMany({
      where: {
        roomId: row.id,
        counted: { gt: 0 },
        userId: { not: row.host_user_id },
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
      orderBy: [{ counted: 'desc' }, { lastBatchAt: 'asc' }, { userId: 'asc' }],
      take: LIVE_CONTRIBUTORS_MAX,
      include: { user: { select: USER_SUMMARY_SELECT } },
    });
    return {
      data: rows.map((r) => ({ user: userSummary(r.user), points: r.counted * POINTS_PER_TAP })),
    };
  }
}
