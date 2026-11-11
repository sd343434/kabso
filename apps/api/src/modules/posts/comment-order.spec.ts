import { describe, expect, it } from 'vitest';
import { commentAfterWhere, commentListScope, commentOrderBy, commentPosition } from './comment-order.js';
import { SocialCursorCodec } from './social-cursor.js';

const postId = '0193f1c2-0000-7000-8000-0000000000aa';
const viewerId = '0193f1c2-0000-7000-8000-0000000000bb';
const id = '0193f1c2-0000-7000-8000-00000000000a';
const at = new Date('2026-11-11T10:00:00.000Z');

describe('comment order (v1.122-social, D364)', () => {
  it('RELEVANT keeps the scope cursors had before `sort`; NEWEST has its own', () => {
    expect(commentListScope(postId, viewerId, 'RELEVANT')).toBe(`comments:${postId}:${viewerId}`);
    expect(commentListScope(postId, viewerId, 'NEWEST')).not.toBe(
      commentListScope(postId, viewerId, 'RELEVANT'),
    );
  });

  it('a cursor of one order is refused by the other', () => {
    const codec = new SocialCursorCodec('k'.repeat(48));
    const relevant = commentListScope(postId, viewerId, 'RELEVANT');
    const newest = commentListScope(postId, viewerId, 'NEWEST');
    const fromRelevant = codec.encode(
      relevant,
      commentPosition('RELEVANT', { id, createdAt: at, likeCount: 3 }),
    );
    const fromNewest = codec.encode(newest, commentPosition('NEWEST', { id, createdAt: at, likeCount: 3 }));
    expect(codec.decode(fromRelevant, relevant)).toEqual({ at, id, n: 3 });
    expect(codec.decode(fromNewest, newest)).toEqual({ at, id });
    expect(codec.decode(fromRelevant, newest)).toBeNull();
    expect(codec.decode(fromNewest, relevant)).toBeNull();
  });

  it('orders: RELEVANT by likes then newest; NEWEST by time then id (dislikes never count)', () => {
    expect(commentOrderBy('RELEVANT')).toEqual([
      { likeCount: 'desc' },
      { createdAt: 'desc' },
      { id: 'desc' },
    ]);
    expect(commentOrderBy('NEWEST')).toEqual([{ createdAt: 'desc' }, { id: 'desc' }]);
  });

  it('keysets match the orders', () => {
    expect(commentAfterWhere('NEWEST', null)).toEqual({});
    expect(commentAfterWhere('RELEVANT', null)).toEqual({});
    expect(commentAfterWhere('NEWEST', { at, id })).toEqual({
      OR: [{ createdAt: { lt: at } }, { createdAt: at, id: { lt: id } }],
    });
    expect(commentAfterWhere('RELEVANT', { at, id, n: 2 })).toEqual({
      OR: [
        { likeCount: { lt: 2 } },
        { likeCount: 2, createdAt: { lt: at } },
        { likeCount: 2, createdAt: at, id: { lt: id } },
      ],
    });
  });
});
