/**
 * D245 (owner 2026-11-02; contract v1.81-social, CONVENTIONS §10.87): automatic exchange rates for every country —
 * the free no-key feed (hourly), the OWNER's paid provider in the panel «مزوّد أسعار الصرف» (every minute; the key
 * write-only, sealed, last 4, the code again + a reason, audited, «اختبار الاتصال»), the manual rate «يدوي» that wins
 * and «إعادة إلى التلقائي», failures that keep the last good rates with a back-off, absurd values rejected, jumps held
 * for review, stale data → USD only, the lease that stops a double run, and the recharge-order price through the one
 * resolver. The providers are a local stub (test/helpers/fake-fx.ts): no real network, no real key.
 */
import { randomBytes, randomUUID } from 'node:crypto';
import { afterAll, beforeAll, describe, expect, it, vi } from 'vitest';
import { FxRatesService } from '../src/modules/fx/fx-rates.service.js';
import { topUpIn } from '../src/modules/recharge/recharge-core.js';
import { panel, type Admin, type Person } from './helpers/admin-panel.js';
import { FakeFx } from './helpers/fake-fx.js';
import { expectContract, operations } from './helpers/openapi.js';
import { createTestApp, type TestContext } from './helpers/test-app.js';

const ADMIN_KEY = 'admin-totp-test-key-0123456789-abcdefghijklmnop';
/** A made-up key built at run time (never real; nothing for a secret scanner to match). */
const KEY = `fxt${randomBytes(10).toString('hex')}K3y9`;
const WRONG = `wrong${randomBytes(4).toString('hex')}1234`;
const RULES = {
  activationMinCoins: 30_000_000,
  priceTiers: [{ minCoins: 0, minorPerMillion: 1200 }],
  currency: 'USD',
};
const HOUR = 3_600_000;

describe('D245 contract coverage', () => {
  it('openapi v1.81-social declares the exchange-rate operations', () => {
    const ids = operations().map((o) => `${o.operationId} ${o.method.toUpperCase()} ${o.path}`);
    for (const op of [
      'listAdminRechargeExchangeRates GET /api/v1/admin/recharge/exchange-rates',
      'setAdminRechargeExchangeRate POST /api/v1/admin/recharge/exchange-rates/{country}',
      'clearAdminRechargeExchangeRate POST /api/v1/admin/recharge/exchange-rates/{country}/clear',
      'refreshAdminFxRates POST /api/v1/admin/fx/refresh',
      'acceptAdminFxHeldRate POST /api/v1/admin/fx/held/{currency}/accept',
      'getAdminFxSettings GET /api/v1/admin/fx-settings',
      'updateAdminFxSettings PATCH /api/v1/admin/fx-settings',
      'testAdminFxSettings POST /api/v1/admin/fx-settings/test',
      'clearAdminFxSettings POST /api/v1/admin/fx-settings/clear',
    ]) {
      expect(ids).toContain(op);
    }
  });
});

