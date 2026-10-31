/**
 * D204: «نزاعات الشحن» against the smoke API (`pnpm --filter @kabso/api smoke:admin-server`, which takes a recharge
 * order to a dispute through the real API). A second OWNER signs in and enrols, opens the queue and the order (its
 * whole chat, the transfer screenshot through the audited endpoint), writes as «الإدارة», then opens «أسعار الصرف».
 * With KABSO_CAPTURE_DIR set it saves the owner's captures (Arabic, desktop 1440×900).
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
  await expect(page.locator('.toast')).toHaveCount(0, { timeout: 5000 });
  await page.waitForTimeout(200);
  await page.screenshot({ path: join(captureDir, `${name}.png`), fullPage: false });
}

test('«نزاعات الشحن»: the queue, the order chat, a «الإدارة» line, the exchange rates', async ({ page }) => {
  test.skip(!smokeFile, 'KABSO_SMOKE_FILE is not set (start the smoke API first)');
  const seed = JSON.parse(readFileSync(smokeFile, 'utf8')) as {
    disputeOwner?: { email: string; password: string };
    disputeOrderId?: string;
  };
  test.skip(!seed.disputeOwner, 'the smoke API has no D204 seed');
  const errors: string[] = [];
  page.on('console', (m) => m.type() === 'error' && errors.push(m.text()));
  page.on('pageerror', (e) => errors.push(e.message));
  await page.setViewportSize({ width: 1440, height: 900 });

  await page.goto('/');
  await page.getByLabel('البريد الإلكتروني').fill(seed.disputeOwner!.email);
  await page.getByLabel('كلمة المرور').fill(seed.disputeOwner!.password);
  await page.getByRole('button', { name: 'دخول' }).click();
  await expect(page.getByRole('heading', { name: 'إعداد تطبيق المصادقة' })).toBeVisible();
  const secret = (await page.getByTestId('totp-secret').innerText()).trim();
  await page.getByLabel('رمز تطبيق المصادقة').fill(totp(secret, Date.now()));
  await page.getByRole('button', { name: 'تحقق' }).click();
  await page.getByRole('button', { name: 'حفظتُ الرموز — متابعة' }).click();

  await page.getByRole('link', { name: 'نزاعات الشحن' }).click();
  await expect(page.getByRole('heading', { name: 'نزاعات الشحن', level: 1 })).toBeVisible();
  await expect(page.locator('tbody tr')).toHaveCount(1);
  await capture(page, 'admin-01-disputes');
  await page.locator('tbody tr').first().click();
  await expect(page.getByRole('heading', { name: 'طلب شحن', level: 1 })).toBeVisible();
  await expect(page.getByText('التحويل لم يصل إلى المحفظة')).toBeVisible();
  await expect(page.getByText('$25.00 · 1262.50 EGP')).toBeVisible();
  const proof = page.locator('img.chat-image');
  await expect(proof).toHaveCount(1);
  await expect.poll(() => proof.evaluate((img: HTMLImageElement) => img.naturalWidth)).toBeGreaterThan(0);
  await page.getByPlaceholder('اكتب للطرفين باسم «الإدارة»').fill('نراجع لقطة الشاشة مع الطرفين، يرجى إرسال فيديو الشاشة.');
  await page.getByRole('button', { name: 'إرسال' }).click();
  await expect(page.locator('.chat-line.admin')).toHaveCount(1);
  await expect(page.getByRole('button', { name: 'إضافة العملات للمشتري' })).toBeVisible();
  await capture(page, 'admin-02-dispute-chat');

  await page.getByRole('link', { name: 'أسعار الصرف' }).click();
  await expect(page.locator('tr[data-country="EG"]')).toContainText('50.5');
  await capture(page, 'admin-03-rates');
  // The first page load asks for the session before the sign-in (401 by design).
  expect(errors.filter((e) => !e.includes('status of 401'))).toEqual([]);
});
