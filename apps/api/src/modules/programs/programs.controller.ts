import { Controller, Get, Param, Post, Query, Req, Res } from '@nestjs/common';
import type { Response } from 'express';
import { languageFromAcceptLanguage, type ContentLanguage } from '../../common/http/content-language.js';
import type { AppRequest, AuthContext } from '../../common/http/request-context.js';
import { CurrentAuth } from '../auth/current-auth.decorator.js';
import { UsersService } from '../users/users.service.js';
import {
  EventsService,
  type EventDetailDto,
  type EventLeaderboardDto,
  type EventListDto,
} from './events.service.js';
import { SvipService, type SvipStatusDto } from './svip.service.js';
import {
  TasksService,
  type CheckInResultDto,
  type MyTasksDto,
  type TaskClaimResultDto,
} from './tasks.service.js';

/**
 * The Me hub's programs (contract v1.44-social draft, D166, CONVENTIONS §10.41): the Task Center, the
 * Event Center and SVIP. Every route needs a signed-in caller and uses the per-user default rate limit;
 * names follow `Accept-Language`, else the caller's locale.
 */
@Controller()
export class ProgramsController {
  constructor(
    private readonly tasks: TasksService,
    private readonly events: EventsService,
    private readonly svip: SvipService,
    private readonly users: UsersService,
  ) {}

  private async language(req: AppRequest, auth: AuthContext): Promise<ContentLanguage> {
    return (
      languageFromAcceptLanguage(req.headers['accept-language']) ?? (await this.users.getLocale(auth.userId))
    );
  }

  @Get('me/tasks')
  async myTasks(@CurrentAuth() auth: AuthContext, @Req() req: AppRequest): Promise<MyTasksDto> {
    return this.tasks.mine(auth.userId, await this.language(req, auth));
  }

  /** 201 checked in now, 200 already today. */
  @Post('me/check-in')
  async checkIn(
    @CurrentAuth() auth: AuthContext,
    @Req() req: AppRequest,
    @Res({ passthrough: true }) res: Response,
  ): Promise<CheckInResultDto> {
    const { created, result } = await this.tasks.checkIn(auth.userId, await this.language(req, auth));
    res.status(created ? 201 : 200);
    return result;
  }

  /** 201 claimed now, 200 already claimed in this period. */
  @Post('me/tasks/:code/claim')
  async claim(
    @CurrentAuth() auth: AuthContext,
    @Req() req: AppRequest,
    @Param('code') code: string,
    @Res({ passthrough: true }) res: Response,
  ): Promise<TaskClaimResultDto> {
    const { created, result } = await this.tasks.claim(auth.userId, code, await this.language(req, auth));
    res.status(created ? 201 : 200);
    return result;
  }

  @Get('me/svip')
  async mySvip(@CurrentAuth() auth: AuthContext, @Req() req: AppRequest): Promise<SvipStatusDto> {
    return this.svip.mine(auth.userId, await this.language(req, auth));
  }

  @Get('events')
  async listEvents(
    @CurrentAuth() auth: AuthContext,
    @Req() req: AppRequest,
    @Query() query: unknown,
  ): Promise<EventListDto> {
    return this.events.list(auth.userId, query, await this.language(req, auth));
  }

  @Get('events/:eventId')
  async event(
    @CurrentAuth() auth: AuthContext,
    @Req() req: AppRequest,
    @Param('eventId') eventId: string,
  ): Promise<EventDetailDto> {
    return this.events.detail(eventId, await this.language(req, auth));
  }

  @Get('events/:eventId/leaderboard')
  leaderboard(
    @CurrentAuth() auth: AuthContext,
    @Param('eventId') eventId: string,
  ): Promise<EventLeaderboardDto> {
    return this.events.leaderboard(auth.userId, eventId);
  }
}
