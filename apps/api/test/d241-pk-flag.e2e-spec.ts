/**
 * D241 (openapi v1.54-live DRAFT, CONVENTIONS §10.84): a room in a D195 PK keeps mode SOLO, so the panel's
 * «PK» chip and the app's hub tag read the open match instead — `LiveRoomSummary.inPk`, `listAdminLives`
 * `mode=PK` / `SOLO` and `AdminLiveRow.pk` / `AdminLiveDetail.pk` (the opponent). A real battle between two
 * rooms (invite → accept), then the PK ends and closes.
 */
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { Clock } from '../src/common/time/clock.js';
import { LivePkService } from '../src/modules/live/live-pk.service.js';
import { LIVE_MEDIA_PROVIDER } from '../src/modules/live/media/live-media.provider.js';
import { panel, type Admin } from './helpers/admin-panel.js';
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
  readonly token: string;
}

describe('D241 contract coverage', () => {
  it('openapi declares inPk, the admin pk and the mode filter', () => {
    const op = operations().find((o) => o.operationId === 'listAdminLives');
    const params = (op?.spec as { parameters?: { name?: string; schema?: unknown }[] }).parameters ?? [];
    expect(params.find((p) => p.name === 'mode')?.schema).toEqual({
      type: 'string',
      // v1.56-live (D213): the «ستريمر» chip.
      enum: ['SOLO', 'PK', 'MULTI', 'AUDIO', 'PODCAST', 'STREAMER'],
    });
  });
});

