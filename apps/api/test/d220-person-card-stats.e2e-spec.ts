/**
 * D220 (owner 2026-11-01; contract v1.77-social, CONVENTIONS §10.74): the person card's four numbers. Real gift
 * sends (a live and a direct conversation, a gift from the bag, a reversal through `economy-admin`) give
 * `PublicProfile.cherriesReceived` / `coinsSent`; the two privacy switches remove them from every other caller's
 * profile — the server does not send the value — while the user still sees both. End to end against PostgreSQL +
 * Redis.
 */
import { execFileSync } from 'node:child_process';
import { randomUUID } from 'node:crypto';
import { fileURLToPath } from 'node:url';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { addGiftIn, type GiftFields } from '../src/modules/gifts/gift-catalogue.js';
import { LIVE_MEDIA_PROVIDER } from '../src/modules/live/media/live-media.provider.js';
import { creditIn } from '../src/modules/wallet/wallet-ledger.js';
import { MemoryLiveMedia } from './helpers/memory-live-media.js';
import { expectContract } from './helpers/openapi.js';
import { createTestApp, registerVerified, type TestContext } from './helpers/test-app.js';

interface TestUser {
  readonly id: string;
  readonly username: string;
  readonly token: string;
}

/** Runs `pnpm economy:admin …` as on the server (migration role, a child process). */
function economyAdmin(...args: string[]): { status: number; out: string } {
  try {
    const out = execFileSync('pnpm', ['-s', 'economy:admin', ...args], {
      cwd: fileURLToPath(new URL('..', import.meta.url)),
      env: { ...process.env },
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'pipe'],
    });
    return { status: 0, out };
  } catch (err) {
    const e = err as { status: number; stderr: string };
    return { status: e.status, out: e.stderr };
  }
}

