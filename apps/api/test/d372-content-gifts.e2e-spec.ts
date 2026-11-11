/**
 * D372 (owner 2026-11-11): «هدية الدعم» — gifts on posts and reels (openapi v1.127-social DRAFT, CONVENTIONS §10.164),
 * end to end against PostgreSQL + Redis with the API as the DML-only runtime role. Covers: the send with coins and from
 * the bag, the idempotent retry, insufficient coins / bag, the recipient rules (host, creator, not a creator, own post,
 * a block, a deleted post, an inactive author, comments off, lucky gifts), the author's cherries at the live share,
 * charm and support levels, family points, the gift line in both orders and the comment count, `Post.giftCherries` and
 * `Post.giftable`, the grouped notification, a reversal, concurrent sends and the rate limit.
 */
import { randomUUID } from 'node:crypto';
import { afterAll, beforeAll, describe, expect, it, vi } from 'vitest';
import { reverseGiftCherriesIn } from '../src/modules/economy/cherry-ledger.js';
import { giftCherries } from '../src/modules/economy/economy-math.js';
import { addGiftIn, type GiftFields } from '../src/modules/gifts/gift-catalogue.js';
import { creditIn } from '../src/modules/wallet/wallet-ledger.js';
import { panel, type Admin } from './helpers/admin-panel.js';
import { expectContract, operations } from './helpers/openapi.js';
import { createTestApp, registerVerified, type TestContext } from './helpers/test-app.js';

interface TestUser {
  readonly id: string;
  readonly username: string;
  readonly token: string;
}

describe('D372 contract coverage', () => {
  it('openapi declares the content gift operation', () => {
    const ids = operations().map((o) => `${o.operationId} ${o.method.toUpperCase()} ${o.path}`);
    expect(ids).toContain('sendContentGift POST /api/v1/posts/{postId}/gifts');
  });
});

