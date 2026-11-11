import { Fragment, useRef, useState } from 'react';
import { api } from '../api';
import { Avatar, codeField, Dialog, ErrorAlert, FormDialog, reasonField, StatusBadge, useAsync } from '../components';
import { useApp } from '../context';
import { formatDate } from '../format';
import type { PanelRole, WaDepartment } from '../types';
import { WA_DEPARTMENTS } from '../types';
import { Icon } from '../ui/icons';
import { STAFF_REGIONS, type StaffRegion } from '../i18n-d283';
import { recruitBreakdown, type RecruitCounts } from './Recruits';

export interface Member {
  id: string;
  email: string;
  username: string;
  displayName: string;
  avatarUrl: string | null;
  status: string;
  roles: PanelRole[];
  totpEnrolled: boolean;
  lockedUntil: string | null;
  lastSignInAt: string | null;
  /** D271: the shift «في المناوبة» (D260); absent from an older API. */
  onShift?: boolean;
  shiftSince?: string | null;
  /** D283: the regions of a MODERATION / SUPPORT staff member (absent from an older API). */
  regions?: StaffRegion[];
  /** D283c: the official staff ID «Kabso01» (absent from an older API; null for a row granted outside the API). */
  staffId?: string | null;
  /** D285: how many recruits the person has, by type (absent from an older API). */
  recruits?: RecruitCounts;
  /** D360: the WhatsApp level «مستوى واتساب» (absent from an older API). */
  whatsapp?: TeamWhatsApp;
  /** D364: the WhatsApp departments «الأقسام» (absent from an older API). */
  whatsappDepartments?: TeamWaDepartments;
}

/** D364 (v1.122-social, §10.157.1): a staff member's WhatsApp departments (GENERAL when none is set). */
export interface TeamWaDepartments {
  departments: WaDepartment[];
  isDefault: boolean;
}

/** D364: set the departments ([] = back to GENERAL) — team.manage, the reason and a fresh code; audited. */
export const setStaffWaDepartments = (userId: string, departments: WaDepartment[], reason: string, totpCode: string) =>
  api.put<{ userId: string; before: WaDepartment[]; whatsappDepartments: TeamWaDepartments }>(
    `/admin/team/${userId}/whatsapp/departments`,
    { departments, reason, totpCode },
  );

/** D364: whether the departments can be set — the WhatsApp level REPLY or MANAGE. */
export const answersWhatsApp = (m: Member) => m.whatsapp?.level === 'REPLY' || m.whatsapp?.level === 'MANAGE';

/** D364: the departments row of a member card, under the WhatsApp level. */
export function WaDepartmentsRow({
  m,
  onEdit,
}: {
  m: Member & { whatsappDepartments: TeamWaDepartments };
  onEdit?: () => void;
}) {
  const { t } = useApp();
  const d = m.whatsappDepartments;
  const replies = answersWhatsApp(m);
  return (
    <>
      <dt>{t('waDepartments')}</dt>
      <dd data-wa-departments={d.departments.join(',')} data-wa-departments-default={d.isDefault ? 'true' : 'false'}>
        {d.departments.map((x) => (
          <Fragment key={x}>
            <span className={`badge ${replies ? 'info' : ''}`}>{t(`waDept${x}`)}</span>{' '}
          </Fragment>
        ))}
        {d.isDefault && <span className="badge">{t('waDepartmentsDefaultTag')}</span>}
        {!replies && <div className="muted small">{t('waDepartmentsReplyOnly')}</div>}
        {replies && onEdit && (
          <div>
            <button className="btn small" data-edit-wa-departments onClick={onEdit}>
              {t('waDepartmentsEdit')}
            </button>
          </div>
        )}
      </dd>
    </>
  );
}

