import { Inject, Injectable } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import { isUuid } from './tokens.js';

export interface AccessClaims {
  readonly userId: string;
  readonly sessionId: string;
}

export interface SignedAccessToken {
  readonly token: string;
  readonly expiresAt: Date;
}

interface AccessPayload {
  sub?: unknown;
  sid?: unknown;
  typ?: unknown;
}

/** HS256 access JWTs with the claims fixed by CONVENTIONS §6. */
@Injectable()
export class AccessTokenService {
  constructor(
    private readonly jwt: JwtService,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
  ) {}

  async sign(claims: AccessClaims, now: Date = new Date()): Promise<SignedAccessToken> {
    const iat = Math.floor(now.getTime() / 1000);
    const exp = iat + this.config.jwt.accessTtlSeconds;
    const token = await this.jwt.signAsync(
      { sid: claims.sessionId, typ: 'access', iat, exp },
      {
        algorithm: 'HS256',
        secret: this.config.jwt.accessSecret,
        subject: claims.userId,
        issuer: this.config.jwt.issuer,
        audience: this.config.jwt.audience,
      },
    );
    return { token, expiresAt: new Date(exp * 1000) };
  }

  /** Returns the claims of a valid access token, or null (bad signature/alg/iss/aud/typ/exp). */
  async verify(token: string): Promise<AccessClaims | null> {
    let payload: AccessPayload;
    try {
      payload = await this.jwt.verifyAsync<AccessPayload & object>(token, {
        algorithms: ['HS256'],
        secret: this.config.jwt.accessSecret,
        issuer: this.config.jwt.issuer,
        audience: this.config.jwt.audience,
      });
    } catch {
      return null;
    }
    const { sub, sid, typ } = payload;
    if (typ !== 'access' || typeof sub !== 'string' || typeof sid !== 'string') return null;
    if (!isUuid(sub) || !isUuid(sid)) return null;
    return { userId: sub, sessionId: sid };
  }
}
