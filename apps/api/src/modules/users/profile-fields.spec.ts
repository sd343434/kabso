import { describe, expect, it } from 'vitest';
import { updateMeSchema } from '../auth/auth.schemas.js';
import {
  FOUNDER_SOCIAL_PLATFORMS,
  keptProfileTagIcons,
  linkPlatform,
  MAX_FOUNDER_PROFILE_LINKS,
  MAX_PROFILE_LINKS,
  PROFILE_TAG_ICONS,
  profileTagIconsOf,
  profileTagIconsSchema,
  MAX_PROFILE_TAGS,
  normalizeProfileLink,
  profileLinksSchema,
  profileTagsOf,
  profileTagsSchema,
  publicGender,
  whatsAppLinkOf,
} from './profile-fields.js';

describe('profile links (v1.47-social, D175, §10.47)', () => {
  it('normalises https links: lower-case host, punycode, no fragment, percent-encoding', () => {
    expect(normalizeProfileLink(' https://WWW.Example.COM/Path?q=1#frag ')).toEqual({
      value: 'https://www.example.com/Path?q=1',
    });
    expect(normalizeProfileLink('https://مثال.com/')).toEqual({ value: 'https://xn--mgbh0fb.com/' });
    expect(normalizeProfileLink('HTTPS://example.com')).toEqual({ value: 'https://example.com/' });
    // The default port is no port.
    expect(normalizeProfileLink('https://example.com:443/a')).toEqual({ value: 'https://example.com/a' });
    expect(normalizeProfileLink('https://example.com/ä')).toEqual({ value: 'https://example.com/%C3%A4' });
  });

  it.each([
    'http://example.com',
    'ftp://example.com',
    'javascript:alert(1)',
    '//example.com',
    'example.com',
    'https://',
    'https://a:b@example.com',
    'https://a@example.com',
    'https://example.com:8080',
    'https://10.0.0.1',
    'https://4294967295',
    'https://0x7f000001',
    'https://[::1]',
    'https://[2001:db8::1]/x',
    'https://localhost',
    'https://intranet',
    'https://example.123',
    'https://exa_mple.com',
    'https://-bad.com',
    'https://exa mple.com',
    'https://example.com/a\tb',
    'https://example.com/​',
    'https://example.com/‮',
    'https://example.com/⁦',
    'https://example.com/؜',
    '',
  ])('refuses %j', (raw) => {
    expect(normalizeProfileLink(raw)).toEqual({ issue: 'invalid_format' });
  });

  it('refuses a link longer than 500 characters once normalised', () => {
    expect(normalizeProfileLink(`https://example.com/${'a'.repeat(480)}`)).toEqual({
      value: `https://example.com/${'a'.repeat(480)}`,
    });
    expect(normalizeProfileLink(`https://example.com/${'a'.repeat(481)}`)).toEqual({ issue: 'too_long' });
  });

  it('names the known platforms by domain or subdomain only', () => {
    const cases: [string, string][] = [
      ['https://instagram.com/a', 'INSTAGRAM'],
      ['https://www.instagram.com/a', 'INSTAGRAM'],
      ['https://m.tiktok.com/@a', 'TIKTOK'],
      ['https://youtube.com/@a', 'YOUTUBE'],
      ['https://m.youtube.com/watch?v=1', 'YOUTUBE'],
      ['https://youtu.be/1', 'YOUTUBE'],
      ['https://facebook.com/a', 'FACEBOOK'],
      ['https://web.facebook.com/a', 'FACEBOOK'],
      ['https://fb.com/a', 'FACEBOOK'],
      ['https://x.com/a', 'X'],
      ['https://mobile.twitter.com/a', 'X'],
      ['https://instagram.com.evil.example/a', 'OTHER'],
      ['https://notinstagram.com/a', 'OTHER'],
      ['https://myx.com/a', 'OTHER'],
      ['https://example.com/instagram.com', 'OTHER'],
      // v1.118-social (D357): the founder row's WhatsApp and Snapchat.
      ['https://wa.me/966501234567', 'WHATSAPP'],
      ['https://api.whatsapp.com/send?phone=966501234567', 'WHATSAPP'],
      ['https://whatsapp.com/channel/abc', 'WHATSAPP'],
      ['https://snapchat.com/add/kabso', 'SNAPCHAT'],
      ['https://www.snapchat.com/add/kabso', 'SNAPCHAT'],
      ['https://wa.me.evil.example/1', 'OTHER'],
      ['https://notsnapchat.com/a', 'OTHER'],
    ];
    for (const [url, platform] of cases) expect([url, linkPlatform(url)]).toEqual([url, platform]);
  });

  it('D357: a bare phone number becomes a wa.me link; national, short or odd input does not', () => {
    expect(whatsAppLinkOf('+966 50 123 4567')).toBe('https://wa.me/966501234567');
    expect(whatsAppLinkOf('00966501234567')).toBe('https://wa.me/966501234567');
    expect(whatsAppLinkOf('966-50-123-4567')).toBe('https://wa.me/966501234567');
    expect(whatsAppLinkOf('0501234567')).toBeNull(); // no country code
    expect(whatsAppLinkOf('+1234567')).toBeNull(); // 7 digits
    expect(whatsAppLinkOf('+1234567890123456')).toBeNull(); // 16 digits
    expect(whatsAppLinkOf('+966 50 abc')).toBeNull();
    expect(whatsAppLinkOf('https://wa.me/1')).toBeNull();
    expect(normalizeProfileLink(' +966 50 123 4567 ')).toEqual({ value: 'https://wa.me/966501234567' });
    expect(linkPlatform('https://wa.me/966501234567')).toBe('WHATSAPP');
    // Everything else keeps the https-only rule.
    expect(normalizeProfileLink('wa.me/966501234567')).toEqual({ issue: 'invalid_format' });
    expect(normalizeProfileLink('http://instagram.com/kabso')).toEqual({ issue: 'invalid_format' });
    expect(FOUNDER_SOCIAL_PLATFORMS).toEqual(['INSTAGRAM', 'FACEBOOK', 'WHATSAPP', 'SNAPCHAT']);
  });

  it('accepts 0–3 links, refuses a fourth and duplicates after normalisation', () => {
    expect(profileLinksSchema.safeParse([]).success).toBe(true);
    const three = [
      { url: 'https://a.co' },
      { url: 'https://b.co', label: '  B  ' },
      { url: 'https://c.co', label: '' },
    ];
    const parsed = profileLinksSchema.parse(three);
    expect(parsed).toEqual([
      { url: 'https://a.co/' },
      { url: 'https://b.co/', label: 'B' },
      { url: 'https://c.co/', label: null },
    ]);
    // D357: the schema takes up to 7 (the app owner's); a 4th for anyone else is refused by the service
    // (`links` / `too_many`, the d175 / d357 e2e); an 8th is refused here for everyone.
    expect(MAX_PROFILE_LINKS).toBe(3);
    expect(MAX_FOUNDER_PROFILE_LINKS).toBe(7);
    const seven = ['a', 'b', 'c', 'd', 'e', 'f', 'g'].map((h) => ({ url: `https://${h}.co` }));
    expect(profileLinksSchema.safeParse(seven).success).toBe(true);
    expect(profileLinksSchema.safeParse([...seven, { url: 'https://h.co' }]).success).toBe(false);
    const dup = profileLinksSchema.safeParse([{ url: 'https://A.co' }, { url: 'https://a.co/#x' }]);
    expect(dup.success).toBe(false);
    expect(dup.error?.issues[0]?.path).toEqual([1, 'url']);
  });
});

