/**
 * «استوديو البث» end to end (D247): the real studio page against the local API (apps/api test/smoke/studio.smoke.ts)
 * and a real LiveKit server, in Chromium with fake media devices and an auto-picked screen. A viewer
 * (apps/api test/smoke/studio-viewer.ts, @livekit/rtc-node) subscribes and checks what arrives. OBS Virtual Camera is
 * SIMULATED: an init script lists Chromium's fake camera a second time under the label «OBS Virtual Camera» (no real
 * OBS here). Captures go to KABSO_STUDIO_CAPTURES when it is set.
 *
 * Needs: KABSO_STUDIO_SMOKE (the smoke server's JSON), KABSO_STUDIO_URL (the preview), KABSO_API_DIR (apps/api, for
 * the viewer script), and optionally KABSO_SITE_DIR (infra/deploy/site) for the website captures.
 */
import { spawn, type ChildProcess } from 'node:child_process';
import { existsSync, mkdirSync, readFileSync, rmSync } from 'node:fs';
import { join } from 'node:path';
import { expect, test, type Page } from '@playwright/test';

interface Smoke {
  port: number;
  livekit: string | null;
  host: { email: string; password: string; username: string; token: string };
  noHost: { email: string; password: string };
  viewer: { email: string; password: string; token: string; username: string };
  giftCode: string;
}
interface ViewerState {
  connected: boolean;
  tracks: Record<string, { frames: number; kind: string; muted: boolean; width?: number; height?: number; peak?: number }>;
  streamerMessages: { main: string; cameraOverlay: { corner: string; visible: boolean }; version: number }[];
  chat: { status: number; code: string | null } | null;
  gift: { status: number; code: string | null } | null;
  error: string | null;
}

const smokeFile = process.env.KABSO_STUDIO_SMOKE ?? '';
const apiDir = process.env.KABSO_API_DIR ?? '';
const captures = process.env.KABSO_STUDIO_CAPTURES ?? '';
const siteDir = process.env.KABSO_SITE_DIR ?? '';
const smoke = (): Smoke => JSON.parse(readFileSync(smokeFile, 'utf8')) as Smoke;
const apiBase = () => `http://127.0.0.1:${smoke().port}`;

const SIZES = [
  { width: 1440, height: 900 },
  { width: 1280, height: 800 },
];

/** Chromium's fake camera listed again as «OBS Virtual Camera» (a simulation: no OBS in this environment). */
const OBS_SIMULATION = `(() => {
  const md = navigator.mediaDevices;
  if (!md) return;
  const enumerate = md.enumerateDevices.bind(md);
  const gum = md.getUserMedia.bind(md);
  md.enumerateDevices = async () => {
    const list = await enumerate();
    const labelled = list.some((d) => d.label);
    if (!labelled) return list;
    const obs = { deviceId: 'obs-virtual-camera', groupId: 'obs', kind: 'videoinput', label: 'OBS Virtual Camera', toJSON() { return this; } };
    return [...list, obs];
  };
  md.getUserMedia = (c) => {
    const v = c && c.video;
    const id = v && typeof v === 'object' && v.deviceId && (v.deviceId.exact || v.deviceId);
    if (id === 'obs-virtual-camera') return gum({ ...c, video: { width: v.width, height: v.height, frameRate: v.frameRate } });
    return gum(c);
  };
})();`;

async function api<T>(method: string, path: string, token: string | null, body?: unknown): Promise<{ status: number; body: T }> {
  const res = await fetch(`${apiBase()}/api/v1${path}`, {
    method,
    headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}) },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  return { status: res.status, body: (await res.json().catch(() => null)) as T };
}

/** A fresh access token (the smoke file's tokens are 15-minute ones). */
async function tokenOf(who: { email: string; password: string }): Promise<string> {
  const res = await api<{ tokens: { accessToken: string } }>('POST', '/auth/login', null, {
    identifier: who.email,
    password: who.password,
  });
  expect(res.status).toBe(200);
  return res.body.tokens.accessToken;
}

