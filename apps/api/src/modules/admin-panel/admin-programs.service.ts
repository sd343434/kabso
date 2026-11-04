import { Inject, Injectable } from '@nestjs/common';
import { AuditService } from '../../common/audit/audit.service.js';
import { csvDocument } from '../../common/csv/csv.js';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import type { Prisma } from '../../generated/prisma/client.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { cherriesUsd, coinsUsd, targetUnitOf } from '../programs/programs-rules.js';
import { auditWaitlistViewIn, waitlistCounts } from '../waitlist/waitlist-admin.js';
import type { AdminContext } from './admin-auth.service.js';
import { tableResult, window, type TableQuery } from './admin-tables.js';
import { viaOf } from './admin-users.service.js';

/**
 * The read-only sections of the panel v2 (v1.65-social, D197, CONVENTIONS §10.60.7): tasks «المهام» and levels
 * «المستويات» with their real money (D188: task cherries at the payout rate `CHERRY_PAYOUT_RATE`, coin values at the
 * retail price `COIN_RETAIL_USD_PER_MILLION`; a level's points ÷ its multiplier = coins), the special usernames
 * «اليوزرات المميزة» (D185) and the website's waitlist «قائمة البريد» (D192; every read audited `waitlist.view` like
 * `waitlist-admin`). Changing tasks and levels stays with `task-admin` and the levels API.
 */
