/**
 * D325 «الفعاليات» (events v2, CONVENTIONS §10.127) in the panel: the v2 body (drafts without dates, decimal
 * multipliers, gift pieces, display pictures, milestones, recurrence, scoring, counted gifts), its round trip, what
 * blocks a draft vs a publish, the row commands, the page and each step of the editor in Arabic (RTL) and English.
 */
import { renderToStaticMarkup } from 'react-dom/server';
import { describe, expect, it } from 'vitest';
import { AppContext, type AppState } from '../src/context';
import {
  emptyGiftEvent,
  formFromServer,
  giftEventBody,
  giftEventProblems,
  prizeTypesFor,
  prizeTypesV2For,
  type EventOptions,
  type GiftEventFormState,
} from '../src/gift-events';
import { translate, type Lang } from '../src/i18n';
import { NAV, visibleNav } from '../src/nav';
import { matchPath } from '../src/router';
import { EVENT_STEPS, EventEditor, Events, newDraft, rowCommands, type EventRow } from '../src/pages/Events';
import type { Capability, PanelRole } from '../src/types';
import { CAPABILITY_ROLES } from './capabilities';

const capsOf = (role: PanelRole) =>
  (Object.keys(CAPABILITY_ROLES) as Capability[]).filter((c) => CAPABILITY_ROLES[c]?.includes(role));

const state = (lang: Lang, caps: string[] | null = null): AppState => ({
  lang,
  t: (key, vars) => translate(lang, key, vars),
  session: null,
  can: (c) => caps === null || caps.includes(c),
  toast: () => undefined,
});
const html = (lang: Lang, node: React.ReactNode, caps: string[] | null = null) =>
  renderToStaticMarkup(<AppContext.Provider value={state(lang, caps)}>{node}</AppContext.Provider>);

const OPTIONS: EventOptions = {
  timeZone: 'Asia/Riyadh',
  boardKinds: ['SENDERS', 'RECEIVERS', 'CREATORS', 'AGENCIES', 'CP'],
  gifts: [
    { code: 'rose', nameAr: 'وردة', nameEn: 'Rose', priceCoins: 100, enabled: true },
    { code: 'kabso_launch_crown', nameAr: 'تاج الافتتاح', nameEn: 'Opening Crown', priceCoins: 1_000_000, enabled: true, eventId: 'e1', fullscreen: true },
    { code: 'other_event_gift', nameAr: 'هدية أخرى', nameEn: 'Other', priceCoins: 10, enabled: true, eventId: 'e2' },
  ],
  bagItems: [
    { code: 'frame_gold', category: 'AVATAR_FRAME', nameAr: 'إطار ذهبي', nameEn: 'Gold frame' },
    { code: 'ev_frame', category: 'AVATAR_FRAME', nameAr: 'إطار الفعالية', nameEn: 'Event frame', eventId: 'e1' },
  ],
  vipTiers: [{ code: 'VIP_1', nameAr: 'في آي بي 1', nameEn: 'VIP 1', enabled: true }],
  giftCategories: [{ code: 'EVENT', nameAr: 'فعاليات', nameEn: 'Events' }],
};

function festival(): GiftEventFormState {
  return {
    ...newDraft('Asia/Riyadh'),
    titleAr: 'مهرجان انطلاقة Kabso',
    titleEn: 'Kabso Launch Festival',
    gifts: [
      { giftCode: 'rose', pointsPerCoin: '1', pointsPerGift: '0' },
      { giftCode: 'kabso_launch_crown', pointsPerCoin: '1.2', pointsPerGift: '0' },
    ],
    boards: [
      {
        kind: 'SENDERS',
        minPoints: '1000000',
        prizes: [
          {
            rankFrom: '1',
            rankTo: '1',
            items: [
              { type: 'COINS', value: '500000', code: '' },
              { type: 'GIFT_PIECES', value: '3', code: 'kabso_launch_crown', displayKey: 'media/events/prize/0193a4f0-0000-7000-8000-000000000001.webp' },
              { type: 'BAG_ITEM', value: '30', code: 'ev_frame' },
            ],
          },
        ],
      },
    ],
    milestones: [{ board: 'SENDERS', points: '1000000', items: [{ type: 'GIFT_PIECES', value: '5', code: 'kabso_launch_crown' }] }],
    reason: 'launch festival',
  };
}

