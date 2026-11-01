/**
 * D208 «تحكم كامل»: the user page's action groups rendered to HTML in Node — the six groups, the state each shows
 * (lock end, restrictions, email, forced change, deletion), the buttons each role gets, the dialogs' contents, and
 * the profile PATCH body (only what changed). Arabic and English.
 */
import { readFileSync } from 'node:fs';
import { renderToStaticMarkup } from 'react-dom/server';
import { describe, expect, it } from 'vitest';
import { AppContext, type AppState } from '../src/context';
import { DICTIONARIES, translate, type Lang } from '../src/i18n';
import { CAPABILITY_ROLES } from './capabilities';
import {
  AdjustDialog,
  ControlGroups,
  DurationDialog,
  profilePatch,
  RestrictionHistory,
} from '../src/pages/UserControl';
import type { Capability, PanelRole, UserControl, UserDetail } from '../src/types';

const state = (lang: Lang, role: PanelRole): AppState => ({
  lang,
  t: (key, vars) => translate(lang, key, vars),
  session: {
    admin: { id: 'a', email: 'a@x', username: 'a', displayName: 'A' },
    roles: [role],
    capabilities: [],
    csrfToken: 'x',
    expiresAt: '2026-11-01T00:00:00.000Z',
  } as never,
  can: (cap: Capability) => (CAPABILITY_ROLES[cap] ?? []).includes(role),
  toast: () => undefined,
});

const detail: UserDetail = {
  user: {
    id: '0190f3a0-0000-7000-8000-000000000009',
    username: 'layla_22',
    displayName: 'ليلى',
    email: 'layla@example.com',
    status: 'ACTIVE',
    avatarUrl: null,
    createdAt: '2026-10-01T09:00:00.000Z',
    role: 'USER',
    lastActiveAt: null,
    countryCode: 'JO',
    bio: 'مرحبا',
    baseUsername: 'layla_22',
  },
  specialUsername: null,
  adminRoles: [],
  balances: { coins: 12500, cherries: 300, lockedTaskCherries: 0 },
  ledger: null,
  rechargeAgent: null,
  hostAgent: null,
  agencyHost: null,
  reports: { open: 0, recent: [] },
};

const restriction = (kind: UserControl['restrictions'][number]['kind'], over: Partial<UserControl['restrictions'][number]> = {}) => ({
  id: `r-${kind}`,
  kind,
  reason: 'سبب',
  startsAt: '2026-10-31T09:00:00.000Z',
  endsAt: '2026-11-03T09:00:00.000Z',
  via: 'panel' as const,
  active: true,
  liftedAt: null,
  liftReason: null,
  createdAt: '2026-10-31T09:00:00.000Z',
  ...over,
});

const control: UserControl = {
  status: 'ACTIVE',
  lock: restriction('LOCK'),
  restrictions: [restriction('CHAT_MUTE')],
  history: [restriction('LOCK'), restriction('CHAT_MUTE'), restriction('NO_POSTING', { active: false, liftReason: 'replaced', liftedAt: '2026-10-30T09:00:00.000Z' })],
  password: { changeRequired: true },
  email: { address: 'layla@example.com', verified: false },
  gender: 'FEMALE',
  cover: null,
  deletion: null,
  adjustToday: { coins: 1000, cherries: 0, capCoins: 10_000_000, capCherries: 10_000_000 },
  adjustments: [],
};

const groups = (lang: Lang, role: PanelRole, c: UserControl | null = control) =>
  renderToStaticMarkup(
    <AppContext.Provider value={state(lang, role)}>
      <ControlGroups detail={detail} control={c} onAction={() => undefined} onTab={() => undefined} />
    </AppContext.Provider>,
  );

