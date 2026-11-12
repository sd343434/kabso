import { describe, expect, it } from 'vitest';
import { m4a } from '../../../test/helpers/m4a.js';
import {
  DEFAULT_VOICE_LIMITS,
  InvalidAudioError,
  MAX_ANY_VOICE_BYTES,
  MAX_VOICE_BYTES,
  verifyVoiceClip,
  voiceLimitsFor,
} from './media-audio.js';

describe('voice clips (CP-017, CONVENTIONS §11.1)', () => {
  it('reads the length from the movie header (versions 0 and 1)', () => {
    expect(verifyVoiceClip(m4a({ durationMs: 12_345 }))).toEqual({ durationMs: 12_345 });
    expect(verifyVoiceClip(m4a({ durationMs: 30_000, mvhdVersion: 1 }))).toEqual({ durationMs: 30_000 });
    expect(verifyVoiceClip(m4a({ durationMs: 1 }))).toEqual({ durationMs: 1 });
  });

  it('accepts encoder padding up to 30.5 s and reports it as 30 s', () => {
    expect(verifyVoiceClip(m4a({ durationMs: 30_500 }))).toEqual({ durationMs: 30_000 });
  });

  it.each([
    ['longer than 30 s', m4a({ durationMs: 30_501 })],
    ['31 s (version 1)', m4a({ durationMs: 31_000, mvhdVersion: 1 })],
    ['no duration', m4a({ durationMs: 0 })],
    ['a video track', m4a({ durationMs: 5_000, handlers: ['soun', 'vide'] })],
    ['no track', m4a({ durationMs: 5_000, handlers: [] })],
    ['not MPEG-4', Buffer.from('ID3\u0004\u0000\u0000\u0000\u0000\u0000\u0000mp3 bytes', 'latin1')],
    ['a JPEG', Buffer.from([0xff, 0xd8, 0xff, 0xe0, 0, 0x10, 0x4a, 0x46, 0x49, 0x46])],
    ['truncated', m4a({ durationMs: 5_000 }).subarray(0, 60)],
    ['over 1 MiB', m4a({ durationMs: 5_000, dataBytes: MAX_VOICE_BYTES })],
  ])('refuses %s', (_name, bytes) => {
    expect(() => verifyVoiceClip(bytes)).toThrow(InvalidAudioError);
  });

  it('refuses a box that claims more bytes than the file has', () => {
    const bytes = Buffer.from(m4a({ durationMs: 5_000 }));
    bytes.writeUInt32BE(0x7fffffff, 0);
    expect(() => verifyVoiceClip(bytes)).toThrow(InvalidAudioError);
  });
});

describe('LONGER_VOICE limits (v1.134-social, D381, §10.171.8)', () => {
  it('everyone else keeps 30 s and 1 MiB; a holder gets the perk seconds and a size scaled with them', () => {
    expect(voiceLimitsFor(null)).toEqual(DEFAULT_VOICE_LIMITS);
    expect(voiceLimitsFor(20)).toEqual(DEFAULT_VOICE_LIMITS);
    expect(voiceLimitsFor(30)).toEqual(DEFAULT_VOICE_LIMITS);
    expect(voiceLimitsFor(180)).toEqual({ maxMs: 180_000, maxBytes: MAX_VOICE_BYTES * 6 });
    // Never above the catalogue's largest value.
    expect(voiceLimitsFor(9_999).maxMs).toBe(600_000);
    expect(MAX_ANY_VOICE_BYTES).toBe(MAX_VOICE_BYTES * 20);
  });

  it("a holder's clip is accepted up to its limit (plus the encoder padding), longer ones refused", () => {
    const limits = voiceLimitsFor(180);
    expect(verifyVoiceClip(m4a({ durationMs: 120_000 }), limits)).toEqual({ durationMs: 120_000 });
    expect(verifyVoiceClip(m4a({ durationMs: 180_400 }), limits)).toEqual({ durationMs: 180_000 });
    expect(() => verifyVoiceClip(m4a({ durationMs: 180_501 }), limits)).toThrow(InvalidAudioError);
    // The same 2-minute clip from a non-holder is refused.
    expect(() => verifyVoiceClip(m4a({ durationMs: 120_000 }))).toThrow(InvalidAudioError);
  });
});
