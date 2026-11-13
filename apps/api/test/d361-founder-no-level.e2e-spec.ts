/**
 * D361 (owner: «المؤسس ليس له ليفيل»; contract v1.121-social, CONVENTIONS §10.156): the founder — the app owner, an
 * ACTIVE account holding OWNER — shows no level anywhere, decided at the source. End to end against PostgreSQL +
 * Redis with published charm and wealth ladders: his `getUserLevels` is empty (another user's is not), his lives carry
 * `roomLevel` null (in the room and in the lists), his chat lines carry `authorBadges.charmLevel` / `supportLevel`
 * null, and his level-ups are never announced on the level ticker. His own `GET /levels/me` still answers (private;
 * the app shows him a neutral state) and nothing is deleted: once he is no longer the owner the levels show again.
 */
import { randomUUID } from 'node:crypto';
import { afterAll, beforeAll, describe, expect, it, vi } from 'vitest';
import { grantRoleIn, revokeRoleIn } from '../src/modules/admin-panel/admin-roles.js';
import { LiveLevelTickerService } from '../src/modules/live/live-level-ticker.service.js';
import { LIVE_MEDIA_PROVIDER } from '../src/modules/live/media/live-media.provider.js';
import { MemoryLiveMedia } from './helpers/memory-live-media.js';
import { expectContract, operations } from './helpers/openapi.js';
import {
  createTestApp,
  registerVerified,
  withMigrationClient,
  type TestContext,
} from './helpers/test-app.js';

interface TestUser {
  readonly id: string;
  readonly username: string;
  readonly email: string;
  readonly token: string;
}

describe('D361 contract', () => {
  it('declares the founder rule on the level fields', () => {
    const spec = JSON.stringify(operations().find((o) => o.operationId === 'getUserLevels')?.spec ?? {});
    expect(spec).toContain('D361');
  });
});