/** D364: pick the departments (checkboxes in the catalogue's order; none = GENERAL), then the reason and the code. */
export function WaDepartmentsDialog({
  member,
  onClose,
  onDone,
}: {
  member: Member & { whatsappDepartments: TeamWaDepartments };
  onClose: () => void;
  onDone: () => void;
}) {
  const { t } = useApp();
  const d = member.whatsappDepartments;
  const [picked, setPicked] = useState<WaDepartment[]>(d.isDefault ? [] : d.departments);
  return (
    <FormDialog
      title={t('waDepartmentsTitle', { name: member.displayName || `@${member.username}` })}
      intro={
        <>
          <p className="muted small">{t('waDepartmentsIntro')}</p>
          <div className="region-picks" role="group" aria-label={t('waDepartments')}>
            {WA_DEPARTMENTS.map((x) => (
              <label key={x} className="check-row" data-wa-department-option={x}>
                <input
                  type="checkbox"
                  checked={picked.includes(x)}
                  onChange={(e) =>
                    setPicked((p) =>
                      e.target.checked ? WA_DEPARTMENTS.filter((y) => y === x || p.includes(y)) : p.filter((y) => y !== x),
                    )
                  }
                />{' '}
                <span className="strong">{t(`waDept${x}`)}</span>
              </label>
            ))}
          </div>
        </>
      }
      fields={[reasonField(t), stepField(t)]}
      confirmLabel={t('save')}
      submit={(v) => setStaffWaDepartments(member.id, picked, v.reason ?? '', v.totpCode ?? '')}
      onClose={onClose}
      onDone={onDone}
    />
  );
}

/** D360 (v1.120-social, §10.155): a staff member's WhatsApp level. */
export type WhatsAppLevel = 'NONE' | 'VIEW' | 'REPLY' | 'MANAGE';
export const WHATSAPP_LEVELS: WhatsAppLevel[] = ['NONE', 'VIEW', 'REPLY', 'MANAGE'];
export interface TeamWhatsApp {
  level: WhatsAppLevel;
  /** The level set for the person; null — the roles' default applies. */
  setLevel: WhatsAppLevel | null;
  defaultLevel: WhatsAppLevel;
  /** An OWNER: always MANAGE. */
  locked: boolean;
}

/** D360: set a level (or null: back to the roles' default) — team.manage, the reason and a fresh code; audited. */
export const setStaffWhatsApp = (userId: string, level: WhatsAppLevel | null, reason: string, totpCode: string) =>
  api.put<{ userId: string; before: WhatsAppLevel; whatsapp: TeamWhatsApp; released: number }>(
    `/admin/team/${userId}/whatsapp`,
    { level, reason, totpCode },
  );

/** D360: the level row of a member card — the level, «افتراضي» when none is set, and what it allows. */
export function WhatsAppLevelRow({ wa, onEdit }: { wa: TeamWhatsApp; onEdit?: () => void }) {
  const { t } = useApp();
  return (
    <>
      <dt>{t('waLevel')}</dt>
      <dd data-wa-level={wa.level} data-wa-level-set={wa.setLevel ?? ''}>
        <span className={`badge ${wa.level === 'NONE' ? '' : wa.level === 'VIEW' ? 'warn' : 'info'}`}>
          {t(`waLevel${wa.level}`)}
        </span>{' '}
        {wa.locked ? (
          <span className="muted small">{t('waLevelOwner')}</span>
        ) : wa.setLevel === null ? (
          <span className="badge">{t('waLevelDefaultTag')}</span>
        ) : null}
        <div className="muted small">{t(`waLevel${wa.level}Hint`)}</div>
        {!wa.locked && onEdit && (
          <button className="btn small" data-edit-wa-level onClick={onEdit}>
            {t('waLevelEdit')}
          </button>
        )}
      </dd>
    </>
  );
}