describe('D208 action groups', () => {
  it('shows the six groups and their state (Arabic first)', () => {
    const html = groups('ar', 'OWNER');
    for (const g of ['الحساب', 'الأمان', 'الملف الشخصي', 'القيود', 'المحتوى', 'المال']) expect(html).toContain(g);
    expect(html).toContain('مقفل حتى');
    expect(html).toContain('كتم الدردشة');
    expect(html).toContain('غير موثّق');
    expect(html).toContain('مطلوب تغيير كلمة المرور');
    expect(html).toContain('12,500');
  });

  it('gives each role only its buttons', () => {
    const owner = groups('en', 'OWNER');
    for (const b of ['Unlock now', 'Ban', 'Delete the account', 'Set a temporary password', 'Change the email', 'Edit the profile', 'Add a restriction', 'Adjust the balance'])
      expect(owner, b).toContain(b);
    const finance = groups('en', 'FINANCE');
    expect(finance).toContain('Adjust the balance');
    for (const b of ['Unlock now', 'Set a temporary password', 'Edit the profile', 'Add a restriction', 'Delete the account'])
      expect(finance, b).not.toContain(b);
    const support = groups('en', 'SUPPORT');
    expect(support).toContain('Set a temporary password');
    expect(support).toContain('Unlock now');
    expect(support).not.toContain('Adjust the balance');
    expect(support).not.toContain('Add a restriction');
    const mod = groups('en', 'MODERATION');
    expect(mod).toContain('Add a restriction');
    expect(mod).not.toContain('Set a temporary password');
  });

  it('offers a lock only to an ACTIVE account and the cancel of a pending deletion', () => {
    const pending = { ...control, lock: null, deletion: { requestedAt: '2026-10-31T09:00:00.000Z', purgeAfter: '2026-11-30T09:00:00.000Z', requestedVia: 'ADMIN' as const } };
    const html = renderToStaticMarkup(
      <AppContext.Provider value={state('en', 'OWNER')}>
        <ControlGroups detail={{ ...detail, user: { ...detail.user, status: 'PENDING_DELETION' } }} control={pending} onAction={() => undefined} onTab={() => undefined} />
      </AppContext.Provider>,
    );
    expect(html).toContain('Cancel the deletion');
    expect(html).not.toContain('Lock for a while');
    expect(html).toContain('Deleted after');
  });

  it('the dialogs show the quick durations, the history, today’s cap and «allow negative» only to an OWNER', () => {
    const lock = renderToStaticMarkup(
      <AppContext.Provider value={state('ar', 'SUPPORT')}>
        <DurationDialog userId="u" mode="lock" control={control} onClose={() => undefined} onDone={() => undefined} />
      </AppContext.Provider>,
    );
    for (const d of ['يوم', '٣ أيام', '٧ أيام', '٣٠ يوماً', 'حتى تاريخ', 'السبب (يظهر للمستخدم)', 'السجل']) expect(lock).toContain(d);
    const restrict = renderToStaticMarkup(
      <AppContext.Provider value={state('en', 'MODERATION')}>
        <DurationDialog userId="u" mode="restrict" control={control} onClose={() => undefined} onDone={() => undefined} />
      </AppContext.Provider>,
    );
    for (const k of ['Chat mute', 'No going live', 'No sending gifts', 'No posting']) expect(restrict).toContain(k);
    const history = renderToStaticMarkup(
      <AppContext.Provider value={state('en', 'OWNER')}>
        <RestrictionHistory rows={control.history} />
      </AppContext.Provider>,
    );
    expect(history).toContain('Replaced');
    const adjust = (role: PanelRole) =>
      renderToStaticMarkup(
        <AppContext.Provider value={state('en', role)}>
          <AdjustDialog userId="u" detail={detail} control={control} onClose={() => undefined} onDone={() => undefined} />
        </AppContext.Provider>,
      );
    expect(adjust('FINANCE')).toContain('Balance now: 12,500');
    expect(adjust('FINANCE')).toContain('Your use today: 1,000 of 10,000,000');
    expect(adjust('FINANCE')).toContain('Authenticator code');
  });

  it('sends only the profile fields that changed', () => {
    const now = { displayName: 'ليلى', username: 'layla_22', bio: 'مرحبا', countryCode: 'JO', gender: 'FEMALE' };
    expect(profilePatch(now, { displayName: 'ليلى', username: 'layla_22', bio: 'مرحبا', country: 'jo', gender: 'FEMALE' })).toEqual({});
    expect(profilePatch(now, { displayName: ' ليلى ك ', username: 'Layla_23', bio: '', country: '', gender: 'MALE' })).toEqual({
      displayName: 'ليلى ك',
      username: 'layla_23',
      bio: null,
      country: null,
      gender: 'MALE',
    });
  });

  it('has every D208 string in both languages', () => {
    const keys = Object.keys(DICTIONARIES.ar).filter((k) => k.startsWith('ct'));
    expect(keys.length).toBeGreaterThan(90);
    for (const k of keys) expect(DICTIONARIES.en[k as keyof typeof DICTIONARIES.en], k).toBeTruthy();
  });

  it('the test copy of the capability table matches the API', () => {
    const src = readFileSync(new URL('../../api/src/modules/admin-panel/admin-permissions.ts', import.meta.url), 'utf8');
    const api = Object.fromEntries(
      [...src.matchAll(/^\s*'([a-z_.]+)': \[([^\]]*)\],/gm)].map((m) => [m[1], m[2]!.split(',').map((r) => r.trim().replace(/'/g, ''))]),
    );
    expect(CAPABILITY_ROLES).toEqual(api);
  });
});
