import { Controller, Get, Param, Query, Req } from '@nestjs/common';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { languageFromAcceptLanguage, type ContentLanguage } from '../../common/http/content-language.js';
import type { AppRequest, AuthContext } from '../../common/http/request-context.js';
import { ZodValidationPipe } from '../../common/validation/zod-validation.pipe.js';
import type { LevelCategoryCode } from '../../generated/prisma/client.js';
import { CurrentAuth } from '../auth/current-auth.decorator.js';
import { UsersService } from '../users/users.service.js';
import type {
  LevelDetailDto,
  LevelSummaryDto,
  LevelTransitionDto,
  PageDto,
  PointsEntryDto,
} from './levels.dto.js';
import { categoryFromSlug } from './levels.constants.js';
import { LevelsQueryService, type PublicLevelDto } from './levels-query.service.js';
import { myLevelsListQuerySchema, type MyLevelsListQuery } from './levels.schemas.js';

/** A path category that is not one of the four (lower case) is 404. */
export function categoryParam(slug: string): LevelCategoryCode {
  const code = categoryFromSlug(slug);
  if (!code) throw new AppException(ErrorCode.NOT_FOUND);
  return code;
}

/**
 * The caller's levels (openapi v1.4-levels DRAFT, CP-005 §7). Read-only: points and levels change
 * only through server-side events and audited admin actions.
 */
@Controller('levels')
export class LevelsController {
  constructor(
    private readonly levels: LevelsQueryService,
    private readonly users: UsersService,
  ) {}

  private async language(req: AppRequest, auth: AuthContext): Promise<ContentLanguage> {
    return (
      languageFromAcceptLanguage(req.headers['accept-language']) ?? (await this.users.getLocale(auth.userId))
    );
  }

  @Get('me')
  async mine(@CurrentAuth() auth: AuthContext, @Req() req: AppRequest): Promise<{ data: LevelSummaryDto[] }> {
    return { data: await this.levels.mySummaries(auth.userId, await this.language(req, auth)) };
  }

  @Get('me/history')
  history(
    @CurrentAuth() auth: AuthContext,
    @Query(new ZodValidationPipe(myLevelsListQuerySchema)) query: MyLevelsListQuery,
  ): Promise<PageDto<LevelTransitionDto>> {
    return this.levels.myHistory(
      auth.userId,
      query.category ? categoryParam(query.category) : undefined,
      query,
    );
  }

  @Get('me/points-history')
  points(
    @CurrentAuth() auth: AuthContext,
    @Query(new ZodValidationPipe(myLevelsListQuerySchema)) query: MyLevelsListQuery,
  ): Promise<PageDto<PointsEntryDto>> {
    return this.levels.myPoints(
      auth.userId,
      query.category ? categoryParam(query.category) : undefined,
      query,
    );
  }

  @Get('me/:category')
  async one(
    @CurrentAuth() auth: AuthContext,
    @Req() req: AppRequest,
    @Param('category') slug: string,
  ): Promise<LevelDetailDto> {
    const code = categoryParam(slug);
    return this.levels.myDetail(auth.userId, code, await this.language(req, auth));
  }
}

/**
 * `GET /users/{username}/levels` (CP-005 §9.1, 7): the levels on someone's profile. The same 404
 * as `GET /users/{username}` for an unknown, malformed, suspended or deleted username.
 */
@Controller('users')
export class UserLevelsController {
  constructor(
    private readonly levels: LevelsQueryService,
    private readonly users: UsersService,
  ) {}

  @Get(':username/levels')
  async levelsOf(
    @CurrentAuth() auth: AuthContext,
    @Req() req: AppRequest,
    @Param('username') username: string,
  ): Promise<{ data: PublicLevelDto[] }> {
    const user = await this.users.findActivePublicUser(username);
    if (!user) throw new AppException(ErrorCode.NOT_FOUND);
    const lang =
      languageFromAcceptLanguage(req.headers['accept-language']) ?? (await this.users.getLocale(auth.userId));
    return { data: await this.levels.publicLevels(user.id, lang) };
  }
}
