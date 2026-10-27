/**
 * Home banners (D124, contract v1.26-live draft, CONVENTIONS §10.26): the rules shared by the API
 * (`GET /home/banners`) and the `banner-admin` CLI, which is the only writer.
 */
import type { HomeBanner, MediaAsset, Prisma, PrismaClient } from '../../generated/prisma/client.js';
import { AuditAction } from '../../common/audit/audit.service.js';
import { uuidv7 } from '../levels/uuidv7.js';
import { isUuid } from '../live/live.schemas.js';
import { USERNAME_PATTERN } from '../users/username.js';
import {
  BANNER_WIDTH,
  processImage,
  ROOM_BANNER_HEIGHT,
  ROOM_BANNER_WIDTH,
  sniffImageType,
  THUMB_SIDE,
} from '../media/media-image.js';
import type { ObjectStorage } from '../media/object-storage.js';

/** At most this many banners are returned (the active ones with the lowest `sortOrder`). */
export const HOME_BANNER_LIMIT = 10;
/** Overlay text: one or two short lines on a 3:1 banner. */
export const BANNER_TITLE_MAX = 40;
export const BANNER_LINK_MAX = 512;
export const BANNER_TITLE_SIDES = ['LEFT', 'RIGHT'] as const;
export type BannerTitleSide = (typeof BANNER_TITLE_SIDES)[number];
/** v1.27.4-live (D137): the live hub (3:1) or the promo box inside a live (3:4). */
export const BANNER_PLACEMENTS = ['HOME', 'ROOM'] as const;
export type BannerPlacement = (typeof BANNER_PLACEMENTS)[number];
/** `GET /home/banners` may be cached by the client for a minute (it is per language). */
export const HOME_BANNERS_CACHE_CONTROL = 'private, max-age=60';

const UUID = '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}';

/**
 * The in-app routes a banner may open (D124 allowlist): the CP space, the families page, a live
 * hub tab, one live room, one profile. Anything else must be an https URL.
 */
