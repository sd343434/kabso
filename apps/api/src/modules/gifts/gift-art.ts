import { createHash } from 'node:crypto';
import { inflateSync } from 'node:zlib';
import sharp from 'sharp';
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
  /^media\/gifts\/[a-z0-9][a-z0-9_]{0,39}\/[0-9a-f]{32}\.svga$/;

/** A file refused by the checks below; the message says why (for the operator). */
export class GiftArtError extends Error {}

/** A checked file, ready to upload. */
export interface GiftArtFile {
  readonly key: string;
  readonly contentType: string;
  readonly body: Buffer;
  readonly size: number;
}

function contentKey(code: string, body: Buffer, ext: string): string {
  const digest = createHash('sha256').update(body).digest('hex').slice(0, 32);
  return `media/gifts/${code}/${digest}.${ext}`;
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

/**
 * Checks a gift's SVGA effect: SVGA 2.x (a zlib stream of the protobuf `MovieEntity`, which the
 * app's player reads), at most 25 MiB. SVGA 1.x (a zip archive) is refused: the app cannot play
 * it. Throws {@link GiftArtError}.
 */
export function giftAnimationFile(code: string, body: Buffer): GiftArtFile {
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
  return { key: contentKey(code, body, 'svga'), contentType: SVGA_CONTENT_TYPE, body, size: body.length };
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
