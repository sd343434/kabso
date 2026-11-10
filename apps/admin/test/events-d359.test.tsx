/**
 * D359 (owner decision: events reach the «البث» hub only through the existing banner carousel; CONVENTIONS §10.154) in
 * the panel: the event wizard's «بانر صفحة البث» — on / off and «يظهر قبل البداية» sent and read back (defaults for an
 * older server), the guidance (size, shape, limits, safe zone), the 5:1 crop preview at phone width, the audience and
 * the window, the local file checks, in Arabic and English.
 */
import { renderToStaticMarkup } from 'react-dom/server';
import { describe, expect, it } from 'vitest';
import { AppContext, type AppState } from '../src/context';
import { formFromServer, giftEventBody, type EventOptions, type GiftEventFormState } from '../src/gift-events';
import { translate, type Lang } from '../src/i18n';
import { HUB_BANNER_SPEC, hubBannerProblem } from '../src/pages/EventHubBanner';
import { EventEditor, newDraft } from '../src/pages/Events';
import type { AdminGiftEvent } from '../src/pages/GiftEventForm';

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
  boardKinds: ['SENDERS'],
  gifts: [{ code: 'rose', nameAr: 'وردة', nameEn: 'Rose', priceCoins: 100, enabled: true }],
  bagItems: [],
  vipTiers: [],
  giftCategories: [],
};

const event = (over: Partial<GiftEventFormState> = {}): GiftEventFormState => ({
  ...newDraft('UTC'),
  titleAr: 'فعالية',
  titleEn: 'Event',
  startsAt: '2026-12-01T18:00',
  endsAt: '2026-12-08T18:00',
  gifts: [{ giftCode: 'rose', pointsPerCoin: '1', pointsPerGift: '0' }],
  boards: [{ kind: 'SENDERS', minPoints: '0', prizes: [] }],
  reason: 'd359 panel',
  ...over,
});

const server = (f: GiftEventFormState, bannerImageUrl: string | null): AdminGiftEvent =>
  ({
    id: 'e1',
    state: 'UPCOMING',
    payoutHold: false,
    structureLocked: false,
    creatorsAsHosts: true,
    form: { ...giftEventBody(f), bannerUrl: null },
    bannerImageUrl,
    results: [],
  }) as unknown as AdminGiftEvent;

const design = (lang: Lang, f: GiftEventFormState, s: AdminGiftEvent | null = null) =>
  html(
    lang,
    <EventEditor
      eventId="e1"
      options={OPTIONS}
      initial={f}
      server={s}
      step="evStepDesign"
      onClose={() => undefined}
      onDone={() => undefined}
    />,
  );

describe('D359 «بانر صفحة البث» body', () => {
  it('sends on / off and «يظهر قبل البداية» and reads them back; an older server reads as the defaults', () => {
    const f = event({ bannerMediaId: '0193a4b2-7c1d-7e2f-8a3b-4c5d6e7f8091', bannerEnabled: false, bannerBeforeStart: true });
    const body = giftEventBody(f);
    expect(body).toMatchObject({ bannerMediaId: f.bannerMediaId, bannerEnabled: false, bannerBeforeStart: true });
    const back = formFromServer({ ...body, bannerUrl: null }, 'UTC');
    expect([back.bannerEnabled, back.bannerBeforeStart]).toEqual([false, true]);
    const { bannerEnabled: _e, bannerBeforeStart: _b, ...older } = body;
    const old = formFromServer({ ...older, bannerUrl: null }, 'UTC');
    expect([old.bannerEnabled, old.bannerBeforeStart]).toEqual([true, false]);
    // A new event: on, from the start; no picture → null (the server then has no banner).
    expect(giftEventBody(event())).toMatchObject({ bannerMediaId: null, bannerEnabled: true, bannerBeforeStart: false });
  });
});

