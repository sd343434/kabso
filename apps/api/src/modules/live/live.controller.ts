import { Body, Controller, Get, HttpCode, Param, Post, Put, Query, Req } from '@nestjs/common';
import { languageFromAcceptLanguage, type ContentLanguage } from '../../common/http/content-language.js';
import { clientIp, type AppRequest, type AuthContext } from '../../common/http/request-context.js';
import { byUserId, RateLimit } from '../../common/rate-limit/rate-limit.decorator.js';
import { getRequestId } from '../../common/request-id/request-id.js';
import { ZodValidationPipe } from '../../common/validation/zod-validation.pipe.js';
import { CurrentAuth } from '../auth/current-auth.decorator.js';
import { UsersService } from '../users/users.service.js';
import { LiveCategoriesService, type LiveCategoryDto } from './live-categories.service.js';
import {
  LiveRoomsService,
  type LiveConfigDto,
  type LiveCountryDto,
  type LiveRoomDto,
  type LiveRoomPageDto,
  type RequestMeta,
} from './live-rooms.service.js';
import { listLiveRoomsQuerySchema, type ListLiveRoomsQuery } from './live.schemas.js';

/**
 * Live discovery and host lifecycle (contract v1.3, CONVENTIONS §10); covers and countries
 * (v1.4, §11.4, §11.9). Every route needs a token.
 */
@Controller('live')
export class LiveController {
  constructor(
    private readonly rooms: LiveRoomsService,
    private readonly categories: LiveCategoriesService,
    private readonly users: UsersService,
  ) {}

  /** §10.1: `Accept-Language` (ar|en), else the caller's stored locale, else `ar`. */
  private async language(req: AppRequest, auth: AuthContext): Promise<ContentLanguage> {
    return (
      languageFromAcceptLanguage(req.headers['accept-language']) ?? (await this.users.getLocale(auth.userId))
    );
  }

  private meta(req: AppRequest): RequestMeta {
    return { ip: clientIp(req), requestId: getRequestId(req) };
  }

  @Get('config')
  config(): LiveConfigDto {
    return this.rooms.getConfig();
  }

  @Get('categories')
  async listCategories(
    @CurrentAuth() auth: AuthContext,
    @Req() req: AppRequest,
  ): Promise<{ data: LiveCategoryDto[] }> {
    return { data: await this.categories.listActive(await this.language(req, auth)) };
  }

  @Get('rooms')
  @RateLimit({ bucket: 'live:list', rule: 'liveListUser', key: byUserId, replacesDefault: true })
  async listRooms(
    @CurrentAuth() auth: AuthContext,
    @Req() req: AppRequest,
    @Query(new ZodValidationPipe(listLiveRoomsQuerySchema)) query: ListLiveRoomsQuery,
  ): Promise<LiveRoomPageDto> {
    return this.rooms.listRooms(auth.userId, query, await this.language(req, auth));
  }

  /**
   * Go live. The body is validated by the service AFTER the LIVE_HOSTING_ENABLED check (openapi
   * check order), so no validation pipe here. The hour and day buckets are counted first (guard).
   */
  @Post('rooms')
  @HttpCode(201)
  @RateLimit(
    { bucket: 'live:start:h', rule: 'liveStartHourUser', key: byUserId, replacesDefault: true },
    { bucket: 'live:start:d', rule: 'liveStartDayUser', key: byUserId, replacesDefault: true },
  )
  async startRoom(
    @CurrentAuth() auth: AuthContext,
    @Req() req: AppRequest,
    @Body() body: unknown,
  ): Promise<LiveRoomDto> {
    return this.rooms.startRoom(auth.userId, body, await this.language(req, auth), this.meta(req));
  }

  @Get('rooms/:roomId')
  async getRoom(
    @CurrentAuth() auth: AuthContext,
    @Req() req: AppRequest,
    @Param('roomId') roomId: string,
  ): Promise<LiveRoomDto> {
    return this.rooms.getRoom(roomId, await this.language(req, auth), auth.userId);
  }

  @Post('rooms/:roomId/heartbeat')
  @HttpCode(204)
  @RateLimit({ bucket: 'live:heartbeat', rule: 'liveHeartbeatUser', key: byUserId, replacesDefault: true })
  async heartbeat(@CurrentAuth() auth: AuthContext, @Param('roomId') roomId: string): Promise<void> {
    await this.rooms.heartbeat(auth.userId, roomId);
  }

  /**
   * v1.4: replace or remove the cover of the caller's LIVE room. The body is validated by the
   * service after the LIVE_HOSTING_ENABLED check (openapi check order).
   */
  @Put('rooms/:roomId/cover')
  @HttpCode(200)
  @RateLimit({ bucket: 'live:cover', rule: 'liveCoverUser', key: byUserId, replacesDefault: true })
  async setCover(
    @CurrentAuth() auth: AuthContext,
    @Req() req: AppRequest,
    @Param('roomId') roomId: string,
    @Body() body: unknown,
  ): Promise<LiveRoomDto> {
    return this.rooms.setCover(auth.userId, roomId, body, await this.language(req, auth), this.meta(req));
  }

  /** v1.4: countries with live rooms right now, with real counts (bounded, unpaginated). */
  @Get('countries')
  @RateLimit({ bucket: 'live:countries', rule: 'liveCountriesUser', key: byUserId, replacesDefault: true })
  async listCountries(
    @CurrentAuth() auth: AuthContext,
    @Req() req: AppRequest,
  ): Promise<{ data: LiveCountryDto[] }> {
    return { data: await this.rooms.listCountries(await this.language(req, auth)) };
  }

  @Post('rooms/:roomId/end')
  @HttpCode(200)
  @RateLimit({ bucket: 'live:end', rule: 'liveEndUser', key: byUserId, replacesDefault: true })
  async endRoom(
    @CurrentAuth() auth: AuthContext,
    @Req() req: AppRequest,
    @Param('roomId') roomId: string,
  ): Promise<LiveRoomDto> {
    return this.rooms.endRoom(auth.userId, roomId, await this.language(req, auth), this.meta(req));
  }
}
