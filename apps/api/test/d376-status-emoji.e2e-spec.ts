/**
 * D376 (the owner sent the «الحالة» pack, 2026-11-12; contract v1.130-social, CONVENTIONS §10.167): the status emoji
 * worn over the picture and «متجر الحالة», end to end against PostgreSQL + Redis with the API as the DML-only runtime
 * role:
 *
 *  - set / clear a free status (`PUT /me/status`), an unknown id refused, the same value twice, the audit;
 *  - the status in `Me`, the public profile, comments (UserSummary), the live room's host and the seats;
 *  - «المميزة»: listed with the server's price (100 000 coins / 30 days); a sold pack's emoji refused until bought;
 *    buy (201, coins taken, ledger `STATUS_PACK_PURCHASE`), the Idempotency-Key replay (200, nothing charged twice)
 *    and conflict, renew while held (days added), insufficient coins (409, nothing charged), a changed price, a
 *    disabled price; on expiry the emoji reads as none everywhere and the next listing clears the row.
 */
import { randomUUID } from 'node:crypto';
import { afterAll, beforeAll, describe, expect, it, vi } from 'vitest';
import { LIVE_MEDIA_PROVIDER } from '../src/modules/live/media/live-media.provider.js';
import { allStatusEmojiIds } from '../src/modules/status-emoji/status-emoji-catalogue.js';
import { creditIn } from '../src/modules/wallet/wallet-ledger.js';
import { MemoryLiveMedia } from './helpers/memory-live-media.js';
import { expectContract, operations } from './helpers/openapi.js';
import { createTestApp, registerVerified, type TestContext } from './helpers/test-app.js';

const DAY = 86_400_000;
const PRICE = 100_000;

interface TestUser {
  readonly id: string;
  readonly username: string;
  readonly token: string;
}

describe('D376 contract coverage', () => {
  it('openapi v1.130-social declares the status operations', () => {
    const ids = operations()
      .filter((o) => o.path === '/api/v1/me/status' || o.path.startsWith('/api/v1/status-packs'))
      .map((o) => `${o.operationId} ${o.method.toUpperCase()} ${o.path}`)
      .sort();
    expect(ids).toEqual([
      'buyStatusPack POST /api/v1/status-packs/{packId}/purchases',
      'listStatusPacks GET /api/v1/status-packs',
      'setMyStatusEmoji PUT /api/v1/me/status',
    ]);
  });
});

