/**
 * D129 (openapi v1.26.4-live DRAFT, CONVENTIONS §10.4, §10.10): the live hub's voice rooms apart
 * from its video lives (`GET /live/rooms?kind=audio|video`), and the hub ranking belongs to one
 * live — a new live starts at 0 and a host who ends a live loses that ranking. End to end against
 * PostgreSQL + Redis with the API as the DML-only runtime role; the media server is the in-memory
 * fake behind the LiveMediaProvider port.
 */
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';
import { Clock } from '../src/common/time/clock.js';
import { LIVE_MEDIA_PROVIDER } from '../src/modules/live/media/live-media.provider.js';
import { MemoryLiveMedia } from './helpers/memory-live-media.js';
import { expectContract, operations } from './helpers/openapi.js';
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
  readonly token: string;
}

describe('D129 contract coverage', () => {
  it('openapi declares the optional kind=audio|video query parameter on listLiveRooms', () => {
    const op = operations().find((o) => o.operationId === 'listLiveRooms');
    expect(op).toBeDefined();
    const params = (op?.spec as { parameters?: { name?: string }[] } | undefined)?.parameters;
    expect(params?.find((p) => p.name === 'kind')).toEqual(
      expect.objectContaining({
        in: 'query',
        required: false,
        schema: { type: 'string', enum: ['audio', 'video'] },
      }),
    );
  });
});

