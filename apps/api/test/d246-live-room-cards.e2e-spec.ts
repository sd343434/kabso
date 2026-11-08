/**
 * D246 (openapi v1.58-live DRAFT, CONVENTIONS §10.89): the party page's room cards —
 * `LiveRoomSummary.roomLevel` (the host's charm level), `popular` («رائج»: the first
 * `LIVE_POPULAR_TOP_N` lives of each kind in the popular order) and `hostCountry`. End to end against
 * PostgreSQL + Redis.
 */
import { afterAll, beforeAll, beforeEach, describe, expect, it, vi } from 'vitest';
import { Clock } from '../src/common/time/clock.js';
import { LIVE_MEDIA_PROVIDER } from '../src/modules/live/media/live-media.provider.js';
import { MemoryLiveMedia } from './helpers/memory-live-media.js';
import { expectContract, openapi } from './helpers/openapi.js';
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

interface Card {
  id: string;
  roomLevel?: number | null;
  popular?: boolean;
  hostCountry?: string;
}

type Mode = 'SOLO' | 'PK' | 'MULTI' | 'AUDIO' | 'PODCAST';

describe('D246 contract coverage', () => {
  it('openapi declares roomLevel, popular and hostCountry on LiveRoomSummary', () => {
    const schemas = (openapi as { components: { schemas: Record<string, { properties?: object }> } })
      .components.schemas;
    const props = schemas.LiveRoomSummary?.properties as Record<string, { type?: unknown }>;
    expect(props.roomLevel?.type).toEqual(['integer', 'null']);
    expect(props.popular?.type).toBe('boolean');
    expect(props.hostCountry?.type).toBe('string');
  });
});

