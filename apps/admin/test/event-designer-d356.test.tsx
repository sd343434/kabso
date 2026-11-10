/**
 * D356 (CONVENTIONS §10.152): the editor's «التصميم» step — the design form and body, the server's rules mirrored
 * (sections, the rules reachable, boards required, tiers within one prize line and the board's places, featured items
 * of that line), the server's 400 issues mapped to their fields, the reorder helpers, the draft the live preview draws
 * and the postMessage protocol (origin and window checked), the contrast warning, the step rendered in Arabic and
 * English, and the Caddyfile's preview headers equal to the local test server's.
 */
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { renderToStaticMarkup } from 'react-dom/server';
import { describe, expect, it } from 'vitest';
import { ApiError } from '../src/api';
import { AppContext, type AppState } from '../src/context';
import {
  CONTRAST_MIN,
  DESIGN_SECTIONS,
  PREVIEW_READY,
  PREVIEW_RENDER,
  brightColour,
  composite,
  contrastRatio,
  contrastWarnings,
  defaultDesign,
  designBody,
  designFromServer,
  designProblems,
  designServerProblems,
  luminance,
  moveSection,
  nextTier,
  offered,
  previewEvent,
  previewMessage,
  previewReply,
  previewUrl,
  problemsAt,
  sectionLock,
  setRulesButton,
  setSectionVisible,
  tiersFromLines,
  type DesignForm,
} from '../src/event-design';
import { SAMPLE_MY_RANK, sampleLeaderboards } from '../src/event-preview-sample';
import { formFromServer, giftEventBody, type BoardForm, type EventOptions, type GiftEventFormState } from '../src/gift-events';
import { translate, type Lang } from '../src/i18n';
import { EventEditor, newDraft } from '../src/pages/Events';
import { ContrastNotice, EventDesignFields, EventLivePreview, thumbnail } from '../src/pages/EventDesigner';

const state = (lang: Lang): AppState => ({
  lang,
  t: (key, vars) => translate(lang, key, vars),
  session: null,
  can: () => true,
  toast: () => undefined,
});
const html = (lang: Lang, node: React.ReactNode) =>
  renderToStaticMarkup(<AppContext.Provider value={state(lang)}>{node}</AppContext.Provider>);

const OPTIONS: EventOptions = {
  timeZone: 'UTC',
  boardKinds: ['SENDERS', 'RECEIVERS', 'CREATORS', 'AGENCIES', 'CP'],
  gifts: [{ code: 'rose', nameAr: 'وردة', nameEn: 'Rose', priceCoins: 100, enabled: true, imageUrl: 'https://m.test/rose.webp' }],
  bagItems: [{ code: 'frame_gold', category: 'AVATAR_FRAME', nameAr: 'إطار البطل', nameEn: 'Champion frame', stillUrl: null }],
  vipTiers: [{ code: 'gold', nameAr: 'ذهبي', nameEn: 'Gold', enabled: true }],
  badges: [{ code: 'medal', nameAr: 'وسام', nameEn: 'Medal', levels: [{ level: 2, imageUrl: 'https://m.test/m2.webp' }] }],
  giftCategories: [],
  specs: [
    {
      kind: 'board_background',
      width: 1080,
      height: 1440,
      formats: ['PNG', 'JPEG', 'WebP'],
      maxStillBytes: 2097152,
      maxAnimatedBytes: null,
      maxDurationMs: null,
      transparent: false,
      safeZone: null,
    },
  ],
};

const senders: BoardForm = {
  kind: 'SENDERS',
  minPoints: '1000',
  shown: '20',
  prizes: [
    { rankFrom: '1', rankTo: '1', items: [{ type: 'COINS', value: '100000', code: '' }, { type: 'BAG_ITEM', value: '7', code: 'frame_gold', permanent: true }] },
    { rankFrom: '2', rankTo: '3', items: [{ type: 'COINS', value: '50000', code: '' }] },
    { rankFrom: '4', rankTo: '10', items: [{ type: 'COINS', value: '5000', code: '' }] },
  ],
};

