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
  Req,
  Res,
  UseGuards,
} from '@nestjs/common';
import type { Request, Response } from 'express';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { byIp, RateLimit } from '../../common/rate-limit/rate-limit.decorator.js';
import { ZodValidationPipe } from '../../common/validation/zod-validation.pipe.js';
import { Public } from '../auth/public.decorator.js';
import type { GiftBadge, EventMetric } from '../../generated/prisma/client.js';
import { GIFT_CATEGORY_CODE_PATTERN, GIFT_CODE_PATTERN } from '../gifts/gift-catalogue.js';
import type { AdminContext } from './admin-auth.service.js';
import { AdminAgenciesService, type AgenciesQuery, type ComplaintsQuery } from './admin-agencies.service.js';
import { AdminCatalogService, type GiftCategoryInput, type GiftUploadKind } from './admin-catalog.service.js';
import {
  AdminGiftEventsService,
  eventBadgeInputSchema,
  eventUploadQuery,
  type EventBadgeInput,
} from './admin-gift-events.service.js';
import type { EventMediaKind } from '../programs/event-media.js';
import { giftEventInputSchema, type GiftEventInput } from '../programs/gift-events.js';
import { AdminLivesService } from './admin-lives.service.js';
import { AdminMoneyService, type RangeQuery } from './admin-money.service.js';
import { pathUuid } from './admin-panel.schemas.js';
import { AdminPeopleService, type UsersTableQuery } from './admin-people.service.js';
import { can, type PanelRole } from './admin-permissions.js';
import { AdminProgramsService } from './admin-programs.service.js';
import { AdminSessionGuard, CurrentAdmin, RequireCapability } from './admin-session.guard.js';
import { AdminStatsService } from './admin-stats.service.js';
import { sendTable, type TableQuery } from './admin-tables.js';
import { AdminTeamService, type AuditQuery, type TeamGrantBody } from './admin-team.service.js';
import { AdminStaffShiftsService } from './admin-staff-shifts.service.js';
import {
  agenciesQuery,
  agencyProbationExtendBody,
  auditQuery,
  bannerUploadQuery,
  type BannerPlacementParam,
  createBannerBody,
  bagGrantBody,
  bagRevokeBody,
  cardOrdersQuery,
  casesQuery,
  closeCaseBody,
  complaintsQuery,
  createAgencyBody,
  createEventBody,
  createGiftBody,
  createGiftCategoryBody,
  giftFileQuery,
  giftUploadQuery,
  removeGiftCategoryBody,
  updateGiftCategoryBody,
  hostBody,
  hostsQuery,
  ledgerQuery,
  livesQuery,
  pageOnlyQuery,
  reasonBody,
  reasonTotpBody,
  agencyBanBody,
  rechargeTopupsQuery,
  refundBody,
  reportQuery,
  resolveComplaintBody,
  revokeSessionsBody,
  searchQuery,
  specialUsernamesQuery,
  statsSeriesQuery,
  teamGrantBody,
  teamResetBody,
  teamRegionsBody,
  type TeamRegionsBody,
  teamRevokeBody,
  updateGiftBody,
  usersTableQuery,
  waitlistQuery,
} from './admin-v2.schemas.js';

/** Every cookie-authenticated panel route: per-IP limit instead of the public default (§10.54.2). */
const PANEL_SPEC = { bucket: 'admin:ip', rule: 'adminIp', key: byIp, replacesDefault: true } as const;
const PANEL_LIMIT = RateLimit(PANEL_SPEC);
/** v1.66-live (D271): a team change also counts in its own tighter bucket (the route's specs replace the class's). */
const TEAM_LIMIT = RateLimit(PANEL_SPEC, { bucket: 'admin-team:ip', rule: 'adminTeamIp', key: byIp });

function giftCode(raw: string): string {
  if (!GIFT_CODE_PATTERN.test(raw)) throw new AppException(ErrorCode.NOT_FOUND);
  return raw;
}

/** v1.71-social (D207): a category code in a path (404 for anything else). */
function categoryCode(raw: string): string {
  if (!GIFT_CATEGORY_CODE_PATTERN.test(raw)) throw new AppException(ErrorCode.NOT_FOUND);
  return raw;
}

/** v1.71-social (D207): the raw upload route (its body is kept as bytes, app.setup). */
export const GIFT_UPLOAD_PATH = '/api/v1/admin/gift-uploads';

/** v1.59-live (D248): the panel's banner picture upload (its body is kept as bytes too, app.setup). */
export const BANNER_UPLOAD_PATH = '/api/v1/admin/banner-uploads';
/** v1.97-social (D303, §10.114.6): the panel's banner video upload (raw bytes, at most 30 MiB, app.setup). */
export const BANNER_VIDEO_UPLOAD_PATH = '/api/v1/admin/banner-video-uploads';
/** v1.97-social (D303 follow-ups, §10.114.9): an event's art upload (raw bytes, ≤ 30 MiB, app.setup). */
export const EVENT_UPLOAD_PATH = '/api/v1/admin/event-uploads';

