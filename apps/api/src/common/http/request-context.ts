import type { Request } from 'express';

/** Identity attached to the request by the access-token guard. */
export interface AuthContext {
  readonly userId: string;
  readonly sessionId: string;
}

export type AppRequest = Request & { auth?: AuthContext };

/** Client IP as resolved by Express (honours the configured `trust proxy`). */
export function clientIp(req: Request): string {
  return req.ip ?? req.socket.remoteAddress ?? 'unknown';
}

export function userAgent(req: Request): string | null {
  const ua = req.headers['user-agent'];
  return typeof ua === 'string' && ua.length > 0 ? ua.slice(0, 512) : null;
}
