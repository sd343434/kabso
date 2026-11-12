import { Inject, Injectable } from '@nestjs/common';
import { auditBy, type AdminVia } from '../../common/audit/admin-actor.js';
import { AuditAction } from '../../common/audit/audit.service.js';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { Clock } from '../../common/time/clock.js';
import type { Prisma, VipTier, VipTierPerk } from '../../generated/prisma/client.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { GiftArtError, giftArtUrl, uploadGiftArt } from '../gifts/gift-art.js';
import { OBJECT_STORAGE, type ObjectStorage } from '../media/object-storage.js';
import { StorageSettingsStore } from '../storage-settings/storage-settings.store.js';
import { ENTRY_CAR_KIND, type EntryDisplay } from '../store/store-rules.js';
import { violatedUniqueIndex } from '../users/users.service.js';
import {
  VIP_BUILT_PERKS,
  VIP_CODE_PATTERN,
  VIP_MAX_TIERS,
  VIP_PERK_AMOUNTS,
  VIP_SUGGESTED_PERKS,
  vipOrderOf,
  vipPerkAvailable,
  VIP_RENEWAL_DISCOUNT_DEFAULT,
} from './vip-rules.js';
import { vipAnimationFile, vipStillFile, type VipArtFile, type VipUploadKind } from './vip-art.js';
import type { CreateVipTierBody, UpdateVipTierBody, VipPerkInput } from './vip.schemas.js';

type Tx = Prisma.TransactionClient;

/** `AdminVipPerk`. */
export interface AdminVipPerkDto {
  code: string;
  titleAr: string;
  titleEn: string;
  descriptionAr: string | null;
  descriptionEn: string | null;
  enabled: boolean;
  /** The app really does this perk today (server list; not editable). */
  available: boolean;
  /** The perk's own art (SVGA + still) and its intrinsic size. */
  animation: string | null;
  still: string | null;
  artWidth: number | null;
  artHeight: number | null;
  /** D258: the perk's number for this tier (bullets / coins a day, level speed-up %); null otherwise. */
  amount: number | null;
  /** v1.128-social (D373, §10.165): the ENTRY_EFFECT perk's display «طريقة العرض»; null for every other perk. */
  entryDisplay: EntryDisplay | null;
}

/** v1.83-social (D258): `AdminVipUpload`. */
export interface AdminVipUploadDto {
  kind: VipUploadKind;
  url: string;
  bytes: number;
  contentType: string;
  /** A still's size in px (null for an animation). */
  width: number | null;
  height: number | null;
}

/** `AdminVipTier`. */
export interface AdminVipTierDto {
  id: string;
  code: string;
  nameAr: string;
  nameEn: string;
  sortOrder: number;
  color: string;
  /** v1.83-social (D258): the special text colour, or null. */
  nameColor: string | null;
  /** v1.83-social (D258): percent off a renewal (0 = none). */
  renewalDiscountPercent: number;
  badgeAnimation: string | null;
  badgeStill: string | null;
  priceCoins: number;
  /** v1.126-social (D370, §10.163): the price in recharge points; null = not redeemable with points. */
  pointsPrice: number | null;
  durationDays: number;
  enabled: boolean;
  /** People whose membership of this tier is active now. */
  activeMembers: number;
  perks: AdminVipPerkDto[];
  updatedAt: string;
}

/** `AdminVipTierList`. */
export interface AdminVipTierListDto {
  data: AdminVipTierDto[];
  /** The perk codes the app really does today (none yet). */
  builtPerks: string[];
  /** The perk codes the panel suggests. */
  suggestedPerks: string[];
}

type TierWithPerks = VipTier & { perks: VipTierPerk[] };

/** Thrown for a refused panel change (409 `ADMIN_ACTION_REFUSED` with the message). */
function refused(message: string): AppException {
  return new AppException(ErrorCode.ADMIN_ACTION_REFUSED, message);
}

function perkDto(p: VipTierPerk): AdminVipPerkDto {
  return {
    code: p.code,
    titleAr: p.titleAr,
    titleEn: p.titleEn,
    descriptionAr: p.descriptionAr,
    descriptionEn: p.descriptionEn,
    enabled: p.enabled,
    available: vipPerkAvailable(p.code),
    animation: p.animation,
    still: p.still,
    artWidth: p.artWidth,
    artHeight: p.artHeight,
    amount: p.amount,
    entryDisplay: p.code === ENTRY_CAR_KIND ? p.entryDisplay : null,
  };
}

