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
    readonly registerVerifyEmail: RateLimitRule;
    readonly registerResendEmail: RateLimitRule;
    readonly registerResendIp: RateLimitRule;
    readonly updateMeUser: RateLimitRule;
    readonly liveListUser: RateLimitRule;
    readonly profileUser: RateLimitRule;
    readonly liveStartHourUser: RateLimitRule;
    readonly liveStartDayUser: RateLimitRule;
    readonly liveHeartbeatUser: RateLimitRule;
    readonly liveEndUser: RateLimitRule;
    readonly followHourUser: RateLimitRule;
    readonly followDayUser: RateLimitRule;
    readonly mediaUploadHourUser: RateLimitRule;
    readonly mediaUploadDayUser: RateLimitRule;
    readonly mediaCompleteUser: RateLimitRule;
    readonly liveCoverUser: RateLimitRule;
    readonly liveCountriesUser: RateLimitRule;
  };
  /** Contract v1.3 live discovery (CONVENTIONS §10). */
  readonly live: {
    readonly hostingEnabled: boolean;
    readonly heartbeatIntervalSeconds: number;
    readonly heartbeatStaleSeconds: number;
    /** 0 = sweeper disabled (tests; refused in production). */
    readonly sweepIntervalSeconds: number;
    /** Stale rooms ended per sweeper batch (SEC-035; LIVE_SWEEP_BATCH_SIZE). */
    readonly sweepBatchSize: number;
    /** Source of the cursor HMAC key (HKDF `live-cursor/v1`): LIVE_CURSOR_KEY, else rateLimitKeySecret. */
    readonly cursorKey: string;
  };
  /** Contract v1.4 media uploads (CONVENTIONS §11, DB_PHASE2_MEDIA §5). */
  readonly media: MediaConfig;
  readonly registration: {
    readonly ttlSeconds: number;
    readonly maxLifetimeSeconds: number;
    /** Dedicated code-HMAC key source (SEC-029); falls back to rateLimitKeySecret. */
    readonly codeKey: string | undefined;
    readonly noticeIntervalSeconds: number;
    readonly cleanupIntervalSeconds: number;
  };
  readonly loginRecentSuccessTtlSeconds: number;
  readonly reservedDisplayNameTerms: readonly string[];
  readonly reservedDisplayNameBrandTerms: readonly string[];
}

/** S3-compatible storage (any provider; Cloudflare R2 per D45). Holds secrets: never log it. */
export interface MediaStorageConfig {
  readonly endpoint: string | undefined;
  readonly region: string;
  readonly forcePathStyle: boolean;
  readonly incomingBucket: string;
  readonly publicBucket: string;
  readonly accessKeyId: string;
  readonly secretAccessKey: string;
}

