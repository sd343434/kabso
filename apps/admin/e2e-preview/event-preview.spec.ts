/**
 * D356 (CONVENTIONS §10.152): the event page preview — the built Flutter-web bundle — on its own (the protocol) and in
 * the panel's design step (live updates, the fallback, the server's refusal at its field). The page's text is read
 * from Flutter's semantics DOM (the preview turns semantics on). With KABSO_CAPTURE_DIR set it saves the captures
 * (Arabic, 1440 × 900 and 393 × 852).
 */
import { mkdirSync } from 'node:fs';
import { join } from 'node:path';
import { expect, test, type Frame, type Page } from '@playwright/test';
import { DESIGN, render, sampleEvent } from './fixture';
import { BRIGHT_PNG, mockApi } from './mock-api';

const captureDir = process.env.KABSO_CAPTURE_DIR;

/** Every text the preview's semantics tree carries, joined. */
async function previewText(frame: Frame): Promise<string> {
  return frame.evaluate(() =>
    [...document.querySelectorAll('flt-semantics')]
      .map((n) => n.getAttribute('aria-label') ?? n.textContent ?? '')
      .join(' | '),
  );
}

async function untilText(frame: Frame, text: string | RegExp, timeout = 30_000) {
  await expect.poll(() => previewText(frame), { timeout }).toMatch(text);
}

const harnessReplies = (page: Page) => page.evaluate(() => (window as unknown as { __replies: { type: string }[] }).__replies);

