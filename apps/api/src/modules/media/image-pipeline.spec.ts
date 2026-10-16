import sharp from 'sharp';
import { afterEach, describe, expect, it } from 'vitest';
import {
  animatedWebp,
  asApng,
  jpeg,
  OTHER_FORMATS,
  png,
  pngBomb,
  POLYGLOT_MARKER,
  polyglot,
  webp,
  withJpegComment,
} from '../../../test/helpers/image-fixtures.js';
import { detectContentType, readImageHeader } from './image-header.js';
import { centredCrop, precheck, processImage, type ProcessRules } from './image-pipeline.js';
import { asOutcome, ImageProcessor } from './image-processor.js';
import { PURPOSES, type MediaContentType } from './media.constants.js';

const rulesOf = (purpose: 'avatar' | 'room_cover'): ProcessRules => {
  const r = PURPOSES[purpose];
  return { ratio: r.ratio, minWidth: r.minWidth, minHeight: r.minHeight, main: r.main, thumb: r.thumb };
};

const run = (bytes: Buffer, declaredType: MediaContentType, purpose: 'avatar' | 'room_cover' = 'avatar') =>
  processImage({ bytes, declaredType, rules: rulesOf(purpose), timeoutSeconds: 10 });

async function expectCleanWebp(data: Uint8Array, width: number, height: number): Promise<void> {
  const buf = Buffer.from(data);
  expect(buf.toString('latin1', 0, 4)).toBe('RIFF');
  expect(buf.toString('latin1', 8, 12)).toBe('WEBP');
  const meta = await sharp(buf).metadata();
  expect({ format: meta.format, width: meta.width, height: meta.height }).toEqual({
    format: 'webp',
    width,
    height,
  });
  // CONVENTIONS §11.2: no EXIF (incl. GPS), XMP, IPTC, ICC or text metadata in any derivative.
  expect(meta.exif).toBeUndefined();
  expect(meta.xmp).toBeUndefined();
  expect(meta.iptc).toBeUndefined();
  expect(meta.icc).toBeUndefined();
  expect(meta.comments ?? []).toEqual([]);
  expect(buf.includes(Buffer.from('Exif', 'latin1'))).toBe(false);
  expect(buf.includes(Buffer.from('XMP ', 'latin1'))).toBe(false);
  expect(buf.includes(Buffer.from('ICCP', 'latin1'))).toBe(false);
}

describe('magic-byte detection and header parsing (no decoder)', () => {
  it('detects JPEG, PNG and WebP by their magic bytes', async () => {
    expect(detectContentType(await jpeg(16, 16))).toBe('image/jpeg');
    expect(detectContentType(await png(16, 16))).toBe('image/png');
    expect(detectContentType(await webp(16, 16))).toBe('image/webp');
  });

  it.each(Object.entries(OTHER_FORMATS))('refuses %s', (_name, bytes) => {
    expect(detectContentType(bytes)).toBeNull();
    expect(precheck(bytes, 'image/jpeg')).toMatchObject({ ok: false, issue: 'invalid_format' });
  });

  it('reads width and height from the headers of all three formats', async () => {
    expect(readImageHeader(await jpeg(321, 123), 'image/jpeg')).toEqual({
      width: 321,
      height: 123,
      animated: false,
    });
    expect(readImageHeader(await png(77, 55), 'image/png')).toEqual({
      width: 77,
      height: 55,
      animated: false,
    });
    expect(readImageHeader(await webp(640, 480), 'image/webp')).toEqual({
      width: 640,
      height: 480,
      animated: false,
    });
    const lossless = await sharp({ create: { width: 300, height: 200, channels: 3, background: 'red' } })
      .webp({ lossless: true })
      .toBuffer();
    expect(readImageHeader(lossless, 'image/webp')).toEqual({ width: 300, height: 200, animated: false });
  });

  it('flags animation from the header: animated WebP and APNG', async () => {
    expect(readImageHeader(await animatedWebp(200, 200), 'image/webp')).toMatchObject({ animated: true });
    expect(readImageHeader(asApng(await png(200, 200)), 'image/png')).toMatchObject({ animated: true });
  });

  it('returns null for truncated or malformed headers', async () => {
    const full = await jpeg(64, 64);
    expect(readImageHeader(full.subarray(0, 4), 'image/jpeg')).toBeNull();
    expect(readImageHeader(Buffer.from([0xff, 0xd8, 0xff, 0xda, 0, 2]), 'image/jpeg')).toBeNull();
    expect(readImageHeader((await png(10, 10)).subarray(0, 20), 'image/png')).toBeNull();
    expect(readImageHeader(Buffer.from('RIFF\0\0\0\0WEBPVP8 ', 'latin1'), 'image/webp')).toBeNull();
  });

  it('computes the largest centred crop for each ratio', () => {
    expect(centredCrop(1000, 800, [1, 1])).toEqual({ left: 100, top: 0, width: 800, height: 800 });
    expect(centredCrop(1000, 800, [3, 4])).toEqual({ left: 200, top: 0, width: 600, height: 800 });
    expect(centredCrop(600, 2000, [3, 4])).toEqual({ left: 0, top: 600, width: 600, height: 800 });
  });
});

