import { dmSnapshotObjectKeys } from '../messages/dm-reports.js';
import { createHash, randomBytes } from 'node:crypto';
import { purgeKycIn } from '../kyc/kyc-core.js';
import { AuditAction } from '../../common/audit/audit.service.js';
import { Prisma, type PrismaClient } from '../../generated/prisma/client.js';
import { releaseUserIn } from '../live/live-seats.store.js';
import { cancelPendingHostApplicationIn } from '../host-applications/host-applications.core.js';
import { isValidUsername } from './username.js';

/**
 * Account deletion «حذف الحساب» (v1.62-social, D193, CONVENTIONS §10.56), shared by the API (request, cancel,
 * sweeper), the `account-admin` CLI and the tests — no Nest dependencies, like `recharge-core`.
 *
 *  1. **Request** ({@link requestDeletionIn}): an ACTIVE account with nothing to settle ({@link deletionBlockersIn})
 *     becomes PENDING_DELETION — every `status = 'ACTIVE'` filter hides it at once (search, profile, lists, live
 *     rooms, follow lists; the access-token guard refuses its tokens) — every session is revoked with its push token,
 *     it leaves the seats it holds, and a PENDING `account_deletion_requests` row records `purge_after`.
 *  2. **Grace** (ACCOUNT_DELETION_GRACE_DAYS, 30): signing in with the right password answers 409
 *     ACCOUNT_DELETION_PENDING; signing in with `cancelDeletion: true` (or `account-admin cancel`) runs
 *     {@link cancelDeletionIn}: ACTIVE again, nothing was removed, so everything is back.
 *  3. **Purge** ({@link purgeAccountIn}, by the sweeper once `purge_after` passed or `account-admin purge-now`): the
 *     user row becomes a tombstone — same random id, no personal data, status DELETED — personal content and the
 *     social graph are deleted, and the financial and audit rows stay under the tombstone id (see the list in
 *     CONVENTIONS §10.56 and `purgeAccountIn`). The regular username is quarantined ({@link DeletedUsername}).
 *  4. **Legal hold** (owner 2026-10-31): content with an OPEN or ACTIONED report is copied into `legal_holds` at the
 *     purge ({@link holdReportedContentIn}) — hidden from every user, linked only to its reports and the tombstone id —
 *     and deleted with its reports and files after REPORT_LEGAL_HOLD_DAYS (90, {@link expireLegalHolds}).
 *  5. **Retention** (owner: 7 years): DELETED_LEDGER_RETENTION_DAYS (2557) after the purge the tombstone's audit rows
 *     and deletion record are deleted and the last free-text fields of its ledgers blanked ({@link endLedgerRetention}).
 */

type Tx = Prisma.TransactionClient;

/** What must be settled (by the team or by waiting) before an account can be deleted. */
export type DeletionBlocker =
  'recharge_agent' | 'host_agency' | 'pending_withdrawal' | 'pending_cherry_sale' | 'negative_balance';

/** The display name of a tombstone: what others see in their gift and chat history (owner wording). */
export const DELETED_DISPLAY_NAME = 'مستخدم محذوف';
/** A tombstone's username: `deleted.` + 16 hex digits. A dot never fits a new regular or premium name (§6). */
export const TOMBSTONE_USERNAME = /^deleted\.[0-9a-f]{16}$/;
/** Not an Argon2 PHC string: the password check always fails (PasswordHasher treats it as a mismatch). */
const TOMBSTONE_PASSWORD_HASH = '!account-deleted';
/** The session revocation reason (`sessions.revoked_reason`). */
export const ACCOUNT_DELETION_REVOKED_REASON = 'ACCOUNT_DELETION';

export interface DeletionRequestView {
  readonly id: string;
  readonly requestedAt: Date;
  readonly purgeAfter: Date;
}

/** Who acted, for the audit rows. */
export interface DeletionActor {
  readonly via: 'APP' | 'ADMIN';
  readonly actorUserId?: string | null;
  readonly reason?: string | null;
  readonly ip?: string | null;
  readonly requestId?: string | null;
  /** v1.72-social (D208): the audit row's `via` for an ADMIN actor — `cli` (default) or `panel` (the admin panel). */
  readonly auditVia?: 'cli' | 'panel' | 'app';
}

/** SHA-256 (hex) of a lower-cased username: the quarantine key (the name itself is not kept). */
export function usernameHash(name: string): string {
  return createHash('sha256').update(name.trim().toLowerCase(), 'utf8').digest('hex');
}

/** True while `name` is the quarantined regular username of a purged account. */
export async function isUsernameQuarantined(
  db: Pick<Tx, 'deletedUsername'>,
  name: string,
  now: Date,
): Promise<boolean> {
  return (
    (await db.deletedUsername.count({ where: { nameHash: usernameHash(name), until: { gt: now } } })) > 0
  );
}

/**
 * What blocks deleting `userId` now, in a fixed order (empty: nothing). Money in flight and roles the team manages
 * must be settled first:
 *  - `recharge_agent`: a recharge agent (D185) that is not suspended, or one with coins left in the stock;
 *  - `host_agency`: the owner of a host agency (D179/D189) that the team has not suspended, or that still has hosts;
 *  - `pending_withdrawal`: a cherry withdrawal waiting to be paid (D179);
 *  - `pending_cherry_sale`: a cherry sale to a recharge agent still open (D185);
 *  - `negative_balance`: a negative coin or cherry balance (a reversal or a dispute; checked generically).
 */
export async function deletionBlockersIn(db: Tx | PrismaClient, userId: string): Promise<DeletionBlocker[]> {
  const [agent, agency, withdrawals, cherrySales, wallet, cherryWallet] = await Promise.all([
    db.rechargeAgent.findUnique({ where: { userId }, select: { status: true, stockCoins: true } }),
    db.agency.findUnique({
      where: { ownerUserId: userId },
      select: {
        suspendedAt: true,
        status: true,
        _count: { select: { hosts: { where: { status: 'ACTIVE' } } } },
      },
    }),
    db.cherryWithdrawal.count({ where: { userId, status: 'PENDING' } }),
    db.rechargeCherryRequest.count({ where: { hostUserId: userId, status: 'PENDING' } }),
    db.wallet.findUnique({ where: { userId }, select: { coins: true } }),
    db.cherryWallet.findUnique({ where: { userId }, select: { cherries: true } }),
  ]);
  const blockers: DeletionBlocker[] = [];
  if (agent && (agent.status !== 'SUSPENDED' || agent.stockCoins > 0n)) blockers.push('recharge_agent');
  // v1.70-social (D206): a closed agency has no hosts and no perks — it does not block.
  if (agency && agency.status === 'OPEN' && (agency.suspendedAt === null || agency._count.hosts > 0)) {
    blockers.push('host_agency');
  }
  if (withdrawals > 0) blockers.push('pending_withdrawal');
  if (cherrySales > 0) blockers.push('pending_cherry_sale');
  if ((wallet && wallet.coins < 0n) || (cherryWallet && cherryWallet.cherries < 0n))
    blockers.push('negative_balance');
  return blockers;
}

