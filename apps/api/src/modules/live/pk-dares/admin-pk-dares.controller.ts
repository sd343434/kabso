import {
  Body,
  Controller,
  Get,
  HttpCode,
  Param,
  Patch,
  Post,
  Put,
  Query,
  Res,
  UseGuards,
} from '@nestjs/common';
import type { Response } from 'express';
import { z } from 'zod';
import { byIp, RateLimit } from '../../../common/rate-limit/rate-limit.decorator.js';
import { ZodValidationPipe } from '../../../common/validation/zod-validation.pipe.js';
import type { AdminContext } from '../../admin-panel/admin-auth.service.js';
import { pathUuid } from '../../admin-panel/admin-panel.schemas.js';
import { AdminSessionGuard, CurrentAdmin, RequireCapability } from '../../admin-panel/admin-session.guard.js';
import { sendTable, tableQuery } from '../../admin-panel/admin-tables.js';
import { Public } from '../../auth/public.decorator.js';
import { AdminPkDaresService, type PkDaresQuery } from './admin-pk-dares.service.js';
import { PK_DARE_CATEGORIES, PK_DARE_LEVELS } from './pk-dare-rules.js';

const reason = z.string().trim().min(1).max(500);
const category = z.enum(PK_DARE_CATEGORIES);
const level = z.enum(PK_DARE_LEVELS);
const text = (max: number) => z.string().trim().min(1).max(max);

export const pkDaresQuery = tableQuery(['seqNo', 'reportCount', 'updatedAt'], 'seqNo')
  .extend({
    category: category.optional(),
    level: level.optional(),
    active: z.enum(['true', 'false']).optional(),
    reported: z.enum(['true']).optional(),
  })
  .strict();
const createBody = z.strictObject({ textAr: text(200), textEn: text(300), category, level, reason });
const updateBody = z
  .strictObject({
    textAr: text(200).optional(),
    textEn: text(300).optional(),
    category: category.optional(),
    level: level.optional(),
    active: z.boolean().optional(),
    reason,
  })
  .refine((v) => Object.keys(v).length > 1, { message: 'at least one change' });
const clearBody = z.strictObject({ enable: z.boolean().default(false), reason });
const importBody = z.strictObject({
  format: z.enum(['json', 'csv']),
  content: z.string().min(1).max(5_000_000),
  dryRun: z.boolean().default(false),
  reason,
});
const points = z.number().int().min(-100).max(100);
const settingsBody = z
  .strictObject({
    winPoints: points.optional(),
    drawPoints: points.optional(),
    lossPoints: points.optional(),
    refusePoints: points.optional(),
    // v1.67-live (D276): a host who withdrew from the battle.
    forfeitPoints: points.optional(),
    decideSeconds: z.number().int().min(5).max(300).optional(),
    reportsToDisable: z.number().int().min(1).max(1000).optional(),
    reason,
  })
  .refine((v) => Object.keys(v).length > 1, { message: 'at least one change' });

/**
 * «أحكام PK» (v1.50-live, D229, CONVENTIONS §10.80): `pk_dares.view` (OWNER only since D274) reads the library,
 * the reported queue, the counts and the settings; `pk_dares.edit` (OWNER only) adds, edits, disables, imports,
 * clears reports and changes the PK points. Every write needs a reason and the CSRF header (the session guard).
 */
@Public()
@Controller('admin')
@RateLimit({ bucket: 'admin:ip', rule: 'adminIp', key: byIp, replacesDefault: true })
@UseGuards(AdminSessionGuard)
export class AdminPkDaresController {
  constructor(private readonly dares: AdminPkDaresService) {}

  @Get('pk-dares')
  @RequireCapability('pk_dares.view')
  async list(
    @Query(new ZodValidationPipe(pkDaresQuery)) q: PkDaresQuery,
    @CurrentAdmin() admin: AdminContext,
    @Res({ passthrough: true }) res: Response,
  ) {
    return sendTable(res, await this.dares.table(q, admin));
  }

  @Get('pk-dares/stats')
  @RequireCapability('pk_dares.view')
  stats() {
    return this.dares.stats();
  }

  @Post('pk-dares')
  @RequireCapability('pk_dares.edit')
  create(
    @Body(new ZodValidationPipe(createBody)) body: z.infer<typeof createBody>,
    @CurrentAdmin() admin: AdminContext,
  ) {
    return this.dares.create(body, admin);
  }

  @Post('pk-dares/import')
  @HttpCode(200)
  @RequireCapability('pk_dares.edit')
  import(
    @Body(new ZodValidationPipe(importBody)) body: z.infer<typeof importBody>,
    @CurrentAdmin() admin: AdminContext,
  ) {
    return this.dares.import(body, admin);
  }

  @Patch('pk-dares/:dareId')
  @RequireCapability('pk_dares.edit')
  update(
    @Param('dareId') id: string,
    @Body(new ZodValidationPipe(updateBody)) body: z.infer<typeof updateBody>,
    @CurrentAdmin() admin: AdminContext,
  ) {
    return this.dares.update(pathUuid(id), body, admin);
  }

  @Post('pk-dares/:dareId/reports/clear')
  @HttpCode(200)
  @RequireCapability('pk_dares.edit')
  clear(
    @Param('dareId') id: string,
    @Body(new ZodValidationPipe(clearBody)) body: z.infer<typeof clearBody>,
    @CurrentAdmin() admin: AdminContext,
  ) {
    return this.dares.clearReports(pathUuid(id), body, admin);
  }

  @Get('pk-dare-settings')
  @RequireCapability('pk_dares.view')
  settings() {
    return this.dares.settings();
  }

  @Put('pk-dare-settings')
  @RequireCapability('pk_dares.edit')
  updateSettings(
    @Body(new ZodValidationPipe(settingsBody)) body: z.infer<typeof settingsBody>,
    @CurrentAdmin() admin: AdminContext,
  ) {
    return this.dares.updateSettings(body, admin);
  }
}
