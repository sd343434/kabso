import { Body, Controller, Delete, Get, HttpCode, Post, Req } from '@nestjs/common';
import { clientIp, type AppRequest, type AuthContext } from '../../common/http/request-context.js';
import { byUserId, RateLimit } from '../../common/rate-limit/rate-limit.decorator.js';
import { getRequestId } from '../../common/request-id/request-id.js';
import { CurrentAuth } from '../auth/current-auth.decorator.js';
import { CategoryVerificationService, type CategoryVerificationStatusDto } from './category-verification.js';

/** v1.138-social (D386, §7): «طلب توثيق الفئة», 5 a day per user, replacing the default. */
const CATEGORY_REQUEST = {
  bucket: 'category:request',
  rule: 'categoryRequestUser',
  key: byUserId,
  replacesDefault: true,
} as const;

/**
 * v1.138-social (D386, CONVENTIONS §10.175.4): `/me/category-verification` — the caller's category verification and
 * their «طلب توثيق الفئة» (every route needs a token; the reads and the cancel use the per-user default).
 */
@Controller('me/category-verification')
export class CategoryVerificationController {
  constructor(private readonly verification: CategoryVerificationService) {}

  @Get()
  status(@CurrentAuth() auth: AuthContext): Promise<CategoryVerificationStatusDto> {
    return this.verification.status(auth.userId);
  }

  @Post()
  @HttpCode(201)
  @RateLimit(CATEGORY_REQUEST)
  request(
    @CurrentAuth() auth: AuthContext,
    @Body() body: unknown,
    @Req() req: AppRequest,
  ): Promise<CategoryVerificationStatusDto> {
    return this.verification.request(auth.userId, body, { ip: clientIp(req), requestId: getRequestId(req) });
  }

  @Delete()
  @HttpCode(200)
  cancel(@CurrentAuth() auth: AuthContext, @Req() req: AppRequest): Promise<CategoryVerificationStatusDto> {
    return this.verification.cancel(auth.userId, { ip: clientIp(req), requestId: getRequestId(req) });
  }
}