/** Locks the user row; null when there is no such user. */
async function lockUser(tx: Tx, userId: string): Promise<{ status: string } | null> {
  const rows = await tx.$queryRaw<{ status: string }[]>`
    SELECT status::text AS status FROM users WHERE id = ${userId}::uuid FOR UPDATE`;
  return rows[0] ?? null;
}

async function pendingRequestOf(tx: Tx, userId: string): Promise<DeletionRequestView | null> {
  return tx.accountDeletionRequest.findFirst({
    where: { userId, status: 'PENDING' },
    select: { id: true, requestedAt: true, purgeAfter: true },
  });
}

function auditRow(
  action: AuditAction,
  userId: string,
  actor: DeletionActor,
  metadata: Prisma.InputJsonObject,
): Prisma.AuditLogUncheckedCreateInput {
  return {
    action,
    actorUserId: actor.via === 'APP' ? userId : (actor.actorUserId ?? null),
    targetType: 'user',
    targetId: userId,
    metadata: {
      via: actor.via === 'APP' ? 'app' : (actor.auditVia ?? 'cli'),
      ...(actor.reason ? { reason: actor.reason } : {}),
      ...metadata,
    },
    ip: actor.ip?.slice(0, 64) ?? null,
    requestId: actor.requestId ?? null,
  };
}

export type RequestDeletionOutcome =
  | { readonly outcome: 'requested'; readonly request: DeletionRequestView; readonly revokedSessions: number }
  | { readonly outcome: 'already_pending'; readonly request: DeletionRequestView }
  | { readonly outcome: 'blocked'; readonly blockers: DeletionBlocker[] }
  | { readonly outcome: 'not_active' };

/**
 * Starts the grace period (idempotent: an account already PENDING_DELETION returns its request). Only ACTIVE
 * accounts; a blocked one changes nothing (the caller audits the refusal).
 */
export async function requestDeletionIn(
  tx: Tx,
  userId: string,
  now: Date,
  graceDays: number,
  actor: DeletionActor,
): Promise<RequestDeletionOutcome> {
  const user = await lockUser(tx, userId);
  if (!user) return { outcome: 'not_active' };
  if (user.status === 'PENDING_DELETION') {
    const request = await pendingRequestOf(tx, userId);
    if (request) return { outcome: 'already_pending', request };
  }
  if (user.status !== 'ACTIVE') return { outcome: 'not_active' };
  const blockers = await deletionBlockersIn(tx, userId);
  if (blockers.length > 0) return { outcome: 'blocked', blockers };

  await tx.user.update({ where: { id: userId }, data: { status: 'PENDING_DELETION' } });
  const request = await tx.accountDeletionRequest.create({
    data: {
      userId,
      requestedVia: actor.via,
      requestedAt: now,
      purgeAfter: new Date(now.getTime() + graceDays * 86_400_000),
    },
    select: { id: true, requestedAt: true, purgeAfter: true },
  });
  // Signed out everywhere: every session (this one too) and its push token.
  const revoked = await tx.session.updateMany({
    where: { userId, revokedAt: null },
    data: { revokedAt: now, revokedReason: ACCOUNT_DELETION_REVOKED_REASON },
  });
  await tx.deviceToken.deleteMany({ where: { userId } });
  // Out of every live room at once (seats, requests, invitations, moderator roles). A LIVE room of theirs is hidden by
  // the ACTIVE-host filter and ended by the room sweeper (no heartbeat any more), as for a soft-deleted account.
  await releaseUserIn(tx, userId, now, { moderator: true });
  await tx.auditLog.create({
    data: auditRow(AuditAction.ACCOUNT_DELETION_REQUESTED, userId, actor, {
      requestId: request.id,
      purgeAfter: request.purgeAfter.toISOString(),
      revokedSessions: revoked.count,
    }),
  });
  return { outcome: 'requested', request, revokedSessions: revoked.count };
}

/** Ends the grace period: ACTIVE again with everything it had. False when the account was not PENDING_DELETION. */
export async function cancelDeletionIn(
  tx: Tx,
  userId: string,
  now: Date,
  actor: DeletionActor,
): Promise<boolean> {
  const user = await lockUser(tx, userId);
  if (user?.status !== 'PENDING_DELETION') return false;
  const request = await pendingRequestOf(tx, userId);
  if (request) {
    await tx.accountDeletionRequest.update({
      where: { id: request.id },
      data: { status: 'CANCELLED', cancelledAt: now, cancelledVia: actor.via },
    });
  }
  await tx.user.update({ where: { id: userId }, data: { status: 'ACTIVE' } });
  await tx.auditLog.create({
    data: auditRow(AuditAction.ACCOUNT_DELETION_CANCELLED, userId, actor, {
      ...(request ? { requestId: request.id } : {}),
    }),
  });
  return true;
}

export interface PurgeOptions {
  /** ACCOUNT_DELETION_USERNAME_QUARANTINE_DAYS (0: the regular username is free at once). */
  readonly quarantineDays: number;
  /** SPECIAL_USERNAME_GRACE_DAYS: a gifted or bought special username in use is held this long, as when it ends. */
  readonly specialGraceDays: number;
  /** REPORT_LEGAL_HOLD_DAYS: reported content (an OPEN or ACTIONED report) is kept hidden this long. */
  readonly legalHoldDays: number;
  readonly via: 'SWEEPER' | 'ADMIN';
  readonly reason?: string | null;
}

export interface PurgeResult {
  readonly userId: string;
  readonly tombstoneUsername: string;
  /** Object-storage keys to delete after the commit (media, avatar, KYC pictures; not those under a legal hold). */
  readonly objectKeys: string[];
  /** Reported items put under a legal hold. */
  readonly held: number;
}

/** A tombstone username nobody has (retried on the rare collision with a grandfathered name). */
async function freeTombstoneUsername(tx: Tx): Promise<string> {
  for (;;) {
    const name = `deleted.${randomBytes(8).toString('hex')}`;
    const taken = await tx.userProfile.count({ where: { username: name } });
    if (taken === 0) return name;
  }
}

