/**
 * Videos of posts and reels (v1.41-social, D162, CP-023, CONVENTIONS §11.14): MP4 or QuickTime,
 * checked without decoding and stored unchanged (no server-side transcoding yet). The server reads
 * only the container: the top-level boxes (each header fetched with a ranged read, so a 200 MiB
 * file is never loaded), `ftyp` for the brand, and the `moov` box (≤ 16 MiB) for the length
 * (`mvhd`), the video track's codec (`stsd`) and its display size (`tkhd`, rotation applied).
 */

/** Content types accepted for `POST_VIDEO` and `REEL_VIDEO` uploads. */
export const VIDEO_CONTENT_TYPES = ['video/mp4', 'video/quicktime'] as const;
export type VideoContentType = (typeof VIDEO_CONTENT_TYPES)[number];

export type VideoKind = 'POST_VIDEO' | 'REEL_VIDEO';

/**
 * Server-enforced limits per kind (owner D162: reels 100 MiB / 60 s, post videos 200 MiB; owner D168:
 * post videos at most 90 s, was 3 min). Post videos stored before D168 keep their length (≤ 180 s).
 */
export const VIDEO_LIMITS: Readonly<Record<VideoKind, { maxBytes: number; maxDurationMs: number }>> = {
  POST_VIDEO: { maxBytes: 200 * 1024 * 1024, maxDurationMs: 90_000 },
  REEL_VIDEO: { maxBytes: 100 * 1024 * 1024, maxDurationMs: 60_000 },
};
/** The largest upload of any kind (`CreateMediaUploadRequest.byteSize` maximum). */
export const MAX_VIDEO_BYTES = VIDEO_LIMITS.POST_VIDEO.maxBytes;
export const MIN_VIDEO_DURATION_MS = 1_000;
/** Encoder padding accepted past the maximum, reported clipped to it (as voice clips, CP-017). */
export const VIDEO_DURATION_TOLERANCE_MS = 500;
export const MIN_VIDEO_SIDE = 16;
export const MAX_VIDEO_SIDE = 4096;
/** The largest `moov` box read (a few-minute phone video's is a few hundred KiB). */
export const MAX_MOOV_BYTES = 16 * 1024 * 1024;
/** Sample entries of the video track that phones play natively (H.264 and HEVC). */
export const VIDEO_CODECS = ['avc1', 'avc3', 'hvc1', 'hev1'] as const;
const MAX_TOP_LEVEL_BOXES = 64;

/** Why an upload is not an acceptable video (never shown to clients; they get MEDIA_INVALID). */
export class InvalidVideoError extends Error {}

export function isVideoKind(kind: string): kind is VideoKind {
  return kind === 'POST_VIDEO' || kind === 'REEL_VIDEO';
}

/** Reads `length` bytes at `offset` of the stored object (fewer at its end; null when missing). */
export type RangeReader = (offset: number, length: number) => Promise<Buffer | null>;

export interface VideoInfo {
  readonly width: number;
  readonly height: number;
  readonly durationMs: number;
  readonly codec: string;
}

interface Box {
  readonly type: string;
  /** Payload start (after the header). */
  readonly start: number;
  /** Payload end (exclusive). */
  readonly end: number;
}

const BOX_TYPE = /^[\x20-\x7e]{4}$/;

/** The boxes directly inside `bytes[start, end)`; throws on a box that does not fit. */
function boxes(bytes: Buffer, start: number, end: number): Box[] {
  const result: Box[] = [];
  let at = start;
  while (at < end) {
    if (end - at < 8) throw new InvalidVideoError('truncated box header');
    let size = bytes.readUInt32BE(at);
    const type = bytes.toString('latin1', at + 4, at + 8);
    let header = 8;
    if (size === 1) {
      if (end - at < 16) throw new InvalidVideoError('truncated box header');
      const large = bytes.readBigUInt64BE(at + 8);
      if (large > BigInt(end - at)) throw new InvalidVideoError('box out of range');
      size = Number(large);
      header = 16;
    } else if (size === 0) {
      size = end - at;
    }
    if (size < header || at + size > end) throw new InvalidVideoError('box out of range');
    result.push({ type, start: at + header, end: at + size });
    at += size;
    if (result.length > 10_000) throw new InvalidVideoError('too many boxes');
  }
  return result;
}

