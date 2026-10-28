/**
 * D155 (owner 2026-10-28): direct messages (openapi v1.40-social DRAFT, CONVENTIONS §11.13), end to
 * end against PostgreSQL + Redis with the API as the DML-only runtime role, a fake clock, in-memory
 * object storage, a scripted lucky RNG and a **fake push sender**. Covers: conversations created by
 * the first message, message requests (3 messages, text only, accept/reply/follow), the privacy
 * setting, blocks, receipts and unread counts, mute, delete for me / for everyone (1 h), the 24-hour
 * retention sweeper (rows and files), pictures and voice notes, pack emojis, blocked words, reports
 * with snapshots (and their 30-day purge), the push hook, gifts in conversations (50 % charm share,
 * lucky at the lucky share, idempotent, requests, blocks) and the rate limits.
 */
import { randomUUID } from 'node:crypto';
import type { Redis } from 'ioredis';
import sharp from 'sharp';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { Clock } from '../src/common/time/clock.js';
import { addGiftIn, type GiftFields } from '../src/modules/gifts/gift-catalogue.js';
import { LuckyGiftsService } from '../src/modules/gifts/lucky-gifts.service.js';
import type { LuckyRng } from '../src/modules/gifts/lucky-odds.js';
import { LUCKY_RNG } from '../src/modules/gifts/lucky-rng.js';
import { OBJECT_STORAGE } from '../src/modules/media/object-storage.js';
import { DmSweeper } from '../src/modules/messages/dm-sweeper.js';
import {
  PUSH_SENDER,
  type PushMessage,
  type PushSendResult,
  type PushSender,
} from '../src/modules/push/push-sender.js';
import { creditIn } from '../src/modules/wallet/wallet-ledger.js';
import { REDIS } from '../src/redis/redis.module.js';
import { m4a } from './helpers/m4a.js';
import { MemoryObjectStorage } from './helpers/memory-storage.js';
import { expectContract, operations } from './helpers/openapi.js';
import {
  createTestApp,
  registerVerified,
  settle,
  withMigrationClient,
  type TestContext,
} from './helpers/test-app.js';

class FakeClock extends Clock {
  private ms = Date.now();
  now(): Date {
    return new Date(this.ms);
  }
  advance(seconds: number): void {
    this.ms += seconds * 1000;
  }
}

/** Every draw loses unless a value is scripted. */
class ScriptedRng implements LuckyRng {
  private queue: number[] = [];
  script(...values: number[]): void {
    this.queue = [...values];
  }
  int(): number {
    return this.queue.shift() ?? 999_999;
  }
}

class FakePushSender implements PushSender {
  readonly enabled = true;
  readonly sent: PushMessage[] = [];
  send(message: PushMessage): Promise<PushSendResult> {
    this.sent.push(message);
    return Promise.resolve({ sent: message.tokens.length, failed: 0, invalidTokens: [] });
  }
  to(token: string): PushMessage[] {
    return this.sent.filter((m) => m.tokens.includes(token));
  }
}

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

describe('D155 contract coverage', () => {
  it('openapi declares the direct message operations', () => {
    const ids = operations().map((o) => `${o.operationId} ${o.method.toUpperCase()} ${o.path}`);
    for (const op of [
      'listDmConversations GET /api/v1/dm/conversations',
      'getDmUnread GET /api/v1/dm/unread',
      'getDmPeer GET /api/v1/dm/peers/{username}',
      'listDmMessages GET /api/v1/dm/conversations/{conversationId}/messages',
      'sendDmMessage POST /api/v1/dm/messages',
      'sendDmGift POST /api/v1/dm/gifts',
      'markDmRead POST /api/v1/dm/conversations/{conversationId}/read',
      'acceptDmRequest POST /api/v1/dm/conversations/{conversationId}/accept',
      'deleteDmConversation DELETE /api/v1/dm/conversations/{conversationId}',
      'muteDmConversation PUT /api/v1/dm/conversations/{conversationId}/mute',
      'unmuteDmConversation DELETE /api/v1/dm/conversations/{conversationId}/mute',
      'deleteDmMessage DELETE /api/v1/dm/messages/{messageId}',
    ]) {
      expect(ids).toContain(op);
    }
  });
});