/**
 * Turns the account into a tombstone, inside the caller's transaction. Returns null when there is nothing to purge
 * (no such user, or already DELETED: idempotent). Runs for a PENDING_DELETION account (the sweeper) and for any
 * other non-deleted account (`account-admin purge-now`, which checks the blockers first).
 *
 * **Deleted:** the email (replaced by `deleted+<id>@deleted.invalid`), the password, the profile fields (name, bio,
 * photo, country, gender, category, links), settings, every session, verification token and push token; posts and
 * reels (with their likes, comments, media and reports), stories, comments (soft-deleted, text removed), likes,
 * saves, reposts, shares and views of others' posts (the counters adjusted), mentions; direct messages they wrote
 * (gift messages stay: the gift is a ledger row), live-chat, family-chat and CP-confession texts they wrote, their
 * notifications and their part in others'; follows, follow requests, blocks and mutes both ways; their media assets
 * and uploads (objects deleted after the commit); KYC data of recharge-agent applications (name, phone, pictures,
 * places, payment methods); hosting permission, schedule, featured slot, watch suggestions; the family membership
 * (a leader hands over to the longest-serving deputy or member, or the family is disbanded when alone) and the CP
 * couple (ended). (Admin permissions are not writable by the runtime role; they are inert on a DELETED account.)
 *
 * **Kept, pseudonymised under the tombstone id (accounting, fraud, legal):** wallets and the coin, cherry, family,
 * CP and level ledgers, gifts sent and received, lucky draws, boosts, bag items and transfers, premium-username
 * leases and payments, recharge sales, stock and cherry requests, agency rows and earnings, cherry withdrawals (the
 * payout details reduced to their last 4 characters), task and event rewards, live-room history and statistics,
 * reports made and received, the 18+ statement, special usernames (system codes held forever), the audit log (its IP
 * addresses dropped and the person's identifiers removed from its metadata, `account_deletion_scrub_audit`).
 *
 * **Held** ({@link holdReportedContentIn}, before anything is deleted): content with an OPEN or ACTIONED report — a
 * snapshot in `legal_holds`, its files kept, its reports re-linked to the hold.
 */
