/**
 * D387 (v1.139-social, CONVENTIONS §10.176): the operations roles in the panel, rendered to HTML in Node — the roles
 * guide on «الموظفون والصلاحيات», each role's navigation and home (no money figure), the OWNER-only revenue, the shift
 * schedule with «في المناوبة الآن», the compensation limits and history, the official accounts (https only), and both
 * languages.
 */
import { renderToStaticMarkup } from 'react-dom/server';
import { describe, expect, it } from 'vitest';
import { AppContext, type AppState } from '../src/context';
import { translate, type Lang } from '../src/i18n';
import { AR_D387, EN_D387 } from '../src/i18n-d387';
import { NAV, visibleNav } from '../src/nav';
import { matchPath } from '../src/router';
import { compensationBody, CompensationTable, LimitsCard } from '../src/pages/Compensations';
import { Dashboard } from '../src/pages/Dashboard';
import { ShiftStrip } from '../src/pages/Reports';
import {
  CommunityHomeView,
  homesOf,
  LiveOpsHomeView,
  TalentHomeView,
  TrustSafetyHomeView,
  VipCareHomeView,
} from '../src/pages/RoleHomes';
import { isHttpsUrl, moved, SocialAccountList } from '../src/pages/SocialAccounts';
import { parseClock, ScheduleGrid, slotsOf } from '../src/pages/StaffSchedule';
import { mayDecideWithdrawal, StaffRequestBadge } from '../src/pages/Withdrawals';
import { ROLES, RolesGuide } from '../src/pages/Team';
import type {
  Capability,
  Compensation,
  PanelRole,
  ShiftNow,
  ShiftPerson,
  SocialAccount,
  StaffSchedule,
  VipCareHome,
} from '../src/types';
import { CAPABILITY_ROLES } from './capabilities';

const state = (lang: Lang, caps: Capability[], roles: PanelRole[] = []): AppState => ({
  lang,
  t: (key, vars) => translate(lang, key, vars),
  session: roles.length
    ? {
        admin: { id: 'a', email: 'a@kabso.test', username: 'amal', displayName: 'Amal' },
        roles,
        capabilities: caps,
        csrfToken: 'x',
        expiresAt: '2027-03-18T10:00:00.000Z',
        idleSeconds: 600,
      }
    : null,
  can: (c) => caps.includes(c),
  toast: () => undefined,
});
const capsOf = (role: PanelRole) =>
  (Object.keys(CAPABILITY_ROLES) as Capability[]).filter((c) => CAPABILITY_ROLES[c]!.includes(role));
const render = (node: React.ReactNode, lang: Lang, caps: Capability[], roles: PanelRole[] = []) =>
  renderToStaticMarkup(<AppContext.Provider value={state(lang, caps, roles)}>{node}</AppContext.Provider>);
const navOf = (role: PanelRole) =>
  visibleNav((c) => capsOf(role).includes(c)).flatMap((g) => g.items.map((i) => i.to));

/** Words that would mean a money figure on a role home. */
const MONEY = /coins|revenue|usd|\$|cherr|commission|profit|عملة|عملات|إيراد|أرباح|ربح|كرز|عمولة/i;

const person = (id: string, name: string, roles: PanelRole[]): ShiftPerson => ({
  userId: id,
  staffId: `Kabso0${id}`,
  username: name.toLowerCase(),
  displayName: name,
  avatarUrl: null,
  roles,
});
const SHIFT: ShiftNow = {
  timeZone: 'Asia/Baghdad',
  onShiftNow: [person('1', 'Sara', ['MODERATION'])],
  next: [
    {
      person: person('2', 'Omar', ['SUPPORT']),
      startsAt: '2027-03-18T13:00:00.000Z',
      weekday: 4,
      startMinute: 960,
      endMinute: 1440,
    },
  ],
};
const ref = (id: string, name: string) => ({ id, username: name.toLowerCase(), displayName: name, avatarUrl: null });

describe('D387 strings', () => {
  it('every key exists in Arabic and English, and the roles have both names', () => {
    expect(Object.keys(EN_D387).sort()).toEqual(Object.keys(AR_D387).sort());
    for (const [k, v] of Object.entries(AR_D387)) {
      expect(v.trim(), k).not.toBe('');
      expect(EN_D387[k as keyof typeof AR_D387].trim(), k).not.toBe('');
    }
    expect(translate('ar', 'roleMODERATION')).toBe('مراقبة المحتوى والأمان');
    expect(translate('en', 'roleMODERATION')).toBe('Trust & safety');
    expect(translate('ar', 'roleLIVE_OPS')).toBe('مدير عمليات البث');
    expect(translate('ar', 'roleTALENT')).toBe('مدير الوكالات والمواهب');
    expect(translate('ar', 'roleVIP_CARE')).toBe('دعم كبار الداعمين');
    expect(translate('ar', 'roleCOMMUNITY')).toBe('المجتمع والفعاليات');
  });
});

