import { Inject, Injectable, Logger, type OnModuleDestroy } from '@nestjs/common';
import type { Redis } from 'ioredis';
import { BackgroundTasks } from '../../common/background/background-tasks.js';
import { safeErrorLog } from '../../logging/redact-text.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { REDIS } from '../../redis/redis.module.js';
import { USER_SUMMARY_SELECT, userSummary } from '../posts/post-views.js';
import { announcesLevelUp, readLevelTickerMinLevel } from '../site-settings/level-ticker.rules.js';
import type { UserSummaryDto } from './live-rooms.service.js';
import { LIVE_MEDIA_PROVIDER, type LiveMediaProvider } from './media/live-media.provider.js';

/** v1.62-live (D254): the data message topic of the level-up banner. */
export const LEVEL_TICKER_TOPIC = 'level';

/** The two level systems announced (owner D254): support (gift senders) and charm (hosts and guests). */
export type LevelTickerCategory = 'SUPPORT' | 'ATTRACTIVENESS';

/** A level change made in a live (a gift send or a tap batch), offered to the banner. */
export interface LevelUpOffer {
  /** The credit that moved the level (`gift:<giftId>` or `taps:<roomId>:…`), for the logs and the app's dedup. */
  readonly sourceId: string;
  readonly userId: string;
  readonly category: LevelTickerCategory;
  readonly previousLevel: number | null;
  readonly level: number;
  /** The LIVE room the level changed in. */
  readonly roomId: string;
  readonly createdAt: string;
}

/** The level-up of a `level-ticker` message. */
export interface LevelTickerLevelUpDto {
  /** `<userId>:<category>:<level>` — one announcement per person, level system and level. */
  readonly id: string;
  readonly user: UserSummaryDto;
  readonly category: LevelTickerCategory;
  readonly level: number;
  readonly previousLevel: number | null;
  readonly roomId: string;
  readonly createdAt: string;
}

/**
 * v1.62-live (D254, owner «شريط متحرك لاعلان عن ترقية الحسابات وصعود ليفيلات لليفيلات المرتفعة»): the data message
 * of topic `level` that EVERY live room receives (its own room too) when someone's support or charm level rises to
 * the panel's threshold or above; the app shows a scrolling banner and opens `room.id` on a tap.
 */
export interface LevelTickerData {
  readonly type: 'level-ticker';
  readonly levelUp: LevelTickerLevelUpDto;
  readonly room: { readonly id: string; readonly title: string; readonly host: UserSummaryDto };
}

/** At most one banner per this many milliseconds across all API instances (the app scrolls each for as long). */
export const LEVEL_TICKER_GAP_MS = 8_000;
/** At most this many level-ups wait for their turn (oldest first); more are dropped. */
export const LEVEL_TICKER_MAX_WAITING = 20;
/** A waiting level-up older than this is dropped (it would be stale news). */
export const LEVEL_TICKER_MAX_AGE_MS = 120_000;
/** One announcement per person, level system and level for this long (a level regained is not news). */
export const LEVEL_TICKER_SEEN_TTL_S = 7 * 24 * 3600;
/** Rooms told at once (each is one media-server call). */
const BROADCAST_CONCURRENCY = 8;
/** Never more rooms than this per banner. */
export const LEVEL_TICKER_MAX_ROOMS = 5_000;

const GATE_KEY = 'level:ticker:gate';
const PENDING_KEY = 'level:ticker:pending';
const seenKey = (o: LevelUpOffer): string => `level:ticker:seen:${o.userId}:${o.category}:${String(o.level)}`;

/**
 * offer(gate, pending, seen; item, gapMs, maxWaiting, seenTtlS, maxAgeMs): already announced → {"seen"}; nobody
 * waiting and no banner in the last gap → takes the gate ({"now"}); else the item waits at the end of the line
 * ({"wait", gate pttl}) unless the line is full ({"full", gate pttl}).
 */
const OFFER_SCRIPT = `
if not redis.call('SET', KEYS[3], '1', 'EX', ARGV[4], 'NX') then
  return {'seen', 0}
end
local waiting = redis.call('LLEN', KEYS[2])
if waiting == 0 and redis.call('SET', KEYS[1], '1', 'PX', ARGV[2], 'NX') then
  return {'now', 0}
end
if waiting >= tonumber(ARGV[3]) then
  return {'full', redis.call('PTTL', KEYS[1])}
end
redis.call('RPUSH', KEYS[2], ARGV[1])
redis.call('PEXPIRE', KEYS[2], ARGV[5])
return {'wait', redis.call('PTTL', KEYS[1])}
`;

/**
 * flush(gate, pending; gapMs, nowMs, maxAgeMs): the gap is not over → {"wait", pttl} (or {} when nobody waits);
 * else the oldest fresh item takes the gate → {"go", item, still waiting}; stale ones are dropped on the way.
 */
const FLUSH_SCRIPT = `
if redis.call('EXISTS', KEYS[1]) == 1 then
  if redis.call('LLEN', KEYS[2]) == 0 then return {} end
  return {'wait', redis.call('PTTL', KEYS[1])}
end
while true do
  local item = redis.call('LPOP', KEYS[2])
  if not item then return {} end
  local at = tonumber(string.match(item, '^([0-9]+)|'))
  if at and at >= tonumber(ARGV[2]) - tonumber(ARGV[3]) then
    redis.call('SET', KEYS[1], '1', 'PX', ARGV[1])
    return {'go', item, redis.call('LLEN', KEYS[2])}
  end
end
`;

