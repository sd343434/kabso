/**
 * D252 (owner 2026-11-03: «اصنع صفحة شراء vip … واضافة الفي اي بي وترتيبه يكون من لوحة كل في اي بي له ميزات وامتيازات
 * مختلفة»; contract v1.82-social, CONVENTIONS §10.93): VIP tiers managed in the admin panel (OWNER adds, edits, orders,
 * switches on / off, each with its own perks; SUPPORT reads; audited) and bought with coins in the app — new, renew,
 * upgrade, a downgrade refused, a tier switched off, the price checked, an Idempotency-Key replay, two purchases at once,
 * the `VIP_PURCHASE` ledger row and an ended membership. End to end against PostgreSQL + Redis with the API as the
 * DML-only runtime role.
 */
import { randomUUID } from 'node:crypto';
import { afterAll, beforeAll, describe, expect, it, vi } from 'vitest';
import { creditIn } from '../src/modules/wallet/wallet-ledger.js';
import { panel, type Admin, type Person } from './helpers/admin-panel.js';
import { expectContract, operations } from './helpers/openapi.js';
import { createTestApp, withMigrationClient, type TestContext } from './helpers/test-app.js';

const ADMIN_KEY = 'admin-totp-test-key-0123456789-abcdefghijklmnop';
const DAY = 86_400_000;

describe('D252 contract coverage', () => {
  it('openapi v1.82-social declares the VIP operations', () => {
    const ids = operations().map((o) => `${o.operationId} ${o.method.toUpperCase()} ${o.path}`);
    for (const op of [
      'listVipTiers GET /api/v1/vip/tiers',
      'getMyVip GET /api/v1/me/vip',
      'buyVip POST /api/v1/me/vip/purchases',
      'listAdminVipTiers GET /api/v1/admin/vip/tiers',
      'createAdminVipTier POST /api/v1/admin/vip/tiers',
      'updateAdminVipTier PATCH /api/v1/admin/vip/tiers/{tierId}',
      'enableAdminVipTier POST /api/v1/admin/vip/tiers/{tierId}/enable',
      'disableAdminVipTier POST /api/v1/admin/vip/tiers/{tierId}/disable',
      'reorderAdminVipTiers PUT /api/v1/admin/vip/tier-order',
    ]) {
      expect(ids).toContain(op);
    }
  });
});