describe('D325 the v2 body', () => {
  it('a draft has no dates; the multiplier keeps two decimals; gift pieces, display pictures and milestones', () => {
    const body = giftEventBody(festival());
    expect(body).toMatchObject({
      status: 'DRAFT',
      startsAt: null,
      endsAt: null,
      recurrence: 'NONE',
      scoring: 'MULTIPLIER',
      countedGifts: 'EVENT_GIFTS',
      permanent: false,
      bannerMediaId: null,
    });
    expect(body.gifts).toEqual([
      { giftCode: 'rose', pointsPerCoin: 1, pointsPerGift: 0 },
      { giftCode: 'kabso_launch_crown', pointsPerCoin: 1.2, pointsPerGift: 0 },
    ]);
    expect(body.boards[0]!.prizes[0]!.items).toEqual([
      { type: 'COINS', amount: 500000 },
      {
        type: 'GIFT_PIECES',
        giftCode: 'kabso_launch_crown',
        count: 3,
        displayKey: 'media/events/prize/0193a4f0-0000-7000-8000-000000000001.webp',
      },
      { type: 'BAG_ITEM', itemCode: 'ev_frame', days: 30 },
    ]);
    expect(body.milestones).toEqual([
      { board: 'SENDERS', points: 1000000, prizes: [{ type: 'GIFT_PIECES', giftCode: 'kabso_launch_crown', count: 5 }] },
    ]);
  });

  it('a weekly permanent event sends no end; the dates go through the event zone', () => {
    const body = giftEventBody({
      ...festival(),
      status: 'PUBLISHED',
      startsAt: '2026-12-01T20:00',
      endsAt: '2026-12-31T20:00',
      permanent: true,
      recurrence: 'WEEKLY',
      scoring: 'COINS',
      countedGifts: 'ALL_GIFTS',
      audience: 'CP',
    });
    expect(body).toMatchObject({
      status: 'PUBLISHED',
      startsAt: '2026-12-01T17:00:00.000Z',
      endsAt: null,
      permanent: true,
      recurrence: 'WEEKLY',
      scoring: 'COINS',
      countedGifts: 'ALL_GIFTS',
      audience: 'CP',
    });
  });

  it('reads the server form back (v2 fields included)', () => {
    const body = giftEventBody(festival());
    const back = formFromServer({ ...body, bannerUrl: null }, 'UTC');
    expect({ ...back, reason: 'launch festival' }).toEqual({
      ...festival(),
      backgroundKey: '',
      backgroundPosterKey: '',
      titleKey: '',
      overlayKey: '',
    });
  });

  it('a draft is saved without dates, gifts or boards; publishing needs them', () => {
    const empty = { ...newDraft('UTC'), titleAr: 'س', titleEn: 'x', reason: 'draft now' };
    expect(giftEventProblems(empty)).toEqual([]);
    const pub = giftEventProblems({ ...empty, status: 'PUBLISHED' });
    expect(pub).toEqual(expect.arrayContaining(['gevNeedDates', 'gevNeedGifts', 'gevNeedBoard']));
    // Every gift counts: no event gift needed; permanent: no end needed.
    expect(
      giftEventProblems({
        ...festival(),
        status: 'PUBLISHED',
        startsAt: '2026-12-01T20:00',
        permanent: true,
        countedGifts: 'ALL_GIFTS',
        gifts: [],
      }),
    ).toEqual([]);
    expect(giftEventProblems({ ...festival(), gifts: [{ giftCode: 'rose', pointsPerCoin: '1.234', pointsPerGift: '0' }] })).toContain(
      'gevBadPoints',
    );
    expect(giftEventProblems({ ...festival(), milestones: [...festival().milestones, ...festival().milestones] })).toContain(
      'evMilestoneTwice',
    );
    expect(
      giftEventProblems({ ...festival(), status: 'PUBLISHED', startsAt: '2026-12-01T20:00', endsAt: '2026-12-08T20:00', milestones: [{ board: 'CP', points: '5', items: [{ type: 'CP_MONEY', value: '', code: '', cherries: '1', coins: '1' }] }] }),
    ).toContain('evBadMilestone');
  });

  it('offers gift pieces on every board in the v2 editor (D303’s list unchanged)', () => {
    expect(prizeTypesV2For('SENDERS')).toEqual([...prizeTypesFor('SENDERS'), 'GIFT_PIECES']);
    expect(prizeTypesFor('SENDERS')).not.toContain('GIFT_PIECES');
  });
});

