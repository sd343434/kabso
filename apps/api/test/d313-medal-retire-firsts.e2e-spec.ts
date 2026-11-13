/**
 * D313 (owner 2026-11-08: «ميداليات موجودة: أول لايف، وأول رسالة عامة، وأول عائلة، وأول ثنائي — ازلها»; CONVENTIONS
 * §10.104.8): FIRST_LIVE «أول لايف», BULLET_FIRST «أول رسالة عامة», FIRST_FAMILY «أول عائلة» and FIRST_CP «أول ثنائي» are
 * retired exactly as D291 retired the charm and live-hours codes — end to end against PostgreSQL + Redis, with the
 * catalogue as the migrations leave it:
 *
 * - never awarded again, from any of their events (lives hosted, bullets, a family, a couple), with no notification;
 * - left out of the medals page, the totals, the profile, the lists; wearing one → 400 `medalCodes` / `invalid_value`;
 * - the migration clears their showcase positions and renumbers the rest; the rows are kept as history.
 */
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import type { Prisma } from '../src/generated/prisma/client.js';
import {
  awardBulletMedalsIn,
  awardCoupleMedalsIn,
  awardFamilyMedalsIn,
  raiseMedalLevelsIn,
} from '../src/modules/medals/medal-awards.js';
import {
  MEDAL_CATALOGUE,
  MEDAL_DEFAULT_LEVELS,
  RETIRED_MEDAL_CODES,
} from '../src/modules/medals/medals.catalogue.js';
import { D313_RETIRED, seedMedalCatalogue } from './helpers/medals.js';
import { expectContract } from './helpers/openapi.js';
import {
  createTestApp,
  registerVerified,
  withMigrationClient,
  type TestContext,
} from './helpers/test-app.js';

interface TestUser {
  readonly id: string;
  readonly username: string;
  readonly token: string;
}

