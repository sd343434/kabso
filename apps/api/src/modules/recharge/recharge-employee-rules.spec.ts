import { describe, expect, it } from 'vitest';
import {
  agentSideBlock,
  cherryActionFits,
  cherryActions,
  employeeMay,
  onShift,
  type EmployeeJob,
} from './recharge-rules.js';

/** D287 (v1.87-social, CONVENTIONS §10.100): who of the agent's side may act, and on what. */
describe('D287 employee rules', () => {
  // Monday 2026-11-02 10:30 UTC.
  const monday = new Date('2026-11-02T10:30:00Z');
  const job = (over: Partial<EmployeeJob> = {}): EmployeeJob => ({
    timeZone: 'UTC',
    schedule: [{ days: [1], start: '09:00', end: '12:00' }],
    canBuyCherries: true,
    receivesOrders: true,
    ...over,
  });

  it('reads the two permissions', () => {
    expect(employeeMay(job(), 'BUY_CHERRIES')).toBe(true);
    expect(employeeMay(job({ canBuyCherries: false }), 'BUY_CHERRIES')).toBe(false);
    expect(employeeMay(job({ canBuyCherries: false }), 'RECEIVE_ORDERS')).toBe(true);
    expect(employeeMay(job({ receivesOrders: false }), 'RECEIVE_ORDERS')).toBe(false);
  });

  it('is on shift inside a slot in the employee zone (start inclusive, end exclusive)', () => {
    expect(onShift(job(), monday)).toBe(true);
    expect(onShift(job(), new Date('2026-11-02T12:00:00Z'))).toBe(false);
    expect(onShift(job(), new Date('2026-11-02T09:00:00Z'))).toBe(true);
    // 10:30 UTC is 13:30 in Riyadh: outside 09–12 there.
    expect(onShift(job({ timeZone: 'Asia/Riyadh' }), monday)).toBe(false);
    expect(onShift(job(), new Date('2026-11-03T10:30:00Z'))).toBe(false); // Tuesday
  });

  it('never blocks the agent', () => {
    expect(agentSideBlock('agent', null, 'BUY_CHERRIES', new Date('2026-11-08T03:00:00Z'), 'emp')).toBeNull();
  });

  it('blocks an employee: the permission first, then another claim, then the hours', () => {
    const off = new Date('2026-11-02T20:00:00Z');
    expect(agentSideBlock('e1', job(), 'BUY_CHERRIES', monday)).toBeNull();
    expect(agentSideBlock('e1', job({ canBuyCherries: false }), 'BUY_CHERRIES', off)).toBe('NOT_PERMITTED');
    expect(agentSideBlock('e1', job({ receivesOrders: false }), 'RECEIVE_ORDERS', monday, 'e2')).toBe(
      'NOT_PERMITTED',
    );
    expect(agentSideBlock('e1', job(), 'RECEIVE_ORDERS', off, 'e2')).toBe('CLAIMED');
    expect(agentSideBlock('e1', job(), 'RECEIVE_ORDERS', monday, 'agent')).toBe('CLAIMED');
    expect(agentSideBlock('e1', job(), 'RECEIVE_ORDERS', monday, 'e1')).toBeNull();
    expect(agentSideBlock('e1', job(), 'RECEIVE_ORDERS', off, 'e1')).toBe('OFF_SHIFT');
    expect(agentSideBlock('e1', job(), 'BUY_CHERRIES', off)).toBe('OFF_SHIFT');
  });

  it('blocks a Kabso Team account before everything, even on shift and with both permissions (owner)', () => {
    const off = new Date('2026-11-08T03:00:00Z');
    expect(agentSideBlock('e1', job({ kabsoTeam: true }), 'BUY_CHERRIES', monday)).toBe('STAFF');
    expect(agentSideBlock('e1', job({ kabsoTeam: true }), 'RECEIVE_ORDERS', monday, 'e1')).toBe('STAFF');
    expect(agentSideBlock('e1', job({ kabsoTeam: true, canBuyCherries: false }), 'BUY_CHERRIES', off)).toBe(
      'STAFF',
    );
    expect(agentSideBlock('e1', job({ kabsoTeam: false }), 'BUY_CHERRIES', monday)).toBeNull();
    expect(cherryActions('AGENT', 'HOST', true, 'STAFF')).toEqual([]);
  });

  it("gives the creator's side cancel and the other side confirm / decline, only while open and unblocked", () => {
    expect(cherryActions('AGENT', 'HOST', true, null)).toEqual(['confirm', 'decline']);
    expect(cherryActions('HOST', 'HOST', true, null)).toEqual(['cancel']);
    expect(cherryActions('AGENT', 'AGENT', true, null)).toEqual(['cancel']);
    expect(cherryActions('HOST', 'AGENT', true, null)).toEqual(['confirm', 'decline']);
    expect(cherryActions('AGENT', 'HOST', false, null)).toEqual([]);
    expect(cherryActions('AGENT', 'HOST', true, 'OFF_SHIFT')).toEqual([]);
    expect(cherryActions('AGENT', 'HOST', true, 'NOT_PERMITTED')).toEqual([]);
    expect(cherryActionFits('confirm', 'AGENT', 'HOST')).toBe(true);
    expect(cherryActionFits('cancel', 'AGENT', 'HOST')).toBe(false);
    expect(cherryActionFits('cancel', 'AGENT', 'AGENT')).toBe(true);
    expect(cherryActionFits('confirm', 'AGENT', 'AGENT')).toBe(false);
    expect(cherryActionFits('approve', 'HOST', 'AGENT')).toBe(false);
  });
});
