import { Injectable } from '@nestjs/common';
import { Prisma } from '../../generated/prisma/client.js';
import { auditBy } from '../../common/audit/admin-actor.js';
import { AuditAction, AuditService } from '../../common/audit/audit.service.js';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { DeviceBanError, liftDeviceBanIn } from '../auth/device-bans.js';
import { iapSettingsIn } from '../store-iap/iap-core.js';
import type { IapProductCreateBody, IapProductUpdateBody, IapUnbanBody } from '../store-iap/iap.schemas.js';
import { IapService } from '../store-iap/iap.service.js';
import { AccountLifecycleService } from '../users/profiles/account-lifecycle.service.js';
import { AdminAuthService, type AdminContext } from './admin-auth.service.js';
import { tableResult, window, type TableQuery } from './admin-tables.js';
import { refused, viaOf } from './admin-users.service.js';

const person = { select: { id: true, profile: { select: { username: true, displayName: true } } } };
type PersonRow = { id: string; profile: { username: string; displayName: string } | null };
const personOf = (u: PersonRow) => ({
  id: u.id,
  username: u.profile?.username ?? '',
  displayName: u.profile?.displayName ?? '',
});

function productDto(p: {
  id: string;
  platform: 'GOOGLE_PLAY' | 'APP_STORE';
  productId: string;
  coins: bigint;
  referenceUsdCents: number | null;
  sortOrder: number;
  enabled: boolean;
  updatedAt: Date;
}) {
  return {
    id: p.id,
    platform: p.platform,
    productId: p.productId,
    coins: Number(p.coins),
    referenceUsdCents: p.referenceUsdCents,
    sortOrder: p.sortOrder,
    enabled: p.enabled,
    updatedAt: p.updatedAt.toISOString(),
  };
}

/**
 * v1.110-social (D345, CONVENTIONS §10.144.6): the panel's «مشتريات المتجر» — the stores' status and the switch, the
 * catalogue (store product ↔ coins), the purchases, the refund bans and the OWNER's «فك الحظر».
 */