const rows: EventRow[] = [
  { id: 'd', titleAr: 'مهرجان انطلاقة Kabso', titleEn: 'Kabso Launch Festival', metric: 'EVENT_GIFTS', startsAt: null, endsAt: null, permanent: false, state: 'DRAFT', payoutHold: false, status: 'DRAFT', recurrence: 'NONE' },
  { id: 'w', titleAr: 'نجم الأسبوع', titleEn: 'Weekly star', metric: 'EVENT_GIFTS', startsAt: '2026-11-01T00:00:00Z', endsAt: null, permanent: true, state: 'RUNNING', payoutHold: false, status: 'PUBLISHED', recurrence: 'WEEKLY', period: 1 },
  { id: 'u', titleAr: 'قادمة', titleEn: 'Upcoming', metric: 'EVENT_GIFTS', startsAt: '2026-12-01T00:00:00Z', endsAt: '2026-12-05T00:00:00Z', permanent: false, state: 'UPCOMING', payoutHold: false },
  { id: 'o', titleAr: 'قديمة', titleEn: 'Old', metric: 'GIFT_COINS_SENT', startsAt: '2026-10-01T00:00:00Z', endsAt: '2026-10-05T00:00:00Z', permanent: false, state: 'HELD', payoutHold: true },
];

describe('D325 the events page', () => {
  it('row commands by state: a draft is published or deleted; an upcoming gift event goes back to a draft', () => {
    expect(rowCommands(rows[0]!)).toEqual(['publish', 'discard']);
    expect(rowCommands(rows[1]!)).toEqual(['end', 'hold']);
    expect(rowCommands(rows[2]!)).toEqual(['unpublish', 'hold']);
    expect(rowCommands(rows[3]!)).toEqual(['release']);
  });

  it('lists every event (older ones marked) with the new event and festival template buttons, RTL in Arabic', () => {
    const ar = html('ar', <Events initial={rows} />);
    expect(ar).toContain('الفعاليات');
    expect(ar).toContain('فعالية جديدة');
    expect(ar).toContain('قالب مهرجان الانطلاقة');
    expect(ar).toContain('مسودة');
    expect(ar).toContain('بلا موعد بعد');
    expect(ar).toContain('أسبوعية');
    expect(ar).toContain('#2');
    expect(ar).toContain('فعالية قديمة');
    expect(ar).toContain('حذف المسودة');
    const en = html('en', <Events initial={rows} />);
    expect(en).toContain('Delete draft');
    expect(en).toContain('Back to draft');
    // Without events.manage: no change buttons.
    const view = html('ar', <Events initial={rows} />, ['catalog.view']);
    expect(view).not.toContain('فعالية جديدة');
    expect(view).not.toContain('حذف المسودة');
  });

  it('is in the menu for the catalogue viewers and routed', () => {
    expect(NAV.flatMap((g) => g.items).find((i) => i.to === '/events')).toMatchObject({ key: 'navEvents' });
    expect(matchPath('/events')?.name).toBe('events');
    const items = (role: 'OWNER' | 'BD') => visibleNav((c) => capsOf(role).includes(c)).flatMap((g) => g.items.map((i) => i.to));
    expect(items('OWNER')).toContain('/events');
    expect(items('BD')).not.toContain('/events');
  });
});

