/**
 * D291 «الميداليات»: each medal's tab and levels in the panel, rendered to HTML in Node — holders per level, read-only
 * for SUPPORT, editable for the OWNER; rising thresholds, one level on 0/1 medals, held levels never removed, https
 * art only; the PUT body. Both languages.
 */
import { renderToStaticMarkup } from 'react-dom/server';
import { describe, expect, it } from 'vitest';
import { AppContext, type AppState } from '../src/context';
import { DICTIONARIES, translate, type Lang } from '../src/i18n';
import { AR_D291, EN_D291 } from '../src/i18n-d291';
import { NAV } from '../src/nav';
import { matchPath } from '../src/router';
import { draftOf, draftProblem, levelsBody, MedalLevelsForm, type MedalDraft } from '../src/pages/Medals';
import type { AdminMedal, Capability } from '../src/types';
import { CAPABILITY_ROLES } from './capabilities';

const state = (lang: Lang, caps: Capability[]): AppState => ({
  lang,
  t: (key, vars) => translate(lang, key, vars),
  session: null,
  can: (c) => caps.includes(c),
  toast: () => undefined,
});
const capsOf = (role: 'OWNER' | 'SUPPORT') =>
  (Object.keys(CAPABILITY_ROLES) as Capability[]).filter((c) => CAPABILITY_ROLES[c]!.includes(role));
const render = (lang: Lang, caps: Capability[], node: React.ReactNode) =>
  renderToStaticMarkup(<AppContext.Provider value={state(lang, caps)}>{node}</AppContext.Provider>);

const LIVES: AdminMedal = {
  code: 'FIRST_LIVE',
  nameAr: 'أول لايف',
  nameEn: 'First live',
  iconKey: 'medal_first_live',
  sortOrder: 10,
  category: 'ACTIVITY',
  metric: 'LIVES_HOSTED',
  retired: false,
  holders: 1250,
  levels: [1, 10, 50, 100, 500].map((threshold, i) => ({
    level: i + 1,
    threshold,
    nameAr: null,
    nameEn: null,
    iconUrl: null,
    iconAsset: null,
    holders: [900, 300, 50, 0, 0][i]!,
  })),
};
const FAMILY: AdminMedal = {
  ...LIVES,
  code: 'FIRST_FAMILY',
  nameAr: 'أول عائلة',
  nameEn: 'First family',
  category: 'ACHIEVEMENT',
  metric: 'FAMILY_JOINED',
  holders: 3,
  levels: [{ level: 1, threshold: 1, nameAr: null, nameEn: null, iconUrl: null, iconAsset: null, holders: 3 }],
};
const noop = () => undefined;

