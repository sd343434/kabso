import { Module } from '@nestjs/common';
import { RechargePointsController } from './recharge-points.controller.js';
import { RechargePointsService } from './recharge-points.service.js';

/**
 * v1.126-social (D370, CONVENTIONS §10.162): «نقاط الشحن». Owns `recharge_points_balances` and the append-only
 * `recharge_points_ledger`; written by the recharge paths (top-up, store purchase, agent sale and order), their
 * reversals, the VIP redemption and the panel's adjustment ({@link RechargePointsService}, exported).
 */
@Module({
  controllers: [RechargePointsController],
  providers: [RechargePointsService],
  exports: [RechargePointsService],
})
export class RechargePointsModule {}
