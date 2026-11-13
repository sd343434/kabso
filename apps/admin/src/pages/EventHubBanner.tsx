import { useEffect, useState } from 'react';
import { uploadEventMedia } from '../api';
import { useApp } from '../context';
import type { EventMediaSpec, GiftEventFormState } from '../gift-events';

/**
 * v1.119-social (D359, CONVENTIONS §10.154): the published spec of the Live hub carousel banner, used when the server's
 * `EventOptions.specs` has none (an older server). Same numbers as `EVENT_MEDIA_SPECS.banner` (the API enforces them).
 */
export const HUB_BANNER_SPEC: EventMediaSpec = {
  kind: 'banner',
  width: 1500,
  height: 300,
  formats: ['PNG', 'JPEG', 'WEBP', 'GIF (animated)', 'WEBP (animated)'],
  maxStillBytes: 2 * 1024 * 1024,
  maxAnimatedBytes: 5 * 1024 * 1024,
  maxDurationMs: 10_000,
  transparent: false,
  safeZone: 'Text inside the centred 900 × 240 px (60 % × 80 %): the corners may be covered by the page dots.',
};

/** What the panel can tell about a chosen file before it is sent (the server checks again). */
export type HubBannerProblem =
  | { key: 'evHubBannerFormat' }
  | { key: 'evHubBannerTooBig'; size: number; max: number }
  | { key: 'evHubBannerTooSmall'; w: number; h: number }
  | { key: 'evHubBannerShape'; ratio: number };

const FORMATS = ['image/png', 'image/jpeg', 'image/webp', 'image/gif'];

/**
 * The checks of `checkEventImage('banner')` the panel can run locally: the type, the size (a GIF / WebP may be animated,
 * so it gets the animated limit), at least 1500 × 300 and the 5:1 shape (±1 %). Null when it may be sent.
 */
export function hubBannerProblem(
  file: { type: string; size: number },
  dims: { w: number; h: number } | null,
  spec: EventMediaSpec = HUB_BANNER_SPEC,
): HubBannerProblem | null {
  if (!FORMATS.includes(file.type)) return { key: 'evHubBannerFormat' };
  const mayAnimate = file.type === 'image/gif' || file.type === 'image/webp';
  const max = (mayAnimate ? spec.maxAnimatedBytes : spec.maxStillBytes) ?? spec.maxStillBytes ?? Infinity;
  if (file.size > max) return { key: 'evHubBannerTooBig', size: file.size, max };
  if (!dims || spec.width === null || spec.height === null) return null;
  const want = spec.width / spec.height;
  const ratio = dims.w / dims.h;
  if (Math.abs(ratio - want) / want > 0.01) return { key: 'evHubBannerShape', ratio: Math.round(ratio * 100) / 100 };
  if (dims.w < spec.width || dims.h < spec.height) return { key: 'evHubBannerTooSmall', w: dims.w, h: dims.h };
  return null;
}

const mb = (n: number) => `${String(Math.round((n / 1048576) * 10) / 10)} MB`;

/** Reads a picture's natural size in the browser (null when it cannot). */
function naturalSize(url: string): Promise<{ w: number; h: number } | null> {
  return new Promise((resolve) => {
    const img = new Image();
    img.onload = () => resolve({ w: img.naturalWidth, h: img.naturalHeight });
    img.onerror = () => resolve(null);
    img.src = url;
  });
}

/**
 * «بانر صفحة البث» (D359): the event's banner in the Live hub's existing carousel — the only way an event shows there.
 * The picture (guidance, local checks, a 5:1 crop preview at phone width with the text safe zone), on / off (the
 * picture kept), «يظهر قبل البداية», who sees it (the event's audience) and when. Saved with the event
 * (`bannerMediaId`, `bannerEnabled`, `bannerBeforeStart`); the server makes / updates / removes the linked banner.
 */
