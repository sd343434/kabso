import { isIP } from 'node:net';
import { ipv6Hextets } from '../common/http/request-context.js';
import { availableParallelism } from 'node:os';
import { z } from 'zod';
import { MIN_SECRET_BYTES, productionSecretProblem } from './secret-strength.js';

/** A rate-limit rule: at most `max` requests per `windowSeconds`. */
export interface RateLimitRule {
  readonly max: number;
  readonly windowSeconds: number;
}

const rateLimit = (fallback: string) =>
  z
    .string()
    .trim()
    .default(fallback)
    .transform((value, ctx): RateLimitRule => {
      const match = /^(\d{1,7})\/(\d{1,7})$/.exec(value);
      const max = Number(match?.[1]);
      const windowSeconds = Number(match?.[2]);
      if (!match || max < 1 || windowSeconds < 1) {
        ctx.addIssue({
          code: 'custom',
          message: `expected "<max>/<windowSeconds>" with positive integers, got "${value}"`,
        });
        return z.NEVER;
      }
      return { max, windowSeconds };
    });

/**
 * A plain decimal integer setting: digits only, no sign, exponent, hex prefix, padding or leading
 * zeros (`z.coerce.number()` accepted `1e3`, `0x10`, ` 15 ` and the empty string as 0). Bounded.
 */
export const intSetting = (fallback: number, min: number, max: number = Number.MAX_SAFE_INTEGER) =>
  z
    .string()
    .regex(/^(0|[1-9][0-9]{0,15})$/, 'must be a plain decimal integer (digits only)')
    .default(String(fallback))
    .transform(Number)
    .pipe(z.number().int().min(min).max(max));

const positiveInt = (fallback: number) => intSetting(fallback, 1);

/** `"true"` / `"false"` switch (default as given). */
const booleanSwitch = (fallback: 'true' | 'false') =>
  z
    .enum(['true', 'false'], { error: 'must be "true" or "false"' })
    .default(fallback)
    .transform((v) => v === 'true');

/** An optional, non-empty trimmed string (empty means unset). */
const optionalText = (max: number) =>
  z
    .string()
    .trim()
    .max(max)
    .optional()
    .transform((v) => (v === undefined || v === '' ? undefined : v));

/** An optional absolute http(s) URL without query, fragment or credentials (empty means unset). */
const optionalBaseUrl = z
  .string()
  .trim()
  .optional()
  .transform((v, ctx) => {
    if (v === undefined || v === '') return undefined;
    let url: URL;
    try {
      url = new URL(v);
    } catch {
      ctx.addIssue({ code: 'custom', message: 'must be an absolute URL' });
      return z.NEVER;
    }
    if (url.protocol !== 'https:' && url.protocol !== 'http:') {
      ctx.addIssue({ code: 'custom', message: 'must be an http(s) URL' });
      return z.NEVER;
    }
    if (url.search !== '' || url.hash !== '' || v.includes('?') || v.includes('#')) {
      ctx.addIssue({ code: 'custom', message: 'must not have a query or fragment' });
      return z.NEVER;
    }
    if (url.username !== '' || url.password !== '') {
      ctx.addIssue({ code: 'custom', message: 'must not contain credentials' });
      return z.NEVER;
    }
    return `${url.origin}${url.pathname.replace(/\/+$/, '')}`;
  });

/** S3 bucket name (the DNS-compatible subset accepted by S3 and Cloudflare R2); empty means unset. */
const optionalBucket = optionalText(63).refine(
  (v) => v === undefined || /^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$/.test(v),
  'must be a valid bucket name',
);

/** Storage settings required when MEDIA_UPLOADS_ENABLED=true (DB_PHASE2_MEDIA §5). */
export const MEDIA_STORAGE_REQUIRED = [
  'MEDIA_STORAGE_REGION',
  'MEDIA_STORAGE_INCOMING_BUCKET',
  'MEDIA_STORAGE_PUBLIC_BUCKET',
  'MEDIA_STORAGE_ACCESS_KEY_ID',
  'MEDIA_STORAGE_SECRET_ACCESS_KEY',
  'MEDIA_PUBLIC_BASE_URL',
] as const;
const nonNegativeInt = (fallback: number) => intSetting(fallback, 0);

