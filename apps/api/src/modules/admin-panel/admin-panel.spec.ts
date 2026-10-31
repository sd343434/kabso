import { describe, expect, it } from 'vitest';
import { AdminSecretBox, newRecoveryCode, recoveryCodeHash } from './admin-crypto.js';
import { CAPABILITIES, can, capabilitiesOf, PANEL_ROLES } from './admin-permissions.js';
import { parseRole } from './admin-roles.js';
import { dashboardDayStart } from './admin-users.service.js';
import { randomBytes } from 'node:crypto';
import { loadConfig } from '../../config/app-config.js';
import { readCookie } from './admin-session.guard.js';
import { base32Decode, base32Encode, hotp, matchTotp, otpauthUri, totpCode, totpStep } from './totp.js';
import {
  normalizeInstagram as instagramUrl,
  normalizeTiktok as tiktokUrl,
  normalizeWhatsapp as whatsappUrl,
  updateSiteSettingsSchema,
} from '../site-settings/site-settings.rules.js';

describe('TOTP (RFC 6238 / RFC 4226)', () => {
  // RFC 4226 appendix D: secret "12345678901234567890".
  const rfcSecret = Buffer.from('12345678901234567890');
  it('matches the RFC 4226 HOTP test values', () => {
    expect([0, 1, 2, 3, 9].map((c) => hotp(rfcSecret, c))).toEqual([
      '755224',
      '287082',
      '359152',
      '969429',
      '520489',
    ]);
  });
  it('matches RFC 6238 SHA-1 at T = 59 s and 1111111109 s (last six digits)', () => {
    const b32 = base32Encode(rfcSecret);
    expect(totpCode(b32, 59_000)).toBe('287082');
    expect(totpCode(b32, 1_111_111_109_000)).toBe('081804');
  });
  it('base32 round-trips', () => {
    const bytes = Buffer.from([0, 1, 2, 250, 255, 7, 99]);
    expect(base32Decode(base32Encode(bytes))).toEqual(bytes);
    expect(base32Encode(Buffer.from('foobar'))).toBe('MZXW6YTBOI');
  });
  it('accepts ±1 step, refuses a used step and older', () => {
    const b32 = base32Encode(rfcSecret);
    const now = 1_700_000_000_000;
    const step = totpStep(now);
    expect(matchTotp(b32, totpCode(b32, now), now, null)).toBe(step);
    expect(matchTotp(b32, totpCode(b32, now - 30_000), now, null)).toBe(step - 1);
    expect(matchTotp(b32, totpCode(b32, now + 30_000), now, null)).toBe(step + 1);
    expect(matchTotp(b32, totpCode(b32, now + 90_000), now, null)).toBeNull();
    expect(matchTotp(b32, totpCode(b32, now), now, step)).toBeNull();
    expect(matchTotp(b32, totpCode(b32, now + 30_000), now, step)).toBe(step + 1);
    expect(matchTotp(b32, '12345', now, null)).toBeNull();
    expect(matchTotp(b32, 'abcdef', now, null)).toBeNull();
  });
  it('builds the otpauth URI', () => {
    expect(otpauthUri('ABC', 'o@x.test')).toBe(
      'otpauth://totp/Kabso%20Admin:o%40x.test?secret=ABC&issuer=Kabso+Admin&algorithm=SHA1&digits=6&period=30',
    );
  });
});

describe('admin secrets', () => {
  it('seals with AES-GCM and refuses another key or a changed value', () => {
    const box = new AdminSecretBox('k'.repeat(40));
    const sealed = box.seal('JBSWY3DPEHPK3PXP');
    expect(sealed).toMatch(/^v1\./);
    expect(sealed).not.toContain('JBSWY3DPEHPK3PXP');
    expect(box.open(sealed)).toBe('JBSWY3DPEHPK3PXP');
    expect(new AdminSecretBox('x'.repeat(40)).open(sealed)).toBeNull();
    expect(box.open(`${sealed.slice(0, -2)}AA`)).toBeNull();
    expect(box.open('garbage')).toBeNull();
  });
  it('recovery codes are 10 + dash, hashed case- and dash-insensitively', () => {
    const code = newRecoveryCode();
    expect(code).toMatch(/^[a-z2-9]{5}-[a-z2-9]{5}$/);
    expect(recoveryCodeHash(code.toUpperCase().replace('-', ' '))).toBe(recoveryCodeHash(code));
    expect(recoveryCodeHash(code)).toMatch(/^[0-9a-f]{64}$/);
  });
  it('reads one cookie', () => {
    expect(readCookie('a=1; __Host-kabso_admin=tok%2Dx; b=2', '__Host-kabso_admin')).toBe('tok-x');
    expect(readCookie(undefined, 'a')).toBeUndefined();
    expect(readCookie('x=1', 'a')).toBeUndefined();
  });
});

