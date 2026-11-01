/**
 * D223 «الجهاز»: the accounts created on a user's sign-up device rendered to HTML in Node (no DOM library) — the count
 * against the limit, deleted accounts listed, the exception; the grant / remove buttons only for an OWNER; an account
 * created without a device id. Both languages.
 */
import { renderToStaticMarkup } from 'react-dom/server';
import { describe, expect, it } from 'vitest';
import { AppContext, type AppState } from '../src/context';
import { DICTIONARIES, translate, type Lang } from '../src/i18n';
import { AR_D223, EN_D223 } from '../src/i18n-d223';
import { DeviceSignupsView } from '../src/pages/UserDevice';
import type { Capability, DeviceSignups } from '../src/types';
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
const render = (lang: Lang, caps: Capability[], data: DeviceSignups) =>
  renderToStaticMarkup(
    <AppContext.Provider value={state(lang, caps)}>
      <DeviceSignupsView data={data} onGrant={() => undefined} onRemove={() => undefined} />
    </AppContext.Provider>,
  );

const DATA: DeviceSignups = {
  known: true,
  platform: 'android',
  createdAt: '2026-11-01T09:00:00.000Z',
  defaultMax: 2,
  maxAccounts: 2,
  count: 2,
  exception: null,
  accounts: [
    { id: '0190f3a0-0000-7000-8000-000000000001', username: 'layla_22', displayName: 'Layla', status: 'ACTIVE', createdAt: '2026-11-01T09:00:00.000Z', self: true },
    { id: '0190f3a0-0000-7000-8000-000000000002', username: 'deleted_x', displayName: '', status: 'DELETED', createdAt: '2026-11-01T10:00:00.000Z', self: false },
  ],
};

describe('D223 «الجهاز»', () => {
  it('every string exists in both languages', () => {
    expect(Object.keys(EN_D223).sort()).toEqual(Object.keys(AR_D223).sort());
    for (const k of Object.keys(AR_D223)) {
      expect(DICTIONARIES.ar[k as never]).toBeTruthy();
      expect(DICTIONARIES.en[k as never]).toBeTruthy();
    }
  });

  it('the capabilities: SUPPORT views, only an OWNER grants', () => {
    expect(capsOf('SUPPORT')).toContain('users.device_view');
    expect(capsOf('SUPPORT')).not.toContain('users.device_exception');
    expect(capsOf('OWNER')).toEqual(expect.arrayContaining(['users.device_view', 'users.device_exception']));
    expect(capsOf('FINANCE')).not.toContain('users.device_view');
  });

  it('SUPPORT: the accounts (deleted included) and the limit, no buttons', () => {
    for (const lang of ['ar', 'en'] as const) {
      const html = render(lang, capsOf('SUPPORT'), DATA);
      expect(html).toContain('@layla_22');
      expect(html).toContain('@deleted_x');
      expect(html).toContain(DICTIONARIES[lang].statusDELETED);
      expect(html).toContain(DICTIONARIES[lang].dvExceptionNone);
      expect(html).not.toContain(DICTIONARIES[lang].dvGrant);
      expect(html).not.toMatch(/[0-9a-f]{64}/);
    }
  });

  it('OWNER: grant, and remove when there is an exception', () => {
    const html = render('ar', capsOf('OWNER'), DATA);
    expect(html).toContain(AR_D223.dvGrant);
    expect(html).not.toContain(AR_D223.dvRemove);
    const withException = render('en', capsOf('OWNER'), {
      ...DATA,
      maxAccounts: 3,
      exception: {
        maxAccounts: 3,
        reason: 'Family phone',
        grantedBy: { id: '0190f3a0-0000-7000-8000-000000000009', username: 'owner_1' },
        grantedAt: '2026-11-01T11:00:00.000Z',
      },
    });
    expect(withException).toContain('Family phone');
    expect(withException).toContain('@owner_1');
    expect(withException).toContain(EN_D223.dvRemove);
  });

  it('an account made without a device id says so', () => {
    const html = render('ar', capsOf('OWNER'), { ...DATA, known: false, platform: null, createdAt: null, count: 0, accounts: [] });
    expect(html).toContain(AR_D223.dvUnknown);
    expect(html).not.toContain(AR_D223.dvGrant);
  });
});