function child(bytes: Buffer, parent: Box, type: string): Box | undefined {
  return boxes(bytes, parent.start, parent.end).find((b) => b.type === type);
}

/** The movie length in milliseconds from `mvhd` (version 0 or 1), rounded up. */
function movieDurationMs(bytes: Buffer, mvhd: Box): number {
  const version = bytes[mvhd.start];
  let timescale: number;
  let duration: bigint;
  if (version === 0) {
    if (mvhd.end - mvhd.start < 20) throw new InvalidVideoError('short mvhd');
    timescale = bytes.readUInt32BE(mvhd.start + 12);
    const raw = bytes.readUInt32BE(mvhd.start + 16);
    if (raw === 0xffffffff) throw new InvalidVideoError('unknown duration');
    duration = BigInt(raw);
  } else if (version === 1) {
    if (mvhd.end - mvhd.start < 32) throw new InvalidVideoError('short mvhd');
    timescale = bytes.readUInt32BE(mvhd.start + 20);
    duration = bytes.readBigUInt64BE(mvhd.start + 24);
    if (duration === 0xffffffffffffffffn) throw new InvalidVideoError('unknown duration');
  } else {
    throw new InvalidVideoError('unknown mvhd version');
  }
  if (timescale === 0 || duration === 0n) throw new InvalidVideoError('no duration');
  const ms = (duration * 1000n + BigInt(timescale) - 1n) / BigInt(timescale);
  return ms > 86_400_000n ? 86_400_000 : Number(ms);
}

/** Width and height shown on screen from `tkhd` (16.16 fixed point; a 90°/270° matrix swaps). */
function displaySize(bytes: Buffer, tkhd: Box): { width: number; height: number } {
  const version = bytes[tkhd.start];
  const matrixAt = tkhd.start + (version === 1 ? 52 : 40);
  const sizeAt = matrixAt + 36;
  if (version !== 0 && version !== 1) throw new InvalidVideoError('unknown tkhd version');
  if (sizeAt + 8 > tkhd.end) throw new InvalidVideoError('short tkhd');
  const a = bytes.readInt32BE(matrixAt);
  const d = bytes.readInt32BE(matrixAt + 16);
  const width = Math.round(bytes.readUInt32BE(sizeAt) / 65536);
  const height = Math.round(bytes.readUInt32BE(sizeAt + 4) / 65536);
  return a === 0 && d === 0 ? { width: height, height: width } : { width, height };
}

/** The first sample entry's type of a track (`mdia/minf/stbl/stsd`). */
function sampleEntry(bytes: Buffer, mdia: Box): string | undefined {
  const minf = child(bytes, mdia, 'minf');
  const stbl = minf ? child(bytes, minf, 'stbl') : undefined;
  const stsd = stbl ? child(bytes, stbl, 'stsd') : undefined;
  if (!stsd || stsd.end - stsd.start < 16) return undefined;
  if (bytes.readUInt32BE(stsd.start + 4) < 1) return undefined;
  return bytes.toString('latin1', stsd.start + 12, stsd.start + 16);
}

/**
 * Parses a `moov` payload (the whole box, header included): the length and the first video
 * track's codec and display size. Exported for unit tests.
 */
export function parseMoov(moovBox: Buffer): {
  durationMs: number;
  width: number;
  height: number;
  codec: string;
} {
  const [moov] = boxes(moovBox, 0, moovBox.length);
  if (moov?.type !== 'moov') throw new InvalidVideoError('not a moov box');
  const inside = boxes(moovBox, moov.start, moov.end);
  const mvhd = inside.find((b) => b.type === 'mvhd');
  if (!mvhd) throw new InvalidVideoError('no mvhd');
  const durationMs = movieDurationMs(moovBox, mvhd);
  for (const trak of inside.filter((b) => b.type === 'trak')) {
    const mdia = child(moovBox, trak, 'mdia');
    const hdlr = mdia ? child(moovBox, mdia, 'hdlr') : undefined;
    if (!mdia || !hdlr || hdlr.end - hdlr.start < 12) continue;
    if (moovBox.toString('latin1', hdlr.start + 8, hdlr.start + 12) !== 'vide') continue;
    const tkhd = child(moovBox, trak, 'tkhd');
    if (!tkhd) throw new InvalidVideoError('no tkhd');
    const codec = sampleEntry(moovBox, mdia);
    if (!codec || !(VIDEO_CODECS as readonly string[]).includes(codec)) {
      throw new InvalidVideoError(`video codec ${String(codec)}`);
    }
    return { durationMs, codec, ...displaySize(moovBox, tkhd) };
  }
  throw new InvalidVideoError('no video track');
}

