import { useState } from 'react';
import { api } from '../api';
import { codeField, ErrorAlert, FormDialog, Loading, reasonField, useAsync } from '../components';
import { useApp } from '../context';
import { formatDate } from '../format';
import type { Key } from '../i18n';
import type { StorageKeyInfo, StorageProvider, StorageSettings, StorageTestReport, StorageTestStep } from '../types';

/**
 * «التخزين (R2 / S3)» (v1.75-social, D222, CONVENTIONS §10.72; OWNER only) — D196's «الدفع (Stripe)» pattern. The
 * access key id and the secret are write-only: the page sends them and from then on sees only their last 4
 * characters, who set them and when. «اختبار الاتصال» runs a real round trip on both buckets and shows each step;
 * every change asks for the authenticator code and a reason; «تفعيل» tests again before it turns the storage on.
 */
export function Storage() {
  const { data, error, loading } = useAsync(() => api.get<StorageSettings>('/admin/storage-settings'), []);
  const [current, setCurrent] = useState<StorageSettings | null>(null);
  const shown = current ?? data;
  if (loading && !shown) return <Loading />;
  if (!shown) return <ErrorAlert error={error} />;
  return <StorageView data={shown} onChange={setCurrent} />;
}

export interface StorageForm {
  provider: StorageProvider;
  accountId: string;
  endpoint: string;
  region: string;
  forcePathStyle: boolean;
  accessKeyId: string;
  secretAccessKey: string;
  publicBucket: string;
  publicBaseUrl: string;
  privateBucket: string;
}

export function storageFormOf(data: StorageSettings): StorageForm {
  const p = data.panel;
  return {
    provider: p.provider,
    accountId: p.accountId ?? '',
    endpoint: p.provider === 'S3' ? (p.endpoint ?? '') : '',
    region: p.provider === 'S3' ? (p.region ?? '') : '',
    forcePathStyle: p.forcePathStyle,
    accessKeyId: '',
    secretAccessKey: '',
    publicBucket: p.publicBucket ?? '',
    publicBaseUrl: p.publicBaseUrl ?? '',
    privateBucket: p.privateBucket ?? '',
  };
}

type Patch = Partial<{
  provider: StorageProvider;
  accountId: string | null;
  endpoint: string | null;
  region: string | null;
  forcePathStyle: boolean;
  accessKeyId: string;
  secretAccessKey: string;
  publicBucket: string | null;
  publicBaseUrl: string | null;
  privateBucket: string | null;
}>;

/** Only what changed (the PATCH semantics of `updateAdminStorageSettings`); the keys only when typed. */
export function storagePatch(form: StorageForm, data: StorageSettings): Patch {
  const out: Patch = {};
  const p = data.panel;
  const text = (v: string) => v.trim() || null;
  if (form.provider !== p.provider) out.provider = form.provider;
  if (form.provider === 'R2') {
    const id = text(form.accountId)?.toLowerCase() ?? null;
    if (id !== p.accountId) out.accountId = id;
  } else {
    if (text(form.endpoint) !== (p.provider === 'S3' ? p.endpoint : null)) out.endpoint = text(form.endpoint);
    if (text(form.region) !== (p.provider === 'S3' ? p.region : null)) out.region = text(form.region);
    if (form.forcePathStyle !== p.forcePathStyle) out.forcePathStyle = form.forcePathStyle;
  }
  if (form.accessKeyId.trim()) out.accessKeyId = form.accessKeyId.trim();
  if (form.secretAccessKey.trim()) out.secretAccessKey = form.secretAccessKey.trim();
  for (const k of ['publicBucket', 'publicBaseUrl', 'privateBucket'] as const) {
    const v = k === 'publicBaseUrl' ? (text(form[k])?.replace(/\/+$/, '') ?? null) : text(form[k]);
    if (v !== p[k]) out[k] = v;
  }
  return out;
}

