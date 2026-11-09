import { Inject, Injectable, Logger, type OnModuleDestroy } from '@nestjs/common';
import type { Redis } from 'ioredis';
import { BackgroundTasks } from '../../common/background/background-tasks.js';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import { safeErrorLog } from '../../logging/redact-text.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { REDIS } from '../../redis/redis.module.js';
import { USER_SUMMARY_SELECT, userSummary } from '../posts/post-views.js';
import {
  globalStripsDefaultsOf,
  luckyMultipliersOf,
  readGlobalStrips,
  type GlobalStripsSettingsDto,
} from '../site-settings/global-strips.rules.js';
import { LIVE_GIFT_TOPIC } from './live-gifts.js';
import type { UserSummaryDto } from './live-rooms.service.js';
import { LIVE_MEDIA_PROVIDER, type LiveMediaProvider } from './media/live-media.provider.js';

/** The gift of a `gift-ticker` message: the room's `gift` message's `LiveGift`. */
export type GiftTickerGiftDto = Record<string, unknown> & {
  readonly id: string;
  readonly roomId: string;
  readonly totalCoins: number;
  /** The price of one gift when it was sent (D305: the strip's threshold is on it). */
  readonly unitPrice: number;
  readonly createdAt: string;
};

/** The live a strip happened in (a tap opens it). */
export interface StripRoomDto {
  readonly id: string;
  readonly title: string;
  readonly host: UserSummaryDto;
}

/**
 * v1.41-live (D178, owner «والهدايا يجب أن تظهر في شريط في جميع البثوث»): the data message of topic
 * `gift` for a gift send of at least GIFT_GLOBAL_TICKER_MIN_COINS coins; the app shows it as a strip
 * and opens `room.id` on a tap. v1.85-live (D305): `kind` GIFT, and its own room receives it too.
 */
export interface GiftTickerData {
  readonly type: 'gift-ticker';
  readonly kind: 'GIFT';
  readonly gift: GiftTickerGiftDto;
  readonly room: StripRoomDto;
}

/** v1.85-live (D305): what a game tells the strip about one prize it paid in tickets. */
export interface GameWinOffer {
  /** The win's own id (the game's round or prize id): one strip per id, ever (a retried call is ignored). */
  readonly id: string;
  /** The game's code, its name in the app's language-neutral form, and its thumbnail (or null). */
  readonly gameCode: string;
  readonly gameName: string;
  readonly gameImageUrl: string | null;
  readonly winnerId: string;
  /** The prize's value in tickets «التذاكر» (game cards, D182). */
  readonly tickets: number;
  /** The live the game was played in, or null (a game outside a live). */
  readonly roomId: string | null;
  readonly createdAt: string;
}

/** v1.85-live (D305): the `GameWin` of a `game-win-ticker` message. */
export interface GameWinDto {
  readonly id: string;
  readonly game: { readonly code: string; readonly name: string; readonly imageUrl: string | null };
  readonly winner: UserSummaryDto;
  readonly tickets: number;
  readonly roomId: string | null;
  readonly createdAt: string;
}

/**
 * v1.85-live (D305, owner «شريط الألعاب … فاز (اسم الفائز) بجائزة قيمتها (قيمة الجائزة بالتذاكر)»): the
 * data message of topic `gift` for a game prize of at least GAME_WIN_TICKER_MIN_TICKETS tickets, to
 * every LIVE room; `room` is the live it was won in (null: none, or it is no longer LIVE).
 */
export interface GameWinTickerData {
  readonly type: 'game-win-ticker';
  readonly kind: 'GAME_WIN';
  readonly win: GameWinDto;
  readonly room: StripRoomDto | null;
}

/** One waiting strip, in Redis (the kind decides how it is told). */
type StripEntry =
  | { readonly kind: 'GIFT'; readonly gift: GiftTickerGiftDto }
  | { readonly kind: 'GAME_WIN'; readonly win: GameWinOffer };

/**
 * At most one strip of a kind per this many milliseconds across all API instances (owner: one at a time,
 * 3 s each). v1.85-live (D305b, owner «شريط الألعاب يكون موقعه فوق شريط الهدايا»): each kind has its own lane
 * in the app, so each kind has its own gate — a gift strip and a games strip can show at the same time.
 */
export const GIFT_TICKER_GAP_MS = 3_000;
/** A waiting strip older than this is dropped (no long queue). */
export const GIFT_TICKER_PENDING_TTL_MS = 12_000;
/** A game win's id is remembered this long (a retried hook call makes no second strip). */
export const GAME_WIN_SEEN_TTL_S = 24 * 3600;
/** The panel's thresholds are read again after this long (owner: effective without a restart, ≤ 60 s). */
export const GLOBAL_STRIPS_CACHE_MS = 30_000;
/** Rooms told at once (each is one media-server call). */
const BROADCAST_CONCURRENCY = 8;
/** Never more rooms than this per strip. */
export const GIFT_TICKER_MAX_ROOMS = 5_000;

type StripKind = StripEntry['kind'];

