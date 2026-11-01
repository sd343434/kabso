import { createHmac, hkdfSync, timingSafeEqual } from 'node:crypto';
import { z } from 'zod';
import type { KycPurpose, KycStatus } from '../../generated/prisma/client.js';
import { AdminSecretBox } from '../admin-panel/admin-crypto.js';

/**
 * v1.80-kyc (D227, CONVENTIONS §10.77): identity verification with Didit «تأكيد الهوية» — the pure rules (no I/O):
 * the settings' shapes and sealing (D196 / D222's pattern: {@link AdminSecretBox} with its own HKDF info and a per-
 * column AAD), Didit's status mapping, the webhook signature (Didit's documented `X-Signature-V2` and `X-Signature`
 * with `X-Timestamp`), what a decision keeps (the minimum) and the document hash.
 *
 * Didit's API as documented at docs.didit.me (read 2026-11-01): `POST /v3/session/` (`x-api-key`; `workflow_id`,
 * `vendor_data`, `callback`, `metadata`, `language` → 201 `session_id`, `session_number`, `session_token`, `url`,
 * `status`), `GET /v3/session/{id}/decision/` (the decision with plural arrays `id_verifications[]`,
 * `liveness_checks[]`, `face_matches[]` …; media are short-lived presigned URLs), `GET /v3/workflows/` (the
 * workflows of the key's application), webhooks `status.updated` / `data.updated` signed HMAC-SHA-256 with the
 * destination's signing key — `X-Signature-V2` over the canonical JSON (keys sorted recursively, compact, Unicode kept),
 * `X-Signature` over the raw bytes, `X-Timestamp` (Unix seconds; reject more than 300 s off).
 */

/** HKDF info of the key that seals the Didit API key and webhook secret (another key than TOTP / Stripe / storage). */
export const KYC_SETTINGS_KEY_INFO = 'kyc-settings/v1';
/** HKDF info of the key the document numbers are hashed with (HMAC; a number is never stored). */
export const KYC_DOCUMENT_KEY_INFO = 'kyc-document/v1';
/** Additional data binding each sealed value to its column. */
export const KYC_AAD = {
  apiKey: 'kyc_settings.api_key',
  webhookSecret: 'kyc_settings.webhook_secret',
} as const;

/** Didit's API (the hosted flow lives at `verify.didit.me`, the console at `business.didit.me`). */
export const DIDIT_API_BASE_URL = 'https://verification.didit.me';
export const DIDIT_CONSOLE_URL = 'https://business.didit.me';
/**
 * Where Didit sends the person at the end of the hosted flow (it appends `verificationSessionId` and `status`). The
 * app's WebView stops at this address and closes (it is never loaded); a custom scheme, as Didit documents for apps.
 */
export const KYC_CALLBACK_URL = 'kabsolive://kyc/done';
/** The webhook's path behind the API prefix (the OWNER pastes `<api>/api/v1/kyc/didit/webhook` in Didit). */
export const KYC_WEBHOOK_PATH = '/api/v1/kyc/didit/webhook';
/** A webhook whose `X-Timestamp` is further than this from now is refused (replay window, Didit's 5 minutes). */
export const KYC_WEBHOOK_TOLERANCE_SECONDS = 300;
/** The minimum age a check must show (owner: 18+). */
export const KYC_MIN_AGE = 18;
/** Delivered events are remembered this long (idempotency; Didit retries within minutes). */
export const KYC_WEBHOOK_EVENT_RETENTION_DAYS = 30;

export const KYC_PURPOSES = [
  'HOST_APPLICATION',
  'AGENCY_OPEN',
  'RECHARGE_AGENT',
] as const satisfies readonly KycPurpose[];

export const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
/** Didit API keys and webhook secrets: printable token characters (their exact shape is not documented). */
export const DIDIT_KEY_PATTERN = /^[A-Za-z0-9_.:+/=-]{16,256}$/;

/** The one string form responses and audit rows carry of a secret: `…AbCd` (never more). */
export function maskedOf(value: string | null | undefined): string | null {
  return value ? `…${value.slice(-4)}` : null;
}

export function newKycSecretBox(adminTotpKey: string | null): AdminSecretBox | null {
  return adminTotpKey ? new AdminSecretBox(adminTotpKey, KYC_SETTINGS_KEY_INFO) : null;
}

