import { AuditAction } from '../../common/audit/audit.service.js';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import type { Prisma } from '../../generated/prisma/client.js';
import type { PrismaService } from '../../prisma/prisma.service.js';

/**
 * v1.95-social (D301, CONVENTIONS §10.112): the app owner's profile «صفحة صاحب البرنامج». The owner is an ACTIVE account
 * holding the OWNER panel role, read from the roles held NOW (a revoke or a suspension applies at once). Shared by the
 * owner-profile module, the public profile, `GET /me`, the posts module and the media module (no Nest dependencies).
 */

type Db = Pick<PrismaService, 'userAdminPermission'> | Prisma.TransactionClient;

/** The two cover-video languages. */
export const COVER_VIDEO_LANGS = ['ar', 'en'] as const;
export type CoverVideoLang = (typeof COVER_VIDEO_LANGS)[number];

/** «رحلة Kabso»: the closed set of icons (CHECK `owner_journey_milestones_icon_known`). */
export const JOURNEY_ICONS = [
  'rocket',
  'users',
  'agency',
  'globe',
  'sparkles',
  'star',
  'trophy',
  'heart',
  'gift',
  'live',
  'crown',
  'flag',
] as const;
export type JourneyIcon = (typeof JOURNEY_ICONS)[number];
/** At most this many milestones per owner (409 `OWNER_JOURNEY_LIMIT`). */
export const MAX_JOURNEY_MILESTONES = 30;

/** «الإبلاغ عن موظف»: the reason categories (CHECK `owner_feedback_shape`). */
export const FEEDBACK_CATEGORIES = [
  'RUDENESS',
  'ABUSE_OF_POWER',
  'UNFAIR_ACTION',
  'NO_RESPONSE',
  'CORRUPTION',
  'OTHER',
] as const;
export type FeedbackCategory = (typeof FEEDBACK_CATEGORIES)[number];
export const FEEDBACK_KINDS = ['FEATURE', 'STAFF_REPORT'] as const;
export type FeedbackKind = (typeof FEEDBACK_KINDS)[number];
export const FEEDBACK_STATUSES = ['NEW', 'READ', 'DONE'] as const;
export type FeedbackStatus = (typeof FEEDBACK_STATUSES)[number];
/** Pictures per kind: a suggestion one, a staff report four. */
export const FEEDBACK_MAX_IMAGES: Readonly<Record<FeedbackKind, number>> = { FEATURE: 1, STAFF_REPORT: 4 };
/** At most this many submissions per account in any 24 hours (counted in the database). */
export const FEEDBACK_DAILY_LIMIT = 3;
export const FEEDBACK_WINDOW_MS = 24 * 3600 * 1000;
export const FEEDBACK_TEXT_MAX = 1000;

/** «لوحة المؤسس»: online = an authenticated request in the last 5 minutes (presence, §10.25). */
export const DASHBOARD_ONLINE_MINUTES = 5;
/** The dashboard is cached this long in Redis (one value for every owner). */
export const DASHBOARD_CACHE_SECONDS = 60;
export const DASHBOARD_CACHE_KEY = 'owner:dashboard:v1';

/** Whether `userId` is the app owner now: an ACTIVE account holding the OWNER panel role. */
export async function isKabsoOwner(db: Db, userId: string): Promise<boolean> {
  const row = await db.userAdminPermission.findFirst({
    where: { userId, permission: 'OWNER', user: { status: 'ACTIVE' } },
    select: { userId: true },
  });
  return row !== null;
}

/** 403 `OWNER_ONLY` unless `userId` is the app owner now. */
export async function assertKabsoOwner(db: Db, userId: string): Promise<void> {
  if (!(await isKabsoOwner(db, userId))) throw new AppException(ErrorCode.OWNER_ONLY);
}

/** `CoverVideoVariant`. */
export interface CoverVideoVariantDto {
  url: string;
  posterUrl: string;
  durationMs: number;
  width: number;
  height: number;
}

/** `OwnerCoverVideo`: the owner's cover videos per language (absent languages are left out). */
export interface OwnerCoverVideoDto {
  ar?: CoverVideoVariantDto;
  en?: CoverVideoVariantDto;
}

