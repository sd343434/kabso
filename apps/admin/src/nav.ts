import type { Key } from './i18n';
import type { IconName } from './ui/icons';
import type { Capability } from './types';

/**
 * The sidebar (D197): grouped sections, each item shown only when the session's capabilities include its own (the
 * server checks every request again). `match` lists the route names that light the item up.
 *
 * Settings also holds D196's «الدفع (Stripe)» page (capability `payments.settings`, OWNER) and D222's «التخزين (R2 / S3)»
 * (`storage.settings`, OWNER).
 */
export interface NavItem {
  to: string;
  key: Key;
  icon: IconName;
  cap: Capability;
  match: string[];
}

export interface NavGroup {
  key: Key;
  items: NavItem[];
}

export const NAV: NavGroup[] = [
  { key: 'navGroupHome', items: [{ to: '/', key: 'navDashboard', icon: 'home', cap: 'dashboard.view', match: ['dashboard'] }] },
  {
    key: 'navGroupUsers',
    items: [
      { to: '/users', key: 'navUsers', icon: 'users', cap: 'users.list', match: ['users', 'user'] },
      { to: '/special-usernames', key: 'navSpecialUsernames', icon: 'at', cap: 'programs.view', match: ['specialUsernames'] },
      // v1.90-social (D293): «شارات التوثيق» — the thresholds (OWNER edits; the team reads).
      { to: '/verification-badges', key: 'navVerificationBadges', icon: 'shield', cap: 'verification.view', match: ['verificationBadges'] },
    ],
  },
  {
    key: 'navGroupAgencies',
    items: [
      { to: '/agencies', key: 'navAgencies', icon: 'agency', cap: 'agencies.view', match: ['agencies', 'agency'] },
      { to: '/agency-complaints', key: 'navComplaints', icon: 'alert', cap: 'agencies.view', match: ['complaints'] },
    ],
  },
  {
    key: 'navGroupLives',
    items: [
      { to: '/lives', key: 'navLives', icon: 'live', cap: 'lives.view', match: ['lives', 'liveWatch'] },
      { to: '/live-hosts', key: 'navHosts', icon: 'key', cap: 'lives.view', match: ['hosts'] },
      // v1.60-live (D250): «الأجهزة المحظورة».
      { to: '/device-bans', key: 'navDeviceBans', icon: 'ban', cap: 'devices.ban', match: ['deviceBans'] },
      // v1.50-live (D229): «أحكام PK».
      { to: '/pk-dares', key: 'navPkDares', icon: 'list', cap: 'pk_dares.view', match: ['pkDares'] },
      // v1.73-social (D209): the applications «كن مضيفاً مع الإدارة».
      { to: '/host-applications', key: 'navHostApplications', icon: 'inbox', cap: 'hosts.applications', match: ['hostApplications', 'hostApplication'] },
    ],
  },
  {
    key: 'navGroupGifts',
    items: [
      { to: '/gifts', key: 'navGifts', icon: 'gift', cap: 'catalog.view', match: ['gifts'] },
      { to: '/gift-categories', key: 'navGiftCategories', icon: 'list', cap: 'catalog.view', match: ['giftCategories'] },
      { to: '/items', key: 'navItems', icon: 'frame', cap: 'catalog.view', match: ['items'] },
      { to: '/promo', key: 'navPromo', icon: 'calendar', cap: 'catalog.view', match: ['promo'] },
      // v1.101-social (D325): «الفعاليات» — every event, the step-by-step editor, drafts and publishing.
      { to: '/events', key: 'navEvents', icon: 'calendar', cap: 'catalog.view', match: ['events'] },
      // v1.51-live (D233): the rocket stages' prices.
      { to: '/live-boost-prices', key: 'navBoostPrices', icon: 'coins', cap: 'catalog.view', match: ['boostPrices'] },
      // v1.81-live (D291): the medals and their levels.
      { to: '/medals', key: 'navMedals', icon: 'shield', cap: 'catalog.view', match: ['medals'] },
    ],
  },
  {
    key: 'navGroupMoney',
    items: [
      { to: '/finance/report', key: 'navReport', icon: 'money', cap: 'finance.view', match: ['report'] },
      { to: '/recharge/applications', key: 'navApplications', icon: 'inbox', cap: 'recharge.applications', match: ['applications', 'application'] },
      { to: '/recharge/agents', key: 'navAgents', icon: 'coins', cap: 'recharge.agents', match: ['agents'] },
      // v1.69-social (D204): «نزاعات الشحن» and «أسعار الصرف».
      { to: '/recharge/disputes', key: 'navDisputes', icon: 'alert', cap: 'recharge.disputes', match: ['disputes', 'dispute'] },
      { to: '/recharge/exchange-rates', key: 'navRates', icon: 'globe', cap: 'recharge.agents', match: ['rates'] },
      // D275: the top-up records are read-only for the moderator «مشرف» (`recharge.topups.view`).
      { to: '/finance/topups', key: 'navAgentTopups', icon: 'list', cap: 'recharge.topups.view', match: ['topups'] },
      { to: '/withdrawals', key: 'navWithdrawals', icon: 'download', cap: 'withdrawals.view', match: ['withdrawals'] },
      { to: '/finance/cards', key: 'navCards', icon: 'shield', cap: 'recharge.topups.view', match: ['cards'] },
      // v1.110-social (D345): «مشتريات المتجر» — Google Play / App Store purchases, refunds and their bans.
      { to: '/store-purchases', key: 'navStoreIap', icon: 'coins', cap: 'store_iap.view', match: ['storeIap'] },
      // v1.74-social (D217): «الدعوات» and their settings.
      { to: '/referrals', key: 'navReferrals', icon: 'users', cap: 'referrals.view', match: ['referrals', 'referral'] },
      { to: '/referral-settings', key: 'navReferralSettings', icon: 'money', cap: 'referrals.view', match: ['referralSettings'] },
    ],
  },
  {
    // v1.75-live (D285): recruitment by staff — «استقطاباتي» (MODERATION, BD), «الاستقطاب» (OWNER), creator applications.
    key: 'navGroupRecruits',
    items: [
      { to: '/my-recruits', key: 'navMyRecruits', icon: 'users', cap: 'recruits.mine', match: ['myRecruits'] },
      { to: '/recruits', key: 'navRecruits', icon: 'agency', cap: 'recruits.view', match: ['recruits'] },
      { to: '/creator-applications', key: 'navCreatorApplications', icon: 'inbox', cap: 'creators.applications', match: ['creatorApplications'] },
    ],
  },
  {
    // v1.89-social (D290): «طلب رفع ليفيل» — the requests (MODERATION, SUPPORT: their own; OWNER: all), the source-app
    // data and the weights (OWNER).
    key: 'navGroupLevelRaise',
    items: [
      { to: '/level-raises', key: 'navLevelRaises', icon: 'arrowUp', cap: 'levels.raise.request', match: ['levelRaises', 'levelRaise'] },
      { to: '/level-raise/apps', key: 'navLevelRaiseApps', icon: 'list', cap: 'levels.raise.decide', match: ['levelRaiseApps'] },
      { to: '/level-raise/settings', key: 'navLevelRaiseSettings', icon: 'money', cap: 'levels.raise.decide', match: ['levelRaiseSettings'] },
    ],
  },
  {
    key: 'navGroupContent',
    items: [
      { to: '/reports', key: 'navReports', icon: 'flag', cap: 'reports.view', match: ['reports'] },
      // v1.116-social (D355): «واتساب» — the official number's inbox, its quick replies and settings.
      { to: '/whatsapp', key: 'navWhatsApp', icon: 'chat', cap: 'support.whatsapp.view', match: ['whatsapp'] },
      { to: '/whatsapp/quick-replies', key: 'navWhatsAppQuickReplies', icon: 'list', cap: 'support.whatsapp.manage', match: ['whatsappQuickReplies'] },
      { to: '/whatsapp/settings', key: 'navWhatsAppSettings', icon: 'settings', cap: 'support.whatsapp.manage', match: ['whatsappSettings'] },
      // v1.95-social (D301): «صندوق المؤسس» — suggestions and confidential staff reports (OWNER only).
      { to: '/owner-inbox', key: 'navOwnerInbox', icon: 'mail', cap: 'owner.inbox', match: ['ownerInbox'] },
      // D301 follow-up (§10.112.10): the fixed monthly costs of «الربح» (OWNER only).
      { to: '/owner-fixed-costs', key: 'navOwnerFixedCosts', icon: 'money', cap: 'owner.costs', match: ['ownerFixedCosts'] },
    ],
  },
  {
    key: 'navGroupPrograms',
    items: [
      { to: '/programs/tasks', key: 'navTasks', icon: 'tasks', cap: 'programs.view', match: ['tasks'] },
      { to: '/programs/levels', key: 'navLevels', icon: 'arrowUp', cap: 'programs.view', match: ['levels'] },
      // v1.71-live (D281): «الأهداف الذكية» (OWNER only).
      { to: '/programs/host-targets', key: 'navHostTargets', icon: 'tasks', cap: 'host_targets.view', match: ['hostTargets'] },
      // v1.82-social (D252): «شراء VIP» — the tiers, their order and perks.
      { to: '/vip', key: 'navVip', icon: 'shield', cap: 'catalog.view', match: ['vip'] },
      // D270: «المتجر» — the store's items, prices and sales.
      { to: '/store', key: 'navStore', icon: 'gift', cap: 'catalog.view', match: ['store'] },
    ],
  },
  {
    key: 'navGroupSettings',
    items: [
      { to: '/site-settings', key: 'navSite', icon: 'globe', cap: 'site.settings', match: ['site'] },
      { to: '/payments', key: 'navPayments', icon: 'money', cap: 'payments.settings', match: ['payments'] },
      // v1.75-social (D222): «التخزين (R2 / S3)».
      { to: '/storage', key: 'navStorage', icon: 'storage', cap: 'storage.settings', match: ['storage'] },
      // v1.80-kyc (D227): «التحقق من الهوية (Didit)».
      { to: '/kyc-settings', key: 'navKyc', icon: 'shield', cap: 'kyc.settings', match: ['kycSettings'] },
      { to: '/waitlist', key: 'navWaitlist', icon: 'mail', cap: 'waitlist.view', match: ['waitlist'] },
      { to: '/team', key: 'navTeam', icon: 'shield', cap: 'team.manage', match: ['team'] },
      { to: '/audit', key: 'navAudit', icon: 'clock', cap: 'audit.view', match: ['audit'] },
    ],
  },
];

/** The capability a route needs (the first nav item that matches it). */
export const CAP_OF_ROUTE: Record<string, Capability> = Object.fromEntries(
  NAV.flatMap((g) => g.items.flatMap((i) => i.match.map((m) => [m, i.cap] as const))),
);

/** The groups and items a session may see (empty groups dropped). */
export function visibleNav(can: (cap: Capability) => boolean): NavGroup[] {
  return NAV.map((g) => ({ ...g, items: g.items.filter((i) => can(i.cap)) })).filter((g) => g.items.length > 0);
}