/** The body of «اختبار الاتصال»: everything typed (what is left empty comes from the saved settings). */
export function testBody(form: StorageForm): Patch {
  const out: Patch = { provider: form.provider };
  const text = (v: string) => v.trim() || undefined;
  if (form.provider === 'R2') {
    if (text(form.accountId)) out.accountId = form.accountId.trim().toLowerCase();
  } else {
    if (text(form.endpoint)) out.endpoint = form.endpoint.trim();
    if (text(form.region)) out.region = form.region.trim();
    out.forcePathStyle = form.forcePathStyle;
  }
  for (const k of ['accessKeyId', 'secretAccessKey', 'publicBucket', 'publicBaseUrl', 'privateBucket'] as const) {
    const v = text(form[k]);
    if (v) out[k] = v;
  }
  return out;
}

/** A person's name inside a sentence of the other direction keeps its own order (Unicode first-strong isolate). */
const isolate = (text: string) => `\u2068${text}\u2069`;

const STATUS: Record<StorageSettings['status'], { badge: string; key: Key; hint: Key }> = {
  active: { badge: 'ok', key: 'stStatusActive', hint: 'stStatusActiveHint' },
  env: { badge: 'info', key: 'stStatusEnv', hint: 'stStatusEnvHint' },
  off: { badge: 'warn', key: 'stStatusOff', hint: 'stStatusOffHint' },
  not_configured: { badge: 'bad', key: 'stStatusNotConfigured', hint: 'stStatusNotConfiguredHint' },
};

function KeyLine({ info }: { info: StorageKeyInfo | null }) {
  const { t, lang } = useApp();
  if (!info) return <p className="small muted">{t('stNotSaved')}</p>;
  return (
    <p className="small muted" data-testid="st-key-saved">
      {t('stSaved', {
        last4: info.last4,
        name: isolate(info.setBy?.displayName || '—'),
        time: info.setAt ? formatDate(info.setAt, lang) : '—',
      })}
    </p>
  );
}

/** The steps of a test, grouped by bucket, each with its outcome and, when failed, why (in the panel's words). */
export function TestSteps({ report }: { report: StorageTestReport }) {
  const { t } = useApp();
  return (
    <div className="st-steps" data-testid="st-steps">
      {(['public', 'private'] as const).map((bucket) => {
        const steps = report.steps.filter((s) => s.bucket === bucket);
        if (steps.length === 0) return null;
        return (
          <div key={bucket} className="st-steps-group">
            <h3 className="small">
              {t(bucket === 'public' ? 'stBucketPublic' : 'stBucketPrivate')}{' '}
              <span className="mono ltr muted">{bucket === 'public' ? report.target.publicBucket : report.target.privateBucket}</span>
            </h3>
            <ol>
              {steps.map((s) => (
                <StepRow key={s.step} step={s} />
              ))}
            </ol>
          </div>
        );
      })}
    </div>
  );
}

function StepRow({ step }: { step: StorageTestStep }) {
  const { t } = useApp();
  return (
    <li className={step.ok ? 'ok' : 'bad'}>
      <span className={`badge ${step.ok ? 'ok' : 'bad'}`}>{t(step.ok ? 'stStepOk' : 'stStepFailed')}</span>{' '}
      {t(`stStep_${step.step}` as Key)} <span className="muted small ltr">{step.ms} ms</span>
      {!step.ok && step.issue && (
        <div className="small">
          {t(`stIssue_${step.issue}` as Key)} {step.detail && <code className="ltr">{step.detail}</code>}
        </div>
      )}
    </li>
  );
}

type Pending = { kind: 'save'; body: Patch } | { kind: 'enable'; on: boolean } | { kind: 'clear' } | null;

