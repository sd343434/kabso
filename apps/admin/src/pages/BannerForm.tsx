import { useEffect, useState } from 'react';
import { api, uploadBannerPicture } from '../api';
import { Dialog, ErrorAlert } from '../components';
import { useApp } from '../context';

/**
 * v1.59-live (D248, CONVENTIONS §10.90): where a banner is shown and the shape its picture is cover-cropped to by the
 * server (around the centre, as the CLI's `--image`). The preview crops the chosen file the same way.
 */
export const BANNER_SHAPES = {
  home: { width: 1500, height: 500 },
  hub_card: { width: 720, height: 805 },
  room: { width: 600, height: 800 },
  tasks: { width: 1500, height: 500 },
  wallet: { width: 1500, height: 500 },
} as const;
export type BannerPlacementKey = keyof typeof BANNER_SHAPES;
export const BANNER_PLACEMENT_KEYS = Object.keys(BANNER_SHAPES) as BannerPlacementKey[];

/** The panel's label key for a stored placement (`HUB_CARD` → `bannerPlacement_hub_card`). */
export function placementLabelKey(placement: string): `bannerPlacement_${BannerPlacementKey}` | null {
  const key = placement.toLowerCase();
  return key in BANNER_SHAPES ? (`bannerPlacement_${key as BannerPlacementKey}` as const) : null;
}

/** Local `datetime-local` text → an ISO time with the browser's offset. */
const localToIso = (value: string): string => new Date(value).toISOString();

export interface BannerFormFields {
  placement: BannerPlacementKey;
  link: string;
  titleAr: string;
  titleEn: string;
  titleSide: 'LEFT' | 'RIGHT';
  startsAt: string;
  endsAt: string;
  sortOrder: string;
  reason: string;
}

/** The `POST /admin/banners` body for an uploaded picture (empty optional fields left out). */
export function bannerBody(mediaId: string, f: BannerFormFields) {
  const sort = Number(f.sortOrder);
  return {
    mediaId,
    placement: f.placement,
    link: f.link.trim(),
    ...(f.titleAr.trim() ? { titleAr: f.titleAr.trim() } : {}),
    ...(f.titleEn.trim() ? { titleEn: f.titleEn.trim() } : {}),
    titleSide: f.titleSide,
    ...(f.startsAt ? { startsAt: localToIso(f.startsAt) } : {}),
    ...(f.endsAt ? { endsAt: localToIso(f.endsAt) } : {}),
    ...(f.sortOrder.trim() && Number.isInteger(sort) ? { sortOrder: sort } : {}),
    reason: f.reason.trim(),
  };
}

const EMPTY: BannerFormFields = {
  placement: 'home',
  link: '',
  titleAr: '',
  titleEn: '',
  titleSide: 'RIGHT',
  startsAt: '',
  endsAt: '',
  sortOrder: '0',
  reason: '',
};

