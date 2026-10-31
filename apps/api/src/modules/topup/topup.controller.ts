import { Body, Controller, Get, Header, Headers, HttpCode, Param, Post, Query, Req } from '@nestjs/common';
import { byUserId, RateLimit, SkipRateLimit } from '../../common/rate-limit/rate-limit.decorator.js';
import { clientIp, userAgent, type AppRequest, type AuthContext } from '../../common/http/request-context.js';
import { getRequestId } from '../../common/request-id/request-id.js';
import { CurrentAuth } from '../auth/current-auth.decorator.js';
import { Public } from '../auth/public.decorator.js';
import {
  TopupService,
  type TopupCheckoutDto,
  type TopupMeDto,
  type TopupOrderDto,
  type TopupPackagesDto,
} from './topup.service.js';
import { renderTopupPage, TOPUP_CSP, TOPUP_CSS, TOPUP_JS, topupLocale } from './topup-web.js';

/** The Stripe webhook's path (outside the JSON body parser: verified over the raw bytes). */
export const STRIPE_WEBHOOK_PATH = '/api/v1/payments/stripe/webhook';

/**
 * Card top-ups (contract v1.59-social draft, D190, CONVENTIONS §10.53). The packages are public (the website shows
 * them before sign-in); checkout, the order's status and the caller's state need the access token; the webhook is
 * Stripe's (signature-verified, no rate limit). Every operation answers 503 TOPUP_UNAVAILABLE while the Stripe
 * keys are missing.
 */
@Controller()
export class TopupController {
  constructor(private readonly topup: TopupService) {}

  @Public()
  @Get('topup/packages')
  packages(): Promise<TopupPackagesDto> {
    return this.topup.packages();
  }

  @Get('topup/me')
  me(@CurrentAuth() auth: AuthContext): Promise<TopupMeDto> {
    return this.topup.me(auth.userId);
  }

  @Post('topup/checkout')
  @HttpCode(201)
  @RateLimit({ bucket: 'topup:checkout', rule: 'topupCheckoutUser', key: byUserId, replacesDefault: true })
  checkout(
    @CurrentAuth() auth: AuthContext,
    @Body() body: unknown,
    @Req() req: AppRequest,
  ): Promise<TopupCheckoutDto> {
    return this.topup.checkout(auth.userId, body, {
      ip: clientIp(req),
      userAgent: userAgent(req),
      requestId: getRequestId(req),
    });
  }

  @Get('topup/orders/:orderId')
  order(@CurrentAuth() auth: AuthContext, @Param('orderId') orderId: string): Promise<TopupOrderDto> {
    return this.topup.order(auth.userId, orderId);
  }

  @Public()
  @SkipRateLimit()
  @Post('payments/stripe/webhook')
  @HttpCode(200)
  webhook(
    @Req() req: AppRequest,
    @Headers('stripe-signature') signature: string | undefined,
  ): Promise<{ received: true }> {
    return this.topup.webhook(req.body, signature);
  }
}

/** The website's pages and assets, outside the `/api/v1` prefix (app.setup.ts). */
@Controller('topup')
export class TopupWebController {
  @Public()
  @Get()
  @Header('Content-Type', 'text/html; charset=utf-8')
  @Header('Content-Security-Policy', TOPUP_CSP)
  main(@Query('lang') lang: unknown): string {
    return renderTopupPage('main', topupLocale(lang), null);
  }

  @Public()
  @Get('success')
  @Header('Content-Type', 'text/html; charset=utf-8')
  @Header('Content-Security-Policy', TOPUP_CSP)
  success(@Query('lang') lang: unknown, @Query('order') order: unknown): string {
    return renderTopupPage('success', topupLocale(lang), order);
  }

  @Public()
  @Get('cancel')
  @Header('Content-Type', 'text/html; charset=utf-8')
  @Header('Content-Security-Policy', TOPUP_CSP)
  cancel(@Query('lang') lang: unknown, @Query('order') order: unknown): string {
    return renderTopupPage('cancel', topupLocale(lang), order);
  }

  @Public()
  @Get('assets/topup.js')
  @Header('Content-Type', 'text/javascript; charset=utf-8')
  script(): string {
    return TOPUP_JS;
  }

  @Public()
  @Get('assets/topup.css')
  @Header('Content-Type', 'text/css; charset=utf-8')
  style(): string {
    return TOPUP_CSS;
  }
}
