/**
 * D293 automatic verification badges «شارة التوثيق» in the panel: the strings in both languages, the menu by role
 * (the team reads «شارات التوثيق», only the OWNER edits), the page from a fixture (the six badges in the owner's order
 * with their holders, the thresholds «more than», read-only for the team), the threshold changes, and the badge chip
 * of the user page.
 */
import { renderToStaticMarkup } from 'react-dom/server';
import { describe, expect, it } from 'vitest';
import { AppContext, type AppState } from '../src/context';
import { DICTIONARIES, translate, type Lang } from '../src/i18n';
import { AR_D293, EN_D293 } from '../src/i18n-d293';
import { visibleNav } from '../src/nav';
import { matchPath } from '../src/router';
import {
  SettingsBody,
  thresholdChanges,
  VerificationChip,
  type VerificationSettingsView,
} from '../src/pages/VerificationBadges';
import { VERIFICATION_BADGES, type Capability, type PanelRole } from '../src/types';
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
    expiresAt: '2026-11-06T20:00:00.000Z',
    idleSeconds: 1800,
  },
  can: (cap) => capsOf(role).includes(cap),
  toast: () => undefined,
});
const html = (lang: Lang, node: React.ReactNode, role: PanelRole = 'OWNER') =>
  renderToStaticMarkup(<AppContext.Provider value={state(lang, role)}>{node}</AppContext.Provider>);

const OWNER_VALUES = {
  rechargeMinSalesCoins: 300_000_000,
  rechargeMinCherries: 300_000_000,
  hostAgentMinHosts: 30,
  hostAgentMinCherries: 300_000_000,
};
const view: VerificationSettingsView = {
  settings: OWNER_VALUES,
  defaults: OWNER_VALUES,
  windowDays: 30,
  holders: {
    OWNER: 1,
    STAFF: 7,
    RECHARGE_AGENT: 2,
    HOST_AGENT: 3,
    CREATOR: 12,
    VERIFIED_HOST: 40,
  },
  lastRunAt: '2026-11-06T10:00:00.000Z',
  updatedAt: '2026-11-06T09:00:00.000Z',
};

describe('D293 strings', () => {
  it('has every string in both languages, merged into the dictionaries', () => {
    expect(Object.keys(EN_D293).sort()).toEqual(Object.keys(AR_D293).sort());
    for (const k of Object.keys(AR_D293) as (keyof typeof AR_D293)[]) {
      expect(DICTIONARIES.ar[k]).toBe(AR_D293[k]);
      expect(DICTIONARIES.en[k]).toBe(EN_D293[k]);
    }
    for (const b of VERIFICATION_BADGES) {
      expect(AR_D293[`vb${b}`]).toBeTruthy();
      expect(AR_D293[`vbRule${b}`]).toBeTruthy();
    }
    expect(AR_D293.vbRECHARGE_AGENT).toBe('وكيل شحن');
  });
});

describe('D293 the menu and the route', () => {
  it('the team sees «شارات التوثيق»; BD does not', () => {
    const has = (role: PanelRole) =>
      visibleNav((c) => capsOf(role).includes(c)).some((g) =>
        g.items.some((i) => i.to === '/verification-badges'),
      );
    for (const role of ['OWNER', 'MODERATION', 'SUPPORT', 'FINANCE'] as const)
      expect(has(role), role).toBe(true);
    expect(has('BD')).toBe(false);
    expect(matchPath('/verification-badges')?.name).toBe('verificationBadges');
  });
});

describe('D293 the page', () => {
  it('lists the six badges in the owner order with their holders; the OWNER edits', () => {
    const ar = html('ar', <SettingsBody view={view} onSaved={() => undefined} />);
    const order = [...ar.matchAll(/data-badge-row="([A-Z_]+)"/g)].map((m) => m[1]);
    expect(order).toEqual([...VERIFICATION_BADGES]);
    expect(ar).toContain('مالك التطبيق');
    expect(ar).toContain('مضيف موثّق');
    expect(ar).toContain('أكثر من');
    expect(ar).toContain('آخر 30 يوماً');
    expect(ar).toContain('حفظ وإعادة الحساب');
    expect(ar).not.toContain('للعرض فقط');
    expect(ar).toContain('value="300000000"');
    const en = html('en', <SettingsBody view={view} onSaved={() => undefined} />);
    expect(en).toContain('Recharge agent (gold): coins sold in the window — More than');
    expect(en).toContain('Default: 30');
  });

  it('is read-only for the team', () => {
    const mod = html('ar', <SettingsBody view={view} onSaved={() => undefined} />, 'MODERATION');
    expect(mod).toContain('للعرض فقط — التعديل للمالك.');
    expect(mod).not.toContain('حفظ وإعادة الحساب');
    expect(mod).toContain('disabled=""');
  });

  it('the changes: only what changed, whole numbers in range', () => {
    const d = (over: Partial<Record<keyof typeof OWNER_VALUES, string>> = {}) => ({
      rechargeMinSalesCoins: '300000000',
      rechargeMinCherries: '300000000',
      hostAgentMinHosts: '30',
      hostAgentMinCherries: '300000000',
      ...over,
    });
    expect(thresholdChanges(OWNER_VALUES, d())).toEqual({});
    expect(thresholdChanges(OWNER_VALUES, d({ hostAgentMinHosts: '31' }))).toEqual({ hostAgentMinHosts: 31 });
    expect(thresholdChanges(OWNER_VALUES, d({ rechargeMinCherries: '1000000000000000' }))).toEqual({
      rechargeMinCherries: 1e15,
    });
    expect(thresholdChanges(OWNER_VALUES, d({ rechargeMinCherries: '1000000000000001' }))).toBeNull();
    expect(thresholdChanges(OWNER_VALUES, d({ hostAgentMinHosts: '100001' }))).toBeNull();
    expect(thresholdChanges(OWNER_VALUES, d({ hostAgentMinHosts: '-1' }))).toBeNull();
    expect(thresholdChanges(OWNER_VALUES, d({ hostAgentMinHosts: '2.5' }))).toBeNull();
    expect(thresholdChanges(OWNER_VALUES, d({ hostAgentMinHosts: '' }))).toBeNull();
  });

  it('the chip names the badge in both languages', () => {
    expect(html('ar', <VerificationChip badge="RECHARGE_AGENT" />)).toContain('شارة التوثيق: وكيل شحن');
    expect(html('en', <VerificationChip badge="OWNER" />)).toContain('Verification badge: App owner');
    expect(html('en', <VerificationChip badge="OWNER" />)).toContain('data-verification="OWNER"');
  });
});
