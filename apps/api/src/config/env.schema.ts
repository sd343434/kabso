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

const positiveInt = (fallback: number) => z.coerce.number().int().positive().default(fallback);
const nonNegativeInt = (fallback: number) => z.coerce.number().int().min(0).default(fallback);

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
    PORT: z.coerce.number().int().min(1).max(65535).default(3000),
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
    LIVE_HEARTBEAT_INTERVAL_SECONDS: z.coerce.number().int().min(5).max(60).default(15),
    /** A LIVE room without a heartbeat for this long is stale (never listed, ended). */
    LIVE_HEARTBEAT_STALE_SECONDS: z.coerce.number().int().positive().max(3600).default(45),
    /** Period of the in-process stale-room sweeper; 0 disables it (refused in production). */
    LIVE_SWEEP_INTERVAL_SECONDS: z.coerce.number().int().min(0).max(3600).default(15),
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
    ARGON2_MAX_CONCURRENCY: z.coerce.number().int().min(1).max(256).default(availableParallelism()),
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
