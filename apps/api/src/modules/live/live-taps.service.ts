import { Injectable } from '@nestjs/common';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { Clock } from '../../common/time/clock.js';
import { zodErrorToDetails } from '../../common/validation/zod-validation.pipe.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { LiveRoomMetadataService } from './live-metadata.service.js';
import {
  LiveRoomsService,
  LIVE_TX_OPTIONS,
  setLiveStatementTimeout,
  type LiveScoreDto,
} from './live-rooms.service.js';
import { acceptedTaps } from './live-taps.js';
import { liveTapsRequestSchema } from './live.schemas.js';

/** `LiveTapsResult` (CP-012). */
export interface LiveTapsResultDto {
  accepted: number;
  score: LiveScoreDto;
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
 */
@Injectable()
export class LiveTapsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly rooms: LiveRoomsService,
    private readonly clock: Clock,
    private readonly metadata: LiveRoomMetadataService,
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
      }

      const [score] = await tx.$queryRaw<{ total: bigint; tap_points: bigint; support_points: bigint }[]>`
        SELECT r.score AS total, COALESCE(sc.tap_points, 0)::bigint AS tap_points,
               COALESCE(sc.support_points, 0)::bigint AS support_points
          FROM live_rooms r LEFT JOIN live_room_scores sc ON sc.room_id = r.id
         WHERE r.id = ${id}::uuid`;
      return {
        accepted,
        score: {
          total: Number(score?.total ?? 0),
          tapPoints: Number(score?.tap_points ?? 0),
          supportPoints: Number(score?.support_points ?? 0),
        },
      };
    }, LIVE_TX_OPTIONS);

    if (result.accepted > 0) await this.metadata.scoreChanged(id);
    return result;
  }
}
