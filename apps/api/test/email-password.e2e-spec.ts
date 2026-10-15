import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { createTestApp, newUser, type TestContext } from './helpers/test-app.js';

let ctx: TestContext;

beforeAll(async () => {
  ctx = await createTestApp();
});

afterAll(async () => {
  await ctx?.close();
});

async function register() {
  const payload = newUser();
  const res = await ctx.http.post('/api/v1/auth/register').send(payload);
  expect(res.status).toBe(201);
  return {
    payload,
    userId: res.body.user.id as string,
    accessToken: res.body.tokens.accessToken as string,
    refreshToken: res.body.tokens.refreshToken as string,
  };
}

const bearer = (token: string) => ({ Authorization: `Bearer ${token}` });

describe('POST /auth/email/verify', () => {
  it('verifies once; a second use returns 410 TOKEN_EXPIRED', async () => {
    const { payload, accessToken } = await register();
    const mail = ctx.mail.last(payload.email, 'verify');
    expect(mail).toBeDefined();

    const ok = await ctx.http.post('/api/v1/auth/email/verify').send({ token: mail!.token });
    expect(ok.status).toBe(204);
    const me = await ctx.http.get('/api/v1/me').set(bearer(accessToken));
    expect(me.body.emailVerified).toBe(true);

    const again = await ctx.http.post('/api/v1/auth/email/verify').send({ token: mail!.token });
    expect(again.status).toBe(410);
    expect(again.body.error.code).toBe('TOKEN_EXPIRED');
  });

  it('returns 410 for an expired token', async () => {
    const { payload, userId } = await register();
    const mail = ctx.mail.last(payload.email, 'verify');
    await ctx.prisma.verificationToken.updateMany({
      where: { userId, purpose: 'EMAIL_VERIFY' },
      data: { expiresAt: new Date(Date.now() - 1000) },
    });
    const res = await ctx.http.post('/api/v1/auth/email/verify').send({ token: mail!.token });
    expect(res.status).toBe(410);
    expect(res.body.error.code).toBe('TOKEN_EXPIRED');
  });

  it('returns 422 TOKEN_INVALID for garbage or unknown tokens', async () => {
    const garbage = await ctx.http.post('/api/v1/auth/email/verify').send({ token: 'this-is-not-a-token!' });
    expect(garbage.status).toBe(422);
    expect(garbage.body.error.code).toBe('TOKEN_INVALID');

    const unknown = await ctx.http.post('/api/v1/auth/email/verify').send({ token: 'A'.repeat(43) });
    expect(unknown.status).toBe(422);
    expect(unknown.body.error.code).toBe('TOKEN_INVALID');
  });

  it('does not accept a password-reset token for email verification', async () => {
    const { payload } = await register();
    await ctx.http.post('/api/v1/auth/password/forgot').send({ email: payload.email });
    const reset = await ctx.mail.waitFor(payload.email, 'reset');
    const res = await ctx.http.post('/api/v1/auth/email/verify').send({ token: reset.token });
    expect(res.status).toBe(422);
  });
});

describe('POST /auth/email/resend', () => {
  it('issues a new token and invalidates the previous one', async () => {
    const { payload, accessToken } = await register();
    const first = ctx.mail.last(payload.email, 'verify');
    const res = await ctx.http.post('/api/v1/auth/email/resend').set(bearer(accessToken));
    expect(res.status).toBe(202);
    const second = ctx.mail.last(payload.email, 'verify');
    expect(second?.token).not.toBe(first?.token);

    const old = await ctx.http.post('/api/v1/auth/email/verify').send({ token: first!.token });
    expect(old.status).toBe(410);
    const fresh = await ctx.http.post('/api/v1/auth/email/verify').send({ token: second!.token });
    expect(fresh.status).toBe(204);
  });

  it('requires authentication', async () => {
    const res = await ctx.http.post('/api/v1/auth/email/resend');
    expect(res.status).toBe(401);
  });
});

describe('password reset', () => {
  it('forgot always returns 202, also for unknown emails (no mail sent)', async () => {
    const before = ctx.mail.sent.length;
    const res = await ctx.http
      .post('/api/v1/auth/password/forgot')
      .send({ email: 'nobody-here@example.com' });
    expect(res.status).toBe(202);
    expect(res.text).toBe('');
    await new Promise((r) => setTimeout(r, 200));
    expect(ctx.mail.sent.length).toBe(before);
  });

  it('forgot validates the email format', async () => {
    const res = await ctx.http.post('/api/v1/auth/password/forgot').send({ email: 'nope' });
    expect(res.status).toBe(400);
    expect(res.body.error.details).toEqual([{ field: 'email', issue: 'invalid_email' }]);
  });

  it('reset changes the password, revokes every session and is single-use', async () => {
    const { payload, accessToken, refreshToken } = await register();
    const other = await ctx.http
      .post('/api/v1/auth/login')
      .send({ identifier: payload.email, password: payload.password });
    expect(other.status).toBe(200);

    const forgot = await ctx.http
      .post('/api/v1/auth/password/forgot')
      .send({ email: payload.email.toUpperCase() });
    expect(forgot.status).toBe(202);
    const mail = await ctx.mail.waitFor(payload.email, 'reset');
    expect(mail.link).toContain('/reset-password?token=');

    const newPassword = 'a brand new passphrase';
    const reset = await ctx.http.post('/api/v1/auth/password/reset').send({ token: mail.token, newPassword });
    expect(reset.status).toBe(204);

    for (const token of [accessToken, other.body.tokens.accessToken as string]) {
      const me = await ctx.http.get('/api/v1/me').set(bearer(token));
      expect(me.status).toBe(401);
    }
    const refresh = await ctx.http.post('/api/v1/auth/refresh').send({ refreshToken });
    expect(refresh.status).toBe(401);

    const oldLogin = await ctx.http
      .post('/api/v1/auth/login')
      .send({ identifier: payload.email, password: payload.password });
    expect(oldLogin.status).toBe(401);
    expect(oldLogin.body.error.code).toBe('AUTH_INVALID_CREDENTIALS');
    const newLogin = await ctx.http
      .post('/api/v1/auth/login')
      .send({ identifier: payload.email, password: newPassword });
    expect(newLogin.status).toBe(200);

    const reuse = await ctx.http
      .post('/api/v1/auth/password/reset')
      .send({ token: mail.token, newPassword: 'yet another passphrase' });
    expect(reuse.status).toBe(410);
    expect(reuse.body.error.code).toBe('TOKEN_EXPIRED');

    const sessions = await ctx.prisma.session.findMany({ where: { revokedReason: 'PASSWORD_RESET' } });
    expect(sessions.length).toBeGreaterThanOrEqual(2);
  });

  it('reset validates the new password and the token', async () => {
    const weak = await ctx.http
      .post('/api/v1/auth/password/reset')
      .send({ token: 'A'.repeat(43), newPassword: 'short' });
    expect(weak.status).toBe(400);
    expect(weak.body.error.details).toEqual([{ field: 'newPassword', issue: 'too_short' }]);

    const unknown = await ctx.http
      .post('/api/v1/auth/password/reset')
      .send({ token: 'A'.repeat(43), newPassword: 'long enough password' });
    expect(unknown.status).toBe(422);
    expect(unknown.body.error.code).toBe('TOKEN_INVALID');
  });
});