/** The Redis gate and waiting slot of each kind (the GIFT ones are D178's keys). */
const LANE_KEYS: Record<StripKind, { readonly gate: string; readonly pending: string }> = {
  GIFT: { gate: 'gift:ticker:gate', pending: 'gift:ticker:pending' },
  GAME_WIN: { gate: 'gift:ticker:game:gate', pending: 'gift:ticker:game:pending' },
};
const gameSeenKey = (id: string): string => `gift:ticker:game-seen:${id}`;

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
 * v1.41-live (D178) / v1.85-live (D305): the global strips «شريط الهدايا» and «شريط الألعاب». A gift
 * send of at least GIFT_GLOBAL_TICKER_MIN_COINS coins (`gift-ticker`, kind GIFT) and a game prize of at
 * least GAME_WIN_TICKER_MIN_TICKETS tickets (`game-win-ticker`, kind GAME_WIN) are told to every LIVE
 * room — the one it happened in too (owner «في جميع الغرف») — on topic `gift`. One strip of each kind per
 * {@link GIFT_TICKER_GAP_MS} across all API instances (Redis; the two kinds are separate lanes, D305b); a strip
 * offered inside its kind's gap waits, a newer one replaces it (one deep: older ones are dropped). Best effort, like every data
 * message: Redis or the media server down → no strip, never a failed send or game.
 */
@Injectable()
export class LiveGiftTickerService implements OnModuleDestroy {
  private readonly logger = new Logger(LiveGiftTickerService.name);
  private readonly timers: Record<StripKind, NodeJS.Timeout | null> = { GIFT: null, GAME_WIN: null };
  private stopped = false;
  private cached: { readonly at: number; readonly value: GlobalStripsSettingsDto } | null = null;

  constructor(
    private readonly prisma: PrismaService,
    @Inject(REDIS) private readonly redis: Redis,
    @Inject(LIVE_MEDIA_PROVIDER) private readonly media: LiveMediaProvider,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
    private readonly background: BackgroundTasks,
  ) {}

  onModuleDestroy(): void {
    this.stopped = true;
    for (const kind of ['GIFT', 'GAME_WIN'] as const) {
      const timer = this.timers[kind];
      if (timer) clearTimeout(timer);
      this.timers[kind] = null;
    }
  }

  /**
   * The thresholds in use: the OWNER's (`site_settings` key `globalStrips`, the panel), else the configuration
   * (`GIFT_GLOBAL_TICKER_MIN_COINS` 500 000, `GAME_WIN_TICKER_MIN_TICKETS` 1 000 000); cached
   * {@link GLOBAL_STRIPS_CACHE_MS}.
   */
  async thresholds(): Promise<GlobalStripsSettingsDto> {
    const now = Date.now();
    if (this.cached && now - this.cached.at < GLOBAL_STRIPS_CACHE_MS) return this.cached.value;
    const value = await readGlobalStrips(
      this.prisma,
      globalStripsDefaultsOf(this.config),
      luckyMultipliersOf(this.config),
    );
    this.cached = { at: now, value };
    return value;
  }

  /** Forgets the cached thresholds (tests; the next offer reads them again). */
  forgetThresholds(): void {
    this.cached = null;
  }

  /**
   * Offers a gift send: told now, kept waiting, or ignored. v1.85-live (D305, owner decision): the threshold is on
   * the price of ONE gift (`unitPrice`), whatever the quantity and the recipients — 10 × 50 000 does not qualify
   * (D178 compared the send's `totalCoins`).
   */
  async offer(gift: GiftTickerGiftDto): Promise<void> {
    if (!(gift.unitPrice >= (await this.thresholds()).giftMinCoins)) return;
    await this.offerEntry({ kind: 'GIFT', gift }, gift.createdAt);
  }

  /**
   * v1.85-live (D305): THE HOOK FOR GAMES. No game pays ticket prizes yet (D173: «الألعاب قريباً»);
   * a game calls this once per prize, after the transaction that credits the winner's tickets has
   * committed (never on an idempotent replay; a repeated `id` is ignored anyway), through
   * `BackgroundTasks.run` so a strip never delays or fails the game. Below the threshold: nothing.
   */
  async offerGameWin(win: GameWinOffer): Promise<void> {
    if (!Number.isSafeInteger(win.tickets) || win.tickets < (await this.thresholds()).gameMinTickets) return;
    try {
      const first = await this.redis.set(gameSeenKey(win.id), '1', 'EX', GAME_WIN_SEEN_TTL_S, 'NX');
      if (first !== 'OK') return;
    } catch (err) {
      this.logger.warn({ error: safeErrorLog(err) }, 'Could not offer a game win ticker');
      return;
    }
    await this.offerEntry({ kind: 'GAME_WIN', win }, win.createdAt);
  }

