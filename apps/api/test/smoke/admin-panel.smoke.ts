/**
 * D191: serves the API for the admin panel's Playwright smoke (apps/admin/e2e/smoke.spec.ts) — the real app on
 * PostgreSQL + Redis (the *_test database is reset), with the in-memory object storage. Seeds a not-yet-enrolled
 * OWNER (its email and password go to SMOKE_FILE), a pending recharge-agent application with its two private
 * pictures, a pending cherry withdrawal and two open reports, then listens on SMOKE_PORT (3000) until SMOKE_STOP_FILE
 * is removed (or an hour passes). D196: TOPUP_PUBLIC_BASE_URL is set and Stripe is a fake (no network; a key with
 * `Bad` in it is refused), so the «الدفع (Stripe)» section can test and save keys. D204: a second not-yet-enrolled
 * OWNER (`disputeOwner`) and a recharge order taken through the real API to a dispute (details, notice, «قمت بالإرسال»
 * with a drawn transfer screenshot, «نزاع» by the agent), plus an EGP exchange rate, for «نزاعات الشحن».
 */
import { existsSync, writeFileSync } from 'node:fs';
import { randomUUID } from 'node:crypto';
import sharp from 'sharp';
import { expect, it } from 'vitest';
import { grantRoleIn } from '../../src/modules/admin-panel/admin-roles.js';
import { OBJECT_STORAGE } from '../../src/modules/media/object-storage.js';
import { STRIPE_API_FACTORY, type StripeApi } from '../../src/modules/topup/stripe-api.js';
import { privateKeyOf, topUpIn } from '../../src/modules/recharge/recharge-core.js';
import { setExchangeRateIn } from '../../src/modules/recharge/recharge-order-core.js';
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
      // D204: the order's pictures go through the private upload.
      MEDIA_UPLOADS_ENABLED: 'true',
      S3_BUCKET: 'kabso-media-smoke',
      S3_ACCESS_KEY_ID: 'smoke',
      S3_SECRET_ACCESS_KEY: 'smoke',
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

  // D204: a disputed recharge order (the real API all the way) and an exchange rate.
  const disputeOwner = await signup('مشرفة النزاعات');
  await withMigrationClient((db) => db.$transaction((tx) => grantRoleIn(tx, disputeOwner.email, 'OWNER')));
  const agent = await signup('محمد الوكيل');
  const agentApp = randomUUID();
  await ctx.prisma.rechargeAgentApplication.create({
    data: {
      id: agentApp,
      userId: agent.id,
      status: 'APPROVED',
      fullName: 'محمد أحمد علي حسن',
      phone: '+201009998887',
      photoKey: privateKeyOf(agentApp, 'photo'),
      selfieKey: privateKeyOf(agentApp, 'selfie'),
      locations: [{ country: 'EG', cities: ['Cairo'] }],
      paymentMethods: [{ country: 'EG', type: 'MOBILE_WALLET', details: '-' }],
      decidedAt: new Date(),
    },
  });
  await ctx.prisma.rechargeAgent.create({
    data: {
      userId: agent.id,
      applicationId: agentApp,
      countries: ['EG'],
      locations: [{ country: 'EG', cities: ['Cairo'] }],
      paymentTypes: { EG: ['MOBILE_WALLET', 'BANK_TRANSFER'] },
    },
  });
  const rules = {
    activationMinCoins: 30_000_000,
    priceTiers: [{ minCoins: 0, minorPerMillion: 1200 }],
    currency: 'USD',
  };
  const { code } = await ctx.prisma.$transaction((tx) =>
    topUpIn(tx, agent.id, 50_000_000n, 60_000n, null, rules, new Date()),
  );
  await ctx.prisma.$transaction((tx) =>
    setExchangeRateIn(tx, 'EG', { currency: 'EGP', rateMicro: 50_500_000n, digits: 2 }, 'smoke', new Date()),
  );
  const buyer = await signup('سارة المشترية');
  const bearer = (u: { token: string }) => ({ Authorization: `Bearer ${u.token}` });
  const receipt = await sharp({ create: { width: 360, height: 640, channels: 3, background: '#f4f4f6' } })
    .composite([
      {
        input: Buffer.from(
          `<svg width="360" height="640"><rect x="24" y="40" width="312" height="70" rx="12" fill="#c8080f"/><rect x="40" y="150" width="280" height="18" fill="#9a9aa6"/><rect x="40" y="190" width="200" height="18" fill="#9a9aa6"/><rect x="40" y="260" width="280" height="44" rx="8" fill="#137a43"/><rect x="40" y="340" width="240" height="18" fill="#9a9aa6"/></svg>`,
        ),
      },
    ])
    .png()
    .toBuffer();
  const privateUpload = async (u: { token: string }) => {
    const slot = await ctx.http
      .post('/api/v1/media/uploads')
      .set(bearer(u))
      .send({ kind: 'RECHARGE_ORDER_IMAGE', contentType: 'image/png', byteSize: receipt.length });
    expect(slot.status).toBe(201);
    expect(storage.upload(slot.body.uploadUrl as string, receipt, 'image/png')).toBe(true);
    return slot.body.uploadId as string;
  };
  const order = await ctx.http
    .post('/api/v1/recharge-orders')
    .set(bearer(buyer))
    .set('Idempotency-Key', randomUUID())
    .send({ agentCode: code, country: 'EG', coins: 2_000_000, paymentType: 'MOBILE_WALLET' });
  expect(order.status).toBe(201);
  const orderId = order.body.id as string;
  const say = async (u: { token: string }, text: string) =>
    expect(
      (await ctx.http.post(`/api/v1/recharge-orders/${orderId}/messages`).set(bearer(u)).send({ text }))
        .status,
    ).toBe(201);
  await say(buyer, 'السلام عليكم، أريد شحن ٢ مليون عملة');
  await say(agent, 'أهلاً، سأرسل لك معلومات التحويل الآن');
  expect(
    (
      await ctx.http
        .post(`/api/v1/recharge-orders/${orderId}/payment-details`)
        .set(bearer(agent))
        .send({ method: 'MOBILE_WALLET', details: 'فودافون كاش: 0100 000 0000\nباسم: محمد أحمد' })
    ).status,
  ).toBe(200);
  expect(
    (await ctx.http.post(`/api/v1/recharge-orders/${orderId}/notice-ack`).set(bearer(buyer))).status,
  ).toBe(200);
  const proofUploadId = await privateUpload(buyer);
  expect(
    (
      await ctx.http
        .post(`/api/v1/recharge-orders/${orderId}/paid`)
        .set(bearer(buyer))
        .send({ proofUploadId })
    ).status,
  ).toBe(200);
  await say(buyer, 'تم التحويل، هذه لقطة الشاشة');
  await say(agent, 'لم يصلني أي مبلغ على الرقم حتى الآن');
  expect(
    (
      await ctx.http
        .post(`/api/v1/recharge-orders/${orderId}/dispute`)
        .set(bearer(agent))
        .send({ reason: 'التحويل لم يصل إلى المحفظة' })
    ).status,
  ).toBe(200);

  writeFileSync(
    file,
    JSON.stringify({
      email: owner.email,
      password: owner.password,
      applicant: applicant.username,
      applicationId: appId,
      disputeOwner: { email: disputeOwner.email, password: disputeOwner.password },
      disputeOrderId: orderId,
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
