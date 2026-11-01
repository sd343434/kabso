import { createCipheriv, createDecipheriv, createHash, hkdfSync, randomBytes } from 'node:crypto';
import { inspect } from 'node:util';

/**
 * Secrets of the admin panel (v1.60-social, D191, §10.54.2). The authenticator secret is AES-256-GCM encrypted with a
 * key derived (HKDF-SHA-256, info `admin-totp/v1`) from ADMIN_TOTP_KEY; the stored form is
 * `v1.<iv>.<tag>.<ciphertext>` (base64url). Cookies, CSRF tokens and recovery codes are random and only their
 * SHA-256 is stored.
 *
 * v1.64-social (D196, §10.53.1): the same box with another HKDF info string (`payment-settings/v1`) seals the Stripe
 * keys the OWNER enters in the panel — a separate key from the same source. `aad` binds a value to its column (a value
 * moved to another column does not open).
 *
 * v1.75-social (D222, §10.72): again with `storage-settings/v1` for the OWNER's object-storage keys «التخزين (R2 / S3)».
 */
export class AdminSecretBox {
  private readonly key: Buffer;

  constructor(source: string, info = 'admin-totp/v1') {
    this.key = Buffer.from(hkdfSync('sha256', Buffer.from(source, 'utf8'), Buffer.alloc(0), info, 32));
  }

  seal(plain: string, aad?: string): string {
    const iv = randomBytes(12);
    const cipher = createCipheriv('aes-256-gcm', this.key, iv);
    if (aad !== undefined) cipher.setAAD(Buffer.from(aad, 'utf8'));
    const data = Buffer.concat([cipher.update(plain, 'utf8'), cipher.final()]);
    return ['v1', iv, cipher.getAuthTag(), data]
      .map((p) => (typeof p === 'string' ? p : p.toString('base64url')))
      .join('.');
  }

  /** Null when the value was sealed with another key (or tampered with). */
  open(sealed: string, aad?: string): string | null {
    const [version, iv, tag, data] = sealed.split('.');
    if (version !== 'v1' || !iv || !tag || data === undefined) return null;
    try {
      const decipher = createDecipheriv('aes-256-gcm', this.key, Buffer.from(iv, 'base64url'));
      decipher.setAuthTag(Buffer.from(tag, 'base64url'));
      if (aad !== undefined) decipher.setAAD(Buffer.from(aad, 'utf8'));
      return Buffer.concat([decipher.update(Buffer.from(data, 'base64url')), decipher.final()]).toString(
        'utf8',
      );
    } catch {
      return null;
    }
  }
}

/**
 * A secret value that never leaves by accident (D196; D222): JSON, string conversion and `util.inspect` (what loggers use) all
 * give `[redacted]`. Only {@link Secret.reveal} returns the value, where a Stripe call needs it.
 */
export class Secret {
  readonly #value: string;
  constructor(value: string) {
    this.#value = value;
  }
  reveal(): string {
    return this.#value;
  }
  toJSON(): string {
    return '[redacted]';
  }
  toString(): string {
    return '[redacted]';
  }
  [inspect.custom](): string {
    return '[redacted]';
  }
}

export function sha256Hex(value: string): string {
  return createHash('sha256').update(value, 'utf8').digest('hex');
}

/** A 256-bit random token (cookie, CSRF), base64url. */
export function randomToken(): string {
  return randomBytes(32).toString('base64url');
}

/** Recovery codes: 10 × `xxxxx-xxxxx` (lower-case base32 without look-alikes, 50 bits each). */
const RECOVERY_ALPHABET = 'abcdefghjkmnpqrstuvwxyz23456789';
export const RECOVERY_CODE_COUNT = 10;

export function newRecoveryCode(): string {
  const bytes = randomBytes(10);
  let out = '';
  for (let i = 0; i < 10; i++) {
    out += RECOVERY_ALPHABET[bytes[i]! % RECOVERY_ALPHABET.length];
    if (i === 4) out += '-';
  }
  return out;
}

/** The stored form of a recovery code: spaces and dashes ignored, case-insensitive. */
export function recoveryCodeHash(code: string): string {
  return sha256Hex(`admin-recovery/v1:${code.replace(/[\s-]/g, '').toLowerCase()}`);
}
