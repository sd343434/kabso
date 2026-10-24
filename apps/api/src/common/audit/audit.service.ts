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
