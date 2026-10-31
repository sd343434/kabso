/**
 * Account deletion from the command line (v1.62-social, D193, CONVENTIONS §10.56). The person deletes their own
 * account in the app («حذف الحساب»); this is the team's tool for the rest: a deletion asked for without the app
 * (an email to the support address, after the team has verified that the sender owns the account), a cancellation
 * on request, and an immediate purge (a legal request, or a test account). Runs as the MIGRATION role
 * (MIGRATION_DATABASE_URL), like `profile-admin`: built into the API image and run on the server with
 * `docker compose --profile jobs run --rm -e S3_ENDPOINT -e S3_REGION -e S3_BUCKET -e S3_ACCESS_KEY_ID
 *  -e S3_SECRET_ACCESS_KEY -e S3_FORCE_PATH_STYLE migrate node dist/cli/account-admin.js …` (docs/DEPLOYMENT.md),
 * locally with `pnpm account:admin …`.
 *
 *   pnpm account:admin pending [<user>]                  the accounts in their grace period (or one account's state)
 *   pnpm account:admin request <user> --reason <text>    starts the grace period, as the in-app request does
 *   pnpm account:admin cancel <user> --reason <text>     ends the grace period: the account is back as it was
 *   pnpm account:admin purge-now <user> --reason <text>  deletes for good now (no grace period)
 *
 * `<user>` is a username (the one shown, or the person's own base username), an email or a user id. `request` and
 * `purge-now` refuse while something must be settled first (a recharge agent, a host agency, a pending withdrawal or
 * cherry sale, a negative balance: the blockers are printed). Every change is audited with the reason
 * (`account.deletion.requested` / `cancelled` / `purged`, `via: cli`). After a purge the files are deleted from
 * object storage (needs the `S3_*` settings; without them the keys are printed for manual deletion). Exit 1 on an
 * unknown user, a refusal or a missing reason.
 */
import 'dotenv/config';
import { parseArgs } from 'node:util';
import { PrismaPg } from '@prisma/adapter-pg';
import { PrismaClient } from '../generated/prisma/client.js';
import type { AppConfig } from '../config/app-config.js';
import type { ObjectStorage } from '../modules/media/object-storage.js';
import { S3ObjectStorage } from '../modules/media/s3-object-storage.js';
import {
  cancelDeletionIn,
  deletionBlockersIn,
  purgeAccountIn,
  requestDeletionIn,
} from '../modules/users/account-deletion.js';

function fail(message: string): never {
  process.stderr.write(`${message}\n`);
  process.exit(1);
}

const USAGE =
  'Usage: pnpm account:admin pending [<user>]\n' +
  '       pnpm account:admin request|cancel|purge-now <user> --reason <text>';

const url = process.env.MIGRATION_DATABASE_URL;
if (!url) fail('MIGRATION_DATABASE_URL is not set (the migration role changes accounts).');
const prisma = new PrismaClient({ adapter: new PrismaPg({ connectionString: url, max: 1 }) });

function intEnv(name: string, fallback: number): number {
  const raw = process.env[name];
  const n = raw === undefined || raw === '' ? fallback : Number(raw);
  if (!Number.isInteger(n) || n < 0) fail(`${name} must be a whole number of days.`);
  return n;
}
const GRACE_DAYS = intEnv('ACCOUNT_DELETION_GRACE_DAYS', 30);
const QUARANTINE_DAYS = intEnv('ACCOUNT_DELETION_USERNAME_QUARANTINE_DAYS', 90);
const SPECIAL_GRACE_DAYS = intEnv('SPECIAL_USERNAME_GRACE_DAYS', 30);

/** Object storage from the API's own settings, or null when they are not all set. */
function storageFromEnv(): ObjectStorage | null {
  const e = process.env;
  if (!e.S3_BUCKET || !e.S3_ACCESS_KEY_ID || !e.S3_SECRET_ACCESS_KEY) return null;
  const media = {
    s3: {
      endpoint: e.S3_ENDPOINT || undefined,
      region: e.S3_REGION || 'auto',
      bucket: e.S3_BUCKET,
      accessKeyId: e.S3_ACCESS_KEY_ID,
      secretAccessKey: e.S3_SECRET_ACCESS_KEY,
      forcePathStyle: e.S3_FORCE_PATH_STYLE === 'true',
    },
  };
  return new S3ObjectStorage({ media } as unknown as AppConfig);
}

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/** The account named by a username (shown or base), an email or an id; fails when unknown. */
async function resolveUser(raw: string): Promise<{ id: string; status: string; username: string | null }> {
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
  if (!user) fail(`No account ${raw}.`);
  return { id: user.id, status: user.status, username: user.profile?.username ?? null };
}

const label = (u: { id: string; username: string | null }) => (u.username ? `@${u.username}` : u.id);

