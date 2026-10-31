import { Body, Controller, Get, HttpCode, Param, Post, Query, Req, Res, UseGuards } from '@nestjs/common';
import type { Response } from 'express';
import { byIp, RateLimit } from '../../common/rate-limit/rate-limit.decorator.js';
import { clientIp } from '../../common/http/request-context.js';
import { getRequestId } from '../../common/request-id/request-id.js';
import { ZodValidationPipe } from '../../common/validation/zod-validation.pipe.js';
import { Public } from '../auth/public.decorator.js';
import { adminReportsQuerySchema, type AdminReportsQuery } from '../safety/safety.schemas.js';
import {
  ADMIN_COOKIE,
  AdminAuthService,
  type AdminContext,
  type IssuedSession,
} from './admin-auth.service.js';
import { AdminFinanceService } from './admin-finance.service.js';
import { AdminModerationService } from './admin-moderation.service.js';
import { AdminOrdersService } from './admin-orders.service.js';
import {
  adminCodeSchema,
  adminLoginSchema,
  adminSecondFactorSchema,
  agentsQuerySchema,
  applicationsQuerySchema,
  capSchema,
  disputeResolveSchema,
  disputesQuerySchema,
  exchangeRateBodySchema,
  orderAdminMessageSchema,
  pathCountry,
  panelReportActionSchema,
  pathUuid,
  reasonSchema,
  specialUsernameSchema,
  topUpSchema,
  userSearchSchema,
  withdrawalPaySchema,
  withdrawalRejectSchema,
  withdrawalsQuerySchema,
} from './admin-panel.schemas.js';
import {
  AdminPendingStage,
  AdminSessionGuard,
  AdminSignedIn,
  CurrentAdmin,
  RequireCapability,
  type AdminRequest,
} from './admin-session.guard.js';
import { AdminUsersService } from './admin-users.service.js';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';

/** Every cookie-authenticated panel route: per-IP limit instead of the public default (§10.54.2). */
const PANEL_LIMIT = RateLimit({ bucket: 'admin:ip', rule: 'adminIp', key: byIp, replacesDefault: true });
const LOGIN_LIMIT = RateLimit({
  bucket: 'admin_login:ip',
  rule: 'adminLoginIp',
  key: byIp,
  replacesDefault: true,
});

function setSessionCookie(res: Response, issued: IssuedSession): void {
  res.cookie(ADMIN_COOKIE, issued.token, {
    httpOnly: true,
    secure: true,
    sameSite: 'strict',
    path: '/',
    maxAge: issued.maxAgeSeconds * 1000,
  });
  res.setHeader('Cache-Control', 'no-store');
}

function clearSessionCookie(res: Response): void {
  res.clearCookie(ADMIN_COOKIE, { httpOnly: true, secure: true, sameSite: 'strict', path: '/' });
  res.setHeader('Cache-Control', 'no-store');
}

function meta(req: AdminRequest) {
  return { ip: clientIp(req), requestId: getRequestId(req) };
}

/** `/admin/auth/*`: the panel's sign-in (v1.60-social, D191, CONVENTIONS §10.54.2). */
@Public()
@Controller('admin/auth')
export class AdminAuthController {
  constructor(private readonly auth: AdminAuthService) {}

  @Post('login')
  @HttpCode(200)
  @LOGIN_LIMIT
  async login(
    @Body(new ZodValidationPipe(adminLoginSchema)) body: { email: string; password: string },
    @Req() req: AdminRequest,
    @Res({ passthrough: true }) res: Response,
  ) {
    const issued = await this.auth.login(body.email, body.password, meta(req));
    setSessionCookie(res, issued);
    return {
      next: issued.next,
      csrfToken: issued.csrfToken,
      expiresAt: new Date(Date.now() + issued.maxAgeSeconds * 1000).toISOString(),
    };
  }

  @Post('totp/enrolment')
  @HttpCode(200)
  @LOGIN_LIMIT
  @UseGuards(AdminSessionGuard)
  @AdminPendingStage()
  async enrolStart(@Req() req: AdminRequest) {
    return this.auth.enrolStart(req.adminSession!, meta(req));
  }

  @Post('totp/enrolment/confirm')
  @HttpCode(200)
  @LOGIN_LIMIT
  @UseGuards(AdminSessionGuard)
  @AdminPendingStage()
  async enrolConfirm(
    @Body(new ZodValidationPipe(adminCodeSchema)) body: { code: string },
    @Req() req: AdminRequest,
    @Res({ passthrough: true }) res: Response,
  ) {
    const { issued, recoveryCodes } = await this.auth.enrolConfirm(req.adminSession!, body.code, meta(req));
    setSessionCookie(res, issued);
    return { recoveryCodes, session: await this.auth.meOfIssued(issued, meta(req)) };
  }

