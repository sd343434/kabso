import { Inject, Injectable, Logger } from '@nestjs/common';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { RateLimitService } from '../../common/rate-limit/rate-limit.service.js';
import { Clock } from '../../common/time/clock.js';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import { zodErrorToDetails } from '../../common/validation/zod-validation.pipe.js';
import { safeErrorLog } from '../../logging/redact-text.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { QUIP_TOPIC, quipSlot } from '../gifts/quips.js';
import { uuidv7 } from '../levels/uuidv7.js';
import { USER_SUMMARY_SELECT, userSummary } from '../posts/post-views.js';
import {
  LiveRoomsService,
  LIVE_TX_OPTIONS,
  setLiveStatementTimeout,
  type UserSummaryDto,
} from './live-rooms.service.js';
import { liveSoundSchema } from './live.schemas.js';
import { LIVE_MEDIA_PROVIDER, type LiveMediaProvider } from './media/live-media.provider.js';

/** v1.32-live (D154): the soundboard of the host and moderators plays one sound every 2 s per user. */
export const LIVE_SOUND_INTERVAL_MS = 2_000;

/** `LiveQuipKind`: a quip sent from the gift panel, or a sound of the host's/moderators' soundboard. */
export type LiveQuipKind = 'GIFT' | 'SOUNDBOARD';

/** `LiveQuip` (v1.32-live, D154, CONVENTIONS §10.33): one sound for the whole room, in queue order. */
export interface LiveQuipDto {
  /** The gift send's id (GIFT) or a new id (SOUNDBOARD). */
  id: string;
  roomId: string;
  kind: LiveQuipKind;
  /** The QUIPS gift played (the app takes its name and art from its catalogue). */
  giftCode: string;
  /** The app's bundled sound. */
  soundKey: string;
  durationMs: number;
  /** The line of text shown as a chat bubble while it plays, or null (a sound without words). */
  text: string | null;
  /** True for a free quip and every soundboard sound. */
  free: boolean;
  sender: UserSummaryDto;
  /** When it starts (server time) and how long after `createdAt` that is (the room's queue). */
  startsAt: string;
  delayMs: number;
  createdAt: string;
}

/** The data message of topic `quip`. */
export interface LiveQuipData {
  readonly type: 'quip';
  readonly quip: LiveQuipDto;
}

/**
 * «إفيهات» quips (D154, CONVENTIONS §10.33): every quip — a QUIPS gift sent from the panel (sent by
 * `LiveGiftsService`) or a free sound of the host's and moderators' soundboard (here) — takes the next
 * slot of its room's one queue (`live_rooms.quip_busy_until`, written under the room row's lock) and
 * goes to the room as a reliable `quip` data message with its `delayMs`; every app plays it after that
 * delay, one at a time. Apps hold no data publish permission (CP-010), so only the server queues.
 */
@Injectable()
export class LiveQuipsService {
  private readonly logger = new Logger(LiveQuipsService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly rooms: LiveRoomsService,
    private readonly limiter: RateLimitService,
    private readonly clock: Clock,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
    @Inject(LIVE_MEDIA_PROVIDER) private readonly media: LiveMediaProvider,
  ) {}

  /** The longest a quip may wait for its turn (QUIP_QUEUE_MAX_WAIT_SECONDS), ms. */
  get maxWaitMs(): number {
    return this.config.gifts.quipMaxWaitMs;
  }

  /**
   * `POST /live/rooms/{roomId}/sounds`. Checks after the auth guard and the route's bucket: visible
   * room (404), LIVE (409 LIVE_ROOM_ENDED), the body (400 `soundCode`), the host or a moderator of
   * this live (403 AUTH_FORBIDDEN), a free QUIPS gift that is enabled (409 GIFT_UNAVAILABLE), one
   * sound every 2 s per user (429 with `Retry-After`), a free slot within the queue's limit (409
   * QUIP_QUEUE_FULL). Nothing is stored but the queue's tail; the data message is best effort.
   */
  async playSound(callerId: string, roomId: string, body: unknown): Promise<LiveQuipDto> {
    const row = await this.rooms.visibleRow(roomId, callerId);
    if (row.status !== 'LIVE') throw new AppException(ErrorCode.LIVE_ROOM_ENDED);
    const parsed = liveSoundSchema.safeParse(body ?? {}, { reportInput: true });
    if (!parsed.success) throw AppException.validation(zodErrorToDetails(parsed.error));
    if (
      callerId !== row.host_user_id &&
      (await this.prisma.liveRoomModerator.count({ where: { roomId: row.id, userId: callerId } })) === 0
    ) {
      throw new AppException(ErrorCode.AUTH_FORBIDDEN);
    }
    const gift = await this.prisma.gift.findUnique({ where: { code: parsed.data.soundCode } });
    if (
      !gift?.enabled ||
      gift.category !== 'QUIPS' ||
      gift.priceCoins !== 0 ||
      gift.soundKey === null ||
      gift.soundMs === null
    ) {
      throw new AppException(ErrorCode.GIFT_UNAVAILABLE);
    }
    const waitMs = await this.limiter.interval(
      'live:sound:interval',
      callerId,
      this.clock.now().getTime(),
      LIVE_SOUND_INTERVAL_MS,
    );
    if (waitMs > 0) {
      throw new AppException(ErrorCode.RATE_LIMITED, undefined, undefined, {
        'Retry-After': String(Math.max(1, Math.ceil(waitMs / 1000))),
      });
    }
    const durationMs = gift.soundMs;
    const slot = await this.prisma.$transaction(async (tx) => {
      await setLiveStatementTimeout(tx);
      const [room] = await tx.$queryRaw<{ status: string; quip_busy_until: Date | null }[]>`
        SELECT status::text AS status, quip_busy_until FROM live_rooms
         WHERE id = ${row.id}::uuid FOR NO KEY UPDATE`;
      if (!room) throw new AppException(ErrorCode.NOT_FOUND);
      if (room.status !== 'LIVE') throw new AppException(ErrorCode.LIVE_ROOM_ENDED);
      const now = this.clock.now();
      const next = quipSlot(now, room.quip_busy_until, durationMs, this.maxWaitMs);
      if (!next) throw new AppException(ErrorCode.QUIP_QUEUE_FULL);
      await tx.$executeRaw`
        UPDATE live_rooms SET quip_busy_until = ${next.busyUntil.toISOString()}::timestamptz
         WHERE id = ${row.id}::uuid`;
      return { ...next, now };
    }, LIVE_TX_OPTIONS);
    const sender = await this.prisma.user.findUniqueOrThrow({
      where: { id: callerId },
      select: USER_SUMMARY_SELECT,
    });
    const dto: LiveQuipDto = {
      id: uuidv7(),
      roomId: row.id,
      kind: 'SOUNDBOARD',
      giftCode: gift.code,
      soundKey: gift.soundKey,
      durationMs,
      text: gift.quipText,
      free: true,
      sender: userSummary(sender),
      startsAt: slot.startsAt.toISOString(),
      delayMs: slot.delayMs,
      createdAt: slot.now.toISOString(),
    };
    await this.broadcast(dto);
    return dto;
  }

  /** The `quip` data message to the room (best effort, like every data message). */
  async broadcast(quip: LiveQuipDto): Promise<void> {
    const data: LiveQuipData = { type: 'quip', quip };
    try {
      await this.media.broadcastData(quip.roomId, QUIP_TOPIC, JSON.stringify(data));
    } catch (err) {
      this.logger.warn({ error: safeErrorLog(err) }, 'Could not send a quip data message to the media room');
    }
  }
}
