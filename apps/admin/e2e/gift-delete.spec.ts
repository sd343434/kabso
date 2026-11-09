/**
 * D338 «حذف» of a gift: the real panel against the gift smoke API (`SMOKE_GIFTS=1 pnpm --filter @kabso/api
 * smoke:admin-server`: a not-yet-enrolled OWNER, a gift never used, one held in a bag, one already archived). Signs in,
 * opens «الهدايا», deletes the unused gift for good, moves the held one to «المحذوفة», and restores the old one from the
 * «المحذوفة» filter. With KABSO_CAPTURE_DIR set it saves the Arabic captures (1440 × 900).
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
  await page.waitForTimeout(200);
  await page.screenshot({ path: join(captureDir, `${name}.png`) });
}

test.setTimeout(300_000);

test('«الهدايا»: «حذف» deletes an unused gift, archives a used one, «استعادة» brings one back', async ({ page }) => {
  test.skip(!smokeFile, 'KABSO_SMOKE_FILE is not set (start the gift smoke API first)');
  const seed = JSON.parse(readFileSync(smokeFile, 'utf8')) as { email: string; password: string };
  const errors: string[] = [];
  page.on('pageerror', (e) => errors.push(e.message));
  await page.setViewportSize({ width: 1440, height: 900 });
  await page.goto('/');
  await expect(page.locator('html')).toHaveAttribute('dir', 'rtl');
  await page.getByLabel('البريد الإلكتروني').fill(seed.email);
  await page.getByLabel('كلمة المرور').fill(seed.password);
  await page.getByRole('button', { name: 'دخول' }).click();
  await expect(page.getByRole('heading', { name: 'إعداد تطبيق المصادقة' })).toBeVisible();
  const secret = (await page.getByTestId('totp-secret').innerText()).trim();
  await page.getByLabel('رمز تطبيق المصادقة').fill(totp(secret, Date.now()));
  await page.getByRole('button', { name: 'تحقق' }).click();
  await page.getByRole('button', { name: 'حفظتُ الرموز — متابعة' }).click();

  await page.goto('/gifts');
  await expect(page.locator('[data-gift-card]')).toHaveCount(3);
  await expect(page.locator('[data-gift-archived-filter]')).toContainText('المحذوفة (1)');
  await capture(page, '01-gifts-list-ar');

  // Never used: deleted for good.
  await page.locator('[data-gift-delete="smoke_new"]').click();
  const dialog = page.getByRole('dialog');
  await expect(dialog.locator('[data-gift-delete-case="delete"]')).toContainText('ستُحذف نهائياً');
  await dialog.locator('textarea, input[type=text]').first().fill('أُضيفت بالخطأ');
  await capture(page, '02-delete-forever-dialog-ar');
  await dialog.getByRole('button', { name: 'حذف نهائياً' }).click();
  await expect(page.locator('[data-gift-card="smoke_new"]')).toHaveCount(0);

  // Held in a bag: moved to «المحذوفة».
  await page.locator('[data-gift-delete="smoke_held"]').click();
  // Owner: the pieces in bags stay until they are used.
  await expect(dialog.locator('[data-gift-delete-case="archive"]')).toContainText(
    'ستختفي من المتجر، وتبقى 3 قطعة في حقائب 1 مستخدمين حتى تُستخدم',
  );
  await dialog.locator('textarea, input[type=text]').first().fill('لم تعد مطلوبة');
  await capture(page, '03-delete-archive-dialog-ar');
  await dialog.getByRole('button', { name: 'نقل إلى المحذوفة' }).click();
  await expect(page.locator('[data-gift-card="smoke_held"]')).toHaveCount(0);
  await expect(page.locator('[data-gift-archived-filter]')).toContainText('المحذوفة (2)');
  await capture(page, '04-after-delete-ar');

  // «المحذوفة»: only the archived ones, with «استعادة».
  await page.locator('[data-gift-archived-filter]').click();
  await expect(page.locator('[data-gift-card]')).toHaveCount(2);
  await expect(page.locator('[data-gift-archived="smoke_held"]')).toContainText('محذوفة');
  await expect(page.locator('[data-gift-archived="smoke_held"]')).toContainText('تبقى 3 قطعة في حقائب 1 مستخدمين');
  await expect(page.locator('[data-gift-archived="smoke_old"]')).toContainText('تبقى 1 قطعة في حقائب 1 مستخدمين');
  await capture(page, '05-archived-filter-ar');
  await page.locator('[data-gift-restore="smoke_old"]').click();
  await dialog.locator('textarea, input[type=text]').first().fill('عادت للفعالية');
  await capture(page, '06-restore-dialog-ar');
  await dialog.getByRole('button', { name: 'استعادة' }).click();
  await expect(page.locator('[data-gift-card]')).toHaveCount(1);
  await page.locator('[data-gift-archived-filter]').click();
  await expect(page.locator('[data-gift-card="smoke_old"]')).toHaveCount(1);
  await capture(page, '07-restored-ar');
  expect(errors).toEqual([]);
});
