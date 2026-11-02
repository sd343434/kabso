import { useState } from 'react';
import { api } from '../api';
import { Dialog, ErrorAlert, FormDialog, Loading, reasonField, useAsync } from '../components';
import { useApp } from '../context';
import { formatDate, formatNumber } from '../format';
import type {
  AdminPkDare,
  AdminPkDareImportResult,
  AdminPkDareSettings,
  AdminPkDareStats,
  PkDareCategory,
  PkDareLevel,
} from '../types';
import { DataTable } from '../ui/DataTable';
import { StatusTabs } from './Applications';

/**
 * «أحكام PK» (v1.50-live, D229, CONVENTIONS §10.80): the «PK أحكام» dare library — the table (category / level / status
 * filters, search in both texts, CSV), add and edit (the server's safety and duplicate checks answer 400 with the
 * rule), disable / enable, the «مُبلَّغ عنها» queue (reported first; keep = clear the reports and enable again), import
 * (JSON lines or CSV, dry run) and the PK points settings. `pk_dares.view` reads (OWNER, MODERATION, SUPPORT);
 * `pk_dares.edit` writes (OWNER, MODERATION). Every write asks for a reason.
 */
export const LEVELS: readonly PkDareLevel[] = ['EASY', 'MEDIUM', 'HARD'];
export const CATEGORIES: readonly PkDareCategory[] = [
  'FUNNY',
  'SINGING',
  'ACTING',
  'TALK',
  'TRUTH',
  'DANCE_LIGHT',
  'IMITATION',
  'QUIZ',
  'DRAWING',
];
const TABS = ['library', 'reported', 'import', 'settings'] as const;
type Tab = (typeof TABS)[number];

export function LevelBadge({ level }: { level: PkDareLevel }) {
  const { t } = useApp();
  const cls = level === 'EASY' ? 'badge ok' : level === 'MEDIUM' ? 'badge warn' : 'badge bad';
  return (
    <span className={cls} data-level={level}>
      {t(`pkdLevel${level}`)}
    </span>
  );
}

export function DareState({ dare }: { dare: AdminPkDare }) {
  const { t } = useApp();
  if (dare.active) return <span className="badge ok">{t('pkdActive')}</span>;
  return <span className="badge bad">{t(`pkdDisabled${dare.disabledReason ?? 'ADMIN'}`)}</span>;
}

/** The counts over the page (pure: rendered in the tests). */
export function PkDareStatsRow({ stats }: { stats: AdminPkDareStats }) {
  const { t, lang } = useApp();
  const tone: Record<string, string> = {
    total: 'wine',
    active: 'blue',
    disabled: 'gold',
    reported: 'red',
    EASY: 'green',
    MEDIUM: 'gold',
    HARD: 'red',
  };
  const cell = (label: string, value: number, key: string) => (
    <div className={`kpi tone-${tone[key] ?? 'blue'}`} style={{ minHeight: 96, paddingBottom: 14 }} data-stat={key}>
      <div className="kpi-top">
        <span className="kpi-label">{label}</span>
      </div>
      <div className="kpi-value num">{formatNumber(value, lang)}</div>
    </div>
  );
  return (
    <div className="kpis four" data-pk-dare-stats style={{ marginBottom: 16 }}>
      {cell(t('pkdStatsTotal'), stats.total, 'total')}
      {cell(t('pkdStatsActive'), stats.active, 'active')}
      {cell(t('pkdStatsDisabled'), stats.disabled, 'disabled')}
      {cell(t('pkdStatsReported'), stats.reported, 'reported')}
      {LEVELS.map((l) => cell(t(`pkdLevel${l}`), stats.byLevel[l] ?? 0, l))}
    </div>
  );
}

interface DareDraft {
  textAr: string;
  textEn: string;
  category: PkDareCategory;
  level: PkDareLevel;
}

