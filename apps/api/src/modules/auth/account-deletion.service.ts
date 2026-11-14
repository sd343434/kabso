import { Inject, Injectable, Logger, type OnModuleDestroy, type OnModuleInit } from '@nestjs/common';
import { z } from 'zod';
import { AuditAction, AuditService } from '../../common/audit/audit.service.js';
import { BackgroundTasks } from '../../common/background/background-tasks.js';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { Clock } from '../../common/time/clock.js';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import { safeErrorLog } from '../../logging/redact-text.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { MAIL_SENDER, type MailSender } from '../mail/mail-sender.js';
import { MediaService } from '../media/media.service.js';
import {
  cancelDeletionIn,
  deletionBlockersIn,
  requestDeletionIn,
  sweepAccountDeletions,
  type SweepResult,
  type DeletionBlocker,
} from '../users/account-deletion.js';
import { normalizePassword } from './auth.schemas.js';
import type { RequestMeta } from './auth.service.js';
import { PasswordHasher } from './password-hasher.service.js';

/** The words the person types to confirm (either language; case and spaces around ignored). */
export const DELETION_CONFIRMATION_WORDS = ['حذف', 'DELETE'] as const;

/** `AccountDeletionRequestBody` (openapi v1.62-social). */
export const accountDeletionSchema = z.strictObject({
  password: z
    .string()
    .min(1)
    .max(512)
    .transform(normalizePassword)
    .refine((v) => [...v].length <= 128, { params: { issue: 'too_long' } }),
  confirmation: z
    .string()
    .trim()
    .min(1)
    .max(20)
    .refine((v) => DELETION_CONFIRMATION_WORDS.some((w) => w.toUpperCase() === v.toUpperCase()), {
      params: { issue: 'invalid_value' },
    }),
});
export type AccountDeletionInput = z.output<typeof accountDeletionSchema>;

/** `AccountDeletionInfo` (openapi): what the explanation screen shows before the person starts. */
export interface AccountDeletionInfoDto {
  graceDays: number;
  /** What must be settled first (empty: the account can be deleted now). */
  blockers: DeletionBlocker[];
  /** Where to write for help, or to ask for deletion without the app. */
  supportEmail: string;
}

/** `AccountDeletionRequest` (openapi). */
export interface AccountDeletionRequestDto {
  status: 'PENDING';
  requestedAt: string;
  purgeAfter: string;
}

/**
 * v1.62-social (D193, CONVENTIONS §10.56): the in-app account deletion «حذف الحساب» — the explanation's data, the
 * request (password re-checked, confirmation word typed, nothing to settle), the cancellation at sign-in, and the
 * notices by mail. The rules themselves are in `users/account-deletion.ts` (shared with the CLI).
 */
@Injectable()
export class AccountDeletionService {
  private readonly logger = new Logger(AccountDeletionService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly passwords: PasswordHasher,
    private readonly audit: AuditService,
    private readonly clock: Clock,
    private readonly background: BackgroundTasks,
    @Inject(MAIL_SENDER) private readonly mail: MailSender,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
  ) {}

  /** `GET /me/account-deletion`. */
  async info(userId: string): Promise<AccountDeletionInfoDto> {
    return {
      graceDays: this.config.accountDeletion.graceDays,
      blockers: await deletionBlockersIn(this.prisma, userId),
      supportEmail: this.config.accountDeletion.supportEmail,
    };
  }