/** A tier's fields for the audit row (before / after). */
function snapshot(t: TierWithPerks): Prisma.InputJsonObject {
  return {
    code: t.code,
    nameAr: t.nameAr,
    nameEn: t.nameEn,
    sortOrder: t.sortOrder,
    color: t.color,
    nameColor: t.nameColor,
    renewalDiscountPercent: t.renewalDiscountPercent,
    badgeAnimation: t.badgeAnimation,
    badgeStill: t.badgeStill,
    priceCoins: Number(t.priceCoins),
    pointsPrice: t.pointsPrice === null ? null : Number(t.pointsPrice),
    durationDays: t.durationDays,
    enabled: t.enabled,
    perks: t.perks.map((p) => ({
      code: p.code,
      titleAr: p.titleAr,
      titleEn: p.titleEn,
      descriptionAr: p.descriptionAr,
      descriptionEn: p.descriptionEn,
      enabled: p.enabled,
      animation: p.animation,
      still: p.still,
      artWidth: p.artWidth,
      artHeight: p.artHeight,
      amount: p.amount,
      // v1.128-social (D373): the entry car's display, audited before / after.
      ...(p.code === ENTRY_CAR_KIND ? { entryDisplay: p.entryDisplay } : {}),
    })),
  };
}

const PERKS_IN_ORDER = { orderBy: [{ sortOrder: 'asc' as const }, { code: 'asc' as const }] };

/**
 * «VIP» in the admin panel (v1.82-social, D252, CONVENTIONS §10.93.4): the OWNER adds tiers, changes their names,
 * colour, badge art, price, length and perks, puts them in order, and switches them on or off — each change with a reason,
 * in one transaction with its audit row (`vip.tier.*`, before / after, `via: panel`). Tiers are never deleted (memberships
 * and purchases keep pointing at them): one switched off is no longer sold, and people who hold it keep it to its end.
 * A price or length change applies to purchases from then on.
 */
