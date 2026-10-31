import { StatusBadge, UserCell } from '../components';
import { useApp } from '../context';
import { formatDate } from '../format';
import { navigate } from '../router';
import { DataTable } from '../ui/DataTable';

interface UsersRow {
  id: string;
  username: string;
  displayName: string;
  email: string;
  status: string;
  role: string;
  avatarUrl: string | null;
  countryCode: string | null;
  createdAt: string;
  lastActiveAt: string | null;
}

/** The users table (D197): pages, sort, status / role filters, search, columns, CSV (users.export, audited). */
export function Users() {
  const { t, lang, can } = useApp();
  return (
    <>
      <div className="page-head">
        <div>
          <h1>{t('usersTitle')}</h1>
          <p className="muted small">{t('usersSubtitle')}</p>
        </div>
      </div>
      <DataTable<UsersRow>
        id="users"
        endpoint="/admin/tables/users"
        rowKey={(r) => r.id}
        defaultSort={{ sort: 'createdAt', order: 'desc' }}
        searchLabel="usersSearch"
        csv={can('users.export')}
        onRowClick={(r) => navigate(`/users/${r.id}`)}
        filters={[
          {
            name: 'status',
            label: 'colStatus',
            options: [
              { value: 'ACTIVE', label: 'statusACTIVE' },
              { value: 'SUSPENDED', label: 'statusSUSPENDED' },
              { value: 'DELETED', label: 'statusDELETED' },
            ],
          },
          { name: 'role', label: 'userRole', options: [{ value: 'USER', label: 'roleUser' }, { value: 'ADMIN', label: 'roleAdmin' }] },
        ]}
        columns={[
          { key: 'user', label: 'colUser', sort: 'username', render: (r) => <UserCell username={r.username} displayName={r.displayName} avatarUrl={r.avatarUrl} /> },
          { key: 'email', label: 'colEmail', sort: 'email', render: (r) => <span className="ltr">{r.email}</span> },
          { key: 'status', label: 'colStatus', render: (r) => <StatusBadge status={r.status} /> },
          { key: 'role', label: 'userRole', render: (r) => (r.role === 'ADMIN' ? <span className="badge info">{t('roleAdmin')}</span> : t('roleUser')) },
          { key: 'country', label: 'userCountry', optional: true, render: (r) => r.countryCode ?? t('none') },
          { key: 'joined', label: 'colJoined', sort: 'createdAt', render: (r) => <span className="date">{formatDate(r.createdAt, lang)}</span> },
          { key: 'active', label: 'userLastActive', sort: 'lastActiveAt', render: (r) => <span className="date">{formatDate(r.lastActiveAt, lang)}</span> },
          { key: 'id', label: 'colId', optional: true, render: (r) => <span className="mono small">{r.id}</span> },
        ]}
      />
    </>
  );
}
