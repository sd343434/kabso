import { randomBytes } from 'node:crypto';
import { JwtService } from '@nestjs/jwt';
import { describe, expect, it } from 'vitest';
import { loadConfig } from '../../config/app-config.js';
import { AccessTokenService } from './access-token.service.js';

const config = loadConfig({
  DATABASE_URL: 'postgresql://u:p@localhost:5432/db',
  REDIS_URL: 'redis://localhost:6379',
  // Generated per run: never commit a secret-like literal (gitleaks).
  JWT_ACCESS_SECRET: randomBytes(48).toString('base64url'),
  APP_PUBLIC_URL: 'http://localhost:3000',
});
const jwt = new JwtService({});
const service = new AccessTokenService(jwt, config);
const claims = {
  userId: '0192f1c2-3b4a-7c5d-8e6f-0123456789ab',
  sessionId: '0192f1c2-3b4a-7c5d-8e6f-0123456789ac',
};

function decode(token: string): Record<string, unknown> {
  return JSON.parse(Buffer.from(token.split('.')[1]!, 'base64url').toString()) as Record<string, unknown>;
}

describe('AccessTokenService', () => {
  it('signs HS256 tokens with the contract claims and a 15-minute TTL', async () => {
    const now = new Date('2026-10-15T13:00:00.000Z');
    const { token, expiresAt } = await service.sign(claims, now);
    const header = JSON.parse(Buffer.from(token.split('.')[0]!, 'base64url').toString()) as Record<
      string,
      unknown
    >;
    expect(header.alg).toBe('HS256');
    expect(decode(token)).toEqual({
      sub: claims.userId,
      sid: claims.sessionId,
      typ: 'access',
      iat: now.getTime() / 1000,
      exp: now.getTime() / 1000 + 900,
      iss: 'kabso-api',
      aud: 'kabso-mobile',
    });
    expect(expiresAt.toISOString()).toBe('2026-10-15T13:15:00.000Z');
  });

  it('verifies its own tokens', async () => {
    const { token } = await service.sign(claims);
    expect(await service.verify(token)).toEqual(claims);
  });

  it('rejects expired, foreign-key, wrong-typ, wrong-aud and alg=none tokens', async () => {
    const expired = await service.sign(claims, new Date(Date.now() - 16 * 60 * 1000));
    expect(await service.verify(expired.token)).toBeNull();

    const base = { sid: claims.sessionId, typ: 'access' };
    const opts = { subject: claims.userId, issuer: 'kabso-api', audience: 'kabso-mobile', expiresIn: 60 };
    const foreign = await jwt.signAsync(base, { ...opts, secret: randomBytes(48).toString('base64url') });
    expect(await service.verify(foreign)).toBeNull();

    const refreshTyp = await jwt.signAsync(
      { ...base, typ: 'refresh' },
      { ...opts, secret: config.jwt.accessSecret },
    );
    expect(await service.verify(refreshTyp)).toBeNull();

    const wrongAud = await jwt.signAsync(base, {
      ...opts,
      audience: 'other',
      secret: config.jwt.accessSecret,
    });
    expect(await service.verify(wrongAud)).toBeNull();

    const none = `${Buffer.from('{"alg":"none","typ":"JWT"}').toString('base64url')}.${Buffer.from(
      JSON.stringify({
        ...base,
        sub: claims.userId,
        iss: 'kabso-api',
        aud: 'kabso-mobile',
        exp: 9_999_999_999,
      }),
    ).toString('base64url')}.`;
    expect(await service.verify(none)).toBeNull();
  });
});