type Page = { page: number; pageSize: number };
type GiftBody = {
  category?: string;
  badge?: GiftBadge;
  reason: string;
  [k: string]: unknown;
};

/**
 * The admin panel v2 (v1.65-social, D197, CONVENTIONS §10.60, CP-039): statistics, quick search, the users table
 * and a user's tabs, agencies, lives and hosts, gifts and items, money, the audit log and the team, tasks / levels /
 * special usernames / waitlist. Every route names one capability (checked by {@link AdminSessionGuard} on every
 * request), every change needs the CSRF header and a reason, and money-moving or team changes the authenticator
 * code again. Changes run the CLIs' own rules with `via: panel`.
 */
@Public()
@Controller('admin')
@PANEL_LIMIT
@UseGuards(AdminSessionGuard)
export class AdminV2Controller {
  constructor(
    private readonly stats: AdminStatsService,
    private readonly people: AdminPeopleService,
    private readonly agencies: AdminAgenciesService,
    private readonly lives: AdminLivesService,
    private readonly catalog: AdminCatalogService,
    private readonly money: AdminMoneyService,
    private readonly team: AdminTeamService,
    private readonly programs: AdminProgramsService,
    private readonly shifts: AdminStaffShiftsService,
    private readonly giftEvents: AdminGiftEventsService,
  ) {}

  // ---- statistics and search (§10.60.1) -------------------------------------------------------------------------

  @Get('stats/overview')
  @RequireCapability('dashboard.view')
  overview() {
    return this.stats.overview();
  }

  @Get('stats/series')
  @RequireCapability('dashboard.view')
  series(@Query(new ZodValidationPipe(statsSeriesQuery)) q: { days: 7 | 30 | 90 }) {
    return this.stats.series(q.days);
  }

  @Get('stats/attention')
  @RequireCapability('dashboard.view')
  attention(@CurrentAdmin() admin: AdminContext) {
    return this.stats.attention(admin);
  }

  @Get('stats/activity')
  @RequireCapability('dashboard.view')
  activity(@CurrentAdmin() admin: AdminContext) {
    return this.stats.activity(admin);
  }

  @Get('search')
  @RequireCapability('users.view')
  search(@Query(new ZodValidationPipe(searchQuery)) q: { q: string }, @CurrentAdmin() admin: AdminContext) {
    return this.stats.search(q.q, admin);
  }

  // ---- users (§10.60.1) -----------------------------------------------------------------------------------------

  @Get('tables/users')
  @RequireCapability('users.list')
  async usersTable(
    @Query(new ZodValidationPipe(usersTableQuery)) q: UsersTableQuery,
    @CurrentAdmin() admin: AdminContext,
    @Res({ passthrough: true }) res: Response,
  ) {
    if (q.format === 'csv' && !can(admin.roles, 'users.export'))
      throw new AppException(ErrorCode.AUTH_FORBIDDEN);
    return sendTable(res, await this.people.table(q, admin));
  }

  @Get('users/:userId/ledger')
  @RequireCapability('users.ledger')
  ledger(
    @Param('userId') id: string,
    @Query(new ZodValidationPipe(ledgerQuery)) q: Page & { kind: 'coins' | 'cherries' },
  ) {
    return this.people.ledger(pathUuid(id), q.kind, q.page, q.pageSize);
  }

  @Get('users/:userId/posts')
  @RequireCapability('users.view')
  posts(@Param('userId') id: string, @Query(new ZodValidationPipe(pageOnlyQuery)) q: Page) {
    return this.people.posts(pathUuid(id), q.page, q.pageSize);
  }

  @Get('users/:userId/audit')
  @RequireCapability('audit.view')
  userAudit(@Param('userId') id: string, @Query(new ZodValidationPipe(pageOnlyQuery)) q: Page) {
    return this.people.auditOf(pathUuid(id), q.page, q.pageSize);
  }

  @Get('users/:userId/sessions')
  @RequireCapability('users.sessions')
  sessions(@Param('userId') id: string) {
    return this.people.sessionsOf(pathUuid(id));
  }

  @Post('users/:userId/sessions/revoke')
  @HttpCode(200)
  @RequireCapability('users.sessions')
  revokeSessions(
    @Param('userId') id: string,
    @Body(new ZodValidationPipe(revokeSessionsBody)) body: { sessionId?: string; reason: string },
    @CurrentAdmin() admin: AdminContext,
  ) {
    return this.people.revokeSessions(pathUuid(id), body.sessionId?.toLowerCase(), body.reason, admin);
  }

