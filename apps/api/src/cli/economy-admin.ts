/**
 * The cherry economy's administration from the command line (v1.52-social, D179, CONVENTIONS §10.46). There
 * is no admin UI: the team creates host agencies, links sub-agencies to their parent, resolves hosts'
 * complaints, pays or rejects withdrawal requests (no payment provider yet: the money is sent by hand)
 * and reverses a send's cherries. Runs as the MIGRATION role (MIGRATION_DATABASE_URL), like `wallet-admin`:
 * on the server `docker compose --profile jobs run --rm migrate node dist/cli/economy-admin.js …`
 * (docs/DEPLOYMENT.md), locally `pnpm economy:admin …`.
 *
 *   pnpm economy:admin agency-create <owner email> [--parent <invite code>]   # prints the invite and host codes
 *   pnpm economy:admin agency-suspend <invite code> --note <reason>   # v1.58 (D189): the host agent's perks go
 *   pnpm economy:admin agency-reinstate <invite code>                 # … and come back
 *   pnpm economy:admin agency-parent <invite code> <parent invite code | none>
 *   pnpm economy:admin agency-list
 *   pnpm economy:admin agency-evaluate        # the rank evaluation and the active-host frames now (what the sweeper does)
 *   pnpm economy:admin agency-probation-extend <invite code> <days> --note <reason>   # v1.70 (D206)
 *   pnpm economy:admin agency-close <invite code> --note <reason>    # hosts released, the owner told
 *   pnpm economy:admin agency-reopen <invite code> --note <reason>   # a self-opened agency gets a new probation
 *   pnpm economy:admin agency-probation-sweep  # settles the running probations now (what the sweeper does)
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
import { createAgencyByAdmin, resolveComplaintIn } from '../modules/economy/agency-admin.js';
import {
  closeAgencyByAdminIn,
  extendProbationIn,
  reopenAgencyIn,
  sweepAgencyProbations,
  type ProbationRules,
} from '../modules/economy/agency-probation.js';
import { evaluateAgencyRanks } from '../modules/economy/agency-ranks.js';
import { HostAgentError, reinstateHostAgentIn, suspendHostAgentIn } from '../modules/economy/host-agents.js';
import { syncHostFrames, type HostFrameChange } from '../modules/economy/host-frames.js';
import { reverseGiftCherriesIn } from '../modules/economy/cherry-ledger.js';
import {
  decideWithdrawalIn,
  WithdrawalAdminError,
  type WithdrawalDecision,
} from '../modules/economy/withdrawal-admin.js';
import { dateValue, monthKey, normalizeInviteCode } from '../modules/economy/economy-math.js';

function fail(message: string): never {
  process.stderr.write(`${message}\n`);
  process.exit(1);
}

const USAGE = [
  'Usage: pnpm economy:admin agency-create <owner email> [--parent <invite code>]',
  '       pnpm economy:admin agency-suspend <invite code> --note <reason> | agency-reinstate <invite code>',
  '       pnpm economy:admin agency-parent <invite code> <parent invite code | none>',
  '       pnpm economy:admin agency-list | agency-evaluate | agency-probation-sweep',
  '       pnpm economy:admin agency-probation-extend <invite code> <days> --note <reason>',
  '       pnpm economy:admin agency-close <invite code> --note <reason> | agency-reopen <invite code> --note <reason>',
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
const graceDays = () => setting('SPECIAL_USERNAME_GRACE_DAYS') as number;

/** v1.58-social (D189): a refused host-agent step exits 1 with its message (nothing changed). */
async function hostAgentStep<T>(step: () => Promise<T>): Promise<T> {
  try {
    return await step();
  } catch (err) {
    if (err instanceof HostAgentError) fail(err.message);
    throw err;
  }
}

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
  // v1.65-social (D197): the rule lives in agency-admin.ts, shared with the admin panel.
  const created = await hostAgentStep(() =>
    createAgencyByAdmin(
      prisma,
      { ownerUserId: owner.id, parentInviteCode: parentCode ?? null },
      { timeZone: zone(), specialGraceDays: graceDays() },
    ),
  );
  process.stdout.write(
    `Agency ${created.agencyId} for ${email ?? ''}: invite code ${created.inviteCode}, host code ${created.hostCode}` +
      ` (evaluated from ${created.evaluateFrom}).\n`,
  );
}

