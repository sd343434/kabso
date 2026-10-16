import { Module } from '@nestjs/common';
import { CountriesModule } from '../../countries/countries.module.js';
import { LiveModule } from '../../live/live.module.js';
import { MediaModule } from '../../media/media.module.js';
import { SocialModule } from '../../social/social.module.js';
import { UsersModule } from '../users.module.js';
import { AccountLifecycleService } from './account-lifecycle.service.js';
import { MeController } from './me.controller.js';
import { MeService } from './me.service.js';
import { PublicProfileController } from './public-profile.controller.js';
import { PublicProfileService } from './public-profile.service.js';

/**
 * Public profiles and account lifecycle (contract v1.3), `PATCH /me` and `GET /countries`
 * (v1.4): the users-domain features that need the live, social and media modules. Kept apart from UsersModule, which live and social depend on.
 */
@Module({
  imports: [UsersModule, LiveModule, SocialModule, MediaModule, CountriesModule],
  controllers: [PublicProfileController, MeController],
  providers: [PublicProfileService, AccountLifecycleService, MeService],
  exports: [AccountLifecycleService],
})
export class PublicProfileModule {}
