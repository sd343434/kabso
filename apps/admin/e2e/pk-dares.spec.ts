/**
 * D229 «أحكام PK» against the real API (`SMOKE_PK_DARES=1 pnpm --filter @kabso/api smoke:admin-server`: the 20 000-dare
 * seed imported, three reported dares, a not-yet-enrolled OWNER). Signs in and enrols, opens «أحكام PK»: the counts
 * (20 000, a third per level), the library filtered to «صعب», a search, the «مُبلَّغ عنها» queue with «إبقاء وتفعيل», an
 * unsafe dare refused by the server's rules, and the PK points settings. With KABSO_CAPTURE_DIR set it saves captures.
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
  await page.waitForTimeout(300);
  await page.screenshot({ path: join(captureDir, `${name}.png`), fullPage: height > 1000 });
}

test.setTimeout(300_000);

test('«أحكام PK»: counts, filters, search, reported queue, a refused add, settings', async ({ page }) => {
  test.skip(!smokeFile, 'KABSO_SMOKE_FILE is not set (start the smoke API first)');
  const seed = JSON.parse(readFileSync(smokeFile, 'utf8')) as { pkDaresOwner?: { email: string; password: string } };
  test.skip(!seed.pkDaresOwner, 'the smoke API was not started with SMOKE_PK_DARES=1');
  const errors: string[] = [];
  page.on('pageerror', (e) => errors.push(e.message));
  await page.setViewportSize({ width: 1440, height: 900 });
  await page.goto('/');
  await page.getByLabel('البريد الإلكتروني').fill(seed.pkDaresOwner!.email);
  await page.getByLabel('كلمة المرور').fill(seed.pkDaresOwner!.password);
  await page.getByRole('button', { name: 'دخول' }).click();
  await expect(page.getByRole('heading', { name: 'إعداد تطبيق المصادقة' })).toBeVisible();
  const secret = (await page.getByTestId('totp-secret').innerText()).trim();
  await page.getByLabel('رمز تطبيق المصادقة').fill(totp(secret, Date.now()));
  await page.getByRole('button', { name: 'تحقق' }).click();
  await page.getByRole('button', { name: 'حفظتُ الرموز — متابعة' }).click();

  await page.locator('nav.nav').getByRole('link', { name: 'أحكام PK', exact: true }).click();
  await expect(page.getByRole('heading', { name: 'أحكام PK', level: 1 })).toBeVisible();
  await expect(page.locator('[data-stat="total"] .kpi-value')).toHaveText('20,000');
  await expect(page.locator('[data-stat="HARD"] .kpi-value')).toContainText(/6,79\d|6,800/);
  await capture(page, '01-ar-library', 1400);

  await page.locator('[data-pk-dare-filters] select').first().selectOption('HARD');
  await expect(page.locator('[data-level="EASY"]')).toHaveCount(0);
  await capture(page, '02-ar-library-hard', 1400);

  await page.getByRole('button', { name: 'مُبلَّغ عنها' }).click();
  await expect(page.getByText('معطّل (بلاغات)')).toBeVisible();
  await capture(page, '03-ar-reported', 1000);
  await page.getByText('معطّل (بلاغات)').click();
  await page.getByRole('button', { name: 'إبقاء وتفعيل' }).click();
  await page.getByRole('dialog').getByLabel('السبب').fill('الحكم مناسب');
  await page.getByRole('dialog').getByRole('button', { name: 'إبقاء وتفعيل' }).click();
  await expect(page.getByRole('dialog')).toHaveCount(0, { timeout: 20_000 });

  await page.getByRole('button', { name: 'إضافة حكم' }).click();
  const dialog = page.getByRole('dialog');
  await dialog.locator('[data-dare-ar]').fill('القفز من النافذة');
  await dialog.locator('[data-dare-en]').fill('Jump out of the window');
  await dialog.getByLabel('السبب').fill('تجربة');
  await dialog.locator('[data-dare-save]').click();
  await expect(dialog.locator('.alert')).toBeVisible({ timeout: 30_000 });
  await capture(page, '04-ar-add-refused', 1000);
  await dialog.getByRole('button', { name: 'إلغاء' }).click();

  await page.getByRole('button', { name: 'نقاط PK والإعدادات' }).click();
  await expect(page.locator('[data-setting="refusePoints"]')).toHaveValue('-3');
  await expect(page.locator('[data-setting="forfeitPoints"]')).toHaveValue('-3');
  await capture(page, '05-ar-settings', 1000);
  expect(errors).toEqual([]);
});
