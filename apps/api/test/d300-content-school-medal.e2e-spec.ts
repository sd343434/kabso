/**
 * D300 (owner 2026-11-07: «مدرسة المحتوى» / Content School; contract v1.83-live DRAFT, CONVENTIONS §10.111): the first
 * multi-requirement medal end to end against PostgreSQL + Redis, with the API as the DML-only runtime role.
 *
 * Owner-confirmed rules: content creators only (`creator_members`); followers now, plus all-time likes and views on
 * posts AND reels, from ACTIVE accounts, never self; a level needs ALL THREE of its thresholds; levels never go down
 * (also when the membership ends).
 *
 * - real follows, likes and views through the API feed it; self likes and views and inactive accounts do not;
 * - two of three is not a level; all three is; a jump straight to level 3; the per-level art key everywhere;
 * - the sweeper (and a creator's activation) raise it; a non-creator never; never lowered; kept after a revocation;
 * - `medals-admin backfill` (child process, migration role); wearing it once only; the panel's three thresholds.
 *
 * Large counts are written in bulk (thousands of accounts, follows, likes and view rows, with the posts' counters kept
 * equal to their rows, as the API keeps them).
 */
import { execFileSync } from 'node:child_process';
import { randomUUID } from 'node:crypto';
import { fileURLToPath } from 'node:url';
import { afterAll, beforeAll, describe, expect, it, vi } from 'vitest';
import { CLI_VIA } from '../src/common/audit/admin-actor.js';
import { activateCreatorIn } from '../src/modules/creator/creator-membership.js';
import { LIVE_MEDIA_PROVIDER } from '../src/modules/live/media/live-media.provider.js';
import { raiseMedalLevelsIn } from '../src/modules/medals/medal-awards.js';
import { MedalRequirementsSweeper } from '../src/modules/medals/medal-requirements.sweeper.js';
import { panel, type Admin } from './helpers/admin-panel.js';
import { seedMedalCatalogue } from './helpers/medals.js';
import { MemoryLiveMedia } from './helpers/memory-live-media.js';
import { expectContract } from './helpers/openapi.js';
import { createTestApp, registerVerified, settle, type TestContext } from './helpers/test-app.js';

const ADMIN_KEY = 'admin-totp-test-key-0123456789-abcdefghijklmnop';
const CODE = 'CONTENT_SCHOOL';

interface TestUser {
  readonly id: string;
  readonly username: string;
  readonly token: string;
}

interface Req {
  metric: string;
  value: number;
  next: number | null;
}

interface MedalBody {
  code: string;
  metric: string | null;
  level: number;
  maxLevel: number;
  eligible: boolean;
  levels: {
    level: number;
    threshold: number;
    iconAsset: string | null;
    requirements: { metric: string; threshold: number }[];
  }[];
  progress: { value: number; next: number | null; requirements: Req[] };
  iconAsset: string | null;
  description: string;
}

