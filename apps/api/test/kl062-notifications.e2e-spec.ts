/**
 * KL-062 / CP-009 (D92): in-app notifications (openapi v1.5-social DRAFT, CONVENTIONS §11.10), end
 * to end against PostgreSQL + Redis with the API as the DML-only runtime role. Object storage is
 * the in-memory test double behind the ObjectStorage port.
 */
import { randomUUID } from 'node:crypto';
import sharp from 'sharp';
import type request from 'supertest';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { OBJECT_STORAGE } from '../src/modules/media/object-storage.js';
import { NotificationsService } from '../src/modules/notifications/notifications.service.js';
import { PostsService } from '../src/modules/posts/posts.service.js';
import { MemoryObjectStorage } from './helpers/memory-storage.js';
import { expectContract, operations } from './helpers/openapi.js';
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

interface Note {
  id: string;
  type: string;
  actors: { id: string; username: string }[];
  actorCount: number;
  target: {
    type: string;
    id: string;
    postId: string | null;
    thumbUrl: string | null;
    text: string | null;
  } | null;
  createdAt: string;
  read: boolean;
}

type Users<N extends number, R extends TestUser[] = []> = R['length'] extends N
  ? R
  : Users<N, [...R, TestUser]>;

const MEDIA_ON = {
  MEDIA_UPLOADS_ENABLED: 'true',
  S3_BUCKET: 'kabso-media-test',
  S3_ACCESS_KEY_ID: 'test',
  S3_SECRET_ACCESS_KEY: 'test',
  MEDIA_PUBLIC_BASE_URL: 'https://media.example.test',
};

describe('CP-009 notifications contract coverage', () => {
  it('openapi declares the five notification operations', () => {
    expect(
      operations()
        .filter((o) => /^\/api\/v1\/(notifications|me\/notification-settings)(\/|$)/.test(o.path))
        .map((o) => o.operationId)
        .sort(),
    ).toEqual([
      'getNotificationSettings',
      'getUnreadNotificationCount',
      'listNotifications',
      'markNotificationsRead',
      'updateNotificationSettings',
    ]);
  });
});

