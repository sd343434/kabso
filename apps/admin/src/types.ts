/** The shapes of openapi.yaml's `admin-panel` schemas the panel reads (contract v1.60-social, D191). */
export type PanelRole = "OWNER" | "MODERATION" | "SUPPORT" | "FINANCE" | "BD";

export type Capability =
  | "dashboard.view"
  | "users.view"
  | "users.balances"
  | "users.ledger"
  | "users.ban"
  | "users.avatar"
  | "users.special_username"
  | "recharge.applications"
  | "recharge.decide"
  | "recharge.agents"
  | "recharge.topup"
  | "recharge.status"
  | "recharge.cap"
  | "withdrawals.view"
  | "withdrawals.decide"
  | "reports.view"
  | "reports.act"
  // v1.78-live (D288): the shared queue's «تم حله» and the OWNER's reopen
  | "reports.resolve"
  | "reports.reopen"
  | "site.settings"
  | "payments.settings"
  // v1.75-social (D222)
  | "storage.settings"
  // v1.80-kyc (D227)
  | "kyc.settings"
  | "kyc.view"
  // v1.81-social (D245)
  | "fx.settings"
  // v1.65-social (D197)
  | "users.list"
  | "users.export"
  | "users.sessions"
  | "agencies.view"
  | "agencies.manage"
  // v1.70-social (D206)
  | "agencies.applications"
  | "agencies.probation"
  /** v1.82-live (D295): «حظر الوكالة» (OWNER). */
  | "agencies.ban"
  // v1.73-social (D209)
  | "hosts.applications"
  | "hosts.applications.photos"
  | "hosts.applications.decide"
  // v1.74-social (D217)
  | "referrals.view"
  | "referrals.decide"
  | "referrals.settings"
  | "pk_dares.view"
  | "pk_dares.edit"
  // v1.71-live (D281): «الأهداف الذكية» (OWNER only).
  | "host_targets.view"
  | "host_targets.edit"
  // v1.60-live (D250): live moderation «مراقبة البث».
  | "lives.watch"
  | "lives.reports"
  | "lives.moderate"
  | "devices.ban"
  // v1.64-live (D260): the hidden watch, and who is on shift (OWNER).
  | "lives.watch.hidden"
  | "staff.shifts"
  | "lives.view"
  | "lives.manage"
  | "catalog.view"
  | "catalog.manage"
  | "items.grant"
  | "finance.view"
  | "finance.refund"
  | "audit.view"
  | "team.manage"
  | "programs.view"
  | "waitlist.view"
  // v1.69-social (D204).
  | "recharge.disputes"
  | "recharge.disputes.resolve"
  | "recharge.rates"
  // D275: the top-up records, read-only (agents' top-ups, users' card orders).
  | "recharge.topups.view"
  // v1.71-social (D207)
  | "gifts.categories"
  // v1.72-social (D208)
  | "users.control_view"
  | "users.lock"
  | "users.restrict"
  | "users.password"
  | "users.email"
  | "users.profile_edit"
  | "users.content"
  | "users.balance_adjust"
  | "users.delete"
  // v1.78-social (D223)
  | "users.device_view"
  | "users.device_exception"
  // v1.75-live (D285): recruitment by staff «الاستقطاب» and the creator programme.
  | "recruits.mine"
  | "recruits.view"
  | "recruits.manage"
  | "creators.applications"
  | "creators.decide"
  // v1.89-social (D290): level-raise requests «طلب رفع ليفيل».
  | "levels.raise.request"
  | "levels.raise.decide"
  // v1.90-social (D293): automatic verification badges «شارة التوثيق».
  | "verification.view"
  | "verification.settings"
  // v1.95-social (D301): «صندوق المؤسس» (OWNER only).
  | "owner.inbox"
  // D301 follow-up (§10.112.10): the fixed monthly costs of «الربح» (OWNER only).
  | "owner.costs"
  // v1.97-social (D303): gift events «فعاليات الهدايا» (create / edit / hold), OWNER.
  | "events.manage"
  // v1.110-social (D345): «مشتريات المتجر».
  | "store_iap.view"
  | "store_iap.manage"
  | "store_iap.unban"
  // v1.116-social (D355): «واتساب».
  | "support.whatsapp"
  | "support.whatsapp.manage"
  // v1.120-social (D360): «مشاهدة فقط» — the WhatsApp level VIEW (the three come from the staff member's level).
  | "support.whatsapp.view";

/** v1.90-social (D293, §10.105): the automatic verification badge, highest first. */
export const VERIFICATION_BADGES = [
  "OWNER",
  "STAFF",
  "RECHARGE_AGENT",
  "HOST_AGENT",
  "CREATOR",
  "VERIFIED_HOST",
] as const;
export type VerificationBadge = (typeof VERIFICATION_BADGES)[number];

export interface AdminSessionInfo {
  admin: { id: string; email: string; username: string; displayName: string };
  roles: PanelRole[];
  capabilities: Capability[];
  csrfToken: string;
  expiresAt: string;
  idleSeconds: number;
}

export interface AdminLoginResponse {
  next: "TOTP_ENROL" | "TOTP_VERIFY";
  csrfToken: string;
  expiresAt: string;
}

export interface PageInfo {
  hasMore: boolean;
  nextCursor: string | null;
}

export interface Page<T> {
  data: T[];
  page: PageInfo;
}

export interface Dashboard {
  since: string;
  today: {
    newUsers: number;
    agentCoinsSold: number;
    agentSales: number;
    giftsSent: number;
    giftCoins: number;
  };
  livesNow: number;
  pending: {
    rechargeApplications: number;
    withdrawals: number;
    reports: number;
  };
}

/** v1.62-social (D193): PENDING_DELETION during the deletion grace period (shown by D208's account group). */
export type UserStatus =
  | "ACTIVE"
  | "SUSPENDED"
  | "PENDING_DELETION"
  | "DELETED";

export interface UserRow {
  id: string;
  username: string;
  displayName: string;
  email: string;
  status: UserStatus;
  avatarUrl: string | null;
  createdAt: string;
}

