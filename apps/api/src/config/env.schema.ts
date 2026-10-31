import { isIP } from 'node:net';
import { ipv6Hextets } from '../common/http/request-context.js';
import { availableParallelism } from 'node:os';
import { z } from 'zod';
import { luckyTable, percentToBps, type PityRule } from '../modules/gifts/lucky-odds.js';
import { MIN_SECRET_BYTES, productionSecretProblem } from './secret-strength.js';

/** A rate-limit rule: at most `max` requests per `windowSeconds`. */
export interface RateLimitRule {
  readonly max: number;
  readonly windowSeconds: number;
}

const rateLimit = (fallback: string) =>
  z
    .string()
    .trim()
    .default(fallback)
    .transform((value, ctx): RateLimitRule => {
      const match = /^(\d{1,7})\/(\d{1,7})$/.exec(value);
      const max = Number(match?.[1]);
      const windowSeconds = Number(match?.[2]);
      if (!match || max < 1 || windowSeconds < 1) {
        ctx.addIssue({
          code: 'custom',
          message: `expected "<max>/<windowSeconds>" with positive integers, got "${value}"`,
        });
        return z.NEVER;
      }
      return { max, windowSeconds };
    });

/**
 * A plain decimal integer setting: digits only, no sign, exponent, hex prefix, padding or leading
 * zeros (`z.coerce.number()` accepted `1e3`, `0x10`, ` 15 ` and the empty string as 0). Bounded.
 */
export const intSetting = (fallback: number, min: number, max: number = Number.MAX_SAFE_INTEGER) =>
  z
    .string()
    .regex(/^(0|[1-9][0-9]{0,15})$/, 'must be a plain decimal integer (digits only)')
    .default(String(fallback))
    .transform(Number)
    .pipe(z.number().int().min(min).max(max));

const positiveInt = (fallback: number) => intSetting(fallback, 1);

/** At most this many gift quantities (LIVE_GIFT_QUANTITIES). */
/** D148: the lucky guarantee of the configuration, or null when LUCKY_PITY_AFTER is 0 (off). */
export function luckyPityOf(env: {
  LUCKY_PITY_AFTER: number;
  LUCKY_PITY_MULTIPLIER: number;
}): PityRule | null {
  return env.LUCKY_PITY_AFTER === 0
    ? null
    : { after: env.LUCKY_PITY_AFTER, multiplier: env.LUCKY_PITY_MULTIPLIER };
}

/**
 * v1.59-social (D190): the retail price in cents per 1 000 000 coins (COIN_RETAIL_USD_PER_MILLION × 100), or null
 * when it is not a whole number of cents.
 */
export function topupMinorPerMillion(usdPerMillion: number): number | null {
  const minor = Math.round(usdPerMillion * 100);
  return Math.abs(minor - usdPerMillion * 100) < 1e-6 ? minor : null;
}

export const LIVE_GIFT_QUANTITIES_MAX = 12;
/** The largest gift quantity. */
export const LIVE_GIFT_QUANTITY_MAX = 9999;

/**
 * v1.23-live (CP-020): a list of gift quantities, e.g. `1,10,66,99`: plain decimal integers
 * 1 … 9999, strictly ascending (so no duplicates), 1 … 12 of them.
 */
/**
 * v1.28-live (D146): the days before a premium username's end when a reminder is sent
 * (`PREMIUM_USERNAME_REMINDER_DAYS`, e.g. `3,1`): 0–5 distinct whole numbers 1–30; empty = none.
 */
export const reminderDays = (fallback: string) =>
  z
    .string()
    .trim()
    .default(fallback)
    .transform((value, ctx): readonly number[] => {
      if (value === '') return [];
      const numbers = value.split(',').map((p) => (/^[1-9][0-9]?$/.test(p.trim()) ? Number(p.trim()) : NaN));
      if (
        numbers.length > 5 ||
        numbers.some((n) => !(n >= 1 && n <= 30)) ||
        new Set(numbers).size !== numbers.length
      ) {
        ctx.addIssue({
          code: 'custom',
          message: 'must be up to 5 distinct whole numbers from 1 to 30, comma-separated',
        });
        return z.NEVER;
      }
      return [...numbers].sort((a, b) => b - a);
    });

export const giftQuantities = (fallback: string) =>
  z
    .string()
    .trim()
    .default(fallback)
    .transform((value, ctx): readonly number[] => {
      const parts = value.split(',').map((p) => p.trim());
      const numbers = parts.map((p) => (/^[1-9][0-9]{0,3}$/.test(p) ? Number(p) : NaN));
      const ascending = numbers.every((n, i) => i === 0 || n > numbers[i - 1]!);
      if (
        parts.length < 1 ||
        parts.length > LIVE_GIFT_QUANTITIES_MAX ||
        numbers.some((n) => !Number.isInteger(n) || n < 1 || n > LIVE_GIFT_QUANTITY_MAX) ||
        !ascending
      ) {
        ctx.addIssue({
          code: 'custom',
          message: `expected 1–${String(LIVE_GIFT_QUANTITIES_MAX)} strictly ascending whole numbers 1–${String(LIVE_GIFT_QUANTITY_MAX)}, comma-separated, got "${value}"`,
        });
        return z.NEVER;
      }
      return Object.freeze(numbers);
    });
const nonNegativeInt = (fallback: number) => intSetting(fallback, 0);

/** v1.27-live (D132): a percentage with at most two decimals ("85", "10.5") → basis points. */
/**
 * v1.32-live (D154, CONVENTIONS §10.33): the recipients' earnings share per gift category, e.g.
 * `POPULAR:65,EVENT:65,FUN:65,QUIPS:50` → basis points by category. Every non-lucky category must be
 * named once (LUCKY keeps LUCKY_GIFT_HOST_SHARE_PERCENT).
 */
export const HOST_SHARE_CATEGORIES = ['POPULAR', 'EVENT', 'FUN', 'QUIPS'] as const;
export type HostShareCategory = (typeof HOST_SHARE_CATEGORIES)[number];

const hostSharePercents = (fallback: string) =>
  z
    .string()
    .trim()
    .default(fallback)
    .transform((value, ctx): Readonly<Record<HostShareCategory, number>> => {
      const out: Partial<Record<HostShareCategory, number>> = {};
      for (const part of value.split(',')) {
        const [name, percent, extra] = part.split(':').map((p) => p.trim());
        const bps = percent === undefined ? null : percentToBps(percent);
        if (
          extra !== undefined ||
          !HOST_SHARE_CATEGORIES.includes(name as HostShareCategory) ||
          bps === null ||
          bps > 10_000 ||
          out[name as HostShareCategory] !== undefined
        ) {
          ctx.addIssue({
            code: 'custom',
            message: `expected CATEGORY:percent pairs for ${HOST_SHARE_CATEGORIES.join(', ')} (each once), got "${value}"`,
          });
          return z.NEVER;
        }
        out[name as HostShareCategory] = bps;
      }
      const missing = HOST_SHARE_CATEGORIES.filter((c) => out[c] === undefined);
      if (missing.length > 0) {
        ctx.addIssue({ code: 'custom', message: `missing ${missing.join(', ')}` });
        return z.NEVER;
      }
      return out as Record<HostShareCategory, number>;
    });

/**
 * v1.33-live (D154b, CONVENTIONS §10.34): the traffic card prices, `minutes:coins` pairs, e.g.
 * `10:10000,20:18000` → ascending by minutes. 1–8 lengths of 1–1440 minutes, prices 1 … 10^9 coins.
 */
export interface BoostPrice {
  readonly minutes: number;
  readonly coins: number;
}
const boostPrices = (fallback: string) =>
  z
    .string()
    .trim()
    .default(fallback)
    .transform((value, ctx): readonly BoostPrice[] => {
      const out: BoostPrice[] = [];
      for (const part of value.split(',')) {
        const m = /^\s*(\d{1,4})\s*:\s*(\d{1,10})\s*$/.exec(part);
        const minutes = Number(m?.[1]);
        const coins = Number(m?.[2]);
        if (
          !m ||
          minutes < 1 ||
          minutes > 1440 ||
          coins < 1 ||
          coins > 1_000_000_000 ||
          out.some((p) => p.minutes === minutes)
        ) {
          ctx.addIssue({
            code: 'custom',
            message: `expected minutes:coins pairs (distinct minutes), got "${value}"`,
          });
          return z.NEVER;
        }
        out.push({ minutes, coins });
      }
      if (out.length > 8) {
        ctx.addIssue({ code: 'custom', message: 'at most 8 lengths' });
        return z.NEVER;
      }
      return out.sort((a, b) => a.minutes - b.minutes);
    });

/**
 * v1.44-social (D166, CONVENTIONS §10.41): the SVIP thresholds — coins spent on gifts in the rolling
 * window for SVIP 1, 2, … (comma-separated, strictly ascending, 1–10 tiers of 1 … 10^12 coins).
 */
const svipTiers = (fallback: string) =>
  z
    .string()
    .trim()
    .default(fallback)
    .transform((value, ctx): readonly number[] => {
      const parts = value.split(',').map((p) => p.trim());
      const numbers = parts.map((p) => (/^[1-9][0-9]{0,12}$/.test(p) ? Number(p) : NaN));
      const ascending = numbers.every((n, i) => i === 0 || n > numbers[i - 1]!);
      if (
        parts.length < 1 ||
        parts.length > 10 ||
        numbers.some((n) => !Number.isInteger(n) || n < 1 || n > 1_000_000_000_000) ||
        !ascending
      ) {
        ctx.addIssue({
          code: 'custom',
          message: `expected 1–10 strictly ascending coin amounts, comma-separated, got "${value}"`,
        });
        return z.NEVER;
      }
      return Object.freeze(numbers);
    });

/** v1.44-social (D166): one coin package of the recharge screen (prices in minor units, e.g. cents). */
export interface RechargePackage {
  readonly id: string;
  readonly coins: number;
  readonly bonusCoins: number;
  readonly priceMinor: number;
  /** The price before a discount, or null (no «عرض» ribbon). */
  readonly originalPriceMinor: number | null;
}

/**
 * v1.44-social (D166, CONVENTIONS §10.41): the recharge packages, `coins+bonus:price[:original]` with
 * prices in minor units, comma-separated, e.g. `10+20:29,276+28:699:800`. 1–12 packages; an original
 * price must be higher than the price. Placeholders until the owner sets real ones (B5).
 */
