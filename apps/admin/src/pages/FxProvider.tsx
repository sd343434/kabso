import { useState } from 'react';
import { api } from '../api';
import { codeField, ErrorAlert, FormDialog, reasonField, useAsync } from '../components';
import { useApp } from '../context';
import { formatDate } from '../format';
import { isKey, type Key } from '../i18n';
import type { FxPaidProvider, FxSettings, FxTestReport } from '../types';

/**
 * «مزوّد أسعار الصرف» (v1.81-social, D245, CONVENTIONS §10.87.4; OWNER only) — D196 / D222 / D227's pattern: the paid
 * provider and its API key, write-only (the page sends it and from then on sees only the last 4 characters, who and
 * when); «اختبار الاتصال»; every change asks for the authenticator code and a reason; «تفعيل» tests again first.
 */
export function FxProviderSection({ onChanged }: { onChanged: () => void }) {
  const { data, error } = useAsync(() => api.get<FxSettings>('/admin/fx-settings'), []);
  const [current, setCurrent] = useState<FxSettings | null>(null);
  const shown = current ?? data;
  if (!shown) return <ErrorAlert error={error} />;
  return (
    <FxProviderView
      data={shown}
      onChange={(next) => {
        setCurrent(next);
        onChanged();
      }}
    />
  );
}

const isolate = (text: string) => `⁨${text}⁩`;

const STATUS: Record<FxSettings['status'], { badge: string; key: Key }> = {
  active: { badge: 'ok', key: 'fxpStatusActive' },
  off: { badge: 'warn', key: 'fxpStatusOff' },
  not_configured: { badge: '', key: 'fxpStatusNotConfigured' },
};

/** What the save sends: the provider when changed, the key only when typed. */
export function fxPatch(provider: FxPaidProvider, apiKey: string, data: FxSettings): { provider?: FxPaidProvider; apiKey?: string } {
  const out: { provider?: FxPaidProvider; apiKey?: string } = {};
  if (provider !== data.provider) out.provider = provider;
  if (apiKey.trim()) out.apiKey = apiKey.trim();
  return out;
}

type Pending = { kind: 'save'; body: ReturnType<typeof fxPatch> } | { kind: 'enable'; on: boolean } | { kind: 'clear' } | null;

