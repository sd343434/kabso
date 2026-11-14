import {
  Body,
  Controller,
  HttpCode,
  Inject,
  Injectable,
  Logger,
  Param,
  Post,
  Req,
  Res,
} from '@nestjs/common';
import type { Response } from 'express';
import { z } from 'zod';
import { AuditAction, AuditService } from '../../common/audit/audit.service.js';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { clientIp, type AppRequest, type AuthContext } from '../../common/http/request-context.js';
import { RateLimitService } from '../../common/rate-limit/rate-limit.service.js';
import { getRequestId } from '../../common/request-id/request-id.js';
import { zodErrorToDetails } from '../../common/validation/zod-validation.pipe.js';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import type { Prisma } from '../../generated/prisma/client.js';
import { safeErrorLog } from '../../logging/redact-text.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { CurrentAuth } from '../auth/current-auth.decorator.js';
import { LiveMediaService } from '../live/live-media.service.js';
import { LiveRoomsService } from '../live/live-rooms.service.js';
import { Notifier } from '../notifications/notifier.js';
import { assertKabsoOwner } from '../owner-profile/owner-core.js';
import {
  AccountControlError,
  MAX_RESTRICTION_DAYS,
  restrictIn,
  restrictionEnd,
} from '../users/account-control.js';
import { requestDeletionIn } from '../users/account-deletion.js';
import { AccountLifecycleService } from '../users/profiles/account-lifecycle.service.js';
import { violatedUniqueIndex } from '../users/users.service.js';
import { refused } from './admin-users.service.js';

type Tx = Prisma.TransactionClient;

/**
 * v1.99-social (D311, CONVENTIONS §10.117; owner: «يمكنه حذف او حظر او تحذير اي شخص»): «إجراءات المؤسس» — what the app
 * owner may do to anyone from a profile's ⋯ menu or a person card. Owner decision (2026-11-08): no authenticator code and
 * no password for these, a confirmation dialog only — he waived D286 / D288's step-up for himself in the app; every other
 * staff member is unchanged.
 */
export const OWNER_MODERATION_ACTIONS = ['WARN', 'SUSPEND', 'BAN', 'DELETE_ACCOUNT'] as const;
export type OwnerModerationActionKind = (typeof OWNER_MODERATION_ACTIONS)[number];

/** `OwnerModerationRequest`. */
export const ownerModerationSchema = z
  .strictObject({
    action: z.enum(OWNER_MODERATION_ACTIONS),
    reason: z.string().trim().min(1).max(500),
    /** SUSPEND «حظر مؤقت» only, and required there: 1 … 365 days (the panel's restriction limit). */
    days: z.number().int().min(1).max(MAX_RESTRICTION_DAYS).optional(),
    /** The app's id of this action: a retry with it returns the first result instead of acting again. */
    clientId: z.uuid(),
  })
  .superRefine((v, ctx) => {
    if (v.action === 'SUSPEND' && v.days === undefined)
      ctx.addIssue({ code: 'custom', path: ['days'], message: 'required', params: { issue: 'required' } });
    if (v.action !== 'SUSPEND' && v.days !== undefined)
      ctx.addIssue({
        code: 'custom',
        path: ['days'],
        message: 'invalid_value',
        params: { issue: 'invalid_value' },
      });
  });
export type OwnerModerationInput = z.output<typeof ownerModerationSchema>;

/** `OwnerModerationResult`. */
export interface OwnerModerationResultDto {
  id: string;
  action: OwnerModerationActionKind;
  target: { id: string; username: string; displayName: string };
  reason: string;
  /** SUSPEND: the days and the end; otherwise null. */
  days: number | null;
  endsAt: string | null;
  /** DELETE_ACCOUNT: when the grace period ends (the account can still be restored until then); otherwise null. */
  purgeAfter: string | null;
  createdAt: string;
  /** True when this answers a retry of an action already taken (nothing was done again). */
  replayed: boolean;
}

export interface OwnerMeta {
  readonly ip: string | null;
  readonly requestId: string | null;
}

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/**
 * The owner's moderation actions. Each one REUSES the rule the panel and the staff tools run (no second copy of the
 * logic): WARN = the report queue's warning (the system notification `MODERATION_WARNING`, audited
 * `admin.user.warn`); SUSPEND «حظر مؤقت» = the account controls' LOCK for N days (`restrictIn`, D208: sessions revoked,
 * the person told, audited `admin.user.lock`); BAN «حظر دائم» = the panel's ban (`AccountLifecycleService.suspendIn`,
 * audited `admin.user.ban`); DELETE_ACCOUNT = the D193 deletion with its grace period (`requestDeletionIn`, still
 * cancellable until it is purged, audited `account.deletion.requested`). All with `via: app`; one more row
 * `owner.moderation.action` ties them to the action. Never on the owner's own account or on another OWNER.
 */
