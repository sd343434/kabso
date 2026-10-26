/**
 * KL-077 / CP-017 (D104, owner 2026-10-26): coins, bullet messages, and voice clips and images in
 * the live chat (openapi v1.19-live DRAFT, CONVENTIONS §10.19, §10.11, §11.1, §4, §7), end to end
 * against PostgreSQL + Redis with the API as the DML-only runtime role.
 *
 * Coins are granted the way the server does it: `wallet:admin` as a child process with the
 * migration role. Time (the 5-second bullet rule, the 1-a-second chat rule, the 60-second expiry
 * of voice clips and images) comes from a FakeClock. The media server is the in-memory fake that
 * records every data message; object storage is the in-memory store.
 */
import { execFileSync } from 'node:child_process';
import { randomUUID } from 'node:crypto';
import { fileURLToPath } from 'node:url';
import sharp from 'sharp';
import type request from 'supertest';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { Clock } from '../src/common/time/clock.js';
import { LIVE_BULLET_COST_COINS } from '../src/modules/live/live-bullets.service.js';
import { LiveChatService } from '../src/modules/live/live-chat.service.js';
import { LIVE_MEDIA_PROVIDER } from '../src/modules/live/media/live-media.provider.js';
import { OBJECT_STORAGE } from '../src/modules/media/object-storage.js';
import { m4a } from './helpers/m4a.js';
import { MemoryLiveMedia } from './helpers/memory-live-media.js';
import { MemoryObjectStorage } from './helpers/memory-storage.js';
import { expectContract, operations } from './helpers/openapi.js';
import { createTestApp, registerVerified, settle, type TestContext } from './helpers/test-app.js';

class FakeClock extends Clock {
  private ms = Date.now();
  now(): Date {
    return new Date(this.ms);
  }
  advance(seconds: number): void {
    this.ms += Math.round(seconds * 1000);
  }
}

interface TestUser {
  readonly id: string;
  readonly username: string;
  readonly email: string;
  readonly token: string;
}

const MEDIA_ON = {
  MEDIA_UPLOADS_ENABLED: 'true',
  S3_BUCKET: 'kabso-media-test',
  S3_ACCESS_KEY_ID: 'test',
  S3_SECRET_ACCESS_KEY: 'test',
  MEDIA_PUBLIC_BASE_URL: 'https://media.example.test',
};

/** Runs `pnpm wallet:admin …` as on the server (migration role, a child process). */
function walletAdmin(...args: string[]): { status: number; out: string } {
  try {
    const out = execFileSync('pnpm', ['-s', 'wallet:admin', ...args], {
      cwd: fileURLToPath(new URL('..', import.meta.url)),
      env: process.env,
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'pipe'],
    });
    return { status: 0, out };
  } catch (err) {
    const e = err as { status: number; stderr: string };
    return { status: e.status, out: e.stderr };
  }
}

describe('CP-017 contract coverage', () => {
  it('openapi declares the wallet and bullet operations', () => {
    const ids = operations().map((o) => `${o.operationId} ${o.method.toUpperCase()} ${o.path}`);
    expect(ids).toContain('getMyWallet GET /api/v1/wallet/me');
    expect(ids).toContain('sendLiveBullet POST /api/v1/live/rooms/{roomId}/bullets');
  });
});

