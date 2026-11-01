/**
 * The account controls «تحكم كامل» from the command line (v1.72-social, D208, CONVENTIONS §10.67): the same rules
 * as the admin panel's user page (`account-control`), for the team on the server. Runs as the MIGRATION role
 * (MIGRATION_DATABASE_URL), like `account-admin`: built into the API image and run on the server with
 * `docker compose --profile jobs run --rm migrate node dist/cli/control-admin.js …` (docs/DEPLOYMENT.md), locally
 * with `pnpm control:admin …`.
 *
 *   pnpm control:admin state <user>                                    locks, restrictions, the forced change
 *   pnpm control:admin lock <user> (--days <n> | --until <ISO>) --reason <text>
 *   pnpm control:admin unlock <user> --reason <text>
 *   pnpm control:admin restrict <user> <CHAT_MUTE|NO_LIVE|NO_GIFTS|NO_POSTING> (--days <n> | --until <ISO>) --reason <text>
 *   pnpm control:admin lift <user> <CHAT_MUTE|NO_LIVE|NO_GIFTS|NO_POSTING> --reason <text>
 *   pnpm control:admin require-password-change <user> --reason <text> [--keep-sessions]
 *   pnpm control:admin adjust <user> <coins|cherries> <+n|-n> --reason <text> [--allow-negative]
 *
 * `<user>` is a username (shown or base), an email or a user id. Every change writes its audit row (`via: cli`,
 * no actor) with the reason, the user's notification where the panel sends one, and — for a lock — ends every
 * session (a live the person hosts ends by the room sweeper: no heartbeat any more). CLI adjustments have no daily
 * cap (the panel's cap is per admin). A temporary password and the reset link are panel-only (the reset link is
 * the app's own «نسيت كلمة المرور»). Exit 1 on an unknown user, a refusal or a missing reason.
 */
import { parseArgs } from 'node:util';
import { PrismaPg } from '@prisma/adapter-pg';
import { CLI_VIA } from '../common/audit/admin-actor.js';
import { PrismaClient } from '../generated/prisma/client.js';
import {
  AccountControlError,
  activeRestrictionsOf,
  adjustBalanceIn,
  liftIn,
  requirePasswordChangeIn,
  RESTRICTION_KINDS,
  restrictIn,
  restrictionEnd,
  type RestrictionKind,
} from '../modules/users/account-control.js';

function fail(message: string): never {
  process.stderr.write(`${message}\n`);
  process.exit(1);
}

const USAGE = [
  'Usage: pnpm control:admin state <user>',
  '       pnpm control:admin lock <user> (--days <n> | --until <ISO>) --reason <text>',
  '       pnpm control:admin unlock <user> --reason <text>',
  '       pnpm control:admin restrict <user> <CHAT_MUTE|NO_LIVE|NO_GIFTS|NO_POSTING> (--days <n> | --until <ISO>) --reason <text>',
  '       pnpm control:admin lift <user> <CHAT_MUTE|NO_LIVE|NO_GIFTS|NO_POSTING> --reason <text>',
  '       pnpm control:admin require-password-change <user> --reason <text> [--keep-sessions]',
  '       pnpm control:admin adjust <user> <coins|cherries> <+n|-n> --reason <text> [--allow-negative]',
].join('\n');

const url = process.env.MIGRATION_DATABASE_URL;
if (!url) fail('MIGRATION_DATABASE_URL is not set (the migration role changes accounts).');
const prisma = new PrismaClient({ adapter: new PrismaPg({ connectionString: url, max: 1 }) });

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

async function resolveUser(raw: string): Promise<{ id: string; label: string }> {
  const name = raw.trim().replace(/^@/, '').toLowerCase();
  const select = { id: true, status: true, profile: { select: { username: true } } } as const;
  const user = UUID.test(name)
    ? await prisma.user.findUnique({ where: { id: name }, select })
    : name.includes('@')
      ? await prisma.user.findUnique({ where: { email: name }, select })
      : ((await prisma.userProfile.findUnique({ where: { username: name }, select: { user: { select } } }))
          ?.user ??
        (
          await prisma.specialUsername.findFirst({
            where: { baseUsername: name, status: 'ACTIVE' },
            select: { user: { select } },
          })
        )?.user ??
        null);
  if (!user || user.status === 'DELETED') fail(`No account ${raw}.`);
  return { id: user.id, label: user.profile?.username ? `@${user.profile.username}` : user.id };
}

function kindOf(raw: string | undefined): RestrictionKind {
  const v = (raw ?? '').toUpperCase();
  if (!(RESTRICTION_KINDS as readonly string[]).includes(v))
    fail(`${USAGE}\nUnknown restriction ${raw ?? ''}.`);
  return v as RestrictionKind;
}

