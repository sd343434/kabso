/**
 * D390 «برنامج سفراء كابسو» in the panel: the strings in both languages, the menu by role (SUPPORT reads and decides,
 * the settings are the OWNER's, FINANCE sees nothing), the list without money for SUPPORT and with it for the OWNER,
 * an ambassador's page with the OWNER's freeze / review buttons, an application card, a campaign, and the settings
 * form's level rules and the PUT body.
 */
import { renderToStaticMarkup } from 'react-dom/server';
import { describe, expect, it } from 'vitest';
import { AppContext, type AppState } from '../src/context';
import { DICTIONARIES, translate, type Lang } from '../src/i18n';
import { AR_D390, EN_D390 } from '../src/i18n-d390';
import { AmbassadorLevelChip, ambassadorLevelCode, ambassadorLevelIcon } from '../src/ambassador-levels';
import { visibleNav } from '../src/nav';
import { matchPath } from '../src/router';
import {
  AmbassadorSettingsForm,
  AmbassadorTable,
  AmbassadorView,
  ApplicationCard,
  CampaignCard,
  ambassadorSettingsChanges,
  bpsLabel,
  campaignBody,
  levelsValid,
  rewardOf,
  type AmbassadorDetailData,
  type AmbassadorRow,
  type AmbassadorSettings,
} from '../src/pages/Ambassadors';
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
    expiresAt: '2026-11-13T20:00:00.000Z',
    idleSeconds: 1800,
  },
  can: (cap) => capsOf(role).includes(cap),
  toast: () => undefined,
});
const html = (lang: Lang, node: React.ReactNode, role: PanelRole = 'OWNER') =>
  renderToStaticMarkup(<AppContext.Provider value={state(lang, role)}>{node}</AppContext.Provider>);

const row = (over: Partial<AmbassadorRow> = {}): AmbassadorRow => ({
  user: { id: '11111111-1111-4111-8111-111111111111', username: 'sara_eg', displayName: 'سارة', avatarUrl: null },
  status: 'ACTIVE',
  level: 'STAR',
  source: 'APPLICATION',
  country: 'EG',
  activatedAt: '2026-11-02T10:00:00.000Z',
  underReview: false,
  reviewReason: null,
  frozenReason: null,
  endedAt: null,
  endedReason: null,
  referrals: { total: 12, active: 7, pending: 5, void: 1 },
  month: { month: '2026-11', activeReferrals: 4, topupCoins: 3_200_000 },
  commissions: { pendingCherries: 120_000, heldCherries: 0, paidCherries: 960_000, reversedCherries: 30_000 },
  ...over,
});
const detail = (over: Partial<AmbassadorDetailData> = {}): AmbassadorDetailData => ({
  ...row(),
  flags: [{ id: 'f1', kind: 'VELOCITY', createdAt: '2026-11-05T10:00:00.000Z', clearedAt: null }],
  months: [
    {
      month: '2026-10',
      activeReferrals: 6,
      topupCoins: 3_100_000,
      commissionCherries: 930_000,
      levelBefore: 'SPARK',
      levelAfter: 'STAR',
      metLevel: 'STAR',
      rewardStatus: 'GRANTED',
    },
  ],
  referralList: [
    {
      invitee: { id: 'i1', username: 'friend1', displayName: 'Friend' },
      status: 'ACTIVE',
      voidReason: null,
      createdAt: '2026-11-03T10:00:00.000Z',
      activeAt: '2026-11-06T10:00:00.000Z',
    },
  ],
  commissionList: [
    {
      id: 'c1',
      createdAt: '2026-11-04T10:00:00.000Z',
      recharge: 'CARD_TOPUP',
      coins: 1_000_000,
      level: 'STAR',
      rateBps: 500,
      cherries: 500_000,
      status: 'CREDITED',
      voidReason: null,
      holdUntil: '2026-11-18T10:00:00.000Z',
    },
  ],
  campaigns: [],
  ...over,
});
const SETTINGS: AmbassadorSettings = {
  enabled: false,
  attributionWindowDays: 60,
  holdDays: 14,
  minActiveDays: 3,
  minActiveTopupCoins: 100_000,
  monthlyCapCherries: 50_000_000,
  velocityMaxPerDay: 30,
  ipClusterMax: 3,
  ipClusterWindowDays: 30,
  levels: [
    { code: 'SPARK', minActiveReferrals: 0, minTopupCoins: 0, commissionBps: 200, reward: { kind: 'NONE' } },
    { code: 'STAR', minActiveReferrals: 5, minTopupCoins: 3_000_000, commissionBps: 300, reward: { kind: 'COINS', amount: 100_000 } },
    { code: 'CONSTELLATION', minActiveReferrals: 15, minTopupCoins: 15_000_000, commissionBps: 400, reward: { kind: 'VIP_DAYS', amount: 7, vipTier: 'VIP_1' } },
    { code: 'GALAXY', minActiveReferrals: 40, minTopupCoins: 60_000_000, commissionBps: 500, reward: { kind: 'COINS', amount: 1_000_000 } },
  ],
  updatedAt: '2026-11-13T10:00:00.000Z',
};
const noop = () => undefined;

