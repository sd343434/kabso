/**
 * Task Center «مركز المهام» administration from the command line (v1.44-social, D166, CONVENTIONS
 * §10.41). The default tasks are seeded by migration 20261214100000_me_programs; the team changes their
 * rewards, targets, names or switches them off here (no app release). Runs as the MIGRATION role
 * (MIGRATION_DATABASE_URL): on the server
 * `docker compose --profile jobs run --rm migrate node dist/cli/task-admin.js …`, locally
 * `pnpm task:admin …`.
 *
 *   pnpm task:admin list
 *   pnpm task:admin set <CODE> [--reward <coins>] [--target <n>] [--enabled true|false]
 *                   [--name-ar <text>] [--name-en <text>] [--sort <n>]
 *
 * The daily cap and the check-in coins are server config (`TASK_DAILY_CAP_COINS`,
 * `TASK_CHECK_IN_COINS`, `TASK_CHECK_IN_STREAK_BONUS_COINS`). A change applies from the next read; a
 * reward already claimed keeps what it paid. Every change writes an audit_logs row (`task.update`).
 */
import 'dotenv/config';
import { parseArgs } from 'node:util';
import { PrismaPg } from '@prisma/adapter-pg';
import { PrismaClient } from '../generated/prisma/client.js';
import { AuditAction } from '../common/audit/audit.service.js';

function fail(message: string): never {
  process.stderr.write(`${message}\n`);
  process.exit(1);
}

const USAGE = [
  'Usage: pnpm task:admin list',
  '       pnpm task:admin set <CODE> [--reward <coins>] [--target <n>] [--enabled true|false]',
  '         [--name-ar <text>] [--name-en <text>] [--sort <n>]',
].join('\n');

const url = process.env.MIGRATION_DATABASE_URL;
if (!url) fail('MIGRATION_DATABASE_URL is not set (the migration role changes the tasks).');
const prisma = new PrismaClient({ adapter: new PrismaPg({ connectionString: url, max: 1 }) });

const OPTIONS = {
  reward: { type: 'string' },
  target: { type: 'string' },
  enabled: { type: 'string' },
  'name-ar': { type: 'string' },
  'name-en': { type: 'string' },
  sort: { type: 'string' },
} as const;

function wholeNumber(raw: string, option: string, min: number, max: number): number {
  if (!/^[0-9]{1,10}$/.test(raw) || Number(raw) < min || Number(raw) > max) {
    fail(`${option} is a whole number ${String(min)}–${String(max)}.`);
  }
  return Number(raw);
}

function name(raw: string, option: string): string {
  const value = raw.trim();
  if (value === '' || [...value].length > 80) fail(`${option} is 1–80 characters.`);
  return value;
}

async function list(): Promise<void> {
  const rows = await prisma.taskDefinition.findMany({ orderBy: [{ sortOrder: 'asc' }, { code: 'asc' }] });
  for (const t of rows) {
    process.stdout.write(
      `${t.enabled ? '+' : '-'} ${t.code} ${t.period} ${t.audience} ${t.metric} target ${String(t.target)} ` +
        `reward ${String(t.rewardCoins)} sort ${String(t.sortOrder)} «${t.nameAr}» / ${t.nameEn}\n`,
    );
  }
}

async function set(code: string, args: readonly string[]): Promise<void> {
  let values: Partial<Record<keyof typeof OPTIONS, string>>;
  try {
    ({ values } = parseArgs({ args: [...args], options: OPTIONS, strict: true, allowPositionals: false }));
  } catch (err) {
    fail(`${err instanceof Error ? err.message : String(err)}\n${USAGE}`);
  }
  const task = await prisma.taskDefinition.findUnique({ where: { code: code.toUpperCase() } });
  if (!task) fail(`No task ${code}.`);
  const data: {
    rewardCoins?: number;
    target?: number;
    enabled?: boolean;
    nameAr?: string;
    nameEn?: string;
    sortOrder?: number;
  } = {};
  if (values.reward !== undefined) data.rewardCoins = wholeNumber(values.reward, '--reward', 1, 1_000_000);
  if (values.target !== undefined) data.target = wholeNumber(values.target, '--target', 1, 1_000_000_000);
  if (values.sort !== undefined) data.sortOrder = wholeNumber(values.sort, '--sort', 0, 1_000_000);
  if (values.enabled !== undefined) {
    if (values.enabled !== 'true' && values.enabled !== 'false') fail('--enabled is true or false.');
    data.enabled = values.enabled === 'true';
  }
  if (values['name-ar'] !== undefined) data.nameAr = name(values['name-ar'], '--name-ar');
  if (values['name-en'] !== undefined) data.nameEn = name(values['name-en'], '--name-en');
  if (Object.keys(data).length === 0) fail(`Nothing to change.\n${USAGE}`);
  await prisma.$transaction(async (tx) => {
    await tx.taskDefinition.update({ where: { code: task.code }, data });
    await tx.auditLog.create({
      data: {
        action: AuditAction.TASK_UPDATE,
        targetType: 'task',
        targetId: task.code,
        metadata: { ...data, via: 'cli' },
      },
    });
  });
  process.stdout.write(`Task ${task.code} updated.\n`);
}

const [command, first, ...rest] = process.argv.slice(2);
try {
  switch (command) {
    case 'list':
      if (first !== undefined) fail(USAGE);
      await list();
      break;
    case 'set':
      if (!first) fail(USAGE);
      await set(first, rest);
      break;
    default:
      fail(command ? `Unknown command ${command}.\n${USAGE}` : USAGE);
  }
} finally {
  await prisma.$disconnect();
}