/** Runs `pnpm medals:admin …` as on the server (migration role, a child process). */
function medalsAdmin(...args: string[]): { status: number; out: string } {
  try {
    const out = execFileSync('pnpm', ['-s', 'medals:admin', ...args], {
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

describe('D300 «مدرسة المحتوى» / Content School', { timeout: 600_000 }, () => {
  const media = new MemoryLiveMedia();
  let ctx: TestContext;
  const p = panel(() => ctx);
  let owner: Admin;

  const auth = (u: TestUser) => ({ Authorization: `Bearer ${u.token}` });
  const signup = async (): Promise<TestUser> => {
    const { res } = await registerVerified(ctx);
    expect(res.status).toBe(201);
    return {
      id: res.body.user.id as string,
      username: res.body.user.username as string,
      token: res.body.tokens.accessToken as string,
    };
  };
  /** The D295 activation every path calls (application, agency), in a real transaction. */
  const makeCreator = async (u: TestUser): Promise<void> => {
    const app = await ctx.prisma.creatorApplication.create({
      data: {
        userId: u.id,
        status: 'APPROVED',
        country: 'SA',
        category: 'VIDEO',
        links: ['https://x.example/creator'],
        decidedAt: new Date(),
      },
    });
    await ctx.prisma.$transaction((tx) =>
      activateCreatorIn(tx, {
        userId: u.id,
        applicationId: app.id,
        now: new Date(),
        by: CLI_VIA,
      }),
    );
  };
  /** A post (or a reel row: the counts read the stored row) by `u` through the API. */
  const post = async (u: TestUser, text = 'content'): Promise<string> => {
    const res = await ctx.http
      .post('/api/v1/posts')
      .set(auth(u))
      .set('Idempotency-Key', randomUUID())
      .send({ text });
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    return res.body.id as string;
  };
  const reel = async (u: TestUser): Promise<string> =>
    (
      await ctx.prisma.post.create({
        data: { authorId: u.id, format: 'REEL', text: `reel ${randomUUID()}`, publishedAt: new Date() },
        select: { id: true },
      })
    ).id;
  /** `n` accounts written in bulk (no profile: they only follow, like and view). */
  const accounts = async (n: number, status: 'ACTIVE' | 'SUSPENDED' = 'ACTIVE'): Promise<string[]> => {
    const tag = randomUUID().slice(0, 8);
    const rows = await ctx.prisma.$queryRaw<{ id: string }[]>`
      INSERT INTO users (id, email, password_hash, status, updated_at)
      SELECT gen_random_uuid(), 'd300-' || ${tag} || '-' || g || '@example.test', 'x', ${status}::user_status, now()
        FROM generate_series(1, ${n}::int) g
      RETURNING id::text AS id`;
    return rows.map((r) => r.id);
  };
  const followAll = async (fans: readonly string[], creator: TestUser) => {
    await ctx.prisma.$executeRaw`
      INSERT INTO follows (follower_id, followee_id)
      SELECT f, ${creator.id}::uuid FROM unnest(${fans}::uuid[]) f`;
  };
  /** Each of `fans` likes each of `posts`; the posts' `like_count` stays equal to their rows. */
  const likeAll = async (fans: readonly string[], posts: readonly string[]) => {
    await ctx.prisma.$executeRaw`
      INSERT INTO post_likes (post_id, user_id)
      SELECT p, f FROM unnest(${posts}::uuid[]) p CROSS JOIN unnest(${fans}::uuid[]) f`;
    await syncCounters(posts);
  };
  /** Each of `fans` has viewed each of `posts` `times` times (§11.4 rows); `view_count` follows. */
  const viewAll = async (fans: readonly string[], posts: readonly string[], times: number) => {
    await ctx.prisma.$executeRaw`
      INSERT INTO post_views (post_id, user_id, viewed_at, counted_views)
      SELECT p, f, now() - interval '2 days', ${times}::int
        FROM unnest(${posts}::uuid[]) p CROSS JOIN unnest(${fans}::uuid[]) f`;
    await syncCounters(posts);
  };
  const syncCounters = async (posts: readonly string[]) => {
    await ctx.prisma.$executeRaw`
      UPDATE posts p SET
        like_count = (SELECT count(*) FROM post_likes l WHERE l.post_id = p.id),
        view_count = (SELECT coalesce(sum(v.counted_views), 0) FROM post_views v WHERE v.post_id = p.id)
       WHERE p.id = ANY(${posts}::uuid[])`;
  };
  const sweep = () => ctx.app.get(MedalRequirementsSweeper).sweep();
  const levelOf = async (u: TestUser): Promise<number | null> =>
    (
      await ctx.prisma.userMedal.findUnique({
        where: { userId_medalCode: { userId: u.id, medalCode: CODE } },
      })
    )?.level ?? null;
  const school = async (u: TestUser, lang = 'en'): Promise<MedalBody> => {
    const res = await ctx.http.get('/api/v1/medals').set(auth(u)).set('Accept-Language', lang);
    expect(res.status).toBe(200);
    expectContract(res, 'listMedals');
    return (res.body.data as MedalBody[]).find((m) => m.code === CODE)!;
  };
  const values = (m: MedalBody) => m.progress.requirements.map((r) => [r.metric, r.value, r.next]);
  const schoolNotes = async (u: TestUser) => {
    await settle(ctx);
    const res = await ctx.http.get('/api/v1/notifications').set(auth(u));
    expect(res.status).toBe(200);
    expectContract(res, 'listNotifications');
    return (res.body.data as { type: string; target: { id: string; medalLevel?: number } | null }[])
      .filter((n) => n.type === 'MEDAL_AWARDED' && n.target?.id === CODE)
      .map((n) => n.target!.medalLevel);
  };

  /**
   * A creator just below level 1 through real API events (two of the three met): 2 000 ACTIVE followers (one through
   * the API), 9 999 likes from others (4 through the API), 21 994 views from others (5 through the API) — plus self
   * likes and views and SUSPENDED accounts' follows, likes and views that must not count.
   */
  let c: TestUser;
  let fanA: TestUser;
  let cPosts: string[];

  beforeAll(async () => {
    vi.useFakeTimers({ toFake: ['Date'], now: p.start() });
    ctx = await createTestApp(
      {
        ADMIN_TOTP_KEY: ADMIN_KEY,
        ADMIN_SESSION_IDLE_SECONDS: '86400',
        ADMIN_SESSION_MAX_SECONDS: '604800',
        RATE_LIMIT_ADMIN_LOGIN_IP: '10000/900',
        RATE_LIMIT_ADMIN_IP: '10000/900',
      },
      [{ token: LIVE_MEDIA_PROVIDER, value: media }],
    );
    await seedMedalCatalogue(ctx.prisma, { keepFirsts: true });
    owner = await p.makeAdmin(['OWNER']);
  });
  afterAll(async () => {
    await ctx?.close();
    vi.useRealTimers();
  });

  it('the medal: four levels with three thresholds each and their own art; creators only', async () => {
    const u = await signup();
    const m = await school(u, 'ar');
    expect(m).toMatchObject({
      metric: 'ALL_REQUIREMENTS',
      level: 0,
      maxLevel: 4,
      eligible: false,
      iconAsset: 'medal_content_school_l1',
      description: 'لصنّاع المحتوى: المتابعون والإعجابات والمشاهدات معاً.',
    });
    expect(
      m.levels.map((l) => [
        l.level,
        l.threshold,
        l.iconAsset,
        l.requirements.map((r) => [r.metric, r.threshold]),
      ]),
    ).toEqual([
      [
        1,
        1,
        'medal_content_school_l1',
        [
          ['CREATOR_FOLLOWERS', 2_000],
          ['CREATOR_LIKES', 10_000],
          ['CREATOR_VIEWS', 20_000],
        ],
      ],
      [
        2,
        2,
        'medal_content_school_l2',
        [
          ['CREATOR_FOLLOWERS', 10_000],
          ['CREATOR_LIKES', 50_000],
          ['CREATOR_VIEWS', 100_000],
        ],
      ],
      [
        3,
        3,
        'medal_content_school_l3',
        [
          ['CREATOR_FOLLOWERS', 100_000],
          ['CREATOR_LIKES', 200_000],
          ['CREATOR_VIEWS', 500_000],
        ],
      ],
      [
        4,
        4,
        'medal_content_school_l4',
        [
          ['CREATOR_FOLLOWERS', 1_000_000],
          ['CREATOR_LIKES', 2_000_000],
          ['CREATOR_VIEWS', 5_000_000],
        ],
      ],
    ]);
    // A non-creator does not progress: zeros against level 1.
    expect(values(m)).toEqual([
      ['CREATOR_FOLLOWERS', 0, 2_000],
      ['CREATOR_LIKES', 0, 10_000],
      ['CREATOR_VIEWS', 0, 20_000],
    ]);
    // Single-metric medals are unchanged: no requirements, always eligible.
    const res = await ctx.http.get('/api/v1/medals').set(auth(u));
    const wealth = (res.body.data as MedalBody[]).find((x) => x.code === 'WEALTH_KINGS')!;
    expect(wealth.eligible).toBe(true);
    // Owner («هذه ميداليات»): both D300 medals sit in the tab of the other medals.
    const all = res.body.data as (MedalBody & { category: string })[];
    expect(
      all.filter((x) => ['WEALTH_KINGS', CODE, 'DARES_PLAYER'].includes(x.code)).map((x) => x.category),
    ).toEqual(['ACHIEVEMENT', 'ACHIEVEMENT', 'ACHIEVEMENT']);
    expect(wealth.progress.requirements).toEqual([]);
    expect(wealth.levels.every((l) => l.requirements.length === 0)).toBe(true);
    expect((await school(u)).description).toBe('For content creators: followers, likes and views together.');
  });

  it('two of three is not level 1; the third through a real API like makes it; self and inactive never count', async () => {
    c = await signup();
    fanA = await signup();
    await makeCreator(c);
    cPosts = [await post(c, 'one'), await post(c, 'two'), await post(c, 'three'), await post(c, 'four')];
    cPosts.push(await reel(c)); // reels count too (owner-confirmed)
    const fans = await accounts(1_999);
    const suspended = await accounts(300, 'SUSPENDED');
    await followAll([...fans, ...suspended], c);
    await likeAll(fans, cPosts); // 9 995
    await likeAll(suspended, cPosts); // never
    await viewAll(fans, cPosts.slice(0, 4), 2); // 15 992
    await viewAll(fans, cPosts.slice(4), 3); // 5 997 on the reel
    await viewAll(suspended, cPosts, 20); // never

    // Real events: fan A follows, likes four of the posts and views all five; the creator likes and views their own.
    const followed = await ctx.http.put(`/api/v1/users/${c.username}/follow`).set(auth(fanA));
    expect(followed.status).toBe(200);
    expect(followed.body.followerCount).toBe(2_000); // the profile's count: ACTIVE followers only
    for (const id of cPosts.slice(0, 4)) {
      expect((await ctx.http.put(`/api/v1/posts/${id}/like`).set(auth(fanA))).status).toBe(200);
    }
    expect((await ctx.http.put(`/api/v1/posts/${cPosts[0]!}/like`).set(auth(c))).status).toBe(200);
    const view = (u: TestUser) =>
      ctx.http
        .post('/api/v1/views')
        .set(auth(u))
        .send({ items: cPosts.map((postId) => ({ postId, watchedMs: 2_000 })) });
    expect((await view(fanA)).status).toBe(204);
    expect((await view(c)).status).toBe(204);

    let m = await school(c);
    expect(m.eligible).toBe(true);
    expect(values(m)).toEqual([
      ['CREATOR_FOLLOWERS', 2_000, 2_000],
      ['CREATOR_LIKES', 9_999, 10_000],
      ['CREATOR_VIEWS', 21_994, 20_000],
    ]);
    const res = await sweep();
    expect(res.raised).toEqual([]);
    expect(await levelOf(c)).toBeNull();
    m = await school(c);
    expect(m).toMatchObject({ level: 0, progress: { value: 0, next: 1 } });

    // The fifth like (on the reel) through the API: all three → level 1 at the next sweep.
    expect((await ctx.http.put(`/api/v1/posts/${cPosts[4]!}/like`).set(auth(fanA))).status).toBe(200);
    const raised = await sweep();
    expect(raised.raised).toEqual([{ userId: c.id, medalCode: CODE, from: null, to: 1 }]);
    expect(await levelOf(c)).toBe(1);
    m = await school(c);
    expect(m).toMatchObject({
      level: 1,
      iconAsset: 'medal_content_school_l1',
      progress: { value: 1, next: 2 },
    });
    expect(values(m)).toEqual([
      ['CREATOR_FOLLOWERS', 2_000, 10_000],
      ['CREATOR_LIKES', 10_000, 50_000],
      ['CREATOR_VIEWS', 21_994, 100_000],
    ]);
    expect(await schoolNotes(c)).toEqual([1]);

    // Owner (2026-11-07, «لا» to leaving them out): likes and views of posts later deleted or removed by moderation
    // still count. The creator deletes a post through the API; the team removes the reel.
    const del = await ctx.http.delete(`/api/v1/posts/${cPosts[1]!}`).set(auth(c));
    expect(del.status, JSON.stringify(del.body)).toBeLessThan(300);
    expect((await ctx.prisma.post.findUniqueOrThrow({ where: { id: cPosts[1]! } })).deletedAt).not.toBeNull();
    await ctx.prisma.post.update({ where: { id: cPosts[4]! }, data: { moderation: 'REMOVED' } });
    expect(values(await school(c))).toEqual([
      ['CREATOR_FOLLOWERS', 2_000, 10_000],
      ['CREATOR_LIKES', 10_000, 50_000],
      ['CREATOR_VIEWS', 21_994, 100_000],
    ]);
    // A repeat sweep changes nothing (and notifies nothing).
    expect((await sweep()).raised).toEqual([]);
    expect(await schoolNotes(c)).toEqual([1]);
  });

  it('a jump straight to level 3, audited with the three values; the level art everywhere; worn once only', async () => {
    const d = await signup();
    const reader = await signup();
    await makeCreator(d);
    const posts = [await post(d, 'a'), await reel(d)];
    const fans = await accounts(100_000);
    await followAll(fans, d);
    await likeAll(fans, posts); // 200 000
    await viewAll(fans, posts.slice(0, 1), 5); // 500 000
    expect((await sweep()).raised).toEqual([{ userId: d.id, medalCode: CODE, from: null, to: 3 }]);
    expect(await schoolNotes(d)).toEqual([3]);
    const audit = await ctx.prisma.auditLog.findMany({
      where: { action: 'medals.level_up', targetId: d.id },
    });
    expect(audit.map((a) => a.metadata)).toEqual([
      expect.objectContaining({
        medalCode: CODE,
        from: null,
        to: 3,
        metric: 'ALL_REQUIREMENTS',
        value: 3,
        via: 'sweep',
        requirements: { CREATOR_FOLLOWERS: 100_000, CREATOR_LIKES: 200_000, CREATOR_VIEWS: 500_000 },
      }),
    ]);
    const m = await school(d);
    expect(m).toMatchObject({
      level: 3,
      iconAsset: 'medal_content_school_l3',
      progress: { value: 3, next: 4 },
    });
    expect(values(m)).toEqual([
      ['CREATOR_FOLLOWERS', 100_000, 1_000_000],
      ['CREATOR_LIKES', 200_000, 2_000_000],
      ['CREATOR_VIEWS', 500_000, 5_000_000],
    ]);

    // Wearing: the same code twice is refused (D291 one medal per category); once shows level 3's art.
    const put = (medalCodes: unknown) =>
      ctx.http.put('/api/v1/me/medals/showcase').set(auth(d)).send({ medalCodes });
    const twice = await put([CODE, CODE]);
    expect(twice.status).toBe(400);
    expectContract(twice, 'setMyMedalShowcase');
    expect(twice.body.error.details).toEqual([{ field: 'medalCodes', issue: 'invalid_value' }]);
    const worn = await put([CODE]);
    expect(worn.status).toBe(200);
    expectContract(worn, 'setMyMedalShowcase');
    expect(worn.body.showcase).toEqual([
      expect.objectContaining({ code: CODE, level: 3, iconAsset: 'medal_content_school_l3' }),
    ]);
    const prof = await ctx.http.get(`/api/v1/users/${d.username}`).set(auth(reader));
    expectContract(prof, 'getPublicProfile');
    expect(prof.body.medals.showcase).toEqual([
      expect.objectContaining({ code: CODE, level: 3, iconAsset: 'medal_content_school_l3' }),
    ]);
    const list = await ctx.http.get(`/api/v1/users/${d.username}/medals`).set(auth(reader));
    expectContract(list, 'listUserMedals');
    expect((list.body.data as { code: string }[]).filter((x) => x.code === CODE)).toEqual([
      expect.objectContaining({ level: 3, maxLevel: 4, iconAsset: 'medal_content_school_l3' }),
    ]);

    // Level 4 (the top): its art; each requirement's `next` is null.
    await ctx.prisma.$transaction((tx) =>
      raiseMedalLevelsIn(tx, 'ALL_REQUIREMENTS', [{ userId: d.id, value: 4 }], { medalCode: CODE }),
    );
    const top = await school(d);
    expect(top).toMatchObject({ level: 4, iconAsset: 'medal_content_school_l4', progress: { next: null } });
    expect(values(top)).toEqual([
      ['CREATOR_FOLLOWERS', 100_000, null],
      ['CREATOR_LIKES', 200_000, null],
      ['CREATOR_VIEWS', 500_000, null],
    ]);
    const after = await ctx.http.get('/api/v1/me/medals/showcase').set(auth(d));
    expectContract(after, 'getMyMedalShowcase');
    expect(after.body.showcase).toEqual([
      expect.objectContaining({ code: CODE, level: 4, iconAsset: 'medal_content_school_l4' }),
    ]);
    // Never more than one row per person and medal.
    expect(await ctx.prisma.userMedal.count({ where: { userId: d.id, medalCode: CODE } })).toBe(1);
  });

  it('a non-creator never; levels never drop; a revoked creator keeps the level; an activation awards at once', async () => {
    // A non-creator with everything level 1 needs: nothing, ever.
    const e = await signup();
    const ePosts = [await post(e, 'x'), await post(e, 'y')];
    const eFans = await accounts(5_000);
    await followAll(eFans, e);
    await likeAll(eFans, ePosts);
    await viewAll(eFans, ePosts, 3);
    await sweep();
    expect(await levelOf(e)).toBeNull();
    const em = await school(e);
    expect(em).toMatchObject({ level: 0, eligible: false });
    expect(values(em).map((v) => v[1])).toEqual([0, 0, 0]);

    // Creator c (level 1): 1 500 of the followers are suspended → below level 1 now; the level stays.
    const fans = await ctx.prisma.$queryRaw<{ id: string }[]>`
      SELECT f.follower_id::text AS id FROM follows f JOIN users u ON u.id = f.follower_id
       WHERE f.followee_id = ${c.id}::uuid AND u.status = 'ACTIVE' AND u.email LIKE 'd300-%' LIMIT 1500`;
    await ctx.prisma.user.updateMany({
      where: { id: { in: fans.map((f) => f.id) } },
      data: { status: 'SUSPENDED' },
    });
    expect((await sweep()).raised).toEqual([]);
    expect(await levelOf(c)).toBe(1);
    const cm = await school(c);
    expect(cm).toMatchObject({ level: 1, eligible: true, iconAsset: 'medal_content_school_l1' });
    expect(values(cm)[0]).toEqual(['CREATOR_FOLLOWERS', 500, 10_000]);

    // The team ends c's membership: the level is kept; no more progress.
    const revoked = await p.send(owner, 'post', `/admin/creator-members/${c.id}/revoke`, {
      reason: 'D300 test',
    });
    expect(revoked.status, JSON.stringify(revoked.body)).toBe(200);
    const gone = await school(c);
    expect(gone).toMatchObject({ level: 1, eligible: false, iconAsset: 'medal_content_school_l1' });
    expect(values(gone).map((v) => v[1])).toEqual([0, 0, 0]);
    await sweep();
    expect(await levelOf(c)).toBe(1);

    // e becomes a creator: the activation awards the level reached at once (no sweep).
    await makeCreator(e);
    expect(await levelOf(e)).toBe(1);
    expect(await schoolNotes(e)).toEqual([1]);
  });

  it('medals-admin backfill raises creators from history (exact, no pre-filter) and PK hosts from their records, once; notify off by default', async () => {
    const f = await signup();
    await makeCreator(f);
    const posts = [
      await post(f, 'p'),
      await reel(f),
      await post(f, 'q'),
      await post(f, 'r'),
      await post(f, 's'),
    ];
    const fans = await accounts(10_000);
    await followAll(fans, f);
    await likeAll(fans, posts); // 50 000
    // The views rows without the posts' counters (as after the migration: rows from before it start at 1, and a
    // counter may be behind) — the backfill counts the rows exactly.
    await ctx.prisma.$executeRaw`
      INSERT INTO post_views (post_id, user_id, viewed_at, counted_views)
      SELECT p, fa, now() - interval '3 days', 2 FROM unnest(${posts}::uuid[]) p CROSS JOIN unnest(${fans}::uuid[]) fa`;
    expect(await levelOf(f)).toBeNull();
    // «لاعب الأحكام»: PK records from before the medal — only «PK أحكام» points count (owner): 3 200 → level 2; a
    // negative total or NORMAL points only → nothing.
    const [pkHost, pkLow, pkNormal] = [await signup(), await signup(), await signup()];
    await ctx.prisma.pkHostRecord.createMany({
      data: [
        // «PK أحكام» points only (owner): 3 200 of the 9 000 → level 2.
        { hostId: pkHost.id, wins: 3_000, points: 9_000, daresPoints: 3_200 },
        { hostId: pkLow.id, losses: 5, points: -6, daresPoints: -6, daresRefused: 2 },
        // 20 000 NORMAL points, none from «PK أحكام»: nothing.
        { hostId: pkNormal.id, wins: 6_667, points: 20_000, daresPoints: 0 },
      ],
    });
    const run = medalsAdmin('backfill');
    expect(run.status, run.out).toBe(0);
    expect(run.out).toMatch(/CONTENT_SCHOOL 1/);
    expect(run.out).toMatch(/DARES_PLAYER 1/);
    expect(await levelOf(f)).toBe(2);
    const dares = async (u: TestUser) =>
      (
        await ctx.prisma.userMedal.findUnique({
          where: { userId_medalCode: { userId: u.id, medalCode: 'DARES_PLAYER' } },
        })
      )?.level ?? null;
    expect(await dares(pkHost)).toBe(2);
    expect(await dares(pkLow)).toBeNull();
    expect(await dares(pkNormal)).toBeNull();
    const pkPage = (await ctx.http.get('/api/v1/medals').set(auth(pkHost))).body.data as MedalBody[];
    expect(pkPage.find((m) => m.code === 'DARES_PLAYER')).toMatchObject({
      level: 2,
      iconAsset: 'medal_dares_player_l2',
      progress: { value: 3_200, next: 5_000, requirements: [] },
    });
    const lowPage = (await ctx.http.get('/api/v1/medals').set(auth(pkLow))).body.data as MedalBody[];
    expect(lowPage.find((m) => m.code === 'DARES_PLAYER')).toMatchObject({
      level: 0,
      progress: { value: 0 },
    });
    expect(await schoolNotes(f)).toEqual([]);
    const audit = await ctx.prisma.auditLog.findMany({
      where: { action: 'medals.level_up', targetId: f.id },
    });
    expect(audit.map((a) => a.metadata)).toEqual([
      expect.objectContaining({ medalCode: CODE, from: null, to: 2, via: 'backfill' }),
    ]);
    expect(medalsAdmin('backfill')).toEqual({
      status: 0,
      out: 'Awarded 0 medals.\nRaised 0 medal levels.\n',
    });
    // Revoked c and the top-level d are untouched.
    expect(await levelOf(c)).toBe(1);
  });

  it('the panel: three thresholds per level; edits checked, saved and audited', async () => {
    const got = await p.send(owner, 'get', '/admin/medals');
    expect(got.status).toBe(200);
    expectContract(got, 'listAdminMedals');
    type AdminMedal = {
      code: string;
      metric: string;
      holders: number;
      levels: {
        level: number;
        threshold: number;
        holders: number;
        requirements: { metric: string; threshold: number }[];
      }[];
    };
    const medal = (got.body.data as AdminMedal[]).find((m) => m.code === CODE)!;
    expect(medal.metric).toBe('ALL_REQUIREMENTS');
    expect(medal.levels.map((l) => l.requirements.map((r) => r.threshold))).toEqual([
      [2_000, 10_000, 20_000],
      [10_000, 50_000, 100_000],
      [100_000, 200_000, 500_000],
      [1_000_000, 2_000_000, 5_000_000],
    ]);
    expect(medal.holders).toBeGreaterThanOrEqual(4);
    const wealth = (got.body.data as AdminMedal[]).find((m) => m.code === 'WEALTH_KINGS')!;
    expect(wealth.levels.every((l) => l.requirements.length === 0)).toBe(true);

    const lv = (k: number, f: number, l: number, v: number) => ({
      threshold: k,
      iconAsset: `medal_content_school_l${String(k)}`,
      requirements: [
        { metric: 'CREATOR_FOLLOWERS', threshold: f },
        { metric: 'CREATOR_LIKES', threshold: l },
        { metric: 'CREATOR_VIEWS', threshold: v },
      ],
    });
    const body = (levels: object[]) => ({
      category: 'ACHIEVEMENT',
      levels,
      reason: 'owner D300',
      totpCode: p.nextCode(owner.secret),
    });
    const good = [
      lv(1, 1_000, 10_000, 20_000),
      lv(2, 10_000, 50_000, 100_000),
      lv(3, 100_000, 200_000, 500_000),
      lv(4, 1_000_000, 2_000_000, 5_000_000),
    ];
    const bad = async (levels: object[]) => {
      const res = await p.send(owner, 'put', `/admin/medals/${CODE}`, body(levels));
      expect(res.status, JSON.stringify(res.body)).toBe(400);
      expectContract(res, 'updateAdminMedal');
      return res;
    };
    // No requirements; a falling one; the wrong threshold; a missing metric on one level; a duplicate metric.
    await bad(good.map(({ threshold }) => ({ threshold })));
    await bad([good[0]!, lv(2, 500, 50_000, 100_000), good[2]!, good[3]!]);
    await bad([{ ...good[0]!, threshold: 5 }, good[1]!, good[2]!, good[3]!]);
    await bad([
      good[0]!,
      { ...good[1]!, requirements: good[1]!.requirements.slice(0, 2) },
      good[2]!,
      good[3]!,
    ]);
    await bad([
      {
        ...good[0]!,
        requirements: [good[0]!.requirements[0]!, good[0]!.requirements[0]!, good[0]!.requirements[2]!],
      },
      good[1]!,
      good[2]!,
      good[3]!,
    ]);
    // A single-metric medal takes no requirements.
    const single = await p.send(owner, 'put', '/admin/medals/BULLET_FIRST', {
      ...body([{ threshold: 1, requirements: [{ metric: 'CREATOR_LIKES', threshold: 5 }] }]),
      category: 'ACTIVITY',
    });
    expect(single.status).toBe(400);
    expect(single.body.error.details).toEqual([{ field: 'levels', issue: 'invalid_value' }]);
    // Levels 1 … 4 are held: a list of 3 would take level 4 away.
    await bad(good.slice(0, 3));

    const saved = await p.send(owner, 'put', `/admin/medals/${CODE}`, body(good));
    expect(saved.status, JSON.stringify(saved.body)).toBe(200);
    expectContract(saved, 'updateAdminMedal');
    expect((saved.body as AdminMedal).levels[0]!.requirements).toEqual([
      { metric: 'CREATOR_FOLLOWERS', threshold: 1_000 },
      { metric: 'CREATOR_LIKES', threshold: 10_000 },
      { metric: 'CREATOR_VIEWS', threshold: 20_000 },
    ]);
    const audit = await ctx.prisma.auditLog.findMany({
      where: { action: 'medals.levels.update', targetId: CODE },
    });
    expect(audit).toHaveLength(1);
    expect(audit[0]!.metadata).toMatchObject({
      reason: 'owner D300',
      before: {
        levels: expect.arrayContaining([
          expect.objectContaining({
            level: 1,
            requirements: 'CREATOR_FOLLOWERS:2000,CREATOR_LIKES:10000,CREATOR_VIEWS:20000',
          }),
        ]),
      },
      after: {
        levels: expect.arrayContaining([
          expect.objectContaining({
            level: 1,
            requirements: 'CREATOR_FOLLOWERS:1000,CREATOR_LIKES:10000,CREATOR_VIEWS:20000',
          }),
        ]),
      },
    });
    // The app sees the new level-1 target.
    const u = await signup();
    expect((await school(u)).levels[0]!.requirements[0]).toEqual({
      metric: 'CREATOR_FOLLOWERS',
      threshold: 1_000,
    });
  });
});
