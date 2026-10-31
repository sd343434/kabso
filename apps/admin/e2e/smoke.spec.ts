/**
 * D191: one smoke run of the real admin panel against a local API (`pnpm --filter @kabso/api smoke:admin-server`,
 * which seeds a not-yet-enrolled OWNER and writes its credentials to KABSO_SMOKE_FILE). Signs in, enrols the
 * authenticator from the page's own secret (codes generated here, RFC 6238), then the dashboard, a user search and
 * profile, an application's approval and a withdrawal marked paid. With KABSO_CAPTURE_DIR set it also saves the
 * owner's review captures (Arabic; desktop 1440×900 and one mobile 390×844; private pictures blurred).
 */
import { createHmac, randomBytes } from 'node:crypto';
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

test('admin panel smoke: sign-in with TOTP, dashboard, users, approve, mark paid', async ({ page }) => {
  test.skip(!smokeFile, 'KABSO_SMOKE_FILE is not set (start the smoke API first)');
  const seed = JSON.parse(readFileSync(smokeFile, 'utf8')) as { email: string; password: string; applicant: string };
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
  await expect(page.getByRole('img', { name: 'إعداد تطبيق المصادقة' })).toBeVisible();
  const secret = (await page.getByTestId('totp-secret').innerText()).trim();
  expect(secret).toMatch(/^[A-Z2-7]{32}$/);
  await capture(page, '02-totp-enrol');
  const enrolAt = Date.now();
  await page.getByLabel('رمز تطبيق المصادقة').fill(totp(secret, enrolAt));
  await page.getByRole('button', { name: 'تحقق' }).click();
  await expect(page.getByTestId('recovery-codes').locator('code')).toHaveCount(10);
  await page.getByRole('button', { name: 'حفظتُ الرموز — متابعة' }).click();

  // Dashboard: real numbers (one pending application, one withdrawal, two reports from the seed).
  await expect(page.getByRole('heading', { name: 'الرئيسية', level: 1 })).toBeVisible();
  await expect(page.getByText('طلبات وكلاء', { exact: true }).locator('..').getByText('1', { exact: true })).toBeVisible();
  await capture(page, '03-dashboard');

  // Users: search and profile.
  await page.getByRole('link', { name: 'المستخدمون' }).click();
  await page.getByRole('searchbox').fill(seed.applicant);
  await page.getByRole('button', { name: 'بحث' }).click();
  await expect(page.getByRole('cell', { name: new RegExp(`@${seed.applicant}`) })).toBeVisible();
  await capture(page, '04-users');
  await page.getByRole('cell', { name: new RegExp(`@${seed.applicant}`) }).click();
  await expect(page.getByText('اسم المستخدم الأساسي')).toBeVisible();
  await expect(page.getByRole('button', { name: 'حظر' })).toBeVisible();
  await capture(page, '05-user-detail');

  // Applications: list, detail (pictures fetched on request, audited), approve.
  await page.getByRole('link', { name: 'طلبات وكلاء الشحن' }).click();
  await expect(page.getByRole('cell', { name: /سارة محمد/ })).toBeVisible();
  await capture(page, '06-applications');
  await page.getByRole('cell', { name: /سارة محمد/ }).click();
  await expect(page.getByText('سارة محمد علي')).toBeVisible();
  await page.getByRole('button', { name: 'عرض الصورة (يُسجَّل)' }).first().click();
  await expect(page.locator('[data-private-photo="photo"] img')).toBeVisible();
  await page.getByRole('button', { name: 'عرض الصورة (يُسجَّل)' }).first().click();
  await expect(page.locator('[data-private-photo="selfie"] img')).toBeVisible();
  await capture(page, '07-application-detail');
  await page.getByRole('button', { name: 'قبول' }).click();
  await expect(page.getByText('مقبول').first()).toBeVisible();

  // Agents: the top-up dialog with the live tier price (cancelled: the smoke does not top up).
  await page.getByRole('link', { name: 'وكلاء الشحن', exact: true }).click();
  await page.getByRole('button', { name: 'شحن مخزون' }).first().click();
  await page.getByLabel('عدد العملات').fill('30000000');
  await expect(page.getByLabel('المبلغ المدفوع (USD)')).toHaveValue('360.00');
  await capture(page, '08-agent-topup-dialog');
  await page.getByRole('button', { name: 'إلغاء' }).click();

  // Withdrawals: mark paid with a reference and a fresh code (the next 30-second step).
  await page.getByRole('link', { name: 'السحوبات' }).click();
  await expect(page.getByText('Vodafone Cash 0100 111 2223')).toBeVisible();
  await capture(page, '09-withdrawals');
  await page.getByRole('button', { name: 'تأكيد الدفع' }).click();
  await page.getByLabel('مرجع الدفع (رقم التحويل)').fill('TX-20261031-01');
  const paidAt = Math.max(Date.now(), enrolAt + 30_000);
  await page.getByLabel('رمز تطبيق المصادقة').fill(totp(secret, paidAt));
  await page.getByRole('dialog').getByRole('button', { name: 'تأكيد الدفع' }).click();
  await expect(page.getByRole('dialog')).toHaveCount(0);
  await expect(page.getByText('لا توجد نتائج.')).toBeVisible();

  // Reports: the queue with previews.
  await page.getByRole('link', { name: 'البلاغات' }).click();
  await expect(page.getByText('يرسل روابط مزعجة')).toBeVisible();
  await capture(page, '10-reports');

  // D196 «الدفع (Stripe)»: enter the keys (made up; the smoke API's Stripe is a fake), test, save with a reason and a
  // fresh code; afterwards the page shows only their type and last 4 characters.
  await page.getByRole('link', { name: 'الدفع (Stripe)' }).click();
  await expect(page.getByRole('heading', { name: 'الدفع (Stripe)', level: 1 })).toBeVisible();
  await expect(page.getByTestId('pay-status')).toHaveText('غير مفعّل');
  await expect(page.locator('#pay-url')).toHaveValue('https://api.kabsolive.com/api/v1/payments/stripe/webhook');
  const sk = ['rk', 'live', `${randomBytes(12).toString('hex')}Kb7Q`].join('_');
  const wh = ['whsec', `${randomBytes(12).toString('hex')}Ws3e`].join('_');
  await page.getByLabel('مفتاح سري جديد').fill(sk);
  await page.getByRole('button', { name: 'اختبار الاتصال' }).click();
  await expect(page.getByText(/Stripe قبِل المفتاح/)).toBeVisible();
  await page.getByLabel('سرّ توقيع جديد').fill(wh);
  await page.getByRole('button', { name: 'حفظ المفاتيح' }).click();
  await page.getByRole('dialog').getByLabel('السبب').fill('مفاتيح الإطلاق من لوحة Stripe');
  // A step after the withdrawal's code (each step works once).
  const lastStep = Math.floor(paidAt / 30_000);
  while (Math.floor((Date.now() + 30_000) / 30_000) <= lastStep) await page.waitForTimeout(1000);
  await page.getByLabel('رمز تطبيق المصادقة').fill(totp(secret, Math.max(Date.now(), (lastStep + 1) * 30_000)));
  await page.getByRole('dialog').getByRole('button', { name: 'حفظ' }).click();
  await expect(page.getByRole('dialog')).toHaveCount(0);
  await expect(page.getByTestId('pay-status')).toHaveText('مفعّل — وضع حقيقي');
  await expect(page.getByText('…Kb7Q')).toBeVisible();
  await expect(page.getByText('…Ws3e')).toBeVisible();
  expect(await page.content()).not.toContain(sk);
  expect(await page.content()).not.toContain(wh);
  await page.setViewportSize({ width: 1440, height: 1340 });
  await capture(page, '12-payments');
  await page.setViewportSize({ width: 1440, height: 900 });

  if (captureDir) {
    await page.setViewportSize({ width: 390, height: 844 });
    await page.getByRole('button', { name: 'menu' }).click();
    await page.getByRole('link', { name: 'الرئيسية' }).click();
    await expect(page.getByRole('heading', { name: 'الرئيسية', level: 1 })).toBeVisible();
    await capture(page, '11-mobile-dashboard');
  }
  // The only expected one: the signed-out session probe at the first load (401 before sign-in).
  expect(errors.filter((e) => !e.includes('status of 401'))).toEqual([]);
  expect(errors.filter((e) => e.includes('status of 401')).length).toBeLessThanOrEqual(1);
});
