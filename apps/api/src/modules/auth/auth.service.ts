import { Inject, Injectable, Logger } from '@nestjs/common';
import { safeErrorLog } from '../../logging/redact-text.js';
import { AuditAction, AuditService } from '../../common/audit/audit.service.js';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { RateLimitService } from '../../common/rate-limit/rate-limit.service.js';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { MAIL_SENDER, type MailLocale, type MailSender } from '../mail/mail-sender.js';
import { normalizeEmail, normalizeUsername } from '../users/username.js';
import { parseStaffId, staffIdHolderOf } from '../users/staff-ids.js';
import { activeDeviceBanOf, deviceBannedError } from './device-bans.js';
import { activeRestrictionOf } from '../users/account-control.js';
import { UsersService, type MeDto } from '../users/users.service.js';
import { AccessTokenService } from './access-token.service.js';
import { AccountDeletionService } from './account-deletion.service.js';
import type { DeviceInfo, InstallSource, LoginInput } from './auth.schemas.js';
import { PasswordHasher } from './password-hasher.service.js';
import {
  RevokedReason,
  SessionsService,
  type IssuedSession,
  type SessionInfoDto,
} from './sessions.service.js';
import { VerificationTokensService } from './verification-tokens.service.js';

/** `TokenPair` response (openapi). */
export interface TokenPairDto {
  accessToken: string;
  accessTokenExpiresAt: string;
  refreshToken: string;
  refreshTokenExpiresAt: string;
}

export interface AuthResponseDto {
  user: MeDto;
  tokens: TokenPairDto;
}

/** Request metadata needed for sessions and audit records. */
export interface RequestMeta {
  readonly ip: string | null;
  /** Client IP as a rate-limit subject (IPv6 grouped by /64). */
  readonly ipBucket: string;
  readonly userAgent: string | null;
  readonly requestId: string;
  readonly acceptLanguage?: MailLocale | undefined;
}

interface LoginLimits {
  readonly account: string;
  /** True while this attempt holds a slot in the account bucket. */
  reserved: boolean;
}

/** How the sign-in identifier was read (audit metadata; v1.84-live D302 adds `staff_id`). */
type LoginIdentifierType = 'email' | 'username' | 'staff_id';

/** Redis flag bucket: "this source logged into this account recently" (SEC-023). */
const RECENT_SUCCESS_BUCKET = 'login:recent_success';

@Injectable()
export class AuthService {
  private readonly logger = new Logger(AuthService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly users: UsersService,
    private readonly sessions: SessionsService,
    private readonly verificationTokens: VerificationTokensService,
    private readonly passwords: PasswordHasher,
    private readonly accessTokens: AccessTokenService,
    private readonly audit: AuditService,
    private readonly rateLimits: RateLimitService,
    private readonly deletion: AccountDeletionService,
    @Inject(MAIL_SENDER) private readonly mail: MailSender,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
  ) {}