describe('D220 person card totals and their privacy', { timeout: 300_000 }, () => {
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
  const coins = (u: TestUser, amount: number) =>
    ctx.prisma.$transaction((tx) => creditIn(tx, u.id, BigInt(amount), 'ADMIN_GRANT', randomUUID()));
  const gift = (code: string, fields: Partial<GiftFields>) =>
    ctx.prisma.$transaction((tx) =>
      addGiftIn(tx, code, {
        category: 'POPULAR',
        nameAr: 'هدية',
        nameEn: 'Gift',
        priceCoins: 100,
        assetKey: `gift_${code}`,
        animationKey: null,
        sortOrder: 0,
        badge: 'NONE',
        tagCode: null,
        tagNameAr: null,
        tagNameEn: null,
        ...fields,
      }),
    );
  const startLive = async (host: TestUser) => {
    await ctx.prisma.liveHost.upsert({
      where: { userId: host.id },
      create: { userId: host.id, source: 'ADMIN' },
      update: {},
    });
    const room = await ctx.http.post('/api/v1/live/rooms').set(auth(host)).send({ title: 'Card' });
    expect(room.status, JSON.stringify(room.body)).toBe(201);
    return room.body.id as string;
  };
  const enter = async (roomId: string, u: TestUser) => {
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
  const liveGift = async (
    roomId: string,
    from: TestUser,
    to: TestUser,
    giftCode: string,
    source = 'COINS',
  ) => {
    const clientId = randomUUID();
    const res = await ctx.http
      .post(`/api/v1/live/rooms/${roomId}/gifts`)
      .set(auth(from))
      .send({ giftCode, quantity: 1, recipients: [to.username], source, clientId });
    expect([200, 201], JSON.stringify(res.body)).toContain(res.status);
    const row = await ctx.prisma.liveGift.findFirstOrThrow({
      where: { senderId: from.id, clientId },
      select: { id: true },
    });
    return row.id;
  };
  const dmGift = async (from: TestUser, to: TestUser, giftCode: string) => {
    // The recipient follows the sender: a conversation, not a message request.
    const f = await ctx.http.put(`/api/v1/users/${from.username}/follow`).set(auth(to));
    expect(f.status).toBe(200);
    const res = await ctx.http
      .post('/api/v1/dm/gifts')
      .set(auth(from))
      .send({ to: to.username, giftCode, quantity: 1, source: 'COINS', clientId: randomUUID() });
    expect(res.status, JSON.stringify(res.body)).toBe(201);
  };
  const profile = async (caller: TestUser, of: TestUser) => {
    const res = await ctx.http.get(`/api/v1/users/${of.username}`).set(auth(caller));
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    expectContract(res, 'getPublicProfile');
    return res.body as Record<string, unknown>;
  };
  const setPrivacy = async (u: TestUser, body: object) => {
    const res = await ctx.http.patch('/api/v1/me/privacy').set(auth(u)).send(body);
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    expectContract(res, 'updatePrivacy');
    return res.body as Record<string, unknown>;
  };

  let viewer: TestUser;
  let host: TestUser;
  let other: TestUser;
  let reversible = '';

  beforeAll(async () => {
    ctx = await createTestApp(
      { LIVE_HOSTING_ENABLED: 'true', LIVE_HEARTBEAT_STALE_SECONDS: '3600', LIVE_RANKINGS_TIME_ZONE: 'UTC' },
      [{ token: LIVE_MEDIA_PROVIDER, value: media }],
    );
    await gift('d220_rose', {});
    await gift('d220_big', { priceCoins: 1000 });
    [viewer, host, other] = [await signup(), await signup(), await signup()];
    await coins(viewer, 100_000);
  });
  afterAll(async () => ctx?.close());

  it('a new account shows 0 and 0 to everyone, and its switches are off', async () => {
    const fresh = await signup();
    expect(await profile(other, fresh)).toMatchObject({ cherriesReceived: 0, coinsSent: 0 });
    expect(await profile(fresh, fresh)).toMatchObject({ cherriesReceived: 0, coinsSent: 0, isSelf: true });
    const privacy = await ctx.http.get('/api/v1/me/privacy').set(auth(fresh));
    expectContract(privacy, 'getPrivacy');
    expect(privacy.body).toMatchObject({ hideCherriesReceived: false, hideCoinsSent: false });
  });

  it('counts the cherries received and the coins paid for gifts — lives and direct messages — minus reversals', async () => {
    const room = await startLive(host);
    await enter(room, viewer);
    await liveGift(room, viewer, host, 'd220_rose'); // 100 coins → 650 cherries (65 %)
    reversible = await liveGift(room, viewer, host, 'd220_big'); // 1 000 coins → 6 500 cherries
    await dmGift(viewer, host, 'd220_rose'); // 100 coins → 500 cherries (direct conversation 50 %)
    const ledger = await ctx.prisma.cherryLedgerEntry.aggregate({
      where: { userId: host.id, reason: 'GIFT_RECEIVED' },
      _sum: { delta: true },
    });
    const received = Number(ledger._sum.delta);
    const paid = Number(
      (await ctx.prisma.liveGift.aggregate({ where: { senderId: viewer.id }, _sum: { coinsCharged: true } }))
        ._sum.coinsCharged,
    );
    expect(paid).toBe(1200);
    expect(await profile(other, host)).toMatchObject({ cherriesReceived: received, coinsSent: 0 });
    expect(await profile(other, viewer)).toMatchObject({ cherriesReceived: 0, coinsSent: 1200 });

    // A reversed gift no longer counts for the recipient (the sender's coins stay spent).
    const r = economyAdmin('reverse-gift', reversible, '--note', 'chargeback');
    expect(r.status, r.out).toBe(0);
    const after = await profile(other, host);
    expect(after.cherriesReceived).toBe(received - 6500);
    expect((await profile(other, viewer)).coinsSent).toBe(1200);

    // Commissions, task rewards and team adjustments are not gifts.
    await ctx.prisma.$executeRaw`
      INSERT INTO cherry_ledger (id, user_id, delta, balance_after, reason, reference_id)
      VALUES (gen_random_uuid(), ${host.id}::uuid, 999, 0, 'TASK_REWARD', ${randomUUID()})`;
    expect((await profile(other, host)).cherriesReceived).toBe(received - 6500);
  });

  it('a gift sent from the bag adds no coins', async () => {
    const before = (await profile(other, viewer)).coinsSent as number;
    await ctx.prisma.userGiftStock.upsert({
      where: { userId_giftCode: { userId: viewer.id, giftCode: 'd220_rose' } },
      create: { userId: viewer.id, giftCode: 'd220_rose', quantity: 1 },
      update: { quantity: 1 },
    });
    const room = await ctx.prisma.liveRoom.findFirstOrThrow({
      where: { hostUserId: host.id, status: 'LIVE' },
      select: { id: true },
    });
    await liveGift(room.id, viewer, host, 'd220_rose', 'BAG');
    expect((await profile(other, viewer)).coinsSent).toBe(before);
  });

  it('the switches hide each total from everyone else — not sent at all — and the user still sees both', async () => {
    const shown = await profile(other, host);
    expect(shown).toHaveProperty('cherriesReceived');
    expect(shown).toHaveProperty('coinsSent');

    expect(await setPrivacy(host, { hideCherriesReceived: true })).toMatchObject({
      hideCherriesReceived: true,
      hideCoinsSent: false,
    });
    const three = await profile(other, host);
    expect(three).not.toHaveProperty('cherriesReceived');
    expect(three.coinsSent).toBe(0);
    // Every other caller gets the same answer (the viewer follows nobody here; `other` is a stranger).
    expect(await profile(viewer, host)).not.toHaveProperty('cherriesReceived');
    const own = await profile(host, host);
    expect(own.cherriesReceived).toBe(shown.cherriesReceived);
    expect(own).toHaveProperty('coinsSent', 0);

    await setPrivacy(host, { hideCoinsSent: true });
    const two = await profile(other, host);
    expect(two).not.toHaveProperty('cherriesReceived');
    expect(two).not.toHaveProperty('coinsSent');
    expect(JSON.stringify(two)).not.toMatch(/cherriesReceived|coinsSent/);
    expect(await profile(host, host)).toMatchObject({
      cherriesReceived: shown.cherriesReceived,
      coinsSent: 0,
    });
    // The follower counts are not affected.
    expect(two).toMatchObject({ followerCount: shown.followerCount, followingCount: shown.followingCount });

    await setPrivacy(viewer, { hideCoinsSent: true });
    const v = await profile(other, viewer);
    expect(v).not.toHaveProperty('coinsSent');
    expect(v).toHaveProperty('cherriesReceived', 0);

    // Off again: shown again.
    await setPrivacy(host, { hideCherriesReceived: false, hideCoinsSent: false });
    expect(await profile(other, host)).toMatchObject({
      cherriesReceived: shown.cherriesReceived,
      coinsSent: 0,
    });
  });

  it('a private account keeps its totals public, like its counts (§10.47)', async () => {
    await setPrivacy(viewer, { isPrivate: true, hideCoinsSent: false });
    const p = await profile(other, viewer);
    expect(p).toMatchObject({ isPrivate: true, coinsSent: 1200, cherriesReceived: 0 });
    await setPrivacy(viewer, { isPrivate: false });
  });

  it('rejects anything but a boolean for the switches', async () => {
    for (const bad of [{ hideCoinsSent: 'yes' }, { hideCherriesReceived: null }, { hideCoinsSent: 1 }]) {
      const res = await ctx.http.patch('/api/v1/me/privacy').set(auth(other)).send(bad);
      expect(res.status, JSON.stringify(bad)).toBe(400);
    }
  });

  it("stores the switches on the user's privacy row", async () => {
    await setPrivacy(other, { hideCherriesReceived: true });
    const row = await ctx.prisma.privacySettings.findUniqueOrThrow({ where: { userId: other.id } });
    expect(row).toMatchObject({ hideCherriesReceived: true, hideCoinsSent: false });
  });
});
