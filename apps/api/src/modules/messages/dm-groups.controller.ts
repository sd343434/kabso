import { Body, Controller, Delete, Get, HttpCode, Param, Patch, Post, Put, Query, Res } from '@nestjs/common';
import type { Response } from 'express';
import type { AuthContext } from '../../common/http/request-context.js';
import { byUserId, RateLimit } from '../../common/rate-limit/rate-limit.decorator.js';
import { ZodValidationPipe } from '../../common/validation/zod-validation.pipe.js';
import { CurrentAuth } from '../auth/current-auth.decorator.js';
import type { UserSummaryDto } from '../live/live-rooms.service.js';
import type { PageDto } from '../posts/post-views.js';
import {
  DmGroupsService,
  type DmGroupDetailDto,
  type DmGroupMessagePageDto,
  type DmGroupSendResultDto,
} from './dm-groups.service.js';
import {
  dmDeleteMessageQuerySchema,
  dmGroupCandidatesQuerySchema,
  dmMessagesQuerySchema,
  type DmDeleteMessageQuery,
  type DmGroupCandidatesQuery,
  type DmMessagesQuery,
} from './dm.schemas.js';

/** D155 (§7): a group message counts in the direct-message send bucket, 30 / minute per user. */
const DM_SEND = { bucket: 'dm:send', rule: 'dmSendUser', key: byUserId, replacesDefault: true } as const;
/** D155 (§7): the other writes, 300 / hour per user. */
const DM_WRITE = { bucket: 'dm:write', rule: 'dmWriteUser', key: byUserId, replacesDefault: true } as const;
/** v1.103-social (D339, §7): new groups, 10 / day per user. */
const DM_GROUP_CREATE = {
  bucket: 'dm:group',
  rule: 'dmGroupCreateUser',
  key: byUserId,
  replacesDefault: true,
} as const;

/**
 * Group messages «رسائل جماعية» (contract v1.103-social draft, D339, CONVENTIONS §10.133). Every route needs a token;
 * reads use the per-user default rate limit.
 */
@Controller('dm')
export class DmGroupsController {
  constructor(private readonly groups: DmGroupsService) {}

  @Get('group-candidates')
  candidates(
    @CurrentAuth() auth: AuthContext,
    @Query(new ZodValidationPipe(dmGroupCandidatesQuerySchema)) query: DmGroupCandidatesQuery,
  ): Promise<PageDto<UserSummaryDto>> {
    return this.groups.candidates(auth.userId, query);
  }

  /** 201 new, 200 a retry with the same `clientId`. */
  @Post('groups')
  @RateLimit(DM_GROUP_CREATE)
  async create(
    @CurrentAuth() auth: AuthContext,
    @Body() body: unknown,
    @Res({ passthrough: true }) res: Response,
  ): Promise<DmGroupDetailDto> {
    const { created, result } = await this.groups.create(auth.userId, body);
    res.status(created ? 201 : 200);
    return result;
  }

  @Get('groups/:groupId')
  detail(@CurrentAuth() auth: AuthContext, @Param('groupId') groupId: string): Promise<DmGroupDetailDto> {
    return this.groups.detail(auth.userId, groupId);
  }

  @Patch('groups/:groupId')
  @RateLimit(DM_WRITE)
  update(
    @CurrentAuth() auth: AuthContext,
    @Param('groupId') groupId: string,
    @Body() body: unknown,
  ): Promise<DmGroupDetailDto> {
    return this.groups.update(auth.userId, groupId, body);
  }

  @Post('groups/:groupId/members')
  @HttpCode(200)
  @RateLimit(DM_WRITE)
  addMembers(
    @CurrentAuth() auth: AuthContext,
    @Param('groupId') groupId: string,
    @Body() body: unknown,
  ): Promise<DmGroupDetailDto> {
    return this.groups.addMembers(auth.userId, groupId, body);
  }