  async login(input: LoginInput, meta: RequestMeta): Promise<AuthResponseDto> {
    const identifier = input.identifier.includes('@')
      ? { email: normalizeEmail(input.identifier) }
      : { username: normalizeUsername(input.identifier) };
    // v1.84-live (D302, §10.96.12; owner: «المشرفين يدخلون من خلال وضع الايدي المميز والباسورد»): a staff ID («Kabso01»,
    // «kabso1», «@KABSO01», the primary OWNER's «Kabso») signs in its CURRENT holder (ACTIVE, a panel role held). A
    // retired number or a suspended holder resolves to nobody and the identifier is read as before (username / email),
    // so the answer and the work done are those of any unknown identifier. Every rule below applies unchanged.
    const staffNumber = parseStaffId(input.identifier);
    const staffHolder = staffNumber === null ? null : await staffIdHolderOf(this.prisma, staffNumber);
    const identifierType: LoginIdentifierType =
      staffHolder !== null ? 'staff_id' : 'email' in identifier ? 'email' : 'username';
    const candidate = await this.users.findLoginCandidate(
      staffHolder !== null ? { id: staffHolder } : identifier,
    );
    const limits = await this.checkLoginLimits(candidate?.id ?? null, identifier, identifierType, meta);

    let passwordOk: boolean;
    try {
      passwordOk = candidate
        ? await this.passwords.verify(candidate.passwordHash, input.password)
        : await this.passwords.verifyAgainstDummy(input.password);
    } catch (err) {
      // No password was checked (e.g. Argon2 cap → 503): give the reserved slot back.
      await this.refundAccountAttempt(limits);
      throw err;
    }

    if (!candidate || !passwordOk || candidate.status === 'DELETED') {
      // SEC-023: the failed attempt keeps the account-bucket slot reserved before the check.
      await this.audit.record({
        action: AuditAction.LOGIN_FAILURE,
        actorUserId: candidate?.id ?? null,
        metadata: { identifierType, reason: candidate ? 'bad_password' : 'unknown_identifier' },
        ip: meta.ip,
        requestId: meta.requestId,
      });
      throw new AppException(ErrorCode.AUTH_INVALID_CREDENTIALS);
    }
    // The password was right: this was not a failed guess (contract §7: failures only).
    await this.refundAccountAttempt(limits);
    // v1.62-social (D193, §10.56): an account in its deletion grace period — only after the right password, so
    // the answer reveals nothing to someone guessing. `cancelDeletion: true` cancels it and signs in.
    if (candidate.status === 'PENDING_DELETION') {
      if (input.cancelDeletion !== true) {
        await this.audit.record({
          action: AuditAction.LOGIN_FAILURE,
          actorUserId: candidate.id,
          metadata: { identifierType, reason: 'deletion_pending' },
          ip: meta.ip,
          requestId: meta.requestId,
        });
        const purgeAfter = await this.deletion.purgeAfterOf(candidate.id);
        throw new AppException(
          ErrorCode.ACCOUNT_DELETION_PENDING,
          undefined,
          purgeAfter ? [{ field: 'purgeAfter', issue: purgeAfter.toISOString() }] : undefined,
        );
      }
      await this.deletion.cancelAtSignIn(candidate.id, meta);
    }
    if (candidate.status === 'SUSPENDED') {
      await this.audit.record({
        action: AuditAction.LOGIN_FAILURE,
        actorUserId: candidate.id,
        metadata: { identifierType, reason: 'suspended' },
        ip: meta.ip,
        requestId: meta.requestId,
      });
      throw new AppException(ErrorCode.ACCOUNT_SUSPENDED);
    }
    // v1.72-social (D208, §10.67): a temporary lock by the team — told only after the right password, with its end
    // and the team's reason (the person sees them on the sign-in screen).
    const lock = await activeRestrictionOf(this.prisma, candidate.id, 'LOCK');
    if (lock) {
      await this.audit.record({
        action: AuditAction.LOGIN_FAILURE,
        actorUserId: candidate.id,
        metadata: { identifierType, reason: 'locked', lockedUntil: lock.endsAt.toISOString() },
        ip: meta.ip,
        requestId: meta.requestId,
      });
      throw new AppException(ErrorCode.ACCOUNT_LOCKED, undefined, [
        { field: 'lockedUntil', issue: lock.endsAt.toISOString() },
        { field: 'reason', issue: lock.reason },
      ]);
    }
    // v1.60-live (D250, §10.91): a device the team banned «حظر جهاز» — refused for every account, told only after the
    // right password (like a lock), with the end and the team's reason.
    const deviceBan = await activeDeviceBanOf(this.prisma, [
      this.sessions.deviceHashOf(input.device?.deviceKey),
    ]);
    if (deviceBan) {
      await this.audit.record({
        action: AuditAction.LOGIN_FAILURE,
        actorUserId: candidate.id,
        metadata: { identifierType, reason: 'device_banned', deviceBanId: deviceBan.id },
        ip: meta.ip,
        requestId: meta.requestId,
      });
      throw deviceBannedError(deviceBan);
    }
    // v1.72-social (D208): the team requires a new password (a temporary one, or «فرض تغيير كلمة المرور»).
    let changedPassword = false;
    if (candidate.passwordChangeRequiredAt !== null) {
      if (input.newPassword === undefined) {
        await this.audit.record({
          action: AuditAction.LOGIN_FAILURE,
          actorUserId: candidate.id,
          metadata: { identifierType, reason: 'password_change_required' },
          ip: meta.ip,
          requestId: meta.requestId,
        });
        throw new AppException(ErrorCode.PASSWORD_CHANGE_REQUIRED);
      }
      if (input.newPassword === input.password) {
        throw AppException.validation([{ field: 'newPassword', issue: 'same_as_current' }]);
      }
      const hash = await this.passwords.hash(input.newPassword);
      const revoked = await this.prisma.$transaction(async (tx) => {
        await tx.user.update({
          where: { id: candidate.id },
          data: { passwordHash: hash, passwordChangeRequiredAt: null },
        });
        await tx.verificationToken.updateMany({
          where: { userId: candidate.id, purpose: 'PASSWORD_RESET', consumedAt: null },
          data: { consumedAt: new Date() },
        });
        return this.sessions.revokeAllForUser(tx, candidate.id, RevokedReason.PASSWORD_RESET);
      });
      await this.audit.record({
        action: AuditAction.PASSWORD_CHANGED_AT_SIGN_IN,
        actorUserId: candidate.id,
        targetType: 'user',
        targetId: candidate.id,
        metadata: { revokedSessions: revoked },
        ip: meta.ip,
        requestId: meta.requestId,
      });
      changedPassword = true;
    }

    if (!changedPassword && this.passwords.needsRehash(candidate.passwordHash)) {
      await this.users.updatePasswordHash(
        this.prisma,
        candidate.id,
        await this.passwords.hash(input.password),
      );
    }

    const session = await this.sessions.create(this.prisma, candidate.id, this.client(input.device, meta));
    await this.rememberSuccessfulSource(candidate.id, meta);
    await this.audit.record({
      action: AuditAction.LOGIN_SUCCESS,
      actorUserId: candidate.id,
      targetType: 'session',
      targetId: session.sessionId,
      metadata: { identifierType },
      ip: meta.ip,
      requestId: meta.requestId,
    });
    const me = await this.users.getMe(candidate.id);
    if (!me) throw new AppException(ErrorCode.AUTH_INVALID_CREDENTIALS);
    return { user: me, tokens: await this.tokenPair(candidate.id, session) };
  }

