/**
 * Special usernames «يوزر مميز» from the command line (v1.54-social, D185, CONVENTIONS §10.48.1). The team gives
 * a person a special username (`ADMIN_GIFT`, for N days or permanently), takes it back, or shows a person's
 * names — the base username is visible only here and to the person themself. Recharge agents get theirs
 * (`coin0001` …) from `recharge-admin topup`, not here. Runs as the MIGRATION role (MIGRATION_DATABASE_URL):
 * on the server `docker compose --profile jobs run --rm migrate node dist/cli/username-admin.js …`, locally
 * `pnpm username:admin …`.
 *
 *   pnpm username:admin gift <user> <special> (--days <N> | --permanent) --reason <text>
 *   pnpm username:admin revoke <user> --reason <text>
 *   pnpm username:admin show <user>                       # audited
 *   pnpm username:admin sweep                             # the sweeper's step now
 *
 * `<user>` is an email, the username shown now or the person's base username. Every action writes an audit row
 * in its transaction; a bad argument or a refused action exits 1 (nothing changed).
 */
import 'dotenv/config';
import { parseArgs } from 'node:util';
import { PrismaPg } from '@prisma/adapter-pg';
import { AuditAction } from '../common/audit/audit.service.js';
import { envSchema } from '../config/env.schema.js';
import { PrismaClient } from '../generated/prisma/client.js';
import {
  endSpecialIn,
  grantSpecialIn,
  resolveUserIdByUsername,
  SpecialUsernameError,
  sweepSpecialUsernames,
} from '../modules/users/special-usernames.js';
import { normalizeUsername } from '../modules/users/username.js';

function fail(message: string): never {
  process.stderr.write(`${message}\n`);
  process.exit(1);
}

const USAGE = [
  'Usage: pnpm username:admin gift <user> <special> (--days <N> | --permanent) --reason <text>',
  '       pnpm username:admin revoke <user> --reason <text>',
  '       pnpm username:admin show <user> | sweep',
].join('\n');

const url = process.env.MIGRATION_DATABASE_URL;
if (!url) fail('MIGRATION_DATABASE_URL is not set.');
const prisma = new PrismaClient({ adapter: new PrismaPg({ connectionString: url, max: 1 }) });

function graceDays(): number {
  const parsed = envSchema.shape.SPECIAL_USERNAME_GRACE_DAYS.safeParse(
    process.env.SPECIAL_USERNAME_GRACE_DAYS,
  );
  if (!parsed.success) fail('SPECIAL_USERNAME_GRACE_DAYS is invalid.');
  return parsed.data;
}

function text(raw: string | undefined, what: string): string {
  const value = (raw ?? '').trim();
  if (value === '') fail(`${what} is required.`);
  if ([...value].length > 500) fail(`${what} is at most 500 characters.`);
  return value;
}

/** A user by email, shown username or base username → id. */
async function userId(raw: string | undefined): Promise<string> {
  if (!raw) fail(USAGE);
  const value = normalizeUsername(raw).replace(/^@/, '');
  const id = value.includes('@')
    ? ((await prisma.user.findUnique({ where: { email: value }, select: { id: true } }))?.id ?? null)
    : await resolveUserIdByUsername(prisma, value);
  if (id === null) fail(`No user ${raw}.`);
  return id;
}

async function run<T>(fn: () => Promise<T>): Promise<T> {
  try {
    return await fn();
  } catch (err) {
    if (err instanceof SpecialUsernameError) fail(err.message);
    throw err;
  }
}

const { positionals, values } = parseArgs({
  allowPositionals: true,
  options: {
    days: { type: 'string' },
    permanent: { type: 'boolean' },
    reason: { type: 'string' },
  },
});
const [command, a, b] = positionals;
const now = new Date();

try {
  switch (command) {
    case 'gift': {
      const user = await userId(a);
      const name = normalizeUsername(b ?? '').replace(/^@/, '');
      if (name === '') fail(USAGE);
      const reason = text(values.reason, '--reason');
      if ((values.days === undefined) === (values.permanent !== true))
        fail('Pass exactly one of --days <N> or --permanent.');
      let expiresAt: Date | null = null;
      if (values.days !== undefined) {
        if (!/^[0-9]{1,4}$/.test(values.days) || Number(values.days) < 1) fail('--days is 1 … 9999.');
        expiresAt = new Date(now.getTime() + Number(values.days) * 86_400_000);
      }
      const row = await run(() =>
        prisma.$transaction((tx) =>
          grantSpecialIn(
            tx,
            user,
            name,
            { source: 'ADMIN_GIFT', expiresAt, reason, via: 'cli' },
            now,
            graceDays(),
          ),
        ),
      );
      process.stdout.write(
        `@${row.username} given (base @${row.baseUsername}), ${
          row.expiresAt ? `until ${row.expiresAt.toISOString()}` : 'permanent'
        }.\n`,
      );
      break;
    }
    case 'revoke': {
      const user = await userId(a);
      const reason = text(values.reason, '--reason');
      const ended = await prisma.$transaction((tx) =>
        endSpecialIn(tx, user, 'REVOKED', now, graceDays(), { via: 'cli', note: reason }),
      );
      if (!ended) fail('The user has no active special username.');
      process.stdout.write(
        'Revoked: the own username is shown again; the special one stays reserved for them.\n',
      );
      break;
    }
    case 'show': {
      const user = await userId(a);
      const [profile, rows] = await prisma.$transaction(async (tx) => {
        await tx.auditLog.create({
          data: {
            action: AuditAction.SPECIAL_USERNAME_VIEW,
            targetType: 'user',
            targetId: user,
            metadata: { via: 'cli' },
          },
        });
        return Promise.all([
          tx.userProfile.findUnique({ where: { userId: user }, select: { username: true } }),
          tx.specialUsername.findMany({ where: { userId: user }, orderBy: { grantedAt: 'desc' }, take: 50 }),
        ]);
      });
      process.stdout.write(`Shown: @${profile?.username ?? '?'}\n`);
      for (const r of rows) {
        process.stdout.write(
          `${r.status.padEnd(6)} @${r.username} (base @${r.baseUsername}) ${r.source} granted ${r.grantedAt.toISOString()} ` +
            `expires ${r.expiresAt?.toISOString() ?? 'never'}${r.status === 'GRACE' ? ` held until ${r.graceUntil?.toISOString() ?? 'forever'}` : ''}` +
            `${r.endReason ? ` ended ${r.endReason}` : ''}\n`,
        );
      }
      if (rows.length === 0) process.stdout.write('No special usernames.\n');
      break;
    }
    case 'sweep': {
      const n = await sweepSpecialUsernames(prisma, now, graceDays());
      process.stdout.write(`Swept ${String(n)} row(s).\n`);
      break;
    }
    default:
      fail(USAGE);
  }
} finally {
  await prisma.$disconnect();
}