const design = (over: Partial<DesignForm> = {}): DesignForm => ({ ...defaultDesign(), ...over });
const issues = (d: DesignForm, boards: BoardForm[] = [senders]) => designProblems(d, boards).map((p) => p.issue);

const SERVER_DESIGN = {
  v: 1,
  layout: 'STAGE',
  leaderboard: 'SPOTLIGHT',
  countdown: 'RING',
  preset: 'GLASS',
  rulesButton: { style: 'SIDE_TAB', edge: 'START' },
  sections: ['BOARDS', 'REWARDS', 'GIFTS', 'RULES', 'MILESTONES'].map((id) => ({ id, visible: id !== 'RULES' })),
  leaderboardBackgroundMediaId: '01a1b6a1-0000-7000-8000-0000000000bb',
  leaderboardBackgroundUrl: 'https://m.test/bg.webp',
  rewards: { tiers: [{ board: 'SENDERS', from: 1, to: 1, labelAr: 'البطل', labelEn: null, featured: [1] }] },
  motion: { entrance: 'SLIDE', durationMs: 600, shimmer: false, pulseFirst: true, overlaySpeed: 0.5, overlayOpacity: 0.5 },
};

describe('the design form and its body', () => {
  it('reads the server’s design and writes the same body back (the response-only URL left out)', () => {
    const d = designFromServer(SERVER_DESIGN)!;
    expect(d.layout).toBe('STAGE');
    expect(d.rulesButton).toEqual({ style: 'SIDE_TAB', edge: 'START' });
    expect(d.backgroundUrl).toBe('https://m.test/bg.webp');
    expect(d.tiers?.[0]).toMatchObject({ from: '1', to: '1', labelAr: 'البطل', labelEn: '', featured: [1] });
    const { leaderboardBackgroundUrl: _, ...input } = SERVER_DESIGN;
    expect(designBody(d)).toEqual(input);
  });

  it('null, another version or an unknown layout is none; unknown choices fall back to their defaults', () => {
    expect(designFromServer(null)).toBeNull();
    expect(designFromServer({ v: 2, layout: 'STAGE' })).toBeNull();
    expect(designFromServer({ v: 1, layout: 'GRID' })).toBeNull();
    const d = designFromServer({ v: 1, layout: 'DECK', leaderboard: 'TOWER', sections: [{ id: 'RULES', visible: false }] })!;
    expect(d.leaderboard).toBe('THRONE');
    expect(d.sections.map((s) => s.id)).toEqual(['RULES', 'GIFTS', 'BOARDS', 'REWARDS', 'MILESTONES']);
    expect(d.motion).toEqual(defaultDesign().motion);
    expect(designBody(null)).toBeNull();
  });

  it('the event body carries the design only once the step has it (absent = kept by the server)', () => {
    const f = { ...newDraft('UTC'), titleAr: 'ف', titleEn: 'E', reason: 'test' };
    expect('design' in giftEventBody(f)).toBe(false);
    expect(giftEventBody({ ...f, design: null }).design).toBeNull();
    expect(giftEventBody({ ...f, design: design({ layout: 'DECK' }) }).design).toMatchObject({ v: 1, layout: 'DECK', rewards: null });
    const stored = { ...giftEventBody(f), bannerUrl: null };
    expect(formFromServer(stored, 'UTC').design).toBeUndefined();
    expect(formFromServer({ ...stored, design: null }, 'UTC').design).toBeNull();
    expect(formFromServer({ ...stored, design: SERVER_DESIGN }, 'UTC', 'https://m.test/new.webp').design?.backgroundUrl).toBe(
      'https://m.test/new.webp',
    );
  });

  it('reset keeps the uploaded background, every choice back to its default', () => {
    const d = defaultDesign(designFromServer(SERVER_DESIGN)!);
    expect(d).toMatchObject({ layout: 'HERO_PODIUM', preset: 'CLASSIC', rulesButton: null, tiers: null });
    expect(d.backgroundMediaId).toBe(SERVER_DESIGN.leaderboardBackgroundMediaId);
  });

  it('offers only what the server lists (an older server lists nothing new)', () => {
    expect(offered(['A', 'B', 'C'] as const, ['A', 'C', 'Z'])).toEqual(['A', 'C']);
    expect(offered(['A', 'B'] as const, undefined)).toEqual(['A', 'B']);
  });
});

