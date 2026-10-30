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
 *                   [--targets <b1,b2,b3,b4>] [--rewards <b1,b2,b3,b4>]   # pool templates and weekly tasks
 *                   [--group <GROUP>]   # pool only
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
 * v1.57-social (D188, owner): `list` and `set` print the real money next to every reward — cherries at
 * the payout rate (`CHERRY_PAYOUT_RATE`, owner 1 000 000 = $1.10) — and next to coin-value targets
 * (gifts sent / received) — coins at the retail price (`COIN_RETAIL_USD_PER_MILLION`, owner $12.50 per
 * 1 000 000). Read from this process's environment (the server's values; defaults when unset).
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
import {
  COIN_VALUE_METRICS,
  TASK_POOL_BANDS,
  TASK_POOL_GROUPS,
  cherriesUsd,
  coinsUsd,
  parsePayoutRate,
  type TaskMetric,
} from '../modules/programs/programs-rules.js';
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
  '         [--targets <b1,b2,b3,b4>] [--rewards <b1,b2,b3,b4>]   (pool templates and weekly tasks)',
  '         [--group <GROUP>]   (pool templates)',
  '       pnpm task:admin bands',
  '       pnpm task:admin band <1-4> [--min-level <n>] [--count <n>] [--host-count <n>]',
  '         [--name-ar <text>] [--name-en <text>]',
].join('\n');

/** v1.53-social (D184): the CHECKs of migration 20261231110000_task_cherries. */
const MAX_REWARD_CHERRIES = 1_000_000_000;

/** v1.57-social (D188): the payout rate and the coins' retail price, as the server reads them. */
const PAYOUT_RATE = (() => {
  const raw = process.env.CHERRY_PAYOUT_RATE?.trim() || '1000000:110';
  return parsePayoutRate(raw) ?? fail('CHERRY_PAYOUT_RATE must be cherries:minor, e.g. 1000000:110.');
})();
const COIN_USD_PER_MILLION = (() => {
  const raw = process.env.COIN_RETAIL_USD_PER_MILLION?.trim() || '12.5';
  if (!/^(0|[1-9][0-9]{0,6})(\.[0-9]{1,4})?$/.test(raw) || Number(raw) <= 0) {
    fail('COIN_RETAIL_USD_PER_MILLION must be a positive decimal, e.g. 12.5.');
  }
  return Number(raw);
})();

/** `9000 (≈ $0.0099)`: cherries with their payout value. */
function cherriesWithUsd(cherries: number): string {
  return `${String(cherries)} (≈ ${cherriesUsd(cherries, PAYOUT_RATE)})`;
}

/** A target, with its retail value when the metric counts coins. */
function targetWithUsd(target: number, metric: string): string {
  return COIN_VALUE_METRICS.includes(metric as TaskMetric)
    ? `${String(target)} coins (≈ ${coinsUsd(target, COIN_USD_PER_MILLION)})`
    : String(target);
}

/** One line per task: targets and rewards with their real money (D188). */
function describe(t: {
  enabled: boolean;
  code: string;
  period: string;
  audience: string;
  metric: string;
  pool: boolean;
  poolGroup: string | null;
  target: number;
  rewardCherries: number;
  bandTargets: number[];
  bandRewards: number[];
  sortOrder: number;
  nameAr: string;
  nameEn: string;
}): string {
  const banded = t.bandTargets.length > 0;
  const body = banded
    ? `${t.pool ? `pool ${t.poolGroup ?? '?'}` : 'per band'} targets ${t.bandTargets.map((x) => targetWithUsd(x, t.metric)).join(', ')}` +
      ` rewards ${t.bandRewards.map(cherriesWithUsd).join(', ')} cherries`
    : `target ${targetWithUsd(t.target, t.metric)} reward ${cherriesWithUsd(t.rewardCherries)} cherries`;
  return (
    `${t.enabled ? '+' : '-'} ${t.code} ${t.period} ${t.audience} ${t.metric} ${body} ` +
    `sort ${String(t.sortOrder)} «${t.nameAr}» / ${t.nameEn}\n`
  );
}

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
  process.stdout.write(
    `Payout ${String(PAYOUT_RATE.cherries)} cherries = ${String(PAYOUT_RATE.minor)} minor units; ` +
      `coins $${String(COIN_USD_PER_MILLION)} per 1000000 (retail).\n`,
  );
  for (const t of rows) process.stdout.write(describe(t));
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
  // v1.57-social (D188 follow-up): a weekly task may also have one target and reward per band.
  const perBandAllowed = task.pool || task.period === 'WEEKLY';
  if (values.group !== undefined && !task.pool) fail('--group is for pool templates only.');
  if ((values.targets !== undefined || values.rewards !== undefined) && !perBandAllowed) {
    fail('--targets and --rewards are for pool templates and weekly tasks only.');
  }
  if (
    !task.pool &&
    (values.targets === undefined) !== (values.rewards === undefined) &&
    task.bandTargets.length === 0
  ) {
    fail('A weekly task gets per-band values with both --targets and --rewards.');
  }
  const banded = task.pool || task.bandTargets.length > 0 || values.targets !== undefined;
  if (banded && (values.target !== undefined || values.reward !== undefined)) {
    fail('This task has --targets and --rewards (one per band), not --target / --reward.');
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
  // A banded row's target / reward mirror its highest band (the CHECK needs ≥ 1).
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
  const updated = await prisma.$transaction(async (tx) => {
    const row = await tx.taskDefinition.update({ where: { code: task.code }, data });
    await tx.auditLog.create({
      data: {
        action: AuditAction.TASK_UPDATE,
        targetType: 'task',
        targetId: task.code,
        metadata: { ...data, via: 'cli' },
      },
    });
    return row;
  });
  process.stdout.write(`Task ${task.code} updated.\n${describe(updated)}`);
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
