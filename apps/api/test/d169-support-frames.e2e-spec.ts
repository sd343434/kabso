/**
 * D169 (v1.46-levels, CONVENTIONS §10.22): reaching a new support-level tier gives that tier's
 * avatar frame (bag `AVATAR_FRAME`, source `LEVEL_REWARD`), once, never worn, kept for good.
 * The support level is moved with the audited admin adjustment (any path that raises the level
 * runs the same hook, in the same transaction).
 */
import { randomUUID } from 'node:crypto';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { BAG_CATALOGUE } from '../src/modules/bag/bag.catalogue.js';
import { presetLadder } from '../src/modules/levels/level-preset.js';
import { expectContract } from './helpers/openapi.js';
import {
  createTestApp,
  registerVerified,
  withMigrationClient,
  type TestContext,
} from './helpers/test-app.js';

interface TestUser {
  readonly id: string;
  readonly token: string;
}

describe('D169 support tier frames', () => {
  let ctx: TestContext;
  let admin: TestUser;

  const signup = async (): Promise<TestUser> => {
    const { res } = await registerVerified(ctx);
    expect(res.status).toBe(201);
    return { id: res.body.user.id, token: res.body.tokens.accessToken };
  };
  const auth = (u: TestUser) => ({ Authorization: `Bearer ${u.token}` });

  /** Adds `delta` support points to `u` (idempotency `key`, or a new one). */
  const adjust = async (u: TestUser, delta: bigint, key: string = randomUUID(), fraud?: boolean) => {
    const res = await ctx.http
      .post(`/api/v1/admin/levels/users/${u.id}/adjustments`)
      .set(auth(admin))
      .set('Idempotency-Key', key)
      .send({
        category: 'SUPPORT',
        pointsDelta: delta.toString(),
        reason: 'D169 tier frame test',
        ...(fraud === undefined ? {} : { fraud }),
      });
    expect(res.status).toBe(200);
    expectContract(res, 'createAdminLevelAdjustment');
    return res;
  };

  const frames = async (u: TestUser) => {
    const res = await ctx.http.get('/api/v1/me/bag?category=AVATAR_FRAME').set(auth(u));
    expect(res.status).toBe(200);
    expectContract(res, 'getMyBag');
    return res.body.data as { code: string; category: string; source: string; equipped: boolean }[];
  };

  const supportLevel = async (u: TestUser) => {
    const res = await ctx.http.get('/api/v1/levels/me/support').set(auth(u));
    expect(res.status).toBe(200);
    return (res.body.level?.levelNumber ?? null) as number | null;
  };

  /** Points needed for `level` on the preset ladder. */
  const at = (level: number) => presetLadder()[level - 1]!.requiredPoints;

  beforeAll(async () => {
    ctx = await createTestApp();
    await ctx.prisma.bagItem.createMany({ data: BAG_CATALOGUE.map((i) => ({ ...i })) });
    // The contract always lists the four categories (`AdminUserLevels.data` has 4 items), as the
    // migration seeds them; the test database is truncated, so they are seeded again (the other
    // three without a published version).
    for (const [code, nameAr, nameEn] of [
      ['ATTRACTIVENESS', 'مستوى الجاذبية', 'Attractiveness'],
      ['WIZARD', 'مستوى الساحر', 'Wizard'],
      ['GAMING', 'مستوى اللعب', 'Gaming'],
    ] as const) {
      await ctx.prisma.levelCategory.create({
        data: { code, nameAr, nameEn, descriptionAr: `وصف ${nameAr}`, descriptionEn: `About ${nameEn}` },
      });
    }
    const category = await ctx.prisma.levelCategory.create({
      data: {
        code: 'SUPPORT',
        nameAr: 'مستوى الدعم',
        nameEn: 'Support',
        descriptionAr: 'يرتفع بقيمة الهدايا التي ترسلها.',
        descriptionEn: 'Grows with the value of the gifts you send.',
      },
    });
    const version = await ctx.prisma.levelCategoryVersion.create({
      data: {
        categoryId: category.id,
        versionNumber: 1,
        status: 'PUBLISHED',
        multiplier: '0.1',
        valueUnit: 'COIN',
        publishedAt: new Date(),
        levels: { create: presetLadder() },
      },
    });
    await ctx.prisma.levelCategory.update({
      where: { id: category.id },
      data: { isEnabled: true, publishedVersionId: version.id },
    });
    admin = await signup();
    await ctx.prisma.user.update({ where: { id: admin.id }, data: { role: 'ADMIN' } });
    // Admin permissions are granted by the migration role (`levels-admin grant`), as in KL-058.
    await withMigrationClient((db) =>
      db.userAdminPermission.create({ data: { userId: admin.id, permission: 'LEVELS_ADJUST' } }),
    );
  });

  afterAll(async () => ctx?.close());

  it('a new tier gives its frame once, never worn; a replay or a level in the same tier gives nothing', async () => {
    const u = await signup();
    expect(await frames(u)).toEqual([]);

    const key = randomUUID();
    await adjust(u, at(3), key); // level 3 → tier 1
    expect(await supportLevel(u)).toBe(3);
    expect(await frames(u)).toEqual([
      expect.objectContaining({
        code: 'support_frame_01',
        category: 'AVATAR_FRAME',
        source: 'LEVEL_REWARD',
        equipped: false,
      }),
    ]);

    await adjust(u, at(3), key); // the same request replayed
    await adjust(u, at(5) - at(3)); // level 5: still tier 1
    expect(await supportLevel(u)).toBe(5);
    expect((await frames(u)).map((f) => f.code)).toEqual(['support_frame_01']);
    const owned = await ctx.prisma.userBagItem.count({ where: { userId: u.id, category: 'AVATAR_FRAME' } });
    expect(owned).toBe(1);
  });

  it('jumping tiers gives every frame passed; a deduction keeps level and frames; level 100 gives frame 21', async () => {
    const u = await signup();
    await adjust(u, at(12)); // level 12 → tier 3
    expect(await supportLevel(u)).toBe(12);
    expect((await frames(u)).map((f) => f.code)).toEqual([
      'support_frame_01',
      'support_frame_02',
      'support_frame_03',
    ]);

    // A deduction that is not fraud: the points drop to level 2's, the level stays 12 (owner).
    await adjust(u, -(at(12) - at(2)));
    expect(await supportLevel(u)).toBe(12);
    expect(await frames(u)).toHaveLength(3);
    const me = await ctx.http.get('/api/v1/levels/me/support').set(auth(u));
    expect(me.body.progressPercent).toBe(0);
    expect(me.body.pointsToNext).toBe((at(13) - at(2)).toString());

    await adjust(u, at(100) - at(2)); // level 100 → tier 21
    expect(await supportLevel(u)).toBe(100);
    const all = await frames(u);
    expect(all).toHaveLength(21);
    expect(all.at(-1)?.code).toBe('support_frame_21');
    expect(all.every((f) => !f.equipped && f.source === 'LEVEL_REWARD')).toBe(true);
  });

  it('a frame can be worn like any bag item; other categories never give frames', async () => {
    const u = await signup();
    await adjust(u, at(7)); // tier 2
    const put = await ctx.http
      .put('/api/v1/me/bag/equipped')
      .set(auth(u))
      .send({ category: 'AVATAR_FRAME', code: 'support_frame_02' });
    expect(put.status).toBe(200);
    expectContract(put, 'setMyBagEquipped');
    expect(put.body.equipped.code).toBe('support_frame_02');
    const notOwned = await ctx.http
      .put('/api/v1/me/bag/equipped')
      .set(auth(u))
      .send({ category: 'AVATAR_FRAME', code: 'support_frame_03' });
    expect(notOwned.status).toBe(409);
    // The profile card (PROFILE_CARD) is untouched by the reward.
    const cards = await ctx.http.get('/api/v1/me/bag?category=PROFILE_CARD').set(auth(u));
    expect((cards.body.data as { source: string }[]).every((i) => i.source !== 'LEVEL_REWARD')).toBe(true);
  });

  it('only a fraud deduction lowers the level, and it takes back the frames of the tiers lost', async () => {
    const u = await signup();
    await adjust(u, at(12)); // level 12, frames 1–3
    await ctx.http
      .put('/api/v1/me/bag/equipped')
      .set(auth(u))
      .send({ category: 'AVATAR_FRAME', code: 'support_frame_03' })
      .expect(200);

    // Fraud needs a deduction.
    const bad = await ctx.http
      .post(`/api/v1/admin/levels/users/${u.id}/adjustments`)
      .set(auth(admin))
      .set('Idempotency-Key', randomUUID())
      .send({ category: 'SUPPORT', pointsDelta: '10', reason: 'not a deduction', fraud: true });
    expect(bad.status).toBe(400);
    expectContract(bad, 'createAdminLevelAdjustment');
    expect(bad.body.error.details).toEqual([{ field: 'fraud', issue: 'fraud_needs_deduction' }]);

    const key = randomUUID();
    await adjust(u, -(at(12) - at(2)), key, true); // back to level 2: tier 1
    expect(await supportLevel(u)).toBe(2);
    expect((await frames(u)).map((f) => f.code)).toEqual(['support_frame_01']);
    // The worn frame went with it: nothing is worn now.
    const worn = await ctx.prisma.userBagItem.count({
      where: { userId: u.id, category: 'AVATAR_FRAME', equipped: true },
    });
    expect(worn).toBe(0);
    // The history says why.
    const history = await ctx.prisma.levelHistory.findFirst({
      where: { userId: u.id, newLevel: 2 },
      orderBy: { createdAt: 'desc' },
    });
    expect(history?.reason).toBe('FRAUD');
    // Replaying the same key with another fraud flag is a conflict.
    const replay = await ctx.http
      .post(`/api/v1/admin/levels/users/${u.id}/adjustments`)
      .set(auth(admin))
      .set('Idempotency-Key', key)
      .send({
        category: 'SUPPORT',
        pointsDelta: (-(at(12) - at(2))).toString(),
        reason: 'D169 tier frame test',
      });
    expect(replay.status).toBe(409);
    expectContract(replay, 'createAdminLevelAdjustment');
    expect(replay.body.error.code).toBe('IDEMPOTENCY_CONFLICT');
  });

  it('a harder new version never lowers a level; frames stay', async () => {
    const u = await signup();
    await adjust(u, at(12)); // level 12
    const category = await ctx.prisma.levelCategory.findFirstOrThrow({ where: { code: 'SUPPORT' } });
    const harder = await ctx.prisma.levelCategoryVersion.create({
      data: {
        categoryId: category.id,
        versionNumber: 2,
        status: 'DRAFT',
        multiplier: '0.1',
        valueUnit: 'COIN',
        levels: {
          create: presetLadder().map((l) => ({ ...l, requiredPoints: l.requiredPoints * 10n })),
        },
      },
    });
    await withMigrationClient((db) =>
      db.userAdminPermission.createMany({
        data: ['LEVELS_PUBLISH', 'LEVELS_VIEW', 'LEVELS_EDIT'].map((permission) => ({
          userId: admin.id,
          permission: permission as 'LEVELS_PUBLISH',
        })),
        skipDuplicates: true,
      }),
    );
    const pub = await ctx.http
      .post(`/api/v1/admin/levels/versions/${harder.id}/publish`)
      .set(auth(admin))
      .send({ recalculation: 'PRESERVE_POINTS' });
    expect(pub.status).toBe(200);
    // Under the new ladder 12's points reach level 3 only; the level stays 12.
    expect(await supportLevel(u)).toBe(12);
    expect(await frames(u)).toHaveLength(3);
  });
});
