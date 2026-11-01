/**
 * D217 «الدعوات»: a referral's page and the settings form rendered to HTML in Node (no DOM library) — the reason in
 * words, the signals and the rewards; the decision buttons only for OWNER / FINANCE and only where they apply; the
 * settings read-only for SUPPORT; only the changed fields are sent; milestones must increase. Both languages.
 */
import { renderToStaticMarkup } from 'react-dom/server';
import { describe, expect, it } from 'vitest';
import { AppContext, type AppState } from '../src/context';
import { DICTIONARIES, translate, type Lang } from '../src/i18n';
import { AR_D217, EN_D217 } from '../src/i18n-d217';
import { milestonesValid, ReferralSettingsForm, ReferralView, settingsChanges } from '../src/pages/Referrals';
import type { Capability, ReferralDetail, ReferralSettings } from '../src/types';
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

const person = (n: string) => ({ id: `0190f3a0-0000-7000-8000-00000000000${n}`, username: `user${n}`, displayName: `User ${n}`, avatarUrl: null, status: 'ACTIVE' });
function detail(over: Partial<ReferralDetail> = {}): ReferralDetail {
  return {
    id: '0190f3a0-0000-7000-8000-0000000000aa',
    status: 'REJECTED',
    source: 'SIGNUP',
    code: 'K7QM4P2X',
    rejectReason: 'SELF_DEVICE',
    voidReason: null,
    inviter: person('1'),
    invitee: person('2'),
    decidedBy: null,
    holdUntil: '2026-11-02T09:00:00.000Z',
    firstRechargeAt: null,
    qualifiedAt: null,
    voidedAt: null,
    createdAt: '2026-11-01T09:00:00.000Z',
    signals: { installId: true, ip: '198.51.100.7', sameDeviceReferrals: 2, sameEmailReferrals: 0 },
    rewards: [],
    ...over,
  };
}
const SAVED: ReferralSettings = {
  enabled: true,
  inviterSignupCherries: 20000,
  inviteeSignupCherries: 0,
  firstRechargeBps: 500,
  milestones: [
    { friends: 1, cherries: 50000 },
    { friends: 5, cherries: 300000 },
    { friends: 15, cherries: 1000000 },
  ],
  dailySignupCap: 20,
  holdHours: 24,
  applyWindowDays: 7,
  selfIpWindowHours: 24,
  updatedAt: '2026-11-01T09:00:00.000Z',
  updatedById: null,
};

const render = (lang: Lang, caps: Capability[], node: React.ReactNode) =>
  renderToStaticMarkup(<AppContext.Provider value={state(lang, caps)}>{node}</AppContext.Provider>);

