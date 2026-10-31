import { Inject, Injectable } from '@nestjs/common';
import { AuditAction, AuditService } from '../../common/audit/audit.service.js';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { decideWithdrawalIn, WithdrawalAdminError } from '../economy/withdrawal-admin.js';
import { OBJECT_STORAGE, type ObjectStorage } from '../media/object-storage.js';
import {
  approveApplicationIn,
  RechargeAdminError,
  reinstateIn,
  rejectApplicationIn,
  setCapIn,
  suspendIn,
  topUpIn,
} from '../recharge/recharge-core.js';
import { parseMoneyMinor } from '../recharge/recharge-rules.js';
import { AdminAuthService, type AdminContext } from './admin-auth.service.js';
import { decodeCursor, pageOf, type Page } from './admin-panel.schemas.js';
import { refused, viaOf } from './admin-users.service.js';

/** The newest (or oldest) first keyset condition after `cursor`. */
function after(cursor: string | undefined, dir: 'asc' | 'desc') {
  const c = decodeCursor(cursor);
  if (!c) return {};
  const op = dir === 'asc' ? 'gt' : 'lt';
  return { OR: [{ createdAt: { [op]: c.at } }, { createdAt: c.at, id: { [op]: c.id } }] };
}

async function shared<T>(step: () => Promise<T>): Promise<T> {
  try {
    return await step();
  } catch (err) {
    if (err instanceof RechargeAdminError || err instanceof WithdrawalAdminError) throw refused(err.message);
    throw err;
  }
}

export type PhotoKind = 'photo' | 'selfie';

/**
 * The panel's recharge agents and withdrawals (v1.60-social, D191, CONVENTIONS §10.54.5): the `recharge-admin` and
 * `economy-admin withdrawal-*` rules themselves (recharge-core, withdrawal-admin) with the admin as the audited actor.
 * Applications' private fields and pictures are read only by roles with `recharge.applications`, each view audited
 * (D185); the pictures are streamed through the API (`private, no-store`), never a storage URL. A top-up and a
 * withdrawal decision need the authenticator code again (§10.54.3).
 */