describe('D372 content gifts', { timeout: 300_000 }, () => {
  let ctx: TestContext;
  let seq = 0;

  const auth = (u: { token: string }) => ({ Authorization: `Bearer ${u.token}` });
  const signup = async (): Promise<TestUser> => {
    const { res } = await registerVerified(ctx);
    expect(res.status).toBe(201);
    return {
      id: res.body.user.id as string,
      username: res.body.user.username as string,
      token: res.body.tokens.accessToken as string,
    };
  };
  const makeHost = (u: TestUser) => ctx.prisma.liveHost.create({ data: { userId: u.id, source: 'ADMIN' } });
  const makeCreator = async (u: TestUser) => {
    const app = await ctx.prisma.creatorApplication.create({
      data: {
        userId: u.id,
        status: 'APPROVED',
        country: 'EG',
        category: 'COMEDY',
        links: ['https://www.tiktok.com/@creator'],
        decidedAt: new Date(),
      },
    });
    await ctx.prisma.creatorMember.create({
      data: { userId: u.id, applicationId: app.id, activatedAt: new Date() },
    });
    // The membership grants hosting, as the panel's approval does (D295).
    await ctx.prisma.liveHost.create({ data: { userId: u.id, source: 'CREATOR' } });
  };
  const newPost = async (u: TestUser, extra: object = {}): Promise<string> => {
    const res = await ctx.http
      .post('/api/v1/posts')
      .set(auth(u))
      .set('Idempotency-Key', randomUUID())
      .send({ text: 'a post', ...extra });
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    return res.body.id as string;
  };
  const coins = (u: TestUser, amount: number) =>
    ctx.prisma.$transaction((tx) => creditIn(tx, u.id, BigInt(amount), 'ADMIN_GRANT', randomUUID()));
  const wallet = async (u: TestUser) =>
    Number((await ctx.prisma.wallet.findUnique({ where: { userId: u.id } }))?.coins ?? 0n);
  const cherries = async (u: TestUser) =>
    (
      await ctx.prisma.cherryLedgerEntry.findMany({ where: { userId: u.id, reason: 'GIFT_RECEIVED' } })
    ).reduce((s, e) => s + e.delta, 0n);
  const gift = async (fields: Partial<GiftFields> = {}): Promise<string> => {
    seq += 1;
    const code = `cg${String(seq)}_${randomUUID().slice(0, 6)}`;
    await ctx.prisma.$transaction((tx) =>
      addGiftIn(tx, code, {
        category: 'POPULAR',
        nameAr: `وردة ${String(seq)}`,
        nameEn: `Rose ${String(seq)}`,
        priceCoins: 10,
        assetKey: `gift_${code}`,
        animationKey: null,
        sortOrder: seq,
        badge: 'NONE',
        tagCode: null,
        tagNameAr: null,
        tagNameEn: null,
        ...fields,
      }),
    );
    return code;
  };
  const sendGift = (by: TestUser, postId: string, body: Record<string, unknown>) =>
    ctx.http
      .post(`/api/v1/posts/${postId}/gifts`)
      .set(auth(by))
      .send({ quantity: 1, source: 'COINS', clientId: randomUUID(), ...body });
  const getPost = async (u: TestUser, postId: string) => {
    const res = await ctx.http.get(`/api/v1/posts/${postId}`).set(auth(u));
    expect(res.status).toBe(200);
    expectContract(res, 'getPost');
    return res.body as { giftCherries: number; giftable: boolean; commentCount: number };
  };
  const comments = async (u: TestUser, postId: string, sort = 'RELEVANT') => {
    const res = await ctx.http.get(`/api/v1/posts/${postId}/comments?sort=${sort}`).set(auth(u));
    expect(res.status).toBe(200);
    expectContract(res, 'listComments');
    return res.body.data as {
      id: string;
      kind: string;
      text: string;
      gift: unknown;
      author: { id: string };
    }[];
  };
  const publish = async (code: 'ATTRACTIVENESS' | 'SUPPORT') => {
    const category = await ctx.prisma.levelCategory.create({
      data: { code, nameAr: 'فئة', nameEn: code, descriptionAr: 'وصف', descriptionEn: 'About' },
    });
    const version = await ctx.prisma.levelCategoryVersion.create({
      data: {
        categoryId: category.id,
        versionNumber: 1,
        status: 'PUBLISHED',
        multiplier: '1',
        valueUnit: 'COIN',
        publishedAt: new Date(),
        levels: { create: [{ levelNumber: 1, nameAr: 'أ', nameEn: 'A', requiredPoints: 0n }] },
      },
    });
    await ctx.prisma.levelCategory.update({
      where: { id: category.id },
      data: { isEnabled: true, publishedVersionId: version.id },
    });
  };
  const expectRefused = async (
    res: { status: number; body: { error?: { code: string; details?: unknown } } },
    status: number,
    code: string,
  ) => {
    expect(res.status, JSON.stringify(res.body)).toBe(status);
    expect(res.body.error?.code).toBe(code);
    expectContract(res as never, 'sendContentGift');
  };

  beforeAll(async () => {
    ctx = await createTestApp();
    await publish('ATTRACTIVENESS');
    await publish('SUPPORT');
  });
  afterAll(async () => ctx?.close());

  it('a COINS send to a host: one debit, the gift line, the cherries at the live share, levels, family and the counter', async () => {
    const [host, fan] = [await signup(), await signup()];
    await makeHost(host);
    const postId = await newPost(host);
    expect((await getPost(fan, postId)).giftable).toBe(true);
    expect((await getPost(host, postId)).giftable).toBe(false);
    const family = await ctx.prisma.family.create({
      data: { name: `Fam ${randomUUID().slice(0, 6)}`, nameKey: randomUUID(), createClientId: randomUUID() },
    });
    await ctx.prisma.familyMember.create({ data: { userId: fan.id, familyId: family.id } });
    // The gift's name follows the reader's account language.
    await ctx.prisma.userProfile.update({ where: { userId: fan.id }, data: { locale: 'ar' } });
    await ctx.prisma.userProfile.update({ where: { userId: host.id }, data: { locale: 'en' } });
    await coins(fan, 1000);
    const code = await gift({ priceCoins: 30 });
    const clientId = randomUUID();

    const res = await sendGift(fan, postId, { giftCode: code, quantity: 10, clientId });
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    expectContract(res, 'sendContentGift');
    // A host without an agency is a direct host: 70 % (D341), as a live send to them alone.
    const share = ctx.config.gifts.directHostShareBps;
    const earned = giftCherries(300n, share, ctx.config.economy.cherriesPerCoin);
    expect(res.body).toMatchObject({ coins: 700, bagQuantity: 0, giftCherries: Number(earned) });
    expect(res.body.comment).toMatchObject({
      kind: 'GIFT',
      text: '',
      parentId: null,
      author: { id: fan.id },
      gift: {
        giftCode: code,
        name: `وردة ${String(seq)}`,
        quantity: 10,
        assetKey: `gift_${code}`,
        imageUrl: null,
      },
    });
    expect(await wallet(fan)).toBe(700);

    const send = await ctx.prisma.liveGift.findFirstOrThrow({ where: { senderId: fan.id, clientId } });
    expect(send).toMatchObject({ postId, roomId: null, dmConversationId: null, hostShareBps: share });
    const ledger = await ctx.prisma.walletLedgerEntry.findMany({
      where: { userId: fan.id, referenceId: send.id },
    });
    expect(ledger.map((l) => [l.reason, l.delta])).toEqual([['CONTENT_GIFT', -300n]]);
    expect(await cherries(host)).toBe(earned);
    // Charm for the author and support for the sender: the full value, as a live gift.
    const points = await ctx.prisma.pointsLedgerEntry.findMany({
      where: { sourceTransactionId: `gift:${send.id}:${host.id}` },
      orderBy: { sourceType: 'asc' },
    });
    expect(points.map((p) => [p.userId, p.sourceType, p.sourceValue])).toEqual([
      [host.id, 'GIFT_RECEIVED', 300n],
      [fan.id, 'GIFT_SENT', 300n],
    ]);
    // The sender's family counts the coins.
    expect((await ctx.prisma.family.findUniqueOrThrow({ where: { id: family.id } })).points).toBe(300n);

    // The line in both orders; it counts in the comment count; the counter is the author's cherries.
    for (const sort of ['RELEVANT', 'NEWEST']) {
      const list = await comments(host, postId, sort);
      expect(list.map((c) => c.id)).toEqual([res.body.comment.id]);
      expect(list[0]!.gift).toMatchObject({ name: `Rose ${String(seq)}` });
    }
    const after = await getPost(fan, postId);
    expect(after).toMatchObject({ commentCount: 1, giftCherries: Number(earned) });

    // The retry: the same send, nothing charged again.
    const again = await sendGift(fan, postId, { giftCode: code, quantity: 10, clientId });
    expect(again.status).toBe(200);
    expectContract(again, 'sendContentGift');
    expect(again.body).toMatchObject({ coins: 700, giftCherries: Number(earned) });
    expect(again.body.comment.id).toBe(res.body.comment.id);
    expect(await ctx.prisma.liveGift.count({ where: { senderId: fan.id } })).toBe(1);
    // The same clientId on another post is a conflict.
    const other = await newPost(host);
    await expectRefused(
      await sendGift(fan, other, { giftCode: code, clientId }),
      409,
      'IDEMPOTENCY_CONFLICT',
    );

    // A text comment and a gift line sit together; a reply to the line works like any.
    const text = await ctx.http
      .post(`/api/v1/posts/${postId}/comments`)
      .set(auth(host))
      .send({ text: 'شكراً' });
    expect(text.status).toBe(201);
    expectContract(text, 'createComment');
    expect(text.body).toMatchObject({ kind: 'TEXT', gift: null });
    const newest = await comments(fan, postId, 'NEWEST');
    expect(newest.map((c) => c.kind)).toEqual(['TEXT', 'GIFT']);
  });

  it('notifies the author once per post; a second sender joins the row; pushes word it', async () => {
    const [host, a, b] = [await signup(), await signup(), await signup()];
    await makeHost(host);
    const postId = await newPost(host);
    const code = await gift();
    for (const u of [a, b]) {
      await coins(u, 100);
      expect((await sendGift(u, postId, { giftCode: code })).status).toBe(201);
    }
    const res = await ctx.http.get('/api/v1/notifications').set(auth(host));
    expect(res.status).toBe(200);
    expectContract(res, 'listNotifications');
    const rows = (
      res.body.data as { type: string; actorCount: number; target: { type: string; id: string } }[]
    ).filter((n) => n.type === 'CONTENT_GIFT_RECEIVED');
    expect(rows).toHaveLength(1);
    expect(rows[0]).toMatchObject({ actorCount: 2, target: { type: 'POST', id: postId } });
  });

  it('a creator member receives at the creator share; a person who is neither is refused', async () => {
    const [creator, plain, fan] = [await signup(), await signup(), await signup()];
    await makeCreator(creator);
    await coins(fan, 1000);
    const code = await gift({ priceCoins: 100 });
    const creatorPost = await newPost(creator);
    const ok = await sendGift(fan, creatorPost, { giftCode: code });
    expect(ok.status, JSON.stringify(ok.body)).toBe(201);
    const send = await ctx.prisma.liveGift.findFirstOrThrow({
      where: { senderId: fan.id, postId: creatorPost },
    });
    // A creator member without an agency: max(creator 70 %, direct creator 75 %).
    expect(send.hostShareBps).toBe(
      Math.max(ctx.config.gifts.creatorShareBps, ctx.config.gifts.directCreatorShareBps),
    );

    const plainPost = await newPost(plain);
    expect((await getPost(fan, plainPost)).giftable).toBe(false);
    const refused = await sendGift(fan, plainPost, { giftCode: code });
    await expectRefused(refused, 409, 'CONTENT_GIFT_RECIPIENT_UNAVAILABLE');
    expect(refused.body.error.details).toEqual([{ field: 'post', issue: 'not_creator' }]);
    const own = await sendGift(creator, creatorPost, { giftCode: code });
    await expectRefused(own, 409, 'CONTENT_GIFT_RECIPIENT_UNAVAILABLE');
    expect(own.body.error.details).toEqual([{ field: 'post', issue: 'own_content' }]);
    expect(await wallet(fan)).toBe(900);
  });

  it('refuses blocked, deleted, inactive, closed and lucky — nothing charged', async () => {
    const [host, fan] = [await signup(), await signup()];
    await makeHost(host);
    await coins(fan, 1000);
    const code = await gift();

    const blockedPost = await newPost(host);
    expect((await ctx.http.put(`/api/v1/users/${fan.username}/block`).set(auth(host))).status).toBeLessThan(
      300,
    );
    await expectRefused(await sendGift(fan, blockedPost, { giftCode: code }), 404, 'NOT_FOUND');
    expect(
      (await ctx.http.delete(`/api/v1/users/${fan.username}/block`).set(auth(host))).status,
    ).toBeLessThan(300);

    const gone = await newPost(host);
    expect((await ctx.http.delete(`/api/v1/posts/${gone}`).set(auth(host))).status).toBe(204);
    await expectRefused(await sendGift(fan, gone, { giftCode: code }), 404, 'NOT_FOUND');

    const closed = await newPost(host, { settings: { commentsEnabled: false } });
    await expectRefused(await sendGift(fan, closed, { giftCode: code }), 403, 'AUTH_FORBIDDEN');

    const open = await newPost(host);
    const lucky = await gift({ category: 'LUCKY', priceCoins: 100 });
    await expectRefused(await sendGift(fan, open, { giftCode: lucky }), 409, 'GIFT_UNAVAILABLE');
    await expectRefused(await sendGift(fan, open, { giftCode: 'no_such_gift' }), 409, 'GIFT_UNAVAILABLE');
    const bad = await sendGift(fan, open, { giftCode: code, quantity: 7 });
    await expectRefused(bad, 400, 'VALIDATION_FAILED');

    await ctx.prisma.user.update({ where: { id: host.id }, data: { status: 'SUSPENDED' } });
    await expectRefused(await sendGift(fan, open, { giftCode: code }), 404, 'NOT_FOUND');
    await ctx.prisma.user.update({ where: { id: host.id }, data: { status: 'ACTIVE' } });

    expect(await wallet(fan)).toBe(1000);
    expect(await ctx.prisma.liveGift.count({ where: { senderId: fan.id } })).toBe(0);
    expect(await ctx.prisma.comment.count({ where: { authorId: fan.id } })).toBe(0);
  });

  it('insufficient coins and an empty bag are refused; a bag send consumes the stock and charges nothing', async () => {
    const [host, fan] = [await signup(), await signup()];
    await makeHost(host);
    const postId = await newPost(host);
    const code = await gift({ priceCoins: 50 });
    await coins(fan, 40);
    await expectRefused(await sendGift(fan, postId, { giftCode: code }), 409, 'INSUFFICIENT_COINS');
    await expectRefused(
      await sendGift(fan, postId, { giftCode: code, source: 'BAG' }),
      409,
      'GIFT_BAG_INSUFFICIENT',
    );
    expect(await ctx.prisma.comment.count({ where: { postId } })).toBe(0);

    await ctx.prisma.userGiftStock.create({ data: { userId: fan.id, giftCode: code, quantity: 12 } });
    const bag = await sendGift(fan, postId, { giftCode: code, source: 'BAG', quantity: 10 });
    expect(bag.status, JSON.stringify(bag.body)).toBe(201);
    expectContract(bag, 'sendContentGift');
    expect(bag.body).toMatchObject({ coins: 40, bagQuantity: 2 });
    const send = await ctx.prisma.liveGift.findFirstOrThrow({ where: { senderId: fan.id, postId } });
    expect(send).toMatchObject({ source: 'BAG', coinsCharged: 0n, totalCoins: 500n });
    expect(await ctx.prisma.walletLedgerEntry.count({ where: { referenceId: send.id } })).toBe(0);
    expect(await cherries(host)).toBeGreaterThan(0n);
  });

  it('a reversal takes the credit off the post counter', async () => {
    const [host, fan] = [await signup(), await signup()];
    await makeHost(host);
    const postId = await newPost(host);
    await coins(fan, 1000);
    const code = await gift({ priceCoins: 100 });
    const first = await sendGift(fan, postId, { giftCode: code });
    const second = await sendGift(fan, postId, { giftCode: code });
    expect([first.status, second.status]).toEqual([201, 201]);
    const each = BigInt(first.body.giftCherries as number);
    expect(second.body.giftCherries).toBe(Number(each * 2n));
    const send = await ctx.prisma.liveGift.findFirstOrThrow({
      where: { senderId: fan.id, postId },
      orderBy: { createdAt: 'asc' },
    });
    await ctx.prisma.$transaction((tx) => reverseGiftCherriesIn(tx, send.id, new Date()));
    expect((await getPost(fan, postId)).giftCherries).toBe(Number(each));
  });

  it('concurrent sends: one conditional debit each, never below 0', async () => {
    const [host, fan] = [await signup(), await signup()];
    await makeHost(host);
    const postId = await newPost(host);
    await coins(fan, 30);
    const code = await gift({ priceCoins: 10 });
    const results = await Promise.all(
      Array.from({ length: 6 }, () => sendGift(fan, postId, { giftCode: code })),
    );
    const statuses = results.map((r) => r.status).sort();
    expect(statuses).toEqual([201, 201, 201, 409, 409, 409]);
    for (const r of results.filter((x) => x.status === 409))
      expect(r.body.error.code).toBe('INSUFFICIENT_COINS');
    expect(await wallet(fan)).toBe(0);
    const post = await ctx.prisma.post.findUniqueOrThrow({ where: { id: postId } });
    expect(post.commentCount).toBe(3);
    expect(post.giftCherries).toBe(
      3n * giftCherries(10n, ctx.config.gifts.directHostShareBps, ctx.config.economy.cherriesPerCoin),
    );
  });
});

