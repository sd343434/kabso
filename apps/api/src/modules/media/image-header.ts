import type { MediaContentType } from './media.constants.js';

/**
 * Header-only inspection of an uploaded image (CONVENTIONS §11.2, §11.11): the real type from the
 * magic bytes, and width / height / animation read from the container header WITHOUT decoding any
 * pixel data. Pure JavaScript over a Buffer, bounded loops, no decoder involved, so a hostile file
 * cannot reach libvips before its dimensions have been checked against the limits.
 */

/** Magic bytes (CONVENTIONS §11.11): JPEG `FF D8 FF`, PNG `89 50 4E 47 0D 0A 1A 0A`, WebP `RIFF....WEBP`. */
export function detectContentType(buf: Buffer): MediaContentType | null {
  if (buf.length >= 3 && buf[0] === 0xff && buf[1] === 0xd8 && buf[2] === 0xff) return 'image/jpeg';
  if (buf.length >= 8 && buf.subarray(0, 8).equals(PNG_SIGNATURE)) return 'image/png';
  if (
    buf.length >= 12 &&
    buf.toString('latin1', 0, 4) === 'RIFF' &&
    buf.toString('latin1', 8, 12) === 'WEBP'
  ) {
    return 'image/webp';
  }
  return null;
}

const PNG_SIGNATURE = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);

export interface ImageHeader {
  readonly width: number;
  readonly height: number;
  readonly animated: boolean;
}

/** Upper bound on container records (JPEG segments, PNG chunks, WebP chunks) walked per file. */
const MAX_RECORDS = 4096;

function jpegHeader(buf: Buffer): ImageHeader | null {
  let i = 2;
  for (let records = 0; records < MAX_RECORDS && i + 4 <= buf.length; records += 1) {
    if (buf[i] !== 0xff) return null;
    // Fill bytes: any number of 0xFF before the marker code.
    while (i < buf.length && buf[i] === 0xff) i += 1;
    if (i >= buf.length) return null;
    const marker = buf[i]!;
    i += 1;
    // Standalone markers without a length.
    if (marker === 0x01 || (marker >= 0xd0 && marker <= 0xd8)) continue;
    if (marker === 0xd9 || marker === 0xda) return null; // EOI / SOS before any frame header
    if (i + 2 > buf.length) return null;
    const length = buf.readUInt16BE(i);
    if (length < 2) return null;
    const isFrame = marker >= 0xc0 && marker <= 0xcf && marker !== 0xc4 && marker !== 0xc8 && marker !== 0xcc;
    if (isFrame) {
      if (i + 7 > buf.length) return null;
      const height = buf.readUInt16BE(i + 3);
      const width = buf.readUInt16BE(i + 5);
      return { width, height, animated: false };
    }
    i += length;
  }
  return null;
}

function pngHeader(buf: Buffer): ImageHeader | null {
  // IHDR must be the first chunk.
  if (buf.length < 33 || buf.toString('latin1', 12, 16) !== 'IHDR' || buf.readUInt32BE(8) !== 13) return null;
  const width = buf.readUInt32BE(16);
  const height = buf.readUInt32BE(20);
  // APNG: an acTL chunk before the first IDAT.
  let animated = false;
  let i = 8;
  for (let records = 0; records < MAX_RECORDS && i + 8 <= buf.length; records += 1) {
    const length = buf.readUInt32BE(i);
    const type = buf.toString('latin1', i + 4, i + 8);
    if (type === 'acTL') {
      animated = true;
      break;
    }
    if (type === 'IDAT' || type === 'IEND') break;
    const next = i + 12 + length;
    if (next <= i) return null;
    i = next;
  }
  return { width, height, animated };
}

function webpHeader(buf: Buffer): ImageHeader | null {
  if (buf.length < 30) return null;
  const first = buf.toString('latin1', 12, 16);
  if (first === 'VP8 ') {
    // Lossy: frame tag (3 bytes) then the start code 9D 01 2A, then 14-bit width and height.
    if (buf[23] !== 0x9d || buf[24] !== 0x01 || buf[25] !== 0x2a) return null;
    return { width: buf.readUInt16LE(26) & 0x3fff, height: buf.readUInt16LE(28) & 0x3fff, animated: false };
  }
  if (first === 'VP8L') {
    if (buf[20] !== 0x2f) return null;
    const bits = buf.readUInt32LE(21);
    return { width: (bits & 0x3fff) + 1, height: ((bits >>> 14) & 0x3fff) + 1, animated: false };
  }
  if (first === 'VP8X') {
    const flags = buf[20]!;
    const width = buf.readUIntLE(24, 3) + 1;
    const height = buf.readUIntLE(27, 3) + 1;
    let animated = (flags & 0x02) !== 0;
    // Also look for ANIM / ANMF chunks whatever the flag says.
    let i = 12;
    for (let records = 0; !animated && records < MAX_RECORDS && i + 8 <= buf.length; records += 1) {
      const type = buf.toString('latin1', i, i + 4);
      const size = buf.readUInt32LE(i + 4);
      if (type === 'ANIM' || type === 'ANMF') animated = true;
      const next = i + 8 + size + (size & 1);
      if (next <= i) return null;
      i = next;
    }
    return { width, height, animated };
  }
  return null;
}

/**
 * Dimensions and animation flag from the header of a file of the given (detected) type, or null
 * when the header is truncated or malformed (→ `invalid_format`).
 */
export function readImageHeader(buf: Buffer, type: MediaContentType): ImageHeader | null {
  const header =
    type === 'image/jpeg' ? jpegHeader(buf) : type === 'image/png' ? pngHeader(buf) : webpHeader(buf);
  if (!header || header.width < 1 || header.height < 1) return null;
  return header;
}
