import { createHash } from 'node:crypto';
import sharp from 'sharp';
import { GiftArtError, giftAnimationFile, type GiftArtFile } from '../gifts/gift-art.js';

/**
 * v1.83-social (D258, CONVENTIONS §10.94.6): a VIP badge's or perk's art uploaded from the panel — an SVGA 2.x
 * animation (≤ 25 MB, the gifts' checks) or a still (PNG / WebP ≤ 2 MB, 16 … 4096 px a side, any shape: an entry banner
 * is wide, a profile card tall). Stored content-addressed under `media/vip/<tier>/`.
 */
export const VIP_STILL_MAX_BYTES = 2 * 1024 * 1024;
const STILL_MIN_SIDE = 16;
const STILL_MAX_SIDE = 4096;

export type VipUploadKind = 'animation' | 'still';

export interface VipArtFile extends GiftArtFile {
  readonly width?: number;
  readonly height?: number;
}

function key(tier: string, body: Buffer, ext: string): string {
  const digest = createHash('sha256').update(body).digest('hex').slice(0, 32);
  return `media/vip/${tier}/${digest}.${ext}`;
}

/** Checks an SVGA 2.x upload (as a gift's effect) and keys it under the tier. Throws {@link GiftArtError}. */
export function vipAnimationFile(tier: string, body: Buffer): VipArtFile {
  const checked = giftAnimationFile(tier, body);
  return { ...checked, key: key(tier, body, 'svga') };
}

/** Checks a still (PNG / WebP by its bytes) and reads its size. Throws {@link GiftArtError}. */
export async function vipStillFile(tier: string, body: Buffer): Promise<VipArtFile> {
  if (body.length === 0) throw new GiftArtError('The image file is empty.');
  if (body.length > VIP_STILL_MAX_BYTES) {
    throw new GiftArtError(
      `The image is ${String(body.length)} bytes; at most ${String(VIP_STILL_MAX_BYTES)} (2 MB).`,
    );
  }
  const png =
    body.length >= 8 &&
    body.subarray(0, 8).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]));
  const webp =
    body.length >= 12 &&
    body.subarray(0, 4).toString('latin1') === 'RIFF' &&
    body.subarray(8, 12).toString('latin1') === 'WEBP';
  if (!png && !webp) throw new GiftArtError('The image must be a PNG or WebP file.');
  let width: number | undefined;
  let height: number | undefined;
  try {
    ({ width, height } = await sharp(body).metadata());
  } catch {
    throw new GiftArtError('The image cannot be read (a broken PNG or WebP file).');
  }
  if (!width || !height) throw new GiftArtError('The image has no size.');
  if (Math.min(width, height) < STILL_MIN_SIDE || Math.max(width, height) > STILL_MAX_SIDE) {
    throw new GiftArtError(
      `The image is ${String(width)} × ${String(height)} px; each side must be ${String(STILL_MIN_SIDE)}–${String(STILL_MAX_SIDE)} px.`,
    );
  }
  return {
    key: key(tier, body, png ? 'png' : 'webp'),
    contentType: png ? 'image/png' : 'image/webp',
    body,
    size: body.length,
    width,
    height,
  };
}
