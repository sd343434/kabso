import { describe, expect, it } from 'vitest';
import {
  activeDays,
  cardFees,
  CHERRY_COST_REASONS,
  cherryMoney,
  coinMoney,
  daysInMonth,
  fixedCostShare,
  isDayKey,
  periodsOf,
} from './owner-profit-rules.js';

describe('D301 «الربح» rules (§10.112.10)', () => {
  it('days and months', () => {
    expect(daysInMonth(2026, 11)).toBe(30);
    expect(daysInMonth(2028, 2)).toBe(29);
    expect(isDayKey('2026-02-29')).toBe(false);
    expect(isDayKey('2028-02-29')).toBe(true);
    expect(isDayKey('2026-1-01')).toBe(false);
  });

  it('a past month is whole; the current one runs to today', () => {
    const past = periodsOf('2026-10-15', '2026-11-07');
    expect(past.day).toMatchObject({
      kind: 'DAY',
      from: '2026-10-15',
      to: '2026-10-15',
      days: 1,
      daysInMonth: 31,
    });
    expect(past.month).toMatchObject({
      key: '2026-10',
      from: '2026-10-01',
      to: '2026-10-31',
      days: 31,
      partial: false,
    });
    const now = periodsOf('2026-11-07', '2026-11-07');
    expect(now.month).toMatchObject({
      key: '2026-11',
      to: '2026-11-07',
      days: 7,
      daysInMonth: 30,
      partial: true,
    });
    expect(periodsOf('2026-11-30', '2026-11-30').month.partial).toBe(false);
  });

  it('a fixed cost: $300 a month is $10 a day in a 30-day month, the whole amount for the whole month', () => {
    const cost = { monthlyMinor: 30_000n, activeFrom: '2026-01-01', activeTo: null };
    const { day, month } = periodsOf('2026-11-07', '2026-11-30');
    expect(fixedCostShare(cost, day)).toBe(1_000n);
    expect(fixedCostShare(cost, month)).toBe(30_000n);
    // The elapsed share of the current month.
    expect(fixedCostShare(cost, periodsOf('2026-11-07', '2026-11-07').month)).toBe(7_000n);
    // A 31-day month: $300 ÷ 31 = $9.68 a day (rounded half up).
    expect(fixedCostShare(cost, periodsOf('2026-10-02', '2026-11-07').day)).toBe(968n);
  });

  it('only the active days count', () => {
    const cost = { monthlyMinor: 30_000n, activeFrom: '2026-11-10', activeTo: '2026-11-19' };
    const { day, month } = periodsOf('2026-11-07', '2026-11-30');
    expect(activeDays(cost, month.from, month.to)).toBe(10);
    expect(fixedCostShare(cost, month)).toBe(10_000n);
    expect(fixedCostShare(cost, day)).toBe(0n);
    expect(fixedCostShare({ ...cost, activeFrom: '2026-12-01', activeTo: null }, month)).toBe(0n);
  });

  it('cherries at the payout rate, a negative net lowering the costs', () => {
    expect(cherryMoney(1_000_000n, 1_000_000, 110)).toBe(110n);
    expect(cherryMoney(4_545n, 1_000_000, 110)).toBe(0n);
    expect(cherryMoney(5_000n, 1_000_000, 110)).toBe(1n);
    expect(cherryMoney(-1_000_000n, 1_000_000, 110)).toBe(-110n);
  });

  it('given-away coins at the lowest agent price ($120 per 10 000 000)', () => {
    expect(coinMoney(10_000_000n, 1200)).toBe(12_000n);
    expect(coinMoney(250_000n, 1200)).toBe(300n);
    expect(coinMoney(0n, 1200)).toBe(0n);
  });

  it('card fees: 2.9 % + $0.30 per order', () => {
    expect(cardFees(10_000n, 2n, { bps: 290, fixedMinor: 30 })).toBe(350n);
    expect(cardFees(0n, 0n, { bps: 290, fixedMinor: 30 })).toBe(0n);
  });

  it('withdrawals are never a cost (the cherries were counted when credited)', () => {
    expect(CHERRY_COST_REASONS).not.toContain('WITHDRAWAL_HOLD');
    expect(CHERRY_COST_REASONS).not.toContain('RECHARGE_SALE');
    expect(CHERRY_COST_REASONS).toContain('GIFT_RECEIVED');
  });
});