describe('D390 strings and menu', () => {
  it('has every string in both languages, merged into the dictionaries', () => {
    expect(Object.keys(EN_D390).sort()).toEqual(Object.keys(AR_D390).sort());
    for (const k of Object.keys(AR_D390) as (keyof typeof AR_D390)[]) {
      expect(DICTIONARIES.ar[k]).toBe(AR_D390[k]);
      expect(DICTIONARIES.en[k]).toBe(EN_D390[k]);
    }
    expect(AR_D390.navAmbassadors).toBe('السفراء');
  });

  it('the routes and the menu by role: SUPPORT reads and decides, the settings are the OWNER’s, FINANCE has none', () => {
    expect(matchPath('/ambassadors')?.name).toBe('ambassadors');
    expect(matchPath('/ambassadors/abc')).toMatchObject({ name: 'ambassador', params: { id: 'abc' } });
    expect(matchPath('/ambassador-settings')?.name).toBe('ambassadorSettings');
    const itemsOf = (role: PanelRole) =>
      visibleNav((c) => capsOf(role).includes(c)).flatMap((g) => g.items.map((i) => i.to)).filter((to) => to.startsWith('/ambassador'));
    expect(itemsOf('OWNER')).toEqual(['/ambassadors', '/ambassador-applications', '/ambassador-campaigns', '/ambassador-settings']);
    expect(itemsOf('SUPPORT')).toEqual(['/ambassadors', '/ambassador-applications', '/ambassador-campaigns']);
    expect(itemsOf('FINANCE')).toEqual([]);
    expect(itemsOf('MODERATION')).toEqual([]);
  });
});