  async refresh(
    refreshToken: string,
    meta: RequestMeta,
    installSource: InstallSource | null = null,
  ): Promise<TokenPairDto> {
    const outcome = await this.sessions.rotate(refreshToken, new Date(), installSource);
    if (outcome.kind === 'reuse') {
      await this.audit.record({
        action: AuditAction.REFRESH_REUSE,
        actorUserId: outcome.userId,
        targetType: 'session',
        targetId: outcome.sessionId,
        metadata: {
          matchedPrevious: outcome.rotationsAgo === 1,
          rotationsAgo: outcome.rotationsAgo,
          secondsSinceLastRotation: Math.round((Date.now() - outcome.lastRotatedAt.getTime()) / 1000),
        },
        ip: meta.ip,
        requestId: meta.requestId,
      });
      // No session id in logs: it is the prefix of refresh tokens (the audit row has it).
      this.logger.warn({ requestId: meta.requestId }, 'Refresh token reuse detected; session revoked');
      throw new AppException(ErrorCode.AUTH_REFRESH_INVALID);
    }
    if (outcome.kind === 'invalid_secret') {
      await this.audit.record({
        action: AuditAction.REFRESH_INVALID_SECRET,
        // The presenter is not proven to be the owner, so no actor is attributed.
        actorUserId: null,
        targetType: 'session',
        targetId: outcome.sessionId,
        ip: meta.ip,
        requestId: meta.requestId,
      });
      throw new AppException(ErrorCode.AUTH_REFRESH_INVALID);
    }
    return this.tokenPair(outcome.userId, outcome.session);
  }

  async logout(userId: string, sessionId: string, meta: RequestMeta): Promise<void> {
    await this.sessions.revoke(userId, sessionId, RevokedReason.LOGOUT);
    await this.audit.record({
      action: AuditAction.LOGOUT,
      actorUserId: userId,
      targetType: 'session',
      targetId: sessionId,
      ip: meta.ip,
      requestId: meta.requestId,
    });
  }

  listSessions(userId: string, currentSessionId: string): Promise<SessionInfoDto[]> {
    return this.sessions.listActive(userId, currentSessionId);
  }

  async revokeSession(userId: string, sessionId: string, meta: RequestMeta): Promise<void> {
    const revoked = await this.sessions.revoke(userId, sessionId, RevokedReason.USER_REVOKED);
    if (!revoked) throw new AppException(ErrorCode.NOT_FOUND);
    await this.audit.record({
      action: AuditAction.SESSION_REVOKED,
      actorUserId: userId,
      targetType: 'session',
      targetId: sessionId,
      ip: meta.ip,
      requestId: meta.requestId,
    });
  }