describe('D291 medals in the panel', () => {
  it('has every string in both languages, a route and a nav item under catalog.view', () => {
    expect(Object.keys(EN_D291).sort()).toEqual(Object.keys(AR_D291).sort());
    for (const k of Object.keys(AR_D291)) {
      expect(DICTIONARIES.ar[k as keyof typeof AR_D291]).toBeTruthy();
      expect(DICTIONARIES.en[k as keyof typeof AR_D291]).toBeTruthy();
    }
    expect(matchPath('/medals')?.name).toBe('medals');
    const item = NAV.flatMap((g) => g.items).find((i) => i.to === '/medals');
    expect(item?.cap).toBe('catalog.view');
  });

  it('SUPPORT reads the levels, thresholds and holders per level, with no edit buttons', () => {
    const html = render('ar', capsOf('SUPPORT'), (
      <MedalLevelsForm medal={LIVES} draft={draftOf(LIVES)} onChange={noop} onSave={noop} />
    ));
    expect(html).toContain('أول لايف');
    expect(html).toContain('عدد البثوث المنتهية');
    expect(html).toContain('1,250 يحملها');
    expect(html.match(/data-level="/g)).toHaveLength(5);
    expect(html).toMatch(/data-level="2".*?value="10".*?data-holders[^>]*>300</s);
    expect(html).not.toContain('data-medal-save');
    expect(html).not.toContain('data-add-level');
  });

  it('the OWNER edits: add / remove, nothing changed cannot be saved; a 0/1 medal keeps one level', () => {
    const same = render('en', capsOf('OWNER'), (
      <MedalLevelsForm medal={LIVES} draft={draftOf(LIVES)} onChange={noop} onSave={noop} />
    ));
    expect(same).toContain('data-add-level');
    expect(same).toContain('No change');
    expect(same).toMatch(/<button[^>]*disabled=""[^>]*data-medal-save/);
    // The last level (500) is held by nobody: it can be removed.
    expect(same).not.toMatch(/<button[^>]*disabled=""[^>]*data-remove-level/);
    const fam = render('en', capsOf('OWNER'), (
      <MedalLevelsForm medal={FAMILY} draft={draftOf(FAMILY)} onChange={noop} onSave={noop} />
    ));
    expect(fam).toContain('Joined a family (once)');
    expect(fam).not.toContain('data-add-level');
  });

  it('rules: rising thresholds, one level on 0/1 medals, held levels kept, https art; the PUT body', () => {
    const d = draftOf(LIVES);
    expect(draftProblem(LIVES, d)).toBeNull();
    const falling: MedalDraft = { ...d, levels: d.levels.map((l, i) => (i === 2 ? { ...l, threshold: 5 } : l)) };
    expect(draftProblem(LIVES, falling)?.key).toBe('mdRising');
    const cut: MedalDraft = { ...d, levels: d.levels.slice(0, 2) };
    expect(draftProblem(LIVES, cut)).toEqual({ key: 'mdHeld', vars: { n: 3 } });
    expect(translate('ar', 'mdHeld', { n: 3 })).toContain('المستوى 3');
    const http: MedalDraft = { ...d, levels: d.levels.map((l, i) => (i === 0 ? { ...l, iconUrl: 'http://x/a.png' } : l)) };
    expect(draftProblem(LIVES, http)?.key).toBe('mdBadUrl');
    const asset: MedalDraft = { ...d, levels: d.levels.map((l, i) => (i === 0 ? { ...l, iconAsset: 'Bad Name' } : l)) };
    expect(draftProblem(LIVES, asset)?.key).toBe('mdBadAsset');
    const two: MedalDraft = { ...draftOf(FAMILY), levels: [...draftOf(FAMILY).levels, { threshold: 2, nameAr: '', nameEn: '', iconUrl: '', iconAsset: '' }] };
    expect(draftProblem(FAMILY, two)?.key).toBe('mdSingle');

    const named: MedalDraft = {
      category: 'ACHIEVEMENT',
      levels: [
        { threshold: 1, nameAr: '', nameEn: ' ', iconUrl: '', iconAsset: 'medal_wealth_l1' },
        { threshold: 20, nameAr: 'نجم', nameEn: 'Star', iconUrl: ' https://cdn.k.test/a.png ', iconAsset: '' },
      ],
    };
    expect(levelsBody(named)).toEqual([
      { threshold: 1, nameAr: null, nameEn: null, iconUrl: null, iconAsset: 'medal_wealth_l1' },
      { threshold: 20, nameAr: 'نجم', nameEn: 'Star', iconUrl: 'https://cdn.k.test/a.png', iconAsset: null },
    ]);
    const changed = render('en', capsOf('OWNER'), (
      <MedalLevelsForm medal={LIVES} draft={{ ...d, category: 'ACHIEVEMENT' }} onChange={noop} onSave={noop} />
    ));
    expect(changed).toContain('Save levels');
    expect(changed).not.toMatch(/<button[^>]*disabled=""[^>]*data-medal-save/);
  });

  it('a retired code (a name-side icon) is shown read-only to the OWNER', () => {
    const charm: AdminMedal = { ...LIVES, code: 'CHARM_10', nameEn: 'Charm 10', retired: true };
    const html = render('en', capsOf('OWNER'), (
      <MedalLevelsForm medal={charm} draft={draftOf(charm)} onChange={noop} onSave={noop} />
    ));
    expect(html).toContain('data-retired');
    expect(html).toContain('Not a wearable medal');
    expect(html).not.toContain('data-medal-save');
    expect(html).not.toContain('data-add-level');
  });
});
