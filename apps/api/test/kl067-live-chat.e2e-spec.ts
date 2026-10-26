/**
 * KL-067 / CP-013 (D96): live room chat (openapi v1.9-live DRAFT, CONVENTIONS §10.11, §4, §7,
 * §11.7), end to end against PostgreSQL + Redis with the API as the DML-only runtime role.
 *
 * Time: the 1-a-second counting rule and the "joined" line throttle read "now" from the injectable
 * Clock; these tests move a FakeClock instead of sleeping. The media server is the in-memory fake
 * behind the LiveMediaProvider port, which records every broadcast data message; the last suite
 * runs against a real LiveKit server (LIVEKIT_TEST_URL) with a real participant that receives the
 * `chat` data messages on topic `chat`.
 */
import { randomUUID } from 'node:crypto';
import type request from 'supertest';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { Clock } from '../src/common/time/clock.js';
import { LiveMediaService } from '../src/modules/live/live-media.service.js';
import { LiveRoomsService } from '../src/modules/live/live-rooms.service.js';
import { LIVE_MEDIA_PROVIDER } from '../src/modules/live/media/live-media.provider.js';
import { LiveKitMediaProvider } from '../src/modules/live/media/livekit-media.provider.js';
import { MemoryLiveMedia } from './helpers/memory-live-media.js';
import { expectContract, operations } from './helpers/openapi.js';
import {
  createTestApp,
  registerVerified,
  withMigrationClient,
  type TestContext,
} from './helpers/test-app.js';

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

interface ChatMessage {
  id: string;
  roomId: string;
  author: { id: string; username: string };
  authorRole: string;
  text: string;
  createdAt: string;
}

const MISSING_ROOM = '0192f1d0-0000-7000-8000-000000000000';
const DAY_MS = 24 * 3600_000;

const CHAT_OPERATIONS = [
  'sendLiveChatMessage POST /api/v1/live/rooms/{roomId}/chat',
  'listLiveChatMessages GET /api/v1/live/rooms/{roomId}/chat',
  'deleteLiveChatMessage DELETE /api/v1/live/rooms/{roomId}/chat/{messageId}',
  'listLiveChatMutes GET /api/v1/live/rooms/{roomId}/chat/mutes',
  'muteLiveChatUser PUT /api/v1/live/rooms/{roomId}/chat/mutes/{username}',
  'unmuteLiveChatUser DELETE /api/v1/live/rooms/{roomId}/chat/mutes/{username}',
];

describe('CP-013 contract coverage', () => {
  it('openapi declares exactly the six chat operations', () => {
    expect(
      operations()
        .filter((o) => /^\/api\/v1\/live\/rooms\/\{roomId\}\/chat(\/|$)/.test(o.path))
        .map((o) => `${o.operationId} ${o.method.toUpperCase()} ${o.path}`)
        .sort(),
    ).toEqual([...CHAT_OPERATIONS].sort());
  });
});

/** Shared helpers for an app context (fake or real media server). */
function helpers(get: () => TestContext) {
  const auth = (u: TestUser) => ({ Authorization: `Bearer ${u.token}` });
  const signup = async (): Promise<TestUser> => {
    const { res } = await registerVerified(get());
    expect(res.status).toBe(201);
    return { id: res.body.user.id, username: res.body.user.username, token: res.body.tokens.accessToken };
  };
  const host = async (): Promise<TestUser> => {
    const u = await signup();
    await get().prisma.liveHost.create({ data: { userId: u.id, source: 'ADMIN' } });
    return u;
  };
  const goLive = async (u: TestUser, extra: object = {}): Promise<string> => {
    const res = await get()
      .http.post('/api/v1/live/rooms')
      .set(auth(u))
      .send({ title: 'Chat', ...extra });
    expect(res.status).toBe(201);
    expectContract(res, 'startLiveRoom');
    expect(res.body).toMatchObject({ chatEnabled: true, chatMuted: false });
    return res.body.id as string;
  };
  const end = async (roomId: string, u: TestUser) => {
    const res = await get().http.post(`/api/v1/live/rooms/${roomId}/end`).set(auth(u));
    expect(res.status).toBe(200);
    expectContract(res, 'endLiveRoom');
  };
  const send = (roomId: string, u: TestUser | null, body: unknown): request.Test => {
    const req = get().http.post(`/api/v1/live/rooms/${roomId}/chat`);
    if (u) void req.set(auth(u));
    return req.send(body as object);
  };
  const say = async (roomId: string, u: TestUser, text: string, clientId = randomUUID()) => {
    const res = await send(roomId, u, { text, clientId });
    expectContract(res, 'sendLiveChatMessage');
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    return res.body as ChatMessage;
  };
  const list = async (roomId: string, u?: TestUser) => {
    const req = get().http.get(`/api/v1/live/rooms/${roomId}/chat`);
    if (u) void req.set(auth(u));
    const res = await req;
    expectContract(res, 'listLiveChatMessages');
    return res;
  };
  const texts = async (roomId: string, u?: TestUser) =>
    ((await list(roomId, u)).body.data as ChatMessage[]).map((m) => m.text);
  const room = async (roomId: string, u?: TestUser) => {
    const req = get().http.get(`/api/v1/live/rooms/${roomId}`);
    if (u) void req.set(auth(u));
    const res = await req;
    expectContract(res, 'getLiveRoom');
    return res;
  };
  const hook = (event: string, roomName: string, identity: string) => {
    const raw = JSON.stringify({ event, room: { name: roomName }, participant: { identity } });
    return get()
      .http.post('/internal/livekit/webhook')
      .set('Content-Type', 'application/webhook+json')
      .set('Authorization', MemoryLiveMedia.sign(raw))
      .send(raw);
  };
  /** The user is in the room's media session (as the media server's webhook reports it). */
  const join = async (roomId: string, u: TestUser) => {
    expect((await hook('participant_joined', roomId, u.id)).status).toBe(200);
  };
  const mute = (roomId: string, by: TestUser, username: string) =>
    get().http.put(`/api/v1/live/rooms/${roomId}/chat/mutes/${username}`).set(auth(by));
  const unmute = (roomId: string, by: TestUser, username: string) =>
    get().http.delete(`/api/v1/live/rooms/${roomId}/chat/mutes/${username}`).set(auth(by));
  const remove = (roomId: string, by: TestUser, messageId: string) =>
    get().http.delete(`/api/v1/live/rooms/${roomId}/chat/${messageId}`).set(auth(by));
  const patch = (roomId: string, by: TestUser, body: object) =>
    get().http.patch(`/api/v1/live/rooms/${roomId}`).set(auth(by)).send(body);
  /** A MULTI room with `mod` as moderator (in the room) and `speaker` on seat 1. */
  const seatedRoom = async (h: TestUser, mod: TestUser, speaker?: TestUser) => {
    const roomId = await goLive(h, { mode: 'MULTI', seatCount: 4 });
    await join(roomId, mod);
    const added = await get()
      .http.put(`/api/v1/live/rooms/${roomId}/moderators/${mod.username}`)
      .set(auth(h));
    expect(added.status).toBe(200);
    if (speaker) {
      await join(roomId, speaker);
      const asked = await get()
        .http.post(`/api/v1/live/rooms/${roomId}/seat-requests`)
        .set(auth(speaker))
        .send({});
      expect(asked.status).toBe(201);
      const accepted = await get()
        .http.post(`/api/v1/live/rooms/${roomId}/seat-requests/${asked.body.id}/accept`)
        .set(auth(h))
        .send({});
      expect(accepted.status).toBe(200);
    }
    return roomId;
  };
  return {
    auth,
    signup,
    host,
    goLive,
    end,
    send,
    say,
    list,
    texts,
    room,
    hook,
    join,
    mute,
    unmute,
    remove,
    patch,
    seatedRoom,
  };
}

