/**
 * D388 (owner 2026-11-13; contract v1.140-social, CONVENTIONS §10.177): «سؤال اللغة» — the WhatsApp language question
 * and language routing. End to end against PostgreSQL + Redis with the fake Graph API of D355: the reply-buttons question
 * on a conversation's first message (once ever, stored as an automatic OUTBOUND message that claims nothing and keeps
 * the preview), the answer by button or by a typed word (the language stored, a confirmation in it), the language on
 * the conversation and its filter, the staff languages set from «الموظفون والصلاحيات» (team.manage, code + reason,
 * audited; REPLY+ only), the push of an unassigned conversation to the staff who speak its language (everyone when none
 * of them can answer), a failed question never sent again, and no question for the in-app «دعم كابسو» threads.
 */
import { randomBytes, randomUUID } from 'node:crypto';
import { mkdtempSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { afterAll, beforeAll, describe, expect, it, vi } from 'vitest';
import { OBJECT_STORAGE } from '../src/modules/media/object-storage.js';
import {
  PUSH_SENDER,
  type PushMessage,
  type PushSender,
  type PushSendResult,
} from '../src/modules/push/push-sender.js';
import { panel, type Admin, type Person } from './helpers/admin-panel.js';
import { FakeWhatsAppGraph, signatureOf, webhookBody } from './helpers/fake-whatsapp.js';
import { MemoryObjectStorage } from './helpers/memory-storage.js';
import { expectContract, operations } from './helpers/openapi.js';
import { createTestApp, settle, type TestContext } from './helpers/test-app.js';

class FakePushSender implements PushSender {
  readonly enabled = true;
  readonly sent: PushMessage[] = [];
  send(message: PushMessage): Promise<PushSendResult> {
    this.sent.push(message);
    return Promise.resolve({ sent: message.tokens.length, failed: 0, invalidTokens: [] });
  }
}

const ADMIN_KEY = 'admin-totp-test-key-0123456789-abcdefghijklmnop';
const PNID = '1098765432188';
const WABA = '2098765432188';
const auth = (u: { token: string }) => ({ Authorization: `Bearer ${u.token}` });
const unix = (d = new Date()) => String(Math.floor(d.getTime() / 1000));

describe('D388 contract coverage', () => {
  it('openapi v1.140-social declares the languages operation', () => {
    const ids = operations().map((o) => `${o.operationId} ${o.method.toUpperCase()} ${o.path}`);
    expect(ids).toContain('setAdminTeamWhatsAppLanguages PUT /api/v1/admin/team/{userId}/whatsapp/languages');
  });
});

describe('D388 the WhatsApp language question', { timeout: 600_000 }, () => {
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
  let arabic: Admin; // SUPPORT, speaks AR only
  let english: Admin; // SUPPORT, speaks EN only
  let viewer: Admin; // SUPPORT lowered to VIEW
  let seq = 0;

  const hook = async (value: Parameters<typeof webhookBody>[1]) => {
    const raw = webhookBody(PNID, value);
    const r = await ctx.http
      .post('/api/v1/webhooks/whatsapp')
      .set('Content-Type', 'application/json')
      .set('X-Hub-Signature-256', signatureOf(raw, appSecret))
      .send(raw);
    expect(r.status, JSON.stringify(r.body)).toBe(200);
    await settle(ctx);
    return r;
  };
  const contact = (phone: string) => [{ profile: { name: 'عميل' }, wa_id: phone }];
  const text = (phone: string, body: string) => {
    seq += 1;
    return {
      contacts: contact(phone),
      messages: [{ from: phone, id: `wamid.D388-${seq}`, timestamp: unix(), type: 'text', text: { body } }],
    };
  };
  const button = (phone: string, id: string, title: string) => {
    seq += 1;
    return {
      contacts: contact(phone),
      messages: [
        {
          from: phone,
          id: `wamid.D388-${seq}`,
          timestamp: unix(),
          type: 'interactive',
          interactive: { type: 'button_reply', button_reply: { id, title } },
        },
      ],
    };
  };
  const convOf = (phone: string) =>
    ctx.prisma.waConversation.findUniqueOrThrow({ where: { phoneE164: `+${phone}` } });
  const staff = (u: { token: string }, path: string) =>
    ctx.http.get(`/api/v1/staff/whatsapp${path}`).set(auth(u));
  const sentTo = (phone: string) => graph.sent.filter((m) => m.to === phone);
  const everyone = () => [owner, moderator, arabic, english, viewer];
  /** Who got a new-message WhatsApp push since `since`. */
  const pushedTo = (since: number) => {
    const sent = push.sent
      .slice(since)
      .filter((m) => m.data.kind === 'whatsapp' && m.data.event === undefined);
    return everyone()
      .filter((u) => sent.some((m) => m.tokens.some((t) => t.includes(u.id.slice(-8)))))
      .map((u) => u.id)
      .sort();
  };
  const setLanguages = async (target: Person, languages: unknown, by: Admin = owner) => {
    const totpCode = p.nextCode(by.secret);
    const r = await p.send(by, 'put', `/admin/team/${target.id}/whatsapp/languages`, {
      languages,
      reason: 'D388 test',
      totpCode,
    });
    vi.useRealTimers();
    return r;
  };
  const setLevel = async (target: Person, level: string | null) => {
    const totpCode = p.nextCode(owner.secret);
    const r = await p.send(owner, 'put', `/admin/team/${target.id}/whatsapp`, {
      level,
      reason: 'D388 test',
      totpCode,
    });
    vi.useRealTimers();
    return r;
  };
  const teamRow = async (u: Person) => {
    const r = await p.send(owner, 'get', '/admin/team');
    vi.useRealTimers();
    expect(r.status).toBe(200);
    expectContract(r, 'listAdminTeam');
    return (r.body.data as { id: string; whatsappLanguages: unknown }[]).find((m) => m.id === u.id)!
      .whatsappLanguages;
  };
  /** Exactly these staff on shift (everyone else off). */
  const onShift = async (...who: Person[]) => {
    await ctx.prisma.adminShift.updateMany({ data: { onShift: false } });
    for (const u of who) {
      await ctx.prisma.adminShift.upsert({
        where: { userId: u.id },
        create: { userId: u.id, onShift: true },
        update: { onShift: true },
      });
    }
  };

  beforeAll(async () => {
    await graph.start();
    const dir = mkdtempSync(join(tmpdir(), 'kabso-wa388-'));
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
        ADMIN_SESSION_MAX_SECONDS: '604800',
        RATE_LIMIT_ADMIN_IP: '100000/900',
        RATE_LIMIT_ADMIN_TEAM_IP: '1000/900',
        WHATSAPP_PHONE_NUMBER_ID: PNID,
        WHATSAPP_BUSINESS_ACCOUNT_ID: WABA,
        WHATSAPP_ACCESS_TOKEN_FILE: file('token', accessToken),
        WHATSAPP_APP_SECRET_FILE: file('secret', appSecret),
        WHATSAPP_VERIFY_TOKEN_FILE: file('verify', verifyToken),
        WHATSAPP_GRAPH_BASE_URL: graph.base,
        WHATSAPP_SWEEP_INTERVAL_SECONDS: '0',
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
    arabic = await p.makeAdmin(['SUPPORT']);
    english = await p.makeAdmin(['SUPPORT']);
    viewer = await p.makeAdmin(['SUPPORT']);
    vi.useRealTimers();
    for (const u of everyone()) {
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
    expect((await setLevel(viewer, 'VIEW')).status).toBe(200);
  });
  afterAll(async () => {
    vi.useRealTimers();
    await ctx?.close();
    await graph.stop();
  });

  it('the first message is answered with the question once; it claims nothing and keeps the preview', async () => {
    const phone = '966522220001';
    await hook(text(phone, 'السلام عليكم'));
    const question = sentTo(phone);
    expect(question).toHaveLength(1);
    expect(question[0]).toMatchObject({
      type: 'interactive',
      interactive: {
        type: 'button',
        action: {
          buttons: [
            { type: 'reply', reply: { id: 'kabso_lang_ar', title: 'العربية' } },
            { type: 'reply', reply: { id: 'kabso_lang_en', title: 'English' } },
          ],
        },
      },
    });
    const row = await convOf(phone);
    expect(row.language).toBeNull();
    expect(row.languageAskedAt).not.toBeNull();
    expect(row.assignedToId).toBeNull();
    expect(row.lastDirection).toBe('INBOUND');
    expect(row.lastPreview).toBe('السلام عليكم');
    expect(row.unreadCount).toBe(1);

    const c = await staff(owner, `/conversations/${row.id}`);
    expectContract(c, 'getStaffWhatsAppConversation');
    expect(c.body.language).toBeNull();
    const msgs = await staff(owner, `/conversations/${row.id}/messages`);
    expectContract(msgs, 'getStaffWhatsAppMessages');
    const auto = (
      msgs.body.data as { direction: string; type: string; sentBy: unknown; text: string }[]
    ).find((m) => m.direction === 'OUTBOUND')!;
    expect(auto).toMatchObject({ type: 'INTERACTIVE', sentBy: null });
    expect(auto.text).toContain('اختر لغتك');
    expect(auto.text).toContain('Please choose your language');
    const audit = await ctx.prisma.auditLog.findMany({
      where: { action: 'whatsapp.language.auto', targetId: row.id },
    });
    expect(audit).toHaveLength(1);
    expect(audit[0]!.actorUserId).toBeNull();
    expect(audit[0]!.metadata).toMatchObject({ kind: 'question' });

    // Another message that is not an answer: no second question.
    await hook(text(phone, 'عندي مشكلة في الشحن'));
    expect(sentTo(phone)).toHaveLength(1);
    expect((await convOf(phone)).language).toBeNull();
  });

  it('the English button sets the language and confirms in English; later answers change nothing', async () => {
    const phone = '966522220002';
    await hook(text(phone, 'hello'));
    await hook(button(phone, 'kabso_lang_en', 'English'));
    const row = await convOf(phone);
    expect(row.language).toBe('EN');
    const out = sentTo(phone);
    expect(out).toHaveLength(2);
    expect(out[1]).toMatchObject({
      type: 'text',
      text: { body: 'Thank you! The Kabso team will reply to you in English as soon as possible.' },
    });
    const c = await staff(owner, `/conversations/${row.id}`);
    expectContract(c, 'getStaffWhatsAppConversation');
    expect(c.body.language).toBe('EN');
    // The answer is a customer message like any other.
    expect(row.unreadCount).toBe(2);
    expect(row.lastPreview).toBe('English');

    await hook(button(phone, 'kabso_lang_ar', 'العربية'));
    await hook(text(phone, 'عربي'));
    expect((await convOf(phone)).language).toBe('EN');
    expect(sentTo(phone)).toHaveLength(2);
  });

  it('a typed «عربي» sets Arabic and confirms in Arabic; a word before the question is not an answer', async () => {
    const phone = '966522220003';
    // The first message is «عربي» itself: it is asked, not answered (the question was not sent yet).
    await hook(text(phone, 'عربي'));
    expect((await convOf(phone)).language).toBeNull();
    await hook(text(phone, '  العربيه '));
    expect((await convOf(phone)).language).toBe('AR');
    const out = sentTo(phone);
    expect(out).toHaveLength(2);
    expect(out[1]).toMatchObject({
      type: 'text',
      text: { body: 'شكراً لك! سيرد عليك فريق كابسو باللغة العربية في أقرب وقت.' },
    });
  });

  it('a closed and reopened conversation is never asked again', async () => {
    const phone = '966522220001';
    const row = await convOf(phone);
    await ctx.prisma.waConversation.update({ where: { id: row.id }, data: { status: 'CLOSED' } });
    await hook(text(phone, 'مرحبا مرة أخرى'));
    expect((await convOf(phone)).status).toBe('OPEN');
    expect(sentTo(phone)).toHaveLength(1);
  });

  it('a failed question is not stored and never sent again', async () => {
    const phone = '966522220004';
    graph.failNext = { status: 500, code: 131000, title: 'Something went wrong' };
    await hook(text(phone, 'hi'));
    const row = await convOf(phone);
    expect(row.languageAskedAt).not.toBeNull();
    expect(sentTo(phone)).toHaveLength(0);
    expect(
      await ctx.prisma.waMessage.count({ where: { conversationId: row.id, direction: 'OUTBOUND' } }),
    ).toBe(0);
    await hook(text(phone, 'hello?'));
    expect(sentTo(phone)).toHaveLength(0);
  });

  it('the language filter keeps the conversations in that language', async () => {
    const ar = await staff(owner, '/conversations?language=AR');
    expectContract(ar, 'getStaffWhatsAppConversations');
    const arIds = (ar.body.data as { id: string; language: string }[]).map((c) => c.language);
    expect(arIds.length).toBeGreaterThan(0);
    expect(arIds.every((l) => l === 'AR')).toBe(true);
    const en = await p.send(owner, 'get', '/admin/whatsapp/conversations?language=EN');
    vi.useRealTimers();
    expect(en.status).toBe(200);
    expectContract(en, 'getAdminWhatsAppConversations');
    expect((en.body.data as { language: string }[]).every((c) => c.language === 'EN')).toBe(true);
    expect((await staff(owner, '/conversations?language=FR')).status).toBe(400);
  });

  it('staff languages are set by team.manage only, for REPLY+ team members, audited; [] is the default', async () => {
    expect(await teamRow(arabic)).toEqual({ languages: ['AR', 'EN'], isDefault: true });
    const r = await setLanguages(arabic, ['AR']);
    expect(r.status, JSON.stringify(r.body)).toBe(200);
    expectContract(r, 'setAdminTeamWhatsAppLanguages');
    expect(r.body).toEqual({
      userId: arabic.id,
      before: ['AR', 'EN'],
      whatsappLanguages: { languages: ['AR'], isDefault: false },
    });
    expect((await setLanguages(english, ['EN'])).status).toBe(200);
    expect(await teamRow(english)).toEqual({ languages: ['EN'], isDefault: false });
    // Both in either order: catalogue order.
    expect((await setLanguages(moderator, ['EN', 'AR'])).body.whatsappLanguages).toEqual({
      languages: ['AR', 'EN'],
      isDefault: false,
    });
    expect((await setLanguages(moderator, [])).body.whatsappLanguages).toEqual({
      languages: ['AR', 'EN'],
      isDefault: true,
    });
    const low = await setLanguages(viewer, ['AR']);
    expect(low.status).toBe(409);
    expect(JSON.stringify(low.body)).toContain('team_languages_level');
    expect((await setLanguages(arabic, ['FR'])).status).toBe(400);
    expect((await setLanguages(arabic, ['AR', 'AR'])).status).toBe(400);
    // Only team.manage.
    expect((await setLanguages(english, ['AR'], moderator)).status).toBe(403);
    const audit = await ctx.prisma.auditLog.findFirstOrThrow({
      where: { action: 'admin.team.whatsapp_languages', targetId: arabic.id },
    });
    expect(audit.metadata).toMatchObject({ before: ['AR', 'EN'], after: ['AR'], reason: 'D388 test' });
  });

  it('an unassigned conversation in a language pushes the staff who speak it', async () => {
    // arabic: AR; english: EN; owner, moderator, viewer: both (none set).
    await onShift(arabic, english);
    const ar = '966522220005';
    await hook(text(ar, 'مرحبا'));
    let since = push.sent.length;
    await hook(button(ar, 'kabso_lang_ar', 'العربية'));
    expect(pushedTo(since)).toEqual([arabic.id]);
    since = push.sent.length;
    await hook(text(ar, 'ما زلت أنتظر'));
    expect(pushedTo(since)).toEqual([arabic.id]);

    const en = '966522220006';
    await hook(text(en, 'hello'));
    since = push.sent.length;
    await hook(button(en, 'kabso_lang_en', 'English'));
    expect(pushedTo(since)).toEqual([english.id]);

    // Nobody who speaks Arabic on shift: the Arabic speakers who can answer (never the English-only one).
    await onShift(english);
    since = push.sent.length;
    await hook(text(ar, 'هل من أحد؟'));
    expect(pushedTo(since)).toEqual([owner.id, moderator.id, arabic.id].sort());

    // Nobody who speaks Arabic can answer at all: the rule of everyone, as before — the agent on shift.
    for (const u of [owner, moderator]) expect((await setLanguages(u, ['EN'])).status).toBe(200);
    expect((await setLevel(arabic, 'VIEW')).status).toBe(200);
    since = push.sent.length;
    await hook(text(ar, 'مرحبا؟'));
    expect(pushedTo(since)).toEqual([english.id]);
  });

  it('the in-app «دعم كابسو» threads are never asked', async () => {
    const person = await p.signup();
    vi.useRealTimers();
    const before = graph.sent.length;
    const r = await ctx.http
      .post('/api/v1/support/thread/messages')
      .set(auth(person))
      .send({ clientId: randomUUID(), kind: 'TEXT', text: 'مرحبا', topic: 'GENERAL' });
    expect(r.status, JSON.stringify(r.body)).toBeLessThan(300);
    await settle(ctx);
    expect(graph.sent.length).toBe(before);
    const row = await ctx.prisma.waConversation.findFirstOrThrow({
      where: { channel: 'IN_APP', linkedUserId: person.id },
    });
    expect(row.languageAskedAt).toBeNull();
    expect(row.language).toBeNull();
  });
});
