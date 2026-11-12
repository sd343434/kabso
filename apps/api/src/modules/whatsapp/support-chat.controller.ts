import { Body, Controller, Get, HttpCode, Post, Query, Res } from '@nestjs/common';
import type { Response } from 'express';
import type { AuthContext } from '../../common/http/request-context.js';
import { byUserId, RateLimit } from '../../common/rate-limit/rate-limit.decorator.js';
import { ZodValidationPipe } from '../../common/validation/zod-validation.pipe.js';
import { CurrentAuth } from '../auth/current-auth.decorator.js';
import {
  SupportChatService,
  supportMessagesQuery,
  type SupportMessageDto,
  type SupportMessagesQuery,
  type SupportThreadDto,
} from './support-chat.service.js';

/** v1.137-social (D385, §7): messages to «دعم كابسو», 10 / minute per user, replacing the default. */
const SUPPORT_SEND = {
  bucket: 'support:send',
  rule: 'supportSendUser',
  key: byUserId,
  replacesDefault: true,
} as const;
/** The read mark counts in the direct messages' other writes (300 / hour per user). */
const DM_WRITE = { bucket: 'dm:write', rule: 'dmWriteUser', key: byUserId, replacesDefault: true } as const;

/**
 * v1.137-social (D385, CONVENTIONS §10.174): «دعم كابسو» — the caller's in-app support thread (every route needs a
 * token; reads use the per-user default rate limit).
 */
@Controller('support/thread')
export class SupportChatController {
  constructor(private readonly support: SupportChatService) {}

  @Get()
  thread(@CurrentAuth() auth: AuthContext): Promise<SupportThreadDto> {
    return this.support.thread(auth.userId);
  }

  @Get('messages')
  messages(
    @CurrentAuth() auth: AuthContext,
    @Query(new ZodValidationPipe(supportMessagesQuery)) query: SupportMessagesQuery,
  ) {
    return this.support.messages(auth.userId, query);
  }

  /** 201 new, 200 a retry with the same `clientId`. */
  @Post('messages')
  @RateLimit(SUPPORT_SEND)
  async send(
    @CurrentAuth() auth: AuthContext,
    @Body() body: unknown,
    @Res({ passthrough: true }) res: Response,
  ): Promise<{ message: SupportMessageDto; thread: SupportThreadDto }> {
    const { created, result } = await this.support.send(auth.userId, body);
    res.status(created ? 201 : 200);
    return result;
  }

  @Post('read')
  @HttpCode(204)
  @RateLimit(DM_WRITE)
  read(@CurrentAuth() auth: AuthContext): Promise<void> {
    return this.support.read(auth.userId);
  }
}
