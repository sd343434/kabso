import { Body, Controller, Delete, HttpCode, Put } from '@nestjs/common';
import type { AuthContext } from '../../common/http/request-context.js';
import { CurrentAuth } from '../auth/current-auth.decorator.js';
import { PushTokensService } from './push-tokens.service.js';

/** The device's push token (contract v1.30-live draft, D152, CONVENTIONS §11.12). Token required. */
@Controller('me/push-token')
export class PushController {
  constructor(private readonly tokens: PushTokensService) {}

  @Put()
  @HttpCode(204)
  async register(@CurrentAuth() auth: AuthContext, @Body() body: unknown): Promise<void> {
    await this.tokens.register(auth.userId, auth.sessionId, body);
  }

  @Delete()
  @HttpCode(204)
  async unregister(@CurrentAuth() auth: AuthContext): Promise<void> {
    await this.tokens.unregister(auth.sessionId);
  }
}
