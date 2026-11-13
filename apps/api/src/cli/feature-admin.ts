/**
 * Featured hosts of the live hub from the command line (v1.27.1-live, D133, CONVENTIONS §10.28).
 * `GET /live/rooms?featured=true` lists the LIVE rooms of these hosts, by rank (lower first), then
 * like `popular`. There is no admin UI or API. Runs as the MIGRATION role (MIGRATION_DATABASE_URL),
 * like `gift-admin` and `banner-admin`: on the server
 * `docker compose --profile jobs run --rm migrate node dist/cli/feature-admin.js …`
 * (docs/DEPLOYMENT.md), locally `pnpm feature:admin …`.
 *
 *   pnpm feature:admin add --user <email|username> [--rank <0-1000000>] [--until <ISO time>|none]
 *                         # features the host, or changes the rank / end of a featured host
 *   pnpm feature:admin remove --user <email|username>
 *   pnpm feature:admin list            # every featured host, expired ones marked `-`
 *
 * `--rank` defaults to 100 for a new row (an existing row keeps its rank unless given); `--until`
 * is an ISO 8601 time with a zone (`2026-11-01T00:00:00Z`) after which the row no longer counts,
 * `none` removes the end. Every change writes an audit_logs row in the same transaction
 * (`live.feature.add` with before and after, `live.feature.remove`). A command that changes nothing
 * exits 0 and says so; a bad argument or an unknown user exits 1.
 */
import 'dotenv/config';
import { parseArgs } from 'node:util';
import { PrismaPg } from '@prisma/adapter-pg';
import { PrismaClient } from '../generated/prisma/client.js';
import { AuditAction } from '../common/audit/audit.service.js';

function fail(message: string): never {
  process.stderr.write(`${message}\n`);
  process.exit(1);
}

const USAGE = [
  'Usage: pnpm feature:admin add --user <email|username> [--rank <0-1000000>] [--until <ISO time>|none]',
  '       pnpm feature:admin remove --user <email|username>',
  '       pnpm feature:admin list',
].join('\n');

/** `live_featured_hosts_rank_range`. */
const RANK_MAX = 1_000_000;
const DEFAULT_RANK = 100;

const url = process.env.MIGRATION_DATABASE_URL;
if (!url) fail('MIGRATION_DATABASE_URL is not set (the migration role changes featured hosts).');
const prisma = new PrismaClient({ adapter: new PrismaPg({ connectionString: url, max: 1 }) });

function options(args: readonly string[], allowed: readonly string[]): Record<string, string | undefined> {
  let values: Record<string, string | undefined>;
  try {
    ({ values } = parseArgs({
      args: [...args],
      options: { user: { type: 'string' }, rank: { type: 'string' }, until: { type: 'string' } },
      strict: true,
      allowPositionals: false,
    }));
  } catch (err) {
    fail(`${err instanceof Error ? err.message : String(err)}\n${USAGE}`);
  }
  for (const key of Object.keys(values)) {
    if (!allowed.includes(key)) fail(`--${key} is not an option of this command.\n${USAGE}`);
  }
  if (!values.user) fail(`--user is required.\n${USAGE}`);
  return values;
}

/** The user named by an email (with `@`) or a username; never a deleted account. */
async function userOf(name: string): Promise<{ id: string; username: string }> {
  const raw = name.trim();
  // `name@host` is an email; `@name` or `name` a username.
  const row =
    raw.indexOf('@') > 0
      ? await prisma.user.findUnique({
          where: { email: raw.toLowerCase() },
          select: { id: true, deletedAt: true, profile: { select: { username: true } } },
        })
      : await prisma.user.findFirst({
          where: { profile: { username: raw.toLowerCase().replace(/^@/, '') } },
          select: { id: true, deletedAt: true, profile: { select: { username: true } } },
        });
  if (!row || row.deletedAt !== null || !row.profile) fail(`No user ${name}.`);
  return { id: row.id, username: row.profile.username };
}

function rankOf(raw: string): number {
  if (!/^(0|[1-9][0-9]{0,6})$/.test(raw) || Number(raw) > RANK_MAX) {
    fail(`The rank must be a whole number from 0 to ${String(RANK_MAX)}.`);
  }
  return Number(raw);
}

