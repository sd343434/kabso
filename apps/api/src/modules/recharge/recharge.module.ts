import { Module } from '@nestjs/common';
import { MediaModule } from '../media/media.module.js';
import { RechargeOrdersController } from './recharge-orders.controller.js';
import { RechargeOrdersService } from './recharge-orders.service.js';
import { RechargeController } from './recharge.controller.js';
import { RechargeService } from './recharge.service.js';

/**
 * v1.54-social (D185, CONVENTIONS §10.48): recharge agents «وكلاء الشحن» — owns `recharge_agent_applications`,
 * `recharge_agents`, `recharge_agent_counter`, `recharge_stock_ledger`, `recharge_topups`, `recharge_sales`,
 * `recharge_employees` and `recharge_cherry_requests`. The team acts through the `recharge-admin` CLI.
 * v1.69-social (D204, §10.64): recharge orders with escrow — owns `recharge_orders`, `recharge_order_messages` and
 * `recharge_exchange_rates` (the panel reads them through {@link RechargeOrdersService}).
 */
@Module({
  imports: [MediaModule],
  controllers: [RechargeController, RechargeOrdersController],
  providers: [RechargeService, RechargeOrdersService],
  exports: [RechargeOrdersService],
})
export class RechargeModule {}