/** The key document numbers are HMAC'ed with (null without ADMIN_TOTP_KEY: Didit then cannot be turned on). */
export function documentHashKey(adminTotpKey: string | null): Buffer | null {
  return adminTotpKey
    ? Buffer.from(
        hkdfSync('sha256', Buffer.from(adminTotpKey, 'utf8'), Buffer.alloc(0), KYC_DOCUMENT_KEY_INFO, 32),
      )
    : null;
}

/** A document number as compared: upper-case, letters and digits only. */
export function normalizeDocumentNumber(raw: string): string {
  return raw
    .normalize('NFKC')
    .toUpperCase()
    .replace(/[^\p{L}\p{N}]/gu, '');
}

/** HMAC-SHA-256 (hex) of `<country>:<number>` — the same document on two accounts gives the same hash. */
export function documentHash(key: Buffer, country: string | null, number: string): string | null {
  const n = normalizeDocumentNumber(number);
  if (n.length < 3) return null;
  return createHmac('sha256', key)
    .update(`${(country ?? '').toUpperCase()}:${n}`, 'utf8')
    .digest('hex');
}

export function ageOn(dateOfBirth: Date, now: Date): number {
  const y = now.getUTCFullYear() - dateOfBirth.getUTCFullYear();
  const beforeBirthday =
    now.getUTCMonth() < dateOfBirth.getUTCMonth() ||
    (now.getUTCMonth() === dateOfBirth.getUTCMonth() && now.getUTCDate() < dateOfBirth.getUTCDate());
  return beforeBirthday ? y - 1 : y;
}

// ---- the settings row ------------------------------------------------------------------------------------------

/** The stored row (`kyc_settings`, id 1), as Prisma returns it. */
export interface KycSettingsRow {
  readonly enabled: boolean;
  readonly apiKeyEnc: string | null;
  readonly apiKeyLast4: string | null;
  readonly apiKeySetById: string | null;
  readonly apiKeySetAt: Date | null;
  readonly webhookSecretEnc: string | null;
  readonly webhookSecretLast4: string | null;
  readonly webhookSecretSetById: string | null;
  readonly webhookSecretSetAt: Date | null;
  readonly workflowId: string | null;
  readonly workflowIdHost: string | null;
  readonly workflowIdAgency: string | null;
  readonly workflowIdRecharge: string | null;
  readonly maxSessionsPerDay: number;
  readonly lastTestAt: Date | null;
  readonly lastTestOk: boolean | null;
  readonly lastTestById: string | null;
  readonly lastTest: unknown;
  readonly updatedAt: Date;
}

export const DEFAULT_MAX_SESSIONS_PER_DAY = 3;

type WorkflowRow = Pick<
  KycSettingsRow,
  'workflowId' | 'workflowIdHost' | 'workflowIdAgency' | 'workflowIdRecharge'
>;

/** The workflow a purpose runs on: its own, else the default. */
export function workflowFor(row: WorkflowRow | null, purpose: KycPurpose): string | null {
  if (!row) return null;
  const own =
    purpose === 'HOST_APPLICATION'
      ? row.workflowIdHost
      : purpose === 'AGENCY_OPEN'
        ? row.workflowIdAgency
        : row.workflowIdRecharge;
  return own ?? row.workflowId;
}

/**
 * Whether an approved check counts for `purpose`: it was made for it, or it ran on the workflow the purpose runs on
 * now (the same checks: with one workflow for all, one approval serves the three applications).
 */
export function countsFor(
  check: { purpose: KycPurpose; workflowId: string },
  purpose: KycPurpose,
  row: WorkflowRow | null,
): boolean {
  if (check.purpose === purpose) return true;
  const wf = workflowFor(row, purpose);
  return wf !== null && wf.toLowerCase() === check.workflowId.toLowerCase();
}

/** The fields still needed to turn Didit on. */
export function missingFields(v: {
  apiKey: boolean;
  webhookSecret: boolean;
  workflowId: string | null;
}): string[] {
  const out: string[] = [];
  if (!v.apiKey) out.push('apiKey');
  if (!v.webhookSecret) out.push('webhookSecret');
  if (!v.workflowId) out.push('workflowId');
  return out;
}

// ---- Didit's statuses ----------------------------------------------------------------------------------------------

/** Didit's session statuses (case-sensitive, docs.didit.me «Session statuses»). */
export const DIDIT_STATUSES = [
  'Not Started',
  'In Progress',
  'Awaiting User',
  'In Review',
  'Approved',
  'Declined',
  'Resubmitted',
  'Expired',
  'Kyc Expired',
  'Abandoned',
] as const;