  @Post('totp/verify')
  @HttpCode(200)
  @LOGIN_LIMIT
  @UseGuards(AdminSessionGuard)
  @AdminPendingStage()
  async verify(
    @Body(new ZodValidationPipe(adminSecondFactorSchema)) body: { code: string } | { recoveryCode: string },
    @Req() req: AdminRequest,
    @Res({ passthrough: true }) res: Response,
  ) {
    const issued = await this.auth.verify(req.adminSession!, body, meta(req));
    setSessionCookie(res, issued);
    return this.auth.meOfIssued(issued, meta(req));
  }

  @Get('session')
  @PANEL_LIMIT
  @UseGuards(AdminSessionGuard)
  @AdminSignedIn()
  async session(
    @CurrentAdmin() admin: AdminContext,
    @Req() req: AdminRequest,
    @Res({ passthrough: true }) res: Response,
  ) {
    res.setHeader('Cache-Control', 'no-store');
    return this.auth.me(admin, req.adminToken!);
  }

  @Post('logout')
  @HttpCode(204)
  @PANEL_LIMIT
  @UseGuards(AdminSessionGuard)
  @AdminSignedIn()
  async logout(
    @CurrentAdmin() admin: AdminContext,
    @Res({ passthrough: true }) res: Response,
  ): Promise<void> {
    await this.auth.logout(admin);
    clearSessionCookie(res);
  }
}

/** Home, users (§10.54.5 sections 1–2). */
@Public()
@Controller('admin')
@PANEL_LIMIT
@UseGuards(AdminSessionGuard)
export class AdminUsersController {
  constructor(private readonly users: AdminUsersService) {}

  @Get('dashboard')
  @RequireCapability('dashboard.view')
  dashboard() {
    return this.users.dashboard();
  }

  @Get('users')
  @RequireCapability('users.view')
  search(@Query(new ZodValidationPipe(userSearchSchema)) query: { q: string; limit: number }) {
    return this.users.search(query.q, query.limit);
  }

  @Get('users/:userId')
  @RequireCapability('users.view')
  detail(@Param('userId') userId: string, @CurrentAdmin() admin: AdminContext) {
    return this.users.detail(pathUuid(userId), admin);
  }

  @Post('users/:userId/ban')
  @HttpCode(200)
  @RequireCapability('users.ban')
  ban(
    @Param('userId') userId: string,
    @Body(new ZodValidationPipe(reasonSchema)) body: { reason: string },
    @CurrentAdmin() admin: AdminContext,
  ) {
    return this.users.ban(pathUuid(userId), body.reason, admin);
  }

  @Post('users/:userId/unban')
  @HttpCode(200)
  @RequireCapability('users.ban')
  unban(
    @Param('userId') userId: string,
    @Body(new ZodValidationPipe(reasonSchema)) body: { reason: string },
    @CurrentAdmin() admin: AdminContext,
  ) {
    return this.users.unban(pathUuid(userId), body.reason, admin);
  }

  @Post('users/:userId/avatar/remove')
  @HttpCode(200)
  @RequireCapability('users.avatar')
  removeAvatar(
    @Param('userId') userId: string,
    @Body(new ZodValidationPipe(reasonSchema)) body: { reason: string },
    @CurrentAdmin() admin: AdminContext,
  ) {
    return this.users.removeAvatar(pathUuid(userId), body.reason, admin);
  }

  @Post('users/:userId/special-username')
  @HttpCode(200)
  @RequireCapability('users.special_username')
  giftSpecial(
    @Param('userId') userId: string,
    @Body(new ZodValidationPipe(specialUsernameSchema))
    body: { username: string; days?: number; permanent?: true; reason: string },
    @CurrentAdmin() admin: AdminContext,
  ) {
    return this.users.giftSpecial(pathUuid(userId), body, admin);
  }

  @Post('users/:userId/special-username/revoke')
  @HttpCode(200)
  @RequireCapability('users.special_username')
  revokeSpecial(
    @Param('userId') userId: string,
    @Body(new ZodValidationPipe(reasonSchema)) body: { reason: string },
    @CurrentAdmin() admin: AdminContext,
  ) {
    return this.users.revokeSpecial(pathUuid(userId), body.reason, admin);
  }
}

/** Recharge agents and withdrawals (§10.54.5 sections 3–4). */
@Public()
@Controller('admin')
@PANEL_LIMIT
@UseGuards(AdminSessionGuard)
export class AdminFinanceController {
  constructor(private readonly finance: AdminFinanceService) {}

  @Get('recharge/applications')
  @RequireCapability('recharge.applications')
  applications(
    @Query(new ZodValidationPipe(applicationsQuerySchema))
    query: {
      status?: 'PENDING' | 'APPROVED' | 'REJECTED';
      cursor?: string;
      limit: number;
    },
  ) {
    return this.finance.applications(query);
  }

