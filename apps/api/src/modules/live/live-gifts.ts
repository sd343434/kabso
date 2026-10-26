/**
 * CP-020 (D108, CONVENTIONS §10.23): the arithmetic of live gifts, as pure functions.
 */
import { POINTS_PER_SUPPORT_COIN } from './live-taps.js';

/** The media data topic of gift data messages. */
export const LIVE_GIFT_TOPIC = 'gift';

export interface GiftAmounts {
  /** Coins each recipient's gifts are worth (unit price × quantity). */
  readonly perRecipientCoins: number;
  /** The send's coin value (× recipients): charged for COINS, the value of the bag gifts for BAG. */
  readonly totalCoins: number;
  /** Gifts taken from the bag for a BAG send (quantity × recipients). */
  readonly bagUnits: number;
  /** Live score / Contribution points (100 a coin, §10.10). */
  readonly scorePoints: number;
}

/** What a send of `quantity` gifts priced `unitPrice` to `recipients` people is worth. */
export function giftAmounts(unitPrice: number, quantity: number, recipients: number): GiftAmounts {
  const perRecipientCoins = unitPrice * quantity;
  const totalCoins = perRecipientCoins * recipients;
  if (!Number.isSafeInteger(totalCoins * POINTS_PER_SUPPORT_COIN)) throw new RangeError('gift too large');
  return {
    perRecipientCoins,
    totalCoins,
    bagUnits: quantity * recipients,
    scorePoints: totalCoins * POINTS_PER_SUPPORT_COIN,
  };
}

/** The recipients' user ids sorted and joined: two sends match for a combo when these are equal. */
export function recipientsKey(userIds: readonly string[]): string {
  return [...userIds].sort().join(',');
}

/** The sender's previous send in the same live (null: none). */
export interface PreviousSend {
  readonly giftCode: string;
  readonly recipientsKey: string;
  readonly comboId: string;
  readonly comboCount: number;
  readonly comboQuantity: bigint;
  readonly createdAt: Date;
}

export interface Combo {
  /** The first send of the combo. */
  readonly id: string;
  /** 1 for a new combo, then 2, 3 … */
  readonly count: number;
  /** Gifts sent per recipient in the whole combo so far. */
  readonly quantity: bigint;
}

/**
 * A send continues the sender's combo when their previous send in the same live was the same gift
 * to the same recipients at most `windowMs` before (a clock that went backwards counts as no time
 * passed); otherwise it starts a new one with its own id.
 */
export function comboFor(
  previous: PreviousSend | null,
  send: {
    readonly id: string;
    readonly giftCode: string;
    readonly recipientsKey: string;
    readonly quantity: number;
  },
  now: Date,
  windowMs: number,
): Combo {
  if (
    previous !== null &&
    previous.giftCode === send.giftCode &&
    previous.recipientsKey === send.recipientsKey &&
    Math.max(0, now.getTime() - previous.createdAt.getTime()) <= windowMs
  ) {
    return {
      id: previous.comboId,
      count: previous.comboCount + 1,
      quantity: previous.comboQuantity + BigInt(send.quantity),
    };
  }
  return { id: send.id, count: 1, quantity: BigInt(send.quantity) };
}