describe('D245 automatic exchange rates', { timeout: 300_000 }, () => {
  const fx = new FakeFx(KEY);
  let ctx: TestContext;
  let svc: FxRatesService;
  const p = panel(() => ctx);
  let owner: Admin;
  let finance: Admin;
  let support: Admin;
  let buyer: Person;
  let agentCode: string;

  const now = () => new Date(p.now());
  const list = (a: Admin) => p.send(a, 'get', '/admin/recharge/exchange-rates');
  const row = async (country: string) =>
    ((await list(finance)).body.data as { country: string }[]).find((r) => r.country === country) as Record<
      string,
      unknown
    >;
  const quote = (country = 'EG', coins = 1_000_000) =>
    ctx.http
      .get(`/api/v1/recharge-orders/quote?agentCode=${agentCode}&country=${country}&coins=${coins}`)
      .set('Authorization', `Bearer ${buyer.token}`);
  const rateOf = async (currency: string) =>
    (await ctx.prisma.fxRate.findUnique({ where: { currency } }))?.rateMicro ?? null;
  const settings = () => ctx.prisma.fxSettings.findUniqueOrThrow({ where: { id: 1 } });
  /** Lets the next run be due (the tests move the clock instead of waiting). */
  const due = () => ctx.prisma.fxSettings.update({ where: { id: 1 }, data: { nextFetchAt: now() } });

  beforeAll(async () => {
    await fx.start();
    vi.useFakeTimers({ toFake: ['Date'], now: p.start() });
    fx.updatedUnix = Math.floor(p.now() / 1000) - 3600;
    ctx = await createTestApp({
      ADMIN_TOTP_KEY: ADMIN_KEY,
      ADMIN_SESSION_IDLE_SECONDS: '7200',
      ADMIN_SESSION_MAX_SECONDS: '28800',
      RATE_LIMIT_ADMIN_LOGIN_IP: '10000/900',
      RATE_LIMIT_ADMIN_IP: '10000/900',
      FX_FREE_URL: `${fx.base}/v6/latest/USD`,
      FX_CURRENCYAPI_BASE_URL: fx.base,
      FX_EXCHANGERATE_API_BASE_URL: fx.base,
      FX_FETCH_TIMEOUT_MS: '5000',
    });
    svc = ctx.app.get(FxRatesService);
    owner = await p.makeAdmin(['OWNER']);
    finance = await p.makeAdmin(['FINANCE']);
    support = await p.makeAdmin(['SUPPORT']);
    buyer = await p.signup();
    // An ACTIVE recharge agent serving EG, SA and EC (a USD country), as in D204.
    const agent = await p.signup();
    const appId = randomUUID();
    await ctx.prisma.rechargeAgentApplication.create({
      data: {
        id: appId,
        userId: agent.id,
        status: 'APPROVED',
        fullName: 'محمد أحمد علي حسن',
        phone: '+201001234567',
        photoKey: `private/recharge-agents/${appId}/photo.webp`,
        selfieKey: `private/recharge-agents/${appId}/selfie.webp`,
        locations: [{ country: 'EG', cities: ['Cairo'] }],
        paymentMethods: [{ country: 'EG', type: 'MOBILE_WALLET', details: 'x' }],
        decidedAt: now(),
      },
    });
    await ctx.prisma.rechargeAgent.create({
      data: {
        userId: agent.id,
        applicationId: appId,
        countries: ['EG', 'SA', 'EC', 'JP'],
        locations: [{ country: 'EG', cities: ['Cairo'] }],
        paymentTypes: {
          EG: ['MOBILE_WALLET'],
          SA: ['BANK_TRANSFER'],
          EC: ['BANK_TRANSFER'],
          JP: ['BANK_TRANSFER'],
        },
      },
    });
    const r = await ctx.prisma.$transaction((tx) =>
      topUpIn(tx, agent.id, 30_000_000n, 36_000n, null, RULES, now()),
    );
    agentCode = r.code!;
  });

  afterAll(async () => {
    await ctx?.close();
    await fx.stop();
    vi.useRealTimers();
  });

  it('before any fetch: every country is listed, nothing automatic yet, USD only (D204 unchanged)', async () => {
    const res = await list(support);
    expectContract(res, 'listAdminRechargeExchangeRates');
    expect(res.status).toBe(200);
    const data = res.body.data as { country: string; source: string; unitsPerUsd: string | null }[];
    expect(data.length).toBeGreaterThanOrEqual(248);
    expect(data.find((r) => r.country === 'EG')).toMatchObject({
      source: 'NONE',
      unitsPerUsd: null,
      currency: 'EGP',
    });
    expect(data.find((r) => r.country === 'EC')).toMatchObject({
      source: 'USD',
      unitsPerUsd: '1',
      currency: 'USD',
    });
    expect(res.body.status).toMatchObject({
      source: 'OPEN_ER_API',
      paidActive: false,
      intervalSeconds: 3600,
      lastSuccessAt: null,
      attribution: { text: 'Rates By Exchange Rate API', url: 'https://www.exchangerate-api.com' },
    });
    expect((await quote()).body.price.local).toBeNull();
  });

  it('a free fetch stores every rate with its source and times; the next one waits an hour', async () => {
    const r = await svc.runIfDue(now());
    expect(r).toMatchObject({ status: 'ok', source: 'OPEN_ER_API', accepted: 5, held: 0, rejected: 0 });
    const egp = await ctx.prisma.fxRate.findUniqueOrThrow({ where: { currency: 'EGP' } });
    expect(egp).toMatchObject({ rateMicro: 48_600_000n, source: 'OPEN_ER_API', heldRateMicro: null });
    expect(egp.providerUpdatedAt?.getTime()).toBe(fx.updatedUnix * 1000);
    expect(egp.fetchedAt.getTime()).toBe(p.now());
    expect(await rateOf('USD')).toBeNull(); // USD is 1 by rule, never stored
    const s = await settings();
    expect(s.nextFetchAt?.getTime()).toBe(p.now() + HOUR);
    expect(s.lastSource).toBe('OPEN_ER_API');
    expect(fx.hits.at(-1)).toMatchObject({ kind: 'free', apikeyHeader: null });
    expect(await svc.runIfDue(now())).toEqual({ status: 'not_due' });
    expect(fx.count('free')).toBe(1);
    expect(await row('EG')).toMatchObject({ source: 'AUTO', unitsPerUsd: '48.6', stale: false });
    expect((await list(finance)).body.status).toMatchObject({ currencies: 5, lastError: null, failures: 0 });
  });

  it('the order price uses the effective rate: automatic, then manual «يدوي» wins, then «إعادة إلى التلقائي»', async () => {
    let q = await quote();
    expectContract(q, 'quoteRechargeOrder');
    expect(q.body.price).toEqual({
      usdMinor: 1250,
      usd: '12.50',
      local: { currency: 'EGP', minor: 60_750, digits: 2, amount: '607.50', rate: '48.6' },
    });
    // A USD country: the USD line only (no second identical line).
    expect((await quote('EC')).body.price.local).toBeNull();
    expect((await quote('SA')).body.price.local).toMatchObject({ currency: 'SAR', rate: '3.75' });
    expect((await quote('JP')).body.price.local).toMatchObject({
      currency: 'JPY',
      digits: 0,
      amount: '1904',
    });
    // Manual wins.
    const set = await p.send(finance, 'post', '/admin/recharge/exchange-rates/EG', {
      currency: 'EGP',
      unitsPerUsd: '50.5',
      digits: 2,
      reason: 'bank rate today',
    });
    expectContract(set, 'setAdminRechargeExchangeRate');
    expect(await row('EG')).toMatchObject({
      source: 'MANUAL',
      unitsPerUsd: '50.5',
      manual: { unitsPerUsd: '50.5' },
      auto: { unitsPerUsd: '48.6', source: 'OPEN_ER_API' },
    });
    q = await quote();
    expect(q.body.price.local).toMatchObject({ amount: '631.25', rate: '50.5' });
    // A new automatic value does not move a manual country.
    fx.rates = { ...fx.rates, EGP: 49 };
    await due();
    expect((await svc.runIfDue(now())).status).toBe('ok');
    expect((await quote()).body.price.local).toMatchObject({ rate: '50.5' });
    // An order made now keeps the manual rate.
    const order = await ctx.http
      .post('/api/v1/recharge-orders')
      .set('Authorization', `Bearer ${buyer.token}`)
      .set('Idempotency-Key', randomUUID())
      .send({ agentCode, country: 'EG', coins: 1_000_000, paymentType: 'MOBILE_WALLET' });
    expect(order.status, JSON.stringify(order.body)).toBe(201);
    expect(order.body.price.local).toMatchObject({ rate: '50.5', amount: '631.25' });
    // «إعادة إلى التلقائي» (the D204 clear: reason, audited).
    const reset = await p.send(finance, 'post', '/admin/recharge/exchange-rates/EG/clear', {
      reason: 'automatic again',
    });
    expectContract(reset, 'clearAdminRechargeExchangeRate');
    expect(reset.status).toBe(200);
    expect(await row('EG')).toMatchObject({ source: 'AUTO', unitsPerUsd: '49', manual: null });
    expect((await quote()).body.price.local).toMatchObject({ rate: '49', amount: '612.50' });
    const audits = await ctx.prisma.auditLog.findMany({
      where: { targetId: 'EG', action: { in: ['recharge.rate.set', 'recharge.rate.clear'] } },
      orderBy: { createdAt: 'asc' },
    });
    // Same fake instant for both rows: compare as a set, then read the reset row by its action.
    expect(audits.map((a) => a.action).sort()).toEqual(['recharge.rate.clear', 'recharge.rate.set']);
    expect(audits.find((a) => a.action === 'recharge.rate.clear')!.metadata).toMatchObject({
      reason: 'automatic again',
      via: 'panel',
    });
    // SUPPORT reads but cannot edit (D204 roles).
    expect(
      (await p.send(support, 'post', '/admin/recharge/exchange-rates/EG/clear', { reason: 'x' })).status,
    ).toBe(403);
  });

  it('a failed fetch keeps the last good rates, shows the error and backs off', async () => {
    fx.free = { status: 500, body: { oops: true } };
    await due();
    const r = await svc.runIfDue(now());
    expect(r).toMatchObject({ status: 'failed', source: 'OPEN_ER_API', issue: 'http_error' });
    expect(await rateOf('EGP')).toBe(49_000_000n);
    let s = await settings();
    expect(s.failures).toBe(1);
    expect(s.nextFetchAt?.getTime()).toBe(p.now() + HOUR);
    // A second failure in a row: twice the wait.
    fx.free = { status: 200, body: { result: 'error', 'error-type': 'unsupported-code' } };
    await due();
    expect(await svc.runIfDue(now())).toMatchObject({ status: 'failed', issue: 'bad_response' });
    s = await settings();
    expect(s.failures).toBe(2);
    expect(s.nextFetchAt?.getTime()).toBe(p.now() + 2 * HOUR);
    const status = (await list(finance)).body.status as Record<string, unknown>;
    expect(status).toMatchObject({ failures: 2, lastError: { issue: 'bad_response' } });
    expect((await quote()).body.price.local).toMatchObject({ rate: '49' });
    // Back to normal: the failures reset.
    fx.free = {};
    await due();
    expect((await svc.runIfDue(now())).status).toBe('ok');
    expect((await settings()).failures).toBe(0);
  });

  it('absurd values are rejected; a jump over 50 % is held for review, then accepted by the team (audited)', async () => {
    fx.rates = { USD: 1, EGP: 49.2, EUR: 0, SAR: -3, KWD: 'NaN', JPY: 460, XYZ1: 3 };
    await due();
    const r = await svc.runIfDue(now());
    expect(r).toMatchObject({ status: 'ok', accepted: 1, held: 1, rejected: 3 });
    expect(await rateOf('EUR')).toBe(920_000n);
    expect(await rateOf('SAR')).toBe(3_750_000n);
    expect(await rateOf('KWD')).toBe(307_100n);
    expect(await rateOf('JPY')).toBe(152_300_000n); // still in force
    const jp = await row('JP');
    expect(jp).toMatchObject({
      source: 'AUTO',
      unitsPerUsd: '152.3',
      auto: { held: { unitsPerUsd: '460', source: 'OPEN_ER_API' } },
    });
    expect((await quote('JP')).body.price.local).toMatchObject({ rate: '152.3' });
    expect((await settings()).lastReport).toMatchObject({
      heldCurrencies: ['JPY'],
      rejectedCurrencies: ['EUR', 'KWD', 'SAR'],
    });
    // Accepting: recharge.rates with a reason; SUPPORT cannot.
    expect((await p.send(support, 'post', '/admin/fx/held/JPY/accept', { reason: 'x' })).status).toBe(403);
    expect((await p.send(finance, 'post', '/admin/fx/held/EGP/accept', { reason: 'x' })).status).toBe(409);
    const ok = await p.send(finance, 'post', '/admin/fx/held/jpy/accept', {
      reason: 'checked with the bank',
    });
    expectContract(ok, 'acceptAdminFxHeldRate');
    expect(ok.body).toEqual({ currency: 'JPY', unitsPerUsd: '460', source: 'OPEN_ER_API' });
    expect((await quote('JP')).body.price.local).toMatchObject({ rate: '460' });
    const audit = await ctx.prisma.auditLog.findFirstOrThrow({ where: { action: 'fx.rate.accept_held' } });
    expect(audit.metadata).toMatchObject({ before: '152.3', after: '460', reason: 'checked with the bank' });
    fx.rates = { USD: 1, EGP: 49.2, EUR: 0.92, SAR: 3.75, JPY: 460, KWD: 0.3071 };
  });

  it('automatic rates older than 48 hours are not used: USD only (manual rates are never stale)', async () => {
    fx.updatedUnix = Math.floor((p.now() - 49 * HOUR) / 1000);
    await due();
    expect((await svc.runIfDue(now())).status).toBe('ok');
    expect(await row('EG')).toMatchObject({
      source: 'NONE',
      stale: true,
      unitsPerUsd: null,
      auto: { stale: true },
    });
    expect((await quote()).body.price.local).toBeNull();
    expect((await quote()).body.price.usd).toBe('12.50');
    fx.updatedUnix = Math.floor(p.now() / 1000);
    await due();
    await svc.runIfDue(now());
    expect((await quote()).body.price.local).toMatchObject({ rate: '49.2' });
  });

  it('the lease stops a double run: two instances at once → one fetch', async () => {
    fx.free = { delayMs: 400 };
    await due();
    const before = fx.count('free');
    const [a, b] = await Promise.all([svc.runIfDue(now()), svc.runIfDue(now())]);
    expect([a.status, b.status].sort()).toEqual(['locked', 'ok']);
    expect(fx.count('free')).toBe(before + 1);
    fx.free = {};
  });

  it('«تحديث الآن»: recharge.rates, at most once a minute, audited', async () => {
    expect((await p.send(support, 'post', '/admin/fx/refresh')).status).toBe(403);
    p.advance(61_000);
    const r = await p.send(finance, 'post', '/admin/fx/refresh');
    expectContract(r, 'refreshAdminFxRates');
    expect(r.body.result).toMatchObject({ status: 'ok' });
    const again = await p.send(finance, 'post', '/admin/fx/refresh');
    expect(again.status).toBe(409);
    expect(again.body.error.details).toEqual([{ field: 'refresh', issue: 'fx_refresh_too_soon' }]);
    expect(await ctx.prisma.auditLog.count({ where: { action: 'fx.rates.refresh' } })).toBe(1);
  });

  it('«مزوّد أسعار الصرف»: OWNER only, the code again + a reason, key write-only (last 4), tested, every minute', async () => {
    const get = (a: Admin) => p.send(a, 'get', '/admin/fx-settings');
    expect((await get(finance)).status).toBe(403);
    expect((await get(support)).status).toBe(403);
    let view = await get(owner);
    expectContract(view, 'getAdminFxSettings');
    expect(view.body).toMatchObject({
      status: 'not_configured',
      enabled: false,
      apiKey: null,
      paidIntervalSeconds: 60,
    });
    expect(view.headers['cache-control']).toBe('no-store');
    // FINANCE cannot change it; no code / a wrong code / no reason are refused.
    const body = { provider: 'CURRENCYAPI', apiKey: KEY, enabled: true, reason: 'paid rates every minute' };
    expect(
      (await p.send(finance, 'patch', '/admin/fx-settings', { ...body, totpCode: '000000' })).status,
    ).toBe(403);
    expect((await p.send(owner, 'patch', '/admin/fx-settings', body)).status).toBe(400);
    expect((await p.send(owner, 'patch', '/admin/fx-settings', { ...body, totpCode: '000000' })).status).toBe(
      403,
    );
    expect(
      (
        await p.send(owner, 'patch', '/admin/fx-settings', {
          ...body,
          reason: '',
          totpCode: p.nextCode(owner.secret),
        })
      ).status,
    ).toBe(400);
    // «اختبار الاتصال»: a wrong key fails, the right one passes (nothing saved but the result).
    const bad = await p.send(owner, 'post', '/admin/fx-settings/test', {
      provider: 'CURRENCYAPI',
      apiKey: WRONG,
    });
    expectContract(bad, 'testAdminFxSettings');
    expect(bad.body).toMatchObject({ ok: false, issue: 'bad_api_key', apiKeyLast4: '1234' });
    const good = await p.send(owner, 'post', '/admin/fx-settings/test', {
      provider: 'CURRENCYAPI',
      apiKey: KEY,
    });
    expect(good.body).toMatchObject({ ok: true, issue: null, currencies: 6, apiKeyLast4: KEY.slice(-4) });
    // Turning on with a wrong key: tested first, refused, nothing saved.
    const refused = await p.send(owner, 'patch', '/admin/fx-settings', {
      ...body,
      apiKey: WRONG,
      totpCode: p.nextCode(owner.secret),
    });
    expect(refused.status).toBe(409);
    expect(refused.body.error.details).toEqual([{ field: 'enabled', issue: 'fx_test_failed' }]);
    expect((await ctx.prisma.fxSettings.findUniqueOrThrow({ where: { id: 1 } })).apiKeyEnc).toBeNull();
    // On.
    const on = await p.send(owner, 'patch', '/admin/fx-settings', {
      ...body,
      totpCode: p.nextCode(owner.secret),
    });
    expectContract(on, 'updateAdminFxSettings');
    expect(on.status, JSON.stringify(on.body)).toBe(200);
    expect(on.body).toMatchObject({
      status: 'active',
      enabled: true,
      provider: 'CURRENCYAPI',
      apiKey: { last4: KEY.slice(-4) },
    });
    // Write-only: never in a response, an audit row or the database in the clear.
    view = await get(owner);
    expect(JSON.stringify(view.body)).not.toContain(KEY);
    expect(JSON.stringify(on.body)).not.toContain(KEY);
    const audits = await ctx.prisma.auditLog.findMany({ where: { action: { startsWith: 'fx.settings' } } });
    expect(audits.map((a) => a.action).sort()).toEqual([
      'fx.settings.test',
      'fx.settings.test',
      'fx.settings.test',
      'fx.settings.test',
      'fx.settings.update',
    ]);
    for (const a of audits) expect(JSON.stringify(a.metadata)).not.toContain(KEY);
    const update = audits.find((a) => a.action === 'fx.settings.update')!;
    expect(update.metadata).toMatchObject({
      before: { enabled: false, apiKey: null },
      after: { enabled: true, provider: 'CURRENCYAPI', apiKey: `…${KEY.slice(-4)}` },
      connectionTest: 'ok',
      reason: 'paid rates every minute',
    });
    const stored = await ctx.prisma.fxSettings.findUniqueOrThrow({ where: { id: 1 } });
    expect(stored.apiKeyEnc).toMatch(/^v1\./);
    expect(stored.apiKeyEnc).not.toContain(KEY);
    // The poller now reads the paid provider with the key, every minute.
    expect(stored.nextFetchAt?.getTime()).toBeLessThanOrEqual(p.now());
    const r = await svc.runIfDue(now());
    expect(r).toMatchObject({ status: 'ok', source: 'CURRENCYAPI' });
    expect(fx.hits.at(-1)).toMatchObject({ kind: 'currencyapi', apikeyHeader: '[present]' });
    expect((await settings()).nextFetchAt?.getTime()).toBe(p.now() + 60_000);
    expect((await ctx.prisma.fxRate.findUniqueOrThrow({ where: { currency: 'EGP' } })).source).toBe(
      'CURRENCYAPI',
    );
    expect((await list(finance)).body.status).toMatchObject({
      source: 'CURRENCYAPI',
      paidActive: true,
      intervalSeconds: 60,
    });
    // A paid failure backs off from one minute (2 min after two).
    fx.paid = { status: 503, body: {} };
    p.advance(60_000);
    expect(await svc.runIfDue(now())).toMatchObject({ status: 'failed', issue: 'http_error' });
    p.advance(60_000);
    expect(await svc.runIfDue(now())).toMatchObject({ status: 'failed' });
    expect((await settings()).nextFetchAt?.getTime()).toBe(p.now() + 120_000);
    fx.paid = {};
    // The other provider behind the same interface (the key in its URL path, never logged).
    const sw = await p.send(owner, 'patch', '/admin/fx-settings', {
      provider: 'EXCHANGERATE_API',
      reason: 'switch provider',
      totpCode: p.nextCode(owner.secret),
    });
    expect(sw.status, JSON.stringify(sw.body)).toBe(200);
    expect(await svc.runIfDue(now())).toMatchObject({ status: 'ok', source: 'EXCHANGERATE_API' });
    // Removing it: the free feed hourly again.
    expect(
      (await p.send(finance, 'post', '/admin/fx-settings/clear', { totpCode: '000000', reason: 'x' })).status,
    ).toBe(403);
    const cleared = await p.send(owner, 'post', '/admin/fx-settings/clear', {
      totpCode: p.nextCode(owner.secret),
      reason: 'back to the free feed',
    });
    expectContract(cleared, 'clearAdminFxSettings');
    expect(cleared.body).toMatchObject({ status: 'not_configured', enabled: false, apiKey: null });
    expect(await svc.runIfDue(now())).toMatchObject({ status: 'ok', source: 'OPEN_ER_API' });
    expect((await settings()).nextFetchAt?.getTime()).toBe(p.now() + HOUR);
    expect(
      (
        await p.send(owner, 'post', '/admin/fx-settings/clear', {
          totpCode: p.nextCode(owner.secret),
          reason: 'x',
        })
      ).status,
    ).toBe(409);
  });
});
