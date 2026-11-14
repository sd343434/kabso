import type { KycCheck, KycPurpose, Prisma, PrismaClient } from '../../generated/prisma/client.js';
import { ageOn, countsFor, DIDIT_CONSOLE_URL, workflowFor, type KycSettingsRow } from './kyc.rules.js';

/**
 * v1.80-kyc (D227, CONVENTIONS §10.77): the identity-check rules the applications share — the API, the CLIs
 * (`host-admin`, `recharge-admin`) and the tests (no Nest dependencies).
 *
 * The gate (owner 2026-11-01): while Didit is ON, an approved check is required before the team approves a «كن
 * مضيفاً مع الإدارة» application (D209), before «افتح وكالة» opens an agency (D206: it opens at once, so at the
 * opening), and before a recharge agent is activated by the first top-up (D185); the manual ID card + selfie are not
 * asked any more. While Didit is OFF, the manual pictures stay the check (the fallback) and an approved check made
 * earlier also counts.
 */

type Db = Prisma.TransactionClient | PrismaClient;

/** A refused decision because the identity check is missing (the panel answers 409 `kyc_required`). */
export class KycRequiredError extends Error {
  readonly issue = 'kyc_required';
}

export async function kycSettingsIn(db: Db): Promise<KycSettingsRow | null> {
  return db.kycSettings.findUnique({ where: { id: 1 } });
}

/** Didit is on: the switch (the row's CHECK guarantees the key, the secret and a workflow are there). */
export function kycOn(row: Pick<KycSettingsRow, 'enabled'> | null): boolean {
  return row?.enabled === true;
}

/** The person's newest APPROVED check that counts for `purpose` (see `countsFor`), or null. */
export async function approvedCheckIn(
  db: Db,
  userId: string,
  purpose: KycPurpose,
  row: KycSettingsRow | null,
): Promise<KycCheck | null> {
  const approved = await db.kycCheck.findMany({
    where: { userId, status: 'APPROVED' },
    orderBy: [{ decidedAt: 'desc' }, { id: 'desc' }],
    take: 20,
  });
  return approved.find((c) => countsFor(c, purpose, row)) ?? null;
}

export interface KycGate {
  readonly enabled: boolean;
  readonly approved: KycCheck | null;
}

export async function kycGateIn(db: Db, userId: string, purpose: KycPurpose): Promise<KycGate> {
  const row = await kycSettingsIn(db);
  return { enabled: kycOn(row), approved: await approvedCheckIn(db, userId, purpose, row) };
}

/**
 * The team's decision gate (host approval, recharge activation): passes with an approved check; with Didit off also
 * with the manual pictures of the application (`hasManualPictures`). Throws {@link KycRequiredError}.
 */
export async function assertKycForDecisionIn(
  db: Db,
  userId: string,
  purpose: KycPurpose,
  hasManualPictures: boolean,
): Promise<KycGate> {
  const gate = await kycGateIn(db, userId, purpose);
  if (gate.approved) return gate;
  if (!gate.enabled && hasManualPictures) return gate;
  throw new KycRequiredError(
    gate.enabled
      ? 'Identity verification (Didit) is on: the applicant must have an approved identity check first.'
      : 'The application has neither the ID pictures nor an approved identity check.',
  );
}

/** Account purge (D193 / D198): every check of the person goes (the record of the session is Didit's). */
export async function purgeKycIn(tx: Prisma.TransactionClient, userId: string): Promise<string[]> {
  const rows = await tx.kycCheck.findMany({ where: { userId }, select: { sessionId: true } });
  const sessions = rows.map((r) => r.sessionId);
  if (sessions.length > 0) {
    await tx.kycWebhookEvent.deleteMany({ where: { sessionId: { in: sessions } } });
  }
  await tx.kycCheck.deleteMany({ where: { userId } });
  return sessions;
}

/** The data export's `kyc_checks` section (the person's own data; never the document hash). */
export async function exportKycIn(db: Db, userId: string) {
  const rows = await db.kycCheck.findMany({ where: { userId }, orderBy: { createdAt: 'asc' } });
  return rows.map((c) => ({
    id: c.id,
    provider: 'Didit',
    purpose: c.purpose,
    status: c.status,
    providerStatus: c.providerStatus,
    reasons: c.reasons,
    fullName: c.fullName,
    dateOfBirth: c.dateOfBirth ? c.dateOfBirth.toISOString().slice(0, 10) : null,
    documentCountry: c.documentCountry,
    documentNumberStored: false,
    startedAt: c.createdAt.toISOString(),
    decidedAt: c.decidedAt?.toISOString() ?? null,
  }));
}

