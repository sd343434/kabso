import { Controller, Get, Query, Req, Res } from '@nestjs/common';
import { AppException } from '../../common/errors/app-exception.js';
import type { Response } from 'express';
import { languageFromAcceptLanguage } from '../../common/http/content-language.js';
import type { AppRequest, AuthContext } from '../../common/http/request-context.js';
import { CurrentAuth } from '../auth/current-auth.decorator.js';
import { UsersService } from '../users/users.service.js';
import { HOME_BANNERS_CACHE_CONTROL } from './home-banners.js';
import { HomeService, type HomeBannerDto } from './home.service.js';

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
   */
  @Get('banners')
  async banners(
    @CurrentAuth() auth: AuthContext,
    @Req() req: AppRequest,
    @Res({ passthrough: true }) res: Response,
    @Query('placement') placementParam?: unknown,
  ): Promise<{ data: HomeBannerDto[] }> {
    // v1.27.4-live (D137): `placement=home` (default) or `room` (the promo box inside a live);
    // v1.51-social (D177): `wallet` (the wallet page).
    if (
      placementParam !== undefined &&
      placementParam !== 'home' &&
      placementParam !== 'room' &&
      placementParam !== 'wallet'
    ) {
      throw AppException.validation([{ field: 'placement', issue: 'invalid_value' }]);
    }
    const placement = placementParam === 'room' ? 'ROOM' : placementParam === 'wallet' ? 'WALLET' : 'HOME';
    const language =
      languageFromAcceptLanguage(req.headers['accept-language']) ?? (await this.users.getLocale(auth.userId));
    const data = await this.home.listBanners(language, placement);
    res.setHeader('Cache-Control', HOME_BANNERS_CACHE_CONTROL);
    res.setHeader('Vary', 'Authorization, Accept-Language');
    return { data };
  }
}
