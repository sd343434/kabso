import { Body, Controller, Delete, Get, Headers, HttpCode, Post, Put, Req, Res } from '@nestjs/common';
import type { Response } from 'express';
import { z } from 'zod';
import { AppException } from '../../common/errors/app-exception.js';
import { languageFromAcceptLanguage, type ContentLanguage } from '../../common/http/content-language.js';
import type { AppRequest, AuthContext } from '../../common/http/request-context.js';
import { ZodValidationPipe } from '../../common/validation/zod-validation.pipe.js';
import { CurrentAuth } from '../auth/current-auth.decorator.js';
import { UsersService } from '../users/users.service.js';
import {
  VipIdentityService,
  vipGoldenIdClaimBody,
  vipSignatureBody,
  type VipGoldenIdChoiceDto,
  type VipGoldenIdHoldingDto,
  type VipSignatureDto,
} from './vip-identity.service.js';
import { buyVipBody, type BuyVipBody } from './vip.schemas.js';
import {
  VipService,
  type MyVipDto,
  type ProfileVisitorListDto,
  type VipDailyCoinsClaimDto,
  type VipPurchaseResultDto,
  type VipTierListDto,
} from './vip.service.js';

const idempotencyKeySchema = z.uuid();

/**
 * «شراء VIP» (contract v1.82-social draft, D252, CONVENTIONS §10.93): the tiers on sale, the caller's membership and a
 * purchase with coins. Every route needs a signed-in caller and uses the per-user default rate limit; names follow
 * `Accept-Language`, else the caller's locale.
 */
@Controller()
export class VipController {
  constructor(
    private readonly vip: VipService,
    private readonly users: UsersService,
    private readonly identity: VipIdentityService,
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

  /** v1.83-social (D258, §10.94.5). D374 (§10.166.6): retired — always 409 `VIP_UNAVAILABLE` (`perk` `retired`). */
  @Post('me/vip/daily-coins')
  @HttpCode(200)
  claimDailyCoins(): VipDailyCoinsClaimDto {
    return this.vip.claimDailyCoins();
  }

  /** v1.83-social (D258, §10.94.9): «من زار ملفي» (members holding PROFILE_VISITORS). */
  @Get('me/profile-visitors')
  profileVisitors(@CurrentAuth() auth: AuthContext): Promise<ProfileVisitorListDto> {
    return this.vip.profileVisitors(auth.userId);
  }

  /** v1.131-social (D378, §10.168.5): the caller's ANIMATED_SIGNATURE text (null clears it). */
  @Put('me/vip/signature')
  setSignature(
    @CurrentAuth() auth: AuthContext,
    @Body(new ZodValidationPipe(vipSignatureBody)) body: z.output<typeof vipSignatureBody>,
  ): Promise<VipSignatureDto> {
    return this.identity.setSignature(auth.userId, body);
  }

  /** v1.131-social (D378, §10.168.4): the golden IDs the caller may pick and their own. */
  @Get('me/vip/golden-ids')
  goldenIds(@CurrentAuth() auth: AuthContext): Promise<VipGoldenIdChoiceDto> {
    return this.identity.choice(auth.userId);
  }

  /** D378: take a golden ID of the caller's class (one at a time; a held one is given back first). */
  @Post('me/vip/golden-id')
  @HttpCode(200)
  claimGoldenId(
    @CurrentAuth() auth: AuthContext,
    @Body(new ZodValidationPipe(vipGoldenIdClaimBody)) body: z.output<typeof vipGoldenIdClaimBody>,
  ): Promise<VipGoldenIdHoldingDto> {
    return this.identity.claim(auth.userId, body);
  }

  /** D378: give the caller's golden ID back to the stock now. Idempotent. */
  @Delete('me/vip/golden-id')
  @HttpCode(204)
  async releaseGoldenId(@CurrentAuth() auth: AuthContext): Promise<void> {
    await this.identity.release(auth.userId);
  }

  /** Buy, renew or upgrade. 201 new, 200 a retry with the same `Idempotency-Key`. */
  @Post('me/vip/purchases')
  async buy(
    @CurrentAuth() auth: AuthContext,
    @Req() req: AppRequest,
    @Headers('idempotency-key') rawKey: string | undefined,
    @Body(new ZodValidationPipe(buyVipBody)) body: BuyVipBody,
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
