/**
 * D239 (owner: «بث صوتي يظهر في غير مكانه»): the app's main live hub lists video lives only —
 * SOLO and PK, the existing `kind=solo` of `GET /live/rooms` (CONVENTIONS §10.4) — under every hub
 * filter (following, nearby, popular, featured, explore); AUDIO, PODCAST and MULTI rooms are the party
 * page's (`kind=audio|podcast|multi`). Server-side, so every page of a cursor walk agrees.
 * v1.115-live (D368, §10.161): a live VIDEO podcast is a camera live of the hub (`kind=solo`), not the party page's.
 * v1.116-live (D369, §10.162): a (legacy) MULTI room is in no list.
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

type Mode = 'SOLO' | 'PK' | 'MULTI' | 'AUDIO' | 'PODCAST' | 'VPODCAST';

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
        : mode === 'PODCAST'
          ? { mode: 'PODCAST', podcast: { topic: 'business' } }
          : mode === 'VPODCAST'
            ? { mode: 'PODCAST', podcast: { topic: 'business', video: true } }
            : {}; // SOLO; PK and a legacy MULTI (D369: no longer started) are set below
    const res = await ctx.http
      .post('/api/v1/live/rooms')
      .set(auth(u))
      .send({ title: 'Hub', ...body });
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    const id = res.body.id as string;
    await ctx.prisma.liveRoom.update({
      where: { id },
      data: {
        score: BigInt(score),
        ...(mode === 'PK' ? { mode: 'PK' } : {}),
        ...(mode === 'MULTI' ? { mode: 'MULTI', seatCount: 4 } : {}),
      },
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

  it('every hub filter with kind=solo lists SOLO, PK and the video podcast only, the same over limit=1 pages', async () => {
    const r = {
      solo: await goLive('SOLO', 40),
      pk: await goLive('PK', 50),
      multi: await goLive('MULTI', 60),
      audio: await goLive('AUDIO', 70),
      podcast: await goLive('PODCAST', 80),
      vpodcast: await goLive('VPODCAST', 90),
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
      expect(new Set(hub), name).toEqual(new Set([r.solo, r.pk, r.vpodcast]));
      for (const id of party) expect(hub, `${name} ${id}`).not.toContain(id);
      // Pagination stays correct: the cursor walk is the single page.
      expect(await pages(`${base}&kind=solo`, viewer), name).toEqual(hub);
      // `kind=video` lists the same camera lives.
      expect(new Set(await ids(`${base}&kind=video`, viewer)), name).toEqual(new Set(hub));
      // The party page (D342): AUDIO and the audio podcast — never the video podcast or a MULTI.
      const partyAll = await ids(`${base}&kind=party_all`, viewer);
      expect(new Set(partyAll), name).toEqual(new Set([r.audio, r.podcast]));
      expect(await pages(`${base}&kind=party_all`, viewer), name).toEqual(partyAll);
      // Without a kind every room is there but the retired MULTI (D369).
      expect(new Set(await ids(base, viewer)), name).toEqual(
        new Set([r.solo, r.pk, r.audio, r.podcast, r.vpodcast]),
      );
    }
    // The party page's tabs keep their rooms; `podcast` keeps every podcast (older apps).
    expect(await ids('tab=popular&kind=audio', viewer)).toEqual([r.audio]);
    expect(new Set(await ids('tab=popular&kind=podcast', viewer))).toEqual(new Set([r.podcast, r.vpodcast]));
    expect(await ids('tab=popular&kind=party', viewer)).toEqual([r.audio]);
    expect(await ids('tab=popular&kind=multi', viewer)).toEqual([]);
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
