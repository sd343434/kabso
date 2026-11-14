/**
 * D240 (openapi v1.53-live DRAFT, CONVENTIONS §10.83): «القريبة» lists the lives of a country the
 * viewer chooses — `country` on `GET /live/rooms`, the host's profile country — in the live hub
 * (`kind=solo`, D239) and the party page (its kind). End to end against PostgreSQL + Redis.
 */
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';
import { Clock } from '../src/common/time/clock.js';
import { LIVE_MEDIA_PROVIDER } from '../src/modules/live/media/live-media.provider.js';
import { MemoryLiveMedia } from './helpers/memory-live-media.js';
import type request from 'supertest';
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
  readonly username: string;
  readonly token: string;
}

type Mode = 'SOLO' | 'PK' | 'MULTI' | 'AUDIO' | 'PODCAST' | 'VPODCAST';

describe('D240 contract coverage', () => {
  it('openapi declares the optional country parameter on listLiveRooms', () => {
    const op = operations().find((o) => o.operationId === 'listLiveRooms');
    const params = (op?.spec as { parameters?: { name?: string; schema?: unknown }[] }).parameters ?? [];
    expect(params.find((p) => p.name === 'country')?.schema).toEqual({
      type: 'string',
      pattern: '^[A-Za-z]{2}$',
    });
  });
});

