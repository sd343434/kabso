/**
 * Live gift administration from the command line (CP-020, D108, CONVENTIONS §10.23). There is no
 * admin UI: the gift catalogue (no gift is seeded; the owner supplies the art) and gift-bag grants
 * are managed here. Runs as the MIGRATION role (MIGRATION_DATABASE_URL), like `wallet-admin` and
 * `bag-admin`: built into the API image and run on the server with
 * `docker compose --profile jobs run --rm migrate node dist/cli/gift-admin.js …`
 * (docs/DEPLOYMENT.md), locally with `pnpm gift:admin …`.
 *
 *   pnpm gift:admin add <code> --category POPULAR|EVENT|FUN --name-ar <text> --name-en <text>
 *                   --price <coins> --asset <assetKey> [--animation <animationKey>] [--sort <n>]
 *                   [--badge NONE|NEW|EVENT] [--tag <tagCode> --tag-ar <text> --tag-en <text>]
 *   pnpm gift:admin update <code> [any of the add options; --animation none removes the effect,
 *                   --tag none removes the sub-category]
 *   pnpm gift:admin disable <code>     # hidden from the catalogue and the bag; cannot be sent
 *   pnpm gift:admin enable <code>
 *   pnpm gift:admin list               # every gift, disabled ones marked `-`
 *   pnpm gift:admin grant <email> <code> <quantity>   # adds to the user's gift bag
 *   pnpm gift:admin bag <email>        # the user's gift bag
 *
 * Every change writes an audit_logs row in the same transaction (`gift.add`, `gift.update`,
 * `gift.disable`, `gift.enable`, `gift.grant`). A command that changes nothing exits 0 and says so;
 * a bad argument or an unknown gift or user exits 1.
 */
import 'dotenv/config';
import { parseArgs } from 'node:util';
import { PrismaPg } from '@prisma/adapter-pg';
import { PrismaClient, type GiftBadge, type GiftCategory } from '../generated/prisma/client.js';
import { AuditAction } from '../common/audit/audit.service.js';
import {
  addGiftIn,
  compareGifts,
  GIFT_CODE_PATTERN,
  GIFT_STOCK_MAX,
  giftFieldProblems,
  GiftFieldsError,
  giftTagProblem,
  grantStockIn,
  setGiftEnabledIn,
  updateGiftIn,
  type GiftFields,
} from '../modules/gifts/gift-catalogue.js';

function fail(message: string): never {
  process.stderr.write(`${message}\n`);
  process.exit(1);
}

const USAGE = [
  'Usage: pnpm gift:admin add <code> --category POPULAR|EVENT|FUN --name-ar <text> --name-en <text>',
  '         --price <coins> --asset <assetKey> [--animation <key>] [--sort <n>] [--badge NONE|NEW|EVENT]',
  '         [--tag <tagCode> --tag-ar <text> --tag-en <text>]',
  '       pnpm gift:admin update <code> [options of add; --animation none / --tag none remove them]',
  '       pnpm gift:admin disable|enable <code>',
  '       pnpm gift:admin list',
  '       pnpm gift:admin grant <email> <code> <quantity>',
  '       pnpm gift:admin bag <email>',
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
} as const;

function wholeNumber(raw: string, what: string): number {
  if (!/^(0|[1-9][0-9]{0,9})$/.test(raw)) fail(`${what} must be a whole number.`);
  return Number(raw);
}

/** The gift fields given on the command line (only those present). */
function fieldsFrom(args: readonly string[]): Partial<GiftFields> {
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
  const problems = giftFieldProblems(fields);
  if (problems.length > 0) fail(problems.join('\n'));
  return fields;
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
  const given = fieldsFrom(args);
  const missing = (['category', 'nameAr', 'nameEn', 'priceCoins', 'assetKey'] as const).filter(
    (k) => given[k] === undefined,
  );
  if (missing.length > 0) fail(`Missing: ${missing.join(', ')}.\n${USAGE}`);
  const fields: GiftFields = {
    category: given.category!,
    nameAr: given.nameAr!,
    nameEn: given.nameEn!,
    priceCoins: given.priceCoins!,
    assetKey: given.assetKey!,
    animationKey: given.animationKey ?? null,
    sortOrder: given.sortOrder ?? 0,
    badge: given.badge ?? 'NONE',
    tagCode: given.tagCode ?? null,
    tagNameAr: given.tagNameAr ?? null,
    tagNameEn: given.tagNameEn ?? null,
  };
  const tagProblem = giftTagProblem(fields);
  if (tagProblem !== null) fail(`${tagProblem}.\n${USAGE}`);
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
  const fields = fieldsFrom(args);
  if (Object.keys(fields).length === 0) fail(`Nothing to update.\n${USAGE}`);
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
        `tag=${g.tagCode === null ? 'none' : `${g.tagCode} "${g.tagNameAr ?? ''}" / "${g.tagNameEn ?? ''}"`}\n`,
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
    const gift = await tx.gift.findUnique({ where: { code }, select: { code: true } });
    if (!gift) fail(`No gift ${code}.`);
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
    default:
      fail(command ? `Unknown command ${command}.\n${USAGE}` : USAGE);
  }
} finally {
  await prisma.$disconnect();
}