  @Get('users/:userId/bag')
  @RequireCapability('items.grant')
  userBag(@Param('userId') id: string) {
    return this.catalog.userBag(pathUuid(id));
  }

  @Post('users/:userId/bag/grant')
  @HttpCode(200)
  @RequireCapability('items.grant')
  grantBag(
    @Param('userId') id: string,
    @Body(new ZodValidationPipe(bagGrantBody)) body: { code: string; days: number | null; reason: string },
    @CurrentAdmin() admin: AdminContext,
  ) {
    return this.catalog.grantBagItem(pathUuid(id), body, admin);
  }

  @Post('users/:userId/bag/revoke')
  @HttpCode(200)
  @RequireCapability('items.grant')
  revokeBag(
    @Param('userId') id: string,
    @Body(new ZodValidationPipe(bagRevokeBody)) body: { code: string; reason: string },
    @CurrentAdmin() admin: AdminContext,
  ) {
    return this.catalog.revokeBagItem(pathUuid(id), body, admin);
  }

  // ---- agencies (§10.60.2) --------------------------------------------------------------------------------------

  @Get('agencies')
  @RequireCapability('agencies.view')
  async agenciesTable(
    @Query(new ZodValidationPipe(agenciesQuery)) q: AgenciesQuery,
    @CurrentAdmin() admin: AdminContext,
    @Res({ passthrough: true }) res: Response,
  ) {
    return sendTable(res, await this.agencies.table(q, admin));
  }

  @Post('agencies')
  @HttpCode(201)
  @RequireCapability('agencies.manage')
  createAgency(
    @Body(new ZodValidationPipe(createAgencyBody))
    body: { ownerUserId?: string; ownerEmail?: string; parentInviteCode?: string; reason: string },
    @CurrentAdmin() admin: AdminContext,
  ) {
    return this.agencies.create(body, admin);
  }

  @Get('agencies/:agencyId')
  @RequireCapability('agencies.view')
  agency(@Param('agencyId') id: string) {
    return this.agencies.detail(pathUuid(id));
  }

  @Post('agencies/:agencyId/suspend')
  @HttpCode(200)
  @RequireCapability('agencies.manage')
  suspendAgency(
    @Param('agencyId') id: string,
    @Body(new ZodValidationPipe(reasonBody)) body: { reason: string },
    @CurrentAdmin() admin: AdminContext,
  ) {
    return this.agencies.suspend(pathUuid(id), body.reason, admin);
  }

  @Post('agencies/:agencyId/reinstate')
  @HttpCode(200)
  @RequireCapability('agencies.manage')
  reinstateAgency(
    @Param('agencyId') id: string,
    @Body(new ZodValidationPipe(reasonBody)) body: { reason: string },
    @CurrentAdmin() admin: AdminContext,
  ) {
    return this.agencies.reinstate(pathUuid(id), body.reason, admin);
  }

  // ---- v1.70-social (D206, §10.65): «افتح وكالة» --------------------------------------------------------------

  @Get('agencies/:agencyId/applications/:applicationId')
  @RequireCapability('agencies.applications')
  agencyApplication(
    @Param('agencyId') id: string,
    @Param('applicationId') appId: string,
    @CurrentAdmin() admin: AdminContext,
  ) {
    return this.agencies.application(pathUuid(id), pathUuid(appId), admin);
  }

  @Get('agencies/:agencyId/applications/:applicationId/photos/:which')
  @RequireCapability('agencies.applications')
  async agencyApplicationPhoto(
    @Param('agencyId') id: string,
    @Param('applicationId') appId: string,
    @Param('which') which: string,
    @CurrentAdmin() admin: AdminContext,
    @Res() res: Response,
  ): Promise<void> {
    if (which !== 'photo' && which !== 'selfie') throw new AppException(ErrorCode.NOT_FOUND);
    const bytes = await this.agencies.applicationPhoto(pathUuid(id), pathUuid(appId), which, admin);
    res.setHeader('Content-Type', 'image/webp');
    res.setHeader('Cache-Control', 'private, no-store');
    res.setHeader('Content-Disposition', 'inline');
    res.setHeader('X-Content-Type-Options', 'nosniff');
    res.status(200).end(bytes);
  }

  @Post('agencies/:agencyId/probation/extend')
  @HttpCode(200)
  @RequireCapability('agencies.probation')
  extendAgencyProbation(
    @Param('agencyId') id: string,
    @Body(new ZodValidationPipe(agencyProbationExtendBody))
    body: { days: number; reason: string; totpCode: string },
    @CurrentAdmin() admin: AdminContext,
  ) {
    return this.agencies.extendProbation(pathUuid(id), body, admin);
  }