@Injectable()
export class AdminIapService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
    private readonly iap: IapService,
    private readonly adminAuth: AdminAuthService,
    private readonly lifecycle: AccountLifecycleService,
  ) {}

  async overview() {
    const s = await iapSettingsIn(this.prisma);
    const [purchases, refunds, activeBans] = await Promise.all([
      this.prisma.iapPurchase.count({ where: { status: { in: ['CREDITED', 'REFUNDED'] } } }),
      this.prisma.iapPurchase.count({ where: { status: 'REFUNDED' } }),
      this.prisma.iapRefundBan.count({
        where: {
          OR: [
            { accountBanned: true, accountLiftedAt: null },
            { devicesBanned: { gt: 0 }, deviceLiftedAt: null },
          ],
        },
      }),
    ]);
    return {
      ...this.iap.status(),
      endpoints: {
        appleNotifications: '/api/v1/payments/apple/notifications',
        googleRtdn: '/api/v1/payments/google/rtdn?token=…',
      },
      settings: {
        oncePerAccountDevice: s.oncePerAccountDevice,
        updatedAt: s.updatedAt.toISOString(),
      },
      voided: {
        lastRunAt: s.voidedLastRunAt?.toISOString() ?? null,
        polledUntil: s.voidedPolledUntil?.toISOString() ?? null,
        lastError: s.voidedLastError,
      },
      counts: { purchases, refunds, activeBans },
    };
  }

  async updateSettings(oncePerAccountDevice: boolean, reason: string, ctx: AdminContext) {
    return this.prisma.$transaction(async (tx) => {
      const before = await iapSettingsIn(tx);
      const row = await tx.iapSettings.update({
        where: { id: 1 },
        data: { oncePerAccountDevice, updatedById: ctx.userId, updatedAt: new Date() },
      });
      await tx.auditLog.create({
        data: {
          ...auditBy(viaOf(ctx)),
          action: AuditAction.STORE_IAP_SETTINGS_UPDATE,
          targetType: 'iap_settings',
          targetId: '1',
          metadata: {
            reason,
            before: { oncePerAccountDevice: before.oncePerAccountDevice },
            after: { oncePerAccountDevice },
            via: viaOf(ctx).via,
          },
        },
      });
      return { oncePerAccountDevice: row.oncePerAccountDevice, updatedAt: row.updatedAt.toISOString() };
    });
  }

  async products() {
    const rows = await this.prisma.iapProduct.findMany({
      orderBy: [{ platform: 'asc' }, { sortOrder: 'asc' }, { coins: 'asc' }],
    });
    return { data: rows.map(productDto) };
  }

  async createProduct(body: IapProductCreateBody, ctx: AdminContext) {
    try {
      return await this.prisma.$transaction(async (tx) => {
        const row = await tx.iapProduct.create({
          data: {
            platform: body.platform,
            productId: body.productId,
            coins: BigInt(body.coins),
            referenceUsdCents: body.referenceUsdCents ?? null,
            sortOrder: body.sortOrder ?? 0,
            enabled: body.enabled ?? true,
            createdById: ctx.userId,
            updatedById: ctx.userId,
          },
        });
        await tx.auditLog.create({
          data: {
            ...auditBy(viaOf(ctx)),
            action: AuditAction.STORE_IAP_PRODUCT_CREATE,
            targetType: 'iap_product',
            targetId: row.id,
            metadata: { reason: body.reason, after: productDto(row), via: viaOf(ctx).via },
          },
        });
        return productDto(row);
      });
    } catch (err) {
      if (err instanceof Prisma.PrismaClientKnownRequestError && err.code === 'P2002') {
        throw refused('This store product id already exists.', 'duplicate', 'productId');
      }
      throw err;
    }
  }

  async updateProduct(id: string, body: IapProductUpdateBody, ctx: AdminContext) {
    return this.prisma.$transaction(async (tx) => {
      const before = await tx.iapProduct.findUnique({ where: { id } });
      if (!before) throw new AppException(ErrorCode.NOT_FOUND);
      const row = await tx.iapProduct.update({
        where: { id },
        data: {
          ...(body.coins !== undefined ? { coins: BigInt(body.coins) } : {}),
          ...(body.referenceUsdCents !== undefined ? { referenceUsdCents: body.referenceUsdCents } : {}),
          ...(body.sortOrder !== undefined ? { sortOrder: body.sortOrder } : {}),
          ...(body.enabled !== undefined ? { enabled: body.enabled } : {}),
          updatedById: ctx.userId,
          updatedAt: new Date(),
        },
      });
      await tx.auditLog.create({
        data: {
          ...auditBy(viaOf(ctx)),
          action: AuditAction.STORE_IAP_PRODUCT_UPDATE,
          targetType: 'iap_product',
          targetId: id,
          metadata: {
            reason: body.reason,
            before: productDto(before),
            after: productDto(row),
            via: viaOf(ctx).via,
          },
        },
      });
      return productDto(row);
    });
  }

  async purchases(
    q: TableQuery & {
      platform?: 'GOOGLE_PLAY' | 'APP_STORE' | undefined;
      status?: 'CREDITED' | 'REJECTED' | 'REFUNDED' | undefined;
      environment?: 'PRODUCTION' | 'SANDBOX' | undefined;
    },
    ctx: AdminContext,
  ) {
    const text = q.q?.trim();
    const where: Prisma.IapPurchaseWhereInput = {
      ...(q.platform ? { platform: q.platform } : {}),
      ...(q.status ? { status: q.status } : {}),
      ...(q.environment ? { environment: q.environment } : {}),
      ...(text
        ? {
            OR: [
              { transactionId: { contains: text } },
              { productId: { contains: text } },
              { user: { profile: { username: { contains: text.replace(/^@/, '').toLowerCase() } } } },
            ],
          }
        : {}),
    };
    const sortKey = q.sort === 'coins' ? 'coins' : 'createdAt';
    const [rows, total] = await Promise.all([
      this.prisma.iapPurchase.findMany({
        where,
        orderBy: [{ [sortKey]: q.order }, { id: q.order }],
        ...window(q),
        include: { user: person, refundBan: true },
      }),
      this.prisma.iapPurchase.count({ where }),
    ]);
    const data = rows.map((r) => ({
      id: r.id,
      user: personOf(r.user),
      platform: r.platform,
      productId: r.productId,
      coins: Number(r.coins),
      transactionId: r.transactionId,
      environment: r.environment,
      status: r.status,
      rejectReason: r.rejectReason,
      deviceRecorded: r.deviceHash !== null,
      consentVersion: r.consentVersion,
      consentShareData: r.consentShareData,
      purchasedAt: r.purchasedAt.toISOString(),
      creditedAt: r.creditedAt?.toISOString() ?? null,
      consumedAt: r.consumedAt?.toISOString() ?? null,
      refundedAt: r.refundedAt?.toISOString() ?? null,
      refundSource: r.refundSource,
      refundReason: r.refundReason,
      refundBanId: r.refundBan?.id ?? null,
      createdAt: r.createdAt.toISOString(),
    }));
    return tableResult(
      this.audit,
      ctx,
      'iap_purchases',
      q,
      data,
      total,
      [
        ['id', (r) => r.id],
        ['user', (r) => r.user.username],
        ['platform', (r) => r.platform],
        ['product', (r) => r.productId],
        ['coins', (r) => r.coins],
        ['transaction', (r) => r.transactionId],
        ['environment', (r) => r.environment],
        ['status', (r) => r.status],
        ['created_at', (r) => r.createdAt],
        ['refunded_at', (r) => r.refundedAt ?? ''],
        ['refund_reason', (r) => r.refundReason ?? ''],
      ],
      { platform: q.platform, status: q.status, environment: q.environment },
    );
  }

  async refundBans(q: TableQuery & { status?: 'ACTIVE' | 'LIFTED' | undefined }, ctx: AdminContext) {
    const active: Prisma.IapRefundBanWhereInput = {
      OR: [
        { accountBanned: true, accountLiftedAt: null },
        { devicesBanned: { gt: 0 }, deviceLiftedAt: null },
      ],
    };
    const text = q.q?.trim();
    const where: Prisma.IapRefundBanWhereInput = {
      AND: [
        q.status === 'ACTIVE' ? active : q.status === 'LIFTED' ? { NOT: active } : {},
        text
          ? {
              OR: [
                { reason: { contains: text } },
                { user: { profile: { username: { contains: text.replace(/^@/, '').toLowerCase() } } } },
              ],
            }
          : {},
      ],
    };
    const [rows, total] = await Promise.all([
      this.prisma.iapRefundBan.findMany({
        where,
        orderBy: [{ createdAt: q.order }, { id: q.order }],
        ...window(q),
        include: {
          user: { select: { ...person.select, status: true } },
          purchase: {
            select: { platform: true, productId: true, coins: true, transactionId: true, refundedAt: true },
          },
        },
      }),
      this.prisma.iapRefundBan.count({ where }),
    ]);
    const data = rows.map((r) => ({
      id: r.id,
      user: personOf(r.user),
      accountStatus: r.user.status,
      purchaseId: r.purchaseId,
      platform: r.purchase.platform,
      productId: r.purchase.productId,
      coins: Number(r.purchase.coins),
      transactionId: r.purchase.transactionId,
      refundedAt: r.purchase.refundedAt?.toISOString() ?? null,
      reason: r.reason,
      accountBanned: r.accountBanned && r.accountLiftedAt === null,
      deviceBanned: r.devicesBanned > 0 && r.deviceLiftedAt === null,
      devicesBanned: r.devicesBanned,
      accountLiftedAt: r.accountLiftedAt?.toISOString() ?? null,
      accountLiftReason: r.accountLiftReason,
      deviceLiftedAt: r.deviceLiftedAt?.toISOString() ?? null,
      deviceLiftReason: r.deviceLiftReason,
      createdAt: r.createdAt.toISOString(),
    }));
    return tableResult(
      this.audit,
      ctx,
      'iap_refund_bans',
      q,
      data,
      total,
      [
        ['id', (r) => r.id],
        ['user', (r) => r.user.username],
        ['reason', (r) => r.reason],
        ['coins', (r) => r.coins],
        ['account_banned', (r) => (r.accountBanned ? 'yes' : 'no')],
        ['device_banned', (r) => (r.deviceBanned ? 'yes' : 'no')],
        ['created_at', (r) => r.createdAt],
      ],
      q.status ? { status: q.status } : {},
    );
  }

  /**
   * «فك الحظر» (OWNER, the authenticator code again, a reason): the account (SUSPENDED → ACTIVE) and/or the purchase's
   * device bans. The coins taken back stay taken. Audited `store_iap.unban`.
   */
  async unban(id: string, body: IapUnbanBody, ctx: AdminContext) {
    await this.adminAuth.reauthenticate(ctx, body.totpCode);
    const now = new Date();
    const by = viaOf(ctx);
    try {
      return await this.prisma.$transaction(async (tx) => {
        const [locked] = await tx.$queryRaw<{ id: string }[]>`
          SELECT id::text AS id FROM iap_refund_bans WHERE id = ${id}::uuid FOR UPDATE`;
        if (!locked) throw new AppException(ErrorCode.NOT_FOUND);
        const ban = await tx.iapRefundBan.findUniqueOrThrow({ where: { id } });
        const before = {
          account: ban.accountBanned && ban.accountLiftedAt === null,
          device: ban.devicesBanned > 0 && ban.deviceLiftedAt === null,
        };
        if (body.account && !before.account) throw refused('The account is not banned by this refund.');
        if (body.device && !before.device) throw refused('No device is banned by this refund.');
        let accountStatus: string | null = null;
        if (body.account) {
          const unsuspended = await this.lifecycle.unsuspendIn(tx, ban.userId);
          accountStatus = unsuspended ? 'ACTIVE' : null;
          await tx.iapRefundBan.update({
            where: { id },
            data: { accountLiftedAt: now, accountLiftedBy: ctx.userId, accountLiftReason: body.reason },
          });
        }
        let devicesLifted = 0;
        if (body.device) {
          const devices = await tx.deviceBan.findMany({
            where: { iapPurchaseId: ban.purchaseId, liftedAt: null },
            select: { id: true },
          });
          for (const d of devices) {
            await liftDeviceBanIn(tx, d.id, body.reason, by, now, { storeRefund: true });
            devicesLifted += 1;
          }
          await tx.iapRefundBan.update({
            where: { id },
            data: { deviceLiftedAt: now, deviceLiftedBy: ctx.userId, deviceLiftReason: body.reason },
          });
        }
        const after = {
          account: before.account && !body.account,
          device: before.device && !body.device,
        };
        await tx.auditLog.create({
          data: {
            ...auditBy(by),
            action: AuditAction.STORE_IAP_UNBAN,
            targetType: 'user',
            targetId: ban.userId,
            metadata: {
              refundBan: id,
              purchase: ban.purchaseId,
              account: body.account,
              device: body.device,
              devicesLifted,
              accountStatus,
              reason: body.reason,
              before,
              after,
              via: by.via,
            },
          },
        });
        return { id, accountBanned: after.account, deviceBanned: after.device, devicesLifted };
      });
    } catch (err) {
      if (err instanceof DeviceBanError) throw refused(err.message);
      throw err;
    }
  }

  async syncVoided(ctx: AdminContext) {
    const result = await this.iap.syncVoided();
    await this.audit.record({
      action: AuditAction.STORE_IAP_VOIDED_SYNC,
      actorUserId: ctx.userId,
      targetType: 'iap_settings',
      targetId: '1',
      metadata: { ...result, via: 'panel' },
      ip: ctx.ip,
      requestId: ctx.requestId,
    });
    return result;
  }
}