describe('D252 purchase VIP', { timeout: 180_000 }, () => {
  let ctx: TestContext;
  const p = panel(() => ctx);
  let owner: Admin;
  const tiers: Record<string, string> = {};

  const auth = (u: Person) => ({ Authorization: `Bearer ${u.token}` });
  const coins = (u: Person, amount: number) =>
    ctx.prisma.$transaction((tx) => creditIn(tx, u.id, BigInt(amount), 'ADMIN_GRANT', randomUUID()));
  const wallet = async (u: Person) =>
    (await ctx.http.get('/api/v1/wallet/me').set(auth(u))).body.coins as number;
  const buy = (u: Person, tier: string, priceCoins: number, key: string = randomUUID()) =>
    ctx.http
      .post('/api/v1/me/vip/purchases')
      .set(auth(u))
      .set('Idempotency-Key', key)
      .send({ tierId: tiers[tier] ?? tier, priceCoins });
  const mine = async (u: Person) => {
    const res = await ctx.http.get('/api/v1/me/vip').set(auth(u)).set('Accept-Language', 'en');
    expect(res.status).toBe(200);
    expectContract(res, 'getMyVip');
    return res.body.membership as {
      tier: { id: string; code: string; name: string; onSale: boolean };
      startedAt: string;
      expiresAt: string;
      daysLeft: number;
    } | null;
  };
  const listed = async (u: Person, lang = 'en') => {
    const res = await ctx.http.get('/api/v1/vip/tiers').set(auth(u)).set('Accept-Language', lang);
    expect(res.status).toBe(200);
    expectContract(res, 'listVipTiers');
    return res.body as {
      data: {
        id: string;
        code: string;
        name: string;
        level: number;
        priceCoins: number;
        badgeAnimation: string | null;
        badgeStill: string | null;
        perks: {
          code: string;
          title: string;
          available: boolean;
          animation: string | null;
          still: string | null;
          artWidth: number | null;
          artHeight: number | null;
        }[];
      }[];
      maxAheadDays: number;
    };
  };
  const perk = (code: string, enabled = true) => ({
    code,
    titleAr: `ميزة ${code}`,
    titleEn: `Perk ${code}`,
    descriptionAr: 'وصف',
    descriptionEn: 'About it',
    enabled,
  });
  const addTier = async (code: string, priceCoins: number, extra: object = {}) => {
    const res = await p.send(owner, 'post', '/admin/vip/tiers', {
      code,
      nameAr: `في آي بي ${code.slice(-1)}`,
      nameEn: `VIP ${code.slice(-1)}`,
      color: '#c9a227',
      priceCoins,
      durationDays: 30,
      enabled: true,
      reason: 'owner D252',
      // D258's renewal discount has its own suite (d258-vip-renewal): these tiers renew at the list price.
      renewalDiscountPercent: 0,
      ...extra,
    });
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    expectContract(res, 'createAdminVipTier');
    tiers[code] = res.body.id as string;
    return res;
  };
  const endMembershipOf = (u: Person) =>
    withMigrationClient((db) =>
      db.vipMembership.update({
        where: { userId: u.id },
        data: { startedAt: new Date(Date.now() - 40 * DAY), expiresAt: new Date(Date.now() - 1000) },
      }),
    );
  // Clears the seeded VIP 1 so the panel / buying tests start from a known, empty set.
  const truncate = () =>
    withMigrationClient(async (db) => {
      await db.vipPurchase.deleteMany({});
      await db.vipMembership.deleteMany({});
      await db.vipTierPerk.deleteMany({});
      await db.vipTier.deleteMany({});
    });

  beforeAll(async () => {
    vi.useFakeTimers({ toFake: ['Date'], now: p.start() });
    ctx = await createTestApp({
      ADMIN_TOTP_KEY: ADMIN_KEY,
      ADMIN_SESSION_IDLE_SECONDS: '86400',
      ADMIN_SESSION_MAX_SECONDS: '604800',
      RATE_LIMIT_ADMIN_LOGIN_IP: '10000/900',
      RATE_LIMIT_ADMIN_IP: '10000/900',
    });
    owner = await p.makeAdmin(['OWNER']);
  });
  afterAll(async () => {
    await ctx?.close();
    vi.useRealTimers();
  });

  it('seeds VIP 1 with the owner badge and perk art (real art out of the box)', async () => {
    const u = await p.signup();
    const list = await listed(u);
    const vip1 = list.data.find((t) => t.code === 'VIP_1');
    expect(vip1, 'VIP 1 should be seeded').toBeDefined();
    expect(vip1!.priceCoins).toBe(1_000_000);
    // All art is hosted and uploaded from the admin panel after merge: seeded URLs are null, nothing is bundled.
    expect(vip1!.badgeStill).toBeNull();
    expect(vip1!.badgeAnimation).toBeNull();
    expect(vip1!.perks.map((pk) => pk.code)).toEqual([
      'BADGE',
      'AVATAR_FRAME',
      'PROFILE_CARD',
      'ENTRY_BANNER',
      'CHAT_BUBBLE',
      'ENTRY_EFFECT',
      // D258: the owner's VIP 1 list completed.
      'CHAT_NAME_COLOR',
      'MIC_WAVE',
      'DAILY_BULLET',
      'PROFILE_VISITORS',
      // D374: the owner removed DAILY_COINS — its seeded row is kept but never listed.
      'LEVEL_SPEEDUP',
    ]);
    expect(vip1!.perks.every((pk) => pk.still === null && pk.animation === null)).toBe(true);
    await truncate();
  });

  it('the panel: the OWNER adds tiers with their own perks, orders and switches them; SUPPORT only reads', async () => {
    await truncate();
    const support = await p.makeAdmin(['SUPPORT']);
    const empty = await p.send(support, 'get', '/admin/vip/tiers');
    expect(empty.status).toBe(200);
    expectContract(empty, 'listAdminVipTiers');
    // D258: the perks the app does are listed for the panel.
    expect(empty.body).toMatchObject({
      data: [],
      // D378 (§10.168): + the eight identity perks.
      builtPerks: [
        'ANIMATED_COVER',
        'ANIMATED_SIGNATURE',
        'AVATAR_FRAME',
        'BADGE',
        'CHAT_BUBBLE',
        'CHAT_NAME_COLOR',
        'DAILY_BULLET',
        'DM_BUBBLE',
        'ENTRY_BANNER',
        'ENTRY_EFFECT',
        'GLOWING_NAME',
        'GOLDEN_ID',
        'LEVEL_SPEEDUP',
        'MIC_WAVE',
        'POST_BADGE',
        'PREMIUM_USERNAME',
        'PROFILE_CARD',
        'PROFILE_VISITORS',
        'STORY_RING',
      ],
    });
    expect(empty.body.suggestedPerks).toContain('BADGE');
    const denied = await p.send(support, 'post', '/admin/vip/tiers', {
      code: 'VIP_X',
      nameAr: 'x',
      nameEn: 'x',
      color: '#000000',
      priceCoins: 1,
      durationDays: 1,
      reason: 'no',
    });
    expect(denied.status).toBe(403);

    // A tier starts switched off unless the owner says otherwise.
    const first = await addTier('VIP_1', 1_000, {
      enabled: undefined,
      badgeAnimation: 'https://cdn.kabso.test/vip/vip1_badge.svga',
      badgeStill: 'https://cdn.kabso.test/vip/vip1_badge.png',
      perks: [
        perk('BADGE'),
        {
          ...perk('AVATAR_FRAME'),
          animation: 'https://cdn.kabso.test/vip/vip1_frame.svga',
          still: 'https://cdn.kabso.test/vip/vip1_frame.png',
          artWidth: 500,
          artHeight: 500,
        },
      ],
    });
    expect(first.body).toMatchObject({
      code: 'VIP_1',
      sortOrder: 1,
      color: '#C9A227',
      enabled: false,
      activeMembers: 0,
      badgeAnimation: 'https://cdn.kabso.test/vip/vip1_badge.svga',
      badgeStill: 'https://cdn.kabso.test/vip/vip1_badge.png',
      perks: [
        // D258: built, so available.
        { code: 'BADGE', enabled: true, available: true },
        {
          code: 'AVATAR_FRAME',
          enabled: true,
          available: true,
          animation: 'https://cdn.kabso.test/vip/vip1_frame.svga',
          still: 'https://cdn.kabso.test/vip/vip1_frame.png',
          artWidth: 500,
          artHeight: 500,
        },
      ],
    });
    await addTier('VIP_2', 3_000, {
      perks: [perk('BADGE'), perk('ENTRY_BANNER'), perk('HIDDEN_VISIT', false)],
    });
    await addTier('VIP_3', 9_000, { perks: [perk('ENTRY_EFFECT')] });

    const dup = await p.send(owner, 'post', '/admin/vip/tiers', {
      code: 'VIP_1',
      nameAr: 'x',
      nameEn: 'x',
      color: '#000000',
      priceCoins: 1,
      durationDays: 1,
      reason: 'dup',
    });
    expect(dup.status).toBe(409);
    expect(dup.body.error.code).toBe('ADMIN_ACTION_REFUSED');
    const badColor = await p.send(owner, 'post', '/admin/vip/tiers', {
      code: 'VIP_9',
      nameAr: 'x',
      nameEn: 'x',
      color: 'gold',
      priceCoins: 1,
      durationDays: 1,
      reason: 'bad',
    });
    expect(badColor.status).toBe(400);
    expectContract(badColor, 'createAdminVipTier');

    // The app: only the tiers switched on, in order, perks switched on, in the reader's language.
    const user = await p.signup();
    const before = await listed(user, 'ar');
    expect(before.data.map((t) => [t.code, t.level])).toEqual([
      ['VIP_2', 1],
      ['VIP_3', 2],
    ]);
    expect(before.data[0]!.name).toBe('في آي بي 2');
    expect(before.data[0]!.perks.map((x) => [x.code, x.title, x.available])).toEqual([
      // D258: the badge and (phase 2) the entry banner are built.
      ['BADGE', 'ميزة BADGE', true],
      ['ENTRY_BANNER', 'ميزة ENTRY_BANNER', true],
    ]);
    expect(before.maxAheadDays).toBe(400);

    const on = await p.send(owner, 'post', `/admin/vip/tiers/${tiers.VIP_1}/enable`, { reason: 'launch' });
    expect(on.status).toBe(200);
    expectContract(on, 'enableAdminVipTier');
    expect(on.body.enabled).toBe(true);
    expect((await listed(user)).data.map((t) => t.code)).toEqual(['VIP_1', 'VIP_2', 'VIP_3']);

    // Order: every tier exactly once.
    const order = await p.send(owner, 'put', '/admin/vip/tier-order', {
      tierIds: [tiers.VIP_3, tiers.VIP_1, tiers.VIP_2],
      reason: 'try',
    });
    expect(order.status).toBe(200);
    expectContract(order, 'reorderAdminVipTiers');
    expect((await listed(user)).data.map((t) => [t.code, t.level])).toEqual([
      ['VIP_3', 1],
      ['VIP_1', 2],
      ['VIP_2', 3],
    ]);
    const partial = await p.send(owner, 'put', '/admin/vip/tier-order', {
      tierIds: [tiers.VIP_1, tiers.VIP_2],
      reason: 'missing one',
    });
    expect(partial.status).toBe(400);
    expect(partial.body.error.details).toEqual([{ field: 'tierIds', issue: 'invalid_value' }]);
    const back = await p.send(owner, 'put', '/admin/vip/tier-order', {
      tierIds: [tiers.VIP_1, tiers.VIP_2, tiers.VIP_3],
      reason: 'back',
    });
    expect(back.body.data.map((t: { code: string; sortOrder: number }) => [t.code, t.sortOrder])).toEqual([
      ['VIP_1', 1],
      ['VIP_2', 2],
      ['VIP_3', 3],
    ]);

    // An edit: name, price and the perks list (replaced, in order).
    const edit = await p.send(owner, 'patch', `/admin/vip/tiers/${tiers.VIP_3}`, {
      nameEn: 'VIP Royal',
      priceCoins: 10_000,
      perks: [perk('ENTRY_EFFECT'), perk('DAILY_BULLET')],
      reason: 'owner prices',
    });
    expect(edit.status, JSON.stringify(edit.body)).toBe(200);
    expectContract(edit, 'updateAdminVipTier');
    expect(edit.body).toMatchObject({ nameEn: 'VIP Royal', priceCoins: 10_000 });
    expect(edit.body.perks.map((x: { code: string }) => x.code)).toEqual(['ENTRY_EFFECT', 'DAILY_BULLET']);
    expect(
      (await p.send(owner, 'patch', `/admin/vip/tiers/${randomUUID()}`, { priceCoins: 2, reason: 'x' }))
        .status,
    ).toBe(404);

    const audit = await ctx.prisma.auditLog.findMany({
      where: { action: { startsWith: 'vip.tier.' } },
      orderBy: { createdAt: 'asc' },
    });
    expect(audit.map((a) => a.action)).toEqual([
      'vip.tier.add',
      'vip.tier.add',
      'vip.tier.add',
      'vip.tier.enable',
      'vip.tier.reorder',
      'vip.tier.reorder',
      'vip.tier.update',
    ]);
    expect(audit.every((a) => a.actorUserId === owner.id)).toBe(true);
    expect(audit[6]!.metadata).toMatchObject({
      reason: 'owner prices',
      via: 'panel',
      before: { priceCoins: 9_000 },
      after: { priceCoins: 10_000, nameEn: 'VIP Royal' },
    });
  });

  it('buying: new, a replay, renew, upgrade; a downgrade, a changed price and too few coins are refused', async () => {
    const u = await p.signup();
    await coins(u, 20_000);
    expect(await mine(u)).toBeNull();

    const key = randomUUID();
    const first = await buy(u, 'VIP_1', 1_000, key);
    expect(first.status, JSON.stringify(first.body)).toBe(201);
    expectContract(first, 'buyVip');
    expect(first.body).toMatchObject({
      kind: 'NEW',
      priceCoins: 1_000,
      durationDays: 30,
      coins: 19_000,
      membership: { tier: { code: 'VIP_1', onSale: true }, daysLeft: 30 },
    });
    const firstEnd = Date.parse(first.body.membership.expiresAt as string);
    expect(firstEnd - Date.now()).toBe(30 * DAY);

    // The same key and body: the first answer, nothing charged again; another body: refused.
    const again = await buy(u, 'VIP_1', 1_000, key);
    expect(again.status).toBe(200);
    expectContract(again, 'buyVip');
    expect(again.body).toMatchObject({ kind: 'NEW', coins: 19_000 });
    expect(await wallet(u)).toBe(19_000);
    const conflict = await buy(u, 'VIP_2', 3_000, key);
    expect(conflict.status).toBe(409);
    expect(conflict.body.error.code).toBe('IDEMPOTENCY_CONFLICT');

    p.advance(60_000);
    const renew = await buy(u, 'VIP_1', 1_000);
    expect(renew.status).toBe(201);
    expect(renew.body.kind).toBe('RENEW');
    expect(Date.parse(renew.body.membership.expiresAt as string)).toBe(firstEnd + 30 * DAY);
    expect(renew.body.membership.startedAt).toBe(first.body.membership.startedAt);

    // Advance so the upgrade's createdAt is strictly after the renew's (the
    // purchases are ordered by createdAt below; frozen fake time would tie).
    p.advance(60_000);
    const up = await buy(u, 'VIP_2', 3_000);
    expect(up.status).toBe(201);
    expect(up.body).toMatchObject({
      kind: 'UPGRADE',
      coins: 15_000,
      membership: { tier: { code: 'VIP_2' } },
    });
    expect(Date.parse(up.body.membership.expiresAt as string) - Date.now()).toBe(30 * DAY);

    const down = await buy(u, 'VIP_1', 1_000);
    expect(down.status).toBe(409);
    expectContract(down, 'buyVip');
    expect(down.body.error).toMatchObject({
      code: 'VIP_UNAVAILABLE',
      details: [{ field: 'tier', issue: 'downgrade' }],
    });

    const stale = await buy(u, 'VIP_3', 9_000);
    expect(stale.status).toBe(409);
    expect(stale.body.error.code).toBe('VIP_PRICE_CHANGED');

    const poor = await p.signup();
    const short = await buy(poor, 'VIP_1', 1_000);
    expect(short.status).toBe(409);
    expect(short.body.error.code).toBe('INSUFFICIENT_COINS');
    expect(await mine(poor)).toBeNull();
    expect(await ctx.prisma.vipPurchase.count({ where: { userId: poor.id } })).toBe(0);

    expect(await wallet(u)).toBe(15_000);
    const now = await mine(u);
    expect(now).toMatchObject({ tier: { code: 'VIP_2', name: 'VIP 2' }, daysLeft: 30 });

    // One ledger row per purchase, referencing it; the history shows the reason.
    const purchases = await ctx.prisma.vipPurchase.findMany({
      where: { userId: u.id },
      orderBy: { createdAt: 'asc' },
    });
    expect(purchases.map((x) => x.kind)).toEqual(['NEW', 'RENEW', 'UPGRADE']);
    const ledger = await ctx.prisma.walletLedgerEntry.findMany({
      where: { userId: u.id, reason: 'VIP_PURCHASE' },
      orderBy: { createdAt: 'asc' },
    });
    expect(ledger.map((l) => [Number(l.delta), l.referenceId])).toEqual(
      purchases.map((x) => [-Number(x.priceCoins), x.id]),
    );
    const history = await ctx.http.get('/api/v1/wallet/me/ledger').set(auth(u));
    expect(history.status).toBe(200);
    expectContract(history, 'listMyWalletLedger');
    expect(history.body.data[0].reason).toBe('VIP_PURCHASE');
    const audits = await ctx.prisma.auditLog.count({ where: { action: 'vip.purchase', actorUserId: u.id } });
    expect(audits).toBe(3);
  });

  it('two purchases at once with coins for one: exactly one is charged', async () => {
    const u = await p.signup();
    await coins(u, 1_000);
    const results = await Promise.all([buy(u, 'VIP_1', 1_000), buy(u, 'VIP_1', 1_000)]);
    expect(results.map((r) => r.status).sort()).toEqual([201, 409]);
    expect(results.find((r) => r.status === 409)!.body.error.code).toBe('INSUFFICIENT_COINS');
    expect(await wallet(u)).toBe(0);
    expect(await ctx.prisma.vipPurchase.count({ where: { userId: u.id } })).toBe(1);
  });

  it('a tier switched off: no longer sold or renewed, its holders keep it to the end; then it ends', async () => {
    const u = await p.signup();
    await coins(u, 10_000);
    expect((await buy(u, 'VIP_2', 3_000)).status).toBe(201);
    const off = await p.send(owner, 'post', `/admin/vip/tiers/${tiers.VIP_2}/disable`, { reason: 'pause' });
    expect(off.status).toBe(200);
    expectContract(off, 'disableAdminVipTier');
    expect(off.body).toMatchObject({ enabled: false, activeMembers: 2 });
    expect((await listed(u)).data.map((t) => t.code)).toEqual(['VIP_1', 'VIP_3']);
    expect(await mine(u)).toMatchObject({ tier: { code: 'VIP_2', onSale: false } });
    const renew = await buy(u, 'VIP_2', 3_000);
    expect(renew.status).toBe(409);
    expect(renew.body.error.details).toEqual([{ field: 'tier', issue: 'tier_off' }]);

    // Ended: none, and any tier can be bought again (a lower one too).
    await endMembershipOf(u);
    expect(await mine(u)).toBeNull();
    const fresh = await buy(u, 'VIP_1', 1_000);
    expect(fresh.status).toBe(201);
    expect(fresh.body.kind).toBe('NEW');
    await p.send(owner, 'post', `/admin/vip/tiers/${tiers.VIP_2}/enable`, { reason: 'back' });
  });

  it('checks: the Idempotency-Key, an unknown tier, a renewal past the prepaid limit', async () => {
    const u = await p.signup();
    await coins(u, 100_000);
    const noKey = await ctx.http
      .post('/api/v1/me/vip/purchases')
      .set(auth(u))
      .send({ tierId: tiers.VIP_1, priceCoins: 1_000 });
    expect(noKey.status).toBe(400);
    expect(noKey.body.error.details).toEqual([{ field: 'Idempotency-Key', issue: 'required' }]);
    const unknown = await buy(u, randomUUID(), 1_000);
    expect(unknown.status).toBe(404);
    // 30 days each: 13 purchases reach 390 days; the 14th would pass 400.
    for (let i = 0; i < 13; i++) expect((await buy(u, 'VIP_1', 1_000)).status).toBe(201);
    const over = await buy(u, 'VIP_1', 1_000);
    expect(over.status).toBe(409);
    expect(over.body.error.details).toEqual([{ field: 'tier', issue: 'renewal_limit' }]);
    expect(await wallet(u)).toBe(87_000);
  });
});
