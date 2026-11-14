/**
 * The personal-data export «تنزيل بياناتي» from the command line (v1.66-social, D198, CONVENTIONS §10.61.1). The
 * person asks in the app (Settings › Privacy); this is the team's tool for a request by email (GDPR Art. 15/20, CCPA)
 * once the team has VERIFIED that the sender owns the account (they write from the account's address and confirm).
 * Runs as the MIGRATION role (MIGRATION_DATABASE_URL), like `account-admin`: on the server
 * `docker compose --profile jobs run --rm migrate node dist/cli/privacy-admin.js …` (docs/DEPLOYMENT.md), locally
 * `pnpm privacy:admin …`.
 *
 *   pnpm privacy:admin exports [<user>]                       the latest export jobs (never their content)
 *   pnpm privacy:admin export <user> --reason <text>          queues an export: the API builds it, the person gets the
 *                                                             notification and the mail and downloads it in the app
 *   pnpm privacy:admin export <user> --reason <text> --save <dir>
 *                                                             builds it now into <dir> (file mode 600) for the team to
 *                                                             send by a secure channel (needs the S3_* settings for the
 *                                                             KYC pictures); the job is recorded as delivered
 *
 * `<user>` is a username, an email or a user id. The 24-hour limit applies as in the app. Every command is audited
 * (`privacy.export.requested` with `via: cli` and the reason; `privacy.export.admin_view` for `exports` and `--save`).
 * Delete a saved file as soon as it has been delivered.
 */
