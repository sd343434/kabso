/**
 * Live gift administration from the command line (CP-020, D108, CONVENTIONS §10.23). There is no
 * admin UI: the gift catalogue (no gift is seeded; the owner supplies the art) and gift-bag grants
 * are managed here. Runs as the MIGRATION role (MIGRATION_DATABASE_URL), like `wallet-admin` and
 * `bag-admin`: built into the API image and run on the server with
 * `docker compose --profile jobs run --rm migrate node dist/cli/gift-admin.js …`
 * (docs/DEPLOYMENT.md), locally with `pnpm gift:admin …`.
 *
 *   pnpm gift:admin add <code> --category POPULAR|EVENT|FUN|LUCKY --name-ar <text> --name-en <text>
 *                   --price <coins> --asset <assetKey> [--animation <animationKey>] [--sort <n>]
 *                   [--badge NONE|NEW|EVENT] [--tag <tagCode> --tag-ar <text> --tag-en <text>]
 *                   [--image <file.png|webp>] [--animation-file <file.svga>]
 *   pnpm gift:admin update <code> [any of the add options; --animation none removes the effect,
 *                   --tag none removes the sub-category, --image none / --animation-file none
 *                   remove the hosted art]
 *   pnpm gift:admin disable <code>     # hidden from the catalogue and the bag; cannot be sent
 *   pnpm gift:admin enable <code>
 *   pnpm gift:admin delete <code>      # v1.102-social (D338): never used → deleted for real (and its unused
 *                                      # files); used → archived (kept for history, hidden everywhere)
 *   pnpm gift:admin restore <code>     # an archived gift back in the catalogue (switched on)
 *   pnpm gift:admin list               # every gift, disabled ones marked `-`, archived ones `x`
 *   pnpm gift:admin grant <email> <code> <quantity>   # adds to the user's gift bag
 *   pnpm gift:admin bag <email>        # the user's gift bag
 *   pnpm gift:admin lucky-wins [--limit N] [--min-multiplier M]   # latest lucky sends with a win
 *   pnpm gift:admin lucky-day [YYYY-MM-DD]                         # a day's lucky spend and payout
 *   pnpm gift:admin quips-seed         # adds the owner's «إفيهات» pack (8 free, 27 paid); idempotent
 *
 * v1.32-live (D154, CONVENTIONS §10.33): `--category QUIPS` makes a quip: `--sound <key>` (the app's
 * bundled sound, e.g. `kabi/ghazal_01`) and `--sound-ms <ms>` are required, `--quip-text <text>` is the
 * optional line shown while it plays; `--price 0` makes it free (one per viewer per live, and the
 * host's/moderators' soundboard). `quips-seed` adds the owner's pack (prices ghazal 99, funny 199,
 * tease 299 coins) — gifts that exist already are left as they are (change them with `update`).
 *
 * v1.43-live (D195, CONVENTIONS §10.58): `--pk-booster DOUBLE|DOUBLE_TURBO|TRIPLE|TRIPLE_TURBO` makes the
 * gift a PK booster's activation gift (shown in the app's «PK» tab during a PK only; never LUCKY or
 * QUIPS; `--pk-booster none` on update makes it ordinary again). `pk-boosters-seed` adds the four with
 * the suggested default prices (owner-confirmable, D195): «دبل» 5 000, «دبل تيربو» 20 000, «تربل»
 * 50 000, «تربل تيربو» 150 000 coins — gifts that exist already are left as they are.
 *
 * v1.27-live (D132, CONVENTIONS §10.27): `--category LUCKY` makes a lucky gift (listed and sendable
 * only while the API has LUCKY_GIFTS_ENABLED=true; sent with coins only, so `grant` refuses it).
 * `lucky-wins` and `lucky-day` read the audit rows of the draws and the daily protection.
 *
 * `--image` / `--animation-file` (v1.26.2-live, D126) upload the gift's art to object storage, from
 * where the app downloads it on demand (no app release for a new gift): a PNG or WebP image (≤ 1 MB,
 * 64–2048 px, about square) and an SVGA 2.x effect (≤ 25 MB), at content-addressed, immutable keys
 * `media/gifts/<code>/<sha256 prefix>.<ext>` (Cache-Control immutable, one year). They need the
 * API's `S3_*` settings (and `MEDIA_PUBLIC_BASE_URL` for the app to see the URLs); the files must be
 * readable where the CLI runs (on the server: mounted into the job container, DEPLOYMENT §5.7).
 * The bundled `--asset` / `--animation` stay the fallback. Replaced files stay in the bucket.
 *
 * v1.46-live (D207, CONVENTIONS §10.66): the categories (the panel's tabs) are rows of `gift_categories`, managed
 * here and in the admin panel: `categories` lists them, `category-add <CODE> --name-ar --name-en [--sort n]
 * [--icon <file>] [--disabled]`, `category-update <CODE> [--name-ar] [--name-en] [--sort n] [--icon <file>|none]`,
 * `category-enable|category-disable <CODE>` (not LUCKY / QUIPS) and `category-delete <CODE> [--move-to <CODE>]`
 * (refused while it has gifts, unless they are moved to another NORMAL category first; never LUCKY / QUIPS).
 * `--category` takes any category code. `--animation-file` takes an SVGA 2.x or an MP4 (H.264, ≤ 8 MB, ≤ 15 s;
 * `--alpha none|side-by-side`, default detected: side-by-side when the width is ≥ 1.8 × the height), and
 * `--sound-file <file.mp3>|none` a hosted MP3 sound (≤ 1 MB, ≤ 15 s; not for QUIPS).
 *
 * Every change writes an audit_logs row in the same transaction (`gift.add`, `gift.update`,
 * `gift.disable`, `gift.enable`, `gift.grant`; v1.102-social `gift.delete`, `gift.archive`, `gift.restore`). A command that changes nothing exits 0 and says so;
 * a bad argument or an unknown gift or user exits 1.
 */
