/**
 * D194 (v1.63-social, CONVENTIONS §10.57): the level ladder repriced. Publishing the new ladder over
 * the old one keeps every level (owner D169): the user gets `carriedPoints` so `points +
 * carriedPoints` sits at the kept level's new threshold plus what they had made inside it; progress
 * then follows the new ladder; frames, the room level and the task band stay; only a fraud
 * deduction lowers a level (taking its share of the carry).
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

/** The 2026-10-20 ladder D194 replaced. */
function oldLadder() {
  const steps: [number, bigint][] = [
    [10, 10n],
    [20, 50n],
    [30, 150n],
    [40, 400n],
    [50, 1_000n],
    [60, 2_500n],
    [80, 6_000n],
    [99, 15_000n],
    [100, 100_000n],
  ];
  let required = 0n;
  return presetLadder().map((l) => {
    if (l.levelNumber > 1) required += steps.find(([last]) => l.levelNumber <= last)![1];
    return { ...l, requiredPoints: required };
  });
}

const OLD = oldLadder();
const NEW = presetLadder();
const oldAt = (n: number) => OLD[n - 1]!.requiredPoints;
const newAt = (n: number) => NEW[n - 1]!.requiredPoints;

describe('D194 level ladder', () => {
  let ctx: TestContext;
  let admin: TestUser;
  let supporter: TestUser;
  let host: TestUser;
  let fresh: TestUser;

  const signup = async (): Promise<TestUser> => {
    const { res } = await registerVerified(ctx);
    expect(res.status).toBe(201);
    return { id: res.body.user.id, token: res.body.tokens.accessToken };
  };
  const auth = (u: TestUser) => ({ Authorization: `Bearer ${u.token}` });

  const adjust = async (
    u: TestUser,
    category: 'SUPPORT' | 'ATTRACTIVENESS',
    delta: bigint,
    fraud?: boolean,
  ) => {
    const res = await ctx.http
      .post(`/api/v1/admin/levels/users/${u.id}/adjustments`)
      .set(auth(admin))
      .set('Idempotency-Key', randomUUID())
      .send({
        category,
        pointsDelta: delta.toString(),
        reason: 'D194 ladder test',
        ...(fraud === undefined ? {} : { fraud }),
      });
    expect(res.status).toBe(200);
    expectContract(res, 'createAdminLevelAdjustment');
    return res;
  };

  const mine = async (u: TestUser, slug: 'support' | 'attractiveness') => {
    const res = await ctx.http.get(`/api/v1/levels/me/${slug}`).set(auth(u));
    expect(res.status).toBe(200);
    expectContract(res, 'getMyLevel');
    return res.body as {
      points: string;
      carriedPoints: string;
      level: { levelNumber: number } | null;
      nextLevel: { levelNumber: number; requiredPoints: string } | null;
      pointsToNext: string | null;
      progressPercent: number | null;
      levels: { requiredPoints: string }[];
    };
  };

  const frames = async (u: TestUser) =>
    ctx.prisma.userBagItem.count({ where: { userId: u.id, category: 'AVATAR_FRAME' } });

  beforeAll(async () => {
    ctx = await createTestApp();
    await ctx.prisma.bagItem.createMany({ data: BAG_CATALOGUE.map((i) => ({ ...i })) });
    for (const [code, nameAr, nameEn, published] of [
      ['ATTRACTIVENESS', 'مستوى الجاذبية', 'Attractiveness', true],
      ['SUPPORT', 'مستوى الدعم', 'Support', true],
      ['WIZARD', 'مستوى الساحر', 'Wizard', false],
      ['GAMING', 'مستوى اللعب', 'Gaming', false],
    ] as const) {
      const category = await ctx.prisma.levelCategory.create({
        data: { code, nameAr, nameEn, descriptionAr: `وصف ${nameAr}`, descriptionEn: `About ${nameEn}` },
      });
      if (!published) continue;
      const version = await ctx.prisma.levelCategoryVersion.create({
        data: {
          categoryId: category.id,
          versionNumber: 1,
          status: 'PUBLISHED',
          multiplier: '0.1',
          valueUnit: 'COIN',
          publishedAt: new Date(),
          levels: { create: OLD },
        },
      });
      await ctx.prisma.levelCategory.update({
        where: { id: category.id },
        data: { isEnabled: true, publishedVersionId: version.id },
      });
    }
    admin = await signup();
    await ctx.prisma.user.update({ where: { id: admin.id }, data: { role: 'ADMIN' } });
    await withMigrationClient((db) =>
      db.userAdminPermission.createMany({
        data: (['LEVELS_ADJUST', 'LEVELS_PUBLISH', 'LEVELS_VIEW', 'LEVELS_EDIT'] as const).map(
          (permission) => ({ userId: admin.id, permission }),
        ),
      }),
    );

    // On the old ladder: a supporter at level 50 (410 points into it), a host at charm level 30
    // kept after a reversal (points below its threshold), someone new at level 1.
    supporter = await signup();
    host = await signup();
    fresh = await signup();
    await adjust(supporter, 'SUPPORT', oldAt(50) + 410n);
    await adjust(host, 'ATTRACTIVENESS', oldAt(30));
    await adjust(host, 'ATTRACTIVENESS', -1_000n); // not fraud: the level stays 30
    await adjust(fresh, 'SUPPORT', 5n);
    expect((await mine(supporter, 'support')).level?.levelNumber).toBe(50);
    expect((await mine(host, 'attractiveness')).level?.levelNumber).toBe(30);
    expect(await frames(supporter)).toBe(10); // support tiers 1–10

    // The owner's new ladder, published over the old one in both categories.
    for (const code of ['SUPPORT', 'ATTRACTIVENESS'] as const) {
      const category = await ctx.prisma.levelCategory.findFirstOrThrow({ where: { code } });
      const draft = await ctx.prisma.levelCategoryVersion.create({
        data: {
          categoryId: category.id,
          versionNumber: 2,
          status: 'DRAFT',
          multiplier: '0.1',
          valueUnit: 'COIN',
          levels: { create: NEW },
        },
      });
      const pub = await ctx.http
        .post(`/api/v1/admin/levels/versions/${draft.id}/publish`)
        .set(auth(admin))
        .send({ recalculation: 'PRESERVE_POINTS' });
      expect(pub.status).toBe(200);
    }
  });

  afterAll(async () => ctx?.close());

  it('keeps the level and measures progress from its new threshold plus the points made inside it', async () => {
    const s = await mine(supporter, 'support');
    expect(s.points).toBe((oldAt(50) + 410n).toString());
    expect(BigInt(s.carriedPoints)).toBe(newAt(50) - oldAt(50));
    expect(s.level?.levelNumber).toBe(50);
    expect(s.nextLevel).toMatchObject({ levelNumber: 51, requiredPoints: newAt(51).toString() });
    expect(s.pointsToNext).toBe((newAt(51) - newAt(50) - 410n).toString());
    expect(s.progressPercent).toBe(0); // 410 of 3 200 000
    expect(s.levels[99]!.requiredPoints).toBe('2000840500');
    expect(await frames(supporter)).toBe(10);

    const h = await mine(host, 'attractiveness');
    expect(h.level?.levelNumber).toBe(30);
    expect(BigInt(h.points) + BigInt(h.carriedPoints)).toBe(newAt(30));
    expect(h.progressPercent).toBe(0);

    const f = await mine(fresh, 'support');
    expect(f).toMatchObject({ points: '5', carriedPoints: '0' });
    expect(f.level?.levelNumber).toBe(1);
    expect(f.pointsToNext).toBe((newAt(2) - 5n).toString());
  });

  it('further progress follows the new ladder; a new tier still gives its frame', async () => {
    const step = newAt(51) - newAt(50);
    await adjust(supporter, 'SUPPORT', step / 2n - 410n);
    expect((await mine(supporter, 'support')).progressPercent).toBe(50);
    await adjust(supporter, 'SUPPORT', step / 2n);
    const s = await mine(supporter, 'support');
    expect(s.level?.levelNumber).toBe(51);
    expect(s.progressPercent).toBe(0);
    expect(await frames(supporter)).toBe(11); // level 51 → tier 11
  });

  it('the task band (higher of Support and Charm) and the room level keep the kept levels', async () => {
    const tasks = await ctx.http.get('/api/v1/me/tasks').set(auth(host));
    expect(tasks.status).toBe(200);
    expect(tasks.body.band.level).toBe(30);
    const state = await ctx.prisma.userLevelState.findFirstOrThrow({
      where: { userId: host.id, category: { code: 'ATTRACTIVENESS' } },
    });
    expect(state.currentLevel).toBe(30);
  });

  it('a non-fraud deduction keeps the level; a fraud one lowers it and takes its share of the carry', async () => {
    await adjust(host, 'ATTRACTIVENESS', -500n);
    expect((await mine(host, 'attractiveness')).level?.levelNumber).toBe(30);

    const before = await mine(supporter, 'support');
    const total = BigInt(before.points);
    const carried = BigInt(before.carriedPoints);
    await adjust(supporter, 'SUPPORT', -(total / 2n), true);
    const after = await mine(supporter, 'support');
    const left = total - total / 2n;
    expect(BigInt(after.carriedPoints)).toBe((carried * left) / total);
    const level = after.level!.levelNumber;
    expect(level).toBeLessThan(51);
    expect(BigInt(after.points) + BigInt(after.carriedPoints) >= newAt(level)).toBe(true);
    expect(BigInt(after.points) + BigInt(after.carriedPoints) < newAt(level + 1)).toBe(true);
    expect(await frames(supporter)).toBe(Math.floor((level - 1) / 5) + 1);
  });
});
