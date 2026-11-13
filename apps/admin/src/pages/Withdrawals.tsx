import { useState } from 'react';
import { api } from '../api';
import { codeField, ErrorAlert, FormDialog, Loading, Pager, reasonField, StatusBadge, useAsync, useCursorPages, UserCell } from '../components';
import { useApp } from '../context';
import { formatDate, formatMoney, formatNumber } from '../format';
import type { Page, WithdrawalRow } from '../types';
import { StatusTabs } from './Applications';

const STATUSES = ['PENDING', 'PAID', 'REJECTED'] as const;

export function Withdrawals() {
  const { t, lang, can, toast } = useApp();
  const [status, setStatus] = useState<(typeof STATUSES)[number]>('PENDING');
  const pages = useCursorPages(status);
  const { data, error, loading, reload } = useAsync(
    () => api.get<Page<WithdrawalRow>>('/admin/withdrawals', { status, cursor: pages.cursor }),
    [status, pages.cursor],
  );
  const [act, setAct] = useState<{ kind: 'pay' | 'reject'; w: WithdrawalRow } | null>(null);
  return (
    <>
      <div className="page-head">
        <h1>{t('wdTitle')}</h1>
        <StatusTabs value={status} options={STATUSES} onChange={setStatus} />
      </div>
      <ErrorAlert error={error} />
      {loading && !data && <Loading />}
      {data && data.data.length === 0 && <p className="muted">{t('empty')}</p>}
      {data && data.data.length > 0 && (
        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>{t('colUser')}</th>
                <th>{t('colAmount')}</th>
                <th>{t('cherries')}</th>
                <th>{t('colPayout')}</th>
                <th>{t('colSubmitted')}</th>
                {status === 'PENDING' ? <th>{t('actions')}</th> : <th>{t('colNote')}</th>}
              </tr>
            </thead>
            <tbody>
              {data.data.map((w) => (
                <tr key={w.id}>
                  <td>
                    <UserCell username={w.user.username} displayName={w.user.displayName} />
                  </td>
                  <td className="num" style={{ fontWeight: 600 }}>
                    {formatMoney(w.amountMinor, w.currency, lang)}
                  </td>
                  <td className="num">{formatNumber(w.cherries, lang)}</td>
                  <td style={{ maxWidth: 260 }}>{w.payoutDetails}</td>
                  <td className="date small">{formatDate(w.createdAt, lang)}</td>
                  {status === 'PENDING' ? (
                    <td>
                      {can('withdrawals.decide') && (
                        <div className="row">
                          <button className="btn small primary" onClick={() => setAct({ kind: 'pay', w })}>
                            {t('markPaid')}
                          </button>
                          <button className="btn small danger" onClick={() => setAct({ kind: 'reject', w })}>
                            {t('rejectWd')}
                          </button>
                        </div>
                      )}
                    </td>
                  ) : (
                    <td className="small">
                      <StatusBadge status={w.status} /> {w.decisionNote}
                    </td>
                  )}
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
      <Pager page={data?.page} index={pages.index} onNext={() => data && pages.next(data.page)} onPrev={pages.prev} />
      {act?.kind === 'pay' && (
        <FormDialog
          title={t('payTitle')}
          intro={
            <p className="small">
              <strong className="num">{formatMoney(act.w.amountMinor, act.w.currency, lang)}</strong> → {act.w.payoutDetails}
            </p>
          }
          fields={[
            { name: 'reference', label: t('payReference'), maxLength: 200 },
            { name: 'note', label: t('note'), kind: 'textarea', required: false, maxLength: 280 },
            codeField(t),
          ]}
          confirmLabel={t('markPaid')}
          submit={(v) =>
            api.post(`/admin/withdrawals/${act.w.id}/pay`, {
              reference: v.reference,
              ...(v.note ? { note: v.note } : {}),
              totpCode: v.totpCode,
            })
          }
          onClose={() => setAct(null)}
          onDone={() => {
            setAct(null);
            toast(t('done'));
            reload();
          }}
        />
      )}
      {act?.kind === 'reject' && (
        <FormDialog
          title={t('rejectWd')}
          fields={[reasonField(t), codeField(t)]}
          confirmLabel={t('rejectWd')}
          danger
          submit={(v) => api.post(`/admin/withdrawals/${act.w.id}/reject`, { reason: v.reason, totpCode: v.totpCode })}
          onClose={() => setAct(null)}
          onDone={() => {
            setAct(null);
            toast(t('done'));
            reload();
          }}
        />
      )}
    </>
  );
}