/** Add / edit a dare: both texts, the category and the level, and the reason (the server checks the texts). */
export function DareDialog({
  dare,
  onClose,
  onDone,
}: {
  dare: AdminPkDare | null;
  onClose: () => void;
  onDone: () => void;
}) {
  const { t } = useApp();
  const [draft, setDraft] = useState<DareDraft>(
    dare
      ? { textAr: dare.textAr, textEn: dare.textEn, category: dare.category, level: dare.level }
      : { textAr: '', textEn: '', category: 'FUNNY', level: 'EASY' },
  );
  const [reason, setReason] = useState('');
  const [error, setError] = useState<unknown>(null);
  const [busy, setBusy] = useState(false);
  const arLength = [...draft.textAr.trim()].length;
  const ready = draft.textAr.trim() && draft.textEn.trim() && reason.trim() && arLength <= 90;
  const save = async () => {
    setBusy(true);
    setError(null);
    try {
      if (dare) {
        const changes: Record<string, unknown> = {};
        for (const k of ['textAr', 'textEn', 'category', 'level'] as const) {
          if (draft[k] !== dare[k]) changes[k] = draft[k];
        }
        await api.patch(`/admin/pk-dares/${dare.id}`, { ...changes, reason });
      } else {
        await api.post('/admin/pk-dares', { ...draft, reason });
      }
      onDone();
    } catch (err) {
      setError(err);
    } finally {
      setBusy(false);
    }
  };
  return (
    <Dialog title={dare ? t('pkdEdit') : t('pkdAdd')} onClose={onClose}>
      <p className="muted small">{t('pkdRulesHint')}</p>
      <label className="field">
        <span>{t('pkdColTextAr')}</span>
        <textarea dir="rtl" lang="ar" value={draft.textAr} maxLength={200} onChange={(e) => setDraft({ ...draft, textAr: e.target.value })} data-dare-ar />
        <span className={arLength > 90 ? 'small bad' : 'muted small'}>{arLength} / 90</span>
      </label>
      <label className="field">
        <span>{t('pkdColTextEn')}</span>
        <textarea dir="ltr" lang="en" value={draft.textEn} maxLength={300} onChange={(e) => setDraft({ ...draft, textEn: e.target.value })} data-dare-en />
      </label>
      <div className="row">
        <label className="field">
          <span>{t('pkdColCategory')}</span>
          <select value={draft.category} onChange={(e) => setDraft({ ...draft, category: e.target.value as PkDareCategory })}>
            {CATEGORIES.map((c) => (
              <option key={c} value={c}>
                {t(`pkdCat${c}`)}
              </option>
            ))}
          </select>
        </label>
        <label className="field">
          <span>{t('pkdColLevel')}</span>
          <select value={draft.level} onChange={(e) => setDraft({ ...draft, level: e.target.value as PkDareLevel })}>
            {LEVELS.map((l) => (
              <option key={l} value={l}>
                {t(`pkdLevel${l}`)}
              </option>
            ))}
          </select>
        </label>
      </div>
      <label className="field">
        <span>{t('reason')}</span>
        <textarea value={reason} maxLength={500} onChange={(e) => setReason(e.target.value)} />
      </label>
      <ErrorAlert error={error} />
      <div className="row end">
        <button className="btn" onClick={onClose}>
          {t('cancel')}
        </button>
        <button className="btn primary" disabled={!ready || busy} onClick={() => void save()} data-dare-save>
          {t('pkdSave')}
        </button>
      </div>
    </Dialog>
  );
}

