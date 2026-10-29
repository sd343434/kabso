import { Controller, Get, Query, Req } from '@nestjs/common';
import { languageFromAcceptLanguage } from '../../common/http/content-language.js';
import type { AppRequest, AuthContext } from '../../common/http/request-context.js';
import { ZodValidationPipe } from '../../common/validation/zod-validation.pipe.js';
import { CurrentAuth } from '../auth/current-auth.decorator.js';
import type { PageDto } from '../posts/post-views.js';
import { pageQuerySchema, type PageQuery } from '../posts/posts.schemas.js';
import { UsersService } from '../users/users.service.js';
import {
  WalletHistoryService,
  type EarningDto,
  type MyEarningsDto,
  type WalletLedgerEntryDto,
} from './wallet-history.service.js';
import { WalletService, type WalletDto } from './wallet.service.js';

/**
 * The caller's coins (contract v1.19-live draft, CP-017, CONVENTIONS §10.19); v1.43-social (D164,
 * §10.40): their coin history and gift earnings. Every route uses the per-user default rate limit.
 */
@Controller('wallet')
export class WalletController {
  constructor(
    private readonly wallet: WalletService,
    private readonly history: WalletHistoryService,
    private readonly users: UsersService,
  ) {}

  @Get('me')
  mine(@CurrentAuth() auth: AuthContext): Promise<WalletDto> {
    return this.wallet.mine(auth.userId);
  }

  /** v1.43-social (D164): every change of the caller's balance, newest first. */
  @Get('me/ledger')
  ledger(
    @CurrentAuth() auth: AuthContext,
    @Query(new ZodValidationPipe(pageQuerySchema)) query: PageQuery,
  ): Promise<PageDto<WalletLedgerEntryDto>> {
    return this.history.ledger(auth.userId, query);
  }

  /** v1.43-social (D164): the caller's gift earnings (display only, D149). */
  @Get('me/earnings')
  earnings(@CurrentAuth() auth: AuthContext): Promise<MyEarningsDto> {
    return this.history.earnings(auth.userId);
  }

  /** v1.43-social (D164): the sends the caller earned from, newest first. */
  @Get('me/earnings/history')
  async earningHistory(
    @CurrentAuth() auth: AuthContext,
    @Req() req: AppRequest,
    @Query(new ZodValidationPipe(pageQuerySchema)) query: PageQuery,
  ): Promise<PageDto<EarningDto>> {
    const lang =
      languageFromAcceptLanguage(req.headers['accept-language']) ?? (await this.users.getLocale(auth.userId));
    return this.history.earningHistory(auth.userId, query, lang);
  }
}
