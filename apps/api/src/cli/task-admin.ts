/**
 * Task Center «مركز المهام» administration from the command line (v1.44-social, D166, CONVENTIONS
 * §10.41). The default tasks are seeded by migration 20261214100000_me_programs; the team changes their
 * rewards, targets, names or switches them off here (no app release). Runs as the MIGRATION role
 * (MIGRATION_DATABASE_URL): on the server
 * `docker compose --profile jobs run --rm migrate node dist/cli/task-admin.js …`, locally
 * `pnpm task:admin …`.
 *
 *   pnpm task:admin list
 *   pnpm task:admin seed-defaults   # adds the default tasks, pool and bands that are missing
 *   pnpm task:admin set <CODE> [--reward <cherries>] [--target <n>] [--enabled true|false]
 *                   [--name-ar <text>] [--name-en <text>] [--sort <n>]
 *                   [--targets <b1,b2,b3,b4>] [--rewards <b1,b2,b3,b4>] [--group <GROUP>]   # pool only
 *   pnpm task:admin bands
 *   pnpm task:admin band <1-4> [--min-level <n>] [--count <n>] [--host-count <n>]
 *                   [--name-ar <text>] [--name-en <text>]
 *
 * v1.50-social (D176): the daily pool. Pool templates (`P_…`) are offered per person: each day a
 * person gets their band's `--count` tasks (hosts `--host-count` of them host tasks), chosen
 * deterministically from the person and the day, with the band's target and reward (`--targets`,
 * `--rewards`, one per band; 0 = not offered in that band). A band starts at `--min-level` (the higher
 * of the Support and Charm levels). Changes apply from the next day's lists (a day's tasks are fixed
 * at its first read).
 *
 * v1.53-social (D184, owner): every task reward (`--reward`, `--rewards`) is in CHERRIES (the cherry
 * ledger, reason TASK_REWARD); the migration converted the coin rewards at 1 coin = 10 cherries. Up to
 * 1 000 000 000 cherries a task.
 *
 * The daily caps and the check-in coins are server config (`TASK_DAILY_CAP_CHERRIES` for the daily
 * tasks' cherries, `TASK_DAILY_CAP_COINS` for the check-in's coins, `TASK_CHECK_IN_COINS`,
 * `TASK_CHECK_IN_STREAK_BONUS_COINS`). A change applies from the next read; a reward already claimed
 * keeps what it paid. Every change writes an audit_logs row (`task.update`).
 */
import 'dotenv/config';
import { parseArgs } from 'node:util';
import { PrismaPg } from '@prisma/adapter-pg';
import { PrismaClient } from '../generated/prisma/client.js';
import { AuditAction } from '../common/audit/audit.service.js';
import { TASK_POOL_BANDS, TASK_POOL_GROUPS } from '../modules/programs/programs-rules.js';
import { seedDefaultTaskPoolIn, seedDefaultTasksIn } from '../modules/programs/programs-seed.js';

function fail(message: string): never {
  process.stderr.write(`${message}\n`);
  process.exit(1);
}

const USAGE = [
  'Usage: pnpm task:admin list',
  '       pnpm task:admin seed-defaults',
  '       pnpm task:admin set <CODE> [--reward <cherries>] [--target <n>] [--enabled true|false]',
  '         [--name-ar <text>] [--name-en <text>] [--sort <n>]',
  '         [--targets <b1,b2,b3,b4>] [--rewards <b1,b2,b3,b4>] [--group <GROUP>]   (pool templates)',
  '       pnpm task:admin bands',
  '       pnpm task:admin band <1-4> [--min-level <n>] [--count <n>] [--host-count <n>]',
  '         [--name-ar <text>] [--name-en <text>]',
].join('\n');

/** v1.53-social (D184): the CHECKs of migration 20261231110000_task_cherries. */
const MAX_REWARD_CHERRIES = 1_000_000_000;

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
  targets: { type: 'string' },
  rewards: { type: 'string' },
  group: { type: 'string' },
} as const;

const BAND_OPTIONS = {
  'min-level': { type: 'string' },
  count: { type: 'string' },
  'host-count': { type: 'string' },
  'name-ar': { type: 'string' },
  'name-en': { type: 'string' },
} as const;

