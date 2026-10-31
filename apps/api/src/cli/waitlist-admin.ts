/**
 * The website's «أبلغني عند الإطلاق» waitlist from the command line (v1.61-social, D192, CONVENTIONS §10.55). There
 * is no API that reads it. Runs as the MIGRATION role (MIGRATION_DATABASE_URL), like the other admin CLIs: on the
 * server `docker compose --profile jobs run --rm migrate node dist/cli/waitlist-admin.js …` (docs/DEPLOYMENT.md),
 * locally `pnpm waitlist:admin …`.
 *
 *   pnpm waitlist:admin list [--limit N]        # the count per language and the newest N (default 50)
 *   pnpm waitlist:admin export [--locale ar|en] # CSV on stdout: email,locale,created_at (oldest first)
 *
 * The e-mails are personal data: every run writes an audit_logs row `waitlist.view` {op, count} (never the
 * addresses). Redirect `export` to a file on the server and delete it after the launch mailing. A bad argument
 * exits 1.
 */
import 'dotenv/config';
import { PrismaPg } from '@prisma/adapter-pg';
import { PrismaClient } from '../generated/prisma/client.js';
import { AuditAction } from '../common/audit/audit.service.js';

function fail(message: string): never {
  process.stderr.write(`${message}\n`);
  process.exit(1);
}

const USAGE = [
  'Usage: pnpm waitlist:admin list [--limit N]',
  '       pnpm waitlist:admin export [--locale ar|en]',
].join('\n');

/** RFC 4180 field: quoted when it holds a comma, quote or line break; a leading = + - @ is neutralised. */
export function csvField(value: string): string {
  const safe = /^[=+\-@\t\r]/.test(value) ? `'${value}` : value;
  return /[",\r\n]/.test(safe) ? `"${safe.replace(/"/g, '""')}"` : safe;
}

function option(args: readonly string[], name: string): string | undefined {
  const i = args.indexOf(name);
  if (i === -1) return undefined;
  const value = args[i + 1];
  if (value === undefined || value.startsWith('--')) fail(USAGE);
  return value;
}

async function main(): Promise<void> {
  const [command, ...args] = process.argv.slice(2);
  if (command !== 'list' && command !== 'export') fail(USAGE);
  const known = command === 'list' ? ['--limit'] : ['--locale'];
  for (let i = 0; i < args.length; i += 2) if (!known.includes(args[i]!)) fail(USAGE);

  const url = process.env.MIGRATION_DATABASE_URL;
  if (!url) fail('MIGRATION_DATABASE_URL is not set (the migration role reads the waitlist).');
  const prisma = new PrismaClient({ adapter: new PrismaPg({ connectionString: url, max: 1 }) });
  try {
    if (command === 'list') {
      const limitText = option(args, '--limit') ?? '50';
      const limit = Number(limitText);
      if (!Number.isInteger(limit) || limit < 1 || limit > 10_000) fail('--limit must be 1–10000.');
      const [counts, rows] = await Promise.all([
        prisma.waitlistSignup.groupBy({ by: ['locale'], _count: { _all: true } }),
        prisma.waitlistSignup.findMany({ orderBy: { createdAt: 'desc' }, take: limit }),
      ]);
      const total = counts.reduce((n, c) => n + c._count._all, 0);
      const per = counts.map((c) => `${c.locale} ${c._count._all}`).join(', ');
      process.stdout.write(`${total} on the waitlist${per ? ` (${per})` : ''}.\n`);
      for (const r of rows) process.stdout.write(`${r.createdAt.toISOString()}  ${r.locale}  ${r.email}\n`);
      await audit(prisma, 'list', rows.length);
    } else {
      const locale = option(args, '--locale');
      if (locale !== undefined && locale !== 'ar' && locale !== 'en') fail('--locale must be ar or en.');
      const rows = await prisma.waitlistSignup.findMany({
        where: locale ? { locale } : {},
        orderBy: [{ createdAt: 'asc' }, { id: 'asc' }],
      });
      process.stdout.write('email,locale,created_at\n');
      for (const r of rows) {
        process.stdout.write(`${csvField(r.email)},${r.locale},${r.createdAt.toISOString()}\n`);
      }
      await audit(prisma, 'export', rows.length);
      process.stderr.write(`${rows.length} rows exported.\n`);
    }
  } finally {
    await prisma.$disconnect();
  }
}

async function audit(prisma: PrismaClient, op: 'list' | 'export', count: number): Promise<void> {
  await prisma.auditLog.create({
    data: { action: AuditAction.WAITLIST_VIEW, targetType: 'waitlist', metadata: { op, count, via: 'cli' } },
  });
}

if (process.argv[1]?.endsWith('waitlist-admin.ts') || process.argv[1]?.endsWith('waitlist-admin.js')) {
  main().catch((err: unknown) => fail(err instanceof Error ? err.message : String(err)));
}
