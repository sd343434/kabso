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
      expect(loadConfig({ ...base, LIVE_HOSTING_ENABLED: 'true' }).live.hostingEnabled).toBe(true);
      expect(loadConfig({ ...base, LIVE_HOSTING_ENABLED: 'false' }).live.hostingEnabled).toBe(false);
      for (const value of ['1', 'yes', 'TRUE', 'on', '']) {
        expect(problemsFor({ ...base, LIVE_HOSTING_ENABLED: value }, 'LIVE_HOSTING_ENABLED')).toHaveLength(1);
      }
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
  describe('media uploads (contract v1.4, KL-049)', () => {
    const hex = () => randomBytes(32).toString('hex');
    const storage = () => ({
      MEDIA_STORAGE_ENDPOINT: 'https://account.r2.example.invalid',
      MEDIA_STORAGE_REGION: 'auto',
      MEDIA_STORAGE_INCOMING_BUCKET: 'kabso-incoming',
      MEDIA_STORAGE_PUBLIC_BUCKET: 'kabso-public',
      MEDIA_STORAGE_ACCESS_KEY_ID: `id${randomBytes(8).toString('hex')}`,
      MEDIA_STORAGE_SECRET_ACCESS_KEY: randomBytes(30).toString('base64url'),
      MEDIA_PUBLIC_BASE_URL: 'https://media.kabso-cdn.example',
    });
    const prod = (extra: Record<string, string> = {}) => ({
      ...base,
      NODE_ENV: 'production',
      MAIL_TRANSPORT: 'log',
      JWT_ACCESS_SECRET: hex(),
      RATE_LIMIT_KEY_SECRET: hex(),
      ...extra,
    });
    const problems = (env: Record<string, string>) => {
      try {
        loadConfig(env);
        return [];
      } catch (err) {
        return (err as ConfigValidationError).problems.filter((p) => p.startsWith('MEDIA_'));
      }
    };

    it('defaults: uploads off, moderation none, no storage, contract limits and CONVENTIONS §7 rates', () => {
      const config = loadConfig(base);
      expect(config.media).toEqual({
        uploadsEnabled: false,
        moderationProvider: 'none',
        storage: null,
        publicBaseUrl: null,
        uploadUrlTtlSeconds: 600,
        maxPendingPerUser: 5,
        dailyBytesPerUser: 104_857_600,
        processMaxConcurrency: 2,
        processTimeoutMs: 10_000,
        unattachedTtlHours: 24,
        deleteGraceHours: 24,
        endedRoomCoverTtlHours: 24,
        cleanupIntervalSeconds: 300,
        cleanupBatchSize: 500,
      });
      expect(config.rateLimits).toMatchObject({
        mediaUploadHourUser: { max: 20, windowSeconds: 3600 },
        mediaUploadDayUser: { max: 60, windowSeconds: 86400 },
        mediaCompleteUser: { max: 30, windowSeconds: 3600 },
        liveCoverUser: { max: 20, windowSeconds: 3600 },
        liveCountriesUser: { max: 300, windowSeconds: 900 },
      });
    });

    it('MEDIA_UPLOADS_ENABLED=true refuses to boot with an incomplete storage configuration', () => {
      expect(
        problems({ ...base, MEDIA_UPLOADS_ENABLED: 'true' })
          .map((p) => p.split(':')[0])
          .sort(),
      ).toEqual(
        [
          'MEDIA_PUBLIC_BASE_URL',
          'MEDIA_STORAGE_ACCESS_KEY_ID',
          'MEDIA_STORAGE_INCOMING_BUCKET',
          'MEDIA_STORAGE_PUBLIC_BUCKET',
          'MEDIA_STORAGE_REGION',
          'MEDIA_STORAGE_SECRET_ACCESS_KEY',
        ].sort(),
      );
      for (const missing of Object.keys(storage()).filter((k) => k !== 'MEDIA_STORAGE_ENDPOINT')) {
        const env: Record<string, string> = { ...base, ...storage(), MEDIA_UPLOADS_ENABLED: 'true' };
        delete env[missing];
        expect(problems(env).length, missing).toBeGreaterThan(0);
      }
      const config = loadConfig({ ...base, ...storage(), MEDIA_UPLOADS_ENABLED: 'true' });
      expect(config.media.uploadsEnabled).toBe(true);
      expect(config.media.storage).toMatchObject({
        region: 'auto',
        incomingBucket: 'kabso-incoming',
        forcePathStyle: false,
      });
      expect(config.media.publicBaseUrl).toBe('https://media.kabso-cdn.example');
    });

    it('never echoes the storage secret in a validation error', () => {
      const secret = randomBytes(30).toString('base64url');
      try {
        loadConfig({
          ...base,
          ...storage(),
          MEDIA_STORAGE_SECRET_ACCESS_KEY: secret,
          MEDIA_UPLOADS_ENABLED: 'yes',
        });
        throw new Error('expected a failure');
      } catch (err) {
        expect((err as Error).message).not.toContain(secret);
      }
    });

    it('validates buckets, URLs and switches', () => {
      expect(problems({ ...base, MEDIA_UPLOADS_ENABLED: 'TRUE' })).toHaveLength(1);
      expect(problems({ ...base, MEDIA_MODERATION_PROVIDER: 'aws' })).toHaveLength(1);
      expect(problems({ ...base, ...storage(), MEDIA_STORAGE_PUBLIC_BUCKET: 'kabso-incoming' })).toHaveLength(
        1,
      );
      expect(problems({ ...base, MEDIA_STORAGE_INCOMING_BUCKET: 'Bad_Bucket' })).toHaveLength(1);
      expect(problems({ ...base, MEDIA_PUBLIC_BASE_URL: 'https://cdn.example/x?y=1' })).toHaveLength(1);
      expect(problems({ ...base, MEDIA_PUBLIC_BASE_URL: 'https://user:pw@cdn.example' })).toHaveLength(1);
      expect(problems({ ...base, MEDIA_PUBLIC_BASE_URL: 'ftp://cdn.example' })).toHaveLength(1);
      expect(problems({ ...base, MEDIA_STORAGE_ACCESS_KEY_ID: 'only-the-id' })).toHaveLength(1);
      expect(
        loadConfig({ ...base, MEDIA_PUBLIC_BASE_URL: 'https://cdn.example/media/' }).media.publicBaseUrl,
      ).toBe('https://cdn.example/media');
      for (const [name, bad] of [
        ['MEDIA_UPLOAD_URL_TTL_SECONDS', '901'],
        ['MEDIA_UPLOAD_URL_TTL_SECONDS', '59'],
        ['MEDIA_MAX_PENDING_PER_USER', '21'],
        ['MEDIA_DAILY_BYTES_PER_USER', '1000'],
        ['MEDIA_PROCESS_MAX_CONCURRENCY', '0'],
        ['MEDIA_PROCESS_TIMEOUT_MS', '999'],
        ['MEDIA_UNATTACHED_TTL_HOURS', '169'],
        ['MEDIA_DELETE_GRACE_HOURS', '0'],
        ['MEDIA_ENDED_ROOM_COVER_TTL_HOURS', '169'],
        ['MEDIA_CLEANUP_INTERVAL_SECONDS', '30'],
        ['MEDIA_CLEANUP_BATCH_SIZE', '5001'],
      ] as const) {
        expect(problems({ ...base, [name]: bad }), `${name}=${bad}`).toHaveLength(1);
      }
      expect(loadConfig({ ...base, MEDIA_CLEANUP_INTERVAL_SECONDS: '0' }).media.cleanupIntervalSeconds).toBe(
        0,
      );
    });

    it('production: allow_all moderation is refused (it is dev/test only)', () => {
      expect(problems(prod({ MEDIA_MODERATION_PROVIDER: 'allow_all' }))).toEqual([
        expect.stringMatching(/^MEDIA_MODERATION_PROVIDER: .*refused in production/),
      ]);
      expect(problems({ ...base, MEDIA_MODERATION_PROVIDER: 'allow_all' })).toEqual([]);
    });

    it('production: https storage endpoint and media host, on a host other than the API', () => {
      expect(problems(prod({ ...storage(), MEDIA_UPLOADS_ENABLED: 'true' }))).toEqual([]);
      expect(problems(prod({ ...storage(), MEDIA_STORAGE_ENDPOINT: 'http://storage.example' }))).toHaveLength(
        1,
      );
      expect(
        problems(prod({ ...storage(), MEDIA_PUBLIC_BASE_URL: 'http://media.kabso-cdn.example' })),
      ).toHaveLength(1);
      expect(problems(prod({ ...storage(), MEDIA_PUBLIC_BASE_URL: 'https://kabso.example/media' }))).toEqual([
        expect.stringMatching(/^MEDIA_PUBLIC_BASE_URL: must be on a host other than the API host/),
      ]);
      expect(problems(prod({ MEDIA_CLEANUP_INTERVAL_SECONDS: '0' }))).toHaveLength(1);
    });
  });
});
