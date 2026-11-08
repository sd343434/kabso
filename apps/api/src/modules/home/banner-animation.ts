/**
 * D248c (owner: «… جميعها يتم تحميلها من لوحة الأدمن، كل فئة يمكن أن تكون متحركة»; CONVENTIONS §10.90.1): an
 * animated banner picture (animated WebP or GIF) keeps its animation — every frame cover-cropped around the centre to
 * the placement's size and re-encoded as an animated WebP (metadata dropped), with a still first-frame thumbnail.
 * Static pictures (JPEG, PNG, WebP, a one-frame GIF) take the usual `processImage` path.
 */
import { encode } from 'blurhash';
import sharp from 'sharp';
import { MAX_IMAGE_PIXELS, MAX_IMAGE_SIDE } from '../media/media-image.js';

/** At most this many frames. */
export const BANNER_ANIMATION_MAX_FRAMES = 150;
/** At most this long, one loop (milliseconds). */
export const BANNER_ANIMATION_MAX_MS = 10_000;
/** The stored animated WebP is at most this big. */
export const BANNER_ANIMATION_MAX_OUTPUT_BYTES = 3 * 1024 * 1024;
/** Every frame of all frames together: at most this many pixels decoded (150 frames of 1 500 × 1 000). */
const MAX_TOTAL_PIXELS = 225_000_000;
/** GIF frames without a delay play at 100 ms (as browsers do). */
const DEFAULT_DELAY_MS = 100;

/** Why an animated banner is refused: a machine-readable issue (the panel translates it) and an English message. */
export class BannerAnimationError extends Error {
  constructor(
    readonly issue:
      | 'banner_animation_too_many_frames'
      | 'banner_animation_too_long'
      | 'banner_animation_too_large'
      | 'banner_animation_unreadable',
    message: string,
  ) {
    super(message);
  }
}

/** `GIF87a` / `GIF89a`. */
export function isGif(bytes: Buffer): boolean {
  return bytes.length >= 6 && /^GIF8[79]a$/.test(bytes.toString('ascii', 0, 6));
}

export interface ProcessedBanner {
  readonly large: Buffer;
  readonly thumb: Buffer;
  /** v1.97-social (D303): the first frame at full size (the still shown with reduced motion). */
  readonly poster?: Buffer;
  readonly width: number;
  readonly height: number;
  readonly blurhash: string;
  readonly frames: number;
  readonly durationMs: number;
}

/**
 * The number of frames of an animated WebP or GIF (1 = still), or null when the bytes are not a readable WebP / GIF.
 */
export async function bannerFrameCount(bytes: Buffer): Promise<number | null> {
  try {
    const meta = await sharp(bytes, { animated: true, limitInputPixels: false, failOn: 'error' }).metadata();
    if (meta.format !== 'webp' && meta.format !== 'gif') return null;
    return meta.pages ?? 1;
  } catch {
    return null;
  }
}

/**
 * Crops every frame of an animated WebP / GIF to `width` × `height` (cover, centre) and the first frame to the thumbnail
 * (`thumbWidth` × `thumbHeight`). Refuses more than 150 frames, longer than 10 s, frames beyond 8 000 px / 50 MP, and an
 * output above 3 MB (after one retry at a lower quality).
 */
export async function processAnimatedBanner(
  bytes: Buffer,
  width: number,
  height: number,
  thumbWidth: number,
  thumbHeight: number,
): Promise<ProcessedBanner> {
  let meta;
  try {
    meta = await sharp(bytes, { animated: true, limitInputPixels: false, failOn: 'error' }).metadata();
  } catch {
    throw new BannerAnimationError('banner_animation_unreadable', 'The animated picture could not be read.');
  }
  const frames = meta.pages ?? 1;
  const frameWidth = meta.width ?? 0;
  const frameHeight = meta.pageHeight ?? meta.height ?? 0;
  if (frames > BANNER_ANIMATION_MAX_FRAMES) {
    throw new BannerAnimationError(
      'banner_animation_too_many_frames',
      `The animation has ${String(frames)} frames; at most ${String(BANNER_ANIMATION_MAX_FRAMES)}.`,
    );
  }
  const delays = meta.delay ?? [];
  let durationMs = 0;
  for (let i = 0; i < frames; i++) {
    const d = delays[i];
    durationMs += d !== undefined && d > 0 ? d : DEFAULT_DELAY_MS;
  }
  if (durationMs > BANNER_ANIMATION_MAX_MS) {
    throw new BannerAnimationError(
      'banner_animation_too_long',
      `The animation lasts ${(durationMs / 1000).toFixed(1)} s; at most ${String(BANNER_ANIMATION_MAX_MS / 1000)} s.`,
    );
  }
  if (
    frameWidth < 1 ||
    frameHeight < 1 ||
    frameWidth > MAX_IMAGE_SIDE ||
    frameHeight > MAX_IMAGE_SIDE ||
    frameWidth * frameHeight > MAX_IMAGE_PIXELS ||
    frameWidth * frameHeight * frames > MAX_TOTAL_PIXELS
  ) {
    throw new BannerAnimationError(
      'banner_animation_too_large',
      'The animation frames are too large (at most 8 000 px a side and 50 MP a frame).',
    );
  }
  const input = () => sharp(bytes, { animated: true, limitInputPixels: false, failOn: 'error' });
  const encodeAt = (quality: number) =>
    input()
      .resize(width, height, { fit: 'cover', position: 'centre' })
      .webp({ quality, loop: 0, effort: 4 })
      .toBuffer();
  let large: Buffer;
  try {
    large = await encodeAt(80);
    if (large.length > BANNER_ANIMATION_MAX_OUTPUT_BYTES) large = await encodeAt(55);
  } catch {
    throw new BannerAnimationError(
      'banner_animation_unreadable',
      'The animated picture could not be re-encoded.',
    );
  }
  if (large.length > BANNER_ANIMATION_MAX_OUTPUT_BYTES) {
    throw new BannerAnimationError(
      'banner_animation_too_large',
      `The animation is ${(large.length / 1024 / 1024).toFixed(1)} MB after cropping; at most 3 MB (fewer frames or colours).`,
    );
  }
  const first = () => sharp(bytes, { pages: 1, limitInputPixels: false, failOn: 'error' });
  const thumb = await first()
    .resize(thumbWidth, thumbHeight, { fit: 'cover', position: 'centre' })
    .webp({ quality: 75 })
    .toBuffer();
  // v1.97-social (D303, §10.114.6): the first frame at the banner's size, for reduced motion.
  const poster = await first()
    .resize(width, height, { fit: 'cover', position: 'centre' })
    .webp({ quality: 80 })
    .toBuffer();
  const small = await first()
    .resize(32, 32, { fit: 'inside' })
    .ensureAlpha()
    .raw()
    .toBuffer({ resolveWithObject: true });
  const blurhash = encode(new Uint8ClampedArray(small.data), small.info.width, small.info.height, 4, 3);
  return { large, thumb, poster, width, height, blurhash, frames, durationMs };
}
