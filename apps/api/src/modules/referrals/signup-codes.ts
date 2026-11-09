import { createHmac, hkdfSync } from 'node:crypto';
import { z } from 'zod';
import { AuditAction } from '../../common/audit/audit.service.js';
import type { Prisma, PrismaClient } from '../../generated/prisma/client.js';
import { findRecruiter } from '../recruits/recruit-core.js';
import { formatStaffId, parseStaffId } from '../users/staff-ids.js';
import { canonicalEmail, normalizeReferralCode } from './referral-rules.js';

/**
 * v1.108-social (D343, CONVENTIONS §10.142; owner: «في انشاء الحساب هناك صندوق يدخل شخص اما رمز الدعوة او رمز المشرف
 * الذي استقطبه … النظام يعرف ان كان الشخص قام بتحميل التطبيق قبل المرة يلا يعتبره مستخدم جديد ولا حالة استقطاب»).
 *
 * One optional sign-up field «رمز الدعوة أو رمز المشرف» takes either
 *  - **INVITE**: a friend's invite code (D217, 8 characters of `CODE_ALPHABET`, an ACTIVE account's), or
 *  - **SUPERVISOR**: a supervisor's staff ID («Kabso07», D283c — an ACTIVE MODERATION or BD staff member, D285),
 * typed, pasted or carried by the invite link `…/i/<code>`. The two never collide: an invite code has no `O`, every
 * staff ID starts with «Kabso».
 *
 * Credit only for a new person: the invite reward or the recruit is withheld (the account is created all the same)
 * when the device already had a Kabso account (`DEVICE_HAD_ACCOUNT`: another account was created on it or signed in on
 * it — `device_signups` and `sessions` keep the server's HMAC of the app's stable device id, D223 / D250) or the
 * mailbox was registered before (`EMAIL_HAD_ACCOUNT`: `signup_email_marks`, a keyed hash of the canonical mailbox,
 * kept SIGNUP_IDENTITY_RETENTION_DAYS after a purge). No IP or user-agent matching (owner: privacy).
 */

type Tx = Prisma.TransactionClient;
type Db = Tx | PrismaClient;
const DAY_MS = 86_400_000;

export type SignupCodeKind = 'INVITE' | 'SUPERVISOR';

export type SignupCode =
  | { readonly kind: 'INVITE'; readonly code: string }
  | { readonly kind: 'SUPERVISOR'; readonly code: string; readonly number: number };

/**
 * A typed code as stored: a staff ID in its display form («Kabso07»; any case, `@` optional), else an invite code in
 * upper case without spaces or dashes; a link's last `/i/<code>` part is read. Null when it can be neither (the format
 * only; whether it exists is the database's answer).
 */
