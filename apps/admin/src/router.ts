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