describe('the server’s rules, mirrored', () => {
  it('the defaults are fine', () => {
    expect(issues(design())).toEqual([]);
  });

  it('sections: each once; the rules reachable; the ranking shown when there are boards', () => {
    expect(issues(design({ sections: [...defaultDesign().sections.slice(0, 4), { id: 'GIFTS', visible: true }] }))).toContain(
      'design_sections',
    );
    const hiddenRules = design({ sections: defaultDesign().sections.map((s) => ({ ...s, visible: s.id !== 'RULES' })) });
    expect(issues(hiddenRules)).toEqual(['design_rules_unreachable']);
    expect(issues({ ...hiddenRules, rulesButton: { style: 'GOLD_PILL', edge: 'END' } })).toEqual([]);
    const hiddenBoards = design({ sections: defaultDesign().sections.map((s) => ({ ...s, visible: s.id !== 'BOARDS' })) });
    expect(issues(hiddenBoards)).toEqual(['design_boards_required']);
    // A draft without boards may hide it.
    expect(issues(hiddenBoards, [])).toEqual([]);
  });

  it('tiers: a board of the event, within its places, in order, inside one line, featured items of that line', () => {
    const tier = (from: string, to: string, featured: number[] = [], board: BoardForm['kind'] = 'SENDERS') => ({
      board,
      from,
      to,
      labelAr: '',
      labelEn: '',
      featured,
    });
    expect(issues(design({ tiers: [tier('1', '1', [1]), tier('2', '2'), tier('3', '3'), tier('4', '10')] }))).toEqual([]);
    expect(issues(design({ tiers: [tier('1', '1', [], 'CP')] }))).toEqual(['design_tier_board']);
    expect(issues(design({ tiers: [tier('3', '2')] }))).toEqual(['design_tier_range']);
    expect(issues(design({ tiers: [tier('4', '25')] }))).toEqual(['design_tier_range']);
    expect(issues(design({ tiers: [tier('5', '9')] }), [{ ...senders, shown: '8' }])).toEqual(['design_tier_range']);
    expect(issues(design({ tiers: [tier('2', '2'), tier('1', '1')] }))).toEqual(['design_tier_overlap']);
    expect(issues(design({ tiers: [tier('1', '2')] }))).toEqual(['design_tier_prize']);
    expect(issues(design({ tiers: [tier('11', '12')] }))).toEqual(['design_tier_prize']);
    expect(issues(design({ tiers: [tier('1', '1', [2])] }))).toEqual(['design_tier_featured']);
    expect(issues(design({ tiers: [tier('1', '1', [0, 0])] }))).toEqual(['design_tier_featured']);
    expect(issues(design({ tiers: [{ ...tier('1', '1'), labelAr: 'x'.repeat(25) }] }))).toEqual(['design_tier_label']);
    const p = designProblems(design({ tiers: [tier('1', '1'), tier('2', '9')] }), [senders]);
    expect(p).toEqual([{ field: 'design.rewards.tiers.1', issue: 'design_tier_prize', tier: 1 }]);
  });

  it('the default tiers are the board’s prize lines; a new tier follows the last one inside a line', () => {
    expect(tiersFromLines(senders).map((t) => `${t.from}-${t.to}`)).toEqual(['1-1', '2-3', '4-10']);
    expect(tiersFromLines({ ...senders, shown: '5' }).map((t) => `${t.from}-${t.to}`)).toEqual(['1-1', '2-3', '4-5']);
    const d = design({ tiers: tiersFromLines(senders).slice(0, 2) });
    expect(nextTier(d, senders)).toMatchObject({ from: '4', to: '4' });
    expect(nextTier(design({ tiers: tiersFromLines(senders) }), senders)).toBeNull();
  });

  it('the server’s 400 design issues go to their fields', () => {
    const err = new ApiError(400, 'VALIDATION_FAILED', 'Validation failed', null, [
      { field: 'design.rewards.tiers.2', issue: 'design_tier_overlap' },
      { field: 'design.rulesButton', issue: 'design_rules_unreachable' },
      { field: 'design.leaderboardBackgroundMediaId', issue: 'invalid_value' },
      { field: 'titleAr', issue: 'too_long' },
    ]);
    const p = designServerProblems(err);
    expect(p).toHaveLength(3);
    expect(problemsAt(p, 2)).toEqual([{ field: 'design.rewards.tiers.2', issue: 'design_tier_overlap', tier: 2 }]);
    expect(problemsAt(p, 'rules').map((x) => x.issue)).toEqual(['design_rules_unreachable']);
    expect(problemsAt(p, 'background').map((x) => x.issue)).toEqual(['invalid_value']);
    expect(designServerProblems(new ApiError(409, 'EVENT_LOCKED', 'x'))).toEqual([]);
    expect(designServerProblems(new Error('x'))).toEqual([]);
  });
});

