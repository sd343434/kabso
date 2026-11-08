/**
 * D301 follow-up «التكاليف الثابتة» in the panel (owner: «تكاليف ثابتة … يتم تقسيمها على الشهر», §10.112.10): the strings,
 * the menu entry for the OWNER only, the table (active / ended / not started), the form's validation and the delete
 * confirmation (rendered from fixtures shaped like openapi v1.95-social `OwnerFixedCost`).
 */
import { renderToStaticMarkup } from 'react-dom/server';
import { describe, expect, it } from 'vitest';
import { AppContext, type AppState } from '../src/context';
import { translate, type Lang } from '../src/i18n';
import { visibleNav } from '../src/nav';
import { matchPath } from '../src/router';
import { draftBody, FixedCostForm, FixedCostsTable, type FixedCost } from '../src/pages/OwnerFixedCosts';
import type { Capability, PanelRole } from '../src/types';
import { CAPABILITY_ROLES } from './capabilities';

const capsOf = (role: PanelRole) =>
  (Object.keys(CAPABILITY_ROLES) as Capability[]).filter((c) => CAPABILITY_ROLES[c]!.includes(role));
const state = (lang: Lang, role: PanelRole = 'OWNER'): AppState => ({
  lang,
  t: (key, vars) => translate(lang, key, vars),
  session: {
    admin: {
      id: 'self',
      email: 'o@kabso.test',
      username: 'o',
      displayName: 'O',
    },
    roles: [role],
    capabilities: capsOf(role),
    csrfToken: 'csrf',
    expiresAt: '2026-11-07T20:00:00.000Z',
    idleSeconds: 1800,
  },
  can: (cap) => capsOf(role).includes(cap),
  toast: () => undefined,
});
const html = (lang: Lang, node: React.ReactNode) =>
  renderToStaticMarkup(<AppContext.Provider value={state(lang)}>{node}</AppContext.Provider>);

const cost = (
  id: string,
  name: string,
  monthlyMinor: number,
  activeFrom: string,
  activeTo: string | null,
): FixedCost => ({
  id,
  name,
  monthlyMinor,
  currency: 'USD',
  activeFrom,
  activeTo,
  createdAt: '2026-11-07T09:00:00.000Z',
  updatedAt: '2026-11-07T09:00:00.000Z',
});
const rows = [
  cost('c1', 'Servers', 30_000, '2026-01-01', null),
  cost('c2', 'DeepAR filters', 30_000, '2026-03-01', '2026-10-31'),
  cost('c3', 'Claude', 6_000, '2026-12-01', null),
];

describe('D301 «التكاليف الثابتة»', () => {
  it('is in the menu for the OWNER only', () => {
    const has = (role: PanelRole) =>
      visibleNav((cap) => capsOf(role).includes(cap)).some((g) =>
        g.items.some((i) => i.to === '/owner-fixed-costs'),
      );
    expect(has('OWNER')).toBe(true);
    for (const role of ['MODERATION', 'SUPPORT', 'FINANCE', 'BD'] as PanelRole[])
      expect(has(role)).toBe(false);
    expect(matchPath('/owner-fixed-costs')?.name).toBe('ownerFixedCosts');
    expect(translate('ar', 'navOwnerFixedCosts')).toBe('التكاليف الثابتة');
    expect(translate('en', 'fcDeleteBody', { name: 'Claude' })).toContain('Claude');
  });

  for (const lang of ['ar', 'en'] as Lang[]) {
    it(`${lang}: the table — the monthly amount, the daily share, active / ended / not started`, () => {
      const out = html(
        lang,
        <FixedCostsTable
          rows={rows}
          today="2026-11-07"
          onEdit={() => undefined}
          onDelete={() => undefined}
        />,
      );
      expect(out).toContain('data-cost="c1" data-active="yes"');
      expect(out).toContain('data-cost="c2" data-active="no"');
      expect(out).toContain(translate(lang, 'fcEnded'));
      expect(out).toContain(translate(lang, 'fcLater'));
      expect(out).toContain(translate(lang, 'fcOngoing'));
      expect(out).toContain('300');
      expect(out).toContain('10');
      expect(out).toContain('data-edit');
      expect(out).toContain('data-delete');
    });
  }

  it('the form: a name, a positive amount, the end not before the start', () => {
    const base = { name: 'LiveKit', amount: '450', activeFrom: '2026-11-01', activeTo: '' };
    expect(draftBody(base)).toEqual({
      name: 'LiveKit',
      monthlyMinor: 45_000,
      activeFrom: '2026-11-01',
      activeTo: null,
    });
    expect(draftBody({ ...base, amount: '12,5' })?.monthlyMinor).toBe(1_250);
    expect(draftBody({ ...base, name: '  ' })).toBeNull();
    expect(draftBody({ ...base, amount: '0' })).toBeNull();
    expect(draftBody({ ...base, activeTo: '2026-10-31' })).toBeNull();
    expect(draftBody({ ...base, activeTo: '2026-11-30' })?.activeTo).toBe('2026-11-30');
    const off = html(
      'ar',
      <FixedCostForm
        draft={{ ...base, name: '' }}
        editing={false}
        onChange={() => undefined}
        onSave={() => undefined}
        onCancel={() => undefined}
      />,
    );
    expect(off).toMatch(/<button[^>]*data-save[^>]*disabled=""/);
    const on = html(
      'en',
      <FixedCostForm
        draft={base}
        editing
        onChange={() => undefined}
        onSave={() => undefined}
        onCancel={() => undefined}
      />,
    );
    expect(on).not.toMatch(/<button[^>]*data-save[^>]*disabled=""/);
    expect(on).toContain(translate('en', 'fcEditTitle'));
  });
});
