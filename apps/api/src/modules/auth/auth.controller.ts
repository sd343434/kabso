import { Body, Controller, Delete, Get, HttpCode, Param, Post, Req } from '@nestjs/common';
import { BackgroundTasks } from '../../common/background/background-tasks.js';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import {
  clientIp,
  clientIpBucket,
  userAgent,
  type AppRequest,
  type AuthContext,
} from '../../common/http/request-context.js';
import { bodyField, RateLimit } from '../../common/rate-limit/rate-limit.decorator.js';
import { getRequestId } from '../../common/request-id/request-id.js';
import { ZodValidationPipe } from '../../common/validation/zod-validation.pipe.js';
import {
  forgotPasswordSchema,
  loginSchema,
  refreshSchema,
  registerResendSchema,
  registerSchema,
  registerVerifySchema,
  resetPasswordSchema,
  verifyEmailSchema,
  type LoginInput,
  type RegisterInput,
  type RegisterVerifyInput,
} from './auth.schemas.js';
import { AuthService, type AuthResponseDto, type RequestMeta, type TokenPairDto } from './auth.service.js';
import { CurrentAuth } from './current-auth.decorator.js';
import { Public } from './public.decorator.js';
import { RegistrationService, type VerificationPendingDto } from './registration.service.js';
import type { SessionInfoDto } from './sessions.service.js';
import { isUuid, parseRefreshToken } from './tokens.js';

function acceptLanguage(req: AppRequest): 'ar' | 'en' | undefined {
  const header = req.headers['accept-language'];
  if (typeof header !== 'string') return undefined;
  const primary = header.split(',')[0]?.trim().slice(0, 2).toLowerCase();
  return primary === 'ar' || primary === 'en' ? primary : undefined;
}

function requestMeta(req: AppRequest): RequestMeta {
  return {
    ip: clientIp(req),
    ipBucket: clientIpBucket(req),
    userAgent: userAgent(req),
    requestId: getRequestId(req),
    acceptLanguage: acceptLanguage(req),
  };
}

/** Refresh is limited per session; unparseable tokens share a per-IP bucket. */
function refreshSubject(req: AppRequest): string {
  const raw = bodyField(req, 'refreshToken');
  const parsed = parseRefreshToken(raw);
  return parsed ? `sid:${parsed.sessionId}` : `ip:${clientIpBucket(req)}`;
}

@Controller('auth')
export class AuthController {
  constructor(
    private readonly auth: AuthService,
    private readonly registration: RegistrationService,
    private readonly background: BackgroundTasks,
  ) {}

  /** v1.2 verify-first registration: always 202 with a constant body (never reveals the email). */
  @Public()
  @Post('register')
  @HttpCode(202)
  @RateLimit(
    { bucket: 'register:ip', rule: 'registerIp', key: (req) => clientIpBucket(req) },
    { bucket: 'register:email', rule: 'registerEmail', key: (req) => bodyField(req, 'email') },
  )
  register(
    @Body(new ZodValidationPipe(registerSchema)) body: RegisterInput,
    @Req() req: AppRequest,
  ): Promise<VerificationPendingDto> {
    return this.registration.register(body, requestMeta(req));
  }

  /** v1.2: completes registration with the emailed code → 201 AuthResponse; failures → 422. */
  @Public()
  @Post('register/verify')
  @HttpCode(201)
  @RateLimit(
    { bucket: 'register_verify:ip', rule: 'registerVerifyIp', key: (req) => clientIpBucket(req) },
    // SEC-027: 15 checks / day per email (counted before the check, atomic INCR).
    { bucket: 'register_verify:email', rule: 'registerVerifyEmail', key: (req) => bodyField(req, 'email') },
  )
  registerVerify(
    @Body(new ZodValidationPipe(registerVerifySchema)) body: RegisterVerifyInput,
    @Req() req: AppRequest,
  ): Promise<AuthResponseDto> {
    return this.registration.verify(body, requestMeta(req));
  }

