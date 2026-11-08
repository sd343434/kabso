import { useState } from 'react';
import { api } from '../api';
import { Dialog, ErrorAlert, Loading, useAsync } from '../components';
import { useApp } from '../context';
import { formatMoney } from '../format';

/**
 * D301 follow-up (owner 2026-11-07: «تكاليف ثابتة مثلاً اشتراك كلاود و لايف كيت والفلاتر والسيرفرات، هذه التكاليف الشهرية
 * يتم تقسيمها على الشهر»; CONVENTIONS §10.112.10): the owner's fixed monthly costs of «الربح» — `owner.costs`, OWNER
 * only. Add, edit and delete (with a confirmation); every change is audited (`via: panel`). The app's «لوحة المؤسس»
 * divides each over the days of its month.
 */

export interface FixedCost {
  id: string;
  name: string;
  monthlyMinor: number;
  currency: 'USD';
  activeFrom: string;
  activeTo: string | null;
  createdAt: string;
  updatedAt: string;
}

export interface FixedCostDraft {
  name: string;
  /** US dollars as typed. */
  amount: string;
  activeFrom: string;
  activeTo: string;
}

/** The request body of a draft, or null when it is not valid (a name, a positive amount, the end not before the start). */
export function draftBody(d: FixedCostDraft) {
  const name = d.name.trim();
  const amount = Number(d.amount.trim().replace(',', '.'));
  if (!name || !Number.isFinite(amount) || amount <= 0) return null;
  if (!/^\d{4}-\d{2}-\d{2}$/.test(d.activeFrom)) return null;
  if (d.activeTo && (!/^\d{4}-\d{2}-\d{2}$/.test(d.activeTo) || d.activeTo < d.activeFrom)) return null;
  return {
    name,
    monthlyMinor: Math.round(amount * 100),
    activeFrom: d.activeFrom,
    activeTo: d.activeTo || null,
  };
}

/** The table (pure rendering: tested). */
export function FixedCostsTable({
  rows,
  today,
  onEdit,
  onDelete,
}: {
  rows: FixedCost[];
  today: string;
  onEdit?: (c: FixedCost) => void;
  onDelete?: (c: FixedCost) => void;
}) {
  const { t, lang } = useApp();
  if (rows.length === 0) return <p className="muted">{t('fcNone')}</p>;
  return (
    <table className="table" data-fixed-costs>
      <thead>
        <tr>
          <th>{t('fcName')}</th>
          <th>{t('fcMonthly')}</th>
          <th>{t('fcPerDay')}</th>
          <th>{t('fcFrom')}</th>
          <th>{t('fcTo')}</th>
          <th />
        </tr>
      </thead>
      <tbody>
        {rows.map((c) => {
          const active = c.activeFrom <= today && (c.activeTo === null || c.activeTo >= today);
          return (
            <tr key={c.id} data-cost={c.id} data-active={active ? 'yes' : 'no'}>
              <td>
                {c.name}{' '}
                {!active && <span className="badge">{t(c.activeFrom > today ? 'fcLater' : 'fcEnded')}</span>}
              </td>
              <td className="ltr">{formatMoney(c.monthlyMinor, 'USD', lang)}</td>
              <td className="ltr small muted">{formatMoney(Math.round(c.monthlyMinor / 30), 'USD', lang)}</td>
              <td className="ltr">{c.activeFrom}</td>
              <td className="ltr">{c.activeTo ?? t('fcOngoing')}</td>
              <td>
                {onEdit && (
                  <button type="button" className="btn" data-edit onClick={() => onEdit(c)}>
                    {t('fcEdit')}
                  </button>
                )}{' '}
                {onDelete && (
                  <button type="button" className="btn danger" data-delete onClick={() => onDelete(c)}>
                    {t('fcDelete')}
                  </button>
                )}
              </td>
            </tr>
          );
        })}
      </tbody>
    </table>
  );
}

