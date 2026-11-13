import { describe, expect, it } from 'vitest';
import { normalizeSocialUrl, socialAccountBody } from '../site-settings/social-accounts.js';
import { LIMITED_STAFF_ROLES, limitedRoleOf } from '../live/live-staff.js';
import { RECRUITER_ROLES } from '../recruits/recruit-core.js';
import {
  CAPABILITIES,
  can,
  capabilitiesOf,
  defaultWhatsAppLevel,
  effectiveCapabilities,
  PANEL_ROLES,
  type Capability,
} from './admin-permissions.js';
import { parseRole } from './admin-roles.js';
import { overLimitOf, vipDaysValue } from './staff-compensations.service.js';
import {
  minutesUntilStart,
  nextSlots,
  SCHEDULE_ROLES,
  slotCovers,
  slotShapeIssue,
  slotsOverlap,
  weekClock,
} from './staff-schedule.js';

/** v1.139-social (D387, CONVENTIONS §10.176): the operations roles. */
describe('D387 operations roles — the capability matrix', () => {
  it('the four new roles are panel roles; TRUST_SAFETY is MODERATION itself', () => {
    expect(PANEL_ROLES).toEqual([
      'OWNER',
      'MODERATION',
      'SUPPORT',
      'FINANCE',
      'BD',
      'LIVE_OPS',
      'TALENT',
      'VIP_CARE',
      'COMMUNITY',
    ]);
    expect(parseRole('trust_safety')).toBe('MODERATION');
    expect(parseRole('MODERATOR')).toBe('MODERATION');
    for (const r of ['LIVE_OPS', 'TALENT', 'VIP_CARE', 'COMMUNITY'])
      expect(parseRole(r.toLowerCase())).toBe(r);
  });

  it('revenue.view is the OWNER alone, and OWNER still holds every capability', () => {
    expect(CAPABILITIES['revenue.view']).toEqual(['OWNER']);
    for (const role of PANEL_ROLES.filter((r) => r !== 'OWNER')) {
      expect(can([role], 'revenue.view'), role).toBe(false);
    }
    expect(capabilitiesOf(['OWNER'])).toEqual(Object.keys(CAPABILITIES));
    // Every other role together still lacks it.
    expect(capabilitiesOf(PANEL_ROLES.filter((r) => r !== 'OWNER'))).not.toContain('revenue.view');
  });

  /** Exactly each new role's capabilities (the WhatsApp ones from the default level). */
  const EXPECTED: Record<string, Capability[]> = {
    LIVE_OPS: [
      'dashboard.view',
      'lives.view',
      'catalog.view',
      'gifts.categories',
      'pk_dares.view',
      'pk_dares.edit',
      'host_targets.view',
      'host_targets.edit',
      'events.manage',
      'home.live_ops',
      'gifts.manage',
      'boosts.manage',
    ],
    TALENT: [
      'dashboard.view',
      'users.view',
      'agencies.view',
      'agencies.applications',
      'hosts.applications',
      'hosts.applications.photos',
      'hosts.applications.decide',
      'host_targets.view',
      'host_targets.edit',
      'recruits.mine',
      'creators.applications',
      'creators.decide',
      'home.talent',
    ],
    VIP_CARE: [
      'dashboard.view',
      'users.view',
      'levels.raise.request',
      'support.whatsapp',
      'support.whatsapp.view',
      'home.vip_care',
      'staff.schedule.view',
      'compensation.grant',
    ],
    COMMUNITY: [
      'dashboard.view',
      'catalog.view',
      'events.manage',
      'home.community',
      'social.accounts',
      'gifts.manage',
      'banners.manage',
      'site.public',
    ],
  };

  for (const [role, caps] of Object.entries(EXPECTED)) {
    it(`${role} holds exactly its capabilities`, () => {
      expect(effectiveCapabilities([role], null)).toEqual(caps);
    });
  }

  it('no new role moves money directly or sees money dashboards', () => {
    const money: Capability[] = [
      'revenue.view',
      'finance.view',
      'finance.refund',
      'users.balance_adjust',
      'recharge.topup',
      'withdrawals.decide',
      'payments.settings',
      'catalog.manage',
      'recruits.view',
      'owner.costs',
    ];
    for (const role of ['LIVE_OPS', 'TALENT', 'VIP_CARE', 'COMMUNITY']) {
      for (const cap of money) expect(can([role], cap), `${role} ${cap}`).toBe(false);
    }
    // VIP_CARE's only coin movement is a compensation within the OWNER's limits.
    expect(can(['VIP_CARE'], 'compensation.grant')).toBe(true);
    expect(can(['VIP_CARE'], 'compensation.approve')).toBe(false);
    expect(can(['VIP_CARE'], 'compensation.settings')).toBe(false);
  });

  it('MODERATION (TRUST_SAFETY) keeps every capability it held and gains its home and the schedule', () => {
    const before: Capability[] = [
      'dashboard.view',
      'users.view',
      'users.balances',
      'users.ledger',
      'users.ban',
      'users.avatar',
      'recharge.agents',
      'recharge.topups.view',
      'reports.view',
      'reports.act',
      'reports.resolve',
      'reports.reopen',
      'recharge.disputes',
      'recharge.disputes.resolve',
      'users.list',
      'users.sessions',
      'hosts.applications',
      'lives.view',
      'lives.manage',
      'users.control_view',
      'users.lock',
      'users.restrict',
      'users.profile_edit',
      'users.content',
      'lives.watch',
      'lives.reports',
      'lives.moderate',
      'devices.ban',
      'lives.watch.hidden',
      'recruits.mine',
      'levels.raise.request',
      'verification.view',
      'store_iap.view',
      'support.whatsapp',
      'support.whatsapp.manage',
      'support.whatsapp.view',
    ];
    const now = capabilitiesOf(['MODERATION']);
    for (const cap of before) expect(now, cap).toContain(cap);
    expect(now).toEqual(expect.arrayContaining(['home.trust_safety', 'staff.schedule.view']));
    expect(now).not.toContain('revenue.view');
  });

  it('the moved write capabilities were OWNER-only before: nobody loses one', () => {
    expect(CAPABILITIES['catalog.manage']).toEqual(['OWNER']);
    expect(CAPABILITIES['site.settings']).toEqual(['OWNER']);
    expect(CAPABILITIES['gifts.manage']).toEqual(['OWNER', 'LIVE_OPS', 'COMMUNITY']);
    expect(CAPABILITIES['banners.manage']).toEqual(['OWNER', 'COMMUNITY']);
    expect(CAPABILITIES['boosts.manage']).toEqual(['OWNER', 'LIVE_OPS']);
    expect(CAPABILITIES['site.public']).toEqual(['OWNER', 'COMMUNITY']);
  });

  it('FINANCE keeps the individual requests but no revenue dashboards', () => {
    const fin = capabilitiesOf(['FINANCE']);
    expect(fin).toEqual(
      expect.arrayContaining([
        'withdrawals.view',
        'withdrawals.decide',
        'recharge.topup',
        'recharge.topups.view',
      ]),
    );
    expect(fin).not.toContain('revenue.view');
  });

  it('VIP_CARE answers «دعم كابسو» by default; the others have no WhatsApp', () => {
    expect(defaultWhatsAppLevel(['VIP_CARE'])).toBe('REPLY');
    for (const r of ['LIVE_OPS', 'TALENT', 'COMMUNITY']) expect(defaultWhatsAppLevel([r])).toBe('NONE');
  });

  it('the new roles are limited staff accounts after the old ones; TALENT recruits like BD', () => {
    expect(LIMITED_STAFF_ROLES.slice(-4)).toEqual(['LIVE_OPS', 'TALENT', 'VIP_CARE', 'COMMUNITY']);
    expect(limitedRoleOf(['VIP_CARE', 'MODERATION'])).toBe('MODERATION');
    expect(limitedRoleOf(['COMMUNITY'])).toBe('COMMUNITY');
    expect(limitedRoleOf(['OWNER', 'COMMUNITY'])).toBeNull();
    expect(RECRUITER_ROLES).toEqual(['MODERATION', 'BD', 'TALENT']);
  });
});

