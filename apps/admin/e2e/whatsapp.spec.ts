/**
 * D355 «واتساب» with a mocked API (no server needed): the inbox (list + chat + customer panel), a text reply, the closed
 * 24-hour window (only «إرسال قالب») and the template dialog, the settings page. Synthetic people and pictures only.
 * With KABSO_CAPTURE_DIR set it saves captures (Arabic light 1440×900, dark, English, phone 390×844).
 */
import { mkdirSync } from 'node:fs';
import { join } from 'node:path';
import { expect, test, type Page, type Route } from '@playwright/test';

const captureDir = process.env.KABSO_CAPTURE_DIR;
const id = (n: number) => `0192f1d0-0000-7000-8000-${String(n).padStart(12, '0')}`;
const ago = (min: number) => new Date(Date.now() - min * 60_000).toISOString();
const OWNER = id(1);
const me = { userId: OWNER, displayName: 'المالك', staffId: 'Kabso' };
const mona = { userId: id(2), displayName: 'منى', staffId: 'Kabso02' };
const CAPS = ['dashboard.view', 'support.whatsapp', 'support.whatsapp.manage', 'team.manage'];

const conv = (n: number, over: Record<string, unknown> = {}) => ({
  id: id(100 + n),
  phone: `+96650000${String(1000 + n)}`,
  name: null,
  status: 'OPEN',
  assignedTo: null,
  assignedToMe: false,
  unreadCount: 0,
  lastMessageAt: ago(n * 7),
  lastPreview: null,
  lastDirection: 'INBOUND',
  window: { open: true, closesAt: new Date(Date.now() + 20 * 3_600_000).toISOString() },
  linkedAccount: null,
  closedAt: null,
  createdAt: ago(600),
  ...over,
});
const OPEN = conv(1, {
  name: 'سارة',
  unreadCount: 2,
  lastPreview: '📷 الإيصال',
  linkedAccount: { userId: id(50), username: 'sara_9', displayName: 'سارة', avatarUrl: null, status: 'ACTIVE', countryCode: 'SA', createdAt: '2026-03-01T00:00:00.000Z' },
});
const CLOSED_WINDOW = conv(2, {
  name: 'Omar',
  assignedTo: me,
  assignedToMe: true,
  lastPreview: 'شكراً',
  window: { open: false, closesAt: ago(60 * 3) },
});
const LIST = [OPEN, CLOSED_WINDOW, conv(3, { name: 'ليلى', assignedTo: mona, lastPreview: 'متى يصل الشحن؟', unreadCount: 1 }), conv(4, { lastPreview: '🎤' })];
const msg = (n: number, over: Record<string, unknown>) => ({
  id: id(200 + n),
  direction: 'INBOUND',
  type: 'TEXT',
  text: null,
  media: null,
  location: null,
  reaction: null,
  template: null,
  status: 'RECEIVED',
  error: null,
  sentBy: null,
  at: ago(60 - n * 5),
  statusAt: null,
  ...over,
});
const MESSAGES = [
  msg(6, { type: 'AUDIO', media: { state: 'STORED', mime: 'audio/ogg', size: 4200, filename: null, voice: true } }),
  msg(5, { type: 'IMAGE', text: 'الإيصال', media: { state: 'STORED', mime: 'image/png', size: 900, filename: null, voice: false } }),
  msg(4, { direction: 'OUTBOUND', text: 'أرسلي صورة الإيصال من فضلك', status: 'READ', sentBy: me, reaction: '👍' }),
  msg(3, { direction: 'OUTBOUND', text: 'أهلاً سارة، نتحقق من طلبك الآن', status: 'DELIVERED', sentBy: me }),
  msg(2, { text: 'دفعت للوكيل ولم يصل الشحن 😟' }),
  msg(1, { text: 'السلام عليكم' }),
];
const OMAR_MESSAGES = [
  msg(2, { direction: 'OUTBOUND', text: 'هل تحتاج أي مساعدة أخرى؟', status: 'READ', sentBy: me }),
  msg(1, { text: 'شكراً' }),
];
const SVG = `<svg xmlns="http://www.w3.org/2000/svg" width="360" height="220"><rect width="360" height="220" rx="12" fill="#ececf0"/><rect x="24" y="24" width="312" height="24" rx="6" fill="#c8080f"/><rect x="24" y="70" width="220" height="14" rx="4" fill="#85858f"/><rect x="24" y="96" width="260" height="14" rx="4" fill="#85858f"/><rect x="24" y="150" width="120" height="36" rx="8" fill="#137a43"/></svg>`;