describe('order and visibility', () => {
  it('moves a section (drag and drop or ↑ / ↓) and keeps every id once', () => {
    const d = moveSection(design(), 3, 0);
    expect(d.sections.map((s) => s.id)).toEqual(['REWARDS', 'GIFTS', 'RULES', 'BOARDS', 'MILESTONES']);
    expect(moveSection(d, 0, 9)).toBe(d);
    expect(new Set(moveSection(d, 4, 1).sections.map((s) => s.id)).size).toBe(DESIGN_SECTIONS.length);
  });

  it('refuses to hide the ranking of an event with boards and the rules without a button', () => {
    expect(sectionLock(design(), 'BOARDS', true)).toBe('design_boards_required');
    expect(sectionLock(design(), 'BOARDS', false)).toBeNull();
    expect(sectionLock(design(), 'RULES', true)).toBe('design_rules_unreachable');
    expect(setSectionVisible(design(), 'BOARDS', false, true).sections.find((s) => s.id === 'BOARDS')?.visible).toBe(true);
    expect(setSectionVisible(design(), 'GIFTS', false, true).sections.find((s) => s.id === 'GIFTS')?.visible).toBe(false);
    const withButton = setRulesButton(design(), { style: 'ROUND_ICON', edge: 'START' });
    const hidden = setSectionVisible(withButton, 'RULES', false, true);
    expect(hidden.sections.find((s) => s.id === 'RULES')?.visible).toBe(false);
    // Removing the button brings the rules back.
    expect(setRulesButton(hidden, null).sections.find((s) => s.id === 'RULES')?.visible).toBe(true);
  });
});

