import { useCallback, useEffect, useMemo, useState } from 'react';
import { api, ApiError, setCsrfToken, setUnauthenticatedHandler } from './api';
import { ErrorAlert } from './components';
import { AppContext, readPref, writePref, type AppState } from './context';
import { translate, type Key, type Lang } from './i18n';
import { Agents } from './pages/Agents';
import { ApplicationDetail, Applications } from './pages/Applications';
import { Dashboard } from './pages/Dashboard';
import { Login } from './pages/Login';
import { Reports } from './pages/Reports';
import { Payments } from './pages/Payments';
import { SiteSettings } from './pages/SiteSettings';
import { UserDetail } from './pages/UserDetail';
import { Withdrawals } from './pages/Withdrawals';
import { Users } from './pages/Users';
import { matchPath, navigate, useLocation } from './router';
import type { AdminSessionInfo, Capability } from './types';

type Theme = 'light' | 'dark';

const NAV: { to: string; key: Key; cap: Capability; match: string[] }[] = [
  { to: '/', key: 'navDashboard', cap: 'dashboard.view', match: ['dashboard'] },
  { to: '/users', key: 'navUsers', cap: 'users.view', match: ['users', 'user'] },
  { to: '/recharge/applications', key: 'navApplications', cap: 'recharge.applications', match: ['applications', 'application'] },
  { to: '/recharge/agents', key: 'navAgents', cap: 'recharge.agents', match: ['agents'] },
  { to: '/withdrawals', key: 'navWithdrawals', cap: 'withdrawals.view', match: ['withdrawals'] },
  { to: '/reports', key: 'navReports', cap: 'reports.view', match: ['reports'] },
  { to: '/site-settings', key: 'navSite', cap: 'site.settings', match: ['site'] },
  { to: '/payments', key: 'navPayments', cap: 'payments.settings', match: ['payments'] },
];

const CAP_OF_ROUTE: Record<string, Capability> = Object.fromEntries(NAV.flatMap((n) => n.match.map((m) => [m, n.cap])));