  @Get('recharge/applications/:applicationId')
  @RequireCapability('recharge.applications')
  application(@Param('applicationId') id: string, @CurrentAdmin() admin: AdminContext) {
    return this.finance.application(pathUuid(id), admin);
  }

  @Get('recharge/applications/:applicationId/photos/:which')
  @RequireCapability('recharge.applications')
  async photo(
    @Param('applicationId') id: string,
    @Param('which') which: string,
    @CurrentAdmin() admin: AdminContext,
    @Res() res: Response,
  ): Promise<void> {
    if (which !== 'photo' && which !== 'selfie') throw new AppException(ErrorCode.NOT_FOUND);
    const bytes = await this.finance.photo(pathUuid(id), which, admin);
    res.setHeader('Content-Type', 'image/webp');
    res.setHeader('Cache-Control', 'private, no-store');
    res.setHeader('Content-Disposition', 'inline');
    res.setHeader('X-Content-Type-Options', 'nosniff');
    res.status(200).end(bytes);
  }

  @Post('recharge/applications/:applicationId/approve')
  @HttpCode(200)
  @RequireCapability('recharge.decide')
  approve(@Param('applicationId') id: string, @CurrentAdmin() admin: AdminContext) {
    return this.finance.approve(pathUuid(id), admin);
  }

  @Post('recharge/applications/:applicationId/reject')
  @HttpCode(200)
  @RequireCapability('recharge.decide')
  reject(
    @Param('applicationId') id: string,
    @Body(new ZodValidationPipe(reasonSchema)) body: { reason: string },
    @CurrentAdmin() admin: AdminContext,
  ) {
    return this.finance.reject(pathUuid(id), body.reason, admin);
  }

  @Get('recharge/agents')
  @RequireCapability('recharge.agents')
  agents(
    @Query(new ZodValidationPipe(agentsQuerySchema))
    query: {
      status?: 'APPROVED' | 'ACTIVE' | 'SUSPENDED';
      cursor?: string;
      limit: number;
    },
  ) {
    return this.finance.agents(query);
  }

  @Post('recharge/agents/:agentUserId/topup')
  @HttpCode(200)
  @RequireCapability('recharge.topup')
  topUp(
    @Param('agentUserId') id: string,
    @Body(new ZodValidationPipe(topUpSchema))
    body: { coins: string; paidUsd: string; note?: string; totpCode: string },
    @CurrentAdmin() admin: AdminContext,
  ) {
    return this.finance.topUp(pathUuid(id), body, admin);
  }

  @Post('recharge/agents/:agentUserId/suspend')
  @HttpCode(200)
  @RequireCapability('recharge.status')
  suspend(
    @Param('agentUserId') id: string,
    @Body(new ZodValidationPipe(reasonSchema)) body: { reason: string },
    @CurrentAdmin() admin: AdminContext,
  ) {
    return this.finance.suspend(pathUuid(id), body.reason, admin);
  }

  @Post('recharge/agents/:agentUserId/reinstate')
  @HttpCode(200)
  @RequireCapability('recharge.status')
  reinstate(
    @Param('agentUserId') id: string,
    @Body(new ZodValidationPipe(reasonSchema)) body: { reason: string },
    @CurrentAdmin() admin: AdminContext,
  ) {
    return this.finance.reinstate(pathUuid(id), body.reason, admin);
  }

  @Post('recharge/agents/:agentUserId/cap')
  @HttpCode(200)
  @RequireCapability('recharge.cap')
  cap(
    @Param('agentUserId') id: string,
    @Body(new ZodValidationPipe(capSchema)) body: { cap: string | null; reason: string },
    @CurrentAdmin() admin: AdminContext,
  ) {
    return this.finance.setCap(pathUuid(id), body.cap, body.reason, admin);
  }

  @Get('withdrawals')
  @RequireCapability('withdrawals.view')
  withdrawals(
    @Query(new ZodValidationPipe(withdrawalsQuerySchema))
    query: {
      status: 'PENDING' | 'PAID' | 'REJECTED';
      cursor?: string;
      limit: number;
    },
  ) {
    return this.finance.withdrawals(query);
  }

  @Post('withdrawals/:withdrawalId/pay')
  @HttpCode(200)
  @RequireCapability('withdrawals.decide')
  pay(
    @Param('withdrawalId') id: string,
    @Body(new ZodValidationPipe(withdrawalPaySchema))
    body: { reference: string; note?: string; totpCode: string },
    @CurrentAdmin() admin: AdminContext,
  ) {
    return this.finance.payWithdrawal(pathUuid(id), body, admin);
  }

