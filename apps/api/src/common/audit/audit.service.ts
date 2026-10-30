import { Injectable, Logger } from '@nestjs/common';
import { safeErrorLog } from '../../logging/redact-text.js';
import type { Prisma } from '../../generated/prisma/client.js';
import { PrismaService } from '../../prisma/prisma.service.js';

export enum AuditAction {
  // Verify-first registration (contract v1.2 §6). Namespaced `auth.` like every other action.
  REGISTRATION_PENDING_CREATED = 'auth.registration.pending_created',
  REGISTRATION_REPLACED = 'auth.registration.replaced',
  REGISTRATION_VERIFIED = 'auth.registration.verified',
  REGISTRATION_VERIFY_FAILED = 'auth.registration.verify_failed',
  REGISTRATION_EXISTING_EMAIL_NOTICE = 'auth.registration.existing_email_notice',
  LOGIN_SUCCESS = 'auth.login.success',
  LOGIN_FAILURE = 'auth.login.failure',
  LOGIN_RATE_LIMITED = 'auth.login.rate_limited',
  LOGOUT = 'auth.logout',
  REFRESH_REUSE = 'auth.refresh.reuse',
  /** CONVENTIONS §6 `refresh.invalid_secret` (namespaced like every other auth action). */
  REFRESH_INVALID_SECRET = 'auth.refresh.invalid_secret',
  EMAIL_VERIFIED = 'auth.email.verified',
  PASSWORD_RESET_REQUESTED = 'auth.password.reset_requested',
  PASSWORD_RESET = 'auth.password.reset',
  SESSION_REVOKED = 'auth.session.revoke',
  // Contract v1.3 (CONVENTIONS §10.3). Heartbeats are not audited.
  LIVE_ROOM_START = 'live.room.start',
  /** Host end or suspension; `metadata.reason` carries the end reason. */
  LIVE_ROOM_END = 'live.room.end',
  /** Ended for a stale heartbeat (sweeper or a read path). */
  LIVE_ROOM_TIMEOUT = 'live.room.timeout',
  // v1.6-live (DRAFT, CP-010): the hosting permission and the room's guests switch.
  LIVE_HOST_GRANT = 'live.host.grant',
  LIVE_HOST_REVOKE = 'live.host.revoke',
  LIVE_ROOM_GUESTS = 'live.room.guests',
  // v1.9-live (DRAFT, CP-013): the host turned the room chat off or on.
  LIVE_ROOM_CHAT = 'live.room.chat',
  // v1.10-live (DRAFT, CP-014): the host edited the live's title, category or topic.
  LIVE_ROOM_EDIT = 'live.room.edit',
  // v1.11-live (DRAFT, CP-015): the host set or removed the live cover.
  LIVE_COVER_UPDATE = 'live.cover.update',
  // v1.12-live (DRAFT, CP-016 B): the host replaced their blocked words (the count is logged).
  LIVE_BLOCKED_WORDS_UPDATE = 'live.blocked_words.update',
  // v1.14-live (DRAFT, CP-016 C): the host announced or cancelled a scheduled live.
  LIVE_SCHEDULE_CREATE = 'live.schedule.create',
  LIVE_SCHEDULE_DELETE = 'live.schedule.delete',
  // v1.20-live (DRAFT, D105): the host or a moderator kicked someone out of a live, or undid it.
  LIVE_KICK = 'live.kick',
  LIVE_KICK_UNDO = 'live.kick.undo',
  // v1.4-levels (DRAFT, CP-005): every admin mutation of the level systems.
  LEVELS_CATEGORY_UPDATE = 'levels.category.update',
  LEVELS_VERSION_CREATE = 'levels.version.create',
  LEVELS_VERSION_UPDATE = 'levels.version.update',
  LEVELS_VERSION_PUBLISH = 'levels.version.publish',
  LEVELS_USER_RECALCULATE = 'levels.user.recalculate',
  LEVELS_USER_ADJUST = 'levels.user.adjust',
  LEVELS_RECONCILIATION_RUN = 'levels.reconciliation.run',
  LEVELS_EVENT_RETRY = 'levels.event.retry',
  LEVELS_PERMISSION_GRANT = 'levels.permission.grant',
  LEVELS_PERMISSION_REVOKE = 'levels.permission.revoke',
  // v1.5-social (CP-006 M1): moderation of reports (CONVENTIONS §11.7).
  MODERATION_REPORT_ACTION = 'moderation.report.action',
  // v1.19-live (DRAFT, CP-017): coins granted or taken back by an admin (`wallet-admin`).
  WALLET_GRANT = 'wallet.grant',
  WALLET_REVOKE = 'wallet.revoke',
  /** v1.21-live (CP-018): a family was created, handed over, disbanded, or a member removed. */
  FAMILY_CREATE = 'family.create',
  FAMILY_TRANSFER = 'family.transfer',
  FAMILY_DISBAND = 'family.disband',
  FAMILY_MEMBER_REMOVE = 'family.member.remove',
  /** v1.21-live (CP-018): `medals-admin backfill` ran. */
  MEDALS_BACKFILL = 'medals.backfill',
  /** v1.22-live (CP-019): a bag item granted or taken back by an admin (`bag-admin`). */
  BAG_GRANT = 'bag.grant',
  BAG_REVOKE = 'bag.revoke',
  /** v1.23-live (CP-020, D108): the gift catalogue and gift-bag grants (`gift-admin` CLI). */
  GIFT_ADD = 'gift.add',
  GIFT_UPDATE = 'gift.update',
  GIFT_DISABLE = 'gift.disable',
  GIFT_ENABLE = 'gift.enable',
  GIFT_GRANT = 'gift.grant',
  // D124 (v1.26-live): home banners, changed only by the banner-admin CLI.
  BANNER_ADD = 'banner.add',
  BANNER_ENABLE = 'banner.enable',
  BANNER_DISABLE = 'banner.disable',
  BANNER_REMOVE = 'banner.remove',
  /** v1.27-live (D132): the caller's one-time 18+ statement for lucky gifts. */
  LUCKY_AGE_CONFIRM = 'lucky.age_confirm',
  /** v1.27.1-live (D133): featured hosts, changed only by the feature-admin CLI. */
  LIVE_FEATURE_ADD = 'live.feature.add',
  LIVE_FEATURE_REMOVE = 'live.feature.remove',
  /** v1.33-live (D154b): traffic cards granted by the boost-admin CLI. */
  LIVE_BOOST_CARD_GRANT = 'live.boost_card.grant',
  /** v1.44-social (D166): events and tasks, changed only by the event-admin and task-admin CLIs. */
  EVENT_CREATE = 'event.create',
  EVENT_END = 'event.end',
  EVENT_HOLD = 'event.hold',
  EVENT_RELEASE = 'event.release',
  /** v1.50-social (D176): an event's calendar line, tone or «رائج» changed. */
  EVENT_STYLE = 'event.style',
  TASK_UPDATE = 'task.update',
  /** v1.52-social (D179): the cherry economy — agencies, complaints, withdrawals, reversals. */
  AGENCY_CREATE = 'agency.create',
  AGENCY_PARENT = 'agency.parent',
  AGENCY_JOIN = 'agency.join',
  AGENCY_LEAVE = 'agency.leave',
  AGENCY_COMPLAINT = 'agency.complaint',
  AGENCY_COMPLAINT_RESOLVE = 'agency.complaint.resolve',
  CHERRY_WITHDRAWAL_REQUEST = 'cherry.withdrawal.request',
  CHERRY_WITHDRAWAL_PAY = 'cherry.withdrawal.pay',
  CHERRY_WITHDRAWAL_REJECT = 'cherry.withdrawal.reject',
  CHERRY_GIFT_REVERSE = 'cherry.gift.reverse',
  // v1.28-live (DRAFT, D146): premium usernames and the username change (CONVENTIONS §10.32).
  USERNAME_CHANGE = 'user.username.change',
  /** v1.45-social (D168): the caller changed their display name and/or bio (field names only). */
  PROFILE_UPDATE = 'user.profile.update',
  /** v1.45-social (D168): the caller set or removed their profile photo. */
  AVATAR_UPDATE = 'user.avatar.update',
  /** v1.47-social (D175): the user switched their account private or public. */
  PRIVACY_PRIVATE = 'user.privacy.private',
  /** v1.47-social (D175): an admin removed a user's profile photo (`profile-admin remove-avatar`). */
  ADMIN_AVATAR_REMOVE = 'admin.avatar.remove',
  PREMIUM_USERNAME_RENT = 'premium_username.rent',
  PREMIUM_USERNAME_RENEW = 'premium_username.renew',
  PREMIUM_USERNAME_GRANT = 'premium_username.grant',
  PREMIUM_USERNAME_REVOKE = 'premium_username.revoke',
  PREMIUM_USERNAME_RELEASE = 'premium_username.release',
  PREMIUM_USERNAME_EXPIRE = 'premium_username.expire',
  PREMIUM_USERNAME_GRACE_END = 'premium_username.grace_end',
  PREMIUM_USERNAME_PRICE = 'premium_username.price',
  PREMIUM_USERNAME_RESERVE = 'premium_username.reserve',
  // v1.29-live (DRAFT, D147): search trends, changed only by the search-admin CLI (§11.11).
  SEARCH_TERM_HIDE = 'search.term.hide',
  SEARCH_BLOCKED_WORD = 'search.blocked_word',
}

