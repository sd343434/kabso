/**
 * D152 (owner 2026-10-28: notification sounds, phase 2 — pushes): push tokens and push delivery
 * (openapi v1.30-live DRAFT, CONVENTIONS §11.12, §11.10, §10.25), end to end against PostgreSQL +
 * Redis with the API as the DML-only runtime role and a **fake push sender** in place of Firebase
 * (no key, no network). Covers: register / refresh / move / unregister, logout and revocation
 * removing the token, the general push from the notifications outbox (visibility, settings,
 * mutes, read, age, throttle, once only, invalid tokens deleted), the family chat push (never the
 * sender, blocks, mutes, `messages` off, per-chat throttle) and push off without a key.
 */
import { randomUUID } from 'node:crypto';
import type { Redis } from 'ioredis';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { uuidv7 } from '../src/modules/levels/uuidv7.js';
import { NotificationPushDispatcher } from '../src/modules/notifications/notification-push.dispatcher.js';
import {
  PUSH_SENDER,
  type PushMessage,
  type PushSendResult,
  type PushSender,
} from '../src/modules/push/push-sender.js';
import { creditIn } from '../src/modules/wallet/wallet-ledger.js';
import { REDIS } from '../src/redis/redis.module.js';
import { expectContract, operations } from './helpers/openapi.js';
import {
  createTestApp,
  registerVerified,
  settle,
  withMigrationClient,
  type TestContext,
} from './helpers/test-app.js';

/** Records every push; answers the tokens in `invalid` as not registered. */
class FakePushSender implements PushSender {
  readonly enabled = true;
  readonly sent: PushMessage[] = [];
  readonly invalid = new Set<string>();

  send(message: PushMessage): Promise<PushSendResult> {
    this.sent.push(message);
    const invalidTokens = message.tokens.filter((t) => this.invalid.has(t));
    return Promise.resolve({
      sent: message.tokens.length - invalidTokens.length,
      failed: invalidTokens.length,
      invalidTokens,
    });
  }

  to(token: string): PushMessage[] {
    return this.sent.filter((m) => m.tokens.includes(token));
  }

  clear(): void {
    this.sent.length = 0;
  }
}

interface TestUser {
  readonly id: string;
  readonly username: string;
  readonly token: string;
  readonly email: string;
}

const PASSWORD = 'correct horse battery staple';

describe('D152 contract coverage', () => {
  it('openapi declares the push token operations and the messages switch', () => {
    const ids = operations().map((o) => `${o.operationId} ${o.method.toUpperCase()} ${o.path}`);
    expect(ids).toContain('registerPushToken PUT /api/v1/me/push-token');
    expect(ids).toContain('unregisterPushToken DELETE /api/v1/me/push-token');
  });
});

