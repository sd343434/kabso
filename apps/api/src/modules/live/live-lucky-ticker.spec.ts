import { describe, expect, it, vi } from 'vitest';
import type { BackgroundTasks } from '../../common/background/background-tasks.js';
import type { AppConfig } from '../../config/app-config.js';
import type { PrismaService } from '../../prisma/prisma.service.js';
import { LiveLuckyTickerService, tickerRank, type LuckyWinDto } from './live-lucky-ticker.service.js';
import type { LiveMediaProvider } from './media/live-media.provider.js';

/** v1.111-live (D347, CONVENTIONS §10.146): the global lucky banner «شريط المردود في كل اللايفات». */

const person = (id: string) => ({
  id,
  profile: { username: `u_${id}`, displayName: `Name ${id}`, avatarUrl: null },
});

const win = (multiplier: number, coinsWon = multiplier * 10): LuckyWinDto => ({
  giftId: `g-${multiplier}`,
  roomId: 'room-1',
  giftCode: 'clover',
  sender: { id: 's', username: 'u_s', displayName: 'Sender', avatarUrl: null },
  multiplier,
  coinsWon,
  createdAt: '2026-11-09T12:00:00.000Z',
});
const art = { code: 'clover', assetKey: 'gift_clover', imageUrl: 'https://media.example/clover.webp' };

