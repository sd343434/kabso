import { describe, expect, it } from 'vitest';
import {
  DESIGN_BOARD_KINDS,
  DESIGN_SECTIONS,
  designAudit,
  designChoices,
  designProblems,
  eventDesignSchema,
  parseStoredDesign,
  type DesignBoard,
} from './event-design.js';
import { EVENT_MEDIA_KINDS, EVENT_MEDIA_SPECS } from './event-media.js';
import { EVENT_BOARD_KINDS, designBoardsOf, giftEventInputSchema } from './gift-events.js';

const base = { v: 1, layout: 'HERO_PODIUM' } as const;
const design = (over: Record<string, unknown> = {}) => eventDesignSchema.parse({ ...base, ...over });
const sections = (hidden: string[] = [], order: readonly string[] = DESIGN_SECTIONS) =>
  order.map((id) => ({ id, visible: !hidden.includes(id) }));
const senders: DesignBoard = {
  kind: 'SENDERS',
  shown: 20,
  lines: [
    { rankFrom: 1, rankTo: 1, items: 3 },
    { rankFrom: 2, rankTo: 2, items: 2 },
    { rankFrom: 3, rankTo: 3, items: 2 },
    { rankFrom: 4, rankTo: 10, items: 1 },
  ],
};
const issues = (d: Record<string, unknown>, boards: DesignBoard[] = [senders]) =>
  designProblems(design(d), boards).map((p) => p.issue);

