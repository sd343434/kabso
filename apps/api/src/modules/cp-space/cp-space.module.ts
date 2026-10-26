import { Module } from '@nestjs/common';
import { CouplesModule } from '../couples/couples.module.js';
import { UsersModule } from '../users/users.module.js';
import { CpConfessionsService } from './cp-confessions.service.js';
import { CpSpaceController } from './cp-space.controller.js';
import { CpSpaceService } from './cp-space.service.js';

/**
 * CP-021 (D112, CONVENTIONS §10.24): the CP space — daily tasks, privileges, the public couple
 * page, the gift wall, the couples ranking and confessions. Owns `cp_points_ledger` (with the
 * couples module, which writes CP gift gains), `cp_check_ins`, `cp_task_claims` and
 * `cp_confessions`.
 */
@Module({
  imports: [CouplesModule, UsersModule],
  controllers: [CpSpaceController],
  providers: [CpSpaceService, CpConfessionsService],
})
export class CpSpaceModule {}