describe('D387 roles and capabilities in the panel', () => {
  it('revenue is the OWNER’s alone; the operations roles hold their own capabilities', () => {
    expect(CAPABILITY_ROLES['revenue.view']).toEqual(['OWNER']);
    for (const role of ROLES.filter((r) => r !== 'OWNER')) expect(capsOf(role)).not.toContain('revenue.view');
    expect(capsOf('VIP_CARE')).toEqual(expect.arrayContaining(['home.vip_care', 'compensation.grant', 'staff.schedule.view']));
    expect(capsOf('VIP_CARE')).not.toContain('compensation.approve');
    expect(capsOf('COMMUNITY')).toEqual(expect.arrayContaining(['social.accounts', 'banners.manage', 'gifts.manage', 'site.public']));
    expect(capsOf('LIVE_OPS')).toEqual(expect.arrayContaining(['events.manage', 'pk_dares.edit', 'host_targets.edit', 'boosts.manage', 'gifts.manage']));
    expect(capsOf('LIVE_OPS')).not.toContain('users.balance_adjust');
    expect(capsOf('TALENT')).toEqual(expect.arrayContaining(['hosts.applications.decide', 'creators.decide', 'recruits.mine', 'host_targets.edit']));
    // MODERATION (TRUST_SAFETY) keeps its moderation and gains its home and the schedule.
    expect(capsOf('MODERATION')).toEqual(expect.arrayContaining(['reports.act', 'users.ban', 'lives.moderate', 'home.trust_safety', 'staff.schedule.view']));
  });

  it('each role’s navigation: the schedule, compensations and accounts where they belong; no money report but the OWNER’s', () => {
    expect(navOf('OWNER')).toEqual(expect.arrayContaining(['/staff-schedule', '/compensations', '/social-accounts', '/finance/report']));
    expect(navOf('FINANCE')).not.toContain('/finance/report');
    expect(navOf('FINANCE')).toContain('/withdrawals');
    expect(navOf('VIP_CARE')).toEqual(expect.arrayContaining(['/staff-schedule', '/compensations', '/level-raises', '/whatsapp']));
    expect(navOf('VIP_CARE')).not.toContain('/social-accounts');
    expect(navOf('COMMUNITY')).toEqual(expect.arrayContaining(['/social-accounts', '/site-settings', '/events', '/gifts']));
    expect(navOf('COMMUNITY')).not.toContain('/staff-schedule');
    expect(navOf('LIVE_OPS')).toEqual(expect.arrayContaining(['/pk-dares', '/live-boost-prices', '/programs/host-targets', '/lives']));
    expect(navOf('TALENT')).toEqual(expect.arrayContaining(['/host-applications', '/creator-applications', '/my-recruits', '/agencies']));
    expect(navOf('SUPPORT')).toContain('/staff-schedule');
    for (const role of ROLES.filter((r) => r !== 'OWNER')) expect(navOf(role), role).not.toContain('/finance/report');
    expect(NAV.flatMap((g) => g.items).find((i) => i.to === '/finance/report')?.cap).toBe('revenue.view');
    expect(matchPath('/staff-schedule')?.name).toBe('staffSchedule');
    expect(matchPath('/compensations')?.name).toBe('compensations');
    expect(matchPath('/social-accounts')?.name).toBe('socialAccounts');
  });

  it('each role lands on its own home; several roles see several homes; the OWNER sees the KPI dashboard', () => {
    const homes = (role: PanelRole) => homesOf((c) => capsOf(role).includes(c)).map((h) => h.cap);
    expect(homes('MODERATION')).toEqual(['home.trust_safety']);
    expect(homes('VIP_CARE')).toEqual(['home.vip_care']);
    expect(homes('LIVE_OPS')).toEqual(['home.live_ops']);
    expect(homes('TALENT')).toEqual(['home.talent']);
    expect(homes('COMMUNITY')).toEqual(['home.community']);
    expect(homes('FINANCE')).toEqual([]);
    const both = [...new Set([...capsOf('MODERATION'), ...capsOf('VIP_CARE')])];
    expect(homesOf((c) => both.includes(c)).map((h) => h.cap)).toEqual(['home.trust_safety', 'home.vip_care']);

    const vip = render(<Dashboard />, 'ar', capsOf('VIP_CARE'), ['VIP_CARE']);
    expect(vip).toContain('class="role-home"');
    expect(vip).toContain(translate('ar', 'homeVipCare'));
    expect(vip).not.toContain(translate('ar', 'kpiCoinsSold'));
    expect(vip).not.toContain(translate('ar', 'chartTitle'));
    const fin = render(<Dashboard />, 'en', capsOf('FINANCE'), ['FINANCE']);
    expect(fin).not.toContain(translate('en', 'kpiCoinsSold'));
    expect(fin).toContain(translate('en', 'attnTitle'));
    const owner = render(<Dashboard />, 'en', capsOf('OWNER'), ['OWNER']);
    expect(owner).toContain(translate('en', 'chartTitle'));
    expect(owner).not.toContain('class="role-home"');
  });

  it('«الموظفون والصلاحيات» lists every role with its Arabic and English names and what it can do', () => {
    for (const lang of ['ar', 'en'] as const) {
      const html = render(<RolesGuide />, lang, capsOf('OWNER'), ['OWNER']);
      for (const r of ROLES) {
        expect(html).toContain(`data-role="${r}"`);
        expect(html).toContain(translate('ar', `role${r}`).replace('&', '&amp;'));
        expect(html).toContain(translate('en', `role${r}`).replace('&', '&amp;'));
      }
      expect(html).toContain('TRUST_SAFETY');
      expect(html).toContain(translate(lang, 'opsRolesRevenue'));
    }
  });
});

