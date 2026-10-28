/**
 * D146 (openapi v1.28-live DRAFT, CONVENTIONS §6, §10.32): the regular username rule (registration
 * and `PUT /me/username`, grandfathered names), premium usernames (status, store, prices absent and
 * present, rent / renew with `Idempotency-Key`, insufficient coins, one winner under concurrency,
 * reserved names, reminders, expiry, grace, revert, give back) and the `premium-admin` CLI (prices,
 * reserved list, grant, revoke), end to end against PostgreSQL + Redis with the API as the DML-only
 * runtime role.
 */
import { execFileSync } from 'node:child_process';
import { randomUUID } from 'node:crypto';
import { fileURLToPath } from 'node:url';
import type request from 'supertest';
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';
import { Clock } from '../src/common/time/clock.js';
import { premiumTierOf } from '../src/modules/premium-usernames/premium-username-rules.js';
import { PremiumUsernamesService } from '../src/modules/premium-usernames/premium-usernames.service.js';
import { creditIn } from '../src/modules/wallet/wallet-ledger.js';
import { expectContract, operations } from './helpers/openapi.js';
import { createTestApp, newUser, registerVerified, type TestContext } from './helpers/test-app.js';

class FakeClock extends Clock {
  private ms = Date.now();
  now(): Date {
    return new Date(this.ms);
  }
  advance(seconds: number): void {
    this.ms += Math.round(seconds * 1000);
  }
}

const DAY = 24 * 3600;

interface TestUser {
  readonly id: string;
  username: string;
  readonly email: string;
  readonly token: string;
}

