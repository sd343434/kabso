import { useEffect, useRef, useState, type ReactNode } from 'react';
import { api } from '../api';
import kabsoLogo from '../assets/kabso_logo.webp';
import { Avatar } from '../components';
import { useApp } from '../context';
import { formatNumber } from '../format';
import type { Key } from '../i18n';
import { visibleNav } from '../nav';
import { navigate } from '../router';
import type { Attention, AttentionKind, SearchResult } from '../types';
import { Icon } from './icons';
import { useLiveReportsSummary } from '../pages/LiveModeration';
import { badgeText, useOpenReports } from '../pages/Reports';
import { useWhatsAppBadge } from '../pages/WhatsApp';

/** v1.78-live (D288): the number on «البلاغات» — the unresolved reports (hidden at 0, «99+» above 99). */
export function NavCount({ count, label = 'navReportsOpen' }: { count: number | null; label?: Key }) {
  const { t } = useApp();
  const text = badgeText(count ?? 0);
  if (text === null) return null;
  return (
    <span className="nav-count" data-nav-count={count ?? 0} aria-label={t(label, { count: count ?? 0 })}>
      {text}
    </span>
  );
}

/** v1.60-live (D250): the sidebar's red dots — «البث الآن» while reported lives are on air. */
export function navDots(reported: { rooms: number } | null): Record<string, number> {
  return { '/lives': reported?.rooms ?? 0 };
}

/** Where each pending queue opens. */
export const ATTENTION_LINK: Record<AttentionKind, { to: string; key: Key }> = {
  RECHARGE_APPLICATIONS: { to: '/recharge/applications', key: 'attnApplications' },
  WITHDRAWALS: { to: '/withdrawals', key: 'attnWithdrawals' },
  REPORTS: { to: '/reports', key: 'attnReports' },
  AGENCY_COMPLAINTS: { to: '/agency-complaints', key: 'attnComplaints' },
  TOPUP_CASES: { to: '/finance/cards', key: 'attnCases' },
};

function useOutside(ref: React.RefObject<HTMLElement | null>, open: boolean, close: () => void) {
  useEffect(() => {
    if (!open) return;
    const on = (e: MouseEvent) => {
      if (ref.current && !ref.current.contains(e.target as Node)) close();
    };
    const key = (e: KeyboardEvent) => e.key === 'Escape' && close();
    window.addEventListener('mousedown', on);
    window.addEventListener('keydown', key);
    return () => {
      window.removeEventListener('mousedown', on);
      window.removeEventListener('keydown', key);
    };
  }, [open, close, ref]);
}

