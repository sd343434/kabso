import { z } from 'zod';
import type { AppConfig } from '../../config/app-config.js';
import { AdminSecretBox, Secret } from '../admin-panel/admin-crypto.js';
import { s3SettingsFromEnv, type S3Settings } from '../media/s3-object-storage.js';

/**
 * v1.75-social (D222, CONVENTIONS §10.72): the media storage (Cloudflare R2 or any S3-compatible service) the OWNER
 * enters and turns on in the admin panel «التخزين (R2 / S3)» — the pure rules (no I/O): the shapes, the R2 endpoint,
 * the masking, the sealing and how the panel's row and the server environment resolve into the storage uploads use.
 * The pattern and the code are D196's (`payment-settings`): the same {@link AdminSecretBox} with its own HKDF info,
 * the same {@link Secret} wrapper, the same «panel over env, env as the fallback».
 */

/** HKDF info of the key that seals the panel's storage keys (a different key from the TOTP and Stripe ones). */
export const STORAGE_SETTINGS_KEY_INFO = 'storage-settings/v1';
/** Additional data binding each sealed value to its column. */
export const STORAGE_AAD = {
  accessKeyId: 'storage_settings.access_key_id',
  secretAccessKey: 'storage_settings.secret_access_key',
} as const;
/** «اختبار الاتصال» writes, reads and deletes one tiny object under this prefix in each bucket. */
export const HEALTHCHECK_PREFIX = '_healthcheck/';

export const PROVIDERS = ['R2', 'S3'] as const;
export type StorageProvider = (typeof PROVIDERS)[number];

export const ACCOUNT_ID_PATTERN = /^[a-f0-9]{32}$/;
/** S3 bucket names (3–63: lower-case letters, digits, dots, hyphens; letter or digit at both ends). */
export const BUCKET_PATTERN = /^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$/;
export const ACCESS_KEY_ID_PATTERN = /^[A-Za-z0-9+/=_.-]{8,128}$/;
export const SECRET_ACCESS_KEY_PATTERN = /^[A-Za-z0-9+/=_.-]{16,256}$/;
export const REGION_PATTERN = /^[a-z0-9-]{2,64}$/;

/** The R2 S3 endpoint of an account. */
export function r2Endpoint(accountId: string): string {
  return `https://${accountId}.r2.cloudflarestorage.com`;
}

/** The one string form responses and audit rows carry of a key: `…AbCd` (never more). */
export function maskedOf(value: string | null | undefined): string | null {
  return value ? `…${value.slice(-4)}` : null;
}

export function newStorageSecretBox(adminTotpKey: string | null): AdminSecretBox | null {
  return adminTotpKey ? new AdminSecretBox(adminTotpKey, STORAGE_SETTINGS_KEY_INFO) : null;
}

/** The stored row (`storage_settings`, id 1), as Prisma returns it. */
export interface StorageSettingsRow {
  readonly enabled: boolean;
  readonly provider: string;
  readonly accountId: string | null;
  readonly endpoint: string | null;
  readonly region: string | null;
  readonly forcePathStyle: boolean;
  readonly accessKeyIdEnc: string | null;
  readonly accessKeyIdLast4: string | null;
  readonly accessKeyIdSetById: string | null;
  readonly accessKeyIdSetAt: Date | null;
  readonly secretAccessKeyEnc: string | null;
  readonly secretAccessKeyLast4: string | null;
  readonly secretAccessKeySetById: string | null;
  readonly secretAccessKeySetAt: Date | null;
  readonly publicBucket: string | null;
  readonly publicBaseUrl: string | null;
  readonly privateBucket: string | null;
  readonly lastTestAt: Date | null;
  readonly lastTestOk: boolean | null;
  readonly lastTestById: string | null;
  readonly lastTest: unknown;
  readonly updatedAt: Date;
}

/** Where to connect (no secrets): what «اختبار الاتصال» and the audit rows describe. */
export interface StorageTarget {
  readonly provider: StorageProvider;
  readonly accountId: string | null;
  readonly endpoint: string | null;
  readonly region: string;
  readonly forcePathStyle: boolean;
  readonly publicBucket: string | null;
  readonly publicBaseUrl: string | null;
  readonly privateBucket: string | null;
}

/** The connection the panel's values describe (the R2 endpoint derived from the account id). */
export function targetOf(v: {
  provider: string;
  accountId: string | null;
  endpoint: string | null;
  region: string | null;
  forcePathStyle: boolean;
  publicBucket: string | null;
  publicBaseUrl: string | null;
  privateBucket: string | null;
}): StorageTarget {
  const provider: StorageProvider = v.provider === 'S3' ? 'S3' : 'R2';
  return provider === 'R2'
    ? {
        provider,
        accountId: v.accountId,
        endpoint: v.accountId ? r2Endpoint(v.accountId) : null,
        region: 'auto',
        forcePathStyle: false,
        publicBucket: v.publicBucket,
        publicBaseUrl: v.publicBaseUrl,
        privateBucket: v.privateBucket,
      }
    : {
        provider,
        accountId: null,
        endpoint: v.endpoint,
        region: v.region ?? 'us-east-1',
        forcePathStyle: v.forcePathStyle,
        publicBucket: v.publicBucket,
        publicBaseUrl: v.publicBaseUrl,
        privateBucket: v.privateBucket,
      };
}