/** Ends a live the host left on air in an earlier run (the studio would offer to continue it). */
async function endLeftoverLive(): Promise<void> {
  const s = smoke();
  const token = await tokenOf(s.host);
  const profile = await api<{ liveRoomId?: string }>('GET', `/users/${s.host.username}`, token);
  if (profile.body.liveRoomId) await api('POST', `/live/rooms/${profile.body.liveRoomId}/end`, token);
}

async function setLook(page: Page, lang: 'ar' | 'en', theme: 'light' | 'dark') {
  // dispatchEvent: the header's toggles work under an open dialog too (the capture of the end confirmation).
  if ((await page.evaluate(() => document.documentElement.lang)) !== lang) await page.getByTestId('lang-toggle').dispatchEvent('click');
  if ((await page.evaluate(() => document.documentElement.dataset.theme)) !== theme) await page.getByTestId('theme-toggle').dispatchEvent('click');
  await expect(page.locator('html')).toHaveAttribute('lang', lang);
  await expect(page.locator('html')).toHaveAttribute('data-theme', theme);
}

/** ar + en, light + dark, 1440×900 and 1280×800; the page ends in Arabic light at 1440×900. */
async function shoot(page: Page, name: string) {
  if (!captures) return;
  mkdirSync(captures, { recursive: true });
  for (const lang of ['ar', 'en'] as const) {
    for (const theme of ['light', 'dark'] as const) {
      await setLook(page, lang, theme);
      for (const size of SIZES) {
        await page.setViewportSize(size);
        await page.waitForTimeout(250);
        await page.screenshot({ path: join(captures, `${name}.${lang}.${theme}.${size.width}x${size.height}.png`) });
      }
    }
  }
  await setLook(page, 'ar', 'light');
  await page.setViewportSize(SIZES[0]!);
}

async function signIn(page: Page, who: { email: string; password: string }) {
  await page.getByTestId('sign-in').locator('input[name=identifier]').fill(who.email);
  await page.getByTestId('sign-in').locator('input[name=password]').fill(who.password);
  await page.getByTestId('sign-in').getByRole('button').click();
}

async function allowDevices(page: Page) {
  // With the permission already given the browser lists named devices at once; else the studio asks first.
  await expect(page.getByTestId('camera-select').or(page.getByTestId('allow-devices'))).toBeVisible();
  if (await page.getByTestId('allow-devices').isVisible()) await allowDevices(page);
  await expect(page.getByTestId('camera-select')).toBeVisible();
}

async function startViewer(roomId: string, out: string, opts: { chat?: string; gift?: boolean; holdMs: number }): Promise<ChildProcess> {
  rmSync(out, { force: true });
  const s = smoke();
  const viewerToken = await tokenOf(s.viewer);
  return spawn('pnpm', ['exec', 'tsx', 'test/smoke/studio-viewer.ts'], {
    cwd: apiDir,
    stdio: 'ignore',
    env: {
      ...process.env,
      STUDIO_VIEWER_API: apiBase(),
      STUDIO_VIEWER_ROOM: roomId,
      STUDIO_VIEWER_TOKEN: viewerToken,
      STUDIO_VIEWER_HOST: s.host.username,
      STUDIO_VIEWER_GIFT: opts.gift ? s.giftCode : '',
      STUDIO_VIEWER_CHAT: opts.chat ?? '',
      STUDIO_VIEWER_OUT: out,
      STUDIO_VIEWER_HOLD_MS: String(opts.holdMs),
    },
  });
}

const viewerState = (out: string): ViewerState | null => {
  try {
    return JSON.parse(readFileSync(out, 'utf8')) as ViewerState;
  } catch {
    return null;
  }
};

async function liveRoomId(): Promise<string> {
  const s = smoke();
  const profile = await api<{ liveRoomId?: string }>('GET', `/users/${s.host.username}`, await tokenOf(s.host));
  expect(profile.body.liveRoomId).toBeTruthy();
  return profile.body.liveRoomId as string;
}

test.describe.configure({ mode: 'serial' });

test.beforeEach(async ({ context }) => {
  test.skip(!smokeFile || !existsSync(smokeFile), 'KABSO_STUDIO_SMOKE is not set (start test/smoke/studio.smoke.ts)');
  await context.addInitScript(OBS_SIMULATION);
});