/** The top bar's quick search: users, recharge agents (coin…) and agencies (host…), as the admin may see them. */
function QuickSearch() {
  const { t } = useApp();
  const [text, setText] = useState('');
  const [result, setResult] = useState<SearchResult | null>(null);
  const [open, setOpen] = useState(false);
  const box = useRef<HTMLDivElement>(null);
  useOutside(box, open, () => setOpen(false));
  useEffect(() => {
    const q = text.trim();
    if (q.length < 2) {
      setResult(null);
      return;
    }
    let live = true;
    const h = window.setTimeout(() => {
      api.get<SearchResult>('/admin/search', { q }).then(
        (r) => live && setResult(r),
        () => live && setResult({ users: [], agents: [], agencies: [] }),
      );
    }, 250);
    return () => {
      live = false;
      window.clearTimeout(h);
    };
  }, [text]);
  const go = (to: string) => {
    setOpen(false);
    setText('');
    navigate(to);
  };
  const empty = result && result.users.length + result.agents.length + result.agencies.length === 0;
  return (
    <div className="quick-search" ref={box}>
      <label className="search-field big">
        <Icon name="search" size={18} />
        <input
          type="search"
          placeholder={t('searchPlaceholder')}
          aria-label={t('searchPlaceholder')}
          value={text}
          onFocus={() => setOpen(true)}
          onChange={(e) => {
            setText(e.target.value);
            setOpen(true);
          }}
        />
      </label>
      {open && result && (
        <div className="menu search-menu" role="listbox">
          {empty && <p className="muted small pad">{t('empty')}</p>}
          {result.users.length > 0 && <div className="menu-title">{t('searchUsers')}</div>}
          {result.users.map((u) => (
            <button key={u.id} className="menu-row" onClick={() => go(`/users/${u.id}`)}>
              <Avatar url={u.avatarUrl} name={u.displayName || u.username} />
              <span className="names">
                <span>{u.displayName}</span>
                <span className="ltr muted small">@{u.username}</span>
              </span>
            </button>
          ))}
          {result.agents.length > 0 && <div className="menu-title">{t('searchAgents')}</div>}
          {result.agents.map((a) => (
            <button key={a.userId} className="menu-row" onClick={() => go(`/users/${a.userId}`)}>
              <Icon name="coins" />
              <span className="names">
                <span className="mono">{a.code}</span>
                <span className="ltr muted small">@{a.username}</span>
              </span>
            </button>
          ))}
          {result.agencies.length > 0 && <div className="menu-title">{t('searchAgencies')}</div>}
          {result.agencies.map((a) => (
            <button key={a.id} className="menu-row" onClick={() => go(`/agencies/${a.id}`)}>
              <Icon name="agency" />
              <span className="names">
                <span className="mono">{a.hostCode ?? a.inviteCode}</span>
                <span className="ltr muted small">@{a.ownerUsername}</span>
              </span>
            </button>
          ))}
        </div>
      )}
    </div>
  );
}

/** The bell: the pending queues (refreshed every minute and on each page change). */
function Bell({ path }: { path: string }) {
  const { t, lang } = useApp();
  const [data, setData] = useState<Attention | null>(null);
  const [open, setOpen] = useState(false);
  const box = useRef<HTMLDivElement>(null);
  useOutside(box, open, () => setOpen(false));
  useEffect(() => {
    let live = true;
    const load = () =>
      api.get<Attention>('/admin/stats/attention').then(
        (d) => live && setData(d),
        () => undefined,
      );
    void load();
    const h = window.setInterval(load, 60_000);
    return () => {
      live = false;
      window.clearInterval(h);
    };
  }, [path]);
  const total = data?.total ?? 0;
  return (
    <div className="bell" ref={box}>
      <button
        type="button"
        className="icon-btn"
        aria-label={t('notifications', { count: total })}
        aria-expanded={open}
        onClick={() => setOpen((o) => !o)}
      >
        <Icon name="bell" />
        {total > 0 && <span className="count">{total > 99 ? '99+' : total}</span>}
      </button>
      {open && (
        <div className="menu bell-menu">
          <div className="menu-title">{t('attnTitle')}</div>
          {data?.items.map((i) => (
            <button
              key={i.kind}
              className="menu-row"
              disabled={i.count === 0}
              onClick={() => {
                setOpen(false);
                navigate(ATTENTION_LINK[i.kind].to);
              }}
            >
              <span className="names">
                <span>{t(ATTENTION_LINK[i.kind].key)}</span>
              </span>
              <span className={`pill ${i.count > 0 ? 'hot' : ''}`}>{formatNumber(i.count, lang)}</span>
            </button>
          ))}
          {data && data.items.length === 0 && <p className="muted small pad">{t('attnNone')}</p>}
        </div>
      )}
    </div>
  );
}

function AdminMenu({ onLogout, tools }: { onLogout: () => void; tools: ReactNode }) {
  const { t, session } = useApp();
  const [open, setOpen] = useState(false);
  const box = useRef<HTMLDivElement>(null);
  useOutside(box, open, () => setOpen(false));
  if (!session) return null;
  return (
    <div className="admin-menu" ref={box}>
      <button type="button" className="me-btn" aria-expanded={open} onClick={() => setOpen((o) => !o)}>
        <Avatar url={null} name={session.admin.displayName || session.admin.username} />
        <span className="names hide-sm">
          <span>{session.admin.displayName}</span>
          <span className="muted small">{session.roles.map((r) => t(`role${r}`)).join(' · ')}</span>
        </span>
        <Icon name="chevronDown" size={16} />
      </button>
      {open && (
        <div className="menu me-menu">
          <div className="pad">
            <div style={{ fontWeight: 600 }}>{session.admin.displayName}</div>
            <div className="ltr muted small">{session.admin.email}</div>
          </div>
          <div className="menu-tools">{tools}</div>
          <button className="menu-row danger" onClick={onLogout}>
            <Icon name="logout" />
            <span>{t('logout')}</span>
          </button>
        </div>
      )}
    </div>
  );
}

