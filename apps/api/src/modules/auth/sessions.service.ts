import { Inject, Injectable } from '@nestjs/common';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import type { Prisma } from '../../generated/prisma/client.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import type { DeviceInfo } from './auth.schemas.js';
import { formatRefreshToken, generateSecret, hashesEqual, parseRefreshToken, sha256Hex } from './tokens.js';

export enum RevokedReason {
  LOGOUT = 'LOGOUT',
  USER_REVOKED = 'USER_REVOKED',
  REFRESH_REUSE = 'REFRESH_REUSE',
  PASSWORD_RESET = 'PASSWORD_RESET',
}

export interface SessionClient {
  readonly device?: DeviceInfo | undefined;
  readonly ip: string | null;
  readonly userAgent: string | null;
}

export interface IssuedSession {
  readonly sessionId: string;
  readonly refreshToken: string;
  readonly refreshTokenExpiresAt: Date;
}

/** `SessionInfo` response (openapi). */
export interface SessionInfoDto {
  id: string;
  current: boolean;
  deviceName: string | null;
  platform: 'android' | 'ios' | 'web' | 'other' | null;
  appVersion: string | null;
  ipCountry: string | null;
  createdAt: string;
  lastUsedAt: string;
}

export type RotationOutcome =
  | { readonly kind: 'rotated'; readonly userId: string; readonly session: IssuedSession }
  | {
      readonly kind: 'reuse';
      readonly userId: string;
      readonly sessionId: string;
      readonly matchedPrevious: boolean;
    };

const MAX_LISTED_SESSIONS = 50;
const PLATFORMS = new Set(['android', 'ios', 'web', 'other']);

function minDate(a: Date, b: Date): Date {
  return a.getTime() <= b.getTime() ? a : b;
}

/** Owns the `sessions` table: creation, rotation (CAS), revocation and access checks. */
@Injectable()
export class SessionsService {
  constructor(
    private readonly prisma: PrismaService,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
  ) {}

  async create(
    tx: Prisma.TransactionClient | PrismaService,
    userId: string,
    client: SessionClient,
    now: Date = new Date(),
  ): Promise<IssuedSession> {
    const secret = generateSecret();
    const absoluteExpiresAt = new Date(now.getTime() + this.config.refresh.absoluteTtlSeconds * 1000);
    const expiresAt = minDate(
      new Date(now.getTime() + this.config.refresh.ttlSeconds * 1000),
      absoluteExpiresAt,
    );
    const session = await tx.session.create({
      data: {
        userId,
        refreshTokenHash: sha256Hex(secret),
        deviceName: client.device?.name || null,
        platform: client.device?.platform ?? null,
        appVersion: client.device?.appVersion || null,
        ip: client.ip?.slice(0, 64) ?? null,
        userAgent: client.userAgent,
        createdAt: now,
        lastUsedAt: now,
        expiresAt,
        absoluteExpiresAt,
      },
      select: { id: true },
    });
    return {
      sessionId: session.id,
      refreshToken: formatRefreshToken(session.id, secret),
      refreshTokenExpiresAt: expiresAt,
    };
  }

