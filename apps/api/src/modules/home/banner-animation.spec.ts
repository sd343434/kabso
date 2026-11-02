import sharp from 'sharp';
import { describe, expect, it } from 'vitest';
import { BannerAnimationError, bannerFrameCount, isGif, processAnimatedBanner } from './banner-animation.js';

/** D248c: [n] Kabso-red frames of [delay] ms as an animated WebP or GIF. */
async function anim(
  n: number,
  delay: number,
  format: 'webp' | 'gif' = 'webp',
  w = 40,
  h = 30,
): Promise<Buffer> {
  if (n === 1)
    return sharp({ create: { width: w, height: h, channels: 3, background: '#e50914' } })
      .webp()
      .toBuffer();
  const frames = await Promise.all(
    Array.from({ length: n }, (_, i) =>
      sharp({
        create: {
          width: w,
          height: h,
          channels: 4,
          background: { r: 229, g: i % 256, b: (i * 13) % 256, alpha: 1 },
        },
      })
        .png()
        .toBuffer(),
    ),
  );
  const joined = sharp(frames, { join: { animated: true } });
  const delays = Array<number>(n).fill(delay);
  return format === 'gif'
    ? joined.gif({ loop: 0, delay: delays }).toBuffer()
    : joined.webp({ loop: 0, delay: delays }).toBuffer();
}

describe('D248c animated banners', () => {
  it('recognises GIF and counts frames', async () => {
    const gif = await anim(3, 100, 'gif');
    expect(isGif(gif)).toBe(true);
    expect(isGif(Buffer.from('RIFF0000WEBP'))).toBe(false);
    expect(await bannerFrameCount(gif)).toBe(3);
    expect(await bannerFrameCount(await anim(1, 100))).toBe(1);
    expect(await bannerFrameCount(Buffer.from('nope'))).toBeNull();
  });

  it('crops every frame to the size, keeps the frames and the loop length, a still thumbnail', async () => {
    const out = await processAnimatedBanner(await anim(5, 200), 1500, 300, 320, 64);
    expect(out).toMatchObject({ width: 1500, height: 300, frames: 5, durationMs: 1000 });
    const m = await sharp(out.large, { animated: true }).metadata();
    expect([m.format, m.width, m.pageHeight, m.pages]).toEqual(['webp', 1500, 300, 5]);
    const t = await sharp(out.thumb, { animated: true }).metadata();
    expect([t.width, t.height, t.pages ?? 1]).toEqual([320, 64, 1]);
  });

  it('refuses more than 150 frames and more than 10 s', async () => {
    await expect(
      processAnimatedBanner(await anim(151, 20, 'webp', 8, 8), 600, 800, 240, 320),
    ).rejects.toMatchObject({
      issue: 'banner_animation_too_many_frames',
    });
    const long = processAnimatedBanner(await anim(6, 2000, 'gif', 8, 8), 600, 800, 240, 320);
    await expect(long).rejects.toBeInstanceOf(BannerAnimationError);
    await expect(long).rejects.toMatchObject({ issue: 'banner_animation_too_long' });
  });
});
