import { api } from '../api';
import { Avatar, ErrorAlert, UserCell, useAsync } from '../components';
import { useApp } from '../context';
import { formatDate, formatNumber } from '../format';
import type { Key } from '../i18n';
import { navigate } from '../router';
import type {
  Capability,
  CommunityHome,
  HomeEvent,
  LiveOpsHome,
  ShiftNow,
  TalentHome,
  TrustSafetyHome,
  VipCareHome,
  VipSupporter,
} from '../types';
import { Icon, type IconName } from '../ui/icons';

/**
 * v1.139-social (D387, CONVENTIONS §10.176.3): the role homes «الرئيسية» — the landing page of a staff member who is
 * not the OWNER. One read per role (`getAdmin<Role>Home`), **no money figure in any of them**: counts, people, levels
 * and times only. The views are pure (rendered in the tests with fixed data); `RoleHomes` loads the ones the session
 * holds, in the order of `HOMES`.
 */

export const HOMES: { cap: Capability; path: string; title: Key }[] = [
  { cap: 'home.trust_safety', path: '/admin/role-homes/trust-safety', title: 'homeTrustSafety' },
  { cap: 'home.vip_care', path: '/admin/role-homes/vip-care', title: 'homeVipCare' },
  { cap: 'home.live_ops', path: '/admin/role-homes/live-ops', title: 'homeLiveOps' },
  { cap: 'home.talent', path: '/admin/role-homes/talent', title: 'homeTalent' },
  { cap: 'home.community', path: '/admin/role-homes/community', title: 'homeCommunity' },
];

/** The role homes the session may see (the OWNER sees the KPI dashboard instead). */
export function homesOf(can: (cap: Capability) => boolean): typeof HOMES {
  return HOMES.filter((h) => can(h.cap));
}

function Stat({ icon, label, value, tone, onOpen }: { icon: IconName; label: string; value: string; tone: string; onOpen?: () => void }) {
  return (
    <div className={`kpi tone-${tone}`} data-home-stat>
      <div className="kpi-top">
        <span className="kpi-icon">
          <Icon name={icon} size={22} />
        </span>
        <span className="kpi-label">{label}</span>
      </div>
      <div className="kpi-value num">{value}</div>
      {onOpen && (
        <div className="kpi-foot">
          <span />
          <button type="button" className="kpi-open" onClick={onOpen} aria-label={label}>
            <Icon name="chevron" size={16} />
          </button>
        </div>
      )}
    </div>
  );
}

function weekdayKey(d: number): Key {
  return `weekday${d}` as Key;
}

export function minuteLabel(m: number): string {
  const h = Math.floor(m / 60) % 24;
  const mm = m % 60;
  return `${String(m === 1440 ? 24 : h).padStart(2, '0')}:${String(mm).padStart(2, '0')}`;
}

/** «في المناوبة الآن» and the next slots (§10.176.6). */
export function ShiftCard({ shift }: { shift: ShiftNow }) {
  const { t, lang } = useApp();
  return (
    <section className="card" data-shift-card>
      <div className="card-head">
        <h2>{t('shiftNow')}</h2>
        <span className="muted small">{t('schedZone', { zone: shift.timeZone })}</span>
      </div>
      <h3 className="small">
        <span className="badge ok" data-on-shift-badge>
          {t('shiftOnNow')}
        </span>
      </h3>
      {shift.onShiftNow.length === 0 ? (
        <p className="muted small">{t('shiftNobody')}</p>
      ) : (
        <ul className="activity">
          {shift.onShiftNow.map((p) => (
            <li key={p.userId}>
              <Avatar url={p.avatarUrl} name={p.displayName} />
              <span className="names">
                <span>
                  <strong>{p.displayName}</strong> {p.staffId && <span className="mono small">{p.staffId}</span>}
                </span>
                <span className="muted small">{p.roles.map((r) => t(`role${r}`)).join(' · ')}</span>
              </span>
            </li>
          ))}
        </ul>
      )}
      {shift.next.length > 0 && (
        <>
          <h3 className="small">{t('shiftNext')}</h3>
          <ul className="activity">
            {shift.next.map((n) => (
              <li key={`${n.person.userId}-${n.startsAt}`}>
                <Avatar url={n.person.avatarUrl} name={n.person.displayName} />
                <span className="names">
                  <span>{n.person.displayName}</span>
                  <span className="muted small">
                    {t(weekdayKey(n.weekday))} {minuteLabel(n.startMinute)}–{minuteLabel(n.endMinute)} ·{' '}
                    <span className="date">{formatDate(n.startsAt, lang)}</span>
                  </span>
                </span>
              </li>
            ))}
          </ul>
        </>
      )}
    </section>
  );
}