/** D360: pick the level (or the roles' default), then the reason and the code. */
export function WhatsAppLevelDialog({
  member,
  onClose,
  onDone,
}: {
  member: Member & { whatsapp: TeamWhatsApp };
  onClose: () => void;
  onDone: (released: number) => void;
}) {
  const { t } = useApp();
  const wa = member.whatsapp;
  const [picked, setPicked] = useState<WhatsAppLevel | 'DEFAULT'>(wa.setLevel ?? 'DEFAULT');
  const released = useRef(0);
  const options: (WhatsAppLevel | 'DEFAULT')[] = ['DEFAULT', ...WHATSAPP_LEVELS];
  return (
    <FormDialog
      title={t('waLevelTitle', { name: member.displayName || `@${member.username}` })}
      intro={
        <>
          <p className="muted small">{t('waLevelIntro')}</p>
          <div className="wa-level-picks" role="radiogroup" aria-label={t('waLevel')}>
            {options.map((o) => (
              <label key={o} className="check-row" data-wa-level-option={o}>
                <input
                  type="radio"
                  name="wa-level"
                  checked={picked === o}
                  onChange={() => setPicked(o)}
                />{' '}
                <span className="strong">
                  {o === 'DEFAULT' ? t('waLevelDefault', { level: t(`waLevel${wa.defaultLevel}`) }) : t(`waLevel${o}`)}
                </span>
                <span className="muted small"> — {t(`waLevel${o === 'DEFAULT' ? wa.defaultLevel : o}Hint`)}</span>
              </label>
            ))}
          </div>
        </>
      }
      fields={[reasonField(t), stepField(t)]}
      confirmLabel={t('save')}
      submit={async (v) => {
        const r = await setStaffWhatsApp(
          member.id,
          picked === 'DEFAULT' ? null : picked,
          v.reason ?? '',
          v.totpCode ?? '',
        );
        released.current = r.released;
        return r;
      }}
      onClose={onClose}
      onDone={() => onDone(released.current)}
    />
  );
}

/**
 * D283c: the staff list's search — the staff ID («Kabso01», «kabso1», «01» all find Kabso01), the name, the username
 * (`@` optional) or the email, any case.
 */
export function matchesStaffQuery(m: Member, raw: string): boolean {
  const q = raw.trim().toLowerCase().replace(/^@/, '');
  if (q === '') return true;
  if (m.staffId) {
    const id = m.staffId.toLowerCase();
    if (id.includes(q)) return true;
    const typed = /^(?:kabso)?0*([1-9][0-9]*)$/.exec(q);
    if (typed && Number(id.replace(/^kabso/, '')) === Number(typed[1])) return true;
  }
  return [m.displayName, m.username, m.email].some((v) => v.toLowerCase().includes(q));
}

/** D283: the roles that carry regions. */
export const REGION_ROLES: PanelRole[] = ['MODERATION', 'SUPPORT', 'BD'];

/** D283: the whole set of a staff member's regions (OWNER; the reason and a fresh code; audited). */
export const setStaffRegions = (userId: string, regions: StaffRegion[], reason: string, totpCode: string) =>
  api.put<{ userId: string; regions: StaffRegion[]; before: StaffRegion[] }>(`/admin/team/${userId}/regions`, {
    regions,
    reason,
    totpCode,
  });

/** D283: pick the regions (checkboxes in the catalogue's order), then the reason and the code. */
export function RegionsDialog({ member, onClose, onDone }: { member: Member; onClose: () => void; onDone: () => void }) {
  const { t } = useApp();
  const [picked, setPicked] = useState<StaffRegion[]>(member.regions ?? []);
  const toggle = (r: StaffRegion) =>
    setPicked((p) => (p.includes(r) ? p.filter((x) => x !== r) : STAFF_REGIONS.filter((x) => x === r || p.includes(x))));
  return (
    <FormDialog
      title={t('staffRegionsTitle', { name: member.displayName || `@${member.username}` })}
      intro={
        <>
          <p className="muted small">{t('staffRegionsIntro')}</p>
          <div className="region-picks" role="group" aria-label={t('staffRegions')}>
            {STAFF_REGIONS.map((r) => (
              <label key={r} className="check-row" data-region={r}>
                <input type="checkbox" checked={picked.includes(r)} onChange={() => toggle(r)} /> {t(`region${r}`)}
              </label>
            ))}
          </div>
        </>
      }
      fields={[reasonField(t), stepField(t)]}
      confirmLabel={t('save')}
      submit={(v) => setStaffRegions(member.id, picked, v.reason ?? '', v.totpCode ?? '')}
      onClose={onClose}
      onDone={onDone}
    />
  );
}

