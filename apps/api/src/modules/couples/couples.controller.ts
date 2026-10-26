import { Body, Controller, Delete, Get, HttpCode, Param, Post, Query, Req, Res } from '@nestjs/common';
import type { Response } from 'express';
import { languageFromAcceptLanguage, type ContentLanguage } from '../../common/http/content-language.js';
import type { AppRequest, AuthContext } from '../../common/http/request-context.js';
import { byUserId, RateLimit } from '../../common/rate-limit/rate-limit.decorator.js';
import { ZodValidationPipe } from '../../common/validation/zod-validation.pipe.js';
import { CurrentAuth } from '../auth/current-auth.decorator.js';
import type { PageDto } from '../posts/post-views.js';
import { UsersService } from '../users/users.service.js';
import { cpRequestListQuerySchema, type CpRequestListQuery } from './couples.schemas.js';
import {
  CouplesService,
  type CpConfigDto,
  type CpCoupleDto,
  type CpGiftResultDto,
  type CpRequestDto,
  type CpRequestResultDto,
} from './couples.service.js';

/** CP-018 (§7): CP requests, answers and ending, 30 / hour per user, replacing the default. */
const CP_WRITE = { bucket: 'cp:write', rule: 'cpWriteUser', key: byUserId, replacesDefault: true } as const;
/** CP-018 (§7): CP gifts, 30 / min per user, replacing the default. */
const CP_GIFT = { bucket: 'cp:gift', rule: 'cpGiftUser', key: byUserId, replacesDefault: true } as const;

/** CP couples (العلاقة, contract v1.21-live draft, CP-018, CONVENTIONS §10.21). */
@Controller('cp')
export class CouplesController {
  constructor(
    private readonly couples: CouplesService,
    private readonly users: UsersService,
  ) {}

  /** Tier names follow `Accept-Language`, else the caller's locale (like level names). */
  private async language(req: AppRequest, auth: AuthContext): Promise<ContentLanguage> {
    return (
      languageFromAcceptLanguage(req.headers['accept-language']) ?? (await this.users.getLocale(auth.userId))
    );
  }

  @Get('config')
  async config(@CurrentAuth() auth: AuthContext, @Req() req: AppRequest): Promise<CpConfigDto> {
    return this.couples.configDto(await this.language(req, auth));
  }

  /** 201 new, 200 a retry with the same `clientId`. */
  @Post('requests')
  @RateLimit(CP_WRITE)
  async send(
    @CurrentAuth() auth: AuthContext,
    @Body() body: unknown,
    @Res({ passthrough: true }) res: Response,
  ): Promise<CpRequestResultDto> {
    const { created, result } = await this.couples.send(auth.userId, body);
    res.status(created ? 201 : 200);
    return result;
  }

  @Get('requests')
  list(
    @CurrentAuth() auth: AuthContext,
    @Query(new ZodValidationPipe(cpRequestListQuerySchema)) query: CpRequestListQuery,
  ): Promise<PageDto<CpRequestDto>> {
    return this.couples.list(auth.userId, query);
  }

  @Delete('requests/:requestId')
  @HttpCode(204)
  @RateLimit(CP_WRITE)
  cancel(@CurrentAuth() auth: AuthContext, @Param('requestId') requestId: string): Promise<void> {
    return this.couples.cancel(auth.userId, requestId);
  }

  @Post('requests/:requestId/accept')
  @HttpCode(200)
  @RateLimit(CP_WRITE)
  async accept(
    @CurrentAuth() auth: AuthContext,
    @Req() req: AppRequest,
    @Param('requestId') requestId: string,
  ): Promise<CpCoupleDto> {
    return this.couples.accept(auth.userId, requestId, await this.language(req, auth));
  }

  @Post('requests/:requestId/decline')
  @HttpCode(204)
  @RateLimit(CP_WRITE)
  decline(@CurrentAuth() auth: AuthContext, @Param('requestId') requestId: string): Promise<void> {
    return this.couples.decline(auth.userId, requestId);
  }

  @Get('me')
  async mine(@CurrentAuth() auth: AuthContext, @Req() req: AppRequest): Promise<{ cp: CpCoupleDto | null }> {
    return this.couples.mine(auth.userId, await this.language(req, auth));
  }

  @Delete('me')
  @HttpCode(204)
  @RateLimit(CP_WRITE)
  end(@CurrentAuth() auth: AuthContext): Promise<void> {
    return this.couples.end(auth.userId);
  }

  /** 201 new, 200 a retry with the same `clientId`. */
  @Post('me/gifts')
  @RateLimit(CP_GIFT)
  async gift(
    @CurrentAuth() auth: AuthContext,
    @Req() req: AppRequest,
    @Body() body: unknown,
    @Res({ passthrough: true }) res: Response,
  ): Promise<CpGiftResultDto> {
    const { created, result } = await this.couples.gift(auth.userId, body, await this.language(req, auth));
    res.status(created ? 201 : 200);
    return result;
  }
}