describe('decompression bombs are refused from the header, before decoding', () => {
  it('a PNG declaring 20000 × 20000 → too_big (side limit)', () => {
    expect(precheck(pngBomb(20_000, 20_000), 'image/png')).toEqual({
      ok: false,
      issue: 'too_big',
      reason: 'side_limit',
    });
  });

  it('a PNG declaring 8000 × 8000 (64 MP) → too_big (pixel limit)', async () => {
    expect(precheck(pngBomb(8000, 8000), 'image/png')).toEqual({
      ok: false,
      issue: 'too_big',
      reason: 'pixel_limit',
    });
    expect(await run(pngBomb(8000, 8000), 'image/png')).toMatchObject({ ok: false, issue: 'too_big' });
  });

  it('a PNG at exactly 8192 × 4882 (under 40 MP) passes the header check', () => {
    expect(precheck(pngBomb(8192, 4882), 'image/png')).toMatchObject({ ok: true });
  });

  it('a JPEG header declaring 65535 × 65535 → too_big', async () => {
    const real = await jpeg(16, 16);
    const forged = Buffer.from(real);
    // Patch the SOF0 dimensions in place.
    for (let i = 2; i < forged.length - 9; i += 1) {
      if (forged[i] === 0xff && forged[i + 1] === 0xc0) {
        forged.writeUInt16BE(0xffff, i + 5);
        forged.writeUInt16BE(0xffff, i + 7);
        break;
      }
    }
    expect(await run(forged, 'image/jpeg')).toMatchObject({ ok: false, issue: 'too_big' });
  });
});

