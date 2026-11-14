import { Module } from '@nestjs/common';
import { MediaModule } from '../media/media.module.js';
import { UsersModule } from '../users/users.module.js';
import { HomeController } from './home.controller.js';
import { HomeService } from './home.service.js';

/**
 * D124 (v1.26-live draft, CONVENTIONS §10.26): the promo banners of the live hub. Owns
 * `home_banners`; only the `banner-admin` CLI writes it.
 */
@Module({
  imports: [MediaModule, UsersModule],
  controllers: [HomeController],
  providers: [HomeService],
})
export class HomeModule {}
