/**
 * Bag administration from the command line (CP-019, D107, CONVENTIONS §10.22). Until a store or
 * rewards exist, an admin on the server is the only way to give someone a bag item that is not
 * free. Runs as the MIGRATION role (MIGRATION_DATABASE_URL), like `wallet-admin` and
 * `medals-admin`: built into the API image and run on the server with
 * `docker compose --profile jobs run --rm migrate node dist/cli/bag-admin.js …`
 * (docs/DEPLOYMENT.md), locally with `pnpm bag:admin …`.
 *
 *   pnpm bag:admin grant  <email> <code>   # gives the item (not worn; what the user wears stays)
 *   pnpm bag:admin revoke <email> <code>   # takes it back (worn → the user wears nothing there)
 *   pnpm bag:admin list   <email>          # the user's items; `*` marks the worn ones
 *
 * Every grant and revoke that changes something writes an audit_logs row (`bag.grant` /
 * `bag.revoke`) in the same transaction. Granting an item the user owns changes nothing (exit 0);
 * revoking one they do not own fails (exit 1).
 */
import 'dotenv/config';
import { PrismaPg } from '@prisma/adapter-pg';
import { PrismaClient } from '../generated/prisma/client.js';
import { AuditAction } from '../common/audit/audit.service.js';
import { catalogueItemIn, grantItemIn, revokeItemIn } from '../modules/bag/bag-grants.js';

function fail(message: string): never {
  process.stderr.write(`${message}\n`);
  process.exit(1);
}

const USAGE = 'Usage: pnpm bag:admin grant|revoke <email> <code> | list <email>';

const url = process.env.MIGRATION_DATABASE_URL;
if (!url) fail('MIGRATION_DATABASE_URL is not set (the migration role changes bags).');
const prisma = new PrismaClient({ adapter: new PrismaPg({ connectionString: url, max: 1 }) });

async function user(email: string): Promise<string> {
  const row = await prisma.user.findUnique({
    where: { email: email.trim().toLowerCase() },
    select: { id: true, deletedAt: true },
  });
  if (!row || row.deletedAt !== null) fail(`No user with email ${email}.`);
  return row.id;
}

async function grant(email: string, code: string): Promise<void> {
  const userId = await user(email);
  const granted = await prisma.$transaction(async (tx) => {
    const item = await catalogueItemIn(tx, code);
    if (!item) fail(`No bag item ${code}.`);
    const added = await grantItemIn(tx, userId, item, 'ADMIN');
    if (added) {
      await tx.auditLog.create({
        data: {
          action: AuditAction.BAG_GRANT,
          targetType: 'user',
          targetId: userId,
          metadata: { item: item.code, category: item.category, via: 'cli' },
        },
      });
    }
    return added;
  });
  process.stdout.write(
    granted ? `${email}: +${code}.\n` : `${email} already owns ${code}; nothing changed.\n`,
  );
}

async function revoke(email: string, code: string): Promise<void> {
  const userId = await user(email);
  const wasEquipped = await prisma.$transaction(async (tx) => {
    const result = await revokeItemIn(tx, userId, code);
    if (!result.owned) fail(`${email} does not own ${code}; nothing changed.`);
    await tx.auditLog.create({
      data: {
        action: AuditAction.BAG_REVOKE,
        targetType: 'user',
        targetId: userId,
        metadata: { item: code, wasEquipped: result.wasEquipped, via: 'cli' },
      },
    });
    return result.wasEquipped;
  });
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
      `${r.equipped ? '*' : ' '} ${r.category} ${r.itemCode} (${r.source}, ${r.acquiredAt.toISOString()})\n`,
    );
  }
}

const [command, email, code] = process.argv.slice(2);
try {
  if (!email) fail(USAGE);
  if (command === 'grant' || command === 'revoke') {
    if (!code) fail(USAGE);
    if (command === 'grant') await grant(email, code);
    else await revoke(email, code);
  } else if (command === 'list') await list(email);
  else fail(`Unknown command ${command ?? ''}.`);
} finally {
  await prisma.$disconnect();
}
