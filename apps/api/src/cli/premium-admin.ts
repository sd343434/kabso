/**
 * Premium usernames from the command line (v1.28-live, D146, CONVENTIONS §10.32): the owner's
 * prices, the reserved list, admin grants and revokes. There is no admin UI or API. Runs as the
 * MIGRATION role (MIGRATION_DATABASE_URL), like `feature-admin`: on the server
 * `docker compose --profile jobs run --rm migrate node dist/cli/premium-admin.js …`
 * (docs/DEPLOYMENT.md §5.12), locally `pnpm premium:admin …`.
 *
 *   pnpm premium:admin price list
 *   pnpm premium:admin price set --tier LEGEND|RUBY|GOLD|SILVER --coins <n>   # monthly price of a tier
 *   pnpm premium:admin price set --username <name> --coins <n>            # one name's own price
 *   pnpm premium:admin price clear --tier <tier> | --username <name>      # not on sale / tier price
 *   pnpm premium:admin reserve add <name> [--reason <text>]               # never rented
 *   pnpm premium:admin reserve remove <name>
 *   pnpm premium:admin reserve list
 *   pnpm premium:admin grant --user <email|username> --username <name> (--days <n> | --forever) [--replace]
 *   pnpm premium:admin revoke --user <email|username>                     # ends it now, no grace
 *   pnpm premium:admin list                                                # ACTIVE and GRACE leases
 *   pnpm premium:admin status <name>                                       # tier, state and price
 *
 * Prices are whole coins from 1 to 1 000 000 000 per month. While a tier has no price its names
 * are not on sale (the store says so); nothing is ever priced by default. Every change writes an
 * audit_logs row in the same transaction (`premium_username.price`, `.reserve`, `.grant`,
 * `.revoke`). A command that changes nothing exits 0 and says so; a bad argument exits 1.
 */
import 'dotenv/config';
import { parseArgs } from 'node:util';
import { PrismaPg } from '@prisma/adapter-pg';
import { PrismaClient } from '../generated/prisma/client.js';
import { AuditAction } from '../common/audit/audit.service.js';
import {
  DAY_MS,
  endLeaseIn,
  grantIn,
  lockName,
  lockUser,
  nameInfo,
  type LeaseRow,
} from '../modules/premium-usernames/premium-username-ops.js';
import {
  PREMIUM_TIERS,
  premiumTierOf,
  type PremiumTier,
} from '../modules/premium-usernames/premium-username-rules.js';
import { isValidUsername } from '../modules/users/username.js';

function fail(message: string): never {
  process.stderr.write(`${message}\n`);
  process.exit(1);
}

const USAGE = [
  'Usage: pnpm premium:admin price list',
  '       pnpm premium:admin price set (--tier LEGEND|RUBY|GOLD|SILVER | --username <name>) --coins <n>',
  '       pnpm premium:admin price clear (--tier <tier> | --username <name>)',
  '       pnpm premium:admin reserve add <name> [--reason <text>] | reserve remove <name> | reserve list',
  '       pnpm premium:admin grant --user <email|username> --username <name> (--days <n> | --forever) [--replace]',
  '       pnpm premium:admin revoke --user <email|username>',
  '       pnpm premium:admin list',
  '       pnpm premium:admin status <name>',
].join('\n');

const MAX_PRICE = 1_000_000_000;
const MAX_GRANT_DAYS = 3650;

const url = process.env.MIGRATION_DATABASE_URL;
if (!url) fail('MIGRATION_DATABASE_URL is not set (the migration role changes premium usernames).');
const prisma = new PrismaClient({ adapter: new PrismaPg({ connectionString: url, max: 1 }) });

const OPTIONS = {
  tier: { type: 'string' },
  username: { type: 'string' },
  coins: { type: 'string' },
  reason: { type: 'string' },
  user: { type: 'string' },
  days: { type: 'string' },
  forever: { type: 'boolean' },
  replace: { type: 'boolean' },
} as const;

type Values = {
  [K in keyof typeof OPTIONS]?: (typeof OPTIONS)[K]['type'] extends 'boolean' ? boolean : string;
};

