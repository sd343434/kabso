import { randomBytes } from 'node:crypto';
import { envSchema, type Env, type RateLimitRule } from './env.schema.js';
import { luckyTable, type LuckyTable } from '../modules/gifts/lucky-odds.js';

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
  /** Outbound SMTP (KL-042); null unless MAIL_TRANSPORT=smtp. */
  readonly smtp: {
    readonly host: string;
    readonly port: number;
    readonly secure: boolean;
    readonly user: string;
    readonly password: string;
    readonly from: string;
  } | null;
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
    /** CP-010: media tokens (per user; guests per IP), room settings, guest reads (per IP). */
    readonly liveMediaTokenUser: RateLimitRule;
    readonly liveMediaTokenGuestIp: RateLimitRule;
    readonly liveUpdateUser: RateLimitRule;
    /** CP-015: `PUT`/`DELETE /me/live-cover`, 30 / hour / user. */
    readonly liveCoverUser: RateLimitRule;
    /** CP-016 B: `PUT /me/live-blocked-words`, 30 / hour / user. */
    readonly liveBlockedWordsUser: RateLimitRule;
    /** CP-016 C: `POST` and `DELETE /me/live-schedule`, 30 / hour / user (one bucket). */
    readonly liveScheduleUser: RateLimitRule;
    readonly liveGuestReadIp: RateLimitRule;
    /** CP-011: seat requests and invitations; host/moderator seat actions; seat reads (per user). */
    readonly liveSeatAskUser: RateLimitRule;
    readonly liveSeatActionUser: RateLimitRule;
    readonly liveSeatsReadUser: RateLimitRule;
    /** CP-012: tap batches (per user). */
    readonly liveTapsUser: RateLimitRule;
    /** CP-013: chat messages (per user). */
    readonly liveChatUser: RateLimitRule;
    /** CP-018: family writes; CP requests, answers and ending; CP gifts (per user). */
    readonly familyWriteUser: RateLimitRule;
    readonly cpWriteUser: RateLimitRule;
    readonly cpGiftUser: RateLimitRule;
    /** CP-020: gift sends in a live (per user). */
    readonly liveGiftUser: RateLimitRule;
    /**
     * D145c (owner: «too many attempts» in a lucky streak): every gift send (the route's ceiling),
     * and lucky sends' own burst limit; normal sends keep {@link liveGiftUser}.
     */
    readonly liveGiftAnyUser: RateLimitRule;
    readonly liveLuckyGiftBurstUser: RateLimitRule;
    /** v1.28-live (D146). */
    readonly premiumRentUser: RateLimitRule;
    readonly usernameChangeUser: RateLimitRule;
    /** CP-021: CP space writes; new confessions (per user). */
    readonly cpSpaceWriteUser: RateLimitRule;
    readonly cpConfessionUser: RateLimitRule;
    /** CP-022: family chat messages (per user). */
    readonly familyChatUser: RateLimitRule;
    readonly liveHeartbeatUser: RateLimitRule;
    readonly liveEndUser: RateLimitRule;
    readonly followHourUser: RateLimitRule;
    readonly followDayUser: RateLimitRule;
    readonly mediaUploadUser: RateLimitRule;
    readonly postCreateHourUser: RateLimitRule;
    readonly postCreateDayUser: RateLimitRule;
    readonly commentUser: RateLimitRule;
    readonly likeUser: RateLimitRule;
    readonly repostUser: RateLimitRule;
    readonly shareUser: RateLimitRule;
    readonly viewsUser: RateLimitRule;
    readonly feedUser: RateLimitRule;
    /** CP-008: `POST /stories` and `PUT /stories/{id}/seen`; the tray uses `feedUser`. */
    readonly storyCreateUser: RateLimitRule;
    readonly storySeenUser: RateLimitRule;
    /** CP-009: `POST /notifications/read`; the inbox and the unread count use `feedUser`. */
    readonly notificationsReadUser: RateLimitRule;
    readonly searchUser: RateLimitRule;
    /** v1.29-live (D147): `POST /search/queries`. */
    readonly searchRecordUser: RateLimitRule;
    readonly blockUser: RateLimitRule;
    readonly reportUser: RateLimitRule;
  };
  /** v1.5-social media storage (CONVENTIONS §11.1). */
  readonly media: {
    readonly uploadsEnabled: boolean;
    readonly s3: {
      readonly endpoint: string | undefined;
      readonly region: string;
      readonly bucket: string | undefined;
      readonly accessKeyId: string | undefined;
      readonly secretAccessKey: string | undefined;
      readonly forcePathStyle: boolean;
    };
    readonly publicBaseUrl: string | undefined;
    readonly sweepIntervalSeconds: number;
  };
  /** v1.5-social posts (CONVENTIONS §11). */
  readonly social: {
    readonly publishIntervalSeconds: number;
    /** CP-009 notifications retention sweeper; 0 = disabled (tests; refused in production). */
    readonly notificationsSweepIntervalSeconds: number;
    /** CP-018: family join request and CP request expiry sweeper; 0 = disabled (tests). */
    readonly bondsSweepIntervalSeconds: number;
    readonly cursorKey: string;
  };
  /** v1.28-live (D146) premium usernames (CONVENTIONS §10.32). */
  readonly premiumUsernames: {
    readonly periodDays: number;
    readonly graceDays: number;
    /** Descending. */
    readonly reminderDays: readonly number[];
    readonly maxPrepaidDays: number;
    /** 0 = sweeper disabled (tests; refused in production). */
    readonly sweepIntervalSeconds: number;
  };
  /** v1.30-live (D152) push notifications (CONVENTIONS §11.12). */
  readonly push: {
    /** The Firebase service-account key file, or null (push off). */
    readonly credentialsFile: string | null;
    /** 0 = the outbox dispatcher is off (tests call it directly). */
    readonly dispatchIntervalMs: number;
    readonly generalGapSeconds: number;
    readonly messagesGapSeconds: number;
  };
  /** v1.29-live (D147) search trends (CONVENTIONS §11.11). */
  readonly searchTrends: {
    readonly minSearchers: number;
    /** 0 = sweeper disabled. */
    readonly sweepIntervalSeconds: number;
  };
  /** v1.23-live live gifts (CONVENTIONS §10.23). */
  readonly gifts: {
    /** The quantities a send may use, ascending (LIVE_GIFT_QUANTITIES). */
    readonly quantities: readonly number[];
  };
  /** v1.27-live (D132) lucky gifts (CONVENTIONS §10.27). */
  readonly lucky: {
    readonly enabled: boolean;
    /** The validated odds (the server refuses to start on an invalid table). */
    readonly table: LuckyTable;
    readonly bigWinMultiplier: number;
    readonly dayTimeZone: string;
    /** ISO 3166-1 alpha-2, upper case. */
    readonly disabledCountries: readonly string[];
    /** Lower-case header name set by the edge, or null. */
    readonly countryHeader: string | null;
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
    /** CP-010: the LiveKit media server, or null when not configured (hosting must then be off). */
    readonly livekit: { readonly url: string; readonly apiKey: string; readonly apiSecret: string } | null;
    /** Source of the guest-number HMAC key (HKDF `live-guest/v1`): rateLimitKeySecret. */
    readonly guestKey: string;
    /** CP-016 A: the popularity boards' time zone (day and week boundaries). */
    readonly rankingsTimeZone: string;
  };
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
    smtp:
      e.MAIL_TRANSPORT === 'smtp' &&
      e.SMTP_HOST !== undefined &&
      e.SMTP_USER !== undefined &&
      e.SMTP_PASSWORD !== undefined &&
      e.MAIL_FROM !== undefined
        ? {
            host: e.SMTP_HOST,
            port: e.SMTP_PORT,
            secure: e.SMTP_SECURE,
            user: e.SMTP_USER,
            password: e.SMTP_PASSWORD,
            from: e.MAIL_FROM,
          }
        : null,
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
      liveMediaTokenUser: e.RATE_LIMIT_LIVE_MEDIA_TOKEN_USER,
      liveMediaTokenGuestIp: e.RATE_LIMIT_LIVE_MEDIA_TOKEN_GUEST_IP,
      liveUpdateUser: e.RATE_LIMIT_LIVE_UPDATE_USER,
      liveCoverUser: e.RATE_LIMIT_LIVE_COVER_USER,
      liveBlockedWordsUser: e.RATE_LIMIT_LIVE_BLOCKED_WORDS_USER,
      liveScheduleUser: e.RATE_LIMIT_LIVE_SCHEDULE_USER,
      liveGuestReadIp: e.RATE_LIMIT_LIVE_GUEST_READ_IP,
      liveSeatAskUser: e.RATE_LIMIT_LIVE_SEAT_ASK_USER,
      liveSeatActionUser: e.RATE_LIMIT_LIVE_SEAT_ACTION_USER,
      liveSeatsReadUser: e.RATE_LIMIT_LIVE_SEATS_READ_USER,
      liveTapsUser: e.RATE_LIMIT_LIVE_TAPS_USER,
      liveChatUser: e.RATE_LIMIT_LIVE_CHAT_USER,
      familyWriteUser: e.RATE_LIMIT_FAMILY_WRITE_USER,
      cpWriteUser: e.RATE_LIMIT_CP_WRITE_USER,
      cpGiftUser: e.RATE_LIMIT_CP_GIFT_USER,
      liveGiftUser: e.RATE_LIMIT_LIVE_GIFT_USER,
      liveGiftAnyUser: e.RATE_LIMIT_LIVE_LUCKY_GIFT_USER,
      liveLuckyGiftBurstUser: e.RATE_LIMIT_LIVE_LUCKY_GIFT_BURST_USER,
      premiumRentUser: e.RATE_LIMIT_PREMIUM_RENT_USER,
      usernameChangeUser: e.RATE_LIMIT_USERNAME_CHANGE_USER,
      cpSpaceWriteUser: e.RATE_LIMIT_CP_SPACE_WRITE_USER,
      cpConfessionUser: e.RATE_LIMIT_CP_CONFESSION_USER,
      familyChatUser: e.RATE_LIMIT_FAMILY_CHAT_USER,
      liveHeartbeatUser: e.RATE_LIMIT_LIVE_HEARTBEAT_USER,
      liveEndUser: e.RATE_LIMIT_LIVE_END_USER,
      followHourUser: e.RATE_LIMIT_FOLLOW_HOUR_USER,
      followDayUser: e.RATE_LIMIT_FOLLOW_DAY_USER,
      mediaUploadUser: e.RATE_LIMIT_MEDIA_UPLOAD_USER,
      postCreateHourUser: e.RATE_LIMIT_POST_CREATE_HOUR_USER,
      postCreateDayUser: e.RATE_LIMIT_POST_CREATE_DAY_USER,
      commentUser: e.RATE_LIMIT_COMMENT_USER,
      likeUser: e.RATE_LIMIT_LIKE_USER,
      repostUser: e.RATE_LIMIT_REPOST_USER,
      shareUser: e.RATE_LIMIT_SHARE_USER,
      viewsUser: e.RATE_LIMIT_VIEWS_USER,
      feedUser: e.RATE_LIMIT_FEED_USER,
      storyCreateUser: e.RATE_LIMIT_STORY_CREATE_USER,
      storySeenUser: e.RATE_LIMIT_STORY_SEEN_USER,
      notificationsReadUser: e.RATE_LIMIT_NOTIFICATIONS_READ_USER,
      searchUser: e.RATE_LIMIT_SEARCH_USER,
      searchRecordUser: e.RATE_LIMIT_SEARCH_RECORD_USER,
      blockUser: e.RATE_LIMIT_BLOCK_USER,
      reportUser: e.RATE_LIMIT_REPORT_USER,
    },
    media: {
      uploadsEnabled: e.MEDIA_UPLOADS_ENABLED,
      s3: {
        endpoint: e.S3_ENDPOINT,
        region: e.S3_REGION,
        bucket: e.S3_BUCKET,
        accessKeyId: e.S3_ACCESS_KEY_ID,
        secretAccessKey: e.S3_SECRET_ACCESS_KEY,
        forcePathStyle: e.S3_FORCE_PATH_STYLE,
      },
      publicBaseUrl: e.MEDIA_PUBLIC_BASE_URL,
      sweepIntervalSeconds: e.MEDIA_SWEEP_INTERVAL_SECONDS,
    },
    social: {
      publishIntervalSeconds: e.POSTS_PUBLISH_INTERVAL_SECONDS,
      notificationsSweepIntervalSeconds: e.NOTIFICATIONS_SWEEP_INTERVAL_SECONDS,
      bondsSweepIntervalSeconds: e.BONDS_SWEEP_INTERVAL_SECONDS,
      cursorKey: e.SOCIAL_CURSOR_KEY ?? rateLimitKeySecret,
    },
    gifts: { quantities: e.LIVE_GIFT_QUANTITIES },
    push: {
      credentialsFile: e.FIREBASE_CREDENTIALS_FILE ?? null,
      dispatchIntervalMs: e.PUSH_DISPATCH_INTERVAL_MS,
      generalGapSeconds: e.PUSH_GENERAL_GAP_SECONDS,
      messagesGapSeconds: e.PUSH_MESSAGES_GAP_SECONDS,
    },
    searchTrends: {
      minSearchers: e.SEARCH_TRENDING_MIN_SEARCHERS,
      sweepIntervalSeconds: e.SEARCH_TRENDS_SWEEP_INTERVAL_SECONDS,
    },
    premiumUsernames: {
      periodDays: e.PREMIUM_USERNAME_PERIOD_DAYS,
      graceDays: e.PREMIUM_USERNAME_GRACE_DAYS,
      reminderDays: e.PREMIUM_USERNAME_REMINDER_DAYS,
      maxPrepaidDays: Math.max(e.PREMIUM_USERNAME_MAX_PREPAID_DAYS, e.PREMIUM_USERNAME_PERIOD_DAYS),
      sweepIntervalSeconds: e.PREMIUM_USERNAME_SWEEP_INTERVAL_SECONDS,
    },
    lucky: {
      enabled: e.LUCKY_GIFTS_ENABLED,
      table: luckyTable(
        e.LUCKY_GIFT_RTP_PERCENT,
        e.LUCKY_GIFT_HOST_SHARE_PERCENT,
        e.LUCKY_GIFT_MULTIPLIERS,
        e.LUCKY_GIFT_RTP_SHARES,
      ) as LuckyTable,
      bigWinMultiplier: e.LUCKY_GIFT_BIG_WIN_MULTIPLIER,
      dayTimeZone: e.LUCKY_GIFT_DAY_TIME_ZONE,
      disabledCountries: e.LUCKY_GIFTS_DISABLED_COUNTRIES,
      countryHeader: e.LUCKY_GIFTS_COUNTRY_HEADER ?? null,
    },
    live: {
      hostingEnabled: e.LIVE_HOSTING_ENABLED,
      heartbeatIntervalSeconds: e.LIVE_HEARTBEAT_INTERVAL_SECONDS,
      heartbeatStaleSeconds: e.LIVE_HEARTBEAT_STALE_SECONDS,
      sweepIntervalSeconds: e.LIVE_SWEEP_INTERVAL_SECONDS,
      sweepBatchSize: e.LIVE_SWEEP_BATCH_SIZE,
      cursorKey: e.LIVE_CURSOR_KEY ?? rateLimitKeySecret,
      livekit:
        e.LIVEKIT_URL !== undefined && e.LIVEKIT_API_KEY !== undefined && e.LIVEKIT_API_SECRET !== undefined
          ? { url: e.LIVEKIT_URL, apiKey: e.LIVEKIT_API_KEY, apiSecret: e.LIVEKIT_API_SECRET }
          : null,
      guestKey: rateLimitKeySecret,
      rankingsTimeZone: e.LIVE_RANKINGS_TIME_ZONE,
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
