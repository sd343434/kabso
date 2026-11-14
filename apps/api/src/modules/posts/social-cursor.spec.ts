import { describe, expect, it } from 'vitest';
import { SocialCursorCodec } from './social-cursor.js';

const codec = new SocialCursorCodec('k'.repeat(48));
const id = '0193f1c2-0000-7000-8000-00000000000a';

describe('SocialCursorCodec', () => {
  it('round-trips a position bound to its scope', () => {
    const at = new Date('2026-10-20T10:00:00.123Z');
    const cursor = codec.encode('feed:following:u1', { at, id, n: 7 });
    expect(codec.decode(cursor, 'feed:following:u1')).toEqual({ at, id, n: 7 });
    expect(codec.decode(cursor, 'feed:following:u2')).toBeNull();
  });
  it('refuses forged, truncated or foreign-key cursors', () => {
    const cursor = codec.encode('s', { at: new Date(0), id });
    const [payload, tag] = cursor.split('.');
    expect(codec.decode(`${payload}x.${tag}`, 's')).toBeNull();
    expect(codec.decode(payload!, 's')).toBeNull();
    expect(new SocialCursorCodec('z'.repeat(48)).decode(cursor, 's')).toBeNull();
    expect(codec.decode('x'.repeat(600), 's')).toBeNull();
  });
});