export function parseSignupCode(raw: string): SignupCode | null {
  let v = raw.trim();
  const link = /\/i\/([A-Za-z0-9@ -]+)\/?(?:[?#].*)?$/.exec(v);
  if (link) v = link[1]!;
  const compact = v.replace(/[\s-]+/gu, '');
  const staff = parseStaffId(compact);
  if (staff !== null) return { kind: 'SUPERVISOR', code: formatStaffId(staff), number: staff };
  const invite = normalizeReferralCode(compact);
  return invite === null ? null : { kind: 'INVITE', code: invite };
}

/** The request field (`RegisterRequest.referralCode`, `CheckSignupCodeRequest.code`): at most 200 characters. */
export const signupCodeInput = z
  .string()
  .max(200)
  .transform((raw, ctx) => {
    const code = parseSignupCode(raw);
    if (code === null) {
      ctx.addIssue({
        code: 'custom',
        message: 'referralCode invalid_format',
        params: { issue: 'invalid_format' },
      });
      return z.NEVER;
    }
    return code.code;
  });

export interface ResolvedSignupCode {
  readonly kind: SignupCodeKind;
  /** The stored form (an invite code, or a staff ID «Kabso07»). */
  readonly code: string;
  /** The inviter or the supervisor. */
  readonly ownerUserId: string;
}

/**
 * Who a code belongs to now: the ACTIVE owner of an invite code, or a supervisor who can recruit now (MODERATION or
 * BD, ACTIVE). Null otherwise — unknown, a closed account, a staff ID of SUPPORT / FINANCE / the OWNER or of someone
 * who left the team: never told apart («الرمز غير صحيح»).
 */
export async function resolveSignupCodeIn(db: Db, stored: string): Promise<ResolvedSignupCode | null> {
  const parsed = parseSignupCode(stored);
  if (parsed === null) return null;
  if (parsed.kind === 'SUPERVISOR') {
    const found = await findRecruiter(db, parsed.code);
    return found ? { kind: 'SUPERVISOR', code: parsed.code, ownerUserId: found.userId } : null;
  }
  const [row] = await db.$queryRaw<{ user_id: string }[]>`
    SELECT c.user_id::text AS user_id FROM referral_codes c JOIN users u ON u.id = c.user_id
     WHERE c.code = ${parsed.code} AND u.status = 'ACTIVE'::user_status`;
  return row ? { kind: 'INVITE', code: parsed.code, ownerUserId: row.user_id } : null;
}

// ---- «ليس شخصاً جديداً»: the device and the mailbox ------------------------------------------------------------------

/** The HMAC key of the mailbox marks: HKDF(SIGNUP_DEVICE_KEY when set, else RATE_LIMIT_KEY_SECRET; `signup-email/v1`). */
export function emailMarkKey(source: string): Buffer {
  return Buffer.from(hkdfSync('sha256', source, 'kabso', 'signup-email/v1', 32));
}

/** What the database keeps of a mailbox: HMAC-SHA-256 of its canonical form (`canonicalEmail`), 64 hex. */
export function emailMarkOf(key: Buffer, email: string): string {
  return createHmac('sha256', key).update(canonicalEmail(email)).digest('hex');
}

/** Records the mailbox an account was created with (once per account). */
export async function recordEmailMarkIn(tx: Tx, userId: string, emailHash: string, now: Date): Promise<void> {
  await tx.$executeRaw`
    INSERT INTO signup_email_marks (user_id, email_hash, created_at)
    VALUES (${userId}::uuid, ${emailHash}, ${now}) ON CONFLICT (user_id) DO NOTHING`;
}

/**
 * The OTHER accounts the new account's device knew: created on it (`device_signups`, deleted accounts' tombstones
 * included) or signed in on it (any session, signed out ones too). Empty when the account has no device (an older
 * app, the website) — the check cannot run then (KNOWN_LIMITATIONS).
 */
export async function otherAccountsOnDeviceIn(db: Db, userId: string): Promise<string[]> {
  const rows = await db.$queryRaw<{ id: string }[]>`
    WITH me AS (SELECT device_hash FROM device_signups WHERE user_id = ${userId}::uuid)
    SELECT DISTINCT x.id FROM (
      SELECT d.user_id::text AS id FROM device_signups d, me WHERE d.device_hash = me.device_hash
      UNION ALL
      SELECT s.user_id::text AS id FROM sessions s, me WHERE s.device_hash = me.device_hash
    ) x
     WHERE x.id <> ${userId}
     LIMIT 50`;
  return rows.map((r) => r.id);
}

/** True when another account (live, or purged within the retention) was created with the same mailbox. */
export async function emailHadAccountIn(
  db: Db,
  userId: string,
  emailHash: string | null,
  now: Date,
  retentionDays: number,
): Promise<boolean> {
  if (emailHash === null) return false;
  const cutoff = new Date(now.getTime() - retentionDays * DAY_MS);
  const [row] = await db.$queryRaw<{ n: number }[]>`
    SELECT count(*)::int AS n FROM signup_email_marks
     WHERE email_hash = ${emailHash} AND user_id <> ${userId}::uuid
       AND (purged_at IS NULL OR purged_at > ${cutoff})`;
  return (row?.n ?? 0) > 0;
}

export type SupervisorWithholdReason = 'DEVICE_HAD_ACCOUNT' | 'EMAIL_HAD_ACCOUNT' | 'RECRUITER_INACTIVE';

export interface SupervisorSignupInput {
  readonly userId: string;
  /** The stored staff ID («Kabso07»). */
  readonly code: string;
  readonly emailHash: string | null;
  readonly now: Date;
  readonly retentionDays: number;
  readonly ip?: string | null;
  readonly requestId?: string | null;
}

export type SupervisorSignupResult =
  | { readonly kind: 'GRANTED'; readonly recruiterUserId: string }
  | { readonly kind: 'WITHHELD'; readonly recruiterUserId: string; readonly reason: SupervisorWithholdReason }
  | { readonly kind: 'UNKNOWN' | 'ALREADY' };

/**
 * The supervisor's staff ID typed at sign-up, once the account exists (its own transaction, after the account's): one
 * `staff_signup_recruits` row — GRANTED, or WITHHELD with the reason (the supervisor left the team between register and
 * verify; the device or the mailbox had an account). Audited `staff.recruit.signup`. Nothing when the staff ID belongs
 * to nobody any more (`UNKNOWN`, audited) or the account already has a row or a referral (`ALREADY`).
 */
export async function attachSupervisorSignupIn(
  tx: Tx,
  input: SupervisorSignupInput,
): Promise<SupervisorSignupResult> {
  const parsed = parseSignupCode(input.code);
  if (parsed?.kind !== 'SUPERVISOR') return { kind: 'UNKNOWN' };
  const holder = await tx.staffId.findUnique({ where: { number: parsed.number }, select: { userId: true } });
  if (!holder?.userId || holder.userId === input.userId) {
    await tx.auditLog.create({
      data: {
        actorUserId: input.userId,
        action: AuditAction.STAFF_RECRUIT_SIGNUP,
        targetType: 'user',
        targetId: input.userId,
        ip: input.ip?.slice(0, 64) ?? null,
        requestId: input.requestId ?? null,
        metadata: { code: parsed.code, status: 'UNKNOWN' },
      },
    });
    return { kind: 'UNKNOWN' };
  }
  const recruiterUserId = holder.userId;
  const already =
    (await tx.staffSignupRecruit.count({ where: { userId: input.userId } })) +
    (await tx.referral.count({ where: { inviteeUserId: input.userId } }));
  if (already > 0) return { kind: 'ALREADY' };
  let reason: SupervisorWithholdReason | null = null;
  if ((await findRecruiter(tx, parsed.code)) === null) reason = 'RECRUITER_INACTIVE';
  if (reason === null && (await otherAccountsOnDeviceIn(tx, input.userId)).length > 0)
    reason = 'DEVICE_HAD_ACCOUNT';
  if (
    reason === null &&
    (await emailHadAccountIn(tx, input.userId, input.emailHash, input.now, input.retentionDays))
  )
    reason = 'EMAIL_HAD_ACCOUNT';
  await tx.staffSignupRecruit.create({
    data: {
      userId: input.userId,
      recruiterUserId,
      code: parsed.code,
      status: reason === null ? 'GRANTED' : 'WITHHELD',
      withholdReason: reason,
      createdAt: input.now,
    },
  });
  await tx.auditLog.create({
    data: {
      actorUserId: input.userId,
      action: AuditAction.STAFF_RECRUIT_SIGNUP,
      targetType: 'user',
      targetId: input.userId,
      ip: input.ip?.slice(0, 64) ?? null,
      requestId: input.requestId ?? null,
      metadata: {
        code: parsed.code,
        recruiter: recruiterUserId,
        status: reason === null ? 'GRANTED' : 'WITHHELD',
        reason,
      },
    },
  });
  return reason === null
    ? { kind: 'GRANTED', recruiterUserId }
    : { kind: 'WITHHELD', recruiterUserId, reason };
}

// ---- Retention and the marks of the accounts made before D343 -------------------------------------------------------

export interface SignupMarkSweep {
  /** Marks written for accounts that existed before the migration. */
  readonly backfilled: number;
  /** Marks of purged accounts deleted after the retention. */
  readonly expired: number;
}

/**
 * The referral sweeper's extra step: deletes the marks of accounts purged more than `retentionDays` ago, and writes
 * the mark of up to `batch` accounts that have none yet (accounts made before the migration; the key is not in the
 * database, so the migration could not). A purged account without a mark gets none (its address is gone).
 */
export async function sweepSignupMarksIn(
  db: PrismaClient,
  key: Buffer,
  now: Date,
  retentionDays: number,
  batch = 500,
): Promise<SignupMarkSweep> {
  const cutoff = new Date(now.getTime() - retentionDays * DAY_MS);
  const expired = await db.$executeRaw`
    DELETE FROM signup_email_marks WHERE purged_at IS NOT NULL AND purged_at <= ${cutoff}`;
  const missing = await db.$queryRaw<{ id: string; email: string }[]>`
    SELECT u.id::text AS id, u.email FROM users u
     WHERE u.status <> 'DELETED'::user_status
       AND NOT EXISTS (SELECT 1 FROM signup_email_marks m WHERE m.user_id = u.id)
     ORDER BY u.created_at
     LIMIT ${batch}`;
  if (missing.length > 0) {
    await db.$executeRaw`
      INSERT INTO signup_email_marks (user_id, email_hash, created_at)
      SELECT x.id, x.hash, ${now} FROM unnest(
        ${missing.map((m) => m.id)}::uuid[], ${missing.map((m) => emailMarkOf(key, m.email))}::text[]
      ) AS x(id, hash)
      ON CONFLICT (user_id) DO NOTHING`;
  }
  return { backfilled: missing.length, expired };
}
