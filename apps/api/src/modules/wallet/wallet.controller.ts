import { Controller, Get, Inject, Query, Req } from '@nestjs/common';
import { languageFromAcceptLanguage } from '../../common/http/content-language.js';
import type { AppRequest, AuthContext } from '../../common/http/request-context.js';
import { ZodValidationPipe } from '../../common/validation/zod-validation.pipe.js';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import { PaymentSettingsStore } from '../payment-settings/payment-settings.store.js';
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

/** `RechargePackages` (openapi v1.44-social, D166). */
export interface RechargePackagesDto {
  /** ISO 4217; prices are in its minor unit (cents). */
  currency: string;
  /** Always false until B5 (store purchases) is done. */
  purchasesEnabled: boolean;
  /**
   * v1.59-social (D190): the Kabso website's top-up page for the app's «الشحن من الموقع» link — only while
   * TOPUP_APP_LINK_ENABLED (store policy; off by default) and card top-ups are configured; else null.
   */
  websiteTopupUrl: string | null;
  packages: {
    id: string;
    coins: number;
    bonusCoins: number;
    priceMinor: number;
    originalPriceMinor: number | null;
  }[];
}

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
    @Inject(APP_CONFIG) private readonly config: AppConfig,
    private readonly payments: PaymentSettingsStore,
  ) {}

  /**
   * v1.44-social (D166, CONVENTIONS §10.41): the recharge screen's coin packages, from server config
   * (`WALLET_RECHARGE_PACKAGES`, placeholders until the owner sets them). Purchases are not available
   * (B5: no payment method and no legal review yet), so there is no purchase operation.
   */
  @Get('recharge-packages')
  async rechargePackages(): Promise<RechargePackagesDto> {
    const { rechargePackages, rechargeCurrency } = this.config.programs;
    // D196: the keys and the app-link switch may come from the admin panel (over the env).
    const topup = await this.payments.resolved();
    return {
      currency: rechargeCurrency,
      purchasesEnabled: false,
      websiteTopupUrl:
        topup.options.appLinkEnabled && topup.stripe ? `${topup.stripe.publicBaseUrl}/topup` : null,
      packages: rechargePackages.map((p) => ({ ...p })),
    };
  }

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
