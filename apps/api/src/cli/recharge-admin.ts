/**
 * Recharge agents «وكلاء الشحن» from the command line (v1.54-social, D185, CONVENTIONS §10.48). There is no admin
 * UI: the team reads applications (private: every view is audited), approves or rejects them, records the
 * wholesale top-ups paid outside the app (the first one ≥ 30 000 000 coins activates the agent and gives the
 * next code `coin0001` …, which also becomes their username — special, locked), suspends and reinstates agents, sets an agent's daily cherry cap and runs the
 * retention step. Runs as the MIGRATION role (MIGRATION_DATABASE_URL), like `economy-admin`: on the server
 * `docker compose --profile jobs run --rm migrate node dist/cli/recharge-admin.js …`, locally
 * `pnpm recharge:admin …`. Reading or deleting the private pictures needs the API's `S3_*` settings.
 *
 *   pnpm recharge:admin applications [--status pending|approved|rejected]
 *   pnpm recharge:admin view <application id> [--save <dir>]     # audited; --save writes the two pictures
 *   pnpm recharge:admin approve <application id>
 *   pnpm recharge:admin reject <application id> --reason <text>
 *   pnpm recharge:admin topup <agent> <coins> --paid <USD> [--note <text>]
 *   pnpm recharge:admin suspend <agent> --reason <text>
 *   pnpm recharge:admin reinstate <agent>
 *   pnpm recharge:admin set-cap <agent> <cherries | 0 | default>   # 0 = no cap; default = the server's (none)
 *   pnpm recharge:admin agents
 *   pnpm recharge:admin purge                                    # the retention step now
 *
 * `<agent>` is a code (`coin0001`), an email or a username. Every change writes an audit row in its
 * transaction; a bad argument or a refused action exits 1 (nothing changed).
 */
