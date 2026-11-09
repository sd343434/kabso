import { useState } from 'react';
import { api } from '../api';
import { codeField, ErrorAlert, FormDialog, Loading, reasonField, useAsync } from '../components';
import { useApp } from '../context';
import { formatDate } from '../format';
import type { Key } from '../i18n';
import type { PaymentKeyCheck, PaymentKeyInfo, PaymentOptions, PaymentSettings } from '../types';

/**
 * «الدفع (Stripe)» (v1.64-social, D196, CONVENTIONS §10.53.1; OWNER only). The secret key and the webhook signing
 * secret are write-only: the page sends them and from then on only sees their type, mode, last 4 characters, who
 * set them and when. Every change asks for the authenticator code and a reason (a dialog); the server tests a new
 * key with Stripe before it saves it.
 */
export function Payments() {
  const { data, error, loading } = useAsync(() => api.get<PaymentSettings>('/admin/payment-settings'), []);
  const [current, setCurrent] = useState<PaymentSettings | null>(null);
  const shown = current ?? data;
  if (loading && !shown) return <Loading />;
  if (!shown) return <ErrorAlert error={error} />;
  return <PaymentsView data={shown} onChange={setCurrent} />;
}

type Tri = 'default' | 'on' | 'off';
const triOf = (v: boolean | null): Tri => (v === null ? 'default' : v ? 'on' : 'off');
const boolOf = (v: Tri): boolean | null => (v === 'default' ? null : v === 'on');

export interface OptionsForm {
  publishableKey: string;
  bankTransferEnabled: Tri;
  /** Left empty: back to the server's value. */
  statementDescriptorSuffix: string;
  disputeAutoSubmit: Tri;
  appLinkEnabled: Tri;
  /** D344: Stripe's fee in the website price. The two texts left empty: back to the server's value. */
  stripeFeeGrossUp: Tri;
  /** Percent, e.g. "2.9". */
  stripeFeePercent: string;
  /** In the currency's units, e.g. "0.30". */
  stripeFeeFixed: string;
}

/** D344: "2.9" → 290 basis points; "" → null (the server's); anything else → undefined (invalid). */
export function percentBpsOf(text: string): number | null | undefined {
  const v = text.trim().replace(',', '.');
  if (v === '') return null;
  if (!/^\d{1,2}(\.\d{1,2})?$/.test(v)) return undefined;
  const bps = Math.round(Number(v) * 100);
  return bps <= 2000 ? bps : undefined;
}

/** D344: "0.30" → 30 minor units; "" → null; anything else → undefined. */
export function fixedMinorOf(text: string): number | null | undefined {
  const v = text.trim().replace(',', '.');
  if (v === '') return null;
  if (!/^\d{1,3}(\.\d{1,2})?$/.test(v)) return undefined;
  const minor = Math.round(Number(v) * 100);
  return minor <= 10_000 ? minor : undefined;
}

const percentText = (bps: number | null) => (bps === null ? '' : String(bps / 100));
const fixedText = (minor: number | null) => (minor === null ? '' : (minor / 100).toFixed(2));

/** D344: the server's formula, for the example only: ceil((base + fixed) / (1 − percent)). */
export function grossUpMinor(baseMinor: number, percentBps: number, fixedMinor: number): number {
  return Math.ceil(((baseMinor + fixedMinor) * 10_000) / (10_000 - percentBps) - 1e-9);
}

/** D344: the typed rates are valid (or empty). */
export function feeFormValid(form: OptionsForm): boolean {
  return percentBpsOf(form.stripeFeePercent) !== undefined && fixedMinorOf(form.stripeFeeFixed) !== undefined;
}

export function optionsFormOf(data: PaymentSettings): OptionsForm {
  return {
    publishableKey: data.publishableKey ?? '',
    bankTransferEnabled: triOf(data.options.bankTransferEnabled),
    statementDescriptorSuffix: data.options.statementDescriptorSuffix ?? '',
    disputeAutoSubmit: triOf(data.options.disputeAutoSubmit),
    appLinkEnabled: triOf(data.options.appLinkEnabled),
    stripeFeeGrossUp: triOf(data.options.stripeFeeGrossUp),
    stripeFeePercent: percentText(data.options.stripeFeePercentBps),
    stripeFeeFixed: fixedText(data.options.stripeFeeFixedMinor),
  };
}

