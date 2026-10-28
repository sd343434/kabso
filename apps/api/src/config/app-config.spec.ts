import { randomBytes } from 'node:crypto';
import { describe, expect, it } from 'vitest';
import { ConfigValidationError, loadConfig } from './app-config.js';

const base = {
  DATABASE_URL: 'postgresql://u:p@localhost:5432/db',
  REDIS_URL: 'redis://localhost:6379',
  // Generated per run: never commit a secret-like literal (gitleaks).
  JWT_ACCESS_SECRET: randomBytes(48).toString('base64url'),
  APP_PUBLIC_URL: 'https://kabso.example/',
};

/** CP-010: livekit-server's public --dev settings. */
const LIVEKIT = {
  LIVEKIT_URL: 'ws://127.0.0.1:7880',
  LIVEKIT_API_KEY: 'devkey',
  LIVEKIT_API_SECRET: 'secret',
};

describe('loadConfig', () => {
  it('applies CONVENTIONS defaults', () => {
    const config = loadConfig(base);
    expect(config.jwt).toMatchObject({
      accessTtlSeconds: 900,
      issuer: 'kabso-api',
      audience: 'kabso-mobile',
    });
    expect(config.refresh).toEqual({ ttlSeconds: 2_592_000, absoluteTtlSeconds: 15_552_000 });
    expect(config.rateLimits.loginIpAccount).toEqual({ max: 10, windowSeconds: 900 });
    expect(config.rateLimits.loginAccount).toEqual({ max: 20, windowSeconds: 900 });
    expect(config.rateLimits.loginIp).toEqual({ max: 50, windowSeconds: 900 });
    expect(config.rateLimits.registerIp).toEqual({ max: 5, windowSeconds: 3600 });
    expect(config.rateLimits.forgotEmail).toEqual({ max: 3, windowSeconds: 3600 });
    expect(config.rateLimits.forgotIp).toEqual({ max: 10, windowSeconds: 3600 });
    expect(config.rateLimits.refreshSession).toEqual({ max: 60, windowSeconds: 900 });
    expect(config.rateLimits.authenticatedUser).toEqual({ max: 600, windowSeconds: 900 });
    expect(config.appPublicUrl).toBe('https://kabso.example');
    expect(config.http.trustProxy).toBe(false);
  });

  it('parses overrides', () => {
    const config = loadConfig({
      ...base,
      RATE_LIMIT_LOGIN_IP: '5/60',
      CORS_ORIGINS: 'https://a.example, https://b.example',
      TRUST_PROXY: '1',
    });
    expect(config.rateLimits.loginIp).toEqual({ max: 5, windowSeconds: 60 });
    expect(config.http.corsOrigins).toEqual(['https://a.example', 'https://b.example']);
    expect(config.http.trustProxy).toBe(1);
  });

  it('fails fast listing every problem without echoing secret values', () => {
    let error: unknown;
    try {
      loadConfig({ JWT_ACCESS_SECRET: 'tooshort', RATE_LIMIT_LOGIN_IP: 'ten' });
    } catch (err) {
      error = err;
    }
    expect(error).toBeInstanceOf(ConfigValidationError);
    const message = (error as Error).message;
    expect(message).toContain('DATABASE_URL');
    expect(message).toContain('REDIS_URL');
    expect(message).toContain('JWT_ACCESS_SECRET: must be at least 32 bytes');
    expect(message).toContain('RATE_LIMIT_LOGIN_IP');
    expect(message).toContain('APP_PUBLIC_URL');
    expect(message).not.toContain('tooshort');
  });

  it('rejects placeholder secrets and the log mail transport in production', () => {
    expect(() =>
      loadConfig({
        ...base,
        NODE_ENV: 'production',
        JWT_ACCESS_SECRET: 'replace-me-with-a-long-random-string-of-at-least-32-bytes',
      }),
    ).toThrow(/JWT_ACCESS_SECRET: looks like a placeholder[\s\S]*MAIL_TRANSPORT/);
  });

  it('rejects an absolute refresh TTL shorter than the sliding TTL', () => {
    expect(() =>
      loadConfig({ ...base, REFRESH_TTL_SECONDS: '100', REFRESH_ABSOLUTE_TTL_SECONDS: '50' }),
    ).toThrow(/REFRESH_ABSOLUTE_TTL_SECONDS/);
  });

  describe('production hardening (KL-011)', () => {
    const hex = () => randomBytes(32).toString('hex');
    const prod = (overrides: Record<string, string> = {}) => ({
      ...base,
      NODE_ENV: 'production',
      JWT_ACCESS_SECRET: hex(),
      RATE_LIMIT_KEY_SECRET: hex(),
      LIVE_CURSOR_KEY: hex(),
      ...overrides,
    });
    function problems(env: Record<string, string>): string[] {
      try {
        loadConfig(env);
        return [];
      } catch (err) {
        if (err instanceof ConfigValidationError) return [...err.problems];
        throw err;
      }
    }
    const about = (env: Record<string, string>, key: string) =>
      problems(env).filter((p) => p.startsWith(`${key}:`));

    it('refuses TRUST_PROXY=true in production but accepts it in development (SEC-003)', () => {
      expect(about(prod({ TRUST_PROXY: 'true' }), 'TRUST_PROXY')).toHaveLength(1);
      expect(loadConfig({ ...base, TRUST_PROXY: 'true' }).http.trustProxy).toBe(true);
    });

    it('accepts a hop count or an address/CIDR list in production', () => {
      expect(about(prod({ TRUST_PROXY: '1' }), 'TRUST_PROXY')).toEqual([]);
      expect(about(prod({ TRUST_PROXY: '10.0.0.0/8, 2001:db8::/32, 192.0.2.7' }), 'TRUST_PROXY')).toEqual([]);
      expect(about(prod({ TRUST_PROXY: 'loopback' }), 'TRUST_PROXY')).toEqual([]);
    });

    it.each(['yes', '10.0.0.0/33', 'proxy.internal', '1.2.3.4/8/1'])(
      'refuses malformed TRUST_PROXY entry %s',
      (value) => {
        expect(about({ ...base, TRUST_PROXY: value }, 'TRUST_PROXY')).toHaveLength(1);
      },
    );

    it.each([
      'abcdefghijklmnopqrstuvwxyzABCDEF',
      'kabso-live-production-jwt-key-2026!',
      '0123456789012345678901234567890123',
    ])('refuses the weak JWT secret from the review in production: %s (SEC-005)', (secret) => {
      expect(about(prod({ JWT_ACCESS_SECRET: secret }), 'JWT_ACCESS_SECRET')).toHaveLength(1);
    });

    it('requires a strong RATE_LIMIT_KEY_SECRET distinct from the JWT secret (SEC-010)', () => {
      const env = prod();
      delete (env as Record<string, string | undefined>).RATE_LIMIT_KEY_SECRET;
      expect(about(env, 'RATE_LIMIT_KEY_SECRET')).toEqual([
        'RATE_LIMIT_KEY_SECRET: is required in production',
      ]);
      const shared = hex();
      expect(
        about(prod({ JWT_ACCESS_SECRET: shared, RATE_LIMIT_KEY_SECRET: shared }), 'RATE_LIMIT_KEY_SECRET'),
      ).toHaveLength(1);
      expect(about(prod({ RATE_LIMIT_KEY_SECRET: 'b'.repeat(48) }), 'RATE_LIMIT_KEY_SECRET')).toHaveLength(1);
      // Production config with generated secrets has no secret/proxy problems (only the B2 mail block).
      expect(problems(prod()).map((p) => p.split(':')[0])).toEqual(['MAIL_TRANSPORT']);
    });

    describe('SMTP mail (KL-042)', () => {
      const smtp = {
        MAIL_TRANSPORT: 'smtp',
        MAIL_FROM: 'Kabso Live <no-reply@kabso.example>',
        SMTP_HOST: 'smtp.kabso.example',
        SMTP_USER: 'no-reply@kabso.example',
        SMTP_PASSWORD: 'app-password',
      };

      it('is the production transport: a production config with SMTP has no problems', () => {
        expect(problems(prod(smtp))).toEqual([]);
        expect(loadConfig(prod(smtp)).smtp).toEqual({
          host: 'smtp.kabso.example',
          port: 465,
          secure: true,
          user: 'no-reply@kabso.example',
          password: 'app-password',
          from: 'Kabso Live <no-reply@kabso.example>',
        });
        expect(loadConfig(prod({ ...smtp, SMTP_PORT: '587', SMTP_SECURE: 'false' })).smtp).toMatchObject({
          port: 587,
          secure: false,
        });
      });

      it.each(['MAIL_FROM', 'SMTP_HOST', 'SMTP_USER', 'SMTP_PASSWORD'])('requires %s with smtp', (key) => {
        const env: Record<string, string> = { ...smtp };
        delete env[key];
        expect(about(prod(env), key)).toEqual([`${key}: is required when MAIL_TRANSPORT=smtp`]);
      });

      it.each(['no-reply', 'Kabso <no-reply>', '<a@b>', 'a@b', 'Kabso <a@b.c', 'a@b.c>'])(
        'refuses the sender %s',
        (from) => {
          expect(about(prod({ ...smtp, MAIL_FROM: from }), 'MAIL_FROM')).toHaveLength(1);
        },
      );

      it.each(['no-reply@kabso.example', 'Kabso Live <no-reply@kabso.example>'])(
        'accepts the sender %s',
        (from) => {
          expect(about(prod({ ...smtp, MAIL_FROM: from }), 'MAIL_FROM')).toEqual([]);
        },
      );

      it('has no SMTP settings with the log transport', () => {
        expect(loadConfig(base).smtp).toBeNull();
        expect(() => loadConfig({ ...base, SMTP_SECURE: 'yes' })).toThrow(/SMTP_SECURE/);
      });
    });

    it('generates a per-process rate-limit key outside production', () => {
      const a = loadConfig(base).rateLimitKeySecret;
      const b = loadConfig(base).rateLimitKeySecret;
      expect(a).not.toBe(b);
      expect(Buffer.from(a, 'base64url').length).toBe(32);
    });

    it('configures the Argon2 cap (default = CPU count)', () => {
      expect(loadConfig(base).argon2.maxConcurrency).toBeGreaterThanOrEqual(1);
      expect(loadConfig({ ...base, ARGON2_MAX_CONCURRENCY: '2', ARGON2_MAX_QUEUE: '0' }).argon2).toEqual({
        maxConcurrency: 2,
        maxQueue: 0,
      });
      expect(() => loadConfig({ ...base, ARGON2_MAX_CONCURRENCY: '0' })).toThrow(/ARGON2_MAX_CONCURRENCY/);
    });
  });

  describe('SEC-003a (contract v1.2 §7)', () => {
    const hex = () => randomBytes(32).toString('hex');
    const prod = (trustProxy: string) => ({
      ...base,
      NODE_ENV: 'production',
      JWT_ACCESS_SECRET: hex(),
      RATE_LIMIT_KEY_SECRET: hex(),
      LIVE_CURSOR_KEY: hex(),
      TRUST_PROXY: trustProxy,
    });
    const trustProxyProblems = (env: Record<string, string>) => {
      try {
        loadConfig(env);
        return [];
      } catch (err) {
        return (err as ConfigValidationError).problems.filter((p) => p.startsWith('TRUST_PROXY'));
      }
    };

    it.each(['0.0.0.0/0', '::/0', '10.0.0.0/8, 0.0.0.0/0', '4', '10'])(
      'refuses TRUST_PROXY=%s in production',
      (value) => {
        expect(trustProxyProblems(prod(value))).toHaveLength(1);
      },
    );

    it.each(['1', '3', '10.0.0.0/8', '2001:db8::/32'])('accepts TRUST_PROXY=%s in production', (value) => {
      expect(trustProxyProblems(prod(value))).toEqual([]);
    });

    it('still allows /0 and large hop counts outside production', () => {
      expect(loadConfig({ ...base, TRUST_PROXY: '0.0.0.0/0' }).http.trustProxy).toEqual(['0.0.0.0/0']);
      expect(loadConfig({ ...base, TRUST_PROXY: '5' }).http.trustProxy).toBe(5);
    });
  });

  describe('v1.2.3 (SEC-003a broad ranges, SEC-029 code key)', () => {
    const hex = () => randomBytes(32).toString('hex');
    const prod = (extra: Record<string, string>) => ({
      ...base,
      NODE_ENV: 'production',
      JWT_ACCESS_SECRET: hex(),
      RATE_LIMIT_KEY_SECRET: hex(),
      LIVE_CURSOR_KEY: hex(),
      ...extra,
    });
    const problemsFor = (env: Record<string, string>, key: string) => {
      try {
        loadConfig(env);
        return [];
      } catch (err) {
        return (err as ConfigValidationError).problems.filter((p) => p.startsWith(key));
      }
    };

    it.each([
      '0.0.0.0/1,128.0.0.0/1',
      '10.0.0.0/7',
      '::/1,8000::/1',
      '2001:db8::/31',
      '::ffff:0:0/96',
      '::ffff:0.0.0.0/100',
    ])('refuses TRUST_PROXY=%s in production', (value) => {
      expect(problemsFor(prod({ TRUST_PROXY: value }), 'TRUST_PROXY')).toHaveLength(1);
    });

    it.each(['10.0.0.0/8', '2001:db8::/32', '::ffff:10.0.0.0/104', '192.0.2.7', '::1', '2'])(
      'accepts TRUST_PROXY=%s in production',
      (value) => {
        expect(problemsFor(prod({ TRUST_PROXY: value }), 'TRUST_PROXY')).toEqual([]);
      },
    );

    it('REGISTRATION_CODE_KEY is optional, strength-checked and distinct in production', () => {
      expect(loadConfig(base).registration.codeKey).toBeUndefined();
      const key = hex();
      expect(loadConfig({ ...base, REGISTRATION_CODE_KEY: key }).registration.codeKey).toBe(key);
      expect(
        problemsFor(prod({ REGISTRATION_CODE_KEY: 'short' }), 'REGISTRATION_CODE_KEY').length,
      ).toBeGreaterThan(0);
      expect(
        problemsFor(prod({ REGISTRATION_CODE_KEY: 'b'.repeat(64) }), 'REGISTRATION_CODE_KEY'),
      ).toHaveLength(1);
      const shared = hex();
      expect(
        problemsFor(
          prod({ RATE_LIMIT_KEY_SECRET: shared, REGISTRATION_CODE_KEY: shared }),
          'REGISTRATION_CODE_KEY',
        ),
      ).toHaveLength(1);
      expect(problemsFor(prod({ REGISTRATION_CODE_KEY: hex() }), 'REGISTRATION_CODE_KEY')).toEqual([]);
    });

    it('defaults: pending lifetime 2 h, verify budget 15/day per email', () => {
      const config = loadConfig(base);
      expect(config.registration.maxLifetimeSeconds).toBe(7200);
      expect(config.rateLimits.registerVerifyEmail).toEqual({ max: 15, windowSeconds: 86400 });
      expect(config.reservedDisplayNameTerms).not.toContain('staff');
      expect(config.reservedDisplayNameTerms).not.toContain('مشرف');
    });
  });

  describe('live discovery (contract v1.3, KL-037)', () => {
    const hex = () => randomBytes(32).toString('hex');
    const prod = (extra: Record<string, string> = {}) => ({
      ...base,
      NODE_ENV: 'production',
      MAIL_TRANSPORT: 'log',
      JWT_ACCESS_SECRET: hex(),
      RATE_LIMIT_KEY_SECRET: hex(),
      LIVE_CURSOR_KEY: hex(),
      ...extra,
    });
    const problemsFor = (env: Record<string, string>, key: string) => {
      try {
        loadConfig(env);
        return [];
      } catch (err) {
        return (err as ConfigValidationError).problems.filter((p) => p.startsWith(key));
      }
    };

    it('defaults: hosting off, 15 s cadence, 45 s stale window, 15 s sweep, CONVENTIONS §7 limits', () => {
      const config = loadConfig(base);
      expect(config.live).toMatchObject({
        hostingEnabled: false,
        heartbeatIntervalSeconds: 15,
        heartbeatStaleSeconds: 45,
        sweepIntervalSeconds: 15,
      });
      expect(config.rateLimits).toMatchObject({
        liveListUser: { max: 300, windowSeconds: 900 },
        profileUser: { max: 300, windowSeconds: 900 },
        liveStartHourUser: { max: 10, windowSeconds: 3600 },
        liveStartDayUser: { max: 30, windowSeconds: 86400 },
        liveHeartbeatUser: { max: 12, windowSeconds: 60 },
        liveEndUser: { max: 30, windowSeconds: 3600 },
        followHourUser: { max: 60, windowSeconds: 3600 },
        followDayUser: { max: 300, windowSeconds: 86400 },
      });
    });

    it('LIVE_HOSTING_ENABLED accepts only "true" / "false"', () => {
      // CP-010: turning hosting on also needs the media server (next test).
      expect(loadConfig({ ...base, ...LIVEKIT, LIVE_HOSTING_ENABLED: 'true' }).live.hostingEnabled).toBe(
        true,
      );
      expect(loadConfig({ ...base, LIVE_HOSTING_ENABLED: 'false' }).live.hostingEnabled).toBe(false);
      for (const value of ['1', 'yes', 'TRUE', 'on', '']) {
        expect(problemsFor({ ...base, LIVE_HOSTING_ENABLED: value }, 'LIVE_HOSTING_ENABLED')).toHaveLength(1);
      }
    });

    it('hosting needs LIVEKIT_URL, LIVEKIT_API_KEY and LIVEKIT_API_SECRET; production needs wss (CP-010)', () => {
      for (const key of ['LIVEKIT_URL', 'LIVEKIT_API_KEY', 'LIVEKIT_API_SECRET'] as const) {
        expect(problemsFor({ ...base, LIVE_HOSTING_ENABLED: 'true' }, key)).toEqual([
          `${key}: is required when LIVE_HOSTING_ENABLED=true`,
        ]);
      }
      expect(loadConfig({ ...base, ...LIVEKIT }).live.livekit).toEqual({
        url: 'ws://127.0.0.1:7880',
        apiKey: 'devkey',
        apiSecret: 'secret',
      });
      expect(loadConfig(base).live.livekit).toBeNull();
      expect(problemsFor({ ...base, LIVEKIT_URL: 'http://x' }, 'LIVEKIT_URL')).toHaveLength(1);
      expect(
        problemsFor(
          prod({ LIVEKIT_URL: 'ws://media.example', LIVEKIT_API_KEY: 'k', LIVEKIT_API_SECRET: 'secret' }),
          'LIVEKIT_URL',
        ),
      ).toEqual(['LIVEKIT_URL: must use wss in production']);
      expect(
        problemsFor(
          prod({ LIVEKIT_URL: 'wss://media.example', LIVEKIT_API_KEY: 'k', LIVEKIT_API_SECRET: 'secret' }),
          'LIVEKIT_API_SECRET',
        ),
      ).toHaveLength(1);
    });

    it('heartbeat interval is 5–60 s and the stale window at least twice the interval', () => {
      expect(
        problemsFor({ ...base, LIVE_HEARTBEAT_INTERVAL_SECONDS: '4' }, 'LIVE_HEARTBEAT_INTERVAL'),
      ).toHaveLength(1);
      expect(
        problemsFor({ ...base, LIVE_HEARTBEAT_INTERVAL_SECONDS: '61' }, 'LIVE_HEARTBEAT_INTERVAL'),
      ).toHaveLength(1);
      expect(
        problemsFor(
          { ...base, LIVE_HEARTBEAT_INTERVAL_SECONDS: '20', LIVE_HEARTBEAT_STALE_SECONDS: '39' },
          'LIVE_HEARTBEAT_STALE',
        ),
      ).toHaveLength(1);
      const ok = loadConfig({
        ...base,
        LIVE_HEARTBEAT_INTERVAL_SECONDS: '20',
        LIVE_HEARTBEAT_STALE_SECONDS: '40',
      });
      expect(ok.live).toMatchObject({ heartbeatIntervalSeconds: 20, heartbeatStaleSeconds: 40 });
      expect(
        problemsFor({ ...base, LIVE_HEARTBEAT_STALE_SECONDS: '0' }, 'LIVE_HEARTBEAT_STALE').length,
      ).toBeGreaterThan(0);
    });

    it('the sweeper may be disabled (0) only outside production', () => {
      expect(loadConfig({ ...base, LIVE_SWEEP_INTERVAL_SECONDS: '0' }).live.sweepIntervalSeconds).toBe(0);
      expect(
        problemsFor(prod({ LIVE_SWEEP_INTERVAL_SECONDS: '0' }), 'LIVE_SWEEP_INTERVAL_SECONDS'),
      ).toHaveLength(1);
      expect(problemsFor(prod(), 'LIVE_SWEEP_INTERVAL_SECONDS')).toEqual([]);
    });

    it('LIVE_CURSOR_KEY is optional, strength-checked and distinct in production', () => {
      const env = prod();
      delete (env as Record<string, string | undefined>).LIVE_CURSOR_KEY;
      expect(problemsFor(env, 'LIVE_CURSOR_KEY')).toEqual([]);
      expect(loadConfig({ ...env, MAIL_TRANSPORT: 'log', NODE_ENV: 'test' }).live.cursorKey).toBe(
        env.RATE_LIMIT_KEY_SECRET,
      );
      expect(problemsFor(prod({ LIVE_CURSOR_KEY: 'short' }), 'LIVE_CURSOR_KEY').length).toBeGreaterThan(0);
      expect(problemsFor(prod({ LIVE_CURSOR_KEY: 'b'.repeat(64) }), 'LIVE_CURSOR_KEY')).toHaveLength(1);
      expect(
        problemsFor(
          prod({ LIVE_CURSOR_KEY: 'change-me-generate-with-openssl-rand-base64-48' }),
          'LIVE_CURSOR_KEY',
        ),
      ).toHaveLength(1);
      for (const other of ['JWT_ACCESS_SECRET', 'RATE_LIMIT_KEY_SECRET', 'REGISTRATION_CODE_KEY']) {
        const shared = hex();
        expect(
          problemsFor(prod({ [other]: shared, LIVE_CURSOR_KEY: shared }), 'LIVE_CURSOR_KEY'),
        ).toHaveLength(1);
      }
      expect(problemsFor(prod({ LIVE_CURSOR_KEY: hex() }), 'LIVE_CURSOR_KEY')).toEqual([]);
    });

    it('LIVE_SWEEP_BATCH_SIZE defaults to 500 and is bounded (SEC-035)', () => {
      expect(loadConfig(base).live.sweepBatchSize).toBe(500);
      expect(loadConfig({ ...base, LIVE_SWEEP_BATCH_SIZE: '1' }).live.sweepBatchSize).toBe(1);
      expect(loadConfig({ ...base, LIVE_SWEEP_BATCH_SIZE: '5000' }).live.sweepBatchSize).toBe(5000);
      for (const value of ['0', '5001', '-1', '1e3', '', ' 500', '500.0']) {
        expect(problemsFor({ ...base, LIVE_SWEEP_BATCH_SIZE: value }, 'LIVE_SWEEP_BATCH_SIZE')).toHaveLength(
          1,
        );
      }
    });

    it('numeric settings accept plain decimal integers only (no exponent, hex, padding or empty)', () => {
      expect(
        loadConfig({ ...base, LIVE_HEARTBEAT_INTERVAL_SECONDS: '10', LIVE_HEARTBEAT_STALE_SECONDS: '30' })
          .live,
      ).toMatchObject({ heartbeatIntervalSeconds: 10, heartbeatStaleSeconds: 30 });
      for (const [name, value] of [
        ['LIVE_HEARTBEAT_INTERVAL_SECONDS', '1e1'],
        ['LIVE_HEARTBEAT_INTERVAL_SECONDS', '0x10'],
        ['LIVE_HEARTBEAT_INTERVAL_SECONDS', ' 15'],
        ['LIVE_HEARTBEAT_INTERVAL_SECONDS', '015'],
        ['LIVE_SWEEP_INTERVAL_SECONDS', ''],
        ['LIVE_HEARTBEAT_STALE_SECONDS', '45.0'],
        ['PORT', '+3000'],
        ['JWT_ACCESS_TTL_SECONDS', '9e2'],
        ['ARGON2_MAX_QUEUE', '-0'],
      ] as const) {
        expect(problemsFor({ ...base, [name]: value }, name)).toHaveLength(1);
      }
      expect(loadConfig({ ...base, PORT: '8080', JWT_ACCESS_TTL_SECONDS: '600' })).toMatchObject({
        port: 8080,
        jwt: { accessTtlSeconds: 600 },
      });
    });

    it('production requires 2× heartbeat headroom in the heartbeat bucket', () => {
      expect(problemsFor(prod(), 'RATE_LIMIT_LIVE_HEARTBEAT_USER')).toEqual([]); // 12/60 at 15 s = 3×
      expect(
        problemsFor(prod({ LIVE_HEARTBEAT_INTERVAL_SECONDS: '10' }), 'RATE_LIMIT_LIVE_HEARTBEAT_USER'),
      ).toEqual([]); // 12/60 at 10 s = 2×
      expect(
        problemsFor(
          prod({ LIVE_HEARTBEAT_INTERVAL_SECONDS: '5', LIVE_HEARTBEAT_STALE_SECONDS: '15' }),
          'RATE_LIMIT_LIVE_HEARTBEAT_USER',
        ),
      ).toHaveLength(1); // 12/60 at 5 s = 1×
      expect(
        problemsFor(
          prod({
            LIVE_HEARTBEAT_INTERVAL_SECONDS: '5',
            LIVE_HEARTBEAT_STALE_SECONDS: '15',
            RATE_LIMIT_LIVE_HEARTBEAT_USER: '24/60',
          }),
          'RATE_LIMIT_LIVE_HEARTBEAT_USER',
        ),
      ).toEqual([]);
      // Outside production a tight bucket stays possible (rate-limit tests).
      expect(
        problemsFor({ ...base, RATE_LIMIT_LIVE_HEARTBEAT_USER: '2/60' }, 'RATE_LIMIT_LIVE_HEARTBEAT_USER'),
      ).toEqual([]);
    });

    it('the cursor key source falls back to RATE_LIMIT_KEY_SECRET', () => {
      const rate = hex();
      expect(loadConfig({ ...base, RATE_LIMIT_KEY_SECRET: rate }).live.cursorKey).toBe(rate);
      const key = hex();
      expect(loadConfig({ ...base, RATE_LIMIT_KEY_SECRET: rate, LIVE_CURSOR_KEY: key }).live.cursorKey).toBe(
        key,
      );
      expect(problemsFor({ ...base, LIVE_CURSOR_KEY: 'short' }, 'LIVE_CURSOR_KEY')).toHaveLength(1);
    });
  });
});

