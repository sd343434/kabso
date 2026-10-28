/**
 * Search trends from the command line (v1.29-live, D147, CONVENTIONS §11.11). There is no admin UI
 * or API. Runs as the MIGRATION role (MIGRATION_DATABASE_URL), like `feature-admin`: on the server
 * `docker compose --profile jobs run --rm migrate node dist/cli/search-admin.js …`
 * (docs/DEPLOYMENT.md), locally `pnpm search:admin …`.
 *
 *   pnpm search:admin top                     # the terms with their 7-day / 24 h searchers
 *   pnpm search:admin hide <term>             # never list this term in GET /search/trending
 *   pnpm search:admin unhide <term>
 *   pnpm search:admin block-word add <word>   # no trending term or hashtag containing it
 *   pnpm search:admin block-word remove <word>
 *   pnpm search:admin block-word list
 *
 * A term is matched in its counted form (lower case, spaces collapsed); hiding a term nobody has
 * searched yet stores it hidden. Every change writes an audit_logs row in the same transaction
 * (`search.term.hide` {op: hide|unhide}, `search.blocked_word` {op: add|remove}); the public list
 * is cached for up to 60 s. A command that changes nothing exits 0 and says so; a bad argument
 * exits 1. Offensive words are added on the server, never committed to this public repository.
 */
import 'dotenv/config';
import { randomUUID } from 'node:crypto';
import { PrismaPg } from '@prisma/adapter-pg';
import { PrismaClient } from '../generated/prisma/client.js';
import { AuditAction } from '../common/audit/audit.service.js';
import { foldWord } from '../modules/live/live-blocked-words.js';
import { normalizeSearchTerm } from '../modules/posts/search-trends.js';

function fail(message: string): never {
  process.stderr.write(`${message}\n`);
  process.exit(1);
}

const USAGE = [
  'Usage: pnpm search:admin top',
  '       pnpm search:admin hide <term>',
  '       pnpm search:admin unhide <term>',
  '       pnpm search:admin block-word add|remove <word>',
  '       pnpm search:admin block-word list',
].join('\n');

const url = process.env.MIGRATION_DATABASE_URL;
if (!url) fail('MIGRATION_DATABASE_URL is not set (the migration role changes search trends).');
const prisma = new PrismaClient({ adapter: new PrismaPg({ connectionString: url, max: 1 }) });

function termOf(args: readonly string[]): string {
  if (args.length === 0) fail(USAGE);
  const term = normalizeSearchTerm(args.join(' '));
  if (term === null)
    fail(`"${args.join(' ')}" is not a term that is counted (2–64 characters with a letter).`);
  return term;
}

async function top(): Promise<void> {
  const rows = await prisma.$queryRaw<{ term: string; hidden: boolean; week: number; day: number }[]>`
    SELECT t.term, t.hidden_at IS NOT NULL AS hidden,
           COALESCE(sum(c.searchers) FILTER (WHERE c.hour >= now() - interval '7 days'), 0)::int AS week,
           COALESCE(sum(c.searchers) FILTER (WHERE c.hour >= now() - interval '24 hours'), 0)::int AS day
      FROM search_terms t LEFT JOIN search_term_counts c ON c.term_id = t.id
     GROUP BY t.id ORDER BY week DESC, t.term ASC LIMIT 50`;
  if (rows.length === 0) process.stdout.write('No search terms counted.\n');
  for (const r of rows) {
    process.stdout.write(
      `${r.hidden ? '-' : ' '} ${String(r.week).padStart(6)} ${String(r.day).padStart(6)}  ${r.term}\n`,
    );
  }
}

async function hide(args: readonly string[], hidden: boolean): Promise<void> {
  const term = termOf(args);
  const changed = await prisma.$transaction(async (tx) => {
    const row = await tx.searchTerm.findUnique({ where: { term } });
    const isHidden = row?.hiddenAt !== null && row?.hiddenAt !== undefined;
    if (isHidden === hidden) return false;
    if (row) await tx.searchTerm.update({ where: { term }, data: { hiddenAt: hidden ? new Date() : null } });
    else await tx.searchTerm.create({ data: { id: randomUUID(), term, hiddenAt: new Date() } });
    await tx.auditLog.create({
      data: {
        action: AuditAction.SEARCH_TERM_HIDE,
        targetType: 'search_term',
        targetId: term.slice(0, 64),
        metadata: { op: hidden ? 'hide' : 'unhide', via: 'cli' },
      },
    });
    return true;
  });
  process.stdout.write(
    changed
      ? `"${term}" ${hidden ? 'hidden' : 'shown again'} (the public list updates within 60 s).\n`
      : `"${term}" is already ${hidden ? 'hidden' : 'shown'}; nothing changed.\n`,
  );
}

async function blockWord(args: readonly string[]): Promise<void> {
  const [sub, ...rest] = args;
  if (sub === 'list' && rest.length === 0) {
    const rows = await prisma.searchBlockedWord.findMany({ orderBy: { word: 'asc' } });
    if (rows.length === 0) process.stdout.write('No blocked words.\n');
    for (const r of rows) process.stdout.write(`${r.word}\n`);
    return;
  }
  if ((sub !== 'add' && sub !== 'remove') || rest.length === 0) fail(USAGE);
  const word = rest.join(' ').normalize('NFC').trim().replace(/\s+/gu, ' ').toLowerCase();
  if (foldWord(word).length === 0 || [...word].length > 30) fail('A blocked word has 1–30 characters.');
  const changed = await prisma.$transaction(async (tx) => {
    const exists = (await tx.searchBlockedWord.count({ where: { word } })) > 0;
    if (exists === (sub === 'add')) return false;
    if (sub === 'add') await tx.searchBlockedWord.create({ data: { word } });
    else await tx.searchBlockedWord.delete({ where: { word } });
    await tx.auditLog.create({
      data: {
        action: AuditAction.SEARCH_BLOCKED_WORD,
        targetType: 'search_blocked_word',
        // The word itself is not written to the audit log (it may be offensive).
        targetId: null,
        metadata: { op: sub, via: 'cli' },
      },
    });
    return true;
  });
  process.stdout.write(
    changed
      ? `${sub === 'add' ? 'Added' : 'Removed'} (the public list updates within 60 s).\n`
      : `Nothing changed (${sub === 'add' ? 'already blocked' : 'not in the list'}).\n`,
  );
}

const [command, ...rest] = process.argv.slice(2);
try {
  switch (command) {
    case 'top':
      if (rest.length > 0) fail(USAGE);
      await top();
      break;
    case 'hide':
      await hide(rest, true);
      break;
    case 'unhide':
      await hide(rest, false);
      break;
    case 'block-word':
      await blockWord(rest);
      break;
    default:
      fail(command ? `Unknown command ${command}.\n${USAGE}` : USAGE);
  }
} finally {
  await prisma.$disconnect();
}
