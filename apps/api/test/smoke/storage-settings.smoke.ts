/**
 * D222: serves the API for the «التخزين (R2 / S3)» Playwright run (apps/admin/e2e/storage.spec.ts) — the real app on
 * PostgreSQL + Redis (the *_test database is reset) with NO server storage (`MEDIA_UPLOADS_ENABLED=false`, no `S3_*`:
 * the staging server today) and a local S3-compatible server (`FakeS3`, test/helpers/fake-s3.ts) holding a public and
 * a private bucket, so the section can test, save and turn on real round trips with the production adapter. Seeds a
 * not-yet-enrolled OWNER and a user; writes the credentials, the S3 endpoint, made-up keys and the bucket names to
 * SMOKE_FILE; listens on SMOKE_PORT (3000) until SMOKE_STOP_FILE is removed. `SMOKE_STORAGE=1 pnpm smoke:admin-server`.
 */
import { existsSync, writeFileSync } from 'node:fs';
import { randomBytes, randomUUID } from 'node:crypto';
import { expect, it } from 'vitest';
import { grantRoleIn } from '../../src/modules/admin-panel/admin-roles.js';
import { FakeS3 } from '../helpers/fake-s3.js';
import { createTestApp, registerVerified, withMigrationClient } from '../helpers/test-app.js';

it.skipIf(process.env.SMOKE_STORAGE !== '1')('serves the storage settings smoke API', async () => {
  const port = Number(process.env.SMOKE_PORT ?? 3000);
  const file = process.env.SMOKE_FILE ?? 'admin-smoke.json';
  const stop = process.env.SMOKE_STOP_FILE;
  // Made-up keys (never real).
  const accessKeyId = `AKSMOKE${randomBytes(5).toString('hex')}Ak1d`;
  const secretAccessKey = `${randomBytes(16).toString('hex')}Sc4t`;
  const s3 = new FakeS3(accessKeyId, secretAccessKey);
  await s3.start();
  s3.createBucket('kabso-media', true);
  s3.createBucket('kabso-private', false);
  const ctx = await createTestApp({
    ADMIN_TOTP_KEY: `smoke-${randomUUID()}-${randomUUID()}`,
    RATE_LIMIT_ADMIN_LOGIN_IP: '1000/900',
    RATE_LIMIT_ADMIN_IP: '100000/900',
    MEDIA_UPLOADS_ENABLED: 'false',
  });
  const { res, payload } = await registerVerified(ctx);
  expect(res.status).toBe(201);
  await ctx.prisma.userProfile.update({
    where: { userId: res.body.user.id as string },
    data: { displayName: 'المالك' },
  });
  await withMigrationClient((db) => db.$transaction((tx) => grantRoleIn(tx, payload.email, 'OWNER')));
  writeFileSync(
    file,
    JSON.stringify({
      storageOwner: { email: payload.email, password: payload.password },
      s3: {
        endpoint: s3.endpoint,
        accessKeyId,
        secretAccessKey,
        publicBucket: 'kabso-media',
        privateBucket: 'kabso-private',
        publicBaseUrl: s3.publicUrl('kabso-media'),
      },
    }),
    { mode: 0o600 },
  );
  await ctx.app.listen(port, '127.0.0.1');
  const until = Date.now() + 3_600_000;
  while (Date.now() < until && (stop === undefined || existsSync(stop))) {
    await new Promise((r) => setTimeout(r, 500));
  }
  await ctx.prisma.storageSettings.deleteMany();
  await ctx.close();
  await s3.stop();
});
