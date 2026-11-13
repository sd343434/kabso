/**
 * D300 «مدرسة المحتوى» in the panel's levels editor, rendered to HTML in Node: three thresholds per level (followers,
 * likes, views) instead of one, read-only for SUPPORT, editable for the OWNER; the rules (each level's threshold is its
 * number, one value per requirement, rising per requirement, held levels kept); the PUT body; single-metric medals
 * unchanged. Both languages.
 */
import { renderToStaticMarkup } from 'react-dom/server';
import { describe, expect, it } from 'vitest';
import { AppContext, type AppState } from '../src/context';
import { DICTIONARIES, translate, type Lang } from '../src/i18n';
import { AR_D300, EN_D300 } from '../src/i18n-d300';
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
const noop = () => undefined;

const THRESHOLDS = [
  [2_000, 10_000, 20_000],
  [10_000, 50_000, 100_000],
  [100_000, 200_000, 500_000],
  [1_000_000, 2_000_000, 5_000_000],
];
const SCHOOL: AdminMedal = {
  code: 'CONTENT_SCHOOL',
  nameAr: 'مدرسة المحتوى',
  nameEn: 'Content School',
  iconKey: 'medal_content_school',
  sortOrder: 120,
  category: 'ACHIEVEMENT',
  metric: 'ALL_REQUIREMENTS',
  retired: false,
  holders: 12,
  levels: THRESHOLDS.map(([f, l, v], i) => ({
    level: i + 1,
    threshold: i + 1,
    nameAr: null,
    nameEn: null,
    iconUrl: null,
    iconAsset: `medal_content_school_l${String(i + 1)}`,
    holders: [8, 3, 1, 0][i]!,
    // Out of order on purpose: the editor sorts followers, likes, views.
    requirements: [
      { metric: 'CREATOR_VIEWS' as const, threshold: v! },
      { metric: 'CREATOR_FOLLOWERS' as const, threshold: f! },
      { metric: 'CREATOR_LIKES' as const, threshold: l! },
    ],
  })),
};

