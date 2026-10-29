/**
 * D166 (owner 2026-10-29: «عندما مشاهدة يوتيوب لا يكون هناك إلا ١٠ كراسي فقط»; contract v1.39-live,
 * CONVENTIONS §10.9, §10.39): while an AUDIO room watches YouTube together it is a cinema with the 10
 * drawn seats (the host's and seats 1–9). Seats 10+ read LOCKED, their people move to a free seat
 * below or leave the seat, requests and invitations can only target seats 1–9, and the room's own
 * count returns when the video stops (nobody is moved back) — end to end against PostgreSQL + Redis.
 */
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { VIEWER_PERMISSION } from '../src/modules/live/live-seats.service.js';
import { LIVE_MEDIA_PROVIDER } from '../src/modules/live/media/live-media.provider.js';
import {
  thumbnailOf,
  YOUTUBE_CLIENT,
  type YoutubeClient,
  type YoutubeVideo,
} from '../src/modules/live/youtube/youtube.client.js';
import { MemoryLiveMedia } from './helpers/memory-live-media.js';
import { expectContract } from './helpers/openapi.js';
import { createTestApp, registerVerified, type TestContext } from './helpers/test-app.js';

const VIDEO = 'aaaaaaaaaaa';

class FakeYoutube implements YoutubeClient {
  searchEnabled = false;
  async video(videoId: string): Promise<YoutubeVideo | null> {
    return { videoId, title: `Video ${videoId}`, channel: null, thumbnailUrl: thumbnailOf(videoId) };
  }
  async search(): Promise<YoutubeVideo[]> {
    return [];
  }
}

interface TestUser {
  readonly id: string;
  readonly username: string;
  readonly token: string;
}

interface SeatBody {
  index: number;
  state: string;
  user: { id: string } | null;
  mutedByHost: boolean;
}

