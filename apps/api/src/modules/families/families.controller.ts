import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  Param,
  Patch,
  Post,
  Put,
  Query,
  Req,
  Res,
} from '@nestjs/common';
import type { Response } from 'express';
import { clientIp, type AppRequest, type AuthContext } from '../../common/http/request-context.js';
import { getRequestId } from '../../common/request-id/request-id.js';
import { byUserId, RateLimit } from '../../common/rate-limit/rate-limit.decorator.js';
import { ZodValidationPipe } from '../../common/validation/zod-validation.pipe.js';
import { CurrentAuth } from '../auth/current-auth.decorator.js';
import type { PageDto } from '../posts/post-views.js';
import { pageQuerySchema, type PageQuery } from '../posts/posts.schemas.js';
import {
  familyChatQuerySchema,
  familyMembersQuerySchema,
  familyRankingsQuerySchema,
  familySearchQuerySchema,
  type FamilyChatQuery,
  type FamilyMembersQuery,
  type FamilyRankingsQuery,
  type FamilySearchQuery,
} from './families.schemas.js';
import {
  FamiliesService,
  type CreateFamilyResultDto,
  type FamilyCardDto,
  type FamilyConfigDto,
  type FamilyContributionsDto,
  type FamilyDto,
  type FamilyJoinRequestDto,
  type FamilyMemberDto,
  type RequestMeta,
} from './families.service.js';
import {
  FamilyChatService,
  type FamilyChatMessageDto,
  type FamilyChatPageDto,
} from './family-chat.service.js';
import {
  FamilyRankingsService,
  type FamilyRankingsDto,
  type FamilyStandingDto,
} from './family-rankings.service.js';

/** CP-018 (§7): family writes, 60 / hour per user, replacing the default. */
const FAMILY_WRITE = {
  bucket: 'families:write',
  rule: 'familyWriteUser',
  key: byUserId,
  replacesDefault: true,
} as const;

/** v1.25-live (CP-022, §7): family chat messages, 30 / minute per user, replacing the default. */
const FAMILY_CHAT = {
  bucket: 'families:chat',
  rule: 'familyChatUser',
  key: byUserId,
  replacesDefault: true,
} as const;

function meta(req: AppRequest): RequestMeta {
  return { ip: clientIp(req), requestId: getRequestId(req) };
}

/**
 * Families (العائلة, contract v1.21-live draft, CP-018, CONVENTIONS §10.21). Every route needs a
 * token; reads use the per-user default rate limit.
 */
@Controller('families')
export class FamiliesController {
  constructor(
    private readonly families: FamiliesService,
    private readonly rankings: FamilyRankingsService,
    private readonly chat: FamilyChatService,
  ) {}

  @Get('config')
  config(): FamilyConfigDto {
    return this.families.configDto();
  }

  @Get()
  search(
    @Query(new ZodValidationPipe(familySearchQuerySchema)) query: FamilySearchQuery,
  ): Promise<PageDto<FamilyCardDto>> {
    return this.families.search(query);
  }

  /** 201 new, 200 a retry with the same `clientId`. */
  @Post()
  @RateLimit(FAMILY_WRITE)
  async create(
    @CurrentAuth() auth: AuthContext,
    @Req() req: AppRequest,
    @Body() body: unknown,
    @Res({ passthrough: true }) res: Response,
  ): Promise<CreateFamilyResultDto> {
    const { created, result } = await this.families.create(auth.userId, body, meta(req));
    res.status(created ? 201 : 200);
    return result;
  }

  /** v1.25-live (CP-022): the family boards (before `:familyId`). */
  @Get('rankings')
  board(
    @CurrentAuth() auth: AuthContext,
    @Query(new ZodValidationPipe(familyRankingsQuerySchema)) query: FamilyRankingsQuery,
  ): Promise<FamilyRankingsDto> {
    return this.rankings.list(auth.userId, query);
  }

  @Get('me')
  mine(@CurrentAuth() auth: AuthContext): Promise<{ family: FamilyDto | null }> {
    return this.families.mine(auth.userId);
  }

