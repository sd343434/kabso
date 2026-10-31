import { describe, expect, it } from 'vitest';
import { csvDocument, csvField } from '../../common/csv/csv.js';
import { CAPABILITIES, capabilitiesOf } from './admin-permissions.js';
import { dayKey, dayWindow, SPARK_DAYS } from './admin-stats.service.js';
import { CSV_MAX_ROWS, dayBound, tableQuery, window } from './admin-tables.js';
import {
  createAgencyBody,
  reportQuery,
  resolveComplaintBody,
  teamGrantBody,
  updateGiftBody,
} from './admin-v2.schemas.js';

/** v1.65-social (D197, CONVENTIONS §10.60): the panel v2's pure rules. */
describe('admin panel v2', () => {
  it('CSV: RFC 4180 quoting and formula neutralising', () => {
    expect(csvField('plain')).toBe('plain');
    expect(csvField('a,b')).toBe('"a,b"');
    expect(csvField('say "hi"')).toBe('"say ""hi"""');
    expect(csvField('=1+1')).toBe("'=1+1");
    expect(csvField('-3')).toBe("'-3");
    expect(csvField('@cmd')).toBe("'@cmd");
    expect(
      csvDocument(
        ['a', 'b'],
        [
          [1, null],
          ['x', true],
        ],
      ),
    ).toBe('a,b\r\n1,\r\nx,true\r\n');
  });

  it('days: Asia/Riyadh keys and a window ending today', () => {
    const now = new Date('2026-10-31T22:30:00Z'); // 01:30 on 1 Nov in Riyadh
    expect(dayKey(now, 'Asia/Riyadh')).toBe('2026-11-01');
    const w = dayWindow(now, 3, 'Asia/Riyadh');
    expect(w.keys).toEqual(['2026-10-30', '2026-10-31', '2026-11-01']);
    expect(w.from.toISOString()).toBe('2026-10-29T21:00:00.000Z');
    expect(dayWindow(now, SPARK_DAYS, 'Asia/Riyadh').keys).toHaveLength(14);
    expect(dayBound('2026-10-31', false, 'Asia/Riyadh')?.toISOString()).toBe('2026-10-30T21:00:00.000Z');
    expect(dayBound('2026-10-31', true, 'Asia/Riyadh')?.toISOString()).toBe('2026-10-31T21:00:00.000Z');
    expect(dayBound(undefined, true, 'Asia/Riyadh')).toBeUndefined();
  });

  it('tables: whitelisted sort, bounded pages, CSV takes every row up to the cap', () => {
    const q = tableQuery(['createdAt', 'username'], 'createdAt');
    expect(q.parse({})).toMatchObject({
      page: 1,
      pageSize: 25,
      sort: 'createdAt',
      order: 'desc',
      format: 'json',
    });
    expect(q.safeParse({ sort: 'password' }).success).toBe(false);
    expect(q.safeParse({ pageSize: '500' }).success).toBe(false);
    const p = q.parse({ page: '3', pageSize: '10' });
    expect(window(p)).toEqual({ skip: 20, take: 10 });
    expect(window(q.parse({ page: '3', format: 'csv' }))).toEqual({ skip: 0, take: CSV_MAX_ROWS });
  });

  it('bodies: a reason everywhere, TOTP for the team, coherent choices', () => {
    expect(createAgencyBody.safeParse({ ownerEmail: 'a@b.c', reason: 'x' }).success).toBe(true);
    expect(createAgencyBody.safeParse({ ownerEmail: 'a@b.c' }).success).toBe(false);
    expect(
      createAgencyBody.safeParse({
        ownerEmail: 'a@b.c',
        ownerUserId: '0190f0f0-0000-7000-8000-000000000000',
        reason: 'x',
      }).success,
    ).toBe(false);
    expect(resolveComplaintBody.safeParse({ decision: 'move', note: 'x' }).success).toBe(false);
    expect(resolveComplaintBody.safeParse({ decision: 'move', toInviteCode: 'ABC', note: 'x' }).success).toBe(
      true,
    );
    expect(teamGrantBody.safeParse({ email: 'a@b.c', role: 'OWNER', reason: 'x' }).success).toBe(false);
    expect(
      teamGrantBody.safeParse({ email: 'a@b.c', role: 'LEVELS_EDIT', reason: 'x', totpCode: '123456' })
        .success,
    ).toBe(false);
    expect(updateGiftBody.safeParse({ reason: 'x' }).success).toBe(false);
    expect(updateGiftBody.safeParse({ priceCoins: 10, reason: 'x' }).success).toBe(true);
    expect(reportQuery.safeParse({ from: '2026-01-01', to: '2026-12-31' }).success).toBe(true);
    expect(reportQuery.safeParse({ from: '2024-01-01', to: '2026-12-31' }).success).toBe(false);
    expect(
      reportQuery.safeParse({ from: '2024-01-01', to: '2026-12-31', granularity: 'month' }).success,
    ).toBe(true);
    expect(reportQuery.safeParse({ from: '2026-02-01', to: '2026-01-01' }).success).toBe(false);
  });

  it('capabilities: the v2 matrix (team and audit OWNER only; money FINANCE + OWNER)', () => {
    expect(CAPABILITIES['team.manage']).toEqual(['OWNER']);
    expect(CAPABILITIES['audit.view']).toEqual(['OWNER']);
    expect(CAPABILITIES['finance.refund']).toEqual(['OWNER', 'FINANCE']);
    expect(capabilitiesOf(['MODERATION'])).toEqual(
      expect.arrayContaining(['lives.manage', 'users.sessions', 'reports.act']),
    );
    expect(capabilitiesOf(['MODERATION'])).not.toContain('finance.view');
    expect(capabilitiesOf(['FINANCE'])).not.toContain('lives.view');
    expect(capabilitiesOf(['SUPPORT'])).toEqual(expect.arrayContaining(['agencies.manage', 'items.grant']));
    // Owner answer CP-039 Q2: the users CSV (with emails) is OWNER only.
    expect(capabilitiesOf(['SUPPORT'])).not.toContain('users.export');
    expect(CAPABILITIES['users.export']).toEqual(['OWNER']);
  });
});
