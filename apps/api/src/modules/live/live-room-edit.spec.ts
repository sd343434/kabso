import { describe, expect, it } from 'vitest';
import { zodErrorToDetails } from '../../common/validation/zod-validation.pipe.js';
import { roomMetadataJson } from './live-metadata.service.js';
import { LIVE_CONTRIBUTORS_MAX } from './live-taps.js';
import { normalizeLiveTopic, updateLiveRoomSchema } from './live.schemas.js';

/** Builds strings from code points, so invisible characters stay visible in this file. */
const cp = (...points: number[]) => String.fromCodePoint(...points);
const ACUTE = cp(0x301);
const ZWJ = cp(0x200d);

describe('CP-014 live topic (CONVENTIONS §10.12)', () => {
  it.each([
    ['سهرة طرب', 'سهرة طرب'],
    ['  Music night  ', 'Music night'],
    [`${cp(0xfeff)}hi${cp(0x3000)}`, 'hi'],
    ['a', 'a'],
    ['x'.repeat(100), 'x'.repeat(100)],
    [cp(0x1f44d, 0x1f3fd).repeat(50), cp(0x1f44d, 0x1f3fd).repeat(50)], // 100 code points
    [`e${ACUTE.repeat(3)}`, `é${ACUTE.repeat(2)}`], // NFC; 3 marks allowed
    [`${cp(0x1f468)}${ZWJ}${cp(0x1f469)}`, `${cp(0x1f468)}${ZWJ}${cp(0x1f469)}`],
  ])('accepts %j', (raw, value) => {
    expect(normalizeLiveTopic(raw)).toEqual({ value });
  });

  it.each(['', '   ', cp(0x3000, 0xfeff)])('%j (empty after trimming) removes the topic', (raw) => {
    expect(normalizeLiveTopic(raw)).toEqual({ value: null });
  });

  it.each([
    ['x'.repeat(101), 'too_long'],
    [cp(0x1f44d, 0x1f3fd).repeat(50) + 'a', 'too_long'],
    ['one\ntwo', 'invalid_format'],
    ['one\rtwo', 'invalid_format'],
    ['one\r\ntwo', 'invalid_format'],
    [`one${cp(0x2028)}two`, 'invalid_format'],
    [`one${cp(0x2029)}two`, 'invalid_format'],
    ['hi\n', 'invalid_format'], // a trailing line break is not trimmed
    [`a${cp(0x202e)}b`, 'invalid_format'], // bidi override
    [`a${cp(0x200b)}b`, 'invalid_format'], // zero-width space
    [`a${cp(0x7)}b`, 'invalid_format'], // control
    [`${ZWJ}a`, 'invalid_format'], // misplaced joiner
    [`e${ACUTE.repeat(4)}`, 'invalid_format'], // zalgo cap
  ])('refuses %j → %s', (raw, issue) => {
    expect(normalizeLiveTopic(raw)).toEqual({ issue });
  });
});

describe('CP-014 UpdateLiveRoomRequest: title, categorySlug, topic', () => {
  const issues = (body: unknown) => {
    const parsed = updateLiveRoomSchema.safeParse(body, { reportInput: true });
    return parsed.success ? [] : zodErrorToDetails(parsed.error);
  };

  it('accepts each field alone and normalizes them', () => {
    expect(updateLiveRoomSchema.parse({ title: '  Night  ' })).toEqual({ title: 'Night' });
    expect(updateLiveRoomSchema.parse({ categorySlug: 'music' })).toEqual({ categorySlug: 'music' });
    expect(updateLiveRoomSchema.parse({ categorySlug: null })).toEqual({ categorySlug: null });
    expect(updateLiveRoomSchema.parse({ topic: ' Talk ' })).toEqual({ topic: 'Talk' });
    expect(updateLiveRoomSchema.parse({ topic: null })).toEqual({ topic: null });
    expect(updateLiveRoomSchema.parse({ topic: '  ' })).toEqual({ topic: null });
  });

  it('uses the go-live title rules', () => {
    expect(issues({ title: '' })).toEqual([{ field: 'title', issue: 'too_short' }]);
    expect(issues({ title: '   ' })).toEqual([{ field: 'title', issue: 'invalid_format' }]);
    expect(issues({ title: 'x'.repeat(81) })).toEqual([{ field: 'title', issue: 'too_long' }]);
    expect(issues({ title: `a${cp(0x202e)}b` })).toEqual([{ field: 'title', issue: 'invalid_format' }]);
    expect(issues({ title: null })).toEqual([{ field: 'title', issue: 'invalid_type' }]);
  });

  it('a malformed category slug is a format error; the topic issues carry the field', () => {
    expect(issues({ categorySlug: 'Music!' })).toEqual([{ field: 'categorySlug', issue: 'invalid_format' }]);
    expect(issues({ topic: 'x'.repeat(101) })).toEqual([{ field: 'topic', issue: 'too_long' }]);
    expect(issues({ topic: 'a\nb' })).toEqual([{ field: 'topic', issue: 'invalid_format' }]);
    expect(issues({ topic: 'x'.repeat(801) })).toEqual([{ field: 'topic', issue: 'too_long' }]);
    expect(issues({ topic: 5 })).toEqual([{ field: 'topic', issue: 'invalid_type' }]);
  });
});

describe('CP-014 room metadata: roomInfoVersion next to seatsVersion and score', () => {
  it('is left out until the live is edited (a missing key reads as 0), then carried with the others', () => {
    expect(roomMetadataJson(3, 1234)).toBe('{"seatsVersion":3,"score":1234}');
    expect(roomMetadataJson(3, 1234, 0)).toBe('{"seatsVersion":3,"score":1234}');
    expect(JSON.parse(roomMetadataJson(0, 5, 2))).toEqual({ seatsVersion: 0, score: 5, roomInfoVersion: 2 });
  });

  it('the Contribution list holds at most 50 people', () => {
    expect(LIVE_CONTRIBUTORS_MAX).toBe(50);
  });
});
