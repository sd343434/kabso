import { encode } from 'blurhash';
import sharp, { type Metadata } from 'sharp';

/** Content types accepted for uploads (CONVENTIONS §11.1). */
export const IMAGE_CONTENT_TYPES = ['image/jpeg', 'image/png', 'image/webp'] as const;
export type ImageContentType = (typeof IMAGE_CONTENT_TYPES)[number];

/** Largest upload (15 MiB, openapi `CreateMediaUploadRequest.byteSize`). */
export const MAX_IMAGE_BYTES = 15 * 1024 * 1024;
export const MAX_IMAGE_SIDE = 8000;
export const MAX_IMAGE_PIXELS = 50_000_000;
export const LARGE_SIDE = 1080;
/** The large variant of a story photo (CP-008): sharp at full screen. */
export const STORY_LARGE_SIDE = 1920;
/** The large variant of a live cover (CP-015): a 640 px square, centre-cropped. */
export const COVER_SIDE = 640;
export const THUMB_SIDE = 320;
/** D124: a home banner is always 1 500 × 500 (3:1), cover-cropped around the centre. */
export const BANNER_WIDTH = 1500;
export const BANNER_HEIGHT = 500;
/** v1.27.4-live (D137): an in-room promo banner is always 600 × 800 (3:4), thumb 240 × 320. */
export const ROOM_BANNER_WIDTH = 600;
export const ROOM_BANNER_HEIGHT = 800;
export const ROOM_BANNER_THUMB_WIDTH = 240;

/**
 * How the variants are shaped: `inside` (the long side bounded, never enlarged), `square` (a live
 * cover or family emblem, CP-015: centre-cropped squares, never enlarged) or `banner` (D124: a
 * home banner, cover-cropped to exactly 3:1 around the centre — 1 500 × 500 and 320 × 107 —
 * enlarged when smaller, so every banner has the same size).
 */
export type ImageShape = 'inside' | 'square' | 'banner' | 'roomBanner';

/** Why an upload is not an acceptable image (never shown to clients; they get MEDIA_INVALID). */
export class InvalidImageError extends Error {}

/**
 * The type the bytes really are, from their signature — the declared Content-Type is never
 * trusted alone (JPEG `FF D8 FF`, PNG `89 50 4E 47 0D 0A 1A 0A`, WebP `RIFF….WEBP`).
 */
export function sniffImageType(bytes: Buffer): ImageContentType | null {
  if (bytes.length >= 3 && bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff) return 'image/jpeg';
  if (
    bytes.length >= 8 &&
    bytes.subarray(0, 8).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]))
  ) {
    return 'image/png';
  }
  if (
    bytes.length >= 12 &&
    bytes.toString('ascii', 0, 4) === 'RIFF' &&
    bytes.toString('ascii', 8, 12) === 'WEBP'
  ) {
    return 'image/webp';
  }
  return null;
}

export interface ProcessedImage {
  readonly large: Buffer;
  readonly thumb: Buffer;
  /** Size of `large` (the displayed aspect). */
  readonly width: number;
  readonly height: number;
  readonly blurhash: string;
}

const SHARP_FORMAT: Readonly<Record<ImageContentType, string>> = {
  'image/jpeg': 'jpeg',
  'image/png': 'png',
  'image/webp': 'webp',
};

/**
 * Verifies and re-encodes an upload: the signature must equal `declared` and the decoder must
 * agree; at most 8 000 px per side and 50 MP; EXIF orientation is applied, then every metadata
 * block (EXIF, GPS, XMP, IPTC) is dropped — sharp writes none unless asked — and colours are
 * converted to sRGB. Outputs WebP at `largeSide` (1 080 px; 1 920 px for stories) and 320 px on the
 * long side (never enlarged) and a 4×3 blurhash. Animated images keep their first frame only.
 * [shape] `square` (a live cover, CP-015) centre-crops both variants to squares instead, never
 * enlarged: the shorter side bounds them; `banner` (D124) cover-crops them to 3:1 (`largeSide` is
 * then ignored: 1 500 × 500 and 320 × 107).
 */
export async function processImage(
  bytes: Buffer,
  declared: ImageContentType,
  largeSide: number = LARGE_SIDE,
  shape: ImageShape = 'inside',
): Promise<ProcessedImage> {
  const sniffed = sniffImageType(bytes);
  if (sniffed !== declared) throw new InvalidImageError(`signature ${sniffed ?? 'unknown'} ≠ ${declared}`);
  let meta: Metadata;
  try {
    meta = await sharp(bytes, { limitInputPixels: MAX_IMAGE_PIXELS, failOn: 'error' }).metadata();
  } catch {
    throw new InvalidImageError('not decodable');
  }
  if (meta.format !== SHARP_FORMAT[declared]) throw new InvalidImageError(`decoded as ${meta.format}`);
  const w = meta.width;
  const h = meta.height;
  if (!w || !h || w > MAX_IMAGE_SIDE || h > MAX_IMAGE_SIDE || w * h > MAX_IMAGE_PIXELS) {
    throw new InvalidImageError('dimensions out of range');
  }
  const base = () =>
    sharp(bytes, { limitInputPixels: MAX_IMAGE_PIXELS, failOn: 'error' }).rotate().toColorspace('srgb');
  const resize = (side: number) => {
    if (shape === 'roomBanner') {
      const width = side === THUMB_SIDE ? ROOM_BANNER_THUMB_WIDTH : ROOM_BANNER_WIDTH;
      return [
        width,
        Math.round((width * ROOM_BANNER_HEIGHT) / ROOM_BANNER_WIDTH),
        { fit: 'cover', position: 'centre' },
      ] as const;
    }
    if (shape === 'banner') {
      const width = side === THUMB_SIDE ? THUMB_SIDE : BANNER_WIDTH;
      return [
        width,
        Math.round((width * BANNER_HEIGHT) / BANNER_WIDTH),
        { fit: 'cover', position: 'centre' },
      ] as const;
    }
    if (shape === 'inside') return [side, side, { fit: 'inside', withoutEnlargement: true }] as const;
    const s = Math.min(side, w, h);
    return [s, s, { fit: 'cover', position: 'centre' }] as const;
  };
  try {
    const large = await base()
      .resize(...resize(shape === 'banner' || shape === 'roomBanner' ? BANNER_WIDTH : largeSide))
      .webp({ quality: 82 })
      .toBuffer({ resolveWithObject: true });
    const thumb = await base()
      .resize(...resize(THUMB_SIDE))
      .webp({ quality: 75 })
      .toBuffer();
    const small = await base()
      .resize(32, 32, { fit: 'inside' })
      .ensureAlpha()
      .raw()
      .toBuffer({ resolveWithObject: true });
    const blurhash = encode(new Uint8ClampedArray(small.data), small.info.width, small.info.height, 4, 3);
    return {
      large: large.data,
      thumb,
      width: large.info.width,
      height: large.info.height,
      blurhash,
    };
  } catch {
    throw new InvalidImageError('re-encoding failed');
  }
}
