/**
 * KL-060 group 2: posts — create (drafts, scheduling, idempotency), read, edit, delete, pins and
 * the profile grid (openapi v1.5-social DRAFT, CONVENTIONS §11.2), end to end against PostgreSQL
 * + Redis with the API as the DML-only runtime role. Every response is checked against openapi.
 */
import { randomUUID } from 'node:crypto';
import sharp from 'sharp';
import type request from 'supertest';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { OBJECT_STORAGE } from '../src/modules/media/object-storage.js';
import { PostsService } from '../src/modules/posts/posts.service.js';
import { MemoryObjectStorage } from './helpers/memory-storage.js';
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

const MEDIA_ON = {
  MEDIA_UPLOADS_ENABLED: 'true',
  S3_BUCKET: 'kabso-media-test',
  S3_ACCESS_KEY_ID: 'test',
  S3_SECRET_ACCESS_KEY: 'test',
  MEDIA_PUBLIC_BASE_URL: 'https://media.example.test',
};

describe('KL-060 posts', () => {
  let ctx: TestContext;
  let storage: MemoryObjectStorage;
  let alice: TestUser;
  let bob: TestUser;
  let carol: TestUser;

  const auth = (u: TestUser) => ({ Authorization: `Bearer ${u.token}` });
  const signup = async (): Promise<TestUser> => {
    const { res } = await registerVerified(ctx);
    expect(res.status).toBe(201);
    return { id: res.body.user.id, username: res.body.user.username, token: res.body.tokens.accessToken };
  };
  const create = (u: TestUser, body: unknown, key: string = randomUUID()) =>
    ctx.http
      .post('/api/v1/posts')
      .set(auth(u))
      .set('Idempotency-Key', key)
      .send(body as object);
  const get = (u: TestUser, id: string) => ctx.http.get(`/api/v1/posts/${id}`).set(auth(u));
  const patch = (u: TestUser, id: string, body: unknown) =>
    ctx.http
      .patch(`/api/v1/posts/${id}`)
      .set(auth(u))
      .send(body as object);
  const photo = async (u: TestUser): Promise<string> => {
    const bytes = await sharp({ create: { width: 800, height: 600, channels: 3, background: '#2a6' } })
      .jpeg()
      .toBuffer();
    const slot = await ctx.http
      .post('/api/v1/media/uploads')
      .set(auth(u))
      .send({ kind: 'POST_IMAGE', contentType: 'image/jpeg', byteSize: bytes.length });
    storage.upload(slot.body.uploadUrl, bytes, 'image/jpeg');
    const done = await ctx.http.post(`/api/v1/media/uploads/${slot.body.uploadId}/complete`).set(auth(u));
    expect(done.status).toBe(200);
    return done.body.id as string;
  };

  beforeAll(async () => {
    storage = new MemoryObjectStorage();
    ctx = await createTestApp(MEDIA_ON, [{ token: OBJECT_STORAGE, value: storage }]);
    ctx.app.getHttpServer().setMaxListeners(64);
    alice = await signup();
    bob = await signup();
    carol = await signup();
  });
  afterAll(async () => ctx?.close());

  describe('create', () => {
    it('needs a UUID Idempotency-Key', async () => {
      const missing = await ctx.http.post('/api/v1/posts').set(auth(alice)).send({ text: 'hi' });
      expect(missing.status).toBe(400);
      expect(missing.body.error.details).toEqual([{ field: 'Idempotency-Key', issue: 'required' }]);
      expectContract(missing, 'createPost');
      const bad = await create(alice, { text: 'hi' }, 'not-a-uuid');
      expect(bad.status).toBe(400);
      expect(bad.body.error.details).toEqual([{ field: 'Idempotency-Key', issue: 'invalid_format' }]);
    });

    it('validates the body strictly', async () => {
      const cases: [unknown, string, string][] = [
        [{}, 'text', 'required'],
        [{ text: '   ' }, 'text', 'required'],
        [{ text: 'x'.repeat(2201) }, 'text', 'too_long'],
        [{ text: 'a‮b' }, 'text', 'invalid_format'],
        [{ text: 'hi', extra: 1 }, 'extra', 'unknown_field'],
        [{ text: 'hi', status: 'SCHEDULED' }, 'publishAt', 'required'],
        [
          { text: 'hi', publishAt: new Date(Date.now() + 3600_000).toISOString() },
          'publishAt',
          'unknown_field',
        ],
        [
          { text: 'hi', status: 'SCHEDULED', publishAt: new Date(Date.now() + 60_000).toISOString() },
          'publishAt',
          'too_small',
        ],
        [
          { text: 'hi', status: 'SCHEDULED', publishAt: new Date(Date.now() + 31 * 86400_000).toISOString() },
          'publishAt',
          'too_big',
        ],
        [{ text: 'hi', mediaIds: ['nope'] }, 'mediaIds.0', 'invalid_format'],
        [{ text: 'hi', settings: {} }, 'settings', 'too_small'],
        [{ text: 'hi', location: 'a\nb' }, 'location', 'too_long'],
      ];
      for (const [body, field, issue] of cases) {
        const res = await create(alice, body);
        expect(res.status, JSON.stringify(body)).toBe(400);
        expect(res.body.error.details, JSON.stringify(body)).toContainEqual({ field, issue });
        expectContract(res, 'createPost');
      }
    });

    it('creates a text post with hashtags and linked mentions', async () => {
      await withMigrationClient((c) =>
        c.privacySettings.create({ data: { userId: carol.id, whoCanMention: 'NOBODY' } }),
      );
      const res = await create(alice, {
        text: `  Hello #Kabso #سفر\n@${bob.username} and @${carol.username} and @nobody_here  `,
        location: ' Amman ',
        settings: { whoCanComment: 'FOLLOWERS' },
      });
      expect(res.status).toBe(201);
      expectContract(res, 'createPost');
      expect(res.body).toMatchObject({
        format: 'POST',
        text: `Hello #Kabso #سفر\n@${bob.username} and @${carol.username} and @nobody_here`,
        location: 'Amman',
        hashtags: ['kabso', 'سفر'],
        status: 'PUBLISHED',
        moderation: 'VISIBLE',
        isSelf: true,
        pinned: false,
        likeCount: 0,
        settings: { commentsEnabled: true, whoCanComment: 'FOLLOWERS', hideLikeCount: false },
        repostedBy: null,
        author: { id: alice.id, username: alice.username },
      });
      // Carol does not allow mentions; unknown names are plain text.
      expect(res.body.mentions.map((m: { username: string }) => m.username)).toEqual([bob.username]);
      expect(res.body.publishedAt).not.toBeNull();
      const seen = await get(bob, res.body.id);
      expect(seen.status).toBe(200);
      expectContract(seen, 'getPost');
      expect(seen.body.isSelf).toBe(false);
    });

    it('replays the same key and body; another body with that key is 409', async () => {
      const key = randomUUID();
      const first = await create(alice, { text: 'once' }, key);
      const again = await create(alice, { text: 'once' }, key);
      expect(again.status).toBe(201);
      expect(again.body.id).toBe(first.body.id);
      const other = await create(alice, { text: 'twice' }, key);
      expect(other.status).toBe(409);
      expect(other.body.error.code).toBe('IDEMPOTENCY_CONFLICT');
      expectContract(other, 'createPost');
      // Keys are per author: Bob may use the same key.
      expect((await create(bob, { text: 'once' }, key)).body.id).not.toBe(first.body.id);
      // Concurrent duplicates create one post.
      const k2 = randomUUID();
      const many = await Promise.all(Array.from({ length: 5 }, () => create(alice, { text: 'race' }, k2)));
      expect(new Set(many.map((r) => r.body.id as string)).size).toBe(1);
      expect(await ctx.prisma.post.count({ where: { authorId: alice.id, text: 'race' } })).toBe(1);
    });

    // D162a (v1.42-social, owner «جميعها تظهر فوراً»): was "a photo post waits for moderation";
    // photo posts are visible at once now. A PENDING post (a future provider or an admin hold)
    // is still visible to its author only.
    it('a photo post is visible at once; a PENDING post only to its author', async () => {
      const media = await photo(alice);
      const res = await create(alice, { mediaIds: [media] });
      expect(res.status).toBe(201);
      expectContract(res, 'createPost');
      expect(res.body.moderation).toBe('VISIBLE');
      expect(res.body.media).toHaveLength(1);
      expect(res.body.media[0].id).toBe(media);
      expect(res.body.text).toBe('');
      expect((await get(alice, res.body.id)).status).toBe(200);
      expect((await get(bob, res.body.id)).status).toBe(200);
      await withMigrationClient((c) =>
        c.post.update({ where: { id: res.body.id }, data: { moderation: 'PENDING' } }),
      );
      const held = await get(alice, res.body.id);
      expect(held.status).toBe(200);
      expect(held.body.moderation).toBe('PENDING');
      expect((await get(bob, res.body.id)).status).toBe(404);
      // The asset is attached once only.
      const reuse = await create(alice, { text: 'again', mediaIds: [media] });
      expect(reuse.status).toBe(400);
      expect(reuse.body.error.details).toEqual([{ field: 'mediaIds', issue: 'invalid_value' }]);
      // Another user's asset is not attachable.
      const bobsMedia = await photo(bob);
      expect((await create(alice, { mediaIds: [bobsMedia] })).status).toBe(400);
      expect(await ctx.prisma.mediaAsset.findUniqueOrThrow({ where: { id: bobsMedia } })).toMatchObject({
        attachedAt: null,
      });
    });
  });

  describe('visibility', () => {
    it('private accounts: followers only; blocks hide both ways', async () => {
      const dave = await signup();
      const post = await create(dave, { text: 'private thoughts' });
      await withMigrationClient((c) =>
        c.userSettings.update({ where: { userId: dave.id }, data: { isPrivate: true } }),
      );
      expect((await get(bob, post.body.id)).status).toBe(404);
      await withMigrationClient((c) =>
        c.follow.create({ data: { followerId: bob.id, followeeId: dave.id } }),
      );
      expect((await get(bob, post.body.id)).status).toBe(200);
      await withMigrationClient((c) =>
        c.userBlock.create({ data: { blockerId: dave.id, blockedId: bob.id } }),
      );
      expect((await get(bob, post.body.id)).status).toBe(404);
      const bobs = await create(bob, { text: 'from bob' });
      expect((await get(dave, bobs.body.id)).status).toBe(404);
      expect((await get(dave, post.body.id)).status).toBe(200);
    });

    it('malformed and unknown ids are 404', async () => {
      for (const id of ['x', randomUUID()]) {
        const res = await get(alice, id);
        expect(res.status).toBe(404);
        expectContract(res, 'getPost');
      }
    });
  });

  describe('drafts and scheduling', () => {
    it('drafts and scheduled posts are the author’s only, listed in their order', async () => {
      const d1 = await create(alice, { text: 'draft 1', status: 'DRAFT' });
      const d2 = await create(alice, { text: 'draft 2', status: 'DRAFT' });
      expect(d1.body).toMatchObject({ status: 'DRAFT', publishedAt: null, publishAt: null });
      expect((await get(bob, d1.body.id)).status).toBe(404);
      const later = new Date(Date.now() + 2 * 3600_000).toISOString();
      const sooner = new Date(Date.now() + 3600_000).toISOString();
      const s1 = await create(alice, { text: 'later', status: 'SCHEDULED', publishAt: later });
      const s2 = await create(alice, { text: 'sooner', status: 'SCHEDULED', publishAt: sooner });
      expect(s1.body.publishAt).toBe(later);

      const drafts = await ctx.http.get('/api/v1/me/posts?status=DRAFT').set(auth(alice));
      expect(drafts.status).toBe(200);
      expectContract(drafts, 'listMyPosts');
      expect(drafts.body.data.map((p: { id: string }) => p.id)).toEqual([d2.body.id, d1.body.id]);
      const scheduled = await ctx.http.get('/api/v1/me/posts?status=SCHEDULED&limit=1').set(auth(alice));
      expect(scheduled.body.data.map((p: { id: string }) => p.id)).toEqual([s2.body.id]);
      expect(scheduled.body.page.hasMore).toBe(true);
      const next = await ctx.http
        .get(`/api/v1/me/posts?status=SCHEDULED&limit=1&cursor=${scheduled.body.page.nextCursor}`)
        .set(auth(alice));
      expect(next.body.data.map((p: { id: string }) => p.id)).toEqual([s1.body.id]);
      // A cursor is bound to its list and caller.
      const stolen = await ctx.http
        .get(`/api/v1/me/posts?status=SCHEDULED&cursor=${scheduled.body.page.nextCursor}`)
        .set(auth(bob));
      expect(stolen.status).toBe(400);
      expect(stolen.body.error.details).toEqual([{ field: 'cursor', issue: 'invalid_value' }]);
      const bad = await ctx.http.get('/api/v1/me/posts?status=PUBLISHED').set(auth(alice));
      expect(bad.status).toBe(400);
      expectContract(bad, 'listMyPosts');

      // Due posts are published at their publish time.
      await withMigrationClient((c) =>
        c.post.update({ where: { id: s2.body.id }, data: { publishAt: new Date(Date.now() - 1000) } }),
      );
      expect(await ctx.app.get(PostsService).publishDue()).toBe(1);
      const published = await get(bob, s2.body.id);
      expect(published.status).toBe(200);
      expect(published.body.status).toBe('PUBLISHED');
    });
  });

  describe('edit and delete', () => {
    it('only the author edits; text changes re-parse tags and mark the post edited', async () => {
      const post = await create(alice, { text: 'first #one' });
      const stranger = await patch(bob, post.body.id, { text: 'hacked' });
      expect(stranger.status).toBe(404);
      expectContract(stranger, 'updatePost');
      const edited = await patch(alice, post.body.id, {
        text: 'second #two',
        settings: { hideLikeCount: true },
      });
      expect(edited.status).toBe(200);
      expectContract(edited, 'updatePost');
      expect(edited.body).toMatchObject({ text: 'second #two', hashtags: ['two'], likeCount: 0 });
      expect(edited.body.editedAt).not.toBeNull();
      // Others no longer see the like count.
      expect((await get(bob, post.body.id)).body.likeCount).toBeNull();
      // A published post cannot go back to draft; empty patches are refused.
      const back = await patch(alice, post.body.id, { status: 'DRAFT' });
      expect(back.status).toBe(400);
      expect(back.body.error.details).toEqual([{ field: 'status', issue: 'invalid_value' }]);
      expect((await patch(alice, post.body.id, {})).status).toBe(400);
      expect((await patch(alice, post.body.id, { text: '' })).status).toBe(400);
    });

    it('a draft is published by PATCH (not marked edited)', async () => {
      const draft = await create(alice, { text: 'soon', status: 'DRAFT' });
      const pub = await patch(alice, draft.body.id, { status: 'PUBLISHED', text: 'now' });
      expect(pub.body).toMatchObject({ status: 'PUBLISHED', text: 'now', editedAt: null });
      expect(pub.body.publishedAt).not.toBeNull();
    });

    it('only the author deletes; the post is gone for everyone', async () => {
      const post = await create(alice, { text: 'bye' });
      const stranger = await ctx.http.delete(`/api/v1/posts/${post.body.id}`).set(auth(bob));
      expect(stranger.status).toBe(404);
      const del = await ctx.http.delete(`/api/v1/posts/${post.body.id}`).set(auth(alice));
      expect(del.status).toBe(204);
      expectContract(del, 'deletePost');
      expect((await get(alice, post.body.id)).status).toBe(404);
      expect((await get(bob, post.body.id)).status).toBe(404);
      expect((await ctx.http.delete(`/api/v1/posts/${post.body.id}`).set(auth(alice))).status).toBe(404);
      expect((await patch(alice, post.body.id, { text: 'zombie' })).status).toBe(404);
    });
  });

  describe('pins and the profile grid', () => {
    it('pins up to 3 published posts, concurrently safe, pinned first in the grid', async () => {
      const erin = await signup();
      const ids: string[] = [];
      for (let i = 0; i < 6; i += 1) ids.push((await create(erin, { text: `post ${i}` })).body.id as string);
      const results = await Promise.all(
        ids.slice(0, 4).map((id) => ctx.http.put(`/api/v1/posts/${id}/pin`).set(auth(erin))),
      );
      expect(results.filter((r) => r.status === 200)).toHaveLength(3);
      const refused = results.find((r) => r.status === 409)!;
      expect(refused.body.error.code).toBe('PIN_LIMIT_REACHED');
      expectContract(refused, 'pinPost');
      const pinnedIds = results.filter((r) => r.status === 200).map((r) => r.body.id as string);
      // Idempotent; others cannot pin; drafts cannot be pinned.
      const again = await ctx.http.put(`/api/v1/posts/${pinnedIds[0]}/pin`).set(auth(erin));
      expect(again.status).toBe(200);
      expectContract(again, 'pinPost');
      expect(again.body.pinned).toBe(true);
      expect((await ctx.http.put(`/api/v1/posts/${ids[5]}/pin`).set(auth(alice))).status).toBe(404);
      const draft = await create(erin, { text: 'draft', status: 'DRAFT' });
      expect((await ctx.http.put(`/api/v1/posts/${draft.body.id}/pin`).set(auth(erin))).status).toBe(404);

      // Grid: pinned first (first page only), then the rest newest first, no repeats.
      const seen: string[] = [];
      let cursor: string | null = null;
      for (let page = 0; page < 5; page += 1) {
        const res: request.Response = await ctx.http
          .get(`/api/v1/users/${erin.username}/posts?limit=2${cursor ? `&cursor=${cursor}` : ''}`)
          .set(auth(bob));
        expect(res.status).toBe(200);
        expectContract(res, 'listUserPosts');
        seen.push(...res.body.data.map((p: { id: string }) => p.id));
        cursor = res.body.page.nextCursor;
        if (!res.body.page.hasMore) break;
      }
      expect(seen.slice(0, 3).sort()).toEqual([...pinnedIds].sort());
      expect(new Set(seen).size).toBe(seen.length);
      expect(seen.sort()).toEqual([...ids].sort());

      const unpin = await ctx.http.delete(`/api/v1/posts/${pinnedIds[0]}/pin`).set(auth(erin));
      expect(unpin.status).toBe(200);
      expectContract(unpin, 'unpinPost');
      expect(unpin.body.pinned).toBe(false);
      expect((await ctx.http.put(`/api/v1/posts/${ids[3]}/pin`).set(auth(erin))).status).toBe(200);
    });

    it('the grid follows profile visibility', async () => {
      const frank = await signup();
      await create(frank, { text: 'secret' });
      await withMigrationClient((c) =>
        c.userSettings.update({ where: { userId: frank.id }, data: { isPrivate: true } }),
      );
      const res = await ctx.http.get(`/api/v1/users/${frank.username}/posts`).set(auth(bob));
      expect(res.status).toBe(404);
      expectContract(res, 'listUserPosts');
      expect(
        (await ctx.http.get(`/api/v1/users/${frank.username}/posts`).set(auth(frank))).body.data,
      ).toHaveLength(1);
      expect((await ctx.http.get('/api/v1/users/no_such_user_x/posts').set(auth(bob))).status).toBe(404);
      const bad = await ctx.http.get(`/api/v1/users/${frank.username}/posts?limit=0`).set(auth(frank));
      expect(bad.status).toBe(400);
    });
  });
});
