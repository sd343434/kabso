/**
 * Versioned legal documents from the command line (v1.66-social, D198, CONVENTIONS §10.61.2). Runs as the MIGRATION
 * role (MIGRATION_DATABASE_URL) like the other admin tools: on the server
 * `docker compose --profile jobs run --rm -v "$PWD/infra/deploy/site:/site:ro" migrate node dist/cli/legal-admin.js …`
 * (docs/DEPLOYMENT.md), locally `pnpm legal:admin …`.
 *
 *   pnpm legal:admin list
 *   pnpm legal:admin publish terms|privacy --version <v> --effective <YYYY-MM-DD | ISO time>
 *        --file <the published page> --summary-ar <text> --summary-en <text> [--url <https://…>]
 *
 * `publish` records a new version: the SHA-256 of `--file` (the exact page the website serves), the public URL
 * (default https://kabsolive.com/terms | /privacy) and the summary of changes the consent screen shows. From
 * `--effective` on (UTC midnight for a date), every signed-in person must accept it on next app open: the API answers
 * 428 CONSENT_REQUIRED to everything else until they do. A version cannot be changed or removed once published
 * (publish a new one). Audited (`legal.document.publish`). Afterwards set the site's `config.json` `documents.<kind>`
 * to the same version and date so the page shows them. Exit 1 on a refusal.
 */
import 'dotenv/config';
import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { parseArgs } from 'node:util';
import { PrismaPg } from '@prisma/adapter-pg';
import { AuditAction } from '../common/audit/audit.service.js';
import { PrismaClient } from '../generated/prisma/client.js';
import { LEGAL_VERSION } from '../modules/privacy/legal.js';

function fail(message: string): never {
  process.stderr.write(`${message}\n`);
  process.exit(1);
}

const USAGE =
  'Usage: pnpm legal:admin list\n' +
  '       pnpm legal:admin publish terms|privacy --version <v> --effective <YYYY-MM-DD|ISO time>\n' +
  '            --file <page> --summary-ar <text> --summary-en <text> [--url <https://…>]';

const DEFAULT_URL = {
  TERMS: 'https://kabsolive.com/terms',
  PRIVACY: 'https://kabsolive.com/privacy',
} as const;

const url = process.env.MIGRATION_DATABASE_URL;
if (!url) fail('MIGRATION_DATABASE_URL is not set (the migration role publishes documents).');
const prisma = new PrismaClient({ adapter: new PrismaPg({ connectionString: url, max: 1 }) });

async function list(): Promise<void> {
  const rows = await prisma.legalDocument.findMany({ orderBy: [{ kind: 'asc' }, { effectiveAt: 'desc' }] });
  if (rows.length === 0) {
    process.stdout.write('No legal document is published (no consent is required yet).\n');
    return;
  }
  const now = new Date();
  const inForce = new Set<string>();
  for (const kind of ['TERMS', 'PRIVACY'] as const) {
    const current = rows.find((r) => r.kind === kind && r.effectiveAt <= now);
    if (current) inForce.add(current.id);
  }
  for (const r of rows) {
    const accepted = await prisma.userConsent.count({ where: { legalDocumentId: r.id } });
    process.stdout.write(
      `${r.kind.toLowerCase()} ${r.version} effective=${r.effectiveAt.toISOString()}` +
        ` published=${r.publishedAt.toISOString()} sha256=${r.contentHash.slice(0, 12)}… accepted=${accepted}` +
        `${inForce.has(r.id) ? ' IN FORCE' : r.effectiveAt > now ? ' (not yet in force)' : ''} ${r.url}\n`,
    );
  }
}

function parseEffective(raw: string): Date {
  const text = /^\d{4}-\d{2}-\d{2}$/.test(raw) ? `${raw}T00:00:00Z` : raw;
  const at = new Date(text);
  if (Number.isNaN(at.getTime()) || !/^\d{4}-\d{2}-\d{2}/.test(raw))
    fail('--effective must be YYYY-MM-DD or an ISO time.');
  return at;
}

function summary(raw: string | undefined, name: string): string {
  const text = raw?.trim() ?? '';
  if (!text) fail(`${USAGE}\n${name} is required (the consent screen shows it).`);
  if ([...text].length > 2000) fail(`${name} is at most 2000 characters.`);
  return text;
}

async function publish(kindRaw: string, v: Record<string, string | undefined>): Promise<void> {
  const kind = kindRaw.toUpperCase();
  if (kind !== 'TERMS' && kind !== 'PRIVACY') fail(USAGE);
  const version = v.version?.trim() ?? '';
  if (!LEGAL_VERSION.test(version))
    fail('--version: 1–32 letters, digits, ".", "_" or "-" (e.g. 2026-11-01).');
  if (!v.effective) fail(`${USAGE}\n--effective is required.`);
  const effectiveAt = parseEffective(v.effective);
  if (!v.file) fail(`${USAGE}\n--file is required (its SHA-256 is recorded).`);
  let bytes: Buffer;
  try {
    bytes = readFileSync(v.file);
  } catch {
    fail(`Cannot read ${v.file}.`);
  }
  if (bytes.length === 0) fail(`${v.file} is empty.`);
  const docUrl = v.url?.trim() || DEFAULT_URL[kind];
  if (!/^https:\/\/[^\s]{1,290}$/.test(docUrl)) fail('--url must be an https:// address.');
  const summaryAr = summary(v['summary-ar'], '--summary-ar');
  const summaryEn = summary(v['summary-en'], '--summary-en');
  const contentHash = createHash('sha256').update(bytes).digest('hex');
  const exists = await prisma.legalDocument.findUnique({ where: { kind_version: { kind, version } } });
  if (exists) fail(`${kind.toLowerCase()} ${version} is already published; publish a new version instead.`);
  const row = await prisma.$transaction(async (tx) => {
    const created = await tx.legalDocument.create({
      data: { kind, version, effectiveAt, contentHash, url: docUrl, summaryAr, summaryEn },
    });
    await tx.auditLog.create({
      data: {
        action: AuditAction.LEGAL_DOCUMENT_PUBLISH,
        actorUserId: null,
        targetType: 'legal_document',
        targetId: created.id,
        metadata: {
          via: 'cli',
          kind,
          version,
          effectiveAt: effectiveAt.toISOString(),
          contentHash,
          url: docUrl,
        },
      },
    });
    return created;
  });
  process.stdout.write(
    `${kind.toLowerCase()} ${row.version} published (sha256 ${contentHash}); in force from ` +
      `${row.effectiveAt.toISOString()}: signed-in people must accept it on next app open.\n` +
      `Set infra/deploy/site/config.json documents.${kind.toLowerCase()} = {"version": "${version}", ` +
      `"effective": "${effectiveAt.toISOString().slice(0, 10)}"} and deploy the site.\n`,
  );
}

try {
  const { positionals, values } = parseArgs({
    args: process.argv.slice(2),
    allowPositionals: true,
    options: {
      version: { type: 'string' },
      effective: { type: 'string' },
      file: { type: 'string' },
      url: { type: 'string' },
      'summary-ar': { type: 'string' },
      'summary-en': { type: 'string' },
    },
  });
  const [command, kind] = positionals;
  if (command === 'list' && positionals.length === 1) await list();
  else if (command === 'publish' && kind && positionals.length === 2) await publish(kind, values);
  else fail(USAGE);
} catch (err) {
  if (err instanceof TypeError) fail(`${err.message}\n${USAGE}`);
  throw err;
} finally {
  await prisma.$disconnect();
}
