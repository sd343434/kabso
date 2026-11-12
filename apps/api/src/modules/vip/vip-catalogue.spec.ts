import { describe, expect, it } from 'vitest';
import {
  VIP_ART_KINDS,
  VIP_CATALOGUE_AMOUNTS,
  VIP_CATALOGUE_BUILT,
  VIP_LIST_MAX_ITEMS,
  VIP_PERK_CATALOGUE,
  VIP_PERK_CATEGORIES,
  VIP_RETIRED_PERKS,
  vipCatalogueEntry,
  vipCatalogueIndex,
  vipPerkRetired,
  vipPerkValueIssues,
} from './vip-catalogue.js';
import { VIP_BUILT_PERKS, VIP_MAX_PERKS, VIP_PERK_AMOUNTS, vipEffectivePerks } from './vip-rules.js';
import { createVipTierBody, vipPerkInput } from './vip.schemas.js';

/** v1.129-social (D374, CONVENTIONS §10.166): the VIP perk catalogue and its value checks. */

const BUILT = [
  'BADGE',
  'AVATAR_FRAME',
  'CHAT_NAME_COLOR',
  'PROFILE_CARD',
  'ENTRY_BANNER',
  'ENTRY_EFFECT',
  'CHAT_BUBBLE',
  'MIC_WAVE',
  'DAILY_BULLET',
  'PROFILE_VISITORS',
  'LEVEL_SPEEDUP',
  // D380 (§10.170): the privacy perks built.
  'HIDDEN_VISIT',
  'RANKING_ANONYMOUS',
  'KICK_MUTE_SHIELD',
  'ANONYMOUS_GIFT',
];
/** D380: the privacy perks built by D380 (counted with BUILT, registered by D374 with the new ones). */
const D380 = ['HIDDEN_VISIT', 'RANKING_ANONYMOUS', 'KICK_MUTE_SHIELD', 'ANONYMOUS_GIFT'];
/** The owner's new perks (D374), registered not built (D380's four since built). */
const NEW = [
  'ANIMATED_COVER',
  'PREMIUM_USERNAME',
  'SEAT_EMOJI',
  'PINNED_MESSAGE',
  'EXCLUSIVE_GIFTS',
  'HIDDEN_VISIT',
  'RANKING_ANONYMOUS',
  'KICK_MUTE_SHIELD',
  'ANONYMOUS_GIFT',
  'DM_BUBBLE',
  'POST_BADGE',
  'STORY_RING',
  'FREE_CP_REQUEST',
  'VIEWER_LIST_PRIORITY',
  'SEAT_REQUEST_PRIORITY',
  'PRIORITY_SUPPORT',
  'MONTHLY_ROCKETS',
  'GLOWING_NAME',
  'HOST_GREETING',
  'SEAT_CROWN',
  'BIG_GIFT_RAIN',
  'TICKER_HOLD',
  'VIP_ROOM',
  'SEAT_RESERVE',
  'GOLDEN_ID',
  'ANIMATED_SIGNATURE',
  'SCHEDULED_GIFT',
  'HIGHER_GIFT_QUANTITY',
  'LONGER_VOICE',
];

const issues = (code: string, value: unknown) => vipPerkValueIssues(code, value).map((i) => i.issue);

