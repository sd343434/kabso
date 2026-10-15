import { createHash, randomBytes, timingSafeEqual } from 'node:crypto';

/** 32 random bytes, base64url (no padding) → 43 characters. */
const SECRET_BYTES = 32;
const SECRET_PATTERN = /^[A-Za-z0-9_-]{43}$/;
const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;

export function generateSecret(): string {
  return randomBytes(SECRET_BYTES).toString('base64url');
}

/** SHA-256 hex digest; the only form in which refresh/verification secrets are stored. */
export function sha256Hex(value: string): string {
  return createHash('sha256').update(value, 'utf8').digest('hex');
}

/** Constant-time comparison of two hex digests. */
export function hashesEqual(a: string, b: string): boolean {
  const left = Buffer.from(a, 'hex');
  const right = Buffer.from(b, 'hex');
  return left.length === right.length && left.length > 0 && timingSafeEqual(left, right);
}

export function isWellFormedSecret(secret: string): boolean {
  return SECRET_PATTERN.test(secret);
}

export function isUuid(value: string): boolean {
  return UUID_PATTERN.test(value.toLowerCase());
}

/** Refresh token wire format (CONVENTIONS §6): `<sessionId>.<secret>`. */
export function formatRefreshToken(sessionId: string, secret: string): string {
  return `${sessionId}.${secret}`;
}

export interface ParsedRefreshToken {
  readonly sessionId: string;
  readonly secret: string;
}

/** Returns null for anything that is not `<uuid>.<43-char base64url secret>`. */
export function parseRefreshToken(token: string): ParsedRefreshToken | null {
  const dot = token.indexOf('.');
  if (dot <= 0 || dot !== token.lastIndexOf('.')) return null;
  const sessionId = token.slice(0, dot).toLowerCase();
  const secret = token.slice(dot + 1);
  if (!isUuid(sessionId) || !isWellFormedSecret(secret)) return null;
  return { sessionId, secret };
}
