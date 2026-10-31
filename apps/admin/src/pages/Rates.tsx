import { useState } from 'react';
import { api } from '../api';
import { ErrorAlert, FormDialog, Loading, reasonField, useAsync } from '../components';
import { useApp } from '../context';
import { formatDate } from '../format';
import type { ExchangeRateRow } from '../types';

/** «أسعار الصرف» (v1.69-social, D204, CONVENTIONS §10.64.1): the rate per country that prices recharge orders. */
export function Rates() {
  const { t, lang, can, toast } = useApp();
  const { data, error, loading, reload } = useAsync(
    () => api.get<{ retailUsdPerMillion: number; data: ExchangeRateRow[] }>('/admin/recharge/exchange-rates'),
    [],
  );
  const [editing, setEditing] = useState<ExchangeRateRow | null>(null);
  const [clearing, setClearing] = useState<ExchangeRateRow | null>(null);
  const canEdit = can('recharge.rates');
  return (
    <>
      <div className="page-head">
        <div>
          <h1>{t('ratesTitle')}</h1>
          {data && <p className="muted small">{t('ratesSubtitle', { usd: data.retailUsdPerMillion })}</p>}
        </div>
      </div>
      <ErrorAlert error={error} />
      {loading && !data && <Loading />}
      {data && (
        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>{t('colCountry')}</th>
                <th>{t('colCurrency')}</th>
                <th>{t('colRate')}</th>
                <th>{t('colDigits')}</th>
                <th>{t('colUpdated')}</th>
                {canEdit && <th>{t('actions')}</th>}
              </tr>
            </thead>
            <tbody>
              {data.data.map((r) => (
                <tr key={r.country} data-country={r.country}>
                  <td className="mono">{r.country}</td>
                  <td className="mono">{r.currency ?? t('none')}</td>
                  <td className="num ltr">{r.unitsPerUsd ?? <span className="muted">{t('rateNone')}</span>}</td>
                  <td className="num">{r.digits}</td>
                  <td className="date small">{r.updatedAt ? formatDate(r.updatedAt, lang) : t('none')}</td>
                  {canEdit && (
                    <td>
                      <div className="row">
                        <button className="btn small" onClick={() => setEditing(r)}>
                          {t('rateEdit')}
                        </button>
                        {r.unitsPerUsd !== null && (
                          <button className="btn small danger" onClick={() => setClearing(r)}>
                            {t('rateClear')}
                          </button>
                        )}
                      </div>
                    </td>
                  )}
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
      {editing && (
        <FormDialog
          title={t('rateEditTitle', { country: editing.country })}
          fields={[
            { name: 'currency', label: t('colCurrency'), maxLength: 3, required: false, hint: editing.currency ?? undefined },
            { name: 'unitsPerUsd', label: t('colRate'), maxLength: 16, hint: editing.unitsPerUsd ?? undefined },
            { name: 'digits', label: t('colDigits'), maxLength: 1, required: false, hint: String(editing.digits) },
            reasonField(t),
          ]}
          confirmLabel={t('save')}
          submit={(v) =>
            api.post(`/admin/recharge/exchange-rates/${editing.country}`, {
              currency: (v.currency || editing.currency || '').toUpperCase(),
              unitsPerUsd: v.unitsPerUsd,
              digits: Number(v.digits || editing.digits),
              reason: v.reason,
            })
          }
          onClose={() => setEditing(null)}
          onDone={() => {
            setEditing(null);
            toast(t('saved'));
            reload();
          }}
        />
      )}
      {clearing && (
        <FormDialog
          title={t('rateClear')}
          intro={<p className="small mono">{clearing.country}</p>}
          fields={[reasonField(t)]}
          confirmLabel={t('rateClear')}
          danger
          submit={(v) => api.post(`/admin/recharge/exchange-rates/${clearing.country}/clear`, { reason: v.reason })}
          onClose={() => setClearing(null)}
          onDone={() => {
            setClearing(null);
            toast(t('done'));
            reload();
          }}
        />
      )}
    </>
  );
}
