import { createHash } from 'node:crypto';
import { inflateSync } from 'node:zlib';
import sharp from 'sharp';
import { inspectVideo, InvalidVideoError } from '../media/media-video.js';
import type { ObjectStorage } from '../media/object-storage.js';

/**
 * Gift art hosted in object storage (v1.26.2-live, D126, CONVENTIONS §10.23): the static image
 * (PNG or WebP) and the SVGA effect of a gift, uploaded by `gift-admin --image` /
 * `--animation-file` and downloaded by the app on demand, so a new gift needs no app release.
 * Shared by the CLI and its tests (no Nest dependencies).
 *
 * Keys are content-addressed — `media/gifts/<code>/<first 32 hex of SHA-256>.<ext>` — so a file is
 * never overwritten with other bytes: the objects are immutable and cached for a year
 * ({@link GIFT_ART_CACHE_CONTROL}); a new file gets a new key and URL. The `media/` prefix is the
 * publicly readable part of the bucket (DEPLOYMENT §5.3).
 */

/** The static image: at most 1 MiB. */
export const GIFT_IMAGE_MAX_BYTES = 1024 * 1024;
/** The SVGA effect: at most 25 MiB (CHECK `gifts_animation_bytes_set`). */
export const GIFT_ANIMATION_MAX_BYTES = 25 * 1024 * 1024;
/** The image's sides: 64 … 2048 px, and "square-ish" (the longer side at most 1.25 × the shorter). */
export const GIFT_IMAGE_MIN_SIDE = 64;
export const GIFT_IMAGE_MAX_SIDE = 2048;
export const GIFT_IMAGE_MAX_RATIO = 1.25;
/** An SVGA inflates to at most this much (a guard against a zip bomb). */
const SVGA_MAX_INFLATED_BYTES = 256 * 1024 * 1024;

/** Immutable: the key changes whenever the bytes do. */
export const GIFT_ART_CACHE_CONTROL = 'public, max-age=31536000, immutable';
/** The SVGA's Content-Type (there is no registered type; this one every CDN passes through as is). */
export const SVGA_CONTENT_TYPE = 'application/octet-stream';

/** `gifts_image_object_key_format` / `gifts_animation_object_key_format`. */
export const GIFT_IMAGE_OBJECT_KEY_PATTERN =
  /^media\/gifts\/[a-z0-9][a-z0-9_]{0,39}\/[0-9a-f]{32}\.(png|webp)$/;
export const GIFT_ANIMATION_OBJECT_KEY_PATTERN =
  /^media\/gifts\/[a-z0-9][a-z0-9_]{0,39}\/[0-9a-f]{32}\.(svga|mp4)$/;
/** v1.46-live (D207): `gifts_audio_set`'s key format. */
export const GIFT_AUDIO_OBJECT_KEY_PATTERN = /^media\/gifts\/[a-z0-9][a-z0-9_]{0,39}\/[0-9a-f]{32}\.mp3$/;

// ---- v1.46-live (D207, CONVENTIONS §10.66): uploads from the admin panel ------------------------------------------

/** The panel's «صورة الهدية»: PNG/WebP, square, at most 512 KiB, at least 128 px a side (owner brief D207). */
export const PANEL_GIFT_IMAGE_MAX_BYTES = 512 * 1024;
export const PANEL_GIFT_IMAGE_MIN_SIDE = 128;
/** "Square": the sides differ by at most 2 % (an exporter's rounding). */
export const PANEL_GIFT_IMAGE_MAX_RATIO = 1.02;
/** An MP4 full-screen effect: H.264, at most 8 MiB and 15 s. */
export const GIFT_VIDEO_MAX_BYTES = 8 * 1024 * 1024;
export const GIFT_VIDEO_MAX_DURATION_MS = 15_000;
export const GIFT_VIDEO_CODECS = ['avc1', 'avc3'] as const;
/** Width ≥ this × height: suggested as side-by-side alpha (left colour, right alpha; e.g. 1440 × 1280 → no). */
export const GIFT_VIDEO_SIDE_BY_SIDE_RATIO = 1.8;
/** An MP3 sound: at most 1 MiB and 15 s (and at least 100 ms). */
export const GIFT_AUDIO_MAX_BYTES = 1024 * 1024;
export const GIFT_AUDIO_MAX_DURATION_MS = 15_000;
export const GIFT_AUDIO_MIN_DURATION_MS = 100;
/** Encoder padding accepted past 15 s and reported clipped (as voice clips and videos). */
export const GIFT_MEDIA_DURATION_TOLERANCE_MS = 500;
/** A category tab icon: PNG/WebP, square, 32 … 512 px, at most 256 KiB. */
export const GIFT_CATEGORY_ICON_MAX_BYTES = 256 * 1024;
export const GIFT_CATEGORY_ICON_MIN_SIDE = 32;
export const GIFT_CATEGORY_ICON_MAX_SIDE = 512;

