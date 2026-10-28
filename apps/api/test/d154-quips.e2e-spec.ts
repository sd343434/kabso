/**
 * D154 (owner 2026-10-28, contract v1.32-live, CONVENTIONS §10.33): «إفيهات» quips — the QUIPS gift
 * category (paid lines and one free sound per viewer per live), the room's one queue of quips, the
 * host's and moderators' soundboard, and the per-category host share fixed on each send — end to end
 * against PostgreSQL + Redis with the API as the DML-only runtime role. `gift-admin quips-seed` runs as
 * on the server (a child process with the migration role). The media server is the in-memory fake
 * that records every data message; time is a FakeClock (the queue).
 */
import { execFileSync } from 'node:child_process';
import { randomUUID } from 'node:crypto';
import { fileURLToPath } from 'node:url';
import type request from 'supertest';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { Clock } from '../src/common/time/clock.js';
import { addGiftIn } from '../src/modules/gifts/gift-catalogue.js';
import { QUIP_GAP_MS, QUIP_PACK } from '../src/modules/gifts/quips.js';
import { LIVE_MEDIA_PROVIDER } from '../src/modules/live/media/live-media.provider.js';
import { creditIn } from '../src/modules/wallet/wallet-ledger.js';
import { MemoryLiveMedia } from './helpers/memory-live-media.js';
import { expectContract, operations } from './helpers/openapi.js';
import { createTestApp, registerVerified, type TestContext } from './helpers/test-app.js';

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
  readonly token: string;
}

