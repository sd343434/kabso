/**
 * Medals administration from the command line (CP-018, D106, CONVENTIONS §10.21). Runs as the
 * MIGRATION role (MIGRATION_DATABASE_URL), like `wallet-admin`: built into the API image and run
 * on the server with `docker compose --profile jobs run --rm migrate node dist/cli/medals-admin.js …`
 * (docs/DEPLOYMENT.md), locally with `pnpm medals:admin …`.
 *
 *   pnpm medals:admin backfill            # awards every medal earned by past events
 *   pnpm medals:admin backfill --notify   # … and sends a MEDAL_AWARDED notification for each
 *
 * Idempotent: a medal is awarded once per user, so running it again awards nothing new. Writes one
 * audit_logs row (`medals.backfill`) with the counts.
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
  const { awarded } = await backfillMedals(prisma, { notify });
  await prisma.auditLog.create({
    data: {
      action: AuditAction.MEDALS_BACKFILL,
      targetType: 'medals',
      metadata: { awarded, notify, via: 'cli' },
    },
  });
  const total = Object.values(awarded).reduce((a, b) => a + (b ?? 0), 0);
  const parts = Object.entries(awarded).map(([code, n]) => `${code} ${String(n)}`);
  process.stdout.write(`Awarded ${String(total)} medals${parts.length ? ` (${parts.join(', ')})` : ''}.\n`);
} finally {
  await prisma.$disconnect();
}
