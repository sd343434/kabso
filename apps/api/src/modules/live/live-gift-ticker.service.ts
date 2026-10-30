import { Inject, Injectable, Logger, type OnModuleDestroy } from '@nestjs/common';
import type { Redis } from 'ioredis';
import { BackgroundTasks } from '../../common/background/background-tasks.js';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import { safeErrorLog } from '../../logging/redact-text.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { REDIS } from '../../redis/redis.module.js';
import { USER_SUMMARY_SELECT, userSummary } from '../posts/post-views.js';
import { LIVE_GIFT_TOPIC } from './live-gifts.js';
import type { UserSummaryDto } from './live-rooms.service.js';
import { LIVE_MEDIA_PROVIDER, type LiveMediaProvider } from './media/live-media.provider.js';

/** The gift of a `gift-ticker` message: the room's `gift` message's `LiveGift`. */
export type GiftTickerGiftDto = Record<string, unknown> & {
  readonly id: string;
  readonly roomId: string;
  readonly totalCoins: number;
  readonly createdAt: string;
};

/**
 * v1.41-live (D178, owner «والهدايا يجب أن تظهر في شريط في جميع البثوث»): the data message of topic
 * `gift` that every other LIVE room receives for a gift send of at least GIFT_GLOBAL_TICKER_MIN_COINS
 * coins; the app shows it as a strip and opens `room.id` on a tap.
 */
export interface GiftTickerData {
  readonly type: 'gift-ticker';
  readonly gift: GiftTickerGiftDto;
  readonly room: { readonly id: string; readonly title: string; readonly host: UserSummaryDto };
}

/** At most one gift strip per this many milliseconds across all API instances (one at a time, 3 s each: owner). */
export const GIFT_TICKER_GAP_MS = 3_000;
/** A waiting send older than this is dropped (no long queue). */
export const GIFT_TICKER_PENDING_TTL_MS = 12_000;
/** Rooms told at once (each is one media-server call). */
const BROADCAST_CONCURRENCY = 8;
/** Never more rooms than this per strip. */
export const GIFT_TICKER_MAX_ROOMS = 5_000;

const GATE_KEY = 'gift:ticker:gate';
const PENDING_KEY = 'gift:ticker:pending';

/**
 * offer(gate, pending; candidate, rank, gapMs, pendingTtlMs): no strip in the last gap → takes the
 * gate ({"now"}); else keeps the candidate as the one waiting when it is newer than the waiting one
 * (the newest first; older ones are dropped) and returns {"wait", gate pttl}.
 */
const OFFER_SCRIPT = `
if redis.call('SET', KEYS[1], '1', 'PX', ARGV[3], 'NX') then
  return {'now', 0}
end
local current = redis.call('GET', KEYS[2])
local keep = true
if current then
  local rank = tonumber(string.match(current, '^([0-9]+)|'))
  if rank and rank > tonumber(ARGV[2]) then keep = false end
end
if keep then redis.call('SET', KEYS[2], ARGV[2] .. '|' .. ARGV[1], 'PX', ARGV[4]) end
return {'wait', redis.call('PTTL', KEYS[1])}
`;

/** flush(gate, pending; gapMs): as the lucky ticker's (D148). */
const FLUSH_SCRIPT = `
local current = redis.call('GET', KEYS[2])
if not current then return {} end
if redis.call('SET', KEYS[1], '1', 'PX', ARGV[1], 'NX') then
  redis.call('DEL', KEYS[2])
  return {'go', current}
end
return {'wait', redis.call('PTTL', KEYS[1])}
`;

/**
 * v1.41-live (D178): the global gift strip. A send of at least GIFT_GLOBAL_TICKER_MIN_COINS coins is
 * told to every other LIVE room as a `gift-ticker` data message on topic `gift` — one strip per
 * {@link GIFT_TICKER_GAP_MS} across all API instances (Redis); a send offered inside the gap waits,
 * a newer one replaces it (the queue is one deep: older ones are dropped). Best effort, like every
 * data message: Redis or the media server down → no strip, never a failed send. Its own room has
 * the `gift` message already.
 */
