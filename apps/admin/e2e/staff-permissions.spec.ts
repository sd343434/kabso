/**
 * D271 «الموظفون والصلاحيات» with a mocked API (no server needed): the OWNER's staff page (roles, authenticator, last
 * sign-in, shift), granting MODERATION to `@username` with a reason and a fresh code, the next steps for the new staff
 * member, and a refused revoke (the last OWNER) worded in Arabic. With KABSO_CAPTURE_DIR set it saves captures
 * (Arabic light 1440×900, dark, English, phone 390×844).
 */
import { mkdirSync } from 'node:fs';
import { join } from 'node:path';
import { expect, test, type Page, type Route } from '@playwright/test';

const captureDir = process.env.KABSO_CAPTURE_DIR;
const id = (n: number) => `0192f1d0-0000-7000-8000-${String(n).padStart(12, '0')}`;
const ago = (min: number) => new Date(Date.now() - min * 60_000).toISOString();

const OWNER = id(1);
const TEAM = [
  { id: OWNER, email: 'owner@kabsolive.com', username: 'kabso.owner', displayName: 'المالك', roles: ['OWNER'], totpEnrolled: true, lastSignInAt: ago(5), onShift: true, shiftSince: ago(90) },
  { id: id(2), email: 'huda@kabsolive.com', username: 'mod.huda', displayName: 'هدى', roles: ['MODERATION'], totpEnrolled: true, lastSignInAt: ago(30), onShift: true, shiftSince: ago(45) },
  { id: id(3), email: 'omar@kabsolive.com', username: 'help.omar', displayName: 'عمر', roles: ['SUPPORT'], totpEnrolled: true, lastSignInAt: ago(60 * 20), onShift: false, shiftSince: null },
  { id: id(4), email: 'lina@kabsolive.com', username: 'fin.lina', displayName: 'لينا', roles: ['FINANCE'], totpEnrolled: true, lastSignInAt: ago(60 * 26), onShift: false, shiftSince: null },
  { id: id(5), email: 'sami@kabsolive.com', username: 'sami.new', displayName: 'سامي', roles: ['SUPPORT', 'MODERATION'], totpEnrolled: false, lastSignInAt: null, onShift: false, shiftSince: null },
].map((m) => ({ avatarUrl: null, status: 'ACTIVE', lockedUntil: null, ...m }));

const CAPS = ['dashboard.view', 'users.view', 'lives.watch', 'audit.view', 'team.manage', 'staff.shifts'];
const sent: { path: string; body: unknown }[] = [];
const json = (route: Route, body: unknown, status = 200) =>
  route.fulfill({ status, contentType: 'application/json', body: JSON.stringify(body) });

async function mockApi(page: Page, lang: 'ar' | 'en'): Promise<void> {
  await page.route('**/api/v1/**', async (route) => {
    const req = route.request();
    const path = new URL(req.url()).pathname.replace('/api/v1', '');
    if (path === '/admin/auth/session')
      return json(route, {
        admin: { id: OWNER, email: 'owner@kabsolive.com', username: 'kabso.owner', displayName: 'المالك' },
        roles: ['OWNER'],
        capabilities: CAPS,
        csrfToken: 'csrf',
        expiresAt: new Date(Date.now() + 3_600_000).toISOString(),
        idleSeconds: 1800,
      });
    if (path === '/admin/stats/attention') return json(route, { total: 0, items: [] });
    if (path === '/admin/team') return json(route, { data: TEAM });
    if (path === '/admin/team/grant') {
      sent.push({ path, body: req.postDataJSON() });
      return json(route, {
        userId: id(9),
        role: 'MODERATION',
        madeAdmin: true,
        already: false,
        account: { email: 'yousef@example.com', username: 'yousef.k', displayName: lang === 'ar' ? 'يوسف' : 'Yousef', totpEnrolled: false },
      });
    }
    if (/^\/admin\/team\/[^/]+\/revoke$/.test(path)) {
      sent.push({ path, body: req.postDataJSON() });
      return json(
        route,
        { error: { code: 'ADMIN_ACTION_REFUSED', message: 'This is the last OWNER.', details: [{ field: 'rule', issue: 'team_last_owner' }], requestId: 'x' } },
        409,
      );
    }
    return json(route, {});
  });
}

async function capture(page: Page, name: string): Promise<void> {
  if (!captureDir) return;
  mkdirSync(captureDir, { recursive: true });
  await page.waitForTimeout(300);
  await page.screenshot({ path: join(captureDir, `${name}.png`) });
}