export interface LedgerRow {
  id: string;
  delta: number;
  balanceAfter: number;
  reason: string;
  createdAt: string;
}

export interface UserDetail {
  user: UserRow & {
    role: "USER" | "ADMIN";
    lastActiveAt: string | null;
    countryCode: string | null;
    bio: string | null;
    baseUsername: string;
    /** v1.136-social (D384): the VIP animated picture (a looping WebP), present only when the person has one. */
    animatedAvatarUrl?: string;
  };
  specialUsername: {
    username: string;
    source: string;
    expiresAt: string | null;
  } | null;
  adminRoles: PanelRole[];
  /** D220: `cherriesReceived` / `coinsSent` are the person card's lifetime totals (also when hidden in the app). */
  balances: {
    coins: number;
    cherries: number;
    lockedTaskCherries: number;
    cherriesReceived: number;
    coinsSent: number;
    /** v1.126-social (D370): «نقاط الشحن» (may be below 0); absent from an older server. */
    rechargePoints?: number;
  } | null;
  ledger: {
    coins: LedgerRow[];
    cherries: LedgerRow[];
    rechargePoints?: LedgerRow[];
  } | null;
  rechargeAgent: {
    status: string;
    code: string | null;
    stockCoins: number;
    dailyCherryCap: number | null;
    suspendReason: string | null;
  } | null;
  hostAgent: {
    inviteCode: string;
    hostCode: string | null;
    rank: string;
    suspended: boolean;
  } | null;
  agencyHost: { agencyInviteCode: string; status: string } | null;
  /** v1.90-social (D293): the automatic verification badge, when it was granted and last confirmed; null when none. */
  verification: {
    badge: VerificationBadge;
    since: string;
    computedAt: string;
  } | null;
  reports: {
    open: number;
    recent: {
      id: string;
      reason: string;
      status: string;
      targetType: string;
      createdAt: string;
    }[];
  };
}

export interface UserRef {
  id: string;
  username: string;
  displayName: string;
}

export interface ApplicationRow {
  id: string;
  status: "PENDING" | "APPROVED" | "REJECTED";
  createdAt: string;
  decidedAt: string | null;
  purged: boolean;
  user: UserRef;
}

export interface Application {
  /** v1.80-kyc (D227): the applicant's identity check (needed before the first top-up). */
  kyc?: AdminKycSummary;
  id: string;
  status: "PENDING" | "APPROVED" | "REJECTED";
  createdAt: string;
  decidedAt: string | null;
  purgedAt: string | null;
  rejectReason: string | null;
  user: UserRef & { email: string };
  fullName: string | null;
  phone: string | null;
  locations: { country: string; cities: string[] }[] | null;
  paymentMethods: { country: string; type: string }[] | null;
  photos: { photo: boolean; selfie: boolean };
}

export interface Pricing {
  activationMinCoins: number;
  priceTiers: { minCoins: number; minorPerMillion: number }[];
  currency: "USD";
}

export interface AgentRow {
  userId: string;
  code: string | null;
  status: "APPROVED" | "ACTIVE" | "SUSPENDED";
  stockCoins: number;
  dailyCherryCap: number | null;
  countries: string[];
  approvedAt: string;
  activatedAt: string | null;
  suspendReason: string | null;
  username: string;
  displayName: string;
}

export interface AgentPage extends Page<AgentRow> {
  pricing: Pricing;
}
/** v1.87-social (D287): `AdminRechargeAgentEmployee`. */
export interface EmployeeTotals {
  count: number;
  coins: number;
}
export interface EmployeeStats {
  today: EmployeeTotals;
  last7Days: EmployeeTotals;
  last30Days: EmployeeTotals;
}
export interface AgentEmployee {
  userId: string;
  username: string;
  displayName: string;
  timeZone: string;
  onShiftNow: boolean;
  canBuyCherries: boolean;
  receivesOrders: boolean;
  addedAt: string;
  removedAt: string | null;
  sales: EmployeeStats;
  cherryPurchases: EmployeeStats;
  orders: EmployeeStats;
}

export interface TopUpResult {
  topupId: string;
  first: boolean;
  code: string | null;
  stockCoins: number;
  tier: string;
  minorPerMillion: number;
  expectedMinor: number;
  paidMinor: number;
}

export interface WithdrawalRow {
  id: string;
  status: "PENDING" | "PAID" | "REJECTED";
  cherries: number;
  amountMinor: number;
  currency: string;
  payoutDetails: string;
  createdAt: string;
  decidedAt: string | null;
  decisionNote: string | null;
  user: UserRef;
}

export interface PanelReport {
  id: string;
  targetType: string;
  targetId: string;
  reason: string;
  note: string | null;
  status: "OPEN" | "ACTIONED" | "DISMISSED";
  createdAt: string;
  resolvedAt: string | null;
  /** v1.78-live (D288): who resolved it and their note (null while OPEN). */
  resolvedBy: { id: string; username: string; displayName: string } | null;
  resolutionNote: string | null;
  /** v1.134-social (D381, §10.171.3): 2 a safety reason, 1 a PRIORITY_SUPPORT holder's report, 0 otherwise. */
  priority?: number;
  reporter?: {
    id: string;
    username: string;
    displayName: string;
    avatarUrl: string | null;
  };
  dmSnapshot?: {
    text: string | null;
    sender: string | null;
    mediaUrl: string | null;
  };
  linkSnapshot?: { username: string; url: string; label: string | null };
  /** v1.104-social (D339): a DM_GROUP report — the group as it was when reported. */
  dmGroupSnapshot?: {
    name: string | null;
    memberCount: number;
    members: string[];
    thread: {
      messages: {
        id: string;
        sender: string | null;
        kind: string;
        text: string | null;
      }[];
    } | null;
    purged: boolean;
  };
  preview: {
    text: string | null;
    mediaUrl: string | null;
    author: {
      id: string;
      username: string;
      displayName: string;
      status: string;
    } | null;
    gone: boolean;
  };
}

