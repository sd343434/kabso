import { rulesForDb, type DbMediaPurpose, type ModerationStatus } from './media.constants.js';

/** 128-bit CSPRNG value, base64url without padding (DB_PHASE2_MEDIA §2 `public_token`). */
export const PUBLIC_TOKEN_PATTERN = /^[A-Za-z0-9_-]{22}$/;

/** What the URL builder and the visibility rule need from a `media_objects` row. */
export interface MediaRef {
  readonly ownerUserId: string;
  readonly purpose: DbMediaPurpose;
  readonly status: string;
  readonly publicToken: string | null;
  readonly moderationStatus: ModerationStatus | null;
}

export interface ImageUrls {
  readonly url: string | null;
  readonly thumbUrl: string | null;
}

export const NO_IMAGE: ImageUrls = { url: null, thumbUrl: null };

/** Public object keys of a processed image: `<a|c>/<token>/<label>.webp` (CONVENTIONS §11.11). */
export function publicKeys(purpose: DbMediaPurpose, token: string): { main: string; thumb: string } {
  const rules = rulesForDb(purpose);
  return {
    main: `${rules.keyPrefix}/${token}/${rules.main.label}.webp`,
    thumb: `${rules.keyPrefix}/${token}/${rules.thumb.label}.webp`,
  };
}

/**
 * Builds public image URLs (CONVENTIONS §11.10, DB_PHASE2_MEDIA §3): always
 * `MEDIA_PUBLIC_BASE_URL` + a key the server generated; nothing is stored, nothing comes from a
 * client. A token that is not a well-formed server token, or a result outside the base, gives
 * null instead of a URL.
 */
export class MediaUrls {
  constructor(private readonly baseUrl: string | null) {}

  /** URLs of a READY image, ignoring visibility (owner preview); null without a base or token. */
  urlsOf(ref: MediaRef | null): ImageUrls {
    if (!ref || this.baseUrl === null || ref.status !== 'READY') return NO_IMAGE;
    if (ref.publicToken === null || !PUBLIC_TOKEN_PATTERN.test(ref.publicToken)) return NO_IMAGE;
    if (ref.moderationStatus === 'REJECTED') return NO_IMAGE;
    const keys = publicKeys(ref.purpose, ref.publicToken);
    const prefix = `${this.baseUrl}/`;
    const url = `${prefix}${keys.main}`;
    const thumbUrl = `${prefix}${keys.thumb}`;
    if (!url.startsWith(prefix) || !thumbUrl.startsWith(prefix)) return NO_IMAGE;
    return { url, thumbUrl };
  }

  /**
   * The visibility rule (CONVENTIONS §11.5): the owner sees an image while PENDING or APPROVED;
   * everyone else only when APPROVED. Otherwise both URLs are null.
   */
  visibleUrls(ref: MediaRef | null, viewerId: string | null): ImageUrls {
    if (!ref) return NO_IMAGE;
    const visible =
      ref.moderationStatus === 'APPROVED' ||
      (ref.moderationStatus === 'PENDING' && viewerId !== null && viewerId === ref.ownerUserId);
    return visible ? this.urlsOf(ref) : NO_IMAGE;
  }
}
