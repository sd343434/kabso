import { randomBytes } from 'node:crypto';

/**
 * A UUIDv7 (RFC 9562): 48-bit Unix milliseconds, version 7, 74 random bits. The same id format
 * Prisma's `@default(uuid(7))` produces; used where the id must be known before the insert (the
 * storage key of an upload contains it).
 */
export function uuidV7(nowMs: number = Date.now()): string {
  const bytes = randomBytes(16);
  bytes.writeUIntBE(Math.floor(nowMs) % 2 ** 48, 0, 6);
  bytes[6] = (bytes[6]! & 0x0f) | 0x70;
  bytes[8] = (bytes[8]! & 0x3f) | 0x80;
  const hex = bytes.toString('hex');
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20)}`;
}
