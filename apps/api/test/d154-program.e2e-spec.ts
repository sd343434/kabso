/**
 * D154e (owner 2026-10-28, item 10; contract v1.36-live, CONVENTIONS §10.37): a live's program
 * «قائمة البرامج» — the host's ≤ 10 segments, everyone reads them (late joiners and guests), the
 * blocked words and text hygiene, the room told when a segment starts (once, never after the end) —
 * end to end against PostgreSQL + Redis. Time is a FakeClock.
 */
import type request from 'supertest';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { Clock } from '../src/common/time/clock.js';
import { LiveProgramService } from '../src/modules/live/live-program.service.js';
import { LIVE_MEDIA_PROVIDER } from '../src/modules/live/media/live-media.provider.js';
import { MemoryLiveMedia } from './helpers/memory-live-media.js';
import { expectContract, operations } from './helpers/openapi.js';
import { createTestApp, registerVerified, type TestContext } from './helpers/test-app.js';

class FakeClock extends Clock {
  private ms = Date.now();
  now(): Date {
    return new Date(this.ms);
  }
  advance(minutes: number): void {
    this.ms += Math.round(minutes * 60_000);
  }
}

interface TestUser {
  readonly id: string;
  readonly username: string;
  readonly token: string;
}

describe('D154e contract coverage', () => {
  it('openapi v1.36-live declares the program operations', () => {
    const ids = operations().map((o) => `${o.operationId} ${o.method.toUpperCase()} ${o.path}`);
    expect(ids).toContain('getLiveProgram GET /api/v1/live/rooms/{roomId}/program');
    expect(ids).toContain('setLiveProgram PUT /api/v1/live/rooms/{roomId}/program');
  });
});

describe('D154e program', { timeout: 120_000 }, () => {
  const clock = new FakeClock();
  const media = new MemoryLiveMedia();
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
  const at = (minutes: number) => new Date(clock.now().getTime() + minutes * 60_000).toISOString();
  const put = (roomId: string, u: TestUser, items: object[]): request.Test =>
    ctx.http.put(`/api/v1/live/rooms/${roomId}/program`).set(auth(u)).send({ items });
  const messages = (roomId: string) =>
    media.broadcastsOf(roomId).filter((m) => String(m.type).startsWith('program'));

  beforeAll(async () => {
    ctx = await createTestApp({ LIVE_HOSTING_ENABLED: 'true', LIVE_HEARTBEAT_STALE_SECONDS: '3600' }, [
      { token: Clock, value: clock },
      { token: LIVE_MEDIA_PROVIDER, value: media },
    ]);
  });
  afterAll(async () => ctx?.close());

  it('the host sets the program; everyone reads it; a started segment is announced once', async () => {
    const h = await signup();
    await ctx.prisma.liveHost.create({ data: { userId: h.id, source: 'ADMIN', blockedWords: ['spoiler'] } });
    const viewer = await signup();
    const room = await ctx.http.post('/api/v1/live/rooms').set(auth(h)).send({ title: 'Show' });
    expect(room.status).toBe(201);
    const roomId = room.body.id as string;

    const res = await put(roomId, h, [
      { startsAt: at(0), title: '  Opening  ' },
      { startsAt: at(15), title: 'Q&A — no spoiler' },
      { startsAt: at(30), title: 'غناء' },
    ]);
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    expectContract(res, 'setLiveProgram');
    expect(res.body.items.map((i: { title: string }) => i.title)).toEqual([
      'Opening',
      'Q&A — no *******',
      'غناء',
    ]);
    expect(res.body.current).toBe(0);
    expect(messages(roomId).at(-1)).toMatchObject({ type: 'program', program: { roomId, current: 0 } });

    // A viewer (and a guest) reads it.
    const read = await ctx.http.get(`/api/v1/live/rooms/${roomId}/program`).set(auth(viewer));
    expect(read.status).toBe(200);
    expectContract(read, 'getLiveProgram');
    expect(read.body.items).toHaveLength(3);
    expect((await ctx.http.get(`/api/v1/live/rooms/${roomId}/program`)).status).toBe(200);

    // Only the host writes it.
    const notHost = await put(roomId, viewer, []);
    expect(notHost.status).toBe(403);
    expectContract(notHost, 'setLiveProgram');

    const service = ctx.app.get(LiveProgramService);
    expect(await service.announceDue()).toBe(1);
    expect(await service.announceDue()).toBe(0);
    clock.advance(15);
    expect(await service.announceDue()).toBe(1);
    expect(
      messages(roomId)
        .filter((m) => m.type === 'program-segment')
        .map((m) => m.item),
    ).toMatchObject([
      { position: 0, title: 'Opening' },
      { position: 1, title: 'Q&A — no *******' },
    ]);
    const now = await ctx.http.get(`/api/v1/live/rooms/${roomId}/program`).set(auth(viewer));
    expect(now.body.current).toBe(1);

    // Saving the same segments again keeps their announcements (nothing is repeated).
    const keep = read.body.items.map((i: { startsAt: string; title: string }) => ({
      startsAt: i.startsAt,
      title: i.title === 'Q&A — no *******' ? 'Q&A — no spoiler' : i.title,
    }));
    expect((await put(roomId, h, keep)).status).toBe(200);
    expect(await service.announceDue()).toBe(0);

    // The host ends early: the last segment is never announced; the program stays readable.
    await ctx.http.post(`/api/v1/live/rooms/${roomId}/end`).set(auth(h)).expect(200);
    clock.advance(20);
    expect(await service.announceDue()).toBe(0);
    const ended = await ctx.http.get(`/api/v1/live/rooms/${roomId}/program`).set(auth(viewer));
    expect(ended.body).toMatchObject({ current: null });
    expect(ended.body.items).toHaveLength(3);
    const late = await put(roomId, h, []);
    expect(late.status).toBe(409);
    expect(late.body.error.code).toBe('LIVE_ROOM_ENDED');
  });

  it('refuses more than 10 segments, starts out of order or outside the live, and bad titles', async () => {
    const h = await signup();
    await ctx.prisma.liveHost.create({ data: { userId: h.id, source: 'ADMIN' } });
    const room = await ctx.http.post('/api/v1/live/rooms').set(auth(h)).send({ title: 'Rules' });
    const roomId = room.body.id as string;
    const eleven = Array.from({ length: 11 }, (_, i) => ({ startsAt: at(i), title: `S${String(i)}` }));
    const cases: [object[], string, string][] = [
      [eleven, 'items', 'too_many'],
      [
        [
          { startsAt: at(10), title: 'b' },
          { startsAt: at(5), title: 'a' },
        ],
        'items',
        'invalid_value',
      ],
      [[{ startsAt: at(-120), title: 'before the live' }], 'items', 'invalid_value'],
      [[{ startsAt: at(25 * 60), title: 'tomorrow' }], 'items', 'invalid_value'],
      [[{ startsAt: at(1), title: '   ' }], 'items.0.title', 'required'],
      [[{ startsAt: at(1), title: 'x'.repeat(61) }], 'items.0.title', 'too_long'],
      [[{ startsAt: at(1), title: 'two\nlines' }], 'items.0.title', 'invalid_format'],
    ];
    for (const [items, field, issue] of cases) {
      const res = await put(roomId, h, items);
      expect(res.status, JSON.stringify(res.body)).toBe(400);
      expect(res.body.error.details).toEqual([{ field, issue }]);
    }
    // An empty program clears it.
    expect((await put(roomId, h, [{ startsAt: at(1), title: 'One' }])).status).toBe(200);
    const cleared = await put(roomId, h, []);
    expect(cleared.body).toMatchObject({ items: [], current: null });
  });
});