test('sign-in, the honest refusal without the hosting permission', async ({ page }) => {
  await page.setViewportSize(SIZES[0]!);
  await page.goto('/');
  await expect(page.getByTestId('sign-in')).toBeVisible();
  await expect(page.locator('html')).toHaveAttribute('dir', 'rtl');
  await shoot(page, 'signin');
  // Wrong password: the server's refusal in the studio's words.
  await signIn(page, { email: smoke().noHost.email, password: 'not the password' });
  await expect(page.getByRole('alert')).toContainText('غير صحيحة');
  await signIn(page, smoke().noHost);
  await expect(page.getByTestId('gate')).toHaveAttribute('data-gate', 'noPermission');
  await expect(page.getByTestId('gate')).toContainText('كن مضيفاً مع الإدارة');
  await shoot(page, 'gate.no-permission');
  await page.getByTestId('sign-out').click();
  await expect(page.getByTestId('sign-in')).toBeVisible();
});

test('screen + camera bubble: sources, preview, live with a real viewer, chat, gifts, layout, stop-sharing, reconnect, end', async ({
  page,
}) => {
  test.setTimeout(420_000);
  const s = smoke();
  await endLeftoverLive();
  await page.setViewportSize(SIZES[0]!);
  await page.goto('/');
  await signIn(page, s.host);
  await expect(page.getByTestId('go-live')).toBeVisible();

  // Sources: the capability note for this browser, the devices after the permission, OBS first and marked.
  await expect(page.getByTestId('cap-note')).toBeVisible();
  await allowDevices(page);
  const cameras = page.getByTestId('camera-select');
  await expect(cameras).toBeVisible();
  await expect(cameras.locator('option', { hasText: 'OBS Virtual Camera' })).toHaveCount(1);
  await expect(page.getByTestId('obs-help')).toHaveAttribute('data-found', 'true');
  await expect(page.getByTestId('obs-help')).toContainText('في OBS اضغط Start Virtual Camera ثم اخترها هنا');
  // The bubble camera: Chromium's own fake camera (not OBS).
  const fakeCam = await cameras.locator('option').evaluateAll((opts) =>
    (opts as HTMLOptionElement[]).find((o) => o.value && o.value !== 'obs-virtual-camera')?.value ?? '',
  );
  await cameras.selectOption(fakeCam);

  // The screen: Chromium picks the whole screen by itself (--auto-select-desktop-capture-source).
  await page.getByTestId('pick-screen').click();
  await expect(page.getByTestId('stage').locator('video.stage-main')).toBeVisible();
  await expect(page.getByTestId('bubble')).toBeVisible();
  await expect(page.getByTestId('stage')).toHaveAttribute('data-orientation', 'LANDSCAPE');
  await page.getByTestId('mode-camera').click();
  await expect(page.getByTestId('obs-help')).toHaveClass(/prominent/);
  await shoot(page, 'sources.obs');
  await page.getByTestId('mode-screen').click();
  await shoot(page, 'sources');
  await page.getByTestId('title').fill('ليلة ببجي من الحاسوب');
  // The preview's bubble moves to another corner by a tap on the corner picker.
  await page.locator('.controls .corner.c-BOTTOM_RIGHT').click();
  await expect(page.getByTestId('bubble')).toHaveAttribute('data-corner', 'BOTTOM_RIGHT');
  await shoot(page, 'preview');

  // Go live.
  await page.getByTestId('go-live').click();
  await expect(page.getByTestId('conn')).toHaveAttribute('data-state', 'connected', { timeout: 30_000 });
  const roomId = await liveRoomId();
  const room = await api<{ mode: string; streamer: { main: string; orientation: string; cameraOverlay: { corner: string; visible: boolean } } }>(
    'GET',
    `/live/rooms/${roomId}`,
    null,
  );
  expect(room.body.mode).toBe('STREAMER');
  expect(room.body.streamer).toMatchObject({ main: 'SCREEN', orientation: 'LANDSCAPE', cameraOverlay: { corner: 'BOTTOM_RIGHT', visible: true } });

  // A real viewer on LiveKit: receives the screen and the camera (and the microphone), chats, sends a gift.
  const out = join(process.env.TMPDIR ?? '/tmp', `studio-viewer-${Date.now()}.json`);
  const viewer = await startViewer(roomId, out, { chat: 'مرحبا من المشاهدة', gift: true, holdMs: 150_000 });
  try {
    await expect
      .poll(() => {
        const v = viewerState(out);
        return v
          ? {
              screen: (v.tracks.screen_share?.frames ?? 0) > 5,
              screenAudio: (v.tracks.screen_share_audio?.frames ?? 0) > 5,
              camera: (v.tracks.camera?.frames ?? 0) > 5,
              mic: (v.tracks.microphone?.frames ?? 0) > 5,
            }
          : null;
      }, { timeout: 60_000 })
      .toEqual({ screen: true, screenAudio: true, camera: true, mic: true });
    expect(viewerState(out)?.tracks.screen_share).toMatchObject({ width: 1280, height: 720 });
    await expect.poll(() => viewerState(out)?.chat?.status, { timeout: 45_000 }).toBe(201);
    await expect.poll(() => viewerState(out)?.gift?.status, { timeout: 20_000 }).toBe(201);
    await expect(page.getByTestId('chat')).toContainText('مرحبا من المشاهدة', { timeout: 15_000 });
    // Viewers are hidden on the media server: the count is the API's (the reconciliation saw the viewer).
    await expect(page.getByTestId('viewers')).toHaveAttribute('data-count', '1', { timeout: 15_000 });
    await page.getByTestId('chat-input').fill('أهلاً بالجميع! 🎮');
    await page.getByTestId('chat-input').press('Enter');
    await expect(page.getByTestId('chat').locator('.msg:not(.pending)', { hasText: 'أهلاً بالجميع' })).toHaveCount(1, { timeout: 10_000 });
    await expect(page.getByTestId('tab-gifts')).toContainText('1');
    await shoot(page, 'live');
    await page.getByTestId('tab-gifts').click();
    await expect(page.getByTestId('gifts')).toContainText('وردة');
    await expect(page.getByTestId('gifts')).toContainText('×10');
    await shoot(page, 'live.gifts');
    await page.getByRole('tab', { name: 'الدردشة' }).click();

    // The layout follows the host: another corner → PUT …/streamer → the viewer's `streamer` message.
    await page.locator('.toolbar .corner.c-TOP_LEFT').click();
    await expect
      .poll(async () => (await api<{ streamer: { cameraOverlay: { corner: string } } }>('GET', `/live/rooms/${roomId}`, null)).body.streamer.cameraOverlay.corner, {
        timeout: 10_000,
      })
      .toBe('TOP_LEFT');
    await expect.poll(() => viewerState(out)?.streamerMessages.at(-1)?.cameraOverlay.corner, { timeout: 10_000 }).toBe('TOP_LEFT');
    // Hide the camera: the bubble goes (layout) and the camera track is muted.
    await page.getByTestId('toggle-camera').click();
    await expect.poll(() => viewerState(out)?.streamerMessages.at(-1)?.cameraOverlay.visible, { timeout: 10_000 }).toBe(false);
    await expect.poll(() => viewerState(out)?.tracks.camera?.muted, { timeout: 10_000 }).toBe(true);
    await page.getByTestId('toggle-camera').click();
    await expect.poll(() => viewerState(out)?.tracks.camera?.muted, { timeout: 10_000 }).toBe(false);
    // Mute the microphone, pause the screen: the viewer sees the tracks muted.
    await page.getByTestId('toggle-mic').click();
    await expect.poll(() => viewerState(out)?.tracks.microphone?.muted, { timeout: 10_000 }).toBe(true);
    await page.getByTestId('toggle-mic').click();
    await page.getByTestId('toggle-screen').click();
    await expect.poll(() => viewerState(out)?.tracks.screen_share?.muted, { timeout: 10_000 }).toBe(true);
    await page.getByTestId('toggle-screen').click();
    await expect.poll(() => viewerState(out)?.tracks.screen_share?.muted, { timeout: 10_000 }).toBe(false);

    // The browser's «Stop sharing»: the screen is paused for viewers, the host shares again (same publication).
    await page.evaluate(() => {
      const v = document.querySelector('[data-testid=live-stage] video.stage-main') as HTMLVideoElement | null;
      const track = (v?.srcObject as MediaStream | null)?.getVideoTracks()[0];
      track?.stop();
      track?.dispatchEvent(new Event('ended'));
    });
    await expect(page.getByTestId('screen-stopped')).toBeVisible();
    await expect.poll(() => viewerState(out)?.tracks.screen_share?.muted, { timeout: 10_000 }).toBe(true);
    await shoot(page, 'live.screen-stopped');
    const before = viewerState(out)?.tracks.screen_share?.frames ?? 0;
    await page.getByTestId('screen-stopped').getByRole('button').click();
    await expect(page.getByTestId('screen-stopped')).toBeHidden();
    await expect.poll(() => viewerState(out)?.tracks.screen_share?.muted, { timeout: 10_000 }).toBe(false);
    await expect.poll(() => (viewerState(out)?.tracks.screen_share?.frames ?? 0) - before, { timeout: 15_000 }).toBeGreaterThan(10);

    // A media-server outage (KABSO_LIVEKIT_RESTART stops LiveKit for a few seconds and starts it again): livekit-client
    // cannot resume the old session, the studio takes a new host token and rejoins, the live stays LIVE (heartbeats
    // go on), and a new viewer gets the screen again.
    if (process.env.KABSO_LIVEKIT_RESTART) {
      const restart = spawn(process.env.KABSO_LIVEKIT_RESTART, ['6'], { stdio: 'ignore' });
      const restarted = new Promise((r) => restart.once('exit', r));
      const seen = new Set<string>();
      const until = Date.now() + 90_000;
      let back = false;
      while (Date.now() < until && !back) {
        const st = (await page.getByTestId('conn').getAttribute('data-state')) ?? '';
        seen.add(st);
        back = st === 'connected' && seen.size > 1;
        await page.waitForTimeout(300);
      }
      await restarted;
      test.info().annotations.push({ type: 'outage-states', description: [...seen].join(' → ') });
      expect(seen.has('rejoining') || seen.has('resuming')).toBe(true);
      await expect(page.getByTestId('conn')).toHaveAttribute('data-state', 'connected', { timeout: 90_000 });
      const after = await api<{ status: string }>('GET', `/live/rooms/${roomId}`, null);
      expect(after.body.status).toBe('LIVE');
      const out2 = join(process.env.TMPDIR ?? '/tmp', `studio-viewer-after-${Date.now()}.json`);
      const viewer2 = await startViewer(roomId, out2, { holdMs: 15_000 });
      try {
        await expect
          .poll(() => ((viewerState(out2)?.tracks.screen_share?.frames ?? 0) > 5 && (viewerState(out2)?.tracks.camera?.frames ?? 0) > 5), {
            timeout: 60_000,
          })
          .toBe(true);
      } finally {
        viewer2.kill();
      }
    }

    // End with a confirmation.
    await page.getByTestId('end-live').click();
    await expect(page.getByRole('alertdialog')).toBeVisible();
    await shoot(page, 'live.end-confirm');
    await page.getByTestId('confirm-end').click();
    await expect(page.getByTestId('ended')).toBeVisible();
    const ended = await api<{ status: string; endReason: string }>('GET', `/live/rooms/${roomId}`, null);
    expect(ended.body).toMatchObject({ status: 'ENDED', endReason: 'HOST_ENDED' });
    await shoot(page, 'ended');
  } finally {
    viewer.kill();
  }
});

