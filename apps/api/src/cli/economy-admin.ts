/**
 * The cherry economy's administration from the command line (v1.52-social, D179, CONVENTIONS §10.46). There
 * is no admin UI: the team creates host agencies, links sub-agencies to their parent, resolves hosts'
 * complaints, pays or rejects withdrawal requests (no payment provider yet: the money is sent by hand)
 * and reverses a send's cherries. Runs as the MIGRATION role (MIGRATION_DATABASE_URL), like `wallet-admin`:
 * on the server `docker compose --profile jobs run --rm migrate node dist/cli/economy-admin.js …`
 * (docs/DEPLOYMENT.md), locally `pnpm economy:admin …`.
 *
 *   pnpm economy:admin agency-create <owner email> [--parent <invite code>]   # prints the invite code
 *   pnpm economy:admin agency-parent <invite code> <parent invite code | none>
 *   pnpm economy:admin agency-list
 *   pnpm economy:admin agency-evaluate        # the rank evaluation and the active-host frames now (what the sweeper does)
 *   pnpm economy:admin complaints [--all]
 *   pnpm economy:admin complaint-resolve <complaint id> release|keep|move [--to <invite code>] [--note <text>]
 *   pnpm economy:admin withdrawals [--status pending|paid|rejected]
 *   pnpm economy:admin withdrawal-pay <withdrawal id> [--note <payment reference>]
 *   pnpm economy:admin withdrawal-reject <withdrawal id> --note <reason>   # the cherries go back
 *   pnpm economy:admin reverse-gift <send id> [--note <reason>]           # mirrors the send's cherries
 *   pnpm economy:admin balance <email>
 *
 * Every change writes an audit_logs row in the same transaction. A bad argument, an unknown row or a
 * decision on a request that is no longer pending exits 1 (nothing changed).
 */
import 'dotenv/config';
import { parseArgs } from 'node:util';
import { PrismaPg } from '@prisma/adapter-pg';
import { PrismaClient, type CherryWithdrawalStatus } from '../generated/prisma/client.js';
import { AuditAction } from '../common/audit/audit.service.js';
import { envSchema } from '../config/env.schema.js';
import { evaluateAgencyRanks } from '../modules/economy/agency-ranks.js';
import { syncHostFrames, type HostFrameChange } from '../modules/economy/host-frames.js';
import { refundCherriesIn, reverseGiftCherriesIn } from '../modules/economy/cherry-ledger.js';
import {
  addMonths,
  dateValue,
  monthKey,
  newInviteCode,
  normalizeInviteCode,
} from '../modules/economy/economy-math.js';
import { uuidv7 } from '../modules/levels/uuidv7.js';

function fail(message: string): never {
  process.stderr.write(`${message}\n`);
  process.exit(1);
}

const USAGE = [
  'Usage: pnpm economy:admin agency-create <owner email> [--parent <invite code>]',
  '       pnpm economy:admin agency-parent <invite code> <parent invite code | none>',
  '       pnpm economy:admin agency-list | agency-evaluate',
  '       pnpm economy:admin complaints [--all]',
  '       pnpm economy:admin complaint-resolve <id> release|keep|move [--to <invite code>] [--note <text>]',
  '       pnpm economy:admin withdrawals [--status pending|paid|rejected]',
  '       pnpm economy:admin withdrawal-pay <id> [--note <text>] | withdrawal-reject <id> --note <text>',
  '       pnpm economy:admin reverse-gift <send id> [--note <text>]',
  '       pnpm economy:admin balance <email>',
].join('\n');

const url = process.env.MIGRATION_DATABASE_URL;
if (!url) fail('MIGRATION_DATABASE_URL is not set (the migration role changes balances).');
const prisma = new PrismaClient({ adapter: new PrismaPg({ connectionString: url, max: 1 }) });

/** A setting from the environment with the API's own validation and default. */
function setting<K extends keyof typeof envSchema.shape>(key: K): unknown {
  const parsed = envSchema.shape[key].safeParse(process.env[key]);
  if (!parsed.success) fail(`${key} is invalid: ${parsed.error.issues[0]?.message ?? 'bad value'}`);
  return parsed.data;
}
const zone = () => setting('LIVE_RANKINGS_TIME_ZONE') as string;

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
function id(raw: string | undefined, what: string): string {
  if (!raw || !UUID.test(raw)) fail(`${what} must be an id (UUID).`);
  return raw.toLowerCase();
}