function EventsList({ events }: { events: HomeEvent[] }) {
  const { t, lang } = useApp();
  if (events.length === 0) return <p className="muted small">{t('homeNone')}</p>;
  return (
    <ul className="activity">
      {events.map((e) => (
        <li key={e.id}>
          <span className={`badge ${e.running ? 'ok' : 'info'}`}>{t(e.running ? 'homeRunning' : 'homeUpcoming')}</span>
          <span className="names">
            <span>{lang === 'ar' ? e.titleAr : e.titleEn}</span>
            <span className="muted small date">
              {e.startsAt ? formatDate(e.startsAt, lang) : '—'} → {e.endsAt ? formatDate(e.endsAt, lang) : '—'}
            </span>
          </span>
        </li>
      ))}
    </ul>
  );
}

export function LiveOpsHomeView({ data }: { data: LiveOpsHome }) {
  const { t, lang } = useApp();
  const n = (v: number) => formatNumber(v, lang);
  return (
    <div data-home="live-ops">
      <div className="kpis">
        <Stat icon="live" tone="green" label={t('homeLivesNow')} value={n(data.livesNow)} onOpen={() => navigate('/lives')} />
        <Stat icon="flag" tone="red" label={t('homePkNow')} value={n(data.pk.battlesNow)} />
        <Stat icon="calendar" tone="blue" label={t('homePkToday')} value={n(data.pk.battlesToday)} />
      </div>
      <div className="dash-grid">
        <section className="card">
          <h2>{t('homeTopLives')}</h2>
          {data.topLives.length === 0 && <p className="muted small">{t('homeNone')}</p>}
          <ul className="activity">
            {data.topLives.map((l) => (
              <li key={l.roomId}>
                <UserCell username={l.host.username} displayName={l.host.displayName} avatarUrl={l.host.avatarUrl} />
                <span className="names">
                  <span>{l.title}</span>
                  <span className="muted small">{t('homeViewers', { n: n(l.viewers) })}</span>
                </span>
              </li>
            ))}
          </ul>
        </section>
        <section className="card">
          <h2>{t('homeTopHosts')}</h2>
          {data.topHosts.length === 0 && <p className="muted small">{t('homeNone')}</p>}
          <ul className="activity">
            {data.topHosts.map((h) => (
              <li key={h.host.id}>
                <UserCell username={h.host.username} displayName={h.host.displayName} avatarUrl={h.host.avatarUrl} />
                <span className="names">
                  <span className="muted small">{t('homeLiveMinutes', { n: n(h.liveMinutes7d) })}</span>
                  {h.liveNow && <span className="badge ok">{t('homeOnAir')}</span>}
                </span>
              </li>
            ))}
          </ul>
        </section>
        <section className="card">
          <h2>{t('homeEvents')}</h2>
          <EventsList events={data.events} />
        </section>
      </div>
    </div>
  );
}