describe('D387 role homes: no money figure', () => {
  it('renders each home in both languages without any amount', () => {
    const views = [
      <TrustSafetyHomeView key="ts" data={{ openReports: 4, avgResolveMinutes: 18, resolved7d: 31, livesNow: 12, shift: SHIFT }} />,
      <LiveOpsHomeView
        key="lo"
        data={{
          livesNow: 12,
          topLives: [{ roomId: 'r1', title: 'Evening show', host: ref('h1', 'Lina'), viewers: 340, startedAt: '2027-03-18T08:00:00.000Z' }],
          topHosts: [{ host: ref('h1', 'Lina'), liveMinutes7d: 1260, liveNow: true }],
          pk: { battlesNow: 3, battlesToday: 41 },
          events: [{ id: 'e1', titleAr: 'موسم الربيع', titleEn: 'Spring season', startsAt: null, endsAt: null, running: true }],
        }}
      />,
      <TalentHomeView
        key="ta"
        data={{
          newHosts7d: 9,
          liveHours7d: 412.5,
          inactiveAgencies: [{ id: 'a1', name: 'Star', inviteCode: 'host01', owner: ref('o1', 'Noor'), activeHosts: 3, lastLiveAt: null }],
          queue: { hostApplications: 5, creatorApplications: 2 },
        }}
      />,
      <CommunityHomeView
        key="co"
        data={{
          upcomingEvents: [{ id: 'e2', titleAr: 'رمضان', titleEn: 'Ramadan', startsAt: '2027-03-20T00:00:00.000Z', endsAt: null, running: false }],
          participation: [{ eventId: 'e1', titleAr: 'موسم الربيع', titleEn: 'Spring season', entrants: 120 }],
          bannersLive: [{ id: 'b1', titleAr: 'بانر', titleEn: 'Banner', placement: 'HOME', endsAt: null }],
        }}
      />,
    ];
    for (const lang of ['ar', 'en'] as const) {
      for (const v of views) {
        const html = render(v, lang, capsOf('OWNER'));
        expect(html.replace(/<[^>]+>/g, ' ')).not.toMatch(MONEY);
      }
    }
    const ts = render(views[0], 'ar', capsOf('MODERATION'));
    expect(ts).toContain('data-on-shift-badge');
    expect(ts).toContain('في المناوبة الآن');
    expect(ts).toContain('Sara');
    expect(ts).toContain('Omar');
  });

  it('VIP care: levels and tiers of the top supporters, never an amount', () => {
    const data: VipCareHome = {
      topSupporters: [
        { user: ref('u1', 'Hadi'), level: 38, vipTier: { code: 'VIP_5', nameAr: 'في آي بي 5', nameEn: 'VIP 5', color: '#C9A227' }, lastActiveAt: '2027-03-18T08:00:00.000Z' },
      ],
      stoppedActive: [{ user: ref('u2', 'Rami'), level: 22, vipTier: null, lastActiveAt: '2027-03-05T08:00:00.000Z' }],
      inactiveDays: 7,
      pendingCompensations: 2,
      shift: SHIFT,
    };
    for (const lang of ['ar', 'en'] as const) {
      const html = render(<VipCareHomeView data={data} />, lang, capsOf('VIP_CARE'));
      expect(html).toContain(translate(lang, 'homeLevel', { n: 38 }));
      expect(html).toContain(lang === 'ar' ? 'في آي بي 5' : 'VIP 5');
      expect(html).toContain('Rami');
      expect(html.replace(/<[^>]+>/g, ' ')).not.toMatch(MONEY);
    }
  });
});

