import { Module } from '@nestjs/common';
import { MediaModule } from '../media/media.module.js';
import { UsersModule } from '../users/users.module.js';
import { VipAdminService } from './vip-admin.service.js';
import { VipController } from './vip.controller.js';
import { VipIdentityService } from './vip-identity.service.js';
import { VipService } from './vip.service.js';

/**
 * v1.82-social (D252, CONVENTIONS §10.93): «شراء VIP». Owns `vip_tiers`, `vip_tier_perks`, `vip_memberships` and
 * `vip_purchases`; takes coins only through `wallet_ledger` (`VIP_PURCHASE`). The admin panel's page uses
 * {@link VipAdminService} (exported).
 */
@Module({
  imports: [UsersModule, MediaModule],
  controllers: [VipController],
  // v1.131-social (D378): the identity perks the server keeps (signature, golden IDs; the panel's stock too).
  providers: [VipService, VipAdminService, VipIdentityService],
  exports: [VipAdminService, VipIdentityService],
})
export class VipModule {}
