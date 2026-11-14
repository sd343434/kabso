import { useState } from 'react';
import { api } from '../api';
import { Dialog, useAsync } from '../components';
import { useApp } from '../context';
import { formatDate } from '../format';
import type { AuditRow } from '../types';
import { DataTable } from '../ui/DataTable';

/** A metadata value as short text. */
export function metaText(v: unknown): string {
  if (v === null || v === undefined) return '—';
  if (typeof v === 'string') return v;
  if (typeof v === 'number' || typeof v === 'boolean') return String(v);
  return JSON.stringify(v);
}

/**
 * The before / after of an audit row: `before` + `after`, or a `changes` map `{field: {from, to}}` (gift updates),
 * as pairs; everything else as key = value.
 */
export function diffOf(meta: Record<string, unknown>): { field: string; before: string; after: string }[] {
  const out: { field: string; before: string; after: string }[] = [];
  if ('before' in meta || 'after' in meta) out.push({ field: '', before: metaText(meta.before), after: metaText(meta.after) });
  const changes = meta.changes;
  if (changes && typeof changes === 'object' && !Array.isArray(changes)) {
    for (const [field, c] of Object.entries(changes as Record<string, { from?: unknown; to?: unknown }>)) {
      out.push({ field, before: metaText(c.from), after: metaText(c.to) });
    }
  }
  return out;
}

export function AuditMeta({ meta }: { meta: Record<string, unknown> }) {
  const diff = diffOf(meta);
  const rest = Object.entries(meta).filter(([k]) => !['before', 'after', 'changes', 'via'].includes(k));
  return (
    <span className="audit-meta">
      {diff.map((d) => (
        <span key={d.field || 'state'} className="diff">
          {d.field && <span className="mono small">{d.field}: </span>}
          <del>{d.before}</del> → <ins>{d.after}</ins>
        </span>
      ))}
      {rest.slice(0, 3).map(([k, v]) => (
        <span key={k} className="small muted kvp">
          {k}: <span className="clip-sm">{metaText(v)}</span>
        </span>
      ))}
    </span>
  );
}

/**
 * The audit log (D197, OWNER): filters actor (username or id), action (exact or a prefix such as `admin.`),
 * target type and id, dates; each row's before/after; the full row in a dialog; CSV (audited).
 */
export function Audit() {
  const { t, lang } = useApp();
  const actions = useAsync(() => api.get<{ data: string[] }>('/admin/audit/actions'), []);
  const [actor, setActor] = useState('');
  const [targetId, setTargetId] = useState('');
  const [from, setFrom] = useState('');
  const [to, setTo] = useState('');
  const [open, setOpen] = useState<AuditRow | null>(null);
  const prefixes = [...new Set((actions.data?.data ?? []).map((a) => `${a.split('.')[0]}.`))];
  return (
    <>
      <div className="page-head">
        <div>
          <h1>{t('auditTitle')}</h1>
          <p className="muted small">{t('auditSubtitle')}</p>
        </div>
      </div>
      <div className="filters card">
        <label className="field">
          <span>{t('colActor')}</span>
          <input type="text" className="ltr" placeholder="@username" value={actor} onChange={(e) => setActor(e.target.value)} />
        </label>
        <label className="field">
          <span>{t('auditTarget')}</span>
          <input type="text" className="ltr" placeholder="uuid / code" value={targetId} onChange={(e) => setTargetId(e.target.value)} />
        </label>
        <label className="field">
          <span>{t('from')}</span>
          <input type="date" value={from} onChange={(e) => setFrom(e.target.value)} />
        </label>
        <label className="field">
          <span>{t('to')}</span>
          <input type="date" value={to} onChange={(e) => setTo(e.target.value)} />
        </label>
      </div>
      <DataTable<AuditRow>
        id="audit"
        endpoint="/admin/audit"
        rowKey={(r) => r.id}
        defaultSort={{ sort: 'createdAt', order: 'desc' }}
        csv
        extraQuery={{
          actor: actor.trim() || undefined,
          targetId: targetId.trim() || undefined,
          from: from || undefined,
          to: to || undefined,
        }}
        filters={[
          {
            name: 'action',
            label: 'colAction',
            options: [
              ...prefixes.map((p) => ({ value: p, label: `${p}*` })),
              ...(actions.data?.data ?? []).map((a) => ({ value: a, label: a })),
            ],
          },
          {
            name: 'targetType',
            label: 'auditTargetType',
            options: ['user', 'agency', 'agency_complaint', 'live_room', 'gift', 'home_banner', 'event', 'topup_order', 'topup_case', 'admin_table', 'waitlist'].map((v) => ({
              value: v,
              label: v,
            })),
          },
        ]}
        onRowClick={(r) => setOpen(r)}
        columns={[
          { key: 'date', label: 'colDate', sort: 'createdAt', render: (r) => <span className="date small">{formatDate(r.createdAt, lang)}</span> },
          { key: 'action', label: 'colAction', render: (r) => <span className="mono small">{r.action}</span> },
          { key: 'actor', label: 'colActor', render: (r) => (r.actor ? <span className="ltr">@{r.actor.username}</span> : <span className="muted">{t('system')}</span>) },
          {
            key: 'target',
            label: 'auditTarget',
            render: (r) => (
              <span className="small">
                {r.targetType ?? '—'} <span className="mono muted">{r.targetId?.slice(0, 12) ?? ''}</span>
              </span>
            ),
          },
          { key: 'meta', label: 'colDetails', render: (r) => <AuditMeta meta={r.metadata} /> },
          { key: 'ip', label: 'colIp', optional: true, render: (r) => <span className="mono small ltr">{r.ip ?? '—'}</span> },
          { key: 'via', label: 'colVia', optional: true, render: (r) => metaText(r.metadata.via) },
        ]}
      />
      {open && (
        <Dialog title={open.action} onClose={() => setOpen(null)}>
          <dl className="kv">
            <dt>{t('colDate')}</dt>
            <dd className="date">{formatDate(open.createdAt, lang)}</dd>
            <dt>{t('colActor')}</dt>
            <dd>{open.actor ? `@${open.actor.username}` : t('system')}</dd>
            <dt>{t('auditTarget')}</dt>
            <dd className="mono small">
              {open.targetType} {open.targetId}
            </dd>
            <dt>IP</dt>
            <dd className="mono small ltr">{open.ip ?? '—'}</dd>
          </dl>
          {diffOf(open.metadata).length > 0 && (
            <table className="diff-table">
              <thead>
                <tr>
                  <th />
                  <th>{t('before')}</th>
                  <th>{t('after')}</th>
                </tr>
              </thead>
              <tbody>
                {diffOf(open.metadata).map((d) => (
                  <tr key={d.field || 'state'}>
                    <td className="mono small">{d.field || t('state')}</td>
                    <td>
                      <del>{d.before}</del>
                    </td>
                    <td>
                      <ins>{d.after}</ins>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
          <pre className="json ltr">{JSON.stringify(open.metadata, null, 2)}</pre>
          <div className="actions">
            <button className="btn" onClick={() => setOpen(null)}>
              {t('close')}
            </button>
          </div>
        </Dialog>
      )}
    </>
  );
}
