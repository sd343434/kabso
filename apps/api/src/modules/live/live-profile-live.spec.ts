import { describe, expect, it, vi } from 'vitest';
import type { StorageSettingsStore } from '../storage-settings/storage-settings.store.js';
import type { AuditService } from '../../common/audit/audit.service.js';
import { Clock } from '../../common/time/clock.js';
import { loadConfig } from '../../config/app-config.js';
import { Prisma } from '../../generated/prisma/client.js';
import type { PrismaService } from '../../prisma/prisma.service.js';
import type { UsersService } from '../users/users.service.js';
import type { LiveCategoriesService } from './live-categories.service.js';
import type { LiveRankingsService } from './live-rankings.service.js';
import type { LiveScheduleService } from './live-schedule.service.js';
import type { LiveCapacityGuard } from './live-capacity.js';
import { LiveRoomsService } from './live-rooms.service.js';

const NOW = new Date('2026-11-05T20:20:00.000Z');

class FixedClock extends Clock {
  now(): Date {
    return NOW;
  }
}

interface Row {
  id: string;
  title: string;
  mode: string;
  started_at: Date;
  last_heartbeat_at: Date;
  viewer_count: number;
  score: bigint;
  visible: boolean;
}

function service(rows: Row[]) {
  const statements: string[] = [];
  const transactions = vi.fn(() => Promise.resolve(1));
  const prisma = {
    $queryRaw: vi.fn((strings: TemplateStringsArray, ...values: unknown[]) => {
      // The nested fragments (Prisma.sql) carry their own text.
      const nested = values.map((v) => (v instanceof Prisma.Sql ? v.sql : '')).join(' ');
      statements.push(`${strings.join('?')} ${nested}`);
      return Promise.resolve(rows);
    }),
    $transaction: transactions,
  };
  const config = loadConfig({
    DATABASE_URL: 'postgresql://u:p@localhost:5432/db',
    REDIS_URL: 'redis://localhost:6379',
    JWT_ACCESS_SECRET: 'x'.repeat(32),
    APP_PUBLIC_URL: 'http://localhost:3000',
    LIVE_HEARTBEAT_STALE_SECONDS: '45',
    LIVE_SWEEP_INTERVAL_SECONDS: '0',
  });
  const rooms = new LiveRoomsService(
    prisma as unknown as PrismaService,
    {} as UsersService,
    {} as LiveCategoriesService,
    {} as AuditService,
    new FixedClock(),
    config,
    {} as LiveRankingsService,
    {} as LiveScheduleService,
    {} as StorageSettingsStore,
    {} as LiveCapacityGuard,
  );
  return { rooms, statements, transactions };
}

const room = (over: Partial<Row> = {}): Row => ({
  id: '0192f1d0-1111-7aaa-8bbb-0c0d0e0f1011',
  title: 'سهرة الجمعة',
  mode: 'SOLO',
  started_at: new Date(NOW.getTime() - 77 * 60_000),
  last_heartbeat_at: new Date(NOW.getTime() - 5_000),
  viewer_count: 93,
  score: 41_900n,
  visible: true,
  ...over,
});

describe('D279 profileLiveOf (PublicProfile.live, §10.5.1)', () => {
  it('a fresh LIVE room: liveRoomId and the card facts (score as a number)', async () => {
    const { rooms, statements } = service([room()]);
    await expect(rooms.profileLiveOf('host', 'viewer')).resolves.toEqual({
      liveRoomId: room().id,
      live: {
        roomId: room().id,
        title: 'سهرة الجمعة',
        mode: 'SOLO',
        startedAt: '2026-11-05T19:03:00.000Z',
        viewerCount: 93,
        score: 41_900,
      },
    });
    // The block rule of the room lists (CP-010) decides `visible`.
    expect(statements[0]).toContain('user_blocks');
    expect(statements[0]).toContain("status = 'LIVE'");
  });

  it('across a block: the ring field stays, the card is null', async () => {
    const { rooms } = service([room({ visible: false })]);
    await expect(rooms.profileLiveOf('host', 'viewer')).resolves.toEqual({
      liveRoomId: room().id,
      live: null,
    });
  });

  it('not live: both null', async () => {
    const { rooms } = service([]);
    await expect(rooms.profileLiveOf('host', 'viewer')).resolves.toEqual({ liveRoomId: null, live: null });
  });

  it('a stale room: both null, and that room is ended', async () => {
    const { rooms, transactions } = service([room({ last_heartbeat_at: new Date(NOW.getTime() - 46_000) })]);
    await expect(rooms.profileLiveOf('host', 'viewer')).resolves.toEqual({ liveRoomId: null, live: null });
    expect(transactions).toHaveBeenCalledTimes(1);
  });
});