/** A file refused by the checks below; the message says why (for the operator). */
export class GiftArtError extends Error {}

/** A checked file, ready to upload. */
export interface GiftArtFile {
  readonly key: string;
  readonly contentType: string;
  readonly body: Buffer;
  readonly size: number;
}

function contentKey(code: string, body: Buffer, ext: string, folder = 'gifts'): string {
  const digest = createHash('sha256').update(body).digest('hex').slice(0, 32);
  return `media/${folder}/${code}/${digest}.${ext}`;
}

function imageKind(body: Buffer): { ext: 'png' | 'webp'; contentType: string } | null {
  if (
    body.length >= 8 &&
    body.subarray(0, 8).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]))
  ) {
    return { ext: 'png', contentType: 'image/png' };
  }
  if (
    body.length >= 12 &&
    body.subarray(0, 4).toString('latin1') === 'RIFF' &&
    body.subarray(8, 12).toString('latin1') === 'WEBP'
  ) {
    return { ext: 'webp', contentType: 'image/webp' };
  }
  return null;
}

/**
 * Checks a gift's static image: PNG or WebP by its bytes (not its name), at most 1 MiB, 64 … 2048
 * px a side and square-ish. Throws {@link GiftArtError}.
 */
export async function giftImageFile(code: string, body: Buffer): Promise<GiftArtFile> {
  if (body.length === 0) throw new GiftArtError('The image file is empty.');
  if (body.length > GIFT_IMAGE_MAX_BYTES) {
    throw new GiftArtError(
      `The image is ${String(body.length)} bytes; at most ${String(GIFT_IMAGE_MAX_BYTES)} (1 MB).`,
    );
  }
  const kind = imageKind(body);
  if (!kind) throw new GiftArtError('The image must be a PNG or WebP file.');
  let width: number | undefined;
  let height: number | undefined;
  try {
    ({ width, height } = await sharp(body).metadata());
  } catch {
    throw new GiftArtError('The image cannot be read (a broken PNG or WebP file).');
  }
  if (!width || !height) throw new GiftArtError('The image has no size.');
  const short = Math.min(width, height);
  const long = Math.max(width, height);
  if (short < GIFT_IMAGE_MIN_SIDE || long > GIFT_IMAGE_MAX_SIDE) {
    throw new GiftArtError(
      `The image is ${String(width)} × ${String(height)} px; each side must be ${String(GIFT_IMAGE_MIN_SIDE)}–${String(GIFT_IMAGE_MAX_SIDE)} px.`,
    );
  }
  if (long > short * GIFT_IMAGE_MAX_RATIO) {
    throw new GiftArtError(
      `The image is ${String(width)} × ${String(height)} px; it must be about square (at most 5:4).`,
    );
  }
  return { key: contentKey(code, body, kind.ext), contentType: kind.contentType, body, size: body.length };
}

/** v1.79-live (D289): what an SVGA movie says of itself — its frame (`params.viewBox`) and its sounds (`audios`). */
export interface SvgaMovieInfo {
  /** The frame in points, or null when `params` gives none. */
  readonly width: number | null;
  readonly height: number | null;
  /** At least one `audios` entry (field 5 of `MovieEntity`). */
  readonly hasAudio: boolean;
}

/** A checked SVGA effect and what it says of itself. */
export interface GiftAnimationFile extends GiftArtFile, SvgaMovieInfo {}

