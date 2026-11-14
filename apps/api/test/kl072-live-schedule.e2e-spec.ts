/**
 * KL-072 / CP-016 part C (D99): the live schedule (openapi v1.14-live DRAFT, CONVENTIONS §10.16)
 * and its `LIVE_SCHEDULED_SOON` reminders (§11.10), end to end against PostgreSQL + Redis with the
 * API as the DML-only runtime role. Time: a FakeClock is moved forward; the reminder sweep is
 * called directly (the in-process sweeper is off in tests).
 */
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';
import { Clock } from '../src/common/time/clock.js';
import { LiveScheduleService } from '../src/modules/live/live-schedule.service.js';
import { expectContract, operations } from './helpers/openapi.js';
import {
  createTestApp,
  registerVerified,
  withMigrationClient,
  type TestContext,
} from './helpers/test-app.js';

class FakeClock extends Clock {
  ms = Date.parse('2026-10-21T10:00:00.000Z');
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

interface Slot {
  id: string;
  title: string;
  startsAt: string;
  createdAt: string;
}

interface Note {
  id: string;
  type: string;
  actors: { id: string }[];
  target: { type: string; id: string; text: string | null; startsAt?: string } | null;
}

const MIN = 60;

describe('CP-016 C contract coverage', () => {
  it('openapi declares the three schedule operations', () => {
    expect(
      operations()
        .filter((o) => o.path.startsWith('/api/v1/me/live-schedule'))
        .map((o) => `${o.operationId} ${o.method.toUpperCase()}`)
        .sort(),
    ).toEqual(['createLiveScheduleSlot POST', 'deleteLiveScheduleSlot DELETE', 'listMyLiveSchedule GET']);
  });
});

describe('CP-016 C the live schedule', () => {
  const clock = new FakeClock();
  let ctx: TestContext;
  const auth = (u: TestUser) => ({ Authorization: `Bearer ${u.token}` });
  const signup = async (): Promise<TestUser> => {
    const { res } = await registerVerified(ctx);
    expect(res.status).toBe(201);
    return { id: res.body.user.id, username: res.body.user.username, token: res.body.tokens.accessToken };
  };
  const host = async (): Promise<TestUser> => {
    const u = await signup();
    await ctx.prisma.liveHost.create({ data: { userId: u.id, source: 'ADMIN' } });
    return u;
  };
  const at = (minutes: number) => new Date(clock.ms + minutes * MIN * 1000).toISOString();
  const create = async (u: TestUser, body: unknown) => {
    const res = await ctx.http
      .post('/api/v1/me/live-schedule')
      .set(auth(u))
      .send(body as object);
    expectContract(res, 'createLiveScheduleSlot');
    return res;
  };
  const list = async (u: TestUser) => {
    const res = await ctx.http.get('/api/v1/me/live-schedule').set(auth(u));
    expectContract(res, 'listMyLiveSchedule');
    return res;
  };
  const remove = async (u: TestUser, id: string) => {
    const res = await ctx.http.delete(`/api/v1/me/live-schedule/${id}`).set(auth(u));
    expectContract(res, 'deleteLiveScheduleSlot');
    return res;
  };
  const follow = async (fan: TestUser, u: TestUser) =>
    ctx.http.put(`/api/v1/users/${u.username}/follow`).set(auth(fan)).expect(200);
  const inbox = async (u: TestUser): Promise<Note[]> => {
    const res = await ctx.http.get('/api/v1/notifications?limit=50').set(auth(u));
    expect(res.status).toBe(200);
    expectContract(res, 'listNotifications');
    return res.body.data as Note[];
  };
  const remind = () => ctx.app.get(LiveScheduleService).sendReminders();

  beforeAll(async () => {
    ctx = await createTestApp({ LIVE_HOSTING_ENABLED: 'true' }, [{ token: Clock, value: clock }]);
  });
  afterAll(async () => ctx?.close());
  beforeEach(() => {
    clock.ms = Date.parse('2026-10-21T10:00:00.000Z');
  });

  it('creates, lists soonest first, deletes; normalized title; audited', async () => {
    const h = await host();
    expect((await list(h)).body).toEqual({ data: [] });
    const later = await create(h, { title: '  Friday night  ', startsAt: at(120) });
    expect(later.status).toBe(201);
    expect(later.body).toMatchObject({ title: 'Friday night', startsAt: at(120) });
    const sooner = await create(h, { title: 'Morning chat', startsAt: at(30) });
    expect(sooner.status).toBe(201);
    expect(((await list(h)).body.data as Slot[]).map((s) => s.title)).toEqual([
      'Morning chat',
      'Friday night',
    ]);

    expect((await remove(h, sooner.body.id as string)).status).toBe(204);
    expect(((await list(h)).body.data as Slot[]).map((s) => s.id)).toEqual([later.body.id]);
    // A started slot leaves the list.
    clock.advance(121 * MIN);
    expect((await list(h)).body.data).toEqual([]);

    const audit = await ctx.prisma.auditLog.findMany({
      where: { actorUserId: h.id, action: { startsWith: 'live.schedule.' } },
      orderBy: { createdAt: 'asc' },
    });
    expect(audit.map((a) => a.action)).toEqual([
      'live.schedule.create',
      'live.schedule.create',
      'live.schedule.delete',
    ]);
  });

  it('refuses: no permission → 403; times and titles → 400; 11th → 409; others → 404', async () => {
    const plain = await signup();
    expect((await list(plain)).status).toBe(403);
    const refused = await create(plain, { title: 'x', startsAt: at(60) });
    expect(refused.status).toBe(403);
    expect(refused.body.error.code).toBe('LIVE_HOSTING_NOT_ALLOWED');

    const h = await host();
    const issue = async (body: unknown) => (await create(h, body)).body.error.details as unknown[];
    expect(await issue({ title: 'soon', startsAt: at(14) })).toEqual([
      { field: 'startsAt', issue: 'too_small' },
    ]);
    expect(await issue({ title: 'far', startsAt: at(30 * 24 * 60 + 1) })).toEqual([
      { field: 'startsAt', issue: 'too_big' },
    ]);
    expect((await create(h, { title: 'x'.repeat(61), startsAt: at(60) })).status).toBe(400);
    expect((await create(h, { title: '   ', startsAt: at(60) })).status).toBe(400);
    expect((await create(h, { title: 'ok', startsAt: 'tomorrow' })).status).toBe(400);
    expect((await create(h, { title: 'ok', startsAt: at(60), extra: 1 })).status).toBe(400);
    expect((await create(h, { title: 'ok' })).status).toBe(400);

    for (let i = 0; i < 10; i += 1) {
      expect((await create(h, { title: `Live ${i}`, startsAt: at(60 + i) })).status).toBe(201);
    }
    const full = await create(h, { title: 'One more', startsAt: at(200) });
    expect(full.status).toBe(409);
    expect(full.body.error.code).toBe('LIVE_SCHEDULE_FULL');

    const other = await host();
    const mine = ((await list(h)).body.data as Slot[])[0]!;
    expect((await remove(other, mine.id)).status).toBe(404);
    expect((await remove(h, 'not-a-uuid')).status).toBe(404);
    expect((await remove(h, '01a17202-a31e-7038-8ea9-2208d1518f96')).status).toBe(404);
  });

  it('reminds followers 15 minutes before, once, with the usual rules', async () => {
    const h = await host();
    const [fan, quiet, blocked, muter, gone, stranger] = await Promise.all(
      Array.from({ length: 6 }, () => signup()),
    );
    for (const u of [fan!, quiet!, blocked!, muter!, gone!]) await follow(u, h);
    await ctx.http
      .patch('/api/v1/me/notification-settings')
      .set(auth(quiet!))
      .send({ lives: false })
      .expect(200);
    await ctx.http.put(`/api/v1/users/${blocked!.username}/block`).set(auth(h)).expect(200);
    await ctx.http.put(`/api/v1/users/${h.username}/mute`).set(auth(muter!)).expect(200);
    await ctx.prisma.user.update({ where: { id: gone!.id }, data: { status: 'SUSPENDED' } });

    const slot = (await create(h, { title: 'Evening songs', startsAt: at(40) })).body as Slot;
    expect(await remind()).toBe(0); // 40 minutes ahead: not due yet
    expect(await inbox(fan!)).toEqual([]);

    clock.advance(26 * MIN); // 14 minutes before
    expect(await remind()).toBe(1);
    const [note] = await inbox(fan!);
    expect(note).toMatchObject({
      type: 'LIVE_SCHEDULED_SOON',
      actors: [{ id: h.id }],
      // The host as a USER target (older apps know the type), with the title and the start.
      target: { type: 'USER', id: h.username, text: 'Evening songs', startsAt: slot.startsAt },
    });
    for (const u of [quiet!, blocked!, muter!, stranger!]) expect(await inbox(u)).toEqual([]);

    // Once only.
    expect(await remind()).toBe(0);
    expect(await inbox(fan!)).toHaveLength(1);

    // Cancelling the slot takes the reminder away.
    expect((await remove(h, slot.id)).status).toBe(204);
    expect(await inbox(fan!)).toEqual([]);
  });

  it('a slot missed by more than 15 minutes is marked, never announced late; retention', async () => {
    const h = await host();
    const fan = await signup();
    await follow(fan, h);
    const slot = (await create(h, { title: 'Missed', startsAt: at(20) })).body as Slot;
    clock.advance(40 * MIN); // the sweeper was down: 20 minutes after the start
    expect(await remind()).toBe(1);
    expect(await inbox(fan)).toEqual([]);
    const row = await ctx.prisma.liveScheduleSlot.findUniqueOrThrow({ where: { id: slot.id } });
    expect(row.remindedAt).not.toBeNull();

    const service = ctx.app.get(LiveScheduleService);
    expect(await service.sweepRetention(new Date(clock.ms + 29 * 24 * 3600_000))).toBe(0);
    expect(await service.sweepRetention(new Date(clock.ms + 31 * 24 * 3600_000))).toBeGreaterThanOrEqual(1);
    expect(await ctx.prisma.liveScheduleSlot.count({ where: { id: slot.id } })).toBe(0);
  });

  it('the settings carry `lives`', async () => {
    const u = await signup();
    const res = await ctx.http.patch('/api/v1/me/notification-settings').set(auth(u)).send({ lives: false });
    expect(res.status).toBe(200);
    expectContract(res, 'updateNotificationSettings');
    expect(res.body.lives).toBe(false);
    await withMigrationClient(async (c) => {
      expect((await c.notificationSettings.findUniqueOrThrow({ where: { userId: u.id } })).lives).toBe(false);
    });
  });
});

describe('CP-016 C rate limit', () => {
  it('POST and DELETE: 30 / hour / user, one bucket (here 2)', async () => {
    const ctx = await createTestApp({
      LIVE_HOSTING_ENABLED: 'true',
      RATE_LIMIT_LIVE_SCHEDULE_USER: '2/3600',
    });
    try {
      const { res } = await registerVerified(ctx);
      const headers = { Authorization: `Bearer ${res.body.tokens.accessToken as string}` };
      await ctx.prisma.liveHost.create({ data: { userId: res.body.user.id, source: 'ADMIN' } });
      const startsAt = new Date(Date.now() + 3600_000).toISOString();
      const created = await ctx.http
        .post('/api/v1/me/live-schedule')
        .set(headers)
        .send({ title: 'a', startsAt });
      expect(created.status).toBe(201);
      expect(
        (await ctx.http.delete(`/api/v1/me/live-schedule/${created.body.id as string}`).set(headers)).status,
      ).toBe(204);
      expect(
        (await ctx.http.post('/api/v1/me/live-schedule').set(headers).send({ title: 'b', startsAt })).status,
      ).toBe(429);
      // GET uses the default bucket.
      expect((await ctx.http.get('/api/v1/me/live-schedule').set(headers)).status).toBe(200);
    } finally {
      await ctx.close();
    }
  });
});