describe('processImage (CONVENTIONS §11.2)', () => {
  it('avatar: centre-crops to 1:1 and writes 512 and 128 px WebP without metadata', async () => {
    const result = await run(await jpeg(1000, 800), 'image/jpeg');
    expect(result.ok).toBe(true);
    if (!result.ok) return;
    expect(result.detectedType).toBe('image/jpeg');
    await expectCleanWebp(result.main.data, 512, 512);
    await expectCleanWebp(result.thumb.data, 128, 128);
  });

  it('room cover: centre-crops to 3:4 and writes 960 × 1280 and 480 × 640', async () => {
    const result = await run(await png(1200, 1600), 'image/png', 'room_cover');
    expect(result.ok).toBe(true);
    if (!result.ok) return;
    await expectCleanWebp(result.main.data, 960, 1280);
    await expectCleanWebp(result.thumb.data, 480, 640);
  });

  it('accepts WebP input', async () => {
    expect(await run(await webp(300, 300), 'image/webp')).toMatchObject({ ok: true });
  });

  it('never upscales: a 300 × 200 avatar gives a 200 px main derivative', async () => {
    const result = await run(await jpeg(300, 200), 'image/jpeg');
    expect(result).toMatchObject({
      ok: true,
      main: { width: 200, height: 200 },
      thumb: { width: 128, height: 128 },
    });
  });

  it('applies EXIF orientation before cropping', async () => {
    // Stored 1280 × 960 with orientation 6 (rotate 90°): displayed 960 × 1280, exactly 3:4.
    const rotated = await jpeg(1280, 960, { orientation: 6 });
    expect((await sharp(rotated).metadata()).orientation).toBe(6);
    const result = await run(rotated, 'image/jpeg', 'room_cover');
    expect(result).toMatchObject({ ok: true, main: { width: 960, height: 1280 } });
  });

  it('strips GPS EXIF, ICC and comments (a GPS-tagged JPEG gives clean derivatives)', async () => {
    const tagged = await jpeg(600, 600, { gps: true, icc: true, comment: 'secret-comment-text' });
    const input = await sharp(tagged).metadata();
    expect(input.exif).toBeDefined();
    expect(input.icc).toBeDefined();
    const result = await run(tagged, 'image/jpeg');
    expect(result.ok).toBe(true);
    if (!result.ok) return;
    await expectCleanWebp(result.main.data, 512, 512);
    await expectCleanWebp(result.thumb.data, 128, 128);
    for (const d of [result.main.data, result.thumb.data]) {
      const buf = Buffer.from(d);
      expect(buf.includes(Buffer.from('KabsoTestCam', 'latin1'))).toBe(false);
      expect(buf.includes(Buffer.from('secret-comment-text', 'latin1'))).toBe(false);
    }
  });

  it('polyglot: trailing HTML / ZIP data is not carried into the derivatives', async () => {
    const result = await run(polyglot(await jpeg(400, 400)), 'image/jpeg');
    expect(result.ok).toBe(true);
    if (!result.ok) return;
    for (const d of [result.main.data, result.thumb.data]) {
      const buf = Buffer.from(d);
      expect(buf.includes(Buffer.from(POLYGLOT_MARKER, 'latin1'))).toBe(false);
      expect(buf.includes(Buffer.from([0x50, 0x4b, 0x05, 0x06]))).toBe(false);
    }
  });

  it('polyglot: a script in a JPEG comment segment is not carried over', async () => {
    const result = await run(withJpegComment(await jpeg(300, 300), POLYGLOT_MARKER), 'image/jpeg');
    expect(result.ok).toBe(true);
    if (result.ok)
      expect(Buffer.from(result.main.data).includes(Buffer.from(POLYGLOT_MARKER, 'latin1'))).toBe(false);
  });

  it.each([
    ['avatar below 128 px', 'avatar', 100, 400],
    ['cover crop below 480 × 640', 'room_cover', 470, 2000],
    ['cover crop below 480 × 640 (wide)', 'room_cover', 2000, 600],
  ] as const)('too_small: %s', async (_label, purpose, w, h) => {
    expect(await run(await jpeg(w, h), 'image/jpeg', purpose)).toMatchObject({
      ok: false,
      issue: 'too_small',
    });
  });

  it('invalid_format: the detected type differs from the declared type', async () => {
    expect(await run(await jpeg(300, 300), 'image/png')).toMatchObject({
      ok: false,
      issue: 'invalid_format',
      reason: 'type_mismatch',
    });
    expect(await run(await png(300, 300), 'image/webp')).toMatchObject({
      ok: false,
      issue: 'invalid_format',
    });
  });

  it('invalid_format: animated WebP and APNG', async () => {
    expect(await run(await animatedWebp(300, 300), 'image/webp')).toMatchObject({
      ok: false,
      issue: 'invalid_format',
      reason: 'animated',
    });
    expect(await run(asApng(await png(300, 300)), 'image/png')).toMatchObject({
      ok: false,
      issue: 'invalid_format',
      reason: 'animated',
    });
  });

  it('invalid_format: truncated and undecodable data', async () => {
    const full = await jpeg(400, 400);
    expect(await run(full.subarray(0, Math.floor(full.length / 2)), 'image/jpeg')).toMatchObject({
      ok: false,
      issue: 'invalid_format',
    });
    const garbage = Buffer.concat([full.subarray(0, 200), Buffer.alloc(5000, 0x41)]);
    expect(await run(garbage, 'image/jpeg')).toMatchObject({ ok: false, issue: 'invalid_format' });
  });

  it.each(Object.entries(OTHER_FORMATS))(
    'invalid_format: %s bytes declared as JPEG',
    async (_name, bytes) => {
      expect(await run(bytes, 'image/jpeg')).toMatchObject({ ok: false, issue: 'invalid_format' });
    },
  );

  it('only the JPEG, PNG and WebP loaders are enabled (a real GIF is refused by libvips too)', async () => {
    const gif = await sharp({ create: { width: 10, height: 10, channels: 3, background: 'blue' } })
      .gif()
      .toBuffer();
    await expect(sharp(gif).metadata()).rejects.toThrow();
  });
});

