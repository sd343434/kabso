import { describe, expect, it } from 'vitest';
import { bannerFieldProblems, bannerLinkProblem, type BannerFields } from './home-banners.js';

describe('bannerLinkProblem (D124 allowlist)', () => {
  it.each([
    '/cp/space',
    '/families',
    '/live?tab=trending',
    '/live?tab=new',
    '/live?tab=following',
    '/home/room/0193a4b2-7c1d-7e2f-8a3b-4c5d6e7f8091',
    '/users/sara.k',
    'https://kabso.app/events/halloween?x=1',
  ])('accepts %s', (link) => {
    expect(bannerLinkProblem(link)).toBeNull();
  });

  it.each([
    '',
    'http://kabso.app',
    'https://',
    'https://user:pass@kabso.app/',
    'javascript:alert(1)',
    '//evil.example',
    '/cp',
    '/cp/space/',
    '/families/123',
    '/live?tab=popular',
    '/live',
    '/home/room/not-a-uuid',
    '/users/Sara',
    '/users/a/medals',
    '/settings',
    '/debug/previews',
    'https://kabso.app/a b',
    `https://kabso.app/${'a'.repeat(600)}`,
  ])('refuses %s', (link) => {
    expect(bannerLinkProblem(link)).not.toBeNull();
  });
});

describe('bannerFieldProblems', () => {
  const ok: BannerFields = {
    titleAr: 'فضاء CP',
    titleEn: 'CP space',
    titleSide: 'RIGHT',
    link: '/cp/space',
    startsAt: new Date('2026-11-01T00:00:00Z'),
    endsAt: new Date('2026-11-08T00:00:00Z'),
    sortOrder: 10,
    enabled: true,
  };

  it('accepts a complete banner and one without text or end', () => {
    expect(bannerFieldProblems(ok)).toEqual([]);
    expect(bannerFieldProblems({ ...ok, titleAr: null, titleEn: null, endsAt: null })).toEqual([]);
  });

  it('refuses an empty or long title, an end before the start and a bad sort', () => {
    expect(bannerFieldProblems({ ...ok, titleAr: '  ' })).toHaveLength(1);
    expect(bannerFieldProblems({ ...ok, titleEn: 'x'.repeat(41) })).toHaveLength(1);
    expect(bannerFieldProblems({ ...ok, endsAt: ok.startsAt })).toHaveLength(1);
    expect(bannerFieldProblems({ ...ok, sortOrder: -1 })).toHaveLength(1);
    expect(bannerFieldProblems({ ...ok, link: '/nope' })).toHaveLength(1);
  });
});
