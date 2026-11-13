import { Body, Controller, Get, Headers, Post, Query, Req, Res } from '@nestjs/common';
import type { Response } from 'express';
import { z } from 'zod';
import { AppException } from '../../common/errors/app-exception.js';
import { languageFromAcceptLanguage, type ContentLanguage } from '../../common/http/content-language.js';
import type { AppRequest, AuthContext } from '../../common/http/request-context.js';
import { byUserId, RateLimit } from '../../common/rate-limit/rate-limit.decorator.js';
import { ZodValidationPipe } from '../../common/validation/zod-validation.pipe.js';
import { CurrentAuth } from '../auth/current-auth.decorator.js';
import { UsersService } from '../users/users.service.js';
import {
  buyStoreItemBody,
  storeItemsQuery,
  type BuyStoreItemBody,
  type StoreItemsQuery,
} from './store.schemas.js';
import { StoreService, type StoreItemListDto, type StorePurchaseResultDto } from './store.service.js';

const idempotencyKeySchema = z.uuid();

/**
 * «المتجر» (contract v1.84-social draft, D270, CONVENTIONS §10.98): the items on sale and a purchase — for oneself or
 * a gift — with coins or cherries. Every route needs a signed-in caller; names follow `Accept-Language`, else the
 * caller's locale.
 */
@Controller()
export class StoreController {
  constructor(
    private readonly store: StoreService,
    private readonly users: UsersService,
  ) {}

  private async language(req: AppRequest, auth: AuthContext): Promise<ContentLanguage> {
    return (
      languageFromAcceptLanguage(req.headers['accept-language']) ?? (await this.users.getLocale(auth.userId))
    );
  }

  /** Per-user default rate limit. */
  @Get('store/items')
  async items(
    @CurrentAuth() auth: AuthContext,
    @Req() req: AppRequest,
    @Query(new ZodValidationPipe(storeItemsQuery)) query: StoreItemsQuery,
  ): Promise<StoreItemListDto> {
    return this.store.items(auth.userId, query, await this.language(req, auth));
  }

  /** Buy (201), or a retry with the same `Idempotency-Key` (200). 30 / hour per user (bucket `store:buy`, §7). */
  @Post('me/store/purchases')
  @RateLimit({ bucket: 'store:buy', rule: 'bagSendUser', key: byUserId, replacesDefault: true })
  async buy(
    @CurrentAuth() auth: AuthContext,
    @Req() req: AppRequest,
    @Headers('idempotency-key') rawKey: string | undefined,
    @Body(new ZodValidationPipe(buyStoreItemBody)) body: BuyStoreItemBody,
    @Res({ passthrough: true }) res: Response,
  ): Promise<StorePurchaseResultDto> {
    if (rawKey === undefined || rawKey === '') {
      throw AppException.validation([{ field: 'Idempotency-Key', issue: 'required' }]);
    }
    const key = idempotencyKeySchema.safeParse(rawKey);
    if (!key.success) throw AppException.validation([{ field: 'Idempotency-Key', issue: 'invalid_format' }]);
    const { replay, result } = await this.store.buy(
      auth.userId,
      key.data,
      body,
      await this.language(req, auth),
    );
    res.status(replay ? 200 : 201);
    return result;
  }
}