/**
 * The signed-in frame (D197): a rounded Kabso-red sidebar with icon navigation in groups (each item only when the
 * role can use it), and a top bar with the quick search, the bell and the admin menu. Below 1024px the sidebar is a
 * drawer.
 */
export function Shell({
  current,
  path,
  children,
  tools,
  onLogout,
}: {
  current: string;
  path: string;
  children: ReactNode;
  tools: ReactNode;
  onLogout: () => void;
}) {
  const { t, can } = useApp();
  const [menuOpen, setMenuOpen] = useState(false);
  useEffect(() => setMenuOpen(false), [path]);
  const groups = visibleNav(can);
  // v1.60-live (D250): a red dot on «البث الآن» while a live on air has open reports.
  const reported = useLiveReportsSummary(can('lives.reports'));
  const dots = navDots(reported);
  // v1.78-live (D288): the unresolved reports on «البلاغات».
  const openReports = useOpenReports(can('reports.view'), path);
  // v1.116-social (D355): the WhatsApp conversations waiting for the caller (theirs and the unassigned ones).
  const waiting = useWhatsAppBadge(can('support.whatsapp'), path);
  return (
    <div className="shell">
      <aside className={`side${menuOpen ? ' open' : ''}`} aria-label={t('appName')}>
        <div className="brand">
          <img className="brand-logo" src={kabsoLogo} alt="" width={127} height={160} decoding="async" />
          <span className="brand-text">
            <span className="wordmark ltr">
              Kabso <b>Live</b>
            </span>
            <span className="brand-sub">{t('appShort')}</span>
          </span>
          <button type="button" className="icon-btn on-side show-sm" aria-label={t('close')} onClick={() => setMenuOpen(false)}>
            <Icon name="close" />
          </button>
        </div>
        <nav className="nav">
          {groups.map((g) => (
            <div className="nav-group" key={g.key}>
              <div className="nav-title">{t(g.key)}</div>
              {g.items.map((n) => (
                <a
                  key={n.to}
                  href={n.to}
                  aria-current={n.match.includes(current) ? 'page' : undefined}
                  onClick={(e) => {
                    e.preventDefault();
                    setMenuOpen(false);
                    navigate(n.to);
                  }}
                >
                  <Icon name={n.icon} />
                  <span>{t(n.key)}</span>
                  {n.to === '/reports' && <NavCount count={openReports} />}
                  {n.to === '/whatsapp' && <NavCount count={waiting} label="navWhatsAppUnread" />}
                  {(dots[n.to] ?? 0) > 0 && (
                    <span className="nav-dot" data-nav-dot={dots[n.to]} aria-label={t('liveReported')}>
                      <span className="red-dot" aria-hidden="true" />
                    </span>
                  )}
                </a>
              ))}
            </div>
          ))}
        </nav>
      </aside>
      <div className="main-col">
        <header className="topbar">
          <button type="button" className="icon-btn show-sm" aria-label={t('menu')} aria-expanded={menuOpen} onClick={() => setMenuOpen(true)}>
            <Icon name="menu" />
          </button>
          {can('users.view') && <QuickSearch />}
          <span className="spacer" />
          <Bell path={path} />
          <AdminMenu onLogout={onLogout} tools={tools} />
        </header>
        <main className="main">{children}</main>
      </div>
      {menuOpen && <div className="scrim side-scrim" onClick={() => setMenuOpen(false)} />}
    </div>
  );
}
