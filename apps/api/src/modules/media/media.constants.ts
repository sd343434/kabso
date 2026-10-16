/**
 * Image rules of contract v1.4 (CONVENTIONS §11.2). These are constants of the contract, not
 * settings: `GET /media/config` reports them so the client can pre-check a file.
 */

export type ApiMediaPurpose = 'avatar' | 'room_cover';
export type DbMediaPurpose = 'AVATAR' | 'ROOM_COVER';
export type MediaContentType = 'image/jpeg' | 'image/png' | 'image/webp';
export type MediaFailureIssue = 'too_big' | 'too_small' | 'invalid_format';
export type ModerationStatus = 'PENDING' | 'APPROVED' | 'REJECTED';

export const MEDIA_CONTENT_TYPES: readonly MediaContentType[] = ['image/jpeg', 'image/png', 'image/webp'];

/** Width × height limit, read from the header before decoding; also the decoder's pixel limit. */
export const MEDIA_MAX_PIXELS = 40_000_000;
export const MEDIA_MAX_SIDE = 8192;
/** Largest `byteSize` the schema accepts (the room-cover limit); per purpose below. */
export const MEDIA_MAX_DECLARED_BYTES = 10_485_760;

export interface DerivativeSpec {
  /** Name in the public key: `<a|c>/<token>/<label>.webp`. */
  readonly label: string;
  readonly width: number;
  readonly height: number;
}

export interface PurposeRules {
  readonly api: ApiMediaPurpose;
  readonly db: DbMediaPurpose;
  /** Public key prefix (`a` avatars, `c` covers). */
  readonly keyPrefix: 'a' | 'c';
  readonly maxBytes: number;
  /** Output aspect ratio width:height (server centre-crop). */
  readonly ratio: readonly [number, number];
  readonly aspectRatio: '1:1' | '3:4';
  /** Minimum size of the largest centred crop. */
  readonly minWidth: number;
  readonly minHeight: number;
  /** Main derivative (`avatarUrl` / `coverUrl`). */
  readonly main: DerivativeSpec;
  /** Thumbnail (`avatarThumbUrl` / `coverThumbUrl`). */
  readonly thumb: DerivativeSpec;
}

export const PURPOSES: Readonly<Record<ApiMediaPurpose, PurposeRules>> = {
  avatar: {
    api: 'avatar',
    db: 'AVATAR',
    keyPrefix: 'a',
    maxBytes: 5_242_880,
    ratio: [1, 1],
    aspectRatio: '1:1',
    minWidth: 128,
    minHeight: 128,
    main: { label: '512', width: 512, height: 512 },
    thumb: { label: '128', width: 128, height: 128 },
  },
  room_cover: {
    api: 'room_cover',
    db: 'ROOM_COVER',
    keyPrefix: 'c',
    maxBytes: 10_485_760,
    ratio: [3, 4],
    aspectRatio: '3:4',
    minWidth: 480,
    minHeight: 640,
    main: { label: '960', width: 960, height: 1280 },
    thumb: { label: '480', width: 480, height: 640 },
  },
};

export function rulesForDb(purpose: DbMediaPurpose): PurposeRules {
  return purpose === 'AVATAR' ? PURPOSES.avatar : PURPOSES.room_cover;
}

/** `complete` stays possible until `expiresAt` + 5 minutes (CONVENTIONS §11.3). */
export const COMPLETE_GRACE_MS = 5 * 60 * 1000;

/** Public objects are immutable; a failed CDN purge still ends within a day (§11.6). */
export const PUBLIC_CACHE_CONTROL = 'public, max-age=86400, immutable';

/** FAILED rows are kept 7 days, EXPIRED / DELETED rows 30 days (DB_PHASE2_MEDIA §4). */
export const FAILED_ROW_RETENTION_MS = 7 * 24 * 3600 * 1000;
export const TERMINAL_ROW_RETENTION_MS = 30 * 24 * 3600 * 1000;