describe('D246 room cards on GET /live/rooms', { timeout: 300_000 }, () => {
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
  const goLive = async (mode: Mode, score: number, country: string | null = 'JO'): Promise<string> => {
    const u = await signup(country);
    await ctx.prisma.liveHost.create({ data: { userId: u.id, source: 'ADMIN' } });
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
      .send({ title: 'Card', ...body });
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    const id = res.body.id as string;
    hostOf.set(id, u);
    await setScore(id, score, mode === 'PK');
    return id;
  };
  const setScore = (id: string, score: number, pk = false) =>
    ctx.prisma.liveRoom.update({
      where: { id },
      // v1.86-live (D310): «رائج» follows the popular order, the room cherries; the fixture sets both.
      data: { score: BigInt(score), cherries: BigInt(score), ...(pk ? { mode: 'PK' } : {}) },
    });
  const cards = async (query: string): Promise<Map<string, Card>> => {
    const res = await ctx.http.get(`/api/v1/live/rooms?${query}`);
    expectContract(res, 'listLiveRooms');
    expect(res.status, `${query} ${JSON.stringify(res.body)}`).toBe(200);
    return new Map((res.body.data as Card[]).map((c) => [c.id, c]));
  };
  const popularIds = async (kind: string): Promise<Set<string>> =>
    new Set(
      [...(await cards(`tab=popular&kind=${kind}&limit=50`)).values()]
        .filter((c) => c.popular)
        .map((c) => c.id),
    );

  /** A charm ladder: level 2 at 2 points, level 3 at 5. */
  const publishCharm = async () => {
    const category = await ctx.prisma.levelCategory.create({
      data: {
        code: 'ATTRACTIVENESS',
        nameAr: 'الجاذبية',
        nameEn: 'Charm',
        descriptionAr: 'وصف',
        descriptionEn: 'About',
      },
    });
    const version = await ctx.prisma.levelCategoryVersion.create({
      data: {
        categoryId: category.id,
        versionNumber: 1,
        status: 'PUBLISHED',
        multiplier: '0.1',
        valueUnit: 'COIN',
        publishedAt: clock.now(),
        levels: {
          create: [
            { levelNumber: 1, nameAr: 'بذرة', nameEn: 'Sprout', requiredPoints: 0n },
            { levelNumber: 2, nameAr: 'بذرة', nameEn: 'Sprout', requiredPoints: 2n },
            { levelNumber: 3, nameAr: 'بذرة', nameEn: 'Sprout', requiredPoints: 5n },
          ],
        },
      },
    });
    await ctx.prisma.levelCategory.update({
      where: { id: category.id },
      data: { isEnabled: true, publishedVersionId: version.id },
    });
    return category.id;
  };

  beforeAll(async () => {
    ctx = await createTestApp(
      { LIVE_HOSTING_ENABLED: 'true', LIVE_HEARTBEAT_STALE_SECONDS: '3600', LIVE_POPULAR_TOP_N: '2' },
      [
        { token: Clock, value: clock },
        { token: LIVE_MEDIA_PROVIDER, value: media },
      ],
    );
  });
  afterAll(async () => ctx?.close());
  beforeEach(async () => {
    await ctx.prisma.liveRoom.updateMany({
      where: { status: 'LIVE' },
      data: { status: 'ENDED', endReason: 'ADMIN', endedAt: clock.now() },
    });
  });

  it('popular = the top N of each kind by the popular order, recomputed as scores move', async () => {
    const a = [await goLive('AUDIO', 10), await goLive('AUDIO', 30), await goLive('AUDIO', 20)] as const;
    const p = [await goLive('PODCAST', 5), await goLive('PODCAST', 1), await goLive('PODCAST', 3)] as const;
    const m = [await goLive('MULTI', 100)] as const;
    const v = [await goLive('SOLO', 7), await goLive('PK', 9), await goLive('SOLO', 8)] as const;

    // N = 2 per kind (LIVE_POPULAR_TOP_N): each kind its own top, whatever the other kinds score.
    expect(await popularIds('audio')).toEqual(new Set([a[1], a[2]]));
    expect(await popularIds('podcast')).toEqual(new Set([p[0], p[2]]));
    expect(await popularIds('multi')).toEqual(new Set([m[0]]));
    expect(await popularIds('solo')).toEqual(new Set([v[1], v[2]]));
    // Every listed room carries the boolean; the flag is the same whatever the tab or filter.
    const latest = await cards('tab=new&kind=audio&limit=50');
    expect([...latest.values()].every((c) => typeof c.popular === 'boolean')).toBe(true);
    expect(latest.get(a[0])?.popular).toBe(false);
    expect(latest.get(a[1])?.popular).toBe(true);
    const party = await cards('tab=popular&kind=party&limit=50');
    expect(party.get(m[0])?.popular).toBe(true);
    expect(party.get(a[0])?.popular).toBe(false);

    // Scores move: the third audio room overtakes; the next request says so.
    await setScore(a[0], 99);
    expect(await popularIds('audio')).toEqual(new Set([a[0], a[1]]));
    // An ended room leaves the top: the next one comes in.
    await ctx.prisma.liveRoom.update({
      where: { id: a[0] },
      data: { status: 'ENDED', endReason: 'ADMIN', endedAt: clock.now() },
    });
    expect(await popularIds('audio')).toEqual(new Set([a[1], a[2]]));
    // The room itself says the same.
    const room = await ctx.http.get(`/api/v1/live/rooms/${a[2]}`);
    expectContract(room, 'getLiveRoom');
    expect(room.body.popular).toBe(true);
  });

  it("hostCountry is the host's profile country, absent without one; roomLevel is the charm level", async () => {
    const jo = await goLive('AUDIO', 3, 'JO');
    const none = await goLive('AUDIO', 2, null);
    let list = await cards('tab=popular&kind=audio');
    expect(list.get(jo)?.hostCountry).toBe('JO');
    expect(list.get(none)).toBeDefined();
    expect('hostCountry' in list.get(none)!).toBe(false);
    // No charm ladder yet: null (as on the room).
    expect(list.get(jo)?.roomLevel).toBeNull();

    const categoryId = await publishCharm();
    await ctx.prisma.userLevelState.create({
      data: { userId: hostOf.get(jo)!.id, categoryId, totalPoints: 6n },
    });
    list = await cards('tab=popular&kind=audio');
    expect(list.get(jo)?.roomLevel).toBe(3);
    expect(list.get(none)?.roomLevel).toBe(1);
    // The same as the room's own level.
    const room = await ctx.http.get(`/api/v1/live/rooms/${jo}`);
    expectContract(room, 'getLiveRoom');
    expect(room.body.roomLevel).toBe(3);
    expect(room.body.hostCountry).toBe('JO');
  });

  it('no N+1: one room statement per list page, whatever the number of rooms', async () => {
    for (let i = 0; i < 3; i += 1) await goLive('AUDIO', i);
    const count = async (): Promise<number> => {
      const spy = vi.spyOn(ctx.prisma, '$queryRaw');
      const res = await ctx.http.get('/api/v1/live/rooms?tab=popular&kind=audio&limit=50');
      expect(res.status).toBe(200);
      const n = spy.mock.calls.length;
      spy.mockRestore();
      return n;
    };
    const few = await count();
    for (let i = 0; i < 9; i += 1) await goLive('AUDIO', 10 + i);
    const many = await count();
    expect(many).toBe(few);
    expect(few).toBeGreaterThanOrEqual(1);
    expect(few).toBeLessThanOrEqual(2);
  });
});
