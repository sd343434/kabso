import sharp, { type Metadata } from 'sharp';
import { InvalidImageError, sniffImageType } from './media-image.js';

/**
 * v1.136-social (D384, CONVENTIONS §10.173.2): the VIP animated picture «صورة متحركة». The app records up to 3 s, removes
 * the background on the phone and uploads the frames as one PNG strip — square frames one under another, transparent
 * where the background was. The server checks it and re-encodes it into a looping animated WebP with alpha and a still
 * of the first frame. No other format is taken (the phone has no WebP encoder; a strip needs no video decoder here).
 */

/** The largest strip upload (8 MiB). */
export const MAX_ANIMATED_AVATAR_BYTES = 8 * 1024 * 1024;
/** The frame side bounds (square frames). */
export const ANIMATED_AVATAR_MIN_SIDE = 64;
export const ANIMATED_AVATAR_MAX_SIDE = 512;
/** 2–36 frames: 3 s at 12 frames a second at most. */
export const ANIMATED_AVATAR_MIN_FRAMES = 2;
export const ANIMATED_AVATAR_MAX_FRAMES = 36;
/** 12 frames a second. */
export const ANIMATED_AVATAR_FRAME_MS = 83;
/** The largest animated WebP kept (1.5 MiB): above it the frames are encoded again at a lower quality, then refused. */
export const MAX_ANIMATED_AVATAR_WEBP_BYTES = 1.5 * 1024 * 1024;
/** The qualities tried in order (colour, alpha). */
const QUALITIES: readonly (readonly [number, number])[] = [
  [78, 85],
  [55, 70],
];

export interface ProcessedAnimatedAvatar {
  /** The looping animated WebP with alpha. */
  readonly clip: Buffer;
  /** The first frame, a still WebP of the same size. */
  readonly still: Buffer;
  /** The frame side (width = height). */
  readonly side: number;
  readonly frames: number;
}

/**
 * Verifies a strip and re-encodes it (metadata dropped: raw pixels in, WebP out). Throws {@link InvalidImageError} when it
 * is not a PNG, not decodable, without alpha, not 64–512 px wide, its height not 2–36 times its width exactly, or the
 * WebP stays over 1.5 MiB.
 */
export async function processAnimatedAvatar(bytes: Buffer): Promise<ProcessedAnimatedAvatar> {
  if (sniffImageType(bytes) !== 'image/png') throw new InvalidImageError('not a PNG strip');
  let meta: Metadata;
  try {
    meta = await sharp(bytes, { failOn: 'error' }).metadata();
  } catch {
    throw new InvalidImageError('not decodable');
  }
  if (meta.format !== 'png') throw new InvalidImageError(`decoded as ${meta.format}`);
  const side = meta.width ?? 0;
  const height = meta.height ?? 0;
  if (side < ANIMATED_AVATAR_MIN_SIDE || side > ANIMATED_AVATAR_MAX_SIDE) {
    throw new InvalidImageError('frame side out of range');
  }
  if (height % side !== 0) throw new InvalidImageError('not whole square frames');
  const frames = height / side;
  if (frames < ANIMATED_AVATAR_MIN_FRAMES || frames > ANIMATED_AVATAR_MAX_FRAMES) {
    throw new InvalidImageError('frame count out of range');
  }
  if (!meta.hasAlpha) throw new InvalidImageError('no alpha channel');
  let raw: Buffer;
  try {
    raw = await sharp(bytes, { failOn: 'error', limitInputPixels: side * height })
      .toColorspace('srgb')
      .ensureAlpha()
      .raw()
      .toBuffer();
  } catch {
    throw new InvalidImageError('not decodable');
  }
  if (raw.length !== side * height * 4) throw new InvalidImageError('unexpected pixel layout');
  const input = { raw: { width: side, height, channels: 4 as const, pageHeight: side } };
  const delay = Array.from({ length: frames }, () => ANIMATED_AVATAR_FRAME_MS);
  let clip: Buffer | null = null;
  for (const [quality, alphaQuality] of QUALITIES) {
    const out = await sharp(raw, input).webp({ quality, alphaQuality, loop: 0, delay, effort: 4 }).toBuffer();
    if (out.length <= MAX_ANIMATED_AVATAR_WEBP_BYTES) {
      clip = out;
      break;
    }
  }
  if (!clip) throw new InvalidImageError('animated WebP too large');
  const still = await sharp(raw.subarray(0, side * side * 4), {
    raw: { width: side, height: side, channels: 4 },
  })
    .webp({ quality: 82, alphaQuality: 90 })
    .toBuffer();
  return { clip, still, side, frames };
}
