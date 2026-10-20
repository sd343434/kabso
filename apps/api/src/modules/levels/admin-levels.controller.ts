import {
  Body,
  Controller,
  Get,
  Headers,
  HttpCode,
  Param,
  Patch,
  Post,
  Put,
  Query,
  Req,
  UseGuards,
} from '@nestjs/common';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { languageFromAcceptLanguage } from '../../common/http/content-language.js';
import { clientIp, type AppRequest, type AuthContext } from '../../common/http/request-context.js';
import { getRequestId } from '../../common/request-id/request-id.js';
import { ZodValidationPipe } from '../../common/validation/zod-validation.pipe.js';
import { CurrentAuth } from '../auth/current-auth.decorator.js';
import { isUuid } from '../live/live.schemas.js';
import { AdminGuard, AdminPermissions, RequireAdminPermission } from './admin.guard.js';
import { LevelAdminService, type AdjustmentResultDto } from './level-admin.service.js';
import {
  LevelConfigService,
  type AdminActor,
  type AdminLevelCategoryDto,
  type LevelPreviewDto,
} from './level-config.service.js';
import { categoryParam } from './levels.controller.js';
import type {
  AdminLevelVersionDto,
  LevelReconciliationRunDto,
  LevelSourceEventDto,
  PageDto,
} from './levels.dto.js';
import {
  LevelsQueryService,
  type AdminUserLevelsDto,
  type LevelAuditLogDto,
  type LevelCategoryReportDto,
} from './levels-query.service.js';
import {
  adjustmentSchema,
  createVersionSchema,
  eventsQuerySchema,
  idempotencyKeySchema,
  pageQuerySchema,
  previewQuerySchema,
  publishSchema,
  reconciliationSchema,
  recalculateSchema,
  updateCategorySchema,
  versionInputSchema,
} from './levels.schemas.js';

type Body<S> = S extends { _zod: { output: infer O } } ? O : never;

/** Path ids that are not UUIDs are not found (404), as elsewhere in the API. */
function uuidParam(value: string): string {
  if (!isUuid(value)) throw new AppException(ErrorCode.NOT_FOUND);
  return value.toLowerCase();
}

/**
 * Level administration (openapi v1.4-levels DRAFT, CP-005 §7). Every route needs `role = ADMIN`
 * and its own permission (§9.8: view, edit drafts, publish, adjust, reconcile); every mutation is
 * audited. The admin web panel arrives with Phase 10.
 */
@Controller('admin/levels')
@UseGuards(AdminGuard)
export class AdminLevelsController {
  constructor(
    private readonly config: LevelConfigService,
    private readonly admin: LevelAdminService,
    private readonly query: LevelsQueryService,
    private readonly permissions: AdminPermissions,
  ) {}

  private actor(auth: AuthContext, req: AppRequest): AdminActor {
    return { userId: auth.userId, ip: clientIp(req), requestId: getRequestId(req) };
  }

  @Get('categories')
  @RequireAdminPermission('LEVELS_VIEW')
  async categories(): Promise<{ data: AdminLevelCategoryDto[] }> {
    return { data: await this.config.listCategories() };
  }

  @Get('categories/:category')
  @RequireAdminPermission('LEVELS_VIEW')
  category(@Param('category') slug: string): Promise<AdminLevelCategoryDto> {
    return this.config.getCategory(categoryParam(slug));
  }

  @Patch('categories/:category')
  @RequireAdminPermission('LEVELS_EDIT')
  async updateCategory(
    @CurrentAuth() auth: AuthContext,
    @Req() req: AppRequest,
    @Param('category') slug: string,
    @Body(new ZodValidationPipe(updateCategorySchema)) body: Body<typeof updateCategorySchema>,
  ): Promise<AdminLevelCategoryDto> {
    const code = categoryParam(slug);
    // Switching a category on or off changes what users earn: as strong as publishing.
    if (body.enabled !== undefined) await this.permissions.require(auth.userId, 'LEVELS_PUBLISH');
    return this.config.updateCategory(code, body, this.actor(auth, req));
  }

  @Get('categories/:category/versions')
  @RequireAdminPermission('LEVELS_VIEW')
  async versions(@Param('category') slug: string): Promise<{ data: AdminLevelVersionDto[] }> {
    return { data: await this.config.listVersions(categoryParam(slug)) };
  }

  @Post('categories/:category/versions')
  @RequireAdminPermission('LEVELS_EDIT')
  @HttpCode(201)
  createVersion(
    @CurrentAuth() auth: AuthContext,
    @Req() req: AppRequest,
    @Param('category') slug: string,
    @Body(new ZodValidationPipe(createVersionSchema)) body: Body<typeof createVersionSchema>,
  ): Promise<AdminLevelVersionDto> {
    const code = categoryParam(slug);
    return this.config.createVersion(
      code,
      body.copyFromVersionId?.toLowerCase() ?? null,
      this.actor(auth, req),
    );
  }

  @Get('versions/:versionId')
  @RequireAdminPermission('LEVELS_VIEW')
  version(@Param('versionId') id: string): Promise<AdminLevelVersionDto> {
    return this.config.getVersion(uuidParam(id));
  }

  @Put('versions/:versionId')
  @RequireAdminPermission('LEVELS_EDIT')
  replaceVersion(
    @CurrentAuth() auth: AuthContext,
    @Req() req: AppRequest,
    @Param('versionId') id: string,
    @Body(new ZodValidationPipe(versionInputSchema)) body: Body<typeof versionInputSchema>,
  ): Promise<AdminLevelVersionDto> {
    const versionId = uuidParam(id);
    return this.config.replaceVersion(versionId, body, this.actor(auth, req));
  }

