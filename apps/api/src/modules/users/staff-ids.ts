import { Prisma } from '../../generated/prisma/client.js';
import type { PrismaService } from '../../prisma/prisma.service.js';
import { PANEL_STAFF_ROLES, panelStaffSql } from '../live/live-staff.js';

/**
 * v1.73-live (D283c, CONVENTIONS §10.96.12; owner: «ايدي للمشرفين والادارة بحيث ايدي الموظفين يبدأ Kabso01»): the
 * official staff ID of an account holding a panel role (OWNER, MODERATION, SUPPORT, FINANCE) — «Kabso01», «Kabso02», …
 * (two digits, then «Kabso100»). The number is given by `kabso_assign_staff_id` in the grant's transaction (migration
 * 20270317090000_staff_ids; the runtime role only reads `staff_ids`), kept for life and never reused: shown only while
 * the account holds a panel role and is ACTIVE, the same number again after a re-grant. The username stays the
 * person's (login, links); the apps show the staff ID where they show the @username.
 */

export const STAFF_ID_PREFIX = 'Kabso';

/**
 * v1.74-live (D283d; owner: «المالك… لا، kabso»): number 0 is the primary OWNER's plain «Kabso» (no digits), given by
 * the first OWNER grant while nobody ever held it; any other OWNER gets the next number like the staff.
 */
export const OWNER_STAFF_NUMBER = 0;

/** 0 → «Kabso» (the primary OWNER), 1 → «Kabso01», 7 → «Kabso07», 100 → «Kabso100». */
export function formatStaffId(n: number): string {
  return n === OWNER_STAFF_NUMBER ? STAFF_ID_PREFIX : `${STAFF_ID_PREFIX}${String(n).padStart(2, '0')}`;
}

/** «Kabso01», «kabso1», «@KABSO01» → 1; «Kabso» → 0 (the primary OWNER); anything else → null (search by staff ID). */
export function parseStaffId(raw: string): number | null {
  const m = /^@?kabso(?:0*([1-9][0-9]{0,8}))?$/i.exec(raw.trim());
  if (!m) return null;
  return m[1] === undefined ? OWNER_STAFF_NUMBER : Number(m[1]);
}

/**
 * A username that looks like a staff ID, reserved for everyone (any case; `.` / `_` / `-` ignored): «kabso» itself and
 * «kabso» followed by digits, with the ASCII look-alikes — `4` for `a`, `8` for `b`, `5` for `s`, `0` for `o` («kabs0»,
 * «k4bso»), and `o` / `i` / `l` among the digits («kabsoO1», «kabso0l») as long as some digit is there. v1.74-live
 * (D283d): the bare look-alikes of «Kabso» too («kabs0», «k4b5o»).
 */
export function isStaffIdLike(name: string): boolean {
  const bare = name.toLowerCase().replace(/[._-]/g, '');
  const m = /^k[a4][b8][s5][o0]([0-9oil]*)$/.exec(bare);
  if (!m) return false;
  return m[1] === '' || /[0-9]/.test(bare);
}

type Db = Pick<PrismaService, '$queryRaw'> | Prisma.TransactionClient;

/** The staff IDs shown now among `userIds` (holders of a panel role with an ACTIVE account). */
export async function staffIdsAmong(db: Db, userIds: readonly string[]): Promise<Map<string, string>> {
  const ids = [...new Set(userIds)];
  const out = new Map<string, string>();
  if (ids.length === 0) return out;
  const rows = await db.$queryRaw<{ id: string; number: number }[]>`
    SELECT s.user_id::text AS id, s.number FROM staff_ids s
     WHERE s.user_id IN (${Prisma.join(ids.map((id) => Prisma.sql`${id}::uuid`))})
       AND ${panelStaffSql(Prisma.sql`s.user_id`)}`;
  for (const r of rows) out.set(r.id, formatStaffId(r.number));
  return out;
}

/** The staff ID `userId` shows now, or null. */
export async function staffIdOf(db: Db, userId: string): Promise<string | null> {
  return (await staffIdsAmong(db, [userId])).get(userId) ?? null;
}

/** The staff ID kept for `userId` (also after a revoke: the panel and the audit), or null. */
export async function keptStaffIdOf(
  db: Pick<PrismaService, 'staffId'> | Prisma.TransactionClient,
  userId: string,
): Promise<string | null> {
  const row = await db.staffId.findUnique({ where: { userId }, select: { number: true } });
  return row ? formatStaffId(row.number) : null;
}

/**
 * For `userSummary` (selected with `USER_SUMMARY_SELECT`): the staff ID while the account is ACTIVE, `role = ADMIN` and
 * holds a panel role; null otherwise (or when the select did not carry the fields).
 */
export function summaryStaffIdOf(user: {
  status?: string;
  role?: string;
  staffNumber?: { number: number } | null;
  adminPermissions?: readonly { permission: string }[];
}): string | null {
  if (!user.staffNumber || user.status !== 'ACTIVE' || user.role !== 'ADMIN') return null;
  if (!user.adminPermissions?.some((p) => (PANEL_STAFF_ROLES as readonly string[]).includes(p.permission)))
    return null;
  return formatStaffId(user.staffNumber.number);
}
