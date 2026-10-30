import type { Prisma } from '../../generated/prisma/client.js';
import { DEFAULT_POOL_TASKS, DEFAULT_TASK_POOL_BANDS, DEFAULT_TASKS } from './programs-rules.js';

type SeedDb = Pick<Prisma.TransactionClient, 'taskDefinition' | 'taskPoolBand'>;

/**
 * Adds the default tasks that are missing (never changes an existing row); returns how many were added.
 * Shared by the `task-admin seed-defaults` CLI and the e2e tests (no Nest dependencies).
 */
export async function seedDefaultTasksIn(
  db: Pick<Prisma.TransactionClient, 'taskDefinition'>,
): Promise<number> {
  const result = await db.taskDefinition.createMany({
    data: DEFAULT_TASKS.map((t) => ({ ...t })),
    skipDuplicates: true,
  });
  return result.count;
}

/** The fixed daily tasks of D166 that the pool replaces (migration 20261230090000_daily_task_pool). */
export const POOL_REPLACES_TASKS = ['WATCH_LIVE', 'FOLLOW_USERS', 'LIVE_CHAT', 'SEND_GIFTS'] as const;

/**
 * v1.50-social (D176): adds the default level bands and pool templates that are missing (never
 * changes an existing band or template); returns how many templates were added. Like the migration,
 * the first time the pool is added it switches D166's four fixed daily tasks off.
 */
export async function seedDefaultTaskPoolIn(db: SeedDb): Promise<number> {
  await db.taskPoolBand.createMany({
    data: DEFAULT_TASK_POOL_BANDS.map((b) => ({ ...b })),
    skipDuplicates: true,
  });
  const result = await db.taskDefinition.createMany({
    data: DEFAULT_POOL_TASKS.map((t) => ({
      code: t.code,
      period: 'DAILY' as const,
      metric: t.metric,
      target: Math.max(...t.bandTargets),
      rewardCoins: Math.max(...t.bandRewards),
      audience: t.audience,
      nameAr: t.nameAr,
      nameEn: t.nameEn,
      sortOrder: t.sortOrder,
      pool: true,
      poolGroup: t.group,
      bandTargets: [...t.bandTargets],
      bandRewards: [...t.bandRewards],
    })),
    skipDuplicates: true,
  });
  if (result.count === DEFAULT_POOL_TASKS.length) {
    await db.taskDefinition.updateMany({
      where: { code: { in: [...POOL_REPLACES_TASKS] }, pool: false },
      data: { enabled: false },
    });
  }
  return result.count;
}
