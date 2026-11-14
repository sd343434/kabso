import { useEffect, useMemo, useRef, useState, type ReactNode } from 'react';
import { api, downloadCsv, type Query } from '../api';
import { ErrorAlert, useAsync } from '../components';
import { useApp } from '../context';
import { formatNumber } from '../format';
import { isKey, type Key } from '../i18n';
import { readPref, writePref } from '../context';
import { Icon } from './icons';

/**
 * The panel's one table (D197, CONVENTIONS §10.60.1): every list of `/admin/*` that answers
 * `{data, total, page, pageSize}` — server-side pages, a whitelisted sort, filters, a text search, columns the
 * viewer can hide (remembered in this browser only), the CSV export of the server (audited there), and honest
 * loading / empty / error states.
 */
export interface Column<T> {
  key: string;
  label: Key;
  render: (row: T) => ReactNode;
  /** The server's `sort` value when this column sorts. */
  sort?: string;
  /** Hidden until the viewer shows it. */
  optional?: boolean;
  numeric?: boolean;
  width?: string;
}

export interface FilterSpec {
  name: string;
  label: Key;
  options: { value: string; label: Key | string }[];
}

export interface TablePage<T> {
  data: T[];
  total: number;
  page: number;
  pageSize: number;
}

/** Pages to show around the current one: 1 … 4 5 [6] 7 8 … 20. */
export function pageWindow(page: number, pages: number): (number | '…')[] {
  if (pages <= 7) return Array.from({ length: pages }, (_, i) => i + 1);
  const out: (number | '…')[] = [1];
  const from = Math.max(2, page - 1);
  const to = Math.min(pages - 1, page + 1);
  if (from > 2) out.push('…');
  for (let p = from; p <= to; p++) out.push(p);
  if (to < pages - 1) out.push('…');
  out.push(pages);
  return out;
}

