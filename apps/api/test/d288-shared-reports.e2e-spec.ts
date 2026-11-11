/**
 * D288 (owner 2026-11-06: «ان البلاغ يصل كل المشرفين والدعم والذي يقوم بحله يضغط تم حله», and «يلغي» for the code on
 * the permanent ban and the permanent content deletion; contract v1.78-live, CONVENTIONS §10.101), end to end against
 * PostgreSQL + Redis:
 *
 *  - the permanent ban and the permanent deletion of a post / story work without the authenticator code, still need
 *    the capability and a reason, and are audited; a code sent by an older panel is ignored;
 *  - everything else D286 kept still asks for the code: account deletion, the temporary password, the e-mail change, a
 *    balance adjustment, a team role grant;
 *  - every report is visible to OWNER, MODERATION and SUPPORT (panel and app), not FINANCE or BD; a new report notifies
 *    every MODERATION and SUPPORT account (`STAFF_REPORT_NEW`, one unread row each, pushed on the staff channel);
 *  - the counters; «تم حله» resolves for everyone with who / when / note, audited; a second press → 409; two at once →
 *    one 200 and one 409; reopen is OWNER and MODERATION (owner: option B), never SUPPORT;
 *  - account deletion works without the code too (owner «نعم»).
 */
import { randomUUID } from 'node:crypto';
import type request from 'supertest';
import { afterAll, beforeAll, describe, expect, it, vi } from 'vitest';
import { grantRoleIn } from '../src/modules/admin-panel/admin-roles.js';
import { totpCode } from '../src/modules/admin-panel/totp.js';
import { NotificationPushDispatcher } from '../src/modules/notifications/notification-push.dispatcher.js';
import {
  PUSH_SENDER,
  type PushMessage,
  type PushSendResult,
  type PushSender,
} from '../src/modules/push/push-sender.js';
import { expectContract, operations } from './helpers/openapi.js';
import { createTestApp, newUser, withMigrationClient, type TestContext } from './helpers/test-app.js';

const COOKIE = '__Host-kabso_admin';

class FakePushSender implements PushSender {
  readonly enabled = true;
  readonly sent: PushMessage[] = [];
  send(message: PushMessage): Promise<PushSendResult> {
    this.sent.push(message);
    return Promise.resolve({ sent: message.tokens.length, failed: 0, invalidTokens: [] });
  }
}

interface TestUser {
  readonly id: string;
  readonly username: string;
  readonly email: string;
  readonly password: string;
  token: string;
}
interface Staff extends TestUser {
  secret: string;
  cookie: string;
  csrf: string;
}

describe('D288 contract coverage', () => {
  it('openapi v1.78-live declares the shared queue in the panel (admin session) and the app (tag staff)', () => {
    const byId = new Map(operations().map((o) => [o.operationId, o]));
    for (const id of ['getAdminPanelReportsSummary', 'resolveAdminPanelReport', 'reopenAdminPanelReport']) {
      const o = byId.get(id)!;
      expect(o, id).toBeDefined();
      expect(String(o.spec.description)).toContain('(v1.78-live, D288');
      expect(o.spec.tags).toEqual(['admin-panel']);
      expect(o.spec.security).toEqual([{ adminSession: [] }]);
    }
    for (const id of ['listStaffReports', 'getStaffReportsSummary', 'resolveStaffReport']) {
      const o = byId.get(id)!;
      expect(o, id).toBeDefined();
      expect(o.spec.tags).toEqual(['staff']);
      expect(o.spec.security).toBeUndefined();
    }
  });
});

