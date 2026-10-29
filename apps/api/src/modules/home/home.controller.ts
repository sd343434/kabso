import { Controller, Get, Query, Req, Res } from '@nestjs/common';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import type { Response } from 'express';
import { languageFromAcceptLanguage } from '../../common/http/content-language.js';
import type { AppRequest } from '../../common/http/request-context.js';
import { byIp, RateLimit } from '../../common/rate-limit/rate-limit.decorator.js';
import { OptionalAuth } from '../auth/public.decorator.js';
import { UsersService } from '../users/users.service.js';
import { HOME_BANNERS_CACHE_CONTROL } from './home-banners.js';
import { HomeService, type HomeBannerDto } from './home.service.js';

/**
 * v1.39-live (D166): a guest reads the in-room banners per IP, in the same bucket as the other live
 * guest reads (CP-010), since they can watch a live.
 */
const GUEST_READ = {
  bucket: 'live:guest:read',
  rule: 'liveGuestReadIp',
  key: byIp,
  replacesDefault: true,
  appliesTo: 'guest',
} as const;

/** The live hub's extras (contract v1.26-live draft, D124, CONVENTIONS §10.26). */
@Controller('home')
export class HomeController {
  constructor(
    private readonly home: HomeService,
    private readonly users: UsersService,
  ) {}

  /**
   * `GET /home/banners`: signed-in callers (the default rate limit). The title follows
   * `Accept-Language`, else the caller's locale (§10.1). `Cache-Control: private, max-age=60`.
   * v1.39-live (D166, owner: «يجب أن يظهر عند الجميع»): `placement=room` also serves a caller
   * without a token (a guest watching a live; rate limited per IP; Arabic without
   * `Accept-Language`); the live hub's `home` banners stay signed-in only (401).
   */
  @Get('banners')
  @OptionalAuth()
  @RateLimit(GUEST_READ)
  async banners(
    @Req() req: AppRequest,
    @Res({ passthrough: true }) res: Response,
    @Query('placement') placementParam?: unknown,
  ): Promise<{ data: HomeBannerDto[] }> {
    // v1.27.4-live (D137): `placement=home` (default) or `room` (the promo box inside a live).
    if (placementParam !== undefined && placementParam !== 'home' && placementParam !== 'room') {
      throw AppException.validation([{ field: 'placement', issue: 'invalid_value' }]);
    }
    const placement = placementParam === 'room' ? 'ROOM' : 'HOME';
    const caller = req.auth?.userId ?? null;
    if (caller === null && placement === 'HOME') throw new AppException(ErrorCode.AUTH_UNAUTHENTICATED);
    const language =
      languageFromAcceptLanguage(req.headers['accept-language']) ??
      (caller === null ? 'ar' : await this.users.getLocale(caller));
    const data = await this.home.listBanners(language, placement);
    res.setHeader('Cache-Control', HOME_BANNERS_CACHE_CONTROL);
    res.setHeader('Vary', 'Authorization, Accept-Language');
    return { data };
  }
}