function note(raw: string | undefined, required: boolean): string | null {
  const value = (raw ?? '').trim();
  if (value === '') {
    if (required) fail('--note is required.');
    return null;
  }
  if (value.length > 500) fail('--note is at most 500 characters.');
  return value;
}

async function userByEmail(email: string | undefined): Promise<{ id: string; status: string }> {
  if (!email) fail(USAGE);
  const row = await prisma.user.findUnique({
    where: { email: email.trim().toLowerCase() },
    select: { id: true, status: true, deletedAt: true },
  });
  if (!row || row.deletedAt !== null) fail(`No user with email ${email}.`);
  return row;
}

async function agencyByCode(
  raw: string | undefined,
): Promise<{ id: string; ownerUserId: string; inviteCode: string }> {
  const code = raw === undefined ? null : normalizeInviteCode(raw);
  const agency = code === null ? null : await prisma.agency.findUnique({ where: { inviteCode: code } });
  if (!agency) fail(`No agency with invite code ${raw ?? ''}.`);
  return agency;
}

async function agencyCreate(email: string | undefined, parentCode: string | undefined): Promise<void> {
  const owner = await userByEmail(email);
  if (owner.status !== 'ACTIVE') fail(`${email ?? ''} is not an ACTIVE account.`);
  if ((await prisma.agency.count({ where: { ownerUserId: owner.id } })) > 0)
    fail(`${email ?? ''} already has an agency.`);
  if ((await prisma.agencyHost.count({ where: { hostUserId: owner.id, status: 'ACTIVE' } })) > 0) {
    fail(`${email ?? ''} is a host of an agency; the host must leave it (or an admin release it) first.`);
  }
  const parent = parentCode === undefined ? null : await agencyByCode(parentCode);
  // A NEW agency keeps its commission until the month start two months after its creation month (its grace).
  const evaluateFrom = addMonths(monthKey(new Date(), zone()), 2);
  for (let attempt = 0; attempt < 5; attempt++) {
    const code = newInviteCode();
    if ((await prisma.agency.count({ where: { inviteCode: code } })) > 0) continue;
    const agencyId = uuidv7();
    await prisma.$transaction(async (tx) => {
      await tx.agency.create({
        data: {
          id: agencyId,
          ownerUserId: owner.id,
          inviteCode: code,
          parentAgencyId: parent?.id ?? null,
          evaluateFrom: dateValue(evaluateFrom),
        },
      });
      await tx.auditLog.create({
        data: {
          action: AuditAction.AGENCY_CREATE,
          targetType: 'agency',
          targetId: agencyId,
          metadata: {
            owner: owner.id,
            inviteCode: code,
            parent: parent?.id ?? null,
            evaluateFrom,
            via: 'cli',
          },
        },
      });
    });
    process.stdout.write(
      `Agency ${agencyId} for ${email ?? ''}: invite code ${code} (evaluated from ${evaluateFrom}).\n`,
    );
    return;
  }
  fail('Could not find a free invite code; try again.');
}

async function agencyParent(code: string | undefined, parentCode: string | undefined): Promise<void> {
  const agency = await agencyByCode(code);
  if (parentCode === undefined) fail(USAGE);
  const parent = parentCode.toLowerCase() === 'none' ? null : await agencyByCode(parentCode);
  if (parent) {
    // No cycle: the parent must not be the agency or one of its descendants.
    let cursor: string | null = parent.id;
    for (let depth = 0; cursor !== null && depth < 100; depth++) {
      if (cursor === agency.id) fail('That parent would make a cycle.');
      const row: { parentAgencyId: string | null } | null = await prisma.agency.findUnique({
        where: { id: cursor },
        select: { parentAgencyId: true },
      });
      cursor = row?.parentAgencyId ?? null;
    }
  }
  await prisma.$transaction(async (tx) => {
    await tx.agency.update({ where: { id: agency.id }, data: { parentAgencyId: parent?.id ?? null } });
    await tx.auditLog.create({
      data: {
        action: AuditAction.AGENCY_PARENT,
        targetType: 'agency',
        targetId: agency.id,
        metadata: { parent: parent?.id ?? null, via: 'cli' },
      },
    });
  });
  process.stdout.write(`${agency.inviteCode}: parent ${parent?.inviteCode ?? 'none'}.\n`);
}