describe('D155 direct messages', { timeout: 240_000 }, () => {
  const clock = new FakeClock();
  const storage = new MemoryObjectStorage();
  const push = new FakePushSender();
  const rng = new ScriptedRng();
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
  const follow = async (by: TestUser, u: TestUser) => {
    const res = await ctx.http.put(`/api/v1/users/${u.username}/follow`).set(auth(by));
    expect(res.status, JSON.stringify(res.body)).toBeLessThan(300);
  };
  const block = async (by: TestUser, u: TestUser) => {
    const res = await ctx.http.put(`/api/v1/users/${u.username}/block`).set(auth(by));
    expect(res.status, JSON.stringify(res.body)).toBeLessThan(300);
  };
  const send = (by: TestUser, to: TestUser | string, body: Record<string, unknown>) =>
    ctx.http
      .post('/api/v1/dm/messages')
      .set(auth(by))
      .send({ to: typeof to === 'string' ? to : to.username, clientId: randomUUID(), ...body });
  const text = async (by: TestUser, to: TestUser, t = 'hello') => {
    const res = await send(by, to, { kind: 'TEXT', text: t });
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    expectContract(res, 'sendDmMessage');
    return res.body as {
      message: { id: string; conversationId: string };
      conversation: Record<string, unknown>;
    };
  };
  const list = async (u: TestUser, box = 'INBOX') => {
    const res = await ctx.http.get(`/api/v1/dm/conversations?box=${box}`).set(auth(u));
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    expectContract(res, 'listDmConversations');
    return res.body.data as {
      id: string;
      status: string;
      unreadCount: number;
      lastMessage: { id: string; text: string | null; read: boolean } | null;
      peer: { username: string };
      canSend: boolean;
      requestMessagesLeft: number | null;
      muted: boolean;
    }[];
  };
  const messages = async (u: TestUser, conversationId: string) => {
    const res = await ctx.http.get(`/api/v1/dm/conversations/${conversationId}/messages`).set(auth(u));
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    expectContract(res, 'listDmMessages');
    return res.body as {
      data: {
        id: string;
        kind: string;
        text: string | null;
        read: boolean;
        mine: boolean;
        gift: unknown;
        media: unknown;
      }[];
      conversation: { peerReadAt: string | null; status: string };
    };
  };
  const unread = async (u: TestUser) => {
    const res = await ctx.http.get('/api/v1/dm/unread').set(auth(u));
    expect(res.status).toBe(200);
    expectContract(res, 'getDmUnread');
    return res.body as { messages: number; conversations: number; requests: number };
  };
  const upload = async (u: TestUser, kind: string, contentType: string, bytes: Buffer) => {
    const slot = await ctx.http
      .post('/api/v1/media/uploads')
      .set(auth(u))
      .send({ kind, contentType, byteSize: bytes.length });
    expect(slot.status, JSON.stringify(slot.body)).toBe(201);
    expect(storage.upload(slot.body.uploadUrl, bytes, contentType)).toBe(true);
    const done = await ctx.http.post(`/api/v1/media/uploads/${slot.body.uploadId}/complete`).set(auth(u));
    expect(done.status, JSON.stringify(done.body)).toBe(200);
    expectContract(done, 'completeMediaUpload');
    return done.body as { id: string; type: string; durationMs?: number };
  };
  const picture = async (u: TestUser, kind = 'DM_IMAGE') => {
    const bytes = await sharp({
      create: { width: 400, height: 300, channels: 3, background: { r: 200, g: 30, b: 40 } },
    })
      .jpeg()
      .toBuffer();
    return upload(u, kind, 'image/jpeg', bytes);
  };
  /** Two people who follow each other (no requests between them). */
  const friends = async (): Promise<[TestUser, TestUser]> => {
    const [a, b] = [await signup(), await signup()];
    await follow(a, b);
    await follow(b, a);
    return [a, b];
  };
  const coins = (u: TestUser, amount: number) =>
    ctx.prisma.$transaction((tx) => creditIn(tx, u.id, BigInt(amount), 'ADMIN_GRANT', randomUUID()));
  const wallet = async (u: TestUser) =>
    Number((await ctx.prisma.wallet.findUnique({ where: { userId: u.id } }))?.coins ?? 0n);
  const gift = async (fields: Partial<GiftFields> = {}): Promise<string> => {
    seq += 1;
    const code = `d${String(seq)}_${randomUUID().slice(0, 6)}`;
    await ctx.prisma.$transaction((tx) =>
      addGiftIn(tx, code, {
        category: 'POPULAR',
        nameAr: `هدية ${String(seq)}`,
        nameEn: `Gift ${String(seq)}`,
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
  const sendGift = (by: TestUser, to: TestUser, body: Record<string, unknown>) =>
    ctx.http
      .post('/api/v1/dm/gifts')
      .set(auth(by))
      .send({ to: to.username, quantity: 1, source: 'COINS', clientId: randomUUID(), ...body });
  const sweep = () => ctx.app.get(DmSweeper).sweep();
  const registerPush = async (u: TestUser) => {
    const token = `fcm_${randomUUID().replaceAll('-', '')}`;
    const res = await ctx.http
      .put('/api/v1/me/push-token')
      .set(auth(u))
      .send({ token, platform: 'ANDROID', appVersion: '0.1.0' });
    expect(res.status).toBe(204);
    return token;
  };
  const clearThrottles = async () => {
    const redis = ctx.app.get<Redis>(REDIS);
    const prefix = ctx.config.redis.keyPrefix;
    const keys = await redis.keys(`${prefix}push:*`);
    if (keys.length > 0) await redis.unlink(...keys.map((k) => k.slice(prefix.length)));
  };
  const publish = async (code: 'ATTRACTIVENESS' | 'SUPPORT' | 'WIZARD') => {
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
        publishedAt: clock.now(),
        levels: { create: [{ levelNumber: 1, nameAr: 'أ', nameEn: 'A', requiredPoints: 0n }] },
      },
    });
    await ctx.prisma.levelCategory.update({
      where: { id: category.id },
      data: { isEnabled: true, publishedVersionId: version.id },
    });
  };

  beforeAll(async () => {
    ctx = await createTestApp(
      {
        ...MEDIA_ON,
        LUCKY_GIFTS_ENABLED: 'true',
        LUCKY_PITY_AFTER: '0',
        PUSH_MESSAGES_GAP_SECONDS: '0',
      },
      [
        { token: Clock, value: clock },
        { token: OBJECT_STORAGE, value: storage },
        { token: PUSH_SENDER, value: push },
        { token: LUCKY_RNG, value: rng },
      ],
    );
    await publish('ATTRACTIVENESS');
    await publish('SUPPORT');
    await publish('WIZARD');
    // The server's blocked words are cached for a minute: seeded before the first send.
    await withMigrationClient(async (c) => {
      await c.searchBlockedWord.deleteMany({ where: { word: 'spamword' } });
      await c.searchBlockedWord.create({ data: { word: 'spamword' } });
    });
  });
  afterAll(async () => ctx?.close());

  // ---- Sending, conversations and requests ----------------------------------------------------

  describe('sending and message requests', () => {
    it('validates the body (400), refuses oneself (400) and unknown people (404), needs a token', async () => {
      const [a, b] = [await signup(), await signup()];
      for (const body of [
        {},
        { kind: 'TEXT' },
        { kind: 'TEXT', text: '   ' },
        { kind: 'TEXT', text: 'x'.repeat(1001) },
        { kind: 'TEXT', text: 'a‮b' },
        { kind: 'TEXT', text: 'hi', token: ':kabi_hi:' },
        { kind: 'EMOJI', token: ':kabi_nope:' },
        { kind: 'IMAGE' },
        { kind: 'GIFT', text: 'x' },
        { kind: 'TEXT', text: 'hi', extra: 1 },
      ]) {
        const res = await send(a, b, body);
        expect(res.status, JSON.stringify(body)).toBe(400);
        expectContract(res, 'sendDmMessage');
      }
      const self = await send(a, a, { kind: 'TEXT', text: 'me' });
      expect(self.status).toBe(400);
      expect(self.body.error.details).toEqual([{ field: 'to', issue: 'invalid_value' }]);
      expect((await send(a, 'nobody_here_9', { kind: 'TEXT', text: 'x' })).status).toBe(404);
      expect((await ctx.http.post('/api/v1/dm/messages').send({})).status).toBe(401);
    });

    it('the first message creates the conversation; a stranger lands in requests; a retry is the same message', async () => {
      const [a, b] = [await signup(), await signup()];
      const clientId = randomUUID();
      const first = await send(a, b, { kind: 'TEXT', text: '  مرحبا  ', clientId });
      expect(first.status).toBe(201);
      expectContract(first, 'sendDmMessage');
      expect(first.body.message).toMatchObject({ kind: 'TEXT', text: 'مرحبا', mine: true, read: false });
      expect(first.body.conversation).toMatchObject({
        status: 'REQUEST_SENT',
        requestMessagesLeft: 2,
        canSend: true,
      });
      const again = await send(a, b, { kind: 'TEXT', text: 'different', clientId });
      expect(again.status).toBe(200);
      expect(again.body.message.id).toBe(first.body.message.id);

      expect((await list(a)).map((c) => [c.peer.username, c.status])).toEqual([[b.username, 'REQUEST_SENT']]);
      expect(await list(b)).toEqual([]);
      const requests = await list(b, 'REQUESTS');
      expect(requests.map((c) => [c.peer.username, c.status, c.unreadCount])).toEqual([
        [a.username, 'REQUEST_RECEIVED', 1],
      ]);
      expect(await unread(b)).toEqual({ messages: 0, conversations: 0, requests: 1 });

      const peer = await ctx.http.get(`/api/v1/dm/peers/${a.username}`).set(auth(b));
      expect(peer.status).toBe(200);
      expectContract(peer, 'getDmPeer');
      expect(peer.body).toMatchObject({
        canMessage: true,
        reason: null,
        conversation: { status: 'REQUEST_RECEIVED' },
      });
      const none = await ctx.http.get(`/api/v1/dm/peers/${(await signup()).username}`).set(auth(a));
      expect(none.body).toMatchObject({ conversation: null, canMessage: true, asRequest: true });
      expect((await ctx.http.get(`/api/v1/dm/peers/${a.username}`).set(auth(a))).status).toBe(400);
    });

    it('a request allows 3 messages, text/emoji only; a reply accepts it', async () => {
      const [a, b] = [await signup(), await signup()];
      await text(a, b, 'one');
      await text(a, b, 'two');
      const pic = await picture(a);
      const refused = await send(a, b, { kind: 'IMAGE', mediaId: pic.id });
      expect(refused.status).toBe(403);
      expect(refused.body.error.code).toBe('DM_REQUEST_TEXT_ONLY');
      const emoji = await send(a, b, { kind: 'EMOJI', token: ':kabi_love:' });
      expect(emoji.status).toBe(201);
      expect(emoji.body.conversation.requestMessagesLeft).toBe(0);
      const fourth = await send(a, b, { kind: 'TEXT', text: 'four' });
      expect(fourth.status).toBe(403);
      expect(fourth.body.error.code).toBe('DM_REQUEST_LIMIT');
      const peer = await ctx.http.get(`/api/v1/dm/peers/${b.username}`).set(auth(a));
      expect(peer.body).toMatchObject({ canMessage: false, reason: 'REQUEST_LIMIT' });
      // Deleting the request does not reset the count.
      const conv = (await list(b, 'REQUESTS'))[0]!;
      expect((await ctx.http.delete(`/api/v1/dm/conversations/${conv.id}`).set(auth(b))).status).toBe(204);
      expect(await list(b, 'REQUESTS')).toEqual([]);
      expect((await send(a, b, { kind: 'TEXT', text: 'five' })).body.error.code).toBe('DM_REQUEST_LIMIT');
      // The recipient replies (a moment later): both sides accepted, pictures allowed.
      clock.advance(1);
      await text(b, a, 'hi back');
      expect((await list(b)).map((c) => c.status)).toEqual(['ACCEPTED']);
      expect((await list(a)).map((c) => c.status)).toEqual(['ACCEPTED']);
      const ok = await send(a, b, { kind: 'IMAGE', mediaId: pic.id });
      expect(ok.status, JSON.stringify(ok.body)).toBe(201);
      expect(ok.body.message.media).toMatchObject({ id: pic.id, type: 'IMAGE' });
    });

    it('accepting moves the request to the inbox; a follower writes straight to the inbox', async () => {
      const [a, b] = [await signup(), await signup()];
      const sent = await text(a, b);
      const accept = await ctx.http
        .post(`/api/v1/dm/conversations/${sent.message.conversationId}/accept`)
        .set(auth(b));
      expect(accept.status).toBe(204);
      expectContract(accept, 'acceptDmRequest');
      expect((await list(b)).map((c) => c.status)).toEqual(['ACCEPTED']);
      expect((await list(a)).map((c) => c.status)).toEqual(['ACCEPTED']);
      expect((await unread(b)).messages).toBe(1);

      const [c, d] = [await signup(), await signup()];
      await follow(d, c);
      const direct = await text(c, d);
      expect(direct.conversation).toMatchObject({ status: 'ACCEPTED', requestMessagesLeft: null });
      expect((await list(d)).map((x) => x.peer.username)).toEqual([c.username]);
    });
  });

  // ---- Push -----------------------------------------------------------------------------------------

  describe('push', () => {
    it('kabso_messages with tag dm:<id>; never the sender; not when muted or switched off', async () => {
      const [a, b] = await friends();
      const tokenB = await registerPush(b);
      const tokenA = await registerPush(a);
      await clearThrottles();
      const t = await text(a, b, 'ping');
      await settle(ctx);
      const got = push.to(tokenB);
      expect(got).toHaveLength(1);
      expect(got[0]).toMatchObject({
        channel: 'messages',
        tag: `dm:${t.message.conversationId}`,
        body: 'ping',
        data: {
          kind: 'dm',
          channel: 'messages',
          conversationId: t.message.conversationId,
          messageId: t.message.id,
          senderUsername: a.username,
        },
      });
      expect(push.to(tokenA)).toHaveLength(0);

      await ctx.http.put(`/api/v1/dm/conversations/${t.message.conversationId}/mute`).set(auth(b));
      await text(a, b, 'muted');
      await settle(ctx);
      expect(push.to(tokenB)).toHaveLength(1);
      await ctx.http.delete(`/api/v1/dm/conversations/${t.message.conversationId}/mute`).set(auth(b));
      await ctx.http.patch('/api/v1/me/notification-settings').set(auth(b)).send({ messages: false });
      await text(a, b, 'off');
      await settle(ctx);
      expect(push.to(tokenB)).toHaveLength(1);
      await ctx.http.patch('/api/v1/me/notification-settings').set(auth(b)).send({ messages: true });
      const pic = await picture(a);
      await send(a, b, { kind: 'IMAGE', mediaId: pic.id });
      await settle(ctx);
      expect(push.to(tokenB).map((m) => m.body)).toEqual(['ping', '📷 Photo']);
    });

    it('a request says so; a gift says how many', async () => {
      const [a, b] = [await signup(), await signup()];
      const tokenB = await registerPush(b);
      await text(a, b, 'hey');
      await settle(ctx);
      expect(push.to(tokenB).map((m) => m.body)).toEqual(['Message request: hey']);
      await follow(b, a);
      await coins(a, 100);
      const code = await gift();
      const g = await sendGift(a, b, { giftCode: code, quantity: 1 });
      expect(g.status, JSON.stringify(g.body)).toBe(201);
      await settle(ctx);
      expect(push.to(tokenB).map((m) => m.body)).toEqual(['Message request: hey', '🎁 Sent you a gift ×1']);
    });
  });

  // ---- Privacy and blocks -----------------------------------------------------------------------

  describe('privacy and blocks', () => {
    it('whoCanMessage NOBODY / FOLLOWING; the recipient having written waives it', async () => {
      const [a, b, c] = [await signup(), await signup(), await signup()];
      const set = await ctx.http.patch('/api/v1/me/privacy').set(auth(b)).send({ whoCanMessage: 'NOBODY' });
      expect(set.status).toBe(200);
      expectContract(set, 'updatePrivacy');
      expect(set.body.whoCanMessage).toBe('NOBODY');
      const refused = await send(a, b, { kind: 'TEXT', text: 'hi' });
      expect(refused.status).toBe(403);
      expect(refused.body.error.code).toBe('DM_NOT_ALLOWED');
      const peer = await ctx.http.get(`/api/v1/dm/peers/${b.username}`).set(auth(a));
      expect(peer.body).toMatchObject({ canMessage: false, reason: 'NOT_ALLOWED' });
      // b writes to a first: a may answer.
      await text(b, a, 'I start');
      expect((await send(a, b, { kind: 'TEXT', text: 'answer' })).status).toBe(201);

      await ctx.http.patch('/api/v1/me/privacy').set(auth(c)).send({ whoCanMessage: 'FOLLOWING' });
      expect((await send(a, c, { kind: 'TEXT', text: 'x' })).body.error.code).toBe('DM_NOT_ALLOWED');
      await follow(c, a);
      expect((await send(a, c, { kind: 'TEXT', text: 'x' })).status).toBe(201);
      const got = await ctx.http.get('/api/v1/me/privacy').set(auth(c));
      expect(got.body.whoCanMessage).toBe('FOLLOWING');
      expectContract(got, 'getPrivacy');
    });

    it('a block either way: 404 on send, the conversation and its messages disappear', async () => {
      const [a, b] = await friends();
      const sent = await text(a, b);
      await block(b, a);
      for (const [from, to] of [
        [a, b],
        [b, a],
      ] as const) {
        const res = await send(from, to, { kind: 'TEXT', text: 'x' });
        expect(res.status).toBe(404);
      }
      expect(await list(a)).toEqual([]);
      expect(await list(b)).toEqual([]);
      const read = await ctx.http
        .get(`/api/v1/dm/conversations/${sent.message.conversationId}/messages`)
        .set(auth(a));
      expect(read.status).toBe(404);
      expect((await ctx.http.get(`/api/v1/dm/peers/${b.username}`).set(auth(a))).status).toBe(404);
      expect((await unread(b)).messages).toBe(0);
    });
  });

  // ---- Receipts, unread, mute, delete ----------------------------------------------------------

  describe('receipts, unread counts, mute and delete', () => {
    it('unread per conversation and in total; read moves ✓✓; mute leaves the badge', async () => {
      const [a, b] = await friends();
      const [c] = [await signup()];
      await follow(b, c);
      await text(a, b, '1');
      const second = await text(a, b, '2');
      await text(c, b, 'from c');
      expect(await unread(b)).toEqual({ messages: 3, conversations: 2, requests: 0 });
      const conv = second.message.conversationId;
      expect((await list(b)).find((x) => x.id === conv)?.unreadCount).toBe(2);

      const bad = await ctx.http
        .post(`/api/v1/dm/conversations/${conv}/read`)
        .set(auth(b))
        .send({ lastMessageId: randomUUID() });
      expect(bad.status).toBe(400);
      const read = await ctx.http
        .post(`/api/v1/dm/conversations/${conv}/read`)
        .set(auth(b))
        .send({ lastMessageId: second.message.id });
      expect(read.status).toBe(204);
      expectContract(read, 'markDmRead');
      expect(await unread(b)).toEqual({ messages: 1, conversations: 1, requests: 0 });
      const seen = await messages(a, conv);
      expect(seen.data.map((m) => m.read)).toEqual([true, true]);
      expect(seen.conversation.peerReadAt).not.toBeNull();

      const cConv = (await list(b)).find((x) => x.peer.username === c.username)!.id;
      const mute = await ctx.http.put(`/api/v1/dm/conversations/${cConv}/mute`).set(auth(b));
      expect(mute.status).toBe(204);
      expectContract(mute, 'muteDmConversation');
      expect(await unread(b)).toEqual({ messages: 0, conversations: 0, requests: 0 });
      expect((await list(b)).find((x) => x.id === cConv)).toMatchObject({ muted: true, unreadCount: 1 });
      expect((await ctx.http.delete(`/api/v1/dm/conversations/${cConv}/mute`).set(auth(b))).status).toBe(204);
      expect((await unread(b)).messages).toBe(1);
    });

    it('delete for me, for everyone within an hour (409 after), never someone else’s for everyone', async () => {
      const [a, b] = await friends();
      const m1 = await text(a, b, 'keep');
      const m2 = await text(a, b, 'oops');
      const conv = m1.message.conversationId;
      const mine = await ctx.http.delete(`/api/v1/dm/messages/${m1.message.id}?scope=me`).set(auth(b));
      expect(mine.status).toBe(204);
      expectContract(mine, 'deleteDmMessage');
      expect((await messages(b, conv)).data.map((m) => m.text)).toEqual(['oops']);
      expect((await messages(a, conv)).data.map((m) => m.text)).toEqual(['oops', 'keep']);
      const others = await ctx.http
        .delete(`/api/v1/dm/messages/${m2.message.id}?scope=everyone`)
        .set(auth(b));
      expect(others.status).toBe(403);
      const all = await ctx.http.delete(`/api/v1/dm/messages/${m2.message.id}?scope=everyone`).set(auth(a));
      expect(all.status).toBe(204);
      expect((await messages(a, conv)).data.map((m) => m.text)).toEqual(['keep']);
      expect((await messages(b, conv)).data).toEqual([]);
      const late = await text(a, b, 'late');
      clock.advance(3601);
      const tooLate = await ctx.http
        .delete(`/api/v1/dm/messages/${late.message.id}?scope=everyone`)
        .set(auth(a));
      expect(tooLate.status).toBe(409);
      expect(tooLate.body.error.code).toBe('DM_DELETE_WINDOW_PASSED');
      // Delete the conversation for me: gone until a new message, which shows alone.
      expect((await ctx.http.delete(`/api/v1/dm/conversations/${conv}`).set(auth(b))).status).toBe(204);
      expect(await list(b)).toEqual([]);
      expect((await list(a)).length).toBe(1);
      clock.advance(1);
      await text(a, b, 'again');
      expect((await messages(b, conv)).data.map((m) => m.text)).toEqual(['again']);
      expect((await list(b)).map((c) => c.lastMessage?.text)).toEqual(['again']);
    });
  });

  // ---- Content: blocked words, emoji, pictures and voice --------------------------------------

  describe('content', () => {
    it('masks the server’s blocked words and the recipient’s live blocked words', async () => {
      const [a, b] = await friends();
      await ctx.prisma.liveHost.create({ data: { userId: b.id, source: 'ADMIN', blockedWords: ['كلمة'] } });
      const res = await text(a, b, 'buy spamword now والكلمة');
      expect(res.message).toMatchObject({ text: 'buy ******** now وال****' });
    });

    it('pictures and voice notes: only the caller’s unattached asset of the right kind', async () => {
      const [a, b] = await friends();
      const pic = await picture(a);
      const wrongKind = await picture(a, 'POST_IMAGE');
      const voice = await upload(a, 'DM_VOICE', 'audio/mp4', m4a({ durationMs: 4_000 }));
      expect(voice).toMatchObject({ type: 'AUDIO', durationMs: 4_000 });
      expect((await send(a, b, { kind: 'IMAGE', mediaId: wrongKind.id })).status).toBe(400);
      expect((await send(a, b, { kind: 'VOICE', mediaId: pic.id })).status).toBe(400);
      const theirs = await picture(b);
      expect((await send(a, b, { kind: 'IMAGE', mediaId: theirs.id })).status).toBe(400);
      const v = await send(a, b, { kind: 'VOICE', mediaId: voice.id });
      expect(v.status, JSON.stringify(v.body)).toBe(201);
      expect(v.body.message.media).toMatchObject({ type: 'AUDIO', durationMs: 4_000 });
      // An asset attaches once.
      expect((await send(a, b, { kind: 'VOICE', mediaId: voice.id })).status).toBe(400);
    });
  });

  // ---- The 24-hour life ------------------------------------------------------------------------

  describe('24-hour retention', () => {
    it('expired messages leave every read and count; the sweeper deletes rows and files; the conversation stays', async () => {
      const [a, b] = await friends();
      const pic = await picture(a);
      const voice = await upload(a, 'DM_VOICE', 'audio/mp4', m4a({ durationMs: 3_000 }));
      const t = await text(a, b, 'short life');
      await send(a, b, { kind: 'IMAGE', mediaId: pic.id });
      await send(a, b, { kind: 'VOICE', mediaId: voice.id });
      const conv = t.message.conversationId;
      expect((await unread(b)).messages).toBe(3);
      expect(storage.objects.has(`media/${pic.id}/1080.webp`)).toBe(true);
      expect(storage.objects.has(`media/${voice.id}/voice.m4a`)).toBe(true);

      clock.advance(24 * 3600 - 10);
      expect((await messages(b, conv)).data.length).toBe(3);
      clock.advance(20);
      // Hidden at once, before any sweep.
      expect((await messages(b, conv)).data).toEqual([]);
      expect(await unread(b)).toEqual({ messages: 0, conversations: 0, requests: 0 });
      const listed = await list(b);
      expect(listed.find((c) => c.id === conv)).toMatchObject({ lastMessage: null, unreadCount: 0 });

      const result = await sweep();
      expect(result.messages).toBeGreaterThanOrEqual(3);
      expect(await ctx.prisma.dmMessage.count({ where: { conversationId: conv } })).toBe(0);
      expect(await ctx.prisma.mediaAsset.count({ where: { id: { in: [pic.id, voice.id] } } })).toBe(0);
      expect(storage.objects.has(`media/${pic.id}/1080.webp`)).toBe(false);
      expect(storage.objects.has(`media/${pic.id}/320.webp`)).toBe(false);
      expect(storage.objects.has(`media/${voice.id}/voice.m4a`)).toBe(false);
      expect(await ctx.prisma.dmConversation.count({ where: { id: conv } })).toBe(1);
      expect((await list(a)).find((c) => c.id === conv)).toBeDefined();
      expect(t.message).toBeDefined();
    });
  });

  // ---- Reports -----------------------------------------------------------------------------------

  describe('reports', () => {
    it('keeps a snapshot (with a copy of the file) that outlives the message; REMOVE_TARGET; 30-day purge', async () => {
      const [a, b] = await friends();
      const mod = await signup();
      await withMigrationClient(async (c) => {
        await c.user.update({ where: { id: mod.id }, data: { role: 'ADMIN' } });
        await c.userAdminPermission.create({ data: { userId: mod.id, permission: 'MODERATION' } });
      });
      const pic = await picture(a);
      const img = await send(a, b, { kind: 'IMAGE', mediaId: pic.id });
      const txt = await text(a, b, 'rude words');
      // Only a message one received.
      const own = await ctx.http
        .post('/api/v1/reports')
        .set(auth(a))
        .send({ targetType: 'DM_MESSAGE', targetId: txt.message.id, reason: 'HARASSMENT' });
      expect(own.status).toBe(404);
      const rep = await ctx.http
        .post('/api/v1/reports')
        .set(auth(b))
        .send({ targetType: 'DM_MESSAGE', targetId: img.body.message.id, reason: 'NUDITY' });
      expect(rep.status, JSON.stringify(rep.body)).toBe(201);
      expectContract(rep, 'createReport');
      const again = await ctx.http
        .post('/api/v1/reports')
        .set(auth(b))
        .send({ targetType: 'DM_MESSAGE', targetId: img.body.message.id, reason: 'NUDITY' });
      expect(again.status).toBe(200);
      const repText = await ctx.http
        .post('/api/v1/reports')
        .set(auth(b))
        .send({ targetType: 'DM_MESSAGE', targetId: txt.message.id, reason: 'HARASSMENT' });
      expect(repText.status).toBe(201);
      const copy = `reports/dm/${rep.body.id as string}.webp`;
      expect(storage.objects.has(copy)).toBe(true);

      // The messages expire and are swept: the reports still show what they were.
      clock.advance(24 * 3600 + 1);
      await sweep();
      expect(await ctx.prisma.dmMessage.count({ where: { id: img.body.message.id } })).toBe(0);
      expect(storage.objects.has(copy)).toBe(true);
      const queue = await ctx.http.get('/api/v1/admin/reports?limit=50').set(auth(mod));
      expect(queue.status).toBe(200);
      expectContract(queue, 'listAdminReports');
      const ours = (queue.body.data as { id: string; dmSnapshot?: Record<string, unknown> }[]).filter((r) =>
        [rep.body.id, repText.body.id].includes(r.id),
      );
      expect(ours.map((r) => r.dmSnapshot)).toEqual([
        expect.objectContaining({
          kind: 'IMAGE',
          sender: a.username,
          mediaUrl: `https://media.example.test/${copy}`,
          purged: false,
        }),
        expect.objectContaining({ kind: 'TEXT', text: 'rude words', sender: a.username, mediaUrl: null }),
      ]);
      const act = await ctx.http
        .post(`/api/v1/admin/reports/${rep.body.id as string}/actions`)
        .set(auth(mod))
        .send({ action: 'REMOVE_TARGET' });
      expect(act.status, JSON.stringify(act.body)).toBe(200);
      expectContract(act, 'actOnReport');
      // Resolved "now" on the test clock (the API stamps resolutions with the wall clock).
      await ctx.prisma.report.updateMany({
        where: { id: { in: [rep.body.id as string, repText.body.id as string] } },
        data: { resolvedAt: clock.now() },
      });

      // 30 days after resolution the snapshot's text and file are cleared.
      clock.advance(29 * 86400);
      await sweep();
      expect(storage.objects.has(copy)).toBe(true);
      await ctx.prisma.report.update({
        where: { id: rep.body.id as string },
        data: { resolvedAt: new Date(clock.now().getTime() - 31 * 86400 * 1000) },
      });
      const swept = await sweep();
      expect(swept.snapshots).toBeGreaterThanOrEqual(1);
      expect(storage.objects.has(copy)).toBe(false);
      const row = await ctx.prisma.report.findUniqueOrThrow({ where: { id: rep.body.id as string } });
      expect(row.dmSnapshot).toMatchObject({ purged: true, mediaKey: null, text: null, kind: 'IMAGE' });
    });

    it('REMOVE_TARGET removes a message that still exists', async () => {
      const [a, b] = await friends();
      const mod = await signup();
      await withMigrationClient(async (c) => {
        await c.user.update({ where: { id: mod.id }, data: { role: 'ADMIN' } });
        await c.userAdminPermission.create({ data: { userId: mod.id, permission: 'MODERATION' } });
      });
      const t = await text(a, b, 'bad');
      const rep = await ctx.http
        .post('/api/v1/reports')
        .set(auth(b))
        .send({ targetType: 'DM_MESSAGE', targetId: t.message.id, reason: 'SPAM' });
      expect(rep.status, JSON.stringify(rep.body)).toBe(201);
      const act = await ctx.http
        .post(`/api/v1/admin/reports/${rep.body.id as string}/actions`)
        .set(auth(mod))
        .send({ action: 'REMOVE_TARGET' });
      expect(act.status, JSON.stringify(act.body)).toBe(200);
      expect(
        await ctx.prisma.dmMessage.count({ where: { id: t.message.id, expiresAt: { gt: clock.now() } } }),
      ).toBe(0);
      expect((await messages(b, t.message.conversationId)).data).toEqual([]);
    });
  });

  // ---- Gifts in conversations ------------------------------------------------------------------

  describe('gifts', () => {
    it('charges once, writes a GIFT message, counts 50 % charm for the recipient and full support', async () => {
      const [a, b] = await friends();
      await coins(a, 1000);
      const code = await gift({ priceCoins: 30 });
      const clientId = randomUUID();
      const res = await sendGift(a, b, { giftCode: code, quantity: 1, clientId });
      expect(res.status, JSON.stringify(res.body)).toBe(201);
      expectContract(res, 'sendDmGift');
      expect(res.body).toMatchObject({ coins: 970, bagQuantity: 0 });
      expect(res.body.luckyResult).toBeUndefined();
      expect(res.body.message).toMatchObject({
        kind: 'GIFT',
        mine: true,
        gift: { giftCode: code, quantity: 1, unitPrice: 30, totalCoins: 30, lucky: null },
      });
      const again = await sendGift(a, b, { giftCode: code, quantity: 1, clientId });
      expect(again.status).toBe(200);
      expect(again.body.message.id).toBe(res.body.message.id);
      expect(await wallet(a)).toBe(970);
      const send = await ctx.prisma.liveGift.findFirstOrThrow({ where: { senderId: a.id, clientId } });
      expect(send).toMatchObject({ roomId: null, dmConversationId: res.body.message.conversationId });
      const ledger = await ctx.prisma.walletLedgerEntry.findMany({
        where: { userId: a.id, referenceId: send.id },
      });
      expect(ledger.map((l) => [l.reason, l.delta])).toEqual([['DM_GIFT', -30n]]);
      const charm = await ctx.prisma.pointsLedgerEntry.findMany({
        where: { sourceTransactionId: `gift:${send.id}:${b.id}` },
        orderBy: { sourceType: 'asc' },
      });
      expect(charm.map((e) => [e.userId, e.sourceType, e.sourceValue])).toEqual([
        [b.id, 'GIFT_RECEIVED', 15n],
        [a.id, 'GIFT_SENT', 30n],
      ]);
      expect((await messages(b, res.body.message.conversationId)).data[0]).toMatchObject({
        kind: 'GIFT',
        mine: false,
      });

      // The message expires; the send and its ledger stay.
      clock.advance(24 * 3600 + 1);
      await sweep();
      expect(await ctx.prisma.dmMessage.count({ where: { id: res.body.message.id } })).toBe(0);
      expect(await ctx.prisma.liveGift.count({ where: { id: send.id } })).toBe(1);
      expect(await ctx.prisma.walletLedgerEntry.count({ where: { referenceId: send.id } })).toBe(1);
    });

    it('lucky gifts keep the lucky share (10 %), draw and pay like in a live', async () => {
      const [a, b] = await friends();
      await coins(a, 1000);
      const code = await gift({ category: 'LUCKY', priceCoins: 100 });
      const unconfirmed = await sendGift(a, b, { giftCode: code });
      expect(unconfirmed.status).toBe(403);
      expect(unconfirmed.body.error.code).toBe('LUCKY_GIFT_AGE_UNCONFIRMED');
      expect(await wallet(a)).toBe(1000);
      await ctx.http.put('/api/v1/me/lucky-gifts/age-confirmation').set(auth(a)).send({ adult: true });
      // A busy day: the daily protection does not hold the win back (CONVENTIONS §10.27).
      const day = new Date(`${ctx.app.get(LuckyGiftsService).dayOf(clock.now())}T00:00:00.000Z`);
      await ctx.prisma.luckyGiftDay.upsert({
        where: { day },
        create: { day, spendCoins: 10_000_000n, paidCoins: 0n, sends: 1, draws: 1n },
        update: { spendCoins: 10_000_000n, paidCoins: 0n },
      });
      rng.script(48_918); // ×10
      const res = await sendGift(a, b, { giftCode: code });
      expect(res.status, JSON.stringify(res.body)).toBe(201);
      expectContract(res, 'sendDmGift');
      expect(res.body.luckyResult).toMatchObject({ draws: 1, coinsWon: 1000, topMultiplier: 10 });
      expect(res.body.coins).toBe(1900);
      expect(res.body.message.gift.lucky).toEqual({ coinsWon: 1000, topMultiplier: 10 });
      const send = await ctx.prisma.liveGift.findFirstOrThrow({ where: { senderId: a.id, giftCode: code } });
      const ledger = await ctx.prisma.walletLedgerEntry.findMany({
        where: { userId: a.id, referenceId: send.id },
        orderBy: { createdAt: 'asc' },
      });
      expect(ledger.map((l) => [l.reason, l.delta])).toEqual([
        ['LUCKY_GIFT', -100n],
        ['LUCKY_GIFT_WIN', 1000n],
      ]);
      const charm = await ctx.prisma.pointsLedgerEntry.findFirstOrThrow({
        where: { sourceTransactionId: `gift:${send.id}:${b.id}`, userId: b.id },
      });
      expect(charm.sourceValue).toBe(10n);
    });

    it('a stranger’s gift is a request message; blocks, privacy and coins are checked', async () => {
      const [a, b] = [await signup(), await signup()];
      const code = await gift({ priceCoins: 5 });
      const poor = await sendGift(a, b, { giftCode: code });
      expect(poor.status).toBe(409);
      expect(poor.body.error.code).toBe('INSUFFICIENT_COINS');
      expect(await ctx.prisma.dmMessage.count({ where: { senderId: a.id } })).toBe(0);
      expect(
        await ctx.prisma.dmConversation.count({
          where: { userLowId: { in: [a.id, b.id] }, userHighId: { in: [a.id, b.id] } },
        }),
      ).toBe(0);
      await coins(a, 100);
      const g = await sendGift(a, b, { giftCode: code });
      expect(g.status).toBe(201);
      expect(g.body.conversation).toMatchObject({ status: 'REQUEST_SENT', requestMessagesLeft: 2 });
      expect((await list(b, 'REQUESTS')).length).toBe(1);
      await text(a, b, '2');
      await text(a, b, '3');
      const over = await sendGift(a, b, { giftCode: code });
      expect(over.status).toBe(403);
      expect(over.body.error.code).toBe('DM_REQUEST_LIMIT');
      expect(await wallet(a)).toBe(95);
      const unknown = await sendGift(a, b, { giftCode: 'no_such_gift' });
      expect(unknown.status).toBe(403);

      const [c, d] = await friends();
      await coins(c, 100);
      await block(d, c);
      const blocked = await sendGift(c, d, { giftCode: code });
      expect(blocked.status).toBe(404);
      expect(await wallet(c)).toBe(100);
      const [e, f] = await friends();
      await coins(e, 100);
      const missing = await sendGift(e, f, { giftCode: 'no_such_gift' });
      expect(missing.status).toBe(409);
      expect(missing.body.error.code).toBe('GIFT_UNAVAILABLE');
    });
  });
});

describe('D155 rate limits', { timeout: 120_000 }, () => {
  let ctx: TestContext;
  const auth = (u: { token: string }) => ({ Authorization: `Bearer ${u.token}` });
  const signup = async () => {
    const { res } = await registerVerified(ctx);
    return { username: res.body.user.username as string, token: res.body.tokens.accessToken as string };
  };
  const send = (by: { token: string }, to: { username: string }, t: string) =>
    ctx.http
      .post('/api/v1/dm/messages')
      .set(auth(by))
      .send({ to: to.username, kind: 'TEXT', text: t, clientId: randomUUID() });

  beforeAll(async () => {
    ctx = await createTestApp({ RATE_LIMIT_DM_SEND_USER: '4/60', RATE_LIMIT_DM_REQUEST_USER: '1/3600' });
  });
  afterAll(async () => ctx?.close());

  it('message requests: 1 an hour here; every send: 4 a minute here (429 with Retry-After)', async () => {
    const [a, b, c] = [await signup(), await signup(), await signup()];
    expect((await send(a, b, 'first request')).status).toBe(201);
    const second = await send(a, c, 'second request');
    expect(second.status).toBe(429);
    expect(second.headers['retry-after']).toBeDefined();
    // Not requests: b answers a (b has a's request), then a can write freely.
    expect((await send(b, a, 'reply')).status).toBe(201);
    expect((await send(a, b, 'ok 2')).status).toBe(201);
    expect((await send(a, b, 'ok 3')).status).toBe(201);
    const limited = await send(a, b, 'ok 4');
    expect(limited.status).toBe(429);
    expectContract(limited, 'sendDmMessage');
  });
});