/** Didit's status → ours (null: a value Didit may add later — kept as is, nothing changes). */
export function statusOf(diditStatus: string): KycStatus | null {
  switch (diditStatus.trim().toLowerCase()) {
    case 'not started':
      return 'NOT_STARTED';
    case 'in progress':
    case 'awaiting user':
    case 'resubmitted':
      return 'IN_PROGRESS';
    case 'in review':
      return 'IN_REVIEW';
    case 'approved':
      return 'APPROVED';
    case 'declined':
      return 'DECLINED';
    case 'expired':
    case 'kyc expired':
      return 'EXPIRED';
    case 'abandoned':
      return 'ABANDONED';
    default:
      return null;
  }
}

/** Statuses a person may start again after (subject to the daily limit). */
export const RETRYABLE: ReadonlySet<KycStatus> = new Set(['DECLINED', 'EXPIRED', 'ABANDONED']);
/** Statuses that are still running at Didit (the same session is opened again). */
export const UNFINISHED: ReadonlySet<KycStatus> = new Set(['NOT_STARTED', 'IN_PROGRESS']);
/** Statuses with a decision (and `decided_at`). */
export const DECIDED: ReadonlySet<KycStatus> = new Set(['APPROVED', 'DECLINED', 'IN_REVIEW']);

// ---- the webhook signature -------------------------------------------------------------------------------------------

/** Keys sorted recursively, as Didit re-encodes the body before signing (`X-Signature-V2`). */
function sortKeys(value: unknown): unknown {
  if (Array.isArray(value)) return value.map(sortKeys);
  if (value !== null && typeof value === 'object') {
    const out: Record<string, unknown> = {};
    for (const k of Object.keys(value).sort()) {
      out[k] = sortKeys((value as Record<string, unknown>)[k]);
    }
    return out;
  }
  return value;
}

/**
 * Didit's canonical JSON: keys sorted recursively, compact separators, Unicode not escaped, whole-valued floats as
 * integers (JSON.parse already reads `1.0` as `1`).
 */
export function canonicalJson(body: unknown): string {
  return JSON.stringify(sortKeys(body));
}

function hmacHex(secret: string, data: string | Buffer): string {
  return createHmac('sha256', secret).update(data).digest('hex');
}

function sameHex(expected: string, given: string): boolean {
  const a = Buffer.from(expected, 'utf8');
  const b = Buffer.from(given.trim().toLowerCase(), 'utf8');
  return a.length === b.length && timingSafeEqual(a, b);
}

export type WebhookCheck =
  | { readonly ok: true; readonly scheme: 'v2' | 'raw' }
  | {
      readonly ok: false;
      readonly issue: 'missing_timestamp' | 'stale_timestamp' | 'missing_signature' | 'invalid_signature';
    };

/**
 * Verifies a delivery: `X-Timestamp` within {@link KYC_WEBHOOK_TOLERANCE_SECONDS} of now (replays refused), then
 * `X-Signature-V2` over the canonical JSON, else `X-Signature` over the raw bytes (each tried with every secret
 * given: the current one only, today). The deprecated `X-Signature-Simple` signs only the envelope and is not
 * accepted. Constant-time comparisons.
 */
export function verifyWebhook(
  input: {
    readonly raw: Buffer;
    readonly parsed: unknown;
    readonly timestamp: string | undefined;
    readonly signatureV2: string | undefined;
    readonly signature: string | undefined;
  },
  secrets: readonly string[],
  nowMs: number,
): WebhookCheck {
  const ts = input.timestamp?.trim();
  if (!ts || !/^\d{1,12}$/.test(ts)) return { ok: false, issue: 'missing_timestamp' };
  if (Math.abs(Math.floor(nowMs / 1000) - Number(ts)) > KYC_WEBHOOK_TOLERANCE_SECONDS) {
    return { ok: false, issue: 'stale_timestamp' };
  }
  if (!input.signatureV2 && !input.signature) return { ok: false, issue: 'missing_signature' };
  for (const secret of secrets) {
    if (input.signatureV2 && sameHex(hmacHex(secret, canonicalJson(input.parsed)), input.signatureV2)) {
      return { ok: true, scheme: 'v2' };
    }
    if (input.signature && sameHex(hmacHex(secret, input.raw), input.signature)) {
      return { ok: true, scheme: 'raw' };
    }
  }
  return { ok: false, issue: 'invalid_signature' };
}

