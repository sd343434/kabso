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
 *   pnpm gift:admin list               # every gift, disabled ones marked `-`
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
 * Every change writes an audit_logs row in the same transaction (`gift.add`, `gift.update`,
 * `gift.disable`, `gift.enable`, `gift.grant`). A command that changes nothing exits 0 and says so;
 * a bad argument or an unknown gift or user exits 1.
 */
import 'dotenv/config';
import { readFile } from 'node:fs/promises';
import { parseArgs } from 'node:util';
import { PrismaPg } from '@prisma/adapter-pg';
import { PrismaClient, type GiftBadge, type GiftCategory } from '../generated/prisma/client.js';
import { AuditAction } from '../common/audit/audit.service.js';
import type { AppConfig } from '../config/app-config.js';
import type { ObjectStorage } from '../modules/media/object-storage.js';
import { S3ObjectStorage } from '../modules/media/s3-object-storage.js';
import {
  GiftArtError,
  giftAnimationFile,
  giftArtUrl,
  giftImageFile,
  uploadGiftArt,
  type GiftArtFile,
} from '../modules/gifts/gift-art.js';
import {
  addGiftIn,
  compareGifts,
  GIFT_CODE_PATTERN,
  GIFT_STOCK_MAX,
  giftFieldProblems,
  GiftFieldsError,
  giftQuipProblem,
  giftTagProblem,
  grantStockIn,
  setGiftEnabledIn,
  updateGiftIn,
  type GiftFields,
} from '../modules/gifts/gift-catalogue.js';
import { budgetLeft, percentToBps } from '../modules/gifts/lucky-odds.js';
import { QUIP_PACK } from '../modules/gifts/quips.js';

function fail(message: string): never {
  process.stderr.write(`${message}\n`);
  process.exit(1);
}

const USAGE = [
  'Usage: pnpm gift:admin add <code> --category POPULAR|EVENT|FUN|LUCKY --name-ar <text> --name-en <text>',
  '         --price <coins> --asset <assetKey> [--animation <key>] [--sort <n>] [--badge NONE|NEW|EVENT]',
  '         [--tag <tagCode> --tag-ar <text> --tag-en <text>]',
  '         [--image <file.png|webp>] [--animation-file <file.svga>]',
  '       pnpm gift:admin update <code> [options of add; --animation none / --tag none /',
  '         --image none / --animation-file none remove them]',
  '       pnpm gift:admin disable|enable <code>',
  '       pnpm gift:admin list',
  '       pnpm gift:admin grant <email> <code> <quantity>',
  '       pnpm gift:admin bag <email>',
  '       pnpm gift:admin lucky-wins [--limit N] [--min-multiplier M]',
  '       pnpm gift:admin lucky-day [YYYY-MM-DD]',
  '       pnpm gift:admin quips-seed',
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
  sound: { type: 'string' },
  'sound-ms': { type: 'string' },
  'quip-text': { type: 'string' },
} as const;

/** The hosted-art options given (`none`: remove), checked and uploaded by {@link uploadArt}. */
interface ArtOptions {
  readonly image?: string;
  readonly animationFile?: string;
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
    } else if (art.animationFile !== undefined) {
      const file = giftAnimationFile(code, await readArt(art.animationFile, 'animation'));
      files.push({ file, what: 'animation' });
      fields.animationObjectKey = file.key;
      fields.animationBytes = file.size;
    }
  } catch (err) {
    if (err instanceof GiftArtError) fail(err.message);
    throw err;
  }
  if (files.length === 0) return fields;
  const storage = storageFromEnv();
  if (!storage) {
    fail(
      '--image / --animation-file need S3_BUCKET, S3_ACCESS_KEY_ID and S3_SECRET_ACCESS_KEY ' +
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
  if (values.category !== undefined) fields.category = values.category as GiftCategory;
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
  const problems = giftFieldProblems(fields);
  for (const option of ['image', 'animation-file'] as const) {
    if (values[option] === '') problems.push(`--${option} needs a file (or none)`);
  }
  if (problems.length > 0) fail(problems.join('\n'));
  return { fields, art: { image: values.image, animationFile: values['animation-file'] } };
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
  if (art.image === 'none' || art.animationFile === 'none') fail(`none is for update.\n${USAGE}`);
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
  };
  const tagProblem = giftTagProblem(fields) ?? giftQuipProblem(fields);
  if (tagProblem !== null) fail(`${tagProblem}.\n${USAGE}`);
  if (await prisma.gift.findUnique({ where: { code }, select: { code: true } })) {
    fail(`A gift ${code} exists already; use update.`);
  }
  Object.assign(fields, await uploadArt(code, art));
  const added = await prisma.$transaction(async (tx) => {
    const created = await addGiftIn(tx, code, fields);
    if (created) {
      await tx.auditLog.create({
        data: {
          action: AuditAction.GIFT_ADD,
          targetType: 'gift',
          targetId: code,
          metadata: { ...fields, via: 'cli' },
        },
      });
    }
    return created;
  });
  if (!added) fail(`A gift ${code} exists already; use update.`);
  process.stdout.write(`+${code} (${fields.category}, ${String(fields.priceCoins)} coins).\n`);
}

