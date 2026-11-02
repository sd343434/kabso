import {
  Body,
  Controller,
  Get,
  Headers,
  HttpCode,
  Param,
  Patch,
  Post,
  Req,
  Res,
  UseGuards,
} from '@nestjs/common';
import type { Response } from 'express';
import type { AppRequest, AuthContext } from '../../common/http/request-context.js';
import { byIp, byUserId, RateLimit, SkipRateLimit } from '../../common/rate-limit/rate-limit.decorator.js';
import { ZodValidationPipe } from '../../common/validation/zod-validation.pipe.js';
import type { AdminContext } from '../admin-panel/admin-auth.service.js';
import { AdminSessionGuard, CurrentAdmin, RequireCapability } from '../admin-panel/admin-session.guard.js';
import { CurrentAuth } from '../auth/current-auth.decorator.js';
import { Public } from '../auth/public.decorator.js';
import type { AdminKycCheckDto } from './kyc-core.js';
import { KycAdminService, type AdminKycMediaDto } from './kyc-admin.service.js';
import { KycSettingsService, type AdminKycSettingsDto } from './kyc-settings.service.js';
import {
  clearKycSettingsSchema,
  testKycSettingsSchema,
  updateKycSettingsSchema,
  type ClearKycSettingsInput,
  type KycTestReport,
  type TestKycSettingsInput,
  type UpdateKycSettingsInput,
} from './kyc.rules.js';
import { KycService, type KycCheckDto, type KycSessionStartDto, type MyKycDto } from './kyc.service.js';

/**
 * «تأكيد الهوية» for the person (v1.80-kyc, D227, CONVENTIONS §10.77; tag `kyc`). Reads use the per-user default
 * rate limit; a start also counts in `kyc:start` (and the panel's daily limit), a sync in `kyc:sync`.
 */
@Controller('me/kyc')
export class KycController {
  constructor(private readonly kyc: KycService) {}

  @Get()
  mine(@CurrentAuth() auth: AuthContext): Promise<MyKycDto> {
    return this.kyc.mine(auth.userId);
  }

  /** 201 a new Didit session, 200 the unfinished one opened again. `Cache-Control: no-store` (the URL is personal). */
  @Post('sessions')
  @RateLimit({ bucket: 'kyc:start', rule: 'kycStartUser', key: byUserId })
  async start(
    @CurrentAuth() auth: AuthContext,
    @Body() body: unknown,
    @Res({ passthrough: true }) res: Response,
  ): Promise<KycSessionStartDto> {
    const { created, result } = await this.kyc.start(auth.userId, body);
    res.status(created ? 201 : 200);
    res.setHeader('Cache-Control', 'no-store');
    return result;
  }

  @Post('checks/:checkId/sync')
  @HttpCode(200)
  @RateLimit({ bucket: 'kyc:sync', rule: 'kycSyncUser', key: byUserId })
  sync(@CurrentAuth() auth: AuthContext, @Param('checkId') checkId: string): Promise<KycCheckDto> {
    return this.kyc.sync(auth.userId, checkId);
  }
}

/** Didit's decision webhook (public; verified over the raw bytes — app.setup.ts keeps this path raw). */
@Controller('kyc/didit')
export class KycWebhookController {
  constructor(private readonly kyc: KycService) {}

  @Public()
  @SkipRateLimit()
  @Post('webhook')
  @HttpCode(200)
  webhook(
    @Req() req: AppRequest,
    @Headers('x-timestamp') timestamp: string | undefined,
    @Headers('x-signature-v2') signatureV2: string | undefined,
    @Headers('x-signature') signature: string | undefined,
  ): Promise<{ received: true }> {
    return this.kyc.webhook(req.body, { timestamp, signatureV2, signature });
  }
}

/**
 * `/admin/kyc-settings`: the OWNER's «التحقق من الهوية (Didit)» section, and `/admin/kyc/checks/:id` the team's view
 * of a check (`kyc.view`), behind the panel's cookie session + CSRF. Responses never carry a secret (`no-store`).
 */
@Public()
@Controller('admin')
@RateLimit({ bucket: 'admin:ip', rule: 'adminIp', key: byIp, replacesDefault: true })
@UseGuards(AdminSessionGuard)
export class AdminKycController {
  constructor(
    private readonly settings: KycSettingsService,
    private readonly checks: KycAdminService,
  ) {}

  @Get('kyc-settings')
  @RequireCapability('kyc.settings')
  get(@Res({ passthrough: true }) res: Response): Promise<AdminKycSettingsDto> {
    res.setHeader('Cache-Control', 'no-store');
    return this.settings.view();
  }

  @Patch('kyc-settings')
  @RequireCapability('kyc.settings')
  update(
    @Body(new ZodValidationPipe(updateKycSettingsSchema)) body: UpdateKycSettingsInput,
    @CurrentAdmin() admin: AdminContext,
    @Res({ passthrough: true }) res: Response,
  ): Promise<AdminKycSettingsDto> {
    res.setHeader('Cache-Control', 'no-store');
    return this.settings.update(body, admin);
  }

  @Post('kyc-settings/test')
  @HttpCode(200)
  @RequireCapability('kyc.settings')
  test(
    @Body(new ZodValidationPipe(testKycSettingsSchema)) body: TestKycSettingsInput,
    @CurrentAdmin() admin: AdminContext,
    @Res({ passthrough: true }) res: Response,
  ): Promise<KycTestReport> {
    res.setHeader('Cache-Control', 'no-store');
    return this.settings.test(body, admin);
  }

  @Post('kyc-settings/clear')
  @HttpCode(200)
  @RequireCapability('kyc.settings')
  clear(
    @Body(new ZodValidationPipe(clearKycSettingsSchema)) body: ClearKycSettingsInput,
    @CurrentAdmin() admin: AdminContext,
    @Res({ passthrough: true }) res: Response,
  ): Promise<AdminKycSettingsDto> {
    res.setHeader('Cache-Control', 'no-store');
    return this.settings.clear(body, admin);
  }

  @Get('kyc/checks/:checkId')
  @RequireCapability('kyc.view')
  view(
    @Param('checkId') checkId: string,
    @CurrentAdmin() admin: AdminContext,
    @Res({ passthrough: true }) res: Response,
  ): Promise<AdminKycCheckDto> {
    res.setHeader('Cache-Control', 'no-store');
    return this.checks.view(checkId, admin);
  }

  @Post('kyc/checks/:checkId/media')
  @HttpCode(200)
  @RequireCapability('kyc.view')
  media(
    @Param('checkId') checkId: string,
    @CurrentAdmin() admin: AdminContext,
    @Res({ passthrough: true }) res: Response,
  ): Promise<AdminKycMediaDto> {
    res.setHeader('Cache-Control', 'no-store');
    return this.checks.media(checkId, admin);
  }
}
