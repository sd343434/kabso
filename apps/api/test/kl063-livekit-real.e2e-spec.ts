/**
 * KL-063 / CP-010 (and KL-064 / CP-011 seats): the LiveKit adapter against a real LiveKit server. Runs only when
 * LIVEKIT_TEST_URL (plus LIVEKIT_TEST_API_KEY / LIVEKIT_TEST_API_SECRET) is set, e.g. against
 * `livekit-server --dev` (ws://127.0.0.1:7880, devkey / secret); skipped otherwise, like the S3
 * storage suite.
 */
import { createHash, randomUUID } from 'node:crypto';
import { AccessToken, RoomServiceClient, TokenVerifier, TrackSource } from 'livekit-server-sdk';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { LIVE_MEDIA_PROVIDER } from '../src/modules/live/media/live-media.provider.js';
import { LiveKitMediaProvider } from '../src/modules/live/media/livekit-media.provider.js';
import { createTestApp, registerVerified, type TestContext } from './helpers/test-app.js';

const url = process.env.LIVEKIT_TEST_URL;
const key = process.env.LIVEKIT_TEST_API_KEY ?? 'devkey';
const secret = process.env.LIVEKIT_TEST_API_SECRET ?? 'secret';

describe.skipIf(!url)('CP-010 LiveKit adapter against a real server', () => {
  const provider = new LiveKitMediaProvider(url ?? '', key, secret);
  const rooms = new RoomServiceClient((url ?? '').replace(/^ws/, 'http'), key, secret);

  it('tokens grant one room: hosts publish camera and microphone; viewers only watch, hidden', async () => {
    const room = randomUUID();
    const verifier = new TokenVerifier(key, secret);
    const host = await verifier.verify(
      await provider.issueToken({ room, identity: 'h', name: 'Host', publish: true, ttlSeconds: 600 }),
    );
    expect(host.video).toMatchObject({
      roomJoin: true,
      room,
      canPublish: true,
      canSubscribe: true,
      canPublishData: false,
    });
    expect(host.video?.canPublishSources?.sort()).toEqual(['camera', 'microphone']);
    expect(host.video?.hidden).toBeFalsy();
    const viewer = await verifier.verify(
      await provider.issueToken({
        room,
        identity: 'guest:x',
        name: 'Guest 1234',
        publish: false,
        ttlSeconds: 600,
      }),
    );
    expect(viewer.video).toMatchObject({ room, canPublish: false, canSubscribe: true, hidden: true });
    expect(viewer.sub).toBe('guest:x');
    expect((viewer.exp ?? 0) - (viewer.nbf ?? viewer.iat ?? 0)).toBeLessThanOrEqual(600);
  });

  it('lists, closes (idempotently) and removes on the real server', async () => {
    const room = randomUUID();
    await rooms.createRoom({ name: room, emptyTimeout: 60 });
    expect(await provider.listRooms()).toContain(room);
    expect(await provider.listIdentities(room)).toEqual([]);
    await provider.removeParticipant(room, 'nobody');
    await provider.closeRoom(room);
    expect(await provider.listRooms()).not.toContain(room);
    await provider.closeRoom(room);
    expect(await provider.listIdentities(room)).toEqual([]);
  });

  it('accepts only webhooks signed with the server key over the exact body', async () => {
    const body = JSON.stringify({
      id: 'EV_1',
      event: 'participant_joined',
      createdAt: String(Math.floor(Date.now() / 1000)),
      room: { name: 'r1' },
      participant: { identity: 'u1' },
    });
    const sign = async (payload: string, signingSecret: string) => {
      const token = new AccessToken(key, signingSecret);
      token.sha256 = createHash('sha256').update(payload).digest('base64');
      return token.toJwt();
    };
    expect(await provider.parseWebhook(body, await sign(body, secret))).toEqual({
      kind: 'joined',
      room: 'r1',
      identity: 'u1',
    });
    await expect(provider.parseWebhook(body, await sign(body, 'wrong-secret'))).rejects.toThrow();
    await expect(provider.parseWebhook(body.replace('u1', 'u2'), await sign(body, secret))).rejects.toThrow();
  });
});

/**
 * KL-064 / CP-011: seat permissions, room metadata and invitation messages on a real LiveKit
 * server. A participant joins through LiveKit's signalling WebSocket (no media is needed for the
 * permission to apply), so `listParticipants` reports what the server enforces.
 */
