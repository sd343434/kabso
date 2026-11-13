import { Injectable } from '@nestjs/common';
import { AppException } from '../../common/errors/app-exception.js';
import { Clock } from '../../common/time/clock.js';
import { zodErrorToDetails } from '../../common/validation/zod-validation.pipe.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { violatedUniqueIndex } from '../users/users.service.js';
import { registerPushTokenSchema } from './push.schemas.js';

/** A token not seen for this long is dropped by the sweeper (the app re-registers at launch). */
export const PUSH_TOKEN_STALE_MS = 60 * 24 * 3600_000;

/** One token the push service may send to (a live session of an ACTIVE account). */
export interface PushTarget {
  readonly userId: string;
  readonly token: string;
  /** The account language (`user_profiles.locale`): `en`, else Arabic. */
  readonly locale: 'ar' | 'en';
}

/**
 * v1.30-live (D152, CONVENTIONS §11.12): `device_tokens`, one Firebase token per session. Owned by
 * the push module; the auth module deletes a session's token when it revokes the session.
 */
@Injectable()
export class PushTokensService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly clock: Clock,
  ) {}

  /** `PUT /me/push-token`: this session's token (replacing its old one; moved from another session). */
  async register(userId: string, sessionId: string, body: unknown): Promise<void> {
    const parsed = registerPushTokenSchema.safeParse(body ?? {}, { reportInput: true });
    if (!parsed.success) throw AppException.validation(zodErrorToDetails(parsed.error));
    const { token, platform, appVersion } = parsed.data;
    for (let attempt = 0; ; attempt += 1) {
      const now = this.clock.now();
      try {
        await this.prisma.$transaction(async (tx) => {
          // The same phone signed in to another account (or a stale row): the token moves here.
          await tx.deviceToken.deleteMany({ where: { token, NOT: { sessionId } } });
          await tx.deviceToken.upsert({
            where: { sessionId },
            create: { userId, sessionId, token, platform, appVersion, createdAt: now, lastSeenAt: now },
            update: { userId, token, platform, appVersion, lastSeenAt: now },
          });
        });
        return;
      } catch (err) {
        // Two sessions registered the same token at the same moment: once more, then it is ours.
        if (attempt === 0 && violatedUniqueIndex(err) !== null) continue;
        throw err;
      }
    }
  }

  /** `DELETE /me/push-token` (and logout): the session's token, if any. */
  async unregister(sessionId: string): Promise<void> {
    await this.prisma.deviceToken.deleteMany({ where: { sessionId } });
  }

  /** Tokens Firebase answered as invalid. */
  async removeTokens(tokens: readonly string[]): Promise<number> {
    if (tokens.length === 0) return 0;
    const res = await this.prisma.deviceToken.deleteMany({ where: { token: { in: [...tokens] } } });
    return res.count;
  }

  /**
   * The ANDROID tokens of `userIds` that may receive a push now: the account is ACTIVE and the
   * token's session is neither revoked nor expired (iOS waits for APNs, §11.12).
   */
  async targets(userIds: readonly string[]): Promise<PushTarget[]> {
    if (userIds.length === 0) return [];
    const now = this.clock.now();
    const rows = await this.prisma.deviceToken.findMany({
      where: {
        userId: { in: [...new Set(userIds)] },
        platform: 'ANDROID',
        user: { status: 'ACTIVE' },
        session: { revokedAt: null, expiresAt: { gt: now }, absoluteExpiresAt: { gt: now } },
      },
      select: { userId: true, token: true, user: { select: { profile: { select: { locale: true } } } } },
    });
    return rows.map((r) => ({
      userId: r.userId,
      token: r.token,
      locale: r.user.profile?.locale === 'en' ? 'en' : 'ar',
    }));
  }

  /** Drops tokens of ended sessions and tokens not seen for 60 days. Returns how many. */
  async sweep(now: Date = this.clock.now()): Promise<number> {
    const stale = new Date(now.getTime() - PUSH_TOKEN_STALE_MS);
    const res = await this.prisma.deviceToken.deleteMany({
      where: {
        OR: [
          { lastSeenAt: { lt: stale } },
          { session: { revokedAt: { not: null } } },
          { session: { expiresAt: { lte: now } } },
          { session: { absoluteExpiresAt: { lte: now } } },
        ],
      },
    });
    return res.count;
  }
}