describe('CP-013 live room chat', () => {
  const clock = new FakeClock();
  const media = new MemoryLiveMedia();
  let ctx: TestContext;
  const h = helpers(() => ctx);
  const { auth, signup, host, goLive, end, send, say, list, texts, room, join, mute, unmute, remove, patch } =
    h;

  /** Moves past the 1-a-second counting rule. */
  const tick = () => clock.advance(1.01);
  const chats = (roomId: string) => media.broadcastsOf(roomId, 'chat');

  beforeAll(async () => {
    ctx = await createTestApp({ LIVE_HOSTING_ENABLED: 'true', LIVE_HEARTBEAT_STALE_SECONDS: '3600' }, [
      { token: Clock, value: clock },
      { token: LIVE_MEDIA_PROVIDER, value: media },
    ]);
    ctx.app.getHttpServer().setMaxListeners(64);
  });
  afterAll(async () => ctx?.close());

  describe('sending', () => {
    it('the host sends without being in the media session; the line reaches the room on topic `chat`', async () => {
      const owner = await host();
      const roomId = await goLive(owner);
      const message = await say(roomId, owner, '  أهلاً بالجميع 👋  ');
      expect(message).toMatchObject({
        roomId,
        author: { id: owner.id, username: owner.username },
        authorRole: 'HOST',
        text: 'أهلاً بالجميع 👋',
      });
      expect(message.createdAt).toBe(clock.now().toISOString());
      const sent = media.broadcasts.filter((b) => b.room === roomId);
      expect(sent).toEqual([
        { room: roomId, topic: 'chat', payload: JSON.stringify({ type: 'chat', message }) },
      ]);
      await end(roomId, owner);
    });

    it('a viewer must be in the room now (a media-session row): 403 LIVE_CHAT_NOT_IN_ROOM, then 201 VIEWER', async () => {
      const owner = await host();
      const v = await signup();
      const roomId = await goLive(owner);
      const refused = await send(roomId, v, { text: 'hi', clientId: randomUUID() });
      expect(refused.status).toBe(403);
      expect(refused.body.error.code).toBe('LIVE_CHAT_NOT_IN_ROOM');
      expectContract(refused, 'sendLiveChatMessage');
      expect(chats(roomId)).toEqual([]);

      await join(roomId, v);
      expect((await say(roomId, v, 'hi')).authorRole).toBe('VIEWER');

      // Leaving the media session: not in the room any more.
      expect((await h.hook('participant_left', roomId, v.id)).status).toBe(200);
      tick();
      expect((await send(roomId, v, { text: 'again', clientId: randomUUID() })).body.error.code).toBe(
        'LIVE_CHAT_NOT_IN_ROOM',
      );
      await end(roomId, owner);
    });

    it('authorRole is the role at sending: MODERATOR, SPEAKER (seated)', async () => {
      const [owner, mod, speaker] = [await host(), await signup(), await signup()];
      const roomId = await h.seatedRoom(owner, mod, speaker);
      expect((await say(roomId, mod, 'mod here')).authorRole).toBe('MODERATOR');
      expect((await say(roomId, speaker, 'on a seat')).authorRole).toBe('SPEAKER');
      // Off the seat: a viewer again; earlier lines keep their role.
      await ctx.http.post(`/api/v1/live/rooms/${roomId}/seats/me/leave`).set(auth(speaker)).expect(204);
      tick();
      expect((await say(roomId, speaker, 'back in the audience')).authorRole).toBe('VIEWER');
      expect(((await list(roomId)).body.data as ChatMessage[]).map((m) => m.authorRole)).toEqual([
        'MODERATOR',
        'SPEAKER',
        'VIEWER',
      ]);
      await end(roomId, owner);
    });

    it('text rules: NFC, trimmed, 1–200 code points, §6 hygiene, no line breaks (400)', async () => {
      const owner = await host();
      const roomId = await goLive(owner);
      const issue = async (body: unknown) => {
        const res = await send(roomId, owner, body);
        expect(res.status).toBe(400);
        expectContract(res, 'sendLiveChatMessage');
        return res.body.error.details as { field: string; issue: string }[];
      };
      expect(await issue({ text: '', clientId: randomUUID() })).toEqual([
        { field: 'text', issue: 'required' },
      ]);
      expect(await issue({ text: '   ', clientId: randomUUID() })).toEqual([
        { field: 'text', issue: 'required' },
      ]);
      expect(await issue({ clientId: randomUUID() })).toEqual([{ field: 'text', issue: 'required' }]);
      expect(await issue({ text: 'x'.repeat(201), clientId: randomUUID() })).toEqual([
        { field: 'text', issue: 'too_long' },
      ]);
      for (const text of ['a\nb', 'a\rb', 'a b', 'a b', 'a‮b', 'a​b']) {
        expect(await issue({ text, clientId: randomUUID() })).toEqual([
          { field: 'text', issue: 'invalid_format' },
        ]);
      }
      expect(await issue({ text: 'hi' })).toEqual([{ field: 'clientId', issue: 'required' }]);
      expect(await issue({ text: 'hi', clientId: 'not-a-uuid' })).toEqual([
        { field: 'clientId', issue: 'invalid_format' },
      ]);
      expect(await issue({ text: 'hi', clientId: randomUUID(), extra: 1 })).toEqual([
        { field: 'extra', issue: 'unknown_field' },
      ]);
      // 200 code points (emoji with a skin tone are 2 each) and NFC.
      const emoji = '\u{1F44D}\u{1F3FD}'.repeat(100);
      expect((await say(roomId, owner, emoji)).text).toBe(emoji);
      tick();
      expect((await say(roomId, owner, 'é')).text).toBe('é');
      expect(chats(roomId)).toHaveLength(2);
      await end(roomId, owner);
    });

    it('check order: 401, 404 (unknown, blocked with the host), 409 ended, 400 text, then 403', async () => {
      const owner = await host();
      const [v, blocked] = [await signup(), await signup()];
      const roomId = await goLive(owner);

      const guest = await send(roomId, null, { text: 'hi', clientId: randomUUID() });
      expect(guest.status).toBe(401);
      expectContract(guest, 'sendLiveChatMessage');
      expect((await send(MISSING_ROOM, v, { text: '', clientId: randomUUID() })).status).toBe(404);
      expect((await send('nope', v, { text: 'hi', clientId: randomUUID() })).status).toBe(404);
      await ctx.http.put(`/api/v1/users/${blocked.username}/block`).set(auth(owner)).expect(200);
      expect((await send(roomId, blocked, { text: '', clientId: randomUUID() })).status).toBe(404);
      // Bad text before "not in the room".
      const bad = await send(roomId, v, { text: 'a\nb', clientId: randomUUID() });
      expect(bad.status).toBe(400);

      await end(roomId, owner);
      const ended = await send(roomId, owner, { text: '', clientId: randomUUID() });
      expect(ended.status).toBe(409);
      expect(ended.body.error.code).toBe('LIVE_ROOM_ENDED');
      expectContract(ended, 'sendLiveChatMessage');
    });

    it('a retry with the same clientId → 200 with the first message, and no second data message', async () => {
      const owner = await host();
      const v = await signup();
      const roomId = await goLive(owner);
      await join(roomId, v);
      const clientId = randomUUID();
      const first = await say(roomId, v, 'once', clientId);
      // Immediately (the counting rule does not refuse a retry) and with another text.
      const retry = await send(roomId, v, { text: 'twice?', clientId: clientId.toUpperCase() });
      expect(retry.status).toBe(200);
      expectContract(retry, 'sendLiveChatMessage');
      expect(retry.body).toEqual(first);
      expect(chats(roomId)).toHaveLength(1);
      expect(await texts(roomId)).toEqual(['once']);

      // Concurrent retries store one message.
      tick();
      const again = randomUUID();
      const raced = await Promise.all(
        Array.from({ length: 4 }, () => send(roomId, owner, { text: 'race', clientId: again })),
      );
      // Exactly one stores it; the others answer with it (or, still racing it, 429 for the
      // counting rule); never a second message.
      expect(raced.filter((r) => r.status === 201)).toHaveLength(1);
      expect(raced.every((r) => [200, 201, 429].includes(r.status))).toBe(true);
      const ids = raced.filter((r) => r.status !== 429).map((r) => (r.body as ChatMessage).id);
      expect(new Set(ids).size).toBe(1);
      expect(await ctx.prisma.liveChatMessage.count({ where: { userId: owner.id, clientId: again } })).toBe(
        1,
      );
      expect(chats(roomId)).toHaveLength(2);
      // The same clientId from another sender is another message.
      tick();
      const other = await send(roomId, owner, { text: 'mine', clientId });
      expect(other.status).toBe(201);
      expect(other.body.id).not.toBe(first.id);
      await end(roomId, owner);
    });
  });

  describe('rate limits', () => {
    it('1 a second per user and room: 429 with Retry-After; other rooms and users are separate', async () => {
      const [a, b] = [await host(), await host()];
      const v = await signup();
      const [roomA, roomB] = [await goLive(a), await goLive(b)];
      await join(roomA, v);
      await join(roomB, v);
      await say(roomA, v, 'one');
      const limited = await send(roomA, v, { text: 'two', clientId: randomUUID() });
      expect(limited.status).toBe(429);
      expect(limited.body.error.code).toBe('RATE_LIMITED');
      expect(limited.headers['retry-after']).toBe('1');
      expectContract(limited, 'sendLiveChatMessage');
      // Another room and another user are not limited by it.
      await say(roomB, v, 'elsewhere');
      await say(roomA, a, 'host');
      clock.advance(0.5);
      expect((await send(roomA, v, { text: 'two', clientId: randomUUID() })).status).toBe(429);
      clock.advance(0.5);
      await say(roomA, v, 'two');
      expect(await texts(roomA)).toEqual(['one', 'host', 'two']);
      // Refused messages are never sent to the room.
      expect(chats(roomA)).toHaveLength(3);
      await end(roomA, a);
      await end(roomB, b);
    });

    describe('20 / min per user (replaces the default)', () => {
      let limitedCtx: TestContext;
      const lh = helpers(() => limitedCtx);
      const limitedClock = new FakeClock();
      beforeAll(async () => {
        limitedCtx = await createTestApp(
          {
            LIVE_HOSTING_ENABLED: 'true',
            LIVE_HEARTBEAT_STALE_SECONDS: '3600',
            RATE_LIMIT_LIVE_CHAT_USER: '3/60',
            // The default per-user bucket would refuse the 2nd request if it applied.
            RATE_LIMIT_AUTHENTICATED_USER: '1/900',
          },
          [
            { token: Clock, value: limitedClock },
            { token: LIVE_MEDIA_PROVIDER, value: new MemoryLiveMedia() },
          ],
        );
      });
      afterAll(async () => limitedCtx?.close());

      it('the 4th message in the window → 429 RATE_LIMITED with Retry-After', async () => {
        const owner = await lh.signup();
        await limitedCtx.prisma.liveHost.create({ data: { userId: owner.id, source: 'ADMIN' } });
        // Go live through the service bucket only (the start buckets are generous).
        const res = await limitedCtx.http
          .post('/api/v1/live/rooms')
          .set(lh.auth(owner))
          .send({ title: 'Limited' });
        expect(res.status).toBe(201);
        const roomId = res.body.id as string;
        for (let i = 0; i < 3; i += 1) {
          const ok = await lh.send(roomId, owner, { text: `m${i}`, clientId: randomUUID() });
          expect(ok.status).toBe(201);
          limitedClock.advance(1.01);
        }
        const limited = await lh.send(roomId, owner, { text: 'm3', clientId: randomUUID() });
        expect(limited.status).toBe(429);
        expect(limited.body.error.code).toBe('RATE_LIMITED');
        expect(Number(limited.headers['retry-after'])).toBeGreaterThan(0);
      });
    });
  });

  describe('chat mutes', () => {
    it('host mutes a viewer: 403 LIVE_CHAT_MUTED, chatMuted on the room; idempotent; unmute', async () => {
      const owner = await host();
      const [v, other] = [await signup(), await signup()];
      const roomId = await goLive(owner);
      await join(roomId, v);
      await join(roomId, other);
      const earlier = await say(roomId, v, 'before the mute');

      const mutedAt = clock.now().toISOString();
      const muted = await mute(roomId, owner, v.username);
      expect(muted.status).toBe(204);
      expectContract(muted, 'muteLiveChatUser');
      expect((await mute(roomId, owner, v.username)).status).toBe(204); // idempotent

      tick();
      const refused = await send(roomId, v, { text: 'muted?', clientId: randomUUID() });
      expect(refused.status).toBe(403);
      expect(refused.body.error.code).toBe('LIVE_CHAT_MUTED');
      expectContract(refused, 'sendLiveChatMessage');
      // Earlier messages stay; others still chat.
      expect((await list(roomId)).body.data.map((m: ChatMessage) => m.id)).toEqual([earlier.id]);
      await say(roomId, other, 'still here');

      expect((await room(roomId, v)).body).toMatchObject({ chatEnabled: true, chatMuted: true });
      expect((await room(roomId, other)).body.chatMuted).toBe(false);
      expect((await room(roomId)).body.chatMuted).toBe(false); // a guest

      const listed = await ctx.http.get(`/api/v1/live/rooms/${roomId}/chat/mutes`).set(auth(owner));
      expect(listed.status).toBe(200);
      expectContract(listed, 'listLiveChatMutes');
      expect(listed.body.data).toEqual([
        {
          user: expect.objectContaining({ id: v.id, username: v.username }),
          mutedAt,
        },
      ]);

      const unmuted = await unmute(roomId, owner, v.username);
      expect(unmuted.status).toBe(204);
      expectContract(unmuted, 'unmuteLiveChatUser');
      expect((await unmute(roomId, owner, v.username)).status).toBe(204); // idempotent
      await say(roomId, v, 'unmuted');
      expect((await room(roomId, v)).body.chatMuted).toBe(false);
      await end(roomId, owner);
    });

    it('mutes last for this live only', async () => {
      const owner = await host();
      const v = await signup();
      const first = await goLive(owner);
      await join(first, v);
      expect((await mute(first, owner, v.username)).status).toBe(204);
      await end(first, owner);
      const second = await goLive(owner);
      await join(second, v);
      expect((await room(second, v)).body.chatMuted).toBe(false);
      await say(second, v, 'new live, new chat');
      await end(second, owner);
    });

    it('who may mute: host and moderators; nobody mutes the host; a moderator never mutes a moderator', async () => {
      const [owner, mod, mod2, v] = [await host(), await signup(), await signup(), await signup()];
      const roomId = await h.seatedRoom(owner, mod);
      await join(roomId, mod2);
      await ctx.http
        .put(`/api/v1/live/rooms/${roomId}/moderators/${mod2.username}`)
        .set(auth(owner))
        .expect(200);
      await join(roomId, v);

      const forbidden = async (res: request.Response) => {
        expect(res.status).toBe(403);
        expect(res.body.error.code).toBe('AUTH_FORBIDDEN');
        expectContract(res, 'muteLiveChatUser');
      };
      await forbidden(await mute(roomId, v, mod.username)); // a viewer
      await forbidden(await mute(roomId, mod, owner.username)); // the host
      await forbidden(await mute(roomId, owner, owner.username)); // nobody mutes the host
      await forbidden(await mute(roomId, mod, mod2.username)); // another moderator
      await forbidden(await mute(roomId, mod, mod.username)); // a moderator is a moderator
      await forbidden(await unmute(roomId, mod, mod2.username));

      expect((await mute(roomId, mod, v.username)).status).toBe(204);
      clock.advance(1);
      // The host may mute a moderator; that moderator can no longer send.
      expect((await mute(roomId, owner, mod2.username)).status).toBe(204);
      expect((await send(roomId, mod2, { text: 'hi', clientId: randomUUID() })).body.error.code).toBe(
        'LIVE_CHAT_MUTED',
      );

      const unknown = await mute(roomId, owner, 'nobody_here_x');
      expect(unknown.status).toBe(404);
      expectContract(unknown, 'muteLiveChatUser');

      // The list: host and moderators only, newest first.
      const byMod = await ctx.http.get(`/api/v1/live/rooms/${roomId}/chat/mutes`).set(auth(mod));
      expect(byMod.status).toBe(200);
      expect(byMod.body.data.map((m: { user: { id: string } }) => m.user.id)).toEqual([mod2.id, v.id]);
      const byViewer = await ctx.http.get(`/api/v1/live/rooms/${roomId}/chat/mutes`).set(auth(v));
      expect(byViewer.status).toBe(403);
      expectContract(byViewer, 'listLiveChatMutes');

      await end(roomId, owner);
      const ended = await mute(roomId, owner, v.username);
      expect(ended.status).toBe(409);
      expect(ended.body.error.code).toBe('LIVE_ROOM_ENDED');
    });
  });

  describe('turning the chat off', () => {
    it('host only: chat-state sent, viewers get 409 LIVE_CHAT_CLOSED, the host still sends', async () => {
      const owner = await host();
      const v = await signup();
      const roomId = await goLive(owner);
      await join(roomId, v);

      const off = await patch(roomId, owner, { chatEnabled: false });
      expect(off.status).toBe(200);
      expectContract(off, 'updateLiveRoom');
      expect(off.body).toMatchObject({ chatEnabled: false, chatMuted: false });
      expect(media.broadcastsOf(roomId, 'chat-state')).toEqual([{ type: 'chat-state', enabled: false }]);
      expect(await ctx.prisma.auditLog.count({ where: { action: 'live.room.chat', targetId: roomId } })).toBe(
        1,
      );
      // Idempotent: no second data message.
      expect((await patch(roomId, owner, { chatEnabled: false })).status).toBe(200);
      expect(media.broadcastsOf(roomId, 'chat-state')).toHaveLength(1);
      expect((await room(roomId, v)).body.chatEnabled).toBe(false);

      const closed = await send(roomId, v, { text: 'hello?', clientId: randomUUID() });
      expect(closed.status).toBe(409);
      expect(closed.body.error.code).toBe('LIVE_CHAT_CLOSED');
      expectContract(closed, 'sendLiveChatMessage');
      await say(roomId, owner, 'only me for now');

      // A viewer cannot switch it (not their room → 404).
      expect((await patch(roomId, v, { chatEnabled: true })).status).toBe(404);
      const on = await patch(roomId, owner, { chatEnabled: true, allowGuests: true });
      expect(on.status).toBe(200);
      expect(on.body.chatEnabled).toBe(true);
      expect(media.broadcastsOf(roomId, 'chat-state')).toEqual([
        { type: 'chat-state', enabled: false },
        { type: 'chat-state', enabled: true },
      ]);
      await say(roomId, v, 'open again');
      expect((await patch(roomId, owner, { chatEnabled: 'no' })).status).toBe(400);
      await end(roomId, owner);
    });
  });

  describe('deleting', () => {
    it('author, host and moderators; a moderator never deletes the host’s or another moderator’s', async () => {
      const [owner, mod, mod2, v, w] = [
        await host(),
        await signup(),
        await signup(),
        await signup(),
        await signup(),
      ];
      const roomId = await h.seatedRoom(owner, mod);
      await join(roomId, mod2);
      await ctx.http
        .put(`/api/v1/live/rooms/${roomId}/moderators/${mod2.username}`)
        .set(auth(owner))
        .expect(200);
      await join(roomId, v);
      await join(roomId, w);
      const byHost = await say(roomId, owner, 'host line');
      const byMod2 = await say(roomId, mod2, 'mod2 line');
      const byV = await say(roomId, v, 'v line');
      const byW = await say(roomId, w, 'w line');
      const byMod = await say(roomId, mod, 'mod line');

      const forbidden = async (res: request.Response) => {
        expect(res.status).toBe(403);
        expect(res.body.error.code).toBe('AUTH_FORBIDDEN');
        expectContract(res, 'deleteLiveChatMessage');
      };
      await forbidden(await remove(roomId, w, byV.id)); // a viewer, not the author
      await forbidden(await remove(roomId, mod, byHost.id));
      await forbidden(await remove(roomId, mod, byMod2.id));

      const own = await remove(roomId, v, byV.id);
      expect(own.status).toBe(204);
      expectContract(own, 'deleteLiveChatMessage');
      expect((await remove(roomId, v, byV.id)).status).toBe(204); // idempotent
      expect(media.broadcastsOf(roomId, 'chat-delete')).toEqual([{ type: 'chat-delete', id: byV.id }]);

      expect((await remove(roomId, mod, byW.id)).status).toBe(204);
      expect((await remove(roomId, mod, byMod.id)).status).toBe(204); // their own
      expect((await remove(roomId, owner, byMod2.id)).status).toBe(204);
      expect(await texts(roomId)).toEqual(['host line']);
      expect(media.broadcastsOf(roomId, 'chat-delete').map((d) => d.id)).toEqual([
        byV.id,
        byW.id,
        byMod.id,
        byMod2.id,
      ]);
      const row = await ctx.prisma.liveChatMessage.findUnique({ where: { id: byW.id } });
      expect(row).toMatchObject({ deletedById: mod.id, deletedAt: clock.now() });

      const unknown = await remove(roomId, owner, randomUUID());
      expect(unknown.status).toBe(404);
      expectContract(unknown, 'deleteLiveChatMessage');
      expect((await remove(roomId, owner, 'not-a-uuid')).status).toBe(404);
      // A message of another room is not found here.
      const other = await host();
      const otherRoom = await goLive(other);
      expect((await remove(otherRoom, other, byHost.id)).status).toBe(404);
      await end(otherRoom, other);

      await end(roomId, owner);
      const ended = await remove(roomId, owner, byHost.id);
      expect(ended.status).toBe(409);
      expect(ended.body.error.code).toBe('LIVE_ROOM_ENDED');
      expectContract(ended, 'deleteLiveChatMessage');
    });
  });

  describe('reading', () => {
    it('the last 50, oldest first, without deleted ones', async () => {
      const owner = await host();
      const roomId = await goLive(owner);
      const sent: ChatMessage[] = [];
      for (let i = 0; i < 53; i += 1) {
        sent.push(await say(roomId, owner, `m${i}`));
        tick();
      }
      const res = await list(roomId, owner);
      expect(res.status).toBe(200);
      expect(res.body.data.map((m: ChatMessage) => m.text)).toEqual(sent.slice(3).map((m) => m.text));
      expect(res.body.data[0]).toEqual(sent[3]);
      await remove(roomId, owner, sent[52]!.id).expect(204);
      const after = (await list(roomId, owner)).body.data as ChatMessage[];
      expect(after).toHaveLength(50);
      expect(after.map((m) => m.text)).toEqual(sent.slice(2, 52).map((m) => m.text));
      await end(roomId, owner);
    });

    it('guests read when the room allows guests (else 403); ended rooms stay readable; 404 when unseen', async () => {
      const owner = await host();
      const [v, blocked] = [await signup(), await signup()];
      const roomId = await goLive(owner);
      await say(roomId, owner, 'welcome');

      const asGuest = await list(roomId);
      expect(asGuest.status).toBe(200);
      expect(asGuest.body.data.map((m: ChatMessage) => m.text)).toEqual(['welcome']);

      expect((await patch(roomId, owner, { allowGuests: false })).status).toBe(200);
      const refused = await list(roomId);
      expect(refused.status).toBe(403);
      expect(refused.body.error.code).toBe('LIVE_GUESTS_NOT_ALLOWED');
      expect((await list(roomId, v)).status).toBe(200);

      expect((await list(MISSING_ROOM, v)).status).toBe(404);
      expect((await list(MISSING_ROOM)).status).toBe(404);
      await ctx.http.put(`/api/v1/users/${blocked.username}/block`).set(auth(owner)).expect(200);
      expect((await list(roomId, blocked)).status).toBe(404);

      await end(roomId, owner);
      expect(await texts(roomId, v)).toEqual(['welcome']);
      expect((await list(roomId)).status).toBe(403); // still no guests
    });

    it('a signed-in reader gets no messages from someone they blocked or who blocked them', async () => {
      const owner = await host();
      const [a, b, c] = [await signup(), await signup(), await signup()];
      const roomId = await goLive(owner);
      for (const u of [a, b, c]) await join(roomId, u);
      await say(roomId, a, 'from a');
      await say(roomId, b, 'from b');
      await say(roomId, c, 'from c');

      await ctx.http.put(`/api/v1/users/${b.username}/block`).set(auth(a)).expect(200); // a blocked b
      await ctx.http.put(`/api/v1/users/${c.username}/block`).set(auth(b)).expect(200); // b blocked c
      expect(await texts(roomId, a)).toEqual(['from a', 'from c']);
      expect(await texts(roomId, b)).toEqual(['from b']);
      expect(await texts(roomId, c)).toEqual(['from a', 'from c']);
      expect(await texts(roomId, owner)).toEqual(['from a', 'from b', 'from c']);
      expect(await texts(roomId)).toEqual(['from a', 'from b', 'from c']);
      await end(roomId, owner);
    });
  });

  describe('reports', () => {
    const admin = async (): Promise<TestUser> => {
      const u = await signup();
      await withMigrationClient(async (c) => {
        await c.user.update({ where: { id: u.id }, data: { role: 'ADMIN' } });
        await c.userAdminPermission.create({ data: { userId: u.id, permission: 'MODERATION' } });
      });
      return u;
    };
    const report = (u: TestUser, targetId: string) =>
      ctx.http
        .post('/api/v1/reports')
        .set(auth(u))
        .send({ targetType: 'LIVE_CHAT_MESSAGE', targetId, reason: 'HATE' });

    it('a message the reporter can read (not their own); REMOVE_TARGET deletes it', async () => {
      const [owner, reporter, author, mod] = [await host(), await signup(), await signup(), await admin()];
      const roomId = await goLive(owner);
      await join(roomId, author);
      const message = await say(roomId, author, 'something nasty');

      expect((await report(author, message.id)).status).toBe(400); // own message
      const created = await report(reporter, message.id);
      expect(created.status).toBe(201);
      expectContract(created, 'createReport');
      expect(created.body).toMatchObject({
        targetType: 'LIVE_CHAT_MESSAGE',
        targetId: message.id,
        status: 'OPEN',
      });
      const repeat = await report(reporter, message.id);
      expect(repeat.status).toBe(200);
      expect(repeat.body.id).toBe(created.body.id);
      expect((await report(reporter, randomUUID())).status).toBe(404);
      expect((await report(reporter, 'nope')).status).toBe(404);

      const queue = await ctx.http.get('/api/v1/admin/reports?status=OPEN').set(auth(mod));
      expect(queue.status).toBe(200);
      expect(queue.body.data).toEqual(
        expect.arrayContaining([
          expect.objectContaining({ id: created.body.id, targetType: 'LIVE_CHAT_MESSAGE' }),
        ]),
      );

      const acted = await ctx.http
        .post(`/api/v1/admin/reports/${created.body.id}/actions`)
        .set(auth(mod))
        .send({ action: 'REMOVE_TARGET' });
      expect(acted.status).toBe(200);
      expect(acted.body).toMatchObject({ status: 'ACTIONED', targetType: 'LIVE_CHAT_MESSAGE' });
      expect(await texts(roomId)).toEqual([]);
      expect(media.broadcastsOf(roomId, 'chat-delete')).toEqual([{ type: 'chat-delete', id: message.id }]);
      expect(await ctx.prisma.liveChatMessage.findUnique({ where: { id: message.id } })).toMatchObject({
        deletedById: mod.id,
      });
      // A deleted message can no longer be reported.
      expect((await report(await signup(), message.id)).status).toBe(404);
      await end(roomId, owner);
    });

    it('a message the reporter cannot read → 404 (a block either way, a room they may not see)', async () => {
      const [owner, author, blocker, blockedByHost] = [
        await host(),
        await signup(),
        await signup(),
        await signup(),
      ];
      const roomId = await goLive(owner);
      await join(roomId, author);
      const message = await say(roomId, author, 'hello');
      await ctx.http.put(`/api/v1/users/${author.username}/block`).set(auth(blocker)).expect(200);
      expect((await report(blocker, message.id)).status).toBe(404);
      await ctx.http.put(`/api/v1/users/${blockedByHost.username}/block`).set(auth(owner)).expect(200);
      expect((await report(blockedByHost, message.id)).status).toBe(404);
      // An ended room's messages can still be reported (they are still readable).
      await end(roomId, owner);
      expect((await report(await signup(), message.id)).status).toBe(201);
    });
  });

  describe('retention (owner D96)', () => {
    const report = (u: TestUser, targetId: string) =>
      ctx.http
        .post('/api/v1/reports')
        .set(auth(u))
        .send({ targetType: 'LIVE_CHAT_MESSAGE', targetId, reason: 'SPAM' });

    it('the live sweeper removes messages and mutes 30 days after the room ended, except reported ones', async () => {
      const [owner, other, reporter, v] = [await host(), await host(), await signup(), await signup()];
      const oldRoom = await goLive(owner);
      await join(oldRoom, v);
      const kept = await say(oldRoom, v, 'reported');
      tick();
      const gone = await say(oldRoom, v, 'ordinary');
      const deleted = await say(oldRoom, owner, 'deleted');
      await remove(oldRoom, owner, deleted.id).expect(204);
      await mute(oldRoom, owner, v.username).expect(204);
      expect((await report(reporter, kept.id)).status).toBe(201);
      await end(oldRoom, owner);

      const recentRoom = await goLive(other);
      const recent = await say(recentRoom, other, 'recent');
      await end(recentRoom, other);

      const liveRoom = await goLive(owner);
      const live = await say(liveRoom, owner, 'live');

      const now = clock.now();
      const endedDaysAgo = (id: string, days: number) => {
        const at = new Date(now.getTime() - days * DAY_MS);
        const started = new Date(at.getTime() - 3600_000);
        return ctx.prisma.liveRoom.update({
          where: { id },
          data: { startedAt: started, lastHeartbeatAt: at, endedAt: at },
        });
      };
      await endedDaysAgo(oldRoom, 31);
      await endedDaysAgo(recentRoom, 29);

      const result = await ctx.app.get(LiveRoomsService).sweepChatRetention(now);
      expect(result.messages).toBeGreaterThanOrEqual(2);
      expect(result.mutes).toBeGreaterThanOrEqual(1);
      const remaining = await ctx.prisma.liveChatMessage.findMany({
        where: { id: { in: [kept.id, gone.id, deleted.id, recent.id, live.id] } },
        select: { id: true },
      });
      expect(remaining.map((m) => m.id).sort()).toEqual([kept.id, recent.id, live.id].sort());
      expect(await ctx.prisma.liveChatMute.count({ where: { roomId: oldRoom } })).toBe(0);

      // Once the report is closed, the next sweep removes the message (and the closed report).
      await ctx.prisma.report.updateMany({
        where: { targetLiveChatMessageId: kept.id },
        data: { status: 'DISMISSED' },
      });
      await ctx.app.get(LiveRoomsService).sweepChatRetention(now);
      expect(await ctx.prisma.liveChatMessage.count({ where: { id: kept.id } })).toBe(0);
      expect(await ctx.prisma.liveChatMessage.count({ where: { id: { in: [recent.id, live.id] } } })).toBe(2);
      await end(liveRoom, owner);
    });
  });

  describe('"joined" lines', () => {
    it('signed-in viewers are announced (webhook and reconciliation), at most one a second per room', async () => {
      const owner = await host();
      const [a, b, c, d] = [await signup(), await signup(), await signup(), await signup()];
      const roomId = await goLive(owner);
      const joins = () => media.broadcastsOf(roomId, 'join');

      await h.hook('participant_joined', roomId, owner.id).expect(200); // the host: not a viewer
      await h.hook('participant_joined', roomId, `guest:${randomUUID()}`).expect(200); // guests: not announced
      expect(joins()).toEqual([]);

      await join(roomId, a);
      expect(joins()).toEqual([
        { type: 'join', user: expect.objectContaining({ id: a.id, username: a.username }), cp: null },
      ]);
      expect(media.broadcasts.filter((x) => x.room === roomId).every((x) => x.topic === 'chat')).toBe(true);
      await join(roomId, b); // same second: dropped
      await join(roomId, a); // a repeated webhook is not a new join
      expect(joins()).toHaveLength(1);
      tick();
      await join(roomId, c);
      expect(joins().map((j) => (j.user as { id: string }).id)).toEqual([a.id, c.id]);

      // Reconciliation records a join whose webhook was missed, and announces it like the webhook.
      tick();
      media.rooms.get(roomId)?.add(d.id);
      await ctx.app.get(LiveMediaService).reconcile();
      expect(joins().map((j) => (j.user as { id: string }).id)).toEqual([a.id, c.id, d.id]);
      await end(roomId, owner);
    });

    it('a media failure never breaks the join (the line is dropped)', async () => {
      const owner = await host();
      const v = await signup();
      const roomId = await goLive(owner);
      tick();
      media.failing = true;
      try {
        await join(roomId, v);
      } finally {
        media.failing = false;
      }
      expect(await ctx.prisma.liveRoomViewer.count({ where: { roomId, userId: v.id } })).toBe(1);
      // Sending still answers 201 when the media room cannot be reached (best effort).
      media.failing = true;
      try {
        const res = await send(roomId, v, { text: 'still stored', clientId: randomUUID() });
        expect(res.status).toBe(201);
      } finally {
        media.failing = false;
      }
      expect(await texts(roomId)).toEqual(['still stored']);
      await end(roomId, owner);
    });
  });
});