describe('D288 shared reports, and no code for the ban and content deletion', { timeout: 900_000 }, () => {
  let ctx: TestContext;
  const push = new FakePushSender();
  let clock = Date.now();
  const advance = (ms: number) => {
    clock += ms;
    vi.setSystemTime(clock);
  };
  const nextCode = (secret: string) => {
    advance(30_000);
    return totpCode(secret, clock);
  };
  let ipCounter = 60;
  const nextIp = () => {
    ipCounter += 1;
    return `198.51.${Math.floor(ipCounter / 250)}.${(ipCounter % 250) + 1}`;
  };
  const auth = (u: { token: string }) => ({ Authorization: `Bearer ${u.token}` });

  const signup = async (): Promise<TestUser> => {
    const payload = newUser();
    const email = String(payload.email).trim().toLowerCase();
    const before = ctx.mail.sent.length;
    const ip = nextIp();
    const res = await ctx.http.post('/api/v1/auth/register').set('X-Forwarded-For', ip).send(payload);
    expect(res.status, JSON.stringify(res.body)).toBe(202);
    const mail = await ctx.mail.waitFor(email, 'code', before);
    const ok = await ctx.http
      .post('/api/v1/auth/register/verify')
      .set('X-Forwarded-For', ip)
      .send({ email, code: mail.code });
    expect(ok.status, JSON.stringify(ok.body)).toBe(201);
    return {
      id: ok.body.user.id as string,
      username: ok.body.user.username as string,
      email,
      password: String(payload.password),
      token: ok.body.tokens.accessToken as string,
    };
  };
  const cookieOf = (res: request.Response): string => {
    const raw = ([] as string[]).concat(res.headers['set-cookie'] ?? []);
    const line = raw.find((c) => c.startsWith(`${COOKIE}=`));
    if (!line) throw new Error(`no session cookie in ${JSON.stringify(raw)}`);
    return line.split(';')[0]!;
  };
  const makeStaff = async (roles: string[]): Promise<Staff> => {
    const p = await signup();
    await withMigrationClient(async (db) => {
      for (const role of roles) await db.$transaction((tx) => grantRoleIn(tx, p.email, role as never));
    });
    const res = await ctx.http
      .post('/api/v1/admin/auth/login')
      .send({ email: p.email, password: p.password });
    const pending = cookieOf(res);
    const csrf = res.body.csrfToken as string;
    const enrolRes = await ctx.http
      .post('/api/v1/admin/auth/totp/enrolment')
      .set('Cookie', pending)
      .set('X-CSRF-Token', csrf);
    const secret = enrolRes.body.secret as string;
    const confirm = await ctx.http
      .post('/api/v1/admin/auth/totp/enrolment/confirm')
      .set('Cookie', pending)
      .set('X-CSRF-Token', csrf)
      .send({ code: nextCode(secret) });
    expect(confirm.status, JSON.stringify(confirm.body)).toBe(200);
    return { ...p, secret, cookie: cookieOf(confirm), csrf: confirm.body.session.csrfToken as string };
  };
  const sget = (u: { token: string }, path: string) => ctx.http.get(`/api/v1${path}`).set(auth(u));
  const spost = (u: { token: string }, path: string, body: object = {}) =>
    ctx.http.post(`/api/v1${path}`).set(auth(u)).send(body);
  const aget = (s: Staff, path: string) => ctx.http.get(`/api/v1/admin${path}`).set('Cookie', s.cookie);
  const apost = (s: Staff, path: string, body: object = {}) =>
    ctx.http.post(`/api/v1/admin${path}`).set('Cookie', s.cookie).set('X-CSRF-Token', s.csrf).send(body);
  const audits = (action: string, targetId?: string) =>
    ctx.prisma.auditLog.findMany({
      where: { action, ...(targetId ? { targetId } : {}) },
      orderBy: [{ createdAt: 'asc' }, { id: 'asc' }],
    });
  const newPost = async (author: TestUser, text = 'content to moderate') => {
    const created = await ctx.http
      .post('/api/v1/posts')
      .set(auth(author))
      .set('Idempotency-Key', randomUUID())
      .send({ text });
    expect(created.status, JSON.stringify(created.body)).toBe(201);
    return created.body.id as string;
  };
  const reportPost = async (reporter: TestUser, postId: string) => {
    advance(1000);
    const res = await ctx.http
      .post('/api/v1/reports')
      .set(auth(reporter))
      .send({ targetType: 'POST', targetId: postId, reason: 'SPAM', note: 'secret reporter note' });
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    return res.body.id as string;
  };
  const staffAlerts = (recipientId: string) =>
    ctx.prisma.notification.findMany({ where: { recipientId, type: 'STAFF_REPORT_NEW' } });
  const closeAllReports = () =>
    withMigrationClient((db) =>
      db.$executeRawUnsafe(
        `UPDATE reports SET status = 'DISMISSED', resolved_at = now() WHERE status = 'OPEN'`,
      ),
    );

  let owner: Staff;
  let mod: Staff;
  let support: Staff;
  let finance: Staff;
  let bd: Staff;

  beforeAll(async () => {
    vi.useFakeTimers({ toFake: ['Date'], now: clock });
    ctx = await createTestApp(
      {
        TRUST_PROXY: 'loopback',
        ADMIN_TOTP_KEY: 'admin-totp-test-key-0123456789-abcdefghijklmnop',
        JWT_ACCESS_TTL_SECONDS: String(60 * 86_400),
        ADMIN_SESSION_IDLE_SECONDS: '86400',
        ADMIN_SESSION_MAX_SECONDS: '604800',
        RATE_LIMIT_ADMIN_LOGIN_IP: '10000/900',
        RATE_LIMIT_ADMIN_IP: '100000/900',
      },
      [{ token: PUSH_SENDER, value: push }],
    );
    owner = await makeStaff(['OWNER']);
    mod = await makeStaff(['MODERATION']);
    support = await makeStaff(['SUPPORT']);
    finance = await makeStaff(['FINANCE']);
    bd = await makeStaff(['BD']);
  });
  afterAll(async () => {
    await ctx?.close();
    vi.useRealTimers();
  });

  describe('Task A: no code for the permanent ban and the permanent content deletion', () => {
    it('the ban works without a code, needs the capability and a reason, and is audited', async () => {
      const target = await signup();
      // A plain SUPPORT / FINANCE account still may not ban (capability on every request).
      expect((await apost(support, `/users/${target.id}/ban`, { reason: 'x' })).status).toBe(403);
      expect((await apost(finance, `/users/${target.id}/ban`, { reason: 'x' })).status).toBe(403);
      // The reason is still required.
      expect((await apost(mod, `/users/${target.id}/ban`, {})).status).toBe(400);
      const ban = await apost(mod, `/users/${target.id}/ban`, { reason: 'spam account' });
      expect(ban.status, JSON.stringify(ban.body)).toBe(200);
      expectContract(ban, 'banAdminUser');
      expect(ban.body.status).toBe('SUSPENDED');
      const [row] = await audits('admin.user.ban', target.id);
      expect(row).toMatchObject({ actorUserId: mod.id, targetType: 'user' });
      expect(row!.ip).toBeTruthy();
      expect(row!.metadata).toEqual({
        reason: 'spam account',
        before: 'ACTIVE',
        after: 'SUSPENDED',
        via: 'panel',
      });
      // An older panel's code is accepted and ignored — even a wrong one, and it never counts towards the lockout.
      const other = await signup();
      const old = await apost(mod, `/users/${other.id}/ban`, { reason: 'old panel', totpCode: '000000' });
      expect(old.status, JSON.stringify(old.body)).toBe(200);
      expect((await aget(mod, '/auth/session')).status).toBe(200);
    });

    it('deleting a post or story for good works without a code and is audited; hiding is unchanged', async () => {
      const author = await signup();
      const reader = await signup();
      const postId = await newPost(author);
      await reportPost(reader, postId);
      expect((await apost(support, `/content/post/${postId}/delete`, { reason: 'x' })).status).toBe(403);
      expect((await apost(mod, `/content/post/${postId}/delete`, {})).status).toBe(400);
      const del = await apost(mod, `/content/post/${postId}/delete`, { reason: 'Repeated spam' });
      expect(del.status, JSON.stringify(del.body)).toBe(200);
      expectContract(del, 'moderateAdminContent');
      expect(del.body).toEqual({ state: 'DELETED', reportsClosed: 1 });
      const [row] = await audits('admin.content.delete', postId);
      expect(row).toMatchObject({ actorUserId: mod.id, targetType: 'post' });
      expect(row!.metadata).toMatchObject({
        reason: 'Repeated spam',
        authorId: author.id,
        after: 'DELETED',
        via: 'panel',
      });
      expect((await ctx.prisma.post.findUniqueOrThrow({ where: { id: postId } })).deletedAt).not.toBeNull();
      // An older panel's code is ignored.
      const second = await newPost(author, 'second');
      const old = await apost(mod, `/content/post/${second}/delete`, {
        reason: 'old panel',
        totpCode: '123456',
      });
      expect(old.status, JSON.stringify(old.body)).toBe(200);
    });

    it('account deletion works without a code (owner «نعم»), needs OWNER and a reason, and is audited', async () => {
      const p = await signup();
      expect((await apost(mod, `/users/${p.id}/deletion`, { reason: 'asked' })).status).toBe(403);
      expect((await apost(support, `/users/${p.id}/deletion`, { reason: 'asked' })).status).toBe(403);
      expect((await apost(owner, `/users/${p.id}/deletion`, {})).status).toBe(400);
      const del = await apost(owner, `/users/${p.id}/deletion`, { reason: 'Written request verified' });
      expect(del.status, JSON.stringify(del.body)).toBe(200);
      expectContract(del, 'requestAdminUserDeletion');
      const [row] = await audits('account.deletion.requested', p.id);
      expect(row).toMatchObject({ actorUserId: owner.id });
      expect(row!.ip).toBeTruthy();
      expect(row!.metadata).toMatchObject({ via: 'panel' });
      expect(JSON.stringify(row!.metadata)).toContain('Written request verified');
      // An older panel's code (even a wrong one) is ignored and never counts towards the lockout.
      const q0 = await signup();
      const old = await apost(owner, `/users/${q0.id}/deletion`, { reason: 'old panel', totpCode: '000000' });
      expect(old.status, JSON.stringify(old.body)).toBe(200);
      expect((await aget(owner, '/auth/session')).status).toBe(200);
    });

    // The device ban's code (app and panel) is asserted by d286-staff-no-code-auto-shift.
    it('the actions D286 kept still ask for the code: sign-in, temporary password, e-mail, adjustment, roles', async () => {
      // The panel sign-in: the password alone only reaches the authenticator step.
      const login = await ctx.http
        .post('/api/v1/admin/auth/login')
        .send({ email: support.email, password: support.password });
      expect(login.status, JSON.stringify(login.body)).toBe(200);
      expect(login.body.next).toBe('TOTP_VERIFY');
      const q = await signup();
      const wrongTemp = await apost(support, `/users/${q.id}/password/temporary`, {
        reason: 'x',
        totpCode: '000000',
      });
      expect(wrongTemp.status).toBe(403);
      expect(wrongTemp.body.error.code).toBe('ADMIN_TOTP_INVALID');
      expect((await apost(support, `/users/${q.id}/password/temporary`, { reason: 'x' })).status).toBe(400);
      expect(
        (
          await apost(support, `/users/${q.id}/email`, {
            email: `n${randomUUID().slice(0, 8)}@example.com`,
            markVerified: false,
            reason: 'x',
          })
        ).status,
      ).toBe(400);
      expect(
        (
          await apost(finance, `/users/${q.id}/balance-adjustments`, {
            currency: 'COINS',
            direction: 'CREDIT',
            amount: '10',
            allowNegative: false,
            reason: 'x',
          })
        ).status,
      ).toBe(400);
      expect(
        (await apost(owner, '/team/grant', { account: q.email, role: 'SUPPORT', reason: 'x' })).status,
      ).toBe(400);
    });
  });

  describe('Task B: the shared report queue', () => {
    it('every report is visible to OWNER, MODERATION and SUPPORT (panel and app), not FINANCE or BD', async () => {
      await closeAllReports();
      const author = await signup();
      const reporter = await signup();
      const reportId = await reportPost(reporter, await newPost(author));
      for (const s of [owner, mod, support]) {
        const list = await aget(s, '/moderation/reports');
        expect(list.status, JSON.stringify(list.body)).toBe(200);
        expectContract(list, 'listAdminPanelReports');
        const row = (list.body.data as { id: string; resolvedBy: unknown; resolutionNote: unknown }[]).find(
          (r) => r.id === reportId,
        );
        expect(row).toMatchObject({ resolvedBy: null, resolutionNote: null });
        const app = await sget(s, '/staff/reports');
        expect(app.status, JSON.stringify(app.body)).toBe(200);
        expectContract(app, 'listStaffReports');
        expect((app.body.data as { id: string }[]).map((r) => r.id)).toContain(reportId);
      }
      for (const s of [finance, bd]) {
        expect((await aget(s, '/moderation/reports')).status).toBe(403);
        expect((await sget(s, '/staff/reports')).status).toBe(403);
        expect((await sget(s, '/staff/reports/summary')).status).toBe(403);
      }
      // A plain account: 403.
      expect((await sget(reporter, '/staff/reports')).status).toBe(403);
      // SUPPORT reads and resolves but takes no action on the target.
      expect(
        (await apost(support, `/moderation/reports/${reportId}/actions`, { action: 'DISMISS' })).status,
      ).toBe(403);
      const me = await sget(support, '/staff/me');
      expect(me.body.capabilities).toEqual(expect.arrayContaining(['reports.view', 'reports.resolve']));
    });

    it('a new report notifies every MODERATION and SUPPORT account (one unread row each), pushed on the staff channel', async () => {
      await closeAllReports();
      const dispatcher = ctx.app.get(NotificationPushDispatcher);
      await dispatcher.dispatchOnce();
      const phone = `fcm_${randomUUID().replaceAll('-', '')}:APA91b${randomUUID().replaceAll('-', '')}`;
      expect(
        (
          await ctx.http
            .put('/api/v1/me/push-token')
            .set(auth(support))
            .send({ token: phone, platform: 'ANDROID', appVersion: '0.1.0' })
        ).status,
      ).toBe(204);
      await ctx.prisma.notification.deleteMany({ where: { type: 'STAFF_REPORT_NEW' } });
      const author = await signup();
      const reporter = await signup();
      const first = await reportPost(reporter, await newPost(author));
      for (const s of [mod, support]) {
        const rows = await staffAlerts(s.id);
        expect(rows.map((r) => r.reportId)).toEqual([first]);
      }
      for (const s of [owner, finance, bd, reporter, author]) expect(await staffAlerts(s.id)).toEqual([]);
      const alert = (await audits('moderation.report.alert', first)).at(-1)!;
      expect(alert.actorUserId).toBeNull();
      expect(alert.metadata).toMatchObject({ route: 'staff' });
      expect((alert.metadata as { recipients: string[] }).recipients).toEqual(
        expect.arrayContaining([mod.id, support.id]),
      );

      push.sent.length = 0;
      expect(await dispatcher.dispatchOnce()).toBeGreaterThanOrEqual(1);
      const sent = push.sent.find((p) => p.tokens.includes(phone))!;
      expect(sent.channel).toBe('staff');
      expect(sent.data).toMatchObject({
        kind: 'notification',
        channel: 'staff',
        type: 'STAFF_REPORT_NEW',
        targetType: 'REPORT',
        targetId: first,
      });
      expect(sent.title).toBe('Kabso Team reports');
      expect(sent.body).toBe('A new report is waiting to be resolved');
      expect(JSON.stringify(sent)).not.toContain('secret reporter note');
      expect(JSON.stringify(sent)).not.toContain(reporter.username);
      // One push audit row per recipient, written in no fixed order: pick the SUPPORT account's (it has a token).
      const pushAudit = (await audits('moderation.report.push', first)).find(
        (a) => (a.metadata as { recipientId?: string }).recipientId === support.id,
      );
      expect(pushAudit?.metadata).toMatchObject({ recipientId: support.id, sent: 1 });

      const inbox = await sget(support, '/notifications');
      expectContract(inbox, 'listNotifications');
      const item = (inbox.body.data as { type: string; target: Record<string, unknown> | null }[]).find(
        (n) => n.type === 'STAFF_REPORT_NEW',
      )!;
      expect(item.target).toMatchObject({
        type: 'REPORT',
        id: first,
        reportTargetType: 'POST',
        reportOpen: true,
      });

      // A second report: still one unread row per staff member, now pointing at the newest one, pushed again.
      advance(120_000);
      const second = await reportPost(await signup(), await newPost(author, 'another'));
      const rows = await staffAlerts(support.id);
      expect(rows).toHaveLength(1);
      expect(rows[0]!.reportId).toBe(second);
      push.sent.length = 0;
      await dispatcher.dispatchOnce();
      expect(push.sent.some((p) => p.tokens.includes(phone) && p.data.targetId === second)).toBe(true);
    });

    it('nobody holds MODERATION or SUPPORT → the OWNERs are told', async () => {
      await closeAllReports();
      await withMigrationClient((db) =>
        db.$executeRawUnsafe(
          `UPDATE user_admin_permissions SET permission = 'FINANCE' WHERE permission IN ('MODERATION', 'SUPPORT') AND user_id IN ('${mod.id}', '${support.id}')`,
        ),
      );
      const others = await ctx.prisma.user.count({
        where: {
          role: 'ADMIN',
          status: 'ACTIVE',
          adminPermissions: { some: { permission: { in: ['MODERATION', 'SUPPORT'] } } },
        },
      });
      try {
        // Only this suite's staff exist (the tables are truncated per file): nobody holds MODERATION or SUPPORT now.
        expect(others).toBe(0);
        await ctx.prisma.notification.deleteMany({ where: { type: 'STAFF_REPORT_NEW' } });
        const id = await reportPost(await signup(), await newPost(await signup()));
        expect((await staffAlerts(owner.id)).map((r) => r.reportId)).toEqual([id]);
        expect((await audits('moderation.report.alert', id)).at(-1)!.metadata).toMatchObject({
          route: 'owners',
        });
      } finally {
        await withMigrationClient(async (db) => {
          await db.$executeRawUnsafe(
            `UPDATE user_admin_permissions SET permission = 'MODERATION' WHERE user_id = '${mod.id}'`,
          );
          await db.$executeRawUnsafe(
            `UPDATE user_admin_permissions SET permission = 'SUPPORT' WHERE user_id = '${support.id}'`,
          );
        });
      }
    });

    it('the counters count every open report; the app badge is not staff work', async () => {
      await closeAllReports();
      await withMigrationClient((db) => db.$executeRawUnsafe(`UPDATE admin_shifts SET on_shift = false`));
      const author = await signup();
      await reportPost(await signup(), await newPost(author));
      await reportPost(await signup(), await newPost(author));
      const panel = await aget(support, '/moderation/reports/summary');
      expect(panel.status, JSON.stringify(panel.body)).toBe(200);
      expectContract(panel, 'getAdminPanelReportsSummary');
      expect(panel.body).toEqual({ open: 2 });
      const app = await sget(mod, '/staff/reports/summary');
      expectContract(app, 'getStaffReportsSummary');
      expect(app.body).toEqual({ open: 2 });
      // Reading the badge never switches the shift on (D286: not staff work).
      expect((await ctx.prisma.adminShift.findUnique({ where: { userId: mod.id } }))?.onShift ?? false).toBe(
        false,
      );
    });

    it('«تم حله»: resolved for everyone with who / when / note, audited; a second press → 409', async () => {
      await closeAllReports();
      const author = await signup();
      const id = await reportPost(await signup(), await newPost(author));
      expect((await spost(finance, `/staff/reports/${id}/resolve`, {})).status).toBe(403);
      expect((await spost(support, `/staff/reports/${id}/resolve`, { note: '' })).status).toBe(400);
      const done = await spost(support, `/staff/reports/${id}/resolve`, {
        note: 'Checked, handled with the author',
      });
      expect(done.status, JSON.stringify(done.body)).toBe(200);
      expectContract(done, 'resolveStaffReport');
      expect(done.body).toMatchObject({
        id,
        status: 'ACTIONED',
        resolvedBy: { id: support.id, username: support.username },
        resolutionNote: 'Checked, handled with the author',
      });
      expect(done.body.resolvedAt).toBeTruthy();
      const [row] = await audits('moderation.report.resolve');
      expect(row).toMatchObject({ actorUserId: support.id, targetType: 'post' });
      expect(row!.ip).toBeTruthy();
      expect(row!.metadata).toEqual({ reportId: id, note: 'Checked, handled with the author', via: 'app' });
      // Everyone sees it resolved: gone from OPEN, first in RESOLVED, the counter down, the alerts read.
      const open = await aget(mod, '/moderation/reports');
      expect((open.body.data as { id: string }[]).map((r) => r.id)).not.toContain(id);
      const resolved = await aget(mod, '/moderation/reports?status=RESOLVED');
      expectContract(resolved, 'listAdminPanelReports');
      expect((resolved.body.data as { id: string }[])[0]).toMatchObject({
        id,
        resolvedBy: { id: support.id },
      });
      expect((await aget(mod, '/moderation/reports/summary')).body).toEqual({ open: 0 });
      const alerts = await ctx.prisma.notification.findMany({
        where: { type: 'STAFF_REPORT_NEW', reportId: id },
      });
      expect(alerts.length).toBeGreaterThan(0);
      expect(alerts.every((n) => n.readAt !== null)).toBe(true);
      // The second press: 409, nothing changes.
      const again = await apost(mod, `/moderation/reports/${id}/resolve`, { note: 'me too' });
      expect(again.status).toBe(409);
      expect(again.body.error.code).toBe('REPORT_ALREADY_RESOLVED');
      expectContract(again, 'resolveAdminPanelReport');
      expect((await ctx.prisma.report.findUniqueOrThrow({ where: { id } })).resolvedById).toBe(support.id);
      expect(await audits('moderation.report.resolve')).toHaveLength(1);
      // An unknown report: 404.
      expect((await apost(mod, `/moderation/reports/${randomUUID()}/resolve`, {})).status).toBe(404);
    });

    it('two presses at once: the first wins, the other gets 409', async () => {
      const id = await reportPost(await signup(), await newPost(await signup()));
      const before = (await audits('moderation.report.resolve')).length;
      const [a, b] = await Promise.all([
        apost(mod, `/moderation/reports/${id}/resolve`, { note: 'from the panel' }),
        spost(support, `/staff/reports/${id}/resolve`, { note: 'from the app' }),
      ]);
      expect([a.status, b.status].sort()).toEqual([200, 409]);
      const loser = a.status === 409 ? a : b;
      expect(loser.body.error.code).toBe('REPORT_ALREADY_RESOLVED');
      const winner = a.status === 200 ? mod : support;
      expect((await ctx.prisma.report.findUniqueOrThrow({ where: { id } })).resolvedById).toBe(winner.id);
      expect(await audits('moderation.report.resolve')).toHaveLength(before + 1);
    });

    it('reopen: OWNER and MODERATION (not SUPPORT), with a reason, audited; an open report → 409', async () => {
      const id = await reportPost(await signup(), await newPost(await signup()));
      expect((await apost(owner, `/moderation/reports/${id}/reopen`, { reason: 'x' })).body.error.code).toBe(
        'ADMIN_ACTION_REFUSED',
      );
      expect((await apost(mod, `/moderation/reports/${id}/resolve`, { note: 'done' })).status).toBe(200);
      // SUPPORT resolves but never reopens.
      expect((await apost(support, `/moderation/reports/${id}/reopen`, { reason: 'x' })).status).toBe(403);
      expect((await apost(owner, `/moderation/reports/${id}/reopen`, {})).status).toBe(400);
      const re = await apost(owner, `/moderation/reports/${id}/reopen`, { reason: 'Not really handled' });
      expect(re.status, JSON.stringify(re.body)).toBe(200);
      expectContract(re, 'reopenAdminPanelReport');
      expect(re.body).toMatchObject({
        id,
        status: 'OPEN',
        resolvedAt: null,
        resolvedBy: null,
        resolutionNote: null,
      });
      const row = (await audits('moderation.report.reopen')).at(-1)!;
      expect(row).toMatchObject({ actorUserId: owner.id });
      expect(row.metadata).toMatchObject({
        reportId: id,
        reason: 'Not really handled',
        before: 'ACTIONED',
        resolvedById: mod.id,
      });
      // It can be resolved again — and a moderator reopens it too (owner: option B), audited with the moderator.
      expect((await spost(support, `/staff/reports/${id}/resolve`, {})).status).toBe(200);
      expect((await apost(mod, `/moderation/reports/${id}/reopen`, {})).status).toBe(400);
      const byMod = await apost(mod, `/moderation/reports/${id}/reopen`, { reason: 'Needs another look' });
      expect(byMod.status, JSON.stringify(byMod.body)).toBe(200);
      expectContract(byMod, 'reopenAdminPanelReport');
      expect(byMod.body).toMatchObject({ id, status: 'OPEN', resolvedBy: null });
      const modRow = (await audits('moderation.report.reopen')).at(-1)!;
      expect(modRow).toMatchObject({ actorUserId: mod.id });
      expect(modRow.metadata).toMatchObject({
        reportId: id,
        reason: 'Needs another look',
        before: 'ACTIONED',
        resolvedById: support.id,
        via: 'panel',
      });
    });
  });
});