  @Post('agencies/:agencyId/close')
  @HttpCode(200)
  @RequireCapability('agencies.probation')
  closeAgency(
    @Param('agencyId') id: string,
    @Body(new ZodValidationPipe(reasonTotpBody)) body: { reason: string; totpCode: string },
    @CurrentAdmin() admin: AdminContext,
  ) {
    return this.agencies.close(pathUuid(id), body, admin);
  }

  /** v1.82-live (D295, §10.108): «حظر الوكالة» — the figures the confirmation shows. */
  @Get('agencies/:agencyId/ban')
  @RequireCapability('agencies.ban')
  agencyBanPreview(@Param('agencyId') id: string) {
    return this.agencies.banPreview(pathUuid(id));
  }

  /** v1.82-live (D295, §10.108): «حظر الوكالة — تفعيل صانع محتوى وهمي» (OWNER, code again, reason; idempotent). */
  @Post('agencies/:agencyId/ban')
  @HttpCode(200)
  @RequireCapability('agencies.ban')
  banAgency(
    @Param('agencyId') id: string,
    @Body(new ZodValidationPipe(agencyBanBody))
    body: { reason: string; totpCode: string; fakeCreatorUserIds: string[] },
    @CurrentAdmin() admin: AdminContext,
  ) {
    return this.agencies.ban(pathUuid(id), body, admin);
  }

  @Post('agencies/:agencyId/reopen')
  @HttpCode(200)
  @RequireCapability('agencies.probation')
  reopenAgency(
    @Param('agencyId') id: string,
    @Body(new ZodValidationPipe(reasonTotpBody)) body: { reason: string; totpCode: string },
    @CurrentAdmin() admin: AdminContext,
  ) {
    return this.agencies.reopen(pathUuid(id), body, admin);
  }

  @Get('agency-complaints')
  @RequireCapability('agencies.view')
  async complaints(
    @Query(new ZodValidationPipe(complaintsQuery)) q: ComplaintsQuery,
    @CurrentAdmin() admin: AdminContext,
    @Res({ passthrough: true }) res: Response,
  ) {
    return sendTable(res, await this.agencies.complaints(q, admin));
  }

  @Post('agency-complaints/:complaintId/resolve')
  @HttpCode(200)
  @RequireCapability('agencies.manage')
  resolveComplaint(
    @Param('complaintId') id: string,
    @Body(new ZodValidationPipe(resolveComplaintBody))
    body: { decision: 'release' | 'keep' | 'move'; toInviteCode?: string; note: string },
    @CurrentAdmin() admin: AdminContext,
  ) {
    return this.agencies.resolveComplaint(pathUuid(id), body, admin);
  }

  @Post('agency-evaluation')
  @HttpCode(200)
  @RequireCapability('agencies.manage')
  evaluate(
    @Body(new ZodValidationPipe(reasonBody)) body: { reason: string },
    @CurrentAdmin() admin: AdminContext,
  ) {
    return this.agencies.evaluate(body.reason, admin);
  }

  // ---- lives and hosts (§10.60.3) -------------------------------------------------------------------------------

  @Get('lives')
  @RequireCapability('lives.view')
  async livesNow(
    @Query(new ZodValidationPipe(livesQuery)) q: TableQuery,
    @CurrentAdmin() admin: AdminContext,
    @Res({ passthrough: true }) res: Response,
  ) {
    // v1.76-live (D286, §10.96.14): opening «بثوثي» is staff work — the shift goes on first, so it lists the lives.
    const mine = q as { assigned?: string; background?: string };
    if (mine.assigned === 'me' && mine.background !== 'true') await this.shifts.work(admin, 'my_lives');
    return sendTable(res, await this.lives.now(q, admin));
  }

  @Get('lives/:roomId')
  @RequireCapability('lives.view')
  live(@Param('roomId') id: string) {
    return this.lives.detail(pathUuid(id));
  }

  @Post('lives/:roomId/end')
  @HttpCode(200)
  @RequireCapability('lives.manage')
  async endLive(
    @Param('roomId') id: string,
    @Body(new ZodValidationPipe(reasonBody)) body: { reason: string },
    @CurrentAdmin() admin: AdminContext,
  ) {
    await this.shifts.work(admin, 'staff_tool');
    return this.lives.end(pathUuid(id), body.reason, admin);
  }

  @Get('live-hosts')
  @RequireCapability('lives.view')
  async hosts(
    @Query(new ZodValidationPipe(hostsQuery))
    q: TableQuery & { source?: 'ADMIN' | 'AGENCY' | 'IDENTITY' | 'CREATOR' },
    @CurrentAdmin() admin: AdminContext,
    @Res({ passthrough: true }) res: Response,
  ) {
    return sendTable(res, await this.lives.hosts(q, admin));
  }

  @Post('live-hosts/grant')
  @HttpCode(200)
  @RequireCapability('lives.manage')
  grantHost(
    @Body(new ZodValidationPipe(hostBody)) body: { username: string; reason: string },
    @CurrentAdmin() admin: AdminContext,
  ) {
    return this.lives.grantHost(body.username, body.reason, admin);
  }

