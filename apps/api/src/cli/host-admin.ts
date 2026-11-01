/**
 * «طلبات المضيفين» from the command line (v1.73-social, D209, CONVENTIONS §10.68): the applications «كن مضيفاً مع
 * الإدارة» — people who apply to host directly with the Kabso team. The team lists them, reads one (private: every
 * view is audited), approves (the hosting permission, `live_hosts` source IDENTITY, the applicant notified) or rejects
 * with a reason (the applicant sees it and may apply again after HOST_APPLICATION_REAPPLY_DAYS). The same rules as
 * the panel's «طلبات المضيفين» (host-applications.core.ts), audited with `via: cli`. Runs as the MIGRATION role
 * (MIGRATION_DATABASE_URL), like `recharge-admin`: on the server
 * `docker compose --profile jobs run --rm migrate node dist/cli/host-admin.js …`, locally `pnpm host:admin …`.
 * Saving the private pictures needs the API's `S3_*` settings.
 *
 *   pnpm host:admin applications [--status pending|approved|rejected|cancelled]
 *   pnpm host:admin view <application id> [--save <dir>]     # audited; --save writes the two pictures
 *   pnpm host:admin approve <application id>
 *   pnpm host:admin reject <application id> --reason <text>
 *
 * A bad argument or a refused action exits 1 (nothing changed).
 */
import 'dotenv/config';
import { mkdirSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { parseArgs } from 'node:util';
import { PrismaPg } from '@prisma/adapter-pg';
import { PrismaClient, type HostApplicationStatus } from '../generated/prisma/client.js';
import { AuditAction } from '../common/audit/audit.service.js';
import type { AppConfig } from '../config/app-config.js';
import type { ObjectStorage } from '../modules/media/object-storage.js';
import { S3ObjectStorage } from '../modules/media/s3-object-storage.js';
import {
  ageOn,
  approveHostApplicationIn,
  HostApplicationError,
  rejectHostApplicationIn,
} from '../modules/host-applications/host-applications.core.js';

function fail(message: string): never {
  process.stderr.write(`${message}\n`);
  process.exit(1);
}

const USAGE = [
  'Usage: pnpm host:admin applications [--status pending|approved|rejected|cancelled]',
  '       pnpm host:admin view <application id> [--save <dir>]',
  '       pnpm host:admin approve <application id> | reject <application id> --reason <text>',
].join('\n');

const url = process.env.MIGRATION_DATABASE_URL;
if (!url) fail('MIGRATION_DATABASE_URL is not set (the migration role gives the hosting permission).');
const prisma = new PrismaClient({ adapter: new PrismaPg({ connectionString: url, max: 1 }) });

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

async function run<T>(fn: () => Promise<T>): Promise<T> {
  try {
    return await fn();
  } catch (err) {
    if (err instanceof HostApplicationError) fail(err.message);
    throw err;
  }
}

async function applications(status: string | undefined): Promise<void> {
  const wanted = status === undefined ? undefined : (status.toUpperCase() as HostApplicationStatus);
  if (wanted !== undefined && !['PENDING', 'APPROVED', 'REJECTED', 'CANCELLED'].includes(wanted)) fail(USAGE);
  const rows = await prisma.hostApplication.findMany({
    where: wanted ? { status: wanted } : {},
    orderBy: { createdAt: 'asc' },
    take: 500,
    select: {
      id: true,
      status: true,
      country: true,
      createdAt: true,
      purgedAt: true,
      user: { select: { profile: { select: { username: true } } } },
    },
  });
  // A list shows no private field (only `view` does, audited).
  for (const r of rows) {
    process.stdout.write(
      `${r.id}  ${r.status.padEnd(9)}  ${r.country}  @${r.user.profile?.username ?? '?'}  ${r.createdAt.toISOString()}${
        r.purgedAt ? '  (purged)' : ''
      }\n`,
    );
  }
  if (rows.length === 0) process.stdout.write('No applications.\n');
}

async function view(applicationId: string, saveDir: string | undefined): Promise<void> {
  const app = await prisma.hostApplication.findUnique({
    where: { id: applicationId },
    include: {
      user: {
        select: { email: true, createdAt: true, status: true, profile: { select: { username: true } } },
      },
    },
  });
  if (!app) fail(`No application ${applicationId}.`);
  await prisma.auditLog.create({
    data: {
      action: AuditAction.HOST_APPLICATION_VIEW,
      targetType: 'host_application',
      targetId: app.id,
      metadata: { saved: saveDir !== undefined, via: 'cli', operator: process.env.USER ?? null },
    },
  });
  const now = new Date();
  const out = [
    `Application ${app.id} (${app.status}) by @${app.user.profile?.username ?? '?'} <${app.user.email}>`,
    `Account ${app.user.status}, created ${app.user.createdAt.toISOString()}`,
    `Submitted ${app.createdAt.toISOString()}${app.decidedAt ? `, decided ${app.decidedAt.toISOString()}` : ''}`,
    `Display name: ${app.displayName}`,
    `Country: ${app.country}`,
  ];
  if (app.purgedAt) {
    out.push(`Private data deleted ${app.purgedAt.toISOString()} (account deletion).`);
  } else {
    if (app.dateOfBirth) {
      out.push(
        `Date of birth: ${app.dateOfBirth.toISOString().slice(0, 10)} (age ${ageOn(app.dateOfBirth, now)})`,
      );
    }
    out.push(`Contact (${app.contactType}): ${app.contactValue ?? ''}`, `Bio: ${app.bio ?? ''}`);
    for (const link of app.links) out.push(`Link: ${link}`);
    out.push(`ID card: ${app.photoKey ?? ''}`, `Selfie: ${app.selfieKey ?? ''}`);
  }
  out.push(`Host rules accepted ${app.rulesAcceptedAt.toISOString()}`);
  if (app.rejectReason) out.push(`Reject reason: ${app.rejectReason}`);
  if (app.cancelReason) out.push(`Cancelled: ${app.cancelReason}`);
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
    },
  });
  const [command, a] = positionals;
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
      const r = await run(() => prisma.$transaction((tx) => approveHostApplicationIn(tx, appId, now)));
      process.stdout.write(`Approved: the person may go live (hosting permission ${r.source}); notified.\n`);
      break;
    }
    case 'reject': {
      const appId = id(a);
      const reason = text(values.reason, '--reason');
      await run(() => prisma.$transaction((tx) => rejectHostApplicationIn(tx, appId, reason, now)));
      process.stdout.write('Rejected; the person sees the reason and may apply again later.\n');
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