function setup(
  opts: { reply?: unknown; pending?: string; status?: string; gapMs?: number; panel?: unknown } = {},
) {
  const evals: unknown[][] = [];
  const redis = {
    eval: vi.fn(async (...args: unknown[]) => {
      evals.push(args);
      if (opts.pending !== undefined) return ['go', opts.pending];
      return opts.reply ?? ['now', 0];
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
      findUnique: vi.fn(async () => ({
        id: 'room-1',
        title: 'Evening',
        status: opts.status ?? 'LIVE',
        mode: 'AUDIO',
        host: person('host'),
      })),
      findMany,
    },
    // v1.111-live (D347): the OWNER's set and gap (the panel), else the configuration below.
    siteSetting: {
      findUnique: vi.fn(async () =>
        opts.panel === undefined ? null : { key: 'globalStrips', value: opts.panel },
      ),
    },
  } as unknown as PrismaService;
  const config = {
    live: { giftTickerMinCoins: 500_000, gameWinTickerMinTickets: 1_000_000 },
    lucky: {
      chatMinMultiplier: 250,
      globalBannerMultipliers: [250, 500, 1000],
      globalBannerGapMs: opts.gapMs ?? 10_000,
      table: { outcomes: [5, 10, 25, 50, 100, 250, 500, 1000].map((multiplier) => ({ multiplier })) },
    },
  } as unknown as AppConfig;
  const background = { run: vi.fn() } as unknown as BackgroundTasks;
  const service = new LiveLuckyTickerService(prisma, redis as never, media, config, background);
  return { service, evals, broadcasts, findMany, prisma };
}

describe('the global banner set (D347)', () => {
  it('default ×250 ×500 ×1000: smaller wins stay in their room (no Redis, no send)', async () => {
    for (const m of [5, 10, 25, 50, 100]) {
      const { service, evals, broadcasts } = setup();
      await service.offer(win(m), art);
      expect(evals, String(m)).toEqual([]);
      expect(broadcasts).toEqual([]);
    }
    for (const m of [250, 500, 1000]) {
      const { service, broadcasts } = setup();
      await service.offer(win(m), art);
      expect(broadcasts, String(m)).toHaveLength(3);
    }
  });

  it("the panel's set and gap win (a set, not a threshold); an invalid stored value falls back to the configuration", async () => {
    const panel = setup({
      panel: {
        giftMinCoins: 1,
        gameMinTickets: 1,
        luckyGlobalMultipliers: [1000, 100],
        luckyGlobalGapSeconds: 3,
      },
    });
    expect(await panel.service.settings()).toEqual({ multipliers: [100, 1000], gapMs: 3_000 });
    await panel.service.offer(win(250), art);
    expect(panel.evals).toEqual([]);
    await panel.service.offer(win(100), art);
    expect(panel.evals[0]![6]).toBe('3000');

    const bad = setup({ panel: { luckyGlobalMultipliers: [250, 300], luckyGlobalGapSeconds: 0 } });
    expect(await bad.service.settings()).toEqual({ multipliers: [250, 500, 1000], gapMs: 10_000 });
    const dup = setup({ panel: { luckyGlobalMultipliers: [500, 500] } });
    expect((await dup.service.settings()).multipliers).toEqual([250, 500, 1000]);
  });

  it('the settings are read once per 30 s (cached), and again after forgetSettings()', async () => {
    const { service, prisma } = setup();
    await service.settings();
    await service.settings();
    const read = (prisma as unknown as { siteSetting: { findUnique: ReturnType<typeof vi.fn> } }).siteSetting
      .findUnique;
    expect(read).toHaveBeenCalledTimes(1);
    service.forgetSettings();
    await service.settings();
    expect(read).toHaveBeenCalledTimes(2);
  });
});

describe('LiveLuckyTickerService (D148, D347)', () => {
  it('fans out to every other LIVE room (newest first, bounded), never the origin, with the gift art and the mode', async () => {
    const { service, broadcasts, findMany } = setup();
    await service.offer(win(500), art);
    expect(findMany).toHaveBeenCalledWith({
      where: { status: 'LIVE', id: { not: 'room-1' } },
      select: { id: true },
      orderBy: { startedAt: 'desc' },
      take: 5_000,
    });
    // A failing room does not stop the others.
    expect(broadcasts.map((b) => b.room)).toEqual(['room-2', 'room-bad', 'room-3']);
    expect(broadcasts.every((b) => b.topic === 'lucky')).toBe(true);
    expect(JSON.parse(broadcasts[0]!.payload)).toEqual({
      type: 'lucky-ticker',
      win: win(500),
      gift: art,
      room: {
        id: 'room-1',
        title: 'Evening',
        mode: 'AUDIO',
        host: { id: 'host', username: 'u_host', displayName: 'Name host', avatarUrl: null },
      },
    });
  });

  it('uses the configured gap for the Redis gate (one per gap for the whole service, so per room)', async () => {
    const { service, evals } = setup({ gapMs: 4_000 });
    await service.offer(win(250), art);
    const args = evals[0]!;
    expect(args[2]).toBe('lucky:ticker:gate');
    expect(args[3]).toBe('lucky:ticker:pending');
    expect(JSON.parse(args[4] as string)).toEqual({ win: win(250), gift: art });
    expect(args[5]).toBe(String(tickerRank(win(250))));
    expect(args[6]).toBe('4000');
    expect(args[7]).toBe('30000');
  });

  it('inside the gap: nothing is sent now (it waits, or is dropped by the script)', async () => {
    const { service, broadcasts } = setup({ reply: ['wait', 5_000] });
    await service.offer(win(1000), art);
    expect(broadcasts).toEqual([]);
    service.onModuleDestroy();
  });

  it('a waiting win whose live ended before its turn is dropped (its tap would lead nowhere)', async () => {
    const pending = `${tickerRank(win(1000))}|${JSON.stringify({ win: win(1000), gift: art })}`;
    const ended = setup({ pending, status: 'ENDED' });
    await ended.service.flush();
    expect(ended.broadcasts).toEqual([]);
    expect(ended.findMany).not.toHaveBeenCalled();

    const live = setup({ pending });
    await live.service.flush();
    expect(live.broadcasts).toHaveLength(3);
    expect(JSON.parse(live.broadcasts[0]!.payload).win.multiplier).toBe(1000);
  });

  it('the rank puts a bigger multiplier first, then more coins', () => {
    expect(tickerRank(win(1000, 10))).toBeGreaterThan(tickerRank(win(500, 9_999_999)));
    expect(tickerRank(win(500, 6_000))).toBeGreaterThan(tickerRank(win(500, 5_000)));
  });

  it('Redis down: no banner, never a throw', async () => {
    const { service, broadcasts } = setup();
    (service as unknown as { redis: { eval: () => Promise<never> } }).redis.eval = async () => {
      throw new Error('redis down');
    };
    await expect(service.offer(win(250), art)).resolves.toBeUndefined();
    expect(broadcasts).toEqual([]);
  });
});
