import { Body, Controller, Get, Param, Put, Req } from '@nestjs/common';
import { languageFromAcceptLanguage, type ContentLanguage } from '../../common/http/content-language.js';
import type { AppRequest, AuthContext } from '../../common/http/request-context.js';
import { byUserId, RateLimit } from '../../common/rate-limit/rate-limit.decorator.js';
import { CurrentAuth } from '../auth/current-auth.decorator.js';
import { UsersService } from '../users/users.service.js';
import {
  MedalsService,
  type MedalCatalogueDto,
  type MedalShowcaseDto,
  type UserMedalListDto,
} from './medals.service.js';

/** Medals (contract v1.21-live draft, CP-018, CONVENTIONS §10.21). Names follow Accept-Language. */
@Controller()
export class MedalsController {
  constructor(
    private readonly medals: MedalsService,
    private readonly users: UsersService,
  ) {}

  private async language(req: AppRequest, auth: AuthContext): Promise<ContentLanguage> {
    return (
      languageFromAcceptLanguage(req.headers['accept-language']) ?? (await this.users.getLocale(auth.userId))
    );
  }

  /** Per-user default rate limit. */
  @Get('medals')
  async catalogue(@CurrentAuth() auth: AuthContext, @Req() req: AppRequest): Promise<MedalCatalogueDto> {
    return this.medals.catalogue(auth.userId, await this.language(req, auth));
  }

  /** Shares the `GET /users/{username}` bucket (profile scraping, §7). */
  @Get('users/:username/medals')
  @RateLimit({ bucket: 'users:profile', rule: 'profileUser', key: byUserId, replacesDefault: true })
  async ofUser(
    @CurrentAuth() auth: AuthContext,
    @Req() req: AppRequest,
    @Param('username') username: string,
  ): Promise<UserMedalListDto> {
    return this.medals.ofUser(username, await this.language(req, auth));
  }

  @Get('me/medals/showcase')
  async myShowcase(@CurrentAuth() auth: AuthContext, @Req() req: AppRequest): Promise<MedalShowcaseDto> {
    return this.medals.myShowcase(auth.userId, await this.language(req, auth));
  }

  /** 60 / hour per user (bucket `medals:showcase`, the family-write numbers; §7). */
  @Put('me/medals/showcase')
  @RateLimit({ bucket: 'medals:showcase', rule: 'familyWriteUser', key: byUserId, replacesDefault: true })
  async setShowcase(
    @CurrentAuth() auth: AuthContext,
    @Req() req: AppRequest,
    @Body() body: unknown,
  ): Promise<MedalShowcaseDto> {
    return this.medals.setShowcase(auth.userId, body, await this.language(req, auth));
  }
}