import 'dotenv/config';
import { readFile } from 'node:fs/promises';
import { parseArgs } from 'node:util';
import { PrismaPg } from '@prisma/adapter-pg';
import { PrismaClient, type GiftBadge, type PkBoosterKind } from '../generated/prisma/client.js';
import { AuditAction } from '../common/audit/audit.service.js';
import type { AppConfig } from '../config/app-config.js';
import type { ObjectStorage } from '../modules/media/object-storage.js';
import { S3ObjectStorage } from '../modules/media/s3-object-storage.js';
import {
  GiftArtError,
  giftAnimationFile,
  giftArtUrl,
  giftAudioFile,
  giftCategoryIconFile,
  giftImageFile,
  giftVideoFile,
  uploadGiftArt,
  type GiftArtFile,
} from '../modules/gifts/gift-art.js';
import {
  addGiftCategoryIn,
  deleteGiftCategoryIn,
  GiftCategoryError,
  giftCategoriesWithCounts,
  setGiftCategoryEnabledIn,
  updateGiftCategoryIn,
  type GiftCategoryFields,
} from '../modules/gifts/gift-categories.js';
import {
  compareGifts,
  GIFT_CATEGORY_CODE_PATTERN,
  GIFT_CODE_PATTERN,
  GIFT_STOCK_MAX,
  giftFieldProblems,
  addGiftIn,
  GiftFieldsError,
  giftMediaProblem,
  giftPkBoosterProblem,
  giftQuipProblem,
  PK_BOOSTER_PACK,
  giftTagProblem,
  grantStockIn,
  type GiftFields,
} from '../modules/gifts/gift-catalogue.js';
import {
  addGiftByAdminIn,
  giftAuditFields,
  removeGiftByAdminIn,
  restoreGiftByAdminIn,
  setGiftEnabledByAdminIn,
  updateGiftByAdminIn,
} from '../modules/gifts/gift-admin-rules.js';
import { budgetLeft, percentToBps } from '../modules/gifts/lucky-odds.js';
import { QUIP_PACK } from '../modules/gifts/quips.js';

function fail(message: string): never {
  process.stderr.write(`${message}\n`);
  process.exit(1);
}

const USAGE = [
  'Usage: pnpm gift:admin add <code> --category <CATEGORY> --name-ar <text> --name-en <text>',
  '         --price <coins> --asset <assetKey> [--animation <key>] [--sort <n>] [--badge NONE|NEW|EVENT]',
  '         [--tag <tagCode> --tag-ar <text> --tag-en <text>]',
  '         [--image <file.png|webp>] [--animation-file <file.svga|mp4> [--alpha none|side-by-side]]',
  '         [--sound-file <file.mp3>]',
  '       pnpm gift:admin update <code> [options of add; --animation none / --tag none /',
  '         --image none / --animation-file none / --sound-file none remove them]',
  '       pnpm gift:admin categories',
  '       pnpm gift:admin category-add <CODE> --name-ar <text> --name-en <text> [--sort <n>] [--icon <file>] [--disabled]',
  '       pnpm gift:admin category-update <CODE> [--name-ar <text>] [--name-en <text>] [--sort <n>] [--icon <file>|none]',
  '       pnpm gift:admin category-enable|category-disable <CODE>',
  '       pnpm gift:admin category-delete <CODE> [--move-to <CODE>]',
  '       pnpm gift:admin disable|enable <code>',
  '       pnpm gift:admin delete|restore <code>',
  '       pnpm gift:admin list',
  '       pnpm gift:admin grant <email> <code> <quantity>',
  '       pnpm gift:admin bag <email>',
  '       pnpm gift:admin lucky-wins [--limit N] [--min-multiplier M]',
  '       pnpm gift:admin lucky-day [YYYY-MM-DD]',
  '       pnpm gift:admin quips-seed',
  '       pnpm gift:admin pk-boosters-seed',
  '       (PK: --pk-booster DOUBLE|DOUBLE_TURBO|TRIPLE|TRIPLE_TURBO|none)',
  '       (QUIPS: --sound <key> --sound-ms <ms> [--quip-text <text>]; update: --quip-text none)',
].join('\n');

const url = process.env.MIGRATION_DATABASE_URL;
if (!url) fail('MIGRATION_DATABASE_URL is not set (the migration role changes the gift catalogue).');
const prisma = new PrismaClient({ adapter: new PrismaPg({ connectionString: url, max: 1 }) });

const OPTIONS = {
  category: { type: 'string' },
  'name-ar': { type: 'string' },
  'name-en': { type: 'string' },
  price: { type: 'string' },
  asset: { type: 'string' },
  animation: { type: 'string' },
  sort: { type: 'string' },
  badge: { type: 'string' },
  tag: { type: 'string' },
  'tag-ar': { type: 'string' },
  'tag-en': { type: 'string' },
  image: { type: 'string' },
  'animation-file': { type: 'string' },
  alpha: { type: 'string' },
  'sound-file': { type: 'string' },
  sound: { type: 'string' },
  'sound-ms': { type: 'string' },
  'quip-text': { type: 'string' },
  'pk-booster': { type: 'string' },
} as const;

/** The hosted-art options given (`none`: remove), checked and uploaded by {@link uploadArt}. */
interface ArtOptions {
  readonly image?: string;
  readonly animationFile?: string;
  /** v1.46-live (D207): an MP4's transparency (`none` | `side-by-side`); default: detected. */
  readonly alpha?: string;
  readonly soundFile?: string;
}

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

