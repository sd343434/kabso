/**
 * Home banner administration from the command line (D124, contract v1.26-live draft, CONVENTIONS
 * §10.26). There is no admin UI: the promo banners shown between the live cards on the live hub are
 * managed here. Runs as the MIGRATION role (MIGRATION_DATABASE_URL), like `gift-admin`: built into
 * the API image and run on the server with
 * `docker compose --profile jobs run --rm migrate node dist/cli/banner-admin.js …`
 * (docs/DEPLOYMENT.md §5.10), locally with `pnpm banner:admin …`.
 *
 *   pnpm banner:admin add (--image <file> --owner <email> | --media <mediaId>) --link <link>
 *                   [--title-ar <text>] [--title-en <text>] [--text-side left|right]
 *                   [--starts <ISO time>] [--ends <ISO time>] [--sort <n>] [--disabled]
 *                   [--placement home|room|tasks|wallet]
 *   pnpm banner:admin list            # every banner: `+` shown now, `-` disabled, `~` outside its window
 *   pnpm banner:admin disable <id>
 *   pnpm banner:admin enable <id>
 *   pnpm banner:admin remove <id>     # deletes the banner and its picture
 *
 * `--placement room` (v1.27.4-live, D137) makes it the promo box inside a live: `--image` is then
 * cover-cropped to 3:4 (600 × 800 and 240 × 320; design it at 600 × 800 px, shown ≈ 82 × 109 pt)
 * and `--media` is refused (a `HOME_BANNER` upload is 3:1). `--placement tasks` (v1.50-social, D176)
 * shows it at the bottom of the Task Center (3:1, like home). `--placement wallet` (v1.51-social,
 * D177) shows it on the wallet page, with the same 3:1 picture as `home`.
 * `--image` reads a JPEG, PNG or WebP file, cover-crops it to 3:1 around the centre and stores
 * 1 500 × 500 and 320 × 107 WebP variants in object storage (it needs the `S3_*` settings and
 * `MEDIA_PUBLIC_BASE_URL` of the API); the picture is owned by the `--owner` account. `--media`
 * takes a `HOME_BANNER` upload made through the API (`POST /media/uploads`) within the last 24 hours.
 * `--link` is `/cp/space`, `/families`, `/live?tab=trending|new|following`, `/home/room/<roomId>`,
 * `/users/<username>` or an `https://` URL. Every change writes an audit_logs row in the same
 * transaction (`banner.add`, `banner.enable`, `banner.disable`, `banner.remove`). A command that
 * changes nothing exits 0 and says so; a bad argument or an unknown banner exits 1.
 */
import 'dotenv/config';
import { readFile } from 'node:fs/promises';
import { parseArgs } from 'node:util';
import { PrismaPg } from '@prisma/adapter-pg';
import { PrismaClient } from '../generated/prisma/client.js';
import type { AppConfig } from '../config/app-config.js';
import { S3ObjectStorage } from '../modules/media/s3-object-storage.js';
import type { ObjectStorage } from '../modules/media/object-storage.js';
import { MAX_IMAGE_BYTES } from '../modules/media/media-image.js';
import {
  activeBannerWhere,
  addBannerIn,
  BANNER_ORDER,
  BannerError,
  bannerFieldProblems,
  removeBannerIn,
  setBannerEnabledIn,
  storeBannerImage,
  type BannerFields,
} from '../modules/home/home-banners.js';

function fail(message: string): never {
  process.stderr.write(`${message}\n`);
  process.exit(1);
}

const USAGE = [
  'Usage: pnpm banner:admin add (--image <file> --owner <email> | --media <mediaId>) --link <link>',
  '         [--title-ar <text>] [--title-en <text>] [--text-side left|right]',
  '         [--starts <ISO time>] [--ends <ISO time>] [--sort <n>] [--disabled] [--placement home|room|tasks|wallet]',
  '       pnpm banner:admin list',
  '       pnpm banner:admin disable|enable|remove <bannerId>',
].join('\n');

const url = process.env.MIGRATION_DATABASE_URL;
if (!url) fail('MIGRATION_DATABASE_URL is not set (the migration role changes the banners).');
const prisma = new PrismaClient({ adapter: new PrismaPg({ connectionString: url, max: 1 }) });

const OPTIONS = {
  image: { type: 'string' },
  owner: { type: 'string' },
  media: { type: 'string' },
  link: { type: 'string' },
  'title-ar': { type: 'string' },
  'title-en': { type: 'string' },
  'text-side': { type: 'string' },
  starts: { type: 'string' },
  ends: { type: 'string' },
  sort: { type: 'string' },
  disabled: { type: 'boolean' },
  placement: { type: 'string' },
} as const;

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

function date(raw: string, option: string): Date {
  const value = new Date(raw);
  if (!/^\d{4}-\d{2}-\d{2}/.test(raw) || Number.isNaN(value.getTime())) {
    fail(`${option} is an ISO time such as 2026-11-01T00:00:00+03:00.`);
  }
  return value;
}