describe('D387 shift schedule rules', () => {
  const slot = { weekday: 3, startMinute: 8 * 60, endMinute: 16 * 60 };

  it('covers [start, end) of its weekday only', () => {
    expect(slotCovers(slot, { weekday: 3, minute: 8 * 60 })).toBe(true);
    expect(slotCovers(slot, { weekday: 3, minute: 16 * 60 - 1 })).toBe(true);
    expect(slotCovers(slot, { weekday: 3, minute: 16 * 60 })).toBe(false);
    expect(slotCovers(slot, { weekday: 4, minute: 9 * 60 })).toBe(false);
  });

  it('overlap, shape and the next start', () => {
    expect(slotsOverlap(slot, { weekday: 3, startMinute: 15 * 60, endMinute: 20 * 60 })).toBe(true);
    expect(slotsOverlap(slot, { weekday: 3, startMinute: 16 * 60, endMinute: 20 * 60 })).toBe(false);
    expect(slotsOverlap(slot, { weekday: 2, startMinute: 8 * 60, endMinute: 16 * 60 })).toBe(false);
    expect(slotShapeIssue(slot)).toBeNull();
    expect(slotShapeIssue({ weekday: 0, startMinute: 0, endMinute: 10 })).toBe('weekday');
    expect(slotShapeIssue({ weekday: 1, startMinute: 600, endMinute: 600 })).toBe('endMinute');
    expect(slotShapeIssue({ weekday: 1, startMinute: 0, endMinute: 1441 })).toBe('endMinute');
    expect(minutesUntilStart(slot, { weekday: 3, minute: 7 * 60 })).toBe(60);
    // Covering now: it starts again next week.
    expect(minutesUntilStart(slot, { weekday: 3, minute: 8 * 60 })).toBe(7 * 1440);
    // Sunday 23:00 → Wednesday 08:00.
    expect(minutesUntilStart(slot, { weekday: 7, minute: 23 * 60 })).toBe(60 + 2 * 1440 + 8 * 60);
    const order = nextSlots(
      [
        slot,
        { weekday: 1, startMinute: 0, endMinute: 60 },
        { weekday: 3, startMinute: 20 * 60, endMinute: 1440 },
      ],
      { weekday: 3, minute: 17 * 60 },
    ).map((s) => s.slot.weekday * 10000 + s.slot.startMinute);
    expect(order).toEqual([3 * 10000 + 20 * 60, 1 * 10000, 3 * 10000 + 8 * 60]);
  });

  it('reads the week clock in the app zone', () => {
    // 2026-11-11 is a Wednesday; 21:30 UTC is Thursday 00:30 in Asia/Riyadh.
    const at = new Date('2026-11-11T21:30:00Z');
    expect(weekClock(at, 'UTC')).toEqual({ weekday: 3, minute: 21 * 60 + 30 });
    expect(weekClock(at, 'Asia/Riyadh')).toEqual({ weekday: 4, minute: 30 });
  });

  it('schedules MODERATION (TRUST_SAFETY), SUPPORT and VIP_CARE', () => {
    expect(SCHEDULE_ROLES).toEqual(['MODERATION', 'SUPPORT', 'VIP_CARE']);
  });
});