describe('D359 «بانر صفحة البث» field', () => {
  it('in Arabic: title, switches, guidance, the 5:1 preview with the safe zone, audience and window', () => {
    const f = event({ audience: 'HOSTS', bannerMediaId: 'm1' });
    const a = design('ar', f, server(f, 'https://media.example.test/banner.webp'));
    expect(a).toContain('data-testid="ev-hub-banner"');
    expect(a).toContain('<legend>بانر صفحة البث</legend>');
    expect(a).toContain('إظهار البانر في صفحة البث');
    expect(a).toContain('يظهر قبل البداية (من وقت النشر)');
    expect(a).toContain('1500 × 300 بكسل (نسبة 5:1');
    expect(a).toContain('حتى 2 MB');
    expect(a).toContain('حتى 5 MB ومدة 10 ث');
    expect(a).toContain('900 × 240');
    expect(a).toContain('class="ev-hub-slide"');
    expect(a).toContain('class="ev-hub-safe"');
    expect(a).toContain('src="https://media.example.test/banner.webp"');
    expect(a).toContain('يظهر لـ: المضيفون (يشمل صناع المحتوى)');
    expect(a).toContain('تغيير الجمهور');
    expect(a).toContain('يظهر من 2026-12-01 18:00 (UTC) إلى 2026-12-08 18:00 (UTC)');
    expect(a).toContain('بانرات الفعاليات الجارية تأتي أولاً');
    expect(a).toContain('إزالة الصورة');
    // The old single file field is gone (one banner field only).
    expect(a.match(/id="ev-banner"/g)).toHaveLength(1);
  });

  it('off: says the picture is kept; before the start: shown from publishing; no picture: no remove button', () => {
    const off = design('ar', event({ bannerEnabled: false, bannerBeforeStart: true }));
    expect(off).toContain('متوقف: لا يظهر البانر، وتبقى الصورة محفوظة');
    expect(off).toContain('data-off="true"');
    expect(off).toContain('يظهر من وقت النشر إلى');
    expect(off).toContain('لا صورة بعد');
    expect(off).not.toContain('إزالة الصورة');
    const forever = design('ar', event({ permanent: true, endsAt: '' }));
    expect(forever).toContain('إلى إنهائها');
  });

  it('in English', () => {
    const e = design('en', event({ bannerMediaId: 'm1' }));
    expect(e).toContain('Live page banner');
    expect(e).toContain('Show the banner on the Live page');
    expect(e).toContain('Recommended size 1500 × 300 px (5:1');
    expect(e).toContain('Crop preview as on a phone (393 pt wide)');
    expect(e).toContain('Shown to: Everyone');
    expect(e).toContain('any audience');
  });
});

describe('D359 local file checks (the server checks again)', () => {
  const png = { type: 'image/png', size: 400_000 };
  it('accepts 1500 × 300 and a larger 5:1 picture', () => {
    expect(hubBannerProblem(png, { w: 1500, h: 300 })).toBeNull();
    expect(hubBannerProblem(png, { w: 3000, h: 600 })).toBeNull();
    expect(hubBannerProblem(png, { w: 1510, h: 300 })).toBeNull(); // ±1 %
  });
  it('refuses the wrong shape, too small, too big, another format', () => {
    expect(hubBannerProblem(png, { w: 1500, h: 500 })).toEqual({ key: 'evHubBannerShape', ratio: 3 });
    expect(hubBannerProblem(png, { w: 1000, h: 200 })).toEqual({ key: 'evHubBannerTooSmall', w: 1000, h: 200 });
    expect(hubBannerProblem({ type: 'image/jpeg', size: 3 * 1048576 }, null)).toMatchObject({ key: 'evHubBannerTooBig' });
    // A GIF / WebP may be animated: the animated limit (5 MB).
    expect(hubBannerProblem({ type: 'image/gif', size: 3 * 1048576 }, { w: 1500, h: 300 })).toBeNull();
    expect(hubBannerProblem({ type: 'image/webp', size: 6 * 1048576 }, null)).toMatchObject({ key: 'evHubBannerTooBig' });
    expect(hubBannerProblem({ type: 'video/mp4', size: 1 }, null)).toEqual({ key: 'evHubBannerFormat' });
  });
  it('the fallback spec equals the published banner spec (5:1, 2 MB, 5 MB, 10 s)', () => {
    expect(HUB_BANNER_SPEC).toMatchObject({
      width: 1500,
      height: 300,
      maxStillBytes: 2 * 1048576,
      maxAnimatedBytes: 5 * 1048576,
      maxDurationMs: 10_000,
    });
  });
});