function initialTheme(): Theme {
  const saved = readPref('kabso-admin-theme');
  if (saved === 'light' || saved === 'dark') return saved;
  return window.matchMedia?.('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
}

export function App() {
  const [lang, setLang] = useState<Lang>(() => (readPref('kabso-admin-lang') === 'en' ? 'en' : 'ar'));
  const [theme, setTheme] = useState<Theme>(initialTheme);
  const [session, setSession] = useState<AdminSessionInfo | null>(null);
  const [checking, setChecking] = useState(true);
  const [bootError, setBootError] = useState<unknown>(null);
  const [toastText, setToastText] = useState<string | null>(null);
  const [menuOpen, setMenuOpen] = useState(false);
  const loc = useLocation();

  useEffect(() => {
    const root = document.documentElement;
    root.lang = lang;
    root.dir = lang === 'ar' ? 'rtl' : 'ltr';
    root.dataset.theme = theme;
    document.title = translate(lang, 'appName');
  }, [lang, theme]);

  const signedOut = useCallback(() => {
    setCsrfToken(null);
    setSession(null);
  }, []);

  useEffect(() => {
    setUnauthenticatedHandler(signedOut);
    api
      .get<AdminSessionInfo>('/admin/auth/session')
      .then(
        (s) => {
          setCsrfToken(s.csrfToken);
          setSession(s);
        },
        (e: unknown) => {
          if (!(e instanceof ApiError && e.status === 401)) setBootError(e);
        },
      )
      .finally(() => setChecking(false));
    return () => setUnauthenticatedHandler(null);
  }, [signedOut]);

  useEffect(() => {
    if (!toastText) return;
    const id = window.setTimeout(() => setToastText(null), 2600);
    return () => window.clearTimeout(id);
  }, [toastText]);

  useEffect(() => setMenuOpen(false), [loc.path]);

  const state: AppState = useMemo(
    () => ({
      lang,
      t: (key, vars) => translate(lang, key, vars),
      session,
      can: (cap) => session?.capabilities.includes(cap) ?? false,
      toast: setToastText,
    }),
    [lang, session],
  );
  const t = state.t;

  const tools = (
    <>
      <button className="btn small ghost" onClick={() => setLang((l) => (writePref('kabso-admin-lang', l === 'ar' ? 'en' : 'ar'), l === 'ar' ? 'en' : 'ar'))}>
        {t('language')}
      </button>
      <button
        className="btn small ghost"
        onClick={() => setTheme((th) => (writePref('kabso-admin-theme', th === 'dark' ? 'light' : 'dark'), th === 'dark' ? 'light' : 'dark'))}
      >
        {theme === 'dark' ? t('themeLight') : t('themeDark')}
      </button>
    </>
  );

  let body: React.ReactNode;
  if (checking) {
    body = <main className="center"><p className="muted">{t('loading')}</p></main>;
  } else if (!session) {
    body = (
      <>
        {bootError ? <div className="main"><ErrorAlert error={bootError} /></div> : null}
        <Login
          onSignedIn={(s) => {
            setSession(s);
            navigate(loc.path === '/' || loc.path === '' ? '/' : loc.path + window.location.search);
          }}
          tools={tools}
        />
      </>
    );
  } else {
    const match = matchPath(loc.path);
    const cap = match ? CAP_OF_ROUTE[match.name] : undefined;
    let page: React.ReactNode;
    if (!match) page = <p className="muted">{t('errNotFound')}</p>;
    else if (cap && !state.can(cap)) page = <div className="alert error">{t('errForbidden')}</div>;
    else {
      switch (match.name) {
        case 'dashboard':
          page = <Dashboard />;
          break;
        case 'users':
          page = <Users />;
          break;
        case 'user':
          page = <UserDetail id={match.params.id!} />;
          break;
        case 'applications':
          page = <Applications />;
          break;
        case 'application':
          page = <ApplicationDetail id={match.params.id!} />;
          break;
        case 'agents':
          page = <Agents />;
          break;
        case 'withdrawals':
          page = <Withdrawals />;
          break;
        case 'reports':
          page = <Reports />;
          break;
        case 'site':
          page = <SiteSettings />;
          break;
        case 'payments':
          page = <Payments />;
          break;
      }
    }
    const current = match?.name ?? '';
    body = (
      <div className="shell">
        <aside className={`side${menuOpen ? ' open' : ''}`} aria-label={t('appName')}>
          <div className="brand">
            <span className="brand-mark" aria-hidden="true">
              K
            </span>
            {t('appName')}
          </div>
          <nav className="nav">
            {NAV.filter((n) => state.can(n.cap)).map((n) => (
              <a
                key={n.to}
                href={n.to}
                aria-current={n.match.includes(current) ? 'page' : undefined}
                onClick={(e) => {
                  e.preventDefault();
                  navigate(n.to);
                }}
              >
                {t(n.key)}
              </a>
            ))}
          </nav>
          <div className="side-foot">
            <div className="who">
              <div style={{ fontWeight: 600 }}>{session.admin.displayName}</div>
              <div className="ltr muted small">{session.admin.email}</div>
              <div className="row" style={{ marginTop: 6 }}>
                {session.roles.map((r) => (
                  <span key={r} className="badge info">
                    {t(`role${r}`)}
                  </span>
                ))}
              </div>
            </div>
            <div className="row">{tools}</div>
            <button
              className="btn"
              onClick={() => {
                void api.post('/admin/auth/logout').finally(signedOut);
              }}
            >
              {t('logout')}
            </button>
          </div>
        </aside>
        <div>
          <div className="topbar">
            <button className="btn small" aria-label="menu" aria-expanded={menuOpen} onClick={() => setMenuOpen((o) => !o)}>
              ☰
            </button>
            <strong>{t('appName')}</strong>
            <span />
          </div>
          <main className="main">{page}</main>
        </div>
        {menuOpen && <div className="scrim" style={{ zIndex: 35 }} onClick={() => setMenuOpen(false)} />}
      </div>
    );
  }

  return (
    <AppContext.Provider value={state}>
      {body}
      {toastText && (
        <div className="toast" role="status">
          {toastText}
        </div>
      )}
    </AppContext.Provider>
  );
}
