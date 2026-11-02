/**
 * D247: serves the API for «استوديو البث»'s Playwright run (apps/studio/e2e) — the real app on PostgreSQL + Redis (the
 * *_test database is reset). With LIVEKIT_TEST_URL (a local `livekit-server --dev`-style server) the media provider is
 * the real LiveKit one and the media reconciliation runs every 2 s, so a viewer that joins the media room may chat;
 * without it the in-memory media server stands in (no real publish). Seeds a host with the hosting permission, an
 * account without it, a viewer with coins and one gift, writes their sign-ins to SMOKE_FILE and listens on SMOKE_PORT
 * until SMOKE_STOP_FILE disappears (or an hour passes). Only with SMOKE_STUDIO=1, one file at a time:
 * `SMOKE_STUDIO=1 pnpm exec vitest run --config vitest.smoke.config.ts test/smoke/studio.smoke.ts`.
 */
import { existsSync, writeFileSync } from 'node:fs';
import { randomUUID } from 'node:crypto';
import { expect, it } from 'vitest';
import { addGiftIn } from '../../src/modules/gifts/gift-catalogue.js';
import { LIVE_MEDIA_PROVIDER } from '../../src/modules/live/media/live-media.provider.js';
import { LiveKitMediaProvider } from '../../src/modules/live/media/livekit-media.provider.js';
import { creditIn } from '../../src/modules/wallet/wallet-ledger.js';
import { MemoryLiveMedia } from '../helpers/memory-live-media.js';
import { createTestApp, registerVerified } from '../helpers/test-app.js';

it.runIf(process.env.SMOKE_STUDIO === '1')('serves the studio smoke API', async () => {
  const port = Number(process.env.SMOKE_PORT ?? 3000);
  const file = process.env.SMOKE_FILE ?? 'studio-smoke.json';
  const stop = process.env.SMOKE_STOP_FILE;
  const lkUrl = process.env.LIVEKIT_TEST_URL;
  const lkKey = process.env.LIVEKIT_TEST_API_KEY ?? 'devkey';
  const lkSecret = process.env.LIVEKIT_TEST_API_SECRET ?? 'secret';
  const ctx = await createTestApp(
    {
      LIVE_HOSTING_ENABLED: 'true',
      LIVE_SWEEP_INTERVAL_SECONDS: lkUrl ? '2' : '15',
      ...(lkUrl ? { LIVEKIT_URL: lkUrl, LIVEKIT_API_KEY: lkKey, LIVEKIT_API_SECRET: lkSecret } : {}),
      RATE_LIMIT_LOGIN_IP: '1000/900',
    },
    [
      {
        token: LIVE_MEDIA_PROVIDER,
        value: lkUrl ? new LiveKitMediaProvider(lkUrl, lkKey, lkSecret) : new MemoryLiveMedia(),
      },
    ],
  );
  const signup = async (displayName: string) => {
    const { res, payload } = await registerVerified(ctx);
    expect(res.status).toBe(201);
    const id = res.body.user.id as string;
    await ctx.prisma.userProfile.update({ where: { userId: id }, data: { displayName } });
    return {
      id,
      username: res.body.user.username as string,
      email: String(payload.email),
      password: String(payload.password),
      token: res.body.tokens.accessToken as string,
    };
  };
  const host = await signup('سارة ستريمر');
  await ctx.prisma.liveHost.create({ data: { userId: host.id, source: 'ADMIN' } });
  const noHost = await signup('مشاهد عادي');
  const viewer = await signup('ليلى');
  await ctx.prisma.$transaction((tx) => creditIn(tx, viewer.id, 100_000n, 'ADMIN_GRANT', randomUUID()));
  const giftCode = 'd247_rose';
  await ctx.prisma.$transaction((tx) =>
    addGiftIn(tx, giftCode, {
      category: 'POPULAR',
      nameAr: 'وردة',
      nameEn: 'Rose',
      priceCoins: 10,
      assetKey: 'gift_rose',
      animationKey: null,
      sortOrder: 1,
      badge: 'NONE',
      tagCode: null,
      tagNameAr: null,
      tagNameEn: null,
    }),
  );
  writeFileSync(file, JSON.stringify({ port, livekit: lkUrl ?? null, host, noHost, viewer, giftCode }), {
    mode: 0o600,
  });
  await ctx.app.listen(port, '127.0.0.1');
  const until = Date.now() + 3_600_000;
  while (Date.now() < until && (stop === undefined || existsSync(stop))) {
    await new Promise((r) => setTimeout(r, 500));
  }
  await ctx.close();
  if (lkUrl) {
    const rtc = await import('@livekit/rtc-node').catch(() => null);
    await rtc?.dispose();
  }
});