describe('D129 the hub kind filter and the per-live ranking', { timeout: 120_000 }, () => {
  const clock = new FakeClock();
  const media = new MemoryLiveMedia();
  let ctx: TestContext;

  const auth = (u: TestUser) => ({ Authorization: `Bearer ${u.token}` });
  const signup = async (): Promise<TestUser> => {
    const { res } = await registerVerified(ctx);
    expect(res.status).toBe(201);
    return { id: res.body.user.id, token: res.body.tokens.accessToken };
  };
  const host = async (): Promise<TestUser> => {
    const u = await signup();
    await ctx.prisma.liveHost.create({ data: { userId: u.id, source: 'ADMIN' } });
    return u;
  };
  const goLive = async (u: TestUser, body: object): Promise<string> => {
    // Distinct start times, so `new` and the score ties have a known order.
    clock.advance(1);
    const res = await ctx.http
      .post('/api/v1/live/rooms')
      .set(auth(u))
      .send({ title: 'Hub', ...body });
    expect(res.status).toBe(201);
    expect(res.body.score).toBe(0);
    return res.body.id as string;
  };
  const end = async (roomId: string, u: TestUser) => {
    const res = await ctx.http.post(`/api/v1/live/rooms/${roomId}/end`).set(auth(u));
    expect(res.status).toBe(200);
    expectContract(res, 'endLiveRoom');
    return res;
  };
  const tap = async (roomId: string, u: TestUser, count: number) => {
    clock.advance(10);
    const res = await ctx.http.post(`/api/v1/live/rooms/${roomId}/taps`).set(auth(u)).send({ count });
    expect(res.status).toBe(200);
    return res.body as { accepted: number };
  };
  const list = async (query: string, u?: TestUser) => {
    const req = ctx.http.get(`/api/v1/live/rooms?${query}`);
    if (u) void req.set(auth(u));
    const res = await req;
    expectContract(res, 'listLiveRooms');
    return res;
  };
  const ids = async (query: string, u?: TestUser): Promise<string[]> => {
    const res = await list(query, u);
    expect(res.status).toBe(200);
    return (res.body.data as { id: string }[]).map((r) => r.id);
  };

  beforeAll(async () => {
    ctx = await createTestApp({ LIVE_HOSTING_ENABLED: 'true', LIVE_HEARTBEAT_STALE_SECONDS: '3600' }, [
      { token: Clock, value: clock },
      { token: LIVE_MEDIA_PROVIDER, value: media },
    ]);
  });
  afterAll(async () => ctx?.close());
  beforeEach(async () => {
    // Every test starts with nobody live.
    await ctx.prisma.liveRoom.updateMany({
      where: { status: 'LIVE' },
      data: { status: 'ENDED', endReason: 'ADMIN', endedAt: clock.now() },
    });
  });

  it('kind=audio lists only voice rooms; kind=video lists solo, multi and PK lives; no kind lists all', async () => {
    const [h1, h2, h3, h4] = [await host(), await host(), await host(), await host()];
    const solo = await goLive(h1, {});
    const audio = await goLive(h2, { mode: 'AUDIO', seatCount: 10 });
    const multi = await goLive(h3, { mode: 'MULTI', seatCount: 4 });
    const pk = await goLive(h4, {});
    // PK has no start route yet (a battle turns a live into PK); it is a video live.
    await ctx.prisma.liveRoom.update({ where: { id: pk }, data: { mode: 'PK' } });
    const viewer = await signup();

    for (const tab of ['popular', 'new'] as const) {
      expect(await ids(`tab=${tab}&kind=audio`)).toEqual([audio]);
      expect(await ids(`tab=${tab}&kind=video`)).toEqual([pk, multi, solo]);
      expect(await ids(`tab=${tab}`)).toEqual([pk, multi, audio, solo]);
      expect(await ids(`tab=${tab}&kind=video`, viewer)).toEqual([pk, multi, solo]);
    }

    // Following: the same filter over the hosts the caller follows.
    for (const h of [h1, h2]) {
      const res = await ctx.http.put(`/api/v1/users/${await usernameOf(h)}/follow`).set(auth(viewer));
      expect([200, 201]).toContain(res.status);
    }
    expect(await ids('tab=following&kind=audio', viewer)).toEqual([audio]);
    expect(await ids('tab=following&kind=video', viewer)).toEqual([solo]);
    expect(await ids('tab=following', viewer)).toEqual([audio, solo]);

    // The listed rooms carry their mode, so the filter is checkable by the client.
    const res = await list('tab=popular&kind=video');
    expect((res.body.data as { mode: string }[]).map((r) => r.mode).sort()).toEqual(['MULTI', 'PK', 'SOLO']);
  });

  it('kind combines with category and a cursor is bound to it', async () => {
    const category = await ctx.prisma.liveCategory.create({
      data: { slug: `kind-${Date.now().toString(36)}`, nameAr: 'بودكاست', nameEn: 'Podcast' },
    });
    const hosts = [await host(), await host(), await host()];
    const a1 = await goLive(hosts[0]!, { mode: 'AUDIO', seatCount: 5, categorySlug: category.slug });
    const a2 = await goLive(hosts[1]!, { mode: 'AUDIO', seatCount: 5, categorySlug: category.slug });
    await goLive(hosts[2]!, { categorySlug: category.slug });

    // A "podcast" category is just a category: its voice rooms are audio.
    expect(await ids(`tab=popular&category=${category.slug}&kind=audio`)).toEqual([a2, a1]);

    const first = await list(`tab=new&kind=audio&limit=1`);
    expect(first.status).toBe(200);
    expect(first.body.data.map((r: { id: string }) => r.id)).toEqual([a2]);
    expect(first.body.page.hasMore).toBe(true);
    const cursor = encodeURIComponent(first.body.page.nextCursor as string);

    const second = await list(`tab=new&kind=audio&limit=1&cursor=${cursor}`);
    expect(second.status).toBe(200);
    expect(second.body.data.map((r: { id: string }) => r.id)).toEqual([a1]);
    expect(second.body.page).toEqual({ nextCursor: null, hasMore: false });

    for (const other of ['tab=new&kind=video', 'tab=new']) {
      const res = await list(`${other}&limit=1&cursor=${cursor}`);
      expect(res.status).toBe(400);
      expect(res.body.error.details).toEqual([{ field: 'cursor', issue: 'invalid_value' }]);
    }
    // A cursor issued without a kind is not valid with one.
    const plain = await list('tab=new&limit=1');
    const plainCursor = encodeURIComponent(plain.body.page.nextCursor as string);
    expect((await list(`tab=new&limit=1&cursor=${plainCursor}`)).status).toBe(200);
    expect((await list(`tab=new&kind=audio&limit=1&cursor=${plainCursor}`)).status).toBe(400);
  });

  it('rejects an unknown kind (podcast is not a kind: it is a voice room)', async () => {
    for (const bad of ['podcast', 'AUDIO', 'all', '']) {
      const res = await list(`tab=popular&kind=${bad}`);
      expect(res.status).toBe(400);
      expect(res.body.error.code).toBe('VALIDATION_FAILED');
      expect(res.body.error.details).toEqual([expect.objectContaining({ field: 'kind' })]);
    }
  });

  it('the ranking belongs to one live: ending it drops the host from the hub, the next live starts at 0', async () => {
    const top = await host();
    const other = await host();
    const fans = [await signup(), await signup(), await signup()];

    // A persistent-looking voice room: the same host, mode and seats, live twice.
    const first = await goLive(top, { mode: 'AUDIO', seatCount: 10 });
    const rival = await goLive(other, { mode: 'AUDIO', seatCount: 10 });
    for (const fan of fans) expect((await tap(first, fan, 10)).accepted).toBe(10);
    expect((await tap(rival, fans[0]!, 3)).accepted).toBe(3);

    expect(await ids('tab=popular&kind=audio')).toEqual([first, rival]);
    const ranked = await list('tab=popular&kind=audio');
    expect(ranked.body.data.map((r: { score: number }) => r.score)).toEqual([30, 3]);

    // The host ends the live: the room leaves the hub at once; the rival leads.
    const ended = await end(first, top);
    expect(ended.body).toMatchObject({ status: 'ENDED', endReason: 'HOST_ENDED', score: 30 });
    expect(await ids('tab=popular&kind=audio')).toEqual([rival]);
    expect(await ids('tab=popular')).toEqual([rival]);

    // Going live again is a new room that starts at 0 and ranks below the rival.
    const again = await goLive(top, { mode: 'AUDIO', seatCount: 10 });
    expect(again).not.toBe(first);
    const hub = await list('tab=popular&kind=audio');
    expect(hub.body.data.map((r: { id: string; score: number }) => [r.id, r.score])).toEqual([
      [rival, 3],
      [again, 0],
    ]);
    const detail = await ctx.http.get(`/api/v1/live/rooms/${again}`);
    expect(detail.status).toBe(200);
    expect(detail.body.scoreParts).toEqual({ total: 0, tapPoints: 0, supportPoints: 0 });

    // The ended room keeps its own final score (history), and only there.
    const old = await ctx.http.get(`/api/v1/live/rooms/${first}`);
    expect(old.body).toMatchObject({ status: 'ENDED', score: 30 });

    // Permanent progress is not reset: the host's charm points from those taps stay.
    const charm = await ctx.prisma.$queryRaw<{ total: bigint | null }[]>`
      SELECT ls.total_points AS total FROM user_level_states ls
        JOIN level_categories lc ON lc.id = ls.category_id
       WHERE lc.code = 'ATTRACTIVENESS' AND ls.user_id = ${top.id}::uuid`;
    const before = charm[0]?.total ?? null;
    await end(again, top);
    const after = await ctx.prisma.$queryRaw<{ total: bigint | null }[]>`
      SELECT ls.total_points AS total FROM user_level_states ls
        JOIN level_categories lc ON lc.id = ls.category_id
       WHERE lc.code = 'ATTRACTIVENESS' AND ls.user_id = ${top.id}::uuid`;
    expect(after[0]?.total ?? null).toEqual(before);
  });

  it('a live that times out also leaves the ranking; the host restarts from 0', async () => {
    const h = await host();
    const fan = await signup();
    const room = await goLive(h, {});
    expect((await tap(room, fan, 10)).accepted).toBe(10);
    expect(await ids('tab=popular&kind=video')).toEqual([room]);

    // No heartbeat for longer than the stale window: hidden at once, ended by the sweeper.
    clock.advance(3601);
    expect(await ids('tab=popular&kind=video')).toEqual([]);
    const next = await goLive(h, {});
    expect(await ids('tab=popular&kind=video')).toEqual([next]);
    const res = await list('tab=popular&kind=video');
    expect(res.body.data[0].score).toBe(0);
    const timedOut = await ctx.prisma.liveRoom.findUniqueOrThrow({ where: { id: room } });
    expect(timedOut.status).toBe('ENDED');
  });

  async function usernameOf(u: TestUser): Promise<string> {
    const p = await ctx.prisma.userProfile.findUniqueOrThrow({ where: { userId: u.id } });
    return p.username;
  }
});