async function agencyList(): Promise<void> {
  const month = monthKey(new Date(), zone());
  const rows = await prisma.agency.findMany({
    orderBy: { createdAt: 'asc' },
    select: {
      id: true,
      inviteCode: true,
      rank: true,
      rankMonth: true,
      parent: { select: { inviteCode: true } },
      owner: { select: { email: true } },
      _count: { select: { hosts: { where: { status: 'ACTIVE' } } } },
      months: { where: { month: dateValue(month) }, select: { hostCherries: true, commission: true } },
    },
  });
  if (rows.length === 0) process.stdout.write('No agencies.\n');
  for (const a of rows) {
    const m = a.months[0];
    process.stdout.write(
      `${a.inviteCode} ${a.rank} (${a.rankMonth?.toISOString().slice(0, 7) ?? 'not evaluated'}) owner ${a.owner.email}` +
        ` parent ${a.parent?.inviteCode ?? '-'} hosts ${String(a._count.hosts)}` +
        ` month ${month.slice(0, 7)}: hosts' cherries ${(m?.hostCherries ?? 0n).toString()},` +
        ` commission ${(m?.commission ?? 0n).toString()}\n`,
    );
  }
}

async function agencyEvaluate(): Promise<void> {
  const rules = {
    rankMinActiveHosts: setting('AGENCY_RANK_MIN_ACTIVE_HOSTS') as number,
    rankExceptionCherries: setting('AGENCY_RANK_EXCEPTION_CHERRIES') as number,
    adminMinSubAgencies: setting('AGENCY_ADMIN_MIN_SUB_AGENCIES') as number,
    ...activityRules(),
  };
  const now = new Date();
  const changes = await evaluateAgencyRanks(prisma, now, rules, zone());
  if (changes.length === 0) process.stdout.write('No rank changed.\n');
  for (const c of changes) {
    process.stdout.write(`${c.agencyId}: ${c.from} → ${c.to}${c.monthStart ? ' (month start)' : ''}\n`);
  }
  // v1.55-social (D186): the active-host frames follow the same active-host test.
  const frames = await syncHostFrames(prisma, now, rules, zone());
  if (frames.length === 0) process.stdout.write('No host frame changed.\n');
  for (const f of frames) process.stdout.write(`${hostFrameLine(f)}\n`);
}

function hostFrameLine(f: HostFrameChange): string {
  if (f.kind === 'granted') return `host frame ${f.userId}: +${f.code}`;
  if (f.kind === 'revoked') return `host frame ${f.userId}: -${f.code}${f.wasWorn ? ' (was worn)' : ''}`;
  return `host frame ${f.userId}: ${f.from} → ${f.to}${f.worn ? ' (worn)' : ''}`;
}

/** The activity rules (the active-host test) from the environment. */
function activityRules() {
  return {
    activeHostMinDays: setting('AGENCY_ACTIVE_HOST_MIN_DAYS') as number,
    activeHostMinHours: setting('AGENCY_ACTIVE_HOST_MIN_HOURS') as number,
    activeHostWindowDays: setting('AGENCY_ACTIVE_HOST_WINDOW_DAYS') as number,
  };
}

async function complaints(all: boolean): Promise<void> {
  const rows = await prisma.agencyComplaint.findMany({
    where: all ? {} : { status: 'OPEN' },
    orderBy: { createdAt: 'asc' },
    take: 200,
  });
  if (rows.length === 0) process.stdout.write(all ? 'No complaints.\n' : 'No open complaints.\n');
  for (const c of rows) {
    const [host, agency] = await Promise.all([
      prisma.user.findUnique({ where: { id: c.hostUserId }, select: { email: true } }),
      prisma.agency.findUnique({ where: { id: c.agencyId }, select: { inviteCode: true } }),
    ]);
    process.stdout.write(
      `${c.id} ${c.status}${c.resolution ? `/${c.resolution}` : ''} ${c.createdAt.toISOString()} host ${host?.email ?? '?'}` +
        ` agency ${agency?.inviteCode ?? '?'}: ${JSON.stringify(c.text)}\n`,
    );
  }
}

