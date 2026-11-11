/**
 * D364 (owner approved «نعم موافق»; contract v1.122-social, CONVENTIONS §10.157): WhatsApp departments and the transfer
 * with a department, a target and a note. End to end against PostgreSQL + Redis with the fake Graph API of D355: the
 * defaults (everyone and every conversation GENERAL), setting departments from «الموظفون والصلاحيات» (team.manage, code +
 * reason, audited; REPLY+ only), a transfer to a person (refused outside the department or below REPLY), «أول متاح في
 * القسم» (fewest open, then least recently assigned, never the current assignee), the department queue when nobody is on
 * shift, the note kept internal (never sent) and linked to the history, the history itself, the push recipients (the
 * receiver; the department for the queue; never the actor or a muted one), the department filter, and D355's transfer
 * call without a department still working (GENERAL).
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
const PNID = '1098765432164';
const WABA = '2098765432164';
const auth = (u: { token: string }) => ({ Authorization: `Bearer ${u.token}` });
const unix = (d = new Date()) => String(Math.floor(d.getTime() / 1000));

describe('D364 contract coverage', () => {
  it('openapi v1.122-social declares the departments operation', () => {
    const ids = operations().map((o) => `${o.operationId} ${o.method.toUpperCase()} ${o.path}`);
    expect(ids).toContain(
      'setAdminTeamWhatsAppDepartments PUT /api/v1/admin/team/{userId}/whatsapp/departments',
    );
  });
});

describe('D364 WhatsApp departments and the transfer', { timeout: 600_000 }, () => {
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
  let ali: Admin; // SUPPORT → PAYMENTS
  let badr: Admin; // SUPPORT → PAYMENTS + TECHNICAL
  let chadi: Admin; // SUPPORT, GENERAL by default
  let viewer: Admin; // SUPPORT lowered to VIEW
  let finance: Admin; // NONE by default
  let customer: Person;
  const conv = { a: '', b: '', c: '', d: '', e: '' };
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
      messages: [{ from: phone, id: `wamid.D364-${seq}`, timestamp: unix(), type: 'text', text: { body } }],
    };
  };
  const staff = (u: { token: string }, method: 'get' | 'post' | 'put', path: string) =>
    ctx.http[method](`/api/v1/staff/whatsapp${path}`).set(auth(u));
  const everyone = () => [owner, moderator, ali, badr, chadi, viewer, finance];
  /** Who got a WhatsApp transfer push since `since`. */
  const transferPushedTo = (since: number) => {
    const sent = push.sent
      .slice(since)
      .filter((m) => m.data.kind === 'whatsapp' && m.data.event === 'transfer');
    return everyone()
      .filter((u) => sent.some((m) => m.tokens.some((t) => t.includes(u.id.slice(-8)))))
      .map((u) => u.id)
      .sort();
  };
  const setDepartments = async (target: Person, departments: unknown, by: Admin = owner) => {
    const totpCode = p.nextCode(by.secret);
    const r = await p.send(by, 'put', `/admin/team/${target.id}/whatsapp/departments`, {
      departments,
      reason: 'D364 test',
      totpCode,
    });
    vi.useRealTimers();
    return r;
  };
  const setLevel = async (target: Person, level: string | null) => {
    const totpCode = p.nextCode(owner.secret);
    const r = await p.send(owner, 'put', `/admin/team/${target.id}/whatsapp`, {
      level,
      reason: 'D364 test',
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
    return (r.body.data as { id: string; whatsappDepartments: unknown }[]).find((m) => m.id === u.id)!
      .whatsappDepartments;
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
  /** The panel's transfer (the panel's session does not switch a shift on). */
  const transfer = (by: Admin, id: string, body: object) =>
    p.send(by, 'post', `/admin/whatsapp/conversations/${id}/transfer`, body);
  const rowOf = (id: string) => ctx.prisma.waConversation.findUniqueOrThrow({ where: { id } });

  beforeAll(async () => {
    await graph.start();
    const dir = mkdtempSync(join(tmpdir(), 'kabso-wa364-'));
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
    ali = await p.makeAdmin(['SUPPORT']);
    badr = await p.makeAdmin(['SUPPORT']);
    chadi = await p.makeAdmin(['SUPPORT']);
    viewer = await p.makeAdmin(['SUPPORT']);
    finance = await p.makeAdmin(['FINANCE']);
    customer = await p.signup();
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
    for (const [k, phone] of [
      ['a', '966511110001'],
      ['b', '966511110002'],
      ['c', '966511110003'],
      ['d', '966511110004'],
      ['e', '966511110005'],
    ] as const) {
      await hook(textFrom(phone, `مرحبا ${k}`, `عميل ${k}`));
      conv[k] = (await ctx.prisma.waConversation.findUniqueOrThrow({ where: { phoneE164: `+${phone}` } })).id;
    }
    await settle(ctx);
  });
  afterAll(async () => {
    vi.useRealTimers();
    await ctx?.close();
    await graph.stop();
  });

  it('the defaults: every staff member and every conversation is GENERAL; agents carry departments and load', async () => {
    expect(await ctx.prisma.waStaffDepartment.count()).toBe(0);
    expect(await teamRow(ali)).toEqual({ departments: ['GENERAL'], isDefault: true });
    expect(await teamRow(owner)).toEqual({ departments: ['GENERAL'], isDefault: true });
    const c = await staff(owner, 'get', `/conversations/${conv.a}`);
    expectContract(c, 'getStaffWhatsAppConversation');
    expect(c.body.department).toBe('GENERAL');
    const agents = await staff(owner, 'get', '/agents');
    expectContract(agents, 'getStaffWhatsAppAgents');
    for (const a of agents.body.data as { departments: string[]; openCount: number }[]) {
      expect(a.departments).toEqual(['GENERAL']);
      expect(a.openCount).toBe(0);
    }
    expect((await staff(owner, 'get', '/agents?department=SALES')).status).toBe(400);
  });

  it('departments are set by team.manage only, for REPLY+ team members, audited', async () => {
    expect((await setLevel(viewer, 'VIEW')).status).toBe(200);
    expect((await setDepartments(ali, ['PAYMENTS'], moderator)).status).toBe(403);
    const offTeam = await setDepartments(customer, ['PAYMENTS']);
    expect(offTeam.status).toBe(409);
    expect(offTeam.body.error.details).toEqual([expect.objectContaining({ issue: 'team_not_member' })]);
    const low = await setDepartments(viewer, ['PAYMENTS']);
    expect(low.status).toBe(409);
    expect(low.body.error.details).toEqual([expect.objectContaining({ issue: 'team_departments_level' })]);
    expect((await setDepartments(finance, ['GENERAL'])).body.error.details).toEqual([
      expect.objectContaining({ issue: 'team_departments_level' }),
    ]);
    expect((await setDepartments(ali, ['SALES'])).status).toBe(400);
    expect((await setDepartments(ali, ['PAYMENTS', 'PAYMENTS'])).status).toBe(400);
    const noCode = await p.send(owner, 'put', `/admin/team/${ali.id}/whatsapp/departments`, {
      departments: ['PAYMENTS'],
      reason: 'x',
      totpCode: '000000',
    });
    expect(noCode.status).not.toBe(200);
    expect(await ctx.prisma.waStaffDepartment.count()).toBe(0);

    const r = await setDepartments(ali, ['PAYMENTS']);
    expect(r.status, JSON.stringify(r.body)).toBe(200);
    expectContract(r, 'setAdminTeamWhatsAppDepartments');
    expect(r.body).toEqual({
      userId: ali.id,
      before: ['GENERAL'],
      whatsappDepartments: { departments: ['PAYMENTS'], isDefault: false },
    });
    const b = await setDepartments(badr, ['TECHNICAL', 'PAYMENTS']);
    expect(b.body.whatsappDepartments).toEqual({ departments: ['PAYMENTS', 'TECHNICAL'], isDefault: false });
    expect(await teamRow(badr)).toEqual({ departments: ['PAYMENTS', 'TECHNICAL'], isDefault: false });
    const audit = await ctx.prisma.auditLog.findFirstOrThrow({
      where: { action: 'admin.team.whatsapp_departments', targetId: badr.id },
      orderBy: { createdAt: 'desc' },
    });
    expect(audit.actorUserId).toBe(owner.id);
    expect(audit.metadata).toMatchObject({
      before: ['GENERAL'],
      after: ['PAYMENTS', 'TECHNICAL'],
      setBefore: [],
      setAfter: ['PAYMENTS', 'TECHNICAL'],
      reason: 'D364 test',
      via: 'panel',
    });
    // [] goes back to the default; set again for the next tests.
    const reset = await setDepartments(ali, []);
    expect(reset.body).toMatchObject({ before: ['PAYMENTS'], whatsappDepartments: { isDefault: true } });
    expect(await ctx.prisma.waStaffDepartment.count({ where: { userId: ali.id } })).toBe(0);
    expect((await setDepartments(ali, ['PAYMENTS'])).status).toBe(200);
    const payments = await staff(owner, 'get', '/agents?department=PAYMENTS');
    expect(payments.body.data.map((x: { userId: string }) => x.userId).sort()).toEqual(
      [ali.id, badr.id].sort(),
    );
    const general = await staff(owner, 'get', '/agents?department=GENERAL');
    expect(general.body.data.map((x: { userId: string }) => x.userId)).not.toContain(ali.id);
    expect(general.body.data.map((x: { userId: string }) => x.userId)).toContain(chadi.id);
    expect(general.body.data.map((x: { userId: string }) => x.userId)).not.toContain(viewer.id);
  });

  it('to a person: only REPLY+ and in the department; the note stays internal and is linked to the history', async () => {
    expect((await staff(chadi, 'post', `/conversations/${conv.a}/claim`)).status).toBe(200);
    // Outside the department, below REPLY, unknown: refused, nothing changes.
    const notIn = await staff(chadi, 'post', `/conversations/${conv.a}/transfer`).send({
      department: 'PAYMENTS',
      toUserId: chadi.id,
    });
    expect(notIn.status).toBe(400);
    expect(notIn.body.error.details).toEqual([{ field: 'toUserId', issue: 'not_in_department' }]);
    const toViewer = await staff(chadi, 'post', `/conversations/${conv.a}/transfer`).send({
      department: 'GENERAL',
      toUserId: viewer.id,
    });
    expect(toViewer.status).toBe(400);
    expect(toViewer.body.error.details).toEqual([{ field: 'toUserId', issue: 'not_an_agent' }]);
    const tooLong = await staff(chadi, 'post', `/conversations/${conv.a}/transfer`).send({
      department: 'PAYMENTS',
      toUserId: ali.id,
      note: 'x'.repeat(501),
    });
    expect(tooLong.status).toBe(400);
    expect((await rowOf(conv.a)).assignedToId).toBe(chadi.id);
    // A viewer cannot transfer at all.
    expect(
      (await staff(viewer, 'post', `/conversations/${conv.a}/transfer`).send({ department: 'GENERAL' }))
        .status,
    ).toBe(403);

    const graphBefore = graph.sent.length;
    const pushBefore = push.sent.length;
    const note = 'العميل دفع للوكيل ٥٠٠٠ كوينز ولم تصل — الإيصال في المحادثة';
    const tr = await staff(chadi, 'post', `/conversations/${conv.a}/transfer`).send({
      department: 'PAYMENTS',
      toUserId: badr.id,
      note,
    });
    expect(tr.status, JSON.stringify(tr.body)).toBe(200);
    expectContract(tr, 'transferStaffWhatsAppConversation');
    expect(tr.body).toMatchObject({ department: 'PAYMENTS', assignedTo: { userId: badr.id } });
    await settle(ctx);
    // Never sent to the customer.
    expect(graph.sent.length).toBe(graphBefore);
    // The note is an internal note.
    const notes = await staff(owner, 'get', `/conversations/${conv.a}/notes`);
    expect(notes.body.data).toEqual([
      expect.objectContaining({ body: note, author: expect.objectContaining({ userId: chadi.id }) }),
    ]);
    // The history: who, from, to, department, note, when.
    const h = await staff(owner, 'get', `/conversations/${conv.a}/assignments`);
    expectContract(h, 'getStaffWhatsAppAssignments');
    expect(h.body.data[0]).toMatchObject({
      action: 'TRANSFER',
      from: { userId: chadi.id },
      to: { userId: badr.id },
      by: { userId: chadi.id },
      department: 'PAYMENTS',
      fromDepartment: 'GENERAL',
      note: { id: notes.body.data[0].id, body: note },
    });
    expect(Date.parse(h.body.data[0].at)).toBeGreaterThan(Date.now() - 60_000);
    expect(h.body.data[1]).toMatchObject({ action: 'CLAIM', department: null, note: null });
    const audit = await ctx.prisma.auditLog.findFirstOrThrow({
      where: { action: 'whatsapp.conversation.assign', targetId: conv.a },
      orderBy: { createdAt: 'desc' },
    });
    expect(audit.metadata).toMatchObject({
      action: 'TRANSFER',
      from: chadi.id,
      to: badr.id,
      department: 'PAYMENTS',
      fromDepartment: 'GENERAL',
      routed: 'person',
      legacy: false,
    });
    // Pushed to the receiver only (never the one who transferred).
    expect(transferPushedTo(pushBefore)).toEqual([badr.id]);
    const pushed = push.sent.slice(pushBefore).find((m) => m.data.event === 'transfer')!;
    expect(pushed.data).toMatchObject({ kind: 'whatsapp', conversationId: conv.a, department: 'PAYMENTS' });
    // A muted receiver is not pushed.
    await staff(ali, 'put', '/me/settings').send({ pushMuted: true });
    const mutedBefore = push.sent.length;
    const toAli = await staff(badr, 'post', `/conversations/${conv.a}/transfer`).send({
      department: 'PAYMENTS',
      toUserId: ali.id,
    });
    expect(toAli.body.assignedTo.userId).toBe(ali.id);
    await settle(ctx);
    expect(transferPushedTo(mutedBefore)).toEqual([]);
    await staff(ali, 'put', '/me/settings').send({ pushMuted: false });
  });

  it('first available: on shift and in the department, fewest open, ties to the least recently assigned', async () => {
    // ali holds conversation a (1 open), badr none; both in PAYMENTS, chadi is GENERAL only.
    await onShift(ali, badr, chadi);
    const r1 = await transfer(owner, conv.b, { department: 'PAYMENTS' });
    expect(r1.status, JSON.stringify(r1.body)).toBe(200);
    expectContract(r1, 'transferAdminWhatsAppConversation');
    expect(r1.body).toMatchObject({ department: 'PAYMENTS', assignedTo: { userId: badr.id } });
    // Now 1 each: the tie goes to the one assigned least recently — ali (a, earlier) before badr (b, just now).
    await onShift(ali, badr);
    const r2 = await transfer(owner, conv.c, { department: 'PAYMENTS' });
    expect(r2.body.assignedTo.userId).toBe(ali.id);
    // ali 2, badr 1: badr. The agents list shows the load.
    const agents = await staff(owner, 'get', '/agents?department=PAYMENTS');
    expect(
      Object.fromEntries(
        (agents.body.data as { userId: string; openCount: number }[]).map((a) => [a.userId, a.openCount]),
      ),
    ).toEqual({ [ali.id]: 2, [badr.id]: 1 });
    // Off shift does not count: only ali on shift → ali, even with more open.
    await onShift(ali);
    const r3 = await transfer(owner, conv.d, { department: 'PAYMENTS', note: 'أول متاح' });
    expect(r3.body.assignedTo.userId).toBe(ali.id);
    const h = await staff(owner, 'get', `/conversations/${conv.d}/assignments`);
    expect(h.body.data[0]).toMatchObject({ to: { userId: ali.id }, note: { body: 'أول متاح' } });
    // Never the current assignee: ali hands d to PAYMENTS with badr on shift → badr.
    await onShift(ali, badr);
    const r4 = await transfer(ali, conv.d, { department: 'PAYMENTS' });
    expect(r4.body.assignedTo.userId).toBe(badr.id);
    const audit = await ctx.prisma.auditLog.findFirstOrThrow({
      where: { action: 'whatsapp.conversation.assign', targetId: conv.d },
      orderBy: { createdAt: 'desc' },
    });
    expect(audit.metadata).toMatchObject({ routed: 'first_available', from: ali.id, to: badr.id });
  });

  it('nobody on shift: the department queue, shown under «غير مسندة» by department; the members are pushed', async () => {
    await onShift();
    const pushBefore = push.sent.length;
    const r = await transfer(owner, conv.e, { department: 'TECHNICAL', note: 'مشكلة في الكاميرا' });
    expect(r.status, JSON.stringify(r.body)).toBe(200);
    expect(r.body).toMatchObject({ department: 'TECHNICAL', assignedTo: null });
    await settle(ctx);
    // Nobody on shift in TECHNICAL: every member (badr) is told.
    expect(transferPushedTo(pushBefore)).toEqual([badr.id]);
    const q = await staff(owner, 'get', '/conversations?filter=unassigned&department=TECHNICAL');
    expectContract(q, 'getStaffWhatsAppConversations');
    expect(q.body.data.map((c: { id: string }) => c.id)).toEqual([conv.e]);
    const pay = await staff(owner, 'get', '/conversations?filter=all&department=PAYMENTS');
    expect(pay.body.data.map((c: { id: string }) => c.id).sort()).toEqual(
      [conv.a, conv.b, conv.c, conv.d].sort(),
    );
    expect((await staff(owner, 'get', '/conversations?department=NOPE')).status).toBe(400);
    const panelList = await p.send(
      owner,
      'get',
      '/admin/whatsapp/conversations?filter=unassigned&department=TECHNICAL',
    );
    expectContract(panelList, 'getAdminWhatsAppConversations');
    expect(panelList.body.data.map((c: { id: string }) => c.id)).toEqual([conv.e]);
    const h = await staff(owner, 'get', `/conversations/${conv.e}/assignments`);
    expect(h.body.data[0]).toMatchObject({
      action: 'TRANSFER',
      from: null,
      to: null,
      department: 'TECHNICAL',
      fromDepartment: 'GENERAL',
      note: { body: 'مشكلة في الكاميرا' },
    });
    // With a member on shift the queue push goes to them only (here the routing picks them instead).
    await onShift(badr);
    const before2 = push.sent.length;
    const r2 = await transfer(owner, conv.e, { department: 'TECHNICAL' });
    expect(r2.body.assignedTo.userId).toBe(badr.id);
    await settle(ctx);
    expect(transferPushedTo(before2)).toEqual([badr.id]);
    // badr is the only TECHNICAL member and the assignee: handing it on goes to the queue, nobody else to push.
    const before3 = push.sent.length;
    const r3 = await staff(badr, 'post', `/conversations/${conv.e}/transfer`).send({
      department: 'TECHNICAL',
    });
    expect(r3.body).toMatchObject({ department: 'TECHNICAL', assignedTo: null });
    await settle(ctx);
    expect(transferPushedTo(before3)).toEqual([]);
    await onShift();
  });

  it('D355’s call without a department still works: GENERAL, an explicit person, no membership check', async () => {
    // e is in TECHNICAL, unassigned; ali is PAYMENTS only.
    const r = await staff(chadi, 'post', `/conversations/${conv.e}/transfer`).send({ toUserId: ali.id });
    expect(r.status, JSON.stringify(r.body)).toBe(200);
    expect(r.body).toMatchObject({ department: 'GENERAL', assignedTo: { userId: ali.id } });
    const audit = await ctx.prisma.auditLog.findFirstOrThrow({
      where: { action: 'whatsapp.conversation.assign', targetId: conv.e },
      orderBy: { createdAt: 'desc' },
    });
    expect(audit.metadata).toMatchObject({
      legacy: true,
      department: 'GENERAL',
      fromDepartment: 'TECHNICAL',
    });
    // The same person again: nothing changes (D355's no-op, no history row).
    const rows = await ctx.prisma.waAssignment.count({ where: { conversationId: conv.e } });
    expect(
      (await staff(ali, 'post', `/conversations/${conv.e}/transfer`).send({ toUserId: ali.id })).status,
    ).toBe(200);
    expect(await ctx.prisma.waAssignment.count({ where: { conversationId: conv.e } })).toBe(rows);
    // Below REPLY still refused; neither a department nor a person: 400.
    const toViewer = await staff(ali, 'post', `/conversations/${conv.e}/transfer`).send({
      toUserId: viewer.id,
    });
    expect(toViewer.body.error.details).toEqual([{ field: 'toUserId', issue: 'not_an_agent' }]);
    const empty = await staff(ali, 'post', `/conversations/${conv.e}/transfer`).send({});
    expect(empty.status).toBe(400);
    expect(empty.body.error.details).toEqual([{ field: 'toUserId', issue: 'required' }]);
    // Someone else's conversation without MANAGE: 409; a closed one: 409 closed.
    const theirs = await staff(chadi, 'post', `/conversations/${conv.e}/transfer`).send({
      department: 'GENERAL',
    });
    expect(theirs.status).toBe(409);
    expect((await staff(ali, 'post', `/conversations/${conv.e}/close`)).status).toBe(200);
    const closed = await staff(ali, 'post', `/conversations/${conv.e}/transfer`).send({
      department: 'REPORTS',
    });
    expect(closed.body.error.code).toBe('WHATSAPP_CONVERSATION_CLOSED');
    expect((await rowOf(conv.e)).department).toBe('GENERAL');
  });

  it('a lowered member stops being a target; off the team the departments go', async () => {
    expect((await setLevel(badr, 'VIEW')).status).toBe(200);
    expect((await staff(owner, 'get', '/agents?department=TECHNICAL')).body.data).toEqual([]);
    const toBadr = await transfer(owner, conv.c, { department: 'TECHNICAL', toUserId: badr.id });
    expect(toBadr.body.error.details).toEqual([{ field: 'toUserId', issue: 'not_an_agent' }]);
    // Kept while VIEW (they count again if raised), but no more edits at VIEW.
    expect(await ctx.prisma.waStaffDepartment.count({ where: { userId: badr.id } })).toBe(2);
    expect((await setDepartments(badr, ['GENERAL'])).status).toBe(409);
    expect((await setLevel(badr, null)).status).toBe(200);
    expect(await teamRow(badr)).toEqual({ departments: ['PAYMENTS', 'TECHNICAL'], isDefault: false });
    const totpCode = p.nextCode(owner.secret);
    const rv = await p.send(owner, 'post', `/admin/team/${badr.id}/revoke`, {
      role: 'SUPPORT',
      reason: 'D364 revoke',
      totpCode,
    });
    vi.useRealTimers();
    expect(rv.status, JSON.stringify(rv.body)).toBe(200);
    expect(await ctx.prisma.waStaffDepartment.count({ where: { userId: badr.id } })).toBe(0);
    await settle(ctx);
  });
});
