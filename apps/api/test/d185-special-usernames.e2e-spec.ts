/**
 * D185 (owner 2026-10-30; contract v1.54-social, CONVENTIONS §10.48.1, CP-028): the special-username layer
 * «يوزر مميز». A recharge agent's code becomes their username (locked); a suspension, a revocation or an expiry
 * gives the person's own (base) username back and keeps the special one reserved for them (30 days; a `coin`
 * name forever). The base username signs in and old links and mentions still lead to the person, but it never
 * appears in anything another person reads. End to end against PostgreSQL + Redis.
 */
import { randomUUID } from 'node:crypto';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { OBJECT_STORAGE } from '../src/modules/media/object-storage.js';
import {
  approveApplicationIn,
  reinstateIn,
  suspendIn,
  topUpIn,
} from '../src/modules/recharge/recharge-core.js';
import {
  endSpecialIn,
  grantSpecialIn,
  SpecialUsernameError,
  sweepSpecialUsernames,
} from '../src/modules/users/special-usernames.js';
import { MemoryObjectStorage } from './helpers/memory-storage.js';
import { expectContract } from './helpers/openapi.js';
import { createTestApp, registerVerified, type TestContext } from './helpers/test-app.js';

interface TestUser {
  readonly id: string;
  readonly username: string;
  readonly email: string;
  readonly password: string;
  readonly token: string;
}

const RULES = {
  activationMinCoins: 30_000_000,
  priceTiers: [{ minCoins: 0, minorPerMillion: 1200 }],
  currency: 'USD',
};
const DAY = 86_400_000;

