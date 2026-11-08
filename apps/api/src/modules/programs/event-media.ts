/**
 * v1.97-social (D303 follow-ups, owner: «كل فعالية تبنى نقوم برفع صفحة الاعلان الخارجي للبنر وضع قياساته لكي نتقيد بها،
 * وايضاً الصفحة الداخلية للفعالية نرفعها من اللوحة، وضع القياسات والصيغة»; CONVENTIONS §10.114.9): the published
 * specs of an event's art — ONE source of truth: the upload checks below, `EventOptions.specs` (the panel and the app
 * show them beside each upload field) and the contract's table are this object.
 *
 * The banner's shape is what the app really renders: the Live home carousel is 5:1 (`KHomeBannerCarousel.homeAspect`,
 * D248b; the server crops HOME banners to 1 500 × 300), so the spec is 1 500 × 300, not D124's 3:1.
 */
import { randomUUID } from 'node:crypto';
import sharp, { type Metadata } from 'sharp';
import type { ObjectStorage } from '../media/object-storage.js';
import {
  inspectVideo,
  InvalidVideoError,
  VIDEO_CODECS,
  type VideoContentType,
} from '../media/media-video.js';
import { protoFields, varint } from '../gifts/gift-art.js';
import { inflateSync } from 'node:zlib';

const MB = 1024 * 1024;

export const EVENT_MEDIA_KINDS = [
  'banner',
  'banner_video',
  'background',
  'background_video',
  'title',
  'overlay',
  'badge',
] as const;
export type EventMediaKind = (typeof EVENT_MEDIA_KINDS)[number];

export interface EventMediaSpec {
  readonly kind: EventMediaKind;
  /** The exact pixel size (images are resized to it; uploads must have its aspect within ±1 % and be at least it). */
  readonly width: number | null;
  readonly height: number | null;
  /** Accepted formats. */
  readonly formats: readonly string[];
  /** Largest file for a still / an animation / a video or overlay (bytes; null = not accepted). */
  readonly maxStillBytes: number | null;
  readonly maxAnimatedBytes: number | null;
  readonly maxDurationMs: number | null;
  /** Needs transparency (an alpha channel). */
  readonly transparent: boolean;
  /** Safe zones (px of the spec size): where text / the title must stay. */
  readonly safeZone: string | null;
}

/** The specs (owner to confirm; CONVENTIONS §10.114.9). */
export const EVENT_MEDIA_SPECS: Readonly<Record<EventMediaKind, EventMediaSpec>> = {
  banner: {
    kind: 'banner',
    width: 1500,
    height: 300,
    formats: ['PNG', 'JPEG', 'WEBP', 'GIF (animated)', 'WEBP (animated)'],
    maxStillBytes: 2 * MB,
    maxAnimatedBytes: 5 * MB,
    maxDurationMs: 10_000,
    transparent: false,
    safeZone:
      'Text inside the centred 900 × 240 px (60 % × 80 %): the corners may be covered by the page dots.',
  },
  banner_video: {
    kind: 'banner_video',
    width: 1500,
    height: 300,
    formats: ['MP4 / MOV (H.264 or HEVC), muted'],
    maxStillBytes: null,
    maxAnimatedBytes: 30 * MB,
    maxDurationMs: 30_000,
    transparent: false,
    safeZone: 'As the banner; its poster is a banner still (required).',
  },
  background: {
    kind: 'background',
    width: 1080,
    height: 1920,
    formats: ['PNG', 'JPEG', 'WEBP', 'GIF (animated)', 'WEBP (animated)'],
    maxStillBytes: 3 * MB,
    maxAnimatedBytes: 8 * MB,
    maxDurationMs: 10_000,
    transparent: false,
    safeZone:
      'Top 0–480 px: the title art; 520–1920 px: the cards cover it (keep it quiet there). A video needs a still poster.',
  },
  background_video: {
    kind: 'background_video',
    width: 1080,
    height: 1920,
    formats: ['MP4 / MOV (H.264 or HEVC), muted, looping'],
    maxStillBytes: null,
    maxAnimatedBytes: 20 * MB,
    maxDurationMs: 15_000,
    transparent: false,
    safeZone: 'As the background; its poster is a background still (required).',
  },
  title: {
    kind: 'title',
    width: 1080,
    height: 480,
    formats: ['PNG', 'WEBP'],
    maxStillBytes: 1 * MB,
    maxAnimatedBytes: null,
    maxDurationMs: null,
    transparent: true,
    safeZone: 'Shown over the background’s top 480 px.',
  },
  overlay: {
    kind: 'overlay',
    width: null,
    height: null,
    formats: ['SVGA 2.x', 'Lottie JSON'],
    maxStillBytes: null,
    maxAnimatedBytes: 2 * MB,
    maxDurationMs: 10_000,
    transparent: true,
    safeZone:
      'Plays looping over the whole page (falling coins, sparkles); pauses off screen and with reduced motion.',
  },
  badge: {
    kind: 'badge',
    width: 512,
    height: 512,
    formats: ['PNG', 'WEBP'],
    maxStillBytes: 1 * MB,
    maxAnimatedBytes: null,
    maxDurationMs: null,
    transparent: true,
    safeZone: 'The medal centred, about 40 px of transparent margin.',
  },
};

