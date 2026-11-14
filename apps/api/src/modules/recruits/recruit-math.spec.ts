import { describe, expect, it } from 'vitest';
import type { ProfitEconomy } from '../programs/host-target-engine.js';
import {
  DEFAULT_RECRUIT_BPS,
  commissionCherries,
  giftProfitUnits,
  recruitCommissionReference,
  topupProfitUnits,
  unitsToUsd,
  withinGuard,
} from './recruit-math.js';

/** The owner's economy: $12.50 per 1 000 000 coins, 1 000 000 cherries = $1.10, 10 cherries per coin, 65 % share. */
const E: ProfitEconomy = {
  cherriesPerCoin: 10,
  coinCentsPerMillion: 1250,
  rateCherries: 1_000_000,
  rateMinor: 110,
  luckyRtpBps: 8500,
  luckyHostShareBps: 1000,
  hostShareBps: { POPULAR: 6500, EVENT: 6500, FUN: 6500, QUIPS: 5000 },
};

describe('D285 recruit commission math', () => {
  it('the owner defaults: 1 % hosts, creators and agencies, 0.75 % recharge agents (basis points)', () => {
    expect(DEFAULT_RECRUIT_BPS).toEqual({ HOST: 100, CREATOR: 100, AGENCY: 100, RECHARGE_AGENT: 75 });
  });

  it('HOST / CREATOR: 1 000 000 coins of normal gifts → $5.35 profit → 1 % = 48 636 cherries', () => {
    const profit = giftProfitUnits(
      { charged: 1_000_000n, luckyCoins: 0n, cherries: 6_500_000n, commissions: 0n },
      E,
    );
    expect(unitsToUsd(profit, E)).toBeCloseTo(5.35, 6);
    expect(commissionCherries(profit, DEFAULT_RECRUIT_BPS.HOST, E)).toBe(48_636n);
    expect(commissionCherries(profit, DEFAULT_RECRUIT_BPS.CREATOR, E)).toBe(48_636n);
  });

  it('AGENCY: the agency commission (15 %) is a cost → $4.2775 → 1 % = 38 886 cherries', () => {
    const profit = giftProfitUnits(
      { charged: 1_000_000n, luckyCoins: 0n, cherries: 6_500_000n, commissions: 975_000n },
      E,
    );
    expect(unitsToUsd(profit, E)).toBeCloseTo(4.2775, 6);
    expect(commissionCherries(profit, DEFAULT_RECRUIT_BPS.AGENCY, E)).toBe(38_886n);
  });

  it('a lucky gift: the expected payout to the sender is a cost → $0.775 → 1 % = 7 045 cherries', () => {
    const profit = giftProfitUnits(
      { charged: 1_000_000n, luckyCoins: 1_000_000n, cherries: 1_000_000n, commissions: 0n },
      E,
    );
    expect(unitsToUsd(profit, E)).toBeCloseTo(0.775, 6);
    expect(commissionCherries(profit, 100, E)).toBe(7_045n);
  });

  it('RECHARGE_AGENT: 30 000 000 coins paid $360 → $145.50 margin → 0.75 % = 992 045 cherries', () => {
    const profit = topupProfitUnits({ paidMinor: 36_000n, coins: 30_000_000n }, E);
    expect(unitsToUsd(profit, E)).toBeCloseTo(145.5, 6);
    expect(commissionCherries(profit, DEFAULT_RECRUIT_BPS.RECHARGE_AGENT, E)).toBe(992_045n);
  });

  it('no profit (a bag gift, a refund) pays nothing; never negative', () => {
    const loss = giftProfitUnits({ charged: 0n, luckyCoins: 0n, cherries: 6_500_000n, commissions: 0n }, E);
    expect(loss < 0n).toBe(true);
    expect(commissionCherries(loss, 100, E)).toBe(0n);
    expect(commissionCherries(0n, 100, E)).toBe(0n);
    expect(commissionCherries(10n ** 20n, 0, E)).toBe(0n);
  });

  it('the guard: the commission never exceeds the share of the ACTUAL profit counted', () => {
    for (const charged of [1n, 37n, 999n, 1_000_000n, 123_456_789n]) {
      for (const bps of [1, 75, 100, 200, 2000]) {
        const profit = giftProfitUnits(
          { charged, luckyCoins: 0n, cherries: (charged * 65n) / 10n, commissions: 0n },
          E,
        );
        const c = commissionCherries(profit, bps, E);
        expect(withinGuard(c, profit, bps, E)).toBe(true);
        expect(withinGuard(c + 1n, profit, bps, E)).toBe(false);
      }
    }
    expect(withinGuard(1n, -5n, 100, E)).toBe(false);
    expect(withinGuard(0n, -5n, 100, E)).toBe(true);
    expect(withinGuard(-1n, 10n ** 20n, 100, E)).toBe(false);
  });

  it('the ledger reference: one per recruitment and day, within 64 characters', () => {
    const ref = recruitCommissionReference('0192f1c2-0000-7000-8000-000000000285', '2027-03-19');
    expect(ref).toBe('SR:0192f1c2-0000-7000-8000-000000000285@2027-03-19');
    expect(ref.length).toBeLessThanOrEqual(64);
  });
});
