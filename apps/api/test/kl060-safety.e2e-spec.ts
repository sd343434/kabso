/**
 * KL-060 group 6: block, mute, hide, reports with the admin queue (permission MODERATION) and
 * privacy settings (openapi v1.5-social DRAFT, CONVENTIONS §11.7), end to end.
 */
import { randomUUID } from 'node:crypto';
import type request from 'supertest';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { expectContract } from './helpers/openapi.js';
import {
  createTestApp,
  registerVerified,
  withMigrationClient,
  type TestContext,
} from './helpers/test-app.js';

interface TestUser {
  readonly id: string;
  readonly username: string;
  readonly token: string;
}

describe('KL-060 safety', () => {
  let ctx: TestContext;
  const auth = (u: TestUser) => ({ Authorization: `Bearer ${u.token}` });
  const signup = async (): Promise<TestUser> => {
    const { res } = await registerVerified(ctx);
    expect(res.status).toBe(201);
    return { id: res.body.user.id, username: res.body.user.username, token: res.body.tokens.accessToken };
  };
  const post = async (u: TestUser, text = 'a post', extra: object = {}): Promise<string> => {
    const res = await ctx.http
      .post('/api/v1/posts')
      .set(auth(u))
      .set('Idempotency-Key', randomUUID())
      .send({ text, ...extra });
    expect(res.status).toBe(201);
    return res.body.id as string;
  };
  const ids = (res: request.Response) => res.body.data.map((p: { id: string }) => p.id) as string[];
  const follow = (a: TestUser, b: TestUser) =>
    ctx.http.put(`/api/v1/users/${b.username}/follow`).set(auth(a));

  beforeAll(async () => {
    ctx = await createTestApp();
  });
  afterAll(async () => ctx?.close());

  describe('block', () => {
    it('hides both sides, removes follows both ways, refuses new follows, and lists blocks', async () => {
      const [me, them] = [await signup(), await signup()];
      expect((await follow(me, them)).status).toBe(200);
      expect((await follow(them, me)).status).toBe(200);
      const theirPost = await post(them);
      const myPost = await post(me);
      const blocked = await ctx.http.put(`/api/v1/users/${them.username}/block`).set(auth(me));
      expect(blocked.status).toBe(200);
      expectContract(blocked, 'blockUser');
      expect(blocked.body).toEqual({ blocked: true });
      expect((await ctx.http.put(`/api/v1/users/${them.username}/block`).set(auth(me))).status).toBe(200);
      expect(
        await ctx.prisma.follow.count({ where: { OR: [{ followerId: me.id }, { followerId: them.id }] } }),
      ).toBe(0);
      expect((await ctx.http.get(`/api/v1/posts/${theirPost}`).set(auth(me))).status).toBe(404);
      expect((await ctx.http.get(`/api/v1/posts/${myPost}`).set(auth(them))).status).toBe(404);
      expect((await ctx.http.get(`/api/v1/users/${me.username}/posts`).set(auth(them))).status).toBe(404);
      // Neither side can follow while the block exists.
      const refollow = await follow(them, me);
      expect(refollow.status).toBe(404);
      expectContract(refollow, 'followUser');
      expect((await follow(me, them)).status).toBe(404);

      const list = await ctx.http.get('/api/v1/me/blocks').set(auth(me));
      expect(list.status).toBe(200);
      expectContract(list, 'listBlocks');
      expect(list.body.data.map((u: { id: string }) => u.id)).toEqual([them.id]);
      expect((await ctx.http.get('/api/v1/me/blocks').set(auth(them))).body.data).toEqual([]);

      const unblock = await ctx.http.delete(`/api/v1/users/${them.username}/block`).set(auth(me));
      expect(unblock.status).toBe(200);
      expectContract(unblock, 'unblockUser');
      expect(unblock.body).toEqual({ blocked: false });
      // Follows are not restored, but may be made again.
      expect(await ctx.prisma.follow.count({ where: { followerId: me.id, followeeId: them.id } })).toBe(0);
      expect((await follow(them, me)).status).toBe(200);
    });

    it('a follow racing a block never survives it', async () => {
      for (let i = 0; i < 5; i += 1) {
        const [a, b] = [await signup(), await signup()];
        await Promise.all([follow(b, a), ctx.http.put(`/api/v1/users/${b.username}/block`).set(auth(a))]);
        expect(await ctx.prisma.follow.count({ where: { followerId: b.id, followeeId: a.id } })).toBe(0);
      }
    });

    it('self, unknown and malformed usernames', async () => {
      const me = await signup();
      const self = await ctx.http.put(`/api/v1/users/${me.username}/block`).set(auth(me));
      expect(self.status).toBe(400);
      expect(self.body.error.details).toEqual([{ field: 'username', issue: 'invalid_value' }]);
      expectContract(self, 'blockUser');
      for (const name of ['no_such_user_zz', 'BAD%20NAME']) {
        const res = await ctx.http.put(`/api/v1/users/${name}/block`).set(auth(me));
        expect(res.status).toBe(404);
        expectContract(res, 'blockUser');
      }
      expect((await ctx.http.put(`/api/v1/users/${me.username}/mute`).set(auth(me))).status).toBe(400);
    });
  });

  describe('mute and hide', () => {
    it('mute is one-way and silent; hide drops a post from the caller’s feeds only', async () => {
      const [me, loud, other] = [await signup(), await signup(), await signup()];
      await follow(me, loud);
      await follow(me, other);
      const loudPost = await post(loud);
      const otherPost = await post(other);
      const muted = await ctx.http.put(`/api/v1/users/${loud.username}/mute`).set(auth(me));
      expect(muted.status).toBe(200);
      expectContract(muted, 'muteUser');
      expect(muted.body).toEqual({ muted: true });
      expect(ids(await ctx.http.get('/api/v1/feed/posts?tab=following').set(auth(me)))).toEqual([otherPost]);
      // Profile and direct links still work; the muted user sees nothing different.
      expect((await ctx.http.get(`/api/v1/posts/${loudPost}`).set(auth(me))).status).toBe(200);
      expect((await follow(loud, me)).status).toBe(200);
      const unmute = await ctx.http.delete(`/api/v1/users/${loud.username}/mute`).set(auth(me));
      expectContract(unmute, 'unmuteUser');
      expect(ids(await ctx.http.get('/api/v1/feed/posts?tab=following').set(auth(me)))).toEqual([
        otherPost,
        loudPost,
      ]);

      const hidden = await ctx.http.put(`/api/v1/posts/${otherPost}/hide`).set(auth(me));
      expect(hidden.status).toBe(204);
      expectContract(hidden, 'hidePost');
      expect((await ctx.http.put(`/api/v1/posts/${otherPost}/hide`).set(auth(me))).status).toBe(204);
      expect(ids(await ctx.http.get('/api/v1/feed/posts?tab=following').set(auth(me)))).toEqual([loudPost]);
      const unhide = await ctx.http.delete(`/api/v1/posts/${otherPost}/hide`).set(auth(me));
      expect(unhide.status).toBe(204);
      expectContract(unhide, 'unhidePost');
      expect(ids(await ctx.http.get('/api/v1/feed/posts?tab=following').set(auth(me)))).toEqual([
        otherPost,
        loudPost,
      ]);
      const missing = await ctx.http.put(`/api/v1/posts/${randomUUID()}/hide`).set(auth(me));
      expect(missing.status).toBe(404);
      expectContract(missing, 'hidePost');
    });
  });

  describe('muted accounts (CP-007)', () => {
    it('lists the caller’s mutes newest first, paged; isMuted on profiles; never told', async () => {
      const me = await signup();
      const [a, b, c] = [await signup(), await signup(), await signup()];
      for (const u of [a, b, c]) {
        expect((await ctx.http.put(`/api/v1/users/${u.username}/mute`).set(auth(me))).status).toBe(200);
        // Distinct created_at so the order is the mute order.
        await new Promise((r) => setTimeout(r, 5));
      }
      // A muted account that is also blocked stays listed (it can still be unmuted).
      expect((await ctx.http.put(`/api/v1/users/${b.username}/block`).set(auth(me))).status).toBe(200);

      const first = await ctx.http.get('/api/v1/me/mutes?limit=2').set(auth(me));
      expect(first.status).toBe(200);
      expectContract(first, 'listMutes');
      expect(ids(first)).toEqual([c.id, b.id]);
      expect(first.body.page.hasMore).toBe(true);
      const second = await ctx.http
        .get(`/api/v1/me/mutes?limit=2&cursor=${encodeURIComponent(first.body.page.nextCursor)}`)
        .set(auth(me));
      expect(second.status).toBe(200);
      expect(ids(second)).toEqual([a.id]);
      expect(second.body.page).toEqual({ hasMore: false, nextCursor: null });

      // A cursor is bound to its list and caller.
      const foreign = await ctx.http
        .get(`/api/v1/me/mutes?cursor=${encodeURIComponent(first.body.page.nextCursor)}`)
        .set(auth(a));
      expect(foreign.status).toBe(400);
      const asBlocks = await ctx.http
        .get(`/api/v1/me/blocks?cursor=${encodeURIComponent(first.body.page.nextCursor)}`)
        .set(auth(me));
      expect(asBlocks.status).toBe(400);

      // Mutes are private: others see their own (empty) list, and no trace of being muted.
      expect((await ctx.http.get('/api/v1/me/mutes').set(auth(a))).body.data).toEqual([]);
      const mine = await ctx.http.get(`/api/v1/users/${a.username}`).set(auth(me));
      expect(mine.status).toBe(200);
      expectContract(mine, 'getPublicProfile');
      expect(mine.body.isMuted).toBe(true);
      const theirs = await ctx.http.get(`/api/v1/users/${me.username}`).set(auth(a));
      expect(theirs.body.isMuted).toBe(false);
      const self = await ctx.http.get(`/api/v1/users/${me.username}`).set(auth(me));
      expect(self.body.isMuted).toBe(false);

      expect((await ctx.http.delete(`/api/v1/users/${a.username}/mute`).set(auth(me))).status).toBe(200);
      expect((await ctx.http.get(`/api/v1/users/${a.username}`).set(auth(me))).body.isMuted).toBe(false);
      expect(ids(await ctx.http.get('/api/v1/me/mutes').set(auth(me)))).toEqual([c.id, b.id]);
      expect((await ctx.http.get('/api/v1/me/mutes').set({})).status).toBe(401);
    });
  });

  describe('reports and the admin queue', () => {
    it('one open report per reporter and target; validation; own targets refused', async () => {
      const [me, them] = [await signup(), await signup()];
      const theirPost = await post(them);
      const first = await ctx.http
        .post('/api/v1/reports')
        .set(auth(me))
        .send({ targetType: 'POST', targetId: theirPost, reason: 'SPAM', note: '  junk  ' });
      expect(first.status).toBe(201);
      expectContract(first, 'createReport');
      expect(first.body).toMatchObject({
        targetType: 'POST',
        targetId: theirPost,
        status: 'OPEN',
        note: 'junk',
      });
      expect(first.body.reporter).toBeUndefined();
      const again = await ctx.http
        .post('/api/v1/reports')
        .set(auth(me))
        .send({ targetType: 'POST', targetId: theirPost, reason: 'HATE' });
      expect(again.status).toBe(200);
      expectContract(again, 'createReport');
      expect(again.body.id).toBe(first.body.id);
      // Concurrent duplicates make one report.
      const user = await Promise.all(
        Array.from({ length: 4 }, () =>
          ctx.http
            .post('/api/v1/reports')
            .set(auth(me))
            .send({ targetType: 'USER', targetId: them.username, reason: 'HARASSMENT' }),
        ),
      );
      expect(new Set(user.map((r) => r.body.id as string)).size).toBe(1);
      expect(user[0]!.body.targetId).toBe(them.username);

      const cases: [object, number][] = [
        [{ targetType: 'POST', targetId: await post(me), reason: 'SPAM' }, 400],
        [{ targetType: 'USER', targetId: me.username, reason: 'SPAM' }, 400],
        [{ targetType: 'POST', targetId: randomUUID(), reason: 'SPAM' }, 404],
        [{ targetType: 'COMMENT', targetId: 'nope', reason: 'SPAM' }, 404],
        [{ targetType: 'POST', targetId: theirPost, reason: 'BORING' }, 400],
        [{ targetType: 'POST', targetId: theirPost, reason: 'SPAM', note: 'x'.repeat(501) }, 400],
        [{ targetType: 'POST', targetId: theirPost, reason: 'SPAM', extra: 1 }, 400],
      ];
      for (const [body, status] of cases) {
        const res = await ctx.http.post('/api/v1/reports').set(auth(me)).send(body);
        expect(res.status, JSON.stringify(body)).toBe(status);
        expectContract(res, 'createReport');
      }
    });

    it('MODERATION: list oldest first; REMOVE_TARGET removes and closes every open report; audited', async () => {
      const [r1, r2, author, mod, plainAdmin] = [
        await signup(),
        await signup(),
        await signup(),
        await signup(),
        await signup(),
      ];
      await withMigrationClient(async (c) => {
        await c.user.update({ where: { id: mod.id }, data: { role: 'ADMIN' } });
        await c.userAdminPermission.create({ data: { userId: mod.id, permission: 'MODERATION' } });
        await c.user.update({ where: { id: plainAdmin.id }, data: { role: 'ADMIN' } });
        await c.userAdminPermission.create({ data: { userId: plainAdmin.id, permission: 'LEVELS_VIEW' } });
      });
      const bad = await post(author, 'bad post');
      const c1 = await ctx.http.post(`/api/v1/posts/${bad}/comments`).set(auth(r1)).send({ text: 'top' });
      const c2 = await ctx.http
        .post(`/api/v1/posts/${bad}/comments`)
        .set(auth(author))
        .send({ text: 'rude reply', parentId: c1.body.id });
      const rep1 = await ctx.http
        .post('/api/v1/reports')
        .set(auth(r1))
        .send({ targetType: 'POST', targetId: bad, reason: 'NUDITY' });
      const rep2 = await ctx.http
        .post('/api/v1/reports')
        .set(auth(r2))
        .send({ targetType: 'POST', targetId: bad, reason: 'VIOLENCE' });
      const repC = await ctx.http
        .post('/api/v1/reports')
        .set(auth(r1))
        .send({ targetType: 'COMMENT', targetId: c2.body.id, reason: 'HARASSMENT' });

      for (const u of [r1, plainAdmin]) {
        const res = await ctx.http.get('/api/v1/admin/reports').set(auth(u));
        expect(res.status).toBe(403);
        expectContract(res, 'listAdminReports');
      }
      // Oldest first; walk all pages until ours appear (earlier runs leave open reports).
      const seen: string[] = [];
      let cursor: string | null = null;
      for (let i = 0; i < 100; i += 1) {
        const res: request.Response = await ctx.http
          .get(`/api/v1/admin/reports?limit=50${cursor ? `&cursor=${cursor}` : ''}`)
          .set(auth(mod));
        expect(res.status).toBe(200);
        expectContract(res, 'listAdminReports');
        seen.push(...res.body.data.map((r: { id: string }) => r.id));
        cursor = res.body.page.nextCursor;
        if (!res.body.page.hasMore) break;
      }
      const ours = seen.filter((id) => [rep1.body.id, rep2.body.id, repC.body.id].includes(id));
      expect(ours).toEqual([rep1.body.id, rep2.body.id, repC.body.id]);

      const act = await ctx.http
        .post(`/api/v1/admin/reports/${rep1.body.id}/actions`)
        .set(auth(mod))
        .send({ action: 'REMOVE_TARGET', note: 'nudity' });
      expect(act.status).toBe(200);
      expectContract(act, 'actOnReport');
      expect(act.body).toMatchObject({ status: 'ACTIONED', reporter: { id: r1.id } });
      expect(act.body.resolvedAt).not.toBeNull();
      // The post is gone for everyone, its author included; the other open report closed too.
      expect((await ctx.http.get(`/api/v1/posts/${bad}`).set(auth(author))).status).toBe(404);
      expect(await ctx.prisma.report.findUniqueOrThrow({ where: { id: rep2.body.id } })).toMatchObject({
        status: 'ACTIONED',
        resolvedById: mod.id,
      });
      const audit = await ctx.prisma.auditLog.findFirstOrThrow({
        where: { action: 'moderation.report.action', actorUserId: mod.id },
        orderBy: { createdAt: 'desc' },
      });
      expect(audit).toMatchObject({ targetType: 'post', targetId: bad });
      expect(audit.metadata).toMatchObject({
        reportId: rep1.body.id,
        action: 'REMOVE_TARGET',
        reportsClosed: 2,
      });

      const twice = await ctx.http
        .post(`/api/v1/admin/reports/${rep2.body.id}/actions`)
        .set(auth(mod))
        .send({ action: 'DISMISS' });
      expect(twice.status).toBe(409);
      expect(twice.body.error.code).toBe('REPORT_ALREADY_RESOLVED');
      expectContract(twice, 'actOnReport');

      // Removing a reply comment adjusts the counts.
      const parentBefore = await ctx.prisma.comment.findUniqueOrThrow({ where: { id: c1.body.id } });
      await ctx.http
        .post(`/api/v1/admin/reports/${repC.body.id}/actions`)
        .set(auth(mod))
        .send({ action: 'REMOVE_TARGET' });
      expect(await ctx.prisma.comment.findUniqueOrThrow({ where: { id: c2.body.id } })).toMatchObject({
        deletedAt: expect.any(Date),
      });
      expect((await ctx.prisma.comment.findUniqueOrThrow({ where: { id: c1.body.id } })).replyCount).toBe(
        parentBefore.replyCount - 1,
      );

      // A new report after resolution opens a new case; DISMISS changes nothing on the target.
      const userReport = await ctx.http
        .post('/api/v1/reports')
        .set(auth(r2))
        .send({ targetType: 'USER', targetId: author.username, reason: 'OTHER' });
      const dismissed = await ctx.http
        .post(`/api/v1/admin/reports/${userReport.body.id}/actions`)
        .set(auth(mod))
        .send({ action: 'DISMISS' });
      expect(dismissed.body.status).toBe('DISMISSED');
      expect((await ctx.prisma.user.findUniqueOrThrow({ where: { id: author.id } })).status).toBe('ACTIVE');

      for (const [id, body, status] of [
        ['x', { action: 'DISMISS' }, 404],
        [randomUUID(), { action: 'DISMISS' }, 404],
        [rep2.body.id, { action: 'BAN' }, 400],
      ] as const) {
        const res = await ctx.http.post(`/api/v1/admin/reports/${id}/actions`).set(auth(mod)).send(body);
        expect(res.status).toBe(status);
        expectContract(res, 'actOnReport');
      }
      const forbidden = await ctx.http
        .post(`/api/v1/admin/reports/${rep2.body.id}/actions`)
        .set(auth(plainAdmin))
        .send({ action: 'DISMISS' });
      expect(forbidden.status).toBe(403);
      const closed = await ctx.http.get('/api/v1/admin/reports?status=ACTIONED&limit=1').set(auth(mod));
      expect(closed.status).toBe(200);
      expectContract(closed, 'listAdminReports');
    });
  });

  describe('privacy', () => {
    it('defaults, partial update, and its effect on new posts and mentions', async () => {
      const [me, other] = [await signup(), await signup()];
      const initial = await ctx.http.get('/api/v1/me/privacy').set(auth(me));
      expect(initial.status).toBe(200);
      expectContract(initial, 'getPrivacy');
      expect(initial.body).toEqual({
        whoCanMention: 'EVERYONE',
        defaultWhoCanComment: 'EVERYONE',
        // v1.25-live (CP-022): presence is visible by default.
        showActivityStatus: true,
      });
      const updated = await ctx.http
        .patch('/api/v1/me/privacy')
        .set(auth(me))
        .send({ defaultWhoCanComment: 'FOLLOWERS', whoCanMention: 'FOLLOWING' });
      expect(updated.status).toBe(200);
      expectContract(updated, 'updatePrivacy');
      expect(updated.body).toEqual({
        whoCanMention: 'FOLLOWING',
        defaultWhoCanComment: 'FOLLOWERS',
        showActivityStatus: true,
      });
      const partial = await ctx.http
        .patch('/api/v1/me/privacy')
        .set(auth(me))
        .send({ whoCanMention: 'NOBODY' });
      expect(partial.body).toEqual({
        whoCanMention: 'NOBODY',
        defaultWhoCanComment: 'FOLLOWERS',
        showActivityStatus: true,
      });
      const created = await ctx.http.get(`/api/v1/posts/${await post(me)}`).set(auth(me));
      expect(created.body.settings.whoCanComment).toBe('FOLLOWERS');
      const mention = await ctx.http
        .get(`/api/v1/posts/${await post(other, `hi @${me.username}`)}`)
        .set(auth(other));
      expect(mention.body.mentions).toEqual([]);
      for (const body of [{}, { whoCanMention: 'FRIENDS' }, { extra: true }]) {
        const res = await ctx.http.patch('/api/v1/me/privacy').set(auth(me)).send(body);
        expect(res.status).toBe(400);
        expectContract(res, 'updatePrivacy');
      }
    });
  });
});
