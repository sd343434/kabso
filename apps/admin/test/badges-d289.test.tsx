/**
 * D289 «شارات الهدايا والمتجر» (CONVENTIONS §10.102): the panel's badge choice for gifts and store items — the two sound
 * badges exclude each other (the panel never sends both), what the uploaded file shows is pre-selected and marked
 * «تلقائي» (and can be changed), the dates of «جديد» (14 days by default) / «لفترة محدودة» / «موسمي» (required), ended
 * badges listed but not sent back; the picker rendered in both languages; the gift and store bodies.
 */
import { renderToStaticMarkup } from 'react-dom/server';
import { describe, expect, it } from 'vitest';
import {
  applyDetection,
  BADGE_COLORS,
  BADGE_ORDER,
  badgeProblems,
  badgesBody,
  badgesChanged,
  badgesPart,
  badgeState,
  daysLeft,
  defaultNewUntil,
  seasonalWithoutEnd,
  setBadgeUntil,
  toggleBadge,
  type AdminItemBadge,
} from '../src/badges';
import { AppContext, type AppState } from '../src/context';
import { translate, type Lang } from '../src/i18n';
import { AR_D289, EN_D289 } from '../src/i18n-d289';
import { autoOn, detectFromFiles } from '../src/pages/Catalog';
import { BadgeChip, BadgePicker, SeasonalNoEndHint, SeasonalNoEndNote } from '../src/pages/BadgePicker';
import { NO_FILE } from '../src/pages/GiftFiles';
import { draftOf, draftValid, itemBody, type AdminStoreItem } from '../src/pages/Store';
import { BADGE_ICON_PATHS } from '../src/ui/badge-icons';
import type { Capability } from '../src/types';

const NOW = new Date('2027-03-23T09:00:00.000Z');
const state = (lang: Lang): AppState => ({
  lang,
  t: (key, vars) => translate(lang, key, vars),
  session: null,
  can: (c: Capability) => c === 'catalog.manage',
  toast: () => undefined,
});
const render = (lang: Lang, node: React.ReactNode) =>
  renderToStaticMarkup(<AppContext.Provider value={state(lang)}>{node}</AppContext.Provider>);