export async function purgeAccountIn(
  tx: Tx,
  userId: string,
  now: Date,
  options: PurgeOptions,
): Promise<PurgeResult | null> {
  const user = await lockUser(tx, userId);
  if (!user || user.status === 'DELETED') return null;
  const at = now.toISOString();
  const u = Prisma.sql`${userId}::uuid`;

  // -- The regular username (behind a special or premium one) is quarantined; system codes stay held forever.
  const profile = await tx.userProfile.findUnique({ where: { userId }, select: { username: true } });
  const activeSpecial = await tx.specialUsername.findFirst({
    where: { userId, status: 'ACTIVE' },
    select: { baseUsername: true },
  });
  const activeLease = await tx.premiumUsernameLease.findFirst({
    where: { userId, status: 'ACTIVE' },
    select: { regularUsername: true },
  });
  const regular = activeSpecial?.baseUsername ?? activeLease?.regularUsername ?? profile?.username ?? null;
  const tombstone = await freeTombstoneUsername(tx);

  // -- Reported content survives as a hidden legal hold (owner: OPEN or ACTIONED report, 90 days); the snapshots of
  // their DM and profile-link reports lose the old username.
  const holds = await holdReportedContentIn(tx, userId, now, options.legalHoldDays);
  await tx.$executeRaw`
    UPDATE reports SET dm_snapshot = jsonb_set(dm_snapshot, '{senderUsername}', 'null'::jsonb)
     WHERE target_type = 'DM_MESSAGE'::report_target_type AND dm_snapshot->>'senderId' = ${userId}`;
  await tx.$executeRaw`
    UPDATE reports SET link_snapshot = jsonb_set(link_snapshot, '{username}', to_jsonb(${tombstone}::text))
     WHERE target_type = 'PROFILE_LINK'::report_target_type AND link_snapshot->>'userId' = ${userId}`;

  // -- v1.116-social (D355, §10.151.8): the WhatsApp conversations linked to the account go with their media (the
  // WhatsApp sweeper deletes the files and rows; a new message from that phone starts a fresh conversation).
  await tx.$executeRaw`UPDATE wa_conversations SET purge_after = ${now} WHERE linked_user_id = ${u}`;

  // -- Content they wrote, and its counters on others' content.
  await tx.$executeRaw`DELETE FROM posts WHERE author_id = ${u}`;
  await tx.$executeRaw`DELETE FROM stories WHERE author_id = ${u}`;
  await tx.$executeRaw`
    WITH d AS (DELETE FROM post_likes WHERE user_id = ${u} RETURNING post_id),
         c AS (SELECT post_id, count(*)::int AS n FROM d GROUP BY post_id)
    UPDATE posts p SET like_count = GREATEST(p.like_count - c.n, 0) FROM c WHERE p.id = c.post_id`;
  await tx.$executeRaw`
    WITH d AS (DELETE FROM post_saves WHERE user_id = ${u} RETURNING post_id),
         c AS (SELECT post_id, count(*)::int AS n FROM d GROUP BY post_id)
    UPDATE posts p SET save_count = GREATEST(p.save_count - c.n, 0) FROM c WHERE p.id = c.post_id`;
  await tx.$executeRaw`
    WITH d AS (DELETE FROM post_reposts WHERE user_id = ${u} RETURNING post_id),
         c AS (SELECT post_id, count(*)::int AS n FROM d GROUP BY post_id)
    UPDATE posts p SET repost_count = GREATEST(p.repost_count - c.n, 0) FROM c WHERE p.id = c.post_id`;
  await tx.$executeRaw`
    WITH d AS (DELETE FROM comment_likes WHERE user_id = ${u} RETURNING comment_id),
         c AS (SELECT comment_id, count(*)::int AS n FROM d GROUP BY comment_id)
    UPDATE comments k SET like_count = GREATEST(k.like_count - c.n, 0) FROM c WHERE k.id = c.comment_id`;
  // Views and share events are totals of the past (the counters stay); their rows name the viewer.
  await tx.$executeRaw`DELETE FROM post_views WHERE user_id = ${u}`;
  await tx.$executeRaw`DELETE FROM post_share_events WHERE user_id = ${u}`;
  await tx.$executeRaw`DELETE FROM post_hides WHERE user_id = ${u}`;
  await tx.$executeRaw`DELETE FROM post_mentions WHERE user_id = ${u}`;
  await tx.$executeRaw`DELETE FROM comment_mentions WHERE user_id = ${u}`;
  await tx.$executeRaw`DELETE FROM story_views WHERE viewer_id = ${u}`;
  await tx.$executeRaw`DELETE FROM story_mentions WHERE user_id = ${u}`;
  // v1.105-social (D340): which event starts the person saw full screen (nothing else reads it).
  await tx.$executeRaw`DELETE FROM event_start_announcements WHERE user_id = ${u}`;
  await softDeleteCommentsIn(tx, userId, now);
  await tx.$executeRaw`UPDATE comments SET text = '' WHERE author_id = ${u}`;

  // -- Messages: their direct messages go (a gift message stays: it shows the gift in the other person's chat);
  // live-chat, family-chat and confession messages go; paid bullet texts are blanked to a placeholder.
  await tx.$executeRaw`DELETE FROM dm_messages WHERE sender_id = ${u} AND kind <> 'GIFT'::dm_message_kind`;
  await tx.$executeRaw`DELETE FROM dm_message_hides WHERE user_id = ${u}`;
  await tx.$executeRaw`DELETE FROM live_chat_messages WHERE user_id = ${u}`;
  await tx.$executeRaw`DELETE FROM family_chat_messages WHERE author_id = ${u}`;
  await tx.$executeRaw`DELETE FROM cp_confessions WHERE author_id = ${u}`;
  await tx.$executeRaw`UPDATE live_bullets SET text = '·' WHERE user_id = ${u}`;
  await tx.$executeRaw`DELETE FROM notifications WHERE recipient_id = ${u}`;
  await tx.$executeRaw`DELETE FROM notification_actors WHERE actor_id = ${u}`;

  // -- The social graph.
  await tx.$executeRaw`DELETE FROM follows WHERE follower_id = ${u} OR followee_id = ${u}`;
  await tx.$executeRaw`DELETE FROM follow_requests WHERE requester_id = ${u} OR target_id = ${u}`;
  await tx.$executeRaw`DELETE FROM user_blocks WHERE blocker_id = ${u} OR blocked_id = ${u}`;
  await tx.$executeRaw`DELETE FROM user_mutes WHERE muter_id = ${u} OR muted_id = ${u}`;

  // -- Live: out of every room; the hosting permission, schedule, featured slot and suggestions go. Ended rooms,
  // gifts, scores and statistics stay (other hosts' history and the ledgers point at them).
  // A LIVE room of theirs (only possible on `purge-now`) is hidden by the ACTIVE-host filter and ended by the room
  // sweeper as HEARTBEAT_TIMEOUT, with its usual bookkeeping.
  await releaseUserIn(tx, userId, now, { moderator: true });
  await tx.$executeRaw`DELETE FROM live_hosts WHERE user_id = ${u}`;
  await tx.$executeRaw`DELETE FROM live_schedule_slots WHERE host_user_id = ${u}`;
  await tx.$executeRaw`DELETE FROM live_featured_hosts WHERE user_id = ${u}`;
  await tx.$executeRaw`DELETE FROM live_watch_suggestions WHERE user_id = ${u}`;
  await tx.$executeRaw`DELETE FROM live_chat_mutes WHERE user_id = ${u}`;

  // -- Family and CP couple.
  const familyKeys = await leaveFamilyIn(tx, userId, now);
  await tx.$executeRaw`
    UPDATE family_join_requests SET status = 'CANCELLED', handled_at = ${at}::timestamptz
     WHERE user_id = ${u} AND status = 'PENDING'`;
  await tx.$executeRaw`DELETE FROM family_chat_mutes WHERE user_id = ${u}`;
  const couple = await tx.cpPartner.findUnique({ where: { userId }, select: { coupleId: true } });
  if (couple) {
    await tx.cpPartner.deleteMany({ where: { coupleId: couple.coupleId } });
    await tx.cpCouple.update({ where: { id: couple.coupleId }, data: { endedAt: now, endedById: userId } });
  }
  // A recharge agent's employee leaves the job (the sales they made stay in the agent's ledger).
  await tx.$executeRaw`
    UPDATE recharge_employees SET removed_at = ${at}::timestamptz WHERE employee_user_id = ${u} AND removed_at IS NULL`;
  // A host leaves their agency (the link and its earnings stay as the agency's accounting).
  await tx.$executeRaw`
    UPDATE agency_hosts SET status = 'RELEASED', ended_at = ${at}::timestamptz
     WHERE host_user_id = ${u} AND status = 'ACTIVE'`;

  // -- Usernames: system codes (coin…/host…) held forever, other special and premium names end as usual; the
  // person's base username is replaced by the tombstone everywhere it was kept.
  await tx.$executeRaw`
    UPDATE special_usernames
       SET status = 'GRACE', ended_at = ${at}::timestamptz, end_reason = 'ACCOUNT_DELETED',
           grace_until = CASE WHEN source IN ('RECHARGE_AGENT', 'HOST_AGENT') THEN NULL
                              ELSE ${at}::timestamptz + make_interval(days => ${options.specialGraceDays}::int) END
     WHERE user_id = ${u} AND status = 'ACTIVE'`;
  await tx.$executeRaw`UPDATE special_usernames SET base_username = ${tombstone} WHERE user_id = ${u}`;
  await tx.$executeRaw`
    UPDATE premium_username_leases
       SET status = 'ENDED', ended_at = COALESCE(ended_at, ${at}::timestamptz),
           end_reason = COALESCE(end_reason, 'RELEASED'), grace_until = NULL, updated_at = ${at}::timestamptz
     WHERE user_id = ${u} AND status IN ('ACTIVE', 'GRACE')`;
  await tx.$executeRaw`UPDATE premium_username_leases SET regular_username = ${tombstone} WHERE user_id = ${u}`;
  if (regular !== null && isValidUsername(regular) && options.quarantineDays > 0) {
    const until = new Date(now.getTime() + options.quarantineDays * 86_400_000);
    await tx.$executeRaw`
      INSERT INTO deleted_usernames (name_hash, until) VALUES (${usernameHash(regular)}, ${until})
      ON CONFLICT (name_hash) DO UPDATE SET until = GREATEST(deleted_usernames.until, EXCLUDED.until)`;
  }

  // -- KYC: the recharge-agent applications keep their status and dates only (as the retention purge does).
  const kyc = await tx.rechargeAgentApplication.findMany({
    where: { userId },
    select: { photoKey: true, selfieKey: true },
  });
  await tx.$executeRaw`
    UPDATE recharge_agent_applications
       SET full_name = NULL, phone = NULL, photo_key = NULL, selfie_key = NULL, locations = NULL,
           payment_methods = NULL, purged_at = COALESCE(purged_at, ${at}::timestamptz)
     WHERE user_id = ${u}`;
  // -- KYC: v1.70-social (D206) the «افتح وكالة» applications keep the agency's name, country and dates only.
  const agencyKyc = await tx.agencyApplication.findMany({
    where: { userId },
    select: { photoKey: true, selfieKey: true },
  });
  await tx.$executeRaw`
    UPDATE agency_applications
       SET contact_value = NULL, bio = NULL, photo_key = NULL, selfie_key = NULL,
           purged_at = COALESCE(purged_at, ${at}::timestamptz)
     WHERE user_id = ${u}`;
  // -- KYC: v1.73-social (D209) «كن مضيفاً مع الإدارة» — a pending application is cancelled; every application keeps
  // its status, country and dates only.
  await cancelPendingHostApplicationIn(tx, userId, 'ACCOUNT', now);
  const hostKyc = await tx.hostApplication.findMany({
    where: { userId },
    select: { photoKey: true, selfieKey: true },
  });
  await tx.$executeRaw`
    UPDATE host_applications
       SET date_of_birth = NULL, contact_value = NULL, bio = NULL, links = '{}', photo_key = NULL,
           selfie_key = NULL, purged_at = COALESCE(purged_at, ${at}::timestamptz)
     WHERE user_id = ${u}`;
  // v1.80-kyc (D227): the identity checks (Didit) are deleted — the minimum we kept (name, birth date, document country,
  // document hash, reasons) goes with them; Didit's own copy follows the retention set in Didit's console.
  await purgeKycIn(tx, userId);
  // v1.74-social (D217): a referral keeps the install id and the mailbox hash (the one-reward-per-device and alias
  // checks), never the IP.
  await tx.$executeRaw`UPDATE referrals SET invitee_ip = NULL WHERE invitee_user_id = ${u}`;
  // v1.108-social (D343, §10.142): the mailbox's keyed hash stays SIGNUP_IDENTITY_RETENTION_DAYS from now (signing up
  // again with it earns no invite or recruit credit), then the referral sweeper deletes it. A supervisor attribution
  // (`staff_signup_recruits`) stays with the tombstone like the recruitments (no personal data in it).
  await tx.$executeRaw`UPDATE signup_email_marks SET purged_at = COALESCE(purged_at, ${at}::timestamptz) WHERE user_id = ${u}`;
  // Withdrawals stay for accounting; the payout details keep only their last 4 characters (to match bank records).
  await tx.$executeRaw`
    UPDATE cherry_withdrawals
       SET payout_details = '…' || right(payout_details, 4)
     WHERE user_id = ${u} AND payout_details NOT LIKE '…%'`;

  // -- Media: the photo first (its FK has no action), then every asset and upload of theirs except those still in use
  // by others (a family's emblem or cover, a home banner).
  await tx.$executeRaw`
    UPDATE user_profiles
       SET username = ${tombstone}, display_name = ${DELETED_DISPLAY_NAME}, bio = NULL, avatar_url = NULL,
           avatar_media_id = NULL, cover_url = NULL, cover_media_id = NULL, country_code = NULL, premium_tier = NULL, gender = NULL, show_gender = FALSE,
           account_category = NULL, updated_at = ${at}::timestamptz
     WHERE user_id = ${u}`;
  const assets = await tx.$queryRaw<{ large_key: string; thumb_key: string; poster_key: string | null }[]>`
    DELETE FROM media_assets a
     WHERE a.owner_id = ${u}
       AND NOT EXISTS (SELECT 1 FROM families f WHERE f.disbanded_at IS NULL
                         AND (f.emblem_media_id = a.id OR f.cover_media_id = a.id))
       AND NOT EXISTS (SELECT 1 FROM home_banners b WHERE b.media_id = a.id)
    RETURNING large_key, thumb_key, poster_key`;
  const uploads = await tx.$queryRaw<{ object_key: string }[]>`
    DELETE FROM media_uploads WHERE user_id = ${u} AND status <> 'COMPLETED' RETURNING object_key`;
  await tx.$executeRaw`DELETE FROM media_uploads WHERE user_id = ${u}`;

  // -- Account data.
  await tx.$executeRaw`DELETE FROM user_profile_links WHERE user_id = ${u}`;
  await tx.$executeRaw`DELETE FROM user_settings WHERE user_id = ${u}`;
  await tx.$executeRaw`DELETE FROM privacy_settings WHERE user_id = ${u}`;
  await tx.$executeRaw`DELETE FROM notification_settings WHERE user_id = ${u}`;
  await tx.$executeRaw`DELETE FROM sessions WHERE user_id = ${u}`;
  // v1.72-social (D208): the team's locks and restrictions (their reasons are free text about the person); the audit
  // rows keep what was done. Balance adjustments are financial and stay (blanked with the ledgers' retention).
  await tx.$executeRaw`DELETE FROM account_restrictions WHERE user_id = ${u}`;
  await tx.$executeRaw`DELETE FROM verification_tokens WHERE user_id = ${u}`;
  await tx.$executeRaw`DELETE FROM device_tokens WHERE user_id = ${u}`;
  // v1.66-social (D198): data exports are deleted with their files; consent records stay as the record of what was
  // accepted, without the truncated IP and the user agent (deleted with the tombstone's other records 7 years later).
  const exports = await tx.$queryRaw<{ object_key: string | null }[]>`
    DELETE FROM data_exports WHERE user_id = ${u} RETURNING object_key`;
  await tx.$executeRaw`UPDATE user_consents SET ip_truncated = NULL, user_agent = NULL WHERE user_id = ${u}`;
  await tx.$executeRaw`
    UPDATE users
       SET email = ${`deleted+${userId}@deleted.invalid`}, email_verified_at = NULL,
           password_hash = ${TOMBSTONE_PASSWORD_HASH}, status = 'DELETED', role = 'USER',
           deleted_at = ${at}::timestamptz, last_active_at = NULL, password_change_required_at = NULL,
           updated_at = ${at}::timestamptz
     WHERE id = ${u}`;
  // The audit log stays (7 years) without the IP addresses (dropped, not truncated: a /24 still narrows a home
  // connection down) and without usernames, emails or names in its metadata. audit_logs is append-only for the runtime
  // role: a SECURITY DEFINER function that acts only on a DELETED account (migration 20270110110000).
  await tx.$queryRaw`SELECT account_deletion_scrub_audit(${u}) AS n`;

  const request = await pendingRequestOf(tx, userId);
  if (request) {
    await tx.accountDeletionRequest.update({
      where: { id: request.id },
      data: { status: 'PURGED', purgedAt: now, purgedVia: options.via },
    });
  } else {
    // `purge-now` of an account that had no request: the record of the deletion is a PURGED row.
    await tx.accountDeletionRequest.create({
      data: {
        userId,
        status: 'PURGED',
        requestedVia: 'ADMIN',
        requestedAt: now,
        purgeAfter: now,
        purgedAt: now,
        purgedVia: options.via,
      },
    });
  }
  const objectKeys = [
    ...assets.flatMap((a) => [a.large_key, a.thumb_key, ...(a.poster_key ? [a.poster_key] : [])]),
    ...uploads.map((x) => x.object_key),
    ...kyc.flatMap((k) => [k.photoKey, k.selfieKey]).filter((k): k is string => k !== null),
    ...agencyKyc.flatMap((k) => [k.photoKey, k.selfieKey]).filter((k): k is string => k !== null),
    ...hostKyc.flatMap((k) => [k.photoKey, k.selfieKey]).filter((k): k is string => k !== null),
    ...familyKeys,
    ...exports.flatMap((x) => (x.object_key ? [x.object_key] : [])),
  ].filter((k) => !holds.objectKeys.has(k)); // files under a legal hold stay until the hold ends
  await tx.auditLog.create({
    data: {
      action: AuditAction.ACCOUNT_DELETION_PURGED,
      actorUserId: null,
      targetType: 'user',
      targetId: userId,
      metadata: {
        via: options.via === 'SWEEPER' ? 'sweeper' : 'cli',
        ...(options.reason ? { reason: options.reason } : {}),
        ...(request ? { requestId: request.id } : {}),
        objects: objectKeys.length,
        usernameQuarantined: regular !== null && options.quarantineDays > 0,
        held: holds.count,
      },
    },
  });
  return { userId, tombstoneUsername: tombstone, objectKeys, held: holds.count };
}