describe('loadConfig — v1.5-social media and posts (CONVENTIONS §11)', () => {
  it('keeps uploads off by default with the §11.8 rate limits', () => {
    const config = loadConfig(base);
    expect(config.media.uploadsEnabled).toBe(false);
    expect(config.media.s3.region).toBe('auto');
    expect(config.media.sweepIntervalSeconds).toBe(300);
    expect(config.social.publishIntervalSeconds).toBe(30);
    expect(config.rateLimits.mediaUploadUser).toEqual({ max: 60, windowSeconds: 3600 });
    expect(config.rateLimits.postCreateHourUser).toEqual({ max: 20, windowSeconds: 3600 });
    expect(config.rateLimits.postCreateDayUser).toEqual({ max: 100, windowSeconds: 86400 });
    expect(config.rateLimits.commentUser).toEqual({ max: 60, windowSeconds: 3600 });
    expect(config.rateLimits.likeUser).toEqual({ max: 600, windowSeconds: 3600 });
    expect(config.rateLimits.feedUser).toEqual({ max: 300, windowSeconds: 900 });
    expect(config.rateLimits.reportUser).toEqual({ max: 30, windowSeconds: 3600 });
    expect(config.rateLimits.storyCreateUser).toEqual({ max: 30, windowSeconds: 3600 });
    expect(config.rateLimits.storySeenUser).toEqual({ max: 600, windowSeconds: 3600 });
  });

  it('needs the bucket, credentials and public URL when uploads are on, never echoing secrets', () => {
    let error: unknown;
    try {
      loadConfig({ ...base, MEDIA_UPLOADS_ENABLED: 'true', S3_SECRET_ACCESS_KEY: 'super-secret-value' });
    } catch (err) {
      error = err;
    }
    const message = (error as Error).message;
    expect(message).toContain('S3_BUCKET: is required when MEDIA_UPLOADS_ENABLED=true');
    expect(message).toContain('S3_ACCESS_KEY_ID');
    expect(message).toContain('MEDIA_PUBLIC_BASE_URL');
    expect(message).not.toContain('S3_SECRET_ACCESS_KEY: is required');
    expect(message).not.toContain('super-secret-value');
    const config = loadConfig({
      ...base,
      MEDIA_UPLOADS_ENABLED: 'true',
      S3_ENDPOINT: 'http://localhost:9000',
      S3_BUCKET: 'kabso-media-dev',
      S3_ACCESS_KEY_ID: 'id',
      S3_SECRET_ACCESS_KEY: 'secret',
      S3_FORCE_PATH_STYLE: 'true',
      MEDIA_PUBLIC_BASE_URL: 'http://localhost:9000/kabso-media-dev/',
    });
    expect(config.media.s3.forcePathStyle).toBe(true);
    expect(config.media.publicBaseUrl).toBe('http://localhost:9000/kabso-media-dev');
  });

  it('runs the notifications sweeper hourly by default and limits marking read to 120 per hour (CP-009)', () => {
    const config = loadConfig(base);
    expect(config.social.notificationsSweepIntervalSeconds).toBe(3600);
    expect(config.rateLimits.notificationsReadUser).toEqual({ max: 120, windowSeconds: 3600 });
    expect(
      loadConfig({ ...base, NOTIFICATIONS_SWEEP_INTERVAL_SECONDS: '0' }).social
        .notificationsSweepIntervalSeconds,
    ).toBe(0);
  });

  it('reads the CP-021 CP space buckets (defaults and overrides)', () => {
    expect(loadConfig(base).rateLimits.cpSpaceWriteUser).toEqual({ max: 60, windowSeconds: 60 });
    expect(loadConfig(base).rateLimits.cpConfessionUser).toEqual({ max: 10, windowSeconds: 3600 });
    expect(
      loadConfig({ ...base, RATE_LIMIT_CP_CONFESSION_USER: '3/60' }).rateLimits.cpConfessionUser,
    ).toEqual({ max: 3, windowSeconds: 60 });
  });

  it('reads the v1.32-live host share per gift category and the quip queue limit (D154)', () => {
    expect(loadConfig(base).gifts.hostShareBps).toEqual({
      POPULAR: 6500,
      EVENT: 6500,
      FUN: 6500,
      QUIPS: 5000,
    });
    expect(loadConfig(base).gifts.quipMaxWaitMs).toBe(60_000);
    expect(
      loadConfig({ ...base, GIFT_HOST_SHARE_PERCENTS: ' QUIPS:40 , FUN:70,EVENT:65.5,POPULAR:0' }).gifts
        .hostShareBps,
    ).toEqual({ POPULAR: 0, EVENT: 6550, FUN: 7000, QUIPS: 4000 });
    for (const bad of [
      'POPULAR:65,EVENT:65,FUN:65',
      'POPULAR:65,EVENT:65,FUN:65,QUIPS:50,LUCKY:10',
      'POPULAR:65,EVENT:65,FUN:65,QUIPS:101',
      'POPULAR:65,POPULAR:60,EVENT:65,FUN:65,QUIPS:50',
      'POPULAR:65,EVENT:65,FUN:65,QUIPS',
    ]) {
      expect(() => loadConfig({ ...base, GIFT_HOST_SHARE_PERCENTS: bad }), bad).toThrow(
        /GIFT_HOST_SHARE_PERCENTS/,
      );
    }
    expect(() => loadConfig({ ...base, QUIP_QUEUE_MAX_WAIT_SECONDS: '4' })).toThrow(
      /QUIP_QUEUE_MAX_WAIT_SECONDS/,
    );
  });

  it('reads the CP-020 gift quantities and the gift-send bucket', () => {
    expect(loadConfig(base).gifts.quantities).toEqual([1, 10, 66, 99, 188, 520, 1314]);
    expect(loadConfig(base).rateLimits.liveGiftUser).toEqual({ max: 120, windowSeconds: 60 });
    // D145c / D145d: lucky gifts' own limits (100 a second, 6000 a minute).
    expect(loadConfig(base).rateLimits.liveGiftAnyUser).toEqual({ max: 6000, windowSeconds: 60 });
    expect(loadConfig(base).rateLimits.liveLuckyGiftBurstUser).toEqual({ max: 100, windowSeconds: 1 });
    expect(loadConfig({ ...base, LIVE_GIFT_QUANTITIES: ' 1, 5 ,9999' }).gifts.quantities).toEqual([
      1, 5, 9999,
    ]);
    expect(loadConfig({ ...base, LIVE_GIFT_QUANTITIES: '7' }).gifts.quantities).toEqual([7]);
    for (const bad of [
      '',
      '0',
      '1,1',
      '10,1',
      '1,10000',
      '1,x',
      '01',
      '1.5',
      '-1',
      '1,,2',
      '1,2,3,4,5,6,7,8,9,10,11,12,13',
    ]) {
      expect(() => loadConfig({ ...base, LIVE_GIFT_QUANTITIES: bad }), bad).toThrow(/LIVE_GIFT_QUANTITIES/);
    }
  });

  it('D155: direct messages live 24 h; the sweeper runs by default and cannot be off in production', () => {
    expect(loadConfig(base).dm).toEqual({
      retentionHours: 24,
      sweepIntervalSeconds: 60,
      requestMaxMessages: 3,
      deleteForEveryoneSeconds: 3600,
      giftRecipientSharePercent: 50,
    });
    expect(loadConfig(base).rateLimits.dmSendUser).toEqual({ max: 30, windowSeconds: 60 });
    expect(loadConfig(base).rateLimits.dmRequestUser).toEqual({ max: 20, windowSeconds: 3600 });
    expect(loadConfig(base).rateLimits.dmWriteUser).toEqual({ max: 300, windowSeconds: 3600 });
    expect(loadConfig({ ...base, DM_SWEEP_INTERVAL_SECONDS: '0' }).dm.sweepIntervalSeconds).toBe(0);
    expect(() => loadConfig({ ...base, NODE_ENV: 'production', DM_SWEEP_INTERVAL_SECONDS: '0' })).toThrow(
      /DM_SWEEP_INTERVAL_SECONDS/,
    );
    for (const [key, bad] of [
      ['DM_RETENTION_HOURS', '0'],
      ['GIFT_DM_RECIPIENT_SHARE_PERCENT', '101'],
      ['DM_REQUEST_MAX_MESSAGES', '0'],
    ] as const) {
      expect(() => loadConfig({ ...base, [key]: bad }), key).toThrow(new RegExp(key));
    }
  });

  it('runs the CP-018 family and CP request sweeper by default and refuses disabling it in production', () => {
    expect(loadConfig(base).social.bondsSweepIntervalSeconds).toBe(300);
    expect(loadConfig({ ...base, BONDS_SWEEP_INTERVAL_SECONDS: '0' }).social.bondsSweepIntervalSeconds).toBe(
      0,
    );
    expect(() => loadConfig({ ...base, NODE_ENV: 'production', BONDS_SWEEP_INTERVAL_SECONDS: '0' })).toThrow(
      /BONDS_SWEEP_INTERVAL_SECONDS/,
    );
  });

  it('refuses plain http storage, disabled workers and a weak cursor key in production', () => {
    expect(() =>
      loadConfig({
        ...base,
        NODE_ENV: 'production',
        S3_ENDPOINT: 'http://r2.example',
        MEDIA_PUBLIC_BASE_URL: 'http://cdn.example',
        MEDIA_SWEEP_INTERVAL_SECONDS: '0',
        POSTS_PUBLISH_INTERVAL_SECONDS: '0',
        NOTIFICATIONS_SWEEP_INTERVAL_SECONDS: '0',
        SOCIAL_CURSOR_KEY: 'replace-me-with-a-long-random-string-of-at-least-32-bytes',
      }),
    ).toThrow(
      /S3_ENDPOINT: must use https[\s\S]*MEDIA_PUBLIC_BASE_URL: must use https[\s\S]*MEDIA_SWEEP_INTERVAL_SECONDS[\s\S]*POSTS_PUBLISH_INTERVAL_SECONDS[\s\S]*NOTIFICATIONS_SWEEP_INTERVAL_SECONDS[\s\S]*SOCIAL_CURSOR_KEY/,
    );
  });
});