/** A protobuf varint at `at`: its value (safe for lengths) and the next offset, or null past the end. */
function varint(bytes: Buffer, at: number): { value: number; next: number } | null {
  let value = 0;
  let scale = 1;
  for (let i = at; i < bytes.length && i < at + 10; i += 1) {
    const b = bytes[i]!;
    value += (b & 0x7f) * scale;
    scale *= 128;
    if ((b & 0x80) === 0) return { value, next: i + 1 };
  }
  return null;
}

/** The top-level fields of a protobuf message: number, wire type and (length-delimited) payload. */
function* protoFields(
  bytes: Buffer,
): Generator<{ field: number; wire: number; start: number; end: number }, void, undefined> {
  let at = 0;
  while (at < bytes.length) {
    const key = varint(bytes, at);
    if (!key) return;
    const field = Math.floor(key.value / 8);
    const wire = key.value % 8;
    at = key.next;
    if (wire === 0) {
      const v = varint(bytes, at);
      if (!v) return;
      yield { field, wire, start: at, end: v.next };
      at = v.next;
    } else if (wire === 1) {
      yield { field, wire, start: at, end: at + 8 };
      at += 8;
    } else if (wire === 2) {
      const len = varint(bytes, at);
      if (!len || len.next + len.value > bytes.length) return;
      yield { field, wire, start: len.next, end: len.next + len.value };
      at = len.next + len.value;
    } else if (wire === 5) {
      yield { field, wire, start: at, end: at + 4 };
      at += 4;
    } else {
      return;
    }
  }
}

/**
 * v1.79-live (D289): reads an inflated SVGA 2.x `MovieEntity` (version 1, params 2 {viewBoxWidth 1, viewBoxHeight 2:
 * floats}, images 3, sprites 4, audios 5) without decoding the art. A movie it cannot walk reads as unknown / silent.
 */
export function svgaMovieInfo(movie: Buffer): SvgaMovieInfo {
  let width: number | null = null;
  let height: number | null = null;
  let hasAudio = false;
  for (const f of protoFields(movie)) {
    if (f.field === 5 && f.wire === 2) hasAudio = true;
    if (f.field === 2 && f.wire === 2) {
      for (const p of protoFields(movie.subarray(f.start, f.end))) {
        if (p.wire !== 5) continue;
        const value = movie.readFloatLE(f.start + p.start);
        if (!Number.isFinite(value) || value <= 0) continue;
        if (p.field === 1) width = Math.round(value);
        if (p.field === 2) height = Math.round(value);
      }
    }
  }
  return { width, height, hasAudio };
}

/**
 * Checks a gift's SVGA effect: SVGA 2.x (a zlib stream of the protobuf `MovieEntity`, which the
 * app's player reads), at most 25 MiB. SVGA 1.x (a zip archive) is refused: the app cannot play
 * it. Throws {@link GiftArtError}. v1.79-live (D289): also answers the frame and whether it has sounds.
 */
export function giftAnimationFile(code: string, body: Buffer): GiftAnimationFile {
  if (body.length === 0) throw new GiftArtError('The animation file is empty.');
  if (body.length > GIFT_ANIMATION_MAX_BYTES) {
    throw new GiftArtError(
      `The animation is ${String(body.length)} bytes; at most ${String(GIFT_ANIMATION_MAX_BYTES)} (25 MB).`,
    );
  }
  if (body.length >= 4 && body.readUInt32BE(0) === 0x504b0304) {
    throw new GiftArtError(
      'This is an SVGA 1.x file (a zip archive); the app plays SVGA 2.x only. Export it as SVGA 2.x.',
    );
  }
  const cmf = body[0] ?? 0;
  const flg = body[1] ?? 0;
  if ((cmf & 0x0f) !== 8 || (cmf * 256 + flg) % 31 !== 0) {
    throw new GiftArtError('The animation must be an SVGA 2.x file (it does not start with a zlib header).');
  }
  let inflated: Buffer;
  try {
    inflated = inflateSync(body, { maxOutputLength: SVGA_MAX_INFLATED_BYTES });
  } catch {
    throw new GiftArtError('The animation cannot be read (a broken or too large SVGA file).');
  }
  // MovieEntity starts with field 1 (`version`, a string) or 2 (`params`, a message).
  if (inflated[0] !== 0x0a && inflated[0] !== 0x12) {
    throw new GiftArtError('The animation is not an SVGA movie.');
  }
  return {
    key: contentKey(code, body, 'svga'),
    contentType: SVGA_CONTENT_TYPE,
    body,
    size: body.length,
    ...svgaMovieInfo(inflated),
  };
}

