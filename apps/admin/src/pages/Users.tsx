import { useState } from 'react';
import { api } from '../api';
import { ErrorAlert, Loading, StatusBadge, useAsync, UserCell } from '../components';
import { useApp } from '../context';
import { formatDate } from '../format';
import { navigate, useLocation } from '../router';
import type { UserRow } from '../types';

export function Users() {
  const { t, lang } = useApp();
  const { search } = useLocation();
  const q = search.get('q') ?? '';
  const [text, setText] = useState(q);
  const { data, error, loading } = useAsync(
    () => (q ? api.get<{ data: UserRow[] }>('/admin/users', { q, limit: 50 }) : Promise.resolve(null)),
    [q],
  );
  return (
    <>
      <div className="page-head">
        <h1>{t('usersTitle')}</h1>
      </div>
      <form
        className="row"
        style={{ marginBottom: 16 }}
        onSubmit={(e) => {
          e.preventDefault();
          if (text.trim()) navigate(`/users?q=${encodeURIComponent(text.trim())}`);
        }}
      >
        <input
          type="search"
          aria-label={t('usersSearch')}
          placeholder={t('usersSearch')}
          value={text}
          onChange={(e) => setText(e.target.value)}
          style={{ flex: '1 1 280px', width: 'auto' }}
        />
        <button className="btn primary" disabled={!text.trim()}>
          {t('search')}
        </button>
      </form>
      <ErrorAlert error={error} />
      {q && loading && <Loading />}
      {data && data.data.length === 0 && <p className="muted">{t('empty')}</p>}
      {data && data.data.length > 0 && (
        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>{t('colUser')}</th>
                <th>{t('colEmail')}</th>
                <th>{t('colStatus')}</th>
                <th>{t('colJoined')}</th>
              </tr>
            </thead>
            <tbody>
              {data.data.map((u) => (
                <tr key={u.id} className="clickable" onClick={() => navigate(`/users/${u.id}`)}>
                  <td>
                    <a href={`/users/${u.id}`} onClick={(e) => e.preventDefault()} style={{ color: 'inherit', textDecoration: 'none' }}>
                      <UserCell username={u.username} displayName={u.displayName} avatarUrl={u.avatarUrl} />
                    </a>
                  </td>
                  <td className="ltr">{u.email}</td>
                  <td>
                    <StatusBadge status={u.status} />
                  </td>
                  <td className="date">{formatDate(u.createdAt, lang)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </>
  );
}