@Injectable()
export class LiveGiftTickerService implements OnModuleDestroy {
  private readonly logger = new Logger(LiveGiftTickerService.name);
  private timer: NodeJS.Timeout | null = null;
  private stopped = false;

  constructor(
    private readonly prisma: PrismaService,
    @Inject(REDIS) private readonly redis: Redis,
    @Inject(LIVE_MEDIA_PROVIDER) private readonly media: LiveMediaProvider,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
    private readonly background: BackgroundTasks,
  ) {}

  onModuleDestroy(): void {
    this.stopped = true;
    if (this.timer) clearTimeout(this.timer);
    this.timer = null;
  }

  /** The coins from which a send makes the strip (GIFT_GLOBAL_TICKER_MIN_COINS). */
  get minCoins(): number {
    return this.config.live.giftTickerMinCoins;
  }

  /** Offers a send: told now, kept waiting (the newest), or ignored below the threshold. */
  async offer(gift: GiftTickerGiftDto): Promise<void> {
    if (gift.totalCoins < this.minCoins) return;
    try {
      const reply = (await this.redis.eval(
        OFFER_SCRIPT,
        2,
        GATE_KEY,
        PENDING_KEY,
        JSON.stringify(gift),
        String(new Date(gift.createdAt).getTime()),
        String(GIFT_TICKER_GAP_MS),
        String(GIFT_TICKER_PENDING_TTL_MS),
      )) as [string, number];
      if (reply[0] === 'now') await this.tell(gift);
      else this.flushIn(reply[1]);
    } catch (err) {
      this.logger.warn({ error: safeErrorLog(err) }, 'Could not offer a gift ticker');
    }
  }

  /** Sends the waiting send when the gap is over (also run by the timer). */
  async flush(): Promise<void> {
    try {
      const reply = (await this.redis.eval(
        FLUSH_SCRIPT,
        2,
        GATE_KEY,
        PENDING_KEY,
        String(GIFT_TICKER_GAP_MS),
      )) as [] | ['go', string] | ['wait', number];
      if (reply[0] === 'go') {
        const raw = reply[1];
        await this.tell(JSON.parse(raw.slice(raw.indexOf('|') + 1)) as GiftTickerGiftDto);
      } else if (reply[0] === 'wait') {
        this.flushIn(reply[1]);
      }
    } catch (err) {
      this.logger.warn({ error: safeErrorLog(err) }, 'Could not flush the gift ticker');
    }
  }

  private flushIn(pttl: number): void {
    if (this.stopped || this.timer) return;
    const delay = Math.max(pttl, 0) + 25;
    this.timer = setTimeout(() => {
      this.timer = null;
      this.background.run('gift ticker flush', () => this.flush());
    }, delay);
    this.timer.unref();
  }

  /** The `gift-ticker` message to every LIVE room but the send's own. */
  private async tell(gift: GiftTickerGiftDto): Promise<void> {
    const origin = await this.prisma.liveRoom.findUnique({
      where: { id: gift.roomId },
      select: { id: true, title: true, status: true, host: { select: USER_SUMMARY_SELECT } },
    });
    if (!origin || origin.status !== 'LIVE') return;
    const data: GiftTickerData = {
      type: 'gift-ticker',
      gift,
      room: { id: origin.id, title: origin.title, host: userSummary(origin.host) },
    };
    const payload = JSON.stringify(data);
    const rooms = await this.prisma.liveRoom.findMany({
      where: { status: 'LIVE', id: { not: gift.roomId } },
      select: { id: true },
      orderBy: { startedAt: 'desc' },
      take: GIFT_TICKER_MAX_ROOMS,
    });
    const ids = rooms.map((r) => r.id);
    for (let i = 0; i < ids.length; i += BROADCAST_CONCURRENCY) {
      await Promise.all(
        ids.slice(i, i + BROADCAST_CONCURRENCY).map(async (roomId) => {
          try {
            await this.media.broadcastData(roomId, LIVE_GIFT_TOPIC, payload);
          } catch (err) {
            this.logger.warn({ error: safeErrorLog(err) }, 'Could not send a gift ticker to a media room');
          }
        }),
      );
    }
  }
}
