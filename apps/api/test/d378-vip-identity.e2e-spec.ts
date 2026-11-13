/**
 * D378 (owner 2026-11-11: the VIP identity perks; contract v1.131-social, CONVENTIONS §10.168): the perks the server
 * keeps — the animated signature (set, blocked words, shown in `UserVip.signature`), the golden IDs «آيدي ذهبي» (the
 * owner's stock in the panel, a holder's pick of their class, uniqueness, the chip in `UserSummary.goldenId`, the grace
 * after the membership and the return to the stock) and the premium username claimed free with VIP (its class, the end
 * with the membership, D146's grace). Holders against non-holders, a perk inherited from a lower tier, and a membership
 * that ends. End to end against PostgreSQL + Redis with the API as the DML-only runtime role.
 */
import { afterAll, beforeAll, describe, expect, it, vi } from 'vitest';
import { PremiumUsernamesService } from '../src/modules/premium-usernames/premium-usernames.service.js';
import { VipIdentityService } from '../src/modules/vip/vip-identity.service.js';
import { panel, type Admin, type Person } from './helpers/admin-panel.js';
import { expectContract } from './helpers/openapi.js';
import { createTestApp, withMigrationClient, type TestContext } from './helpers/test-app.js';

const ADMIN_KEY = 'admin-totp-test-key-0123456789-abcdefghijklmnop';
const VIP1 = '01a25200-0000-7000-8000-000000000001';
const DAY = 86_400_000;

const D378 = [
  'ANIMATED_COVER',
  'PREMIUM_USERNAME',
  'GOLDEN_ID',
  'ANIMATED_SIGNATURE',
  'POST_BADGE',
  'STORY_RING',
  'GLOWING_NAME',
  'DM_BUBBLE',
];

