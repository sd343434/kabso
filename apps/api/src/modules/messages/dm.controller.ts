import { Body, Controller, Delete, Get, HttpCode, Param, Post, Put, Query, Req, Res } from '@nestjs/common';
import type { Response } from 'express';
import type { AppRequest, AuthContext } from '../../common/http/request-context.js';
import { byUserId, RateLimit } from '../../common/rate-limit/rate-limit.decorator.js';
import { ZodValidationPipe } from '../../common/validation/zod-validation.pipe.js';
import { CurrentAuth } from '../auth/current-auth.decorator.js';
import { LuckyGiftsService } from '../gifts/lucky-gifts.service.js';
import type { PageDto } from '../posts/post-views.js';
import {
  dmConversationsQuerySchema,
  dmDeleteMessageQuerySchema,
  dmMessagesQuerySchema,
  type DmConversationsQuery,
  type DmDeleteMessageQuery,
  type DmMessagesQuery,
} from './dm.schemas.js';
import {
  DmService,
  type DmConversationDto,
  type DmGiftResultDto,
  type DmMessagePageDto,
  type DmPeerDto,
  type DmSendResultDto,
  type DmUnreadDto,
} from './dm.service.js';

/** v1.40-social (D155, §7): direct message sends, 30 / minute per user, replacing the default. */
const DM_SEND = { bucket: 'dm:send', rule: 'dmSendUser', key: byUserId, replacesDefault: true } as const;
/** D155 (§7): the other writes (read, accept, delete, mute), 300 / hour per user. */
const DM_WRITE = { bucket: 'dm:write', rule: 'dmWriteUser', key: byUserId, replacesDefault: true } as const;

/**
 * Direct messages (contract v1.40-social draft, D155, CONVENTIONS §11.13). Every route needs a
 * token; reads use the per-user default rate limit.
 */
@Controller('dm')
export class DmController {
  constructor(
    private readonly dm: DmService,
    private readonly lucky: LuckyGiftsService,
  ) {}

  @Get('conversations')
  list(
    @CurrentAuth() auth: AuthContext,
    @Query(new ZodValidationPipe(dmConversationsQuerySchema)) query: DmConversationsQuery,
  ): Promise<PageDto<DmConversationDto>> {
    return this.dm.list(auth.userId, query);
  }

  @Get('unread')
  unread(@CurrentAuth() auth: AuthContext): Promise<DmUnreadDto> {
    return this.dm.unread(auth.userId);
  }

  @Get('peers/:username')
  peer(@CurrentAuth() auth: AuthContext, @Param('username') username: string): Promise<DmPeerDto> {
    return this.dm.peer(auth.userId, username);
  }

  @Get('conversations/:conversationId/messages')
  messages(
    @CurrentAuth() auth: AuthContext,
    @Param('conversationId') conversationId: string,
    @Query(new ZodValidationPipe(dmMessagesQuerySchema)) query: DmMessagesQuery,
  ): Promise<DmMessagePageDto> {
    return this.dm.messages(auth.userId, conversationId, query);
  }

  /** 201 new, 200 a retry with the same `clientId`. */
  @Post('messages')
  @RateLimit(DM_SEND)
  async send(
    @CurrentAuth() auth: AuthContext,
    @Body() body: unknown,
    @Res({ passthrough: true }) res: Response,
  ): Promise<DmSendResultDto> {
    const { created, result } = await this.dm.send(auth.userId, body);
    res.status(created ? 201 : 200);
    return result;
  }

  /**
   * A gift in a conversation: every send 6000 / min here (the live gift route's bucket); the normal
   * or lucky bucket in the pipeline (§7).
   */
  @Post('gifts')
  @RateLimit({ bucket: 'live:gift:any', rule: 'liveGiftAnyUser', key: byUserId, replacesDefault: true })
  async sendGift(
    @CurrentAuth() auth: AuthContext,
    @Req() req: AppRequest,
    @Body() body: unknown,
    @Res({ passthrough: true }) res: Response,
  ): Promise<DmGiftResultDto> {
    const { created, result } = await this.dm.sendGift(auth.userId, body, this.lucky.regionOf(req.headers));
    res.status(created ? 201 : 200);
    return result;
  }

  @Post('conversations/:conversationId/read')
  @HttpCode(204)
  @RateLimit(DM_WRITE)
  read(
    @CurrentAuth() auth: AuthContext,
    @Param('conversationId') conversationId: string,
    @Body() body: unknown,
  ): Promise<void> {
    return this.dm.markRead(auth.userId, conversationId, body);
  }

  @Post('conversations/:conversationId/accept')
  @HttpCode(204)
  @RateLimit(DM_WRITE)
  accept(@CurrentAuth() auth: AuthContext, @Param('conversationId') conversationId: string): Promise<void> {
    return this.dm.accept(auth.userId, conversationId);
  }

  @Delete('conversations/:conversationId')
  @HttpCode(204)
  @RateLimit(DM_WRITE)
  deleteConversation(
    @CurrentAuth() auth: AuthContext,
    @Param('conversationId') conversationId: string,
  ): Promise<void> {
    return this.dm.deleteConversation(auth.userId, conversationId);
  }

  @Put('conversations/:conversationId/mute')
  @HttpCode(204)
  @RateLimit(DM_WRITE)
  mute(@CurrentAuth() auth: AuthContext, @Param('conversationId') conversationId: string): Promise<void> {
    return this.dm.setMuted(auth.userId, conversationId, true);
  }

  @Delete('conversations/:conversationId/mute')
  @HttpCode(204)
  @RateLimit(DM_WRITE)
  unmute(@CurrentAuth() auth: AuthContext, @Param('conversationId') conversationId: string): Promise<void> {
    return this.dm.setMuted(auth.userId, conversationId, false);
  }

  @Delete('messages/:messageId')
  @HttpCode(204)
  @RateLimit(DM_WRITE)
  deleteMessage(
    @CurrentAuth() auth: AuthContext,
    @Param('messageId') messageId: string,
    @Query(new ZodValidationPipe(dmDeleteMessageQuerySchema)) query: DmDeleteMessageQuery,
  ): Promise<void> {
    return this.dm.deleteMessage(auth.userId, messageId, query);
  }
}
