import { useState } from 'react';
import { api } from '../api';
import { codeField, ErrorAlert, FormDialog, Loading, reasonField, useAsync } from '../components';
import { useApp } from '../context';
import type { Key } from '../i18n';
import { formatNumber } from '../format';
import type { AdminMedal, AdminMedalList, MedalCategory } from '../types';

/** One editable level (empty strings = no name / no art). */
export interface LevelDraft {
  threshold: number;
  nameAr: string;
  nameEn: string;
  iconUrl: string;
  /** D291: the app's bundled art key for this level (e.g. medal_wealth_l1); '' = none. */
  iconAsset: string;
}

export interface MedalDraft {
  category: MedalCategory;
  levels: LevelDraft[];
}

const MAX_LEVELS = 20;
const MAX_THRESHOLD = 1_000_000_000_000;

export function draftOf(m: AdminMedal): MedalDraft {
  return {
    category: m.category,
    levels: m.levels.length
      ? m.levels.map((l) => ({
          threshold: l.threshold,
          nameAr: l.nameAr ?? '',
          nameEn: l.nameEn ?? '',
          iconUrl: l.iconUrl ?? '',
          iconAsset: l.iconAsset ?? '',
        }))
      : [{ threshold: 1, nameAr: '', nameEn: '', iconUrl: '', iconAsset: '' }],
  };
}

/** A 0/1 medal (family, couple, or no metric): exactly one level at 1. */
export function singleLevel(m: AdminMedal): boolean {
  return m.metric === null || m.metric === 'FAMILY_JOINED' || m.metric === 'CP_FORMED';
}

/** The first problem of [draft] as a translation key and its variables, or null (the server checks it again). */
export function draftProblem(m: AdminMedal, draft: MedalDraft): { key: Key; vars?: Record<string, number> } | null {
  const ts = draft.levels.map((l) => l.threshold);
  if (singleLevel(m) && (ts.length !== 1 || ts[0] !== 1)) return { key: 'mdSingle' };
  if (
    ts.length < 1 ||
    ts.length > MAX_LEVELS ||
    !ts.every((t, i) => Number.isInteger(t) && t >= 1 && t <= MAX_THRESHOLD && (i === 0 || t > ts[i - 1]!))
  )
    return { key: 'mdRising' };
  const held = m.levels.filter((l) => l.holders > 0).reduce((a, l) => Math.max(a, l.level), 0);
  if (held > ts.length) return { key: 'mdHeld', vars: { n: held } };
  if (draft.levels.some((l) => l.iconUrl.trim() !== '' && !/^https:\/\/\S+$/.test(l.iconUrl.trim())))
    return { key: 'mdBadUrl' };
  if (draft.levels.some((l) => l.iconAsset.trim() !== '' && !/^[a-z0-9_]{1,60}$/.test(l.iconAsset.trim())))
    return { key: 'mdBadAsset' };
  return null;
}

export function draftChanged(m: AdminMedal, draft: MedalDraft): boolean {
  return JSON.stringify(draftOf(m)) !== JSON.stringify(draft);
}

/** The PUT body's levels (empty strings sent as null). */
export function levelsBody(draft: MedalDraft) {
  const opt = (s: string) => (s.trim() === '' ? null : s.trim());
  return draft.levels.map((l) => ({
    threshold: l.threshold,
    nameAr: opt(l.nameAr),
    nameEn: opt(l.nameEn),
    iconUrl: opt(l.iconUrl),
    iconAsset: opt(l.iconAsset),
  }));
}