export function DataTable<T>({
  id,
  endpoint,
  columns,
  rowKey,
  defaultSort,
  filters = [],
  extraQuery = {},
  searchLabel,
  csv,
  onRowClick,
  reloadKey,
  header,
  pageSize: initialSize = 25,
  onLoaded,
}: {
  id: string;
  endpoint: string;
  columns: Column<T>[];
  rowKey: (row: T) => string;
  defaultSort?: { sort: string; order: 'asc' | 'desc' };
  filters?: FilterSpec[];
  extraQuery?: Query;
  searchLabel?: Key;
  csv?: boolean;
  onRowClick?: (row: T) => void;
  reloadKey?: unknown;
  header?: ReactNode;
  pageSize?: number;
  onLoaded?: (page: TablePage<T> & Record<string, unknown>) => void;
}) {
  const { t, lang, toast } = useApp();
  const [page, setPage] = useState(1);
  const [pageSize, setPageSize] = useState(initialSize);
  const [sort, setSort] = useState(defaultSort);
  const [q, setQ] = useState('');
  const [typed, setTyped] = useState('');
  const [values, setValues] = useState<Record<string, string>>({});
  const prefKey = `kabso-admin-cols-${id}`;
  const [hidden, setHidden] = useState<Set<string>>(() => {
    const saved = readPref(prefKey);
    if (saved) {
      try {
        return new Set(JSON.parse(saved) as string[]);
      } catch {
        // a broken preference: the defaults
      }
    }
    return new Set(columns.filter((c) => c.optional).map((c) => c.key));
  });
  const [colsOpen, setColsOpen] = useState(false);
  const [exporting, setExporting] = useState(false);
  const [exportError, setExportError] = useState<unknown>(null);
  const colsRef = useRef<HTMLDivElement>(null);

  // A search waits for the typing to pause.
  useEffect(() => {
    const h = window.setTimeout(() => {
      setQ(typed.trim());
      setPage(1);
    }, 300);
    return () => window.clearTimeout(h);
  }, [typed]);

  useEffect(() => {
    if (!colsOpen) return;
    const close = (e: MouseEvent) => {
      if (colsRef.current && !colsRef.current.contains(e.target as Node)) setColsOpen(false);
    };
    window.addEventListener('mousedown', close);
    return () => window.removeEventListener('mousedown', close);
  }, [colsOpen]);

  const query: Query = useMemo(
    () => ({
      ...extraQuery,
      ...values,
      ...(q ? { q } : {}),
      ...(sort ? { sort: sort.sort, order: sort.order } : {}),
    }),
    [extraQuery, values, q, sort],
  );
  const { data, error, loading, reload } = useAsync(
    () => api.get<TablePage<T> & Record<string, unknown>>(endpoint, { ...query, page, pageSize }),
    [endpoint, JSON.stringify(query), page, pageSize, reloadKey],
  );
  useEffect(() => {
    if (data) onLoaded?.(data);
  }, [data]);
  const visible = columns.filter((c) => !hidden.has(c.key));
  const pages = data ? Math.max(1, Math.ceil(data.total / data.pageSize)) : 1;
  const toggleSort = (c: Column<T>) => {
    const key = c.sort;
    if (!key) return;
    setPage(1);
    setSort((s) => (s && s.sort === key ? { sort: key, order: s.order === 'asc' ? 'desc' : 'asc' } : { sort: key, order: 'desc' }));
  };

  return (
    <div className="table-card card">
      <div className="table-tools">
        {header}
        {searchLabel && (
          <label className="search-field">
            <Icon name="search" size={18} />
            <input type="search" placeholder={t(searchLabel)} aria-label={t(searchLabel)} value={typed} onChange={(e) => setTyped(e.target.value)} />
          </label>
        )}
        {filters.map((f) => (
          <select
            key={f.name}
            aria-label={t(f.label)}
            value={values[f.name] ?? ''}
            onChange={(e) => {
              setPage(1);
              setValues((v) => ({ ...v, [f.name]: e.target.value }));
            }}
          >
            <option value="">{t(f.label)}</option>
            {f.options.map((o) => (
              <option key={o.value} value={o.value}>
                {isKey(o.label) ? t(o.label) : o.label}
              </option>
            ))}
          </select>
        ))}
        <span className="spacer" />
        <div className="cols-menu" ref={colsRef}>
          <button type="button" className="btn small ghost" aria-expanded={colsOpen} onClick={() => setColsOpen((o) => !o)}>
            <Icon name="columns" size={16} />
            {t('tableColumns')}
          </button>
          {colsOpen && (
            <div className="menu" role="menu">
              {columns.map((c) => (
                <label key={c.key} className="check" role="menuitemcheckbox" aria-checked={!hidden.has(c.key)}>
                  <input
                    type="checkbox"
                    checked={!hidden.has(c.key)}
                    onChange={() =>
                      setHidden((h) => {
                        const next = new Set(h);
                        if (next.has(c.key)) next.delete(c.key);
                        else if (columns.length - next.size > 1) next.add(c.key);
                        writePref(prefKey, JSON.stringify([...next]));
                        return next;
                      })
                    }
                  />
                  {t(c.label)}
                </label>
              ))}
            </div>
          )}
        </div>
        {csv && (
          <button
            type="button"
            className="btn small"
            disabled={exporting || !data || data.total === 0}
            onClick={() => {
              setExporting(true);
              setExportError(null);
              downloadCsv(endpoint, query, `kabso-${id}.csv`).then(
                () => {
                  setExporting(false);
                  toast(t('tableExported'));
                },
                (e: unknown) => {
                  setExporting(false);
                  setExportError(e);
                },
              );
            }}
          >
            <Icon name="download" size={16} />
            {t('tableCsv')}
          </button>
        )}
      </div>
      <ErrorAlert error={exportError} />
      {error ? (
        <div className="state error-state">
          <ErrorAlert error={error} />
          <button className="btn small" onClick={reload}>
            {t('retry')}
          </button>
        </div>
      ) : (
        <div className="table-wrap" aria-busy={loading}>
          <table>
            <thead>
              <tr>
                {visible.map((c) => (
                  <th
                    key={c.key}
                    className={c.numeric ? 'num' : undefined}
                    style={c.width ? { width: c.width } : undefined}
                    aria-sort={sort && c.sort === sort.sort ? (sort.order === 'asc' ? 'ascending' : 'descending') : undefined}
                  >
                    {c.sort ? (
                      <button type="button" className="sort" onClick={() => toggleSort(c)}>
                        {t(c.label)}
                        {sort?.sort === c.sort && <Icon name={sort.order === 'asc' ? 'arrowUp' : 'arrowDown'} size={14} />}
                      </button>
                    ) : (
                      t(c.label)
                    )}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              {loading && !data
                ? Array.from({ length: 5 }, (_, i) => (
                    <tr key={`s${i}`} className="skeleton-row">
                      {visible.map((c) => (
                        <td key={c.key}>
                          <span className="skeleton" />
                        </td>
                      ))}
                    </tr>
                  ))
                : data?.data.map((row) => (
                    <tr
                      key={rowKey(row)}
                      className={onRowClick ? 'clickable' : undefined}
                      onClick={onRowClick ? () => onRowClick(row) : undefined}
                      tabIndex={onRowClick ? 0 : undefined}
                      onKeyDown={onRowClick ? (e) => e.key === 'Enter' && onRowClick(row) : undefined}
                    >
                      {visible.map((c) => (
                        <td key={c.key} className={c.numeric ? 'num' : undefined}>
                          {c.render(row)}
                        </td>
                      ))}
                    </tr>
                  ))}
            </tbody>
          </table>
          {data && data.data.length === 0 && (
            <div className="state empty-state">
              <Icon name="inbox" size={28} />
              <p>{t('empty')}</p>
            </div>
          )}
        </div>
      )}
      {data && data.total > 0 && (
        <div className="table-foot">
          <span className="muted small">
            {t('tableRange', {
              from: formatNumber((data.page - 1) * data.pageSize + 1, lang),
              to: formatNumber(Math.min(data.total, data.page * data.pageSize), lang),
              total: formatNumber(data.total, lang),
            })}
          </span>
          <select
            aria-label={t('tablePageSize')}
            value={pageSize}
            onChange={(e) => {
              setPage(1);
              setPageSize(Number(e.target.value));
            }}
          >
            {[10, 25, 50, 100].map((n) => (
              <option key={n} value={n}>
                {n}
              </option>
            ))}
          </select>
          <nav className="pages" aria-label={t('tablePages')}>
            <button className="btn small ghost flip" disabled={page <= 1} onClick={() => setPage(page - 1)} aria-label={t('previous')}>
              <Icon name="chevron" size={16} />
            </button>
            {pageWindow(page, pages).map((p, i) =>
              p === '…' ? (
                <span key={`e${i}`} className="muted">
                  …
                </span>
              ) : (
                <button key={p} className={`btn small ${p === page ? 'primary' : 'ghost'}`} aria-current={p === page ? 'page' : undefined} onClick={() => setPage(p)}>
                  {p}
                </button>
              ),
            )}
            <button className="btn small ghost" disabled={page >= pages} onClick={() => setPage(page + 1)} aria-label={t('next')}>
              <Icon name="chevron" size={16} />
            </button>
          </nav>
        </div>
      )}
    </div>
  );
}
