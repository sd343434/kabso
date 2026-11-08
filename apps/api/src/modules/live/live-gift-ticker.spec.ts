import { describe, expect, it, vi } from 'vitest';
import type { BackgroundTasks } from '../../common/background/background-tasks.js';
import type { AppConfig } from '../../config/app-config.js';
import type { PrismaService } from '../../prisma/prisma.service.js';
import {
  GIFT_TICKER_GAP_MS,
  LiveGiftTickerService,
  type GameWinOffer,
  type GiftTickerGiftDto,
} from './live-gift-ticker.service.js';
import type { LiveMediaProvider } from './media/live-media.provider.js';

const person = (id: string) => ({
  id,
  profile: { username: `u_${id}`, displayName: `Name ${id}`, avatarUrl: null },
});

function setup(
  opts: {
    reply?: unknown;
    status?: string;
    seen?: boolean;
    pending?: string;
    winner?: boolean;
    panel?: unknown;
  } = {},
) {
  const evals: unknown[][] = [];
  const sets: unknown[][] = [];
  const redis = {
    eval: vi.fn(async (...args: unknown[]) => {
      evals.push(args);
      if (opts.pending !== undefined) return ['go', opts.pending];
      return opts.reply ?? ['now', 0];
    }),
    set: vi.fn(async (...args: unknown[]) => {
      sets.push(args);
      return opts.seen ? null : 'OK';
    }),
  };
  const broadcasts: { room: string; topic: string; payload: string }[] = [];
  const media = {
    broadcastData: vi.fn(async (room: string, topic: string, payload: string) => {
      broadcasts.push({ room, topic, payload });
      if (room === 'room-bad') throw new Error('media down');
    }),
  } as unknown as LiveMediaProvider;
  const findMany = vi.fn(async () => [{ id: 'room-2' }, { id: 'room-bad' }, { id: 'room-3' }]);
  const prisma = {
    liveRoom: {
      findUnique: async () => ({
        id: 'room-1',
        title: 'Evening',
        status: opts.status ?? 'LIVE',
        host: person('host'),
      }),
      findMany,
    },
    user: { findUnique: async () => (opts.winner === false ? null : person('winner')) },
    siteSetting: {
      findUnique: vi.fn(async () =>
        opts.panel === undefined ? null : { key: 'globalStrips', value: opts.panel },
      ),
    },
  } as unknown as PrismaService;
  const config = {
    live: { giftTickerMinCoins: 500_000, gameWinTickerMinTickets: 1_000_000 },
  } as unknown as AppConfig;
  const background = { run: vi.fn() } as unknown as BackgroundTasks;
  const service = new LiveGiftTickerService(prisma, redis as never, media, config, background);
  return { service, evals, sets, broadcasts, findMany, prisma };
}

const gift = (unitPrice: number, quantity = 1): GiftTickerGiftDto => ({
  id: 'g1',
  roomId: 'room-1',
  unitPrice,
  totalCoins: unitPrice * quantity,
  createdAt: '2026-11-07T10:00:00.000Z',
});

const win = (over: Partial<GameWinOffer> = {}): GameWinOffer => ({
  id: 'w1',
  gameCode: 'wheel',
  gameName: 'Wheel',
  gameImageUrl: null,
  winnerId: 'winner',
  tickets: 1_000_000,
  roomId: 'room-1',
  createdAt: '2026-11-07T10:00:00.000Z',
  ...over,
});

