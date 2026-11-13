import { createHmac, hkdfSync } from 'node:crypto';
import { z } from 'zod';
import type { Prisma } from '../../generated/prisma/client.js';

type Tx = Prisma.TransactionClient;

/**
 * v1.78-social (D223, CONVENTIONS §10.75; owner 2026-11-01: «الجهاز الواحد لا يمكنه عمل غير حسابين لكنه يمكن فتح
 * حسابات مختلفة»): one device may CREATE at most SIGNUP_MAX_ACCOUNTS_PER_DEVICE accounts; signing in to any number of
 * existing accounts is never limited.
 *
 * The device is `DeviceInfo.deviceKey`: the app's salted SHA-256 of Android's `ANDROID_ID` or the iOS Keychain id (the
 * raw id never leaves the phone). The server keeps only HMAC-SHA-256(key, deviceKey) under a key derived (HKDF, info
 * `signup-device/v1`) from SIGNUP_DEVICE_KEY when set, else RATE_LIMIT_KEY_SECRET — so a database leak alone cannot be
 * matched against device ids. A sign-up without a device key (the website, an app older than D223) is not counted.
 */

/** 64 lower-case hex characters (a SHA-256). */
export const deviceKeySchema = z.string().regex(/^[0-9a-f]{64}$/);

export function deviceHmacKey(source: string): Buffer {
  return Buffer.from(hkdfSync('sha256', source, 'kabso', 'signup-device/v1', 32));
}

/** What the database keeps of a device key (null when the app sent none). */
export function deviceHashOf(key: Buffer, deviceKey: string | undefined | null): string | null {
  if (!deviceKey) return null;
  return createHmac('sha256', key).update(deviceKey).digest('hex');
}

export interface DeviceAllowance {
  /** Accounts created on the device so far (every status: deleted and pending deletion included). */
  readonly count: number;
  /** The limit for this device: its OWNER exception, else the server's default. */
  readonly max: number;
  readonly exception: {
    maxAccounts: number;
    reason: string;
    grantedById: string | null;
    createdAt: Date;
  } | null;
}

export async function deviceAllowanceIn(
  tx: Tx,
  deviceHash: string,
  defaultMax: number,
): Promise<DeviceAllowance> {
  const [count, exception] = await Promise.all([
    tx.deviceSignup.count({ where: { deviceHash } }),
    tx.deviceSignupException.findUnique({
      where: { deviceHash },
      select: { maxAccounts: true, reason: true, grantedById: true, createdAt: true },
    }),
  ]);
  return { count, max: exception?.maxAccounts ?? defaultMax, exception };
}

/**
 * Serialises the sign-ups of one device for the rest of the transaction (two verifies at once on the same phone cannot
 * both take its last place).
 */
export async function lockDeviceIn(tx: Tx, deviceHash: string): Promise<void> {
  await tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtext('kabso:signup-device'), hashtext(${deviceHash}::text))`;
}

/** Records the device an account was created on (once per account). */
export async function recordDeviceSignupIn(
  tx: Tx,
  userId: string,
  deviceHash: string,
  platform: string | null,
  now: Date,
): Promise<void> {
  await tx.deviceSignup.create({ data: { userId, deviceHash, platform, createdAt: now } });
}
