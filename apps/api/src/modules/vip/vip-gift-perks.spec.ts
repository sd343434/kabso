import { describe, expect, it } from 'vitest';
import { vipExtraQuantities, vipGiftCodesFor, vipMaySendGift } from './vip-gift-perks.js';
import { rocketStageNumber } from './vip-monthly-rockets.js';

/** v1.134-social (D381, CONVENTIONS §10.171): the pure parts of the gift / rocket perks. */

const BASE = [1, 9, 49, 99, 199, 520, 1314];

describe('D381 EXCLUSIVE_GIFTS', () => {
  // castle: from rank 1 (VIP 1 lists it; VIP 3 lists it too — the lowest wins); crown: from rank 3.
  const exclusive = new Map([
    ['castle', 1],
    ['crown', 3],
  ]);

  it('a gift on no list is open to everyone; a listed one from its lowest tier up (inheritance)', () => {
    expect(vipMaySendGift(exclusive, 'rose', null)).toBe(true);
    expect(vipMaySendGift(exclusive, 'castle', null)).toBe(false);
    expect(vipMaySendGift(exclusive, 'castle', 1)).toBe(true);
    expect(vipMaySendGift(exclusive, 'castle', 5)).toBe(true);
    expect(vipMaySendGift(exclusive, 'crown', 2)).toBe(false);
    expect(vipMaySendGift(exclusive, 'crown', 3)).toBe(true);
  });

  it("the «VIP» tab lists the codes the member's rank may send, sorted; none without VIP", () => {
    expect(vipGiftCodesFor(exclusive, null)).toEqual([]);
    expect(vipGiftCodesFor(exclusive, 2)).toEqual(['castle']);
    expect(vipGiftCodesFor(exclusive, 4)).toEqual(['castle', 'crown']);
  });
});

describe('D381 HIGHER_GIFT_QUANTITY', () => {
  it('no extra quantity without the perk or with a maximum not above the configured ones', () => {
    expect(vipExtraQuantities(BASE, null)).toEqual([]);
    expect(vipExtraQuantities(BASE, 1000)).toEqual([]);
    expect(vipExtraQuantities(BASE, 1314)).toEqual([]);
  });

  it('the steps above the configured quantities up to the maximum, and the maximum itself', () => {
    expect(vipExtraQuantities(BASE, 9999)).toEqual([3344, 5200, 9999]);
    expect(vipExtraQuantities(BASE, 4000)).toEqual([3344, 4000]);
    expect(vipExtraQuantities(BASE, 99_999)).toEqual([3344, 5200, 9999, 13140, 52000, 99999]);
  });
});

describe('D381 MONTHLY_ROCKETS', () => {
  it('reads the stage STAGE_1…STAGE_4 (D233) as 1–4; anything else is no stage', () => {
    expect(rocketStageNumber('STAGE_1')).toBe(1);
    expect(rocketStageNumber('STAGE_4')).toBe(4);
    expect(rocketStageNumber('STAGE_5')).toBeNull();
    expect(rocketStageNumber(2)).toBeNull();
  });
});
