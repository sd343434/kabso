/**
 * Who an event is for (`EventAudience`), shared by the Event Center, the start notification and the Live home banners.
 *
 * - EVERYONE: every account.
 * - HOSTS: shown to every account but content creators under D295 (owner, int16: «تختفي من عنده فعاليات المضيفين»);
 *   announced to approved hosts who are not creators. v1.102-social (D334, owner 2026-11-09: «صناع المحتوى يعتبرون
 *   مضيفين، والمضيفون ليسوا صناع محتوى»): an event with `creators_as_hosts` (every event made after migration
 *   20270409090200) is also shown and announced to content creators — creator members, and hosts whose permission
 *   came with their creator membership. The older events keep D295's rule.
 * - CREATORS: creator members only (D303) — a host is never a creator; unchanged by D334.
 * - AGENCIES (D325): owners of an open agency and its active member hosts. CP (D325): people in a CP couple now.
 */
import { Prisma, type EventAudience } from '../../generated/prisma/client.js';

/** The audiences one signed-in person belongs to. */
export interface PersonAudience {
  /** The audiences whose events the person sees under every rule (D295 for HOSTS). */
  readonly audiences: readonly EventAudience[];
  /** A content-creator member: sees HOSTS events that count creators as hosts (D334) too. */
  readonly creator: boolean;
}

/** Without a caller (a guest): EVERYONE only. */
export const GUEST_AUDIENCE: PersonAudience = { audiences: ['EVERYONE'], creator: false };

type Db = { $queryRaw: Prisma.TransactionClient['$queryRaw'] };

/** The audiences of `me` (one query). */
export async function personAudienceOf(db: Db, me: string): Promise<PersonAudience> {
  const [row] = await db.$queryRaw<{ creator: boolean; agency: boolean; cp: boolean }[]>`
    SELECT EXISTS (SELECT 1 FROM creator_members cm WHERE cm.user_id = ${me}::uuid) AS creator,
           (EXISTS (SELECT 1 FROM agencies a WHERE a.owner_user_id = ${me}::uuid AND a.status = 'OPEN')
            OR EXISTS (SELECT 1 FROM agency_hosts h JOIN agencies a ON a.id = h.agency_id AND a.status = 'OPEN'
                        WHERE h.host_user_id = ${me}::uuid AND h.status = 'ACTIVE' AND h.ended_at IS NULL)) AS agency,
           EXISTS (SELECT 1 FROM cp_couples c
                    WHERE (c.user_a_id = ${me}::uuid OR c.user_b_id = ${me}::uuid) AND c.ended_at IS NULL) AS cp`;
  const creator = row?.creator ?? false;
  const audiences: EventAudience[] = ['EVERYONE', creator ? 'CREATORS' : 'HOSTS'];
  if (row?.agency) audiences.push('AGENCIES');
  if (row?.cp) audiences.push('CP');
  return { audiences, creator };
}

/** The events the person may see, as a Prisma filter (combine it under `AND`). */
export function eventAudienceWhere(a: PersonAudience): Prisma.EventWhereInput {
  return {
    OR: [
      { audience: { in: [...a.audiences] } },
      ...(a.creator ? [{ audience: 'HOSTS' as const, creatorsAsHosts: true }] : []),
    ],
  };
}

/** Whether the person may see `event`. */
export function inEventAudience(
  a: PersonAudience,
  event: { audience: EventAudience; creatorsAsHosts: boolean },
): boolean {
  return (
    a.audiences.includes(event.audience) || (a.creator && event.audience === 'HOSTS' && event.creatorsAsHosts)
  );
}

const isCreator = (user: Prisma.Sql) =>
  Prisma.sql`EXISTS (SELECT 1 FROM creator_members cm WHERE cm.user_id = ${user})`;

/**
 * Who counts as a host for a HOSTS event (its start notification; a D166 HOSTS board). D295 (older events): an approved
 * host whose permission is not a creator's, and not a creator member. D334 (`creatorsAsHosts`): every approved host
 * (`live_hosts`, any source) and every creator member.
 */
export function hostOfEventSql(user: Prisma.Sql, creatorsAsHosts: boolean): Prisma.Sql {
  return creatorsAsHosts
    ? Prisma.sql`(EXISTS (SELECT 1 FROM live_hosts h WHERE h.user_id = ${user}) OR ${isCreator(user)})`
    : Prisma.sql`(EXISTS (SELECT 1 FROM live_hosts h WHERE h.user_id = ${user}
                           AND h.source <> 'CREATOR'::live_host_source)
                  AND NOT ${isCreator(user)})`;
}

/** The people of an event's audience (the start notification). */
export function audienceSql(
  event: { audience: EventAudience; creatorsAsHosts: boolean },
  user: Prisma.Sql,
): Prisma.Sql {
  switch (event.audience) {
    case 'EVERYONE':
      return Prisma.sql`true`;
    case 'HOSTS':
      return hostOfEventSql(user, event.creatorsAsHosts);
    case 'CREATORS':
      return isCreator(user);
    case 'AGENCIES':
      return Prisma.sql`(EXISTS (SELECT 1 FROM agencies a WHERE a.owner_user_id = ${user} AND a.status = 'OPEN')
                      OR EXISTS (SELECT 1 FROM agency_hosts ah JOIN agencies a ON a.id = ah.agency_id AND a.status = 'OPEN'
                                  WHERE ah.host_user_id = ${user} AND ah.status = 'ACTIVE' AND ah.ended_at IS NULL))`;
    case 'CP':
      return Prisma.sql`EXISTS (SELECT 1 FROM cp_couples c
                                 WHERE (c.user_a_id = ${user} OR c.user_b_id = ${user}) AND c.ended_at IS NULL)`;
  }
}