export function EventHubBannerField({
  f,
  spec = HUB_BANNER_SPEC,
  imageUrl,
  onChange,
  onUploaded,
  onError,
  onEditAudience,
}: {
  f: Pick<
    GiftEventFormState,
    'bannerMediaId' | 'bannerEnabled' | 'bannerBeforeStart' | 'audience' | 'startsAt' | 'endsAt' | 'permanent' | 'timeZone'
  >;
  spec?: EventMediaSpec;
  imageUrl: string | null;
  onChange: (k: 'bannerMediaId' | 'bannerEnabled' | 'bannerBeforeStart', v: string | boolean) => void;
  onUploaded: (mediaId: string, url: string | null) => void;
  onError: (e: unknown) => void;
  onEditAudience?: () => void;
}) {
  const { t } = useApp();
  const [local, setLocal] = useState<string | null>(null);
  const [problem, setProblem] = useState<HubBannerProblem | null>(null);
  const [busy, setBusy] = useState(false);
  useEffect(() => () => (local ? URL.revokeObjectURL(local) : undefined), [local]);
  const shown = local ?? imageUrl;
  const has = !!f.bannerMediaId;

  const pick = async (file: File) => {
    onError(null);
    const url = URL.createObjectURL(file);
    setLocal(url);
    const found = hubBannerProblem(file, await naturalSize(url), spec);
    setProblem(found);
    if (found) return;
    setBusy(true);
    uploadEventMedia('banner', file).then(
      (up) => {
        setBusy(false);
        onUploaded(up.mediaId ?? '', up.url);
      },
      (e: unknown) => {
        setBusy(false);
        onError(e);
      },
    );
  };
  const problemText = (p: HubBannerProblem) =>
    p.key === 'evHubBannerTooBig'
      ? t(p.key, { size: mb(p.size), max: mb(p.max) })
      : p.key === 'evHubBannerTooSmall'
        ? t(p.key, { w: p.w, h: p.h })
        : p.key === 'evHubBannerShape'
          ? t(p.key, { ratio: p.ratio })
          : t(p.key);
  const to = f.permanent || !f.endsAt ? t('evHubBannerNoEnd') : `${f.endsAt.replace('T', ' ')} (${f.timeZone})`;
  const from = f.bannerBeforeStart
    ? t('evHubBannerFromPublish')
    : f.startsAt
      ? `${f.startsAt.replace('T', ' ')} (${f.timeZone})`
      : t('evHubBannerFromStart');

  return (
    <fieldset className="field span-2 ev-hub-banner" data-testid="ev-hub-banner">
      <legend>{t('evHubBanner')}</legend>
      <p className="hint">{t('evHubBannerIntro')}</p>
      <label className="check">
        <input
          id="ev-hub-banner-on"
          type="checkbox"
          checked={f.bannerEnabled}
          onChange={(e) => onChange('bannerEnabled', e.target.checked)}
        />
        {t('evHubBannerOn')}
      </label>
      {!f.bannerEnabled && <span className="hint">{t('evHubBannerOffHint')}</span>}
      <div className="ev-hub-banner-body" data-off={f.bannerEnabled ? undefined : 'true'}>
        <label htmlFor="ev-banner">{t('evHubBannerFile')}</label>
        <div className="row">
          <input
            id="ev-banner"
            type="file"
            accept={FORMATS.join(',')}
            disabled={busy}
            onChange={(e) => {
              const file = e.target.files?.[0];
              if (file) void pick(file);
            }}
          />
          {has && (
            <button
              type="button"
              className="btn small"
              onClick={() => {
                setLocal(null);
                setProblem(null);
                onChange('bannerMediaId', '');
                onUploaded('', null);
              }}
            >
              {t('evHubBannerRemove')}
            </button>
          )}
          {busy && <span className="muted small">{t('evHubBannerUploading')}</span>}
        </div>
        <ul className="hint ev-hub-banner-guide">
          <li>{t('evHubBannerGuide')}</li>
          <li>
            {t('evHubBannerLimits', {
              still: mb(spec.maxStillBytes ?? 0),
              animated: mb(spec.maxAnimatedBytes ?? 0),
              seconds: (spec.maxDurationMs ?? 0) / 1000,
            })}
          </li>
          <li>{t('evHubBannerSafe')}</li>
        </ul>
        {problem && (
          <p className="error small" role="alert">
            {problemText(problem)}
          </p>
        )}
        <span className="muted small">{t('evHubBannerPreview')}</span>
        <div className="ev-hub-phone" aria-label={t('evHubBannerPreview')}>
          <div className="ev-hub-slide">
            {shown ? <img src={shown} alt="" /> : <span className="muted small">{t('evHubBannerNone')}</span>}
            <span className="ev-hub-safe" aria-hidden="true" />
            <span className="ev-hub-dots" aria-hidden="true" />
          </div>
        </div>
        <label className="check">
          <input
            id="ev-hub-banner-early"
            type="checkbox"
            checked={f.bannerBeforeStart}
            onChange={(e) => onChange('bannerBeforeStart', e.target.checked)}
          />
          {t('evHubBannerBeforeStart')}
        </label>
        <span className="hint">{t('evHubBannerBeforeStartHint')}</span>
        <p className="small">
          {t('evHubBannerAudience', { audience: t(`evAudience_${f.audience}`) })}{' '}
          {onEditAudience && (
            <button type="button" className="btn link small" onClick={onEditAudience}>
              {t('evHubBannerAudienceChange')}
            </button>
          )}
        </p>
        <span className="hint">{t('evBannerHint')}</span>
        <p className="small muted">{t('evHubBannerWindow', { from, to })}</p>
        <p className="small muted">{t('evHubBannerOrder')}</p>
      </div>
    </fieldset>
  );
}
