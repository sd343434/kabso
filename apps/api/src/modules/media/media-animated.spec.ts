import sharp from 'sharp';
import { describe, expect, it } from 'vitest';
import {
  ANIMATED_AVATAR_FRAME_MS,
  ANIMATED_AVATAR_MAX_FRAMES,
  ANIMATED_AVATAR_MAX_SIDE,
  MAX_ANIMATED_AVATAR_BYTES,
  MAX_ANIMATED_AVATAR_WEBP_BYTES,
  processAnimatedAvatar,
} from './media-animated.js';
import { InvalidImageError } from './media-image.js';
import { createMediaUploadSchema, maxUploadBytes } from './media.service.js';

/** v1.136-social (D384, CONVENTIONS §10.173.2): the animated picture's strip check and re-encoding. */

/** A synthetic strip (no face): a transparent background with a disc that moves frame to frame. */
async function strip(
  side: number,
  frames: number,
  channels: 3 | 4 = 4,
  height = side * frames,
): Promise<Buffer> {
  const raw = Buffer.alloc(side * height * channels);
  for (let y = 0; y < height; y += 1) {
    for (let x = 0; x < side; x += 1) {
      const i = (y * side + x) * channels;
      const dx = x - side / 2 - Math.floor(y / side);
      const dy = (y % side) - side / 2;
      raw[i] = 220;
      raw[i + 1] = 140;
      raw[i + 2] = 90;
      if (channels === 4) raw[i + 3] = dx * dx + dy * dy < (side * side) / 9 ? 255 : 0;
    }
  }
  return sharp(raw, { raw: { width: side, height, channels } })
    .png()
    .toBuffer();
}

describe('D384 animated picture strip', () => {
  it('the limits: 8 MiB PNG strips, 2–36 square frames of 64–512 px, 12 a second, a WebP ≤ 1.5 MiB', () => {
    expect(MAX_ANIMATED_AVATAR_BYTES).toBe(8 * 1024 * 1024);
    expect(maxUploadBytes('ANIMATED_AVATAR')).toBe(8 * 1024 * 1024);
    expect(ANIMATED_AVATAR_MAX_FRAMES).toBe(36);
    expect(ANIMATED_AVATAR_MAX_SIDE).toBe(512);
    expect(ANIMATED_AVATAR_FRAME_MS).toBe(83);
    expect(MAX_ANIMATED_AVATAR_WEBP_BYTES).toBe(1.5 * 1024 * 1024);
    const ok = (contentType: string, byteSize: number) =>
      createMediaUploadSchema.safeParse({ kind: 'ANIMATED_AVATAR', contentType, byteSize }).success;
    expect(ok('image/png', 8 * 1024 * 1024)).toBe(true);
    expect(ok('image/png', 8 * 1024 * 1024 + 1)).toBe(false);
    expect(ok('image/jpeg', 1000)).toBe(false);
    expect(ok('image/webp', 1000)).toBe(false);
    expect(ok('video/mp4', 1000)).toBe(false);
  });

  it('re-encodes a strip into a looping animated WebP with alpha and a still of the first frame', async () => {
    const out = await processAnimatedAvatar(await strip(80, 6));
    expect(out).toMatchObject({ side: 80, frames: 6 });
    const clip = await sharp(out.clip, { animated: true }).metadata();
    expect(clip).toMatchObject({
      format: 'webp',
      pages: 6,
      pageHeight: 80,
      width: 80,
      hasAlpha: true,
      loop: 0,
    });
    expect(clip.delay).toEqual(Array.from({ length: 6 }, () => 83));
    const still = await sharp(out.still).metadata();
    expect(still).toMatchObject({ format: 'webp', width: 80, height: 80, hasAlpha: true });
  });

  it('refuses anything else', async () => {
    const refused = async (bytes: Buffer) => {
      await expect(processAnimatedAvatar(bytes)).rejects.toBeInstanceOf(InvalidImageError);
    };
    await refused(Buffer.from('not an image at all'));
    await refused(
      await sharp(await strip(64, 2))
        .webp()
        .toBuffer(),
    );
    await refused(await strip(96, 3, 3));
    await refused(await strip(96, 3, 4, 96 * 3 + 1));
    await refused(await strip(96, 1));
    await refused(await strip(64, 37));
    await refused(await strip(63, 3));
    await refused(await strip(513, 2));
    // A truncated PNG.
    const cut = await strip(96, 3);
    await refused(cut.subarray(0, cut.length - 40));
  });
});