export function TalentHomeView({ data }: { data: TalentHome }) {
  const { t, lang } = useApp();
  const n = (v: number) => formatNumber(v, lang);
  return (
    <div data-home="talent">
      <div className="kpis">
        <Stat icon="users" tone="green" label={t('homeNewHosts')} value={n(data.newHosts7d)} />
        <Stat icon="clock" tone="blue" label={t('homeLiveHours')} value={formatNumber(data.liveHours7d, lang)} />
        <Stat icon="inbox" tone="gold" label={t('homeHostApps')} value={n(data.queue.hostApplications)} onOpen={() => navigate('/host-applications')} />
        <Stat icon="inbox" tone="wine" label={t('homeCreatorApps')} value={n(data.queue.creatorApplications)} onOpen={() => navigate('/creator-applications')} />
      </div>
      <section className="card">
        <h2>{t('homeInactiveAgencies')}</h2>
        {data.inactiveAgencies.length === 0 && <p className="muted small">{t('homeNone')}</p>}
        <ul className="activity">
          {data.inactiveAgencies.map((a) => (
            <li key={a.id}>
              <button type="button" className="linklike" onClick={() => navigate(`/agencies/${a.id}`)}>
                <span className="mono">{a.inviteCode}</span> {a.name ?? ''}
              </button>
              <span className="names">
                <span className="muted small">{a.owner.displayName}</span>
                <span className="muted small">
                  {a.lastLiveAt ? t('homeLastLive', { date: formatDate(a.lastLiveAt, lang) }) : t('homeNeverLive')}
                </span>
              </span>
            </li>
          ))}
        </ul>
      </section>
    </div>
  );
}

export function TrustSafetyHomeView({ data }: { data: TrustSafetyHome }) {
  const { t, lang } = useApp();
  const n = (v: number) => formatNumber(v, lang);
  return (
    <div data-home="trust-safety">
      <div className="kpis">
        <Stat icon="flag" tone="red" label={t('homeOpenReports')} value={n(data.openReports)} onOpen={() => navigate('/reports')} />
        <Stat
          icon="clock"
          tone="blue"
          label={t('homeAvgResolve')}
          value={data.avgResolveMinutes === null ? '—' : t('homeMinutes', { n: n(data.avgResolveMinutes) })}
        />
        <Stat icon="tasks" tone="green" label={t('homeResolved7d')} value={n(data.resolved7d)} />
        <Stat icon="live" tone="gold" label={t('homeLivesNow')} value={n(data.livesNow)} onOpen={() => navigate('/lives')} />
      </div>
      <ShiftCard shift={data.shift} />
    </div>
  );
}

function SupporterRow({ s }: { s: VipSupporter }) {
  const { t, lang } = useApp();
  return (
    <li>
      <UserCell username={s.user.username} displayName={s.user.displayName} avatarUrl={s.user.avatarUrl} />
      <span className="names">
        <span>
          {s.level !== null && <span className="badge">{t('homeLevel', { n: s.level })}</span>}{' '}
          {s.vipTier && (
            <span className="badge" style={{ borderColor: s.vipTier.color, color: s.vipTier.color }}>
              {lang === 'ar' ? s.vipTier.nameAr : s.vipTier.nameEn}
            </span>
          )}
        </span>
        <span className="muted small">
          {s.lastActiveAt ? t('homeLastActive', { date: formatDate(s.lastActiveAt, lang) }) : '—'}
        </span>
      </span>
    </li>
  );
}

