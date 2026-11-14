/**
 * D154h (owner 2026-10-28, item 3; contract v1.37-live, CONVENTIONS §10.38): stickers on a live
 * «ملصقات» — the catalogue, the host's ≤ 3 Kabi or text stickers at relative positions, the blocked
 * words and the text hygiene, the room told of every change and late joiners reading them — end to
 * end against PostgreSQL + Redis.
 */
import type request from 'supertest';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { LIVE_MEDIA_PROVIDER } from '../src/modules/live/media/live-media.provider.js';
import { MemoryLiveMedia } from './helpers/memory-live-media.js';
import { expectContract, operations } from './helpers/openapi.js';
import { createTestApp, registerVerified, type TestContext } from './helpers/test-app.js';

interface TestUser {
  readonly id: string;
  readonly username: string;
  readonly token: string;
}

describe('D154h contract coverage', () => {
  it('openapi v1.37-live declares the sticker operations', () => {
    const ids = operations().map((o) => `${o.operationId} ${o.method.toUpperCase()} ${o.path}`);
    expect(ids).toContain('listLiveStickerArt GET /api/v1/live/stickers');
    expect(ids).toContain('getLiveStickers GET /api/v1/live/rooms/{roomId}/stickers');
    expect(ids).toContain('setLiveStickers PUT /api/v1/live/rooms/{roomId}/stickers');
  });
});

describe('D154h stickers', { timeout: 120_000 }, () => {
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
  const put = (roomId: string, u: TestUser, items: object[]): request.Test =>
    ctx.http.put(`/api/v1/live/rooms/${roomId}/stickers`).set(auth(u)).send({ items });
  const place = { x: 0.5, y: 0.4, scale: 1, rotation: 0 };

  beforeAll(async () => {
    ctx = await createTestApp({ LIVE_HOSTING_ENABLED: 'true', LIVE_HEARTBEAT_STALE_SECONDS: '3600' }, [
      { token: LIVE_MEDIA_PROVIDER, value: media },
    ]);
  });
  afterAll(async () => ctx?.close());

  it('the catalogue lists the Kabi pack', async () => {
    const u = await signup();
    const res = await ctx.http.get('/api/v1/live/stickers').set(auth(u));
    expect(res.status).toBe(200);
    expectContract(res, 'listLiveStickerArt');
    expect(res.body.items).toHaveLength(24);
    expect(res.body.items[0]).toEqual({ key: 'kabi_hi', pack: 'kabi' });
  });

  it('the host places, moves and removes stickers; everyone (late joiners, guests) reads them', async () => {
    const h = await signup();
    await ctx.prisma.liveHost.create({ data: { userId: h.id, source: 'ADMIN', blockedWords: ['spoiler'] } });
    const viewer = await signup();
    const room = await ctx.http.post('/api/v1/live/rooms').set(auth(h)).send({ title: 'Stickers' });
    const roomId = room.body.id as string;

    const res = await put(roomId, h, [
      { artKey: 'kabi_love', ...place },
      { text: '  no spoiler please ', x: 0, y: 1, scale: 2.5, rotation: -1.2 },
    ]);
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    expectContract(res, 'setLiveStickers');
    expect(res.body.items).toMatchObject([
      { artKey: 'kabi_love', text: null, x: 0.5, y: 0.4 },
      { artKey: null, text: 'no ******* please', scale: 2.5, rotation: -1.2 },
    ]);
    const sent = media.broadcastsOf(roomId).filter((m) => m.type === 'stickers');
    expect(sent.at(-1)).toMatchObject({ stickers: { roomId, items: [{ artKey: 'kabi_love' }, {}] } });

    // Moved: the same id comes back.
    const first = res.body.items[0] as { id: string };
    const moved = await put(roomId, h, [{ id: first.id, artKey: 'kabi_love', ...place, x: 0.9 }]);
    expect(moved.body.items).toEqual([{ ...res.body.items[0], x: 0.9 }]);

    const read = await ctx.http.get(`/api/v1/live/rooms/${roomId}/stickers`).set(auth(viewer));
    expect(read.status).toBe(200);
    expectContract(read, 'getLiveStickers');
    expect(read.body.items).toHaveLength(1);
    expect((await ctx.http.get(`/api/v1/live/rooms/${roomId}/stickers`)).status).toBe(200);

    expect((await put(roomId, viewer, [])).status).toBe(403);

    const cleared = await put(roomId, h, []);
    expect(cleared.body).toEqual({ roomId, items: [] });

    // Ended: none shown, none placed.
    await put(roomId, h, [{ artKey: 'kabi_hi', ...place }]);
    await ctx.http.post(`/api/v1/live/rooms/${roomId}/end`).set(auth(h)).expect(200);
    const ended = await ctx.http.get(`/api/v1/live/rooms/${roomId}/stickers`).set(auth(viewer));
    expect(ended.body.items).toEqual([]);
    const late = await put(roomId, h, []);
    expect(late.status).toBe(409);
    expect(late.body.error.code).toBe('LIVE_ROOM_ENDED');
  });

  it('refuses more than 3, unknown art, both or neither, bad places and bad texts', async () => {
    const h = await signup();
    await ctx.prisma.liveHost.create({ data: { userId: h.id, source: 'ADMIN' } });
    const room = await ctx.http.post('/api/v1/live/rooms').set(auth(h)).send({ title: 'Rules' });
    const roomId = room.body.id as string;
    const cases: [object[], string, string][] = [
      [Array.from({ length: 4 }, () => ({ artKey: 'kabi_hi', ...place })), 'items', 'too_many'],
      [[{ artKey: 'acme_logo', ...place }], 'items.0.artKey', 'invalid_value'],
      [[{ artKey: 'kabi_hi', text: 'x', ...place }], 'items.0.artKey', 'invalid_value'],
      [[{ ...place }], 'items.0.artKey', 'invalid_value'],
      [[{ artKey: 'kabi_hi', ...place, x: 1.5 }], 'items.0.x', 'too_big'],
      [[{ artKey: 'kabi_hi', ...place, scale: 9 }], 'items.0.scale', 'too_big'],
      [[{ text: 'x'.repeat(41), ...place }], 'items.0.text', 'too_long'],
      [[{ text: 'two\nlines', ...place }], 'items.0.text', 'invalid_format'],
    ];
    for (const [items, field, issue] of cases) {
      const res = await put(roomId, h, items);
      expect(res.status, JSON.stringify(res.body)).toBe(400);
      expect(res.body.error.details, JSON.stringify(items)).toEqual([{ field, issue }]);
    }
  });
});
