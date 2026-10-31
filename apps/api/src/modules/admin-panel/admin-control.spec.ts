import { describe, expect, it } from 'vitest';
import { AccountControlError, restrictionEnd } from '../users/account-control.js';
import { CAPABILITIES } from './admin-permissions.js';
import { lockBody, adjustBody, profileEditBody, restrictBody } from './admin-control.schemas.js';
import { maskEmail, temporaryPassword } from './admin-control.service.js';

/** v1.72-social (D208, CONVENTIONS §10.67): the account controls' pure rules. */
describe('D208 account controls', () => {
  const now = new Date('2026-10-31T12:00:00.000Z');

  it('ends a lock after N days or at a date in the future, at most a year away', () => {
    expect(restrictionEnd(now, { days: 1 }).toISOString()).toBe('2026-11-01T12:00:00.000Z');
    expect(restrictionEnd(now, { days: 30 }).toISOString()).toBe('2026-11-30T12:00:00.000Z');
    const until = new Date('2026-11-03T08:00:00.000Z');
    expect(restrictionEnd(now, { until })).toEqual(until);
    expect(() => restrictionEnd(now, {})).toThrow(AccountControlError);
    expect(() => restrictionEnd(now, { until: new Date('2026-10-31T11:59:59.000Z') })).toThrow(/future/);
    expect(() => restrictionEnd(now, { days: 366 })).toThrow(/365/);
  });

  it('generates temporary passwords of 4 groups without look-alike characters, never the same', () => {
    const seen = new Set<string>();
    for (let i = 0; i < 200; i++) {
      const p = temporaryPassword();
      expect(p).toMatch(/^[A-HJ-NP-Za-km-np-z2-9]{4}(-[A-HJ-NP-Za-km-np-z2-9]{4}){3}$/);
      expect(p).not.toMatch(/[0O1lI]/);
      seen.add(p);
    }
    expect(seen.size).toBe(200);
  });

  it('masks addresses for the audit log and the panel', () => {
    expect(maskEmail('layla@example.com')).toBe('l***@example.com');
    expect(maskEmail('broken')).toBe('***');
  });

  it('needs exactly one of days / until, a reason and a known kind', () => {
    expect(lockBody.safeParse({ days: 7, reason: 'x' }).success).toBe(true);
    expect(lockBody.safeParse({ reason: 'x' }).success).toBe(false);
    expect(lockBody.safeParse({ days: 7, until: '2026-11-03T08:00:00Z', reason: 'x' }).success).toBe(false);
    expect(lockBody.safeParse({ days: 7, reason: ' ' }).success).toBe(false);
    expect(restrictBody.safeParse({ kind: 'CHAT_MUTE', days: 3, reason: 'x' }).success).toBe(true);
    expect(restrictBody.safeParse({ kind: 'LOCK', days: 3, reason: 'x' }).success).toBe(false);
    expect(profileEditBody.safeParse({ reason: 'x' }).success).toBe(false);
    expect(profileEditBody.safeParse({ bio: null, reason: 'x' }).success).toBe(true);
  });

  it('takes whole amounts as strings, the code, and «allow negative» off by default', () => {
    const ok = adjustBody.parse({
      currency: 'COINS',
      direction: 'DEBIT',
      amount: '1500',
      reason: 'x',
      totpCode: '123456',
    });
    expect(ok.allowNegative).toBe(false);
    for (const amount of ['0', '-5', '1.5', '12345678901']) {
      expect(adjustBody.safeParse({ ...ok, amount }).success, amount).toBe(false);
    }
    expect(adjustBody.safeParse({ ...ok, totpCode: undefined }).success).toBe(false);
  });

  it('gives money to FINANCE / OWNER, deletion to OWNER only, never content or restrictions to FINANCE', () => {
    expect(CAPABILITIES['users.balance_adjust']).toEqual(['OWNER', 'FINANCE']);
    expect(CAPABILITIES['users.delete']).toEqual(['OWNER']);
    expect(CAPABILITIES['users.password']).toEqual(['OWNER', 'SUPPORT']);
    expect(CAPABILITIES['users.restrict']).not.toContain('FINANCE');
    expect(CAPABILITIES['users.content']).not.toContain('FINANCE');
  });
});