/** Only what changed (the PATCH semantics of `updateAdminPaymentSettings`); empty → nothing to save. */
export function optionsPatch(form: OptionsForm, data: PaymentSettings): Partial<PaymentOptions> & { publishableKey?: string | null } {
  const out: Partial<PaymentOptions> & { publishableKey?: string | null } = {};
  const pk = form.publishableKey.trim() || null;
  if (pk !== data.publishableKey) out.publishableKey = pk;
  const suffix = form.statementDescriptorSuffix.trim() || null;
  if (suffix !== data.options.statementDescriptorSuffix) out.statementDescriptorSuffix = suffix;
  for (const k of ['bankTransferEnabled', 'disputeAutoSubmit', 'appLinkEnabled', 'stripeFeeGrossUp'] as const) {
    const v = boolOf(form[k]);
    if (v !== data.options[k]) out[k] = v;
  }
  // D344: only valid rates are sent (the form refuses to save otherwise).
  const bps = percentBpsOf(form.stripeFeePercent);
  if (bps !== undefined && bps !== data.options.stripeFeePercentBps) out.stripeFeePercentBps = bps;
  const fixed = fixedMinorOf(form.stripeFeeFixed);
  if (fixed !== undefined && fixed !== data.options.stripeFeeFixedMinor) out.stripeFeeFixedMinor = fixed;
  return out;
}

/** The keys part of the PATCH: only filled fields (an empty field keeps the stored key). */
export function keysPatch(form: { secretKey: string; webhookSecret: string; skip: boolean }) {
  const out: { secretKey?: string; webhookSecret?: string; skipConnectionTest?: boolean } = {};
  if (form.secretKey.trim()) out.secretKey = form.secretKey.trim();
  if (form.webhookSecret.trim()) out.webhookSecret = form.webhookSecret.trim();
  if (out.secretKey && form.skip) out.skipConnectionTest = true;
  return out;
}

function KeyRow({ label, info }: { label: string; info: PaymentKeyInfo | null }) {
  const { t, lang } = useApp();
  if (!info) {
    return (
      <tr>
        <td>{label}</td>
        <td colSpan={4} className="muted">
          —
        </td>
      </tr>
    );
  }
  return (
    <tr>
      <td>{label}</td>
      <td>
        <span className="badge info">{t(`payKind${info.kind}` as Key)}</span>{' '}
        {info.mode && <span className={`badge ${info.mode === 'live' ? 'ok' : 'warn'}`}>{t(`payMode${info.mode}` as Key)}</span>}
      </td>
      <td className="mono ltr">…{info.last4}</td>
      <td>{info.source === 'env' ? <span className="muted">{t('payFromServer')}</span> : (info.setBy?.displayName ?? '—')}</td>
      <td className="date small">{info.setAt ? formatDate(info.setAt, lang) : '—'}</td>
    </tr>
  );
}

/** `serverValue` is known only while the panel does not override it (then `effective` is the server's). */
function TriSelect({ id, label, value, serverValue, onChange }: { id: string; label: string; value: Tri; serverValue: boolean | null; onChange: (v: Tri) => void }) {
  const { t } = useApp();
  return (
    <div className="field">
      <label htmlFor={id}>{label}</label>
      <select id={id} value={value} onChange={(e) => onChange(e.target.value as Tri)}>
        <option value="default">{serverValue === null ? t('payDefaultPlain') : t('payDefault', { value: serverValue ? t('payOn') : t('payOff') })}</option>
        <option value="on">{t('payOn')}</option>
        <option value="off">{t('payOff')}</option>
      </select>
    </div>
  );
}

