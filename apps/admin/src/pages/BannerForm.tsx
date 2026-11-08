import { useEffect, useState } from 'react';
import { api, ApiError, uploadBannerPicture, uploadBannerVideo, uploadEventMedia } from '../api';
import { Dialog, ErrorAlert, useAsync } from '../components';
import { useApp } from '../context';

/**
 * v1.59-live (D248, CONVENTIONS §10.90): where a banner is shown and the shape its picture is cover-cropped to by the
 * server (around the centre, as the CLI's `--image`). The preview crops the chosen file the same way.
 */
export const BANNER_SHAPES = {
  // D248b: the live hub carousel is 5:1 (the owner's reference).
  home: { width: 1500, height: 300 },
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

/**
 * D248c: whether a picked file is an animation (an animated WebP has an `ANIM` chunk; a GIF more than one graphic
 * control block). Only for the «متحرك» mark: the server decides (and keeps the animation).
 */
export function looksAnimated(bytes: Uint8Array): boolean {
  const ascii = (from: number, to: number) => String.fromCharCode(...bytes.subarray(from, to));
  if (bytes.length >= 12 && ascii(0, 4) === 'RIFF' && ascii(8, 12) === 'WEBP') {
    const head = ascii(12, Math.min(bytes.length, 64));
    return head.includes('ANIM');
  }
  if (bytes.length >= 6 && /^GIF8[79]a$/.test(ascii(0, 6))) {
    let blocks = 0;
    for (let i = 0; i + 2 < bytes.length && blocks < 2; i++) {
      if (bytes[i] === 0x21 && bytes[i + 1] === 0xf9 && bytes[i + 2] === 0x04) blocks++;
    }
    return blocks > 1;
  }
  return false;
}

/** D248c: the server's refusal of an animation, in the panel's language (else null: the usual error box). */
export function animationIssueKey(error: unknown) {
  if (!(error instanceof ApiError)) return null;
  const issue = error.details[0]?.issue;
  switch (issue) {
    case 'banner_animation_too_many_frames':
      return 'bannerAnimTooManyFrames' as const;
    case 'banner_animation_too_long':
      return 'bannerAnimTooLong' as const;
    case 'banner_animation_too_large':
      return 'bannerAnimTooLarge' as const;
    case 'banner_animation_unreadable':
      return 'bannerAnimUnreadable' as const;
    default:
      return null;
  }
}

/** The crop preview in the placement's own shape (the browser plays an animated file, cropped like the server). */
export function BannerPreview({ placement, url, animated }: { placement: BannerPlacementKey; url: string | null; animated: boolean }) {
  const { t } = useApp();
  const shape = BANNER_SHAPES[placement];
  return (
    <div
      className="banner-preview"
      data-placement={placement}
      style={{
        aspectRatio: `${shape.width} / ${shape.height}`,
        width: `min(100%, ${Math.round((240 * shape.width) / shape.height)}px)`,
      }}
      aria-label={t('bannerPreview')}
    >
      {url ? <img src={url} alt="" /> : <span className="muted small">{t('bannerPreview')}</span>}
      {url && animated && <span className="badge ok banner-anim">{t('bannerAnimated')}</span>}
    </div>
  );
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
  /** v1.97-social (D303): `image` (a still or an animated picture) or `video` (home only; the picture is its poster). */
  kind?: 'image' | 'video';
  /** v1.97-social (D303): the event the banner opens ('' = the link). */
  eventId?: string;
}

/**
 * v1.97-social (D303 follow-ups, §10.114.9): an event banner's spec — the carousel's real 5:1 shape. The editor shows
 * the server's `EventOptions.specs`; this line repeats it for the banner form (kept equal by the panel test).
 */
export const EVENT_BANNER_SPEC =
  '1500 × 300 px (5:1) · PNG / JPEG / WebP ≤ 2 MB · animated WebP / GIF ≤ 5 MB, ≤ 10 s · MP4 / MOV (H.264 / HEVC) ≤ 30 MB, ≤ 30 s + a still poster · text in the centred 900 × 240 px';

/** v1.97-social (D303): the server's video limits for a home banner. */
export const BANNER_VIDEO_MAX_BYTES = 30 * 1024 * 1024;

/** The `POST /admin/banners` body for an uploaded picture (empty optional fields left out). */
export function bannerBody(mediaId: string, f: BannerFormFields, videoMediaId: string | null = null) {
  const sort = Number(f.sortOrder);
  return {
    mediaId,
    placement: f.placement,
    // D303: a banner on an event opens it (the server sets the link `/events/<id>`).
    link: f.eventId ? `/events/${f.eventId}` : f.link.trim(),
    ...(videoMediaId ? { videoMediaId } : {}),
    ...(f.eventId ? { eventId: f.eventId } : {}),
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
  const { t, lang } = useApp();
  const [f, setF] = useState<BannerFormFields>(initial);
  const [file, setFile] = useState<File | null>(null);
  const [preview, setPreview] = useState<string | null>(null);
  const [progress, setProgress] = useState<number | null>(null);
  const [error, setError] = useState<unknown>(null);
  const [busy, setBusy] = useState(false);
  const [animated, setAnimated] = useState(false);
  const [video, setVideo] = useState<File | null>(null);
  const events = useAsync(
    () =>
      api.get<{
        data: { id: string; titleAr: string; titleEn: string; state: string }[];
      }>('/admin/events'),
    [],
  );
  useEffect(() => {
    if (!file) {
      setPreview(null);
      setAnimated(false);
      return;
    }
    const url = URL.createObjectURL(file);
    setPreview(url);
    let live = true;
    void file
      .slice(0, 1024 * 1024)
      .arrayBuffer()
      .then((b) => live && setAnimated(looksAnimated(new Uint8Array(b))));
    return () => {
      live = false;
      URL.revokeObjectURL(url);
    };
  }, [file]);
  const issueKey = animationIssueKey(error);
  const set = (k: keyof BannerFormFields) => (e: { target: { value: string } }) => setF((x) => ({ ...x, [k]: e.target.value }));
  const shape = BANNER_SHAPES[f.placement];
  const kind = f.kind ?? 'image';
  const videoOk = kind === 'image' || (f.placement === 'home' && video !== null && video.size <= BANNER_VIDEO_MAX_BYTES);
  const ok = file !== null && (!!f.link.trim() || !!f.eventId) && !!f.reason.trim() && videoOk;
  return (
    <Dialog title={t('bannerCreate')} onClose={onClose}>
      {issueKey ? <p className="alert bad">{t(issueKey)}</p> : <ErrorAlert error={error} />}
      <form
        className="form-grid"
        onSubmit={(e) => {
          e.preventDefault();
          if (!ok || busy) return;
          setBusy(true);
          setError(null);
          // D303: a video banner uploads its video first, then the poster picture.
          (kind === 'video' && video
            ? f.eventId
              ? uploadEventMedia('banner_video', video, setProgress).then((v) => v.mediaId ?? '')
              : uploadBannerVideo(video, setProgress).then((v) => v.mediaId)
            : Promise.resolve(null)
          )
            .then((videoId) =>
              // D303 follow-ups: an event's banner must meet the published spec (checked by the server).
              (f.eventId
                ? uploadEventMedia('banner', file, setProgress).then((up) => ({
                    mediaId: up.mediaId ?? '',
                  }))
                : uploadBannerPicture(f.placement, file, setProgress)
              ).then((up) => api.post('/admin/banners', bannerBody(up.mediaId, f, videoId))),
            )
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
          <input id="bn-file" type="file" accept="image/jpeg,image/png,image/webp,image/gif" onChange={(e) => setFile(e.target.files?.[0] ?? null)} />
          <span className="hint">{t('bannerPictureHint')}</span>
        </div>
        <div className="field span-2">
          <BannerPreview placement={f.placement} url={preview} animated={animated} />
        </div>
        <div className="field">
          <label htmlFor="bn-kind">{t('bannerKind')}</label>
          <select id="bn-kind" value={kind} onChange={(e) => setF((x) => ({ ...x, kind: e.target.value as 'image' | 'video' }))}>
            <option value="image">
              {t('bannerKind_IMAGE')} / {t('bannerKind_ANIMATED')}
            </option>
            <option value="video">{t('bannerKind_VIDEO')}</option>
          </select>
          {kind === 'video' && f.placement !== 'home' && <span className="hint bad">{t('bannerVideoHomeOnly')}</span>}
        </div>
        {kind === 'video' && (
          <div className="field">
            <label htmlFor="bn-video">{t('bannerVideo')}</label>
            <input id="bn-video" type="file" accept="video/mp4,video/quicktime" onChange={(e) => setVideo(e.target.files?.[0] ?? null)} />
            <span className="hint">{t('bannerVideoHint')}</span>
          </div>
        )}
        <div className="field span-2">
          <label htmlFor="bn-event">{t('bannerEvent')}</label>
          <select id="bn-event" value={f.eventId ?? ''} onChange={(e) => setF((x) => ({ ...x, eventId: e.target.value }))}>
            <option value="">{t('bannerEventNone')}</option>
            {events.data?.data
              .filter((ev) => ev.state === 'UPCOMING' || ev.state === 'RUNNING')
              .map((ev) => (
                <option key={ev.id} value={ev.id}>
                  {lang === 'ar' ? ev.titleAr : ev.titleEn}
                </option>
              ))}
          </select>
          <span className="hint">{t('bannerEventHint')}</span>
          {f.eventId && (
            <span className="hint ltr spec" data-spec="banner">
              {t('bannerSpecHint')}: {EVENT_BANNER_SPEC}
            </span>
          )}
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
