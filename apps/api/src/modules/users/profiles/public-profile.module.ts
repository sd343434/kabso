import { Module } from '@nestjs/common';
import { BagModule } from '../../bag/bag.module.js';
import { CouplesModule } from '../../couples/couples.module.js';
import { FamiliesModule } from '../../families/families.module.js';
import { LiveModule } from '../../live/live.module.js';
import { MedalsModule } from '../../medals/medals.module.js';
import { SocialModule } from '../../social/social.module.js';
import { UsersModule } from '../users.module.js';
import { AccountLifecycleService } from './account-lifecycle.service.js';
import { PublicProfileController } from './public-profile.controller.js';
import { PublicProfileService } from './public-profile.service.js';

/**
 * Public profiles and account lifecycle (contract v1.3): the users-domain features that need the
 * live and social modules. Kept apart from UsersModule, which live and social depend on.
 */
@Module({
  imports: [UsersModule, LiveModule, SocialModule, FamiliesModule, CouplesModule, MedalsModule, BagModule],
  controllers: [PublicProfileController],
  providers: [PublicProfileService, AccountLifecycleService],
  exports: [AccountLifecycleService],
})
export class PublicProfileModule {}
