import { describe, expect, it } from 'vitest';
import { csvField } from '../../cli/waitlist-admin.js';
import {
  normalizeInstagram,
  normalizeSocial,
  normalizeTiktok,
  normalizeWhatsapp,
  storedSocial,
} from './site-settings.rules.js';

describe('D192 site settings — social link rules', () => {
  it('instagram: https on instagram.com with one handle, normalized to www', () => {
    expect(normalizeInstagram('https://instagram.com/kabso.live')).toBe(
      'https://www.instagram.com/kabso.live',
    );
    expect(normalizeInstagram(' https://www.instagram.com/kabso_live/ ')).toBe(
      'https://www.instagram.com/kabso_live',
    );
    expect(normalizeInstagram('https://www.instagram.com/kabso?igsh=x')).toBe(
      'https://www.instagram.com/kabso',
    );
    for (const bad of [
      'http://instagram.com/kabso',
      'https://instagram.com.evil.example/kabso',
      'https://evil.example/instagram.com/kabso',
      'https://instagram.com/',
      'https://instagram.com/a/b',
      'https://instagram.com/bad..dots',
      'https://user:pw@instagram.com/kabso',
      'https://instagram.com:444/kabso',
      'javascript:alert(1)',
      'kabso',
    ]) {
      expect(normalizeInstagram(bad), bad).toBeNull();
    }
  });

  it('tiktok: https on tiktok.com with @handle', () => {
    expect(normalizeTiktok('https://www.tiktok.com/@kabso.live')).toBe('https://www.tiktok.com/@kabso.live');
    expect(normalizeTiktok('https://tiktok.com/@kabso/')).toBe('https://www.tiktok.com/@kabso');
    for (const bad of [
      'https://tiktok.com/kabso',
      'https://vm.tiktok.com/@kabso',
      'https://tiktok.com/@k',
      'http://tiktok.com/@kabso',
    ]) {
      expect(normalizeTiktok(bad), bad).toBeNull();
    }
  });

  it('whatsapp: a wa.me URL or an international number → wa.me digits', () => {
    expect(normalizeWhatsapp('https://wa.me/966500000000')).toBe('https://wa.me/966500000000');
    expect(normalizeWhatsapp('+966 50-000-0000')).toBe('https://wa.me/966500000000');
    expect(normalizeWhatsapp('201001234567')).toBe('https://wa.me/201001234567');
    for (const bad of [
      'https://wa.me/0500000000',
      'https://wa.me/123',
      'https://wa.me/966500000000?text=hi',
      'https://api.whatsapp.com/send?phone=966500000000',
      'https://wa.me.evil.example/966500000000',
      '+1234567890123456',
      'call me',
    ]) {
      expect(normalizeWhatsapp(bad), bad).toBeNull();
    }
  });

  it('null or empty removes; too long or invalid is refused; stored values are re-checked', () => {
    expect(normalizeSocial('instagram', null)).toBeNull();
    expect(normalizeSocial('tiktok', '  ')).toBeNull();
    expect(normalizeSocial('instagram', `https://instagram.com/${'a'.repeat(300)}`)).toBeUndefined();
    expect(normalizeSocial('whatsapp', 'nope')).toBeUndefined();
    expect(storedSocial('instagram', 'https://evil.example/x')).toBeNull();
    expect(storedSocial('instagram', 42)).toBeNull();
    expect(storedSocial('whatsapp', 'https://wa.me/966500000000')).toBe('https://wa.me/966500000000');
  });
});

describe('D192 waitlist-admin CSV', () => {
  it('quotes and neutralises spreadsheet formulas', () => {
    expect(csvField('a@b.co')).toBe('a@b.co');
    expect(csvField('a,"b"@c.co')).toBe('"a,""b""@c.co"');
    expect(csvField('=cmd@x.co')).toBe("'=cmd@x.co");
  });
});
