import { createHmac, hkdfSync, randomBytes } from 'node:crypto';
import { describe, expect, it } from 'vitest';
import {
  CURSOR_MAX_STARTED_AT_MS,
  CURSOR_MAX_VIEWER_COUNT,
  cursorScope,
  LiveCursorCodec,
  type CursorPosition,
  type CursorScope,
} from './live-cursor.js';

const USER = '0192f1c2-7a10-7c3e-9d2a-3b4c5d6e7f80';
const OTHER = '0192f1c2-7a10-7c3e-9d2a-3b4c5d6e7f81';
const ROOM = '0192f1d0-1111-7aaa-8bbb-0c0d0e0f1011';
const position: CursorPosition = {
  viewerCount: 3,
  startedAt: new Date('2026-10-16T19:00:00.123Z'),
  id: ROOM,
};

const key = randomBytes(48).toString('base64url');
const codec = new LiveCursorCodec(key);

/** Re-signs an arbitrary payload with the real key derivation (to test post-tag checks). */
function forge(payload: unknown, keySource = key): string {
  const k = Buffer.from(hkdfSync('sha256', keySource, 'kabso', 'live-cursor/v1', 32));
  const body = Buffer.from(JSON.stringify(payload)).toString('base64url');
  const tag = createHmac('sha256', k).update(`live-cursor\u0000${body}`).digest().subarray(0, 16);
  return `${body}.${tag.toString('base64url')}`;
}

