/**
 * «الدعوات» from the command line (v1.74-social, D217, CONVENTIONS §10.71): the referrals of «دعوة الأصدقاء» and the
 * programme's settings. The same rules as the panel's «الدعوات» (referral-core.ts), audited with `via: cli`. Runs as
 * the MIGRATION role (MIGRATION_DATABASE_URL), like `recharge-admin`: on the server
 * `docker compose --profile jobs run --rm migrate node dist/cli/referral-admin.js …`, locally `pnpm referral:admin …`.
 *
 *   pnpm referral:admin list [--status pending|qualified|rejected|void]
 *   pnpm referral:admin view <referral id>
 *   pnpm referral:admin approve <referral id> --reason <text>     # credits its rewards now
 *   pnpm referral:admin void <referral id> --reason <text>        # voids its pending rewards
 *   pnpm referral:admin settings                                   # prints the settings
 *   pnpm referral:admin settings --set key=value [--set …] --reason <text>
 *       keys: enabled (true|false), inviterSignupCherries, inviteeSignupCherries, firstRechargeBps,
 *             milestones (friends:cherries,… e.g. 1:50000,5:300000,15:1000000), dailySignupCap, holdHours,
 *             applyWindowDays, selfIpWindowHours
 *   pnpm referral:admin sweep                                      # one sweeper step now
 *
 * A bad argument or a refused action exits 1 (nothing changed).
 */
import 'dotenv/config';
import { parseArgs } from 'node:util';
import { PrismaPg } from '@prisma/adapter-pg';
import { PrismaClient, type ReferralStatus } from '../generated/prisma/client.js';
import {
  approveReferralIn,
  ReferralAdminError,
  referralSettingsIn,
  settingsJson,
  sweepReferrals,
  updateReferralSettingsIn,
  voidReferralIn,
} from '../modules/referrals/referral-core.js';
import { referralSettingsPatch } from '../modules/referrals/referral-rules.js';

function fail(message: string): never {
  process.stderr.write(`${message}\n`);
  process.exit(1);
}

const USAGE = [
  'Usage: pnpm referral:admin list [--status pending|qualified|rejected|void]',
  '       pnpm referral:admin view <referral id>',
  '       pnpm referral:admin approve|void <referral id> --reason <text>',
  '       pnpm referral:admin settings [--set key=value …] [--reason <text>]',
  '       pnpm referral:admin sweep',
].join('\n');

const url = process.env.MIGRATION_DATABASE_URL;
if (!url) fail('MIGRATION_DATABASE_URL is not set (the migration role credits cherries).');
const prisma = new PrismaClient({ adapter: new PrismaPg({ connectionString: url, max: 1 }) });

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
function id(raw: string | undefined): string {
  if (!raw || !UUID.test(raw)) fail(`A referral id (UUID) is required.\n${USAGE}`);
  return raw.toLowerCase();
}

function text(raw: string | undefined, what: string): string {
  const value = (raw ?? '').trim();
  if (value === '') fail(`${what} is required.`);
  if ([...value].length > 500) fail(`${what} is at most 500 characters.`);
  return value;
}

async function run<T>(fn: () => Promise<T>): Promise<T> {
  try {
    return await fn();
  } catch (err) {
    if (err instanceof ReferralAdminError) fail(err.message);
    throw err;
  }
}

/** `--set key=value` pairs → the settings patch (validated by the same schema as the panel). */
function parseSets(sets: readonly string[]): Record<string, unknown> {
  const out: Record<string, unknown> = {};
  for (const pair of sets) {
    const eq = pair.indexOf('=');
    if (eq <= 0) fail(`--set needs key=value: ${pair}`);
    const key = pair.slice(0, eq).trim();
    const raw = pair.slice(eq + 1).trim();
    if (key === 'enabled') {
      if (raw !== 'true' && raw !== 'false') fail('enabled is true or false.');
      out[key] = raw === 'true';
    } else if (key === 'milestones') {
      out[key] =
        raw === ''
          ? []
          : raw.split(',').map((m) => {
              const [friends, cherries] = m.split(':');
              return { friends: Number(friends), cherries: cherries ?? '' };
            });
    } else if (key === 'inviterSignupCherries' || key === 'inviteeSignupCherries') {
      out[key] = raw;
    } else {
      out[key] = Number(raw);
    }
  }
  return out;
}