describe('D374 VIP perk catalogue', () => {
  it("holds the owner's list: eleven built, the new ones, MONTHLY_GIFT; codes unique; DAILY_COINS and HIDE_COINS_SENT removed", () => {
    const codes = VIP_PERK_CATALOGUE.map((e) => e.code);
    expect(new Set(codes).size).toBe(codes.length);
    expect([...VIP_CATALOGUE_BUILT].sort()).toEqual([...BUILT].sort());
    expect([...VIP_BUILT_PERKS].sort()).toEqual([...BUILT].sort());
    for (const c of NEW) expect(vipCatalogueEntry(c)?.built, c).toBe(D380.includes(c));
    // D380: the owner removed HIDE_COINS_SENT (2026-11-12): D220's free switch hides the number for everyone.
    expect(vipCatalogueEntry('HIDE_COINS_SENT')).toBeUndefined();
    expect(vipPerkRetired('HIDE_COINS_SENT')).toBe(true);
    expect(vipCatalogueEntry('MONTHLY_GIFT')?.built).toBe(false);
    expect(codes).toHaveLength(BUILT.length - D380.length + NEW.length + 1);
    expect(codes.length).toBeLessThanOrEqual(VIP_MAX_PERKS);
    expect(VIP_MAX_PERKS).toBeGreaterThanOrEqual(64);
    // The owner removed DAILY_COINS (2026-11-11): not in the catalogue, retired.
    expect(vipCatalogueEntry('DAILY_COINS')).toBeUndefined();
    expect(VIP_RETIRED_PERKS).toEqual(['DAILY_COINS', 'HIDE_COINS_SENT']);
    expect(vipPerkRetired('DAILY_COINS')).toBe(true);
    expect(vipPerkRetired('BADGE')).toBe(false);
    // The code is MIC_WAVE (not MIC_SOUND_WAVE).
    expect(vipCatalogueEntry('MIC_WAVE')).toBeDefined();
    expect(vipCatalogueEntry('MIC_SOUND_WAVE')).toBeUndefined();
  });

  it('every entry has both titles and descriptions, a category, and its art kinds are known; listed by category', () => {
    let lastCategory = -1;
    for (const e of VIP_PERK_CATALOGUE) {
      expect(e.titleAr.length, e.code).toBeGreaterThan(0);
      expect(e.titleAr.length, e.code).toBeLessThanOrEqual(40);
      expect(e.titleEn.length, e.code).toBeLessThanOrEqual(40);
      expect(e.descriptionAr.length, e.code).toBeLessThanOrEqual(200);
      expect(e.descriptionEn.length, e.code).toBeLessThanOrEqual(200);
      const c = VIP_PERK_CATEGORIES.indexOf(e.category);
      expect(c, e.code).toBeGreaterThanOrEqual(lastCategory);
      lastCategory = c;
      for (const k of e.art?.kinds ?? []) expect(VIP_ART_KINDS).toContain(k);
    }
    expect(vipCatalogueIndex('BADGE')).toBe(0);
    expect(vipCatalogueIndex('NOT_A_PERK')).toBe(VIP_PERK_CATALOGUE.length);
  });

  it('the legacy amount perks (D258) are DAILY_BULLET and LEVEL_SPEEDUP, with their old bounds', () => {
    expect(VIP_CATALOGUE_AMOUNTS).toEqual({
      DAILY_BULLET: { min: 1, max: 100 },
      LEVEL_SPEEDUP: { min: 1, max: 100 },
    });
    expect(VIP_PERK_AMOUNTS).toBe(VIP_CATALOGUE_AMOUNTS);
  });

  it('none: only null', () => {
    expect(issues('BADGE', null)).toEqual([]);
    expect(issues('BADGE', 3)).toEqual(['not_allowed']);
  });

  it('int: whole numbers within the bounds', () => {
    expect(issues('LONGER_VOICE', 180)).toEqual([]);
    expect(issues('LONGER_VOICE', 30)).toEqual(['out_of_range']);
    expect(issues('LONGER_VOICE', 601)).toEqual(['out_of_range']);
    expect(issues('LONGER_VOICE', 60.5)).toEqual(['invalid_type']);
    expect(issues('LONGER_VOICE', '180')).toEqual(['invalid_type']);
    expect(issues('FREE_CP_REQUEST', 2)).toEqual([]);
    expect(issues('BIG_GIFT_RAIN', 10_000)).toEqual([]);
    expect(issues('SEAT_RESERVE', 61)).toEqual(['out_of_range']);
  });

  it('enum: one of its options; VIP_TIER: a tier code (existence checked when saving)', () => {
    expect(issues('PREMIUM_USERNAME', 'GOLD')).toEqual([]);
    expect(issues('PREMIUM_USERNAME', 'PLATINUM')).toEqual(['invalid_value']);
    expect(issues('PREMIUM_USERNAME', 1)).toEqual(['invalid_type']);
    expect(issues('VIP_ROOM', 'VIP_3')).toEqual([]);
    expect(issues('VIP_ROOM', 'vip 3')).toEqual(['invalid_format']);
  });

  it('color: #RRGGBB upper case', () => {
    expect(issues('STORY_RING', '#FFAA00')).toEqual([]);
    expect(issues('STORY_RING', '#ffaa00')).toEqual(['invalid_format']);
    expect(issues('STORY_RING', ['#FFAA00'])).toEqual(['invalid_type']);
  });

  it('list: distinct gift codes, at least one, at most the limit', () => {
    expect(issues('EXCLUSIVE_GIFTS', ['rose', 'castle_2'])).toEqual([]);
    expect(issues('EXCLUSIVE_GIFTS', [])).toEqual(['too_few']);
    expect(issues('EXCLUSIVE_GIFTS', ['rose', 'rose'])).toEqual(['duplicate_value']);
    expect(issues('EXCLUSIVE_GIFTS', ['Rose!'])).toEqual(['invalid_format']);
    expect(issues('EXCLUSIVE_GIFTS', 'rose')).toEqual(['invalid_type']);
    const many = Array.from({ length: VIP_LIST_MAX_ITEMS + 1 }, (_, i) => `g${String(i)}`);
    expect(issues('EXCLUSIVE_GIFTS', many)).toEqual(['too_many']);
  });

  it('art_list: distinct https URLs (an art pack)', () => {
    expect(issues('SEAT_EMOJI', ['https://cdn.example/a.svga', 'https://cdn.example/b.png'])).toEqual([]);
    expect(issues('SEAT_EMOJI', ['http://cdn.example/a.svga'])).toEqual(['invalid_format']);
    expect(vipPerkValueIssues('SEAT_EMOJI', ['https://x/a', 'https://x/a'])).toEqual([
      { path: [1], issue: 'duplicate_value' },
    ]);
  });

  it('composite: every field, each checked; no other field', () => {
    expect(issues('PINNED_MESSAGE', { count: 3, seconds: 60 })).toEqual([]);
    expect(issues('MONTHLY_ROCKETS', { count: 2, stage: 'STAGE_3' })).toEqual([]);
    expect(vipPerkValueIssues('MONTHLY_ROCKETS', { count: 0, stage: 'STAGE_9', extra: 1 })).toEqual([
      { path: ['extra'], issue: 'unknown_field' },
      { path: ['count'], issue: 'out_of_range' },
      { path: ['stage'], issue: 'invalid_value' },
    ]);
    expect(vipPerkValueIssues('PINNED_MESSAGE', { count: 3 })).toEqual([
      { path: ['seconds'], issue: 'required' },
    ]);
    expect(issues('PINNED_MESSAGE', [3, 60])).toEqual(['invalid_type']);
  });

  it('a code outside the catalogue (a retired one included) is unknown', () => {
    expect(issues('NOT_A_PERK', null)).toEqual(['unknown_perk']);
    expect(issues('DAILY_COINS', 5)).toEqual(['unknown_perk']);
  });
});