/** Runs `pnpm premium:admin …` as on the server (migration role, a child process). */
function premiumAdmin(...args: string[]): { status: number; out: string } {
  try {
    const out = execFileSync('pnpm', ['-s', 'premium:admin', ...args], {
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

const OPS = [
  'changeUsername',
  'getPremiumUsernameStore',
  'getPremiumUsernameStatus',
  'getMyPremiumUsername',
  'releaseMyPremiumUsername',
  'rentPremiumUsername',
] as const;

describe('D146 contract coverage', () => {
  it('openapi declares the premium username operations', () => {
    const ids = operations().map((o) => o.operationId);
    for (const id of OPS) expect(ids).toContain(id);
  });
});

describe('D146 premium usernames', { timeout: 300_000 }, () => {
  const clock = new FakeClock();
  let ctx: TestContext;
  let premium: PremiumUsernamesService;
  let seq = 0;

  const auth = (u: TestUser) => ({ Authorization: `Bearer ${u.token}` });
  const signup = async (): Promise<TestUser> => {
    const { res, payload } = await registerVerified(ctx);
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    return {
      id: res.body.user.id as string,
      username: res.body.user.username as string,
      email: String(payload.email).toLowerCase(),
      token: res.body.tokens.accessToken as string,
    };
  };
  const coins = (u: TestUser, amount: number) =>
    ctx.prisma.$transaction((tx) => creditIn(tx, u.id, BigInt(amount), 'ADMIN_GRANT', randomUUID()));
  const wallet = async (u: TestUser) => {
    const res = await ctx.http.get('/api/v1/wallet/me').set(auth(u));
    return res.body.coins as number;
  };
  const expectCode = (res: request.Response, status: number, code: string) => {
    expect(res.status, JSON.stringify(res.body)).toBe(status);
    expect(res.body.error.code).toBe(code);
  };
  const status = async (u: TestUser, name: string) => {
    const res = await ctx.http.get(`/api/v1/premium-usernames/${encodeURIComponent(name)}`).set(auth(u));
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    expectContract(res, 'getPremiumUsernameStatus');
    return res.body as {
      status: string;
      tier: string | null;
      priceCoins: number | null;
      heldUntil: string | null;
    };
  };
  const rent = (u: TestUser, username: string, priceCoins: number, key: string = randomUUID()) =>
    ctx.http
      .post('/api/v1/me/premium-username/rentals')
      .set(auth(u))
      .set('Idempotency-Key', key)
      .send({ username, priceCoins });
  const me = async (u: TestUser) => {
    const res = await ctx.http.get('/api/v1/me').set(auth(u));
    expect(res.status).toBe(200);
    expectContract(res, 'getMe');
    return res.body as { username: string; premiumTier?: string };
  };
  const mine = async (u: TestUser) => {
    const res = await ctx.http.get('/api/v1/me/premium-username').set(auth(u));
    expect(res.status).toBe(200);
    expectContract(res, 'getMyPremiumUsername');
    return res.body.premium as {
      username: string;
      status: string;
      source: string;
      expiresAt: string | null;
      graceUntil: string | null;
      regularUsername: string;
      canRenew: boolean;
      renewPriceCoins: number | null;
    } | null;
  };
  /** A fresh, unused GOLD name (5 digits, not one repeated digit). */
  const goldName = (): string => {
    for (;;) {
      seq += 1;
      const name = String(10000 + ((Date.now() + seq * 7919) % 89999));
      if (premiumTierOf(name) === 'GOLD') return name;
    }
  };
  /** A fresh, unused SILVER name (6+ letters, no pattern). */
  const silverName = (): string => {
    for (;;) {
      seq += 1;
      const n = (Date.now() + seq * 104729).toString(26).replace(/[0-9]/g, (d) => 'qrstuvwxyz'[Number(d)]!);
      const name = `qx${n}`.slice(0, 12);
      if (premiumTierOf(name) === 'SILVER') return name;
    }
  };

  beforeAll(async () => {
    ctx = await createTestApp(
      {
        PREMIUM_USERNAME_SWEEP_INTERVAL_SECONDS: '0',
        RATE_LIMIT_PREMIUM_RENT_USER: '10000/60',
        RATE_LIMIT_USERNAME_CHANGE_USER: '10000/60',
      },
      [{ token: Clock, value: clock }],
    );
    premium = ctx.app.get(PremiumUsernamesService);
  });
  afterAll(async () => ctx?.close());
  beforeEach(async () => {
    await ctx.prisma.premiumUsernameTierPrice.deleteMany({});
    await ctx.prisma.premiumUsernameNamePrice.deleteMany({});
  });

  describe('the regular username rule', () => {
    it.each([
      ['abc', 'premium'],
      ['7777', 'premium'],
      ['abcdef', 'premium'],
      ['123456', 'premium'],
      ['aaa777', 'premium'],
      ['ali777', 'premium'],
      ['ab_1', 'too_short'],
      ['abc_def', 'letters_and_digits'],
      ['Abc123', 'invalid_format'],
      ['abc.12', 'invalid_format'],
      ['_abc12', 'invalid_format'],
      [`a1${'b'.repeat(29)}`, 'too_long'],
    ])('registration refuses %s (%s)', async (username, issue) => {
      const res = await ctx.http.post('/api/v1/auth/register').send(newUser({ username }));
      expectCode(res, 400, 'VALIDATION_FAILED');
      expect(res.body.error.details).toEqual([{ field: 'username', issue }]);
    });

    it('accepts letters with digits (and _), and keeps grandfathered names working', async () => {
      const res = await ctx.http
        .post('/api/v1/auth/register')
        .send(newUser({ username: `sara_${String(Date.now()).slice(-6)}` }));
      expect(res.status, JSON.stringify(res.body)).toBe(202);
      // A name from before D146 (5 letters, a dot) still logs in, has a profile and is looked up.
      const u = await signup();
      await ctx.prisma.userProfile.update({ where: { userId: u.id }, data: { username: 'old.nm' } });
      const login = await ctx.http
        .post('/api/v1/auth/login')
        .send({ identifier: 'old.nm', password: 'correct horse battery staple' });
      expect(login.status, JSON.stringify(login.body)).toBe(200);
      const profile = await ctx.http.get('/api/v1/users/old.nm').set(auth(u));
      expect(profile.status).toBe(200);
      expect(profile.body.premiumTier).toBeUndefined();
      // A grandfathered short name is TAKEN in the store (and carries no badge).
      await ctx.prisma.userProfile.update({ where: { userId: u.id }, data: { username: 'oldnm' } });
      expect((await status(u, 'oldnm')).status).toBe('TAKEN');
      expect((await me(u)).premiumTier).toBeUndefined();
    });

    it('PUT /me/username: the rule, taken, reserved, same name, success and the audit row', async () => {
      const u = await signup();
      const other = await signup();
      const put = (username: string) => ctx.http.put('/api/v1/me/username').set(auth(u)).send({ username });
      let res = await put('777');
      expectCode(res, 400, 'VALIDATION_FAILED');
      expect(res.body.error.details).toEqual([{ field: 'username', issue: 'premium' }]);
      expectCode(await put('abcdefg'), 400, 'VALIDATION_FAILED');
      expectCode(await put(other.username), 409, 'USERNAME_TAKEN');
      res = await put(u.username);
      expect(res.status).toBe(200);
      const next = `nm_${String(Date.now()).slice(-8)}`;
      res = await put(next);
      expect(res.status, JSON.stringify(res.body)).toBe(200);
      expectContract(res, 'changeUsername');
      expect(res.body.username).toBe(next);
      const audit = await ctx.prisma.auditLog.findFirst({
        where: { action: 'user.username.change', targetId: u.id },
        orderBy: { createdAt: 'desc' },
      });
      expect(audit?.metadata).toEqual({ from: u.username, to: next });
      // The old name is free again.
      const free = await ctx.http.get('/api/v1/users/username-availability').query({ username: u.username });
      expect(free.body.available).toBe(true);
      u.username = next;
    });
  });

  describe('status, prices and the store', () => {
    it('without prices nothing is on sale; prices come only from premium-admin', async () => {
      const u = await signup();
      const store = await ctx.http.get('/api/v1/premium-usernames').set(auth(u));
      expect(store.status).toBe(200);
      expectContract(store, 'getPremiumUsernameStore');
      expect(store.body.tiers).toEqual([
        { tier: 'LEGEND', priceCoins: null },
        { tier: 'RUBY', priceCoins: null },
        { tier: 'GOLD', priceCoins: null },
        { tier: 'SILVER', priceCoins: null },
      ]);
      expect(store.body.suggestions).toEqual([]);
      const name = goldName();
      expect(await status(u, name)).toMatchObject({ status: 'NOT_FOR_SALE', tier: 'GOLD', priceCoins: null });
      await coins(u, 100_000);
      expectCode(await rent(u, name, 1000), 409, 'PREMIUM_USERNAME_UNAVAILABLE');

      expect(premiumAdmin('price', 'set', '--tier', 'GOLD', '--coins', '1000').status).toBe(0);
      expect(premiumAdmin('price', 'set', '--username', name, '--coins', '2500').status).toBe(0);
      expect(await status(u, name)).toMatchObject({ status: 'AVAILABLE', tier: 'GOLD', priceCoins: 2500 });
      expect(await status(u, '86420')).toMatchObject({ status: 'AVAILABLE', priceCoins: 1000 });
      expect(await status(u, '88888')).toMatchObject({ status: 'NOT_FOR_SALE', tier: 'RUBY' });
      const priced = await ctx.http.get('/api/v1/premium-usernames?tier=GOLD').set(auth(u));
      expectContract(priced, 'getPremiumUsernameStore');
      expect(priced.body.tiers[2]).toEqual({ tier: 'GOLD', priceCoins: 1000 });
      const sugg = priced.body.suggestions as { tier: string; status: string }[];
      expect(sugg.length).toBeGreaterThan(0);
      expect(sugg.every((s) => s.tier === 'GOLD' && s.status === 'AVAILABLE')).toBe(true);
      expect(premiumAdmin('price', 'clear', '--username', name).out).toContain('price removed');
      expect(premiumAdmin('price', 'list').out).toContain('GOLD     1000 coins / month');
      expect(premiumAdmin('price', 'set', '--tier', 'GOLD', '--coins', '0').status).toBe(1);
      const audits = await ctx.prisma.auditLog.count({ where: { action: 'premium_username.price' } });
      expect(audits).toBeGreaterThanOrEqual(3);
    });

    it('INVALID, REGULAR and RESERVED (code list, kabso, the owner list)', async () => {
      const u = await signup();
      expect((await status(u, 'a b')).status).toBe('INVALID');
      expect((await status(u, 'sara2026')).status).toBe('REGULAR');
      expect(await status(u, '@Admin')).toMatchObject({ status: 'RESERVED', tier: 'GOLD' });
      expect((await status(u, 'kabso')).status).toBe('RESERVED');
      const word = silverName();
      expect(premiumAdmin('reserve', 'add', word, '--reason', 'test').status).toBe(0);
      expect((await status(u, word)).status).toBe('RESERVED');
      expect(premiumAdmin('reserve', 'remove', word).status).toBe(0);
      expect((await status(u, word)).status).not.toBe('RESERVED');
    });
  });

  describe('rent, renew, idempotency and concurrency', () => {
    it('rents: the username changes, the badge shows, the old name is kept, replay and conflicts', async () => {
      premiumAdmin('price', 'set', '--tier', 'GOLD', '--coins', '1000');
      const u = await signup();
      const regular = u.username;
      const name = goldName();
      // Header and body checks first.
      expectCode(
        await ctx.http
          .post('/api/v1/me/premium-username/rentals')
          .set(auth(u))
          .send({ username: name, priceCoins: 1000 }),
        400,
        'VALIDATION_FAILED',
      );
      // Insufficient coins: nothing changes.
      await coins(u, 999);
      expectCode(await rent(u, name, 1000), 409, 'INSUFFICIENT_COINS');
      expect((await me(u)).username).toBe(regular);
      expect(await ctx.prisma.premiumUsernameLease.count({ where: { userId: u.id } })).toBe(0);
      await coins(u, 10_001);
      expectCode(await rent(u, name, 999), 409, 'PREMIUM_USERNAME_PRICE_CHANGED');
      const key = randomUUID();
      const first = await rent(u, name, 1000, key);
      expect(first.status, JSON.stringify(first.body)).toBe(201);
      expectContract(first, 'rentPremiumUsername');
      expect(first.body.coins).toBe(10_000);
      expect(first.body.premium).toMatchObject({
        username: name,
        tier: 'GOLD',
        status: 'ACTIVE',
        source: 'RENT',
        regularUsername: regular,
      });
      // Replay: 200, same answer, charged once.
      const again = await rent(u, name, 1000, key);
      expect(again.status).toBe(200);
      expect(again.body.coins).toBe(10_000);
      expect(await wallet(u)).toBe(10_000);
      expectCode(await rent(u, '97531', 1000, key), 409, 'IDEMPOTENCY_CONFLICT');
      // The account shows the premium name with its badge everywhere.
      expect(await me(u)).toMatchObject({ username: name, premiumTier: 'GOLD' });
      const profile = await ctx.http.get(`/api/v1/users/${name}`).set(auth(u));
      expect(profile.status).toBe(200);
      expect(profile.body.premiumTier).toBe('GOLD');
      const search = await ctx.http.get(`/api/v1/search?type=users&q=${name}`).set(auth(u));
      expect(search.status, JSON.stringify(search.body)).toBe(200);
      expect(
        (search.body.data as { username: string; premiumTier?: string }[]).find((r) => r.username === name)
          ?.premiumTier,
      ).toBe('GOLD');
      // The regular name is kept for the renter.
      const reg = await ctx.http.post('/api/v1/auth/register').send(newUser({ username: regular }));
      expectCode(reg, 409, 'USERNAME_TAKEN');
      const other = await signup();
      expectCode(
        await ctx.http.put('/api/v1/me/username').set(auth(other)).send({ username: regular }),
        409,
        'USERNAME_TAKEN',
      );
      expect((await status(other, name)).status).toBe('TAKEN');
      expect((await status(u, name)).status).toBe('YOURS');
      // One at a time; no username change while it is active.
      expectCode(await rent(u, '86420', 1000), 409, 'PREMIUM_USERNAME_ACTIVE');
      expectCode(
        await ctx.http
          .put('/api/v1/me/username')
          .set(auth(u))
          .send({ username: `nm_${String(Date.now()).slice(-7)}` }),
        409,
        'PREMIUM_USERNAME_ACTIVE',
      );
      // Ledger and audit.
      const ledger = await ctx.prisma.walletLedgerEntry.findMany({
        where: { userId: u.id, reason: 'PREMIUM_USERNAME_RENT' },
      });
      expect(ledger.map((l) => Number(l.delta))).toEqual([-1000]);
      expect(
        await ctx.prisma.auditLog.count({ where: { action: 'premium_username.rent', targetId: u.id } }),
      ).toBe(1);

      // Renew: +30 days, a RENEW ledger row.
      const before = (await mine(u))!;
      const renewed = await rent(u, name, 1000);
      expect(renewed.status).toBe(201);
      expect(
        new Date(renewed.body.premium.expiresAt as string).getTime() - new Date(before.expiresAt!).getTime(),
      ).toBe(30 * DAY * 1000);
      expect(
        await ctx.prisma.walletLedgerEntry.count({
          where: { userId: u.id, reason: 'PREMIUM_USERNAME_RENEW' },
        }),
      ).toBe(1);

      // Give back: regular name again, the name is free at once (no grace), no refund.
      const del = await ctx.http.delete('/api/v1/me/premium-username').set(auth(u));
      expect(del.status).toBe(204);
      expect(await me(u)).toEqual(expect.objectContaining({ username: regular }));
      expect((await me(u)).premiumTier).toBeUndefined();
      expect((await status(other, name)).status).toBe('AVAILABLE');
      expect(await wallet(u)).toBe(9_000);
      expect((await ctx.http.delete('/api/v1/me/premium-username').set(auth(u))).status).toBe(204);
    });

    it('two people renting one name at once: exactly one wins, the other is not charged', async () => {
      premiumAdmin('price', 'set', '--tier', 'GOLD', '--coins', '500');
      const a = await signup();
      const b = await signup();
      await coins(a, 1000);
      await coins(b, 1000);
      const name = goldName();
      const results = await Promise.all([rent(a, name, 500), rent(b, name, 500)]);
      const statuses = results.map((r) => r.status).sort();
      expect(statuses, JSON.stringify(results.map((r) => r.body as unknown))).toEqual([201, 409]);
      expect(results.find((r) => r.status === 409)!.body.error.code).toBe('PREMIUM_USERNAME_UNAVAILABLE');
      expect((await wallet(a)) + (await wallet(b))).toBe(1500);
      expect(
        await ctx.prisma.premiumUsernameLease.count({ where: { username: name, status: 'ACTIVE' } }),
      ).toBe(1);
    });
  });

  describe('reminders, expiry, grace and revert', () => {
    it('reminds at 3 and 1 days, reverts at the end, holds 7 days for the renter, then frees it', async () => {
      premiumAdmin('price', 'set', '--tier', 'SILVER', '--coins', '300');
      // Only this test's lease is swept (earlier tests' leases would expire with the clock).
      await ctx.prisma.premiumUsernameLease.updateMany({
        where: { status: { in: ['ACTIVE', 'GRACE'] } },
        data: { status: 'ENDED', endReason: 'REVOKED' },
      });
      const u = await signup();
      const other = await signup();
      await coins(u, 10_000);
      await coins(other, 10_000);
      const regular = u.username;
      const name = silverName();
      expect((await rent(u, name, 300)).status).toBe(201);

      clock.advance(26 * DAY + 3600);
      expect(await premium.sweep(clock.now())).toMatchObject({ reminded: 0 });
      clock.advance(DAY);
      expect((await premium.sweep(clock.now())).reminded).toBe(1);
      expect((await premium.sweep(clock.now())).reminded).toBe(0);
      clock.advance(2 * DAY);
      expect((await premium.sweep(clock.now())).reminded).toBe(1);
      const notes = await ctx.http.get('/api/v1/notifications').set(auth(u));
      expectContract(notes, 'listNotifications');
      const expiring = (notes.body.data as { type: string; target: { type: string; id: string } }[]).filter(
        (n) => n.type === 'PREMIUM_USERNAME_EXPIRING',
      );
      expect(expiring.length).toBe(2);
      expect(expiring[0]!.target).toMatchObject({ type: 'PREMIUM_USERNAME', id: name });

      clock.advance(DAY);
      expect((await premium.sweep(clock.now())).expired).toBe(1);
      expect(await me(u)).toEqual(expect.objectContaining({ username: regular }));
      const grace = (await mine(u))!;
      expect(grace).toMatchObject({
        status: 'GRACE',
        username: name,
        regularUsername: regular,
        canRenew: true,
      });
      expect(await status(other, name)).toMatchObject({ status: 'HELD' });
      expectCode(await rent(other, name, 300), 409, 'PREMIUM_USERNAME_UNAVAILABLE');
      expect((await status(u, name)).status).toBe('YOURS_GRACE');
      const types = (
        (await ctx.http.get('/api/v1/notifications').set(auth(u))).body.data as { type: string }[]
      ).map((n) => n.type);
      expect(types).toContain('PREMIUM_USERNAME_EXPIRED');
      expect(
        await ctx.prisma.auditLog.count({ where: { action: 'premium_username.expire', targetId: u.id } }),
      ).toBe(1);

      // The renter takes it back during grace: a new period from now.
      const back = await rent(u, name, 300);
      expect(back.status, JSON.stringify(back.body)).toBe(201);
      expect(await me(u)).toMatchObject({ username: name, premiumTier: 'SILVER' });

      // Expire again and let the grace run out: the name returns to the pool.
      clock.advance(31 * DAY);
      expect((await premium.sweep(clock.now())).expired).toBe(1);
      clock.advance(8 * DAY);
      expect((await premium.sweep(clock.now())).ended).toBe(1);
      expect(await mine(u)).toBeNull();
      expect((await status(other, name)).status).toBe('AVAILABLE');
      expect(
        await ctx.prisma.auditLog.count({ where: { action: 'premium_username.grace_end', targetId: u.id } }),
      ).toBe(1);
    });
  });

  describe('premium-admin grant and revoke', () => {
    it('grants without an end (no charge, no renewal), refuses taken names, revokes', async () => {
      const u = await signup();
      const regular = u.username;
      expect(premiumAdmin('grant', '--user', u.email, '--username', 'support', '--forever').status).toBe(0);
      expect(await me(u)).toMatchObject({ username: 'support', premiumTier: 'SILVER' });
      expect(await mine(u)).toMatchObject({ source: 'GRANT', expiresAt: null, canRenew: false });
      expect(await wallet(u)).toBe(0);
      const other = await signup();
      const refused = premiumAdmin('grant', '--user', other.email, '--username', 'support', '--days', '3');
      expect(refused.status).toBe(1);
      expect(refused.out).toContain('another user');
      expect(premiumAdmin('grant', '--user', other.email, '--username', regular, '--days', '3').status).toBe(
        1,
      );
      expect(premiumAdmin('list').out).toContain('@support');
      expect(premiumAdmin('revoke', '--user', u.email).out).toContain('back to @');
      expect((await me(u)).username).toBe(regular);
      expect(premiumAdmin('revoke', '--user', u.email).out).toContain('nothing changed');
      expect(
        await ctx.prisma.auditLog.count({ where: { action: 'premium_username.grant', targetId: u.id } }),
      ).toBe(1);
      expect(
        await ctx.prisma.auditLog.count({ where: { action: 'premium_username.revoke', targetId: u.id } }),
      ).toBe(1);
    });
  });
});
