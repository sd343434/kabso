import {
  Body,
  Controller,
  Delete,
  Get,
  Headers,
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
import type { Response } from 'express';
import type { AppRequest } from '../../common/http/request-context.js';
import { byIp, byUserId, RateLimit, SkipRateLimit } from '../../common/rate-limit/rate-limit.decorator.js';
import { ZodValidationPipe } from '../../common/validation/zod-validation.pipe.js';
import type { AdminContext } from '../admin-panel/admin-auth.service.js';
import { pathUuid } from '../admin-panel/admin-panel.schemas.js';
import { AdminSessionGuard, CurrentAdmin, RequireCapability } from '../admin-panel/admin-session.guard.js';
import {
  CurrentStaff,
  NotStaffWork,
  StaffAppGuard,
  StaffCapability,
} from '../admin-panel/staff-app.guard.js';
import { Public } from '../auth/public.decorator.js';
import {
  agentsQuery,
  linkBody,
  listQuery,
  mediaQuery,
  messagesQuery,
  noteBody,
  quickReplyBody,
  quickReplyPatch,
  sendBody,
  settingsBody,
  templatesQuery,
  transferBody,
  type AgentsQuery,
  type ListQuery,
  type MediaQuery,
  type MessagesQuery,
  type SendBody,
  type TransferBody,
} from './whatsapp.schemas.js';
import { WhatsAppWebhookService } from './whatsapp-webhook.service.js';
import { WhatsAppService } from './whatsapp.service.js';

/** The public webhook path (app.setup keeps its body raw: the signature is over the exact bytes). */
export const WHATSAPP_WEBHOOK_PATH = '/api/v1/webhooks/whatsapp';
/** The outbound media upload paths (raw bytes, `application/octet-stream`; app.setup). */
export const WHATSAPP_MEDIA_UPLOAD_PATH =
  /^\/api\/v1\/(staff|admin)\/whatsapp\/conversations\/[0-9a-fA-F-]{36}\/media$/;

function sendMedia(res: Response, m: { bytes: Buffer; mime: string; filename: string | null }): void {
  res.setHeader('Content-Type', m.mime);
  res.setHeader('Cache-Control', 'private, no-store');
  res.setHeader('X-Content-Type-Options', 'nosniff');
  // Never rendered inline by a browser on the API origin (a document could carry script).
  const safe = (m.filename ?? 'file').replace(/[^A-Za-z0-9._-]/g, '_').slice(0, 100);
  res.setHeader('Content-Disposition', `attachment; filename="${safe}"`);
  res.send(m.bytes);
}

const STAFF_LIMIT = {
  bucket: 'staff:user',
  rule: 'staffAppUser',
  key: byUserId,
  replacesDefault: true,
} as const;

/**
 * v1.116-social (D355, CONVENTIONS §10.151): «واتساب» in the staff's app — the staff member's own account (bearer);
 * the role and the capability are checked on every request (StaffAppGuard), staff work switches the shift on.
 * v1.120-social (D360, §10.155): reading needs `support.whatsapp.view` (VIEW and above), every action
 * `support.whatsapp` (REPLY and above), the quick-reply edits and the settings `support.whatsapp.manage` (MANAGE) —
 * the staff member's WhatsApp level.
 */
@Controller('staff/whatsapp')
@RateLimit(STAFF_LIMIT)
export class StaffWhatsAppController {
  constructor(private readonly wa: WhatsAppService) {}

  @Get('summary')
  @UseGuards(StaffAppGuard)
  @StaffCapability('support.whatsapp.view')
  @NotStaffWork()
  summary(@CurrentStaff() ctx: AdminContext) {
    return this.wa.summary(ctx);
  }

  @Get('conversations')
  @UseGuards(StaffAppGuard)
  @StaffCapability('support.whatsapp.view')
  list(@CurrentStaff() ctx: AdminContext, @Query(new ZodValidationPipe(listQuery)) q: ListQuery) {
    return this.wa.list(ctx, q);
  }

  @Get('conversations/:id')
  @UseGuards(StaffAppGuard)
  @StaffCapability('support.whatsapp.view')
  get(@CurrentStaff() ctx: AdminContext, @Param('id') id: string) {
    return this.wa.get(ctx, pathUuid(id));
  }

  @Get('conversations/:id/messages')
  @UseGuards(StaffAppGuard)
  @StaffCapability('support.whatsapp.view')
  messages(
    @CurrentStaff() ctx: AdminContext,
    @Param('id') id: string,
    @Query(new ZodValidationPipe(messagesQuery)) q: MessagesQuery,
  ) {
    return this.wa.messages(ctx, pathUuid(id), q);
  }

  @Post('conversations/:id/messages')
  @HttpCode(201)
  @UseGuards(StaffAppGuard)
  @StaffCapability('support.whatsapp')
  send(
    @CurrentStaff() ctx: AdminContext,
    @Param('id') id: string,
    @Body(new ZodValidationPipe(sendBody)) body: SendBody,
  ) {
    return body.type === 'TEXT'
      ? this.wa.sendText(ctx, pathUuid(id), body.text)
      : this.wa.sendTemplate(ctx, pathUuid(id), body.template);
  }

  @Post('conversations/:id/media')
  @HttpCode(201)
  @UseGuards(StaffAppGuard)
  @StaffCapability('support.whatsapp')
  sendMedia(
    @CurrentStaff() ctx: AdminContext,
    @Param('id') id: string,
    @Query(new ZodValidationPipe(mediaQuery)) q: MediaQuery,
    @Req() req: AppRequest,
  ) {
    return this.wa.sendMedia(ctx, pathUuid(id), req.body, q);
  }

  @Get('messages/:messageId/media')
  @UseGuards(StaffAppGuard)
  @StaffCapability('support.whatsapp.view')
  async media(@Param('messageId') id: string, @Res() res: Response): Promise<void> {
    const m = await this.wa.media(pathUuid(id));
    sendMedia(res, m);
  }

  @Post('conversations/:id/read')
  @HttpCode(200)
  @UseGuards(StaffAppGuard)
  @StaffCapability('support.whatsapp')
  read(@CurrentStaff() ctx: AdminContext, @Param('id') id: string) {
    return this.wa.markRead(ctx, pathUuid(id));
  }

  @Post('conversations/:id/claim')
  @HttpCode(200)
  @UseGuards(StaffAppGuard)
  @StaffCapability('support.whatsapp')
  claim(@CurrentStaff() ctx: AdminContext, @Param('id') id: string) {
    return this.wa.claim(ctx, pathUuid(id));
  }

  @Post('conversations/:id/release')
  @HttpCode(200)
  @UseGuards(StaffAppGuard)
  @StaffCapability('support.whatsapp')
  release(@CurrentStaff() ctx: AdminContext, @Param('id') id: string) {
    return this.wa.release(ctx, pathUuid(id));
  }

  @Post('conversations/:id/transfer')
  @HttpCode(200)
  @UseGuards(StaffAppGuard)
  @StaffCapability('support.whatsapp')
  transfer(
    @CurrentStaff() ctx: AdminContext,
    @Param('id') id: string,
    @Body(new ZodValidationPipe(transferBody)) body: TransferBody,
  ) {
    return this.wa.transfer(ctx, pathUuid(id), body);
  }

  @Post('conversations/:id/close')
  @HttpCode(200)
  @UseGuards(StaffAppGuard)
  @StaffCapability('support.whatsapp')
  close(@CurrentStaff() ctx: AdminContext, @Param('id') id: string) {
    return this.wa.close(ctx, pathUuid(id));
  }

  @Post('conversations/:id/reopen')
  @HttpCode(200)
  @UseGuards(StaffAppGuard)
  @StaffCapability('support.whatsapp')
  reopen(@CurrentStaff() ctx: AdminContext, @Param('id') id: string) {
    return this.wa.reopen(ctx, pathUuid(id));
  }

  @Get('conversations/:id/assignments')
  @UseGuards(StaffAppGuard)
  @StaffCapability('support.whatsapp.view')
  assignments(@Param('id') id: string) {
    return this.wa.assignments(pathUuid(id));
  }

  @Get('conversations/:id/notes')
  @UseGuards(StaffAppGuard)
  @StaffCapability('support.whatsapp.view')
  notes(@Param('id') id: string) {
    return this.wa.notes(pathUuid(id));
  }

  @Post('conversations/:id/notes')
  @HttpCode(201)
  @UseGuards(StaffAppGuard)
  @StaffCapability('support.whatsapp')
  addNote(
    @CurrentStaff() ctx: AdminContext,
    @Param('id') id: string,
    @Body(new ZodValidationPipe(noteBody)) body: { body: string },
  ) {
    return this.wa.addNote(ctx, pathUuid(id), body.body);
  }

  @Post('conversations/:id/link')
  @HttpCode(200)
  @UseGuards(StaffAppGuard)
  @StaffCapability('support.whatsapp')
  link(
    @CurrentStaff() ctx: AdminContext,
    @Param('id') id: string,
    @Body(new ZodValidationPipe(linkBody)) body: { username: string },
  ) {
    return this.wa.link(ctx, pathUuid(id), body.username);
  }

  @Delete('conversations/:id/link')
  @HttpCode(200)
  @UseGuards(StaffAppGuard)
  @StaffCapability('support.whatsapp')
  unlink(@CurrentStaff() ctx: AdminContext, @Param('id') id: string) {
    return this.wa.unlink(ctx, pathUuid(id));
  }

  @Get('templates')
  @UseGuards(StaffAppGuard)
  @StaffCapability('support.whatsapp')
  async templates(@Query(new ZodValidationPipe(templatesQuery)) q: { refresh: boolean }) {
    return { data: await this.wa.templates(q.refresh) };
  }

  @Get('agents')
  @UseGuards(StaffAppGuard)
  @StaffCapability('support.whatsapp')
  agents(@Query(new ZodValidationPipe(agentsQuery)) q: AgentsQuery) {
    return this.wa.agents(q.department);
  }

  @Get('quick-replies')
  @UseGuards(StaffAppGuard)
  @StaffCapability('support.whatsapp')
  quickReplies() {
    return this.wa.quickReplies();
  }

  @Post('quick-replies')
  @HttpCode(201)
  @UseGuards(StaffAppGuard)
  @StaffCapability('support.whatsapp.manage')
  createQuickReply(
    @CurrentStaff() ctx: AdminContext,
    @Body(new ZodValidationPipe(quickReplyBody)) body: { title: string; body: string },
  ) {
    return this.wa.createQuickReply(ctx, body);
  }

  @Patch('quick-replies/:replyId')
  @UseGuards(StaffAppGuard)
  @StaffCapability('support.whatsapp.manage')
  updateQuickReply(
    @CurrentStaff() ctx: AdminContext,
    @Param('replyId') id: string,
    @Body(new ZodValidationPipe(quickReplyPatch)) body: { title?: string; body?: string },
  ) {
    return this.wa.updateQuickReply(ctx, pathUuid(id), body);
  }

  @Delete('quick-replies/:replyId')
  @HttpCode(204)
  @UseGuards(StaffAppGuard)
  @StaffCapability('support.whatsapp.manage')
  async deleteQuickReply(@CurrentStaff() ctx: AdminContext, @Param('replyId') id: string): Promise<void> {
    await this.wa.deleteQuickReply(ctx, pathUuid(id));
  }

  @Get('me/settings')
  @UseGuards(StaffAppGuard)
  @StaffCapability('support.whatsapp.view')
  @NotStaffWork()
  mySettings(@CurrentStaff() ctx: AdminContext) {
    return this.wa.mySettings(ctx);
  }

  @Put('me/settings')
  @UseGuards(StaffAppGuard)
  @StaffCapability('support.whatsapp.view')
  @NotStaffWork()
  setMySettings(
    @CurrentStaff() ctx: AdminContext,
    @Body(new ZodValidationPipe(settingsBody)) body: { pushMuted: boolean },
  ) {
    return this.wa.setMySettings(ctx, body.pushMuted);
  }
}

/** v1.116-social (D355, CONVENTIONS §10.151): «واتساب» in the panel — the same rules with the panel's cookie session. */
@Public()
@Controller('admin/whatsapp')
@RateLimit({ bucket: 'admin:ip', rule: 'adminIp', key: byIp, replacesDefault: true })
@UseGuards(AdminSessionGuard)
export class AdminWhatsAppController {
  constructor(private readonly wa: WhatsAppService) {}

  @Get('summary')
  @RequireCapability('support.whatsapp.view')
  summary(@CurrentAdmin() ctx: AdminContext) {
    return this.wa.summary(ctx);
  }

  @Get('conversations')
  @RequireCapability('support.whatsapp.view')
  list(@CurrentAdmin() ctx: AdminContext, @Query(new ZodValidationPipe(listQuery)) q: ListQuery) {
    return this.wa.list(ctx, q);
  }

  @Get('conversations/:id')
  @RequireCapability('support.whatsapp.view')
  get(@CurrentAdmin() ctx: AdminContext, @Param('id') id: string) {
    return this.wa.get(ctx, pathUuid(id));
  }

  @Get('conversations/:id/messages')
  @RequireCapability('support.whatsapp.view')
  messages(
    @CurrentAdmin() ctx: AdminContext,
    @Param('id') id: string,
    @Query(new ZodValidationPipe(messagesQuery)) q: MessagesQuery,
  ) {
    return this.wa.messages(ctx, pathUuid(id), q);
  }

  @Post('conversations/:id/messages')
  @HttpCode(201)
  @RequireCapability('support.whatsapp')
  send(
    @CurrentAdmin() ctx: AdminContext,
    @Param('id') id: string,
    @Body(new ZodValidationPipe(sendBody)) body: SendBody,
  ) {
    return body.type === 'TEXT'
      ? this.wa.sendText(ctx, pathUuid(id), body.text)
      : this.wa.sendTemplate(ctx, pathUuid(id), body.template);
  }

  @Post('conversations/:id/media')
  @HttpCode(201)
  @RequireCapability('support.whatsapp')
  sendMedia(
    @CurrentAdmin() ctx: AdminContext,
    @Param('id') id: string,
    @Query(new ZodValidationPipe(mediaQuery)) q: MediaQuery,
    @Req() req: AppRequest,
  ) {
    return this.wa.sendMedia(ctx, pathUuid(id), req.body, q);
  }

  @Get('messages/:messageId/media')
  @RequireCapability('support.whatsapp.view')
  async media(@Param('messageId') id: string, @Res() res: Response): Promise<void> {
    const m = await this.wa.media(pathUuid(id));
    sendMedia(res, m);
  }

  @Post('conversations/:id/read')
  @HttpCode(200)
  @RequireCapability('support.whatsapp')
  read(@CurrentAdmin() ctx: AdminContext, @Param('id') id: string) {
    return this.wa.markRead(ctx, pathUuid(id));
  }

  @Post('conversations/:id/claim')
  @HttpCode(200)
  @RequireCapability('support.whatsapp')
  claim(@CurrentAdmin() ctx: AdminContext, @Param('id') id: string) {
    return this.wa.claim(ctx, pathUuid(id));
  }

  @Post('conversations/:id/release')
  @HttpCode(200)
  @RequireCapability('support.whatsapp')
  release(@CurrentAdmin() ctx: AdminContext, @Param('id') id: string) {
    return this.wa.release(ctx, pathUuid(id));
  }

  @Post('conversations/:id/transfer')
  @HttpCode(200)
  @RequireCapability('support.whatsapp')
  transfer(
    @CurrentAdmin() ctx: AdminContext,
    @Param('id') id: string,
    @Body(new ZodValidationPipe(transferBody)) body: TransferBody,
  ) {
    return this.wa.transfer(ctx, pathUuid(id), body);
  }

  @Post('conversations/:id/close')
  @HttpCode(200)
  @RequireCapability('support.whatsapp')
  close(@CurrentAdmin() ctx: AdminContext, @Param('id') id: string) {
    return this.wa.close(ctx, pathUuid(id));
  }

  @Post('conversations/:id/reopen')
  @HttpCode(200)
  @RequireCapability('support.whatsapp')
  reopen(@CurrentAdmin() ctx: AdminContext, @Param('id') id: string) {
    return this.wa.reopen(ctx, pathUuid(id));
  }

  @Get('conversations/:id/assignments')
  @RequireCapability('support.whatsapp.view')
  assignments(@Param('id') id: string) {
    return this.wa.assignments(pathUuid(id));
  }

  @Get('conversations/:id/notes')
  @RequireCapability('support.whatsapp.view')
  notes(@Param('id') id: string) {
    return this.wa.notes(pathUuid(id));
  }

  @Post('conversations/:id/notes')
  @HttpCode(201)
  @RequireCapability('support.whatsapp')
  addNote(
    @CurrentAdmin() ctx: AdminContext,
    @Param('id') id: string,
    @Body(new ZodValidationPipe(noteBody)) body: { body: string },
  ) {
    return this.wa.addNote(ctx, pathUuid(id), body.body);
  }

  @Post('conversations/:id/link')
  @HttpCode(200)
  @RequireCapability('support.whatsapp')
  link(
    @CurrentAdmin() ctx: AdminContext,
    @Param('id') id: string,
    @Body(new ZodValidationPipe(linkBody)) body: { username: string },
  ) {
    return this.wa.link(ctx, pathUuid(id), body.username);
  }

  @Delete('conversations/:id/link')
  @HttpCode(200)
  @RequireCapability('support.whatsapp')
  unlink(@CurrentAdmin() ctx: AdminContext, @Param('id') id: string) {
    return this.wa.unlink(ctx, pathUuid(id));
  }

  @Get('templates')
  @RequireCapability('support.whatsapp')
  async templates(@Query(new ZodValidationPipe(templatesQuery)) q: { refresh: boolean }) {
    return { data: await this.wa.templates(q.refresh) };
  }

  @Get('agents')
  @RequireCapability('support.whatsapp')
  agents(@Query(new ZodValidationPipe(agentsQuery)) q: AgentsQuery) {
    return this.wa.agents(q.department);
  }

  @Get('quick-replies')
  @RequireCapability('support.whatsapp')
  quickReplies() {
    return this.wa.quickReplies();
  }

  @Post('quick-replies')
  @HttpCode(201)
  @RequireCapability('support.whatsapp.manage')
  createQuickReply(
    @CurrentAdmin() ctx: AdminContext,
    @Body(new ZodValidationPipe(quickReplyBody)) body: { title: string; body: string },
  ) {
    return this.wa.createQuickReply(ctx, body);
  }

  @Patch('quick-replies/:replyId')
  @RequireCapability('support.whatsapp.manage')
  updateQuickReply(
    @CurrentAdmin() ctx: AdminContext,
    @Param('replyId') id: string,
    @Body(new ZodValidationPipe(quickReplyPatch)) body: { title?: string; body?: string },
  ) {
    return this.wa.updateQuickReply(ctx, pathUuid(id), body);
  }

  @Delete('quick-replies/:replyId')
  @HttpCode(204)
  @RequireCapability('support.whatsapp.manage')
  async deleteQuickReply(@CurrentAdmin() ctx: AdminContext, @Param('replyId') id: string): Promise<void> {
    await this.wa.deleteQuickReply(ctx, pathUuid(id));
  }

  @Get('me/settings')
  @RequireCapability('support.whatsapp.view')
  mySettings(@CurrentAdmin() ctx: AdminContext) {
    return this.wa.mySettings(ctx);
  }

  @Put('me/settings')
  @RequireCapability('support.whatsapp.view')
  setMySettings(
    @CurrentAdmin() ctx: AdminContext,
    @Body(new ZodValidationPipe(settingsBody)) body: { pushMuted: boolean },
  ) {
    return this.wa.setMySettings(ctx, body.pushMuted);
  }

  @Get('settings')
  @RequireCapability('support.whatsapp.manage')
  status() {
    return this.wa.status();
  }

  @Post('settings/test')
  @HttpCode(200)
  @RequireCapability('support.whatsapp.manage')
  test(@CurrentAdmin() ctx: AdminContext) {
    return this.wa.test(ctx);
  }
}

/** v1.116-social (D355, CONVENTIONS §10.151.3): Meta's webhook — public, no session; the signature is the check. */
@Public()
@SkipRateLimit()
@Controller('webhooks/whatsapp')
export class WhatsAppWebhookController {
  constructor(private readonly hook: WhatsAppWebhookService) {}

  @Get()
  verify(@Query() query: Record<string, unknown>, @Res() res: Response): void {
    const challenge = this.hook.verify(query);
    res.status(200).type('text/plain').send(challenge);
  }

  @Post()
  @HttpCode(200)
  receive(@Req() req: AppRequest, @Headers('x-hub-signature-256') signature: string | undefined) {
    return this.hook.receive(req.body, signature);
  }
}
