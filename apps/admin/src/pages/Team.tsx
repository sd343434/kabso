import { useState } from 'react';
import { api } from '../api';
import { Avatar, codeField, Dialog, ErrorAlert, FormDialog, reasonField, StatusBadge, useAsync } from '../components';
import { useApp } from '../context';
import { formatDate } from '../format';
import type { PanelRole } from '../types';
import { Icon } from '../ui/icons';

interface Member {
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
}

const ROLES: PanelRole[] = ['OWNER', 'MODERATION', 'SUPPORT', 'FINANCE'];

function GrantDialog({ onClose, onDone }: { onClose: () => void; onDone: () => void }) {
  const { t } = useApp();
  const [role, setRole] = useState<PanelRole>('SUPPORT');
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
        </>
      }
      fields={[{ name: 'email', label: t('email'), maxLength: 254 }, reasonField(t), codeField(t)]}
      confirmLabel={t('teamGrant')}
      submit={(v) => api.post('/admin/team/grant', { email: v.email, role, reason: v.reason, totpCode: v.totpCode })}
      onClose={onClose}
      onDone={onDone}
    />
  );
}

/**
 * The team «الفريق» (D197, OWNER): who has which panel role, their authenticator and lock; grant / revoke a role
 * and reset an authenticator — the `admin-admin` rules, each with the code again and a reason (audited).
 */
export function Team() {
  const { t, lang, session, toast } = useApp();
  const { data, error, reload } = useAsync(() => api.get<{ data: Member[] }>('/admin/team'), []);
  const [dialog, setDialog] = useState<'grant' | { revoke: Member } | { reset: Member } | null>(null);
  const [revokeRole, setRevokeRole] = useState<PanelRole | null>(null);
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
          <h1>{t('teamTitle')}</h1>
          <p className="muted small">{t('teamSubtitle')}</p>
        </div>
        <button className="btn primary" onClick={() => setDialog('grant')}>
          <Icon name="plus" size={16} />
          {t('teamGrant')}
        </button>
      </div>
      <ErrorAlert error={error} />
      <div className="team-grid">
        {data?.data.map((m) => (
          <div key={m.id} className="card member">
            <div className="row">
              <Avatar url={m.avatarUrl} name={m.displayName || m.username} large />
              <div className="grow">
                <div className="strong">
                  {m.displayName} {m.id === session?.admin.id && <span className="badge">{t('teamYou')}</span>}
                </div>
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
              {m.lockedUntil && (
                <>
                  <dt>{t('teamLocked')}</dt>
                  <dd className="date">{formatDate(m.lockedUntil, lang)}</dd>
                </>
              )}
            </dl>
            {m.id !== session?.admin.id && (
              <div className="row">
                <button className="btn small" onClick={() => setDialog({ revoke: m })}>
                  {t('teamRevoke')}
                </button>
                {m.totpEnrolled && (
                  <button className="btn small" onClick={() => setDialog({ reset: m })}>
                    {t('teamReset2fa')}
                  </button>
                )}
              </div>
            )}
          </div>
        ))}
      </div>
      <p className="muted small">{t('teamCliNote')}</p>
      {dialog === 'grant' && <GrantDialog onClose={() => setDialog(null)} onDone={done} />}
      {dialog && dialog !== 'grant' && 'revoke' in dialog && !revokeRole && (
        <Dialog title={t('teamRevoke')} onClose={() => setDialog(null)}>
          <p className="muted small">{t('teamRevokePick', { name: dialog.revoke.displayName })}</p>
          <div className="row">
            {dialog.revoke.roles.map((r) => (
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
          intro={<p className="muted small">{t('teamRevokeIntro')}</p>}
          fields={[reasonField(t), codeField(t)]}
          confirmLabel={t('teamRevoke')}
          danger
          submit={(v) => api.post(`/admin/team/${dialog.revoke.id}/revoke`, { role: revokeRole, reason: v.reason, totpCode: v.totpCode })}
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
          fields={[reasonField(t), codeField(t)]}
          confirmLabel={t('teamReset2fa')}
          danger
          submit={(v) => api.post(`/admin/team/${dialog.reset.id}/reset-2fa`, { reason: v.reason, totpCode: v.totpCode })}
          onClose={() => setDialog(null)}
          onDone={done}
        />
      )}
    </>
  );
}
