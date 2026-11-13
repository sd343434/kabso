/**
 * Medals administration from the command line (CP-018, D106, CONVENTIONS §10.21). Runs as the
 * MIGRATION role (MIGRATION_DATABASE_URL), like `wallet-admin`: built into the API image and run
 * on the server with `docker compose --profile jobs run --rm migrate node dist/cli/medals-admin.js …`
 * (docs/DEPLOYMENT.md), locally with `pnpm medals:admin …`.
 *
 *   pnpm medals:admin backfill            # awards every medal earned by past events and raises levels
 *   pnpm medals:admin backfill --notify   # … and sends a MEDAL_AWARDED notification for each change
 *
 * Idempotent: a medal is awarded once per user and a level never goes down, so running it again changes nothing.
 * v1.81-live (D291): it also raises each holder's level to what their current totals reach — run it once after the
 * `20270325090000_medal_levels` migration (every medal held before is level 1 until then) and after the panel lowers a
 * threshold. Writes one audit_logs row (`medals.backfill`) with the counts, plus `medals.level_up` per level above 1.
 */
import 'dotenv/config';
import { PrismaPg } from '@prisma/adapter-pg';
import { PrismaClient } from '../generated/prisma/client.js';
import { AuditAction } from '../common/audit/audit.service.js';
import { backfillMedals } from '../modules/medals/medal-awards.js';

function fail(message: string): never {
  process.stderr.write(`${message}\n`);
  process.exit(1);
}

const url = process.env.MIGRATION_DATABASE_URL;
if (!url) fail('MIGRATION_DATABASE_URL is not set (the migration role runs the backfill).');
const prisma = new PrismaClient({ adapter: new PrismaPg({ connectionString: url, max: 1 }) });

const [command, ...flags] = process.argv.slice(2);
try {
  if (command !== 'backfill') fail('Usage: pnpm medals:admin backfill [--notify]');
  const unknown = flags.filter((f) => f !== '--notify');
  if (unknown.length > 0) fail(`Unknown option ${unknown[0]!}.`);
  const notify = flags.includes('--notify');
  const { awarded, levelUps } = await backfillMedals(prisma, { notify });
  await prisma.auditLog.create({
    data: {
      action: AuditAction.MEDALS_BACKFILL,
      targetType: 'medals',
      metadata: { awarded, levelUps, notify, via: 'cli' },
    },
  });
  const total = Object.values(awarded).reduce((a, b) => a + (b ?? 0), 0);
  const parts = Object.entries(awarded).map(([code, n]) => `${code} ${String(n)}`);
  const ups = Object.values(levelUps).reduce((a, b) => a + (b ?? 0), 0);
  const upParts = Object.entries(levelUps).map(([code, n]) => `${code} ${String(n)}`);
  process.stdout.write(`Awarded ${String(total)} medals${parts.length ? ` (${parts.join(', ')})` : ''}.\n`);
  process.stdout.write(
    `Raised ${String(ups)} medal levels${upParts.length ? ` (${upParts.join(', ')})` : ''}.\n`,
  );
} finally {
  await prisma.$disconnect();
}