describe('D390 the list and the performance page', () => {
  it('SUPPORT sees no money; the OWNER sees the commissions', () => {
    const support = html('ar', <AmbassadorTable rows={[row({ commissions: null })]} />, 'SUPPORT');
    expect(support).toContain('المبالغ للمالك فقط');
    expect(support).not.toContain('960,000');
    const owner = html('en', <AmbassadorTable rows={[row()]} />);
    expect(owner).toContain('Commissions paid (cherries)');
    expect(owner).toContain('960,000');
    expect(owner).toContain('amb-star');
    expect(owner).toContain('>Star</span>');
    expect(owner).toMatch(/<img class="amb-level-icon" src="[^"]*star[^"]*\.webp" alt=""\/>/);
  });

  it('frozen and under review show as badges', () => {
    const out = html('ar', <AmbassadorTable rows={[row({ status: 'FROZEN', underReview: true, reviewReason: 'VELOCITY' })]} />);
    expect(out).toContain('data-amb-status="FROZEN"');
    expect(out).toContain('قيد المراجعة');
  });

  it('an ambassador’s page: flags, months, friends, commissions; the OWNER’s buttons only for the OWNER', () => {
    const owner = html('ar', <AmbassadorView data={detail({ underReview: true, reviewReason: 'VELOCITY' })} onAction={noop} />);
    expect(owner).toContain('سرعة إحالات غير طبيعية');
    expect(owner).toContain('data-amb-freeze');
    expect(owner).toContain('data-amb-clear-review');
    expect(owner).toContain('data-amb-level-chip="STAR"');
    expect(owner).toContain('>نجم</span> <span class="mono">5%</span>');
    expect(owner).toMatch(/>شرارة<\/span> → <span[^>]*data-amb-level-chip="STAR"/);
    const frozen = html('en', <AmbassadorView data={detail({ status: 'FROZEN', frozenReason: 'complaint' })} onAction={noop} />);
    expect(frozen).toContain('data-amb-unfreeze');
    expect(frozen).toContain('data-amb-end');
    // «إنهاء العضوية»: an ended member shows the end and no OWNER button at all.
    const ended = html('ar', <AmbassadorView data={detail({ status: 'ENDED', endedAt: '2026-11-13T10:00:00.000Z', endedReason: 'إحالات وهمية' })} onAction={noop} />);
    expect(ended).toContain('data-amb-status="ENDED"');
    expect(ended).toContain('انتهت العضوية');
    expect(ended).toContain('إحالات وهمية');
    expect(ended).not.toContain('data-amb-end');
    expect(ended).not.toContain('data-amb-freeze');
    expect(frozen).toContain('complaint');
    const support = html('en', <AmbassadorView data={detail({ commissions: null })} onAction={noop} />, 'SUPPORT');
    expect(support).not.toContain('data-amb-freeze');
    expect(support).not.toContain('data-amb-paid');
  });
});

describe('D390 applications and campaigns', () => {
  const app = {
    id: 'a1',
    status: 'PENDING' as const,
    country: 'SA',
    links: ['https://example.com/@sara'],
    audienceSize: 25_000,
    motivation: 'I run weekly contests.',
    createdAt: '2026-11-12T10:00:00.000Z',
    decidedAt: null,
    rejectReason: null,
    user: { id: 'u1', username: 'sara', displayName: 'Sara', avatarUrl: null },
    creator: true,
  };
  it('a pending application has approve / reject for SUPPORT, none for FINANCE; a creator is marked', () => {
    const support = html('ar', <ApplicationCard app={app} onApprove={noop} onReject={noop} />, 'SUPPORT');
    expect(support).toContain('data-amb-approve');
    expect(support).toContain('صانع محتوى');
    expect(support).toContain('25,000');
    expect(support).toContain('rel="noopener noreferrer nofollow"');
    const finance = html('en', <ApplicationCard app={app} onApprove={noop} onReject={noop} />, 'FINANCE');
    expect(finance).not.toContain('data-amb-approve');
  });

  it('a campaign lists its dates, country and ambassadors; the save body sends null for no country', () => {
    const out = html(
      'en',
      <CampaignCard c={{ id: 'k1', title: 'Ramadan nights', country: 'EG', startsOn: '2027-02-20', endsOn: '2027-03-20', notes: 'Two lives a week', ambassadors: [{ id: 'u1', username: 'sara', displayName: 'Sara' }] }} />,
    );
    expect(out).toContain('Ramadan nights');
    expect(out).toContain('2027-02-20 → 2027-03-20');
    expect(out).toContain('@sara');
    expect(campaignBody({ title: ' X ', country: ' ', startsOn: '2027-01-01', endsOn: '2027-01-02', notes: '', ambassadors: [] })).toEqual({
      title: 'X',
      country: null,
      startsOn: '2027-01-01',
      endsOn: '2027-01-02',
      notes: '',
      ambassadors: [],
    });
  });
});

