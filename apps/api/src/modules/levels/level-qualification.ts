import type { LevelCategoryCode, PointsSourceType } from '../../generated/prisma/client.js';

/** A committed gift (normal or lucky), as the gifts module reports it (CP-005 §6). */
export interface GiftCommittedEvent {
  readonly type: 'GIFT_COMMITTED';
  readonly sourceTransactionId: string;
  readonly senderUserId: string;
  readonly recipientUserId: string;
  /** Final eligible value in the source unit (COIN). */
  readonly value: bigint;
  readonly lucky: boolean;
}

/** Committed spending inside a game (never winnings or prizes). */
export interface GameSpendCommittedEvent {
  readonly type: 'GAME_SPEND_COMMITTED';
  readonly sourceTransactionId: string;
  readonly userId: string;
  readonly value: bigint;
}

/** A refund/reversal of a previously committed gift or game spend. */
export interface ReversalEvent {
  readonly type: 'GIFT_REVERSED' | 'GAME_SPEND_REVERSED';
  readonly sourceTransactionId: string;
}

export type LevelSourceEventInput = GiftCommittedEvent | GameSpendCommittedEvent | ReversalEvent;

export interface Credit {
  readonly userId: string;
  readonly category: LevelCategoryCode;
  readonly sourceType: PointsSourceType;
  readonly value: bigint;
}

export interface QualificationPolicy {
  /** SUPPORT's `luckyGiftsCountAsSupport` (CP-005 §5, default false). */
  readonly luckyGiftsCountAsSupport: boolean;
}

/** Why an activity event earns nothing at all. */
export type DisqualifiedReason = 'non_positive_value' | 'self_gift';

/**
 * CP-005 §5: which categories an activity credits, and whom. Explicit and exhaustive: one
 * activity never credits a category it does not qualify for.
 *
 * - normal gift → ATTRACTIVENESS (recipient), SUPPORT (sender);
 * - lucky gift → ATTRACTIVENESS (recipient), WIZARD (sender), and SUPPORT (sender) only when the
 *   policy says so — Wizard is the value of lucky gifts SENT, never their winnings;
 * - game spend → GAMING (spender) — never winnings, prizes or rewards.
 *
 * A gift to oneself earns nothing (anti-fraud).
 */
export function qualify(
  event: GiftCommittedEvent | GameSpendCommittedEvent,
  policy: QualificationPolicy,
): Credit[] | DisqualifiedReason {
  if (event.value <= 0n) return 'non_positive_value';
  if (event.type === 'GAME_SPEND_COMMITTED') {
    return [{ userId: event.userId, category: 'GAMING', sourceType: 'GAME_SPEND', value: event.value }];
  }
  if (event.senderUserId === event.recipientUserId) return 'self_gift';
  const credits: Credit[] = [
    {
      userId: event.recipientUserId,
      category: 'ATTRACTIVENESS',
      sourceType: 'GIFT_RECEIVED',
      value: event.value,
    },
  ];
  if (event.lucky) {
    credits.push({
      userId: event.senderUserId,
      category: 'WIZARD',
      sourceType: 'LUCKY_GIFT_SENT',
      value: event.value,
    });
    if (policy.luckyGiftsCountAsSupport) {
      credits.push({
        userId: event.senderUserId,
        category: 'SUPPORT',
        sourceType: 'GIFT_SENT',
        value: event.value,
      });
    }
  } else {
    credits.push({
      userId: event.senderUserId,
      category: 'SUPPORT',
      sourceType: 'GIFT_SENT',
      value: event.value,
    });
  }
  return credits;
}
