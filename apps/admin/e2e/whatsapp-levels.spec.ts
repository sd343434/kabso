/**
 * D360 «مستوى واتساب لكل موظف» with a mocked API (no server needed): the team page's level row and its dialog (the
 * OWNER, team.manage), and the VIEW-only chat («مشاهدة فقط», no actions, no composer, no read receipt). Synthetic
 * people only. With KABSO_CAPTURE_DIR set it saves captures (Arabic first, then English; light and dark; 1440×900).
 */
import { mkdirSync } from 'node:fs';
import { join } from 'node:path';
import { expect, test, type Page, type Route } from '@playwright/test';

const captureDir = process.env.KABSO_CAPTURE_DIR;
const id = (n: number) => `0192f1d0-0000-7000-8000-${String(n).padStart(12, '0')}`;
const ago = (min: number) => new Date(Date.now() - min * 60_000).toISOString();
const OWNER_CAPS = ['dashboard.view', 'team.manage', 'support.whatsapp.view', 'support.whatsapp', 'support.whatsapp.manage'];
const VIEW_CAPS = ['dashboard.view', 'support.whatsapp.view'];
const recruits = { HOST: 0, AGENCY: 0, RECHARGE_AGENT: 0, CREATOR: 0, total: 0 };
const member = (n: number, name: string, roles: string[], whatsapp: Record<string, unknown>) => ({
  id: id(n),
  email: `staff${n}@kabso.example`,
  username: `staff_${n}`,
  displayName: name,
  avatarUrl: null,
  status: 'ACTIVE',
  roles,
  totpEnrolled: true,
  lockedUntil: null,
  lastSignInAt: ago(30 * n),
  onShift: n === 2,
  shiftSince: n === 2 ? ago(40) : null,
  regions: [],
  staffId: `Kabso0${n}`,
  recruits,
  whatsapp,
});
const TEAM = [
  member(1, 'المالك', ['OWNER'], { level: 'MANAGE', setLevel: null, defaultLevel: 'MANAGE', locked: true }),
  member(2, 'منى', ['SUPPORT'], { level: 'VIEW', setLevel: 'VIEW', defaultLevel: 'REPLY', locked: false }),
  member(3, 'خالد', ['MODERATION'], { level: 'MANAGE', setLevel: null, defaultLevel: 'MANAGE', locked: false }),
  member(4, 'سلمى', ['FINANCE'], { level: 'REPLY', setLevel: 'REPLY', defaultLevel: 'NONE', locked: false }),
];
const mona = { userId: id(3), displayName: 'خالد', staffId: 'Kabso03' };
const CONV = {
  id: id(101),
  phone: '+966500001001',
  name: 'سارة',
  status: 'OPEN',
  assignedTo: mona,
  assignedToMe: false,
  unreadCount: 2,
  lastMessageAt: ago(4),
  lastPreview: 'لم يصل الشحن',
  lastDirection: 'INBOUND',
  window: { open: true, closesAt: new Date(Date.now() + 20 * 3_600_000).toISOString() },
  linkedAccount: { userId: id(50), username: 'sara_9', displayName: 'سارة', avatarUrl: null, status: 'ACTIVE', countryCode: 'SA', createdAt: '2026-03-01T00:00:00.000Z' },
  closedAt: null,
  createdAt: ago(600),
};
const msg = (n: number, over: Record<string, unknown>) => ({
  id: id(200 + n),
  direction: 'INBOUND',
  type: 'TEXT',
  text: null,
  media: null,
  location: null,
  reaction: null,
  template: null,
  status: 'RECEIVED',
  error: null,
  sentBy: null,
  at: ago(60 - n * 5),
  statusAt: null,
  ...over,
});
const MESSAGES = [
  msg(3, { direction: 'OUTBOUND', text: 'أهلاً سارة، نتحقق من طلبك الآن', status: 'DELIVERED', sentBy: mona }),
  msg(2, { text: 'دفعت للوكيل ولم يصل الشحن' }),
  msg(1, { text: 'السلام عليكم' }),
];

const json = (route: Route, body: unknown, status = 200) =>
  route.fulfill({ status, contentType: 'application/json', body: JSON.stringify(body) });

