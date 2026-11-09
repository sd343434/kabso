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
    const rules = (enabled: boolean, platforms: readonly ('android' | 'ios')[]) => ({
      enabled,
      platforms,
      sources: ['SIDELOAD'] as const,
    });
    const s = (platform: string | null) => ({ platform, installSource: 'SIDELOAD' });
    expect(appLinkShownFor(s('android'), rules(true, both))).toBe(true);
    expect(appLinkShownFor(s('ios'), rules(true, both))).toBe(true);
    expect(appLinkShownFor(s('ios'), rules(false, both))).toBe(false);
    expect(appLinkShownFor(s('ios'), rules(true, ['android']))).toBe(false);
    expect(appLinkShownFor(s('android'), rules(true, ['android']))).toBe(true);
    expect(appLinkShownFor(s('android'), rules(true, []))).toBe(false);
    // Another or no platform: only when no store hides it.
    expect(appLinkShownFor(s(null), rules(true, both))).toBe(true);
    expect(appLinkShownFor(s('web'), rules(true, both))).toBe(true);
    expect(appLinkShownFor(s('other'), rules(true, ['android']))).toBe(false);
  });
});

describe('int21 website link per install source (TOPUP_APP_LINK_SOURCES)', () => {
  it('defaults to SIDELOAD (the direct APK) and parses a list or none', () => {
    expect(loadConfig(base).topup.appLinkSources).toEqual(['SIDELOAD']);
    expect(
      loadConfig({ ...base, TOPUP_APP_LINK_SOURCES: 'SIDELOAD,PLAY,SIDELOAD' }).topup.appLinkSources,
    ).toEqual(['SIDELOAD', 'PLAY']);
    expect(loadConfig({ ...base, TOPUP_APP_LINK_SOURCES: '' }).topup.appLinkSources).toEqual([]);
    for (const bad of ['sideload', 'TESTFLIGHT', 'PLAY;SIDELOAD', 'PLAY,']) {
      expect(() => loadConfig({ ...base, TOPUP_APP_LINK_SOURCES: bad }), bad).toThrow(ConfigValidationError);
    }
  });

  it('offers the link only to a session whose reported source is listed', () => {
    const both = ['android', 'ios'] as const;
    const on = { enabled: true, platforms: both, sources: ['SIDELOAD'] as const };
    expect(appLinkShownFor({ platform: 'android', installSource: 'SIDELOAD' }, on)).toBe(true);
    expect(appLinkShownFor({ platform: 'android', installSource: 'PLAY' }, on)).toBe(false);
    expect(appLinkShownFor({ platform: 'ios', installSource: 'APP_STORE' }, on)).toBe(false);
    // Not reported (an older app, the website), or no session: never.
    expect(appLinkShownFor({ platform: 'android', installSource: null }, on)).toBe(false);
    expect(appLinkShownFor(null, on)).toBe(false);
    // Configurable: the stores too, or nobody.
    const stores = { ...on, sources: ['PLAY', 'APP_STORE', 'SIDELOAD'] as const };
    expect(appLinkShownFor({ platform: 'ios', installSource: 'APP_STORE' }, stores)).toBe(true);
    expect(appLinkShownFor({ platform: 'android', installSource: 'SIDELOAD' }, { ...on, sources: [] })).toBe(
      false,
    );
    // TOPUP_APP_LINK_PLATFORMS still applies on top.
    expect(
      appLinkShownFor({ platform: 'android', installSource: 'SIDELOAD' }, { ...on, platforms: ['ios'] }),
    ).toBe(false);
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
