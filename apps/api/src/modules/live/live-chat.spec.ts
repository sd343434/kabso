import { describe, expect, it } from 'vitest';
import { zodErrorToDetails } from '../../common/validation/zod-validation.pipe.js';
import {
  liveBulletSendSchema,
  normalizeLiveChatText,
  parseLiveChatSend,
  updateLiveRoomSchema,
} from './live.schemas.js';

/** Builds strings from code points, so invisible characters stay visible in this file. */
const cp = (...points: number[]) => String.fromCodePoint(...points);
const ACUTE = cp(0x301);
const ZWJ = cp(0x200d);
const CLIENT_ID = '0192f1d0-0000-7000-8000-0000000000aa';
const MEDIA_ID = '0192f1d0-0000-7000-8000-0000000000bb';

describe('live chat text (CONVENTIONS §10.11)', () => {
  it.each([
    ['مرحبا 👋', 'مرحبا 👋'],
    ['  hello  ', 'hello'],
    [`${cp(0xfeff)}hi${cp(0x3000)}`, 'hi'],
    ['a', 'a'],
    ['x'.repeat(200), 'x'.repeat(200)],
    [cp(0x1f44d, 0x1f3fd).repeat(100), cp(0x1f44d, 0x1f3fd).repeat(100)], // 200 code points
    [`@someone https://example.com`, `@someone https://example.com`], // plain text
    [`e${ACUTE.repeat(3)}`, `é${ACUTE.repeat(2)}`], // NFC; 3 marks allowed
    [`${cp(0x1f468)}${ZWJ}${cp(0x1f469)}`, `${cp(0x1f468)}${ZWJ}${cp(0x1f469)}`],
  ])('accepts %j', (raw, value) => {
    expect(normalizeLiveChatText(raw)).toEqual({ value });
  });

  it.each([
    ['', 'required'],
    ['   ', 'required'],
    [cp(0x3000, 0xfeff), 'required'],
    ['x'.repeat(201), 'too_long'],
    [cp(0x1f44d, 0x1f3fd).repeat(100) + 'a', 'too_long'],
    ['one\ntwo', 'invalid_format'],
    ['one\rtwo', 'invalid_format'],
    ['one\r\ntwo', 'invalid_format'],
    ['one two', 'invalid_format'],
    ['one two', 'invalid_format'],
    ['hi\n', 'invalid_format'], // a trailing line break is not trimmed
    [`a${cp(0x202e)}b`, 'invalid_format'], // bidi override
    [`a${cp(0x200b)}b`, 'invalid_format'], // zero-width space
    [`a${cp(0x7)}b`, 'invalid_format'], // control
    [`${ZWJ}a`, 'invalid_format'], // misplaced joiner
    [`e${ACUTE.repeat(4)}`, 'invalid_format'], // zalgo cap
  ])('refuses %j (%s)', (raw, issue) => {
    expect(normalizeLiveChatText(raw)).toEqual({ issue });
  });

  it('the request: text and clientId required, unknown fields refused, issues on `text`', () => {
    const details = (body: unknown) => {
      const parsed = parseLiveChatSend(body);
      return parsed.success ? [] : parsed.details;
    };
    expect(parseLiveChatSend({ text: ' hi ', clientId: CLIENT_ID })).toEqual({
      success: true,
      data: { kind: 'TEXT', text: 'hi', clientId: CLIENT_ID },
    });
    expect(details({})).toEqual(
      expect.arrayContaining([
        { field: 'text', issue: 'required' },
        { field: 'clientId', issue: 'required' },
      ]),
    );
    expect(details({ text: ' ', clientId: CLIENT_ID })).toEqual([{ field: 'text', issue: 'required' }]);
    expect(details({ text: 'a\nb', clientId: CLIENT_ID })).toEqual([
      { field: 'text', issue: 'invalid_format' },
    ]);
    expect(details({ text: 'x'.repeat(201), clientId: CLIENT_ID })).toEqual([
      { field: 'text', issue: 'too_long' },
    ]);
    expect(details({ text: 'x'.repeat(5000), clientId: CLIENT_ID })).toEqual([
      { field: 'text', issue: 'too_long' },
    ]);
    expect(details({ text: 'hi', clientId: 'nope' })).toEqual([
      { field: 'clientId', issue: 'invalid_format' },
    ]);
    expect(details({ text: 'hi', clientId: CLIENT_ID, roomId: 'x' })).toEqual([
      { field: 'roomId', issue: 'unknown_field' },
    ]);
    expect(details({ text: 5, clientId: CLIENT_ID })).toEqual([{ field: 'text', issue: 'invalid_type' }]);
    expect(details({ clientId: CLIENT_ID })).toEqual([{ field: 'text', issue: 'required' }]);
    expect(details({ text: 'hi' })).toEqual([{ field: 'clientId', issue: 'required' }]);
  });

  it('CP-017 kinds: VOICE and IMAGE take a mediaId and no text; TEXT takes no mediaId', () => {
    const details = (body: unknown) => {
      const parsed = parseLiveChatSend(body);
      return parsed.success ? [] : parsed.details;
    };
    expect(parseLiveChatSend({ kind: 'TEXT', text: 'hi', clientId: CLIENT_ID })).toEqual({
      success: true,
      data: { kind: 'TEXT', text: 'hi', clientId: CLIENT_ID },
    });
    for (const kind of ['VOICE', 'IMAGE']) {
      expect(parseLiveChatSend({ kind, mediaId: MEDIA_ID, clientId: CLIENT_ID })).toEqual({
        success: true,
        data: { kind, mediaId: MEDIA_ID, clientId: CLIENT_ID },
      });
      expect(details({ kind, clientId: CLIENT_ID })).toEqual([{ field: 'mediaId', issue: 'required' }]);
      expect(details({ kind, mediaId: MEDIA_ID, text: 'hi', clientId: CLIENT_ID })).toEqual([
        { field: 'text', issue: 'invalid_value' },
      ]);
      expect(details({ kind, mediaId: 'nope', clientId: CLIENT_ID })).toEqual([
        { field: 'mediaId', issue: 'invalid_format' },
      ]);
    }
    expect(details({ text: 'hi', mediaId: MEDIA_ID, clientId: CLIENT_ID })).toEqual([
      { field: 'mediaId', issue: 'invalid_value' },
    ]);
    expect(details({ kind: 'VIDEO', mediaId: MEDIA_ID, clientId: CLIENT_ID })).toEqual([
      { field: 'kind', issue: 'invalid_value' },
    ]);
    expect(details({ kind: 'VOICE' })).toEqual([
      { field: 'mediaId', issue: 'required' },
      { field: 'clientId', issue: 'required' },
    ]);
  });

  it('CP-017 bullet text: the chat rules with at most 60 code points', () => {
    const details = (body: unknown) => {
      const parsed = liveBulletSendSchema.safeParse(body, { reportInput: true });
      return parsed.success ? [] : zodErrorToDetails(parsed.error);
    };
    expect(liveBulletSendSchema.parse({ text: ' مرحبا ', clientId: CLIENT_ID })).toEqual({
      text: 'مرحبا',
      clientId: CLIENT_ID,
    });
    expect(normalizeLiveChatText('x'.repeat(60), 60)).toEqual({ value: 'x'.repeat(60) });
    expect(details({ text: 'x'.repeat(60), clientId: CLIENT_ID })).toEqual([]);
    expect(details({ text: 'x'.repeat(61), clientId: CLIENT_ID })).toEqual([
      { field: 'text', issue: 'too_long' },
    ]);
    expect(details({ text: '  ', clientId: CLIENT_ID })).toEqual([{ field: 'text', issue: 'required' }]);
    expect(details({ text: 'a\nb', clientId: CLIENT_ID })).toEqual([
      { field: 'text', issue: 'invalid_format' },
    ]);
    expect(details({ text: 'hi', clientId: CLIENT_ID, roomId: 'x' })).toEqual([
      { field: 'roomId', issue: 'unknown_field' },
    ]);
  });

  it('PATCH accepts chatEnabled alone (CP-013)', () => {
    expect(updateLiveRoomSchema.parse({ chatEnabled: false })).toEqual({ chatEnabled: false });
    expect(updateLiveRoomSchema.safeParse({ chatEnabled: 'no' }).success).toBe(false);
  });
});
