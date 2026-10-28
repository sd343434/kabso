import { describe, expect, it } from 'vitest';
import { dmPushBody } from './dm-push.js';
import { allowedInRequest, decideDm, pairOf, type DmFacts } from './dm-rules.js';

const STRANGER: DmFacts = {
  recipientWho: 'EVERYONE',
  recipientFollowsSender: false,
  recipientHasSent: false,
  recipientStatus: null,
  senderRequestSent: 0,
};

describe('D155 decideDm (CONVENTIONS §11.13)', () => {
  it('a stranger writes a request, at most 3 messages', () => {
    expect(decideDm(STRANGER, 3)).toEqual({ allowed: true, reason: null, asRequest: true });
    expect(decideDm({ ...STRANGER, senderRequestSent: 2 }, 3).allowed).toBe(true);
    expect(decideDm({ ...STRANGER, senderRequestSent: 3 }, 3)).toEqual({
      allowed: false,
      reason: 'REQUEST_LIMIT',
      asRequest: true,
    });
    expect(decideDm({ ...STRANGER, recipientStatus: 'REQUEST', senderRequestSent: 3 }, 3).reason).toBe(
      'REQUEST_LIMIT',
    );
  });

  it('follow, accept or a reply make it a normal message (no limit)', () => {
    for (const f of [
      { recipientFollowsSender: true },
      { recipientStatus: 'ACCEPTED' as const },
      { recipientHasSent: true },
    ]) {
      expect(decideDm({ ...STRANGER, ...f, senderRequestSent: 3 }, 3)).toEqual({
        allowed: true,
        reason: null,
        asRequest: false,
      });
    }
  });

  it('privacy: NOBODY and FOLLOWING refuse, unless the recipient has written', () => {
    expect(decideDm({ ...STRANGER, recipientWho: 'NOBODY' }, 3).reason).toBe('NOT_ALLOWED');
    expect(decideDm({ ...STRANGER, recipientWho: 'NOBODY', recipientFollowsSender: true }, 3).reason).toBe(
      'NOT_ALLOWED',
    );
    expect(decideDm({ ...STRANGER, recipientWho: 'NOBODY', recipientHasSent: true }, 3).allowed).toBe(true);
    expect(decideDm({ ...STRANGER, recipientWho: 'FOLLOWING' }, 3).reason).toBe('NOT_ALLOWED');
    expect(decideDm({ ...STRANGER, recipientWho: 'FOLLOWING', recipientFollowsSender: true }, 3)).toEqual({
      allowed: true,
      reason: null,
      asRequest: false,
    });
    // Privacy is reported before the request limit.
    expect(decideDm({ ...STRANGER, recipientWho: 'NOBODY', senderRequestSent: 9 }, 3).reason).toBe(
      'NOT_ALLOWED',
    );
  });

  it('requests carry text, emojis and gifts only; pairs are ordered', () => {
    expect(['TEXT', 'EMOJI', 'GIFT'].every(allowedInRequest)).toBe(true);
    expect(['IMAGE', 'VOICE'].some(allowedInRequest)).toBe(false);
    expect(pairOf('b', 'a')).toEqual({ low: 'a', high: 'b' });
    expect(pairOf('a', 'b')).toEqual({ low: 'a', high: 'b' });
  });
});

describe('D155 dmPushBody', () => {
  it('words each kind in Arabic and English, marks requests and clips long texts', () => {
    const base = { text: null, quantity: null, asRequest: false };
    expect(dmPushBody({ ...base, kind: 'TEXT', text: 'مرحبا' }, 'ar')).toBe('مرحبا');
    expect(dmPushBody({ ...base, kind: 'IMAGE' }, 'ar')).toBe('📷 صورة');
    expect(dmPushBody({ ...base, kind: 'IMAGE' }, 'en')).toBe('📷 Photo');
    expect(dmPushBody({ ...base, kind: 'VOICE' }, 'ar')).toBe('🎤 رسالة صوتية');
    expect(dmPushBody({ ...base, kind: 'VOICE' }, 'en')).toBe('🎤 Voice message');
    expect(dmPushBody({ ...base, kind: 'EMOJI' }, 'en')).toBe('Sticker');
    expect(dmPushBody({ ...base, kind: 'GIFT', quantity: 5 }, 'ar')).toBe('🎁 أرسل لك هدية ×5');
    expect(dmPushBody({ ...base, kind: 'GIFT', quantity: 5 }, 'en')).toBe('🎁 Sent you a gift ×5');
    expect(dmPushBody({ ...base, kind: 'TEXT', text: 'hi', asRequest: true }, 'ar')).toBe('طلب مراسلة: hi');
    expect(dmPushBody({ ...base, kind: 'TEXT', text: 'hi', asRequest: true }, 'en')).toBe(
      'Message request: hi',
    );
    const long = dmPushBody({ ...base, kind: 'TEXT', text: 'x'.repeat(300) }, 'en');
    expect([...long].length).toBe(100);
    expect(long.endsWith('…')).toBe(true);
  });
});