function parse(
  args: readonly string[],
  allowed: readonly string[],
): { values: Values; positionals: string[] } {
  let parsed: { values: Values; positionals: string[] };
  try {
    const out = parseArgs({ args: [...args], options: OPTIONS, strict: true, allowPositionals: true });
    parsed = { values: out.values, positionals: out.positionals };
  } catch (err) {
    fail(`${err instanceof Error ? err.message : String(err)}\n${USAGE}`);
  }
  for (const key of Object.keys(parsed.values)) {
    if (!allowed.includes(key)) fail(`--${key} is not an option of this command.\n${USAGE}`);
  }
  return parsed;
}

function tierOf(raw: string): PremiumTier {
  const tier = raw.toUpperCase() as PremiumTier;
  if (!PREMIUM_TIERS.includes(tier)) fail('--tier is LEGEND, RUBY, GOLD or SILVER.');
  return tier;
}

/** A premium-shaped name (lower case, letters and digits). */
function premiumName(raw: string): string {
  const name = raw.trim().toLowerCase().replace(/^@/, '');
  if (premiumTierOf(name) === null)
    fail(`${raw} is not a premium username (1–30 letters and digits; see §10.32).`);
  return name;
}

function coinsOf(raw: string): bigint {
  if (!/^[1-9][0-9]{0,9}$/.test(raw) || Number(raw) > MAX_PRICE) {
    fail(`--coins is a whole number from 1 to ${String(MAX_PRICE)}.`);
  }
  return BigInt(raw);
}

