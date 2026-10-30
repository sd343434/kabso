import { describe, expect, it } from 'vitest';
import { linkPlatform, normalizeProfileLink, profileLinksSchema, publicGender } from './profile-fields.js';

describe('profile links (v1.47-social, D175, §10.43)', () => {
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
    ];
    for (const [url, platform] of cases) expect([url, linkPlatform(url)]).toEqual([url, platform]);
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
    expect(profileLinksSchema.safeParse([...three, { url: 'https://d.co' }]).success).toBe(false);
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
