import { Body, Controller, Get, HttpCode, Patch, Post, Query } from '@nestjs/common';
import type { AuthContext } from '../../common/http/request-context.js';
import { byUserId, RateLimit } from '../../common/rate-limit/rate-limit.decorator.js';
import { ZodValidationPipe } from '../../common/validation/zod-validation.pipe.js';
import { CurrentAuth } from '../auth/current-auth.decorator.js';
import type { PageDto } from '../posts/post-views.js';
import { pageQuerySchema, type PageQuery } from '../posts/posts.schemas.js';
import {
  NotificationsService,
  type NotificationDto,
  type NotificationSettingsDto,
} from './notifications.service.js';

/** In-app notifications (contract v1.5-social draft, CP-009, CONVENTIONS §11.10). Every route needs a token. */
@Controller()
export class NotificationsController {
  constructor(private readonly notifications: NotificationsService) {}

  @Get('notifications')
  @RateLimit({ bucket: 'notifications:read', rule: 'feedUser', key: byUserId, replacesDefault: true })
  list(
    @CurrentAuth() auth: AuthContext,
    @Query(new ZodValidationPipe(pageQuerySchema)) query: PageQuery,
  ): Promise<PageDto<NotificationDto>> {
    return this.notifications.list(auth.userId, query);
  }

  @Get('notifications/unread-count')
  @RateLimit({ bucket: 'notifications:read', rule: 'feedUser', key: byUserId, replacesDefault: true })
  unreadCount(@CurrentAuth() auth: AuthContext): Promise<{ count: number }> {
    return this.notifications.unreadCount(auth.userId);
  }

  @Post('notifications/read')
  @HttpCode(204)
  @RateLimit({
    bucket: 'notifications:mark',
    rule: 'notificationsReadUser',
    key: byUserId,
    replacesDefault: true,
  })
  async markRead(@CurrentAuth() auth: AuthContext, @Body() body: unknown): Promise<void> {
    await this.notifications.markRead(auth.userId, body);
  }

  @Get('me/notification-settings')
  settings(@CurrentAuth() auth: AuthContext): Promise<NotificationSettingsDto> {
    return this.notifications.settings(auth.userId);
  }

  @Patch('me/notification-settings')
  updateSettings(@CurrentAuth() auth: AuthContext, @Body() body: unknown): Promise<NotificationSettingsDto> {
    return this.notifications.updateSettings(auth.userId, body);
  }
}