export interface AuditEntry {
  readonly action: AuditAction;
  readonly actorUserId?: string | null;
  readonly targetType?: string;
  readonly targetId?: string;
  /** Never put secrets (passwords, tokens) or raw identifiers here. */
  readonly metadata?: Prisma.InputJsonObject;
  readonly ip?: string | null;
  readonly requestId?: string | null;
}

function toRow(entry: AuditEntry): Prisma.AuditLogUncheckedCreateInput {
  return {
    action: entry.action,
    actorUserId: entry.actorUserId ?? null,
    targetType: entry.targetType ?? null,
    targetId: entry.targetId ?? null,
    ...(entry.metadata ? { metadata: entry.metadata } : {}),
    ip: entry.ip?.slice(0, 64) ?? null,
    requestId: entry.requestId ?? null,
  };
}

/** Append-only security audit trail. Failures to write are logged, never surfaced. */
@Injectable()
export class AuditService {
  private readonly logger = new Logger(AuditService.name);

  constructor(private readonly prisma: PrismaService) {}

  async record(entry: AuditEntry): Promise<void> {
    try {
      await this.prisma.auditLog.create({ data: toRow(entry) });
    } catch (err) {
      this.logger.error({ error: safeErrorLog(err), action: entry.action }, 'Audit write failed');
    }
  }

  /** Writes inside the caller's transaction (a failure aborts the transaction). */
  async recordIn(tx: Prisma.TransactionClient, entry: AuditEntry): Promise<void> {
    await tx.auditLog.create({ data: toRow(entry) });
  }

  /** Writes several entries inside the caller's transaction. */
  async recordManyIn(tx: Prisma.TransactionClient, entries: readonly AuditEntry[]): Promise<void> {
    if (entries.length === 0) return;
    await tx.auditLog.createMany({ data: entries.map(toRow) });
  }
}