/** The fields a complete (activatable) configuration needs that this one lacks. */
export function missingFields(
  t: StorageTarget,
  keys: { accessKeyId: boolean; secretAccessKey: boolean },
): string[] {
  const out: string[] = [];
  if (t.provider === 'R2' && !t.accountId) out.push('accountId');
  if (!keys.accessKeyId) out.push('accessKeyId');
  if (!keys.secretAccessKey) out.push('secretAccessKey');
  if (!t.publicBucket) out.push('publicBucket');
  if (!t.publicBaseUrl) out.push('publicBaseUrl');
  if (!t.privateBucket) out.push('privateBucket');
  return out;
}

/** The S3 settings of a complete target with its keys (two buckets: `media/` public, the rest private). */
export function s3SettingsOf(t: StorageTarget, accessKeyId: string, secretAccessKey: string): S3Settings {
  return {
    endpoint: t.endpoint ?? undefined,
    region: t.region,
    bucket: t.publicBucket ?? '',
    privateBucket: t.privateBucket,
    accessKeyId,
    secretAccessKey,
    forcePathStyle: t.forcePathStyle,
  };
}

export type StorageSource = 'panel' | 'env' | 'none';

/** What uploads run with now. `s3` holds the keys as {@link Secret}s: this object can be logged safely. */
export interface ResolvedStorage {
  readonly source: StorageSource;
  /** False: every upload is 503 `MEDIA_UPLOADS_UNAVAILABLE` («التخزين غير مفعّل»). */
  readonly uploadsEnabled: boolean;
  /** The base of every public media URL (`<base>/media/…`). */
  readonly publicBaseUrl: string | undefined;
  readonly s3: {
    readonly endpoint: string | undefined;
    readonly region: string;
    readonly bucket: string;
    readonly privateBucket: string | null;
    readonly accessKeyId: Secret;
    readonly secretAccessKey: Secret;
    readonly forcePathStyle: boolean;
  } | null;
  /** The panel is on but its keys cannot be opened (another ADMIN_TOTP_KEY): the env applies. */
  readonly panelIgnored: 'unreadable' | null;
}

export function revealS3(s3: NonNullable<ResolvedStorage['s3']>): S3Settings {
  return { ...s3, accessKeyId: s3.accessKeyId.reveal(), secretAccessKey: s3.secretAccessKey.reveal() };
}

/**
 * The source of truth (owner D222): the panel's settings when its switch is on and its keys open, else the server's
 * `S3_*` / `MEDIA_PUBLIC_BASE_URL` / `MEDIA_UPLOADS_ENABLED` exactly as before, else none.
 */
export function resolveStorageSettings(
  row: StorageSettingsRow | null,
  env: Pick<AppConfig, 'media'>,
  box: AdminSecretBox | null,
): ResolvedStorage {
  let panelIgnored: ResolvedStorage['panelIgnored'] = null;
  if (row?.enabled && row.accessKeyIdEnc && row.secretAccessKeyEnc) {
    const id = box?.open(row.accessKeyIdEnc, STORAGE_AAD.accessKeyId) ?? null;
    const secret = box?.open(row.secretAccessKeyEnc, STORAGE_AAD.secretAccessKey) ?? null;
    const t = targetOf(row);
    if (id === null || secret === null) panelIgnored = 'unreadable';
    else if (missingFields(t, { accessKeyId: true, secretAccessKey: true }).length === 0) {
      return {
        source: 'panel',
        uploadsEnabled: true,
        publicBaseUrl: t.publicBaseUrl ?? undefined,
        s3: {
          endpoint: t.endpoint ?? undefined,
          region: t.region,
          bucket: t.publicBucket!,
          privateBucket: t.privateBucket,
          accessKeyId: new Secret(id),
          secretAccessKey: new Secret(secret),
          forcePathStyle: t.forcePathStyle,
        },
        panelIgnored: null,
      };
    }
  }
  const e = s3SettingsFromEnv(env);
  return {
    source: e ? 'env' : 'none',
    uploadsEnabled: env.media.uploadsEnabled,
    publicBaseUrl: env.media.publicBaseUrl,
    s3: e
      ? {
          ...e,
          accessKeyId: new Secret(e.accessKeyId),
          secretAccessKey: new Secret(e.secretAccessKey),
        }
      : null,
    panelIgnored,
  };
}

// ---- «اختبار الاتصال» ---------------------------------------------------------------------------------------

export const TEST_STEPS = ['put', 'head', 'get', 'public_read', 'not_public', 'delete'] as const;
export type TestStepName = (typeof TEST_STEPS)[number];

