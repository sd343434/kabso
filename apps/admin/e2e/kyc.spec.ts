/**
 * D227 «التحقق من الهوية (Didit)» against the real API (`SMOKE_KYC=1 pnpm --filter @kabso/api smoke:admin-server`:
 * Didit faked behind its port, made-up keys, a not-yet-enrolled OWNER, a pending host application whose applicant has
 * an approved check, and another account with the same document). Signs in and enrols, sees «غير مُعدّ», types the
 * key, the webhook secret and the workflow, «اختبار الاتصال» (the key and the workflow pass), saves with a reason and a
 * fresh code, turns it on (tested again) and sees «مفعّل» with the secrets as last 4 only; then the host application's
 * page shows «التحقق من الهوية» (verified, the minimum, the duplicate account). With KABSO_CAPTURE_DIR set it saves the
 * owner's captures (Arabic light 1440×900, English, phone 390×844).
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

async function capture(page: Page, name: string, height = 900): Promise<void> {
  if (!captureDir) return;
  mkdirSync(captureDir, { recursive: true });
  const width = page.viewportSize()?.width ?? 1440;
  await page.setViewportSize({ width, height });
  await expect(page.locator('.toast')).toHaveCount(0, { timeout: 6000 });
  await page.waitForTimeout(200);
  await page.screenshot({ path: join(captureDir, `${name}.png`), fullPage: height > 1000 });
}

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

async function confirm(page: Page, secret: string, reason: string, button: string): Promise<void> {
  const dialog = page.getByRole('dialog');
  await dialog.getByLabel('السبب').fill(reason);
  await dialog.getByLabel('رمز تطبيق المصادقة').fill(await freshCode(page, secret));
  await dialog.getByRole('button', { name: button }).click();
  await expect(page.getByRole('dialog')).toHaveCount(0, { timeout: 30_000 });
}

test.setTimeout(420_000);

test('«التحقق من الهوية (Didit)»: not configured → test → save → on; the application page shows the check', async ({ page }) => {
  test.skip(!smokeFile, 'KABSO_SMOKE_FILE is not set (start the smoke API first)');
  const seed = JSON.parse(readFileSync(smokeFile, 'utf8')) as {
    kycOwner?: { email: string; password: string };
    didit?: { apiKey: string; webhookSecret: string; workflowId: string };
    hostApplicationId?: string;
  };
  test.skip(!seed.kycOwner || !seed.didit, 'the smoke API was not started with SMOKE_KYC=1');
  const didit = seed.didit!;
  const errors: string[] = [];
  page.on('console', (m) => m.type() === 'error' && errors.push(m.text()));
  page.on('pageerror', (e) => errors.push(e.message));
  await page.setViewportSize({ width: 1440, height: 900 });

  await page.goto('/');
  await page.getByLabel('البريد الإلكتروني').fill(seed.kycOwner!.email);
  await page.getByLabel('كلمة المرور').fill(seed.kycOwner!.password);
  await page.getByRole('button', { name: 'دخول' }).click();
  await expect(page.getByRole('heading', { name: 'إعداد تطبيق المصادقة' })).toBeVisible();
  const secret = (await page.getByTestId('totp-secret').innerText()).trim();
  await page.getByLabel('رمز تطبيق المصادقة').fill(await freshCode(page, secret));
  await page.getByRole('button', { name: 'تحقق' }).click();
  await page.getByRole('button', { name: 'حفظتُ الرموز — متابعة' }).click();

  await page.locator('nav.nav').getByRole('link', { name: 'التحقق من الهوية (Didit)', exact: true }).click();
  await expect(page.getByRole('heading', { name: 'التحقق من الهوية (Didit)', level: 1 })).toBeVisible();
  await expect(page.getByTestId('kyc-status')).toHaveText('غير مُعدّ');
  await expect(page.getByTestId('kyc-enable')).toBeDisabled();
  await expect(page.getByTestId('kyc-webhook-url')).toContainText('/api/v1/kyc/didit/webhook');
  await capture(page, '01-ar-not-configured', 1400);

  await page.getByLabel('مفتاح API', { exact: true }).fill(didit.apiKey);
  await page.getByLabel('سر الـ Webhook (Webhook Secret Key)').fill(didit.webhookSecret);
  await page.getByLabel('معرّف سير العمل الافتراضي (Workflow ID)').fill(didit.workflowId);
  await page.getByTestId('kyc-test').click();
  await expect(page.getByTestId('kyc-result')).toHaveText('الاتصال يعمل: المفتاح صحيح وكل سير عمل منشور.');
  await expect(page.locator('[data-testid="kyc-steps"] li.ok')).toHaveCount(2);
  await capture(page, '02-ar-test-ok', 1400);

  await page.getByTestId('kyc-save').click();
  await confirm(page, secret, 'تفعيل التحقق من الهوية للمتقدمين', 'حفظ');
  await expect(page.getByTestId('kyc-status')).toHaveText('متوقف');
  await expect(page.getByTestId('kyc-key-saved').first()).toContainText(didit.apiKey.slice(-4));
  await page.getByTestId('kyc-enable').click();
  await confirm(page, secret, 'تشغيل Didit', 'تفعيل التحقق من الهوية');
  await expect(page.getByTestId('kyc-status')).toHaveText('مفعّل');
  const html = await page.content();
  expect(html).not.toContain(didit.apiKey);
  expect(html).not.toContain(didit.webhookSecret);
  await capture(page, '03-ar-active', 1400);

  // The application page: «التحقق من الهوية» with the approved check and the duplicate account.
  await page.goto(`/host-applications/${seed.hostApplicationId}`);
  await expect(page.locator('[data-kyc-block]')).toBeVisible();
  await expect(page.locator('[data-kyc-gate]')).toHaveText('هوية مؤكدة');
  await expect(page.locator('[data-kyc-block]')).toContainText('NOURA AL SAUD');
  await expect(page.locator('[data-kyc-duplicate]')).toBeVisible();
  await capture(page, '04-ar-host-application-kyc', 1400);

  const menu = async (name: string) => {
    const button = page.getByRole('button', { name, exact: true });
    if (!(await page.locator('.me-menu').isVisible())) await page.locator('.me-btn').click();
    await button.click();
    if (await page.locator('.me-menu').isVisible()) await page.locator('.me-btn').click();
    await expect(page.locator('.me-menu')).toBeHidden();
  };
  await menu('English');
  await expect(page.locator('html')).toHaveAttribute('dir', 'ltr');
  await expect(page.locator('[data-kyc-gate]')).toHaveText('Identity verified');
  await page.mouse.move(5, 5);
  await capture(page, '05-en-host-application-kyc', 1400);
  await page.goto('/kyc-settings');
  await expect(page.getByTestId('kyc-status')).toHaveText('On');
  await page.mouse.move(5, 5);
  await capture(page, '06-en-active', 1400);
  await menu('Dark mode');
  await page.mouse.move(5, 5);
  await capture(page, '07-en-dark-active', 1400);
  await menu('Light mode');
  await menu('العربية');
  await page.setViewportSize({ width: 390, height: 844 });
  await expect(page.locator('html')).toHaveAttribute('dir', 'rtl');
  const scroll = await page.evaluate(() => document.documentElement.scrollWidth - document.documentElement.clientWidth);
  expect(scroll).toBeLessThanOrEqual(0);
  if (captureDir) {
    mkdirSync(captureDir, { recursive: true });
    await page.screenshot({ path: join(captureDir, '08-ar-phone-full.png'), fullPage: true });
  }
  expect(errors.filter((e) => !e.includes('status of 401'))).toEqual([]);
});
