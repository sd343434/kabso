import { describe, expect, it } from 'vitest';
import type { PrismaClient } from '../../generated/prisma/client.js';
import {
  endLedgerRetention,
  expireLegalHolds,
  LEGAL_HOLD_REPORT_STATUSES,
  legalHoldDeleteAfter,
  ledgerRetentionCutoff,
} from './account-deletion.js';

/**
 * D193 retention rules (owner 2026-10-31) without a database: the legal hold of reported content ends after
 * REPORT_LEGAL_HOLD_DAYS, the tombstone's ledgers and audit rows after DELETED_LEDGER_RETENTION_DAYS, both measured
 * against the clock the sweeper is given (moved in these tests). The SQL itself is covered by the e2e suite.
 */

const DAY = 86_400_000;
const T0 = new Date('2027-01-10T12:00:00.000Z');

interface FakeHold {
  id: string;
  targetType: string;
  objectKeys: string[];
  deleteAfter: Date;
  reports: number;
}

/** The parts of PrismaClient the hold expiry uses, over an in-memory list. */
function holdsDb(holds: FakeHold[]) {
  const audits: { action: string; targetId: string | null; metadata: unknown }[] = [];
  const tx = {
    legalHold: {
      findUnique: ({ where }: { where: { id: string } }) =>
        Promise.resolve(holds.find((h) => h.id === where.id) ?? null),
      delete: ({ where }: { where: { id: string } }) => {
        holds.splice(
          holds.findIndex((h) => h.id === where.id),
          1,
        );
        return Promise.resolve({});
      },
    },
    report: {
      count: ({ where }: { where: { legalHoldId: string } }) =>
        Promise.resolve(holds.find((h) => h.id === where.legalHoldId)?.reports ?? 0),
    },
    auditLog: {
      create: ({ data }: { data: { action: string; targetId: string | null; metadata: unknown } }) => {
        audits.push(data);
        return Promise.resolve({});
      },
    },
  };
  const db = {
    ...tx,
    legalHold: {
      ...tx.legalHold,
      findMany: ({ where }: { where: { deleteAfter: { lte: Date } } }) =>
        Promise.resolve(
          holds
            .filter((h) => h.deleteAfter <= where.deleteAfter.lte)
            .sort((a, b) => a.deleteAfter.getTime() - b.deleteAfter.getTime())
            .map((h) => ({ id: h.id })),
        ),
    },
    $transaction: <T>(fn: (t: typeof tx) => Promise<T>) => fn(tx),
  };
  return { db: db as unknown as PrismaClient, audits };
}

describe('D193 retention periods', () => {
  it('a hold made at the purge ends after the configured days; the ledgers 2557 days (7 years) after it', () => {
    expect(legalHoldDeleteAfter(T0, 90).getTime() - T0.getTime()).toBe(90 * DAY);
    expect(T0.getTime() - ledgerRetentionCutoff(T0, 2557).getTime()).toBe(2557 * DAY);
    // 2557 days cover 7 calendar years including two leap days.
    expect(ledgerRetentionCutoff(new Date('2034-01-10T12:00:00.000Z'), 2557).toISOString()).toBe(
      '2027-01-10T12:00:00.000Z',
    );
    expect(LEGAL_HOLD_REPORT_STATUSES).toEqual(['OPEN', 'ACTIONED']);
  });
});

describe('expireLegalHolds', () => {
  const hold = (id: string, deleteAfter: Date, keys: string[] = []): FakeHold => ({
    id,
    targetType: 'POST',
    objectKeys: keys,
    deleteAfter,
    reports: 2,
  });

  it('keeps a hold until its delete_after, then deletes it, audits it and deletes its files after the commit', async () => {
    const at = legalHoldDeleteAfter(T0, 90);
    const holds = [hold('h1', at, ['media/a/large.webp', 'media/a/thumb.webp']), hold('h2', at)];
    const { db, audits } = holdsDb(holds);
    const deleted: string[][] = [];
    const del = (keys: string[]) => {
      deleted.push(keys);
      return Promise.resolve();
    };

    expect(await expireLegalHolds(db, new Date(at.getTime() - 60_000), del)).toBe(0);
    expect(holds).toHaveLength(2);
    expect(deleted).toEqual([]);

    expect(await expireLegalHolds(db, new Date(at.getTime() + 60_000), del)).toBe(2);
    expect(holds).toHaveLength(0);
    expect(deleted).toEqual([['media/a/large.webp', 'media/a/thumb.webp']]); // h2 had no files
    expect(audits.map((a) => [a.action, a.targetId])).toEqual([
      ['account.deletion.hold_expired', 'h1'],
      ['account.deletion.hold_expired', 'h2'],
    ]);
    expect(audits[0]!.metadata).toEqual({ via: 'sweeper', heldType: 'POST', reports: 2, objects: 2 });
    // Idempotent.
    expect(await expireLegalHolds(db, new Date(at.getTime() + 120_000), del)).toBe(0);
  });

  it('leaves a hold whose period was extended between the listing and its transaction', async () => {
    const at = legalHoldDeleteAfter(T0, 90);
    const holds = [hold('h1', at)];
    const { db } = holdsDb(holds);
    const fake = db as unknown as { legalHold: { findMany: () => Promise<{ id: string }[]> } };
    fake.legalHold.findMany = () => {
      holds[0]!.deleteAfter = new Date(at.getTime() + 30 * DAY); // extended right after the listing
      return Promise.resolve([{ id: 'h1' }]);
    };
    expect(await expireLegalHolds(db, at, () => Promise.resolve())).toBe(0);
    expect(holds).toHaveLength(1);
  });
});

