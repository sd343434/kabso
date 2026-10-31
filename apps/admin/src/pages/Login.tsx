import { useState, type FormEvent } from 'react';
import { api, setCsrfToken } from '../api';
import { ErrorAlert } from '../components';
import { useApp } from '../context';
import { QrCode } from '../qr';
import type { AdminLoginResponse, AdminSessionInfo } from '../types';

type Step =
  | { kind: 'password' }
  | { kind: 'verify'; recovery: boolean }
  | { kind: 'enrol'; secret: string; uri: string }
  | { kind: 'codes'; codes: string[]; session: AdminSessionInfo };

/**
 * Sign-in: email and password, then the second factor — the QR enrolment on the first sign-in (with the ten
 * recovery codes shown once), or an authenticator code / a recovery code later (CONVENTIONS §10.54.2).
 */
export function Login({ onSignedIn, tools }: { onSignedIn: (s: AdminSessionInfo) => void; tools: React.ReactNode }) {
  const { t } = useApp();
  const [step, setStep] = useState<Step>({ kind: 'password' });
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [code, setCode] = useState('');
  const [error, setError] = useState<unknown>(null);
  const [busy, setBusy] = useState(false);
  const [copied, setCopied] = useState(false);

  const act = async (fn: () => Promise<void>) => {
    setBusy(true);
    setError(null);
    try {
      await fn();
    } catch (e) {
      setError(e);
    } finally {
      setBusy(false);
    }
  };

  const submitPassword = (e: FormEvent) => {
    e.preventDefault();
    void act(async () => {
      const res = await api.post<AdminLoginResponse>('/admin/auth/login', { email, password });
      setPassword('');
      setCsrfToken(res.csrfToken);
      if (res.next === 'TOTP_ENROL') {
        const enrol = await api.post<{ secret: string; otpauthUri: string }>('/admin/auth/totp/enrolment');
        setStep({ kind: 'enrol', secret: enrol.secret, uri: enrol.otpauthUri });
      } else {
        setStep({ kind: 'verify', recovery: false });
      }
    });
  };

  const submitCode = (e: FormEvent) => {
    e.preventDefault();
    void act(async () => {
      if (step.kind === 'enrol') {
        const res = await api.post<{ recoveryCodes: string[]; session: AdminSessionInfo }>(
          '/admin/auth/totp/enrolment/confirm',
          { code },
        );
        setCsrfToken(res.session.csrfToken);
        setStep({ kind: 'codes', codes: res.recoveryCodes, session: res.session });
      } else if (step.kind === 'verify') {
        const body = step.recovery ? { recoveryCode: code } : { code };
        const session = await api.post<AdminSessionInfo>('/admin/auth/totp/verify', body);
        setCsrfToken(session.csrfToken);
        onSignedIn(session);
      }
      setCode('');
    });
  };

  return (
    <main className="center">
      <div className="card auth-card">
        <div className="brand">
          <span className="brand-mark" aria-hidden="true">
            K
          </span>
          {t('appName')}
        </div>
        {step.kind === 'password' && (
          <form onSubmit={submitPassword}>
            <h1>{t('loginTitle')}</h1>
            <p className="muted small">{t('loginSubtitle')}</p>
            <ErrorAlert error={error} />
            <div className="field">
              <label htmlFor="email">{t('email')}</label>
              <input id="email" type="email" className="ltr" autoComplete="username" required value={email} onChange={(e) => setEmail(e.target.value)} />
            </div>
            <div className="field">
              <label htmlFor="password">{t('password')}</label>
              <input id="password" type="password" className="ltr" autoComplete="current-password" required value={password} onChange={(e) => setPassword(e.target.value)} />
            </div>
            <button className="btn primary" style={{ width: '100%' }} disabled={busy || !email || !password}>
              {t('signIn')}
            </button>
          </form>
        )}
        {(step.kind === 'verify' || step.kind === 'enrol') && (
          <form onSubmit={submitCode}>
            <h1>{step.kind === 'enrol' ? t('enrolTitle') : t('verifyTitle')}</h1>
            <p className="muted small">{step.kind === 'enrol' ? t('enrolSubtitle') : t('verifySubtitle')}</p>
            {step.kind === 'enrol' && (
              <>
                <QrCode text={step.uri} label={t('enrolTitle')} />
                <p className="small muted" style={{ textAlign: 'center' }}>
                  {t('enrolManual')}
                  <br />
                  <code className="mono" data-testid="totp-secret">
                    {step.secret}
                  </code>
                </p>
              </>
            )}
            <ErrorAlert error={error} />
            <div className="field">
              <label htmlFor="code">{step.kind === 'verify' && step.recovery ? t('recoveryCode') : t('totpCode')}</label>
              {step.kind === 'verify' && step.recovery ? (
                <input id="code" type="text" className="ltr mono" autoComplete="off" value={code} onChange={(e) => setCode(e.target.value)} />
              ) : (
                <input
                  id="code"
                  type="text"
                  className="code-input"
                  inputMode="numeric"
                  autoComplete="one-time-code"
                  maxLength={6}
                  value={code}
                  onChange={(e) => setCode(e.target.value.replace(/[^0-9]/g, ''))}
                />
              )}
            </div>
            <button className="btn primary" style={{ width: '100%' }} disabled={busy || code.length < 6}>
              {t('verify')}
            </button>
            {step.kind === 'verify' && (
              <p style={{ textAlign: 'center' }}>
                <button type="button" className="btn ghost small" onClick={() => setStep({ kind: 'verify', recovery: !step.recovery })}>
                  {step.recovery ? t('useTotp') : t('useRecovery')}
                </button>
              </p>
            )}
          </form>
        )}
        {step.kind === 'codes' && (
          <div>
            <h1>{t('recoveryTitle')}</h1>
            <p className="muted small">{t('recoverySubtitle')}</p>
            <div className="codes" data-testid="recovery-codes">
              {step.codes.map((c) => (
                <code key={c} className="mono">
                  {c}
                </code>
              ))}
            </div>
            <div className="row" style={{ justifyContent: 'space-between' }}>
              <button
                type="button"
                className="btn"
                onClick={() => {
                  void navigator.clipboard?.writeText(step.codes.join('\n')).then(() => setCopied(true), () => undefined);
                }}
              >
                {copied ? t('copied') : t('copy')}
              </button>
              <button type="button" className="btn primary" onClick={() => onSignedIn(step.session)}>
                {t('recoverySaved')}
              </button>
            </div>
          </div>
        )}
        <div className="auth-tools">{tools}</div>
      </div>
    </main>
  );
}