import 'dotenv/config';
import { chmodSync, mkdirSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { parseArgs } from 'node:util';
import { PrismaPg } from '@prisma/adapter-pg';
import { AuditAction } from '../common/audit/audit.service.js';
import type { AppConfig } from '../config/app-config.js';
import { PrismaClient } from '../generated/prisma/client.js';
import type { ObjectStorage } from '../modules/media/object-storage.js';
import { S3ObjectStorage } from '../modules/media/s3-object-storage.js';
import { buildDataExport, nextExportAllowedAt } from '../modules/privacy/data-export.js';

function fail(message: string): never {
  process.stderr.write(`${message}\n`);
  process.exit(1);
}

const USAGE =
  'Usage: pnpm privacy:admin exports [<user>]\n' +
  '       pnpm privacy:admin export <user> --reason <text> [--save <dir>]';

const url = process.env.MIGRATION_DATABASE_URL;
if (!url) fail('MIGRATION_DATABASE_URL is not set (the migration role records the export).');
const prisma = new PrismaClient({ adapter: new PrismaPg({ connectionString: url, max: 1 }) });

const MIN_INTERVAL_HOURS = Number(process.env.DATA_EXPORT_MIN_INTERVAL_HOURS || 24);
const SUPPORT_EMAIL = process.env.SUPPORT_EMAIL || 'info@kabsolive.com';
const MEDIA_BASE = process.env.MEDIA_PUBLIC_BASE_URL || '';

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

async function resolveUser(raw: string): Promise<{ id: string; status: string; username: string | null }> {
  const name = raw.trim().replace(/^@/, '').toLowerCase();
  const select = { id: true, status: true, profile: { select: { username: true } } } as const;
  const user = UUID.test(name)
    ? await prisma.user.findUnique({ where: { id: name }, select })
    : name.includes('@')
      ? await prisma.user.findUnique({ where: { email: name }, select })
      : ((await prisma.userProfile.findUnique({ where: { username: name }, select: { user: { select } } }))
          ?.user ?? null);
  if (!user) fail(`No account ${raw}.`);
  return { id: user.id, status: user.status, username: user.profile?.username ?? null };
}

const label = (u: { id: string; username: string | null }) => (u.username ? `@${u.username}` : u.id);

async function exportsList(raw: string | undefined): Promise<void> {
  const user = raw ? await resolveUser(raw) : null;
  const rows = await prisma.dataExport.findMany({
    where: user ? { userId: user.id } : {},
    orderBy: { requestedAt: 'desc' },
    take: 100,
    select: {
      id: true,
      userId: true,
      status: true,
      requestedVia: true,
      requestedAt: true,
      readyAt: true,
      expiresAt: true,
      downloadedAt: true,
      sizeBytes: true,
      attempts: true,
      user: { select: { profile: { select: { username: true } } } },
    },
  });
  await prisma.auditLog.create({
    data: {
      action: AuditAction.DATA_EXPORT_ADMIN_VIEW,
      actorUserId: null,
      targetType: user ? 'user' : 'data_export',
      ...(user ? { targetId: user.id } : {}),
      metadata: { via: 'cli', command: 'exports', rows: rows.length },
    },
  });
  if (rows.length === 0) {
    process.stdout.write('No export job.\n');
    return;
  }
  for (const r of rows) {
    process.stdout.write(
      `${r.id} ${label({ id: r.userId, username: r.user.profile?.username ?? null })} ${r.status} via=${r.requestedVia}` +
        ` requested=${r.requestedAt.toISOString()}` +
        (r.readyAt ? ` ready=${r.readyAt.toISOString()}` : '') +
        (r.expiresAt ? ` link-until=${r.expiresAt.toISOString()}` : '') +
        (r.downloadedAt ? ` downloaded=${r.downloadedAt.toISOString()}` : '') +
        (r.sizeBytes !== null ? ` bytes=${r.sizeBytes}` : '') +
        ` attempts=${r.attempts}\n`,
    );
  }
}

async function exportOne(raw: string, reason: string, save: string | undefined): Promise<void> {
  const user = await resolveUser(raw);
  if (user.status === 'DELETED') fail(`${label(user)} is deleted; there is nothing to export.`);
  const now = new Date();
  const next = await nextExportAllowedAt(prisma, user.id, MIN_INTERVAL_HOURS);
  if (next && next > now)
    fail(`${label(user)} already had an export; the next one is possible after ${next.toISOString()}.`);
  const job = await prisma.$transaction(async (tx) => {
    const row = await tx.dataExport.create({
      data: { userId: user.id, requestedVia: 'ADMIN', requestedAt: now },
    });
    await tx.auditLog.create({
      data: {
        action: AuditAction.DATA_EXPORT_REQUESTED,
        actorUserId: null,
        targetType: 'data_export',
        targetId: row.id,
        metadata: { userId: user.id, via: 'cli', reason, delivery: save ? 'saved' : 'app' },
      },
    });
    return row;
  });
  if (!save) {
    process.stdout.write(
      `${label(user)}: export ${job.id} queued. The API builds it within DATA_EXPORT_SWEEP_INTERVAL_SECONDS; the person ` +
        'gets a notification and an email and downloads it in the app (Settings › Privacy), once, within 7 days.\n',
    );
    return;
  }
  const result = await buildDataExport(prisma, {
    userId: user.id,
    now,
    mediaBaseUrl: MEDIA_BASE,
    supportEmail: SUPPORT_EMAIL,
    storage: storageFromEnv(),
  });
  mkdirSync(save, { recursive: true, mode: 0o700 });
  const file = join(save, `kabso-data-${job.id}.zip`);
  writeFileSync(file, result.zip, { mode: 0o600 });
  chmodSync(file, 0o600);
  await prisma.$transaction(async (tx) => {
    await tx.dataExport.update({
      where: { id: job.id },
      data: {
        status: 'DOWNLOADED',
        startedAt: now,
        readyAt: new Date(),
        downloadedAt: new Date(),
        sizeBytes: result.zip.length,
        sha256: result.sha256,
        attempts: 1,
      },
    });
    await tx.auditLog.create({
      data: {
        action: AuditAction.DATA_EXPORT_ADMIN_VIEW,
        actorUserId: null,
        targetType: 'data_export',
        targetId: job.id,
        metadata: {
          via: 'cli',
          command: 'export --save',
          reason,
          bytes: result.zip.length,
          sha256: result.sha256,
        },
      },
    });
  });
  process.stdout.write(
    `${label(user)}: ${file} (${result.zip.length} bytes, sha256 ${result.sha256}, ${result.files} file(s)).\n` +
      'Send it by a secure channel to the verified address only, then delete it.\n',
  );
}

try {
  const { positionals, values } = parseArgs({
    args: process.argv.slice(2),
    allowPositionals: true,
    options: { reason: { type: 'string' }, save: { type: 'string' } },
  });
  const [command, target] = positionals;
  if (
    command === 'exports' &&
    positionals.length <= 2 &&
    values.reason === undefined &&
    values.save === undefined
  ) {
    await exportsList(target);
  } else if (command === 'export' && target && positionals.length === 2) {
    const reason = values.reason?.trim();
    if (!reason)
      fail(
        `${USAGE}\nA reason is required (it is kept in the audit log), e.g. "verified email request <date>".`,
      );
    if ([...reason].length > 500) fail('The reason is at most 500 characters.');
    await exportOne(target, reason, values.save);
  } else {
    fail(USAGE);
  }
} catch (err) {
  if (err instanceof TypeError) fail(`${err.message}\n${USAGE}`);
  throw err;
} finally {
  await prisma.$disconnect();
}