/** D344: «عمولة Stripe في سعر الموقع» — the gross-up switch, the account's rates and an example price. */
function FeeFields({ data, opts, setOpts }: { data: PaymentSettings; opts: OptionsForm; setOpts: (f: (o: OptionsForm) => OptionsForm) => void }) {
  const { t } = useApp();
  const cur = data.feeCurrency;
  const money = (minor: number) => `${(minor / 100).toFixed(2)} ${cur}`;
  const on = opts.stripeFeeGrossUp === 'default' ? data.effective.stripeFeeGrossUp : opts.stripeFeeGrossUp === 'on';
  const bps = percentBpsOf(opts.stripeFeePercent);
  const fixed = fixedMinorOf(opts.stripeFeeFixed);
  // The example uses the typed rate, else the one in use now.
  const rateBps = typeof bps === 'number' ? bps : data.effective.stripeFeePercentBps;
  const rateFixed = typeof fixed === 'number' ? fixed : data.effective.stripeFeeFixedMinor;
  const base = 1250;
  return (
    <fieldset className="field" aria-labelledby="pay-fee-title">
      <legend id="pay-fee-title">{t('payFeeTitle')}</legend>
      <p className="small muted">{t('payFeeIntro')}</p>
      <TriSelect
        id="pay-fee-grossup"
        label={t('payFeeGrossUp')}
        value={opts.stripeFeeGrossUp}
        serverValue={data.options.stripeFeeGrossUp === null ? data.effective.stripeFeeGrossUp : null}
        onChange={(v) => setOpts((o) => ({ ...o, stripeFeeGrossUp: v }))}
      />
      <p className="small warn-text" id="pay-fee-adjust">
        {t('payFeeAdjust')}
      </p>
      <div className="field">
        <label htmlFor="pay-fee-percent">{t('payFeePercent')}</label>
        <input
          id="pay-fee-percent"
          type="text"
          inputMode="decimal"
          className="ltr"
          maxLength={5}
          value={opts.stripeFeePercent}
          placeholder={String(data.effective.stripeFeePercentBps / 100)}
          aria-describedby="pay-fee-adjust"
          onChange={(e) => setOpts((o) => ({ ...o, stripeFeePercent: e.target.value }))}
        />
        <span className="small muted">{t('payFeeServer', { value: `${data.effective.stripeFeePercentBps / 100} %` })}</span>
      </div>
      <div className="field">
        <label htmlFor="pay-fee-fixed">{t('payFeeFixed', { currency: cur })}</label>
        <input
          id="pay-fee-fixed"
          type="text"
          inputMode="decimal"
          className="ltr"
          maxLength={6}
          value={opts.stripeFeeFixed}
          placeholder={(data.effective.stripeFeeFixedMinor / 100).toFixed(2)}
          aria-describedby="pay-fee-adjust"
          onChange={(e) => setOpts((o) => ({ ...o, stripeFeeFixed: e.target.value }))}
        />
        <span className="small muted">{t('payFeeServer', { value: money(data.effective.stripeFeeFixedMinor) })}</span>
      </div>
      <p className="small" id="pay-fee-example">
        {on ? t('payFeeExample', { base: money(base), price: money(grossUpMinor(base, rateBps, rateFixed)) }) : t('payFeeExampleOff', { base: money(base) })}
      </p>
    </fieldset>
  );
}

type Pending = { kind: 'keys' | 'options'; body: Record<string, unknown> } | { kind: 'clear' } | null;