// The wallet tests start the CLI as a child process (a few seconds each).
describe('CP-017 coins, bullet messages, voice clips and images', { timeout: 120_000 }, () => {
  const clock = new FakeClock();
  const media = new MemoryLiveMedia();
  const storage = new MemoryObjectStorage();
  let ctx: TestContext;

  const auth = (u: TestUser) => ({ Authorization: `Bearer ${u.token}` });
  const signup = async (): Promise<TestUser> => {
    const { res, payload } = await registerVerified(ctx);
    expect(res.status).toBe(201);
    return {
      id: res.body.user.id as string,
      username: res.body.user.username as string,
      email: String(payload.email).toLowerCase(),
      token: res.body.tokens.accessToken as string,
    };
  };
  const host = async (): Promise<TestUser> => {
    const u = await signup();
    await ctx.prisma.liveHost.create({ data: { userId: u.id, source: 'ADMIN' } });
    return u;
  };
  const goLive = async (u: TestUser, extra: object = {}): Promise<string> => {
    const res = await ctx.http
      .post('/api/v1/live/rooms')
      .set(auth(u))
      .send({ title: 'Coins', ...extra });
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    return res.body.id as string;
  };
  const end = async (roomId: string, u: TestUser) => {
    expect((await ctx.http.post(`/api/v1/live/rooms/${roomId}/end`).set(auth(u))).status).toBe(200);
  };
  const join = async (roomId: string, u: TestUser) => {
    const raw = JSON.stringify({
      event: 'participant_joined',
      room: { name: roomId },
      participant: { identity: u.id },
    });
    const res = await ctx.http
      .post('/internal/livekit/webhook')
      .set('Content-Type', 'application/webhook+json')
      .set('Authorization', MemoryLiveMedia.sign(raw))
      .send(raw);
    expect(res.status).toBe(200);
  };
  const wallet = async (u: TestUser) => {
    const res = await ctx.http.get('/api/v1/wallet/me').set(auth(u));
    expect(res.status).toBe(200);
    expectContract(res, 'getMyWallet');
    return res.body.coins as number;
  };
  const grant = (u: TestUser, coins: number) => {
    const run = walletAdmin('grant', u.email, String(coins));
    expect(run.status, run.out).toBe(0);
  };
  const bullet = (roomId: string, u: TestUser | null, body: unknown): request.Test => {
    const req = ctx.http.post(`/api/v1/live/rooms/${roomId}/bullets`);
    if (u) void req.set(auth(u));
    return req.send(body as object);
  };
  const bulletsTo = (roomId: string) =>
    media.broadcasts.filter((b) => b.room === roomId && b.topic === 'bullet');
  const ledger = (u: TestUser) =>
    ctx.prisma.walletLedgerEntry.findMany({ where: { userId: u.id }, orderBy: { createdAt: 'asc' } });
  /** Moves past the 5-second bullet rule (and the chat's 1-a-second rule). */
  const wait5 = () => clock.advance(5.01);

  beforeAll(async () => {
    ctx = await createTestApp(
      { LIVE_HOSTING_ENABLED: 'true', LIVE_HEARTBEAT_STALE_SECONDS: '3600', ...MEDIA_ON },
      [
        { token: Clock, value: clock },
        { token: LIVE_MEDIA_PROVIDER, value: media },
        { token: OBJECT_STORAGE, value: storage },
      ],
    );
  });
  afterAll(async () => ctx?.close());

  // ---- Coins ------------------------------------------------------------------------------------

  describe('wallet', () => {
    it('GET /wallet/me needs a token and starts at 0', async () => {
      const anonymous = await ctx.http.get('/api/v1/wallet/me');
      expect(anonymous.status).toBe(401);
      expectContract(anonymous, 'getMyWallet');
      const u = await signup();
      expect(await wallet(u)).toBe(0);
    });

    it('wallet:admin grant adds coins with a ledger row and an audit row; revoke and balance', async () => {
      const u = await signup();
      const run = walletAdmin('grant', u.email.toUpperCase(), '100');
      expect(run).toEqual({ status: 0, out: `${u.email.toUpperCase()}: +100 coins, balance 100.\n` });
      expect(await wallet(u)).toBe(100);
      expect(walletAdmin('grant', u.email, '50').status).toBe(0);
      expect(await wallet(u)).toBe(150);

      const rows = await ledger(u);
      expect(rows.map((r) => [r.reason, Number(r.delta), Number(r.balanceAfter)])).toEqual([
        ['ADMIN_GRANT', 100, 100],
        ['ADMIN_GRANT', 50, 150],
      ]);
      expect(new Set(rows.map((r) => r.referenceId)).size).toBe(2);
      const audits = await ctx.prisma.auditLog.findMany({
        where: { action: 'wallet.grant', targetId: u.id },
        orderBy: { createdAt: 'asc' },
      });
      expect(audits.map((a) => a.metadata)).toEqual([
        { coins: 100, balance: 100, ledgerId: rows[0]!.id, via: 'cli' },
        { coins: 50, balance: 150, ledgerId: rows[1]!.id, via: 'cli' },
      ]);

      const short = walletAdmin('revoke', u.email, '151');
      expect(short.status).toBe(1);
      expect(short.out).toContain('fewer than 151 coins; nothing changed');
      expect(walletAdmin('revoke', u.email, '30')).toEqual({
        status: 0,
        out: `${u.email}: -30 coins, balance 120.\n`,
      });
      expect(walletAdmin('balance', u.email)).toEqual({ status: 0, out: `${u.email}: 120 coins.\n` });
      expect(await wallet(u)).toBe(120);
      expect((await ledger(u)).map((r) => r.reason)).toEqual(['ADMIN_GRANT', 'ADMIN_GRANT', 'ADMIN_REVOKE']);
      expect(await ctx.prisma.auditLog.count({ where: { action: 'wallet.revoke', targetId: u.id } })).toBe(1);
    });

    it('wallet:admin refuses non-positive or malformed amounts, unknown emails and a missing amount', async () => {
      const u = await signup();
      for (const amount of ['0', '-5', '1.5', 'abc', '00', '1000000001']) {
        const run = walletAdmin('grant', u.email, amount);
        expect(run.status, amount).toBe(1);
      }
      expect(walletAdmin('grant', u.email).status).toBe(1);
      const unknown = walletAdmin('grant', 'nobody@example.invalid', '10');
      expect(unknown.status).toBe(1);
      expect(unknown.out).toContain('No user with email');
      expect(walletAdmin('mint', u.email, '10').status).toBe(1);
      expect(await wallet(u)).toBe(0);
      expect(await ledger(u)).toEqual([]);
    });

    it('the ledger is append-only for the runtime role', async () => {
      await expect(ctx.prisma.$executeRawUnsafe('UPDATE wallet_ledger SET delta = 1')).rejects.toThrow();
      await expect(ctx.prisma.$executeRawUnsafe('DELETE FROM wallet_ledger')).rejects.toThrow();
    });
  });

  // ---- Bullet messages ---------------------------------------------------------------------------

  describe('bullet messages', () => {
    it('costs 15 coins and reaches every LIVE room (video and audio) on topic `bullet`', async () => {
      const [h1, h2, h3, h4] = [await host(), await host(), await host(), await host()];
      const viewer = await signup();
      const solo = await goLive(h1);
      const audio = await goLive(h2, { mode: 'AUDIO', seatCount: 10 });
      const multi = await goLive(h3, { mode: 'MULTI', seatCount: 4 });
      const ended = await goLive(h4);
      await end(ended, h4);
      await join(solo, viewer);
      grant(viewer, 20);
      wait5();

      const clientId = randomUUID();
      const res = await bullet(solo, viewer, { text: '  مساء الخير يا أحلى لايف  ', clientId });
      expect(res.status, JSON.stringify(res.body)).toBe(201);
      expectContract(res, 'sendLiveBullet');
      expect(res.body).toEqual({
        bullet: {
          id: expect.any(String),
          text: 'مساء الخير يا أحلى لايف',
          sender: {
            id: viewer.id,
            username: viewer.username,
            displayName: expect.any(String),
            avatarUrl: null,
          },
          roomId: solo,
          createdAt: clock.now().toISOString(),
        },
        coins: 20 - LIVE_BULLET_COST_COINS,
      });
      expect(LIVE_BULLET_COST_COINS).toBe(15);
      expect(await wallet(viewer)).toBe(5);

      await settle(ctx);
      const payload = JSON.stringify({ type: 'bullet', bullet: res.body.bullet });
      for (const roomId of [solo, audio, multi]) {
        expect(bulletsTo(roomId)).toEqual([{ room: roomId, topic: 'bullet', payload }]);
      }
      expect(bulletsTo(ended)).toEqual([]);
      // Not a chat line.
      expect(
        media.broadcasts.filter((b) => b.topic === 'chat' && b.payload.includes(res.body.bullet.id)),
      ).toEqual([]);

      const rows = await ledger(viewer);
      expect(rows.map((r) => [r.reason, Number(r.delta), Number(r.balanceAfter), r.referenceId])).toEqual([
        ['ADMIN_GRANT', 20, 20, expect.any(String)],
        ['BULLET_MESSAGE', -15, 5, res.body.bullet.id],
      ]);
      for (const [roomId, u] of [
        [solo, h1],
        [audio, h2],
        [multi, h3],
      ] as const) {
        await end(roomId, u);
      }
    });

    it('a short balance → 409 INSUFFICIENT_COINS: nothing stored, charged or sent', async () => {
      const h = await host();
      const viewer = await signup();
      const roomId = await goLive(h);
      await join(roomId, viewer);
      grant(viewer, 14);
      wait5();
      const broadcastsBefore = media.broadcasts.length;
      const res = await bullet(roomId, viewer, { text: 'hello', clientId: randomUUID() });
      expect(res.status).toBe(409);
      expect(res.body.error.code).toBe('INSUFFICIENT_COINS');
      expectContract(res, 'sendLiveBullet');
      await settle(ctx);
      expect(media.broadcasts.length).toBe(broadcastsBefore);
      expect(await wallet(viewer)).toBe(14);
      expect(await ctx.prisma.liveBullet.count({ where: { userId: viewer.id } })).toBe(0);
      expect((await ledger(viewer)).map((r) => r.reason)).toEqual(['ADMIN_GRANT']);

      // Without any wallet row at all.
      const poor = await signup();
      await join(roomId, poor);
      const none = await bullet(roomId, poor, { text: 'hello', clientId: randomUUID() });
      expect(none.status).toBe(409);
      expect(none.body.error.code).toBe('INSUFFICIENT_COINS');
      expect(await wallet(poor)).toBe(0);
      await end(roomId, h);
    });

    it('a retry with the same clientId → 200, the first bullet, never charged or sent twice', async () => {
      const h = await host();
      const viewer = await signup();
      const roomId = await goLive(h);
      await join(roomId, viewer);
      grant(viewer, 100);
      wait5();
      const clientId = randomUUID();
      const first = await bullet(roomId, viewer, { text: 'once', clientId });
      expect(first.status).toBe(201);
      // Inside the 5-second window and with another text: still the first bullet.
      const again = await bullet(roomId, viewer, { text: 'twice?', clientId: clientId.toUpperCase() });
      expect(again.status).toBe(200);
      expectContract(again, 'sendLiveBullet');
      expect(again.body).toEqual({ bullet: first.body.bullet, coins: 85 });
      await settle(ctx);
      expect(bulletsTo(roomId)).toHaveLength(1);
      expect(await wallet(viewer)).toBe(85);
      expect((await ledger(viewer)).filter((r) => r.reason === 'BULLET_MESSAGE')).toHaveLength(1);
      // Concurrent duplicates: one bullet, one charge (a duplicate that reaches the 5-second
      // rule before the first one committed may get 429; it is never charged).
      wait5();
      const racedId = randomUUID();
      const raced = await Promise.all(
        [0, 1, 2].map(() => bullet(roomId, viewer, { text: 'race', clientId: racedId })),
      );
      const statuses = raced.map((r) => r.status);
      expect(statuses.filter((s) => s === 201)).toHaveLength(1);
      expect(statuses.every((s) => s === 200 || s === 201 || s === 429)).toBe(true);
      const ids = raced.filter((r) => r.status !== 429).map((r) => r.body.bullet.id as string);
      expect(new Set(ids).size).toBe(1);
      expect(await wallet(viewer)).toBe(70);
      expect((await ledger(viewer)).filter((r) => r.reason === 'BULLET_MESSAGE')).toHaveLength(2);
      await end(roomId, h);
    });

    it('one bullet every 5 s per user (429 with Retry-After), across lives', async () => {
      const [h1, h2] = [await host(), await host()];
      const viewer = await signup();
      const a = await goLive(h1);
      const b = await goLive(h2);
      await join(a, viewer);
      await join(b, viewer);
      grant(viewer, 100);
      wait5();
      expect((await bullet(a, viewer, { text: 'one', clientId: randomUUID() })).status).toBe(201);
      clock.advance(4);
      const limited = await bullet(b, viewer, { text: 'two', clientId: randomUUID() });
      expect(limited.status).toBe(429);
      expect(limited.body.error.code).toBe('RATE_LIMITED');
      expect(limited.headers['retry-after']).toBe('1');
      expectContract(limited, 'sendLiveBullet');
      expect(await wallet(viewer)).toBe(85);
      clock.advance(1);
      expect((await bullet(b, viewer, { text: 'two', clientId: randomUUID() })).status).toBe(201);
      expect(await wallet(viewer)).toBe(70);
      await end(a, h1);
      await end(b, h2);
    });

    it('checks: 401, 404, 409 ended, 400 text, 403 not in the room, 403 muted; the host may send', async () => {
      const h = await host();
      const [viewer, outsider, muted] = [await signup(), await signup(), await signup()];
      const roomId = await goLive(h);
      for (const u of [viewer, outsider, muted, h]) grant(u, 100);
      await join(roomId, viewer);
      await join(roomId, muted);
      wait5();

      const guest = await bullet(roomId, null, { text: 'hi', clientId: randomUUID() });
      expect(guest.status).toBe(401);
      expectContract(guest, 'sendLiveBullet');
      const missing = await bullet('0192f1d0-0000-7000-8000-000000000000', viewer, {
        text: 'hi',
        clientId: randomUUID(),
      });
      expect(missing.status).toBe(404);
      expectContract(missing, 'sendLiveBullet');

      const issue = async (body: unknown) => {
        const res = await bullet(roomId, viewer, body);
        expect(res.status).toBe(400);
        expectContract(res, 'sendLiveBullet');
        return res.body.error.details as { field: string; issue: string }[];
      };
      expect(await issue({ text: 'x'.repeat(61), clientId: randomUUID() })).toEqual([
        { field: 'text', issue: 'too_long' },
      ]);
      expect(await issue({ text: '   ', clientId: randomUUID() })).toEqual([
        { field: 'text', issue: 'required' },
      ]);
      expect(await issue({ text: 'a\nb', clientId: randomUUID() })).toEqual([
        { field: 'text', issue: 'invalid_format' },
      ]);
      expect(await issue({ text: 'hi' })).toEqual([{ field: 'clientId', issue: 'required' }]);
      expect(await issue({ text: 'hi', clientId: randomUUID(), roomId })).toEqual([
        { field: 'roomId', issue: 'unknown_field' },
      ]);

      const out = await bullet(roomId, outsider, { text: 'hi', clientId: randomUUID() });
      expect(out.status).toBe(403);
      expect(out.body.error.code).toBe('LIVE_CHAT_NOT_IN_ROOM');
      expectContract(out, 'sendLiveBullet');

      expect(
        (await ctx.http.put(`/api/v1/live/rooms/${roomId}/chat/mutes/${muted.username}`).set(auth(h))).status,
      ).toBe(204);
      const silenced = await bullet(roomId, muted, { text: 'hi', clientId: randomUUID() });
      expect(silenced.status).toBe(403);
      expect(silenced.body.error.code).toBe('LIVE_CHAT_MUTED');

      // 60 code points is fine; the host sends without a media-session row.
      expect((await bullet(roomId, viewer, { text: 'x'.repeat(60), clientId: randomUUID() })).status).toBe(
        201,
      );
      expect((await bullet(roomId, h, { text: 'from the host', clientId: randomUUID() })).status).toBe(201);
      // Nobody but these two was charged.
      expect(await wallet(outsider)).toBe(100);
      expect(await wallet(muted)).toBe(100);
      expect(await wallet(viewer)).toBe(85);
      expect(await wallet(h)).toBe(85);

      await end(roomId, h);
      wait5();
      const after = await bullet(roomId, viewer, { text: 'hi', clientId: randomUUID() });
      expect(after.status).toBe(409);
      expect(after.body.error.code).toBe('LIVE_ROOM_ENDED');
      expect(await wallet(viewer)).toBe(85);
    });
  });

  // ---- Voice clips and images in the chat --------------------------------------------------------

  describe('voice clips and images in the live chat', () => {
    const upload = async (u: TestUser, kind: string, contentType: string, bytes: Buffer) => {
      const slot = await ctx.http
        .post('/api/v1/media/uploads')
        .set(auth(u))
        .send({ kind, contentType, byteSize: bytes.length });
      expect(slot.status, JSON.stringify(slot.body)).toBe(201);
      expectContract(slot, 'createMediaUpload');
      expect(storage.upload(slot.body.uploadUrl, bytes, contentType)).toBe(true);
      const done = await ctx.http.post(`/api/v1/media/uploads/${slot.body.uploadId}/complete`).set(auth(u));
      expectContract(done, 'completeMediaUpload');
      return done;
    };
    const voice = async (u: TestUser, durationMs = 12_000) => {
      const done = await upload(u, 'LIVE_CHAT_VOICE', 'audio/mp4', m4a({ durationMs }));
      expect(done.status, JSON.stringify(done.body)).toBe(200);
      return done.body as { id: string; url: string; durationMs: number };
    };
    const picture = async (u: TestUser) => {
      const bytes = await sharp({
        create: { width: 1600, height: 1200, channels: 3, background: { r: 200, g: 30, b: 40 } },
      })
        .jpeg()
        .toBuffer();
      const done = await upload(u, 'LIVE_CHAT_IMAGE', 'image/jpeg', bytes);
      expect(done.status).toBe(200);
      return done.body as { id: string; url: string; thumbUrl: string };
    };
    const send = (roomId: string, u: TestUser, body: object) =>
      ctx.http.post(`/api/v1/live/rooms/${roomId}/chat`).set(auth(u)).send(body);
    const list = async (roomId: string, u: TestUser) => {
      const res = await ctx.http.get(`/api/v1/live/rooms/${roomId}/chat`).set(auth(u));
      expect(res.status).toBe(200);
      expectContract(res, 'listLiveChatMessages');
      return res.body.data as { id: string; kind: string; media: unknown; expiresAt: string | null }[];
    };
    const sweep = () => ctx.app.get(LiveChatService).sweepExpiredMedia();

    it('upload rules: audio/mp4 only for LIVE_CHAT_VOICE, at most 1 MiB', async () => {
      const u = await signup();
      for (const [body, field, issue] of [
        [
          { kind: 'LIVE_CHAT_VOICE', contentType: 'image/jpeg', byteSize: 10 },
          'contentType',
          'invalid_value',
        ],
        [{ kind: 'POST_IMAGE', contentType: 'audio/mp4', byteSize: 10 }, 'contentType', 'invalid_value'],
        [{ kind: 'LIVE_CHAT_IMAGE', contentType: 'audio/mp4', byteSize: 10 }, 'contentType', 'invalid_value'],
        [
          { kind: 'LIVE_CHAT_VOICE', contentType: 'audio/mp4', byteSize: 1024 * 1024 + 1 },
          'byteSize',
          'too_big',
        ],
        [
          { kind: 'LIVE_CHAT_VOICE', contentType: 'audio/mpeg', byteSize: 10 },
          'contentType',
          'invalid_value',
        ],
      ] as const) {
        const res = await ctx.http.post('/api/v1/media/uploads').set(auth(u)).send(body);
        expect(res.status, JSON.stringify(body)).toBe(400);
        expectContract(res, 'createMediaUpload');
        expect(res.body.error.details).toEqual([{ field, issue }]);
      }
    });

    it('a voice clip is stored unchanged with its length; longer than 30 s or with video → 422', async () => {
      const u = await signup();
      const bytes = m4a({ durationMs: 12_000 });
      const done = await upload(u, 'LIVE_CHAT_VOICE', 'audio/mp4', bytes);
      expect(done.status).toBe(200);
      expect(done.body).toEqual({
        id: expect.any(String),
        type: 'AUDIO',
        status: 'READY',
        width: 0,
        height: 0,
        blurhash: null,
        url: `https://media.example.test/media/${done.body.id}/voice.m4a`,
        thumbUrl: `https://media.example.test/media/${done.body.id}/voice.m4a`,
        durationMs: 12_000,
      });
      const stored = storage.objects.get(`media/${done.body.id}/voice.m4a`);
      expect(stored?.contentType).toBe('audio/mp4');
      expect(stored?.body.equals(bytes)).toBe(true);
      // Completing again: the same asset.
      const again = await ctx.http.post(`/api/v1/media/uploads/${done.body.id}/complete`).set(auth(u));
      expect(again.body).toEqual(done.body);

      for (const clip of [
        m4a({ durationMs: 31_000 }),
        m4a({ durationMs: 30_501 }),
        m4a({ durationMs: 5_000, handlers: ['soun', 'vide'] }),
        Buffer.from('not an mp4 file at all, just text bytes'),
      ]) {
        const refused = await upload(u, 'LIVE_CHAT_VOICE', 'audio/mp4', clip);
        expect(refused.status).toBe(422);
        expect(refused.body.error.code).toBe('MEDIA_INVALID');
      }
      expect(
        (await upload(u, 'LIVE_CHAT_VOICE', 'audio/mp4', m4a({ durationMs: 30_400 }))).body.durationMs,
      ).toBe(30_000);
    });

    it('a VOICE message carries the clip and expiresAt (+60 s); after it, reads drop it and the sweeper deletes it', async () => {
      const h = await host();
      const viewer = await signup();
      const roomId = await goLive(h);
      await join(roomId, viewer);
      const clip = await voice(viewer);
      wait5();
      const res = await send(roomId, viewer, { kind: 'VOICE', mediaId: clip.id, clientId: randomUUID() });
      expect(res.status, JSON.stringify(res.body)).toBe(201);
      expectContract(res, 'sendLiveChatMessage');
      const sentAt = clock.now();
      expect(res.body).toMatchObject({
        kind: 'VOICE',
        text: '',
        authorRole: 'VIEWER',
        media: { id: clip.id, type: 'AUDIO', durationMs: 12_000, url: clip.url },
        expiresAt: new Date(sentAt.getTime() + 60_000).toISOString(),
        createdAt: sentAt.toISOString(),
      });
      // The data message carries expiresAt so apps hide it.
      const data = media.broadcastsOf(roomId, 'chat').at(-1) as {
        message: { id: string; expiresAt: string };
      };
      expect(data).toEqual({ type: 'chat', message: res.body });

      // A TEXT line next to it keeps its retention.
      clock.advance(1.01);
      const text = await send(roomId, viewer, { text: 'hello', clientId: randomUUID() });
      expect(text.status).toBe(201);
      expect(text.body).toMatchObject({ kind: 'TEXT', media: null, expiresAt: null });

      expect((await list(roomId, h)).map((m) => m.kind)).toEqual(['VOICE', 'TEXT']);
      expect(await sweep()).toBe(0);
      expect(storage.objects.has(`media/${clip.id}/voice.m4a`)).toBe(true);

      clock.advance(59);
      expect((await list(roomId, h)).map((m) => m.kind)).toEqual(['TEXT']);
      expect(await sweep()).toBe(1);
      expect(storage.objects.has(`media/${clip.id}/voice.m4a`)).toBe(false);
      expect(await ctx.prisma.mediaAsset.findUnique({ where: { id: clip.id } })).toBeNull();
      const row = await ctx.prisma.liveChatMessage.findUniqueOrThrow({ where: { id: res.body.id } });
      expect(row.mediaId).toBeNull();
      expect(await sweep()).toBe(0);
      // A retry of the vanished message answers with it, without its media.
      const retry = await send(roomId, viewer, {
        kind: 'VOICE',
        mediaId: clip.id,
        clientId: (await ctx.prisma.liveChatMessage.findUniqueOrThrow({ where: { id: res.body.id } }))
          .clientId,
      });
      expect(retry.status).toBe(200);
      expect(retry.body).toMatchObject({ id: res.body.id, media: null });
      await end(roomId, h);
    });

    it('an IMAGE message vanishes the same way; both sizes are deleted', async () => {
      const h = await host();
      const roomId = await goLive(h);
      const pic = await picture(h);
      wait5();
      const res = await send(roomId, h, { kind: 'IMAGE', mediaId: pic.id, clientId: randomUUID() });
      expect(res.status).toBe(201);
      expectContract(res, 'sendLiveChatMessage');
      expect(res.body).toMatchObject({ kind: 'IMAGE', media: { id: pic.id, type: 'IMAGE' } });
      expect(storage.objects.has(`media/${pic.id}/1080.webp`)).toBe(true);
      expect(storage.objects.has(`media/${pic.id}/320.webp`)).toBe(true);
      clock.advance(60);
      expect(await list(roomId, h)).toEqual([]);
      expect(await sweep()).toBe(1);
      expect(storage.objects.has(`media/${pic.id}/1080.webp`)).toBe(false);
      expect(storage.objects.has(`media/${pic.id}/320.webp`)).toBe(false);
      await end(roomId, h);
    });

    it("mediaId must be the caller's unused asset of the kind (400); the kind rules of the body", async () => {
      const h = await host();
      const [viewer, other] = [await signup(), await signup()];
      const roomId = await goLive(h);
      await join(roomId, viewer);
      const clip = await voice(viewer);
      const theirs = await voice(other);
      const pic = await picture(viewer);
      const refused = async (body: object, details: unknown) => {
        clock.advance(1.01);
        const res = await send(roomId, viewer, { clientId: randomUUID(), ...body });
        expect(res.status, JSON.stringify(res.body)).toBe(400);
        expectContract(res, 'sendLiveChatMessage');
        expect(res.body.error.details).toEqual(details);
      };
      const wrongAsset = [{ field: 'mediaId', issue: 'invalid_value' }];
      await refused({ kind: 'IMAGE', mediaId: clip.id }, wrongAsset);
      await refused({ kind: 'VOICE', mediaId: pic.id }, wrongAsset);
      await refused({ kind: 'VOICE', mediaId: theirs.id }, wrongAsset);
      await refused({ kind: 'VOICE', mediaId: randomUUID() }, wrongAsset);
      await refused({ kind: 'VOICE' }, [{ field: 'mediaId', issue: 'required' }]);
      await refused({ kind: 'VOICE', mediaId: clip.id, text: 'caption' }, [
        { field: 'text', issue: 'invalid_value' },
      ]);
      await refused({ text: 'hi', mediaId: clip.id }, [{ field: 'mediaId', issue: 'invalid_value' }]);
      await refused({ kind: 'VIDEO', mediaId: clip.id }, [{ field: 'kind', issue: 'invalid_value' }]);

      clock.advance(1.01);
      expect(
        (await send(roomId, viewer, { kind: 'VOICE', mediaId: clip.id, clientId: randomUUID() })).status,
      ).toBe(201);
      // Used once: not again.
      await refused({ kind: 'VOICE', mediaId: clip.id }, wrongAsset);
      // The chat's own checks still come first: someone not in the room.
      const outsider = await signup();
      const theirClip = await voice(outsider);
      const out = await send(roomId, outsider, {
        kind: 'VOICE',
        mediaId: theirClip.id,
        clientId: randomUUID(),
      });
      expect(out.status).toBe(403);
      expect(out.body.error.code).toBe('LIVE_CHAT_NOT_IN_ROOM');
      await end(roomId, h);
    });
  });
});
