import { useCallback, useEffect, useRef, useState, type ReactNode } from 'react';
import { useApp } from './context';
import { errorKey, serverMessage } from './errors';
import { isKey } from './i18n';
import type { PageInfo } from './types';

export function ErrorAlert({ error }: { error: unknown }) {
  const { t } = useApp();
  if (!error) return null;
  const own = serverMessage(error);
  const { key, vars } = errorKey(error);
  return (
    <div className="alert error" role="alert">
      {own ?? t(key, vars)}
    </div>
  );
}

/** Loads `load()` and reloads when `deps` change; `reload()` after a change. */
export function useAsync<T>(load: () => Promise<T>, deps: readonly unknown[]) {
  const [data, setData] = useState<T | null>(null);
  const [error, setError] = useState<unknown>(null);
  const [loading, setLoading] = useState(true);
  const seq = useRef(0);
  const run = useCallback(() => {
    const mine = ++seq.current;
    setLoading(true);
    setError(null);
    load().then(
      (d) => {
        if (mine === seq.current) {
          setData(d);
          setLoading(false);
        }
      },
      (e: unknown) => {
        if (mine === seq.current) {
          setError(e);
          setLoading(false);
        }
      },
    );
  }, deps);
  useEffect(run, [run]);
  return { data, error, loading, reload: run };
}

export function Loading() {
  const { t } = useApp();
  return <p className="muted">{t('loading')}</p>;
}

/** Cursor pages: a stack of the cursors that led to each page. */
export function useCursorPages(resetKey: string) {
  const [stack, setStack] = useState<(string | undefined)[]>([undefined]);
  useEffect(() => setStack([undefined]), [resetKey]);
  const cursor = stack[stack.length - 1];
  return {
    cursor,
    index: stack.length - 1,
    next: (page: PageInfo) => page.nextCursor && setStack((s) => [...s, page.nextCursor ?? undefined]),
    prev: () => setStack((s) => (s.length > 1 ? s.slice(0, -1) : s)),
  };
}

export function Pager({ page, index, onNext, onPrev }: { page: PageInfo | undefined; index: number; onNext: () => void; onPrev: () => void }) {
  const { t } = useApp();
  if (!page || (index === 0 && !page.hasMore)) return null;
  return (
    <div className="pager">
      <button className="btn small" disabled={index === 0} onClick={onPrev}>
        {t('previous')}
      </button>
      <button className="btn small" disabled={!page.hasMore} onClick={onNext}>
        {t('next')}
      </button>
    </div>
  );
}

const TONES: Record<string, string> = {
  ACTIVE: 'ok',
  APPROVED: 'ok',
  PAID: 'ok',
  ACTIONED: 'ok',
  SUSPENDED: 'bad',
  DELETED: 'bad',
  REJECTED: 'bad',
  PENDING: 'warn',
  OPEN: 'warn',
  DISMISSED: '',
};

export function StatusBadge({ status }: { status: string }) {
  const { t } = useApp();
  const key = `status${status}`;
  const label = isKey(key) ? t(key) : status;
  return <span className={`badge ${TONES[status] ?? ''}`}>{label}</span>;
}

export function Avatar({ url, name, large }: { url: string | null; name: string; large?: boolean }) {
  const [broken, setBroken] = useState(false);
  const cls = `avatar${large ? ' lg' : ''}`;
  if (url && !broken) return <img className={cls} src={url} alt="" onError={() => setBroken(true)} />;
  return (
    <span className={cls} aria-hidden="true">
      {(name.trim()[0] ?? '?').toUpperCase()}
    </span>
  );
}

export function UserCell({ username, displayName, avatarUrl }: { username: string; displayName: string; avatarUrl?: string | null }) {
  return (
    <span className="user-cell">
      <Avatar url={avatarUrl ?? null} name={displayName || username} />
      <span className="names">
        <span>{displayName}</span>
        <span className="ltr">@{username}</span>
      </span>
    </span>
  );
}

