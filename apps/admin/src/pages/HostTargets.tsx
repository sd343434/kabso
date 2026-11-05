import { useState } from 'react';
import { api } from '../api';
import { ErrorAlert, FormDialog, Loading, reasonField, useAsync } from '../components';
import { useApp } from '../context';
import { formatDate, formatNumber } from '../format';
import type { AdminHostTargetDay, AdminHostTargetSettings, AdminTargetCatalogue } from '../types';

/**
 * D281 «الأهداف الذكية» (OWNER only, CONVENTIONS §10.62.2): the knobs of the smart targets and tasks (the level
 * percentiles, the reward shares 1.5 / 2.5 / 4 %, the no-repeat days, …; saved with a reason, audited), the size of the
 * generated catalogues, and a host's targets of a day with «لماذا هذا الهدف».
 */
type Draft = Omit<AdminHostTargetSettings, 'engineFrom' | 'updatedAt' | 'updatedById'>;
type Knob = Exclude<keyof Draft, 'newHostDefaults'>;

/** D281b: the new-host defaults' kinds, in the order the form shows them. */
export const DEFAULT_KINDS = [
  'GIFT_SENDS',
  'SUPPORTERS',
  'GIFT_CHERRIES',
  'LUCKY_SENDS',
  'LUCKY_SUPPORTERS',
  'LUCKY_CHERRIES',
] as const;

export const KNOB_FIELDS: readonly [Knob, string][] = [
  ['easyPercentile', 'htEasyPercentile'],
  ['mediumPercentile', 'htMediumPercentile'],
  ['hardPercentile', 'htHardPercentile'],
  ['easyRewardBps', 'htEasyRewardBps'],
  ['mediumRewardBps', 'htMediumRewardBps'],
  ['hardRewardBps', 'htHardRewardBps'],
  ['noRepeatDays', 'htNoRepeatDays'],
  ['taskNoRepeatDays', 'htTaskNoRepeatDays'],
  ['historyDays', 'htHistoryDays'],
  ['completionShift', 'htCompletionShift'],
];

/** Only the knobs that changed (pure: tested). */
export function knobChanges(saved: AdminHostTargetSettings, draft: Draft): Partial<Draft> {
  const out: Partial<Draft> = {};
  for (const [k] of KNOB_FIELDS) if (draft[k] !== saved[k]) out[k] = draft[k];
  if (JSON.stringify(draft.newHostDefaults) !== JSON.stringify(saved.newHostDefaults)) {
    out.newHostDefaults = draft.newHostDefaults;
  }
  return out;
}

/** D281b: every band of the new-host defaults keeps easy ≤ medium ≤ hard (whole numbers ≥ 1). */
export function defaultsValid(d: Record<string, number[][]>): boolean {
  return DEFAULT_KINDS.every((k) =>
    (d[k] ?? []).every((b) => b.every((x) => Number.isInteger(x) && x >= 1) && b[0]! <= b[1]! && b[1]! <= b[2]!),
  );
}

/** Whether the order holds (easy < medium < hard; easy ≤ medium ≤ hard shares) — the API refuses it otherwise. */
export function knobsValid(d: Draft): boolean {
  return (
    d.easyPercentile < d.mediumPercentile &&
    d.mediumPercentile < d.hardPercentile &&
    d.easyRewardBps <= d.mediumRewardBps &&
    d.mediumRewardBps <= d.hardRewardBps &&
    defaultsValid(d.newHostDefaults)
  );
}

/** `150` bps → «1.5٪» / «1.5%». */
export function bpsPercent(bps: number, lang: 'ar' | 'en'): string {
  const v = (bps / 100).toString();
  return lang === 'ar' ? `${v}٪` : `${v}%`;
}

