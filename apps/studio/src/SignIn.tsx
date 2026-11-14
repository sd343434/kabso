import { useState, type FormEvent } from 'react';
import { ApiError, type Api } from './api';
import { useT } from './context';
import { errorKey } from './errors';
import type { AuthResponse, Me } from './types';

export const STUDIO_VERSION = '0.1.0';

/** `DeviceInfo` of the studio's session (shown in the app's «الأجهزة» list): platform `web`. */
export function studioDevice(userAgent: string): { name: string; platform: 'web'; appVersion: string } {
  const ua = userAgent.toLowerCase();
  const browser = /edg\//.test(ua) ? 'Edge' : /firefox\//.test(ua) ? 'Firefox' : /chrome\//.test(ua) ? 'Chrome' : /safari\//.test(ua) ? 'Safari' : 'Browser';
  const os = /windows/.test(ua) ? 'Windows' : /mac os x/.test(ua) ? 'macOS' : /cros/.test(ua) ? 'ChromeOS' : /linux/.test(ua) ? 'Linux' : 'Web';
  return { name: `Kabso Studio — ${browser} on ${os}`, platform: 'web', appVersion: `studio-${STUDIO_VERSION}` };
}

/**
 * Sign-in with the app's user login (`POST /auth/login`: email or username + password). Kabso has no second factor
 * for users; the two server rules the form answers are a password the team asked to change (`PASSWORD_CHANGE_REQUIRED`
 * → the same request with `newPassword`) and the honest refusals (locked, deletion pending — that one is cancelled in
 * the app).
 */
export function SignIn({ api, onSignedIn }: { api: Api; onSignedIn: (me: Me) => void }) {
  const { t } = useT();
  const [identifier, setIdentifier] = useState('');
  const [password, setPassword] = useState('');
  const [newPassword, setNewPassword] = useState('');
  const [needsNew, setNeedsNew] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<unknown>(null);

  const submit = async (e: FormEvent) => {
    e.preventDefault();
    setBusy(true);
    setError(null);
    try {
      const res = await api.anonymous<AuthResponse>('POST', '/auth/login', {
        identifier: identifier.trim(),
        password,
        device: studioDevice(navigator.userAgent),
        ...(needsNew ? { newPassword } : {}),
      });
      api.session.signedIn(res.tokens);
      setPassword('');
      setNewPassword('');
      onSignedIn(res.user);
    } catch (err) {
      if (err instanceof ApiError && err.code === 'PASSWORD_CHANGE_REQUIRED') {
        setNeedsNew(true);
      } else {
        setError(err);
      }
    } finally {
      setBusy(false);
    }
  };

  const msg = error ? errorKey(error) : null;
  return (
    <main className="center">
      <form className="card auth-card" onSubmit={submit} data-testid="sign-in">
        <div className="auth-brand">
          <span className="brand-mark" aria-hidden="true">
            K
          </span>
          <div>
            <strong>{t('appName')}</strong>
            <small>{t('appTag')}</small>
          </div>
        </div>
        <h1>{t('signInTitle')}</h1>
        <p className="muted">{t('signInSubtitle')}</p>
        {msg && (
          <div className="alert error" role="alert">
            {t(msg.key, msg.vars)}
          </div>
        )}
        <label className="field">
          <span>{t('identifier')}</span>
          <input
            name="identifier"
            className="ltr"
            autoComplete="username"
            required
            maxLength={254}
            value={identifier}
            onChange={(e) => setIdentifier(e.target.value)}
          />
        </label>
        <label className="field">
          <span>{t('password')}</span>
          <input
            name="password"
            type="password"
            className="ltr"
            autoComplete="current-password"
            required
            maxLength={128}
            value={password}
            onChange={(e) => setPassword(e.target.value)}
          />
        </label>
        {needsNew && (
          <label className="field">
            <span>{t('newPassword')}</span>
            <small className="muted">{t('newPasswordHint')}</small>
            <input
              name="newPassword"
              type="password"
              className="ltr"
              autoComplete="new-password"
              required
              minLength={8}
              maxLength={128}
              value={newPassword}
              onChange={(e) => setNewPassword(e.target.value)}
            />
          </label>
        )}
        <button className="btn primary block" disabled={busy || !identifier.trim() || !password || (needsNew && newPassword.length < 8)}>
          {busy ? t('signingIn') : t('signIn')}
        </button>
        <p className="muted small center-text">{t('forgotHint')}</p>
      </form>
    </main>
  );
}
