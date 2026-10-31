/**
 * The admin panel's roles from the command line (v1.60-social, D191, owner 2026-10-31, CONVENTIONS §10.54.1). The
 * panel itself cannot grant or revoke roles. Runs as the MIGRATION role (MIGRATION_DATABASE_URL), like
 * `recharge-admin`: on the server `docker compose --profile jobs run --rm migrate node dist/cli/admin-admin.js …`
 * (docs/DEPLOYMENT.md), locally `pnpm admin:admin …`.
 *
 *   pnpm admin:admin grant <email> OWNER|MODERATOR|SUPPORT|FINANCE   # the first OWNER is bootstrapped this way
 *   pnpm admin:admin revoke <email> OWNER|MODERATOR|SUPPORT|FINANCE  # the last role ends the panel sessions
 *   pnpm admin:admin list
 *   pnpm admin:admin reset-2fa <email>                               # a lost phone: enrol again at the next sign-in
 *
 * A grant makes the account an admin (`users.role = ADMIN`) when it is not yet. Every change writes an audit row in
 * its transaction; a bad argument or a refused change exits 1 (nothing changed).
 */
import 'dotenv/config';
import { parseArgs } from 'node:util';
import { PrismaPg } from '@prisma/adapter-pg';
import { PrismaClient } from '../generated/prisma/client.js';
import {
  AdminRoleError,
  grantRoleIn,
  listPanelAdmins,
  parseRole,
  resetSecondFactorIn,
  revokeRoleIn,
} from '../modules/admin-panel/admin-roles.js';

function fail(message: string): never {
  process.stderr.write(`${message}\n`);
  process.exit(1);
}

const USAGE = [
  'Usage: pnpm admin:admin grant|revoke <email> OWNER|MODERATOR|SUPPORT|FINANCE',
  '       pnpm admin:admin list | reset-2fa <email>',
].join('\n');

const url = process.env.MIGRATION_DATABASE_URL;
if (!url) fail('MIGRATION_DATABASE_URL is not set (the migration role grants admin roles).');
const prisma = new PrismaClient({ adapter: new PrismaPg({ connectionString: url, max: 1 }) });

try {
  const { positionals } = parseArgs({ args: process.argv.slice(2), allowPositionals: true, options: {} });
  const [command, email, roleRaw] = positionals;
  if (command === 'grant' || command === 'revoke') {
    if (!email || !roleRaw || positionals.length !== 3) fail(USAGE);
    const role = parseRole(roleRaw);
    if (command === 'grant') {
      const r = await prisma.$transaction((tx) => grantRoleIn(tx, email, role));
      process.stdout.write(
        `${email}: ${role} granted${r.madeAdmin ? ' (the account is now an admin)' : ''}.\n`,
      );
    } else {
      const r = await prisma.$transaction((tx) => revokeRoleIn(tx, email, role));
      process.stdout.write(
        `${email}: ${role} revoked; ${r.left.length === 0 ? 'no panel role left (panel sessions ended)' : `left ${r.left.join(', ')}`}.\n`,
      );
    }
  } else if (command === 'reset-2fa') {
    if (!email || positionals.length !== 2) fail(USAGE);
    await prisma.$transaction((tx) => resetSecondFactorIn(tx, email));
    process.stdout.write(`${email}: authenticator reset; the next sign-in sets it up again.\n`);
  } else if (command === 'list') {
    const rows = await prisma.$transaction((tx) => listPanelAdmins(tx));
    for (const r of rows) {
      process.stdout.write(
        `${r.email}  ${r.roles.join(',')}  ${r.role}/${r.status}  2FA ${r.enrolled ? 'on' : 'not set up'}` +
          `${r.lockedUntil && r.lockedUntil > new Date() ? `  locked until ${r.lockedUntil.toISOString()}` : ''}\n`,
      );
    }
    if (rows.length === 0) process.stdout.write('No panel admins.\n');
  } else {
    fail(USAGE);
  }
} catch (err) {
  if (err instanceof AdminRoleError) fail(err.message);
  if (err instanceof TypeError) fail(`${err.message}\n${USAGE}`);
  throw err;
} finally {
  await prisma.$disconnect();
}
