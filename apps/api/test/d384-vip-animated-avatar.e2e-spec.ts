/**
 * D384 (owner 2026-11-12: «انتبه جيداً لطريقة الصورة شخصية» — an animated cut-out clip as a VIP perk; contract
 * v1.136-social, CONVENTIONS §10.173): the VIP «صورة متحركة». The strip upload and its limits, the perk gate (holder
 * versus non-holder, inherited from a lower tier, the end of the VIP and its renewal, the perk switched off), set and
 * clear, blocks either way, and the panel's removal (notification, audit, files). End to end against PostgreSQL + Redis
 * with the API as the DML-only runtime role.
 */
import sharp from 'sharp';
import { afterAll, beforeAll, describe, expect, it, vi } from 'vitest';
import { OBJECT_STORAGE } from '../src/modules/media/object-storage.js';
import { panel, type Admin } from './helpers/admin-panel.js';
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

const BASE = 'https://media.example.test';
const ADMIN_KEY = 'admin-totp-test-key-0123456789-abcdefghijklmnop';
const VIP1 = '01a25200-0000-7000-8000-000000000001';
const VIP2 = '01a25200-0000-7000-8000-000000000384';
const DAY = 86_400_000;

/**
 * A synthetic strip (no real face): [frames] square frames of [side] px, a coloured disc moving on a transparent
 * background; [alpha] false gives an RGB strip without an alpha channel.
 */
async function strip(side: number, frames: number, alpha = true, height = side * frames): Promise<Buffer> {
  const channels = alpha ? 4 : 3;
  const raw = Buffer.alloc(side * height * channels);
  for (let y = 0; y < height; y += 1) {
    const f = Math.floor(y / side);
    for (let x = 0; x < side; x += 1) {
      const i = (y * side + x) * channels;
      const dx = x - side / 2 - f;
      const dy = (y % side) - side / 2;
      const inside = dx * dx + dy * dy < (side * side) / 9;
      raw[i] = 200;
      raw[i + 1] = 120 + ((f * 5) % 100);
      raw[i + 2] = 60;
      if (alpha) raw[i + 3] = inside ? 255 : 0;
    }
  }
  return sharp(raw, { raw: { width: side, height, channels } })
    .png()
    .toBuffer();
}

describe('D384 contract coverage', () => {
  it('openapi v1.136-social declares the set / remove operations and the panel removal', () => {
    expect(
      operations()
        .filter(
          (o) =>
            o.path === '/api/v1/me/animated-avatar' ||
            o.path === '/api/v1/admin/users/{userId}/animated-avatar/remove',
        )
        .map((o) => `${o.operationId} ${o.method.toUpperCase()}`)
        .sort(),
    ).toEqual([
      'removeAdminUserAnimatedAvatar POST',
      'removeMyAnimatedAvatar DELETE',
      'setMyAnimatedAvatar PUT',
    ]);
  });
});

