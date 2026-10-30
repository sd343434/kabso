import { Inject, Injectable } from '@nestjs/common';
import { z } from 'zod';
import { AuditAction } from '../../common/audit/audit.service.js';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { Clock } from '../../common/time/clock.js';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { HOST_FRAME_CODES, type HostFrameStyle } from '../bag/bag.catalogue.js';
import { hostActivity } from './agency-ranks.js';
import {
  canChooseHostFrame,
  hostFrameStyle,
  syncHostFrameIn,
  type HostFrameStyleFrom,
} from './host-frames.js';

/** `SetHostFrameStyleRequest`. */
export const hostFrameStyleBodySchema = z.strictObject({ style: z.enum(['BLUE', 'PINK']) });
export type HostFrameStyleBody = z.infer<typeof hostFrameStyleBodySchema>;

/** `HostFrameItem`: the HOST_ACTIVE frame the caller owns now. */
export interface HostFrameItemDto {
  code: string;
  assetKey: string;
  equipped: boolean;
}

/** `HostFrame` (v1.55-social, D186, CONVENTIONS §10.49): the caller's active-host frame. */
export interface HostFrameDto {
  /** The caller is an ACTIVE agency host (the frame needs an agency). */
  agencyHost: boolean;
  /** The caller passes the active-host test now (D179). */
  active: boolean;
  /** Days with live time and seconds live in the window. */
  liveDays: number;
  liveSeconds: number;
  /** The style that applies (from the gender, or chosen), null until a host without a gender chooses. */
  style: HostFrameStyle | null;
  styleFrom: HostFrameStyleFrom | null;
  /** The caller picks the style (no gender, or «prefer not to say»). */
  canChoose: boolean;
  /** The HOST_ACTIVE frame owned now (the sweeper gives and takes it), or null. */
  frame: HostFrameItemDto | null;
  rule: { minDays: number; minHours: number; windowDays: number };
}

/**
 * The active-host frame (v1.55-social, D186): what the caller has and why, and the style choice of a host
 * without a stated gender. The frame itself is given and taken by the agency sweeper (`syncHostFrames`);
 * a choice applies at once (the frame is given or swapped in the same transaction, a worn one stays worn).
 */
@Injectable()
export class HostFrameService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly clock: Clock,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
  ) {}

  private get zone(): string {
    return this.config.live.rankingsTimeZone;
  }

  /** `GET /me/host-frame`. */
  async mine(me: string): Promise<HostFrameDto> {
    const now = this.clock.now();
    const [activity, profile, choice, owned] = await Promise.all([
      hostActivity(this.prisma, null, now, this.config.economy, this.zone, [me]),
      this.prisma.userProfile.findUnique({ where: { userId: me }, select: { gender: true } }),
      this.prisma.hostFrameChoice.findUnique({ where: { userId: me }, select: { style: true } }),
      this.prisma.userBagItem.findFirst({
        where: { userId: me, source: 'HOST_ACTIVE' },
        select: { itemCode: true, equipped: true, item: { select: { assetKey: true } } },
      }),
    ]);
    const a = activity[0];
    const gender = profile?.gender ?? null;
    const { style, from } = hostFrameStyle(gender, choice?.style ?? null);
    const e = this.config.economy;
    return {
      agencyHost: a !== undefined,
      active: a?.active ?? false,
      liveDays: a?.liveDays ?? 0,
      liveSeconds: a?.liveSeconds ?? 0,
      style,
      styleFrom: from,
      canChoose: canChooseHostFrame(gender),
      frame: owned ? { code: owned.itemCode, assetKey: owned.item.assetKey, equipped: owned.equipped } : null,
      rule: {
        minDays: e.activeHostMinDays,
        minHours: e.activeHostMinHours,
        windowDays: e.activeHostWindowDays,
      },
    };
  }

  /**
   * `PUT /me/host-frame/style {style}`: 409 HOST_FRAME_STYLE_FROM_GENDER while the gender is male or
   * female; otherwise stores the choice (any time, also before the host is active; changeable later) and
   * syncs the frame in the same transaction. Idempotent. Audited when the choice changes.
   */
  async choose(me: string, body: HostFrameStyleBody): Promise<HostFrameDto> {
    const now = this.clock.now();
    await this.prisma.$transaction(async (tx) => {
      const [p] = await tx.$queryRaw<{ gender: string | null }[]>`
        SELECT gender::text AS gender FROM user_profiles WHERE user_id = ${me}::uuid FOR UPDATE`;
      if (!p) throw new AppException(ErrorCode.AUTH_UNAUTHENTICATED);
      if (!canChooseHostFrame(p.gender)) throw new AppException(ErrorCode.HOST_FRAME_STYLE_FROM_GENDER);
      const before = await tx.hostFrameChoice.findUnique({ where: { userId: me }, select: { style: true } });
      if (before?.style !== body.style) {
        await tx.hostFrameChoice.upsert({
          where: { userId: me },
          create: { userId: me, style: body.style, updatedAt: now },
          update: { style: body.style, updatedAt: now },
        });
        await tx.auditLog.create({
          data: {
            actorUserId: me,
            action: AuditAction.HOST_FRAME_CHOICE,
            targetType: 'user',
            targetId: me,
            metadata: { from: before?.style ?? null, to: body.style, item: HOST_FRAME_CODES[body.style] },
          },
        });
      }
      await syncHostFrameIn(tx, me, now, this.config.economy, this.zone);
    });
    return this.mine(me);
  }
}
