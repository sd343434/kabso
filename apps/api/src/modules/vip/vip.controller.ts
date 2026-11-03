import { Body, Controller, Get, Headers, Post, Req, Res } from '@nestjs/common';
import type { Response } from 'express';
import { z } from 'zod';
import { AppException } from '../../common/errors/app-exception.js';
import { languageFromAcceptLanguage, type ContentLanguage } from '../../common/http/content-language.js';
import type { AppRequest, AuthContext } from '../../common/http/request-context.js';
import { ZodValidationPipe } from '../../common/validation/zod-validation.pipe.js';
import { CurrentAuth } from '../auth/current-auth.decorator.js';
import { UsersService } from '../users/users.service.js';
import { buyVipBody } from './vip.schemas.js';
import { VipService, type MyVipDto, type VipPurchaseResultDto, type VipTierListDto } from './vip.service.js';

const idempotencyKeySchema = z.uuid();

/**
 * «شراء VIP» (contract v1.82-social draft, D252, CONVENTIONS §10.92): the tiers on sale, the caller's membership and a
 * purchase with coins. Every route needs a signed-in caller and uses the per-user default rate limit; names follow
 * `Accept-Language`, else the caller's locale.
 */
@Controller()
export class VipController {
  constructor(
    private readonly vip: VipService,
    private readonly users: UsersService,
  ) {}

  private async language(req: AppRequest, auth: AuthContext): Promise<ContentLanguage> {
    return (
      languageFromAcceptLanguage(req.headers['accept-language']) ?? (await this.users.getLocale(auth.userId))
    );
  }

  @Get('vip/tiers')
  async tiers(@CurrentAuth() auth: AuthContext, @Req() req: AppRequest): Promise<VipTierListDto> {
    return this.vip.tiers(await this.language(req, auth));
  }

  @Get('me/vip')
  async mine(@CurrentAuth() auth: AuthContext, @Req() req: AppRequest): Promise<MyVipDto> {
    return this.vip.mine(auth.userId, await this.language(req, auth));
  }

  /** Buy, renew or upgrade. 201 new, 200 a retry with the same `Idempotency-Key`. */
  @Post('me/vip/purchases')
  async buy(
    @CurrentAuth() auth: AuthContext,
    @Req() req: AppRequest,
    @Headers('idempotency-key') rawKey: string | undefined,
    @Body(new ZodValidationPipe(buyVipBody)) body: z.output<typeof buyVipBody>,
    @Res({ passthrough: true }) res: Response,
  ): Promise<VipPurchaseResultDto> {
    if (rawKey === undefined || rawKey === '') {
      throw AppException.validation([{ field: 'Idempotency-Key', issue: 'required' }]);
    }
    const key = idempotencyKeySchema.safeParse(rawKey);
    if (!key.success) throw AppException.validation([{ field: 'Idempotency-Key', issue: 'invalid_format' }]);
    const { replay, result } = await this.vip.buy(
      auth.userId,
      key.data,
      body,
      await this.language(req, auth),
    );
    res.status(replay ? 200 : 201);
    return result;
  }
}
