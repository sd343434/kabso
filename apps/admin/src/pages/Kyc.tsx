import { useState } from 'react';
import { api } from '../api';
import { codeField, ErrorAlert, FormDialog, Loading, reasonField, useAsync } from '../components';
import { useApp } from '../context';
import { formatDate } from '../format';
import { isKey, type Key } from '../i18n';
import { navigate } from '../router';
import type { AdminKycCheck, AdminKycMedia, AdminKycSummary, KycKeyInfo, KycSettings, KycStatus, KycTestReport, KycWorkflowField } from '../types';

/**
 * «التحقق من الهوية (Didit)» (v1.80-kyc, D227, CONVENTIONS §10.77; OWNER only) — D196 / D222's pattern. The API key and
 * the webhook secret are write-only: the page sends them and from then on sees only their last 4 characters, who set
 * them and when. «اختبار الاتصال» checks the key and each workflow at Didit; every change asks for the authenticator
 * code and a reason; «تفعيل» tests again before it turns Didit on. Also `KycBlock`: the identity check shown on the
 * three application pages (capability `kyc.view` for the personal fields and the images).
 */
export function KycSettingsPage() {
  const { data, error, loading } = useAsync(() => api.get<KycSettings>('/admin/kyc-settings'), []);
  const [current, setCurrent] = useState<KycSettings | null>(null);
  const shown = current ?? data;
  if (loading && !shown) return <Loading />;
  if (!shown) return <ErrorAlert error={error} />;
  return <KycSettingsView data={shown} onChange={setCurrent} />;
}

export interface KycForm {
  apiKey: string;
  webhookSecret: string;
  workflowId: string;
  workflowIdHost: string;
  workflowIdAgency: string;
  workflowIdRecharge: string;
  maxSessionsPerDay: number;
}

const WORKFLOWS: KycWorkflowField[] = ['workflowId', 'workflowIdHost', 'workflowIdAgency', 'workflowIdRecharge'];

export function kycFormOf(data: KycSettings): KycForm {
  return {
    apiKey: '',
    webhookSecret: '',
    workflowId: data.workflowId ?? '',
    workflowIdHost: data.workflowIdHost ?? '',
    workflowIdAgency: data.workflowIdAgency ?? '',
    workflowIdRecharge: data.workflowIdRecharge ?? '',
    maxSessionsPerDay: data.maxSessionsPerDay,
  };
}

type Patch = Partial<Record<KycWorkflowField, string | null> & { apiKey: string; webhookSecret: string; maxSessionsPerDay: number }>;

/** Only what changed (the PATCH semantics of `updateAdminKycSettings`); the secrets only when typed. */
export function kycPatch(form: KycForm, data: KycSettings): Patch {
  const out: Patch = {};
  if (form.apiKey.trim()) out.apiKey = form.apiKey.trim();
  if (form.webhookSecret.trim()) out.webhookSecret = form.webhookSecret.trim();
  for (const k of WORKFLOWS) {
    const v = form[k].trim().toLowerCase() || null;
    if (v !== data[k]) out[k] = v;
  }
  if (form.maxSessionsPerDay !== data.maxSessionsPerDay) out.maxSessionsPerDay = form.maxSessionsPerDay;
  return out;
}

/** The body of «اختبار الاتصال»: the key and workflows typed (what is left empty comes from the saved settings). */
export function kycTestBody(form: KycForm): Patch {
  const out: Patch = {};
  if (form.apiKey.trim()) out.apiKey = form.apiKey.trim();
  for (const k of WORKFLOWS) if (form[k].trim()) out[k] = form[k].trim().toLowerCase();
  return out;
}

/** A person's name inside a sentence of the other direction keeps its own order (Unicode first-strong isolate). */
const isolate = (text: string) => `⁨${text}⁩`;

const STATUS: Record<KycSettings['status'], { badge: string; key: Key; hint: Key }> = {
  active: { badge: 'ok', key: 'kycStatusActive', hint: 'kycStatusActiveHint' },
  off: { badge: 'warn', key: 'kycStatusOff', hint: 'kycStatusOffHint' },
  not_configured: { badge: 'bad', key: 'kycStatusNotConfigured', hint: 'kycStatusNotConfiguredHint' },
};