/**
 * CP-013 through the API on a real LiveKit server: a participant connected with the token the API
 * gives a viewer receives the `chat`, `chat-delete`, `chat-state` and `join` data messages,
 * reliable, on topic `chat` (LiveKit's own client SDK over WebRTC, `@livekit/rtc-node`). Runs only
 * when LIVEKIT_TEST_URL is set (as kl063-livekit-real).
 */
const url = process.env.LIVEKIT_TEST_URL;
const key = process.env.LIVEKIT_TEST_API_KEY ?? 'devkey';
const secret = process.env.LIVEKIT_TEST_API_SECRET ?? 'secret';

describe.skipIf(!url)('CP-013 chat delivery on a real LiveKit server', () => {
  const provider = new LiveKitMediaProvider(url ?? '', key, secret);
  let ctx: TestContext;
  const h = helpers(() => ctx);

  beforeAll(async () => {
    ctx = await createTestApp({ LIVE_HOSTING_ENABLED: 'true' }, [
      { token: LIVE_MEDIA_PROVIDER, value: provider },
    ]);
  });
  afterAll(async () => {
    await ctx?.close();
    const rtc = await import('@livekit/rtc-node');
    await rtc.dispose();
  });

  it('a connected viewer receives chat data messages on topic `chat`', async () => {
    const rtc = await import('@livekit/rtc-node');
    const [owner, viewer] = [await h.host(), await h.signup()];
    const roomId = await h.goLive(owner);
    const access = await ctx.http
      .post(`/api/v1/live/rooms/${roomId}/media-token`)
      .set(h.auth(viewer))
      .send({});
    expect(access.status).toBe(200);
    expect(access.body.role).toBe('VIEWER');

    const received: { topic: string | undefined; kind: unknown; data: Record<string, unknown> }[] = [];
    const room = new rtc.Room();
    room.on(rtc.RoomEvent.DataReceived, (payload, _participant, kind, topic) => {
      received.push({
        topic,
        kind,
        data: JSON.parse(new TextDecoder().decode(payload)) as Record<string, unknown>,
      });
    });
    const waitFor = async (n: number) => {
      for (let i = 0; i < 100 && received.length < n; i += 1) await new Promise((r) => setTimeout(r, 100));
      expect(received.length).toBeGreaterThanOrEqual(n);
    };
    try {
      await room.connect(access.body.url as string, access.body.token as string, {
        autoSubscribe: true,
        dynacast: false,
      });
      // The real media session lists the viewer; the API learns it like the webhook would.
      for (let i = 0; i < 50 && !(await provider.listIdentities(roomId)).includes(viewer.id); i += 1) {
        await new Promise((r) => setTimeout(r, 100));
      }
      await ctx.app.get(LiveMediaService).reconcile();
      expect(await ctx.prisma.liveRoomViewer.count({ where: { roomId, userId: viewer.id } })).toBe(1);

      const message = await h.say(roomId, owner, 'hello from the host');
      await waitFor(2); // the viewer's own "joined" line, then the message
      const own = await h.say(roomId, viewer, 'hi host');
      await waitFor(3);
      await h.remove(roomId, owner, own.id).expect(204);
      await waitFor(4);
      expect((await h.patch(roomId, owner, { chatEnabled: false })).status).toBe(200);
      await waitFor(5);

      expect(received.map((r) => r.topic)).toEqual(['chat', 'chat', 'chat', 'chat', 'chat']);
      expect(received.every((r) => r.kind === rtc.DataPacketKind.KIND_RELIABLE)).toBe(true);
      expect(received.map((r) => r.data)).toEqual([
        {
          type: 'join',
          user: expect.objectContaining({ id: viewer.id, username: viewer.username }),
          cp: null,
        },
        { type: 'chat', message },
        { type: 'chat', message: own },
        { type: 'chat-delete', id: own.id },
        { type: 'chat-state', enabled: false },
      ]);
    } finally {
      await room.disconnect();
      await h.end(roomId, owner);
    }
  });
});
