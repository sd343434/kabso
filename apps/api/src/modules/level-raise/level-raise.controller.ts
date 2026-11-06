import {
  Body,
  Controller,
  Get,
  HttpCode,
  Module,
  Param,
  Post,
  Put,
  Query,
  Req,
  Res,
  UseGuards,
} from '@nestjs/common';
import type { Request, Response } from 'express';
import { byIp, byUserId, RateLimit } from '../../common/rate-limit/rate-limit.decorator.js';
import type { AdminContext } from '../admin-panel/admin-auth.service.js';
import { AdminPanelModule } from '../admin-panel/admin-panel.module.js';
import { pathUuid } from '../admin-panel/admin-panel.schemas.js';
import { AdminSessionGuard, CurrentAdmin, RequireCapability } from '../admin-panel/admin-session.guard.js';
import {
  CurrentStaff,
  NotStaffWork,
  StaffAppGuard,
  StaffCapability,
} from '../admin-panel/staff-app.guard.js';
import { Public } from '../auth/public.decorator.js';
import { LevelProgressService } from '../levels/level-progress.service.js';
import { LiveModule } from '../live/live.module.js';
import { MediaModule } from '../media/media.module.js';
import { LevelRaiseService } from './level-raise.service.js';

/** The panel's raw video upload route (its body is kept as bytes, app.setup). */
export const LEVEL_RAISE_VIDEO_UPLOAD_PATH = '/api/v1/admin/level-raise-videos';

const STAFF_LIMIT = {
  bucket: 'staff:user',
  rule: 'staffAppUser',
  key: byUserId,
  replacesDefault: true,
} as const;
const PANEL_LIMIT = RateLimit({ bucket: 'admin:ip', rule: 'adminIp', key: byIp, replacesDefault: true });
/** One chunk of the panel's video proxy (a `<video>` asks for ranges). */
const VIDEO_CHUNK = 2 * 1024 * 1024;

/**
 * v1.89-social (D290, CONVENTIONS §10.103): «طلب رفع ليفيل» in the app — the staff Me tab «أنا» (MODERATION /
 * SUPPORT; `levels.raise.request`, checked on every request by {@link StaffAppGuard}). The video is uploaded first
 * with the media flow (`LEVEL_RAISE_VIDEO`).
 */
@Controller('staff/level-raises')
@UseGuards(StaffAppGuard)
export class StaffLevelRaisesController {
  constructor(private readonly raises: LevelRaiseService) {}

  @Get('source-apps')
  @RateLimit(STAFF_LIMIT)
  @StaffCapability('levels.raise.request')
  @NotStaffWork()
  sourceApps() {
    return this.raises.appOptions();
  }

  /** «هل تقصد: …؟» while typing an "other" app's name (the staff bucket, 300 / 15 min per user). */
  @Get('source-apps/suggest')
  @RateLimit(STAFF_LIMIT)
  @StaffCapability('levels.raise.request')
  @NotStaffWork()
  suggest(@Query() query: unknown) {
    return this.raises.suggest(query);
  }

  @Get('check')
  @RateLimit(STAFF_LIMIT)
  @StaffCapability('levels.raise.request')
  @NotStaffWork()
  check(@Query() query: unknown) {
    return this.raises.check(query);
  }

  @Get()
  @RateLimit(STAFF_LIMIT)
  @StaffCapability('levels.raise.request')
  @NotStaffWork()
  mine(@CurrentStaff() ctx: AdminContext, @Query() query: unknown) {
    return this.raises.mine(ctx.userId, query);
  }

  @Post()
  @HttpCode(201)
  @RateLimit(STAFF_LIMIT)
  @StaffCapability('levels.raise.request')
  create(@CurrentStaff() ctx: AdminContext, @Body() body: unknown) {
    return this.raises.create(ctx, body);
  }
}

/**
 * v1.89-social (D290): the panel — «طلبات رفع الليفيل». Staff (`levels.raise.request`) make requests and see their
 * own; the OWNER (`levels.raise.decide`) sees every request with the proposal and its reasoning, approves or rejects,
 * and edits the source-app data and the weights. Every change is audited (`via: panel`).
 */
@Public()
@Controller('admin')
@PANEL_LIMIT
@UseGuards(AdminSessionGuard)
export class AdminLevelRaisesController {
  constructor(private readonly raises: LevelRaiseService) {}

  @Get('level-raises')
  @RequireCapability('levels.raise.request')
  list(@CurrentAdmin() admin: AdminContext, @Query() query: unknown) {
    return this.raises.list(admin, query);
  }

  @Get('level-raises/check')
  @RequireCapability('levels.raise.request')
  check(@Query() query: unknown) {
    return this.raises.check(query);
  }

  @Get('level-raises/source-apps/suggest')
  @RequireCapability('levels.raise.request')
  suggest(@Query() query: unknown) {
    return this.raises.suggest(query);
  }