describe('the live preview', () => {
  const form = (over: Partial<GiftEventFormState> = {}): GiftEventFormState => ({
    ...newDraft('Asia/Riyadh'),
    titleAr: 'ملك الهدايا',
    titleEn: 'Gift King',
    rulesAr: 'القواعد',
    rulesEn: 'Rules',
    gifts: [{ giftCode: 'rose', pointsPerCoin: '1.5', pointsPerGift: '10' }],
    boards: [senders],
    milestones: [{ board: 'SENDERS', points: '1000', items: [{ type: 'BADGE', value: '7', code: 'medal', level: '2' }] }],
    reason: '',
    design: design({ preset: 'NEON', backgroundMediaId: 'm1', backgroundUrl: 'https://m.test/bg.webp' }),
    ...over,
  });

  it('draws the draft as the app’s EventDetail: titles, gifts, boards, prize items, milestones, art, the design', () => {
    const e = previewEvent(form({ backgroundKey: 'events/bg/a.mp4' }), OPTIONS, { background: 'https://m.test/a.mp4', backgroundPoster: 'https://m.test/p.webp', title: 'https://m.test/t.webp' }, 'ar', 'e1');
    expect(e).toMatchObject({ id: 'e1', title: 'ملك الهدايا', rules: 'القواعد', metric: 'EVENT_GIFTS' });
    expect(e.art).toEqual({
      background: { kind: 'VIDEO', url: 'https://m.test/a.mp4', posterUrl: 'https://m.test/p.webp' },
      titleUrl: 'https://m.test/t.webp',
      overlay: null,
    });
    expect(e.gifts).toEqual([
      { code: 'rose', name: 'وردة', priceCoins: 100, assetKey: 'rose', imageUrl: 'https://m.test/rose.webp', pointsPerCoin: 1.5, pointsPerGift: 10, pointsEach: 160 },
    ]);
    const boards = e.boards as { prizes: { items: Record<string, unknown>[] }[]; shown: number }[];
    expect(boards[0]!.shown).toBe(20);
    expect(boards[0]!.prizes[0]!.items).toEqual([
      { type: 'COINS', amount: 100000 },
      { type: 'BAG_ITEM', code: 'frame_gold', name: 'إطار البطل', category: 'AVATAR_FRAME', days: null, stillUrl: null },
    ]);
    expect((e.milestones as { prize: unknown[] }[])[0]!.prize).toEqual([
      { type: 'BADGE', code: 'medal', name: 'وسام', category: 'BADGE', level: 2, days: 7, imageUrl: 'https://m.test/m2.webp' },
    ]);
    expect(e.design).toMatchObject({ v: 1, preset: 'NEON', leaderboardBackgroundMediaId: 'm1', leaderboardBackgroundUrl: 'https://m.test/bg.webp' });
    expect(previewEvent(form(), OPTIONS, {}, 'en').title).toBe('Gift King');
    expect(previewEvent(form({ design: null }), OPTIONS, {}, 'en').design).toBeNull();
    expect(previewEvent(form({ titleAr: '', titleEn: '' }), OPTIONS, {}, 'ar').title).toBe('—');
  });

  it('the render message is versioned JSON text with an increasing sequence', () => {
    const s = { language: 'en', theme: 'light', state: 'FINAL_HOUR', device: 'android', reduceMotion: true } as const;
    const a = JSON.parse(previewMessage({ id: 'x' }, s)) as Record<string, unknown>;
    const b = JSON.parse(previewMessage({ id: 'x' }, s)) as Record<string, unknown>;
    expect(a).toMatchObject({ type: PREVIEW_RENDER, v: 2, language: 'en', theme: 'light', state: 'FINAL_HOUR', reduceMotion: true, event: { id: 'x' }, leaderboards: {} });
    expect(a).not.toHaveProperty('device');
    expect(Number(b.seq)).toBe(Number(a.seq) + 1);
  });

  it('the sample boards: labelled sample data, the API’s shape, no photo, one per board of the draft', () => {
    const e = { boards: [{ kind: 'SENDERS', minPoints: 1000 }, { kind: 'CP', minPoints: 0 }, { kind: 'AGENCIES' }] };
    const boards = sampleLeaderboards(e, 'ar', 'ENDED');
    expect(Object.keys(boards)).toEqual(['SENDERS', 'CP', 'AGENCIES']);
    const s = boards.SENDERS!;
    expect(s).toMatchObject({ board: 'SENDERS', minPoints: 1000, final: true, me: { rank: SAMPLE_MY_RANK, prize: [] } });
    expect(s.data).toHaveLength(12);
    expect(s.data.every((r) => r.user.avatarUrl === null && r.score >= 1000 && r.user.id.startsWith('sample-'))).toBe(true);
    expect(s.me.score).toBe(s.data[SAMPLE_MY_RANK - 1]!.score);
    expect(boards.CP!.data[0]).toHaveProperty('partner');
    expect(boards.AGENCIES!.data[0]).toMatchObject({ agency: { name: 'وكالة سارة' } });
    expect(sampleLeaderboards(e, 'en', 'RUNNING').SENDERS!.final).toBe(false);
    const sent = JSON.parse(previewMessage(e, { language: 'en', theme: 'dark', state: 'RUNNING', device: 'phone', reduceMotion: false })) as {
      leaderboards: Record<string, { data: { user: { displayName: string } }[] }>;
    };
    expect(sent.leaderboards.SENDERS!.data[0]!.user.displayName).toBe('Sara');
  });

  it('reads replies only from the preview’s own window and origin', () => {
    const win = {};
    const ok = { origin: 'https://admin.example.test', window: win };
    const msg = (data: unknown, origin = ok.origin, source: unknown = win) => previewReply({ data, origin, source }, ok);
    expect(msg(JSON.stringify({ type: PREVIEW_READY, v: 2 }))).toEqual({ type: PREVIEW_READY });
    expect(msg(JSON.stringify({ type: 'kabso.eventPreview.rendered', v: 2, seq: 4, designed: true }))).toEqual({
      type: 'kabso.eventPreview.rendered',
      seq: 4,
      designed: true,
    });
    expect(msg(JSON.stringify({ type: 'kabso.eventPreview.error', v: 2, seq: 5, reason: 'no event' }))).toMatchObject({ reason: 'no event' });
    expect(msg(JSON.stringify({ type: PREVIEW_READY, v: 2 }), 'https://evil.test')).toBeNull();
    expect(msg(JSON.stringify({ type: PREVIEW_READY, v: 2 }), ok.origin, {})).toBeNull();
    expect(msg(JSON.stringify({ type: PREVIEW_READY, v: 1 }))).toBeNull();
    expect(msg('{not json')).toBeNull();
    expect(msg({ type: PREVIEW_READY, v: 2 })).toBeNull();
    expect(previewReply({ data: '', origin: ok.origin, source: null }, { origin: ok.origin, window: null })).toBeNull();
  });

  it('the bundle is /event-preview/ on the panel’s origin unless development points elsewhere', () => {
    expect(previewUrl(undefined, 'https://admin.example.test').href).toBe('https://admin.example.test/event-preview/');
    expect(previewUrl('http://localhost:5190/event-preview/', 'http://localhost:5180').origin).toBe('http://localhost:5190');
  });
});