describe('D313 the four «first» medals are retired', { timeout: 300_000 }, () => {
  let ctx: TestContext;
  const auth = (u: { token: string }) => ({ Authorization: `Bearer ${u.token}` });
  const tx = <T>(fn: (t: Prisma.TransactionClient) => Promise<T>): Promise<T> => ctx.prisma.$transaction(fn);
  const signup = async (): Promise<TestUser> => {
    const { res } = await registerVerified(ctx);
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    return {
      id: res.body.user.id as string,
      username: res.body.user.username as string,
      token: res.body.tokens.accessToken as string,
    };
  };
  const wearable = MEDAL_CATALOGUE.filter((m) => !RETIRED_MEDAL_CODES.has(m.code)).map((m) => m.code);

  beforeAll(async () => {
    ctx = await createTestApp({
      RATE_LIMIT_PROFILE_USER: '100000/900',
      RATE_LIMIT_AUTHENTICATED_USER: '100000/900',
    });
    await seedMedalCatalogue(ctx.prisma);
  });
  afterAll(async () => {
    await ctx?.close();
  });

  it('the catalogue: the four codes are retired, as D291’s five; four wearable medals are left', async () => {
    for (const code of ['FIRST_LIVE', 'BULLET_FIRST', 'FIRST_FAMILY', 'FIRST_CP'] as const) {
      expect(RETIRED_MEDAL_CODES.has(code)).toBe(true);
      expect(D313_RETIRED.has(code)).toBe(true);
      expect((await ctx.prisma.medal.findUniqueOrThrow({ where: { code } })).retired).toBe(true);
    }
    expect(MEDAL_CATALOGUE.find((m) => m.code === 'BULLET_FIRST')?.nameAr).toBe('أول رسالة عامة');
    expect(wearable.sort()).toEqual(['CONTENT_SCHOOL', 'DARES_PLAYER', 'LUCKY_MASTER', 'WEALTH_KINGS']);
  });

  it('never awarded again by any of their events, and nobody is notified', async () => {
    const u = await signup();
    const v = await signup();
    // Values far past every level of the four (lives hosted, bullets, a family, a couple).
    await tx((t) =>
      raiseMedalLevelsIn(t, 'LIVES_HOSTED', [
        { userId: u.id, value: MEDAL_DEFAULT_LEVELS.FIRST_LIVE.at(-1)! * 2 },
      ]),
    );
    await tx((t) =>
      raiseMedalLevelsIn(t, 'BULLETS_SENT', [
        { userId: u.id, value: MEDAL_DEFAULT_LEVELS.BULLET_FIRST.at(-1)! * 2 },
      ]),
    );
    await tx((t) => awardBulletMedalsIn(t, u.id));
    await tx((t) => awardFamilyMedalsIn(t, [u.id, v.id]));
    await tx((t) => awardCoupleMedalsIn(t, [u.id, v.id]));
    expect(await ctx.prisma.userMedal.count({ where: { userId: { in: [u.id, v.id] } } })).toBe(0);
    expect(
      await ctx.prisma.notification.count({
        where: { recipientId: { in: [u.id, v.id] }, type: 'MEDAL_AWARDED' },
      }),
    ).toBe(0);
  });

  it('earned before: kept as history but never shown, counted or worn', async () => {
    const u = await signup();
    const reader = await signup();
    await ctx.prisma.userMedal.createMany({
      data: [
        { userId: u.id, medalCode: 'FIRST_LIVE', level: 3 },
        { userId: u.id, medalCode: 'BULLET_FIRST', level: 2 },
        { userId: u.id, medalCode: 'FIRST_FAMILY', level: 1 },
        { userId: u.id, medalCode: 'FIRST_CP', level: 1 },
        { userId: u.id, medalCode: 'WEALTH_KINGS', level: 1 },
      ],
    });
    const page = await ctx.http.get('/api/v1/medals').set(auth(u)).set('Accept-Language', 'ar');
    expect(page.status).toBe(200);
    expectContract(page, 'listMedals');
    const codes = (page.body.data as { code: string }[]).map((m) => m.code);
    expect(codes.sort()).toEqual([...wearable].sort());
    expect(page.body).toMatchObject({ total: wearable.length, owned: 1 });

    for (const code of ['FIRST_LIVE', 'BULLET_FIRST', 'FIRST_FAMILY', 'FIRST_CP']) {
      const res = await ctx.http
        .put('/api/v1/me/medals/showcase')
        .set(auth(u))
        .send({ medalCodes: [code] });
      expect(res.status, code).toBe(400);
      expectContract(res, 'setMyMedalShowcase');
      expect(res.body.error.details).toEqual([{ field: 'medalCodes', issue: 'invalid_value' }]);
    }

    const prof = await ctx.http.get(`/api/v1/users/${u.username}`).set(auth(reader));
    expect(prof.status).toBe(200);
    expectContract(prof, 'getPublicProfile');
    expect(prof.body.medals).toMatchObject({ owned: 1, total: wearable.length });
    expect((prof.body.medals.latest as { code: string }[]).map((m) => m.code)).toEqual(['WEALTH_KINGS']);
    const list = await ctx.http.get(`/api/v1/users/${u.username}/medals`).set(auth(reader));
    expect(list.status).toBe(200);
    expectContract(list, 'listUserMedals');
    expect((list.body.data as { code: string }[]).map((m) => m.code)).toEqual(['WEALTH_KINGS']);
    // History kept.
    expect(await ctx.prisma.userMedal.count({ where: { userId: u.id } })).toBe(5);
  });

  it('the migration clears their showcase positions and renumbers the rest (rows kept)', async () => {
    const u = await signup();
    // As before D313: the four live, worn with a wearable one in between.
    await ctx.prisma.medal.updateMany({
      where: { code: { in: [...D313_RETIRED] } },
      data: { retired: false },
    });
    await ctx.prisma.userMedal.createMany({
      data: [
        { userId: u.id, medalCode: 'FIRST_LIVE', showcasePosition: 1 },
        { userId: u.id, medalCode: 'WEALTH_KINGS', showcasePosition: 2 },
        { userId: u.id, medalCode: 'BULLET_FIRST', showcasePosition: 3 },
        { userId: u.id, medalCode: 'LUCKY_MASTER', showcasePosition: 4 },
        { userId: u.id, medalCode: 'FIRST_CP', showcasePosition: 5 },
        { userId: u.id, medalCode: 'FIRST_FAMILY' },
      ],
    });
    const sql = readFileSync(
      fileURLToPath(
        new URL('../prisma/migrations/20270407090100_medal_retire_firsts/migration.sql', import.meta.url),
      ),
      'utf8',
    );
    // One transaction: one connection, so the migration's temporary table is seen by every statement.
    await withMigrationClient((db) =>
      db.$transaction(async (t) => {
        for (const stmt of sql
          .split(/;\s*\n/)
          .map((x) => x.replace(/^(\s*--[^\n]*\n)+/, '').trim())
          .filter((x) => x.length > 0)) {
          await t.$executeRawUnsafe(stmt);
        }
      }),
    );
    for (const code of D313_RETIRED) {
      expect((await ctx.prisma.medal.findUniqueOrThrow({ where: { code } })).retired, code).toBe(true);
    }
    const rows = await ctx.prisma.userMedal.findMany({
      where: { userId: u.id },
      orderBy: { medalCode: 'asc' },
    });
    expect(rows.map((r) => [r.medalCode, r.showcasePosition])).toEqual([
      ['BULLET_FIRST', null],
      ['FIRST_CP', null],
      ['FIRST_FAMILY', null],
      ['FIRST_LIVE', null],
      ['LUCKY_MASTER', 2],
      ['WEALTH_KINGS', 1],
    ]);
  });
});
