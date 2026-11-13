import { useEffect, useRef, useState } from 'react';
import { uploadGiftFile, type GiftUpload } from '../api';
import { ErrorAlert } from '../components';
import { useApp } from '../context';
import { formatNumber } from '../format';
import { playSvga, readSvga, type SvgaMovie } from '../svga';
import { Icon } from '../ui/icons';

/**
 * v1.71-social (D207, CONVENTIONS §10.66): the gift form's files — «صورة الهدية», «ملف العرض» (SVGA or MP4) and an MP3
 * sound — and a category's icon. Each slot uploads the chosen file at once (progress shown; the server checks it and
 * answers its key), previews it (the image, the MP4 — composited when side-by-side alpha —, the SVGA's bitmaps, the
 * MP3) and offers «إزالة». The form sends only the keys.
 */

export type Alpha = 'NONE' | 'SIDE_BY_SIDE';

/** A slot's value: the stored key (null: none / removed) and what the preview plays. */
export interface FileValue {
  key: string | null;
  /** The same-origin preview URL ({@link previewUrl}). */
  url: string | null;
  format?: 'SVGA' | 'MP4' | undefined;
  info?: GiftUpload | undefined;
  /** The chosen file (an SVGA is previewed from its bytes). */
  file?: File | undefined;
  durationMs?: number | null | undefined;
}

export const NO_FILE: FileValue = { key: null, url: null };

/**
 * The same-origin preview URL of a stored file (`GET /admin/gift-files`): the panel's CSP allows media only from
 * 'self', and the side-by-side composite reads the video's pixels, which needs the same origin.
 */
export function previewUrl(key: string | null): string | null {
  return key ? `/api/v1/admin/gift-files?key=${encodeURIComponent(key)}` : null;
}

const ACCEPT: Record<GiftUpload['kind'], string> = {
  image: 'image/png,image/webp',
  icon: 'image/png,image/webp',
  animation: '.svga,video/mp4,.mp4',
  sound: 'audio/mpeg,.mp3',
};

const seconds = (ms: number | null | undefined) => (ms ? (ms / 1000).toFixed(1) : '0');

/** Plays a side-by-side alpha MP4 (left colour, right alpha) composited on a canvas; a plain one as a video. */
export function VideoPreview({ url, alpha }: { url: string; alpha: Alpha }) {
  const video = useRef<HTMLVideoElement>(null);
  const canvas = useRef<HTMLCanvasElement>(null);
  const [tainted, setTainted] = useState(false);
  useEffect(() => {
    if (alpha !== 'SIDE_BY_SIDE') return;
    const v = video.current;
    const c = canvas.current;
    if (!v || !c) return;
    const work = document.createElement('canvas');
    let raf = 0;
    const draw = () => {
      raf = requestAnimationFrame(draw);
      if (v.readyState < 2 || !v.videoWidth) return;
      const half = Math.floor(v.videoWidth / 2);
      const scale = Math.min(1, 320 / half);
      const w = Math.max(1, Math.round(half * scale));
      const h = Math.max(1, Math.round(v.videoHeight * scale));
      if (c.width !== w || c.height !== h) {
        c.width = w;
        c.height = h;
        work.width = w * 2;
        work.height = h;
      }
      const wctx = work.getContext('2d', { willReadFrequently: true });
      const ctx = c.getContext('2d');
      if (!wctx || !ctx) return;
      wctx.drawImage(v, 0, 0, w * 2, h);
      try {
        const colour = wctx.getImageData(0, 0, w, h);
        const mask = wctx.getImageData(w, 0, w, h);
        for (let i = 0; i < colour.data.length; i += 4) colour.data[i + 3] = mask.data[i]!;
        ctx.putImageData(colour, 0, 0);
      } catch {
        // Pixels that cannot be read (a cross-origin source): show the raw video instead.
        setTainted(true);
        cancelAnimationFrame(raf);
      }
    };
    raf = requestAnimationFrame(draw);
    return () => cancelAnimationFrame(raf);
  }, [url, alpha]);
  const composite = alpha === 'SIDE_BY_SIDE' && !tainted;
  return (
    <div className="media-preview checker">
      <video
        ref={video}
        src={url}
        autoPlay
        loop
        muted
        playsInline
        controls={!composite}
        style={composite ? { position: 'absolute', width: 1, height: 1, opacity: 0, pointerEvents: 'none' } : undefined}
      />
      {composite && <canvas ref={canvas} aria-label="MP4" />}
    </div>
  );
}

/** Plays the SVGA's bitmap sprites (svga.ts); vector shapes are not drawn. */
export function SvgaPreview({ file, url }: { file?: File | undefined; url: string | null }) {
  const { t, lang } = useApp();
  const canvas = useRef<HTMLCanvasElement>(null);
  const [movie, setMovie] = useState<SvgaMovie | null>(null);
  const [failed, setFailed] = useState(false);
  useEffect(() => {
    let stop: (() => void) | null = null;
    let cancelled = false;
    setFailed(false);
    setMovie(null);
    (async () => {
      const blob = file ?? (url ? await fetch(url).then((r) => (r.ok ? r.blob() : Promise.reject(new Error(String(r.status))))) : null);
      if (!blob) return;
      const m = await readSvga(blob);
      if (cancelled) return;
      setMovie(m);
      if (canvas.current) stop = await playSvga(m, canvas.current);
      if (cancelled) stop?.();
    })().catch(() => !cancelled && setFailed(true));
    return () => {
      cancelled = true;
      stop?.();
    };
  }, [file, url]);
  return (
    <div className="media-preview-wrap">
      <div className="media-preview checker">
        <canvas ref={canvas} width={240} height={240} aria-label="SVGA" />
      </div>
      {movie && (
        <span className="hint ltr">
          {t('giftSvgaInfo', {
            version: movie.version || '2',
            w: formatNumber(Math.round(movie.width), lang),
            h: formatNumber(Math.round(movie.height), lang),
            frames: formatNumber(movie.frames, lang),
            fps: formatNumber(movie.fps, lang),
          })}
        </span>
      )}
      {movie && movie.vectorSprites > 0 && <span className="hint">{t('giftSvgaVector')}</span>}
      {failed && <span className="hint">{t('giftSvgaNoPreview')}</span>}
    </div>
  );
}