describe('D185 special usernames', { timeout: 300_000 }, () => {
  let ctx: TestContext;
  const auth = (u: TestUser) => ({ Authorization: `Bearer ${u.token}` });
  const signup = async (): Promise<TestUser> => {
    const { res, payload } = await registerVerified(ctx);
    expect(res.status).toBe(201);
    return {
      id: res.body.user.id as string,
      username: res.body.user.username as string,
      email: payload.email,
      password: payload.password,
      token: res.body.tokens.accessToken as string,
    };
  };
  const me = async (u: TestUser) => {
    const res = await ctx.http.get('/api/v1/me').set(auth(u));
    expect(res.status).toBe(200);
    expectContract(res, 'getMe');
    return res.body as {
      username: string;
      specialUsername?: {
        username: string;
        baseUsername: string;
        source: string;
        expiresAt: string | null;
        locked: boolean;
      };
    };
  };
  const login = (identifier: string, password: string) =>
    ctx.http.post('/api/v1/auth/login').send({ identifier, password });
  const changeUsername = (u: TestUser, username: string) =>
    ctx.http.put('/api/v1/me/username').set(auth(u)).send({ username });
  const shown = async (userId: string) =>
    (await ctx.prisma.userProfile.findUniqueOrThrow({ where: { userId } })).username;
  /** An approved applicant activated by a first top-up (rows written directly: the application flow is
   *  covered by d185-recharge-agents). */
  const activate = async (u: TestUser): Promise<string> => {
    const id = `00000000-0000-7000-8000-${u.id.slice(-12)}`;
    await ctx.prisma.rechargeAgentApplication.create({
      data: {
        id,
        userId: u.id,
        fullName: 'Test Agent Name',
        phone: '+201001234567',
        locations: [{ country: 'EG', cities: ['Cairo'] }],
        paymentMethods: [{ country: 'EG', type: 'BANK_TRANSFER', details: 'x' }],
        photoKey: `private/recharge-agents/${id}/photo.webp`,
        selfieKey: `private/recharge-agents/${id}/selfie.webp`,
      },
    });
    await ctx.prisma.$transaction((tx) => approveApplicationIn(tx, id, new Date()));
    const r = await ctx.prisma.$transaction((tx) =>
      topUpIn(tx, u.id, 30_000_000n, 36_000n, null, RULES, new Date(), 30),
    );
    return r.code!;
  };
  const gift = (u: TestUser, name: string, expiresAt: Date | null, now = new Date()) =>
    ctx.prisma.$transaction((tx) =>
      grantSpecialIn(
        tx,
        u.id,
        name,
        { source: 'ADMIN_GIFT', expiresAt, reason: 'test', via: 'cli' },
        now,
        30,
      ),
    );
  const giftError = (u: TestUser, name: string) =>
    gift(u, name, null).then(
      () => null,
      (err: unknown) => (err instanceof SpecialUsernameError ? err.reason : String(err)),
    );

  beforeAll(async () => {
    ctx = await createTestApp(
      { RECHARGE_AGENT_SWEEP_INTERVAL_SECONDS: '0', SPECIAL_USERNAME_SWEEP_INTERVAL_SECONDS: '0' },
      [{ token: OBJECT_STORAGE, value: new MemoryObjectStorage() }],
    );
  });
  afterAll(async () => ctx?.close());

  it('activation makes @coinNNNN the username, locked; the base signs in and stays private', async () => {
    const agent = await signup();
    const base = agent.username;
    const code = await activate(agent);
    expect(code).toMatch(/^coin[0-9]{4,}$/);
    expect(await shown(agent.id)).toBe(code);

    const own = await me(agent);
    expect(own.username).toBe(code);
    expect(own.specialUsername).toMatchObject({
      username: code,
      baseUsername: base,
      source: 'RECHARGE_AGENT',
      expiresAt: null,
      locked: true,
    });

    // Locked: no change of username, no premium rental.
    const changed = await changeUsername(agent, `${base}x`);
    expect(changed.status).toBe(409);
    expect(changed.body.error.code).toBe('USERNAME_LOCKED');
    expectContract(changed, 'changeUsername');

    // Sign in by the special username, the base one (any case) and the email.
    for (const id of [code, base, base.toUpperCase(), agent.email]) {
      const res = await login(id, agent.password);
      expect(res.status, id).toBe(200);
      expect(res.body.user.id).toBe(agent.id);
      expect(res.body.user.username).toBe(code);
    }
  });

  it('the base username never appears in what others read (profile, summaries, search, mentions)', async () => {
    const agent = await signup();
    const base = agent.username;
    const code = await activate(agent);
    const viewer = await signup();

    const noBase = (body: unknown, what: string) => {
      const json = JSON.stringify(body);
      expect(json, what).not.toContain(base);
      expect(json, what).not.toContain('baseUsername');
      expect(json, what).not.toContain('specialUsername');
    };

    // The public profile, by the shown name and by an old link to the base name.
    for (const name of [code, base]) {
      const res = await ctx.http.get(`/api/v1/users/${name}`).set(auth(viewer));
      expect(res.status, name).toBe(200);
      expectContract(res, 'getPublicProfile');
      expect(res.body.username).toBe(code);
      noBase(res.body, `profile via ${name}`);
    }

    // A post by the agent (UserSummary as author), and a viewer's post mentioning the agent by both names.
    const newPost = (u: TestUser, text: string) =>
      ctx.http.post('/api/v1/posts').set(auth(u)).set('Idempotency-Key', randomUUID()).send({ text });
    const post = await newPost(agent, 'hello from an agent');
    expect(post.status, JSON.stringify(post.body)).toBe(201);
    const read = await ctx.http.get(`/api/v1/posts/${post.body.id as string}`).set(auth(viewer));
    expect(read.status).toBe(200);
    expect(read.body.author.username).toBe(code);
    noBase(read.body, 'post author');

    const mention = await newPost(viewer, `hi @${code}`);
    expect(mention.status).toBe(201);
    expect((mention.body.mentions as { id: string; username: string }[]).map((m) => m.id)).toEqual([
      agent.id,
    ]);
    noBase(mention.body, 'mention');
    // An old text with the base name still links to the person (the text is the author's own words).
    const old = await newPost(viewer, `hi @${base}`);
    expect(old.status).toBe(201);
    const oldMentions = old.body.mentions as { id: string; username: string }[];
    expect(oldMentions.map((m) => [m.id, m.username])).toEqual([[agent.id, code]]);
    const notified = await ctx.prisma.postMention.count({
      where: { postId: old.body.id as string, userId: agent.id },
    });
    expect(notified).toBe(1);

    // Search: the shown name finds the person; the base name finds nobody.
    const byCode = await ctx.http.get('/api/v1/search').query({ q: code, type: 'users' }).set(auth(viewer));
    expect(byCode.status).toBe(200);
    expect(JSON.stringify(byCode.body)).toContain(agent.id);
    noBase(byCode.body, 'search by code');
    const byBase = await ctx.http.get('/api/v1/search').query({ q: base, type: 'users' }).set(auth(viewer));
    expect(byBase.status).toBe(200);
    expect(JSON.stringify(byBase.body)).not.toContain(agent.id);

    // Follow lists (UserSummary) after a follow by the base name.
    expect((await ctx.http.put(`/api/v1/users/${base}/follow`).set(auth(viewer))).status).toBeLessThan(300);
    const followers = await ctx.http.get(`/api/v1/users/${code}/followers`).set(auth(viewer));
    expect(followers.status).toBe(200);
    expect(JSON.stringify(followers.body)).toContain(viewer.id);
    const following = await ctx.http.get(`/api/v1/users/${viewer.username}/following`).set(auth(viewer));
    expect(JSON.stringify(following.body)).toContain(code);
    noBase(following.body, 'following list');
  });

  it('a suspension gives the base back; the code stays theirs forever; reinstating restores it', async () => {
    const agent = await signup();
    const base = agent.username;
    const code = await activate(agent);
    await ctx.prisma.$transaction((tx) => suspendIn(tx, agent.id, 'test', new Date(), 30));
    expect(await shown(agent.id)).toBe(base);
    expect((await me(agent)).specialUsername).toBeUndefined();
    const row = await ctx.prisma.specialUsername.findFirstOrThrow({ where: { userId: agent.id } });
    expect(row).toMatchObject({ status: 'GRACE', graceUntil: null, endReason: 'SUSPENDED' });

    // The code no longer signs in (only the shown and base names do); an old link still leads to them.
    expect((await login(code, agent.password)).status).toBe(401);
    expect((await login(base, agent.password)).status).toBe(200);
    const viewer = await signup();
    const old = await ctx.http.get(`/api/v1/users/${code}`).set(auth(viewer));
    expect(old.status).toBe(200);
    expect(old.body.id).toBe(agent.id);

    // Nobody else can take it, even long after (coin names are never released).
    await sweepSpecialUsernames(ctx.prisma, new Date(Date.now() + 400 * DAY), 30);
    expect((await ctx.prisma.specialUsername.findUniqueOrThrow({ where: { id: row.id } })).status).toBe(
      'GRACE',
    );
    // (A code with `000` is also a premium shape: 400 `premium`; otherwise 409 `USERNAME_TAKEN`.)
    expect([400, 409]).toContain((await changeUsername(viewer, code)).status);
    expect(await giftError(viewer, code)).toBe('INVALID');
    const other = await ctx.prisma.$transaction((tx) =>
      grantSpecialIn(
        tx,
        viewer.id,
        code,
        { source: 'RECHARGE_AGENT', expiresAt: null, reason: 'test', via: 'system' },
        new Date(),
        30,
      ).then(
        () => 'granted',
        (err: unknown) => (err instanceof SpecialUsernameError ? err.reason : 'error'),
      ),
    );
    expect(other).toBe('TAKEN');

    // While suspended the agent may change the regular username; reinstating keeps that as the base.
    expect((await changeUsername(agent, `${base}z`)).status).toBe(200);
    expect(await ctx.prisma.$transaction((tx) => reinstateIn(tx, agent.id, new Date(), 30))).toBe('ACTIVE');
    expect(await shown(agent.id)).toBe(code);
    expect((await me(agent)).specialUsername).toMatchObject({ username: code, baseUsername: `${base}z` });
  });

  it('a gift with an end gives the base back, holds the name for the grace period, then releases it', async () => {
    const u = await signup();
    const other = await signup();
    const name = `star${u.id.slice(-6).replace(/-/g, '')}`;
    const t0 = new Date();
    await gift(u, name, new Date(t0.getTime() + DAY), t0);
    expect(await shown(u.id)).toBe(name);
    expect((await me(u)).specialUsername).toMatchObject({ source: 'ADMIN_GIFT', baseUsername: u.username });

    // Not due yet: nothing changes.
    expect(await sweepSpecialUsernames(ctx.prisma, new Date(t0.getTime() + DAY / 2), 30)).toBe(0);
    // Expired: the base is shown again; the gifted name is held for the person (30 days).
    expect(await sweepSpecialUsernames(ctx.prisma, new Date(t0.getTime() + 2 * DAY), 30)).toBeGreaterThan(0);
    expect(await shown(u.id)).toBe(u.username);
    expect((await me(u)).specialUsername).toBeUndefined();
    expect((await changeUsername(other, name)).body.error?.code).toBe('USERNAME_TAKEN');
    // The holder gets it back during the grace period.
    expect(await giftError(u, name)).toBeNull();
    expect(await shown(u.id)).toBe(name);
    await ctx.prisma.$transaction((tx) =>
      endSpecialIn(tx, u.id, 'REVOKED', new Date(t0.getTime() + 3 * DAY), 30, { via: 'cli' }),
    );
    expect(await shown(u.id)).toBe(u.username);
    // After the grace period: released.
    await sweepSpecialUsernames(ctx.prisma, new Date(t0.getTime() + 34 * DAY), 30);
    const changed = await changeUsername(other, name);
    expect(changed.status, JSON.stringify(changed.body)).toBe(200);
  });

  it('names are unique both ways and coin + digits is reserved', async () => {
    const a = await signup();
    const c = await signup();
    const special = `gem${a.id.slice(-6).replace(/-/g, '')}`;
    await gift(a, special, null);

    // A's base username and special username are both taken for everyone else.
    for (const name of [a.username, special]) {
      const res = await changeUsername(c, name);
      expect(res.status, name).toBe(409);
      expect(res.body.error.code).toBe('USERNAME_TAKEN');
      const avail = await ctx.http.get('/api/v1/users/username-availability').query({ username: name });
      expect(avail.body.available, name).toBe(false);
      expect(await giftError(c, name), name).toBe('TAKEN');
    }
    // …and A cannot be given a name another account uses.
    expect(await giftError(a, c.username)).toBe('TAKEN');
    // A registration with the base name is refused too.
    const reg = await ctx.http.post('/api/v1/auth/register').send({
      email: `dup${Date.now().toString(36)}@example.com`,
      password: 'correct horse battery staple',
      username: a.username,
      displayName: 'Dup',
      gender: 'UNDISCLOSED',
      locale: 'en',
    });
    expect(reg.status).toBe(409);

    // coin + digits: never a regular username, never a gift.
    const coin = await changeUsername(c, 'coin98765');
    expect(coin.status).toBe(409);
    expect(coin.body.error.code).toBe('USERNAME_TAKEN');
    expect(await giftError(c, 'coin98765')).toBe('INVALID');
    const avail = await ctx.http.get('/api/v1/users/username-availability').query({ username: 'coin98765' });
    expect(avail.body.available).toBe(false);
  });
});