describe('ImageProcessor: isolated worker, time limit and concurrency cap', () => {
  const misbehaving = new URL('../../../test/helpers/misbehaving-image-worker.ts', import.meta.url);
  const processors: ImageProcessor[] = [];
  afterEach(() => processors.splice(0));

  it('processes a job in the real worker process', async () => {
    const processor = new ImageProcessor({ maxConcurrency: 1, timeoutMs: 20_000 });
    const outcome = await processor.process({
      bytes: await jpeg(600, 400),
      declaredType: 'image/jpeg',
      rules: rulesOf('avatar'),
    });
    expect(outcome).toMatchObject({ ok: true, main: { width: 400, height: 400 } });
    expect(processor.active).toBe(0);
  }, 30_000);

  it('the real worker refuses a bomb from the header', async () => {
    const processor = new ImageProcessor({ maxConcurrency: 1, timeoutMs: 20_000 });
    const outcome = await processor.process({
      bytes: pngBomb(30_000, 30_000),
      declaredType: 'image/png',
      rules: rulesOf('avatar'),
    });
    expect(outcome).toMatchObject({ ok: false, issue: 'too_big' });
  }, 30_000);

  it('kills a worker that exceeds the time limit → invalid_format', async () => {
    const processor = new ImageProcessor({ maxConcurrency: 1, timeoutMs: 1500, workerUrl: misbehaving });
    const started = Date.now();
    const outcome = await processor.process({
      bytes: Buffer.alloc(1),
      declaredType: 'image/jpeg',
      rules: rulesOf('avatar'),
    });
    expect(outcome).toEqual({ ok: false, issue: 'invalid_format', reason: 'timeout' });
    expect(Date.now() - started).toBeLessThan(10_000);
    expect(processor.active).toBe(0);
  }, 20_000);

  it('a crashing worker → invalid_format', async () => {
    const processor = new ImageProcessor({ maxConcurrency: 1, timeoutMs: 10_000, workerUrl: misbehaving });
    const outcome = await processor.process({
      bytes: Buffer.alloc(1),
      declaredType: 'image/png',
      rules: rulesOf('avatar'),
    });
    expect(outcome).toMatchObject({ ok: false, issue: 'invalid_format' });
  }, 20_000);

  it('a forged answer from the worker is not trusted', async () => {
    const processor = new ImageProcessor({ maxConcurrency: 1, timeoutMs: 10_000, workerUrl: misbehaving });
    const outcome = await processor.process({
      bytes: Buffer.alloc(1),
      declaredType: 'image/webp',
      rules: rulesOf('avatar'),
    });
    expect(outcome).toEqual({ ok: false, issue: 'invalid_format', reason: 'bad_worker_answer' });
    expect(asOutcome(null)).toMatchObject({ ok: false, issue: 'invalid_format' });
    expect(asOutcome({ ok: false, issue: 'evil' })).toMatchObject({ issue: 'invalid_format' });
  }, 20_000);

  it('saturated: 503 SERVICE_UNAVAILABLE with Retry-After, no queue; released slots are reusable', async () => {
    const processor = new ImageProcessor({ maxConcurrency: 2, timeoutMs: 7000 });
    const a = processor.reserve();
    const b = processor.reserve();
    let error: unknown;
    try {
      processor.reserve();
    } catch (err) {
      error = err;
    }
    expect(error).toMatchObject({
      code: 'SERVICE_UNAVAILABLE',
      status: 503,
      headers: { 'Retry-After': '7' },
    });
    a.release();
    b.release();
    b.release(); // idempotent
    await new Promise((resolve) => setImmediate(resolve));
    expect(processor.active).toBe(0);
    processor.reserve().release();
  });
});
