/**
 * D356: the design step's option thumbnails are captures of the REAL page (the preview bundle), one per choice, made
 * here and committed as small WebP files in src/assets/event-design/ (thumbnails.py converts). Runs only with
 * KABSO_THUMBS_DIR set (the PNG output folder):
 *
 *   KABSO_THUMBS_DIR=/dev/shm/thumbs EVENT_PREVIEW_DIR=… pnpm exec playwright test -c playwright.preview.config.ts thumbnails
 *   python3 -I e2e-preview/thumbnails.py /dev/shm/thumbs src/assets/event-design
 *
 * Sample data only (the preview's sample leaderboard, Kabso's development photos); no event art.
 */
import { mkdirSync } from 'node:fs';
import { join } from 'node:path';
import { expect, test, type Page } from '@playwright/test';
import { DESIGN, sampleEvent } from './fixture';

const out = process.env.KABSO_THUMBS_DIR;
test.skip(!out, 'KABSO_THUMBS_DIR not set');

const ALL = ['GIFTS', 'RULES', 'BOARDS', 'REWARDS', 'MILESTONES'];
const order = (first: string[]) => [...first, ...ALL.filter((x) => !first.includes(x))].map((id) => ({ id, visible: true }));

type Shot = { name: string; design: Record<string, unknown>; clip: { y: number; height: number } };
const base = { ...DESIGN, countdown: 'CLASSIC', preset: 'CLASSIC', leaderboard: 'THRONE', rulesButton: { style: 'ROUND_ICON', edge: 'END' } };
const shots: Shot[] = [
  ...['HERO_PODIUM', 'STAGE', 'DECK'].map((v) => ({
    name: `layout-${v}`,
    design: { ...base, layout: v, sections: order(['BOARDS']) },
    clip: { y: 0, height: 852 },
  })),
  ...['THRONE', 'PODIUM', 'CARDS_ROW', 'SPOTLIGHT', 'SHIELD_CREST'].map((v) => ({
    name: `leaderboard-${v}`,
    design: { ...base, layout: 'STAGE', leaderboard: v, sections: order(['BOARDS']) },
    clip: { y: 340, height: 512 },
  })),
  ...['CLASSIC', 'FLIP', 'RING', 'COINS', 'NEON', 'RIBBON'].map((v) => ({
    name: `countdown-${v}`,
    design: { ...base, rulesButton: null, countdown: v },
    clip: { y: 40, height: 512 },
  })),
  ...['CLASSIC', 'LUXURY_GOLD', 'GLASS', 'DARK_MINIMAL', 'NEON', 'KABSO_RED'].map((v) => ({
    name: `preset-${v}`,
    design: { ...base, layout: 'STAGE', preset: v, sections: order(['GIFTS', 'RULES', 'REWARDS']) },
    clip: { y: 340, height: 512 },
  })),
  ...['NONE', 'EDGE_RIBBON', 'ROUND_ICON', 'GOLD_PILL', 'GLASS_CHIP', 'SIDE_TAB', 'APP_BAR_LINK'].map((v) => ({
    name: `rules-${v}`,
    design: { ...base, rulesButton: v === 'NONE' ? null : { style: v, edge: 'END' } },
    clip: { y: 0, height: 512 },
  })),
];

async function render(page: Page, design: unknown, seq: number) {
  await page.evaluate(
    (m) => (window as unknown as { __post: (m: unknown) => void }).__post(m),
    { type: 'kabso.eventPreview.render', v: 1, seq, language: 'ar', theme: 'dark', state: 'RUNNING', reduceMotion: true, event: sampleEvent(design) },
  );
  await expect
    .poll(() => page.evaluate((s) => (window as unknown as { __replies: { seq?: number }[] }).__replies.some((r) => r.seq === s), seq))
    .toBe(true);
}

test('option thumbnails from the real page', async ({ page }) => {
  test.setTimeout(600_000);
  mkdirSync(out!, { recursive: true });
  await page.goto('/__harness.html');
  await expect
    .poll(() => page.evaluate(() => (window as unknown as { __replies: unknown[] }).__replies.length), { timeout: 60_000 })
    .toBeGreaterThan(0);
  const box = (await page.locator('#preview').boundingBox())!;
  let seq = 0;
  for (const s of shots) {
    // A fresh page each time (no scroll or tab left over).
    await render(page, null, ++seq);
    await render(page, s.design, ++seq);
    await page.waitForTimeout(1500);
    await page.screenshot({
      path: join(out!, `${s.name}.png`),
      clip: { x: box.x, y: box.y + s.clip.y, width: 393, height: s.clip.height },
    });
  }
});
