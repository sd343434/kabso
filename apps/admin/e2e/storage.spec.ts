/**
 * D222 «التخزين (R2 / S3)» against the real API (`SMOKE_STORAGE=1 pnpm --filter @kabso/api smoke:admin-server`: no
 * server storage, a local S3-compatible server with a public and a private bucket, a not-yet-enrolled OWNER). Signs in
 * and enrols, sees «غير مُعدّ», fills the R2 form, then the local S3: «اختبار الاتصال» (every step passes), a wrong
 * public URL (the step and the reason in Arabic), saves with a reason and a fresh code, turns it on (tested again) and
 * sees «مفعّل» with the keys as last 4 only. With KABSO_CAPTURE_DIR set it saves the owner's captures (Arabic light
 * 1440×900, dark, English, phone 390×844).
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

test('«التخزين (R2 / S3)»: not configured → test → save → on, keys as last 4 only', async ({ page }) => {
  test.skip(!smokeFile, 'KABSO_SMOKE_FILE is not set (start the smoke API first)');
  const seed = JSON.parse(readFileSync(smokeFile, 'utf8')) as {
    storageOwner?: { email: string; password: string };
    s3?: { endpoint: string; accessKeyId: string; secretAccessKey: string; publicBucket: string; privateBucket: string; publicBaseUrl: string };
  };
  test.skip(!seed.storageOwner || !seed.s3, 'the smoke API was not started with SMOKE_STORAGE=1');
  const s3 = seed.s3!;
  const errors: string[] = [];
  page.on('console', (m) => m.type() === 'error' && errors.push(m.text()));
  page.on('pageerror', (e) => errors.push(e.message));
  await page.setViewportSize({ width: 1440, height: 900 });

  await page.goto('/');
  await page.getByLabel('البريد الإلكتروني').fill(seed.storageOwner!.email);
  await page.getByLabel('كلمة المرور').fill(seed.storageOwner!.password);
  await page.getByRole('button', { name: 'دخول' }).click();
  await expect(page.getByRole('heading', { name: 'إعداد تطبيق المصادقة' })).toBeVisible();
  const secret = (await page.getByTestId('totp-secret').innerText()).trim();
  await page.getByLabel('رمز تطبيق المصادقة').fill(await freshCode(page, secret));
  await page.getByRole('button', { name: 'تحقق' }).click();
  await page.getByRole('button', { name: 'حفظتُ الرموز — متابعة' }).click();

  await page.locator('nav.nav').getByRole('link', { name: 'التخزين (R2 / S3)', exact: true }).click();
  await expect(page.getByRole('heading', { name: 'التخزين (R2 / S3)', level: 1 })).toBeVisible();
  await expect(page.getByTestId('st-status')).toHaveText('غير مُعدّ');
  await expect(page.getByTestId('st-enable')).toBeDisabled();
  await capture(page, '01-ar-not-configured', 1400);

  // The R2 form (the default): the account id gives the endpoint.
  await page.getByLabel('معرّف حساب Cloudflare (Account ID)').fill('0123456789abcdef0123456789abcdef');
  await expect(page.getByText('https://0123456789abcdef0123456789abcdef.r2.cloudflarestorage.com')).toBeVisible();
  await page.getByLabel('الحاوية العامة', { exact: true }).fill('kabso-media');
  await page.getByLabel('الرابط العام للحاوية العامة').fill('https://media.kabsolive.com');
  await page.getByLabel('الحاوية الخاصة', { exact: true }).fill('kabso-private');
  await capture(page, '02-ar-r2-form', 1400);

  // The local S3-compatible server (the smoke stands in for R2): a real round trip with the production adapter.
  await page.getByLabel('المزوّد').selectOption('S3');
  await page.getByLabel('نقطة الاتصال (Endpoint)').fill(s3.endpoint);
  await page.getByLabel('المنطقة (Region)').fill('us-east-1');
  await page.getByLabel('مسار الحاوية في الرابط (path-style، لـ MinIO)').check();
  await page.getByLabel('معرّف مفتاح الوصول (Access Key ID)').fill(s3.accessKeyId);
  await page.getByLabel('المفتاح السري (Secret Access Key)').fill(s3.secretAccessKey);
  await page.getByLabel('الحاوية العامة', { exact: true }).fill(s3.publicBucket);
  await page.getByLabel('الرابط العام للحاوية العامة').fill(`${s3.endpoint}/${s3.privateBucket}`);
  await page.getByLabel('الحاوية الخاصة', { exact: true }).fill(s3.privateBucket);
  // First a wrong public URL (the private bucket's): the step and the reason in Arabic.
  await page.getByTestId('st-test').click();
  await expect(page.getByTestId('st-result')).toHaveText('فشل الاختبار. راجع الخطوة المعلّمة أدناه.');
  await expect(page.getByText('الرابط العام لا يعرض الحاوية العامة', { exact: false })).toBeVisible();
  await capture(page, '03-ar-test-failed', 1500);
  await page.getByLabel('الرابط العام للحاوية العامة').fill(s3.publicBaseUrl);
  await page.getByTestId('st-test').click();
  await expect(page.getByTestId('st-result')).toHaveText('نجح الاختبار: الحاويتان تعملان والرابط العام يعرض الحاوية العامة.');
  await expect(page.locator('.st-steps li.ok')).toHaveCount(10);
  await capture(page, '04-ar-test-ok', 1500);

  // Save (the code again + a reason), then turn it on (tested again by the server).
  await page.getByTestId('st-save').click();
  await confirm(page, secret, 'تخزين الوسائط على Cloudflare R2', 'حفظ');
  await expect(page.getByTestId('st-status')).toHaveText('متوقف');
  await expect(page.getByTestId('st-key-saved').first()).toContainText(`…${s3.accessKeyId.slice(-4)}`);
  await page.getByTestId('st-enable').click(); // controlled: the dialog decides
  await confirm(page, secret, 'تشغيل الرفع', 'تفعيل التخزين');
  await expect(page.getByTestId('st-status')).toHaveText('مفعّل');
  await expect(page.getByText('يعمل', { exact: true })).toBeVisible();
  const html = await page.content();
  expect(html).not.toContain(s3.secretAccessKey);
  expect(html).not.toContain(s3.accessKeyId);
  await capture(page, '05-ar-active', 1400);

  // Dark, English, phone (the admin menu may already be open after a choice).
  const menu = async (name: string) => {
    const button = page.getByRole('button', { name, exact: true });
    if (!(await page.locator('.me-menu').isVisible())) await page.locator('.me-btn').click();
    await button.click();
    // Close the menu (it would cover the page in the capture).
    if (await page.locator('.me-menu').isVisible()) await page.locator('.me-btn').click();
    await expect(page.locator('.me-menu')).toBeHidden();
  };
  await menu('الوضع الداكن');
  await page.mouse.move(5, 5);
  await capture(page, '06-ar-dark-active', 1400);
  await menu('English');
  await expect(page.locator('html')).toHaveAttribute('dir', 'ltr');
  await expect(page.getByTestId('st-status')).toHaveText('On');
  await page.mouse.move(5, 5);
  await capture(page, '07-en-dark-active', 1400);
  await menu('Light mode');
  await page.mouse.move(5, 5);
  await capture(page, '08-en-light-active', 1400);
  await menu('العربية');
  await page.setViewportSize({ width: 390, height: 844 });
  await expect(page.locator('html')).toHaveAttribute('dir', 'rtl');
  const scroll = await page.evaluate(() => document.documentElement.scrollWidth - document.documentElement.clientWidth);
  expect(scroll).toBeLessThanOrEqual(0);
  if (captureDir) {
    mkdirSync(captureDir, { recursive: true });
    await page.screenshot({ path: join(captureDir, '09-ar-phone.png'), fullPage: false });
    await page.screenshot({ path: join(captureDir, '10-ar-phone-full.png'), fullPage: true });
  }
  expect(errors.filter((e) => !e.includes('status of 401'))).toEqual([]);
});