/** A checked image's size (shared by the panel's image and the category icon). */
async function squareImage(
  body: Buffer,
  limits: { maxBytes: number; minSide: number; maxSide: number; what: string },
): Promise<{ ext: 'png' | 'webp'; contentType: string; width: number; height: number }> {
  if (body.length === 0) throw new GiftArtError(`The ${limits.what} file is empty.`);
  if (body.length > limits.maxBytes) {
    throw new GiftArtError(
      `The ${limits.what} is ${String(body.length)} bytes; at most ${String(limits.maxBytes / 1024)} KB.`,
    );
  }
  const kind = imageKind(body);
  if (!kind) throw new GiftArtError(`The ${limits.what} must be a PNG or WebP file.`);
  let width: number | undefined;
  let height: number | undefined;
  try {
    ({ width, height } = await sharp(body).metadata());
  } catch {
    throw new GiftArtError(`The ${limits.what} cannot be read (a broken PNG or WebP file).`);
  }
  if (!width || !height) throw new GiftArtError(`The ${limits.what} has no size.`);
  const short = Math.min(width, height);
  const long = Math.max(width, height);
  if (short < limits.minSide || long > limits.maxSide) {
    throw new GiftArtError(
      `The ${limits.what} is ${String(width)} × ${String(height)} px; each side must be ${String(limits.minSide)}–${String(limits.maxSide)} px.`,
    );
  }
  if (long > short * PANEL_GIFT_IMAGE_MAX_RATIO) {
    throw new GiftArtError(
      `The ${limits.what} is ${String(width)} × ${String(height)} px; it must be square.`,
    );
  }
  return { ...kind, width, height };
}

/** v1.46-live (D207): the panel's «صورة الهدية» — PNG/WebP, square, ≥ 128 px, ≤ 512 KiB. */
export async function panelGiftImageFile(
  code: string,
  body: Buffer,
): Promise<GiftArtFile & { width: number; height: number }> {
  const img = await squareImage(body, {
    maxBytes: PANEL_GIFT_IMAGE_MAX_BYTES,
    minSide: PANEL_GIFT_IMAGE_MIN_SIDE,
    maxSide: GIFT_IMAGE_MAX_SIDE,
    what: 'image',
  });
  return {
    key: contentKey(code, body, img.ext),
    contentType: img.contentType,
    body,
    size: body.length,
    width: img.width,
    height: img.height,
  };
}

/** v1.46-live (D207): a category tab's icon — PNG/WebP, square, 32 … 512 px, ≤ 256 KiB, under `media/gift-categories/`. */
export async function giftCategoryIconFile(
  categoryCode: string,
  body: Buffer,
): Promise<GiftArtFile & { width: number; height: number }> {
  const img = await squareImage(body, {
    maxBytes: GIFT_CATEGORY_ICON_MAX_BYTES,
    minSide: GIFT_CATEGORY_ICON_MIN_SIDE,
    maxSide: GIFT_CATEGORY_ICON_MAX_SIDE,
    what: 'icon',
  });
  return {
    key: contentKey(categoryCode, body, img.ext, 'gift-categories'),
    contentType: img.contentType,
    body,
    size: body.length,
    width: img.width,
    height: img.height,
  };
}

/** The transparency of an MP4 effect: a plain video, or the left half colour / right half alpha. */
export type GiftVideoAlphaKind = 'NONE' | 'SIDE_BY_SIDE';

