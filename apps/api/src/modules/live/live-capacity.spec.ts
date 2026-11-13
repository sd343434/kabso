import type { Redis } from 'ioredis';
import { describe, expect, it, vi } from 'vitest';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { loadConfig } from '../../config/app-config.js';
import type { Prisma } from '../../generated/prisma/client.js';
import {
  capacityExceeded,
  capacityWeightOf,
  LiveCapacityGuard,
  refusalsKey,
  type CapacityMode,
} from './live-capacity.js';

const BASE = {
  DATABASE_URL: 'postgresql://u:p@localhost:5432/db',
  REDIS_URL: 'redis://localhost:6379',
  JWT_ACCESS_SECRET: 'x'.repeat(32),
  APP_PUBLIC_URL: 'http://localhost:3000',
};
const HOST = '0192f1d0-1111-7aaa-8bbb-0c0d0e0f1011';
const NOW = new Date('2026-11-10T21:30:00.000Z');
const CUTOFF = new Date(NOW.getTime() - 45_000);

function guard(env: Record<string, string> = {}) {
  const config = loadConfig({ ...BASE, ...env });
  const exec = vi.fn(() => Promise.resolve([[null, 1]]));
  const multi = { incr: vi.fn(), expire: vi.fn(), exec };
  multi.incr.mockReturnValue(multi);
  multi.expire.mockReturnValue(multi);
  const redis = { multi: vi.fn(() => multi), get: vi.fn(() => Promise.resolve('7')) };
  return { guard: new LiveCapacityGuard(config, redis as unknown as Redis), redis, multi, config };
}

function tx(row: { used: number; rooms: number; mine: boolean } | undefined) {
  const statements: string[] = [];
  const text = (parts: TemplateStringsArray) => parts.join('?');
  const client = {
    $executeRaw: vi.fn((parts: TemplateStringsArray) => {
      statements.push(text(parts));
      return Promise.resolve(1);
    }),
    $queryRaw: vi.fn((parts: TemplateStringsArray) => {
      statements.push(text(parts));
      return Promise.resolve(row ? [row] : []);
    }),
  };
  return { tx: client as unknown as Prisma.TransactionClient, statements, client };
}

async function refusal(promise: Promise<unknown>): Promise<AppException> {
  try {
    await promise;
  } catch (err) {
    if (err instanceof AppException) return err;
    throw err;
  }
  throw new Error('expected LIVE_CAPACITY_FULL');
}

describe('capacity config (D351)', () => {
  it('is off by default with the documented defaults', () => {
    expect(loadConfig(BASE).live.capacity).toEqual({
      maxRooms: 0,
      videoWeightPercent: 100,
      audioWeightPercent: 25,
      retryAfterSeconds: 60,
      bypassUserIds: [],
    });
  });

  it('reads the settings and refuses bad values', () => {
    const c = loadConfig({
      ...BASE,
      LIVE_CAPACITY_MAX_ROOMS: '120',
      LIVE_CAPACITY_WEIGHT_VIDEO_PERCENT: '150',
      LIVE_CAPACITY_WEIGHT_AUDIO_PERCENT: '20',
      LIVE_CAPACITY_RETRY_AFTER_SECONDS: '90',
      LIVE_CAPACITY_BYPASS_USER_IDS: ` ${HOST.toUpperCase()} , ${HOST}`,
    }).live.capacity;
    expect(c).toEqual({
      maxRooms: 120,
      videoWeightPercent: 150,
      audioWeightPercent: 20,
      retryAfterSeconds: 90,
      bypassUserIds: [HOST],
    });
    for (const [key, value] of [
      ['LIVE_CAPACITY_MAX_ROOMS', '-1'],
      ['LIVE_CAPACITY_MAX_ROOMS', '1e3'],
      ['LIVE_CAPACITY_MAX_ROOMS', '100001'],
      ['LIVE_CAPACITY_WEIGHT_VIDEO_PERCENT', '0'],
      ['LIVE_CAPACITY_WEIGHT_AUDIO_PERCENT', '1001'],
      ['LIVE_CAPACITY_RETRY_AFTER_SECONDS', '0'],
      ['LIVE_CAPACITY_BYPASS_USER_IDS', 'owner'],
      ['LIVE_CAPACITY_BYPASS_USER_IDS', `${HOST},`],
    ] as const) {
      expect(() => loadConfig({ ...BASE, [key]: value }), `${key}=${value}`).toThrow(key);
    }
  });
});

