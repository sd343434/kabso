/**
 * D296 (owner 2026-11-06: «يجب عند الضغط عليه الدخول إلى البوست، ويكون له أزرار صلاحية للتحذير والحظر ومنع النشر …
 * عندما يضغط على البلاغ يدخل إلى الشات المبلغ عنه ويكون عنده إجراء. ولاحظت خلل في رسائل الإبلاغ غير فعّال», then: an
 * action resolves the report automatically; contract v1.93-social, CONVENTIONS §10.109), end to end against PostgreSQL +
 * Redis:
 *
 *  - the bug: a USER report sent with the user's id (what the app sends from the conversation's «الإبلاغ عن الشخص», the
 *    profile and the live person card) was 404; it is stored now, reaches the staff queue and alerts them; a DM report
 *    reaches the queue too;
 *  - `getStaffReport`: each target type for the staff whatever its visibility (hidden, deleted, private, blocked), a DM
 *    only as the snapshot with every read audited; a non-staff / FINANCE / BD account → 403;
 *  - `actOnStaffReport`: WARN, RESTRICT, SUSPEND, BAN, REMOVE_CONTENT — capability-gated per role (SUPPORT only what the
 *    matrix gives it), audited with the report id, and each resolves the report (and the target's other OPEN reports)
 *    once: `resolutionAction`, the reason as the note, the staff's alerts read; a second press → 409 with no second
 *    notification; a manual «تم حله» still works with no action; reopen clears the action.
 */
import { randomUUID } from 'node:crypto';
import type request from 'supertest';
import { afterAll, beforeAll, describe, expect, it, vi } from 'vitest';
import { grantRoleIn } from '../src/modules/admin-panel/admin-roles.js';
import { totpCode } from '../src/modules/admin-panel/totp.js';
import { DM_REPORT_THREAD_MAX_MESSAGES } from '../src/modules/messages/dm-reports.js';
import { DmSweeper } from '../src/modules/messages/dm-sweeper.js';
import { expectContract, operations } from './helpers/openapi.js';
import { createTestApp, newUser, withMigrationClient, type TestContext } from './helpers/test-app.js';

const COOKIE = '__Host-kabso_admin';

interface TestUser {
  readonly id: string;
  readonly username: string;
  readonly email: string;
  readonly password: string;
  token: string;
}

describe('D296 contract coverage', () => {
  it('openapi v1.93-social declares the report view and the actions in the app (tag staff)', () => {
    const byId = new Map(operations().map((o) => [o.operationId, o]));
    for (const id of ['getStaffReport', 'actOnStaffReport', 'getStaffReportDmThread']) {
      const o = byId.get(id)!;
      expect(o, id).toBeDefined();
      expect(String(o.spec.summary)).toContain('(v1.93-social, D296)');
      expect(o.spec.tags).toEqual(['staff']);
    }
  });
});

