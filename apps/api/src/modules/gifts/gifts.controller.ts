import { Body, Controller, Get, HttpCode, Put, Req } from '@nestjs/common';
import { languageFromAcceptLanguage, type ContentLanguage } from '../../common/http/content-language.js';
import { clientIp, type AppRequest, type AuthContext } from '../../common/http/request-context.js';
import { getRequestId } from '../../common/request-id/request-id.js';
import { byIp, RateLimit } from '../../common/rate-limit/rate-limit.decorator.js';
import { ZodValidationPipe } from '../../common/validation/zod-validation.pipe.js';
import { CurrentAuth } from '../auth/current-auth.decorator.js';
import { OptionalAuth } from '../auth/public.decorator.js';
import { UsersService } from '../users/users.service.js';
import { GiftsService, type GiftBagDto, type GiftCatalogueDto } from './gifts.service.js';
import {
  LuckyGiftsService,
  luckyAgeConfirmationSchema,
  type LuckyGiftOddsDto,
} from './lucky-gifts.service.js';

/** Guest reads (CP-010): per IP instead of per user (the same bucket as the live guest reads). */
const GUEST_READ = {
  bucket: 'live:guest:read',
  rule: 'liveGuestReadIp',
  key: byIp,
  replacesDefault: true,
  appliesTo: 'guest',
} as const;

/**
 * Live gifts (contract v1.23-live draft, CP-020, CONVENTIONS §10.23): the catalogue and the
 * caller's gift bag. Names follow Accept-Language, else the caller's locale. Sending is
 * `POST /live/rooms/{roomId}/gifts` (live module). v1.27-live (D132, §10.27): the lucky-gift odds
 * and the caller's 18+ statement.
 */
@Controller()
export class GiftsController {
  constructor(
    private readonly gifts: GiftsService,
    private readonly lucky: LuckyGiftsService,
    private readonly users: UsersService,
  ) {}

  private async language(req: AppRequest, auth: AuthContext): Promise<ContentLanguage> {
    return (
      languageFromAcceptLanguage(req.headers['accept-language']) ?? (await this.users.getLocale(auth.userId))
    );
  }

  /** Per-user default rate limit (§7). */
  @Get('gifts/catalogue')
  async catalogue(@CurrentAuth() auth: AuthContext, @Req() req: AppRequest): Promise<GiftCatalogueDto> {
    return this.gifts.catalogue(await this.language(req, auth));
  }

  /** Per-user default rate limit (§7). */
  @Get('me/gifts/bag')
  async bag(@CurrentAuth() auth: AuthContext, @Req() req: AppRequest): Promise<GiftBagDto> {
    return this.gifts.bag(auth.userId, await this.language(req, auth));
  }

  /** v1.27-live (D132): the published odds; guests too (per-IP bucket), signed in: per-user default. */
  @Get('live/gifts/lucky/odds')
  @OptionalAuth()
  @RateLimit(GUEST_READ)
  async luckyOdds(@Req() req: AppRequest): Promise<LuckyGiftOddsDto> {
    return this.lucky.odds(req.auth?.userId ?? null, this.lucky.regionOf(req.headers));
  }

  /** v1.27-live (D132): the caller's one-time 18+ statement (per-user default rate limit). */
  @Put('me/lucky-gifts/age-confirmation')
  @HttpCode(200)
  async confirmLuckyAge(
    @CurrentAuth() auth: AuthContext,
    @Req() req: AppRequest,
    @Body(new ZodValidationPipe(luckyAgeConfirmationSchema)) _body: unknown,
  ): Promise<{ ageConfirmedAt: string }> {
    return this.lucky.confirmAge(auth.userId, { ip: clientIp(req), requestId: getRequestId(req) });
  }
}