/** Signs a body as Didit does (`X-Signature-V2`) — for the tests' fake Didit and the panel's self-check. */
export function signWebhookV2(secret: string, body: unknown): string {
  return hmacHex(secret, canonicalJson(body));
}

// ---- what a decision keeps -------------------------------------------------------------------------------------------

/** The minimum a decision keeps (no image, no address, no number). */
export interface DecisionFacts {
  readonly status: KycStatus | null;
  readonly providerStatus: string;
  readonly reasons: string[];
  readonly fullName: string | null;
  readonly dateOfBirth: Date | null;
  readonly documentCountry: string | null;
  readonly documentNumber: string | null;
  readonly sessionNumber: number | null;
}

type Json = Record<string, unknown>;
const obj = (v: unknown): Json | null =>
  v !== null && typeof v === 'object' && !Array.isArray(v) ? (v as Json) : null;
const arr = (v: unknown): unknown[] => (Array.isArray(v) ? v : []);
const text = (v: unknown, max: number): string | null => {
  if (typeof v !== 'string') return null;
  const s = v
    // Control characters (C0 and DEL) become spaces.
    .replace(/\p{Cc}/gu, ' ')
    .replace(/\s+/g, ' ')
    .trim();
  return s === '' ? null : s.slice(0, max);
};

function calendarDay(raw: unknown): Date | null {
  if (typeof raw !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(raw)) return null;
  const d = new Date(`${raw}T00:00:00.000Z`);
  return Number.isNaN(d.getTime()) || d.toISOString().slice(0, 10) !== raw ? null : d;
}

/** The feature arrays a decision may carry (v3 plural arrays; the warnings of each item are the reasons). */
const FEATURE_ARRAYS = [
  'id_verifications',
  'nfc_verifications',
  'liveness_checks',
  'face_matches',
  'aml_screenings',
  'ip_analyses',
  'database_validations',
  'phone_verifications',
  'email_verifications',
  'poa_verifications',
] as const;

/**
 * What we keep of a decision (a webhook's `decision`, or `GET /v3/session/{id}/decision/`): the status, the warning
 * codes (`risk`) of a declined or reviewed session, and from the first document the name, the date of birth, the
 * issuing state and the document number (hashed by the caller, never stored). Unknown shapes give nulls.
 */
export function factsOf(diditStatus: string, decision: unknown): DecisionFacts {
  const d = obj(decision);
  const status = statusOf(diditStatus);
  const reasons: string[] = [];
  if (d && (status === 'DECLINED' || status === 'IN_REVIEW')) {
    for (const key of FEATURE_ARRAYS) {
      for (const item of arr(d[key])) {
        for (const w of arr(obj(item)?.warnings)) {
          const risk = text(obj(w)?.risk, 64);
          if (risk && /^[A-Z0-9_]+$/.test(risk) && !reasons.includes(risk)) reasons.push(risk);
        }
      }
    }
  }
  const idv = obj(arr(d?.id_verifications)[0]);
  const first = text(idv?.first_name, 100);
  const last = text(idv?.last_name, 100);
  const fullName = text(idv?.full_name, 200) ?? ([first, last].filter(Boolean).join(' ') || null);
  const country = text(idv?.issuing_state, 3)?.toUpperCase() ?? null;
  const number = number_(idv?.document_number) ?? number_(idv?.personal_number);
  const sn = d?.session_number;
  return {
    status,
    providerStatus: diditStatus.slice(0, 32),
    reasons: reasons.slice(0, 19),
    fullName,
    dateOfBirth: calendarDay(idv?.date_of_birth),
    documentCountry: country && /^[A-Z]{3}$/.test(country) ? country : null,
    documentNumber: number,
    sessionNumber: typeof sn === 'number' && Number.isInteger(sn) ? sn : null,
  };
}

function number_(v: unknown): string | null {
  const s = text(v, 64);
  return s && normalizeDocumentNumber(s).length >= 3 ? s : null;
}

/** The short-lived image links of a decision the panel may show (never stored). */
export interface DecisionMedia {
  readonly portrait: string | null;
  readonly front: string | null;
  readonly back: string | null;
  readonly liveness: string | null;
}