export interface SiteSettings {
  socials: {
    instagram: string | null;
    tiktok: string | null;
    whatsapp: string | null;
  };
  topupEnabled: boolean;
}

/** v1.49-live (D228): `CameraFxSettings` — the app's camera effects engine. */
export type CameraFxEngine = "DEEPAR" | "FREE";
export interface CameraFxSettings {
  cameraFxEngine: CameraFxEngine;
}

/** v1.62-live (D254): `LevelTickerSettings` — the level from which a level-up is a banner in every live. */
export interface LevelTickerSettings {
  minLevel: number;
}

/** v1.85-live (D305): `GlobalStripsSettings` — the thresholds of the gifts strip and the games strip. */
export interface GlobalStripsSettings {
  /** One gift's price (coins). */
  giftMinCoins: number;
  /** A game prize (tickets). */
  gameMinTickets: number;
  /** v1.89-live (D318): a lucky win's chat line from this multiplier (absent from an older API). */
  luckyChatMinMultiplier?: number;
  /** v1.89-live (D318): the lucky multipliers the threshold may be (absent from an older API). */
  luckyMultipliers?: number[];
  /** v1.111-live (D347): the global lucky banner's multipliers (absent from an older API). */
  luckyGlobalMultipliers?: number[];
  /** v1.111-live (D347): the global lucky banner's gap, seconds (absent from an older API). */
  luckyGlobalGapSeconds?: number;
}

/** v1.64-social (D196): `PaymentKeyInfo` — all the panel ever sees of a Stripe secret. */
export interface PaymentKeyInfo {
  kind: "secret" | "restricted" | "webhook";
  mode: "live" | "test" | null;
  last4: string;
  source: "panel" | "env";
  setBy: { id: string; displayName: string } | null;
  setAt: string | null;
}

export interface PaymentOptions {
  bankTransferEnabled: boolean | null;
  statementDescriptorSuffix: string | null;
  disputeAutoSubmit: boolean | null;
  appLinkEnabled: boolean | null;
  /** v1.109-social (D344): Stripe's fee in the website price (null = the server's value). */
  stripeFeeGrossUp: boolean | null;
  stripeFeePercentBps: number | null;
  stripeFeeFixedMinor: number | null;
}

/** v1.64-social (D196): `AdminPaymentSettings` «الدفع (Stripe)». */
export interface PaymentSettings {
  source: "panel" | "env" | "none";
  configured: boolean;
  mode: "live" | "test" | null;
  secretKey: PaymentKeyInfo | null;
  webhookSecret: PaymentKeyInfo | null;
  previousWebhookSecretValidUntil: string | null;
  panelKeys: {
    secretKey: PaymentKeyInfo;
    webhookSecret: PaymentKeyInfo;
  } | null;
  envKeys: { secretKey: PaymentKeyInfo; webhookSecret: PaymentKeyInfo } | null;
  panelKeysIgnored: "unreadable" | "test_key_in_production" | null;
  publishableKey: string | null;
  options: PaymentOptions;
  effective: {
    bankTransferEnabled: boolean;
    statementDescriptorSuffix: string | null;
    disputeAutoSubmit: boolean;
    appLinkEnabled: boolean;
    stripeFeeGrossUp: boolean;
    stripeFeePercentBps: number;
    stripeFeeFixedMinor: number;
  };
  /** v1.109-social (D344): the currency of the fixed fee and the website prices. */
  feeCurrency: string;
  publicBaseUrl: string | null;
  webhookUrl: string | null;
  webhookEvents: string[];
  testKeysAllowed: boolean;
  connectionTestSkippable: boolean;
}

/** `PaymentKeyCheck` («اختبار الاتصال»). */
export interface PaymentKeyCheck {
  ok: true;
  kind: "secret" | "restricted" | "webhook";
  mode: "live" | "test" | null;
  last4: string;
  restricted: boolean;
}

// ---- v1.65-social (D197): the panel v2 ----------------------------------------------------------------------------

export interface PersonRef {
  id: string;
  username: string;
  displayName: string;
  avatarUrl?: string | null;
}

export interface Kpi {
  value: number;
  today: number;
  yesterday: number;
  spark: number[];
}

export interface StatsOverview {
  since: string;
  timeZone: string;
  kpis: {
    newUsers: Kpi;
    coinsSold: Kpi & { agentsToday: number; websiteToday: number };
    giftCoins: Kpi & { giftsToday: number };
    lives: Kpi;
    pending: Kpi;
  };
}

export interface StatsDay {
  day: string;
  newUsers: number;
  agentCoins: number;
  websiteCoins: number;
  coinsSold: number;
  giftCoins: number;
  giftsSent: number;
  livesStarted: number;
  newPending: number;
}

export type AttentionKind =
  | "RECHARGE_APPLICATIONS"
  | "WITHDRAWALS"
  | "REPORTS"
  | "AGENCY_COMPLAINTS"
  | "TOPUP_CASES";

export interface Attention {
  total: number;
  items: { kind: AttentionKind; count: number; oldestAt: string | null }[];
}

export interface ActivityRow {
  id: string;
  action: string;
  targetType: string | null;
  targetId: string | null;
  createdAt: string;
  actor: PersonRef | null;
}

export interface AuditRow extends ActivityRow {
  metadata: Record<string, unknown>;
  ip: string | null;
}

export interface SearchResult {
  users: UserRow[];
  agents: {
    userId: string;
    code: string | null;
    status: string;
    username: string;
    displayName: string;
  }[];
  agencies: {
    id: string;
    inviteCode: string;
    hostCode: string | null;
    rank: string;
    suspended: boolean;
    ownerUsername: string;
    ownerDisplayName: string;
  }[];
}

// ---- v1.69-social (D204): «نزاعات الشحن» and «أسعار الصرف» ----

export interface RechargePrice {
  usdMinor: number;
  usd: string;
  local: {
    currency: string;
    minor: number;
    digits: number;
    amount: string;
    rate: string;
  } | null;
}

