/**
 * D229 «أحكام PK»: a local API for the panel's Playwright smoke (apps/admin/e2e/pk-dares.spec.ts). Boots the real app
 * against the *_test database, imports the 20 000-dare seed with the shared importer (as `pk-dares-admin import`),
 * marks three dares reported (one auto-disabled), seeds a not-yet-enrolled OWNER (email and password to SMOKE_FILE)
 * and listens on SMOKE_PORT until SMOKE_STOP_FILE disappears. `SMOKE_PK_DARES=1 pnpm smoke:admin-server`.
 */
import { existsSync, readFileSync, writeFileSync } from 'node:fs';
import { randomUUID } from 'node:crypto';
import { expect, it } from 'vitest';
import { grantRoleIn } from '../../src/modules/admin-panel/admin-roles.js';
import { importPkDaresIn } from '../../src/modules/live/pk-dares/pk-dare-library.js';
import { parseDareImport, type PkDareImport } from '../../src/modules/live/pk-dares/pk-dare-rules.js';
import { createTestApp, registerVerified, withMigrationClient } from '../helpers/test-app.js';

it.skipIf(process.env.SMOKE_PK_DARES !== '1')('serves the «أحكام PK» smoke API', async () => {
  const port = Number(process.env.SMOKE_PORT ?? 3000);
  const file = process.env.SMOKE_FILE ?? 'admin-smoke.json';
  const stop = process.env.SMOKE_STOP_FILE;
  const ctx = await createTestApp({
    ADMIN_TOTP_KEY: `smoke-${randomUUID()}-${randomUUID()}`,
    RATE_LIMIT_ADMIN_LOGIN_IP: '1000/900',
    RATE_LIMIT_ADMIN_IP: '100000/900',
  });
  const seed = readFileSync(new URL('../../prisma/seed/pk-dares/pk-dares.v1.jsonl', import.meta.url), 'utf8')
    .split('\n')
    .filter((l) => l.trim().length > 0)
    .map((l) => parseDareImport(JSON.parse(l)) as PkDareImport);
  await withMigrationClient(async (db) => {
    await db.$transaction(
      (tx) =>
        importPkDaresIn(tx, seed, {
          dryRun: false,
          reason: 'smoke',
          actor: { userId: null, via: 'cli' },
          createdBy: 'SEED',
        }),
      { timeout: 600_000, maxWait: 60_000 },
    );
    await db.pkDare.updateMany({ data: { active: true, reportCount: 0, disabledReason: null } });
    await db.pkDare.update({
      where: { code: 'v1-funny-00007' },
      data: { reportCount: 6, active: false, disabledReason: 'REPORTS' },
    });
    await db.pkDare.update({ where: { code: 'v1-acting-00012' }, data: { reportCount: 2 } });
    await db.pkDare.update({ where: { code: 'v1-truth-00030' }, data: { reportCount: 1 } });
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
    JSON.stringify({ pkDaresOwner: { email: payload.email, password: payload.password } }),
    {
      mode: 0o600,
    },
  );
  await ctx.app.listen(port, '127.0.0.1');
  const until = Date.now() + 3_600_000;
  while (Date.now() < until && (stop === undefined || existsSync(stop))) {
    await new Promise((r) => setTimeout(r, 500));
  }
  await ctx.close();
});