async function list(status: string | undefined): Promise<void> {
  const wanted = status === undefined ? undefined : (status.toUpperCase() as ReferralStatus);
  if (wanted !== undefined && !['PENDING', 'QUALIFIED', 'REJECTED', 'VOID'].includes(wanted)) fail(USAGE);
  const rows = await prisma.referral.findMany({
    where: wanted ? { status: wanted } : {},
    orderBy: { createdAt: 'desc' },
    take: 500,
    select: {
      id: true,
      status: true,
      source: true,
      rejectReason: true,
      voidReason: true,
      createdAt: true,
      inviter: { select: { profile: { select: { username: true } } } },
      invitee: { select: { profile: { select: { username: true } } } },
    },
  });
  for (const r of rows) {
    const why = r.rejectReason ?? r.voidReason;
    process.stdout.write(
      `${r.id}  ${r.status.padEnd(9)}  ${r.source.padEnd(6)}  @${r.inviter.profile?.username ?? '?'} → @${
        r.invitee.profile?.username ?? '?'
      }  ${r.createdAt.toISOString()}${why ? `  (${why})` : ''}\n`,
    );
  }
  if (rows.length === 0) process.stdout.write('No referrals.\n');
}

async function view(referralId: string): Promise<void> {
  const r = await prisma.referral.findUnique({
    where: { id: referralId },
    include: {
      rewards: { orderBy: { createdAt: 'asc' } },
      inviter: { select: { profile: { select: { username: true } } } },
      invitee: { select: { profile: { select: { username: true } } } },
    },
  });
  if (!r) fail(`No referral ${referralId}.`);
  process.stdout.write(
    [
      `Referral ${r.id}: ${r.status} (${r.source}, code ${r.code})`,
      `Inviter: @${r.inviter.profile?.username ?? '?'}  Invitee: @${r.invitee.profile?.username ?? '?'}`,
      `Created ${r.createdAt.toISOString()}, hold until ${r.holdUntil.toISOString()}`,
      `Reject reason: ${r.rejectReason ?? '-'}  Void reason: ${r.voidReason ?? '-'}`,
      `First recharge: ${r.firstRechargeAt?.toISOString() ?? '-'}`,
      ...r.rewards.map(
        (w) =>
          `  reward ${w.id}  ${w.kind.padEnd(14)} ${w.status.padEnd(8)} ${w.cherries} cherries${
            w.voidReason ? `  (${w.voidReason})` : ''
          }`,
      ),
      '',
    ].join('\n'),
  );
  await prisma.auditLog.create({
    data: { action: 'referral.view', targetType: 'referral', targetId: r.id, metadata: { via: 'cli' } },
  });
}

try {
  const { positionals, values } = parseArgs({
    args: process.argv.slice(2),
    allowPositionals: true,
    options: {
      status: { type: 'string' },
      reason: { type: 'string' },
      set: { type: 'string', multiple: true },
    },
  });
  const [command, a] = positionals;
  const now = new Date();
  switch (command) {
    case 'list':
      await list(values.status);
      break;
    case 'view':
      await view(id(a));
      break;
    case 'approve': {
      const rid = id(a);
      const reason = text(values.reason, '--reason');
      const r = await run(() => prisma.$transaction((tx) => approveReferralIn(tx, rid, reason, now)));
      process.stdout.write(
        r.changed ? `Approved: ${r.credited} cherries credited.\n` : 'Already qualified; nothing changed.\n',
      );
      break;
    }
    case 'void': {
      const rid = id(a);
      const reason = text(values.reason, '--reason');
      const r = await run(() => prisma.$transaction((tx) => voidReferralIn(tx, rid, reason, now)));
      process.stdout.write(
        r.changed
          ? `Voided: ${r.voidedRewards} pending reward(s) voided; ${r.reversedCherries} credited cherries taken back` +
              (r.shortfall > 0n ? ` (${r.shortfall} not covered by the balance: a debt).\n` : '.\n')
          : 'Already void; nothing changed.\n',
      );
      break;
    }
    case 'settings': {
      const sets = values.set ?? [];
      if (sets.length > 0) {
        const parsed = referralSettingsPatch.safeParse(parseSets(sets));
        if (!parsed.success)
          fail(`Invalid settings: ${parsed.error.issues.map((i) => i.path.join('.')).join(', ')}`);
        const reason = text(values.reason, '--reason');
        await prisma.$transaction((tx) => updateReferralSettingsIn(tx, parsed.data, reason, now));
      }
      process.stdout.write(`${JSON.stringify(settingsJson(await referralSettingsIn(prisma)), null, 2)}\n`);
      break;
    }
    case 'sweep': {
      const r = await sweepReferrals(prisma, now);
      process.stdout.write(
        `Qualified ${r.qualified}, voided ${r.voided}; rewards credited ${r.credited}, voided ${r.rewardsVoided}; milestone cherries ${r.milestoneCherries}.\n`,
      );
      break;
    }
    default:
      fail(USAGE);
  }
} catch (err) {
  if (err instanceof TypeError) fail(`${err.message}\n${USAGE}`);
  throw err;
} finally {
  await prisma.$disconnect();
}
