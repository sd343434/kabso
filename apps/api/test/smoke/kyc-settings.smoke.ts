/**
 * D227: serves the API for the «التحقق من الهوية (Didit)» Playwright run (apps/admin/e2e/kyc.spec.ts) — the real app
 * on PostgreSQL + Redis (the *_test database is reset) with Didit FAKED (test/helpers/fake-didit.ts behind
 * `DIDIT_API_FACTORY`: no network, made-up keys). Seeds a not-yet-enrolled OWNER, a pending «كن مضيفاً مع الإدارة»
 * application whose applicant has an approved check, and another account with the same document (the duplicate
 * flag). Writes the credentials, the made-up Didit key / secret / workflow and the application id to SMOKE_FILE;
 * listens on SMOKE_PORT (3000) until SMOKE_STOP_FILE is removed. `SMOKE_KYC=1 pnpm smoke:admin-server`.
 */
import { existsSync, writeFileSync } from 'node:fs';
import { randomUUID } from 'node:crypto';
import { expect, it } from 'vitest';
import { grantRoleIn } from '../../src/modules/admin-panel/admin-roles.js';
import { DIDIT_API_FACTORY } from '../../src/modules/kyc/didit-api.js';
import { FakeDidit, fakeKey } from '../helpers/fake-didit.js';
import { createTestApp, registerVerified, withMigrationClient } from '../helpers/test-app.js';

it.skipIf(process.env.SMOKE_KYC !== '1')('serves the identity verification smoke API', async () => {
  const port = Number(process.env.SMOKE_PORT ?? 3000);
  const file = process.env.SMOKE_FILE ?? 'admin-smoke.json';
  const stop = process.env.SMOKE_STOP_FILE;
  const didit = new FakeDidit();
  const apiKey = fakeKey('didit_smoke_api');
  const webhookSecret = fakeKey('didit_smoke_whsec');
  didit.keys.add(apiKey);
  const workflowId = didit.addWorkflow({ label: 'Kabso KYC', features: 'OCR + LIVENESS + FACE_MATCH' });
  const ctx = await createTestApp(
    {
      ADMIN_TOTP_KEY: `smoke-${randomUUID()}-${randomUUID()}`,
      RATE_LIMIT_ADMIN_LOGIN_IP: '1000/900',
      RATE_LIMIT_ADMIN_IP: '100000/900',
    },
    [{ token: DIDIT_API_FACTORY, value: didit.factory }],
  );
  const signup = async (name: string) => {
    const { res, payload } = await registerVerified(ctx);
    expect(res.status).toBe(201);
    const id = res.body.user.id as string;
    await ctx.prisma.userProfile.update({ where: { userId: id }, data: { displayName: name } });
    return { id, payload };
  };
  const owner = await signup('المالك');
  await withMigrationClient((db) => db.$transaction((tx) => grantRoleIn(tx, owner.payload.email, 'OWNER')));
  const applicant = await signup('نورة المضيفة');
  const other = await signup('حساب آخر');
  const now = new Date();
  const hash = 'a'.repeat(64);
  const application = await ctx.prisma.hostApplication.create({
    data: {
      userId: applicant.id,
      clientKey: randomUUID(),
      requestHash: 'b'.repeat(64),
      displayName: 'نورة المضيفة',
      country: 'SA',
      dateOfBirth: new Date('1995-04-02T00:00:00.000Z'),
      contactType: 'WHATSAPP',
      contactValue: '+966511111111',
      bio: 'أبث الطبخ والدردشة كل مساء',
      links: [],
      rulesAcceptedAt: now,
      createdAt: now,
    },
  });
  for (const [userId, number] of [
    [applicant.id, 43762],
    [other.id, 43790],
  ] as const) {
    await ctx.prisma.kycCheck.create({
      data: {
        userId,
        purpose: 'HOST_APPLICATION',
        status: 'APPROVED',
        sessionId: randomUUID(),
        sessionNumber: number,
        workflowId,
        providerStatus: 'Approved',
        fullName: userId === applicant.id ? 'NOURA AL SAUD' : 'NOURA ALSAUD',
        dateOfBirth: new Date('1995-04-02T00:00:00.000Z'),
        documentCountry: 'SAU',
        documentHash: hash,
        duplicateDocument: true,
        createdAt: now,
        decidedAt: now,
      },
    });
  }
  writeFileSync(
    file,
    JSON.stringify({
      kycOwner: { email: owner.payload.email, password: owner.payload.password },
      didit: { apiKey, webhookSecret, workflowId },
      hostApplicationId: application.id,
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
