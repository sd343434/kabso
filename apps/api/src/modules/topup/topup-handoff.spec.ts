import { randomBytes } from 'node:crypto';
import { Writable } from 'node:stream';
import { pino } from 'pino';
import { describe, expect, it } from 'vitest';
import { ConfigValidationError, loadConfig } from '../../config/app-config.js';
import { REDACT_PATHS } from '../../logging/logger.options.js';
import { redactText } from '../../logging/redact-text.js';
import { appLinkShownFor } from './topup-rules.js';

const base = {
  DATABASE_URL: 'postgresql://u:p@localhost:5432/db',
  REDIS_URL: 'redis://localhost:6379',
  JWT_ACCESS_SECRET: randomBytes(48).toString('base64url'),
  APP_PUBLIC_URL: 'https://kabso.example/',
};

describe('D344 website link per store (TOPUP_APP_LINK_PLATFORMS)', () => {
  it('defaults to both stores (the D190 behaviour) and parses a list or none', () => {
    expect(loadConfig(base).topup.appLinkPlatforms).toEqual(['android', 'ios']);
    expect(loadConfig({ ...base, TOPUP_APP_LINK_PLATFORMS: 'android' }).topup.appLinkPlatforms).toEqual([
      'android',
    ]);
    expect(loadConfig({ ...base, TOPUP_APP_LINK_PLATFORMS: '' }).topup.appLinkPlatforms).toEqual([]);
    expect(loadConfig(base).rateLimits.topupHandoffUser).toEqual({ max: 10, windowSeconds: 600 });
    expect(loadConfig(base).rateLimits.topupHandoffIp).toEqual({ max: 30, windowSeconds: 600 });
    for (const bad of ['web', 'android,web', 'ANDROID', 'android;ios']) {
      expect(() => loadConfig({ ...base, TOPUP_APP_LINK_PLATFORMS: bad }), bad).toThrow(
        ConfigValidationError,
      );
    }
  });

  it('shows the link by the session platform, after the master switch', () => {
    const both = ['android', 'ios'] as const;
    expect(appLinkShownFor('android', true, both)).toBe(true);
    expect(appLinkShownFor('ios', true, both)).toBe(true);
    expect(appLinkShownFor('ios', false, both)).toBe(false);
    expect(appLinkShownFor('ios', true, ['android'])).toBe(false);
    expect(appLinkShownFor('android', true, ['android'])).toBe(true);
    expect(appLinkShownFor('android', true, [])).toBe(false);
    // Another or no platform: only when no store hides it.
    expect(appLinkShownFor(null, true, both)).toBe(true);
    expect(appLinkShownFor('web', true, both)).toBe(true);
    expect(appLinkShownFor('other', true, ['android'])).toBe(false);
  });
});

describe('D344 the one-time code never reaches a log', () => {
  it('is redacted by key (handoff, websiteUrl) and by shape in free text', () => {
    const code = randomBytes(32).toString('base64url');
    const lines: string[] = [];
    const sink = new Writable({
      write(chunk: Buffer, _enc, cb) {
        lines.push(chunk.toString());
        cb();
      },
    });
    const logger = pino({ redact: { paths: REDACT_PATHS, censor: '[REDACTED]' } }, sink);
    logger.info({
      body: { handoff: code },
      handoff: code,
      result: { websiteUrl: `https://x/topup#h=${code}` },
    });
    expect(lines.join('')).not.toContain(code);
    expect(redactText(`exchange failed for https://api.kabso.example/topup?lang=ar#h=${code}`)).not.toContain(
      code,
    );
  });
});