const httpsUrl = (v: unknown): string | null => {
  if (typeof v !== 'string' || v.length > 4096) return null;
  try {
    return new URL(v).protocol === 'https:' ? v : null;
  } catch {
    return null;
  }
};

export function mediaOf(decision: unknown): DecisionMedia {
  const d = obj(decision);
  const idv = obj(arr(d?.id_verifications)[0]);
  const live = obj(arr(d?.liveness_checks)[0]);
  return {
    portrait: httpsUrl(idv?.portrait_image),
    front: httpsUrl(idv?.front_image),
    back: httpsUrl(idv?.back_image),
    liveness: httpsUrl(live?.reference_image),
  };
}

// ---- request shapes ------------------------------------------------------------------------------------------------

const totpCode = z.string().regex(/^[0-9]{6}$/);
const reason = z.string().trim().min(1).max(500);
const workflow = z.string().trim().toLowerCase().regex(UUID_PATTERN);

/** `StartKycSessionRequest`. */
export const startKycSchema = z.strictObject({
  purpose: z.enum(KYC_PURPOSES),
  language: z.enum(['ar', 'en']).optional(),
});
export type StartKycInput = z.infer<typeof startKycSchema>;

const settingsFields = {
  apiKey: z.string().trim().regex(DIDIT_KEY_PATTERN).optional(),
  webhookSecret: z.string().trim().regex(DIDIT_KEY_PATTERN).optional(),
  workflowId: workflow.nullable().optional(),
  workflowIdHost: workflow.nullable().optional(),
  workflowIdAgency: workflow.nullable().optional(),
  workflowIdRecharge: workflow.nullable().optional(),
};
export const WORKFLOW_FIELDS = [
  'workflowId',
  'workflowIdHost',
  'workflowIdAgency',
  'workflowIdRecharge',
] as const;
/** The fields whose change while on re-runs «اختبار الاتصال». */
export const CONNECTION_FIELDS = ['apiKey', ...WORKFLOW_FIELDS] as const;

/** `UpdateAdminKycSettingsRequest`: only the fields sent change; every change needs the code again and a reason. */
export const updateKycSettingsSchema = z
  .strictObject({
    ...settingsFields,
    maxSessionsPerDay: z.number().int().min(1).max(10).optional(),
    enabled: z.boolean().optional(),
    /** Only when NODE_ENV is not production: turn on without «اختبار الاتصال». */
    skipConnectionTest: z.boolean().optional(),
    totpCode,
    reason,
  })
  .refine(
    (b) =>
      [...Object.keys(settingsFields), 'maxSessionsPerDay', 'enabled'].some(
        (k) => (b as Record<string, unknown>)[k] !== undefined,
      ),
    { message: 'nothing to change', path: ['enabled'] },
  );
export type UpdateKycSettingsInput = z.infer<typeof updateKycSettingsSchema>;

/** «اختبار الاتصال»: the key and workflows typed so far; the rest from what is saved. */
export const testKycSettingsSchema = z.strictObject({
  apiKey: settingsFields.apiKey,
  workflowId: settingsFields.workflowId,
  workflowIdHost: settingsFields.workflowIdHost,
  workflowIdAgency: settingsFields.workflowIdAgency,
  workflowIdRecharge: settingsFields.workflowIdRecharge,
});
export type TestKycSettingsInput = z.infer<typeof testKycSettingsSchema>;

export const clearKycSettingsSchema = z.strictObject({ totpCode, reason });
export type ClearKycSettingsInput = z.infer<typeof clearKycSettingsSchema>;

// ---- «اختبار الاتصال» ---------------------------------------------------------------------------------------------

export type KycTestIssue =
  | 'bad_api_key'
  | 'unreachable'
  | 'workflow_not_found'
  | 'workflow_not_published'
  | 'workflow_archived'
  | 'error';

export interface KycTestWorkflow {
  readonly field: (typeof WORKFLOW_FIELDS)[number];
  readonly workflowId: string;
  readonly ok: boolean;
  readonly label: string | null;
  readonly features: string | null;
  readonly issue: KycTestIssue | null;
}

/** The report of «اختبار الاتصال» (kept as the last test). */
export interface KycTestReport {
  readonly ok: boolean;
  readonly at: string;
  readonly apiKeyLast4: string | null;
  readonly apiKey: { readonly ok: boolean; readonly issue: KycTestIssue | null; readonly ms: number };
  readonly workflows: KycTestWorkflow[];
}