describe('D374 the panel body (vipPerkInput)', () => {
  const issuesOf = (body: unknown) => {
    const r = vipPerkInput.safeParse(body);
    return r.success
      ? []
      : r.error.issues.map((i) => ({
          path: i.path.join('.'),
          issue: (i as { params?: { issue?: string } }).params?.issue ?? i.code,
        }));
  };

  it('a catalogue code alone is enough (titles default); an unknown or retired code is refused', () => {
    expect(issuesOf({ code: 'HIDDEN_VISIT' })).toEqual([]);
    expect(issuesOf({ code: 'MADE_UP' })).toEqual([{ path: 'code', issue: 'unknown_perk' }]);
    expect(issuesOf({ code: 'DAILY_COINS', amount: 5 })).toEqual([{ path: 'code', issue: 'unknown_perk' }]);
  });

  it('legacy amounts: `amount` or `value`, both must agree, bounds kept', () => {
    expect(issuesOf({ code: 'DAILY_BULLET', amount: 5 })).toEqual([]);
    expect(issuesOf({ code: 'DAILY_BULLET', value: 5 })).toEqual([]);
    expect(issuesOf({ code: 'DAILY_BULLET', amount: 5, value: 5 })).toEqual([]);
    expect(issuesOf({ code: 'DAILY_BULLET', amount: 5, value: 6 })).toEqual([
      { path: 'value', issue: 'invalid_value' },
    ]);
    expect(issuesOf({ code: 'LEVEL_SPEEDUP', amount: 101 })).toEqual([
      { path: 'amount', issue: 'out_of_range' },
    ]);
    expect(issuesOf({ code: 'BADGE', amount: 1 })).toEqual([{ path: 'amount', issue: 'not_allowed' }]);
  });

  it('values are checked at their path; an MP4 only where the art takes MP4', () => {
    expect(issuesOf({ code: 'MONTHLY_ROCKETS', value: { count: 99, stage: 'STAGE_1' } })).toEqual([
      { path: 'value.count', issue: 'out_of_range' },
    ]);
    expect(issuesOf({ code: 'ANIMATED_COVER', video: 'https://cdn.example/c.mp4' })).toEqual([]);
    expect(issuesOf({ code: 'BADGE', video: 'https://cdn.example/c.mp4' })).toEqual([
      { path: 'video', issue: 'not_allowed' },
    ]);
  });

  it('a tier takes more than 20 perks (the whole catalogue)', () => {
    const body = {
      code: 'VIP_9',
      nameAr: 'في آي بي ٩',
      nameEn: 'VIP 9',
      color: '#AA8800',
      priceCoins: 1000,
      durationDays: 30,
      reason: 'test',
      perks: VIP_PERK_CATALOGUE.map((e) => ({ code: e.code })),
    };
    expect(VIP_PERK_CATALOGUE.length).toBeGreaterThan(20);
    expect(createVipTierBody.safeParse(body).success).toBe(true);
  });
});

describe('D374 inheritance is unchanged (vipEffectivePerks)', () => {
  it('a higher tier holds the lower tiers’ perks; the highest row wins for a code; values travel with the row', () => {
    const p = (code: string, value: unknown, enabled = true) => ({ code, value, enabled });
    const tiers = [
      { rank: 1, perks: [p('DAILY_BULLET', 3), p('SEAT_RESERVE', 5)] },
      { rank: 2, perks: [p('DAILY_BULLET', 10), p('LONGER_VOICE', 180, false)] },
    ];
    const two = vipEffectivePerks(tiers, 2);
    expect([...two.keys()].sort()).toEqual(['DAILY_BULLET', 'SEAT_RESERVE']);
    expect(two.get('DAILY_BULLET')?.value).toBe(10);
    expect(two.get('SEAT_RESERVE')?.value).toBe(5);
  });
});