function KeyLine({ info }: { info: KycKeyInfo | null }) {
  const { t, lang } = useApp();
  if (!info) return <p className="small muted">{t('stNotSaved')}</p>;
  return (
    <p className="small muted" data-testid="kyc-key-saved">
      {t('stSaved', { last4: isolate(info.last4), name: isolate(info.setBy?.displayName || '—'), time: info.setAt ? formatDate(info.setAt, lang) : '—' })}
    </p>
  );
}

export function KycTestResult({ report }: { report: KycTestReport }) {
  const { t } = useApp();
  return (
    <ol className="st-steps small" data-testid="kyc-steps">
      <li className={report.apiKey.ok ? 'ok' : 'bad'}>
        <span className={`badge ${report.apiKey.ok ? 'ok' : 'bad'}`}>{t(report.apiKey.ok ? 'stStepOk' : 'stStepFailed')}</span> {t('kycTestKey')}{' '}
        <span className="muted ltr">{report.apiKey.ms} ms</span>
        {report.apiKey.issue && <div>{t(`kycIssue_${report.apiKey.issue}` as Key)}</div>}
      </li>
      {report.workflows.map((w) => (
        <li key={w.field} className={w.ok ? 'ok' : 'bad'}>
          <span className={`badge ${w.ok ? 'ok' : 'bad'}`}>{t(w.ok ? 'stStepOk' : 'stStepFailed')}</span> {t(`kycField_${w.field}` as Key)}{' '}
          <bdi className="mono muted">{w.label ?? w.workflowId}</bdi>
          {w.features && (
            <div className="muted small">
              <bdi>{w.features}</bdi>
            </div>
          )}
          {w.issue && <div>{t(`kycIssue_${w.issue}` as Key)}</div>}
        </li>
      ))}
    </ol>
  );
}

type Pending = { kind: 'save'; body: Patch } | { kind: 'enable'; on: boolean } | { kind: 'clear' } | null;

