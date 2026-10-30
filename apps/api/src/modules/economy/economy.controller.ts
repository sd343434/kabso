import { Body, Controller, Get, Headers, Param, Post, Query, Req, Res } from '@nestjs/common';
import type { Response } from 'express';
import { languageFromAcceptLanguage } from '../../common/http/content-language.js';
import type { AppRequest, AuthContext } from '../../common/http/request-context.js';
import { ZodValidationPipe } from '../../common/validation/zod-validation.pipe.js';
import { CurrentAuth } from '../auth/current-auth.decorator.js';
import type { PageDto } from '../posts/post-views.js';
import { pageQuerySchema, type PageQuery } from '../posts/posts.schemas.js';
import { UsersService } from '../users/users.service.js';
import {
  AgencyService,
  type AgencyComplaintDto,
  type AgencyHostDto,
  type AgencyPreviewDto,
  type MyAgencyDto,
} from './agency.service.js';
import {
  CherriesService,
  type CherryLedgerEntryDto,
  type CherryWalletDto,
  type CherryWithdrawalDto,
} from './cherries.service.js';

/**
 * The cherry economy (contract v1.52-social draft, D179, CONVENTIONS §10.43): the caller's cherries and
 * withdrawal requests (tag `wallet`) and host agencies (tag `agency`). Every route uses the per-user
 * default rate limit.
 */
@Controller()
export class EconomyController {
  constructor(
    private readonly cherries: CherriesService,
    private readonly agencies: AgencyService,
    private readonly users: UsersService,
  ) {}

  @Get('wallet/me/cherries')
  wallet(@CurrentAuth() auth: AuthContext): Promise<CherryWalletDto> {
    return this.cherries.wallet(auth.userId);
  }

  @Get('wallet/me/cherries/ledger')
  async ledger(
    @CurrentAuth() auth: AuthContext,
    @Req() req: AppRequest,
    @Query(new ZodValidationPipe(pageQuerySchema)) query: PageQuery,
  ): Promise<PageDto<CherryLedgerEntryDto>> {
    const lang =
      languageFromAcceptLanguage(req.headers['accept-language']) ?? (await this.users.getLocale(auth.userId));
    return this.cherries.ledger(auth.userId, query, lang);
  }

  /** 201 requested now (the cherries held), 200 the same Idempotency-Key again. */
  @Post('wallet/me/cherries/withdrawals')
  async withdraw(
    @CurrentAuth() auth: AuthContext,
    @Headers('idempotency-key') key: string | undefined,
    @Body() body: unknown,
    @Res({ passthrough: true }) res: Response,
  ): Promise<CherryWithdrawalDto> {
    const { created, result } = await this.cherries.withdraw(auth.userId, key, body);
    res.status(created ? 201 : 200);
    return result;
  }

  @Get('wallet/me/cherries/withdrawals')
  withdrawals(
    @CurrentAuth() auth: AuthContext,
    @Query(new ZodValidationPipe(pageQuerySchema)) query: PageQuery,
  ): Promise<PageDto<CherryWithdrawalDto>> {
    return this.cherries.withdrawals(auth.userId, query);
  }

  @Get('agencies/:inviteCode')
  agency(@Param('inviteCode') code: string): Promise<AgencyPreviewDto> {
    return this.agencies.byCode(code);
  }

  @Get('me/agency')
  myAgency(@CurrentAuth() auth: AuthContext): Promise<MyAgencyDto> {
    return this.agencies.mine(auth.userId);
  }

  /** 201 joined now, 200 already a host of this agency. */
  @Post('me/agency/join')
  async join(
    @CurrentAuth() auth: AuthContext,
    @Body() body: unknown,
    @Res({ passthrough: true }) res: Response,
  ): Promise<MyAgencyDto> {
    const { created, result } = await this.agencies.join(auth.userId, body);
    res.status(created ? 201 : 200);
    return result;
  }

  @Post('me/agency/leave')
  async leave(
    @CurrentAuth() auth: AuthContext,
    @Res({ passthrough: true }) res: Response,
  ): Promise<MyAgencyDto> {
    const result = await this.agencies.leave(auth.userId);
    res.status(200);
    return result;
  }

  /** 201 filed now, 200 an open complaint already exists (it is returned). */
  @Post('me/agency/complaints')
  async complain(
    @CurrentAuth() auth: AuthContext,
    @Body() body: unknown,
    @Res({ passthrough: true }) res: Response,
  ): Promise<AgencyComplaintDto> {
    const { created, result } = await this.agencies.complain(auth.userId, body);
    res.status(created ? 201 : 200);
    return result;
  }

  @Get('me/agency/hosts')
  hosts(
    @CurrentAuth() auth: AuthContext,
    @Query(new ZodValidationPipe(pageQuerySchema)) query: PageQuery,
  ): Promise<PageDto<AgencyHostDto>> {
    return this.agencies.hosts(auth.userId, query);
  }
}