export function FxProviderView({ data, onChange }: { data: FxSettings; onChange: (next: FxSettings) => void }) {
  const { t, lang, toast } = useApp();
  const [provider, setProvider] = useState<FxPaidProvider>(data.provider);
  const [apiKey, setApiKey] = useState('');
  const [report, setReport] = useState<FxTestReport | null>(null);
  const [testError, setTestError] = useState<unknown>(null);
  const [testing, setTesting] = useState(false);
  const [pending, setPending] = useState<Pending>(null);
  const [info, setInfo] = useState<string | null>(null);
  const status = STATUS[data.status];
  const issue = (code: string | null) => {
    const key = `fxrIssue_${code ?? ''}`;
    return isKey(key) ? t(key) : (code ?? '');
  };
  const applied = (next: FxSettings) => {
    onChange(next);
    setApiKey('');
    setProvider(next.provider);
    setPending(null);
    toast(t('saved'));
  };
  const shownReport = report ?? (data.lastTest && !data.lastTest.ok ? data.lastTest : null);
  return (
    <section className="card" style={{ marginTop: 16 }} aria-labelledby="fxp-title" data-testid="fxp-section">
      <div className="row" style={{ justifyContent: 'space-between', flexWrap: 'wrap', gap: 8 }}>
        <h2 id="fxp-title" style={{ margin: 0 }}>
          {t('fxpTitle')}
        </h2>
        <span className={`badge ${status.badge}`} data-testid="fxp-status">
          {t(status.key, { seconds: data.paidIntervalSeconds })}
        </span>
      </div>
      <p className="muted small">{t('fxpIntro', { seconds: data.paidIntervalSeconds })}</p>
      {data.panelIgnored && (
        <div className="alert error small" role="alert">
          {t('fxrPaidIgnored')}
        </div>
      )}
      <form
        autoComplete="off"
        onSubmit={(e) => {
          e.preventDefault();
          const body = fxPatch(provider, apiKey, data);
          if (Object.keys(body).length === 0) return setInfo(t('stNothing'));
          setInfo(null);
          setPending({ kind: 'save', body });
        }}
      >
        <div className="grid cols-2" style={{ alignItems: 'start' }}>
          <fieldset className="plain">
            <legend className="small">{t('fxpProvider')}</legend>
            {data.providers.map((p) => (
              <label key={p.code} className="switch-row">
                <input
                  type="radio"
                  name="fxp-provider"
                  value={p.code}
                  checked={provider === p.code}
                  onChange={() => {
                    setProvider(p.code);
                    setReport(null);
                  }}
                />
                <span>
                  <bdi>{p.name}</bdi>{' '}
                  <span className="small muted">
                    {p.signupUrl && (
                      <a href={p.signupUrl} target="_blank" rel="noreferrer noopener">
                        {t('fxpSignup')}
                      </a>
                    )}{' '}
                    ·{' '}
                    <a href={p.docsUrl} target="_blank" rel="noreferrer noopener">
                      {t('fxpDocs')}
                    </a>
                  </span>
                </span>
              </label>
            ))}
            <p className="small muted">{t('fxpGuide')}</p>
          </fieldset>
          <fieldset className="plain">
            <div className="field">
              <label htmlFor="fxp-key">{t('fxpApiKey')}</label>
              <input
                id="fxp-key"
                type="password"
                className="ltr mono"
                autoComplete="off"
                spellCheck={false}
                maxLength={128}
                value={apiKey}
                onChange={(e) => {
                  setApiKey(e.target.value);
                  setReport(null);
                }}
                data-testid="fxp-key"
              />
              <p className="small muted">{t('fxpKeyHint')}</p>
              <p className="small muted" data-testid="fxp-key-saved">
                {data.apiKey
                  ? t('stSaved', {
                      last4: isolate(data.apiKey.last4),
                      name: isolate(data.apiKey.setBy?.displayName || '—'),
                      time: data.apiKey.setAt ? formatDate(data.apiKey.setAt, lang) : '—',
                    })
                  : t('stNotSaved')}
              </p>
            </div>
            <dl className="kv small">
              <dt>{t('stLastTest')}</dt>
              <dd data-testid="fxp-last-test">
                {data.lastTest
                  ? t(data.lastTest.ok ? 'stLastTestOk' : 'stLastTestFailed', {
                      time: formatDate(data.lastTest.at, lang),
                      name: isolate(data.lastTest.by?.displayName || '—'),
                    })
                  : t('stLastTestNone')}
              </dd>
            </dl>
          </fieldset>
        </div>
        {shownReport && (
          <div className={`alert ${shownReport.ok ? 'success' : 'error'} small`} role="status" data-testid="fxp-result">
            {shownReport.ok ? t('fxpTestOk', { n: shownReport.currencies }) : t('fxpTestFailed', { issue: issue(shownReport.issue) })}{' '}
            <span className="muted ltr">
              …{shownReport.apiKeyLast4} · {shownReport.ms} ms
            </span>
          </div>
        )}
        <ErrorAlert error={testError} />
        {info && <p className="small muted">{info}</p>}
        <div className="row" style={{ justifyContent: 'space-between', flexWrap: 'wrap', gap: 8 }}>
          <div className="row" style={{ gap: 8, flexWrap: 'wrap' }}>
            <button
              type="button"
              className="btn"
              disabled={testing || (!apiKey.trim() && !data.apiKey)}
              data-testid="fxp-test"
              onClick={() => {
                setTesting(true);
                setReport(null);
                setTestError(null);
                api
                  .post<FxTestReport>('/admin/fx-settings/test', { provider, ...(apiKey.trim() ? { apiKey: apiKey.trim() } : {}) })
                  .then(
                    (r) => {
                      setTesting(false);
                      setReport(r);
                    },
                    (err: unknown) => {
                      setTesting(false);
                      setTestError(err);
                    },
                  );
              }}
            >
              {t(testing ? 'stTesting' : 'stTest')}
            </button>
            <button className="btn primary" data-testid="fxp-save">
              {t('stSave')}
            </button>
            <label className="switch-row" style={{ margin: 0 }}>
              <input
                type="checkbox"
                role="switch"
                aria-checked={data.enabled}
                checked={data.enabled}
                disabled={!data.enabled && !data.apiKey}
                onChange={(e) => setPending({ kind: 'enable', on: e.target.checked })}
                data-testid="fxp-enable"
              />
              <span>{t('stEnable')}</span>
            </label>
          </div>
          {data.apiKey && (
            <button type="button" className="btn danger" onClick={() => setPending({ kind: 'clear' })}>
              {t('fxpClear')}
            </button>
          )}
        </div>
      </form>
      {pending?.kind === 'save' && (
        <FormDialog
          title={t('stConfirmTitle')}
          intro={<p className="small">{t('fxpConfirmIntro')}</p>}
          fields={[reasonField(t), codeField(t)]}
          confirmLabel={t('save')}
          submit={async (v) => applied(await api.patch<FxSettings>('/admin/fx-settings', { ...pending.body, reason: v.reason, totpCode: v.totpCode }))}
          onClose={() => setPending(null)}
          onDone={() => setPending(null)}
        />
      )}
      {pending?.kind === 'enable' && (
        <FormDialog
          title={t(pending.on ? 'fxpEnableOn' : 'fxpEnableOff')}
          intro={<p className="small">{t(pending.on ? 'fxpEnableIntro' : 'fxpDisableIntro')}</p>}
          fields={[reasonField(t), codeField(t)]}
          confirmLabel={t(pending.on ? 'fxpEnableOn' : 'fxpEnableOff')}
          danger={!pending.on}
          submit={async (v) => applied(await api.patch<FxSettings>('/admin/fx-settings', { enabled: pending.on, reason: v.reason, totpCode: v.totpCode }))}
          onClose={() => setPending(null)}
          onDone={() => setPending(null)}
        />
      )}
      {pending?.kind === 'clear' && (
        <FormDialog
          title={t('fxpClear')}
          intro={<p className="small">{t('fxpClearHint')}</p>}
          fields={[reasonField(t), codeField(t)]}
          confirmLabel={t('stClearConfirm')}
          danger
          submit={async (v) => applied(await api.post<FxSettings>('/admin/fx-settings/clear', { reason: v.reason, totpCode: v.totpCode }))}
          onClose={() => setPending(null)}
          onDone={() => setPending(null)}
        />
      )}
    </section>
  );
}
