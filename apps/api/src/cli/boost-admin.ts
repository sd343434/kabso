/**
 * Traffic cards «بطاقة الزيارات» from the command line (v1.33-live, D154b, CONVENTIONS §10.34). An admin
 * grants cards as rewards (owner 15); the prices are server config (`LIVE_BOOST_PRICES`). Runs as the
 * MIGRATION role (MIGRATION_DATABASE_URL), like `gift-admin`: on the server
 * `docker compose --profile jobs run --rm migrate node dist/cli/boost-admin.js …` (docs/DEPLOYMENT.md),
 * locally `pnpm boost:admin …`.
 *
 *   pnpm boost:admin grant <email|username> <minutes> <quantity>   # adds cards (audited)
 *   pnpm boost:admin cards <email|username>                        # the user's cards
 *   pnpm boost:admin queue                                         # cards running and waiting now
 *
 * `<minutes>` must be one of the lengths on sale (`LIVE_BOOST_PRICES`, default 10, 20, 30, 60), so a
 * card can always be used. Every grant writes an audit_logs row (`live.boost_card.grant`) in the same
 * transaction. A bad argument or an unknown user exits 1.
 */
import 'dotenv/config';
import { PrismaPg } from '@prisma/adapter-pg';
import { PrismaClient } from '../generated/prisma/client.js';
import { AuditAction } from '../common/audit/audit.service.js';
import { envSchema } from '../config/env.schema.js';
import { addBoostCardsIn, BOOST_CARDS_MAX } from '../modules/live/live-boosts.js';

function fail(message: string): never {
  process.stderr.write(`${message}\n`);
  process.exit(1);
}

const USAGE = [
  'Usage: pnpm boost:admin grant <email|username> <minutes> <quantity>',
  '       pnpm boost:admin cards <email|username>',
  '       pnpm boost:admin queue',
].join('\n');

const url = process.env.MIGRATION_DATABASE_URL;
if (!url) fail('MIGRATION_DATABASE_URL is not set (the migration role grants traffic cards).');
const prisma = new PrismaClient({ adapter: new PrismaPg({ connectionString: url, max: 1 }) });

/** The lengths on sale, from the API's own setting (or its default). */
function lengths(): number[] {
  const parsed = envSchema.shape.LIVE_BOOST_PRICES.safeParse(process.env.LIVE_BOOST_PRICES);
  if (!parsed.success) fail('LIVE_BOOST_PRICES is invalid (see docs/DEPLOYMENT.md §5.18).');
  return parsed.data.map((p) => p.minutes);
}

/** The user named by an email (with `@`) or a username; never a deleted account. */
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

function wholeNumber(raw: string | undefined, what: string): number {
  if (raw === undefined || !/^[1-9][0-9]{0,6}$/.test(raw))
    fail(`${what} must be a whole number above 0.\n${USAGE}`);
  return Number(raw);
}

async function grant(
  name: string,
  rawMinutes: string | undefined,
  rawQuantity: string | undefined,
): Promise<void> {
  const minutes = wholeNumber(rawMinutes, 'The minutes');
  const quantity = wholeNumber(rawQuantity, 'The quantity');
  const sale = lengths();
  if (!sale.includes(minutes)) fail(`Cards are ${sale.join(', ')} minutes long (LIVE_BOOST_PRICES).`);
  if (quantity > BOOST_CARDS_MAX) fail(`At most ${String(BOOST_CARDS_MAX)} at once.`);
  const user = await userOf(name);
  const total = await prisma.$transaction(async (tx) => {
    const after = await addBoostCardsIn(tx, user.id, minutes, quantity);
    if (after === null)
      fail(`@${user.username} would hold more than ${String(BOOST_CARDS_MAX)}; nothing changed.`);
    await tx.auditLog.create({
      data: {
        action: AuditAction.LIVE_BOOST_CARD_GRANT,
        targetType: 'user',
        targetId: user.id,
        metadata: { minutes, quantity, total: after, via: 'cli' },
      },
    });
    return after;
  });
  process.stdout.write(
    `@${user.username}: +${String(quantity)} × ${String(minutes)} min, holds ${String(total)}.\n`,
  );
}

async function cards(name: string): Promise<void> {
  const user = await userOf(name);
  const rows = await prisma.liveBoostCard.findMany({
    where: { userId: user.id, quantity: { gt: 0 } },
    orderBy: { minutes: 'asc' },
  });
  if (rows.length === 0) {
    process.stdout.write(`@${user.username}: no traffic cards.\n`);
    return;
  }
  for (const r of rows) process.stdout.write(`${String(r.minutes)} min × ${String(r.quantity)}\n`);
}

async function queue(): Promise<void> {
  const now = new Date();
  const rows = await prisma.liveBoost.findMany({
    where: { cancelledAt: null, endsAt: { gt: now } },
    orderBy: [{ startsAt: 'asc' }, { id: 'asc' }],
    include: {
      host: { select: { profile: { select: { username: true } } } },
      buyer: { select: { profile: { select: { username: true } } } },
    },
  });
  if (rows.length === 0) {
    process.stdout.write('No traffic cards running or waiting.\n');
    return;
  }
  for (const r of rows) {
    process.stdout.write(
      `${r.startsAt <= now ? 'RUNNING' : 'WAITING'} slot ${String(r.slot)} ${r.startsAt.toISOString()} → ` +
        `${r.endsAt.toISOString()} @${r.host.profile?.username ?? '?'} by @${r.buyer.profile?.username ?? '?'} ` +
        `${String(r.minutes)} min ${r.source}${r.source === 'COINS' ? ` ${String(r.coinsCharged)} coins` : ''}\n`,
    );
  }
}

const [command, first, ...rest] = process.argv.slice(2);
try {
  switch (command) {
    case 'grant':
      if (!first || rest.length !== 2) fail(USAGE);
      await grant(first, rest[0], rest[1]);
      break;
    case 'cards':
      if (!first || rest.length > 0) fail(USAGE);
      await cards(first);
      break;
    case 'queue':
      if (first !== undefined) fail(USAGE);
      await queue();
      break;
    default:
      fail(command ? `Unknown command ${command}.\n${USAGE}` : USAGE);
  }
} finally {
  await prisma.$disconnect();
}
