import { Body, Controller, Get, HttpCode, Param, Patch, Post, Query, Res, UseGuards } from '@nestjs/common';
import type { Response } from 'express';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { byIp, RateLimit } from '../../common/rate-limit/rate-limit.decorator.js';
import { ZodValidationPipe } from '../../common/validation/zod-validation.pipe.js';
import { Public } from '../auth/public.decorator.js';
import type { AccountRestrictionKind } from '../../generated/prisma/client.js';
import type { AdjustCurrency, RestrictionKind } from '../users/account-control.js';
import type { AdminContext } from './admin-auth.service.js';
import {
  adjustBody,
  CONTENT_TYPES,
  emailChangeBody,
  liftBody,
  lockBody,
  profileEditBody,
  reasonCodeBody,
  reasonOnlyBody,
  requireChangeBody,
  restrictBody,
  userContentQuery,
  type ContentType,
} from './admin-control.schemas.js';
import { AdminControlService } from './admin-control.service.js';
import { pathUuid } from './admin-panel.schemas.js';
import { AdminSessionGuard, CurrentAdmin, RequireCapability } from './admin-session.guard.js';

/** Every cookie-authenticated panel route: per-IP limit instead of the public default (§10.54.2). */
const PANEL_LIMIT = RateLimit({ bucket: 'admin:ip', rule: 'adminIp', key: byIp, replacesDefault: true });

type Duration = { days?: number; until?: string; reason: string };

/**
 * The account controls «تحكم كامل» (v1.72-social, D208, CONVENTIONS §10.67): `/admin/users/{userId}/…` and
 * `/admin/content/{type}/{id}/…`. Each route names its capability (checked on every request), every change needs the
 * CSRF header and a reason, and the destructive or money ones the authenticator code again.
 */
@Public()
@Controller('admin')
@PANEL_LIMIT
@UseGuards(AdminSessionGuard)
export class AdminControlController {
  constructor(private readonly control: AdminControlService) {}

  @Get('users/:userId/control')
  @RequireCapability('users.control_view')
  state(@Param('userId') id: string, @CurrentAdmin() admin: AdminContext) {
    return this.control.state(pathUuid(id), admin);
  }

  // ---- account ---------------------------------------------------------------------------------------------------

  @Post('users/:userId/lock')
  @HttpCode(200)
  @RequireCapability('users.lock')
  lock(
    @Param('userId') id: string,
    @Body(new ZodValidationPipe(lockBody)) body: Duration,
    @CurrentAdmin() admin: AdminContext,
  ) {
    return this.control.restrict(pathUuid(id), 'LOCK', body, admin);
  }

  @Post('users/:userId/unlock')
  @HttpCode(200)
  @RequireCapability('users.lock')
  unlock(
    @Param('userId') id: string,
    @Body(new ZodValidationPipe(reasonOnlyBody)) body: { reason: string },
    @CurrentAdmin() admin: AdminContext,
  ) {
    return this.control.lift(pathUuid(id), 'LOCK', body.reason, admin);
  }

  @Post('users/:userId/deletion')
  @HttpCode(200)
  @RequireCapability('users.delete')
  requestDeletion(
    @Param('userId') id: string,
    @Body(new ZodValidationPipe(reasonCodeBody)) body: { reason: string; totpCode: string },
    @CurrentAdmin() admin: AdminContext,
  ) {
    return this.control.requestDeletion(pathUuid(id), body, admin);
  }

  @Post('users/:userId/deletion/cancel')
  @HttpCode(200)
  @RequireCapability('users.delete')
  cancelDeletion(
    @Param('userId') id: string,
    @Body(new ZodValidationPipe(reasonOnlyBody)) body: { reason: string },
    @CurrentAdmin() admin: AdminContext,
  ) {
    return this.control.cancelDeletion(pathUuid(id), body.reason, admin);
  }

  // ---- restrictions ----------------------------------------------------------------------------------------------

  @Post('users/:userId/restrictions')
  @HttpCode(200)
  @RequireCapability('users.restrict')
  restrict(
    @Param('userId') id: string,
    @Body(new ZodValidationPipe(restrictBody)) body: Duration & { kind: RestrictionKind },
    @CurrentAdmin() admin: AdminContext,
  ) {
    return this.control.restrict(pathUuid(id), body.kind, body, admin);
  }

  @Post('users/:userId/restrictions/lift')
  @HttpCode(200)
  @RequireCapability('users.restrict')
  lift(
    @Param('userId') id: string,
    @Body(new ZodValidationPipe(liftBody)) body: { kind: AccountRestrictionKind; reason: string },
    @CurrentAdmin() admin: AdminContext,
  ) {
    // A lock is lifted with `unlock` (its own capability).
    if (body.kind === 'LOCK') throw AppException.validation([{ field: 'kind', issue: 'invalid_value' }]);
    return this.control.lift(pathUuid(id), body.kind, body.reason, admin);
  }