function DareTable({ reported, onEdit, reloadKey }: { reported: boolean; onEdit: (d: AdminPkDare) => void; reloadKey: number }) {
  const { t, lang, can } = useApp();
  const [level, setLevel] = useState('');
  const [category, setCategory] = useState('');
  const [active, setActive] = useState('');
  return (
    <DataTable<AdminPkDare>
      id={reported ? 'pk-dares-reported' : 'pk-dares'}
      endpoint="/admin/pk-dares"
      rowKey={(r) => r.id}
      reloadKey={`${String(reloadKey)}-${level}-${category}-${active}`}
      extraQuery={{
        reported: reported ? 'true' : undefined,
        level: level || undefined,
        category: category || undefined,
        active: active || undefined,
      }}
      defaultSort={reported ? { sort: 'reportCount', order: 'desc' } : { sort: 'seqNo', order: 'asc' }}
      searchLabel="search"
      csv
      header={
        <div className="row" data-pk-dare-filters>
          <select aria-label={t('pkdColLevel')} value={level} onChange={(e) => setLevel(e.target.value)}>
            <option value="">{`${t('pkdColLevel')}: ${t('pkdFilterAll')}`}</option>
            {LEVELS.map((l) => (
              <option key={l} value={l}>
                {t(`pkdLevel${l}`)}
              </option>
            ))}
          </select>
          <select aria-label={t('pkdColCategory')} value={category} onChange={(e) => setCategory(e.target.value)}>
            <option value="">{`${t('pkdColCategory')}: ${t('pkdFilterAll')}`}</option>
            {CATEGORIES.map((c) => (
              <option key={c} value={c}>
                {t(`pkdCat${c}`)}
              </option>
            ))}
          </select>
          <select aria-label={t('pkdColActive')} value={active} onChange={(e) => setActive(e.target.value)}>
            <option value="">{`${t('pkdColActive')}: ${t('pkdFilterAll')}`}</option>
            <option value="true">{t('pkdActive')}</option>
            <option value="false">{t('pkdDisable')}</option>
          </select>
        </div>
      }
      onRowClick={can('pk_dares.edit') ? onEdit : undefined}
      columns={[
        { key: 'code', label: 'pkdColCode', sort: 'seqNo', optional: true, render: (r) => <span className="mono ltr small">{r.code}</span> },
        { key: 'level', label: 'pkdColLevel', render: (r) => <LevelBadge level={r.level} /> },
        { key: 'category', label: 'pkdColCategory', render: (r) => t(`pkdCat${r.category}`) },
        { key: 'ar', label: 'pkdColTextAr', render: (r) => <span dir="rtl" lang="ar">{r.textAr}</span> },
        { key: 'en', label: 'pkdColTextEn', render: (r) => <span dir="ltr" lang="en" className="small">{r.textEn}</span> },
        { key: 'state', label: 'pkdColActive', render: (r) => <DareState dare={r} /> },
        { key: 'reports', label: 'pkdColReports', sort: 'reportCount', numeric: true, render: (r) => formatNumber(r.reportCount, lang) },
        { key: 'updated', label: 'colUpdated', sort: 'updatedAt', optional: true, render: (r) => <span className="date small">{formatDate(r.updatedAt, lang)}</span> },
      ]}
    />
  );
}

/** A dare's actions (edit dialog's companion): disable / enable, and in the queue keep with or without enabling. */
function DareActions({ dare, onClose, onDone }: { dare: AdminPkDare; onClose: () => void; onDone: () => void }) {
  const { t } = useApp();
  const [mode, setMode] = useState<'edit' | 'toggle' | 'keep' | 'clear' | null>(null);
  if (mode === 'edit') return <DareDialog dare={dare} onClose={onClose} onDone={onDone} />;
  if (mode) {
    const submit = (v: Record<string, string>) =>
      mode === 'toggle'
        ? api.patch(`/admin/pk-dares/${dare.id}`, { active: !dare.active, reason: v.reason })
        : api.post(`/admin/pk-dares/${dare.id}/reports/clear`, { enable: mode === 'keep', reason: v.reason });
    const label = mode === 'toggle' ? (dare.active ? t('pkdDisable') : t('pkdEnable')) : mode === 'keep' ? t('pkdKeep') : t('pkdKeepOff');
    return <FormDialog title={label} fields={[reasonField(t)]} confirmLabel={label} danger={mode === 'toggle' && dare.active} submit={submit} onClose={onClose} onDone={onDone} />;
  }
  return (
    <Dialog title={dare.code} onClose={onClose}>
      <p dir="rtl" lang="ar">{dare.textAr}</p>
      <p dir="ltr" lang="en" className="muted">
        {dare.textEn}
      </p>
      <div className="row">
        <LevelBadge level={dare.level} />
        <DareState dare={dare} />
      </div>
      <div className="row end" style={{ marginTop: 16 }}>
        <button className="btn" onClick={() => setMode('edit')} data-dare-edit>
          {t('pkdEdit')}
        </button>
        <button className={dare.active ? 'btn danger' : 'btn'} onClick={() => setMode('toggle')} data-dare-toggle>
          {dare.active ? t('pkdDisable') : t('pkdEnable')}
        </button>
        {dare.reportCount > 0 && (
          <>
            <button className="btn primary" onClick={() => setMode('keep')} data-dare-keep>
              {t('pkdKeep')}
            </button>
            <button className="btn" onClick={() => setMode('clear')}>
              {t('pkdKeepOff')}
            </button>
          </>
        )}
      </div>
    </Dialog>
  );
}