describe('capacity arithmetic (D351)', () => {
  const capacity = loadConfig(BASE).live.capacity;

  it('weighs video modes as the video weight and audio / podcast as the audio weight', () => {
    for (const mode of ['SOLO', 'PK', 'MULTI', 'STREAMER'] as CapacityMode[]) {
      expect(capacityWeightOf(mode, capacity), mode).toBe(100);
    }
    expect(capacityWeightOf('AUDIO', capacity)).toBe(25);
    expect(capacityWeightOf('PODCAST', capacity)).toBe(25);
  });

  it('weighs a video podcast as a video room (D363) and an audio podcast as before', () => {
    expect(capacityWeightOf('PODCAST', capacity, true)).toBe(100);
    expect(capacityWeightOf('PODCAST', capacity, false)).toBe(25);
    // The flag only means something for a PODCAST.
    expect(capacityWeightOf('AUDIO', capacity, true)).toBe(25);
    expect(capacityWeightOf('SOLO', capacity, true)).toBe(100);
  });

  it('refuses exactly when the new room no longer fits («≥ the limit» for video rooms)', () => {
    expect(capacityExceeded(0, 100, 1)).toBe(false);
    expect(capacityExceeded(100, 100, 1)).toBe(true);
    expect(capacityExceeded(200, 100, 3)).toBe(false);
    expect(capacityExceeded(300, 100, 3)).toBe(true);
    // 3 video + 3 audio rooms use 375 of 400: one more audio room fits, a video room does not.
    expect(capacityExceeded(375, 25, 4)).toBe(false);
    expect(capacityExceeded(375, 100, 4)).toBe(true);
  });

  it('counts refusals per UTC day', () => {
    expect(refusalsKey(NOW)).toBe('live:capacity:refused:2026-11-10');
    expect(refusalsKey(new Date('2026-11-10T23:59:59.999+00:00'))).toBe('live:capacity:refused:2026-11-10');
  });
});