  /**
   * Rotates a refresh token. The new secret is written with a compare-and-swap on the current
   * hash, so two concurrent refreshes with the same token cannot both succeed. Presenting a
   * secret that is not the current one for a live session is treated as reuse: the session is
   * revoked (REFRESH_REUSE).
   */
  async rotate(refreshToken: string, now: Date = new Date()): Promise<RotationOutcome> {
    const parsed = parseRefreshToken(refreshToken);
    if (!parsed) throw new AppException(ErrorCode.AUTH_REFRESH_INVALID);

    const session = await this.prisma.session.findUnique({
      where: { id: parsed.sessionId },
      select: {
        id: true,
        userId: true,
        refreshTokenHash: true,
        previousRefreshTokenHash: true,
        expiresAt: true,
        absoluteExpiresAt: true,
        revokedAt: true,
        user: { select: { status: true } },
      },
    });
    if (!session || session.revokedAt) throw new AppException(ErrorCode.AUTH_REFRESH_INVALID);

    const presentedHash = sha256Hex(parsed.secret);
    if (!hashesEqual(presentedHash, session.refreshTokenHash)) {
      const revoked = await this.prisma.session.updateMany({
        where: { id: session.id, revokedAt: null },
        data: { revokedAt: now, revokedReason: RevokedReason.REFRESH_REUSE },
      });
      if (revoked.count === 0) throw new AppException(ErrorCode.AUTH_REFRESH_INVALID);
      return {
        kind: 'reuse',
        userId: session.userId,
        sessionId: session.id,
        matchedPrevious:
          session.previousRefreshTokenHash !== null &&
          hashesEqual(presentedHash, session.previousRefreshTokenHash),
      };
    }

    if (session.expiresAt <= now || session.absoluteExpiresAt <= now) {
      throw new AppException(ErrorCode.AUTH_REFRESH_INVALID);
    }
    if (session.user.status === 'SUSPENDED') throw new AppException(ErrorCode.ACCOUNT_SUSPENDED);
    if (session.user.status !== 'ACTIVE') throw new AppException(ErrorCode.AUTH_REFRESH_INVALID);

    const secret = generateSecret();
    const expiresAt = minDate(
      new Date(now.getTime() + this.config.refresh.ttlSeconds * 1000),
      session.absoluteExpiresAt,
    );
    const swapped = await this.prisma.session.updateMany({
      where: { id: session.id, refreshTokenHash: presentedHash, revokedAt: null },
      data: {
        refreshTokenHash: sha256Hex(secret),
        previousRefreshTokenHash: presentedHash,
        rotationCounter: { increment: 1 },
        lastUsedAt: now,
        expiresAt,
      },
    });
    // Lost the race against a concurrent refresh with the same token.
    if (swapped.count !== 1) throw new AppException(ErrorCode.AUTH_REFRESH_INVALID);

    return {
      kind: 'rotated',
      userId: session.userId,
      session: {
        sessionId: session.id,
        refreshToken: formatRefreshToken(session.id, secret),
        refreshTokenExpiresAt: expiresAt,
      },
    };
  }

  /** True when the session exists, belongs to `userId`, is live, and the user is ACTIVE. */
  async isActive(sessionId: string, userId: string, now: Date = new Date()): Promise<boolean> {
    const session = await this.prisma.session.findUnique({
      where: { id: sessionId },
      select: {
        userId: true,
        revokedAt: true,
        expiresAt: true,
        absoluteExpiresAt: true,
        user: { select: { status: true } },
      },
    });
    return (
      session !== null &&
      session.userId === userId &&
      session.revokedAt === null &&
      session.expiresAt > now &&
      session.absoluteExpiresAt > now &&
      session.user.status === 'ACTIVE'
    );
  }

  /** Revokes one live session of `userId`; false if none matched (absent, foreign, revoked). */
  async revoke(
    userId: string,
    sessionId: string,
    reason: RevokedReason,
    now: Date = new Date(),
  ): Promise<boolean> {
    const result = await this.prisma.session.updateMany({
      where: { id: sessionId, userId, revokedAt: null },
      data: { revokedAt: now, revokedReason: reason },
    });
    return result.count > 0;
  }

  async revokeAllForUser(
    tx: Prisma.TransactionClient | PrismaService,
    userId: string,
    reason: RevokedReason,
    now: Date = new Date(),
  ): Promise<number> {
    const result = await tx.session.updateMany({
      where: { userId, revokedAt: null },
      data: { revokedAt: now, revokedReason: reason },
    });
    return result.count;
  }

  async listActive(
    userId: string,
    currentSessionId: string,
    now: Date = new Date(),
  ): Promise<SessionInfoDto[]> {
    const sessions = await this.prisma.session.findMany({
      where: { userId, revokedAt: null, expiresAt: { gt: now }, absoluteExpiresAt: { gt: now } },
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
      take: MAX_LISTED_SESSIONS,
      select: {
        id: true,
        deviceName: true,
        platform: true,
        appVersion: true,
        createdAt: true,
        lastUsedAt: true,
      },
    });
    return sessions.map((s) => ({
      id: s.id,
      current: s.id === currentSessionId,
      deviceName: s.deviceName,
      platform: s.platform && PLATFORMS.has(s.platform) ? (s.platform as SessionInfoDto['platform']) : null,
      appVersion: s.appVersion,
      ipCountry: null,
      createdAt: s.createdAt.toISOString(),
      lastUsedAt: s.lastUsedAt.toISOString(),
    }));
  }
}