const rechargePackages = (fallback: string) =>
  z
    .string()
    .trim()
    .default(fallback)
    .transform((value, ctx): readonly RechargePackage[] => {
      const out: RechargePackage[] = [];
      for (const part of value.split(',')) {
        const m = /^\s*(\d{1,9})\s*\+\s*(\d{1,9})\s*:\s*(\d{1,9})\s*(?::\s*(\d{1,9})\s*)?$/.exec(part);
        const coins = Number(m?.[1]);
        const bonusCoins = Number(m?.[2]);
        const priceMinor = Number(m?.[3]);
        const original = m?.[4] === undefined ? null : Number(m[4]);
        if (!m || coins < 1 || priceMinor < 1 || (original !== null && original <= priceMinor)) {
          ctx.addIssue({
            code: 'custom',
            message: `expected coins+bonus:price[:originalPrice] packages, got "${value}"`,
          });
          return z.NEVER;
        }
        out.push({
          id: `p${String(out.length + 1)}`,
          coins,
          bonusCoins,
          priceMinor,
          originalPriceMinor: original,
        });
      }
      if (out.length > 12) {
        ctx.addIssue({ code: 'custom', message: 'at most 12 packages' });
        return z.NEVER;
      }
      return Object.freeze(out);
    });

const percentSetting = (fallback: string) =>
  z
    .string()
    .trim()
    .default(fallback)
    .transform((value, ctx): number => {
      const bps = percentToBps(value);
      if (bps === null) {
        ctx.addIssue({ code: 'custom', message: `expected a percentage like 85 or 10.5, got "${value}"` });
        return z.NEVER;
      }
      return bps;
    });

/** v1.27-live (D132): a comma-separated list of plain whole numbers (checked further in superRefine). */
const wholeNumberList = (fallback: string) =>
  z
    .string()
    .trim()
    .default(fallback)
    .transform((value, ctx): readonly number[] => {
      const parts = value.split(',').map((p) => p.trim());
      if (parts.some((p) => !/^[1-9][0-9]{0,5}$/.test(p))) {
        ctx.addIssue({ code: 'custom', message: `expected comma-separated whole numbers, got "${value}"` });
        return z.NEVER;
      }
      return Object.freeze(parts.map(Number));
    });

/** v1.27-live (D132): ISO 3166-1 alpha-2 codes, comma-separated (case-insensitive), possibly none. */
const countryList = z
  .string()
  .trim()
  .default('')
  .transform((value, ctx): readonly string[] => {
    if (value === '') return Object.freeze([]);
    const codes = value.split(',').map((p) => p.trim().toUpperCase());
    if (codes.some((c) => !/^[A-Z]{2}$/.test(c))) {
      ctx.addIssue({
        code: 'custom',
        message: `expected two-letter country codes, comma-separated, got "${value}"`,
      });
      return z.NEVER;
    }
    return Object.freeze([...new Set(codes)]);
  });

const ianaTimeZone = (fallback: string) =>
  z
    .string()
    .trim()
    .default(fallback)
    .refine(
      (tz) => {
        try {
          new Intl.DateTimeFormat('en', { timeZone: tz });
          return true;
        } catch {
          return false;
        }
      },
      { message: 'must be an IANA time zone' },
    );

/** SEC-035: bounds of LIVE_SWEEP_BATCH_SIZE (rooms ended per sweeper transaction). */
export const LIVE_SWEEP_BATCH_SIZE_MIN = 1;
export const LIVE_SWEEP_BATCH_SIZE_MAX = 5000;

/**
 * Heartbeat headroom: in production the per-user heartbeat bucket must allow at least this many
 * times the expected cadence (one beat per LIVE_HEARTBEAT_INTERVAL_SECONDS), so client retries
 * never hit 429 (CONVENTIONS §7: 12 / min at a 15 s cadence = 3×).
 */
export const HEARTBEAT_RATE_LIMIT_HEADROOM = 2;

/**
 * SEC-003a (contract v1.2.3): a trusted-proxy range is too broad for production when it is an
 * IPv4 prefix shorter than /8, an IPv6 prefix shorter than /32, or an IPv4-mapped IPv6 range
 * (`::ffff:a.b.c.d/n`, n ≥ 96) whose IPv4 equivalent is shorter than /8 (e.g. `::ffff:0:0/96`).
 */
export function isOverlyBroadProxyRange(entry: string): boolean {
  const [address = '', prefixText] = entry.split('/');
  if (prefixText === undefined) return false;
  const prefix = Number(prefixText);
  const family = isIP(address);
  if (family === 4) return prefix < 8;
  if (family !== 6) return false;
  const groups = ipv6Hextets(address);
  const mapped = groups !== null && groups.slice(0, 5).every((g) => g === 0) && groups[5] === 0xffff;
  if (mapped && prefix >= 96) return prefix - 96 < 8;
  return prefix < 32;
}

const TRUST_PROXY_KEYWORDS = new Set(['loopback', 'linklocal', 'uniquelocal']);

/** True for an IP address, an IP/prefix CIDR, or one of Express' proxy keywords. */
export function isTrustedProxyEntry(entry: string): boolean {
  if (TRUST_PROXY_KEYWORDS.has(entry)) return true;
  const [address = '', prefix, ...rest] = entry.split('/');
  const family = isIP(address);
  if (family === 0 || rest.length > 0) return false;
  if (prefix === undefined) return true;
  if (!/^\d{1,3}$/.test(prefix)) return false;
  return Number(prefix) <= (family === 4 ? 32 : 128);
}

/**
 * Express `trust proxy`: `false` | `true` | hop count | comma-separated addresses/CIDRs/keywords.
 * `true` (trust every hop, i.e. the client-controlled left-most X-Forwarded-For) is refused in
 * production by the schema refinement below (SEC-003, CONVENTIONS §7).
 */
const trustProxy = z
  .string()
  .trim()
  .default('false')
  .transform((value, ctx): boolean | number | string[] => {
    if (value === '' || value === 'false') return false;
    if (value === 'true') return true;
    if (/^\d+$/.test(value)) return Number(value);
    const entries = value
      .split(',')
      .map((part) => part.trim())
      .filter(Boolean);
    const invalid = entries.filter((entry) => !isTrustedProxyEntry(entry));
    if (invalid.length > 0) {
      ctx.addIssue({
        code: 'custom',
        message: `expected false, a hop count, or IPs/CIDRs (loopback|linklocal|uniquelocal); invalid: ${invalid.join(', ')}`,
      });
      return z.NEVER;
    }
    return entries;
  });

