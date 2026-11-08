import { useState, type FormEvent, type ReactNode } from 'react';
import { api, setCsrfToken } from '../api';
import kabiArt from '../assets/kabi_win.png';
import kabsoLogo from '../assets/kabso_logo.webp';
import { ErrorAlert } from '../components';
import { useApp } from '../context';
import { QrCode } from '../qr';
import type { AdminLoginResponse, AdminSessionInfo } from '../types';
import { Icon } from '../ui/icons';

export type LoginStep =
  | { kind: 'password' }
  | { kind: 'verify'; recovery: boolean }
  | { kind: 'enrol'; secret: string; uri: string }
  | { kind: 'codes'; codes: string[]; session: AdminSessionInfo };

type Step = LoginStep;

/**
 * D249 / D249b: the full-screen split every step of the sign-in shares (no page background around it) — the form
 * half on the reading-start side (right in Arabic) with the owner's logo (Kabi face mark,
 * `infra/deploy/site/assets/logo.webp`, 127×160, shown at most 76 px high), the Kabi panel with the slogan edge to
 * edge on the end side, a short banner on top below 820 px. Kabi is the owner's own art
 * (`apps/mobile/assets/pk/score_bar/kabi/kabi_win.png`, the kabso_pk_powers pack); nothing from the owner's
 * third-party style reference is used. Strict CSP: no external font, image or script.
 */
export function AuthShell({ children, tools }: { children: ReactNode; tools: ReactNode }) {
  const { t } = useApp();
  return (
    <main className="auth">
      <div className="auth-card" data-testid="auth-card">
        <section className="auth-form">
          <div className="auth-inner">
            <div className="brand auth-brand">
              <img className="auth-logo" src={kabsoLogo} alt="" width={127} height={160} decoding="async" />
              <span>{t('appName')}</span>
            </div>
            {children}
          </div>
          <div className="auth-tools">{tools}</div>
        </section>
        <aside className="auth-art">
          <span className="art-cloud a1" aria-hidden="true" />
          <span className="art-cloud a2" aria-hidden="true" />
          <span className="art-cloud a3" aria-hidden="true" />
          <span className="art-halo" aria-hidden="true" />
          <img className="art-kabi" src={kabiArt} alt="" width={512} height={489} decoding="async" />
          <div className="art-copy">
            <p className="auth-slogan">
              <span>{t('loginSlogan1')}</span>
              <span>{t('loginSlogan2')}</span>
            </p>
            <p className="art-caption">{t('loginPanelCaption')}</p>
          </div>
        </aside>
      </div>
    </main>
  );
}

/**
 * Sign-in: email (or the staff ID «Kabso01», D302) and password, then the second factor — the QR enrolment on the first sign-in (with the ten
 * recovery codes shown once), or an authenticator code / a recovery code later (CONVENTIONS §10.54.2).
 * `initialStep` exists for the unit tests of each step's shell; the app always starts at the password.
 */
export function Login({
  onSignedIn,
  tools,
  initialStep = { kind: 'password' },
}: {
  onSignedIn: (s: AdminSessionInfo) => void;
  tools: ReactNode;
  initialStep?: Step;
}) {
  const { t } = useApp();
  const [step, setStep] = useState<Step>(initialStep);
  const [showPassword, setShowPassword] = useState(false);
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
      setShowPassword(false);
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
    <AuthShell tools={tools}>
      {step.kind === 'password' && (
        <form onSubmit={submitPassword}>
          <h1>{t('loginWelcome')}</h1>
          <p className="muted small auth-sub">{t('loginSubtitle')}</p>
          <ErrorAlert error={error} />
          <div className="field">
            {/* D302: the email or the staff ID («Kabso01»), sent in the same `email` field. */}
            <label htmlFor="email">{t('loginIdentifier')}</label>
            <input id="email" type="text" inputMode="email" className="ltr" autoComplete="username" autoCapitalize="none" spellCheck={false} required value={email} onChange={(e) => setEmail(e.target.value)} />
          </div>
          <div className="field">
            <label htmlFor="password">{t('password')}</label>
            <div className="pw-wrap">
              <input
                id="password"
                type={showPassword ? 'text' : 'password'}
                className="ltr"
                autoComplete="current-password"
                required
                value={password}
                onChange={(e) => setPassword(e.target.value)}
              />
              <button
                type="button"
                className="pw-toggle"
                aria-controls="password"
                aria-pressed={showPassword}
                aria-label={showPassword ? t('passwordHide') : t('passwordShow')}
                title={showPassword ? t('passwordHide') : t('passwordShow')}
                onClick={() => setShowPassword((v) => !v)}
              >
                <Icon name={showPassword ? 'eyeOff' : 'eye'} size={18} />
              </button>
            </div>
          </div>
          <button className="btn primary auth-submit" disabled={busy || !email || !password}>
            {t('signIn')}
          </button>
        </form>
      )}
      {(step.kind === 'verify' || step.kind === 'enrol') && (
        <form onSubmit={submitCode}>
          <h1>{step.kind === 'enrol' ? t('enrolTitle') : t('verifyTitle')}</h1>
          <p className="muted small auth-sub">{step.kind === 'enrol' ? t('enrolSubtitle') : t('verifySubtitle')}</p>
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
          <button className="btn primary auth-submit" disabled={busy || code.length < 6}>
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
          <p className="muted small auth-sub">{t('recoverySubtitle')}</p>
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
    </AuthShell>
  );
}
