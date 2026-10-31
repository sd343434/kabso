import { createHmac, randomBytes, timingSafeEqual } from 'node:crypto';

/**
 * TOTP (RFC 6238 over RFC 4226 HOTP): HMAC-SHA-1, 30-second steps, 6 digits — what every authenticator app
 * (Google Authenticator, Microsoft Authenticator, 1Password …) reads from an `otpauth://` QR code (v1.60-social,
 * D191, CONVENTIONS §10.54.2). No dependency: node:crypto only.
 */
export const TOTP_PERIOD_SECONDS = 30;
export const TOTP_DIGITS = 6;
/** Codes of the previous and next step are accepted too (clock drift). */
export const TOTP_WINDOW = 1;

const BASE32 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';

export function base32Encode(bytes: Uint8Array): string {
  let bits = 0;
  let value = 0;
  let out = '';
  for (const byte of bytes) {
    value = (value << 8) | byte;
    bits += 8;
    while (bits >= 5) {
      out += BASE32[(value >>> (bits - 5)) & 31];
      bits -= 5;
    }
  }
  if (bits > 0) out += BASE32[(value << (5 - bits)) & 31];
  return out;
}

export function base32Decode(text: string): Buffer {
  const clean = text.replace(/[\s=-]/g, '').toUpperCase();
  let bits = 0;
  let value = 0;
  const out: number[] = [];
  for (const ch of clean) {
    const i = BASE32.indexOf(ch);
    if (i < 0) throw new RangeError('not base32');
    value = (value << 5) | i;
    bits += 5;
    if (bits >= 8) {
      out.push((value >>> (bits - 8)) & 255);
      bits -= 8;
    }
  }
  return Buffer.from(out);
}

/** A new 160-bit secret (RFC 4226 recommends ≥ 128), base32. */
export function newTotpSecret(): string {
  return base32Encode(randomBytes(20));
}

export function totpStep(nowMs: number): number {
  return Math.floor(nowMs / 1000 / TOTP_PERIOD_SECONDS);
}

/** The HOTP value of `step` (zero-padded to 6 digits). */
export function hotp(secret: Buffer, step: number): string {
  const counter = Buffer.alloc(8);
  counter.writeBigUInt64BE(BigInt(step));
  const mac = createHmac('sha1', secret).update(counter).digest();
  const offset = mac[mac.length - 1]! & 0x0f;
  const binary = (mac.readUInt32BE(offset) & 0x7fffffff) % 10 ** TOTP_DIGITS;
  return String(binary).padStart(TOTP_DIGITS, '0');
}

export function totpCode(secretBase32: string, nowMs: number): string {
  return hotp(base32Decode(secretBase32), totpStep(nowMs));
}

/**
 * The step `code` matches within ±{@link TOTP_WINDOW} of now, or null. A step at or before `lastUsedStep` is
 * refused (a code works once: RFC 6238 §5.2).
 */
export function matchTotp(
  secretBase32: string,
  code: string,
  nowMs: number,
  lastUsedStep: number | null,
): number | null {
  if (!/^[0-9]{6}$/.test(code)) return null;
  const secret = base32Decode(secretBase32);
  const now = totpStep(nowMs);
  const given = Buffer.from(code);
  let found: number | null = null;
  for (let step = now - TOTP_WINDOW; step <= now + TOTP_WINDOW; step++) {
    // Every candidate is compared (constant work), the first match kept.
    if (timingSafeEqual(Buffer.from(hotp(secret, step)), given) && found === null) found = step;
  }
  if (found === null || (lastUsedStep !== null && found <= lastUsedStep)) return null;
  return found;
}

/** The `otpauth://` URI an authenticator app scans (issuer «Kabso Admin», the admin's email as the account). */
export function otpauthUri(secretBase32: string, account: string, issuer = 'Kabso Admin'): string {
  const label = `${encodeURIComponent(issuer)}:${encodeURIComponent(account)}`;
  const params = new URLSearchParams({
    secret: secretBase32,
    issuer,
    algorithm: 'SHA1',
    digits: String(TOTP_DIGITS),
    period: String(TOTP_PERIOD_SECONDS),
  });
  return `otpauth://totp/${label}?${params.toString()}`;
}