interface Person {
  id: string;
  username: string;
  displayName: string;
}

/** `AdminKycCheck`: what the panel shows of a check (`kyc.view`). */
export interface AdminKycCheckDto {
  id: string;
  purpose: KycPurpose;
  status: KycCheck['status'];
  providerStatus: string;
  reasons: string[];
  sessionId: string;
  sessionNumber: number | null;
  workflowId: string;
  fullName: string | null;
  dateOfBirth: string | null;
  age: number | null;
  documentCountry: string | null;
  duplicateDocument: boolean;
  duplicates: Person[];
  createdAt: string;
  decidedAt: string | null;
  consoleUrl: string;
}

/** `AdminKycSummary`: the identity check of an application's person, for the application pages. */
export interface AdminKycSummaryDto {
  enabled: boolean;
  required: boolean;
  satisfied: boolean;
  workflowId: string | null;
  approved: AdminKycCheckDto | null;
  latest: AdminKycCheckDto | null;
}

/** The other accounts whose check has the same document hash. */
export async function duplicatesOf(
  db: Db,
  check: Pick<KycCheck, 'userId' | 'documentHash'>,
): Promise<Person[]> {
  if (!check.documentHash) return [];
  const rows = await db.kycCheck.findMany({
    where: { documentHash: check.documentHash, userId: { not: check.userId } },
    select: { user: { select: { id: true, profile: { select: { username: true, displayName: true } } } } },
    distinct: ['userId'],
    take: 10,
  });
  return rows.map((r) => ({
    id: r.user.id,
    username: r.user.profile?.username ?? '',
    displayName: r.user.profile?.displayName ?? '',
  }));
}

export async function adminCheckDto(
  db: Db,
  c: KycCheck,
  now: Date,
  personal = true,
): Promise<AdminKycCheckDto> {
  if (!personal) {
    // Without `kyc.view` (e.g. MODERATION on «طلبات المضيفين»): the state only, no personal field.
    return {
      ...(await adminCheckDto(db, c, now, true)),
      fullName: null,
      dateOfBirth: null,
      age: null,
      documentCountry: null,
      duplicates: [],
    };
  }
  return {
    id: c.id,
    purpose: c.purpose,
    status: c.status,
    providerStatus: c.providerStatus,
    reasons: c.reasons,
    sessionId: c.sessionId,
    sessionNumber: c.sessionNumber,
    workflowId: c.workflowId,
    fullName: c.fullName,
    dateOfBirth: c.dateOfBirth ? c.dateOfBirth.toISOString().slice(0, 10) : null,
    age: c.dateOfBirth ? ageOn(c.dateOfBirth, now) : null,
    documentCountry: c.documentCountry,
    duplicateDocument: c.duplicateDocument,
    duplicates: c.duplicateDocument ? await duplicatesOf(db, c) : [],
    createdAt: c.createdAt.toISOString(),
    decidedAt: c.decidedAt?.toISOString() ?? null,
    consoleUrl: DIDIT_CONSOLE_URL,
  };
}

/**
 * The summary an application page shows: whether Didit is on (required), whether the gate passes, the approved
 * check that counts and the newest check of the person (any purpose).
 */
export async function adminKycSummaryIn(
  db: Db,
  userId: string,
  purpose: KycPurpose,
  now: Date,
  personal: boolean,
): Promise<AdminKycSummaryDto> {
  const row = await kycSettingsIn(db);
  const [approved, latest] = await Promise.all([
    approvedCheckIn(db, userId, purpose, row),
    db.kycCheck.findFirst({ where: { userId }, orderBy: [{ createdAt: 'desc' }, { id: 'desc' }] }),
  ]);
  return {
    enabled: kycOn(row),
    required: kycOn(row),
    satisfied: approved !== null,
    workflowId: workflowFor(row, purpose),
    approved: approved ? await adminCheckDto(db, approved, now, personal) : null,
    latest: latest ? await adminCheckDto(db, latest, now, personal) : null,
  };
}
