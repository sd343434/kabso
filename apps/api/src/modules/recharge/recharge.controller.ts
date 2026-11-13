import {
  Body,
  Controller,
  Delete,
  Get,
  Headers,
  HttpCode,
  Param,
  Post,
  Put,
  Query,
  Res,
} from '@nestjs/common';
import type { Response } from 'express';
import { z } from 'zod';
import type { AuthContext } from '../../common/http/request-context.js';
import { byUserId, RateLimit } from '../../common/rate-limit/rate-limit.decorator.js';
import { ZodValidationPipe } from '../../common/validation/zod-validation.pipe.js';
import { CurrentAuth } from '../auth/current-auth.decorator.js';
import type { PageDto } from '../posts/post-views.js';
import { pageQuerySchema, type PageQuery } from '../posts/posts.schemas.js';
import {
  RechargeService,
  type AvailabilityDto,
  type RechargeAgentListingDto,
  type RechargeAgentMeDto,
  type RechargeCherryRequestDto,
  type RechargeEmployeeDto,
  type RechargeSaleDto,
} from './recharge.service.js';

const directoryQuerySchema = pageQuerySchema.extend({ country: z.string().max(8).optional() });

const WRITE = {
  bucket: 'recharge:write',
  rule: 'rechargeWriteUser',
  key: byUserId,
  replacesDefault: true,
} as const;

/** Recharge agents «وكلاء الشحن» (contract v1.54-social draft, D185, CONVENTIONS §10.48), tag `recharge`. */
@Controller()
export class RechargeController {
  constructor(private readonly recharge: RechargeService) {}

  @Get('me/recharge-agent')
  me(@CurrentAuth() auth: AuthContext): Promise<RechargeAgentMeDto> {
    return this.recharge.me(auth.userId);
  }

  @Post('me/recharge-agent/application')
  @HttpCode(201)
  @RateLimit(WRITE)
  apply(@CurrentAuth() auth: AuthContext, @Body() body: unknown): Promise<RechargeAgentMeDto> {
    return this.recharge.apply(auth.userId, body);
  }

  @Put('me/recharge-agent/availability')
  @RateLimit(WRITE)
  availability(@CurrentAuth() auth: AuthContext, @Body() body: unknown): Promise<AvailabilityDto> {
    return this.recharge.setAvailability(auth.userId, body);
  }

  /** 201 sold now, 200 the same Idempotency-Key again. */
  @Post('me/recharge-agent/sales')
  @RateLimit({ bucket: 'recharge:sell', rule: 'rechargeSellUser', key: byUserId, replacesDefault: true })
  async sell(
    @CurrentAuth() auth: AuthContext,
    @Headers('idempotency-key') key: string | undefined,
    @Body() body: unknown,
    @Res({ passthrough: true }) res: Response,
  ): Promise<RechargeSaleDto> {
    const { created, result } = await this.recharge.sell(auth.userId, key, body);
    res.status(created ? 201 : 200);
    return result;
  }

  @Get('me/recharge-agent/sales')
  sales(
    @CurrentAuth() auth: AuthContext,
    @Query(new ZodValidationPipe(pageQuerySchema)) query: PageQuery,
  ): Promise<PageDto<RechargeSaleDto>> {
    return this.recharge.sales(auth.userId, query);
  }

  @Get('me/recharge-agent/employees')
  employees(@CurrentAuth() auth: AuthContext): Promise<{ data: RechargeEmployeeDto[] }> {
    return this.recharge.employees(auth.userId);
  }

  @Post('me/recharge-agent/employees')
  @HttpCode(201)
  @RateLimit(WRITE)
  addEmployee(@CurrentAuth() auth: AuthContext, @Body() body: unknown): Promise<RechargeEmployeeDto> {
    return this.recharge.addEmployee(auth.userId, body);
  }

  @Put('me/recharge-agent/employees/:username')
  @RateLimit(WRITE)
  updateEmployee(
    @CurrentAuth() auth: AuthContext,
    @Param('username') username: string,
    @Body() body: unknown,
  ): Promise<RechargeEmployeeDto> {
    return this.recharge.updateEmployee(auth.userId, username, body);
  }

  @Delete('me/recharge-agent/employees/:username')
  @HttpCode(204)
  @RateLimit(WRITE)
  async removeEmployee(@CurrentAuth() auth: AuthContext, @Param('username') username: string): Promise<void> {
    await this.recharge.removeEmployee(auth.userId, username);
  }

  @Get('recharge-agents')
  directory(
    @Query(new ZodValidationPipe(directoryQuerySchema)) query: z.output<typeof directoryQuerySchema>,
  ): Promise<PageDto<RechargeAgentListingDto>> {
    return this.recharge.directory(query.country, query);
  }

  @Get('recharge-agents/:code')
  byCode(@Param('code') code: string): Promise<RechargeAgentListingDto> {
    return this.recharge.byCode(code);
  }

  @Get('recharge-cherry-requests')
  cherryRequests(
    @CurrentAuth() auth: AuthContext,
    @Query(new ZodValidationPipe(pageQuerySchema)) query: PageQuery,
  ): Promise<PageDto<RechargeCherryRequestDto>> {
    return this.recharge.cherryRequests(auth.userId, query);
  }

  /** 201 requested now, 200 the same Idempotency-Key again. */
  @Post('recharge-cherry-requests')
  @RateLimit(WRITE)
  async createCherryRequest(
    @CurrentAuth() auth: AuthContext,
    @Headers('idempotency-key') key: string | undefined,
    @Body() body: unknown,
    @Res({ passthrough: true }) res: Response,
  ): Promise<RechargeCherryRequestDto> {
    const { created, result } = await this.recharge.createCherryRequest(auth.userId, key, body);
    res.status(created ? 201 : 200);
    return result;
  }

  @Post('recharge-cherry-requests/:requestId/:action')
  @HttpCode(200)
  @RateLimit(WRITE)
  answer(
    @CurrentAuth() auth: AuthContext,
    @Param('requestId') requestId: string,
    @Param('action') action: string,
  ): Promise<RechargeCherryRequestDto> {
    return this.recharge.answerCherryRequest(auth.userId, requestId, action);
  }
}