@Injectable()
export class AdminProgramsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
  ) {}

  private get rate() {
    return { cherries: this.config.economy.rateCherries, minor: this.config.economy.rateMinor };
  }

  /** A coin target at the retail price; v1.69-live (D277): a cherry target at the payout rate. */
  private targetUsd(target: number, metric: string): string | null {
    const unit = targetUnitOf(metric);
    if (unit === 'COINS') return coinsUsd(target, this.config.economy.coinRetailUsdPerMillion);
    if (unit === 'CHERRIES') return cherriesUsd(target, this.rate);
    return null;
  }

  async tasks() {
    const rows = await this.prisma.taskDefinition.findMany({
      orderBy: [{ pool: 'asc' }, { period: 'asc' }, { sortOrder: 'asc' }, { code: 'asc' }],
    });
    return {
      coinRetailUsdPerMillion: this.config.economy.coinRetailUsdPerMillion,
      payoutRate: this.rate,
      data: rows.map((t) => ({
        code: t.code,
        period: t.period,
        metric: t.metric,
        audience: t.audience,
        nameAr: t.nameAr,
        nameEn: t.nameEn,
        enabled: t.enabled,
        pool: t.pool,
        poolGroup: t.poolGroup,
        target: t.target,
        // D277: «كرز» / «عملة» next to the targets (null: a count, minutes…).
        targetUnit: targetUnitOf(t.metric),
        targetUsd: this.targetUsd(t.target, t.metric),
        rewardCherries: t.rewardCherries,
        rewardUsd: cherriesUsd(t.rewardCherries, this.rate),
        bands: t.bandTargets.map((target, i) => ({
          target,
          targetUsd: this.targetUsd(target, t.metric),
          rewardCherries: t.bandRewards[i] ?? 0,
          rewardUsd: cherriesUsd(t.bandRewards[i] ?? 0, this.rate),
        })),
      })),
    };
  }

  async levels() {
    const cats = await this.prisma.levelCategory.findMany({
      orderBy: { code: 'asc' },
      select: {
        code: true,
        nameAr: true,
        nameEn: true,
        isEnabled: true,
        publishedVersion: {
          select: {
            versionNumber: true,
            multiplier: true,
            valueUnit: true,
            publishedAt: true,
            levels: {
              orderBy: { levelNumber: 'asc' },
              select: { levelNumber: true, nameAr: true, nameEn: true, requiredPoints: true },
            },
          },
        },
      },
    });
    const perMillion = this.config.economy.coinRetailUsdPerMillion;
    return {
      coinRetailUsdPerMillion: perMillion,
      data: cats.map((c) => {
        const v = c.publishedVersion;
        const mult = v?.multiplier ? Number(v.multiplier) : null;
        return {
          code: c.code,
          nameAr: c.nameAr,
          nameEn: c.nameEn,
          enabled: c.isEnabled,
          version: v?.versionNumber ?? null,
          multiplier: mult === null ? null : String(mult),
          valueUnit: (v?.valueUnit as string | null) ?? null,
          publishedAt: v?.publishedAt?.toISOString() ?? null,
          levels: (v?.levels ?? []).map((l) => {
            const points = Number(l.requiredPoints);
            const coins = mult && v?.valueUnit === 'COIN' ? Math.ceil(points / mult) : null;
            return {
              level: l.levelNumber,
              nameAr: l.nameAr,
              nameEn: l.nameEn,
              requiredPoints: points,
              coins,
              usd: coins === null ? null : coinsUsd(coins, perMillion),
            };
          }),
        };
      }),
    };
  }

  async specialUsernames(
    q: TableQuery & { status?: 'ACTIVE' | 'GRACE' | 'ENDED' | undefined; source?: string | undefined },
    ctx: AdminContext,
  ) {
    const text = q.q?.trim().toLowerCase().replace(/^@/, '');
    const where: Prisma.SpecialUsernameWhereInput = {
      ...(q.status ? { status: q.status } : {}),
      ...(q.source ? { source: q.source as never } : {}),
      ...(text ? { OR: [{ username: { startsWith: text } }, { baseUsername: { startsWith: text } }] } : {}),
    };
    const orderBy: Prisma.SpecialUsernameOrderByWithRelationInput[] =
      q.sort === 'username'
        ? [{ username: q.order }, { id: q.order }]
        : [{ grantedAt: q.order }, { id: q.order }];
    const [rows, total] = await Promise.all([
      this.prisma.specialUsername.findMany({
        where,
        orderBy,
        ...window(q),
        select: {
          id: true,
          userId: true,
          username: true,
          baseUsername: true,
          source: true,
          status: true,
          grantedAt: true,
          expiresAt: true,
          graceUntil: true,
          endedAt: true,
          reason: true,
          user: { select: { profile: { select: { displayName: true, avatarUrl: true } } } },
        },
      }),
      this.prisma.specialUsername.count({ where }),
    ]);
    const data = rows.map((s) => ({
      id: s.id,
      userId: s.userId,
      username: s.username,
      baseUsername: s.baseUsername,
      displayName: s.user.profile?.displayName ?? '',
      avatarUrl: s.user.profile?.avatarUrl ?? null,
      source: s.source,
      status: s.status,
      grantedAt: s.grantedAt.toISOString(),
      expiresAt: s.expiresAt?.toISOString() ?? null,
      graceUntil: s.graceUntil?.toISOString() ?? null,
      endedAt: s.endedAt?.toISOString() ?? null,
      reason: s.reason,
    }));
    return tableResult(this.audit, ctx, 'special-usernames', q, data, total, [
      ['username', (r) => r.username],
      ['base_username', (r) => r.baseUsername],
      ['source', (r) => r.source],
      ['status', (r) => r.status],
      ['granted_at', (r) => r.grantedAt],
      ['expires_at', (r) => r.expiresAt],
    ]);
  }

  /** The waitlist page: counts and the newest sign-ups; audited `waitlist.view` {op: list}. */
  async waitlist(q: TableQuery & { locale?: 'ar' | 'en' | undefined }, ctx: AdminContext) {
    const where = q.locale ? { locale: q.locale } : {};
    const [counts, rows, total] = await Promise.all([
      waitlistCounts(this.prisma),
      this.prisma.waitlistSignup.findMany({
        where,
        orderBy: [{ createdAt: q.order }, { id: q.order }],
        ...window(q),
        select: { id: true, email: true, locale: true, createdAt: true },
      }),
      this.prisma.waitlistSignup.count({ where }),
    ]);
    await auditWaitlistViewIn(this.prisma, q.format === 'csv' ? 'export' : 'list', rows.length, viaOf(ctx));
    const data = rows.map((r) => ({
      id: r.id,
      email: r.email,
      locale: r.locale,
      createdAt: r.createdAt.toISOString(),
    }));
    if (q.format === 'csv') {
      // The CLI's export format (email,locale,created_at).
      return {
        kind: 'csv' as const,
        filename: `kabso-waitlist-${new Date().toISOString().slice(0, 10)}.csv`,
        body: csvDocument(
          ['email', 'locale', 'created_at'],
          data.map((r) => [r.email, r.locale, r.createdAt]),
        ),
      };
    }
    return { kind: 'json' as const, body: { data, total, page: q.page, pageSize: q.pageSize, counts } };
  }
}