export function VipCareHomeView({ data }: { data: VipCareHome }) {
  const { t, lang } = useApp();
  return (
    <div data-home="vip-care">
      <div className="kpis">
        <Stat
          icon="inbox"
          tone="gold"
          label={t('homePendingComp')}
          value={formatNumber(data.pendingCompensations, lang)}
          onOpen={() => navigate('/compensations')}
        />
      </div>
      <div className="dash-grid">
        <section className="card">
          <h2>{t('homeTopSupporters')}</h2>
          {data.topSupporters.length === 0 && <p className="muted small">{t('homeNone')}</p>}
          <ul className="activity">
            {data.topSupporters.map((s) => (
              <SupporterRow key={s.user.id} s={s} />
            ))}
          </ul>
        </section>
        <section className="card">
          <h2>{t('homeStopped', { n: data.inactiveDays })}</h2>
          {data.stoppedActive.length === 0 && <p className="muted small">{t('homeNone')}</p>}
          <ul className="activity">
            {data.stoppedActive.map((s) => (
              <SupporterRow key={s.user.id} s={s} />
            ))}
          </ul>
        </section>
        <ShiftCard shift={data.shift} />
      </div>
    </div>
  );
}

export function CommunityHomeView({ data }: { data: CommunityHome }) {
  const { t, lang } = useApp();
  return (
    <div data-home="community">
      <div className="dash-grid">
        <section className="card">
          <h2>{t('homeUpcomingEvents')}</h2>
          <EventsList events={data.upcomingEvents} />
        </section>
        <section className="card">
          <h2>{t('homeParticipation')}</h2>
          {data.participation.length === 0 && <p className="muted small">{t('homeNone')}</p>}
          <ul className="activity">
            {data.participation.map((p) => (
              <li key={p.eventId}>
                <span className="names">
                  <span>{lang === 'ar' ? p.titleAr : p.titleEn}</span>
                  <span className="muted small">{t('homeEntrants', { n: formatNumber(p.entrants, lang) })}</span>
                </span>
              </li>
            ))}
          </ul>
        </section>
        <section className="card">
          <h2>{t('homeBannersLive')}</h2>
          {data.bannersLive.length === 0 && <p className="muted small">{t('homeNone')}</p>}
          <ul className="activity">
            {data.bannersLive.map((b) => (
              <li key={b.id}>
                <span className="names">
                  <span>{(lang === 'ar' ? b.titleAr : b.titleEn) ?? b.placement}</span>
                  <span className="muted small">
                    <span className="mono">{b.placement}</span>
                    {b.endsAt && ` · ${t('homeUntil', { date: formatDate(b.endsAt, lang) })}`}
                  </span>
                </span>
              </li>
            ))}
          </ul>
        </section>
      </div>
    </div>
  );
}

function OneHome({ cap, path, title }: (typeof HOMES)[number]) {
  const { t } = useApp();
  const res = useAsync(() => api.get<unknown>(path), [path]);
  let view: React.ReactNode = null;
  if (res.data) {
    switch (cap) {
      case 'home.live_ops':
        view = <LiveOpsHomeView data={res.data as LiveOpsHome} />;
        break;
      case 'home.talent':
        view = <TalentHomeView data={res.data as TalentHome} />;
        break;
      case 'home.trust_safety':
        view = <TrustSafetyHomeView data={res.data as TrustSafetyHome} />;
        break;
      case 'home.vip_care':
        view = <VipCareHomeView data={res.data as VipCareHome} />;
        break;
      case 'home.community':
        view = <CommunityHomeView data={res.data as CommunityHome} />;
        break;
    }
  }
  return (
    <section className="role-home">
      <h2>{t(title)}</h2>
      <ErrorAlert error={res.error} />
      {view ?? (!res.error && <div className="kpis"><div className="kpi skeleton-card" /></div>)}
    </section>
  );
}

/** The landing page of a staff member with one or more role homes (never the OWNER: the KPI dashboard). */
export function RoleHomes() {
  const { t, can, session } = useApp();
  const homes = homesOf(can);
  return (
    <>
      <div className="page-head">
        <div>
          <h1>{t('homeHello', { name: session?.admin.displayName ?? '' })}</h1>
          <p className="muted small">
            {session?.roles.map((r) => t(`role${r}`)).join(' · ')} · {t('homeNoMoney')}
          </p>
        </div>
      </div>
      {homes.map((h) => (
        <OneHome key={h.cap} {...h} />
      ))}
    </>
  );
}
