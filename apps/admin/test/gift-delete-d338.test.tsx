/**
 * D338 (owner: «أريد زر لإزالتهم وليس فقط إيقافهم»; CONVENTIONS §10.131): «حذف» of a gift in «الهدايا» — the confirm
 * dialog says which case applies (deleted for good when nothing ever used it, else moved to «المحذوفة»), the normal list
 * hides archived gifts and the «المحذوفة» filter shows only them; OWNER only (catalog.manage). Both languages.
 */
import { renderToStaticMarkup } from 'react-dom/server';
import { describe, expect, it } from 'vitest';
import { AppContext, type AppState } from '../src/context';
import { DICTIONARIES, translate, type Lang } from '../src/i18n';
import { AR_D338, EN_D338 } from '../src/i18n-d338';
import { GiftDeleteIntro, giftDeleteCase, giftsShown, type GiftDto } from '../src/pages/Catalog';
import type { Capability } from '../src/types';
import { CAPABILITY_ROLES } from './capabilities';

const state = (lang: Lang, caps: Capability[] = []): AppState => ({
  lang,
  t: (key, vars) => translate(lang, key, vars),
  session: null,
  can: (c) => caps.includes(c),
  toast: () => undefined,
});
const render = (lang: Lang, node: React.ReactNode) =>
  renderToStaticMarkup(<AppContext.Provider value={state(lang)}>{node}</AppContext.Provider>);

const gift = (over: Partial<GiftDto>): GiftDto => ({
  code: 'rose',
  category: 'POPULAR',
  nameAr: 'وردة',
  nameEn: 'Rose',
  priceCoins: 10,
  priceUsd: '0.00',
  assetKey: 'rose',
  animationKey: null,
  imageUrl: null,
  hostedAnimation: false,
  imageObjectKey: null,
  animationObjectKey: null,
  animationUrl: null,
  animationFormat: null,
  animationAlpha: null,
  animationBytes: null,
  audioObjectKey: null,
  audioUrl: null,
  audioMs: null,
  sortOrder: 0,
  badge: 'NONE',
  badges: [],
  lucky: false,
  tagCode: null,
  tagNameAr: null,
  tagNameEn: null,
  soundKey: null,
  soundMs: null,
  quipText: null,
  enabled: true,
  sends: 0,
  coinsSpent: 0,
  archivedAt: null,
  inUse: false,
  holders: 0,
  pieces: 0,
  ...over,
});

describe('D338 «حذف» a gift', () => {
  it('the case follows the server’s inUse: never used → delete for good, used → archive', () => {
    expect(giftDeleteCase(gift({ inUse: false }))).toBe('delete');
    expect(giftDeleteCase(gift({ inUse: true, sends: 0, holders: 1 }))).toBe('archive');
  });

  it('the dialog names the case (ar and en): delete for good, or archive with the sends', () => {
    const forever = render('ar', <GiftDeleteIntro gift={gift({})} />);
    expect(forever).toContain('data-gift-delete-case="delete"');
    expect(forever).toContain('ستُحذف نهائياً');
    const sent = render('en', <GiftDeleteIntro gift={gift({ inUse: true, sends: 1234 })} />);
    expect(sent).toContain('data-gift-delete-case="archive"');
    expect(sent).toContain('history (sent 1,234 times).');
    // Named only by another record (an event, a wish list): no numbers.
    const other = render('ar', <GiftDeleteIntro gift={gift({ inUse: true })} />);
    expect(other).toContain('لأن لها سجلاً.');
  });

  it('owner «مخفية الا ان تنتهي من حقيبة المستخدمين ثم تحذف»: with pieces out the dialog says they stay until used', () => {
    const ar = render('ar', <GiftDeleteIntro gift={gift({ inUse: true, sends: 5, holders: 3, pieces: 12 })} />);
    expect(ar).toContain('data-gift-delete-case="archive"');
    expect(ar).toContain('ستختفي من المتجر، وتبقى 12 قطعة في حقائب 3 مستخدمين حتى تُستخدم');
    const en = render('en', <GiftDeleteIntro gift={gift({ inUse: true, holders: 1, pieces: 2 })} />);
    expect(en).toContain('2 pieces stay in 1 users’ bags until they are used');
  });

  it('the normal list hides archived gifts; the «المحذوفة» filter shows only them (with the category filter)', () => {
    const all = [
      gift({ code: 'a' }),
      gift({ code: 'b', archivedAt: '2026-11-09T08:00:00.000Z', enabled: false, inUse: true }),
      gift({ code: 'c', category: 'FUN', archivedAt: '2026-11-09T08:00:00.000Z', enabled: false, inUse: true }),
      gift({ code: 'd', enabled: false }),
    ];
    const codes = (l: GiftDto[]) => l.map((g) => g.code);
    expect(codes(giftsShown(all, { cat: '', noEndOnly: false, archivedOnly: false }))).toEqual(['a', 'd']);
    expect(codes(giftsShown(all, { cat: '', noEndOnly: false, archivedOnly: true }))).toEqual(['b', 'c']);
    expect(codes(giftsShown(all, { cat: 'FUN', noEndOnly: false, archivedOnly: true }))).toEqual(['c']);
  });

  it('every text exists in both languages', () => {
    expect(Object.keys(EN_D338).sort()).toEqual(Object.keys(AR_D338).sort());
    for (const key of Object.keys(AR_D338)) {
      expect(DICTIONARIES.ar[key as keyof typeof DICTIONARIES.ar]).toBeTruthy();
      expect(DICTIONARIES.en[key as keyof typeof DICTIONARIES.en]).toBeTruthy();
    }
  });

  it('delete and restore need catalog.manage: OWNER only, as the server', () => {
    expect(CAPABILITY_ROLES['catalog.manage']).toEqual(['OWNER']);
  });
});
