import { Prisma } from '../../generated/prisma/client.js';
import type { PrismaService } from '../../prisma/prisma.service.js';

/**
 * v1.121-social (D361, CONVENTIONS §10.156; owner: «المؤسس ليس له ليفيل»): the founder — the app owner, an ACTIVE
 * account holding the OWNER panel role (`isKabsoOwner`, D301) — shows NO level anywhere. Every public payload that
 * carries a user's level (wealth «SUPPORT» / charm «ATTRACTIVENESS») leaves the founder's out at the source: these
 * helpers. His points and levels are still kept (nothing is deleted; if he stops being the owner they show again), and
 * no permission depends on them.
 */
export function founderSql(userId: string | Prisma.Sql): Prisma.Sql {
  const id = typeof userId === 'string' ? Prisma.sql`${userId}::uuid` : userId;
  return Prisma.sql`(EXISTS (SELECT 1 FROM user_admin_permissions fo JOIN users fu ON fu.id = fo.user_id
                      WHERE fo.user_id = ${id} AND fo.permission = 'OWNER'::admin_permission
                        AND fu.status = 'ACTIVE'::user_status))`;
}

type Db = Pick<PrismaService, 'userAdminPermission'> | Prisma.TransactionClient;

/** Which of `userIds` are the founder now (an ACTIVE account holding OWNER). */
export async function foundersAmong(db: Db, userIds: readonly string[]): Promise<Set<string>> {
  if (userIds.length === 0) return new Set();
  const rows = await db.userAdminPermission.findMany({
    where: { userId: { in: [...new Set(userIds)] }, permission: 'OWNER', user: { status: 'ACTIVE' } },
    select: { userId: true },
  });
  return new Set(rows.map((r) => r.userId));
}