test.setTimeout(120_000);

for (const [lang, theme, width, height] of [
  ['ar', 'light', 1440, 900],
  ['ar', 'dark', 1440, 900],
  ['en', 'light', 1440, 900],
  ['ar', 'light', 390, 844],
] as const) {
  test(`«الموظفون والصلاحيات» — list, grant with the code, next steps (${lang}, ${theme}, ${width})`, async ({ page }) => {
    const errors: string[] = [];
    page.on('pageerror', (e) => errors.push(e.message));
    await page.addInitScript(
      ([th, lg]) => {
        window.localStorage.setItem('kabso-admin-theme', th ?? 'light');
        window.localStorage.setItem('kabso-admin-lang', lg ?? 'ar');
      },
      [theme, lang],
    );
    sent.length = 0;
    await mockApi(page, lang);
    await page.setViewportSize({ width, height });
    await page.goto('/team');
    const ar = lang === 'ar';
    await expect(page.getByRole('heading', { name: ar ? 'الموظفون والصلاحيات' : 'Staff & permissions', level: 1 })).toBeVisible();
    await expect(page.locator('.member')).toHaveCount(5);
    await expect(page.locator('.member[data-on-shift="true"]')).toHaveCount(2);
    await expect(page.getByText('@mod.huda')).toBeVisible();
    const tag = `${lang}.${theme}${width < 600 ? '.phone' : ''}`;
    await capture(page, `01-staff-list.${tag}`);

    // Grant MODERATION to @yousef.k with a reason and a fresh code.
    await page.getByRole('button', { name: ar ? 'منح دور' : 'Grant role' }).first().click();
    const dialog = page.getByRole('dialog');
    await dialog.getByRole('button', { name: ar ? 'مشرف' : 'Moderator' }).click();
    await dialog.getByLabel(ar ? 'البريد أو اسم المستخدم' : 'Email or username').fill('@yousef.k');
    await dialog.getByLabel(ar ? 'السبب' : 'Reason').fill(ar ? 'موظف مراقبة جديد' : 'New moderation hire');
    await dialog.getByLabel(ar ? 'رمز تطبيق المصادقة' : 'Authenticator code').fill('123456');
    await capture(page, `02-grant-dialog.${tag}`);
    await dialog.getByRole('button', { name: ar ? 'منح دور' : 'Grant role' }).click();
    await expect(page.getByRole('dialog')).toContainText(ar ? 'الخطوات التالية' : 'next steps');
    await expect(page.getByRole('dialog')).toContainText(ar ? '«في المناوبة»' : '«On shift»');
    expect(sent).toEqual([
      {
        path: '/admin/team/grant',
        body: { account: '@yousef.k', role: 'MODERATION', reason: ar ? 'موظف مراقبة جديد' : 'New moderation hire', totpCode: '123456' },
      },
    ]);
    await capture(page, `03-next-steps.${tag}`);
    await page.getByRole('button', { name: ar ? 'تم' : 'Done' }).click();

    // The OWNER grant shows its warning.
    await page.getByRole('button', { name: ar ? 'منح دور' : 'Grant role' }).first().click();
    await page.getByRole('dialog').getByRole('button', { name: ar ? 'مالك' : 'Owner' }).click();
    await expect(page.locator('[data-owner-warning]')).toBeVisible();
    await capture(page, `04-grant-owner-warning.${tag}`);
    await page.getByRole('dialog').getByRole('button', { name: ar ? 'إلغاء' : 'Cancel' }).click();

    // A revoke refused by the server is worded by the panel.
    await page.locator(`.member[data-member="${id(2)}"]`).getByRole('button', { name: ar ? 'سحب دور' : 'Revoke role' }).click();
    await page.getByRole('dialog').getByRole('button', { name: ar ? 'مشرف' : 'Moderator' }).click();
    const rd = page.getByRole('dialog');
    await rd.getByLabel(ar ? 'السبب' : 'Reason').fill('x');
    await rd.getByLabel(ar ? 'رمز تطبيق المصادقة' : 'Authenticator code').fill('654321');
    await rd.getByRole('button', { name: ar ? 'سحب دور' : 'Revoke role' }).click();
    await expect(rd).toContainText(ar ? 'هذا آخر مالك' : 'This is the last OWNER');
    expect(errors).toEqual([]);
  });
}