  @Post('live-hosts/revoke')
  @HttpCode(200)
  @RequireCapability('lives.manage')
  revokeHost(
    @Body(new ZodValidationPipe(hostBody)) body: { username: string; reason: string },
    @CurrentAdmin() admin: AdminContext,
  ) {
    return this.lives.revokeHost(body.username, body.reason, admin);
  }

  // ---- gifts and items (§10.60.4) -------------------------------------------------------------------------------

  @Get('gifts')
  @RequireCapability('catalog.view')
  gifts() {
    return this.catalog.gifts();
  }

  @Post('gifts')
  @HttpCode(201)
  @RequireCapability('catalog.manage')
  createGift(
    @Body(new ZodValidationPipe(createGiftBody)) body: GiftBody & { code: string },
    @CurrentAdmin() admin: AdminContext,
  ) {
    const { code, ...rest } = body;
    return this.catalog.createGift(code, rest, admin);
  }

  @Patch('gifts/:code')
  @RequireCapability('catalog.manage')
  updateGift(
    @Param('code') code: string,
    @Body(new ZodValidationPipe(updateGiftBody)) body: GiftBody,
    @CurrentAdmin() admin: AdminContext,
  ) {
    return this.catalog.updateGift(giftCode(code), body, admin);
  }

  @Post('gifts/:code/enable')
  @HttpCode(200)
  @RequireCapability('catalog.manage')
  enableGift(
    @Param('code') code: string,
    @Body(new ZodValidationPipe(reasonBody)) body: { reason: string },
    @CurrentAdmin() admin: AdminContext,
  ) {
    return this.catalog.setGiftEnabled(giftCode(code), true, body.reason, admin);
  }

  // ---- v1.71-social (D207, §10.66): gift categories and the gift's files ----------------------------------------

  @Get('gift-categories')
  @RequireCapability('catalog.view')
  giftCategories() {
    return this.catalog.giftCategories();
  }

  @Post('gift-categories')
  @HttpCode(201)
  @RequireCapability('gifts.categories')
  createGiftCategory(
    @Body(new ZodValidationPipe(createGiftCategoryBody))
    body: GiftCategoryInput & { code: string; reason: string },
    @CurrentAdmin() admin: AdminContext,
  ) {
    const { code, ...rest } = body;
    return this.catalog.createGiftCategory(code, rest, admin);
  }

  @Patch('gift-categories/:code')
  @RequireCapability('gifts.categories')
  updateGiftCategory(
    @Param('code') code: string,
    @Body(new ZodValidationPipe(updateGiftCategoryBody)) body: GiftCategoryInput & { reason: string },
    @CurrentAdmin() admin: AdminContext,
  ) {
    return this.catalog.updateGiftCategory(categoryCode(code), body, admin);
  }

  @Post('gift-categories/:code/enable')
  @HttpCode(200)
  @RequireCapability('gifts.categories')
  enableGiftCategory(
    @Param('code') code: string,
    @Body(new ZodValidationPipe(reasonBody)) body: { reason: string },
    @CurrentAdmin() admin: AdminContext,
  ) {
    return this.catalog.setGiftCategoryEnabled(categoryCode(code), true, body.reason, admin);
  }

  @Post('gift-categories/:code/disable')
  @HttpCode(200)
  @RequireCapability('gifts.categories')
  disableGiftCategory(
    @Param('code') code: string,
    @Body(new ZodValidationPipe(reasonBody)) body: { reason: string },
    @CurrentAdmin() admin: AdminContext,
  ) {
    return this.catalog.setGiftCategoryEnabled(categoryCode(code), false, body.reason, admin);
  }

  @Post('gift-categories/:code/remove')
  @HttpCode(200)
  @RequireCapability('gifts.categories')
  removeGiftCategory(
    @Param('code') code: string,
    @Body(new ZodValidationPipe(removeGiftCategoryBody)) body: { moveTo?: string; reason: string },
    @CurrentAdmin() admin: AdminContext,
  ) {
    return this.catalog.removeGiftCategory(categoryCode(code), body.moveTo ?? null, body.reason, admin);
  }

  /**
   * One file of a gift (image, SVGA / MP4 effect, MP3 sound) or a category's icon, the raw bytes as the body
   * (`application/octet-stream`, at most 26 MB). catalog.manage; an icon gifts.categories.
   */
  @Post('gift-uploads')
  @HttpCode(201)
  @RequireCapability('catalog.manage')
  uploadGiftFile(
    @Query(new ZodValidationPipe(giftUploadQuery)) q: { kind: GiftUploadKind; code: string },
    @Req() req: Request,
    @CurrentAdmin() admin: AdminContext,
  ) {
    if (q.kind === 'icon' && !can(admin.roles, 'gifts.categories'))
      throw new AppException(ErrorCode.AUTH_FORBIDDEN);
    return this.catalog.upload(q.kind, q.code, req.body);
  }

