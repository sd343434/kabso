import { useState } from 'react';
import { api } from '../api';
import { Dialog, ErrorAlert, Loading, UserCell, useAsync } from '../components';
import { useApp } from '../context';
import { formatDate } from '../format';
import type { Key } from '../i18n';

/**
 * D301 (owner, CONVENTIONS §10.112.5): «صندوق المؤسس» — the suggestions «اقتراح ميزة» and the confidential staff reports
 * «الإبلاغ عن موظف» users send from the owner's profile. `owner.inbox`: OWNER only (staff never see reports about
 * staff). Opening an item marks it read (audited); «تم» / «مقروء» / «إعادة كجديد» set its status (audited).
 */

export type InboxKind = 'FEATURE' | 'STAFF_REPORT';
export type InboxStatus = 'NEW' | 'READ' | 'DONE';
export interface InboxPerson {
  id: string;
  username: string | null;
  displayName: string | null;
  avatarUrl: string | null;
  staffId: string | null;
}
export interface InboxItem {
  id: string;
  kind: InboxKind;
  status: InboxStatus;
  text: string;
  category: string | null;
  sender: InboxPerson;
  staff: InboxPerson | null;
  imageCount: number;
  createdAt: string;
  readAt: string | null;
  doneAt: string | null;
}
export interface InboxPage {
  data: InboxItem[];
  counts: Record<InboxStatus, number>;
  nextCursor: string | null;
}

const STATUSES: (InboxStatus | null)[] = ['NEW', 'READ', 'DONE', null];
const KINDS: (InboxKind | null)[] = [null, 'FEATURE', 'STAFF_REPORT'];

/** The private picture's address (served by the API to the OWNER's session only). */
export const inboxImageUrl = (id: string, index: number) => `/api/v1/admin/owner-inbox/${id}/images/${index}`;

function Person({ p }: { p: InboxPerson | null }) {
  const { t } = useApp();
  if (!p) return <span className="muted">{t('oiStaffGone')}</span>;
  return (
    <span>
      <UserCell username={p.username ?? '—'} displayName={p.displayName ?? ''} avatarUrl={p.avatarUrl} />
      {p.staffId && <span className="badge ltr">{p.staffId}</span>}
    </span>
  );
}

/** The table (pure rendering: tested). */
export function InboxTable({ rows, onOpen }: { rows: InboxItem[]; onOpen?: (id: string) => void }) {
  const { t, lang } = useApp();
  if (rows.length === 0) return <p className="muted">{t('oiNone')}</p>;
  return (
    <table className="table" data-owner-inbox>
      <thead>
        <tr>
          <th>{t('oiDate')}</th>
          <th>
            {t('oiKindFEATURE')} / {t('oiKindSTAFF_REPORT')}
          </th>
          <th>{t('oiFrom')}</th>
          <th>{t('oiAbout')}</th>
          <th>{t('oiText')}</th>
          <th />
        </tr>
      </thead>
      <tbody>
        {rows.map((r) => (
          <tr key={r.id} data-item={r.id} data-status={r.status}>
            <td>
              {formatDate(r.createdAt, lang)}
              <br />
              <span className={`badge ${r.status === 'NEW' ? 'warn' : r.status === 'DONE' ? 'ok' : ''}`}>
                {t(`oiStatus${r.status}`)}
              </span>
            </td>
            <td>
              <span className={`badge ${r.kind === 'STAFF_REPORT' ? 'danger' : ''}`}>
                {t(`oiKind${r.kind}`)}
              </span>
              {r.category && <div className="small muted">{t(`oiCat${r.category}` as Key)}</div>}
            </td>
            <td>
              <Person p={r.sender} />
            </td>
            <td>{r.kind === 'STAFF_REPORT' ? <Person p={r.staff} /> : '—'}</td>
            <td className="clip">{r.text}</td>
            <td>
              {onOpen && (
                <button type="button" className="btn" onClick={() => onOpen(r.id)}>
                  {t('oiOpen')}
                </button>
              )}
            </td>
          </tr>
        ))}
      </tbody>
    </table>
  );
}