describe('D300 «مدرسة المحتوى» in the panel', () => {
  it('has every string in both languages, the «PK أحكام» points metric included', () => {
    expect(AR_D300.mdMetricPK_DARES_POINTS).toBe('نقاط PK أحكام (لاعب الأحكام)');
    expect(EN_D300.mdMetricPK_DARES_POINTS).toBe('«PK أحكام» points (Dares Player)');
    expect(Object.keys(EN_D300).sort()).toEqual(Object.keys(AR_D300).sort());
    for (const k of Object.keys(AR_D300)) {
      expect(DICTIONARIES.ar[k as keyof typeof AR_D300]).toBeTruthy();
      expect(DICTIONARIES.en[k as keyof typeof AR_D300]).toBeTruthy();
    }
  });

  it('shows three thresholds per level (followers, likes, views) and no single threshold; read-only for SUPPORT', () => {
    const html = render(
      'ar',
      capsOf('SUPPORT'),
      <MedalLevelsForm medal={SCHOOL} draft={draftOf(SCHOOL)} onChange={noop} onSave={noop} />,
    );
    expect(html).toContain('مدرسة المحتوى');
    expect(html).toContain('عدة شروط معاً (لصنّاع المحتوى)');
    expect([...html.matchAll(/data-requirement-head="([A-Z_]+)"[^>]*>([^<]+)</g)].map((m) => [m[1], m[2]])).toEqual([
      ['CREATOR_FOLLOWERS', 'المتابعون'],
      ['CREATOR_LIKES', 'الإعجابات'],
      ['CREATOR_VIEWS', 'المشاهدات'],
    ]);
    expect(html).not.toContain('>الحد<');
    expect(html.match(/data-level="/g)).toHaveLength(4);
    for (const [i, [f, l, v]] of THRESHOLDS.entries()) {
      const row = html.split(`data-level="${String(i + 1)}"`)[1]!.split('</tr>')[0]!;
      expect(row).toMatch(new RegExp(`data-requirement="CREATOR_FOLLOWERS".*?value="${String(f)}"`, 's'));
      expect(row).toMatch(new RegExp(`data-requirement="CREATOR_LIKES".*?value="${String(l)}"`, 's'));
      expect(row).toMatch(new RegExp(`data-requirement="CREATOR_VIEWS".*?value="${String(v)}"`, 's'));
      expect(row.match(/<input[^>]*type="number"[^>]*disabled=""/g)).toHaveLength(3);
    }
    expect(html).toContain('data-requirements-hint');
    expect(html).not.toContain('data-medal-save');
  });

  it('the OWNER edits the three numbers in English; the levels are labelled', () => {
    const html = render(
      'en',
      capsOf('OWNER'),
      <MedalLevelsForm medal={SCHOOL} draft={draftOf(SCHOOL)} onChange={noop} onSave={noop} />,
    );
    expect(html).toContain('Several requirements together (content creators)');
    expect(html).toContain('aria-label="Followers 1"');
    expect(html).toContain('aria-label="Likes 4"');
    expect(html).toContain('aria-label="Views 2"');
    expect(html).not.toMatch(/aria-label="Followers 1"[^>]*disabled=""/);
    expect(html).toContain('data-add-level');
    expect(html).toContain('No change');
  });

  it('rules: valid as seeded; falling, missing or the wrong level number refused; held levels kept; the PUT body', () => {
    const d = draftOf(SCHOOL);
    expect(draftProblem(SCHOOL, d)).toBeNull();
    const set = (level: number, patch: object): MedalDraft => ({
      ...d,
      levels: d.levels.map((l, i) => (i === level - 1 ? { ...l, ...patch } : l)),
    });
    const reqs = (level: number) => d.levels[level - 1]!.requirements!;
    // Level 2's followers below level 1's.
    const falling = set(2, {
      requirements: reqs(2).map((r) => (r.metric === 'CREATOR_FOLLOWERS' ? { ...r, threshold: 1_000 } : r)),
    });
    expect(draftProblem(SCHOOL, falling)?.key).toBe('mdReqRising');
    expect(draftProblem(SCHOOL, set(3, { requirements: reqs(3).slice(0, 2) }))?.key).toBe('mdReqRising');
    expect(draftProblem(SCHOOL, set(1, { threshold: 7 }))?.key).toBe('mdReqRising');
    expect(draftProblem(SCHOOL, set(1, { requirements: reqs(1).map((r) => ({ ...r, threshold: 0 })) }))?.key).toBe(
      'mdReqRising',
    );
    // Level 3 is held: three levels are the least.
    expect(draftProblem(SCHOOL, { ...d, levels: d.levels.slice(0, 2) })).toEqual({ key: 'mdHeld', vars: { n: 3 } });
    expect(draftProblem(SCHOOL, { ...d, levels: d.levels.slice(0, 3) })).toBeNull();

    const lower = set(1, {
      requirements: reqs(1).map((r) => (r.metric === 'CREATOR_FOLLOWERS' ? { ...r, threshold: 1_500 } : r)),
    });
    const body = levelsBody(lower);
    expect(body[0]).toEqual({
      threshold: 1,
      nameAr: null,
      nameEn: null,
      iconUrl: null,
      iconAsset: 'medal_content_school_l1',
      requirements: [
        { metric: 'CREATOR_FOLLOWERS', threshold: 1_500 },
        { metric: 'CREATOR_LIKES', threshold: 10_000 },
        { metric: 'CREATOR_VIEWS', threshold: 20_000 },
      ],
    });
    expect(body.map((l) => l.threshold)).toEqual([1, 2, 3, 4]);
    const changed = render(
      'en',
      capsOf('OWNER'),
      <MedalLevelsForm medal={SCHOOL} draft={lower} onChange={noop} onSave={noop} />,
    );
    expect(changed).toContain('Save levels');
    expect(changed).not.toMatch(/<button[^>]*disabled=""[^>]*data-medal-save/);
  });

  it('a single-metric medal is unchanged: one threshold column, no requirements in its body', () => {
    const wealth: AdminMedal = {
      ...SCHOOL,
      code: 'WEALTH_KINGS',
      metric: 'GIFTS_SENT_COINS',
      levels: [50_000_000, 150_000_000].map((threshold, i) => ({
        level: i + 1,
        threshold,
        nameAr: null,
        nameEn: null,
        iconUrl: null,
        iconAsset: null,
        holders: 0,
        requirements: [],
      })),
    };
    const html = render(
      'en',
      capsOf('OWNER'),
      <MedalLevelsForm medal={wealth} draft={draftOf(wealth)} onChange={noop} onSave={noop} />,
    );
    expect(html).toContain('>Threshold<');
    expect(html).not.toContain('data-requirement');
    expect(levelsBody(draftOf(wealth))[0]).not.toHaveProperty('requirements');
  });
});
