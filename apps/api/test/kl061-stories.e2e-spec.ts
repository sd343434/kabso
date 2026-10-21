/**
 * KL-061 / CP-008 (D91): photo stories (openapi v1.5-social DRAFT, CONVENTIONS §11.9), end to end
 * against PostgreSQL + Redis with the API as the DML-only runtime role. Object storage is the
 * in-memory test double behind the ObjectStorage port.
 */
import { randomUUID } from 'node:crypto';
import sharp from 'sharp';
import type request from 'supertest';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { OBJECT_STORAGE } from '../src/modules/media/object-storage.js';
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

const MEDIA_ON = {
  MEDIA_UPLOADS_ENABLED: 'true',
  S3_BUCKET: 'kabso-media-test',
  S3_ACCESS_KEY_ID: 'test',
  S3_SECRET_ACCESS_KEY: 'test',
  MEDIA_PUBLIC_BASE_URL: 'https://media.example.test',
};

describe('CP-008 stories contract coverage', () => {
  it('openapi declares the eight story operations', () => {
    expect(
      operations()
        .filter((o) => o.path.includes('stories'))
        .map((o) => o.operationId)
        .sort(),
    ).toEqual([
      'createStory',
      'deleteStory',
      'getStory',
      'listStoryArchive',
      'listStoryTray',
      'listStoryViewers',
      'listUserStories',
      'markStorySeen',
    ]);
  });
});

