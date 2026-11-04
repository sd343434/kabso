/**
 * D265 (owner feedback on VIP 1, CONVENTIONS §10.94): a VIP host's own room carries their VIP like every other
 * UserSummary (their seat's frame, their entry on their own screen), and a VIP member's join line is never dropped by
 * the one-join-a-second window (their entry car), like an agent's. End to end against PostgreSQL + Redis with the API
 * as the DML-only runtime role.
 */
import { randomUUID } from 'node:crypto';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { LiveMediaService } from '../src/modules/live/live-media.service.js';
import { LIVE_MEDIA_PROVIDER } from '../src/modules/live/media/live-media.provider.js';
import { creditIn } from '../src/modules/wallet/wallet-ledger.js';
import { panel, type Person } from './helpers/admin-panel.js';
import { MemoryLiveMedia } from './helpers/memory-live-media.js';
import { expectContract } from './helpers/openapi.js';
import { createTestApp, type TestContext } from './helpers/test-app.js';

const VIP1 = '01a25200-0000-7000-8000-000000000001';
const VIP1_SUMMARY = { tier: 'VIP_1', rank: 1, color: '#2E8B3D' };

describe('D265 VIP in lives', { timeout: 180_000 }, () => {
  const media = new MemoryLiveMedia();
  let ctx: TestContext;
  const p = panel(() => ctx);
  const auth = (u: Person) => ({ Authorization: `Bearer ${u.token}` });

  const buyVip = async (u: Person) => {
    await ctx.prisma.$transaction((tx) => creditIn(tx, u.id, 2_000_000n, 'ADMIN_GRANT', randomUUID()));
    const buy = await ctx.http
      .post('/api/v1/me/vip/purchases')
      .set(auth(u))
      .set('Idempotency-Key', randomUUID())
      .send({ tierId: VIP1, priceCoins: 1_000_000 });
    expect(buy.status, JSON.stringify(buy.body)).toBe(201);
  };

  beforeAll(async () => {
    ctx = await createTestApp(
      {
        LIVE_HOSTING_ENABLED: 'true',
        LIVE_HEARTBEAT_STALE_SECONDS: '3600',
        LIVE_RANKINGS_TIME_ZONE: 'UTC',
      },
      [{ token: LIVE_MEDIA_PROVIDER, value: media }],
    );
  });
  afterAll(async () => ctx?.close());

  it("the room's host carries their VIP; a VIP's join is never dropped in the same second", async () => {
    const host = await p.signup();
    await buyVip(host);
    await ctx.prisma.liveHost.create({ data: { userId: host.id, source: 'ADMIN' } });
    const room = await ctx.http.post('/api/v1/live/rooms').set(auth(host)).send({ title: 'VIP live' });
    expect(room.status, JSON.stringify(room.body)).toBe(201);
    expectContract(room, 'startLiveRoom');
    expect(room.body.host.vip).toEqual(VIP1_SUMMARY);
    const roomId = room.body.id as string;

    const viewer = await p.signup();
    const read = await ctx.http.get(`/api/v1/live/rooms/${roomId}`).set(auth(viewer));
    expect(read.status).toBe(200);
    expectContract(read, 'getLiveRoom');
    expect(read.body.host.vip).toEqual(VIP1_SUMMARY);

    // Two joins in the same second: a plain one, then a VIP member's — both announced.
    const member = await p.signup();
    await buyVip(member);
    const late = await p.signup();
    const onJoined = (id: string) =>
      ctx.app
        .get<LiveMediaService, { onJoined(r: string, i: string): Promise<void> }>(LiveMediaService)
        .onJoined(roomId, id);
    await onJoined(viewer.id);
    await onJoined(member.id);
    const joins = media.broadcastsOf(roomId, 'join');
    expect(joins.map((j) => (j.user as { id: string; vip?: unknown }).vip)).toEqual([
      undefined,
      VIP1_SUMMARY,
    ]);
    // A plain one in the same second is still dropped (D96).
    await onJoined(late.id);
    expect(media.broadcastsOf(roomId, 'join')).toHaveLength(2);
  });
});