describe('D372 rate limit', { timeout: 120_000 }, () => {
  let ctx: TestContext;
  beforeAll(async () => {
    ctx = await createTestApp({ RATE_LIMIT_LIVE_GIFT_USER: '2/60' });
  });
  afterAll(async () => ctx?.close());

  it('as a live gift: the third send in a minute is 429, nothing charged', async () => {
    const reg = async () => {
      const { res } = await registerVerified(ctx);
      return { id: res.body.user.id as string, token: res.body.tokens.accessToken as string };
    };
    const [host, fan] = [await reg(), await reg()];
    await ctx.prisma.liveHost.create({ data: { userId: host.id, source: 'ADMIN' } });
    const post = await ctx.http
      .post('/api/v1/posts')
      .set({ Authorization: `Bearer ${host.token}` })
      .set('Idempotency-Key', randomUUID())
      .send({ text: 'rate' });
    const code = `rl_${randomUUID().slice(0, 6)}`;
    await ctx.prisma.$transaction(async (tx) => {
      await addGiftIn(tx, code, {
        category: 'POPULAR',
        nameAr: 'هدية',
        nameEn: 'Gift',
        priceCoins: 10,
        assetKey: 'gift_rl',
        animationKey: null,
        sortOrder: 1,
        badge: 'NONE',
        tagCode: null,
        tagNameAr: null,
        tagNameEn: null,
      });
      await creditIn(tx, fan.id, 1000n, 'ADMIN_GRANT', randomUUID());
    });
    const send = () =>
      ctx.http
        .post(`/api/v1/posts/${post.body.id as string}/gifts`)
        .set({ Authorization: `Bearer ${fan.token}` })
        .send({ giftCode: code, quantity: 1, source: 'COINS', clientId: randomUUID() });
    expect((await send()).status).toBe(201);
    expect((await send()).status).toBe(201);
    const third = await send();
    expect(third.status).toBe(429);
    expect(third.body.error.code).toBe('RATE_LIMITED');
    expect(Number((await ctx.prisma.wallet.findUniqueOrThrow({ where: { userId: fan.id } })).coins)).toBe(
      980,
    );
  });
});

