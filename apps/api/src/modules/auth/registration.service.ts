import { createHmac, hkdfSync, randomInt } from 'node:crypto';
import { Inject, Injectable, Logger, type OnModuleDestroy, type OnModuleInit } from '@nestjs/common';
import { AuditAction, AuditService } from '../../common/audit/audit.service.js';
import { BackgroundTasks } from '../../common/background/background-tasks.js';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { RateLimitService } from '../../common/rate-limit/rate-limit.service.js';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import { safeErrorLog } from '../../logging/redact-text.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { MAIL_SENDER, type MailLocale, type MailSender } from '../mail/mail-sender.js';
import { containsReservedTerm } from '../users/confusables.js';
import { isReservedUsername } from '../users/username.js';
import { toMeDto, UsersService, violatedUniqueIndex, type MailRecipient } from '../users/users.service.js';
import type { RegisterInput, RegisterVerifyInput } from './auth.schemas.js';
import { AuthService, type AuthResponseDto, type RequestMeta } from './auth.service.js';
import { PasswordHasher } from './password-hasher.service.js';
import { SessionsService } from './sessions.service.js';
import { hashesEqual } from './tokens.js';

/** Constant 202 body (contract v1.2 §6). */
export const VERIFICATION_PENDING = { status: 'verification_pending' } as const;
export type VerificationPendingDto = typeof VERIFICATION_PENDING;

/** Code checks per pending registration before it is deleted (contract: 5). */
export const MAX_CODE_ATTEMPTS = 5;
const CODE_DIGITS = 8;

/** Internal (never returned) reasons for `auth.registration.verify_failed`. */
type VerifyFailure =
  'no_live_pending' | 'wrong_code' | 'attempts_exhausted' | 'email_registered' | 'concurrent_verify';

interface ClaimedPending {
  id: string;
  code_hash: string;
  attempts: number;
  username: string;
  display_name: string;
  locale: string;
  password_hash: string;
  device_name: string | null;
  platform: string | null;
  app_version: string | null;
}

class VerifyFailed extends Error {
  constructor(readonly reason: VerifyFailure) {
    super(reason);
  }
}

/**
 * Verify-first registration (contract v1.2 §6, KL-019). Owns `pending_registrations`.
 *
 * Equal cost on both branches of `register`: request validation, username check, one Argon2
 * hash (through the process cap), one user lookup and one small transaction on
 * `pending_registrations`; everything branch-specific (audit, mail, notice throttling) runs in a
 * background task after the 202 is written.
 */