  /** The bytes of an uploaded gift file / category icon, for the panel's preview (same origin; not cached). */
  @Get('gift-files')
  @RequireCapability('catalog.view')
  async giftFile(
    @Query(new ZodValidationPipe(giftFileQuery)) q: { key: string },
    @Res({ passthrough: false }) res: Response,
  ): Promise<void> {
    const file = await this.catalog.file(q.key);
    res.status(200).type(file.contentType).setHeader('Content-Length', String(file.body.length));
    res.end(file.body);
  }

  @Post('gifts/:code/disable')
  @HttpCode(200)
  @RequireCapability('catalog.manage')
  disableGift(
    @Param('code') code: string,
    @Body(new ZodValidationPipe(reasonBody)) body: { reason: string },
    @CurrentAdmin() admin: AdminContext,
  ) {
    return this.catalog.setGiftEnabled(giftCode(code), false, body.reason, admin);
  }

  @Get('bag-items')
  @RequireCapability('catalog.view')
  bagItems() {
    return this.catalog.bagItems();
  }

  @Get('banners')
  @RequireCapability('catalog.view')
  banners() {
    return this.catalog.banners();
  }

  /**
   * v1.59-live (D248, §10.90): a banner's picture, the raw bytes as the body (`application/octet-stream`, JPEG / PNG /
   * WebP, at most 15 MiB), cover-cropped around the centre to the placement's shape (home, tasks, wallet 1 500 × 500;
   * room 600 × 800; hub_card 720 × 805). Not shown anywhere until `POST /admin/banners` names it (within 24 hours).
   */
  @Post('banner-uploads')
  @HttpCode(201)
  @RequireCapability('catalog.manage')
  uploadBannerPicture(
    @Query(new ZodValidationPipe(bannerUploadQuery)) q: { placement: BannerPlacementParam },
    @Req() req: Request,
    @CurrentAdmin() admin: AdminContext,
  ) {
    return this.catalog.uploadBannerPicture(q.placement, req.body, admin);
  }

  /** v1.59-live (D248, §10.90): adds a banner on an uploaded picture (`banner.add`, via panel, with the reason). */
  /**
   * v1.97-social (D303, §10.114.6): a HOME banner's video, the raw bytes (`application/octet-stream`: MP4 / MOV, H.264 or
   * HEVC, 1–30 s, at most 30 MiB), stored unchanged (muted in the app). `POST /admin/banners` names it as `videoMediaId`
   * beside its poster picture (`mediaId`) within 24 hours.
   */
  @Post('banner-video-uploads')
  @HttpCode(201)
  @RequireCapability('catalog.manage')
  uploadBannerVideo(@Req() req: Request, @CurrentAdmin() admin: AdminContext) {
    return this.catalog.uploadBannerVideo(req.body, admin);
  }

  @Post('banners')
  @HttpCode(201)
  @RequireCapability('catalog.manage')
  createBanner(
    @Body(new ZodValidationPipe(createBannerBody))
    body: Parameters<AdminCatalogService['createBanner']>[0],
    @CurrentAdmin() admin: AdminContext,
  ) {
    return this.catalog.createBanner(body, admin);
  }

  @Post('banners/:bannerId/enable')
  @HttpCode(200)
  @RequireCapability('catalog.manage')
  enableBanner(
    @Param('bannerId') id: string,
    @Body(new ZodValidationPipe(reasonBody)) body: { reason: string },
    @CurrentAdmin() admin: AdminContext,
  ) {
    return this.catalog.setBannerEnabled(pathUuid(id), true, body.reason, admin);
  }

  @Post('banners/:bannerId/disable')
  @HttpCode(200)
  @RequireCapability('catalog.manage')
  disableBanner(
    @Param('bannerId') id: string,
    @Body(new ZodValidationPipe(reasonBody)) body: { reason: string },
    @CurrentAdmin() admin: AdminContext,
  ) {
    return this.catalog.setBannerEnabled(pathUuid(id), false, body.reason, admin);
  }

  @Post('banners/:bannerId/remove')
  @HttpCode(200)
  @RequireCapability('catalog.manage')
  removeBanner(
    @Param('bannerId') id: string,
    @Body(new ZodValidationPipe(reasonBody)) body: { reason: string },
    @CurrentAdmin() admin: AdminContext,
  ) {
    return this.catalog.removeBanner(pathUuid(id), body.reason, admin);
  }

  @Get('events')
  @RequireCapability('catalog.view')
  events() {
    return this.catalog.events();
  }

