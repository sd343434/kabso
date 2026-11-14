import type { Gender } from '../users/profile-fields.js';
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
import { recordRegistrationConsentsIn, type RegistrationConsent } from '../privacy/legal.js';
import { attachReferralIn } from '../referrals/referral-core.js';
import {
  attachSupervisorSignupIn,
  emailMarkKey,
  emailMarkOf,
  parseSignupCode,
  recordEmailMarkIn,
  resolveSignupCodeIn,
} from '../referrals/signup-codes.js';
import {
  deviceAllowanceIn,
  deviceHashOf,
  deviceHmacKey,
  lockDeviceIn,
  recordDeviceSignupIn,
} from './device-signups.js';
import { activeDeviceBanOf, deviceBannedError } from './device-bans.js';

/** Constant 202 body (contract v1.2 §6). */
export const VERIFICATION_PENDING = { status: 'verification_pending' } as const;
export type VerificationPendingDto = typeof VERIFICATION_PENDING;

/** Code checks per pending registration before it is deleted (contract: 5). */
export const MAX_CODE_ATTEMPTS = 5;
/** Code checks per pending registration across resends (contract v1.2.3, SEC-026). */
export const MAX_TOTAL_ATTEMPTS = 10;
const CODE_DIGITS = 8;

/** Internal (never returned) reasons for `auth.registration.verify_failed`. */
type VerifyFailure =
  'no_live_pending' | 'wrong_code' | 'attempts_exhausted' | 'email_registered' | 'concurrent_verify';

interface ClaimedPending {
  id: string;
  code_hash: string;
  attempts: number;
  total_attempts: number;
  username: string;
  display_name: string;
  /** v1.47-social (D175): null only on rows made before the field existed. */
  gender: Gender | null;
  locale: string;
  password_hash: string;
  device_name: string | null;
  platform: string | null;
  app_version: string | null;
  /** v1.66-social (D198): what the person accepted at sign-up (`RegisterRequest.legal`), with the time, IP and UA. */
  legal_consent: RegistrationConsent | null;
  /** v1.74-social (D217): the app's install id and the invite code typed at sign-up. */
  install_id: string | null;
  referral_code: string | null;
  /** v1.78-social (D223): the HMAC of the device key sent to `register` (null: none). */
  device_hash: string | null;
}

class VerifyFailed extends Error {
  constructor(readonly reason: VerifyFailure) {
    super(reason);
  }
}

/** v1.78-social (D223): the device already created its accounts (thrown inside the account's transaction). */
class DeviceLimitReached extends Error {
  constructor(
    readonly count: number,
    readonly max: number,
  ) {
    super('device_account_limit');
  }
}

