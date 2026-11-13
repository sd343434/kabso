import { useState } from 'react';
import { api } from '../api';
import { codeField, Dialog, ErrorAlert, FormDialog, reasonField, UserCell, useAsync } from '../components';
import { useApp } from '../context';
import { formatDate, formatNumber } from '../format';
import type { Compensation, CompensationKind, CompensationPage, CompensationSettings, CompensationStatus } from '../types';
import { Icon } from '../ui/icons';

/**
 * v1.139-social (D387, CONVENTIONS §10.176.4): «التعويضات» — VIP_CARE grants coins, VIP days or a store item to a
 * supporter, always with a reason and the authenticator code. Within the OWNER's limits (a daily value per staff member,
 * a maximum per grant, in coins) it is granted at once; above them it waits for the OWNER, who approves or rejects. The
 * history: VIP_CARE their own, the OWNER everyone's.
 */

export const COMP_KINDS: CompensationKind[] = ['COINS', 'VIP_DAYS', 'ITEM'];
export const COMP_STATUSES: CompensationStatus[] = ['PENDING', 'GRANTED', 'APPROVED', 'REJECTED'];

/** The request body of the grant form (null while incomplete). */
export function compensationBody(f: {
  user: string;
  kind: CompensationKind;
  coins: string;
  days: string;
  tierCode: string;
  itemCode: string;
  reason: string;
  totpCode: string;
}): Record<string, unknown> | null {
  const base = { user: f.user.trim(), kind: f.kind, reason: f.reason.trim(), totpCode: f.totpCode };
  if (!base.user || base.reason.length < 3 || !/^[0-9]{6}$/.test(f.totpCode)) return null;
  const int = (v: string) => (/^[0-9]+$/.test(v.trim()) ? Number(v.trim()) : null);
  if (f.kind === 'COINS') {
    const coins = int(f.coins);
    return coins && coins > 0 ? { ...base, coins } : null;
  }
  const days = int(f.days);
  if (!days) return null;
  if (f.kind === 'VIP_DAYS') return f.tierCode.trim() ? { ...base, days, tierCode: f.tierCode.trim() } : null;
  return f.itemCode.trim() && [7, 14, 30].includes(days) ? { ...base, days, itemCode: f.itemCode.trim() } : null;
}

/** The limits card (pure: rendered in the tests). */
export function LimitsCard({ settings, onEdit }: { settings: CompensationSettings; onEdit?: () => void }) {
  const { t, lang } = useApp();
  const n = (v: number) => t('compCoins', { n: formatNumber(v, lang) });
  return (
    <section className="card" data-comp-limits>
      <div className="card-head">
        <h2>{t('compLimits')}</h2>
        {onEdit && (
          <button className="btn small" onClick={onEdit}>
            {t('compEditLimits')}
          </button>
        )}
      </div>
      <div className="kpis">
        <div className="kpi tone-gold">
          <span className="kpi-label">{t('compDaily')}</span>
          <div className="kpi-value num">{n(settings.dailyLimitCoins)}</div>
        </div>
        <div className="kpi tone-blue">
          <span className="kpi-label">{t('compPerGrant')}</span>
          <div className="kpi-value num">{n(settings.perGrantMaxCoins)}</div>
        </div>
        <div className="kpi tone-green">
          <span className="kpi-label">{t('compUsedToday')}</span>
          <div className="kpi-value num">{n(settings.usedTodayCoins)}</div>
        </div>
      </div>
      <p className="muted small">{t('compLimitsNote', { zone: settings.timeZone })}</p>
    </section>
  );
}