describe('D166 cinema seats', { timeout: 180_000 }, () => {
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
  const room = (id: string) => `/api/v1/live/rooms/${id}`;
  const audio = async (seatCount: number) => {
    const h = await signup();
    await ctx.prisma.liveHost.create({ data: { userId: h.id, source: 'ADMIN' } });
    const res = await ctx.http
      .post('/api/v1/live/rooms')
      .set(auth(h))
      .send({ title: 'Cinema', mode: 'AUDIO', seatCount });
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    return { h, roomId: res.body.id as string };
  };
  const seat = async (roomId: string, h: TestUser, index: number): Promise<TestUser> => {
    const guest = await signup();
    const asked = await ctx.http
      .post(`${room(roomId)}/seat-requests`)
      .set(auth(guest))
      .send({ seatIndex: index });
    expect(asked.status, JSON.stringify(asked.body)).toBe(201);
    const accepted = await ctx.http
      .post(`${room(roomId)}/seat-requests/${asked.body.id}/accept`)
      .set(auth(h))
      .send({});
    expect(accepted.status, JSON.stringify(accepted.body)).toBe(200);
    return guest;
  };
  const watch = (roomId: string, h: TestUser, video: string | null) =>
    ctx.http
      .put(`${room(roomId)}/watch`)
      .set(auth(h))
      .send(
        video === null
          ? { video: null, playing: false, positionMs: 0 }
          : { video, playing: true, positionMs: 0 },
      );
  const seats = async (roomId: string, as?: TestUser) => {
    const req = ctx.http.get(`${room(roomId)}/seats`);
    const res = as ? await req.set(auth(as)) : await req;
    expect(res.status).toBe(200);
    expectContract(res, 'getLiveRoomSeats');
    return res.body as {
      cinema: boolean;
      seatCount: number;
      seats: SeatBody[];
      mine?: { seatIndex: number | null };
    };
  };
  const at = (body: { seats: SeatBody[] }, index: number) => body.seats.find((s) => s.index === index)!;

  beforeAll(async () => {
    ctx = await createTestApp({ LIVE_HOSTING_ENABLED: 'true', LIVE_HEARTBEAT_STALE_SECONDS: '3600' }, [
      { token: LIVE_MEDIA_PROVIDER, value: media },
      { token: YOUTUBE_CLIENT, value: new FakeYoutube() },
    ]);
  });
  afterAll(async () => ctx?.close());

  it('YouTube starts: people on seats 10+ move to the first free seats 1–9 (mic state kept); seats 10+ read LOCKED', async () => {
    const { h, roomId } = await audio(15);
    const stay = await seat(roomId, h, 3);
    const a = await seat(roomId, h, 11);
    const b = await seat(roomId, h, 12);
    const c = await seat(roomId, h, 14);
    // The host muted b: still muted after the move.
    const muted = await ctx.http
      .post(`${room(roomId)}/seats/12/mute`)
      .set(auth(h))
      .send({ muted: true });
    expect(muted.status).toBe(200);
    const before = await seats(roomId);
    expect(before.cinema).toBe(false);
    expect(at(before, 11).user?.id).toBe(a.id);

    const started = await watch(roomId, h, VIDEO);
    expect(started.status, JSON.stringify(started.body)).toBe(200);

    const after = await seats(roomId, a);
    expect(after.cinema).toBe(true);
    expect(after.seatCount).toBe(15);
    expect(after.seats.map((s) => s.index)).toEqual(Array.from({ length: 14 }, (_, i) => i + 1));
    expect(at(after, 3).user?.id).toBe(stay.id);
    expect(at(after, 1).user?.id).toBe(a.id);
    expect(at(after, 2)).toMatchObject({ state: 'TAKEN', user: { id: b.id }, mutedByHost: true });
    expect(at(after, 4).user?.id).toBe(c.id);
    for (let i = 10; i < 15; i += 1) {
      expect(at(after, i)).toMatchObject({ state: 'LOCKED', user: null });
    }
    expect(after.mine?.seatIndex).toBe(1);
    // Still on a seat: nobody's publish permission was withdrawn.
    for (const u of [a, b, c]) {
      expect(media.lastPermission(roomId, u.id)).not.toEqual(VIEWER_PERMISSION);
    }
    // A guest without an account reads the same cinema.
    expect((await seats(roomId)).cinema).toBe(true);
  });

  it('no free seat below 10: they leave the seat (publish permission withdrawn); pending requests for 10+ expire', async () => {
    const { h, roomId } = await audio(15);
    const far = await signup();
    const pending = await ctx.http
      .post(`${room(roomId)}/seat-requests`)
      .set(auth(far))
      .send({ seatIndex: 13 });
    expect(pending.status).toBe(201);
    for (let i = 1; i < 10; i += 1) {
      const locked = await ctx.http
        .post(`${room(roomId)}/seats/${String(i)}/lock`)
        .set(auth(h))
        .send({ locked: true });
      expect(locked.status).toBe(200);
    }
    const x = await seat(roomId, h, 10);
    const y = await seat(roomId, h, 12);
    expect((await watch(roomId, h, VIDEO)).status).toBe(200);
    const after = await seats(roomId, x);
    expect(after.mine?.seatIndex).toBeNull();
    expect(after.seats.some((s) => s.user?.id === x.id || s.user?.id === y.id)).toBe(false);
    expect(media.lastPermission(roomId, x.id)).toEqual(VIEWER_PERMISSION);
    expect(media.lastPermission(roomId, y.id)).toEqual(VIEWER_PERMISSION);
    const request = await ctx.prisma.liveSeatRequest.findUniqueOrThrow({ where: { id: pending.body.id } });
    expect(request.status).toBe('EXPIRED');
  });

  it('while the cinema is on, requests, invitations and locks for seats 10+ are refused; seats 1–9 work', async () => {
    const { h, roomId } = await audio(20);
    expect((await watch(roomId, h, VIDEO)).status).toBe(200);
    const v = await signup();
    const far = await ctx.http
      .post(`${room(roomId)}/seat-requests`)
      .set(auth(v))
      .send({ seatIndex: 11 });
    expect(far.status).toBe(409);
    expect(far.body.error.code).toBe('LIVE_SEAT_UNAVAILABLE');
    const invite = await ctx.http
      .post(`${room(roomId)}/seat-invites`)
      .set(auth(h))
      .send({ username: v.username, seatIndex: 15 });
    expect(invite.status).toBe(409);
    const lock = await ctx.http
      .post(`${room(roomId)}/seats/12/lock`)
      .set(auth(h))
      .send({ locked: true });
    expect(lock.status).toBe(409);
    // Without a seat number the request gets a seat below 10.
    const near = await ctx.http
      .post(`${room(roomId)}/seat-requests`)
      .set(auth(v))
      .send({});
    expect(near.status).toBe(201);
    const ok = await ctx.http
      .post(`${room(roomId)}/seat-requests/${near.body.id}/accept`)
      .set(auth(h))
      .send({});
    expect(ok.status).toBe(200);
    expect((await seats(roomId, v)).mine?.seatIndex).toBe(1);
  });

  it('YouTube stops: the room has its own seats again (nobody moved back); seat 12 can be asked for', async () => {
    const { h, roomId } = await audio(15);
    const a = await seat(roomId, h, 12);
    expect((await watch(roomId, h, VIDEO)).status).toBe(200);
    const version = (await ctx.prisma.liveRoom.findUniqueOrThrow({ where: { id: roomId } })).seatsVersion;
    expect((await watch(roomId, h, null)).status).toBe(200);
    expect(
      (await ctx.prisma.liveRoom.findUniqueOrThrow({ where: { id: roomId } })).seatsVersion,
    ).toBeGreaterThan(version);
    const after = await seats(roomId, a);
    expect(after.cinema).toBe(false);
    expect(after.mine?.seatIndex).toBe(1);
    for (let i = 10; i < 15; i += 1) expect(at(after, i).state).toBe('EMPTY');
    const v = await signup();
    const asked = await ctx.http
      .post(`${room(roomId)}/seat-requests`)
      .set(auth(v))
      .send({ seatIndex: 12 });
    expect(asked.status).toBe(201);
  });

  it('a room of 10 seats or fewer keeps its seats in the cinema (cinema true, nothing locked or moved)', async () => {
    const { h, roomId } = await audio(10);
    const a = await seat(roomId, h, 9);
    const version = (await ctx.prisma.liveRoom.findUniqueOrThrow({ where: { id: roomId } })).seatsVersion;
    expect((await watch(roomId, h, VIDEO)).status).toBe(200);
    expect((await ctx.prisma.liveRoom.findUniqueOrThrow({ where: { id: roomId } })).seatsVersion).toBe(
      version,
    );
    const after = await seats(roomId);
    expect(after.cinema).toBe(true);
    expect(at(after, 9).user?.id).toBe(a.id);
    expect(after.seats.some((s) => s.state === 'LOCKED')).toBe(false);
  });

  it('a video live (MULTI) is never a cinema', async () => {
    const h = await signup();
    await ctx.prisma.liveHost.create({ data: { userId: h.id, source: 'ADMIN' } });
    const res = await ctx.http
      .post('/api/v1/live/rooms')
      .set(auth(h))
      .send({ title: 'Multi', mode: 'MULTI', seatCount: 12 });
    expect(res.status).toBe(201);
    const roomId = res.body.id as string;
    expect((await watch(roomId, h, VIDEO)).status).toBe(200);
    const after = await seats(roomId);
    expect(after.cinema).toBe(false);
    expect(after.seats.some((s) => s.state === 'LOCKED')).toBe(false);
  });
});