  private async offerEntry(entry: StripEntry, createdAt: string): Promise<void> {
    const keys = LANE_KEYS[entry.kind];
    try {
      const reply = (await this.redis.eval(
        OFFER_SCRIPT,
        2,
        keys.gate,
        keys.pending,
        JSON.stringify(entry),
        String(new Date(createdAt).getTime()),
        String(GIFT_TICKER_GAP_MS),
        String(GIFT_TICKER_PENDING_TTL_MS),
      )) as [string, number];
      if (reply[0] === 'now') await this.tell(entry);
      else this.flushIn(entry.kind, reply[1]);
    } catch (err) {
      this.logger.warn({ error: safeErrorLog(err) }, 'Could not offer a global strip');
    }
  }

  /** Sends the waiting strip of [kind] when its gap is over (also run by the timer). */
  async flush(kind: StripKind = 'GIFT'): Promise<void> {
    const keys = LANE_KEYS[kind];
    try {
      const reply = (await this.redis.eval(
        FLUSH_SCRIPT,
        2,
        keys.gate,
        keys.pending,
        String(GIFT_TICKER_GAP_MS),
      )) as [] | ['go', string] | ['wait', number];
      if (reply[0] === 'go') {
        const raw = reply[1];
        const parsed = JSON.parse(raw.slice(raw.indexOf('|') + 1)) as Partial<StripEntry> &
          Record<string, unknown>;
        // A send kept by an API before v1.85-live is the bare gift.
        const entry: StripEntry =
          parsed.kind === 'GIFT' || parsed.kind === 'GAME_WIN'
            ? (parsed as StripEntry)
            : { kind: 'GIFT', gift: parsed as unknown as GiftTickerGiftDto };
        await this.tell(entry);
      } else if (reply[0] === 'wait') {
        this.flushIn(kind, reply[1]);
      }
    } catch (err) {
      this.logger.warn({ error: safeErrorLog(err) }, 'Could not flush the global strip');
    }
  }

  private flushIn(kind: StripKind, pttl: number): void {
    if (this.stopped || this.timers[kind]) return;
    const delay = Math.max(pttl, 0) + 25;
    const timer = setTimeout(() => {
      this.timers[kind] = null;
      this.background.run('gift ticker flush', () => this.flush(kind));
    }, delay);
    timer.unref();
    this.timers[kind] = timer;
  }

  private async tell(entry: StripEntry): Promise<void> {
    if (entry.kind === 'GIFT') await this.tellGift(entry.gift);
    else await this.tellGameWin(entry.win);
  }

  /** The `gift-ticker` message to every LIVE room, its own first. */
  private async tellGift(gift: GiftTickerGiftDto): Promise<void> {
    const origin = await this.liveRoom(gift.roomId);
    if (!origin) return;
    const data: GiftTickerData = { type: 'gift-ticker', kind: 'GIFT', gift, room: origin };
    await this.toEveryLive(JSON.stringify(data), origin.id);
  }

  /** The `game-win-ticker` message to every LIVE room, the game's own first. */
  private async tellGameWin(win: GameWinOffer): Promise<void> {
    const winner = await this.prisma.user.findUnique({
      where: { id: win.winnerId },
      select: USER_SUMMARY_SELECT,
    });
    if (!winner) return;
    const room = win.roomId === null ? null : await this.liveRoom(win.roomId);
    const data: GameWinTickerData = {
      type: 'game-win-ticker',
      kind: 'GAME_WIN',
      win: {
        id: win.id,
        game: { code: win.gameCode, name: win.gameName, imageUrl: win.gameImageUrl },
        winner: userSummary(winner),
        tickets: win.tickets,
        roomId: room?.id ?? null,
        createdAt: win.createdAt,
      },
      room,
    };
    await this.toEveryLive(JSON.stringify(data), room?.id ?? null);
  }

  private async liveRoom(id: string): Promise<StripRoomDto | null> {
    const row = await this.prisma.liveRoom.findUnique({
      where: { id },
      select: { id: true, title: true, status: true, host: { select: USER_SUMMARY_SELECT } },
    });
    if (!row || row.status !== 'LIVE') return null;
    return { id: row.id, title: row.title, host: userSummary(row.host) };
  }

  private async toEveryLive(payload: string, first: string | null): Promise<void> {
    const rooms = await this.prisma.liveRoom.findMany({
      where: { status: 'LIVE', ...(first === null ? {} : { id: { not: first } }) },
      select: { id: true },
      orderBy: { startedAt: 'desc' },
      take: first === null ? GIFT_TICKER_MAX_ROOMS : GIFT_TICKER_MAX_ROOMS - 1,
    });
    const ids = [...(first === null ? [] : [first]), ...rooms.map((r) => r.id)];
    for (let i = 0; i < ids.length; i += BROADCAST_CONCURRENCY) {
      await Promise.all(
        ids.slice(i, i + BROADCAST_CONCURRENCY).map(async (roomId) => {
          try {
            await this.media.broadcastData(roomId, LIVE_GIFT_TOPIC, payload);
          } catch (err) {
            this.logger.warn({ error: safeErrorLog(err) }, 'Could not send a global strip to a media room');
          }
        }),
      );
    }
  }
}