  /**
   * `POST /auth/sessions/revoke-others` (v1.79-social, D226, §10.76). Order after auth and the rate limit: 400 body →
   * 403 `REAUTH_FAILED` (the password is not the account's; audited) → 200 with the number of sessions ended
   * (0 when there was no other; audited either way). The caller's own session stays.
   */
  async revokeOtherSessions(
    userId: string,
    currentSessionId: string,
    password: string,
    meta: RequestMeta,
  ): Promise<{ revoked: number }> {
    const user = await this.prisma.user.findUnique({ where: { id: userId }, select: { passwordHash: true } });
    if (!user) throw new AppException(ErrorCode.AUTH_UNAUTHENTICATED);
    if (!(await this.passwords.verify(user.passwordHash, password))) {
      await this.audit.record({
        action: AuditAction.SESSIONS_REVOKE_OTHERS_REAUTH_FAILED,
        actorUserId: userId,
        targetType: 'user',
        targetId: userId,
        ip: meta.ip,
        requestId: meta.requestId,
      });
      throw new AppException(ErrorCode.REAUTH_FAILED);
    }
    const revoked = await this.sessions.revokeOthers(userId, currentSessionId, RevokedReason.USER_REVOKED);
    await this.audit.record({
      action: AuditAction.SESSIONS_REVOKED_OTHERS,
      actorUserId: userId,
      targetType: 'session',
      targetId: currentSessionId,
      metadata: { count: revoked },
      ip: meta.ip,
      requestId: meta.requestId,
    });
    return { revoked };
  }

  async verifyEmail(token: string, meta: RequestMeta): Promise<void> {
    const now = new Date();
    const userId = await this.prisma.$transaction(async (tx) => {
      const owner = await this.verificationTokens.consume(tx, token, 'EMAIL_VERIFY', now);
      await this.users.markEmailVerified(tx, owner, now);
      return owner;
    });
    await this.audit.record({
      action: AuditAction.EMAIL_VERIFIED,
      actorUserId: userId,
      targetType: 'user',
      targetId: userId,
      ip: meta.ip,
      requestId: meta.requestId,
    });
  }

  async resendVerification(userId: string): Promise<void> {
    const user = await this.users.findMailRecipient({ id: userId });
    if (!user || user.emailVerifiedAt !== null || user.status !== 'ACTIVE') return;
    const token = await this.verificationTokens.issue(
      this.prisma,
      user.id,
      'EMAIL_VERIFY',
      this.config.tokens.emailVerifyTtlSeconds,
    );
    await this.sendMail('verify', user.email, user.locale, token);
  }

  /**
   * Always resolves (the controller answers 202 before this completes) so neither the status
   * code nor the response time reveals whether the email is registered.
   */
  async forgotPassword(email: string, meta: RequestMeta): Promise<void> {
    try {
      const user = await this.users.findMailRecipient({ email });
      // v1.62-social (D193): a person in their deletion grace period may reset a forgotten password (to cancel).
      if (!user || (user.status !== 'ACTIVE' && user.status !== 'PENDING_DELETION')) return;
      const token = await this.verificationTokens.issue(
        this.prisma,
        user.id,
        'PASSWORD_RESET',
        this.config.tokens.passwordResetTtlSeconds,
      );
      await this.audit.record({
        action: AuditAction.PASSWORD_RESET_REQUESTED,
        actorUserId: user.id,
        targetType: 'user',
        targetId: user.id,
        ip: meta.ip,
        requestId: meta.requestId,
      });
      await this.sendMail('reset', user.email, user.locale, token);
    } catch (err) {
      this.logger.error(
        { error: safeErrorLog(err), requestId: meta.requestId },
        'Forgot-password processing failed',
      );
    }
  }

  async resetPassword(token: string, newPassword: string, meta: RequestMeta): Promise<void> {
    // Reject bad tokens before spending Argon2 time; the transaction re-checks atomically.
    await this.verificationTokens.check(this.prisma, token, 'PASSWORD_RESET');
    const passwordHash = await this.passwords.hash(newPassword);
    const now = new Date();
    const { userId, revokedSessions } = await this.prisma.$transaction(async (tx) => {
      const owner = await this.verificationTokens.consume(tx, token, 'PASSWORD_RESET', now);
      await this.users.updatePasswordHash(tx, owner, passwordHash);
      // Invalidate any other outstanding reset tokens for this user.
      await tx.verificationToken.updateMany({
        where: { userId: owner, purpose: 'PASSWORD_RESET', consumedAt: null },
        data: { consumedAt: now },
      });
      const revoked = await this.sessions.revokeAllForUser(tx, owner, RevokedReason.PASSWORD_RESET, now);
      return { userId: owner, revokedSessions: revoked };
    });
    await this.audit.record({
      action: AuditAction.PASSWORD_RESET,
      actorUserId: userId,
      targetType: 'user',
      targetId: userId,
      metadata: { revokedSessions },
      ip: meta.ip,
      requestId: meta.requestId,
    });
  }