export function StorageView({ data, onChange }: { data: StorageSettings; onChange: (next: StorageSettings) => void }) {
  const { t, lang, toast } = useApp();
  const [form, setForm] = useState<StorageForm>(() => storageFormOf(data));
  const [report, setReport] = useState<StorageTestReport | null>(null);
  const [testError, setTestError] = useState<unknown>(null);
  const [testing, setTesting] = useState(false);
  const [pending, setPending] = useState<Pending>(null);
  const [info, setInfo] = useState<string | null>(null);
  const status = STATUS[data.status];
  const set = <K extends keyof StorageForm>(k: K, v: StorageForm[K]) => {
    setForm((f) => ({ ...f, [k]: v }));
    setReport(null);
  };
  const applied = (next: StorageSettings) => {
    onChange(next);
    setForm(storageFormOf(next));
    setPending(null);
    toast(t('saved'));
  };
  const refresh = () => {
    void api.get<StorageSettings>('/admin/storage-settings').then(onChange, () => undefined);
  };
  const last = data.lastTest;
  const missing = data.panel.missing.map((f) => t(`stField_${f}` as Key)).join(lang === 'ar' ? '، ' : ', ');
  const derived = form.provider === 'R2' && /^[a-fA-F0-9]{32}$/.test(form.accountId.trim())
    ? `https://${form.accountId.trim().toLowerCase()}.r2.cloudflarestorage.com`
    : null;

  return (
    <>
      <div className="page-head">
        <div>
          <h1>{t('stTitle')}</h1>
          <p className="muted small">{t('stSubtitle')}</p>
        </div>
      </div>

      <div className="grid cols-2" style={{ alignItems: 'start' }}>
        <section className="card" aria-labelledby="st-status">
          <div className="row" style={{ justifyContent: 'space-between' }}>
            <h2 id="st-status" style={{ margin: 0 }}>
              {t('stStatus')}
            </h2>
            <span className={`badge ${status.badge}`} data-testid="st-status">
              {t(status.key)}
            </span>
          </div>
          <p className="muted small">{t(status.hint)}</p>
          {data.panelIgnored && (
            <div className="alert error" role="alert">
              {t('stIgnoredUnreadable')}
            </div>
          )}
          <dl className="kv">
            <dt>{t('stUploads')}</dt>
            <dd>
              <span className={`badge ${data.uploadsEnabled ? 'ok' : 'bad'}`}>{t(data.uploadsEnabled ? 'stUploadsOn' : 'stUploadsOff')}</span>
            </dd>
            <dt>{t('stPublicUrlNow')}</dt>
            <dd className="mono ltr small">{data.publicBaseUrl ?? '—'}</dd>
            <dt>{t('stLastTest')}</dt>
            <dd className="small" data-testid="st-last-test">
              {last
                ? t(last.ok ? 'stLastTestOk' : 'stLastTestFailed', { time: formatDate(last.at, lang), name: isolate(last.by?.displayName || '—') })
                : t('stLastTestNone')}
            </dd>
          </dl>
          {last && !last.ok && !report && <TestSteps report={last} />}
        </section>

        <section className="card" aria-labelledby="st-enable">
          <h2 id="st-enable" style={{ marginTop: 0 }}>
            {t('stEnable')}
          </h2>
          <p className="muted small">{t('stEnableHint')}</p>
          {data.panel.missing.length > 0 && !data.enabled && <div className="alert warn small">{t('stMissing', { fields: missing })}</div>}
          <label className="switch-row">
            <input
              type="checkbox"
              role="switch"
              aria-checked={data.enabled}
              checked={data.enabled}
              disabled={!data.enabled && data.panel.missing.length > 0}
              onChange={(e) => setPending({ kind: 'enable', on: e.target.checked })}
              data-testid="st-enable"
            />
            <span>{t(data.enabled ? 'stStatusActive' : 'stStatusOff')}</span>
          </label>
        </section>
      </div>

      <form
        className="card"
        style={{ marginTop: 16 }}
        aria-labelledby="st-connection"
        autoComplete="off"
        onSubmit={(e) => {
          e.preventDefault();
          const body = storagePatch(form, data);
          if (Object.keys(body).length === 0) return setInfo(t('stNothing'));
          setInfo(null);
          setPending({ kind: 'save', body });
        }}
      >
        <h2 id="st-connection" style={{ marginTop: 0 }}>
          {t('stConnection')}
        </h2>
        <div className="grid cols-2" style={{ alignItems: 'start' }}>
          <fieldset className="plain">
            <div className="field">
              <label htmlFor="st-provider">{t('stProvider')}</label>
              <select id="st-provider" value={form.provider} onChange={(e) => set('provider', e.target.value as StorageProvider)}>
                <option value="R2">{t('stProviderR2')}</option>
                <option value="S3">{t('stProviderS3')}</option>
              </select>
            </div>
            {form.provider === 'R2' ? (
              <div className="field">
                <label htmlFor="st-account">{t('stAccountId')}</label>
                <input
                  id="st-account"
                  type="text"
                  className="ltr mono"
                  maxLength={32}
                  spellCheck={false}
                  value={form.accountId}
                  placeholder="0123456789abcdef0123456789abcdef"
                  onChange={(e) => set('accountId', e.target.value.trim())}
                />
                <p className="small muted">{derived ? <span className="ltr mono">{t('stEndpointDerived', { url: derived })}</span> : t('stAccountIdHint')}</p>
              </div>
            ) : (
              <>
                <div className="field">
                  <label htmlFor="st-endpoint">{t('stEndpoint')}</label>
                  <input id="st-endpoint" type="text" className="ltr mono" maxLength={300} spellCheck={false} value={form.endpoint} placeholder="https://s3.eu-central-1.amazonaws.com" onChange={(e) => set('endpoint', e.target.value)} />
                </div>
                <div className="field">
                  <label htmlFor="st-region">{t('stRegion')}</label>
                  <input id="st-region" type="text" className="ltr mono" maxLength={64} spellCheck={false} value={form.region} placeholder="us-east-1" onChange={(e) => set('region', e.target.value)} />
                </div>
                <label className="check field">
                  <input type="checkbox" checked={form.forcePathStyle} onChange={(e) => set('forcePathStyle', e.target.checked)} />
                  {t('stPathStyle')}
                </label>
              </>
            )}
            <h3 className="small" style={{ marginBottom: 4 }}>
              {t('stKeys')}
            </h3>
            <p className="small muted" style={{ marginTop: 0 }}>
              {t('stKeysHint')}
            </p>
            <div className="field">
              <label htmlFor="st-akid">{t('stAccessKeyId')}</label>
              <input id="st-akid" type="password" className="ltr mono" autoComplete="off" spellCheck={false} maxLength={128} value={form.accessKeyId} onChange={(e) => set('accessKeyId', e.target.value)} />
              <KeyLine info={data.panel.accessKeyId} />
            </div>
            <div className="field">
              <label htmlFor="st-secret">{t('stSecretAccessKey')}</label>
              <input id="st-secret" type="password" className="ltr mono" autoComplete="off" spellCheck={false} maxLength={256} value={form.secretAccessKey} onChange={(e) => set('secretAccessKey', e.target.value)} />
              <KeyLine info={data.panel.secretAccessKey} />
            </div>
          </fieldset>
          <fieldset className="plain">
            <h3 className="small" style={{ marginTop: 0 }}>
              {t('stBuckets')}
            </h3>
            <div className="field">
              <label htmlFor="st-pub">{t('stPublicBucket')}</label>
              <input id="st-pub" type="text" className="ltr mono" maxLength={63} spellCheck={false} value={form.publicBucket} placeholder="kabso-media" onChange={(e) => set('publicBucket', e.target.value.trim().toLowerCase())} />
              <p className="small muted">{t('stPublicBucketHint')}</p>
            </div>
            <div className="field">
              <label htmlFor="st-base">{t('stPublicBaseUrl')}</label>
              <input id="st-base" type="text" className="ltr mono" maxLength={300} spellCheck={false} value={form.publicBaseUrl} placeholder="https://media.kabsolive.com" onChange={(e) => set('publicBaseUrl', e.target.value.trim())} />
              <p className="small muted">{t('stPublicBaseUrlHint')}</p>
            </div>
            <div className="field">
              <label htmlFor="st-priv">{t('stPrivateBucket')}</label>
              <input id="st-priv" type="text" className="ltr mono" maxLength={63} spellCheck={false} value={form.privateBucket} placeholder="kabso-private" onChange={(e) => set('privateBucket', e.target.value.trim().toLowerCase())} />
              <p className="small muted">{t('stPrivateBucketHint')}</p>
            </div>
          </fieldset>
        </div>

        {report && (
          <div className={`alert ${report.ok ? 'success' : 'error'}`} role="status" data-testid="st-result">
            {t(report.ok ? 'stResultOk' : 'stResultFailed')}
          </div>
        )}
        {report && <TestSteps report={report} />}
        <ErrorAlert error={testError} />
        {info && <p className="small muted">{info}</p>}
        <div className="row" style={{ justifyContent: 'space-between', flexWrap: 'wrap', gap: 8 }}>
          <div className="row" style={{ gap: 8 }}>
            <button
              type="button"
              className="btn"
              disabled={testing}
              data-testid="st-test"
              onClick={() => {
                setTesting(true);
                setReport(null);
                setTestError(null);
                api.post<StorageTestReport>('/admin/storage-settings/test', testBody(form)).then(
                  (r) => {
                    setTesting(false);
                    setReport(r);
                    refresh();
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
            <button className="btn primary" data-testid="st-save">
              {t('stSave')}
            </button>
          </div>
          {(data.panel.accessKeyId || data.panel.publicBucket || data.panel.privateBucket) && (
            <button type="button" className="btn danger" onClick={() => setPending({ kind: 'clear' })}>
              {t('stClear')}
            </button>
          )}
        </div>
      </form>

      <div className="grid cols-2" style={{ marginTop: 16, alignItems: 'start' }}>
        <section className="card" aria-labelledby="st-server">
          <h2 id="st-server" style={{ marginTop: 0 }}>
            {t('stServer')}
          </h2>
          <p className="muted small">{t('stServerHint')}</p>
          {data.env.configured ? (
            <dl className="kv">
              <dt>{t('stServerBucket')}</dt>
              <dd className="mono ltr small">{data.env.bucket}</dd>
              <dt>{t('stEndpoint')}</dt>
              <dd className="mono ltr small">{data.env.endpoint ?? '—'}</dd>
              <dt>{t('stAccessKeyId')}</dt>
              <dd className="mono ltr small">…{data.env.accessKeyIdLast4}</dd>
              <dt>{t('stPublicBaseUrl')}</dt>
              <dd className="mono ltr small">{data.env.publicBaseUrl ?? '—'}</dd>
              <dt>{t('stServerUploads')}</dt>
              <dd>
                <span className={`badge ${data.env.uploadsEnabled ? 'ok' : 'bad'}`}>{t(data.env.uploadsEnabled ? 'stUploadsOn' : 'stUploadsOff')}</span>
              </dd>
            </dl>
          ) : (
            <p className="small">{t('stServerNone')}</p>
          )}
        </section>
        <section className="card" aria-labelledby="st-guide">
          <h2 id="st-guide" style={{ marginTop: 0 }}>
            {t('stGuide')}
          </h2>
          <ol className="small st-guide">
            {(['stGuide1', 'stGuide2', 'stGuide3', 'stGuide4', 'stGuide5'] as const).map((k) => (
              <li key={k}>{t(k)}</li>
            ))}
          </ol>
          <p className="small muted">{t('stGuideCors')}</p>
        </section>
      </div>

      {pending?.kind === 'save' && (
        <FormDialog
          title={t('stConfirmTitle')}
          intro={<p className="small">{t('stConfirmIntro')}</p>}
          fields={[reasonField(t), codeField(t)]}
          confirmLabel={t('save')}
          submit={async (v) => {
            try {
              applied(await api.patch<StorageSettings>('/admin/storage-settings', { ...pending.body, reason: v.reason, totpCode: v.totpCode }));
            } finally {
              refresh();
            }
          }}
          onClose={() => setPending(null)}
          onDone={() => setPending(null)}
        />
      )}
      {pending?.kind === 'enable' && (
        <FormDialog
          title={t(pending.on ? 'stEnableOn' : 'stEnableOff')}
          intro={<p className="small">{t(pending.on ? 'stEnableIntro' : 'stDisableIntro')}</p>}
          fields={[reasonField(t), codeField(t)]}
          confirmLabel={t(pending.on ? 'stEnableOn' : 'stEnableOff')}
          danger={!pending.on}
          submit={async (v) => {
            try {
              applied(await api.patch<StorageSettings>('/admin/storage-settings', { enabled: pending.on, reason: v.reason, totpCode: v.totpCode }));
            } finally {
              refresh();
            }
          }}
          onClose={() => setPending(null)}
          onDone={() => setPending(null)}
        />
      )}
      {pending?.kind === 'clear' && (
        <FormDialog
          title={t('stClear')}
          intro={<p className="small">{t('stClearHint')}</p>}
          fields={[reasonField(t), codeField(t)]}
          confirmLabel={t('stClearConfirm')}
          danger
          submit={async (v) => applied(await api.post<StorageSettings>('/admin/storage-settings/clear', { reason: v.reason, totpCode: v.totpCode }))}
          onClose={() => setPending(null)}
          onDone={() => setPending(null)}
        />
      )}
    </>
  );
}
