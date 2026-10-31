/**
 * Builds minimal MP3 files for tests (v1.46-live, D207): MPEG-1 Layer III frame headers at 128 kbit/s, 44.1 kHz
 * (417 bytes, 1152 samples ≈ 26.1 ms each) with zero payload, optionally after an ID3v2 tag. Enough for the server's
 * frame walk (it never decodes the audio).
 */
const FRAME_BYTES = 417;
const FRAME_MS = (1152 / 44_100) * 1000;

export interface Mp3Options {
  readonly durationMs: number;
  /** An ID3v2 tag of this many bytes first. */
  readonly id3Bytes?: number;
  /** Bytes of junk after the last frame. */
  readonly trailingBytes?: number;
}

export function mp3(options: Mp3Options): Buffer {
  const frames = Math.max(1, Math.round(options.durationMs / FRAME_MS));
  const frame = Buffer.alloc(FRAME_BYTES);
  frame.set([0xff, 0xfb, 0x90, 0x00]);
  const parts: Buffer[] = [];
  if (options.id3Bytes) {
    const size = options.id3Bytes;
    const header = Buffer.from([
      0x49,
      0x44,
      0x33,
      4,
      0,
      0,
      (size >> 21) & 0x7f,
      (size >> 14) & 0x7f,
      (size >> 7) & 0x7f,
      size & 0x7f,
    ]);
    parts.push(header, Buffer.alloc(size));
  }
  for (let i = 0; i < frames; i += 1) parts.push(frame);
  if (options.trailingBytes) parts.push(Buffer.alloc(options.trailingBytes, 0x55));
  return Buffer.concat(parts);
}
