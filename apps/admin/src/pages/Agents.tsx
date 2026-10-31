import { useState } from 'react';
import { api } from '../api';
import { Dialog, ErrorAlert, FormDialog, Loading, Pager, reasonField, StatusBadge, useAsync, useCursorPages, UserCell } from '../components';
import { useApp } from '../context';
import { formatMoney, formatNumber } from '../format';
import { expectedMinor, minorToUsd, parseUsd, tierFor } from '../price';
import type { AgentPage, AgentRow, Pricing, TopUpResult } from '../types';
import { StatusTabs } from './Applications';

const STATUSES = ['', 'ACTIVE', 'APPROVED', 'SUSPENDED'] as const;

/** The top-up dialog: the owner's tier price shown live; the paid amount defaults to it; the code again. */
export function TopUpDialog({ agent, pricing, onClose, onDone }: { agent: AgentRow; pricing: Pricing; onClose: () => void; onDone: (r: TopUpResult) => void }) {
  const { t, lang } = useApp();
  const [coins, setCoins] = useState('');
  const [paid, setPaid] = useState('');
  const [paidTouched, setPaidTouched] = useState(false);
  const [note, setNote] = useState('');
  const [code, setCode] = useState('');
  const [error, setError] = useState<unknown>(null);
  const [busy, setBusy] = useState(false);
  const coinsN = /^[1-9][0-9]{0,12}$/.test(coins) ? BigInt(coins) : null;
  const tier = coinsN === null ? null : tierFor(coinsN, pricing.priceTiers);
  const expected = coinsN !== null && tier ? expectedMinor(coinsN, tier) : null;
  const paidText = paidTouched ? paid : expected !== null ? minorToUsd(expected) : '';
  const paidMinor = parseUsd(paidText);
  const differs = paidMinor !== null && expected !== null && paidMinor !== expected;
  const first = agent.code === null;
  const belowFirst = first && coinsN !== null && coinsN < BigInt(pricing.activationMinCoins);
  const ok = coinsN !== null && paidMinor !== null && code.length === 6 && (!differs || note.trim() !== '') && !belowFirst;
  return (
    <Dialog title={t('topupTitle')} onClose={onClose}>
      <p className="muted small">
        <UserCell username={agent.username} displayName={agent.displayName} /> {agent.code && <span className="mono">{agent.code}</span>}
      </p>
      {first && <div className="alert info">{t('topupFirst', { min: formatNumber(pricing.activationMinCoins, lang) })}</div>}
      <ErrorAlert error={error} />
      <form
        onSubmit={(e) => {
          e.preventDefault();
          if (!ok) return;
          setBusy(true);
          setError(null);
          api
            .post<TopUpResult>(`/admin/recharge/agents/${agent.userId}/topup`, {
              coins,
              paidUsd: paidText,
              ...(note.trim() ? { note: note.trim() } : {}),
              totpCode: code,
            })
            .then(onDone, (err: unknown) => {
              setError(err);
              setCode('');
              setBusy(false);
            });
        }}
      >
        <div className="field">
          <label htmlFor="tu-coins">{t('topupCoins')}</label>
          <input id="tu-coins" type="text" inputMode="numeric" className="ltr" value={coins} onChange={(e) => setCoins(e.target.value.replace(/[^0-9]/g, ''))} />
          {coinsN !== null && <span className="hint num">{formatNumber(Number(coinsN), lang)}</span>}
        </div>
        {tier && expected !== null && (
          <dl className="kv card" style={{ marginBottom: 14, padding: 12 }}>
            <dt>{t('topupTier')}</dt>
            <dd className="mono">{tier.minCoins === 0 ? 'STANDARD' : `≥ ${formatNumber(tier.minCoins, lang)}`}</dd>
            <dt>{t('topupPrice')}</dt>
            <dd className="num">{formatMoney(tier.minorPerMillion, pricing.currency, lang)}</dd>
            <dt>{t('topupExpected')}</dt>
            <dd className="num" style={{ fontWeight: 700 }}>
              {formatMoney(Number(expected), pricing.currency, lang)}
            </dd>
          </dl>
        )}
        <div className="field">
          <label htmlFor="tu-paid">{t('topupPaid')}</label>
          <input
            id="tu-paid"
            type="text"
            inputMode="decimal"
            className="ltr"
            value={paidText}
            onChange={(e) => {
              setPaidTouched(true);
              setPaid(e.target.value);
            }}
          />
          {differs && <span className="hint" style={{ color: 'var(--warning)' }}>{t('topupNoteRequired')}</span>}
        </div>
        <div className="field">
          <label htmlFor="tu-note">{t('note')}</label>
          <textarea id="tu-note" maxLength={500} value={note} onChange={(e) => setNote(e.target.value)} />
        </div>
        <div className="field">
          <label htmlFor="tu-code">{t('totpCode')}</label>
          <input
            id="tu-code"
            type="text"
            className="code-input"
            inputMode="numeric"
            autoComplete="one-time-code"
            maxLength={6}
            value={code}
            onChange={(e) => setCode(e.target.value.replace(/[^0-9]/g, ''))}
          />
          <span className="hint">{t('totpHint')}</span>
        </div>
        <div className="actions">
          <button type="button" className="btn" onClick={onClose}>
            {t('cancel')}
          </button>
          <button className="btn primary" disabled={!ok || busy}>
            {t('topup')}
          </button>
        </div>
      </form>
    </Dialog>
  );
}