/**
 * Soft-deletes the person's live comments on others' posts with their replies and adjusts the counters (as
 * `CommentsService.removeIn` does for one; their own posts are gone already). Lock order: the post, then comments.
 */
async function softDeleteCommentsIn(tx: Tx, userId: string, now: Date): Promise<void> {
  const rows = await tx.$queryRaw<{ id: string; post_id: string }[]>`
    SELECT id::text AS id, post_id::text AS post_id FROM comments
     WHERE author_id = ${userId}::uuid AND deleted_at IS NULL
     ORDER BY post_id, parent_id NULLS FIRST, id`;
  for (const row of rows) {
    await tx.$queryRaw`SELECT 1 FROM posts WHERE id = ${row.post_id}::uuid FOR UPDATE`;
    const locked = await tx.$queryRaw<{ parent_id: string | null }[]>`
      SELECT parent_id::text AS parent_id FROM comments
       WHERE id = ${row.id}::uuid AND deleted_at IS NULL FOR UPDATE`;
    const comment = locked[0];
    if (!comment) continue; // a reply of a comment removed just before
    const replies = await tx.comment.updateMany({
      where: { parentId: row.id, deletedAt: null },
      data: { deletedAt: now, pinnedAt: null },
    });
    await tx.comment.update({ where: { id: row.id }, data: { deletedAt: now, pinnedAt: null } });
    await tx.$executeRaw`
      UPDATE posts SET comment_count = GREATEST(comment_count - ${1 + replies.count}::int, 0)
       WHERE id = ${row.post_id}::uuid`;
    if (comment.parent_id) {
      await tx.$executeRaw`
        UPDATE comments SET reply_count = GREATEST(reply_count - 1, 0) WHERE id = ${comment.parent_id}::uuid`;
    }
  }
}