test.describe('the preview bundle alone', () => {
  test('answers ready, draws a posted design, reports a bad message and ignores another type', async ({ page }) => {
    const errors: string[] = [];
    page.on('console', (m) => {
      if (/Unable to load asset|Refused to/.test(m.text())) errors.push(m.text());
    });
    await page.goto('/__harness.html');
    await expect.poll(() => harnessReplies(page), { timeout: 60_000 }).toContainEqual({ type: 'kabso.eventPreview.ready', v: 2 });
    const frame = page.frame({ url: /\/event-preview\// })!;
    const post = (m: unknown) => page.evaluate((x) => (window as unknown as { __post: (m: unknown) => void }).__post(x), m);

    await post(render({ seq: 1, language: 'ar', theme: 'dark', state: 'RUNNING', reduceMotion: true, event: sampleEvent(DESIGN) }));
    await expect.poll(() => harnessReplies(page)).toContainEqual({ type: 'kabso.eventPreview.rendered', v: 2, seq: 1, designed: true });
    await untilText(frame, /ملك الهدايا/);
    await untilText(frame, /بيانات المتصدرين تجريبية/);
    // The panel's sample rows (event-preview-sample.ts), read by the app's fromJson.
    await untilText(frame, /سارة/);
    // GOLD_PILL: the rules button under the countdown.
    await untilText(frame, /القواعد/);

    // English, ended, no design: today's page.
    await post(render({ seq: 2, language: 'en', theme: 'light', state: 'ENDED', reduceMotion: true, event: sampleEvent(null, false) }));
    await expect.poll(() => harnessReplies(page)).toContainEqual({ type: 'kabso.eventPreview.rendered', v: 2, seq: 2, designed: false });
    await untilText(frame, /Gift King/);
    await untilText(frame, /Preview · sample leaderboard data/);

    // An unknown design version is today's page too.
    await post(render({ seq: 3, language: 'ar', theme: 'dark', state: 'RUNNING', reduceMotion: true, event: sampleEvent({ ...DESIGN, v: 2 }) }));
    await expect.poll(() => harnessReplies(page)).toContainEqual({ type: 'kabso.eventPreview.rendered', v: 2, seq: 3, designed: false });

    // A broken event: an error reply, the last page stays.
    await post(render({ seq: 4, event: { title: 5 } }));
    await expect.poll(() => harnessReplies(page)).toContainEqual(expect.objectContaining({ type: 'kabso.eventPreview.error', seq: 4 }));
    await untilText(frame, /ملك الهدايا/);
    // Protocol v1 (boards made in the app) is refused.
    await post({ type: 'kabso.eventPreview.render', v: 1, seq: 5, event: sampleEvent(DESIGN) });
    await expect.poll(() => harnessReplies(page)).toContainEqual(expect.objectContaining({ type: 'kabso.eventPreview.error', seq: 5 }));
    // Another message type: nothing at all.
    const before = (await harnessReplies(page)).length;
    await post({ type: 'something.else', v: 1 });
    await page.waitForTimeout(500);
    expect((await harnessReplies(page)).length).toBe(before);
    expect(errors).toEqual([]);
  });
});

async function capture(page: Page, name: string) {
  if (!captureDir) return;
  mkdirSync(captureDir, { recursive: true });
  await page.waitForTimeout(1200);
  await page.screenshot({ path: join(captureDir, `${name}.png`) });
}

async function openDesignStep(page: Page) {
  await page.goto('/events');
  await page.getByRole('button', { name: 'تعديل' }).first().click();
  await page.locator('.ev-step', { hasText: 'التصميم' }).click();
  const preview = page.getByTestId('dsg-preview');
  await expect(preview).toHaveAttribute('data-preview-status', 'ready', { timeout: 60_000 });
  const frame = page.frame({ url: /\/event-preview\// })!;
  return { preview, frame };
}

test.describe('the design step', () => {
  test('the real preview follows the fields', async ({ page }) => {
    await page.setViewportSize({ width: 1440, height: 900 });
    await mockApi(page);
    const { preview, frame } = await openDesignStep(page);
    await expect(preview).toHaveAttribute('data-preview-designed', 'true', { timeout: 30_000 });
    await untilText(frame, /ملك الهدايا/);
    await capture(page, 'ar.1440.1-heroPodium-flip-luxuryGold');

    // STAGE + CARDS_ROW + RING + GLASS + a round rules icon.
    await page.locator('[data-picker="layout"] [data-value="STAGE"]').click();
    await page.locator('[data-picker="leaderboard"] [data-value="CARDS_ROW"]').click();
    await page.locator('[data-picker="countdown"] [data-value="RING"]').click();
    await page.locator('[data-picker="preset"] [data-value="GLASS"]').click();
    await page.locator('[data-picker="rules"] [data-value="ROUND_ICON"]').click();
    // A light leaderboard background: «قد يصعب قراءة النص» (a warning; saving stays possible).
    await page.locator('#dsg-bg').setInputFiles({ name: 'board.png', mimeType: 'image/png', buffer: BRIGHT_PNG });
    await expect(page.getByTestId('dsg-contrast')).toBeVisible();
    await expect(page.getByTestId('dsg-contrast').locator('[data-where="board"]')).toBeVisible();
    await page.locator('[data-picker="layout"]').scrollIntoViewIfNeeded();
    await page.waitForTimeout(1500);
    await capture(page, 'ar.1440.2-stage-cardsRow-ring-glass-board');
    // The page scrolled to its leaderboard (over the light background) and the form at the warning.
    if (captureDir) {
      await page.getByTestId('dsg-contrast').scrollIntoViewIfNeeded();
      const box = (await page.locator('.dsg-phone iframe').boundingBox())!;
      await page.mouse.move(box.x + box.width / 2, box.y + box.height / 2);
      await page.mouse.wheel(0, 700);
      await capture(page, 'ar.1440.2b-board-background-contrast-warning');
      await page.mouse.wheel(0, -3000);
    }

    // DECK + PODIUM + RIBBON + KABSO_RED, rewards first, English in the preview.
    await page.locator('[data-picker="layout"] [data-value="DECK"]').click();
    await page.locator('[data-picker="leaderboard"] [data-value="PODIUM"]').click();
    await page.locator('[data-picker="countdown"] [data-value="RIBBON"]').click();
    await page.locator('[data-picker="preset"] [data-value="KABSO_RED"]').click();
    await page.locator('[data-section="REWARDS"] button[aria-label="إلى الأعلى"]').click();
    await page.locator('[data-section="REWARDS"] button[aria-label="إلى الأعلى"]').click();
    await page.getByTestId('dsg-preview').locator('select').first().selectOption('en');
    await untilText(frame, /Gift King/);
    await page.getByTestId('dsg-sections').scrollIntoViewIfNeeded();
    await capture(page, 'ar.1440.3-deck-podium-ribbon-kabsoRed-rewardsFirst-en');

    // The designer off: today's page.
    await page.locator('#dsg-use').uncheck();
    await expect(preview).toHaveAttribute('data-preview-designed', 'false', { timeout: 30_000 });
  });

  test('a design refusal from the server shows at its field', async ({ page }) => {
    await page.setViewportSize({ width: 1440, height: 900 });
    const api = await mockApi(page);
    await openDesignStep(page);
    api.refuse = [{ field: 'design.rewards.tiers.0', issue: 'design_tier_prize' }];
    await page.locator('.ev-step', { hasText: 'المراجعة' }).click();
    await page.locator('#ev-reason').fill('preview test');
    await page.getByRole('button', { name: 'حفظ التعديلات' }).click();
    await expect(page.locator('.ev-body')).toHaveAttribute('data-step', 'evStepDesign');
    await expect(page.locator('[data-tier="0"] .dsg-issues')).toContainText('سطر جوائز واحد');
    expect(api.saves[0]).toMatchObject({ design: { v: 1, layout: 'HERO_PODIUM', preset: 'LUXURY_GOLD' } });
  });

  test('the phone: the design step at 393 wide', async ({ page }) => {
    await page.setViewportSize({ width: 393, height: 852 });
    await mockApi(page);
    const { frame } = await openDesignStep(page);
    await untilText(frame, /ملك الهدايا/);
    if (captureDir) {
      mkdirSync(captureDir, { recursive: true });
      await page.waitForTimeout(1200);
      await page.screenshot({ path: join(captureDir, 'ar.393.design-step.png') });
      await page.getByTestId('dsg-preview').scrollIntoViewIfNeeded();
      await page.waitForTimeout(800);
      await page.screenshot({ path: join(captureDir, 'ar.393.design-step-preview.png') });
    }
  });

  test('the sketch preview when the bundle does not answer', async ({ page }) => {
    await page.setViewportSize({ width: 1440, height: 900 });
    await mockApi(page);
    await page.route('**/event-preview/**', (route) => route.fulfill({ status: 404, body: 'gone' }));
    await page.clock.install();
    await page.goto('/events');
    await page.getByRole('button', { name: 'تعديل' }).first().click();
    await page.locator('.ev-step', { hasText: 'التصميم' }).click();
    await page.clock.runFor(25_000);
    await expect(page.getByTestId('dsg-preview')).toHaveAttribute('data-preview-status', 'failed');
    await expect(page.locator('.dsg-preview-fallback .gev-preview')).toBeVisible();
  });
});

