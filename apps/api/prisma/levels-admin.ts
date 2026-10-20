/**
 * Levels administration from the command line (CP-005 §9, D72). Runs as the MIGRATION role
 * (MIGRATION_DATABASE_URL): the API's runtime role cannot grant admin permissions.
 *
 *   pnpm levels:admin grant  <email> <PERMISSION…|ALL>   # e.g. LEVELS_VIEW LEVELS_EDIT
 *   pnpm levels:admin revoke <email> <PERMISSION…|ALL>
 *   pnpm levels:admin list   <email>
 *   pnpm levels:admin draft-preset <admin email>         # the owner's ladder as DRAFTS
 *
 * The user must already have `role = ADMIN`. Every grant, revoke and draft is written to
 * audit_logs. `draft-preset` never publishes or enables anything: an admin with LEVELS_PUBLISH
 * reviews each draft, then publishes it and switches the category on through the API.
 */
import 'dotenv/config';
import { PrismaPg } from '@prisma/adapter-pg';
import { PrismaClient, type AdminPermission } from '../src/generated/prisma/client.js';
import { AuditAction } from '../src/common/audit/audit.service.js';
import { LEVEL_CATEGORIES } from '../src/modules/levels/levels.constants.js';
import { PRESET_MULTIPLIER, presetLadder } from '../src/modules/levels/level-preset.js';

const PERMISSIONS: readonly AdminPermission[] = [
  'LEVELS_VIEW',
  'LEVELS_EDIT',
  'LEVELS_PUBLISH',
  'LEVELS_ADJUST',
  'LEVELS_RECONCILE',
];

function fail(message: string): never {
  process.stderr.write(`${message}\n`);
  process.exit(1);
}

const url = process.env.MIGRATION_DATABASE_URL;
if (!url) fail('MIGRATION_DATABASE_URL is not set (the migration role grants permissions).');
const prisma = new PrismaClient({ adapter: new PrismaPg({ connectionString: url, max: 1 }) });

async function admin(email: string): Promise<string> {
  const user = await prisma.user.findUnique({ where: { email: email.trim().toLowerCase() } });
  if (!user) fail(`No user with email ${email}.`);
  if (user.role !== 'ADMIN') fail(`${email} does not have role ADMIN.`);
  return user.id;
}

function permissions(args: string[]): AdminPermission[] {
  if (args.length === 1 && args[0] === 'ALL') return [...PERMISSIONS];
  if (args.length === 0) fail(`Name permissions: ${PERMISSIONS.join(' ')} or ALL.`);
  for (const a of args) if (!(PERMISSIONS as readonly string[]).includes(a)) fail(`Unknown permission ${a}.`);
  return args as AdminPermission[];
}

async function grant(email: string, list: AdminPermission[]): Promise<void> {
  const userId = await admin(email);
  await prisma.$transaction(async (tx) => {
    await tx.userAdminPermission.createMany({
      data: list.map((permission) => ({ userId, permission })),
      skipDuplicates: true,
    });
    await tx.auditLog.create({
      data: {
        action: AuditAction.LEVELS_PERMISSION_GRANT,
        targetType: 'user',
        targetId: userId,
        metadata: { permissions: list },
      },
    });
  });
}

async function revoke(email: string, list: AdminPermission[]): Promise<void> {
  const userId = await admin(email);
  await prisma.$transaction(async (tx) => {
    await tx.userAdminPermission.deleteMany({ where: { userId, permission: { in: list } } });
    await tx.auditLog.create({
      data: {
        action: AuditAction.LEVELS_PERMISSION_REVOKE,
        targetType: 'user',
        targetId: userId,
        metadata: { permissions: list },
      },
    });
  });
}

async function list(email: string): Promise<void> {
  const userId = await admin(email);
  const rows = await prisma.userAdminPermission.findMany({
    where: { userId },
    orderBy: { permission: 'asc' },
  });
  process.stdout.write(`${rows.map((r) => r.permission).join('\n') || '(none)'}\n`);
}

async function draftPreset(email: string): Promise<void> {
  const actor = await admin(email);
  const ladder = presetLadder();
  for (const code of LEVEL_CATEGORIES) {
    const created = await prisma.$transaction(async (tx) => {
      const [category] = await tx.$queryRaw<{ id: string }[]>`
        SELECT id FROM level_categories WHERE code = ${code}::level_category_code FOR UPDATE`;
      if (!category) fail(`Category ${code} is missing (run the migrations).`);
      const last = await tx.levelCategoryVersion.aggregate({
        where: { categoryId: category.id },
        _max: { versionNumber: true },
      });
      const version = await tx.levelCategoryVersion.create({
        data: {
          categoryId: category.id,
          versionNumber: (last._max.versionNumber ?? 0) + 1,
          status: 'DRAFT',
          multiplier: PRESET_MULTIPLIER,
          valueUnit: 'COIN',
          reversalPolicy: 'REVERSE_POINTS',
          luckyGiftsCountAsSupport: false,
          createdById: actor,
          levels: { create: ladder.map((l) => ({ ...l })) },
        },
      });
      await tx.auditLog.create({
        data: {
          action: AuditAction.LEVELS_VERSION_CREATE,
          actorUserId: actor,
          targetType: 'level_version',
          targetId: version.id,
          metadata: { category: code, versionNumber: version.versionNumber, preset: 'owner-2026-10-20' },
        },
      });
      return version;
    });
    process.stdout.write(`${code}: draft v${String(created.versionNumber)} ${created.id}\n`);
  }
}

const [command, email, ...rest] = process.argv.slice(2);
try {
  if (!email) fail('Usage: pnpm levels:admin grant|revoke|list|draft-preset <email> [PERMISSION…|ALL]');
  if (command === 'grant') await grant(email, permissions(rest));
  else if (command === 'revoke') await revoke(email, permissions(rest));
  else if (command === 'list') await list(email);
  else if (command === 'draft-preset') await draftPreset(email);
  else fail(`Unknown command ${command ?? ''}.`);
} finally {
  await prisma.$disconnect();
}
