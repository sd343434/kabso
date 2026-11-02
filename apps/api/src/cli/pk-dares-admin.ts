/**
 * «PK أحكام» dare library from the command line (v1.50-live, D229, CONVENTIONS §10.80). Runs as the MIGRATION role
 * (MIGRATION_DATABASE_URL), like `pk-admin`: on the server
 * `docker compose --profile jobs run --rm migrate node dist/cli/pk-dares-admin.js …` (docs/DEPLOYMENT.md), locally
 * `pnpm pk-dares:admin …`.
 *
 *   pnpm pk-dares:admin import [file] [--dry-run]     # default: prisma/seed/pk-dares/pk-dares.v1.jsonl (idempotent)
 *   pnpm pk-dares:admin export [file] [--csv]         # every dare (JSON lines, or CSV)
 *   pnpm pk-dares:admin stats                          # counts per level / category, active, reported
 *   pnpm pk-dares:admin disable <code> --reason <text> # disable one dare (audited)
 *   pnpm pk-dares:admin enable <code> --reason <text>
 *
 * `import` reads JSON lines (the seed's format) or a `.csv` (header code,category,level,textAr,textEn): a code already
 * present is left as it is (an admin's edit is never overwritten), every new line must pass the safety rules and the
 * duplicate check, refused lines are printed and never written. Audited `pk_dare.import` (counts) with `via: cli`.
 */
import 'dotenv/config';
import { readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { parseArgs } from 'node:util';
import { PrismaPg } from '@prisma/adapter-pg';
import { PrismaClient } from '../generated/prisma/client.js';
import { importPkDaresIn, pkDareStatsIn, updatePkDareIn } from '../modules/live/pk-dares/pk-dare-library.js';
import { parseCsv, parseDareImport, toCsv } from '../modules/live/pk-dares/pk-dare-rules.js';

function fail(message: string): never {
  process.stderr.write(`${message}\n`);
  process.exit(1);
}

const USAGE = [
  'Usage: pnpm pk-dares:admin import [file] [--dry-run]',
  '       pnpm pk-dares:admin export [file] [--csv]',
  '       pnpm pk-dares:admin stats',
  '       pnpm pk-dares:admin disable|enable <code> --reason <text>',
].join('\n');

const here = dirname(fileURLToPath(import.meta.url));
/** The seed next to the sources (`src/cli` → `prisma/seed`), also from `dist/cli` in the image. */
const SEED = join(here, '../../prisma/seed/pk-dares/pk-dares.v1.jsonl');
const CLI = { userId: null, via: 'cli' as const };

const { positionals, values } = parseArgs({
  allowPositionals: true,
  options: {
    'dry-run': { type: 'boolean', default: false },
    csv: { type: 'boolean', default: false },
    reason: { type: 'string' },
  },
});
const [command, arg] = positionals;

const url = process.env.MIGRATION_DATABASE_URL;
if (!url) fail('MIGRATION_DATABASE_URL is not set (the migration role writes the dare library).');
const prisma = new PrismaClient({ adapter: new PrismaPg({ connectionString: url, max: 1 }) });

function readItems(file: string) {
  const text = readFileSync(file, 'utf8');
  const raw: unknown[] = file.endsWith('.csv')
    ? parseCsv(text)
    : text
        .split('\n')
        .filter((l) => l.trim().length > 0)
        .map((l, i) => {
          try {
            return JSON.parse(l) as unknown;
          } catch {
            fail(`Line ${i + 1} is not JSON.`);
          }
        });
  return raw.map((r, i) => {
    const parsed = parseDareImport(r);
    return typeof parsed === 'string' ? { line: i + 1, error: parsed } : parsed;
  });
}

async function main(): Promise<void> {
  switch (command) {
    case 'import': {
      const file = arg ?? SEED;
      const items = readItems(file);
      const result = await prisma.$transaction(
        (tx) =>
          importPkDaresIn(tx, items, {
            dryRun: values['dry-run'] === true,
            reason: `import ${file.split('/').pop()}`,
            actor: CLI,
            createdBy: arg === undefined ? 'SEED' : 'ADMIN',
          }),
        { timeout: 600_000, maxWait: 60_000 },
      );
      for (const r of result.rejected.slice(0, 50)) {
        process.stdout.write(`rejected line ${r.line} ${r.code ?? ''}: ${r.issues.join(', ')}\n`);
      }
      process.stdout.write(
        `${values['dry-run'] ? 'DRY RUN — ' : ''}received ${result.received}, inserted ${result.inserted}, ` +
          `already present ${result.existing}, rejected ${result.rejected.length}\n`,
      );
      if (result.rejected.length > 0) process.exitCode = 2;
      return;
    }
    case 'export': {
      const rows = await prisma.pkDare.findMany({ orderBy: { seqNo: 'asc' } });
      const items = rows.map((d) => ({
        code: d.code,
        category: d.category,
        level: d.level,
        textAr: d.textAr,
        textEn: d.textEn,
        active: d.active,
      }));
      const body = values.csv ? toCsv(items) : items.map((i) => JSON.stringify(i)).join('\n') + '\n';
      if (arg) writeFileSync(arg, body, 'utf8');
      else process.stdout.write(body);
      if (arg) process.stdout.write(`exported ${items.length}\n`);
      return;
    }
    case 'stats': {
      process.stdout.write(`${JSON.stringify(await pkDareStatsIn(prisma), null, 2)}\n`);
      return;
    }
    case 'disable':
    case 'enable': {
      if (!arg) fail(USAGE);
      const reason = values.reason?.trim() ?? '';
      if (reason.length < 1 || reason.length > 500) fail('A --reason of 1–500 characters is required.');
      const dare = await prisma.pkDare.findUnique({ where: { code: arg } });
      if (!dare) fail(`No dare with code ${arg}.`);
      await prisma.$transaction((tx) =>
        updatePkDareIn(tx, dare.id, { active: command === 'enable' }, reason, CLI, new Date()),
      );
      process.stdout.write(`${command}d ${arg}\n`);
      return;
    }
    default:
      fail(USAGE);
  }
}

main()
  .catch((err: unknown) => fail(err instanceof Error ? err.message : String(err)))
  .finally(() => void prisma.$disconnect());
