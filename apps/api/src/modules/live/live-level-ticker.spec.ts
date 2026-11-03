import { describe, expect, it, vi } from 'vitest';
import type { BackgroundTasks } from '../../common/background/background-tasks.js';
import type { PrismaService } from '../../prisma/prisma.service.js';
import {
  LEVEL_TICKER_GAP_MS,
  LEVEL_TICKER_TOPIC,
  LiveLevelTickerService,
  type LevelUpOffer,
} from './live-level-ticker.service.js';
import type { LiveMediaProvider } from './media/live-media.provider.js';

const person = (id: string) => ({
  id,
  profile: { username: `u_${id}`, displayName: `Name ${id}`, avatarUrl: null },
});

function setup(opts: { minLevel?: unknown; reply?: unknown; status?: string; evalFails?: boolean } = {}) {
  const evals: unknown[][] = [];
  const redis = {
    eval: vi.fn(async (...args: unknown[]) => {
      evals.push(args);
      if (opts.evalFails) throw new Error('redis down');
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
  const prisma = {
    siteSetting: {
      findUnique: async () =>
        opts.minLevel === undefined ? null : { key: 'levelTickerMinLevel', value: opts.minLevel },
    },
    liveRoom: {
      findUnique: async () => ({
        id: 'room-1',
        title: 'Evening',
        status: opts.status ?? 'LIVE',
        host: person('host'),
      }),
      findMany: async () => [{ id: 'room-2' }, { id: 'room-bad' }, { id: 'room-3' }],
    },
    user: { findUnique: async () => person('sender') },
  } as unknown as PrismaService;
  const background = { run: vi.fn() } as unknown as BackgroundTasks;
  const service = new LiveLevelTickerService(prisma, redis as never, media, background);
  return { service, evals, broadcasts, redis };
}

const offer = (over: Partial<LevelUpOffer> = {}): LevelUpOffer => ({
  sourceId: 'gift:g1',
  userId: 'sender',
  category: 'SUPPORT',
  previousLevel: 29,
  level: 30,
  roomId: 'room-1',
  createdAt: '2026-11-03T10:00:00.000Z',
  ...over,
});

describe('D254 level ticker', () => {
  it('a level-up to the default threshold (30) is told to every LIVE room, its own first', async () => {
    const { service, evals, broadcasts } = setup();
    await service.offerAll([offer()]);
    expect(evals).toHaveLength(1);
    // The seen key is per person, level system and level; the gap is the 8 s one.
    expect(evals[0]!.slice(1, 5)).toEqual([
      3,
      'level:ticker:gate',
      'level:ticker:pending',
      'level:ticker:seen:sender:SUPPORT:30',
    ]);
    expect(evals[0]![6]).toBe(String(LEVEL_TICKER_GAP_MS));
    expect(broadcasts.map((b) => b.room)).toEqual(['room-1', 'room-2', 'room-bad', 'room-3']);
    expect(new Set(broadcasts.map((b) => b.topic))).toEqual(new Set([LEVEL_TICKER_TOPIC]));
    expect(JSON.parse(broadcasts[0]!.payload)).toEqual({
      type: 'level-ticker',
      levelUp: {
        id: 'sender:SUPPORT:30',
        user: expect.objectContaining({ id: 'sender', displayName: 'Name sender' }),
        category: 'SUPPORT',
        level: 30,
        previousLevel: 29,
        roomId: 'room-1',
        createdAt: '2026-11-03T10:00:00.000Z',
      },
      room: { id: 'room-1', title: 'Evening', host: expect.objectContaining({ id: 'host' }) },
    });
  });

  it('below the threshold, or not a rise, nothing is offered', async () => {
    const { service, evals } = setup();
    await service.offerAll([
      offer({ previousLevel: 28, level: 29 }),
      offer({ previousLevel: 31, level: 31 }),
      offer({ category: 'ATTRACTIVENESS', previousLevel: 1, level: 12 }),
    ]);
    expect(evals).toHaveLength(0);
  });

  it('the panel threshold applies (here 12); a stored value out of bounds reads as 30', async () => {
    const low = setup({ minLevel: 12 });
    await low.service.offerAll([offer({ category: 'ATTRACTIVENESS', previousLevel: 11, level: 12 })]);
    expect(low.evals).toHaveLength(1);
    const bad = setup({ minLevel: 500 });
    await bad.service.offerAll([offer({ previousLevel: 11, level: 12 })]);
    expect(bad.evals).toHaveLength(0);
  });

  it('already announced, waiting or full: nothing is sent now; an ended live is not announced', async () => {
    for (const reply of [
      ['seen', 0],
      ['wait', 5_000],
      ['full', 5_000],
    ]) {
      const { service, broadcasts } = setup({ reply });
      await service.offerAll([offer()]);
      expect(broadcasts, JSON.stringify(reply)).toEqual([]);
      service.onModuleDestroy();
    }
    const ended = setup({ status: 'ENDED' });
    await ended.service.offerAll([offer()]);
    expect(ended.broadcasts).toEqual([]);
  });

  it('best effort: Redis down never throws', async () => {
    const { service, broadcasts } = setup({ evalFails: true });
    await expect(service.offerAll([offer()])).resolves.toBeUndefined();
    expect(broadcasts).toEqual([]);
  });
});