export interface OrderPerson {
  id: string;
  username: string;
  displayName: string;
  email?: string | null;
  code?: string | null;
  stockCoins?: number;
}

export interface DisputeRow {
  id: string;
  status: string;
  coins: number;
  country: string;
  price: RechargePrice;
  disputedAt: string;
  disputedBy: string | null;
  closedAt: string | null;
  buyer: OrderPerson;
  agent: OrderPerson;
}

export interface OrderMessage {
  id: string;
  kind: "TEXT" | "IMAGE" | "PAYMENT_DETAILS" | "TRANSFER_PROOF" | "SYSTEM";
  role: "BUYER" | "AGENT" | "EMPLOYEE" | "ADMIN" | "SYSTEM";
  author: { id: string; username: string; displayName: string } | null;
  text: string | null;
  method: string | null;
  event: string | null;
  hasImage: boolean;
  createdAt: string;
  adminUserId: string | null;
}

export interface AdminOrder {
  id: string;
  status: string;
  coins: number;
  heldCoins: number;
  country: string;
  price: RechargePrice;
  paymentType: string;
  createdAt: string;
  detailsAt: string | null;
  noticeAcknowledgedAt: string | null;
  paidAt: string | null;
  disputedAt: string;
  disputedBy: string | null;
  closedAt: string | null;
  closeReason: string | null;
  buyer: OrderPerson;
  agent: OrderPerson;
  messages: OrderMessage[];
}

/** v1.81-social (D245): where an automatic rate came from. */
export type FxSource = "OPEN_ER_API" | "CURRENCYAPI" | "EXCHANGERATE_API";
export type FxPaidProvider = "CURRENCYAPI" | "EXCHANGERATE_API";

/** `AdminFxRateRow` (D204; D245): a country's effective rate (manual «يدوي» over automatic «تلقائي») and both sources. */
export interface ExchangeRateRow {
  country: string;
  currency: string | null;
  digits: number;
  unitsPerUsd: string | null;
  updatedAt: string | null;
  source: "MANUAL" | "AUTO" | "USD" | "NONE";
  stale: boolean;
  manual: {
    currency: string;
    digits: number;
    unitsPerUsd: string;
    updatedAt: string;
  } | null;
  auto: {
    currency: string;
    unitsPerUsd: string;
    source: FxSource;
    fetchedAt: string;
    providerUpdatedAt: string | null;
    stale: boolean;
    held: {
      unitsPerUsd: string;
      source: FxSource;
      at: string;
      jumpPercent: number;
    } | null;
  } | null;
}

/** `AdminFxStatus` (D245): the automatic feed's status card. */
export interface FxStatus {
  source: FxSource;
  sourceName: string;
  paidActive: boolean;
  paidIgnored: "unreadable" | null;
  intervalSeconds: number;
  polling: boolean;
  lastAttemptAt: string | null;
  lastSuccessAt: string | null;
  lastSource: FxSource | null;
  lastProviderUpdatedAt: string | null;
  nextFetchAt: string | null;
  lastError: { at: string; issue: string; detail: string | null } | null;
  failures: number;
  lastReport: {
    accepted?: number;
    held?: number;
    rejected?: number;
    heldCurrencies?: string[];
    rejectedCurrencies?: string[];
  } | null;
  currencies: number;
  held: number;
  staleAfterHours: number;
  maxJumpPercent: number;
  attribution: { text: string; url: string } | null;
}

export interface ExchangeRates {
  retailUsdPerMillion: number;
  status: FxStatus;
  data: ExchangeRateRow[];
}

/** `FxTestReport` (D245): «اختبار الاتصال» (never the key, only its last 4). */
export interface FxTestReport {
  ok: boolean;
  at: string;
  provider: FxPaidProvider;
  apiKeyLast4: string;
  ms: number;
  issue: string | null;
  detail: string | null;
  currencies: number;
  providerUpdatedAt: string | null;
  by?: { id: string; displayName: string } | null;
}

/** `AdminFxSettings` (D245): the OWNER's paid provider «مزوّد أسعار الصرف». */
export interface FxSettings {
  status: "active" | "off" | "not_configured";
  provider: FxPaidProvider;
  enabled: boolean;
  apiKey: {
    last4: string;
    setBy: { id: string; displayName: string } | null;
    setAt: string | null;
  } | null;
  updatedAt: string | null;
  panelIgnored: "unreadable" | null;
  lastTest: FxTestReport | null;
  paidIntervalSeconds: number;
  freeIntervalSeconds: number;
  providers: {
    code: FxPaidProvider;
    name: string;
    site: string;
    signupUrl: string | null;
    docsUrl: string;
  }[];
  connectionTestSkippable: boolean;
}

// ---- v1.72-social (D208, CONVENTIONS §10.67): the account controls -------------------------------------------------
export type RestrictionKind =
  | "LOCK"
  | "CHAT_MUTE"
  | "NO_LIVE"
  | "NO_GIFTS"
  | "NO_POSTING";

export interface Restriction {
  id: string;
  kind: RestrictionKind;
  reason: string;
  startsAt: string;
  endsAt: string;
  via: "panel" | "cli";
  active: boolean;
  liftedAt: string | null;
  liftReason: string | null;
  createdAt: string;
}

export interface UserControl {
  status: "ACTIVE" | "SUSPENDED" | "PENDING_DELETION" | "DELETED";
  lock: Restriction | null;
  restrictions: Restriction[];
  history: Restriction[];
  password: { changeRequired: boolean };
  email: { address: string; verified: boolean };
  gender: "MALE" | "FEMALE" | "UNDISCLOSED" | null;
  cover: null;
  deletion: {
    requestedAt: string;
    purgeAfter: string;
    requestedVia: "APP" | "ADMIN";
  } | null;
  adjustToday: {
    coins: number;
    cherries: number;
    capCoins: number;
    capCherries: number;
  };
  adjustments: {
    id: string;
    currency: "COINS" | "CHERRIES";
    delta: number;
    before: number;
    after: number;
    reason: string;
    actor: string | null;
    createdAt: string;
  }[];
}

