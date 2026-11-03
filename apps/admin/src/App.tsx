import { useCallback, useEffect, useMemo, useState } from 'react';
import { api, ApiError, setCsrfToken, setUnauthenticatedHandler } from './api';
import { ErrorAlert } from './components';
import { Levels, SpecialUsernames, Tasks, Waitlist } from './pages/Programs';
import { Team } from './pages/Team';
import { Cards, Report, AgentTopups } from './pages/Finance';
import { Gifts, Items, Promo } from './pages/Catalog';
import { GiftCategories } from './pages/GiftCategories';
import { LiveBoostPrices } from './pages/LiveBoostPrices';
import { Vip } from './pages/Vip';
import { Hosts, Lives } from './pages/Lives';
import { DeviceBans } from './pages/LiveModeration';
import { LiveWatch } from './pages/LiveWatch';
import { HostApplicationDetail, HostApplications } from './pages/HostApplications';
import { PkDares } from './pages/PkDares';
import { ReferralDetail, Referrals, ReferralSettingsPage } from './pages/Referrals';
import { AgencyDetail, Agencies, Complaints } from './pages/Agencies';
import { CAP_OF_ROUTE } from './nav';
import { Audit } from './pages/Audit';
import { Shell } from './ui/Shell';
import { Icon } from './ui/icons';
import { AppContext, readPref, writePref, type AppState } from './context';
import { translate, type Lang } from './i18n';
import { Agents } from './pages/Agents';
import { ApplicationDetail, Applications } from './pages/Applications';
import { Dashboard } from './pages/Dashboard';
import { DisputeDetail, Disputes } from './pages/Disputes';
import { Rates } from './pages/Rates';
import { Login } from './pages/Login';
import { Reports } from './pages/Reports';
import { Payments } from './pages/Payments';
import { Storage } from './pages/Storage';
import { KycSettingsPage } from './pages/Kyc';
import { SiteSettings } from './pages/SiteSettings';
import { UserDetail } from './pages/UserDetail';
import { Withdrawals } from './pages/Withdrawals';
import { Users } from './pages/Users';
import { matchPath, navigate, useLocation } from './router';
import type { AdminSessionInfo } from './types';

type Theme = 'light' | 'dark';

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
        <Icon name="globe" size={16} />
        {t('language')}
      </button>
      <button
        className="btn small ghost"
        onClick={() => setTheme((th) => (writePref('kabso-admin-theme', th === 'dark' ? 'light' : 'dark'), th === 'dark' ? 'light' : 'dark'))}
      >
        <Icon name={theme === 'dark' ? 'sun' : 'moon'} size={16} />
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
        case 'storage':
          page = <Storage />;
          break;
        case 'kycSettings':
          page = <KycSettingsPage />;
          break;
        case 'agencies':
          page = <Agencies />;
          break;
        case 'agency':
          page = <AgencyDetail id={match.params.id!} />;
          break;
        case 'complaints':
          page = <Complaints />;
          break;
        case 'lives':
          page = <Lives />;
          break;
        // v1.60-live (D250): the watch view and the device bans.
        case 'liveWatch':
          page = <LiveWatch id={match.params.id!} />;
          break;
        case 'deviceBans':
          page = <DeviceBans />;
          break;
        case 'hosts':
          page = <Hosts />;
          break;
        case 'hostApplications':
          page = <HostApplications />;
          break;
        case 'hostApplication':
          page = <HostApplicationDetail id={match.params.id!} />;
          break;
        case 'referrals':
          page = <Referrals />;
          break;
        case 'referral':
          page = <ReferralDetail id={match.params.id!} />;
          break;
        case 'referralSettings':
          page = <ReferralSettingsPage />;
          break;
        case 'pkDares':
          page = <PkDares />;
          break;
        case 'gifts':
          page = <Gifts />;
          break;
        case 'giftCategories':
          page = <GiftCategories />;
          break;
        case 'items':
          page = <Items />;
          break;
        case 'promo':
          page = <Promo />;
          break;
        case 'boostPrices':
          page = <LiveBoostPrices />;
          break;
        case 'vip':
          page = <Vip />;
          break;
        case 'report':
          page = <Report />;
          break;
        case 'topups':
          page = <AgentTopups />;
          break;
        case 'cards':
          page = <Cards />;
          break;
        case 'team':
          page = <Team />;
          break;
        case 'specialUsernames':
          page = <SpecialUsernames />;
          break;
        case 'tasks':
          page = <Tasks />;
          break;
        case 'levels':
          page = <Levels />;
          break;
        case 'waitlist':
          page = <Waitlist />;
          break;
        case 'audit':
          page = <Audit />;
          break;
        case 'disputes':
          page = <Disputes />;
          break;
        case 'dispute':
          page = <DisputeDetail id={match.params.id!} />;
          break;
        case 'rates':
          page = <Rates />;
          break;
      }
    }
    body = (
      <Shell
        current={match?.name ?? ''}
        path={loc.path}
        tools={tools}
        onLogout={() => {
          void api.post('/admin/auth/logout').finally(signedOut);
        }}
      >
        {page}
      </Shell>
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
