/**
 * D338: serves the API for the «حذف» Playwright run (apps/admin/e2e/gift-delete.spec.ts) — the real app on PostgreSQL +
 * Redis (the *_test database is reset) with a not-yet-enrolled OWNER and four gifts: one never used (deleted for good),
 * one held in a bag (archived), one already archived and one plain. Writes the credentials to SMOKE_FILE; listens on
 * SMOKE_PORT (3000) until SMOKE_STOP_FILE is removed. `SMOKE_GIFTS=1 pnpm smoke:admin-server`.
 */
import { existsSync, writeFileSync } from 'node:fs';
import { randomUUID } from 'node:crypto';
import { expect, it } from 'vitest';
import { CLI_VIA } from '../../src/common/audit/admin-actor.js';
import { grantRoleIn } from '../../src/modules/admin-panel/admin-roles.js';
import { removeGiftByAdminIn } from '../../src/modules/gifts/gift-admin-rules.js';
import { addGiftIn, grantStockIn } from '../../src/modules/gifts/gift-catalogue.js';
import { createTestApp, registerVerified, withMigrationClient } from '../helpers/test-app.js';

const off = process.env.SMOKE_GIFTS !== '1';
it.skipIf(off)('serves the gift delete smoke API', async () => {
  const port = Number(process.env.SMOKE_PORT ?? 3000);
  const file = process.env.SMOKE_FILE ?? 'admin-smoke.json';
  const stop = process.env.SMOKE_STOP_FILE;
  const ctx = await createTestApp({
    ADMIN_TOTP_KEY: `smoke-${randomUUID()}-${randomUUID()}`,
    RATE_LIMIT_ADMIN_LOGIN_IP: '1000/900',
    RATE_LIMIT_ADMIN_IP: '100000/900',
    MEDIA_UPLOADS_ENABLED: 'false',
  });
  const { res, payload } = await registerVerified(ctx);
  expect(res.status).toBe(201);
  const ownerId = res.body.user.id as string;
  await ctx.prisma.userProfile.update({ where: { userId: ownerId }, data: { displayName: 'المالك' } });
  await withMigrationClient((db) => db.$transaction((tx) => grantRoleIn(tx, payload.email, 'OWNER')));
  for (const [code, ar, en, price] of [
    ['smoke_new', 'هدية جديدة', 'New gift', 100],
    ['smoke_held', 'وردة الحقيبة', 'Bag rose', 500],
    ['smoke_old', 'هدية قديمة', 'Old gift', 1000],
    ['smoke_star', 'نجمة', 'Star', 2000],
  ] as const) {
    await ctx.prisma.$transaction((tx) =>
      addGiftIn(tx, code, {
        category: 'POPULAR',
        nameAr: ar,
        nameEn: en,
        priceCoins: price,
        assetKey: code,
        animationKey: null,
        sortOrder: 0,
        badge: 'NONE',
        tagCode: null,
        tagNameAr: null,
        tagNameEn: null,
      }),
    );
  }
  await ctx.prisma.$transaction((tx) => grantStockIn(tx, ownerId, 'smoke_held', 3));
  await ctx.prisma.$transaction((tx) => grantStockIn(tx, ownerId, 'smoke_old', 1));
  await ctx.prisma.$transaction((tx) => removeGiftByAdminIn(tx, 'smoke_old', CLI_VIA, 'retired'));
  writeFileSync(file, JSON.stringify({ email: payload.email, password: payload.password }), { mode: 0o600 });
  await ctx.app.listen(port, '127.0.0.1');
  const until = Date.now() + 3_600_000;
  while (Date.now() < until && (stop === undefined || existsSync(stop))) {
    await new Promise((r) => setTimeout(r, 500));
  }
  await ctx.close();
});