async function readArt(path: string, what: string): Promise<Buffer> {
  try {
    return await readFile(path);
  } catch (err) {
    const reason = err instanceof Error && 'code' in err ? String(err.code) : 'unreadable';
    return fail(
      `Cannot read the ${what} ${path} (${reason}). On the server the file must be inside the job ` +
        'container: mount its folder with -v (DEPLOYMENT §5.7).',
    );
  }
}

/**
 * Checks and uploads the files named by `--image` / `--animation-file` and returns the gift fields
 * they set (`none` clears them). Nothing is uploaded unless every given file passes its checks.
 */
async function uploadArt(code: string, art: ArtOptions): Promise<Partial<GiftFields>> {
  const fields: { -readonly [K in keyof GiftFields]?: GiftFields[K] } = {};
  const files: { file: GiftArtFile; what: string }[] = [];
  try {
    if (art.image === 'none') {
      fields.imageObjectKey = null;
    } else if (art.image !== undefined) {
      const file = await giftImageFile(code, await readArt(art.image, 'image'));
      files.push({ file, what: 'image' });
      fields.imageObjectKey = file.key;
    }
    if (art.animationFile === 'none') {
      fields.animationObjectKey = null;
      fields.animationBytes = null;
      fields.animationFormat = null;
      fields.animationAlpha = null;
    } else if (art.animationFile !== undefined) {
      const body = await readArt(art.animationFile, 'animation');
      // v1.46-live (D207): an MP4 (an `ftyp` box first) or an SVGA.
      if (body.length >= 8 && body.toString('latin1', 4, 8) === 'ftyp') {
        const file = await giftVideoFile(code, body);
        files.push({ file, what: 'animation' });
        fields.animationObjectKey = file.key;
        fields.animationBytes = file.size;
        fields.animationFormat = 'MP4';
        fields.animationAlpha =
          art.alpha === undefined
            ? file.detectedAlpha
            : art.alpha === 'side-by-side'
              ? 'SIDE_BY_SIDE'
              : 'NONE';
        process.stdout.write(
          `MP4 ${String(file.width)}×${String(file.height)} ${String(file.durationMs)} ms; transparency ` +
            `${fields.animationAlpha === 'SIDE_BY_SIDE' ? 'side-by-side' : 'none'}` +
            `${art.alpha === undefined ? ' (detected)' : ''}\n`,
        );
      } else {
        if (art.alpha !== undefined) fail('--alpha is for an MP4 effect.');
        const file = giftAnimationFile(code, body);
        files.push({ file, what: 'animation' });
        fields.animationObjectKey = file.key;
        fields.animationBytes = file.size;
        fields.animationFormat = 'SVGA';
        fields.animationAlpha = null;
      }
    } else if (art.alpha !== undefined) {
      fail('--alpha goes with --animation-file <file.mp4>.');
    }
    if (art.soundFile === 'none') {
      fields.audioObjectKey = null;
      fields.audioBytes = null;
      fields.audioMs = null;
    } else if (art.soundFile !== undefined) {
      const file = giftAudioFile(code, await readArt(art.soundFile, 'sound'));
      files.push({ file, what: 'sound' });
      fields.audioObjectKey = file.key;
      fields.audioBytes = file.size;
      fields.audioMs = file.durationMs;
    }
  } catch (err) {
    if (err instanceof GiftArtError) fail(err.message);
    throw err;
  }
  if (files.length === 0) return fields;
  const storage = storageFromEnv();
  if (!storage) {
    fail(
      '--image / --animation-file / --sound-file / --icon need S3_BUCKET, S3_ACCESS_KEY_ID and S3_SECRET_ACCESS_KEY ' +
        '(and S3_ENDPOINT for R2/MinIO), as the API has them.',
    );
  }
  const base = process.env.MEDIA_PUBLIC_BASE_URL;
  for (const { file, what } of files) {
    try {
      await uploadGiftArt(storage, file);
    } catch (err) {
      fail(
        `Uploading the ${what} failed; nothing changed: ${err instanceof Error ? err.message : String(err)}`,
      );
    }
    process.stdout.write(
      `uploaded ${what} ${giftArtUrl(base, file.key) ?? file.key} (${file.contentType}, ${String(file.size)} bytes)\n`,
    );
  }
  if (!base) {
    process.stdout.write(
      'MEDIA_PUBLIC_BASE_URL is not set here; the API serves the URLs from its own setting.\n',
    );
  }
  return fields;
}

function wholeNumber(raw: string, what: string): number {
  if (!/^(0|[1-9][0-9]{0,9})$/.test(raw)) fail(`${what} must be a whole number.`);
  return Number(raw);
}

