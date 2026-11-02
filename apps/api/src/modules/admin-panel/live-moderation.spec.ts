import { describe, expect, it } from 'vitest';
import { CAPABILITIES } from './admin-permissions.js';
import { activeDeviceBanOf, deviceBannedError } from '../auth/device-bans.js';
import { notificationBody } from '../push/push-texts.js';

/** v1.60-live (D250, §10.91): the pure parts of live moderation. */
describe('D250 live moderation', () => {
  const base = {
    type: 'LIVE_MODERATED',
    actorName: null,
    actorCount: 0,
    targetType: 'LIVE_MODERATION',
    targetId: 'x',
  };

  it('the push carries the team’s reason in the account’s language (clipped), or says the live ended without one', () => {
    expect(notificationBody({ ...base, targetText: 'Nudity on camera' }, 'en')).toBe(
      'The Kabso team ended your live. Reason: Nudity on camera',
    );
    expect(notificationBody({ ...base, targetText: 'محتوى مخالف' }, 'ar')).toBe(
      'أنهى فريق Kabso بثك. السبب: محتوى مخالف',
    );
    expect(notificationBody({ ...base, targetText: null }, 'en')).toBe('The Kabso team ended your live');
    const long = notificationBody({ ...base, targetText: 'x'.repeat(300) }, 'en')!;
    expect([...long].length).toBeLessThan(130);
    expect(long.endsWith('…')).toBe(true);
  });

  it('picks the ban that lasts longest (a permanent one first) and none for no device', async () => {
    const rows = [
      { id: 'a', reason: 'one', endsAt: new Date('2027-01-01T00:00:00Z') },
      { id: 'b', reason: 'two', endsAt: new Date('2027-06-01T00:00:00Z') },
    ];
    const db = (list: typeof rows | { id: string; reason: string; endsAt: Date | null }[]) =>
      ({ deviceBan: { findMany: () => Promise.resolve(list) } }) as never;
    expect(await activeDeviceBanOf(db(rows), ['h'])).toMatchObject({ id: 'b' });
    expect(
      await activeDeviceBanOf(db([...rows, { id: 'p', reason: 'p', endsAt: null }]), ['h']),
    ).toMatchObject({
      id: 'p',
    });
    expect(await activeDeviceBanOf(db(rows), [null, undefined, ''])).toBeNull();
  });

  it('DEVICE_BANNED says until when (or permanent) and why', () => {
    const until = deviceBannedError({ id: 'a', reason: 'why', endsAt: new Date('2027-01-01T00:00:00Z') });
    expect(until.code).toBe('DEVICE_BANNED');
    expect(until.details).toEqual([
      { field: 'until', issue: '2027-01-01T00:00:00.000Z' },
      { field: 'reason', issue: 'why' },
    ]);
    expect(deviceBannedError({ id: 'a', reason: 'why', endsAt: null }).details[0]).toEqual({
      field: 'until',
      issue: 'permanent',
    });
  });

  it('the four capabilities are OWNER and MODERATION only', () => {
    for (const cap of ['lives.watch', 'lives.reports', 'lives.moderate', 'devices.ban'] as const) {
      expect(CAPABILITIES[cap]).toEqual(['OWNER', 'MODERATION']);
    }
  });
});