async function complaintResolve(
  complaintId: string,
  action: string | undefined,
  to: string | undefined,
  text: string | null,
): Promise<void> {
  if (action !== 'release' && action !== 'keep' && action !== 'move') fail(USAGE);
  const target = action === 'move' ? await agencyByCode(to) : null;
  if (action === 'move' && to === undefined) fail('move needs --to <invite code>.');
  const now = new Date();
  const result = await prisma.$transaction(async (tx) => {
    const [c] = await tx.$queryRaw<
      { id: string; status: string; agency_host_id: string; host_user_id: string }[]
    >`
      SELECT id::text AS id, status::text AS status, agency_host_id::text AS agency_host_id,
             host_user_id::text AS host_user_id
        FROM agency_complaints WHERE id = ${complaintId}::uuid FOR UPDATE`;
    if (!c) fail(`No complaint ${complaintId}.`);
    if (c.status !== 'OPEN') fail(`Complaint ${complaintId} is ${c.status}; nothing changed.`);
    const link = await tx.agencyHost.findUnique({ where: { id: c.agency_host_id } });
    if (target && target.ownerUserId === c.host_user_id) fail('A host cannot be moved to their own agency.');
    if (target && link && target.id === link.agencyId) fail('The host is already in that agency.');
    if (action !== 'keep' && link?.status === 'ACTIVE') {
      await tx.agencyHost.update({
        where: { id: link.id },
        data: { status: action === 'move' ? 'MOVED' : 'RELEASED', endedAt: now },
      });
    }
    let newLink: string | null = null;
    if (target) {
      const rank = await tx.agency.findUnique({ where: { id: target.id }, select: { rank: true } });
      newLink = uuidv7();
      await tx.agencyHost.create({
        data: {
          id: newLink,
          agencyId: target.id,
          hostUserId: c.host_user_id,
          commissionEligible: rank?.rank !== 'LAPSED',
          activatedAt: now,
        },
      });
    }
    await tx.agencyComplaint.update({
      where: { id: complaintId },
      data: {
        status: action === 'keep' ? 'REJECTED' : 'RESOLVED',
        resolution: action === 'release' ? 'RELEASED' : action === 'move' ? 'MOVED' : 'KEPT',
        note: text,
        resolvedAt: now,
      },
    });
    await tx.auditLog.create({
      data: {
        action: AuditAction.AGENCY_COMPLAINT_RESOLVE,
        targetType: 'agency_complaint',
        targetId: complaintId,
        metadata: { action, link: link?.id ?? null, to: target?.id ?? null, newLink, note: text, via: 'cli' },
      },
    });
    return { action, hostUserId: c.host_user_id };
  });
  process.stdout.write(`Complaint ${complaintId}: ${result.action}.\n`);
  // v1.55-social (D186): a released host is no longer an agency host (the frame follows at once).
  for (const f of await syncHostFrames(prisma, new Date(), activityRules(), zone(), [result.hostUserId]))
    process.stdout.write(`${hostFrameLine(f)}\n`);
}

async function withdrawals(statusRaw: string | undefined): Promise<void> {
  const status = (statusRaw ?? 'pending').toUpperCase();
  if (!['PENDING', 'PAID', 'REJECTED'].includes(status)) fail(USAGE);
  const rows = await prisma.cherryWithdrawal.findMany({
    where: { status: status as CherryWithdrawalStatus },
    orderBy: { createdAt: 'asc' },
    take: 200,
    select: {
      id: true,
      cherries: true,
      amountMinor: true,
      currency: true,
      payoutDetails: true,
      createdAt: true,
      decisionNote: true,
      user: { select: { email: true } },
    },
  });
  if (rows.length === 0) process.stdout.write(`No ${status.toLowerCase()} withdrawals.\n`);
  for (const w of rows) {
    const amount = `${(Number(w.amountMinor) / 100).toFixed(2)} ${w.currency}`;
    process.stdout.write(
      `${w.id} ${w.createdAt.toISOString()} ${w.user.email}: ${amount} (${w.cherries.toString()} cherries)` +
        ` to ${JSON.stringify(w.payoutDetails)}${w.decisionNote ? ` — ${w.decisionNote}` : ''}\n`,
    );
  }
}

