import { describe, expect, it } from 'vitest';
import type { CatalogueGift } from './host-target-engine.js';
import { DEFAULT_POOL_TASKS, DEFAULT_TASK_POOL_BANDS } from './programs-rules.js';
import {
  assignSmartTasks,
  enumerateTasks,
  taskCatalogueStats,
  taskCompletionFactor,
  taskSeed,
  usualWindow,
  variantName,
  variantReward,
  type TaskProfile,
  type TaskTemplate,
} from './task-catalogue.js';

const TEMPLATES: TaskTemplate[] = DEFAULT_POOL_TASKS.filter((t) => t.enabled !== false).map((t) => ({
  code: t.code,
  metric: t.metric,
  group: t.group,
  audience: t.audience,
  bandTargets: t.bandTargets,
  bandRewards: t.bandRewards,
  sortOrder: t.sortOrder,
  nameAr: t.nameAr,
  nameEn: t.nameEn,
}));

const GIFTS: CatalogueGift[] = [
  { code: 'rose', category: 'POPULAR', priceCoins: 10, nameAr: 'وردة', nameEn: 'Rose', lucky: false },
  { code: 'warrior', category: 'FUN', priceCoins: 1_000, nameAr: 'المحارب', nameEn: 'Warrior', lucky: false },
  { code: 'luck', category: 'LUCKY', priceCoins: 10, nameAr: 'حظ', nameEn: 'Luck', lucky: true },
];

const profile = (over: Partial<TaskProfile> = {}): TaskProfile => ({
  band: DEFAULT_TASK_POOL_BANDS[1]!,
  isHost: false,
  dailyAverage: {},
  recentAssigned: 0,
  recentClaimed: 0,
  recentVariants: [],
  yesterdayTemplates: [],
  inFamily: false,
  favouriteGifts: [],
  activeHours: new Array<number>(24).fill(0),
  ...over,
});

describe('D281 the Task Center catalogue', () => {
  it('holds more than 100 000 distinct tasks from the default templates — even with no gifts', () => {
    const count = (gifts: CatalogueGift[]) => {
      const codes = new Set<string>();
      for (const v of enumerateTasks(TEMPLATES, gifts)) codes.add(v.code);
      return codes.size;
    };
    const none = count([]);
    expect(none).toBeGreaterThan(100_000);
    const withGifts = count(GIFTS);
    expect(withGifts).toBeGreaterThan(none);
    expect(taskCatalogueStats(TEMPLATES, GIFTS).total).toBe(withGifts);
    // The host targets' metric (P_HOST_GIFTS) is never a Task Center task any more.
    expect(taskCatalogueStats(TEMPLATES, GIFTS).byTemplate.P_HOST_GIFTS).toBeUndefined();
  });

  it('rewards follow the Task Center rules: symbolic for actions, ≈ 1 % of the coin value for money tasks', () => {
    const t = (code: string) => TEMPLATES.find((x) => x.code === code)!;
    // Band 2 «comment in a live»: 5 → 500 cherries; double → 1 000; ten times → still 1 000 (≤ 2×); one → 250 (≥ ½).
    expect(variantReward(t('P_LIVE_COMMENTS'), 2, 5, 5)).toBe(500);
    expect(variantReward(t('P_LIVE_COMMENTS'), 2, 10, 10)).toBe(1_000);
    expect(variantReward(t('P_LIVE_COMMENTS'), 2, 50, 50)).toBe(1_000);
    expect(variantReward(t('P_LIVE_COMMENTS'), 2, 1, 1)).toBe(250);
    // «Send gifts» band 2: 25 000 coins → 2 500; the same rate for 10 000 coins (never a higher rate).
    expect(variantReward(t('P_SEND_GIFTS'), 2, 25_000, 25_000)).toBe(2_500);
    expect(variantReward(t('P_SEND_GIFTS'), 2, 10_000, 10_000)).toBe(1_000);
    // A chosen gift: 10 × the warrior = 10 000 coins → 1 000 (0.1 cherry a coin, as «send gifts»).
    expect(variantReward(t('P_SEND_GIFT_OF'), 2, 10, 10_000)).toBe(1_000);
  });

  it('the completion factor and the usual hours', () => {
    expect(taskCompletionFactor(0, 4)).toBe(1);
    expect(taskCompletionFactor(0, 10)).toBe(0.7);
    expect(taskCompletionFactor(10, 10)).toBe(1.3);
    const hours = new Array<number>(24).fill(0);
    hours[20] = 5;
    hours[21] = 5;
    hours[3] = 1;
    expect(usualWindow(hours)).toEqual({ from: 19 * 60, to: 22 * 60 });
    expect(usualWindow(new Array<number>(24).fill(1))).toBeNull();
  });
});