describe('D387 the shift schedule', () => {
  const schedule: StaffSchedule = {
    timeZone: 'Asia/Baghdad',
    now: { weekday: 4, minute: 720 },
    slots: [
      { id: 's1', person: person('1', 'Sara', ['MODERATION']), weekday: 4, startMinute: 480, endMinute: 960, onShiftNow: true },
      { id: 's2', person: person('2', 'Omar', ['SUPPORT']), weekday: 4, startMinute: 960, endMinute: 1440, onShiftNow: false },
      { id: 's3', person: person('3', 'Huda', ['VIP_CARE']), weekday: 5, startMinute: 0, endMinute: 480, onShiftNow: false },
    ],
    shift: SHIFT,
    me: { onShiftNow: true },
  };
  it('the week grid marks who is on shift now; the filter keeps them only', () => {
    expect(slotsOf(schedule, 4, false).map((s) => s.id)).toEqual(['s1', 's2']);
    expect(slotsOf(schedule, 4, true).map((s) => s.id)).toEqual(['s1']);
    for (const lang of ['ar', 'en'] as const) {
      const html = render(<ScheduleGrid schedule={schedule} onlyNow={false} />, lang, capsOf('SUPPORT'));
      expect(html).toContain(translate(lang, 'weekday4'));
      expect(html).toContain('08:00–16:00');
      expect(html).toContain('16:00–24:00');
      expect(html).toContain('data-on-shift="true"');
      expect(html).toContain(translate(lang, 'shiftOnNow'));
      expect(html).not.toContain(translate(lang, 'schedEdit'));
    }
    const owner = render(<ScheduleGrid schedule={schedule} onlyNow onEdit={() => undefined} />, 'en', capsOf('OWNER'));
    expect(owner).toContain('Sara');
    expect(owner).not.toContain('Omar');
    expect(owner).toContain(translate('en', 'schedEdit'));
  });
  it('reads clock times; the reports page shows the viewer’s badge', () => {
    expect(parseClock('08:00')).toBe(480);
    expect(parseClock('24:00')).toBe(1440);
    expect(parseClock('24:30')).toBeNull();
    expect(parseClock('7')).toBeNull();
    const strip = render(<ShiftStrip schedule={schedule} />, 'ar', capsOf('MODERATION'));
    expect(strip).toContain('data-on-shift-badge');
    expect(strip).toContain('Sara');
    const off = render(<ShiftStrip schedule={{ ...schedule, me: { onShiftNow: false } }} />, 'ar', capsOf('SUPPORT'));
    expect(off).not.toContain('data-on-shift-badge');
  });
});

describe('D387 compensations', () => {
  const row = (over: Partial<Compensation>): Compensation => ({
    id: 'c1',
    staff: ref('s1', 'Huda'),
    user: ref('u1', 'Hadi'),
    kind: 'COINS',
    coins: 9000,
    days: null,
    tierCode: null,
    itemCode: null,
    valueCoins: 9000,
    reason: 'stream dropped',
    status: 'PENDING',
    overLimit: 'per_grant',
    decidedBy: null,
    decidedAt: null,
    decisionNote: null,
    createdAt: '2027-03-18T09:00:00.000Z',
    ...over,
  });
  it('the limits card and the history; only the OWNER decides a pending one', () => {
    const limits = { dailyLimitCoins: 50000, perGrantMaxCoins: 10000, usedTodayCoins: 12000, timeZone: 'Asia/Riyadh', updatedAt: null };
    const ar = render(<LimitsCard settings={limits} onEdit={() => undefined} />, 'ar', capsOf('OWNER'));
    expect(ar).toContain('50,000');
    expect(ar).toContain(translate('ar', 'compEditLimits'));
    const vip = render(<LimitsCard settings={limits} />, 'en', capsOf('VIP_CARE'));
    expect(vip).not.toContain(translate('en', 'compEditLimits'));
    const rows = [row({}), row({ id: 'c2', status: 'GRANTED', overLimit: null, coins: 500, valueCoins: 500 })];
    const owner = render(<CompensationTable rows={rows} onDecide={() => undefined} />, 'en', capsOf('OWNER'));
    expect(owner.match(/>Approve</g)).toHaveLength(1);
    expect(owner).toContain(translate('en', 'compOverper_grant'));
    const staff = render(<CompensationTable rows={rows} />, 'ar', capsOf('VIP_CARE'));
    expect(staff).not.toContain(translate('ar', 'compApprove'));
    expect(staff).toContain(translate('ar', 'compStatusPENDING'));
  });
  it('the grant form asks for the kind’s own fields, a reason and the code', () => {
    const base = { user: 'hadi', kind: 'COINS' as const, coins: '500', days: '', tierCode: '', itemCode: '', reason: 'stream dropped', totpCode: '123456' };
    expect(compensationBody(base)).toEqual({ user: 'hadi', kind: 'COINS', coins: 500, reason: 'stream dropped', totpCode: '123456' });
    expect(compensationBody({ ...base, totpCode: '12' })).toBeNull();
    expect(compensationBody({ ...base, reason: 'x' })).toBeNull();
    expect(compensationBody({ ...base, coins: '0' })).toBeNull();
    expect(compensationBody({ ...base, kind: 'VIP_DAYS', days: '3', tierCode: 'VIP_1' })).toMatchObject({ days: 3, tierCode: 'VIP_1' });
    expect(compensationBody({ ...base, kind: 'ITEM', days: '5', itemCode: 'frame' })).toBeNull();
    expect(compensationBody({ ...base, kind: 'ITEM', days: '7', itemCode: 'frame' })).toMatchObject({ days: 7, itemCode: 'frame' });
  });
});

