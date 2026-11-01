import { randomInt } from 'node:crypto';
import { z } from 'zod';

/**
 * «دعوة الأصدقاء» (v1.74-social, D217, CONVENTIONS §10.71): the pure rules — the invite code, the canonical email of
 * the alias checks, the masked names, the settings and their validation, the milestone states. No database, no Nest.
 */

/** Crockford-like: no 0/O, 1/I/L, U. Eight characters ≈ 8.5 × 10^11 codes. */
export const CODE_ALPHABET = '23456789ABCDEFGHJKMNPQRSTVWXYZ';
export const CODE_LENGTH = 8;

export function newReferralCode(): string {
  let out = '';
  for (let i = 0; i < CODE_LENGTH; i++) out += CODE_ALPHABET[randomInt(0, CODE_ALPHABET.length)];
  return out;
}

/**
 * A typed code as stored: upper case, without spaces, dashes or a leading link (`…/i/CODE`). Null when it cannot be a
 * code (the format only; whether it exists is the database's answer).
 */
export function normalizeReferralCode(raw: string): string | null {
  let v = raw.trim();
  const link = /\/i\/([A-Za-z0-9 -]+)\/?$/.exec(v);
  if (link) v = link[1]!;
  v = v.replace(/[\s-]+/gu, '').toUpperCase();
  return /^[A-Z0-9]{6,16}$/.test(v) ? v : null;
}

/** The request field: a code or an invite link, at most 200 characters (normalized by the rules above). */
export const referralCodeInput = z
  .string()
  .max(200)
  .transform((raw, ctx) => {
    const code = normalizeReferralCode(raw);
    if (code === null) {
      ctx.addIssue({
        code: 'custom',
        message: 'referralCode invalid_format',
        params: { issue: 'invalid_format' },
      });
      return z.NEVER;
    }
    return code;
  });

/** `DeviceInfo.installId`: the app's random id for this install (kept until it is uninstalled). */
export const installIdSchema = z.string().regex(/^[A-Za-z0-9-]{8,64}$/);

const GMAIL = new Set(['gmail.com', 'googlemail.com']);
/** Providers where `+tag` is an alias of the same mailbox (cheap and common). */
const PLUS_ALIAS = new Set([
  'gmail.com',
  'googlemail.com',
  'outlook.com',
  'hotmail.com',
  'live.com',
  'icloud.com',
  'me.com',
  'proton.me',
  'protonmail.com',
  'yahoo.com',
  'fastmail.com',
]);

/**
 * The mailbox behind an address, for the duplicate and self-referral checks: lower case; `+tag` removed at the
 * providers that ignore it; Gmail's dots removed and `googlemail.com` read as `gmail.com`.
 */
export function canonicalEmail(email: string): string {
  const lower = email.trim().toLowerCase();
  const at = lower.lastIndexOf('@');
  if (at <= 0) return lower;
  let local = lower.slice(0, at);
  let domain = lower.slice(at + 1);
  if (PLUS_ALIAS.has(domain)) local = local.split('+')[0]!;
  if (GMAIL.has(domain)) {
    local = local.replace(/\./g, '');
    domain = 'gmail.com';
  }
  return `${local}@${domain}`;
}

/** A name shown to others: its first and last grapheme with `***` between (`سارة` → `س***ة`, `Al` → `A***`). */
export function maskName(name: string): string {
  const seg = new Intl.Segmenter(undefined, { granularity: 'grapheme' });
  const parts = [...seg.segment(name.trim())].map((s) => s.segment).filter((s) => s.trim() !== '');
  if (parts.length === 0) return '***';
  if (parts.length <= 2) return `${parts[0]}***`;
  return `${parts[0]}***${parts[parts.length - 1]}`;
}

export interface Milestone {
  readonly friends: number;
  readonly cherries: bigint;
}

/** The settings row as the rules use it. */
export interface ReferralSettingsValue {
  readonly enabled: boolean;
  readonly inviterSignupCherries: bigint;
  readonly inviteeSignupCherries: bigint;
  readonly firstRechargeBps: number;
  readonly milestones: readonly Milestone[];
  readonly dailySignupCap: number;
  readonly holdHours: number;
  readonly applyWindowDays: number;
  readonly selfIpWindowHours: number;
}

const cherries = z
  .union([z.number().int(), z.string().regex(/^[0-9]+$/)])
  .transform((v) => BigInt(v))
  .pipe(z.bigint().min(0n).max(100_000_000n));

const milestonesSchema = z
  .array(
    z.strictObject({
      friends: z.number().int().min(1).max(1000),
      cherries: z
        .union([z.number().int(), z.string().regex(/^[0-9]+$/)])
        .transform((v) => BigInt(v))
        .pipe(z.bigint().min(1n).max(100_000_000n)),
    }),
  )
  .max(5)
  .refine((ms) => ms.every((m, i) => i === 0 || m.friends > ms[i - 1]!.friends), {
    message: 'milestones must have increasing friends',
    params: { issue: 'invalid_value' },
  });

