import { Inject, Injectable, Logger } from '@nestjs/common';
import { BackgroundTasks } from '../../common/background/background-tasks.js';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { RateLimitService } from '../../common/rate-limit/rate-limit.service.js';
import { Clock } from '../../common/time/clock.js';
import { zodErrorToDetails } from '../../common/validation/zod-validation.pipe.js';
import type { Prisma } from '../../generated/prisma/client.js';
import { safeErrorLog } from '../../logging/redact-text.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { USER_SUMMARY_SELECT, userSummary } from '../posts/post-views.js';
import { violatedUniqueIndex } from '../users/users.service.js';
import { WalletService } from '../wallet/wallet.service.js';
import { maskBlockedWords } from './live-blocked-words.js';
import { LiveBlockedWordsService } from './live-blocked-words.service.js';
import { LiveRoomsService, type UserSummaryDto } from './live-rooms.service.js';
import { liveBulletSendSchema } from './live.schemas.js';
import { LIVE_MEDIA_PROVIDER, type LiveMediaProvider } from './media/live-media.provider.js';

// ---- Response shapes (openapi v1.19-live, CP-017) ----------------------------------------------

/** `LiveBullet`. */
export interface LiveBulletDto {
  id: string;
  text: string;
  sender: UserSummaryDto;
  /** The live it was sent from. */
  roomId: string;
  createdAt: string;
}

/** `LiveBulletResult`: the bullet and the sender's balance after it. */
export interface LiveBulletResultDto {
  bullet: LiveBulletDto;
  coins: number;
}

/** What a bullet message costs (owner D104). */
export const LIVE_BULLET_COST_COINS = 15;
/** Counting rule: at most one bullet every 5 seconds per user (CONVENTIONS §7, §10.19). */
export const LIVE_BULLET_SEND_INTERVAL_MS = 5_000;
/** The media data topic of bullet data messages (CONVENTIONS §10.19). */
export const LIVE_BULLET_TOPIC = 'bullet';
/** Rooms a fan-out sends to at the same time. */
const FAN_OUT_CONCURRENCY = 16;

/** The data message of topic `bullet`. */
export interface LiveBulletData {
  readonly type: 'bullet';
  readonly bullet: LiveBulletDto;
}

const BULLET_INCLUDE = { user: { select: USER_SUMMARY_SELECT } } as const;
type BulletRow = Prisma.LiveBulletGetPayload<{ include: typeof BULLET_INCLUDE }>;

function toDto(row: BulletRow, originRoomId: string): LiveBulletDto {
  return {
    id: row.id,
    text: row.text,
    sender: userSummary(row.user),
    roomId: row.roomId ?? originRoomId,
    createdAt: row.createdAt.toISOString(),
  };
}

/**
 * Bullet messages (رسالة عامة, CP-017, D104, CONVENTIONS §10.19): a signed-in viewer of a live
 * pays {@link LIVE_BULLET_COST_COINS} coins and the line is shown in every live (audio and video)
 * as a `bullet` data message on topic `bullet`. The charge and the bullet are one transaction
 * (nothing is charged when the balance is short, and a retry with the same `clientId` is never
 * charged again). The fan-out runs after the response, best effort per room like every data
 * message.
 */
@Injectable()
export class LiveBulletsService {
  private readonly logger = new Logger(LiveBulletsService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly rooms: LiveRoomsService,
    private readonly wallet: WalletService,
    private readonly limiter: RateLimitService,
    private readonly clock: Clock,
    @Inject(LIVE_MEDIA_PROVIDER) private readonly media: LiveMediaProvider,
    private readonly blockedWords: LiveBlockedWordsService,
    private readonly background: BackgroundTasks,
  ) {}

  /** In the room now: a row in the room's media session (CP-010 `live_room_viewers`). */
  private async inMediaSession(roomId: string, userId: string): Promise<boolean> {
    return (await this.prisma.liveRoomViewer.count({ where: { roomId, userId } })) > 0;
  }