  @Post('events')
  @HttpCode(201)
  @RequireCapability('events.manage')
  createEvent(
    @Body(new ZodValidationPipe(createEventBody))
    body: Parameters<AdminCatalogService['createEvent']>[0] & { metric: EventMetric },
    @CurrentAdmin() admin: AdminContext,
  ) {
    return this.catalog.createEvent(body, admin);
  }

  // ---- v1.97-social (D303, §10.114.7): gift events -----------------------------------------------------------------

  @Get('event-options')
  @RequireCapability('events.manage')
  eventOptions() {
    return this.giftEvents.options();
  }

  @Post('gift-events')
  @HttpCode(201)
  @RequireCapability('events.manage')
  createGiftEvent(
    @Body(new ZodValidationPipe(giftEventInputSchema)) body: GiftEventInput,
    @CurrentAdmin() admin: AdminContext,
  ) {
    return this.giftEvents.create(body, admin);
  }

  /** D303 follow-ups (§10.114.9): one piece of an event's art, checked against the published spec. */
  @Post('event-uploads')
  @HttpCode(201)
  @RequireCapability('events.manage')
  uploadEventMedia(
    @Query(new ZodValidationPipe(eventUploadQuery)) q: { kind: EventMediaKind },
    @Req() req: Request,
    @CurrentAdmin() admin: AdminContext,
  ) {
    return this.giftEvents.upload(q.kind, req.body, admin);
  }

  /** D303 follow-up: a reusable event badge «وسام فعالية». */
  @Post('event-badges')
  @HttpCode(201)
  @RequireCapability('events.manage')
  createEventBadge(
    @Body(new ZodValidationPipe(eventBadgeInputSchema)) body: EventBadgeInput,
    @CurrentAdmin() admin: AdminContext,
  ) {
    return this.giftEvents.createBadge(body, admin);
  }

  @Get('gift-events/:eventId')
  @RequireCapability('catalog.view')
  giftEvent(@Param('eventId') id: string) {
    return this.giftEvents.get(pathUuid(id));
  }

  @Put('gift-events/:eventId')
  @RequireCapability('events.manage')
  updateGiftEvent(
    @Param('eventId') id: string,
    @Body(new ZodValidationPipe(giftEventInputSchema)) body: GiftEventInput,
    @CurrentAdmin() admin: AdminContext,
  ) {
    return this.giftEvents.update(pathUuid(id), body, admin);
  }

  // v1.97-social (D303): end / hold / release need `events.manage` (OWNER, as `catalog.manage` before).
  @Post('events/:eventId/:command')
  @HttpCode(200)
  @RequireCapability('events.manage')
  changeEvent(
    @Param('eventId') id: string,
    @Param('command') command: string,
    @Body(new ZodValidationPipe(reasonBody)) body: { reason: string },
    @CurrentAdmin() admin: AdminContext,
  ) {
    if (command !== 'end' && command !== 'hold' && command !== 'release')
      throw new AppException(ErrorCode.NOT_FOUND);
    return this.catalog.changeEvent(pathUuid(id), command, body.reason, admin);
  }

  // ---- money (§10.60.5) -----------------------------------------------------------------------------------------

  // D275: the top-up records and their CSV (audited) are `recharge.topups.view` (the moderator too, owner «نعم»).
  @Get('finance/recharge-topups')
  @RequireCapability('recharge.topups.view')
  async rechargeTopups(
    @Query(new ZodValidationPipe(rechargeTopupsQuery)) q: RangeQuery,
    @CurrentAdmin() admin: AdminContext,
    @Res({ passthrough: true }) res: Response,
  ) {
    return sendTable(res, (await this.money.rechargeTopups(q, admin)) as never);
  }

  @Get('finance/card-orders')
  @RequireCapability('recharge.topups.view')
  async cardOrders(
    @Query(new ZodValidationPipe(cardOrdersQuery))
    q: RangeQuery & { status?: 'PENDING' | 'AWAITING_FUNDS' | 'PAID' | 'EXPIRED' | 'FAILED' },
    @CurrentAdmin() admin: AdminContext,
    @Res({ passthrough: true }) res: Response,
  ) {
    return sendTable(res, await this.money.cardOrders(q, admin));
  }

  @Post('finance/card-orders/:orderId/refund')
  @HttpCode(200)
  @RequireCapability('finance.refund')
  refund(
    @Param('orderId') id: string,
    @Body(new ZodValidationPipe(refundBody)) body: { reason: string; totpCode: string },
    @CurrentAdmin() admin: AdminContext,
  ) {
    return this.money.refund(pathUuid(id), body, admin);
  }

  @Get('finance/cases')
  @RequireCapability('finance.view')
  async cases(
    @Query(new ZodValidationPipe(casesQuery)) q: TableQuery & { status?: 'OPEN' | 'CLOSED' },
    @CurrentAdmin() admin: AdminContext,
    @Res({ passthrough: true }) res: Response,
  ) {
    return sendTable(res, await this.money.cases(q, admin));
  }

