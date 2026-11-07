import { useState } from 'react';
import { api } from '../api';
import { codeField, ErrorAlert, FormDialog, Loading, reasonField, useAsync } from '../components';
import { useApp } from '../context';
import { formatDate, formatNumber } from '../format';
import type { Key } from '../i18n';
import { VERIFICATION_BADGES, type VerificationBadge } from '../types';

/**
 * v1.90-social (D293, CONVENTIONS §10.105): «شارات التوثيق» — the badges in the owner's priority order with who gets
 * each and how many hold it now, and the OWNER's four thresholds (`verification.settings`: a reason and the
 * authenticator code again; everyone recomputed at once). The team reads it (`verification.view`). Every threshold is
 * «more than» over the last 30 days.
 */
export const THRESHOLD_KEYS = [
  'rechargeMinSalesCoins',
  'rechargeMinCherries',
  'hostAgentMinHosts',
  'hostAgentMinCherries',
] as const;
export type ThresholdKey = (typeof THRESHOLD_KEYS)[number];
export type Thresholds = Record<ThresholdKey, number>;

export interface VerificationSettingsView {
  settings: Thresholds;
  defaults: Thresholds;
  windowDays: number;
  holders: Record<VerificationBadge, number>;
  lastRunAt: string | null;
  updatedAt: string;
}

/** The badge's colours in the panel (the app's seal colours). */
export const BADGE_COLOURS: Record<VerificationBadge, { bg: string; fg: string; ring?: string }> = {
  OWNER: { bg: '#111111', fg: '#E8C25A', ring: '#E8C25A' },
  STAFF: { bg: '#D32F2F', fg: '#FFFFFF' },
  RECHARGE_AGENT: { bg: '#C9971C', fg: '#FFFFFF' },
  HOST_AGENT: { bg: '#2E9D4F', fg: '#FFFFFF' },
  CREATOR: { bg: '#7B3FC4', fg: '#FFFFFF' },
  VERIFIED_HOST: { bg: '#1E88E5', fg: '#FFFFFF' },
};

/** The changed thresholds of the draft, or null when one is not a whole number in range. */
export function thresholdChanges(
  current: Thresholds,
  draft: Record<ThresholdKey, string>,
): Partial<Thresholds> | null {
  const out: Partial<Thresholds> = {};
  for (const k of THRESHOLD_KEYS) {
    const raw = draft[k].trim();
    if (!/^[0-9]{1,16}$/.test(raw)) return null;
    const v = Number(raw);
    const max = k === 'hostAgentMinHosts' ? 100_000 : 1e15;
    if (!Number.isSafeInteger(v) || v > max) return null;
    if (v !== current[k]) out[k] = v;
  }
  return out;
}

/** The badge as a small coloured chip (the user page, the list on this page). */
export function VerificationChip({ badge }: { badge: VerificationBadge }) {
  const { t } = useApp();
  const c = BADGE_COLOURS[badge];
  return (
    <span
      className="badge"
      data-verification={badge}
      style={{
        background: c.bg,
        color: c.fg,
        border: c.ring ? `1px solid ${c.ring}` : undefined,
      }}
      title={`${t('vbBadge')}: ${t(`vb${badge}` as Key)}`}
    >
      ✓ {t(`vb${badge}` as Key)}
    </span>
  );
}

export function VerificationBadgesPage() {
  const view = useAsync(() => api.get<VerificationSettingsView>('/admin/verification-badges/settings'), []);
  if (view.error) return <ErrorAlert error={view.error} />;
  if (view.loading || !view.data) return <Loading />;
  return <SettingsBody key={view.data.updatedAt} view={view.data} onSaved={view.reload} />;
}

export function SettingsBody({ view, onSaved }: { view: VerificationSettingsView; onSaved: () => void }) {
  const { t, lang, can, toast } = useApp();
  const editable = can('verification.settings');
  const [draft, setDraft] = useState<Record<ThresholdKey, string>>(
    Object.fromEntries(THRESHOLD_KEYS.map((k) => [k, String(view.settings[k])])) as Record<
      ThresholdKey,
      string
    >,
  );
  const [confirm, setConfirm] = useState(false);
  const changes = thresholdChanges(view.settings, draft);
  return (
    <div className="page" data-page="verification-badges">
      <h1>{t('navVerificationBadges')}</h1>
      <p className="muted">{t('vbIntro')}</p>
      <p className="muted small">
        {t('vbWindow', { n: String(view.windowDays) })} ·{' '}
        {view.lastRunAt ? t('vbLastRun', { d: formatDate(view.lastRunAt, lang) }) : t('vbNeverRun')}
      </p>
      <div className="card">
        <table className="table">
          <thead>
            <tr>
              <th>{t('vbBadge')}</th>
              <th>{t('vbHolders')}</th>
            </tr>
          </thead>
          <tbody>
            {VERIFICATION_BADGES.map((b) => (
              <tr key={b} data-badge-row={b}>
                <td>
                  <VerificationChip badge={b} /> <span className="muted small">{t(`vbRule${b}` as Key)}</span>
                </td>
                <td className="num">{formatNumber(view.holders[b], lang)}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      <div className="card">
        {!editable && <p className="muted small">{t('vbReadOnly')}</p>}
        {THRESHOLD_KEYS.map((k) => (
          <div className="field" key={k}>
            <label htmlFor={`vb-${k}`}>
              {t(`vbSet${k}` as Key)} — {t('vbMoreThan')}
            </label>
            <input
              id={`vb-${k}`}
              type="number"
              min={0}
              step={1}
              inputMode="numeric"
              dir="ltr"
              value={draft[k]}
              disabled={!editable}
              onChange={(e) => setDraft((d) => ({ ...d, [k]: e.target.value }))}
            />
            <span className="hint">{t('vbDefault', { v: formatNumber(view.defaults[k], lang) })}</span>
          </div>
        ))}
        {changes === null && <p className="error small">{t('vbInvalid')}</p>}
        {editable && (
          <button
            className="btn primary"
            disabled={changes === null || Object.keys(changes).length === 0}
            onClick={() => setConfirm(true)}
          >
            {t('vbSave')}
          </button>
        )}
      </div>
      {confirm && changes && (
        <FormDialog
          title={t('vbSave')}
          intro={<p className="muted small">{t('vbSaveIntro')}</p>}
          fields={[reasonField(t), codeField(t)]}
          confirmLabel={t('vbSave')}
          submit={(v) => api.put('/admin/verification-badges/settings', { ...changes, ...v })}
          onClose={() => setConfirm(false)}
          onDone={() => {
            setConfirm(false);
            toast(t('vbSaved'));
            onSaved();
          }}
        />
      )}
    </div>
  );
}