/**
 * v1.62-live (D254): the level-up banner. A support or charm level that rises to the OWNER's threshold
 * (`levelTickerMinLevel`, default 30) or above in a live is told to every LIVE room (its own included) as a
 * `level-ticker` data message on topic `level` — one banner per {@link LEVEL_TICKER_GAP_MS} across all API
 * instances (Redis); level-ups offered inside the gap wait in line (oldest first, at most
 * {@link LEVEL_TICKER_MAX_WAITING}, none older than {@link LEVEL_TICKER_MAX_AGE_MS}). A person's level in a level
 * system is announced once. Best effort, like every data message: Redis, the database or the media server down →
 * no banner, never a failed gift or tap.
 */
@Injectable()
export class LiveLevelTickerService implements OnModuleDestroy {
  private readonly logger = new Logger(LiveLevelTickerService.name);
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

  /** Offers the level changes of one send or tap batch, in order (below the threshold: ignored). */
  async offerAll(offers: readonly LevelUpOffer[]): Promise<void> {
    if (offers.length === 0) return;
    const minLevel = await readLevelTickerMinLevel(this.prisma);
    for (const offer of offers) {
      if (!announcesLevelUp(offer.previousLevel, offer.level, minLevel)) continue;
      await this.offer(offer);
    }
  }

  private async offer(offer: LevelUpOffer): Promise<void> {
    try {
      const reply = (await this.redis.eval(
        OFFER_SCRIPT,
        3,
        GATE_KEY,
        PENDING_KEY,
        seenKey(offer),
        `${String(Date.now())}|${JSON.stringify(offer)}`,
        String(LEVEL_TICKER_GAP_MS),
        String(LEVEL_TICKER_MAX_WAITING),
        String(LEVEL_TICKER_SEEN_TTL_S),
        String(LEVEL_TICKER_MAX_AGE_MS),
      )) as [string, number];
      if (reply[0] === 'now') await this.tell(offer);
      else if (reply[0] === 'wait' || reply[0] === 'full') this.flushIn(reply[1]);
    } catch (err) {
      this.logger.warn({ error: safeErrorLog(err) }, 'Could not offer a level ticker');
    }
  }

  /** Sends the oldest waiting level-up when the gap is over (also run by the timer). */
  async flush(): Promise<void> {
    try {
      const reply = (await this.redis.eval(
        FLUSH_SCRIPT,
        2,
        GATE_KEY,
        PENDING_KEY,
        String(LEVEL_TICKER_GAP_MS),
        String(Date.now()),
        String(LEVEL_TICKER_MAX_AGE_MS),
      )) as [] | ['go', string, number] | ['wait', number];
      if (reply[0] === 'go') {
        const raw = reply[1];
        if (reply[2] > 0) this.flushIn(LEVEL_TICKER_GAP_MS);
        await this.tell(JSON.parse(raw.slice(raw.indexOf('|') + 1)) as LevelUpOffer);
      } else if (reply[0] === 'wait') {
        this.flushIn(reply[1]);
      }
    } catch (err) {
      this.logger.warn({ error: safeErrorLog(err) }, 'Could not flush the level ticker');
    }
  }

  private flushIn(pttl: number): void {
    if (this.stopped || this.timer) return;
    const delay = Math.max(pttl, 0) + 25;
    this.timer = setTimeout(() => {
      this.timer = null;
      this.background.run('level ticker flush', () => this.flush());
    }, delay);
    this.timer.unref();
  }

  /** The `level-ticker` message to every LIVE room, the level-up's own room first. */
  private async tell(offer: LevelUpOffer): Promise<void> {
    const [origin, user] = await Promise.all([
      this.prisma.liveRoom.findUnique({
        where: { id: offer.roomId },
        select: { id: true, title: true, status: true, host: { select: USER_SUMMARY_SELECT } },
      }),
      this.prisma.user.findUnique({ where: { id: offer.userId }, select: USER_SUMMARY_SELECT }),
    ]);
    // The live ended meanwhile (nothing to open) or the account is gone: no banner.
    if (!origin || origin.status !== 'LIVE' || !user) return;
    const data: LevelTickerData = {
      type: 'level-ticker',
      levelUp: {
        id: `${offer.userId}:${offer.category}:${String(offer.level)}`,
        user: userSummary(user),
        category: offer.category,
        level: offer.level,
        previousLevel: offer.previousLevel,
        roomId: offer.roomId,
        createdAt: offer.createdAt,
      },
      room: { id: origin.id, title: origin.title, host: userSummary(origin.host) },
    };
    const payload = JSON.stringify(data);
    const rooms = await this.prisma.liveRoom.findMany({
      where: { status: 'LIVE', id: { not: origin.id } },
      select: { id: true },
      orderBy: { startedAt: 'desc' },
      take: LEVEL_TICKER_MAX_ROOMS - 1,
    });
    const ids = [origin.id, ...rooms.map((r) => r.id)];
    for (let i = 0; i < ids.length; i += BROADCAST_CONCURRENCY) {
      await Promise.all(
        ids.slice(i, i + BROADCAST_CONCURRENCY).map(async (roomId) => {
          try {
            await this.media.broadcastData(roomId, LEVEL_TICKER_TOPIC, payload);
          } catch (err) {
            this.logger.warn({ error: safeErrorLog(err) }, 'Could not send a level ticker to a media room');
          }
        }),
      );
    }
  }
}