/** `AdminTeamGrantResult` (D271 adds `account`). */
export interface GrantResult {
  userId: string;
  role: PanelRole;
  madeAdmin: boolean;
  already: boolean;
  /** D283c: the person's staff ID (new with a first grant, the same again on a re-grant). */
  staffId?: string | null;
  account?: { email: string; username: string; displayName: string; totpEnrolled: boolean };
}

export const ROLES: PanelRole[] = ['OWNER', 'MODERATION', 'SUPPORT', 'FINANCE', 'BD'];
/** The roles with a shift and lives to watch (D260; the API's `lives.watch`). */
export const SHIFT_ROLES: PanelRole[] = ['OWNER', 'MODERATION', 'SUPPORT'];

/** The three team changes, each with the reason and a fresh authenticator code (checked by the server first). */
export const grantStaff = (account: string, role: PanelRole, reason: string, totpCode: string) =>
  api.post<GrantResult>('/admin/team/grant', { account, role, reason, totpCode });
export const revokeStaff = (userId: string, role: PanelRole, reason: string, totpCode: string) =>
  api.post<{ userId: string; left: PanelRole[]; shiftEnded?: boolean }>(`/admin/team/${userId}/revoke`, {
    role,
    reason,
    totpCode,
  });
export const resetStaff2fa = (userId: string, reason: string, totpCode: string) =>
  api.post<{ reset: boolean }>(`/admin/team/${userId}/reset-2fa`, { reason, totpCode });

/** The roles the OWNER may take from `m` here: never their own OWNER, never the last active OWNER's. */
export function revocableRoles(m: Member, selfId: string | undefined, activeOwners: number): PanelRole[] {
  return m.roles.filter((r) => {
    if (r !== 'OWNER') return true;
    if (m.id === selfId) return false;
    return !(m.status === 'ACTIVE' && activeOwners <= 1);
  });
}

function stepField(t: ReturnType<typeof useApp>['t']) {
  return { ...codeField(t), hint: t('staffCodeHint') };
}

export function GrantDialog({ onClose, onDone }: { onClose: () => void; onDone: (r: GrantResult) => void }) {
  const { t } = useApp();
  const [role, setRole] = useState<PanelRole>('SUPPORT');
  const result = useRef<GrantResult | null>(null);
  return (
    <FormDialog
      title={t('teamGrant')}
      intro={
        <>
          <div className="segmented wrap" role="group" aria-label={t('teamRole')}>
            {ROLES.map((r) => (
              <button key={r} type="button" aria-pressed={role === r} onClick={() => setRole(r)}>
                {t(`role${r}`)}
              </button>
            ))}
          </div>
          <p className="muted small">{t(`roleHint${role}` as never)}</p>
          {role === 'OWNER' && (
            <div className="alert warn" data-owner-warning>
              {t('staffOwnerWarning')}
            </div>
          )}
        </>
      }
      fields={[
        { name: 'account', label: t('staffAccount'), maxLength: 254, hint: t('staffAccountHint') },
        reasonField(t),
        stepField(t),
      ]}
      confirmLabel={t('teamGrant')}
      submit={async (v) => {
        result.current = await grantStaff(v.account ?? '', role, v.reason ?? '', v.totpCode ?? '');
      }}
      onClose={onClose}
      onDone={() => {
        // FormDialog calls this after `submit` resolved, so the result is set.
        if (result.current) onDone(result.current);
      }}
    />
  );
}