/**
 * The person leaves their family. A leader hands the family to the longest-serving deputy (else member); a leader
 * alone disbands it (as `FamiliesService.disband`). Returns the object keys of a disbanded family's pictures.
 */
async function leaveFamilyIn(tx: Tx, userId: string, now: Date): Promise<string[]> {
  const member = await tx.familyMember.findUnique({
    where: { userId },
    select: { familyId: true, role: true },
  });
  if (!member) return [];
  await tx.$queryRaw`SELECT id FROM families WHERE id = ${member.familyId}::uuid FOR UPDATE`;
  await tx.familyMember.delete({ where: { userId } });
  const left = await tx.family.update({
    where: { id: member.familyId },
    data: { memberCount: { decrement: 1 }, updatedAt: now },
    select: { memberCount: true, emblemMediaId: true, coverMediaId: true },
  });
  if (member.role !== 'LEADER') return [];
  const [next] = await tx.$queryRaw<{ user_id: string }[]>`
    SELECT user_id::text AS user_id FROM family_members WHERE family_id = ${member.familyId}::uuid
     ORDER BY (role = 'DEPUTY'::family_role) DESC, joined_at, user_id LIMIT 1`;
  if (next) {
    await tx.familyMember.update({ where: { userId: next.user_id }, data: { role: 'LEADER' } });
    return [];
  }
  // Alone: disbanded (the row stays; its name becomes free), pending requests cancelled, pictures deleted.
  await tx.familyJoinRequest.updateMany({
    where: { familyId: member.familyId, status: 'PENDING' },
    data: { status: 'CANCELLED', handledAt: now },
  });
  await tx.family.update({
    where: { id: member.familyId },
    data: {
      disbandedAt: now,
      memberCount: 0,
      emblemMediaId: null,
      emblemUrl: null,
      coverMediaId: null,
      coverUrl: null,
      updatedAt: now,
    },
  });
  await tx.familyChatMute.deleteMany({ where: { familyId: member.familyId } });
  const ids = [left.emblemMediaId, left.coverMediaId].filter((x): x is string => x !== null);
  if (ids.length === 0) return [];
  const gone = await tx.$queryRaw<{ large_key: string; thumb_key: string }[]>`
    DELETE FROM media_assets WHERE id = ANY(${ids}::uuid[]) RETURNING large_key, thumb_key`;
  return gone.flatMap((g) => [g.large_key, g.thumb_key]);
}

export interface SweepOptions extends Omit<PurgeOptions, 'via' | 'reason'> {
  /** DELETED_LEDGER_RETENTION_DAYS: how long after the purge the tombstone's ledgers and audit rows are kept. */
  readonly ledgerRetentionDays: number;
}

export interface SweepResult {
  readonly purged: number;
  readonly released: number;
  /** Legal holds deleted (with their reports and files). */
  readonly holdsExpired: number;
  /** Tombstones whose retention period ended. */
  readonly retentionEnded: number;
}

/**
 * One sweep: purges the accounts whose grace period ended (oldest first), ends finished quarantines, deletes the legal
 * holds that ran out and ends the retention of tombstones purged more than DELETED_LEDGER_RETENTION_DAYS ago.
 */
export async function sweepAccountDeletions(
  prisma: PrismaClient,
  now: Date,
  options: SweepOptions,
  deleteObjects: (keys: string[]) => Promise<void>,
  limit = 50,
): Promise<SweepResult> {
  const due = await prisma.accountDeletionRequest.findMany({
    where: { status: 'PENDING', purgeAfter: { lte: now } },
    orderBy: [{ purgeAfter: 'asc' }, { id: 'asc' }],
    select: { userId: true },
    take: limit,
  });
  const { ledgerRetentionDays, ...purgeOptions } = options;
  let purged = 0;
  for (const d of due) {
    const result = await prisma.$transaction((tx) =>
      purgeAccountIn(tx, d.userId, now, { ...purgeOptions, via: 'SWEEPER' }),
    );
    if (!result) continue;
    purged++;
    await deleteObjects(result.objectKeys);
  }
  const released = await prisma.deletedUsername.deleteMany({ where: { until: { lte: now } } });
  const holdsExpired = await expireLegalHolds(prisma, now, deleteObjects, limit * 4);
  const retentionEnded = await endLedgerRetention(prisma, now, ledgerRetentionDays, limit);
  return { purged, released: released.count, holdsExpired, retentionEnded };
}

// ---------------------------------------------------------------------------------------------------------------
// Legal hold of reported content (owner 2026-10-31)

/** Report statuses that keep their content under a legal hold at the purge (a DISMISSED report does not). */
export const LEGAL_HOLD_REPORT_STATUSES = ['OPEN', 'ACTIONED'] as const;

/** When a hold made at `now` is deleted. */
export function legalHoldDeleteAfter(now: Date, days: number): Date {
  return new Date(now.getTime() + days * 86_400_000);
}

/** Content types a purge can hold: the person's own items that the purge deletes or blanks. */
export type HeldTargetType =
  | 'POST'
  | 'COMMENT'
  | 'STORY'
  | 'LIVE_CHAT_MESSAGE'
  | 'CP_CONFESSION'
  | 'FAMILY_CHAT_MESSAGE'
  | 'DM_MESSAGE'
  | 'PROFILE_LINK';

/** The report column naming each held type's target (DM and profile-link reports have no foreign key). */
const TARGET_COLUMN = {
  POST: 'targetPostId',
  COMMENT: 'targetCommentId',
  STORY: 'targetStoryId',
  LIVE_CHAT_MESSAGE: 'targetLiveChatMessageId',
  CP_CONFESSION: 'targetCpConfessionId',
  FAMILY_CHAT_MESSAGE: 'targetFamilyChatMessageId',
  DM_MESSAGE: 'targetDmMessageId',
  PROFILE_LINK: 'targetProfileLinkId',
} as const satisfies Record<HeldTargetType, keyof Prisma.ReportWhereInput>;

