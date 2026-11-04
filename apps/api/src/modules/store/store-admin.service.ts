import { Inject, Injectable } from '@nestjs/common';
import { auditBy, type AdminVia } from '../../common/audit/admin-actor.js';
import { AuditAction } from '../../common/audit/audit.service.js';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { Clock } from '../../common/time/clock.js';
import type { Prisma } from '../../generated/prisma/client.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { giftArtUrl, uploadGiftArt } from '../gifts/gift-art.js';
import type { UserSummaryDto } from '../live/live-rooms.service.js';
import { OBJECT_STORAGE, type ObjectStorage } from '../media/object-storage.js';
import { USER_SUMMARY_SELECT, userSummary } from '../posts/post-views.js';
import { StorageSettingsStore } from '../storage-settings/storage-settings.store.js';
import { GiftArtError, storeAnimationFile, storeStillFile, type StoreArtFile } from './store-art.js';
import {
  newStoreBagCode,
  sortedPrices,
  STORE_CURRENCIES,
  STORE_DAYS,
  STORE_KINDS,
  STORE_MAX_ITEMS,
  type StoreCurrency,
  type StoreKind,
} from './store-rules.js';
import type { CreateStoreItemBody, UpdateStoreItemBody } from './store.schemas.js';

type Tx = Prisma.TransactionClient;

/** `AdminStorePrice`. */
export interface AdminStorePriceDto {
  currency: StoreCurrency;
  days: number;
  amount: number;
}

/** `AdminStoreItem`. */
export interface AdminStoreItemDto {
  id: string;
  code: string;
  kind: StoreKind;
  nameAr: string;
  nameEn: string;
  still: string | null;
  animation: string | null;
  animationFormat: 'SVGA' | 'MP4' | null;
  animationAlpha: 'NONE' | 'SIDE_BY_SIDE' | null;
  artWidth: number | null;
  artHeight: number | null;
  prices: AdminStorePriceDto[];
  sortOrder: number;
  isNew: boolean;
  enabled: boolean;
  /** People holding it now (not expired). */
  owners: number;
  /** Purchases of it, ever. */
  sold: number;
  createdAt: string;
  updatedAt: string;
}

/** `AdminStoreItemList`. */
export interface AdminStoreItemListDto {
  data: AdminStoreItemDto[];
  kinds: StoreKind[];
  days: number[];
  currencies: StoreCurrency[];
}

/** `AdminStoreUpload`. */
export interface AdminStoreUploadDto {
  kind: 'animation' | 'still';
  url: string;
  bytes: number;
  contentType: string;
  /** An animation's format (null for a still). */
  format: 'SVGA' | 'MP4' | null;
  width: number | null;
  height: number | null;
  /** An MP4's suggested transparency (null otherwise). */
  detectedAlpha: 'NONE' | 'SIDE_BY_SIDE' | null;
  durationMs: number | null;
}

/** `AdminStoreSale`. */
export interface AdminStoreSaleDto {
  id: string;
  createdAt: string;
  item: { id: string; code: string; kind: StoreKind; nameAr: string; nameEn: string };
  buyer: UserSummaryDto;
  /** Null: bought for themselves. */
  recipient: UserSummaryDto | null;
  currency: StoreCurrency;
  days: number;
  price: number;
  extended: boolean;
}

/** `AdminStoreSales`: the latest sales (≤ `limit`) and the totals of the filter. */
export interface AdminStoreSalesDto {
  data: AdminStoreSaleDto[];
  totals: { purchases: number; gifts: number; coins: number; cherries: number };
}

type ItemRow = Prisma.StoreItemGetPayload<{ include: { prices: true } }>;

function refused(message: string): AppException {
  return new AppException(ErrorCode.ADMIN_ACTION_REFUSED, message);
}

/** An item's fields for the audit row (before / after). */
function snapshot(i: ItemRow): Prisma.InputJsonObject {
  return {
    code: i.bagCode,
    kind: i.kind,
    nameAr: i.nameAr,
    nameEn: i.nameEn,
    still: i.still,
    animation: i.animation,
    animationFormat: i.animationFormat,
    animationAlpha: i.animationAlpha,
    artWidth: i.artWidth,
    artHeight: i.artHeight,
    prices: sortedPrices(i.prices).map((p) => ({
      currency: p.currency,
      days: p.days,
      amount: Number(p.amount),
    })),
    sortOrder: i.sortOrder,
    isNew: i.isNew,
    enabled: i.enabled,
  };
}

