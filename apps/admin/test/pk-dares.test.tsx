/**
 * D229 «أحكام PK»: the panel's dare library page rendered to HTML in Node — the counts, the level badges, the import
 * result with its refused lines, the settings form read-only for SUPPORT and editable for MODERATION, only the
 * changed fields sent, and both languages (every key in Arabic and English).
 */
import { renderToStaticMarkup } from 'react-dom/server';
import { describe, expect, it } from 'vitest';
import { AppContext, type AppState } from '../src/context';
import { translate, type Lang } from '../src/i18n';
import { AR_D229, EN_D229 } from '../src/i18n-d229';
import { DareDialog, ImportResult, LevelBadge, PkDareSettingsForm, PkDareStatsRow, pkDareSettingsChanges } from '../src/pages/PkDares';
import type { AdminPkDareSettings, Capability } from '../src/types';
import { CAPABILITY_ROLES } from './capabilities';

const state = (lang: Lang, caps: Capability[]): AppState => ({
  lang,
  t: (key, vars) => translate(lang, key, vars),
  session: null,
  can: (c) => caps.includes(c),
  toast: () => undefined,
});
const capsOf = (role: 'OWNER' | 'SUPPORT' | 'FINANCE' | 'MODERATION') =>
  (Object.keys(CAPABILITY_ROLES) as Capability[]).filter((c) => CAPABILITY_ROLES[c]!.includes(role));
const render = (node: React.ReactNode, lang: Lang, caps: Capability[]) =>
  renderToStaticMarkup(<AppContext.Provider value={state(lang, caps)}>{node}</AppContext.Provider>);

const SAVED: AdminPkDareSettings = {
  winPoints: 3,
  drawPoints: 1,
  lossPoints: 0,
  refusePoints: -3,
  forfeitPoints: -3,
  decideSeconds: 30,
  reportsToDisable: 5,
  updatedAt: '2026-11-01T09:00:00.000Z',
  updatedById: null,
};

describe('D229 «أحكام PK»', () => {
  it('every string exists in both languages', () => {
    expect(Object.keys(EN_D229).sort()).toEqual(Object.keys(AR_D229).sort());
    for (const v of Object.values(EN_D229)) expect(v.trim().length).toBeGreaterThan(0);
  });

  it('capabilities (D274): OWNER only; moderation, support and finance see nothing', () => {
    // v1.139-social (D387, §10.176.1): + LIVE_OPS «مدير عمليات البث»; never moderation, support or finance.
    expect(CAPABILITY_ROLES['pk_dares.view']).toEqual(['OWNER', 'LIVE_OPS']);
    expect(CAPABILITY_ROLES['pk_dares.edit']).toEqual(['OWNER', 'LIVE_OPS']);
    for (const role of ['MODERATION', 'SUPPORT', 'FINANCE'] as const) {
      expect(capsOf(role)).not.toContain('pk_dares.view');
    }
  });

  it('the counts and the level badges (ar / en)', () => {
    const stats = { total: 20000, active: 19990, disabled: 10, reported: 3, byLevel: { EASY: 6600, MEDIUM: 6600, HARD: 6790 }, byCategory: {} };
    const ar = render(<PkDareStatsRow stats={stats} />, 'ar', capsOf('SUPPORT'));
    expect(ar).toContain('الإجمالي');
    expect(ar).toContain('صعب');
    const en = render(<PkDareStatsRow stats={stats} />, 'en', capsOf('SUPPORT'));
    expect(en).toContain('20,000');
    expect(render(<LevelBadge level="HARD" />, 'en', [])).toContain('badge bad');
    expect(render(<LevelBadge level="EASY" />, 'ar', [])).toContain('سهل');
  });

  it('the import result lists the refused lines with their rules', () => {
    const html = render(
      <ImportResult result={{ received: 3, inserted: 1, existing: 0, rejected: [{ line: 2, code: 't-2', issues: ['ingest'] }] }} />,
      'ar',
      capsOf('MODERATION'),
    );
    expect(html).toContain('أُضيف 1');
    expect(html).toContain('data-rejected-line="2"');
    expect(html).toContain('ingest');
  });

  it('settings: read-only without the edit capability, a save button for the OWNER (D274); only changes are sent', () => {
    const support = render(<PkDareSettingsForm saved={SAVED} draft={SAVED} onChange={() => undefined} onSave={() => undefined} />, 'ar', capsOf('SUPPORT'));
    expect(support).toContain('readOnly');
    expect(support).not.toContain('data-pk-dare-settings-save');
    const mod = render(<PkDareSettingsForm saved={SAVED} draft={{ ...SAVED, refusePoints: -5 }} onChange={() => undefined} onSave={() => undefined} />, 'en', capsOf('OWNER'));
    expect(mod).toContain('data-pk-dare-settings-save');
    expect(pkDareSettingsChanges(SAVED, { ...SAVED, refusePoints: -5 })).toEqual({ refusePoints: -5 });
    expect(pkDareSettingsChanges(SAVED, SAVED)).toEqual({});
  });

  it('the add dialog shows the rules and the 90-character counter (both directions)', () => {
    const html = render(<DareDialog dare={null} onClose={() => undefined} onDone={() => undefined} />, 'ar', capsOf('OWNER'));
    expect(html).toContain('dir="rtl"');
    expect(html).toContain('dir="ltr"');
    expect(html).toContain('0 / 90');
    expect(html).toContain('قواعد السلامة');
  });
});