describe.skipIf(!url)('CP-011 seats against a real LiveKit server', () => {
  const provider = new LiveKitMediaProvider(url ?? '', key, secret);
  const rooms = new RoomServiceClient((url ?? '').replace(/^ws/, 'http'), key, secret);

  interface Joined {
    close(): void;
  }

  /** Joins `room` as `identity` with a viewer token and waits until the server lists it. */
  async function join(room: string, identity: string): Promise<Joined> {
    const token = await provider.issueToken({
      room,
      identity,
      name: identity,
      publish: false,
      ttlSeconds: 600,
    });
    const ws = new WebSocket(
      `${url}/rtc?access_token=${token}&auto_subscribe=1&protocol=15&sdk=js&version=2.0.0`,
    );
    for (let i = 0; i < 50; i += 1) {
      if ((await provider.listIdentities(room)).includes(identity)) return { close: () => ws.close() };
      await new Promise((r) => setTimeout(r, 100));
    }
    ws.close();
    throw new Error(`${identity} did not join ${room}`);
  }

  async function permissionOf(room: string, identity: string) {
    const participant = (await rooms.listParticipants(room)).find((p) => p.identity === identity);
    const permission = participant?.permission;
    return {
      canPublish: permission?.canPublish ?? false,
      hidden: permission?.hidden ?? false,
      sources: [...(permission?.canPublishSources ?? [])].sort(),
    };
  }

  it('seating grants publishing at once; muting withdraws the microphone; removing revokes publishing', async () => {
    const room = randomUUID();
    const viewer = await join(room, 'guest-1');
    try {
      expect(await permissionOf(room, 'guest-1')).toEqual({ canPublish: false, hidden: true, sources: [] });
      expect(await provider.listParticipants(room)).toEqual([
        { identity: 'guest-1', permission: { visible: false, sources: [] } },
      ]);

      await provider.setPermission(room, 'guest-1', { visible: true, sources: ['camera', 'microphone'] });
      expect(await permissionOf(room, 'guest-1')).toEqual({
        canPublish: true,
        hidden: false,
        sources: [TrackSource.CAMERA, TrackSource.MICROPHONE].sort(),
      });

      await provider.setPermission(room, 'guest-1', { visible: true, sources: ['camera'] });
      expect(await permissionOf(room, 'guest-1')).toEqual({
        canPublish: true,
        hidden: false,
        sources: [TrackSource.CAMERA],
      });

      // AUDIO: a muted guest publishes nothing (and an empty list is never sent as "any source").
      await provider.setPermission(room, 'guest-1', { visible: true, sources: [] });
      expect(await permissionOf(room, 'guest-1')).toEqual({ canPublish: false, hidden: false, sources: [] });

      await provider.setPermission(room, 'guest-1', { visible: false, sources: [] });
      expect(await permissionOf(room, 'guest-1')).toEqual({ canPublish: false, hidden: true, sources: [] });
      // A participant or room that is gone is not an error.
      await provider.setPermission(room, 'nobody', { visible: false, sources: [] });
      await provider.setPermission(randomUUID(), 'nobody', { visible: false, sources: [] });
    } finally {
      viewer.close();
      await provider.closeRoom(room);
    }
  });

  it('writes and reads the seat version in the room metadata; sends the invitation to one identity', async () => {
    const room = randomUUID();
    const invitee = await join(room, 'invitee');
    try {
      await provider.setRoomMetadata(room, JSON.stringify({ seatsVersion: 7 }));
      expect(await provider.roomMetadata(room)).toBe('{"seatsVersion":7}');
      expect((await rooms.listRooms([room]))[0]?.metadata).toBe('{"seatsVersion":7}');
      expect(await provider.roomMetadata(randomUUID())).toBeNull();
      await provider.setRoomMetadata(randomUUID(), '{}');

      // Data packets travel on the WebRTC data channel, which a signalling-only participant does not
      // open; here the server must accept a message addressed to one identity (the app check
      // covers receipt), and refuse one for a room that is not open (callers log and ignore it).
      const payload = JSON.stringify({ type: 'seat-invite', roomId: room });
      await expect(provider.sendData(room, 'invitee', payload)).resolves.toBeUndefined();
      await expect(provider.sendData(randomUUID(), 'invitee', payload)).rejects.toThrow();
    } finally {
      invitee.close();
      await provider.closeRoom(room);
    }
  });

  it('tokens: a seated guest is visible and publishes the seat sources; an AUDIO host the microphone only', async () => {
    const room = randomUUID();
    const verifier = new TokenVerifier(key, secret);
    const audioHost = await verifier.verify(
      await provider.issueToken({
        room,
        identity: 'h',
        name: 'H',
        publish: true,
        sources: ['microphone'],
        ttlSeconds: 600,
      }),
    );
    expect(audioHost.video).toMatchObject({ canPublish: true, canPublishSources: ['microphone'] });
    expect(audioHost.video?.hidden).toBeFalsy();
    const mutedSpeaker = await verifier.verify(
      await provider.issueToken({
        room,
        identity: 's',
        name: 'S',
        publish: true,
        sources: [],
        ttlSeconds: 600,
      }),
    );
    expect(mutedSpeaker.video).toMatchObject({ canPublish: false, canSubscribe: true });
    expect(mutedSpeaker.video?.canPublishSources).toBeUndefined();
    expect(mutedSpeaker.video?.hidden).toBeFalsy();
  });
});