  @Get(':familyId')
  get(@CurrentAuth() auth: AuthContext, @Param('familyId') familyId: string): Promise<FamilyDto> {
    return this.families.get(auth.userId, familyId);
  }

  @Patch(':familyId')
  @RateLimit(FAMILY_WRITE)
  update(
    @CurrentAuth() auth: AuthContext,
    @Param('familyId') familyId: string,
    @Body() body: unknown,
  ): Promise<FamilyDto> {
    return this.families.update(auth.userId, familyId, body);
  }

  @Delete(':familyId')
  @HttpCode(204)
  @RateLimit(FAMILY_WRITE)
  disband(
    @CurrentAuth() auth: AuthContext,
    @Req() req: AppRequest,
    @Param('familyId') familyId: string,
  ): Promise<void> {
    return this.families.disband(auth.userId, familyId, meta(req));
  }

  @Get(':familyId/members')
  members(
    @CurrentAuth() auth: AuthContext,
    @Param('familyId') familyId: string,
    @Query(new ZodValidationPipe(familyMembersQuerySchema)) query: FamilyMembersQuery,
  ): Promise<PageDto<FamilyMemberDto>> {
    return this.families.members(auth.userId, familyId, query);
  }

  /** v1.25-live: who gave the most this month. */
  @Get(':familyId/contributions')
  contributions(
    @Param('familyId') familyId: string,
    @Query(new ZodValidationPipe(pageQuerySchema)) query: PageQuery,
  ): Promise<FamilyContributionsDto> {
    return this.families.contributions(familyId, query);
  }

  /** v1.25-live: the family's place on both boards. */
  @Get(':familyId/rankings')
  standing(@Param('familyId') familyId: string): Promise<FamilyStandingDto> {
    return this.rankings.standing(familyId);
  }

  /** v1.25-live: the family chat, newest first (members only). */
  @Get(':familyId/chat')
  chatPage(
    @CurrentAuth() auth: AuthContext,
    @Param('familyId') familyId: string,
    @Query(new ZodValidationPipe(familyChatQuerySchema)) query: FamilyChatQuery,
  ): Promise<FamilyChatPageDto> {
    return this.chat.list(auth.userId, familyId, query);
  }

  /** 201 new, 200 a retry with the same `clientId`. */
  @Post(':familyId/chat')
  @RateLimit(FAMILY_CHAT)
  async chatSend(
    @CurrentAuth() auth: AuthContext,
    @Param('familyId') familyId: string,
    @Body() body: unknown,
    @Res({ passthrough: true }) res: Response,
  ): Promise<FamilyChatMessageDto> {
    const { created, message } = await this.chat.send(auth.userId, familyId, body);
    res.status(created ? 201 : 200);
    return message;
  }

  @Delete(':familyId/chat/:messageId')
  @HttpCode(204)
  @RateLimit(FAMILY_WRITE)
  chatDelete(
    @CurrentAuth() auth: AuthContext,
    @Param('familyId') familyId: string,
    @Param('messageId') messageId: string,
  ): Promise<void> {
    return this.chat.remove(auth.userId, familyId, messageId);
  }

  @Put(':familyId/chat/mutes/:username')
  @HttpCode(204)
  @RateLimit(FAMILY_WRITE)
  chatMute(
    @CurrentAuth() auth: AuthContext,
    @Param('familyId') familyId: string,
    @Param('username') username: string,
  ): Promise<void> {
    return this.chat.setMuted(auth.userId, familyId, username, true);
  }

  @Delete(':familyId/chat/mutes/:username')
  @HttpCode(204)
  @RateLimit(FAMILY_WRITE)
  chatUnmute(
    @CurrentAuth() auth: AuthContext,
    @Param('familyId') familyId: string,
    @Param('username') username: string,
  ): Promise<void> {
    return this.chat.setMuted(auth.userId, familyId, username, false);
  }