/** One item with its pictures and the status buttons (pure rendering: tested). */
export function InboxDetail({
  item,
  onStatus,
  onClose,
  onDelete,
}: {
  item: InboxItem;
  onStatus?: (status: InboxStatus) => void;
  onClose?: () => void;
  /** Owner (PP-58): kept until the owner deletes it. */
  onDelete?: () => void;
}) {
  const { t, lang } = useApp();
  return (
    <div className="card" data-owner-inbox-item={item.id}>
      <h2>
        <span className={`badge ${item.kind === 'STAFF_REPORT' ? 'danger' : ''}`}>
          {t(`oiKind${item.kind}`)}
        </span>{' '}
        <span className="badge">{t(`oiStatus${item.status}`)}</span>
      </h2>
      <dl className="facts">
        <dt>{t('oiDate')}</dt>
        <dd>{formatDate(item.createdAt, lang)}</dd>
        <dt>{t('oiFrom')}</dt>
        <dd>
          <Person p={item.sender} />
        </dd>
        {item.kind === 'STAFF_REPORT' && (
          <>
            <dt>{t('oiAbout')}</dt>
            <dd>
              <Person p={item.staff} />
            </dd>
            <dt>{t('oiReason')}</dt>
            <dd>{item.category ? t(`oiCat${item.category}` as Key) : '—'}</dd>
          </>
        )}
      </dl>
      <p className="prewrap" dir="auto">
        {item.text}
      </p>
      {item.imageCount > 0 && (
        <div className="photos">
          {Array.from({ length: item.imageCount }, (_, i) => (
            <img
              key={i}
              src={inboxImageUrl(item.id, i)}
              alt={`${t('oiImages')} ${i + 1}`}
              referrerPolicy="no-referrer"
            />
          ))}
        </div>
      )}
      <div className="row">
        {onStatus && item.status !== 'DONE' && (
          <button type="button" className="btn primary" onClick={() => onStatus('DONE')}>
            {t('oiMarkDone')}
          </button>
        )}
        {onStatus && item.status === 'DONE' && (
          <button type="button" className="btn" onClick={() => onStatus('READ')}>
            {t('oiMarkRead')}
          </button>
        )}
        {onStatus && item.status !== 'NEW' && (
          <button type="button" className="btn" onClick={() => onStatus('NEW')}>
            {t('oiMarkNew')}
          </button>
        )}
        {onDelete && (
          <button type="button" className="btn danger" data-delete onClick={onDelete}>
            {t('oiDelete')}
          </button>
        )}
        {onClose && (
          <button type="button" className="btn" onClick={onClose}>
            {t('oiClose')}
          </button>
        )}
      </div>
    </div>
  );
}

/** The confirm dialog of «حذف» (pure rendering: tested). */
export function DeleteConfirm({ onConfirm, onCancel }: { onConfirm: () => void; onCancel: () => void }) {
  const { t } = useApp();
  return (
    <Dialog title={t('oiDeleteTitle')} onClose={onCancel}>
      <p>{t('oiDeleteBody')}</p>
      <div className="row">
        <button type="button" className="btn danger" data-confirm-delete onClick={onConfirm}>
          {t('oiDeleteConfirm')}
        </button>
        <button type="button" className="btn" onClick={onCancel}>
          {t('oiCancel')}
        </button>
      </div>
    </Dialog>
  );
}

export function OwnerInbox() {
  const { t, toast } = useApp();
  const [confirming, setConfirming] = useState(false);
  const [status, setStatus] = useState<InboxStatus | null>('NEW');
  const [kind, setKind] = useState<InboxKind | null>(null);
  const [open, setOpen] = useState<InboxItem | null>(null);
  const [error, setError] = useState<unknown>(null);
  const list = useAsync(
    () =>
      api.get<InboxPage>('/admin/owner-inbox', {
        ...(status ? { status } : {}),
        ...(kind ? { kind } : {}),
      }),
    [status, kind],
  );
  const openItem = async (id: string) => {
    setError(null);
    try {
      setOpen(await api.get<InboxItem>(`/admin/owner-inbox/${id}`));
      list.reload();
    } catch (err) {
      setError(err);
    }
  };
  const setItemStatus = async (s: InboxStatus) => {
    if (!open) return;
    setError(null);
    try {
      setOpen(
        await api.put<InboxItem>(`/admin/owner-inbox/${open.id}/status`, {
          status: s,
        }),
      );
      list.reload();
    } catch (err) {
      setError(err);
    }
  };
  const removeItem = async () => {
    if (!open) return;
    setConfirming(false);
    setError(null);
    try {
      await api.del<void>(`/admin/owner-inbox/${open.id}`);
      setOpen(null);
      toast(t('oiDeleted'));
      list.reload();
    } catch (err) {
      setError(err);
    }
  };
  const counts = list.data?.counts;
  return (
    <div className="page" data-page="owner-inbox">
      <h1>{t('navOwnerInbox')}</h1>
      <p className="muted">{t('oiIntro')}</p>
      <div className="row">
        <div className="segmented wrap" role="group">
          {STATUSES.map((s) => (
            <button key={s ?? 'all'} type="button" aria-pressed={status === s} onClick={() => setStatus(s)}>
              {s ? `${t(`oiStatus${s}`)}${counts ? ` (${counts[s]})` : ''}` : t('oiAll')}
            </button>
          ))}
        </div>
        <div className="segmented wrap" role="group">
          {KINDS.map((k) => (
            <button key={k ?? 'all'} type="button" aria-pressed={kind === k} onClick={() => setKind(k)}>
              {k ? t(`oiKind${k}`) : t('oiAll')}
            </button>
          ))}
        </div>
      </div>
      <ErrorAlert error={list.error ?? error} />
      {open && (
        <InboxDetail
          item={open}
          onStatus={(s) => void setItemStatus(s)}
          onClose={() => setOpen(null)}
          onDelete={() => setConfirming(true)}
        />
      )}
      {confirming && (
        <DeleteConfirm onConfirm={() => void removeItem()} onCancel={() => setConfirming(false)} />
      )}
      {list.loading || !list.data ? (
        <Loading />
      ) : (
        <InboxTable rows={list.data.data} onOpen={(id) => void openItem(id)} />
      )}
    </div>
  );
}