describe('the badge choice (D289)', () => {
  it('has the nine badges in priority, each with one icon, a colour and both languages', () => {
    expect(BADGE_ORDER).toEqual([
      'LIMITED',
      'NEW',
      'SEASONAL',
      'EXCLUSIVE',
      'MOST_WANTED',
      'FEATURED',
      'FULLSCREEN',
      'SOUND',
      'NO_SOUND',
    ]);
    for (const code of BADGE_ORDER) {
      expect(BADGE_ICON_PATHS[code].length).toBeGreaterThan(0);
      expect(BADGE_COLORS[code].fill).toMatch(/^#[0-9A-F]{6}$/);
      expect(AR_D289[`badge${code}` as keyof typeof AR_D289]).toBeTruthy();
      expect(EN_D289[`badge${code}` as keyof typeof EN_D289]).toBeTruthy();
    }
    // The owner's colours: offer red, new green, most wanted gold, sound blue.
    expect(BADGE_COLORS.LIMITED.fill).toBe('#E50914');
    expect(BADGE_COLORS.NEW.fill).toBe('#137A43');
    expect(BADGE_COLORS.MOST_WANTED.fill).toBe('#F5C451');
    expect(BADGE_COLORS.SOUND.fill).toBe('#1A64BF');
    expect(AR_D289.badgeSOUND).toBe('بمؤثرات صوتية');
    expect(AR_D289.badgeNO_SOUND).toBe('بدون مؤثرات صوتية');
    expect(AR_D289.badgeMOST_WANTED).toBe('الأكثر طلباً');
  });

  it('the two sound badges exclude each other: ticking one clears the other; never both in the body', () => {
    let s = toggleBadge(badgeState(), 'SOUND', true);
    expect(s.SOUND.on).toBe(true);
    s = toggleBadge(s, 'NO_SOUND', true);
    expect([s.SOUND.on, s.NO_SOUND.on]).toEqual([false, true]);
    s = toggleBadge(s, 'SOUND', true);
    expect([s.SOUND.on, s.NO_SOUND.on]).toEqual([true, false]);
    expect(badgesBody(s)).toEqual([{ code: 'SOUND' }]);
    // A state forced into both (it cannot be reached through the picker) is a problem the form blocks.
    expect(badgeProblems({ ...s, NO_SOUND: { ...s.NO_SOUND, on: true } }, NOW)).toEqual(['sound']);
    // Unticking keeps the other off.
    expect(toggleBadge(s, 'SOUND', false).NO_SOUND.on).toBe(false);
  });

  it('pre-selects from the files — sound, no sound, full screen — marked auto, and the owner can change it', () => {
    const mp4 = applyDetection(badgeState(), { hasEffect: true, hasAudio: true, fullscreen: true });
    expect(mp4.SOUND).toMatchObject({ on: true, auto: true });
    expect(mp4.FULLSCREEN).toMatchObject({ on: true, auto: true });
    expect(mp4.NO_SOUND.on).toBe(false);
    const silent = applyDetection(mp4, { hasEffect: true, hasAudio: false, fullscreen: false });
    expect([silent.SOUND.on, silent.NO_SOUND.on, silent.FULLSCREEN.on]).toEqual([false, true, false]);
    expect(silent.NO_SOUND.auto).toBe(true);
    const changed = toggleBadge(silent, 'NO_SOUND', false);
    expect(changed.NO_SOUND).toMatchObject({ on: false, auto: false });
    // The gift's form: an MP3 sound means «بمؤثرات صوتية» even with a silent effect.
    const files = {
      image: NO_FILE,
      animation: {
        key: 'media/gifts/rose/a.svga',
        url: null,
        info: { kind: 'animation' as const, key: 'k', url: null, bytes: 1, contentType: 'x', hasAudio: false, fullscreen: true },
      },
      alpha: 'NONE' as const,
      sound: { key: 'media/gifts/rose/b.mp3', url: null },
    };
    expect(detectFromFiles(files)).toEqual({ hasEffect: true, hasAudio: true, fullscreen: true });
    expect(detectFromFiles({ ...files, sound: NO_FILE })).toEqual({ hasEffect: true, hasAudio: false, fullscreen: true });
    const picked = applyDetection(badgeState(), detectFromFiles(files));
    expect(autoOn(picked)).toEqual(['FULLSCREEN', 'SOUND']);
    // The owner's other choices stay.
    const mine = applyDetection(toggleBadge(badgeState(), 'EXCLUSIVE', true), { hasEffect: true, hasAudio: true });
    expect(mine.EXCLUSIVE).toMatchObject({ on: true, auto: false });
  });

  it('dates: «جديد» 14 days by default, «لفترة محدودة» / «موسمي» need a future date within a year', () => {
    let s = toggleBadge(toggleBadge(badgeState(), 'NEW', true), 'LIMITED', true);
    expect(badgeProblems(s, NOW)).toEqual(['LIMITED:until_required']);
    expect(defaultNewUntil(NOW)).toBe('2027-04-06');
    s = setBadgeUntil(s, 'LIMITED', '2027-03-22');
    expect(badgeProblems(s, NOW)).toEqual(['LIMITED:until_past']);
    s = setBadgeUntil(s, 'LIMITED', '2028-04-01');
    expect(badgeProblems(s, NOW)).toEqual(['LIMITED:until_too_far']);
    s = setBadgeUntil(s, 'LIMITED', '2027-03-23');
    expect(badgeProblems(s, NOW)).toEqual([]);
    // The end is the end of that day; NEW without a date sends none (the server sets 14 days).
    expect(badgesBody(s)).toEqual([{ code: 'LIMITED', until: '2027-03-23T23:59:59.999Z' }, { code: 'NEW' }]);
    s = toggleBadge(s, 'SEASONAL', true);
    expect(badgeProblems(s, NOW)).toEqual(['SEASONAL:until_required']);
    expect(daysLeft('2027-03-26T09:00:00.000Z', NOW)).toBe(3);
  });

  it('a stored set: ended badges are listed, not ticked and not sent back; an unchanged set is not sent', () => {
    const stored: AdminItemBadge[] = [
      { code: 'LIMITED', until: '2027-03-20T00:00:00.000Z', active: false },
      { code: 'NEW', until: '2027-04-01T09:00:00.000Z', active: true },
      { code: 'SOUND', until: null, active: true },
    ];
    const s = badgeState(stored);
    expect(s.LIMITED).toMatchObject({ on: false, ended: true });
    expect(s.NEW).toMatchObject({ on: true, until: '2027-04-01' });
    expect(badgesChanged(s, stored)).toBe(false);
    expect(badgesPart(s, { badges: stored })).toEqual({});
    const edited = toggleBadge(s, 'MOST_WANTED', true);
    expect(badgesPart(edited, { badges: stored })).toEqual({
      badges: [{ code: 'NEW', until: '2027-04-01T23:59:59.999Z' }, { code: 'MOST_WANTED' }, { code: 'SOUND' }],
    });
    expect(badgesPart(badgeState(), null)).toEqual({});
    expect(badgesPart(toggleBadge(badgeState(), 'FEATURED', true), null)).toEqual({ badges: [{ code: 'FEATURED' }] });
  });

  it('renders the picker in Arabic and English: the exclusion line, «تلقائي», the dates, ended', () => {
    const s = applyDetection(
      badgeState([{ code: 'SEASONAL', until: '2027-03-01T00:00:00.000Z', active: false }]),
      { hasEffect: true, hasAudio: true, fullscreen: true },
    );
    const withNew = toggleBadge(toggleBadge(s, 'NEW', true), 'LIMITED', true);
    const ar = render('ar', <BadgePicker value={withNew} onChange={() => undefined} now={NOW} detected={['FULLSCREEN', 'SOUND']} />);
    expect(ar).toContain('الشارات');
    expect(ar).toContain('«بمؤثرات صوتية» و«بدون مؤثرات صوتية» لا يجتمعان');
    expect(ar).toContain('اختير تلقائياً من الملف: شاشة كاملة، بمؤثرات صوتية');
    expect(ar.match(/data-badge-auto="/g)?.length).toBe(2);
    expect(ar).toContain('دون تاريخ: بعد 14 يوماً (2027-04-06)');
    expect(ar).toContain('اختر تاريخ الانتهاء.');
    expect(ar).toContain('انتهت');
    for (const code of BADGE_ORDER) expect(ar).toContain(`data-badge-row="${code}"`);
    const en = render('en', <BadgePicker value={withNew} onChange={() => undefined} now={NOW} />);
    expect(en).toContain('“With sound” and “No sound” cannot both be chosen');
    expect(en).toContain('Choose the end date.');
    expect(en).not.toContain('data-badge-detected');
    const chip = render('ar', <BadgeChip code="MOST_WANTED" iconOnly />);
    expect(chip).toContain('data-badge-icon="MOST_WANTED"');
    expect(chip).toContain('background:#F5C451');
    expect(chip).toContain('الأكثر طلباً');
  });

  it('the store form sends the badges (not isNew) and blocks a limited offer without a date', () => {
    const before: AdminStoreItem = {
      id: 'i',
      code: 'store_0123456789ab',
      kind: 'AVATAR_FRAME',
      nameAr: 'إطار',
      nameEn: 'Frame',
      still: 'https://cdn.k.test/a.png',
      animation: null,
      animationFormat: null,
      animationAlpha: null,
      artWidth: null,
      artHeight: null,
      prices: [{ currency: 'COINS', days: 7, amount: 50_000 }],
      sortOrder: 10,
      isNew: true,
      badges: [{ code: 'NEW', until: '2027-04-02T09:00:00.000Z', active: true }],
      enabled: true,
      hiddenAt: null,
      owners: 0,
      sold: 0,
      createdAt: '2027-03-01T00:00:00.000Z',
      updatedAt: '2027-03-01T00:00:00.000Z',
    };
    const d = draftOf(before);
    expect(itemBody(d, before)).toEqual({});
    const offer = { ...d, badges: toggleBadge(d.badges, 'LIMITED', true) };
    expect(draftValid(offer, NOW)).toBe(false);
    const dated = { ...offer, badges: setBadgeUntil(offer.badges, 'LIMITED', '2027-04-01') };
    expect(draftValid(dated, NOW)).toBe(true);
    expect(itemBody(dated, before)).toEqual({
      badges: [{ code: 'LIMITED', until: '2027-04-01T23:59:59.999Z' }, { code: 'NEW', until: '2027-04-02T23:59:59.999Z' }],
    });
    const created = itemBody({ ...draftOf(null), nameAr: 'x', nameEn: 'x', badges: toggleBadge(badgeState(), 'MOST_WANTED', true) }, null);
    expect(created).toMatchObject({ badges: [{ code: 'MOST_WANTED' }] });
    expect(created).not.toHaveProperty('isNew');
  });

  it('owner Q2: a «موسمي» without an end (migrated from EVENT) is marked in the lists, counted, filterable, and needs a date to be saved', () => {
    const legacy: AdminItemBadge[] = [{ code: 'SEASONAL', until: null, active: true }];
    expect(seasonalWithoutEnd(legacy)).toBe(true);
    expect(seasonalWithoutEnd([{ code: 'SEASONAL', until: '2027-04-01T00:00:00.000Z', active: true }])).toBe(false);
    expect(seasonalWithoutEnd([{ code: 'NEW', until: null, active: true }])).toBe(false);
    expect(seasonalWithoutEnd([])).toBe(false);
    const ar = render('ar', <SeasonalNoEndNote count={3} only={false} onOnly={() => undefined} />);
    expect(ar).toContain('3 بشارة «موسمي» بلا تاريخ انتهاء');
    expect(ar).toContain('عرضها فقط');
    expect(ar).toContain('data-seasonal-filter="off"');
    const en = render('en', <SeasonalNoEndNote count={3} only onOnly={() => undefined} />);
    expect(en).toContain('Show all');
    expect(render('ar', <SeasonalNoEndNote count={0} only={false} onOnly={() => undefined} />)).toBe('');
    expect(render('ar', <SeasonalNoEndHint />)).toContain('حدد تاريخ الانتهاء');
    // Opened in the form, it is ticked without a date: the save waits for one.
    const s = badgeState(legacy);
    expect(s.SEASONAL).toMatchObject({ on: true, until: '' });
    expect(badgeProblems(s, NOW)).toEqual(['SEASONAL:until_required']);
    expect(badgeProblems(setBadgeUntil(s, 'SEASONAL', '2027-04-10'), NOW)).toEqual([]);
  });
});