  // ---- security --------------------------------------------------------------------------------------------------

  @Post('users/:userId/password/reset-link')
  @HttpCode(200)
  @RequireCapability('users.password')
  resetLink(
    @Param('userId') id: string,
    @Body(new ZodValidationPipe(reasonOnlyBody)) body: { reason: string },
    @CurrentAdmin() admin: AdminContext,
  ) {
    return this.control.sendResetLink(pathUuid(id), body.reason, admin);
  }

  @Post('users/:userId/password/temporary')
  @HttpCode(200)
  @RequireCapability('users.password')
  async temporary(
    @Param('userId') id: string,
    @Body(new ZodValidationPipe(reasonCodeBody)) body: { reason: string; totpCode: string },
    @CurrentAdmin() admin: AdminContext,
    @Res({ passthrough: true }) res: Response,
  ) {
    // Shown once: never cached anywhere.
    res.setHeader('Cache-Control', 'no-store');
    return this.control.temporaryPassword(pathUuid(id), body, admin);
  }

  @Post('users/:userId/password/require-change')
  @HttpCode(200)
  @RequireCapability('users.password')
  requireChange(
    @Param('userId') id: string,
    @Body(new ZodValidationPipe(requireChangeBody)) body: { reason: string; endSessions: boolean },
    @CurrentAdmin() admin: AdminContext,
  ) {
    return this.control.requirePasswordChange(pathUuid(id), body, admin);
  }

  @Post('users/:userId/email')
  @HttpCode(200)
  @RequireCapability('users.email')
  changeEmail(
    @Param('userId') id: string,
    @Body(new ZodValidationPipe(emailChangeBody))
    body: { email: string; markVerified: boolean; reason: string; totpCode: string },
    @CurrentAdmin() admin: AdminContext,
  ) {
    return this.control.changeEmail(pathUuid(id), body, admin);
  }

  @Post('users/:userId/email/resend-verification')
  @HttpCode(200)
  @RequireCapability('users.email')
  resendVerification(
    @Param('userId') id: string,
    @Body(new ZodValidationPipe(reasonOnlyBody)) body: { reason: string },
    @CurrentAdmin() admin: AdminContext,
  ) {
    return this.control.resendVerification(pathUuid(id), body.reason, admin);
  }

  // ---- profile ---------------------------------------------------------------------------------------------------

  @Patch('users/:userId/profile')
  @RequireCapability('users.profile_edit')
  editProfile(
    @Param('userId') id: string,
    @Body(new ZodValidationPipe(profileEditBody))
    body: {
      displayName?: string;
      username?: string;
      bio?: string | null;
      country?: string | null;
      gender?: 'MALE' | 'FEMALE' | 'UNDISCLOSED';
      reason: string;
    },
    @CurrentAdmin() admin: AdminContext,
  ) {
    return this.control.editProfile(pathUuid(id), body, admin);
  }

  // ---- content ---------------------------------------------------------------------------------------------------

  @Get('users/:userId/content')
  @RequireCapability('users.view')
  userContent(
    @Param('userId') id: string,
    @Query(new ZodValidationPipe(userContentQuery))
    q: { kind: 'stories' | 'comments'; page: number; pageSize: number },
  ) {
    return this.control.userContent(pathUuid(id), q.kind, q.page, q.pageSize);
  }

  @Post('content/:type/:contentId/:op')
  @HttpCode(200)
  @RequireCapability('users.content')
  content(
    @Param('type') type: string,
    @Param('contentId') contentId: string,
    @Param('op') op: string,
    @Body() raw: unknown,
    @CurrentAdmin() admin: AdminContext,
  ) {
    if (!(CONTENT_TYPES as readonly string[]).includes(type)) throw new AppException(ErrorCode.NOT_FOUND);
    if (op !== 'hide' && op !== 'restore' && op !== 'delete') throw new AppException(ErrorCode.NOT_FOUND);
    const schema = op === 'delete' ? reasonCodeBody : reasonOnlyBody;
    const body = new ZodValidationPipe(schema).transform(raw) as { reason: string; totpCode?: string };
    return this.control.content(type as ContentType, pathUuid(contentId), op, body, admin);
  }

  // ---- money -----------------------------------------------------------------------------------------------------

  @Post('users/:userId/balance-adjustments')
  @HttpCode(200)
  @RequireCapability('users.balance_adjust')
  adjust(
    @Param('userId') id: string,
    @Body(new ZodValidationPipe(adjustBody))
    body: {
      currency: AdjustCurrency;
      direction: 'CREDIT' | 'DEBIT';
      amount: string;
      allowNegative: boolean;
      reason: string;
      totpCode: string;
    },
    @CurrentAdmin() admin: AdminContext,
  ) {
    return this.control.adjust(pathUuid(id), body, admin);
  }
}