/** The gift fields given on the command line (only those present) and the hosted-art options. */
function optionsFrom(args: readonly string[]): { fields: Partial<GiftFields>; art: ArtOptions } {
  let values: Record<string, string | undefined>;
  try {
    ({ values } = parseArgs({ args: [...args], options: OPTIONS, strict: true, allowPositionals: false }));
  } catch (err) {
    fail(`${err instanceof Error ? err.message : String(err)}\n${USAGE}`);
  }
  const fields: { -readonly [K in keyof GiftFields]?: GiftFields[K] } = {};
  if (values.category !== undefined) fields.category = values.category;
  if (values['name-ar'] !== undefined) fields.nameAr = values['name-ar'];
  if (values['name-en'] !== undefined) fields.nameEn = values['name-en'];
  if (values.price !== undefined) fields.priceCoins = wholeNumber(values.price, 'The price');
  if (values.asset !== undefined) fields.assetKey = values.asset;
  if (values.animation !== undefined) {
    fields.animationKey = values.animation === 'none' ? null : values.animation;
  }
  if (values.sort !== undefined) fields.sortOrder = wholeNumber(values.sort, 'The sort order');
  if (values.badge !== undefined) fields.badge = values.badge as GiftBadge;
  if (values.tag === 'none') {
    if (values['tag-ar'] !== undefined || values['tag-en'] !== undefined) {
      fail('--tag none removes the tag; it takes no --tag-ar / --tag-en.');
    }
    fields.tagCode = null;
    fields.tagNameAr = null;
    fields.tagNameEn = null;
  } else {
    if (values.tag !== undefined) fields.tagCode = values.tag;
    if (values['tag-ar'] !== undefined) fields.tagNameAr = values['tag-ar'];
    if (values['tag-en'] !== undefined) fields.tagNameEn = values['tag-en'];
  }
  if (values.sound !== undefined) fields.soundKey = values.sound;
  if (values['sound-ms'] !== undefined) fields.soundMs = wholeNumber(values['sound-ms'], 'The sound length');
  if (values['quip-text'] !== undefined) {
    fields.quipText = values['quip-text'] === 'none' ? null : values['quip-text'];
  }
  if (values['pk-booster'] !== undefined) {
    fields.pkBooster = values['pk-booster'] === 'none' ? null : (values['pk-booster'] as PkBoosterKind);
  }
  const problems = giftFieldProblems(fields);
  if (values.alpha !== undefined && values.alpha !== 'none' && values.alpha !== 'side-by-side') {
    problems.push('--alpha is none or side-by-side');
  }
  for (const option of ['image', 'animation-file', 'sound-file'] as const) {
    if (values[option] === '') problems.push(`--${option} needs a file (or none)`);
  }
  if (problems.length > 0) fail(problems.join('\n'));
  return {
    fields,
    art: {
      image: values.image,
      animationFile: values['animation-file'],
      alpha: values.alpha,
      soundFile: values['sound-file'],
    },
  };
}

function giftCode(raw: string | undefined): string {
  if (raw === undefined) fail(USAGE);
  if (!GIFT_CODE_PATTERN.test(raw)) fail('A gift code is 1–40 characters: a-z, 0-9 and _ (not first).');
  return raw;
}

async function user(email: string): Promise<string> {
  const row = await prisma.user.findUnique({
    where: { email: email.trim().toLowerCase() },
    select: { id: true, deletedAt: true },
  });
  if (!row || row.deletedAt !== null) fail(`No user with email ${email}.`);
  return row.id;
}

async function add(code: string, args: readonly string[]): Promise<void> {
  const { fields: options, art } = optionsFrom(args);
  const missing = (['category', 'nameAr', 'nameEn', 'priceCoins', 'assetKey'] as const).filter(
    (k) => options[k] === undefined,
  );
  if (missing.length > 0) fail(`Missing: ${missing.join(', ')}.\n${USAGE}`);
  if (art.image === 'none' || art.animationFile === 'none' || art.soundFile === 'none') {
    fail(`none is for update.\n${USAGE}`);
  }
  const fields: GiftFields = {
    category: options.category!,
    nameAr: options.nameAr!,
    nameEn: options.nameEn!,
    priceCoins: options.priceCoins!,
    assetKey: options.assetKey!,
    animationKey: options.animationKey ?? null,
    sortOrder: options.sortOrder ?? 0,
    badge: options.badge ?? 'NONE',
    tagCode: options.tagCode ?? null,
    tagNameAr: options.tagNameAr ?? null,
    tagNameEn: options.tagNameEn ?? null,
    soundKey: options.soundKey ?? null,
    soundMs: options.soundMs ?? null,
    quipText: options.quipText ?? null,
    pkBooster: options.pkBooster ?? null,
  };
  const tagProblem = giftTagProblem(fields) ?? giftQuipProblem(fields) ?? giftPkBoosterProblem(fields);
  if (tagProblem !== null) fail(`${tagProblem}.\n${USAGE}`);
  if (await prisma.gift.findUnique({ where: { code }, select: { code: true } })) {
    fail(`A gift ${code} exists already; use update.`);
  }
  if (!(await prisma.giftCategory.findUnique({ where: { code: fields.category }, select: { code: true } }))) {
    fail(`There is no gift category ${fields.category} (see: gift-admin categories).`);
  }
  if (art.soundFile !== undefined && fields.category === 'QUIPS') {
    fail('A QUIPS gift has its own --sound; no --sound-file.');
  }
  Object.assign(fields, await uploadArt(code, art));
  const mediaProblem = giftMediaProblem(fields);
  if (mediaProblem !== null) fail(`${mediaProblem}.\n${USAGE}`);
  // v1.65-social (D197): the audited rule is shared with the admin panel (gift-admin-rules.ts).
  let added: boolean;
  try {
    added = await prisma.$transaction((tx) => addGiftByAdminIn(tx, code, fields));
  } catch (err) {
    if (err instanceof GiftFieldsError) fail(`${err.message}.\n${USAGE}`);
    throw err;
  }
  if (!added) fail(`A gift ${code} exists already; use update.`);
  process.stdout.write(`+${code} (${fields.category}, ${String(fields.priceCoins)} coins).\n`);
}