  @Delete(':familyId/members/:username')
  @HttpCode(204)
  @RateLimit(FAMILY_WRITE)
  removeMember(
    @CurrentAuth() auth: AuthContext,
    @Req() req: AppRequest,
    @Param('familyId') familyId: string,
    @Param('username') username: string,
  ): Promise<void> {
    return this.families.removeMember(auth.userId, familyId, username, meta(req));
  }

  @Put(':familyId/members/:username/role')
  @RateLimit(FAMILY_WRITE)
  setRole(
    @CurrentAuth() auth: AuthContext,
    @Param('familyId') familyId: string,
    @Param('username') username: string,
    @Body() body: unknown,
  ): Promise<FamilyMemberDto> {
    return this.families.setRole(auth.userId, familyId, username, body);
  }

  @Post(':familyId/transfer')
  @HttpCode(200)
  @RateLimit(FAMILY_WRITE)
  transfer(
    @CurrentAuth() auth: AuthContext,
    @Req() req: AppRequest,
    @Param('familyId') familyId: string,
    @Body() body: unknown,
  ): Promise<FamilyDto> {
    return this.families.transfer(auth.userId, familyId, body, meta(req));
  }

  @Post(':familyId/leave')
  @HttpCode(204)
  @RateLimit(FAMILY_WRITE)
  leave(@CurrentAuth() auth: AuthContext, @Param('familyId') familyId: string): Promise<void> {
    return this.families.leave(auth.userId, familyId);
  }

  /** 201 new, 200 when the caller already asked this family. */
  @Post(':familyId/join-requests')
  @RateLimit(FAMILY_WRITE)
  async requestJoin(
    @CurrentAuth() auth: AuthContext,
    @Param('familyId') familyId: string,
    @Res({ passthrough: true }) res: Response,
  ): Promise<FamilyJoinRequestDto> {
    const { created, request } = await this.families.requestJoin(auth.userId, familyId);
    res.status(created ? 201 : 200);
    return request;
  }

  @Get(':familyId/join-requests')
  listRequests(
    @CurrentAuth() auth: AuthContext,
    @Param('familyId') familyId: string,
    @Query(new ZodValidationPipe(pageQuerySchema)) query: PageQuery,
  ): Promise<PageDto<FamilyJoinRequestDto>> {
    return this.families.listRequests(auth.userId, familyId, query);
  }

  @Post(':familyId/join-requests/:requestId/accept')
  @HttpCode(200)
  @RateLimit(FAMILY_WRITE)
  accept(
    @CurrentAuth() auth: AuthContext,
    @Param('familyId') familyId: string,
    @Param('requestId') requestId: string,
  ): Promise<FamilyMemberDto> {
    return this.families.accept(auth.userId, familyId, requestId);
  }

  @Post(':familyId/join-requests/:requestId/decline')
  @HttpCode(204)
  @RateLimit(FAMILY_WRITE)
  decline(
    @CurrentAuth() auth: AuthContext,
    @Param('familyId') familyId: string,
    @Param('requestId') requestId: string,
  ): Promise<void> {
    return this.families.decline(auth.userId, familyId, requestId);
  }
}

/** CP-018 routes outside `/families` (unambiguous paths, §10.21). */
@Controller()
export class FamilyLookupController {
  constructor(private readonly families: FamiliesService) {}

  @Get('me/family-join-request')
  myRequest(@CurrentAuth() auth: AuthContext): Promise<{ request: FamilyJoinRequestDto | null }> {
    return this.families.myRequest(auth.userId);
  }

  /** Idempotent: no pending request → 204 too. */
  @Delete('me/family-join-request')
  @HttpCode(204)
  @RateLimit(FAMILY_WRITE)
  cancelRequest(@CurrentAuth() auth: AuthContext): Promise<void> {
    return this.families.cancelMyRequest(auth.userId);
  }

  @Get('family-numbers/:number')
  byNumber(@CurrentAuth() auth: AuthContext, @Param('number') number: string): Promise<FamilyDto> {
    return this.families.getByNumber(auth.userId, number);
  }
}
