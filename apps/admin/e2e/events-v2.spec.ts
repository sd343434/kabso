/**
 * D325 «الفعاليات» (events v2): the real panel against the events smoke API (`SMOKE_EVENTS=1 pnpm --filter @kabso/api
 * smoke:admin-server`: a not-yet-enrolled OWNER, «مهرجان انطلاقة Kabso» as a draft, a weekly event, an older D166 event).
 * Signs in and enrols, opens «الفعاليات», checks the list (draft without dates, weekly, the older event), opens the
 * festival draft and walks the eight steps of the editor. With KABSO_CAPTURE_DIR set it saves the Arabic captures
 * (1440 × 900) and the English list.
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

async function capture(page: Page, name: string, fullPage = false): Promise<void> {
  if (!captureDir) return;
  mkdirSync(captureDir, { recursive: true });
  await page.waitForTimeout(200);
  await page.screenshot({ path: join(captureDir, `${name}.png`), fullPage });
}

test.setTimeout(300_000);

test('«الفعاليات»: the list, the festival draft and the eight steps of the editor', async ({ page }) => {
  test.skip(!smokeFile, 'KABSO_SMOKE_FILE is not set (start the events smoke API first)');
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

  await page.locator('nav.nav').getByRole('link', { name: 'الفعاليات', exact: true }).click();
  await expect(page.getByRole('heading', { name: 'الفعاليات', level: 1 })).toBeVisible();
  const table = page.locator('table.events-v2');
  await expect(table.locator('tbody tr')).toHaveCount(3);
  await expect(table).toContainText('مهرجان انطلاقة Kabso');
  await expect(table).toContainText('بلا موعد بعد');
  await expect(table).toContainText('أسبوعية');
  await expect(table).toContainText('فعالية قديمة');
  await capture(page, '01-events-list-ar');

  await table.locator('tr', { hasText: 'مهرجان انطلاقة Kabso' }).getByRole('button', { name: 'متابعة التجهيز' }).click();
  const dialog = page.getByRole('dialog');
  await expect(dialog.locator('.ev-step')).toHaveCount(8);
  const steps = [
    ['02-step-basics', 'العنوان والقواعد'],
    ['03-step-time', 'الوقت والتكرار'],
    ['04-step-audience', 'الجمهور والنقاط'],
    ['05-step-gifts', 'هدايا الفعالية'],
    ['06-step-boards', 'اللوحات والجوائز'],
    ['07-step-milestones', 'المراحل'],
    ['08-step-design', 'التصميم'],
    ['09-step-review', 'المراجعة والنشر'],
  ] as const;
  for (const [name, label] of steps) {
    await dialog.locator('.ev-steps').getByRole('button', { name: label }).click();
    await expect(dialog.locator('.ev-step.on')).toContainText(label);
    await capture(page, name);
  }
  // The festival's gifts and multipliers are there; a draft without dates cannot be published yet.
  await dialog.locator('.ev-steps').getByRole('button', { name: 'هدايا الفعالية' }).click();
  await expect(dialog.locator('.gev-gift')).toHaveCount(4);
  await expect(dialog.locator('.gev-gift input[type=number]').nth(3)).toHaveValue('1.5');
  await dialog.locator('.ev-steps').getByRole('button', { name: 'المراجعة والنشر' }).click();
  await expect(dialog.getByRole('button', { name: 'حفظ ونشر' })).toBeDisabled();
  await page.keyboard.press('Escape');

  // English: the same list, left to right.
  const english = page.getByRole('button', { name: 'English' });
  if ((await english.count()) > 0) {
    await english.first().click();
    await expect(page.locator('html')).toHaveAttribute('dir', 'ltr');
    await expect(page.getByRole('heading', { name: 'Events', level: 1 })).toBeVisible();
    await capture(page, '10-events-list-en');
  }
  expect(errors).toEqual([]);
});
