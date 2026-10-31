/** The shapes of openapi.yaml's `admin-panel` schemas the panel reads (contract v1.60-social, D191). */
export type PanelRole = 'OWNER' | 'MODERATION' | 'SUPPORT' | 'FINANCE';

export type Capability =
  | 'dashboard.view'
  | 'users.view'
  | 'users.balances'
  | 'users.ledger'
  | 'users.ban'
  | 'users.avatar'
  | 'users.special_username'
  | 'recharge.applications'
  | 'recharge.decide'
  | 'recharge.agents'
  | 'recharge.topup'
  | 'recharge.status'
  | 'recharge.cap'
  | 'withdrawals.view'
  | 'withdrawals.decide'
  | 'reports.view'
  | 'reports.act'
  | 'site.settings'
  | 'payments.settings'
  // v1.65-social (D197)
  | 'users.list'
  | 'users.export'
  | 'users.sessions'
  | 'agencies.view'
  | 'agencies.manage'
  | 'lives.view'
  | 'lives.manage'
  | 'catalog.view'
  | 'catalog.manage'
  | 'items.grant'
  | 'finance.view'
  | 'finance.refund'
  | 'audit.view'
  | 'team.manage'
  | 'programs.view'
  | 'waitlist.view'
  // v1.72-social (D208)
  | 'users.control_view'
  | 'users.lock'
  | 'users.restrict'
  | 'users.password'
  | 'users.email'
  | 'users.profile_edit'
  | 'users.content'
  | 'users.balance_adjust'
  | 'users.delete';

export interface AdminSessionInfo {
  admin: { id: string; email: string; username: string; displayName: string };
  roles: PanelRole[];
  capabilities: Capability[];
  csrfToken: string;
  expiresAt: string;
  idleSeconds: number;
}

export interface AdminLoginResponse {
  next: 'TOTP_ENROL' | 'TOTP_VERIFY';
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
  today: { newUsers: number; agentCoinsSold: number; agentSales: number; giftsSent: number; giftCoins: number };
  livesNow: number;
  pending: { rechargeApplications: number; withdrawals: number; reports: number };
}

/** v1.62-social (D193): PENDING_DELETION during the deletion grace period (shown by D208's account group). */
export type UserStatus = 'ACTIVE' | 'SUSPENDED' | 'PENDING_DELETION' | 'DELETED';

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
    role: 'USER' | 'ADMIN';
    lastActiveAt: string | null;
    countryCode: string | null;
    bio: string | null;
    baseUsername: string;
  };
  specialUsername: { username: string; source: string; expiresAt: string | null } | null;
  adminRoles: PanelRole[];
  balances: { coins: number; cherries: number; lockedTaskCherries: number } | null;
  ledger: { coins: LedgerRow[]; cherries: LedgerRow[] } | null;
  rechargeAgent: {
    status: string;
    code: string | null;
    stockCoins: number;
    dailyCherryCap: number | null;
    suspendReason: string | null;
  } | null;
  hostAgent: { inviteCode: string; hostCode: string | null; rank: string; suspended: boolean } | null;
  agencyHost: { agencyInviteCode: string; status: string } | null;
  reports: {
    open: number;
    recent: { id: string; reason: string; status: string; targetType: string; createdAt: string }[];
  };
}

export interface UserRef {
  id: string;
  username: string;
  displayName: string;
}

export interface ApplicationRow {
  id: string;
  status: 'PENDING' | 'APPROVED' | 'REJECTED';
  createdAt: string;
  decidedAt: string | null;
  purged: boolean;
  user: UserRef;
}

export interface Application {
  id: string;
  status: 'PENDING' | 'APPROVED' | 'REJECTED';
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
  currency: 'USD';
}

export interface AgentRow {
  userId: string;
  code: string | null;
  status: 'APPROVED' | 'ACTIVE' | 'SUSPENDED';
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
  status: 'PENDING' | 'PAID' | 'REJECTED';
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
  status: 'OPEN' | 'ACTIONED' | 'DISMISSED';
  createdAt: string;
  resolvedAt: string | null;
  reporter?: { id: string; username: string; displayName: string; avatarUrl: string | null };
  dmSnapshot?: { text: string | null; sender: string | null; mediaUrl: string | null };
  linkSnapshot?: { username: string; url: string; label: string | null };
  preview: {
    text: string | null;
    mediaUrl: string | null;
    author: { id: string; username: string; displayName: string; status: string } | null;
    gone: boolean;
  };
}

