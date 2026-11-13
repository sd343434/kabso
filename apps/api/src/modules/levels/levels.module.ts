import { Module } from '@nestjs/common';
import { UsersModule } from '../users/users.module.js';
import { AdminGuard, AdminPermissions } from './admin.guard.js';
import { AdminLevelsController } from './admin-levels.controller.js';
import { LevelAdminService } from './level-admin.service.js';
import { LevelConfigService } from './level-config.service.js';
import { LevelEventsService } from './level-events.service.js';
import { LevelProgressService } from './level-progress.service.js';
import { LevelsController, UserLevelsController } from './levels.controller.js';
import { LevelsQueryService } from './levels-query.service.js';
import { LEVEL_SOURCE_VERIFIER, UnavailableSourceVerifier } from './source-verifier.js';

/**
 * `levels` module (openapi v1.4-levels DRAFT, CP-005): four independent level systems. Owns the
 * `level_*` tables, `user_level_states` and `points_ledger`. The source verifier rejects every
 * event until a gifts/wallet/games module provides a real one (CP-005 §6), so nothing earns
 * points in production yet. `LevelEventsService` is exported for those future producers.
 */
@Module({
  imports: [UsersModule],
  controllers: [LevelsController, UserLevelsController, AdminLevelsController],
  providers: [
    AdminGuard,
    AdminPermissions,
    LevelProgressService,
    LevelEventsService,
    LevelConfigService,
    LevelsQueryService,
    LevelAdminService,
    { provide: LEVEL_SOURCE_VERIFIER, useClass: UnavailableSourceVerifier },
  ],
  exports: [LevelEventsService],
})
export class LevelsModule {}