describe('D361 the founder has no level', { timeout: 300_000 }, () => {
  const media = new MemoryLiveMedia();
  let ctx: TestContext;
  let founder: TestUser;
  let alice: TestUser;
  let charm = '';
  let support = '';
  let charmVersion = '';
  let supportVersion = '';
  let founderRoom = '';
  let aliceRoom = '';

  const auth = (u: TestUser) => ({ Authorization: `Bearer ${u.token}` });
  const signup = async (): Promise<TestUser> => {
    const { res, payload } = await registerVerified(ctx);
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    return {
      id: res.body.user.id as string,
      username: res.body.user.username as string,
      email: String(payload.email).trim().toLowerCase(),
      token: res.body.tokens.accessToken as string,
    };
  };
  const get = (u: TestUser, path: string) => ctx.http.get(`/api/v1${path}`).set(auth(u));
  const ladder = async (code: 'ATTRACTIVENESS' | 'SUPPORT') => {
    const category = await ctx.prisma.levelCategory.create({
      data: { code, nameAr: code, nameEn: code, descriptionAr: 'وصف', descriptionEn: 'About' },
    });
    const version = await ctx.prisma.levelCategoryVersion.create({
      data: {
        categoryId: category.id,
        versionNumber: 1,
        status: 'PUBLISHED',
        multiplier: '0.1',
        valueUnit: 'COIN',
        publishedAt: new Date(),
        levels: {
          create: [1, 2, 3, 4, 5].map((n) => ({
            levelNumber: n,
            nameAr: `م${n}`,
            nameEn: `L${n}`,
            requiredPoints: BigInt((n - 1) * 10),
          })),
        },
      },
    });
    await ctx.prisma.levelCategory.update({
      where: { id: category.id },
      data: { isEnabled: true, publishedVersionId: version.id },
    });
    return { category: category.id, version: version.id };
  };
  const setLevel = (u: TestUser, categoryId: string, versionId: string, level: number) =>
    ctx.prisma.userLevelState.upsert({
      where: { userId_categoryId: { userId: u.id, categoryId } },
      create: { userId: u.id, categoryId, versionId, currentLevel: level },
      update: { versionId, currentLevel: level },
    });
  const goLive = async (u: TestUser) => {
    await ctx.prisma.liveHost.upsert({
      where: { userId: u.id },
      create: { userId: u.id, source: 'ADMIN' },
      update: {},
    });
    const res = await ctx.http.post('/api/v1/live/rooms').set(auth(u)).send({ title: 'D361' });
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    return res.body.id as string;
  };
  const say = async (roomId: string, u: TestUser, text: string) => {
    const res = await ctx.http
      .post(`/api/v1/live/rooms/${roomId}/chat`)
      .set(auth(u))
      .send({ text, clientId: randomUUID() });
    expect(res.status, JSON.stringify(res.body)).toBe(201);
  };

  beforeAll(async () => {
    ctx = await createTestApp(
      {
        LIVE_HOSTING_ENABLED: 'true',
        RATE_LIMIT_PROFILE_USER: '100000/900',
        RATE_LIMIT_AUTHENTICATED_USER: '100000/900',
      },
      [{ token: LIVE_MEDIA_PROVIDER, value: media }],
    );
    founder = await signup();
    alice = await signup();
    await withMigrationClient((db) => db.$transaction((tx) => grantRoleIn(tx, founder.email, 'OWNER')));
    ({ category: charm, version: charmVersion } = await ladder('ATTRACTIVENESS'));
    ({ category: support, version: supportVersion } = await ladder('SUPPORT'));
    for (const u of [founder, alice]) {
      await setLevel(u, charm, charmVersion, 4);
      await setLevel(u, support, supportVersion, 3);
    }
  });
  afterAll(async () => {
    vi.restoreAllMocks();
    await ctx?.close();
  });

  it('getUserLevels: the founder’s is empty for every viewer; another user’s is not', async () => {
    for (const viewer of [alice, founder]) {
      const f = await get(viewer, `/users/${founder.username}/levels`);
      expect(f.status).toBe(200);
      expectContract(f, 'getUserLevels');
      expect(f.body).toEqual({ data: [] });
    }
    const a = await get(founder, `/users/${alice.username}/levels`);
    expect(a.status).toBe(200);
    const levels = (a.body.data as { level: { levelNumber: number } | null }[]).map(
      (l) => l.level?.levelNumber,
    );
    expect(levels).toEqual(expect.arrayContaining([4, 3]));
    // His own levels page reads his private summary (the app shows him a neutral state); nothing deleted.
    const mine = await get(founder, '/levels/me');
    expect(mine.status).toBe(200);
    expect(await ctx.prisma.userLevelState.count({ where: { userId: founder.id } })).toBe(2);
  });

  it('his lives carry no room level, in the room and in the list; another host’s do', async () => {
    founderRoom = await goLive(founder);
    aliceRoom = await goLive(alice);
    const fr = await get(alice, `/live/rooms/${founderRoom}`);
    expect(fr.status).toBe(200);
    expectContract(fr, 'getLiveRoom');
    expect(fr.body.roomLevel).toBeNull();
    expect((await get(founder, `/live/rooms/${aliceRoom}`)).body.roomLevel).toBe(4);
    const list = await get(alice, '/live/rooms?tab=new');
    expect(list.status, JSON.stringify(list.body)).toBe(200);
    const byId = new Map(
      (list.body.data as { id: string; roomLevel: number | null }[]).map((r) => [r.id, r.roomLevel]),
    );
    expect(byId.get(founderRoom)).toBeNull();
    expect(byId.get(aliceRoom)).toBe(4);
    expect(byId.has(founderRoom)).toBe(true);
  });

  it('his chat lines carry no charm or wealth level; everyone else’s still do', async () => {
    // In his own live (as its host; the app owner in someone else's live is the hidden Kabso Team watch).
    const raw = JSON.stringify({
      event: 'participant_joined',
      room: { name: founderRoom },
      participant: { identity: alice.id },
    });
    const joined = await ctx.http
      .post('/internal/livekit/webhook')
      .set('Content-Type', 'application/webhook+json')
      .set('Authorization', MemoryLiveMedia.sign(raw))
      .send(raw);
    expect(joined.status).toBe(200);
    await say(founderRoom, founder, 'السلام عليكم');
    await say(founderRoom, alice, 'أهلاً');
    const res = await get(alice, `/live/rooms/${founderRoom}/chat`);
    expect(res.status).toBe(200);
    expectContract(res, 'listLiveChatMessages');
    const lines = res.body.data as {
      author: { id: string };
      authorBadges: { charmLevel: number | null; supportLevel: number | null };
    }[];
    const his = lines.find((l) => l.author.id === founder.id)!;
    const hers = lines.find((l) => l.author.id === alice.id)!;
    expect(his.authorBadges).toMatchObject({ charmLevel: null, supportLevel: null });
    expect(hers.authorBadges).toMatchObject({ charmLevel: 4, supportLevel: 3 });
  });

  it('his level-ups are never announced on the level ticker; another user’s are', async () => {
    const ticker = ctx.app.get(LiveLevelTickerService);
    const offer = vi.spyOn(ticker as unknown as { offer: (o: unknown) => Promise<void> }, 'offer');
    offer.mockResolvedValue(undefined);
    const up = (u: TestUser) => ({
      userId: u.id,
      category: 'SUPPORT' as const,
      previousLevel: 29,
      level: 31,
      roomId: aliceRoom,
      source: 'gift:test',
    });
    await ticker.offerAll([up(founder) as never, up(alice) as never]);
    expect(offer).toHaveBeenCalledTimes(1);
    expect((offer.mock.calls[0]![0] as { userId: string }).userId).toBe(alice.id);
    offer.mockRestore();
  });

  it('nothing is lost: without OWNER his levels show again', async () => {
    // A second OWNER first (the last one cannot be revoked).
    await withMigrationClient((db) => db.$transaction((tx) => grantRoleIn(tx, alice.email, 'OWNER')));
    await withMigrationClient((db) => db.$transaction((tx) => revokeRoleIn(tx, founder.email, 'OWNER')));
    const f = await get(alice, `/users/${founder.username}/levels`);
    expect((f.body.data as unknown[]).length).toBeGreaterThan(0);
    expect((await get(alice, `/live/rooms/${founderRoom}`)).body.roomLevel).toBe(4);
  });
});