async function update(code: string, args: readonly string[]): Promise<void> {
  const { fields: options, art } = optionsFrom(args);
  if (
    Object.keys(options).length === 0 &&
    art.image === undefined &&
    art.animationFile === undefined &&
    art.soundFile === undefined
  ) {
    fail(`Nothing to update.\n${USAGE}`);
  }
  if (!(await prisma.gift.findUnique({ where: { code }, select: { code: true } }))) fail(`No gift ${code}.`);
  const fields = { ...options, ...(await uploadArt(code, art)) };
  let changed: string[] | null;
  try {
    changed = await prisma.$transaction((tx) => updateGiftByAdminIn(tx, code, fields));
  } catch (err) {
    if (err instanceof GiftFieldsError) fail(`${err.message}.\n${USAGE}`);
    throw err;
  }
  if (!changed) fail(`No gift ${code}.`);
  process.stdout.write(
    changed.length > 0 ? `${code}: ${changed.join(', ')} updated.\n` : `${code}: nothing changed.\n`,
  );
}

async function setEnabled(code: string, enabled: boolean): Promise<void> {
  let changed: boolean | null;
  try {
    changed = await prisma.$transaction((tx) => setGiftEnabledByAdminIn(tx, code, enabled));
  } catch (err) {
    // v1.102-social (D338): an archived gift is restored, not enabled.
    if (err instanceof GiftFieldsError) fail(`${err.message}: pnpm gift:admin restore ${code}.`);
    throw err;
  }
  if (changed === null) fail(`No gift ${code}.`);
  const state = enabled ? 'enabled' : 'disabled';
  process.stdout.write(changed ? `${code}: ${state}.\n` : `${code} is already ${state}; nothing changed.\n`);
}

/**
 * v1.102-social (D338, CONVENTIONS §10.131) «حذف», the panel's rule: nothing ever used the gift → deleted for real
 * (`gift.delete`), then its uploaded files that no other gift names (with the S3_* settings; without them the files
 * stay in the bucket and the command says so); otherwise archived (`gift.archive`) — kept for history, hidden from
 * the catalogue, the bag's send choices, the lists and the pickers. `restore` brings an archived gift back.
 */
async function remove(code: string): Promise<void> {
  const done = await prisma.$transaction((tx) => removeGiftByAdminIn(tx, code));
  if (done === null) fail(`No gift ${code}.`);
  const uses = Object.entries(done.usage)
    .filter(([, n]) => n > 0)
    .map(([k, n]) => `${k}=${String(n)}`)
    .join(' ');
  if (done.result === 'ARCHIVED') {
    process.stdout.write(
      done.changed
        ? `${code}: archived (in use: ${uses}); history keeps it. Undo: pnpm gift:admin restore ${code}.\n`
        : `${code} is archived already; nothing changed.\n`,
    );
    return;
  }
  const b = done.before;
  const keys = [...new Set([b.imageObjectKey, b.animationObjectKey, b.audioObjectKey])].filter(
    (k): k is string => k !== null,
  );
  const still = await prisma.gift.findMany({
    where: {
      OR: [
        { imageObjectKey: { in: keys } },
        { animationObjectKey: { in: keys } },
        { audioObjectKey: { in: keys } },
      ],
    },
    select: { imageObjectKey: true, animationObjectKey: true, audioObjectKey: true },
  });
  const kept = new Set(still.flatMap((g) => [g.imageObjectKey, g.animationObjectKey, g.audioObjectKey]));
  const gone = keys.filter((k) => !kept.has(k));
  let files = '';
  if (gone.length > 0) {
    const storage = storageFromEnv();
    if (!storage) files = ` Its ${String(gone.length)} file(s) stay in the bucket (no S3_* settings here).`;
    else {
      try {
        await storage.delete(gone);
        files = ` ${String(gone.length)} file(s) deleted.`;
      } catch (err) {
        files = ` Its file(s) could not be deleted (${err instanceof Error ? err.message : String(err)}); they only cost storage.`;
      }
    }
  }
  process.stdout.write(`${code}: deleted (never used).${files}\n`);
}

async function restore(code: string): Promise<void> {
  const changed = await prisma.$transaction((tx) => restoreGiftByAdminIn(tx, code));
  if (changed === null) fail(`No gift ${code}.`);
  process.stdout.write(
    changed ? `${code}: restored and enabled.\n` : `${code} is not archived; nothing changed.\n`,
  );
}

/** v1.46-live (D207): the category codes in tab order (for sorting lists). */
async function tabOrder(): Promise<string[]> {
  const rows = await prisma.giftCategory.findMany({
    orderBy: [{ sortOrder: 'asc' }, { code: 'asc' }],
    select: { code: true },
  });
  return rows.map((r) => r.code);
}

async function list(): Promise<void> {
  const tabs = await tabOrder();
  const gifts = (await prisma.gift.findMany()).sort((a, b) => compareGifts(a, b, tabs));
  if (gifts.length === 0) {
    process.stdout.write('No gifts.\n');
    return;
  }
  for (const g of gifts) {
    process.stdout.write(
      `${g.archivedAt !== null ? 'x' : g.enabled ? ' ' : '-'} ${g.category} ${String(g.sortOrder)} ${g.code} ${String(g.priceCoins)} coins ` +
        `asset=${g.assetKey} animation=${g.animationKey ?? 'none'} badge=${g.badge} ` +
        `"${g.nameAr}" / "${g.nameEn}" ` +
        `tag=${g.tagCode === null ? 'none' : `${g.tagCode} "${g.tagNameAr ?? ''}" / "${g.tagNameEn ?? ''}"`} ` +
        `image=${g.imageObjectKey ?? 'none'} ` +
        `animation-file=${g.animationObjectKey === null ? 'none' : `${g.animationObjectKey} (${String(g.animationBytes)} bytes)`}` +
        (g.animationFormat === 'MP4'
          ? ` transparency=${g.animationAlpha === 'SIDE_BY_SIDE' ? 'side-by-side' : 'none'}`
          : '') +
        (g.audioObjectKey === null ? '' : ` sound-file=${g.audioObjectKey} (${String(g.audioMs)} ms)`) +
        (g.pkBooster === null ? '' : ` pk-booster=${g.pkBooster}`) +
        (g.soundKey === null
          ? ''
          : ` sound=${g.soundKey} (${String(g.soundMs)} ms) text="${g.quipText ?? ''}"`) +
        '\n',
    );
  }
}