@Injectable()
export class AdminFinanceService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
    private readonly auth: AdminAuthService,
    @Inject(OBJECT_STORAGE) private readonly storage: ObjectStorage,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
  ) {}

  private get grace(): number {
    return this.config.specialUsernames.graceDays;
  }

  // ---- applications ---------------------------------------------------------------------------------------------

  async applications(query: {
    status?: 'PENDING' | 'APPROVED' | 'REJECTED' | undefined;
    cursor?: string | undefined;
    limit: number;
  }) {
    const rows = await this.prisma.rechargeAgentApplication.findMany({
      where: { ...(query.status ? { status: query.status } : {}), ...after(query.cursor, 'desc') },
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
      take: query.limit + 1,
      select: {
        id: true,
        status: true,
        createdAt: true,
        decidedAt: true,
        purgedAt: true,
        user: { select: { id: true, profile: { select: { username: true, displayName: true } } } },
      },
    });
    // A list shows no private field (only the audited detail does).
    return pageOf(rows, query.limit, (r) => ({
      id: r.id,
      status: r.status,
      createdAt: r.createdAt.toISOString(),
      decidedAt: r.decidedAt?.toISOString() ?? null,
      purged: r.purgedAt !== null,
      user: {
        id: r.user.id,
        username: r.user.profile?.username ?? '',
        displayName: r.user.profile?.displayName ?? '',
      },
    }));
  }

  /** The application with its private fields (audited `recharge.application.view`, via panel). */
  async application(id: string, ctx: AdminContext) {
    const app = await this.prisma.rechargeAgentApplication.findUnique({
      where: { id },
      include: {
        user: {
          select: { id: true, email: true, profile: { select: { username: true, displayName: true } } },
        },
      },
    });
    if (!app) throw new AppException(ErrorCode.NOT_FOUND);
    await this.audit.record({
      action: AuditAction.RECHARGE_APPLICATION_VIEW,
      actorUserId: ctx.userId,
      targetType: 'recharge_application',
      targetId: app.id,
      metadata: { via: 'panel' },
      ip: ctx.ip,
      requestId: ctx.requestId,
    });
    const purged = app.purgedAt !== null;
    return {
      id: app.id,
      status: app.status,
      createdAt: app.createdAt.toISOString(),
      decidedAt: app.decidedAt?.toISOString() ?? null,
      purgedAt: app.purgedAt?.toISOString() ?? null,
      rejectReason: app.rejectReason,
      user: {
        id: app.user.id,
        username: app.user.profile?.username ?? '',
        displayName: app.user.profile?.displayName ?? '',
        email: app.user.email,
      },
      fullName: purged ? null : app.fullName,
      phone: purged ? null : app.phone,
      locations: purged ? null : (app.locations ?? null),
      paymentMethods: purged ? null : (app.paymentMethods ?? null),
      photos: {
        photo: !purged && app.photoKey !== null,
        selfie: !purged && app.selfieKey !== null,
      },
    };
  }

  /** One private picture's bytes (audited per view); 404 when purged or missing. */
  async photo(id: string, which: PhotoKind, ctx: AdminContext): Promise<Buffer> {
    const app = await this.prisma.rechargeAgentApplication.findUnique({
      where: { id },
      select: { photoKey: true, selfieKey: true, purgedAt: true },
    });
    const key = app && app.purgedAt === null ? (which === 'photo' ? app.photoKey : app.selfieKey) : null;
    if (!key) throw new AppException(ErrorCode.NOT_FOUND);
    await this.audit.record({
      action: AuditAction.RECHARGE_PHOTO_VIEW,
      actorUserId: ctx.userId,
      targetType: 'recharge_application',
      targetId: id,
      metadata: { which, via: 'panel' },
      ip: ctx.ip,
      requestId: ctx.requestId,
    });
    const bytes = await this.storage.get(key, 16 * 1024 * 1024);
    if (!bytes) throw new AppException(ErrorCode.NOT_FOUND);
    return bytes;
  }

  async approve(id: string, ctx: AdminContext): Promise<{ status: 'APPROVED' }> {
    await shared(() =>
      this.prisma.$transaction((tx) => approveApplicationIn(tx, id, new Date(), viaOf(ctx))),
    );
    return { status: 'APPROVED' };
  }

  async reject(id: string, reason: string, ctx: AdminContext): Promise<{ status: 'REJECTED' }> {
    await shared(() =>
      this.prisma.$transaction((tx) => rejectApplicationIn(tx, id, reason, new Date(), viaOf(ctx))),
    );
    return { status: 'REJECTED' };
  }

  // ---- agents ---------------------------------------------------------------------------------------------------

  pricing() {
    return {
      activationMinCoins: this.config.recharge.activationMinCoins,
      priceTiers: this.config.recharge.priceTiers.map((t) => ({
        minCoins: t.minCoins,
        minorPerMillion: t.minorPerMillion,
      })),
      currency: 'USD',
    };
  }

  async agents(query: {
    status?: 'APPROVED' | 'ACTIVE' | 'SUSPENDED' | undefined;
    cursor?: string | undefined;
    limit: number;
  }) {
    const c = decodeCursor(query.cursor);
    const rows = await this.prisma.rechargeAgent.findMany({
      where: {
        ...(query.status ? { status: query.status } : {}),
        ...(c ? { OR: [{ approvedAt: { lt: c.at } }, { approvedAt: c.at, userId: { lt: c.id } }] } : {}),
      },
      orderBy: [{ approvedAt: 'desc' }, { userId: 'desc' }],
      take: query.limit + 1,
      select: {
        userId: true,
        code: true,
        status: true,
        stockCoins: true,
        dailyCherryCap: true,
        countries: true,
        approvedAt: true,
        activatedAt: true,
        suspendReason: true,
        user: { select: { profile: { select: { username: true, displayName: true } } } },
      },
    });
    const page = pageOf(
      rows.map((r) => ({ ...r, id: r.userId, createdAt: r.approvedAt })),
      query.limit,
      (r) => ({
        userId: r.userId,
        code: r.code,
        status: r.status,
        stockCoins: Number(r.stockCoins),
        dailyCherryCap: r.dailyCherryCap === null ? null : Number(r.dailyCherryCap),
        countries: r.countries,
        approvedAt: r.approvedAt.toISOString(),
        activatedAt: r.activatedAt?.toISOString() ?? null,
        suspendReason: r.suspendReason,
        username: r.user.profile?.username ?? '',
        displayName: r.user.profile?.displayName ?? '',
      }),
    );
    return { ...page, pricing: this.pricing() };
  }

  /** `recharge-admin topup` with the owner's tier price; needs the authenticator code again. */
  async topUp(
    agentUserId: string,
    body: { coins: string; paidUsd: string; note?: string | undefined; totpCode: string },
    ctx: AdminContext,
  ) {
    await this.auth.reauthenticate(ctx, body.totpCode);
    const paid = parseMoneyMinor(body.paidUsd);
    if (paid === null) throw AppException.validation([{ field: 'paidUsd', issue: 'invalid' }]);
    const rules = { ...this.pricing(), priceTiers: this.config.recharge.priceTiers };
    const r = await shared(() =>
      this.prisma.$transaction((tx) =>
        topUpIn(
          tx,
          agentUserId,
          BigInt(body.coins),
          paid,
          body.note ?? null,
          rules,
          new Date(),
          this.grace,
          viaOf(ctx),
        ),
      ),
    );
    return {
      topupId: r.topupId,
      first: r.first,
      code: r.code,
      stockCoins: Number(r.stock),
      tier: r.tier,
      minorPerMillion: r.minorPerMillion,
      expectedMinor: Number(r.expectedMinor),
      paidMinor: Number(paid),
    };
  }

  async suspend(agentUserId: string, reason: string, ctx: AdminContext): Promise<{ status: 'SUSPENDED' }> {
    await shared(() =>
      this.prisma.$transaction((tx) =>
        suspendIn(tx, agentUserId, reason, new Date(), this.grace, viaOf(ctx)),
      ),
    );
    return { status: 'SUSPENDED' };
  }

  async reinstate(agentUserId: string, reason: string, ctx: AdminContext): Promise<{ status: string }> {
    const status = await shared(() =>
      this.prisma.$transaction((tx) =>
        reinstateIn(tx, agentUserId, new Date(), this.grace, viaOf(ctx), reason),
      ),
    );
    return { status };
  }

  async setCap(agentUserId: string, cap: string | null, reason: string, ctx: AdminContext) {
    await shared(() =>
      this.prisma.$transaction((tx) =>
        setCapIn(tx, agentUserId, cap === null ? null : BigInt(cap), viaOf(ctx), reason),
      ),
    );
    return { dailyCherryCap: cap === null ? null : Number(cap) };
  }

  // ---- withdrawals ----------------------------------------------------------------------------------------------

  async withdrawals(query: {
    status: 'PENDING' | 'PAID' | 'REJECTED';
    cursor?: string | undefined;
    limit: number;
  }): Promise<Page<unknown>> {
    // Pending ones oldest first (the queue); decided ones newest first.
    const dir = query.status === 'PENDING' ? 'asc' : 'desc';
    const rows = await this.prisma.cherryWithdrawal.findMany({
      where: { status: query.status, ...after(query.cursor, dir) },
      orderBy: [{ createdAt: dir }, { id: dir }],
      take: query.limit + 1,
      select: {
        id: true,
        status: true,
        cherries: true,
        amountMinor: true,
        currency: true,
        payoutDetails: true,
        createdAt: true,
        decidedAt: true,
        decisionNote: true,
        user: { select: { id: true, profile: { select: { username: true, displayName: true } } } },
      },
    });
    return pageOf(rows, query.limit, (w) => ({
      id: w.id,
      status: w.status,
      cherries: Number(w.cherries),
      amountMinor: Number(w.amountMinor),
      currency: w.currency,
      payoutDetails: w.payoutDetails,
      createdAt: w.createdAt.toISOString(),
      decidedAt: w.decidedAt?.toISOString() ?? null,
      decisionNote: w.decisionNote,
      user: {
        id: w.user.id,
        username: w.user.profile?.username ?? '',
        displayName: w.user.profile?.displayName ?? '',
      },
    }));
  }

  /** Marks a request paid (the money was sent by hand); the note keeps the payment reference. Code again. */
  async payWithdrawal(
    id: string,
    body: { reference: string; note?: string | undefined; totpCode: string },
    ctx: AdminContext,
  ) {
    await this.auth.reauthenticate(ctx, body.totpCode);
    const note = body.note ? `ref: ${body.reference} — ${body.note}` : `ref: ${body.reference}`;
    const d = await shared(() =>
      this.prisma.$transaction((tx) => decideWithdrawalIn(tx, id, true, note, new Date(), viaOf(ctx))),
    );
    return { status: d.status, cherries: Number(d.cherries) };
  }

  /** Rejects a request with a reason: the held cherries go back (a balance change: code again). */
  async rejectWithdrawal(id: string, body: { reason: string; totpCode: string }, ctx: AdminContext) {
    await this.auth.reauthenticate(ctx, body.totpCode);
    const d = await shared(() =>
      this.prisma.$transaction((tx) =>
        decideWithdrawalIn(tx, id, false, body.reason, new Date(), viaOf(ctx)),
      ),
    );
    return { status: d.status, cherries: Number(d.cherries) };
  }
}