/** What the new staff member does next: sign in, enrol the authenticator, go on shift (D260). */
export function NextSteps({ result, origin, onClose }: { result: GrantResult; origin: string; onClose: () => void }) {
  const { t } = useApp();
  const a = result.account;
  const name = a ? a.displayName || `@${a.username}` : '';
  const watches = SHIFT_ROLES.includes(result.role);
  return (
    <Dialog title={t('staffNextTitle', { name })} onClose={onClose}>
      <div className="next-steps" data-role={result.role}>
        <div className="row roles">
          <span className="badge info">{t(`role${result.role}`)}</span>
          {result.staffId ? (
            <span className="badge staff-id ltr" data-staff-id={result.staffId}>
              {t('staffIdLabel', { id: result.staffId })}
            </span>
          ) : null}
          {a?.username ? <span className="ltr muted small">@{a.username}</span> : null}
        </div>
        {result.staffId ? <p className="small">{t('staffNextId', { id: result.staffId })}</p> : null}
        {result.already ? (
          <p className="muted">{t('staffNextAlready')}</p>
        ) : (
          <>
            <p className="muted small">{t('staffNextIntro')}</p>
            <ol className="steps">
              <li>{t('staffNextSignIn', { url: origin, email: a?.email ?? '' })}</li>
              <li>{a?.totpEnrolled ? t('staffNextEnrolled') : t('staffNextEnrol')}</li>
              <li>{watches ? t('staffNextShift') : t('staffNextFinance')}</li>
            </ol>
          </>
        )}
      </div>
      <div className="actions">
        <button className="btn primary" onClick={onClose}>
          {t('staffNextDone')}
        </button>
      </div>
    </Dialog>
  );
}

export function MemberCard({
  m,
  selfId,
  activeOwners,
  onRevoke,
  onReset,
  onRegions,
  onWhatsApp,
  onWaDepartments,
}: {
  m: Member;
  selfId: string | undefined;
  activeOwners: number;
  onRevoke: () => void;
  onReset: () => void;
  /** D283: edit the regions (MODERATION / SUPPORT only). */
  onRegions?: () => void;
  /** D360: change the WhatsApp level (never an OWNER's). */
  onWhatsApp?: () => void;
  /** D364: change the WhatsApp departments (REPLY / MANAGE only). */
  onWaDepartments?: () => void;
}) {
  const { t, lang } = useApp();
  const self = m.id === selfId;
  const watches = m.roles.some((r) => SHIFT_ROLES.includes(r));
  const canRevoke = revocableRoles(m, selfId, activeOwners).length > 0;
  const regional = m.regions !== undefined && m.roles.some((r) => REGION_ROLES.includes(r));
  return (
    <div className="card member" data-member={m.id} data-on-shift={m.onShift ? 'true' : 'false'}>
      <div className="row">
        <Avatar url={m.avatarUrl} name={m.displayName || m.username} large />
        <div className="grow">
          <div className="strong">
            {m.displayName} {self && <span className="badge">{t('teamYou')}</span>}
          </div>
          {m.staffId ? (
            <div>
              <span className="badge staff-id ltr" data-staff-id={m.staffId} title={t('staffIdTitle')}>
                {t('staffIdLabel', { id: m.staffId })}
              </span>
            </div>
          ) : null}
          {m.username ? <div className="ltr muted small">@{m.username}</div> : null}
          <div className="ltr muted small">{m.email}</div>
        </div>
        <StatusBadge status={m.status} />
      </div>
      <div className="row roles">
        {m.roles.map((r) => (
          <span key={r} className="badge info">
            {t(`role${r}`)}
          </span>
        ))}
      </div>
      <dl className="kv small">
        <dt>{t('team2fa')}</dt>
        <dd>{m.totpEnrolled ? <span className="badge ok">{t('team2faOn')}</span> : <span className="badge warn">{t('team2faOff')}</span>}</dd>
        <dt>{t('teamLastSignIn')}</dt>
        <dd className="date">{formatDate(m.lastSignInAt, lang)}</dd>
        {m.onShift !== undefined && (
          <>
            <dt>{t('staffShift')}</dt>
            <dd>
              {!watches ? (
                <span className="muted">{t('staffNoShift')}</span>
              ) : m.onShift ? (
                <>
                  <span className="badge ok">{t('shiftOn')}</span>{' '}
                  {m.shiftSince ? <span className="muted date">{t('staffShiftSince', { time: formatDate(m.shiftSince, lang) })}</span> : null}
                </>
              ) : (
                <span className="badge">{t('shiftOff')}</span>
              )}
            </dd>
          </>
        )}
        {regional && (
          <>
            <dt>{t('staffRegions')}</dt>
            <dd data-regions={(m.regions ?? []).join(',')}>
              {(m.regions ?? []).length === 0 ? (
                <span className="muted">{t('staffRegionsNone')}</span>
              ) : (
                (m.regions ?? []).map((r) => (
                  <span key={r} className="badge info region">
                    {t(`region${r}`)}
                  </span>
                ))
              )}
            </dd>
          </>
        )}
        {m.recruits && (m.recruits.total > 0 || m.roles.includes('BD') || m.roles.includes('MODERATION')) && (
          <>
            <dt>{t('recruitsTitle')}</dt>
            <dd data-recruits={m.recruits.total}>
              <span className="badge info">{t('recruitsCount', { n: m.recruits.total })}</span>{' '}
              <span className="muted small">{recruitBreakdown(m.recruits, t)}</span>
            </dd>
          </>
        )}
        {m.whatsapp && <WhatsAppLevelRow wa={m.whatsapp} onEdit={onWhatsApp} />}
        {m.whatsapp && m.whatsappDepartments && (
          <WaDepartmentsRow m={m as Member & { whatsappDepartments: TeamWaDepartments }} onEdit={onWaDepartments} />
        )}
        {m.lockedUntil && (
          <>
            <dt>{t('teamLocked')}</dt>
            <dd className="date">{formatDate(m.lockedUntil, lang)}</dd>
          </>
        )}
      </dl>
      {(canRevoke || (!self && m.totpEnrolled) || (regional && onRegions)) && (
        <div className="row">
          {regional && onRegions && (
            <button className="btn small" data-edit-regions onClick={onRegions}>
              {t('staffRegionsEdit')}
            </button>
          )}
          {canRevoke && (
            <button className="btn small" onClick={onRevoke}>
              {t('teamRevoke')}
            </button>
          )}
          {!self && m.totpEnrolled && (
            <button className="btn small" onClick={onReset}>
              {t('teamReset2fa')}
            </button>
          )}
        </div>
      )}
    </div>
  );
}