const sent: { path: string; body: unknown }[] = [];
const json = (route: Route, body: unknown, status = 200) =>
  route.fulfill({ status, contentType: 'application/json', body: JSON.stringify(body) });

async function mockApi(page: Page): Promise<void> {
  await page.route('**/api/v1/**', async (route) => {
    const req = route.request();
    const url = new URL(req.url());
    const path = url.pathname.replace('/api/v1', '');
    if (path === '/admin/auth/session')
      return json(route, {
        admin: { id: OWNER, email: 'owner@kabsolive.com', username: 'kabso.owner', displayName: 'المالك' },
        roles: ['OWNER'],
        capabilities: CAPS,
        csrfToken: 'csrf',
        expiresAt: new Date(Date.now() + 3_600_000).toISOString(),
        idleSeconds: 1800,
      });
    if (path === '/admin/stats/attention') return json(route, { total: 0, items: [] });
    if (path === '/admin/whatsapp/summary') return json(route, { enabled: true, badge: 3, mine: 0, unassigned: 3, unreadMessages: 4 });
    if (path === '/admin/whatsapp/conversations') {
      const f = url.searchParams.get('filter');
      const items = f === 'mine' ? LIST.filter((c) => c.assignedToMe) : f === 'unassigned' ? LIST.filter((c) => !c.assignedTo) : LIST;
      return json(route, { data: items, page: { nextCursor: null, hasMore: false } });
    }
    const m = /^\/admin\/whatsapp\/conversations\/([^/]+)(\/[a-z-]+)?$/.exec(path);
    if (m) {
      const c = LIST.find((x) => x.id === m[1]) ?? OPEN;
      const sub = m[2];
      if (!sub) return json(route, c);
      if (sub === '/messages' && req.method() === 'GET') return json(route, { data: c === OPEN ? MESSAGES : OMAR_MESSAGES, page: { nextCursor: null, hasMore: false } });
      if (sub === '/messages') {
        sent.push({ path, body: req.postDataJSON() });
        return json(route, msg(9, { direction: 'OUTBOUND', text: 'x', status: 'SENT', sentBy: me }), 201);
      }
      if (sub === '/notes') return json(route, { data: [{ id: id(300), body: 'العميلة أرسلت الإيصال، ننتظر تأكيد الوكيل', author: mona, at: ago(20) }] });
      if (sub === '/assignments') return json(route, { data: [{ id: id(301), action: 'CLAIM', from: null, to: me, by: me, at: ago(40) }] });
      if (sub === '/read') return json(route, { ...c, unreadCount: 0 });
      return json(route, c);
    }
    if (/\/admin\/whatsapp\/messages\/[^/]+\/media$/.test(path)) {
      return route.fulfill({ status: 200, contentType: 'image/svg+xml', body: SVG });
    }
    if (path === '/admin/whatsapp/templates')
      return json(route, {
        data: [
          { name: 'kabso_followup', language: 'ar', category: 'UTILITY', body: 'مرحباً {{1}}، هل ما زلت تحتاج المساعدة في طلبك {{2}}؟', parameterCount: 2 },
          { name: 'kabso_hello', language: 'en_US', category: 'UTILITY', body: 'Hello from Kabso Live', parameterCount: 0 },
        ],
      });
    if (path === '/admin/whatsapp/quick-replies') return json(route, { data: [{ id: id(400), title: 'ترحيب', body: 'أهلاً بك في دعم Kabso Live، كيف نساعدك؟', updatedAt: ago(100) }] });
    if (path === '/admin/whatsapp/settings')
      return json(route, {
        enabled: true,
        phoneNumberId: '1098765432100',
        businessAccountId: '2098765432100',
        displayName: 'Kabso Live',
        graphApiVersion: 'v23.0',
        webhookUrl: 'https://api.kabsolive.com/api/v1/webhooks/whatsapp',
        subscribedFields: ['messages'],
        retentionDays: 180,
        mediaMaxBytes: 16 * 1048576,
        lastInboundAt: ago(3),
        conversations: 4,
        missing: [],
      });
    if (path === '/admin/whatsapp/settings/test')
      return json(route, { ok: true, displayPhoneNumber: '+966 50 000 0000', verifiedName: 'Kabso Live', qualityRating: 'GREEN', templates: 2, error: null });
    return json(route, {});
  });
}