/** 409 DEVICE_ACCOUNT_LIMIT with the limit in `details[0].issue` (§10.75). */
function deviceLimitError(max: number): AppException {
  return new AppException(ErrorCode.DEVICE_ACCOUNT_LIMIT, undefined, [
    { field: 'device', issue: String(max) },
  ]);
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
  /** v1.78-social (D223): the HMAC key of the stored device keys. */
  private readonly deviceKey: Buffer;
  /** v1.108-social (D343): the HMAC key of the mailbox marks. */
  private readonly emailKey: Buffer;
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
    // Codes are stored as HMAC-SHA-256 under a key derived (HKDF) from REGISTRATION_CODE_KEY when
    // set (SEC-029), else from RATE_LIMIT_KEY_SECRET, so a database leak alone does not allow
    // brute-forcing the 10^8 code space offline. Rotating the source key invalidates every live
    // pending code (users request a new one with register/resend).
    this.codeKey = Buffer.from(
      hkdfSync(
        'sha256',
        config.registration.codeKey ?? config.rateLimitKeySecret,
        'kabso',
        'registration-code/v1',
        32,
      ),
    );
    this.deviceKey = deviceHmacKey(config.registration.deviceKey ?? config.rateLimitKeySecret);
    this.emailKey = emailMarkKey(config.registration.deviceKey ?? config.rateLimitKeySecret);
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
    // v1.78-social (D223, §10.75): a device that already created its accounts is told so before anything else (the
    // answer depends on the device only, never on the email). Checked again when the account is created.
    const deviceHash = deviceHashOf(this.deviceKey, input.device?.deviceKey);
    // v1.60-live (D250, §10.91): a device the team banned cannot sign up (any email).
    await this.refuseBannedDevice(deviceHash, 'register', null, meta);
    if (deviceHash) {
      const allowance = await deviceAllowanceIn(
        this.prisma,
        deviceHash,
        this.config.registration.maxAccountsPerDevice,
      );
      if (allowance.count >= allowance.max) {
        await this.recordDeviceLimit('register', allowance.count, allowance.max, null, meta);
        throw deviceLimitError(allowance.max);
      }
    }
    // v1.108-social (D343, §10.142): «رمز الدعوة أو رمز المشرف» must belong to someone who can use it now (an ACTIVE
    // inviter, a supervisor who can recruit). The answer depends on the code only, never on the email.
    if (
      input.referralCode !== undefined &&
      (await resolveSignupCodeIn(this.prisma, input.referralCode)) === null
    )
      throw AppException.validation([{ field: 'referralCode', issue: 'not_found' }]);
    if (
      containsReservedTerm(
        input.displayName,
        this.config.reservedDisplayNameTerms,
        this.config.reservedDisplayNameBrandTerms,
      )
    ) {
      throw AppException.validation([{ field: 'displayName', issue: 'reserved_term' }]);
    }
    if (isReservedUsername(input.username)) throw new AppException(ErrorCode.USERNAME_TAKEN);
    // Usernames are public: an account or ANY live pending registration holds it — including one
    // for this same email, so the 409 never confirms that an email is mid-registration (SEC-025).
    if (await this.users.isUsernameTaken(input.username, undefined, now)) {
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
            gender: input.gender,
            locale,
            passwordHash,
            deviceName: input.device?.name || null,
            platform: input.device?.platform ?? null,
            appVersion: input.device?.appVersion || null,
            installId: input.device?.installId ?? null,
            referralCode: input.referralCode ?? null,
            deviceHash,
            ip: meta.ip?.slice(0, 64) ?? null,
            userAgent: meta.userAgent,
            ...(input.legal
              ? {
                  legalConsent: {
                    age18: input.legal.ageConfirmed,
                    terms: input.legal.termsVersion ?? null,
                    privacy: input.legal.privacyVersion ?? null,
                    at: now.toISOString(),
                    ip: meta.ip?.slice(0, 64) ?? null,
                    userAgent: meta.userAgent?.slice(0, 512) ?? null,
                  } satisfies RegistrationConsent,
                }
              : {}),
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
      // Consume one attempt atomically BEFORE comparing, so at most 5 checks per code and 10 per
      // pending registration across resends (SEC-026) ever happen, even under concurrency.
      const rows = await this.prisma.$queryRaw<ClaimedPending[]>`
        UPDATE "pending_registrations"
        SET "attempts" = "attempts" + 1, "total_attempts" = "total_attempts" + 1, "updated_at" = ${now}
        WHERE "email" = ${input.email} AND "expires_at" > ${now}
          AND "attempts" < ${MAX_CODE_ATTEMPTS} AND "total_attempts" < ${MAX_TOTAL_ATTEMPTS}
        RETURNING "id", "code_hash", "attempts", "total_attempts", "username", "display_name", "gender"::text AS "gender", "locale",
                  "password_hash", "device_name", "platform", "app_version", "legal_consent",
                  "install_id", "referral_code", "device_hash"`;
      const pending = rows[0];
      if (!pending) {
        // Lazy cleanup of an expired row for this address. Never an exhausted one: the request that took the last
        // attempt may hold the correct code and still be creating the account — deleting the row under it would
        // fail every concurrent verify. An exhausted row is deleted by that request (wrong code below, or the
        // account's transaction), and it can no longer be claimed meanwhile.
        await this.prisma.pendingRegistration.deleteMany({
          where: { email: input.email, expiresAt: { lte: now } },
        });
        throw new VerifyFailed('no_live_pending');
      }
      pendingId = pending.id;

      if (!hashesEqual(this.codeHash(input.email, input.code), pending.code_hash)) {
        if (pending.attempts >= MAX_CODE_ATTEMPTS || pending.total_attempts >= MAX_TOTAL_ATTEMPTS) {
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
        select: { id: true, locale: true, createdAt: true },
      });
      if (!pending) return;
      const code = this.newCode();
      // SEC-026: a new code never extends the pending registration past its absolute lifetime.
      const expiresAt = new Date(
        Math.min(
          now.getTime() + this.config.registration.ttlSeconds * 1000,
          pending.createdAt.getTime() + this.config.registration.maxLifetimeSeconds * 1000,
        ),
      );
      if (expiresAt <= now) return;
      // A new code invalidates the old one (single code hash per row) and resets the per-code
      // attempts; `totalAttempts` keeps counting across codes.
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
      ...(pending.install_id ? { installId: pending.install_id } : {}),
    };
    // v1.78-social (D223): the device creating the account — the one verifying, else the one that registered.
    const deviceHash = deviceHashOf(this.deviceKey, input.device?.deviceKey) ?? pending.device_hash;
    // v1.60-live (D250): banned between register and verify (or verifying on a banned device) — the pending sign-up
    // can never succeed here: released at once.
    try {
      await this.refuseBannedDevice(deviceHash, 'verify', pending.id, meta);
    } catch (err) {
      await this.prisma.pendingRegistration.deleteMany({ where: { id: pending.id } });
      throw err;
    }
    try {
      const { user, session } = await this.prisma.$transaction(async (tx) => {
        // Claim the row first: a concurrent verify of the same pending blocks here and then
        // finds nothing to delete.
        const claimed = await tx.pendingRegistration.deleteMany({ where: { id: pending.id } });
        if (claimed.count !== 1) throw new VerifyFailed('concurrent_verify');
        if ((await tx.user.count({ where: { email: input.email } })) > 0) {
          throw new VerifyFailed('email_registered');
        }
        if (deviceHash) {
          await lockDeviceIn(tx, deviceHash);
          const allowance = await deviceAllowanceIn(
            tx,
            deviceHash,
            this.config.registration.maxAccountsPerDevice,
          );
          if (allowance.count >= allowance.max) throw new DeviceLimitReached(allowance.count, allowance.max);
        }
        const created = await this.users.createAccount(tx, {
          email: input.email,
          passwordHash: pending.password_hash,
          username: pending.username,
          displayName: pending.display_name,
          gender: pending.gender,
          locale: pending.locale === 'en' ? 'en' : 'ar',
          emailVerifiedAt: now,
        });
        // v1.66-social (D198, §10.61.2): the terms, the privacy policy and the 18+ statement accepted at sign-up.
        if (pending.legal_consent) await recordRegistrationConsentsIn(tx, created.id, pending.legal_consent);
        if (deviceHash) await recordDeviceSignupIn(tx, created.id, deviceHash, device.platform ?? null, now);
        // v1.108-social (D343): the mailbox's keyed hash, for the «not a new person» rule of later sign-ups.
        await recordEmailMarkIn(tx, created.id, emailMarkOf(this.emailKey, input.email), now);
        const issued = await this.sessions.create(tx, created.id, this.auth.client(device, meta), now);
        return { user: created, session: issued };
      });
      if (pending.referral_code) {
        if (parseSignupCode(pending.referral_code)?.kind === 'SUPERVISOR')
          await this.attachSupervisor(user.id, input.email, pending.referral_code, meta, now);
        else await this.attachReferral(user.id, input.email, pending, device.installId, meta, now);
      }
      return { user: toMeDto(user), tokens: await this.auth.tokenPair(user.id, session) };
    } catch (err) {
      if (err instanceof DeviceLimitReached) {
        // This pending sign-up can never succeed on this device: release its username at once.
        await this.prisma.pendingRegistration.deleteMany({ where: { id: pending.id } });
        await this.recordDeviceLimit('verify', err.count, err.max, pending.id, meta);
        throw deviceLimitError(err.max);
      }
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

  /**
   * v1.74-social (D217, §10.71): the invite code typed at sign-up, applied once the account exists — in a transaction
   * of its own after the account's, so no referral problem can ever fail a sign-up (an unknown code, the programme
   * switched off or a database error is logged and the account is created without a referral; a fraud rule records
   * a REJECTED referral).
   */
  private async attachReferral(
    userId: string,
    email: string,
    pending: ClaimedPending,
    installId: string | undefined,
    meta: RequestMeta,
    now: Date,
  ): Promise<void> {
    try {
      const result = await this.prisma.$transaction((tx) =>
        attachReferralIn(tx, {
          inviteeUserId: userId,
          code: pending.referral_code!,
          source: 'SIGNUP',
          installId: installId ?? pending.install_id ?? null,
          ip: meta.ip,
          email,
          now,
          requestId: meta.requestId,
          emailMark: emailMarkOf(this.emailKey, email),
          retentionDays: this.config.registration.identityRetentionDays,
        }),
      );
      if (result.kind !== 'ATTACHED')
        this.logger.log({ result: result.kind }, 'Sign-up invite code not attached');
    } catch (err) {
      this.logger.error({ error: safeErrorLog(err) }, 'Sign-up invite code failed');
    }
  }

  /**
   * v1.108-social (D343, §10.142): the supervisor's staff ID typed at sign-up, applied once the account exists, in a
   * transaction of its own (like the invite code: no attribution problem ever fails a sign-up). The credit is
   * withheld, with the reason, for a person who is not new (`attachSupervisorSignupIn`).
   */
  private async attachSupervisor(
    userId: string,
    email: string,
    code: string,
    meta: RequestMeta,
    now: Date,
  ): Promise<void> {
    try {
      const result = await this.prisma.$transaction((tx) =>
        attachSupervisorSignupIn(tx, {
          userId,
          code,
          emailHash: emailMarkOf(this.emailKey, email),
          now,
          retentionDays: this.config.registration.identityRetentionDays,
          ip: meta.ip,
          requestId: meta.requestId,
        }),
      );
      if (result.kind !== 'GRANTED')
        this.logger.log({ result: result.kind }, 'Sign-up supervisor code not credited');
    } catch (err) {
      this.logger.error({ error: safeErrorLog(err) }, 'Sign-up supervisor code failed');
    }
  }

  /** v1.108-social (D343): `checkSignupCode` — what a code is, or 400 `code` `not_found`. */
  async checkSignupCode(code: string): Promise<{ kind: 'INVITE' | 'SUPERVISOR'; code: string }> {
    const found = await resolveSignupCodeIn(this.prisma, code);
    if (!found) throw AppException.validation([{ field: 'code', issue: 'not_found' }]);
    return { kind: found.kind, code: found.code };
  }

  /** v1.78-social (D223): the audit row of a sign-up refused for its device (no email, no device hash). */
  private async recordDeviceLimit(
    stage: 'register' | 'verify',
    count: number,
    max: number,
    pendingId: string | null,
    meta: RequestMeta,
  ): Promise<void> {
    await this.audit.record({
      action: AuditAction.REGISTRATION_DEVICE_LIMIT,
      targetType: 'pending_registration',
      ...(pendingId ? { targetId: pendingId } : {}),
      metadata: { stage, count, max },
      ip: meta.ip,
      requestId: meta.requestId,
    });
  }

  /** v1.60-live (D250): 403 DEVICE_BANNED (audited `auth.device_banned` {stage}) when the device is banned now. */
  private async refuseBannedDevice(
    deviceHash: string | null,
    stage: 'register' | 'verify',
    pendingId: string | null,
    meta: RequestMeta,
  ): Promise<void> {
    const ban = await activeDeviceBanOf(this.prisma, [deviceHash]);
    if (!ban) return;
    await this.audit.record({
      action: AuditAction.DEVICE_BAN_REFUSED,
      targetType: 'device_ban',
      targetId: ban.id,
      metadata: { stage, ...(pendingId ? { pendingId } : {}) },
      ip: meta.ip,
      requestId: meta.requestId,
    });
    throw deviceBannedError(ban);
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