type CoverDb = Pick<PrismaService, 'ownerCoverVideo'> | Prisma.TransactionClient;

/** The owner's cover videos, with the public URLs `urlOf` gives each stored object. */
export async function coverVideoOf(
  db: CoverDb,
  userId: string,
  urlOf: (key: string) => string,
): Promise<OwnerCoverVideoDto> {
  const rows = await db.ownerCoverVideo.findMany({
    where: { userId },
    select: {
      lang: true,
      media: {
        select: { largeKey: true, posterKey: true, durationMs: true, width: true, height: true },
      },
    },
  });
  const out: OwnerCoverVideoDto = {};
  for (const r of rows) {
    if (r.lang !== 'ar' && r.lang !== 'en') continue;
    const m = r.media;
    if (m.posterKey === null || m.durationMs === null) continue;
    out[r.lang] = {
      url: urlOf(m.largeKey),
      posterUrl: urlOf(m.posterKey),
      durationMs: m.durationMs,
      width: m.width,
      height: m.height,
    };
  }
  return out;
}

/** v1.98-social (D307, §10.112.11) `OwnerBio`: the owner's bio per language (absent languages are left out). */
export interface OwnerBioDto {
  ar?: string;
  en?: string;
}

type BioDb = Pick<PrismaService, 'ownerBio'> | Prisma.TransactionClient;

/** The owner's stored bilingual bio (each language left out when it has none). */
export async function ownerBioOf(db: BioDb, userId: string): Promise<OwnerBioDto> {
  const row = await db.ownerBio.findUnique({ where: { userId }, select: { bioAr: true, bioEn: true } });
  return {
    ...(row?.bioAr ? { ar: row.bioAr } : {}),
    ...(row?.bioEn ? { en: row.bioEn } : {}),
  };
}

/**
 * `PublicProfile.kabsoOwner` / `.coverVideo` / `.ownerBio` and the same on `Me` (§10.112): only for the owner;
 * `coverVideo` only with at least one video; v1.98-social (D307) `ownerBio` only with at least one language.
 */
export async function ownerProfileFields(
  db: Db & CoverDb & BioDb,
  userId: string,
  urlOf: (key: string) => string,
): Promise<{ kabsoOwner?: true; coverVideo?: OwnerCoverVideoDto; ownerBio?: OwnerBioDto }> {
  if (!(await isKabsoOwner(db, userId))) return {};
  const coverVideo = await coverVideoOf(db, userId, urlOf);
  const ownerBio = await ownerBioOf(db, userId);
  return {
    kabsoOwner: true,
    ...(coverVideo.ar || coverVideo.en ? { coverVideo } : {}),
    ...(ownerBio.ar || ownerBio.en ? { ownerBio } : {}),
  };
}

/**
 * D301 follow-up (§10.112.7): queues the notification of a new announcement to every ACTIVE account (once per post: the
 * fan-out row is keyed by it) and audits the publish. The rows themselves are written after the request, in batches.
 * Returns whether this call queued it.
 */
export async function queueAnnouncementIn(
  tx: Prisma.TransactionClient,
  postId: string,
  ownerId: string,
  meta: { ip: string | null; requestId: string | null },
): Promise<boolean> {
  const queued = await tx.ownerAnnouncementFanout.createMany({ data: [{ postId }], skipDuplicates: true });
  if (queued.count === 0) return false;
  await tx.auditLog.create({
    data: {
      action: AuditAction.OWNER_ANNOUNCEMENT_PUBLISH,
      actorUserId: ownerId,
      targetType: 'post',
      targetId: postId,
      ip: meta.ip?.slice(0, 64) ?? null,
      requestId: meta.requestId,
    },
  });
  return true;
}

/** At most this many accounts are written per fan-out step. */
export const ANNOUNCEMENT_FANOUT_BATCH = 1000;
/** How often the fan-out sweeper looks for queued announcements. */
export const ANNOUNCEMENT_FANOUT_INTERVAL_MS = 5000;

/** The private object key of a feedback picture. */
export function feedbackImageKey(feedbackId: string, index: number): string {
  return `private/owner-feedback/${feedbackId}/${String(index)}.webp`;
}