describe('the contrast warning «قد يصعب قراءة النص»', () => {
  it('WCAG luminance and ratio', () => {
    expect(contrastRatio(luminance([255, 255, 255]), luminance([0, 0, 0]))).toBeCloseTo(21, 5);
    expect(contrastRatio(luminance([118, 118, 118]), 1)).toBeCloseTo(4.54, 1);
    expect(composite([0, 0, 0], 0.5, [200, 100, 50])).toEqual([100, 50, 25]);
  });

  it('measures a picture by its light parts (90th percentile), transparent pixels over the page backdrop', () => {
    const px = (n: number, rgba: number[]) => Array.from({ length: n }, () => rgba).flat();
    expect(brightColour([...px(9, [0, 0, 0, 255]), ...px(1, [255, 255, 255, 255])])).toEqual([255, 255, 255]);
    expect(brightColour([...px(95, [10, 10, 10, 255]), ...px(5, [255, 255, 255, 255])])).toEqual([10, 10, 10]);
    expect(brightColour(px(4, [255, 255, 255, 0]))).toEqual([0x1a, 0x12, 0x08]);
  });

  it('warns for a light card fill over a light background and for light board art; dark presets pass', () => {
    const white: [number, number, number] = [250, 250, 245];
    expect(contrastWarnings('GLASS', 'THRONE', white, null).map((w) => w.where)).toEqual(['cards']);
    expect(contrastWarnings('DARK_MINIMAL', 'THRONE', white, null)).toEqual([]);
    expect(contrastWarnings('CLASSIC', 'THRONE', null, null)).toEqual([]);
    const board = contrastWarnings('CLASSIC', 'PODIUM', null, white);
    expect(board.map((w) => w.where)).toEqual(['board']);
    expect(board[0]!.ratio).toBeLessThan(CONTRAST_MIN);
    expect(contrastWarnings('CLASSIC', 'PODIUM', null, [20, 15, 10])).toEqual([]);
  });

  it('renders the warning with the ratio and never blocks (no disabled control)', () => {
    const markup = html(
      'ar',
      <ContrastNotice design={design({ preset: 'GLASS', backgroundMediaId: 'm', leaderboard: 'PODIUM' })} page={[250, 250, 250]} board={[250, 250, 250]} />,
    );
    expect(markup).toContain('قد يصعب قراءة النص');
    expect(markup).toContain('data-where="cards"');
    expect(markup).toContain('data-where="board"');
    expect(markup).toContain('الحفظ متاح');
    // The board warning needs an uploaded background.
    expect(html('en', <ContrastNotice design={design({ preset: 'GLASS' })} page={null} board={[250, 250, 250]} />)).toBe('');
  });
});