describe('CP-008 stories', () => {
  let ctx: TestContext;
  let storage: MemoryObjectStorage;
  const auth = (u: TestUser) => ({ Authorization: `Bearer ${u.token}` });
  const signup = async (): Promise<TestUser> => {
    const { res } = await registerVerified(ctx);
    expect(res.status).toBe(201);
    return { id: res.body.user.id, username: res.body.user.username, token: res.body.tokens.accessToken };
  };
  const follow = (a: TestUser, b: TestUser) =>
    ctx.http.put(`/api/v1/users/${b.username}/follow`).set(auth(a));
  const upload = async (
    u: TestUser,
    kind: 'STORY_IMAGE' | 'POST_IMAGE' = 'STORY_IMAGE',
    w = 1440,
    h = 2560,
  ) => {
    const bytes = await sharp({
      create: { width: w, height: h, channels: 3, background: { r: 200, g: 90, b: 40 } },
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
    return done.body as { id: string; url: string; width: number; height: number };
  };
  const story = async (u: TestUser, text?: string): Promise<request.Response> => {
    const media = await upload(u);
    return ctx.http
      .post('/api/v1/stories')
      .set(auth(u))
      .set('Idempotency-Key', randomUUID())
      .send({ mediaId: media.id, ...(text !== undefined ? { text } : {}) });
  };
  const storyId = async (u: TestUser, text?: string): Promise<string> => {
    const res = await story(u, text);
    expect(res.status).toBe(201);
    return res.body.id as string;
  };
  /** Every tray entry, walking all pages with `limit`. */
  const trayAll = async (u: TestUser, limit = 50) => {
    const items: { user: { id: string }; hasUnseen: boolean; storyCount: number }[] = [];
    let cursor: string | null = null;
    for (let i = 0; i < 50; i += 1) {
      const res: request.Response = await ctx.http
        .get(`/api/v1/feed/stories?limit=${limit}${cursor ? `&cursor=${encodeURIComponent(cursor)}` : ''}`)
        .set(auth(u));
      expect(res.status).toBe(200);
      expectContract(res, 'listStoryTray');
      items.push(...res.body.data);
      cursor = res.body.page.nextCursor;
      if (!res.body.page.hasMore) break;
    }
    return items;
  };

  beforeAll(async () => {
    storage = new MemoryObjectStorage();
    ctx = await createTestApp(MEDIA_ON, [{ token: OBJECT_STORAGE, value: storage }]);
    ctx.app.getHttpServer().setMaxListeners(64);
  });
  afterAll(async () => ctx?.close());

  describe('media', () => {
    it('a STORY_IMAGE keeps up to 1 920 px; kinds attach only to their own target', async () => {
      const u = await signup();
      const photo = await upload(u, 'STORY_IMAGE', 1440, 2560);
      expect(photo.url).toMatch(/\/1920\.webp$/);
      expect([photo.width, photo.height]).toEqual([1080, 1920]);
      const asPost = await ctx.http
        .post('/api/v1/posts')
        .set(auth(u))
        .set('Idempotency-Key', randomUUID())
        .send({ mediaIds: [photo.id] });
      expect(asPost.status).toBe(400);
      expect(asPost.body.error.details).toEqual([{ field: 'mediaIds', issue: 'invalid_value' }]);
      const postPhoto = await upload(u, 'POST_IMAGE', 1440, 2560);
      expect(postPhoto.url).toMatch(/\/1080\.webp$/);
      const asStory = await ctx.http
        .post('/api/v1/stories')
        .set(auth(u))
        .set('Idempotency-Key', randomUUID())
        .send({ mediaId: postPhoto.id });
      expect(asStory.status).toBe(400);
      expect(asStory.body.error.details).toEqual([{ field: 'mediaId', issue: 'invalid_value' }]);
      expectContract(asStory, 'createStory');
    });
  });

  describe('create and read', () => {
    it('needs a UUID Idempotency-Key; a retry returns the same story; another body → 409', async () => {
      const u = await signup();
      const media = await upload(u);
      const missing = await ctx.http.post('/api/v1/stories').set(auth(u)).send({ mediaId: media.id });
      expect(missing.status).toBe(400);
      expect(missing.body.error.details).toEqual([{ field: 'Idempotency-Key', issue: 'required' }]);
      const key = randomUUID();
      const first = await ctx.http
        .post('/api/v1/stories')
        .set(auth(u))
        .set('Idempotency-Key', key)
        .send({ mediaId: media.id, text: 'hi' });
      expect(first.status).toBe(201);
      expectContract(first, 'createStory');
      const again = await ctx.http
        .post('/api/v1/stories')
        .set(auth(u))
        .set('Idempotency-Key', key)
        .send({ mediaId: media.id, text: 'hi' });
      expect(again.status).toBe(201);
      expect(again.body.id).toBe(first.body.id);
      const other = await ctx.http
        .post('/api/v1/stories')
        .set(auth(u))
        .set('Idempotency-Key', key)
        .send({ mediaId: media.id, text: 'changed' });
      expect(other.status).toBe(409);
      expect(other.body.error.code).toBe('IDEMPOTENCY_CONFLICT');
    });

    it('text: at most 200 characters and 3 line breaks; mentions are linked', async () => {
      const [u, friend] = [await signup(), await signup()];
      expect((await story(u, 'x'.repeat(201))).status).toBe(400);
      expect((await story(u, 'a\nb\nc\nd\ne')).status).toBe(400);
      const res = await story(u, `  with @${friend.username} #tag  `);
      expect(res.status).toBe(201);
      expect(res.body.text).toBe(`with @${friend.username} #tag`);
      expect(res.body.mentions.map((m: { id: string }) => m.id)).toEqual([friend.id]);
      expect(res.body).toMatchObject({ isSelf: true, viewerHasSeen: true, viewCount: 0 });
      expect(new Date(res.body.expiresAt).getTime() - new Date(res.body.createdAt).getTime()).toBe(
        24 * 3600_000,
      );
    });

    it('visible at once to others (D91); a private author only to followers; a block hides it', async () => {
      const [author, stranger] = [await signup(), await signup()];
      const id = await storyId(author, 'hello');
      const seen = await ctx.http.get(`/api/v1/stories/${id}`).set(auth(stranger));
      expect(seen.status).toBe(200);
      expectContract(seen, 'getStory');
      expect(seen.body).toMatchObject({ isSelf: false, viewerHasSeen: false, viewCount: null });
      const list = await ctx.http.get(`/api/v1/users/${author.username}/stories`).set(auth(stranger));
      expect(list.status).toBe(200);
      expectContract(list, 'listUserStories');
      expect(list.body.data.map((s: { id: string }) => s.id)).toEqual([id]);

      await withMigrationClient((c) =>
        c.userSettings.upsert({
          where: { userId: author.id },
          create: { userId: author.id, isPrivate: true },
          update: { isPrivate: true },
        }),
      );
      expect((await ctx.http.get(`/api/v1/stories/${id}`).set(auth(stranger))).status).toBe(404);
      const hidden = await ctx.http.get(`/api/v1/users/${author.username}/stories`).set(auth(stranger));
      expect(hidden.status).toBe(404);
      expectContract(hidden, 'listUserStories');
      await withMigrationClient((c) =>
        c.follow.create({ data: { followerId: stranger.id, followeeId: author.id } }),
      );
      expect((await ctx.http.get(`/api/v1/stories/${id}`).set(auth(stranger))).status).toBe(200);

      expect((await ctx.http.put(`/api/v1/users/${stranger.username}/block`).set(auth(author))).status).toBe(
        200,
      );
      expect((await ctx.http.get(`/api/v1/stories/${id}`).set(auth(stranger))).status).toBe(404);
      expect((await ctx.http.put(`/api/v1/stories/${id}/seen`).set(auth(stranger))).status).toBe(404);
    });

    it("a user's active stories come oldest first", async () => {
      const [author, viewer] = [await signup(), await signup()];
      const a = await storyId(author, 'one');
      const b = await storyId(author, 'two');
      const res = await ctx.http.get(`/api/v1/users/${author.username}/stories`).set(auth(viewer));
      expect(res.body.data.map((s: { id: string }) => s.id)).toEqual([a, b]);
    });
  });

  describe('tray', () => {
    it('me first, then unseen followed accounts, then seen ones; muted and not followed left out', async () => {
      const me = await signup();
      const seenOne = await signup();
      const unseenOld = await signup();
      const unseenNew = await signup();
      const muted = await signup();
      const notFollowed = await signup();
      for (const u of [seenOne, unseenOld, unseenNew, muted]) expect((await follow(me, u)).status).toBe(200);
      const s1 = await storyId(seenOne);
      await storyId(unseenOld);
      await storyId(unseenNew);
      await storyId(muted);
      await storyId(notFollowed);
      await storyId(me);
      expect((await ctx.http.put(`/api/v1/stories/${s1}/seen`).set(auth(me))).status).toBe(204);
      expect((await ctx.http.put(`/api/v1/users/${muted.username}/mute`).set(auth(me))).status).toBe(200);

      const expected = [me.id, unseenNew.id, unseenOld.id, seenOne.id];
      const all = await trayAll(me);
      expect(all.map((i) => i.user.id)).toEqual(expected);
      expect(all.map((i) => i.hasUnseen)).toEqual([false, true, true, false]);
      // One per page walks the same order once.
      expect((await trayAll(me, 1)).map((i) => i.user.id)).toEqual(expected);

      const foreign = await ctx.http.get('/api/v1/feed/stories?cursor=abc.def').set(auth(me));
      expect(foreign.status).toBe(400);
      expectContract(foreign, 'listStoryTray');
    });
  });

  describe('seen and viewers', () => {
    it('seen is idempotent and never counts the author; viewers are for the author only', async () => {
      const [author, v1, v2] = [await signup(), await signup(), await signup()];
      const id = await storyId(author);
      const first = await ctx.http.put(`/api/v1/stories/${id}/seen`).set(auth(v1));
      expect(first.status).toBe(204);
      expectContract(first, 'markStorySeen');
      expect((await ctx.http.put(`/api/v1/stories/${id}/seen`).set(auth(v1))).status).toBe(204);
      expect((await ctx.http.put(`/api/v1/stories/${id}/seen`).set(auth(v2))).status).toBe(204);
      expect((await ctx.http.put(`/api/v1/stories/${id}/seen`).set(auth(author))).status).toBe(204);
      const mine = await ctx.http.get(`/api/v1/stories/${id}`).set(auth(author));
      expect(mine.body.viewCount).toBe(2);
      expect((await ctx.http.get(`/api/v1/stories/${id}`).set(auth(v1))).body.viewerHasSeen).toBe(true);

      const page = await ctx.http.get(`/api/v1/stories/${id}/viewers?limit=1`).set(auth(author));
      expect(page.status).toBe(200);
      expectContract(page, 'listStoryViewers');
      expect(page.body.data.map((u: { id: string }) => u.id)).toEqual([v2.id]);
      const next = await ctx.http
        .get(`/api/v1/stories/${id}/viewers?limit=1&cursor=${encodeURIComponent(page.body.page.nextCursor)}`)
        .set(auth(author));
      expect(next.body.data.map((u: { id: string }) => u.id)).toEqual([v1.id]);
      const other = await ctx.http.get(`/api/v1/stories/${id}/viewers`).set(auth(v1));
      expect(other.status).toBe(404);
      expectContract(other, 'listStoryViewers');

      await withMigrationClient((c) =>
        c.story.update({ where: { id }, data: { createdAt: new Date(Date.now() - 49 * 3600_000) } }),
      );
      expect((await ctx.http.get(`/api/v1/stories/${id}/viewers`).set(auth(author))).status).toBe(404);
    });
  });

  describe('expiry, archive and delete', () => {
    it('an expired story leaves every list but the archive; delete removes it everywhere', async () => {
      const [author, viewer] = [await signup(), await signup()];
      expect((await follow(viewer, author)).status).toBe(200);
      const old = await storyId(author, 'yesterday');
      const fresh = await storyId(author, 'today');
      await withMigrationClient((c) =>
        c.story.update({
          where: { id: old },
          data: {
            createdAt: new Date(Date.now() - 25 * 3600_000),
            expiresAt: new Date(Date.now() - 3600_000),
          },
        }),
      );
      expect((await ctx.http.get(`/api/v1/stories/${old}`).set(auth(viewer))).status).toBe(404);
      expect((await ctx.http.put(`/api/v1/stories/${old}/seen`).set(auth(viewer))).status).toBe(404);
      expect((await ctx.http.get(`/api/v1/stories/${old}`).set(auth(author))).status).toBe(200);
      const list = await ctx.http.get(`/api/v1/users/${author.username}/stories`).set(auth(viewer));
      expect(list.body.data.map((s: { id: string }) => s.id)).toEqual([fresh]);
      const tray = await trayAll(viewer);
      expect(tray.find((i) => i.user.id === author.id)?.storyCount).toBe(1);

      const archive = await ctx.http.get('/api/v1/me/stories/archive').set(auth(author));
      expect(archive.status).toBe(200);
      expectContract(archive, 'listStoryArchive');
      expect(archive.body.data.map((s: { id: string }) => s.id)).toEqual([fresh, old]);
      expect((await ctx.http.get('/api/v1/me/stories/archive').set(auth(viewer))).body.data).toEqual([]);

      const notMine = await ctx.http.delete(`/api/v1/stories/${fresh}`).set(auth(viewer));
      expect(notMine.status).toBe(404);
      expectContract(notMine, 'deleteStory');
      const del = await ctx.http.delete(`/api/v1/stories/${fresh}`).set(auth(author));
      expect(del.status).toBe(204);
      expect((await ctx.http.delete(`/api/v1/stories/${fresh}`).set(auth(author))).status).toBe(404);
      expect((await ctx.http.get(`/api/v1/stories/${fresh}`).set(auth(author))).status).toBe(404);
      const after = await ctx.http.get('/api/v1/me/stories/archive').set(auth(author));
      expect(after.body.data.map((s: { id: string }) => s.id)).toEqual([old]);
      expect((await trayAll(viewer)).some((i) => i.user.id === author.id)).toBe(false);
    });
  });

  describe('reports', () => {
    it('a story can be reported (not your own); REMOVE_TARGET removes it everywhere', async () => {
      const [author, reporter, mod] = [await signup(), await signup(), await signup()];
      await withMigrationClient(async (c) => {
        await c.user.update({ where: { id: mod.id }, data: { role: 'ADMIN' } });
        await c.userAdminPermission.create({ data: { userId: mod.id, permission: 'MODERATION' } });
      });
      const id = await storyId(author, 'bad');
      const own = await ctx.http
        .post('/api/v1/reports')
        .set(auth(author))
        .send({ targetType: 'STORY', targetId: id, reason: 'SPAM' });
      expect(own.status).toBe(400);
      const rep = await ctx.http
        .post('/api/v1/reports')
        .set(auth(reporter))
        .send({ targetType: 'STORY', targetId: id, reason: 'NUDITY' });
      expect(rep.status).toBe(201);
      expectContract(rep, 'createReport');
      expect(rep.body).toMatchObject({ targetType: 'STORY', targetId: id, status: 'OPEN' });
      const repeat = await ctx.http
        .post('/api/v1/reports')
        .set(auth(reporter))
        .send({ targetType: 'STORY', targetId: id, reason: 'NUDITY' });
      expect(repeat.status).toBe(200);
      expect(repeat.body.id).toBe(rep.body.id);

      const act = await ctx.http
        .post(`/api/v1/admin/reports/${rep.body.id}/actions`)
        .set(auth(mod))
        .send({ action: 'REMOVE_TARGET' });
      expect(act.status).toBe(200);
      expectContract(act, 'actOnReport');
      expect(act.body).toMatchObject({ status: 'ACTIONED', targetType: 'STORY' });
      expect((await ctx.http.get(`/api/v1/stories/${id}`).set(auth(reporter))).status).toBe(404);
      expect((await ctx.http.get(`/api/v1/stories/${id}`).set(auth(author))).status).toBe(404);
      expect((await ctx.http.get('/api/v1/me/stories/archive').set(auth(author))).body.data).toEqual([]);
      const audit = await withMigrationClient((c) =>
        c.auditLog.findFirst({ where: { targetType: 'story', targetId: id } }),
      );
      expect(audit).not.toBeNull();
    });
  });
});