describe('CP-009 notifications', () => {
  let ctx: TestContext;
  let storage: MemoryObjectStorage;
  const auth = (u: TestUser) => ({ Authorization: `Bearer ${u.token}` });
  const signup = async (): Promise<TestUser> => {
    const { res } = await registerVerified(ctx);
    expect(res.status).toBe(201);
    return { id: res.body.user.id, username: res.body.user.username, token: res.body.tokens.accessToken };
  };
  /** `n` fresh users, typed as a tuple so destructuring needs no checks. */
  const users = async <N extends number>(n: N): Promise<Users<N>> => {
    const out: TestUser[] = [];
    for (let i = 0; i < n; i += 1) out.push(await signup());
    return out as Users<N>;
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
  const comment = async (u: TestUser, postId: string, text: string, parentId?: string): Promise<string> => {
    const res = await ctx.http
      .post(`/api/v1/posts/${postId}/comments`)
      .set(auth(u))
      .send({ text, ...(parentId ? { parentId } : {}) });
    expect(res.status).toBe(201);
    return res.body.id as string;
  };
  const like = (u: TestUser, postId: string, on = true) =>
    on
      ? ctx.http.put(`/api/v1/posts/${postId}/like`).set(auth(u))
      : ctx.http.delete(`/api/v1/posts/${postId}/like`).set(auth(u));
  /** The whole inbox, walking all pages with `limit`. */
  const inbox = async (u: TestUser, limit = 50): Promise<Note[]> => {
    const items: Note[] = [];
    let cursor: string | null = null;
    for (let i = 0; i < 50; i += 1) {
      const res: request.Response = await ctx.http
        .get(`/api/v1/notifications?limit=${limit}${cursor ? `&cursor=${encodeURIComponent(cursor)}` : ''}`)
        .set(auth(u));
      expect(res.status).toBe(200);
      expectContract(res, 'listNotifications');
      items.push(...res.body.data);
      cursor = res.body.page.nextCursor;
      if (!res.body.page.hasMore) break;
    }
    return items;
  };
  const unread = async (u: TestUser): Promise<number> => {
    const res = await ctx.http.get('/api/v1/notifications/unread-count').set(auth(u));
    expect(res.status).toBe(200);
    expectContract(res, 'getUnreadNotificationCount');
    return res.body.count as number;
  };
  const markAll = async (u: TestUser) => {
    const res = await ctx.http.post('/api/v1/notifications/read').set(auth(u)).send({ all: true });
    expect(res.status).toBe(204);
  };
  const upload = async (u: TestUser, kind: 'STORY_IMAGE' | 'POST_IMAGE') => {
    const bytes = await sharp({
      create: { width: 64, height: 64, channels: 3, background: { r: 9, g: 9, b: 9 } },
    })
      .jpeg()
      .toBuffer();
    const slot = await ctx.http
      .post('/api/v1/media/uploads')
      .set(auth(u))
      .send({ kind, contentType: 'image/jpeg', byteSize: bytes.length });
    expect(slot.status).toBe(201);
    storage.upload(slot.body.uploadUrl, bytes, 'image/jpeg');
    const done = await ctx.http.post(`/api/v1/media/uploads/${slot.body.uploadId}/complete`).set(auth(u));
    expect(done.status).toBe(200);
    return done.body as { id: string; thumbUrl: string };
  };

  beforeAll(async () => {
    storage = new MemoryObjectStorage();
    ctx = await createTestApp(MEDIA_ON, [{ token: OBJECT_STORAGE, value: storage }]);
    ctx.app.getHttpServer().setMaxListeners(64);
  });
  afterAll(async () => ctx?.close());

  it('needs a token', async () => {
    for (const res of [
      await ctx.http.get('/api/v1/notifications'),
      await ctx.http.get('/api/v1/notifications/unread-count'),
      await ctx.http.post('/api/v1/notifications/read').send({ all: true }),
      await ctx.http.get('/api/v1/me/notification-settings'),
    ]) {
      expect(res.status).toBe(401);
    }
  });

  describe('likes and reposts', () => {
    it('likes group while unread (newest actors first); never yourself; unlike takes the actor away', async () => {
      const [author, b, c] = await users(3);
      const p = await post(author, 'my post');
      await like(author, p);
      expect(await inbox(author)).toEqual([]);
      await like(b, p);
      await like(c, p);
      await like(c, p); // idempotent
      let notes = await inbox(author);
      expect(notes).toHaveLength(1);
      expect(notes[0]).toMatchObject({
        type: 'LIKE_POST',
        actorCount: 2,
        read: false,
        target: { type: 'POST', id: p, postId: null, thumbUrl: null, text: 'my post' },
      });
      expect(notes[0]!.actors.map((a) => a.id)).toEqual([c.id, b.id]);
      expect(await unread(author)).toBe(1);
      expect((await like(c, p, false)).status).toBe(200);
      notes = await inbox(author);
      expect(notes[0]).toMatchObject({ actorCount: 1, actors: [{ id: b.id }] });
      await like(b, p, false);
      expect(await inbox(author)).toEqual([]);
      expect(await unread(author)).toBe(0);
    });

    it('a read group is closed: the next like starts a new one at the top', async () => {
      const [author, b, c] = await users(3);
      const p = await post(author);
      await like(b, p);
      await markAll(author);
      await like(c, p);
      const notes = await inbox(author);
      expect(notes.map((n) => [n.type, n.read, n.actors.map((a) => a.id)])).toEqual([
        ['LIKE_POST', false, [c.id]],
        ['LIKE_POST', true, [b.id]],
      ]);
      expect(await unread(author)).toBe(1);
    });

    it('concurrent likes join one group', async () => {
      const [author, ...likers] = await users(6);
      const p = await post(author);
      await Promise.all(likers.map((u) => like(u, p)));
      const notes = await inbox(author);
      expect(notes).toHaveLength(1);
      expect(notes[0]!.actorCount).toBe(5);
      expect(notes[0]!.actors).toHaveLength(3);
    });

    it('reposts group; un-repost takes it away', async () => {
      const [author, b, c] = await users(3);
      const p = await post(author);
      await ctx.http.put(`/api/v1/posts/${p}/repost`).set(auth(b)).expect(200);
      await ctx.http.put(`/api/v1/posts/${p}/repost`).set(auth(c)).expect(200);
      expect((await inbox(author))[0]).toMatchObject({ type: 'REPOST', actorCount: 2 });
      await ctx.http.delete(`/api/v1/posts/${p}/repost`).set(auth(b)).expect(200);
      await ctx.http.delete(`/api/v1/posts/${p}/repost`).set(auth(c)).expect(200);
      expect(await inbox(author)).toEqual([]);
    });
  });

  describe('comments, replies and mentions', () => {
    it('COMMENT to the post author, REPLY to the comment replied to, MENTION once; likes on comments', async () => {
      const [author, b, c, d] = await users(4);
      const p = await post(author);
      const top = await comment(b, p, `nice one @${d.username}`);
      const reply = await comment(c, p, `@${b.username} agreed @${d.username}`, top);
      // A reply to a reply attaches to the top comment but tells the one replied to.
      const reply2 = await comment(author, p, 'thanks', reply);
      expect((await inbox(author)).map((n) => [n.type, n.target?.id])).toEqual([['COMMENT', top]]);
      const authorNote = (await inbox(author))[0]!;
      expect(authorNote.target).toMatchObject({
        type: 'COMMENT',
        postId: p,
        text: `nice one @${d.username}`,
      });
      expect((await inbox(b)).map((n) => [n.type, n.target?.id])).toEqual([['REPLY', reply]]);
      expect((await inbox(c)).map((n) => [n.type, n.target?.id])).toEqual([['REPLY', reply2]]);
      expect((await inbox(d)).map((n) => [n.type, n.target?.id])).toEqual([
        ['MENTION', reply],
        ['MENTION', top],
      ]);
      await ctx.http.put(`/api/v1/comments/${top}/like`).set(auth(c)).expect(200);
      await ctx.http.put(`/api/v1/comments/${top}/like`).set(auth(author)).expect(200);
      const likes = (await inbox(b)).filter((n) => n.type === 'LIKE_COMMENT');
      expect(likes).toHaveLength(1);
      expect(likes[0]).toMatchObject({ actorCount: 2, target: { type: 'COMMENT', id: top, postId: p } });
      await ctx.http.delete(`/api/v1/comments/${top}/like`).set(auth(c)).expect(200);
      await ctx.http.delete(`/api/v1/comments/${top}/like`).set(auth(author)).expect(200);
      expect((await inbox(b)).map((n) => n.type)).toEqual(['REPLY']);
      // Deleting a comment drops its notifications (and its replies').
      await ctx.http.delete(`/api/v1/comments/${top}`).set(auth(b)).expect(204);
      expect(await inbox(author)).toEqual([]);
      expect(await inbox(d)).toEqual([]);
      expect(await inbox(c)).toEqual([]);
    });

    it('post mentions: published only, once per user; an edit tells only the new ones; long text is cut to 80', async () => {
      const [author, b, c] = await users(3);
      const draft = await post(author, `draft @${b.username}`, { status: 'DRAFT' });
      expect(await inbox(b)).toEqual([]);
      await ctx.http
        .patch(`/api/v1/posts/${draft}`)
        .set(auth(author))
        .send({ status: 'PUBLISHED' })
        .expect(200);
      expect((await inbox(b)).map((n) => [n.type, n.target?.id])).toEqual([['MENTION', draft]]);
      const long = `@${b.username} ${'word '.repeat(40)}`;
      await ctx.http
        .patch(`/api/v1/posts/${draft}`)
        .set(auth(author))
        .send({ text: `${long} @${c.username}` })
        .expect(200);
      const bNotes = await inbox(b);
      expect(bNotes).toHaveLength(1);
      const text = bNotes[0]!.target!.text!;
      expect([...text].length).toBe(80);
      expect(text.endsWith('…')).toBe(true);
      expect((await inbox(c)).map((n) => n.type)).toEqual(['MENTION']);
    });

    it('scheduled posts: POST_PUBLISHED to the author and mentions when published', async () => {
      const [author, b] = await users(2);
      const s = await post(author, `soon @${b.username}`, {
        status: 'SCHEDULED',
        publishAt: new Date(Date.now() + 3600_000).toISOString(),
      });
      expect(await inbox(b)).toEqual([]);
      await withMigrationClient((c) =>
        c.post.update({ where: { id: s }, data: { publishAt: new Date(Date.now() - 1000) } }),
      );
      expect(await ctx.app.get(PostsService).publishDue()).toBeGreaterThanOrEqual(1);
      const mine = await inbox(author);
      expect(mine).toHaveLength(1);
      expect(mine[0]).toMatchObject({
        type: 'POST_PUBLISHED',
        actors: [],
        actorCount: 0,
        target: { type: 'POST', id: s },
      });
      expect((await inbox(b)).map((n) => [n.type, n.actors[0]?.id])).toEqual([['MENTION', author.id]]);
    });

    it('story mentions point at the story with its photo', async () => {
      const [author, b] = await users(2);
      const media = await upload(author, 'STORY_IMAGE');
      const res = await ctx.http
        .post('/api/v1/stories')
        .set(auth(author))
        .set('Idempotency-Key', randomUUID())
        .send({ mediaId: media.id, text: `hey @${b.username}` });
      expect(res.status).toBe(201);
      const notes = await inbox(b);
      expect(notes).toHaveLength(1);
      expect(notes[0]).toMatchObject({
        type: 'MENTION',
        target: {
          type: 'STORY',
          id: res.body.id,
          postId: null,
          thumbUrl: media.thumbUrl,
          text: `hey @${b.username}`,
        },
      });
    });
  });

  describe('follows', () => {
    it('FOLLOW points at the follower; unfollow takes it away', async () => {
      const [me, fan] = await users(2);
      await ctx.http.put(`/api/v1/users/${me.username}/follow`).set(auth(fan)).expect(200);
      await ctx.http.put(`/api/v1/users/${me.username}/follow`).set(auth(fan)).expect(200);
      const notes = await inbox(me);
      expect(notes).toHaveLength(1);
      expect(notes[0]).toMatchObject({
        type: 'FOLLOW',
        actorCount: 1,
        target: { type: 'USER', id: fan.username, postId: null, thumbUrl: null, text: null },
      });
      await ctx.http.delete(`/api/v1/users/${me.username}/follow`).set(auth(fan)).expect(200);
      expect(await inbox(me)).toEqual([]);
    });
  });

  describe('safety', () => {
    it('a block hides existing notifications and stops new ones, both ways', async () => {
      const [me, b] = await users(2);
      const p = await post(me);
      await like(b, p);
      expect(await unread(me)).toBe(1);
      await ctx.http.put(`/api/v1/users/${b.username}/block`).set(auth(me)).expect(200);
      expect(await inbox(me)).toEqual([]);
      expect(await unread(me)).toBe(0);
      await ctx.http.delete(`/api/v1/users/${b.username}/block`).set(auth(me)).expect(200);
      expect(await inbox(me)).toHaveLength(1);
      // Blocked by the recipient: nothing new is written.
      await ctx.http.put(`/api/v1/users/${me.username}/block`).set(auth(b)).expect(200);
      const other = await post(b);
      expect((await like(me, other)).status).toBe(404);
      expect(await withMigrationClient((c) => c.notification.count({ where: { recipientId: b.id } }))).toBe(
        0,
      );
    });

    it('a muted account cannot notify (D92); an account no longer ACTIVE leaves the group', async () => {
      const [me, muted, gone, ok] = await users(4);
      const p = await post(me);
      await ctx.http.put(`/api/v1/users/${muted.username}/mute`).set(auth(me)).expect(200);
      await like(muted, p);
      expect(await inbox(me)).toEqual([]);
      await ctx.http.delete(`/api/v1/users/${muted.username}/mute`).set(auth(me)).expect(200);
      expect(await inbox(me)).toEqual([]);
      await like(gone, p);
      await like(ok, p);
      expect((await inbox(me))[0]!.actorCount).toBe(2);
      await withMigrationClient((c) =>
        c.user.update({ where: { id: gone.id }, data: { status: 'SUSPENDED' } }),
      );
      expect((await inbox(me))[0]).toMatchObject({ actorCount: 1, actors: [{ id: ok.id }] });
      // A mute set later hides the existing group too.
      await ctx.http.put(`/api/v1/users/${ok.username}/mute`).set(auth(me)).expect(200);
      expect(await inbox(me)).toEqual([]);
    });

    it("moderation tells the author (CONTENT_REMOVED) and drops the removed post's notifications", async () => {
      const [author, reporter, mod] = await users(3);
      await withMigrationClient(async (c) => {
        await c.user.update({ where: { id: mod.id }, data: { role: 'ADMIN' } });
        await c.userAdminPermission.create({ data: { userId: mod.id, permission: 'MODERATION' } });
      });
      const p = await post(author, 'bad post');
      await like(reporter, p);
      const rep = await ctx.http
        .post('/api/v1/reports')
        .set(auth(reporter))
        .send({ targetType: 'POST', targetId: p, reason: 'SPAM' });
      expect(rep.status).toBe(201);
      await ctx.http
        .post(`/api/v1/admin/reports/${rep.body.id}/actions`)
        .set(auth(mod))
        .send({ action: 'REMOVE_TARGET' })
        .expect(200);
      const notes = await inbox(author);
      expect(notes).toHaveLength(1);
      expect(notes[0]).toMatchObject({
        type: 'CONTENT_REMOVED',
        actors: [],
        actorCount: 0,
        target: { type: 'POST', id: p, thumbUrl: null, text: null },
      });
    });
  });

  describe('settings', () => {
    it('all on by default; a switched-off type creates nothing; validation', async () => {
      const [me, b] = await users(2);
      const get = await ctx.http.get('/api/v1/me/notification-settings').set(auth(me));
      expect(get.status).toBe(200);
      expectContract(get, 'getNotificationSettings');
      expect(get.body).toEqual({ likes: true, comments: true, mentions: true, follows: true, reposts: true });
      const patch = await ctx.http
        .patch('/api/v1/me/notification-settings')
        .set(auth(me))
        .send({ likes: false });
      expect(patch.status).toBe(200);
      expectContract(patch, 'updateNotificationSettings');
      expect(patch.body).toEqual({
        likes: false,
        comments: true,
        mentions: true,
        follows: true,
        reposts: true,
      });
      const p = await post(me);
      await like(b, p);
      await comment(b, p, 'hi');
      expect((await inbox(me)).map((n) => n.type)).toEqual(['COMMENT']);
      for (const body of [{}, { likes: 'no' }, { push: true }]) {
        const bad = await ctx.http.patch('/api/v1/me/notification-settings').set(auth(me)).send(body);
        expect(bad.status).toBe(400);
        expectContract(bad, 'updateNotificationSettings');
      }
    });
  });

  describe('inbox, read and retention', () => {
    it('pages by the latest activity with a cursor bound to the caller', async () => {
      const [me, other, ...fans] = await users(5);
      for (const f of fans)
        await ctx.http.put(`/api/v1/users/${me.username}/follow`).set(auth(f)).expect(200);
      const all = await inbox(me, 1);
      expect(all.map((n) => n.actors[0]!.id)).toEqual([...fans].reverse().map((f) => f.id));
      const first = await ctx.http.get('/api/v1/notifications?limit=1').set(auth(me));
      expect(first.body.page.hasMore).toBe(true);
      const stolen = await ctx.http
        .get(`/api/v1/notifications?cursor=${encodeURIComponent(first.body.page.nextCursor)}`)
        .set(auth(other));
      expect(stolen.status).toBe(400);
      expect(stolen.body.error.details).toEqual([{ field: 'cursor', issue: 'invalid_value' }]);
    });

    it('mark read: own ids only (others ignored), or all; idempotent; validation', async () => {
      const [me, other, fan1, fan2] = await users(4);
      await ctx.http.put(`/api/v1/users/${me.username}/follow`).set(auth(fan1)).expect(200);
      await ctx.http.put(`/api/v1/users/${me.username}/follow`).set(auth(fan2)).expect(200);
      await ctx.http.put(`/api/v1/users/${other.username}/follow`).set(auth(fan1)).expect(200);
      const [n2, n1] = await inbox(me);
      const [theirs] = await inbox(other);
      const res = await ctx.http
        .post('/api/v1/notifications/read')
        .set(auth(me))
        .send({ ids: [n1!.id, theirs!.id] });
      expect(res.status).toBe(204);
      expect((await inbox(me)).map((n) => n.read)).toEqual([false, true]);
      expect((await inbox(other))[0]!.read).toBe(false);
      expect(await unread(me)).toBe(1);
      await ctx.http
        .post('/api/v1/notifications/read')
        .set(auth(me))
        .send({ ids: [n2!.id] })
        .expect(204);
      await ctx.http
        .post('/api/v1/notifications/read')
        .set(auth(me))
        .send({ ids: [n2!.id] })
        .expect(204);
      expect(await unread(me)).toBe(0);
      for (const body of [
        {},
        { ids: [] },
        { ids: ['nope'] },
        { ids: [n1!.id, n1!.id] },
        { ids: Array.from({ length: 101 }, () => randomUUID()) },
        { all: false },
        { all: true, ids: [n1!.id] },
      ]) {
        const bad = await ctx.http.post('/api/v1/notifications/read').set(auth(me)).send(body);
        expect(bad.status).toBe(400);
        expectContract(bad, 'markNotificationsRead');
      }
    });

    it('the unread count is capped at 99', async () => {
      const [me] = await users(1);
      const p = await post(me);
      await withMigrationClient((c) =>
        c.notification.createMany({
          data: Array.from({ length: 105 }, () => ({
            recipientId: me.id,
            type: 'POST_PUBLISHED' as const,
            postId: p,
          })),
        }),
      );
      expect(await unread(me)).toBe(99);
    });

    it('the sweeper deletes notifications whose latest activity is older than 30 days', async () => {
      const [me, fan1, fan2] = await users(3);
      await ctx.http.put(`/api/v1/users/${me.username}/follow`).set(auth(fan1)).expect(200);
      await ctx.http.put(`/api/v1/users/${me.username}/follow`).set(auth(fan2)).expect(200);
      const [recent, old] = await inbox(me);
      const day = 24 * 3600_000;
      await withMigrationClient(async (c) => {
        await c.notification.update({
          where: { id: old!.id },
          data: { updatedAt: new Date(Date.now() - 31 * day) },
        });
        await c.notification.update({
          where: { id: recent!.id },
          data: { updatedAt: new Date(Date.now() - 29 * day) },
        });
      });
      expect(await ctx.app.get(NotificationsService).sweep()).toBeGreaterThanOrEqual(1);
      expect((await inbox(me)).map((n) => n.id)).toEqual([recent!.id]);
    });
  });
});