async function add(args: readonly string[]): Promise<void> {
  let values: {
    image?: string;
    owner?: string;
    media?: string;
    link?: string;
    'title-ar'?: string;
    'title-en'?: string;
    'text-side'?: string;
    starts?: string;
    ends?: string;
    sort?: string;
    disabled?: boolean;
    placement?: string;
  };
  try {
    ({ values } = parseArgs({ args: [...args], options: OPTIONS, strict: true, allowPositionals: false }));
  } catch (err) {
    fail(`${err instanceof Error ? err.message : String(err)}\n${USAGE}`);
  }
  if ((values.image === undefined) === (values.media === undefined)) {
    fail(`Give exactly one of --image <file> or --media <mediaId>.\n${USAGE}`);
  }
  if (values.image !== undefined && values.owner === undefined) {
    fail('--image needs --owner <email> (the account that owns the picture).');
  }
  if (values.link === undefined) fail(`Missing --link.\n${USAGE}`);
  const side = (values['text-side'] ?? 'right').toUpperCase();
  if (side !== 'LEFT' && side !== 'RIGHT') fail('--text-side is left or right.');
  const placement = (values.placement ?? 'home').toUpperCase();
  if (placement !== 'HOME' && placement !== 'ROOM' && placement !== 'TASKS' && placement !== 'WALLET') {
    fail('--placement is home, room, tasks or wallet.');
  }
  const sort = values.sort ?? '0';
  if (!/^(0|[1-9][0-9]{0,6})$/.test(sort)) fail('--sort is a whole number 0–1000000.');
  const fields: BannerFields = {
    titleAr: values['title-ar'] ?? null,
    titleEn: values['title-en'] ?? null,
    titleSide: side,
    link: values.link,
    startsAt: values.starts === undefined ? new Date() : date(values.starts, '--starts'),
    endsAt: values.ends === undefined ? null : date(values.ends, '--ends'),
    sortOrder: Number(sort),
    enabled: values.disabled !== true,
    placement,
  };
  // Every field is checked before anything is uploaded.
  const problems = bannerFieldProblems(fields);
  if (problems.length > 0) fail(problems.join('\n'));

  let mediaId = values.media;
  if (values.image !== undefined) {
    const storage = storageFromEnv();
    if (!storage) {
      fail(
        '--image needs S3_BUCKET, S3_ACCESS_KEY_ID and S3_SECRET_ACCESS_KEY (and S3_ENDPOINT for R2/MinIO).',
      );
    }
    const email = values.owner!.trim().toLowerCase();
    const owner = await prisma.user.findUnique({ where: { email }, select: { id: true, deletedAt: true } });
    if (!owner || owner.deletedAt !== null) fail(`No user with email ${email}.`);
    let bytes: Buffer;
    try {
      bytes = await readFile(values.image);
    } catch {
      fail(`Cannot read ${values.image}.`);
    }
    if (bytes.length === 0 || bytes.length > MAX_IMAGE_BYTES)
      fail('The image is empty or larger than 15 MiB.');
    try {
      mediaId = (await storeBannerImage(prisma, storage, owner.id, bytes, placement)).id;
    } catch (err) {
      if (err instanceof BannerError) fail(err.message);
      throw err;
    }
  }
  let banner;
  try {
    banner = await prisma.$transaction((tx) => addBannerIn(tx, mediaId!, fields));
  } catch (err) {
    if (err instanceof BannerError) fail(err.message);
    throw err;
  }
  process.stdout.write(
    `+${banner.id} ${banner.placement.toLowerCase()} ${banner.link} (media ${banner.mediaId}, sort ${String(banner.sortOrder)}` +
      `${banner.enabled ? '' : ', disabled'}).\n`,
  );
}

async function list(): Promise<void> {
  const now = new Date();
  const banners = await prisma.homeBanner.findMany({ orderBy: BANNER_ORDER, include: { media: true } });
  if (banners.length === 0) {
    process.stdout.write('No banners.\n');
    return;
  }
  const active = new Set(
    (await prisma.homeBanner.findMany({ where: activeBannerWhere(now), select: { id: true } })).map(
      (b) => b.id,
    ),
  );
  const base = process.env.MEDIA_PUBLIC_BASE_URL ?? '';
  for (const b of banners) {
    const mark = active.has(b.id) ? '+' : b.enabled ? '~' : '-';
    process.stdout.write(
      `${mark} ${b.id} ${b.placement.toLowerCase()} sort=${String(b.sortOrder)} ${b.startsAt.toISOString()}..${b.endsAt?.toISOString() ?? 'open'} ` +
        `link=${b.link} text=${b.titleSide.toLowerCase()} "${b.titleAr ?? ''}" / "${b.titleEn ?? ''}" ` +
        `image=${base}/${b.media.largeKey}\n`,
    );
  }
}

async function setEnabled(id: string, enabled: boolean): Promise<void> {
  const changed = await prisma.$transaction((tx) => setBannerEnabledIn(tx, id, enabled));
  if (changed === null) fail(`No banner ${id}.`);
  const state = enabled ? 'enabled' : 'disabled';
  process.stdout.write(changed ? `${id}: ${state}.\n` : `${id} is already ${state}; nothing changed.\n`);
}

async function remove(id: string): Promise<void> {
  const keys = await prisma.$transaction((tx) => removeBannerIn(tx, id));
  if (keys === null) fail(`No banner ${id}.`);
  const storage = storageFromEnv();
  if (!storage) {
    process.stdout.write(
      `${id}: removed. S3 is not configured here; delete these objects: ${keys.join(' ')}\n`,
    );
    return;
  }
  try {
    await storage.delete(keys);
  } catch {
    process.stdout.write(`${id}: removed. The picture's objects could not be deleted: ${keys.join(' ')}\n`);
    return;
  }
  process.stdout.write(`${id}: removed.\n`);
}

const [command, first, ...rest] = process.argv.slice(2);
try {
  switch (command) {
    case 'add':
      await add(first === undefined ? rest : [first, ...rest]);
      break;
    case 'list':
      if (first !== undefined) fail(USAGE);
      await list();
      break;
    case 'disable':
    case 'enable':
      if (!first || rest.length > 0) fail(USAGE);
      await setEnabled(first, command === 'enable');
      break;
    case 'remove':
      if (!first || rest.length > 0) fail(USAGE);
      await remove(first);
      break;
    default:
      fail(command ? `Unknown command ${command}.\n${USAGE}` : USAGE);
  }
} finally {
  await prisma.$disconnect();
}