async function mockApi(page: Page, caps: string[], calls: string[]): Promise<void> {
  await page.route('**/api/v1/**', async (route) => {
    const req = route.request();
    const url = new URL(req.url());
    const path = url.pathname.replace('/api/v1', '');
    if (req.method() !== 'GET') calls.push(`${req.method()} ${path}`);
    if (path === '/admin/auth/session')
      return json(route, {
        admin: { id: id(1), email: 'owner@kabso.example', username: 'kabso.owner', displayName: 'المالك' },
        roles: caps === OWNER_CAPS ? ['OWNER'] : ['SUPPORT'],
        capabilities: caps,
        csrfToken: 'csrf',
        expiresAt: new Date(Date.now() + 3_600_000).toISOString(),
        idleSeconds: 1800,
      });
    if (path === '/admin/stats/attention') return json(route, { total: 0, items: [] });
    if (path === '/admin/team') return json(route, { data: TEAM });
    if (path === '/admin/whatsapp/summary') return json(route, { enabled: true, badge: 1, mine: 0, unassigned: 1, unreadMessages: 2 });
    if (path === '/admin/whatsapp/conversations') return json(route, { data: [CONV], page: { nextCursor: null, hasMore: false } });
    const m = /^\/admin\/whatsapp\/conversations\/([^/]+)(\/[a-z-]+)?$/.exec(path);
    if (m) {
      const sub = m[2];
      if (!sub) return json(route, CONV);
      if (sub === '/messages') return json(route, { data: MESSAGES, page: { nextCursor: null, hasMore: false } });
      if (sub === '/notes') return json(route, { data: [{ id: id(300), body: 'ننتظر تأكيد الوكيل', author: mona, at: ago(20) }] });
      if (sub === '/assignments') return json(route, { data: [{ id: id(301), action: 'CLAIM', from: null, to: mona, by: mona, at: ago(40) }] });
      return json(route, {}, 403);
    }
    return json(route, {});
  });
}

async function capture(page: Page, name: string): Promise<void> {
  if (!captureDir) return;
  mkdirSync(captureDir, { recursive: true });
  await page.waitForTimeout(400);
  await page.screenshot({ path: join(captureDir, `${name}.png`) });
}

test.setTimeout(120_000);

for (const [lang, theme] of [
  ['ar', 'light'],
  ['ar', 'dark'],
  ['en', 'light'],
  ['en', 'dark'],
] as const) {
  const ar = lang === 'ar';
  const prep = async (page: Page) => {
    await page.addInitScript(
      ([th, lg]) => {
        window.localStorage.setItem('kabso-admin-theme', th ?? 'light');
        window.localStorage.setItem('kabso-admin-lang', lg ?? 'ar');
      },
      [theme, lang],
    );
    await page.setViewportSize({ width: 1440, height: 900 });
  };

  test(`the team page: «مستوى واتساب» and its dialog (${lang}, ${theme})`, async ({ page }) => {
    await prep(page);
    await mockApi(page, OWNER_CAPS, []);
    await page.goto('/team');
    await expect(page.locator('[data-wa-level]')).toHaveCount(4);
    await expect(page.locator(`[data-member="${id(2)}"] [data-wa-level="VIEW"]`)).toBeVisible();
    await expect(page.locator(`[data-member="${id(1)}"] [data-edit-wa-level]`)).toHaveCount(0);
    await capture(page, `panel.team_level.${lang}.${theme}`);
    await page.locator(`[data-member="${id(2)}"] [data-edit-wa-level]`).click();
    await expect(page.locator('[data-wa-level-option]')).toHaveCount(5);
    await expect(page.locator('[data-wa-level-option="VIEW"] input')).toBeChecked();
    await capture(page, `panel.team_level_dialog.${lang}.${theme}`);
  });

  test(`the VIEW-only chat (${lang}, ${theme})`, async ({ page }) => {
    const errors: string[] = [];
    page.on('pageerror', (e) => errors.push(e.message));
    const calls: string[] = [];
    await prep(page);
    await mockApi(page, VIEW_CAPS, calls);
    await page.goto(`/whatsapp?c=${CONV.id}`);
    await expect(page.getByRole('heading', { name: ar ? 'واتساب' : 'WhatsApp', level: 1 })).toBeVisible();
    await expect(page.locator('[data-wa-view-only]')).toBeVisible();
    await expect(page.locator('.wa-bubble')).toHaveCount(3);
    await expect(page.locator('.wa-composer')).toHaveCount(0);
    await expect(page.locator('.wa-actions')).toHaveCount(0);
    await expect(page.locator('.wa-view-only')).toBeVisible();
    await expect(page.locator('[data-wa-account]')).toContainText('@sara_9');
    await capture(page, `panel.view_only_chat.${lang}.${theme}`);
    expect(calls).toEqual([]); // never marks read, never acts
    expect(errors).toEqual([]);
  });
}
