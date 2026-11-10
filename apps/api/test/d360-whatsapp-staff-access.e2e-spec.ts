/**
 * D360 (owner approved; contract v1.120-social, CONVENTIONS §10.155): a WhatsApp level per staff member — NONE / VIEW /
 * REPLY / MANAGE instead of the D355 role rule. End to end against PostgreSQL + Redis with the fake Graph API of D355:
 * the defaults (exactly D355 with no level set), setting a level from «الموظفون والصلاحيات» (team.manage, code +
 * reason, audited before / after / actor), each level on every `/staff/whatsapp/*` and `/admin/whatsapp/*` route, the
 * badge and the pushes (VIEW and above), transfer targets (REPLY and above), the release of a lowered person's
 * conversations, a revoke that lowers the level, and the refusals (OWNER, not on the team, not team.manage).
 */
import { randomBytes } from 'node:crypto';
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
const PNID = '1098765432100';
const WABA = '2098765432100';
const auth = (u: { token: string }) => ({ Authorization: `Bearer ${u.token}` });
const unix = (d = new Date()) => String(Math.floor(d.getTime() / 1000));
const WA = (caps: string[]) => caps.filter((c) => c.startsWith('support.whatsapp')).sort();

describe('D360 contract coverage', () => {
  it('openapi v1.120-social declares the level operation', () => {
    const ids = operations().map((o) => `${o.operationId} ${o.method.toUpperCase()} ${o.path}`);
    expect(ids).toContain('setAdminTeamWhatsApp PUT /api/v1/admin/team/{userId}/whatsapp');
  });
});

