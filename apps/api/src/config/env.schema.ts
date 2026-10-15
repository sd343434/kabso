import { isIP } from 'node:net';
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