describe('D281 the smart task assignment', () => {
  it('deterministic per person and day; the band’s count; no template twice; host tasks for hosts only', () => {
    const p = profile();
    const a = assignSmartTasks(TEMPLATES, p, GIFTS, taskSeed('u1', '2027-01-31'));
    expect(assignSmartTasks(TEMPLATES, p, GIFTS, taskSeed('u1', '2027-01-31'))).toEqual(a);
    expect(a).toHaveLength(DEFAULT_TASK_POOL_BANDS[1]!.dailyCount);
    expect(new Set(a.map((x) => x.template)).size).toBe(a.length);
    expect(a.some((x) => TEMPLATES.find((t) => t.code === x.template)!.audience === 'HOSTS')).toBe(false);
    const host = assignSmartTasks(TEMPLATES, profile({ isHost: true }), GIFTS, 3);
    expect(
      host.slice(0, 2).every((x) => TEMPLATES.find((t) => t.code === x.template)!.audience === 'HOSTS'),
    ).toBe(true);
    for (const x of a) {
      expect(x.rewardCherries).toBeGreaterThan(0);
      expect(x.target).toBe(x.variant.amount);
    }
  });

  it('reads the person: what they do weighs more, amounts follow their own average and completion', () => {
    // A heavy chatter: «comment in a live» is picked far more often and its amount follows their 40 a day.
    let picked = 0;
    const amounts: number[] = [];
    for (let s = 0; s < 200; s++) {
      const x = assignSmartTasks(
        TEMPLATES,
        profile({ dailyAverage: { LIVE_CHAT_MESSAGES: 40 } }),
        GIFTS,
        s,
      ).find((y) => y.template === 'P_LIVE_COMMENTS');
      if (x) {
        picked += 1;
        if (x.variant.window.from === 0 && x.variant.window.to === 1440) amounts.push(x.target);
      }
    }
    let baseline = 0;
    for (let s = 0; s < 200; s++) {
      if (assignSmartTasks(TEMPLATES, profile(), GIFTS, s).some((y) => y.template === 'P_LIVE_COMMENTS'))
        baseline += 1;
    }
    expect(picked).toBeGreaterThan(baseline);
    // 40 a day, capped at 3 × the band's target (5) = 15.
    expect(new Set(amounts)).toEqual(new Set([15]));
    // Never finishes → smaller; always finishes → larger (within the band's limits).
    const at = (claimed: number) =>
      assignSmartTasks(
        TEMPLATES,
        profile({ dailyAverage: { WATCH_MINUTES: 20 }, recentAssigned: 20, recentClaimed: claimed }),
        GIFTS,
        11,
      ).find((y) => y.template === 'P_WATCH_MINUTES');
    const low = at(0);
    const high = at(20);
    if (low && high && low.variant.window.to === 1440 && high.variant.window.to === 1440) {
      expect(high.target).toBeGreaterThan(low.target);
      expect(low.reason.factor).toBe(0.7);
      expect(high.reason.factor).toBe(1.3);
    }
  });

  it('no repeat within N days; family tasks by membership; a gift task names their favourite gift', () => {
    const a = assignSmartTasks(TEMPLATES, profile(), GIFTS, 5);
    const b = assignSmartTasks(
      TEMPLATES,
      profile({ recentVariants: a.map((x) => x.variant.code) }),
      GIFTS,
      5,
    );
    for (const x of b) expect(a.map((y) => y.variant.code)).not.toContain(x.variant.code);
    for (let s = 0; s < 100; s++) {
      const inFamily = assignSmartTasks(TEMPLATES, profile({ inFamily: true }), GIFTS, s).map(
        (x) => x.template,
      );
      expect(inFamily).not.toContain('P_FAMILY_JOIN');
      const outside = assignSmartTasks(TEMPLATES, profile(), GIFTS, s).map((x) => x.template);
      expect(outside).not.toContain('P_FAMILY_CHAT');
      const fav = assignSmartTasks(TEMPLATES, profile({ favouriteGifts: ['warrior'] }), GIFTS, s).find(
        (x) => x.template === 'P_SEND_GIFT_OF',
      );
      if (fav) {
        expect(fav.variant.subject).toBe('warrior');
        // Band 2: 10 000 coins = 10 warriors.
        expect(fav.target).toBe(10);
      }
    }
    const name = variantName(
      { metric: 'GIFT_COUNT_SENT', nameAr: 'x', nameEn: 'x' },
      { amount: 10, subject: 'warrior', window: { from: 1200, to: 1380 } },
      { ar: 'المحارب', en: 'Warrior' },
    );
    expect(name).toEqual({
      ar: 'أرسل 10 من المحارب بين 20:00–23:00',
      en: 'Send 10 × Warrior between 20:00–23:00',
    });
  });
});
