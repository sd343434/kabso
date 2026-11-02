/**
 * D250 «مراقبة البث» with a MOCKED API (every /api/v1 call answered here; fictional people, no pictures): «البث الآن» with
 * muted previews (at most 6 playing), the «لايفات مبلّغ عنها» chip and the sidebar's red dot, a card's ⋯ menu, the watch
 * view (a PK too), the four action dialogs (what they send is checked), and «الأجهزة المحظورة». Arabic, light and dark.
 *
 * Video: when KABSO_D250_MEDIA names a JSON file {url, preview: {roomId: token}, watch: {roomId: token}} the watch-token
 * answers point at that media server (the D250 capture run: a local LiveKit with SYNTHETIC test-pattern video); without
 * it the previews show the cover and the watch view says the media server is not available. KABSO_CAPTURE_DIR saves
 * the captures.
 */
import { mkdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { expect, test, type Page, type Route } from '@playwright/test';

const captureDir = process.env.KABSO_CAPTURE_DIR;
const media = process.env.KABSO_D250_MEDIA
  ? (JSON.parse(readFileSync(process.env.KABSO_D250_MEDIA, 'utf8')) as {
      url: string;
      preview: Record<string, string>;
      watch: Record<string, string>;
    })
  : null;

const id = (n: number) => `0192f1d0-0000-7000-8000-${String(n).padStart(12, '0')}`;
const D250_ROOMS = {
  solo: id(1),
  pkA: id(2),
  pkB: id(3),
  audio: id(4),
  podcast: id(5),
  multi: id(6),
  solo2: id(7),
  solo3: id(8),
};
const host = (n: number, username: string, displayName: string) => ({
  id: `0192f1d0-1111-7000-8000-${String(n).padStart(12, '0')}`,
  username,
  displayName,
  avatarUrl: null,
});
const minutesAgo = (m: number) => new Date(Date.now() - m * 60_000).toISOString();
const LIVES = [
  { id: D250_ROOMS.solo, title: 'سهرة الجمعة مع ليث', mode: 'SOLO', viewers: 1520, startedAt: minutesAgo(48), host: host(1, 'laith.live', 'ليث'), pk: null, openReports: 3 },
  {
    id: D250_ROOMS.pkA,
    title: 'تحدي PK الليلة',
    mode: 'SOLO',
    viewers: 980,
    startedAt: minutesAgo(31),
    host: host(2, 'sara.k', 'سارة'),
    pk: { opponentRoomId: D250_ROOMS.pkB, opponentUsername: 'omar.vibes', opponentDisplayName: 'عمر' },
    openReports: 1,
  },
  {
    id: D250_ROOMS.pkB,
    title: 'عمر في PK',
    mode: 'SOLO',
    viewers: 860,
    startedAt: minutesAgo(29),
    host: host(3, 'omar.vibes', 'عمر'),
    pk: { opponentRoomId: D250_ROOMS.pkA, opponentUsername: 'sara.k', opponentDisplayName: 'سارة' },
    openReports: 0,
  },
  { id: D250_ROOMS.multi, title: 'جلسة متعددة', mode: 'MULTI', viewers: 640, startedAt: minutesAgo(75), host: host(6, 'nour.multi', 'نور'), pk: null, openReports: 0 },
  { id: D250_ROOMS.solo2, title: 'طبخ مباشر', mode: 'SOLO', viewers: 410, startedAt: minutesAgo(12), host: host(7, 'chef.huda', 'هدى'), pk: null, openReports: 0 },
  { id: D250_ROOMS.audio, title: 'سوالف المساء', mode: 'AUDIO', viewers: 300, startedAt: minutesAgo(90), host: host(4, 'yaser.voice', 'ياسر'), pk: null, openReports: 0 },
  { id: D250_ROOMS.solo3, title: 'ألعاب وتحديات', mode: 'SOLO', viewers: 205, startedAt: minutesAgo(8), host: host(8, 'gamer.ali', 'علي'), pk: null, openReports: 0 },
  { id: D250_ROOMS.podcast, title: 'بودكاست التقنية', mode: 'PODCAST', viewers: 150, startedAt: minutesAgo(40), host: host(5, 'tech.cast', 'تقنية'), pk: null, openReports: 0 },
].map((l) => ({ ...l, coverUrl: null, score: 0, categoryAr: null, categoryEn: null }));

const CAPS = [
  'dashboard.view',
  'users.view',
  'users.list',
  'users.balances',
  'users.ban',
  'users.lock',
  'users.restrict',
  'users.control_view',
  'reports.view',
  'reports.act',
  'lives.view',
  'lives.manage',
  'lives.watch',
  'lives.reports',
  'lives.moderate',
  'devices.ban',
  'pk_dares.view',
  'pk_dares.edit',
];

const reporter = (n: number, username: string) => ({ id: `0192f1d0-2222-7000-8000-${String(n).padStart(12, '0')}`, username, displayName: username, avatarUrl: null });
const chatLine = (n: number, who: { id: string; username: string; displayName: string; avatarUrl: null }, text: string, m: number, deleted = false) => ({
  id: `0192f1d0-3333-7000-8000-${String(n).padStart(12, '0')}`,
  kind: 'TEXT',
  text,
  createdAt: minutesAgo(m),
  deleted,
  authorRole: n % 3 === 0 ? 'HOST' : 'VIEWER',
  author: who,
});
const viewerA = reporter(1, 'mona_22');
const viewerB = reporter(2, 'fahad.k');
const viewerC = reporter(3, 'rania.m');
const CHAT = [
  chatLine(1, viewerA, 'مساء الخير يا ليث 👋', 9),
  chatLine(2, viewerB, 'صوتك واضح اليوم', 8),
  chatLine(3, LIVES[0]!.host as never, 'أهلاً بالجميع، ابدأوا بالأسئلة', 7),
  chatLine(4, viewerC, 'ممكن تعيد آخر جزء؟', 6),
  chatLine(5, viewerB, 'رسالة مسيئة حذفها المشرف', 5, true),
  chatLine(6, viewerA, 'المضيف يستخدم ألفاظاً غير لائقة', 4),
  chatLine(7, viewerC, 'تم الإبلاغ', 3),
];
const REPORTS = [
  {
    id: id(901),
    targetType: 'LIVE_ROOM',
    reason: 'HARASSMENT',
    note: 'المضيف يشتم المشاهدين في الدقيقة الأخيرة',
    status: 'OPEN',
    createdAt: minutesAgo(3),
    resolvedAt: null,
    resolutionNote: null,
    reporter: viewerA,
    chatBefore: CHAT.slice(2, 6),
  },
  { id: id(902), targetType: 'LIVE_ROOM', reason: 'HATE', note: null, status: 'OPEN', createdAt: minutesAgo(2), resolvedAt: null, resolutionNote: null, reporter: viewerC, chatBefore: CHAT.slice(3, 7) },
  { id: id(903), targetType: 'USER', reason: 'SPAM', note: 'إعلانات متكررة', status: 'OPEN', createdAt: minutesAgo(1), resolvedAt: null, resolutionNote: null, reporter: viewerB, chatBefore: CHAT.slice(4, 7) },
];
const DEVICE_BANS = [
  {
    id: id(801),
    status: 'ACTIVE',
    reason: 'بث محتوى مخالف وتكرار المخالفة بعد التحذير',
    createdAt: minutesAgo(60 * 26),
    endsAt: new Date(Date.now() + 6 * 86_400_000).toISOString(),
    liftedAt: null,
    liftReason: null,
    account: host(11, 'bad.actor', 'حساب مخالف'),
    createdBy: { id: id(700), username: 'mod.huda', displayName: 'هدى (مشرفة)', avatarUrl: null },
    liftedBy: null,
    liveRoomId: id(11),
  },
  {
    id: id(802),
    status: 'ACTIVE',
    reason: 'التهرب من الحظر بحسابات جديدة',
    createdAt: minutesAgo(60 * 50),
    endsAt: null,
    liftedAt: null,
    liftReason: null,
    account: host(12, 'evader01', 'متهرب'),
    createdBy: { id: id(700), username: 'mod.huda', displayName: 'هدى (مشرفة)', avatarUrl: null },
    liftedBy: null,
    liveRoomId: null,
  },
  {
    id: id(803),
    status: 'LIFTED',
    reason: 'إساءة في البث',
    createdAt: minutesAgo(60 * 24 * 9),
    endsAt: new Date(Date.now() + 21 * 86_400_000).toISOString(),
    liftedAt: minutesAgo(60 * 24 * 2),
    liftReason: 'قُبل الاعتراض',
    account: host(13, 'appeal.ok', 'اعتراض مقبول'),
    createdBy: { id: id(700), username: 'mod.huda', displayName: 'هدى (مشرفة)', avatarUrl: null },
    liftedBy: { id: id(701), username: 'owner', displayName: 'المالك', avatarUrl: null },
    liveRoomId: null,
  },
  {
    id: id(804),
    status: 'EXPIRED',
    reason: 'مخالفة متكررة',
    createdAt: minutesAgo(60 * 24 * 40),
    endsAt: minutesAgo(60 * 24 * 10),
    liftedAt: null,
    liftReason: null,
    account: host(14, 'old.case', 'حالة قديمة'),
    createdBy: { id: id(700), username: 'mod.huda', displayName: 'هدى (مشرفة)', avatarUrl: null },
    liftedBy: null,
    liveRoomId: null,
  },
];

const sent: { path: string; body: unknown }[] = [];
const json = (route: Route, body: unknown, status = 200) =>
  route.fulfill({ status, contentType: 'application/json', body: JSON.stringify(body) });

async function mockApi(page: Page): Promise<void> {
  await page.route('**/api/v1/**', async (route) => {
    const req = route.request();
    const url = new URL(req.url());
    const path = url.pathname.replace('/api/v1', '');
    const method = req.method();
    if (path === '/admin/auth/session')
      return json(route, {
        admin: { id: id(700), email: 'mod@example.com', username: 'mod.huda', displayName: 'هدى (مشرفة)' },
        roles: ['MODERATION'],
        capabilities: CAPS,
        csrfToken: 'csrf',
        expiresAt: new Date(Date.now() + 3_600_000).toISOString(),
        idleSeconds: 1800,
      });
    if (path === '/admin/stats/attention') return json(route, { total: 3, items: [{ kind: 'REPORTS', count: 3, oldestAt: minutesAgo(30) }] });
    if (path === '/admin/live-reports/summary') return json(route, { rooms: 2, reports: 4 });
    if (path === '/admin/lives' && method === 'GET') {
      const reported = url.searchParams.get('reported') === 'true';
      const mode = url.searchParams.get('mode');
      const rows = LIVES.filter((l) => (!reported || l.openReports > 0) && (!mode || (mode === 'PK' ? l.pk : l.mode === mode && !l.pk)));
      return json(route, { data: rows, total: rows.length, page: 1, pageSize: 24 });
    }
    const m = /^\/admin\/lives\/([0-9a-f-]{36})(\/.*)?$/.exec(path);
    if (m) {
      const roomId = m[1]!;
      const sub = m[2] ?? '';
      const l = LIVES.find((x) => x.id === roomId) ?? LIVES[0]!;
      if (sub === '' && method === 'GET')
        return json(route, { ...l, topic: null, status: 'LIVE', endReason: null, peakViewers: l.viewers + 240, endedAt: null, roomNumber: 100200 + LIVES.indexOf(l), giftCoins: 125000, giftsSent: 312, seatsTaken: l.mode === 'MULTI' ? 3 : 0, moderators: 2, chatEnabled: true, allowGuests: true });
      if (sub === '/reports') return json(route, { open: l.openReports, data: REPORTS.slice(0, l.openReports) });
      if (sub === '/chat') return json(route, { data: url.searchParams.get('after') ? [] : CHAT });
      if (sub === '/moderations') return json(route, { data: [] });
      if (sub === '/watch-token') {
        const purpose = (req.postDataJSON() as { purpose: 'PREVIEW' | 'WATCH' }).purpose;
        if (!media) return json(route, { error: { code: 'LIVE_HOSTING_UNAVAILABLE', message: 'no media', requestId: 'x' } }, 503);
        const pick = purpose === 'PREVIEW' ? media.preview : media.watch;
        const access = (r: string) => ({ roomId: r, url: media.url, token: pick[r] ?? '', identity: 'staff:cap', expiresAt: new Date(Date.now() + 120_000).toISOString() });
        return json(route, { purpose, main: access(roomId), opponent: purpose === 'WATCH' && l.pk?.opponentRoomId ? access(l.pk.opponentRoomId) : null });
      }
      if (method === 'POST') {
        sent.push({ path, body: req.postDataJSON() });
        return json(route, { id: id(990), kind: 'END', reason: 'x', endsAt: null, endedLive: true, reportsClosed: 3, devicesBanned: 0, sessionsEnded: 0 });
      }
    }
    if (path === '/admin/device-bans') {
      const status = url.searchParams.get('status');
      const rows = DEVICE_BANS.filter((b) => !status || b.status === status);
      return json(route, { data: rows, total: rows.length, page: 1, pageSize: 25 });
    }
    return json(route, {});
  });
}

async function capture(page: Page, name: string, full = false): Promise<void> {
  if (!captureDir) return;
  mkdirSync(captureDir, { recursive: true });
  await page.waitForTimeout(400);
  await page.screenshot({ path: join(captureDir, `${name}.png`), fullPage: full });
}

test.setTimeout(240_000);
// The capture VM's media server advertises its one interface; Chromium's mDNS-hidden host candidates cannot reach it
// there (a real network resolves them), so the capture run shows the real addresses.
if (media) test.use({ launchOptions: { args: ['--disable-features=WebRtcHideLocalIpsWithMdns'] } });

for (const theme of ['light', 'dark'] as const) {
  test(`«مراقبة البث» — previews, reported lives, watch view, actions, device bans (ar, ${theme})`, async ({ page }) => {
    const errors: string[] = [];
    page.on('pageerror', (e) => errors.push(e.message));
    await page.addInitScript((th) => {
      window.localStorage.setItem('kabso-admin-theme', th);
      window.localStorage.setItem('kabso-admin-lang', 'ar');
    }, theme);
    await mockApi(page);
    await page.setViewportSize({ width: 1440, height: 900 });
    await page.goto('/lives');
    await expect(page.getByRole('heading', { name: 'البث الآن', level: 1 })).toBeVisible();

    // The sidebar's red dot and the chip's count.
    await expect(page.locator('nav.nav a[href="/lives"] [data-nav-dot="2"]')).toBeVisible();
    await expect(page.locator('.reported-tab .count-pill')).toHaveText('2');
    // Previews: at most 6 play; the rest show a play button.
    await expect(page.locator('article.live-card')).toHaveCount(8);
    if (media) await expect(page.locator('video.live-preview-video.on')).toHaveCount(5, { timeout: 30_000 }).catch(() => undefined);
    const playing = await page.locator('.thumb[data-preview]:not([data-preview="off"])').count();
    expect(playing).toBeLessThanOrEqual(6);
    expect(await page.locator('.play-btn').count()).toBeGreaterThanOrEqual(2);
    await page.waitForTimeout(media ? 2500 : 300);
    await capture(page, `01-lives-previews.${theme}`);

    await page.locator('.reported-tab').click();
    await expect(page.locator('article.live-card')).toHaveCount(2);
    await expect(page.locator('[data-open-reports="3"]')).toBeVisible();
    await page.waitForTimeout(media ? 2500 : 300);
    await capture(page, `02-reported-tab.${theme}`);

    await page.locator(`article.live-card`).first().getByRole('button', { name: 'إجراءات البث' }).click();
    await expect(page.getByRole('menu')).toBeVisible();
    await capture(page, `03-card-menu.${theme}`);
    await page.keyboard.press('Escape');

    // The watch view (a PK: both sides).
    await page.goto(`/lives/${D250_ROOMS.pkA}`);
    await expect(page.locator('[data-live-watch]')).toBeVisible();
    if (media) await expect(page.locator('.watch-tile video')).toHaveCount(2, { timeout: 30_000 }).catch(() => undefined);
    await page.waitForTimeout(media ? 3000 : 500);
    await capture(page, `04-watch-pk.${theme}`);

    await page.goto(`/lives/${D250_ROOMS.solo}`);
    await expect(page.getByText('المضيف يشتم المشاهدين في الدقيقة الأخيرة')).toBeVisible();
    await expect(page.getByText('مساء الخير يا ليث 👋')).toBeVisible();
    if (media) await expect(page.locator('.watch-tile video')).toHaveCount(1, { timeout: 30_000 }).catch(() => undefined);
    await page.locator('.watch-reports details').first().evaluate((d) => ((d as HTMLDetailsElement).open = true));
    await page.waitForTimeout(media ? 2500 : 300);
    await capture(page, `05-watch-reported.${theme}`, true);

    // The action dialogs.
    const act = async (action: string) => {
      await page.locator(`.watch-actions [data-action="${action}"]`).click();
      await expect(page.getByRole('dialog')).toBeVisible();
    };
    await act('END');
    await page.getByLabel('السبب (يصل للمضيف)').fill('ألفاظ مسيئة متكررة للمشاهدين رغم التنبيه');
    await capture(page, `06-dialog-end.${theme}`);
    await page.getByRole('dialog').getByRole('button', { name: 'إلغاء' }).click();

    await act('BAN');
    await page.getByRole('dialog').getByText('تعليق الحساب', { exact: true }).click();
    await page.getByRole('dialog').locator('[data-duration="7d"]').click();
    await page.getByLabel('السبب (يصل للمضيف)').fill('محتوى غير لائق أثناء البث');
    await capture(page, `07-dialog-temp-ban.${theme}`);
    const before = sent.length;
    await page.getByRole('dialog').getByRole('button', { name: 'حظر مؤقت' }).click();
    await expect(page.getByRole('dialog')).toHaveCount(0);
    expect(sent[before]).toEqual({
      path: `/admin/lives/${D250_ROOMS.solo}/moderate`,
      body: { action: 'SUSPEND', reason: 'محتوى غير لائق أثناء البث', hours: 168 },
    });

    await act('DEVICE_BAN');
    await page.getByRole('dialog').locator('[data-duration="permanent"]').click();
    await page.getByLabel('السبب (يصل للمضيف)').fill('التهرب من الحظر بحسابات جديدة');
    await page.getByLabel('رمز تطبيق المصادقة').fill('123456');
    await capture(page, `08-dialog-device-ban.${theme}`);
    await page.getByRole('dialog').getByRole('button', { name: 'حظر جهاز' }).click();
    await expect(page.getByRole('dialog')).toHaveCount(0);
    expect(sent.at(-1)!.body).toEqual({ action: 'DEVICE_BAN', reason: 'التهرب من الحظر بحسابات جديدة', permanent: true, totpCode: '123456' });

    await act('DISMISS');
    await page.getByLabel('ملاحظة المراجعة').fill('راجعت البث كاملاً ولا توجد مخالفة');
    await capture(page, `09-dialog-dismiss.${theme}`);
    await page.getByRole('dialog').getByRole('button', { name: 'لا مخالفة' }).click();
    await expect(page.getByRole('dialog')).toHaveCount(0);
    expect(sent.at(-1)).toEqual({ path: `/admin/lives/${D250_ROOMS.solo}/reports/dismiss`, body: { reason: 'راجعت البث كاملاً ولا توجد مخالفة' } });

    // «الأجهزة المحظورة».
    await page.locator('nav.nav').getByRole('link', { name: 'الأجهزة المحظورة' }).click();
    await expect(page.getByRole('heading', { name: 'الأجهزة المحظورة', level: 1 })).toBeVisible();
    await expect(page.getByText('@bad.actor')).toBeVisible();
    await capture(page, `10-device-bans.${theme}`);

    expect(errors).toEqual([]);
  });
}
