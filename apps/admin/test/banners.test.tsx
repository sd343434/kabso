/**
 * D248 «إضافة بانر»: adding a banner from the panel — every placement with the size its picture is cropped to (the
 * live hub's card-size banner 720 × 805), the crop preview in that shape, and the `POST /admin/banners` body.
 */
import { renderToStaticMarkup } from 'react-dom/server';
import { describe, expect, it } from 'vitest';
import { AppContext, type AppState } from '../src/context';
import { translate, type Lang } from '../src/i18n';
import { ApiError } from '../src/api';
import {
  animationIssueKey,
  BANNER_PLACEMENT_KEYS,
  BANNER_SHAPES,
  bannerBody,
  BannerForm,
  BannerPreview,
  looksAnimated,
  placementLabelKey,
} from '../src/pages/BannerForm';

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
    expect(html).toContain('بنر بين اللايفات');
    expect(html).toContain('البنر الأساسي');
    expect(html).toContain('داخل البث — بانر صغير');
    expect(html).toContain('image/gif');
    expect(html).toContain('1500 × 300');
    expect(html).toMatch(/<button class="btn primary" disabled="">/);
  });

  it('D394: the link hint offers «برنامج سفراء Kabso» (/ambassadors) in both languages; the body keeps it', () => {
    const ar = render('ar');
    expect(ar).toContain('/ambassadors (برنامج سفراء Kabso)');
    const en = render('en');
    expect(en).toContain('/ambassadors (Kabso Ambassadors Program)');
    for (const placement of BANNER_PLACEMENT_KEYS) {
      expect(render('en', placement)).toContain('/ambassadors');
      expect(
        bannerBody('0193a4b2-7c1d-7e2f-8a3b-4c5d6e7f8091', {
          placement,
          link: ' /ambassadors ',
          titleAr: '',
          titleEn: '',
          titleSide: 'RIGHT',
          startsAt: '',
          endsAt: '',
          sortOrder: '0',
          reason: 'D394',
        }).link,
      ).toBe('/ambassadors');
    }
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

  it('D248c: the three categories preview in their own shapes; an animated file is marked «متحرك»', () => {
    const preview = (placement: keyof typeof BANNER_SHAPES, animated: boolean) =>
      renderToStaticMarkup(
        <AppContext.Provider value={state('ar')}>
          <BannerPreview placement={placement} url="blob:x" animated={animated} />
        </AppContext.Provider>,
      );
    expect(preview('home', true)).toContain('aspect-ratio:1500 / 300');
    expect(preview('home', true)).toContain('متحرك');
    expect(preview('hub_card', true)).toContain('aspect-ratio:720 / 805');
    expect(preview('room', false)).toContain('aspect-ratio:600 / 800');
    expect(preview('room', false)).not.toContain('متحرك');
  });

  it('D248c: detects animated WebP / GIF headers; translates the animation refusals', () => {
    const enc = (s: string) => new Uint8Array([...s].map((c) => c.charCodeAt(0)));
    expect(looksAnimated(enc('RIFF\0\0\0\0WEBPVP8X\0\0\0\0\0\0\0\0\0\0\0\0ANIM'))).toBe(true);
    expect(looksAnimated(enc('RIFF\0\0\0\0WEBPVP8 \0\0\0\0'))).toBe(false);
    const gce = '\x21\xf9\x04\0\0\0\0';
    expect(looksAnimated(enc('GIF89a' + gce + 'x' + gce))).toBe(true);
    expect(looksAnimated(enc('GIF89a' + gce))).toBe(false);
    const err = new ApiError(409, 'ADMIN_ACTION_REFUSED', 'x', null, [{ field: 'file', issue: 'banner_animation_too_long' }]);
    expect(animationIssueKey(err)).toBe('bannerAnimTooLong');
    expect(translate('ar', 'bannerAnimTooLong')).toContain('10 ثوانٍ');
    expect(animationIssueKey(new Error('x'))).toBeNull();
  });
});
