/**
 * D385 (owner 2026-11-12; contract v1.137-social, CONVENTIONS §10.174): «دعم كابسو» — the in-app support chat answered
 * in the staff WhatsApp inbox (channel IN_APP) — and the pinned chats at the top of «الرسائل». End to end against
 * PostgreSQL + Redis with in-memory object storage, a fake push sender and (for both channels side by side) a fake
 * Graph API on a local port. Covers: the person's ticket flow (topic, text / picture / voice, the idempotent retry,
 * «تم الاستلام» then read, the staff reply with the first name only, the push, close and a new ticket with a new
 * topic), the inbox without the WhatsApp credentials and with both channels, VIP priority, the levels (VIEW / REPLY /
 * NONE), nobody reading another person's thread, the in-app refusals (templates, media, link), the sweeper, the rate
 * limit, and pins (5 at most with 409, order, two devices, unpin, groups, support never counted, presence rules).
 */
import { randomBytes, randomUUID } from 'node:crypto';
import { mkdtempSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import sharp from 'sharp';
import { afterAll, beforeAll, describe, expect, it, vi } from 'vitest';
import { OBJECT_STORAGE } from '../src/modules/media/object-storage.js';
import {
  PUSH_SENDER,
  type PushMessage,
  type PushSender,
  type PushSendResult,
} from '../src/modules/push/push-sender.js';
import { WhatsAppSweeper } from '../src/modules/whatsapp/whatsapp.sweeper.js';
import { panel, type Admin, type Person } from './helpers/admin-panel.js';
import { FakeWhatsAppGraph, signatureOf, webhookBody } from './helpers/fake-whatsapp.js';
import { m4a } from './helpers/m4a.js';
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
const VIP1 = '01a25200-0000-7000-8000-000000000001';
const DAY = 86_400_000;
const auth = (u: { token: string }) => ({ Authorization: `Bearer ${u.token}` });
const MEDIA_ON = {
  MEDIA_UPLOADS_ENABLED: 'true',
  S3_BUCKET: 'kabso-media-test',
  S3_ACCESS_KEY_ID: 'test',
  S3_SECRET_ACCESS_KEY: 'test',
  MEDIA_PUBLIC_BASE_URL: 'https://media.example.test',
};

interface Thread {
  id: string | null;
  status: string;
  department: string | null;
  unreadCount: number;
}
interface SupportMsg {
  id: string;
  mine: boolean;
  kind: string;
  text: string | null;
  media: { id: string; type: string } | null;
  staff: { firstName: string | null } | null;
  receipt: string | null;
}

describe('D385 contract coverage', () => {
  it('openapi v1.137-social declares the support and pin operations', () => {
    const ids = operations().map((o) => `${o.operationId} ${o.method.toUpperCase()} ${o.path}`);
    for (const op of [
      'getSupportThread GET /api/v1/support/thread',
      'listSupportMessages GET /api/v1/support/thread/messages',
      'sendSupportMessage POST /api/v1/support/thread/messages',
      'readSupportThread POST /api/v1/support/thread/read',
      'listDmPins GET /api/v1/dm/pins',
      'pinDmConversation PUT /api/v1/dm/conversations/{conversationId}/pin',
      'unpinDmConversation DELETE /api/v1/dm/conversations/{conversationId}/pin',
      'pinDmGroup PUT /api/v1/dm/groups/{groupId}/pin',
      'unpinDmGroup DELETE /api/v1/dm/groups/{groupId}/pin',
    ]) {
      expect(ids).toContain(op);
    }
  });
});

describe('D385 «دعم كابسو» without the WhatsApp credentials', { timeout: 600_000 }, () => {
  const push = new FakePushSender();
  const storage = new MemoryObjectStorage();
  let ctx: TestContext;
  const p = panel(() => ctx);
  let owner: Admin;
  let support: Admin;
  let viewer: Admin;
  let finance: Admin;
  let alice: Person;
  let bob: Person;

  const staff = (u: { token: string }, method: 'get' | 'post' | 'put' | 'delete', path: string) =>
    ctx.http[method](`/api/v1/staff/whatsapp${path}`).set(auth(u));
  const thread = async (u: Person): Promise<Thread> => {
    const r = await ctx.http.get('/api/v1/support/thread').set(auth(u));
    expect(r.status, JSON.stringify(r.body)).toBe(200);
    expectContract(r, 'getSupportThread');
    return r.body as Thread;
  };
  const messagesOf = async (u: Person) => {
    const r = await ctx.http.get('/api/v1/support/thread/messages').set(auth(u));
    expect(r.status, JSON.stringify(r.body)).toBe(200);
    expectContract(r, 'listSupportMessages');
    return r.body as { data: SupportMsg[]; thread: Thread };
  };
  const write = (u: Person, body: Record<string, unknown>) =>
    ctx.http
      .post('/api/v1/support/thread/messages')
      .set(auth(u))
      .send({ clientId: randomUUID(), ...body });
  const upload = async (u: Person, kind: string, contentType: string, bytes: Buffer) => {
    const slot = await ctx.http
      .post('/api/v1/media/uploads')
      .set(auth(u))
      .send({ kind, contentType, byteSize: bytes.length });
    expect(slot.status, JSON.stringify(slot.body)).toBe(201);
    expect(storage.upload(slot.body.uploadUrl, bytes, contentType)).toBe(true);
    const done = await ctx.http.post(`/api/v1/media/uploads/${slot.body.uploadId}/complete`).set(auth(u));
    expect(done.status, JSON.stringify(done.body)).toBe(200);
    return done.body as { id: string };
  };
  const receipt = async (u: Person) =>
    upload(
      u,
      'DM_IMAGE',
      'image/jpeg',
      await sharp({
        create: { width: 320, height: 480, channels: 3, background: { r: 240, g: 240, b: 240 } },
      })
        .jpeg()
        .toBuffer(),
    );
  const setLevel = async (target: Person, level: string) => {
    const r = await p.send(owner, 'put', `/admin/team/${target.id}/whatsapp`, {
      level,
      reason: 'D385 test',
      totpCode: p.nextCode(owner.secret),
    });
    vi.useRealTimers();
    expect(r.status, JSON.stringify(r.body)).toBe(200);
  };
  const pushesTo = (u: Person, since: number, kind: string) =>
    push.sent
      .slice(since)
      .filter((m) => m.data.kind === kind && m.tokens.some((t) => t.includes(u.id.slice(-8))));

  beforeAll(async () => {
    ctx = await createTestApp(
      {
        ...MEDIA_ON,
        ADMIN_TOTP_KEY: ADMIN_KEY,
        JWT_ACCESS_TTL_SECONDS: String(60 * 86_400),
        ADMIN_SESSION_IDLE_SECONDS: '86400',
        WHATSAPP_SWEEP_INTERVAL_SECONDS: '0',
        WHATSAPP_PUSH_GAP_SECONDS: '0',
      },
      [
        { token: PUSH_SENDER, value: push },
        { token: OBJECT_STORAGE, value: storage },
      ],
    );
    expect(ctx.config.whatsapp.credentials).toBeNull();
    owner = await p.makeAdmin(['OWNER']);
    support = await p.makeAdmin(['SUPPORT']);
    viewer = await p.makeAdmin(['SUPPORT']);
    finance = await p.makeAdmin(['FINANCE']);
    await setLevel(viewer, 'VIEW');
    alice = await p.signup();
    bob = await p.signup();
    vi.useRealTimers();
    await withMigrationClient((db) =>
      db.userProfile.update({ where: { userId: support.id }, data: { displayName: 'Sara Ahmed Staff' } }),
    );
    for (const u of [owner, support, viewer, alice]) {
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
  });

  it('every account has the thread (NONE); the first message needs a topic', async () => {
    expect(await thread(alice)).toEqual({
      id: null,
      status: 'NONE',
      department: null,
      unreadCount: 0,
      lastMessageAt: null,
      lastPreview: null,
    });
    expect((await messagesOf(alice)).data).toEqual([]);
    const noTopic = await write(alice, { kind: 'TEXT', text: 'لم يصلني الشحن' });
    expect(noTopic.status).toBe(400);
    expect(noTopic.body.error.details).toEqual([{ field: 'topic', issue: 'required' }]);
    const badTopic = await write(alice, { kind: 'TEXT', text: 'x', topic: 'BILLING' });
    expect(badTopic.status).toBe(400);
    const both = await write(alice, { kind: 'TEXT', text: 'x', mediaId: randomUUID(), topic: 'GENERAL' });
    expect(both.status).toBe(400);
    expect(await ctx.prisma.waConversation.count()).toBe(0);
  });

  it('opens a ticket with the topic, stores text / picture / voice once and pushes the team', async () => {
    const before = push.sent.length;
    const clientId = randomUUID();
    const first = await write(alice, { kind: 'TEXT', text: 'لم يصلني الشحن', topic: 'PAYMENTS', clientId });
    expect(first.status, JSON.stringify(first.body)).toBe(201);
    expectContract(first, 'sendSupportMessage');
    expect(first.body.message).toMatchObject({ mine: true, kind: 'TEXT', receipt: 'RECEIVED', staff: null });
    expect(first.body.thread).toMatchObject({ status: 'OPEN', department: 'PAYMENTS', unreadCount: 0 });
    // A retry with the same clientId: 200, the same message, nothing new.
    const again = await write(alice, { kind: 'TEXT', text: 'لم يصلني الشحن', topic: 'PAYMENTS', clientId });
    expect(again.status).toBe(200);
    expectContract(again, 'sendSupportMessage');
    expect(again.body.message.id).toBe(first.body.message.id);
    // With an open ticket the topic is not needed (and ignored when given).
    const pic = await receipt(alice);
    const photo = await write(alice, { kind: 'IMAGE', mediaId: pic.id, topic: 'GENERAL' });
    expect(photo.status, JSON.stringify(photo.body)).toBe(201);
    expect(photo.body.message.media).toMatchObject({ id: pic.id, type: 'IMAGE' });
    expect(photo.body.thread.department).toBe('PAYMENTS');
    // The same upload cannot be attached twice; a picture is not a voice clip.
    expect((await write(alice, { kind: 'IMAGE', mediaId: pic.id })).status).toBe(400);
    const clip = await upload(alice, 'DM_VOICE', 'audio/mp4', m4a({ durationMs: 3_000 }));
    expect((await write(alice, { kind: 'IMAGE', mediaId: clip.id })).status).toBe(400);
    const voice = await write(alice, { kind: 'VOICE', mediaId: clip.id });
    expect(voice.status, JSON.stringify(voice.body)).toBe(201);
    expect(voice.body.message).toMatchObject({ kind: 'VOICE', media: { id: clip.id, type: 'AUDIO' } });
    const conv = await ctx.prisma.waConversation.findFirstOrThrow({ where: { linkedUserId: alice.id } });
    expect(conv).toMatchObject({
      channel: 'IN_APP',
      phoneE164: null,
      waId: null,
      status: 'OPEN',
      department: 'PAYMENTS',
      unreadCount: 3,
      assignedToId: null,
    });
    expect(await ctx.prisma.waMessage.count({ where: { conversationId: conv.id } })).toBe(3);
    expect(await ctx.prisma.auditLog.count({ where: { action: 'support.ticket.open' } })).toBe(1);
    await settle(ctx);
    const alerts = push.sent.slice(before).filter((m) => m.data.kind === 'whatsapp');
    expect(alerts.length).toBeGreaterThan(0);
    expect(alerts[0]!.channel).toBe('staff');
    expect(alerts[0]!.data).toMatchObject({ conversationId: conv.id, source: 'IN_APP' });
    expect([alerts[0]!.title]).toEqual(
      expect.arrayContaining([expect.stringMatching(/دعم كابسو|Kabso Support/)]),
    );
  });

  it('the inbox serves it without WhatsApp: summary, list «داخل التطبيق», messages, the media', async () => {
    const s = await staff(support, 'get', '/summary');
    expect(s.status).toBe(200);
    expectContract(s, 'getStaffWhatsAppSummary');
    expect(s.body).toEqual({
      enabled: false,
      inApp: true,
      badge: 1,
      mine: 0,
      unassigned: 1,
      unreadMessages: 3,
    });
    const list = await staff(support, 'get', '/conversations');
    expect(list.status, JSON.stringify(list.body)).toBe(200);
    expectContract(list, 'getStaffWhatsAppConversations');
    expect(list.body.data).toHaveLength(1);
    const row = list.body.data[0];
    expect(row).toMatchObject({
      channel: 'IN_APP',
      phone: null,
      window: { open: true, closesAt: null },
      department: 'PAYMENTS',
      linkedAccount: { userId: alice.id },
    });
    // Asking for WhatsApp threads while it is off: 503 as before.
    expect((await staff(support, 'get', '/conversations?channel=WHATSAPP')).status).toBe(503);
    expect((await staff(support, 'get', '/conversations?channel=IN_APP')).body.data).toHaveLength(1);
    const msgs = await staff(support, 'get', `/conversations/${row.id}/messages`);
    expect(msgs.status).toBe(200);
    expectContract(msgs, 'getStaffWhatsAppMessages');
    const image = (msgs.body.data as { id: string; type: string; media: { state: string } | null }[]).find(
      (m) => m.type === 'IMAGE',
    )!;
    expect(image.media?.state).toBe('STORED');
    const bytes = await staff(support, 'get', `/messages/${image.id}/media`).buffer(true);
    expect(bytes.status).toBe(200);
    expect(bytes.headers['content-type']).toMatch(/^image\//);
    // The panel lists it too.
    const panelList = await p.send(owner, 'get', '/admin/whatsapp/conversations');
    vi.useRealTimers();
    expect(panelList.status).toBe(200);
    expectContract(panelList, 'getAdminWhatsAppConversations');
    expect(panelList.body.data.map((c: { channel: string }) => c.channel)).toEqual(['IN_APP']);
  });

  it('levels: NONE nothing, VIEW reads only, REPLY answers; a person never reaches the inbox', async () => {
    const id = (await ctx.prisma.waConversation.findFirstOrThrow({ where: { linkedUserId: alice.id } })).id;
    expect((await staff(finance, 'get', '/conversations')).status).toBe(403);
    expect((await staff(viewer, 'get', '/conversations')).status).toBe(200);
    expect((await staff(viewer, 'get', `/conversations/${id}/messages`)).status).toBe(200);
    expect(
      (await staff(viewer, 'post', `/conversations/${id}/messages`).send({ type: 'TEXT', text: 'x' })).status,
    ).toBe(403);
    expect((await staff(viewer, 'post', `/conversations/${id}/close`)).status).toBe(403);
    expect((await staff(alice, 'get', '/conversations')).status).toBe(403);
    expect((await staff(bob, 'get', `/conversations/${id}/messages`)).status).toBe(403);
    expect(
      (
        await p.send(viewer, 'post', `/admin/whatsapp/conversations/${id}/messages`, {
          type: 'TEXT',
          text: 'x',
        })
      ).status,
    ).toBe(403);
    vi.useRealTimers();
  });

  it("nobody reads another person's thread", async () => {
    expect(await thread(bob)).toMatchObject({ id: null, status: 'NONE' });
    expect((await messagesOf(bob)).data).toEqual([]);
    // Bob's own ticket is his: Alice never sees it, and his cursor is no key to hers.
    const b = await write(bob, { kind: 'TEXT', text: 'مشكلة تقنية', topic: 'TECHNICAL' });
    expect(b.status).toBe(201);
    const aliceMsgs = await messagesOf(alice);
    expect(aliceMsgs.data.map((m) => m.text)).not.toContain('مشكلة تقنية');
    expect(aliceMsgs.thread.id).not.toBe(b.body.thread.id);
    const page = await ctx.http.get('/api/v1/support/thread/messages?limit=1').set(auth(alice));
    expect(page.body.page.nextCursor).not.toBeNull();
    const stolen = await ctx.http
      .get(
        `/api/v1/support/thread/messages?cursor=${encodeURIComponent(page.body.page.nextCursor as string)}`,
      )
      .set(auth(bob));
    expect(stolen.status).toBe(400);
  });

  it('a staff reply: the first name only, «تم الاستلام» then read, the unread count and a push to the person', async () => {
    const id = (await ctx.prisma.waConversation.findFirstOrThrow({ where: { linkedUserId: alice.id } })).id;
    const before = push.sent.length;
    const read = await staff(support, 'post', `/conversations/${id}/read`);
    expect(read.status).toBe(200);
    expect((await messagesOf(alice)).data.filter((m) => m.mine).every((m) => m.receipt === 'READ')).toBe(
      true,
    );
    const reply = await staff(support, 'post', `/conversations/${id}/messages`).send({
      type: 'TEXT',
      text: 'أهلًا، نتحقق من الشحن الآن',
    });
    expect(reply.status, JSON.stringify(reply.body)).toBe(201);
    expectContract(reply, 'sendStaffWhatsAppMessage');
    // The sender claimed it.
    expect((await ctx.prisma.waConversation.findUniqueOrThrow({ where: { id } })).assignedToId).toBe(
      support.id,
    );
    await settle(ctx);
    const toAlice = pushesTo(alice, before, 'support');
    expect(toAlice).toHaveLength(1);
    expect(toAlice[0]!.channel).toBe('messages');
    expect(toAlice[0]!.title).toMatch(/دعم كابسو|Kabso Support/);
    expect(toAlice[0]!.body).toMatch(/^Sara · (فريق كابسو|Kabso Team): أهلًا/);
    const t = await thread(alice);
    expect(t.unreadCount).toBe(1);
    // Owner (2026-11-12): the unread reply counts in the Messages tab badge.
    const badge = await ctx.http.get('/api/v1/dm/unread').set(auth(alice));
    expect(badge.status).toBe(200);
    expectContract(badge, 'getDmUnread');
    expect(badge.body.support).toBe(1);
    const page = await messagesOf(alice);
    const last = page.data[0]!;
    expect(last).toEqual({
      id: reply.body.id,
      mine: false,
      kind: 'TEXT',
      text: 'أهلًا، نتحقق من الشحن الآن',
      media: null,
      staff: { firstName: 'Sara' },
      receipt: null,
      createdAt: expect.any(String),
    });
    // Nothing of the staff account leaks.
    expect(JSON.stringify(page)).not.toContain(support.id);
    const r = await ctx.http.post('/api/v1/support/thread/read').set(auth(alice));
    expect(r.status).toBe(204);
    expect((await thread(alice)).unreadCount).toBe(0);
    // Reading the thread clears the badge.
    expect((await ctx.http.get('/api/v1/dm/unread').set(auth(alice))).body.support).toBe(0);
  });

  it('in-app: no templates, never linked or unlinked; a staff picture goes through the image pipeline', async () => {
    const id = (await ctx.prisma.waConversation.findFirstOrThrow({ where: { linkedUserId: alice.id } })).id;
    const tpl = await staff(support, 'post', `/conversations/${id}/messages`).send({
      type: 'TEMPLATE',
      template: { name: 'hello', language: 'ar', parameters: [] },
    });
    expect(tpl.status).toBe(400);
    expect(tpl.body.error.details).toEqual([{ field: 'template', issue: 'in_app' }]);
    // Only pictures (the direct-message image rules); a broken one is refused by the pipeline.
    const pdf = await staff(support, 'post', `/conversations/${id}/media?mime=application/pdf`)
      .set('Content-Type', 'application/octet-stream')
      .send(Buffer.from('%PDF-1.4'));
    expect(pdf.status).toBe(400);
    expect(pdf.body.error.details).toEqual([{ field: 'mime', issue: 'not_allowed' }]);
    const broken = await staff(support, 'post', `/conversations/${id}/media?mime=image/png`)
      .set('Content-Type', 'application/octet-stream')
      .send(Buffer.from([1, 2, 3]));
    expect(broken.status).toBeGreaterThanOrEqual(400);
    expect(broken.status).toBeLessThan(500);
    // VIEW cannot send one.
    const png = await sharp({
      create: { width: 300, height: 200, channels: 3, background: { r: 20, g: 120, b: 200 } },
    })
      .png()
      .toBuffer();
    const viewOnly = await staff(viewer, 'post', `/conversations/${id}/media?mime=image/png`)
      .set('Content-Type', 'application/octet-stream')
      .send(png);
    expect(viewOnly.status).toBe(403);
    const before = push.sent.length;
    const audits = await ctx.prisma.auditLog.count({ where: { action: 'whatsapp.message.send' } });
    const pic = await staff(
      support,
      'post',
      `/conversations/${id}/media?mime=image/png&caption=${encodeURIComponent('الإيصال المطلوب')}`,
    )
      .set('Content-Type', 'application/octet-stream')
      .send(png);
    expect(pic.status, JSON.stringify(pic.body)).toBe(201);
    expectContract(pic, 'sendStaffWhatsAppMedia');
    expect(pic.body).toMatchObject({ type: 'IMAGE', media: { state: 'STORED' } });
    expect(await ctx.prisma.auditLog.count({ where: { action: 'whatsapp.message.send' } })).toBe(audits + 1);
    // The person sees a picture (a re-encoded asset), with the first name only.
    const page = await messagesOf(alice);
    expect(page.data[0]).toMatchObject({
      id: pic.body.id,
      mine: false,
      kind: 'IMAGE',
      text: 'الإيصال المطلوب',
      staff: { firstName: 'Sara' },
      media: { type: 'IMAGE' },
    });
    const asset = await ctx.prisma.mediaAsset.findUniqueOrThrow({
      where: { id: (page.data[0]!.media as { id: string }).id },
    });
    expect(asset).toMatchObject({ kind: 'DM_IMAGE', ownerId: support.id });
    expect(asset.attachedAt).not.toBeNull();
    expect(asset.largeKey).toMatch(/\.webp$/);
    // The team's own view of it.
    const bytes = await staff(support, 'get', `/messages/${pic.body.id}/media`).buffer(true);
    expect(bytes.status).toBe(200);
    await settle(ctx);
    expect(pushesTo(alice, before, 'support')).toHaveLength(1);
    expect(await ctx.http.post('/api/v1/support/thread/read').set(auth(alice))).toHaveProperty('status', 204);
    const link = await staff(support, 'post', `/conversations/${id}/link`).send({ username: 'someone' });
    expect(link.status).toBe(400);
    expect((await staff(support, 'delete', `/conversations/${id}/link`)).status).toBe(400);
    // Notes and the history work (and are never shown to the person).
    const note = await staff(support, 'post', `/conversations/${id}/notes`).send({
      body: 'حوّلنا الإيصال للمالية',
    });
    expect(note.status).toBe(201);
    expect(JSON.stringify(await messagesOf(alice))).not.toContain('حوّلنا الإيصال');
  });

  it('transfer, close and a new ticket: the topic picks the queue again', async () => {
    const id = (await ctx.prisma.waConversation.findFirstOrThrow({ where: { linkedUserId: alice.id } })).id;
    const moved = await staff(support, 'post', `/conversations/${id}/transfer`).send({
      department: 'GENERAL',
    });
    expect(moved.status, JSON.stringify(moved.body)).toBe(200);
    expect(moved.body.department).toBe('GENERAL');
    const closed = await staff(owner, 'post', `/conversations/${id}/close`);
    expect(closed.status).toBe(200);
    expect(closed.body.status).toBe('CLOSED');
    expect((await thread(alice)).status).toBe('CLOSED');
    expect((await write(alice, { kind: 'TEXT', text: 'مرحبا مجددا' })).status).toBe(400);
    const reopened = await write(alice, { kind: 'TEXT', text: 'مرحبا مجددا', topic: 'AGENCIES' });
    expect(reopened.status).toBe(201);
    expect(reopened.body.thread).toMatchObject({ status: 'OPEN', department: 'AGENCIES', id });
    const row = await ctx.prisma.waConversation.findUniqueOrThrow({ where: { id } });
    expect(row).toMatchObject({ status: 'OPEN', department: 'AGENCIES', assignedToId: null });
    const history = await staff(support, 'get', `/conversations/${id}/assignments`);
    expect(history.status).toBe(200);
    expect(history.body.data[0]).toMatchObject({
      action: 'REOPEN',
      department: 'AGENCIES',
      fromDepartment: 'GENERAL',
    });
    expect(await ctx.prisma.auditLog.count({ where: { action: 'support.ticket.open' } })).toBe(3);
    // Staff reopen (from CLOSED) works the same as WhatsApp's.
    expect((await staff(owner, 'post', `/conversations/${id}/close`)).status).toBe(200);
    expect((await staff(owner, 'post', `/conversations/${id}/reopen`)).body.status).toBe('OPEN');
  });

  it('VIP priority: a PRIORITY_SUPPORT holder is listed first', async () => {
    const v1 = await p.send(owner, 'patch', `/admin/vip/tiers/${VIP1}`, {
      reason: 'owner D385',
      perks: [{ code: 'BADGE' }, { code: 'PRIORITY_SUPPORT' }],
    });
    vi.useRealTimers();
    expect(v1.status, JSON.stringify(v1.body)).toBe(200);
    const carol = await p.signup();
    vi.useRealTimers();
    await withMigrationClient((db) =>
      db.vipMembership.create({
        data: {
          userId: carol.id,
          tierId: VIP1,
          startedAt: new Date(Date.now() - DAY),
          expiresAt: new Date(Date.now() + 30 * DAY),
        },
      }),
    );
    expect((await write(carol, { kind: 'TEXT', text: 'VIP here', topic: 'GENERAL' })).status).toBe(201);
    // Bob writes later: still after the VIP.
    expect((await write(bob, { kind: 'TEXT', text: 'later' })).status).toBe(201);
    const list = await staff(owner, 'get', '/conversations?filter=all');
    const rows = list.body.data as { linkedAccount: { userId: string }; priority: boolean }[];
    expect(rows[0]).toMatchObject({ priority: true, linkedAccount: { userId: carol.id } });
    expect(rows.slice(1).every((r) => !r.priority)).toBe(true);
  });

  it('the sweeper deletes an old thread with its pictures and voice clips', async () => {
    const conv = await ctx.prisma.waConversation.findFirstOrThrow({ where: { linkedUserId: alice.id } });
    const assets = await ctx.prisma.waMessage.findMany({
      where: { conversationId: conv.id, mediaAssetId: { not: null } },
      select: { mediaAssetId: true },
    });
    // Alice's picture and voice clip, and the team's picture.
    expect(assets).toHaveLength(3);
    await withMigrationClient((db) =>
      db.waConversation.update({
        where: { id: conv.id },
        data: { lastMessageAt: new Date(Date.now() - 400 * DAY) },
      }),
    );
    const out = await ctx.app.get(WhatsAppSweeper).purgeOnce();
    expect(out.conversations).toBe(1);
    expect(await ctx.prisma.waConversation.count({ where: { id: conv.id } })).toBe(0);
    expect(
      await ctx.prisma.mediaAsset.count({ where: { id: { in: assets.map((a) => a.mediaAssetId!) } } }),
    ).toBe(0);
    expect(await thread(alice)).toMatchObject({ id: null, status: 'NONE' });
  });
});

describe('D385 the support rate limit', { timeout: 120_000 }, () => {
  let ctx: TestContext;
  const p = panel(() => ctx);
  beforeAll(async () => {
    ctx = await createTestApp({ RATE_LIMIT_SUPPORT_SEND_USER: '2/60' });
  });
  afterAll(async () => {
    vi.useRealTimers();
    await ctx?.close();
  });

  it('the 3rd message within a minute is 429', async () => {
    const u = await p.signup();
    vi.useRealTimers();
    const w = (text: string) =>
      ctx.http
        .post('/api/v1/support/thread/messages')
        .set(auth(u))
        .send({ kind: 'TEXT', text, topic: 'GENERAL', clientId: randomUUID() });
    expect((await w('1')).status).toBe(201);
    expect((await w('2')).status).toBe(201);
    const third = await w('3');
    expect(third.status).toBe(429);
    expect(third.body.error.code).toBe('RATE_LIMITED');
  });
});

describe('D385 both channels in one inbox', { timeout: 300_000 }, () => {
  const PNID = '1098765432185';
  const WABA = '2098765432185';
  const accessToken = randomBytes(24).toString('base64url');
  const appSecret = randomBytes(16).toString('hex');
  const verifyToken = randomBytes(16).toString('base64url');
  const graph = new FakeWhatsAppGraph(accessToken, PNID, WABA);
  let ctx: TestContext;
  const p = panel(() => ctx);
  let owner: Admin;
  let person: Person;

  beforeAll(async () => {
    await graph.start();
    const dir = mkdtempSync(join(tmpdir(), 'kabso-wa-d385-'));
    const file = (n: string, v: string) => {
      const path = join(dir, n);
      writeFileSync(path, v, { mode: 0o600 });
      return path;
    };
    ctx = await createTestApp({
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
      WHATSAPP_PUSH_GAP_SECONDS: '0',
      API_PUBLIC_URL: 'https://api.kabso.example',
    });
    owner = await p.makeAdmin(['OWNER']);
    person = await p.signup();
    vi.useRealTimers();
  });
  afterAll(async () => {
    vi.useRealTimers();
    await ctx?.close();
    await graph.stop();
  });

  it('lists WhatsApp and in-app threads together (newest first) and filters by channel', async () => {
    const raw = webhookBody(PNID, {
      contacts: [{ profile: { name: 'عميل' }, wa_id: '966500000385' }],
      messages: [
        {
          from: '966500000385',
          id: 'wamid.D385A',
          timestamp: String(Math.floor(Date.now() / 1000)),
          type: 'text',
          text: { body: 'hi on WhatsApp' },
        },
      ],
    });
    const hook = await ctx.http
      .post('/api/v1/webhooks/whatsapp')
      .set('Content-Type', 'application/json')
      .set('X-Hub-Signature-256', signatureOf(raw, appSecret))
      .send(raw);
    expect(hook.status).toBe(200);
    await settle(ctx);
    const inApp = await ctx.http
      .post('/api/v1/support/thread/messages')
      .set(auth(person))
      .send({ kind: 'TEXT', text: 'hi in the app', topic: 'TECHNICAL', clientId: randomUUID() });
    expect(inApp.status).toBe(201);
    const s = await ctx.http.get('/api/v1/staff/whatsapp/summary').set(auth(owner));
    expect(s.body).toMatchObject({ enabled: true, inApp: true, unassigned: 2 });
    const all = await ctx.http.get('/api/v1/staff/whatsapp/conversations').set(auth(owner));
    expect(all.status).toBe(200);
    expectContract(all, 'getStaffWhatsAppConversations');
    expect(all.body.data.map((c: { channel: string; phone: string | null }) => [c.channel, c.phone])).toEqual(
      [
        ['IN_APP', null],
        ['WHATSAPP', '+966500000385'],
      ],
    );
    const wa = await ctx.http.get('/api/v1/staff/whatsapp/conversations?channel=WHATSAPP').set(auth(owner));
    expect(wa.body.data.map((c: { channel: string }) => c.channel)).toEqual(['WHATSAPP']);
    const app = await ctx.http.get('/api/v1/staff/whatsapp/conversations?channel=IN_APP').set(auth(owner));
    expect(app.body.data.map((c: { channel: string }) => c.channel)).toEqual(['IN_APP']);
    // A WhatsApp reply still goes through Meta; the in-app one never does.
    const waId = wa.body.data[0].id as string;
    const sentBefore = graph.sent.length;
    expect(
      (
        await ctx.http
          .post(`/api/v1/staff/whatsapp/conversations/${waId}/messages`)
          .set(auth(owner))
          .send({ type: 'TEXT', text: 'رد واتساب' })
      ).status,
    ).toBe(201);
    const appId = app.body.data[0].id as string;
    expect(
      (
        await ctx.http
          .post(`/api/v1/staff/whatsapp/conversations/${appId}/messages`)
          .set(auth(owner))
          .send({ type: 'TEXT', text: 'رد داخل التطبيق' })
      ).status,
    ).toBe(201);
    expect(graph.sent.length).toBe(sentBefore + 1);
  });
});

describe('D385 pinned chats', { timeout: 300_000 }, () => {
  let ctx: TestContext;
  const p = panel(() => ctx);
  type U = Person & { username: string };
  const signup = async (): Promise<U> => {
    const u = await p.signup();
    vi.useRealTimers();
    const profile = await ctx.prisma.userProfile.findUniqueOrThrow({ where: { userId: u.id } });
    return { ...u, username: profile.username };
  };
  const follow = async (by: U, u: U) => {
    const r = await ctx.http.put(`/api/v1/users/${u.username}/follow`).set(auth(by));
    expect(r.status, JSON.stringify(r.body)).toBeLessThan(300);
  };
  const dm = async (by: U, to: U, text = 'hi') => {
    const r = await ctx.http
      .post('/api/v1/dm/messages')
      .set(auth(by))
      .send({ to: to.username, kind: 'TEXT', text, clientId: randomUUID() });
    expect(r.status, JSON.stringify(r.body)).toBe(201);
    return r.body.message.conversationId as string;
  };
  const friendsWith = async (me: U): Promise<{ peer: U; conversationId: string }> => {
    const peer = await signup();
    await follow(me, peer);
    await follow(peer, me);
    const conversationId = await dm(me, peer);
    await dm(peer, me, 'hey');
    return { peer, conversationId };
  };
  const pins = async (u: { token: string }) => {
    const r = await ctx.http.get('/api/v1/dm/pins').set(auth(u));
    expect(r.status, JSON.stringify(r.body)).toBe(200);
    expectContract(r, 'listDmPins');
    return r.body as {
      data: { type: string; id: string; online: boolean | null; chat: { type: string } }[];
      max: number;
    };
  };

  beforeAll(async () => {
    ctx = await createTestApp({ JWT_ACCESS_TTL_SECONDS: String(60 * 86_400) });
  });
  afterAll(async () => {
    vi.useRealTimers();
    await ctx?.close();
  });

  it('pins up to 5 (in pin order, groups too), the 6th is 409; idempotent; unpin; support never counts', async () => {
    const me = await signup();
    expect(await pins(me)).toEqual({ data: [], max: 5 });
    const chats: string[] = [];
    for (let i = 0; i < 4; i += 1) chats.push((await friendsWith(me)).conversationId);
    const extra = await friendsWith(me);
    const member = await signup();
    await follow(member, me);
    await follow(me, member);
    const group = await ctx.http
      .post('/api/v1/dm/groups')
      .set(auth(me))
      .send({ name: 'Pins', members: [member.username], clientId: randomUUID() });
    expect(group.status, JSON.stringify(group.body)).toBe(201);
    const groupId = group.body.group.id as string;
    // Pin in an order unlike the chats' recency.
    const order = [chats[2]!, chats[0]!, chats[3]!, chats[1]!];
    for (const id of order) {
      const r = await ctx.http.put(`/api/v1/dm/conversations/${id}/pin`).set(auth(me));
      expect(r.status, JSON.stringify(r.body)).toBe(200);
      expectContract(r, 'pinDmConversation');
    }
    const g = await ctx.http.put(`/api/v1/dm/groups/${groupId}/pin`).set(auth(me));
    expect(g.status, JSON.stringify(g.body)).toBe(200);
    expectContract(g, 'pinDmGroup');
    const list = await pins(me);
    expect(list.data.map((x) => x.id)).toEqual([...order, groupId]);
    expect(list.data.map((x) => x.type)).toEqual(['DIRECT', 'DIRECT', 'DIRECT', 'DIRECT', 'GROUP']);
    expect(list.data[4]!.online).toBeNull();
    // Pinning a pinned one again: unchanged.
    const again = await ctx.http.put(`/api/v1/dm/conversations/${order[0]}/pin`).set(auth(me));
    expect(again.status).toBe(200);
    expect(again.body.data.map((x: { id: string }) => x.id)).toEqual([...order, groupId]);
    // A 6th: 409.
    const sixth = await ctx.http.put(`/api/v1/dm/conversations/${extra.conversationId}/pin`).set(auth(me));
    expect(sixth.status).toBe(409);
    expectContract(sixth, 'pinDmConversation');
    expect(sixth.body.error.code).toBe('DM_PIN_LIMIT');
    expect(sixth.body.error.details).toEqual([{ field: 'pins', issue: 'too_many' }]);
    // «دعم كابسو» is not a pin and never counts.
    const s = await ctx.http
      .post('/api/v1/support/thread/messages')
      .set(auth(me))
      .send({ kind: 'TEXT', text: 'help', topic: 'GENERAL', clientId: randomUUID() });
    expect(s.status).toBe(201);
    expect((await pins(me)).data).toHaveLength(5);
    // Another device of the same account sees the same row.
    const login = await ctx.http
      .post('/api/v1/auth/login')
      .send({ identifier: me.email, password: me.password });
    expect(login.status, JSON.stringify(login.body)).toBe(200);
    const device2 = { token: login.body.tokens.accessToken as string };
    expect((await pins(device2)).data.map((x) => x.id)).toEqual([...order, groupId]);
    // Unpin (idempotent), then the 6th fits at the end.
    const un = await ctx.http.delete(`/api/v1/dm/conversations/${order[1]}/pin`).set(auth(device2));
    expect(un.status).toBe(200);
    expectContract(un, 'unpinDmConversation');
    expect(
      (await ctx.http.delete(`/api/v1/dm/conversations/${order[1]}/pin`).set(auth(device2))).status,
    ).toBe(200);
    const fits = await ctx.http.put(`/api/v1/dm/conversations/${extra.conversationId}/pin`).set(auth(me));
    expect(fits.status).toBe(200);
    expect(fits.body.data.map((x: { id: string }) => x.id)).toEqual([
      order[0],
      order[2],
      order[3],
      groupId,
      extra.conversationId,
    ]);
    const ug = await ctx.http.delete(`/api/v1/dm/groups/${groupId}/pin`).set(auth(me));
    expect(ug.status).toBe(200);
    expectContract(ug, 'unpinDmGroup');
    expect(ug.body.data).toHaveLength(4);
    // Pinned chats stay in «الدردشات».
    const chatsList = await ctx.http.get('/api/v1/dm/chats').set(auth(me));
    expect(chatsList.body.data.map((c: { id: string }) => c.id)).toEqual(expect.arrayContaining(order));
  });

  it('only chats the person can open: 404 for others, a request, a bad id; a block or leaving drops the pin', async () => {
    const me = await signup();
    const { peer, conversationId } = await friendsWith(me);
    const stranger = await signup();
    expect(
      (await ctx.http.put(`/api/v1/dm/conversations/${conversationId}/pin`).set(auth(stranger))).status,
    ).toBe(404);
    expect((await ctx.http.put('/api/v1/dm/conversations/nope/pin').set(auth(me))).status).toBe(404);
    expect((await ctx.http.put(`/api/v1/dm/groups/${randomUUID()}/pin`).set(auth(me))).status).toBe(404);
    // A message request waiting for the caller cannot be pinned.
    const requester = await signup();
    const req = await dm(requester, me, 'a request');
    expect((await ctx.http.put(`/api/v1/dm/conversations/${req}/pin`).set(auth(me))).status).toBe(404);
    // A block drops the pin (and frees its place).
    expect((await ctx.http.put(`/api/v1/dm/conversations/${conversationId}/pin`).set(auth(me))).status).toBe(
      200,
    );
    expect((await pins(me)).data).toHaveLength(1);
    const b = await ctx.http.put(`/api/v1/users/${me.username}/block`).set(auth(peer));
    expect(b.status).toBeLessThan(300);
    expect((await pins(me)).data).toEqual([]);
    expect(await ctx.prisma.dmPin.count({ where: { userId: me.id } })).toBe(0);
  });

  it('presence for every partner (owner): online, offline, hidden by the switch, never with a block', async () => {
    const me = await signup();
    const live = await friendsWith(me);
    const away = await friendsWith(me);
    const hidden = await friendsWith(me);
    const blocker = await friendsWith(me);
    for (const c of [live, away, hidden, blocker]) {
      expect(
        (await ctx.http.put(`/api/v1/dm/conversations/${c.conversationId}/pin`).set(auth(me))).status,
      ).toBe(200);
    }
    await settle(ctx);
    // None of them shares a family with me (no family at all): presence is not family-only any more.
    expect(await ctx.prisma.familyMember.count({ where: { userId: me.id } })).toBe(0);
    await withMigrationClient(async (db) => {
      await db.user.update({
        where: { id: away.peer.id },
        data: { lastActiveAt: new Date(Date.now() - 3_600_000) },
      });
      await db.privacySettings.upsert({
        where: { userId: hidden.peer.id },
        create: { userId: hidden.peer.id, showActivityStatus: false },
        update: { showActivityStatus: false },
      });
    });
    const list = await pins(me);
    const onlineOf = (id: string) => list.data.find((x) => x.id === id)!.online;
    expect(onlineOf(live.conversationId)).toBe(true);
    expect(onlineOf(away.conversationId)).toBe(false);
    expect(onlineOf(hidden.conversationId)).toBeNull();
    // The same on the conversation rows.
    const chats = await ctx.http.get('/api/v1/dm/chats').set(auth(me));
    expect(chats.status).toBe(200);
    expectContract(chats, 'listDmChats');
    const rowOf = (id: string) =>
      (chats.body.data as { id: string; conversation: { online: boolean | null } | null }[]).find(
        (c) => c.id === id,
      )!.conversation!.online;
    expect(rowOf(live.conversationId)).toBe(true);
    expect(rowOf(away.conversationId)).toBe(false);
    expect(rowOf(hidden.conversationId)).toBeNull();
    // And for the other side: I show my activity, so they see me.
    const theirs = await ctx.http.get('/api/v1/dm/conversations').set(auth(live.peer));
    expect(theirs.body.data.find((c: { id: string }) => c.id === live.conversationId).online).toBe(true);
    // A block (either way): no dot anywhere — the pin is dropped and the row leaves the lists.
    const b = await ctx.http.put(`/api/v1/users/${me.username}/block`).set(auth(blocker.peer));
    expect(b.status).toBeLessThan(300);
    const after = await pins(me);
    expect(after.data.map((x) => x.id)).not.toContain(blocker.conversationId);
    const chats2 = await ctx.http.get('/api/v1/dm/chats').set(auth(me));
    expect(chats2.body.data.map((c: { id: string }) => c.id)).not.toContain(blocker.conversationId);
    const fromThem = await ctx.http.get('/api/v1/dm/conversations').set(auth(blocker.peer));
    expect(fromThem.body.data.map((c: { id: string }) => c.id)).not.toContain(blocker.conversationId);
  });
});