async function pending(raw: string | undefined): Promise<void> {
  if (raw !== undefined) {
    const user = await resolveUser(raw);
    const request = await prisma.accountDeletionRequest.findFirst({
      where: { userId: user.id },
      orderBy: { requestedAt: 'desc' },
    });
    process.stdout.write(
      `${label(user)} ${user.id} status=${user.status}` +
        (request
          ? ` last-request=${request.status} via=${request.requestedVia} requested=${request.requestedAt.toISOString()}` +
            ` purge-after=${request.purgeAfter.toISOString()}`
          : ' (no deletion request)') +
        '\n',
    );
    const blockers = await deletionBlockersIn(prisma, user.id);
    if (blockers.length > 0) process.stdout.write(`blockers: ${blockers.join(', ')}\n`);
    return;
  }
  const rows = await prisma.accountDeletionRequest.findMany({
    where: { status: 'PENDING' },
    orderBy: [{ purgeAfter: 'asc' }, { id: 'asc' }],
    select: {
      userId: true,
      requestedVia: true,
      requestedAt: true,
      purgeAfter: true,
      user: { select: { profile: { select: { username: true } } } },
    },
    take: 500,
  });
  if (rows.length === 0) {
    process.stdout.write('No account is waiting for deletion.\n');
    return;
  }
  for (const r of rows) {
    process.stdout.write(
      `${label({ id: r.userId, username: r.user.profile?.username ?? null })} ${r.userId} via=${r.requestedVia}` +
        ` requested=${r.requestedAt.toISOString()} purge-after=${r.purgeAfter.toISOString()}\n`,
    );
  }
}

async function request(raw: string, reason: string): Promise<void> {
  const user = await resolveUser(raw);
  const outcome = await prisma.$transaction((tx) =>
    requestDeletionIn(tx, user.id, new Date(), GRACE_DAYS, { via: 'ADMIN', reason }),
  );
  if (outcome.outcome === 'not_active')
    fail(`${label(user)} is ${user.status}; only an ACTIVE account can start a deletion (see purge-now).`);
  if (outcome.outcome === 'blocked')
    fail(`${label(user)} cannot be deleted yet; settle first: ${outcome.blockers.join(', ')}.`);
  if (outcome.outcome === 'already_pending') {
    process.stdout.write(
      `${label(user)} is already waiting for deletion (purge after ${outcome.request.purgeAfter.toISOString()}).\n`,
    );
    return;
  }
  process.stdout.write(
    `${label(user)}: deletion requested; signed out of ${outcome.revokedSessions} session(s); purged after ` +
      `${outcome.request.purgeAfter.toISOString()} unless cancelled. Tell the person by email.\n`,
  );
}

async function cancel(raw: string, reason: string): Promise<void> {
  const user = await resolveUser(raw);
  const done = await prisma.$transaction((tx) =>
    cancelDeletionIn(tx, user.id, new Date(), { via: 'ADMIN', reason }),
  );
  if (!done) fail(`${label(user)} is ${user.status}, not waiting for deletion; nothing changed.`);
  process.stdout.write(`${label(user)}: deletion cancelled; the account is ACTIVE again.\n`);
}

async function purgeNow(raw: string, reason: string): Promise<void> {
  const user = await resolveUser(raw);
  if (user.status === 'DELETED') {
    process.stdout.write(`${label(user)} is already deleted; nothing changed.\n`);
    return;
  }
  const blockers = await deletionBlockersIn(prisma, user.id);
  if (blockers.length > 0)
    fail(`${label(user)} cannot be deleted yet; settle first: ${blockers.join(', ')}.`);
  const result = await prisma.$transaction(
    (tx) =>
      purgeAccountIn(tx, user.id, new Date(), {
        quarantineDays: QUARANTINE_DAYS,
        specialGraceDays: SPECIAL_GRACE_DAYS,
        via: 'ADMIN',
        reason,
      }),
    { timeout: 60_000 },
  );
  if (!result) {
    process.stdout.write(`${label(user)} is already deleted; nothing changed.\n`);
    return;
  }
  const head = `${label(user)}: deleted (tombstone @${result.tombstoneUsername}).`;
  if (result.objectKeys.length === 0) {
    process.stdout.write(`${head} No stored files.\n`);
    return;
  }
  const storage = storageFromEnv();
  if (!storage) {
    process.stdout.write(
      `${head} S3 is not configured here; delete these objects: ${result.objectKeys.join(' ')}\n`,
    );
    return;
  }
  try {
    await storage.delete(result.objectKeys);
  } catch {
    process.stdout.write(`${head} Its files could not be deleted: ${result.objectKeys.join(' ')}\n`);
    return;
  }
  process.stdout.write(`${head} ${result.objectKeys.length} file(s) deleted.\n`);
}

try {
  const { positionals, values } = parseArgs({
    args: process.argv.slice(2),
    allowPositionals: true,
    options: { reason: { type: 'string' } },
  });
  const [command, target] = positionals;
  if (command === 'pending') {
    if (positionals.length > 2) fail(USAGE);
    await pending(target);
  } else {
    if (!['request', 'cancel', 'purge-now'].includes(command ?? '') || !target || positionals.length !== 2)
      fail(USAGE);
    const reason = values.reason?.trim();
    if (!reason) fail(`${USAGE}\nA reason is required (it is kept in the audit log).`);
    if ([...reason].length > 500) fail('The reason is at most 500 characters.');
    if (command === 'request') await request(target, reason);
    else if (command === 'cancel') await cancel(target, reason);
    else await purgeNow(target, reason);
  }
} catch (err) {
  if (err instanceof TypeError) fail(`${err.message}\n${USAGE}`);
  throw err;
} finally {
  await prisma.$disconnect();
}