import 'dotenv/config';
import { mkdirSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { parseArgs } from 'node:util';
import { PrismaPg } from '@prisma/adapter-pg';
import { PrismaClient, type RechargeApplicationStatus } from '../generated/prisma/client.js';
import { AuditAction } from '../common/audit/audit.service.js';
import type { AppConfig } from '../config/app-config.js';
import { envSchema } from '../config/env.schema.js';
import type { ObjectStorage } from '../modules/media/object-storage.js';
import { S3ObjectStorage } from '../modules/media/s3-object-storage.js';
import {
  approveApplicationIn,
  purgeApplications,
  RechargeAdminError,
  reinstateIn,
  rejectApplicationIn,
  setCapIn,
  suspendIn,
  topUpIn,
} from '../modules/recharge/recharge-core.js';
import { normalizeAgentCode, parseMoneyMinor } from '../modules/recharge/recharge-rules.js';

function fail(message: string): never {
  process.stderr.write(`${message}\n`);
  process.exit(1);
}

const USAGE = [
  'Usage: pnpm recharge:admin applications [--status pending|approved|rejected]',
  '       pnpm recharge:admin view <application id> [--save <dir>]',
  '       pnpm recharge:admin approve <application id> | reject <application id> --reason <text>',
  '       pnpm recharge:admin topup <agent> <coins> --paid <USD> [--note <text>]',
  '       pnpm recharge:admin suspend <agent> --reason <text> | reinstate <agent>',
  '       pnpm recharge:admin set-cap <agent> <cherries | 0 | default>',
  '       pnpm recharge:admin agents | purge',
].join('\n');

const url = process.env.MIGRATION_DATABASE_URL;
if (!url) fail('MIGRATION_DATABASE_URL is not set (the migration role changes balances).');
const prisma = new PrismaClient({ adapter: new PrismaPg({ connectionString: url, max: 1 }) });

function setting<K extends keyof typeof envSchema.shape>(key: K): unknown {
  const parsed = envSchema.shape[key].safeParse(process.env[key]);
  if (!parsed.success) fail(`${key} is invalid: ${parsed.error.issues[0]?.message ?? 'bad value'}`);
  return parsed.data;
}

/** D185 (§10.48.1): how long a special username stays the person's after it ends. */
function graceDays(): number {
  return setting('SPECIAL_USERNAME_GRACE_DAYS') as number;
}

function storageFromEnv(): ObjectStorage | null {
  const e = process.env;
  if (!e.S3_BUCKET || !e.S3_ACCESS_KEY_ID || !e.S3_SECRET_ACCESS_KEY) return null;
  const media = {
    s3: {
      endpoint: e.S3_ENDPOINT || undefined,
      region: e.S3_REGION || 'auto',
      bucket: e.S3_BUCKET,
      accessKeyId: e.S3_ACCESS_KEY_ID,
      secretAccessKey: e.S3_SECRET_ACCESS_KEY,
      forcePathStyle: e.S3_FORCE_PATH_STYLE === 'true',
    },
  };
  return new S3ObjectStorage({ media } as unknown as AppConfig);
}

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
function id(raw: string | undefined): string {
  if (!raw || !UUID.test(raw)) fail(`An application id (UUID) is required.\n${USAGE}`);
  return raw.toLowerCase();
}

function text(raw: string | undefined, what: string): string {
  const value = (raw ?? '').trim();
  if (value === '') fail(`${what} is required.`);
  if ([...value].length > 500) fail(`${what} is at most 500 characters.`);
  return value;
}

/** An agent by code, email or username → its user id. */
async function agentId(raw: string | undefined): Promise<string> {
  if (!raw) fail(USAGE);
  const code = normalizeAgentCode(raw);
  if (code !== null) {
    const a = await prisma.rechargeAgent.findUnique({ where: { code }, select: { userId: true } });
    if (!a) fail(`No agent ${code}.`);
    return a.userId;
  }
  const value = raw.trim().replace(/^@/, '').toLowerCase();
  const user = value.includes('@')
    ? await prisma.user.findUnique({ where: { email: value }, select: { id: true } })
    : await prisma.userProfile
        .findUnique({ where: { username: value }, select: { userId: true } })
        .then((p) => (p ? { id: p.userId } : null));
  if (!user) fail(`No user ${raw}.`);
  return user.id;
}

async function run<T>(fn: () => Promise<T>): Promise<T> {
  try {
    return await fn();
  } catch (err) {
    if (err instanceof RechargeAdminError) fail(err.message);
    throw err;
  }
}

async function applications(status: string | undefined): Promise<void> {
  const wanted = status === undefined ? undefined : (status.toUpperCase() as RechargeApplicationStatus);
  if (wanted !== undefined && !['PENDING', 'APPROVED', 'REJECTED'].includes(wanted)) fail(USAGE);
  const rows = await prisma.rechargeAgentApplication.findMany({
    where: wanted ? { status: wanted } : {},
    orderBy: { createdAt: 'asc' },
    take: 500,
    select: {
      id: true,
      status: true,
      createdAt: true,
      purgedAt: true,
      user: { select: { profile: { select: { username: true } } } },
    },
  });
  // A list shows no private field (only `view` does, audited).
  for (const r of rows) {
    process.stdout.write(
      `${r.id}  ${r.status.padEnd(8)}  @${r.user.profile?.username ?? '?'}  ${r.createdAt.toISOString()}${
        r.purgedAt ? '  (purged)' : ''
      }\n`,
    );
  }
  if (rows.length === 0) process.stdout.write('No applications.\n');
}

async function view(applicationId: string, saveDir: string | undefined): Promise<void> {
  const app = await prisma.rechargeAgentApplication.findUnique({
    where: { id: applicationId },
    include: { user: { select: { email: true, profile: { select: { username: true } } } } },
  });
  if (!app) fail(`No application ${applicationId}.`);
  await prisma.auditLog.create({
    data: {
      action: AuditAction.RECHARGE_APPLICATION_VIEW,
      targetType: 'recharge_application',
      targetId: app.id,
      metadata: { saved: saveDir !== undefined, via: 'cli', operator: process.env.USER ?? null },
    },
  });
  const out = [
    `Application ${app.id} (${app.status}) by @${app.user.profile?.username ?? '?'} <${app.user.email}>`,
    `Submitted ${app.createdAt.toISOString()}${app.decidedAt ? `, decided ${app.decidedAt.toISOString()}` : ''}`,
  ];
  if (app.purgedAt) {
    out.push(`Private data deleted ${app.purgedAt.toISOString()} (retention).`);
  } else {
    out.push(`Full name: ${app.fullName ?? ''}`, `Phone (WhatsApp): ${app.phone ?? ''}`);
    out.push(`Locations: ${JSON.stringify(app.locations)}`);
    out.push(`Payment methods: ${JSON.stringify(app.paymentMethods)}`);
    out.push(`Photo: ${app.photoKey ?? ''}`, `Selfie (face confirmation): ${app.selfieKey ?? ''}`);
  }
  if (app.rejectReason) out.push(`Reject reason: ${app.rejectReason}`);
  process.stdout.write(`${out.join('\n')}\n`);
  if (saveDir !== undefined && !app.purgedAt) {
    const storage = storageFromEnv();
    if (!storage) fail('S3 is not configured here; the pictures cannot be saved.');
    mkdirSync(saveDir, { recursive: true, mode: 0o700 });
    for (const [name, key] of [
      ['photo', app.photoKey],
      ['selfie', app.selfieKey],
    ] as const) {
      const bytes = key ? await storage.get(key, 16 * 1024 * 1024) : null;
      if (!bytes) {
        process.stdout.write(`${name}: missing in storage\n`);
        continue;
      }
      const file = join(saveDir, `${app.id}-${name}.webp`);
      writeFileSync(file, bytes, { mode: 0o600 });
      process.stdout.write(`${name}: saved to ${file} (delete it after the review)\n`);
    }
  }
}

try {
  const { positionals, values } = parseArgs({
    args: process.argv.slice(2),
    allowPositionals: true,
    options: {
      status: { type: 'string' },
      save: { type: 'string' },
      reason: { type: 'string' },
      paid: { type: 'string' },
      note: { type: 'string' },
    },
  });
  const [command, a, b] = positionals;
  const now = new Date();
  switch (command) {
    case 'applications':
      await applications(values.status);
      break;
    case 'view':
      await view(id(a), values.save);
      break;
    case 'approve': {
      const appId = id(a);
      await run(() => prisma.$transaction((tx) => approveApplicationIn(tx, appId, now)));
      process.stdout.write(`Approved ${appId}: waiting for the first top-up.\n`);
      break;
    }
    case 'reject': {
      const appId = id(a);
      const reason = text(values.reason, '--reason');
      await run(() => prisma.$transaction((tx) => rejectApplicationIn(tx, appId, reason, now)));
      process.stdout.write(`Rejected ${appId}.\n`);
      break;
    }
    case 'topup': {
      const agent = await agentId(a);
      if (!b || !/^[1-9][0-9]{0,12}$/.test(b)) fail(`<coins> must be a positive integer.\n${USAGE}`);
      const paid = parseMoneyMinor(values.paid ?? '');
      if (paid === null) fail('--paid <USD> is required (e.g. 360 or 360.00).');
      const note = values.note === undefined ? null : text(values.note, '--note');
      const rules = {
        activationMinCoins: setting('RECHARGE_AGENT_ACTIVATION_MIN_COINS') as number,
        priceTiers: setting('RECHARGE_AGENT_PRICE_TIERS') as { minCoins: number; minorPerMillion: number }[],
        currency: 'USD',
      };
      const r = await run(() =>
        prisma.$transaction((tx) => topUpIn(tx, agent, BigInt(b), paid, note, rules, now, graceDays())),
      );
      process.stdout.write(
        `Top-up ${r.topupId}: ${b} coins, tier ${r.tier} (${String(r.minorPerMillion)} cents / 1M, expected ${String(
          r.expectedMinor,
        )} cents, paid ${String(paid)}); stock ${String(r.stock)}.${r.first ? ` ACTIVATED as ${r.code ?? ''}.` : ''}\n`,
      );
      break;
    }
    case 'suspend': {
      const agent = await agentId(a);
      const reason = text(values.reason, '--reason');
      await run(() => prisma.$transaction((tx) => suspendIn(tx, agent, reason, now, graceDays())));
      process.stdout.write(
        'Suspended: no selling, no listing, no frame, badge or entrance; the own username is shown again.\n',
      );
      break;
    }
    case 'reinstate': {
      const agent = await agentId(a);
      const status = await run(() => prisma.$transaction((tx) => reinstateIn(tx, agent, now, graceDays())));
      process.stdout.write(`Reinstated: ${status}.\n`);
      break;
    }
    case 'set-cap': {
      const agent = await agentId(a);
      if (!b || !(b === 'default' || /^[0-9]{1,13}$/.test(b))) fail(USAGE);
      await run(() => prisma.$transaction((tx) => setCapIn(tx, agent, b === 'default' ? null : BigInt(b))));
      process.stdout.write(`Daily cherry cap: ${b === '0' ? 'none' : b}.\n`);
      break;
    }
    case 'agents': {
      const rows = await prisma.rechargeAgent.findMany({
        orderBy: [{ codeNumber: 'asc' }, { approvedAt: 'asc' }],
        select: {
          code: true,
          status: true,
          stockCoins: true,
          dailyCherryCap: true,
          countries: true,
          user: { select: { profile: { select: { username: true } } } },
        },
      });
      for (const r of rows) {
        process.stdout.write(
          `${(r.code ?? '-').padEnd(9)} ${r.status.padEnd(9)} @${r.user.profile?.username ?? '?'}  stock ${String(
            r.stockCoins,
          )}  cap ${r.dailyCherryCap === null ? 'default' : String(r.dailyCherryCap)}  ${r.countries.join(',')}\n`,
        );
      }
      if (rows.length === 0) process.stdout.write('No agents.\n');
      break;
    }
    case 'purge': {
      const storage = storageFromEnv();
      if (!storage) fail('S3 is not configured here; the pictures cannot be deleted.');
      const days = setting('RECHARGE_AGENT_KYC_RETENTION_DAYS') as number;
      const n = await purgeApplications(prisma, (keys) => storage.delete(keys), now, days, 'cli');
      process.stdout.write(`Purged ${String(n)} application(s).\n`);
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
