import { useEffect, useState } from 'react';
import { api } from '../api';
import { ErrorAlert, Loading, useAsync } from '../components';
import { useApp } from '../context';
import type { CameraFxEngine, CameraFxSettings, SiteSettings as Settings } from '../types';

export function SiteSettings() {
  const { t, toast } = useApp();
  const { data, error, loading } = useAsync(() => api.get<Settings>('/admin/site-settings'), []);
  const [form, setForm] = useState({ instagram: '', tiktok: '', whatsapp: '', topupEnabled: false, reason: '' });
  const [saveError, setSaveError] = useState<unknown>(null);
  const [busy, setBusy] = useState(false);
  useEffect(() => {
    if (data)
      setForm({
        instagram: data.socials.instagram ?? '',
        tiktok: data.socials.tiktok ?? '',
        whatsapp: data.socials.whatsapp ?? '',
        topupEnabled: data.topupEnabled,
        reason: '',
      });
  }, [data]);
  if (loading && !data) return <Loading />;
  if (!data) return <ErrorAlert error={error} />;
  const set = (k: keyof typeof form) => (e: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement>) =>
    setForm((f) => ({ ...f, [k]: e.target.value }));
  return (
    <>
      <div className="page-head">
        <div>
          <h1>{t('siteTitle')}</h1>
          <p className="muted small">{t('siteSubtitle')}</p>
        </div>
      </div>
      <form
        className="card"
        style={{ maxWidth: 640 }}
        onSubmit={(e) => {
          e.preventDefault();
          setBusy(true);
          setSaveError(null);
          api
            .put<Settings>('/admin/site-settings', {
              socials: { instagram: form.instagram.trim() || null, tiktok: form.tiktok.trim() || null, whatsapp: form.whatsapp.trim() || null },
              topupEnabled: form.topupEnabled,
              ...(form.reason.trim() ? { reason: form.reason.trim() } : {}),
            })
            .then(
              (saved) => {
                setBusy(false);
                setForm({
                  instagram: saved.socials.instagram ?? '',
                  tiktok: saved.socials.tiktok ?? '',
                  whatsapp: saved.socials.whatsapp ?? '',
                  topupEnabled: saved.topupEnabled,
                  reason: '',
                });
                toast(t('saved'));
              },
              (err: unknown) => {
                setBusy(false);
                setSaveError(err);
              },
            );
        }}
      >
        <ErrorAlert error={saveError} />
        <div className="field">
          <label htmlFor="s-ig">{t('instagram')}</label>
          <input id="s-ig" type="text" className="ltr" placeholder="https://www.instagram.com/…" value={form.instagram} onChange={set('instagram')} />
        </div>
        <div className="field">
          <label htmlFor="s-tt">{t('tiktok')}</label>
          <input id="s-tt" type="text" className="ltr" placeholder="https://www.tiktok.com/@…" value={form.tiktok} onChange={set('tiktok')} />
        </div>
        <div className="field">
          <label htmlFor="s-wa">{t('whatsapp')}</label>
          <input id="s-wa" type="text" className="ltr" placeholder="+966…" value={form.whatsapp} onChange={set('whatsapp')} />
        </div>
        <label className="check field">
          <input type="checkbox" checked={form.topupEnabled} onChange={(e) => setForm((f) => ({ ...f, topupEnabled: e.target.checked }))} />
          {t('topupEnabled')}
        </label>
        <div className="field">
          <label htmlFor="s-reason">{t('reason')}</label>
          <textarea id="s-reason" maxLength={500} value={form.reason} onChange={set('reason')} />
          <span className="hint">{t('reasonHint')}</span>
        </div>
        <button className="btn primary" disabled={busy}>
          {t('save')}
        </button>
      </form>
      <CameraFxCard />
    </>
  );
}

/** D228: the PUT body of «محرك مؤثرات الكاميرا» (a reason only when typed). */
export function cameraFxBody(engine: CameraFxEngine, reason: string): { cameraFxEngine: CameraFxEngine; reason?: string } {
  return { cameraFxEngine: engine, ...(reason.trim() ? { reason: reason.trim() } : {}) };
}

/** D228: the form of «محرك مؤثرات الكاميرا» (the app's camera effects engine), pure for the tests. */
export function CameraFxView(props: {
  engine: CameraFxEngine;
  reason: string;
  busy: boolean;
  onEngine: (engine: CameraFxEngine) => void;
  onReason: (reason: string) => void;
  onSave: () => void;
}) {
  const { t } = useApp();
  const option = (value: CameraFxEngine, label: string) => (
    <label className="check field">
      <input type="radio" name="camera-fx" value={value} checked={props.engine === value} onChange={() => props.onEngine(value)} />
      {label}
    </label>
  );
  return (
    <form
      className="card"
      style={{ maxWidth: 640, marginTop: 16 }}
      onSubmit={(e) => {
        e.preventDefault();
        props.onSave();
      }}
    >
      <h2>{t('fxTitle')}</h2>
      <p className="muted small">{t('fxIntro')}</p>
      {option('DEEPAR', t('fxDeepar'))}
      {option('FREE', t('fxFree'))}
      {props.engine === 'FREE' ? <p className="hint">{t('fxFreeNote')}</p> : null}
      <div className="field">
        <label htmlFor="fx-reason">{t('reason')}</label>
        <textarea id="fx-reason" maxLength={500} value={props.reason} onChange={(e) => props.onReason(e.target.value)} />
      </div>
      <button className="btn primary" disabled={props.busy}>
        {t('fxSave')}
      </button>
    </form>
  );
}

function CameraFxCard() {
  const { t, toast } = useApp();
  const { data, error, loading } = useAsync(() => api.get<CameraFxSettings>('/admin/camera-fx'), []);
  const [engine, setEngine] = useState<CameraFxEngine>('DEEPAR');
  const [reason, setReason] = useState('');
  const [busy, setBusy] = useState(false);
  const [saveError, setSaveError] = useState<unknown>(null);
  useEffect(() => {
    if (data) setEngine(data.cameraFxEngine);
  }, [data]);
  if (loading && !data) return <Loading />;
  if (!data) return <ErrorAlert error={error} />;
  return (
    <>
      <ErrorAlert error={saveError} />
      <CameraFxView
        engine={engine}
        reason={reason}
        busy={busy}
        onEngine={setEngine}
        onReason={setReason}
        onSave={() => {
          setBusy(true);
          setSaveError(null);
          api.put<CameraFxSettings>('/admin/camera-fx', cameraFxBody(engine, reason)).then(
            (saved) => {
              setBusy(false);
              setEngine(saved.cameraFxEngine);
              setReason('');
              toast(t('saved'));
            },
            (err: unknown) => {
              setBusy(false);
              setSaveError(err);
            },
          );
        }}
      />
    </>
  );
}