/**
 * Checks a stored video of `size` bytes declared as `contentType` for `kind` and returns its
 * display size, length (clipped to the kind's maximum) and codec. Throws
 * {@link InvalidVideoError} for anything that is not an acceptable MP4 / QuickTime video.
 */
export async function inspectVideo(
  read: RangeReader,
  size: number,
  contentType: VideoContentType,
  kind: VideoKind,
): Promise<VideoInfo> {
  const limits = VIDEO_LIMITS[kind];
  if (size > limits.maxBytes) throw new InvalidVideoError('too large');
  if (size < 16) throw new InvalidVideoError('too small');
  // Walk the top-level boxes by their headers.
  const top: { type: string; at: number; size: number }[] = [];
  let at = 0;
  while (at < size) {
    if (top.length >= MAX_TOP_LEVEL_BOXES) throw new InvalidVideoError('too many top-level boxes');
    const header = await read(at, Math.min(16, size - at));
    if (!header || header.length < 8) throw new InvalidVideoError('truncated box header');
    let boxSize = header.readUInt32BE(0);
    const type = header.toString('latin1', 4, 8);
    if (!BOX_TYPE.test(type)) throw new InvalidVideoError('not a box');
    if (boxSize === 1) {
      if (header.length < 16) throw new InvalidVideoError('truncated box header');
      const large = header.readBigUInt64BE(8);
      if (large > BigInt(size - at)) throw new InvalidVideoError('box out of range');
      boxSize = Number(large);
      if (boxSize < 16) throw new InvalidVideoError('box out of range');
    } else if (boxSize === 0) {
      boxSize = size - at;
    } else if (boxSize < 8) {
      throw new InvalidVideoError('box out of range');
    }
    if (at + boxSize > size) throw new InvalidVideoError('box out of range');
    top.push({ type, at, size: boxSize });
    at += boxSize;
  }
  if (top[0]?.type !== 'ftyp') throw new InvalidVideoError('not an MPEG-4 / QuickTime file');
  const ftyp = await read(0, Math.min(top[0].size, 64));
  if (!ftyp || ftyp.length < 12) throw new InvalidVideoError('short ftyp');
  const brand = ftyp.toString('latin1', 8, 12);
  if ((brand === 'qt  ') !== (contentType === 'video/quicktime')) {
    throw new InvalidVideoError(`brand ${brand} is not ${contentType}`);
  }
  if (!top.some((b) => b.type === 'mdat')) throw new InvalidVideoError('no mdat');
  const moovs = top.filter((b) => b.type === 'moov');
  if (moovs.length !== 1) throw new InvalidVideoError('not exactly one moov');
  const moov = moovs[0]!;
  if (moov.size > MAX_MOOV_BYTES) throw new InvalidVideoError('moov too large');
  const moovBytes = await read(moov.at, moov.size);
  if (!moovBytes || moovBytes.length !== moov.size) throw new InvalidVideoError('moov unreadable');
  const parsed = parseMoov(moovBytes);
  if (parsed.durationMs < MIN_VIDEO_DURATION_MS) throw new InvalidVideoError('shorter than 1 s');
  if (parsed.durationMs > limits.maxDurationMs + VIDEO_DURATION_TOLERANCE_MS) {
    throw new InvalidVideoError(`${String(parsed.durationMs)} ms is too long for ${kind}`);
  }
  for (const side of [parsed.width, parsed.height]) {
    if (side < MIN_VIDEO_SIDE || side > MAX_VIDEO_SIDE) throw new InvalidVideoError(`side ${String(side)}`);
  }
  return {
    width: parsed.width,
    height: parsed.height,
    durationMs: Math.min(parsed.durationMs, limits.maxDurationMs),
    codec: parsed.codec,
  };
}