async function grant(email: string, code: string, rawQuantity: string | undefined): Promise<void> {
  if (rawQuantity === undefined) fail(USAGE);
  const quantity = wholeNumber(rawQuantity, 'The quantity');
  if (quantity < 1 || quantity > GIFT_STOCK_MAX) {
    fail(`The quantity must be from 1 to ${String(GIFT_STOCK_MAX)}.`);
  }
  const userId = await user(email);
  const total = await prisma.$transaction(async (tx) => {
    const gift = await tx.gift.findUnique({
      where: { code },
      select: { code: true, category: true, archivedAt: true },
    });
    if (!gift) fail(`No gift ${code}.`);
    // v1.102-social (D338): a deleted (archived) gift is never put in a bag.
    if (gift.archivedAt !== null) fail(`${code} is deleted (archived); restore it first.`);
    // v1.27-live (D132): lucky gifts are sent with coins only (a bag send would draw for free).
    if (gift.category === 'LUCKY') fail(`${code} is a LUCKY gift; lucky gifts cannot be put in a bag.`);
    // v1.32-live (D154): quips likewise (coins only; the free ones are one per live).
    if (gift.category === 'QUIPS') fail(`${code} is a QUIPS gift; quips cannot be put in a bag.`);
    const after = await grantStockIn(tx, userId, code, quantity);
    if (after === null)
      fail(`${email} would hold more than ${String(GIFT_STOCK_MAX)} of ${code}; nothing changed.`);
    await tx.auditLog.create({
      data: {
        action: AuditAction.GIFT_GRANT,
        targetType: 'user',
        targetId: userId,
        metadata: { gift: code, quantity, total: after, via: 'cli' },
      },
    });
    return after;
  });
  process.stdout.write(`${email}: +${String(quantity)} ${code}, holds ${String(total)}.\n`);
}

async function bag(email: string): Promise<void> {
  const userId = await user(email);
  const rows = await prisma.userGiftStock.findMany({
    where: { userId, quantity: { gt: 0 } },
    include: { gift: true },
  });
  if (rows.length === 0) {
    process.stdout.write(`${email}: no gifts.\n`);
    return;
  }
  const tabs = await tabOrder();
  rows.sort((a, b) => compareGifts(a.gift, b.gift, tabs));
  for (const r of rows) {
    process.stdout.write(`${r.gift.enabled ? ' ' : '-'} ${r.giftCode} ${String(r.quantity)}\n`);
  }
}

/**
 * v1.32-live (D154): adds the owner's «إفيهات» pack (QUIP_PACK). Idempotent: a gift whose code exists
 * already is left as it is and reported (change it with `update`). One transaction, audited per gift.
 */
async function quipsSeed(): Promise<void> {
  const added = await prisma.$transaction(async (tx) => {
    const codes: string[] = [];
    for (const { code, ...fields } of QUIP_PACK) {
      if (await addGiftIn(tx, code, fields)) {
        codes.push(code);
        await tx.auditLog.create({
          data: {
            action: AuditAction.GIFT_ADD,
            targetType: 'gift',
            targetId: code,
            metadata: { ...giftAuditFields(fields), via: 'cli', pack: 'quips' },
          },
        });
      }
    }
    return codes;
  });
  const kept = QUIP_PACK.length - added.length;
  process.stdout.write(
    `quips: ${String(added.length)} added${added.length > 0 ? ` (${added.join(', ')})` : ''}, ` +
      `${String(kept)} already there (unchanged).\n`,
  );
}

/**
 * v1.43-live (D195): adds the four PK boosters' activation gifts (PK_BOOSTER_PACK, suggested prices).
 * Idempotent like `quips-seed`: an existing code is left as it is (change it with `update`).
 */
async function pkBoostersSeed(): Promise<void> {
  const added = await prisma.$transaction(async (tx) => {
    const codes: string[] = [];
    for (const { code, ...fields } of PK_BOOSTER_PACK) {
      if (await addGiftIn(tx, code, fields)) {
        codes.push(code);
        await tx.auditLog.create({
          data: {
            action: AuditAction.GIFT_ADD,
            targetType: 'gift',
            targetId: code,
            metadata: { ...giftAuditFields(fields), via: 'cli', pack: 'pk-boosters' },
          },
        });
      }
    }
    return codes;
  });
  process.stdout.write(
    `pk boosters: ${String(added.length)} added${added.length > 0 ? ` (${added.join(', ')})` : ''}, ` +
      `${String(PK_BOOSTER_PACK.length - added.length)} already there (unchanged).\n`,
  );
}

// ---- v1.46-live (D207, §10.66): the categories ----------------------------------------------------------------

const CATEGORY_OPTIONS = {
  'name-ar': { type: 'string' },
  'name-en': { type: 'string' },
  sort: { type: 'string' },
  icon: { type: 'string' },
  disabled: { type: 'boolean' },
  'move-to': { type: 'string' },
} as const;

function categoryCode(raw: string | undefined): string {
  if (raw === undefined) fail(USAGE);
  if (!GIFT_CATEGORY_CODE_PATTERN.test(raw)) {
    fail('A category code is 1–40 characters: A-Z, 0-9 and _, starting with a letter.');
  }
  return raw;
}

