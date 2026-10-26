import type { Prisma, PrismaClient } from '../../generated/prisma/client.js';
import { charmMedalsFor, LIVE_HOURS_MEDALS, liveHoursMedalsFor, type MedalCode } from './medals.catalogue.js';

type Tx = Prisma.TransactionClient;

/**
 * Awards medals to `userId` inside the caller's transaction (CP-018, D106, CONVENTIONS §10.21):
 * one `user_medals` row per user and medal (`ON CONFLICT DO NOTHING`, so awarding again is a
 * no-op), and with `notify` a `MEDAL_AWARDED` in-app notification for each medal this call
 * awarded. A code missing from the catalogue (`medals`) awards nothing. Returns the codes awarded
 * now. Shared by the API and `medals-admin` (no Nest dependencies).
 */
export async function awardMedalsIn(
  tx: Tx,
  userId: string,
  codes: readonly MedalCode[],
  options: { readonly at?: Date; readonly notify?: boolean } = {},
): Promise<MedalCode[]> {
  if (codes.length === 0) return [];
  const at = options.at ?? new Date();
  const rows = await tx.$queryRaw<{ medal_code: MedalCode }[]>`
    INSERT INTO user_medals (user_id, medal_code, awarded_at)
    SELECT ${userId}::uuid, m.code, ${at.toISOString()}::timestamptz
      FROM medals m WHERE m.code = ANY(${[...new Set(codes)]}::text[])
    ON CONFLICT (user_id, medal_code) DO NOTHING
    RETURNING medal_code`;
  const awarded = rows.map((r) => r.medal_code);
  if (options.notify !== false && awarded.length > 0) {
    await tx.notification.createMany({
      data: awarded.map((code) => ({
        recipientId: userId,
        type: 'MEDAL_AWARDED' as const,
        medalCode: code,
        createdAt: at,
        updatedAt: at,
      })),
    });
  }
  return awarded;
}

/**
 * Live medals for the hosts of rooms that just ended, inside the ending transaction (every path:
 * the host, a timeout, the sweeper, a suspension, an admin): FIRST_LIVE once a host has an ended
 * live, LIVE_HOURS_10 / LIVE_HOURS_100 from the hours of all their ended lives. Set-based (one
 * statement for every host of the batch, one for the notifications), so a sweeper batch of
 * hundreds of rooms stays cheap.
 */
export async function awardLiveMedalsForRoomsIn(
  tx: Tx,
  roomIds: readonly string[],
  at: Date = new Date(),
): Promise<void> {
  if (roomIds.length === 0) return;
  const [ten, hundred] = LIVE_HOURS_MEDALS;
  const awarded = await tx.$queryRaw<{ user_id: string; medal_code: string }[]>`
    WITH hosts AS (
      SELECT DISTINCT host_user_id FROM live_rooms
       WHERE id = ANY(${[...new Set(roomIds)]}::uuid[]) AND status = 'ENDED'
    ), totals AS (
      SELECT r.host_user_id, sum(extract(epoch FROM (r.ended_at - r.started_at))) / 3600 AS hours
        FROM live_rooms r JOIN hosts h ON h.host_user_id = r.host_user_id
       WHERE r.status = 'ENDED' AND r.ended_at IS NOT NULL
       GROUP BY r.host_user_id
    ), wanted AS (
      SELECT host_user_id, 'FIRST_LIVE'::text AS code FROM totals
      UNION ALL SELECT host_user_id, ${ten!.code}::text FROM totals WHERE hours >= ${ten!.hours}
      UNION ALL SELECT host_user_id, ${hundred!.code}::text FROM totals WHERE hours >= ${hundred!.hours}
    )
    INSERT INTO user_medals (user_id, medal_code, awarded_at)
    SELECT w.host_user_id, m.code, ${at.toISOString()}::timestamptz
      FROM wanted w JOIN medals m ON m.code = w.code
    ON CONFLICT (user_id, medal_code) DO NOTHING
    RETURNING user_id::text AS user_id, medal_code`;
  if (awarded.length === 0) return;
  await tx.notification.createMany({
    data: awarded.map((row) => ({
      recipientId: row.user_id,
      type: 'MEDAL_AWARDED' as const,
      medalCode: row.medal_code,
      createdAt: at,
      updatedAt: at,
    })),
  });
}

/** Charm medals for a user whose charm level is now `level` (inside the level change). */
export async function awardCharmMedalsIn(tx: Tx, userId: string, level: number | null): Promise<void> {
  await awardMedalsIn(tx, userId, charmMedalsFor(level));
}

export interface BackfillResult {
  /** Medals awarded by this run, by code. */
  readonly awarded: Partial<Record<MedalCode, number>>;
}

/**
 * Awards every medal earned by past events (CP-018, `medals-admin backfill`): hosts with ended
 * lives and their hours, charm levels already reached, family members, partners of every couple
 * ever formed, and senders of a bullet message. Idempotent (awarding again does nothing). The
 * award time is now; with `notify` each new medal also gets a notification. Each user is awarded
 * in their own short transaction.
 */
export async function backfillMedals(
  prisma: PrismaClient,
  options: { readonly notify?: boolean } = {},
): Promise<BackfillResult> {
  const awarded: Partial<Record<MedalCode, number>> = {};
  const award = async (userId: string, codes: MedalCode[]) => {
    if (codes.length === 0) return;
    const now = await prisma.$transaction((tx) =>
      awardMedalsIn(tx, userId, codes, { notify: options.notify === true }),
    );
    for (const code of now) awarded[code] = (awarded[code] ?? 0) + 1;
  };

  const hosts = await prisma.$queryRaw<{ id: string; seconds: number }[]>`
    SELECT host_user_id::text AS id, sum(extract(epoch FROM (ended_at - started_at)))::float8 AS seconds
      FROM live_rooms WHERE status = 'ENDED' AND ended_at IS NOT NULL GROUP BY host_user_id`;
  for (const host of hosts) await award(host.id, ['FIRST_LIVE', ...liveHoursMedalsFor(host.seconds / 3600)]);

  const charm = await prisma.$queryRaw<{ id: string; level: number }[]>`
    SELECT s.user_id::text AS id, s.current_level AS level
      FROM user_level_states s JOIN level_categories c ON c.id = s.category_id
     WHERE c.code = 'ATTRACTIVENESS' AND s.current_level IS NOT NULL`;
  for (const row of charm) await award(row.id, charmMedalsFor(row.level));

  const members = await prisma.$queryRaw<{ id: string }[]>`SELECT user_id::text AS id FROM family_members`;
  for (const row of members) await award(row.id, ['FIRST_FAMILY']);

  const partners = await prisma.$queryRaw<{ id: string }[]>`
    SELECT user_a_id::text AS id FROM cp_couples UNION SELECT user_b_id::text FROM cp_couples`;
  for (const row of partners) await award(row.id, ['FIRST_CP']);

  const senders = await prisma.$queryRaw<
    { id: string }[]
  >`SELECT DISTINCT user_id::text AS id FROM live_bullets`;
  for (const row of senders) await award(row.id, ['BULLET_FIRST']);

  return { awarded };
}