/** «إضافة بانر»: the picture (cropped preview), where it shows, the link, the window and the reason. */
export function BannerForm({ onClose, onDone, initial = EMPTY }: { onClose: () => void; onDone: () => void; initial?: BannerFormFields }) {
  const { t } = useApp();
  const [f, setF] = useState<BannerFormFields>(initial);
  const [file, setFile] = useState<File | null>(null);
  const [preview, setPreview] = useState<string | null>(null);
  const [progress, setProgress] = useState<number | null>(null);
  const [error, setError] = useState<unknown>(null);
  const [busy, setBusy] = useState(false);
  useEffect(() => {
    if (!file) {
      setPreview(null);
      return;
    }
    const url = URL.createObjectURL(file);
    setPreview(url);
    return () => URL.revokeObjectURL(url);
  }, [file]);
  const set = (k: keyof BannerFormFields) => (e: { target: { value: string } }) => setF((x) => ({ ...x, [k]: e.target.value }));
  const shape = BANNER_SHAPES[f.placement];
  const ok = file !== null && !!f.link.trim() && !!f.reason.trim();
  return (
    <Dialog title={t('bannerCreate')} onClose={onClose}>
      <ErrorAlert error={error} />
      <form
        className="form-grid"
        onSubmit={(e) => {
          e.preventDefault();
          if (!ok || busy) return;
          setBusy(true);
          setError(null);
          uploadBannerPicture(f.placement, file, setProgress)
            .then((up) => api.post('/admin/banners', bannerBody(up.mediaId, f)))
            .then(onDone, (err: unknown) => {
              setError(err);
              setBusy(false);
              setProgress(null);
            });
        }}
      >
        <div className="field">
          <label htmlFor="bn-placement">{t('bannerPlacement')}</label>
          <select id="bn-placement" value={f.placement} onChange={set('placement')}>
            {BANNER_PLACEMENT_KEYS.map((p) => (
              <option key={p} value={p}>
                {t(`bannerPlacement_${p}`)}
              </option>
            ))}
          </select>
          <span className="hint">{t('bannerSizeHint', { w: shape.width, h: shape.height })}</span>
        </div>
        <div className="field">
          <label htmlFor="bn-file">{t('bannerPicture')}</label>
          <input id="bn-file" type="file" accept="image/jpeg,image/png,image/webp" onChange={(e) => setFile(e.target.files?.[0] ?? null)} />
          <span className="hint">{t('bannerPictureHint')}</span>
        </div>
        <div className="field span-2">
          <div
            className="banner-preview"
            data-placement={f.placement}
            style={{
              aspectRatio: `${shape.width} / ${shape.height}`,
              width: `min(100%, ${Math.round((240 * shape.width) / shape.height)}px)`,
            }}
            aria-label={t('bannerPreview')}
          >
            {preview ? <img src={preview} alt="" /> : <span className="muted small">{t('bannerPreview')}</span>}
          </div>
        </div>
        <div className="field span-2">
          <label htmlFor="bn-link">{t('bannerLink')}</label>
          <input id="bn-link" type="text" dir="ltr" maxLength={512} placeholder="/families" value={f.link} onChange={set('link')} />
          <span className="hint">{t('bannerLinkHint')}</span>
        </div>
        <div className="field">
          <label htmlFor="bn-tar">{t('bannerTitleAr')}</label>
          <input id="bn-tar" type="text" maxLength={40} value={f.titleAr} onChange={set('titleAr')} />
        </div>
        <div className="field">
          <label htmlFor="bn-ten">{t('bannerTitleEn')}</label>
          <input id="bn-ten" type="text" dir="ltr" maxLength={40} value={f.titleEn} onChange={set('titleEn')} />
        </div>
        <div className="field">
          <label htmlFor="bn-start">{t('eventStarts')}</label>
          <input id="bn-start" type="datetime-local" value={f.startsAt} onChange={set('startsAt')} />
          <span className="hint">{t('bannerStartsHint')}</span>
        </div>
        <div className="field">
          <label htmlFor="bn-end">{t('eventEnds')}</label>
          <input id="bn-end" type="datetime-local" value={f.endsAt} onChange={set('endsAt')} />
          <span className="hint">{t('bannerEndsHint')}</span>
        </div>
        <div className="field">
          <label htmlFor="bn-sort">{t('bannerSort')}</label>
          <input id="bn-sort" type="number" min={0} max={1000000} value={f.sortOrder} onChange={set('sortOrder')} />
        </div>
        <div className="field span-2">
          <label htmlFor="bn-reason">{t('reason')}</label>
          <textarea id="bn-reason" maxLength={500} value={f.reason} onChange={set('reason')} />
          <span className="hint">{t('reasonHint')}</span>
        </div>
        {progress !== null && (
          <progress className="span-2" max={1} value={progress}>
            {Math.round(progress * 100)}%
          </progress>
        )}
        <div className="actions span-2">
          <button type="button" className="btn" onClick={onClose}>
            {t('cancel')}
          </button>
          <button className="btn primary" disabled={!ok || busy}>
            {t('bannerCreate')}
          </button>
        </div>
      </form>
    </Dialog>
  );
}