describe('D378 VIP identity perks', { timeout: 240_000 }, () => {
  let ctx: TestContext;
  const p = panel(() => ctx);
  let owner: Admin;
  /** VIP_2 (inherits VIP_1's perks), VIP_1, and a person without VIP. */
  let member: Person;
  let lower: Person;
  let plain: Person;
  let vip2Id: string;
  let identity: VipIdentityService;
  let premium: PremiumUsernamesService;

  const auth = (u: Person) => ({ Authorization: `Bearer ${u.token}` });
  const usernameOf = async (u: Person) =>
    (await ctx.prisma.userProfile.findUniqueOrThrow({ where: { userId: u.id } })).username;
  const giveVip = (u: Person, tierId: string, expiresAt: Date) =>
    withMigrationClient((db) =>
      db.vipMembership.upsert({
        where: { userId: u.id },
        create: { userId: u.id, tierId, startedAt: new Date(Date.now() - DAY), expiresAt },
        update: { tierId, expiresAt },
      }),
    );
  const profileOf = async (viewer: Person, u: Person) => {
    const res = await ctx.http.get(`/api/v1/users/${await usernameOf(u)}`).set(auth(viewer));
    expect(res.status).toBe(200);
    expectContract(res, 'getPublicProfile');
    return res.body as { vip?: { signature?: string }; goldenId?: { number: string; class: string } };
  };

  beforeAll(async () => {
    vi.useFakeTimers({ toFake: ['Date'], now: p.start() });
    ctx = await createTestApp({
      ADMIN_TOTP_KEY: ADMIN_KEY,
      ADMIN_SESSION_IDLE_SECONDS: '86400',
      ADMIN_SESSION_MAX_SECONDS: '604800',
      RATE_LIMIT_ADMIN_LOGIN_IP: '10000/900',
      RATE_LIMIT_ADMIN_IP: '10000/900',
      RATE_LIMIT_PREMIUM_RENT_USER: '10000/60',
      PREMIUM_USERNAME_SWEEP_INTERVAL_SECONDS: '0',
    });
    identity = ctx.app.get(VipIdentityService);
    premium = ctx.app.get(PremiumUsernamesService);
    owner = await p.makeAdmin(['OWNER']);
    // VIP_1 holds the server-kept perks; VIP_2 holds none of its own and inherits them.
    const patch = await p.send(owner, 'patch', `/admin/vip/tiers/${VIP1}`, {
      reason: 'owner D378',
      perks: [
        { code: 'BADGE' },
        { code: 'PREMIUM_USERNAME', value: 'GOLD' },
        { code: 'GOLDEN_ID', value: 'FOUR_DIGIT' },
        { code: 'ANIMATED_SIGNATURE' },
        { code: 'POST_BADGE' },
        { code: 'STORY_RING', value: '#FFAA00' },
        { code: 'GLOWING_NAME' },
        { code: 'DM_BUBBLE' },
        { code: 'ANIMATED_COVER' },
      ],
    });
    expect(patch.status, JSON.stringify(patch.body)).toBe(200);
    const vip2 = await p.send(owner, 'post', '/admin/vip/tiers', {
      code: 'VIP_2',
      nameAr: 'في آي بي 2',
      nameEn: 'VIP 2',
      color: '#3366CC',
      priceCoins: 2_000_000,
      durationDays: 30,
      enabled: true,
      perks: [{ code: 'CHAT_NAME_COLOR' }],
      reason: 'owner D378',
    });
    expect(vip2.status, JSON.stringify(vip2.body)).toBe(201);
    vip2Id = vip2.body.id as string;
    member = await p.signup();
    lower = await p.signup();
    plain = await p.signup();
    await giveVip(member, vip2Id, new Date(Date.now() + 30 * DAY));
    await giveVip(lower, VIP1, new Date(Date.now() + 30 * DAY));
  });
  afterAll(async () => {
    await ctx?.close();
    vi.useRealTimers();
  });

  it('the eight identity perks are built: available to the app, inherited by VIP_2', async () => {
    const res = await ctx.http.get('/api/v1/vip/tiers').set(auth(plain));
    expect(res.status).toBe(200);
    expectContract(res, 'listVipTiers');
    const t2 = (
      res.body.data as {
        code: string;
        effectivePerks: { code: string; available: boolean; fromTier?: string }[];
      }[]
    ).find((t) => t.code === 'VIP_2')!;
    for (const code of D378) {
      const perk = t2.effectivePerks.find((pk) => pk.code === code);
      expect(perk, code).toMatchObject({ available: true, fromTier: 'VIP_1' });
    }
  });

  describe('ANIMATED_SIGNATURE', () => {
    it('only a holder sets it (inherited counts); checked and audited; shown in UserVip.signature', async () => {
      const set = (u: Person, signature: string | null) =>
        ctx.http.put('/api/v1/me/vip/signature').set(auth(u)).send({ signature });
      const none = await set(plain, 'hello');
      expect(none.status).toBe(409);
      expectContract(none, 'setMyVipSignature');
      expect(none.body.error.details).toEqual([{ field: 'perk', issue: 'not_held' }]);

      const ok = await set(member, '  ملك   الليل ');
      expect(ok.status, JSON.stringify(ok.body)).toBe(200);
      expectContract(ok, 'setMyVipSignature');
      expect(ok.body).toEqual({ signature: 'ملك الليل' });
      expect((await profileOf(plain, member)).vip?.signature).toBe('ملك الليل');
      const audit = await ctx.prisma.auditLog.findFirst({
        where: { action: 'vip.signature.set', actorUserId: member.id },
      });
      expect(audit?.metadata).toEqual({ before: null, after: 'ملك الليل' });

      expect((await set(member, 'x'.repeat(25))).body.error.details).toEqual([
        { field: 'signature', issue: 'too_long' },
      ]);
      expect((await set(member, 'two\nlines')).body.error.details).toEqual([
        { field: 'signature', issue: 'invalid_format' },
      ]);
      await withMigrationClient((db) => db.searchBlockedWord.create({ data: { word: 'd378bad' } }));
      const blocked = await set(member, 'so D378BAD here');
      expect(blocked.status).toBe(400);
      expect(blocked.body.error.details).toEqual([{ field: 'signature', issue: 'blocked_word' }]);
      expect((await set(lower, 'VIP 1')).status).toBe(200);
      expect((await set(lower, null)).body).toEqual({ signature: null });
      expect((await profileOf(plain, lower)).vip?.signature).toBeUndefined();
    });
  });

  describe('GOLDEN_ID', () => {
    it('the owner manages the stock: classes from the digits, duplicates and bad numbers refused, audited', async () => {
      const bad = await p.send(owner, 'post', '/admin/vip/golden-ids', {
        numbers: ['8888', '2026', '12a4', '2026'],
        reason: 'stock D378',
      });
      expect(bad.status).toBe(400);
      expect(bad.body.error.details).toEqual([
        { field: 'numbers.2', issue: 'invalid_format' },
        { field: 'numbers.3', issue: 'duplicate_value' },
      ]);
      const add = await p.send(owner, 'post', '/admin/vip/golden-ids', {
        numbers: ['8888', '2026', '2027', '123', '4321'],
        reason: 'stock D378',
      });
      expect(add.status, JSON.stringify(add.body)).toBe(201);
      expectContract(add, 'addAdminVipGoldenIds');
      expect((add.body.data as { number: string; class: string }[]).map((r) => [r.number, r.class])).toEqual([
        ['123', 'THREE_DIGIT'],
        ['2026', 'FOUR_DIGIT'],
        ['2027', 'FOUR_DIGIT'],
        ['4321', 'FOUR_DIGIT'],
        ['8888', 'REPEATED'],
      ]);
      const again = await p.send(owner, 'post', '/admin/vip/golden-ids', {
        numbers: ['123'],
        reason: 'again',
      });
      expect(again.body.error.details).toEqual([{ field: 'numbers.0', issue: 'taken' }]);
      expect(await ctx.prisma.auditLog.count({ where: { action: 'vip.golden_id.stock_add' } })).toBe(1);
    });

    it('a holder picks a free number of their class (inherited); one holder each; the chip shows', async () => {
      const none = await ctx.http.get('/api/v1/me/vip/golden-ids').set(auth(plain));
      expect(none.status).toBe(200);
      expectContract(none, 'getMyVipGoldenIds');
      expect(none.body).toEqual({ class: null, mine: null, available: [] });
      expect(
        (await ctx.http.post('/api/v1/me/vip/golden-id').set(auth(plain)).send({ number: '2026' })).body.error
          .details,
      ).toEqual([{ field: 'perk', issue: 'not_held' }]);

      const choice = await ctx.http.get('/api/v1/me/vip/golden-ids').set(auth(member));
      expect(choice.body).toEqual({ class: 'FOUR_DIGIT', mine: null, available: ['2026', '2027', '4321'] });
      const wrong = await ctx.http
        .post('/api/v1/me/vip/golden-id')
        .set(auth(member))
        .send({ number: '8888' });
      expect(wrong.status).toBe(409);
      expect(wrong.body.error.details).toEqual([{ field: 'number', issue: 'class' }]);
      const missing = await ctx.http
        .post('/api/v1/me/vip/golden-id')
        .set(auth(member))
        .send({ number: '9999' });
      expect(missing.body.error.details).toEqual([{ field: 'number', issue: 'not_found' }]);

      const take = await ctx.http.post('/api/v1/me/vip/golden-id').set(auth(member)).send({ number: '2026' });
      expect(take.status, JSON.stringify(take.body)).toBe(200);
      expectContract(take, 'claimMyVipGoldenId');
      expect(take.body).toMatchObject({
        number: '2026',
        class: 'FOUR_DIGIT',
        state: 'HELD',
        graceUntil: null,
      });
      const taken = await ctx.http.post('/api/v1/me/vip/golden-id').set(auth(lower)).send({ number: '2026' });
      expect(taken.body.error.details).toEqual([{ field: 'number', issue: 'taken' }]);
      expect((await profileOf(plain, member)).goldenId).toEqual({ number: '2026', class: 'FOUR_DIGIT' });
      expect((await profileOf(plain, lower)).goldenId).toBeUndefined();

      // A switch gives the old number back (one number a holder).
      expect(
        (await ctx.http.post('/api/v1/me/vip/golden-id').set(auth(member)).send({ number: '2027' })).status,
      ).toBe(200);
      const rows = await ctx.prisma.vipGoldenId.findMany({ where: { number: { in: ['2026', '2027'] } } });
      expect(rows.map((r) => [r.number, r.state, r.holderId])).toEqual(
        expect.arrayContaining([
          ['2026', 'FREE', null],
          ['2027', 'HELD', member.id],
        ]),
      );
      // The owner cannot remove a held number; a free one goes.
      const held = await p.send(owner, 'post', '/admin/vip/golden-ids/2027/remove', {
        reason: 'remove D378',
      });
      expect(held.status).toBe(409);
      expect(held.body.error.details).toEqual([{ field: 'rule', issue: 'golden_id_held' }]);
      const gone = await p.send(owner, 'post', '/admin/vip/golden-ids/123/remove', { reason: 'remove D378' });
      expect(gone.status).toBe(200);
      expectContract(gone, 'removeAdminVipGoldenId');
      const list = await p.send(owner, 'get', '/admin/vip/golden-ids?state=HELD');
      expect(list.status).toBe(200);
      expectContract(list, 'listAdminVipGoldenIds');
      expect(list.body.data).toEqual([
        expect.objectContaining({
          number: '2027',
          holder: { id: member.id, username: await usernameOf(member) },
        }),
      ]);
    });

    it('the membership ends: hidden at once, kept 7 days in grace (back with VIP), then free', async () => {
      await giveVip(member, vip2Id, new Date(Date.now() - 1000));
      expect((await profileOf(plain, member)).goldenId).toBeUndefined();
      await identity.sweep(new Date());
      const grace = await ctx.prisma.vipGoldenId.findUniqueOrThrow({ where: { number: '2027' } });
      expect(grace).toMatchObject({ state: 'GRACE', holderId: member.id });
      // Nobody else can take it during the grace.
      expect(
        (await ctx.http.post('/api/v1/me/vip/golden-id').set(auth(lower)).send({ number: '2027' })).body.error
          .details,
      ).toEqual([{ field: 'number', issue: 'taken' }]);
      // A renewal brings it back.
      await giveVip(member, vip2Id, new Date(Date.now() + 30 * DAY));
      await identity.sweep(new Date());
      expect((await profileOf(plain, member)).goldenId).toEqual({ number: '2027', class: 'FOUR_DIGIT' });
      // Ends again; once the grace is over the number is free.
      await giveVip(member, vip2Id, new Date(Date.now() - 1000));
      await identity.sweep(new Date());
      await identity.sweep(new Date(Date.now() + 8 * DAY));
      expect(await ctx.prisma.vipGoldenId.findUniqueOrThrow({ where: { number: '2027' } })).toMatchObject({
        state: 'FREE',
        holderId: null,
      });
      expect(
        await ctx.prisma.auditLog.count({ where: { action: 'vip.golden_id.free' } }),
      ).toBeGreaterThanOrEqual(2);
      await giveVip(member, vip2Id, new Date(Date.now() + 30 * DAY));
    });

    it('a holder gives the number back', async () => {
      expect(
        (await ctx.http.post('/api/v1/me/vip/golden-id').set(auth(lower)).send({ number: '4321' })).status,
      ).toBe(200);
      const del = await ctx.http.delete('/api/v1/me/vip/golden-id').set(auth(lower));
      expect(del.status).toBe(204);
      expect((await ctx.http.delete('/api/v1/me/vip/golden-id').set(auth(lower))).status).toBe(204);
      expect(await ctx.prisma.vipGoldenId.findUniqueOrThrow({ where: { number: '4321' } })).toMatchObject({
        state: 'FREE',
      });
    });
  });

  describe('PREMIUM_USERNAME', () => {
    it('a holder claims a name of the class or lower free; the store says so; audited', async () => {
      const store = await ctx.http.get('/api/v1/premium-usernames').set(auth(member));
      expect(store.status).toBe(200);
      expectContract(store, 'getPremiumUsernameStore');
      expect(store.body.vipTier).toBe('GOLD');
      // Nothing is priced: the VIP's medals are suggested anyway (NOT_FOR_SALE, claimable).
      const suggested = store.body.suggestions as { tier: string; status: string }[];
      expect(suggested.length).toBeGreaterThan(0);
      expect(suggested.every((s) => ['GOLD', 'SILVER'].includes(s.tier) && s.status === 'NOT_FOR_SALE')).toBe(
        true,
      );
      expect((await ctx.http.get('/api/v1/premium-usernames').set(auth(plain))).body.vipTier).toBeNull();

      const claim = (u: Person, username: string) =>
        ctx.http.post('/api/v1/me/premium-username/vip-claim').set(auth(u)).send({ username });
      expect((await claim(plain, 'zqk7')).body.error.details).toEqual([{ field: 'perk', issue: 'not_held' }]);
      const ruby = await claim(member, '7777');
      expect(ruby.status).toBe(409);
      expect(ruby.body.error.details).toEqual([{ field: 'username', issue: 'class' }]);
      const before = await usernameOf(member);
      const ok = await claim(member, 'zqk7');
      expect(ok.status, JSON.stringify(ok.body)).toBe(201);
      expectContract(ok, 'claimVipPremiumUsername');
      const end = (await ctx.prisma.vipMembership.findUniqueOrThrow({ where: { userId: member.id } }))
        .expiresAt;
      expect(ok.body.premium).toMatchObject({
        username: 'zqk7',
        tier: 'GOLD',
        source: 'VIP',
        status: 'ACTIVE',
        expiresAt: end.toISOString(),
        regularUsername: before,
      });
      expect(await usernameOf(member)).toBe('zqk7');
      expect(await ctx.prisma.auditLog.count({ where: { action: 'premium_username.vip_claim' } })).toBe(1);
      // A second name while one is held.
      expect((await claim(member, 'zqk8')).body.error.code).toBe('PREMIUM_USERNAME_ACTIVE');
      // Another VIP cannot take it.
      expect((await claim(lower, 'zqk7')).body.error.code).toBe('PREMIUM_USERNAME_UNAVAILABLE');
    });

    it('the lease follows the membership; at its end the name goes into D146 grace and the username returns', async () => {
      const later = new Date(Date.now() + 60 * DAY);
      await giveVip(member, vip2Id, later);
      await premium.sweep(new Date());
      const lease = await ctx.prisma.premiumUsernameLease.findFirstOrThrow({ where: { userId: member.id } });
      expect(lease.expiresAt?.toISOString()).toBe(later.toISOString());
      await giveVip(member, vip2Id, new Date(Date.now() - 1000));
      const swept = await premium.sweep(new Date());
      expect(swept.expired).toBe(1);
      expect(
        await ctx.prisma.premiumUsernameLease.findFirstOrThrow({ where: { userId: member.id } }),
      ).toMatchObject({
        status: 'GRACE',
        source: 'VIP',
      });
      expect(await usernameOf(member)).not.toBe('zqk7');
    });
  });
});