describe('D325 the step-by-step editor', () => {
  const editor = (lang: Lang, step: (typeof EVENT_STEPS)[number], f = festival()) =>
    html(
      lang,
      <EventEditor eventId="e1" options={OPTIONS} initial={f} server={null} step={step} onClose={() => undefined} onDone={() => undefined} />,
    );

  it('has the eight steps in order', () => {
    const a = editor('ar', 'evStepBasics');
    for (const label of ['العنوان والقواعد', 'الوقت والتكرار', 'الجمهور والنقاط', 'هدايا الفعالية', 'اللوحات والجوائز', 'المراحل', 'التصميم', 'المراجعة والنشر']) {
      expect(a).toContain(label);
    }
    expect(a).toContain('الخطوة 1 من 8');
    expect(a).toContain('حفظ كمسودة');
    expect(editor('en', 'evStepBasics')).toContain('Step 1 of 8');
  });

  it('time: permanent, once / weekly / monthly', () => {
    const a = editor('ar', 'evStepTime');
    expect(a).toContain('دائمة (بلا نهاية)');
    expect(a).toContain('أسبوعية (تبدأ من جديد كل أسبوع)');
    expect(a).toContain('شهرية (تبدأ من جديد كل شهر)');
  });

  it('audience and points: five audiences, the two scoring methods and the counted gifts', () => {
    const a = editor('ar', 'evStepAudience');
    for (const label of ['الجميع', 'المضيفون', 'صناع المحتوى', 'الوكالات', 'الثنائيات (CP)', 'مضاعف لكل هدية', 'النقاط = الكوينز', 'هدايا الفعالية فقط', 'كل الهدايا']) {
      expect(a).toContain(label);
    }
  });

  it('gifts: the multiplier and the points of one gift; this event’s exclusive gifts only; the upload button', () => {
    const a = editor('ar', 'evStepGifts');
    expect(a).toContain('رفع هدية حصرية');
    expect(a).toContain('step="0.01"');
    expect(a).toContain('حصرية للفعالية');
    expect(a).not.toContain('هدية أخرى'); // another event's gift is never offered
    const en = editor('en', 'evStepGifts');
    expect(en).toContain('Points of one gift: 1,200,000');
    // Points = coins: no multiplier field.
    expect(editor('en', 'evStepGifts', { ...festival(), scoring: 'COINS' })).not.toContain('step="0.01"');
  });

  it('boards: prize items with gift pieces and a display picture; the exclusive prize upload', () => {
    const a = editor('ar', 'evStepBoards');
    expect(a).toContain('رفع جائزة حصرية');
    expect(a).toContain('قطع هدية حصرية في الحقيبة');
    expect(a).toContain('صورة عرض مرفوعة');
    expect(a).toContain('إطار الفعالية');
    expect(a).toContain('أفضل 20');
  });

  it('milestones, design (banner and art with their specs) and the review', () => {
    expect(editor('ar', 'evStepMilestones')).toContain('إضافة مرحلة');
    const d = editor('ar', 'evStepDesign');
    // D359: the banner field is «بانر صفحة البث» with its 1500 × 300 guidance.
    expect(d).toContain('بانر صفحة البث');
    expect(d).toContain('1500 × 300 بكسل');
    // D356: the real preview (the app's page) replaces the sketch, which stays as its fallback.
    expect(d).toContain('معاينة حقيقية');
    const r = editor('ar', 'evStepReview');
    expect(r).toContain('بلا موعد بعد');
    expect(r).toContain('حفظ ونشر');
    // A draft without dates cannot be published from the review.
    expect(r).toMatch(/<button type="button" class="btn primary" disabled="">حفظ ونشر<\/button>/);
  });

  it('starts a new event as a draft', () => {
    expect(newDraft('UTC')).toMatchObject({ status: 'DRAFT', gifts: [], boards: [], startsAt: '', endsAt: '' });
    expect(emptyGiftEvent('UTC').status).toBe('PUBLISHED');
  });
});
