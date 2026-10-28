/**
 * D154i (owner 2026-10-28, item 9; contract v1.38-live, CONVENTIONS §10.39): YouTube watch-together
 * «يوتيوب» — the host's sync state relayed and read by late joiners and guests, viewers' suggestions
 * (one a minute, blocked words) played or turned down by the host, a video YouTube refuses, and search
 * on or off with the server's key — end to end against PostgreSQL + Redis. YouTube itself is a fake.
 */
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { Clock } from '../src/common/time/clock.js';
import { LIVE_MEDIA_PROVIDER } from '../src/modules/live/media/live-media.provider.js';
import {
  thumbnailOf,
  YOUTUBE_CLIENT,
  type YoutubeClient,
  type YoutubeVideo,
} from '../src/modules/live/youtube/youtube.client.js';
import { MemoryLiveMedia } from './helpers/memory-live-media.js';
import { expectContract, operations } from './helpers/openapi.js';
import { createTestApp, registerVerified, type TestContext } from './helpers/test-app.js';

class FakeClock extends Clock {
  private ms = Date.now();
  now(): Date {
    return new Date(this.ms);
  }
  advance(seconds: number): void {
    this.ms += seconds * 1000;
  }
}

const OK = 'aaaaaaaaaaa';
const SPOILER = 'bbbbbbbbbbb';
const BLOCKED = 'ccccccccccc';

class FakeYoutube implements YoutubeClient {
  searchEnabled = false;
  searches: string[] = [];
  async video(videoId: string): Promise<YoutubeVideo | null> {
    if (videoId === BLOCKED) return null;
    return {
      videoId,
      title: videoId === SPOILER ? 'Big spoiler inside' : `Video ${videoId}`,
      channel: 'Kabso',
      thumbnailUrl: thumbnailOf(videoId),
    };
  }
  async search(query: string): Promise<YoutubeVideo[]> {
    this.searches.push(query);
    return [{ videoId: OK, title: `Found ${query}`, channel: null, thumbnailUrl: thumbnailOf(OK) }];
  }
}

interface TestUser {
  readonly id: string;
  readonly username: string;
  readonly token: string;
}

describe('D154i contract coverage', () => {
  it('openapi v1.38-live declares the watch-together operations', () => {
    const ids = operations().map((o) => `${o.operationId} ${o.method.toUpperCase()} ${o.path}`);
    for (const id of [
      'searchYoutube GET /api/v1/live/youtube/search',
      'getLiveWatch GET /api/v1/live/rooms/{roomId}/watch',
      'setLiveWatch PUT /api/v1/live/rooms/{roomId}/watch',
      'listLiveWatchSuggestions GET /api/v1/live/rooms/{roomId}/watch/suggestions',
      'suggestLiveWatch POST /api/v1/live/rooms/{roomId}/watch/suggestions',
      'decideLiveWatchSuggestion POST /api/v1/live/rooms/{roomId}/watch/suggestions/{suggestionId}/decision',
    ]) {
      expect(ids).toContain(id);
    }
  });
});