/** What a checked MP4 is (the panel shows it and suggests the transparency). */
export interface GiftVideoFile extends GiftArtFile {
  readonly width: number;
  readonly height: number;
  readonly durationMs: number;
  readonly codec: string;
  /** SIDE_BY_SIDE when width ≥ 1.8 × height (the admin may override it), else NONE. */
  readonly detectedAlpha: GiftVideoAlphaKind;
  /** v1.79-live (D289): an audio track is in the file (the panel pre-selects «بمؤثرات صوتية»). */
  readonly hasAudio: boolean;
}

/**
 * v1.46-live (D207): checks an MP4 full-screen effect — an MPEG-4 file (not QuickTime) with an H.264 video track,
 * 1 … 15 s, 16 … 4096 px a side, at most 8 MiB — by reading its boxes (`ftyp`, `moov/mvhd`, the video track's
 * `tkhd` and `stsd`; the media module's parser, D162). The API image has no ffprobe, and the file is not decoded.
 * Throws {@link GiftArtError}.
 */
export async function giftVideoFile(code: string, body: Buffer): Promise<GiftVideoFile> {
  if (body.length === 0) throw new GiftArtError('The video file is empty.');
  if (body.length > GIFT_VIDEO_MAX_BYTES) {
    throw new GiftArtError(`The video is ${String(body.length)} bytes; at most 8 MB.`);
  }
  let info: { width: number; height: number; durationMs: number; codec: string; hasAudio: boolean };
  try {
    info = await inspectVideo(
      (offset, length) => Promise.resolve(body.subarray(offset, offset + length)),
      body.length,
      'video/mp4',
      'REEL_VIDEO',
    );
  } catch (err) {
    if (err instanceof InvalidVideoError) {
      const why = err.message;
      if (why.startsWith('video codec')) {
        throw new GiftArtError(`The video must be H.264 (it is ${why.slice('video codec '.length)}).`);
      }
      if (why.includes('too long')) throw new GiftArtError('The video must be at most 15 seconds.');
      if (why.includes('shorter')) throw new GiftArtError('The video must be at least 1 second.');
      throw new GiftArtError(`The file is not a playable MP4 video (${why}).`);
    }
    throw err;
  }
  if (!(GIFT_VIDEO_CODECS as readonly string[]).includes(info.codec)) {
    throw new GiftArtError(`The video must be H.264 (it is ${info.codec}).`);
  }
  if (info.durationMs > GIFT_VIDEO_MAX_DURATION_MS + GIFT_MEDIA_DURATION_TOLERANCE_MS) {
    throw new GiftArtError(
      `The video is ${(info.durationMs / 1000).toFixed(1)} s; at most ${String(GIFT_VIDEO_MAX_DURATION_MS / 1000)} s.`,
    );
  }
  return {
    key: contentKey(code, body, 'mp4'),
    contentType: 'video/mp4',
    body,
    size: body.length,
    width: info.width,
    height: info.height,
    durationMs: Math.min(info.durationMs, GIFT_VIDEO_MAX_DURATION_MS),
    codec: info.codec,
    detectedAlpha: info.width >= info.height * GIFT_VIDEO_SIDE_BY_SIDE_RATIO ? 'SIDE_BY_SIDE' : 'NONE',
    hasAudio: info.hasAudio,
  };
}

// MPEG audio Layer III: bit rates (kbit/s) by index for MPEG-1 and for MPEG-2 / 2.5, and sample rates (Hz).
const MP3_BITRATES_V1 = [0, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320, 0];
const MP3_BITRATES_V2 = [0, 8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160, 0];
const MP3_SAMPLE_RATES: Record<number, readonly number[]> = {
  3: [44_100, 48_000, 32_000],
  2: [22_050, 24_000, 16_000],
  0: [11_025, 12_000, 8_000],
};
/** Bytes after the last frame that are tolerated (an ID3v1 tag is 128, APE tags or padding a little more). */
const MP3_MAX_TRAILING_BYTES = 8 * 1024;