describe('D241 rooms in a PK are flagged', { timeout: 300_000 }, () => {
  const clock = new FakeClock();
  const media = new MemoryLiveMedia();
  let ctx: TestContext;
  let pk: LivePkService;
  const admin = panel(() => ctx);
  let owner: Admin;

  const auth = (u: TestUser) => ({ Authorization: `Bearer ${u.token}` });
  const host = async (): Promise<TestUser> => {
    const { res } = await registerVerified(ctx);
    expect(res.status).toBe(201);
    const u = {
      id: res.body.user.id as string,
      username: res.body.user.username as string,
      token: res.body.tokens.accessToken as string,
    };
    await ctx.prisma.liveHost.create({ data: { userId: u.id, source: 'ADMIN' } });
    return u;
  };
  const goLive = async (u: TestUser, score: number): Promise<string> => {
    clock.advance(1);
    const res = await ctx.http.post('/api/v1/live/rooms').set(auth(u)).send({ title: 'PK' });
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    const id = res.body.id as string;
    await ctx.prisma.liveRoom.update({ where: { id }, data: { score: BigInt(score) } });
    return id;
  };
  const heartbeat = async (roomId: string, u: TestUser) => {
    const res = await ctx.http.post(`/api/v1/live/rooms/${roomId}/heartbeat`).set(auth(u));
    expect(res.status).toBe(204);
  };
  const flags = async (query: string): Promise<Record<string, boolean>> => {
    const res = await ctx.http.get(`/api/v1/live/rooms?${query}`);
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    expectContract(res, 'listLiveRooms');
    return Object.fromEntries((res.body.data as { id: string; inPk: boolean }[]).map((r) => [r.id, r.inPk]));
  };
  /** Every page with limit=1. */
  const pages = async (query: string): Promise<Record<string, boolean>> => {
    const out: Record<string, boolean> = {};
    let cursor: string | null = null;
    for (let i = 0; i < 50; i += 1) {
      const res = await ctx.http.get(
        `/api/v1/live/rooms?${query}&limit=1${cursor ? `&cursor=${encodeURIComponent(cursor)}` : ''}`,
      );
      expect(res.status).toBe(200);
      for (const r of res.body.data as { id: string; inPk: boolean }[]) out[r.id] = r.inPk;
      cursor = res.body.page.nextCursor as string | null;
      if (!cursor) return out;
    }
    throw new Error('too many pages');
  };
  const adminLives = async (mode?: string) => {
    const res = await admin.send(owner, 'get', `/admin/lives${mode ? `?mode=${mode}` : ''}`);
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    expectContract(res, 'listAdminLives');
    return res.body as {
      total: number;
      data: {
        id: string;
        mode: string;
        pk: { opponentRoomId: string | null; opponentUsername: string | null } | null;
      }[];
    };
  };

  beforeAll(async () => {
    ctx = await createTestApp(
      {
        ADMIN_TOTP_KEY: 'admin-totp-test-key-0123456789-abcdefghijklmnop',
        ADMIN_SESSION_IDLE_SECONDS: '3600',
        ADMIN_SESSION_MAX_SECONDS: '28800',
        RATE_LIMIT_ADMIN_LOGIN_IP: '10000/900',
        RATE_LIMIT_ADMIN_IP: '100000/900',
        LIVE_HOSTING_ENABLED: 'true',
        LIVE_HEARTBEAT_STALE_SECONDS: '3600',
        PK_SCORE_BROADCAST_MS: '0',
        PK_EFFECTIVE_MIN_POINTS: '0',
      },
      [
        { token: Clock, value: clock },
        { token: LIVE_MEDIA_PROVIDER, value: media },
      ],
    );
    pk = ctx.app.get(LivePkService);
    owner = await admin.makeAdmin(['OWNER']);
  });
  afterAll(async () => ctx?.close());

  it('a real battle flags both rooms (public list, panel chip, opponent), then neither once it closes', async () => {
    const [a, b, c] = [await host(), await host(), await host()];
    const roomA = await goLive(a, 30);
    const roomB = await goLive(b, 20);
    const solo = await goLive(c, 10);
    const inv = await ctx.http
      .post(`/api/v1/live/rooms/${roomA}/pk/invites`)
      .set(auth(a))
      .send({ toRoomId: roomB });
    expect(inv.status, JSON.stringify(inv.body)).toBe(201);
    const acc = await ctx.http
      .post(`/api/v1/live/rooms/${roomB}/pk/invites/${inv.body.id as string}/accept`)
      .set(auth(b));
    expect(acc.status, JSON.stringify(acc.body)).toBe(200);
    // The rooms stay SOLO: the old `mode = 'PK'` test never matched.
    const rooms = await ctx.prisma.liveRoom.findMany({ where: { id: { in: [roomA, roomB] } } });
    expect(rooms.map((r) => r.mode)).toEqual(['SOLO', 'SOLO']);

    const want = { [roomA]: true, [roomB]: true, [solo]: false };
    for (const q of ['tab=popular', 'tab=new', 'tab=popular&kind=solo']) {
      expect(await flags(q), q).toMatchObject(want);
      expect(await pages(q), q).toMatchObject(want);
    }
    const room = await ctx.http.get(`/api/v1/live/rooms/${roomA}`);
    expectContract(room, 'getLiveRoom');
    expect(room.body.inPk).toBe(true);

    const pkChip = await adminLives('PK');
    expect(pkChip.total).toBe(2);
    expect(new Set(pkChip.data.map((r) => r.id))).toEqual(new Set([roomA, roomB]));
    const byId = Object.fromEntries(pkChip.data.map((r) => [r.id, r]));
    expect(byId[roomA]!.pk).toEqual({
      opponentRoomId: roomB,
      opponentUsername: b.username,
      opponentDisplayName: expect.any(String),
    });
    expect(byId[roomB]!.pk?.opponentUsername).toBe(a.username);
    const soloChip = await adminLives('SOLO');
    expect(soloChip.data.map((r) => r.id)).toEqual([solo]);
    expect(soloChip.total).toBe(1);
    const all = await adminLives();
    expect(all.total).toBe(3);
    expect(all.data.find((r) => r.id === solo)!.pk).toBeNull();
    const detail = await admin.send(owner, 'get', `/admin/lives/${roomB}`);
    expectContract(detail, 'getAdminLive');
    expect(detail.body.pk.opponentRoomId).toBe(roomA);

    // The battle ends (time up), the result shows 60 s, then the match closes.
    for (let left = 300; left > 0; left -= 15) {
      clock.advance(15);
      for (const [r, u] of [
        [roomA, a],
        [roomB, b],
        [solo, c],
      ] as const)
        await heartbeat(r, u);
    }
    await pk.tick();
    // RESULT (and its dare) is still a PK on screen: still flagged.
    expect(await flags('tab=popular')).toMatchObject(want);
    for (let left = 60; left > 0; left -= 15) {
      clock.advance(15);
      for (const [r, u] of [
        [roomA, a],
        [roomB, b],
        [solo, c],
      ] as const)
        await heartbeat(r, u);
    }
    await pk.tick();
    expect((await ctx.prisma.pkMatch.findFirstOrThrow({ where: { roomAId: roomA } })).status).toBe('CLOSED');
    expect(await flags('tab=popular')).toEqual({ [roomA]: false, [roomB]: false, [solo]: false });
    expect(await pages('tab=popular')).toEqual({ [roomA]: false, [roomB]: false, [solo]: false });
    expect((await adminLives('PK')).total).toBe(0);
    expect((await adminLives('SOLO')).total).toBe(3);
  });

  it('a legacy mode PK room is flagged without an opponent', async () => {
    const d = await host();
    const legacy = await goLive(d, 5);
    await ctx.prisma.liveRoom.update({ where: { id: legacy }, data: { mode: 'PK' } });
    expect((await flags('tab=popular'))[legacy]).toBe(true);
    const chip = await adminLives('PK');
    const row = chip.data.find((r) => r.id === legacy)!;
    expect(row.pk).toEqual({ opponentRoomId: null, opponentUsername: null, opponentDisplayName: null });
  });
});
