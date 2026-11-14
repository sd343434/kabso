/**
 * KL-075 / CP-016 D (D101): the room level is the host's charm level, and taps give the host charm
 * points (openapi v1.17-live DRAFT, CONVENTIONS §10.18), end to end against PostgreSQL + Redis with
 * the API as the DML-only runtime role. Time comes from a FakeClock (the 10-a-second tap rule).
 */
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { Clock } from '../src/common/time/clock.js';
import { MAX_TAPS_PER_ROOM } from '../src/modules/live/live-taps.js';
import { LIVE_MEDIA_PROVIDER } from '../src/modules/live/media/live-media.provider.js';
import { MemoryLiveMedia } from './helpers/memory-live-media.js';
import { expectContract } from './helpers/openapi.js';
import { createTestApp, registerVerified, type TestContext } from './helpers/test-app.js';

class FakeClock extends Clock {
  private ms = Date.parse('2026-10-25T10:00:00.000Z');
  now(): Date {
    return new Date(this.ms);
  }
  advance(seconds: number): void {
    this.ms += Math.round(seconds * 1000);
  }
}

interface TestUser {
  readonly id: string;
  readonly token: string;
}

describe('CP-016 D room level and charm points from taps', () => {
  const clock = new FakeClock();
  const media = new MemoryLiveMedia();
  let ctx: TestContext;

  const auth = (u: TestUser) => ({ Authorization: `Bearer ${u.token}` });
  const signup = async (): Promise<TestUser> => {
    const { res } = await registerVerified(ctx);
    expect(res.status).toBe(201);
    return { id: res.body.user.id, token: res.body.tokens.accessToken };
  };
  const host = async (): Promise<TestUser> => {
    const u = await signup();
    await ctx.prisma.liveHost.create({ data: { userId: u.id, source: 'ADMIN' } });
    return u;
  };
  const goLive = async (u: TestUser): Promise<string> => {
    const res = await ctx.http.post('/api/v1/live/rooms').set(auth(u)).send({ title: 'Charm' });
    expect(res.status).toBe(201);
    expectContract(res, 'startLiveRoom');
    return res.body.id as string;
  };
  const room = async (roomId: string, u: TestUser) => {
    const res = await ctx.http.get(`/api/v1/live/rooms/${roomId}`).set(auth(u));
    expect(res.status).toBe(200);
    expectContract(res, 'getLiveRoom');
    return res.body as { roomLevel: number | null; score: number };
  };
  /** Taps `count` after a pause long enough for all of them to count. */
  const tap = async (roomId: string, u: TestUser, count: number) => {
    clock.advance(5);
    const res = await ctx.http.post(`/api/v1/live/rooms/${roomId}/taps`).set(auth(u)).send({ count });
    expect(res.status).toBe(200);
    expectContract(res, 'tapLiveRoom');
    return res.body as { accepted: number };
  };
  const charmEntries = (u: TestUser) =>
    ctx.prisma.pointsLedgerEntry.findMany({
      where: { userId: u.id, sourceType: 'LIVE_TAPS' },
      orderBy: { createdAt: 'asc' },
    });
  const infoVersion = async (roomId: string) =>
    (await ctx.prisma.liveRoom.findUniqueOrThrow({ where: { id: roomId } })).infoVersion;

  /** Publishes a small charm ladder: level 2 at 2 points, level 3 at 5. */
  const publishCharm = async () => {
    const category = await ctx.prisma.levelCategory.create({
      data: {
        code: 'ATTRACTIVENESS',
        nameAr: 'الجاذبية',
        nameEn: 'Charm',
        descriptionAr: 'وصف',
        descriptionEn: 'About',
      },
    });
    const version = await ctx.prisma.levelCategoryVersion.create({
      data: {
        categoryId: category.id,
        versionNumber: 1,
        status: 'PUBLISHED',
        multiplier: '0.1',
        valueUnit: 'COIN',
        publishedAt: clock.now(),
        levels: {
          create: [
            { levelNumber: 1, nameAr: 'بذرة', nameEn: 'Sprout', requiredPoints: 0n },
            { levelNumber: 2, nameAr: 'بذرة', nameEn: 'Sprout', requiredPoints: 2n },
            { levelNumber: 3, nameAr: 'بذرة', nameEn: 'Sprout', requiredPoints: 5n },
          ],
        },
      },
    });
    await ctx.prisma.levelCategory.update({
      where: { id: category.id },
      data: { isEnabled: true, publishedVersionId: version.id },
    });
  };

  beforeAll(async () => {
    ctx = await createTestApp({ LIVE_HOSTING_ENABLED: 'true' }, [
      { token: LIVE_MEDIA_PROVIDER, value: media },
      { token: Clock, value: clock },
    ]);
  });
  afterAll(async () => ctx?.close());

  it('has no level and credits nothing while the charm category is unavailable', async () => {
    const [h, viewer] = [await host(), await signup()];
    const roomId = await goLive(h);
    expect((await room(roomId, viewer)).roomLevel).toBeNull();
    expect((await tap(roomId, viewer, 10)).accepted).toBe(10);
    expect((await tap(roomId, viewer, 10)).accepted).toBe(10);
    expect(await charmEntries(h)).toEqual([]);
    expect((await room(roomId, viewer)).score).toBe(20);
  });

  describe('with a published charm ladder', () => {
    beforeAll(publishCharm);

    it('every 10 counted taps of a viewer give the host 1 point and raise the room level', async () => {
      const [h, viewer] = [await host(), await signup()];
      const roomId = await goLive(h);
      expect((await room(roomId, viewer)).roomLevel).toBe(1);

      await tap(roomId, viewer, 9);
      expect(await charmEntries(h)).toEqual([]);
      const before = await infoVersion(roomId);
      await tap(roomId, viewer, 1); // 10 taps: 1 point, still level 1
      await tap(roomId, viewer, 15); // 25 taps: 2 points, level 2
      const entries = await charmEntries(h);
      expect(entries.map((e) => [e.entryType, e.pointsDelta, e.sourceValue])).toEqual([
        ['EARN', 1n, 10n],
        ['EARN', 1n, 10n],
      ]);
      expect(entries.map((e) => e.sourceTransactionId)).toEqual([
        `taps:${roomId}:${viewer.id}:1`,
        `taps:${roomId}:${viewer.id}:2`,
      ]);
      expect((await room(roomId, viewer)).roomLevel).toBe(2);
      // The level change raised the info version (§10.12) so apps read the room again.
      expect(await infoVersion(roomId)).toBeGreaterThan(before);
      expect(media.metadataWrites.some((w) => w.metadata.includes('"roomInfoVersion"'))).toBe(true);

      // The host reads the entries in their own history, with the new source type.
      const history = await ctx.http.get('/api/v1/levels/me/points-history').set(auth(h));
      expect(history.status).toBe(200);
      expectContract(history, 'listMyPointsHistory');
      expect(history.body.data.map((e: { sourceType: string }) => e.sourceType)).toEqual([
        'LIVE_TAPS',
        'LIVE_TAPS',
      ]);
    });

    it("the level is the host's: it carries over to the next live; D120: the host's own taps count", async () => {
      const [h, viewer] = [await host(), await signup()];
      const first = await goLive(h);
      await tap(first, viewer, 10); // a first batch counts at most 10 (§10.10)
      await tap(first, viewer, 40); // 50 taps: 5 points, level 3
      expect((await room(first, viewer)).roomLevel).toBe(3);
      await ctx.http.post(`/api/v1/live/rooms/${first}/end`).set(auth(h)).expect(200);

      const second = await goLive(h);
      const read = await room(second, viewer);
      expect(read.roomLevel).toBe(3);
      expect(read.score).toBe(0);
      // D120 (owner): the host's own taps count like a viewer's: a first batch counts at most 10,
      // and every 10 counted taps of the host give the host 1 charm point.
      expect((await tap(second, h, 50)).accepted).toBe(10);
      expect((await tap(second, h, 10)).accepted).toBe(10);
      const entries = await charmEntries(h);
      expect(entries.map((e) => e.sourceTransactionId)).toEqual([
        `taps:${first}:${viewer.id}:1`,
        `taps:${first}:${viewer.id}:5`,
        `taps:${second}:${h.id}:1`,
        `taps:${second}:${h.id}:2`,
      ]);
      expect((await room(second, viewer)).score).toBe(20);
    });

    it('D120: the host has the same 10 000 a live as a viewer (1 000 points)', async () => {
      const h = await host();
      const roomId = await goLive(h);
      await tap(roomId, h, 10);
      await ctx.prisma.liveRoomTapper.update({
        where: { roomId_userId: { roomId, userId: h.id } },
        data: { counted: MAX_TAPS_PER_ROOM - 5, points: MAX_TAPS_PER_ROOM - 5 },
      });
      expect((await tap(roomId, h, 50)).accepted).toBe(5); // 1 point at 10 000
      expect((await tap(roomId, h, 50)).accepted).toBe(0);
      expect((await charmEntries(h)).map((e) => e.sourceTransactionId)).toEqual([
        `taps:${roomId}:${h.id}:1`,
        `taps:${roomId}:${h.id}:1000`,
      ]);
    });

    it('the owner limit: a viewer gives at most 10 000 taps a live, so 1 000 points', async () => {
      const [h, viewer, other] = [await host(), await signup(), await signup()];
      const roomId = await goLive(h);
      await tap(roomId, viewer, 10);
      // Near the end of the live's limit (as after 999 points' worth of taps).
      await ctx.prisma.liveRoomTapper.update({
        where: { roomId_userId: { roomId, userId: viewer.id } },
        data: { counted: MAX_TAPS_PER_ROOM - 15, points: MAX_TAPS_PER_ROOM - 15 },
      });
      expect((await tap(roomId, viewer, 50)).accepted).toBe(15); // 1 point at 10 000
      expect((await tap(roomId, viewer, 50)).accepted).toBe(0); // the limit: nothing more
      expect((await charmEntries(h)).map((e) => e.sourceTransactionId)).toEqual([
        `taps:${roomId}:${viewer.id}:1`,
        `taps:${roomId}:${viewer.id}:1000`,
      ]);
      // Another viewer has their own 10 000.
      await tap(roomId, other, 10);
      expect((await charmEntries(h)).length).toBe(3);
    });
  });
});
