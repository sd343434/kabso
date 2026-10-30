import type { Prisma } from '../../generated/prisma/client.js';
import { DEFAULT_TASKS } from './programs-rules.js';

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
