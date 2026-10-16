/**
 * Moderation hook (CONVENTIONS §11.5). After `complete`, the media service hands the processed
 * image to this port asynchronously; `complete` never waits for it.
 *
 * - `none` (default, D45: no provider approved): returns null, so images stay PENDING and are
 *   visible to their owner only. Fails closed.
 * - `allow_all`: approves every image that passed verification without any content check. Local
 *   development and tests only; the API refuses to boot with it in production (env.schema.ts).
 *
 * A real provider adapter is added by contract patch, with owner approval.
 */
export const MEDIA_MODERATION = Symbol('MEDIA_MODERATION');

export type ModerationDecision = 'APPROVED' | 'REJECTED';

export interface ModerationSubject {
  readonly uploadId: string;
  readonly purpose: 'AVATAR' | 'ROOM_COVER';
  /** The main WebP derivative (what other users would see). */
  readonly image: Uint8Array;
}

export interface MediaModerationPort {
  /** Adapter name recorded in `moderation_source`. */
  readonly source: string;
  /** A decision, or null to leave the image PENDING. */
  review(subject: ModerationSubject): Promise<ModerationDecision | null>;
}

export class NoModeration implements MediaModerationPort {
  readonly source = 'none';
  async review(): Promise<null> {
    return null;
  }
}

export class AllowAllModeration implements MediaModerationPort {
  readonly source = 'allow_all';
  async review(): Promise<ModerationDecision> {
    return 'APPROVED';
  }
}

export function moderationFor(provider: 'none' | 'allow_all'): MediaModerationPort {
  return provider === 'allow_all' ? new AllowAllModeration() : new NoModeration();
}
