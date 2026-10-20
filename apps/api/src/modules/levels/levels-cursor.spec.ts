import { randomBytes } from 'node:crypto';
import { describe, expect, it } from 'vitest';
import { LevelsCursorCodec } from './levels-cursor.js';

const codec = new LevelsCursorCodec(randomBytes(32).toString('hex'));
const position = {
  createdAt: new Date('2026-10-20T10:00:00.000Z'),
  id: '0192f1c2-7a10-7c3e-9d2a-3b4c5d6e7f80',
};

describe('levels cursors', () => {
  it('round-trips within its scope only', () => {
    const cursor = codec.encode('history:u1:all', position);
    expect(codec.decode(cursor, 'history:u1:all')).toEqual(position);
    expect(codec.decode(cursor, 'history:u2:all')).toBeNull();
    expect(codec.decode(cursor, 'points:u1:all')).toBeNull();
  });

  it('rejects forged, truncated and foreign cursors', () => {
    const cursor = codec.encode('s', position);
    const [payload] = cursor.split('.');
    expect(codec.decode(`${payload ?? ''}.AAAAAAAAAAAAAAAAAAAAAA`, 's')).toBeNull();
    expect(codec.decode(cursor.slice(0, -1), 's')).toBeNull();
    expect(codec.decode('not-a-cursor', 's')).toBeNull();
    expect(new LevelsCursorCodec(randomBytes(32).toString('hex')).decode(cursor, 's')).toBeNull();
  });
});
