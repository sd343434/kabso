/**
 * v1.66-social (D198, CONVENTIONS §10.61.2): versioned legal documents and consent records — the rules shared by the
 * API (sign-up, the consent screen, the 428 gate), the `legal-admin` CLI and D190's top-up terms. No Nest here.
 *
 * - A document version is published by `legal-admin publish terms|privacy --version --effective` (audited). The
 *   version IN FORCE for a kind is the latest whose `effective_at` has passed; until one exists nothing is required.
 * - A consent row records (user, document, version, accepted_at, ip_truncated, user agent, method).
 * - The gate: a signed-in person who has not accepted the terms and the privacy policy in force gets 428
 *   CONSENT_REQUIRED on every route except the few marked `@ConsentExempt()`.
 */
import { isIPv4, isIPv6 } from 'node:net';
import type { LegalDocumentKind, Prisma, PrismaClient } from '../../generated/prisma/client.js';

type Db = Prisma.TransactionClient | PrismaClient;

export const LEGAL_KINDS: readonly LegalDocumentKind[] = ['TERMS', 'PRIVACY'];

/** The version recorded for the 18+ statement (it has no published document). */
export const AGE_STATEMENT_VERSION = '18+';

export type ConsentMethod = 'REGISTRATION' | 'IN_APP' | 'TOPUP_WEBSITE' | 'LUCKY_GIFT';

/** `version`: letters, digits, `.`, `_`, `-`, 1–32 (e.g. `2026-11-01` or `2.0`). Same CHECK as the table. */
export const LEGAL_VERSION = /^[0-9A-Za-z][0-9A-Za-z._-]{0,31}$/;

export interface LegalDocumentRow {
  readonly id: string;
  readonly kind: LegalDocumentKind;
  readonly version: string;
  readonly effectiveAt: Date;
  readonly publishedAt: Date;
  readonly contentHash: string;
  readonly url: string;
  readonly summaryAr: string;
  readonly summaryEn: string;
}

/**
 * Keeps only the network part of an address: IPv4 → its /24 (`203.0.113.0`), IPv6 → its /48 (`2001:db8:1::`), an
 * IPv4-mapped IPv6 address as IPv4. Anything else → null (never stored as given).
 */
export function truncateIp(ip: string | null | undefined): string | null {
  if (!ip) return null;
  let raw = ip.trim();
  const mapped = /^::ffff:(\d+\.\d+\.\d+\.\d+)$/i.exec(raw);
  if (mapped?.[1]) raw = mapped[1];
  if (isIPv4(raw)) {
    const p = raw.split('.');
    return `${p[0]}.${p[1]}.${p[2]}.0`;
  }
  if (isIPv6(raw)) {
    const groups = expandIpv6(raw);
    if (!groups) return null;
    return `${groups
      .slice(0, 3)
      .map((g) => g.replace(/^0+(?=.)/, ''))
      .join(':')}::`;
  }
  return null;
}

/** The eight 16-bit groups of a valid IPv6 address (an embedded IPv4 tail becomes two groups). */
function expandIpv6(ip: string): string[] | null {
  let text = (ip.split('%')[0] ?? '').toLowerCase();
  const v4 = /(\d+)\.(\d+)\.(\d+)\.(\d+)$/.exec(text);
  if (v4) {
    const [a, b, c, d] = v4.slice(1).map(Number) as [number, number, number, number];
    text = text.slice(0, v4.index) + `${((a << 8) | b).toString(16)}:${((c << 8) | d).toString(16)}`;
  }
  const halves = text.split('::');
  if (halves.length > 2) return null;
  const head = halves[0] ? halves[0].split(':') : [];
  const tail = halves.length === 2 && halves[1] ? halves[1].split(':') : [];
  const missing = 8 - head.length - tail.length;
  if (halves.length === 1 ? missing !== 0 : missing < 1) return null;
  return [...head, ...Array<string>(halves.length === 1 ? 0 : missing).fill('0'), ...tail];
}

/** The documents in force at `now`, one per kind (absent when that kind has never taken effect). */
export async function currentLegalDocuments(
  db: Db,
  now: Date,
): Promise<Partial<Record<LegalDocumentKind, LegalDocumentRow>>> {
  const rows = await db.legalDocument.findMany({
    where: { effectiveAt: { lte: now } },
    orderBy: [{ effectiveAt: 'desc' }, { publishedAt: 'desc' }],
    distinct: ['kind'],
  });
  const out: Partial<Record<LegalDocumentKind, LegalDocumentRow>> = {};
  for (const r of rows) out[r.kind] = r;
  return out;
}

