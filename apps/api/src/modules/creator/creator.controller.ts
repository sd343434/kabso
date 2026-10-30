import { Controller, Get, Query } from '@nestjs/common';
import type { AuthContext } from '../../common/http/request-context.js';
import { CurrentAuth } from '../auth/current-auth.decorator.js';
import { CreatorStatsService, type CreatorStatsDto } from './creator-stats.service.js';

/** The creator center (contract v1.43-social draft, D164, CONVENTIONS §10.40). */
@Controller('me/creator-stats')
export class CreatorController {
  constructor(private readonly stats: CreatorStatsService) {}

  /** Per-user default rate limit (§7). */
  @Get()
  mine(@CurrentAuth() auth: AuthContext, @Query() query: unknown): Promise<CreatorStatsDto> {
    return this.stats.mine(auth.userId, query);
  }
}
