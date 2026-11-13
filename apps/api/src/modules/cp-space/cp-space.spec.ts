import { describe, expect, it } from 'vitest';
import { CP_GIFT_AMOUNTS, CP_GIFT_PRESETS, CP_TIERS, cpGiftPresetFor } from '../couples/couples.constants.js';
import { CP_PRIVILEGES, cpHasPrivilege, cpPrivilegeName, cpPrivilegesFor } from './cp-privileges.js';
import { CP_RANKING_MAX, CP_RANKING_PERIODS, CP_TASKS } from './cp-space.constants.js';
import { cpConfessionCreateSchema, cpRankingsQuerySchema } from './cp-space.schemas.js';

describe('CP-021 privileges (D112)', () => {
  it('unlocks one privilege per CP tier 1–5, in order (nothing new at 6, D113)', () => {
    expect(CP_PRIVILEGES.map((p) => [p.code, p.unlockLevel])).toEqual([
      ['SPECIAL_FRAME', 1],
      ['CHAT_BUBBLE', 2],
      ['MIC_EFFECT', 3],
      ['ENTRANCE_EFFECT', 4],
      ['GIFT_WALL', 5],
    ]);
    expect(CP_PRIVILEGES.map((p) => p.unlockLevel)).toEqual(
      CP_TIERS.filter((t) => t.level <= 5).map((t) => t.level),
    );
  });

  it('cpPrivilegesFor returns the codes unlocked at a level', () => {
    expect(cpPrivilegesFor(1)).toEqual(['SPECIAL_FRAME']);
    expect(cpPrivilegesFor(2)).toEqual(['SPECIAL_FRAME', 'CHAT_BUBBLE']);
    expect(cpPrivilegesFor(4)).toEqual(['SPECIAL_FRAME', 'CHAT_BUBBLE', 'MIC_EFFECT', 'ENTRANCE_EFFECT']);
    expect(cpPrivilegesFor(5)).toHaveLength(5);
    // D113: nothing new unlocks at CP level 6.
    expect(cpPrivilegesFor(6)).toEqual(cpPrivilegesFor(5));
    expect(cpPrivilegesFor(0)).toEqual([]);
    expect(cpHasPrivilege(1, 'CHAT_BUBBLE')).toBe(false);
    expect(cpHasPrivilege(2, 'CHAT_BUBBLE')).toBe(true);
    expect(cpHasPrivilege(4, 'GIFT_WALL')).toBe(false);
    expect(cpHasPrivilege(5, 'GIFT_WALL')).toBe(true);
  });

  it('names every privilege in Arabic and English', () => {
    for (const p of CP_PRIVILEGES) {
      expect(cpPrivilegeName(p, 'ar')).toMatch(/\p{Script=Arabic}/u);
      expect(cpPrivilegeName(p, 'en')).toMatch(/^[A-Z]/);
      expect(p.iconKey).toMatch(/^cp_priv_[a-z_]+$/);
    }
  });
});

describe('CP-021 gift cards (D112)', () => {
  it("maps the owner's five names to the gift amounts ascending", () => {
    expect(CP_GIFT_PRESETS.map((g) => g.amount)).toEqual([...CP_GIFT_AMOUNTS]);
    expect(CP_GIFT_PRESETS.map((g) => [g.code, g.nameEn, g.nameAr])).toEqual([
      ['rose_love', 'Rose Love', 'وردة الحب'],
      ['angel_heart', 'Angel Heart', 'قلب الملاك'],
      ['love_carriage', 'Love Carriage', 'عربة الحب'],
      ['swan_love', 'Swan Love', 'بجعتا الحب'],
      ['eternal_heart', 'Eternal Heart', 'القلب الأبدي'],
    ]);
    for (const g of CP_GIFT_PRESETS) expect(g.assetKey).toBe(`cp_gift_${g.code}`);
    expect(cpGiftPresetFor(520)?.code).toBe('swan_love');
    expect(cpGiftPresetFor(7)).toBeNull();
  });
});

describe('CP-021 daily tasks (D112)', () => {
  it('has unique codes, positive rewards and targets, and both names', () => {
    expect(CP_TASKS.map((t) => t.code)).toEqual(['CHECK_IN', 'SEND_GIFT', 'CHAT_TOGETHER']);
    expect(CP_TASKS.map((t) => [t.reward, t.target])).toEqual([
      [10, 2],
      [20, 1],
      [30, 1],
    ]);
    for (const t of CP_TASKS) {
      expect(t.code).toMatch(/^[A-Z][A-Z0-9_]{0,39}$/);
      expect(t.nameAr).toMatch(/\p{Script=Arabic}/u);
      expect(t.descriptionEn.length).toBeGreaterThan(0);
    }
  });
});

describe('CP-021 request schemas', () => {
  const clientId = '0192f1d0-9999-7000-8000-000000000011';

  it('normalizes a confession like chat text and bounds it to 200 code points', () => {
    const ok = cpConfessionCreateSchema.safeParse({ text: '  أحبك ❤  ', clientId });
    expect(ok.success && ok.data.text).toBe('أحبك ❤');
    const issue = (text: string) => {
      const r = cpConfessionCreateSchema.safeParse({ text, clientId });
      return r.success ? null : (r.error.issues[0]?.message ?? null);
    };
    expect(issue('   ')).toBe('required');
    expect(issue('a\nb')).toBe('invalid_format');
    expect(issue('x'.repeat(201))).toBe('too_long');
    expect(issue('x'.repeat(200))).toBeNull();
    expect(issue('bad\u0000char')).toBe('invalid_format');
    expect(cpConfessionCreateSchema.safeParse({ text: 'hi', clientId, extra: 1 }).success).toBe(false);
  });

  it('defaults the ranking period to WEEK and refuses others', () => {
    expect(CP_RANKING_PERIODS).toEqual(['WEEK', 'ALL']);
    expect(CP_RANKING_MAX).toBe(100);
    expect(cpRankingsQuerySchema.parse({})).toEqual({ period: 'WEEK', limit: 20 });
    expect(cpRankingsQuerySchema.parse({ period: 'ALL', limit: '5' })).toEqual({ period: 'ALL', limit: 5 });
    expect(cpRankingsQuerySchema.safeParse({ period: 'DAY' }).success).toBe(false);
  });
});