function ImportPanel({ onDone }: { onDone: () => void }) {
  const { t } = useApp();
  const [format, setFormat] = useState<'json' | 'csv'>('json');
  const [content, setContent] = useState('');
  const [dryRun, setDryRun] = useState(true);
  const [reason, setReason] = useState('');
  const [result, setResult] = useState<AdminPkDareImportResult | null>(null);
  const [error, setError] = useState<unknown>(null);
  const [busy, setBusy] = useState(false);
  const run = async () => {
    setBusy(true);
    setError(null);
    try {
      const r = await api.post<AdminPkDareImportResult>('/admin/pk-dares/import', { format, content, dryRun, reason });
      setResult(r);
      if (!dryRun) onDone();
    } catch (err) {
      setError(err);
    } finally {
      setBusy(false);
    }
  };
  return (
    <div className="card" data-pk-dare-import>
      <p className="muted small">{t('pkdImportHint')}</p>
      <div className="row">
        <label className="field">
          <span>{t('pkdImportFormat')}</span>
          <select value={format} onChange={(e) => setFormat(e.target.value as 'json' | 'csv')}>
            <option value="json">JSON</option>
            <option value="csv">CSV</option>
          </select>
        </label>
        <label className="field">
          <span>{t('pkdImportFile')}</span>
          <input
            type="file"
            accept=".json,.jsonl,.csv,application/json,text/csv"
            onChange={(e) => {
              const file = e.target.files?.[0];
              if (!file) return;
              if (file.name.endsWith('.csv')) setFormat('csv');
              void file.text().then(setContent);
            }}
          />
        </label>
      </div>
      <label className="field">
        <span>{t('pkdImportContent')}</span>
        <textarea rows={8} dir="auto" value={content} onChange={(e) => setContent(e.target.value)} className="mono" />
      </label>
      <label className="row">
        <input type="checkbox" checked={dryRun} onChange={(e) => setDryRun(e.target.checked)} />
        <span>{t('pkdImportDryRun')}</span>
      </label>
      <label className="field">
        <span>{t('reason')}</span>
        <textarea value={reason} maxLength={500} onChange={(e) => setReason(e.target.value)} />
      </label>
      <ErrorAlert error={error} />
      <button className="btn primary" disabled={busy || !content.trim() || !reason.trim()} onClick={() => void run()}>
        {t('pkdImportRun')}
      </button>
      {result && <ImportResult result={result} />}
    </div>
  );
}

