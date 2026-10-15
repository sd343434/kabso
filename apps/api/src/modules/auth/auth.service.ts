import { Inject, Injectable, Logger } from '@nestjs/common';
import { AuditAction, AuditService } from '../../common/audit/audit.service.js';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { MAIL_SENDER, type MailLocale, type MailSender } from '../mail/mail-sender.js';
import { normalizeEmail, normalizeUsername, isReservedUsername } from '../users/username.js';
import { UsersService, type MeDto } from '../users/users.service.js';
import { toMeDto } from '../users/users.service.js';
import { AccessTokenService } from './access-token.service.js';
import type { DeviceInfo, LoginInput, RegisterInput } from './auth.schemas.js';
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
  readonly userAgent: string | null;
  readonly requestId: string;
  readonly acceptLanguage?: MailLocale | undefined;
}

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
    @Inject(MAIL_SENDER) private readonly mail: MailSender,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
  ) {}

  async register(input: RegisterInput, meta: RequestMeta): Promise<AuthResponseDto> {
    if (isReservedUsername(input.username)) throw new AppException(ErrorCode.USERNAME_TAKEN);
    // Fast-path checks; the unique constraints remain the source of truth under races.
    if (await this.users.emailExists(input.email)) throw new AppException(ErrorCode.EMAIL_TAKEN);
    if (await this.users.usernameExists(input.username)) throw new AppException(ErrorCode.USERNAME_TAKEN);

    const passwordHash = await this.passwords.hash(input.password);
    const locale: MailLocale = input.locale ?? meta.acceptLanguage ?? 'ar';
    const now = new Date();

    const { user, session, verification } = await this.prisma.$transaction(async (tx) => {
      const created = await this.users.createAccount(tx, {
        email: input.email,
        passwordHash,
        username: input.username,
        displayName: input.displayName,
        locale,
      });
      const issued = await this.sessions.create(tx, created.id, this.client(input.device, meta), now);
      const token = await this.verificationTokens.issue(
        tx,
        created.id,
        'EMAIL_VERIFY',
        this.config.tokens.emailVerifyTtlSeconds,
        now,
      );
      return { user: created, session: issued, verification: token };
    });

    await this.audit.record({
      action: AuditAction.REGISTER,
      actorUserId: user.id,
      targetType: 'user',
      targetId: user.id,
      metadata: { sessionId: session.sessionId },
      ip: meta.ip,
      requestId: meta.requestId,
    });
    await this.sendMail('verify', user.email, locale, verification);

    return { user: toMeDto(user), tokens: await this.tokenPair(user.id, session) };
  }

  async login(input: LoginInput, meta: RequestMeta): Promise<AuthResponseDto> {
    const identifier = input.identifier.includes('@')
      ? { email: normalizeEmail(input.identifier) }
      : { username: normalizeUsername(input.identifier) };
    const identifierType = 'email' in identifier ? 'email' : 'username';
    const candidate = await this.users.findLoginCandidate(identifier);

    const passwordOk = candidate
      ? await this.passwords.verify(candidate.passwordHash, input.password)
      : await this.passwords.verifyAgainstDummy(input.password);

    if (!candidate || !passwordOk || candidate.status === 'DELETED') {
      await this.audit.record({
        action: AuditAction.LOGIN_FAILURE,
        actorUserId: candidate?.id ?? null,
        metadata: { identifierType, reason: candidate ? 'bad_password' : 'unknown_identifier' },
        ip: meta.ip,
        requestId: meta.requestId,
      });
      throw new AppException(ErrorCode.AUTH_INVALID_CREDENTIALS);
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

    if (this.passwords.needsRehash(candidate.passwordHash)) {
      await this.users.updatePasswordHash(
        this.prisma,
        candidate.id,
        await this.passwords.hash(input.password),
      );
    }

    const session = await this.sessions.create(this.prisma, candidate.id, this.client(input.device, meta));
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

  async refresh(refreshToken: string, meta: RequestMeta): Promise<TokenPairDto> {
    const outcome = await this.sessions.rotate(refreshToken);
    if (outcome.kind === 'reuse') {
      await this.audit.record({
        action: AuditAction.REFRESH_REUSE,
        actorUserId: outcome.userId,
        targetType: 'session',
        targetId: outcome.sessionId,
        metadata: { matchedPrevious: outcome.matchedPrevious },
        ip: meta.ip,
        requestId: meta.requestId,
      });
      this.logger.warn({ sessionId: outcome.sessionId }, 'Refresh token reuse detected; session revoked');
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
      if (!user || user.status !== 'ACTIVE') return;
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
        { err: { message: (err as Error).message }, requestId: meta.requestId },
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

  private client(device: DeviceInfo | undefined, meta: RequestMeta) {
    return { device, ip: meta.ip, userAgent: meta.userAgent };
  }

  private async tokenPair(userId: string, session: IssuedSession): Promise<TokenPairDto> {
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
      this.logger.error({ err: { message: (err as Error).message }, kind }, 'Mail delivery failed');
    }
  }
}
