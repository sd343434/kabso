import { Body, Controller, Get, HttpCode, Post, Query, Req } from '@nestjs/common';
import { languageFromAcceptLanguage } from '../../common/http/content-language.js';
import type { AppRequest, AuthContext } from '../../common/http/request-context.js';
import { SkipRateLimit } from '../../common/rate-limit/rate-limit.decorator.js';
import { ZodValidationPipe } from '../../common/validation/zod-validation.pipe.js';
import { CurrentAuth } from '../auth/current-auth.decorator.js';
import { Public } from '../auth/public.decorator.js';
import {
  appleNotificationSchema,
  googleRtdnSchema,
  iapCatalogQuery,
  verifyIapSchema,
  type VerifyIapInput,
} from './iap.schemas.js';
import { IapService, type IapCatalogDto, type IapPurchaseResultDto } from './iap.service.js';

/**
 * v1.110-social (D345, CONVENTIONS §10.144): coins from the stores. The catalogue and the verification need the access
 * token (the per-user default rate limit); the two store endpoints are the stores' (verified: Apple's signed payload,
 * Google's secret push token), with no rate limit. Every operation of a store that is not configured answers 503
 * STORE_IAP_UNAVAILABLE (the catalogue says `available: false` instead).
 */
@Controller()
export class IapController {
  constructor(private readonly iap: IapService) {}

  @Get('store/iap/catalog')
  catalog(
    @CurrentAuth() auth: AuthContext,
    @Query(new ZodValidationPipe(iapCatalogQuery)) q: { platform: 'ANDROID' | 'IOS' },
  ): Promise<IapCatalogDto> {
    return this.iap.catalog(auth.userId, auth.sessionId, q.platform);
  }

  @Post('store/iap/purchases')
  @HttpCode(200)
  verify(
    @CurrentAuth() auth: AuthContext,
    @Body(new ZodValidationPipe(verifyIapSchema)) body: VerifyIapInput,
    @Req() req: AppRequest,
  ): Promise<IapPurchaseResultDto> {
    return this.iap.verify(
      auth.userId,
      auth.sessionId,
      body,
      languageFromAcceptLanguage(req.headers['accept-language']),
    );
  }

  @Public()
  @SkipRateLimit()
  @Post('payments/apple/notifications')
  @HttpCode(200)
  apple(@Body(new ZodValidationPipe(appleNotificationSchema)) body: { signedPayload: string }) {
    return this.iap.appleNotification(body.signedPayload);
  }

  @Public()
  @SkipRateLimit()
  @Post('payments/google/rtdn')
  @HttpCode(200)
  google(
    @Query('token') token: unknown,
    @Body(new ZodValidationPipe(googleRtdnSchema)) body: { message: Record<string, unknown> },
  ) {
    return this.iap.googleRtdn(typeof token === 'string' ? token : undefined, body);
  }
}
