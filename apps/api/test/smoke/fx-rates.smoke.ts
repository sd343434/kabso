/**
 * D245: serves the API for the «أسعار الصرف» / «مزوّد أسعار الصرف» Playwright run (apps/admin/e2e/fx-rates.spec.ts) —
 * the real app on PostgreSQL + Redis (the *_test database is reset) with the exchange-rate providers replaced by the
 * local stub (test/helpers/fake-fx.ts: no network, a made-up key). The stub's values are illustrative, not market
 * data. Seeds a not-yet-enrolled OWNER, runs one free fetch, sets a manual rate for EG and makes a held JPY value.
 * Writes the credentials and the made-up key to SMOKE_FILE; listens on SMOKE_PORT until SMOKE_STOP_FILE is removed.
 * `SMOKE_FX=1 pnpm smoke:admin-server test/smoke/fx-rates.smoke.ts`.
 */
import { existsSync, writeFileSync } from 'node:fs';
import { randomBytes, randomUUID } from 'node:crypto';
import { expect, it } from 'vitest';
import { grantRoleIn } from '../../src/modules/admin-panel/admin-roles.js';
import { FxRatesService } from '../../src/modules/fx/fx-rates.service.js';
import { setExchangeRateIn } from '../../src/modules/recharge/recharge-order-core.js';
import { FakeFx } from '../helpers/fake-fx.js';
import { createTestApp, registerVerified, withMigrationClient } from '../helpers/test-app.js';

/** Illustrative stub values (units per 1 USD), not market data. */
const STUB_RATES: Record<string, number> = {
  USD: 1,
  AED: 3.6725,
  SAR: 3.75,
  QAR: 3.64,
  KWD: 0.3071,
  BHD: 0.376,
  OMR: 0.3845,
  JOD: 0.709,
  EGP: 48.6,
  IQD: 1310,
  LBP: 89500,
  SYP: 13000,
  YER: 250,
  MAD: 9.9,
  DZD: 133,
  TND: 3.1,
  LYD: 5.45,
  SDG: 600,
  MRU: 39.8,
  SOS: 571,
  DJF: 177.7,
  KMF: 455,
  ILS: 3.7,
  TRY: 34.2,
  EUR: 0.92,
  GBP: 0.78,
  JPY: 152.3,
  INR: 84.1,
  PKR: 278,
  IDR: 15700,
  MYR: 4.4,
  CNY: 7.12,
  RUB: 97,
  BRL: 5.6,
  MXN: 19.9,
  CAD: 1.38,
  AUD: 1.52,
  NGN: 1650,
  ZAR: 17.8,
  KES: 129,
};

it.skipIf(process.env.SMOKE_FX !== '1')('serves the exchange-rates smoke API', async () => {
  const port = Number(process.env.SMOKE_PORT ?? 3000);
  const file = process.env.SMOKE_FILE ?? 'admin-smoke.json';
  const stop = process.env.SMOKE_STOP_FILE;
  const apiKey = `fxsmoke${randomBytes(8).toString('hex')}Ky42`;
  const fx = new FakeFx(apiKey);
  fx.rates = { ...STUB_RATES };
  fx.updatedUnix = Math.floor(Date.now() / 1000) - 3 * 3600;
  await fx.start();
  const ctx = await createTestApp({
    ADMIN_TOTP_KEY: `smoke-${randomUUID()}-${randomUUID()}`,
    RATE_LIMIT_ADMIN_LOGIN_IP: '1000/900',
    RATE_LIMIT_ADMIN_IP: '100000/900',
    FX_FREE_URL: `${fx.base}/v6/latest/USD`,
    FX_CURRENCYAPI_BASE_URL: fx.base,
    FX_EXCHANGERATE_API_BASE_URL: fx.base,
    // The poller runs as in production (it checks every 5 s here), so «التحديث القادم» and a switch to the paid
    // provider show for real.
    FX_POLL_TICK_SECONDS: '5',
  });
  const { res, payload } = await registerVerified(ctx);
  expect(res.status).toBe(201);
  await ctx.prisma.userProfile.update({
    where: { userId: res.body.user.id as string },
    data: { displayName: 'المالك' },
  });
  await withMigrationClient((db) => db.$transaction((tx) => grantRoleIn(tx, payload.email, 'OWNER')));
  const svc = ctx.app.get(FxRatesService);
  /** One fetch now (waits while the poller holds the lease). */
  const fetchNow = async () => {
    for (;;) {
      const r = await svc.runIfDue(new Date(), true);
      if (r.status !== 'locked') return r;
      await new Promise((ok) => setTimeout(ok, 500));
    }
  };
  expect((await fetchNow()).status).toBe('ok');
  await ctx.prisma.$transaction((tx) =>
    setExchangeRateIn(
      tx,
      'EG',
      { currency: 'EGP', rateMicro: 50_500_000n, digits: 2 },
      'سعر البنك اليوم',
      new Date(),
    ),
  );
  fx.rates = { ...STUB_RATES, JPY: 460 };
  expect((await fetchNow()).status).toBe('ok');
  fx.rates = { ...STUB_RATES };
  writeFileSync(
    file,
    JSON.stringify({ fxOwner: { email: payload.email, password: payload.password }, fx: { apiKey } }),
    { mode: 0o600 },
  );
  await ctx.app.listen(port, '127.0.0.1');
  const until = Date.now() + 3_600_000;
  while (Date.now() < until && (stop === undefined || existsSync(stop))) {
    await new Promise((r) => setTimeout(r, 500));
  }
  await ctx.close();
  await fx.stop();
});