try {
  const { positionals, values } = parseArgs({
    args: process.argv.slice(2),
    allowPositionals: true,
    options: {
      reason: { type: 'string' },
      days: { type: 'string' },
      until: { type: 'string' },
      'keep-sessions': { type: 'boolean' },
      'allow-negative': { type: 'boolean' },
    },
  });
  const [command, who, a, b] = positionals;
  if (!command || !who) fail(USAGE);
  const reasonOf = (): string => {
    const reason = values.reason?.trim();
    if (!reason) fail(`${USAGE}\nA reason is required (it is kept in the audit log).`);
    if ([...reason].length > 500) fail('The reason is at most 500 characters.');
    return reason;
  };
  const endOf = (now: Date): Date => {
    if ((values.days === undefined) === (values.until === undefined))
      fail(`${USAGE}\nGive --days or --until.`);
    const days = values.days === undefined ? undefined : Number(values.days);
    if (days !== undefined && (!Number.isInteger(days) || days < 1))
      fail('--days must be a whole number ≥ 1.');
    return restrictionEnd(now, {
      days,
      until: values.until === undefined ? undefined : new Date(values.until),
    });
  };
  const user = await resolveUser(who);
  const now = new Date();
  if (command === 'state') {
    const active = await activeRestrictionsOf(prisma, user.id, now);
    const row = await prisma.user.findUniqueOrThrow({
      where: { id: user.id },
      select: { status: true, passwordChangeRequiredAt: true },
    });
    process.stdout.write(
      `${user.label} ${user.id} status=${row.status} password-change-required=${row.passwordChangeRequiredAt !== null}\n`,
    );
    if (active.length === 0) process.stdout.write('No active lock or restriction.\n');
    for (const r of active) {
      process.stdout.write(`${r.kind} until ${r.endsAt.toISOString()} via=${r.via} reason=${r.reason}\n`);
    }
  } else if (command === 'lock' || command === 'restrict') {
    const kind = command === 'lock' ? 'LOCK' : kindOf(a);
    const reason = reasonOf();
    const endsAt = endOf(now);
    const out = await prisma.$transaction((tx) =>
      restrictIn(tx, user.id, kind, endsAt, reason, CLI_VIA, now),
    );
    process.stdout.write(
      `${user.label}: ${kind} until ${endsAt.toISOString()}` +
        (kind === 'LOCK' ? ` (${out.sessions} session(s) ended)` : '') +
        (out.replaced ? ` — replaced the one until ${out.replaced.endsAt.toISOString()}` : '') +
        '\n',
    );
  } else if (command === 'unlock' || command === 'lift') {
    const kind = command === 'unlock' ? 'LOCK' : kindOf(a);
    const reason = reasonOf();
    await prisma.$transaction((tx) => liftIn(tx, user.id, kind, reason, CLI_VIA, now));
    process.stdout.write(`${user.label}: ${kind} lifted.\n`);
  } else if (command === 'require-password-change') {
    const reason = reasonOf();
    const out = await prisma.$transaction((tx) =>
      requirePasswordChangeIn(tx, user.id, reason, CLI_VIA, {
        endSessions: values['keep-sessions'] !== true,
      }),
    );
    process.stdout.write(
      `${user.label}: a new password is required at the next sign-in (${out.sessions} session(s) ended).\n`,
    );
  } else if (command === 'adjust') {
    const currency =
      (a ?? '').toLowerCase() === 'coins'
        ? 'COINS'
        : (a ?? '').toLowerCase() === 'cherries'
          ? 'CHERRIES'
          : null;
    if (!currency || !b || !/^[+-][1-9][0-9]{0,9}$/.test(b)) fail(USAGE);
    const reason = reasonOf();
    const out = await prisma.$transaction((tx) =>
      adjustBalanceIn(
        tx,
        {
          userId: user.id,
          currency,
          delta: BigInt(b),
          allowNegative: values['allow-negative'] === true,
          reason,
          dailyCap: null,
          zone: 'UTC',
        },
        CLI_VIA,
        now,
      ),
    );
    process.stdout.write(
      `${user.label}: ${currency.toLowerCase()} ${out.before.toString()} → ${out.after.toString()} (adjustment ${out.adjustmentId}).\n`,
    );
  } else {
    fail(USAGE);
  }
} catch (err) {
  if (err instanceof AccountControlError) fail(err.message);
  if (err instanceof TypeError) fail(`${err.message}\n${USAGE}`);
  throw err;
} finally {
  await prisma.$disconnect();
}