/** Add or edit (pure rendering: tested). */
export function FixedCostForm({
  draft,
  editing,
  onChange,
  onSave,
  onCancel,
}: {
  draft: FixedCostDraft;
  editing: boolean;
  onChange: (d: FixedCostDraft) => void;
  onSave: () => void;
  onCancel: () => void;
}) {
  const { t } = useApp();
  const valid = draftBody(draft) !== null;
  return (
    <div className="card" data-fixed-cost-form>
      <h2>{t(editing ? 'fcEditTitle' : 'fcAdd')}</h2>
      <p className="muted small">{t('fcHint')}</p>
      <div className="field">
        <label htmlFor="fc-name">{t('fcName')}</label>
        <input
          id="fc-name"
          maxLength={60}
          placeholder={t('fcNameHint')}
          value={draft.name}
          onChange={(e) => onChange({ ...draft, name: e.target.value })}
        />
      </div>
      <div className="field">
        <label htmlFor="fc-amount">{t('fcMonthly')}</label>
        <input
          id="fc-amount"
          className="ltr"
          inputMode="decimal"
          value={draft.amount}
          onChange={(e) => onChange({ ...draft, amount: e.target.value.replace(/[^0-9.,]/g, '') })}
        />
      </div>
      <div className="row">
        <div className="field">
          <label htmlFor="fc-from">{t('fcFrom')}</label>
          <input
            id="fc-from"
            type="date"
            className="ltr"
            value={draft.activeFrom}
            onChange={(e) => onChange({ ...draft, activeFrom: e.target.value })}
          />
        </div>
        <div className="field">
          <label htmlFor="fc-to">{t('fcTo')}</label>
          <input
            id="fc-to"
            type="date"
            className="ltr"
            value={draft.activeTo}
            onChange={(e) => onChange({ ...draft, activeTo: e.target.value })}
          />
        </div>
      </div>
      <div className="row">
        <button type="button" className="btn primary" data-save disabled={!valid} onClick={onSave}>
          {t('fcSave')}
        </button>
        <button type="button" className="btn" onClick={onCancel}>
          {t('oiCancel')}
        </button>
      </div>
    </div>
  );
}

const todayKey = () => new Date().toISOString().slice(0, 10);

export function OwnerFixedCosts() {
  const { t, toast } = useApp();
  const list = useAsync(() => api.get<{ items: FixedCost[] }>('/admin/owner-fixed-costs'), []);
  const [draft, setDraft] = useState<FixedCostDraft | null>(null);
  const [editing, setEditing] = useState<FixedCost | null>(null);
  const [deleting, setDeleting] = useState<FixedCost | null>(null);
  const [error, setError] = useState<unknown>(null);
  const run = async (action: () => Promise<unknown>, done: string) => {
    setError(null);
    try {
      await action();
      toast(t(done as 'fcSaved'));
      list.reload();
      return true;
    } catch (err) {
      setError(err);
      return false;
    }
  };
  const save = async () => {
    const body = draft && draftBody(draft);
    if (!body) return;
    const ok = await run(
      () =>
        editing
          ? api.patch<FixedCost>(`/admin/owner-fixed-costs/${editing.id}`, body)
          : api.post<FixedCost>('/admin/owner-fixed-costs', body),
      'fcSaved',
    );
    if (ok) {
      setDraft(null);
      setEditing(null);
    }
  };
  const remove = async () => {
    const c = deleting;
    setDeleting(null);
    if (c) await run(() => api.del<void>(`/admin/owner-fixed-costs/${c.id}`), 'oiDeleted');
  };
  return (
    <div className="page" data-page="owner-fixed-costs">
      <h1>{t('navOwnerFixedCosts')}</h1>
      <p className="muted">{t('fcIntro')}</p>
      <ErrorAlert error={list.error ?? error} />
      {draft ? (
        <FixedCostForm
          draft={draft}
          editing={editing !== null}
          onChange={setDraft}
          onSave={() => void save()}
          onCancel={() => {
            setDraft(null);
            setEditing(null);
          }}
        />
      ) : (
        <div className="row">
          <button
            type="button"
            className="btn primary"
            data-add
            onClick={() => setDraft({ name: '', amount: '', activeFrom: todayKey(), activeTo: '' })}
          >
            {t('fcAdd')}
          </button>
        </div>
      )}
      {deleting && (
        <Dialog title={t('fcDeleteTitle')} onClose={() => setDeleting(null)}>
          <p>{t('fcDeleteBody', { name: deleting.name })}</p>
          <div className="row">
            <button type="button" className="btn danger" data-confirm-delete onClick={() => void remove()}>
              {t('fcDelete')}
            </button>
            <button type="button" className="btn" onClick={() => setDeleting(null)}>
              {t('oiCancel')}
            </button>
          </div>
        </Dialog>
      )}
      {list.loading || !list.data ? (
        <Loading />
      ) : (
        <FixedCostsTable
          rows={list.data.items}
          today={todayKey()}
          onEdit={(c) => {
            setEditing(c);
            setDraft({
              name: c.name,
              amount: (c.monthlyMinor / 100).toFixed(2),
              activeFrom: c.activeFrom,
              activeTo: c.activeTo ?? '',
            });
          }}
          onDelete={setDeleting}
        />
      )}
    </div>
  );
}
