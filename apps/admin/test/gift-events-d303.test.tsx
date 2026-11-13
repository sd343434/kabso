/**
 * D303 «فعاليات الهدايا» in the panel: the editor (gifts with points, the five board kinds, prize bundles, minimums,
 * dates in the event's time zone), its body, the results with each payout, and the banner's video and event.
 */
import { renderToStaticMarkup } from 'react-dom/server';
import { describe, expect, it } from 'vitest';
import { AppContext, type AppState } from '../src/context';
import {
  emptyGiftEvent,
  formFromServer,
  giftEventBody,
  giftEventProblems,
  isoToZoned,
  zonedToIso,
  type EventOptions,
  type GiftEventFormState,
} from '../src/gift-events';
import { translate, type Lang } from '../src/i18n';
import { bannerBody, BannerForm } from '../src/pages/BannerForm';
import { GiftEventForm, GiftEventResults, type AdminGiftEvent } from '../src/pages/GiftEventForm';

const state = (lang: Lang): AppState => ({
  lang,
  t: (key, vars) => translate(lang, key, vars),
  session: null,
  can: () => true,
  toast: () => undefined,
});

const OPTIONS: EventOptions = {
  timeZone: 'Asia/Riyadh',
  boardKinds: ['SENDERS', 'RECEIVERS', 'CREATORS', 'AGENCIES', 'CP'],
  gifts: [
    {
      code: 'rose',
      nameAr: 'وردة',
      nameEn: 'Rose',
      priceCoins: 10,
      enabled: true,
    },
    {
      code: 'crown',
      nameAr: 'تاج',
      nameEn: 'Crown',
      priceCoins: 1000,
      enabled: true,
    },
  ],
  bagItems: [
    {
      code: 'frame_gold',
      category: 'AVATAR_FRAME',
      nameAr: 'إطار ذهبي',
      nameEn: 'Gold frame',
    },
  ],
  vipTiers: [{ code: 'VIP_1', nameAr: 'في آي بي 1', nameEn: 'VIP 1', enabled: true }],
};

function filled(): GiftEventFormState {
  const f = emptyGiftEvent('Asia/Riyadh');
  return {
    ...f,
    titleAr: 'ملك الهدايا',
    titleEn: 'Gift King',
    startsAt: '2026-11-10T20:00',
    endsAt: '2026-11-17T20:00',
    gifts: [
      { giftCode: 'rose', pointsPerCoin: '2', pointsPerGift: '0' },
      { giftCode: 'crown', pointsPerCoin: '1', pointsPerGift: '50' },
    ],
    boards: [
      {
        kind: 'SENDERS',
        minPoints: '1000',
        prizes: [
          {
            rankFrom: '1',
            rankTo: '1',
            items: [
              { type: 'COINS', value: '10000', code: '' },
              { type: 'BAG_ITEM', value: '7', code: 'frame_gold' },
              { type: 'VIP', value: '30', code: 'VIP_1' },
            ],
          },
          {
            rankFrom: '2',
            rankTo: '3',
            items: [{ type: 'COINS', value: '500', code: '' }],
          },
        ],
      },
      {
        kind: 'CP',
        minPoints: '0',
        prizes: [
          {
            rankFrom: '1',
            rankTo: '1',
            items: [{ type: 'BAG_ITEM', value: '3', code: 'frame_gold' }],
          },
        ],
      },
    ],
    reason: 'weekly event',
  };
}

describe('D303 time zones', () => {
  it('a wall time typed for a zone is that zone’s instant, whatever the browser', () => {
    expect(zonedToIso('2026-11-10T20:00', 'Asia/Riyadh')).toBe('2026-11-10T17:00:00.000Z');
    expect(zonedToIso('2026-11-10T20:00', 'UTC')).toBe('2026-11-10T20:00:00.000Z');
    // Daylight saving: New York is UTC−4 in July, UTC−5 in December.
    expect(zonedToIso('2026-07-01T09:30', 'America/New_York')).toBe('2026-07-01T13:30:00.000Z');
    expect(zonedToIso('2026-12-01T09:30', 'America/New_York')).toBe('2026-12-01T14:30:00.000Z');
    expect(isoToZoned('2026-11-10T17:00:00.000Z', 'Asia/Riyadh')).toBe('2026-11-10T20:00');
    expect(() => zonedToIso('tomorrow', 'UTC')).toThrow(RangeError);
  });
});

