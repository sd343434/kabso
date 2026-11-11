/**
 * D342 (owner 2026-11-09: «ازل فلاتر بث صوتي بث بوكاست و بث متعدد … ان يكونو بنفس الصف لكن ميز كل واحده بهم»):
 * the party page «الحفلة» shows every party kind in one list — `GET /live/rooms?kind=party_all` (v1.107-live,
 * CONVENTIONS §10.141) = AUDIO, PODCAST and MULTI, server-side, in the tab's own order and paged by one cursor, so the
 * app never merges three paged lists. `party` (AUDIO and MULTI) keeps its meaning.
 * v1.115-live (D368, §10.161): `party_all` lists the AUDIO podcasts only — a live video podcast is the main hub's.
 * v1.116-live (D369, §10.162): MULTI is retired — a (legacy) MULTI room is in no list; `party` = AUDIO.
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

describe('D342 the party page: one mixed list of its kinds', { timeout: 240_000 }, () => {
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
  let hosts: TestUser[] = [];
  /** A live of [mode] whose cherries (the popular order) and feature rank are [score]. */
  const goLive = async (mode: Mode, score: number, country = 'SA'): Promise<string> => {
    const u = await signup(country);
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
      .send({ title: 'Party', ...body });
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    const id = res.body.id as string;
    await ctx.prisma.liveRoom.update({
      where: { id },
      data: {
        score: BigInt(score),
        cherries: BigInt(score),
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
  const rows = async (query: string, u: TestUser) =>
    (await list(query, u)).body.data as { id: string; mode: string }[];
  const ids = async (query: string, u: TestUser): Promise<string[]> =>
    (await rows(query, u)).map((r) => r.id);
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

  it('kind=party_all lists AUDIO and the audio PODCASTs together in each filter’s own order, the same over limit=1 pages', async () => {
    const r = {
      solo: await goLive('SOLO', 100),
      audio: await goLive('AUDIO', 90),
      pk: await goLive('PK', 85),
      podcast: await goLive('PODCAST', 80),
      vpodcast: await goLive('VPODCAST', 75),
      multi: await goLive('MULTI', 70),
      audio2: await goLive('AUDIO', 60),
      podcast2: await goLive('PODCAST', 50),
      audioJo: await goLive('AUDIO', 45, 'JO'),
      multiJo: await goLive('MULTI', 40, 'JO'),
    };
    const viewer = await signup('SA');
    for (const h of hosts) {
      const res = await ctx.http.put(`/api/v1/users/${h.username}/follow`).set(auth(viewer));
      expect([200, 201]).toContain(res.status);
    }
    // The main hub's camera lives (D368: the video podcast among them).
    const video = new Set([r.solo, r.pk, r.vpodcast]);

    // Popular: the cherries, every kind mixed (not grouped by kind).
    const popular = await rows('tab=popular&kind=party_all', viewer);
    expect(popular.map((x) => x.id)).toEqual([r.audio, r.podcast, r.audio2, r.podcast2, r.audioJo]);
    expect(popular.map((x) => x.mode)).toEqual(['AUDIO', 'PODCAST', 'AUDIO', 'PODCAST', 'AUDIO']);
    // Explore (`tab=new`): the newest first.
    expect(await ids('tab=new&kind=party_all', viewer)).toEqual([
      r.audioJo,
      r.podcast2,
      r.audio2,
      r.podcast,
      r.audio,
    ]);

    // The party page's four filters (LiveHubSelection.queryOf in the app) and Featured: each is the same filter's
    // full list without the video lives — the same order, one cursor walk.
    const filters = {
      following: 'tab=following',
      nearby: 'tab=popular&scope=nearby',
      country: 'tab=popular&country=JO',
      popular: 'tab=popular',
      featured: 'tab=popular&featured=true',
      explore: 'tab=new',
    };
    for (const [name, base] of Object.entries(filters)) {
      const all = (await ids(base, viewer)).filter((id) => !video.has(id));
      // v1.116-live (D369): the legacy MULTI rooms are in no list, with or without a kind.
      expect(all, name).not.toContain(r.multi);
      expect(all, name).not.toContain(r.multiJo);
      const party = await ids(`${base}&kind=party_all`, viewer);
      expect(party, name).toEqual(all);
      expect(party.length, name).toBeGreaterThan(0);
      for (const id of video) expect(party, `${name} ${id}`).not.toContain(id);
      expect(await pages(`${base}&kind=party_all`, viewer), name).toEqual(party);
    }
    expect(await ids('tab=popular&scope=nearby&kind=party_all', viewer)).not.toContain(r.audioJo);
    expect(await ids('tab=popular&country=JO&kind=party_all', viewer)).toEqual([r.audioJo]);

    // `party` is AUDIO now (D369: no MULTI, no podcast); `podcast` keeps every podcast (older apps); `multi` lists
    // nothing.
    expect(new Set(await ids('tab=popular&kind=party', viewer))).toEqual(
      new Set([r.audio, r.audio2, r.audioJo]),
    );
    expect(await ids('tab=popular&kind=podcast', viewer)).toEqual([r.podcast, r.vpodcast, r.podcast2]);
    expect(await ids('tab=popular&kind=audio', viewer)).toEqual([r.audio, r.audio2, r.audioJo]);
    expect(await ids('tab=popular&kind=multi', viewer)).toEqual([]);
  });

  it('a party_all cursor is bound to it; an unknown kind is refused', async () => {
    await goLive('AUDIO', 3);
    await goLive('PODCAST', 2);
    await goLive('AUDIO', 1);
    const viewer = await signup('SA');
    const first = await list('tab=popular&kind=party_all&limit=1', viewer);
    const cursor = first.body.page.nextCursor as string;
    expect(cursor).toBeTruthy();
    for (const other of ['', '&kind=party', '&kind=audio']) {
      const reused = await ctx.http
        .get(`/api/v1/live/rooms?tab=popular${other}&limit=1&cursor=${encodeURIComponent(cursor)}`)
        .set(auth(viewer));
      expect(reused.status, other).toBe(400);
      expect(reused.body.error.code).toBe('VALIDATION_FAILED');
    }
    const bad = await ctx.http.get('/api/v1/live/rooms?tab=popular&kind=party_mix').set(auth(viewer));
    expectContract(bad, 'listLiveRooms');
    expect(bad.status).toBe(400);
    expect(bad.body.error.details).toEqual(
      expect.arrayContaining([expect.objectContaining({ field: 'kind' })]),
    );
  });
});