describe('D384 VIP animated picture', { timeout: 180_000 }, () => {
  let storage: MemoryObjectStorage;
  let ctx: TestContext;
  const p = panel(() => ctx);
  let owner: Admin;

  const auth = (u: TestUser) => ({ Authorization: `Bearer ${u.token}` });
  const keyOf = (url: string) => url.replace(`${BASE}/`, '');
  const signup = async (): Promise<TestUser> => {
    const { res } = await registerVerified(ctx);
    expect(res.status).toBe(201);
    return { id: res.body.user.id, username: res.body.user.username, token: res.body.tokens.accessToken };
  };
  const slot = (u: TestUser, body: Record<string, unknown>) =>
    ctx.http.post('/api/v1/media/uploads').set(auth(u)).send(body);
  /** Uploads [bytes] as ANIMATED_AVATAR and completes it; returns the `complete` response. */
  const send = async (u: TestUser, bytes: Buffer) => {
    const s = await slot(u, { kind: 'ANIMATED_AVATAR', contentType: 'image/png', byteSize: bytes.length });
    expect(s.status, JSON.stringify(s.body)).toBe(201);
    expectContract(s, 'createMediaUpload');
    expect(storage.upload(s.body.uploadUrl, bytes, 'image/png')).toBe(true);
    return ctx.http.post(`/api/v1/media/uploads/${s.body.uploadId}/complete`).set(auth(u));
  };
  const upload = async (u: TestUser, side = 96, frames = 4) => {
    const done = await send(u, await strip(side, frames));
    expect(done.status, JSON.stringify(done.body)).toBe(200);
    expectContract(done, 'completeMediaUpload');
    return done.body as { id: string; url: string; thumbUrl: string; width: number; height: number };
  };
  const put = async (u: TestUser, body: unknown) => {
    const res = await ctx.http
      .put('/api/v1/me/animated-avatar')
      .set(auth(u))
      .send(body as object);
    expectContract(res, 'setMyAnimatedAvatar');
    return res;
  };
  const remove = async (u: TestUser) => {
    const res = await ctx.http.delete('/api/v1/me/animated-avatar').set(auth(u));
    expectContract(res, 'removeMyAnimatedAvatar');
    return res;
  };
  const profileOf = async (viewer: TestUser, of: TestUser) => {
    const res = await ctx.http.get(`/api/v1/users/${of.username}`).set(auth(viewer));
    expect(res.status).toBe(200);
    expectContract(res, 'getPublicProfile');
    return res.body as { animatedAvatar?: { url: string; stillUrl: string; width: number; height: number } };
  };
  /** Makes [u] a member of [tierId] until [days] from now (negative: ended). */
  const member = (u: TestUser, tierId: string, days = 30) =>
    withMigrationClient((db) =>
      db.vipMembership.upsert({
        where: { userId: u.id },
        create: {
          userId: u.id,
          tierId,
          startedAt: new Date(Date.now() - 40 * DAY),
          expiresAt: new Date(Date.now() + days * DAY),
        },
        update: {
          tierId,
          startedAt: new Date(Date.now() - 40 * DAY),
          expiresAt: new Date(Date.now() + days * DAY),
        },
      }),
    );
  /** VIP 1's ANIMATED_AVATAR perk on or off (VIP 2 holds it by inheritance). */
  const perk = (enabled: boolean) =>
    withMigrationClient((db) =>
      db.vipTierPerk.updateMany({ where: { tierId: VIP1, code: 'ANIMATED_AVATAR' }, data: { enabled } }),
    );

  beforeAll(async () => {
    vi.useFakeTimers({ toFake: ['Date'], now: p.start() });
    storage = new MemoryObjectStorage();
    ctx = await createTestApp(
      {
        MEDIA_UPLOADS_ENABLED: 'true',
        S3_BUCKET: 'kabso-media-test',
        S3_ACCESS_KEY_ID: 'test',
        S3_SECRET_ACCESS_KEY: 'test',
        MEDIA_PUBLIC_BASE_URL: BASE,
        RATE_LIMIT_MEDIA_UPLOAD_USER: '1000/3600',
        RATE_LIMIT_AVATAR_USER: '1000/3600',
        ADMIN_TOTP_KEY: ADMIN_KEY,
        ADMIN_SESSION_IDLE_SECONDS: '86400',
        ADMIN_SESSION_MAX_SECONDS: '604800',
        RATE_LIMIT_ADMIN_LOGIN_IP: '10000/900',
        RATE_LIMIT_ADMIN_IP: '10000/900',
      },
      [{ token: OBJECT_STORAGE, value: storage }],
    );
    owner = await p.makeAdmin(['OWNER']);
    // VIP 1 holds the perk (a tick only); VIP 2, above it, inherits it (D258).
    await withMigrationClient(async (db) => {
      await db.vipTierPerk.create({
        data: {
          tierId: VIP1,
          code: 'ANIMATED_AVATAR',
          titleAr: 'صورة متحركة',
          titleEn: 'Animated picture',
          sortOrder: 20,
          enabled: true,
        },
      });
      await db.vipTier.create({
        data: {
          id: VIP2,
          code: 'VIP_2',
          nameAr: 'في آي بي 2',
          nameEn: 'VIP 2',
          sortOrder: 2,
          color: '#1E2A44',
          priceCoins: 2_000_000n,
          durationDays: 30,
          enabled: true,
        },
      });
    });
  });
  afterAll(async () => {
    await ctx?.close();
    vi.useRealTimers();
  });

  describe('the upload', () => {
    it('takes a PNG only, at most 8 MiB', async () => {
      const u = await signup();
      const jpeg = await slot(u, { kind: 'ANIMATED_AVATAR', contentType: 'image/jpeg', byteSize: 1000 });
      expect(jpeg.status).toBe(400);
      expect(jpeg.body.error.details).toEqual([{ field: 'contentType', issue: 'invalid_value' }]);
      const big = await slot(u, {
        kind: 'ANIMATED_AVATAR',
        contentType: 'image/png',
        byteSize: 8 * 1024 * 1024 + 1,
      });
      expect(big.status).toBe(400);
      expect(big.body.error.details).toEqual([{ field: 'byteSize', issue: 'too_big' }]);
      const max = await slot(u, {
        kind: 'ANIMATED_AVATAR',
        contentType: 'image/png',
        byteSize: 8 * 1024 * 1024,
      });
      expect(max.status).toBe(201);
    });

    it('re-encodes a strip into a looping animated WebP with alpha and a still of the first frame', async () => {
      const u = await signup();
      const asset = await upload(u, 96, 5);
      expect(asset).toMatchObject({ width: 96, height: 96 });
      expect(asset.url).toBe(`${BASE}/media/${asset.id}/clip.webp`);
      expect(asset.thumbUrl).toBe(`${BASE}/media/${asset.id}/still.webp`);
      const clip = storage.objects.get(keyOf(asset.url))!;
      expect(clip.contentType).toBe('image/webp');
      const meta = await sharp(clip.body, { animated: true }).metadata();
      expect(meta).toMatchObject({
        format: 'webp',
        pages: 5,
        pageHeight: 96,
        width: 96,
        hasAlpha: true,
        loop: 0,
      });
      expect(meta.delay).toEqual([67, 67, 67, 67, 67]);
      const still = await sharp(storage.objects.get(keyOf(asset.thumbUrl))!.body).metadata();
      expect(still).toMatchObject({ format: 'webp', width: 96, height: 96, hasAlpha: true });
      expect(still.pages ?? 1).toBe(1);
    });

    it('refuses a strip of the wrong shape: no alpha, not whole squares, one frame, too many, too small or too large', async () => {
      const u = await signup();
      for (const bytes of [
        await strip(96, 3, false),
        await strip(96, 3, true, 96 * 3 + 10),
        await strip(96, 1),
        await strip(64, 46),
        await strip(48, 3),
        await strip(520, 2),
        await sharp({ create: { width: 96, height: 192, channels: 4, background: '#0000' } })
          .webp()
          .toBuffer(),
      ]) {
        const done = await send(u, bytes);
        expect(done.status).toBe(422);
        expect(done.body.error.code).toBe('MEDIA_INVALID');
      }
      // The bounds themselves pass: 64 px × 45 frames (15 a second for 3 s), 512 px × 2 frames.
      expect((await send(u, await strip(64, 45))).status).toBe(200);
      expect((await send(u, await strip(512, 2))).status).toBe(200);
    });
  });

  describe('the perk', () => {
    it('a non-holder is refused 409 VIP_UNAVAILABLE no_perk; a holder by inheritance sets it and everyone sees it', async () => {
      const [u, viewer] = [await signup(), await signup()];
      const asset = await upload(u);
      const refused = await put(u, { mediaId: asset.id });
      expect(refused.status).toBe(409);
      expect(refused.body.error).toMatchObject({
        code: 'VIP_UNAVAILABLE',
        details: [{ field: 'perk', issue: 'no_perk' }],
      });
      // A VIP 2 member holds VIP 1's perk.
      await member(u, VIP2);
      const set = await put(u, { mediaId: asset.id });
      expect(set.status, JSON.stringify(set.body)).toBe(200);
      const shown = { url: asset.url, stillUrl: asset.thumbUrl, width: 96, height: 96 };
      expect(set.body).toEqual(shown);
      expect((await profileOf(viewer, u)).animatedAvatar).toEqual(shown);
      expect((await profileOf(u, u)).animatedAvatar).toEqual(shown);
      // The viewer has none.
      expect((await profileOf(u, viewer)).animatedAvatar).toBeUndefined();
    });

    it('disappears when the VIP ends or the perk is switched off, and comes back on renewal (the clip is kept)', async () => {
      const [u, viewer] = [await signup(), await signup()];
      await member(u, VIP1);
      const asset = await upload(u);
      expect((await put(u, { mediaId: asset.id })).status).toBe(200);
      await member(u, VIP1, -1);
      expect((await profileOf(viewer, u)).animatedAvatar).toBeUndefined();
      expect((await profileOf(u, u)).animatedAvatar).toBeUndefined();
      // A new clip needs the perk.
      const next = await upload(u);
      expect((await put(u, { mediaId: next.id })).status).toBe(409);
      // Renewed: the kept clip shows again without a new upload.
      await member(u, VIP1);
      expect((await profileOf(viewer, u)).animatedAvatar?.url).toBe(asset.url);
      expect(storage.objects.has(keyOf(asset.url))).toBe(true);
      // The owner switches the perk off on the tier: hidden; on again: back.
      await perk(false);
      try {
        expect((await profileOf(viewer, u)).animatedAvatar).toBeUndefined();
      } finally {
        await perk(true);
      }
      expect((await profileOf(viewer, u)).animatedAvatar?.url).toBe(asset.url);
    });
  });

  describe('set and clear', () => {
    it('replaces the clip (the old files go), changes nothing for the same one, clears idempotently, audited', async () => {
      const [u, viewer] = [await signup(), await signup()];
      await member(u, VIP1);
      const first = await upload(u);
      expect((await put(u, { mediaId: first.id })).status).toBe(200);
      expect((await put(u, { mediaId: first.id })).body.url).toBe(first.url);
      const second = await upload(u, 128, 3);
      const replaced = await put(u, { mediaId: second.id });
      expect(replaced.body).toMatchObject({ url: second.url, width: 128 });
      expect(storage.objects.has(keyOf(first.url))).toBe(false);
      expect(storage.objects.has(keyOf(first.thumbUrl))).toBe(false);
      expect(await ctx.prisma.mediaAsset.findUnique({ where: { id: first.id } })).toBeNull();

      expect((await remove(u)).status).toBe(204);
      expect((await profileOf(viewer, u)).animatedAvatar).toBeUndefined();
      expect(storage.objects.has(keyOf(second.url))).toBe(false);
      expect((await remove(u)).status).toBe(204);
      const audits = await ctx.prisma.auditLog.findMany({
        where: { actorUserId: u.id, action: 'user.animated_avatar.update' },
        orderBy: { createdAt: 'asc' },
      });
      // The clock is frozen in this file: the rows share a time, so compare them as a set.
      expect(audits.map((a) => (a.metadata as { animatedAvatar: string }).animatedAvatar).sort()).toEqual([
        'removed',
        'set',
        'set',
      ]);
    });

    it('removing works without the perk (after the VIP ended)', async () => {
      const u = await signup();
      await member(u, VIP1);
      const asset = await upload(u);
      expect((await put(u, { mediaId: asset.id })).status).toBe(200);
      await member(u, VIP1, -1);
      expect((await remove(u)).status).toBe(204);
      await member(u, VIP1);
      expect((await profileOf(u, u)).animatedAvatar).toBeUndefined();
    });

    it('refuses another kind, another user’s asset and a malformed body', async () => {
      const [u, other] = [await signup(), await signup()];
      await member(u, VIP1);
      await member(other, VIP1);
      const png = await sharp({ create: { width: 64, height: 64, channels: 3, background: '#336699' } })
        .png()
        .toBuffer();
      const s = await slot(u, { kind: 'AVATAR', contentType: 'image/png', byteSize: png.length });
      storage.upload(s.body.uploadUrl, png, 'image/png');
      const avatar = await ctx.http.post(`/api/v1/media/uploads/${s.body.uploadId}/complete`).set(auth(u));
      const wrongKind = await put(u, { mediaId: avatar.body.id });
      expect(wrongKind.status).toBe(400);
      expect(wrongKind.body.error.details).toEqual([{ field: 'mediaId', issue: 'invalid_value' }]);
      const theirs = await upload(other);
      expect((await put(u, { mediaId: theirs.id })).status).toBe(400);
      expect((await put(u, { mediaId: 'nope' })).status).toBe(400);
      expect((await put(u, { mediaId: theirs.id, extra: 1 })).status).toBe(400);
      // The clip can never be the profile photo.
      const mine = await upload(u);
      expect((await ctx.http.put('/api/v1/me/avatar').set(auth(u)).send({ mediaId: mine.id })).status).toBe(
        400,
      );
    });
  });

  describe('safety', () => {
    it('never across a block, either way; a third person still sees it', async () => {
      const [u, blocker, blocked, third] = [await signup(), await signup(), await signup(), await signup()];
      await member(u, VIP1);
      const asset = await upload(u);
      expect((await put(u, { mediaId: asset.id })).status).toBe(200);
      expect((await ctx.http.put(`/api/v1/users/${u.username}/block`).set(auth(blocker))).status).toBe(200);
      expect((await profileOf(blocker, u)).animatedAvatar).toBeUndefined();
      expect((await ctx.http.put(`/api/v1/users/${blocked.username}/block`).set(auth(u))).status).toBe(200);
      expect((await profileOf(blocked, u)).animatedAvatar).toBeUndefined();
      expect((await profileOf(third, u)).animatedAvatar?.url).toBe(asset.url);
      // Unblocked: shown again.
      expect((await ctx.http.delete(`/api/v1/users/${u.username}/block`).set(auth(blocker))).status).toBe(
        200,
      );
      expect((await profileOf(blocker, u)).animatedAvatar?.url).toBe(asset.url);
    });

    it('staff see it in the panel and take it down: notified, audited, files deleted; none left → 409', async () => {
      const [u, viewer] = [await signup(), await signup()];
      await member(u, VIP1);
      const asset = await upload(u);
      expect((await put(u, { mediaId: asset.id })).status).toBe(200);
      const detail = await p.send(owner, 'get', `/admin/users/${u.id}`);
      expect(detail.status).toBe(200);
      expectContract(detail, 'getAdminUser');
      expect(detail.body.user.animatedAvatarUrl).toBe(asset.url);

      const noReason = await p.send(owner, 'post', `/admin/users/${u.id}/animated-avatar/remove`, {});
      expect(noReason.status).toBe(400);
      const removed = await p.send(owner, 'post', `/admin/users/${u.id}/animated-avatar/remove`, {
        reason: 'violates the rules',
      });
      expect(removed.status, JSON.stringify(removed.body)).toBe(200);
      expectContract(removed, 'removeAdminUserAnimatedAvatar');
      expect(removed.body).toEqual({ removed: true });
      expect((await profileOf(viewer, u)).animatedAvatar).toBeUndefined();
      expect(storage.objects.has(keyOf(asset.url))).toBe(false);
      expect(storage.objects.has(keyOf(asset.thumbUrl))).toBe(false);
      expect(await ctx.prisma.mediaAsset.findUnique({ where: { id: asset.id } })).toBeNull();
      const notes = await ctx.http.get('/api/v1/notifications').set(auth(u));
      expect(notes.status).toBe(200);
      expectContract(notes, 'listNotifications');
      expect(notes.body.data.map((n: { type: string }) => n.type)).toContain('ANIMATED_AVATAR_REMOVED');
      const audit = await ctx.prisma.auditLog.findFirst({
        where: { action: 'admin.animated_avatar.remove', targetId: u.id },
      });
      expect(audit?.metadata).toMatchObject({ reason: 'violates the rules', via: 'panel' });
      const again = await p.send(owner, 'post', `/admin/users/${u.id}/animated-avatar/remove`, {
        reason: 'again',
      });
      expect(again.status).toBe(409);
      expect(again.body.error.code).toBe('ADMIN_ACTION_REFUSED');
      const after = await p.send(owner, 'get', `/admin/users/${u.id}`);
      expect(after.body.user.animatedAvatarUrl).toBeUndefined();
    });
  });
});