/** v1.73-social (D209): `AdminHostApplicationRow` — a row of «طلبات المضيفين» (no private field). */
export interface HostApplicationRow {
  id: string;
  status: "PENDING" | "APPROVED" | "REJECTED" | "CANCELLED";
  displayName: string;
  country: string;
  user: PersonRef;
  decidedBy: PersonRef | null;
  createdAt: string;
  decidedAt: string | null;
  purged: boolean;
}

/** v1.73-social (D209): `AdminHostApplication` — the application with its private fields and the account summary. */
export interface HostApplicationDetail {
  /** v1.80-kyc (D227): the applicant's identity check. */
  kyc?: AdminKycSummary;
  id: string;
  status: HostApplicationRow["status"];
  createdAt: string;
  decidedAt: string | null;
  decidedBy: PersonRef | null;
  rejectReason: string | null;
  cancelReason: "USER" | "AGENCY" | "ACCOUNT" | null;
  purgedAt: string | null;
  reapplyAt: string | null;
  displayName: string;
  country: string;
  dateOfBirth: string | null;
  age: number | null;
  contact: {
    type: "WHATSAPP" | "TELEGRAM" | "PHONE" | "EMAIL" | "OTHER";
    value: string | null;
  };
  bio: string | null;
  links: string[];
  rulesAcceptedAt: string;
  photos: { photo: boolean; selfie: boolean };
  account: {
    id: string;
    username: string;
    displayName: string;
    avatarUrl: string | null;
    email: string;
    status: string;
    createdAt: string;
    accountAgeDays: number;
    profileCountry: string | null;
    openReports: number;
    totalReports: number;
    bans: number;
    warnings: number;
    host: {
      source: "ADMIN" | "AGENCY" | "IDENTITY" | "CREATOR";
      grantedAt: string;
    } | null;
    agency: { role: "HOST" | "OWNER"; inviteCode: string } | null;
  };
  history: {
    id: string;
    status: HostApplicationRow["status"];
    createdAt: string;
    decidedAt: string | null;
    rejectReason: string | null;
  }[];
}

// ---- v1.75-social (D222): «التخزين (R2 / S3)» ---------------------------------------------------------------

export interface StorageKeyInfo {
  last4: string;
  setBy: { id: string; displayName: string } | null;
  setAt: string | null;
}

export type StorageProvider = "R2" | "S3";

export interface StorageTarget {
  provider: StorageProvider;
  accountId: string | null;
  endpoint: string | null;
  region: string;
  forcePathStyle: boolean;
  publicBucket: string | null;
  publicBaseUrl: string | null;
  privateBucket: string | null;
}

export type StorageStepName =
  | "put"
  | "head"
  | "get"
  | "public_read"
  | "not_public"
  | "delete";
export type StorageIssue =
  | "bad_credentials"
  | "access_denied"
  | "no_such_bucket"
  | "unreachable"
  | "mismatch"
  | "not_public"
  | "publicly_readable"
  | "http_status"
  | "error";

export interface StorageTestStep {
  bucket: "public" | "private";
  step: StorageStepName;
  ok: boolean;
  ms: number;
  issue: StorageIssue | null;
  detail: string | null;
}

export interface StorageTestReport {
  ok: boolean;
  at: string;
  target: StorageTarget;
  accessKeyIdLast4: string | null;
  steps: StorageTestStep[];
}

/** `AdminStorageSettings`. */
export interface StorageSettings {
  status: "active" | "env" | "off" | "not_configured";
  source: "panel" | "env" | "none";
  uploadsEnabled: boolean;
  publicBaseUrl: string | null;
  enabled: boolean;
  panel: {
    provider: StorageProvider;
    accountId: string | null;
    endpoint: string | null;
    region: string | null;
    forcePathStyle: boolean;
    publicBucket: string | null;
    publicBaseUrl: string | null;
    privateBucket: string | null;
    accessKeyId: StorageKeyInfo | null;
    secretAccessKey: StorageKeyInfo | null;
    missing: string[];
    updatedAt: string | null;
  };
  env: {
    configured: boolean;
    uploadsEnabled: boolean;
    endpoint: string | null;
    region: string;
    bucket: string | null;
    publicBaseUrl: string | null;
    accessKeyIdLast4: string | null;
  };
  panelIgnored: "unreadable" | null;
  lastTest:
    | (StorageTestReport & { by: { id: string; displayName: string } | null })
    | null;
  publicPrefix: string;
  healthcheckPrefix: string;
  connectionTestSkippable: boolean;
}

// ---- v1.74-social (D217, CONVENTIONS §10.71): «الدعوات» ---------------------------------------------------------
export type ReferralStatus = "PENDING" | "QUALIFIED" | "REJECTED" | "VOID";
export type ReferralRewardKind =
  | "SIGNUP_INVITER"
  | "SIGNUP_INVITEE"
  | "FIRST_RECHARGE"
  | "MILESTONE";

export interface ReferralPerson {
  id: string;
  username: string;
  displayName: string;
  avatarUrl: string | null;
  status: string;
}

/** `AdminReferralRow` */
export interface ReferralRow {
  id: string;
  status: ReferralStatus;
  source: "SIGNUP" | "LATER";
  code: string;
  rejectReason: string | null;
  voidReason: string | null;
  inviter: ReferralPerson;
  invitee: ReferralPerson;
  holdUntil: string;
  firstRecharge: boolean;
  pendingCherries: number;
  creditedCherries: number;
  createdAt: string;
}

/** `AdminReferralReward` */
export interface ReferralReward {
  id: string;
  userId: string;
  kind: ReferralRewardKind;
  status: "PENDING" | "CREDITED" | "VOID" | "REVERSED";
  cherries: number;
  holdUntil: string;
  baseCoins: number | null;
  rateBps: number | null;
  rechargeReason: string | null;
  creditedAt: string | null;
  voidedAt: string | null;
  voidReason: string | null;
  /** REVERSED: taken back when the team voided the referral; the part the balance did not cover. */
  reversedAt: string | null;
  reversalShortfall: number | null;
}