/** SEC-035: bounds of LIVE_SWEEP_BATCH_SIZE (rooms ended per sweeper transaction). */
export const LIVE_SWEEP_BATCH_SIZE_MIN = 1;
export const LIVE_SWEEP_BATCH_SIZE_MAX = 5000;

/**
 * Heartbeat headroom: in production the per-user heartbeat bucket must allow at least this many
 * times the expected cadence (one beat per LIVE_HEARTBEAT_INTERVAL_SECONDS), so client retries
 * never hit 429 (CONVENTIONS §7: 12 / min at a 15 s cadence = 3×).
 */
export const HEARTBEAT_RATE_LIMIT_HEADROOM = 2;

/**
 * SEC-003a (contract v1.2.3): a trusted-proxy range is too broad for production when it is an
 * IPv4 prefix shorter than /8, an IPv6 prefix shorter than /32, or an IPv4-mapped IPv6 range
 * (`::ffff:a.b.c.d/n`, n ≥ 96) whose IPv4 equivalent is shorter than /8 (e.g. `::ffff:0:0/96`).
 */
export function isOverlyBroadProxyRange(entry: string): boolean {
  const [address = '', prefixText] = entry.split('/');
  if (prefixText === undefined) return false;
  const prefix = Number(prefixText);
  const family = isIP(address);
  if (family === 4) return prefix < 8;
  if (family !== 6) return false;
  const groups = ipv6Hextets(address);
  const mapped = groups !== null && groups.slice(0, 5).every((g) => g === 0) && groups[5] === 0xffff;
  if (mapped && prefix >= 96) return prefix - 96 < 8;
  return prefix < 32;
}

const TRUST_PROXY_KEYWORDS = new Set(['loopback', 'linklocal', 'uniquelocal']);

/** True for an IP address, an IP/prefix CIDR, or one of Express' proxy keywords. */
export function isTrustedProxyEntry(entry: string): boolean {
  if (TRUST_PROXY_KEYWORDS.has(entry)) return true;
  const [address = '', prefix, ...rest] = entry.split('/');
  const family = isIP(address);
  if (family === 0 || rest.length > 0) return false;
  if (prefix === undefined) return true;
  if (!/^\d{1,3}$/.test(prefix)) return false;
  return Number(prefix) <= (family === 4 ? 32 : 128);
}

/**
 * Express `trust proxy`: `false` | `true` | hop count | comma-separated addresses/CIDRs/keywords.
 * `true` (trust every hop, i.e. the client-controlled left-most X-Forwarded-For) is refused in
 * production by the schema refinement below (SEC-003, CONVENTIONS §7).
 */
const trustProxy = z
  .string()
  .trim()
  .default('false')
  .transform((value, ctx): boolean | number | string[] => {
    if (value === '' || value === 'false') return false;
    if (value === 'true') return true;
    if (/^\d+$/.test(value)) return Number(value);
    const entries = value
      .split(',')
      .map((part) => part.trim())
      .filter(Boolean);
    const invalid = entries.filter((entry) => !isTrustedProxyEntry(entry));
    if (invalid.length > 0) {
      ctx.addIssue({
        code: 'custom',
        message: `expected false, a hop count, or IPs/CIDRs (loopback|linklocal|uniquelocal); invalid: ${invalid.join(', ')}`,
      });
      return z.NEVER;
    }
    return entries;
  });