describe('endLedgerRetention', () => {
  /** Records the statements the retention end issues for each tombstone. */
  function retentionDb(requests: { userId: string; purgedAt: Date }[], statuses: Record<string, string>) {
    const calls: string[] = [];
    const audits: unknown[] = [];
    const tx = {
      $queryRaw: (strings: TemplateStringsArray, ...values: unknown[]) => {
        const sql = strings.join('?');
        if (sql.includes('FOR UPDATE')) return Promise.resolve([{ status: statuses[values[0] as string] }]);
        calls.push(`fn ${String(values[0])} ${(values[1] as Date).toISOString()}`);
        return Promise.resolve([{ n: 3 }]);
      },
      cherryWithdrawal: {
        updateMany: (a: { where: { userId: string }; data: unknown }) => {
          calls.push(`withdrawals ${a.where.userId} ${JSON.stringify(a.data)}`);
          return Promise.resolve({ count: 1 });
        },
      },
      luckyGiftAgeConfirmation: {
        deleteMany: (a: { where: { userId: string } }) => {
          calls.push(`age ${a.where.userId}`);
          return Promise.resolve({ count: 1 });
        },
      },
      // D198: consent records end with the trail.
      userConsent: {
        deleteMany: (a: { where: { userId: string } }) => {
          calls.push(`consents ${a.where.userId}`);
          return Promise.resolve({ count: 1 });
        },
      },
      // v1.72-social (D208): the team's balance adjustments lose their reason text.
      adminBalanceAdjustment: {
        updateMany: (a: { where: { userId: string }; data: unknown }) => {
          calls.push(`adjustments ${a.where.userId} ${JSON.stringify(a.data)}`);
          return Promise.resolve({ count: 0 });
        },
      },
      accountDeletionRequest: {
        deleteMany: (a: { where: { userId: string } }) => {
          calls.push(`requests ${a.where.userId}`);
          return Promise.resolve({ count: 1 });
        },
      },
    };
    const db = {
      accountDeletionRequest: {
        findMany: ({ where }: { where: { purgedAt: { lte: Date } } }) =>
          Promise.resolve(
            requests.filter((r) => r.purgedAt <= where.purgedAt.lte).map((r) => ({ userId: r.userId })),
          ),
      },
      auditLog: {
        create: ({ data }: { data: unknown }) => {
          audits.push(data);
          return Promise.resolve({});
        },
      },
      $transaction: <T>(fn: (t: typeof tx) => Promise<T>) => fn(tx),
    };
    return { db: db as unknown as PrismaClient, calls, audits };
  }

  it('waits the full retention after the purge, then deletes the trail and anonymises the withdrawals', async () => {
    const { db, calls, audits } = retentionDb(
      [
        { userId: 'tomb-1', purgedAt: T0 },
        { userId: 'tomb-1', purgedAt: T0 }, // two rows of one tombstone: handled once
        { userId: 'tomb-2', purgedAt: new Date(T0.getTime() + 10 * DAY) },
      ],
      { 'tomb-1': 'DELETED', 'tomb-2': 'DELETED' },
    );
    expect(await endLedgerRetention(db, new Date(T0.getTime() + 2556 * DAY), 2557)).toBe(0);
    expect(calls).toEqual([]);
    expect(audits).toEqual([]);

    const now = new Date(T0.getTime() + 2557 * DAY + 60_000);
    expect(await endLedgerRetention(db, now, 2557)).toBe(1);
    expect(calls).toEqual([
      `fn tomb-1 ${ledgerRetentionCutoff(now, 2557).toISOString()}`,
      'withdrawals tomb-1 {"payoutDetails":"…","decisionNote":null}',
      'age tomb-1',
      'consents tomb-1',
      'adjustments tomb-1 {"reason":"…"}',
      'requests tomb-1',
    ]);
    expect(audits).toEqual([
      {
        action: 'account.deletion.retention_ended',
        actorUserId: null,
        metadata: { via: 'sweeper', tombstones: 1, retentionDays: 2557 },
      },
    ]);
  });

  it('skips an account that is not a tombstone', async () => {
    const { db, calls } = retentionDb([{ userId: 'u', purgedAt: T0 }], { u: 'ACTIVE' });
    expect(await endLedgerRetention(db, new Date(T0.getTime() + 3000 * DAY), 2557)).toBe(0);
    expect(calls).toEqual([]);
  });
});
