import { useState } from 'react';
import { api } from '../api';
import { ErrorAlert, FormDialog, reasonField, StatusBadge, useAsync, UserCell } from '../components';
import { useApp } from '../context';
import { formatDate } from '../format';
import type { AccountCategory, AdminUserCategory, CategoryRequestRow } from '../types';
import { DataTable } from '../ui/DataTable';
import { StatusTabs } from './Applications';

/**
 * D386 (v1.138-social, CONVENTIONS §10.175.5): the account category in the panel. Only a category the Kabso Team
 * verified changes a person's profile page in the app (owner «الموثقة»). The user page shows the category, whether it
 * is verified or locked and the latest request, with VERIFY / UNVERIFY / CLEAR / LOCK / UNLOCK (each with a reason,
 * audited, the person notified); «طلبات توثيق الفئة» lists the requests with approve / reject. Reading is
 * `users.control_view`; acting `users.profile_edit` (the server checks every request again).
 */
export type CategoryAction = 'VERIFY' | 'UNVERIFY' | 'CLEAR' | 'LOCK' | 'UNLOCK';

const STATUSES = ['PENDING', 'APPROVED', 'REJECTED', 'CANCELLED', ''] as const;

/** The category's name in the panel's language. */
export function useCategoryName() {
  const { t } = useApp();
  return (c: AccountCategory | null) => (c ? t(`cat${c}`) : t('catNone'));
}

/** The actions that change something now (a no-op is not offered). */
export function categoryActions(state: AdminUserCategory): CategoryAction[] {
  return [
    ...(state.category !== null && !state.verified ? (['VERIFY'] as const) : []),
    ...(state.verified ? (['UNVERIFY'] as const) : []),
    ...(state.category !== null ? (['CLEAR'] as const) : []),
    ...(state.locked ? (['UNLOCK'] as const) : (['LOCK'] as const)),
  ];
}

/** The user page's block (pure: rendered in the tests). */
export function UserCategoryView({
  state,
  onAction,
}: {
  state: AdminUserCategory;
  onAction: (a: CategoryAction) => void;
}) {
  const { t, lang, can } = useApp();
  const name = useCategoryName();
  return (
    <div className="card" data-category-block={state.category ?? 'none'}>
      <h2>{t('catBlockTitle')}</h2>
      <dl className="kv">
        <dt>{t('catBlockTitle')}</dt>
        <dd>
          <strong>{name(state.category)}</strong>{' '}
          {state.category && (
            <span className={`badge ${state.verified ? 'ok' : ''}`} data-category-verified={state.verified}>
              {state.verified ? `✓ ${t('catVerified')}` : t('catNotVerified')}
            </span>
          )}{' '}
          {state.locked && (
            <span className="badge warn" data-category-locked="true">
              {t('catLocked')}
            </span>
          )}
          {state.verified && state.verifiedAt && (
            <span className="muted small">
              {' '}
              · {formatDate(state.verifiedAt, lang)}
              {state.verifiedBy ? ` · @${state.verifiedBy.username}` : ''}
            </span>
          )}
        </dd>
        {state.request && (
          <>
            <dt>{t('catLatestRequest')}</dt>
            <dd>
              {name(state.request.category)} <StatusBadge status={state.request.status} />{' '}
              <span className="date small">{formatDate(state.request.createdAt, lang)}</span>
              {state.request.rejectReason && <div className="muted small">{state.request.rejectReason}</div>}
            </dd>
          </>
        )}
      </dl>
      {state.kabsoTeam && <p className="muted small">{t('catTeamHidden')}</p>}
      {can('users.profile_edit') && (
        <div className="row actions-row">
          {categoryActions(state).map((a) => (
            <button
              key={a}
              className={`btn ${a === 'CLEAR' ? 'danger' : a === 'VERIFY' ? 'primary' : ''}`}
              data-category-action={a}
              onClick={() => onAction(a)}
            >
              {t(`catAction${a}`)}
            </button>
          ))}
        </div>
      )}
    </div>
  );
}