export const envSchema = z
  .object({
    NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
    PORT: intSetting(3000, 1, 65535),
    LOG_LEVEL: z.enum(['fatal', 'error', 'warn', 'info', 'debug', 'trace', 'silent']).default('info'),

    DATABASE_URL: z
      .string()
      .trim()
      .min(1, 'is required')
      .refine((v) => /^postgres(ql)?:\/\//.test(v), 'must be a postgresql:// URL'),
    REDIS_URL: z
      .string()
      .trim()
      .min(1, 'is required')
      .refine((v) => /^rediss?:\/\//.test(v), 'must be a redis:// or rediss:// URL'),
    /** Prefix for every Redis key written by this process (isolates environments/tests). */
    REDIS_KEY_PREFIX: z
      .string()
      .trim()
      .regex(/^[A-Za-z0-9:_-]{1,64}$/)
      .default('kabso:'),

    JWT_ACCESS_SECRET: z
      .string()
      .min(1, 'is required')
      .refine((v) => Buffer.byteLength(v, 'utf8') >= 32, 'must be at least 32 bytes'),
    /** HMAC key for rate-limit subject keys (SEC-010). Required in production. */
    RATE_LIMIT_KEY_SECRET: z
      .string()
      .min(1)
      .refine((v) => Buffer.byteLength(v, 'utf8') >= MIN_SECRET_BYTES, 'must be at least 32 bytes')
      .optional(),
    JWT_ACCESS_TTL_SECONDS: positiveInt(900),
    REFRESH_TTL_SECONDS: positiveInt(30 * 24 * 3600),
    REFRESH_ABSOLUTE_TTL_SECONDS: positiveInt(180 * 24 * 3600),
    EMAIL_VERIFY_TOKEN_TTL_SECONDS: positiveInt(24 * 3600),
    PASSWORD_RESET_TOKEN_TTL_SECONDS: positiveInt(3600),

    APP_PUBLIC_URL: z.url({ protocol: /^https?$/ }).transform((v) => v.replace(/\/+$/, '')),
    /**
     * `log` writes mail to the log (development only). `smtp` sends through the SMTP_* server
     * (KL-042, B2) over TLS: implicit TLS when SMTP_SECURE=true (port 465), otherwise STARTTLS,
     * which is then required.
     */
    MAIL_TRANSPORT: z.enum(['log', 'smtp']).default('log'),
    /** Sender of every message, e.g. `Kabso Live <no-reply@example.com>`. Required with smtp. */
    MAIL_FROM: z.string().trim().min(3).max(256).optional(),
    SMTP_HOST: z.string().trim().min(1).max(255).optional(),
    SMTP_PORT: intSetting(465, 1, 65535),
    SMTP_SECURE: z
      .enum(['true', 'false'], { error: 'must be "true" or "false"' })
      .default('true')
      .transform((v) => v === 'true'),
    SMTP_USER: z.string().trim().min(1).max(256).optional(),
    SMTP_PASSWORD: z.string().min(1).max(512).optional(),

    CORS_ORIGINS: z
      .string()
      .default('')
      .transform((v) =>
        v
          .split(',')
          .map((o) => o.trim())
          .filter(Boolean),
      ),
    TRUST_PROXY: trustProxy,
    BODY_LIMIT: z
      .string()
      .trim()
      .regex(/^\d+(b|kb|mb)$/i)
      .default('100kb'),

    RATE_LIMIT_LOGIN_IP_ACCOUNT: rateLimit('10/900'),
    RATE_LIMIT_LOGIN_ACCOUNT: rateLimit('20/900'),
    RATE_LIMIT_LOGIN_IP: rateLimit('50/900'),
    RATE_LIMIT_REGISTER_IP: rateLimit('5/3600'),
    RATE_LIMIT_FORGOT_EMAIL: rateLimit('3/3600'),
    RATE_LIMIT_FORGOT_IP: rateLimit('10/3600'),
    RATE_LIMIT_REFRESH_SESSION: rateLimit('60/900'),
    RATE_LIMIT_AUTHENTICATED_USER: rateLimit('600/900'),
    RATE_LIMIT_EMAIL_RESEND_USER: rateLimit('5/3600'),
    RATE_LIMIT_PUBLIC_IP: rateLimit('300/900'),
    /** v1.60-social (D191, §10.54.2): panel sign-in, second factor and enrolment per IP. */
    RATE_LIMIT_ADMIN_LOGIN_IP: rateLimit('30/900'),
    /** v1.60-social (D191): every other cookie-authenticated panel request per IP. */
    RATE_LIMIT_ADMIN_IP: rateLimit('1200/900'),
    // v1.2 (CONVENTIONS §7)
    RATE_LIMIT_REGISTER_EMAIL: rateLimit('3/3600'),
    RATE_LIMIT_REGISTER_VERIFY_IP: rateLimit('10/900'),
    RATE_LIMIT_REGISTER_VERIFY_EMAIL: rateLimit('15/86400'),
    RATE_LIMIT_REGISTER_RESEND_EMAIL: rateLimit('3/3600'),
    RATE_LIMIT_REGISTER_RESEND_IP: rateLimit('10/3600'),
    RATE_LIMIT_UPDATE_ME_USER: rateLimit('30/3600'),
    // v1.3 (CONVENTIONS §7): per-user buckets that replace the default authenticated bucket.
    RATE_LIMIT_LIVE_LIST_USER: rateLimit('300/900'),
    RATE_LIMIT_PROFILE_USER: rateLimit('300/900'),
    RATE_LIMIT_LIVE_START_HOUR_USER: rateLimit('10/3600'),
    RATE_LIMIT_LIVE_START_DAY_USER: rateLimit('30/86400'),
    RATE_LIMIT_LIVE_HEARTBEAT_USER: rateLimit('12/60'),
    RATE_LIMIT_LIVE_END_USER: rateLimit('30/3600'),
    RATE_LIMIT_LIVE_MEDIA_TOKEN_USER: rateLimit('120/3600'),
    RATE_LIMIT_LIVE_MEDIA_TOKEN_GUEST_IP: rateLimit('60/3600'),
    RATE_LIMIT_LIVE_UPDATE_USER: rateLimit('60/3600'),
    RATE_LIMIT_LIVE_COVER_USER: rateLimit('30/3600'),
    // v1.45-social (D168, CONVENTIONS §7, §10.42): `PUT` / `DELETE /me/avatar`, one bucket.
    RATE_LIMIT_AVATAR_USER: rateLimit('30/3600'),
    // v1.47-social (D175, CONVENTIONS §7, §10.47): accept / decline a follow request, one bucket.
    RATE_LIMIT_FOLLOW_REQUEST_ANSWER_USER: rateLimit('300/3600'),
    RATE_LIMIT_LIVE_BLOCKED_WORDS_USER: rateLimit('30/3600'),
    RATE_LIMIT_LIVE_SCHEDULE_USER: rateLimit('30/3600'),
    RATE_LIMIT_LIVE_GUEST_READ_IP: rateLimit('300/900'),
    // CP-011 (CONVENTIONS §7): per user, each replacing the default authenticated bucket.
    RATE_LIMIT_LIVE_SEAT_ASK_USER: rateLimit('30/600'),
    RATE_LIMIT_LIVE_SEAT_ACTION_USER: rateLimit('300/3600'),
    RATE_LIMIT_LIVE_SEATS_READ_USER: rateLimit('600/900'),
    // CP-012 (CONVENTIONS §7): tap batches per user, replacing the default authenticated bucket.
    RATE_LIMIT_LIVE_TAPS_USER: rateLimit('120/60'),
    // CP-013 (CONVENTIONS §7): chat messages per user, replacing the default authenticated bucket
    // (the 1-a-second-per-room counting rule is separate, §10.11).
    RATE_LIMIT_LIVE_CHAT_USER: rateLimit('20/60'),
    // v1.21-live (CP-018, CONVENTIONS §7): family and CP writes and CP gifts, per user, each
    // replacing the default authenticated bucket.
    RATE_LIMIT_FAMILY_WRITE_USER: rateLimit('60/3600'),
    RATE_LIMIT_CP_WRITE_USER: rateLimit('30/3600'),
    RATE_LIMIT_CP_GIFT_USER: rateLimit('30/60'),
    // v1.23-live (CP-020, CONVENTIONS §7): gift sends in a live, per user, replacing the default
    // authenticated bucket (combos are quick taps on "send": one a second on average, 2× headroom).
    RATE_LIMIT_LIVE_GIFT_USER: rateLimit('120/60'),
    // D145c (CONVENTIONS §7): lucky gifts (the MAX X streak) get their own, higher limits — every
    // gift send of a user counts against the per-minute ceiling (the route's bucket), and a lucky
    // send against its burst bucket instead of RATE_LIMIT_LIVE_GIFT_USER. D145d (owner: 100 lucky
    // sends a second per user): 6000 / min and 100 / s.
    RATE_LIMIT_LIVE_LUCKY_GIFT_USER: rateLimit('6000/60'),
    RATE_LIMIT_LIVE_LUCKY_GIFT_BURST_USER: rateLimit('100/1'),
    // v1.28-live (D146, CONVENTIONS §7): premium usernames and the username change.
    RATE_LIMIT_PREMIUM_RENT_USER: rateLimit('20/3600'),
    RATE_LIMIT_USERNAME_CHANGE_USER: rateLimit('5/86400'),
    // v1.24-live (CP-021, CONVENTIONS §7): CP space writes (check-in, task claims, confession
    // deletes) and new confessions, per user, each replacing the default authenticated bucket.
    RATE_LIMIT_CP_SPACE_WRITE_USER: rateLimit('60/60'),
    RATE_LIMIT_CP_CONFESSION_USER: rateLimit('10/3600'),
    // v1.25-live (CP-022, D116): family chat messages, 30 / minute per user.
    RATE_LIMIT_FAMILY_CHAT_USER: rateLimit('30/60'),
    // v1.40-social (D155, CONVENTIONS §7, §11.13): direct messages — sends, message requests (sent
    // to people who do not follow the sender), and the other writes (read, accept, delete, mute).
    RATE_LIMIT_DM_SEND_USER: rateLimit('30/60'),
    RATE_LIMIT_DM_REQUEST_USER: rateLimit('20/3600'),
    RATE_LIMIT_DM_WRITE_USER: rateLimit('300/3600'),
    // v1.48-social (D171, CONVENTIONS §7, §10.45): bag item sends, per user.
    RATE_LIMIT_BAG_SEND_USER: rateLimit('30/3600'),
    /** v1.54-social (D185, §10.48): coin sales by a recharge agent or employee, and the other recharge writes. */
    RATE_LIMIT_RECHARGE_SELL_USER: rateLimit('120/3600'),
    RATE_LIMIT_RECHARGE_WRITE_USER: rateLimit('60/3600'),
    /** v1.59-social (D190, §10.53): card top-up checkouts started, per user. */
    RATE_LIMIT_TOPUP_CHECKOUT_USER: rateLimit('20/3600'),
    /** v1.61-social (D192, §10.55): the website's waitlist sign-ups, per client IP (no account). */
    RATE_LIMIT_WAITLIST_IP: rateLimit('10/3600'),
    RATE_LIMIT_FOLLOW_HOUR_USER: rateLimit('60/3600'),
    RATE_LIMIT_FOLLOW_DAY_USER: rateLimit('300/86400'),
    // v1.5-social (CONVENTIONS §11.8); every bucket is per user and replaces the default.
    RATE_LIMIT_MEDIA_UPLOAD_USER: rateLimit('60/3600'),
    RATE_LIMIT_POST_CREATE_HOUR_USER: rateLimit('20/3600'),
    RATE_LIMIT_POST_CREATE_DAY_USER: rateLimit('100/86400'),
    RATE_LIMIT_COMMENT_USER: rateLimit('60/3600'),
    RATE_LIMIT_LIKE_USER: rateLimit('600/3600'),
    RATE_LIMIT_REPOST_USER: rateLimit('60/3600'),
    RATE_LIMIT_SHARE_USER: rateLimit('120/3600'),
    RATE_LIMIT_VIEWS_USER: rateLimit('120/3600'),
    RATE_LIMIT_FEED_USER: rateLimit('300/900'),
    RATE_LIMIT_STORY_CREATE_USER: rateLimit('30/3600'),
    RATE_LIMIT_STORY_SEEN_USER: rateLimit('600/3600'),
    RATE_LIMIT_NOTIFICATIONS_READ_USER: rateLimit('120/3600'),
    RATE_LIMIT_SEARCH_USER: rateLimit('300/900'),
    /** v1.29-live (D147, §11.11): `POST /search/queries` (a submitted search counted for trends). */
    RATE_LIMIT_SEARCH_RECORD_USER: rateLimit('120/3600'),
    RATE_LIMIT_BLOCK_USER: rateLimit('60/3600'),
    RATE_LIMIT_REPORT_USER: rateLimit('30/3600'),

    /**
     * v1.3 (CONVENTIONS §10, B1): going live and heartbeats are refused with 503
     * LIVE_HOSTING_UNAVAILABLE unless this is exactly "true". Default off: there is no media
     * provider yet, so production must not list rooms that cannot play.
     */
    LIVE_HOSTING_ENABLED: z
      .enum(['true', 'false'], { error: 'must be "true" or "false"' })
      .default('false')
      .transform((v) => v === 'true'),
    /** Heartbeat cadence the client is told to use (GET /live/config). */
    LIVE_HEARTBEAT_INTERVAL_SECONDS: intSetting(15, 5, 60),
    /** A LIVE room without a heartbeat for this long is stale (never listed, ended). */
    LIVE_HEARTBEAT_STALE_SECONDS: intSetting(45, 1, 3600),
    /** Period of the in-process stale-room sweeper; 0 disables it (refused in production). */
    LIVE_SWEEP_INTERVAL_SECONDS: intSetting(15, 0, 3600),
    /**
     * v1.42-live (D170, CONVENTIONS §10.44): a video live whose host has been away (the app in the
     * background, the camera off) this long is ended by the sweeper with HOST_AWAY_TIMEOUT.
     */
    LIVE_HOST_AWAY_TIMEOUT_SECONDS: intSetting(300, 30, 86400),
    /**
     * CP-016 A (D99): the one region's time zone (IANA name). The popularity boards' day starts at
     * midnight and the week on Monday there; the hour is the same everywhere.
     */
    LIVE_RANKINGS_TIME_ZONE: z
      .string()
      .trim()
      .default('UTC')
      .refine(
        (tz) => {
          try {
            new Intl.DateTimeFormat('en', { timeZone: tz });
            return true;
          } catch {
            return false;
          }
        },
        { message: 'must be an IANA time zone' },
      ),
    /**
     * v1.23-live (CP-020, D108, CONVENTIONS §10.23): the quantities a gift send may use (the
     * quantity picker), comma-separated whole numbers 1–9999, strictly ascending, 1–12 of them.
     * `GET /gifts/catalogue` returns them; any other quantity → 400.
     */
    LIVE_GIFT_QUANTITIES: giftQuantities('1,10,66,99,188,520,1314'),
    /**
     * v1.32-live (D154, CONVENTIONS §10.33): the recipients' earnings share per gift category (owner:
     * normal gifts 65 % (D149), «إفيهات» quips 50 %). Fixed on each send (`live_gifts.host_share_bps`).
     */
    GIFT_HOST_SHARE_PERCENTS: hostSharePercents('POPULAR:65,EVENT:65,FUN:65,QUIPS:50'),
    /**
     * v1.32-live (D154): a quip (or soundboard sound) is refused (409 QUIP_QUEUE_FULL) when it would
     * start more than this many seconds from now (one plays at a time per room).
     */
    QUIP_QUEUE_MAX_WAIT_SECONDS: intSetting(60, 5, 600),
    /**
     * v1.33-live (D154b, CONVENTIONS §10.34): traffic cards — the prices by length (owner 15c: 10 min
     * 10 000, 20 min 18 000, 30 min 25 000, 60 min 45 000 coins), the paid slots at the top of the live
     * list (owner: 3), and the longest a new card may wait for its slot (else 409 BOOST_QUEUE_FULL).
     */
    LIVE_BOOST_PRICES: boostPrices('10:10000,20:18000,30:25000,60:45000'),
    LIVE_BOOST_SLOTS: intSetting(3, 1, 20),
    LIVE_BOOST_MAX_WAIT_MINUTES: intSetting(180, 10, 1440),
    /**
     * v1.34-live (D154c, CONVENTIONS §10.35): an account younger than this many days is a newcomer
     * («جديد 🌱» in the live chat, the host's Newcomers list); owner: 30 (was 7).
     */
    NEWCOMER_DAYS: intSetting(30, 1, 365),
    /**
     * v1.44-social (D166, CONVENTIONS §10.41, CP-024 approved with defaults): the Task Center — the most
     * coins a person gets from daily tasks and check-ins in one day, the check-in's coins, and the bonus
     * on every 7th day in a row (owner 2026-10-29: 50, 5, 20; the owner may change them).
     */
    TASK_DAILY_CAP_COINS: intSetting(50, 1, 1_000_000),
    /**
     * v1.53-social (D184, CONVENTIONS §10.41.3): task rewards are cherries — the most cherries a person
     * gets from daily tasks in one day (owner: at most about $5 a month — at $1.10 per 1 000 000 cherries
     * ≈ 4 500 000 a month ≈ 150 000 a day). Since D184 `TASK_DAILY_CAP_COINS` caps only the check-in's coins.
     * v1.57-social (D188, owner): 50 000 a day (the 150 000 came from wrong pricing).
     */
    TASK_DAILY_CAP_CHERRIES: intSetting(50_000, 1, 1_000_000_000),
    /**
     * v1.57-social (D188, owner, CONVENTIONS §10.41.3): the most task cherries a person gets in one calendar
     * month (LIVE_RANKINGS_TIME_ZONE), daily and weekly tasks together, in minor units of
     * CHERRY_PAYOUT_CURRENCY converted at CHERRY_PAYOUT_RATE and floored (owner: $5 = 500 → 4 545 454
     * cherries at $1.10 per 1 000 000); 0 = no monthly cap.
     */
    TASK_MONTHLY_CAP_MINOR: intSetting(500, 0, 100_000_000),
    TASK_CHECK_IN_COINS: intSetting(5, 1, 1_000_000),
    TASK_CHECK_IN_STREAK_BONUS_COINS: intSetting(20, 0, 1_000_000),
    /**
     * D166: the Event Center — hours between an event's end (its leaderboard frozen) and the automatic
     * prize payout (the review window; `event-admin hold` stops it), and the sweeper's period (0 = off,
     * refused in production).
     */
    EVENT_PRIZE_REVIEW_HOURS: intSetting(24, 0, 720),
    EVENTS_SWEEP_INTERVAL_SECONDS: intSetting(300, 0, 86_400),
    /**
     * D166: SVIP is earned by gift spending (CP-024 §4): coins spent in the last SVIP_WINDOW_DAYS days for
     * SVIP 1, 2, 3 (owner defaults 50 000 / 150 000 / 400 000), kept SVIP_STATUS_DAYS days after the last
     * moment the threshold was met.
     */
    SVIP_TIERS: svipTiers('50000,150000,400000'),
    SVIP_WINDOW_DAYS: intSetting(30, 1, 365),
    SVIP_STATUS_DAYS: intSetting(30, 1, 365),
    /**
     * D166: the recharge screen's coin packages (placeholders from the owner's reference until the owner
     * sets real ones) and their currency (ISO 4217). Purchases stay off (B5): no purchase endpoint.
     */
    WALLET_RECHARGE_PACKAGES: rechargePackages(
      '10+20:29,38+20:99,276+28:699:800,800+30:1999,2500+30:5999,4193+30:9999,5197+30:12999',
    ),
    WALLET_RECHARGE_CURRENCY: z
      .string()
      .trim()
      .default('USD')
      .refine((c) => /^[A-Z]{3}$/.test(c), { message: 'must be an ISO 4217 code like USD' }),
    /**
     * v1.38-live (D154i, CONVENTIONS §10.39): the YouTube Data API key for watch-together search
     * (server-side only, a secret). Unset: search is off and hosts paste links.
     */
    YOUTUBE_API_KEY: z.string().min(20).max(200).optional(),
    /**
     * v1.27-live (D132, CONVENTIONS §10.27): lucky gifts. Off by default: LUCKY gifts are not
     * listed and cannot be sent; the odds are still published. Every other LUCKY_GIFT* setting is
     * checked at start-up even while off (the server refuses to start on an invalid table).
     */
    LUCKY_GIFTS_ENABLED: z
      .enum(['true', 'false'], { error: 'must be "true" or "false"' })
      .default('false')
      .transform((v) => v === 'true'),
    /** The expected return to senders (RTP), percent (owner: 85). */
    LUCKY_GIFT_RTP_PERCENT: percentSetting('85'),
    /** The share of a lucky gift's value counted for charm, scores, boards and families (owner: 10). */
    LUCKY_GIFT_HOST_SHARE_PERCENT: percentSetting('10'),
    /**
     * The winning multipliers, strictly ascending (D148 owner: ×5 ×10 ×25 ×50 ×100 ×250 ×500
     * ×1000; D132 had ×5 ×10 ×50 ×100 ×500).
     */
    LUCKY_GIFT_MULTIPLIERS: wholeNumberList('5,10,25,50,100,250,500,1000'),
    /**
     * D148: the chance of each multiplier, draws per million, in the same order. The default returns
     * 84.9999 % with the guarantee below (CONVENTIONS §10.27); the table's return, guarantee
     * included, must not pass LUCKY_GIFT_RTP_PERCENT.
     */
    LUCKY_GIFT_CHANCES_PER_MILLION: wholeNumberList('48918,15451,3903,1464,569,130,40,12'),
    /**
     * D132's way of setting the odds, replaced in D148 by LUCKY_GIFT_CHANCES_PER_MILLION: set → the
     * server refuses to start (so an old configuration is never read with a different meaning).
     */
    LUCKY_GIFT_RTP_SHARES: z.string().optional(),
    /**
     * D148 (owner, option B): after this many losing lucky draws in a row by one sender (any room,
     * any session) their next draw pays at least LUCKY_PITY_MULTIPLIER. 0 turns the guarantee off.
     */
    LUCKY_PITY_AFTER: intSetting(15, 0, 1_000),
    /** D148: what the guarantee pays at least (one of LUCKY_GIFT_MULTIPLIERS; owner: ×5). */
    LUCKY_PITY_MULTIPLIER: intSetting(5, 2, 10_000),
    /**
     * Sends whose best win is at least this multiplier are told to every other live (`lucky-ticker`,
     * D148). v1.41-live (D178): every win (×1 and up) is announced to its own room (`lucky-win`).
     */
    LUCKY_GIFT_BIG_WIN_MULTIPLIER: intSetting(100, 2, 10_000),
    /**
     * v1.41-live (D178, owner): a gift send worth at least this many coins is told to every other
     * live as a `gift-ticker` strip (one at a time, the newest first). Every gift shows in its own room.
     */
    GIFT_GLOBAL_TICKER_MIN_COINS: intSetting(1000, 1, 1_000_000_000),
    /** The daily protection's day starts at midnight in this IANA time zone. */
    LUCKY_GIFT_DAY_TIME_ZONE: ianaTimeZone('UTC'),
    /** Countries (ISO 3166-1 alpha-2) where lucky gifts are off; needs LUCKY_GIFTS_COUNTRY_HEADER. */
    LUCKY_GIFTS_DISABLED_COUNTRIES: countryList,
    /**
     * The request header the edge (CDN / reverse proxy) sets to the client's country, e.g.
     * `cf-ipcountry`. The edge must set or strip it on every request. Unset: no edge country.
     */
    LUCKY_GIFTS_COUNTRY_HEADER: z
      .string()
      .trim()
      .regex(/^[A-Za-z0-9-]{1,64}$/, 'must be an HTTP header name')
      .transform((v) => v.toLowerCase())
      .optional(),
    /**
     * SEC-035 (CONVENTIONS §10.2, D43): the sweeper ends at most this many stale rooms per batch,
     * each batch in its own short transaction. Bounded so one batch always fits its timeout.
     */
    LIVE_SWEEP_BATCH_SIZE: intSetting(500, LIVE_SWEEP_BATCH_SIZE_MIN, LIVE_SWEEP_BATCH_SIZE_MAX),
    /**
     * Optional dedicated source of the HMAC key (HKDF, info `live-cursor/v1`) that signs list
     * cursors (CONVENTIONS §10.4; same pattern as REGISTRATION_CODE_KEY). When unset, the key is
     * derived from RATE_LIMIT_KEY_SECRET with that distinct HKDF label (DB_PHASE2_DISCOVERY §4).
     * In production a set value must pass the secret-strength checks and differ from the other
     * secrets. Rotating the source only invalidates outstanding cursors (clients get 400 cursor
     * and reload from the first page).
     */
    LIVE_CURSOR_KEY: z
      .string()
      .min(1)
      .refine((v) => Buffer.byteLength(v, 'utf8') >= MIN_SECRET_BYTES, 'must be at least 32 bytes')
      .optional(),
    /**
     * CP-010 (CONVENTIONS §10.8, D3, B1): the LiveKit media server. Required when
     * LIVE_HOSTING_ENABLED=true; `wss://` in production. Locally `livekit-server --dev`
     * (ws://127.0.0.1:7880); LiveKit Cloud in production with the owner's keys.
     */
    LIVEKIT_URL: z
      .string()
      .url({ protocol: /^wss?$/ })
      .transform((v) => v.replace(/\/+$/, ''))
      .optional(),
    LIVEKIT_API_KEY: z.string().min(1).max(128).optional(),
    LIVEKIT_API_SECRET: z.string().min(1).max(512).optional(),

    /**
     * v1.5-social (CONVENTIONS §11.1, B12): uploads are refused with 503
     * MEDIA_UPLOADS_UNAVAILABLE unless this is exactly "true". When on, the S3 settings and
     * MEDIA_PUBLIC_BASE_URL are required (MinIO locally, Cloudflare R2 in the cloud, D45).
     */
    MEDIA_UPLOADS_ENABLED: z
      .enum(['true', 'false'], { error: 'must be "true" or "false"' })
      .default('false')
      .transform((v) => v === 'true'),
    /** S3-compatible endpoint (MinIO/R2); unset = AWS S3 for the region. */
    S3_ENDPOINT: z.url({ protocol: /^https?$/ }).optional(),
    S3_REGION: z.string().trim().min(1).max(64).default('auto'),
    S3_BUCKET: z.string().trim().min(3).max(63).optional(),
    S3_ACCESS_KEY_ID: z.string().trim().min(1).max(256).optional(),
    S3_SECRET_ACCESS_KEY: z.string().min(1).max(512).optional(),
    S3_FORCE_PATH_STYLE: z
      .enum(['true', 'false'], { error: 'must be "true" or "false"' })
      .default('false')
      .transform((v) => v === 'true'),
    /** Public base URL of the processed images (CDN or bucket domain), without a trailing slash. */
    MEDIA_PUBLIC_BASE_URL: z
      .url({ protocol: /^https?$/ })
      .transform((v) => v.replace(/\/+$/, ''))
      .optional(),
    /** Period of the media sweeper (expired slots, unattached assets); 0 disables it (not in production). */
    MEDIA_SWEEP_INTERVAL_SECONDS: intSetting(300, 0, 86400),
    /** Period of the scheduled-post publisher; 0 disables it (not in production). */
    POSTS_PUBLISH_INTERVAL_SECONDS: intSetting(30, 0, 3600),
    /** Period of the notifications retention sweeper (30 days, CP-009); 0 disables it (not in production). */
    NOTIFICATIONS_SWEEP_INTERVAL_SECONDS: intSetting(3600, 0, 86400),
    /**
     * v1.21-live (CP-018): period of the sweeper that expires family join requests and CP requests
     * after 7 days (and refunds the CP request's coins); 0 disables it (not in production).
     */
    BONDS_SWEEP_INTERVAL_SECONDS: intSetting(300, 0, 86400),
    /** v1.28-live (D146, §10.32): one rent or renewal of a premium username, in days. */
    PREMIUM_USERNAME_PERIOD_DAYS: intSetting(30, 1, 365),
    /** D146: days an expired premium username is kept for its last renter. */
    PREMIUM_USERNAME_GRACE_DAYS: intSetting(7, 0, 90),
    /** D146: reminders before the end (in-app notifications). */
    PREMIUM_USERNAME_REMINDER_DAYS: reminderDays('3,1'),
    /** D146: a renewal may prepay at most this far ahead. */
    PREMIUM_USERNAME_MAX_PREPAID_DAYS: intSetting(365, 1, 3650),
    /** D146: period of the premium-username sweeper (reminders, expiry, grace); 0 disables it (not in production). */
    PREMIUM_USERNAME_SWEEP_INTERVAL_SECONDS: intSetting(60, 0, 3600),
    /**
     * v1.29-live (D147, §11.11): a search term is listed in `GET /search/trending` only once at
     * least this many different people searched it in the last 7 days (nothing rare or personal).
     */
    SEARCH_TRENDING_MIN_SEARCHERS: intSetting(5, 2, 100000),
    /** D147: period of the search-trends sweeper (drops counts older than 14 days); 0 disables it. */
    SEARCH_TRENDS_SWEEP_INTERVAL_SECONDS: intSetting(3600, 0, 86400),
    /**
     * v1.30-live (D152, §11.12): path of the Firebase service-account key (a read-only file mounted
     * into the container, never the key itself). Unset, missing or invalid → push notifications
     * are off (one log line); everything else works.
     */
    FIREBASE_CREDENTIALS_FILE: z.string().trim().min(1).max(4096).optional(),
    /** D152: how often the push outbox (new notifications) is read; 0 disables it (tests). */
    PUSH_DISPATCH_INTERVAL_MS: intSetting(2000, 0, 60000),
    /** D152: at most one general push per recipient per this many seconds (0 = no limit). */
    PUSH_GENERAL_GAP_SECONDS: intSetting(5, 0, 3600),
    /** D152: at most one message push per recipient per chat per this many seconds (0 = no limit). */
    PUSH_MESSAGES_GAP_SECONDS: intSetting(10, 0, 3600),
    /** v1.40-social (D155, §11.13, owner): a direct message is deleted this many hours after it was sent. */
    DM_RETENTION_HOURS: intSetting(24, 1, 720),
    /** v1.48-social (D171): period of the sweeper that deletes expired bag items; 0 disables it (reads filter them anyway). */
    BAG_SWEEP_INTERVAL_SECONDS: intSetting(300, 0, 86400),
    /** D155: period of the direct-message sweeper (expired messages and their media); 0 disables it (not in production). */
    DM_SWEEP_INTERVAL_SECONDS: intSetting(60, 0, 3600),
    /** D155: messages a sender may send in a message request before the recipient accepts or replies. */
    DM_REQUEST_MAX_MESSAGES: intSetting(3, 1, 20),
    /** D155: one's own message may be deleted for everyone within this many seconds of sending it. */
    DM_DELETE_FOR_EVERYONE_SECONDS: intSetting(3600, 0, 86400),
    /**
     * D155 (owner: 50 %): the share of a (non-lucky) gift's coin value counted for the recipient's
     * charm when it is sent in a direct conversation. Lucky gifts keep LUCKY_GIFT_HOST_SHARE_PERCENT.
     */
    GIFT_DM_RECIPIENT_SHARE_PERCENT: intSetting(50, 0, 100),
    /**
     * v1.52-social (D179, CONVENTIONS §10.46, owner 2026-10-30): the cherry economy. Cherries a recipient
     * gets per coin of their share (1 coin = 10 cherries); an agency's commission on its hosts' cherries
     * (15 %), the rate for the month after a month in which its hosts earned AGENCY_TIER_MONTHLY_CHERRIES
     * (16 % after 1.5 billion) and a parent agency's commission on its sub-agencies' hosts (3 %), in basis
     * points, paid by the company on top of the host's share.
     */
    CHERRIES_PER_COIN: intSetting(10, 1, 1000),
    AGENCY_COMMISSION_BPS: intSetting(1500, 0, 10_000),
    AGENCY_COMMISSION_TIER_BPS: intSetting(1600, 0, 10_000),
    AGENCY_TIER_MONTHLY_CHERRIES: intSetting(1_500_000_000, 1),
    AGENCY_PARENT_COMMISSION_BPS: intSetting(300, 0, 10_000),
    /**
     * D179: agency ranks — an AGENT has ≥ AGENCY_RANK_MIN_ACTIVE_HOSTS active hosts or its hosts earned
     * ≥ AGENCY_RANK_EXCEPTION_CHERRIES in the month; an ADMIN (parent) is an agent with ≥
     * AGENCY_ADMIN_MIN_SUB_AGENCIES sub-agencies that qualify as agents. An active host was live on ≥
     * AGENCY_ACTIVE_HOST_MIN_DAYS days and ≥ AGENCY_ACTIVE_HOST_MIN_HOURS hours in the last
     * AGENCY_ACTIVE_HOST_WINDOW_DAYS days. A host may leave within AGENCY_LEAVE_DAYS of joining. The
     * sweeper evaluates ranks every AGENCY_SWEEP_INTERVAL_SECONDS (0 = off; refused in production).
     */
    AGENCY_RANK_MIN_ACTIVE_HOSTS: intSetting(5, 1, 1000),
    AGENCY_RANK_EXCEPTION_CHERRIES: intSetting(200_000_000, 1),
    AGENCY_ADMIN_MIN_SUB_AGENCIES: intSetting(3, 1, 1000),
    AGENCY_ACTIVE_HOST_MIN_DAYS: intSetting(7, 1, 365),
    AGENCY_ACTIVE_HOST_MIN_HOURS: intSetting(10, 1, 8760),
    AGENCY_ACTIVE_HOST_WINDOW_DAYS: intSetting(30, 1, 365),
    AGENCY_LEAVE_DAYS: intSetting(14, 0, 365),
    AGENCY_SWEEP_INTERVAL_SECONDS: intSetting(3600, 0, 86_400),
    /**
     * D179: withdrawals (paid by hand, no provider yet): CHERRY_PAYOUT_RATE = `cherries:minor` (owner:
     * 1 000 000 cherries = $1.10 → `1000000:110`), the currency, the smallest request in minor units
     * (owner: $10) and the payout time shown to the requester («تُدفع يدوياً خلال … أيام»).
     */
    CHERRY_PAYOUT_RATE: z
      .string()
      .trim()
      .default('1000000:110')
      .refine((v) => /^[1-9][0-9]{0,12}:[1-9][0-9]{0,6}$/.test(v), {
        message: 'must be cherries:minor, e.g. 1000000:110',
      })
      .transform((v) => {
        const [cherries, minor] = v.split(':');
        return { cherries: Number(cherries), minor: Number(minor) };
      }),
    /**
     * v1.57-social (D188, owner): the retail price of coins, in US dollars per 1 000 000 coins (owner:
     * $12.50). Used to show the real money of coin-value task targets (`task-admin`); nothing is charged
     * with it.
     */
    COIN_RETAIL_USD_PER_MILLION: z
      .string()
      .trim()
      .default('12.5')
      .refine((v) => /^(0|[1-9][0-9]{0,6})(\.[0-9]{1,4})?$/.test(v) && Number(v) > 0, {
        message: 'must be a positive decimal, e.g. 12.5',
      })
      .transform(Number),
    CHERRY_PAYOUT_CURRENCY: z
      .string()
      .trim()
      .default('USD')
      .refine((c) => /^[A-Z]{3}$/.test(c), { message: 'must be an ISO 4217 code like USD' }),
    CHERRY_WITHDRAWAL_MIN_MINOR: intSetting(1000, 1, 100_000_000),
    CHERRY_WITHDRAWAL_PAYOUT_DAYS: intSetting(7, 1, 90),
    /**
     * v1.53-social (D184, CONVENTIONS §10.46.1): task-reward cherries stay locked for withdrawal until the
     * person's lifetime gift cherries (GIFT_RECEIVED minus GIFT_REVERSAL) are worth at least this many minor
     * units of CHERRY_PAYOUT_CURRENCY at CHERRY_PAYOUT_RATE (owner, confirmed: lifetime received support
     * worth $50 = 5000); 0 = task cherries are never locked. v1.57-social (D188, owner: «لمن يكون قيمة ما حصل
     * عليه من دعم لا يقل عن 60 دولار»): $60 = 6000.
     */
    TASK_CHERRIES_UNLOCK_GIFT_MINOR: intSetting(6000, 0, 100_000_000_000),
    /**
     * v1.54-social (D185, CONVENTIONS §10.48): recharge agents. The first top-up that activates an agent (owner:
     * 30 000 000 coins); the owner's wholesale price tiers `minCoins:minorPerMillion,…` (USD cents per 1 000 000
     * coins: $12, from 100M $11.95, from 300M $11.90); the cherry → coin rate for an agent buying a host's
     * cherries `cherries:coins` (owner: 1 000 000 → 93 220), its minimum and step, how long a request stays open,
     * the default daily cap per agent (cherries), the most employees per agent, how long a rejected
     * application's private data is kept, and the sweeper (retention; 0 = off, refused in production).
     */
    RECHARGE_AGENT_ACTIVATION_MIN_COINS: intSetting(30_000_000, 1),
    RECHARGE_AGENT_PRICE_TIERS: z
      .string()
      .trim()
      .default('0:1200,100000000:1195,300000000:1190')
      .refine((v) => /^0:[1-9][0-9]{0,6}(,[1-9][0-9]{0,14}:[1-9][0-9]{0,6})*$/.test(v), {
        message: 'must be minCoins:minorPerMillion pairs, the first from 0, e.g. 0:1200,100000000:1195',
      })
      .transform((v) =>
        v.split(',').map((pair) => {
          const [minCoins, minor] = pair.split(':');
          return { minCoins: Number(minCoins), minorPerMillion: Number(minor) };
        }),
      )
      .refine((tiers) => tiers.every((t, i) => i === 0 || t.minCoins > tiers[i - 1]!.minCoins), {
        message: 'tiers must be in increasing order of minCoins',
      }),
    RECHARGE_AGENT_CHERRY_RATE: z
      .string()
      .trim()
      .default('1000000:93220')
      .refine((v) => /^[1-9][0-9]{0,12}:[1-9][0-9]{0,12}$/.test(v), {
        message: 'must be cherries:coins, e.g. 1000000:93220',
      })
      .transform((v) => {
        const [cherries, coins] = v.split(':');
        return { cherries: Number(cherries), coins: Number(coins) };
      }),
    RECHARGE_AGENT_CHERRY_MIN: intSetting(1_000_000, 1),
    RECHARGE_AGENT_CHERRY_STEP: intSetting(100_000, 1),
    RECHARGE_AGENT_CHERRY_REQUEST_TTL_MINUTES: intSetting(30, 1, 10_080),
    // Owner (D185 follow-up, «حد وكيل مفتوح»): 0 = no daily cap (the default); a positive value caps every
    // agent without their own cap (`recharge-admin set-cap`).
    RECHARGE_AGENT_CHERRY_DAILY_CAP: intSetting(0, 0),
    RECHARGE_AGENT_MAX_EMPLOYEES: intSetting(20, 0, 1000),
    RECHARGE_AGENT_KYC_RETENTION_DAYS: intSetting(90, 1, 3650),
    RECHARGE_AGENT_SWEEP_INTERVAL_SECONDS: intSetting(3600, 0, 86_400),
    /**
     * v1.54-social (D185, §10.48.1): special usernames («يوزر مميز»). After one ends, the name stays reserved
     * for the person this many days (a `coin` name: forever). The sweeper ends expired ones and releases names.
     */
    SPECIAL_USERNAME_GRACE_DAYS: intSetting(30, 1, 3650),
    SPECIAL_USERNAME_SWEEP_INTERVAL_SECONDS: intSetting(300, 0, 86_400),
    /**
     * v1.60-social (D191, CONVENTIONS §10.54): the admin panel. ADMIN_TOTP_KEY is the source of the AES-256-GCM key
     * (HKDF, info `admin-totp/v1`) that encrypts the admins' authenticator secrets; unset = the panel is off (503
     * ADMIN_PANEL_UNAVAILABLE). Changing it makes every enrolled authenticator unreadable (`admin-admin reset-2fa`).
     * In production it must pass the secret-strength checks and differ from the other secrets.
     */
    ADMIN_TOTP_KEY: z
      .string()
      .min(1)
      .refine((v) => Buffer.byteLength(v, 'utf8') >= MIN_SECRET_BYTES, 'must be at least 32 bytes')
      .optional(),
    /** A panel session ends after this long without a request … */
    ADMIN_SESSION_IDLE_SECONDS: intSetting(1800, 60, 86_400),
    /** … and this long after sign-in at the latest. */
    ADMIN_SESSION_MAX_SECONDS: intSetting(28_800, 300, 7 * 86_400),
    /** The second factor (code or enrolment) must follow the password within this. */
    ADMIN_PENDING_SECONDS: intSetting(300, 60, 3600),
    /** Consecutive failed passwords or codes before the admin account locks … */
    ADMIN_LOCKOUT_ATTEMPTS: intSetting(5, 3, 50),
    /** … for this long. */
    ADMIN_LOCKOUT_SECONDS: intSetting(900, 60, 86_400),
    /**
     * v1.56-social (D187, CONVENTIONS §10.50): the daily recharge badges. The minimum coins recharged in one
     * calendar day for each of the five tiers (owner: 1 000 000, 10 000 001, 20 000 001, 40 000 001,
     * 70 000 001 — tier 1 is 1M–10M, tier 2 10.01M–20M …), the zone of that day (owner default Asia/Riyadh)
     * and how long a badge shows from the moment its tier was reached (owner: 24 hours).
     */
    RECHARGE_BADGE_TIERS: z
      .string()
      .trim()
      .default('1000000,10000001,20000001,40000001,70000001')
      .refine((v) => /^[1-9][0-9]{0,14}(,[1-9][0-9]{0,14}){4}$/.test(v), {
        message: 'must be five minimum coin amounts, e.g. 1000000,10000001,20000001,40000001,70000001',
      })
      .transform((v) => v.split(',').map(Number))
      .refine((mins) => mins.every((m, i) => i === 0 || m > mins[i - 1]!), {
        message: 'tiers must be in increasing order',
      }),
    RECHARGE_BADGE_TIME_ZONE: ianaTimeZone('Asia/Riyadh'),
    RECHARGE_BADGE_HOURS: intSetting(24, 1, 168),
    /**
     * v1.59-social (D190, CONVENTIONS §10.53): card top-ups on the Kabso website through Stripe Checkout. Off
     * (every top-up operation answers 503 TOPUP_UNAVAILABLE) until the owner places all three secrets in the
     * server environment: the secret key, the webhook signing secret and the public base URL of the website.
     * Never in git or chat. A test key (`sk_test_`/`rk_test_`) is refused in production unless
     * STRIPE_ALLOW_TEST_KEYS_IN_PRODUCTION=true. Hosted Checkout needs no publishable key.
     */
    STRIPE_SECRET_KEY: z
      .string()
      .trim()
      .regex(/^(sk|rk)_(test|live)_[A-Za-z0-9_]{8,250}$/, 'must be a Stripe secret or restricted key')
      .optional(),
    STRIPE_WEBHOOK_SECRET: z
      .string()
      .trim()
      .regex(/^whsec_[A-Za-z0-9+/=_]{8,250}$/, 'must be a Stripe webhook signing secret (whsec_…)')
      .optional(),
    STRIPE_ALLOW_TEST_KEYS_IN_PRODUCTION: z
      .enum(['true', 'false'], { error: 'must be "true" or "false"' })
      .default('false')
      .transform((v) => v === 'true'),
    /** The website's origin (the API serves `/topup`): Stripe's success / cancel redirects come back here. */
    TOPUP_PUBLIC_BASE_URL: z
      .string()
      .trim()
      .url()
      .refine((v) => /^https?:\/\/[^/?#]+$/.test(v.replace(/\/$/, '')), {
        message: 'must be an origin like https://kabso.live',
      })
      .transform((v) => v.replace(/\/$/, ''))
      .optional(),
    /**
     * The coin packages sold on the website (owner: 100 000 … 50 000 000). Each price is computed on the server
     * from COIN_RETAIL_USD_PER_MILLION (owner $12.50 per 1 000 000) and must be a whole number of cents ≥ 50.
     */
    TOPUP_PACKAGES: z
      .string()
      .trim()
      .default('100000,500000,1000000,5000000,10000000,50000000')
      .refine((v) => /^[1-9][0-9]{0,12}(,[1-9][0-9]{0,12}){0,11}$/.test(v), {
        message: 'must be 1–12 comma-separated coin amounts',
      })
      .transform((v) => v.split(',').map(Number))
      .refine((list) => new Set(list).size === list.length, { message: 'must not repeat an amount' }),
    /**
     * Stripe bank transfers (`customer_balance` with bank-transfer funding instructions: push payments, no
     * chargebacks) offered next to the card (owner CP-033 Q3: on at launch; Kigofi LLC is a US LLC → `us_bank_transfer`).
     */
    STRIPE_BANK_TRANSFER_ENABLED: z
      .enum(['true', 'false'], { error: 'must be "true" or "false"' })
      .default('true')
      .transform((v) => v === 'true'),
    STRIPE_BANK_TRANSFER_TYPE: z
      .enum([
        'us_bank_transfer',
        'eu_bank_transfer',
        'gb_bank_transfer',
        'mx_bank_transfer',
        'jp_bank_transfer',
      ])
      .default('us_bank_transfer'),
    /**
     * Optional dynamic suffix after the account's statement descriptor prefix (the prefix «KABSO LIVE» is set in the
     * Stripe dashboard). Letters, digits and spaces; prefix + suffix ≤ 22 characters.
     */
    STRIPE_STATEMENT_DESCRIPTOR_SUFFIX: z
      .string()
      .trim()
      .regex(/^[A-Za-z0-9 ]{1,10}$/, 'must be 1–10 letters, digits or spaces')
      .optional(),
    /** On `charge.dispute.created` the evidence is submitted to Stripe at once (owner); false = staged only. */
    STRIPE_DISPUTE_AUTO_SUBMIT: z
      .enum(['true', 'false'], { error: 'must be "true" or "false"' })
      .default('true')
      .transform((v) => v === 'true'),
    /**
     * The app's «الشحن من الموقع» link to the website (owner CP-033 Q4: shown; a per-environment switch). When true
     * and top-ups are on, `GET /wallet/recharge-packages` carries `websiteTopupUrl`.
     */
    TOPUP_APP_LINK_ENABLED: z
      .enum(['true', 'false'], { error: 'must be "true" or "false"' })
      .default('true')
      .transform((v) => v === 'true'),
    /** The version of the «العملات رقمية وغير قابلة للاسترداد» statement recorded with every acceptance. */
    TOPUP_TERMS_VERSION: z
      .string()
      .trim()
      .regex(/^[A-Za-z0-9._-]{1,32}$/, 'must be 1–32 letters, digits, dots, dashes or underscores')
      .default('2026-10-31'),
    /**
     * Optional dedicated source of the HMAC key (HKDF, info `social-cursor/v1`) of the v1.5-social
     * list cursors; like LIVE_CURSOR_KEY it falls back to RATE_LIMIT_KEY_SECRET.
     */
    SOCIAL_CURSOR_KEY: z
      .string()
      .min(1)
      .refine((v) => Buffer.byteLength(v, 'utf8') >= MIN_SECRET_BYTES, 'must be at least 32 bytes')
      .optional(),

    /** Pending registration lifetime (contract: 30 min). */
    REGISTRATION_TTL_SECONDS: positiveInt(30 * 60),
    /** Absolute lifetime of a pending registration from creation; resend never extends it (2 h). */
    REGISTRATION_MAX_LIFETIME_SECONDS: positiveInt(2 * 3600),
    /**
     * Optional dedicated key for registration-code HMACs (SEC-029). When unset, the key is derived
     * from RATE_LIMIT_KEY_SECRET. Changing either invalidates every live pending code.
     */
    REGISTRATION_CODE_KEY: z
      .string()
      .min(1)
      .refine((v) => Buffer.byteLength(v, 'utf8') >= MIN_SECRET_BYTES, 'must be at least 32 bytes')
      .optional(),
    /** At most one "account already exists" notice per account per interval (contract: 1 h). */
    REGISTRATION_NOTICE_INTERVAL_SECONDS: positiveInt(3600),
    /** Periodic deletion of expired pending registrations; 0 disables the job. */
    REGISTRATION_CLEANUP_INTERVAL_SECONDS: nonNegativeInt(600),
    /** A source that logged into an account within this window bypasses the account bucket. */
    LOGIN_RECENT_SUCCESS_TTL_SECONDS: positiveInt(30 * 24 * 3600),
    /**
     * Reserved display-name terms (comma-separated; matched after NFKC casefold + confusable
     * skeleton). Defaults to the CONVENTIONS §6 list (v1.2.4: without `staff` and `مشرف`, QA-012; v1.2.6: without `رسمي`, SEC-032).
     */
    /** Brand terms also matched as a prefix/suffix of the separator-free name (v1.2.1). */
    RESERVED_DISPLAY_NAME_BRAND_TERMS: z
      .string()
      .default('kabso,كابسو')
      .transform((v) =>
        v
          .split(',')
          .map((t) => t.trim())
          .filter(Boolean),
      ),
    RESERVED_DISPLAY_NAME_TERMS: z
      .string()
      .default('kabso,admin,administrator,support,official,moderator,كابسو,الدعم,الإدارة')
      .transform((v) =>
        v
          .split(',')
          .map((t) => t.trim())
          .filter(Boolean),
      ),

    /** Concurrent Argon2 operations per process (SEC-002); default = available CPUs. */
    ARGON2_MAX_CONCURRENCY: intSetting(Math.min(availableParallelism(), 256), 1, 256),
    /** Operations allowed to wait for a slot; beyond this → 503 SERVICE_UNAVAILABLE. */
    ARGON2_MAX_QUEUE: nonNegativeInt(availableParallelism() * 4),
  })
  .superRefine((env, ctx) => {
    // v1.27-live (D132): the lucky-gift table must be valid whether or not lucky gifts are on.
    if (env.LUCKY_GIFT_RTP_SHARES !== undefined) {
      ctx.addIssue({
        code: 'custom',
        path: ['LUCKY_GIFT_RTP_SHARES'],
        message: 'was replaced by LUCKY_GIFT_CHANCES_PER_MILLION (D148); remove it',
      });
    }
    const lucky = luckyTable(
      env.LUCKY_GIFT_RTP_PERCENT,
      env.LUCKY_GIFT_HOST_SHARE_PERCENT,
      env.LUCKY_GIFT_MULTIPLIERS,
      env.LUCKY_GIFT_CHANCES_PER_MILLION,
      luckyPityOf(env),
    );
    if (Array.isArray(lucky)) {
      for (const problem of lucky) {
        ctx.addIssue({ code: 'custom', path: ['LUCKY_GIFT_MULTIPLIERS'], message: problem });
      }
    } else if (!env.LUCKY_GIFT_MULTIPLIERS.includes(env.LUCKY_GIFT_BIG_WIN_MULTIPLIER)) {
      ctx.addIssue({
        code: 'custom',
        path: ['LUCKY_GIFT_BIG_WIN_MULTIPLIER'],
        message: 'must be one of LUCKY_GIFT_MULTIPLIERS',
      });
    }
    if (env.LUCKY_GIFTS_DISABLED_COUNTRIES.length > 0 && env.LUCKY_GIFTS_COUNTRY_HEADER === undefined) {
      ctx.addIssue({
        code: 'custom',
        path: ['LUCKY_GIFTS_COUNTRY_HEADER'],
        message: 'is required when LUCKY_GIFTS_DISABLED_COUNTRIES is set (the edge country decides)',
      });
    }
    if (env.REFRESH_ABSOLUTE_TTL_SECONDS < env.REFRESH_TTL_SECONDS) {
      ctx.addIssue({
        code: 'custom',
        path: ['REFRESH_ABSOLUTE_TTL_SECONDS'],
        message: 'must be >= REFRESH_TTL_SECONDS',
      });
    }
    if (env.LIVE_HEARTBEAT_STALE_SECONDS < 2 * env.LIVE_HEARTBEAT_INTERVAL_SECONDS) {
      ctx.addIssue({
        code: 'custom',
        path: ['LIVE_HEARTBEAT_STALE_SECONDS'],
        message: 'must be at least 2 × LIVE_HEARTBEAT_INTERVAL_SECONDS',
      });
    }
    if (env.LIVE_HOSTING_ENABLED) {
      for (const key of ['LIVEKIT_URL', 'LIVEKIT_API_KEY', 'LIVEKIT_API_SECRET'] as const) {
        if (env[key] === undefined) {
          ctx.addIssue({
            code: 'custom',
            path: [key],
            message: 'is required when LIVE_HOSTING_ENABLED=true',
          });
        }
      }
    }
    if (env.MAIL_TRANSPORT === 'smtp') {
      for (const key of ['MAIL_FROM', 'SMTP_HOST', 'SMTP_USER', 'SMTP_PASSWORD'] as const) {
        if (env[key] === undefined) {
          ctx.addIssue({ code: 'custom', path: [key], message: 'is required when MAIL_TRANSPORT=smtp' });
        }
      }
      if (
        env.MAIL_FROM !== undefined &&
        !/^(?:[^<>@]*<[^\s<>@]+@[^\s<>@]+\.[^\s<>@]+>|[^\s<>@]+@[^\s<>@]+\.[^\s<>@]+)$/.test(env.MAIL_FROM)
      ) {
        ctx.addIssue({
          code: 'custom',
          path: ['MAIL_FROM'],
          message: 'must be an address or "Name <address>"',
        });
      }
    }
    if (env.MEDIA_UPLOADS_ENABLED) {
      for (const key of [
        'S3_BUCKET',
        'S3_ACCESS_KEY_ID',
        'S3_SECRET_ACCESS_KEY',
        'MEDIA_PUBLIC_BASE_URL',
      ] as const) {
        if (env[key] === undefined) {
          ctx.addIssue({
            code: 'custom',
            path: [key],
            message: 'is required when MEDIA_UPLOADS_ENABLED=true',
          });
        }
      }
    }
    // v1.59-social (D190): card top-ups are all or nothing (a key without the webhook secret would take payments
    // that are never credited).
    {
      const topupKeys = ['STRIPE_SECRET_KEY', 'STRIPE_WEBHOOK_SECRET', 'TOPUP_PUBLIC_BASE_URL'] as const;
      const set = topupKeys.filter((k) => env[k] !== undefined);
      if (set.length > 0 && set.length < topupKeys.length) {
        for (const key of topupKeys.filter((k) => env[k] === undefined)) {
          ctx.addIssue({
            code: 'custom',
            path: [key],
            message: `is required when ${set.join(', ')} is set (card top-ups need all three)`,
          });
        }
      }
      const minorPerMillion = topupMinorPerMillion(env.COIN_RETAIL_USD_PER_MILLION);
      if (minorPerMillion === null) {
        if (set.length > 0) {
          ctx.addIssue({
            code: 'custom',
            path: ['COIN_RETAIL_USD_PER_MILLION'],
            message: 'must be a whole number of cents per 1 000 000 coins when card top-ups are on',
          });
        }
      } else if (set.length > 0) {
        // Only when card top-ups are on: COIN_RETAIL_USD_PER_MILLION also prices task rewards (D188).
        for (const coins of env.TOPUP_PACKAGES) {
          const minor = (coins * minorPerMillion) / 1_000_000;
          if (!Number.isInteger(minor) || minor < 50) {
            ctx.addIssue({
              code: 'custom',
              path: ['TOPUP_PACKAGES'],
              message: `${coins} coins cost ${minor} cents: each package must cost a whole number of cents, at least 50`,
            });
          }
        }
      }
    }
    if (env.NODE_ENV === 'production') {
      if (env.LIVEKIT_URL !== undefined && !env.LIVEKIT_URL.startsWith('wss://')) {
        ctx.addIssue({ code: 'custom', path: ['LIVEKIT_URL'], message: 'must use wss in production' });
      }
      if (env.STRIPE_SECRET_KEY !== undefined && /^(sk|rk)_test_/.test(env.STRIPE_SECRET_KEY)) {
        if (!env.STRIPE_ALLOW_TEST_KEYS_IN_PRODUCTION) {
          ctx.addIssue({
            code: 'custom',
            path: ['STRIPE_SECRET_KEY'],
            message:
              'a Stripe TEST key is refused in production (set STRIPE_ALLOW_TEST_KEYS_IN_PRODUCTION=true only for a ' +
              'staging server that must not take real money)',
          });
        }
      }
      if (env.TOPUP_PUBLIC_BASE_URL !== undefined && !env.TOPUP_PUBLIC_BASE_URL.startsWith('https://')) {
        ctx.addIssue({
          code: 'custom',
          path: ['TOPUP_PUBLIC_BASE_URL'],
          message: 'must use https in production',
        });
      }
      if (env.LIVEKIT_API_SECRET !== undefined) {
        const problem = productionSecretProblem(env.LIVEKIT_API_SECRET);
        if (problem) ctx.addIssue({ code: 'custom', path: ['LIVEKIT_API_SECRET'], message: problem });
      }
      for (const key of ['S3_ENDPOINT', 'MEDIA_PUBLIC_BASE_URL'] as const) {
        const value = env[key];
        if (value !== undefined && !value.startsWith('https://')) {
          ctx.addIssue({ code: 'custom', path: [key], message: 'must use https in production' });
        }
      }
      if (env.MEDIA_SWEEP_INTERVAL_SECONDS === 0) {
        ctx.addIssue({
          code: 'custom',
          path: ['MEDIA_SWEEP_INTERVAL_SECONDS'],
          message: 'the media sweeper cannot be disabled in production',
        });
      }
      if (env.POSTS_PUBLISH_INTERVAL_SECONDS === 0) {
        ctx.addIssue({
          code: 'custom',
          path: ['POSTS_PUBLISH_INTERVAL_SECONDS'],
          message: 'the scheduled-post publisher cannot be disabled in production',
        });
      }
      if (env.PREMIUM_USERNAME_SWEEP_INTERVAL_SECONDS === 0) {
        ctx.addIssue({
          code: 'custom',
          path: ['PREMIUM_USERNAME_SWEEP_INTERVAL_SECONDS'],
          message: 'the premium username sweeper cannot be disabled in production',
        });
      }
      if (env.BONDS_SWEEP_INTERVAL_SECONDS === 0) {
        ctx.addIssue({
          code: 'custom',
          path: ['BONDS_SWEEP_INTERVAL_SECONDS'],
          message: 'the family and CP request sweeper cannot be disabled in production',
        });
      }
      if (env.NOTIFICATIONS_SWEEP_INTERVAL_SECONDS === 0) {
        ctx.addIssue({
          code: 'custom',
          path: ['NOTIFICATIONS_SWEEP_INTERVAL_SECONDS'],
          message: 'the notifications sweeper cannot be disabled in production',
        });
      }
      // D185: rejected applications' private data must be deleted on time (retention).
      if (env.RECHARGE_AGENT_SWEEP_INTERVAL_SECONDS === 0) {
        ctx.addIssue({
          code: 'custom',
          path: ['RECHARGE_AGENT_SWEEP_INTERVAL_SECONDS'],
          message: 'the recharge-agent sweeper (KYC retention) cannot be disabled in production',
        });
      }
      // D185: an expired special username must give the person's own username back on time.
      if (env.SPECIAL_USERNAME_SWEEP_INTERVAL_SECONDS === 0) {
        ctx.addIssue({
          code: 'custom',
          path: ['SPECIAL_USERNAME_SWEEP_INTERVAL_SECONDS'],
          message: 'the special-username sweeper cannot be disabled in production',
        });
      }
      // D179: agency ranks must be re-evaluated at each month start.
      if (env.AGENCY_SWEEP_INTERVAL_SECONDS === 0) {
        ctx.addIssue({
          code: 'custom',
          path: ['AGENCY_SWEEP_INTERVAL_SECONDS'],
          message: 'the agency sweeper (monthly rank evaluation) cannot be disabled in production',
        });
      }
      // D166: ended events must be frozen and their prizes paid.
      if (env.EVENTS_SWEEP_INTERVAL_SECONDS === 0) {
        ctx.addIssue({
          code: 'custom',
          path: ['EVENTS_SWEEP_INTERVAL_SECONDS'],
          message: 'the event sweeper (leaderboard freeze and prize payout) cannot be disabled in production',
        });
      }
      // D155 (owner): direct messages must really disappear after DM_RETENTION_HOURS.
      if (env.DM_SWEEP_INTERVAL_SECONDS === 0) {
        ctx.addIssue({
          code: 'custom',
          path: ['DM_SWEEP_INTERVAL_SECONDS'],
          message: 'the direct-message sweeper cannot be disabled in production',
        });
      }
      if (env.SOCIAL_CURSOR_KEY !== undefined) {
        const problem = productionSecretProblem(env.SOCIAL_CURSOR_KEY);
        if (problem) ctx.addIssue({ code: 'custom', path: ['SOCIAL_CURSOR_KEY'], message: problem });
      }
      const jwtProblem = productionSecretProblem(env.JWT_ACCESS_SECRET);
      if (jwtProblem) ctx.addIssue({ code: 'custom', path: ['JWT_ACCESS_SECRET'], message: jwtProblem });

      if (env.RATE_LIMIT_KEY_SECRET === undefined) {
        ctx.addIssue({
          code: 'custom',
          path: ['RATE_LIMIT_KEY_SECRET'],
          message: 'is required in production',
        });
      } else {
        const rlProblem = productionSecretProblem(env.RATE_LIMIT_KEY_SECRET);
        if (rlProblem) ctx.addIssue({ code: 'custom', path: ['RATE_LIMIT_KEY_SECRET'], message: rlProblem });
        else if (env.RATE_LIMIT_KEY_SECRET === env.JWT_ACCESS_SECRET) {
          ctx.addIssue({
            code: 'custom',
            path: ['RATE_LIMIT_KEY_SECRET'],
            message: 'must differ from JWT_ACCESS_SECRET',
          });
        }
      }

      if (env.REGISTRATION_CODE_KEY !== undefined) {
        const codeKeyProblem = productionSecretProblem(env.REGISTRATION_CODE_KEY);
        if (codeKeyProblem) {
          ctx.addIssue({ code: 'custom', path: ['REGISTRATION_CODE_KEY'], message: codeKeyProblem });
        } else if ([env.JWT_ACCESS_SECRET, env.RATE_LIMIT_KEY_SECRET].includes(env.REGISTRATION_CODE_KEY)) {
          ctx.addIssue({
            code: 'custom',
            path: ['REGISTRATION_CODE_KEY'],
            message: 'must differ from JWT_ACCESS_SECRET and RATE_LIMIT_KEY_SECRET',
          });
        }
      }
      if (env.ADMIN_TOTP_KEY !== undefined) {
        const adminKeyProblem = productionSecretProblem(env.ADMIN_TOTP_KEY);
        if (adminKeyProblem) {
          ctx.addIssue({ code: 'custom', path: ['ADMIN_TOTP_KEY'], message: adminKeyProblem });
        } else if (
          [env.JWT_ACCESS_SECRET, env.RATE_LIMIT_KEY_SECRET, env.REGISTRATION_CODE_KEY].includes(
            env.ADMIN_TOTP_KEY,
          )
        ) {
          ctx.addIssue({
            code: 'custom',
            path: ['ADMIN_TOTP_KEY'],
            message: 'must differ from JWT_ACCESS_SECRET, RATE_LIMIT_KEY_SECRET and REGISTRATION_CODE_KEY',
          });
        }
      }
      if (env.LIVE_CURSOR_KEY !== undefined) {
        const cursorKeyProblem = productionSecretProblem(env.LIVE_CURSOR_KEY);
        if (cursorKeyProblem) {
          ctx.addIssue({ code: 'custom', path: ['LIVE_CURSOR_KEY'], message: cursorKeyProblem });
        } else if (
          [env.JWT_ACCESS_SECRET, env.RATE_LIMIT_KEY_SECRET, env.REGISTRATION_CODE_KEY].includes(
            env.LIVE_CURSOR_KEY,
          )
        ) {
          ctx.addIssue({
            code: 'custom',
            path: ['LIVE_CURSOR_KEY'],
            message: 'must differ from JWT_ACCESS_SECRET, RATE_LIMIT_KEY_SECRET and REGISTRATION_CODE_KEY',
          });
        }
      }
      // Heartbeat headroom (KL-040 observation): a short cadence with the default bucket would
      // leave no room for retries and end live rooms with 429s.
      const beat = env.RATE_LIMIT_LIVE_HEARTBEAT_USER;
      const expected = Math.ceil(beat.windowSeconds / env.LIVE_HEARTBEAT_INTERVAL_SECONDS);
      if (beat.max < HEARTBEAT_RATE_LIMIT_HEADROOM * expected) {
        ctx.addIssue({
          code: 'custom',
          path: ['RATE_LIMIT_LIVE_HEARTBEAT_USER'],
          message:
            `allows ${beat.max} per ${beat.windowSeconds} s, but a ${env.LIVE_HEARTBEAT_INTERVAL_SECONDS} s ` +
            `heartbeat cadence needs at least ${HEARTBEAT_RATE_LIMIT_HEADROOM * expected} ` +
            `(${HEARTBEAT_RATE_LIMIT_HEADROOM}× headroom for retries)`,
        });
      }
      if (env.LIVE_SWEEP_INTERVAL_SECONDS === 0) {
        ctx.addIssue({
          code: 'custom',
          path: ['LIVE_SWEEP_INTERVAL_SECONDS'],
          message: 'the stale-room sweeper cannot be disabled in production',
        });
      }
      // SEC-003a: hop counts above 3 and overly broad ranges trust client-supplied headers.
      if (typeof env.TRUST_PROXY === 'number' && env.TRUST_PROXY > 3) {
        ctx.addIssue({
          code: 'custom',
          path: ['TRUST_PROXY'],
          message: 'hop counts greater than 3 are refused in production',
        });
      }
      if (Array.isArray(env.TRUST_PROXY)) {
        const tooBroad = env.TRUST_PROXY.filter(isOverlyBroadProxyRange);
        if (tooBroad.length > 0) {
          ctx.addIssue({
            code: 'custom',
            path: ['TRUST_PROXY'],
            message:
              'ranges broader than IPv4 /8 or IPv6 /32 (incl. ::ffff:0:0/96) trust client-supplied ' +
              `headers and are refused in production: ${tooBroad.join(', ')}`,
          });
        }
      }
      if (env.TRUST_PROXY === true) {
        ctx.addIssue({
          code: 'custom',
          path: ['TRUST_PROXY'],
          message:
            '"true" trusts the client-controlled X-Forwarded-For and is refused in production; ' +
            'set the exact proxy hop count (e.g. 1) or the proxy addresses/CIDRs',
        });
      }
      if (env.MAIL_TRANSPORT === 'log') {
        ctx.addIssue({
          code: 'custom',
          path: ['MAIL_TRANSPORT'],
          message:
            '"log" is a development transport (it writes token links to logs) and is refused in ' +
            'production; use MAIL_TRANSPORT=smtp with the SMTP_* settings (KL-042)',
        });
      }
    }
  });

export type Env = z.output<typeof envSchema>;