type Act = { kind: 'topup' | 'suspend' | 'reinstate' | 'cap'; agent: AgentRow } | null;

export function Agents() {
  const { t, lang, can, toast } = useApp();
  const [status, setStatus] = useState<(typeof STATUSES)[number]>('');
  const pages = useCursorPages(status);
  const { data, error, loading, reload } = useAsync(
    () => api.get<AgentPage>('/admin/recharge/agents', { status, cursor: pages.cursor }),
    [status, pages.cursor],
  );
  const [act, setAct] = useState<Act>(null);
  const finish = (text = t('done')) => {
    setAct(null);
    toast(text);
    reload();
  };
  const capText = (a: AgentRow) => (a.dailyCherryCap === null ? t('capDefault') : a.dailyCherryCap === 0 ? t('capNone') : formatNumber(a.dailyCherryCap, lang));
  return (
    <>
      <div className="page-head">
        <h1>{t('agentsTitle')}</h1>
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
                <th>{t('colCode')}</th>
                <th>{t('colStatus')}</th>
                <th>{t('stock')}</th>
                <th>{t('dailyCap')}</th>
                <th>{t('colCountries')}</th>
                <th>{t('actions')}</th>
              </tr>
            </thead>
            <tbody>
              {data.data.map((a) => (
                <tr key={a.userId}>
                  <td>
                    <UserCell username={a.username} displayName={a.displayName} />
                  </td>
                  <td className="mono">{a.code ?? t('none')}</td>
                  <td>
                    <StatusBadge status={a.status} />
                  </td>
                  <td className="num">{formatNumber(a.stockCoins, lang)}</td>
                  <td className="num">{capText(a)}</td>
                  <td className="mono small">{a.countries.join(', ')}</td>
                  <td>
                    <div className="row">
                      {can('recharge.topup') && a.status !== 'SUSPENDED' && (
                        <button className="btn small primary" onClick={() => setAct({ kind: 'topup', agent: a })}>
                          {t('topup')}
                        </button>
                      )}
                      {can('recharge.status') && a.status !== 'SUSPENDED' && (
                        <button className="btn small danger" onClick={() => setAct({ kind: 'suspend', agent: a })}>
                          {t('suspend')}
                        </button>
                      )}
                      {can('recharge.status') && a.status === 'SUSPENDED' && (
                        <button className="btn small" onClick={() => setAct({ kind: 'reinstate', agent: a })}>
                          {t('reinstate')}
                        </button>
                      )}
                      {can('recharge.cap') && (
                        <button className="btn small" onClick={() => setAct({ kind: 'cap', agent: a })}>
                          {t('setCap')}
                        </button>
                      )}
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
      <Pager page={data?.page} index={pages.index} onNext={() => data && pages.next(data.page)} onPrev={pages.prev} />
      {act?.kind === 'topup' && data && (
        <TopUpDialog
          agent={act.agent}
          pricing={data.pricing}
          onClose={() => setAct(null)}
          onDone={(r) => finish(t('topupDone', { stock: formatNumber(r.stockCoins, lang) }))}
        />
      )}
      {(act?.kind === 'suspend' || act?.kind === 'reinstate') && (
        <FormDialog
          title={t(act.kind)}
          fields={[reasonField(t)]}
          confirmLabel={t(act.kind)}
          danger={act.kind === 'suspend'}
          submit={(v) => api.post(`/admin/recharge/agents/${act.agent.userId}/${act.kind}`, { reason: v.reason })}
          onClose={() => setAct(null)}
          onDone={() => finish()}
        />
      )}
      {act?.kind === 'cap' && (
        <FormDialog
          title={t('setCap')}
          intro={<p className="muted small">{t('capUseDefault')}: «default»</p>}
          fields={[{ name: 'cap', label: t('capValue') }, reasonField(t)]}
          confirmLabel={t('save')}
          submit={(v) => {
            const raw = (v.cap ?? '').toLowerCase();
            return api.post(`/admin/recharge/agents/${act.agent.userId}/cap`, {
              cap: raw === 'default' ? null : raw.replace(/[^0-9]/g, ''),
              reason: v.reason,
            });
          }}
          onClose={() => setAct(null)}
          onDone={() => finish()}
        />
      )}
    </>
  );
}