describe('the gender others see', () => {
  it('only MALE or FEMALE, and only when shown', () => {
    expect(publicGender('MALE', true)).toBe('MALE');
    expect(publicGender('FEMALE', true)).toBe('FEMALE');
    expect(publicGender('UNDISCLOSED', true)).toBeNull();
    expect(publicGender('MALE', false)).toBeNull();
    expect(publicGender(null, true)).toBeNull();
  });
});

describe('profile tags «منشنات» (v1.85-social, D278b, §10.99)', () => {
  it('keeps the order, trims and NFC-normalises each tag', () => {
    expect(profileTagsSchema.parse(['  صانع محتوى ', 'Gamer', '10👑'])).toEqual([
      'صانع محتوى',
      'Gamer',
      '10👑',
    ]);
    expect(profileTagsSchema.parse(['Cafe\u0301'])).toEqual(['Café']);
    expect(profileTagsSchema.parse([])).toEqual([]);
  });

  it('allows 10, refuses 11 (too_many via the pipe: zod too_big on the array)', () => {
    const ten = Array.from({ length: MAX_PROFILE_TAGS }, (_, i) => `tag${i}`);
    expect(profileTagsSchema.parse(ten)).toHaveLength(10);
    const r = profileTagsSchema.safeParse([...ten, 'tag10']);
    expect(r.success).toBe(false);
    expect(r.error?.issues[0]?.code).toBe('too_big');
  });

  it.each([
    ['', 'too_short'],
    ['   ', 'too_short'],
    ['a'.repeat(25), 'too_long'],
    ['two\nlines', 'too_long'],
    ['bad\u202Eturn', 'invalid_format'],
    ['zero\u200Bwidth', 'invalid_format'],
  ])('refuses %j (%s)', (raw, issue) => {
    const r = profileTagsSchema.safeParse([raw]);
    expect(r.success).toBe(false);
    expect(r.error?.issues[0]?.path).toEqual([0]);
    expect((r.error?.issues[0] as { params?: { issue?: string } }).params?.issue).toBe(issue);
  });

  it('accepts 24 code points; the same tag twice (ignoring case) is invalid_value on the second', () => {
    expect(profileTagsSchema.parse(['ع'.repeat(24)])).toHaveLength(1);
    const r = profileTagsSchema.safeParse(['Gamer', 'music', 'GAMER']);
    expect(r.success).toBe(false);
    expect(r.error?.issues[0]?.path).toEqual([2]);
    expect((r.error?.issues[0] as { params?: { issue?: string } }).params?.issue).toBe('invalid_value');
  });

  it('PATCH /me takes `tags` alone (the whole set; [] clears)', () => {
    expect(updateMeSchema.parse({ tags: ['Gamer'] })).toEqual({ tags: ['Gamer'] });
    expect(updateMeSchema.parse({ tags: [] })).toEqual({ tags: [] });
  });

  it('reads at most 10, in order; none when absent', () => {
    expect(profileTagsOf(undefined)).toEqual([]);
    expect(profileTagsOf(null)).toEqual([]);
    expect(profileTagsOf(Array.from({ length: 12 }, (_, i) => `${i}`))).toHaveLength(10);
  });
});

