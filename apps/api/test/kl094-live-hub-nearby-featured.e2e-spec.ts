/**
 * D133 (openapi v1.27.1-live DRAFT, CONVENTIONS §10.4, §10.28): the live hub's Nearby, Featured and
 * the kinds `solo`, `multi` and `party` on `GET /live/rooms`, the caller's own country
 * (`PATCH /me` `country`, `Me.country`) and the `feature-admin` CLI, end to end against
 * PostgreSQL + Redis with the API as the DML-only runtime role.
 */
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
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
  readonly username: string;
  readonly email: string;
  readonly token: string;
}

/** Runs `pnpm feature:admin …` as on the server (migration role, a child process). */
function featureAdmin(...args: string[]): { status: number; out: string } {
  try {
    const out = execFileSync('pnpm', ['-s', 'feature:admin', ...args], {
      cwd: fileURLToPath(new URL('..', import.meta.url)),
      env: process.env,
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'pipe'],
    });
    return { status: 0, out };
  } catch (err) {
    const e = err as { status: number; stderr: string };
    return { status: e.status, out: e.stderr };
  }
}

const KINDS = ['audio', 'video', 'solo', 'multi', 'party'] as const;
const TABS = ['popular', 'new', 'following'] as const;

describe('D133 contract coverage', () => {
  it('openapi declares scope, featured and the new kinds on listLiveRooms, and Me.country', () => {
    const op = operations().find((o) => o.operationId === 'listLiveRooms');
    const params = (op?.spec as { parameters?: { name?: string; schema?: unknown }[] }).parameters ?? [];
    expect(params.find((p) => p.name === 'kind')?.schema).toEqual({ type: 'string', enum: [...KINDS] });
    expect(params.find((p) => p.name === 'scope')?.schema).toEqual({ type: 'string', enum: ['nearby'] });
    expect(params.find((p) => p.name === 'featured')?.schema).toEqual({
      type: 'string',
      enum: ['true', 'false'],
    });
  });
});