describe('D152 push notifications', { timeout: 180_000 }, () => {
  const fake = new FakePushSender();
  let ctx: TestContext;
  let dispatcher: NotificationPushDispatcher;

  const auth = (u: { token: string }) => ({ Authorization: `Bearer ${u.token}` });
  const signup = async (overrides: Record<string, unknown> = {}): Promise<TestUser> => {
    const { res, payload } = await registerVerified(ctx, overrides);
    expect(res.status).toBe(201);
    return {
      id: res.body.user.id as string,
      username: res.body.user.username as string,
      token: res.body.tokens.accessToken as string,
      email: String(payload.email),
    };
  };
  /** A second session of the same account (another phone). */
  const login = async (u: TestUser): Promise<{ token: string }> => {
    const res = await ctx.http
      .post('/api/v1/auth/login')
      .send({ identifier: u.email, password: PASSWORD, device: { name: 'Phone 2', platform: 'android' } });
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    return { token: res.body.tokens.accessToken as string };
  };
  const fcm = () => `fcm_${randomUUID().replaceAll('-', '')}:APA91b${randomUUID().replaceAll('-', '')}`;
  const register = async (u: { token: string }, token: string, platform = 'ANDROID') => {
    const res = await ctx.http
      .put('/api/v1/me/push-token')
      .set(auth(u))
      .send({ token, platform, appVersion: '0.1.0-staging+abc1234' });
    expect(res.status, JSON.stringify(res.body)).toBe(204);
    expectContract(res, 'registerPushToken');
  };
  const rows = (userId: string) =>
    ctx.prisma.deviceToken.findMany({ where: { userId }, orderBy: { createdAt: 'asc' } });
  const follow = async (by: TestUser, u: TestUser) => {
    const res = await ctx.http.put(`/api/v1/users/${u.username}/follow`).set(auth(by));
    expect(res.status, JSON.stringify(res.body)).toBeLessThan(300);
  };
  /** Clears the push throttles (Redis), so a test starts fresh. */
  const clearThrottles = async () => {
    const redis = ctx.app.get<Redis>(REDIS);
    const prefix = ctx.config.redis.keyPrefix;
    // KEYS takes the full name; UNLINK adds the client's prefix itself.
    const keys = await redis.keys(`${prefix}push:*`);
    if (keys.length > 0) await redis.unlink(...keys.map((k) => k.slice(prefix.length)));
  };

  beforeAll(async () => {
    ctx = await createTestApp({}, [{ token: PUSH_SENDER, value: fake }]);
    dispatcher = ctx.app.get(NotificationPushDispatcher);
  });
  afterAll(async () => ctx?.close());

  // ---- Tokens ----------------------------------------------------------------------------------

  describe('PUT / DELETE /me/push-token', () => {
    it('validates the body (400) and needs a token (401)', async () => {
      const u = await signup();
      for (const body of [
        {},
        { token: 'abc', platform: 'ANDROID' },
        { token: 'has space', platform: 'ANDROID', appVersion: '1' },
        { token: 'abc', platform: 'WINDOWS', appVersion: '1' },
        { token: 'x'.repeat(1025), platform: 'ANDROID', appVersion: '1' },
        { token: 'abc', platform: 'ANDROID', appVersion: '1', extra: true },
      ]) {
        const res = await ctx.http.put('/api/v1/me/push-token').set(auth(u)).send(body);
        expect(res.status, JSON.stringify(body)).toBe(400);
        expectContract(res, 'registerPushToken');
        expect(res.body.error.code).toBe('VALIDATION_FAILED');
      }
      const anon = await ctx.http
        .put('/api/v1/me/push-token')
        .send({ token: 'a', platform: 'ANDROID', appVersion: '1' });
      expect(anon.status).toBe(401);
      expect((await ctx.http.delete('/api/v1/me/push-token')).status).toBe(401);
    });

    it('one token per session: a refresh replaces it, re-sending is idempotent, DELETE removes it', async () => {
      const u = await signup();
      const t1 = fcm();
      await register(u, t1);
      await register(u, t1);
      expect((await rows(u.id)).map((r) => r.token)).toEqual([t1]);
      const t2 = fcm();
      await register(u, t2);
      const after = await rows(u.id);
      expect(after.map((r) => [r.token, r.platform, r.appVersion])).toEqual([
        [t2, 'ANDROID', '0.1.0-staging+abc1234'],
      ]);
      // A second phone: its own row.
      const phone2 = await login(u);
      const t3 = fcm();
      await register(phone2, t3, 'IOS');
      expect((await rows(u.id)).map((r) => r.token).sort()).toEqual([t2, t3].sort());
      const del = await ctx.http.delete('/api/v1/me/push-token').set(auth(phone2));
      expect(del.status).toBe(204);
      expectContract(del, 'unregisterPushToken');
      expect((await ctx.http.delete('/api/v1/me/push-token').set(auth(phone2))).status).toBe(204);
      expect((await rows(u.id)).map((r) => r.token)).toEqual([t2]);
    });

    it('the same phone signs in to another account: the token moves there', async () => {
      const [a, b] = [await signup(), await signup()];
      const t = fcm();
      await register(a, t);
      await register(b, t);
      expect(await rows(a.id)).toEqual([]);
      expect((await rows(b.id)).map((r) => r.token)).toEqual([t]);
    });

    it('logout and session revocation remove the session’s token', async () => {
      const u = await signup();
      await register(u, fcm());
      const out = await ctx.http.post('/api/v1/auth/logout').set(auth(u));
      expect(out.status).toBe(204);
      expect(await rows(u.id)).toEqual([]);

      const v = await signup();
      const other = await login(v);
      await register(other, fcm());
      const sessions = await ctx.http.get('/api/v1/auth/sessions').set(auth(v));
      const otherSession = (sessions.body.data as { id: string; current: boolean }[]).find((s) => !s.current);
      expect(otherSession).toBeDefined();
      const revoke = await ctx.http.delete(`/api/v1/auth/sessions/${otherSession!.id}`).set(auth(v));
      expect(revoke.status).toBe(204);
      expect(await rows(v.id)).toEqual([]);
    });
  });

  // ---- General pushes ------------------------------------------------------------------------

  describe('general pushes (the notifications outbox)', () => {
    it('a new follower: one push on kabso_general in the recipient’s language, once', async () => {
      const [a, b] = [await signup({ displayName: 'Amal' }), await signup({ displayName: 'Basim' })];
      const ta = fcm();
      await register(a, ta);
      await dispatcher.dispatchOnce(); // drain anything earlier
      await clearThrottles();
      fake.clear();
      await follow(b, a);
      expect(await dispatcher.dispatchOnce()).toBe(1);
      const sent = fake.to(ta);
      expect(sent).toHaveLength(1);
      const m = sent[0]!;
      expect(m.channel).toBe('general');
      expect(m.title).toBe('Kabso Live');
      expect(m.body).toBe('Basim started following you');
      expect(m.tokens).toEqual([ta]);
      expect(m.data).toMatchObject({
        kind: 'notification',
        channel: 'general',
        type: 'FOLLOW',
        targetType: 'USER',
        targetId: b.username,
        actorUsername: b.username,
      });
      expect(m.tag).toBe(`n:${m.data.notificationId}`);
      // The actor never gets one; nothing is pushed twice.
      expect(await dispatcher.dispatchOnce()).toBe(0);
      expect(fake.sent).toHaveLength(1);
    });

    it('Arabic accounts get the Arabic sentence', async () => {
      const [a, b] = [await signup({ locale: 'ar' }), await signup({ displayName: 'سارة' })];
      const ta = fcm();
      await register(a, ta);
      await dispatcher.dispatchOnce();
      await clearThrottles();
      fake.clear();
      await follow(b, a);
      await dispatcher.dispatchOnce();
      expect(fake.to(ta).map((m) => m.body)).toEqual(['بدأ سارة بمتابعتك']);
    });

    it('nothing for a muted actor, a switched-off type, a read or an old notification, or without a token', async () => {
      const [a, b, c, d, e] = [
        await signup(),
        await signup(),
        await signup(),
        await signup(),
        await signup(),
      ];
      const ta = fcm();
      await register(a, ta);
      await dispatcher.dispatchOnce();
      await clearThrottles();
      fake.clear();
      // Muted: no notification at all (§11.10), so no push.
      expect((await ctx.http.put(`/api/v1/users/${b.username}/mute`).set(auth(a))).status).toBeLessThan(300);
      await follow(b, a);
      // Switched off.
      expect(
        (await ctx.http.patch('/api/v1/me/notification-settings').set(auth(a)).send({ follows: false }))
          .status,
      ).toBe(200);
      await follow(c, a);
      expect(
        (await ctx.http.patch('/api/v1/me/notification-settings').set(auth(a)).send({ follows: true }))
          .status,
      ).toBe(200);
      // Read before the dispatcher ran.
      await follow(d, a);
      expect(
        (await ctx.http.post('/api/v1/notifications/read').set(auth(a)).send({ all: true })).status,
      ).toBe(204);
      expect(await dispatcher.dispatchOnce()).toBe(0);
      // Older than 10 minutes when the dispatcher sees it (e.g. after downtime).
      await follow(e, a);
      await withMigrationClient((cl) =>
        cl.$executeRawUnsafe(
          `UPDATE notifications SET updated_at = now() - interval '11 minutes' WHERE recipient_id = $1::uuid AND pushed_at IS NULL`,
          a.id,
        ),
      );
      expect(await dispatcher.dispatchOnce()).toBe(0);
      expect(fake.to(ta)).toEqual([]);
      // No token: nothing sent, the row is still handled.
      const [f, g] = [await signup(), await signup()];
      await follow(g, f);
      expect(await dispatcher.dispatchOnce()).toBe(0);
      expect(await ctx.prisma.notification.count({ where: { recipientId: f.id, pushedAt: null } })).toBe(0);
    });

    it('a burst collapses: one push per recipient per PUSH_GENERAL_GAP_SECONDS', async () => {
      const [a, b, c] = [await signup(), await signup(), await signup()];
      const ta = fcm();
      await register(a, ta);
      await dispatcher.dispatchOnce();
      await clearThrottles();
      fake.clear();
      await follow(b, a);
      await follow(c, a);
      expect(await dispatcher.dispatchOnce()).toBe(1);
      expect(fake.to(ta)).toHaveLength(1);
      // Both stay in the inbox.
      const inbox = await ctx.http.get('/api/v1/notifications').set(auth(a));
      expect(inbox.body.data).toHaveLength(2);
    });

    it('a revoked or logged-out session is never pushed to; invalid tokens are deleted', async () => {
      const [a, b, c] = [await signup(), await signup(), await signup()];
      const phone2 = await login(a);
      const [t1, t2] = [fcm(), fcm()];
      await register(a, t1);
      await register(phone2, t2);
      await dispatcher.dispatchOnce();
      await clearThrottles();
      fake.clear();
      fake.invalid.add(t1);
      await follow(b, a);
      await dispatcher.dispatchOnce();
      expect(fake.sent).toHaveLength(1);
      expect([...fake.sent[0]!.tokens].sort()).toEqual([t1, t2].sort());
      // Firebase said t1 is gone: deleted.
      expect((await rows(a.id)).map((r) => r.token)).toEqual([t2]);
      // A session revoked behind the API's back (e.g. expired) is skipped even with its row.
      await withMigrationClient((cl) =>
        cl.$executeRawUnsafe(
          `UPDATE sessions SET expires_at = now() - interval '1 second' WHERE user_id = $1::uuid`,
          a.id,
        ),
      );
      await clearThrottles();
      fake.clear();
      await follow(c, a);
      await dispatcher.dispatchOnce();
      expect(fake.sent).toEqual([]);
    });
  });

  // ---- Family chat ---------------------------------------------------------------------------

  describe('family chat pushes', () => {
    const grant = (u: TestUser, coins: number) =>
      ctx.prisma.$transaction((tx) => creditIn(tx, u.id, BigInt(coins), 'ADMIN_GRANT', uuidv7()));
    const newFamily = async (leader: TestUser, name: string): Promise<string> => {
      await grant(leader, 500);
      const res = await ctx.http
        .post('/api/v1/families')
        .set(auth(leader))
        .send({ name, clientId: randomUUID() });
      expect(res.status, JSON.stringify(res.body)).toBe(201);
      return res.body.family.id as string;
    };
    const join = async (leader: TestUser, u: TestUser, familyId: string) => {
      const asked = await ctx.http.post(`/api/v1/families/${familyId}/join-requests`).set(auth(u));
      expect(asked.status).toBe(201);
      const ok = await ctx.http
        .post(`/api/v1/families/${familyId}/join-requests/${asked.body.id as string}/accept`)
        .set(auth(leader));
      expect(ok.status).toBe(200);
    };
    const say = async (u: TestUser, familyId: string, text: string) => {
      const res = await ctx.http
        .post(`/api/v1/families/${familyId}/chat`)
        .set(auth(u))
        .send({ text, clientId: randomUUID() });
      expect(res.status, JSON.stringify(res.body)).toBe(201);
      await settle(ctx);
      return res.body as { id: string };
    };

    it('to the other members on kabso_messages, never the sender; blocks, mutes and `messages` off respected; one per chat per 10 s', async () => {
      const leader = await signup({ displayName: 'Leader' });
      const [m1, m2, m3, m4, m5] = [
        await signup(),
        await signup(),
        await signup(),
        await signup(),
        await signup(),
      ];
      const familyId = await newFamily(leader, `Push house ${Date.now() % 100000}`);
      for (const m of [m1, m2, m3, m4, m5]) await join(leader, m, familyId);
      const tokens = new Map<string, string>();
      for (const u of [leader, m1, m2, m3, m4, m5]) {
        const t = fcm();
        tokens.set(u.id, t);
        await register(u, t);
      }
      await dispatcher.dispatchOnce(); // the join notifications are not what this test is about
      await clearThrottles();
      fake.clear();
      // m2 blocked the leader; m3 muted the leader; m4 switched family chat pushes off.
      expect((await ctx.http.put(`/api/v1/users/${leader.username}/block`).set(auth(m2))).status).toBe(200);
      expect((await ctx.http.put(`/api/v1/users/${leader.username}/mute`).set(auth(m3))).status).toBeLessThan(
        300,
      );
      const off = await ctx.http
        .patch('/api/v1/me/notification-settings')
        .set(auth(m4))
        .send({ messages: false });
      expect(off.status).toBe(200);
      expectContract(off, 'updateNotificationSettings');
      expect(off.body.messages).toBe(false);

      const msg = await say(leader, familyId, 'Hello   family   welcome');
      const chat = fake.sent.filter((m) => m.channel === 'messages');
      expect(chat).toHaveLength(1);
      const m = chat[0]!;
      expect([...m.tokens].sort()).toEqual([tokens.get(m1.id)!, tokens.get(m5.id)!].sort());
      expect(m.title).toMatch(/^Push house/);
      expect(m.body).toBe('Leader: Hello family welcome');
      expect(m.tag).toBe(`family:${familyId}`);
      expect(m.data).toEqual({ kind: 'family_chat', channel: 'messages', familyId, messageId: msg.id });

      // A second message within 10 s: collapsed for those who just got one.
      fake.clear();
      await say(leader, familyId, 'second');
      expect(fake.sent.filter((x) => x.channel === 'messages')).toEqual([]);
      // Another member writes: the leader (and m5) hear it; m1 (the author) does not.
      await say(m1, familyId, 'hi leader');
      const second = fake.sent.filter((x) => x.channel === 'messages');
      expect(second).toHaveLength(1);
      expect(second[0]!.tokens).not.toContain(tokens.get(m1.id));
      expect(second[0]!.tokens).toContain(tokens.get(leader.id));
    });

    it('the settings answer carries `messages` (default on)', async () => {
      const u = await signup();
      const res = await ctx.http.get('/api/v1/me/notification-settings').set(auth(u));
      expect(res.status).toBe(200);
      expectContract(res, 'getNotificationSettings');
      expect(res.body.messages).toBe(true);
    });
  });
});

describe('D152 push off (no Firebase key)', { timeout: 60_000 }, () => {
  let ctx: TestContext;
  beforeAll(async () => {
    ctx = await createTestApp();
  });
  afterAll(async () => ctx?.close());

  it('tokens are still accepted; the outbox is drained without sending', async () => {
    const [a, b] = [await registerVerified(ctx), await registerVerified(ctx)];
    const ua = {
      token: a.res.body.tokens.accessToken as string,
      username: a.res.body.user.username as string,
    };
    const ub = { token: b.res.body.tokens.accessToken as string };
    const put = await ctx.http
      .put('/api/v1/me/push-token')
      .set({ Authorization: `Bearer ${ua.token}` })
      .send({ token: 'fcm_offline_token', platform: 'ANDROID', appVersion: '1.0.0' });
    expect(put.status).toBe(204);
    await ctx.http.put(`/api/v1/users/${ua.username}/follow`).set({ Authorization: `Bearer ${ub.token}` });
    const dispatcher = ctx.app.get(NotificationPushDispatcher);
    expect(await dispatcher.dispatchOnce()).toBe(0);
    expect(await ctx.prisma.notification.count({ where: { pushedAt: null } })).toBe(0);
  });
});