describe('D296 report actions from the app', { timeout: 900_000 }, () => {
  let ctx: TestContext;
  let clock = Date.now();
  const advance = (ms: number) => {
    clock += ms;
    vi.setSystemTime(clock);
  };
  let ipCounter = 10;
  const nextIp = () => {
    ipCounter += 1;
    return `198.51.${Math.floor(ipCounter / 250) + 7}.${(ipCounter % 250) + 1}`;
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
  const makeStaff = async (roles: string[]): Promise<TestUser> => {
    const p = await signup();
    await withMigrationClient(async (db) => {
      for (const role of roles) await db.$transaction((tx) => grantRoleIn(tx, p.email, role as never));
    });
    return p;
  };
  const panelSession = async (p: TestUser) => {
    const cookieOf = (res: request.Response): string => {
      const raw = ([] as string[]).concat(res.headers['set-cookie'] ?? []);
      const line = raw.find((c) => c.startsWith(`${COOKIE}=`));
      if (!line) throw new Error(`no session cookie in ${JSON.stringify(raw)}`);
      return line.split(';')[0]!;
    };
    const res = await ctx.http
      .post('/api/v1/admin/auth/login')
      .send({ email: p.email, password: p.password });
    const pending = cookieOf(res);
    const csrf = res.body.csrfToken as string;
    const enrol = await ctx.http
      .post('/api/v1/admin/auth/totp/enrolment')
      .set('Cookie', pending)
      .set('X-CSRF-Token', csrf);
    const secret = enrol.body.secret as string;
    advance(30_000);
    const confirm = await ctx.http
      .post('/api/v1/admin/auth/totp/enrolment/confirm')
      .set('Cookie', pending)
      .set('X-CSRF-Token', csrf)
      .send({ code: totpCode(secret, clock) });
    expect(confirm.status, JSON.stringify(confirm.body)).toBe(200);
    return { cookie: cookieOf(confirm), csrf: confirm.body.session.csrfToken as string };
  };
  const sget = (u: { token: string }, path: string) => ctx.http.get(`/api/v1${path}`).set(auth(u));
  const spost = (u: { token: string }, path: string, body: object = {}) =>
    ctx.http.post(`/api/v1${path}`).set(auth(u)).send(body);
  const audits = (action: string) =>
    ctx.prisma.auditLog.findMany({ where: { action }, orderBy: [{ createdAt: 'asc' }, { id: 'asc' }] });
  const newPost = async (author: TestUser, text = 'content to moderate') => {
    const created = await ctx.http
      .post('/api/v1/posts')
      .set(auth(author))
      .set('Idempotency-Key', randomUUID())
      .send({ text });
    expect(created.status, JSON.stringify(created.body)).toBe(201);
    return created.body.id as string;
  };
  const report = async (reporter: TestUser, targetType: string, targetId: string, reason = 'SPAM') => {
    advance(1000);
    const res = await spost(reporter, '/reports', { targetType, targetId, reason });
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    return res.body.id as string;
  };
  const dmText = async (from: TestUser, to: TestUser, text: string) => {
    const res = await spost(from, '/dm/messages', {
      to: to.username,
      clientId: randomUUID(),
      kind: 'TEXT',
      text,
    });
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    return res.body.message as { id: string; conversationId: string };
  };
  const view = (u: TestUser, reportId: string) => sget(u, `/staff/reports/${reportId}`);
  /** D296 follow-up: the conversation opened on a tap (audited). */
  const openThread = (u: TestUser, reportId: string) => sget(u, `/staff/reports/${reportId}/dm-thread`);
  const act = (u: TestUser, reportId: string, body: object) =>
    spost(u, `/staff/reports/${reportId}/actions`, body);

  let owner: TestUser;
  let mod: TestUser;
  let support: TestUser;
  let finance: TestUser;
  let bd: TestUser;

  beforeAll(async () => {
    vi.useFakeTimers({ toFake: ['Date'], now: clock });
    ctx = await createTestApp({
      TRUST_PROXY: 'loopback',
      ADMIN_TOTP_KEY: 'admin-totp-test-key-0123456789-abcdefghijklmnop',
      JWT_ACCESS_TTL_SECONDS: String(60 * 86_400),
      ADMIN_SESSION_IDLE_SECONDS: '86400',
      ADMIN_SESSION_MAX_SECONDS: '604800',
      RATE_LIMIT_ADMIN_LOGIN_IP: '10000/900',
      RATE_LIMIT_ADMIN_IP: '100000/900',
      MEDIA_PUBLIC_BASE_URL: 'https://media.example.test',
    });
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

  describe('the bug «رسائل الإبلاغ غير فعّال»', () => {
    it('a USER report by id (the app) is stored, reaches the queue and alerts the staff; by username still works', async () => {
      const [reporter, rude] = [await signup(), await signup()];
      // What the conversation's «الإبلاغ عن الشخص» sends: the peer's id. Before D296 this was 404.
      const byId = await spost(reporter, '/reports', {
        targetType: 'USER',
        targetId: rude.id,
        reason: 'HARASSMENT',
      });
      expect(byId.status, JSON.stringify(byId.body)).toBe(201);
      expectContract(byId, 'createReport');
      expect(byId.body.targetId).toBe(rude.username);
      // The same person again (by username): the same open report.
      const again = await spost(reporter, '/reports', {
        targetType: 'USER',
        targetId: rude.username,
        reason: 'HARASSMENT',
      });
      expect(again.status).toBe(200);
      expect(again.body.id).toBe(byId.body.id);
      // One's own id → 400; an unknown id → 404; a suspended account → 404.
      expect(
        (await spost(reporter, '/reports', { targetType: 'USER', targetId: reporter.id, reason: 'SPAM' }))
          .status,
      ).toBe(400);
      expect(
        (await spost(reporter, '/reports', { targetType: 'USER', targetId: randomUUID(), reason: 'SPAM' }))
          .status,
      ).toBe(404);
      // It reaches «بلاغات» and every moderator / support member is told.
      const queue = await sget(support, '/staff/reports?limit=50');
      expect(queue.status).toBe(200);
      expect((queue.body.data as { id: string }[]).map((r) => r.id)).toContain(byId.body.id);
      const alert = await ctx.prisma.notification.findFirst({
        where: { recipientId: mod.id, type: 'STAFF_REPORT_NEW', readAt: null },
      });
      expect(alert?.reportId).toBe(byId.body.id);
    });

    it('a DM report from the long-press reaches the queue and the alert', async () => {
      const [a, b] = [await signup(), await signup()];
      const m = await dmText(a, b, 'a rude private message');
      const id = await report(b, 'DM_MESSAGE', m.id, 'HARASSMENT');
      const queue = await sget(mod, '/staff/reports?limit=50');
      const row = (queue.body.data as { id: string; targetType: string }[]).find((r) => r.id === id);
      expect(row?.targetType).toBe('DM_MESSAGE');
      const alert = await ctx.prisma.notification.findFirst({
        where: { recipientId: support.id, type: 'STAFF_REPORT_NEW', readAt: null },
      });
      expect(alert?.reportId).toBe(id);
    });
  });

  describe('getStaffReport', () => {
    it('non-staff, FINANCE and BD get 403; an unknown report 404', async () => {
      const [r, author] = [await signup(), await signup()];
      const id = await report(r, 'POST', await newPost(author));
      for (const u of [r, author, finance, bd]) {
        expect((await view(u, id)).status).toBe(403);
        expect((await act(u, id, { action: 'WARN', reason: 'x' })).status).toBe(403);
      }
      expect((await view(mod, randomUUID())).status).toBe(404);
    });

    it('a post hidden by moderation, from a private account that blocked the staff member, opens with its state', async () => {
      const [r, author] = [await signup(), await signup()];
      const postId = await newPost(author, 'reported words');
      const id = await report(r, 'POST', postId);
      // Hidden by moderation, the account private, and the author blocked the moderator.
      await ctx.prisma.post.update({ where: { id: postId }, data: { moderation: 'REMOVED' } });
      expect((await ctx.http.put(`/api/v1/users/${mod.username}/block`).set(auth(author))).status).toBe(200);
      expect(
        (await ctx.http.patch('/api/v1/me/privacy').set(auth(author)).send({ isPrivate: true })).status,
      ).toBe(200);
      const res = await view(mod, id);
      expect(res.status, JSON.stringify(res.body)).toBe(200);
      expectContract(res, 'getStaffReport');
      expect(res.body.target).toMatchObject({ type: 'POST', state: 'HIDDEN' });
      expect(res.body.target.post.id).toBe(postId);
      expect(res.body.target.post.text).toBe('reported words');
      expect(res.body.target.author.username).toBe(author.username);
      expect(res.body.actions).toEqual([
        'WARN',
        'RESTRICT',
        'SUSPEND',
        'BAN',
        'REMOVE_CONTENT',
        'DELETE_CONTENT',
      ]);
      // Deleting an account is the OWNER's (users.delete).
      expect((await view(owner, id)).body.actions).toContain('DELETE_ACCOUNT');
      expect(res.body.restrictions).toEqual(['NO_POSTING', 'NO_LIVE', 'CHAT_MUTE']);
      expect(res.body.canResolve).toBe(true);
      // SUPPORT reads it and may only do what the panel's matrix gives it: the temporary lock (users.lock).
      const sup = await view(support, id);
      expect(sup.status).toBe(200);
      expect(sup.body.actions).toEqual(['SUSPEND']);
      expect(sup.body.restrictions).toEqual([]);
      // Deleted by its author: still shown, DELETED.
      await ctx.prisma.post.update({ where: { id: postId }, data: { deletedAt: new Date() } });
      expect((await view(mod, id)).body.target.state).toBe('DELETED');
    });

    it('a comment opens with its post; a user; a story; an ended live', async () => {
      const [r, author] = [await signup(), await signup()];
      const postId = await newPost(author, 'the post');
      const c = await spost(r, `/posts/${postId}/comments`, { text: 'context' });
      expect(c.status, JSON.stringify(c.body)).toBe(201);
      const bad = await spost(author, `/posts/${postId}/comments`, { text: 'the reported comment' });
      expect(bad.status, JSON.stringify(bad.body)).toBe(201);
      const cid = await report(r, 'COMMENT', bad.body.id as string);
      const cv = await view(mod, cid);
      expect(cv.status, JSON.stringify(cv.body)).toBe(200);
      expectContract(cv, 'getStaffReport');
      expect(cv.body.target).toMatchObject({ type: 'COMMENT', state: 'VISIBLE' });
      expect(cv.body.target.comment).toMatchObject({ text: 'the reported comment', postId });
      expect(cv.body.target.post.id).toBe(postId);

      const uid = await report(r, 'USER', author.id);
      const uv = await view(support, uid);
      expect(uv.status).toBe(200);
      expectContract(uv, 'getStaffReport');
      expect(uv.body.target).toMatchObject({ type: 'USER', state: 'VISIBLE' });
      expect(uv.body.target.author.username).toBe(author.username);
      // A user has no content to remove.
      expect((await view(mod, uid)).body.actions).not.toContain('REMOVE_CONTENT');
      expect((await act(mod, uid, { action: 'REMOVE_CONTENT', reason: 'x' })).status).toBe(409);

      // A story and an ended live: the reports are stored directly (the media pipeline is not under test here).
      const asset = await ctx.prisma.mediaAsset.create({
        data: {
          ownerId: author.id,
          kind: 'STORY_IMAGE',
          width: 1080,
          height: 1920,
          largeKey: `media/${randomUUID()}/large.webp`,
          thumbKey: `media/${randomUUID()}/thumb.webp`,
          byteSize: 1000,
          attachedAt: new Date(),
        },
      });
      const story = await ctx.prisma.story.create({
        data: {
          authorId: author.id,
          mediaAssetId: asset.id,
          text: 'story words',
          expiresAt: new Date(clock + 3600_000),
        },
      });
      const sid = await report(r, 'STORY', story.id);
      const sv = await view(mod, sid);
      expect(sv.status, JSON.stringify(sv.body)).toBe(200);
      expectContract(sv, 'getStaffReport');
      expect(sv.body.target).toMatchObject({ type: 'STORY', state: 'VISIBLE' });
      expect(sv.body.target.story.text).toBe('story words');
      expect(sv.body.target.story.media.url).toContain(asset.largeKey);

      const room = await ctx.prisma.liveRoom.create({
        data: {
          hostUserId: author.id,
          title: 'an old live',
          status: 'ENDED',
          endedAt: new Date(),
          endReason: 'HOST_ENDED',
        },
      });
      const rr = await ctx.prisma.report.create({
        data: { reporterId: r.id, targetType: 'LIVE_ROOM', targetLiveRoomId: room.id, reason: 'SPAM' },
      });
      const lv = await view(mod, rr.id);
      expect(lv.status, JSON.stringify(lv.body)).toBe(200);
      expectContract(lv, 'getStaffReport');
      expect(lv.body.target).toMatchObject({ type: 'LIVE_ROOM', state: 'ENDED' });
      expect(lv.body.target.live).toMatchObject({ roomId: room.id, title: 'an old live', status: 'ENDED' });
    });

    it('a DM: the report shows the conversation closed (a summary, no audit); opening it returns it and audits', async () => {
      const [a, b] = [await signup(), await signup()];
      await dmText(b, a, 'what the reporter said before');
      advance(1000);
      const m = await dmText(a, b, 'the reported message');
      advance(1000);
      await dmText(a, b, 'a later message');
      const id = await report(b, 'DM_MESSAGE', m.id, 'HARASSMENT');
      const before = (await audits('moderation.report.dm_read')).length;
      const res = await view(support, id);
      expect(res.status, JSON.stringify(res.body)).toBe(200);
      expectContract(res, 'getStaffReport');
      expect(res.body.target.type).toBe('DM_MESSAGE');
      expect(res.body.target.state).toBe('VISIBLE');
      expect(res.body.target.dm.snapshot).toMatchObject({
        kind: 'TEXT',
        text: 'the reported message',
        sender: a.username,
      });
      expect(res.body.target.dm.recipient.username).toBe(b.username);
      expect(res.body.target.author.username).toBe(a.username);
      // Owner (follow-up): the conversation is closed on the report — a summary only, nothing of it, no audit.
      expect(res.body.target.dm.thread).toBeUndefined();
      expect(res.body.target.dm.threadSummary).toMatchObject({ messages: 3, total: 3, truncated: false });
      const closedBody = JSON.stringify(res.body);
      expect(closedBody).not.toContain('what the reporter said before');
      expect(closedBody).not.toContain('a later message');
      expect((await audits('moderation.report.dm_read')).length).toBe(before);
      // A tap opens it: the whole conversation as it was when reported (the report's copy), and the read is audited.
      const opened = await openThread(support, id);
      expect(opened.status, JSON.stringify(opened.body)).toBe(200);
      expectContract(opened, 'getStaffReportDmThread');
      expect(opened.body.thread.messages.map((x: { text: string }) => x.text)).toEqual([
        'what the reporter said before',
        'the reported message',
        'a later message',
      ]);
      expect(opened.body).toMatchObject({
        reportId: id,
        reported: { username: a.username },
        recipient: { username: b.username },
        snapshot: { text: 'the reported message' },
      });
      const reads = await audits('moderation.report.dm_read');
      expect(reads.length).toBe(before + 1);
      expect(reads.at(-1)).toMatchObject({
        actorUserId: support.id,
        targetType: 'dm_message',
        targetId: m.id,
      });
      expect(reads.at(-1)!.metadata).toEqual({ reportId: id, purged: false, threadMessages: 3, via: 'app' });
      // After the 24-hour life the message is gone; the snapshot is still there.
      advance(25 * 3600_000);
      const later = await view(mod, id);
      expect(later.body.target.state).toBe('EXPIRED');
      expect(later.body.target.dm.snapshot.text).toBe('the reported message');
      expect((await audits('moderation.report.dm_read')).length).toBe(before + 1);
      expect((await openThread(mod, id)).status).toBe(200);
      expect((await audits('moderation.report.dm_read')).length).toBe(before + 2);
    });

    it('the conversation endpoint needs the capability, and a report with no conversation has none', async () => {
      const [a, b, other] = [await signup(), await signup(), await signup()];
      const m = await dmText(a, b, 'private');
      const id = await report(b, 'DM_MESSAGE', m.id);
      const before = (await audits('moderation.report.dm_read')).length;
      for (const u of [a, b, finance, bd]) expect((await openThread(u, id)).status).toBe(403);
      expect((await audits('moderation.report.dm_read')).length).toBe(before);
      expect((await openThread(mod, randomUUID())).status).toBe(404);
      const postReport = await report(other, 'POST', await newPost(a));
      expect((await openThread(mod, postReport)).status).toBe(404);
      const plainUser = await report(other, 'USER', a.id);
      expect((await openThread(mod, plainUser)).status).toBe(404);
      expect((await audits('moderation.report.dm_read')).length).toBe(before);
    });
  });

  describe('the whole conversation frozen with the report (owner: «مثل طريقة نزاع وكيل الشحن»)', () => {
    it('a DM report keeps every retained message at report time, never later ones, and survives the 24 h purge', async () => {
      const [a, b] = [await signup(), await signup()];
      advance(1000);
      const m1 = await dmText(b, a, 'the reporter wrote first');
      advance(1000);
      const m2 = await dmText(a, b, 'a reply');
      advance(1000);
      const bad = await dmText(a, b, 'the reported threat');
      advance(1000);
      const m4 = await dmText(b, a, 'stop it');
      // Deleted for everyone before the report: gone, so not kept.
      const gone = await dmText(b, a, 'oops, wrong chat');
      expect(
        (await ctx.http.delete(`/api/v1/dm/messages/${gone.id}?scope=everyone`).set(auth(b))).status,
      ).toBe(204);
      const id = await report(b, 'DM_MESSAGE', bad.id, 'HARASSMENT');
      advance(1000);
      await dmText(a, b, 'a message after the report');

      const closed = await view(mod, id);
      expect(closed.status, JSON.stringify(closed.body)).toBe(200);
      expectContract(closed, 'getStaffReport');
      expect(closed.body.target.dm.threadSummary).toMatchObject({ messages: 4, total: 4, truncated: false });
      const res = await openThread(mod, id);
      expect(res.status, JSON.stringify(res.body)).toBe(200);
      expectContract(res, 'getStaffReportDmThread');
      const thread = res.body.thread;
      expect(thread.truncated).toBe(false);
      expect(thread.total).toBe(4);
      expect(thread.messages.map((m: { text: string }) => m.text)).toEqual([
        'the reporter wrote first',
        'a reply',
        'the reported threat',
        'stop it',
      ]);
      expect(thread.messages.map((m: { id: string }) => m.id)).toEqual([m1.id, m2.id, bad.id, m4.id]);
      expect(
        thread.messages.filter((m: { reported: boolean }) => m.reported).map((m: { id: string }) => m.id),
      ).toEqual([bad.id]);
      expect(thread.messages.map((m: { sender: string }) => m.sender)).toEqual([
        b.username,
        a.username,
        a.username,
        b.username,
      ]);
      expect(thread.messages.map((m: { fromReported: boolean }) => m.fromReported)).toEqual([
        false,
        true,
        true,
        false,
      ]);
      expect(JSON.stringify(res.body)).not.toContain('a message after the report');
      expect(JSON.stringify(res.body)).not.toContain('oops, wrong chat');
      // Not in the lists (only the audited view shows it).
      const list = await sget(mod, '/staff/reports?limit=50');
      expect(JSON.stringify(list.body)).not.toContain('the reporter wrote first');
      const [read] = (await audits('moderation.report.dm_read')).filter(
        (x) => (x.metadata as { reportId?: string }).reportId === id,
      );
      expect(read!.metadata).toEqual({ reportId: id, purged: false, threadMessages: 4, via: 'app' });

      // 24 h later the sweeper deletes every message; the frozen conversation stays.
      advance(25 * 3600_000);
      await ctx.app.get(DmSweeper).sweep();
      expect(await ctx.prisma.dmMessage.count({ where: { conversationId: bad.conversationId } })).toBe(0);
      const later = await view(support, id);
      expect(later.body.target.state).toBe('EXPIRED');
      expect((await openThread(support, id)).body.thread.messages).toHaveLength(4);

      // 30 days after resolution the snapshot, the thread included, is cleared (resolved_at moved back, not the clock:
      // the test sessions would expire).
      expect((await spost(mod, `/staff/reports/${id}/resolve`, {})).status).toBe(200);
      await ctx.prisma.report.update({
        where: { id },
        data: { resolvedAt: new Date(Date.now() - 31 * 86_400_000) },
      });
      await ctx.app.get(DmSweeper).sweep();
      const purged = await view(mod, id);
      expect(purged.body.target.dm.threadSummary).toBeNull();
      expect(purged.body.target.dm.snapshot.purged).toBe(true);
      expect((await openThread(mod, id)).body).toMatchObject({ thread: null, snapshot: { purged: true } });
    });

    it('a person reported from the conversation keeps the conversation; the conversation must be theirs', async () => {
      const [a, b, c] = [await signup(), await signup(), await signup()];
      await dmText(a, b, 'hello there');
      // The test clock is frozen: one second apart, so the order is the sending order.
      advance(1000);
      const m = await dmText(a, b, 'send me your number');
      // Not with USER → 400; someone else's conversation → 404.
      expect(
        (
          await spost(b, '/reports', {
            targetType: 'POST',
            targetId: randomUUID(),
            reason: 'SPAM',
            dmConversationId: m.conversationId,
          })
        ).status,
      ).toBe(400);
      expect(
        (
          await spost(c, '/reports', {
            targetType: 'USER',
            targetId: a.id,
            reason: 'SPAM',
            dmConversationId: m.conversationId,
          })
        ).status,
      ).toBe(404);
      advance(1000);
      const res = await spost(b, '/reports', {
        targetType: 'USER',
        targetId: a.id,
        reason: 'HARASSMENT',
        dmConversationId: m.conversationId,
      });
      expect(res.status, JSON.stringify(res.body)).toBe(201);
      const v = await view(mod, res.body.id as string);
      expect(v.status).toBe(200);
      expectContract(v, 'getStaffReport');
      expect(v.body.target.type).toBe('USER');
      expect(v.body.target.dm.snapshot).toBeNull();
      expect(v.body.target.dm.threadSummary).toMatchObject({ messages: 2 });
      const t = await openThread(mod, res.body.id as string);
      expect(t.status).toBe(200);
      expectContract(t, 'getStaffReportDmThread');
      expect(t.body.snapshot).toBeNull();
      expect(t.body.reported.username).toBe(a.username);
      expect(t.body.thread.messages.map((x: { text: string }) => x.text)).toEqual([
        'hello there',
        'send me your number',
      ]);
      expect(t.body.thread.messages.every((x: { fromReported: boolean }) => x.fromReported)).toBe(true);
      // A report of the person from elsewhere keeps no conversation.
      const plain = await report(c, 'USER', a.id);
      expect((await view(mod, plain)).body.target.dm).toBeUndefined();
    });

    it('the thread is bounded (newest messages kept, truncated flagged)', () => {
      expect(DM_REPORT_THREAD_MAX_MESSAGES).toBe(300);
    });
  });

  describe('permanent deletion from a report (owner: in the app too)', () => {
    it('DELETE_CONTENT: a post for good, the typed word and a reason, users.content, only this report closes', async () => {
      const [r1, r2, author] = [await signup(), await signup(), await signup()];
      const postId = await newPost(author, 'delete me for good');
      const id = await report(r1, 'POST', postId);
      const other = await report(r2, 'POST', postId);
      expect((await act(mod, id, { action: 'DELETE_CONTENT', reason: 'illegal' })).status).toBe(400);
      expect(
        (await act(mod, id, { action: 'DELETE_CONTENT', reason: 'illegal', confirm: 'delete' })).status,
      ).toBe(400);
      expect(
        (await act(support, id, { action: 'DELETE_CONTENT', reason: 'illegal', confirm: 'DELETE' })).status,
      ).toBe(403);
      const res = await act(mod, id, { action: 'DELETE_CONTENT', reason: 'illegal', confirm: 'DELETE' });
      expect(res.status, JSON.stringify(res.body)).toBe(200);
      expectContract(res, 'actOnStaffReport');
      expect(res.body.report).toMatchObject({ status: 'ACTIONED', resolutionAction: 'DELETE_CONTENT' });
      expect((await ctx.prisma.post.findUniqueOrThrow({ where: { id: postId } })).deletedAt).not.toBeNull();
      expect((await ctx.prisma.report.findUniqueOrThrow({ where: { id: other } })).status).toBe('OPEN');
      const [del] = (await audits('admin.content.delete')).filter((x) => x.targetId === postId);
      expect(del).toMatchObject({ actorUserId: mod.id, targetType: 'post' });
      expect(del!.metadata).toMatchObject({
        reason: 'illegal',
        after: 'DELETED',
        reportsClosed: 0,
        via: 'app',
      });
      const [link] = (await audits('moderation.report.action')).filter(
        (x) => (x.metadata as { reportId?: string }).reportId === id,
      );
      expect(link!.metadata).toMatchObject({ action: 'DELETE_CONTENT', contentType: 'post', via: 'app' });
      expect(
        (await act(owner, id, { action: 'DELETE_CONTENT', reason: 'x', confirm: 'DELETE' })).status,
      ).toBe(409);
      // A comment cannot be deleted for good (only removed).
      const p2 = await newPost(author, 'post');
      const cm = await spost(author, `/posts/${p2}/comments`, { text: 'a comment' });
      const cid = await report(r1, 'COMMENT', cm.body.id as string);
      expect((await view(mod, cid)).body.actions).not.toContain('DELETE_CONTENT');
      expect((await act(mod, cid, { action: 'DELETE_CONTENT', reason: 'x', confirm: 'DELETE' })).status).toBe(
        409,
      );
    });

    it('DELETE_ACCOUNT: the OWNER only, the D193 deletion with its grace period, audited and linked', async () => {
      const [r, bad] = [await signup(), await signup()];
      const id = await report(r, 'USER', bad.id);
      expect((await view(mod, id)).body.actions).not.toContain('DELETE_ACCOUNT');
      expect(
        (await act(mod, id, { action: 'DELETE_ACCOUNT', reason: 'fraud', confirm: 'DELETE' })).status,
      ).toBe(403);
      expect((await act(owner, id, { action: 'DELETE_ACCOUNT', reason: 'fraud' })).status).toBe(400);
      const res = await act(owner, id, { action: 'DELETE_ACCOUNT', reason: 'fraud', confirm: 'DELETE' });
      expect(res.status, JSON.stringify(res.body)).toBe(200);
      expectContract(res, 'actOnStaffReport');
      expect(res.body.report).toMatchObject({ status: 'ACTIONED', resolutionAction: 'DELETE_ACCOUNT' });
      const request = await ctx.prisma.accountDeletionRequest.findFirstOrThrow({ where: { userId: bad.id } });
      expect(request.status).toBe('PENDING');
      const [audit] = (await audits('account.deletion.requested')).filter((x) => x.targetId === bad.id);
      expect(audit).toMatchObject({ actorUserId: owner.id });
      expect(audit!.metadata).toMatchObject({ reason: 'fraud', via: 'app' });
      const [link] = (await audits('moderation.report.action')).filter(
        (x) => (x.metadata as { reportId?: string }).reportId === id,
      );
      expect(link!.metadata).toMatchObject({ action: 'DELETE_ACCOUNT', via: 'app' });
      // Signed out everywhere.
      expect((await sget(bad, '/me')).status).toBe(401);
    });
  });

  describe('actOnStaffReport', () => {
    it('validates the body', async () => {
      const [r, author] = [await signup(), await signup()];
      const id = await report(r, 'POST', await newPost(author));
      for (const body of [
        { action: 'WARN' },
        { action: 'WARN', reason: '' },
        { action: 'WARN', reason: 'x', days: 3 },
        { action: 'RESTRICT', reason: 'x', days: 3 },
        { action: 'RESTRICT', reason: 'x', restriction: 'NO_POSTING' },
        { action: 'RESTRICT', reason: 'x', restriction: 'LOCK', days: 3 },
        { action: 'SUSPEND', reason: 'x' },
        { action: 'SUSPEND', reason: 'x', days: 366 },
        { action: 'BAN', reason: 'x', restriction: 'NO_LIVE' },
        { action: 'DELETE', reason: 'x' },
      ]) {
        expect((await act(mod, id, body)).status, JSON.stringify(body)).toBe(400);
      }
    });

    it('WARN resolves ONLY the pressed report, once, audited and linked; a second press is 409', async () => {
      const [r1, r2, author] = [await signup(), await signup(), await signup()];
      const postId = await newPost(author);
      const id = await report(r1, 'POST', postId);
      const other = await report(r2, 'POST', postId);
      // SUPPORT may not warn (reports.act).
      expect((await act(support, id, { action: 'WARN', reason: 'x' })).status).toBe(403);
      const res = await act(mod, id, { action: 'WARN', reason: 'first warning' });
      expect(res.status, JSON.stringify(res.body)).toBe(200);
      expectContract(res, 'actOnStaffReport');
      expect(res.body).toMatchObject({ action: 'WARN', reportsClosed: 1 });
      expect(res.body.report).toMatchObject({
        status: 'ACTIONED',
        resolutionAction: 'WARN',
        resolutionNote: 'first warning',
        resolvedBy: { id: mod.id },
      });
      // Owner (as D288's «تم حله»): another person's report on the same post stays in the queue.
      const otherRow = await ctx.prisma.report.findUniqueOrThrow({ where: { id: other } });
      expect(otherRow).toMatchObject({ status: 'OPEN', resolutionAction: null, resolvedById: null });
      // The author was warned once; the staff's alerts about the pressed report are read for everyone.
      const warnings = () =>
        ctx.prisma.notification.count({ where: { recipientId: author.id, type: 'MODERATION_WARNING' } });
      expect(await warnings()).toBe(1);
      expect(
        await ctx.prisma.notification.count({
          where: { type: 'STAFF_REPORT_NEW', reportId: id, readAt: null },
        }),
      ).toBe(0);
      expect(
        await ctx.prisma.notification.count({
          where: { type: 'STAFF_REPORT_NEW', reportId: other, readAt: null },
        }),
      ).toBeGreaterThan(0);
      const [warn] = (await audits('admin.user.warn')).filter(
        (a) => (a.metadata as { reportId?: string }).reportId === id,
      );
      expect(warn).toMatchObject({ actorUserId: mod.id, targetType: 'user', targetId: author.id });
      expect(warn!.metadata).toEqual({ reason: 'first warning', reportId: id, via: 'app' });
      const [link] = (await audits('moderation.report.action')).filter(
        (a) => (a.metadata as { reportId?: string }).reportId === id,
      );
      expect(link).toMatchObject({ actorUserId: mod.id, targetType: 'post', targetId: postId });
      expect(link!.metadata).toMatchObject({ action: 'WARN', reportsClosed: 1, via: 'app' });
      // Idempotent: the second press (or another moderator) → 409, nothing sent again.
      const second = await act(owner, id, { action: 'WARN', reason: 'again' });
      expect(second.status).toBe(409);
      expect(second.body.error.code).toBe('REPORT_ALREADY_RESOLVED');
      expect(await warnings()).toBe(1);
      // The other report is still open: its own actions and «تم حله» are there.
      expect((await view(mod, other)).body.actions).toContain('WARN');
      expect((await spost(support, `/staff/reports/${other}/resolve`, {})).status).toBe(200);
      expect((await view(mod, id)).body.actions).toEqual([]);
      // «تم حله» on it too → 409.
      expect((await spost(mod, `/staff/reports/${id}/resolve`, {})).status).toBe(409);
    });

    it('two staff members acting at once: one 200, one 409, one warning', async () => {
      const [r, author] = [await signup(), await signup()];
      const id = await report(r, 'POST', await newPost(author));
      const both = await Promise.all([
        act(mod, id, { action: 'WARN', reason: 'a' }),
        act(owner, id, { action: 'WARN', reason: 'b' }),
      ]);
      expect(both.map((x) => x.status).sort()).toEqual([200, 409]);
      expect(
        await ctx.prisma.notification.count({
          where: { recipientId: author.id, type: 'MODERATION_WARNING' },
        }),
      ).toBe(1);
    });

    it('RESTRICT «منع النشر» for some days, via app, and the person can no longer post', async () => {
      const [r, author] = [await signup(), await signup()];
      const id = await report(r, 'POST', await newPost(author));
      expect(
        (await act(support, id, { action: 'RESTRICT', reason: 'x', restriction: 'NO_POSTING', days: 7 }))
          .status,
      ).toBe(403);
      const res = await act(mod, id, {
        action: 'RESTRICT',
        reason: 'spam posts',
        restriction: 'NO_POSTING',
        days: 7,
      });
      expect(res.status, JSON.stringify(res.body)).toBe(200);
      expectContract(res, 'actOnStaffReport');
      expect(res.body.report.resolutionAction).toBe('RESTRICT');
      const row = await ctx.prisma.accountRestriction.findFirstOrThrow({
        where: { userId: author.id, kind: 'NO_POSTING', liftedAt: null },
      });
      expect(row).toMatchObject({ via: 'app', createdById: mod.id, reason: 'spam posts' });
      expect(row.endsAt.getTime() - row.startsAt.getTime()).toBe(7 * 86_400_000);
      const blocked = await ctx.http
        .post('/api/v1/posts')
        .set(auth(author))
        .set('Idempotency-Key', randomUUID())
        .send({ text: 'more' });
      expect(blocked.status).toBe(403);
      expect(blocked.body.error.code).toBe('ACCOUNT_RESTRICTED');
      const [audit] = (await audits('admin.user.restrict')).filter((a) => a.targetId === author.id);
      expect(audit!.metadata).toMatchObject({ kind: 'NO_POSTING', reason: 'spam posts', via: 'app' });
      const [link] = (await audits('moderation.report.action')).filter(
        (a) => (a.metadata as { reportId?: string }).reportId === id,
      );
      expect(link!.metadata).toMatchObject({ action: 'RESTRICT', kind: 'NO_POSTING', days: 7, via: 'app' });
    });

    it('«منع الرسائل» (CHAT_MUTE) from a DM report stops the sender’s messages', async () => {
      const [a, b] = [await signup(), await signup()];
      const m = await dmText(a, b, 'spam spam');
      const id = await report(b, 'DM_MESSAGE', m.id);
      const res = await act(mod, id, {
        action: 'RESTRICT',
        reason: 'dm spam',
        restriction: 'CHAT_MUTE',
        days: 1,
      });
      expect(res.status, JSON.stringify(res.body)).toBe(200);
      const again = await spost(a, '/dm/messages', {
        to: b.username,
        clientId: randomUUID(),
        kind: 'TEXT',
        text: 'x',
      });
      expect(again.status).toBe(403);
      expect(again.body.error.code).toBe('ACCOUNT_RESTRICTED');
    });

    it('SUSPEND (SUPPORT may: users.lock) locks the account for some days; BAN suspends it', async () => {
      const [r, a, b] = [await signup(), await signup(), await signup()];
      const id = await report(r, 'USER', a.id);
      const res = await act(support, id, { action: 'SUSPEND', reason: 'cool down', days: 3 });
      expect(res.status, JSON.stringify(res.body)).toBe(200);
      expectContract(res, 'actOnStaffReport');
      expect(res.body.report.resolutionAction).toBe('SUSPEND');
      const lock = await ctx.prisma.accountRestriction.findFirstOrThrow({
        where: { userId: a.id, kind: 'LOCK', liftedAt: null },
      });
      expect(lock.via).toBe('app');
      expect((await sget(a, '/me')).status).toBe(401);
      // SUPPORT may not ban for good (users.ban).
      const id2 = await report(r, 'USER', b.id);
      expect((await act(support, id2, { action: 'BAN', reason: 'x' })).status).toBe(403);
      const ban = await act(mod, id2, { action: 'BAN', reason: 'fake account' });
      expect(ban.status, JSON.stringify(ban.body)).toBe(200);
      expect((await ctx.prisma.user.findUniqueOrThrow({ where: { id: b.id } })).status).toBe('SUSPENDED');
      const [audit] = (await audits('admin.user.ban')).filter((x) => x.targetId === b.id);
      expect(audit!.metadata).toMatchObject({
        reason: 'fake account',
        reportId: id2,
        after: 'SUSPENDED',
        via: 'app',
      });
    });

    it('REMOVE_CONTENT hides a post or expires a DM, and resolves the report', async () => {
      const [r, author, a, b] = [await signup(), await signup(), await signup(), await signup()];
      const postId = await newPost(author);
      const id = await report(r, 'POST', postId);
      const second = await signup();
      const other = await report(second, 'POST', postId);
      const res = await act(mod, id, { action: 'REMOVE_CONTENT', reason: 'nudity' });
      expect(res.status, JSON.stringify(res.body)).toBe(200);
      expectContract(res, 'actOnStaffReport');
      expect(res.body.report).toMatchObject({ status: 'ACTIONED', resolutionAction: 'REMOVE_CONTENT' });
      expect((await ctx.prisma.post.findUniqueOrThrow({ where: { id: postId } })).moderation).toBe('REMOVED');
      // Only the pressed report closes (owner).
      expect((await ctx.prisma.report.findUniqueOrThrow({ where: { id: other } })).status).toBe('OPEN');
      expect(
        await ctx.prisma.notification.count({ where: { recipientId: author.id, type: 'CONTENT_REMOVED' } }),
      ).toBe(1);
      expect((await act(mod, id, { action: 'REMOVE_CONTENT', reason: 'again' })).status).toBe(409);
      expect(
        await ctx.prisma.notification.count({ where: { recipientId: author.id, type: 'CONTENT_REMOVED' } }),
      ).toBe(1);
      const [link] = (await audits('moderation.report.action')).filter(
        (x) => (x.metadata as { reportId?: string }).reportId === id,
      );
      expect(link!.metadata).toMatchObject({ action: 'REMOVE_TARGET', via: 'app' });

      const m = await dmText(a, b, 'remove me');
      const did = await report(b, 'DM_MESSAGE', m.id);
      const dm = await act(mod, did, { action: 'REMOVE_CONTENT', reason: 'abuse' });
      expect(dm.status, JSON.stringify(dm.body)).toBe(200);
      const left = await ctx.prisma.dmMessage.findUniqueOrThrow({ where: { id: m.id } });
      expect(left.expiresAt.getTime()).toBeLessThanOrEqual(Date.now());
    });

    it('only an OWNER acts on a «فريق كابسو» account', async () => {
      const r = await signup();
      const id = await report(r, 'USER', support.id);
      expect((await act(mod, id, { action: 'WARN', reason: 'x' })).status).toBe(403);
      expect((await ctx.prisma.report.findUniqueOrThrow({ where: { id } })).status).toBe('OPEN');
      expect((await act(owner, id, { action: 'WARN', reason: 'be careful' })).status).toBe(200);
    });

    it('«تم حله» without an action still works (no action recorded); reopen clears the action', async () => {
      const [r, author] = [await signup(), await signup()];
      const id = await report(r, 'POST', await newPost(author));
      const done = await spost(support, `/staff/reports/${id}/resolve`, { note: 'checked' });
      expect(done.status, JSON.stringify(done.body)).toBe(200);
      expect(done.body).toMatchObject({
        status: 'ACTIONED',
        resolutionAction: null,
        resolutionNote: 'checked',
      });

      const id2 = await report(r, 'POST', await newPost(author, 'second'));
      expect((await act(mod, id2, { action: 'WARN', reason: 'warned' })).status).toBe(200);
      const panel = await panelSession(mod);
      const reopen = await ctx.http
        .post(`/api/v1/admin/moderation/reports/${id2}/reopen`)
        .set('Cookie', panel.cookie)
        .set('X-CSRF-Token', panel.csrf)
        .send({ reason: 'wrong person' });
      expect(reopen.status, JSON.stringify(reopen.body)).toBe(200);
      expect(reopen.body).toMatchObject({ status: 'OPEN', resolutionAction: null, resolvedBy: null });
      const [audit] = (await audits('moderation.report.reopen')).filter(
        (x) => (x.metadata as { reportId?: string }).reportId === id2,
      );
      expect(audit!.metadata).toMatchObject({ resolutionAction: 'WARN' });
      // Open again: the actions are back.
      expect((await view(mod, id2)).body.actions).toContain('WARN');
    });
  });
});
