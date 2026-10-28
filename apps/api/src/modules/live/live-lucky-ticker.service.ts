import { Inject, Injectable, Logger, type OnModuleDestroy } from '@nestjs/common';
import type { Redis } from 'ioredis';
import { BackgroundTasks } from '../../common/background/background-tasks.js';
import { safeErrorLog } from '../../logging/redact-text.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { REDIS } from '../../redis/redis.module.js';
import { USER_SUMMARY_SELECT, userSummary } from '../posts/post-views.js';
import { LUCKY_WIN_TOPIC } from './live-gifts.js';
import type { UserSummaryDto } from './live-rooms.service.js';
import { LIVE_MEDIA_PROVIDER, type LiveMediaProvider } from './media/live-media.provider.js';

/** The `win` of a `lucky-win` / `lucky-ticker` data message (v1.27-live, D132; v1.30-live, D148). */
export interface LuckyWinDto {
  giftId: string;
  roomId: string;
  giftCode: string;
  sender: UserSummaryDto;
  multiplier: number;
  coinsWon: number;
  createdAt: string;
}

/**
 * v1.30-live (D148, CONVENTIONS §10.27): the data message of topic `lucky` that every other live
 * room receives for a big win — «فلان ربح ×500 في غرفة …»; the app opens `room.id` on a tap.
 */
export interface LuckyTickerData {
  readonly type: 'lucky-ticker';
  readonly win: LuckyWinDto;
  readonly room: { readonly id: string; readonly title: string; readonly host: UserSummaryDto };
}

/** At most one global ticker per this many milliseconds (all API instances together). */
export const LUCKY_TICKER_GAP_MS = 10_000;
/** A waiting win older than this is dropped (it would no longer be news). */
export const LUCKY_TICKER_PENDING_TTL_MS = 30_000;
/** Rooms told at once (each is one media-server call). */
const BROADCAST_CONCURRENCY = 8;
/** Never more rooms than this per ticker (a bound on one ticker's media-server calls). */
export const LUCKY_TICKER_MAX_ROOMS = 5_000;

const GATE_KEY = 'lucky:ticker:gate';
const PENDING_KEY = 'lucky:ticker:pending';

/**
 * offer(gate, pending; candidate, rank, gapMs, pendingTtlMs): when no ticker went out in the last
 * gap → takes the gate and returns {"now"}; else keeps the candidate as the one waiting when it
 * ranks above the waiting one (or none waits), and returns {"wait", gate pttl}.
 */
const OFFER_SCRIPT = `
if redis.call('SET', KEYS[1], '1', 'PX', ARGV[3], 'NX') then
  return {'now', 0}
end
local current = redis.call('GET', KEYS[2])
local keep = true
if current then
  local rank = tonumber(string.match(current, '^([0-9]+)|'))
  if rank and rank >= tonumber(ARGV[2]) then keep = false end
end
if keep then redis.call('SET', KEYS[2], ARGV[2] .. '|' .. ARGV[1], 'PX', ARGV[4]) end
return {'wait', redis.call('PTTL', KEYS[1])}
`;

/**
 * flush(gate, pending; gapMs): when the gap passed and a win waits → takes the gate and the waiting
 * win ({"go", candidate}); a win waits but the gap has not passed → {"wait", gate pttl}; else {}.
 */
const FLUSH_SCRIPT = `
local current = redis.call('GET', KEYS[2])
if not current then return {} end
if redis.call('SET', KEYS[1], '1', 'PX', ARGV[1], 'NX') then
  redis.call('DEL', KEYS[2])
  return {'go', current}
end
return {'wait', redis.call('PTTL', KEYS[1])}
`;

/** The rank of a win: the multiplier first, then the coins (bigger keeps its place). */
export function tickerRank(win: Pick<LuckyWinDto, 'multiplier' | 'coinsWon'>): number {
  // multiplier ≤ 10 000 (§10.27) → 5 digits; coins capped at 10^10 − 1 for the tie-break.
  return win.multiplier * 10_000_000_000 + Math.min(win.coinsWon, 9_999_999_999);
}