describe('the step', () => {
  const fields = (lang: Lang, d: DesignForm | null, problems = designProblems(d ?? design(), [senders])) =>
    html(lang, <EventDesignFields design={d} boards={[senders]} options={OPTIONS} problems={problems} onChange={() => undefined} />);

  it('off: the switch and today’s page explained', () => {
    const markup = fields('ar', null);
    expect(markup).toContain('صمّم صفحة هذه الفعالية');
    expect(markup).toContain('بدون تصميم تظهر صفحة الفعالية المعتادة');
    expect(markup).not.toContain('data-picker');
  });

  it('every choice as a picker card with its real-page thumbnail, the chosen one checked', () => {
    const markup = fields('ar', design({ layout: 'DECK', preset: 'KABSO_RED', rulesButton: { style: 'SIDE_TAB', edge: 'START' } }));
    for (const [picker, n] of [['layout', 3], ['leaderboard', 5], ['countdown', 6], ['preset', 6], ['rules', 7]] as const) {
      const block = markup.slice(markup.indexOf(`data-picker="${picker}"`), markup.indexOf('</fieldset>', markup.indexOf(`data-picker="${picker}"`)));
      expect(block.match(/class="dsg-option[ "]/g)).toHaveLength(n);
      expect(block.match(/<img /g)).toHaveLength(n);
    }
    expect(thumbnail('preset', 'GLASS')).toMatch(/preset-GLASS.*\.webp$/);
    expect(markup).toMatch(/checked="" value="DECK"/);
    expect(markup).toMatch(/checked="" value="KABSO_RED"/);
    expect(markup).toMatch(/checked="" value="SIDE_TAB"/);
    expect(markup).toContain('بداية السطر (اليمين بالعربية');
    expect(markup).toContain('إعادة إلى التصميم الافتراضي');
  });

  it('the sections list: draggable rows, ↑ / ↓, the locked switches with their reasons', () => {
    const markup = fields('ar', design());
    expect(markup.match(/draggable="true"/g)).toHaveLength(5);
    expect(markup).toContain('data-lock="design_boards_required"');
    expect(markup).toContain('للفعالية لوحات ترتيب، فلا يمكن إخفاء الترتيب.');
    expect(markup).toContain('data-lock="design_rules_unreachable"');
    expect(markup).toContain('aria-label="إلى الأعلى"');
    const first = moveSection(design(), 3, 0);
    expect(fields('ar', first)).toContain('الجوائز قبل الترتيب');
  });

  it('the tiers editor: the board’s places, each tier’s line and featured prizes, a problem at its tier', () => {
    const d = design({
      tiers: [
        { board: 'SENDERS', from: '1', to: '1', labelAr: 'البطل', labelEn: '', featured: [1] },
        { board: 'SENDERS', from: '2', to: '9', labelAr: '', labelEn: '', featured: [] },
      ],
    });
    const markup = fields('ar', d);
    expect(markup).toContain('المراكز المعروضة: 1–20');
    expect(markup).toContain('من سطر الجوائز 1–1');
    expect(markup).toContain('جوائز تظهر كبيرة');
    expect(markup).toContain('frame_gold');
    const tier1 = markup.slice(markup.lastIndexOf('<div', markup.indexOf('data-tier="1"')));
    expect(tier1).toContain('dsg-tier invalid');
    expect(tier1).toContain('الشريحة يجب أن تقع داخل سطر جوائز واحد من لوحتها.');
  });

  it('the background upload with its spec and the motion controls, in English too', () => {
    const markup = fields('en', design({ backgroundMediaId: 'm1', backgroundUrl: 'https://m.test/bg.webp' }));
    expect(markup).toContain('1080 × 1440 px');
    expect(markup).toContain('Remove the background');
    expect(markup).toContain('Entrance length: 450 ms');
    expect(markup).toContain('Animation layer speed: ×1');
    expect(markup).toContain('Animation layer opacity: 100%');
    expect(markup).toContain('reduce motion');
  });

  it('the live preview: the bundle in an iframe in a phone frame, loading until it answers', () => {
    const markup = html('ar', <EventLivePreview eventFor={() => ({ id: 'x' })} fallback={<p>sketch</p>} />);
    expect(markup).toContain('data-preview-status="loading"');
    expect(markup).toContain('src="http://localhost/event-preview/"');
    expect(markup).toContain('width="393" height="852"');
    expect(markup).toContain('dir="ltr"');
    expect(markup).toContain('أسماء المتصدرين وأرقامهم تجريبية');
    expect(markup).not.toContain('sketch');
  });

  it('the editor’s design step: the designer beside the preview, the stored design loaded', () => {
    const f = { ...newDraft('UTC'), titleAr: 'ف', titleEn: 'E', boards: [senders], reason: 'r', design: designFromServer(SERVER_DESIGN) };
    const markup = html(
      'ar',
      <EventEditor eventId="e1" options={OPTIONS} initial={f} server={null} step="evStepDesign" onClose={() => undefined} onDone={() => undefined} />,
    );
    expect(markup).toContain('class="dsg-layout"');
    expect(markup).toContain('data-testid="dsg-preview"');
    expect(markup).toMatch(/checked="" value="STAGE"/);
    // The sketch preview is the fallback only, not shown beside the real one.
    expect(markup).not.toContain('class="gev-preview"');
  });
});

describe('the preview’s headers', () => {
  it('the Caddyfile sends the same policies as the local test server', () => {
    const root = join(__dirname, '..', '..', '..');
    const caddy = readFileSync(join(root, 'infra/deploy/Caddyfile'), 'utf8');
    const local = readFileSync(join(__dirname, '..', 'e2e-preview', 'headers.mjs'), 'utf8');
    const preview = /PREVIEW_CSP =\s*"([^"]+)"/.exec(local)![1]!;
    expect(caddy).toContain(`Content-Security-Policy "${preview}"`);
    expect(preview).toContain("frame-ancestors 'self'");
    expect(preview).toContain("'wasm-unsafe-eval'");
    const block = caddy.slice(caddy.indexOf('admin.{$KABSO_DOMAIN} {'), caddy.indexOf('studio.{$KABSO_DOMAIN} {'));
    expect(block).toContain('handle_path /event-preview/*');
    expect(block).toContain("frame-src 'self'");
    expect(block).toMatch(/header @preview \{[^}]*X-Frame-Options "SAMEORIGIN"/);
  });
});
