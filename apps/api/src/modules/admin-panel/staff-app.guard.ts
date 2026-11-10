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
import { LiveStaffAssignmentService } from '../live/live-staff-assignment.service.js';
import { AdminAuthService, type AdminContext } from './admin-auth.service.js';
import type { Capability } from './admin-permissions.js';

const STAFF_CAPABILITY_KEY = 'kabso:staff-app-capability';
const STAFF_NOT_WORK_KEY = 'kabso:staff-app-not-work';

/**
 * v1.68-live (D273, §10.96.6): the panel capability a staff route in the app needs — the panel's own table
 * (`admin-permissions.ts`), so a staff member can do from the phone exactly what the panel lets them do for a live.
 */
export const StaffCapability = (cap: Capability) => SetMetadata(STAFF_CAPABILITY_KEY, cap);

/**
 * v1.76-live (D286, §10.96.14): a staff route that is NOT staff work (reading or switching the shift itself), so it
 * never switches the shift on automatically. Every other staff route is staff work.
 */
export const NotStaffWork = () => SetMetadata(STAFF_NOT_WORK_KEY, true);

export type StaffRequest = AppRequest & { staff?: AdminContext };

/**
 * v1.68-live (D273, CONVENTIONS §10.96.6): every staff route of the app, after the app's bearer guard (a normal user
 * session). On EVERY request: the panel roles held now (an ACTIVE ADMIN account — a revoked role or a suspension
 * applies at once; 403 AUTH_FORBIDDEN) and the route's capability (403 AUTH_FORBIDDEN). v1.76-live (D286, owner:
 * «ازله لتسهيل العملية»): no step-up any more — holding the role is enough (the authenticator code stays only for the
 * permanent device ban, which asks for it in the body). A staff-work route also switches the shift on (§10.96.14).
 * The handler gets an {@link AdminContext} with `via: 'app'`, so the panel's rule functions run unchanged and audit
 * `via: app`.
 */
@Injectable()
export class StaffAppGuard implements CanActivate {
  constructor(
    private readonly reflector: Reflector,
    private readonly auth: AdminAuthService,
    private readonly assignments: LiveStaffAssignmentService,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const req = context.switchToHttp().getRequest<StaffRequest>();
    if (!req.auth) throw new AppException(ErrorCode.AUTH_UNAUTHENTICATED);
    this.auth.requireOn();
    const cap = this.reflector.get<Capability | undefined>(STAFF_CAPABILITY_KEY, context.getHandler());
    if (!cap) throw new AppException(ErrorCode.AUTH_FORBIDDEN);
    // The roles held now and their capabilities, the WhatsApp ones from the person's level (D360, §10.155).
    const { roles, capabilities } = await this.auth.accessOf(req.auth.userId);
    if (roles.length === 0 || !capabilities.includes(cap)) throw new AppException(ErrorCode.AUTH_FORBIDDEN);
    req.staff = {
      sessionId: req.auth.sessionId,
      userId: req.auth.userId,
      stage: 'ACTIVE',
      roles,
      capabilities,
      ip: clientIp(req),
      requestId: getRequestId(req),
      via: 'app',
    };
    if (!this.reflector.get<boolean | undefined>(STAFF_NOT_WORK_KEY, context.getHandler())) {
      // v1.76-live (D286): staff work switches the shift on (watch staff only; best effort, never fails the tool).
      await this.assignments.staffWorkBestEffort(
        req.auth.userId,
        cap === 'lives.watch' ? 'my_lives' : 'staff_tool',
        'app',
        { ip: req.staff.ip, requestId: req.staff.requestId },
      );
    }
    return true;
  }
}

/** The staff member behind a staff route (set by {@link StaffAppGuard}). */
export const CurrentStaff = createParamDecorator((_: unknown, context: ExecutionContext): AdminContext => {
  const staff = context.switchToHttp().getRequest<StaffRequest>().staff;
  if (!staff) throw new AppException(ErrorCode.AUTH_UNAUTHENTICATED);
  return staff;
});
