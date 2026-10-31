import { Body, Controller, Get, HttpCode, Post, Req } from '@nestjs/common';
import type { AppRequest, AuthContext } from '../../common/http/request-context.js';
import { byUserId, RateLimit } from '../../common/rate-limit/rate-limit.decorator.js';
import { ZodValidationPipe } from '../../common/validation/zod-validation.pipe.js';
import {
  accountDeletionSchema,
  AccountDeletionService,
  type AccountDeletionInfoDto,
  type AccountDeletionInput,
  type AccountDeletionRequestDto,
} from './account-deletion.service.js';
import { requestMeta } from './auth.controller.js';
import { CurrentAuth } from './current-auth.decorator.js';
import { ConsentExempt } from '../privacy/consent-exempt.decorator.js';

/** D193 (§7): the request re-checks the password — 5 / 15 min per user, replacing the default. */
const REQUEST_LIMIT = {
  bucket: 'account_deletion:user',
  rule: 'accountDeletionUser',
  key: byUserId,
  replacesDefault: true,
} as const;

/** Account deletion «حذف الحساب» (contract v1.62-social draft, D193, CONVENTIONS §10.56). */
@Controller('me/account-deletion')
@ConsentExempt()
export class AccountDeletionController {
  constructor(private readonly deletion: AccountDeletionService) {}

  /** What the explanation screen needs: the grace period, what must be settled first, the support address. */
  @Get()
  info(@CurrentAuth() auth: AuthContext): Promise<AccountDeletionInfoDto> {
    return this.deletion.info(auth.userId);
  }

  /** Re-authenticated request: the account is hidden and signed out everywhere until purged or cancelled. */
  @Post()
  @HttpCode(202)
  @RateLimit(REQUEST_LIMIT)
  request(
    @CurrentAuth() auth: AuthContext,
    @Body(new ZodValidationPipe(accountDeletionSchema)) body: AccountDeletionInput,
    @Req() req: AppRequest,
  ): Promise<AccountDeletionRequestDto> {
    return this.deletion.request(auth.userId, body, requestMeta(req));
  }
}