/** The history table (pure: rendered in the tests). */
export function CompensationTable({
  rows,
  onDecide,
}: {
  rows: Compensation[];
  onDecide?: (row: Compensation, approve: boolean) => void;
}) {
  const { t, lang } = useApp();
  if (rows.length === 0) return <p className="muted state">{t('compNone')}</p>;
  return (
    <div className="table-wrap">
      <table data-comp-table>
        <thead>
          <tr>
            <th>{t('compUser')}</th>
            <th>{t('compKind')}</th>
            <th className="num">{t('compValue')}</th>
            <th>{t('compStaff')}</th>
            <th>{t('compStatus')}</th>
            <th>{t('reason')}</th>
            <th />
          </tr>
        </thead>
        <tbody>
          {rows.map((r) => (
            <tr key={r.id} data-status={r.status}>
              <td>
                <UserCell username={r.user.username} displayName={r.user.displayName} avatarUrl={r.user.avatarUrl} />
              </td>
              <td>
                {t(`compKind${r.kind}`)}
                <span className="muted small">
                  {' '}
                  {r.kind === 'COINS' && r.coins !== null && formatNumber(r.coins, lang)}
                  {r.kind === 'VIP_DAYS' && `${r.tierCode} · ${r.days}`}
                  {r.kind === 'ITEM' && `${r.itemCode} · ${r.days}`}
                </span>
              </td>
              <td className="num">{t('compCoins', { n: formatNumber(r.valueCoins, lang) })}</td>
              <td className="small">{r.staff?.displayName ?? '—'}</td>
              <td>
                <span className={`badge ${r.status === 'PENDING' ? 'warn' : r.status === 'REJECTED' ? 'bad' : 'ok'}`}>
                  {t(`compStatus${r.status}`)}
                </span>
                {r.overLimit && <span className="muted small"> {t(`compOver${r.overLimit}`)}</span>}
                {r.decidedBy && <span className="muted small"> · {t('compDecidedBy', { name: r.decidedBy.displayName })}</span>}
                <div className="muted small date">{formatDate(r.createdAt, lang)}</div>
              </td>
              <td className="small">{r.reason}</td>
              <td>
                {onDecide && r.status === 'PENDING' && (
                  <span className="row">
                    <button className="btn small primary" onClick={() => onDecide(r, true)}>
                      {t('compApprove')}
                    </button>
                    <button className="btn small danger" onClick={() => onDecide(r, false)}>
                      {t('compReject')}
                    </button>
                  </span>
                )}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

function GrantDialog({ onClose, onDone }: { onClose: () => void; onDone: (row: Compensation) => void }) {
  const { t } = useApp();
  const [f, setF] = useState({
    user: '',
    kind: 'COINS' as CompensationKind,
    coins: '',
    days: '',
    tierCode: '',
    itemCode: '',
    reason: '',
    totpCode: '',
  });
  const [error, setError] = useState<unknown>(null);
  const [busy, setBusy] = useState(false);
  const body = compensationBody(f);
  const set = (k: keyof typeof f) => (e: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement | HTMLSelectElement>) =>
    setF((v) => ({ ...v, [k]: k === 'totpCode' ? e.target.value.replace(/[^0-9]/g, '') : e.target.value }));
  return (
    <Dialog title={t('compGrant')} onClose={onClose}>
      <ErrorAlert error={error} />
      <form
        onSubmit={(e) => {
          e.preventDefault();
          if (!body || busy) return;
          setBusy(true);
          setError(null);
          api.post<Compensation>('/admin/compensations', body).then(onDone, (err: unknown) => {
            setBusy(false);
            setError(err);
          });
        }}
      >
        <div className="field">
          <label htmlFor="comp-user">{t('compUser')}</label>
          <input id="comp-user" className="ltr" value={f.user} onChange={set('user')} />
        </div>
        <div className="segmented wrap" role="group" aria-label={t('compKind')}>
          {COMP_KINDS.map((k) => (
            <button key={k} type="button" aria-pressed={f.kind === k} onClick={() => setF((v) => ({ ...v, kind: k }))}>
              {t(`compKind${k}`)}
            </button>
          ))}
        </div>
        {f.kind === 'COINS' ? (
          <div className="field">
            <label htmlFor="comp-coins">{t('compAmount')}</label>
            <input id="comp-coins" className="ltr" inputMode="numeric" value={f.coins} onChange={set('coins')} />
          </div>
        ) : (
          <div className="field">
            <label htmlFor="comp-days">{t('compDays')}</label>
            <input id="comp-days" className="ltr" inputMode="numeric" value={f.days} onChange={set('days')} placeholder={f.kind === 'ITEM' ? '7 / 14 / 30' : ''} />
          </div>
        )}
        {f.kind === 'VIP_DAYS' && (
          <div className="field">
            <label htmlFor="comp-tier">{t('compTier')}</label>
            <input id="comp-tier" className="ltr" value={f.tierCode} onChange={set('tierCode')} placeholder="VIP_1" />
          </div>
        )}
        {f.kind === 'ITEM' && (
          <div className="field">
            <label htmlFor="comp-item">{t('compItem')}</label>
            <input id="comp-item" className="ltr" value={f.itemCode} onChange={set('itemCode')} />
          </div>
        )}
        <div className="field">
          <label htmlFor="comp-reason">{t('reason')}</label>
          <textarea id="comp-reason" maxLength={500} value={f.reason} onChange={set('reason')} />
        </div>
        <div className="field">
          <label htmlFor="comp-code">{t('totpCode')}</label>
          <input id="comp-code" className="code-input" inputMode="numeric" autoComplete="one-time-code" maxLength={6} value={f.totpCode} onChange={set('totpCode')} />
        </div>
        <div className="actions">
          <button type="button" className="btn" onClick={onClose}>
            {t('cancel')}
          </button>
          <button type="submit" className="btn primary" disabled={!body || busy}>
            {t('compGrant')}
          </button>
        </div>
      </form>
    </Dialog>
  );
}

export function Compensations() {
  const { t, can, toast } = useApp();
  const owner = can('compensation.settings');
  const [status, setStatus] = useState<CompensationStatus | ''>(owner ? 'PENDING' : '');
  const settings = useAsync(() => api.get<CompensationSettings>('/admin/compensations/settings'), []);
  const list = useAsync(
    () => api.get<CompensationPage>('/admin/compensations', status ? { status } : {}),
    [status],
  );
  const [dialog, setDialog] = useState<'grant' | 'limits' | { decide: Compensation; approve: boolean } | null>(null);
  const done = () => {
    setDialog(null);
    toast(t('done'));
    settings.reload();
    list.reload();
  };
  return (
    <>
      <div className="page-head">
        <div>
          <h1>{t('compTitle')}</h1>
          <p className="muted small">{t('compSubtitle')}</p>
        </div>
        <button className="btn primary" onClick={() => setDialog('grant')}>
          <Icon name="plus" size={16} />
          {t('compGrant')}
        </button>
      </div>
      <ErrorAlert error={settings.error} />
      {settings.data && <LimitsCard settings={settings.data} onEdit={owner ? () => setDialog('limits') : undefined} />}
      <section className="card">
        <div className="card-head">
          <h2>{t('compHistory')}</h2>
          <div className="segmented wrap" role="group" aria-label={t('compStatus')}>
            <button type="button" aria-pressed={status === ''} onClick={() => setStatus('')}>
              {t('compAll')}
            </button>
            {COMP_STATUSES.map((s) => (
              <button key={s} type="button" aria-pressed={status === s} onClick={() => setStatus(s)}>
                {t(`compStatus${s}`)}
              </button>
            ))}
          </div>
        </div>
        <ErrorAlert error={list.error} />
        {list.data && (
          <CompensationTable
            rows={list.data.data}
            onDecide={can('compensation.approve') ? (row, approve) => setDialog({ decide: row, approve }) : undefined}
          />
        )}
      </section>
      {dialog === 'grant' && <GrantDialog onClose={() => setDialog(null)} onDone={done} />}
      {dialog === 'limits' && settings.data && (
        <FormDialog
          title={t('compEditLimits')}
          intro={<p className="muted small">{t('compLimitsNote', { zone: settings.data.timeZone })}</p>}
          fields={[
            { name: 'dailyLimitCoins', label: t('compDaily'), hint: String(settings.data.dailyLimitCoins) },
            { name: 'perGrantMaxCoins', label: t('compPerGrant'), hint: String(settings.data.perGrantMaxCoins) },
            reasonField(t),
            codeField(t),
          ]}
          confirmLabel={t('save')}
          submit={(v) =>
            api.put('/admin/compensations/settings', {
              dailyLimitCoins: Number(v.dailyLimitCoins),
              perGrantMaxCoins: Number(v.perGrantMaxCoins),
              reason: v.reason,
              totpCode: v.totpCode,
            })
          }
          onClose={() => setDialog(null)}
          onDone={done}
        />
      )}
      {dialog && typeof dialog === 'object' && dialog.approve && (
        <FormDialog
          title={t('compApprove')}
          fields={[{ name: 'note', label: t('compNote'), kind: 'textarea', required: false }, codeField(t)]}
          confirmLabel={t('compApprove')}
          submit={(v) =>
            api.post(`/admin/compensations/${dialog.decide.id}/approve`, {
              ...(v.note ? { note: v.note } : {}),
              totpCode: v.totpCode,
            })
          }
          onClose={() => setDialog(null)}
          onDone={done}
        />
      )}
      {dialog && typeof dialog === 'object' && !dialog.approve && (
        <FormDialog
          title={t('compReject')}
          fields={[reasonField(t)]}
          confirmLabel={t('compReject')}
          danger
          submit={(v) => api.post(`/admin/compensations/${dialog.decide.id}/reject`, { reason: v.reason })}
          onClose={() => setDialog(null)}
          onDone={done}
        />
      )}
    </>
  );
}
