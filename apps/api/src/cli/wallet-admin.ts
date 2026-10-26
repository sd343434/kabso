/**
 * Coins administration from the command line (CP-017, D104, CONVENTIONS §10.19). Purchases wait
 * for B5, so an admin on the server is the only source of coins. Runs as the MIGRATION role
 * (MIGRATION_DATABASE_URL), like `levels-admin`: built into the API image and run on the server
 * with `docker compose --profile jobs run --rm migrate node dist/cli/wallet-admin.js …`
 * (docs/DEPLOYMENT.md §11), locally with `pnpm wallet:admin …`.
 *
 *   pnpm wallet:admin grant   <email> <coins>   # adds coins (a positive whole number)
 *   pnpm wallet:admin revoke  <email> <coins>   # takes coins back (never below 0)
 *   pnpm wallet:admin balance <email>
 *
 * Every grant and revoke writes a `wallet_ledger` row and an audit_logs row in one transaction.
 */
import 'dotenv/config';
import { PrismaPg } from '@prisma/adapter-pg';
import { PrismaClient } from '../generated/prisma/client.js';
import { AuditAction } from '../common/audit/audit.service.js';
import { uuidv7 } from '../modules/levels/uuidv7.js';
import { creditIn, debitIn, MAX_COINS } from '../modules/wallet/wallet-ledger.js';

/** The most coins one command moves (a typo guard; the balance itself may grow beyond it). */
const MAX_PER_COMMAND = 1_000_000_000n;

function fail(message: string): never {
  process.stderr.write(`${message}\n`);
  process.exit(1);
}

const url = process.env.MIGRATION_DATABASE_URL;
if (!url) fail('MIGRATION_DATABASE_URL is not set (the migration role changes balances).');
const prisma = new PrismaClient({ adapter: new PrismaPg({ connectionString: url, max: 1 }) });

async function user(email: string): Promise<string> {
  const row = await prisma.user.findUnique({
    where: { email: email.trim().toLowerCase() },
    select: { id: true, deletedAt: true },
  });
  if (!row || row.deletedAt !== null) fail(`No user with email ${email}.`);
  return row.id;
}

function amount(raw: string | undefined): bigint {
  if (raw === undefined || !/^\d{1,13}$/.test(raw)) fail('Coins must be a positive whole number.');
  const value = BigInt(raw);
  if (value <= 0n) fail('Coins must be a positive whole number.');
  if (value > MAX_PER_COMMAND) fail(`At most ${MAX_PER_COMMAND.toString()} coins per command.`);
  return value;
}

async function grant(email: string, coins: bigint): Promise<void> {
  const userId = await user(email);
  const reference = uuidv7();
  const change = await prisma.$transaction(async (tx) => {
    const wallet = await tx.wallet.findUnique({ where: { userId }, select: { coins: true } });
    if ((wallet?.coins ?? 0n) + coins > MAX_COINS) fail('The balance would exceed 2^53 − 1 coins.');
    const result = await creditIn(tx, userId, coins, 'ADMIN_GRANT', reference);
    await tx.auditLog.create({
      data: {
        action: AuditAction.WALLET_GRANT,
        targetType: 'user',
        targetId: userId,
        metadata: {
          coins: Number(coins),
          balance: Number(result.coins),
          ledgerId: result.ledgerId,
          via: 'cli',
        },
      },
    });
    return result;
  });
  process.stdout.write(`${email}: +${coins.toString()} coins, balance ${change.coins.toString()}.\n`);
}

async function revoke(email: string, coins: bigint): Promise<void> {
  const userId = await user(email);
  const reference = uuidv7();
  const change = await prisma.$transaction(async (tx) => {
    const result = await debitIn(tx, userId, coins, 'ADMIN_REVOKE', reference);
    if (!result) fail(`${email} has fewer than ${coins.toString()} coins; nothing changed.`);
    await tx.auditLog.create({
      data: {
        action: AuditAction.WALLET_REVOKE,
        targetType: 'user',
        targetId: userId,
        metadata: {
          coins: Number(coins),
          balance: Number(result.coins),
          ledgerId: result.ledgerId,
          via: 'cli',
        },
      },
    });
    return result;
  });
  process.stdout.write(`${email}: -${coins.toString()} coins, balance ${change.coins.toString()}.\n`);
}

async function balance(email: string): Promise<void> {
  const userId = await user(email);
  const wallet = await prisma.wallet.findUnique({ where: { userId }, select: { coins: true } });
  process.stdout.write(`${email}: ${(wallet?.coins ?? 0n).toString()} coins.\n`);
}

const [command, email, coins] = process.argv.slice(2);
try {
  if (!email) fail('Usage: pnpm wallet:admin grant|revoke <email> <coins> | balance <email>');
  if (command === 'grant') await grant(email, amount(coins));
  else if (command === 'revoke') await revoke(email, amount(coins));
  else if (command === 'balance') await balance(email);
  else fail(`Unknown command ${command ?? ''}.`);
} finally {
  await prisma.$disconnect();
}