describe('D305 global strips (D178 gift ticker extended)', () => {
  it("a gift priced below 500 000 is not offered (10 × 50 000 neither: one gift's price counts); at 500 000 it goes to every LIVE room, its own first, kind GIFT", async () => {
    const { service, evals, broadcasts } = setup();
    await service.offer(gift(499_999));
    await service.offer(gift(50_000, 10));
    expect(evals).toHaveLength(0);
    await service.offer(gift(500_000));
    expect(evals).toHaveLength(1);
    expect(evals[0]![2]).toBe('gift:ticker:gate');
    expect(evals[0]![6]).toBe(String(GIFT_TICKER_GAP_MS));
    expect(broadcasts.map((b) => b.room)).toEqual(['room-1', 'room-2', 'room-bad', 'room-3']);
    expect(new Set(broadcasts.map((b) => b.topic))).toEqual(new Set(['gift']));
    expect(JSON.parse(broadcasts[0]!.payload)).toMatchObject({
      type: 'gift-ticker',
      kind: 'GIFT',
      gift: { id: 'g1', unitPrice: 500_000, totalCoins: 500_000 },
      room: { id: 'room-1', title: 'Evening', host: { id: 'host' } },
    });
  });

  it('a gift whose live has ended is not told', async () => {
    const { service, broadcasts } = setup({ status: 'ENDED' });
    await service.offer(gift(600_000));
    expect(broadcasts).toEqual([]);
  });

  it('inside the gap the strip waits (no broadcast)', async () => {
    const { service, broadcasts } = setup({ reply: ['wait', 1000] });
    await service.offer(gift(600_000));
    expect(broadcasts).toEqual([]);
    service.onModuleDestroy();
  });

  it('a game prize below 1 000 000 tickets does nothing; at 1 000 000 it is a game-win-ticker in every live', async () => {
    const { service, evals, sets, broadcasts } = setup();
    await service.offerGameWin(win({ tickets: 999_999 }));
    expect(sets).toHaveLength(0);
    expect(evals).toHaveLength(0);
    await service.offerGameWin(win());
    expect(sets[0]!.slice(0, 2)).toEqual(['gift:ticker:game-seen:w1', '1']);
    // D305b: its own lane — its own gate and waiting slot (a gift strip can show at the same time).
    expect(evals[0]!.slice(2, 4)).toEqual(['gift:ticker:game:gate', 'gift:ticker:game:pending']);
    expect(broadcasts.map((b) => b.room)).toEqual(['room-1', 'room-2', 'room-bad', 'room-3']);
    expect(JSON.parse(broadcasts[0]!.payload)).toEqual({
      type: 'game-win-ticker',
      kind: 'GAME_WIN',
      win: {
        id: 'w1',
        game: { code: 'wheel', name: 'Wheel', imageUrl: null },
        winner: expect.objectContaining({ id: 'winner' }),
        tickets: 1_000_000,
        roomId: 'room-1',
        createdAt: '2026-11-07T10:00:00.000Z',
      },
      room: expect.objectContaining({ id: 'room-1', title: 'Evening' }),
    });
  });

  it('a game prize already seen, or of an unknown winner, or not a whole number, makes no strip', async () => {
    const seen = setup({ seen: true });
    await seen.service.offerGameWin(win());
    expect(seen.evals).toHaveLength(0);
    const nobody = setup({ winner: false });
    await nobody.service.offerGameWin(win());
    expect(nobody.broadcasts).toEqual([]);
    const odd = setup();
    await odd.service.offerGameWin(win({ tickets: 1_000_000.5 }));
    expect(odd.sets).toHaveLength(0);
  });

  it('a game prize without a live: room null, every LIVE room (no origin first)', async () => {
    const { service, broadcasts, findMany } = setup();
    await service.offerGameWin(win({ roomId: null }));
    expect(findMany).toHaveBeenCalledWith(expect.objectContaining({ where: { status: 'LIVE' } }));
    expect(broadcasts.map((b) => b.room)).toEqual(['room-2', 'room-bad', 'room-3']);
    expect(JSON.parse(broadcasts[0]!.payload)).toMatchObject({ room: null, win: { roomId: null } });
  });

  it('flush: a waiting entry of either kind, and a bare gift kept by an older API, are told', async () => {
    const game = setup({ pending: `1|${JSON.stringify({ kind: 'GAME_WIN', win: win() })}` });
    await game.service.flush('GAME_WIN');
    expect(game.evals[0]!.slice(2, 4)).toEqual(['gift:ticker:game:gate', 'gift:ticker:game:pending']);
    expect(JSON.parse(game.broadcasts[0]!.payload)).toMatchObject({ type: 'game-win-ticker' });
    const old = setup({ pending: `1|${JSON.stringify(gift(700_000))}` });
    await old.service.flush();
    expect(JSON.parse(old.broadcasts[0]!.payload)).toMatchObject({ type: 'gift-ticker', kind: 'GIFT' });
  });

  it("the panel's thresholds win over the configuration (cached 30 s); invalid values fall back", async () => {
    const { service, evals, prisma } = setup({ panel: { giftMinCoins: 1_000, gameMinTickets: 50 } });
    expect(await service.thresholds()).toEqual({ giftMinCoins: 1_000, gameMinTickets: 50 });
    await service.offer(gift(1_000));
    expect(evals).toHaveLength(1);
    await service.offerGameWin(win({ tickets: 50 }));
    expect(evals).toHaveLength(2);
    // One read for all of them (the cache).
    expect(vi.mocked(prisma.siteSetting.findUnique)).toHaveBeenCalledTimes(1);
    const bad = setup({ panel: { giftMinCoins: 0, gameMinTickets: 'x' } });
    expect(await bad.service.thresholds()).toEqual({ giftMinCoins: 500_000, gameMinTickets: 1_000_000 });
  });
});
