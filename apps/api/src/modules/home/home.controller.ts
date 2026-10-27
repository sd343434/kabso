import { Controller, Get, Req, Res } from '@nestjs/common';
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
  ): Promise<{ data: HomeBannerDto[] }> {
    const language =
      languageFromAcceptLanguage(req.headers['accept-language']) ?? (await this.users.getLocale(auth.userId));
    const data = await this.home.listBanners(language);
    res.setHeader('Cache-Control', HOME_BANNERS_CACHE_CONTROL);
    res.setHeader('Vary', 'Authorization, Accept-Language');
    return { data };
  }
}