/** A refused upload: a machine-readable issue and a message (the panel and the app show it). */
export class EventMediaError extends Error {
  constructor(
    readonly issue:
      | 'event_media_format'
      | 'event_media_size'
      | 'event_media_bytes'
      | 'event_media_duration'
      | 'event_media_transparency'
      | 'event_media_codec',
    message: string,
  ) {
    super(message);
  }
}

export interface EventMediaChecked {
  readonly kind: EventMediaKind;
  readonly body: Buffer;
  readonly contentType: string;
  readonly ext: string;
  readonly width: number | null;
  readonly height: number | null;
  readonly animated: boolean;
  readonly durationMs: number | null;
}

const mb = (n: number) => `${(n / MB).toFixed(n % MB === 0 ? 0 : 1)} MB`;

/** Width/height within ±1 % of the spec's aspect and at least its size. */
function checkSize(spec: EventMediaSpec, w: number, h: number): void {
  if (spec.width === null || spec.height === null) return;
  const want = spec.width / spec.height;
  const got = w / h;
  if (Math.abs(got - want) / want > 0.01 || w < spec.width || h < spec.height) {
    throw new EventMediaError(
      'event_media_size',
      `The picture is ${String(w)} × ${String(h)} px; it must be ${String(spec.width)} × ${String(spec.height)} px (or larger with the same shape, ±1 %).`,
    );
  }
}

/** Checks an image upload (still or animated) of `kind` and re-encodes it as WebP at the spec size. */
export async function checkEventImage(kind: EventMediaKind, bytes: Buffer): Promise<EventMediaChecked> {
  const spec = EVENT_MEDIA_SPECS[kind];
  let meta: Metadata;
  try {
    meta = await sharp(bytes, { animated: true, failOn: 'error', limitInputPixels: 60_000_000 }).metadata();
  } catch {
    throw new EventMediaError('event_media_format', `Not a picture; send ${spec.formats.join(', ')}.`);
  }
  const format = meta.format ?? '';
  const pages = meta.pages ?? 1;
  const animated = pages > 1;
  const allowed = kind === 'title' || kind === 'badge' ? ['png', 'webp'] : ['png', 'jpeg', 'webp', 'gif'];
  if (!allowed.includes(format)) {
    throw new EventMediaError(
      'event_media_format',
      `A ${format || 'unknown'} file; send ${spec.formats.join(', ')}.`,
    );
  }
  if (animated && spec.maxAnimatedBytes === null) {
    throw new EventMediaError('event_media_format', 'This slot takes a still picture only.');
  }
  const max = animated ? spec.maxAnimatedBytes! : spec.maxStillBytes!;
  if (bytes.length > max) {
    throw new EventMediaError('event_media_bytes', `The file is ${mb(bytes.length)}; at most ${mb(max)}.`);
  }
  const w = meta.width ?? 0;
  const h = (animated ? meta.pageHeight : meta.height) ?? 0;
  checkSize(spec, w, h);
  let durationMs: number | null = null;
  if (animated) {
    const loop = (meta.delay ?? [])
      .slice(0, pages)
      .reduce((sum: number, d: number) => sum + (d > 0 ? d : 100), 0);
    durationMs = loop;
    if (spec.maxDurationMs !== null && loop > spec.maxDurationMs) {
      throw new EventMediaError(
        'event_media_duration',
        `The animation lasts ${(loop / 1000).toFixed(1)} s; at most ${String(spec.maxDurationMs / 1000)} s.`,
      );
    }
  }
  if (spec.transparent && !meta.hasAlpha) {
    throw new EventMediaError(
      'event_media_transparency',
      'The picture must have a transparent background (alpha).',
    );
  }
  const body = await sharp(bytes, { animated, failOn: 'error', limitInputPixels: 60_000_000 })
    .resize(spec.width, spec.height, { fit: 'cover', position: 'centre' })
    .webp(animated ? { loop: 0, quality: 75 } : { quality: 85, alphaQuality: 100 })
    .toBuffer();
  return {
    kind,
    body,
    contentType: 'image/webp',
    ext: animated ? 'anim.webp' : 'webp',
    width: spec.width,
    height: spec.height,
    animated,
    durationMs,
  };
}