describe('D303 the gift event body and its checks', () => {
  it('builds the GiftEventInput body (items by type) and reads it back from the server form', () => {
    const body = giftEventBody(filled());
    expect(body).toMatchObject({
      titleEn: 'Gift King',
      startsAt: '2026-11-10T17:00:00.000Z',
      endsAt: '2026-11-17T17:00:00.000Z',
      timeZone: 'Asia/Riyadh',
      audience: 'EVERYONE',
      bannerUrl: null,
      gifts: [
        { giftCode: 'rose', pointsPerCoin: 2, pointsPerGift: 0 },
        { giftCode: 'crown', pointsPerCoin: 1, pointsPerGift: 50 },
      ],
      reason: 'weekly event',
    });
    expect(body.boards[0]).toEqual({
      kind: 'SENDERS',
      minPoints: 1000,
      prizes: [
        {
          rankFrom: 1,
          rankTo: 1,
          items: [
            { type: 'COINS', amount: 10000 },
            { type: 'BAG_ITEM', itemCode: 'frame_gold', days: 7 },
            { type: 'VIP', tierCode: 'VIP_1', days: 30 },
          ],
        },
        { rankFrom: 2, rankTo: 3, items: [{ type: 'COINS', amount: 500 }] },
      ],
    });
    const back = formFromServer({ ...body, bannerUrl: null }, 'UTC');
    expect({ ...back, reason: 'weekly event' }).toEqual({
      ...filled(),
      backgroundKey: '',
      backgroundPosterKey: '',
      titleKey: '',
      overlayKey: '',
    });
  });

  it('lists what blocks saving', () => {
    expect(giftEventProblems(filled())).toEqual([]);
    const f = filled();
    expect(giftEventProblems({ ...f, titleAr: '' })).toContain('gevNeedTitles');
    expect(giftEventProblems({ ...f, endsAt: '2026-11-01T00:00' })).toContain('gevEndAfterStart');
    expect(giftEventProblems({ ...f, gifts: [f.gifts[0]!, f.gifts[0]!] })).toContain('gevGiftTwice');
    expect(
      giftEventProblems({
        ...f,
        gifts: [{ giftCode: 'rose', pointsPerCoin: '0', pointsPerGift: '0' }],
      }),
    ).toContain('gevBadPoints');
    expect(giftEventProblems({ ...f, boards: [] })).toContain('gevNeedBoard');
    const overlap = filled();
    overlap.boards[0]!.prizes[1]!.rankFrom = '1';
    expect(giftEventProblems(overlap)).toContain('gevBadRanks');
    const noItem = filled();
    noItem.boards[0]!.prizes[0]!.items[1]!.code = '';
    expect(giftEventProblems(noItem)).toContain('gevBadItems');
    expect(giftEventProblems({ ...f, reason: '' })).toContain('gevNeedReason');
  });
});