async function withdrawalDecide(withdrawalId: string, pay: boolean, text: string | null): Promise<void> {
  const now = new Date();
  const done = await prisma.$transaction(async (tx) => {
    const [w] = await tx.$queryRaw<{ id: string; user_id: string; status: string; cherries: bigint }[]>`
      SELECT id::text AS id, user_id::text AS user_id, status::text AS status, cherries
        FROM cherry_withdrawals WHERE id = ${withdrawalId}::uuid FOR UPDATE`;
    if (!w) fail(`No withdrawal ${withdrawalId}.`);
    if (w.status !== 'PENDING') fail(`Withdrawal ${withdrawalId} is ${w.status}; nothing changed.`);
    await tx.cherryWithdrawal.update({
      where: { id: withdrawalId },
      data: { status: pay ? 'PAID' : 'REJECTED', decidedAt: now, decisionNote: text },
    });
    if (!pay) await refundCherriesIn(tx, w.user_id, w.cherries, withdrawalId, now);
    await tx.auditLog.create({
      data: {
        action: pay ? AuditAction.CHERRY_WITHDRAWAL_PAY : AuditAction.CHERRY_WITHDRAWAL_REJECT,
        targetType: 'cherry_withdrawal',
        targetId: withdrawalId,
        metadata: { user: w.user_id, cherries: Number(w.cherries), note: text, via: 'cli' },
      },
    });
    return w;
  });
  process.stdout.write(
    `Withdrawal ${withdrawalId}: ${pay ? 'PAID' : `REJECTED, ${done.cherries.toString()} cherries given back`}.\n`,
  );
}

async function reverseGift(giftId: string, text: string | null): Promise<void> {
  const now = new Date();
  const result = await prisma.$transaction(async (tx) => {
    const r = await reverseGiftCherriesIn(tx, giftId, now);
    if (r.reversed) {
      await tx.auditLog.create({
        data: {
          action: AuditAction.CHERRY_GIFT_REVERSE,
          targetType: 'live_gift',
          targetId: giftId,
          metadata: { rows: r.rows, cherries: Number(r.cherries), note: text, via: 'cli' },
        },
      });
    }
    return r;
  });
  process.stdout.write(
    result.reversed
      ? `Send ${giftId}: ${String(result.rows)} credits reversed (${result.cherries.toString()} cherries).\n`
      : `Send ${giftId}: nothing to reverse (no cherries, or reversed before).\n`,
  );
}

async function balance(email: string | undefined): Promise<void> {
  const user = await userByEmail(email);
  const wallet = await prisma.cherryWallet.findUnique({
    where: { userId: user.id },
    select: { cherries: true },
  });
  process.stdout.write(`${email ?? ''}: ${(wallet?.cherries ?? 0n).toString()} cherries.\n`);
}

const { values, positionals } = parseArgs({
  args: process.argv.slice(2),
  allowPositionals: true,
  strict: true,
  options: {
    parent: { type: 'string' },
    to: { type: 'string' },
    note: { type: 'string' },
    status: { type: 'string' },
    all: { type: 'boolean' },
  },
});
const [command, a, b] = positionals;
try {
  if (command === 'agency-create') await agencyCreate(a, values.parent);
  else if (command === 'agency-parent') await agencyParent(a, b);
  else if (command === 'agency-list') await agencyList();
  else if (command === 'agency-evaluate') await agencyEvaluate();
  else if (command === 'complaints') await complaints(values.all === true);
  else if (command === 'complaint-resolve')
    await complaintResolve(id(a, 'The complaint'), b, values.to, note(values.note, false));
  else if (command === 'withdrawals') await withdrawals(values.status);
  else if (command === 'withdrawal-pay')
    await withdrawalDecide(id(a, 'The withdrawal'), true, note(values.note, false));
  else if (command === 'withdrawal-reject')
    await withdrawalDecide(id(a, 'The withdrawal'), false, note(values.note, true));
  else if (command === 'reverse-gift') await reverseGift(id(a, 'The send'), note(values.note, false));
  else if (command === 'balance') await balance(a);
  else fail(USAGE);
} finally {
  await prisma.$disconnect();
}
