import { Body, Controller, Delete, Get, HttpCode, Param, Post, Query, Req, Res } from '@nestjs/common';
import type { Response } from 'express';
import { languageFromAcceptLanguage, type ContentLanguage } from '../../common/http/content-language.js';
import type { AppRequest, AuthContext } from '../../common/http/request-context.js';
import { byUserId, RateLimit } from '../../common/rate-limit/rate-limit.decorator.js';
import { ZodValidationPipe } from '../../common/validation/zod-validation.pipe.js';
import { CurrentAuth } from '../auth/current-auth.decorator.js';
import type { PageDto } from '../posts/post-views.js';
import { UsersService } from '../users/users.service.js';
import { CpConfessionsService, type CpConfessionDto } from './cp-confessions.service.js';
import {
  cpPageQuerySchema,
  cpRankingsQuerySchema,
  type CpPageQuery,
  type CpRankingsQuery,
} from './cp-space.schemas.js';
import {
  CpSpaceService,
  type CpCouplePublicDto,
  type CpGiftWallDto,
  type CpPrivilegesDto,
  type CpRankingsDto,
  type CpTaskClaimResultDto,
  type CpTasksDto,
} from './cp-space.service.js';

/** CP-021 (§7): check-in, task claims and confession deletes, 60 / min per user, replacing the default. */
const CP_SPACE_WRITE = {
  bucket: 'cp:space',
  rule: 'cpSpaceWriteUser',
  key: byUserId,
  replacesDefault: true,
} as const;
/** CP-021 (§7): new confessions, 10 / hour per user, replacing the default. */
const CP_CONFESSION = {
  bucket: 'cp:confession',
  rule: 'cpConfessionUser',
  key: byUserId,
  replacesDefault: true,
} as const;

/** The CP space (contract v1.24-live draft, CP-021, CONVENTIONS §10.24). */
@Controller('cp')
export class CpSpaceController {
  constructor(
    private readonly space: CpSpaceService,
    private readonly confessions: CpConfessionsService,
    private readonly users: UsersService,
  ) {}

  /** Names follow `Accept-Language`, else the caller's locale (like the CP tier names). */
  private async language(req: AppRequest, auth: AuthContext): Promise<ContentLanguage> {
    return (
      languageFromAcceptLanguage(req.headers['accept-language']) ?? (await this.users.getLocale(auth.userId))
    );
  }

  @Get('me/tasks')
  async tasks(@CurrentAuth() auth: AuthContext, @Req() req: AppRequest): Promise<CpTasksDto> {
    return this.space.tasks(auth.userId, await this.language(req, auth));
  }

  /** 201 checked in now, 200 already today. */
  @Post('me/check-in')
  @RateLimit(CP_SPACE_WRITE)
  async checkIn(
    @CurrentAuth() auth: AuthContext,
    @Req() req: AppRequest,
    @Res({ passthrough: true }) res: Response,
  ): Promise<CpTasksDto> {
    const { created, result } = await this.space.checkIn(auth.userId, await this.language(req, auth));
    res.status(created ? 201 : 200);
    return result;
  }

  /** 201 claimed now, 200 already claimed today. */
  @Post('me/tasks/:code/claim')
  @RateLimit(CP_SPACE_WRITE)
  async claim(
    @CurrentAuth() auth: AuthContext,
    @Req() req: AppRequest,
    @Param('code') code: string,
    @Res({ passthrough: true }) res: Response,
  ): Promise<CpTaskClaimResultDto> {
    const { created, result } = await this.space.claim(auth.userId, code, await this.language(req, auth));
    res.status(created ? 201 : 200);
    return result;
  }

  @Get('me/privileges')
  async privileges(@CurrentAuth() auth: AuthContext, @Req() req: AppRequest): Promise<CpPrivilegesDto> {
    return this.space.privileges(auth.userId, await this.language(req, auth));
  }

  @Get('me/confessions')
  myConfessions(
    @CurrentAuth() auth: AuthContext,
    @Query(new ZodValidationPipe(cpPageQuerySchema)) query: CpPageQuery,
  ): Promise<PageDto<CpConfessionDto>> {
    return this.confessions.listMine(auth.userId, query);
  }

  /** 201 new, 200 a retry with the same `clientId`. */
  @Post('me/confessions')
  @RateLimit(CP_CONFESSION)
  async confess(
    @CurrentAuth() auth: AuthContext,
    @Body() body: unknown,
    @Res({ passthrough: true }) res: Response,
  ): Promise<CpConfessionDto> {
    const { created, confession } = await this.confessions.create(auth.userId, body);
    res.status(created ? 201 : 200);
    return confession;
  }

  @Delete('me/confessions/:confessionId')
  @HttpCode(204)
  @RateLimit(CP_SPACE_WRITE)
  removeConfession(
    @CurrentAuth() auth: AuthContext,
    @Param('confessionId') confessionId: string,
  ): Promise<void> {
    return this.confessions.remove(auth.userId, confessionId);
  }

  @Get('rankings')
  async rankings(
    @CurrentAuth() auth: AuthContext,
    @Req() req: AppRequest,
    @Query(new ZodValidationPipe(cpRankingsQuerySchema)) query: CpRankingsQuery,
  ): Promise<CpRankingsDto> {
    return this.space.rankings(auth.userId, query, await this.language(req, auth));
  }

  @Get('couples/:coupleId')
  async couple(
    @CurrentAuth() auth: AuthContext,
    @Req() req: AppRequest,
    @Param('coupleId') coupleId: string,
  ): Promise<CpCouplePublicDto> {
    return this.space.couple(auth.userId, coupleId, await this.language(req, auth));
  }

  @Get('couples/:coupleId/gift-wall')
  giftWall(
    @CurrentAuth() auth: AuthContext,
    @Param('coupleId') coupleId: string,
    @Query(new ZodValidationPipe(cpPageQuerySchema)) query: CpPageQuery,
  ): Promise<CpGiftWallDto> {
    return this.space.giftWall(auth.userId, coupleId, query);
  }

  @Get('couples/:coupleId/confessions')
  coupleConfessions(
    @CurrentAuth() auth: AuthContext,
    @Param('coupleId') coupleId: string,
    @Query(new ZodValidationPipe(cpPageQuerySchema)) query: CpPageQuery,
  ): Promise<PageDto<CpConfessionDto>> {
    return this.confessions.listPublic(auth.userId, coupleId, query);
  }
}