/** `1,2,3,4`: one whole number per band (0 = not offered in that band). */
function perBand(raw: string, option: string, max: number): number[] {
  const parts = raw.split(',').map((p) => p.trim());
  if (parts.length !== TASK_POOL_BANDS || parts.some((p) => !/^[0-9]{1,10}$/.test(p) || Number(p) > max)) {
    fail(
      `${option} is ${String(TASK_POOL_BANDS)} whole numbers 0–${String(max)}, comma-separated (one per band).`,
    );
  }
  return parts.map(Number);
}

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
      `${t.enabled ? '+' : '-'} ${t.code} ${t.period} ${t.audience} ${t.metric} ` +
        (t.pool
          ? `pool ${t.poolGroup ?? '?'} targets ${t.bandTargets.join(',')} rewards ${t.bandRewards.join(',')} cherries `
          : `target ${String(t.target)} reward ${String(t.rewardCherries)} cherries `) +
        `sort ${String(t.sortOrder)} «${t.nameAr}» / ${t.nameEn}\n`,
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
    rewardCherries?: number;
    target?: number;
    enabled?: boolean;
    nameAr?: string;
    nameEn?: string;
    sortOrder?: number;
    bandTargets?: number[];
    bandRewards?: number[];
    poolGroup?: string;
  } = {};
  const poolOnly = values.targets !== undefined || values.rewards !== undefined || values.group !== undefined;
  if (poolOnly && !task.pool) fail('--targets, --rewards and --group are for pool templates only.');
  if (task.pool && (values.target !== undefined || values.reward !== undefined)) {
    fail('A pool template has --targets and --rewards (one per band), not --target / --reward.');
  }
  if (values.targets !== undefined) data.bandTargets = perBand(values.targets, '--targets', 1_000_000_000);
  if (values.rewards !== undefined)
    data.bandRewards = perBand(values.rewards, '--rewards', MAX_REWARD_CHERRIES);
  if (values.group !== undefined) {
    const group = values.group.toUpperCase();
    if (!(TASK_POOL_GROUPS as readonly string[]).includes(group))
      fail(`--group is ${TASK_POOL_GROUPS.join(', ')}.`);
    data.poolGroup = group;
  }
  // A pool row's target / reward mirror its highest band (the CHECK needs ≥ 1).
  if (data.bandTargets) data.target = Math.max(1, ...data.bandTargets);
  if (data.bandRewards) data.rewardCherries = Math.max(1, ...data.bandRewards);
  if (values.reward !== undefined)
    data.rewardCherries = wholeNumber(values.reward, '--reward', 1, MAX_REWARD_CHERRIES);
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

async function bands(): Promise<void> {
  const rows = await prisma.taskPoolBand.findMany({ orderBy: { band: 'asc' } });
  for (const b of rows) {
    process.stdout.write(
      `band ${String(b.band)} from level ${String(b.minLevel)}: ${String(b.dailyCount)} tasks a day ` +
        `(${String(b.hostCount)} host tasks for hosts) «${b.nameAr}» / ${b.nameEn}\n`,
    );
  }
}

async function band(raw: string, args: readonly string[]): Promise<void> {
  let values: Partial<Record<keyof typeof BAND_OPTIONS, string>>;
  try {
    ({ values } = parseArgs({
      args: [...args],
      options: BAND_OPTIONS,
      strict: true,
      allowPositionals: false,
    }));
  } catch (err) {
    fail(`${err instanceof Error ? err.message : String(err)}\n${USAGE}`);
  }
  const number = wholeNumber(raw, 'The band', 1, TASK_POOL_BANDS);
  const row = await prisma.taskPoolBand.findUnique({ where: { band: number } });
  if (!row) fail(`No band ${String(number)} (run seed-defaults).`);
  const data: {
    minLevel?: number;
    dailyCount?: number;
    hostCount?: number;
    nameAr?: string;
    nameEn?: string;
  } = {};
  if (values['min-level'] !== undefined)
    data.minLevel = wholeNumber(values['min-level'], '--min-level', 0, 200);
  if (values.count !== undefined) data.dailyCount = wholeNumber(values.count, '--count', 1, 12);
  if (values['host-count'] !== undefined)
    data.hostCount = wholeNumber(values['host-count'], '--host-count', 0, 12);
  if (values['name-ar'] !== undefined) data.nameAr = name(values['name-ar'], '--name-ar');
  if (values['name-en'] !== undefined) data.nameEn = name(values['name-en'], '--name-en');
  if (Object.keys(data).length === 0) fail(`Nothing to change.\n${USAGE}`);
  if ((data.hostCount ?? row.hostCount) > (data.dailyCount ?? row.dailyCount)) {
    fail('--host-count cannot be more than --count.');
  }
  await prisma.$transaction(async (tx) => {
    await tx.taskPoolBand.update({ where: { band: number }, data });
    await tx.auditLog.create({
      data: {
        action: AuditAction.TASK_UPDATE,
        targetType: 'task_band',
        targetId: String(number),
        metadata: { ...data, via: 'cli' },
      },
    });
  });
  process.stdout.write(`Band ${String(number)} updated.\n`);
}

const [command, first, ...rest] = process.argv.slice(2);
try {
  switch (command) {
    case 'list':
      if (first !== undefined) fail(USAGE);
      await list();
      break;
    case 'seed-defaults': {
      if (first !== undefined) fail(USAGE);
      const added = await seedDefaultTasksIn(prisma);
      const pool = await seedDefaultTaskPoolIn(prisma);
      process.stdout.write(`Added ${String(added)} default task(s) and ${String(pool)} pool template(s).\n`);
      break;
    }
    case 'bands':
      if (first !== undefined) fail(USAGE);
      await bands();
      break;
    case 'band':
      if (!first) fail(USAGE);
      await band(first, rest);
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
