import { Injectable } from '@nestjs/common';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import type { Prisma, VerificationPurpose } from '../../generated/prisma/client.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { generateSecret, isWellFormedSecret, sha256Hex } from './tokens.js';

type Db = Prisma.TransactionClient | PrismaService;

/** Owns `verification_tokens`: single-use, hashed, expiring tokens. */
@Injectable()
export class VerificationTokensService {
  constructor(private readonly prisma: PrismaService) {}

  /**
   * Issues a fresh token and invalidates any outstanding token of the same purpose for the
   * user. Returns the raw token (to be mailed; never stored).
   */
  async issue(
    db: Db,
    userId: string,
    purpose: VerificationPurpose,
    ttlSeconds: number,
    now: Date = new Date(),
  ): Promise<{ token: string; expiresAt: Date }> {
    await db.verificationToken.updateMany({
      where: { userId, purpose, consumedAt: null },
      data: { consumedAt: now },
    });
    const token = generateSecret();
    const expiresAt = new Date(now.getTime() + ttlSeconds * 1000);
    await db.verificationToken.create({
      data: { userId, purpose, tokenHash: sha256Hex(token), expiresAt, createdAt: now },
    });
    return { token, expiresAt };
  }

  /**
   * Atomically consumes a token inside `tx`. Unknown/malformed → TOKEN_INVALID (422);
   * expired or already used → TOKEN_EXPIRED (410). Returns the owning user id.
   */
  async consume(
    tx: Prisma.TransactionClient,
    rawToken: string,
    purpose: VerificationPurpose,
    now: Date = new Date(),
  ): Promise<string> {
    const record = await this.check(tx, rawToken, purpose, now);
    const consumed = await tx.verificationToken.updateMany({
      where: { id: record.id, consumedAt: null, expiresAt: { gt: now } },
      data: { consumedAt: now },
    });
    if (consumed.count !== 1) throw new AppException(ErrorCode.TOKEN_EXPIRED);
    return record.userId;
  }

  /** Validates a token without consuming it (throws TOKEN_INVALID / TOKEN_EXPIRED). */
  async check(
    db: Db,
    rawToken: string,
    purpose: VerificationPurpose,
    now: Date = new Date(),
  ): Promise<{ id: string; userId: string }> {
    if (!isWellFormedSecret(rawToken)) throw new AppException(ErrorCode.TOKEN_INVALID);
    const record = await db.verificationToken.findUnique({
      where: { tokenHash: sha256Hex(rawToken) },
      select: { id: true, userId: true, purpose: true, expiresAt: true, consumedAt: true },
    });
    if (!record || record.purpose !== purpose) throw new AppException(ErrorCode.TOKEN_INVALID);
    if (record.consumedAt !== null || record.expiresAt <= now) {
      throw new AppException(ErrorCode.TOKEN_EXPIRED);
    }
    return { id: record.id, userId: record.userId };
  }
}
