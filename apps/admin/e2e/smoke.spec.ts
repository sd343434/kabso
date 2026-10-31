/**
 * D191 + D197: one smoke run of the real admin panel against a local API (`SMOKE_V2=1 pnpm --filter @kabso/api
 * smoke:admin-server`, which seeds a not-yet-enrolled OWNER, 30 days of synthetic activity, lives, agencies and gifts,
 * and writes the credentials to KABSO_SMOKE_FILE). Signs in and enrols the authenticator from the page's own secret
 * (codes generated here, RFC 6238), then: the dashboard's KPI cards and chart with data, the users table and a user's
 * tabs, agencies list → detail, END LIVE with a reason, a new gift, a team grant with the code again, the audit viewer
 * filtered, the finance report, an application approved and a withdrawal marked paid. With KABSO_CAPTURE_DIR set it
 * saves the owner's review captures (Arabic light 1440×900, dark, mobile 390×844; private pictures blurred).
 */
import { createHmac } from 'node:crypto';
import { mkdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { expect, test, type Page } from '@playwright/test';

const B32 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
function totp(secret: string, atMs: number): string {
  let bits = 0;
  let value = 0;
  const bytes: number[] = [];
  for (const ch of secret.replace(/=+$/, '')) {
    value = (value << 5) | B32.indexOf(ch);
    bits += 5;
    if (bits >= 8) {
      bytes.push((value >>> (bits - 8)) & 255);
      bits -= 8;
    }
  }
  const counter = Buffer.alloc(8);
  counter.writeBigUInt64BE(BigInt(Math.floor(atMs / 30_000)));
  const mac = createHmac('sha1', Buffer.from(bytes)).update(counter).digest();
  const offset = mac[mac.length - 1]! & 0x0f;
  return String((mac.readUInt32BE(offset) & 0x7fffffff) % 1_000_000).padStart(6, '0');
}

const smokeFile = process.env.KABSO_SMOKE_FILE ?? '';
const captureDir = process.env.KABSO_CAPTURE_DIR;

async function capture(page: Page, name: string): Promise<void> {
  if (!captureDir) return;
  mkdirSync(captureDir, { recursive: true });
  // The applicant's private pictures never appear sharp in a capture.
  await page.addStyleTag({ content: '[data-private-photo] img { filter: blur(18px) !important; }' });
  await expect(page.locator('.toast')).toHaveCount(0, { timeout: 5000 });
  await page.waitForTimeout(150);
  await page.screenshot({ path: join(captureDir, `${name}.png`), fullPage: false });
}

/** A code of the next 30-second step not used yet (a code works once). */
let lastStep = 0;
async function freshCode(page: Page, secret: string): Promise<string> {
  let step = Math.floor(Date.now() / 30_000);
  while (step <= lastStep) {
    await page.waitForTimeout(1000);
    step = Math.floor(Date.now() / 30_000);
  }
  lastStep = step;
  return totp(secret, Date.now());
}

async function go(page: Page, label: string): Promise<void> {
  const width = page.viewportSize()?.width ?? 1440;
  if (width < 1024) await page.getByRole('button', { name: 'القائمة' }).click();
  await page.locator('nav.nav').getByRole('link', { name: label, exact: true }).click();
}

test.setTimeout(420_000);

test('admin panel smoke: TOTP sign-in, dashboard charts, users, agencies, end a live, gift, team, audit, money', async ({ page }) => {
  test.skip(!smokeFile, 'KABSO_SMOKE_FILE is not set (start the smoke API first)');
  const seed = JSON.parse(readFileSync(smokeFile, 'utf8')) as {
    email: string;
    password: string;
    applicant: string;
    teamRecruit?: string;
    liveTitle?: string;
  };
  const v2 = seed.teamRecruit !== undefined;
  const errors: string[] = [];
  page.on('console', (m) => m.type() === 'error' && errors.push(m.text()));
  page.on('pageerror', (e) => errors.push(e.message));
  await page.setViewportSize({ width: 1440, height: 900 });

  await page.goto('/');
  await expect(page.locator('html')).toHaveAttribute('dir', 'rtl');
  await expect(page.getByRole('heading', { name: 'تسجيل دخول المشرفين' })).toBeVisible();
  await capture(page, '01-login');
  await page.getByLabel('البريد الإلكتروني').fill(seed.email);
  await page.getByLabel('كلمة المرور').fill(seed.password);
  await page.getByRole('button', { name: 'دخول' }).click();

  // First sign-in: the QR enrolment, the code from the page's secret, the recovery codes.
  await expect(page.getByRole('heading', { name: 'إعداد تطبيق المصادقة' })).toBeVisible();
  const secret = (await page.getByTestId('totp-secret').innerText()).trim();
  expect(secret).toMatch(/^[A-Z2-7]{32}$/);
  await page.getByLabel('رمز تطبيق المصادقة').fill(await freshCode(page, secret));
  await page.getByRole('button', { name: 'تحقق' }).click();
  await expect(page.getByTestId('recovery-codes').locator('code')).toHaveCount(10);
  await page.getByRole('button', { name: 'حفظتُ الرموز — متابعة' }).click();

  // Dashboard: five KPI cards with sparklines, the chart with data, the attention list and the bell.
  await expect(page.locator('.kpi')).toHaveCount(5);
  await expect(page.locator('.kpi .spark')).toHaveCount(5);
  await expect(page.getByRole('heading', { name: 'نظرة على النمو' })).toBeVisible();
  await expect(page.locator('.chart-svg path[stroke]')).toHaveCount(3);
  await expect(page.getByRole('heading', { name: 'يحتاج انتباهك' })).toBeVisible();
  if (v2) {
    const coins = await page.locator('.kpi.tone-gold .kpi-value').innerText();
    expect(Number(coins.replace(/[^0-9]/g, ''))).toBeGreaterThan(0);
    // The tooltip on the chart.
    const box = (await page.locator('.chart-svg').boundingBox())!;
    await page.mouse.move(box.x + box.width / 2, box.y + box.height / 2);
    await expect(page.locator('.tooltip')).toBeVisible();
  }
  await page.getByRole('button', { name: '7 يوماً' }).click();
  await page.getByRole('button', { name: '30 يوماً' }).click();
  await page.mouse.move(5, 5);
  await capture(page, '02-dashboard');

  // Users table → a user's page and its tabs.
  await go(page, 'المستخدمون');
  await expect(page.getByRole('heading', { name: 'المستخدمون', level: 1 })).toBeVisible();
  await page.locator('.table-tools input[type=search]').fill(seed.applicant);
  await expect(page.locator('tbody tr')).toHaveCount(1);
  if (v2) {
    await page.locator('.table-tools input[type=search]').fill('');
    await expect(page.locator('tbody tr').nth(5)).toBeVisible();
  }
  await capture(page, '03-users');
  await page.locator('.table-tools input[type=search]').fill(seed.applicant);
  await expect(page.locator('tbody tr')).toHaveCount(1);
  await page.locator('tbody tr').first().click();
  await expect(page.getByRole('tab', { name: 'نظرة عامة' })).toBeVisible();
  await expect(page.getByRole('button', { name: 'حظر' })).toBeVisible();
  await capture(page, '04-user-overview');
  await page.getByRole('tab', { name: 'المال' }).click();
  await expect(page.getByRole('heading', { name: 'آخر حركات العملات' })).toBeVisible();
  await capture(page, '05-user-money');
  await page.getByRole('tab', { name: 'الأجهزة والجلسات' }).click();
  await expect(page.getByRole('button', { name: 'تسجيل خروج الجهاز' }).first()).toBeVisible();
  await capture(page, '06-user-sessions');
  await page.getByRole('tab', { name: 'السجل' }).click();
  await expect(page.getByText('admin.user.view').first()).toBeVisible();
  await capture(page, '07-user-audit');

  if (v2) {
    // Agencies: list → detail.
    await go(page, 'الوكالات');
    await expect(page.locator('tbody tr')).toHaveCount(3);
    await capture(page, '08-agencies');
    await page.locator('tbody tr').first().click();
    await expect(page.getByRole('heading', { name: 'آخر ستة أشهر' })).toBeVisible();
    await capture(page, '09-agency-detail');

    // Lives now: open one and END LIVE with a reason.
    await go(page, 'البث الآن');
    await expect(page.locator('.live-card')).toHaveCount(6);
    await capture(page, '10-lives');
    await page.locator('.live-card', { hasText: seed.liveTitle! }).click();
    await page.getByRole('dialog').getByRole('button', { name: 'إنهاء البث' }).click();
    await page.getByLabel('السبب').fill('محتوى مخالف (اختبار)');
    await page.getByRole('dialog').getByRole('button', { name: 'إنهاء البث' }).click();
    await expect(page.locator('.live-card')).toHaveCount(5);

    // Gifts: create one.
    await go(page, 'الهدايا');
    await expect(page.locator('.gift-card')).toHaveCount(6);
    await page.getByRole('button', { name: 'إضافة هدية' }).click();
    const dlg = page.getByRole('dialog');
    await dlg.getByLabel('الرمز (حروف لاتينية صغيرة)').fill('smoke_star');
    await dlg.getByLabel('الاسم بالعربية').fill('نجمة');
    await dlg.getByLabel('الاسم بالإنجليزية').fill('Star');
    await dlg.getByLabel('السعر بالعملات').fill('520');
    await dlg.getByLabel('مفتاح الصورة').fill('gifts/star');
    await dlg.getByLabel('السبب').fill('هدية موسمية (اختبار)');
    await dlg.getByRole('button', { name: 'إضافة هدية' }).click();
    await expect(page.locator('.gift-card', { hasText: 'smoke_star' })).toBeVisible();
    await capture(page, '11-gifts');

    // Finance report.
    await go(page, 'التقرير المالي');
    await expect(page.locator('.report-table tbody tr')).toHaveCount(15);
    await capture(page, '12-finance-report');

    // Team: grant SUPPORT with the code again.
    await go(page, 'الفريق');
    await expect(page.locator('.member')).toHaveCount(3);
    await page.getByRole('button', { name: 'منح دور' }).click();
    await page.getByRole('dialog').getByLabel('البريد الإلكتروني').fill(seed.teamRecruit!);
    await page.getByRole('dialog').getByLabel('السبب').fill('انضم لفريق الدعم (اختبار)');
    await page.getByRole('dialog').getByLabel('رمز تطبيق المصادقة').fill(await freshCode(page, secret));
    await page.getByRole('dialog').getByRole('button', { name: 'منح دور' }).click();
    await expect(page.locator('.member')).toHaveCount(4);
    await capture(page, '13-team');

    // Audit viewer: filter by an action.
    await go(page, 'سجل التدقيق');
    await page.getByRole('combobox', { name: 'الإجراء' }).selectOption('admin.live.end');
    await expect(page.locator('tbody tr')).toHaveCount(1);
    await expect(page.getByText('محتوى مخالف (اختبار)')).toBeVisible();
    await page.getByRole('combobox', { name: 'الإجراء' }).selectOption('');
    await expect(page.locator('tbody tr').nth(3)).toBeVisible();
    await capture(page, '14-audit');
  }

  // Applications: approve (D191).
  await go(page, 'طلبات وكلاء الشحن');
  await expect(page.getByRole('cell', { name: /سارة محمد/ })).toBeVisible();
  await page.getByRole('cell', { name: /سارة محمد/ }).click();
  await expect(page.getByText('سارة محمد علي')).toBeVisible();
  await page.getByRole('button', { name: 'قبول' }).click();
  await expect(page.getByText('مقبول').first()).toBeVisible();

  // Withdrawals: mark paid with a reference and a fresh code (D191).
  await go(page, 'السحوبات');
  await expect(page.getByText('Vodafone Cash 0100 111 2223')).toBeVisible();
  await page.getByRole('button', { name: 'تأكيد الدفع' }).click();
  await page.getByLabel('مرجع الدفع (رقم التحويل)').fill('TX-20261031-01');
  await page.getByLabel('رمز تطبيق المصادقة').fill(await freshCode(page, secret));
  await page.getByRole('dialog').getByRole('button', { name: 'تأكيد الدفع' }).click();
  await expect(page.getByRole('dialog')).toHaveCount(0);

  // Reports queue.
  await go(page, 'البلاغات');
  await expect(page.getByText('يرسل روابط مزعجة')).toBeVisible();
  await capture(page, '15-reports');

  if (captureDir) {
    // Dark mode dashboard, then English, then mobile.
    await page.locator('.me-btn').click();
    await page.getByRole('button', { name: 'الوضع الداكن' }).click();
    await go(page, 'الرئيسية');
    await expect(page.locator('.kpi')).toHaveCount(5);
    await page.mouse.move(5, 5);
    await capture(page, '16-dark-dashboard');
    await go(page, 'البث الآن');
    await capture(page, '17-dark-lives');
    await page.locator('.me-btn').click();
    await page.getByRole('button', { name: 'الوضع الفاتح' }).click();
    await page.getByRole('button', { name: 'English' }).click();
    await page.locator('nav.nav').getByRole('link', { name: 'Home', exact: true }).click();
    await expect(page.locator('html')).toHaveAttribute('dir', 'ltr');
    await expect(page.locator('.kpi')).toHaveCount(5);
    await capture(page, '18-en-dashboard');
    await page.locator('.me-btn').click();
    await page.getByRole('button', { name: 'العربية' }).click();
    await page.setViewportSize({ width: 390, height: 844 });
    await page.getByRole('button', { name: 'القائمة' }).click();
    await capture(page, '19-mobile-menu');
    await page.locator('nav.nav').getByRole('link', { name: 'الرئيسية', exact: true }).click();
    await expect(page.locator('.kpi')).toHaveCount(5);
    await capture(page, '20-mobile-dashboard');
  }
  // The only expected one: the signed-out session probe at the first load (401 before sign-in).
  expect(errors.filter((e) => !e.includes('status of 401'))).toEqual([]);
  expect(errors.filter((e) => e.includes('status of 401')).length).toBeLessThanOrEqual(1);
});
