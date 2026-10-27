import { Inject, Injectable, Logger } from '@nestjs/common';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { RateLimitService } from '../../common/rate-limit/rate-limit.service.js';
import { Clock } from '../../common/time/clock.js';
import { zodErrorToDetails } from '../../common/validation/zod-validation.pipe.js';
import { safeErrorLog } from '../../logging/redact-text.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { uuidv7 } from '../levels/uuidv7.js';
import { USER_SUMMARY_SELECT, userSummary } from '../posts/post-views.js';
import { LiveRoomsService, type UserSummaryDto } from './live-rooms.service.js';
import { SEAT_EMOJI_INTERVAL_MS, SEAT_EMOJI_MODES, SEAT_EMOJI_TOPIC } from './live-seat-emoji.js';
import { liveSeatEmojiSchema } from './live.schemas.js';
import { LIVE_MEDIA_PROVIDER, type LiveMediaProvider } from './media/live-media.provider.js';

/** `LiveSeatEmoji` (v1.27.5-live, D138). */
export interface LiveSeatEmojiDto {
  id: string;
  /** The tile it plays on: 0 for the host, else the seat index. */
  seat: number;
  user: UserSummaryDto;
  token: string;
  createdAt: string;
}

/** The data message of topic `seat-emoji`. */
export interface LiveSeatEmojiData extends LiveSeatEmojiDto {
  readonly type: 'seat-emoji';
}

/**
 * An emoji on one's own seat (D138, CONVENTIONS §10.30): in a room with seats (AUDIO, MULTI) the
 * host (tile 0) or someone seated plays one of the owner's animated emojis once inside their own
 * tile, for everyone in the room. Nothing is stored: the server checks the caller and the token,
 * applies one emoji every 2 s per user, and sends a reliable `seat-emoji` data message on topic
 * `seat-emoji` (apps hold no data publish permission, CP-010 `canPublishData: false`, so a client
 * cannot put a message in the room that the server has not checked).
 */
@Injectable()
export class LiveSeatEmojiService {
  private readonly logger = new Logger(LiveSeatEmojiService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly rooms: LiveRoomsService,
    private readonly limiter: RateLimitService,
    private readonly clock: Clock,
    @Inject(LIVE_MEDIA_PROVIDER) private readonly media: LiveMediaProvider,
  ) {}

  /**
   * `POST /live/rooms/{roomId}/seat-emoji`. Checks after the auth guard: visible room (404), LIVE
   * (409 LIVE_ROOM_ENDED), the body (400 `token`), kicked out of this live (403 LIVE_KICKED), a
   * room with seats and the caller the host or seated now (409 LIVE_SEAT_UNAVAILABLE), one every
   * 2 s per user (429 with `Retry-After`). Then the data message (best effort).
   */
  async send(callerId: string, roomId: string, body: unknown): Promise<LiveSeatEmojiDto> {
    const row = await this.rooms.visibleRow(roomId, callerId);
    if (row.status !== 'LIVE') throw new AppException(ErrorCode.LIVE_ROOM_ENDED);
    const parsed = liveSeatEmojiSchema.safeParse(body ?? {}, { reportInput: true });
    if (!parsed.success) throw AppException.validation(zodErrorToDetails(parsed.error));
    if (row.kicked) throw new AppException(ErrorCode.LIVE_KICKED);
    if (!SEAT_EMOJI_MODES.has(row.mode)) throw new AppException(ErrorCode.LIVE_SEAT_UNAVAILABLE);

    let seat = 0;
    if (callerId !== row.host_user_id) {
      const taken = await this.prisma.liveRoomSeat.findFirst({
        where: { roomId: row.id, userId: callerId },
        select: { seatIndex: true },
      });
      if (!taken) throw new AppException(ErrorCode.LIVE_SEAT_UNAVAILABLE);
      seat = taken.seatIndex;
    }

    const now = this.clock.now();
    const waitMs = await this.limiter.interval(
      'live:seat-emoji:interval',
      callerId,
      now.getTime(),
      SEAT_EMOJI_INTERVAL_MS,
    );
    if (waitMs > 0) {
      throw new AppException(ErrorCode.RATE_LIMITED, undefined, undefined, {
        'Retry-After': String(Math.max(1, Math.ceil(waitMs / 1000))),
      });
    }

    const user = await this.prisma.user.findUniqueOrThrow({
      where: { id: callerId },
      select: USER_SUMMARY_SELECT,
    });
    const dto: LiveSeatEmojiDto = {
      id: uuidv7(),
      seat,
      user: userSummary(user),
      token: parsed.data.token,
      createdAt: now.toISOString(),
    };
    const data: LiveSeatEmojiData = { type: 'seat-emoji', ...dto };
    try {
      await this.media.broadcastData(row.id, SEAT_EMOJI_TOPIC, JSON.stringify(data));
    } catch (err) {
      this.logger.warn(
        { error: safeErrorLog(err) },
        'Could not send a seat emoji data message to the media room',
      );
    }
    return dto;
  }
}