/**
 * v1.30-live (D148, owner «لحظة الحظ»): a big lucky win (≥ LUCKY_GIFT_BIG_WIN_MULTIPLIER) is told
 * to every other LIVE room as a `lucky-ticker` data message on topic `lucky` — at most one ticker
 * per {@link LUCKY_TICKER_GAP_MS} across all API instances (Redis). A win offered inside the gap
 * waits; while it waits a bigger win replaces it (a smaller one is dropped); when the gap ends the
 * waiting win goes out. Best effort, like every data message: Redis or the media server down → no
 * ticker, never a failed send.
 */
@Injectable()
export class LiveLuckyTickerService implements OnModuleDestroy {
  private readonly logger = new Logger(LiveLuckyTickerService.name);
  private timer: NodeJS.Timeout | null = null;
  private stopped = false;

  constructor(
    private readonly prisma: PrismaService,
    @Inject(REDIS) private readonly redis: Redis,
    @Inject(LIVE_MEDIA_PROVIDER) private readonly media: LiveMediaProvider,
    private readonly background: BackgroundTasks,
  ) {}

  onModuleDestroy(): void {
    this.stopped = true;
    if (this.timer) clearTimeout(this.timer);
    this.timer = null;
  }

  /** Offers a big win: told now, or kept waiting (if it is the biggest), or dropped. */
  async offer(win: LuckyWinDto): Promise<void> {
    try {
      const reply = (await this.redis.eval(
        OFFER_SCRIPT,
        2,
        GATE_KEY,
        PENDING_KEY,
        JSON.stringify(win),
        String(tickerRank(win)),
        String(LUCKY_TICKER_GAP_MS),
        String(LUCKY_TICKER_PENDING_TTL_MS),
      )) as [string, number];
      if (reply[0] === 'now') await this.tell(win);
      else this.flushIn(reply[1]);
    } catch (err) {
      this.logger.warn({ error: safeErrorLog(err) }, 'Could not offer a lucky ticker');
    }
  }

  /** Sends the waiting win when the gap is over (also run by the timer). */
  async flush(): Promise<void> {
    try {
      const reply = (await this.redis.eval(
        FLUSH_SCRIPT,
        2,
        GATE_KEY,
        PENDING_KEY,
        String(LUCKY_TICKER_GAP_MS),
      )) as [] | ['go', string] | ['wait', number];
      if (reply[0] === 'go') {
        const raw = reply[1];
        await this.tell(JSON.parse(raw.slice(raw.indexOf('|') + 1)) as LuckyWinDto);
      } else if (reply[0] === 'wait') {
        this.flushIn(reply[1]);
      }
    } catch (err) {
      this.logger.warn({ error: safeErrorLog(err) }, 'Could not flush the lucky ticker');
    }
  }

  private flushIn(pttl: number): void {
    if (this.stopped || this.timer) return;
    const delay = Math.max(pttl, 0) + 25;
    this.timer = setTimeout(() => {
      this.timer = null;
      this.background.run('lucky ticker flush', () => this.flush());
    }, delay);
    this.timer.unref();
  }

  /** The `lucky-ticker` message to every LIVE room but the win's own (it has the big card). */
  private async tell(win: LuckyWinDto): Promise<void> {
    const origin = await this.prisma.liveRoom.findUnique({
      where: { id: win.roomId },
      select: { id: true, title: true, host: { select: USER_SUMMARY_SELECT } },
    });
    if (!origin) return;
    const data: LuckyTickerData = {
      type: 'lucky-ticker',
      win,
      room: { id: origin.id, title: origin.title, host: userSummary(origin.host) },
    };
    const payload = JSON.stringify(data);
    const rooms = await this.prisma.liveRoom.findMany({
      where: { status: 'LIVE', id: { not: win.roomId } },
      select: { id: true },
      orderBy: { startedAt: 'desc' },
      take: LUCKY_TICKER_MAX_ROOMS,
    });
    const ids = rooms.map((r) => r.id);
    for (let i = 0; i < ids.length; i += BROADCAST_CONCURRENCY) {
      await Promise.all(
        ids.slice(i, i + BROADCAST_CONCURRENCY).map(async (roomId) => {
          try {
            await this.media.broadcastData(roomId, LUCKY_WIN_TOPIC, payload);
          } catch (err) {
            this.logger.warn({ error: safeErrorLog(err) }, 'Could not send a lucky ticker to a media room');
          }
        }),
      );
    }
  }
}
