import { describe, expect, it } from 'vitest';
import {
  addMonths,
  agencyCommissionPaid,
  agencyRateBps,
  cherriesValueMinor,
  commissionOf,
  giftCherries,
  monthKey,
  newInviteCode,
  nextRank,
  normalizeInviteCode,
  parentCommissionPaid,
  qualifiedRank,
  qualifiesAsAgent,
  withdrawalCherries,
} from './economy-math.js';

const rules = {
  cherriesPerCoin: 10,
  agencyCommissionBps: 1500,
  agencyTierCommissionBps: 1600,
  agencyTierMonthlyCherries: 1_500_000_000,
  parentCommissionBps: 300,
};
const ranks = { rankMinActiveHosts: 5, rankExceptionCherries: 200_000_000, adminMinSubAgencies: 3 };

describe('D179 cherry arithmetic', () => {
  it('credits coins × share × 10, rounded down, for every gift kind', () => {
    expect(giftCherries(100n, 6500, 10)).toBe(650n); // normal 65 %
    expect(giftCherries(100n, 1000, 10)).toBe(100n); // lucky 10 %
    expect(giftCherries(100n, 5000, 10)).toBe(500n); // quips 50 %, DM 50 %
    expect(giftCherries(1n, 6500, 10)).toBe(6n); // 6.5 → 6
    expect(giftCherries(0n, 6500, 10)).toBe(0n); // a free quip
    expect(giftCherries(1_000_000n, 6500, 10)).toBe(6_500_000n); // the owner's example
  });

  it('pays commissions on the host cherries, rounded down', () => {
    expect(commissionOf(6_500_000n, 1500)).toBe(975_000n); // the owner's example: 0.975M
    expect(commissionOf(6_500_000n, 300)).toBe(195_000n); // parent 3 %: 0.195M
    expect(commissionOf(6n, 1500)).toBe(0n);
    expect(commissionOf(650n, 1600)).toBe(104n);
  });

  it('switches to 16 % in the month after a month of ≥ 1.5 billion host cherries', () => {
    expect(agencyRateBps(1_499_999_999n, rules)).toBe(1500);
    expect(agencyRateBps(1_500_000_000n, rules)).toBe(1600);
  });

  it('pays a lapsed agency only for hosts who joined before the lapse; a parent only as ADMIN', () => {
    expect(agencyCommissionPaid('NEW', false)).toBe(true);
    expect(agencyCommissionPaid('AGENT', false)).toBe(true);
    expect(agencyCommissionPaid('LAPSED', true)).toBe(true);
    expect(agencyCommissionPaid('LAPSED', false)).toBe(false);
    expect(parentCommissionPaid('ADMIN')).toBe(true);
    expect(parentCommissionPaid('AGENT')).toBe(false);
    expect(parentCommissionPaid(null)).toBe(false);
  });

  it('qualifies agents by 5 active hosts or the 200 million exception; admins by 3 qualified subs', () => {
    expect(qualifiesAsAgent(5, 0n, ranks)).toBe(true);
    expect(qualifiesAsAgent(4, 199_999_999n, ranks)).toBe(false);
    expect(qualifiesAsAgent(4, 200_000_000n, ranks)).toBe(true);
    expect(qualifiedRank(true, 3, ranks)).toBe('ADMIN');
    expect(qualifiedRank(true, 2, ranks)).toBe('AGENT');
    expect(qualifiedRank(false, 5, ranks)).toBe('LAPSED');
  });

  it('demotes only at a month start and promotes at any time', () => {
    expect(nextRank('AGENT', 'LAPSED', false)).toBe('AGENT');
    expect(nextRank('AGENT', 'LAPSED', true)).toBe('LAPSED');
    expect(nextRank('NEW', 'LAPSED', false)).toBe('NEW');
    expect(nextRank('LAPSED', 'AGENT', false)).toBe('AGENT');
    expect(nextRank('AGENT', 'ADMIN', false)).toBe('ADMIN');
    expect(nextRank('ADMIN', 'AGENT', true)).toBe('AGENT');
  });

  it('holds ceil(amount × cherries / minor) for a withdrawal ($10 = 9 090 910 at $1.10 per million)', () => {
    expect(withdrawalCherries(1000n, 1_000_000, 110)).toBe(9_090_910n);
    expect(withdrawalCherries(110n, 1_000_000, 110)).toBe(1_000_000n);
    expect(cherriesValueMinor(9_090_910n, 1_000_000, 110)).toBe(1000n);
    expect(cherriesValueMinor(999_999n, 1_000_000, 110)).toBe(109n);
  });

  it('names months in the reporting time zone', () => {
    const t = new Date('2026-10-31T22:30:00Z');
    expect(monthKey(t, 'UTC')).toBe('2026-10-01');
    expect(monthKey(t, 'Asia/Riyadh')).toBe('2026-11-01');
    expect(addMonths('2026-01-01', -1)).toBe('2025-12-01');
    expect(addMonths('2026-11-01', 2)).toBe('2027-01-01');
  });

  it('makes and normalizes invite codes', () => {
    for (let i = 0; i < 20; i++) expect(normalizeInviteCode(newInviteCode())).not.toBeNull();
    expect(normalizeInviteCode(' abcd2345 ')).toBe('ABCD2345');
    expect(normalizeInviteCode('ABCD0123')).toBeNull(); // 0 and 1 are never used
    expect(normalizeInviteCode('short')).toBeNull();
  });
});