/**
 * «الموظفون والصلاحيات» (D197 «الفريق», D271; OWNER): who has which panel role, their authenticator, last sign-in
 * and shift; grant a role to an app account (email or username), revoke one, reset an authenticator — the
 * `admin-admin` rules on the server, each with a reason and a fresh authenticator code (audited). After a grant the
 * new staff member's next steps.
 */
export function Team() {
  const { t, session, toast } = useApp();
  const { data, error, reload } = useAsync(() => api.get<{ data: Member[] }>('/admin/team'), []);
  const [dialog, setDialog] = useState<
    | 'grant'
    | { revoke: Member }
    | { reset: Member }
    | { next: GrantResult }
    | { regions: Member }
    | { whatsapp: Member & { whatsapp: TeamWhatsApp } }
    | { departments: Member & { whatsappDepartments: TeamWaDepartments } }
    | null
  >(null);
  const [revokeRole, setRevokeRole] = useState<PanelRole | null>(null);
  const [query, setQuery] = useState('');
  const members = data?.data ?? [];
  const shown = members.filter((m) => matchesStaffQuery(m, query));
  const selfId = session?.admin.id;
  const activeOwners = members.filter((m) => m.status === 'ACTIVE' && m.roles.includes('OWNER')).length;
  const onShift = members.filter((m) => m.onShift).length;
  const done = () => {
    setDialog(null);
    setRevokeRole(null);
    toast(t('done'));
    reload();
  };
  return (
    <>
      <div className="page-head">
        <div>
          <h1>{t('staffTitle')}</h1>
          <p className="muted small">{t('staffSubtitle')}</p>
          {data && (
            <p className="small">
              <span className="badge">{t('staffCount', { n: members.length })}</span>{' '}
              <span className="badge ok">{t('staffOnShiftCount', { n: onShift })}</span>
            </p>
          )}
        </div>
        <button className="btn primary" onClick={() => setDialog('grant')}>
          <Icon name="plus" size={16} />
          {t('teamGrant')}
        </button>
      </div>
      <ErrorAlert error={error} />
      <div className="filters card">
        <label className="field">
          <span>{t('staffSearch')}</span>
          <input
            type="search"
            className="ltr"
            data-staff-search
            placeholder="Kabso01"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
          />
        </label>
      </div>
      {data && shown.length === 0 && query.trim() !== '' && (
        <p className="muted">{t('staffSearchNone', { q: query.trim() })}</p>
      )}
      <div className="team-grid">
        {shown.map((m) => (
          <MemberCard
            key={m.id}
            m={m}
            selfId={selfId}
            activeOwners={activeOwners}
            onRevoke={() => setDialog({ revoke: m })}
            onReset={() => setDialog({ reset: m })}
            onRegions={() => setDialog({ regions: m })}
            onWhatsApp={m.whatsapp ? () => setDialog({ whatsapp: m as Member & { whatsapp: TeamWhatsApp } }) : undefined}
            onWaDepartments={
              m.whatsappDepartments
                ? () => setDialog({ departments: m as Member & { whatsappDepartments: TeamWaDepartments } })
                : undefined
            }
          />
        ))}
      </div>
      <p className="muted small">{t('staffIdNote')}</p>
      <p className="muted small">{t('teamCliNote')}</p>
      {dialog === 'grant' && (
        <GrantDialog
          onClose={() => setDialog(null)}
          onDone={(r) => {
            setDialog({ next: r });
            reload();
          }}
        />
      )}
      {dialog && dialog !== 'grant' && 'next' in dialog && (
        <NextSteps result={dialog.next} origin={window.location.origin} onClose={() => setDialog(null)} />
      )}
      {dialog && dialog !== 'grant' && 'revoke' in dialog && !revokeRole && (
        <Dialog title={t('teamRevoke')} onClose={() => setDialog(null)}>
          <p className="muted small">{t('teamRevokePick', { name: dialog.revoke.displayName })}</p>
          <div className="row">
            {revocableRoles(dialog.revoke, selfId, activeOwners).map((r) => (
              <button key={r} className="btn" onClick={() => setRevokeRole(r)}>
                {t(`role${r}`)}
              </button>
            ))}
          </div>
          <div className="actions">
            <button className="btn" onClick={() => setDialog(null)}>
              {t('cancel')}
            </button>
          </div>
        </Dialog>
      )}
      {dialog && dialog !== 'grant' && 'revoke' in dialog && revokeRole && (
        <FormDialog
          title={`${t('teamRevoke')} · ${t(`role${revokeRole}`)}`}
          intro={
            <>
              <p className="muted small">{t('teamRevokeIntro')}</p>
              {dialog.revoke.onShift && <p className="muted small">{t('staffRevokeShiftNote')}</p>}
            </>
          }
          fields={[reasonField(t), stepField(t)]}
          confirmLabel={t('teamRevoke')}
          danger
          submit={(v) => revokeStaff(dialog.revoke.id, revokeRole, v.reason ?? '', v.totpCode ?? '')}
          onClose={() => {
            setDialog(null);
            setRevokeRole(null);
          }}
          onDone={done}
        />
      )}
      {dialog && dialog !== 'grant' && 'whatsapp' in dialog && (
        <WhatsAppLevelDialog
          member={dialog.whatsapp}
          onClose={() => setDialog(null)}
          onDone={(released) => {
            done();
            if (released > 0) toast(t('waLevelReleased', { n: released }));
          }}
        />
      )}
      {dialog && dialog !== 'grant' && 'departments' in dialog && (
        <WaDepartmentsDialog member={dialog.departments} onClose={() => setDialog(null)} onDone={done} />
      )}
      {dialog && dialog !== 'grant' && 'regions' in dialog && (
        <RegionsDialog member={dialog.regions} onClose={() => setDialog(null)} onDone={done} />
      )}
      {dialog && dialog !== 'grant' && 'reset' in dialog && (
        <FormDialog
          title={t('teamReset2fa')}
          intro={<p className="muted small">{t('teamResetIntro', { name: dialog.reset.displayName })}</p>}
          fields={[reasonField(t), stepField(t)]}
          confirmLabel={t('teamReset2fa')}
          danger
          submit={(v) => resetStaff2fa(dialog.reset.id, v.reason ?? '', v.totpCode ?? '')}
          onClose={() => setDialog(null)}
          onDone={done}
        />
      )}
    </>
  );
}
