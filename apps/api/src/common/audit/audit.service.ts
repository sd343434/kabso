import { Injectable, Logger } from '@nestjs/common';
import type { Prisma } from '../../generated/prisma/client.js';
import { PrismaService } from '../../prisma/prisma.service.js';

export enum AuditAction {
  REGISTER = 'auth.register',
  LOGIN_SUCCESS = 'auth.login.success',
  LOGIN_FAILURE = 'auth.login.failure',
  LOGOUT = 'auth.logout',
  REFRESH_REUSE = 'auth.refresh.reuse',
  EMAIL_VERIFIED = 'auth.email.verified',
  PASSWORD_RESET_REQUESTED = 'auth.password.reset_requested',
  PASSWORD_RESET = 'auth.password.reset',
  SESSION_REVOKED = 'auth.session.revoke',
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

/** Append-only security audit trail. Failures to write are logged, never surfaced. */
@Injectable()
export class AuditService {
  private readonly logger = new Logger(AuditService.name);

  constructor(private readonly prisma: PrismaService) {}

  async record(entry: AuditEntry): Promise<void> {
    try {
      await this.prisma.auditLog.create({
        data: {
          action: entry.action,
          actorUserId: entry.actorUserId ?? null,
          targetType: entry.targetType ?? null,
          targetId: entry.targetId ?? null,
          ...(entry.metadata ? { metadata: entry.metadata } : {}),
          ip: entry.ip?.slice(0, 64) ?? null,
          requestId: entry.requestId ?? null,
        },
      });
    } catch (err) {
      this.logger.error(
        { err: { message: (err as Error).message }, action: entry.action },
        'Audit write failed',
      );
    }
  }
}
