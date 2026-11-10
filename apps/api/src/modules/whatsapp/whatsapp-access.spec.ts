/**
 * D360 (v1.120-social, CONVENTIONS §10.155): the WhatsApp level per staff member — the defaults are exactly D355's
 * roles, a level set replaces only the three WhatsApp capabilities, an OWNER is always MANAGE, and the DB helpers
 * read the level that applies.
 */
import { describe, expect, it, vi } from 'vitest';
import {
  CAPABILITIES,
  capabilitiesOf,
  defaultWhatsAppLevel,
  effectiveCapabilities,
  effectiveWhatsAppLevel,
  WHATSAPP_CAPABILITIES,
  WHATSAPP_LEVELS,
  whatsAppCapabilitiesOf,
  type Capability,
} from '../admin-panel/admin-permissions.js';
import { isAtWhatsAppLevel, staffAtLevel } from './whatsapp-access.js';

const wa = (caps: readonly Capability[]) => caps.filter((c) => c.startsWith('support.whatsapp')).sort();

describe('D360 WhatsApp levels', () => {
  it('the defaults follow the D355 roles exactly: OWNER / MODERATION MANAGE, SUPPORT REPLY, others NONE', () => {
    expect(defaultWhatsAppLevel(['OWNER'])).toBe('MANAGE');
    expect(defaultWhatsAppLevel(['MODERATION'])).toBe('MANAGE');
    expect(defaultWhatsAppLevel(['SUPPORT'])).toBe('REPLY');
    expect(defaultWhatsAppLevel(['FINANCE'])).toBe('NONE');
    expect(defaultWhatsAppLevel(['BD'])).toBe('NONE');
    expect(defaultWhatsAppLevel(['SUPPORT', 'FINANCE'])).toBe('REPLY');
    expect(defaultWhatsAppLevel([])).toBe('NONE');
  });

  it('with no level set, every role keeps exactly the capabilities it had (the WhatsApp ones as D355 + view)', () => {
    for (const roles of [
      ['OWNER'],
      ['MODERATION'],
      ['SUPPORT'],
      ['FINANCE'],
      ['BD'],
      ['SUPPORT', 'FINANCE'],
    ]) {
      expect(effectiveCapabilities(roles, null)).toEqual(capabilitiesOf(roles));
    }
    // The role table's own lists are the default and agree with the level rule.
    for (const cap of WHATSAPP_CAPABILITIES) {
      for (const role of ['OWNER', 'MODERATION', 'SUPPORT', 'FINANCE', 'BD']) {
        expect((CAPABILITIES[cap] as readonly string[]).includes(role)).toBe(
          whatsAppCapabilitiesOf(defaultWhatsAppLevel([role])).includes(cap),
        );
      }
    }
  });

  it('the levels are cumulative', () => {
    expect(whatsAppCapabilitiesOf('NONE')).toEqual([]);
    expect(whatsAppCapabilitiesOf('VIEW')).toEqual(['support.whatsapp.view']);
    expect(whatsAppCapabilitiesOf('REPLY')).toEqual(['support.whatsapp.view', 'support.whatsapp']);
    expect(whatsAppCapabilitiesOf('MANAGE')).toEqual([
      'support.whatsapp.view',
      'support.whatsapp',
      'support.whatsapp.manage',
    ]);
    expect(WHATSAPP_LEVELS).toEqual(['NONE', 'VIEW', 'REPLY', 'MANAGE']);
  });

  it('a level set replaces only the WhatsApp capabilities, both ways', () => {
    const mod = effectiveCapabilities(['MODERATION'], 'VIEW');
    expect(wa(mod)).toEqual(['support.whatsapp.view']);
    expect(mod.filter((c) => !c.startsWith('support.whatsapp'))).toEqual(
      capabilitiesOf(['MODERATION']).filter((c) => !c.startsWith('support.whatsapp')),
    );
    expect(wa(effectiveCapabilities(['SUPPORT'], 'NONE'))).toEqual([]);
    expect(wa(effectiveCapabilities(['SUPPORT'], 'MANAGE'))).toEqual(
      ['support.whatsapp', 'support.whatsapp.manage', 'support.whatsapp.view'].sort(),
    );
    // A FINANCE staff member can be given WhatsApp by a level.
    expect(wa(effectiveCapabilities(['FINANCE'], 'REPLY'))).toEqual([
      'support.whatsapp',
      'support.whatsapp.view',
    ]);
  });

  it('an OWNER is always MANAGE and nobody without a panel role has any', () => {
    expect(effectiveWhatsAppLevel(['OWNER'], 'NONE')).toBe('MANAGE');
    expect(effectiveWhatsAppLevel(['OWNER', 'SUPPORT'], 'VIEW')).toBe('MANAGE');
    expect(effectiveWhatsAppLevel([], 'MANAGE')).toBe('NONE');
    expect(effectiveCapabilities([], 'MANAGE')).toEqual([]);
  });

  it('staffAtLevel / isAtWhatsAppLevel combine the roles and the rows set', async () => {
    const users = [
      { id: 'a', adminPermissions: [{ permission: 'SUPPORT' }] },
      { id: 'b', adminPermissions: [{ permission: 'MODERATION' }] },
      { id: 'c', adminPermissions: [{ permission: 'FINANCE' }] },
      { id: 'd', adminPermissions: [{ permission: 'OWNER' }] },
    ];
    const db = {
      user: { findMany: vi.fn(async () => users) },
      waStaffAccess: {
        findMany: vi.fn(async () => [
          { userId: 'b', level: 'VIEW' },
          { userId: 'c', level: 'REPLY' },
          { userId: 'd', level: 'NONE' },
        ]),
      },
    } as never;
    expect(await staffAtLevel(db, 'VIEW')).toEqual([
      { userId: 'a', roles: ['SUPPORT'], level: 'REPLY' },
      { userId: 'b', roles: ['MODERATION'], level: 'VIEW' },
      { userId: 'c', roles: ['FINANCE'], level: 'REPLY' },
      { userId: 'd', roles: ['OWNER'], level: 'MANAGE' },
    ]);
    expect((await staffAtLevel(db, 'REPLY')).map((s) => s.userId)).toEqual(['a', 'c', 'd']);
    expect((await staffAtLevel(db, 'MANAGE')).map((s) => s.userId)).toEqual(['d']);
    const none = { user: { findMany: vi.fn(async () => []) }, waStaffAccess: { findMany: vi.fn() } } as never;
    expect(await isAtWhatsAppLevel(none, 'x', 'VIEW')).toBe(false);
  });
});
