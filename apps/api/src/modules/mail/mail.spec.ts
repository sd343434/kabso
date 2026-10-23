import { randomBytes } from 'node:crypto';
import { Logger } from '@nestjs/common';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { loadConfig, type AppConfig } from '../../config/app-config.js';
import { LogMailSender } from './log-mail-sender.js';
import { renderMail } from './mail-templates.js';
import { SmtpMailSender, smtpTransport } from './smtp-mail-sender.js';
import { createTransport } from 'nodemailer';

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

describe('SmtpMailSender (KL-042)', () => {
  const smtp = {
    host: 'smtp.kabso.example',
    port: 465,
    secure: true,
    user: 'no-reply@kabso.example',
    password: 'app-password',
    from: 'Kabso Live <no-reply@kabso.example>',
  };

  it('sends the rendered registration code from the configured sender', async () => {
    const sendMail = vi.fn().mockResolvedValue({});
    const sender = new SmtpMailSender({ sendMail }, smtp.from);
    await sender.sendRegistrationCode({
      to: 'someone@example.com',
      locale: 'ar',
      code: '98765432',
      expiresAt: new Date(Date.now() + 30 * 60_000),
    });
    expect(sendMail).toHaveBeenCalledTimes(1);
    const message = sendMail.mock.calls[0]?.[0] as Record<string, unknown>;
    expect(message).toMatchObject({
      from: smtp.from,
      to: 'someone@example.com',
      subject: 'رمز التحقق من كابسو: 98765432',
      headers: { 'Content-Language': 'ar', 'Auto-Submitted': 'auto-generated' },
    });
    expect(message.text).toContain('98765432');
    expect(message.text).toContain('30');
  });

  it('builds a UTF-8 message that nodemailer can encode (stream transport)', async () => {
    const transport = createTransport({ streamTransport: true, buffer: true, newline: 'unix' });
    const sendMail = vi.fn((mail: Parameters<typeof transport.sendMail>[0]) => transport.sendMail(mail));
    const sender = new SmtpMailSender({ sendMail }, smtp.from);
    await sender.sendPasswordReset({
      to: 'someone@example.com',
      locale: 'en',
      token: 't0k3n',
      link: 'https://kabso.example/reset-password?token=t0k3n',
      expiresAt: new Date(Date.now() + 60 * 60_000),
    });
    const info = (await sendMail.mock.results[0]?.value) as { message: Buffer; envelope: unknown };
    const raw = info.message.toString('utf8');
    expect(info.envelope).toEqual({ from: 'no-reply@kabso.example', to: ['someone@example.com'] });
    expect(raw).toContain('Subject: Reset your Kabso password');
    expect(raw).toContain('Content-Type: text/plain; charset=utf-8');
    // The body is quoted-printable (soft line breaks, `=` as =3D).
    const body = raw.replace(/=\n/g, '').replace(/=3D/g, '=');
    expect(body).toContain('https://kabso.example/reset-password?token=t0k3n');
  });

  it('propagates a delivery failure to the caller (who logs it without the message)', async () => {
    const sender = new SmtpMailSender({ sendMail: vi.fn().mockRejectedValue(new Error('550')) }, smtp.from);
    await expect(
      sender.sendAccountExistsNotice({ to: 'a@example.com', locale: 'en', appUrl: 'https://kabso.example' }),
    ).rejects.toThrow('550');
  });

  it('always uses TLS: implicit on 465, required STARTTLS otherwise', () => {
    const implicit = smtpTransport(smtp).options as Record<string, unknown>;
    expect(implicit).toMatchObject({ secure: true, requireTLS: false, logger: false, debug: false });
    const starttls = smtpTransport({ ...smtp, port: 587, secure: false }).options as Record<string, unknown>;
    expect(starttls).toMatchObject({ secure: false, requireTLS: true });
  });
});