/**
 * KL-064 / CP-011 through the API with the real LiveKit adapter: seating, muting and removing a
 * guest change their permission on the server at once, and every change moves the room's
 * `seatsVersion` metadata; CP-012: a tap's score is written next to it.
 */
describe.skipIf(!url)('CP-011 seats through the API on a real LiveKit server', () => {
  const provider = new LiveKitMediaProvider(url ?? '', key, secret);
  const rooms = new RoomServiceClient((url ?? '').replace(/^ws/, 'http'), key, secret);
  let ctx: TestContext;

  beforeAll(async () => {
    ctx = await createTestApp({ LIVE_HOSTING_ENABLED: 'true' }, [
      { token: LIVE_MEDIA_PROVIDER, value: provider },
    ]);
  });
  afterAll(async () => ctx?.close());

  it('accept → publish (camera + microphone), mute → camera only, remove → none; metadata follows', async () => {
    const signup = async () => {
      const { res } = await registerVerified(ctx);
      return { id: res.body.user.id as string, token: res.body.tokens.accessToken as string };
    };
    const [host, guest] = [await signup(), await signup()];
    await ctx.prisma.liveHost.create({ data: { userId: host.id, source: 'ADMIN' } });
    const bearer = (u: { token: string }) => ({ Authorization: `Bearer ${u.token}` });
    const created = await ctx.http
      .post('/api/v1/live/rooms')
      .set(bearer(host))
      .send({ title: 'Real seats', mode: 'MULTI', seatCount: 4 });
    expect(created.status).toBe(201);
    const roomId = created.body.id as string;
    const base = `/api/v1/live/rooms/${roomId}`;

    // The guest watches with the token the API gives them (a hidden viewer).
    const access = await ctx.http.post(`${base}/media-token`).set(bearer(guest)).send({});
    expect(access.body.role).toBe('VIEWER');
    const ws = new WebSocket(
      `${access.body.url}/rtc?access_token=${access.body.token}&auto_subscribe=1&protocol=15&sdk=js&version=2.0.0`,
    );
    const permission = async () => {
      const p = (await rooms.listParticipants(roomId)).find((x) => x.identity === guest.id)?.permission;
      return {
        canPublish: p?.canPublish ?? false,
        hidden: p?.hidden ?? false,
        sources: [...(p?.canPublishSources ?? [])].sort(),
      };
    };
    const metadata = async () => (await rooms.listRooms([roomId]))[0]?.metadata;
    try {
      for (let i = 0; i < 50 && !(await provider.listIdentities(roomId)).includes(guest.id); i += 1) {
        await new Promise((r) => setTimeout(r, 100));
      }
      expect(await permission()).toEqual({ canPublish: false, hidden: true, sources: [] });

      const asked = await ctx.http.post(`${base}/seat-requests`).set(bearer(guest)).send({});
      expect(asked.status).toBe(201);
      // CP-012: the score rides next to the seat version.
      expect(await metadata()).toBe('{"seatsVersion":1,"score":0}');
      const accepted = await ctx.http
        .post(`${base}/seat-requests/${asked.body.id}/accept`)
        .set(bearer(host))
        .send({});
      expect(accepted.status).toBe(200);
      expect(await permission()).toEqual({
        canPublish: true,
        hidden: false,
        sources: [TrackSource.CAMERA, TrackSource.MICROPHONE].sort(),
      });
      expect(await metadata()).toBe('{"seatsVersion":2,"score":0}');

      await ctx.http.post(`${base}/seats/1/mute`).set(bearer(host)).send({ muted: true }).expect(200);
      expect(await permission()).toEqual({ canPublish: true, hidden: false, sources: [TrackSource.CAMERA] });
      expect(await metadata()).toBe('{"seatsVersion":3,"score":0}');

      // CP-012: the seated guest's taps count; the score reaches the room metadata next to the
      // seat version (the first write of a room is immediate), and the next seat change keeps it.
      const tapped = await ctx.http.post(`${base}/taps`).set(bearer(guest)).send({ count: 5 });
      expect(tapped.status).toBe(200);
      expect(tapped.body).toEqual({ accepted: 5, score: { total: 5, tapPoints: 5, supportPoints: 0 } });
      expect(await metadata()).toBe('{"seatsVersion":3,"score":5}');

      await ctx.http.post(`${base}/seats/1/remove`).set(bearer(host)).send({}).expect(200);
      expect(await permission()).toEqual({ canPublish: false, hidden: true, sources: [] });
      expect(await metadata()).toBe('{"seatsVersion":4,"score":5}');
    } finally {
      ws.close();
      await ctx.http.post(`${base}/end`).set(bearer(host)).expect(200);
    }
    expect(await provider.listRooms()).not.toContain(roomId);
  });
});
