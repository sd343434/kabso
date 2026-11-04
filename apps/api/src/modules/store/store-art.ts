import { createHash } from 'node:crypto';
import { GiftArtError, giftAnimationFile, giftVideoFile, type GiftArtFile } from '../gifts/gift-art.js';
import { vipStillFile } from '../vip/vip-art.js';

/**
 * D270 (CONVENTIONS §10.98.5): a store item's art uploaded from the panel — a still (PNG / WebP ≤ 2 MB, any shape: a
 * banner is wide, a card tall; VIP's checks) and an animation: an SVGA 2.x (≤ 25 MB, the gifts' checks) **or** an MP4
 * (H.264, ≤ 8 MB, ≤ 15 s; the gifts' D207 checks — a side-by-side transparent one is suggested when the frame is at
 * least 1.8 × as wide as tall). Stored content-addressed under `media/store/`.
 */

export interface StoreArtFile extends GiftArtFile {
  readonly format: 'SVGA' | 'MP4' | null;
  readonly width: number | null;
  readonly height: number | null;
  /** An MP4's suggested transparency (the panel may change it); null otherwise. */
  readonly detectedAlpha: 'NONE' | 'SIDE_BY_SIDE' | null;
  readonly durationMs: number | null;
}

function storeKey(body: Buffer, ext: string): string {
  const digest = createHash('sha256').update(body).digest('hex').slice(0, 32);
  return `media/store/${digest}.${ext}`;
}

/** An ISO-BMFF file (`ftyp` at offset 4): an MP4 (checked further by the gifts' video checks). */
export function looksLikeMp4(body: Buffer): boolean {
  return body.length >= 12 && body.subarray(4, 8).toString('latin1') === 'ftyp';
}

/** Checks an animation (SVGA 2.x or MP4, told by its bytes). Throws {@link GiftArtError}. */
export async function storeAnimationFile(body: Buffer): Promise<StoreArtFile> {
  if (looksLikeMp4(body)) {
    const video = await giftVideoFile('store', body);
    return {
      key: storeKey(body, 'mp4'),
      contentType: video.contentType,
      body,
      size: video.size,
      format: 'MP4',
      // A side-by-side video's picture is half its width.
      width: video.detectedAlpha === 'SIDE_BY_SIDE' ? Math.round(video.width / 2) : video.width,
      height: video.height,
      detectedAlpha: video.detectedAlpha,
      durationMs: video.durationMs,
    };
  }
  const svga = giftAnimationFile('store', body);
  return {
    key: storeKey(body, 'svga'),
    contentType: svga.contentType,
    body,
    size: svga.size,
    format: 'SVGA',
    width: null,
    height: null,
    detectedAlpha: null,
    durationMs: null,
  };
}

/** Checks a still (PNG / WebP by its bytes) and reads its size. Throws {@link GiftArtError}. */
export async function storeStillFile(body: Buffer): Promise<StoreArtFile> {
  const still = await vipStillFile('store', body);
  const ext = still.contentType === 'image/png' ? 'png' : 'webp';
  return {
    key: storeKey(body, ext),
    contentType: still.contentType,
    body,
    size: still.size,
    format: null,
    width: still.width ?? null,
    height: still.height ?? null,
    detectedAlpha: null,
    durationMs: null,
  };
}

export { GiftArtError };
