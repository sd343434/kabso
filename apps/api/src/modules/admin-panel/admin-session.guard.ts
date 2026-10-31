import {
  createParamDecorator,
  Injectable,
  SetMetadata,
  type CanActivate,
  type ExecutionContext,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { clientIp, type AppRequest } from '../../common/http/request-context.js';
import { getRequestId } from '../../common/request-id/request-id.js';
import { ADMIN_COOKIE, AdminAuthService, CSRF_HEADER, type AdminContext } from './admin-auth.service.js';
import { can, type Capability } from './admin-permissions.js';
import type { AdminSession } from '../../generated/prisma/client.js';

const CAPABILITY_KEY = 'kabso:admin-capability';
const STAGE_KEY = 'kabso:admin-stage';

/** The capability a panel route needs (§10.54.1). A panel route without one (and not `@AdminSignedIn`) is refused. */
export const RequireCapability = (cap: Capability) => SetMetadata(CAPABILITY_KEY, cap);
/** Any panel role (e.g. `GET /admin/auth/session`, logout). */
export const AdminSignedIn = () => SetMetadata(CAPABILITY_KEY, '*');
/** The second-factor routes: a session between the password and the code. */
export const AdminPendingStage = () => SetMetadata(STAGE_KEY, 'PASSWORD');

export type AdminRequest = AppRequest & {
  admin?: AdminContext;
  adminSession?: AdminSession;
  adminToken?: string;
};

/** Reads one cookie from the `Cookie` header (no cookie-parser dependency). */
export function readCookie(header: string | undefined, name: string): string | undefined {
  if (!header) return undefined;
  for (const part of header.split(';')) {
    const i = part.indexOf('=');
    if (i < 0) continue;
    if (part.slice(0, i).trim() === name) return decodeURIComponent(part.slice(i + 1).trim());
  }
  return undefined;
}

const SAFE_METHODS = new Set(['GET', 'HEAD', 'OPTIONS']);

/**
 * Every cookie-authenticated panel route (v1.60-social, D191, CONVENTIONS §10.54.2): the session cookie (401 when
 * missing, unknown, revoked or expired), the session stage, the admin's current roles (read on every request, so a
 * revoked role or a suspension applies at once) and the route's capability (403 AUTH_FORBIDDEN), and for a change
 * the `X-CSRF-Token` header (403 ADMIN_CSRF_INVALID). The routes are `@Public()` for the global bearer guard.
 */
@Injectable()
export class AdminSessionGuard implements CanActivate {
  constructor(
    private readonly reflector: Reflector,
    private readonly auth: AdminAuthService,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const req = context.switchToHttp().getRequest<AdminRequest>();
    this.auth.requireOn();
    const token = readCookie(req.headers.cookie, ADMIN_COOKIE);
    const session = await this.auth.sessionOf(token);
    if (!session || !token) throw new AppException(ErrorCode.AUTH_UNAUTHENTICATED);
    const wantStage =
      this.reflector.getAllAndOverride<string | undefined>(STAGE_KEY, [
        context.getHandler(),
        context.getClass(),
      ]) ?? 'ACTIVE';
    if (session.stage !== wantStage) throw new AppException(ErrorCode.AUTH_UNAUTHENTICATED);
    if (!SAFE_METHODS.has(req.method)) {
      const header = req.headers[CSRF_HEADER];
      if (!this.auth.csrfMatches(token, typeof header === 'string' ? header : undefined)) {
        throw new AppException(ErrorCode.ADMIN_CSRF_INVALID);
      }
    }
    const ctx = await this.auth.context(session, { ip: clientIp(req), requestId: getRequestId(req) });
    if (!ctx) throw new AppException(ErrorCode.AUTH_UNAUTHENTICATED);
    req.adminSession = session;
    req.adminToken = token;
    req.admin = ctx;
    if (wantStage === 'PASSWORD') return true;
    const cap = this.reflector.get<Capability | '*' | undefined>(CAPABILITY_KEY, context.getHandler());
    if (!cap) throw new AppException(ErrorCode.AUTH_FORBIDDEN);
    if (cap !== '*' && !can(ctx.roles, cap)) throw new AppException(ErrorCode.AUTH_FORBIDDEN);
    return true;
  }
}

/** The signed-in admin (set by {@link AdminSessionGuard}). */
export const CurrentAdmin = createParamDecorator((_: unknown, context: ExecutionContext): AdminContext => {
  const admin = context.switchToHttp().getRequest<AdminRequest>().admin;
  if (!admin) throw new AppException(ErrorCode.AUTH_UNAUTHENTICATED);
  return admin;
});
