/**
 * D384 (the VIP «صورة متحركة»): the user page's profile group shows the person's animated picture for review and
 * offers «حذف الصورة المتحركة» to the roles holding `users.avatar` — only when there is one. Arabic and English.
 */
import { renderToStaticMarkup } from 'react-dom/server';
import { describe, expect, it } from 'vitest';
import { AppContext, type AppState } from '../src/context';
import { DICTIONARIES, translate, type Lang } from '../src/i18n';
import { AR_D384 } from '../src/i18n-d384';
import { ControlGroups } from '../src/pages/UserControl';
import type { Capability, PanelRole, UserDetail } from '../src/types';
import { CAPABILITY_ROLES } from './capabilities';

const state = (lang: Lang, role: PanelRole): AppState => ({
  lang,
  t: (key, vars) => translate(lang, key, vars),
  session: {
    admin: { id: 'a', email: 'a@x', username: 'a', displayName: 'A' },
    roles: [role],
    capabilities: [],
    csrfToken: 'x',
    expiresAt: '2026-11-12T00:00:00.000Z',
  } as never,
  can: (cap: Capability) => (CAPABILITY_ROLES[cap] ?? []).includes(role),
  toast: () => undefined,
});

const CLIP = 'https://media.example.test/media/0190f3a0-0000-7000-8000-0000000003a4/clip.webp';

const detail = (animatedAvatarUrl?: string): UserDetail => ({
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
    bio: null,
    baseUsername: 'layla_22',
    ...(animatedAvatarUrl ? { animatedAvatarUrl } : {}),
  },
  specialUsername: null,
  adminRoles: [],
  balances: { coins: 0, cherries: 0, lockedTaskCherries: 0, cherriesReceived: 0, coinsSent: 0 },
  ledger: null,
  rechargeAgent: null,
  hostAgent: null,
  agencyHost: null,
  verification: null,
  reports: { open: 0, recent: [] },
});

const html = (lang: Lang, role: PanelRole, d: UserDetail) =>
  renderToStaticMarkup(
    <AppContext.Provider value={state(lang, role)}>
      <ControlGroups detail={d} control={null} onAction={() => undefined} onTab={() => undefined} />
    </AppContext.Provider>,
  );

describe('D384 the VIP animated picture on the user page', () => {
  it('shows the clip and the removal to a moderator (Arabic first)', () => {
    const out = html('ar', 'MODERATION', detail(CLIP));
    expect(out).toContain(`src="${CLIP}"`);
    expect(out).toContain('ct-animated-avatar');
    expect(out).toContain('حذف الصورة المتحركة');
    expect(out).toContain('alt="الصورة المتحركة (VIP)"');
    expect(html('en', 'OWNER', detail(CLIP))).toContain('Remove animated picture');
  });

  it('nothing without a clip; no button for a role without users.avatar', () => {
    const none = html('ar', 'OWNER', detail());
    expect(none).not.toContain('ct-animated-avatar');
    expect(none).not.toContain('حذف الصورة المتحركة');
    // users.avatar is OWNER and MODERATION (the capability table).
    expect(CAPABILITY_ROLES['users.avatar']).toEqual(['OWNER', 'MODERATION']);
    for (const role of ['SUPPORT', 'FINANCE'] as PanelRole[]) {
      expect(html('en', role, detail(CLIP)), role).not.toContain('Remove animated picture');
    }
  });

  it('has its strings in both languages', () => {
    for (const key of Object.keys(AR_D384)) {
      expect(DICTIONARIES.ar[key as keyof typeof DICTIONARIES.ar], key).toBeTruthy();
      expect(DICTIONARIES.en[key as keyof typeof DICTIONARIES.en], key).toBeTruthy();
    }
  });
});
