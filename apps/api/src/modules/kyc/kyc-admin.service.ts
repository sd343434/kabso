import { Injectable } from '@nestjs/common';
import { AuditAction, AuditService } from '../../common/audit/audit.service.js';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { Clock } from '../../common/time/clock.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import type { AdminContext } from '../admin-panel/admin-auth.service.js';
import { DiditKeyRejectedError, DiditRequestError, DiditUnreachableError } from './didit-api.js';
import { adminCheckDto, type AdminKycCheckDto } from './kyc-core.js';
import { mediaOf, UUID_PATTERN, type DecisionMedia } from './kyc.rules.js';
import { KycSettingsStore } from './kyc.store.js';

/** `AdminKycMedia`: Didit's short-lived links, fetched now (never stored). */
export interface AdminKycMediaDto extends DecisionMedia {
  fetchedAt: string;
}

/**
 * The team's view of a check (v1.80-kyc, D227, §10.77; capability `kyc.view`, OWNER + SUPPORT): the minimum kept
 * (audited `kyc.check.view`), and the images through a short-lived fetch of Didit's decision (its presigned links,
 * audited `kyc.check.media.view` per fetch; nothing stored). The rest is in Didit's console.
 */
@Injectable()
export class KycAdminService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
    private readonly store: KycSettingsStore,
    private readonly clock: Clock,
  ) {}

  private async find(id: string) {
    if (!UUID_PATTERN.test(id)) throw new AppException(ErrorCode.NOT_FOUND);
    const check = await this.prisma.kycCheck.findUnique({ where: { id } });
    if (!check) throw new AppException(ErrorCode.NOT_FOUND);
    return check;
  }

  async view(id: string, ctx: AdminContext): Promise<AdminKycCheckDto> {
    const check = await this.find(id);
    await this.audit.record({
      action: AuditAction.KYC_CHECK_VIEW,
      actorUserId: ctx.userId,
      targetType: 'kyc_check',
      targetId: check.id,
      metadata: { user: check.userId, via: 'panel' },
      ip: ctx.ip,
      requestId: ctx.requestId,
    });
    return adminCheckDto(this.prisma, check, this.clock.now());
  }

  async media(id: string, ctx: AdminContext): Promise<AdminKycMediaDto> {
    const check = await this.find(id);
    const r = await this.store.resolved();
    if (!r.apiKey) throw new AppException(ErrorCode.KYC_UNAVAILABLE);
    // Audited before the fetch: an attempt to look is a look.
    await this.audit.record({
      action: AuditAction.KYC_MEDIA_VIEW,
      actorUserId: ctx.userId,
      targetType: 'kyc_check',
      targetId: check.id,
      metadata: { user: check.userId, sessionNumber: check.sessionNumber, via: 'panel' },
      ip: ctx.ip,
      requestId: ctx.requestId,
    });
    try {
      const decision = await this.store.api(r.apiKey).decision(check.sessionId);
      return { ...mediaOf(decision.body), fetchedAt: this.clock.now().toISOString() };
    } catch (err) {
      if (err instanceof DiditRequestError && err.status === 404) throw new AppException(ErrorCode.NOT_FOUND);
      if (
        err instanceof DiditUnreachableError ||
        err instanceof DiditKeyRejectedError ||
        err instanceof DiditRequestError
      ) {
        throw new AppException(ErrorCode.SERVICE_UNAVAILABLE, 'Didit cannot be reached right now.');
      }
      throw err;
    }
  }
}
