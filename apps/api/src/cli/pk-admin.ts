/**
 * PK 1 v 1 moderation from the command line (v1.43-live, D195, CONVENTIONS §10.58). Runs as the
 * MIGRATION role (MIGRATION_DATABASE_URL), like `gift-admin`: on the server
 * `docker compose --profile jobs run --rm migrate node dist/cli/pk-admin.js …` (docs/DEPLOYMENT.md),
 * locally `pnpm pk:admin …`.
 *
 *   pnpm pk:admin list                              # matches in BATTLE or RESULT now
 *   pnpm pk:admin show <matchId>                    # one match (both sides, scores, boosters)
 *   pnpm pk:admin end <matchId> --reason <text>     # a moderator ends it (audited)
 *
 * `end`: a running battle becomes void (`endReason` ADMIN, no winner, not counted in any record) and
 * is closed at once; a match in its result phase is closed (its result stands). The reason (1–200
 * characters) is stored with the match and in the audit row `live.pk.admin_end`, written in the same
 * transaction. The API's PK tick tells both rooms within a second (`pending_notice`). An unknown or
 * already closed match exits 1.
 */
import 'dotenv/config';
import { parseArgs } from 'node:util';
import { PrismaPg } from '@prisma/adapter-pg';
import { PrismaClient } from '../generated/prisma/client.js';
import { AuditAction } from '../common/audit/audit.service.js';
import { adminEndPkIn } from '../modules/live/live-pk.js';

function fail(message: string): never {
  process.stderr.write(`${message}\n`);
  process.exit(1);
}

const USAGE = [
  'Usage: pnpm pk:admin list',
  '       pnpm pk:admin show <matchId>',
  '       pnpm pk:admin end <matchId> --reason <text>',
].join('\n');

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

const url = process.env.MIGRATION_DATABASE_URL;
if (!url) fail('MIGRATION_DATABASE_URL is not set (the migration role moderates PK matches).');
const prisma = new PrismaClient({ adapter: new PrismaPg({ connectionString: url, max: 1 }) });

function matchId(raw: string | undefined): string {
  if (raw === undefined || !UUID.test(raw)) fail(`A match id is a UUID.\n${USAGE}`);
  return raw.toLowerCase();
}

async function usernames(ids: readonly string[]): Promise<Map<string, string>> {
  const rows = await prisma.userProfile.findMany({
    where: { userId: { in: [...ids] } },
    select: { userId: true, username: true },
  });
  return new Map(rows.map((r) => [r.userId, r.username]));
}

async function list(): Promise<void> {
  const rows = await prisma.pkMatch.findMany({
    where: { status: { not: 'CLOSED' } },
    orderBy: { startedAt: 'asc' },
  });
  if (rows.length === 0) {
    process.stdout.write('No PK running.\n');
    return;
  }
  const names = await usernames(rows.flatMap((r) => [r.hostAId, r.hostBId]));
  for (const r of rows) {
    process.stdout.write(
      `${r.id} ${r.status} ${r.source} @${names.get(r.hostAId) ?? '?'} ${String(r.scoreA)} – ` +
        `${String(r.scoreB)} @${names.get(r.hostBId) ?? '?'} started=${r.startedAt.toISOString()} ` +
        `battleEnds=${r.battleEndsAt.toISOString()}\n`,
    );
  }
}

async function show(id: string): Promise<void> {
  const r = await prisma.pkMatch.findUnique({
    where: { id },
    include: { boosts: { orderBy: { startsAt: 'asc' } } },
  });
  if (!r) fail(`No PK match ${id}.`);
  const names = await usernames([r.hostAId, r.hostBId]);
  process.stdout.write(
    `${r.id} ${r.status} ${r.source} reason=${r.endReason ?? '-'} winner=${r.winner ?? '-'}\n` +
      `  A @${names.get(r.hostAId) ?? '?'} room=${r.roomAId} score=${String(r.scoreA)}\n` +
      `  B @${names.get(r.hostBId) ?? '?'} room=${r.roomBId} score=${String(r.scoreB)}\n` +
      `  started=${r.startedAt.toISOString()} battleEnds=${r.battleEndsAt.toISOString()} ` +
      `ended=${r.endedAt?.toISOString() ?? '-'} closed=${r.closedAt?.toISOString() ?? '-'}` +
      (r.adminReason ? ` admin="${r.adminReason}"` : '') +
      '\n',
  );
  for (const b of r.boosts) {
    process.stdout.write(
      `  boost ${b.side} ${b.kind} ×${String(b.multiplier)} ${b.startsAt.toISOString()}–${b.endsAt.toISOString()}` +
        `${b.replaced ? ' (replaced)' : ''}\n`,
    );
  }
}

async function end(id: string, args: readonly string[]): Promise<void> {
  let values: { reason?: string };
  try {
    ({ values } = parseArgs({
      args: [...args],
      options: { reason: { type: 'string' } },
      strict: true,
      allowPositionals: false,
    }));
  } catch (err) {
    fail(`${err instanceof Error ? err.message : String(err)}\n${USAGE}`);
  }
  const reason = values.reason?.trim() ?? '';
  if (reason.length === 0 || reason.length > 200) fail(`--reason is 1–200 characters.\n${USAGE}`);
  const before = await prisma.$transaction(async (tx) => {
    const status = await adminEndPkIn(tx, id, reason, new Date());
    if (status === null) return null;
    await tx.auditLog.create({
      data: {
        action: AuditAction.LIVE_PK_ADMIN_END,
        targetType: 'pk_match',
        targetId: id,
        metadata: { reason, previousStatus: status, via: 'cli' },
      },
    });
    return status;
  });
  if (before === null) fail(`No running PK match ${id}.`);
  process.stdout.write(
    before === 'BATTLE' || before === 'CONNECTED'
      ? `${id}: ended by a moderator (void, not counted).\n`
      : `${id}: result phase closed by a moderator (result kept).\n`,
  );
}

const [command, first, ...rest] = process.argv.slice(2);
try {
  switch (command) {
    case 'list':
      if (first !== undefined) fail(USAGE);
      await list();
      break;
    case 'show':
      if (rest.length > 0) fail(USAGE);
      await show(matchId(first));
      break;
    case 'end':
      await end(matchId(first), rest);
      break;
    default:
      fail(command ? `Unknown command ${command}.\n${USAGE}` : USAGE);
  }
} finally {
  await prisma.$disconnect();
}
