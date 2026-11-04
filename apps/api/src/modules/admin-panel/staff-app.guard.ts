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
import { Clock } from '../../common/time/clock.js';
import { getRequestId } from '../../common/request-id/request-id.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { activeStaffGrant } from '../live/live-staff.js';
import { AdminAuthService, type AdminContext } from './admin-auth.service.js';
import { can, capabilitiesOf, type Capability } from './admin-permissions.js';

const STAFF_CAPABILITY_KEY = 'kabso:staff-app-capability';

/**
 * v1.68-live (D273, §10.96.6): the panel capability a staff route in the app needs — the panel's own table
 * (`admin-permissions.ts`), so a staff member can do from the phone exactly what the panel lets them do for a live.
 */
export const StaffCapability = (cap: Capability) => SetMetadata(STAFF_CAPABILITY_KEY, cap);

export type StaffRequest = AppRequest & { staff?: AdminContext };

/**
 * v1.68-live (D273, CONVENTIONS §10.96.6): every staff route of the app, after the app's bearer guard (a normal user
 * session). On EVERY request: the panel roles held now (an ACTIVE ADMIN account — a revoked role or a suspension
 * applies at once; 403 AUTH_FORBIDDEN), the route's capability (403 AUTH_FORBIDDEN), and the step-up grant of this
 * very app session — not ended, not expired (403 STAFF_STEP_UP_REQUIRED). The handler gets an {@link AdminContext}
 * with `via: 'app'`, so the panel's rule functions run unchanged and audit `via: app`.
 */
@Injectable()
export class StaffAppGuard implements CanActivate {
  constructor(
    private readonly reflector: Reflector,
    private readonly auth: AdminAuthService,
    private readonly prisma: PrismaService,
    private readonly clock: Clock,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const req = context.switchToHttp().getRequest<StaffRequest>();
    if (!req.auth) throw new AppException(ErrorCode.AUTH_UNAUTHENTICATED);
    this.auth.requireOn();
    const cap = this.reflector.get<Capability | undefined>(STAFF_CAPABILITY_KEY, context.getHandler());
    if (!cap) throw new AppException(ErrorCode.AUTH_FORBIDDEN);
    const roles = await this.auth.rolesOf(req.auth.userId);
    if (roles.length === 0 || !can(roles, cap)) throw new AppException(ErrorCode.AUTH_FORBIDDEN);
    const grant = await activeStaffGrant(this.prisma, req.auth.userId, req.auth.sessionId, this.clock.now());
    if (!grant) throw new AppException(ErrorCode.STAFF_STEP_UP_REQUIRED);
    req.staff = {
      sessionId: grant.id,
      userId: req.auth.userId,
      stage: 'ACTIVE',
      roles,
      capabilities: capabilitiesOf(roles),
      ip: clientIp(req),
      requestId: getRequestId(req),
      via: 'app',
    };
    return true;
  }
}

/** The staff member behind a staff route (set by {@link StaffAppGuard}). */
export const CurrentStaff = createParamDecorator((_: unknown, context: ExecutionContext): AdminContext => {
  const staff = context.switchToHttp().getRequest<StaffRequest>().staff;
  if (!staff) throw new AppException(ErrorCode.AUTH_UNAUTHENTICATED);
  return staff;
});
