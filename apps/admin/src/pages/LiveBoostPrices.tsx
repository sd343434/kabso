import { useState } from 'react';
import { api } from '../api';
import { codeField, ErrorAlert, FormDialog, Loading, reasonField, useAsync } from '../components';
import { useApp } from '../context';
import { formatNumber } from '../format';
import type { AdminLiveBoostPrices } from '../types';

/** Each stage strictly dearer than the one before, every price 1 … 10^9 (the server checks it again). */
export function pricesValid(prices: readonly number[]): boolean {
  return (
    prices.length === 4 &&
    prices.every((c, i) => Number.isInteger(c) && c >= 1 && c <= 1_000_000_000 && (i === 0 || c > prices[i - 1]!))
  );
}

/** The rocket stages' prices form (pure: rendered in the tests). Coins only — never a currency. */
export function BoostPricesForm({
  saved,
  draft,
  onChange,
  onSave,
}: {
  saved: AdminLiveBoostPrices;
  draft: number[];
  onChange: (d: number[]) => void;
  onSave: () => void;
}) {
  const { t, lang, can } = useApp();
  const edit = can('catalog.manage');
  const changed = saved.stages.some((s, i) => s.priceCoins !== draft[i]);
  const valid = pricesValid(draft);
  return (
    <div className="card" data-boost-prices style={{ maxWidth: 640 }}>
      {!edit && <div className="alert info">{t('bpReadOnly')}</div>}
      {saved.stages.map((s, i) => (
        <div className="field" key={s.stage} data-stage={s.stage}>
          <label htmlFor={`bp-${s.stage}`}>
            🚀 {t('bpStage', { n: s.stage })} · {t('bpMinutes', { n: s.minutes })}
          </label>
          <input
            id={`bp-${s.stage}`}
            type="number"
            min={1}
            className="ltr mono"
            aria-label={t('bpPrice')}
            value={draft[i]}
            disabled={!edit}
            onChange={(e) => onChange(draft.map((x, j) => (j === i ? Math.max(0, Math.floor(Number(e.target.value)) || 0) : x)))}
          />
          <p className="muted small">
            {t('bpConfig', { coins: formatNumber(s.configCoins, lang) })}
            {s.custom && <> · {t('bpCustom')}</>}
          </p>
        </div>
      ))}
      {!valid && <div className="alert error">{t('bpRising')}</div>}
      {edit && (
        <button className="btn primary" disabled={!valid || !changed} onClick={onSave} data-boost-save>
          {changed ? t('bpSave') : t('bpNoChange')}
        </button>
      )}
    </div>
  );
}

/** «صواريخ الزيارات» (v1.51-live, D233, CONVENTIONS §10.81). */
export function LiveBoostPrices() {
  const { t, toast } = useApp();
  const { data, error, loading, reload } = useAsync(() => api.get<AdminLiveBoostPrices>('/admin/live-boost-prices'), []);
  const [draft, setDraft] = useState<number[] | null>(null);
  const [saving, setSaving] = useState(false);
  if (loading && !data) return <Loading />;
  if (!data) return <ErrorAlert error={error} />;
  const current = draft ?? data.stages.map((s) => s.priceCoins);
  return (
    <>
      <div className="page-head">
        <div>
          <h1>{t('bpTitle')}</h1>
          <p className="muted small">{t('bpSubtitle')}</p>
        </div>
      </div>
      <BoostPricesForm saved={data} draft={current} onChange={setDraft} onSave={() => setSaving(true)} />
      {saving && (
        <FormDialog
          title={t('bpSave')}
          intro={<p className="muted small">{t('bpSaveIntro')}</p>}
          fields={[reasonField(t), codeField(t)]}
          confirmLabel={t('bpSave')}
          submit={(v) => api.put('/admin/live-boost-prices', { prices: current, ...v })}
          onClose={() => setSaving(false)}
          onDone={() => {
            setSaving(false);
            setDraft(null);
            toast(t('bpSaved'));
            reload();
          }}
        />
      )}
    </>
  );
}