/** Runs `pnpm gift:admin …` as on the server (migration role, a child process). */
function giftAdmin(...args: string[]): { status: number; out: string } {
  try {
    const out = execFileSync('pnpm', ['-s', 'gift:admin', ...args], {
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

const durationOf = (code: string): number => QUIP_PACK.find((q) => q.code === code)!.soundMs!;

describe('D154 contract coverage', () => {
  it('openapi v1.32-live declares the soundboard operation', () => {
    const ids = operations().map((o) => `${o.operationId} ${o.method.toUpperCase()} ${o.path}`);
    expect(ids).toContain('playLiveSound POST /api/v1/live/rooms/{roomId}/sounds');
  });
});

describe('D154 quips', { timeout: 180_000 }, () => {
  const clock = new FakeClock();
  const media = new MemoryLiveMedia();
  let ctx: TestContext;

  const auth = (u: TestUser) => ({ Authorization: `Bearer ${u.token}` });
  const signup = async (): Promise<TestUser> => {
    const { res } = await registerVerified(ctx);
    expect(res.status).toBe(201);
    return {
      id: res.body.user.id as string,
      username: res.body.user.username as string,
      token: res.body.tokens.accessToken as string,
    };
  };
  const host = async (): Promise<TestUser> => {
    const u = await signup();
    await ctx.prisma.liveHost.create({ data: { userId: u.id, source: 'ADMIN' } });
    return u;
  };
  const goLive = async (u: TestUser): Promise<string> => {
    const res = await ctx.http
      .post('/api/v1/live/rooms')
      .set(auth(u))
      .send({ title: 'Quips', mode: 'AUDIO', seatCount: 10 });
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    return res.body.id as string;
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
  const coins = (u: TestUser, amount: number) =>
    ctx.prisma.$transaction((tx) => creditIn(tx, u.id, BigInt(amount), 'ADMIN_GRANT', randomUUID()));
  const wallet = async (u: TestUser) => {
    const res = await ctx.http.get('/api/v1/wallet/me').set(auth(u));
    expect(res.status).toBe(200);
    return res.body.coins as number;
  };
  const send = (roomId: string, u: TestUser, code: string, to: TestUser, extra: object = {}): request.Test =>
    ctx.http
      .post(`/api/v1/live/rooms/${roomId}/gifts`)
      .set(auth(u))
      .send({
        giftCode: code,
        quantity: 1,
        recipients: [to.username],
        source: 'COINS',
        clientId: randomUUID(),
        ...extra,
      });
  const sound = (roomId: string, u: TestUser, soundCode: string): request.Test =>
    ctx.http.post(`/api/v1/live/rooms/${roomId}/sounds`).set(auth(u)).send({ soundCode });
  const messages = (roomId: string, topic: string) =>
    media.broadcasts
      .filter((b) => b.room === roomId && b.topic === topic)
      .map((b) => JSON.parse(b.payload) as Record<string, unknown>);
  const expectError = (res: request.Response, status: number, code: string, op: string) => {
    expect(res.status, JSON.stringify(res.body)).toBe(status);
    expect(res.body.error.code).toBe(code);
    expectContract(res, op);
  };
  const scene = async () => {
    const h = await host();
    const viewer = await signup();
    const roomId = await goLive(h);
    await join(roomId, viewer);
    return { h, viewer, roomId };
  };
  /** Lets the room's queue drain (the FakeClock moves past every slot). */
  const drain = () => clock.advance(120);

  beforeAll(async () => {
    ctx = await createTestApp(
      {
        LIVE_HOSTING_ENABLED: 'true',
        LIVE_HEARTBEAT_STALE_SECONDS: '3600',
        QUIP_QUEUE_MAX_WAIT_SECONDS: '20',
      },
      [
        { token: Clock, value: clock },
        { token: LIVE_MEDIA_PROVIDER, value: media },
      ],
    );
    const seeded = giftAdmin('quips-seed');
    expect(seeded.status, seeded.out).toBe(0);
    expect(seeded.out).toContain('35 added');
  });
  afterAll(async () => ctx?.close());

  it("quips-seed is idempotent and the catalogue lists the quips tab with each quip's sound", async () => {
    const again = giftAdmin('quips-seed');
    expect(again.status, again.out).toBe(0);
    expect(again.out).toContain('0 added');
    expect(again.out).toContain('35 already there');
    const u = await signup();
    const res = await ctx.http.get('/api/v1/gifts/catalogue').set(auth(u)).set('Accept-Language', 'ar');
    expect(res.status).toBe(200);
    expectContract(res, 'getGiftCatalogue');
    expect(res.body.categories).toEqual(['POPULAR', 'EVENT', 'FUN', 'QUIPS']);
    const quips = (res.body.data as { category: string }[]).filter((g) => g.category === 'QUIPS');
    expect(quips).toHaveLength(35);
    expect(res.body.data.find((g: { code: string }) => g.code === 'quip_tease_02')).toMatchObject({
      priceCoins: 299,
      name: 'تريقة ٢',
      tag: { code: 'tease', name: 'تريقة' },
      quip: { soundKey: 'kabi/tease_02', durationMs: 5721, text: 'إنت لو التركيز فلوس، كنت استلفت مننا.' },
    });
    expect(res.body.data.find((g: { code: string }) => g.code === 'quip_clap')).toMatchObject({
      priceCoins: 0,
      quip: { soundKey: 'room/clap', text: null },
    });
    // A normal gift has no quip.
    await ctx.prisma.$transaction((tx) =>
      addGiftIn(tx, 'd154_rose', {
        category: 'POPULAR',
        nameAr: 'وردة',
        nameEn: 'Rose',
        priceCoins: 10,
        assetKey: 'gift_rose',
        animationKey: null,
        sortOrder: 0,
        badge: 'NONE',
        tagCode: null,
        tagNameAr: null,
        tagNameEn: null,
      }),
    );
    const after = await ctx.http.get('/api/v1/gifts/catalogue').set(auth(u));
    expect(after.body.data.find((g: { code: string }) => g.code === 'd154_rose').quip).toBeNull();
    // Quips can never be put in a bag.
    const grant = giftAdmin('grant', 'nobody@example.com', 'quip_clap', '1');
    expect(grant.status).toBe(1);
  });

  it('a paid quip charges its price, fixes the 50 % share, plays as a `quip` message (not a gift effect)', async () => {
    const { h, viewer, roomId } = await scene();
    await coins(viewer, 1000);
    drain();
    const res = await send(roomId, viewer, 'quip_ghazal_01', h);
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    expectContract(res, 'sendLiveGift');
    expect(res.body.coins).toBe(1000 - 99);
    expect(res.body.gift).toMatchObject({ giftCode: 'quip_ghazal_01', unitPrice: 99, totalCoins: 99 });
    expect(res.body.quip).toMatchObject({
      id: res.body.gift.id,
      roomId,
      kind: 'GIFT',
      giftCode: 'quip_ghazal_01',
      soundKey: 'kabi/ghazal_01',
      durationMs: durationOf('quip_ghazal_01'),
      text: 'إيه الجمال ده! تحفة بجد!',
      free: false,
      delayMs: 0,
      sender: { username: viewer.username },
    });
    await new Promise((r) => setTimeout(r, 50));
    expect(messages(roomId, 'gift')).toEqual([]);
    expect(messages(roomId, 'quip')).toEqual([{ type: 'quip', quip: res.body.quip }]);
    const row = await ctx.prisma.liveGift.findUniqueOrThrow({ where: { id: res.body.gift.id as string } });
    expect(row.hostShareBps).toBe(5000);
    const ledger = await ctx.prisma.walletLedgerEntry.findMany({
      where: { userId: viewer.id, reason: 'LIVE_GIFT' },
    });
    expect(ledger.map((l) => Number(l.delta))).toEqual([-99]);
    // The score counts it like a normal gift (100 a coin).
    const room = await ctx.http.get(`/api/v1/live/rooms/${roomId}`).set(auth(viewer));
    expect(room.body.score).toBe(99 * 100);
    // A normal gift fixes the normal share (65 %).
    const rose = await send(roomId, viewer, 'd154_rose', h);
    expect(rose.status).toBe(201);
    expect(rose.body.quip).toBeUndefined();
    const roseRow = await ctx.prisma.liveGift.findUniqueOrThrow({
      where: { id: rose.body.gift.id as string },
    });
    expect(roseRow.hostShareBps).toBe(6500);
    // A retry with the same clientId is answered with the first send and plays nothing again.
    const clientId = randomUUID();
    drain();
    const first = await send(roomId, viewer, 'quip_funny_01', h, { clientId });
    expect(first.status).toBe(201);
    const retry = await send(roomId, viewer, 'quip_funny_01', h, { clientId });
    expect(retry.status).toBe(200);
    expect(retry.body.gift.id).toBe(first.body.gift.id);
    expect(await wallet(viewer)).toBe(1000 - 99 - 10 - 199);
  });

  it("quips take turns in the room's one queue; past the wait limit → 409 QUIP_QUEUE_FULL, nothing charged", async () => {
    const { h, viewer, roomId } = await scene();
    await coins(viewer, 10_000);
    drain();
    const a = await send(roomId, viewer, 'quip_funny_03', h);
    const b = await send(roomId, viewer, 'quip_ghazal_02', h);
    expect(a.body.quip.delayMs).toBe(0);
    expect(b.body.quip.delayMs).toBe(durationOf('quip_funny_03') + QUIP_GAP_MS);
    expect(Date.parse(b.body.quip.startsAt as string) - Date.parse(a.body.quip.startsAt as string)).toBe(
      durationOf('quip_funny_03') + QUIP_GAP_MS,
    );
    clock.advance(2);
    const c = await send(roomId, viewer, 'quip_ghazal_03', h);
    expect(c.body.quip.delayMs).toBe(
      durationOf('quip_funny_03') + durationOf('quip_ghazal_02') + 2 * QUIP_GAP_MS - 2000,
    );
    // 12.3 + 4.9 + 5.9 s (+ the gaps) are queued from 2 s ago: a fourth would start 22.3 s from now,
    // past QUIP_QUEUE_MAX_WAIT_SECONDS (20 here).
    const balance = await wallet(viewer);
    const full = await send(roomId, viewer, 'quip_funny_02', h);
    expectError(full, 409, 'QUIP_QUEUE_FULL', 'sendLiveGift');
    expect(await wallet(viewer)).toBe(balance);
    // Once it drains, the queue takes quips again at once.
    drain();
    expect((await send(roomId, viewer, 'quip_funny_02', h)).body.quip.delayMs).toBe(0);
  });

  it('a quip is sent with coins and quantity 1 only', async () => {
    const { h, viewer, roomId } = await scene();
    await coins(viewer, 1000);
    const bag = await send(roomId, viewer, 'quip_ghazal_01', h, { source: 'BAG' });
    expectError(bag, 400, 'VALIDATION_FAILED', 'sendLiveGift');
    expect(bag.body.error.details).toEqual([{ field: 'source', issue: 'invalid_value' }]);
    const ten = await send(roomId, viewer, 'quip_ghazal_01', h, { quantity: 10 });
    expectError(ten, 400, 'VALIDATION_FAILED', 'sendLiveGift');
    expect(ten.body.error.details).toEqual([{ field: 'quantity', issue: 'invalid_value' }]);
    expect(await wallet(viewer)).toBe(1000);
  });

  it('one free quip per viewer per live: no coins needed, counts nothing; a second → 409 QUIP_FREE_USED', async () => {
    const { h, viewer, roomId } = await scene();
    drain();
    const free = await send(roomId, viewer, 'quip_clap', h);
    expect(free.status, JSON.stringify(free.body)).toBe(201);
    expectContract(free, 'sendLiveGift');
    expect(free.body).toMatchObject({
      coins: 0,
      gift: { unitPrice: 0, totalCoins: 0 },
      quip: { free: true, text: null },
    });
    const again = await send(roomId, viewer, 'quip_wow', h);
    expectError(again, 409, 'QUIP_FREE_USED', 'sendLiveGift');
    expect(await ctx.prisma.liveGift.count({ where: { senderId: viewer.id, roomId } })).toBe(1);
    expect(await ctx.prisma.liveFreeQuip.count({ where: { userId: viewer.id, roomId } })).toBe(1);
    // Nothing counted: no score, no Contribution row, no ledger row.
    const room = await ctx.http.get(`/api/v1/live/rooms/${roomId}`).set(auth(viewer));
    expect(room.body.score).toBe(0);
    expect(await ctx.prisma.liveRoomTapper.count({ where: { roomId, userId: viewer.id } })).toBe(0);
    expect(await ctx.prisma.walletLedgerEntry.count({ where: { userId: viewer.id } })).toBe(0);
    // Paid quips are still available to them.
    await coins(viewer, 500);
    expect((await send(roomId, viewer, 'quip_ghazal_05', h)).status).toBe(201);
    // In their next live the host's viewers get a new free quip.
    await ctx.http.post(`/api/v1/live/rooms/${roomId}/end`).set(auth(h)).expect(200);
    const next = await goLive(h);
    await join(next, viewer);
    drain();
    expect((await send(next, viewer, 'quip_wow', h)).status).toBe(201);
  });

  it('the soundboard: host and moderators play free sounds, one every 2 s; viewers cannot', async () => {
    const { h, viewer, roomId } = await scene();
    const mod = await signup();
    await join(roomId, mod);
    await ctx.prisma.liveRoomModerator.create({ data: { roomId, userId: mod.id } });
    drain();
    const anonymous = await ctx.http
      .post(`/api/v1/live/rooms/${roomId}/sounds`)
      .send({ soundCode: 'quip_clap' });
    expectError(anonymous, 401, 'AUTH_UNAUTHENTICATED', 'playLiveSound');
    expectError(await sound(roomId, viewer, 'quip_clap'), 403, 'AUTH_FORBIDDEN', 'playLiveSound');
    const bad = await sound(roomId, h, 'Not A Code');
    expectError(bad, 400, 'VALIDATION_FAILED', 'playLiveSound');
    expectError(await sound(roomId, h, 'quip_ghazal_01'), 409, 'GIFT_UNAVAILABLE', 'playLiveSound');
    expectError(await sound(roomId, h, 'd154_rose'), 409, 'GIFT_UNAVAILABLE', 'playLiveSound');

    const played = await sound(roomId, h, 'quip_clap');
    expect(played.status, JSON.stringify(played.body)).toBe(201);
    expectContract(played, 'playLiveSound');
    expect(played.body.quip).toMatchObject({
      kind: 'SOUNDBOARD',
      giftCode: 'quip_clap',
      soundKey: 'room/clap',
      free: true,
      delayMs: 0,
    });
    const tooSoon = await sound(roomId, h, 'quip_bell');
    expectError(tooSoon, 429, 'RATE_LIMITED', 'playLiveSound');
    expect(Number(tooSoon.headers['retry-after'])).toBeGreaterThanOrEqual(1);
    // A moderator's sound queues behind the host's.
    const modSound = await sound(roomId, mod, 'quip_bell');
    expect(modSound.status).toBe(201);
    expect(modSound.body.quip.delayMs).toBe(durationOf('quip_clap') + QUIP_GAP_MS);
    await new Promise((r) => setTimeout(r, 50));
    expect(messages(roomId, 'quip').map((m) => (m.quip as { id: string }).id)).toEqual([
      played.body.quip.id,
      modSound.body.quip.id,
    ]);
    // Two seconds later the host plays again; nothing was stored as a gift.
    clock.advance(2.1);
    expect((await sound(roomId, h, 'quip_tada')).status).toBe(201);
    expect(await ctx.prisma.liveGift.count({ where: { roomId } })).toBe(0);
    // An ended live plays nothing.
    await ctx.http.post(`/api/v1/live/rooms/${roomId}/end`).set(auth(h)).expect(200);
    clock.advance(3);
    expectError(await sound(roomId, h, 'quip_clap'), 409, 'LIVE_ROOM_ENDED', 'playLiveSound');
  });
});
