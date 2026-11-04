import { describe, expect, it } from 'vitest';
import {
  isVipOnlyBagCategory,
  vipNotWorn,
  VIP_BAG_PERKS,
  vipBagCode,
  vipBagPerkIn,
  vipBagPerkOf,
  vipOffPerksAfter,
} from './vip-bag.js';

describe('D264 VIP bag rules', () => {
  it('codes: vip:<PERK> both ways; anything else is not a VIP item', () => {
    for (const perk of Object.keys(VIP_BAG_PERKS) as (keyof typeof VIP_BAG_PERKS)[]) {
      expect(vipBagPerkOf(vipBagCode(perk))).toBe(perk);
    }
    expect(vipBagPerkOf('vip:BADGE')).toBeNull();
    expect(vipBagPerkOf('vip:avatar_frame')).toBeNull();
    expect(vipBagPerkOf('support_frame_01')).toBeNull();
  });

  it('categories: every wearable perk shares a bag category but the mic wave (D270: the store sells the rest)', () => {
    expect(vipBagPerkIn('AVATAR_FRAME')).toBe('AVATAR_FRAME');
    expect(vipBagPerkIn('PROFILE_CARD')).toBe('PROFILE_CARD');
    expect(vipBagPerkIn('ROOM_CARD')).toBeNull();
    expect(vipBagPerkIn('ENTRY_EFFECT')).toBe('ENTRY_EFFECT');
    expect(isVipOnlyBagCategory('MIC_WAVE')).toBe(true);
    expect(isVipOnlyBagCategory('CHAT_BUBBLE')).toBe(false);
    expect(isVipOnlyBagCategory('ENTRY_BANNER')).toBe(false);
    expect(isVipOnlyBagCategory('AVATAR_FRAME')).toBe(false);
    expect(isVipOnlyBagCategory('PROFILE_CARD')).toBe(false);
  });

  it('taking off and wearing again: a set in a fixed order, unknown codes dropped', () => {
    expect(vipOffPerksAfter([], 'MIC_WAVE', false)).toEqual(['MIC_WAVE']);
    expect(vipOffPerksAfter(['MIC_WAVE'], 'AVATAR_FRAME', false)).toEqual(['AVATAR_FRAME', 'MIC_WAVE']);
    expect(vipOffPerksAfter(['AVATAR_FRAME', 'MIC_WAVE'], 'AVATAR_FRAME', true)).toEqual(['MIC_WAVE']);
    expect(vipOffPerksAfter(['MIC_WAVE'], 'MIC_WAVE', false)).toEqual(['MIC_WAVE']);
    expect(vipOffPerksAfter(['BADGE'], 'CHAT_BUBBLE', true)).toEqual([]);
  });

  it('not worn: taken off, or covered by a bag item worn of the same kind', () => {
    expect(vipNotWorn([], [])).toEqual([]);
    expect(vipNotWorn(['MIC_WAVE'], ['PROFILE_CARD'])).toEqual(['PROFILE_CARD', 'MIC_WAVE']);
    expect(vipNotWorn([], ['AVATAR_FRAME', 'PROFILE_CARD'])).toEqual(['AVATAR_FRAME', 'PROFILE_CARD']);
    expect(vipNotWorn(['AVATAR_FRAME'], ['AVATAR_FRAME'])).toEqual(['AVATAR_FRAME']);
    // D270: a store bubble / car worn covers the VIP one too; nothing covers the mic wave.
    expect(vipNotWorn([], ['CHAT_BUBBLE', 'ENTRY_EFFECT'])).toEqual(['CHAT_BUBBLE', 'ENTRY_EFFECT']);
    expect(vipNotWorn([], ['MIC_WAVE'])).toEqual([]);
  });
});