describe('D133 nearby, featured and kinds', { timeout: 240_000 }, () => {
  const clock = new FakeClock();
  const media = new MemoryLiveMedia();
  let ctx: TestContext;

  const auth = (u: TestUser) => ({ Authorization: `Bearer ${u.token}` });
  const signup = async (country: string | null = null): Promise<TestUser> => {
    const { res, payload } = await registerVerified(ctx);
    expect(res.status).toBe(201);
    const u: TestUser = {
      id: res.body.user.id as string,
      username: res.body.user.username as string,
      email: String(payload.email).toLowerCase(),
      token: res.body.tokens.accessToken as string,
    };
    if (country !== null) await setCountry(u, country);
    return u;
  };
  const setCountry = async (u: TestUser, country: string | null) => {
    const res = await ctx.http.patch('/api/v1/me').set(auth(u)).send({ country });
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    expectContract(res, 'updateMe');
    return res;
  };
  const host = async (country: string | null): Promise<TestUser> => {
    const u = await signup(country);
    await ctx.prisma.liveHost.create({ data: { userId: u.id, source: 'ADMIN' } });
    return u;
  };
  const goLive = async (
    u: TestUser,
    mode: 'SOLO' | 'MULTI' | 'AUDIO' | 'PK',
    score: number,
    category?: string,
  ) => {
    clock.advance(1);
    const body =
      mode === 'AUDIO'
        ? { mode: 'AUDIO', seatCount: 10 }
        : mode === 'MULTI'
          ? { mode: 'MULTI', seatCount: 4 }
          : {};
    const res = await ctx.http
      .post('/api/v1/live/rooms')
      .set(auth(u))
      .send({ title: 'Hub', ...body, ...(category ? { categorySlug: category } : {}) });
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    const id = res.body.id as string;
    // PK has no start route yet (a battle turns a live into PK); the score orders `popular`.
    await ctx.prisma.liveRoom.update({
      where: { id },
      data: { score: BigInt(score), ...(mode === 'PK' ? { mode: 'PK' } : {}) },
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
  /** Every page with limit=1, following the cursors. */
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
  const follow = async (viewer: TestUser, h: TestUser) => {
    const res = await ctx.http.put(`/api/v1/users/${h.username}/follow`).set(auth(viewer));
    expect([200, 201]).toContain(res.status);
  };

  beforeAll(async () => {
    ctx = await createTestApp({ LIVE_HOSTING_ENABLED: 'true', LIVE_HEARTBEAT_STALE_SECONDS: '3600' }, [
      { token: Clock, value: clock },
      { token: LIVE_MEDIA_PROVIDER, value: media },
    ]);
    await ctx.prisma.liveCategory.create({ data: { slug: 'music', nameAr: 'موسيقى', nameEn: 'Music' } });
  });
  afterAll(async () => ctx?.close());
  beforeEach(async () => {
    await ctx.prisma.liveRoom.updateMany({
      where: { status: 'LIVE' },
      data: { status: 'ENDED', endReason: 'ADMIN', endedAt: clock.now() },
    });
    await ctx.prisma.liveFeaturedHost.deleteMany({});
  });

  describe('the caller country (PATCH /me country)', () => {
    it('sets, upper-cases, clears and validates it; Me carries it; locale is optional now', async () => {
      const u = await signup();
      const me = await ctx.http.get('/api/v1/me').set(auth(u));
      expect(me.body.country).toBeNull();
      expect((await setCountry(u, 'sa')).body).toMatchObject({ country: 'SA' });
      expect((await ctx.http.get('/api/v1/me').set(auth(u))).body.country).toBe('SA');
      // locale alone still works and keeps the country.
      const locale = await ctx.http.patch('/api/v1/me').set(auth(u)).send({ locale: 'en' });
      expect(locale.body).toMatchObject({ locale: 'en', country: 'SA' });
      expect((await setCountry(u, null)).body.country).toBeNull();
      for (const [body, details] of [
        [{ country: 'ZZ' }, [{ field: 'country', issue: 'invalid_value' }]],
        [{ country: 'QQ' }, [{ field: 'country', issue: 'invalid_value' }]],
        [{ country: 'EU' }, [{ field: 'country', issue: 'invalid_value' }]],
        [{ country: 'XK' }, [{ field: 'country', issue: 'invalid_value' }]],
        [{ country: 'SAU' }, [{ field: 'country', issue: 'invalid_value' }]],
        [{ country: 5 }, [{ field: 'country', issue: 'invalid_type' }]],
        [{}, [{ field: 'body', issue: 'required' }]],
      ] as const) {
        const res = await ctx.http.patch('/api/v1/me').set(auth(u)).send(body);
        expect(res.status, JSON.stringify(body)).toBe(400);
        expectContract(res, 'updateMe');
        expect(res.body.error.details).toEqual(details);
      }
    });
  });

  describe('nearby', () => {
    it('needs a token; a caller without a country gets an honest empty page', async () => {
      const guest = await list('tab=popular&scope=nearby');
      expect(guest.status).toBe(401);
      const h = await host('SA');
      await goLive(h, 'SOLO', 5);
      const u = await signup();
      const res = await list('tab=popular&scope=nearby', u);
      expect(res.status).toBe(200);
      expect(res.body).toEqual({
        data: [],
        page: { nextCursor: null, hasMore: false },
        emptyReason: 'COUNTRY_NOT_SET',
      });
      // Without scope the field is absent (old responses unchanged).
      expect((await list('tab=popular', u)).body).not.toHaveProperty('emptyReason');
      expect((await list('tab=popular&scope=far', u)).status).toBe(400);
    });

    it('lists only rooms of hosts in the caller country, with every tab, kind and category; cursors bind the country', async () => {
      const sa = [await host('SA'), await host('SA'), await host('SA'), await host('SA'), await host('SA')];
      const eg = [await host('EG'), await host('EG')];
      const none = await host(null);
      const r = {
        solo: await goLive(sa[0]!, 'SOLO', 50, 'music'),
        pk: await goLive(sa[1]!, 'PK', 40),
        multi: await goLive(sa[2]!, 'MULTI', 30, 'music'),
        audio: await goLive(sa[3]!, 'AUDIO', 20),
        audio2: await goLive(sa[4]!, 'AUDIO', 10, 'music'),
        egSolo: await goLive(eg[0]!, 'SOLO', 100),
        egAudio: await goLive(eg[1]!, 'AUDIO', 90),
        noneSolo: await goLive(none, 'SOLO', 80),
      };
      const viewer = await signup('SA');
      for (const h of [sa[0]!, sa[3]!, eg[0]!]) await follow(viewer, h);

      const nearbyAll = [r.solo, r.pk, r.multi, r.audio, r.audio2];
      const byKind: Record<(typeof KINDS)[number], string[]> = {
        audio: [r.audio, r.audio2],
        video: [r.solo, r.pk, r.multi],
        solo: [r.solo, r.pk],
        multi: [r.multi],
        party: [r.multi, r.audio, r.audio2],
      };
      const newest = (list: string[]) => nearbyAll.filter((id) => list.includes(id)).reverse();
      const followed = [r.solo, r.audio];
      const music = [r.solo, r.multi, r.audio2];

      const res = await list('tab=popular&scope=nearby', viewer);
      expect(res.body.emptyReason).toBeNull();
      expect(await ids('tab=popular&scope=nearby', viewer)).toEqual(nearbyAll);
      expect(await ids('tab=new&scope=nearby', viewer)).toEqual(newest(nearbyAll));
      expect(await ids('tab=following&scope=nearby', viewer)).toEqual(newest(followed));
      for (const kind of KINDS) {
        expect(await ids(`tab=popular&scope=nearby&kind=${kind}`, viewer)).toEqual(byKind[kind]);
        expect(await ids(`tab=new&scope=nearby&kind=${kind}`, viewer)).toEqual(newest(byKind[kind]));
        expect(await ids(`tab=following&scope=nearby&kind=${kind}`, viewer)).toEqual(
          newest(byKind[kind].filter((id) => followed.includes(id))),
        );
        expect(await ids(`tab=popular&scope=nearby&kind=${kind}&category=music`, viewer)).toEqual(
          byKind[kind].filter((id) => music.includes(id)),
        );
        expect(await pages(`tab=popular&scope=nearby&kind=${kind}`, viewer)).toEqual(byKind[kind]);
      }
      // Without nearby every country is listed.
      expect(await ids('tab=popular', viewer)).toEqual([r.egSolo, r.egAudio, r.noneSolo, ...nearbyAll]);

      // A cursor binds the country: after the caller moves to EG it is refused.
      const first = await list('tab=popular&scope=nearby&limit=1', viewer);
      const cursor = first.body.page.nextCursor as string;
      expect(cursor).toBeTruthy();
      await setCountry(viewer, 'EG');
      const stale = await list(
        `tab=popular&scope=nearby&limit=1&cursor=${encodeURIComponent(cursor)}`,
        viewer,
      );
      expect(stale.status).toBe(400);
      expect(stale.body.error.details).toEqual([{ field: 'cursor', issue: 'invalid_value' }]);
      expect(await ids('tab=popular&scope=nearby', viewer)).toEqual([r.egSolo, r.egAudio]);
      // …and a nearby cursor is not a cursor of the plain list.
      expect((await list(`tab=popular&limit=1&cursor=${encodeURIComponent(cursor)}`, viewer)).status).toBe(
        400,
      );
    });
  });

  describe('featured', () => {
    it('feature-admin add / remove / list, audited; featured rooms by rank, then popular, on every tab and kind', async () => {
      const [a, b, c, d, e] = [
        await host('SA'),
        await host('SA'),
        await host('EG'),
        await host(null),
        await host(null),
      ];
      const r = {
        a: await goLive(a, 'SOLO', 10, 'music'),
        b: await goLive(b, 'AUDIO', 99),
        c: await goLive(c, 'MULTI', 50, 'music'),
        d: await goLive(d, 'PK', 70),
        e: await goLive(e, 'SOLO', 1_000),
      };
      expect(featureAdmin('add', '--user', a.email, '--rank', '1')).toEqual({
        status: 0,
        out: `+@${a.username} featured (rank 1, until none).\n`,
      });
      expect(featureAdmin('add', '--user', b.username, '--rank', '5').status).toBe(0);
      expect(featureAdmin('add', '--user', `@${c.username}`, '--rank', '5').status).toBe(0);
      const until = new Date(clock.now().getTime() + 3_600_000).toISOString();
      expect(featureAdmin('add', '--user', d.username, '--until', until).status).toBe(0); // rank 100
      // Unchanged → says so; bad input → exit 1.
      expect(featureAdmin('add', '--user', a.username, '--rank', '1')).toEqual({
        status: 0,
        out: `@${a.username} is already featured like that; nothing changed.\n`,
      });
      expect(featureAdmin('add', '--user', 'nobody_here').status).toBe(1);
      expect(featureAdmin('add', '--user', a.username, '--rank', '-1').status).toBe(1);
      expect(featureAdmin('add', '--user', a.username, '--rank', '1000001').status).toBe(1);
      expect(featureAdmin('add', '--user', a.username, '--until', '2026-11-01').status).toBe(1);
      expect(featureAdmin('remove', '--user', a.username, '--rank', '1').status).toBe(1);
      expect(featureAdmin('add').status).toBe(1);

      const viewer = await signup('SA');
      for (const h of [a, c]) await follow(viewer, h);
      // Rank 1, then rank 5 by score (b 99 > c 50), then rank 100; e is not featured.
      const featured = [r.a, r.b, r.c, r.d];
      for (const tab of ['popular', 'new'] as const) {
        expect(await ids(`tab=${tab}&featured=true`)).toEqual(featured);
        expect(await ids(`tab=${tab}&featured=true`, viewer)).toEqual(featured);
        expect(await pages(`tab=${tab}&featured=true`, viewer)).toEqual(featured);
        expect(await ids(`tab=${tab}&featured=false`)).toContain(r.e);
      }
      expect(await ids('tab=following&featured=true', viewer)).toEqual([r.a, r.c]);
      const byKind: Record<(typeof KINDS)[number], string[]> = {
        audio: [r.b],
        video: [r.a, r.c, r.d],
        solo: [r.a, r.d],
        multi: [r.c],
        party: [r.b, r.c],
      };
      for (const kind of KINDS) {
        for (const tab of TABS) {
          const want =
            tab === 'following' ? byKind[kind].filter((id) => [r.a, r.c].includes(id)) : byKind[kind];
          expect(await ids(`tab=${tab}&featured=true&kind=${kind}`, viewer), `${tab} ${kind}`).toEqual(want);
          expect(await pages(`tab=${tab}&featured=true&kind=${kind}`, viewer)).toEqual(want);
        }
        expect(await ids(`tab=popular&featured=true&kind=${kind}&category=music`, viewer)).toEqual(
          byKind[kind].filter((id) => [r.a, r.c].includes(id)),
        );
        // Featured and nearby together (viewer in SA: a and b).
        expect(await ids(`tab=popular&featured=true&scope=nearby&kind=${kind}`, viewer)).toEqual(
          byKind[kind].filter((id) => [r.a, r.b].includes(id)),
        );
      }
      expect((await list('tab=popular&featured=yes')).status).toBe(400);

      // A featured cursor is bound to featured.
      const first = await list('tab=popular&featured=true&limit=1');
      const cursor = encodeURIComponent(first.body.page.nextCursor as string);
      expect((await list(`tab=popular&limit=1&cursor=${cursor}`)).status).toBe(400);
      expect((await list(`tab=popular&featured=true&limit=1&cursor=${cursor}`)).body.data[0].id).toBe(r.b);

      // `until` passes: d drops out. Changing a rank re-orders; remove drops the host.
      clock.advance(3_601);
      await ctx.prisma.liveRoom.updateMany({
        where: { status: 'LIVE' },
        data: { lastHeartbeatAt: clock.now() },
      });
      expect(await ids('tab=popular&featured=true')).toEqual([r.a, r.b, r.c]);
      expect(featureAdmin('add', '--user', c.username, '--rank', '0').status).toBe(0);
      expect(await ids('tab=popular&featured=true')).toEqual([r.c, r.a, r.b]);
      expect(featureAdmin('remove', '--user', a.email)).toEqual({
        status: 0,
        out: `-@${a.username} is no longer featured.\n`,
      });
      expect(featureAdmin('remove', '--user', a.email)).toEqual({
        status: 0,
        out: `@${a.username} is not featured; nothing changed.\n`,
      });
      expect(await ids('tab=popular&featured=true')).toEqual([r.c, r.b]);

      // An end in the past: listed with `-`, never in the hub (the CLI uses the real time).
      expect(featureAdmin('add', '--user', e.username, '--until', '2001-01-01T00:00:00Z').status).toBe(0);
      expect(await ids('tab=popular&featured=true')).toEqual([r.c, r.b]);
      const listed = featureAdmin('list');
      expect(listed.status).toBe(0);
      expect(listed.out.split('\n').filter(Boolean)).toEqual([
        `  0 @${c.username} until=none`,
        `  5 @${b.username} until=none`,
        `  100 @${d.username} until=${until}`,
        `- 100 @${e.username} until=2001-01-01T00:00:00.000Z`,
      ]);

      const audits = await ctx.prisma.auditLog.findMany({
        where: {
          action: { in: ['live.feature.add', 'live.feature.remove'] },
          targetId: { in: [a.id, c.id] },
        },
        orderBy: { createdAt: 'asc' },
      });
      expect(audits.map((x) => [x.action, x.targetId, x.metadata])).toEqual([
        ['live.feature.add', a.id, { before: null, after: { rank: 1, until: null }, via: 'cli' }],
        ['live.feature.add', c.id, { before: null, after: { rank: 5, until: null }, via: 'cli' }],
        [
          'live.feature.add',
          c.id,
          { before: { rank: 5, until: null }, after: { rank: 0, until: null }, via: 'cli' },
        ],
        ['live.feature.remove', a.id, { before: { rank: 1, until: null }, via: 'cli' }],
      ]);
    });
  });

  describe('kinds', () => {
    it('solo, multi and party filter every tab, with and without a category; unknown kinds → 400', async () => {
      const hs = [await host(null), await host(null), await host(null), await host(null)];
      const r = {
        solo: await goLive(hs[0]!, 'SOLO', 4, 'music'),
        pk: await goLive(hs[1]!, 'PK', 3),
        multi: await goLive(hs[2]!, 'MULTI', 2, 'music'),
        audio: await goLive(hs[3]!, 'AUDIO', 1),
      };
      const viewer = await signup();
      for (const h of hs) await follow(viewer, h);
      const want: Record<(typeof KINDS)[number], string[]> = {
        audio: [r.audio],
        video: [r.solo, r.pk, r.multi],
        solo: [r.solo, r.pk],
        multi: [r.multi],
        party: [r.multi, r.audio],
      };
      const order = [r.solo, r.pk, r.multi, r.audio];
      for (const kind of KINDS) {
        expect(await ids(`tab=popular&kind=${kind}`)).toEqual(want[kind]);
        const byNew = order.filter((id) => want[kind].includes(id)).reverse();
        expect(await ids(`tab=new&kind=${kind}`)).toEqual(byNew);
        expect(await ids(`tab=following&kind=${kind}`, viewer)).toEqual(byNew);
        expect(await ids(`tab=popular&kind=${kind}&category=music`)).toEqual(
          want[kind].filter((id) => [r.solo, r.multi].includes(id)),
        );
        expect(await pages(`tab=popular&kind=${kind}`)).toEqual(want[kind]);
        // A cursor of one kind is refused for another.
        const first = await list(`tab=popular&kind=${kind}&limit=1`);
        const next = first.body.page.nextCursor as string | null;
        if (next) {
          const other = kind === 'solo' ? 'multi' : 'solo';
          expect(
            (await list(`tab=popular&kind=${other}&limit=1&cursor=${encodeURIComponent(next)}`)).status,
          ).toBe(400);
        }
      }
      for (const bad of ['pk', 'AUDIO', 'podcast', '']) {
        const res = await list(`tab=popular&kind=${bad}`);
        expect(res.status, bad).toBe(400);
        expect(res.body.error.details[0].field).toBe('kind');
      }
    });
  });
});