@Injectable()
export class OwnerModerationService {
  private readonly logger = new Logger(OwnerModerationService.name);
  private readonly notifier = new Notifier();

  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
    private readonly lifecycle: AccountLifecycleService,
    private readonly live: LiveRoomsService,
    private readonly liveMedia: LiveMediaService,
    private readonly limiter: RateLimitService,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
  ) {}

  async act(
    callerId: string,
    targetId: string,
    body: unknown,
    meta: OwnerMeta,
  ): Promise<{ created: boolean; result: OwnerModerationResultDto }> {
    // 403 OWNER_ONLY for anyone but the app owner now (an ACTIVE account holding the OWNER panel role, read now) —
    // the other staff roles included: their tools are unchanged.
    await assertKabsoOwner(this.prisma, callerId);
    const parsed = ownerModerationSchema.safeParse(body ?? {}, { reportInput: true });
    if (!parsed.success) throw AppException.validation(zodErrorToDetails(parsed.error));
    const input = parsed.data;
    const clientId = input.clientId.toLowerCase();
    const first = await this.byClientId(callerId, clientId);
    if (first) return { created: false, result: first };
    await this.limiter.consume('owner:moderation', callerId, this.config.rateLimits.ownerModerationUser);
    if (!UUID.test(targetId)) throw new AppException(ErrorCode.NOT_FOUND);
    const target = targetId.toLowerCase();

    let rooms: string[] = [];
    let actionId: string;
    try {
      actionId = await this.prisma.$transaction(async (tx: Tx) => {
        const person = await tx.user.findUnique({
          where: { id: target },
          select: { status: true, adminPermissions: { select: { permission: true } } },
        });
        if (!person || person.status === 'DELETED') throw new AppException(ErrorCode.NOT_FOUND);
        if (target === callerId) throw refused('You cannot do this to your own account.', 'self', 'rule');
        if (person.adminPermissions.some((p) => p.permission === 'OWNER'))
          throw refused('Another owner of the app cannot be acted on from here.', 'owner_target', 'rule');
        const now = new Date();
        const by = { via: 'app' as const, actorUserId: callerId, ip: meta.ip, requestId: meta.requestId };
        let endsAt: Date | null = null;
        let purgeAfter: Date | null = null;
        let detail: Record<string, unknown> = {};
        if (input.action === 'WARN') {
          // The queue's WARN: the person is told by the system (never the owner's name).
          await this.notifier.system(tx, { type: 'MODERATION_WARNING', recipientId: target });
          await this.audit.recordIn(tx, {
            action: AuditAction.ADMIN_USER_WARN,
            actorUserId: callerId,
            targetType: 'user',
            targetId: target,
            metadata: { reason: input.reason, via: 'app', owner: true },
            ip: meta.ip,
            requestId: meta.requestId,
          });
        } else if (input.action === 'BAN') {
          if (!(await this.lifecycle.suspendIn(tx, target))) throw refused('The account is not ACTIVE.');
          await this.audit.recordIn(tx, {
            action: AuditAction.ADMIN_USER_BAN,
            actorUserId: callerId,
            targetType: 'user',
            targetId: target,
            metadata: {
              reason: input.reason,
              before: person.status,
              after: 'SUSPENDED',
              via: 'app',
              owner: true,
            },
            ip: meta.ip,
            requestId: meta.requestId,
          });
        } else if (input.action === 'SUSPEND') {
          endsAt = restrictionEnd(now, { days: input.days });
          // `restrictIn` locks the account row, audits `admin.user.lock` and tells the person (ACCOUNT_RESTRICTED).
          const out = await restrictIn(tx, target, 'LOCK', endsAt, input.reason, by, now);
          rooms = await this.live.endByAdminIn(tx, { hostUserId: target });
          await this.live.releaseSeatsOfUserIn(tx, target);
          detail = { restrictionId: out.restriction.id, sessions: out.sessions };
        } else {
          // The panel's «حذف الحساب»: the D193 deletion with its grace period (cancellable until purged).
          const r = await requestDeletionIn(tx, target, now, this.config.accountDeletion.graceDays, {
            via: 'ADMIN',
            actorUserId: callerId,
            reason: input.reason,
            ip: meta.ip,
            requestId: meta.requestId,
            auditVia: 'app',
          });
          if (r.outcome === 'not_active') throw refused('The account is not ACTIVE.');
          if (r.outcome === 'already_pending') throw refused('A deletion is already pending.');
          if (r.outcome === 'blocked') {
            throw new AppException(
              ErrorCode.ACCOUNT_DELETION_BLOCKED,
              undefined,
              r.blockers.map((b) => ({ field: 'blocker', issue: b })),
            );
          }
          purgeAfter = r.request.purgeAfter;
          rooms = await this.live.endByAdminIn(tx, { hostUserId: target });
          detail = { sessions: r.revokedSessions };
        }
        const row = await tx.ownerModerationAction.create({
          data: {
            actorId: callerId,
            targetId: target,
            clientId,
            action: input.action,
            reason: input.reason,
            days: input.days ?? null,
            endsAt,
            purgeAfter,
            createdAt: now,
          },
          select: { id: true },
        });
        await this.audit.recordIn(tx, {
          action: AuditAction.OWNER_MODERATION_ACTION,
          actorUserId: callerId,
          targetType: 'user',
          targetId: target,
          metadata: {
            actionId: row.id,
            action: input.action,
            reason: input.reason,
            ...(input.days !== undefined ? { days: input.days } : {}),
            ...(endsAt ? { endsAt: endsAt.toISOString() } : {}),
            ...(purgeAfter ? { purgeAfter: purgeAfter.toISOString() } : {}),
            ...detail,
            via: 'app',
          },
          ip: meta.ip,
          requestId: meta.requestId,
        });
        return row.id;
      });
    } catch (err) {
      // A concurrent retry with the same clientId committed first: answer with its result.
      if (violatedUniqueIndex(err) !== null) {
        const raced = await this.byClientId(callerId, clientId);
        if (raced) return { created: false, result: raced };
      }
      if (err instanceof AccountControlError) {
        if (err.issue === 'not_found') throw new AppException(ErrorCode.NOT_FOUND);
        throw refused(err.message, err.issue, 'rule');
      }
      throw err;
    }
    for (const roomId of rooms) {
      try {
        await this.liveMedia.closeMedia(roomId);
      } catch (err) {
        this.logger.warn({ error: safeErrorLog(err), roomId }, 'Media session could not be closed');
      }
    }
    const result = await this.one(actionId);
    return { created: true, result: { ...result, replayed: false } };
  }

  private async byClientId(actorId: string, clientId: string): Promise<OwnerModerationResultDto | null> {
    const row = await this.prisma.ownerModerationAction.findUnique({
      where: { actorId_clientId: { actorId, clientId } },
      select: { id: true },
    });
    return row ? { ...(await this.one(row.id)), replayed: true } : null;
  }

  private async one(id: string): Promise<OwnerModerationResultDto> {
    const r = await this.prisma.ownerModerationAction.findUniqueOrThrow({
      where: { id },
      include: {
        target: { select: { id: true, profile: { select: { username: true, displayName: true } } } },
      },
    });
    return {
      id: r.id,
      action: r.action as OwnerModerationActionKind,
      target: {
        id: r.target.id,
        username: r.target.profile?.username ?? '',
        displayName: r.target.profile?.displayName ?? '',
      },
      reason: r.reason,
      days: r.days,
      endsAt: r.endsAt?.toISOString() ?? null,
      purgeAfter: r.purgeAfter?.toISOString() ?? null,
      createdAt: r.createdAt.toISOString(),
      replayed: false,
    };
  }
}

/** v1.99-social (D311, §10.117): `POST /owner/users/{userId}/actions` — the app owner only (403 `OWNER_ONLY`). */
@Controller('owner/users')
export class OwnerModerationController {
  constructor(private readonly service: OwnerModerationService) {}

  @Post(':userId/actions')
  @HttpCode(201)
  async act(
    @CurrentAuth() auth: AuthContext,
    @Req() req: AppRequest,
    @Param('userId') userId: string,
    @Body() body: unknown,
    @Res({ passthrough: true }) res: Response,
  ): Promise<OwnerModerationResultDto> {
    const { created, result } = await this.service.act(auth.userId, userId, body, {
      ip: clientIp(req),
      requestId: getRequestId(req),
    });
    if (!created) res.status(200);
    return result;
  }
}