  /**
   * `POST /me/account-deletion`. Order: 400 body (the confirmation word) → 403 REAUTH_FAILED (wrong password,
   * audited) → 409 ACCOUNT_DELETION_BLOCKED (`details[].issue` per blocker, audited) → 202. Idempotent: a repeated
   * call for an account already pending returns the same request (the sessions are already gone, so in practice
   * only a racing retry gets here).
   */
  async request(
    userId: string,
    input: AccountDeletionInput,
    meta: RequestMeta,
  ): Promise<AccountDeletionRequestDto> {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { passwordHash: true, email: true, profile: { select: { locale: true } } },
    });
    if (!user) throw new AppException(ErrorCode.AUTH_UNAUTHENTICATED);
    if (!(await this.passwords.verify(user.passwordHash, input.password))) {
      await this.audit.record({
        action: AuditAction.ACCOUNT_DELETION_REAUTH_FAILED,
        actorUserId: userId,
        targetType: 'user',
        targetId: userId,
        ip: meta.ip,
        requestId: meta.requestId,
      });
      throw new AppException(ErrorCode.REAUTH_FAILED);
    }
    const now = this.clock.now();
    const outcome = await this.prisma.$transaction((tx) =>
      requestDeletionIn(tx, userId, now, this.config.accountDeletion.graceDays, {
        via: 'APP',
        ip: meta.ip,
        requestId: meta.requestId,
      }),
    );
    switch (outcome.outcome) {
      case 'not_active':
        throw new AppException(ErrorCode.AUTH_UNAUTHENTICATED);
      case 'blocked':
        await this.audit.record({
          action: AuditAction.ACCOUNT_DELETION_BLOCKED,
          actorUserId: userId,
          targetType: 'user',
          targetId: userId,
          metadata: { blockers: outcome.blockers },
          ip: meta.ip,
          requestId: meta.requestId,
        });
        throw new AppException(
          ErrorCode.ACCOUNT_DELETION_BLOCKED,
          undefined,
          outcome.blockers.map((issue) => ({ field: 'account', issue })),
        );
      case 'already_pending':
        return toDto(outcome.request);
      case 'requested': {
        const locale = user.profile?.locale === 'en' ? 'en' : 'ar';
        this.notify(user.email, locale, 'requested', outcome.request.purgeAfter);
        return toDto(outcome.request);
      }
    }
  }

  /** When an account in its grace period may be purged (null: not pending). */
  async purgeAfterOf(userId: string): Promise<Date | null> {
    const row = await this.prisma.accountDeletionRequest.findFirst({
      where: { userId, status: 'PENDING' },
      select: { purgeAfter: true },
    });
    return row?.purgeAfter ?? null;
  }

  /** Sign-in with `cancelDeletion: true` (the password was checked by the caller): ACTIVE again, notice sent. */
  async cancelAtSignIn(userId: string, meta: RequestMeta): Promise<boolean> {
    const cancelled = await this.prisma.$transaction((tx) =>
      cancelDeletionIn(tx, userId, this.clock.now(), { via: 'APP', ip: meta.ip, requestId: meta.requestId }),
    );
    if (cancelled) {
      const user = await this.prisma.user.findUnique({
        where: { id: userId },
        select: { email: true, profile: { select: { locale: true } } },
      });
      if (user) this.notify(user.email, user.profile?.locale === 'en' ? 'en' : 'ar', 'cancelled', null);
    }
    return cancelled;
  }

  /** The notice is sent after the response; a delivery failure never fails the request. */
  private notify(
    to: string,
    locale: 'ar' | 'en',
    kind: 'requested' | 'cancelled',
    purgeAfter: Date | null,
  ): void {
    const supportEmail = this.config.accountDeletion.supportEmail;
    this.background.run(`account.deletion.${kind}.mail`, async () => {
      try {
        await this.mail.sendAccountDeletionNotice({ to, locale, kind, purgeAfter, supportEmail });
      } catch (err) {
        this.logger.error({ error: safeErrorLog(err), kind }, 'Account-deletion notice not delivered');
      }
    });
  }
}

function toDto(request: { requestedAt: Date; purgeAfter: Date }): AccountDeletionRequestDto {
  return {
    status: 'PENDING',
    requestedAt: request.requestedAt.toISOString(),
    purgeAfter: request.purgeAfter.toISOString(),
  };
}

/**
 * D193: purges the accounts whose grace period ended, ends finished username quarantines, deletes legal holds that ran
 * out (REPORT_LEGAL_HOLD_DAYS) and ends the retention of old tombstones (DELETED_LEDGER_RETENTION_DAYS), every
 * `ACCOUNT_DELETION_SWEEP_INTERVAL_SECONDS` (0: off — tests; refused in production). Objects are deleted from storage
 * after each purge commits (a storage failure is logged by MediaService; the rows are already gone).
 */
@Injectable()
export class AccountDeletionSweeper implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(AccountDeletionSweeper.name);
  private timer: NodeJS.Timeout | null = null;
  private inFlight: Promise<unknown> | null = null;

  constructor(
    private readonly prisma: PrismaService,
    private readonly clock: Clock,
    private readonly media: MediaService,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
  ) {}

  onModuleInit(): void {
    if (this.config.accountDeletion.sweepIntervalSeconds > 0) this.schedule();
  }

  async onModuleDestroy(): Promise<void> {
    if (this.timer) clearTimeout(this.timer);
    await this.inFlight?.catch(() => undefined);
  }

  /** One step (also the tests' entry, with a moved clock). */
  sweep(now: Date = this.clock.now()): Promise<SweepResult> {
    return sweepAccountDeletions(
      this.prisma,
      now,
      {
        quarantineDays: this.config.accountDeletion.usernameQuarantineDays,
        specialGraceDays: this.config.specialUsernames.graceDays,
        legalHoldDays: this.config.accountDeletion.legalHoldDays,
        ledgerRetentionDays: this.config.accountDeletion.ledgerRetentionDays,
      },
      (keys) => this.media.deleteObjects(keys),
    );
  }

  private schedule(): void {
    this.timer = setTimeout(() => {
      this.inFlight = this.sweep()
        .then((r) => {
          if (r.purged + r.released + r.holdsExpired + r.retentionEnded > 0)
            this.logger.log(r, 'Account deletions swept');
        })
        .catch((err: unknown) => {
          this.logger.error({ error: safeErrorLog(err) }, 'Account-deletion sweep failed');
        })
        .finally(() => {
          this.inFlight = null;
          this.schedule();
        });
    }, this.config.accountDeletion.sweepIntervalSeconds * 1000);
    this.timer.unref();
  }
}
