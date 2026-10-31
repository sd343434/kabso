import { Body, Controller, Get, HttpCode, Param, ParseUUIDPipe, Post, Query, Req, Res } from '@nestjs/common';
import type { Response } from 'express';
import type { AppRequest, AuthContext } from '../../common/http/request-context.js';
import { byUserId, RateLimit } from '../../common/rate-limit/rate-limit.decorator.js';
import { ZodValidationPipe } from '../../common/validation/zod-validation.pipe.js';
import { requestMeta } from '../auth/auth.controller.js';
import { CurrentAuth } from '../auth/current-auth.decorator.js';
import { Public } from '../auth/public.decorator.js';
import {
  acceptConsentsSchema,
  ConsentExempt,
  ConsentsService,
  type AcceptConsentsInput,
  type ConsentStatusDto,
} from './consents.service.js';
import {
  dataExportRequestSchema,
  DataExportsService,
  downloadQuerySchema,
  type DataExportDto,
  type DataExportLinkDto,
  type DataExportListDto,
  type DataExportRequestInput,
} from './data-exports.service.js';
import type { LegalDocumentDto } from './legal.js';

/** D198 (§7): the request re-checks the password — 5 / 15 min per user, replacing the default. */
const EXPORT_LIMIT = {
  bucket: 'data_export:user',
  rule: 'dataExportUser',
  key: byUserId,
  replacesDefault: true,
} as const;
const DOWNLOAD_LIMIT = {
  bucket: 'data_export_download:user',
  rule: 'dataExportDownloadUser',
  key: byUserId,
  replacesDefault: true,
} as const;

/** Versioned legal documents (contract v1.66-social draft, D198, CONVENTIONS §10.61.2). */
@Controller('legal')
export class LegalController {
  constructor(private readonly consents: ConsentsService) {}

  /** The terms and the privacy policy in force (public: the sign-up screen and the website read it). */
  @Public()
  @Get('documents')
  documents(@Res({ passthrough: true }) res: Response): Promise<{ documents: LegalDocumentDto[] }> {
    res.setHeader('Cache-Control', 'public, max-age=60');
    return this.consents.documents();
  }
}

/** The caller's consents (D198, §10.61.2). Works while consent is required (the consent screen). */
@Controller('me/consents')
@ConsentExempt()
export class ConsentsController {
  constructor(private readonly consents: ConsentsService) {}

  @Get()
  status(@CurrentAuth() auth: AuthContext): Promise<ConsentStatusDto> {
    return this.consents.status(auth.userId);
  }

  @Post()
  @HttpCode(200)
  accept(
    @CurrentAuth() auth: AuthContext,
    @Body(new ZodValidationPipe(acceptConsentsSchema)) body: AcceptConsentsInput,
    @Req() req: AppRequest,
  ): Promise<ConsentStatusDto> {
    return this.consents.accept(auth.userId, body, requestMeta(req));
  }
}

/** «تنزيل بياناتي» (D198, §10.61.1). Works while consent is required (a person may want a copy before accepting). */
@Controller('me/data-exports')
@ConsentExempt()
export class DataExportsController {
  constructor(private readonly exports: DataExportsService) {}

  @Get()
  list(@CurrentAuth() auth: AuthContext): Promise<DataExportListDto> {
    return this.exports.list(auth.userId);
  }

  @Post()
  @HttpCode(202)
  @RateLimit(EXPORT_LIMIT)
  request(
    @CurrentAuth() auth: AuthContext,
    @Body(new ZodValidationPipe(dataExportRequestSchema)) body: DataExportRequestInput,
    @Req() req: AppRequest,
  ): Promise<DataExportDto> {
    return this.exports.request(auth.userId, body, requestMeta(req));
  }

  @Post(':exportId/link')
  @HttpCode(200)
  @RateLimit(DOWNLOAD_LIMIT)
  link(
    @CurrentAuth() auth: AuthContext,
    @Param('exportId', new ParseUUIDPipe()) exportId: string,
    @Req() req: AppRequest,
  ): Promise<DataExportLinkDto> {
    return this.exports.link(auth.userId, exportId, requestMeta(req));
  }

  /** The ZIP itself, once (`application/zip`, never cached). */
  @Get(':exportId/file')
  @RateLimit(DOWNLOAD_LIMIT)
  async file(
    @CurrentAuth() auth: AuthContext,
    @Param('exportId', new ParseUUIDPipe()) exportId: string,
    @Query(new ZodValidationPipe(downloadQuerySchema)) query: { token: string },
    @Req() req: AppRequest,
    @Res() res: Response,
  ): Promise<void> {
    const { bytes, name } = await this.exports.download(auth.userId, exportId, query.token, requestMeta(req));
    res.status(200);
    res.setHeader('Content-Type', 'application/zip');
    res.setHeader('Content-Length', String(bytes.length));
    res.setHeader('Content-Disposition', `attachment; filename="${name}"`);
    res.setHeader('Cache-Control', 'no-store');
    res.end(bytes);
  }
}
