import { Module } from '@nestjs/common';
import { LiveModule } from '../live/live.module.js';
import { CreatorController } from './creator.controller.js';
import { CreatorStatsService } from './creator-stats.service.js';

/** v1.43-social (D164): the Me hub's creator center; reads follows, posts and live summaries. */
@Module({
  imports: [LiveModule],
  controllers: [CreatorController],
  providers: [CreatorStatsService],
})
export class CreatorModule {}