describe('D240 country on GET /live/rooms', { timeout: 240_000 }, () => {
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
  const hostOf = new Map<string, TestUser>();
  const goLive = async (country: string | null, mode: Mode, score: number): Promise<string> => {
    const u = await signup(country);
    await ctx.prisma.liveHost.create({ data: { userId: u.id, source: 'ADMIN' } });
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
      .send({ title: 'Near', ...body });
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    const id = res.body.id as string;
    hostOf.set(id, u);
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
  const list = async (query: string, u?: TestUser) => {
    const req = ctx.http.get(`/api/v1/live/rooms?${query}`);
    if (u) void req.set(auth(u));
    const res = await req;
    expectContract(res, 'listLiveRooms');
    return res;
  };
  const ids = async (query: string, u?: TestUser): Promise<string[]> => {
    const res = await list(query, u);
    expect(res.status, `${query} ${JSON.stringify(res.body)}`).toBe(200);
    return (res.body.data as { id: string }[]).map((r) => r.id);
  };
  const pages = async (query: string, u?: TestUser): Promise<string[]> => {
    const out: string[] = [];
    let cursor: string | null = null;
    for (let i = 0; i < 50; i += 1) {
      const res = await list(`${query}&limit=1${cursor ? `&cursor=${encodeURIComponent(cursor)}` : ''}`, u);
      expect(res.status, JSON.stringify(res.body)).toBe(200);
      out.push(...(res.body.data as { id: string }[]).map((r) => r.id));
      cursor = res.body.page.nextCursor as string | null;
      if (!cursor) return out;
    }
    throw new Error('too many pages');
  };

  const expectError = (res: request.Response, status: number, code: string, operationId: string) => {
    expectContract(res, operationId);
    expect({ status: res.status, code: res.body.error?.code }).toEqual({ status, code });
  };

  beforeAll(async () => {
    ctx = await createTestApp({ LIVE_HOSTING_ENABLED: 'true', LIVE_HEARTBEAT_STALE_SECONDS: '3600' }, [
      { token: Clock, value: clock },
      { token: LIVE_MEDIA_PROVIDER, value: media },
    ]);
  });
  afterAll(async () => ctx?.close());
  beforeEach(async () => {
    await ctx.prisma.liveRoom.updateMany({
      where: { status: 'LIVE' },
      data: { status: 'ENDED', endReason: 'ADMIN', endedAt: clock.now() },
    });
  });

  it("lists the chosen country's rooms (hosts without a country never), with every kind, tab and cursor", async () => {
    const r = {
      joSolo: await goLive('JO', 'SOLO', 30),
      joPk: await goLive('JO', 'PK', 40),
      joAudio: await goLive('JO', 'AUDIO', 50),
      joPodcast: await goLive('JO', 'PODCAST', 55),
      joMulti: await goLive('JO', 'MULTI', 60),
      joVideoPodcast: await goLive('JO', 'VPODCAST', 65),
      saSolo: await goLive('SA', 'SOLO', 70),
      none: await goLive(null, 'SOLO', 80),
    };
    // A viewer of another country (SA) chooses Jordan; a guest may too; any case.
    const viewer = await signup('SA');
    // v1.116-live (D369): the legacy MULTI is in no list.
    const jo = [r.joSolo, r.joPk, r.joAudio, r.joPodcast, r.joVideoPodcast];
    for (const tab of ['popular', 'new'] as const) {
      expect(new Set(await ids(`tab=${tab}&country=JO`, viewer)), tab).toEqual(new Set(jo));
      expect(new Set(await ids(`tab=${tab}&country=jo`)), `${tab} guest`).toEqual(new Set(jo));
      // The hub (D239: kind=solo) and each party tab.
      // v1.115-live (D368): the video podcast is the hub's, the audio podcast the party page's.
      expect(new Set(await ids(`tab=${tab}&country=JO&kind=solo`, viewer))).toEqual(
        new Set([r.joSolo, r.joPk, r.joVideoPodcast]),
      );
      expect(new Set(await ids(`tab=${tab}&country=JO&kind=party_all`, viewer))).toEqual(
        new Set([r.joAudio, r.joPodcast]),
      );
      expect(await ids(`tab=${tab}&country=JO&kind=audio`, viewer)).toEqual([r.joAudio]);
      expect(new Set(await ids(`tab=${tab}&country=JO&kind=podcast`, viewer))).toEqual(
        new Set([r.joPodcast, r.joVideoPodcast]),
      );
      expect(await ids(`tab=${tab}&country=JO&kind=multi`, viewer)).toEqual([]);
      // The cursor walk is the page.
      expect(await pages(`tab=${tab}&country=JO`, viewer)).toEqual(
        await ids(`tab=${tab}&country=JO`, viewer),
      );
    }
    // A host without a country is never «nearby», whatever is chosen.
    for (const c of ['JO', 'SA', 'EG'])
      expect(await ids(`tab=popular&country=${c}`, viewer)).not.toContain(r.none);
    expect(await ids('tab=popular&country=SA', viewer)).toEqual([r.saSolo]);
    expect(await ids('tab=popular&country=EG', viewer)).toEqual([]);
    // `country` wins over scope=nearby (the caller's SA), no emptyReason.
    const both = await list('tab=popular&scope=nearby&country=JO&kind=solo', viewer);
    expect(both.status).toBe(200);
    expect(new Set((both.body.data as { id: string }[]).map((x) => x.id))).toEqual(
      new Set([r.joSolo, r.joPk, r.joVideoPodcast]),
    );
    expect(both.body.emptyReason).toBeNull();
    // Without a country of their own, a caller still gets the chosen one; scope=nearby alone is honest.
    const stranger = await signup(null);
    expect(await ids('tab=popular&scope=nearby&country=SA', stranger)).toEqual([r.saSolo]);
    const unset = await list('tab=popular&scope=nearby', stranger);
    expect(unset.body.emptyReason).toBe('COUNTRY_NOT_SET');
    // Following combines with it.
    const follower = await signup('SA');
    const f = await ctx.http
      .put(`/api/v1/users/${hostOf.get(r.joSolo)!.username}/follow`)
      .set(auth(follower));
    expect([200, 201]).toContain(f.status);
    expect(await ids('tab=following&country=JO', follower)).toEqual([r.joSolo]);
    expect(await ids('tab=following&country=SA', follower)).toEqual([]);
  });

  it('binds the cursor to the country; validates the code', async () => {
    await goLive('JO', 'SOLO', 1);
    await goLive('JO', 'PK', 2);
    const first = await list('tab=popular&country=JO&limit=1');
    const cursor = first.body.page.nextCursor as string;
    expect(cursor).toBeTruthy();
    for (const other of ['country=SA', '']) {
      const res = await ctx.http.get(
        `/api/v1/live/rooms?tab=popular&limit=1&${other}&cursor=${encodeURIComponent(cursor)}`,
      );
      expectError(res, 400, 'VALIDATION_FAILED', 'listLiveRooms');
    }
    for (const bad of ['J', 'JOR', 'J1', 'ZZ', '']) {
      const res = await ctx.http.get(`/api/v1/live/rooms?tab=popular&country=${bad}`);
      expectError(res, 400, 'VALIDATION_FAILED', 'listLiveRooms');
      expect(res.body.error.details[0].field).toBe('country');
    }
  });
});