test('camera only (OBS): the camera is the picture, no screen; closing the tab and coming back resumes', async ({ page, context }) => {
  test.setTimeout(300_000);
  const s = smoke();
  await endLeftoverLive();
  await page.setViewportSize(SIZES[0]!);
  await page.goto('/');
  await signIn(page, s.host);
  await allowDevices(page);
  await page.getByTestId('mode-camera').click();
  // OBS is chosen by itself for «الكاميرا فقط».
  await expect(page.getByTestId('camera-select')).toHaveValue('obs-virtual-camera');
  await expect(page.getByTestId('stage')).toHaveAttribute('data-main', 'CAMERA');
  await expect(page.getByTestId('stage').locator('video.stage-main')).toBeVisible();
  await expect(page.getByTestId('bubble')).toHaveCount(0);
  await page.getByTestId('title').fill('مشهد OBS');
  await shoot(page, 'preview.obs');
  await page.getByTestId('go-live').click();
  await expect(page.getByTestId('conn')).toHaveAttribute('data-state', 'connected', { timeout: 30_000 });
  const roomId = await liveRoomId();
  const room = await api<{ streamer: { main: string; orientation: string; cameraOverlay: { visible: boolean } } }>('GET', `/live/rooms/${roomId}`, null);
  expect(room.body.streamer).toMatchObject({ main: 'CAMERA', cameraOverlay: { visible: false } });

  const out = join(process.env.TMPDIR ?? '/tmp', `studio-viewer-obs-${Date.now()}.json`);
  const viewer = await startViewer(roomId, out, { holdMs: 20_000 });
  try {
    await expect.poll(() => (viewerState(out)?.tracks.camera?.frames ?? 0) > 5, { timeout: 60_000 }).toBe(true);
    const v = viewerState(out)!;
    expect(v.tracks.screen_share).toBeUndefined();
    expect(v.tracks.camera!.width).toBeGreaterThan(v.tracks.camera!.height ?? 0);
    expect(room.body.streamer.orientation).toBe('LANDSCAPE');
    await shoot(page, 'live.obs');
  } finally {
    viewer.kill();
  }

  // The tab closes (the browser asks first): the live is left like a killed app — no heartbeat, LiveKit left at once.
  let asked = false;
  page.on('dialog', (d) => {
    asked = d.type() === 'beforeunload';
    void d.accept();
  });
  await page.close({ runBeforeUnload: true });
  await expect.poll(() => asked, { timeout: 10_000 }).toBe(true);
  // Within the stale window the host comes back: the studio offers to continue that live.
  const again = await context.newPage();
  await again.setViewportSize(SIZES[0]!);
  await again.goto('/');
  await signIn(again, s.host);
  await expect(again.getByTestId('active-live')).toBeVisible();
  await shoot(again, 'resume');
  await again.getByTestId('active-live').getByRole('button', { name: 'تابع البث الجاري' }).click();
  await allowDevices(again);
  await again.getByTestId('go-live').click();
  await expect(again.getByTestId('conn')).toHaveAttribute('data-state', 'connected', { timeout: 30_000 });
  expect(await liveRoomId()).toBe(roomId);
  await again.getByTestId('end-live').click();
  await again.getByTestId('confirm-end').click();
  await expect(again.getByTestId('ended')).toBeVisible();
});