@Injectable()
export class VipAdminService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly clock: Clock,
    @Inject(OBJECT_STORAGE) private readonly storage: ObjectStorage,
    private readonly storageSettings: StorageSettingsStore,
  ) {}

  /**
   * v1.83-social (D258, §10.94.6): one file of a tier's badge or perk art (SVGA 2.x or a PNG / WebP still), the raw
   * bytes; stored content-addressed, the URL returned for the tier's form (the tier itself changes only on save).
   */
  async upload(kind: VipUploadKind, tier: string, body: unknown): Promise<AdminVipUploadDto> {
    if (!Buffer.isBuffer(body) || body.length === 0) {
      throw new AppException(ErrorCode.ADMIN_ACTION_REFUSED, 'The file is empty.', [
        { field: 'file', issue: 'empty' },
      ]);
    }
    if (!VIP_CODE_PATTERN.test(tier))
      throw AppException.validation([{ field: 'tier', issue: 'invalid_format' }]);
    let file: VipArtFile;
    try {
      file = kind === 'animation' ? vipAnimationFile(tier, body) : await vipStillFile(tier, body);
    } catch (err) {
      if (err instanceof GiftArtError) {
        throw new AppException(ErrorCode.ADMIN_ACTION_REFUSED, err.message, [
          { field: 'file', issue: 'invalid_file' },
        ]);
      }
      throw err;
    }
    await uploadGiftArt(this.storage, file);
    const url = giftArtUrl(this.storageSettings.current().publicBaseUrl, file.key);
    if (url === null) {
      throw new AppException(ErrorCode.ADMIN_ACTION_REFUSED, 'No public media URL is set.', [
        { field: 'storage', issue: 'no_public_url' },
      ]);
    }
    return {
      kind,
      url,
      bytes: file.size,
      contentType: file.contentType,
      width: file.width ?? null,
      height: file.height ?? null,
    };
  }

  async list(): Promise<AdminVipTierListDto> {
    const rows = await this.prisma.vipTier.findMany({
      orderBy: [{ sortOrder: 'asc' }, { id: 'asc' }],
      include: { perks: PERKS_IN_ORDER },
    });
    const counts = await this.activeCounts(this.prisma);
    return {
      data: rows.map((t) => this.dto(t, counts)),
      builtPerks: [...VIP_BUILT_PERKS].sort(),
      suggestedPerks: [...VIP_SUGGESTED_PERKS],
    };
  }

  async create(body: CreateVipTierBody, by: AdminVia): Promise<AdminVipTierDto> {
    try {
      return await this.prisma.$transaction(async (tx) => {
        // One panel change of the tier list at a time (the order and the cap).
        await tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtext('kabso:vip-tiers'))`;
        const count = await tx.vipTier.count();
        if (count >= VIP_MAX_TIERS) throw refused(`At most ${VIP_MAX_TIERS} VIP tiers.`);
        const last = await tx.vipTier.aggregate({ _max: { sortOrder: true } });
        const tier = await tx.vipTier.create({
          data: {
            code: body.code,
            nameAr: body.nameAr,
            nameEn: body.nameEn,
            sortOrder: (last._max.sortOrder ?? 0) + 1,
            color: body.color,
            nameColor: body.nameColor ?? null,
            renewalDiscountPercent: body.renewalDiscountPercent ?? VIP_RENEWAL_DISCOUNT_DEFAULT,
            badgeAnimation: body.badgeAnimation ?? null,
            badgeStill: body.badgeStill ?? null,
            priceCoins: BigInt(body.priceCoins),
            pointsPrice:
              body.pointsPrice === undefined || body.pointsPrice === null ? null : BigInt(body.pointsPrice),
            durationDays: body.durationDays,
            enabled: body.enabled ?? false,
            updatedById: by.actorUserId,
          },
        });
        await this.writePerks(tx, tier.id, body.perks ?? []);
        const after = await this.load(tx, tier.id);
        await tx.auditLog.create({
          data: {
            ...auditBy(by),
            action: AuditAction.VIP_TIER_ADD,
            targetType: 'vip_tier',
            targetId: tier.id,
            metadata: { after: snapshot(after), reason: body.reason, via: by.via },
          },
        });
        return this.dto(after, await this.activeCounts(tx));
      });
    } catch (err) {
      if (violatedUniqueIndex(err) !== null) throw refused(`A VIP tier ${body.code} exists already.`);
      throw err;
    }
  }

  async update(id: string, body: UpdateVipTierBody, by: AdminVia): Promise<AdminVipTierDto> {
    return this.prisma.$transaction(async (tx) => {
      const before = await this.lockTier(tx, id);
      await tx.vipTier.update({
        where: { id },
        data: {
          ...(body.nameAr !== undefined ? { nameAr: body.nameAr } : {}),
          ...(body.nameEn !== undefined ? { nameEn: body.nameEn } : {}),
          ...(body.color !== undefined ? { color: body.color } : {}),
          ...(body.nameColor !== undefined ? { nameColor: body.nameColor } : {}),
          ...(body.renewalDiscountPercent !== undefined
            ? { renewalDiscountPercent: body.renewalDiscountPercent }
            : {}),
          ...(body.badgeAnimation !== undefined ? { badgeAnimation: body.badgeAnimation } : {}),
          ...(body.badgeStill !== undefined ? { badgeStill: body.badgeStill } : {}),
          ...(body.priceCoins !== undefined ? { priceCoins: BigInt(body.priceCoins) } : {}),
          ...(body.pointsPrice !== undefined
            ? { pointsPrice: body.pointsPrice === null ? null : BigInt(body.pointsPrice) }
            : {}),
          ...(body.durationDays !== undefined ? { durationDays: body.durationDays } : {}),
          updatedById: by.actorUserId,
        },
      });
      if (body.perks !== undefined) await this.writePerks(tx, id, body.perks);
      const after = await this.load(tx, id);
      await tx.auditLog.create({
        data: {
          ...auditBy(by),
          action: AuditAction.VIP_TIER_UPDATE,
          targetType: 'vip_tier',
          targetId: id,
          metadata: {
            before: snapshot(before),
            after: snapshot(after),
            reason: body.reason,
            via: by.via,
          },
        },
      });
      return this.dto(after, await this.activeCounts(tx));
    });
  }

  /** On / off. The same state again changes nothing and writes no audit row. */
  async setEnabled(id: string, enabled: boolean, reason: string, by: AdminVia): Promise<AdminVipTierDto> {
    return this.prisma.$transaction(async (tx) => {
      const before = await this.lockTier(tx, id);
      if (before.enabled !== enabled) {
        await tx.vipTier.update({ where: { id }, data: { enabled, updatedById: by.actorUserId } });
        await tx.auditLog.create({
          data: {
            ...auditBy(by),
            action: enabled ? AuditAction.VIP_TIER_ENABLE : AuditAction.VIP_TIER_DISABLE,
            targetType: 'vip_tier',
            targetId: id,
            metadata: {
              code: before.code,
              before: before.enabled ? 'enabled' : 'disabled',
              after: enabled ? 'enabled' : 'disabled',
              reason,
              via: by.via,
            },
          },
        });
      }
      return this.dto(await this.load(tx, id), await this.activeCounts(tx));
    });
  }

  /** The new order: every tier's id exactly once, lowest first (else 400 `tierIds` `invalid_value`). */
  async reorder(ids: string[], reason: string, by: AdminVia): Promise<AdminVipTierListDto> {
    await this.prisma.$transaction(async (tx) => {
      await tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtext('kabso:vip-tiers'))`;
      const rows = await tx.vipTier.findMany({
        orderBy: [{ sortOrder: 'asc' }, { id: 'asc' }],
        select: { id: true, code: true, sortOrder: true },
      });
      const order = vipOrderOf(
        ids.map((i) => i.toLowerCase()),
        rows.map((r) => r.id),
      );
      if (!order) throw AppException.validation([{ field: 'tierIds', issue: 'invalid_value' }]);
      for (const r of rows) {
        const sortOrder = order.get(r.id)!;
        if (sortOrder !== r.sortOrder) {
          await tx.vipTier.update({ where: { id: r.id }, data: { sortOrder, updatedById: by.actorUserId } });
        }
      }
      await tx.auditLog.create({
        data: {
          ...auditBy(by),
          action: AuditAction.VIP_TIER_REORDER,
          targetType: 'vip_tier',
          targetId: null,
          metadata: {
            before: rows.map((r) => r.code),
            after: [...rows].sort((a, b) => order.get(a.id)! - order.get(b.id)!).map((r) => r.code),
            reason,
            via: by.via,
          },
        },
      });
    });
    return this.list();
  }

  // ---- helpers ------------------------------------------------------------------------------------------------------

  private async lockTier(tx: Tx, id: string): Promise<TierWithPerks> {
    const locked = await tx.$queryRaw<{ id: string }[]>`
      SELECT id::text AS id FROM vip_tiers WHERE id = ${id}::uuid FOR UPDATE`;
    if (locked.length === 0) throw new AppException(ErrorCode.NOT_FOUND);
    return this.load(tx, id);
  }

  private load(tx: Tx, id: string): Promise<TierWithPerks> {
    return tx.vipTier.findUniqueOrThrow({ where: { id }, include: { perks: PERKS_IN_ORDER } });
  }

  /** Replaces the tier's perks with [perks], in that order. */
  private async writePerks(tx: Tx, tierId: string, perks: readonly VipPerkInput[]): Promise<void> {
    // v1.128-social (D373): a perk sent without `entryDisplay` (an older panel) keeps the one it had.
    const kept = new Map(
      (
        await tx.vipTierPerk.findMany({
          where: { tierId, code: ENTRY_CAR_KIND },
          select: { code: true, entryDisplay: true },
        })
      ).map((p) => [p.code, p.entryDisplay]),
    );
    await tx.vipTierPerk.deleteMany({ where: { tierId } });
    if (perks.length === 0) return;
    await tx.vipTierPerk.createMany({
      data: perks.map((p, i) => ({
        tierId,
        code: p.code,
        titleAr: p.titleAr,
        titleEn: p.titleEn,
        descriptionAr: p.descriptionAr ? p.descriptionAr : null,
        descriptionEn: p.descriptionEn ? p.descriptionEn : null,
        sortOrder: i,
        enabled: p.enabled ?? true,
        animation: p.animation ?? null,
        still: p.still ?? null,
        artWidth: p.artWidth ?? null,
        artHeight: p.artHeight ?? null,
        // D258: only the perks that take a number keep one.
        amount: VIP_PERK_AMOUNTS[p.code] ? (p.amount ?? null) : null,
        entryDisplay: p.entryDisplay ?? kept.get(p.code) ?? 'FULL_SCREEN',
      })),
    });
  }

  private async activeCounts(db: Tx): Promise<Map<string, number>> {
    const groups = await db.vipMembership.groupBy({
      by: ['tierId'],
      where: { expiresAt: { gt: this.clock.now() } },
      _count: { _all: true },
    });
    return new Map(groups.map((g) => [g.tierId, g._count._all]));
  }

  private dto(t: TierWithPerks, counts: Map<string, number>): AdminVipTierDto {
    return {
      id: t.id,
      code: t.code,
      nameAr: t.nameAr,
      nameEn: t.nameEn,
      sortOrder: t.sortOrder,
      color: t.color,
      nameColor: t.nameColor,
      renewalDiscountPercent: t.renewalDiscountPercent,
      badgeAnimation: t.badgeAnimation,
      badgeStill: t.badgeStill,
      priceCoins: Number(t.priceCoins),
      pointsPrice: t.pointsPrice === null ? null : Number(t.pointsPrice),
      durationDays: t.durationDays,
      enabled: t.enabled,
      activeMembers: counts.get(t.id) ?? 0,
      perks: t.perks.map(perkDto),
      updatedAt: t.updatedAt.toISOString(),
    };
  }
}
