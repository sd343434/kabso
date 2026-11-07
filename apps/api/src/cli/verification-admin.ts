/**
 * Verification badges «شارة التوثيق» from the command line (v1.90-social, D293, CONVENTIONS §10.105). Runs as the
 * MIGRATION role (MIGRATION_DATABASE_URL), like `medals-admin`: built into the API image and run on the server with
 * `docker compose --profile jobs run --rm migrate node dist/cli/verification-admin.js recompute` (docs/DEPLOYMENT.md
 * §5.73), locally with `pnpm verification:admin recompute`.
 *
 *   pnpm verification:admin recompute     # recomputes every badge now (the first-run backfill)
 *
 * Idempotent: it writes only the differences (each audited `verification.badge.change`, cause `backfill`), then one
 * `verification.recompute` row with the counts. The API's sweeper does the same every
 * `VERIFICATION_BADGE_SWEEP_INTERVAL_SECONDS`.
 */
import 'dotenv/config';
import { PrismaPg } from '@prisma/adapter-pg';
import { PrismaClient } from '../generated/prisma/client.js';
import { AuditAction } from '../common/audit/audit.service.js';
import { recomputeAllBadges } from '../modules/verification/verification-badges.js';

function fail(message: string): never {
  process.stderr.write(`${message}\n`);
  process.exit(1);
}

const url = process.env.MIGRATION_DATABASE_URL;
if (!url) fail('MIGRATION_DATABASE_URL is not set (the migration role runs the recompute).');
const prisma = new PrismaClient({ adapter: new PrismaPg({ connectionString: url, max: 1 }) });

const [command, ...flags] = process.argv.slice(2);
try {
  if (command !== 'recompute' || flags.length > 0) fail('Usage: pnpm verification:admin recompute');
  const result = await recomputeAllBadges(prisma, 'backfill');
  await prisma.auditLog.create({
    data: {
      action: AuditAction.VERIFICATION_RECOMPUTE,
      targetType: 'verification_badge_settings',
      targetId: '1',
      metadata: { ...result, via: 'cli' },
    },
  });
  process.stdout.write(
    `Verification badges: ${String(result.granted)} granted, ${String(result.changed)} changed, ` +
      `${String(result.removed)} removed, ${String(result.kept)} kept.\n`,
  );
} finally {
  await prisma.$disconnect();
}