async function update(code: string, args: readonly string[]): Promise<void> {
  const { fields: options, art } = optionsFrom(args);
  if (Object.keys(options).length === 0 && art.image === undefined && art.animationFile === undefined) {
    fail(`Nothing to update.\n${USAGE}`);
  }
  if (!(await prisma.gift.findUnique({ where: { code }, select: { code: true } }))) fail(`No gift ${code}.`);
  const fields = { ...options, ...(await uploadArt(code, art)) };
  const changed = await prisma.$transaction(async (tx) => {
    let result: Awaited<ReturnType<typeof updateGiftIn>>;
    try {
      result = await updateGiftIn(tx, code, fields);
    } catch (err) {
      if (err instanceof GiftFieldsError) fail(`${err.message}.\n${USAGE}`);
      throw err;
    }
    if (!result) fail(`No gift ${code}.`);
    const changes: Record<string, { from: string | number | null; to: string | number | null }> = {};
    for (const key of Object.keys(fields) as (keyof GiftFields)[]) {
      if (result.before[key] !== result.after[key]) {
        changes[key] = { from: result.before[key], to: result.after[key] };
      }
    }
    if (Object.keys(changes).length > 0) {
      await tx.auditLog.create({
        data: {
          action: AuditAction.GIFT_UPDATE,
          targetType: 'gift',
          targetId: code,
          metadata: { changes, via: 'cli' },
        },
      });
    }
    return Object.keys(changes);
  });
  process.stdout.write(
    changed.length > 0 ? `${code}: ${changed.join(', ')} updated.\n` : `${code}: nothing changed.\n`,
  );
}

async function setEnabled(code: string, enabled: boolean): Promise<void> {
  const changed = await prisma.$transaction(async (tx) => {
    const result = await setGiftEnabledIn(tx, code, enabled);
    if (result === null) fail(`No gift ${code}.`);
    if (result) {
      await tx.auditLog.create({
        data: {
          action: enabled ? AuditAction.GIFT_ENABLE : AuditAction.GIFT_DISABLE,
          targetType: 'gift',
          targetId: code,
          metadata: { via: 'cli' },
        },
      });
    }
    return result;
  });
  const state = enabled ? 'enabled' : 'disabled';
  process.stdout.write(changed ? `${code}: ${state}.\n` : `${code} is already ${state}; nothing changed.\n`);
}

async function list(): Promise<void> {
  const gifts = (await prisma.gift.findMany()).sort(compareGifts);
  if (gifts.length === 0) {
    process.stdout.write('No gifts.\n');
    return;
  }
  for (const g of gifts) {
    process.stdout.write(
      `${g.enabled ? ' ' : '-'} ${g.category} ${String(g.sortOrder)} ${g.code} ${String(g.priceCoins)} coins ` +
        `asset=${g.assetKey} animation=${g.animationKey ?? 'none'} badge=${g.badge} ` +
        `"${g.nameAr}" / "${g.nameEn}" ` +
        `tag=${g.tagCode === null ? 'none' : `${g.tagCode} "${g.tagNameAr ?? ''}" / "${g.tagNameEn ?? ''}"`} ` +
        `image=${g.imageObjectKey ?? 'none'} ` +
        `animation-file=${g.animationObjectKey === null ? 'none' : `${g.animationObjectKey} (${String(g.animationBytes)} bytes)`}` +
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
    const gift = await tx.gift.findUnique({ where: { code }, select: { code: true, category: true } });
    if (!gift) fail(`No gift ${code}.`);
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
  rows.sort((a, b) => compareGifts(a.gift, b.gift));
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
            metadata: { ...fields, via: 'cli', pack: 'quips' },
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
    default:
      fail(command ? `Unknown command ${command}.\n${USAGE}` : USAGE);
  }
} finally {
  await prisma.$disconnect();
}
