import type { Prisma } from '../../generated/prisma/client.js';
import {
  DEFAULT_CREATOR_POOL_TASKS,
  DEFAULT_CREATOR_TASKS,
  DEFAULT_D297_HOST_TASKS,
  DEFAULT_POOL_TASKS,
  DEFAULT_TASK_POOL_BANDS,
  DEFAULT_TASKS,
  type DefaultPoolTask,
} from './programs-rules.js';
import {
  GEN_DEFAULT_STEP,
  GEN_ENTRIES,
  genName,
  genReward,
  genTarget,
  genTemplateCode,
} from './task-generator.js';

type SeedDb = Pick<Prisma.TransactionClient, 'taskDefinition' | 'taskPoolBand'>;

/**
 * Adds the default tasks that are missing (never changes an existing row); returns how many were added.
 * Shared by the `task-admin seed-defaults` CLI and the e2e tests (no Nest dependencies).
 */
export async function seedDefaultTasksIn(
  db: Pick<Prisma.TransactionClient, 'taskDefinition'>,
): Promise<number> {
  const result = await db.taskDefinition.createMany({
    data: DEFAULT_TASKS.map((t) => ({
      ...t,
      bandTargets: t.bandTargets ? [...t.bandTargets] : [],
      bandRewards: t.bandRewards ? [...t.bandRewards] : [],
    })),
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
    data: DEFAULT_POOL_TASKS.map(poolRow),
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

/** A pool template's `task_definitions` row (`target` / `reward_cherries` mirror its highest band). */
function poolRow(t: DefaultPoolTask) {
  return {
    code: t.code,
    period: 'DAILY' as const,
    metric: t.metric,
    target: Math.max(...t.bandTargets),
    rewardCherries: Math.max(...t.bandRewards),
    audience: t.audience,
    nameAr: t.nameAr,
    nameEn: t.nameEn,
    sortOrder: t.sortOrder,
    enabled: t.enabled ?? true,
    pool: true,
    poolGroup: t.group,
    bandTargets: [...t.bandTargets],
    bandRewards: [...t.bandRewards],
  };
}

/**
 * v1.94-social (D297, CONVENTIONS §10.110, §10.110.1): adds the D297 rows that are missing — the CREATOR pool
 * templates, the six weekly creator tasks, the two extra weekly host tasks and the generator's 32 template rows
 * (`G_CR_…`, `G_HO_…`; `generator` false seeds them switched off) — as migrations 20270331090100_creator_tasks and
 * 20270331090200_task_generator seed them (never changes an existing row); returns how many were added. Shared by
 * `task-admin seed-defaults` and the e2e tests.
 */
export async function seedD297TasksIn(
  db: Pick<Prisma.TransactionClient, 'taskDefinition'>,
  options: { generator: boolean } = { generator: true },
): Promise<number> {
  const result = await db.taskDefinition.createMany({
    data: [
      ...DEFAULT_CREATOR_POOL_TASKS.map(poolRow),
      ...[...DEFAULT_CREATOR_TASKS, ...DEFAULT_D297_HOST_TASKS].map((t) => ({
        ...t,
        bandTargets: t.bandTargets ? [...t.bandTargets] : [],
        bandRewards: t.bandRewards ? [...t.bandRewards] : [],
      })),
      ...GEN_ENTRIES.map((entry, i) => {
        const name = genName(entry, 0);
        return {
          code: genTemplateCode(entry),
          period: entry.period,
          metric: entry.metric,
          target: genTarget(entry, 0, GEN_DEFAULT_STEP),
          rewardCherries: genReward(entry, 0, GEN_DEFAULT_STEP),
          audience: entry.audience,
          nameAr: name.ar,
          nameEn: name.en,
          sortOrder: 1000 + i * 10,
          enabled: options.generator,
        };
      }),
    ],
    skipDuplicates: true,
  });
  return result.count;
}