  @Delete('groups/:groupId/members/:username')
  @HttpCode(204)
  @RateLimit(DM_WRITE)
  removeMember(
    @CurrentAuth() auth: AuthContext,
    @Param('groupId') groupId: string,
    @Param('username') username: string,
  ): Promise<void> {
    return this.groups.removeMember(auth.userId, groupId, username);
  }

  @Put('groups/:groupId/members/:username/role')
  @HttpCode(204)
  @RateLimit(DM_WRITE)
  setRole(
    @CurrentAuth() auth: AuthContext,
    @Param('groupId') groupId: string,
    @Param('username') username: string,
    @Body() body: unknown,
  ): Promise<void> {
    return this.groups.setRole(auth.userId, groupId, username, body);
  }

  @Post('groups/:groupId/leave')
  @HttpCode(204)
  @RateLimit(DM_WRITE)
  leave(@CurrentAuth() auth: AuthContext, @Param('groupId') groupId: string): Promise<void> {
    return this.groups.leave(auth.userId, groupId);
  }

  @Get('groups/:groupId/messages')
  messages(
    @CurrentAuth() auth: AuthContext,
    @Param('groupId') groupId: string,
    @Query(new ZodValidationPipe(dmMessagesQuerySchema)) query: DmMessagesQuery,
  ): Promise<DmGroupMessagePageDto> {
    return this.groups.messages(auth.userId, groupId, query);
  }

  /** 201 new, 200 a retry with the same `clientId`. */
  @Post('groups/:groupId/messages')
  @RateLimit(DM_SEND)
  async send(
    @CurrentAuth() auth: AuthContext,
    @Param('groupId') groupId: string,
    @Body() body: unknown,
    @Res({ passthrough: true }) res: Response,
  ): Promise<DmGroupSendResultDto> {
    const { created, result } = await this.groups.send(auth.userId, groupId, body);
    res.status(created ? 201 : 200);
    return result;
  }

  @Post('groups/:groupId/read')
  @HttpCode(204)
  @RateLimit(DM_WRITE)
  read(
    @CurrentAuth() auth: AuthContext,
    @Param('groupId') groupId: string,
    @Body() body: unknown,
  ): Promise<void> {
    return this.groups.markRead(auth.userId, groupId, body);
  }

  @Delete('groups/:groupId/messages/:messageId')
  @HttpCode(204)
  @RateLimit(DM_WRITE)
  deleteMessage(
    @CurrentAuth() auth: AuthContext,
    @Param('groupId') groupId: string,
    @Param('messageId') messageId: string,
    @Query(new ZodValidationPipe(dmDeleteMessageQuerySchema)) query: DmDeleteMessageQuery,
  ): Promise<void> {
    return this.groups.deleteMessage(auth.userId, groupId, messageId, query);
  }

  @Put('groups/:groupId/mute')
  @HttpCode(204)
  @RateLimit(DM_WRITE)
  mute(@CurrentAuth() auth: AuthContext, @Param('groupId') groupId: string): Promise<void> {
    return this.groups.setMuted(auth.userId, groupId, true);
  }

  @Delete('groups/:groupId/mute')
  @HttpCode(204)
  @RateLimit(DM_WRITE)
  unmute(@CurrentAuth() auth: AuthContext, @Param('groupId') groupId: string): Promise<void> {
    return this.groups.setMuted(auth.userId, groupId, false);
  }

  @Put('groups/:groupId/archive')
  @HttpCode(204)
  @RateLimit(DM_WRITE)
  archive(@CurrentAuth() auth: AuthContext, @Param('groupId') groupId: string): Promise<void> {
    return this.groups.setArchived(auth.userId, groupId, true);
  }

  @Delete('groups/:groupId/archive')
  @HttpCode(204)
  @RateLimit(DM_WRITE)
  unarchive(@CurrentAuth() auth: AuthContext, @Param('groupId') groupId: string): Promise<void> {
    return this.groups.setArchived(auth.userId, groupId, false);
  }
}