/** One medal's tab and levels (pure: rendered in the tests). */
export function MedalLevelsForm({
  medal,
  draft,
  onChange,
  onSave,
}: {
  medal: AdminMedal;
  draft: MedalDraft;
  onChange: (d: MedalDraft) => void;
  onSave: () => void;
}) {
  const { t, lang, can } = useApp();
  // D291: a retired code is a name-side icon, not a medal — shown read-only.
  const edit = can('catalog.manage') && !medal.retired;
  const single = singleLevel(medal);
  const problem = draftProblem(medal, draft);
  const changed = draftChanged(medal, draft);
  const holdersOf = (level: number) => medal.levels.find((l) => l.level === level)?.holders ?? 0;
  const setLevel = (i: number, patch: Partial<LevelDraft>) =>
    onChange({ ...draft, levels: draft.levels.map((l, j) => (j === i ? { ...l, ...patch } : l)) });
  const last = draft.levels[draft.levels.length - 1];
  return (
    <div className="card" data-medal={medal.code} style={{ marginBottom: 16 }}>
      <div className="page-head" style={{ marginBottom: 8 }}>
        <div>
          <h2 style={{ margin: 0 }}>{lang === 'ar' ? medal.nameAr : medal.nameEn}</h2>
          <p className="muted small">
            <span className="mono ltr">{medal.code}</span> · {t('mdMetric')}:{' '}
            {medal.metric ? t(`mdMetric${medal.metric}` as Key) : t('mdMetricNone')} ·{' '}
            {t('mdHolders', { n: formatNumber(medal.holders, lang) })}
          </p>
          {medal.retired && (
            <div className="alert info" data-retired>
              {t('mdRetired')}
            </div>
          )}
        </div>
        <div className="field" style={{ minWidth: 180 }}>
          <label htmlFor={`md-tab-${medal.code}`}>{t('mdTab')}</label>
          <select
            id={`md-tab-${medal.code}`}
            value={draft.category}
            disabled={!edit}
            onChange={(e) => onChange({ ...draft, category: e.target.value as MedalCategory })}
          >
            <option value="ACHIEVEMENT">{t('mdTabACHIEVEMENT')}</option>
            <option value="ACTIVITY">{t('mdTabACTIVITY')}</option>
          </select>
        </div>
      </div>
      <table className="table" data-levels>
        <thead>
          <tr>
            <th>{t('mdLevel')}</th>
            <th>{t('mdThreshold')}</th>
            <th>{t('mdNameAr')}</th>
            <th>{t('mdNameEn')}</th>
            <th>{t('mdIconUrl')}</th>
            <th>{t('mdIconAsset')}</th>
            <th>{t('mdLevelHolders')}</th>
          </tr>
        </thead>
        <tbody>
          {draft.levels.map((l, i) => (
            <tr key={i} data-level={i + 1}>
              <td className="mono">{i + 1}</td>
              <td>
                <input
                  type="number"
                  min={1}
                  className="ltr mono"
                  aria-label={`${t('mdThreshold')} ${i + 1}`}
                  value={l.threshold}
                  disabled={!edit || single}
                  onChange={(e) => setLevel(i, { threshold: Math.max(0, Math.floor(Number(e.target.value)) || 0) })}
                />
              </td>
              <td>
                <input
                  dir="rtl"
                  aria-label={`${t('mdNameAr')} ${i + 1}`}
                  maxLength={60}
                  value={l.nameAr}
                  disabled={!edit}
                  onChange={(e) => setLevel(i, { nameAr: e.target.value })}
                />
              </td>
              <td>
                <input
                  dir="ltr"
                  aria-label={`${t('mdNameEn')} ${i + 1}`}
                  maxLength={60}
                  value={l.nameEn}
                  disabled={!edit}
                  onChange={(e) => setLevel(i, { nameEn: e.target.value })}
                />
              </td>
              <td>
                <input
                  className="ltr"
                  dir="ltr"
                  aria-label={`${t('mdIconUrl')} ${i + 1}`}
                  maxLength={500}
                  placeholder="https://"
                  value={l.iconUrl}
                  disabled={!edit}
                  onChange={(e) => setLevel(i, { iconUrl: e.target.value })}
                />
              </td>
              <td>
                <input
                  className="ltr mono"
                  dir="ltr"
                  aria-label={`${t('mdIconAsset')} ${i + 1}`}
                  maxLength={60}
                  placeholder="medal_…"
                  value={l.iconAsset}
                  disabled={!edit}
                  onChange={(e) => setLevel(i, { iconAsset: e.target.value })}
                />
              </td>
              <td className="mono" data-holders>
                {formatNumber(holdersOf(i + 1), lang)}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
      <p className="muted small">{t('mdIconHint')}</p>
      {problem && <div className="alert error">{t(problem.key, problem.vars)}</div>}
      {edit && (
        <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
          {!single && (
            <>
              <button
                className="btn"
                disabled={draft.levels.length >= MAX_LEVELS}
                data-add-level
                onClick={() =>
                  onChange({
                    ...draft,
                    levels: [
                      ...draft.levels,
                      { threshold: (last?.threshold ?? 0) * 2 || 1, nameAr: '', nameEn: '', iconUrl: '', iconAsset: '' },
                    ],
                  })
                }
              >
                {t('mdAddLevel')}
              </button>
              <button
                className="btn"
                disabled={draft.levels.length <= 1 || holdersOf(draft.levels.length) > 0}
                data-remove-level
                onClick={() => onChange({ ...draft, levels: draft.levels.slice(0, -1) })}
              >
                {t('mdRemoveLevel')}
              </button>
            </>
          )}
          <button className="btn primary" disabled={problem !== null || !changed} onClick={onSave} data-medal-save>
            {changed ? t('mdSave') : t('mdNoChange')}
          </button>
        </div>
      )}
    </div>
  );
}

/** «الميداليات» (v1.81-live, D291, CONVENTIONS §10.104.4). */
export function Medals() {
  const { t, can, toast } = useApp();
  const { data, error, loading, reload } = useAsync(() => api.get<AdminMedalList>('/admin/medals'), []);
  const [drafts, setDrafts] = useState<Record<string, MedalDraft>>({});
  const [saving, setSaving] = useState<string | null>(null);
  if (loading && !data) return <Loading />;
  if (!data) return <ErrorAlert error={error} />;
  const draftFor = (m: AdminMedal) => drafts[m.code] ?? draftOf(m);
  const savingMedal = data.data.find((m) => m.code === saving);
  return (
    <>
      <div className="page-head">
        <div>
          <h1>{t('mdTitle')}</h1>
          <p className="muted small">{t('mdSubtitle')}</p>
        </div>
      </div>
      {!can('catalog.manage') && <div className="alert info">{t('mdReadOnly')}</div>}
      {data.data.map((m) => (
        <MedalLevelsForm
          key={m.code}
          medal={m}
          draft={draftFor(m)}
          onChange={(d) => setDrafts({ ...drafts, [m.code]: d })}
          onSave={() => setSaving(m.code)}
        />
      ))}
      {savingMedal && (
        <FormDialog
          title={t('mdSave')}
          intro={<p className="muted small">{t('mdSaveIntro')}</p>}
          fields={[reasonField(t), codeField(t)]}
          confirmLabel={t('mdSave')}
          submit={(v) => {
            const d = draftFor(savingMedal);
            return api.put(`/admin/medals/${encodeURIComponent(savingMedal.code)}`, {
              category: d.category,
              levels: levelsBody(d),
              ...v,
            });
          }}
          onClose={() => setSaving(null)}
          onDone={() => {
            const rest = { ...drafts };
            delete rest[savingMedal.code];
            setDrafts(rest);
            setSaving(null);
            toast(t('mdSaved'));
            reload();
          }}
        />
      )}
    </>
  );
}