/** The documents in force the user has not accepted (empty: nothing to do). */
export async function pendingLegalDocumentsIn(
  db: Db,
  userId: string,
  current: Partial<Record<LegalDocumentKind, LegalDocumentRow>>,
): Promise<LegalDocumentRow[]> {
  const docs = LEGAL_KINDS.map((k) => current[k]).filter((d): d is LegalDocumentRow => d !== undefined);
  if (docs.length === 0) return [];
  const accepted = await db.userConsent.findMany({
    where: { userId, legalDocumentId: { in: docs.map((d) => d.id) } },
    select: { legalDocumentId: true },
  });
  const done = new Set(accepted.map((a) => a.legalDocumentId));
  return docs.filter((d) => !done.has(d.id));
}

export interface ConsentMeta {
  readonly ip: string | null;
  readonly userAgent: string | null;
  readonly method: ConsentMethod;
  readonly at: Date;
}

/** Records the acceptance of published documents (idempotent per user and document version). */
export async function recordDocumentConsentsIn(
  tx: Prisma.TransactionClient,
  userId: string,
  docs: readonly LegalDocumentRow[],
  meta: ConsentMeta,
): Promise<number> {
  if (docs.length === 0) return 0;
  const { count } = await tx.userConsent.createMany({
    data: docs.map((d) => ({
      userId,
      document: d.kind,
      version: d.version,
      legalDocumentId: d.id,
      acceptedAt: meta.at,
      ipTruncated: truncateIp(meta.ip),
      userAgent: meta.userAgent?.slice(0, 512) ?? null,
      method: meta.method,
    })),
    skipDuplicates: true,
  });
  return count;
}

/** Records a statement without a published document: the 18+ statement or the top-up terms. */
export async function recordStatementConsentIn(
  tx: Prisma.TransactionClient,
  userId: string,
  document: 'AGE_18' | 'TOPUP_TERMS',
  version: string,
  meta: ConsentMeta,
): Promise<void> {
  await tx.userConsent.create({
    data: {
      userId,
      document,
      version: version.slice(0, 32),
      acceptedAt: meta.at,
      ipTruncated: truncateIp(meta.ip),
      userAgent: meta.userAgent?.slice(0, 512) ?? null,
      method: meta.method,
    },
  });
}

/** What `register` keeps on the pending registration (D198). */
export interface RegistrationConsent {
  readonly age18: boolean;
  readonly terms: string | null;
  readonly privacy: string | null;
  /** ISO 8601: when the person accepted (the `register` call). */
  readonly at: string;
  readonly ip: string | null;
  readonly userAgent: string | null;
}

/**
 * `register/verify`: records what was accepted at `register` — the 18+ statement, and each named version that was
 * published (an unknown version records nothing: the consent screen asks after sign-in).
 */
export async function recordRegistrationConsentsIn(
  tx: Prisma.TransactionClient,
  userId: string,
  c: RegistrationConsent,
): Promise<void> {
  const at = new Date(c.at);
  const meta: ConsentMeta = {
    ip: c.ip,
    userAgent: c.userAgent,
    method: 'REGISTRATION',
    at: Number.isNaN(at.getTime()) ? new Date() : at,
  };
  if (c.age18) await recordStatementConsentIn(tx, userId, 'AGE_18', AGE_STATEMENT_VERSION, meta);
  const wanted = [
    ...(c.terms ? [{ kind: 'TERMS' as const, version: c.terms }] : []),
    ...(c.privacy ? [{ kind: 'PRIVACY' as const, version: c.privacy }] : []),
  ];
  if (wanted.length === 0) return;
  const docs = await tx.legalDocument.findMany({ where: { OR: wanted } });
  await recordDocumentConsentsIn(tx, userId, docs, meta);
}

/** The public shape of a document version (`LegalDocument` in openapi). */
export interface LegalDocumentDto {
  kind: 'TERMS' | 'PRIVACY';
  version: string;
  effectiveAt: string;
  url: string;
  contentHash: string;
  summaryAr: string;
  summaryEn: string;
}

export function legalDocumentDto(d: LegalDocumentRow): LegalDocumentDto {
  return {
    kind: d.kind,
    version: d.version,
    effectiveAt: d.effectiveAt.toISOString(),
    url: d.url,
    contentHash: d.contentHash,
    summaryAr: d.summaryAr,
    summaryEn: d.summaryEn,
  };
}