async function userOf(name: string): Promise<{ id: string; username: string }> {
  const raw = name.trim();
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

async function priceList(): Promise<void> {
  const [tiers, names] = await Promise.all([
    prisma.premiumUsernameTierPrice.findMany(),
    prisma.premiumUsernameNamePrice.findMany({ orderBy: { username: 'asc' } }),
  ]);
  const byTier = new Map(tiers.map((t) => [t.tier, t.monthlyCoins]));
  for (const tier of PREMIUM_TIERS) {
    const price = byTier.get(tier);
    process.stdout.write(
      `${tier.padEnd(8)} ${price === undefined ? 'not on sale' : `${String(price)} coins / month`}\n`,
    );
  }
  for (const n of names)
    process.stdout.write(`@${n.username} ${String(n.monthlyCoins)} coins / month (own price)\n`);
}

async function priceSet(args: readonly string[]): Promise<void> {
  const { values } = parse(args, ['tier', 'username', 'coins']);
  if (!values.coins) fail(`--coins is required.\n${USAGE}`);
  if (Boolean(values.tier) === Boolean(values.username)) fail(`Give --tier or --username.\n${USAGE}`);
  const coins = coinsOf(values.coins);
  await prisma.$transaction(async (tx) => {
    let before: bigint | null;
    let target: string;
    if (values.tier) {
      const tier = tierOf(values.tier);
      target = tier;
      before = (await tx.premiumUsernameTierPrice.findUnique({ where: { tier } }))?.monthlyCoins ?? null;
      await tx.premiumUsernameTierPrice.upsert({
        where: { tier },
        create: { tier, monthlyCoins: coins },
        update: { monthlyCoins: coins, updatedAt: new Date() },
      });
    } else {
      const name = premiumName(values.username!);
      target = `@${name}`;
      before =
        (await tx.premiumUsernameNamePrice.findUnique({ where: { username: name } }))?.monthlyCoins ?? null;
      await tx.premiumUsernameNamePrice.upsert({
        where: { username: name },
        create: { username: name, monthlyCoins: coins },
        update: { monthlyCoins: coins, updatedAt: new Date() },
      });
    }
    await tx.auditLog.create({
      data: {
        action: AuditAction.PREMIUM_USERNAME_PRICE,
        targetType: 'premium_username_price',
        targetId: target,
        metadata: { before: before === null ? null : Number(before), after: Number(coins), via: 'cli' },
      },
    });
    process.stdout.write(
      `${target}: ${String(coins)} coins / month (was ${before === null ? 'not on sale' : String(before)}).\n`,
    );
  });
}

async function priceClear(args: readonly string[]): Promise<void> {
  const { values } = parse(args, ['tier', 'username']);
  if (Boolean(values.tier) === Boolean(values.username)) fail(`Give --tier or --username.\n${USAGE}`);
  await prisma.$transaction(async (tx) => {
    let before: bigint | null;
    let target: string;
    if (values.tier) {
      const tier = tierOf(values.tier);
      target = tier;
      before = (await tx.premiumUsernameTierPrice.findUnique({ where: { tier } }))?.monthlyCoins ?? null;
      if (before !== null) await tx.premiumUsernameTierPrice.delete({ where: { tier } });
    } else {
      const name = premiumName(values.username!);
      target = `@${name}`;
      before =
        (await tx.premiumUsernameNamePrice.findUnique({ where: { username: name } }))?.monthlyCoins ?? null;
      if (before !== null) await tx.premiumUsernameNamePrice.delete({ where: { username: name } });
    }
    if (before === null) {
      process.stdout.write(`${target} has no price; nothing changed.\n`);
      return;
    }
    await tx.auditLog.create({
      data: {
        action: AuditAction.PREMIUM_USERNAME_PRICE,
        targetType: 'premium_username_price',
        targetId: target,
        metadata: { before: Number(before), after: null, via: 'cli' },
      },
    });
    process.stdout.write(`${target}: price removed (was ${String(before)}).\n`);
  });
}

async function reserve(args: readonly string[]): Promise<void> {
  const [sub, ...rest] = args;
  if (sub === 'list') {
    const rows = await prisma.premiumUsernameReserved.findMany({ orderBy: { name: 'asc' } });
    if (rows.length === 0)
      process.stdout.write('No names in the reserved list (the code list always applies).\n');
    for (const r of rows) process.stdout.write(`@${r.name}${r.reason ? ` — ${r.reason}` : ''}\n`);
    return;
  }
  const { values, positionals } = parse(rest, sub === 'add' ? ['reason'] : []);
  if (positionals.length !== 1) fail(USAGE);
  const name = positionals[0]!.trim().toLowerCase().replace(/^@/, '');
  if (!isValidUsername(name)) fail(`${positionals[0]!} is not a username.`);
  if (sub === 'add') {
    const reason = values.reason?.trim().slice(0, 200) ?? null;
    const added = await prisma.$transaction(async (tx) => {
      if (await tx.premiumUsernameReserved.findUnique({ where: { name } })) return false;
      await tx.premiumUsernameReserved.create({ data: { name, reason } });
      await tx.auditLog.create({
        data: {
          action: AuditAction.PREMIUM_USERNAME_RESERVE,
          targetType: 'premium_username_reserved',
          targetId: name,
          metadata: { op: 'add', reason, via: 'cli' },
        },
      });
      return true;
    });
    process.stdout.write(
      added ? `+@${name} reserved.\n` : `@${name} is already reserved; nothing changed.\n`,
    );
    return;
  }
  if (sub === 'remove') {
    const removed = await prisma.$transaction(async (tx) => {
      if (!(await tx.premiumUsernameReserved.findUnique({ where: { name } }))) return false;
      await tx.premiumUsernameReserved.delete({ where: { name } });
      await tx.auditLog.create({
        data: {
          action: AuditAction.PREMIUM_USERNAME_RESERVE,
          targetType: 'premium_username_reserved',
          targetId: name,
          metadata: { op: 'remove', via: 'cli' },
        },
      });
      return true;
    });
    process.stdout.write(
      removed ? `-@${name} is no longer reserved.\n` : `@${name} is not in the list; nothing changed.\n`,
    );
    return;
  }
  fail(USAGE);
}

async function grant(args: readonly string[]): Promise<void> {
  const { values } = parse(args, ['user', 'username', 'days', 'forever', 'replace']);
  if (!values.user || !values.username) fail(`--user and --username are required.\n${USAGE}`);
  if (Boolean(values.days) === Boolean(values.forever)) fail(`Give --days <n> or --forever.\n${USAGE}`);
  if (values.days && (!/^[1-9][0-9]{0,3}$/.test(values.days) || Number(values.days) > MAX_GRANT_DAYS)) {
    fail(`--days is a whole number from 1 to ${String(MAX_GRANT_DAYS)}.`);
  }
  const user = await userOf(values.user);
  const name = premiumName(values.username);
  const now = new Date();
  const expiresAt = values.forever ? null : new Date(now.getTime() + Number(values.days) * DAY_MS);
  const outcome = await prisma.$transaction((tx) =>
    grantIn(tx, { userId: user.id, username: name, expiresAt, replace: values.replace === true, now }),
  );
  if (!outcome.ok) fail(outcome.reason);
  process.stdout.write(
    `+@${name} granted to the user who was @${user.username} (${premiumTierOf(name)!}, until ${expiresAt?.toISOString() ?? 'no end'}; back to @${outcome.lease.regularUsername} after).\n`,
  );
}

async function revoke(args: readonly string[]): Promise<void> {
  const { values } = parse(args, ['user']);
  if (!values.user) fail(`--user is required.\n${USAGE}`);
  const user = await userOf(values.user);
  const ended = await prisma.$transaction(async (tx) => {
    await lockUser(tx, user.id);
    const leases = (await tx.premiumUsernameLease.findMany({
      where: { userId: user.id, status: { in: ['ACTIVE', 'GRACE'] } },
    })) as LeaseRow[];
    const out: string[] = [];
    for (const lease of leases) {
      await lockName(tx, lease.username);
      const { revertedTo } = await endLeaseIn(tx, lease, 'REVOKED', new Date(), null, 'cli');
      out.push(`@${lease.username} (${lease.status})${revertedTo ? ` → back to @${revertedTo}` : ''}`);
    }
    return out;
  });
  process.stdout.write(
    ended.length === 0
      ? `@${user.username} has no premium username; nothing changed.\n`
      : `Revoked ${ended.join(', ')}.\n`,
  );
}

async function list(): Promise<void> {
  const rows = await prisma.premiumUsernameLease.findMany({
    where: { status: { in: ['ACTIVE', 'GRACE'] } },
    orderBy: [{ status: 'asc' }, { expiresAt: 'asc' }],
  });
  if (rows.length === 0) {
    process.stdout.write('No premium usernames in use.\n');
    return;
  }
  for (const r of rows) {
    process.stdout.write(
      `${r.status.padEnd(6)} @${r.username} ${r.tier} ${r.source} user=${r.userId} regular=@${r.regularUsername} ` +
        `expires=${r.expiresAt?.toISOString() ?? 'never'}${r.graceUntil ? ` grace-until=${r.graceUntil.toISOString()}` : ''}\n`,
    );
  }
}

async function status(args: readonly string[]): Promise<void> {
  if (args.length !== 1) fail(USAGE);
  const name = args[0]!.trim().toLowerCase().replace(/^@/, '');
  const info = await nameInfo(prisma, name, null, new Date());
  process.stdout.write(
    `@${name}: ${info.state}, tier ${info.tier ?? '-'}, price ${info.priceCoins === null ? '-' : `${String(info.priceCoins)} coins / month`}` +
      `${info.heldUntil ? `, held until ${info.heldUntil.toISOString()}` : ''}\n`,
  );
}

const [command, ...rest] = process.argv.slice(2);
try {
  switch (command) {
    case 'price': {
      const [sub, ...more] = rest;
      if (sub === 'list' && more.length === 0) await priceList();
      else if (sub === 'set') await priceSet(more);
      else if (sub === 'clear') await priceClear(more);
      else fail(USAGE);
      break;
    }
    case 'reserve':
      await reserve(rest);
      break;
    case 'grant':
      await grant(rest);
      break;
    case 'revoke':
      await revoke(rest);
      break;
    case 'list':
      if (rest.length > 0) fail(USAGE);
      await list();
      break;
    case 'status':
      await status(rest);
      break;
    default:
      fail(command ? `Unknown command ${command}.\n${USAGE}` : USAGE);
  }
} finally {
  await prisma.$disconnect();
}