/** v1.58-social (D189): `agency-suspend` / `agency-reinstate` — the host agent's perks only. */
async function agencySuspend(
  code: string | undefined,
  suspend: boolean,
  reason: string | null,
): Promise<void> {
  const agency = await agencyByCode(code);
  const now = new Date();
  await hostAgentStep(() =>
    prisma.$transaction((tx) =>
      suspend
        ? suspendHostAgentIn(tx, agency.id, reason!, now, graceDays())
        : reinstateHostAgentIn(tx, agency.id, now, graceDays()),
    ),
  );
  process.stdout.write(
    `${agency.inviteCode}: host agent ${suspend ? 'suspended (perks removed)' : 'reinstated (perks back)'}.\n`,
  );
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
      hostCode: true,
      suspendedAt: true,
      name: true,
      status: true,
      probationEndsAt: true,
      probationPassedAt: true,
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
        ` host code ${a.hostCode ?? '-'}${a.suspendedAt ? ' (SUSPENDED)' : ''}` +
        `${a.name ? ` name ${JSON.stringify(a.name)}` : ''}${a.status === 'CLOSED' ? ' (CLOSED)' : ''}` +
        `${a.probationEndsAt && !a.probationPassedAt && a.status === 'OPEN' ? ` probation until ${a.probationEndsAt.toISOString()}` : ''}` +
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

/** v1.70-social (D206): the probation rules from the environment. */
function probationRules(): ProbationRules {
  return {
    probationDays: setting('AGENCY_PROBATION_DAYS') as number,
    probationMinHosts: setting('AGENCY_PROBATION_MIN_HOSTS') as number,
    probationReminderHours: setting('AGENCY_PROBATION_REMINDER_HOURS') as number,
    reopenCooldownDays: setting('AGENCY_REOPEN_COOLDOWN_DAYS') as number,
  };
}

async function syncReleased(hosts: readonly string[]): Promise<void> {
  if (hosts.length === 0) return;
  for (const f of await syncHostFrames(prisma, new Date(), activityRules(), zone(), hosts))
    process.stdout.write(`${hostFrameLine(f)}\n`);
}

/** v1.70-social (D206, §10.65): `agency-probation-extend`, `agency-close`, `agency-reopen`, `agency-probation-sweep`. */
async function agencyProbation(
  op: 'extend' | 'close' | 'reopen',
  code: string | undefined,
  daysRaw: string | undefined,
  reason: string,
): Promise<void> {
  const agency = await agencyByCode(code);
  const now = new Date();
  if (op === 'extend') {
    const days = Number(daysRaw);
    if (!Number.isInteger(days) || days < 1 || days > 90) fail('days must be a whole number 1–90.');
    const r = await hostAgentStep(() =>
      prisma.$transaction((tx) => extendProbationIn(tx, agency.id, days, reason, now)),
    );
    process.stdout.write(`${agency.inviteCode}: probation now ends ${r.endsAt}.\n`);
  } else if (op === 'close') {
    const r = await hostAgentStep(() =>
      prisma.$transaction((tx) => closeAgencyByAdminIn(tx, agency.id, reason, now, graceDays())),
    );
    process.stdout.write(`${agency.inviteCode}: CLOSED, ${String(r.releasedHosts.length)} hosts released.\n`);
    await syncReleased(r.releasedHosts);
  } else {
    const r = await hostAgentStep(() =>
      prisma.$transaction((tx) => reopenAgencyIn(tx, agency.id, reason, now, probationRules(), graceDays())),
    );
    process.stdout.write(
      `${agency.inviteCode}: OPEN${r.probationEndsAt ? `, probation until ${r.probationEndsAt}` : ''}.\n`,
    );
  }
}

async function agencyProbationSweep(): Promise<void> {
  const r = await sweepAgencyProbations(prisma, new Date(), probationRules(), graceDays());
  process.stdout.write(
    `Probations: ${String(r.passed.length)} passed, ${String(r.closed.length)} closed, ` +
      `${String(r.reminded.length)} reminded.\n`,
  );
  for (const x of r.passed) process.stdout.write(`passed ${x}\n`);
  for (const x of r.closed) process.stdout.write(`closed ${x}\n`);
  await syncReleased(r.releasedHosts);
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
  if (action === 'move' && to === undefined) fail('move needs --to <invite code>.');
  // v1.65-social (D197): the rule lives in agency-admin.ts, shared with the admin panel.
  const result = await hostAgentStep(() =>
    prisma.$transaction((tx) => resolveComplaintIn(tx, complaintId, action, to ?? null, text, new Date())),
  );
  process.stdout.write(`Complaint ${complaintId}: ${action}.\n`);
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
  // v1.60-social (D191): the same rule as the admin panel (modules/economy/withdrawal-admin.ts).
  let done: WithdrawalDecision;
  try {
    done = await prisma.$transaction((tx) => decideWithdrawalIn(tx, withdrawalId, pay, text, new Date()));
  } catch (err) {
    if (err instanceof WithdrawalAdminError) fail(err.message);
    throw err;
  }
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
  else if (command === 'agency-suspend') await agencySuspend(a, true, note(values.note, true));
  else if (command === 'agency-reinstate') await agencySuspend(a, false, null);
  else if (command === 'agency-list') await agencyList();
  else if (command === 'agency-evaluate') await agencyEvaluate();
  else if (command === 'agency-probation-sweep') await agencyProbationSweep();
  else if (command === 'agency-probation-extend')
    await agencyProbation('extend', a, b, note(values.note, true)!);
  else if (command === 'agency-close') await agencyProbation('close', a, undefined, note(values.note, true)!);
  else if (command === 'agency-reopen')
    await agencyProbation('reopen', a, undefined, note(values.note, true)!);
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