  /** v1.2: re-sends the code if a live pending registration exists; always 202. */
  @Public()
  @Post('register/resend')
  @HttpCode(202)
  @RateLimit(
    { bucket: 'register_resend:email', rule: 'registerResendEmail', key: (req) => bodyField(req, 'email') },
    { bucket: 'register_resend:ip', rule: 'registerResendIp', key: (req) => clientIpBucket(req) },
  )
  registerResend(
    @Body(new ZodValidationPipe(registerResendSchema)) body: { email: string },
    @Req() req: AppRequest,
  ): VerificationPendingDto {
    return this.registration.resend(body.email, requestMeta(req));
  }

  @Public()
  @Post('login')
  @HttpCode(200)
  // Per-IP here; the per-account and per-IP+account buckets need the resolved account and are
  // applied by AuthService.login before any password hashing (CONVENTIONS §7).
  @RateLimit({ bucket: 'login:ip', rule: 'loginIp', key: (req) => clientIpBucket(req) })
  login(
    @Body(new ZodValidationPipe(loginSchema)) body: LoginInput,
    @Req() req: AppRequest,
  ): Promise<AuthResponseDto> {
    return this.auth.login(body, requestMeta(req));
  }

  @Public()
  @Post('refresh')
  @HttpCode(200)
  @RateLimit({ bucket: 'refresh:session', rule: 'refreshSession', key: refreshSubject })
  refresh(
    @Body(new ZodValidationPipe(refreshSchema)) body: { refreshToken: string },
    @Req() req: AppRequest,
  ): Promise<TokenPairDto> {
    return this.auth.refresh(body.refreshToken, requestMeta(req));
  }

  @Post('logout')
  @HttpCode(204)
  async logout(@CurrentAuth() auth: AuthContext, @Req() req: AppRequest): Promise<void> {
    await this.auth.logout(auth.userId, auth.sessionId, requestMeta(req));
  }

  @Public()
  @Post('email/verify')
  @HttpCode(204)
  async verifyEmail(
    @Body(new ZodValidationPipe(verifyEmailSchema)) body: { token: string },
    @Req() req: AppRequest,
  ): Promise<void> {
    await this.auth.verifyEmail(body.token, requestMeta(req));
  }

  @Post('email/resend')
  @HttpCode(202)
  @RateLimit({ bucket: 'email_resend:user', rule: 'emailResendUser', key: (req) => req.auth?.userId ?? '' })
  async resendVerification(@CurrentAuth() auth: AuthContext): Promise<void> {
    await this.auth.resendVerification(auth.userId);
  }

  @Public()
  @Post('password/forgot')
  @HttpCode(202)
  @RateLimit(
    { bucket: 'forgot:email', rule: 'forgotEmail', key: (req) => bodyField(req, 'email') },
    { bucket: 'forgot:ip', rule: 'forgotIp', key: (req) => clientIpBucket(req) },
  )
  forgotPassword(
    @Body(new ZodValidationPipe(forgotPasswordSchema)) body: { email: string },
    @Req() req: AppRequest,
  ): void {
    // Processed after the response so timing does not reveal whether the account exists.
    const meta = requestMeta(req);
    this.background.run('password.forgot', () => this.auth.forgotPassword(body.email, meta));
  }

  @Public()
  @Post('password/reset')
  @HttpCode(204)
  async resetPassword(
    @Body(new ZodValidationPipe(resetPasswordSchema)) body: { token: string; newPassword: string },
    @Req() req: AppRequest,
  ): Promise<void> {
    await this.auth.resetPassword(body.token, body.newPassword, requestMeta(req));
  }

  @Get('sessions')
  async listSessions(@CurrentAuth() auth: AuthContext): Promise<{ data: SessionInfoDto[] }> {
    return { data: await this.auth.listSessions(auth.userId, auth.sessionId) };
  }

  @Delete('sessions/:sessionId')
  @HttpCode(204)
  async revokeSession(
    @CurrentAuth() auth: AuthContext,
    @Param('sessionId') sessionId: string,
    @Req() req: AppRequest,
  ): Promise<void> {
    // Malformed ids cannot name a visible session → 404 (contract lists only 401/404).
    if (!isUuid(sessionId)) throw new AppException(ErrorCode.NOT_FOUND);
    await this.auth.revokeSession(auth.userId, sessionId.toLowerCase(), requestMeta(req));
  }
}