  @Post('finance/cases/:caseId/close')
  @HttpCode(200)
  @RequireCapability('finance.refund')
  closeCase(
    @Param('caseId') id: string,
    @Body(new ZodValidationPipe(closeCaseBody)) body: { note: string },
    @CurrentAdmin() admin: AdminContext,
  ) {
    return this.money.closeCase(pathUuid(id), body.note, admin);
  }

  @Get('finance/report')
  @RequireCapability('finance.view')
  async report(
    @Query(new ZodValidationPipe(reportQuery))
    q: { granularity: 'day' | 'month'; from: string; to: string; format: 'json' | 'csv' },
    @CurrentAdmin() admin: AdminContext,
    @Res({ passthrough: true }) res: Response,
  ) {
    return sendTable(res, (await this.money.reportTable(q, admin)) as never);
  }

  // ---- audit and team (§10.60.6) --------------------------------------------------------------------------------

  @Get('audit')
  @RequireCapability('audit.view')
  async audit(
    @Query(new ZodValidationPipe(auditQuery)) q: AuditQuery,
    @CurrentAdmin() admin: AdminContext,
    @Res({ passthrough: true }) res: Response,
  ) {
    return sendTable(res, await this.team.auditTable(q, admin));
  }

  @Get('audit/actions')
  @RequireCapability('audit.view')
  auditActions() {
    return this.team.actions();
  }

  @Get('team')
  @RequireCapability('team.manage')
  teamList() {
    return this.team.team();
  }

  @Post('team/grant')
  @HttpCode(200)
  @TEAM_LIMIT
  @RequireCapability('team.manage')
  teamGrant(
    @Body(new ZodValidationPipe(teamGrantBody)) body: TeamGrantBody,
    @CurrentAdmin() admin: AdminContext,
  ) {
    return this.team.grant(body, admin);
  }

  @Post('team/:userId/revoke')
  @HttpCode(200)
  @TEAM_LIMIT
  @RequireCapability('team.manage')
  teamRevoke(
    @Param('userId') id: string,
    @Body(new ZodValidationPipe(teamRevokeBody)) body: { role: PanelRole; reason: string; totpCode: string },
    @CurrentAdmin() admin: AdminContext,
  ) {
    return this.team.revoke(pathUuid(id), body, admin);
  }

  /** v1.72-live (D283, §10.96.11): the regions and their countries. */
  @Get('team/regions')
  @RequireCapability('team.manage')
  teamRegionCatalog() {
    return this.team.regionCatalog();
  }

  /** v1.72-live (D283, §10.96.11): a MODERATION / SUPPORT staff member's regions (OWNER, code + reason, audited). */
  @Put('team/:userId/regions')
  @HttpCode(200)
  @TEAM_LIMIT
  @RequireCapability('team.manage')
  teamRegions(
    @Param('userId') id: string,
    @Body(new ZodValidationPipe(teamRegionsBody)) body: TeamRegionsBody,
    @CurrentAdmin() admin: AdminContext,
  ) {
    return this.team.setRegions(pathUuid(id), body, admin);
  }

  @Post('team/:userId/reset-2fa')
  @HttpCode(200)
  @TEAM_LIMIT
  @RequireCapability('team.manage')
  teamReset(
    @Param('userId') id: string,
    @Body(new ZodValidationPipe(teamResetBody)) body: { reason: string; totpCode: string },
    @CurrentAdmin() admin: AdminContext,
  ) {
    return this.team.resetTotp(pathUuid(id), body, admin);
  }

  // ---- programs, special usernames, waitlist (§10.60.7) ---------------------------------------------------------

  @Get('programs/tasks')
  @RequireCapability('programs.view')
  tasks() {
    return this.programs.tasks();
  }

  @Get('programs/levels')
  @RequireCapability('programs.view')
  levels() {
    return this.programs.levels();
  }

  @Get('special-usernames')
  @RequireCapability('programs.view')
  async specialUsernames(
    @Query(new ZodValidationPipe(specialUsernamesQuery))
    q: TableQuery & { status?: 'ACTIVE' | 'GRACE' | 'ENDED'; source?: string },
    @CurrentAdmin() admin: AdminContext,
    @Res({ passthrough: true }) res: Response,
  ) {
    return sendTable(res, await this.programs.specialUsernames(q, admin));
  }

  @Get('waitlist')
  @RequireCapability('waitlist.view')
  async waitlist(
    @Query(new ZodValidationPipe(waitlistQuery)) q: TableQuery & { locale?: 'ar' | 'en' },
    @CurrentAdmin() admin: AdminContext,
    @Res({ passthrough: true }) res: Response,
  ) {
    return sendTable(res, (await this.programs.waitlist(q, admin)) as never);
  }
}
