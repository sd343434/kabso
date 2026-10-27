import sharp from 'sharp';
import { describe, expect, it } from 'vitest';
import { InvalidImageError, processImage, sniffImageType } from './media-image.js';

const solid = (width: number, height: number) =>
  sharp({ create: { width, height, channels: 3, background: { r: 200, g: 30, b: 40 } } });

describe('sniffImageType', () => {
  it('reads the signature, not the name', async () => {
    expect(sniffImageType(await solid(4, 4).jpeg().toBuffer())).toBe('image/jpeg');
    expect(sniffImageType(await solid(4, 4).png().toBuffer())).toBe('image/png');
    expect(sniffImageType(await solid(4, 4).webp().toBuffer())).toBe('image/webp');
    expect(sniffImageType(await solid(4, 4).gif().toBuffer())).toBeNull();
    expect(sniffImageType(Buffer.from('<svg xmlns="http://www.w3.org/2000/svg"/>'))).toBeNull();
    expect(sniffImageType(Buffer.alloc(0))).toBeNull();
  });
});

describe('processImage', () => {
  it('re-encodes to WebP 1080/320, applies orientation and drops every metadata block', async () => {
    const input = await solid(2400, 1200)
      .jpeg()
      .withExif({ IFD0: { Make: 'TestCam', Copyright: 'private' }, IFD3: { GPSLatitudeRef: 'N' } })
      .withMetadata({ orientation: 6 })
      .toBuffer();
    expect((await sharp(input).metadata()).exif).toBeDefined();
    const out = await processImage(input, 'image/jpeg');
    // Orientation 6 rotates by 90°: the long side is now the height.
    expect([out.width, out.height]).toEqual([540, 1080]);
    for (const buffer of [out.large, out.thumb]) {
      const meta = await sharp(buffer).metadata();
      expect(meta.format).toBe('webp');
      expect(meta.exif).toBeUndefined();
      expect(meta.xmp).toBeUndefined();
      expect(meta.orientation).toBeUndefined();
    }
    expect(
      Math.max((await sharp(out.thumb).metadata()).width, (await sharp(out.thumb).metadata()).height),
    ).toBe(320);
    expect(out.blurhash).toMatch(/^[0-9A-Za-z#$%*+,-.:;=?@[\]^_{|}~]{6,}$/);
  });

  it('never enlarges a small image', async () => {
    const out = await processImage(await solid(300, 200).png().toBuffer(), 'image/png');
    expect([out.width, out.height]).toEqual([300, 200]);
  });

  it('D124: a banner is cover-cropped to exactly 1 500 × 500 and 320 × 107, whatever the upload', async () => {
    for (const [w, h] of [
      [3000, 600],
      [1200, 1200],
      [800, 100],
    ] as const) {
      const out = await processImage(await solid(w, h).png().toBuffer(), 'image/png', 1500, 'banner');
      expect([out.width, out.height]).toEqual([1500, 500]);
      const thumb = await sharp(out.thumb).metadata();
      expect([thumb.width, thumb.height, thumb.format]).toEqual([320, 107, 'webp']);
    }
  });

  it('refuses a declared type that the bytes contradict', async () => {
    const png = await solid(10, 10).png().toBuffer();
    await expect(processImage(png, 'image/jpeg')).rejects.toBeInstanceOf(InvalidImageError);
  });

  it('refuses bytes that only carry a valid signature', async () => {
    const fake = Buffer.concat([Buffer.from([0xff, 0xd8, 0xff, 0xe0]), Buffer.alloc(200, 7)]);
    await expect(processImage(fake, 'image/jpeg')).rejects.toBeInstanceOf(InvalidImageError);
  });

  it('refuses images wider or taller than 8 000 px', async () => {
    const wide = await solid(8001, 2).png().toBuffer();
    await expect(processImage(wide, 'image/png')).rejects.toBeInstanceOf(InvalidImageError);
  });
});
