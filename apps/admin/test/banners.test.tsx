/**
 * D248 «إضافة بانر»: adding a banner from the panel — every placement with the size its picture is cropped to (the
 * live hub's card-size banner 720 × 805), the crop preview in that shape, and the `POST /admin/banners` body.
 */
import { renderToStaticMarkup } from 'react-dom/server';
import { describe, expect, it } from 'vitest';
import { AppContext, type AppState } from '../src/context';
import { translate, type Lang } from '../src/i18n';
import { BANNER_PLACEMENT_KEYS, BANNER_SHAPES, bannerBody, BannerForm, placementLabelKey } from '../src/pages/BannerForm';

const state = (lang: Lang): AppState => ({
  lang,
  t: (key, vars) => translate(lang, key, vars),
  session: null,
  can: () => true,
  toast: () => undefined,
});

const render = (lang: Lang, placement: keyof typeof BANNER_SHAPES = 'home') =>
  renderToStaticMarkup(
    <AppContext.Provider value={state(lang)}>
      <BannerForm
        onClose={() => undefined}
        onDone={() => undefined}
        initial={{
          placement,
          link: '',
          titleAr: '',
          titleEn: '',
          titleSide: 'RIGHT',
          startsAt: '',
          endsAt: '',
          sortOrder: '0',
          reason: '',
        }}
      />
    </AppContext.Provider>,
  );

describe('D248 add a banner', () => {
  it('Arabic: every placement offered, the hub card one named, the add button disabled until filled', () => {
    const html = render('ar');
    expect(html).toContain('إضافة بانر');
    for (const p of BANNER_PLACEMENT_KEYS) expect(html).toContain(`value="${p}"`);
    expect(html).toContain('بانر بحجم بطاقة البث');
    expect(html).toContain('1500 × 300');
    expect(html).toMatch(/<button class="btn primary" disabled="">/);
  });

  it('the hub card: 720 × 805 and a preview in the live card shape', () => {
    const html = render('en', 'hub_card');
    expect(html).toContain('Design the picture at 720 × 805 px');
    expect(html).toContain('aspect-ratio:720 / 805');
    expect(BANNER_SHAPES.hub_card.width / BANNER_SHAPES.hub_card.height).toBeCloseTo(0.894, 3);
  });

  it('the body: trimmed, optional fields only when filled, ISO times', () => {
    const body = bannerBody('0193a4b2-7c1d-7e2f-8a3b-4c5d6e7f8091', {
      placement: 'hub_card',
      link: ' /families ',
      titleAr: '  ',
      titleEn: 'Families',
      titleSide: 'RIGHT',
      startsAt: '2026-11-03T10:00',
      endsAt: '',
      sortOrder: '2',
      reason: ' owner ref ',
    });
    expect(body).toEqual({
      mediaId: '0193a4b2-7c1d-7e2f-8a3b-4c5d6e7f8091',
      placement: 'hub_card',
      link: '/families',
      titleEn: 'Families',
      titleSide: 'RIGHT',
      startsAt: new Date('2026-11-03T10:00').toISOString(),
      sortOrder: 2,
      reason: 'owner ref',
    });
  });

  it('placement labels for stored values; every key has both languages', () => {
    expect(placementLabelKey('HUB_CARD')).toBe('bannerPlacement_hub_card');
    expect(placementLabelKey('ODD')).toBeNull();
    for (const key of ['bannerCreate', 'bannerPlacement_hub_card', 'bannerSizeHint', 'bannerPreview'] as const) {
      expect(translate('ar', key)).not.toBe(translate('en', key));
    }
  });
});
