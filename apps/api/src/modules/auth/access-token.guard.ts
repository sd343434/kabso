import { Injectable, type CanActivate, type ExecutionContext } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import type { AppRequest } from '../../common/http/request-context.js';
import { AccessTokenService } from './access-token.service.js';
import { IS_OPTIONAL_AUTH_KEY, IS_PUBLIC_KEY } from './public.decorator.js';
import { SessionsService } from './sessions.service.js';

// RFC 7235: the auth scheme is case-insensitive (QA-002).
const BEARER = /^Bearer +([A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+)$/i;

/**
 * Global guard: every route requires a valid access token unless marked `@Public()` (or, with no
 * `Authorization` header at all, `@OptionalAuth()`: a guest, CP-010).
 * Besides the JWT itself it checks the session (not revoked, not expired) and that the user
 * is ACTIVE, so logout, revocation and suspension take effect immediately (CONVENTIONS §6).
 */
@Injectable()
export class AccessTokenGuard implements CanActivate {
  constructor(
    private readonly reflector: Reflector,
    private readonly accessTokens: AccessTokenService,
    private readonly sessions: SessionsService,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    // Deny-by-default: no WebSocket/RPC auth strategy exists yet (SEC-013, SECURITY_MODEL R8).
    if (context.getType() !== 'http') return false;
    const isPublic = this.reflector.getAllAndOverride<boolean>(IS_PUBLIC_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);
    if (isPublic) return true;

    const req = context.switchToHttp().getRequest<AppRequest>();
    const header = req.headers.authorization;
    if (
      header === undefined &&
      this.reflector.getAllAndOverride<boolean>(IS_OPTIONAL_AUTH_KEY, [
        context.getHandler(),
        context.getClass(),
      ])
    ) {
      return true; // a guest (CP-010)
    }
    const match = typeof header === 'string' ? BEARER.exec(header) : null;
    if (!match?.[1]) throw new AppException(ErrorCode.AUTH_UNAUTHENTICATED);

    const claims = await this.accessTokens.verify(match[1]);
    if (!claims || !(await this.sessions.isActive(claims.sessionId, claims.userId))) {
      throw new AppException(ErrorCode.AUTH_UNAUTHENTICATED);
    }
    req.auth = { userId: claims.userId, sessionId: claims.sessionId };
    return true;
  }
}
