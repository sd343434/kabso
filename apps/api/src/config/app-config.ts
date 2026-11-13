import { randomBytes } from 'node:crypto';
import {
  envSchema,
  luckyPityOf,
  topupMinorPerMillion,
  type BoostPrice,
  type Env,
  type HostShareCategory,
  type RateLimitRule,
  type RechargePackage,
} from './env.schema.js';
import { luckyTable, type LuckyTable } from '../modules/gifts/lucky-odds.js';
import type { RechargeBadgeRules } from '../modules/recharge/recharge-badges.js';

export const APP_CONFIG = Symbol('APP_CONFIG');

/** v1.43-live (D195): the four PK boosters, in order. */
export type PkBoosterKindName = 'DOUBLE' | 'DOUBLE_TURBO' | 'TRIPLE' | 'TRIPLE_TURBO';
export const PK_BOOSTER_KINDS: readonly PkBoosterKindName[] = [
  'DOUBLE',
  'DOUBLE_TURBO',
  'TRIPLE',
  'TRIPLE_TURBO',
];

/** v1.43-live (D195): one booster's rule. */
export interface PkBoosterRule {
  readonly kind: PkBoosterKindName;
  readonly multiplier: number;
  /** How long it is active. */
  readonly durationSeconds: number;
  /** It may start only in the battle's last N seconds; 0 = any time. */
  readonly lastSeconds: number;
  /** Uses per side per match. */
  readonly limitPerMatch: number;
}

