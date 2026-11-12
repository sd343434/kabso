import { describe, expect, it } from 'vitest';
import { vipCatalogueEntry } from './vip-catalogue.js';
import {
  ANONYMOUS_DISPLAY_NAME,
  ANONYMOUS_GIFT_RATE,
  ANONYMOUS_USERNAME,
  VIP_PRIVACY_SWITCHES,
  anonymousUserSummary,
  rankedUser,
  vipPrivacyOnIn,
} from './vip-privacy.js';

/** v1.133-social (D380, CONVENTIONS §10.170): the VIP privacy helpers. */
describe('D380 VIP privacy helpers', () => {
  const member = {
    id: '0192f1d0-0000-7000-8000-000000000001',
    username: 'lina1',
    displayName: 'لينا',
    avatarUrl: 'https://x.test/a.png',
  };

  it('«مجهول» carries nothing of the member: a fresh id every time, no picture, an untakeable username', () => {
    const a = anonymousUserSummary();
    const b = anonymousUserSummary();
    expect(a).toEqual({
      id: expect.stringMatching(/^[0-9a-f-]{36}$/),
      username: ANONYMOUS_USERNAME,
      displayName: ANONYMOUS_DISPLAY_NAME,
      avatarUrl: null,
      anonymous: true,
    });
    expect(a.id).not.toBe(b.id);
    // A regular username is a–z, 0–9 and `_` only (D146): a dot can never be registered.
    expect(ANONYMOUS_USERNAME).toContain('.');
    expect(ANONYMOUS_DISPLAY_NAME).toBe('مجهول');
  });

  it('rankedUser: «مجهول» to others; the member and the extra real readers (the host) see the real person', () => {
    const anonymous = new Set([member.id]);
    expect(rankedUser(member, anonymous, null).anonymous).toBe(true);
    expect(rankedUser(member, anonymous, 'someone-else').anonymous).toBe(true);
    expect(rankedUser(member, anonymous, member.id)).toBe(member);
    expect(rankedUser(member, anonymous, 'host-id', ['host-id'])).toBe(member);
    // Not hiding: as it is, for everyone.
    expect(rankedUser(member, new Set(), 'someone-else')).toBe(member);
  });

  it('the switch defaults: hidden visits and the shield on, anonymous rankings off', () => {
    expect(VIP_PRIVACY_SWITCHES.HIDDEN_VISIT.default).toBe(true);
    expect(VIP_PRIVACY_SWITCHES.RANKING_ANONYMOUS.default).toBe(false);
    expect(VIP_PRIVACY_SWITCHES.KICK_MUTE_SHIELD.default).toBe(true);
    expect(ANONYMOUS_GIFT_RATE).toEqual({ max: 60, windowSeconds: 3600 });
  });

  it('the four perks are built; HIDE_COINS_SENT stays «قريباً»', () => {
    for (const code of ['HIDDEN_VISIT', 'RANKING_ANONYMOUS', 'KICK_MUTE_SHIELD', 'ANONYMOUS_GIFT']) {
      expect(vipCatalogueEntry(code)?.built, code).toBe(true);
      expect(vipCatalogueEntry(code)?.value, code).toEqual({ kind: 'none' });
    }
    expect(vipCatalogueEntry('HIDE_COINS_SENT')?.built).toBe(false);
  });

  it('vipPrivacyOnIn asks nothing for no ids, and one query for many', async () => {
    let calls = 0;
    const db = {
      $queryRaw: (() => {
        calls += 1;
        return Promise.resolve([{ user_id: member.id }]);
      }) as never,
    };
    expect(await vipPrivacyOnIn(db, [], 'RANKING_ANONYMOUS', new Date())).toEqual(new Set());
    expect(calls).toBe(0);
    const on = await vipPrivacyOnIn(db, [member.id, member.id, 'other'], 'ANONYMOUS_GIFT', new Date());
    expect(on).toEqual(new Set([member.id]));
    expect(calls).toBe(1);
  });
});
