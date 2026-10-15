import { describe, expect, it } from 'vitest';
import { ipv6Hextets, rateLimitIpSubject } from './request-context.js';

describe('rateLimitIpSubject (CONVENTIONS §7: IPv6 grouped by /64)', () => {
  it('keeps IPv4 addresses as-is and unwraps IPv4-mapped IPv6', () => {
    expect(rateLimitIpSubject('203.0.113.7')).toBe('203.0.113.7');
    expect(rateLimitIpSubject('::ffff:203.0.113.7')).toBe('203.0.113.7');
    expect(rateLimitIpSubject('::ffff:cb00:7107')).toBe('203.0.113.7');
  });

  it('groups every address of one /64 into the same subject', () => {
    const subjects = new Set(
      [
        '2001:db8:1:2::1',
        '2001:db8:1:2:ffff:ffff:ffff:ffff',
        '2001:0db8:0001:0002:abcd:0:0:1',
        '2001:DB8:1:2:a:b:c:d',
        'fe80::1%eth0',
      ]
        .slice(0, 4)
        .map(rateLimitIpSubject),
    );
    expect([...subjects]).toEqual(['2001:db8:1:2::/64']);
  });

  it('separates different /64 prefixes', () => {
    expect(rateLimitIpSubject('2001:db8:1:3::1')).toBe('2001:db8:1:3::/64');
    expect(rateLimitIpSubject('::1')).toBe('0:0:0:0::/64');
    expect(rateLimitIpSubject('fe80::1%eth0')).toBe('fe80:0:0:0::/64');
  });

  it('passes through values that are not IP addresses', () => {
    expect(rateLimitIpSubject('unknown')).toBe('unknown');
  });

  it('expands IPv6 notation correctly', () => {
    expect(ipv6Hextets('2001:db8::1')).toEqual([0x2001, 0xdb8, 0, 0, 0, 0, 0, 1]);
    expect(ipv6Hextets('::')).toEqual([0, 0, 0, 0, 0, 0, 0, 0]);
    expect(ipv6Hextets('1:2:3:4:5:6:7:8')).toEqual([1, 2, 3, 4, 5, 6, 7, 8]);
    expect(ipv6Hextets('::ffff:1.2.3.4')).toEqual([0, 0, 0, 0, 0, 0xffff, 0x0102, 0x0304]);
    expect(ipv6Hextets('1.2.3.4')).toBeNull();
  });
});