describe('D360 WhatsApp level per staff member', { timeout: 600_000 }, () => {
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
  let support2: Admin;
  let finance: Admin;
  let bd: Admin;
  let customer: Person;
  let convA = '';
  let convB = '';
  let seq = 0;

  const hook = (value: Parameters<typeof webhookBody>[1]) => {
    const raw = webhookBody(PNID, value);
    return ctx.http
      .post('/api/v1/webhooks/whatsapp')
      .set('Content-Type', 'application/json')
      .set('X-Hub-Signature-256', signatureOf(raw, appSecret))
      .send(raw);
  };
  const textFrom = (phone: string, body: string, name = 'سارة') => {
    seq += 1;
    return {
      contacts: [{ profile: { name }, wa_id: phone }],
      messages: [{ from: phone, id: `wamid.D360-${seq}`, timestamp: unix(), type: 'text', text: { body } }],
    };
  };
  const staff = (u: { token: string }, method: 'get' | 'post' | 'put' | 'patch' | 'delete', path: string) =>
    ctx.http[method](`/api/v1/staff/whatsapp${path}`).set(auth(u));
  const pushedTo = (since: number) => {
    const sent = push.sent.slice(since).filter((m) => m.data.kind === 'whatsapp');
    const who = [owner, moderator, support, support2, finance, bd];
    return who.filter((u) => sent.some((m) => m.tokens.some((t) => t.includes(u.id.slice(-8)))));
  };
  /** The OWNER sets a level from the panel (code again, reason). */
  const setLevel = async (target: Person, level: string | null, by: Admin = owner) => {
    const totpCode = p.nextCode(by.secret);
    const r = await p.send(by, 'put', `/admin/team/${target.id}/whatsapp`, {
      level,
      reason: 'D360 test',
      totpCode,
    });
    vi.useRealTimers();
    return r;
  };
  const capsOf = async (u: Person) => {
    const r = await ctx.http.get('/api/v1/staff/me').set(auth(u));
    expect(r.status).toBe(200);
    return WA(r.body.capabilities as string[]);
  };
  const teamRow = async (u: Person) => {
    const r = await p.send(owner, 'get', '/admin/team');
    vi.useRealTimers();
    expect(r.status).toBe(200);
    expectContract(r, 'listAdminTeam');
    return (r.body.data as { id: string; whatsapp: unknown }[]).find((m) => m.id === u.id)!.whatsapp;
  };
  /** Every read route (VIEW and above) and every action (REPLY and above) of the app, for one person. */
  const appRoutes = (conv: string) => ({
    reads: [
      ['get', '/summary'],
      ['get', '/conversations?filter=all'],
      ['get', `/conversations/${conv}`],
      ['get', `/conversations/${conv}/messages`],
      ['get', `/conversations/${conv}/assignments`],
      ['get', `/conversations/${conv}/notes`],
      ['get', '/me/settings'],
    ] as const,
    actions: [
      ['post', `/conversations/${conv}/messages`, { type: 'TEXT', text: 'رد' }],
      ['post', `/conversations/${conv}/read`, undefined],
      ['post', `/conversations/${conv}/claim`, undefined],
      ['post', `/conversations/${conv}/release`, undefined],
      ['post', `/conversations/${conv}/transfer`, { toUserId: '00000000-0000-0000-0000-000000000000' }],
      ['post', `/conversations/${conv}/close`, undefined],
      ['post', `/conversations/${conv}/reopen`, undefined],
      ['post', `/conversations/${conv}/notes`, { body: 'ملاحظة' }],
      ['post', `/conversations/${conv}/link`, { username: 'nobody_here' }],
      ['delete', `/conversations/${conv}/link`, undefined],
      ['get', '/templates', undefined],
      ['get', '/agents', undefined],
      ['get', '/quick-replies', undefined],
    ] as const,
  });

  beforeAll(async () => {
    await graph.start();
    const dir = mkdtempSync(join(tmpdir(), 'kabso-wa360-'));
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
    support = await p.makeAdmin(['SUPPORT']);
    support2 = await p.makeAdmin(['SUPPORT']);
    finance = await p.makeAdmin(['FINANCE']);
    bd = await p.makeAdmin(['BD']);
    customer = await p.signup();
    vi.useRealTimers();
    for (const u of [owner, moderator, support, support2, finance, bd]) {
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
    await hook(textFrom('966511111111', 'مرحبا'));
    await hook(textFrom('966522222222', 'سؤال', 'Omar'));
    await settle(ctx);
    convA = (await ctx.prisma.waConversation.findUniqueOrThrow({ where: { phoneE164: '+966511111111' } })).id;
    convB = (await ctx.prisma.waConversation.findUniqueOrThrow({ where: { phoneE164: '+966522222222' } })).id;
  });
  afterAll(async () => {
    vi.useRealTimers();
    await ctx?.close();
    await graph.stop();
  });

  it('no level set: exactly D355 — OWNER / MODERATION MANAGE, SUPPORT REPLY, FINANCE / BD nothing', async () => {
    expect(await ctx.prisma.waStaffAccess.count()).toBe(0);
    const all = ['support.whatsapp', 'support.whatsapp.manage', 'support.whatsapp.view'];
    expect(await capsOf(owner)).toEqual(all);
    expect(await capsOf(moderator)).toEqual(all);
    expect(await capsOf(support)).toEqual(['support.whatsapp', 'support.whatsapp.view']);
    expect(await capsOf(finance)).toEqual([]);
    expect(await capsOf(bd)).toEqual([]);
    expect(await teamRow(owner)).toEqual({
      level: 'MANAGE',
      setLevel: null,
      defaultLevel: 'MANAGE',
      locked: true,
    });
    expect(await teamRow(moderator)).toEqual({
      level: 'MANAGE',
      setLevel: null,
      defaultLevel: 'MANAGE',
      locked: false,
    });
    expect(await teamRow(support)).toEqual({
      level: 'REPLY',
      setLevel: null,
      defaultLevel: 'REPLY',
      locked: false,
    });
    expect(await teamRow(finance)).toEqual({
      level: 'NONE',
      setLevel: null,
      defaultLevel: 'NONE',
      locked: false,
    });
    // The panel session carries the same capabilities.
    const session = await p.send(support, 'get', '/admin/auth/session');
    expect(WA(session.body.capabilities as string[])).toEqual(['support.whatsapp', 'support.whatsapp.view']);
    // SUPPORT reads and acts, not the quick-reply edits; FINANCE nothing.
    expect((await staff(support, 'get', '/summary')).status).toBe(200);
    expect((await staff(support, 'get', '/agents')).status).toBe(200);
    expect((await staff(support, 'post', '/quick-replies').send({ title: 'x', body: 'y' })).status).toBe(403);
    expect((await staff(finance, 'get', '/summary')).status).toBe(403);
    expect((await p.send(bd, 'get', '/admin/whatsapp/conversations')).status).toBe(403);
    // The agents (transfer targets) are the REPLY+ staff: OWNER, MODERATION, both SUPPORT.
    const agents = await staff(support, 'get', '/agents');
    expect(agents.body.data.map((a: { userId: string }) => a.userId).sort()).toEqual(
      [owner.id, moderator.id, support.id, support2.id].sort(),
    );
  });

  it('only team.manage sets a level; never on an OWNER or someone off the team; bad input refused', async () => {
    const byMod = await setLevel(support, 'VIEW', moderator);
    expect(byMod.status).toBe(403);
    const onOwner = await setLevel(owner, 'VIEW');
    expect(onOwner.status).toBe(409);
    expect(onOwner.body.error.details).toEqual([expect.objectContaining({ issue: 'team_whatsapp_owner' })]);
    const offTeam = await setLevel(customer, 'REPLY');
    expect(offTeam.status).toBe(409);
    expect(offTeam.body.error.details).toEqual([expect.objectContaining({ issue: 'team_not_member' })]);
    const bad = await setLevel(support, 'ADMIN');
    expect(bad.status).toBe(400);
    const noCode = await p.send(owner, 'put', `/admin/team/${support.id}/whatsapp`, {
      level: 'VIEW',
      reason: 'x',
      totpCode: '000000',
    });
    expect(noCode.status).not.toBe(200);
    expect(await ctx.prisma.waStaffAccess.count()).toBe(0);
  });

  it('VIEW: reads everything, every action 403, «مشاهدة فقط» — lowering releases the person’s conversations', async () => {
    // SUPPORT claims conversation A first (REPLY by default).
    const claim = await staff(support, 'post', `/conversations/${convA}/claim`);
    expect(claim.status, JSON.stringify(claim.body)).toBe(200);
    expect(claim.body.assignedTo.userId).toBe(support.id);

    const r = await setLevel(support, 'VIEW');
    expect(r.status, JSON.stringify(r.body)).toBe(200);
    expectContract(r, 'setAdminTeamWhatsApp');
    expect(r.body).toEqual({
      userId: support.id,
      before: 'REPLY',
      whatsapp: { level: 'VIEW', setLevel: 'VIEW', defaultLevel: 'REPLY', locked: false },
      released: 1,
    });
    // Released with the history and the audit (before, after, actor).
    const a = await ctx.prisma.waConversation.findUniqueOrThrow({ where: { id: convA } });
    expect(a.assignedToId).toBeNull();
    const hist = await staff(owner, 'get', `/conversations/${convA}/assignments`);
    expect(hist.body.data[0]).toMatchObject({
      action: 'RELEASE',
      from: { userId: support.id },
      to: null,
      by: { userId: owner.id },
    });
    const audit = await ctx.prisma.auditLog.findFirstOrThrow({
      where: { action: 'admin.team.whatsapp', targetId: support.id },
      orderBy: { createdAt: 'desc' },
    });
    expect(audit.actorUserId).toBe(owner.id);
    expect(audit.metadata).toMatchObject({
      before: 'REPLY',
      after: 'VIEW',
      setBefore: null,
      setAfter: 'VIEW',
      released: 1,
      conversations: [convA],
      reason: 'D360 test',
      via: 'panel',
    });

    expect(await capsOf(support)).toEqual(['support.whatsapp.view']);
    expect(await teamRow(support)).toMatchObject({ level: 'VIEW', setLevel: 'VIEW' });
    const routes = appRoutes(convB);
    for (const [m, path] of routes.reads) {
      const res = await staff(support, m, path);
      expect(res.status, `${m} ${path} ${JSON.stringify(res.body)}`).toBe(200);
    }
    const sum = await staff(support, 'get', '/summary');
    expectContract(sum, 'getStaffWhatsAppSummary');
    expect(sum.body).toMatchObject({ enabled: true, mine: 0 });
    expect(sum.body.unassigned).toBeGreaterThanOrEqual(1);
    expect((await staff(support, 'put', '/me/settings').send({ pushMuted: false })).status).toBe(200);
    const sentBefore = graph.sent.length;
    for (const [m, path, body] of routes.actions) {
      const req = staff(support, m, path);
      const res = body ? await req.send(body) : await req;
      expect(res.status, `${m} ${path}`).toBe(403);
      expect(res.body.error.code).toBe('AUTH_FORBIDDEN');
    }
    expect(graph.sent.length).toBe(sentBefore); // nothing reached Meta
    expect(graph.reads).toEqual([]); // no read receipt from a viewer
    const unread = await ctx.prisma.waConversation.findUniqueOrThrow({ where: { id: convB } });
    expect(unread.unreadCount).toBe(1);
    // The same from the panel (cookie).
    expect((await p.send(support, 'get', '/admin/whatsapp/conversations?filter=all')).status).toBe(200);
    expect((await p.send(support, 'get', `/admin/whatsapp/conversations/${convB}/messages`)).status).toBe(
      200,
    );
    expect((await p.send(support, 'get', `/admin/whatsapp/conversations/${convB}/notes`)).status).toBe(200);
    for (const [m, path, body] of [
      ['post', `/admin/whatsapp/conversations/${convB}/messages`, { type: 'TEXT', text: 'x' }],
      ['post', `/admin/whatsapp/conversations/${convB}/claim`, {}],
      ['post', `/admin/whatsapp/conversations/${convB}/notes`, { body: 'x' }],
      ['post', `/admin/whatsapp/conversations/${convB}/read`, {}],
      ['get', '/admin/whatsapp/agents', undefined],
      ['get', '/admin/whatsapp/settings', undefined],
    ] as const) {
      expect((await p.send(support, m, path, body)).status, `${m} ${path}`).toBe(403);
    }
    const session = await p.send(support, 'get', '/admin/auth/session');
    expect(WA(session.body.capabilities as string[])).toEqual(['support.whatsapp.view']);

    // VIEW is never a transfer target nor an agent.
    const toViewer = await staff(moderator, 'post', `/conversations/${convB}/transfer`).send({
      toUserId: support.id,
    });
    expect(toViewer.status).toBe(400);
    expect(toViewer.body.error.details).toEqual([{ field: 'toUserId', issue: 'not_an_agent' }]);
    const agents = await staff(moderator, 'get', '/agents');
    expect(agents.body.data.map((x: { userId: string }) => x.userId)).not.toContain(support.id);
  });

  it('the badge and the pushes reach VIEW and above, never NONE; somebody who can reply is always told', async () => {
    await ctx.prisma.adminShift.updateMany({ data: { onShift: false } });
    expect((await setLevel(finance, 'NONE')).status).toBe(200);
    // Nobody on shift: every REPLY+ agent; the VIEW support is off shift.
    let before = push.sent.length;
    await hook(textFrom('966533333333', 'مرحبا ١'));
    await settle(ctx);
    expect(
      pushedTo(before)
        .map((u) => u.id)
        .sort(),
    ).toEqual([owner.id, moderator.id, support2.id].sort());
    // Only the VIEW support on shift: they are told, and so is every REPLY+ agent (the viewer cannot answer).
    await ctx.prisma.adminShift.upsert({
      where: { userId: support.id },
      create: { userId: support.id, onShift: true },
      update: { onShift: true },
    });
    before = push.sent.length;
    await hook(textFrom('966544444444', 'مرحبا ٢'));
    await settle(ctx);
    expect(
      pushedTo(before)
        .map((u) => u.id)
        .sort(),
    ).toEqual([owner.id, moderator.id, support.id, support2.id].sort());
    // The viewer and a REPLY agent on shift: only those two.
    await ctx.prisma.adminShift.upsert({
      where: { userId: support2.id },
      create: { userId: support2.id, onShift: true },
      update: { onShift: true },
    });
    before = push.sent.length;
    await hook(textFrom('966555555555', 'مرحبا ٣'));
    await settle(ctx);
    expect(
      pushedTo(before)
        .map((u) => u.id)
        .sort(),
    ).toEqual([support.id, support2.id].sort());
    // FINANCE set to NONE explicitly and BD by default: no badge.
    expect((await staff(finance, 'get', '/summary')).status).toBe(403);
    expect((await staff(bd, 'get', '/summary')).status).toBe(403);
    await ctx.prisma.adminShift.updateMany({ data: { onShift: false } });
  });

  it('REPLY given to FINANCE: it answers and claims; MANAGE vs REPLY decides the quick replies and settings', async () => {
    const r = await setLevel(finance, 'REPLY');
    expect(r.body.whatsapp).toEqual({
      level: 'REPLY',
      setLevel: 'REPLY',
      defaultLevel: 'NONE',
      locked: false,
    });
    expect(await capsOf(finance)).toEqual(['support.whatsapp', 'support.whatsapp.view']);
    const send = await staff(finance, 'post', `/conversations/${convB}/messages`).send({
      type: 'TEXT',
      text: 'أهلاً',
    });
    expect(send.status, JSON.stringify(send.body)).toBe(201);
    expect((await staff(finance, 'get', `/conversations/${convB}`)).body.assignedToMe).toBe(true);
    expect((await staff(finance, 'post', '/quick-replies').send({ title: 'a', body: 'b' })).status).toBe(403);
    expect((await p.send(finance, 'get', '/admin/whatsapp/settings')).status).toBe(403);
    // The moderator lowered to REPLY loses the management; MANAGE given to SUPPORT2 gains it.
    expect((await setLevel(moderator, 'REPLY')).body.released).toBe(0);
    expect((await staff(moderator, 'post', '/quick-replies').send({ title: 'm', body: 'b' })).status).toBe(
      403,
    );
    expect((await p.send(moderator, 'get', '/admin/whatsapp/settings')).status).toBe(403);
    // REPLY only: a conversation assigned to someone else stays theirs.
    expect((await staff(moderator, 'post', `/conversations/${convB}/release`)).status).toBe(409);
    expect((await setLevel(support2, 'MANAGE')).status).toBe(200);
    const qr = await staff(support2, 'post', '/quick-replies').send({ title: 'ترحيب', body: 'أهلاً بك' });
    expect(qr.status, JSON.stringify(qr.body)).toBe(201);
    expect((await p.send(support2, 'get', '/admin/whatsapp/settings')).status).toBe(200);
    // Back to the default: the moderator is MANAGE again, no row left.
    const reset = await setLevel(moderator, null);
    expect(reset.body).toMatchObject({
      before: 'REPLY',
      whatsapp: { level: 'MANAGE', setLevel: null, defaultLevel: 'MANAGE' },
    });
    expect(await ctx.prisma.waStaffAccess.count({ where: { userId: moderator.id } })).toBe(0);
    expect((await p.send(moderator, 'get', '/admin/whatsapp/settings')).status).toBe(200);
  });

  it('NONE: no WhatsApp at all, not even the badge, from the app or the panel', async () => {
    const r = await setLevel(moderator, 'NONE');
    expect(r.status).toBe(200);
    expect(await capsOf(moderator)).toEqual([]);
    for (const path of ['/summary', '/conversations', `/conversations/${convB}`, '/me/settings']) {
      expect((await staff(moderator, 'get', path)).status, path).toBe(403);
    }
    expect((await p.send(moderator, 'get', '/admin/whatsapp/summary')).status).toBe(403);
    // Their other capabilities are untouched (reports, lives).
    const me = await ctx.http.get('/api/v1/staff/me').set(auth(moderator));
    expect(me.body.capabilities).toEqual(expect.arrayContaining(['lives.watch', 'reports.view']));
    expect((await setLevel(moderator, null)).body.whatsapp.level).toBe('MANAGE');
  });

  it('a revoke that lowers the level releases the conversations too; off the team, the level set goes', async () => {
    // FINANCE (REPLY by a level) holds conversation B; revoking FINANCE leaves no role → NONE.
    expect((await ctx.prisma.waConversation.findUniqueOrThrow({ where: { id: convB } })).assignedToId).toBe(
      finance.id,
    );
    const totpCode = p.nextCode(owner.secret);
    const rv = await p.send(owner, 'post', `/admin/team/${finance.id}/revoke`, {
      role: 'FINANCE',
      reason: 'D360 revoke',
      totpCode,
    });
    vi.useRealTimers();
    expect(rv.status, JSON.stringify(rv.body)).toBe(200);
    expect(
      (await ctx.prisma.waConversation.findUniqueOrThrow({ where: { id: convB } })).assignedToId,
    ).toBeNull();
    expect(await ctx.prisma.waStaffAccess.count({ where: { userId: finance.id } })).toBe(0);
    const audit = await ctx.prisma.auditLog.findFirstOrThrow({
      where: { action: 'admin.team.whatsapp', targetId: finance.id },
      orderBy: { createdAt: 'desc' },
    });
    expect(audit.metadata).toMatchObject({
      before: 'REPLY',
      after: 'NONE',
      setBefore: 'REPLY',
      setAfter: null,
      released: 1,
      cause: 'role_revoked',
    });
    // Raising back from VIEW keeps nothing assigned and gives the actions back.
    const up = await setLevel(support, 'REPLY');
    expect(up.body).toMatchObject({ before: 'VIEW', released: 0, whatsapp: { level: 'REPLY' } });
    expect((await staff(support, 'post', `/conversations/${convA}/claim`)).status).toBe(200);
    await settle(ctx);
  });
});