export function Dialog({ title, children, onClose }: { title: string; children: ReactNode; onClose: () => void }) {
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => e.key === 'Escape' && onClose();
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [onClose]);
  return (
    <div className="scrim" onMouseDown={(e) => e.target === e.currentTarget && onClose()}>
      <div className="dialog" role="dialog" aria-modal="true" aria-label={title}>
        <h2>{title}</h2>
        {children}
      </div>
    </div>
  );
}

export interface FieldSpec {
  name: string;
  label: string;
  kind?: 'text' | 'textarea' | 'code';
  required?: boolean;
  hint?: string;
  maxLength?: number;
}

/**
 * A confirm dialog with a few text fields (a reason, a reference, the authenticator code …). `submit` gets the
 * values; its error stays in the dialog.
 */
export function FormDialog({
  title,
  intro,
  fields,
  confirmLabel,
  danger,
  submit,
  onClose,
  onDone,
}: {
  title: string;
  intro?: ReactNode;
  fields: FieldSpec[];
  confirmLabel: string;
  danger?: boolean;
  submit: (values: Record<string, string>) => Promise<unknown>;
  onClose: () => void;
  onDone: () => void;
}) {
  const { t } = useApp();
  const [values, setValues] = useState<Record<string, string>>({});
  const [error, setError] = useState<unknown>(null);
  const [busy, setBusy] = useState(false);
  const missing = fields.some((f) => f.required !== false && !(values[f.name] ?? '').trim());
  const go = async () => {
    setBusy(true);
    setError(null);
    try {
      await submit(Object.fromEntries(fields.map((f) => [f.name, (values[f.name] ?? '').trim()])));
      onDone();
    } catch (e) {
      setError(e);
      setBusy(false);
    }
  };
  return (
    <Dialog title={title} onClose={onClose}>
      {intro}
      <ErrorAlert error={error} />
      <form
        onSubmit={(e) => {
          e.preventDefault();
          if (!missing && !busy) void go();
        }}
      >
        {fields.map((f) => (
          <div className="field" key={f.name}>
            <label htmlFor={`f-${f.name}`}>{f.label}</label>
            {f.kind === 'textarea' ? (
              <textarea
                id={`f-${f.name}`}
                maxLength={f.maxLength ?? 500}
                value={values[f.name] ?? ''}
                onChange={(e) => setValues((v) => ({ ...v, [f.name]: e.target.value }))}
              />
            ) : (
              <input
                id={`f-${f.name}`}
                type="text"
                className={f.kind === 'code' ? 'code-input' : undefined}
                inputMode={f.kind === 'code' ? 'numeric' : undefined}
                autoComplete={f.kind === 'code' ? 'one-time-code' : 'off'}
                maxLength={f.kind === 'code' ? 6 : (f.maxLength ?? 500)}
                value={values[f.name] ?? ''}
                onChange={(e) =>
                  setValues((v) => ({
                    ...v,
                    [f.name]: f.kind === 'code' ? e.target.value.replace(/[^0-9]/g, '') : e.target.value,
                  }))
                }
              />
            )}
            {f.hint ? <span className="hint">{f.hint}</span> : null}
          </div>
        ))}
        <div className="actions">
          <button type="button" className="btn" onClick={onClose}>
            {t('cancel')}
          </button>
          <button type="submit" className={`btn ${danger ? 'danger' : 'primary'}`} disabled={missing || busy}>
            {confirmLabel}
          </button>
        </div>
      </form>
    </Dialog>
  );
}

export function reasonField(t: ReturnType<typeof useApp>['t'], label?: string): FieldSpec {
  return { name: 'reason', label: label ?? t('reason'), kind: 'textarea', hint: t('reasonHint') };
}

export function codeField(t: ReturnType<typeof useApp>['t']): FieldSpec {
  return { name: 'totpCode', label: t('totpCode'), kind: 'code', hint: t('totpHint') };
}