/** The art columns of a body: the format follows the animation (from the URL when not given); MP4 needs an alpha. */
function artOf(
  body: Pick<
    CreateStoreItemBody,
    'still' | 'animation' | 'animationFormat' | 'animationAlpha' | 'artWidth' | 'artHeight'
  >,
  before?: ItemRow,
): Prisma.StoreItemUncheckedUpdateInput {
  const out: Prisma.StoreItemUncheckedUpdateInput = {};
  if (body.still !== undefined) out.still = body.still;
  if (body.artWidth !== undefined) out.artWidth = body.artWidth;
  if (body.artHeight !== undefined) out.artHeight = body.artHeight;
  const touched =
    body.animation !== undefined || body.animationFormat !== undefined || body.animationAlpha !== undefined;
  if (!touched) return out;
  const animation = body.animation !== undefined ? body.animation : (before?.animation ?? null);
  if (animation === null) {
    return { ...out, animation: null, animationFormat: null, animationAlpha: null };
  }
  // A new file without a format: told by its URL (the panel's upload names it `.mp4` or `.svga`).
  const keptFormat = body.animation === undefined ? (before?.animationFormat ?? null) : null;
  const format = body.animationFormat ?? keptFormat ?? (/\.mp4(\?|$)/i.test(animation) ? 'MP4' : 'SVGA');
  const keptAlpha = body.animation === undefined ? (before?.animationAlpha ?? null) : null;
  const alpha = format === 'MP4' ? (body.animationAlpha ?? keptAlpha ?? 'NONE') : null;
  return { ...out, animation, animationFormat: format, animationAlpha: alpha };
}

/**
 * «المتجر» in the admin panel (D270, CONVENTIONS §10.98.5): the OWNER adds items (a kind, names, art, prices per
 * duration per currency, the order, the «جديد» badge), changes them, switches them on or off — each change with a
 * reason, in one transaction with its audit row (`store.item.*`, before / after, `via: panel`) — and sees the sales.
 * Items are never deleted (purchases and bag rows point at them): one switched off is no longer sold; owners keep it to
 * its end. A new price applies to purchases from then on.
 */
