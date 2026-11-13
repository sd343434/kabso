import { describe, expect, it } from 'vitest';
import { transferBody } from './whatsapp.schemas.js';
import {
  effectiveDepartments,
  firstAvailable,
  isWaDepartment,
  sortDepartments,
  teamDepartmentsOf,
  WA_DEPARTMENTS,
} from './whatsapp-departments.js';

/** D366 (CONVENTIONS §10.159): the departments and «أول متاح في القسم». */
describe('WhatsApp departments (D366)', () => {
  it('the fixed set, the catalogue order and GENERAL by default', () => {
    expect(WA_DEPARTMENTS).toEqual(['PAYMENTS', 'AGENCIES', 'TECHNICAL', 'REPORTS', 'GENERAL']);
    expect(isWaDepartment('REPORTS')).toBe(true);
    expect(isWaDepartment('SALES')).toBe(false);
    expect(isWaDepartment(null)).toBe(false);
    expect(sortDepartments(['GENERAL', 'PAYMENTS', 'GENERAL', 'TECHNICAL'])).toEqual([
      'PAYMENTS',
      'TECHNICAL',
      'GENERAL',
    ]);
    expect(effectiveDepartments(undefined)).toEqual(['GENERAL']);
    expect(effectiveDepartments([])).toEqual(['GENERAL']);
    expect(effectiveDepartments(['REPORTS', 'AGENCIES'])).toEqual(['AGENCIES', 'REPORTS']);
    expect(teamDepartmentsOf(undefined)).toEqual({ departments: ['GENERAL'], isDefault: true });
    expect(teamDepartmentsOf(['PAYMENTS'])).toEqual({ departments: ['PAYMENTS'], isDefault: false });
  });

  it('first available: the fewest open conversations', () => {
    const t = (iso: string) => new Date(iso);
    expect(firstAvailable([])).toBeNull();
    expect(
      firstAvailable([
        { userId: 'a', open: 3, lastAssignedAt: null },
        { userId: 'b', open: 1, lastAssignedAt: t('2026-11-11T09:00:00Z') },
        { userId: 'c', open: 2, lastAssignedAt: null },
      ])?.userId,
    ).toBe('b');
  });

  it('a tie goes to the one assigned least recently; never assigned first; then the lowest id', () => {
    const t = (iso: string) => new Date(iso);
    expect(
      firstAvailable([
        { userId: 'a', open: 1, lastAssignedAt: t('2026-11-11T09:00:00Z') },
        { userId: 'b', open: 1, lastAssignedAt: t('2026-11-11T08:00:00Z') },
        { userId: 'c', open: 1, lastAssignedAt: t('2026-11-11T10:00:00Z') },
      ])?.userId,
    ).toBe('b');
    expect(
      firstAvailable([
        { userId: 'a', open: 0, lastAssignedAt: t('2026-11-11T08:00:00Z') },
        { userId: 'b', open: 0, lastAssignedAt: null },
      ])?.userId,
    ).toBe('b');
    expect(
      firstAvailable([
        { userId: 'z', open: 0, lastAssignedAt: null },
        { userId: 'm', open: 0, lastAssignedAt: null },
      ])?.userId,
    ).toBe('m');
  });

  it('the transfer body: D366 with a department, D355 with toUserId only, never neither', () => {
    const uuid = '0190f1f2-0000-7000-8000-000000000001';
    expect(transferBody.safeParse({ toUserId: uuid }).success).toBe(true);
    expect(transferBody.safeParse({ department: 'PAYMENTS' }).success).toBe(true);
    expect(transferBody.safeParse({ department: 'PAYMENTS', toUserId: uuid, note: ' نص ' }).data).toEqual({
      department: 'PAYMENTS',
      toUserId: uuid,
      note: 'نص',
    });
    const neither = transferBody.safeParse({ note: 'x' });
    expect(neither.success).toBe(false);
    expect(neither.error?.issues[0]?.path).toEqual(['toUserId']);
    expect(transferBody.safeParse({ department: 'SALES' }).success).toBe(false);
    expect(transferBody.safeParse({ department: 'GENERAL', note: 'x'.repeat(501) }).success).toBe(false);
    expect(transferBody.safeParse({ department: 'GENERAL', note: 'x'.repeat(500) }).success).toBe(true);
    expect(transferBody.safeParse({ department: 'GENERAL', extra: 1 }).success).toBe(false);
  });
});
