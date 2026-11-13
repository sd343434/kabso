import { describe, expect, it } from 'vitest';
import { can, type PanelRole } from './admin-permissions.js';
import { STAFF_APP_CAPABILITIES } from './staff-app.service.js';
import {
  STAFF_REPORT_ACTION_CAPABILITY,
  STAFF_REPORT_ACTIONS,
  staffReportActionSchema,
} from './staff-report-actions.service.js';

/** v1.93-social (D296, CONVENTIONS §10.109): the actions from a report follow the panel's capability matrix. */
describe('D296 staff report actions', () => {
  const allowed = (role: PanelRole) =>
    STAFF_REPORT_ACTIONS.filter((a) => can([role], STAFF_REPORT_ACTION_CAPABILITY[a]));

  it('OWNER: every action; MODERATION: all but deleting an account; SUPPORT only the temporary lock', () => {
    expect(allowed('OWNER')).toEqual([
      'WARN',
      'RESTRICT',
      'SUSPEND',
      'BAN',
      'REMOVE_CONTENT',
      'DELETE_CONTENT',
      'DELETE_ACCOUNT',
    ]);
    expect(allowed('MODERATION')).toEqual([
      'WARN',
      'RESTRICT',
      'SUSPEND',
      'BAN',
      'REMOVE_CONTENT',
      'DELETE_CONTENT',
    ]);
    expect(allowed('SUPPORT')).toEqual(['SUSPEND']);
    expect(allowed('FINANCE')).toEqual([]);
    expect(allowed('BD')).toEqual([]);
  });

  it('the app learns every capability the actions need (StaffStatus.capabilities)', () => {
    for (const cap of Object.values(STAFF_REPORT_ACTION_CAPABILITY)) {
      expect(STAFF_APP_CAPABILITIES as readonly string[]).toContain(cap);
    }
  });

  it('days with RESTRICT / SUSPEND only; a restriction with RESTRICT only', () => {
    const ok = (v: object) => staffReportActionSchema.safeParse(v).success;
    expect(ok({ action: 'WARN', reason: 'r' })).toBe(true);
    expect(ok({ action: 'BAN', reason: 'r' })).toBe(true);
    expect(ok({ action: 'REMOVE_CONTENT', reason: 'r' })).toBe(true);
    expect(ok({ action: 'SUSPEND', reason: 'r', days: 3 })).toBe(true);
    expect(ok({ action: 'RESTRICT', reason: 'r', restriction: 'CHAT_MUTE', days: 365 })).toBe(true);
    expect(ok({ action: 'WARN', reason: '  ' })).toBe(false);
    expect(ok({ action: 'WARN', reason: 'r', days: 1 })).toBe(false);
    expect(ok({ action: 'SUSPEND', reason: 'r' })).toBe(false);
    expect(ok({ action: 'SUSPEND', reason: 'r', days: 0 })).toBe(false);
    expect(ok({ action: 'RESTRICT', reason: 'r', days: 3 })).toBe(false);
    expect(ok({ action: 'RESTRICT', reason: 'r', restriction: 'NO_GIFTS', days: 3 })).toBe(false);
    expect(ok({ action: 'BAN', reason: 'r', restriction: 'NO_LIVE' })).toBe(false);
    expect(ok({ action: 'WARN', reason: 'r', extra: 1 })).toBe(false);
    // The permanent deletions need the typed word, and only they take it.
    expect(ok({ action: 'DELETE_CONTENT', reason: 'r', confirm: 'DELETE' })).toBe(true);
    expect(ok({ action: 'DELETE_ACCOUNT', reason: 'r', confirm: 'DELETE' })).toBe(true);
    expect(ok({ action: 'DELETE_CONTENT', reason: 'r' })).toBe(false);
    expect(ok({ action: 'DELETE_ACCOUNT', reason: 'r', confirm: 'delete' })).toBe(false);
    expect(ok({ action: 'BAN', reason: 'r', confirm: 'DELETE' })).toBe(false);
  });
});