async function capture(page: Page, name: string): Promise<void> {
  if (!captureDir) return;
  mkdirSync(captureDir, { recursive: true });
  await page.waitForTimeout(400);
  await page.screenshot({ path: join(captureDir, `${name}.png`) });
}

test.setTimeout(120_000);

for (const [lang, theme, width, height] of [
  ['ar', 'light', 1440, 900],
  ['ar', 'dark', 1440, 900],
  ['en', 'light', 1440, 900],
  ['ar', 'light', 390, 844],
] as const) {
  test(`«واتساب» — inbox, reply, closed window, settings (${lang}, ${theme}, ${width})`, async ({ page }) => {
    const errors: string[] = [];
    page.on('pageerror', (e) => errors.push(e.message));
    await page.addInitScript(
      ([th, lg]) => {
        window.localStorage.setItem('kabso-admin-theme', th ?? 'light');
        window.localStorage.setItem('kabso-admin-lang', lg ?? 'ar');
      },
      [theme, lang],
    );
    sent.length = 0;
    await mockApi(page);
    await page.setViewportSize({ width, height });
    const ar = lang === 'ar';
    const tag = `${lang}.${theme}${width < 600 ? '.phone' : ''}`;
    await page.goto(`/whatsapp?c=${OPEN.id}`);
    await expect(page.getByRole('heading', { name: ar ? 'واتساب' : 'WhatsApp', level: 1 })).toBeVisible();
    await page.getByRole('tab', { name: ar ? 'الكل' : 'All' }).click();
    await expect(page.locator('.wa-row')).toHaveCount(4);
    await expect(page.locator('.nav-count').first()).toBeVisible();
    await expect(page.locator('.wa-bubble')).toHaveCount(6);
    await expect(page.locator('.wa-ticks.read')).toHaveCount(1);
    await expect(page.locator('[data-wa-account]')).toContainText('@sara_9');
    await page.locator('.wa-composer textarea').fill(ar ? 'وصل الشحن الآن، تأكدي من المحفظة' : 'The top-up arrived, please check the wallet');
    await capture(page, `01-inbox.${tag}`);
    await page.getByRole('button', { name: ar ? 'إرسال' : 'Send', exact: true }).click();
    await expect.poll(() => sent.length).toBe(1);
    expect(sent[0]!.body).toMatchObject({ type: 'TEXT' });

    // Omar's window closed: only «إرسال قالب».
    await page.goto(`/whatsapp?c=${CLOSED_WINDOW.id}`);
    await expect(page.locator('.wa-window.closed')).toBeVisible();
    await expect(page.locator('.wa-composer textarea')).toHaveCount(0);
    await capture(page, `02-window-closed.${tag}`);
    await page.getByRole('button', { name: ar ? 'إرسال قالب' : 'Send a template' }).click();
    const dialog = page.getByRole('dialog');
    await dialog.getByLabel(ar ? 'المتغيّر 1' : 'Variable 1').fill('Omar');
    await dialog.getByLabel(ar ? 'المتغيّر 2' : 'Variable 2').fill('#42');
    await capture(page, `03-template.${tag}`);
    await dialog.getByRole('button', { name: ar ? 'إرسال' : 'Send', exact: true }).click();
    await expect.poll(() => sent.length).toBe(2);
    expect(sent[1]!.body).toEqual({ type: 'TEMPLATE', template: { name: 'kabso_followup', language: 'ar', parameters: ['Omar', '#42'] } });

    await page.goto('/whatsapp/settings');
    await page.getByRole('button', { name: ar ? 'اختبار الاتصال' : 'Test the connection' }).click();
    await expect(page.locator('.alert.success')).toBeVisible();
    await capture(page, `04-settings.${tag}`);
    expect(errors).toEqual([]);
  });
}