/** Types whose target row the purge deletes (or, for a comment, may delete): the report's id is moved to the hold. */
const DETACHED_TYPES: ReadonlySet<HeldTargetType> = new Set([
  'POST',
  'COMMENT',
  'STORY',
  'LIVE_CHAT_MESSAGE',
  'CP_CONFESSION',
  'FAMILY_CHAT_MESSAGE',
]);

interface MediaRow {
  kind: string;
  width: number;
  height: number;
  durationMs: number | null;
  largeKey: string;
  thumbKey: string;
  posterKey: string | null;
}

const MEDIA_SELECT = {
  kind: true,
  width: true,
  height: true,
  durationMs: true,
  largeKey: true,
  thumbKey: true,
  posterKey: true,
} as const;

const mediaKeys = (m: MediaRow): string[] => [m.largeKey, m.thumbKey, ...(m.posterKey ? [m.posterKey] : [])];
const iso = (d: Date | null): string | null => d?.toISOString() ?? null;

/** What a hold keeps of one item: its content without the author's identity (the hold row names the tombstone). */
async function heldSnapshotIn(
  tx: Tx,
  type: HeldTargetType,
  id: string,
): Promise<{ snapshot: Prisma.InputJsonObject; objectKeys: string[] } | null> {
  switch (type) {
    case 'POST': {
      const p = await tx.post.findUnique({
        where: { id },
        select: {
          text: true,
          format: true,
          location: true,
          status: true,
          moderation: true,
          createdAt: true,
          publishedAt: true,
          deletedAt: true,
          media: {
            select: { position: true, mediaAsset: { select: MEDIA_SELECT } },
            orderBy: { position: 'asc' },
          },
        },
      });
      if (!p) return null;
      const media = p.media.map((m) => ({ position: m.position, ...m.mediaAsset }));
      return {
        snapshot: {
          text: p.text,
          format: p.format,
          location: p.location,
          status: p.status,
          moderation: p.moderation,
          createdAt: p.createdAt.toISOString(),
          publishedAt: iso(p.publishedAt),
          deletedAt: iso(p.deletedAt),
          media,
        },
        objectKeys: media.flatMap(mediaKeys),
      };
    }
    case 'STORY': {
      const st = await tx.story.findUnique({
        where: { id },
        select: {
          text: true,
          createdAt: true,
          expiresAt: true,
          deletedAt: true,
          removedAt: true,
          mediaAsset: { select: MEDIA_SELECT },
        },
      });
      if (!st) return null;
      return {
        snapshot: {
          text: st.text,
          createdAt: st.createdAt.toISOString(),
          expiresAt: st.expiresAt.toISOString(),
          deletedAt: iso(st.deletedAt),
          removedAt: iso(st.removedAt),
          media: [st.mediaAsset],
        },
        objectKeys: mediaKeys(st.mediaAsset),
      };
    }
    case 'COMMENT': {
      const c = await tx.comment.findUnique({
        where: { id },
        select: { text: true, postId: true, parentId: true, createdAt: true, deletedAt: true },
      });
      if (!c) return null;
      return {
        snapshot: {
          text: c.text,
          postId: c.postId,
          parentId: c.parentId,
          createdAt: c.createdAt.toISOString(),
          deletedAt: iso(c.deletedAt),
        },
        objectKeys: [],
      };
    }
    case 'LIVE_CHAT_MESSAGE': {
      const m = await tx.liveChatMessage.findUnique({
        where: { id },
        select: {
          roomId: true,
          kind: true,
          text: true,
          createdAt: true,
          deletedAt: true,
          media: { select: MEDIA_SELECT },
        },
      });
      if (!m) return null;
      return {
        snapshot: {
          roomId: m.roomId,
          kind: m.kind,
          text: m.text,
          createdAt: m.createdAt.toISOString(),
          deletedAt: iso(m.deletedAt),
          media: m.media ? [m.media] : [],
        },
        objectKeys: m.media ? mediaKeys(m.media) : [],
      };
    }
    case 'CP_CONFESSION': {
      const c = await tx.cpConfession.findUnique({
        where: { id },
        select: { coupleId: true, text: true, createdAt: true, deletedAt: true },
      });
      if (!c) return null;
      return {
        snapshot: {
          coupleId: c.coupleId,
          text: c.text,
          createdAt: c.createdAt.toISOString(),
          deletedAt: iso(c.deletedAt),
        },
        objectKeys: [],
      };
    }
    case 'FAMILY_CHAT_MESSAGE': {
      const f = await tx.familyChatMessage.findUnique({
        where: { id },
        select: { familyId: true, text: true, createdAt: true, deletedAt: true },
      });
      if (!f) return null;
      return {
        snapshot: {
          familyId: f.familyId,
          text: f.text,
          createdAt: f.createdAt.toISOString(),
          deletedAt: iso(f.deletedAt),
        },
        objectKeys: [],
      };
    }
    case 'DM_MESSAGE':
    case 'PROFILE_LINK': {
      // No row to read (a DM lives 24 h; a link may have been edited): the reports' own snapshots, and their files.
      const reports = await tx.report.findMany({
        where: { [TARGET_COLUMN[type]]: id },
        orderBy: [{ createdAt: 'asc' }, { id: 'asc' }],
        select: { dmSnapshot: true, linkSnapshot: true },
      });
      const first = reports[0];
      if (!first) return null;
      const raw = (type === 'DM_MESSAGE' ? first.dmSnapshot : first.linkSnapshot) as Record<
        string,
        unknown
      > | null;
      const keep =
        type === 'DM_MESSAGE'
          ? ['kind', 'text', 'token', 'conversationId', 'sentAt', 'mediaKey', 'giftCode', 'quantity']
          : ['url', 'label'];
      const snapshot: Record<string, Prisma.InputJsonValue | null> = {};
      for (const k of keep) snapshot[k] = raw?.[k] ?? null;
      const objectKeys =
        type === 'DM_MESSAGE'
          ? // v1.93-social (D296): the frozen conversation's files too, so the hold deletes them with it.
            reports.flatMap((r) => dmSnapshotObjectKeys(r.dmSnapshot))
          : [];
      return { snapshot, objectKeys };
    }
  }
}

/**
 * Puts `userId`'s reported content under a legal hold, inside the purge's transaction and before anything is deleted:
 * every item of theirs with at least one OPEN or ACTIONED report becomes one `legal_holds` row (a snapshot of the
 * content and the keys of its files, linked to the tombstone id; `delete_after` = now + `holdDays`), and every report
 * of that item (whatever its status) is linked to the hold — for a post, comment, story, live-chat, family-chat or
 * CP-confession message its target id is moved to the hold, so the purge's deletes do not cascade into it. Returns the
 * number of holds and the files to keep.
 */
