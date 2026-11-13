import type { Prisma } from '../../generated/prisma/client.js';

/** `listComments?sort=` (v1.122-social, D364, CONVENTIONS §10.158). */
export type CommentSort = 'RELEVANT' | 'NEWEST';

/** A decoded cursor position: the last row's time, id and (RELEVANT only) like count. */
export interface CommentPosition {
  readonly at: Date;
  readonly id: string;
  readonly n?: number;
}

/**
 * The signed scope of a comments cursor. RELEVANT keeps the scope it had before `sort` existed (cursors already
 * handed out stay valid); NEWEST has its own, so a cursor of one order is refused by the other (400 `cursor`).
 */
export function commentListScope(postId: string, viewerId: string, sort: CommentSort): string {
  return sort === 'NEWEST' ? `comments:newest:${postId}:${viewerId}` : `comments:${postId}:${viewerId}`;
}

/** The rows after [after] in [sort]'s order (keyset, matching [commentOrderBy]). */
export function commentAfterWhere(
  sort: CommentSort,
  after: CommentPosition | null,
): Prisma.CommentWhereInput {
  if (!after) return {};
  if (sort === 'NEWEST') {
    return { OR: [{ createdAt: { lt: after.at } }, { createdAt: after.at, id: { lt: after.id } }] };
  }
  const n = after.n ?? 0;
  return {
    OR: [
      { likeCount: { lt: n } },
      { likeCount: n, createdAt: { lt: after.at } },
      { likeCount: n, createdAt: after.at, id: { lt: after.id } },
    ],
  };
}

/** RELEVANT: likes, then newest (`comments_top_idx`); NEWEST: newest (`comments_newest_idx`). Dislikes never count. */
export function commentOrderBy(sort: CommentSort): Prisma.CommentOrderByWithRelationInput[] {
  return sort === 'NEWEST'
    ? [{ createdAt: 'desc' }, { id: 'desc' }]
    : [{ likeCount: 'desc' }, { createdAt: 'desc' }, { id: 'desc' }];
}

/** The position a page's last row leaves in the cursor. */
export function commentPosition(
  sort: CommentSort,
  row: { id: string; createdAt: Date; likeCount: number },
): CommentPosition {
  return sort === 'NEWEST'
    ? { at: row.createdAt, id: row.id }
    : { at: row.createdAt, id: row.id, n: row.likeCount };
}
