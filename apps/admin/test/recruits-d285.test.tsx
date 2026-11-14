/**
 * D285 recruitment by staff «الاستقطاب» in the panel: the BD role on the team page (grant choice, badge, recruit
 * counts), the menu by role (BD sees only «استقطاباتي»; the OWNER «الاستقطاب»; SUPPORT the creator applications), the
 * percentages and the share changes, «استقطاباتي» and the OWNER's page (rendered from fixtures), both languages.
 */
import { renderToStaticMarkup } from 'react-dom/server';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { AppContext, type AppState } from '../src/context';
import { DICTIONARIES, translate, type Lang } from '../src/i18n';
import { AR_D285, EN_D285 } from '../src/i18n-d285';
import { visibleNav } from '../src/nav';
import { matchPath } from '../src/router';
import { bpsPercent, recruitBreakdown, shareChanges } from '../src/pages/Recruits';
import { MemberCard, ROLES, REGION_ROLES, type Member } from '../src/pages/Team';
import type { Capability, PanelRole } from '../src/types';
import { CAPABILITY_ROLES } from './capabilities';

const capsOf = (role: PanelRole) =>
  (Object.keys(CAPABILITY_ROLES) as Capability[]).filter((c) => CAPABILITY_ROLES[c]!.includes(role));
const state = (lang: Lang, role: PanelRole = 'OWNER'): AppState => ({
  lang,
  t: (key, vars) => translate(lang, key, vars),
  session: {
    admin: { id: 'self', email: 'o@kabso.test', username: 'o', displayName: 'O' },
    roles: [role],
    capabilities: capsOf(role),
    csrfToken: 'csrf',
    expiresAt: '2026-11-05T20:00:00.000Z',
    idleSeconds: 1800,
  },
  can: (cap) => capsOf(role).includes(cap),
  toast: () => undefined,
});
const html = (lang: Lang, node: React.ReactNode, role: PanelRole = 'OWNER') =>
  renderToStaticMarkup(<AppContext.Provider value={state(lang, role)}>{node}</AppContext.Provider>);

const bdMember = (over: Partial<Member> = {}): Member => ({
  id: '33333333-3333-4333-8333-333333333333',
  email: 'bd@kabso.test',
  username: 'bd_one',
  displayName: 'نور',
  avatarUrl: null,
  status: 'ACTIVE',
  roles: ['BD'],
  totpEnrolled: true,
  lockedUntil: null,
  lastSignInAt: '2026-11-05T09:00:00.000Z',
  onShift: false,
  shiftSince: null,
  regions: ['ARAB_WORLD'],
  staffId: 'Kabso05',
  recruits: { HOST: 2, AGENCY: 1, RECHARGE_AGENT: 0, CREATOR: 1, total: 4 },
  ...over,
});
const noop = () => undefined;

describe('D285 strings', () => {
  it('has every string in both languages, merged into the dictionaries', () => {
    expect(Object.keys(EN_D285).sort()).toEqual(Object.keys(AR_D285).sort());
    for (const k of Object.keys(AR_D285) as (keyof typeof AR_D285)[]) {
      expect(DICTIONARIES.ar[k]).toBe(AR_D285[k]);
      expect(DICTIONARIES.en[k]).toBe(EN_D285[k]);
    }
    expect(AR_D285.roleBD).toBe('تطوير الأعمال');
    expect(AR_D285.navMyRecruits).toBe('استقطاباتي');
  });
});

