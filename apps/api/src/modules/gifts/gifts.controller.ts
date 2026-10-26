import { Controller, Get, Req } from '@nestjs/common';
import { languageFromAcceptLanguage, type ContentLanguage } from '../../common/http/content-language.js';
import type { AppRequest, AuthContext } from '../../common/http/request-context.js';
import { CurrentAuth } from '../auth/current-auth.decorator.js';
import { UsersService } from '../users/users.service.js';
import { GiftsService, type GiftBagDto, type GiftCatalogueDto } from './gifts.service.js';

/**
 * Live gifts (contract v1.23-live draft, CP-020, CONVENTIONS §10.23): the catalogue and the
 * caller's gift bag. Names follow Accept-Language, else the caller's locale. Sending is
 * `POST /live/rooms/{roomId}/gifts` (live module).
 */
@Controller()
export class GiftsController {
  constructor(
    private readonly gifts: GiftsService,
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
}