/** The knobs form (pure: rendered in the tests; read-only without `host_targets.edit`). */
export function HostTargetKnobsForm({
  saved,
  draft,
  onChange,
  onSave,
}: {
  saved: AdminHostTargetSettings;
  draft: Draft;
  onChange: (d: Draft) => void;
  onSave: () => void;
}) {
  const { t, lang, can } = useApp();
  const edit = can('host_targets.edit');
  const changes = knobChanges(saved, draft);
  const valid = knobsValid(draft);
  return (
    <div className="card" data-host-target-knobs>
      <h2>{t('htKnobs')}</h2>
      <p className="muted small">{t('htKnobsHint')}</p>
      <div className="grid cols-2">
        {KNOB_FIELDS.map(([k, label]) => (
          <label key={k} className="field">
            <span>
              {t(label as never)}
              {k.endsWith('RewardBps') ? ` — ${bpsPercent(draft[k], lang)}` : ''}
            </span>
            <input
              type="number"
              className="num"
              value={draft[k]}
              readOnly={!edit}
              data-knob={k}
              onChange={(e) => onChange({ ...draft, [k]: Number(e.target.value) })}
            />
          </label>
        ))}
      </div>
      <h3>{t('htDefaults')}</h3>
      <p className="muted small">{t('htDefaultsHint')}</p>
      <div className="table-wrap">
        <table data-new-host-defaults>
          <thead>
            <tr>
              <th>{t('htTarget')}</th>
              {[1, 2, 3, 4].map((b) => (
                <th key={b}>{t('htBand', { band: String(b) })}</th>
              ))}
            </tr>
          </thead>
          <tbody>
            {DEFAULT_KINDS.map((k) => (
              <tr key={k}>
                <td>{t(`htKind${k}` as never)}</td>
                {(draft.newHostDefaults[k] ?? []).map((band, bi) => (
                  <td key={bi}>
                    {band.map((v, li) => (
                      <input
                        key={li}
                        type="number"
                        className="num"
                        style={{ width: '6.5em' }}
                        value={v}
                        readOnly={!edit}
                        data-default={`${k}.${String(bi)}.${String(li)}`}
                        onChange={(e) => {
                          const next = structuredClone(draft.newHostDefaults);
                          next[k]![bi]![li] = Number(e.target.value);
                          onChange({ ...draft, newHostDefaults: next });
                        }}
                      />
                    ))}
                  </td>
                ))}
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      <p className="muted small">
        {t('htEngineFrom')}: <span className="date">{saved.engineFrom ?? t('htEngineNotYet')}</span>
        {' · '}
        {t('refUpdatedAt')}: <span className="date">{formatDate(saved.updatedAt, lang)}</span>
      </p>
      {edit && (
        <button
          className="btn primary"
          disabled={Object.keys(changes).length === 0 || !valid}
          onClick={onSave}
          data-host-target-knobs-save
        >
          {Object.keys(changes).length === 0 ? t('htNoChange') : t('htSave')}
        </button>
      )}
    </div>
  );
}

/** The catalogues' size (pure). */
export function CatalogueStats({ data }: { data: AdminTargetCatalogue }) {
  const { t, lang } = useApp();
  const n = (v: number) => formatNumber(v, lang);
  return (
    <div className="card" data-target-catalogue>
      <h2>{t('htCatalogue')}</h2>
      <div className="grid cols-2">
        <div>
          <p className="kpi" data-catalogue-targets>
            {t('htCatalogueTargets')}: <strong className="num">{n(data.targets.total)}</strong>
          </p>
          <p className="muted small">
            {t('htTrackGIFTS')}: {n(data.targets.byTrack.GIFTS ?? 0)} · {t('htTrackLUCKY')}:{' '}
            {n(data.targets.byTrack.LUCKY ?? 0)} · {t('htCatalogueLuckyGifts')}: {n(data.targets.luckyGifts)}
          </p>
          <p className="muted small">
            {t('htCatalogueGifts')}: {n(data.targets.gifts)} · {t('htCatalogueWindows')}: {n(data.targets.windows)} ·{' '}
            {t('htCatalogueVersion')}: <code>{data.targets.version}</code>
          </p>
          <ul className="small">
            {Object.entries(data.targets.byKind).map(([k, v]) => (
              <li key={k}>
                {t(`htKind${k}` as never)}: <span className="num">{n(v)}</span>
              </li>
            ))}
          </ul>
        </div>
        <div>
          <p className="kpi" data-catalogue-tasks>
            {t('htCatalogueTasks')}: <strong className="num">{n(data.tasks.total)}</strong>
          </p>
          <ul className="small">
            {Object.entries(data.tasks.byTemplate).map(([k, v]) => (
              <li key={k}>
                <code>{k}</code>: <span className="num">{n(v)}</span>
              </li>
            ))}
          </ul>
        </div>
      </div>
    </div>
  );
}

/** A host's day: the three targets with their reasons (pure). */
export function HostTargetDayView({ data }: { data: AdminHostTargetDay }) {
  const { t, lang } = useApp();
  const n = (v: number) => formatNumber(v, lang);
  if (data.targets.length === 0) return <p className="muted state">{t('htNone')}</p>;
  return (
    <div className="table-wrap" data-host-target-day>
      <table>
        <thead>
          <tr>
            <th>{t('htTrack')}</th>
            <th>{t('htLevel')}</th>
            <th>{t('htTarget')}</th>
            <th>{t('htProgress')}</th>
            <th>{t('htReward')}</th>
            <th>{t('htPaid')}</th>
            <th>{t('htWhy')}</th>
          </tr>
        </thead>
        <tbody>
          {data.targets.map((x) => (
            <tr key={`${x.track}:${x.level}`} data-level={x.level} data-track={x.track}>
              <td>{t(`htTrack${x.track}` as never)}</td>
              <td>{t(`htLevel${x.level}` as never)}</td>
              <td>
                <div>{lang === 'ar' ? x.titleAr : x.titleEn}</div>
                <div className="muted small">
                  {t(`htKind${x.kind}` as never)} · <code>{x.code}</code>
                </div>
              </td>
              <td className="num">
                {n(Math.min(x.progress, x.amount))} / {n(x.amount)}
              </td>
              <td className="num">
                {n(x.rewardCherries)} ({bpsPercent(x.rewardBps, lang)})
              </td>
              <td className="num">{x.paidCherries === null ? '—' : n(x.paidCherries)}</td>
              <td className="small" data-why>
                {x.reason.newHost ? <strong>{t('htNewHost')} · </strong> : null}
                {lang === 'ar' ? x.reason.whyAr : x.reason.why}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

function Knobs() {
  const { t, toast } = useApp();
  const { data, error, loading, reload } = useAsync(
    () => api.get<AdminHostTargetSettings>('/admin/host-targets/settings'),
    [],
  );
  const [draft, setDraft] = useState<Draft | null>(null);
  const [saving, setSaving] = useState(false);
  if (loading && !data) return <Loading />;
  if (!data) return <ErrorAlert error={error} />;
  const current: Draft = draft ?? data;
  return (
    <>
      <HostTargetKnobsForm saved={data} draft={current} onChange={setDraft} onSave={() => setSaving(true)} />
      {saving && (
        <FormDialog
          title={t('htSave')}
          fields={[reasonField(t)]}
          confirmLabel={t('htSave')}
          submit={(v) =>
            api.put('/admin/host-targets/settings', { ...knobChanges(data, current), reason: v.reason })
          }
          onClose={() => setSaving(false)}
          onDone={() => {
            setSaving(false);
            setDraft(null);
            toast(t('htSaved'));
            reload();
          }}
        />
      )}
    </>
  );
}

function HostLookup() {
  const { t } = useApp();
  const [username, setUsername] = useState('');
  const [day, setDay] = useState('');
  const [query, setQuery] = useState<{ username: string; day: string } | null>(null);
  const { data, error, loading } = useAsync(
    () =>
      query
        ? api.get<AdminHostTargetDay>(
            `/admin/host-targets/hosts/${encodeURIComponent(query.username)}${query.day ? `?day=${query.day}` : ''}`,
          )
        : Promise.resolve(null),
    [query],
  );
  return (
    <div className="card">
      <h2>{t('htHost')}</h2>
      <p className="muted small">{t('htHostHint')}</p>
      <form
        className="row"
        onSubmit={(e) => {
          e.preventDefault();
          if (username.trim()) setQuery({ username: username.trim(), day });
        }}
      >
        <label className="field">
          <span>{t('htUsername')}</span>
          <input value={username} onChange={(e) => setUsername(e.target.value)} data-host-username />
        </label>
        <label className="field">
          <span>{t('htDay')}</span>
          <input type="date" value={day} onChange={(e) => setDay(e.target.value)} />
        </label>
        <button className="btn" type="submit">
          {t('htShow')}
        </button>
      </form>
      <ErrorAlert error={error} />
      {loading && query ? <Loading /> : data ? <HostTargetDayView data={data} /> : null}
    </div>
  );
}

export function HostTargets() {
  const { t } = useApp();
  const catalogue = useAsync(() => api.get<AdminTargetCatalogue>('/admin/host-targets/catalogue'), []);
  return (
    <>
      <div className="page-head">
        <div>
          <h1>{t('htTitle')}</h1>
          <p className="muted small">{t('htSubtitle')}</p>
        </div>
      </div>
      <Knobs />
      <ErrorAlert error={catalogue.error} />
      {catalogue.data && <CatalogueStats data={catalogue.data} />}
      <HostLookup />
    </>
  );
}
