import { Module } from '@nestjs/common';
import { AdminPanelModule } from '../../admin-panel/admin-panel.module.js';
import { AdminPkDaresController } from './admin-pk-dares.controller.js';
import { AdminPkDaresService } from './admin-pk-dares.service.js';

/** «أحكام PK» in the admin panel (v1.50-live, D229): the dare library and the PK points settings. */
@Module({
  imports: [AdminPanelModule],
  controllers: [AdminPkDaresController],
  providers: [AdminPkDaresService],
})
export class PkDaresAdminModule {}
