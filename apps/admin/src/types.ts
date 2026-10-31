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
  | 'site.settings';

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

export type UserStatus = 'ACTIVE' | 'SUSPENDED' | 'DELETED';

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