/** `AdminReferral.voidClawback`: what «إلغاء الدعوة» would take back now. */
export interface ReferralClawback {
  cherries: number;
  shortfall: number;
  rewards: number;
  people: {
    userId: string;
    cherries: number;
    balance: number;
    shortfall: number;
  }[];
}

/** `AdminReferral` */
export interface ReferralDetail {
  id: string;
  status: ReferralStatus;
  source: "SIGNUP" | "LATER";
  code: string;
  rejectReason: string | null;
  voidReason: string | null;
  inviter: ReferralPerson;
  invitee: ReferralPerson;
  decidedBy: ReferralPerson | null;
  holdUntil: string;
  firstRechargeAt: string | null;
  qualifiedAt: string | null;
  voidedAt: string | null;
  createdAt: string;
  signals: {
    installId: boolean;
    ip: string | null;
    sameDeviceReferrals: number;
    sameEmailReferrals: number;
  };
  rewards: ReferralReward[];
  voidClawback: ReferralClawback;
}

/** `AdminLiveBoostStage` (v1.51-live, D233): one rocket stage. */
export interface AdminLiveBoostStage {
  stage: number;
  minutes: number;
  priceCoins: number;
  configCoins: number;
  custom: boolean;
  updatedAt: string | null;
}

/** `AdminLiveBoostPrices` (v1.51-live, D233). */
export interface AdminLiveBoostPrices {
  stages: AdminLiveBoostStage[];
}

/** `MedalCategory` (v1.81-live, D291): the app's medals page tabs. */
export type MedalCategory = "ACHIEVEMENT" | "ACTIVITY";

/** `MedalMetric` (v1.81-live, D291): what a medal's levels count. */
export type MedalMetric =
  | "LIVES_HOSTED"
  | "LIVE_HOURS"
  | "CHARM_LEVEL"
  | "FAMILY_JOINED"
  | "CP_FORMED"
  | "BULLETS_SENT"
  | "GIFTS_SENT_COINS"
  | "LUCKY_GIFTS_SENT_COINS"
  | "ALL_REQUIREMENTS"
  | MedalRequirementMetric
  | "PK_DARES_POINTS";

/** D300 (v1.83-live): a requirement metric of a multi-requirement medal («مدرسة المحتوى»). */
export type MedalRequirementMetric =
  | "CREATOR_FOLLOWERS"
  | "CREATOR_LIKES"
  | "CREATOR_VIEWS";

/** `MedalLevelRequirement` (v1.83-live, D300): one threshold of a multi-requirement level. */
export interface AdminMedalRequirement {
  metric: MedalRequirementMetric;
  threshold: number;
}

/** `AdminMedalLevel` (v1.81-live, D291). */
export interface AdminMedalLevel {
  level: number;
  threshold: number;
  nameAr: string | null;
  nameEn: string | null;
  iconUrl: string | null;
  /** D291: the level's art bundled in the app (asset key), or null. */
  iconAsset: string | null;
  holders: number;
  /** D300 (v1.83-live): the level's thresholds, all needed together; empty (or absent from an older server) otherwise. */
  requirements?: AdminMedalRequirement[];
}

/** `AdminMedal` (v1.81-live, D291). */
export interface AdminMedal {
  code: string;
  nameAr: string;
  nameEn: string;
  iconKey: string;
  sortOrder: number;
  category: MedalCategory;
  metric: MedalMetric | null;
  /** D291: a name-side icon, not a wearable medal (read-only). */
  retired: boolean;
  holders: number;
  levels: AdminMedalLevel[];
}

/** `AdminMedalList` (v1.81-live, D291). */
export interface AdminMedalList {
  data: AdminMedal[];
}

/** `AdminReferralSettings` */
export interface ReferralSettings {
  enabled: boolean;
  inviterSignupCherries: number;
  inviteeSignupCherries: number;
  firstRechargeBps: number;
  milestones: { friends: number; cherries: number }[];
  dailySignupCap: number;
  holdHours: number;
  applyWindowDays: number;
  selfIpWindowHours: number;
  updatedAt: string;
  updatedById: string | null;
}

/** v1.78-social (D223): the accounts created on a user's sign-up device (`getAdminDeviceSignups`). */
export interface DeviceSignups {
  known: boolean;
  platform: string | null;
  createdAt: string | null;
  defaultMax: number;
  maxAccounts: number;
  count: number;
  exception: {
    maxAccounts: number;
    reason: string;
    grantedBy: { id: string; username: string } | null;
    grantedAt: string;
  } | null;
  accounts: {
    id: string;
    username: string;
    displayName: string;
    status: UserStatus;
    createdAt: string;
    self: boolean;
  }[];
}

// ---- v1.80-kyc (D227): identity verification with Didit ----------------------------------------------------------

export type KycPurpose = "HOST_APPLICATION" | "AGENCY_OPEN" | "RECHARGE_AGENT";
export type KycStatus =
  | "NOT_STARTED"
  | "IN_PROGRESS"
  | "IN_REVIEW"
  | "APPROVED"
  | "DECLINED"
  | "EXPIRED"
  | "ABANDONED";

/** `AdminKycCheck`. */
export interface AdminKycCheck {
  id: string;
  purpose: KycPurpose;
  status: KycStatus;
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
  duplicates: { id: string; username: string; displayName: string }[];
  createdAt: string;
  decidedAt: string | null;
  consoleUrl: string;
}

/** `AdminKycSummary`: on the three application pages. */
export interface AdminKycSummary {
  enabled: boolean;
  required: boolean;
  satisfied: boolean;
  workflowId: string | null;
  approved: AdminKycCheck | null;
  latest: AdminKycCheck | null;
}

/** `AdminKycMedia`. */
export interface AdminKycMedia {
  portrait: string | null;
  front: string | null;
  back: string | null;
  liveness: string | null;
  fetchedAt: string;
}

export interface KycKeyInfo {
  last4: string;
  setBy: { id: string; displayName: string } | null;
  setAt: string | null;
}