export interface MediaConfig {
  /** MEDIA_UPLOADS_ENABLED (default false). True only with a complete storage config. */
  readonly uploadsEnabled: boolean;
  readonly moderationProvider: 'none' | 'allow_all';
  /** Complete storage settings, else null (then nothing can talk to storage). */
  readonly storage: MediaStorageConfig | null;
  /** MEDIA_PUBLIC_BASE_URL without a trailing slash, else null (no image URL can be built). */
  readonly publicBaseUrl: string | null;
  readonly uploadUrlTtlSeconds: number;
  readonly maxPendingPerUser: number;
  readonly dailyBytesPerUser: number;
  readonly processMaxConcurrency: number;
  readonly processTimeoutMs: number;
  readonly unattachedTtlHours: number;
  readonly deleteGraceHours: number;
  readonly endedRoomCoverTtlHours: number;
  /** 0 = cleanup job disabled (tests; refused in production). */
  readonly cleanupIntervalSeconds: number;
  readonly cleanupBatchSize: number;
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
  const rateLimitKeySecret = e.RATE_LIMIT_KEY_SECRET ?? randomBytes(32).toString('base64url');
  return {
    env: e.NODE_ENV,
    isProduction: e.NODE_ENV === 'production',
    port: e.PORT,
    logLevel: e.LOG_LEVEL,
    databaseUrl: e.DATABASE_URL,
    redis: { url: e.REDIS_URL, keyPrefix: e.REDIS_KEY_PREFIX },
    rateLimitKeySecret,
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
      registerVerifyEmail: e.RATE_LIMIT_REGISTER_VERIFY_EMAIL,
      registerResendEmail: e.RATE_LIMIT_REGISTER_RESEND_EMAIL,
      registerResendIp: e.RATE_LIMIT_REGISTER_RESEND_IP,
      updateMeUser: e.RATE_LIMIT_UPDATE_ME_USER,
      liveListUser: e.RATE_LIMIT_LIVE_LIST_USER,
      profileUser: e.RATE_LIMIT_PROFILE_USER,
      liveStartHourUser: e.RATE_LIMIT_LIVE_START_HOUR_USER,
      liveStartDayUser: e.RATE_LIMIT_LIVE_START_DAY_USER,
      liveHeartbeatUser: e.RATE_LIMIT_LIVE_HEARTBEAT_USER,
      liveEndUser: e.RATE_LIMIT_LIVE_END_USER,
      followHourUser: e.RATE_LIMIT_FOLLOW_HOUR_USER,
      followDayUser: e.RATE_LIMIT_FOLLOW_DAY_USER,
      mediaUploadHourUser: e.RATE_LIMIT_MEDIA_UPLOAD_HOUR_USER,
      mediaUploadDayUser: e.RATE_LIMIT_MEDIA_UPLOAD_DAY_USER,
      mediaCompleteUser: e.RATE_LIMIT_MEDIA_COMPLETE_USER,
      liveCoverUser: e.RATE_LIMIT_LIVE_COVER_USER,
      liveCountriesUser: e.RATE_LIMIT_LIVE_COUNTRIES_USER,
    },
    live: {
      hostingEnabled: e.LIVE_HOSTING_ENABLED,
      heartbeatIntervalSeconds: e.LIVE_HEARTBEAT_INTERVAL_SECONDS,
      heartbeatStaleSeconds: e.LIVE_HEARTBEAT_STALE_SECONDS,
      sweepIntervalSeconds: e.LIVE_SWEEP_INTERVAL_SECONDS,
      sweepBatchSize: e.LIVE_SWEEP_BATCH_SIZE,
      cursorKey: e.LIVE_CURSOR_KEY ?? rateLimitKeySecret,
    },
    media: {
      uploadsEnabled: e.MEDIA_UPLOADS_ENABLED,
      moderationProvider: e.MEDIA_MODERATION_PROVIDER,
      storage:
        e.MEDIA_STORAGE_REGION !== undefined &&
        e.MEDIA_STORAGE_INCOMING_BUCKET !== undefined &&
        e.MEDIA_STORAGE_PUBLIC_BUCKET !== undefined &&
        e.MEDIA_STORAGE_ACCESS_KEY_ID !== undefined &&
        e.MEDIA_STORAGE_SECRET_ACCESS_KEY !== undefined
          ? {
              endpoint: e.MEDIA_STORAGE_ENDPOINT,
              region: e.MEDIA_STORAGE_REGION,
              forcePathStyle: e.MEDIA_STORAGE_FORCE_PATH_STYLE,
              incomingBucket: e.MEDIA_STORAGE_INCOMING_BUCKET,
              publicBucket: e.MEDIA_STORAGE_PUBLIC_BUCKET,
              accessKeyId: e.MEDIA_STORAGE_ACCESS_KEY_ID,
              secretAccessKey: e.MEDIA_STORAGE_SECRET_ACCESS_KEY,
            }
          : null,
      publicBaseUrl: e.MEDIA_PUBLIC_BASE_URL ?? null,
      uploadUrlTtlSeconds: e.MEDIA_UPLOAD_URL_TTL_SECONDS,
      maxPendingPerUser: e.MEDIA_MAX_PENDING_PER_USER,
      dailyBytesPerUser: e.MEDIA_DAILY_BYTES_PER_USER,
      processMaxConcurrency: e.MEDIA_PROCESS_MAX_CONCURRENCY,
      processTimeoutMs: e.MEDIA_PROCESS_TIMEOUT_MS,
      unattachedTtlHours: e.MEDIA_UNATTACHED_TTL_HOURS,
      deleteGraceHours: e.MEDIA_DELETE_GRACE_HOURS,
      endedRoomCoverTtlHours: e.MEDIA_ENDED_ROOM_COVER_TTL_HOURS,
      cleanupIntervalSeconds: e.MEDIA_CLEANUP_INTERVAL_SECONDS,
      cleanupBatchSize: e.MEDIA_CLEANUP_BATCH_SIZE,
    },
    registration: {
      ttlSeconds: e.REGISTRATION_TTL_SECONDS,
      maxLifetimeSeconds: e.REGISTRATION_MAX_LIFETIME_SECONDS,
      codeKey: e.REGISTRATION_CODE_KEY,
      noticeIntervalSeconds: e.REGISTRATION_NOTICE_INTERVAL_SECONDS,
      cleanupIntervalSeconds: e.REGISTRATION_CLEANUP_INTERVAL_SECONDS,
    },
    loginRecentSuccessTtlSeconds: e.LOGIN_RECENT_SUCCESS_TTL_SECONDS,
    reservedDisplayNameTerms: e.RESERVED_DISPLAY_NAME_TERMS,
    reservedDisplayNameBrandTerms: e.RESERVED_DISPLAY_NAME_BRAND_TERMS,
  };
}