describe('D217 «الدعوات»', () => {
  it('every string exists in both languages', () => {
    expect(Object.keys(EN_D217).sort()).toEqual(Object.keys(AR_D217).sort());
    for (const k of Object.keys(AR_D217)) {
      expect(DICTIONARIES.ar[k as never]).toBeTruthy();
      expect(DICTIONARIES.en[k as never]).toBeTruthy();
    }
  });

  it('a rejected referral: the reason in words, the signals, approve and void for FINANCE only', () => {
    for (const lang of ['ar', 'en'] as const) {
      const html = render(lang, capsOf('FINANCE'), <ReferralView data={detail()} onApprove={() => undefined} onVoid={() => undefined} />);
      expect(html).toContain(lang === 'ar' ? 'نفس جهاز الداعي' : "The inviter&#x27;s device");
      expect(html).toContain('198.51.100.7');
      expect(html).toContain('data-referral-approve');
      expect(html).toContain('data-referral-void');
    }
    const support = render('ar', capsOf('SUPPORT'), <ReferralView data={detail()} onApprove={() => undefined} onVoid={() => undefined} />);
    expect(support).not.toContain('data-referral-approve');
    expect(support).not.toContain('data-referral-void');
    // A qualified one cannot be approved again; a void one cannot be voided again.
    const qualified = render('ar', capsOf('OWNER'), <ReferralView data={detail({ status: 'QUALIFIED', rejectReason: null, qualifiedAt: '2026-11-02T09:00:00.000Z' })} onApprove={() => undefined} onVoid={() => undefined} />);
    expect(qualified).not.toContain('data-referral-approve');
    expect(qualified).toContain('data-referral-void');
    const voided = render('ar', capsOf('OWNER'), <ReferralView data={detail({ status: 'VOID', voidReason: 'INVITEE_BANNED', voidedAt: '2026-11-02T09:00:00.000Z' })} onApprove={() => undefined} onVoid={() => undefined} />);
    expect(voided).not.toContain('data-referral-void');
  });

  it('the rewards list each kind, amount and status', () => {
    const html = render(
      'en',
      capsOf('SUPPORT'),
      <ReferralView
        data={detail({
          status: 'QUALIFIED',
          rewards: [
            { id: 'r1', userId: 'u', kind: 'SIGNUP_INVITER', status: 'CREDITED', cherries: 20000, holdUntil: '2026-11-02T09:00:00.000Z', baseCoins: null, rateBps: null, rechargeReason: null, creditedAt: '2026-11-02T09:00:00.000Z', voidedAt: null, voidReason: null },
            { id: 'r2', userId: 'u', kind: 'FIRST_RECHARGE', status: 'VOID', cherries: 500, holdUntil: '2026-11-02T09:00:00.000Z', baseCoins: 1000, rateBps: 500, rechargeReason: 'CARD_TOPUP', creditedAt: null, voidedAt: '2026-11-02T09:00:00.000Z', voidReason: 'RECHARGE_REVERSED' },
          ],
        })}
        onApprove={() => undefined}
        onVoid={() => undefined}
      />,
    );
    expect(html).toContain('data-reward="SIGNUP_INVITER"');
    expect(html).toContain('Friend signed up (inviter)');
    expect(html).toContain('20,000');
    expect(html).toContain('RECHARGE_REVERSED');
    expect(html).toContain('Credited');
  });

  it('settings: read-only for SUPPORT, editable for FINANCE, only the changed fields are sent', () => {
    const ro = render('ar', capsOf('SUPPORT'), <ReferralSettingsForm saved={SAVED} draft={SAVED} onChange={() => undefined} onSave={() => undefined} />);
    expect(ro).toContain('للعرض فقط');
    expect(ro).not.toContain('data-referral-save');
    const fin = render('en', capsOf('FINANCE'), <ReferralSettingsForm saved={SAVED} draft={{ ...SAVED, holdHours: 48 }} onChange={() => undefined} onSave={() => undefined} />);
    expect(fin).toContain('data-referral-save');
    expect(fin).toContain('Save settings');
    expect(settingsChanges(SAVED, { ...SAVED, holdHours: 48, enabled: false })).toEqual({ holdHours: 48, enabled: false });
    expect(settingsChanges(SAVED, SAVED)).toEqual({});
    expect(settingsChanges(SAVED, { ...SAVED, milestones: [{ friends: 2, cherries: 10 }] })).toEqual({ milestones: [{ friends: 2, cherries: 10 }] });
  });

  it('milestones must increase and pay more than 0', () => {
    expect(milestonesValid(SAVED.milestones)).toBe(true);
    expect(milestonesValid([])).toBe(true);
    expect(milestonesValid([{ friends: 5, cherries: 1 }, { friends: 3, cherries: 1 }])).toBe(false);
    expect(milestonesValid([{ friends: 1, cherries: 0 }])).toBe(false);
    const bad = render('ar', capsOf('OWNER'), <ReferralSettingsForm saved={SAVED} draft={{ ...SAVED, milestones: [{ friends: 5, cherries: 1 }, { friends: 3, cherries: 1 }] }} onChange={() => undefined} onSave={() => undefined} />);
    expect(bad).toContain('يجب أن تتزايد');
  });
});