export type KycWorkflowField =
  | "workflowId"
  | "workflowIdHost"
  | "workflowIdAgency"
  | "workflowIdRecharge";

export interface KycTestReport {
  ok: boolean;
  at: string;
  apiKeyLast4: string | null;
  apiKey: { ok: boolean; issue: string | null; ms: number };
  workflows: {
    field: KycWorkflowField;
    workflowId: string;
    ok: boolean;
    label: string | null;
    features: string | null;
    issue: string | null;
  }[];
}

/** `AdminKycSettings`. */
export interface KycSettings {
  status: "active" | "off" | "not_configured";
  enabled: boolean;
  apiKey: KycKeyInfo | null;
  webhookSecret: KycKeyInfo | null;
  workflowId: string | null;
  workflowIdHost: string | null;
  workflowIdAgency: string | null;
  workflowIdRecharge: string | null;
  maxSessionsPerDay: number;
  missing: ("apiKey" | "webhookSecret" | "workflowId")[];
  updatedAt: string | null;
  panelIgnored: "unreadable" | null;
  lastTest:
    | (KycTestReport & { by: { id: string; displayName: string } | null })
    | null;
  webhookUrl: string;
  callbackUrl: string;
  consoleUrl: string;
  connectionTestSkippable: boolean;
}

// ---- v1.50-live (D229, CONVENTIONS §10.80): «أحكام PK» --------------------------------------------------------------
export type PkDareLevel = "EASY" | "MEDIUM" | "HARD";
export type PkDareCategory =
  | "FUNNY"
  | "SINGING"
  | "ACTING"
  | "TALK"
  | "TRUTH"
  | "DANCE_LIGHT"
  | "IMITATION"
  | "QUIZ"
  | "DRAWING";
export interface AdminPkDare {
  id: string;
  seqNo: number;
  code: string;
  textAr: string;
  textEn: string;
  category: PkDareCategory;
  level: PkDareLevel;
  requiresCamera: boolean;
  active: boolean;
  disabledReason: "ADMIN" | "REPORTS" | null;
  reportCount: number;
  reportsClearedAt: string | null;
  createdBy: "SEED" | "ADMIN";
  createdAt: string;
  updatedAt: string;
}
export interface AdminPkDareStats {
  total: number;
  active: number;
  disabled: number;
  reported: number;
  byLevel: Record<string, number>;
  byCategory: Record<string, number>;
}
/** v1.71-live (D281) `AdminHostTargetSettings`. */
export interface AdminHostTargetSettings {
  easyPercentile: number;
  mediumPercentile: number;
  hardPercentile: number;
  easyRewardBps: number;
  mediumRewardBps: number;
  hardRewardBps: number;
  noRepeatDays: number;
  taskNoRepeatDays: number;
  historyDays: number;
  completionShift: number;
  /** D281b: the new-host defaults per kind, per band 1…4: [easy, medium, hard]. */
  newHostDefaults: Record<string, number[][]>;
  engineFrom: string | null;
  updatedAt: string;
  updatedById: string | null;
}
/** v1.71-live (D281) `AdminTargetCatalogue`. */
export interface AdminTargetCatalogue {
  targets: {
    version: string;
    total: number;
    windows: number;
    gifts: number;
    /** D281b. */
    luckyGifts: number;
    categories: number;
    byKind: Record<string, number>;
    byTrack: Record<string, number>;
  };
  tasks: {
    total: number;
    templates: number;
    byTemplate: Record<string, number>;
  };
}
/** v1.71-live (D281) `AdminHostTarget`. */
export interface AdminHostTarget {
  /** D281b: «الهدايا» or «هدايا الحظ». */
  track: "GIFTS" | "LUCKY";
  level: "EASY" | "MEDIUM" | "HARD";
  code: string;
  kind: string;
  subject: string | null;
  titleAr: string;
  titleEn: string;
  amount: number;
  progress: number;
  window: { from: string; to: string } | null;
  expectedCoins: number;
  rewardBps: number;
  rewardCherries: number;
  paidCherries: number | null;
  paidAt: string | null;
  profitUsd: number | null;
  catalogueVersion: string;
  reason: {
    newHost?: boolean;
    why?: string;
    whyAr?: string;
    [key: string]: unknown;
  };
}
/** v1.71-live (D281) `AdminHostTargetDay`. */
export interface AdminHostTargetDay {
  host: { id: string; username: string; displayName: string };
  day: string;
  targets: AdminHostTarget[];
}
export interface AdminPkDareSettings {
  winPoints: number;
  drawPoints: number;
  lossPoints: number;
  refusePoints: number;
  /** D276: a host who withdrew from the battle (−3 by default). */
  forfeitPoints: number;
  decideSeconds: number;
  reportsToDisable: number;
  updatedAt: string;
  updatedById: string | null;
}
export interface AdminPkDareImportResult {
  received: number;
  inserted: number;
  existing: number;
  rejected: { line: number; code: string | null; issues: string[] }[];
}

// ---- v1.110-social (D345, CONVENTIONS §10.144): «مشتريات المتجر» ------------------------------------------------------

export type IapPlatform = "GOOGLE_PLAY" | "APP_STORE";

/** `AdminStoreIapOverview`. */
export interface StoreIapOverview {
  googlePlay: {
    configured: boolean;
    packageName: string | null;
    rtdnEnabled: boolean;
  };
  appStore: { configured: boolean; bundleId: string | null; roots: number };
  acceptSandbox: boolean;
  voidedPollHours: number;
  consentVersion: string;
  endpoints: { appleNotifications: string; googleRtdn: string };
  settings: { oncePerAccountDevice: boolean; updatedAt: string };
  voided: {
    lastRunAt: string | null;
    polledUntil: string | null;
    lastError: string | null;
  };
  counts: { purchases: number; refunds: number; activeBans: number };
}

/** `AdminStoreIapProduct`. */
export interface StoreIapProduct {
  id: string;
  platform: IapPlatform;
  productId: string;
  coins: number;
  referenceUsdCents: number | null;
  sortOrder: number;
  enabled: boolean;
  updatedAt: string;
}