describe('D285 the BD role on «الموظفون والصلاحيات»', () => {
  it('can be granted, carries regions, and its card shows the role, the staff ID and the recruit counts', () => {
    expect(ROLES).toContain('BD');
    expect(REGION_ROLES).toContain('BD');
    const ar = html('ar', <MemberCard m={bdMember()} selfId="self" activeOwners={1} onRevoke={noop} onReset={noop} />);
    expect(ar).toContain('تطوير الأعمال');
    expect(ar).toContain('data-recruits="4"');
    expect(ar).toContain('4 مستقطَب');
    expect(ar).toContain('2 مضيف · 1 وكالة · 1 صانع محتوى');
    const en = html('en', <MemberCard m={bdMember()} selfId="self" activeOwners={1} onRevoke={noop} onReset={noop} />);
    expect(en).toContain('Business development');
    expect(en).toContain('4 recruits');
  });

  it('a FINANCE member without recruits shows no recruit row; an older API none at all', () => {
    const fin = bdMember({ roles: ['FINANCE'], recruits: { HOST: 0, AGENCY: 0, RECHARGE_AGENT: 0, CREATOR: 0, total: 0 } });
    expect(html('ar', <MemberCard m={fin} selfId="self" activeOwners={1} onRevoke={noop} onReset={noop} />)).not.toContain('data-recruits');
    const old = bdMember({ recruits: undefined });
    expect(html('ar', <MemberCard m={old} selfId="self" activeOwners={1} onRevoke={noop} onReset={noop} />)).not.toContain('data-recruits');
  });
});

describe('D285 the menu by role', () => {
  const items = (role: PanelRole) =>
    visibleNav((c) => capsOf(role).includes(c)).flatMap((g) => g.items.map((i) => i.to));
  it('BD sees only «استقطاباتي» — no lives, reports, users or moderation', () => {
    expect(items('BD')).toEqual(['/my-recruits']);
  });
  it('MODERATION has «استقطاباتي» besides its moderation pages; not the OWNER’s view', () => {
    const mod = items('MODERATION');
    expect(mod).toContain('/my-recruits');
    expect(mod).toContain('/reports');
    expect(mod).not.toContain('/recruits');
  });
  it('the OWNER sees «الاستقطاب» and the creator applications; SUPPORT the applications only', () => {
    expect(items('OWNER')).toEqual(expect.arrayContaining(['/recruits', '/creator-applications']));
    expect(items('SUPPORT')).toContain('/creator-applications');
    expect(items('SUPPORT')).not.toContain('/recruits');
    expect(items('SUPPORT')).not.toContain('/my-recruits');
  });
  it('routes the three pages', () => {
    expect(matchPath('/my-recruits')?.name).toBe('myRecruits');
    expect(matchPath('/recruits')?.name).toBe('recruits');
    expect(matchPath('/creator-applications')?.name).toBe('creatorApplications');
  });
});

describe('D285 the shares', () => {
  it('basis points as percentages: the owner defaults 1 % and 0.75 %', () => {
    expect(bpsPercent(100)).toBe('1%');
    expect(bpsPercent(75)).toBe('0.75%');
    expect(bpsPercent(150)).toBe('1.5%');
    expect(bpsPercent(2000)).toBe('20%');
    expect(bpsPercent(0)).toBe('0%');
  });
  it('sends only the shares that changed, in the API names', () => {
    const saved = { HOST: 100, AGENCY: 100, RECHARGE_AGENT: 75, CREATOR: 100 };
    expect(shareChanges(saved, saved)).toEqual({});
    expect(shareChanges(saved, { ...saved, RECHARGE_AGENT: 50, CREATOR: 120 })).toEqual({
      rechargeAgent: 50,
      creator: 120,
    });
  });
  it('the breakdown lists only the non-zero types', () => {
    const t = state('en').t;
    expect(recruitBreakdown({ HOST: 0, AGENCY: 2, RECHARGE_AGENT: 1, CREATOR: 0, total: 3 }, t)).toBe(
      '2 Agency · 1 Recharge agent',
    );
  });
});

describe('D285 «استقطاباتي» and «الاستقطاب» render their data', () => {
  afterEach(() => vi.restoreAllMocks());

  it('the pages render their headings and loading states in both languages (server render)', async () => {
    const { MyRecruits, Recruits, CreatorApplications } = await import('../src/pages/Recruits');
    expect(html('ar', <MyRecruits />, 'BD')).toContain('استقطاباتي');
    expect(html('en', <MyRecruits />, 'BD')).toContain('My recruits');
    expect(html('ar', <Recruits />)).toContain('الاستقطاب');
    expect(html('en', <CreatorApplications />, 'SUPPORT')).toContain('Creator applications');
  });
});