  @Get('level-raises/source-apps')
  @RequireCapability('levels.raise.request')
  sourceApps() {
    return this.raises.appOptions();
  }

  @Post('level-raises')
  @HttpCode(201)
  @RequireCapability('levels.raise.request')
  create(@CurrentAdmin() admin: AdminContext, @Body() body: unknown) {
    return this.raises.create(admin, body);
  }

  /** The video as raw bytes (`application/octet-stream`, MP4 / QuickTime, ≤ 100 MiB, ≤ 90 s). */
  @Post('level-raise-videos')
  @HttpCode(201)
  @RequireCapability('levels.raise.request')
  upload(@CurrentAdmin() admin: AdminContext, @Req() req: Request) {
    return this.raises.uploadPanelVideo(admin, req.body);
  }

  @Get('level-raises/:requestId')
  @RequireCapability('levels.raise.decide')
  detail(@Param('requestId') id: string) {
    return this.raises.detail(pathUuid(id));
  }

  /** The request's video through the API (Range requests; the panel's CSP allows no storage origin). */
  @Get('level-raises/:requestId/video')
  @RequireCapability('levels.raise.decide')
  async video(@Param('requestId') id: string, @Req() req: Request, @Res() res: Response): Promise<void> {
    const v = await this.raises.video(pathUuid(id));
    const range = /^bytes=(\d*)-(\d*)$/.exec(String(req.headers.range ?? ''));
    let start = 0;
    let end = Math.min(v.size, VIDEO_CHUNK) - 1;
    if (range) {
      if (range[1] === '' && range[2] !== '') {
        start = Math.max(v.size - Number(range[2]), 0);
      } else {
        start = Number(range[1] || '0');
      }
      end = Math.min(
        range[2] && range[1] !== '' ? Number(range[2]) : start + VIDEO_CHUNK - 1,
        start + VIDEO_CHUNK - 1,
        v.size - 1,
      );
      if (start >= v.size || end < start) {
        res
          .status(416)
          .setHeader('Content-Range', `bytes */${String(v.size)}`)
          .end();
        return;
      }
    }
    const bytes = await this.raises.readVideoRange(v.key, start, end - start + 1);
    if (!bytes) {
      res.status(404).end();
      return;
    }
    res.status(range || v.size > VIDEO_CHUNK ? 206 : 200);
    res.setHeader('Content-Type', v.contentType);
    res.setHeader('Accept-Ranges', 'bytes');
    res.setHeader('Content-Length', String(bytes.length));
    if (range || v.size > VIDEO_CHUNK) {
      res.setHeader(
        'Content-Range',
        `bytes ${String(start)}-${String(start + bytes.length - 1)}/${String(v.size)}`,
      );
    }
    res.end(bytes);
  }

  @Post('level-raises/:requestId/approve')
  @HttpCode(200)
  @RequireCapability('levels.raise.decide')
  approve(@CurrentAdmin() admin: AdminContext, @Param('requestId') id: string, @Body() body: unknown) {
    return this.raises.approve(admin, pathUuid(id), body);
  }

  @Post('level-raises/:requestId/reject')
  @HttpCode(200)
  @RequireCapability('levels.raise.decide')
  reject(@CurrentAdmin() admin: AdminContext, @Param('requestId') id: string, @Body() body: unknown) {
    return this.raises.reject(admin, pathUuid(id), body);
  }

  @Get('level-raise/apps')
  @RequireCapability('levels.raise.decide')
  apps() {
    return this.raises.apps();
  }

  @Post('level-raise/apps')
  @HttpCode(201)
  @RequireCapability('levels.raise.decide')
  createApp(@CurrentAdmin() admin: AdminContext, @Body() body: unknown) {
    return this.raises.createApp(admin, body);
  }

  @Put('level-raise/apps/:appId')
  @RequireCapability('levels.raise.decide')
  updateApp(@CurrentAdmin() admin: AdminContext, @Param('appId') id: string, @Body() body: unknown) {
    return this.raises.updateApp(admin, pathUuid(id), body);
  }

  @Get('level-raise/settings')
  @RequireCapability('levels.raise.decide')
  settings() {
    return this.raises.settingsView();
  }

  @Put('level-raise/settings')
  @RequireCapability('levels.raise.decide')
  updateSettings(@CurrentAdmin() admin: AdminContext, @Body() body: unknown) {
    return this.raises.updateSettings(admin, body);
  }
}

/** v1.89-social (D290): level-raise requests «طلب رفع ليفيل». */
@Module({
  // LiveModule: the staff guard's shift service (D286: staff work switches the shift on).
  imports: [AdminPanelModule, MediaModule, LiveModule],
  controllers: [StaffLevelRaisesController, AdminLevelRaisesController],
  providers: [LevelRaiseService, LevelProgressService],
})
export class LevelRaiseModule {}
