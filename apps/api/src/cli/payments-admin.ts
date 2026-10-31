/**
 * Card top-ups administration (v1.59-social, D190, CONVENTIONS §10.53). Runs as the MIGRATION role
 * (MIGRATION_DATABASE_URL) like the other admin tools: on the server
 * `docker compose --profile jobs run --rm migrate node dist/cli/payments-admin.js …` (docs/DEPLOYMENT.md §11),
 * locally `pnpm payments:admin …`.
 *
 *   pnpm payments:admin orders [--email <email>] [--limit <n>]     # newest first
 *   pnpm payments:admin order <order id>                           # one order with its events and cases
 *   pnpm payments:admin cases [--all]                              # open cases (all with --all)
 *   pnpm payments:admin case <case id>                             # the FIFO-attributed gifts, recipients, cherries
 *   pnpm payments:admin close-case <case id> --note <decision>     # after deciding (e.g. reverse-gift)
 *   pnpm payments:admin unfreeze <email> --note <reason>           # lifts the card-purchase freeze
 *   pnpm payments:admin refund <order id> --note <reason>          # refunds through Stripe (STRIPE_SECRET_KEY)
 *
 * Host cherries are never taken back here: a case lists the sends funded by the purchase and the team decides with
 * `pnpm economy:admin reverse-gift <send id>` (D179). A refund made here only asks Stripe; the coins come back
 * through the signed `charge.refunded` webhook like any other refund (one path). Every change writes an audit row.
 */
import 'dotenv/config';
import { parseArgs } from 'node:util';
import { PrismaPg } from '@prisma/adapter-pg';
import { PrismaClient } from '../generated/prisma/client.js';
import { AuditAction } from '../common/audit/audit.service.js';
import { closeCaseIn } from '../modules/topup/topup-core.js';
import { createStripeApi } from '../modules/topup/stripe-api.js';

function fail(message: string): never {
  process.stderr.write(`${message}\n`);
  process.exit(1);
}

const USAGE = [
  'Usage: pnpm payments:admin orders [--email <email>] [--limit <n>]',
  '       pnpm payments:admin order <order id>',
  '       pnpm payments:admin cases [--all]',
  '       pnpm payments:admin case <case id>',
  '       pnpm payments:admin close-case <case id> --note <text>',
  '       pnpm payments:admin unfreeze <email> --note <text>',
  '       pnpm payments:admin refund <order id> --note <text>',
].join('\n');

const url = process.env.MIGRATION_DATABASE_URL;
if (!url) fail('MIGRATION_DATABASE_URL is not set (the migration role runs admin tools).');
const prisma = new PrismaClient({ adapter: new PrismaPg({ connectionString: url, max: 1 }) });

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const out = (line = '') => process.stdout.write(`${line}\n`);
const money = (minor: number, currency: string) => `${(minor / 100).toFixed(2)} ${currency}`;

function uuid(raw: string | undefined, what: string): string {
  if (!raw || !UUID.test(raw)) fail(`${what} must be a UUID.\n${USAGE}`);
  return raw.toLowerCase();
}

function note(raw: string | undefined): string {
  const text = (raw ?? '').trim();
  if (text.length < 3 || text.length > 500) fail('--note is required (3–500 characters).');
  return text;
}

async function userByEmail(email: string): Promise<string> {
  const row = await prisma.user.findUnique({
    where: { email: email.trim().toLowerCase() },
    select: { id: true },
  });
  if (!row) fail(`No user with email ${email}.`);
  return row.id;
}

async function orders(email: string | undefined, limit: number): Promise<void> {
  const userId = email ? await userByEmail(email) : undefined;
  const rows = await prisma.topupOrder.findMany({
    where: userId ? { userId } : {},
    orderBy: { createdAt: 'desc' },
    take: limit,
    include: { user: { select: { email: true } } },
  });
  if (rows.length === 0) out('No orders.');
  for (const o of rows) {
    const flags = [
      o.creditedAt ? 'credited' : '',
      o.refundedMinor > 0 ? `refunded ${money(o.refundedMinor, o.currency)}` : '',
      o.fraudWarningAt ? 'fraud-warning' : '',
      o.disputeStatus ? `dispute ${o.disputeStatus}` : '',
      o.coinsReversed > 0n ? `reversed ${o.coinsReversed.toString()}` : '',
    ].filter(Boolean);
    out(
      `${o.id}  ${o.createdAt.toISOString()}  ${o.user.email}  ${o.coins.toString()} coins  ` +
        `${money(o.amountMinor, o.currency)}  ${o.status}${flags.length ? `  [${flags.join(', ')}]` : ''}`,
    );
  }
}