describe('D303 the editor', () => {
  const render = (lang: Lang, locked = false, initial = filled()) =>
    renderToStaticMarkup(
      <AppContext.Provider value={state(lang)}>
        <GiftEventForm
          onClose={() => undefined}
          onDone={() => undefined}
          options={OPTIONS}
          initial={initial}
          locked={locked}
        />
      </AppContext.Provider>,
    );

  it('Arabic: the five boards with their hints, gifts with points per coin and the points of one gift, prize items', () => {
    const html = render('ar');
    expect(html).toContain('فعالية هدايا جديدة');
    for (const b of ['ترتيب الداعمين', 'ترتيب المضيفين', 'ترتيب صناع المحتوى', 'ترتيب الوكالات', 'ترتيب الثنائيات CP'])
      expect(html).toContain(b);
    expect(html).toContain('الجائزة لصاحب الوكالة');
    expect(html).toContain('نقاط لكل عملة');
    expect(html).toContain('نقاط الهدية الواحدة: 20');
    expect(html).toContain('نقاط الهدية الواحدة: 1,050');
    expect(html).toContain('بطاقة VIP');
    expect(html).toContain('إطار ذهبي');
    expect(html).toContain('الحد الأدنى للتأهل');
    expect(html).toContain('Asia/Riyadh');
    expect(html).toContain('صناع المحتوى فقط');
    // Only the boards in use show their prize lines.
    expect(html.match(/data-board="/g)).toHaveLength(5);
    expect(html).not.toMatch(/<button class="btn primary" disabled="">/);
  });

  it('English; an empty form cannot be saved; a running event locks its structure', () => {
    const empty = render('en', false, emptyGiftEvent('UTC'));
    expect(empty).toContain('New gift event');
    expect(empty).toContain('Write both titles.');
    expect(empty).toMatch(/<button class="btn primary" disabled="">/);
    const locked = render('en', true);
    expect(locked).toContain('The event has started');
    expect(locked).toMatch(/<fieldset class="span-2" disabled="">/);
  });

  it('the results: each board’s ranks, the prize and its payout', () => {
    const data: AdminGiftEvent = {
      id: 'e1',
      state: 'PAID',
      payoutHold: false,
      structureLocked: true,
      form: { ...giftEventBody(filled()), bannerUrl: null },
      results: [
        {
          board: 'SENDERS',
          rank: 1,
          username: 'sara',
          displayName: 'Sara',
          score: 21000,
          prize: [
            { type: 'COINS', amount: 10000 },
            { type: 'BAG_ITEM', itemCode: 'frame_gold', days: 7 },
          ],
          prizeStatus: 'PAID',
          payouts: [{ userId: 'u1', status: 'PAID' }],
        },
        {
          board: 'CP',
          rank: 1,
          username: 'omar',
          displayName: 'Omar',
          score: 300,
          prize: [],
          prizeStatus: 'FORFEITED',
          payouts: [],
        },
      ],
    };
    const html = renderToStaticMarkup(
      <AppContext.Provider value={state('ar')}>
        <GiftEventResults eventId="e1" data={data} onClose={() => undefined} />
      </AppContext.Provider>,
    );
    expect(html).toContain('ترتيب الداعمين');
    expect(html).toContain('عملات 10,000');
    expect(html).toContain('عنصر من الحقيبة frame_gold · 7 الأيام');
    expect(html).toContain('صُرفت');
    expect(html).toContain('سقطت (الحساب غير نشط)');
  });
});

describe('D303 banner video and event', () => {
  it('the form offers a video (home only) and an event; the body names them', () => {
    const html = renderToStaticMarkup(
      <AppContext.Provider value={state('ar')}>
        <BannerForm
          onClose={() => undefined}
          onDone={() => undefined}
          initial={{
            placement: 'room',
            link: '',
            titleAr: '',
            titleEn: '',
            titleSide: 'RIGHT',
            startsAt: '',
            endsAt: '',
            sortOrder: '0',
            reason: '',
            kind: 'video',
          }}
        />
      </AppContext.Provider>,
    );
    expect(html).toContain('فيديو');
    expect(html).toContain('video/mp4');
    expect(html).toContain('الفيديو للبانر الأساسي فقط.');
    expect(html).toContain('يفتح فعالية (اختياري)');
    const f = {
      placement: 'home' as const,
      link: '',
      titleAr: '',
      titleEn: '',
      titleSide: 'RIGHT' as const,
      startsAt: '',
      endsAt: '',
      sortOrder: '0',
      reason: 'r',
      eventId: 'ev-1',
    };
    expect(bannerBody('m1', f, 'v1')).toMatchObject({
      mediaId: 'm1',
      videoMediaId: 'v1',
      eventId: 'ev-1',
      link: '/events/ev-1',
    });
    expect(bannerBody('m1', { ...f, eventId: '', link: '/families' })).toEqual(
      expect.not.objectContaining({
        videoMediaId: expect.anything(),
        eventId: expect.anything(),
      }),
    );
  });
});

describe('D303 follow-ups: board money, CP amounts, permanent, medals, art specs', () => {
  it('each board offers its own money only; a wrong one blocks saving', async () => {
    const { prizeTypesFor } = await import('../src/gift-events');
    expect(prizeTypesFor('SENDERS')).toEqual(['COINS', 'BAG_ITEM', 'VIP', 'BADGE']);
    expect(prizeTypesFor('RECEIVERS')).toEqual(['CHERRIES', 'BAG_ITEM', 'VIP', 'BADGE']);
    expect(prizeTypesFor('AGENCIES')).toEqual(['COINS', 'CHERRIES', 'BAG_ITEM', 'VIP', 'BADGE']);
    expect(prizeTypesFor('CP')).toEqual(['CP_MONEY', 'BAG_ITEM', 'VIP', 'BADGE']);
    const f = filled();
    f.boards[0]!.prizes[1]!.items[0] = {
      type: 'CHERRIES',
      value: '5',
      code: '',
    };
    expect(giftEventProblems(f)).toContain('gevWrongMoney');
  });

  it('the CP two-amount line, a permanent item and a medal level go to the body', () => {
    const f = filled();
    f.boards[1]!.prizes[0]!.items = [
      { type: 'CP_MONEY', value: '', code: '', cherries: '400', coins: '250' },
      { type: 'BAG_ITEM', value: '', code: 'frame_gold', permanent: true },
      { type: 'BADGE', value: '4', code: 'gift_king', level: '3' },
    ];
    expect(giftEventProblems(f)).toEqual([]);
    expect(giftEventBody(f).boards[1]!.prizes[0]!.items).toEqual([
      { type: 'CP_MONEY', cherries: 400, coins: 250 },
      { type: 'BAG_ITEM', itemCode: 'frame_gold', days: null },
      { type: 'BADGE', badgeCode: 'gift_king', level: 3, days: 4 },
    ]);
    f.boards[1]!.prizes[0]!.items = [{ type: 'CP_MONEY', value: '', code: '', cherries: '0', coins: '0' }];
    expect(giftEventProblems(f)).toContain('gevBadItems');
  });

  it('the art fields show the published specs; the preview shows the page', async () => {
    const { specText } = await import('../src/gift-events');
    const specs = [
      {
        kind: 'background',
        width: 1080,
        height: 1920,
        formats: ['PNG', 'MP4'],
        maxStillBytes: 3145728,
        maxAnimatedBytes: 8388608,
        maxDurationMs: 10000,
        transparent: false,
        safeZone: 'Top 0–480 px: the title art',
      },
      {
        kind: 'title',
        width: 1080,
        height: 480,
        formats: ['PNG', 'WEBP'],
        maxStillBytes: 1048576,
        maxAnimatedBytes: null,
        maxDurationMs: null,
        transparent: true,
        safeZone: null,
      },
    ];
    expect(specText(specs[1]!)).toBe('1080 × 480 px · PNG, WEBP · ≤ 1 MB (still) · transparent');
    const html = renderToStaticMarkup(
      <AppContext.Provider value={state('ar')}>
        <GiftEventForm
          onClose={() => undefined}
          onDone={() => undefined}
          options={{ ...OPTIONS, specs }}
          initial={filled()}
        />
      </AppContext.Provider>,
    );
    expect(html).toContain('تصميم صفحة الفعالية');
    expect(html).toContain('1080 × 1920 px');
    expect(html).toContain('Top 0–480 px');
    expect(html).toContain('معاينة الصفحة قبل النشر');
    expect(html).toContain('وسام جديد');
  });
});