function untilOf(raw: string): Date | null {
  if (raw === 'none') return null;
  // A full ISO 8601 date-time with a zone, so the end never depends on the server's time zone.
  if (!/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(:\d{2}(\.\d{1,3})?)?(Z|[+-]\d{2}:\d{2})$/.test(raw)) {
    fail('--until is an ISO time with a zone, e.g. 2026-11-01T00:00:00Z, or none.');
  }
  const at = new Date(raw);
  if (Number.isNaN(at.getTime())) fail('--until is not a valid time.');
  return at;
}

function describe(
  row: { rank: number; until: Date | null } | null,
): { rank: number; until: string | null } | null {
  return row === null ? null : { rank: row.rank, until: row.until?.toISOString() ?? null };
}

async function add(args: readonly string[]): Promise<void> {
  const values = options(args, ['user', 'rank', 'until']);
  const user = await userOf(values.user!);
  const rank = values.rank === undefined ? undefined : rankOf(values.rank);
  const until = values.until === undefined ? undefined : untilOf(values.until);
  const outcome = await prisma.$transaction(async (tx) => {
    const before = await tx.liveFeaturedHost.findUnique({ where: { userId: user.id } });
    const next = {
      rank: rank ?? before?.rank ?? DEFAULT_RANK,
      until: until === undefined ? (before?.until ?? null) : until,
    };
    if (
      before &&
      before.rank === next.rank &&
      (before.until?.getTime() ?? null) === (next.until?.getTime() ?? null)
    ) {
      return 'unchanged' as const;
    }
    await tx.liveFeaturedHost.upsert({
      where: { userId: user.id },
      create: { userId: user.id, rank: next.rank, until: next.until },
      update: { rank: next.rank, until: next.until, updatedAt: new Date() },
    });
    await tx.auditLog.create({
      data: {
        action: AuditAction.LIVE_FEATURE_ADD,
        targetType: 'user',
        targetId: user.id,
        metadata: { before: describe(before), after: describe(next), via: 'cli' },
      },
    });
    return next;
  });
  if (outcome === 'unchanged') {
    process.stdout.write(`@${user.username} is already featured like that; nothing changed.\n`);
    return;
  }
  process.stdout.write(
    `+@${user.username} featured (rank ${String(outcome.rank)}, until ${outcome.until?.toISOString() ?? 'none'}).\n`,
  );
}

async function remove(args: readonly string[]): Promise<void> {
  const values = options(args, ['user']);
  const user = await userOf(values.user!);
  const removed = await prisma.$transaction(async (tx) => {
    const before = await tx.liveFeaturedHost.findUnique({ where: { userId: user.id } });
    if (!before) return false;
    await tx.liveFeaturedHost.delete({ where: { userId: user.id } });
    await tx.auditLog.create({
      data: {
        action: AuditAction.LIVE_FEATURE_REMOVE,
        targetType: 'user',
        targetId: user.id,
        metadata: { before: describe(before), via: 'cli' },
      },
    });
    return true;
  });
  process.stdout.write(
    removed
      ? `-@${user.username} is no longer featured.\n`
      : `@${user.username} is not featured; nothing changed.\n`,
  );
}

async function list(): Promise<void> {
  const rows = await prisma.liveFeaturedHost.findMany({
    orderBy: [{ rank: 'asc' }, { userId: 'asc' }],
    include: { user: { select: { profile: { select: { username: true } } } } },
  });
  if (rows.length === 0) {
    process.stdout.write('No featured hosts.\n');
    return;
  }
  const now = Date.now();
  for (const r of rows) {
    const live = r.until === null || r.until.getTime() > now;
    process.stdout.write(
      `${live ? ' ' : '-'} ${String(r.rank)} @${r.user.profile?.username ?? '?'} until=${r.until?.toISOString() ?? 'none'}\n`,
    );
  }
}

const [command, ...rest] = process.argv.slice(2);
try {
  switch (command) {
    case 'add':
      await add(rest);
      break;
    case 'remove':
      await remove(rest);
      break;
    case 'list':
      if (rest.length > 0) fail(USAGE);
      await list();
      break;
    default:
      fail(command ? `Unknown command ${command}.\n${USAGE}` : USAGE);
  }
} finally {
  await prisma.$disconnect();
}
