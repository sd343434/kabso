import { describe, expect, it } from 'vitest';
import { userSummary } from '../posts/post-views.js';
import { formatStaffId, isStaffIdLike, parseStaffId, summaryStaffIdOf } from './staff-ids.js';
import { isReservedUsername } from './username.js';

/**
 * v1.73-live (D283c, CONVENTIONS §10.96.12): the official staff ID «Kabso01» — its format, the search parse, the
 * reserved look-alikes and when a `UserSummary` carries it.
 */
describe('staff IDs (D283c)', () => {
  it('formats two digits, growing to three and more after 99', () => {
    expect(formatStaffId(1)).toBe('Kabso01');
    expect(formatStaffId(9)).toBe('Kabso09');
    expect(formatStaffId(10)).toBe('Kabso10');
    expect(formatStaffId(99)).toBe('Kabso99');
    expect(formatStaffId(100)).toBe('Kabso100');
    expect(formatStaffId(1234)).toBe('Kabso1234');
  });

  it('parses what a search or the panel types (any case, @, leading zeros)', () => {
    expect(parseStaffId('Kabso01')).toBe(1);
    expect(parseStaffId('kabso1')).toBe(1);
    expect(parseStaffId(' @KABSO012 ')).toBe(12);
    expect(parseStaffId('Kabso100')).toBe(100);
    for (const no of ['Kabso', 'Kabso00', 'kabso01x', 'kabs01', 'support', '01', 'kabso-01']) {
      expect(parseStaffId(no), no).toBeNull();
    }
  });

  it('reserves anything that looks like a staff ID for normal users (any case, look-alikes)', () => {
    for (const name of [
      'kabso01',
      'kabso1',
      'kabso100',
      'kabso_01',
      'kab.so01',
      'kabs001',
      'kabs0o1',
      'k4bso01',
      'kab5o01',
      'ka8so01',
      'kabsoo1',
      'kabso0l',
      'KABSO01',
    ]) {
      expect(isStaffIdLike(name), name).toBe(true);
      expect(isReservedUsername(name.toLowerCase()), name).toBe(true);
    }
    for (const name of ['kabsolive', 'kabsofan', 'kabsoil', 'akabso01', 'kabso01fan', 'ali2024', 'kabsa01']) {
      expect(isStaffIdLike(name), name).toBe(false);
    }
    // The existing rules stay (kabso itself, support, coin / host + digits).
    for (const name of ['kabso', 'support', 'live', 'coin12', 'host7']) {
      expect(isReservedUsername(name), name).toBe(true);
    }
  });

  it('a UserSummary carries it only while a panel role is held by an active ADMIN account', () => {
    const base = {
      id: '0192f1c2-0000-7000-8000-000000000001',
      profile: { username: 'sara.staff', displayName: 'Sara', avatarUrl: null },
      status: 'ACTIVE',
      role: 'ADMIN',
      staffNumber: { number: 1 },
      adminPermissions: [{ permission: 'SUPPORT' }],
    };
    expect(userSummary(base).staffId).toBe('Kabso01');
    expect(userSummary(base).username).toBe('sara.staff');
    expect(userSummary({ ...base, adminPermissions: [{ permission: 'OWNER' }] }).staffId).toBe('Kabso01');
    // Revoked (the number is kept, not shown), suspended, demoted, never staff, an older select.
    expect(userSummary({ ...base, adminPermissions: [] }).staffId).toBeUndefined();
    expect(userSummary({ ...base, status: 'SUSPENDED' }).staffId).toBeUndefined();
    expect(userSummary({ ...base, role: 'USER' }).staffId).toBeUndefined();
    expect(userSummary({ ...base, staffNumber: null }).staffId).toBeUndefined();
    expect(userSummary({ id: base.id, profile: base.profile }).staffId).toBeUndefined();
    expect(summaryStaffIdOf({ ...base, adminPermissions: [{ permission: 'LEVELS_VIEW' }] })).toBeNull();
    expect('staffId' in userSummary({ ...base, adminPermissions: [] })).toBe(false);
  });
});
