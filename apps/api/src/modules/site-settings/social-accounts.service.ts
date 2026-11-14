import { Injectable } from '@nestjs/common';
import { AuditAction, AuditService } from '../../common/audit/audit.service.js';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import type { Prisma } from '../../generated/prisma/client.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import type { AdminContext } from '../admin-panel/admin-auth.service.js';
import { refused } from '../admin-panel/admin-users.service.js';
import {
  normalizeSocialUrl,
  SOCIAL_ACCOUNTS_MAX,
  type SocialAccountInput,
  type SocialPlatform,
} from './social-accounts.js';

type Tx = Prisma.TransactionClient;

export interface AdminSocialAccountDto {
  id: string;
  platform: SocialPlatform;
  handle: string;
  url: string;
  sortOrder: number;
  updatedAt: string;
}

export interface OfficialSocialAccountDto {
  platform: SocialPlatform;
  handle: string;
  url: string;
}

/**
 * v1.139-social (D387, CONVENTIONS §10.176.5): the official social accounts — COMMUNITY and the OWNER manage them
 * (`social.accounts`; every change audited `site.social_account.*`), the app reads them publicly for «تابعنا». Links
 * only (https, no user name or password part); no secret of those accounts is ever stored.
 */
@Injectable()
export class SocialAccountsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
  ) {}

  private async rows(db: Tx | PrismaService = this.prisma) {
    return db.officialSocialAccount.findMany({ orderBy: [{ sortOrder: 'asc' }, { id: 'asc' }] });
  }

  /** `listAdminSocialAccounts`. */
  async adminList(db: Tx | PrismaService = this.prisma): Promise<{ data: AdminSocialAccountDto[] }> {
    return {
      data: (await this.rows(db)).map((r) => ({
        id: r.id,
        platform: r.platform as SocialPlatform,
        handle: r.handle,
        url: r.url,
        sortOrder: r.sortOrder,
        updatedAt: r.updatedAt.toISOString(),
      })),
    };
  }

  /** `listOfficialSocialAccounts` (public): a stored URL that no longer passes the rule is left out. */
  async publicList(): Promise<{ data: OfficialSocialAccountDto[] }> {
    return {
      data: (await this.rows())
        .filter((r) => normalizeSocialUrl(r.url) !== null)
        .map((r) => ({ platform: r.platform as SocialPlatform, handle: r.handle, url: r.url })),
    };
  }

  private urlOf(raw: string): string {
    const url = normalizeSocialUrl(raw);
    if (url === null) {
      throw new AppException(ErrorCode.VALIDATION_FAILED, 'An https link, with no user name or password.', [
        { field: 'url', issue: 'invalid_value' },
      ]);
    }
    return url;
  }

  private record(tx: Tx, ctx: AdminContext, action: AuditAction, targetId: string, metadata: object) {
    return this.audit.recordIn(tx, {
      action,
      actorUserId: ctx.userId,
      targetType: 'social_account',
      targetId,
      metadata: { ...metadata, via: ctx.via ?? 'panel' },
      ip: ctx.ip,
      requestId: ctx.requestId,
    });
  }

  private lock(tx: Tx) {
    return tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtext('kabso:official-social-accounts'))`;
  }

  /** `createAdminSocialAccount`: at the end of the list. */
  async create(input: SocialAccountInput, ctx: AdminContext) {
    const url = this.urlOf(input.url);
    return this.prisma.$transaction(async (tx) => {
      await this.lock(tx);
      const rows = await this.rows(tx);
      if (rows.length >= SOCIAL_ACCOUNTS_MAX) {
        throw refused(`At most ${SOCIAL_ACCOUNTS_MAX} accounts.`, 'social_accounts_full', 'rule');
      }
      const row = await tx.officialSocialAccount.create({
        data: {
          platform: input.platform,
          handle: input.handle,
          url,
          sortOrder: rows.length === 0 ? 0 : Math.max(...rows.map((r) => r.sortOrder)) + 1,
          updatedById: ctx.userId,
        },
      });
      await this.record(tx, ctx, AuditAction.SOCIAL_ACCOUNT_CREATE, row.id, {
        after: { platform: row.platform, handle: row.handle, url: row.url },
      });
      return this.adminList(tx);
    });
  }

  /** `updateAdminSocialAccount`. */
  async update(id: string, input: SocialAccountInput, ctx: AdminContext) {
    const url = this.urlOf(input.url);
    return this.prisma.$transaction(async (tx) => {
      await this.lock(tx);
      const before = await tx.officialSocialAccount.findUnique({ where: { id } });
      if (!before) throw new AppException(ErrorCode.NOT_FOUND);
      const row = await tx.officialSocialAccount.update({
        where: { id },
        data: { platform: input.platform, handle: input.handle, url, updatedById: ctx.userId },
      });
      await this.record(tx, ctx, AuditAction.SOCIAL_ACCOUNT_UPDATE, id, {
        before: { platform: before.platform, handle: before.handle, url: before.url },
        after: { platform: row.platform, handle: row.handle, url: row.url },
      });
      return this.adminList(tx);
    });
  }

  /** `deleteAdminSocialAccount`. */
  async remove(id: string, ctx: AdminContext) {
    return this.prisma.$transaction(async (tx) => {
      await this.lock(tx);
      const before = await tx.officialSocialAccount.findUnique({ where: { id } });
      if (!before) throw new AppException(ErrorCode.NOT_FOUND);
      await tx.officialSocialAccount.delete({ where: { id } });
      await this.record(tx, ctx, AuditAction.SOCIAL_ACCOUNT_DELETE, id, {
        before: { platform: before.platform, handle: before.handle, url: before.url },
      });
      return this.adminList(tx);
    });
  }

  /** `reorderAdminSocialAccounts`: exactly the current ids, each once (else 400 `ids`). */
  async reorder(ids: readonly string[], ctx: AdminContext) {
    return this.prisma.$transaction(async (tx) => {
      await this.lock(tx);
      const rows = await this.rows(tx);
      const want = ids.map((i) => i.toLowerCase());
      const same =
        want.length === rows.length &&
        new Set(want).size === want.length &&
        rows.every((r) => want.includes(r.id));
      if (!same) {
        throw new AppException(ErrorCode.VALIDATION_FAILED, 'Every account once.', [
          { field: 'ids', issue: 'invalid_value' },
        ]);
      }
      for (const [i, id] of want.entries()) {
        await tx.officialSocialAccount.update({ where: { id }, data: { sortOrder: i } });
      }
      await this.record(tx, ctx, AuditAction.SOCIAL_ACCOUNT_REORDER, 'order', {
        before: rows.map((r) => r.id),
        after: want,
      });
      return this.adminList(tx);
    });
  }
}
