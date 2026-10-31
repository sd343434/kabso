/**
 * D191: serves the API for the admin panel's Playwright smoke (apps/admin/e2e/smoke.spec.ts) — the real app on
 * PostgreSQL + Redis (the *_test database is reset), with the in-memory object storage. Seeds a not-yet-enrolled
 * OWNER (its email and password go to SMOKE_FILE), a pending recharge-agent application with its two private
 * pictures, a pending cherry withdrawal and two open reports, then listens on SMOKE_PORT (3000) until SMOKE_STOP_FILE
 * is removed (or an hour passes). D196: TOPUP_PUBLIC_BASE_URL is set and Stripe is a fake (no network; a key with
 * `Bad` in it is refused), so the «الدفع (Stripe)» section can test and save keys.
 */
import { existsSync, writeFileSync } from 'node:fs';
import { randomUUID } from 'node:crypto';
import sharp from 'sharp';
import { expect, it } from 'vitest';
import { grantRoleIn } from '../../src/modules/admin-panel/admin-roles.js';
import { OBJECT_STORAGE } from '../../src/modules/media/object-storage.js';
import { STRIPE_API_FACTORY, type StripeApi } from '../../src/modules/topup/stripe-api.js';
import { privateKeyOf } from '../../src/modules/recharge/recharge-core.js';
import { MemoryObjectStorage } from '../helpers/memory-storage.js';
import { createTestApp, registerVerified, withMigrationClient } from '../helpers/test-app.js';

it('serves the admin panel smoke API', async () => {
  const port = Number(process.env.SMOKE_PORT ?? 3000);
  const file = process.env.SMOKE_FILE ?? 'admin-smoke.json';
  const stop = process.env.SMOKE_STOP_FILE;
  const storage = new MemoryObjectStorage();
  const ctx = await createTestApp(
    {
      ADMIN_TOTP_KEY: `smoke-${randomUUID()}-${randomUUID()}`,
      RATE_LIMIT_ADMIN_LOGIN_IP: '1000/900',
      RATE_LIMIT_ADMIN_IP: '100000/900',
      MEDIA_PUBLIC_BASE_URL: 'http://localhost:5180/media-not-served',
      RECHARGE_AGENT_SWEEP_INTERVAL_SECONDS: '0',
      TOPUP_PUBLIC_BASE_URL: 'https://api.kabsolive.com',
    },
    [
      { token: OBJECT_STORAGE, value: storage },
      { token: STRIPE_API_FACTORY, value: fakeStripe },
    ],
  );
  const signup = async (displayName: string) => {
    const { res, payload } = await registerVerified(ctx);
    expect(res.status).toBe(201);
    const id = res.body.user.id as string;
    await ctx.prisma.userProfile.update({ where: { userId: id }, data: { displayName } });
    return {
      id,
      email: payload.email,
      password: payload.password,
      username: res.body.user.username as string,
      token: res.body.tokens.accessToken as string,
    };
  };

  const owner = await signup('مالك كابسو');
  await withMigrationClient((db) => db.$transaction((tx) => grantRoleIn(tx, owner.email, 'OWNER')));

  // A pending application with two private pictures (drawn here: no real person).
  const applicant = await signup('سارة محمد');
  const appId = randomUUID();
  const picture = (bg: string) =>
    sharp({ create: { width: 480, height: 320, channels: 3, background: bg } })
      .composite([
        {
          input: Buffer.from(
            `<svg width="480" height="320"><rect x="40" y="40" width="140" height="180" rx="12" fill="#ffffff" opacity="0.8"/><rect x="210" y="70" width="220" height="22" fill="#ffffff" opacity="0.7"/><rect x="210" y="120" width="180" height="22" fill="#ffffff" opacity="0.7"/><rect x="210" y="170" width="200" height="22" fill="#ffffff" opacity="0.7"/></svg>`,
          ),
        },
      ])
      .webp()
      .toBuffer();
  storage.putRaw(privateKeyOf(appId, 'photo'), await picture('#3b5b8a'), 'image/webp');
  storage.putRaw(privateKeyOf(appId, 'selfie'), await picture('#6a4b8a'), 'image/webp');
  await ctx.prisma.rechargeAgentApplication.create({
    data: {
      id: appId,
      userId: applicant.id,
      fullName: 'سارة محمد علي',
      phone: '+201001112223',
      photoKey: privateKeyOf(appId, 'photo'),
      selfieKey: privateKeyOf(appId, 'selfie'),
      locations: [{ country: 'EG', cities: ['Cairo', 'Giza'] }],
      paymentMethods: [{ country: 'EG', type: 'VODAFONE_CASH' }],
    },
  });

  // A pending withdrawal (gift cherries, then the real request).
  const host = await signup('مضيف تجريبي');
  await ctx.prisma.$transaction(async (tx) => {
    const w = await tx.cherryWallet.upsert({
      where: { userId: host.id },
      create: { userId: host.id, cherries: 25_000_000n },
      update: {},
    });
    await tx.cherryLedgerEntry.create({
      data: {
        userId: host.id,
        delta: 25_000_000n,
        balanceAfter: w.cherries,
        reason: 'GIFT_RECEIVED',
        referenceId: randomUUID(),
      },
    });
  });
  const wd = await ctx.http
    .post('/api/v1/wallet/me/cherries/withdrawals')
    .set('Authorization', `Bearer ${host.token}`)
    .set('Idempotency-Key', randomUUID())
    .send({ amountMinor: 2000, payoutDetails: 'Vodafone Cash 0100 111 2223' });
  expect(wd.status).toBe(201);

  // Two open reports.
  const reporter = await signup('مستخدم مبلّغ');
  const rude = await signup('حساب مخالف');
  await ctx.prisma.userProfile.update({
    where: { userId: rude.id },
    data: { bio: 'رسائل مزعجة متكررة في التعليقات' },
  });
  for (const [target, reason, note] of [
    [rude.username, 'SPAM', 'يرسل روابط مزعجة'],
    [host.username, 'HARASSMENT', 'إساءة في البث'],
  ] as const) {
    const r = await ctx.http
      .post('/api/v1/reports')
      .set('Authorization', `Bearer ${reporter.token}`)
      .send({ targetType: 'USER', targetId: target, reason, note });
    expect(r.status).toBe(201);
  }

  writeFileSync(
    file,
    JSON.stringify({
      email: owner.email,
      password: owner.password,
      applicant: applicant.username,
      applicationId: appId,
    }),
    { mode: 0o600 },
  );
  await ctx.app.listen(port, '127.0.0.1');
  const until = Date.now() + 3_600_000;
  while (Date.now() < until && (stop === undefined || existsSync(stop))) {
    await new Promise((r) => setTimeout(r, 500));
  }
  await ctx.close();
});

/** D196: a Stripe that answers the key check only (the smoke makes no payment). */
function fakeStripe(secretKey: string): StripeApi {
  const none = () => Promise.reject(new Error('the smoke makes no Stripe payment'));
  return {
    createCheckoutSession: none,
    createRefund: none,
    updateDispute: none,
    uploadEvidenceFile: none,
    createCustomer: none,
    checkKey: async () =>
      secretKey.includes('Bad')
        ? { ok: false, reason: 'rejected' }
        : { ok: true, livemode: secretKey.includes('_live_'), restricted: false },
  };
}
