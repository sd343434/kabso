import type { PrismaService } from '../../src/prisma/prisma.service.js';

/**
 * D281: keeps a suite on the engine before the smart targets and tasks (D176's pool, D277's two targets) — the
 * behaviour of the day of the switch and of any day before it — by putting the smart engine's first day far ahead.
 * The suites written for those rules call it right after `createTestApp` (which truncates the tables).
 */
export async function keepLegacyTargetsEngine(prisma: PrismaService): Promise<void> {
  await prisma.hostTargetSettings.upsert({
    where: { id: 1 },
    create: { id: 1, engineFrom: new Date('2999-01-01T00:00:00.000Z') },
    update: { engineFrom: new Date('2999-01-01T00:00:00.000Z') },
  });
}

/** D281: the smart engine from `day` (`YYYY-MM-DD`). */
export async function smartTargetsEngineFrom(prisma: PrismaService, day: string): Promise<void> {
  await prisma.hostTargetSettings.upsert({
    where: { id: 1 },
    create: { id: 1, engineFrom: new Date(`${day}T00:00:00.000Z`) },
    update: { engineFrom: new Date(`${day}T00:00:00.000Z`) },
  });
}
