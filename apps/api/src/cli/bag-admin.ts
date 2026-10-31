/**
 * Bag administration from the command line (CP-019, D107, CONVENTIONS §10.22). Until a store or
 * rewards exist, an admin on the server is the only way to give someone a bag item that is not
 * free. Runs as the MIGRATION role (MIGRATION_DATABASE_URL), like `wallet-admin` and
 * `medals-admin`: built into the API image and run on the server with
 * `docker compose --profile jobs run --rm migrate node dist/cli/bag-admin.js …`
 * (docs/DEPLOYMENT.md), locally with `pnpm bag:admin …`.
 *
 *   pnpm bag:admin grant  <email> <code> [<days>|forever]
 *                                  # gives the item for <days> (1–3650) or for ever (the default);
 *                                  # not worn (what the user wears stays). An item the user owns
 *                                  # gets the days added (v1.48-social, D171); `forever` makes it
 *                                  # permanent; a permanent one is left as it is.
 *   pnpm bag:admin revoke <email> <code>   # takes it back (worn → the user wears nothing there)
 *   pnpm bag:admin list   <email>          # the user's items; `*` marks the worn ones
 *
 * The active-host frames (`host_frame_blue`, `host_frame_pink`, v1.55-social, D186) are refused: the
 * server gives and takes them with the host's activity (`pnpm economy:admin agency-evaluate`).
 *
 * Every grant and revoke that changes something writes an audit_logs row (`bag.grant` /
 * `bag.revoke`) in the same transaction. Granting an item the user owns permanently changes
 * nothing (exit 0); revoking one they do not own fails (exit 1).
 */
import 'dotenv/config';
import { PrismaPg } from '@prisma/adapter-pg';
import { PrismaClient } from '../generated/prisma/client.js';
import {
  BagAdminError,
  grantBagItemByAdminIn,
  revokeBagItemByAdminIn,
} from '../modules/bag/bag-admin-rules.js';
import { BAG_MAX_DAYS } from '../modules/bag/bag.catalogue.js';

function fail(message: string): never {
  process.stderr.write(`${message}\n`);
  process.exit(1);
}

const USAGE =
  'Usage: pnpm bag:admin grant <email> <code> [<days>|forever] | revoke <email> <code> | list <email>';

const url = process.env.MIGRATION_DATABASE_URL;
if (!url) fail('MIGRATION_DATABASE_URL is not set (the migration role changes bags).');
const prisma = new PrismaClient({ adapter: new PrismaPg({ connectionString: url, max: 1 }) });

/** A refused bag change exits 1 with its sentence (nothing changed). */
async function bagStep<T>(step: () => Promise<T>): Promise<T> {
  try {
    return await step();
  } catch (err) {
    if (err instanceof BagAdminError) fail(err.message);
    throw err;
  }
}

async function user(email: string): Promise<string> {
  const row = await prisma.user.findUnique({
    where: { email: email.trim().toLowerCase() },
    select: { id: true, deletedAt: true },
  });
  if (!row || row.deletedAt !== null) fail(`No user with email ${email}.`);
  return row.id;
}

/** `<days>` (1–3650) or `forever` (the default): the days, or null for ever. */
function parseDays(arg: string | undefined): number | null {
  if (arg === undefined || arg === 'forever') return null;
  if (!/^\d{1,4}$/.test(arg) || Number(arg) < 1 || Number(arg) > BAG_MAX_DAYS) {
    fail(`Days must be 1–${BAG_MAX_DAYS} or "forever", not ${arg}.`);
  }
  return Number(arg);
}

async function grant(email: string, code: string, daysArg: string | undefined): Promise<void> {
  const days = parseDays(daysArg);
  const userId = await user(email);
  // v1.65-social (D197): the audited rule is shared with the admin panel (bag-admin-rules.ts).
  const outcome = await bagStep(() =>
    prisma.$transaction((tx) => grantBagItemByAdminIn(tx, userId, code, days)),
  );
  if (outcome.kind === 'permanent') {
    process.stdout.write(`${email} already owns ${code}; nothing changed.\n`);
    return;
  }
  const until = outcome.expiresAt === null ? 'for ever' : `until ${outcome.expiresAt.toISOString()}`;
  process.stdout.write(
    outcome.kind === 'added' && outcome.expiresAt === null
      ? `${email}: +${code}.\n`
      : `${email}: +${code} ${until}${outcome.kind === 'extended' ? ' (time added)' : ''}.\n`,
  );
}

async function revoke(email: string, code: string): Promise<void> {
  const userId = await user(email);
  const { wasEquipped } = await bagStep(() =>
    prisma.$transaction((tx) => revokeBagItemByAdminIn(tx, userId, code)),
  );
  process.stdout.write(`${email}: -${code}${wasEquipped ? ' (was worn; now wears nothing there)' : ''}.\n`);
}

async function list(email: string): Promise<void> {
  const userId = await user(email);
  const rows = await prisma.userBagItem.findMany({
    where: { userId },
    include: { item: { select: { sortOrder: true } } },
    orderBy: [{ category: 'asc' }, { item: { sortOrder: 'asc' } }, { itemCode: 'asc' }],
  });
  if (rows.length === 0) {
    process.stdout.write(`${email}: no items.\n`);
    return;
  }
  for (const r of rows) {
    process.stdout.write(
      `${r.equipped ? '*' : ' '} ${r.category} ${r.itemCode} (${r.source}, ${r.acquiredAt.toISOString()}${
        r.expiresAt === null
          ? ''
          : `, ${r.expiresAt <= new Date() ? 'expired' : 'until'} ${r.expiresAt.toISOString()}`
      })\n`,
    );
  }
}

const [command, email, code, extra] = process.argv.slice(2);
try {
  if (!email) fail(USAGE);
  if (command === 'grant' || command === 'revoke') {
    if (!code) fail(USAGE);
    if (command === 'grant') await grant(email, code, extra);
    else await revoke(email, code);
  } else if (command === 'list') await list(email);
  else fail(`Unknown command ${command ?? ''}.`);
} finally {
  await prisma.$disconnect();
}
