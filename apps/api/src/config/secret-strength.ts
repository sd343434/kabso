/**
 * Production strength rules for server-side keys (JWT_ACCESS_SECRET, RATE_LIMIT_KEY_SECRET).
 * SEC-005: a key must be what a generator produces (e.g. `openssl rand -base64 48`), not text a
 * human typed. Rules:
 *  1. only base64 / base64url characters (optional `=` padding), so it is decodable;
 *  2. decodes to at least 32 bytes (≥ 43 characters);
 *  3. sane entropy: Shannon estimate ≥ 3.3 bits/char (random hex ≈ 3.8+, random base64 ≈ 5+),
 *     at most 40 % of adjacent pairs repeating or stepping by one (`aaaa…`, `abcd…`, `0123…`);
 *  4. no placeholder words.
 */
export const MIN_SECRET_BYTES = 32;

const BASE64_ANY = /^[A-Za-z0-9+/_-]+={0,2}$/;
// Placeholder words delimited like typed text, so random generator output cannot match by chance.
const PLACEHOLDER =
  /(?:^|[-_.\s])(?:replace[-_ ]?me|change[-_ ]?me|changeit|placeholder|example|secret|dummy|test|password)(?:$|[-_.\s\d])/i;

export function decodedLength(value: string): number {
  return Buffer.from(value.replace(/=+$/, '').replace(/-/g, '+').replace(/_/g, '/'), 'base64').length;
}

export function shannonBitsPerChar(value: string): number {
  if (value.length === 0) return 0;
  const counts = new Map<string, number>();
  for (const ch of value) counts.set(ch, (counts.get(ch) ?? 0) + 1);
  let bits = 0;
  for (const count of counts.values()) {
    const p = count / value.length;
    bits -= p * Math.log2(p);
  }
  return bits;
}

/** Fraction of adjacent character pairs that repeat or step by ±1 (keyboard/sequence patterns). */
export function sequentialFraction(value: string): number {
  if (value.length < 2) return 1;
  let hits = 0;
  for (let i = 1; i < value.length; i += 1) {
    if (Math.abs(value.charCodeAt(i) - value.charCodeAt(i - 1)) <= 1) hits += 1;
  }
  return hits / (value.length - 1);
}

/** Returns a human-readable problem, or null when the value is acceptable as a production key. */
export function productionSecretProblem(value: string): string | null {
  const hint = 'generate it with `openssl rand -base64 48`';
  if (!BASE64_ANY.test(value)) return `must be base64/base64url encoded random bytes; ${hint}`;
  if (decodedLength(value) < MIN_SECRET_BYTES) {
    return `must decode to at least ${MIN_SECRET_BYTES} bytes (≥ 43 base64 characters); ${hint}`;
  }
  if (PLACEHOLDER.test(value)) return `looks like a placeholder; ${hint}`;
  if (shannonBitsPerChar(value) < 3.3 || sequentialFraction(value) > 0.4) {
    return `has too little entropy (repeated or sequential characters); ${hint}`;
  }
  return null;
}
