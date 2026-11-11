import { describe, expect, it, vi } from 'vitest';
import { buyVipBody, createVipTierBody, updateVipTierBody } from '../vip/vip.schemas.js';
import { vipPointsCharge } from '../vip/vip-rules.js';
import {
  earnRechargePointsIn,
  movePointsIn,
  reversalReference,
  spendPointsIn,
} from './recharge-points-ledger.js';

/** v1.126-social (D370, CONVENTIONS §10.162): «نقاط الشحن» — the rules without a database. */

const TIER = '0192f1c2-0000-7000-8000-000000000001';

describe('vipPointsCharge (the renewal discount on the points price)', () => {
  it('takes the same percent off, rounded down, never below 1', () => {
    expect(vipPointsCharge(2_000_000n, 0)).toBe(2_000_000n);
    expect(vipPointsCharge(2_000_000n, 15)).toBe(1_700_000n);
    expect(vipPointsCharge(3_500_001n, 15)).toBe(2_975_000n);
    expect(vipPointsCharge(400_000_000n, 90)).toBe(40_000_000n);
    expect(vipPointsCharge(1n, 15)).toBe(1n);
  });
});

describe('buyVipBody (payWith)', () => {
  const parse = (v: unknown) => buyVipBody.safeParse(v);
  it('an older app (no payWith) buys with coins as before', () => {
    expect(parse({ tierId: TIER, priceCoins: 1_000_000 }).data).toEqual({
      tierId: TIER,
      payWith: 'COINS',
      price: 1_000_000,
    });
  });
  it('POINTS needs pricePoints and refuses priceCoins', () => {
    expect(parse({ tierId: TIER, payWith: 'POINTS', pricePoints: 2_000_000 }).data).toEqual({
      tierId: TIER,
      payWith: 'POINTS',
      price: 2_000_000,
    });
    expect(parse({ tierId: TIER, payWith: 'POINTS' }).success).toBe(false);
    expect(parse({ tierId: TIER, payWith: 'POINTS', pricePoints: 1, priceCoins: 1 }).success).toBe(false);
    expect(parse({ tierId: TIER, payWith: 'COINS', pricePoints: 1 }).success).toBe(false);
    expect(parse({ tierId: TIER, payWith: 'POINTS', pricePoints: 0 }).success).toBe(false);
    expect(parse({ tierId: TIER, payWith: 'CHERRIES', priceCoins: 1 }).success).toBe(false);
  });
});

describe('the panel tier form (pointsPrice)', () => {
  const base = {
    code: 'VIP_2',
    nameAr: 'في آي بي 2',
    nameEn: 'VIP 2',
    color: '#C9A227',
    priceCoins: 2_000_000,
    durationDays: 30,
    reason: 'x',
  };
  it('is optional, nullable, 1 … 10^12', () => {
    expect(createVipTierBody.safeParse(base).success).toBe(true);
    expect(createVipTierBody.safeParse({ ...base, pointsPrice: 3_500_000 }).success).toBe(true);
    expect(createVipTierBody.safeParse({ ...base, pointsPrice: null }).success).toBe(true);
    expect(createVipTierBody.safeParse({ ...base, pointsPrice: 0 }).success).toBe(false);
    expect(createVipTierBody.safeParse({ ...base, pointsPrice: 1_000_000_000_001 }).success).toBe(false);
    expect(updateVipTierBody.safeParse({ pointsPrice: null, reason: 'off' }).success).toBe(true);
  });
});

describe('the ledger helpers', () => {
  const tx = (rows: { points: bigint }[]) => {
    const create = vi.fn().mockResolvedValue({ id: 'e1' });
    const queryRaw = vi.fn().mockResolvedValue(rows);
    return { db: { $queryRaw: queryRaw, rechargePointsEntry: { create } } as never, create, queryRaw };
  };
  it('earning writes a positive RECHARGE_* row with the balance after', async () => {
    const t = tx([{ points: 5n }]);
    const out = await earnRechargePointsIn(t.db, {
      userId: 'u',
      coins: 5n,
      reason: 'RECHARGE_AGENT',
      referenceId: 'sale-1',
    });
    expect(out).toEqual({ points: 5n, entryId: 'e1' });
    expect(t.create).toHaveBeenCalledWith({
      data: { userId: 'u', delta: 5n, balanceAfter: 5n, reason: 'RECHARGE_AGENT', referenceId: 'sale-1' },
      select: { id: true },
    });
    await expect(
      earnRechargePointsIn(t.db, { userId: 'u', coins: 0n, reason: 'RECHARGE_WEB', referenceId: 'x' }),
    ).rejects.toThrow(RangeError);
  });
  it('a redemption that the balance does not cover changes nothing', async () => {
    const t = tx([]);
    expect(await spendPointsIn(t.db, 'u', 10n, 'p1')).toBeNull();
    expect(t.create).not.toHaveBeenCalled();
    const ok = tx([{ points: 0n }]);
    expect(await spendPointsIn(ok.db, 'u', 10n, 'p1')).toEqual({ points: 0n, entryId: 'e1' });
    expect(ok.create.mock.calls[0]![0].data).toMatchObject({ delta: -10n, reason: 'VIP_REDEEM' });
  });
  it('a reversal may take the balance below 0; 0 is refused', async () => {
    const t = tx([{ points: -7n }]);
    expect(await movePointsIn(t.db, 'u', -10n, 'REVERSAL', 'web:evt')).toEqual({
      points: -7n,
      entryId: 'e1',
    });
    await expect(movePointsIn(t.db, 'u', 0n, 'REVERSAL', 'x')).rejects.toThrow(RangeError);
  });
  it('reversal references are per source and at most 64 characters', () => {
    expect(reversalReference('web', 'evt_1')).toBe('web:evt_1');
    expect(reversalReference('store', 'p')).toBe('store:p');
    expect(reversalReference('web', 'x'.repeat(80))).toHaveLength(64);
  });
});