describe('profile tag icons (v1.91-social, D292, §10.106)', () => {
  it('accepts the closed set and flag:<country> (upper-cased); null is default', () => {
    const keys = PROFILE_TAG_ICONS.filter((k) => k !== 'flag');
    expect(profileTagIconsSchema.parse(keys.slice(0, 10))).toEqual(keys.slice(0, 10));
    expect(profileTagIconsSchema.parse(['flag:sa', null, 'flag:EG'])).toEqual([
      'flag:SA',
      'default',
      'flag:EG',
    ]);
  });

  it('refuses a bare flag, an unknown country, other words and emoji, per entry', () => {
    for (const bad of ['flag', 'flag:ZZ', 'flag:XK', 'flag:SAU', 'rocket', 'Crown', '👑', '']) {
      const r = profileTagIconsSchema.safeParse(['star', bad]);
      expect(r.success, bad).toBe(false);
      expect(r.error?.issues[0]?.path).toEqual([1]);
    }
  });

  it('PATCH /me: tagIcons only with tags and one per tag', () => {
    expect(updateMeSchema.safeParse({ tags: ['a'], tagIcons: ['star'] }).success).toBe(true);
    for (const body of [
      { tagIcons: ['star'] },
      { tags: ['a', 'b'], tagIcons: ['star'] },
      { tags: [], tagIcons: ['star'] },
    ]) {
      const r = updateMeSchema.safeParse(body);
      expect(r.success).toBe(false);
      expect(r.error?.issues.map((i) => i.path)).toEqual([['tagIcons']]);
    }
  });

  it('reads one icon per tag, default where none is stored', () => {
    expect(profileTagIconsOf(['a', 'b'], [])).toEqual(['default', 'default']);
    expect(profileTagIconsOf(['a', 'b'], ['star', 'moon'])).toEqual(['star', 'moon']);
    expect(profileTagIconsOf(null, null)).toEqual([]);
  });

  it('an older app sending only tags: each keeps its icon by text (ignoring case), a new one is default', () => {
    expect(
      keptProfileTagIcons(
        ['saudi', 'New', 'MUSIC'],
        ['Music', 'Games', 'Saudi'],
        ['music', 'gamepad', 'flag:SA'],
      ),
    ).toEqual(['flag:SA', 'default', 'music']);
    expect(keptProfileTagIcons([], ['a'], ['star'])).toEqual([]);
  });
});
