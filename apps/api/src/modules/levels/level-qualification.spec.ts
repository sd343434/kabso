import { describe, expect, it } from 'vitest';
import { qualify, type GiftCommittedEvent } from './level-qualification.js';

const gift: GiftCommittedEvent = {
  type: 'GIFT_COMMITTED',
  sourceTransactionId: 'gift-1',
  senderUserId: 'sender',
  recipientUserId: 'recipient',
  value: 50n,
  lucky: false,
};

describe('activity → category mapping (CP-005 §5)', () => {
  it('normal gift: recipient Attractiveness, sender Support, nothing else', () => {
    expect(qualify(gift, { luckyGiftsCountAsSupport: true })).toEqual([
      { userId: 'recipient', category: 'ATTRACTIVENESS', sourceType: 'GIFT_RECEIVED', value: 50n },
      { userId: 'sender', category: 'SUPPORT', sourceType: 'GIFT_SENT', value: 50n },
    ]);
  });

  it('lucky gift: Wizard for the sender (what they SEND), Support only by policy', () => {
    const lucky = { ...gift, lucky: true };
    expect(qualify(lucky, { luckyGiftsCountAsSupport: false })).toEqual([
      { userId: 'recipient', category: 'ATTRACTIVENESS', sourceType: 'GIFT_RECEIVED', value: 50n },
      { userId: 'sender', category: 'WIZARD', sourceType: 'LUCKY_GIFT_SENT', value: 50n },
    ]);
    expect(qualify(lucky, { luckyGiftsCountAsSupport: true })).toEqual([
      { userId: 'recipient', category: 'ATTRACTIVENESS', sourceType: 'GIFT_RECEIVED', value: 50n },
      { userId: 'sender', category: 'WIZARD', sourceType: 'LUCKY_GIFT_SENT', value: 50n },
      { userId: 'sender', category: 'SUPPORT', sourceType: 'GIFT_SENT', value: 50n },
    ]);
  });

  it('game spend: Gaming only', () => {
    expect(
      qualify(
        { type: 'GAME_SPEND_COMMITTED', sourceTransactionId: 'g-1', userId: 'player', value: 7n },
        { luckyGiftsCountAsSupport: true },
      ),
    ).toEqual([{ userId: 'player', category: 'GAMING', sourceType: 'GAME_SPEND', value: 7n }]);
  });

  it('earns nothing for zero values or gifts to oneself', () => {
    expect(qualify({ ...gift, value: 0n }, { luckyGiftsCountAsSupport: false })).toBe('non_positive_value');
    expect(qualify({ ...gift, recipientUserId: 'sender' }, { luckyGiftsCountAsSupport: false })).toBe(
      'self_gift',
    );
  });
});