/** The settings a change may name (each optional). */
export const referralSettingsFields = {
  enabled: z.boolean().optional(),
  inviterSignupCherries: cherries.optional(),
  inviteeSignupCherries: cherries.optional(),
  firstRechargeBps: z.number().int().min(0).max(5000).optional(),
  milestones: milestonesSchema.optional(),
  dailySignupCap: z.number().int().min(0).max(1000).optional(),
  holdHours: z.number().int().min(0).max(720).optional(),
  applyWindowDays: z.number().int().min(0).max(90).optional(),
  selfIpWindowHours: z.number().int().min(0).max(720).optional(),
};
export const REFERRAL_SETTING_KEYS = Object.keys(
  referralSettingsFields,
) as (keyof typeof referralSettingsFields)[];

/** The CLI's change: any subset of the settings (at least one). */
export const referralSettingsPatch = z
  .strictObject(referralSettingsFields)
  .refine((v) => Object.values(v).some((x) => x !== undefined), {
    message: 'nothing to change',
    path: ['body'],
    params: { issue: 'required' },
  });
export type ReferralSettingsPatch = z.output<typeof referralSettingsPatch>;

/** `UpdateAdminReferralSettingsRequest`: the change, a reason and the authenticator code again. */
export const adminReferralSettingsBody = z
  .strictObject({
    ...referralSettingsFields,
    reason: z.string().trim().min(1).max(500),
    totpCode: z.string().regex(/^[0-9]{6}$/),
  })
  .refine((v) => REFERRAL_SETTING_KEYS.some((k) => v[k] !== undefined), {
    message: 'nothing to change',
    path: ['body'],
    params: { issue: 'required' },
  });
export type AdminReferralSettingsBody = z.output<typeof adminReferralSettingsBody>;

/** The patch part of a panel body. */
export function patchOf(
  body: Partial<Record<keyof typeof referralSettingsFields, unknown>>,
): ReferralSettingsPatch {
  const out: Record<string, unknown> = {};
  for (const k of REFERRAL_SETTING_KEYS) if (body[k] !== undefined) out[k] = body[k];
  return out;
}

/** The stored JSON of `referral_settings.milestones` (read defensively: a bad row gives no milestones). */
export function parseMilestones(raw: unknown): Milestone[] {
  const parsed = milestonesSchema.safeParse(raw);
  return parsed.success ? parsed.data.map((m) => ({ friends: m.friends, cherries: m.cherries })) : [];
}

export function milestonesJson(ms: readonly Milestone[]): { friends: number; cherries: number }[] {
  return ms.map((m) => ({ friends: m.friends, cherries: Number(m.cherries) }));
}

/** The first-recharge reward: floor(coins × CHERRIES_PER_COIN × bps / 10 000) cherries. */
export function firstRechargeCherries(coins: bigint, cherriesPerCoin: number, bps: number): bigint {
  if (coins <= 0n || bps <= 0) return 0n;
  return (coins * BigInt(cherriesPerCoin) * BigInt(bps)) / 10_000n;
}

/** The milestones' total («ادعُ أصدقاء جدداً واربح حتى Z»). */
export function milestonesTotal(ms: readonly Milestone[]): bigint {
  return ms.reduce((s, m) => s + m.cherries, 0n);
}

/**
 * The hero's «اربح حتى N» without the recharge share (it has no ceiling): the inviter's sign-up reward for as many
 * friends as the last milestone needs, plus every milestone.
 */
export function heroUpTo(s: Pick<ReferralSettingsValue, 'inviterSignupCherries' | 'milestones'>): bigint {
  const friends = s.milestones.length > 0 ? s.milestones[s.milestones.length - 1]!.friends : 1;
  return s.inviterSignupCherries * BigInt(friends) + milestonesTotal(s.milestones);
}

export type MilestoneState = 'LOCKED' | 'UNLOCKED' | 'CLAIMED';

/**
 * LOCKED: fewer friends than the threshold; UNLOCKED: enough friends counting those still in their hold (not yet
 * qualified); CLAIMED: the bonus was credited.
 */
export function milestoneState(
  m: Milestone,
  counts: { qualified: number; pending: number },
  credited: ReadonlySet<number>,
): MilestoneState {
  if (credited.has(m.friends)) return 'CLAIMED';
  return counts.qualified + counts.pending >= m.friends ? 'UNLOCKED' : 'LOCKED';
}

/** Why a referral is refused at the start (`referrals.reject_reason`). */
export type ReferralRejectReason =
  'SELF_DEVICE' | 'SELF_EMAIL' | 'SELF_IP' | 'DUPLICATE_DEVICE' | 'DUPLICATE_EMAIL';
