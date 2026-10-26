import { Controller, Get, Param, Req } from '@nestjs/common';
import { languageFromAcceptLanguage } from '../../../common/http/content-language.js';
import type { AppRequest, AuthContext } from '../../../common/http/request-context.js';
import { byUserId, RateLimit } from '../../../common/rate-limit/rate-limit.decorator.js';
import { CurrentAuth } from '../../auth/current-auth.decorator.js';
import { UsersService } from '../users.service.js';
import { PublicProfileService, type PublicProfileDto } from './public-profile.service.js';

@Controller('users')
export class PublicProfileController {
  constructor(
    private readonly profiles: PublicProfileService,
    private readonly users: UsersService,
  ) {}

  /**
   * `GET /users/{username}` (v1.3). A malformed `username` is not found (404, never 400 or 500);
   * the users service checks the format before querying (SEC-037). `GET /users/username-availability` is registered first (UsersModule is
   * imported before this module) and cannot be a username anyway (`-` is not allowed).
   */
  @Get(':username')
  @RateLimit({ bucket: 'users:profile', rule: 'profileUser', key: byUserId, replacesDefault: true })
  async get(
    @CurrentAuth() auth: AuthContext,
    @Req() req: AppRequest,
    @Param('username') username: string,
  ): Promise<PublicProfileDto> {
    // v1.21-live (CP-018): CP tier and medal names follow Accept-Language, else the caller's locale.
    const lang =
      languageFromAcceptLanguage(req.headers['accept-language']) ?? (await this.users.getLocale(auth.userId));
    return this.profiles.get(auth.userId, username, lang);
  }
}
