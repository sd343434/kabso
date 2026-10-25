import { describe, expect, it, vi } from 'vitest';
import type { AuditService } from '../../common/audit/audit.service.js';
import { Clock } from '../../common/time/clock.js';
import { loadConfig } from '../../config/app-config.js';
import type { PrismaService } from '../../prisma/prisma.service.js';
import type { UsersService } from '../users/users.service.js';
import type { LiveCategoriesService } from './live-categories.service.js';
import type { LiveRankingsService } from './live-rankings.service.js';
import { errorClassAndCode, LIVE_TX_OPTIONS, LiveRoomsService } from './live-rooms.service.js';

class FixedClock extends Clock {
  now(): Date {
    return new Date('2026-10-16T12:00:00.000Z');
  }
}

/**
 * A fake database holding `stale` stale rooms. Each batch transaction locks up to LIMIT of them
 * (first statement after `statement_timeout`) and ends them (second statement).
 */
function fakeDb(stale: number, onBatch?: () => Promise<void>) {
  let remaining = stale;
  const txOptions: unknown[] = [];
  const statements: string[] = [];
  let nextId = 0;
  const tx = {
    $queryRaw: vi.fn((strings: TemplateStringsArray, ...values: unknown[]) => {
      const sql = strings.join('?');
      statements.push(sql.replace(/\s+/g, ' ').trim().slice(0, 40));
      if (sql.includes('set_config')) return Promise.resolve([]);
      if (sql.includes('FOR UPDATE SKIP LOCKED')) {
        const limit = values.find((v) => typeof v === 'number') as number;
        const n = Math.min(limit, remaining);
        remaining -= n;
        return Promise.resolve(Array.from({ length: n }, () => ({ id: `room-${(nextId += 1)}` })));
      }
      const ids = values.find((v) => Array.isArray(v)) as string[];
      return Promise.resolve(ids.map((id) => ({ id, host_user_id: 'host' })));
    }),
  };
  const prisma = {
    $transaction: vi.fn(async (fn: (t: typeof tx) => Promise<unknown>, options: unknown) => {
      txOptions.push(options);
      await onBatch?.();
      return fn(tx);
    }),
  };
  return { prisma, txOptions, statements, remaining: () => remaining };
}

function service(prisma: unknown, batchSize = 10) {
  const config = loadConfig({
    DATABASE_URL: 'postgresql://u:p@localhost:5432/db',
    REDIS_URL: 'redis://localhost:6379',
    JWT_ACCESS_SECRET: 'x'.repeat(32),
    APP_PUBLIC_URL: 'http://localhost:3000',
    LIVE_SWEEP_BATCH_SIZE: String(batchSize),
    LIVE_SWEEP_INTERVAL_SECONDS: '0',
  });
  const audit = { recordManyIn: vi.fn(() => Promise.resolve()) };
  const rooms = new LiveRoomsService(
    prisma as PrismaService,
    {} as UsersService,
    {} as LiveCategoriesService,
    audit as unknown as AuditService,
    new FixedClock(),
    config,
    {} as LiveRankingsService,
  );
  return { rooms, audit };
}

describe('stale-room sweeper (SEC-035)', () => {
  it('ends rooms in batches of LIVE_SWEEP_BATCH_SIZE, one transaction each, until drained', async () => {
    const db = fakeDb(25);
    const { rooms, audit } = service(db.prisma, 10);
    expect(await rooms.runSweep()).toEqual({ ended: 25, batches: 3, stoppedBy: 'drained' });
    expect(db.prisma.$transaction).toHaveBeenCalledTimes(3);
    expect(db.txOptions).toEqual([LIVE_TX_OPTIONS, LIVE_TX_OPTIONS, LIVE_TX_OPTIONS]);
    expect(audit.recordManyIn.mock.calls.map((call: unknown[]) => (call[1] as unknown[]).length)).toEqual([
      10, 10, 5,
    ]);
    // Every batch sets a statement timeout before its work.
    expect(db.statements.filter((s) => s.includes('set_config'))).toHaveLength(3);
  });

  it('stops at the per-run batch budget and continues on the next run', async () => {
    const db = fakeDb(50);
    const { rooms } = service(db.prisma, 10);
    expect(await rooms.runSweep({ maxBatches: 2 })).toEqual({
      ended: 20,
      batches: 2,
      stoppedBy: 'batch_budget',
    });
    expect(db.remaining()).toBe(30);
    expect(await rooms.runSweep()).toEqual({ ended: 30, batches: 4, stoppedBy: 'drained' });
  });

  it('stops at the per-run time budget', async () => {
    const db = fakeDb(50, () => new Promise((r) => setTimeout(r, 15)));
    const { rooms } = service(db.prisma, 10);
    const result = await rooms.runSweep({ budgetMs: 20 });
    expect(result.stoppedBy).toBe('time_budget');
    expect(result.batches).toBeGreaterThanOrEqual(1);
    expect(result.batches).toBeLessThan(5);
  });

  it('never overlaps runs in one instance', async () => {
    let release!: () => void;
    const gate = new Promise<void>((r) => (release = r));
    const db = fakeDb(5, () => gate);
    const { rooms } = service(db.prisma, 10);
    const first = rooms.runSweep();
    expect(await rooms.runSweep()).toEqual({ ended: 0, batches: 0, stoppedBy: 'already_running' });
    expect(await rooms.sweepStale()).toBe(0);
    release();
    expect(await first).toEqual({ ended: 5, batches: 1, stoppedBy: 'drained' });
    expect(db.prisma.$transaction).toHaveBeenCalledTimes(1);
    // Free again once the run has finished.
    expect((await rooms.runSweep()).stoppedBy).toBe('drained');
  });

  it('stops between batches once the module is being destroyed', async () => {
    const db = fakeDb(100);
    const { rooms } = service(db.prisma, 10);
    await rooms.onModuleDestroy();
    expect(await rooms.runSweep()).toEqual({ ended: 0, batches: 0, stoppedBy: 'stopped' });
  });
});

describe('errorClassAndCode (sweep failure log)', () => {
  it('reports the error class and the Prisma or driver code', () => {
    class PrismaClientKnownRequestError extends Error {
      code = 'P2028';
    }
    expect(errorClassAndCode(new PrismaClientKnownRequestError('Transaction already closed'))).toEqual({
      errorClass: 'PrismaClientKnownRequestError',
      code: 'P2028',
    });
    const driver = Object.assign(new Error('canceling statement due to statement timeout'), {
      cause: { originalCode: '57014' },
    });
    expect(errorClassAndCode(driver)).toEqual({ errorClass: 'Error', code: '57014' });
    expect(errorClassAndCode(new TypeError('x'))).toEqual({ errorClass: 'TypeError', code: null });
    expect(errorClassAndCode('boom')).toEqual({ errorClass: 'string', code: null });
    expect(errorClassAndCode(null)).toEqual({ errorClass: 'null', code: null });
  });
});