test('the website: the studio link and the streamers page', async ({ page }) => {
  test.skip(!siteDir, 'KABSO_SITE_DIR is not set');
  const port = 8247;
  const server = spawn('python3', ['-m', 'http.server', String(port), '--bind', '127.0.0.1', '--directory', siteDir], { stdio: 'ignore' });
  try {
    await page.waitForTimeout(800);
    for (const lang of ['ar', 'en'] as const) {
      for (const scheme of ['light', 'dark'] as const) {
        await page.emulateMedia({ colorScheme: scheme });
        for (const size of SIZES) {
          await page.setViewportSize(size);
          await page.goto(`http://127.0.0.1:${port}/index.html${lang === 'en' ? '?lang=en' : ''}`);
          const link = page.locator('footer a[data-internal="/studio"]');
          await expect(link).toBeVisible();
          await expect(link).toHaveText(lang === 'ar' ? 'استوديو البث' : 'Streaming studio');
          await page.waitForTimeout(2500); // the home page's entrance animation
          if (captures) await page.screenshot({ path: join(captures, `site.home.${lang}.${scheme}.${size.width}x${size.height}.png`) });
          await page.goto(`http://127.0.0.1:${port}/studio.html${lang === 'en' ? '?lang=en' : ''}`);
          await expect(page.locator(`article[data-lang=${lang}] h1`)).toBeVisible();
          await expect(page.locator(`article[data-lang=${lang}]`)).toContainText('OBS');
          await expect(page.locator(`article[data-lang=${lang}] a[href="https://studio.kabsolive.com"]`).first()).toBeVisible();
          if (captures) await page.screenshot({ path: join(captures, `site.studio.${lang}.${scheme}.${size.width}x${size.height}.png`), fullPage: true });
        }
      }
    }
  } finally {
    server.kill();
  }
});
