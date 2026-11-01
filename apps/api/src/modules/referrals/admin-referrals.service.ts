import { Injectable } from '@nestjs/common';
import { AuditAction, AuditService } from '../../common/audit/audit.service.js';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import type { Prisma, ReferralStatus } from '../../generated/prisma/client.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { AdminAuthService, type AdminContext } from '../admin-panel/admin-auth.service.js';
import { tableResult, window, type TableQuery } from '../admin-panel/admin-tables.js';
import { refused, viaOf } from '../admin-panel/admin-users.service.js';
import {
  approveReferralIn,
  ReferralAdminError,
  referralSettingsIn,
  updateReferralSettingsIn,
  voidReferralIn,
  type ReferralSettingsRow,
} from './referral-core.js';
import { milestonesJson, type ReferralSettingsPatch } from './referral-rules.js';

export interface ReferralsQuery extends TableQuery {
  readonly status?: ReferralStatus | undefined;
}

async function rule<T>(step: () => Promise<T>): Promise<T> {
  try {
    return await step();
  } catch (err) {
    if (err instanceof ReferralAdminError) throw refused(err.message);
    throw err;
  }
}

const person = {
  select: {
    id: true,
    status: true,
    profile: { select: { username: true, displayName: true, avatarUrl: true } },
  },
};
type Person = {
  id: string;
  status: string;
  profile: { username: string; displayName: string; avatarUrl: string | null } | null;
};
const personDto = (u: Person) => ({
  id: u.id,
  username: u.profile?.username ?? '',
  displayName: u.profile?.displayName ?? '',
  avatarUrl: u.profile?.avatarUrl ?? null,
  status: u.status,
});

/** `AdminReferralSettings`: the settings as the panel shows and edits them. */
export function settingsDto(s: ReferralSettingsRow) {
  return {
    enabled: s.enabled,
    inviterSignupCherries: Number(s.inviterSignupCherries),
    inviteeSignupCherries: Number(s.inviteeSignupCherries),
    firstRechargeBps: s.firstRechargeBps,
    milestones: milestonesJson(s.milestones),
    dailySignupCap: s.dailySignupCap,
    holdHours: s.holdHours,
    applyWindowDays: s.applyWindowDays,
    selfIpWindowHours: s.selfIpWindowHours,
    updatedAt: s.updatedAt.toISOString(),
    updatedById: s.updatedById,
  };
}

/**
 * «الدعوات» in the panel (v1.74-social, D217, CONVENTIONS §10.71): the referrals table (status filter, CSV), a
 * referral with its rewards and the fraud signals (audited `referral.view`), approve / void with a reason and the
 * authenticator code again (money), and the settings (FINANCE / OWNER, code again). The rules are `referral-core.ts`,
 * the same code as `referral-admin`.
 */
