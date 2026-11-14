import { Injectable, SetMetadata, type CanActivate, type ExecutionContext } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import type { AppRequest } from '../../common/http/request-context.js';
import type { AdminPermission } from '../../generated/prisma/client.js';
import { PrismaService } from '../../prisma/prisma.service.js';

const PERMISSION_KEY = 'kabso:admin-permission';

/** The permission an admin route needs (CP-005 §9.8). A route without one is refused. */
export const RequireAdminPermission = (permission: AdminPermission) =>
  SetMetadata(PERMISSION_KEY, permission);

/** Reads admin rights on every request, so a demotion or a revoked permission applies at once. */
@Injectable()
export class AdminPermissions {
  constructor(private readonly prisma: PrismaService) {}

  async has(userId: string, permission: AdminPermission): Promise<boolean> {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { role: true, adminPermissions: { where: { permission }, select: { permission: true } } },
    });
    return user?.role === 'ADMIN' && user.adminPermissions.length > 0;
  }

  async require(userId: string, permission: AdminPermission): Promise<void> {
    if (!(await this.has(userId, permission))) throw new AppException(ErrorCode.AUTH_FORBIDDEN);
  }
}

/**
 * Admin endpoints (CP-005 §7, §9.8): runs after the global AccessTokenGuard and requires
 * `users.role = ADMIN` and the route's `@RequireAdminPermission`. Fails closed: a route that
 * names no permission is forbidden.
 */
@Injectable()
export class AdminGuard implements CanActivate {
  constructor(
    private readonly reflector: Reflector,
    private readonly permissions: AdminPermissions,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const req = context.switchToHttp().getRequest<AppRequest>();
    const userId = req.auth?.userId;
    if (!userId) throw new AppException(ErrorCode.AUTH_UNAUTHENTICATED);
    const permission = this.reflector.get<AdminPermission | undefined>(PERMISSION_KEY, context.getHandler());
    if (!permission) throw new AppException(ErrorCode.AUTH_FORBIDDEN);
    await this.permissions.require(userId, permission);
    return true;
  }
}
