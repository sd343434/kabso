import { randomBytes } from 'node:crypto';
import { Logger } from '@nestjs/common';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { sendError } from '../common/errors/all-exceptions.filter.js';
import { redactText, safeErrorLog } from './redact-text.js';

const secret = () => randomBytes(32).toString('base64url');

describe('redactText (SEC-017)', () => {
  it('masks credentials, tokens, hashes and emails embedded in free text', () => {
    const refresh = `0192f1c2-3b4a-7c5d-8e6f-0123456789ab.${secret()}`;
    const jwt = `eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJ4In0.${secret()}`;
    const argon = '$argon2id$v=19$m=19456,t=2,p=1$c2FsdHNhbHQ$aGFzaGhhc2hoYXNo';
    const sha = 'ab'.repeat(32);
    const text = [
      `Invalid prisma.user.create() invocation: { email: "victim@example.com", passwordHash: "${argon}" }`,
      `password: 'hunter2hunter2' token=${secret()}`,
      `Authorization: Bearer ${jwt}`,
      `refreshToken ${refresh} hash ${sha}`,
    ].join('\n');
    const out = redactText(text);
    for (const leaked of ['victim@example.com', argon, 'hunter2hunter2', jwt, refresh, sha]) {
      expect(out).not.toContain(leaked);
    }
    expect(out).toContain('Invalid prisma.user.create() invocation');
    expect(out).toContain('[REDACTED]');
  });

  it('v1.4: masks the signature and credential of a presigned storage URL', () => {
    const signature = 'a1'.repeat(32);
    const keyId = `test${randomBytes(8).toString('hex')}`;
    const credential = `${keyId}%2F20261016%2Fauto%2Fs3%2Faws4_request`;
    const url =
      'https://bucket.example.invalid/in/x/y?X-Amz-Algorithm=AWS4-HMAC-SHA256' +
      `&X-Amz-Credential=${credential}&X-Amz-Date=20261016T000000Z&X-Amz-Expires=600` +
      `&X-Amz-Signature=${signature}&X-Amz-SignedHeaders=content-length%3Bcontent-type%3Bhost`;
    const out = redactText(`PUT failed for ${url}`);
    expect(out).not.toContain(signature);
    expect(out).not.toContain(keyId);
    expect(out).toContain('X-Amz-Signature=[REDACTED]');
    expect(out).toContain('X-Amz-Credential=[REDACTED]');
  });

  it('keeps ordinary text intact', () => {
    expect(redactText('Unique constraint failed on the fields: (`email`)')).toBe(
      'Unique constraint failed on the fields: (`email`)',
    );
  });

  it('safeErrorLog keeps only name, message and stack', () => {
    const err = Object.assign(new Error('failed for someone@example.com'), {
      meta: { target: 'x', password: 'hunter2hunter2' },
      clientVersion: '7.10.0',
    });
    const logged = safeErrorLog(err);
    expect(Object.keys(logged).sort()).toEqual(['message', 'name', 'stack']);
    expect(logged.message).toBe('failed for [REDACTED]');
    expect(JSON.stringify(logged)).not.toContain('hunter2hunter2');
    expect(safeErrorLog('plain string')).toEqual({ name: 'string', message: 'plain string' });
  });
});

describe('exception filter logging (SEC-017)', () => {
  afterEach(() => vi.restoreAllMocks());

  it('logs a redacted name/message/stack instead of the raw error object', () => {
    const spy = vi.spyOn(Logger.prototype, 'error').mockImplementation(() => undefined);
    const err = Object.assign(new Error('boom: passwordHash: "$argon2id$v=19$m=1$abc$def" for a@b.co'), {
      meta: { secret: 'raw-meta-value' },
    });
    const res = {
      headersSent: false,
      setHeader: vi.fn(),
      status: vi.fn().mockReturnThis(),
      json: vi.fn(),
    };
    const req = { method: 'POST', path: '/api/v1/auth/login', id: 'rid-1' };
    sendError(err, req as never, res as never);

    expect(res.status).toHaveBeenCalledWith(500);
    expect(spy).toHaveBeenCalledTimes(1);
    const [payload] = spy.mock.calls[0] as [Record<string, unknown>];
    const dump = JSON.stringify(payload);
    expect(dump).not.toContain('raw-meta-value');
    expect(dump).not.toContain('$argon2id$');
    expect(dump).not.toContain('a@b.co');
    expect(payload).not.toHaveProperty('err');
    expect(Object.keys(payload.error as object).sort()).toEqual(['message', 'name', 'stack']);
  });
});