export interface SiteSettings {
  socials: { instagram: string | null; tiktok: string | null; whatsapp: string | null };
  topupEnabled: boolean;
}

/** v1.64-social (D196): `PaymentKeyInfo` — all the panel ever sees of a Stripe secret. */
export interface PaymentKeyInfo {
  kind: 'secret' | 'restricted' | 'webhook';
  mode: 'live' | 'test' | null;
  last4: string;
  source: 'panel' | 'env';
  setBy: { id: string; displayName: string } | null;
  setAt: string | null;
}

export interface PaymentOptions {
  bankTransferEnabled: boolean | null;
  statementDescriptorSuffix: string | null;
  disputeAutoSubmit: boolean | null;
  appLinkEnabled: boolean | null;
}

/** v1.64-social (D196): `AdminPaymentSettings` «الدفع (Stripe)». */
export interface PaymentSettings {
  source: 'panel' | 'env' | 'none';
  configured: boolean;
  mode: 'live' | 'test' | null;
  secretKey: PaymentKeyInfo | null;
  webhookSecret: PaymentKeyInfo | null;
  previousWebhookSecretValidUntil: string | null;
  panelKeys: { secretKey: PaymentKeyInfo; webhookSecret: PaymentKeyInfo } | null;
  envKeys: { secretKey: PaymentKeyInfo; webhookSecret: PaymentKeyInfo } | null;
  panelKeysIgnored: 'unreadable' | 'test_key_in_production' | null;
  publishableKey: string | null;
  options: PaymentOptions;
  effective: {
    bankTransferEnabled: boolean;
    statementDescriptorSuffix: string | null;
    disputeAutoSubmit: boolean;
    appLinkEnabled: boolean;
  };
  publicBaseUrl: string | null;
  webhookUrl: string | null;
  webhookEvents: string[];
  testKeysAllowed: boolean;
  connectionTestSkippable: boolean;
}

/** `PaymentKeyCheck` («اختبار الاتصال»). */
export interface PaymentKeyCheck {
  ok: true;
  kind: 'secret' | 'restricted' | 'webhook';
  mode: 'live' | 'test' | null;
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

export type AttentionKind = 'RECHARGE_APPLICATIONS' | 'WITHDRAWALS' | 'REPORTS' | 'AGENCY_COMPLAINTS' | 'TOPUP_CASES';

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
  agents: { userId: string; code: string | null; status: string; username: string; displayName: string }[];
  agencies: { id: string; inviteCode: string; hostCode: string | null; rank: string; suspended: boolean; ownerUsername: string; ownerDisplayName: string }[];
}

// ---- v1.72-social (D208, CONVENTIONS §10.67): the account controls -------------------------------------------------
export type RestrictionKind = 'LOCK' | 'CHAT_MUTE' | 'NO_LIVE' | 'NO_GIFTS' | 'NO_POSTING';

export interface Restriction {
  id: string;
  kind: RestrictionKind;
  reason: string;
  startsAt: string;
  endsAt: string;
  via: 'panel' | 'cli';
  active: boolean;
  liftedAt: string | null;
  liftReason: string | null;
  createdAt: string;
}

export interface UserControl {
  status: 'ACTIVE' | 'SUSPENDED' | 'PENDING_DELETION' | 'DELETED';
  lock: Restriction | null;
  restrictions: Restriction[];
  history: Restriction[];
  password: { changeRequired: boolean };
  email: { address: string; verified: boolean };
  gender: 'MALE' | 'FEMALE' | 'UNDISCLOSED' | null;
  cover: null;
  deletion: { requestedAt: string; purgeAfter: string; requestedVia: 'APP' | 'ADMIN' } | null;
  adjustToday: { coins: number; cherries: number; capCoins: number; capCherries: number };
  adjustments: {
    id: string;
    currency: 'COINS' | 'CHERRIES';
    delta: number;
    before: number;
    after: number;
    reason: string;
    actor: string | null;
    createdAt: string;
  }[];
}
