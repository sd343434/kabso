/**
 * D245 «أسعار الصرف» (automatic rates for every country) and the OWNER's «مزوّد أسعار الصرف» against the real API
 * (`SMOKE_FX=1 pnpm --filter @kabso/api smoke:admin-server test/smoke/fx-rates.smoke.ts`: the providers are a local
 * stub, a made-up key; one free fetch done, a manual EG rate, a held JPY value). Signs in and enrols, sees the status
 * card («آخر تحديث», the source, the attribution), searches, filters the held value, accepts it; in the provider
 * section types the key, «اختبار الاتصال», saves and turns it on with a reason and a fresh code, and sees the key as its
 * last 4 only. With KABSO_CAPTURE_DIR set it saves the captures (Arabic 1440×900, English, dark, phone 390×844).
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

test('«أسعار الصرف»: status, search, held value; «مزوّد أسعار الصرف»: test → save → on', async ({ page }) => {
  test.skip(!smokeFile, 'KABSO_SMOKE_FILE is not set (start the smoke API first)');
  const seed = JSON.parse(readFileSync(smokeFile, 'utf8')) as {
    fxOwner?: { email: string; password: string };
    fx?: { apiKey: string };
  };
  test.skip(!seed.fxOwner || !seed.fx, 'the smoke API was not started with SMOKE_FX=1');
  const apiKey = seed.fx!.apiKey;
  const errors: string[] = [];
  page.on('console', (m) => m.type() === 'error' && errors.push(m.text()));
  page.on('pageerror', (e) => errors.push(e.message));
  await page.setViewportSize({ width: 1440, height: 900 });

  await page.goto('/');
  await page.getByLabel('البريد الإلكتروني').fill(seed.fxOwner!.email);
  await page.getByLabel('كلمة المرور').fill(seed.fxOwner!.password);
  await page.getByRole('button', { name: 'دخول' }).click();
  await expect(page.getByRole('heading', { name: 'إعداد تطبيق المصادقة' })).toBeVisible();
  const secret = (await page.getByTestId('totp-secret').innerText()).trim();
  await page.getByLabel('رمز تطبيق المصادقة').fill(await freshCode(page, secret));
  await page.getByRole('button', { name: 'تحقق' }).click();
  await page.getByRole('button', { name: 'حفظتُ الرموز — متابعة' }).click();

  await page.locator('nav.nav').getByRole('link', { name: 'أسعار الصرف', exact: true }).click();
  await expect(page.getByRole('heading', { name: 'أسعار الصرف', level: 1 })).toBeVisible();
  await expect(page.getByTestId('fxr-last-update')).not.toHaveText('لم يتم بعد');
  await expect(page.getByTestId('fxr-attribution')).toContainText('Rates By Exchange Rate API');
  await expect(page.locator('tr[data-country]')).not.toHaveCount(0);
  expect(await page.locator('tr[data-country]').count()).toBeGreaterThanOrEqual(248);
  await expect(page.locator('tr[data-country="EG"] [data-testid="fxr-source"]')).toHaveText('يدوي');
  await expect(page.locator('tr[data-country="SA"] [data-testid="fxr-source"]')).toHaveText('تلقائي');
  await expect(page.locator('tr[data-country="FR"] [data-testid="fxr-source"]')).toHaveText('تلقائي');
  await capture(page, '01-ar-rates');

  await page.getByTestId('fxr-search').fill('مصر');
  await expect(page.locator('tr[data-country]')).toHaveCount(1);
  await capture(page, '02-ar-search-manual');
  await page.getByTestId('fxr-search').fill('');
  await page.getByRole('button', { name: 'معلّق للمراجعة', exact: true }).click();
  await expect(page.locator('tr[data-country]')).toHaveCount(1);
  await expect(page.locator('tr[data-country="JP"]')).toContainText('معلّق: 460');
  await capture(page, '03-ar-held');
  await page.locator('tr[data-country="JP"]').getByRole('button', { name: 'قبول السعر الجديد' }).click();
  const dialog = page.getByRole('dialog');
  await dialog.getByLabel('السبب').fill('تأكدت من البنك');
  await dialog.getByRole('button', { name: 'قبول السعر الجديد' }).click();
  await expect(page.getByRole('dialog')).toHaveCount(0, { timeout: 30_000 });
  await expect(page.locator('tr[data-country]')).toHaveCount(0);
  await page.getByRole('button', { name: 'الكل', exact: true }).click();

  // The OWNER's paid provider.
  const section = page.getByTestId('fxp-section');
  await section.scrollIntoViewIfNeeded();
  await expect(page.getByTestId('fxp-status')).toHaveText('غير مُعدّ — المصدر المجاني');
  await expect(page.getByTestId('fxp-enable')).toBeDisabled();
  if (captureDir) await section.screenshot({ path: join(captureDir, '04-ar-provider-not-configured.png') });
  await page.getByTestId('fxp-key').fill(apiKey);
  await page.getByTestId('fxp-test').click();
  await expect(page.getByTestId('fxp-result')).toContainText('نجح الاتصال');
  if (captureDir) await section.screenshot({ path: join(captureDir, '05-ar-provider-test-ok.png') });
  await page.getByTestId('fxp-save').click();
  await confirm(page, secret, 'مفتاح المزوّد المدفوع', 'حفظ');
  await expect(page.getByTestId('fxp-status')).toHaveText('متوقف — المصدر المجاني');
  await expect(page.getByTestId('fxp-key-saved')).toContainText(apiKey.slice(-4));
  await page.getByTestId('fxp-enable').click();
  await confirm(page, secret, 'تحديث كل دقيقة', 'تفعيل المزوّد المدفوع');
  await expect(page.getByTestId('fxp-status')).toHaveText('مفعّل — كل 60 ثانية');
  expect(await page.content()).not.toContain(apiKey);
  await page.mouse.move(5, 5);
  await expect(page.locator('.toast')).toHaveCount(0, { timeout: 6000 });
  if (captureDir) await section.screenshot({ path: join(captureDir, '06-ar-provider-active.png') });

  const menu = async (name: string) => {
    const button = page.getByRole('button', { name, exact: true });
    if (!(await page.locator('.me-menu').isVisible())) await page.locator('.me-btn').click();
    await button.click();
    if (await page.locator('.me-menu').isVisible()) await page.locator('.me-btn').click();
    await expect(page.locator('.me-menu')).toBeHidden();
  };
  // The poller (every 5 s on the smoke server) now reads the paid provider (the stub) every minute.
  await page.waitForTimeout(7000);
  await expect(async () => {
    await page.reload();
    await expect(page.getByTestId('fxr-status')).toContainText('currencyapi.com', { timeout: 2000 });
    await expect(page.getByTestId('fxr-status')).toContainText('كل 60 ثانية', { timeout: 2000 });
  }).toPass({ timeout: 30_000 });
  await page.evaluate(() => window.scrollTo(0, 0));
  await menu('English');
  await expect(page.locator('html')).toHaveAttribute('dir', 'ltr');
  await expect(page.locator('tr[data-country="EG"] [data-testid="fxr-source"]')).toHaveText('Manual');
  await page.mouse.move(5, 5);
  await capture(page, '07-en-rates');
  await menu('Dark mode');
  await page.mouse.move(5, 5);
  await capture(page, '08-en-dark-rates');
  await menu('Light mode');
  await menu('العربية');
  await page.setViewportSize({ width: 390, height: 844 });
  await expect(page.locator('html')).toHaveAttribute('dir', 'rtl');
  await page.mouse.move(5, 5);
  await capture(page, '09-ar-phone', 844);
  expect(errors.filter((e) => !e.includes('status of 401'))).toEqual([]);
});