/** Why a step failed, in words the panel translates. */
export const TEST_ISSUES = [
  'bad_credentials',
  'access_denied',
  'no_such_bucket',
  'unreachable',
  'mismatch',
  'not_public',
  'publicly_readable',
  'http_status',
  'error',
] as const;
export type TestIssue = (typeof TEST_ISSUES)[number];

export interface StorageTestStep {
  readonly bucket: 'public' | 'private';
  readonly step: TestStepName;
  readonly ok: boolean;
  readonly ms: number;
  readonly issue: TestIssue | null;
  /** A short technical hint (an S3 error name or an HTTP status), never a secret. */
  readonly detail: string | null;
}

export interface StorageTestReport {
  readonly ok: boolean;
  readonly at: string;
  readonly target: StorageTarget;
  readonly accessKeyIdLast4: string | null;
  readonly steps: StorageTestStep[];
}

/** An S3 SDK error (or a network failure) as a step issue. */
export function issueOfError(err: unknown): { issue: TestIssue; detail: string } {
  const e = err as { name?: string; Code?: string; $metadata?: { httpStatusCode?: number } } | null;
  const name = (e?.name ?? e?.Code ?? 'Error').slice(0, 60);
  const status = e?.$metadata?.httpStatusCode;
  if (['InvalidAccessKeyId', 'SignatureDoesNotMatch', 'InvalidToken', 'Unauthorized'].includes(name)) {
    return { issue: 'bad_credentials', detail: name };
  }
  if (name === 'NoSuchBucket') return { issue: 'no_such_bucket', detail: name };
  if (name === 'AccessDenied' || status === 403) return { issue: 'access_denied', detail: name };
  if (status === 404 && name !== 'NotFound') return { issue: 'no_such_bucket', detail: name };
  if (
    !status &&
    /ENOTFOUND|ECONNREFUSED|ECONNRESET|ETIMEDOUT|EAI_AGAIN|TimeoutError|AbortError|socket|fetch failed/i.test(
      `${name} ${(err as Error | null)?.message ?? ''}`,
    )
  ) {
    return { issue: 'unreachable', detail: name };
  }
  return { issue: 'error', detail: status ? `${name} (${status})` : name };
}

// ---- the panel's write ------------------------------------------------------------------------------------------

const totpCode = z.string().regex(/^[0-9]{6}$/);
const reason = z.string().trim().min(1).max(500);

/** An https base URL (http allowed outside production, checked by the service), no query, no trailing slash. */
const baseUrl = z
  .string()
  .trim()
  .max(300)
  .refine((v) => {
    try {
      const u = new URL(v);
      return (u.protocol === 'https:' || u.protocol === 'http:') && !u.search && !u.hash && !u.username;
    } catch {
      return false;
    }
  }, 'invalid_value')
  .transform((v) => v.replace(/\/+$/, ''));

/** The connection fields (shared by the save and the test). Null clears an optional field. */
const connectionFields = {
  provider: z.enum(PROVIDERS).optional(),
  accountId: z.string().trim().toLowerCase().regex(ACCOUNT_ID_PATTERN).nullable().optional(),
  endpoint: baseUrl.nullable().optional(),
  region: z.string().trim().regex(REGION_PATTERN).nullable().optional(),
  forcePathStyle: z.boolean().optional(),
  accessKeyId: z.string().trim().regex(ACCESS_KEY_ID_PATTERN).optional(),
  secretAccessKey: z.string().trim().regex(SECRET_ACCESS_KEY_PATTERN).optional(),
  publicBucket: z.string().trim().regex(BUCKET_PATTERN).nullable().optional(),
  publicBaseUrl: baseUrl.nullable().optional(),
  privateBucket: z.string().trim().regex(BUCKET_PATTERN).nullable().optional(),
};
export const CONNECTION_FIELDS = Object.keys(connectionFields) as (keyof typeof connectionFields)[];

/**
 * `UpdateAdminStorageSettingsRequest`: only the fields sent change. The secret is write-only. Every change needs the
 * code again and a reason. Turning on (or changing the connection while on) runs «اختبار الاتصال» first.
 */
export const updateStorageSettingsSchema = z
  .strictObject({
    ...connectionFields,
    enabled: z.boolean().optional(),
    /** Only when NODE_ENV is not production: save / turn on without the round trip. */
    skipConnectionTest: z.boolean().optional(),
    totpCode,
    reason,
  })
  .refine(
    (b) => [...CONNECTION_FIELDS, 'enabled'].some((k) => (b as Record<string, unknown>)[k] !== undefined),
    { message: 'nothing to change', path: ['enabled'] },
  );
export type UpdateStorageSettingsInput = z.infer<typeof updateStorageSettingsSchema>;

/** «اختبار الاتصال» before saving: the fields typed so far; the rest (and the stored keys) from the saved row. */
export const testStorageSettingsSchema = z.strictObject(connectionFields);
export type TestStorageSettingsInput = z.infer<typeof testStorageSettingsSchema>;

export const clearStorageSettingsSchema = z.strictObject({ totpCode, reason });
export type ClearStorageSettingsInput = z.infer<typeof clearStorageSettingsSchema>;