@Injectable()
export class StoreAdminService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly clock: Clock,
    @Inject(OBJECT_STORAGE) private readonly storage: ObjectStorage,
    private readonly storageSettings: StorageSettingsStore,
  ) {}

  /** One art file (raw bytes): stored content-addressed; the URL goes into the item's form. */
  async upload(kind: 'animation' | 'still', body: unknown): Promise<AdminStoreUploadDto> {
    if (!Buffer.isBuffer(body) || body.length === 0) {
      throw new AppException(ErrorCode.ADMIN_ACTION_REFUSED, 'The file is empty.', [
        { field: 'file', issue: 'empty' },
      ]);
    }
    let file: StoreArtFile;
    try {
      file = kind === 'animation' ? await storeAnimationFile(body) : await storeStillFile(body);
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
      format: file.format,
      width: file.width,
      height: file.height,
      detectedAlpha: file.detectedAlpha,
      durationMs: file.durationMs,
    };
  }

  async list(): Promise<AdminStoreItemListDto> {
    const rows = await this.prisma.storeItem.findMany({
      include: { prices: true },
      orderBy: [{ kind: 'asc' }, { sortOrder: 'asc' }, { createdAt: 'asc' }, { id: 'asc' }],
    });
    const stats = await this.stats(
      this.prisma,
      rows.map((r) => r.id),
    );
    const kindRank = (k: string) => STORE_KINDS.indexOf(k as StoreKind);
    return {
      data: rows.sort((a, b) => kindRank(a.kind) - kindRank(b.kind)).map((r) => this.dto(r, stats.get(r.id))),
      kinds: [...STORE_KINDS],
      days: [...STORE_DAYS],
      currencies: [...STORE_CURRENCIES],
    };
  }

  async create(body: CreateStoreItemBody, by: AdminVia): Promise<AdminStoreItemDto> {
    return this.prisma.$transaction(async (tx) => {
      await tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtext('kabso:store-items'))`;
      if ((await tx.storeItem.count()) >= STORE_MAX_ITEMS)
        throw refused(`At most ${STORE_MAX_ITEMS} store items.`);
      const sortOrder =
        body.sortOrder ??
        ((await tx.storeItem.aggregate({ where: { kind: body.kind }, _max: { sortOrder: true } }))._max
          .sortOrder ?? 0) + 10;
      const code = newStoreBagCode();
      // The bag row first: the item is a bag catalogue item (never free; `assetKey` unused — the art is hosted).
      await tx.bagItem.create({
        data: {
          code,
          category: body.kind,
          nameAr: body.nameAr,
          nameEn: body.nameEn,
          assetKey: code,
          sortOrder,
          free: false,
        },
      });
      const art = artOf(body);
      const item = await tx.storeItem.create({
        data: {
          bagCode: code,
          kind: body.kind,
          nameAr: body.nameAr,
          nameEn: body.nameEn,
          still: (art.still as string | null | undefined) ?? null,
          animation: (art.animation as string | null | undefined) ?? null,
          animationFormat: (art.animationFormat as 'SVGA' | 'MP4' | null | undefined) ?? null,
          animationAlpha: (art.animationAlpha as 'NONE' | 'SIDE_BY_SIDE' | null | undefined) ?? null,
          artWidth: (art.artWidth as number | null | undefined) ?? null,
          artHeight: (art.artHeight as number | null | undefined) ?? null,
          sortOrder,
          isNew: body.isNew ?? false,
          enabled: body.enabled ?? false,
        },
      });
      await this.writePrices(tx, item.id, body.prices);
      const after = await this.load(tx, item.id);
      await tx.auditLog.create({
        data: {
          ...auditBy(by),
          action: AuditAction.STORE_ITEM_ADD,
          targetType: 'store_item',
          targetId: item.id,
          metadata: { after: snapshot(after), reason: body.reason, via: by.via },
        },
      });
      return this.dto(after, (await this.stats(tx, [item.id])).get(item.id));
    });
  }

  async update(id: string, body: UpdateStoreItemBody, by: AdminVia): Promise<AdminStoreItemDto> {
    return this.prisma.$transaction(async (tx) => {
      const before = await this.lockItem(tx, id);
      await tx.storeItem.update({
        where: { id },
        data: {
          ...(body.nameAr !== undefined ? { nameAr: body.nameAr } : {}),
          ...(body.nameEn !== undefined ? { nameEn: body.nameEn } : {}),
          ...(body.sortOrder !== undefined ? { sortOrder: body.sortOrder } : {}),
          ...(body.isNew !== undefined ? { isNew: body.isNew } : {}),
          ...artOf(body, before),
        },
      });
      // The bag row carries the names (the bag and the notifications read them there).
      if (body.nameAr !== undefined || body.nameEn !== undefined || body.sortOrder !== undefined) {
        await tx.bagItem.update({
          where: { code: before.bagCode },
          data: {
            ...(body.nameAr !== undefined ? { nameAr: body.nameAr } : {}),
            ...(body.nameEn !== undefined ? { nameEn: body.nameEn } : {}),
            ...(body.sortOrder !== undefined ? { sortOrder: body.sortOrder } : {}),
          },
        });
      }
      if (body.prices !== undefined) await this.writePrices(tx, id, body.prices);
      const after = await this.load(tx, id);
      await tx.auditLog.create({
        data: {
          ...auditBy(by),
          action: AuditAction.STORE_ITEM_UPDATE,
          targetType: 'store_item',
          targetId: id,
          metadata: { before: snapshot(before), after: snapshot(after), reason: body.reason, via: by.via },
        },
      });
      return this.dto(after, (await this.stats(tx, [id])).get(id));
    });
  }

  /** On / off. The same state again changes nothing and writes no audit row. */
  async setEnabled(id: string, enabled: boolean, reason: string, by: AdminVia): Promise<AdminStoreItemDto> {
    return this.prisma.$transaction(async (tx) => {
      const before = await this.lockItem(tx, id);
      if (before.enabled !== enabled) {
        await tx.storeItem.update({ where: { id }, data: { enabled } });
        await tx.auditLog.create({
          data: {
            ...auditBy(by),
            action: enabled ? AuditAction.STORE_ITEM_ENABLE : AuditAction.STORE_ITEM_DISABLE,
            targetType: 'store_item',
            targetId: id,
            metadata: {
              code: before.bagCode,
              before: before.enabled ? 'enabled' : 'disabled',
              after: enabled ? 'enabled' : 'disabled',
              reason,
              via: by.via,
            },
          },
        });
      }
      return this.dto(await this.load(tx, id), (await this.stats(tx, [id])).get(id));
    });
  }

  /** The latest sales (newest first, ≤ [limit]) and the totals of the filter (one item, or all). */
  async sales(itemId: string | undefined, limit: number): Promise<AdminStoreSalesDto> {
    const where = itemId ? { itemId } : {};
    const [rows, groups, gifts] = await Promise.all([
      this.prisma.storePurchase.findMany({
        where,
        orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
        take: limit,
        include: {
          item: { select: { id: true, bagCode: true, kind: true, nameAr: true, nameEn: true } },
          buyer: { select: USER_SUMMARY_SELECT },
          recipient: { select: USER_SUMMARY_SELECT },
        },
      }),
      this.prisma.storePurchase.groupBy({ by: ['currency'], where, _sum: { price: true }, _count: true }),
      this.prisma.storePurchase.count({
        where: { ...where, NOT: { recipientId: { equals: this.prisma.storePurchase.fields.buyerId } } },
      }),
    ]);
    const now = this.clock.now();
    const sum = (c: StoreCurrency) => Number(groups.find((g) => g.currency === c)?._sum.price ?? 0n);
    return {
      data: rows.map((r) => ({
        id: r.id,
        createdAt: r.createdAt.toISOString(),
        item: {
          id: r.item.id,
          code: r.item.bagCode,
          kind: r.item.kind,
          nameAr: r.item.nameAr,
          nameEn: r.item.nameEn,
        },
        buyer: userSummary(r.buyer, now),
        recipient: r.recipientId === r.buyerId ? null : userSummary(r.recipient, now),
        currency: r.currency,
        days: r.days,
        price: Number(r.price),
        extended: r.extended,
      })),
      totals: {
        purchases: groups.reduce((n, g) => n + g._count, 0),
        gifts,
        coins: sum('COINS'),
        cherries: sum('CHERRIES'),
      },
    };
  }

  private async writePrices(
    tx: Tx,
    itemId: string,
    prices: readonly { currency: StoreCurrency; days: number; amount: number }[],
  ): Promise<void> {
    await tx.storeItemPrice.deleteMany({ where: { itemId } });
    if (prices.length === 0) return;
    await tx.storeItemPrice.createMany({
      data: prices.map((p) => ({ itemId, currency: p.currency, days: p.days, amount: BigInt(p.amount) })),
    });
  }

  private async lockItem(tx: Tx, id: string): Promise<ItemRow> {
    const rows = await tx.$queryRaw<{ id: string }[]>`
      SELECT id::text AS id FROM store_items WHERE id = ${id}::uuid FOR UPDATE`;
    if (rows.length === 0) throw new AppException(ErrorCode.NOT_FOUND);
    return this.load(tx, id);
  }

  private load(tx: Tx, id: string): Promise<ItemRow> {
    return tx.storeItem.findUniqueOrThrow({ where: { id }, include: { prices: true } });
  }

  /** Owners now and purchases ever, per item. */
  private async stats(
    db: Tx | PrismaService,
    ids: readonly string[],
  ): Promise<Map<string, { owners: number; sold: number }>> {
    const out = new Map<string, { owners: number; sold: number }>();
    if (ids.length === 0) return out;
    const rows = await db.$queryRaw<{ id: string; owners: number; sold: number }[]>`
      SELECT si.id::text AS id,
             (SELECT count(*)::int FROM user_bag_items b
               WHERE b.item_code = si.bag_code AND (b.expires_at IS NULL OR b.expires_at > now())) AS owners,
             (SELECT count(*)::int FROM store_purchases p WHERE p.item_id = si.id) AS sold
        FROM store_items si WHERE si.id = ANY(${[...ids]}::uuid[])`;
    for (const r of rows) out.set(r.id, { owners: r.owners, sold: r.sold });
    return out;
  }

  private dto(i: ItemRow, stats: { owners: number; sold: number } | undefined): AdminStoreItemDto {
    return {
      id: i.id,
      code: i.bagCode,
      kind: i.kind,
      nameAr: i.nameAr,
      nameEn: i.nameEn,
      still: i.still,
      animation: i.animation,
      animationFormat: i.animationFormat,
      animationAlpha: i.animationAlpha,
      artWidth: i.artWidth,
      artHeight: i.artHeight,
      prices: sortedPrices(i.prices).map((p) => ({
        currency: p.currency,
        days: p.days,
        amount: Number(p.amount),
      })),
      sortOrder: i.sortOrder,
      isNew: i.isNew,
      enabled: i.enabled,
      owners: stats?.owners ?? 0,
      sold: stats?.sold ?? 0,
      createdAt: i.createdAt.toISOString(),
      updatedAt: i.updatedAt.toISOString(),
    };
  }
}
