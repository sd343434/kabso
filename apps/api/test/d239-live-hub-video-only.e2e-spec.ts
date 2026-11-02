/**
 * D239 (owner: «بث صوتي يظهر في غير مكانه»): the app's main live hub lists video lives only —
 * SOLO and PK, the existing `kind=solo` of `GET /live/rooms` (CONVENTIONS §10.4) — under every hub
 * filter (following, nearby, popular, featured, explore); AUDIO, PODCAST and MULTI rooms are the party
 * page's (`kind=audio|podcast|multi`). Server-side, so every page of a cursor walk agrees.
 */
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';
import { Clock } from '../src/common/time/clock.js';
import { LIVE_MEDIA_PROVIDER } from '../src/modules/live/media/live-media.provider.js';
import { MemoryLiveMedia } from './helpers/memory-live-media.js';
import { expectContract } from './helpers/openapi.js';
import { createTestApp, registerVerified, type TestContext } from './helpers/test-app.js';

class FakeClock extends Clock {
  private ms = Date.now();
  now(): Date {
    return new Date(this.ms);
  }
  advance(seconds: number): void {
    this.ms += Math.round(seconds * 1000);
  }
}

interface TestUser {
  readonly id: string;
  readonly username: string;
  readonly token: string;
}

type Mode = 'SOLO' | 'PK' | 'MULTI' | 'AUDIO' | 'PODCAST';

describe('D239 the main hub: video lives only', { timeout: 240_000 }, () => {
  const clock = new FakeClock();
  const media = new MemoryLiveMedia();
  let ctx: TestContext;

  const auth = (u: TestUser) => ({ Authorization: `Bearer ${u.token}` });
  const signup = async (country: string | null): Promise<TestUser> => {
    const { res } = await registerVerified(ctx);
    expect(res.status).toBe(201);
    const u: TestUser = {
      id: res.body.user.id as string,
      username: res.body.user.username as string,
      token: res.body.tokens.accessToken as string,
    };
    if (country !== null) {
      const patch = await ctx.http.patch('/api/v1/me').set(auth(u)).send({ country });
      expect(patch.status, JSON.stringify(patch.body)).toBe(200);
    }
    return u;
  };
  const goLive = async (mode: Mode, score: number): Promise<string> => {
    const u = await signup('SA');
    await ctx.prisma.liveHost.create({ data: { userId: u.id, source: 'ADMIN' } });
    await ctx.prisma.liveFeaturedHost.create({ data: { userId: u.id, rank: score } });
    hosts.push(u);
    clock.advance(1);
    const body =
      mode === 'AUDIO'
        ? { mode: 'AUDIO', seatCount: 10 }
        : mode === 'MULTI'
          ? { mode: 'MULTI', seatCount: 4 }
          : mode === 'PODCAST'
            ? { mode: 'PODCAST', podcast: { topic: 'business' } }
            : {};
    const res = await ctx.http
      .post('/api/v1/live/rooms')
      .set(auth(u))
      .send({ title: 'Hub', ...body });
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    const id = res.body.id as string;
    await ctx.prisma.liveRoom.update({
      where: { id },
      data: { score: BigInt(score), ...(mode === 'PK' ? { mode: 'PK' } : {}) },
    });
    return id;
  };
  const list = async (query: string, u: TestUser) => {
    const res = await ctx.http.get(`/api/v1/live/rooms?${query}`).set(auth(u));
    expectContract(res, 'listLiveRooms');
    expect(res.status, `${query} ${JSON.stringify(res.body)}`).toBe(200);
    return res;
  };
  const ids = async (query: string, u: TestUser): Promise<string[]> =>
    ((await list(query, u)).body.data as { id: string }[]).map((r) => r.id);
  /** Every page with limit=1, following the cursors. */
  const pages = async (query: string, u: TestUser): Promise<string[]> => {
    const out: string[] = [];
    let cursor: string | null = null;
    for (let i = 0; i < 50; i += 1) {
      const res = await list(`${query}&limit=1${cursor ? `&cursor=${encodeURIComponent(cursor)}` : ''}`, u);
      out.push(...(res.body.data as { id: string }[]).map((r) => r.id));
      cursor = res.body.page.nextCursor as string | null;
      if (!cursor) return out;
    }
    throw new Error('too many pages');
  };

  let hosts: TestUser[] = [];

  beforeAll(async () => {
    ctx = await createTestApp({ LIVE_HOSTING_ENABLED: 'true', LIVE_HEARTBEAT_STALE_SECONDS: '3600' }, [
      { token: Clock, value: clock },
      { token: LIVE_MEDIA_PROVIDER, value: media },
    ]);
  });
  afterAll(async () => ctx?.close());
  beforeEach(async () => {
    hosts = [];
    await ctx.prisma.liveRoom.updateMany({
      where: { status: 'LIVE' },
      data: { status: 'ENDED', endReason: 'ADMIN', endedAt: clock.now() },
    });
    await ctx.prisma.liveFeaturedHost.deleteMany({});
  });

  it('every hub filter with kind=solo lists SOLO and PK only, the same over limit=1 pages', async () => {
    const r = {
      solo: await goLive('SOLO', 40),
      pk: await goLive('PK', 50),
      multi: await goLive('MULTI', 60),
      audio: await goLive('AUDIO', 70),
      podcast: await goLive('PODCAST', 80),
    };
    const viewer = await signup('SA');
    for (const h of hosts) {
      const res = await ctx.http.put(`/api/v1/users/${h.username}/follow`).set(auth(viewer));
      expect([200, 201]).toContain(res.status);
    }
    const party = [r.multi, r.audio, r.podcast];
    // The hub's five filters (LiveHubSelection.query in the app).
    const filters = {
      following: 'tab=following',
      nearby: 'tab=popular&scope=nearby',
      popular: 'tab=popular',
      featured: 'tab=popular&featured=true',
      explore: 'tab=new',
    };
    for (const [name, base] of Object.entries(filters)) {
      const hub = await ids(`${base}&kind=solo`, viewer);
      expect(new Set(hub), name).toEqual(new Set([r.solo, r.pk]));
      for (const id of party) expect(hub, `${name} ${id}`).not.toContain(id);
      // Pagination stays correct: the cursor walk is the single page.
      expect(await pages(`${base}&kind=solo`, viewer), name).toEqual(hub);
      // Without a kind every room is there (the party kinds are the party page's).
      expect(new Set(await ids(base, viewer)), name).toEqual(new Set(Object.values(r)));
    }
    // The party page's tabs keep their rooms.
    expect(await ids('tab=popular&kind=audio', viewer)).toEqual([r.audio]);
    expect(await ids('tab=popular&kind=podcast', viewer)).toEqual([r.podcast]);
    expect(await ids('tab=popular&kind=multi', viewer)).toEqual([r.multi]);
  });

  it('a hub cursor is bound to kind=solo (no reuse without it)', async () => {
    await goLive('SOLO', 1);
    await goLive('PK', 2);
    await goLive('AUDIO', 3);
    const viewer = await signup('SA');
    const first = await list('tab=popular&kind=solo&limit=1', viewer);
    const cursor = first.body.page.nextCursor as string;
    expect(cursor).toBeTruthy();
    const reused = await ctx.http
      .get(`/api/v1/live/rooms?tab=popular&limit=1&cursor=${encodeURIComponent(cursor)}`)
      .set(auth(viewer));
    expect(reused.status).toBe(400);
  });
});