export async function holdReportedContentIn(
  tx: Tx,
  userId: string,
  now: Date,
  holdDays: number,
): Promise<{ count: number; objectKeys: Set<string> }> {
  const u = Prisma.sql`${userId}::uuid`;
  const targets = await tx.$queryRaw<{ target_type: HeldTargetType; target_id: string }[]>`
    SELECT DISTINCT r.target_type::text AS target_type,
           COALESCE(r.target_post_id, r.target_comment_id, r.target_story_id, r.target_live_chat_message_id,
                    r.target_cp_confession_id, r.target_family_chat_message_id, r.target_dm_message_id,
                    r.target_profile_link_id)::text AS target_id
      FROM reports r
     WHERE r.status IN ('OPEN'::report_status, 'ACTIONED'::report_status)
       AND r.legal_hold_id IS NULL
       AND (r.target_post_id IN (SELECT id FROM posts WHERE author_id = ${u})
            OR r.target_comment_id IN (SELECT id FROM comments WHERE author_id = ${u})
            OR r.target_story_id IN (SELECT id FROM stories WHERE author_id = ${u})
            OR r.target_live_chat_message_id IN (SELECT id FROM live_chat_messages WHERE user_id = ${u})
            OR r.target_cp_confession_id IN (SELECT id FROM cp_confessions WHERE author_id = ${u})
            OR r.target_family_chat_message_id IN (SELECT id FROM family_chat_messages WHERE author_id = ${u})
            OR (r.target_type = 'DM_MESSAGE'::report_target_type AND r.dm_snapshot->>'senderId' = ${userId})
            OR (r.target_type = 'PROFILE_LINK'::report_target_type AND r.link_snapshot->>'userId' = ${userId}))
     ORDER BY 1, 2`;
  const kept = new Set<string>();
  let count = 0;
  for (const t of targets) {
    const held = await heldSnapshotIn(tx, t.target_type, t.target_id);
    if (!held) continue;
    const hold = await tx.legalHold.create({
      data: {
        userId,
        targetType: t.target_type,
        targetId: t.target_id,
        snapshot: held.snapshot,
        objectKeys: [...new Set(held.objectKeys)],
        heldAt: now,
        deleteAfter: legalHoldDeleteAfter(now, holdDays),
      },
      select: { id: true },
    });
    const column = TARGET_COLUMN[t.target_type];
    await tx.report.updateMany({
      where: { [column]: t.target_id },
      data: { legalHoldId: hold.id, ...(DETACHED_TYPES.has(t.target_type) ? { [column]: null } : {}) },
    });
    for (const k of held.objectKeys) kept.add(k);
    count++;
  }
  return { count, objectKeys: kept };
}

/**
 * Deletes the legal holds whose `delete_after` passed (oldest first), each with its reports (the foreign key cascades)
 * in its own transaction, then their files. One audit row per hold (`account.deletion.hold_expired`: the hold id, the
 * type and the counts; no user).
 */
export async function expireLegalHolds(
  prisma: PrismaClient,
  now: Date,
  deleteObjects: (keys: string[]) => Promise<void>,
  limit = 200,
): Promise<number> {
  const due = await prisma.legalHold.findMany({
    where: { deleteAfter: { lte: now } },
    orderBy: [{ deleteAfter: 'asc' }, { id: 'asc' }],
    select: { id: true },
    take: limit,
  });
  let expired = 0;
  for (const d of due) {
    const gone = await prisma.$transaction(async (tx) => {
      const hold = await tx.legalHold.findUnique({
        where: { id: d.id },
        select: { targetType: true, objectKeys: true, deleteAfter: true },
      });
      if (!hold || hold.deleteAfter > now) return null;
      const reports = await tx.report.count({ where: { legalHoldId: d.id } });
      await tx.legalHold.delete({ where: { id: d.id } });
      await tx.auditLog.create({
        data: {
          action: AuditAction.ACCOUNT_DELETION_HOLD_EXPIRED,
          actorUserId: null,
          targetType: 'legal_hold',
          targetId: d.id,
          metadata: { via: 'sweeper', heldType: hold.targetType, reports, objects: hold.objectKeys.length },
        },
      });
      return hold;
    });
    if (!gone) continue;
    expired++;
    if (gone.objectKeys.length > 0) await deleteObjects(gone.objectKeys);
  }
  return expired;
}

// ---------------------------------------------------------------------------------------------------------------
// Retention of the ledgers and audit rows kept under a tombstone (owner 2026-10-31: 7 years)

/** Tombstones purged at or before this moment reached the end of their retention. */
export function ledgerRetentionCutoff(now: Date, days: number): Date {
  return new Date(now.getTime() - days * 86_400_000);
}

/**
 * Ends the retention of tombstones purged more than `retentionDays` ago, one transaction each. Deleted: the audit rows
 * whose actor or target user is the tombstone, its deletion requests (the record of the deletion) and its 18+
 * statement. Anonymised: cherry withdrawals keep amounts and dates only (payout details `…`, decision note removed),
 * admin reasons on its points ledger are blanked. The money rows other people's balances and the company's books
 * depend on (wallets and ledgers, gifts, transfers, sales, earnings) stay under the tombstone's random id, which no
 * longer leads to anything about the person. One aggregate audit row per sweep (`account.deletion.retention_ended`,
 * a count only).
 */
export async function endLedgerRetention(
  prisma: PrismaClient,
  now: Date,
  retentionDays: number,
  limit = 50,
): Promise<number> {
  const cutoff = ledgerRetentionCutoff(now, retentionDays);
  const due = await prisma.accountDeletionRequest.findMany({
    where: { status: 'PURGED', purgedAt: { lte: cutoff } },
    orderBy: [{ purgedAt: 'asc' }, { id: 'asc' }],
    select: { userId: true },
    take: limit,
  });
  let ended = 0;
  for (const userId of [...new Set(due.map((d) => d.userId))]) {
    const done = await prisma.$transaction(async (tx) => {
      const user = await lockUser(tx, userId);
      if (user?.status !== 'DELETED') return false;
      await tx.$queryRaw`SELECT account_deletion_end_retention(${userId}::uuid, ${cutoff}::timestamptz) AS n`;
      await tx.cherryWithdrawal.updateMany({
        where: { userId },
        data: { payoutDetails: '…', decisionNote: null },
      });
      await tx.luckyGiftAgeConfirmation.deleteMany({ where: { userId } });
      // v1.66-social (D198): the consent records go with the rest of the trail.
      await tx.userConsent.deleteMany({ where: { userId } });
      // v1.72-social (D208): the team's balance adjustments keep their amounts; the reason text goes.
      await tx.adminBalanceAdjustment.updateMany({ where: { userId }, data: { reason: '…' } });
      await tx.accountDeletionRequest.deleteMany({ where: { userId } });
      return true;
    });
    if (done) ended++;
  }
  if (ended > 0) {
    await prisma.auditLog.create({
      data: {
        action: AuditAction.ACCOUNT_DELETION_RETENTION_ENDED,
        actorUserId: null,
        metadata: { via: 'sweeper', tombstones: ended, retentionDays },
      },
    });
  }
  return ended;
}
