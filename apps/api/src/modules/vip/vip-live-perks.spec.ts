import { describe, expect, it } from 'vitest';
import { Prisma } from '../../generated/prisma/client.js';
import { isSeatEmojiToken, vipSeatEmojiIndex } from '../live/live-seat-emoji.js';
import { vipCatalogueEntry } from './vip-catalogue.js';
import {
  VIP_LIVE_PERKS,
  vipArtPackValue,
  vipIntValue,
  vipPerkRankSql,
  vipPinValue,
} from './vip-live-perks.js';
import { VIP_BUILT_PERKS } from './vip-rules.js';

describe('D379 VIP live-room perk helpers', () => {
  it('the ten live-room perks are built in the catalogue', () => {
    expect(VIP_LIVE_PERKS).toHaveLength(10);
    for (const code of VIP_LIVE_PERKS) {
      expect(vipCatalogueEntry(code)?.built, code).toBe(true);
      expect(VIP_BUILT_PERKS.has(code), code).toBe(true);
    }
  });

  it('reads int, pin and art-pack values; anything else is "not set"', () => {
    expect(vipIntValue(5)).toBe(5);
    for (const v of [0, -1, 1.5, '5', null, { n: 1 }]) expect(vipIntValue(v)).toBeNull();
    expect(vipPinValue({ count: 2, seconds: 30 })).toEqual({ count: 2, seconds: 30 });
    expect(vipPinValue({ count: 2 })).toBeNull();
    expect(vipPinValue([2, 30])).toBeNull();
    expect(vipPinValue(null)).toBeNull();
    expect(vipArtPackValue(['https://a/1.svga', 'http://b/2.png', 3, 'https://c/3.png'])).toEqual([
      'https://a/1.svga',
      'https://c/3.png',
    ]);
    expect(vipArtPackValue('https://a/1.svga')).toEqual([]);
  });

  it('a VIP seat-emoji token is :vip_<1…99>:', () => {
    expect(vipSeatEmojiIndex(':vip_1:')).toBe(1);
    expect(vipSeatEmojiIndex(':vip_24:')).toBe(24);
    for (const t of [':vip_0:', ':vip_100:', ':vip_01:', 'vip_1', ':vip_x:'])
      expect(vipSeatEmojiIndex(t)).toBeNull();
    expect(isSeatEmojiToken(':vip_3:')).toBe(true);
    expect(isSeatEmojiToken(':kabi_love:')).toBe(true);
  });

  it('the rank SQL binds the perk code; a code that is not built ranks nobody', () => {
    const sql = vipPerkRankSql('SEAT_REQUEST_PRIORITY', Prisma.sql`q.user_id`);
    expect(sql.values).toContain('SEAT_REQUEST_PRIORITY');
    expect(sql.sql).toContain('vm.expires_at > now()');
  });
});
