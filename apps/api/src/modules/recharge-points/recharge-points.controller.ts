import { Controller, Get, Query } from '@nestjs/common';
import type { AuthContext } from '../../common/http/request-context.js';
import { ZodValidationPipe } from '../../common/validation/zod-validation.pipe.js';
import { CurrentAuth } from '../auth/current-auth.decorator.js';
import { pageQuerySchema, type PageQuery } from '../posts/posts.schemas.js';
import { RechargePointsService, type RechargePointsDto } from './recharge-points.service.js';

/**
 * «نقاط الشحن» (contract v1.126-social draft, D370, CONVENTIONS §10.162): the caller's recharge points and their
 * history. Signed-in, per-user default rate limit.
 */
@Controller('me/recharge-points')
export class RechargePointsController {
  constructor(private readonly points: RechargePointsService) {}

  @Get()
  mine(
    @CurrentAuth() auth: AuthContext,
    @Query(new ZodValidationPipe(pageQuerySchema)) query: PageQuery,
  ): Promise<RechargePointsDto> {
    return this.points.mine(auth.userId, query);
  }
}