/** The user page's block, read and acted on. */
export function UserCategoryBlock({ userId }: { userId: string }) {
  const { t, toast } = useApp();
  const state = useAsync(() => api.get<AdminUserCategory>(`/admin/users/${userId}/category`), [userId]);
  const [action, setAction] = useState<CategoryAction | null>(null);
  if (!state.data) return <ErrorAlert error={state.error} />;
  return (
    <>
      <UserCategoryView state={state.data} onAction={setAction} />
      {action && (
        <FormDialog
          title={t(`catAction${action}`)}
          fields={[reasonField(t)]}
          confirmLabel={t(`catAction${action}`)}
          danger={action === 'CLEAR'}
          submit={(v) => api.post(`/admin/users/${userId}/category`, { action, reason: v.reason })}
          onClose={() => setAction(null)}
          onDone={() => {
            setAction(null);
            toast(t('done'));
            state.reload();
          }}
        />
      )}
    </>
  );
}

/** «طلبات توثيق الفئة». */
export function CategoryRequests() {
  const { t, lang, can, toast } = useApp();
  const name = useCategoryName();
  const [status, setStatus] = useState<(typeof STATUSES)[number]>('PENDING');
  const [bump, setBump] = useState(0);
  const [rejecting, setRejecting] = useState<string | null>(null);
  const [error, setError] = useState<unknown>(null);
  const decide = can('users.profile_edit');
  const approve = (id: string) => {
    setError(null);
    api.post(`/admin/category-requests/${id}/approve`, {}).then(
      () => {
        toast(t('done'));
        setBump((b) => b + 1);
      },
      (e: unknown) => setError(e),
    );
  };
  return (
    <>
      <div className="page-head">
        <div>
          <h1>{t('catReqTitle')}</h1>
          <p className="muted small">{t('catReqSubtitle')}</p>
        </div>
        <StatusTabs value={status} options={STATUSES} onChange={setStatus} />
      </div>
      <ErrorAlert error={error} />
      <DataTable<CategoryRequestRow>
        key={bump}
        id="category-requests"
        endpoint="/admin/category-requests"
        rowKey={(r) => r.id}
        extraQuery={{ status: status || undefined }}
        defaultSort={{ sort: 'createdAt', order: 'desc' }}
        searchLabel="usersSearch"
        csv
        columns={[
          { key: 'user', label: 'colUser', render: (r) => <UserCell username={r.user.username} displayName={r.user.displayName} avatarUrl={r.user.avatarUrl} /> },
          { key: 'category', label: 'catReqCategory', render: (r) => name(r.category) },
          { key: 'current', label: 'catReqCurrent', render: (r) => name(r.currentCategory) },
          { key: 'note', label: 'catReqNote', optional: true, render: (r) => r.note ?? '—' },
          { key: 'status', label: 'colStatus', render: (r) => <StatusBadge status={r.status} /> },
          { key: 'created', label: 'colSubmitted', sort: 'createdAt', render: (r) => <span className="date small">{formatDate(r.createdAt, lang)}</span> },
          { key: 'decided', label: 'colDecided', sort: 'decidedAt', render: (r) => <span className="date small">{formatDate(r.decidedAt, lang)}</span> },
          {
            key: 'actions',
            label: 'colActions',
            render: (r) =>
              decide && r.status === 'PENDING' ? (
                <span className="row">
                  <button className="btn primary small" data-approve={r.id} onClick={() => approve(r.id)}>
                    {t('catReqApprove')}
                  </button>
                  <button className="btn danger small" data-reject={r.id} onClick={() => setRejecting(r.id)}>
                    {t('catReqReject')}
                  </button>
                </span>
              ) : (
                '—'
              ),
          },
        ]}
      />
      {rejecting && (
        <FormDialog
          title={t('catReqReject')}
          fields={[reasonField(t, t('catReqRejectReason'))]}
          confirmLabel={t('catReqReject')}
          danger
          submit={(v) => api.post(`/admin/category-requests/${rejecting}/reject`, { reason: v.reason })}
          onClose={() => setRejecting(null)}
          onDone={() => {
            setRejecting(null);
            toast(t('done'));
            setBump((b) => b + 1);
          }}
        />
      )}
    </>
  );
}