function categoryOptions(
  args: readonly string[],
  allowed: readonly (keyof typeof CATEGORY_OPTIONS)[],
): { [K in keyof typeof CATEGORY_OPTIONS]?: K extends 'disabled' ? boolean : string } {
  let values: Record<string, string | boolean | undefined>;
  try {
    ({ values } = parseArgs({
      args: [...args],
      options: CATEGORY_OPTIONS,
      strict: true,
      allowPositionals: false,
    }));
  } catch (err) {
    fail(`${err instanceof Error ? err.message : String(err)}\n${USAGE}`);
  }
  for (const key of Object.keys(values)) {
    if (!(allowed as readonly string[]).includes(key))
      fail(`--${key} is not an option of this command.\n${USAGE}`);
  }
  return values;
}

function categoryError(err: unknown): never {
  if (err instanceof GiftCategoryError) fail(err.message);
  throw err;
}

/** Checks and uploads `--icon <file>`; the key it sets (`none`: null), or undefined when not given. */
async function uploadIcon(code: string, icon: string | undefined): Promise<string | null | undefined> {
  if (icon === undefined) return undefined;
  if (icon === 'none') return null;
  let file: GiftArtFile;
  try {
    file = await giftCategoryIconFile(code, await readArt(icon, 'icon'));
  } catch (err) {
    if (err instanceof GiftArtError) fail(err.message);
    throw err;
  }
  const storage = storageFromEnv();
  if (!storage)
    fail('--icon needs S3_BUCKET, S3_ACCESS_KEY_ID and S3_SECRET_ACCESS_KEY, as the API has them.');
  await uploadGiftArt(storage, file);
  process.stdout.write(
    `uploaded icon ${giftArtUrl(process.env.MEDIA_PUBLIC_BASE_URL, file.key) ?? file.key}\n`,
  );
  return file.key;
}

async function categories(): Promise<void> {
  const rows = await giftCategoriesWithCounts(prisma);
  for (const c of rows) {
    process.stdout.write(
      `${c.enabled ? ' ' : '-'} ${String(c.sortOrder)} ${c.code} ${c.kind} "${c.nameAr}" / "${c.nameEn}" ` +
        `gifts=${String(c.gifts)} (enabled ${String(c.enabledGifts)}) icon=${c.iconObjectKey ?? 'none'}\n`,
    );
  }
}

async function categoryAdd(code: string, args: readonly string[]): Promise<void> {
  const v = categoryOptions(args, ['name-ar', 'name-en', 'sort', 'icon', 'disabled']);
  if (v['name-ar'] === undefined || v['name-en'] === undefined)
    fail(`Missing: --name-ar, --name-en.\n${USAGE}`);
  if (v.icon === 'none') fail('none is for category-update.');
  if (await prisma.giftCategory.findUnique({ where: { code }, select: { code: true } })) {
    fail(`A gift category ${code} exists already; use category-update.`);
  }
  const fields: GiftCategoryFields & { enabled: boolean } = {
    nameAr: v['name-ar'],
    nameEn: v['name-en'],
    sortOrder: v.sort === undefined ? 0 : wholeNumber(v.sort, 'The sort order'),
    enabled: v.disabled !== true,
  };
  const iconObjectKey = await uploadIcon(code, v.icon);
  await prisma
    .$transaction((tx) => addGiftCategoryIn(tx, code, { ...fields, iconObjectKey: iconObjectKey ?? null }))
    .catch(categoryError);
  process.stdout.write(`+category ${code} "${fields.nameAr}" / "${fields.nameEn}".\n`);
}

async function categoryUpdate(code: string, args: readonly string[]): Promise<void> {
  const v = categoryOptions(args, ['name-ar', 'name-en', 'sort', 'icon']);
  if (Object.keys(v).length === 0) fail(`Nothing to update.\n${USAGE}`);
  if (!(await prisma.giftCategory.findUnique({ where: { code }, select: { code: true } }))) {
    fail(`No gift category ${code}.`);
  }
  const iconObjectKey = await uploadIcon(code, v.icon);
  const fields: { -readonly [K in keyof GiftCategoryFields]?: GiftCategoryFields[K] } = {};
  if (v['name-ar'] !== undefined) fields.nameAr = v['name-ar'];
  if (v['name-en'] !== undefined) fields.nameEn = v['name-en'];
  if (v.sort !== undefined) fields.sortOrder = wholeNumber(v.sort, 'The sort order');
  if (iconObjectKey !== undefined) fields.iconObjectKey = iconObjectKey;
  const changed = await prisma
    .$transaction((tx) => updateGiftCategoryIn(tx, code, fields))
    .catch(categoryError);
  if (changed === null) fail(`No gift category ${code}.`);
  process.stdout.write(
    changed.length > 0 ? `${code}: ${changed.join(', ')} updated.\n` : `${code}: nothing changed.\n`,
  );
}

async function categorySetEnabled(code: string, enabled: boolean): Promise<void> {
  const changed = await prisma
    .$transaction((tx) => setGiftCategoryEnabledIn(tx, code, enabled))
    .catch(categoryError);
  if (changed === null) fail(`No gift category ${code}.`);
  const state = enabled ? 'enabled' : 'disabled';
  process.stdout.write(changed ? `${code}: ${state}.\n` : `${code} is already ${state}; nothing changed.\n`);
}

