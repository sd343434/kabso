/**
 * Test images generated at run time (D40: no binary fixtures, and no malicious sample is ever
 * committed). Decompression-bomb and polyglot inputs are built in memory by these helpers and are
 * only ever fed to the API's own verification code.
 */
import { deflateSync } from 'node:zlib';
import sharp from 'sharp';

/** A JPEG of the given size (a gradient, so it is not trivially compressible). */
export async function jpeg(
  width: number,
  height: number,
  options: { orientation?: number; gps?: boolean; icc?: boolean; comment?: string } = {},
): Promise<Buffer> {
  const channels = 3;
  const raw = Buffer.alloc(width * height * channels);
  for (let y = 0; y < height; y += 1) {
    for (let x = 0; x < width; x += 1) {
      const i = (y * width + x) * channels;
      raw[i] = (x * 255) / Math.max(1, width - 1);
      raw[i + 1] = (y * 255) / Math.max(1, height - 1);
      raw[i + 2] = 128;
    }
  }
  let image = sharp(raw, { raw: { width, height, channels } });
  if (options.gps) {
    image = image.withExif({
      IFD0: { Make: 'KabsoTestCam', Model: 'Fixture' },
      IFD3: {
        GPSLatitudeRef: 'N',
        GPSLatitude: '24/1 42/1 0/1',
        GPSLongitudeRef: 'E',
        GPSLongitude: '46/1 40/1 0/1',
      },
    });
  }
  if (options.icc) image = image.withIccProfile('p3');
  let out: Buffer = await image.jpeg({ quality: 85 }).toBuffer();
  if (options.orientation !== undefined)
    out = await sharp(out).withMetadata({ orientation: options.orientation }).jpeg().toBuffer();
  if (options.comment !== undefined) out = withJpegComment(out, options.comment);
  return out;
}

/** Inserts a COM segment right after SOI. */
export function withJpegComment(jpg: Buffer, text: string): Buffer {
  const body = Buffer.from(text, 'latin1');
  const segment = Buffer.alloc(4 + body.length);
  segment[0] = 0xff;
  segment[1] = 0xfe;
  segment.writeUInt16BE(body.length + 2, 2);
  body.copy(segment, 4);
  return Buffer.concat([jpg.subarray(0, 2), segment, jpg.subarray(2)]);
}

export async function png(width: number, height: number): Promise<Buffer> {
  return sharp({ create: { width, height, channels: 4, background: { r: 200, g: 30, b: 60, alpha: 1 } } })
    .png()
    .toBuffer();
}

export async function webp(width: number, height: number): Promise<Buffer> {
  return sharp({ create: { width, height, channels: 3, background: { r: 20, g: 120, b: 200 } } })
    .webp()
    .toBuffer();
}

/** An animated WebP (two frames). */
export async function animatedWebp(width: number, height: number): Promise<Buffer> {
  const frame = width * height * 3;
  const raw = Buffer.alloc(frame * 2);
  raw.fill(200, 0, frame);
  raw.fill(30, frame);
  return sharp(raw, { raw: { width, height: height * 2, channels: 3, pageHeight: height } })
    .webp({ loop: 0 })
    .toBuffer();
}

const CRC_TABLE = (() => {
  const table = new Uint32Array(256);
  for (let n = 0; n < 256; n += 1) {
    let c = n;
    for (let k = 0; k < 8; k += 1) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    table[n] = c >>> 0;
  }
  return table;
})();

function crc32(buf: Buffer): number {
  let c = 0xffffffff;
  for (const byte of buf) c = CRC_TABLE[(c ^ byte) & 0xff]! ^ (c >>> 8);
  return (c ^ 0xffffffff) >>> 0;
}

export function pngChunk(type: string, data: Buffer): Buffer {
  const out = Buffer.alloc(12 + data.length);
  out.writeUInt32BE(data.length, 0);
  out.write(type, 4, 'latin1');
  data.copy(out, 8);
  out.writeUInt32BE(crc32(out.subarray(4, 8 + data.length)), 8 + data.length);
  return out;
}

const PNG_SIGNATURE = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);

/**
 * A decompression bomb: a valid PNG header declaring `width` × `height` (8-bit grey) followed by a
 * tiny compressed IDAT. Only the first `rows` rows are actually encoded, so building it is cheap;
 * the API must refuse it from the header, before any decoder runs.
 */
export function pngBomb(width: number, height: number, rows = 1): Buffer {
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(width, 0);
  ihdr.writeUInt32BE(height, 4);
  ihdr[8] = 8; // bit depth
  ihdr[9] = 0; // greyscale
  const scanlines = Buffer.alloc(rows * (width + 1));
  return Buffer.concat([
    PNG_SIGNATURE,
    pngChunk('IHDR', ihdr),
    pngChunk('IDAT', deflateSync(scanlines, { level: 9 })),
    pngChunk('IEND', Buffer.alloc(0)),
  ]);
}

/** Inserts an `acTL` chunk after IHDR, making a PNG an APNG (animation control). */
export function asApng(pngBytes: Buffer): Buffer {
  const actl = Buffer.alloc(8);
  actl.writeUInt32BE(2, 0); // frames
  actl.writeUInt32BE(0, 4); // plays
  const afterIhdr = 8 + 12 + 13;
  return Buffer.concat([
    pngBytes.subarray(0, afterIhdr),
    pngChunk('acTL', actl),
    pngBytes.subarray(afterIhdr),
  ]);
}

/** Harmless marker text appended to images in polyglot tests. */
export const POLYGLOT_MARKER = 'KABSO_POLYGLOT_MARKER_<script>void 0</script>';

/** An image followed by trailing data (an HTML-ish marker and a ZIP end-of-central-directory). */
export function polyglot(image: Buffer): Buffer {
  const eocd = Buffer.from([0x50, 0x4b, 0x05, 0x06, ...new Array<number>(18).fill(0)]);
  return Buffer.concat([image, Buffer.from(POLYGLOT_MARKER, 'latin1'), eocd]);
}

/** A few bytes of other formats that must be refused. */
export const OTHER_FORMATS: Readonly<Record<string, Buffer>> = {
  gif: Buffer.concat([Buffer.from('GIF89a', 'latin1'), Buffer.alloc(32)]),
  svg: Buffer.from('<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10"/>', 'utf8'),
  heic: Buffer.concat([Buffer.from([0, 0, 0, 0x18]), Buffer.from('ftypheic', 'latin1'), Buffer.alloc(32)]),
  avif: Buffer.concat([Buffer.from([0, 0, 0, 0x18]), Buffer.from('ftypavif', 'latin1'), Buffer.alloc(32)]),
  bmp: Buffer.concat([Buffer.from('BM', 'latin1'), Buffer.alloc(52)]),
  tiff: Buffer.concat([Buffer.from([0x49, 0x49, 0x2a, 0x00]), Buffer.alloc(32)]),
  html: Buffer.from('<!doctype html><title>x</title>', 'utf8'),
};
