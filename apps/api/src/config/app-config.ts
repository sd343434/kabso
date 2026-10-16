import { randomBytes } from 'node:crypto';
import { envSchema, type Env, type RateLimitRule } from './env.schema.js';

export const APP_CONFIG = Symbol('APP_CONFIG');

export interface AppConfig {
  readonly env: Env['NODE_ENV'];
  readonly isProduction: boolean;
  readonly port: number;
  readonly logLevel: Env['LOG_LEVEL'];
  readonly databaseUrl: string;
  readonly redis: { readonly url: string; readonly keyPrefix: string };
  /** HMAC key for rate-limit subject keys (generated per process outside production). */
  readonly rateLimitKeySecret: string;
  readonly argon2: { readonly maxConcurrency: number; readonly maxQueue: number };
  readonly jwt: {
    readonly accessSecret: string;
    readonly accessTtlSeconds: number;
    readonly issuer: 'kabso-api';
    readonly audience: 'kabso-mobile';
  };
  readonly refresh: { readonly ttlSeconds: number; readonly absoluteTtlSeconds: number };
  readonly tokens: {
    readonly emailVerifyTtlSeconds: number;
    readonly passwordResetTtlSeconds: number;
  };
  readonly appPublicUrl: string;
  readonly mailTransport: Env['MAIL_TRANSPORT'];
  readonly http: {
    readonly corsOrigins: readonly string[];
    readonly trustProxy: boolean | number | string[];
    readonly bodyLimit: string;
  };
  readonly rateLimits: {
    readonly loginIpAccount: RateLimitRule;
    readonly loginAccount: RateLimitRule;
    readonly loginIp: RateLimitRule;
    readonly registerIp: RateLimitRule;
    readonly forgotEmail: RateLimitRule;
    readonly forgotIp: RateLimitRule;
    readonly refreshSession: RateLimitRule;
    readonly authenticatedUser: RateLimitRule;
    readonly emailResendUser: RateLimitRule;
    readonly publicIp: RateLimitRule;
    readonly registerEmail: RateLimitRule;
    readonly registerVerifyIp: RateLimitRule;
    readonly registerResendEmail: RateLimitRule;
    readonly registerResendIp: RateLimitRule;
    readonly updateMeUser: RateLimitRule;
  };
  readonly registration: {
    readonly ttlSeconds: number;
    readonly noticeIntervalSeconds: number;
    readonly cleanupIntervalSeconds: number;
  };
  readonly loginRecentSuccessTtlSeconds: number;
  readonly reservedDisplayNameTerms: readonly string[];
  readonly reservedDisplayNameBrandTerms: readonly string[];
}

export class ConfigValidationError extends Error {
  constructor(readonly problems: readonly string[]) {
    super(`Invalid environment configuration:\n${problems.map((p) => `  - ${p}`).join('\n')}`);
    this.name = 'ConfigValidationError';
  }
}

/**
 * Validates raw environment variables and builds the typed application config.
 * Throws {@link ConfigValidationError} listing every problem (variable values are never echoed
 * for secrets).
 */
export function loadConfig(raw: Record<string, string | undefined>): AppConfig {
  const parsed = envSchema.safeParse(raw);
  if (!parsed.success) {
    throw new ConfigValidationError(
      parsed.error.issues.map((issue) => `${issue.path.join('.') || '(root)'}: ${issue.message}`),
    );
  }
  const e = parsed.data;
  return {
    env: e.NODE_ENV,
    isProduction: e.NODE_ENV === 'production',
    port: e.PORT,
    logLevel: e.LOG_LEVEL,
    databaseUrl: e.DATABASE_URL,
    redis: { url: e.REDIS_URL, keyPrefix: e.REDIS_KEY_PREFIX },
    rateLimitKeySecret: e.RATE_LIMIT_KEY_SECRET ?? randomBytes(32).toString('base64url'),
    argon2: { maxConcurrency: e.ARGON2_MAX_CONCURRENCY, maxQueue: e.ARGON2_MAX_QUEUE },
    jwt: {
      accessSecret: e.JWT_ACCESS_SECRET,
      accessTtlSeconds: e.JWT_ACCESS_TTL_SECONDS,
      issuer: 'kabso-api',
      audience: 'kabso-mobile',
    },
    refresh: {
      ttlSeconds: e.REFRESH_TTL_SECONDS,
      absoluteTtlSeconds: e.REFRESH_ABSOLUTE_TTL_SECONDS,
    },
    tokens: {
      emailVerifyTtlSeconds: e.EMAIL_VERIFY_TOKEN_TTL_SECONDS,
      passwordResetTtlSeconds: e.PASSWORD_RESET_TOKEN_TTL_SECONDS,
    },
    appPublicUrl: e.APP_PUBLIC_URL,
    mailTransport: e.MAIL_TRANSPORT,
    http: { corsOrigins: e.CORS_ORIGINS, trustProxy: e.TRUST_PROXY, bodyLimit: e.BODY_LIMIT },
    rateLimits: {
      loginIpAccount: e.RATE_LIMIT_LOGIN_IP_ACCOUNT,
      loginAccount: e.RATE_LIMIT_LOGIN_ACCOUNT,
      loginIp: e.RATE_LIMIT_LOGIN_IP,
      registerIp: e.RATE_LIMIT_REGISTER_IP,
      forgotEmail: e.RATE_LIMIT_FORGOT_EMAIL,
      forgotIp: e.RATE_LIMIT_FORGOT_IP,
      refreshSession: e.RATE_LIMIT_REFRESH_SESSION,
      authenticatedUser: e.RATE_LIMIT_AUTHENTICATED_USER,
      emailResendUser: e.RATE_LIMIT_EMAIL_RESEND_USER,
      publicIp: e.RATE_LIMIT_PUBLIC_IP,
      registerEmail: e.RATE_LIMIT_REGISTER_EMAIL,
      registerVerifyIp: e.RATE_LIMIT_REGISTER_VERIFY_IP,
      registerResendEmail: e.RATE_LIMIT_REGISTER_RESEND_EMAIL,
      registerResendIp: e.RATE_LIMIT_REGISTER_RESEND_IP,
      updateMeUser: e.RATE_LIMIT_UPDATE_ME_USER,
    },
    registration: {
      ttlSeconds: e.REGISTRATION_TTL_SECONDS,
      noticeIntervalSeconds: e.REGISTRATION_NOTICE_INTERVAL_SECONDS,
      cleanupIntervalSeconds: e.REGISTRATION_CLEANUP_INTERVAL_SECONDS,
    },
    loginRecentSuccessTtlSeconds: e.LOGIN_RECENT_SUCCESS_TTL_SECONDS,
    reservedDisplayNameTerms: e.RESERVED_DISPLAY_NAME_TERMS,
    reservedDisplayNameBrandTerms: e.RESERVED_DISPLAY_NAME_BRAND_TERMS,
  };
}