/**
 * One file slot. `code` is the folder (a gift's or a category's code); without it, choosing a file asks for it first.
 * `alpha` / `onAlpha` (animation) drive the MP4 preview and the «الشفافية» choice.
 */
export function FileSlot({
  kind,
  code,
  label,
  hint,
  value,
  onChange,
  removable = true,
  alpha,
  onAlpha,
}: {
  kind: GiftUpload['kind'];
  code: string;
  label: string;
  hint: string;
  value: FileValue;
  onChange: (v: FileValue) => void;
  removable?: boolean;
  alpha?: Alpha;
  onAlpha?: (a: Alpha) => void;
}) {
  const { t, lang } = useApp();
  const input = useRef<HTMLInputElement>(null);
  const [progress, setProgress] = useState<number | null>(null);
  const [error, setError] = useState<unknown>(null);
  const [needCode, setNeedCode] = useState(false);
  const id = `slot-${kind}`;
  const pick = (file: File | undefined) => {
    if (!file) return;
    if (!code) {
      setNeedCode(true);
      return;
    }
    setNeedCode(false);
    setError(null);
    setProgress(0);
    uploadGiftFile(kind, code, file, setProgress).then(
      (info) => {
        setProgress(null);
        if (info.format === 'MP4' && info.detectedAlpha && onAlpha) onAlpha(info.detectedAlpha);
        onChange({ key: info.key, url: previewUrl(info.key), format: info.format, info, file, durationMs: info.durationMs ?? null });
      },
      (err: unknown) => {
        setProgress(null);
        setError(err);
      },
    );
  };
  const format = value.format ?? value.info?.format;
  return (
    <div className="field span-2 file-slot" data-kind={kind}>
      <label htmlFor={id}>{label}</label>
      <div className="file-slot-body">
        {value.url && (kind === 'image' || kind === 'icon') && (
          <div className={`media-preview checker${kind === 'icon' ? ' small' : ''}`}>
            <img src={value.url} alt="" />
          </div>
        )}
        {value.url && kind === 'sound' && <audio controls src={value.url} />}
        {value.url && kind === 'animation' && format === 'MP4' && <VideoPreview url={value.url} alpha={alpha ?? 'NONE'} />}
        {(value.url || value.file) && kind === 'animation' && format === 'SVGA' && <SvgaPreview file={value.file} url={value.url} />}
        <div className="file-slot-side">
          <div className="row">
            <input
              ref={input}
              id={id}
              type="file"
              accept={ACCEPT[kind]}
              hidden
              onChange={(e) => {
                pick(e.target.files?.[0]);
                e.target.value = '';
              }}
            />
            <button type="button" className="btn small" disabled={progress !== null} onClick={() => input.current?.click()}>
              <Icon name="plus" size={14} />
              {value.key ? t('giftReplaceFile') : t('giftChooseFile')}
            </button>
            {removable && value.key && (
              <button type="button" className="btn small danger" disabled={progress !== null} onClick={() => onChange(NO_FILE)}>
                {t('giftRemoveFile')}
              </button>
            )}
          </div>
          {progress !== null && (
            <div className="progress" role="progressbar" aria-valuenow={Math.round(progress * 100)} aria-valuemin={0} aria-valuemax={100}>
              <span style={{ width: `${String(Math.round(progress * 100))}%` }} />
              <em>{t('giftUploading', { p: formatNumber(Math.round(progress * 100), lang) })}</em>
            </div>
          )}
          {value.info && progress === null && (
            <span className="hint ltr">
              {value.info.format === 'MP4'
                ? t('giftMp4Info', { w: String(value.info.width), h: String(value.info.height), s: seconds(value.info.durationMs) })
                : kind === 'sound'
                  ? t('giftMp3Info', { s: seconds(value.info.durationMs) })
                  : `${value.info.contentType} · ${formatNumber(Math.round(value.info.bytes / 1024), lang)} KB`}
            </span>
          )}
          {!value.info && value.key && kind === 'sound' && value.durationMs ? (
            <span className="hint ltr">{t('giftMp3Info', { s: seconds(value.durationMs) })}</span>
          ) : null}
          {kind === 'animation' && format === 'MP4' && onAlpha && (
            <div className="field">
              <label htmlFor="slot-alpha">{t('giftAlpha')}</label>
              <select id="slot-alpha" value={alpha ?? 'NONE'} onChange={(e) => onAlpha(e.target.value as Alpha)}>
                <option value="NONE">{t('giftAlphaNONE')}</option>
                <option value="SIDE_BY_SIDE">{t('giftAlphaSIDE_BY_SIDE')}</option>
              </select>
              {value.info?.detectedAlpha && (
                <span className="hint">
                  {t('giftAlphaDetected', {
                    kind: t(`giftAlpha${value.info.detectedAlpha}`),
                    w: String(value.info.width),
                    h: String(value.info.height),
                  })}
                </span>
              )}
            </div>
          )}
          <span className="hint">{hint}</span>
          {needCode && <span className="hint warn-text">{t('giftNeedCode')}</span>}
        </div>
      </div>
      <ErrorAlert error={error} />
    </div>
  );
}