async function order(id: string): Promise<void> {
  const o = await prisma.topupOrder.findUnique({
    where: { id },
    include: {
      user: { select: { email: true } },
      terms: true,
      events: { orderBy: { receivedAt: 'asc' } },
      cases: { orderBy: { createdAt: 'asc' } },
    },
  });
  if (!o) fail(`No order ${id}.`);
  const freeze = await prisma.topupFreeze.findUnique({ where: { userId: o.userId } });
  out(`Order ${o.id} — ${o.user.email}`);
  out(
    `  package ${o.packageId}: ${o.coins.toString()} coins for ${money(o.amountMinor, o.currency)} (${o.status})`,
  );
  out(`  methods ${o.paymentMethodTypes.join(', ')}; paid with ${o.paymentMethodType ?? '-'}`);
  out(
    `  stripe session ${o.stripeSessionId ?? '-'}, payment ${o.stripePaymentIntentId ?? '-'}, charge ${o.stripeChargeId ?? '-'}`,
  );
  out(`  credited ${o.creditedAt?.toISOString() ?? '-'}; coins reversed ${o.coinsReversed.toString()}`);
  out(
    `  refunded ${money(o.refundedMinor, o.currency)}; fraud warning ${o.fraudWarningAt?.toISOString() ?? '-'}`,
  );
  out(
    `  dispute ${o.disputeId ?? '-'} ${o.disputeStatus ?? ''}; evidence ${o.evidenceSubmittedAt?.toISOString() ?? '-'}`,
  );
  out(
    `  terms "${o.terms.termsText}" v${o.terms.termsVersion} at ${o.terms.acceptedAt.toISOString()} from ${o.terms.ip ?? '-'}`,
  );
  out(`  buyer frozen: ${freeze ? `yes (${freeze.reason}, since ${freeze.createdAt.toISOString()})` : 'no'}`);
  for (const e of o.events)
    out(`  event ${e.id} ${e.type} → ${e.outcome ?? '-'} ${e.processedAt ? '' : '(not finished)'}`);
  for (const c of o.cases) out(`  case ${c.id} ${c.kind} ${c.status}${c.outcome ? ` (${c.outcome})` : ''}`);
}

async function cases(all: boolean): Promise<void> {
  const rows = await prisma.topupCase.findMany({
    where: all ? {} : { status: 'OPEN' },
    orderBy: { createdAt: 'desc' },
    take: 200,
    include: { user: { select: { email: true } } },
  });
  if (rows.length === 0) out(all ? 'No cases.' : 'No open cases.');
  for (const c of rows) {
    const a = c.attribution as unknown as { gifts?: unknown[] };
    out(
      `${c.id}  ${c.createdAt.toISOString()}  ${c.kind}  ${c.status}${c.outcome ? ` (${c.outcome})` : ''}  ` +
        `${c.user.email}  order ${c.orderId}  reversed ${c.coinsReversed.toString()}  gifts ${a.gifts?.length ?? 0}`,
    );
  }
}

interface CaseGift {
  giftId: string;
  sentAt: string;
  giftCode: string | null;
  place: string;
  coinsFromPurchase: number;
  totalCoins: number;
  recipients: { userId: string; username: string | null; cherries: number }[];
  cherriesReversed: boolean;
}

async function showCase(id: string): Promise<void> {
  const c = await prisma.topupCase.findUnique({
    where: { id },
    include: { user: { select: { email: true } } },
  });
  if (!c) fail(`No case ${id}.`);
  const a = c.attribution as unknown as {
    purchasedCoins: number;
    openingBalance: number;
    unspentCoins: number;
    gifts: CaseGift[];
    otherSpends: { reason: string; referenceId: string; coins: number; at: string }[];
  };
  const wallet = await prisma.wallet.findUnique({ where: { userId: c.userId }, select: { coins: true } });
  out(`Case ${c.id} — ${c.kind} (${c.stripeObjectId}) ${c.status}${c.outcome ? `, ${c.outcome}` : ''}`);
  out(`  buyer ${c.user.email}; balance now ${(wallet?.coins ?? 0n).toString()} coins; order ${c.orderId}`);
  out(
    `  purchased ${a.purchasedCoins}, held before ${a.openingBalance}, unused ${a.unspentCoins}; reversed ${c.coinsReversed.toString()}`,
  );
  out(`  gifts funded by the purchase (first in, first out): ${a.gifts.length}`);
  for (const g of a.gifts) {
    const to = g.recipients.map((r) => `@${r.username ?? r.userId} ${r.cherries} cherries`).join(', ') || '-';
    out(
      `    send ${g.giftId}  ${g.sentAt}  ${g.giftCode ?? '?'} (${g.place})  ${g.coinsFromPurchase}/${g.totalCoins} coins  → ${to}` +
        `${g.cherriesReversed ? '  [cherries already reversed]' : ''}`,
    );
  }
  for (const o of a.otherSpends) out(`    other ${o.at}  ${o.reason}  ${o.coins} coins  (${o.referenceId})`);
  out('  To take a send\'s cherries back: pnpm economy:admin reverse-gift <send id> --note "<case id>"');
  if (c.note) out(`  note: ${c.note}`);
}