describe('D372 the panel', { timeout: 120_000 }, () => {
  let ctx: TestContext;
  const p = panel(() => ctx);
  let owner: Admin;
  beforeAll(async () => {
    vi.useFakeTimers({ toFake: ['Date'], now: p.start() });
    ctx = await createTestApp({
      ADMIN_TOTP_KEY: 'admin-totp-test-key-0123456789-abcdefghijklmnop',
      ADMIN_SESSION_IDLE_SECONDS: '86400',
      ADMIN_SESSION_MAX_SECONDS: '604800',
      RATE_LIMIT_ADMIN_LOGIN_IP: '10000/900',
      RATE_LIMIT_ADMIN_IP: '100000/900',
    });
    owner = await p.makeAdmin(['OWNER']);
  });
  afterAll(async () => {
    await ctx?.close();
    vi.useRealTimers();
  });

  it('the sender’s coin ledger shows CONTENT_GIFT; the author’s cherries GIFT_RECEIVED', async () => {
    const reg = async () => {
      const { res } = await registerVerified(ctx);
      return { id: res.body.user.id as string, token: res.body.tokens.accessToken as string };
    };
    const [host, fan] = [await reg(), await reg()];
    await ctx.prisma.liveHost.create({ data: { userId: host.id, source: 'ADMIN' } });
    const post = await ctx.http
      .post('/api/v1/posts')
      .set({ Authorization: `Bearer ${host.token}` })
      .set('Idempotency-Key', randomUUID())
      .send({ text: 'panel' });
    const code = `pn_${randomUUID().slice(0, 6)}`;
    await ctx.prisma.$transaction(async (tx) => {
      await addGiftIn(tx, code, {
        category: 'POPULAR',
        nameAr: 'هدية',
        nameEn: 'Gift',
        priceCoins: 100,
        assetKey: 'gift_pn',
        animationKey: null,
        sortOrder: 1,
        badge: 'NONE',
        tagCode: null,
        tagNameAr: null,
        tagNameEn: null,
      });
      await creditIn(tx, fan.id, 1000n, 'ADMIN_GRANT', randomUUID());
    });
    const sent = await ctx.http
      .post(`/api/v1/posts/${post.body.id as string}/gifts`)
      .set({ Authorization: `Bearer ${fan.token}` })
      .send({ giftCode: code, quantity: 1, source: 'COINS', clientId: randomUUID() });
    expect(sent.status, JSON.stringify(sent.body)).toBe(201);
    const coins = await p.send(owner, 'get', `/admin/users/${fan.id}/ledger?kind=coins`);
    expect(coins.status, JSON.stringify(coins.body)).toBe(200);
    expectContract(coins, 'listAdminUserLedger');
    // Both rows carry the same (faked) clock, so look the row up instead of relying on the order.
    expect(coins.body.data).toEqual(
      expect.arrayContaining([expect.objectContaining({ reason: 'CONTENT_GIFT', delta: -100 })]),
    );
    const cherries = await p.send(owner, 'get', `/admin/users/${host.id}/ledger?kind=cherries`);
    expect(cherries.status).toBe(200);
    expectContract(cherries, 'listAdminUserLedger');
    expect(cherries.body.data).toEqual(
      expect.arrayContaining([expect.objectContaining({ reason: 'GIFT_RECEIVED' })]),
    );
  });
});