/** One Layer III frame header at `at`: its length in bytes and its samples, or null. */
function mp3Frame(body: Buffer, at: number): { bytes: number; samples: number; rate: number } | null {
  if (at + 4 > body.length) return null;
  const b1 = body[at + 1]!;
  const b2 = body[at + 2]!;
  if (body[at] !== 0xff || (b1 & 0xe0) !== 0xe0) return null;
  const version = (b1 >> 3) & 0x03; // 3: MPEG-1, 2: MPEG-2, 0: MPEG-2.5, 1: reserved
  const layer = (b1 >> 1) & 0x03; // 1: Layer III
  if (version === 1 || layer !== 1) return null;
  const bitrate = (version === 3 ? MP3_BITRATES_V1 : MP3_BITRATES_V2)[(b2 >> 4) & 0x0f]!;
  const rate = MP3_SAMPLE_RATES[version]?.[(b2 >> 2) & 0x03];
  if (!bitrate || !rate) return null;
  const padding = (b2 >> 1) & 0x01;
  const samples = version === 3 ? 1152 : 576;
  const bytes = Math.floor(((samples / 8) * bitrate * 1000) / rate) + padding;
  return { bytes, samples, rate };
}

/** What a checked MP3 is. */
export interface GiftAudioFile extends GiftArtFile {
  readonly durationMs: number;
}

/**
 * v1.46-live (D207): checks a gift's MP3 sound — an optional ID3v2 tag, then MPEG audio Layer III frames to the end
 * (an ID3v1 / APE tag or a little padding allowed), 100 ms … 15 s by the frames' samples, at most 1 MiB. Throws
 * {@link GiftArtError}.
 */
export function giftAudioFile(code: string, body: Buffer): GiftAudioFile {
  if (body.length === 0) throw new GiftArtError('The sound file is empty.');
  if (body.length > GIFT_AUDIO_MAX_BYTES) {
    throw new GiftArtError(`The sound is ${String(body.length)} bytes; at most 1 MB.`);
  }
  let at = 0;
  if (body.length >= 10 && body.toString('latin1', 0, 3) === 'ID3') {
    const size =
      ((body[6]! & 0x7f) << 21) | ((body[7]! & 0x7f) << 14) | ((body[8]! & 0x7f) << 7) | (body[9]! & 0x7f);
    at = 10 + size + ((body[5]! & 0x10) !== 0 ? 10 : 0);
  }
  // Some encoders pad the tag with zeros.
  while (at < body.length && at < 64 * 1024 && body[at] === 0) at += 1;
  let frames = 0;
  let seconds = 0;
  for (;;) {
    const frame = mp3Frame(body, at);
    if (!frame || at + frame.bytes > body.length) break;
    frames += 1;
    seconds += frame.samples / frame.rate;
    at += frame.bytes;
  }
  if (frames < 2) throw new GiftArtError('The sound must be an MP3 file (MPEG audio Layer III).');
  if (body.length - at > MP3_MAX_TRAILING_BYTES) {
    throw new GiftArtError('The sound is not a clean MP3 file (data after the audio).');
  }
  const durationMs = Math.round(seconds * 1000);
  if (durationMs < GIFT_AUDIO_MIN_DURATION_MS) throw new GiftArtError('The sound is too short.');
  if (durationMs > GIFT_AUDIO_MAX_DURATION_MS + GIFT_MEDIA_DURATION_TOLERANCE_MS) {
    throw new GiftArtError(
      `The sound is ${(durationMs / 1000).toFixed(1)} s; at most ${String(GIFT_AUDIO_MAX_DURATION_MS / 1000)} s.`,
    );
  }
  return {
    key: contentKey(code, body, 'mp3'),
    contentType: 'audio/mpeg',
    body,
    size: body.length,
    durationMs: Math.min(durationMs, GIFT_AUDIO_MAX_DURATION_MS),
  };
}

/** Uploads a checked file (immutable, cached for a year). Uploading the same bytes again is harmless. */
export async function uploadGiftArt(storage: ObjectStorage, file: GiftArtFile): Promise<void> {
  await storage.put(file.key, file.body, file.contentType, GIFT_ART_CACHE_CONTROL);
}

/** The public URL of an object key, or null without a key or without `MEDIA_PUBLIC_BASE_URL`. */
export function giftArtUrl(publicBaseUrl: string | undefined, key: string | null): string | null {
  if (key === null || !publicBaseUrl) return null;
  return `${publicBaseUrl.replace(/\/+$/, '')}/${key}`;
}