async function categoryDelete(code: string, args: readonly string[]): Promise<void> {
  const v = categoryOptions(args, ['move-to']);
  const moveTo = v['move-to'] === undefined ? null : categoryCode(v['move-to']);
  const done = await prisma.$transaction((tx) => deleteGiftCategoryIn(tx, code, moveTo)).catch(categoryError);
  if (done === null) fail(`No gift category ${code}.`);
  process.stdout.write(
    `-category ${code}` +
      (done.moved.length > 0 ? `; ${String(done.moved.length)} gift(s) moved to ${String(moveTo)}` : '') +
      '.\n',
  );
}

/** v1.27-live (D132): the latest lucky sends that won something (the audit rows of the draws). */
async function luckyWins(args: readonly string[]): Promise<void> {
  let values: Record<string, string | undefined>;
  try {
    ({ values } = parseArgs({
      args: [...args],
      options: { limit: { type: 'string' }, 'min-multiplier': { type: 'string' } },
      strict: true,
      allowPositionals: false,
    }));
  } catch (err) {
    fail(`${err instanceof Error ? err.message : String(err)}\n${USAGE}`);
  }
  const limit = values.limit === undefined ? 50 : wholeNumber(values.limit, 'The limit');
  if (limit < 1 || limit > 1000) fail('The limit must be from 1 to 1000.');
  const min =
    values['min-multiplier'] === undefined
      ? 2
      : wholeNumber(values['min-multiplier'], 'The minimum multiplier');
  const rows = await prisma.luckyGiftDraw.findMany({
    where: { coinsWon: { gt: 0 }, topMultiplier: { gte: min } },
    orderBy: { createdAt: 'desc' },
    take: limit,
    include: { sender: { select: { email: true, profile: { select: { username: true } } } } },
  });
  if (rows.length === 0) {
    process.stdout.write('No lucky wins.\n');
    return;
  }
  for (const r of rows) {
    process.stdout.write(
      `${r.createdAt.toISOString()} ${r.giftId} @${r.sender.profile?.username ?? '?'} ${r.giftCode} ` +
        `${String(r.unitPrice)}x${String(r.quantity)}x${String(r.recipients)} draws=${String(r.draws)} ` +
        `top=x${String(r.topMultiplier)} won=${String(r.coinsWon)} downgraded=${String(r.downgraded)} ` +
        `budget=${String(r.budgetBefore)}->${String(r.budgetAfter)}\n`,
    );
  }
}

/** v1.27-live (D132): one day of the daily protection (default: today in UTC). */
async function luckyDay(raw: string | undefined): Promise<void> {
  const day = raw ?? new Date().toISOString().slice(0, 10);
  if (!/^\d{4}-\d{2}-\d{2}$/.test(day) || Number.isNaN(Date.parse(`${day}T00:00:00Z`))) {
    fail('The day is YYYY-MM-DD.');
  }
  const row = await prisma.luckyGiftDay.findUnique({ where: { day: new Date(`${day}T00:00:00.000Z`) } });
  if (!row) {
    process.stdout.write(`${day}: no lucky gifts.\n`);
    return;
  }
  const rtpBps = percentToBps(process.env.LUCKY_GIFT_RTP_PERCENT ?? '85') ?? 8500;
  const realised = row.spendCoins > 0n ? Number((row.paidCoins * 10_000n) / row.spendCoins) / 100 : 0;
  process.stdout.write(
    `${day}: spend=${String(row.spendCoins)} paid=${String(row.paidCoins)} ` +
      `budget left=${String(budgetLeft(row.spendCoins, row.paidCoins, rtpBps))} (RTP ${String(rtpBps / 100)} %) ` +
      `realised=${String(realised)} % sends=${String(row.sends)} draws=${String(row.draws)}\n`,
  );
}

const [command, first, ...rest] = process.argv.slice(2);
try {
  switch (command) {
    case 'add':
      await add(giftCode(first), rest);
      break;
    case 'update':
      await update(giftCode(first), rest);
      break;
    case 'disable':
    case 'enable':
      if (rest.length > 0) fail(USAGE);
      await setEnabled(giftCode(first), command === 'enable');
      break;
    case 'delete':
      if (rest.length > 0) fail(USAGE);
      await remove(giftCode(first));
      break;
    case 'restore':
      if (rest.length > 0) fail(USAGE);
      await restore(giftCode(first));
      break;
    case 'list':
      if (first !== undefined) fail(USAGE);
      await list();
      break;
    case 'grant':
      if (!first || rest.length !== 2) fail(USAGE);
      await grant(first, giftCode(rest[0]), rest[1]);
      break;
    case 'bag':
      if (!first || rest.length > 0) fail(USAGE);
      await bag(first);
      break;
    case 'lucky-wins':
      await luckyWins(first === undefined ? [] : [first, ...rest]);
      break;
    case 'lucky-day':
      if (rest.length > 0) fail(USAGE);
      await luckyDay(first);
      break;
    case 'quips-seed':
      if (first !== undefined) fail(USAGE);
      await quipsSeed();
      break;
    case 'pk-boosters-seed':
      if (first !== undefined) fail(USAGE);
      await pkBoostersSeed();
      break;
    case 'categories':
      if (first !== undefined) fail(USAGE);
      await categories();
      break;
    case 'category-add':
      await categoryAdd(categoryCode(first), rest);
      break;
    case 'category-update':
      await categoryUpdate(categoryCode(first), rest);
      break;
    case 'category-enable':
    case 'category-disable':
      if (rest.length > 0) fail(USAGE);
      await categorySetEnabled(categoryCode(first), command === 'category-enable');
      break;
    case 'category-delete':
      await categoryDelete(categoryCode(first), rest);
      break;
    default:
      fail(command ? `Unknown command ${command}.\n${USAGE}` : USAGE);
  }
} finally {
  await prisma.$disconnect();
}
