import { useRef, useState } from 'react';
import { api } from '../api';
import { Avatar, codeField, Dialog, ErrorAlert, FormDialog, reasonField, StatusBadge, useAsync } from '../components';
import { useApp } from '../context';
import { formatDate } from '../format';
import type { PanelRole } from '../types';
import { Icon } from '../ui/icons';

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
}

/** `AdminTeamGrantResult` (D271 adds `account`). */
export interface GrantResult {
  userId: string;
  role: PanelRole;
  madeAdmin: boolean;
  already: boolean;
  account?: { email: string; username: string; displayName: string; totpEnrolled: boolean };
}

export const ROLES: PanelRole[] = ['OWNER', 'MODERATION', 'SUPPORT', 'FINANCE'];
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
          {a?.username ? <span className="ltr muted small">@{a.username}</span> : null}
        </div>
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
}: {
  m: Member;
  selfId: string | undefined;
  activeOwners: number;
  onRevoke: () => void;
  onReset: () => void;
}) {
  const { t, lang } = useApp();
  const self = m.id === selfId;
  const watches = m.roles.some((r) => SHIFT_ROLES.includes(r));
  const canRevoke = revocableRoles(m, selfId, activeOwners).length > 0;
  return (
    <div className="card member" data-member={m.id} data-on-shift={m.onShift ? 'true' : 'false'}>
      <div className="row">
        <Avatar url={m.avatarUrl} name={m.displayName || m.username} large />
        <div className="grow">
          <div className="strong">
            {m.displayName} {self && <span className="badge">{t('teamYou')}</span>}
          </div>
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
        {m.lockedUntil && (
          <>
            <dt>{t('teamLocked')}</dt>
            <dd className="date">{formatDate(m.lockedUntil, lang)}</dd>
          </>
        )}
      </dl>
      {(canRevoke || (!self && m.totpEnrolled)) && (
        <div className="row">
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
  const [dialog, setDialog] = useState<'grant' | { revoke: Member } | { reset: Member } | { next: GrantResult } | null>(null);
  const [revokeRole, setRevokeRole] = useState<PanelRole | null>(null);
  const members = data?.data ?? [];
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
      <div className="team-grid">
        {members.map((m) => (
          <MemberCard
            key={m.id}
            m={m}
            selfId={selfId}
            activeOwners={activeOwners}
            onRevoke={() => setDialog({ revoke: m })}
            onReset={() => setDialog({ reset: m })}
          />
        ))}
      </div>
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
