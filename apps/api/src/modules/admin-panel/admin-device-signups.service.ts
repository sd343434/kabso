import { Inject, Injectable } from '@nestjs/common';
import { AuditAction, AuditService } from '../../common/audit/audit.service.js';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { deviceAllowanceIn, lockDeviceIn } from '../auth/device-signups.js';
import { AdminAuthService, type AdminContext } from './admin-auth.service.js';
import { refused } from './admin-users.service.js';

/** At most this many accounts of one device are listed (the count is exact). */
const LIST_LIMIT = 50;

export interface AdminDeviceSignupsDto {
  known: boolean;
  platform: string | null;
  createdAt: string | null;
  defaultMax: number;
  maxAccounts: number;
  count: number;
  exception: {
    maxAccounts: number;
    reason: string;
    grantedBy: { id: string; username: string } | null;
    grantedAt: string;
  } | null;
  accounts: {
    id: string;
    username: string;
    displayName: string;
    status: string;
    createdAt: string;
    self: boolean;
  }[];
}

/**
 * v1.78-social (D223, CONVENTIONS §10.75): the user page's «الجهاز» — the accounts created on the device the account
 * was created on (deleted ones included, as the limit counts them), and an OWNER's exception for that device (more
 * accounts than SIGNUP_MAX_ACCOUNTS_PER_DEVICE): the authenticator code again, a reason, audited. The panel never
 * sees the device hash itself; the device is named by one of its accounts.
 */
@Injectable()
export class AdminDeviceSignupsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
    private readonly adminAuth: AdminAuthService,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
  ) {}

  private async deviceOf(userId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { id: true, deviceSignup: { select: { deviceHash: true, platform: true, createdAt: true } } },
    });
    if (!user) throw new AppException(ErrorCode.NOT_FOUND);
    return user.deviceSignup;
  }

  private async view(userId: string, device: Awaited<ReturnType<AdminDeviceSignupsService['deviceOf']>>) {
    const defaultMax = this.config.registration.maxAccountsPerDevice;
    if (!device) {
      return {
        known: false,
        platform: null,
        createdAt: null,
        defaultMax,
        maxAccounts: defaultMax,
        count: 0,
        exception: null,
        accounts: [],
      } satisfies AdminDeviceSignupsDto;
    }
    const allowance = await deviceAllowanceIn(this.prisma, device.deviceHash, defaultMax);
    const rows = await this.prisma.deviceSignup.findMany({
      where: { deviceHash: device.deviceHash },
      orderBy: { createdAt: 'asc' },
      take: LIST_LIMIT,
      select: {
        createdAt: true,
        user: {
          select: { id: true, status: true, profile: { select: { username: true, displayName: true } } },
        },
      },
    });
    const grantedBy = allowance.exception?.grantedById
      ? await this.prisma.userProfile.findUnique({
          where: { userId: allowance.exception.grantedById },
          select: { userId: true, username: true },
        })
      : null;
    return {
      known: true,
      platform: device.platform,
      createdAt: device.createdAt.toISOString(),
      defaultMax,
      maxAccounts: allowance.max,
      count: allowance.count,
      exception: allowance.exception
        ? {
            maxAccounts: allowance.exception.maxAccounts,
            reason: allowance.exception.reason,
            grantedBy: grantedBy ? { id: grantedBy.userId, username: grantedBy.username } : null,
            grantedAt: allowance.exception.createdAt.toISOString(),
          }
        : null,
      accounts: rows.map((r) => ({
        id: r.user.id,
        username: r.user.profile?.username ?? '',
        displayName: r.user.profile?.displayName ?? '',
        status: r.user.status,
        createdAt: r.createdAt.toISOString(),
        self: r.user.id === userId,
      })),
    } satisfies AdminDeviceSignupsDto;
  }

  /** GET /admin/users/{userId}/device-signups (`users.device_view`; audited). */
  async get(userId: string, ctx: AdminContext): Promise<AdminDeviceSignupsDto> {
    const device = await this.deviceOf(userId);
    const out = await this.view(userId, device);
    await this.audit.record({
      action: AuditAction.DEVICE_SIGNUPS_VIEW,
      actorUserId: ctx.userId,
      targetType: 'user',
      targetId: userId,
      metadata: { known: out.known, accounts: out.count, via: 'panel' },
      ip: ctx.ip,
      requestId: ctx.requestId,
    });
    return out;
  }

  /** PUT /admin/users/{userId}/device-signups/exception (`users.device_exception`, OWNER; the code again). */
  async grant(
    userId: string,
    body: { maxAccounts: number; reason: string; totpCode: string },
    ctx: AdminContext,
  ): Promise<AdminDeviceSignupsDto> {
    const device = await this.deviceOf(userId);
    await this.adminAuth.reauthenticate(ctx, body.totpCode);
    if (!device)
      throw refused('This account was not created with a device id (the website or an older app).');
    const now = new Date();
    await this.prisma.$transaction(async (tx) => {
      await lockDeviceIn(tx, device.deviceHash);
      const before = await tx.deviceSignupException.findUnique({
        where: { deviceHash: device.deviceHash },
        select: { maxAccounts: true },
      });
      await tx.deviceSignupException.upsert({
        where: { deviceHash: device.deviceHash },
        create: {
          deviceHash: device.deviceHash,
          maxAccounts: body.maxAccounts,
          reason: body.reason,
          grantedById: ctx.userId,
          createdAt: now,
        },
        update: {
          maxAccounts: body.maxAccounts,
          reason: body.reason,
          grantedById: ctx.userId,
          createdAt: now,
        },
      });
      await this.audit.recordIn(tx, {
        action: AuditAction.DEVICE_EXCEPTION_GRANT,
        actorUserId: ctx.userId,
        targetType: 'user',
        targetId: userId,
        metadata: {
          reason: body.reason,
          maxAccounts: body.maxAccounts,
          before: before?.maxAccounts ?? null,
          defaultMax: this.config.registration.maxAccountsPerDevice,
          via: 'panel',
        },
        ip: ctx.ip,
        requestId: ctx.requestId,
      });
    });
    return this.view(userId, device);
  }

  /** POST /admin/users/{userId}/device-signups/exception/remove (`users.device_exception`, OWNER; the code again). */
  async remove(userId: string, body: { reason: string; totpCode: string }, ctx: AdminContext) {
    const device = await this.deviceOf(userId);
    await this.adminAuth.reauthenticate(ctx, body.totpCode);
    if (!device)
      throw refused('This account was not created with a device id (the website or an older app).');
    await this.prisma.$transaction(async (tx) => {
      await lockDeviceIn(tx, device.deviceHash);
      const before = await tx.deviceSignupException.findUnique({
        where: { deviceHash: device.deviceHash },
        select: { maxAccounts: true },
      });
      if (!before) throw refused('This device has no exception.');
      await tx.deviceSignupException.delete({ where: { deviceHash: device.deviceHash } });
      await this.audit.recordIn(tx, {
        action: AuditAction.DEVICE_EXCEPTION_REMOVE,
        actorUserId: ctx.userId,
        targetType: 'user',
        targetId: userId,
        metadata: { reason: body.reason, before: before.maxAccounts, via: 'panel' },
        ip: ctx.ip,
        requestId: ctx.requestId,
      });
    });
    return this.view(userId, device);
  }
}