export function PaymentsView({ data, onChange }: { data: PaymentSettings; onChange: (next: PaymentSettings) => void }) {
  const { t, lang, toast } = useApp();
  const [keys, setKeys] = useState({ secretKey: '', webhookSecret: '', skip: false });
  const [opts, setOpts] = useState<OptionsForm>(() => optionsFormOf(data));
  const [check, setCheck] = useState<PaymentKeyCheck | null>(null);
  const [checkError, setCheckError] = useState<unknown>(null);
  const [testing, setTesting] = useState(false);
  const [pending, setPending] = useState<Pending>(null);
  const [info, setInfo] = useState<string | null>(null);

  const status =
    data.mode === 'live' ? (['ok', 'payStatusLive'] as const) : data.mode === 'test' ? (['warn', 'payStatusTest'] as const) : (['bad', 'payStatusOff'] as const);
  const sourceKey: Key = data.source === 'panel' ? 'paySourcePanel' : data.source === 'env' ? 'paySourceEnv' : 'paySourceNone';
  const newKeyIsTest = /^(sk|rk)_test_/.test(keys.secretKey.trim());
  const copy = (text: string) => {
    void navigator.clipboard?.writeText(text).then(() => toast(t('payCopied')), () => undefined);
  };
  const applied = (next: PaymentSettings) => {
    onChange(next);
    setKeys({ secretKey: '', webhookSecret: '', skip: false });
    setOpts(optionsFormOf(next));
    setCheck(null);
    setPending(null);
    toast(t('saved'));
  };

  return (
    <>
      <div className="page-head">
        <div>
          <h1>{t('paymentsTitle')}</h1>
          <p className="muted small">{t('paySubtitle')}</p>
        </div>
      </div>

      <section className="card" aria-labelledby="pay-status">
        <div className="row" style={{ justifyContent: 'space-between' }}>
          <h2 id="pay-status" style={{ margin: 0 }}>
            {t('payStatus')}
          </h2>
          <span className={`badge ${status[0]}`} data-testid="pay-status">
            {t(status[1])}
          </span>
        </div>
        <p className="muted small">{t(sourceKey)}</p>
        {data.panelKeysIgnored && (
          <div className="alert error" role="alert">
            {t(data.panelKeysIgnored === 'unreadable' ? 'payIgnoredUnreadable' : 'payIgnoredTestInProd')}
          </div>
        )}
        {!data.publicBaseUrl && <div className="alert error">{t('payNoBaseUrl')}</div>}
        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>{t('payKeyCol')}</th>
                <th>{t('payTypeCol')}</th>
                <th>{t('payLast4Col')}</th>
                <th>{t('paySetByCol')}</th>
                <th>{t('paySetAtCol')}</th>
              </tr>
            </thead>
            <tbody>
              <KeyRow label={t('paySecretKey')} info={data.secretKey} />
              <KeyRow label={t('payWebhookSecret')} info={data.webhookSecret} />
            </tbody>
          </table>
        </div>
        {data.previousWebhookSecretValidUntil && (
          <p className="small muted">{t('payPreviousUntil', { time: formatDate(data.previousWebhookSecretValidUntil, lang) })}</p>
        )}
      </section>

      <section className="card" aria-labelledby="pay-webhook" style={{ marginTop: 16 }}>
        <h2 id="pay-webhook" style={{ marginTop: 0 }}>
          {t('payWebhook')}
        </h2>
        <p className="muted small">{t('payWebhookHint')}</p>
        <div className="field">
          <label htmlFor="pay-url">{t('payWebhookUrl')}</label>
          <div className="row">
            <input id="pay-url" type="text" className="ltr mono" readOnly value={data.webhookUrl ?? ''} style={{ flex: 1 }} />
            <button type="button" className="btn small" disabled={!data.webhookUrl} onClick={() => data.webhookUrl && copy(data.webhookUrl)}>
              {t('payCopy')}
            </button>
          </div>
        </div>
        <div className="field">
          <span className="label-text">{t('payEvents')}</span>
          <ul className="chips ltr" aria-label={t('payEvents')}>
            {data.webhookEvents.map((e) => (
              <li key={e}>
                <code>{e}</code>
              </li>
            ))}
          </ul>
        </div>
        <div className="field">
          <label htmlFor="pay-base">{t('payBaseUrl')}</label>
          <input id="pay-base" type="text" className="ltr mono" readOnly value={data.publicBaseUrl ?? ''} />
        </div>
      </section>

      <div className="grid cols-2" style={{ marginTop: 16, alignItems: 'start' }}>
        <form
          className="card"
          aria-labelledby="pay-keys"
          autoComplete="off"
          onSubmit={(e) => {
            e.preventDefault();
            const body = keysPatch(keys);
            if (!body.secretKey && !body.webhookSecret) return setInfo(t('payNothing'));
            setInfo(null);
            setPending({ kind: 'keys', body });
          }}
        >
          <h2 id="pay-keys" style={{ marginTop: 0 }}>
            {t('payKeysTitle')}
          </h2>
          <p className="muted small">{t('payKeysHint')}</p>
          <div className="field">
            <label htmlFor="pay-sk">{t('payNewSecretKey')}</label>
            <input
              id="pay-sk"
              type="password"
              placeholder="sk_live_… / rk_live_…"
              className="ltr mono"
              autoComplete="off"
              spellCheck={false}
              maxLength={260}
              value={keys.secretKey}
              onChange={(e) => {
                setKeys((k) => ({ ...k, secretKey: e.target.value }));
                setCheck(null);
                setCheckError(null);
              }}
            />
          </div>
          <div className="row" style={{ marginBottom: 12 }}>
            <button
              type="button"
              className="btn small"
              disabled={testing || !keys.secretKey.trim()}
              onClick={() => {
                setTesting(true);
                setCheck(null);
                setCheckError(null);
                api.post<PaymentKeyCheck>('/admin/payment-settings/test', { secretKey: keys.secretKey.trim() }).then(
                  (r) => {
                    setTesting(false);
                    setCheck(r);
                  },
                  (err: unknown) => {
                    setTesting(false);
                    setCheckError(err);
                  },
                );
              }}
            >
              {t('payTest')}
            </button>
          </div>
          {check && (
            <div className="alert success" role="status">
              {t('payTestOk', { kind: t(`payKind${check.kind}` as Key), mode: check.mode ? t(`payMode${check.mode}` as Key) : '—', last4: check.last4 })}
              {check.restricted && <div className="small">{t('payTestRestricted')}</div>}
            </div>
          )}
          <ErrorAlert error={checkError} />
          <div className="field">
            <label htmlFor="pay-wh">{t('payNewWebhookSecret')}</label>
            <input
              id="pay-wh"
              type="password"
              placeholder="whsec_…"
              className="ltr mono"
              autoComplete="off"
              spellCheck={false}
              maxLength={260}
              value={keys.webhookSecret}
              onChange={(e) => setKeys((k) => ({ ...k, webhookSecret: e.target.value }))}
            />
          </div>
          {data.connectionTestSkippable && newKeyIsTest && (
            <label className="check field">
              <input type="checkbox" checked={keys.skip} onChange={(e) => setKeys((k) => ({ ...k, skip: e.target.checked }))} />
              {t('paySkipTest')}
            </label>
          )}
          {info && <p className="small muted">{info}</p>}
          <div className="row" style={{ justifyContent: 'space-between' }}>
            <button className="btn primary">{t('paySaveKeys')}</button>
            {data.panelKeys && (
              <button type="button" className="btn danger" onClick={() => setPending({ kind: 'clear' })}>
                {t('payClearKeys')}
              </button>
            )}
          </div>
        </form>

        <form
          className="card"
          aria-labelledby="pay-options"
          onSubmit={(e) => {
            e.preventDefault();
            if (!feeFormValid(opts)) return setInfo(t('payFeeInvalid'));
            const body = optionsPatch(opts, data);
            if (Object.keys(body).length === 0) return setInfo(t('payNothing'));
            setInfo(null);
            setPending({ kind: 'options', body });
          }}
        >
          <h2 id="pay-options" style={{ marginTop: 0 }}>
            {t('payOptionsTitle')}
          </h2>
          <TriSelect
            id="pay-bank"
            label={t('payBankTransfer')}
            value={opts.bankTransferEnabled}
            serverValue={data.options.bankTransferEnabled === null ? data.effective.bankTransferEnabled : null}
            onChange={(v) => setOpts((o) => ({ ...o, bankTransferEnabled: v }))}
          />
          <TriSelect
            id="pay-dispute"
            label={t('payDisputeSubmit')}
            value={opts.disputeAutoSubmit}
            serverValue={data.options.disputeAutoSubmit === null ? data.effective.disputeAutoSubmit : null}
            onChange={(v) => setOpts((o) => ({ ...o, disputeAutoSubmit: v }))}
          />
          <TriSelect
            id="pay-applink"
            label={t('payAppLink')}
            value={opts.appLinkEnabled}
            serverValue={data.options.appLinkEnabled === null ? data.effective.appLinkEnabled : null}
            onChange={(v) => setOpts((o) => ({ ...o, appLinkEnabled: v }))}
          />
          <FeeFields data={data} opts={opts} setOpts={setOpts} />
          <div className="field">
            <label htmlFor="pay-suffix">{t('payDescriptor')}</label>
            <input
              id="pay-suffix"
              type="text"
              className="ltr"
              maxLength={10}
              value={opts.statementDescriptorSuffix}
              placeholder={data.effective.statementDescriptorSuffix ?? ''}
              onChange={(e) => setOpts((o) => ({ ...o, statementDescriptorSuffix: e.target.value.replace(/[^A-Za-z0-9 ]/g, '') }))}
            />
          </div>
          <div className="field">
            <label htmlFor="pay-pk">{t('payPublishable')}</label>
            <input
              id="pay-pk"
              type="text"
              placeholder="pk_live_…"
              className="ltr mono"
              autoComplete="off"
              spellCheck={false}
              maxLength={260}
              value={opts.publishableKey}
              onChange={(e) => setOpts((o) => ({ ...o, publishableKey: e.target.value }))}
            />
          </div>
          <button className="btn primary">{t('paySaveOptions')}</button>
        </form>
      </div>

      {pending && pending.kind !== 'clear' && (
        <FormDialog
          title={t('payConfirmTitle')}
          intro={<p className="small">{t('payConfirmIntro')}</p>}
          fields={[reasonField(t), codeField(t)]}
          confirmLabel={t('save')}
          submit={async (v) => applied(await api.patch<PaymentSettings>('/admin/payment-settings', { ...pending.body, reason: v.reason, totpCode: v.totpCode }))}
          onClose={() => setPending(null)}
          onDone={() => setPending(null)}
        />
      )}
      {pending?.kind === 'clear' && (
        <FormDialog
          title={t('payClearKeys')}
          intro={<p className="small">{t('payClearHint')}</p>}
          fields={[reasonField(t), codeField(t)]}
          confirmLabel={t('payClearConfirm')}
          danger
          submit={async (v) => applied(await api.post<PaymentSettings>('/admin/payment-settings/clear-keys', { reason: v.reason, totpCode: v.totpCode }))}
          onClose={() => setPending(null)}
          onDone={() => setPending(null)}
        />
      )}
    </>
  );
}
