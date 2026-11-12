/**
 * Voice clips of the live chat (CP-017, D104, CONVENTIONS §11.1, §10.19): AAC in an MPEG-4
 * container (`.m4a`, `audio/mp4`), at most 30 s and 1 MiB. The server reads the container — the
 * `ftyp` box first, the movie header (`moov/mvhd`) for the length, and every track's handler
 * (`moov/trak/mdia/hdlr`), which must all be sound — and stores the bytes unchanged. It does not
 * decode the audio.
 */

/** Content types accepted for a `LIVE_CHAT_VOICE` upload. */
export const AUDIO_CONTENT_TYPES = ['audio/mp4'] as const;
export type AudioContentType = (typeof AUDIO_CONTENT_TYPES)[number];

/** Largest voice clip (1 MiB: 30 s of AAC at 128 kbit/s with room to spare). */
export const MAX_VOICE_BYTES = 1024 * 1024;
/** Longest voice clip (owner D104). */
export const MAX_VOICE_DURATION_MS = 30_000;
/**
 * Encoders pad a clip (AAC priming and the last frame), so a recording stopped at 30 s may read a
 * little longer in its container. Up to this much more is accepted and reported as 30 000 ms.
 */
export const VOICE_DURATION_TOLERANCE_MS = 500;

/** A voice clip's limits: its longest length and largest size. */
export interface VoiceLimits {
  readonly maxMs: number;
  readonly maxBytes: number;
}

/** Everyone's limits (30 s, 1 MiB). */
export const DEFAULT_VOICE_LIMITS: VoiceLimits = { maxMs: MAX_VOICE_DURATION_MS, maxBytes: MAX_VOICE_BYTES };

/** v1.134-social (D381): LONGER_VOICE's largest value (the catalogue's `int` 31–600 s). */
export const MAX_VIP_VOICE_SECONDS = 600;

/**
 * v1.134-social (D381, §10.171.8) LONGER_VOICE: the limits of a holder of [seconds] (null: not held → the defaults) —
 * that length, and the size scaled from 1 MiB per 30 s (the same bit rate with room to spare).
 */
export function voiceLimitsFor(seconds: number | null): VoiceLimits {
  if (seconds === null || seconds * 1000 <= MAX_VOICE_DURATION_MS) return DEFAULT_VOICE_LIMITS;
  const s = Math.min(seconds, MAX_VIP_VOICE_SECONDS);
  return { maxMs: s * 1000, maxBytes: Math.ceil((MAX_VOICE_BYTES * s * 1000) / MAX_VOICE_DURATION_MS) };
}

/** The largest voice upload anyone may request (a 600 s holder's): the request's first bound. */
export const MAX_ANY_VOICE_BYTES = voiceLimitsFor(MAX_VIP_VOICE_SECONDS).maxBytes;

/** Why an upload is not an acceptable voice clip (clients get MEDIA_INVALID). */
export class InvalidAudioError extends Error {}

interface Box {
  readonly type: string;
  /** Payload start (after the header). */
  readonly start: number;
  /** Payload end (exclusive). */
  readonly end: number;
}

/** The boxes directly inside `[start, end)`; throws on a box that does not fit. */
function boxes(bytes: Buffer, start: number, end: number): Box[] {
  const result: Box[] = [];
  let at = start;
  while (at < end) {
    if (end - at < 8) throw new InvalidAudioError('truncated box header');
    let size = bytes.readUInt32BE(at);
    const type = bytes.toString('latin1', at + 4, at + 8);
    let header = 8;
    if (size === 1) {
      if (end - at < 16) throw new InvalidAudioError('truncated box header');
      const large = bytes.readBigUInt64BE(at + 8);
      if (large > BigInt(end - at)) throw new InvalidAudioError('box out of range');
      size = Number(large);
      header = 16;
    } else if (size === 0) {
      size = end - at;
    }
    if (size < header || at + size > end) throw new InvalidAudioError('box out of range');
    result.push({ type, start: at + header, end: at + size });
    at += size;
    if (result.length > 10_000) throw new InvalidAudioError('too many boxes');
  }
  return result;
}

function child(bytes: Buffer, parent: Box, type: string): Box | undefined {
  return boxes(bytes, parent.start, parent.end).find((b) => b.type === type);
}

/** The movie length in milliseconds from `mvhd` (version 0 or 1). */
function movieDurationMs(bytes: Buffer, mvhd: Box): number {
  const version = bytes[mvhd.start];
  let timescale: number;
  let duration: bigint;
  if (version === 0) {
    if (mvhd.end - mvhd.start < 20) throw new InvalidAudioError('short mvhd');
    timescale = bytes.readUInt32BE(mvhd.start + 12);
    const raw = bytes.readUInt32BE(mvhd.start + 16);
    if (raw === 0xffffffff) throw new InvalidAudioError('unknown duration');
    duration = BigInt(raw);
  } else if (version === 1) {
    if (mvhd.end - mvhd.start < 32) throw new InvalidAudioError('short mvhd');
    timescale = bytes.readUInt32BE(mvhd.start + 20);
    duration = bytes.readBigUInt64BE(mvhd.start + 24);
    if (duration === 0xffffffffffffffffn) throw new InvalidAudioError('unknown duration');
  } else {
    throw new InvalidAudioError('unknown mvhd version');
  }
  if (timescale === 0 || duration === 0n) throw new InvalidAudioError('no duration');
  return Number((duration * 1000n + BigInt(timescale) - 1n) / BigInt(timescale));
}

/**
 * Checks a voice clip and returns its length in ms (at most {@link MAX_VOICE_DURATION_MS}).
 * Throws {@link InvalidAudioError} for anything that is not an MPEG-4 audio file of at most
 * 30 s (plus {@link VOICE_DURATION_TOLERANCE_MS}) whose tracks are all sound tracks.
 */
export function verifyVoiceClip(
  bytes: Buffer,
  limits: VoiceLimits = DEFAULT_VOICE_LIMITS,
): { durationMs: number } {
  if (bytes.length > limits.maxBytes) throw new InvalidAudioError('too large');
  const top = boxes(bytes, 0, bytes.length);
  if (top[0]?.type !== 'ftyp') throw new InvalidAudioError('not an MPEG-4 file');
  const moov = top.find((b) => b.type === 'moov');
  if (!moov) throw new InvalidAudioError('no moov');
  const inside = boxes(bytes, moov.start, moov.end);
  const mvhd = inside.find((b) => b.type === 'mvhd');
  if (!mvhd) throw new InvalidAudioError('no mvhd');
  const traks = inside.filter((b) => b.type === 'trak');
  if (traks.length === 0) throw new InvalidAudioError('no track');
  for (const trak of traks) {
    const mdia = child(bytes, trak, 'mdia');
    const hdlr = mdia ? child(bytes, mdia, 'hdlr') : undefined;
    if (!hdlr || hdlr.end - hdlr.start < 12) throw new InvalidAudioError('no handler');
    const handler = bytes.toString('latin1', hdlr.start + 8, hdlr.start + 12);
    if (handler !== 'soun') throw new InvalidAudioError(`a ${handler} track`);
  }
  const durationMs = movieDurationMs(bytes, mvhd);
  if (durationMs > limits.maxMs + VOICE_DURATION_TOLERANCE_MS) {
    throw new InvalidAudioError(`${String(durationMs)} ms is longer than ${String(limits.maxMs / 1000)} s`);
  }
  return { durationMs: Math.min(durationMs, limits.maxMs) };
}