describe('D390 the settings (OWNER)', () => {
  it('renders every number and the four proposed levels; says the programme is off', () => {
    const ar = html('ar', <AmbassadorSettingsForm saved={SETTINGS} draft={SETTINGS} onChange={noop} onSave={noop} />);
    expect(ar).toContain('البرنامج متوقف حالياً');
    for (const code of ['SPARK', 'STAR', 'CONSTELLATION', 'GALAXY']) {
      expect(ar).toContain(`data-amb-level="${code}"`);
      expect(ar).toContain(`data-amb-level-chip="${code}"`);
    }
    for (const name of ['شرارة', 'نجم', 'كوكبة', 'مجرّة']) expect(ar).toContain(`>${name}</span>`);
    expect(ar).toContain('data-amb-level-names');
    expect(ar).toContain('data-bps="500"');
    expect(ar).toContain('value="60"');
    expect(ar).toContain('لا تغييرات');
  });

  it('the level rules match the server, and the PUT body sends only the changes', () => {
    expect(levelsValid(SETTINGS.levels)).toBe(true);
    expect(levelsValid([{ ...SETTINGS.levels[0]!, minActiveReferrals: 1 }])).toBe(false);
    expect(levelsValid([SETTINGS.levels[0]!, { ...SETTINGS.levels[1]!, commissionBps: 100 }])).toBe(false);
    expect(levelsValid([SETTINGS.levels[0]!, { ...SETTINGS.levels[1]!, code: 'SPARK' }])).toBe(false);
    expect(ambassadorSettingsChanges(SETTINGS, { ...SETTINGS, enabled: true, holdDays: 7 })).toEqual({ enabled: true, holdDays: 7 });
    const levels = SETTINGS.levels.map((l) => (l.code === 'CONSTELLATION' ? { ...l, commissionBps: 450 } : l));
    expect(ambassadorSettingsChanges(SETTINGS, { ...SETTINGS, levels })).toEqual({ levels });
    expect(rewardOf('NONE', 5, 'x')).toEqual({ kind: 'NONE' });
    expect(rewardOf('VIP_DAYS', 7, '')).toEqual({ kind: 'VIP_DAYS', amount: 7, vipTier: 'VIP_1' });
    expect(rewardOf('BAG_ITEM', 30, 'frame_gold')).toEqual({ kind: 'BAG_ITEM', amount: 30, itemCode: 'frame_gold' });
    expect(bpsLabel(750)).toBe('7.5%');
  });
});

describe('D390 the level names and icons «سفراء النجوم» (owner 2026-11-14)', () => {
  const chip = (lang: Lang, code: string) => html(lang, <AmbassadorLevelChip code={code} />);

  it('the four default codes show their name and the app’s icon, in both languages', () => {
    const names: [string, string, string, string][] = [
      ['SPARK', 'شرارة', 'Spark', 'spark'],
      ['STAR', 'نجم', 'Star', 'star'],
      ['CONSTELLATION', 'كوكبة', 'Constellation', 'constellation'],
      ['GALAXY', 'مجرّة', 'Galaxy', 'galaxy'],
    ];
    for (const [code, ar, en, file] of names) {
      expect(chip('ar', code)).toContain(`>${ar}</span>`);
      expect(chip('en', code)).toContain(`>${en}</span>`);
      expect(chip('en', code)).toContain(`amb-level amb-${file}`);
      expect(ambassadorLevelIcon(code)).toMatch(new RegExp(`${file}[^/]*\\.webp$`));
    }
  });

  it('an old default code reads as its renamed level; a code the OWNER added shows as it is, without an icon', () => {
    expect(ambassadorLevelCode('BRONZE')).toBe('SPARK');
    expect(ambassadorLevelCode('SILVER')).toBe('STAR');
    expect(ambassadorLevelCode('GOLD')).toBe('CONSTELLATION');
    expect(ambassadorLevelCode('DIAMOND')).toBe('GALAXY');
    expect(chip('ar', 'GOLD')).toContain('>كوكبة</span>');
    expect(chip('ar', 'GOLD')).toContain('title="GOLD"');
    const custom = chip('en', 'PLATINUM');
    expect(custom).toContain('>PLATINUM</span>');
    expect(custom).not.toContain('<img');
    expect(ambassadorLevelIcon('PLATINUM')).toBeNull();
  });
});