describe('panel roles', () => {
  it('OWNER holds every capability; the others only theirs', () => {
    expect(capabilitiesOf(['OWNER'])).toEqual(Object.keys(CAPABILITIES));
    expect(can(['MODERATION'], 'reports.act')).toBe(true);
    expect(can(['MODERATION'], 'recharge.applications')).toBe(false);
    // Owner 2026-10-31: the moderator sees a user's balances (read-only), not the ledger rows.
    expect(can(['MODERATION'], 'users.balances')).toBe(true);
    expect(can(['MODERATION'], 'users.ledger')).toBe(false);
    expect(can(['SUPPORT'], 'users.ledger')).toBe(true);
    expect(can(['FINANCE'], 'users.ledger')).toBe(true);
    expect(can(['SUPPORT'], 'recharge.applications')).toBe(true);
    expect(can(['SUPPORT'], 'recharge.topup')).toBe(false);
    expect(can(['FINANCE'], 'recharge.topup')).toBe(true);
    expect(can(['FINANCE'], 'withdrawals.decide')).toBe(true);
    expect(can(['FINANCE'], 'recharge.applications')).toBe(false);
    expect(can(['FINANCE', 'MODERATION'], 'reports.view')).toBe(true);
    for (const role of ['MODERATION', 'SUPPORT', 'FINANCE']) expect(can([role], 'site.settings')).toBe(false);
    expect(capabilitiesOf([])).toEqual([]);
    expect(capabilitiesOf(['LEVELS_VIEW'])).toEqual([]);
  });
  it('parses the CLI role names', () => {
    expect(parseRole('moderator')).toBe('MODERATION');
    expect(PANEL_ROLES.map((r) => parseRole(r))).toEqual([...PANEL_ROLES]);
    expect(() => parseRole('ADMIN')).toThrow(/Unknown role/);
  });
});

describe('site settings rules', () => {
  it('normalizes the links and refuses other hosts', () => {
    expect(instagramUrl('https://www.instagram.com/kabsolive/')).toBe('https://www.instagram.com/kabsolive');
    expect(instagramUrl('http://instagram.com/kabso')).toBeNull();
    expect(instagramUrl('https://evil.com/kabso')).toBeNull();
    expect(instagramUrl('https://instagram.com.evil.com/kabso')).toBeNull();
    expect(tiktokUrl('https://www.tiktok.com/@kabso.live')).toBe('https://www.tiktok.com/@kabso.live');
    expect(tiktokUrl('https://www.tiktok.com/kabso')).toBeNull();
    expect(whatsappUrl('+966 50 123 4567')).toBe('https://wa.me/966501234567');
    expect(whatsappUrl('https://wa.me/201001234567')).toBe('https://wa.me/201001234567');
    expect(whatsappUrl('0501234567')).toBeNull();
    expect(whatsappUrl('https://wa.me.evil/1')).toBeNull();
  });
  it('validates the whole document; empty clears', () => {
    const ok = updateSiteSettingsSchema.safeParse({
      socials: { instagram: '', tiktok: null, whatsapp: '+201001234567' },
      topupEnabled: true,
    });
    expect(ok.success && ok.data).toEqual({
      socials: { instagram: null, tiktok: null, whatsapp: 'https://wa.me/201001234567' },
      topupEnabled: true,
    });
    expect(
      updateSiteSettingsSchema.safeParse({
        socials: { instagram: 'javascript:alert(1)', tiktok: null, whatsapp: null },
        topupEnabled: false,
      }).success,
    ).toBe(false);
    expect(
      updateSiteSettingsSchema.safeParse({ socials: { instagram: null, tiktok: null }, topupEnabled: false })
        .success,
    ).toBe(false);
  });
});

describe('dashboard «today» (owner 2026-10-31: the Asia/Riyadh day)', () => {
  it('starts at midnight in Riyadh (UTC+3), not at UTC midnight', () => {
    // 2026-10-31 22:30 UTC is already 2026-11-01 01:30 in Riyadh.
    expect(dashboardDayStart(new Date('2026-10-31T22:30:00Z'), 'Asia/Riyadh').toISOString()).toBe(
      '2026-10-31T21:00:00.000Z',
    );
    // 2026-11-01 20:59 UTC is still 2026-11-01 (23:59) in Riyadh.
    expect(dashboardDayStart(new Date('2026-11-01T20:59:00Z'), 'Asia/Riyadh').toISOString()).toBe(
      '2026-10-31T21:00:00.000Z',
    );
    expect(dashboardDayStart(new Date('2026-10-31T22:30:00Z'), 'UTC').toISOString()).toBe(
      '2026-10-31T00:00:00.000Z',
    );
  });
  it('defaults to Asia/Riyadh (ADMIN_DASHBOARD_TIME_ZONE)', () => {
    const base = {
      DATABASE_URL: 'postgresql://u:p@localhost:5432/db',
      REDIS_URL: 'redis://localhost:6379',
      // Generated per run: never commit a secret-like literal (gitleaks).
      JWT_ACCESS_SECRET: randomBytes(48).toString('base64url'),
      APP_PUBLIC_URL: 'https://kabso.example/',
    };
    expect(loadConfig(base).adminPanel.dashboardTimeZone).toBe('Asia/Riyadh');
    expect(loadConfig({ ...base, ADMIN_DASHBOARD_TIME_ZONE: 'UTC' }).adminPanel.dashboardTimeZone).toBe(
      'UTC',
    );
    expect(() => loadConfig({ ...base, ADMIN_DASHBOARD_TIME_ZONE: 'Mars/Base' })).toThrow();
  });
});