describe('D354 event page design (v1.115-social)', () => {
  it('fills every default of a minimal design (null → today’s page is the caller’s choice)', () => {
    expect(design()).toEqual({
      v: 1,
      layout: 'HERO_PODIUM',
      leaderboard: 'THRONE',
      countdown: 'CLASSIC',
      preset: 'CLASSIC',
      rulesButton: null,
      sections: DESIGN_SECTIONS.map((id) => ({ id, visible: true })),
      leaderboardBackgroundMediaId: null,
      rewards: null,
      motion: {
        entrance: 'FADE',
        durationMs: 450,
        shimmer: true,
        pulseFirst: true,
        overlaySpeed: 1,
        overlayOpacity: 1,
      },
    });
  });

  it('accepts every option of every enum', () => {
    const c = designChoices();
    expect(c.layouts).toHaveLength(3);
    expect(c.leaderboards).toHaveLength(5);
    expect(c.countdowns).toHaveLength(6);
    expect(c.presets).toHaveLength(6);
    expect(c.rulesButtons).toHaveLength(6);
    for (const layout of c.layouts) expect(design({ layout }).layout).toBe(layout);
    for (const leaderboard of c.leaderboards) expect(design({ leaderboard }).leaderboard).toBe(leaderboard);
    for (const countdown of c.countdowns) expect(design({ countdown }).countdown).toBe(countdown);
    for (const preset of c.presets) expect(design({ preset }).preset).toBe(preset);
    for (const style of c.rulesButtons) {
      for (const edge of c.edges) {
        expect(design({ rulesButton: { style, edge } }).rulesButton).toEqual({ style, edge });
      }
    }
    for (const entrance of c.entrances)
      expect(design({ motion: { entrance } }).motion.entrance).toBe(entrance);
  });

  it('refuses unknown values, versions and fields (shape: 400 from the pipe)', () => {
    for (const bad of [
      { v: 2, layout: 'HERO_PODIUM' },
      { v: 1 },
      { v: 1, layout: 'GRID' },
      { ...base, leaderboard: 'TOWER' },
      { ...base, countdown: 'PILL' },
      { ...base, preset: 'PINK' },
      { ...base, rulesButton: { style: 'BUBBLE' } },
      { ...base, rulesButton: { style: 'SIDE_TAB', edge: 'LEFT' } },
      { ...base, sections: sections().slice(0, 4) },
      { ...base, sections: [...sections(), { id: 'GIFTS', visible: true }] },
      { ...base, leaderboardBackgroundMediaId: 'not-a-uuid' },
      { ...base, motion: { durationMs: 1600 } },
      { ...base, motion: { overlaySpeed: 3 } },
      { ...base, motion: { overlayOpacity: -0.1 } },
      { ...base, rewards: { tiers: [] } },
      { ...base, extra: true },
    ]) {
      expect(eventDesignSchema.safeParse(bad).success, JSON.stringify(bad)).toBe(false);
    }
  });

  it('sections: each once; RULES hidden needs a rules button; BOARDS visible when the event has boards', () => {
    const order = ['BOARDS', 'REWARDS', 'GIFTS', 'MILESTONES', 'RULES'];
    expect(issues({ sections: sections([], order) })).toEqual([]);
    expect(issues({ sections: [...sections().slice(0, 4), { id: 'GIFTS', visible: true }] })).toEqual([
      'design_sections',
    ]);
    expect(issues({ sections: sections(['RULES']) })).toEqual(['design_rules_unreachable']);
    expect(issues({ sections: sections(['RULES']), rulesButton: { style: 'GOLD_PILL' } })).toEqual([]);
    expect(issues({ sections: sections(['BOARDS']) })).toEqual(['design_boards_required']);
    // A draft without boards yet may hide them.
    expect(issues({ sections: sections(['BOARDS']) }, [])).toEqual([]);
    expect(issues({ sections: sections(['GIFTS', 'REWARDS', 'MILESTONES']) })).toEqual([]);
  });

  it('tiers: rank ranges of a board inside one prize line, in order, within the places, featured of that line', () => {
    const tier = (from: number, to: number, over: Record<string, unknown> = {}) => ({
      board: 'SENDERS',
      from,
      to,
      ...over,
    });
    const ok = [tier(1, 1, { featured: [0, 2], labelAr: 'البطل' }), tier(2, 2), tier(3, 3), tier(4, 10)];
    expect(issues({ rewards: { tiers: ok } })).toEqual([]);
    // A line may be split into narrower tiers (5–6 and 7–10 both inside 4–10).
    expect(issues({ rewards: { tiers: [tier(5, 6), tier(7, 10)] } })).toEqual([]);
    expect(issues({ rewards: { tiers: [tier(1, 2)] } })).toEqual(['design_tier_prize']);
    expect(issues({ rewards: { tiers: [tier(11, 12)] } })).toEqual(['design_tier_prize']);
    expect(issues({ rewards: { tiers: [tier(2, 1)] } })).toEqual(['design_tier_range']);
    expect(issues({ rewards: { tiers: [tier(4, 21)] } })).toEqual(['design_tier_range']);
    expect(issues({ rewards: { tiers: [tier(2, 2), tier(1, 1)] } })).toEqual(['design_tier_overlap']);
    expect(issues({ rewards: { tiers: [tier(4, 6), tier(6, 8)] } })).toEqual(['design_tier_overlap']);
    expect(issues({ rewards: { tiers: [tier(1, 1, { featured: [3] })] } })).toEqual(['design_tier_featured']);
    expect(issues({ rewards: { tiers: [tier(1, 1, { featured: [1, 1] })] } })).toEqual([
      'design_tier_featured',
    ]);
    expect(issues({ rewards: { tiers: [tier(1, 1, { board: 'CP' })] } })).toEqual(['design_tier_board']);
    // Another board's tiers are ordered on their own.
    const receivers: DesignBoard = {
      kind: 'RECEIVERS',
      shown: 5,
      lines: [{ rankFrom: 1, rankTo: 5, items: 1 }],
    };
    expect(
      issues({ rewards: { tiers: [tier(4, 10), tier(1, 5, { board: 'RECEIVERS' })] } }, [senders, receivers]),
    ).toEqual([]);
    expect(
      issues({ rewards: { tiers: [tier(1, 6, { board: 'RECEIVERS' })] } }, [senders, receivers]),
    ).toEqual(['design_tier_range']);
  });

  it('the gift event body carries the design: 400 issues on its paths, absent ≠ null', () => {
    const body = {
      titleAr: 'فعالية',
      titleEn: 'Event',
      startsAt: '2026-11-08T00:00:00Z',
      endsAt: '2026-11-15T00:00:00Z',
      gifts: [{ giftCode: 'rose' }],
      boards: [
        { kind: 'SENDERS', prizes: [{ rankFrom: 1, rankTo: 3, items: [{ type: 'COINS', amount: 10 }] }] },
      ],
      reason: 'D354 test',
    };
    expect(giftEventInputSchema.parse(body).design).toBeUndefined();
    expect(giftEventInputSchema.parse({ ...body, design: null }).design).toBeNull();
    expect(giftEventInputSchema.parse({ ...body, design: base }).design?.layout).toBe('HERO_PODIUM');
    const bad = giftEventInputSchema.safeParse({
      ...body,
      design: {
        ...base,
        sections: sections(['BOARDS']),
        rewards: { tiers: [{ board: 'SENDERS', from: 2, to: 4 }] },
      },
    });
    expect(bad.success).toBe(false);
    const found = bad.error!.issues.map((i) => [
      i.path.join('.'),
      (i as { params?: { issue?: string } }).params?.issue,
    ]);
    expect(found).toEqual([
      ['design.sections', 'design_boards_required'],
      ['design.rewards.tiers.0', 'design_tier_prize'],
    ]);
    // A board whose places the body leaves out is bounded by 100 here; the service checks the stored value.
    expect(designBoardsOf([{ kind: 'SENDERS', prizes: [] }])[0]!.shown).toBeNull();
    expect(designBoardsOf([{ kind: 'SENDERS', prizes: [] }], new Map([['SENDERS', 7]]))[0]!.shown).toBe(7);
    expect(designBoardsOf([{ kind: 'SENDERS', prizes: [] }], new Map())[0]!.shown).toBe(20);
  });

  it('a stored design that no longer parses reads as none; the audit summary is short', () => {
    expect(parseStoredDesign(null)).toBeNull();
    expect(parseStoredDesign({ v: 2, layout: 'STAGE' })).toBeNull();
    expect(parseStoredDesign({ v: 1, layout: 'STAGE' })?.layout).toBe('STAGE');
    expect(designAudit(null)).toBeNull();
    expect(
      designAudit(
        design({
          rulesButton: { style: 'SIDE_TAB', edge: 'START' },
          sections: sections(['RULES']),
          rewards: { tiers: [{ board: 'SENDERS', from: 1, to: 1 }] },
        }),
      ),
    ).toMatchObject({
      rulesButton: 'SIDE_TAB:START',
      sections: expect.arrayContaining(['RULES:hidden']),
      tiers: ['SENDERS:1-1'],
    });
  });

  it('keeps its board kinds in step with gift-events.ts; the background is an event media kind', () => {
    expect([...DESIGN_BOARD_KINDS]).toEqual([...EVENT_BOARD_KINDS]);
    expect(EVENT_MEDIA_KINDS).toContain('board_background');
    expect(EVENT_MEDIA_SPECS.board_background).toMatchObject({
      width: 1080,
      height: 1440,
      maxAnimatedBytes: null,
      transparent: false,
    });
  });
});
