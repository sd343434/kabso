/**
 * D200 (CONVENTIONS §10.21 amendment): family levels and the family price repriced for the coin
 * price 1 000 000 coins = $12.50. Creating a family costs 1 000 000 coins; the ladder is level 2 at
 * 4 000 000 points … level 10 at 24 000 000 000. No family drops a level: the stored level is a
 * floor, the D200 migration only raises a level, and a family kept above what its points reach
 * shows the next level's threshold (`nextLevelPoints`) honestly.
 */
import { readFileSync } from 'node:fs';
import { randomUUID } from 'node:crypto';
import { fileURLToPath } from 'node:url';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { FAMILY_CREATE_COST_COINS } from '../src/modules/families/families.constants.js';
import { uuidv7 } from '../src/modules/levels/uuidv7.js';
import { creditIn } from '../src/modules/wallet/wallet-ledger.js';
import { WalletService } from '../src/modules/wallet/wallet.service.js';
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

const MIGRATION = fileURLToPath(
  new URL('../prisma/migrations/20270113100000_family_levels_d200/migration.sql', import.meta.url),
);

describe('D200 family levels and price', () => {
  let ctx: TestContext;

  const signup = async (): Promise<TestUser> => {
    const { res } = await registerVerified(ctx);
    expect(res.status).toBe(201);
    return { id: res.body.user.id as string, token: res.body.tokens.accessToken as string };
  };
  const auth = (u: TestUser) => ({ Authorization: `Bearer ${u.token}` });
  const grant = (u: TestUser, coins: number) =>
    ctx.prisma.$transaction((tx) => creditIn(tx, u.id, BigInt(coins), 'ADMIN_GRANT', uuidv7()));
  const balance = async (u: TestUser): Promise<number> => {
    const res = await ctx.http.get('/api/v1/wallet/me').set(auth(u));
    expect(res.status).toBe(200);
    return res.body.coins as number;
  };
  /** A real spend that counts for the spender's family (as a bullet message). */
  const spend = async (u: TestUser, coins: number) => {
    await grant(u, coins);
    const wallet = ctx.app.get(WalletService);
    const done = await ctx.prisma.$transaction((tx) =>
      wallet.debitIn(tx, u.id, coins, 'BULLET_MESSAGE', uuidv7()),
    );
    expect(done).not.toBeNull();
  };
  const create = (u: TestUser, name: string) =>
    ctx.http.post('/api/v1/families').set(auth(u)).send({ name, clientId: randomUUID() });
  const newFamily = async (u: TestUser, name: string): Promise<string> => {
    await grant(u, FAMILY_CREATE_COST_COINS);
    const res = await create(u, name);
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    return res.body.family.id as string;
  };
  const read = async (u: TestUser, id: string) => {
    const res = await ctx.http.get(`/api/v1/families/${id}`).set(auth(u));
    expect(res.status).toBe(200);
    expectContract(res, 'getFamily');
    return res.body as { level: number; points: number; nextLevelPoints: number | null };
  };
  const setFamily = (id: string, points: bigint, level: number) =>
    ctx.prisma.family.update({ where: { id }, data: { points, level } });

  beforeAll(async () => {
    ctx = await createTestApp();
  });
  afterAll(async () => ctx?.close());

  it('creating a family costs 1 000 000 coins and refuses 999 999', async () => {
    const u = await signup();
    await grant(u, 999_999);
    const short = await create(u, 'Price house');
    expect(short.status).toBe(409);
    expectContract(short, 'createFamily');
    expect(short.body.error.code).toBe('INSUFFICIENT_COINS');
    expect(await balance(u)).toBe(999_999);
    expect(await ctx.prisma.family.count({ where: { createdById: u.id } })).toBe(0);

    await grant(u, 1);
    const made = await create(u, 'Price house');
    expect(made.status).toBe(201);
    expectContract(made, 'createFamily');
    expect(made.body.coins).toBe(0);
    expect(made.body.family).toMatchObject({ level: 1, points: 1_000_000, nextLevelPoints: 4_000_000 });
    const rows = await ctx.prisma.walletLedgerEntry.findMany({
      where: { userId: u.id, reason: 'FAMILY_CREATE' },
    });
    expect(rows.map((r) => Number(r.delta))).toEqual([-1_000_000]);

    const config = await ctx.http.get('/api/v1/families/config').set(auth(u));
    expectContract(config, 'getFamilyConfig');
    expect(config.body.createCost).toBe(1_000_000);
    expect(config.body.levels.map((s: { minPoints: number }) => s.minPoints)).toEqual([
      0, 4_000_000, 20_000_000, 80_000_000, 240_000_000, 640_000_000, 1_600_000_000, 4_000_000_000,
      9_600_000_000, 24_000_000_000,
    ]);
  });

  it('rises at the new thresholds (n − 1 stays, n levels up), up to level 10', async () => {
    const lead = await signup();
    const id = await newFamily(lead, 'Ladder house');
    // 1 000 000 from the creation; 2 999 999 more is one short of level 2.
    await spend(lead, 2_999_999);
    expect(await read(lead, id)).toMatchObject({ points: 3_999_999, level: 1, nextLevelPoints: 4_000_000 });
    await spend(lead, 1);
    expect(await read(lead, id)).toMatchObject({ points: 4_000_000, level: 2, nextLevelPoints: 20_000_000 });

    await setFamily(id, 9_600_000_000n - 2n, 2);
    await spend(lead, 1);
    expect(await read(lead, id)).toMatchObject({ level: 8, nextLevelPoints: 9_600_000_000 });
    await spend(lead, 1);
    expect(await read(lead, id)).toMatchObject({ points: 9_600_000_000, level: 9 });
    await setFamily(id, 24_000_000_000n - 1n, 9);
    await spend(lead, 1);
    expect(await read(lead, id)).toMatchObject({ points: 24_000_000_000, level: 10, nextLevelPoints: null });
  });

  it('keeps a level reached under the old ladder (the floor) and shows honest progress', async () => {
    const lead = await signup();
    const id = await newFamily(lead, 'Old guard');
    // Level 5 under D106 (50 000 points); its points reach only level 1 on the D200 ladder.
    await setFamily(id, 60_000n, 5);
    await spend(lead, 15);
    // Still 5; the next level is 6 at 640 000 000 points (the bar: 60 015 / 640 000 000 ≈ 0 %).
    expect(await read(lead, id)).toMatchObject({ points: 60_015, level: 5, nextLevelPoints: 640_000_000 });
    // It rises again only at the new threshold of level 6.
    await setFamily(id, 640_000_000n - 1n, 5);
    await spend(lead, 1);
    expect(await read(lead, id)).toMatchObject({ level: 6, nextLevelPoints: 1_600_000_000 });
  });

  it('the D200 migration never lowers a family level and raises one its points pass', async () => {
    const lead = [await signup(), await signup(), await signup()];
    const kept = await newFamily(lead[0]!, 'Kept house');
    const top = await newFamily(lead[1]!, 'Top house');
    const plain = await newFamily(lead[2]!, 'Plain house');
    await setFamily(kept, 6_000n, 3); // level 3 under the old ladder
    await setFamily(top, 25_000_000_000n, 4); // its points reach 10
    await setFamily(plain, 1_000_000n, 1);
    const sql = readFileSync(MIGRATION, 'utf8');
    await withMigrationClient((c) => c.$executeRawUnsafe(sql));
    const levels = await ctx.prisma.family.findMany({
      where: { id: { in: [kept, top, plain] } },
      select: { id: true, level: true, points: true },
    });
    const byId = new Map(levels.map((f) => [f.id, f]));
    expect(byId.get(kept)).toMatchObject({ level: 3, points: 6_000n });
    expect(byId.get(top)).toMatchObject({ level: 10, points: 25_000_000_000n });
    expect(byId.get(plain)).toMatchObject({ level: 1, points: 1_000_000n });
    // Every family at least at its ladder level after the migration, none above 10.
    const below = await withMigrationClient((c) =>
      c.$queryRawUnsafe<{ n: bigint }[]>(
        `SELECT count(*) AS n FROM families WHERE disbanded_at IS NULL AND level < CASE
           WHEN points >= 24000000000 THEN 10 WHEN points >= 4000000 THEN 2 ELSE 1 END`,
      ),
    );
    expect(Number(below[0]!.n)).toBe(0);
  });
});