async function closeCase(id: string, text: string): Promise<void> {
  const done = await prisma.$transaction((tx) => closeCaseIn(tx, id, new Date(), text, null, null));
  if (!done) fail(`Case ${id} does not exist or is already closed; nothing changed.`);
  out(`Case ${id} closed.`);
}

async function unfreeze(email: string, text: string): Promise<void> {
  const userId = await userByEmail(email);
  await prisma.$transaction(async (tx) => {
    const freeze = await tx.topupFreeze.findUnique({ where: { userId } });
    if (!freeze) fail(`${email} is not frozen; nothing changed.`);
    await tx.topupFreeze.delete({ where: { userId } });
    await tx.auditLog.create({
      data: {
        action: AuditAction.TOPUP_UNFREEZE,
        targetType: 'user',
        targetId: userId,
        metadata: { via: 'cli', note: text, order: freeze.orderId, reason: freeze.reason },
      },
    });
  });
  out(`${email} can buy by card again (a negative coin balance still blocks gifts until it is paid).`);
}

async function refund(id: string, text: string): Promise<void> {
  const key = process.env.STRIPE_SECRET_KEY;
  if (!key) fail('STRIPE_SECRET_KEY is not set: refunds go through Stripe.');
  const o = await prisma.topupOrder.findUnique({ where: { id } });
  if (!o) fail(`No order ${id}.`);
  if (!o.stripePaymentIntentId || o.creditedAt === null)
    fail(`Order ${id} was never paid; nothing to refund.`);
  if (o.refundedMinor >= o.amountMinor) fail(`Order ${id} is already refunded in full.`);
  const stripe = createStripeApi(key);
  const result = await stripe.createRefund(
    {
      payment_intent: o.stripePaymentIntentId,
      reason: 'requested_by_customer',
      metadata: { kabso_order_id: o.id, kabso_reason: 'admin' },
    },
    `kabso-admin-refund-${o.id}`,
  );
  await prisma.auditLog.create({
    data: {
      action: AuditAction.TOPUP_ADMIN_REFUND,
      targetType: 'topup_order',
      targetId: o.id,
      metadata: { refund: result.id, status: result.status ?? '', note: text, via: 'cli' },
    },
  });
  out(`Refund ${result.id} (${result.status ?? '?'}) asked for order ${o.id}.`);
  out(
    'The coins are taken back when Stripe sends charge.refunded (the buyer is then frozen and a case opens).',
  );
}

async function main(): Promise<void> {
  const { positionals, values } = parseArgs({
    allowPositionals: true,
    options: {
      email: { type: 'string' },
      limit: { type: 'string' },
      note: { type: 'string' },
      all: { type: 'boolean', default: false },
    },
  });
  const [command, arg] = positionals;
  switch (command) {
    case 'orders': {
      const limit = values.limit === undefined ? 50 : Number(values.limit);
      if (!Number.isInteger(limit) || limit < 1 || limit > 500) fail('--limit must be 1–500.');
      return orders(values.email, limit);
    }
    case 'order':
      return order(uuid(arg, 'The order id'));
    case 'cases':
      return cases(values.all);
    case 'case':
      return showCase(uuid(arg, 'The case id'));
    case 'close-case':
      return closeCase(uuid(arg, 'The case id'), note(values.note));
    case 'unfreeze':
      if (!arg) fail(USAGE);
      return unfreeze(arg, note(values.note));
    case 'refund':
      return refund(uuid(arg, 'The order id'), note(values.note));
    default:
      fail(USAGE);
  }
}

main()
  .catch((err: unknown) => fail(`payments-admin failed: ${(err as Error).message}`))
  .finally(() => void prisma.$disconnect());
