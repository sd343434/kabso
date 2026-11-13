import { useState } from 'react';
import { api } from '../api';
import { Dialog, ErrorAlert, Loading, useAsync } from '../components';
import { useApp } from '../context';
import { SOCIAL_PLATFORMS, type SocialAccount, type SocialPlatform } from '../types';
import { Icon } from '../ui/icons';

/**
 * v1.139-social (D387, CONVENTIONS §10.176.5): «حساباتنا الرسمية» — the app's official social media accounts (COMMUNITY
 * and the OWNER, `social.accounts`): platform, handle and an https link, in order. **Links only: no password, token or
 * key is ever asked for or stored.** The app shows them in Settings under «تابعنا».
 */

/** The panel's own check before sending (the server checks again): https, a host, no user name or password. */
export function isHttpsUrl(raw: string): boolean {
  const v = raw.trim();
  if (!/^https:\/\//i.test(v) || /\s/.test(v) || v.length > 512) return false;
  try {
    const u = new URL(v);
    return u.protocol === 'https:' && u.hostname !== '' && u.username === '' && u.password === '';
  } catch {
    return false;
  }
}

/** The ids with one account moved up (-1) or down (+1). */
export function moved(ids: string[], id: string, by: -1 | 1): string[] {
  const i = ids.indexOf(id);
  const j = i + by;
  if (i < 0 || j < 0 || j >= ids.length) return ids;
  const next = [...ids];
  [next[i], next[j]] = [next[j]!, next[i]!];
  return next;
}

/** The list (pure: rendered in the tests). */
export function SocialAccountList({
  accounts,
  onEdit,
  onMove,
}: {
  accounts: SocialAccount[];
  onEdit?: (a: SocialAccount) => void;
  onMove?: (a: SocialAccount, by: -1 | 1) => void;
}) {
  const { t } = useApp();
  if (accounts.length === 0) return <p className="muted state">{t('socialNone')}</p>;
  return (
    <ul className="activity" data-social-list>
      {accounts.map((a, i) => (
        <li key={a.id}>
          <span className="badge">{t(`platform${a.platform}`)}</span>
          <span className="names">
            <span className="ltr">{a.handle}</span>
            <a className="muted small ltr" href={a.url} target="_blank" rel="noopener noreferrer">
              {a.url}
            </a>
          </span>
          {onMove && (
            <span className="row">
              <button className="btn small ghost" disabled={i === 0} onClick={() => onMove(a, -1)} aria-label={t('socialUp')}>
                <Icon name="arrowUp" size={14} />
              </button>
              <button className="btn small ghost" disabled={i === accounts.length - 1} onClick={() => onMove(a, 1)} aria-label={t('socialDown')}>
                <Icon name="arrowDown" size={14} />
              </button>
            </span>
          )}
          {onEdit && (
            <button className="btn small" onClick={() => onEdit(a)}>
              {t('socialEdit')}
            </button>
          )}
        </li>
      ))}
    </ul>
  );
}

function AccountDialog({
  account,
  onClose,
  onDone,
}: {
  account: SocialAccount | null;
  onClose: () => void;
  onDone: () => void;
}) {
  const { t } = useApp();
  const [platform, setPlatform] = useState<SocialPlatform>(account?.platform ?? 'INSTAGRAM');
  const [handle, setHandle] = useState(account?.handle ?? '');
  const [url, setUrl] = useState(account?.url ?? 'https://');
  const [error, setError] = useState<unknown>(null);
  const [busy, setBusy] = useState(false);
  const urlOk = isHttpsUrl(url);
  const ok = handle.trim() !== '' && handle.trim().length <= 64 && urlOk;
  const run = (p: Promise<unknown>) => {
    setBusy(true);
    setError(null);
    p.then(onDone, (err: unknown) => {
      setBusy(false);
      setError(err);
    });
  };
  return (
    <Dialog title={t(account ? 'socialEdit' : 'socialAdd')} onClose={onClose}>
      <ErrorAlert error={error} />
      <form
        onSubmit={(e) => {
          e.preventDefault();
          if (!ok || busy) return;
          const body = { platform, handle: handle.trim(), url: url.trim() };
          run(account ? api.put(`/admin/social-accounts/${account.id}`, body) : api.post('/admin/social-accounts', body));
        }}
      >
        <div className="field">
          <label htmlFor="soc-platform">{t('socialPlatform')}</label>
          <select id="soc-platform" value={platform} onChange={(e) => setPlatform(e.target.value as SocialPlatform)}>
            {SOCIAL_PLATFORMS.map((p) => (
              <option key={p} value={p}>
                {t(`platform${p}`)}
              </option>
            ))}
          </select>
        </div>
        <div className="field">
          <label htmlFor="soc-handle">{t('socialHandle')}</label>
          <input id="soc-handle" className="ltr" maxLength={64} value={handle} onChange={(e) => setHandle(e.target.value)} />
        </div>
        <div className="field">
          <label htmlFor="soc-url">{t('socialUrl')}</label>
          <input id="soc-url" className="ltr" maxLength={512} value={url} onChange={(e) => setUrl(e.target.value)} />
          {!urlOk && url.trim() !== '' && url.trim() !== 'https://' && <span className="hint error">{t('socialHttps')}</span>}
        </div>
        <div className="actions">
          {account && (
            <button
              type="button"
              className="btn danger"
              disabled={busy}
              onClick={() => run(api.del(`/admin/social-accounts/${account.id}`))}
            >
              {t('socialDelete')}
            </button>
          )}
          <button type="button" className="btn" onClick={onClose}>
            {t('cancel')}
          </button>
          <button type="submit" className="btn primary" disabled={!ok || busy}>
            {t('save')}
          </button>
        </div>
      </form>
    </Dialog>
  );
}

export function SocialAccounts() {
  const { t, toast } = useApp();
  const res = useAsync(() => api.get<{ data: SocialAccount[] }>('/admin/social-accounts'), []);
  const [dialog, setDialog] = useState<'add' | SocialAccount | null>(null);
  const [error, setError] = useState<unknown>(null);
  const done = () => {
    setDialog(null);
    toast(t('done'));
    res.reload();
  };
  if (res.loading && !res.data) return <Loading />;
  if (!res.data) return <ErrorAlert error={res.error} />;
  const accounts = res.data.data;
  return (
    <>
      <div className="page-head">
        <div>
          <h1>{t('socialTitle')}</h1>
          <p className="muted small">{t('socialSubtitle')}</p>
          <p className="muted small">{t('socialMax')}</p>
        </div>
        <button className="btn primary" onClick={() => setDialog('add')} disabled={accounts.length >= 20}>
          <Icon name="plus" size={16} />
          {t('socialAdd')}
        </button>
      </div>
      <ErrorAlert error={error} />
      <section className="card">
        <SocialAccountList
          accounts={accounts}
          onEdit={(a) => setDialog(a)}
          onMove={(a, by) => {
            setError(null);
            api
              .put('/admin/social-accounts/order', { ids: moved(accounts.map((x) => x.id), a.id, by) })
              .then(() => res.reload(), setError);
          }}
        />
      </section>
      {dialog && <AccountDialog account={dialog === 'add' ? null : dialog} onClose={() => setDialog(null)} onDone={done} />}
    </>
  );
}
