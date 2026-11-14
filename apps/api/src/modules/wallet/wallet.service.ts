import { Injectable } from '@nestjs/common';
import type { Prisma } from '../../generated/prisma/client.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { creditFamilyForSpendIn, FAMILY_SPEND_REASONS } from '../families/family-points.js';
import { creditIn, debitIn, type WalletChange, type WalletLedgerReason } from './wallet-ledger.js';

/** `Wallet` (openapi v1.19-live, CP-017). */
export interface WalletDto {
  coins: number;
}

/**
 * Coin balances (CP-017, D104, CONVENTIONS §10.19). Coins come only from an admin on the server
 * (`wallet-admin grant`, purchases wait for B5) and are spent by bullet messages. Every change is
 * a `wallet_ledger` row written in the same transaction.
 */
@Injectable()
export class WalletService {
  constructor(private readonly prisma: PrismaService) {}

  /** `GET /wallet/me`: 0 for a user who never had coins. */
  async mine(userId: string): Promise<WalletDto> {
    const wallet = await this.prisma.wallet.findUnique({ where: { userId }, select: { coins: true } });
    return { coins: Number(wallet?.coins ?? 0n) };
  }

  /**
   * Charges `amount` coins inside the caller's transaction; null when the balance is short.
   * v1.21-live (CP-018): spending that counts for the spender's family (bullets, creating a family,
   * CP gifts) adds the same number of family points in the same transaction.
   */
  async debitIn(
    tx: Prisma.TransactionClient,
    userId: string,
    amount: number,
    reason: WalletLedgerReason,
    referenceId: string,
  ): Promise<WalletChange | null> {
    const change = await debitIn(tx, userId, BigInt(amount), reason, referenceId);
    if (change && FAMILY_SPEND_REASONS.has(reason)) {
      await creditFamilyForSpendIn(tx, userId, change.ledgerId, BigInt(amount));
    }
    return change;
  }

  /**
   * CP-018: gives coins back (a CP refund) inside the caller's transaction. v1.27-live (D132): also
   * the coins a lucky gift's draws won (`LUCKY_GIFT_WIN`, never family points).
   */
  creditIn(
    tx: Prisma.TransactionClient,
    userId: string,
    amount: number,
    reason: 'CP_REFUND' | 'LUCKY_GIFT_WIN',
    referenceId: string,
  ): Promise<WalletChange> {
    return creditIn(tx, userId, BigInt(amount), reason, referenceId);
  }
}