export function KycSettingsView({ data, onChange }: { data: KycSettings; onChange: (next: KycSettings) => void }) {
  const { t, lang, toast } = useApp();
  const [form, setForm] = useState<KycForm>(() => kycFormOf(data));
  const [report, setReport] = useState<KycTestReport | null>(null);
  const [testError, setTestError] = useState<unknown>(null);
  const [testing, setTesting] = useState(false);
  const [pending, setPending] = useState<Pending>(null);
  const [info, setInfo] = useState<string | null>(null);
  const status = STATUS[data.status];
  const set = <K extends keyof KycForm>(k: K, v: KycForm[K]) => {
    setForm((f) => ({ ...f, [k]: v }));
    setReport(null);
  };
  const applied = (next: KycSettings) => {
    onChange(next);
    setForm(kycFormOf(next));
    setPending(null);
    toast(t('saved'));
  };
  const refresh = () => {
    void api.get<KycSettings>('/admin/kyc-settings').then(onChange, () => undefined);
  };
  const last = data.lastTest;
  const missing = data.missing.map((f) => t(`kycField_${f}` as Key)).join(lang === 'ar' ? '، ' : ', ');
  return (
    <>
      <div className="page-head">
        <div>
          <h1>{t('kycTitle')}</h1>
          <p className="muted small">{t('kycSubtitle')}</p>
        </div>
      </div>

      <div className="grid cols-2" style={{ alignItems: 'start' }}>
        <section className="card" aria-labelledby="kyc-status">
          <div className="row" style={{ justifyContent: 'space-between' }}>
            <h2 id="kyc-status" style={{ margin: 0 }}>
              {t('stStatus')}
            </h2>
            <span className={`badge ${status.badge}`} data-testid="kyc-status">
              {t(status.key)}
            </span>
          </div>
          <p className="muted small">{t(status.hint)}</p>
          {data.panelIgnored && (
            <div className="alert error" role="alert">
              {t('kycIgnoredUnreadable')}
            </div>
          )}
          <dl className="kv">
            <dt>{t('kycWebhookUrl')}</dt>
            <dd className="small">
              <div className="mono ltr" style={{ wordBreak: 'break-all' }} data-testid="kyc-webhook-url">
                {data.webhookUrl}
              </div>
              <button type="button" className="btn small" style={{ marginTop: 4 }} onClick={() => void navigator.clipboard?.writeText(data.webhookUrl).then(() => toast(t('copied')))}>
                {t('copy')}
              </button>
            </dd>
            <dt>{t('stLastTest')}</dt>
            <dd className="small" data-testid="kyc-last-test">
              {last ? t(last.ok ? 'stLastTestOk' : 'stLastTestFailed', { time: formatDate(last.at, lang), name: isolate(last.by?.displayName || '—') }) : t('stLastTestNone')}
            </dd>
          </dl>
          {last && !last.ok && !report && <KycTestResult report={last} />}
        </section>

        <section className="card" aria-labelledby="kyc-enable">
          <h2 id="kyc-enable" style={{ marginTop: 0 }}>
            {t('stEnable')}
          </h2>
          <p className="muted small">{t('kycEnableHint')}</p>
          {data.missing.length > 0 && !data.enabled && <div className="alert warn small">{t('stMissing', { fields: missing })}</div>}
          <label className="switch-row">
            <input
              type="checkbox"
              role="switch"
              aria-checked={data.enabled}
              checked={data.enabled}
              disabled={!data.enabled && data.missing.length > 0}
              onChange={(e) => setPending({ kind: 'enable', on: e.target.checked })}
              data-testid="kyc-enable"
            />
            <span>{t(data.enabled ? 'kycStatusActive' : 'kycStatusOff')}</span>
          </label>
        </section>
      </div>

      <form
        className="card"
        style={{ marginTop: 16 }}
        aria-labelledby="kyc-connection"
        autoComplete="off"
        onSubmit={(e) => {
          e.preventDefault();
          const body = kycPatch(form, data);
          if (Object.keys(body).length === 0) return setInfo(t('stNothing'));
          setInfo(null);
          setPending({ kind: 'save', body });
        }}
      >
        <h2 id="kyc-connection" style={{ marginTop: 0 }}>
          {t('kycConnection')}
        </h2>
        <div className="grid cols-2" style={{ alignItems: 'start' }}>
          <fieldset className="plain">
            <p className="small muted" style={{ marginTop: 0 }}>
              {t('kycKeysHint')}
            </p>
            <div className="field">
              <label htmlFor="kyc-api-key">{t('kycField_apiKey')}</label>
              <input id="kyc-api-key" type="password" className="ltr mono" autoComplete="off" spellCheck={false} maxLength={256} value={form.apiKey} onChange={(e) => set('apiKey', e.target.value)} />
              <KeyLine info={data.apiKey} />
            </div>
            <div className="field">
              <label htmlFor="kyc-secret">{t('kycField_webhookSecret')}</label>
              <input id="kyc-secret" type="password" className="ltr mono" autoComplete="off" spellCheck={false} maxLength={256} value={form.webhookSecret} onChange={(e) => set('webhookSecret', e.target.value)} />
              <KeyLine info={data.webhookSecret} />
            </div>
            <div className="field">
              <label htmlFor="kyc-max">{t('kycMaxPerDay')}</label>
              <input id="kyc-max" type="number" min={1} max={10} className="ltr" value={form.maxSessionsPerDay} onChange={(e) => set('maxSessionsPerDay', Math.max(1, Math.min(10, Number(e.target.value) || 1)))} />
              <p className="small muted">{t('kycMaxPerDayHint')}</p>
            </div>
          </fieldset>
          <fieldset className="plain">
            {WORKFLOWS.map((k) => (
              <div className="field" key={k}>
                <label htmlFor={`kyc-${k}`}>{t(`kycField_${k}` as Key)}</label>
                <input
                  id={`kyc-${k}`}
                  type="text"
                  className="ltr mono"
                  maxLength={36}
                  spellCheck={false}
                  placeholder="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
                  value={form[k]}
                  onChange={(e) => set(k, e.target.value.trim())}
                />
                {k !== 'workflowId' && <p className="small muted">{t('kycWorkflowOptional')}</p>}
              </div>
            ))}
          </fieldset>
        </div>
        {report && (
          <div className={`alert ${report.ok ? 'success' : 'error'}`} role="status" data-testid="kyc-result">
            {t(report.ok ? 'kycResultOk' : 'kycResultFailed')}
          </div>
        )}
        {report && <KycTestResult report={report} />}
        <ErrorAlert error={testError} />
        {info && <p className="small muted">{info}</p>}
        <div className="row" style={{ justifyContent: 'space-between', flexWrap: 'wrap', gap: 8 }}>
          <div className="row" style={{ gap: 8 }}>
            <button
              type="button"
              className="btn"
              disabled={testing}
              data-testid="kyc-test"
              onClick={() => {
                setTesting(true);
                setReport(null);
                setTestError(null);
                api.post<KycTestReport>('/admin/kyc-settings/test', kycTestBody(form)).then(
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
            <button className="btn primary" data-testid="kyc-save">
              {t('stSave')}
            </button>
          </div>
          {(data.apiKey || data.webhookSecret || data.workflowId) && (
            <button type="button" className="btn danger" onClick={() => setPending({ kind: 'clear' })}>
              {t('kycClear')}
            </button>
          )}
        </div>
      </form>

      <section className="card" style={{ marginTop: 16 }} aria-labelledby="kyc-guide">
        <h2 id="kyc-guide" style={{ marginTop: 0 }}>
          {t('kycGuideTitle')}
        </h2>
        <ol className="small st-guide">
          {(['kycGuide1', 'kycGuide2', 'kycGuide3', 'kycGuide4', 'kycGuide5', 'kycGuide6'] as const).map((k) => (
            <li key={k}>{t(k, { url: data.webhookUrl })}</li>
          ))}
        </ol>
      </section>

      {pending?.kind === 'save' && (
        <FormDialog
          title={t('stConfirmTitle')}
          intro={<p className="small">{t('kycConfirmIntro')}</p>}
          fields={[reasonField(t), codeField(t)]}
          confirmLabel={t('save')}
          submit={async (v) => {
            try {
              applied(await api.patch<KycSettings>('/admin/kyc-settings', { ...pending.body, reason: v.reason, totpCode: v.totpCode }));
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
          title={t(pending.on ? 'kycEnableOn' : 'kycEnableOff')}
          intro={<p className="small">{t(pending.on ? 'kycEnableIntro' : 'kycDisableIntro')}</p>}
          fields={[reasonField(t), codeField(t)]}
          confirmLabel={t(pending.on ? 'kycEnableOn' : 'kycEnableOff')}
          danger={!pending.on}
          submit={async (v) => {
            try {
              applied(await api.patch<KycSettings>('/admin/kyc-settings', { enabled: pending.on, reason: v.reason, totpCode: v.totpCode }));
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
          title={t('kycClear')}
          intro={<p className="small">{t('kycClearHint')}</p>}
          fields={[reasonField(t), codeField(t)]}
          confirmLabel={t('stClearConfirm')}
          danger
          submit={async (v) => applied(await api.post<KycSettings>('/admin/kyc-settings/clear', { reason: v.reason, totpCode: v.totpCode }))}
          onClose={() => setPending(null)}
          onDone={() => setPending(null)}
        />
      )}
    </>
  );
}

// ---- the identity check on an application page ------------------------------------------------------------------

const CHECK_BADGE: Record<KycStatus, string> = {
  APPROVED: 'ok',
  DECLINED: 'bad',
  IN_REVIEW: 'warn',
  IN_PROGRESS: 'info',
  NOT_STARTED: '',
  EXPIRED: '',
  ABANDONED: '',
};

export function KycStatusBadge({ status }: { status: KycStatus }) {
  const { t } = useApp();
  return (
    <span className={`badge ${CHECK_BADGE[status]}`} data-kyc-status={status}>
      {t(`kycCheck_${status}` as Key)}
    </span>
  );
}

/** A known Didit / Kabso reason in words; an unknown code as itself. */
export function reasonText(t: (k: Key) => string, code: string): string {
  const key = `kycReason_${code}`;
  return isKey(key) ? t(key) : code;
}

function CheckFields({ check }: { check: AdminKycCheck }) {
  const { t, lang } = useApp();
  return (
    <dl className="kv">
      <dt>{t('colStatus')}</dt>
      <dd>
        <KycStatusBadge status={check.status} /> <span className="muted small ltr">{check.providerStatus}</span>
      </dd>
      {check.reasons.length > 0 && (
        <>
          <dt>{t('kycReasons')}</dt>
          <dd>
            {check.reasons.map((r) => (
              <div key={r} className="small">
                {reasonText(t, r)}
              </div>
            ))}
          </dd>
        </>
      )}
      <dt>{t('kycFullName')}</dt>
      <dd>{check.fullName ?? '—'}</dd>
      <dt>{t('kycBirth')}</dt>
      <dd>
        <span className="date">{check.dateOfBirth ?? '—'}</span> {check.age !== null && <span className="badge">{t('hostAppAge', { n: check.age })}</span>}
      </dd>
      <dt>{t('kycCountry')}</dt>
      <dd className="mono">{check.documentCountry ?? '—'}</dd>
      <dt>{t('kycSession')}</dt>
      <dd className="small">
        <span className="ltr mono">#{check.sessionNumber ?? '—'}</span> · <span className="date">{formatDate(check.decidedAt ?? check.createdAt, lang)}</span>
      </dd>
    </dl>
  );
}

/** «التحقق من الهوية» on the host, agency and recharge application pages. */
export function KycBlock({ summary }: { summary: AdminKycSummary | undefined }) {
  const { t, can } = useApp();
  const [media, setMedia] = useState<AdminKycMedia | null>(null);
  const [mediaError, setMediaError] = useState<unknown>(null);
  const [loadingMedia, setLoadingMedia] = useState(false);
  if (!summary) return null;
  const check = summary.approved ?? summary.latest;
  return (
    <div className="card" data-kyc-block>
      <div className="row" style={{ justifyContent: 'space-between' }}>
        <h2 style={{ margin: 0 }}>{t('kycBlockTitle')}</h2>
        <span className={`badge ${summary.satisfied ? 'ok' : summary.required ? 'bad' : ''}`} data-kyc-gate>
          {t(summary.satisfied ? 'kycGateOk' : summary.required ? 'kycGateMissing' : 'kycGateOff')}
        </span>
      </div>
      <p className="muted small">{t(summary.required ? 'kycRequiredHint' : 'kycOffHint')}</p>
      {!check ? (
        <p className="small" data-kyc-none>
          {t('kycNone')}
        </p>
      ) : (
        <>
          <CheckFields check={check} />
          {check.duplicateDocument && (
            <div className="alert warn small" data-kyc-duplicate>
              {t('kycDuplicate')}{' '}
              {check.duplicates.map((d) => (
                <a key={d.id} href={`/users/${d.id}`} onClick={(e) => (e.preventDefault(), navigate(`/users/${d.id}`))} className="ltr">
                  @{d.username}{' '}
                </a>
              ))}
            </div>
          )}
          {can('kyc.view') && (
            <div className="row" style={{ gap: 8, flexWrap: 'wrap' }}>
              <button
                type="button"
                className="btn"
                disabled={loadingMedia}
                data-kyc-media
                onClick={() => {
                  setLoadingMedia(true);
                  setMediaError(null);
                  api.post<AdminKycMedia>(`/admin/kyc/checks/${check.id}/media`).then(
                    (m) => {
                      setLoadingMedia(false);
                      setMedia(m);
                    },
                    (e: unknown) => {
                      setLoadingMedia(false);
                      setMediaError(e);
                    },
                  );
                }}
              >
                {t('kycShowImages')}
              </button>
              <a className="btn" href={check.consoleUrl} target="_blank" rel="noreferrer noopener">
                {t('kycOpenConsole')}
              </a>
            </div>
          )}
          <p className="muted small">{t('kycImagesNote')}</p>
          <ErrorAlert error={mediaError} />
          {media && (
            <div className="grid cols-2" data-kyc-images>
              {(['front', 'back', 'portrait', 'liveness'] as const).map((k) =>
                media[k] ? (
                  <figure key={k} className="photo-box">
                    <img src={media[k]} alt={t(`kycImage_${k}` as Key)} referrerPolicy="no-referrer" />
                    <figcaption className="small muted">{t(`kycImage_${k}` as Key)}</figcaption>
                  </figure>
                ) : null,
              )}
            </div>
          )}
        </>
      )}
    </div>
  );
}