@Injectable()
export class RegistrationService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(RegistrationService.name);
  private readonly codeKey: Buffer;
  private cleanupTimer: NodeJS.Timeout | undefined;

  constructor(
    private readonly prisma: PrismaService,
    private readonly users: UsersService,
    private readonly sessions: SessionsService,
    private readonly passwords: PasswordHasher,
    private readonly auth: AuthService,
    private readonly audit: AuditService,
    private readonly rateLimits: RateLimitService,
    private readonly background: BackgroundTasks,
    @Inject(MAIL_SENDER) private readonly mail: MailSender,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
  ) {
    // Codes are stored as HMAC-SHA-256 under a key derived (HKDF) from RATE_LIMIT_KEY_SECRET, so
    // a database leak alone does not allow brute-forcing the 10^8 code space offline.
    this.codeKey = Buffer.from(
      hkdfSync('sha256', config.rateLimitKeySecret, 'kabso', 'registration-code/v1', 32),
    );
  }

  onModuleInit(): void {
    const seconds = this.config.registration.cleanupIntervalSeconds;
    if (seconds > 0) {
      this.cleanupTimer = setInterval(() => {
        void this.deleteExpired().catch((err: unknown) =>
          this.logger.error({ error: safeErrorLog(err) }, 'Pending-registration cleanup failed'),
        );
      }, seconds * 1000);
      this.cleanupTimer.unref();
    }
  }

  onModuleDestroy(): void {
    if (this.cleanupTimer) clearInterval(this.cleanupTimer);
  }

  /** Periodic + lazy cleanup of expired pending registrations (contract v1.2 §6 rule 8). */
  async deleteExpired(now: Date = new Date()): Promise<number> {
    const { count } = await this.prisma.pendingRegistration.deleteMany({
      where: { expiresAt: { lte: now } },
    });
    return count;
  }

  codeHash(email: string, code: string): string {
    return createHmac('sha256', this.codeKey).update(`${email}\n${code}`).digest('hex');
  }

  /** POST /auth/register → always 202 with a constant body (or 400/409/429/503). */
  async register(input: RegisterInput, meta: RequestMeta): Promise<VerificationPendingDto> {
    const now = new Date();
    if (containsReservedTerm(input.displayName, this.config.reservedDisplayNameTerms)) {
      throw AppException.validation([{ field: 'displayName', issue: 'reserved_term' }]);
    }
    if (isReservedUsername(input.username)) throw new AppException(ErrorCode.USERNAME_TAKEN);
    // Usernames are public: an account or another email's live pending registration holds it.
    if (await this.users.isUsernameTaken(input.username, input.email, now)) {
      throw new AppException(ErrorCode.USERNAME_TAKEN);
    }

    // Always hash before branching on email existence (equal Argon2 cost, through the cap).
    const passwordHash = await this.passwords.hash(input.password);
    const existing = await this.users.findMailRecipient({ email: input.email });
    const locale: MailLocale = input.locale ?? meta.acceptLanguage ?? 'ar';

    // Both branches run the SAME committed transaction (look up, clear, insert the pending row);
    // for an existing account the inserted row is deleted again before commit, for a new email the
    // audit row is written instead. Equal DB work and an equal commit → equal latency
    // (contract v1.2 §6 step 2).
    const code = this.newCode();
    const expiresAt = new Date(now.getTime() + this.config.registration.ttlSeconds * 1000);
    try {
      await this.prisma.$transaction(async (tx) => {
        const previous = await tx.pendingRegistration.findUnique({
          where: { email: input.email },
          select: { id: true },
        });
        // Replacing releases the previous row's username reservation and invalidates its code.
        await tx.pendingRegistration.deleteMany({
          where: { OR: [{ email: input.email }, { username: input.username, expiresAt: { lte: now } }] },
        });
        const row = await tx.pendingRegistration.create({
          data: {
            email: input.email,
            username: input.username,
            displayName: input.displayName,
            locale,
            passwordHash,
            deviceName: input.device?.name || null,
            platform: input.device?.platform ?? null,
            appVersion: input.device?.appVersion || null,
            ip: meta.ip?.slice(0, 64) ?? null,
            userAgent: meta.userAgent,
            codeHash: this.codeHash(input.email, code),
            expiresAt,
          },
          select: { id: true },
        });
        if (existing) {
          await tx.pendingRegistration.delete({ where: { id: row.id } });
        } else {
          await this.audit.recordIn(tx, {
            action: previous ? AuditAction.REGISTRATION_REPLACED : AuditAction.REGISTRATION_PENDING_CREATED,
            targetType: 'pending_registration',
            targetId: row.id,
            ...(previous ? { metadata: { replacedPendingId: previous.id } } : {}),
            ip: meta.ip,
            requestId: meta.requestId,
          });
        }
      });
    } catch (err) {
      const index = violatedUniqueIndex(err);
      if (index !== null) {
        // A concurrent pending registration took the username first.
        if (/pending_registrations_username_key|^username$/.test(index)) {
          throw new AppException(ErrorCode.USERNAME_TAKEN);
        }
        // A concurrent register for the same email won the race: its code is the live one.
        if (/pending_registrations_email_key|^email$/.test(index)) return VERIFICATION_PENDING;
      }
      throw err;
    }
    if (existing) {
      this.background.run('registration.existing_email', () =>
        this.sendExistingAccountNotice(existing, meta),
      );
      return VERIFICATION_PENDING;
    }
    this.background.run('registration.pending', async () => {
      await this.mail.sendRegistrationCode({ to: input.email, locale, code, expiresAt });
    });
    return VERIFICATION_PENDING;
  }

  /** POST /auth/register/verify → 201 AuthResponse; every failure is the same 422. */
  async verify(input: RegisterVerifyInput, meta: RequestMeta): Promise<AuthResponseDto> {
    const now = new Date();
    let pendingId: string | null = null;
    try {
      // Consume one attempt atomically BEFORE comparing, so at most 5 codes are ever checked
      // per pending registration, even under concurrency.
      const rows = await this.prisma.$queryRaw<ClaimedPending[]>`
        UPDATE "pending_registrations"
        SET "attempts" = "attempts" + 1, "updated_at" = ${now}
        WHERE "email" = ${input.email} AND "expires_at" > ${now} AND "attempts" < ${MAX_CODE_ATTEMPTS}
        RETURNING "id", "code_hash", "attempts", "username", "display_name", "locale",
                  "password_hash", "device_name", "platform", "app_version"`;
      const pending = rows[0];
      if (!pending) {
        // Lazy cleanup of an expired/exhausted row for this address.
        await this.prisma.pendingRegistration.deleteMany({
          where: {
            email: input.email,
            OR: [{ expiresAt: { lte: now } }, { attempts: { gte: MAX_CODE_ATTEMPTS } }],
          },
        });
        throw new VerifyFailed('no_live_pending');
      }
      pendingId = pending.id;

      if (!hashesEqual(this.codeHash(input.email, input.code), pending.code_hash)) {
        if (pending.attempts >= MAX_CODE_ATTEMPTS) {
          await this.prisma.pendingRegistration.deleteMany({ where: { id: pending.id } });
          throw new VerifyFailed('attempts_exhausted');
        }
        throw new VerifyFailed('wrong_code');
      }

      const result = await this.createAccount(input, pending, meta, now);
      // The account now exists: a Redis outage must not turn this success into an error.
      await this.auth.rememberSuccessfulSource(result.user.id, meta).catch((err: unknown) => {
        this.logger.warn({ error: safeErrorLog(err) }, 'Could not record the successful source');
      });
      await this.audit.record({
        action: AuditAction.REGISTRATION_VERIFIED,
        actorUserId: result.user.id,
        targetType: 'user',
        targetId: result.user.id,
        metadata: { sessionId: result.tokens.refreshToken.split('.')[0] ?? null },
        ip: meta.ip,
        requestId: meta.requestId,
      });
      return result;
    } catch (err) {
      if (!(err instanceof VerifyFailed)) throw err;
      await this.audit.record({
        action: AuditAction.REGISTRATION_VERIFY_FAILED,
        targetType: 'pending_registration',
        ...(pendingId ? { targetId: pendingId } : {}),
        metadata: { reason: err.reason },
        ip: meta.ip,
        requestId: meta.requestId,
      });
      throw new AppException(ErrorCode.TOKEN_INVALID);
    }
  }

  /** POST /auth/register/resend → always 202; the work happens after the response. */
  resend(email: string, meta: RequestMeta): VerificationPendingDto {
    this.background.run('registration.resend', async () => {
      const now = new Date();
      const pending = await this.prisma.pendingRegistration.findFirst({
        where: { email, expiresAt: { gt: now } },
        select: { id: true, locale: true },
      });
      if (!pending) return;
      const code = this.newCode();
      const expiresAt = new Date(now.getTime() + this.config.registration.ttlSeconds * 1000);
      // A new code invalidates the old one (single code hash per row) and resets the attempts.
      const updated = await this.prisma.pendingRegistration.updateMany({
        where: { id: pending.id, expiresAt: { gt: now } },
        data: { codeHash: this.codeHash(email, code), attempts: 0, expiresAt },
      });
      if (updated.count === 0) return;
      const locale: MailLocale = meta.acceptLanguage ?? (pending.locale === 'en' ? 'en' : 'ar');
      await this.mail.sendRegistrationCode({ to: email, locale, code, expiresAt });
    });
    return VERIFICATION_PENDING;
  }

  private async createAccount(
    input: RegisterVerifyInput,
    pending: ClaimedPending,
    meta: RequestMeta,
    now: Date,
  ): Promise<AuthResponseDto> {
    const device = input.device ?? {
      ...(pending.device_name ? { name: pending.device_name } : {}),
      ...(pending.platform ? { platform: pending.platform as 'android' | 'ios' | 'web' | 'other' } : {}),
      ...(pending.app_version ? { appVersion: pending.app_version } : {}),
    };
    try {
      const { user, session } = await this.prisma.$transaction(async (tx) => {
        // Claim the row first: a concurrent verify of the same pending blocks here and then
        // finds nothing to delete.
        const claimed = await tx.pendingRegistration.deleteMany({ where: { id: pending.id } });
        if (claimed.count !== 1) throw new VerifyFailed('concurrent_verify');
        if ((await tx.user.count({ where: { email: input.email } })) > 0) {
          throw new VerifyFailed('email_registered');
        }
        const created = await this.users.createAccount(tx, {
          email: input.email,
          passwordHash: pending.password_hash,
          username: pending.username,
          displayName: pending.display_name,
          locale: pending.locale === 'en' ? 'en' : 'ar',
          emailVerifiedAt: now,
        });
        const issued = await this.sessions.create(tx, created.id, this.auth.client(device, meta), now);
        return { user: created, session: issued };
      });
      return { user: toMeDto(user), tokens: await this.auth.tokenPair(user.id, session) };
    } catch (err) {
      const emailConflict =
        (err instanceof VerifyFailed && err.reason === 'email_registered') ||
        (err instanceof AppException && err.code === ErrorCode.EMAIL_TAKEN);
      if (emailConflict) {
        // The address was registered between register and verify (unique backstop included).
        await this.prisma.pendingRegistration.deleteMany({ where: { id: pending.id } });
        const emailRegistered = await this.users.findMailRecipient({ email: input.email });
        if (emailRegistered) {
          const owner = emailRegistered;
          this.background.run('registration.existing_email', () =>
            this.sendExistingAccountNotice(owner, meta),
          );
        }
        throw new VerifyFailed('email_registered');
      }
      if (err instanceof AppException && err.code === ErrorCode.USERNAME_TAKEN) {
        // Backstop: the username became an account meanwhile; this pending can never succeed.
        await this.prisma.pendingRegistration.deleteMany({ where: { id: pending.id } });
      }
      throw err;
    }
  }

  /** "Account already exists" notice, in the account's locale, at most once per interval. */
  private async sendExistingAccountNotice(owner: MailRecipient, meta: RequestMeta): Promise<void> {
    if (owner.status !== 'ACTIVE') return;
    const first = await this.rateLimits.setFlagOnce(
      'registration:notice',
      owner.id,
      this.config.registration.noticeIntervalSeconds,
    );
    if (!first) return;
    await this.audit.record({
      action: AuditAction.REGISTRATION_EXISTING_EMAIL_NOTICE,
      actorUserId: null,
      targetType: 'user',
      targetId: owner.id,
      ip: meta.ip,
      requestId: meta.requestId,
    });
    await this.mail.sendAccountExistsNotice({
      to: owner.email,
      locale: owner.locale,
      appUrl: this.config.appPublicUrl,
    });
  }

  private newCode(): string {
    return String(randomInt(0, 10 ** CODE_DIGITS)).padStart(CODE_DIGITS, '0');
  }
}
