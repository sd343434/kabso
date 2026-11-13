/**
 * D172 (owner 2026-10-29: the Creator Center in the layout of the owner's reference, whose stats card is
 * «بيانات أكتوبر» — this month's data; contract v1.49-social, CONVENTIONS §10.40):
 * `GET /me/creator-stats?period=THIS_MONTH` counts from the 1st at 00:00 in the region's zone
 * (`LIVE_RANKINGS_TIME_ZONE`) until now and names the month — end to end against PostgreSQL + Redis.
 */
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { Clock } from '../src/common/time/clock.js';
import { expectContract } from './helpers/openapi.js';
import { createTestApp, registerVerified, type TestContext } from './helpers/test-app.js';

/** 2026-11-01 04:00 in Riyadh (UTC+3) = 01:00 UTC; the month there began at 21:00 UTC on Oct 31. */
const NOW = Date.UTC(2026, 10, 1, 1, 0);

class FixedClock extends Clock {
  now(): Date {
    return new Date(NOW);
  }
}

interface TestUser {
  readonly id: string;
  readonly username: string;
  readonly token: string;
}

describe('D172 creator stats of this month', { timeout: 120_000 }, () => {
  let ctx: TestContext;

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

  beforeAll(async () => {
    ctx = await createTestApp({ LIVE_RANKINGS_TIME_ZONE: 'Asia/Riyadh' }, [
      { token: Clock, value: new FixedClock() },
    ]);
  });

  afterAll(async () => {
    await ctx?.close();
  });

  it('THIS_MONTH starts on the 1st at 00:00 in the region and names the month', async () => {
    const me = await signup();
    const fans = [await signup(), await signup(), await signup()];
    for (const f of fans) {
      const res = await ctx.http.put(`/api/v1/users/${me.username}/follow`).set(auth(f));
      expect(res.status).toBeLessThan(300);
    }
    const followedAt = async (fan: TestUser, at: Date) =>
      ctx.prisma.follow.update({
        where: { followerId_followeeId: { followerId: fan.id, followeeId: me.id } },
        data: { createdAt: at },
      });
    // 2026-11-01 01:00 in Riyadh (22:00 UTC the day before): this month there.
    await followedAt(fans[0]!, new Date(Date.UTC(2026, 9, 31, 22, 0)));
    // 2026-10-31 23:00 in Riyadh: last month.
    await followedAt(fans[1]!, new Date(Date.UTC(2026, 9, 31, 20, 0)));
    // 2026-10-15: last month.
    await followedAt(fans[2]!, new Date(Date.UTC(2026, 9, 15)));

    // Posts: one published this month in Riyadh (Oct 31 21:30 UTC), one just before (20:59 UTC).
    for (const [text, at, views] of [
      ['this month', Date.UTC(2026, 9, 31, 21, 30), 40],
      ['last month', Date.UTC(2026, 9, 31, 20, 59), 900],
    ] as const) {
      await ctx.prisma.post.create({
        data: { authorId: me.id, format: 'POST', text, publishedAt: new Date(at), viewCount: views },
      });
    }

    const res = await ctx.http.get('/api/v1/me/creator-stats?period=THIS_MONTH').set(auth(me));
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    expectContract(res, 'getMyCreatorStats');
    expect(res.body).toMatchObject({
      period: 'THIS_MONTH',
      from: '2026-10-31T21:00:00.000Z',
      to: '2026-11-01T01:00:00.000Z',
      month: '2026-11',
      followers: { total: 3, newInPeriod: 1 },
      posts: { published: 1, views: 40 },
      reels: { published: 0 },
      live: { lives: 0, liveSeconds: 0, earningsCoins: 0 },
    });

    // The other periods carry no month.
    for (const period of ['LAST_7_DAYS', 'LAST_30_DAYS', 'ALL_TIME']) {
      const other = await ctx.http.get(`/api/v1/me/creator-stats?period=${period}`).set(auth(me));
      expect(other.status).toBe(200);
      expectContract(other, 'getMyCreatorStats');
      expect(other.body.month).toBeNull();
    }

    for (const q of ['?period=this_month', '?period=MONTH', '?period=THIS_MONTH&tz=UTC']) {
      const bad = await ctx.http.get(`/api/v1/me/creator-stats${q}`).set(auth(me));
      expect(bad.status).toBe(400);
      expectContract(bad, 'getMyCreatorStats');
    }
    expect((await ctx.http.get('/api/v1/me/creator-stats?period=THIS_MONTH')).status).toBe(401);
  });
});
