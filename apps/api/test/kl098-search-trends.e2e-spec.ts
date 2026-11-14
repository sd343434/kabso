/**
 * D147 (v1.29-live DRAFT, CONVENTIONS §11.11): search trends end to end — counting submitted
 * searches without storing who searched, the distinct-searcher threshold, tags, hiding, blocked
 * words, the rate limit, and the hashtags of the week.
 */
import { randomUUID } from 'node:crypto';
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';
import { SearchTrendsService } from '../src/modules/posts/search-trends.service.js';
import { expectContract } from './helpers/openapi.js';
import {
  createTestApp,
  registerVerified,
  withMigrationClient,
  type TestContext,
} from './helpers/test-app.js';

interface TestUser {
  readonly id: string;
  readonly username: string;
  readonly token: string;
}

const HOUR = 3600_000;

describe('D147 search trends', () => {
  let ctx: TestContext;
  let trends: SearchTrendsService;
  const run = randomUUID().replace(/-/g, '').slice(0, 8).replace(/\d/g, 'x');
  const auth = (u: TestUser) => ({ Authorization: `Bearer ${u.token}` });
  const signup = async (): Promise<TestUser> => {
    const { res } = await registerVerified(ctx);
    expect(res.status).toBe(201);
    return { id: res.body.user.id, username: res.body.user.username, token: res.body.tokens.accessToken };
  };
  const users: TestUser[] = [];
  const record = (u: TestUser, q: string) => ctx.http.post('/api/v1/search/queries').set(auth(u)).send({ q });
  const trending = async (u: TestUser) => {
    await trends.invalidate();
    const res = await ctx.http.get('/api/v1/search/trending').set(auth(u));
    expect(res.status).toBe(200);
    expectContract(res, 'listTrendingSearches');
    return res.body.data as { term: string; tag: string | null }[];
  };
  /** Stores a term with counts directly (hours ago → searchers), as if searched in the past. */
  const seed = (term: string, firstSeenHoursAgo: number, counts: Record<number, number>) =>
    withMigrationClient(async (c) => {
      const now = Date.now();
      const hour = (h: number) => {
        const d = new Date(now - h * HOUR);
        d.setUTCMinutes(0, 0, 0);
        return d;
      };
      const row = await c.searchTerm.create({
        data: { id: randomUUID(), term, firstSeenAt: new Date(now - firstSeenHoursAgo * HOUR) },
      });
      for (const [h, n] of Object.entries(counts)) {
        await c.searchTermCount.create({ data: { termId: row.id, hour: hour(Number(h)), searchers: n } });
      }
    });

  beforeAll(async () => {
    ctx = await createTestApp();
    trends = ctx.app.get(SearchTrendsService);
    for (let i = 0; i < 6; i++) users.push(await signup());
  });
  afterAll(async () => ctx?.close());
  beforeEach(async () => {
    await withMigrationClient(async (c) => {
      await c.searchTerm.deleteMany({});
      await c.searchBlockedWord.deleteMany({});
    });
  });

  it('counts a term once per person; listed only from 5 different searchers; no user id stored', async () => {
    const term = `rising stars ${run}`;
    const first = await record(users[0]!, `  Rising   STARS ${run} `);
    expect(first.status).toBe(204);
    expectContract(first, 'recordSearchQuery');
    // The same person again (another spelling of the same term) does not count twice.
    expect((await record(users[0]!, `#rising stars ${run}`)).status).toBe(204);
    for (const u of users.slice(1, 4)) expect((await record(u, term)).status).toBe(204);
    expect(await trending(users[5]!)).toEqual([]);

    expect((await record(users[4]!, term)).status).toBe(204);
    expect(await trending(users[5]!)).toEqual([{ term, tag: 'NEW' }]);

    // Privacy: only the term and hourly counts; nothing that names a searcher.
    const stored = await withMigrationClient(async (c) => ({
      terms: await c.searchTerm.findMany(),
      counts: await c.searchTermCount.findMany(),
    }));
    expect(stored.terms).toHaveLength(1);
    expect(stored.counts.reduce((n, r) => n + r.searchers, 0)).toBe(5);
    const dump = JSON.stringify(stored);
    for (const u of users) {
      expect(dump).not.toContain(u.id);
      expect(dump).not.toContain(u.username);
    }
  });

  it('accepts but never counts identifying or too-short searches', async () => {
    for (const q of ['a', '0791234567', 'room 123456789', 'me@example.com', 'https://x.y', '12']) {
      const res = await record(users[0]!, q);
      expect(res.status).toBe(204);
    }
    expect(await withMigrationClient((c) => c.searchTerm.count())).toBe(0);
  });

  it('validates the body and needs a token', async () => {
    for (const body of [{}, { q: '' }, { q: 'x'.repeat(65) }, { q: 'ok', extra: 1 }, { q: 5 }]) {
      const res = await ctx.http.post('/api/v1/search/queries').set(auth(users[0]!)).send(body);
      expect(res.status).toBe(400);
      expectContract(res, 'recordSearchQuery');
    }
    const anon = await ctx.http.post('/api/v1/search/queries').send({ q: 'hello' });
    expect(anon.status).toBe(401);
    expect((await ctx.http.get('/api/v1/search/trending')).status).toBe(401);
    expect((await ctx.http.get('/api/v1/search/trending-hashtags')).status).toBe(401);
  });

  it('ranks by 7-day searchers, tags TRENDING / NEW / none, lists at most 6', async () => {
    // Rising: 6 in the last 24 h, 3 the day before (old term) → TRENDING.
    await seed(`live pk ${run}`, 200, { 1: 4, 5: 2, 30: 3 });
    // Steady: 2 today, 3 the day before → no tag; most searchers overall.
    await seed(`baddies ${run}`, 200, { 2: 2, 30: 3, 100: 10 });
    // New today.
    await seed(`makeup show ${run}`, 3, { 1: 5 });
    // Below the threshold, and counts older than 7 days do not count.
    await seed(`rare ${run}`, 300, { 2: 4, 200: 50 });
    for (let i = 0; i < 4; i++) await seed(`filler ${String(i)} ${run}`, 200, { 50: 5 });
    const list = await trending(users[0]!);
    expect(list).toHaveLength(6);
    // Ties on 7-day searchers go to more searchers in the last 24 h, then the term.
    expect(list).toEqual([
      { term: `baddies ${run}`, tag: null },
      { term: `live pk ${run}`, tag: 'TRENDING' },
      { term: `makeup show ${run}`, tag: 'NEW' },
      { term: `filler 0 ${run}`, tag: null },
      { term: `filler 1 ${run}`, tag: null },
      { term: `filler 2 ${run}`, tag: null },
    ]);
  });

  it('never lists a hidden term or one with a blocked word (Arabic folded)', async () => {
    await seed(`gorgeous ${run}`, 200, { 1: 9 });
    await seed(`viral moves ${run}`, 200, { 1: 8 });
    await seed(`تعارف عربي ${run}`, 200, { 1: 7 });
    expect((await trending(users[0]!)).map((t) => t.term)).toHaveLength(3);
    await withMigrationClient(async (c) => {
      await c.searchTerm.update({ where: { term: `gorgeous ${run}` }, data: { hiddenAt: new Date() } });
      await c.searchBlockedWord.create({ data: { word: 'تعارف' } });
    });
    expect(await trending(users[0]!)).toEqual([{ term: `viral moves ${run}`, tag: 'TRENDING' }]);
    // A hidden term is still counted (so unhiding restores it), never listed meanwhile.
    expect((await record(users[1]!, `gorgeous ${run}`)).status).toBe(204);
    expect((await trending(users[0]!)).map((t) => t.term)).not.toContain(`gorgeous ${run}`);
  });

  it('the sweeper drops counts older than 14 days and terms left without counts', async () => {
    await seed(`ancient ${run}`, 24 * 30, { [24 * 20]: 7 });
    await seed(`recent ${run}`, 24 * 30, { [24 * 20]: 7, 3: 1 });
    const out = await trends.sweep();
    expect(out).toEqual({ counts: 2, terms: 1 });
    const left = await withMigrationClient((c) => c.searchTerm.findMany({ select: { term: true } }));
    expect(left.map((t) => t.term)).toEqual([`recent ${run}`]);
  });

  describe('hashtags of the week', () => {
    const post = async (u: TestUser, text: string): Promise<string> => {
      const res = await ctx.http
        .post('/api/v1/posts')
        .set(auth(u))
        .set('Idempotency-Key', randomUUID())
        .send({ text });
      expect(res.status).toBe(201);
      return res.body.id as string;
    };
    const tags = async (u: TestUser, query = '') => {
      const res = await ctx.http.get(`/api/v1/search/trending-hashtags${query}`).set(auth(u));
      expect(res.status).toBe(200);
      expectContract(res, 'listTrendingHashtags');
      return res.body.data as { tag: string; postCount: number }[];
    };

    it('3+ visible posts by 2+ authors in 7 days, most posts first; blocks, age and words count', async () => {
      const [a, b, c, viewer] = [await signup(), await signup(), await signup(), await signup()];
      const hot = `hot${run}`;
      const warm = `warm${run}`;
      const solo = `solo${run}`;
      const old = `old${run}`;
      for (const u of [a, a, b, c]) await post(u, `fun #${hot}`);
      for (const u of [a, b, b]) await post(u, `nice #${warm}`);
      for (let i = 0; i < 3; i++) await post(a, `mine #${solo}`);
      const oldIds = [await post(a, `x #${old}`), await post(b, `y #${old}`), await post(c, `z #${old}`)];
      await withMigrationClient((m) =>
        m.post.updateMany({
          where: { id: { in: oldIds } },
          data: { publishedAt: new Date(Date.now() - 8 * 24 * HOUR) },
        }),
      );

      const list = await tags(viewer);
      expect(list.filter((t) => t.tag.endsWith(run))).toEqual([
        { tag: hot, postCount: 4 },
        { tag: warm, postCount: 3 },
      ]);
      expect((await tags(viewer, '?limit=1')).length).toBe(1);

      // The viewer blocks b: warm keeps 1 post of a → gone; hot keeps 3 posts by a and c.
      expect((await ctx.http.put(`/api/v1/users/${b.username}/block`).set(auth(viewer))).status).toBe(200);
      expect((await tags(viewer)).filter((t) => t.tag.endsWith(run))).toEqual([{ tag: hot, postCount: 3 }]);

      await withMigrationClient((m) => m.searchBlockedWord.create({ data: { word: hot } }));
      expect((await tags(viewer)).filter((t) => t.tag.endsWith(run))).toEqual([]);
    });

    it('validates limit', async () => {
      for (const q of ['?limit=0', '?limit=21', '?limit=x', '?foo=1']) {
        const res = await ctx.http.get(`/api/v1/search/trending-hashtags${q}`).set(auth(users[0]!));
        expect(res.status).toBe(400);
        expectContract(res, 'listTrendingHashtags');
      }
    });
  });
});

describe('D147 search record rate limit', () => {
  let ctx: TestContext;
  beforeAll(async () => {
    ctx = await createTestApp({ RATE_LIMIT_SEARCH_RECORD_USER: '2/3600' });
  });
  afterAll(async () => ctx?.close());

  it('120 / hour per user by default; here 2, then 429', async () => {
    const { res } = await registerVerified(ctx);
    const h = { Authorization: `Bearer ${res.body.tokens.accessToken as string}` };
    expect((await ctx.http.post('/api/v1/search/queries').set(h).send({ q: 'one' })).status).toBe(204);
    expect((await ctx.http.post('/api/v1/search/queries').set(h).send({ q: 'two' })).status).toBe(204);
    const third = await ctx.http.post('/api/v1/search/queries').set(h).send({ q: 'three' });
    expect(third.status).toBe(429);
    expectContract(third, 'recordSearchQuery');
  });
});
