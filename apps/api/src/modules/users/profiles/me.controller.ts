import { Body, Controller, Get, HttpCode, Patch, Req } from '@nestjs/common';
import { languageFromAcceptLanguage } from '../../../common/http/content-language.js';
import { clientIp, type AppRequest, type AuthContext } from '../../../common/http/request-context.js';
import { RateLimit } from '../../../common/rate-limit/rate-limit.decorator.js';
import { getRequestId } from '../../../common/request-id/request-id.js';
import { ZodValidationPipe } from '../../../common/validation/zod-validation.pipe.js';
import { CurrentAuth } from '../../auth/current-auth.decorator.js';
import { CountriesService, type CountryDto } from '../../countries/countries.service.js';
import { updateMeSchema, type UpdateMeInput } from '../me.schemas.js';
import { UsersService, type MeDto } from '../users.service.js';
import { MeService } from './me.service.js';

@Controller()
export class MeController {
  constructor(
    private readonly me: MeService,
    private readonly users: UsersService,
    private readonly countries: CountriesService,
  ) {}

  /**
   * v1.2 locale; v1.4 avatar and country (all optional, at least one). 30 / hour / user, counted
   * together with the per-user default (CONVENTIONS §7: "counts both").
   */
  @Patch('me')
  @HttpCode(200)
  @RateLimit({ bucket: 'update_me:user', rule: 'updateMeUser', key: (req) => req.auth?.userId ?? '' })
  updateMe(
    @CurrentAuth() auth: AuthContext,
    @Req() req: AppRequest,
    @Body(new ZodValidationPipe(updateMeSchema)) body: UpdateMeInput,
  ): Promise<MeDto> {
    return this.me.updateMe(auth.userId, body, { ip: clientIp(req), requestId: getRequestId(req) });
  }

  /**
   * v1.4 `GET /countries` (CONVENTIONS §11.7): every selectable country, localized like category
   * names (§10.1) and sorted by the localized name. Default per-user bucket.
   */
  @Get('countries')
  async listCountries(
    @CurrentAuth() auth: AuthContext,
    @Req() req: AppRequest,
  ): Promise<{ data: CountryDto[] }> {
    const lang =
      languageFromAcceptLanguage(req.headers['accept-language']) ?? (await this.users.getLocale(auth.userId));
    return { data: this.countries.list(lang) };
  }
}