describe('D387 compensation limits', () => {
  const limits = { dailyLimitCoins: 50_000n, perGrantMaxCoins: 10_000n };

  it('within both limits is granted; above either waits for the OWNER; the OWNER is never limited', () => {
    expect(overLimitOf(10_000n, 40_000n, limits, false)).toBeNull();
    expect(overLimitOf(10_001n, 0n, limits, false)).toBe('per_grant');
    expect(overLimitOf(5_000n, 46_000n, limits, false)).toBe('daily');
    expect(overLimitOf(1_000_000n, 1_000_000n, limits, true)).toBeNull();
  });

  it('VIP days are valued at the tier price per day, rounded up', () => {
    expect(vipDaysValue(30_000n, 30, 7)).toBe(7_000n);
    expect(vipDaysValue(10_000n, 30, 1)).toBe(334n);
    expect(vipDaysValue(1n, 365, 1)).toBe(1n);
  });
});

describe('D387 official social accounts', () => {
  it('https links only, never a user name or password part', () => {
    expect(normalizeSocialUrl('https://www.instagram.com/kabsolive')).toBe(
      'https://www.instagram.com/kabsolive',
    );
    expect(normalizeSocialUrl('  HTTPS://X.com/kabso ')).toBe('https://x.com/kabso');
    expect(normalizeSocialUrl('http://x.com/kabso')).toBeNull();
    expect(normalizeSocialUrl('javascript:alert(1)')).toBeNull();
    expect(normalizeSocialUrl('https://user:secret@x.com/kabso')).toBeNull();
    expect(normalizeSocialUrl('https://x.com/ka bso')).toBeNull();
    expect(normalizeSocialUrl(`https://x.com/${'a'.repeat(600)}`)).toBeNull();
  });

  it('the body has no field for a password or token', () => {
    const ok = socialAccountBody.safeParse({
      platform: 'TIKTOK',
      handle: '@kabsolive',
      url: 'https://tiktok.com/@k',
    });
    expect(ok.success).toBe(true);
    expect(
      socialAccountBody.safeParse({
        platform: 'TIKTOK',
        handle: 'k',
        url: 'https://tiktok.com/@k',
        password: 'x',
      }).success,
    ).toBe(false);
    expect(
      socialAccountBody.safeParse({ platform: 'MYSPACE', handle: 'k', url: 'https://a.b' }).success,
    ).toBe(false);
  });
});