export const envSchema = z
  .object({
    NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
    PORT: intSetting(3000, 1, 65535),
    LOG_LEVEL: z.enum(['fatal', 'error', 'warn', 'info', 'debug', 'trace', 'silent']).default('info'),

    DATABASE_URL: z
      .string()
      .trim()
      .min(1, 'is required')
      .refine((v) => /^postgres(ql)?:\/\//.test(v), 'must be a postgresql:// URL'),
    REDIS_URL: z
      .string()
      .trim()
      .min(1, 'is required')
      .refine((v) => /^rediss?:\/\//.test(v), 'must be a redis:// or rediss:// URL'),
    /** Prefix for every Redis key written by this process (isolates environments/tests). */
    REDIS_KEY_PREFIX: z
      .string()
      .trim()
      .regex(/^[A-Za-z0-9:_-]{1,64}$/)
      .default('kabso:'),

    JWT_ACCESS_SECRET: z
      .string()
      .min(1, 'is required')
      .refine((v) => Buffer.byteLength(v, 'utf8') >= 32, 'must be at least 32 bytes'),
    /** HMAC key for rate-limit subject keys (SEC-010). Required in production. */
    RATE_LIMIT_KEY_SECRET: z
      .string()
      .min(1)
      .refine((v) => Buffer.byteLength(v, 'utf8') >= MIN_SECRET_BYTES, 'must be at least 32 bytes')
      .optional(),
    JWT_ACCESS_TTL_SECONDS: positiveInt(900),
    REFRESH_TTL_SECONDS: positiveInt(30 * 24 * 3600),
    REFRESH_ABSOLUTE_TTL_SECONDS: positiveInt(180 * 24 * 3600),
    EMAIL_VERIFY_TOKEN_TTL_SECONDS: positiveInt(24 * 3600),
    PASSWORD_RESET_TOKEN_TTL_SECONDS: positiveInt(3600),

    APP_PUBLIC_URL: z.url({ protocol: /^https?$/ }).transform((v) => v.replace(/\/+$/, '')),
    MAIL_TRANSPORT: z.enum(['log']).default('log'),

    CORS_ORIGINS: z
      .string()
      .default('')
      .transform((v) =>
        v
          .split(',')
          .map((o) => o.trim())
          .filter(Boolean),
      ),
    TRUST_PROXY: trustProxy,
    BODY_LIMIT: z
      .string()
      .trim()
      .regex(/^\d+(b|kb|mb)$/i)
      .default('100kb'),

    RATE_LIMIT_LOGIN_IP_ACCOUNT: rateLimit('10/900'),
    RATE_LIMIT_LOGIN_ACCOUNT: rateLimit('20/900'),
    RATE_LIMIT_LOGIN_IP: rateLimit('50/900'),
    RATE_LIMIT_REGISTER_IP: rateLimit('5/3600'),
    RATE_LIMIT_FORGOT_EMAIL: rateLimit('3/3600'),
    RATE_LIMIT_FORGOT_IP: rateLimit('10/3600'),
    RATE_LIMIT_REFRESH_SESSION: rateLimit('60/900'),
    RATE_LIMIT_AUTHENTICATED_USER: rateLimit('600/900'),
    RATE_LIMIT_EMAIL_RESEND_USER: rateLimit('5/3600'),
    RATE_LIMIT_PUBLIC_IP: rateLimit('300/900'),
    // v1.2 (CONVENTIONS §7)
    RATE_LIMIT_REGISTER_EMAIL: rateLimit('3/3600'),
    RATE_LIMIT_REGISTER_VERIFY_IP: rateLimit('10/900'),
    RATE_LIMIT_REGISTER_VERIFY_EMAIL: rateLimit('15/86400'),
    RATE_LIMIT_REGISTER_RESEND_EMAIL: rateLimit('3/3600'),
    RATE_LIMIT_REGISTER_RESEND_IP: rateLimit('10/3600'),
    RATE_LIMIT_UPDATE_ME_USER: rateLimit('30/3600'),
    // v1.3 (CONVENTIONS §7): per-user buckets that replace the default authenticated bucket.
    RATE_LIMIT_LIVE_LIST_USER: rateLimit('300/900'),
    RATE_LIMIT_PROFILE_USER: rateLimit('300/900'),
    RATE_LIMIT_LIVE_START_HOUR_USER: rateLimit('10/3600'),
    RATE_LIMIT_LIVE_START_DAY_USER: rateLimit('30/86400'),
    RATE_LIMIT_LIVE_HEARTBEAT_USER: rateLimit('12/60'),
    RATE_LIMIT_LIVE_END_USER: rateLimit('30/3600'),
    RATE_LIMIT_FOLLOW_HOUR_USER: rateLimit('60/3600'),
    RATE_LIMIT_FOLLOW_DAY_USER: rateLimit('300/86400'),
    // v1.4 (CONVENTIONS §7): per-user buckets that replace the default authenticated bucket.
    RATE_LIMIT_MEDIA_UPLOAD_HOUR_USER: rateLimit('20/3600'),
    RATE_LIMIT_MEDIA_UPLOAD_DAY_USER: rateLimit('60/86400'),
    RATE_LIMIT_MEDIA_COMPLETE_USER: rateLimit('30/3600'),
    RATE_LIMIT_LIVE_COVER_USER: rateLimit('20/3600'),
    RATE_LIMIT_LIVE_COUNTRIES_USER: rateLimit('300/900'),

    // ---- v1.4 media uploads (CONVENTIONS §11, DB_PHASE2_MEDIA §5) ------------------------------
    /**
     * Uploads are available only when exactly "true". Default off (D44/D45: no storage provider is
     * activated). "true" requires every storage setting below, otherwise the API refuses to boot.
     */
    MEDIA_UPLOADS_ENABLED: booleanSwitch('false'),
    /** `none`: images stay PENDING (owner-only). `allow_all`: dev/test only, refused in production. */
    MEDIA_MODERATION_PROVIDER: z.enum(['none', 'allow_all']).default('none'),
    /** S3-compatible endpoint (e.g. Cloudflare R2). Unset = the SDK's AWS default. https in production. */
    MEDIA_STORAGE_ENDPOINT: optionalBaseUrl,
    MEDIA_STORAGE_REGION: optionalText(64),
    MEDIA_STORAGE_FORCE_PATH_STYLE: booleanSwitch('false'),
    MEDIA_STORAGE_INCOMING_BUCKET: optionalBucket,
    MEDIA_STORAGE_PUBLIC_BUCKET: optionalBucket,
    /** Secret (secret manager, PP-09). No default, never logged. */
    MEDIA_STORAGE_ACCESS_KEY_ID: optionalText(256),
    /** Secret (secret manager, PP-09). No default, never logged. */
    MEDIA_STORAGE_SECRET_ACCESS_KEY: optionalText(256),
    /** Base of every public image URL (CDN / custom domain); https and not the API host in production. */
    MEDIA_PUBLIC_BASE_URL: optionalBaseUrl,
    MEDIA_UPLOAD_URL_TTL_SECONDS: intSetting(600, 60, 900),
    MEDIA_MAX_PENDING_PER_USER: intSetting(5, 1, 20),
    MEDIA_DAILY_BYTES_PER_USER: intSetting(104_857_600, 10_485_760, 1_073_741_824),
    MEDIA_PROCESS_MAX_CONCURRENCY: intSetting(2, 1, 16),
    MEDIA_PROCESS_TIMEOUT_MS: intSetting(10_000, 1000, 60_000),
    MEDIA_UNATTACHED_TTL_HOURS: intSetting(24, 1, 168),
    MEDIA_DELETE_GRACE_HOURS: intSetting(24, 1, 168),
    MEDIA_ENDED_ROOM_COVER_TTL_HOURS: intSetting(24, 0, 168),
    /** Period of the media cleanup job: 60–3600 s; 0 disables it (tests only; refused in production). */
    MEDIA_CLEANUP_INTERVAL_SECONDS: intSetting(300, 0, 3600).refine(
      (v) => v === 0 || v >= 60,
      'must be 0 (disabled) or 60–3600',
    ),
    MEDIA_CLEANUP_BATCH_SIZE: intSetting(500, 1, 5000),

    /**
     * v1.3 (CONVENTIONS §10, B1): going live and heartbeats are refused with 503
     * LIVE_HOSTING_UNAVAILABLE unless this is exactly "true". Default off: there is no media
     * provider yet, so production must not list rooms that cannot play.
     */
    LIVE_HOSTING_ENABLED: z
      .enum(['true', 'false'], { error: 'must be "true" or "false"' })
      .default('false')
      .transform((v) => v === 'true'),
    /** Heartbeat cadence the client is told to use (GET /live/config). */
    LIVE_HEARTBEAT_INTERVAL_SECONDS: intSetting(15, 5, 60),
    /** A LIVE room without a heartbeat for this long is stale (never listed, ended). */
    LIVE_HEARTBEAT_STALE_SECONDS: intSetting(45, 1, 3600),
    /** Period of the in-process stale-room sweeper; 0 disables it (refused in production). */
    LIVE_SWEEP_INTERVAL_SECONDS: intSetting(15, 0, 3600),
    /**
     * SEC-035 (CONVENTIONS §10.2, D43): the sweeper ends at most this many stale rooms per batch,
     * each batch in its own short transaction. Bounded so one batch always fits its timeout.
     */
    LIVE_SWEEP_BATCH_SIZE: intSetting(500, LIVE_SWEEP_BATCH_SIZE_MIN, LIVE_SWEEP_BATCH_SIZE_MAX),
    /**
     * Optional dedicated source of the HMAC key (HKDF, info `live-cursor/v1`) that signs list
     * cursors (CONVENTIONS §10.4; same pattern as REGISTRATION_CODE_KEY). When unset, the key is
     * derived from RATE_LIMIT_KEY_SECRET with that distinct HKDF label (DB_PHASE2_DISCOVERY §4).
     * In production a set value must pass the secret-strength checks and differ from the other
     * secrets. Rotating the source only invalidates outstanding cursors (clients get 400 cursor
     * and reload from the first page).
     */
    LIVE_CURSOR_KEY: z
      .string()
      .min(1)
      .refine((v) => Buffer.byteLength(v, 'utf8') >= MIN_SECRET_BYTES, 'must be at least 32 bytes')
      .optional(),

    /** Pending registration lifetime (contract: 30 min). */
    REGISTRATION_TTL_SECONDS: positiveInt(30 * 60),
    /** Absolute lifetime of a pending registration from creation; resend never extends it (2 h). */
    REGISTRATION_MAX_LIFETIME_SECONDS: positiveInt(2 * 3600),
    /**
     * Optional dedicated key for registration-code HMACs (SEC-029). When unset, the key is derived
     * from RATE_LIMIT_KEY_SECRET. Changing either invalidates every live pending code.
     */
    REGISTRATION_CODE_KEY: z
      .string()
      .min(1)
      .refine((v) => Buffer.byteLength(v, 'utf8') >= MIN_SECRET_BYTES, 'must be at least 32 bytes')
      .optional(),
    /** At most one "account already exists" notice per account per interval (contract: 1 h). */
    REGISTRATION_NOTICE_INTERVAL_SECONDS: positiveInt(3600),
    /** Periodic deletion of expired pending registrations; 0 disables the job. */
    REGISTRATION_CLEANUP_INTERVAL_SECONDS: nonNegativeInt(600),
    /** A source that logged into an account within this window bypasses the account bucket. */
    LOGIN_RECENT_SUCCESS_TTL_SECONDS: positiveInt(30 * 24 * 3600),
    /**
     * Reserved display-name terms (comma-separated; matched after NFKC casefold + confusable
     * skeleton). Defaults to the CONVENTIONS §6 list (v1.2.4: without `staff` and `مشرف`, QA-012; v1.2.6: without `رسمي`, SEC-032).
     */
    /** Brand terms also matched as a prefix/suffix of the separator-free name (v1.2.1). */
    RESERVED_DISPLAY_NAME_BRAND_TERMS: z
      .string()
      .default('kabso,كابسو')
      .transform((v) =>
        v
          .split(',')
          .map((t) => t.trim())
          .filter(Boolean),
      ),
    RESERVED_DISPLAY_NAME_TERMS: z
      .string()
      .default('kabso,admin,administrator,support,official,moderator,كابسو,الدعم,الإدارة')
      .transform((v) =>
        v
          .split(',')
          .map((t) => t.trim())
          .filter(Boolean),
      ),

    /** Concurrent Argon2 operations per process (SEC-002); default = available CPUs. */
    ARGON2_MAX_CONCURRENCY: intSetting(Math.min(availableParallelism(), 256), 1, 256),
    /** Operations allowed to wait for a slot; beyond this → 503 SERVICE_UNAVAILABLE. */
    ARGON2_MAX_QUEUE: nonNegativeInt(availableParallelism() * 4),
  })
  .superRefine((env, ctx) => {
    if (env.REFRESH_ABSOLUTE_TTL_SECONDS < env.REFRESH_TTL_SECONDS) {
      ctx.addIssue({
        code: 'custom',
        path: ['REFRESH_ABSOLUTE_TTL_SECONDS'],
        message: 'must be >= REFRESH_TTL_SECONDS',
      });
    }
    if (env.LIVE_HEARTBEAT_STALE_SECONDS < 2 * env.LIVE_HEARTBEAT_INTERVAL_SECONDS) {
      ctx.addIssue({
        code: 'custom',
        path: ['LIVE_HEARTBEAT_STALE_SECONDS'],
        message: 'must be at least 2 × LIVE_HEARTBEAT_INTERVAL_SECONDS',
      });
    }
    // v1.4 (CONVENTIONS §11.1, DB_PHASE2_MEDIA §5): "enabled but not configured" cannot happen.
    if (env.MEDIA_UPLOADS_ENABLED) {
      for (const name of MEDIA_STORAGE_REQUIRED) {
        if (env[name] === undefined) {
          ctx.addIssue({
            code: 'custom',
            path: [name],
            message: 'is required when MEDIA_UPLOADS_ENABLED=true',
          });
        }
      }
    }
    if (
      env.MEDIA_STORAGE_INCOMING_BUCKET !== undefined &&
      env.MEDIA_STORAGE_INCOMING_BUCKET === env.MEDIA_STORAGE_PUBLIC_BUCKET
    ) {
      ctx.addIssue({
        code: 'custom',
        path: ['MEDIA_STORAGE_INCOMING_BUCKET'],
        message: 'must differ from MEDIA_STORAGE_PUBLIC_BUCKET',
      });
    }
    if (
      (env.MEDIA_STORAGE_ACCESS_KEY_ID === undefined) !==
      (env.MEDIA_STORAGE_SECRET_ACCESS_KEY === undefined)
    ) {
      ctx.addIssue({
        code: 'custom',
        path: ['MEDIA_STORAGE_SECRET_ACCESS_KEY'],
        message: 'MEDIA_STORAGE_ACCESS_KEY_ID and MEDIA_STORAGE_SECRET_ACCESS_KEY must be set together',
      });
    }
    if (env.NODE_ENV === 'production') {
      if (env.MEDIA_MODERATION_PROVIDER === 'allow_all') {
        ctx.addIssue({
          code: 'custom',
          path: ['MEDIA_MODERATION_PROVIDER'],
          message: '"allow_all" approves images without any content check and is refused in production',
        });
      }
      if (env.MEDIA_STORAGE_ENDPOINT !== undefined && !env.MEDIA_STORAGE_ENDPOINT.startsWith('https://')) {
        ctx.addIssue({
          code: 'custom',
          path: ['MEDIA_STORAGE_ENDPOINT'],
          message: 'must be https in production',
        });
      }
      if (env.MEDIA_PUBLIC_BASE_URL !== undefined) {
        const base = new URL(env.MEDIA_PUBLIC_BASE_URL);
        if (base.protocol !== 'https:') {
          ctx.addIssue({
            code: 'custom',
            path: ['MEDIA_PUBLIC_BASE_URL'],
            message: 'must be https in production',
          });
        } else if (base.hostname.toLowerCase() === new URL(env.APP_PUBLIC_URL).hostname.toLowerCase()) {
          ctx.addIssue({
            code: 'custom',
            path: ['MEDIA_PUBLIC_BASE_URL'],
            message: 'must be on a host other than the API host (APP_PUBLIC_URL): media is served cookieless',
          });
        }
      }
      if (env.MEDIA_CLEANUP_INTERVAL_SECONDS === 0) {
        ctx.addIssue({
          code: 'custom',
          path: ['MEDIA_CLEANUP_INTERVAL_SECONDS'],
          message: 'the media cleanup job cannot be disabled in production',
        });
      }
    }
    if (env.NODE_ENV === 'production') {
      const jwtProblem = productionSecretProblem(env.JWT_ACCESS_SECRET);
      if (jwtProblem) ctx.addIssue({ code: 'custom', path: ['JWT_ACCESS_SECRET'], message: jwtProblem });

      if (env.RATE_LIMIT_KEY_SECRET === undefined) {
        ctx.addIssue({
          code: 'custom',
          path: ['RATE_LIMIT_KEY_SECRET'],
          message: 'is required in production',
        });
      } else {
        const rlProblem = productionSecretProblem(env.RATE_LIMIT_KEY_SECRET);
        if (rlProblem) ctx.addIssue({ code: 'custom', path: ['RATE_LIMIT_KEY_SECRET'], message: rlProblem });
        else if (env.RATE_LIMIT_KEY_SECRET === env.JWT_ACCESS_SECRET) {
          ctx.addIssue({
            code: 'custom',
            path: ['RATE_LIMIT_KEY_SECRET'],
            message: 'must differ from JWT_ACCESS_SECRET',
          });
        }
      }

      if (env.REGISTRATION_CODE_KEY !== undefined) {
        const codeKeyProblem = productionSecretProblem(env.REGISTRATION_CODE_KEY);
        if (codeKeyProblem) {
          ctx.addIssue({ code: 'custom', path: ['REGISTRATION_CODE_KEY'], message: codeKeyProblem });
        } else if ([env.JWT_ACCESS_SECRET, env.RATE_LIMIT_KEY_SECRET].includes(env.REGISTRATION_CODE_KEY)) {
          ctx.addIssue({
            code: 'custom',
            path: ['REGISTRATION_CODE_KEY'],
            message: 'must differ from JWT_ACCESS_SECRET and RATE_LIMIT_KEY_SECRET',
          });
        }
      }
      if (env.LIVE_CURSOR_KEY !== undefined) {
        const cursorKeyProblem = productionSecretProblem(env.LIVE_CURSOR_KEY);
        if (cursorKeyProblem) {
          ctx.addIssue({ code: 'custom', path: ['LIVE_CURSOR_KEY'], message: cursorKeyProblem });
        } else if (
          [env.JWT_ACCESS_SECRET, env.RATE_LIMIT_KEY_SECRET, env.REGISTRATION_CODE_KEY].includes(
            env.LIVE_CURSOR_KEY,
          )
        ) {
          ctx.addIssue({
            code: 'custom',
            path: ['LIVE_CURSOR_KEY'],
            message: 'must differ from JWT_ACCESS_SECRET, RATE_LIMIT_KEY_SECRET and REGISTRATION_CODE_KEY',
          });
        }
      }
      // Heartbeat headroom (KL-040 observation): a short cadence with the default bucket would
      // leave no room for retries and end live rooms with 429s.
      const beat = env.RATE_LIMIT_LIVE_HEARTBEAT_USER;
      const expected = Math.ceil(beat.windowSeconds / env.LIVE_HEARTBEAT_INTERVAL_SECONDS);
      if (beat.max < HEARTBEAT_RATE_LIMIT_HEADROOM * expected) {
        ctx.addIssue({
          code: 'custom',
          path: ['RATE_LIMIT_LIVE_HEARTBEAT_USER'],
          message:
            `allows ${beat.max} per ${beat.windowSeconds} s, but a ${env.LIVE_HEARTBEAT_INTERVAL_SECONDS} s ` +
            `heartbeat cadence needs at least ${HEARTBEAT_RATE_LIMIT_HEADROOM * expected} ` +
            `(${HEARTBEAT_RATE_LIMIT_HEADROOM}× headroom for retries)`,
        });
      }
      if (env.LIVE_SWEEP_INTERVAL_SECONDS === 0) {
        ctx.addIssue({
          code: 'custom',
          path: ['LIVE_SWEEP_INTERVAL_SECONDS'],
          message: 'the stale-room sweeper cannot be disabled in production',
        });
      }
      // SEC-003a: hop counts above 3 and overly broad ranges trust client-supplied headers.
      if (typeof env.TRUST_PROXY === 'number' && env.TRUST_PROXY > 3) {
        ctx.addIssue({
          code: 'custom',
          path: ['TRUST_PROXY'],
          message: 'hop counts greater than 3 are refused in production',
        });
      }
      if (Array.isArray(env.TRUST_PROXY)) {
        const tooBroad = env.TRUST_PROXY.filter(isOverlyBroadProxyRange);
        if (tooBroad.length > 0) {
          ctx.addIssue({
            code: 'custom',
            path: ['TRUST_PROXY'],
            message:
              'ranges broader than IPv4 /8 or IPv6 /32 (incl. ::ffff:0:0/96) trust client-supplied ' +
              `headers and are refused in production: ${tooBroad.join(', ')}`,
          });
        }
      }
      if (env.TRUST_PROXY === true) {
        ctx.addIssue({
          code: 'custom',
          path: ['TRUST_PROXY'],
          message:
            '"true" trusts the client-controlled X-Forwarded-For and is refused in production; ' +
            'set the exact proxy hop count (e.g. 1) or the proxy addresses/CIDRs',
        });
      }
      if (env.MAIL_TRANSPORT === 'log') {
        ctx.addIssue({
          code: 'custom',
          path: ['MAIL_TRANSPORT'],
          message:
            '"log" is a development transport (it writes token links to logs) and is refused in ' +
            'production; a real transport is BLOCKED on B2 (SMTP provider)',
        });
      }
    }
  });

export type Env = z.output<typeof envSchema>;
