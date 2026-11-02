import { useState } from 'react';
import { useT } from './context';

/**
 * OBS Virtual Camera as a first-class source (D247): the one-line how-to always, the steps on demand, and whether it
 * is connected now (its label is in the camera list; the list refreshes on `devicechange`).
 */
export function ObsHelp({ found, prominent }: { found: boolean; prominent: boolean }) {
  const { t } = useT();
  const [open, setOpen] = useState(prominent);
  return (
    <div className={`obs ${prominent ? 'prominent' : ''}`} data-testid="obs-help" data-found={found}>
      <div className="obs-head">
        <span className="obs-badge">{t('obsTag')}</span>
        <div>
          <strong>{t('obsTitle')}</strong>
          <p className="small">{t('obsHowTo')}</p>
        </div>
      </div>
      <p className={`small ${found ? 'ok' : 'muted'}`} role="status">
        {found ? `✓ ${t('obsFound')}` : t('obsNotFound')}
      </p>
      <button type="button" className="link small" aria-expanded={open} onClick={() => setOpen((v) => !v)}>
        {t('obsMore')}
      </button>
      {open && (
        <ol className="steps small">
          <li>{t('obsStep1')}</li>
          <li>{t('obsStep2')}</li>
          <li>{t('obsStep3')}</li>
          <li>{t('obsStep4')}</li>
          <li className="muted">{t('obsIdleNote')}</li>
        </ol>
      )}
    </div>
  );
}
