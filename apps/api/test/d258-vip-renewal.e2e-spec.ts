/**
 * D258 (owner: «نعم أضفه وفعّله»; contract v1.83-social, CONVENTIONS §10.94.12): the renewal discount — buying the
 * same tier again while the membership is active, or up to 7 days after it ended, is charged the tier's renewal
 * discount (15 % by default; 0 = none); never a first purchase or an upgrade. End to end against PostgreSQL + Redis.
 */
import { randomUUID } from 'node:crypto';
import { afterAll, beforeAll, describe, expect, it, vi } from 'vitest';
import { creditIn } from '../src/modules/wallet/wallet-ledger.js';
import { panel, type Admin, type Person } from './helpers/admin-panel.js';
import { expectContract } from './helpers/openapi.js';
import { createTestApp, withMigrationClient, type TestContext } from './helpers/test-app.js';

const ADMIN_KEY = 'admin-totp-test-key-0123456789-abcdefghijklmnop';
const DAY = 86_400_000;
const VIP1 = '01a25200-0000-7000-8000-000000000001';
const PRICE = 1_000_000;
const RENEW = 850_000; // 15 % off

describe('D258 VIP renewal discount', { timeout: 180_000 }, () => {
  let ctx: TestContext;
  const p = panel(() => ctx);
  let owner: Admin;

  const auth = (u: Person) => ({ Authorization: `Bearer ${u.token}` });
  const coins = (u: Person, amount: number) =>
    ctx.prisma.$transaction((tx) => creditIn(tx, u.id, BigInt(amount), 'ADMIN_GRANT', randomUUID()));
  const buy = (u: Person, tierId: string, priceCoins: number, key: string = randomUUID()) =>
    ctx.http
      .post('/api/v1/me/vip/purchases')
      .set(auth(u))
      .set('Idempotency-Key', key)
      .send({ tierId, priceCoins });
  const balance = async (u: Person) =>
    Number((await ctx.http.get('/api/v1/wallet/me').set(auth(u))).body.coins);
  const endsIn = (u: Person, ms: number) => {
    const expiresAt = new Date(Date.now() + ms);
    return ctx.prisma.vipMembership.update({
      where: { userId: u.id },
      data: { startedAt: new Date(expiresAt.getTime() - 30 * DAY), expiresAt },
    });
  };

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

  it('the tier quotes its renewal price; a first purchase pays the list price, a renewal 15 % less', async () => {
    const u = await p.signup();
    await coins(u, 5_000_000);
    const tiers = await ctx.http.get('/api/v1/vip/tiers').set(auth(u));
    expectContract(tiers, 'listVipTiers');
    expect(tiers.body.data[0]).toMatchObject({
      code: 'VIP_1',
      renewalDiscountPercent: 15,
      renewPriceCoins: RENEW,
    });

    // First purchase: the discounted price is refused, the list price taken.
    expect((await buy(u, VIP1, RENEW)).body.error?.code).toBe('VIP_PRICE_CHANGED');
    const first = await buy(u, VIP1, PRICE);
    expect(first.status, JSON.stringify(first.body)).toBe(201);
    expectContract(first, 'buyVip');
    expect(first.body).toMatchObject({
      kind: 'NEW',
      priceCoins: PRICE,
      listPriceCoins: PRICE,
      discountPercent: 0,
    });

    const mine = await ctx.http.get('/api/v1/me/vip').set(auth(u));
    expectContract(mine, 'getMyVip');
    expect(mine.body.renewal).toMatchObject({ tierId: VIP1, priceCoins: RENEW, discountPercent: 15 });

    // Renewal while active: the list price is refused (the price shown was the discounted one).
    expect((await buy(u, VIP1, PRICE)).body.error?.code).toBe('VIP_PRICE_CHANGED');
    const before = await balance(u);
    const renew = await buy(u, VIP1, RENEW);
    expect(renew.status, JSON.stringify(renew.body)).toBe(201);
    expectContract(renew, 'buyVip');
    expect(renew.body).toMatchObject({
      kind: 'RENEW',
      priceCoins: RENEW,
      listPriceCoins: PRICE,
      discountPercent: 15,
    });
    expect(await balance(u)).toBe(before - RENEW);
    const row = await ctx.prisma.vipPurchase.findFirstOrThrow({ where: { userId: u.id, kind: 'RENEW' } });
    expect(row).toMatchObject({
      priceCoins: BigInt(RENEW),
      listPriceCoins: BigInt(PRICE),
      discountPercent: 15,
    });
  });

  it('within 7 days after the end: still discounted (a new term); on day 8 the list price', async () => {
    const u = await p.signup();
    await coins(u, 10_000_000);
    expect((await buy(u, VIP1, PRICE)).status).toBe(201);
    // Ended 7 days ago less a minute: discounted.
    await endsIn(u, -(7 * DAY - 60_000));
    const day7 = await buy(u, VIP1, RENEW);
    expect(day7.status, JSON.stringify(day7.body)).toBe(201);
    expect(day7.body).toMatchObject({ kind: 'NEW', priceCoins: RENEW, discountPercent: 15 });
    // Ended 8 days ago: the list price again, no renewal quote.
    await endsIn(u, -8 * DAY);
    expect((await ctx.http.get('/api/v1/me/vip').set(auth(u))).body.renewal).toBeUndefined();
    expect((await buy(u, VIP1, RENEW)).body.error?.code).toBe('VIP_PRICE_CHANGED');
    const day8 = await buy(u, VIP1, PRICE);
    expect(day8.status).toBe(201);
    expect(day8.body).toMatchObject({ kind: 'NEW', priceCoins: PRICE, discountPercent: 0 });
  });

  it('no discount on an upgrade; the panel sets it (audited) and 0 % is the full price', async () => {
    // A second tier above VIP 1.
    const add = await p.send(owner, 'post', '/admin/vip/tiers', {
      code: 'VIP_2',
      nameAr: 'في آي بي 2',
      nameEn: 'VIP 2',
      color: '#2F6FDB',
      priceCoins: 3_000_000,
      durationDays: 30,
      enabled: true,
      reason: 'D258',
    });
    expect(add.status, JSON.stringify(add.body)).toBe(201);
    expect(add.body.renewalDiscountPercent).toBe(15);
    const vip2 = add.body.id as string;
    const u = await p.signup();
    await coins(u, 20_000_000);
    expect((await buy(u, VIP1, PRICE)).status).toBe(201);
    const up = await buy(u, vip2, 3_000_000);
    expect(up.status, JSON.stringify(up.body)).toBe(201);
    expect(up.body).toMatchObject({ kind: 'UPGRADE', priceCoins: 3_000_000, discountPercent: 0 });

    // The panel: out of range refused; 0 saved and audited.
    expect(
      (await p.send(owner, 'patch', `/admin/vip/tiers/${vip2}`, { renewalDiscountPercent: 91, reason: 'x' }))
        .status,
    ).toBe(400);
    const zero = await p.send(owner, 'patch', `/admin/vip/tiers/${vip2}`, {
      renewalDiscountPercent: 0,
      reason: 'no discount',
    });
    expect(zero.status, JSON.stringify(zero.body)).toBe(200);
    expectContract(zero, 'updateAdminVipTier');
    expect(zero.body.renewalDiscountPercent).toBe(0);
    const audit = await withMigrationClient((db) =>
      db.auditLog.findFirst({
        where: { action: 'vip.tier.update', targetId: vip2 },
        orderBy: { createdAt: 'desc' },
      }),
    );
    expect(JSON.stringify(audit?.metadata)).toContain('"renewalDiscountPercent":0');
    const renew = await buy(u, vip2, 3_000_000);
    expect(renew.status, JSON.stringify(renew.body)).toBe(201);
    expect(renew.body).toMatchObject({ kind: 'RENEW', priceCoins: 3_000_000, discountPercent: 0 });
  });

  it('two renewals at once: each charged the discounted price once, the balance exact', async () => {
    const u = await p.signup();
    await coins(u, 5_000_000);
    expect((await buy(u, VIP1, PRICE)).status).toBe(201);
    const before = await balance(u);
    const [a, b] = await Promise.all([buy(u, VIP1, RENEW), buy(u, VIP1, RENEW)]);
    expect([a.status, b.status].sort()).toEqual([201, 201]);
    expect(await balance(u)).toBe(before - 2 * RENEW);
    const rows = await ctx.prisma.vipPurchase.count({
      where: { userId: u.id, kind: 'RENEW', discountPercent: 15 },
    });
    expect(rows).toBe(2);
  });
});