  /**
   * Login limits that need the resolved account (CONVENTIONS §7, SEC-002/SEC-009/SEC-023), checked
   * before any Argon2 work. Email and username of one account share the key (the user id);
   * unknown identifiers are keyed on the normalized identifier.
   *  - per IP+account: every attempt counts;
   *  - per account across IPs: only FAILED attempts count. The slot is reserved with an atomic
   *    INCR before the Argon2 check (refused when the result exceeds the limit) and refunded
   *    (DECR) when the password turns out to be correct, so concurrent guesses can never exceed
   *    the limit (contract v1.2.3 §7, SEC-023 race). A source (IPv4 / IPv6 /64) that logged into
   *    this account successfully within LOGIN_RECENT_SUCCESS_TTL_SECONDS bypasses this bucket.
   */
  private async checkLoginLimits(
    userId: string | null,
    identifier: { email: string } | { username: string },
    identifierType: LoginIdentifierType,
    meta: RequestMeta,
  ): Promise<LoginLimits> {
    const account = userId
      ? `user:${userId}`
      : 'email' in identifier
        ? `email:${identifier.email}`
        : `username:${identifier.username}`;
    try {
      await this.rateLimits.consume(
        'login:ip_account',
        `${meta.ipBucket}|${account}`,
        this.config.rateLimits.loginIpAccount,
      );
      const trustedSource =
        userId !== null &&
        (await this.rateLimits.hasFlag(RECENT_SUCCESS_BUCKET, `${userId}|${meta.ipBucket}`));
      if (!trustedSource) {
        await this.rateLimits.consume('login:account', account, this.config.rateLimits.loginAccount);
      }
      return { account, reserved: !trustedSource };
    } catch (err) {
      if (err instanceof AppException && err.code === ErrorCode.RATE_LIMITED) {
        await this.audit.record({
          action: AuditAction.LOGIN_RATE_LIMITED,
          actorUserId: userId,
          metadata: { identifierType },
          ip: meta.ip,
          requestId: meta.requestId,
        });
      }
      throw err;
    }
  }

  private async refundAccountAttempt(limits: LoginLimits): Promise<void> {
    if (!limits.reserved) return;
    limits.reserved = false;
    await this.rateLimits.refund('login:account', limits.account);
  }

  /** Marks this source (IP / IPv6 /64, HMAC-keyed in Redis) as recently successful (SEC-023). */
  async rememberSuccessfulSource(userId: string, meta: RequestMeta): Promise<void> {
    await this.rateLimits.setFlag(
      RECENT_SUCCESS_BUCKET,
      `${userId}|${meta.ipBucket}`,
      this.config.loginRecentSuccessTtlSeconds,
    );
  }

  client(device: DeviceInfo | undefined, meta: RequestMeta) {
    return { device, ip: meta.ip, userAgent: meta.userAgent };
  }

  async tokenPair(userId: string, session: IssuedSession): Promise<TokenPairDto> {
    const access = await this.accessTokens.sign({ userId, sessionId: session.sessionId });
    return {
      accessToken: access.token,
      accessTokenExpiresAt: access.expiresAt.toISOString(),
      refreshToken: session.refreshToken,
      refreshTokenExpiresAt: session.refreshTokenExpiresAt.toISOString(),
    };
  }

  private async sendMail(
    kind: 'verify' | 'reset',
    to: string,
    locale: MailLocale,
    token: { token: string; expiresAt: Date },
  ): Promise<void> {
    const path = kind === 'verify' ? 'verify-email' : 'reset-password';
    const link = `${this.config.appPublicUrl}/${path}?token=${encodeURIComponent(token.token)}`;
    const mail = { to, locale, token: token.token, link, expiresAt: token.expiresAt };
    try {
      if (kind === 'verify') await this.mail.sendEmailVerification(mail);
      else await this.mail.sendPasswordReset(mail);
    } catch (err) {
      // Delivery failure must not fail the user-facing request (user can ask for a resend).
      this.logger.error({ error: safeErrorLog(err), kind }, 'Mail delivery failed');
    }
  }
}