describe('LiveCapacityGuard.assertFits (D351)', () => {
  it('does nothing while off: no lock, no count', async () => {
    const { guard: g } = guard();
    const t = tx({ used: 999_900, rooms: 9_999, mine: false });
    await g.assertFits(t.tx, HOST, 'SOLO', CUTOFF, NOW);
    expect(t.statements).toEqual([]);
    expect(g.enabled).toBe(false);
  });

  it('takes the advisory lock, then counts the fresh LIVE rooms; passes while the room fits', async () => {
    const { guard: g, redis } = guard({ LIVE_CAPACITY_MAX_ROOMS: '2' });
    const t = tx({ used: 100, rooms: 1, mine: false });
    await g.assertFits(t.tx, HOST, 'SOLO', CUTOFF, NOW);
    expect(t.statements).toHaveLength(2);
    expect(t.statements[0]).toContain('pg_advisory_xact_lock');
    expect(t.statements[1]).toContain("status = 'LIVE' AND last_heartbeat_at >");
    expect(t.client.$queryRaw.mock.calls[0]).toContain(CUTOFF.toISOString());
    expect(redis.multi).not.toHaveBeenCalled();
  });

  it('refuses with 503 LIVE_CAPACITY_FULL + Retry-After and counts the refusal', async () => {
    const { guard: g, multi } = guard({
      LIVE_CAPACITY_MAX_ROOMS: '2',
      LIVE_CAPACITY_RETRY_AFTER_SECONDS: '75',
    });
    const err = await refusal(
      g.assertFits(tx({ used: 200, rooms: 2, mine: false }).tx, HOST, 'MULTI', CUTOFF, NOW),
    );
    expect(err.code).toBe(ErrorCode.LIVE_CAPACITY_FULL);
    expect(err.status).toBe(503);
    expect(err.headers).toEqual({ 'Retry-After': '75' });
    expect(multi.incr).toHaveBeenCalledWith('live:capacity:refused:2026-11-10');
    expect(multi.expire).toHaveBeenCalledWith('live:capacity:refused:2026-11-10', 8 * 86_400);
    expect(g.refusalsSinceStart).toBe(1);
  });

  it('lets a lighter audio room in where a video room is refused', async () => {
    const { guard: g } = guard({ LIVE_CAPACITY_MAX_ROOMS: '2' });
    await g.assertFits(tx({ used: 150, rooms: 3, mine: false }).tx, HOST, 'AUDIO', CUTOFF, NOW);
    await g.assertFits(tx({ used: 150, rooms: 3, mine: false }).tx, HOST, 'PODCAST', CUTOFF, NOW);
    await expect(
      g.assertFits(tx({ used: 150, rooms: 3, mine: false }).tx, HOST, 'STREAMER', CUTOFF, NOW),
    ).rejects.toThrow(AppException);
  });

  it('refuses a video podcast where an audio podcast still fits, and counts video podcasts as video (D363)', async () => {
    const { guard: g } = guard({ LIVE_CAPACITY_MAX_ROOMS: '2' });
    await g.assertFits(tx({ used: 150, rooms: 3, mine: false }).tx, HOST, 'PODCAST', CUTOFF, NOW, false);
    await expect(
      g.assertFits(tx({ used: 150, rooms: 3, mine: false }).tx, HOST, 'PODCAST', CUTOFF, NOW, true),
    ).rejects.toThrow(AppException);
    const t = tx({ used: 0, rooms: 0, mine: false });
    await g.assertFits(t.tx, HOST, 'SOLO', CUTOFF, NOW);
    expect(t.statements[1]).toContain('NOT podcast_video');
  });

  it('leaves a caller who is already live to the 409 of the insert', async () => {
    const { guard: g } = guard({ LIVE_CAPACITY_MAX_ROOMS: '1' });
    await g.assertFits(tx({ used: 100, rooms: 1, mine: true }).tx, HOST, 'SOLO', CUTOFF, NOW);
  });

  it('never refuses a bypass user (no lock taken)', async () => {
    const { guard: g } = guard({
      LIVE_CAPACITY_MAX_ROOMS: '1',
      LIVE_CAPACITY_BYPASS_USER_IDS: HOST.toUpperCase(),
    });
    const t = tx({ used: 500, rooms: 5, mine: false });
    await g.assertFits(t.tx, HOST, 'SOLO', CUTOFF, NOW);
    expect(t.statements).toEqual([]);
  });

  it('still refuses when Redis cannot count the refusal', async () => {
    const { guard: g, multi } = guard({ LIVE_CAPACITY_MAX_ROOMS: '1' });
    multi.exec.mockReturnValueOnce(Promise.reject(new Error('redis down')));
    const err = await refusal(
      g.assertFits(tx({ used: 100, rooms: 1, mine: false }).tx, HOST, 'SOLO', CUTOFF, NOW),
    );
    expect(err.code).toBe(ErrorCode.LIVE_CAPACITY_FULL);
  });

  it('reads today’s refusals (null when Redis does not answer)', async () => {
    const { guard: g, redis } = guard();
    expect(await g.refusalsToday(NOW)).toBe(7);
    redis.get.mockReturnValueOnce(Promise.resolve(null as unknown as string));
    expect(await g.refusalsToday(NOW)).toBe(0);
    redis.get.mockReturnValueOnce(Promise.reject(new Error('down')));
    expect(await g.refusalsToday(NOW)).toBeNull();
  });
});