describe('LiveCursorCodec', () => {
  const scopes: CursorScope[] = [
    cursorScope('popular', undefined, USER),
    cursorScope('new', 'music', USER),
    cursorScope('following', undefined, USER),
    cursorScope('following', 'music', USER),
  ];

  it.each(scopes)('round-trips %o', (scope) => {
    const cursor = codec.encode(scope, position);
    expect(cursor).toMatch(/^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]{22}$/);
    expect(cursor.length).toBeLessThanOrEqual(512);
    expect(codec.decode(cursor, scope)).toEqual(position);
  });

  it('binds the caller only for the personal following tab', () => {
    expect(cursorScope('popular', undefined, USER).userId).toBeNull();
    expect(cursorScope('new', undefined, USER).userId).toBeNull();
    expect(cursorScope('following', undefined, USER).userId).toBe(USER);
    // A public-tab cursor is valid for any caller.
    const cursor = codec.encode(cursorScope('new', undefined, USER), position);
    expect(codec.decode(cursor, cursorScope('new', undefined, OTHER))).toEqual(position);
  });

  it('rejects a cursor issued for another tab, category or caller', () => {
    const following = codec.encode(cursorScope('following', 'music', USER), position);
    expect(codec.decode(following, cursorScope('following', 'music', OTHER))).toBeNull();
    expect(codec.decode(following, cursorScope('following', undefined, USER))).toBeNull();
    expect(codec.decode(following, cursorScope('following', 'gaming', USER))).toBeNull();
    expect(codec.decode(following, cursorScope('new', 'music', USER))).toBeNull();
    const popular = codec.encode(cursorScope('popular', undefined, USER), position);
    expect(codec.decode(popular, cursorScope('new', undefined, USER))).toBeNull();
    expect(codec.decode(popular, cursorScope('popular', 'music', USER))).toBeNull();
  });

  it('rejects tampering with the payload or the tag', () => {
    const scope = cursorScope('popular', undefined, USER);
    const cursor = codec.encode(scope, position);
    const [payload = '', tag = ''] = cursor.split('.');
    const decoded = JSON.parse(Buffer.from(payload, 'base64url').toString()) as Record<string, unknown>;
    const altered = Buffer.from(JSON.stringify({ ...decoded, n: 999 })).toString('base64url');
    expect(codec.decode(`${altered}.${tag}`, scope)).toBeNull();
    const flipped = `${tag.startsWith('A') ? 'B' : 'A'}${tag.slice(1)}`;
    expect(codec.decode(`${payload}.${flipped}`, scope)).toBeNull();
    // A non-canonical encoding of the same tag bytes (unused low bits of the last character).
    const last = tag.at(-1)!;
    const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_';
    const sibling = alphabet[alphabet.indexOf(last) ^ 1]!;
    const nonCanonical = `${payload}.${tag.slice(0, -1)}${sibling}`;
    expect(Buffer.from(nonCanonical.split('.')[1]!, 'base64url')).toEqual(Buffer.from(tag, 'base64url'));
    expect(codec.decode(nonCanonical, scope)).toBeNull();
    // Same payload, signed with another key.
    expect(new LiveCursorCodec(randomBytes(48).toString('base64url')).decode(cursor, scope)).toBeNull();
  });

  it.each([
    '',
    'not-a-cursor',
    'a.b.c',
    'eyJ2IjoxfQ',
    'eyJ2IjoxfQ.',
    '.AAAAAAAAAAAAAAAAAAAAAA',
    'eyJ2IjoxfQ.AAAAAAAAAAAAAAAAAAAAAA',
    'ey$$.AAAAAAAAAAAAAAAAAAAAAA',
    `${'A'.repeat(600)}.AAAAAAAAAAAAAAAAAAAAAA`,
  ])('rejects malformed cursor %#', (cursor) => {
    expect(codec.decode(cursor, cursorScope('new', undefined, USER))).toBeNull();
  });

  it('rejects a correctly signed payload with an unknown version or a bad shape', () => {
    const scope = cursorScope('new', undefined, USER);
    const good = { v: 1, t: 'new', c: null, u: null, n: 0, s: position.startedAt.getTime(), i: ROOM };
    expect(codec.decode(forge(good), scope)).toEqual({ ...position, viewerCount: 0 });
    expect(codec.decode(forge({ ...good, v: 2 }), scope)).toBeNull();
    expect(codec.decode(forge({ ...good, i: 'x' }), scope)).toBeNull();
    expect(codec.decode(forge({ ...good, n: -1 }), scope)).toBeNull();
    expect(codec.decode(forge({ ...good, s: 'yesterday' }), scope)).toBeNull();
    expect(codec.decode(forge({ ...good, extra: 1 }), scope)).toBeNull();
  });

  it('SEC-038: bounds the sort keys to values the database accepts', () => {
    const scope = cursorScope('popular', undefined, USER);
    const good = { v: 1, t: 'popular', c: null, u: null, n: 0, s: 0, i: ROOM };
    expect(
      codec.decode(forge({ ...good, n: CURSOR_MAX_VIEWER_COUNT, s: CURSOR_MAX_STARTED_AT_MS }), scope),
    ).toEqual({
      viewerCount: CURSOR_MAX_VIEWER_COUNT,
      startedAt: new Date(CURSOR_MAX_STARTED_AT_MS),
      id: ROOM,
    });
    expect(new Date(CURSOR_MAX_STARTED_AT_MS).toISOString()).toBe('9999-12-31T23:59:59.999Z');
    for (const bad of [
      { n: CURSOR_MAX_VIEWER_COUNT + 1 },
      { n: 1.5 },
      { n: -1 },
      { s: CURSOR_MAX_STARTED_AT_MS + 1 },
      { s: 8_640_000_000_000_000 },
      { s: -1 },
      { s: 1e300 },
      { s: 0.5 },
    ]) {
      expect(codec.decode(forge({ ...good, ...bad }), scope)).toBeNull();
    }
    expect(codec.decode(forge('just a string'), scope)).toBeNull();
    // Not JSON at all, but correctly signed.
    const k = Buffer.from(hkdfSync('sha256', key, 'kabso', 'live-cursor/v1', 32));
    const body = Buffer.from('{oops').toString('base64url');
    const tag = createHmac('sha256', k).update(`live-cursor\u0000${body}`).digest().subarray(0, 16);
    expect(codec.decode(`${body}.${tag.toString('base64url')}`, scope)).toBeNull();
  });

  it('derives its key with HKDF (a cursor signed with the raw source key is rejected)', () => {
    const scope = cursorScope('new', undefined, USER);
    const body = Buffer.from(
      JSON.stringify({ v: 1, t: 'new', c: null, u: null, n: 0, s: 0, i: ROOM }),
    ).toString('base64url');
    const tag = createHmac('sha256', key).update(`live-cursor\u0000${body}`).digest().subarray(0, 16);
    expect(codec.decode(`${body}.${tag.toString('base64url')}`, scope)).toBeNull();
  });
});