export interface PkConfig {
  readonly enabled: boolean;
  readonly inviteTtlSeconds: number;
  readonly inviteCooldownSeconds: number;
  readonly randomWaitSeconds: number;
  readonly battleSeconds: number;
  readonly resultSeconds: number;
  /** v1.44-live (D199): combined PK points from which a match counts in the records. */
  readonly effectiveMinPoints: number;
  /** v1.44-live (D199): how long a CONNECTED PK may wait for a start. */
  readonly connectSeconds: number;
  /** v1.44-live (D199): Auto Match's rest after a PK closed. */
  readonly autoMatchRestSeconds: number;
  readonly absenceGraceSeconds: number;
  /** 0 = no tick (tests). */
  readonly tickMs: number;
  readonly scoreBroadcastMs: number;
  readonly boosters: readonly PkBoosterRule[];
  /** v1.50-live (D229): «PK أحكام» on, the draw's reveal, the dare's timer and the outcome's time (seconds). */
  readonly daresEnabled: boolean;
  readonly dareDrawSeconds: number;
  readonly dareSeconds: number;
  readonly dareOutcomeSeconds: number;
  /** v1.55-live (D242) «جولة أخرى»: the offer's answer time and the rematches in a row (0 = unlimited). */
  readonly rematchAcceptSeconds: number;
  readonly rematchMax: number;
  /** v1.118-live (D391, §10.180) «PK رباعي»: on, the lobby's time, an invitation's time, the watchers' cap (0: none). */
  readonly pk4: {
    readonly enabled: boolean;
    readonly lobbySeconds: number;
    readonly inviteTtlSeconds: number;
    readonly maxWatchersPerRoom: number;
  };
}

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
    /** v1.108-social (D343): `checkSignupCode` per IP. */
    readonly signupCodeIp: RateLimitRule;
    readonly forgotEmail: RateLimitRule;
    readonly forgotIp: RateLimitRule;
    readonly refreshSession: RateLimitRule;
    readonly authenticatedUser: RateLimitRule;
    readonly emailResendUser: RateLimitRule;
    readonly publicIp: RateLimitRule;
    /** v1.60-social (D191). */
    readonly adminLoginIp: RateLimitRule;
    readonly adminIp: RateLimitRule;
    /** v1.66-live (D271): the team's grant / revoke / reset-2fa. */
    readonly adminTeamIp: RateLimitRule;
    /** v1.68-live (D273): the staff tools in the app, and their step-up. */
    readonly staffAppUser: RateLimitRule;
    readonly staffStepUpUser: RateLimitRule;
    /** v1.99-social (D311): the app owner's moderation actions per user. */
    readonly ownerModerationUser: RateLimitRule;
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
    readonly avatarUser: RateLimitRule;
    /** v1.47-social (D175): accept / decline a follow request (one bucket). */
    readonly followRequestAnswerUser: RateLimitRule;
    /** CP-016 B: `PUT /me/live-blocked-words`, 30 / hour / user. */
    readonly liveBlockedWordsUser: RateLimitRule;
    /** CP-016 C: `POST` and `DELETE /me/live-schedule`, 30 / hour / user (one bucket). */
    readonly liveScheduleUser: RateLimitRule;
    readonly liveGuestReadIp: RateLimitRule;
    /** CP-011: seat requests and invitations; host/moderator seat actions; seat reads (per user). */
    readonly liveSeatAskUser: RateLimitRule;
    readonly liveSeatActionUser: RateLimitRule;
    /** v1.114-live (D363): question upvotes (video podcast). */
    readonly liveQuestionVoteUser: RateLimitRule;
    /** v1.114-live (D363): the host's director relay (video podcast). */
    readonly livePodcastDirectorUser: RateLimitRule;
    readonly liveSeatsReadUser: RateLimitRule;
    /** v1.43-live (D195): PK invitations; every other PK action (per user). */
    readonly livePkInviteUser: RateLimitRule;
    readonly livePkActionUser: RateLimitRule;
    /** v1.50-live (D229): «PK أحكام» dare reports (per user). */
    readonly livePkDareReportUser: RateLimitRule;
    /** v1.45-live (D201): second-camera codes created; codes redeemed; the other live tools calls. */
    readonly liveSecondCameraCodeUser: RateLimitRule;
    readonly liveSecondCameraRedeemUser: RateLimitRule;
    readonly liveToolsUser: RateLimitRule;
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
    /** D193: account-deletion requests (the password is re-checked), per user. */
    readonly accountDeletionUser: RateLimitRule;
    /** D198: data-export requests and downloads, per user. */
    readonly dataExportUser: RateLimitRule;
    readonly dataExportDownloadUser: RateLimitRule;
    /** CP-021: CP space writes; new confessions (per user). */
    readonly cpSpaceWriteUser: RateLimitRule;
    readonly cpConfessionUser: RateLimitRule;
    /** CP-022: family chat messages (per user). */
    readonly familyChatUser: RateLimitRule;
    /** v1.40-social (D155): direct message sends, message requests, other writes (per user). */
    readonly dmSendUser: RateLimitRule;
    readonly dmRequestUser: RateLimitRule;
    readonly dmWriteUser: RateLimitRule;
    /** v1.104-social (D339): new groups (per user). */
    readonly dmGroupCreateUser: RateLimitRule;
    /** v1.137-social (D385): messages to «دعم كابسو» (per user). */
    readonly supportSendUser: RateLimitRule;
    /** v1.48-social (D171): bag item sends (per user). */
    readonly bagSendUser: RateLimitRule;
    /** v1.54-social (D185). */
    readonly rechargeSellUser: RateLimitRule;
    readonly rechargeWriteUser: RateLimitRule;
    /** v1.69-social (D204). */
    readonly rechargeOrderUser: RateLimitRule;
    readonly rechargeOrderActionUser: RateLimitRule;
    /** v1.70-social (D206). */
    readonly agencyOpenUser: RateLimitRule;
    /** v1.73-social (D209). */
    readonly hostApplyUser: RateLimitRule;
    /** v1.80-kyc (D227). */
    readonly kycStartUser: RateLimitRule;
    readonly kycSyncUser: RateLimitRule;
    /** v1.74-social (D217): a later invite code (per user); the public rewards ticker (per IP). */
    readonly referralApplyUser: RateLimitRule;
    readonly referralTickerIp: RateLimitRule;
    readonly topupCheckoutUser: RateLimitRule;
    /** v1.109-social (D344): `POST /wallet/topup-session` (per user) and `POST /topup/handoff` (per IP). */
    readonly topupHandoffUser: RateLimitRule;
    readonly topupHandoffIp: RateLimitRule;
    /** v1.61-social (D192): `POST /waitlist`, per client IP. */
    readonly waitlistIp: RateLimitRule;
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
  /** v1.40-social (D155) direct messages (CONVENTIONS §11.13). */
  /** v1.52-social (D179): the cherry economy (CONVENTIONS §10.46). */
  readonly economy: {
    readonly cherriesPerCoin: number;
    /** v1.82-live (D295): agencies earn their commission on their creator members' gifts (owner: yes). */
    readonly creatorAgencyCommission: boolean;
    readonly agencyCommissionBps: number;
    readonly agencyTierCommissionBps: number;
    readonly agencyTierMonthlyCherries: number;
    readonly parentCommissionBps: number;
    readonly rankMinActiveHosts: number;
    readonly rankExceptionCherries: number;
    readonly adminMinSubAgencies: number;
    readonly activeHostMinDays: number;
    readonly activeHostMinHours: number;
    readonly activeHostWindowDays: number;
    readonly leaveDays: number;
    readonly sweepIntervalSeconds: number;
    /** v1.70-social (D206, §10.65): the probation of a self-opened agency and the reopening cooldown. */
    readonly probationDays: number;
    readonly probationMinHosts: number;
    readonly probationReminderHours: number;
    readonly reopenCooldownDays: number;
    /** v1.73-social (D209, §10.68): «كن مضيفاً مع الإدارة» — the minimum age and the wait after a rejection. */
    readonly hostApplyMinAge: number;
    readonly hostApplyReapplyDays: number;
    /** `rateCherries` cherries are paid `rateMinor` minor units of `currency`. */
    readonly rateCherries: number;
    readonly rateMinor: number;
    readonly currency: string;
    /** v1.57-social (D188): the coins' retail price, US dollars per 1 000 000 coins (owner: 12.5). */
    readonly coinRetailUsdPerMillion: number;
    readonly minWithdrawalMinor: number;
    readonly payoutDays: number;
    /**
     * v1.53-social (D184): task cherries unlock for withdrawal once lifetime gift cherries are worth this
     * (minor units; 0 = never locked). Owner rule: $50 of lifetime gift cherries (§10.46.1).
     */
    readonly taskCherriesUnlockGiftMinor: number;
  };
  /** v1.54-social (D185): recharge agents (CONVENTIONS §10.48). */
  readonly recharge: {
    readonly activationMinCoins: number;
    /** Increasing `minCoins`; the first is 0. Minor units (USD cents) per 1 000 000 coins. */
    readonly priceTiers: readonly { minCoins: number; minorPerMillion: number }[];
    readonly cherryRate: { cherries: number; coins: number };
    readonly cherryMin: number;
    readonly cherryStep: number;
    readonly requestTtlMinutes: number;
    readonly dailyCherryCap: number;
    readonly maxEmployees: number;
    readonly kycRetentionDays: number;
    readonly sweepIntervalSeconds: number;
    /** v1.56-social (D187, §10.50): the daily recharge badges. */
    readonly badges: RechargeBadgeRules;
    /** v1.69-social (D204, §10.64): recharge orders with escrow. */
    readonly orders: {
      readonly enabled: boolean;
      readonly minCoins: number;
      readonly maxCoins: number;
      readonly requestTtlMinutes: number;
      readonly paymentTtlMinutes: number;
      readonly disputeAfterMinutes: number;
      readonly sweepIntervalSeconds: number;
    };
  };
  /** v1.59-social (D190): card top-ups on the website through Stripe Checkout (CONVENTIONS §10.53). */
  readonly topup: {
    /**
     * The ENV keys: null until the owner sets STRIPE_SECRET_KEY, STRIPE_WEBHOOK_SECRET and TOPUP_PUBLIC_BASE_URL.
     * D196: read through `PaymentSettingsStore`, where the panel's keys override these (both missing → 503).
     */
    readonly stripe: {
      readonly secretKey: string;
      readonly webhookSecret: string;
      readonly publicBaseUrl: string;
      readonly testMode: boolean;
    } | null;
    /**
     * v1.64-social (D196): TOPUP_PUBLIC_BASE_URL on its own (the panel's keys use it when the env has no keys) and
     * STRIPE_ALLOW_TEST_KEYS_IN_PRODUCTION (env only, applies to the panel's keys too).
     */
    readonly publicBaseUrl: string | null;
    readonly allowTestKeysInProduction: boolean;
    /** The packages, prices computed from COIN_RETAIL_USD_PER_MILLION (id = the coin amount). */
    readonly packages: readonly { id: string; coins: number; priceMinor: number }[];
    readonly currency: 'USD';
    readonly bankTransfer: { readonly enabled: boolean; readonly type: string };
    readonly statementDescriptorSuffix: string | null;
    readonly disputeAutoSubmit: boolean;
    readonly appLinkEnabled: boolean;
    /** v1.109-social (D344): the app platforms that show «الشحن من الموقع» (TOPUP_APP_LINK_PLATFORMS). */
    readonly appLinkPlatforms: readonly ('android' | 'ios')[];
    /** v1.112-social (§10.143.3): the install sources that show «الشحن من الموقع» (TOPUP_APP_LINK_SOURCES). */
    readonly appLinkSources: readonly ('PLAY' | 'APP_STORE' | 'SIDELOAD')[];
    /**
     * v1.109-social (D344): Stripe's fee folded into the website price (TOPUP_STRIPE_FEE_*); the panel may override.
     */
    readonly fee: { readonly grossUp: boolean; readonly percentBps: number; readonly fixedMinor: number };
    readonly termsVersion: string;
  };
  /** v1.110-social (D345, CONVENTIONS §10.144): coins from the stores (paths only; the files are read at boot). */
  readonly storeIap: {
    readonly google: {
      readonly packageName: string;
      readonly serviceAccountFile: string;
      readonly rtdnToken: string | null;
    } | null;
    readonly apple: {
      readonly bundleId: string;
      readonly issuerId: string;
      readonly keyId: string;
      readonly privateKeyFile: string;
      readonly rootCertFiles: readonly string[];
      readonly appAppleId: string | null;
    } | null;
    readonly acceptSandbox: boolean;
    readonly voidedPollHours: number;
    readonly sweepIntervalSeconds: number;
    readonly consentVersion: string;
  };
  /** v1.116-social (D355, CONVENTIONS §10.151): «واتساب» (ids and file paths only; the files are read at boot). */
  readonly whatsapp: {
    readonly credentials: {
      readonly phoneNumberId: string;
      readonly businessAccountId: string;
      readonly accessTokenFile: string;
      readonly appSecretFile: string;
      readonly verifyTokenFile: string;
    } | null;
    readonly graphApiVersion: string;
    readonly graphBaseUrl: string;
    readonly displayName: string | null;
    readonly retentionDays: number;
    readonly mediaMaxBytes: number;
    readonly sweepIntervalSeconds: number;
    readonly templateCacheSeconds: number;
    readonly pushGapSeconds: number;
    /** v1.140-social (D388, §10.177.1): the language question on a conversation's first message. */
    readonly askLanguage: boolean;
  };
  /** v1.81-social (D245, §10.87): automatic exchange rates (the paid key is in the panel, never here). */
  readonly fx: {
    readonly freeUrl: string;
    readonly currencyApiBaseUrl: string;
    readonly exchangeRateApiBaseUrl: string;
    readonly freeIntervalSeconds: number;
    readonly paidIntervalSeconds: number;
    /** 0 = no automatic fetch (tests). */
    readonly tickSeconds: number;
    readonly staleAfterHours: number;
    readonly maxJumpPercent: number;
    readonly fetchTimeoutMs: number;
  };
  /** v1.59-live (D248, §10.90): the live hub's card-size banner: its grid cell (0-based, reading order). */
  readonly home: { readonly hubCardCell: number };
  /** v1.80-kyc (D227, §10.77): identity checks with Didit (the keys are in the panel, never here). */
  readonly kyc: {
    /** API_PUBLIC_URL: shown as the webhook address's origin (default `https://api.kabsolive.com`). */
    readonly publicApiBaseUrl: string;
  };
  /** v1.60-social (D191, CONVENTIONS §10.54): the admin panel; `totpKey` null = the panel is off. */
  readonly adminPanel: {
    readonly totpKey: string | null;
    readonly sessionIdleSeconds: number;
    readonly sessionMaxSeconds: number;
    readonly pendingSeconds: number;
    readonly lockoutAttempts: number;
    readonly lockoutSeconds: number;
    /** v1.68-live (D273): the staff tools' step-up in the app lasts this long (STAFF_APP_GRANT_SECONDS). */
    readonly staffAppGrantSeconds: number;
    /** v1.76-live (D286): an automatic shift goes off after this long without staff work (0 = never). */
    readonly staffShiftIdleOffSeconds: number;
    /** IANA zone of the dashboard's «today» (default Asia/Riyadh). */
    readonly dashboardTimeZone: string;
    /** v1.65-social (D197): the report's estimated card fees (basis points + fixed cents per order). */
    readonly reportCardFee: { readonly bps: number; readonly fixedMinor: number };
    /** D301 follow-up (§10.112.10): «الربح»'s value of given-away coins, US cents per 1 000 000 coins. */
    readonly ownerProfitCoinMinorPerMillion: number;
    /** v1.72-social (D208): the per-admin daily cap of balance adjustments (0 = none allowed). */
    readonly adjustDailyCap: { readonly coins: number; readonly cherries: number };
    /** v1.72-social (D208): days the old username stays held after a team rename (0 = none). */
    readonly renameHoldDays: number;
  };
  /**
   * v1.74-social (D217, CONVENTIONS §10.71): «دعوة الأصدقاء». The amounts and rules live in `referral_settings` (the
   * panel); only the sweeper's interval is a server setting (0 = off: tests; refused in production).
   */
  readonly referrals: {
    readonly sweepIntervalSeconds: number;
  };
  /**
   * v1.75-live (D285, CONVENTIONS §10.96.13): recruitment by staff. The shares per type live in
   * `staff_recruit_settings` (the panel); the daily commission job's interval (0 = off: tests; refused in production)
   * and how many past days it catches up after a pause are server settings.
   */
  readonly recruits: {
    readonly sweepIntervalSeconds: number;
    readonly catchUpDays: number;
  };
  /**
   * v1.90-social (D293, CONVENTIONS §10.105): the verification badges' sweeper interval (0 = off: tests; refused in
   * production). The thresholds live in `verification_badge_settings` (the panel).
   */
  readonly verificationBadges: {
    readonly sweepIntervalSeconds: number;
  };
  /** D300 (CONVENTIONS §10.111): the content-creator medals' sweeper interval (0 = off: tests; refused in production). */
  readonly medalCreators: {
    readonly sweepIntervalSeconds: number;
  };
  /** v1.62-social (D193): account deletion (CONVENTIONS §10.56). */
  readonly accountDeletion: {
    readonly graceDays: number;
    readonly usernameQuarantineDays: number;
    /** SUPPORT_EMAIL: the contact address in the notices (and for requests without the app). */
    readonly supportEmail: string;
    /** 0 = sweeper disabled (tests; refused in production). */
    readonly sweepIntervalSeconds: number;
    /** REPORT_LEGAL_HOLD_DAYS: reported content of a purged account is kept hidden this long, then deleted. */
    readonly legalHoldDays: number;
    /** DELETED_LEDGER_RETENTION_DAYS: the tombstone's ledgers and audit rows are kept this long after the purge. */
    readonly ledgerRetentionDays: number;
  };
  /** v1.66-social (D198): the personal-data export (CONVENTIONS §10.61). */
  readonly dataExport: {
    readonly minIntervalHours: number;
    readonly linkDays: number;
    /** 0 = sweeper disabled (tests; refused in production). */
    readonly sweepIntervalSeconds: number;
  };
  /** v1.54-social (D185): special usernames (CONVENTIONS §10.48.1). */
  readonly specialUsernames: {
    readonly graceDays: number;
    /** 0 = sweeper disabled (tests; refused in production). */
    readonly sweepIntervalSeconds: number;
  };
  readonly dm: {
    readonly retentionHours: number;
    /** 0 = sweeper disabled (tests; refused in production). */
    readonly sweepIntervalSeconds: number;
    readonly requestMaxMessages: number;
    readonly deleteForEveryoneSeconds: number;
    /** Percent of a non-lucky gift's value counted for the recipient's charm. */
    readonly giftRecipientSharePercent: number;
    /** v1.104-social (D339): the most members of a group, its creator included. */
    readonly groupMaxMembers: number;
  };
  /** v1.48-social (D171) the bag (CONVENTIONS §10.45). */
  readonly bag: {
    /** Period of the sweeper that deletes expired bag items; 0 = disabled (tests; reads filter them anyway). */
    readonly sweepIntervalSeconds: number;
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
    /** v1.32-live (D154): the recipients' earnings share by category, basis points. */
    readonly hostShareBps: Readonly<Record<HostShareCategory, number>>;
    /** v1.82-live (D295, §10.108): a creator's live — non-lucky gifts (70 %) and quips (60 %), basis points. */
    readonly creatorShareBps: number;
    readonly creatorQuipShareBps: number;
    /** v1.106-social (D341, §10.140): a normal gift to direct recipients only (no agency) — a host's 70 %, a creator's 75 %. */
    readonly directHostShareBps: number;
    readonly directCreatorShareBps: number;
    /** v1.100-social (D312, §10.118): a custom gift — the recipients' share and the gift owner's coin share, bps. */
    readonly customShareBps: number;
    readonly customOwnerBps: number;
    /** v1.32-live (D154): the longest a quip may wait for its turn, in ms. */
    readonly quipMaxWaitMs: number;
  };
  /** v1.34-live (D154c): an account younger than this is a newcomer (CONVENTIONS §10.35). */
  readonly newcomerDays: number;
  /** v1.38-live (D154i): the YouTube Data API key (search), or null (search off). */
  readonly youtubeApiKey: string | null;
  /** v1.33-live (D154b) traffic cards (CONVENTIONS §10.34). */
  readonly boosts: {
    readonly prices: readonly BoostPrice[];
    readonly slots: number;
    readonly maxWaitMs: number;
  };
  /** v1.44-social (D166): the Me hub's programs (CONVENTIONS §10.41). */
  readonly programs: {
    /** Since v1.53-social (D184): the check-in's coins only. */
    readonly taskDailyCapCoins: number;
    /** v1.53-social (D184): the daily tasks' cherries. */
    readonly taskDailyCapCherries: number;
    /**
     * v1.57-social (D188): the monthly cap of task cherries (daily + weekly) in payout minor units,
     * converted at the economy's payout rate (0 = none).
     */
    readonly taskMonthlyCapMinor: number;
    readonly checkInCoins: number;
    readonly checkInStreakBonusCoins: number;
    readonly eventPrizeReviewMs: number;
    readonly eventsSweepIntervalSeconds: number;
    /** Coins spent in the window for SVIP 1, 2, … (ascending). */
    readonly svipTiers: readonly number[];
    readonly svipWindowDays: number;
    readonly svipStatusDays: number;
    readonly rechargePackages: readonly RechargePackage[];
    readonly rechargeCurrency: string;
  };
  /** v1.27-live (D132) lucky gifts (CONVENTIONS §10.27). */
  readonly lucky: {
    readonly enabled: boolean;
    /** The validated odds (the server refuses to start on an invalid table). */
    readonly table: LuckyTable;
    readonly bigWinMultiplier: number;
    /** v1.111-live (D347): the best-win multipliers that make the global banner (`lucky-ticker`), ascending. */
    readonly globalBannerMultipliers: readonly number[];
    /** v1.111-live (D347): at most one global banner per this many ms (all instances, so per room too). */
    readonly globalBannerGapMs: number;
    /** v1.89-live (D318): the smallest win multiplier with a chat line (the panel's value wins). */
    readonly chatMinMultiplier: number;
    readonly dayTimeZone: string;
    /** ISO 3166-1 alpha-2, upper case. */
    readonly disabledCountries: readonly string[];
    /** Lower-case header name set by the edge, or null. */
    readonly countryHeader: string | null;
  };
  /** v1.43-live (D195, CONVENTIONS §10.58): PK 1 v 1; every value an owner-confirmable default. */
  readonly pk: PkConfig;
  /** Contract v1.3 live discovery (CONVENTIONS §10). */
  readonly live: {
    readonly hostingEnabled: boolean;
    /** v1.41-live (D178): the coins from which a gift send is told to every other live. */
    readonly giftTickerMinCoins: number;
    /** v1.85-live (D305): the tickets from which a game prize is told to every live. */
    readonly gameWinTickerMinTickets: number;
    readonly heartbeatIntervalSeconds: number;
    readonly heartbeatStaleSeconds: number;
    /** v1.58-live (D246): `LIVE_POPULAR_TOP_N`, the «رائج» lives per kind. */
    readonly popularTopN: number;
    /** 0 = sweeper disabled (tests; refused in production). */
    readonly sweepIntervalSeconds: number;
    /** v1.42-live (D170, §10.44): a video live's host away this long → HOST_AWAY_TIMEOUT. */
    readonly hostAwayTimeoutSeconds: number;
    /** Stale rooms ended per sweeper batch (SEC-035; LIVE_SWEEP_BATCH_SIZE). */
    readonly sweepBatchSize: number;
    /** Source of the cursor HMAC key (HKDF `live-cursor/v1`): LIVE_CURSOR_KEY, else rateLimitKeySecret. */
    readonly cursorKey: string;
    /**
     * CP-010: the LiveKit media server, or null when not configured (hosting must then be off). `url` is the public
     * URL clients get; D350 `apiUrl` is where the API's own server calls go (LIVEKIT_API_URL, else `url`).
     */
    readonly livekit: {
      readonly url: string;
      readonly apiUrl: string;
      readonly apiKey: string;
      readonly apiSecret: string;
    } | null;
    /** D350: `POST /livekit/webhook` (public, signed) is served (LIVEKIT_PUBLIC_WEBHOOK_ENABLED). */
    readonly publicWebhookEnabled: boolean;
    /** Source of the guest-number HMAC key (HKDF `live-guest/v1`): rateLimitKeySecret. */
    readonly guestKey: string;
    /** CP-016 A: the popularity boards' time zone (day and week boundaries). */
    readonly rankingsTimeZone: string;
    /** v1.88-live (D315): at least one game is on (the «مجنون اللعب» tab shows). */
    readonly gamesEnabled: boolean;
    /** v1.45-live (D201, §10.63): a second-camera pairing code's lifetime (LIVE_SECOND_CAMERA_CODE_SECONDS). */
    readonly secondCameraCodeSeconds: number;
    /**
     * v1.113-live (D351, §10.148): the capacity guard «حد الامتلاء» on `startLiveRoom`. `maxRooms` 0 = off. Weights are
     * percent of one video room; `bypassUserIds` (lower-case UUIDs) are never refused (their rooms still count).
     */
    readonly capacity: {
      readonly maxRooms: number;
      readonly videoWeightPercent: number;
      readonly audioWeightPercent: number;
      readonly retryAfterSeconds: number;
      readonly bypassUserIds: readonly string[];
    };
  };
  readonly registration: {
    readonly ttlSeconds: number;
    readonly maxLifetimeSeconds: number;
    /** Dedicated code-HMAC key source (SEC-029); falls back to rateLimitKeySecret. */
    readonly codeKey: string | undefined;
    readonly noticeIntervalSeconds: number;
    readonly cleanupIntervalSeconds: number;
    /** v1.78-social (D223, §10.75): accounts one device may create (deleted ones included). */
    readonly maxAccountsPerDevice: number;
    /** v1.78-social (D223): dedicated device-HMAC key source; falls back to rateLimitKeySecret. */
    readonly deviceKey: string | undefined;
    /**
     * v1.108-social (D343, §10.142): days a purged account's mailbox mark is kept for the sign-up credit check
     * (SIGNUP_IDENTITY_RETENTION_DAYS).
     */
    readonly identityRetentionDays: number;
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
      signupCodeIp: e.RATE_LIMIT_SIGNUP_CODE_IP,
      forgotEmail: e.RATE_LIMIT_FORGOT_EMAIL,
      forgotIp: e.RATE_LIMIT_FORGOT_IP,
      refreshSession: e.RATE_LIMIT_REFRESH_SESSION,
      authenticatedUser: e.RATE_LIMIT_AUTHENTICATED_USER,
      emailResendUser: e.RATE_LIMIT_EMAIL_RESEND_USER,
      publicIp: e.RATE_LIMIT_PUBLIC_IP,
      adminLoginIp: e.RATE_LIMIT_ADMIN_LOGIN_IP,
      adminIp: e.RATE_LIMIT_ADMIN_IP,
      adminTeamIp: e.RATE_LIMIT_ADMIN_TEAM_IP,
      staffAppUser: e.RATE_LIMIT_STAFF_APP_USER,
      staffStepUpUser: e.RATE_LIMIT_STAFF_STEP_UP_USER,
      ownerModerationUser: e.RATE_LIMIT_OWNER_MODERATION_USER,
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
      avatarUser: e.RATE_LIMIT_AVATAR_USER,
      followRequestAnswerUser: e.RATE_LIMIT_FOLLOW_REQUEST_ANSWER_USER,
      liveBlockedWordsUser: e.RATE_LIMIT_LIVE_BLOCKED_WORDS_USER,
      liveScheduleUser: e.RATE_LIMIT_LIVE_SCHEDULE_USER,
      liveGuestReadIp: e.RATE_LIMIT_LIVE_GUEST_READ_IP,
      liveSeatAskUser: e.RATE_LIMIT_LIVE_SEAT_ASK_USER,
      liveSeatActionUser: e.RATE_LIMIT_LIVE_SEAT_ACTION_USER,
      liveQuestionVoteUser: e.RATE_LIMIT_LIVE_QUESTION_VOTE_USER,
      livePodcastDirectorUser: e.RATE_LIMIT_LIVE_PODCAST_DIRECTOR_USER,
      liveSeatsReadUser: e.RATE_LIMIT_LIVE_SEATS_READ_USER,
      livePkInviteUser: e.RATE_LIMIT_LIVE_PK_INVITE_USER,
      livePkActionUser: e.RATE_LIMIT_LIVE_PK_ACTION_USER,
      livePkDareReportUser: e.RATE_LIMIT_LIVE_PK_DARE_REPORT_USER,
      liveSecondCameraCodeUser: e.RATE_LIMIT_LIVE_SECOND_CAMERA_CODE_USER,
      liveSecondCameraRedeemUser: e.RATE_LIMIT_LIVE_SECOND_CAMERA_REDEEM_USER,
      liveToolsUser: e.RATE_LIMIT_LIVE_TOOLS_USER,
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
      accountDeletionUser: e.RATE_LIMIT_ACCOUNT_DELETION_USER,
      dataExportUser: e.RATE_LIMIT_DATA_EXPORT_USER,
      dataExportDownloadUser: e.RATE_LIMIT_DATA_EXPORT_DOWNLOAD_USER,
      cpSpaceWriteUser: e.RATE_LIMIT_CP_SPACE_WRITE_USER,
      cpConfessionUser: e.RATE_LIMIT_CP_CONFESSION_USER,
      familyChatUser: e.RATE_LIMIT_FAMILY_CHAT_USER,
      dmSendUser: e.RATE_LIMIT_DM_SEND_USER,
      dmRequestUser: e.RATE_LIMIT_DM_REQUEST_USER,
      dmWriteUser: e.RATE_LIMIT_DM_WRITE_USER,
      dmGroupCreateUser: e.RATE_LIMIT_DM_GROUP_CREATE_USER,
      supportSendUser: e.RATE_LIMIT_SUPPORT_SEND_USER,
      bagSendUser: e.RATE_LIMIT_BAG_SEND_USER,
      rechargeSellUser: e.RATE_LIMIT_RECHARGE_SELL_USER,
      rechargeWriteUser: e.RATE_LIMIT_RECHARGE_WRITE_USER,
      rechargeOrderUser: e.RATE_LIMIT_RECHARGE_ORDER_USER,
      rechargeOrderActionUser: e.RATE_LIMIT_RECHARGE_ORDER_ACTION_USER,
      agencyOpenUser: e.RATE_LIMIT_AGENCY_OPEN_USER,
      hostApplyUser: e.RATE_LIMIT_HOST_APPLY_USER,
      kycStartUser: e.RATE_LIMIT_KYC_START_USER,
      kycSyncUser: e.RATE_LIMIT_KYC_SYNC_USER,
      referralApplyUser: e.RATE_LIMIT_REFERRAL_APPLY_USER,
      referralTickerIp: e.RATE_LIMIT_REFERRAL_TICKER_IP,
      topupCheckoutUser: e.RATE_LIMIT_TOPUP_CHECKOUT_USER,
      topupHandoffUser: e.RATE_LIMIT_TOPUP_HANDOFF_USER,
      topupHandoffIp: e.RATE_LIMIT_TOPUP_HANDOFF_IP,
      waitlistIp: e.RATE_LIMIT_WAITLIST_IP,
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
    gifts: {
      quantities: e.LIVE_GIFT_QUANTITIES,
      hostShareBps: e.GIFT_HOST_SHARE_PERCENTS,
      creatorShareBps: e.GIFT_CREATOR_SHARE_PERCENT,
      creatorQuipShareBps: e.GIFT_CREATOR_QUIP_SHARE_PERCENT,
      directHostShareBps: e.GIFT_DIRECT_HOST_SHARE_PERCENT,
      directCreatorShareBps: e.GIFT_DIRECT_CREATOR_SHARE_PERCENT,
      customShareBps: e.GIFT_CUSTOM_SHARE_PERCENT,
      customOwnerBps: e.GIFT_CUSTOM_OWNER_PERCENT,
      quipMaxWaitMs: e.QUIP_QUEUE_MAX_WAIT_SECONDS * 1000,
    },
    newcomerDays: e.NEWCOMER_DAYS,
    youtubeApiKey: e.YOUTUBE_API_KEY ?? null,
    boosts: {
      prices: e.LIVE_BOOST_PRICES,
      slots: e.LIVE_BOOST_SLOTS,
      maxWaitMs: e.LIVE_BOOST_MAX_WAIT_MINUTES * 60_000,
    },
    programs: {
      taskDailyCapCoins: e.TASK_DAILY_CAP_COINS,
      taskDailyCapCherries: e.TASK_DAILY_CAP_CHERRIES,
      taskMonthlyCapMinor: e.TASK_MONTHLY_CAP_MINOR,
      checkInCoins: e.TASK_CHECK_IN_COINS,
      checkInStreakBonusCoins: e.TASK_CHECK_IN_STREAK_BONUS_COINS,
      eventPrizeReviewMs: e.EVENT_PRIZE_REVIEW_HOURS * 3_600_000,
      eventsSweepIntervalSeconds: e.EVENTS_SWEEP_INTERVAL_SECONDS,
      svipTiers: e.SVIP_TIERS,
      svipWindowDays: e.SVIP_WINDOW_DAYS,
      svipStatusDays: e.SVIP_STATUS_DAYS,
      rechargePackages: e.WALLET_RECHARGE_PACKAGES,
      rechargeCurrency: e.WALLET_RECHARGE_CURRENCY,
    },
    push: {
      credentialsFile: e.FIREBASE_CREDENTIALS_FILE ?? null,
      dispatchIntervalMs: e.PUSH_DISPATCH_INTERVAL_MS,
      generalGapSeconds: e.PUSH_GENERAL_GAP_SECONDS,
      messagesGapSeconds: e.PUSH_MESSAGES_GAP_SECONDS,
    },
    economy: {
      cherriesPerCoin: e.CHERRIES_PER_COIN,
      creatorAgencyCommission: e.CREATOR_AGENCY_COMMISSION,
      agencyCommissionBps: e.AGENCY_COMMISSION_BPS,
      agencyTierCommissionBps: e.AGENCY_COMMISSION_TIER_BPS,
      agencyTierMonthlyCherries: e.AGENCY_TIER_MONTHLY_CHERRIES,
      parentCommissionBps: e.AGENCY_PARENT_COMMISSION_BPS,
      rankMinActiveHosts: e.AGENCY_RANK_MIN_ACTIVE_HOSTS,
      rankExceptionCherries: e.AGENCY_RANK_EXCEPTION_CHERRIES,
      adminMinSubAgencies: e.AGENCY_ADMIN_MIN_SUB_AGENCIES,
      activeHostMinDays: e.AGENCY_ACTIVE_HOST_MIN_DAYS,
      activeHostMinHours: e.AGENCY_ACTIVE_HOST_MIN_HOURS,
      activeHostWindowDays: e.AGENCY_ACTIVE_HOST_WINDOW_DAYS,
      leaveDays: e.AGENCY_LEAVE_DAYS,
      sweepIntervalSeconds: e.AGENCY_SWEEP_INTERVAL_SECONDS,
      probationDays: e.AGENCY_PROBATION_DAYS,
      probationMinHosts: e.AGENCY_PROBATION_MIN_HOSTS,
      probationReminderHours: e.AGENCY_PROBATION_REMINDER_HOURS,
      reopenCooldownDays: e.AGENCY_REOPEN_COOLDOWN_DAYS,
      hostApplyMinAge: e.HOST_APPLICATION_MIN_AGE,
      hostApplyReapplyDays: e.HOST_APPLICATION_REAPPLY_DAYS,
      rateCherries: e.CHERRY_PAYOUT_RATE.cherries,
      rateMinor: e.CHERRY_PAYOUT_RATE.minor,
      currency: e.CHERRY_PAYOUT_CURRENCY,
      coinRetailUsdPerMillion: e.COIN_RETAIL_USD_PER_MILLION,
      minWithdrawalMinor: e.CHERRY_WITHDRAWAL_MIN_MINOR,
      payoutDays: e.CHERRY_WITHDRAWAL_PAYOUT_DAYS,
      taskCherriesUnlockGiftMinor: e.TASK_CHERRIES_UNLOCK_GIFT_MINOR,
    },
    recharge: {
      activationMinCoins: e.RECHARGE_AGENT_ACTIVATION_MIN_COINS,
      priceTiers: e.RECHARGE_AGENT_PRICE_TIERS,
      cherryRate: e.RECHARGE_AGENT_CHERRY_RATE,
      cherryMin: e.RECHARGE_AGENT_CHERRY_MIN,
      cherryStep: e.RECHARGE_AGENT_CHERRY_STEP,
      requestTtlMinutes: e.RECHARGE_AGENT_CHERRY_REQUEST_TTL_MINUTES,
      dailyCherryCap: e.RECHARGE_AGENT_CHERRY_DAILY_CAP,
      maxEmployees: e.RECHARGE_AGENT_MAX_EMPLOYEES,
      kycRetentionDays: e.RECHARGE_AGENT_KYC_RETENTION_DAYS,
      sweepIntervalSeconds: e.RECHARGE_AGENT_SWEEP_INTERVAL_SECONDS,
      badges: {
        tierMins: e.RECHARGE_BADGE_TIERS,
        timeZone: e.RECHARGE_BADGE_TIME_ZONE,
        hours: e.RECHARGE_BADGE_HOURS,
      },
      orders: {
        enabled: e.RECHARGE_ORDERS_ENABLED,
        minCoins: e.RECHARGE_ORDER_MIN_COINS,
        maxCoins: e.RECHARGE_ORDER_MAX_COINS,
        requestTtlMinutes: e.RECHARGE_ORDER_REQUEST_TTL_MINUTES,
        paymentTtlMinutes: e.RECHARGE_ORDER_PAYMENT_TTL_MINUTES,
        disputeAfterMinutes: e.RECHARGE_ORDER_DISPUTE_AFTER_MINUTES,
        sweepIntervalSeconds: e.RECHARGE_ORDER_SWEEP_INTERVAL_SECONDS,
      },
    },
    kyc: { publicApiBaseUrl: e.API_PUBLIC_URL ?? 'https://api.kabsolive.com' },
    home: { hubCardCell: e.HOME_HUB_CARD_CELL },
    fx: {
      freeUrl: e.FX_FREE_URL,
      currencyApiBaseUrl: e.FX_CURRENCYAPI_BASE_URL,
      exchangeRateApiBaseUrl: e.FX_EXCHANGERATE_API_BASE_URL,
      freeIntervalSeconds: e.FX_FREE_INTERVAL_SECONDS,
      paidIntervalSeconds: e.FX_PAID_INTERVAL_SECONDS,
      tickSeconds: e.FX_POLL_TICK_SECONDS,
      staleAfterHours: e.FX_STALE_AFTER_HOURS,
      maxJumpPercent: e.FX_MAX_JUMP_PERCENT,
      fetchTimeoutMs: e.FX_FETCH_TIMEOUT_MS,
    },
    topup: {
      stripe:
        e.STRIPE_SECRET_KEY !== undefined &&
        e.STRIPE_WEBHOOK_SECRET !== undefined &&
        e.TOPUP_PUBLIC_BASE_URL !== undefined
          ? {
              secretKey: e.STRIPE_SECRET_KEY,
              webhookSecret: e.STRIPE_WEBHOOK_SECRET,
              publicBaseUrl: e.TOPUP_PUBLIC_BASE_URL,
              testMode: /^(sk|rk)_test_/.test(e.STRIPE_SECRET_KEY),
            }
          : null,
      publicBaseUrl: e.TOPUP_PUBLIC_BASE_URL ?? null,
      allowTestKeysInProduction: e.STRIPE_ALLOW_TEST_KEYS_IN_PRODUCTION,
      packages: e.TOPUP_PACKAGES.map((coins) => ({
        id: String(coins),
        coins,
        priceMinor: Math.round(
          (coins * (topupMinorPerMillion(e.COIN_RETAIL_USD_PER_MILLION) ?? 0)) / 1_000_000,
        ),
      })),
      currency: 'USD',
      bankTransfer: { enabled: e.STRIPE_BANK_TRANSFER_ENABLED, type: e.STRIPE_BANK_TRANSFER_TYPE },
      statementDescriptorSuffix: e.STRIPE_STATEMENT_DESCRIPTOR_SUFFIX ?? null,
      disputeAutoSubmit: e.STRIPE_DISPUTE_AUTO_SUBMIT,
      appLinkEnabled: e.TOPUP_APP_LINK_ENABLED,
      appLinkPlatforms: e.TOPUP_APP_LINK_PLATFORMS,
      appLinkSources: e.TOPUP_APP_LINK_SOURCES,
      fee: {
        grossUp: e.TOPUP_STRIPE_FEE_GROSS_UP,
        percentBps: e.TOPUP_STRIPE_FEE_PERCENT,
        fixedMinor: e.TOPUP_STRIPE_FEE_FIXED_MINOR,
      },
      termsVersion: e.TOPUP_TERMS_VERSION,
    },
    storeIap: {
      google:
        e.STORE_IAP_GOOGLE_PACKAGE_NAME !== undefined && e.STORE_IAP_GOOGLE_SERVICE_ACCOUNT_FILE !== undefined
          ? {
              packageName: e.STORE_IAP_GOOGLE_PACKAGE_NAME,
              serviceAccountFile: e.STORE_IAP_GOOGLE_SERVICE_ACCOUNT_FILE,
              rtdnToken: e.STORE_IAP_GOOGLE_RTDN_TOKEN ?? null,
            }
          : null,
      apple:
        e.STORE_IAP_APPLE_BUNDLE_ID !== undefined &&
        e.STORE_IAP_APPLE_ISSUER_ID !== undefined &&
        e.STORE_IAP_APPLE_KEY_ID !== undefined &&
        e.STORE_IAP_APPLE_PRIVATE_KEY_FILE !== undefined &&
        e.STORE_IAP_APPLE_ROOT_CERT_FILES !== undefined
          ? {
              bundleId: e.STORE_IAP_APPLE_BUNDLE_ID,
              issuerId: e.STORE_IAP_APPLE_ISSUER_ID,
              keyId: e.STORE_IAP_APPLE_KEY_ID,
              privateKeyFile: e.STORE_IAP_APPLE_PRIVATE_KEY_FILE,
              rootCertFiles: e.STORE_IAP_APPLE_ROOT_CERT_FILES,
              appAppleId: e.STORE_IAP_APPLE_APP_ID ?? null,
            }
          : null,
      acceptSandbox: e.STORE_IAP_ACCEPT_SANDBOX,
      voidedPollHours: e.STORE_IAP_VOIDED_POLL_HOURS,
      sweepIntervalSeconds: e.STORE_IAP_SWEEP_INTERVAL_SECONDS,
      consentVersion: e.STORE_IAP_CONSENT_VERSION,
    },
    whatsapp: {
      credentials:
        e.WHATSAPP_PHONE_NUMBER_ID !== undefined &&
        e.WHATSAPP_BUSINESS_ACCOUNT_ID !== undefined &&
        e.WHATSAPP_ACCESS_TOKEN_FILE !== undefined &&
        e.WHATSAPP_APP_SECRET_FILE !== undefined &&
        e.WHATSAPP_VERIFY_TOKEN_FILE !== undefined
          ? {
              phoneNumberId: e.WHATSAPP_PHONE_NUMBER_ID,
              businessAccountId: e.WHATSAPP_BUSINESS_ACCOUNT_ID,
              accessTokenFile: e.WHATSAPP_ACCESS_TOKEN_FILE,
              appSecretFile: e.WHATSAPP_APP_SECRET_FILE,
              verifyTokenFile: e.WHATSAPP_VERIFY_TOKEN_FILE,
            }
          : null,
      graphApiVersion: e.WHATSAPP_GRAPH_API_VERSION,
      graphBaseUrl: e.WHATSAPP_GRAPH_BASE_URL,
      displayName: e.WHATSAPP_DISPLAY_NAME ?? null,
      retentionDays: e.WHATSAPP_RETENTION_DAYS,
      mediaMaxBytes: e.WHATSAPP_MEDIA_MAX_BYTES,
      sweepIntervalSeconds: e.WHATSAPP_SWEEP_INTERVAL_SECONDS,
      templateCacheSeconds: e.WHATSAPP_TEMPLATE_CACHE_SECONDS,
      pushGapSeconds: e.WHATSAPP_PUSH_GAP_SECONDS,
      askLanguage: e.WHATSAPP_ASK_LANGUAGE,
    },
    adminPanel: {
      totpKey: e.ADMIN_TOTP_KEY ?? null,
      sessionIdleSeconds: e.ADMIN_SESSION_IDLE_SECONDS,
      sessionMaxSeconds: e.ADMIN_SESSION_MAX_SECONDS,
      pendingSeconds: e.ADMIN_PENDING_SECONDS,
      lockoutAttempts: e.ADMIN_LOCKOUT_ATTEMPTS,
      lockoutSeconds: e.ADMIN_LOCKOUT_SECONDS,
      staffAppGrantSeconds: e.STAFF_APP_GRANT_SECONDS,
      staffShiftIdleOffSeconds: e.STAFF_SHIFT_IDLE_OFF_SECONDS,
      dashboardTimeZone: e.ADMIN_DASHBOARD_TIME_ZONE,
      reportCardFee: { bps: e.ADMIN_REPORT_CARD_FEE_BPS, fixedMinor: e.ADMIN_REPORT_CARD_FEE_FIXED_MINOR },
      ownerProfitCoinMinorPerMillion: e.OWNER_PROFIT_COIN_VALUE_MINOR_PER_MILLION,
      adjustDailyCap: { coins: e.ADMIN_ADJUST_DAILY_CAP_COINS, cherries: e.ADMIN_ADJUST_DAILY_CAP_CHERRIES },
      renameHoldDays: e.ADMIN_USERNAME_RENAME_HOLD_DAYS,
    },
    referrals: {
      sweepIntervalSeconds: e.REFERRAL_SWEEP_INTERVAL_SECONDS,
    },
    recruits: {
      sweepIntervalSeconds: e.RECRUIT_COMMISSION_SWEEP_INTERVAL_SECONDS,
      catchUpDays: e.RECRUIT_COMMISSION_CATCH_UP_DAYS,
    },
    verificationBadges: {
      sweepIntervalSeconds: e.VERIFICATION_BADGE_SWEEP_INTERVAL_SECONDS,
    },
    medalCreators: {
      sweepIntervalSeconds: e.MEDAL_CREATOR_SWEEP_INTERVAL_SECONDS,
    },
    accountDeletion: {
      graceDays: e.ACCOUNT_DELETION_GRACE_DAYS,
      usernameQuarantineDays: e.ACCOUNT_DELETION_USERNAME_QUARANTINE_DAYS,
      supportEmail: e.SUPPORT_EMAIL,
      sweepIntervalSeconds: e.ACCOUNT_DELETION_SWEEP_INTERVAL_SECONDS,
      legalHoldDays: e.REPORT_LEGAL_HOLD_DAYS,
      ledgerRetentionDays: e.DELETED_LEDGER_RETENTION_DAYS,
    },
    dataExport: {
      minIntervalHours: e.DATA_EXPORT_MIN_INTERVAL_HOURS,
      linkDays: e.DATA_EXPORT_LINK_DAYS,
      sweepIntervalSeconds: e.DATA_EXPORT_SWEEP_INTERVAL_SECONDS,
    },
    specialUsernames: {
      graceDays: e.SPECIAL_USERNAME_GRACE_DAYS,
      sweepIntervalSeconds: e.SPECIAL_USERNAME_SWEEP_INTERVAL_SECONDS,
    },
    dm: {
      retentionHours: e.DM_RETENTION_HOURS,
      sweepIntervalSeconds: e.DM_SWEEP_INTERVAL_SECONDS,
      requestMaxMessages: e.DM_REQUEST_MAX_MESSAGES,
      deleteForEveryoneSeconds: e.DM_DELETE_FOR_EVERYONE_SECONDS,
      giftRecipientSharePercent: e.GIFT_DM_RECIPIENT_SHARE_PERCENT,
      groupMaxMembers: e.DM_GROUP_MAX_MEMBERS,
    },
    bag: {
      sweepIntervalSeconds: e.BAG_SWEEP_INTERVAL_SECONDS,
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
        e.LUCKY_GIFT_CHANCES_PER_MILLION,
        luckyPityOf(e),
      ) as LuckyTable,
      bigWinMultiplier: e.LUCKY_GIFT_BIG_WIN_MULTIPLIER,
      globalBannerMultipliers: Object.freeze([...e.LUCKY_GLOBAL_BANNER_MULTIPLIERS].sort((a, b) => a - b)),
      globalBannerGapMs: e.LUCKY_GLOBAL_BANNER_GAP_SECONDS * 1000,
      chatMinMultiplier: e.LUCKY_CHAT_MIN_MULTIPLIER,
      dayTimeZone: e.LUCKY_GIFT_DAY_TIME_ZONE,
      disabledCountries: e.LUCKY_GIFTS_DISABLED_COUNTRIES,
      countryHeader: e.LUCKY_GIFTS_COUNTRY_HEADER ?? null,
    },
    pk: {
      enabled: e.PK_ENABLED,
      inviteTtlSeconds: e.PK_INVITE_TTL_SECONDS,
      inviteCooldownSeconds: e.PK_INVITE_COOLDOWN_SECONDS,
      randomWaitSeconds: e.PK_RANDOM_WAIT_SECONDS,
      battleSeconds: e.PK_BATTLE_SECONDS,
      resultSeconds: e.PK_RESULT_SECONDS,
      effectiveMinPoints: e.PK_EFFECTIVE_MIN_POINTS,
      connectSeconds: e.PK_CONNECT_SECONDS,
      autoMatchRestSeconds: e.PK_AUTO_MATCH_REST_SECONDS,
      absenceGraceSeconds: e.PK_ABSENCE_GRACE_SECONDS,
      tickMs: e.PK_TICK_MS,
      scoreBroadcastMs: e.PK_SCORE_BROADCAST_MS,
      boosters: PK_BOOSTER_KINDS.map((kind, i) => ({
        kind,
        multiplier: e.PK_BOOSTER_MULTIPLIERS[i]!,
        durationSeconds: e.PK_BOOSTER_SECONDS[i]!,
        lastSeconds: e.PK_BOOSTER_WINDOWS[i]!,
        limitPerMatch: e.PK_BOOSTER_LIMITS[i]!,
      })),
      daresEnabled: e.PK_DARES_ENABLED,
      dareDrawSeconds: e.PK_DARE_DRAW_SECONDS,
      dareSeconds: e.PK_DARE_SECONDS,
      dareOutcomeSeconds: e.PK_DARE_OUTCOME_SECONDS,
      rematchAcceptSeconds: e.PK_REMATCH_ACCEPT_SECONDS,
      rematchMax: e.PK_REMATCH_MAX,
      pk4: {
        enabled: e.PK4_ENABLED,
        lobbySeconds: e.PK4_LOBBY_SECONDS,
        inviteTtlSeconds: e.PK4_INVITE_TTL_SECONDS,
        maxWatchersPerRoom: e.PK4_MAX_WATCHERS_PER_ROOM,
      },
    },
    live: {
      hostingEnabled: e.LIVE_HOSTING_ENABLED,
      giftTickerMinCoins: e.GIFT_GLOBAL_TICKER_MIN_COINS,
      gameWinTickerMinTickets: e.GAME_WIN_TICKER_MIN_TICKETS,
      heartbeatIntervalSeconds: e.LIVE_HEARTBEAT_INTERVAL_SECONDS,
      heartbeatStaleSeconds: e.LIVE_HEARTBEAT_STALE_SECONDS,
      popularTopN: e.LIVE_POPULAR_TOP_N,
      sweepIntervalSeconds: e.LIVE_SWEEP_INTERVAL_SECONDS,
      hostAwayTimeoutSeconds: e.LIVE_HOST_AWAY_TIMEOUT_SECONDS,
      sweepBatchSize: e.LIVE_SWEEP_BATCH_SIZE,
      cursorKey: e.LIVE_CURSOR_KEY ?? rateLimitKeySecret,
      livekit:
        e.LIVEKIT_URL !== undefined && e.LIVEKIT_API_KEY !== undefined && e.LIVEKIT_API_SECRET !== undefined
          ? {
              url: e.LIVEKIT_URL,
              apiUrl: e.LIVEKIT_API_URL ?? e.LIVEKIT_URL,
              apiKey: e.LIVEKIT_API_KEY,
              apiSecret: e.LIVEKIT_API_SECRET,
            }
          : null,
      publicWebhookEnabled: e.LIVEKIT_PUBLIC_WEBHOOK_ENABLED,
      guestKey: rateLimitKeySecret,
      rankingsTimeZone: e.LIVE_RANKINGS_TIME_ZONE,
      gamesEnabled: e.LIVE_GAMES_ENABLED,
      secondCameraCodeSeconds: e.LIVE_SECOND_CAMERA_CODE_SECONDS,
      capacity: {
        maxRooms: e.LIVE_CAPACITY_MAX_ROOMS,
        videoWeightPercent: e.LIVE_CAPACITY_WEIGHT_VIDEO_PERCENT,
        audioWeightPercent: e.LIVE_CAPACITY_WEIGHT_AUDIO_PERCENT,
        retryAfterSeconds: e.LIVE_CAPACITY_RETRY_AFTER_SECONDS,
        bypassUserIds: e.LIVE_CAPACITY_BYPASS_USER_IDS,
      },
    },
    registration: {
      ttlSeconds: e.REGISTRATION_TTL_SECONDS,
      maxLifetimeSeconds: e.REGISTRATION_MAX_LIFETIME_SECONDS,
      codeKey: e.REGISTRATION_CODE_KEY,
      noticeIntervalSeconds: e.REGISTRATION_NOTICE_INTERVAL_SECONDS,
      cleanupIntervalSeconds: e.REGISTRATION_CLEANUP_INTERVAL_SECONDS,
      maxAccountsPerDevice: e.SIGNUP_MAX_ACCOUNTS_PER_DEVICE,
      deviceKey: e.SIGNUP_DEVICE_KEY,
      identityRetentionDays: e.SIGNUP_IDENTITY_RETENTION_DAYS,
    },
    loginRecentSuccessTtlSeconds: e.LOGIN_RECENT_SUCCESS_TTL_SECONDS,
    reservedDisplayNameTerms: e.RESERVED_DISPLAY_NAME_TERMS,
    reservedDisplayNameBrandTerms: e.RESERVED_DISPLAY_NAME_BRAND_TERMS,
  };
}
