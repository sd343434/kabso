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
      { to: '/lives', key: 'navLives', icon: 'live', cap: 'lives.view', match: ['lives'] },
      { to: '/live-hosts', key: 'navHosts', icon: 'key', cap: 'lives.view', match: ['hosts'] },
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
      { to: '/finance/topups', key: 'navAgentTopups', icon: 'list', cap: 'finance.view', match: ['topups'] },
      { to: '/withdrawals', key: 'navWithdrawals', icon: 'download', cap: 'withdrawals.view', match: ['withdrawals'] },
      { to: '/finance/cards', key: 'navCards', icon: 'shield', cap: 'finance.view', match: ['cards'] },
      // v1.74-social (D217): «الدعوات» and their settings.
      { to: '/referrals', key: 'navReferrals', icon: 'users', cap: 'referrals.view', match: ['referrals', 'referral'] },
      { to: '/referral-settings', key: 'navReferralSettings', icon: 'money', cap: 'referrals.view', match: ['referralSettings'] },
    ],
  },
  { key: 'navGroupContent', items: [{ to: '/reports', key: 'navReports', icon: 'flag', cap: 'reports.view', match: ['reports'] }] },
  {
    key: 'navGroupPrograms',
    items: [
      { to: '/programs/tasks', key: 'navTasks', icon: 'tasks', cap: 'programs.view', match: ['tasks'] },
      { to: '/programs/levels', key: 'navLevels', icon: 'arrowUp', cap: 'programs.view', match: ['levels'] },
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
