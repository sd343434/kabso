/**
 * D355 (owner 2026-11-10; contract v1.116-social, CONVENTIONS §10.151): «واتساب» — the official Kabso WhatsApp number
 * answered by the staff from the app and the panel. End to end against PostgreSQL + Redis with a fake Graph API on a
 * local port (test/helpers/fake-whatsapp.ts, no network): the webhook check and signature, inbound text / media /
 * reaction / statuses, a delivery twice (idempotency), the 24-hour window, templates, media both ways, permissions,
 * claim / transfer / release / close / reopen, notes, quick replies, the account link, pushes and the mute, the
 * panel's settings and test, the retention sweeper, the account purge and the data export.
 */
import { randomBytes } from 'node:crypto';
import { mkdtempSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { afterAll, beforeAll, describe, expect, it, vi } from 'vitest';
import { OBJECT_STORAGE } from '../src/modules/media/object-storage.js';
import { buildDataExport } from '../src/modules/privacy/data-export.js';
import {
  PUSH_SENDER,
  type PushMessage,
  type PushSender,
  type PushSendResult,
} from '../src/modules/push/push-sender.js';
import { purgeAccountIn } from '../src/modules/users/account-deletion.js';
import { WhatsAppSweeper } from '../src/modules/whatsapp/whatsapp.sweeper.js';
import { panel, type Admin, type Person } from './helpers/admin-panel.js';
import { FakeWhatsAppGraph, signatureOf, webhookBody } from './helpers/fake-whatsapp.js';
import { MemoryObjectStorage } from './helpers/memory-storage.js';
import { expectContract, operations } from './helpers/openapi.js';
import { createTestApp, settle, withMigrationClient, type TestContext } from './helpers/test-app.js';

class FakePushSender implements PushSender {
  readonly enabled = true;
  readonly sent: PushMessage[] = [];
  send(message: PushMessage): Promise<PushSendResult> {
    this.sent.push(message);
    return Promise.resolve({ sent: message.tokens.length, failed: 0, invalidTokens: [] });
  }
}

const ADMIN_KEY = 'admin-totp-test-key-0123456789-abcdefghijklmnop';
const PNID = '1098765432100';
const WABA = '2098765432100';
const auth = (u: { token: string }) => ({ Authorization: `Bearer ${u.token}` });
const unix = (d = new Date()) => String(Math.floor(d.getTime() / 1000));

describe('D355 contract coverage', () => {
  it('openapi v1.116-social declares the WhatsApp operations', () => {
    const ids = operations().map((o) => `${o.operationId} ${o.method.toUpperCase()} ${o.path}`);
    for (const op of [
      'verifyWhatsAppWebhook GET /api/v1/webhooks/whatsapp',
      'receiveWhatsAppWebhook POST /api/v1/webhooks/whatsapp',
      'getStaffWhatsAppSummary GET /api/v1/staff/whatsapp/summary',
      'getStaffWhatsAppConversations GET /api/v1/staff/whatsapp/conversations',
      'sendStaffWhatsAppMessage POST /api/v1/staff/whatsapp/conversations/{id}/messages',
      'sendStaffWhatsAppMedia POST /api/v1/staff/whatsapp/conversations/{id}/media',
      'claimStaffWhatsAppConversation POST /api/v1/staff/whatsapp/conversations/{id}/claim',
      'transferStaffWhatsAppConversation POST /api/v1/staff/whatsapp/conversations/{id}/transfer',
      'addStaffWhatsAppNote POST /api/v1/staff/whatsapp/conversations/{id}/notes',
      'linkStaffWhatsAppConversation POST /api/v1/staff/whatsapp/conversations/{id}/link',
      'createStaffWhatsAppQuickReply POST /api/v1/staff/whatsapp/quick-replies',
      'getAdminWhatsAppConversations GET /api/v1/admin/whatsapp/conversations',
      'getAdminWhatsAppStatus GET /api/v1/admin/whatsapp/settings',
      'testAdminWhatsAppConnection POST /api/v1/admin/whatsapp/settings/test',
    ]) {
      expect(ids).toContain(op);
    }
  });
});

describe('D355 WhatsApp switched off', { timeout: 120_000 }, () => {
  let ctx: TestContext;
  const p = panel(() => ctx);
  beforeAll(async () => {
    ctx = await createTestApp({ ADMIN_TOTP_KEY: ADMIN_KEY });
  });
  afterAll(async () => {
    vi.useRealTimers();
    await ctx?.close();
  });

  it('without credentials: the badge says enabled false, the inbox and the webhook answer 503', async () => {
    expect(ctx.config.whatsapp.credentials).toBeNull();
    const support = await p.makeAdmin(['SUPPORT']);
    const s = await ctx.http.get('/api/v1/staff/whatsapp/summary').set(auth(support));
    expect(s.status, JSON.stringify(s.body)).toBe(200);
    expectContract(s, 'getStaffWhatsAppSummary');
    expect(s.body).toEqual({ enabled: false, badge: 0, mine: 0, unassigned: 0, unreadMessages: 0 });
    const l = await ctx.http.get('/api/v1/staff/whatsapp/conversations').set(auth(support));
    expect(l.status).toBe(503);
    expect(l.body.error.code).toBe('WHATSAPP_UNAVAILABLE');
    const w = await ctx.http
      .post('/api/v1/webhooks/whatsapp')
      .set('Content-Type', 'application/json')
      .send('{}');
    expect(w.status).toBe(503);
    const v = await ctx.http.get(
      '/api/v1/webhooks/whatsapp?hub.mode=subscribe&hub.verify_token=x&hub.challenge=1',
    );
    expect(v.status).toBe(503);
    const st = await p.send(support, 'get', '/admin/whatsapp/settings');
    expect(st.status).toBe(403); // SUPPORT has no support.whatsapp.manage
  });
});

describe('D355 WhatsApp inbox', { timeout: 600_000 }, () => {
  const accessToken = randomBytes(24).toString('base64url');
  const appSecret = randomBytes(16).toString('hex');
  const verifyToken = randomBytes(16).toString('base64url');
  const graph = new FakeWhatsAppGraph(accessToken, PNID, WABA);
  const push = new FakePushSender();
  const storage = new MemoryObjectStorage();
  let ctx: TestContext;
  const p = panel(() => ctx);
  let owner: Admin;
  let moderator: Admin;
  let support: Admin;
  let finance: Admin;
  let customer: Person;
  let convId = '';
  let seq = 0;

  const hook = (value: Parameters<typeof webhookBody>[1], secret = appSecret) => {
    const raw = webhookBody(PNID, value);
    return ctx.http
      .post('/api/v1/webhooks/whatsapp')
      .set('Content-Type', 'application/json')
      .set('X-Hub-Signature-256', signatureOf(raw, secret))
      .send(raw);
  };
  const textFrom = (phone: string, body: string, name = 'سارة', at = new Date()) => {
    seq += 1;
    return {
      contacts: [{ profile: { name }, wa_id: phone }],
      messages: [{ from: phone, id: `wamid.IN${seq}`, timestamp: unix(at), type: 'text', text: { body } }],
    };
  };
  const staff = (u: { token: string }, method: 'get' | 'post' | 'put' | 'patch' | 'delete', path: string) =>
    ctx.http[method](`/api/v1/staff/whatsapp${path}`).set(auth(u));
  const pushesTo = (u: Person, since: number) =>
    push.sent
      .slice(since)
      .filter((m) => m.data.kind === 'whatsapp' && m.tokens.some((t) => t.includes(u.id.slice(-8))));

  beforeAll(async () => {
    await graph.start();
    const dir = mkdtempSync(join(tmpdir(), 'kabso-wa-'));
    const file = (n: string, v: string) => {
      const path = join(dir, n);
      writeFileSync(path, v, { mode: 0o600 });
      return path;
    };
    ctx = await createTestApp(
      {
        ADMIN_TOTP_KEY: ADMIN_KEY,
        JWT_ACCESS_TTL_SECONDS: String(60 * 86_400),
        ADMIN_SESSION_IDLE_SECONDS: '86400',
        WHATSAPP_PHONE_NUMBER_ID: PNID,
        WHATSAPP_BUSINESS_ACCOUNT_ID: WABA,
        WHATSAPP_ACCESS_TOKEN_FILE: file('token', accessToken),
        WHATSAPP_APP_SECRET_FILE: file('secret', appSecret),
        WHATSAPP_VERIFY_TOKEN_FILE: file('verify', verifyToken),
        WHATSAPP_GRAPH_BASE_URL: graph.base,
        WHATSAPP_SWEEP_INTERVAL_SECONDS: '0',
        WHATSAPP_MEDIA_MAX_BYTES: '200000',
        // Every message pushes (the 30 s collapse would hide the later pushes of this fast test).
        WHATSAPP_PUSH_GAP_SECONDS: '0',
        API_PUBLIC_URL: 'https://api.kabso.example',
      },
      [
        { token: PUSH_SENDER, value: push },
        { token: OBJECT_STORAGE, value: storage },
      ],
    );
    owner = await p.makeAdmin(['OWNER']);
    moderator = await p.makeAdmin(['MODERATION']);
    support = await p.makeAdmin(['SUPPORT']);
    finance = await p.makeAdmin(['FINANCE']);
    customer = await p.signup();
    // The panel helper froze Date for the authenticator codes; the inbox orders by time, so real time from here.
    vi.useRealTimers();
    for (const u of [owner, moderator, support]) {
      const r = await ctx.http
        .put('/api/v1/me/push-token')
        .set(auth(u))
        .send({
          token: `fcm_${u.id.slice(-8)}${randomBytes(12).toString('hex')}:APA91b${randomBytes(16).toString('hex')}`,
          platform: 'ANDROID',
          appVersion: '1.0.0',
        });
      expect(r.status, JSON.stringify(r.body)).toBe(204);
    }
  });
  afterAll(async () => {
    vi.useRealTimers();
    await ctx?.close();
    await graph.stop();
  });

  it('answers Meta’s subscription check only with the verify token', async () => {
    const ok = await ctx.http.get(
      `/api/v1/webhooks/whatsapp?hub.mode=subscribe&hub.verify_token=${verifyToken}&hub.challenge=1158201444`,
    );
    expect(ok.status).toBe(200);
    expect(ok.text).toBe('1158201444');
    expect(ok.headers['content-type']).toMatch(/^text\/plain/);
    const bad = await ctx.http.get(
      '/api/v1/webhooks/whatsapp?hub.mode=subscribe&hub.verify_token=nope&hub.challenge=1',
    );
    expect(bad.status).toBe(403);
  });

  it('refuses a webhook without a valid signature and stores nothing', async () => {
    const forged = await hook(textFrom('966512345678', 'forged'), 'not-the-secret');
    expect(forged.status).toBe(403);
    const unsigned = await ctx.http
      .post('/api/v1/webhooks/whatsapp')
      .set('Content-Type', 'application/json')
      .send(webhookBody(PNID, textFrom('966512345678', 'unsigned')));
    expect(unsigned.status).toBe(403);
    expect(await ctx.prisma.waMessage.count()).toBe(0);
    expect(await ctx.prisma.auditLog.count({ where: { action: 'whatsapp.webhook.refused' } })).toBe(2);
  });

  it('stores an inbound text once (a retried delivery changes nothing) and pushes every agent', async () => {
    const before = push.sent.length;
    const body = textFrom('966512345678', 'السلام عليكم، لم يصلني الشحن');
    const r1 = await hook(body);
    expect(r1.status, JSON.stringify(r1.body)).toBe(200);
    expectContract(r1, 'receiveWhatsAppWebhook');
    expect(r1.body).toEqual({ received: true, events: 1 });
    const r2 = await hook(body);
    expect(r2.status).toBe(200);
    await settle(ctx);
    const conv = await ctx.prisma.waConversation.findUniqueOrThrow({ where: { phoneE164: '+966512345678' } });
    convId = conv.id;
    expect(conv).toMatchObject({ profileName: 'سارة', unreadCount: 1, status: 'OPEN', assignedToId: null });
    expect(await ctx.prisma.waMessage.count({ where: { conversationId: conv.id } })).toBe(1);
    // nobody on shift → every agent (OWNER, MODERATION, SUPPORT), never FINANCE; the second delivery pushes nothing.
    const sent = push.sent.slice(before).filter((m) => m.data.kind === 'whatsapp');
    expect(sent).toHaveLength(1);
    expect(sent[0]!.channel).toBe('staff');
    expect(sent[0]!.data).toMatchObject({ conversationId: conv.id });
    expect(sent[0]!.tokens).toHaveLength(3);
    expect(sent[0]!.body).toContain('سارة');
  });

  it('permissions: FINANCE and a plain account get 403; SUPPORT sees the inbox and the badge', async () => {
    for (const path of ['/summary', '/conversations']) {
      expect((await staff(finance, 'get', path)).status).toBe(403);
      expect((await staff(customer, 'get', path)).status).toBe(403);
    }
    expect((await p.send(finance, 'get', '/admin/whatsapp/conversations')).status).toBe(403);
    const s = await staff(support, 'get', '/summary');
    expect(s.status).toBe(200);
    expectContract(s, 'getStaffWhatsAppSummary');
    expect(s.body).toEqual({ enabled: true, badge: 1, mine: 0, unassigned: 1, unreadMessages: 1 });
    const l = await staff(support, 'get', '/conversations?filter=unassigned');
    expect(l.status).toBe(200);
    expectContract(l, 'getStaffWhatsAppConversations');
    expect(l.body.data.map((c: { id: string }) => c.id)).toEqual([convId]);
    expect(l.body.data[0]).toMatchObject({ phone: '+966512345678', name: 'سارة', window: { open: true } });
    const search = await staff(support, 'get', `/conversations?q=${encodeURIComponent('+9665123')}`);
    expect(search.body.data).toHaveLength(1);
    const none = await staff(support, 'get', '/conversations?q=nobody');
    expect(none.body.data).toHaveLength(0);
    expect((await staff(support, 'get', '/conversations?filter=mine')).body.data).toHaveLength(0);
    const m = await staff(support, 'get', `/conversations/${convId}/messages`);
    expect(m.status).toBe(200);
    expectContract(m, 'getStaffWhatsAppMessages');
    expect(m.body.data[0]).toMatchObject({ direction: 'INBOUND', type: 'TEXT', status: 'RECEIVED' });
  });

  it('a reply claims the conversation; another agent is refused; statuses move forward only', async () => {
    const r = await staff(support, 'post', `/conversations/${convId}/messages`).send({
      type: 'TEXT',
      text: 'وعليكم السلام، نتحقق الآن',
    });
    expect(r.status, JSON.stringify(r.body)).toBe(201);
    expectContract(r, 'sendStaffWhatsAppMessage');
    expect(r.body).toMatchObject({ direction: 'OUTBOUND', status: 'SENT', sentBy: { userId: support.id } });
    expect(graph.sent.at(-1)).toMatchObject({
      messaging_product: 'whatsapp',
      to: '966512345678',
      type: 'text',
      text: { body: 'وعليكم السلام، نتحقق الآن' },
    });
    const c = await staff(support, 'get', `/conversations/${convId}`);
    expect(c.body).toMatchObject({ assignedToMe: true, assignedTo: { userId: support.id } });
    const other = await staff(moderator, 'post', `/conversations/${convId}/messages`).send({
      type: 'TEXT',
      text: 'x',
    });
    expect(other.status).toBe(409);
    expect(other.body.error.code).toBe('WHATSAPP_CONVERSATION_ASSIGNED');
    const claim = await staff(moderator, 'post', `/conversations/${convId}/claim`);
    expect(claim.status).toBe(409);

    const wamid = (await ctx.prisma.waMessage.findFirstOrThrow({ where: { direction: 'OUTBOUND' } }))
      .waMessageId!;
    for (const status of ['delivered', 'read', 'delivered', 'sent']) {
      expect(
        (await hook({ statuses: [{ id: wamid, status, timestamp: unix(), recipient_id: '966512345678' }] }))
          .status,
      ).toBe(200);
    }
    expect((await ctx.prisma.waMessage.findFirstOrThrow({ where: { waMessageId: wamid } })).status).toBe(
      'READ',
    );
    const failed = await staff(support, 'post', `/conversations/${convId}/messages`).send({
      type: 'TEXT',
      text: 'ثانية',
    });
    expect(failed.status).toBe(201);
    const wamid2 = (await ctx.prisma.waMessage.findFirstOrThrow({ where: { id: failed.body.id as string } }))
      .waMessageId!;
    await hook({
      statuses: [
        {
          id: wamid2,
          status: 'failed',
          timestamp: unix(),
          errors: [{ code: 131026, title: 'Message undeliverable' }],
        },
      ],
    });
    const m = await staff(support, 'get', `/conversations/${convId}/messages?limit=1`);
    expect(m.body.data[0]).toMatchObject({
      status: 'FAILED',
      error: { code: 131026, title: 'Message undeliverable' },
    });
    expect(m.body.page.hasMore).toBe(true);
    const next = await staff(
      support,
      'get',
      `/conversations/${convId}/messages?limit=1&cursor=${encodeURIComponent(m.body.page.nextCursor as string)}`,
    );
    expect(next.status).toBe(200);
    expect(next.body.data[0].id).not.toBe(m.body.data[0].id);
    const forged = await staff(support, 'get', `/conversations/${convId}/messages?cursor=abc.def`);
    expect(forged.status).toBe(400);
    // Meta refuses: 502 with Meta's code, nothing stored; a throughput code → 429.
    const count = await ctx.prisma.waMessage.count();
    graph.failNext = { status: 400, code: 131026, title: 'Message undeliverable' };
    const refused = await staff(support, 'post', `/conversations/${convId}/messages`).send({
      type: 'TEXT',
      text: 'x',
    });
    expect(refused.status).toBe(502);
    expect(refused.body.error).toMatchObject({
      code: 'WHATSAPP_SEND_FAILED',
      details: [{ field: 'whatsapp', issue: 'meta_131026' }],
    });
    graph.failNext = { status: 400, code: 131056, title: 'Pair rate limit hit' };
    const limited = await staff(support, 'post', `/conversations/${convId}/messages`).send({
      type: 'TEXT',
      text: 'x',
    });
    expect(limited.status).toBe(429);
    expect(limited.headers['retry-after']).toBe('60');
    expect(await ctx.prisma.waMessage.count()).toBe(count);
  });

  it('marks read: unread 0 and Meta gets the read receipt of the last inbound message', async () => {
    const r = await staff(support, 'post', `/conversations/${convId}/read`);
    expect(r.status).toBe(200);
    expectContract(r, 'markStaffWhatsAppRead');
    expect(r.body.unreadCount).toBe(0);
    const firstIn = await ctx.prisma.waMessage.findFirstOrThrow({ where: { direction: 'INBOUND' } });
    expect(graph.reads).toEqual([firstIn.waMessageId]);
    expect((await staff(support, 'get', '/summary')).body.badge).toBe(0);
  });

  it('inbound media: stored privately when allowed, refused by type or size; a reaction marks its message', async () => {
    const jpeg = Buffer.concat([Buffer.from([0xff, 0xd8, 0xff]), randomBytes(500)]);
    graph.addMedia('m-img', jpeg, 'image/jpeg');
    graph.addMedia('m-exe', randomBytes(100), 'application/x-msdownload');
    graph.addMedia('m-big', randomBytes(250_000), 'video/mp4');
    graph.addMedia('m-voice', randomBytes(300), 'audio/ogg');
    const from = '966512345678';
    await hook({
      messages: [
        {
          from,
          id: 'wamid.IMG',
          timestamp: unix(),
          type: 'image',
          image: { id: 'm-img', mime_type: 'image/jpeg', caption: 'الإيصال' },
        },
        {
          from,
          id: 'wamid.EXE',
          timestamp: unix(),
          type: 'document',
          document: { id: 'm-exe', mime_type: 'application/x-msdownload', filename: 'a.exe' },
        },
        {
          from,
          id: 'wamid.BIG',
          timestamp: unix(),
          type: 'video',
          video: { id: 'm-big', mime_type: 'video/mp4' },
        },
        {
          from,
          id: 'wamid.VOICE',
          timestamp: unix(),
          type: 'audio',
          audio: { id: 'm-voice', mime_type: 'audio/ogg; codecs=opus', voice: true },
        },
        {
          from,
          id: 'wamid.LOC',
          timestamp: unix(),
          type: 'location',
          location: { latitude: 24.71, longitude: 46.67, name: 'الرياض' },
        },
        {
          from,
          id: 'wamid.REACT',
          timestamp: unix(),
          type: 'reaction',
          reaction: { message_id: 'wamid.OUT1', emoji: '👍' },
        },
      ],
    });
    await settle(ctx);
    const state = async (wamid: string) =>
      (await ctx.prisma.waMessage.findUniqueOrThrow({ where: { waMessageId: wamid } })).mediaState;
    expect(await state('wamid.IMG')).toBe('STORED');
    expect(await state('wamid.EXE')).toBe('TYPE_REFUSED');
    expect(await state('wamid.BIG')).toBe('TOO_LARGE');
    expect(await state('wamid.VOICE')).toBe('STORED');
    const img = await ctx.prisma.waMessage.findUniqueOrThrow({ where: { waMessageId: 'wamid.IMG' } });
    expect(img.mediaKey).toMatch(/^private\/whatsapp\//);
    const file = await staff(support, 'get', `/messages/${img.id}/media`).buffer(true);
    expect(file.status).toBe(200);
    expect(file.headers['content-type']).toBe('image/jpeg');
    expect(file.headers['cache-control']).toBe('private, no-store');
    expect(Buffer.compare(file.body as Buffer, jpeg)).toBe(0);
    const exe = await ctx.prisma.waMessage.findUniqueOrThrow({ where: { waMessageId: 'wamid.EXE' } });
    expect((await staff(support, 'get', `/messages/${exe.id}/media`)).status).toBe(404);
    const out1 = await ctx.prisma.waMessage.findUniqueOrThrow({ where: { waMessageId: 'wamid.OUT1' } });
    expect(out1.reactionEmoji).toBe('👍');
    const list = await staff(support, 'get', `/conversations/${convId}/messages?limit=50`);
    expectContract(list, 'getStaffWhatsAppMessages');
    expect(list.body.data.some((m: { type: string }) => m.type === 'REACTION')).toBe(false);
    expect(list.body.data.find((m: { id: string }) => m.id === img.id)).toMatchObject({
      type: 'IMAGE',
      text: 'الإيصال',
      media: { state: 'STORED', mime: 'image/jpeg' },
    });
    // 5 new messages (the reaction is not one); the assigned agent alone is pushed.
    expect((await staff(support, 'get', `/conversations/${convId}`)).body.unreadCount).toBe(5);
  });

  it('outbound media: allowlisted raw bytes are uploaded to Meta and kept for the inbox', async () => {
    const png = Buffer.concat([Buffer.from([0x89, 0x50, 0x4e, 0x47]), randomBytes(200)]);
    const r = await staff(
      support,
      'post',
      `/conversations/${convId}/media?mime=image/png&caption=${encodeURIComponent('الخطوات')}`,
    )
      .set('Content-Type', 'application/octet-stream')
      .send(png);
    expect(r.status, JSON.stringify(r.body)).toBe(201);
    expectContract(r, 'sendStaffWhatsAppMedia');
    expect(r.body).toMatchObject({
      type: 'IMAGE',
      text: 'الخطوات',
      media: { state: 'STORED', mime: 'image/png' },
    });
    expect(graph.uploads.at(-1)?.type).toBe('image/png');
    expect(graph.sent.at(-1)).toMatchObject({
      type: 'image',
      image: { id: expect.stringMatching(/^up-/) as string, caption: 'الخطوات' },
    });
    const bad = await staff(support, 'post', `/conversations/${convId}/media?mime=application/x-msdownload`)
      .set('Content-Type', 'application/octet-stream')
      .send(png);
    expect(bad.status).toBe(400);
  });

  it('the 24-hour window: free-form refused after it, an approved template allowed', async () => {
    await ctx.prisma.waConversation.update({
      where: { id: convId },
      data: { lastInboundAt: new Date(Date.now() - 25 * 3600_000) },
    });
    const c = await staff(support, 'get', `/conversations/${convId}`);
    expect(c.body.window.open).toBe(false);
    const t = await staff(support, 'post', `/conversations/${convId}/messages`).send({
      type: 'TEXT',
      text: 'مرحبا',
    });
    expect(t.status).toBe(409);
    expect(t.body.error.code).toBe('WHATSAPP_WINDOW_CLOSED');
    const media = await staff(support, 'post', `/conversations/${convId}/media?mime=image/png`)
      .set('Content-Type', 'application/octet-stream')
      .send(randomBytes(10));
    expect(media.status).toBe(409);
    const list = await staff(support, 'get', '/templates');
    expect(list.status).toBe(200);
    expectContract(list, 'getStaffWhatsAppTemplates');
    expect(list.body.data.map((x: { name: string }) => x.name)).toEqual(['kabso_followup', 'kabso_hello']);
    expect(list.body.data[0].parameterCount).toBe(2);
    const wrong = await staff(support, 'post', `/conversations/${convId}/messages`).send({
      type: 'TEMPLATE',
      template: { name: 'kabso_followup', language: 'ar', parameters: ['سارة'] },
    });
    expect(wrong.status).toBe(400);
    const draft = await staff(support, 'post', `/conversations/${convId}/messages`).send({
      type: 'TEMPLATE',
      template: { name: 'kabso_draft', language: 'ar' },
    });
    expect(draft.status).toBe(400);
    const ok = await staff(support, 'post', `/conversations/${convId}/messages`).send({
      type: 'TEMPLATE',
      template: { name: 'kabso_followup', language: 'ar', parameters: ['سارة', '#42'] },
    });
    expect(ok.status, JSON.stringify(ok.body)).toBe(201);
    expectContract(ok, 'sendStaffWhatsAppMessage');
    expect(ok.body).toMatchObject({
      type: 'TEMPLATE',
      text: 'مرحباً سارة، هل ما زلت تحتاج المساعدة في طلبك #42؟',
      template: { name: 'kabso_followup', language: 'ar' },
    });
    expect(graph.sent.at(-1)).toMatchObject({
      type: 'template',
      template: {
        name: 'kabso_followup',
        language: { code: 'ar' },
        components: [
          {
            type: 'body',
            parameters: [
              { type: 'text', text: 'سارة' },
              { type: 'text', text: '#42' },
            ],
          },
        ],
      },
    });
    // The customer answers: the window opens again.
    await hook(textFrom('966512345678', 'نعم'));
    expect((await staff(support, 'get', `/conversations/${convId}`)).body.window.open).toBe(true);
  });

  it('transfer, release, claim, close (a new message reopens) with the history', async () => {
    const tr = await staff(support, 'post', `/conversations/${convId}/transfer`).send({
      toUserId: moderator.id,
    });
    expect(tr.status, JSON.stringify(tr.body)).toBe(200);
    expectContract(tr, 'transferStaffWhatsAppConversation');
    expect(tr.body.assignedTo.userId).toBe(moderator.id);
    const toFinance = await staff(moderator, 'post', `/conversations/${convId}/transfer`).send({
      toUserId: finance.id,
    });
    expect(toFinance.status).toBe(400);
    expect((await staff(support, 'post', `/conversations/${convId}/release`)).status).toBe(409);
    expect((await staff(moderator, 'post', `/conversations/${convId}/release`)).body.assignedTo).toBeNull();
    expect((await staff(owner, 'post', `/conversations/${convId}/claim`)).body.assignedTo.userId).toBe(
      owner.id,
    );
    const closed = await staff(owner, 'post', `/conversations/${convId}/close`);
    expect(closed.body).toMatchObject({ status: 'CLOSED', unreadCount: 0 });
    const send = await staff(owner, 'post', `/conversations/${convId}/messages`).send({
      type: 'TEXT',
      text: 'x',
    });
    expect(send.body.error.code).toBe('WHATSAPP_CONVERSATION_CLOSED');
    expect((await staff(owner, 'get', '/conversations?filter=closed')).body.data).toHaveLength(1);
    const before = push.sent.length;
    await hook(textFrom('966512345678', 'عندي سؤال آخر'));
    await settle(ctx);
    const reopened = await staff(owner, 'get', `/conversations/${convId}`);
    expect(reopened.body).toMatchObject({ status: 'OPEN', assignedTo: { userId: owner.id }, unreadCount: 1 });
    // assigned → only the assignee is pushed
    const sent = push.sent.slice(before).filter((m) => m.data.kind === 'whatsapp');
    expect(sent).toHaveLength(1);
    expect(sent[0]!.tokens).toHaveLength(1);
    expect(sent[0]!.tokens[0]).toContain(owner.id.slice(-8));
    const h = await staff(owner, 'get', `/conversations/${convId}/assignments`);
    expectContract(h, 'getStaffWhatsAppAssignments');
    expect(h.body.data.map((a: { action: string }) => a.action)).toEqual([
      'REOPEN',
      'CLOSE',
      'CLAIM',
      'RELEASE',
      'TRANSFER',
      'CLAIM',
    ]);
    expect(h.body.data[0].by).toBeNull();
  });

  it('notes stay internal; quick replies are managed by OWNER / MODERATION only', async () => {
    const sentBefore = graph.sent.length;
    const n = await staff(support, 'post', `/conversations/${convId}/notes`).send({
      body: 'العميل أرسل الإيصال، ننتظر المالية',
    });
    expect(n.status).toBe(201);
    expectContract(n, 'addStaffWhatsAppNote');
    const list = await staff(owner, 'get', `/conversations/${convId}/notes`);
    expect(list.body.data).toHaveLength(1);
    expect(list.body.data[0].author.userId).toBe(support.id);
    expect(graph.sent.length).toBe(sentBefore);

    expect(
      (await staff(support, 'post', '/quick-replies').send({ title: 'ترحيب', body: 'أهلاً بك' })).status,
    ).toBe(403);
    const q = await staff(moderator, 'post', '/quick-replies').send({
      title: 'ترحيب',
      body: 'أهلاً بك في دعم Kabso Live',
    });
    expect(q.status).toBe(201);
    expectContract(q, 'createStaffWhatsAppQuickReply');
    expect(
      (await staff(moderator, 'post', '/quick-replies').send({ title: 'ترحيب', body: 'x' })).status,
    ).toBe(400);
    const upd = await p.send(owner, 'patch', `/admin/whatsapp/quick-replies/${q.body.id as string}`, {
      body: 'أهلاً وسهلاً',
    });
    expect(upd.status).toBe(200);
    expectContract(upd, 'updateAdminWhatsAppQuickReply');
    const read = await staff(support, 'get', '/quick-replies');
    expect(read.body.data).toEqual([expect.objectContaining({ title: 'ترحيب', body: 'أهلاً وسهلاً' })]);
    const del = await p.send(owner, 'delete', `/admin/whatsapp/quick-replies/${q.body.id as string}`);
    expect(del.status).toBe(204);
  });

  it('links the conversation to the account the customer named and shows only the card', async () => {
    const profile = await ctx.prisma.userProfile.findUniqueOrThrow({ where: { userId: customer.id } });
    const missing = await staff(owner, 'post', `/conversations/${convId}/link`).send({
      username: 'nobody_here_x',
    });
    expect(missing.status).toBe(400);
    const l = await staff(owner, 'post', `/conversations/${convId}/link`).send({
      username: `@${profile.username}`,
    });
    expect(l.status, JSON.stringify(l.body)).toBe(200);
    expectContract(l, 'linkStaffWhatsAppConversation');
    expect(l.body.linkedAccount).toEqual({
      userId: customer.id,
      username: profile.username,
      displayName: profile.displayName,
      avatarUrl: profile.avatarUrl,
      status: 'ACTIVE',
      countryCode: profile.countryCode,
      createdAt: expect.any(String) as string,
    });
    expect(JSON.stringify(l.body)).not.toContain(customer.email);
    expect(
      await ctx.prisma.auditLog.count({ where: { action: 'whatsapp.conversation.link', targetId: convId } }),
    ).toBe(1);
  });

  it('the push mute and the shift: on-shift agents first, a muted agent never', async () => {
    const mute = await staff(support, 'put', '/me/settings').send({ pushMuted: true });
    expect(mute.status).toBe(200);
    expectContract(mute, 'updateStaffWhatsAppMySettings');
    // Staff work switched everyone's shift on (D286): only the moderator stays on shift here.
    await ctx.prisma.adminShift.updateMany({ data: { onShift: false } });
    await ctx.prisma.adminShift.upsert({
      where: { userId: moderator.id },
      create: { userId: moderator.id, onShift: true },
      update: { onShift: true },
    });
    const before = push.sent.length;
    await hook(textFrom('966598765432', 'استفسار جديد', 'Omar'));
    await settle(ctx);
    const sent = push.sent.slice(before).filter((m) => m.data.kind === 'whatsapp');
    expect(sent).toHaveLength(1);
    expect(sent[0]!.tokens).toHaveLength(1);
    expect(sent[0]!.tokens[0]).toContain(moderator.id.slice(-8));
    expect(pushesTo(support, before)).toHaveLength(0);
    const s = await staff(support, 'get', '/summary');
    expect(s.body).toMatchObject({ unassigned: 1 });
  });

  it('the panel: the same inbox, the settings (no secret) and the connection test', async () => {
    const l = await p.send(owner, 'get', '/admin/whatsapp/conversations?filter=all');
    expect(l.status).toBe(200);
    expectContract(l, 'getAdminWhatsAppConversations');
    expect(l.body.data).toHaveLength(2);
    const st = await p.send(moderator, 'get', '/admin/whatsapp/settings');
    expect(st.status).toBe(200);
    expectContract(st, 'getAdminWhatsAppStatus');
    expect(st.body).toMatchObject({
      enabled: true,
      phoneNumberId: PNID,
      webhookUrl: 'https://api.kabso.example/api/v1/webhooks/whatsapp',
      missing: [],
    });
    const text = JSON.stringify(st.body);
    for (const secret of [accessToken, appSecret, verifyToken]) expect(text).not.toContain(secret);
    expect((await p.send(support, 'get', '/admin/whatsapp/settings')).status).toBe(403);
    const t = await p.send(owner, 'post', '/admin/whatsapp/settings/test');
    expect(t.status).toBe(200);
    expectContract(t, 'testAdminWhatsAppConnection');
    expect(t.body).toMatchObject({
      ok: true,
      verifiedName: 'Kabso Live',
      qualityRating: 'GREEN',
      templates: 2,
    });
    const pm = await p.send(owner, 'post', `/admin/whatsapp/conversations/${convId}/messages`, {
      type: 'TEXT',
      text: 'من اللوحة',
    });
    expect(pm.status, JSON.stringify(pm.body)).toBe(201);
    expectContract(pm, 'sendAdminWhatsAppMessage');
    expect(graph.badAuth).toBe(0);
  });

  it('the data export lists the linked conversation; the account purge and the retention delete it with its media', async () => {
    const exp = await buildDataExport(ctx.prisma, {
      userId: customer.id,
      now: new Date(),
      mediaBaseUrl: 'https://media.example',
      supportEmail: 'support@kabso.example',
      storage: null,
    });
    expect(exp.counts.whatsapp).toBeGreaterThan(5);
    const keys = (
      await ctx.prisma.waMessage.findMany({ where: { conversationId: convId, mediaKey: { not: null } } })
    ).map((m) => m.mediaKey!);
    expect(keys.length).toBeGreaterThan(0);
    for (const k of keys) expect(storage.objects.has(k)).toBe(true);
    await withMigrationClient((db) =>
      db.$transaction((tx) =>
        purgeAccountIn(tx, customer.id, new Date(), {
          quarantineDays: 0,
          specialGraceDays: 0,
          legalHoldDays: 0,
          via: 'ADMIN',
        }),
      ),
    );
    expect((await staff(owner, 'get', `/conversations/${convId}`)).status).toBe(404);
    const sweeper = ctx.app.get(WhatsAppSweeper);
    const first = await sweeper.purgeOnce();
    expect(first.conversations).toBe(1);
    expect(await ctx.prisma.waConversation.count({ where: { id: convId } })).toBe(0);
    for (const k of keys) expect(storage.objects.has(k)).toBe(false);
    // retention: the other conversation ages out after WHATSAPP_RETENTION_DAYS.
    await ctx.prisma.waConversation.updateMany({
      data: { lastMessageAt: new Date(Date.now() - 181 * 86_400_000) },
    });
    expect((await sweeper.purgeOnce()).conversations).toBe(1);
    expect(await ctx.prisma.waConversation.count()).toBe(0);
    expect(await ctx.prisma.auditLog.count({ where: { action: 'whatsapp.retention.purge' } })).toBe(2);
  });
});
