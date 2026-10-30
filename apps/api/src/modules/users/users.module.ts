import { Module } from '@nestjs/common';
import { MediaModule } from '../media/media.module.js';
import { PresenceTracker } from './presence.js';
import { ProfileEditService } from './profile-edit.service.js';
import { SpecialUsernamesSweeper } from './special-usernames.sweeper.js';
import { AvatarController, UsersController } from './users.controller.js';
import { UsersService } from './users.service.js';

@Module({
  // D168: the profile photo is an `AVATAR` media asset (§10.42).
  imports: [MediaModule],
  controllers: [UsersController, AvatarController],
  providers: [UsersService, PresenceTracker, ProfileEditService, SpecialUsernamesSweeper],
  exports: [UsersService, PresenceTracker],
})
export class UsersModule {}