  @Post('versions/:versionId/validate')
  @RequireAdminPermission('LEVELS_VIEW')
  @HttpCode(200)
  validate(
    @Param('versionId') id: string,
  ): Promise<{ valid: boolean; issues: { field: string; issue: string }[] }> {
    return this.config.validateVersion(uuidParam(id));
  }

  @Get('versions/:versionId/preview')
  @RequireAdminPermission('LEVELS_VIEW')
  preview(
    @Param('versionId') id: string,
    @Query(new ZodValidationPipe(previewQuerySchema)) query: Body<typeof previewQuerySchema>,
  ): Promise<LevelPreviewDto> {
    const versionId = uuidParam(id);
    return this.config.previewVersion(versionId, query.recalculation);
  }

  @Post('versions/:versionId/publish')
  @RequireAdminPermission('LEVELS_PUBLISH')
  @HttpCode(200)
  publish(
    @CurrentAuth() auth: AuthContext,
    @Req() req: AppRequest,
    @Param('versionId') id: string,
    @Body(new ZodValidationPipe(publishSchema)) body: Body<typeof publishSchema>,
  ): Promise<AdminLevelVersionDto> {
    const versionId = uuidParam(id);
    return this.config.publishVersion(versionId, body.recalculation, this.actor(auth, req));
  }

  @Get('users/:userId')
  @RequireAdminPermission('LEVELS_VIEW')
  user(@Req() req: AppRequest, @Param('userId') id: string): Promise<AdminUserLevelsDto> {
    const userId = uuidParam(id);
    return this.query.adminUser(userId, languageFromAcceptLanguage(req.headers['accept-language']) ?? 'en');
  }

  @Post('users/:userId/recalculate')
  @RequireAdminPermission('LEVELS_ADJUST')
  @HttpCode(200)
  recalculate(
    @CurrentAuth() auth: AuthContext,
    @Req() req: AppRequest,
    @Param('userId') id: string,
    @Body(new ZodValidationPipe(recalculateSchema)) body: Body<typeof recalculateSchema>,
  ): Promise<AdminUserLevelsDto> {
    const userId = uuidParam(id);
    return this.admin.recalculate(userId, body.category, this.actor(auth, req));
  }

  @Post('users/:userId/adjustments')
  @RequireAdminPermission('LEVELS_ADJUST')
  @HttpCode(200)
  adjust(
    @CurrentAuth() auth: AuthContext,
    @Req() req: AppRequest,
    @Param('userId') id: string,
    @Headers('idempotency-key') rawKey: string | undefined,
    @Body(new ZodValidationPipe(adjustmentSchema)) body: Body<typeof adjustmentSchema>,
  ): Promise<AdjustmentResultDto> {
    const userId = uuidParam(id);
    if (rawKey === undefined)
      throw AppException.validation([{ field: 'Idempotency-Key', issue: 'required' }]);
    const key = idempotencyKeySchema.safeParse(rawKey);
    if (!key.success) throw AppException.validation([{ field: 'Idempotency-Key', issue: 'invalid_format' }]);
    return this.admin.adjust(userId, body, key.data.toLowerCase(), this.actor(auth, req));
  }

  @Get('reconciliation')
  @RequireAdminPermission('LEVELS_VIEW')
  runs(
    @Query(new ZodValidationPipe(pageQuerySchema)) query: Body<typeof pageQuerySchema>,
  ): Promise<PageDto<LevelReconciliationRunDto>> {
    return this.query.runs(query);
  }

  @Post('reconciliation')
  @RequireAdminPermission('LEVELS_RECONCILE')
  @HttpCode(200)
  reconcile(
    @CurrentAuth() auth: AuthContext,
    @Req() req: AppRequest,
    @Body(new ZodValidationPipe(reconciliationSchema)) body: Body<typeof reconciliationSchema>,
  ): Promise<LevelReconciliationRunDto> {
    return this.admin.reconcile(body.mode, body.category, this.actor(auth, req));
  }

  @Get('reconciliation/:runId')
  @RequireAdminPermission('LEVELS_VIEW')
  run(@Param('runId') id: string): Promise<LevelReconciliationRunDto> {
    return this.query.run(uuidParam(id));
  }

  @Get('events')
  @RequireAdminPermission('LEVELS_VIEW')
  events(
    @Query(new ZodValidationPipe(eventsQuerySchema)) query: Body<typeof eventsQuerySchema>,
  ): Promise<PageDto<LevelSourceEventDto>> {
    return this.query.events(query.status, query);
  }

  @Post('events/:eventId/retry')
  @RequireAdminPermission('LEVELS_RECONCILE')
  @HttpCode(200)
  retry(
    @CurrentAuth() auth: AuthContext,
    @Req() req: AppRequest,
    @Param('eventId') id: string,
  ): Promise<LevelSourceEventDto> {
    return this.admin.retryEvent(uuidParam(id), this.actor(auth, req));
  }

  @Get('reports')
  @RequireAdminPermission('LEVELS_VIEW')
  async reports(): Promise<{ data: LevelCategoryReportDto[] }> {
    return { data: await this.query.reports() };
  }

  @Get('audit-logs')
  @RequireAdminPermission('LEVELS_VIEW')
  auditLogs(
    @Query(new ZodValidationPipe(pageQuerySchema)) query: Body<typeof pageQuerySchema>,
  ): Promise<PageDto<LevelAuditLogDto>> {
    return this.query.auditLogs(query);
  }
}
