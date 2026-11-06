import { useState } from 'react';
import {
  BADGE_COLORS,
  BADGE_ORDER,
  badgeProblems,
  defaultNewUntil,
  setBadgeUntil,
  TIMED,
  toggleBadge,
  type BadgeState,
  type ItemBadgeCode,
} from '../badges';
import { useApp } from '../context';
import type { Key } from '../i18n';
import { BadgeIcon } from '../ui/badge-icons';

/** One badge as a coloured pill: its icon and (unless `iconOnly`) its name — the app's look. */
export function BadgeChip({ code, iconOnly = false, ended = false }: { code: ItemBadgeCode; iconOnly?: boolean; ended?: boolean }) {
  const { t } = useApp();
  const c = BADGE_COLORS[code];
  const name = t(`badge${code}` as Key);
  return (
    <span
      className={`item-badge${iconOnly ? ' icon-only' : ''}${ended ? ' ended' : ''}`}
      data-item-badge={code}
      title={name}
      style={{ background: c.fill, color: c.ink, borderColor: c.edge ?? c.fill }}
    >
      <BadgeIcon code={code} size={13} />
      {iconOnly ? <span className="sr-only">{name}</span> : <span>{name}</span>}
    </span>
  );
}

/**
 * v1.79-live (D289, CONVENTIONS §10.102): the badge choice of the gift and store forms — nine rows (icon, name, a date
 * for the timed ones), the sound pair as one choice, «تلقائي» on what the uploaded file pre-selected, ended ones marked.
 */
export function BadgePicker({
  value,
  onChange,
  now = new Date(),
  detected = [],
}: {
  value: BadgeState;
  onChange: (next: BadgeState) => void;
  now?: Date;
  /** The badges just pre-selected from a file (for the note). */
  detected?: readonly ItemBadgeCode[];
}) {
  const { t } = useApp();
  const [cleared, setCleared] = useState<{ name: ItemBadgeCode; other: ItemBadgeCode } | null>(null);
  const problems = badgeProblems(value, now);
  const tick = (code: ItemBadgeCode, on: boolean) => {
    const other: ItemBadgeCode | null = code === 'SOUND' ? 'NO_SOUND' : code === 'NO_SOUND' ? 'SOUND' : null;
    // The note stays until the sound choice changes again.
    if (other) setCleared(on && value[other].on ? { name: other, other: code } : null);
    onChange(toggleBadge(value, code, on));
  };
  const problemOf = (code: ItemBadgeCode): Key | null => {
    const p = problems.find((x) => x.startsWith(`${code}:`));
    if (!p) return null;
    if (p.endsWith('until_required')) return 'badgeUntilRequired';
    if (p.endsWith('until_past')) return 'badgeUntilPast';
    if (p.endsWith('until_too_far')) return 'badgeUntilTooFar';
    return 'badgeUntilRequired';
  };
  return (
    <fieldset className="span-2 badge-picker" data-badge-picker>
      <legend>{t('badgesTitle')}</legend>
      <p className="hint">{t('badgesHint')}</p>
      {detected.length > 0 && (
        <p className="alert info" data-badge-detected>
          {t('badgeDetected', { list: detected.map((c) => t(`badge${c}` as Key)).join('، ') })}
        </p>
      )}
      <div className="badge-rows">
        {BADGE_ORDER.map((code) => {
          const c = value[code];
          const id = `badge-${code}`;
          const problem = c.on ? problemOf(code) : null;
          const sound = code === 'SOUND' || code === 'NO_SOUND';
          return (
            <div key={code} className={`badge-row${c.on ? ' on' : ''}${sound ? ' sound' : ''}`} data-badge-row={code}>
              <input id={id} type="checkbox" checked={c.on} onChange={(e) => tick(code, e.target.checked)} />
              <label htmlFor={id}>
                <BadgeChip code={code} />
              </label>
              {c.auto && c.on && (
                <span className="badge info" data-badge-auto={code}>
                  {t('badgeAuto')}
                </span>
              )}
              {c.ended && !c.on && <span className="badge">{t('badgeEnded')}</span>}
              {TIMED.includes(code) && c.on && (
                <span className="badge-until">
                  <label htmlFor={`${id}-until`} className="small muted">
                    {t('badgeUntil')}
                  </label>
                  <input
                    id={`${id}-until`}
                    type="date"
                    className="ltr"
                    value={c.until}
                    required={code !== 'NEW'}
                    onChange={(e) => onChange(setBadgeUntil(value, code, e.target.value))}
                  />
                  {code === 'NEW' && !c.until && (
                    <span className="hint">{t('badgeNewDefault', { date: defaultNewUntil(now) })}</span>
                  )}
                  {problem && (
                    <span className="hint error" role="alert">
                      {t(problem)}
                    </span>
                  )}
                </span>
              )}
            </div>
          );
        })}
      </div>
      <p className={`hint${cleared ? ' warn' : ''}`} data-badge-exclusive>
        {cleared
          ? t('badgeSoundCleared', { name: t(`badge${cleared.name}` as Key), other: t(`badge${cleared.other}` as Key) })
          : t('badgeSoundExclusive')}
      </p>
      <p className="hint">{t('badgeEndAfter')}</p>
    </fieldset>
  );
}

/**
 * v1.79-live (D289, owner answer Q2): the lists' note — how many items carry a «موسمي» without an end, with a filter to
 * show only them. Nothing when there are none.
 */
export function SeasonalNoEndNote({ count, only, onOnly }: { count: number; only: boolean; onOnly: (only: boolean) => void }) {
  const { t } = useApp();
  if (count === 0 && !only) return null;
  return (
    <div className="alert warn row seasonal-no-end" data-seasonal-no-end={count}>
      <span>{t('badgeSeasonalNoEndCount', { n: count })}</span>
      <button type="button" className="btn small" onClick={() => onOnly(!only)} data-seasonal-filter={only ? 'on' : 'off'}>
        {only ? t('badgeSeasonalNoEndAll') : t('badgeSeasonalNoEndFilter')}
      </button>
    </div>
  );
}

/** The per-item hint «حدد تاريخ الانتهاء». */
export function SeasonalNoEndHint() {
  const { t } = useApp();
  return (
    <span className="badge warn" data-seasonal-no-end-hint>
      {t('badgeSeasonalNoEnd')}
    </span>
  );
}