describe('D376 «الحالة»', { timeout: 180_000 }, () => {
  let ctx: TestContext;
  const media = new MemoryLiveMedia();
  const start = new Date('2027-05-05T10:00:00.000Z');

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
  const setStatus = (u: TestUser, statusEmojiId: string | null) =>
    ctx.http.put('/api/v1/me/status').set(auth(u)).send({ statusEmojiId });
  const coins = (u: TestUser, amount: number) =>
    ctx.prisma.$transaction((tx) => creditIn(tx, u.id, BigInt(amount), 'ADMIN_GRANT', randomUUID()));
  const balance = async (u: TestUser) =>
    Number((await ctx.prisma.wallet.findUnique({ where: { userId: u.id } }))?.coins ?? 0n);
  const packs = async (u: TestUser) => {
    const res = await ctx.http.get('/api/v1/status-packs').set(auth(u));
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    expectContract(res, 'listStatusPacks');
    return res.body as {
      data: { id: string; emojiIds: string[]; options: { days: number; coins: number }[]; expiresAt: string | null }[];
      coins: number;
    };
  };
  const buy = (u: TestUser, body: { days: number; price: number }, key: string = randomUUID(), pack = 'premium') =>
    ctx.http.post(`/api/v1/status-packs/${pack}/purchases`).set(auth(u)).set('Idempotency-Key', key).send(body);
  const me = async (u: TestUser) => {
    const res = await ctx.http.get('/api/v1/me').set(auth(u));
    expect(res.status).toBe(200);
    expectContract(res, 'getMe');
    return res.body as { statusEmojiId: string | null };
  };
  const profile = async (viewer: TestUser, of: TestUser) => {
    const res = await ctx.http.get(`/api/v1/users/${of.username}`).set(auth(viewer));
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    expectContract(res, 'getPublicProfile');
    return res.body as { statusEmojiId: string | null };
  };
  const now = () => new Date();

  beforeAll(async () => {
    vi.useFakeTimers({ toFake: ['Date'], now: start });
    ctx = await createTestApp({ LIVE_HOSTING_ENABLED: 'true', LIVE_HEARTBEAT_STALE_SECONDS: '36000000' }, [
      { token: LIVE_MEDIA_PROVIDER, value: media },
    ]);
  });
  afterAll(async () => {
    await ctx?.close();
    vi.useRealTimers();
  });

  it('sets, keeps and clears a free status; refuses an unknown id; audits the change (no N+1 select)', async () => {
    const u = await signup();
    expect((await me(u)).statusEmojiId).toBeNull();

    const set = await setStatus(u, 'kabi.crown');
    expect(set.status, JSON.stringify(set.body)).toBe(200);
    expectContract(set, 'setMyStatusEmoji');
    expect(set.body.statusEmojiId).toBe('kabi.crown');
    expect((await me(u)).statusEmojiId).toBe('kabi.crown');

    // Every free pack's emoji is accepted (Kabso packs and «عام»).
    for (const id of ['flags.jo', 'noto.fire', 'neno.serenade', 'lulu.rainbow']) {
      const res = await setStatus(u, id);
      expect(res.status, id).toBe(200);
      expect(res.body.statusEmojiId).toBe(id);
    }

    // Unknown, malformed and wrong-type values: 400, nothing changed.
    for (const bad of ['kabi.nope', 'nope.crown', 'kabi_crown', 'KABI.CROWN', '', 'x'.repeat(65)]) {
      const res = await setStatus(u, bad);
      expect(res.status, bad).toBe(400);
      expect(res.body.error.code).toBe('VALIDATION_FAILED');
    }
    const wrongType = await ctx.http.put('/api/v1/me/status').set(auth(u)).send({ statusEmojiId: 5 });
    expect(wrongType.status).toBe(400);
    const extra = await ctx.http.put('/api/v1/me/status').set(auth(u)).send({ statusEmojiId: null, x: 1 });
    expect(extra.status).toBe(400);
    expect((await me(u)).statusEmojiId).toBe('lulu.rainbow');

    // The same value: 200, no new audit row.
    const before = await ctx.prisma.auditLog.count({ where: { action: 'user.status.update', actorUserId: u.id } });
    expect((await setStatus(u, 'lulu.rainbow')).status).toBe(200);
    expect(await ctx.prisma.auditLog.count({ where: { action: 'user.status.update', actorUserId: u.id } })).toBe(
      before,
    );

    // «بدون حالة».
    const cleared = await setStatus(u, null);
    expect(cleared.status).toBe(200);
    expect(cleared.body.statusEmojiId).toBeNull();
    expect((await ctx.prisma.user.findUnique({ where: { id: u.id } }))?.statusEmojiId).toBeNull();
    const last = await ctx.prisma.auditLog.findFirst({
      where: { action: 'user.status.update', actorUserId: u.id },
      orderBy: { createdAt: 'desc' },
    });
    expect(last?.metadata).toEqual({ from: 'lulu.rainbow', to: null });

    // The database refuses a malformed id even past the API.
    await expect(
      ctx.prisma.user.update({ where: { id: u.id }, data: { statusEmojiId: 'Bad Id' } }),
    ).rejects.toThrow();
  });

  it('the status appears in the public profile, comments (UserSummary), the live room host and the seats', async () => {
    const star = await signup();
    const viewer = await signup();
    const plain = await signup();
    expect((await setStatus(star, 'noto.party')).status).toBe(200);

    expect((await profile(viewer, star)).statusEmojiId).toBe('noto.party');
    expect((await profile(viewer, plain)).statusEmojiId).toBeNull();

    // A comment's author.
    const post = await ctx.http
      .post('/api/v1/posts')
      .set(auth(star))
      .set('Idempotency-Key', randomUUID())
      .send({ text: 'D376' });
    expect(post.status, JSON.stringify(post.body)).toBe(201);
    expect(post.body.author.statusEmojiId).toBe('noto.party');
    const postId = post.body.id as string;
    for (const u of [star, plain]) {
      const c = await ctx.http.post(`/api/v1/posts/${postId}/comments`).set(auth(u)).send({ text: 'hi' });
      expect(c.status, JSON.stringify(c.body)).toBe(201);
    }
    const comments = await ctx.http.get(`/api/v1/posts/${postId}/comments`).set(auth(viewer));
    expect(comments.status).toBe(200);
    expectContract(comments, 'listComments');
    const authors = (comments.body.data as { author: { id: string; statusEmojiId?: string } }[]).map((c) => c.author);
    expect(authors.find((a) => a.id === star.id)?.statusEmojiId).toBe('noto.party');
    expect(authors.find((a) => a.id === plain.id)).not.toHaveProperty('statusEmojiId');

    // A live: the host (raw SQL summary) and a seated guest (UserSummary).
    await ctx.prisma.liveHost.create({ data: { userId: star.id, source: 'ADMIN' } });
    const room = await ctx.http
      .post('/api/v1/live/rooms')
      .set(auth(star))
      .send({ title: 'D376', mode: 'AUDIO', seatCount: 10 });
    expect(room.status, JSON.stringify(room.body)).toBe(201);
    const roomId = room.body.id as string;
    const card = await ctx.http.get(`/api/v1/live/rooms/${roomId}`).set(auth(viewer));
    expect(card.status).toBe(200);
    expectContract(card, 'getLiveRoom');
    expect(card.body.host.statusEmojiId).toBe('noto.party');

    expect((await setStatus(viewer, 'flags.ps')).status).toBe(200);
    const asked = await ctx.http
      .post(`/api/v1/live/rooms/${roomId}/seat-requests`)
      .set(auth(viewer))
      .send({ seatIndex: 2 });
    expect(asked.status, JSON.stringify(asked.body)).toBe(201);
    const accepted = await ctx.http
      .post(`/api/v1/live/rooms/${roomId}/seat-requests/${asked.body.id as string}/accept`)
      .set(auth(star))
      .send({});
    expect(accepted.status, JSON.stringify(accepted.body)).toBe(200);
    const seats = await ctx.http.get(`/api/v1/live/rooms/${roomId}/seats`).set(auth(plain));
    expect(seats.status).toBe(200);
    expectContract(seats, 'getLiveRoomSeats');
    const seat = (seats.body.seats as { index: number; user: { statusEmojiId?: string } | null }[]).find(
      (s) => s.index === 2,
    );
    expect(seat?.user?.statusEmojiId).toBe('flags.ps');
  });

  it('«المميزة»: listed at the server price; its emoji refused until bought; buy, replay, conflict, renew', async () => {
    const u = await signup();
    const list = await packs(u);
    const premium = list.data.find((p) => p.id === 'premium')!;
    expect(premium.options).toEqual([{ days: 30, coins: PRICE }]);
    expect(premium.expiresAt).toBeNull();
    expect(premium.emojiIds).toEqual(allStatusEmojiIds().store);
    expect(premium.emojiIds).toHaveLength(27);
    expect(list.coins).toBe(0);

    // Not held: 409 pack_not_owned, nothing changed.
    const refused = await setStatus(u, 'premium.eagle');
    expect(refused.status).toBe(409);
    expect(refused.body.error.code).toBe('STORE_UNAVAILABLE');
    expect(refused.body.error.details).toEqual([{ field: 'statusEmojiId', issue: 'pack_not_owned' }]);
    expect((await me(u)).statusEmojiId).toBeNull();

    // Not enough coins: 409, nothing charged, no pack.
    await coins(u, PRICE - 1);
    const poor = await buy(u, { days: 30, price: PRICE });
    expect(poor.status).toBe(409);
    expect(poor.body.error.code).toBe('INSUFFICIENT_COINS');
    expect(await balance(u)).toBe(PRICE - 1);
    expect(await ctx.prisma.userStatusPack.count({ where: { userId: u.id } })).toBe(0);
    expect(await ctx.prisma.statusPackPurchase.count({ where: { userId: u.id } })).toBe(0);

    // Bad requests.
    expect((await buy(u, { days: 30, price: PRICE }, 'not-a-uuid')).status).toBe(400);
    const noKey = await ctx.http
      .post('/api/v1/status-packs/premium/purchases')
      .set(auth(u))
      .send({ days: 30, price: PRICE });
    expect(noKey.status).toBe(400);
    expect((await buy(u, { days: 30, price: PRICE }, randomUUID(), 'kabi')).status).toBe(404);
    expect((await buy(u, { days: 30, price: PRICE }, randomUUID(), 'NOPE')).status).toBe(404);

    // The price the app showed is only compared: another price → 409 STORE_PRICE_CHANGED; no 7-day option → not_priced.
    await coins(u, 1 + PRICE * 2);
    const cheap = await buy(u, { days: 30, price: 1 });
    expect(cheap.status).toBe(409);
    expect(cheap.body.error.code).toBe('STORE_PRICE_CHANGED');
    const week = await buy(u, { days: 7, price: PRICE });
    expect(week.status).toBe(409);
    expect(week.body.error).toMatchObject({ code: 'STORE_UNAVAILABLE', details: [{ field: 'days', issue: 'not_priced' }] });
    expect(await balance(u)).toBe(PRICE * 3);

    // Buy: 201, coins taken once, ledger row, pack until now + 30 days.
    const key = randomUUID();
    const bought = await buy(u, { days: 30, price: PRICE }, key);
    expect(bought.status, JSON.stringify(bought.body)).toBe(201);
    expectContract(bought, 'buyStatusPack');
    expect(bought.body).toMatchObject({ packId: 'premium', days: 30, price: PRICE, extended: false, coins: PRICE * 2 });
    const firstEnd = new Date(now().getTime() + 30 * DAY).toISOString();
    expect(bought.body.expiresAt).toBe(firstEnd);
    const ledger = await ctx.prisma.walletLedgerEntry.findMany({
      where: { userId: u.id, reason: 'STATUS_PACK_PURCHASE' },
    });
    expect(ledger).toHaveLength(1);
    expect(ledger[0]).toMatchObject({ delta: BigInt(-PRICE), referenceId: bought.body.id });
    expect(
      await ctx.prisma.auditLog.count({ where: { action: 'status_pack.purchase', actorUserId: u.id } }),
    ).toBe(1);

    // The same key and body: 200, the first answer, nothing charged again.
    const replay = await buy(u, { days: 30, price: PRICE }, key);
    expect(replay.status).toBe(200);
    expectContract(replay, 'buyStatusPack');
    expect(replay.body.id).toBe(bought.body.id);
    expect(await balance(u)).toBe(PRICE * 2);
    // The same key with another body: 409 IDEMPOTENCY_CONFLICT.
    const conflict = await buy(u, { days: 7, price: PRICE }, key);
    expect(conflict.status).toBe(409);
    expect(conflict.body.error.code).toBe('IDEMPOTENCY_CONFLICT');

    // Held: the emoji is accepted and shown.
    const worn = await setStatus(u, 'premium.eagle');
    expect(worn.status, JSON.stringify(worn.body)).toBe(200);
    expect(worn.body.statusEmojiId).toBe('premium.eagle');
    expect((await packs(u)).data.find((p) => p.id === 'premium')?.expiresAt).toBe(firstEnd);

    // Renew 10 days later: the 30 days are added to the 20 left (max(now, end) + days).
    vi.setSystemTime(new Date(now().getTime() + 10 * DAY));
    const renewed = await buy(u, { days: 30, price: PRICE });
    expect(renewed.status).toBe(201);
    expect(renewed.body.extended).toBe(true);
    expect(renewed.body.expiresAt).toBe(new Date(new Date(firstEnd).getTime() + 30 * DAY).toISOString());
    expect(renewed.body.coins).toBe(PRICE);
    expect(await ctx.prisma.statusPackPurchase.count({ where: { userId: u.id } })).toBe(2);
  });

  it('on expiry the emoji reads as none everywhere at once; the listing clears it; a new purchase starts from now', async () => {
    const u = await signup();
    const viewer = await signup();
    await coins(u, PRICE * 2);
    expect((await buy(u, { days: 30, price: PRICE })).status).toBe(201);
    expect((await setStatus(u, 'premium.peacock')).status).toBe(200);
    expect((await profile(viewer, u)).statusEmojiId).toBe('premium.peacock');

    // One second before the end: still shown. After it: none in Me, the profile and comments; the row still holds it.
    vi.setSystemTime(new Date(now().getTime() + 30 * DAY - 1000));
    expect((await me(u)).statusEmojiId).toBe('premium.peacock');
    vi.setSystemTime(new Date(now().getTime() + 2000));
    expect((await me(u)).statusEmojiId).toBeNull();
    expect((await profile(viewer, u)).statusEmojiId).toBeNull();
    const post = await ctx.http
      .post('/api/v1/posts')
      .set(auth(u))
      .set('Idempotency-Key', randomUUID())
      .send({ text: 'expired' });
    expect(post.status).toBe(201);
    expect(post.body.author).not.toHaveProperty('statusEmojiId');
    expect((await ctx.prisma.user.findUnique({ where: { id: u.id } }))?.statusEmojiId).toBe('premium.peacock');

    // Setting it again is refused; the listing shows the pack not held and clears the stored emoji.
    expect((await setStatus(u, 'premium.peacock')).status).toBe(409);
    expect((await packs(u)).data.find((p) => p.id === 'premium')?.expiresAt).toBeNull();
    expect((await ctx.prisma.user.findUnique({ where: { id: u.id } }))?.statusEmojiId).toBeNull();

    // A purchase after the end counts from now (not from the old end).
    const again = await buy(u, { days: 30, price: PRICE });
    expect(again.status).toBe(201);
    expect(again.body.extended).toBe(false);
    expect(again.body.expiresAt).toBe(new Date(now().getTime() + 30 * DAY).toISOString());
  });

  it('a disabled price is not sold; a held pack is still listed (no options)', async () => {
    const u = await signup();
    await coins(u, PRICE * 2);
    expect((await buy(u, { days: 30, price: PRICE })).status).toBe(201);
    await ctx.prisma.statusPackOffer.update({
      where: { packId_days: { packId: 'premium', days: 30 } },
      data: { enabled: false },
    });
    try {
      const listed = (await packs(u)).data.find((p) => p.id === 'premium');
      expect(listed?.options).toEqual([]);
      expect(listed?.expiresAt).not.toBeNull();
      const off = await buy(u, { days: 30, price: PRICE });
      expect(off.status).toBe(409);
      expect(off.body.error.details).toEqual([{ field: 'days', issue: 'not_priced' }]);
      const other = await signup();
      expect((await packs(other)).data.find((p) => p.id === 'premium')).toBeUndefined();
    } finally {
      await ctx.prisma.statusPackOffer.update({
        where: { packId_days: { packId: 'premium', days: 30 } },
        data: { enabled: true },
      });
    }
  });

  it('the purchases are append-only for the runtime role', async () => {
    await expect(ctx.prisma.statusPackPurchase.deleteMany({})).rejects.toThrow(/permission denied|42501/i);
    await expect(ctx.prisma.statusPackPurchase.updateMany({ data: { days: 1 } })).rejects.toThrow(
      /permission denied|42501/i,
    );
  });
});
