/**
 * v1.40-social (D155, CONVENTIONS §11.13): who may write to whom, as a pure function of the facts
 * the send reads under the pair's lock.
 */

export type WhoCanMessage = 'EVERYONE' | 'FOLLOWING' | 'NOBODY';

export interface DmFacts {
  /** The recipient's «who can message you» setting. */
  readonly recipientWho: WhoCanMessage;
  /** The recipient follows the sender. */
  readonly recipientFollowsSender: boolean;
  /** The recipient wrote in this conversation at least once (started it or replied). */
  readonly recipientHasSent: boolean;
  /** The recipient's side of the conversation (null: none yet). */
  readonly recipientStatus: 'ACCEPTED' | 'REQUEST' | null;
  /** Messages the sender already sent as requests in this conversation. */
  readonly senderRequestSent: number;
}

export interface DmDecision {
  /** The sender may write now. */
  readonly allowed: boolean;
  /** Why not: the privacy setting, or the request's message limit. */
  readonly reason: 'NOT_ALLOWED' | 'REQUEST_LIMIT' | null;
  /** The next message is a message request (the recipient's REQUESTS box, limited). */
  readonly asRequest: boolean;
}

/**
 * Privacy first (`EVERYONE`; `FOLLOWING`: the recipient follows the sender; `NOBODY`) — waived in a
 * conversation where the recipient has written. Then requests: a message is a request unless the
 * recipient accepted the conversation, wrote in it, or follows the sender; a request allows at most
 * `maxRequestMessages` messages.
 */
export function decideDm(f: DmFacts, maxRequestMessages: number): DmDecision {
  const privacyOk =
    f.recipientHasSent ||
    f.recipientWho === 'EVERYONE' ||
    (f.recipientWho === 'FOLLOWING' && f.recipientFollowsSender);
  const asRequest = !(f.recipientStatus === 'ACCEPTED' || f.recipientHasSent || f.recipientFollowsSender);
  if (!privacyOk) return { allowed: false, reason: 'NOT_ALLOWED', asRequest };
  if (asRequest && f.senderRequestSent >= maxRequestMessages) {
    return { allowed: false, reason: 'REQUEST_LIMIT', asRequest };
  }
  return { allowed: true, reason: null, asRequest };
}

/** The kinds a message request may carry (pictures and voice wait for the recipient's accept). */
export function allowedInRequest(kind: string): boolean {
  return kind === 'TEXT' || kind === 'EMOJI' || kind === 'GIFT';
}

/** The ordered pair of a conversation (`user_low_id` < `user_high_id`). */
export function pairOf(a: string, b: string): { low: string; high: string } {
  return a < b ? { low: a, high: b } : { low: b, high: a };
}