@Injectable()
export class AdminReferralsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
    private readonly auth: AdminAuthService,
  ) {}

  async table(q: ReferralsQuery, ctx: AdminContext) {
    const text = q.q?.trim().toLowerCase().replace(/^@/, '');
    const where: Prisma.ReferralWhereInput = {
      ...(q.status ? { status: q.status } : {}),
      ...(text
        ? {
            OR: [
              { inviter: { profile: { username: { startsWith: text } } } },
              { invitee: { profile: { username: { startsWith: text } } } },
              { code: { equals: text.toUpperCase() } },
            ],
          }
        : {}),
    };
    const orderBy: Prisma.ReferralOrderByWithRelationInput[] =
      q.sort === 'holdUntil'
        ? [{ holdUntil: q.order }, { id: q.order }]
        : [{ createdAt: q.order }, { id: q.order }];
    const [rows, total] = await Promise.all([
      this.prisma.referral.findMany({
        where,
        orderBy,
        ...window(q),
        select: {
          id: true,
          status: true,
          source: true,
          code: true,
          rejectReason: true,
          voidReason: true,
          holdUntil: true,
          firstRechargeAt: true,
          createdAt: true,
          inviter: person,
          invitee: person,
          rewards: { select: { status: true, cherries: true } },
        },
      }),
      this.prisma.referral.count({ where }),
    ]);
    const data = rows.map((r) => ({
      id: r.id,
      status: r.status,
      source: r.source,
      code: r.code,
      rejectReason: r.rejectReason,
      voidReason: r.voidReason,
      inviter: personDto(r.inviter),
      invitee: personDto(r.invitee),
      holdUntil: r.holdUntil.toISOString(),
      firstRecharge: r.firstRechargeAt !== null,
      pendingCherries: Number(
        r.rewards.filter((w) => w.status === 'PENDING').reduce((s, w) => s + w.cherries, 0n),
      ),
      creditedCherries: Number(
        r.rewards.filter((w) => w.status === 'CREDITED').reduce((s, w) => s + w.cherries, 0n),
      ),
      createdAt: r.createdAt.toISOString(),
    }));
    return tableResult(
      this.audit,
      ctx,
      'referrals',
      q,
      data,
      total,
      [
        ['id', (r) => r.id],
        ['status', (r) => r.status],
        ['source', (r) => r.source],
        ['inviter', (r) => r.inviter.username],
        ['invitee', (r) => r.invitee.username],
        ['reject_reason', (r) => r.rejectReason],
        ['void_reason', (r) => r.voidReason],
        ['pending_cherries', (r) => r.pendingCherries],
        ['credited_cherries', (r) => r.creditedCherries],
        ['created_at', (r) => r.createdAt],
      ],
      { status: q.status ?? null },
    );
  }

  /** A referral with its rewards and the fraud signals (audited `referral.view`, via panel). */
  async detail(id: string, ctx: AdminContext) {
    const r = await this.prisma.referral.findUnique({
      where: { id },
      include: {
        inviter: person,
        invitee: person,
        decidedBy: person,
        rewards: { orderBy: { createdAt: 'asc' } },
      },
    });
    if (!r) throw new AppException(ErrorCode.NOT_FOUND);
    // The same install id or mailbox elsewhere (the duplicate signals the rules used).
    const [sameDevice, sameEmail] = await Promise.all([
      r.inviteeInstallId
        ? this.prisma.referral.count({ where: { inviteeInstallId: r.inviteeInstallId, id: { not: r.id } } })
        : Promise.resolve(0),
      this.prisma.referral.count({
        where: { inviteeEmailHash: r.inviteeEmailHash, id: { not: r.id } },
      }),
    ]);
    await this.audit.record({
      action: AuditAction.REFERRAL_VIEW,
      actorUserId: ctx.userId,
      targetType: 'referral',
      targetId: r.id,
      metadata: { via: 'panel' },
      ip: ctx.ip,
      requestId: ctx.requestId,
    });
    return {
      id: r.id,
      status: r.status,
      source: r.source,
      code: r.code,
      rejectReason: r.rejectReason,
      voidReason: r.voidReason,
      inviter: personDto(r.inviter),
      invitee: personDto(r.invitee),
      decidedBy: r.decidedBy ? personDto(r.decidedBy) : null,
      holdUntil: r.holdUntil.toISOString(),
      firstRechargeAt: r.firstRechargeAt?.toISOString() ?? null,
      qualifiedAt: r.qualifiedAt?.toISOString() ?? null,
      voidedAt: r.voidedAt?.toISOString() ?? null,
      createdAt: r.createdAt.toISOString(),
      signals: {
        installId: r.inviteeInstallId !== null,
        ip: r.inviteeIp,
        sameDeviceReferrals: sameDevice,
        sameEmailReferrals: sameEmail,
      },
      rewards: r.rewards.map((w) => ({
        id: w.id,
        userId: w.userId,
        kind: w.kind,
        status: w.status,
        cherries: Number(w.cherries),
        holdUntil: w.holdUntil.toISOString(),
        baseCoins: w.baseCoins === null ? null : Number(w.baseCoins),
        rateBps: w.rateBps,
        rechargeReason: w.rechargeReason,
        creditedAt: w.creditedAt?.toISOString() ?? null,
        voidedAt: w.voidedAt?.toISOString() ?? null,
        voidReason: w.voidReason,
      })),
    };
  }

  async approve(id: string, body: { reason: string; totpCode: string }, ctx: AdminContext) {
    await this.auth.reauthenticate(ctx, body.totpCode);
    const r = await rule(() =>
      this.prisma.$transaction((tx) => approveReferralIn(tx, id, body.reason, new Date(), viaOf(ctx))),
    );
    return { status: 'QUALIFIED' as const, changed: r.changed, creditedCherries: Number(r.credited) };
  }

  async voidReferral(id: string, body: { reason: string; totpCode: string }, ctx: AdminContext) {
    await this.auth.reauthenticate(ctx, body.totpCode);
    const r = await rule(() =>
      this.prisma.$transaction((tx) => voidReferralIn(tx, id, body.reason, new Date(), viaOf(ctx))),
    );
    return { status: 'VOID' as const, ...r };
  }

  async settings() {
    return settingsDto(await referralSettingsIn(this.prisma));
  }

  async updateSettings(
    body: { patch: ReferralSettingsPatch; reason: string; totpCode: string },
    ctx: AdminContext,
  ) {
    await this.auth.reauthenticate(ctx, body.totpCode);
    const after = await this.prisma.$transaction((tx) =>
      updateReferralSettingsIn(tx, body.patch, body.reason, new Date(), viaOf(ctx)),
    );
    return settingsDto(after);
  }
}
