/**
 * Profile moderation from the command line (v1.47-social, D175, owner 2026-10-30, CONVENTIONS
 * §10.43). Profile photos are visible at once (D168) and reported like the user; this is the tool a
 * moderator uses to take a violating photo down. Runs as the MIGRATION role
 * (MIGRATION_DATABASE_URL), like `banner-admin`: built into the API image and run on the server with
 * `docker compose --profile jobs run --rm -e S3_ENDPOINT -e S3_REGION -e S3_BUCKET -e S3_ACCESS_KEY_ID
 *  -e S3_SECRET_ACCESS_KEY -e S3_FORCE_PATH_STYLE migrate node dist/cli/profile-admin.js …`
 * (docs/DEPLOYMENT.md), locally with `pnpm profile:admin …`.
 *
 *   pnpm profile:admin remove-avatar <username> --reason <text>
 *
 * The profile goes back to the initial, the photo's `AVATAR` asset row is deleted in the same
 * transaction as an `admin.avatar.remove` audit row (with the reason) and an `AVATAR_REMOVED`
 * notification to the user; its files are deleted from object storage afterwards (needs the `S3_*`
 * settings; without them the keys are printed for manual deletion). A user without a photo changes
 * nothing (exit 0); an unknown username or a missing reason exits 1.
 */
import 'dotenv/config';
import { parseArgs } from 'node:util';
import { PrismaPg } from '@prisma/adapter-pg';
import { PrismaClient } from '../generated/prisma/client.js';
import type { AppConfig } from '../config/app-config.js';
import type { ObjectStorage } from '../modules/media/object-storage.js';
import { S3ObjectStorage } from '../modules/media/s3-object-storage.js';
import { removeAvatarByAdminIn } from '../modules/users/avatar-admin.js';

function fail(message: string): never {
  process.stderr.write(`${message}\n`);
  process.exit(1);
}

const USAGE = 'Usage: pnpm profile:admin remove-avatar <username> --reason <text>';

const url = process.env.MIGRATION_DATABASE_URL;
if (!url) fail('MIGRATION_DATABASE_URL is not set (the migration role changes profiles).');
const prisma = new PrismaClient({ adapter: new PrismaPg({ connectionString: url, max: 1 }) });

/** Object storage from the API's own settings, or null when they are not all set. */
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

async function removeAvatar(username: string, reason: string): Promise<void> {
  const result = await prisma.$transaction((tx) => removeAvatarByAdminIn(tx, username, reason));
  if (result.outcome === 'unknown_user') fail(`No user @${username}.`);
  if (result.outcome === 'no_photo') {
    process.stdout.write(`@${username} has no profile photo; nothing changed.\n`);
    return;
  }
  if (result.objectKeys.length === 0) {
    process.stdout.write(`@${username}: photo removed (it was not an uploaded asset).\n`);
    return;
  }
  const storage = storageFromEnv();
  if (!storage) {
    process.stdout.write(
      `@${username}: photo removed. S3 is not configured here; delete these objects: ${result.objectKeys.join(' ')}\n`,
    );
    return;
  }
  try {
    await storage.delete(result.objectKeys);
  } catch {
    process.stdout.write(
      `@${username}: photo removed. Its objects could not be deleted: ${result.objectKeys.join(' ')}\n`,
    );
    return;
  }
  process.stdout.write(`@${username}: photo removed and its files deleted.\n`);
}

try {
  const { positionals, values } = parseArgs({
    args: process.argv.slice(2),
    allowPositionals: true,
    options: { reason: { type: 'string' } },
  });
  const [command, username] = positionals;
  if (command !== 'remove-avatar' || !username || positionals.length !== 2) fail(USAGE);
  const reason = values.reason?.trim();
  if (!reason) fail(`${USAGE}\nA reason is required (it is kept in the audit log).`);
  if ([...reason].length > 500) fail('The reason is at most 500 characters.');
  await removeAvatar(username.replace(/^@/, ''), reason);
} catch (err) {
  if (err instanceof TypeError) fail(`${err.message}\n${USAGE}`);
  throw err;
} finally {
  await prisma.$disconnect();
}