  /**
   * `POST /live/rooms/{roomId}/bullets`. Checks after the auth guard (§10.19): visible room (404),
   * LIVE (409 LIVE_ROOM_ENDED), the body (400), a retry with the same `clientId` by the same sender
   * → the first bullet and the current balance (`created` false; nothing charged or sent again),
   * the caller in the room (403 LIVE_CHAT_NOT_IN_ROOM), not muted in this live's chat (403
   * LIVE_CHAT_MUTED), one bullet every 5 s (429 with `Retry-After`), then the charge (409
   * INSUFFICIENT_COINS, nothing stored or charged).
   */
  async send(
    callerId: string,
    roomId: string,
    body: unknown,
  ): Promise<{ created: boolean; result: LiveBulletResultDto }> {
    const row = await this.rooms.visibleRow(roomId, callerId);
    if (row.status !== 'LIVE') throw new AppException(ErrorCode.LIVE_ROOM_ENDED);
    const parsed = liveBulletSendSchema.safeParse(body ?? {}, { reportInput: true });
    if (!parsed.success) throw AppException.validation(zodErrorToDetails(parsed.error));
    const clientId = parsed.data.clientId.toLowerCase();

    const first = await this.byClientId(callerId, clientId);
    if (first) return { created: false, result: await this.replay(callerId, first, row.id) };

    if (callerId !== row.host_user_id) {
      if (!(await this.inMediaSession(row.id, callerId))) {
        throw new AppException(ErrorCode.LIVE_CHAT_NOT_IN_ROOM);
      }
      if (row.chat_muted) throw new AppException(ErrorCode.LIVE_CHAT_MUTED);
    }
    const now = this.clock.now();
    const waitMs = await this.limiter.interval(
      'live:bullet:interval',
      callerId,
      now.getTime(),
      LIVE_BULLET_SEND_INTERVAL_MS,
    );
    if (waitMs > 0) {
      const stored = await this.byClientId(callerId, clientId);
      if (stored) return { created: false, result: await this.replay(callerId, stored, row.id) };
      throw new AppException(ErrorCode.RATE_LIMITED, undefined, undefined, {
        'Retry-After': String(Math.max(1, Math.ceil(waitMs / 1000))),
      });
    }

    // CP-016 B: the origin host's blocked words are masked before the bullet is stored or sent.
    const text = maskBlockedWords(parsed.data.text, await this.blockedWords.wordsOf(row.host_user_id));
    let created: { bullet: BulletRow; coins: bigint };
    try {
      created = await this.prisma.$transaction(async (tx) => {
        const bullet = await tx.liveBullet.create({
          data: {
            userId: callerId,
            clientId,
            roomId: row.id,
            text,
            cost: LIVE_BULLET_COST_COINS,
            createdAt: now,
          },
          include: BULLET_INCLUDE,
        });
        const charged = await this.wallet.debitIn(
          tx,
          callerId,
          LIVE_BULLET_COST_COINS,
          'BULLET_MESSAGE',
          bullet.id,
        );
        if (!charged) throw new AppException(ErrorCode.INSUFFICIENT_COINS);
        return { bullet, coins: charged.coins };
      });
    } catch (err) {
      // A concurrent request with the same clientId won: answer with its bullet.
      if (violatedUniqueIndex(err) !== null) {
        const raced = await this.byClientId(callerId, clientId);
        if (raced) return { created: false, result: await this.replay(callerId, raced, row.id) };
      }
      throw err;
    }
    const bullet = toDto(created.bullet, row.id);
    this.background.run('live bullet fan-out', async () => {
      await this.fanOut({ type: 'bullet', bullet });
    });
    return { created: true, result: { bullet, coins: Number(created.coins) } };
  }

  private byClientId(userId: string, clientId: string): Promise<BulletRow | null> {
    return this.prisma.liveBullet.findUnique({
      where: { userId_clientId: { userId, clientId } },
      include: BULLET_INCLUDE,
    });
  }

  private async replay(userId: string, row: BulletRow, roomId: string): Promise<LiveBulletResultDto> {
    return { bullet: toDto(row, roomId), coins: (await this.wallet.mine(userId)).coins };
  }

  /**
   * Sends the bullet to every LIVE room (audio and video), a few rooms at a time. Best effort per
   * room: a room that is not open on the media server answers with an error, logged and ignored.
   */
  async fanOut(data: LiveBulletData): Promise<number> {
    const payload = JSON.stringify(data);
    const live = await this.prisma.liveRoom.findMany({ where: { status: 'LIVE' }, select: { id: true } });
    let sent = 0;
    for (let i = 0; i < live.length; i += FAN_OUT_CONCURRENCY) {
      const results = await Promise.allSettled(
        live
          .slice(i, i + FAN_OUT_CONCURRENCY)
          .map((r) => this.media.broadcastData(r.id, LIVE_BULLET_TOPIC, payload)),
      );
      for (const result of results) {
        if (result.status === 'fulfilled') sent += 1;
        else {
          this.logger.warn(
            { error: safeErrorLog(result.reason) },
            'Could not send a bullet data message to a media room',
          );
        }
      }
    }
    return sent;
  }
}
