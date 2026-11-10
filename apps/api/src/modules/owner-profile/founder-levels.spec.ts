/**
 * D361 (v1.121-social, CONVENTIONS §10.156; owner: «المؤسس ليس له ليفيل»): the founder helpers — who is the founder
 * (an ACTIVE account holding OWNER) and the SQL every public level read wraps, so his level is null at the source.
 */
import { describe, expect, it, vi } from 'vitest';
import { Prisma } from '../../generated/prisma/client.js';
import { levelSql } from '../live/live-chat-badges.service.js';
import { founderSql, foundersAmong } from './founder-levels.js';

describe('D361 the founder has no level', () => {
  it('foundersAmong asks for ACTIVE OWNER holders among the ids, once each', async () => {
    const findMany = vi.fn(async () => [{ userId: 'f' }]);
    const db = { userAdminPermission: { findMany } } as never;
    expect(await foundersAmong(db, ['f', 'a', 'f'])).toEqual(new Set(['f']));
    expect(findMany).toHaveBeenCalledWith({
      where: { userId: { in: ['f', 'a'] }, permission: 'OWNER', user: { status: 'ACTIVE' } },
      select: { userId: true },
    });
    const none = vi.fn();
    expect(await foundersAmong({ userAdminPermission: { findMany: none } } as never, [])).toEqual(new Set());
    expect(none).not.toHaveBeenCalled();
  });

  it('founderSql checks OWNER on an ACTIVE account; levelSql answers null for him first', () => {
    const sql = founderSql(Prisma.sql`a.id`);
    expect(sql.sql).toContain("'OWNER'::admin_permission");
    expect(sql.sql).toContain("'ACTIVE'::user_status");
    const byId = founderSql('00000000-0000-0000-0000-000000000001');
    expect(byId.values).toEqual(['00000000-0000-0000-0000-000000000001']);
    const level = levelSql('SUPPORT').sql.replace(/\s+/g, ' ');
    expect(level).toMatch(
      /CASE WHEN \(EXISTS \(SELECT 1 FROM user_admin_permissions fo .*\)\) THEN NULL WHEN lc\.is_enabled/,
    );
  });
});