describe('D387 the official accounts', () => {
  it('https links only; the order moves; the list shows platform, handle and link', () => {
    expect(isHttpsUrl('https://instagram.com/kabso')).toBe(true);
    expect(isHttpsUrl('http://instagram.com/kabso')).toBe(false);
    expect(isHttpsUrl('javascript:alert(1)')).toBe(false);
    expect(isHttpsUrl('https://user:pw@x.com')).toBe(false);
    expect(isHttpsUrl('https://x .com')).toBe(false);
    expect(moved(['a', 'b', 'c'], 'b', -1)).toEqual(['b', 'a', 'c']);
    expect(moved(['a', 'b', 'c'], 'c', 1)).toEqual(['a', 'b', 'c']);
    const accounts: SocialAccount[] = [
      { id: 'a', platform: 'INSTAGRAM', handle: '@kabso.live', url: 'https://instagram.com/kabso.live', sortOrder: 0, updatedAt: '2027-03-18T09:00:00.000Z' },
      { id: 'b', platform: 'TIKTOK', handle: '@kabso', url: 'https://www.tiktok.com/@kabso', sortOrder: 1, updatedAt: '2027-03-18T09:00:00.000Z' },
    ];
    for (const lang of ['ar', 'en'] as const) {
      const html = render(<SocialAccountList accounts={accounts} onEdit={() => undefined} onMove={() => undefined} />, lang, capsOf('COMMUNITY'));
      expect(html).toContain(translate(lang, 'platformINSTAGRAM'));
      expect(html).toContain('@kabso.live');
      expect(html).toContain('href="https://www.tiktok.com/@kabso"');
      expect(html).toContain('rel="noopener noreferrer"');
      expect(html).not.toMatch(/password|token/i);
    }
  });
});

describe('D387 staff money rules in the panel (§10.176.9)', () => {
  it('a staff member’s withdrawal request is marked and decided by the OWNER alone', () => {
    expect(CAPABILITY_ROLES['withdrawals.staff']).toEqual(['OWNER']);
    const can = (role: PanelRole) => (c: Capability) => capsOf(role).includes(c);
    expect(mayDecideWithdrawal({ staffRequest: true }, can('OWNER'))).toBe(true);
    expect(mayDecideWithdrawal({ staffRequest: true }, can('FINANCE'))).toBe(false);
    expect(mayDecideWithdrawal({ staffRequest: false }, can('FINANCE'))).toBe(true);
    expect(mayDecideWithdrawal({}, can('FINANCE'))).toBe(true);
    expect(mayDecideWithdrawal({ staffRequest: false }, can('VIP_CARE'))).toBe(false);
    for (const lang of ['ar', 'en'] as const) {
      const html = render(<StaffRequestBadge w={{ staffRequest: true }} />, lang, capsOf('OWNER'));
      expect(html).toContain('data-staff-request');
      expect(html).toContain(translate(lang, 'wdStaffRequest'));
      expect(render(<StaffRequestBadge w={{ staffRequest: false }} />, lang, capsOf('OWNER'))).toBe('');
    }
  });
});
