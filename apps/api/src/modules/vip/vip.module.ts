import { Module } from '@nestjs/common';
import { MediaModule } from '../media/media.module.js';
import { UsersModule } from '../users/users.module.js';
import { VipAdminService } from './vip-admin.service.js';
import { VipController } from './vip.controller.js';
import { VipService } from './vip.service.js';

/**
 * v1.82-social (D252, CONVENTIONS §10.93): «شراء VIP». Owns `vip_tiers`, `vip_tier_perks`, `vip_memberships` and
 * `vip_purchases`; takes coins only through `wallet_ledger` (`VIP_PURCHASE`). The admin panel's page uses
 * {@link VipAdminService} (exported).
 */
@Module({
  imports: [UsersModule, MediaModule],
  controllers: [VipController],
  providers: [VipService, VipAdminService],
  exports: [VipAdminService],
})
export class VipModule {}
