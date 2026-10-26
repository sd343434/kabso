import { Module } from '@nestjs/common';
import { PresenceTracker } from './presence.js';
import { UsersController } from './users.controller.js';
import { UsersService } from './users.service.js';

@Module({
  controllers: [UsersController],
  providers: [UsersService, PresenceTracker],
  exports: [UsersService, PresenceTracker],
})
export class UsersModule {}