const ROUTE_LINKS: readonly RegExp[] = [
  /^\/cp\/space$/,
  /^\/families$/,
  /^\/live\?tab=(trending|new|following)$/,
  new RegExp(`^/home/room/${UUID}$`),
  /^\/users\/[^/?#]+$/,
];

/** Why `link` may not be a banner's link, or null when it may. */
export function bannerLinkProblem(link: string): string | null {
  if (link.length === 0 || link.length > BANNER_LINK_MAX) {
    return `A link is 1–${String(BANNER_LINK_MAX)} characters`;
  }
  // eslint-disable-next-line no-control-regex
  if (/[\s\u0000-\u001f\u007f]/.test(link)) return 'A link has no spaces or control characters';
  if (link.startsWith('https://')) {
    let url: URL;
    try {
      url = new URL(link);
    } catch {
      return 'Not a valid https URL';
    }
    if (url.protocol !== 'https:' || url.hostname.length === 0) return 'Not a valid https URL';
    if (url.username !== '' || url.password !== '') return 'An https link carries no user name or password';
    return null;
  }
  if (!ROUTE_LINKS.some((pattern) => pattern.test(link))) {
    return 'The link must be /cp/space, /families, /live?tab=trending|new|following, /home/room/<roomId>, /users/<username> or an https:// URL';
  }
  const user = /^\/users\/(.+)$/.exec(link);
  if (user && !USERNAME_PATTERN.test(user[1]!)) return 'Not a valid username';
  return null;
}

/** What the CLI sets on a new banner. */
export interface BannerFields {
  readonly titleAr: string | null;
  readonly titleEn: string | null;
  readonly titleSide: BannerTitleSide;
  readonly link: string;
  readonly startsAt: Date;
  readonly endsAt: Date | null;
  readonly sortOrder: number;
  readonly enabled: boolean;
  /** v1.27.4-live (D137): `HOME` (default) or `ROOM`. */
  readonly placement?: BannerPlacement;
}

/** Every problem with [fields] (empty when they are acceptable). */
export function bannerFieldProblems(fields: BannerFields): string[] {
  const problems: string[] = [];
  const link = bannerLinkProblem(fields.link);
  if (link !== null) problems.push(link);
  for (const [name, value] of [
    ['--title-ar', fields.titleAr],
    ['--title-en', fields.titleEn],
  ] as const) {
    if (value === null) continue;
    const length = [...value.trim()].length;
    if (length === 0 || length > BANNER_TITLE_MAX) {
      problems.push(`${name} is 1–${String(BANNER_TITLE_MAX)} characters`);
    }
  }
  if (!BANNER_TITLE_SIDES.includes(fields.titleSide)) problems.push('--text-side is left or right');
  if (fields.placement !== undefined && !BANNER_PLACEMENTS.includes(fields.placement)) {
    problems.push('--placement is home or room');
  }
  if (Number.isNaN(fields.startsAt.getTime())) problems.push('--starts is not a date');
  if (fields.endsAt !== null) {
    if (Number.isNaN(fields.endsAt.getTime())) problems.push('--ends is not a date');
    else if (fields.endsAt.getTime() <= fields.startsAt.getTime())
      problems.push('--ends must be after --starts');
  }
  if (!Number.isInteger(fields.sortOrder) || fields.sortOrder < 0 || fields.sortOrder > 1_000_000) {
    problems.push('--sort is a whole number 0–1000000');
  }
  return problems;
}

export class BannerError extends Error {}

/**
 * Stores an image file as a `HOME_BANNER` media asset owned by `ownerId` (the CLI's `--image`):
 * the same checks as an upload (signature, decoder, size limits, metadata stripped), cover-cropped
 * to 1 500 × 500 and 320 × 107 WebP. The asset is unattached until [addBannerIn] claims it.
 */
export async function storeBannerImage(
  prisma: Pick<PrismaClient, 'mediaAsset'>,
  storage: ObjectStorage,
  ownerId: string,
  bytes: Buffer,
  placement: BannerPlacement = 'HOME',
): Promise<MediaAsset> {
  const type = sniffImageType(bytes);
  if (type === null) throw new BannerError('The file is not a JPEG, PNG or WebP image');
  let image;
  try {
    // D137: a ROOM banner is cover-cropped to 3:4 (600 × 800 and 240 × 320).
    image = await processImage(bytes, type, BANNER_WIDTH, placement === 'ROOM' ? 'roomBanner' : 'banner');
  } catch {
    throw new BannerError('The image could not be read (or is larger than 8 000 px / 50 MP)');
  }
  const id = uuidv7();
  const largeKey = `media/${id}/${String(placement === 'ROOM' ? ROOM_BANNER_WIDTH : BANNER_WIDTH)}.webp`;
  const thumbKey = `media/${id}/${String(THUMB_SIDE)}.webp`;
  const cache = 'public, max-age=31536000, immutable';
  await storage.put(largeKey, image.large, 'image/webp', cache);
  await storage.put(thumbKey, image.thumb, 'image/webp', cache);
  return prisma.mediaAsset.create({
    data: {
      id,
      ownerId,
      kind: 'HOME_BANNER',
      width: image.width,
      height: image.height,
      blurhash: image.blurhash,
      largeKey,
      thumbKey,
      byteSize: image.large.length,
    },
  });
}

/**
 * Adds a banner on the `HOME_BANNER` asset `mediaId` inside the caller's transaction: the asset
 * must be READY, unattached and less than 24 hours old (the media sweeper deletes it afterwards);
 * it is attached here (locked, so it cannot serve two banners). Writes the `banner.add` audit row.
 * Throws [BannerError] when the fields or the asset are not acceptable.
 */
export async function addBannerIn(
  tx: Prisma.TransactionClient,
  mediaId: string,
  fields: BannerFields,
): Promise<HomeBanner> {
  const problems = bannerFieldProblems(fields);
  if (problems.length > 0) throw new BannerError(problems.join('\n'));
  if (!isUuid(mediaId)) throw new BannerError('--media is a media id (UUID)');
  const id = mediaId.toLowerCase();
  const locked = await tx.$queryRaw<
    { kind: string; attached: boolean; fresh: boolean; width: number; height: number }[]
  >`
    SELECT kind, attached_at IS NOT NULL AS attached, created_at > now() - interval '24 hours' AS fresh,
           width, height
    FROM media_assets WHERE id = ${id}::uuid FOR UPDATE`;
  const asset = locked[0];
  if (!asset) throw new BannerError(`No media ${id}.`);
  if (asset.kind !== 'HOME_BANNER') {
    throw new BannerError(`Media ${id} is a ${asset.kind}, not a HOME_BANNER upload.`);
  }
  if (asset.attached) throw new BannerError(`Media ${id} is already used.`);
  if (!asset.fresh) throw new BannerError(`Media ${id} is older than 24 hours; upload it again.`);
  // D137: a ROOM banner's picture is 3:4 (stored by `--image` with `--placement room`); a HOME
  // banner's is never that one.
  const placement = fields.placement ?? 'HOME';
  const roomShaped = asset.width === ROOM_BANNER_WIDTH && asset.height === ROOM_BANNER_HEIGHT;
  if ((placement === 'ROOM') !== roomShaped) {
    throw new BannerError(
      placement === 'ROOM'
        ? `Media ${id} is not a 600 × 800 room banner picture; add it with --image and --placement room.`
        : `Media ${id} is a room banner picture (600 × 800); add it with --placement room.`,
    );
  }
  await tx.mediaAsset.update({ where: { id }, data: { attachedAt: new Date() } });
  const banner = await tx.homeBanner.create({
    data: {
      mediaId: id,
      titleAr: fields.titleAr?.trim() ?? null,
      titleEn: fields.titleEn?.trim() ?? null,
      titleSide: fields.titleSide,
      link: fields.link,
      startsAt: fields.startsAt,
      endsAt: fields.endsAt,
      sortOrder: fields.sortOrder,
      enabled: fields.enabled,
      placement,
    },
  });
  await tx.auditLog.create({
    data: {
      action: AuditAction.BANNER_ADD,
      targetType: 'home_banner',
      targetId: banner.id,
      metadata: {
        mediaId: id,
        link: banner.link,
        titleAr: banner.titleAr,
        titleEn: banner.titleEn,
        titleSide: banner.titleSide,
        startsAt: banner.startsAt.toISOString(),
        endsAt: banner.endsAt?.toISOString() ?? null,
        sortOrder: banner.sortOrder,
        enabled: banner.enabled,
        placement: banner.placement,
        via: 'cli',
      },
    },
  });
  return banner;
}

/**
 * Turns a banner on or off. Returns null when there is no such banner, false when it already was
 * in that state (nothing written), true when it changed (with a `banner.enable` / `banner.disable`
 * audit row).
 */
export async function setBannerEnabledIn(
  tx: Prisma.TransactionClient,
  bannerId: string,
  enabled: boolean,
): Promise<boolean | null> {
  if (!isUuid(bannerId)) return null;
  const id = bannerId.toLowerCase();
  const changed = await tx.homeBanner.updateMany({ where: { id, enabled: !enabled }, data: { enabled } });
  if (changed.count === 0) {
    return (await tx.homeBanner.findUnique({ where: { id }, select: { id: true } })) ? false : null;
  }
  await tx.auditLog.create({
    data: {
      action: enabled ? AuditAction.BANNER_ENABLE : AuditAction.BANNER_DISABLE,
      targetType: 'home_banner',
      targetId: id,
      metadata: { via: 'cli' },
    },
  });
  return true;
}

/**
 * Deletes a banner and its picture's asset row (`banner.remove` audit row). Returns the object keys
 * the caller deletes from storage after the commit, or null when there is no such banner.
 */
export async function removeBannerIn(
  tx: Prisma.TransactionClient,
  bannerId: string,
): Promise<string[] | null> {
  if (!isUuid(bannerId)) return null;
  const id = bannerId.toLowerCase();
  const banner = await tx.homeBanner.findUnique({ where: { id }, include: { media: true } });
  if (!banner) return null;
  await tx.homeBanner.delete({ where: { id } });
  await tx.mediaAsset.delete({ where: { id: banner.mediaId } });
  await tx.auditLog.create({
    data: {
      action: AuditAction.BANNER_REMOVE,
      targetType: 'home_banner',
      targetId: id,
      metadata: { mediaId: banner.mediaId, link: banner.link, via: 'cli' },
    },
  });
  return [...new Set([banner.media.largeKey, banner.media.thumbKey])];
}

/** A banner is shown now: enabled and `startsAt <= now < endsAt` (no end = open). */
export function activeBannerWhere(now: Date, placement?: BannerPlacement): Prisma.HomeBannerWhereInput {
  return {
    enabled: true,
    startsAt: { lte: now },
    OR: [{ endsAt: null }, { endsAt: { gt: now } }],
    ...(placement === undefined ? {} : { placement }),
  };
}

/** Lowest `sortOrder` first, then the latest start, then the id. */
export const BANNER_ORDER: Prisma.HomeBannerOrderByWithRelationInput[] = [
  { sortOrder: 'asc' },
  { startsAt: 'desc' },
  { id: 'asc' },
];
