import { execFileSync } from 'node:child_process';
import { mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { describe, expect, it } from 'vitest';
import { exportReadme, maskTail } from './data-export.js';
import { truncateIp } from './legal.js';
import { ZipWriter } from './zip.js';

describe('D198 privacy helpers', () => {
  it('truncates IPv4 to /24 and IPv6 to /48, never keeps anything else', () => {
    expect(truncateIp('203.0.113.77')).toBe('203.0.113.0');
    expect(truncateIp('::ffff:10.1.2.3')).toBe('10.1.2.0');
    expect(truncateIp('2001:db8:abcd:12::1')).toBe('2001:db8:abcd::');
    expect(truncateIp('2001:0db8:0000:0000:0000:0000:0000:0001')).toBe('2001:db8:0::');
    expect(truncateIp('fe80::1%eth0')).toBe('fe80:0:0::');
    expect(truncateIp('1.2.3')).toBeNull();
    expect(truncateIp('')).toBeNull();
    expect(truncateIp(null)).toBeNull();
  });

  it('masks payout details to the last 4 characters', () => {
    expect(maskTail('IBAN SA00 0000 9876')).toBe('…9876');
    expect(maskTail('123')).toBe('…');
    expect(maskTail('…1234')).toBe('…1234');
  });

  it('writes a ZIP that unzip reads (UTF-8 names, stored and deflated entries)', () => {
    const zip = new ZipWriter(new Date('2026-11-01T10:00:00Z'));
    zip.add('README.txt', exportReadme(new Date('2026-11-01T10:00:00Z'), 'info@kabsolive.com'));
    zip.add('data/بيانات.json', '{"a":1}\n');
    zip.add('files/x.bin', Buffer.from([1, 2, 3]));
    expect(() => zip.add('../evil', 'x')).toThrow();
    expect(() => zip.add('data/بيانات.json', 'again')).toThrow();
    const dir = mkdtempSync(join(tmpdir(), 'zip-'));
    try {
      writeFileSync(join(dir, 'a.zip'), zip.finish());
      const out = execFileSync('unzip', ['-t', join(dir, 'a.zip')], { encoding: 'utf8' });
      expect(out).toContain('No errors detected');
      const readme = execFileSync('unzip', ['-p', join(dir, 'a.zip'), 'README.txt'], { encoding: 'utf8' });
      expect(readme).toContain('نسخة من بياناتك');
      expect(readme).toContain('a copy of your data');
    } finally {
      rmSync(dir, { recursive: true, force: true });
    }
  });
});
