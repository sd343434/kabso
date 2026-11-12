import { Module } from '@nestjs/common';
import { MediaModule } from '../media/media.module.js';
import { CategoryVerificationController } from './category-verification.controller.js';
import { CategoryVerificationService } from './category-verification.js';
import { PresenceTracker } from './presence.js';
import { ProfileEditService } from './profile-edit.service.js';
import { SpecialUsernamesSweeper } from './special-usernames.sweeper.js';
import {
  AnimatedAvatarController,
  AvatarController,
  CoverController,
  UsersController,
} from './users.controller.js';
import { UsersService } from './users.service.js';

@Module({
  // D168: the profile photo is an `AVATAR` media asset (§10.42).
  imports: [MediaModule],
  controllers: [
    UsersController,
    AvatarController,
    CoverController,
    AnimatedAvatarController,
    // v1.138-social (D386): «طلب توثيق الفئة».
    CategoryVerificationController,
  ],
  providers: [
    UsersService,
    PresenceTracker,
    ProfileEditService,
    SpecialUsernamesSweeper,
    CategoryVerificationService,
  ],
  exports: [UsersService, PresenceTracker],
})
export class UsersModule {}
