import { useEffect, useState } from 'react';

/**
 * A tiny router on the History API (no dependency): routes are path patterns with `:params`. Caddy serves
 * index.html for every path of admin.<domain> that is not a file, so deep links work.
 */
export interface Match {
  readonly name: string;
  readonly params: Record<string, string>;
}

export const ROUTES: readonly { name: string; pattern: string }[] = [
  { name: 'dashboard', pattern: '/' },
  { name: 'users', pattern: '/users' },
  { name: 'user', pattern: '/users/:id' },
  { name: 'applications', pattern: '/recharge/applications' },
  { name: 'application', pattern: '/recharge/applications/:id' },
  { name: 'agents', pattern: '/recharge/agents' },
  { name: 'withdrawals', pattern: '/withdrawals' },
  { name: 'reports', pattern: '/reports' },
  { name: 'site', pattern: '/site-settings' },
  { name: 'payments', pattern: '/payments' },
  // v1.75-social (D222): «التخزين (R2 / S3)».
  { name: 'storage', pattern: '/storage' },
  // v1.80-kyc (D227): «التحقق من الهوية (Didit)».
  { name: 'kycSettings', pattern: '/kyc-settings' },
  // v1.65-social (D197): the panel v2 sections.
  { name: 'specialUsernames', pattern: '/special-usernames' },
  { name: 'agencies', pattern: '/agencies' },
  { name: 'agency', pattern: '/agencies/:id' },
  { name: 'complaints', pattern: '/agency-complaints' },
  { name: 'lives', pattern: '/lives' },
  // v1.60-live (D250): the watch view and the device bans.
  { name: 'liveWatch', pattern: '/lives/:id' },
  { name: 'deviceBans', pattern: '/device-bans' },
  { name: 'hosts', pattern: '/live-hosts' },
  // v1.73-social (D209): «طلبات المضيفين».
  { name: 'hostApplications', pattern: '/host-applications' },
  { name: 'hostApplication', pattern: '/host-applications/:id' },
  // v1.74-social (D217): «الدعوات».
  { name: 'referrals', pattern: '/referrals' },
  { name: 'referral', pattern: '/referrals/:id' },
  { name: 'referralSettings', pattern: '/referral-settings' },
  // v1.50-live (D229): «أحكام PK».
  { name: 'pkDares', pattern: '/pk-dares' },
  { name: 'gifts', pattern: '/gifts' },
  { name: 'giftCategories', pattern: '/gift-categories' },
  { name: 'items', pattern: '/items' },
  { name: 'promo', pattern: '/promo' },
  // v1.101-social (D325): «الفعاليات».
  { name: 'events', pattern: '/events' },
  // v1.51-live (D233): «صواريخ الزيارات».
  { name: 'boostPrices', pattern: '/live-boost-prices' },
  // v1.81-live (D291): «الميداليات».
  { name: 'medals', pattern: '/medals' },
  { name: 'report', pattern: '/finance/report' },
  { name: 'topups', pattern: '/finance/topups' },
  { name: 'cards', pattern: '/finance/cards' },
  { name: 'tasks', pattern: '/programs/tasks' },
  { name: 'levels', pattern: '/programs/levels' },
  // v1.71-live (D281): «الأهداف الذكية».
  { name: 'hostTargets', pattern: '/programs/host-targets' },
  // v1.82-social (D252): «VIP».
  { name: 'vip', pattern: '/vip' },
  // D270: «المتجر».
  { name: 'store', pattern: '/store' },
  { name: 'waitlist', pattern: '/waitlist' },
  { name: 'team', pattern: '/team' },
  { name: 'audit', pattern: '/audit' },
  { name: 'disputes', pattern: '/recharge/disputes' },
  { name: 'dispute', pattern: '/recharge/disputes/:id' },
  { name: 'rates', pattern: '/recharge/exchange-rates' },
  // v1.75-live (D285): «استقطاباتي», «الاستقطاب», «طلبات صناع المحتوى».
  { name: 'myRecruits', pattern: '/my-recruits' },
  { name: 'recruits', pattern: '/recruits' },
  { name: 'creatorApplications', pattern: '/creator-applications' },
  // v1.89-social (D290): «طلب رفع ليفيل».
  { name: 'levelRaises', pattern: '/level-raises' },
  { name: 'levelRaise', pattern: '/level-raises/:id' },
  { name: 'levelRaiseApps', pattern: '/level-raise/apps' },
  { name: 'levelRaiseSettings', pattern: '/level-raise/settings' },
  { name: 'verificationBadges', pattern: '/verification-badges' },
  // v1.95-social (D301): «صندوق المؤسس» (OWNER only).
  { name: 'ownerInbox', pattern: '/owner-inbox' },
  // D301 follow-up (§10.112.10): «التكاليف الثابتة» (OWNER only).
  { name: 'ownerFixedCosts', pattern: '/owner-fixed-costs' },
];

export function matchPath(path: string): Match | null {
  const clean = path.replace(/\/+$/, '') || '/';
  for (const r of ROUTES) {
    const want = r.pattern.split('/');
    const got = clean.split('/');
    if (want.length !== got.length) continue;
    const params: Record<string, string> = {};
    let ok = true;
    want.forEach((seg, i) => {
      const value = got[i] ?? '';
      if (seg.startsWith(':')) {
        if (value === '') ok = false;
        else params[seg.slice(1)] = decodeURIComponent(value);
      } else if (seg !== value) ok = false;
    });
    if (ok) return { name: r.name, params };
  }
  return null;
}

export function navigate(to: string): void {
  if (to === window.location.pathname + window.location.search) return;
  window.history.pushState(null, '', to);
  window.dispatchEvent(new PopStateEvent('popstate'));
  window.scrollTo(0, 0);
}

export function useLocation(): { path: string; search: URLSearchParams } {
  const read = () => ({ path: window.location.pathname, search: new URLSearchParams(window.location.search) });
  const [loc, setLoc] = useState(read);
  useEffect(() => {
    const on = () => setLoc(read());
    window.addEventListener('popstate', on);
    return () => window.removeEventListener('popstate', on);
  }, []);
  return loc;
}