/** Checks a video upload of `kind` (`banner_video`, `background_video`): container, codec, length, size and shape. */
export async function checkEventVideo(kind: 'banner_video' | 'background_video', bytes: Buffer) {
  const spec = EVENT_MEDIA_SPECS[kind];
  if (bytes.length > spec.maxAnimatedBytes!) {
    throw new EventMediaError(
      'event_media_bytes',
      `The video is ${mb(bytes.length)}; at most ${mb(spec.maxAnimatedBytes!)}.`,
    );
  }
  const brand = bytes.length >= 12 ? bytes.toString('latin1', 4, 12) : '';
  if (!brand.startsWith('ftyp')) throw new EventMediaError('event_media_format', 'Not an MP4 / MOV video.');
  const contentType: VideoContentType = brand.slice(4) === 'qt  ' ? 'video/quicktime' : 'video/mp4';
  try {
    const info = await inspectVideo(
      (offset, length) => Promise.resolve(bytes.subarray(offset, Math.min(offset + length, bytes.length))),
      bytes.length,
      contentType,
      kind === 'banner_video' ? 'BANNER_VIDEO' : 'EVENT_VIDEO',
    );
    if (!(VIDEO_CODECS as readonly string[]).includes(info.codec)) {
      throw new EventMediaError('event_media_codec', 'The video must be H.264 or HEVC.');
    }
    checkSize(spec, info.width, info.height);
    return { info, contentType, ext: contentType === 'video/quicktime' ? 'mov' : 'mp4' };
  } catch (err) {
    if (err instanceof InvalidVideoError) {
      const long = /duration|long/.test(err.message);
      throw new EventMediaError(
        long ? 'event_media_duration' : 'event_media_format',
        long
          ? `The video is longer than ${String(spec.maxDurationMs! / 1000)} s (or has no length).`
          : `The video cannot be read (${err.message}); send MP4 / MOV with H.264 or HEVC.`,
      );
    }
    throw err;
  }
}

/** The length (ms) of an SVGA 2.x movie from its params (fps, frames), or null when unknown. */
function svgaDurationMs(movie: Buffer): number | null {
  for (const f of protoFields(movie)) {
    if (f.field !== 2 || f.wire !== 2) continue;
    let fps = 0;
    let frames = 0;
    const params = movie.subarray(f.start, f.end);
    for (const p of protoFields(params)) {
      if (p.wire !== 0) continue;
      const v = varint(params, p.start)?.value ?? 0;
      if (p.field === 3) fps = v;
      if (p.field === 4) frames = v;
    }
    return fps > 0 && frames > 0 ? Math.round((frames / fps) * 1000) : null;
  }
  return null;
}

/** Checks an overlay (SVGA 2.x or Lottie JSON), ≤ 2 MB, ≤ 10 s a loop. */
export function checkEventOverlay(bytes: Buffer): EventMediaChecked {
  const spec = EVENT_MEDIA_SPECS.overlay;
  if (bytes.length === 0 || bytes.length > spec.maxAnimatedBytes!) {
    throw new EventMediaError(
      'event_media_bytes',
      `The overlay is ${mb(bytes.length)}; at most ${mb(spec.maxAnimatedBytes!)}.`,
    );
  }
  let durationMs: number | null;
  let ext: string;
  let contentType: string;
  const first = bytes.subarray(0, 64).toString('utf8').trimStart();
  if (first.startsWith('{')) {
    let json: Record<string, unknown>;
    try {
      json = JSON.parse(bytes.toString('utf8')) as Record<string, unknown>;
    } catch {
      throw new EventMediaError('event_media_format', 'Not a Lottie JSON file.');
    }
    const fr = Number(json.fr);
    const ip = Number(json.ip);
    const op = Number(json.op);
    if (!Array.isArray(json.layers) || !(fr > 0) || !(op > ip)) {
      throw new EventMediaError(
        'event_media_format',
        'Not a Lottie animation (needs fr, ip, op and layers).',
      );
    }
    durationMs = Math.round(((op - ip) / fr) * 1000);
    ext = 'json';
    contentType = 'application/json';
  } else {
    const cmf = bytes[0] ?? 0;
    const flg = bytes[1] ?? 0;
    if ((cmf & 0x0f) !== 8 || (cmf * 256 + flg) % 31 !== 0) {
      throw new EventMediaError('event_media_format', 'Send an SVGA 2.x or a Lottie JSON file.');
    }
    let movie: Buffer;
    try {
      movie = inflateSync(bytes, { maxOutputLength: 64 * MB });
    } catch {
      throw new EventMediaError('event_media_format', 'The SVGA file cannot be read.');
    }
    durationMs = svgaDurationMs(movie);
    ext = 'svga';
    contentType = 'application/octet-stream';
  }
  if (durationMs === null || durationMs > spec.maxDurationMs!) {
    throw new EventMediaError(
      'event_media_duration',
      `The overlay loop must be known and at most ${String(spec.maxDurationMs! / 1000)} s.`,
    );
  }
  return {
    kind: 'overlay',
    body: bytes,
    contentType,
    ext,
    width: null,
    height: null,
    animated: true,
    durationMs,
  };
}

const FOLDER: Readonly<Record<Exclude<EventMediaKind, 'banner' | 'banner_video'>, string>> = {
  background: 'bg',
  background_video: 'bg',
  title: 'title',
  overlay: 'overlay',
  badge: 'badge',
};

/** Stores checked event art at `media/events/<folder>/<uuid>.<ext>`; returns its key. */
export async function storeEventArt(
  storage: ObjectStorage,
  kind: Exclude<EventMediaKind, 'banner' | 'banner_video'>,
  checked: { body: Buffer; contentType: string; ext: string },
): Promise<string> {
  const key = `media/events/${FOLDER[kind]}/${randomUUID()}.${checked.ext}`;
  await storage.put(key, checked.body, checked.contentType, 'public, max-age=31536000, immutable');
  return key;
}