export function ImportResult({ result }: { result: AdminPkDareImportResult }) {
  const { t } = useApp();
  return (
    <div data-import-result>
      <p>
        {t('pkdImportResult', {
          received: String(result.received),
          inserted: String(result.inserted),
          existing: String(result.existing),
          rejected: String(result.rejected.length),
        })}
      </p>
      {result.rejected.length > 0 && (
        <ul className="plain-list small">
          {result.rejected.slice(0, 50).map((r) => (
            <li key={r.line} data-rejected-line={r.line}>
              {t('pkdImportLine', { line: String(r.line) })} <span className="mono ltr">{r.code ?? ''}</span> — {r.issues.join(', ')}
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}

type SettingsDraft = Omit<AdminPkDareSettings, 'updatedAt' | 'updatedById'>;
const SETTING_FIELDS: readonly [keyof SettingsDraft, string][] = [
  ['winPoints', 'pkdSetWin'],
  ['drawPoints', 'pkdSetDraw'],
  ['lossPoints', 'pkdSetLoss'],
  ['refusePoints', 'pkdSetRefuse'],
  ['decideSeconds', 'pkdSetDecide'],
  ['reportsToDisable', 'pkdSetReports'],
];

/** Only the fields that changed (pure: tested). */
export function pkDareSettingsChanges(saved: AdminPkDareSettings, draft: SettingsDraft): Partial<SettingsDraft> {
  const out: Partial<SettingsDraft> = {};
  for (const [k] of SETTING_FIELDS) if (draft[k] !== saved[k]) out[k] = draft[k];
  return out;
}

/** The settings form (pure: rendered in the tests; read-only without `pk_dares.edit`). */
export function PkDareSettingsForm({
  saved,
  draft,
  onChange,
  onSave,
}: {
  saved: AdminPkDareSettings;
  draft: SettingsDraft;
  onChange: (d: SettingsDraft) => void;
  onSave: () => void;
}) {
  const { t, lang, can } = useApp();
  const edit = can('pk_dares.edit');
  const changes = pkDareSettingsChanges(saved, draft);
  return (
    <div className="card" data-pk-dare-settings>
      <p className="muted small">{t('pkdSetHint')}</p>
      <div className="grid cols-2">
        {SETTING_FIELDS.map(([k, label]) => (
          <label key={k} className="field">
            <span>{t(label as never)}</span>
            <input
              type="number"
              className="num"
              value={draft[k]}
              readOnly={!edit}
              data-setting={k}
              onChange={(e) => onChange({ ...draft, [k]: Number(e.target.value) })}
            />
          </label>
        ))}
      </div>
      <p className="muted small">
        {t('refUpdatedAt')}: <span className="date">{formatDate(saved.updatedAt, lang)}</span>
      </p>
      {edit && (
        <button className="btn primary" disabled={Object.keys(changes).length === 0} onClick={onSave} data-pk-dare-settings-save>
          {Object.keys(changes).length === 0 ? t('pkdNoChange') : t('pkdSave')}
        </button>
      )}
    </div>
  );
}

function SettingsPanel() {
  const { t, toast } = useApp();
  const { data, error, loading, reload } = useAsync(() => api.get<AdminPkDareSettings>('/admin/pk-dare-settings'), []);
  const [draft, setDraft] = useState<SettingsDraft | null>(null);
  const [saving, setSaving] = useState(false);
  if (loading && !data) return <Loading />;
  if (!data) return <ErrorAlert error={error} />;
  const current: SettingsDraft = draft ?? data;
  return (
    <>
      <PkDareSettingsForm saved={data} draft={current} onChange={setDraft} onSave={() => setSaving(true)} />
      {saving && (
        <FormDialog
          title={t('pkdSave')}
          fields={[reasonField(t)]}
          confirmLabel={t('pkdSave')}
          submit={(v) => api.put('/admin/pk-dare-settings', { ...pkDareSettingsChanges(data, current), reason: v.reason })}
          onClose={() => setSaving(false)}
          onDone={() => {
            setSaving(false);
            setDraft(null);
            toast(t('pkdSaved'));
            reload();
          }}
        />
      )}
    </>
  );
}

export function PkDares() {
  const { t, can } = useApp();
  const [tab, setTab] = useState<Tab>('library');
  const [reload, setReload] = useState(0);
  const [adding, setAdding] = useState(false);
  const [open, setOpen] = useState<AdminPkDare | null>(null);
  const stats = useAsync(() => api.get<AdminPkDareStats>('/admin/pk-dares/stats'), [reload]);
  const done = () => {
    setAdding(false);
    setOpen(null);
    setReload((n) => n + 1);
  };
  const tabs = can('pk_dares.edit') ? TABS : TABS.filter((x) => x !== 'import');
  return (
    <>
      <div className="page-head">
        <div>
          <h1>{t('pkdTitle')}</h1>
          <p className="muted small">{t('pkdSubtitle')}</p>
        </div>
        {can('pk_dares.edit') && (
          <button className="btn primary" onClick={() => setAdding(true)} data-pk-dare-add>
            {t('pkdAdd')}
          </button>
        )}
      </div>
      {stats.data && <PkDareStatsRow stats={stats.data} />}
      <StatusTabs value={tab} options={tabs} onChange={setTab} label={(x) => t(`pkdTab${x.charAt(0).toUpperCase()}${x.slice(1)}` as never)} />
      {tab === 'library' && <DareTable reported={false} onEdit={setOpen} reloadKey={reload} />}
      {tab === 'reported' && <DareTable reported onEdit={setOpen} reloadKey={reload} />}
      {tab === 'import' && <ImportPanel onDone={done} />}
      {tab === 'settings' && <SettingsPanel />}
      {adding && <DareDialog dare={null} onClose={() => setAdding(false)} onDone={done} />}
      {open && <DareActions dare={open} onClose={() => setOpen(null)} onDone={done} />}
    </>
  );
}