export interface StoreIapPerson {
  id: string;
  username: string;
  displayName: string;
}

/** `AdminStoreIapPurchaseRow`. */
export interface StoreIapPurchaseRow {
  id: string;
  user: StoreIapPerson;
  platform: IapPlatform;
  productId: string;
  coins: number;
  transactionId: string;
  environment: "PRODUCTION" | "SANDBOX";
  status: "CREDITED" | "REJECTED" | "REFUNDED";
  rejectReason: string | null;
  deviceRecorded: boolean;
  consentVersion: string;
  consentShareData: boolean;
  purchasedAt: string;
  creditedAt: string | null;
  consumedAt: string | null;
  refundedAt: string | null;
  refundSource: string | null;
  refundReason: string | null;
  refundBanId: string | null;
  createdAt: string;
}

/** `AdminStoreIapRefundBanRow`. */
export interface StoreIapRefundBanRow {
  id: string;
  user: StoreIapPerson;
  accountStatus: string;
  purchaseId: string;
  platform: IapPlatform;
  productId: string;
  coins: number;
  transactionId: string;
  refundedAt: string | null;
  reason: string;
  accountBanned: boolean;
  deviceBanned: boolean;
  devicesBanned: number;
  accountLiftedAt: string | null;
  accountLiftReason: string | null;
  deviceLiftedAt: string | null;
  deviceLiftReason: string | null;
  createdAt: string;
}

// ---- v1.116-social (D355, CONVENTIONS §10.151): «واتساب» ------------------------------------------------------------
export interface WaStaffRef {
  userId: string;
  displayName: string | null;
  staffId: string | null;
}
export interface WaAccountCard {
  userId: string;
  username: string;
  displayName: string;
  avatarUrl: string | null;
  status: string;
  countryCode: string | null;
  createdAt: string;
}
export interface WaSummary {
  enabled: boolean;
  /** v1.137-social (D385, §10.174.6): the in-app «دعم كابسو» threads are served (also with WhatsApp off). */
  inApp?: boolean;
  badge: number;
  mine: number;
  unassigned: number;
  unreadMessages: number;
}
export interface WaConversation {
  id: string;
  /** v1.137-social (D385): null for an in-app thread. */
  phone: string | null;
  name: string | null;
  status: "OPEN" | "CLOSED";
  assignedTo: WaStaffRef | null;
  assignedToMe: boolean;
  unreadCount: number;
  lastMessageAt: string;
  lastPreview: string | null;
  lastDirection: "INBOUND" | "OUTBOUND" | null;
  window: { open: boolean; closesAt: string | null };
  linkedAccount: WaAccountCard | null;
  closedAt: string | null;
  createdAt: string;
  /** D366 (§10.159): the department (absent from an older API: GENERAL). */
  department?: WaDepartment;
  /** v1.134-social (D381, §10.171.3): a PRIORITY_SUPPORT holder's conversation (listed first by the API). */
  priority?: boolean;
  /** v1.137-social (D385, §10.174.6): WHATSAPP, or IN_APP «دعم كابسو» «داخل التطبيق» (absent from an older API). */
  channel?: "WHATSAPP" | "IN_APP";
}
/** D366 (v1.123-social, §10.159): the WhatsApp departments, catalogue order. */
export type WaDepartment =
  | "PAYMENTS"
  | "AGENCIES"
  | "TECHNICAL"
  | "REPORTS"
  | "GENERAL";
export const WA_DEPARTMENTS: WaDepartment[] = [
  "PAYMENTS",
  "AGENCIES",
  "TECHNICAL",
  "REPORTS",
  "GENERAL",
];
export interface WaMessage {
  id: string;
  direction: "INBOUND" | "OUTBOUND";
  type: string;
  text: string | null;
  media: {
    state: "STORED" | "TOO_LARGE" | "TYPE_REFUSED" | "FAILED";
    mime: string | null;
    size: number | null;
    filename: string | null;
    voice: boolean;
  } | null;
  location: { latitude: number; longitude: number; name: string | null } | null;
  reaction: string | null;
  template: { name: string; language: string } | null;
  status: "RECEIVED" | "SENT" | "DELIVERED" | "READ" | "FAILED";
  error: { code: number | null; title: string | null } | null;
  sentBy: WaStaffRef | null;
  at: string;
  statusAt: string | null;
}
export interface WaNote {
  id: string;
  body: string;
  author: WaStaffRef | null;
  at: string;
}
export interface WaAssignment {
  id: string;
  action: "CLAIM" | "RELEASE" | "TRANSFER" | "CLOSE" | "REOPEN";
  from: WaStaffRef | null;
  to: WaStaffRef | null;
  by: WaStaffRef | null;
  at: string;
  /** D366: a TRANSFER's departments and its internal note (absent from an older API). */
  department?: WaDepartment | null;
  fromDepartment?: WaDepartment | null;
  note?: { id: string; body: string } | null;
}
export interface WaTemplate {
  name: string;
  language: string;
  category: string | null;
  body: string | null;
  parameterCount: number;
}
export interface WaQuickReply {
  id: string;
  title: string;
  body: string;
  updatedAt: string;
}
export interface WaAgent extends WaStaffRef {
  onShift: boolean;
  /** D366: the agent's departments and open assigned conversations (absent from an older API). */
  departments?: WaDepartment[];
  openCount?: number;
}
export interface WaStatus {
  enabled: boolean;
  phoneNumberId: string | null;
  businessAccountId: string | null;
  displayName: string | null;
  graphApiVersion: string;
  webhookUrl: string;
  subscribedFields: string[];
  retentionDays: number;
  mediaMaxBytes: number;
  lastInboundAt: string | null;
  conversations: number;
  missing: string[];
}
export interface WaTestResult {
  ok: boolean;
  displayPhoneNumber: string | null;
  verifiedName: string | null;
  qualityRating: string | null;
  templates: number | null;
  error: { status: number; code: number | null; title: string | null } | null;
}
