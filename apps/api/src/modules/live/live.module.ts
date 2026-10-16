import { Module } from '@nestjs/common';
import { UsersModule } from '../users/users.module.js';
import { LiveCategoriesService } from './live-categories.service.js';
import { LiveRoomsService } from './live-rooms.service.js';
import { LiveController } from './live.controller.js';

/**
 * `live` module (contract v1.3): owns `live_categories` and `live_rooms`
 * (DB_PHASE2_DISCOVERY.md). Runs the in-process stale-room sweeper.
 */
@Module({
  imports: [UsersModule],
  controllers: [LiveController],
  providers: [LiveCategoriesService, LiveRoomsService],
  exports: [LiveRoomsService],
})
export class LiveModule {}
