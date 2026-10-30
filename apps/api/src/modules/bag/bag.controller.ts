import { Body, Controller, Get, HttpCode, Post, Put, Query, Req } from '@nestjs/common';
import { languageFromAcceptLanguage, type ContentLanguage } from '../../common/http/content-language.js';
import type { AppRequest, AuthContext } from '../../common/http/request-context.js';
import { byUserId, RateLimit } from '../../common/rate-limit/rate-limit.decorator.js';
import { ZodValidationPipe } from '../../common/validation/zod-validation.pipe.js';
import { CurrentAuth } from '../auth/current-auth.decorator.js';
import { UsersService } from '../users/users.service.js';
import {
  bagQuerySchema,
  equipBodySchema,
  sendBodySchema,
  type BagQuery,
  type EquipBody,
  type SendBody,
} from './bag.schemas.js';
import {
  BagService,
  type BagCatalogueDto,
  type BagDto,
  type BagEquippedDto,
  type BagTransferDto,
} from './bag.service.js';

/** The bag (contract v1.22-live draft, CP-019, CONVENTIONS §10.22; v1.48-social, D171, §10.43). Names follow Accept-Language. */
@Controller()
export class BagController {
  constructor(
    private readonly bag: BagService,
    private readonly users: UsersService,
  ) {}

  private async language(req: AppRequest, auth: AuthContext): Promise<ContentLanguage> {
    return (
      languageFromAcceptLanguage(req.headers['accept-language']) ?? (await this.users.getLocale(auth.userId))
    );
  }

  /** Per-user default rate limit. */
  @Get('bag/catalogue')
  async catalogue(
    @CurrentAuth() auth: AuthContext,
    @Req() req: AppRequest,
    @Query(new ZodValidationPipe(bagQuerySchema)) query: BagQuery,
  ): Promise<BagCatalogueDto> {
    return this.bag.catalogue(query, await this.language(req, auth));
  }

  /** Per-user default rate limit. */
  @Get('me/bag')
  async mine(
    @CurrentAuth() auth: AuthContext,
    @Req() req: AppRequest,
    @Query(new ZodValidationPipe(bagQuerySchema)) query: BagQuery,
  ): Promise<BagDto> {
    return this.bag.mine(auth.userId, query, await this.language(req, auth));
  }

  /** 60 / hour per user (bucket `bag:equip`, the family-write numbers like the medal showcase; §7). */
  @Put('me/bag/equipped')
  @RateLimit({ bucket: 'bag:equip', rule: 'familyWriteUser', key: byUserId, replacesDefault: true })
  async equip(
    @CurrentAuth() auth: AuthContext,
    @Req() req: AppRequest,
    @Body(new ZodValidationPipe(equipBodySchema)) body: EquipBody,
  ): Promise<BagEquippedDto> {
    return this.bag.equip(auth.userId, body, await this.language(req, auth));
  }

  /** v1.48-social (D171): 30 / hour per user (bucket `bag:send`, §7). */
  @Post('me/bag/transfers')
  @HttpCode(201)
  @RateLimit({ bucket: 'bag:send', rule: 'bagSendUser', key: byUserId, replacesDefault: true })
  async send(
    @CurrentAuth() auth: AuthContext,
    @Req() req: AppRequest,
    @Body(new ZodValidationPipe(sendBodySchema)) body: SendBody,
  ): Promise<BagTransferDto> {
    return this.bag.send(auth.userId, body, await this.language(req, auth));
  }
}