describe('D154i watch-together', { timeout: 120_000 }, () => {
  const clock = new FakeClock();
  const media = new MemoryLiveMedia();
  const youtube = new FakeYoutube();
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
  const live = async () => {
    const h = await signup();
    await ctx.prisma.liveHost.create({ data: { userId: h.id, source: 'ADMIN', blockedWords: ['spoiler'] } });
    const room = await ctx.http.post('/api/v1/live/rooms').set(auth(h)).send({ title: 'Watch' });
    expect(room.status).toBe(201);
    return { h, roomId: room.body.id as string };
  };

  beforeAll(async () => {
    ctx = await createTestApp({ LIVE_HOSTING_ENABLED: 'true', LIVE_HEARTBEAT_STALE_SECONDS: '3600' }, [
      { token: Clock, value: clock },
      { token: LIVE_MEDIA_PROVIDER, value: media },
      { token: YOUTUBE_CLIENT, value: youtube },
    ]);
  });
  afterAll(async () => ctx?.close());

  it('the host plays, pauses and stops; everyone (late joiners, guests) reads the state', async () => {
    const { h, roomId } = await live();
    const viewer = await signup();
    const watch = (body: object) =>
      ctx.http.put(`/api/v1/live/rooms/${roomId}/watch`).set(auth(h)).send(body);

    const none = await ctx.http.get(`/api/v1/live/rooms/${roomId}/watch`);
    expect(none.status).toBe(200);
    expectContract(none, 'getLiveWatch');
    expect(none.body).toMatchObject({ video: null, playing: false, searchEnabled: false });

    const started = await watch({ video: `https://youtu.be/${OK}`, playing: true, positionMs: 0 });
    expect(started.status, JSON.stringify(started.body)).toBe(200);
    expectContract(started, 'setLiveWatch');
    expect(started.body.video).toMatchObject({ videoId: OK, title: `Video ${OK}`, channel: 'Kabso' });
    expect(
      media
        .broadcastsOf(roomId)
        .filter((m) => m.type === 'watch')
        .at(-1),
    ).toMatchObject({
      watch: { video: { videoId: OK }, playing: true },
    });

    clock.advance(30);
    const paused = await watch({ playing: false, positionMs: 30_000 });
    expect(paused.body).toMatchObject({ playing: false, positionMs: 30_000, video: { videoId: OK } });
    const late = await ctx.http.get(`/api/v1/live/rooms/${roomId}/watch`).set(auth(viewer));
    expect(late.body).toMatchObject({ playing: false, positionMs: 30_000, video: { videoId: OK } });
    expect(late.body.updatedAt).toBe(clock.now().toISOString());

    // A title with the host's blocked word is masked.
    const masked = await watch({ video: SPOILER, playing: true, positionMs: 0 });
    expect(masked.body.video.title).toBe('Big ******* inside');

    // Errors: not the host; not a YouTube link; a video YouTube refuses; no video to update.
    expect(
      (
        await ctx.http
          .put(`/api/v1/live/rooms/${roomId}/watch`)
          .set(auth(viewer))
          .send({ playing: true, positionMs: 0 })
      ).status,
    ).toBe(403);
    const bad = await watch({ video: 'https://vimeo.com/1', playing: true, positionMs: 0 });
    expect(bad.status).toBe(400);
    expect(bad.body.error.details).toEqual([{ field: 'video', issue: 'invalid_format' }]);
    const refused = await watch({ video: BLOCKED, playing: true, positionMs: 0 });
    expect(refused.status).toBe(422);
    expect(refused.body.error.code).toBe('YOUTUBE_VIDEO_UNAVAILABLE');
    expectContract(refused, 'setLiveWatch');

    const stopped = await watch({ video: null, playing: false, positionMs: 0 });
    expect(stopped.body.video).toBeNull();
    const nothing = await watch({ playing: true, positionMs: 0 });
    expect(nothing.status).toBe(400);
    expect(nothing.body.error.details).toEqual([{ field: 'video', issue: 'required' }]);

    // Ended: nothing to watch, nothing to set.
    await watch({ video: OK, playing: true, positionMs: 0 });
    await ctx.http.post(`/api/v1/live/rooms/${roomId}/end`).set(auth(h)).expect(200);
    expect((await ctx.http.get(`/api/v1/live/rooms/${roomId}/watch`)).body.video).toBeNull();
    expect((await watch({ playing: true, positionMs: 0 })).status).toBe(409);
  });

  it('viewers suggest (one a minute, masked); the host plays or turns them down', async () => {
    const { h, roomId } = await live();
    const fan = await signup();
    const suggest = (u: TestUser, video: string) =>
      ctx.http.post(`/api/v1/live/rooms/${roomId}/watch/suggestions`).set(auth(u)).send({ video });

    const first = await suggest(fan, `https://www.youtube.com/watch?v=${SPOILER}`);
    expect(first.status, JSON.stringify(first.body)).toBe(201);
    expectContract(first, 'suggestLiveWatch');
    expect(first.body).toMatchObject({
      status: 'PENDING',
      video: { videoId: SPOILER, title: 'Big ******* inside' },
      suggester: { username: fan.username },
    });
    expect(media.broadcastsOf(roomId).filter((m) => m.type === 'watch-suggestion')).toHaveLength(1);

    const again = await suggest(fan, OK);
    expect(again.status).toBe(429);
    expect(Number(again.headers['retry-after'])).toBeGreaterThan(0);
    expect((await suggest(h, OK)).status).toBe(403);
    expect((await suggest(fan, BLOCKED)).status).toBe(422);

    clock.advance(61);
    const second = await suggest(fan, OK);
    expect(second.status).toBe(201);

    const list = await ctx.http.get(`/api/v1/live/rooms/${roomId}/watch/suggestions`).set(auth(h));
    expect(list.status).toBe(200);
    expectContract(list, 'listLiveWatchSuggestions');
    expect(list.body.data.map((s: { id: string }) => s.id)).toEqual([first.body.id, second.body.id]);
    expect((await ctx.http.get(`/api/v1/live/rooms/${roomId}/watch/suggestions`).set(auth(fan))).status).toBe(
      403,
    );

    const decide = (id: string, approve: boolean) =>
      ctx.http
        .post(`/api/v1/live/rooms/${roomId}/watch/suggestions/${id}/decision`)
        .set(auth(h))
        .send({ approve });
    const turnedDown = await decide(first.body.id, false);
    expect(turnedDown.status).toBe(200);
    expect(turnedDown.body.video).toBeNull();
    const played = await decide(second.body.id, true);
    expect(played.status).toBe(200);
    expectContract(played, 'decideLiveWatchSuggestion');
    expect(played.body).toMatchObject({ video: { videoId: OK }, playing: true, positionMs: 0 });
    expect((await decide(second.body.id, true)).status).toBe(404);
    const left = await ctx.http.get(`/api/v1/live/rooms/${roomId}/watch/suggestions`).set(auth(h));
    expect(left.body.data).toEqual([]);
  });

  it('search: off without the key (paste a link), on with it', async () => {
    const u = await signup();
    const off = await ctx.http.get('/api/v1/live/youtube/search?q=cats').set(auth(u));
    expect(off.status).toBe(503);
    expect(off.body.error.code).toBe('YOUTUBE_SEARCH_UNAVAILABLE');
    expectContract(off, 'searchYoutube');
    youtube.searchEnabled = true;
    const on = await ctx.http.get('/api/v1/live/youtube/search?q=cats').set(auth(u));
    expect(on.status).toBe(200);
    expectContract(on, 'searchYoutube');
    expect(on.body.items).toEqual([
      { videoId: OK, title: 'Found cats', channel: null, thumbnailUrl: thumbnailOf(OK) },
    ]);
    expect((await ctx.http.get('/api/v1/live/youtube/search').set(auth(u))).status).toBe(400);
    youtube.searchEnabled = false;
  });
});
