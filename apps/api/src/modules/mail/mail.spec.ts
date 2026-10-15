import { randomBytes } from 'node:crypto';
import { Logger } from '@nestjs/common';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { loadConfig, type AppConfig } from '../../config/app-config.js';
import { LogMailSender } from './log-mail-sender.js';
import { renderMail } from './mail-templates.js';

const base = {
  DATABASE_URL: 'postgresql://u:p@localhost:5432/db',
  REDIS_URL: 'redis://localhost:6379',
  JWT_ACCESS_SECRET: 'x'.repeat(32),
  APP_PUBLIC_URL: 'https://kabso.example',
};

describe('mail templates (ar + en)', () => {
  it('renders the registration code in both locales', () => {
    const ar = renderMail({ kind: 'registration_code', code: '01234567', minutes: 30 }, 'ar');
    const en = renderMail({ kind: 'registration_code', code: '01234567', minutes: 30 }, 'en');
    expect(ar.subject).toContain('01234567');
    expect(ar.text).toContain('01234567');
    expect(ar.text).toMatch(/[؀-ۿ]/);
    expect(en.subject).toBe('Your Kabso verification code: 01234567');
    expect(en.text).toContain('expires in 30 minutes');
  });

  it('renders the account-exists notice in both locales without any code', () => {
    const ar = renderMail({ kind: 'account_exists', appUrl: 'https://kabso.example' }, 'ar');
    const en = renderMail({ kind: 'account_exists', appUrl: 'https://kabso.example' }, 'en');
    expect(ar.subject).toMatch(/[؀-ۿ]/);
    expect(en.subject).toBe('You already have a Kabso account');
    expect(en.text).toContain('reset your password');
    expect(ar.text).toContain('https://kabso.example');
  });
});

describe('LogMailSender', () => {
  afterEach(() => vi.restoreAllMocks());

  function logged(config: AppConfig): string {
    const spy = vi.spyOn(Logger.prototype, 'log').mockImplementation(() => undefined);
    const sender = new LogMailSender(config);
    void sender.sendRegistrationCode({
      to: 'someone@example.com',
      locale: 'en',
      code: '98765432',
      expiresAt: new Date(Date.now() + 30 * 60_000),
    });
    return JSON.stringify(spy.mock.calls);
  }

  it('logs the code outside production (development aid)', () => {
    expect(logged(loadConfig(base))).toContain('98765432');
  });

  it('never logs the code in production (defence in depth; the transport is refused there)', () => {
    // Build a production config object without going through validation (which refuses `log`).
    const prod = {
      ...loadConfig({
        ...base,
        JWT_ACCESS_SECRET: randomBytes(32).toString('hex'),
      }),
      env: 'production',
      isProduction: true,
    } as AppConfig;
    const out = logged(prod);
    expect(out).not.toContain('98765432');
    expect(out).toContain('[REDACTED]');
    expect(out).not.toContain('someone@example.com');
  });
});