  @Post('withdrawals/:withdrawalId/reject')
  @HttpCode(200)
  @RequireCapability('withdrawals.decide')
  rejectWithdrawal(
    @Param('withdrawalId') id: string,
    @Body(new ZodValidationPipe(withdrawalRejectSchema)) body: { reason: string; totpCode: string },
    @CurrentAdmin() admin: AdminContext,
  ) {
    return this.finance.rejectWithdrawal(pathUuid(id), body, admin);
  }
}

/** Reports and moderation (§10.54.5 section 5). */
@Public()
@Controller('admin/moderation')
@PANEL_LIMIT
@UseGuards(AdminSessionGuard)
export class AdminModerationController {
  constructor(private readonly moderation: AdminModerationService) {}

  @Get('reports')
  @RequireCapability('reports.view')
  list(@Query(new ZodValidationPipe(adminReportsQuerySchema)) query: AdminReportsQuery) {
    return this.moderation.list(query);
  }

  @Post('reports/:reportId/actions')
  @HttpCode(200)
  @RequireCapability('reports.act')
  act(
    @Param('reportId') id: string,
    @Body(new ZodValidationPipe(panelReportActionSchema))
    body: { action: 'DISMISS' | 'REMOVE_TARGET' | 'WARN' | 'BAN'; note?: string },
    @CurrentAdmin() admin: AdminContext,
  ) {
    return this.moderation.act(pathUuid(id), body, admin);
  }
}

/** v1.69-social (D204, §10.64.6): «نزاعات الشحن» and «أسعار الصرف». */
@Public()
@Controller('admin/recharge')
@PANEL_LIMIT
@UseGuards(AdminSessionGuard)
export class AdminRechargeOrdersController {
  constructor(private readonly orders: AdminOrdersService) {}

  @Get('disputes')
  @RequireCapability('recharge.disputes')
  disputes(
    @Query(new ZodValidationPipe(disputesQuerySchema))
    query: {
      status: 'OPEN' | 'RESOLVED';
      cursor?: string;
      limit: number;
    },
  ) {
    return this.orders.disputes(query);
  }

  @Get('orders/:orderId')
  @RequireCapability('recharge.disputes')
  order(@Param('orderId') id: string, @CurrentAdmin() admin: AdminContext) {
    return this.orders.order(pathUuid(id), admin);
  }

  @Get('orders/:orderId/messages/:messageId/image')
  @RequireCapability('recharge.disputes')
  async image(
    @Param('orderId') id: string,
    @Param('messageId') messageId: string,
    @CurrentAdmin() admin: AdminContext,
    @Res() res: Response,
  ): Promise<void> {
    const bytes = await this.orders.image(pathUuid(id), messageId, admin);
    res.setHeader('Content-Type', 'image/webp');
    res.setHeader('Cache-Control', 'private, no-store');
    res.setHeader('Content-Disposition', 'inline');
    res.setHeader('X-Content-Type-Options', 'nosniff');
    res.status(200).end(bytes);
  }

  @Post('orders/:orderId/messages')
  @HttpCode(201)
  @RequireCapability('recharge.disputes')
  post(
    @Param('orderId') id: string,
    @Body(new ZodValidationPipe(orderAdminMessageSchema)) body: { text: string },
    @CurrentAdmin() admin: AdminContext,
  ) {
    return this.orders.post(pathUuid(id), body.text, admin);
  }

  @Post('orders/:orderId/resolve')
  @HttpCode(200)
  @RequireCapability('recharge.disputes.resolve')
  resolve(
    @Param('orderId') id: string,
    @Body(new ZodValidationPipe(disputeResolveSchema))
    body: { outcome: 'CREDIT_BUYER' | 'REFUND_AGENT'; reason: string; totpCode: string },
    @CurrentAdmin() admin: AdminContext,
  ) {
    return this.orders.resolve(pathUuid(id), body, admin);
  }

  @Get('exchange-rates')
  @RequireCapability('recharge.agents')
  rates() {
    return this.orders.rates();
  }

  @Post('exchange-rates/:country')
  @HttpCode(200)
  @RequireCapability('recharge.rates')
  setRate(
    @Param('country') country: string,
    @Body(new ZodValidationPipe(exchangeRateBodySchema))
    body: { currency: string; unitsPerUsd: string; digits: number; reason: string },
    @CurrentAdmin() admin: AdminContext,
  ) {
    return this.orders.setRate(pathCountry(country), body, admin);
  }

  @Post('exchange-rates/:country/clear')
  @HttpCode(200)
  @RequireCapability('recharge.rates')
  clearRate(
    @Param('country') country: string,
    @Body(new ZodValidationPipe(reasonSchema)) body: { reason: string },
    @CurrentAdmin() admin: AdminContext,
  ) {
    return this.orders.clearRate(pathCountry(country), body.reason, admin);
  }
}
