import { existsSync, readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { Prisma } from '../../generated/prisma/client.js';

/**
 * v1.72-live (D283, CONVENTIONS §10.96.10; owner: «وهذه الصورة الشخصية الخاص بالادمن والمشرفين بحيث لا يمكن
 * تغييرها»): a limited Kabso Team account (MODERATION / SUPPORT / FINANCE, not OWNER) has ONE fixed picture — the
 * owner's Kabi-in-a-suit art, served by the API at {@link TEAM_AVATAR_PATH}.
 *
 * **How (the cleanest of the options):** the account's `user_profiles.avatar_url` IS that URL while it is limited
 * staff. Every surface that shows a picture (profiles, summaries in chat, viewers, seats, DMs, comments, posts, the
 * panel) reads `avatar_url`, so they all show it with no change — older apps too. The person's own photo is kept in
 * `staff_saved_avatar_url` and comes back when the last limited role goes (or OWNER is granted). `PUT` / `DELETE
 * /me/avatar` answer 403 STAFF_ACCOUNT_LIMITED `avatar` meanwhile. The new app recognises the URL
 * ({@link isTeamAvatarUrl}) and draws the bundled art on a red radial background inside the locked team frame.
 */
export const TEAM_AVATAR_PATH = '/api/v1/staff/team-avatar.png';

/** The team picture's absolute URL (`API_PUBLIC_URL`, default `https://api.kabsolive.com`). */
export function teamAvatarUrl(env: NodeJS.ProcessEnv = process.env): string {
  return `${(env.API_PUBLIC_URL ?? 'https://api.kabsolive.com').replace(/\/+$/, '')}${TEAM_AVATAR_PATH}`;
}

/** Whether `url` is the team picture (any origin: the path decides). */
export function isTeamAvatarUrl(url: string | null | undefined): boolean {
  if (!url) return false;
  try {
    return new URL(url).pathname === TEAM_AVATAR_PATH;
  } catch {
    return false;
  }
}

/** The SQL predicate of a limited staff account for the picture: the roles only (a suspension keeps it). */
function holdsLimitedRoleSql(id: Prisma.Sql): Prisma.Sql {
  return Prisma.sql`(EXISTS (SELECT 1 FROM user_admin_permissions sp WHERE sp.user_id = ${id}
                       AND sp.permission IN ('MODERATION'::admin_permission, 'SUPPORT'::admin_permission,
                                             'FINANCE'::admin_permission, 'BD'::admin_permission))
                 AND NOT EXISTS (SELECT 1 FROM user_admin_permissions so WHERE so.user_id = ${id}
                       AND so.permission = 'OWNER'::admin_permission))`;
}

/**
 * Puts the team picture on, or gives the person's own back, so `avatar_url` matches the roles held now. `userId`:
 * one account (after a grant / revoke), or null: every account (the API's start — a changed `API_PUBLIC_URL`, the
 * CLI's grants). Idempotent; returns the rows changed.
 */
export async function syncTeamAvatarsIn(
  db: Pick<Prisma.TransactionClient, '$executeRaw'>,
  userId: string | null,
  url: string = teamAvatarUrl(),
): Promise<number> {
  const only = userId === null ? Prisma.empty : Prisma.sql`AND p.user_id = ${userId}::uuid`;
  const holds = holdsLimitedRoleSql(Prisma.sql`p.user_id`);
  const on = await db.$executeRaw`
    UPDATE user_profiles p
       SET staff_saved_avatar_url = CASE WHEN p.staff_avatar THEN p.staff_saved_avatar_url ELSE p.avatar_url END,
           staff_avatar = true,
           avatar_url = ${url}
     WHERE ${holds} AND (NOT p.staff_avatar OR p.avatar_url IS DISTINCT FROM ${url}) ${only}`;
  const off = await db.$executeRaw`
    UPDATE user_profiles p
       SET avatar_url = p.staff_saved_avatar_url, staff_saved_avatar_url = NULL, staff_avatar = false
     WHERE p.staff_avatar AND NOT ${holds} ${only}`;
  return on + off;
}

/** The bundled art (apps/api/assets/staff/kabso_team_avatar.png), read once; null when the file is missing. */
let cached: Buffer | null | undefined;
export function teamAvatarPng(): Buffer | null {
  if (cached !== undefined) return cached;
  // src/modules/live → apps/api (dev, tests) or dist/modules/live → apps/api (the image).
  const candidates = [
    '../../../assets/staff/kabso_team_avatar.png',
    '../../../../assets/staff/kabso_team_avatar.png',
  ];
  for (const rel of candidates) {
    const path = fileURLToPath(new URL(rel, import.meta.url));
    if (existsSync(path)) return (cached = readFileSync(path));
  }
  return (cached = null);
}
