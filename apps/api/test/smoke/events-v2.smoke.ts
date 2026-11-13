/**
 * D325: serves the API for the «الفعاليات» Playwright run (apps/admin/e2e/events-v2.spec.ts) — the real app on
 * PostgreSQL + Redis (the *_test database is reset) with a not-yet-enrolled OWNER, two gifts, «مهرجان انطلاقة Kabso» as a
 * draft (the panel's template rule), a published weekly gift event and an older D166 event. Writes the credentials to
 * SMOKE_FILE; listens on SMOKE_PORT (3000) until SMOKE_STOP_FILE is removed. `SMOKE_EVENTS=1 pnpm smoke:admin-server`.
 */
import { existsSync, writeFileSync } from 'node:fs';
import { randomUUID } from 'node:crypto';
import { expect, it } from 'vitest';
import { CLI_VIA } from '../../src/common/audit/admin-actor.js';
import { grantRoleIn } from '../../src/modules/admin-panel/admin-roles.js';
import { addGiftIn } from '../../src/modules/gifts/gift-catalogue.js';
import { createEventByAdminIn } from '../../src/modules/programs/event-admin-rules.js';
import { createGiftEventIn, giftEventInputSchema } from '../../src/modules/programs/gift-events.js';
import { createLaunchFestivalDraftIn } from '../../src/modules/programs/launch-festival.js';
import { createTestApp, registerVerified, withMigrationClient } from '../helpers/test-app.js';

const off = process.env.SMOKE_EVENTS !== '1';
it.skipIf(off)('serves the events v2 smoke API', async () => {
  const port = Number(process.env.SMOKE_PORT ?? 3000);
  const file = process.env.SMOKE_FILE ?? 'admin-smoke.json';
  const stop = process.env.SMOKE_STOP_FILE;
  const ctx = await createTestApp({
    ADMIN_TOTP_KEY: `smoke-${randomUUID()}-${randomUUID()}`,
    RATE_LIMIT_ADMIN_LOGIN_IP: '1000/900',
    RATE_LIMIT_ADMIN_IP: '100000/900',
    MEDIA_UPLOADS_ENABLED: 'false',
    LIVE_RANKINGS_TIME_ZONE: 'Asia/Riyadh',
    EVENTS_SWEEP_INTERVAL_SECONDS: '0',
  });
  const { res, payload } = await registerVerified(ctx);
  expect(res.status).toBe(201);
  await ctx.prisma.userProfile.update({
    where: { userId: res.body.user.id as string },
    data: { displayName: 'المالك' },
  });
  await withMigrationClient((db) => db.$transaction((tx) => grantRoleIn(tx, payload.email, 'OWNER')));
  const now = new Date();
  for (const [code, ar, en, price] of [
    ['smoke_rose', 'وردة', 'Rose', 100],
    ['smoke_star', 'نجمة', 'Star', 1000],
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
  await ctx.prisma.$transaction((tx) =>
    createLaunchFestivalDraftIn(tx, CLI_VIA, now, 'prepare the launch festival', 'Asia/Riyadh'),
  );
  await ctx.prisma.$transaction((tx) =>
    createGiftEventIn(
      tx,
      giftEventInputSchema.parse({
        status: 'PUBLISHED',
        titleAr: 'نجم الأسبوع',
        titleEn: 'Weekly star',
        startsAt: new Date(now.getTime() - 3_600_000).toISOString(),
        endsAt: null,
        permanent: true,
        recurrence: 'WEEKLY',
        timeZone: 'Asia/Riyadh',
        gifts: [{ giftCode: 'smoke_star', pointsPerCoin: 1.5 }],
        boards: [
          { kind: 'SENDERS', prizes: [{ rankFrom: 1, rankTo: 3, items: [{ type: 'COINS', amount: 1000 }] }] },
        ],
        reason: 'weekly star',
      }),
      now,
      CLI_VIA,
      'Asia/Riyadh',
    ),
  );
  await ctx.prisma.$transaction((tx) =>
    createEventByAdminIn(tx, {
      titleAr: 'أكثر الداعمين (قديمة)',
      titleEn: 'Top supporters (older)',
      rulesAr: '',
      rulesEn: '',
      startsAt: new Date(now.getTime() - 10 * 86_400_000),
      endsAt: new Date(now.getTime() - 3 * 86_400_000),
      permanent: false,
      metric: 'GIFT_COINS_SENT',
      audience: 'EVERYONE',
      regions: [],
      featured: false,
      bannerUrl: null,
      prizes: [{ rankFrom: 1, rankTo: 1, coins: 500 }],
      summaryAr: null,
      summaryEn: null,
      tone: null,
    }),
  );
  writeFileSync(file, JSON.stringify({ email: payload.email, password: payload.password }), { mode: 0o600 });
  await ctx.app.listen(port, '127.0.0.1');
  const until = Date.now() + 3_600_000;
  while (Date.now() < until && (stop === undefined || existsSync(stop))) {
    await new Promise((r) => setTimeout(r, 500));
  }
  await ctx.close();
});
