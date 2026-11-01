import { z } from 'zod';
import { GIFT_ASSET_KEY_PATTERN, GIFT_CODE_PATTERN } from '../gifts/gift-catalogue.js';
import { EVENT_METRICS, EVENT_TONES } from '../programs/event-admin-rules.js';
import { PANEL_ROLES } from './admin-permissions.js';
import { dayRange, tableQuery } from './admin-tables.js';

/** Request bodies and queries of the panel v2 (v1.65-social, D197, CONVENTIONS §10.60; openapi tag `admin-panel`). */

const reason = z.string().trim().min(1).max(500);
const totpCode = z.string().regex(/^[0-9]{6}$/);
const uuid = z
  .string()
  .regex(/^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$/);

export const reasonBody = z.strictObject({ reason });

export const statsSeriesQuery = z.strictObject({
  days: z
    .enum(['7', '30', '90'])
    .default('30')
    .transform((v) => Number(v) as 7 | 30 | 90),
});

export const searchQuery = z.strictObject({ q: z.string().trim().min(1).max(254) });

export const pageOnlyQuery = z.strictObject({
  page: z.coerce.number().int().min(1).max(100_000).default(1),
  pageSize: z.coerce.number().int().min(1).max(100).default(25),
});

export const ledgerQuery = pageOnlyQuery.extend({ kind: z.enum(['coins', 'cherries']).default('coins') });

export const usersTableQuery = tableQuery(['createdAt', 'lastActiveAt', 'username', 'email'], 'createdAt')
  .extend({
    status: z.enum(['ACTIVE', 'SUSPENDED', 'DELETED']).optional(),
    role: z.enum(['USER', 'ADMIN']).optional(),
  })
  .strict();

export const revokeSessionsBody = z.strictObject({ sessionId: uuid.optional(), reason });

export const agenciesQuery = tableQuery(['createdAt', 'inviteCode', 'rank'], 'createdAt')
  .extend({
    rank: z.enum(['NEW', 'AGENT', 'ADMIN', 'LAPSED']).optional(),
    // v1.70-social (D206): `probation` (a running probation), `closed`; `origin` who made it.
    state: z.enum(['active', 'suspended', 'probation', 'closed']).optional(),
    origin: z.enum(['ADMIN', 'SELF']).optional(),
  })
  .strict();

/** v1.70-social (D206, §10.65): the probation / closing / reopening of an agency (OWNER, authenticator code again). */
export const agencyProbationExtendBody = z.strictObject({
  days: z.number().int().min(1).max(90),
  reason,
  totpCode,
});
export const reasonTotpBody = z.strictObject({ reason, totpCode });

export const createAgencyBody = z
  .strictObject({
    ownerUserId: uuid.optional(),
    ownerEmail: z.string().trim().min(3).max(254).optional(),
    parentInviteCode: z.string().trim().min(1).max(12).optional(),
    reason,
  })
  .refine((v) => (v.ownerUserId === undefined) !== (v.ownerEmail === undefined), {
    message: 'exactly one of ownerUserId or ownerEmail',
    path: ['ownerUserId'],
  });

export const complaintsQuery = tableQuery(['createdAt'], 'createdAt')
  .extend({ status: z.enum(['OPEN', 'RESOLVED', 'REJECTED']).default('OPEN') })
  .strict();

export const resolveComplaintBody = z
  .strictObject({
    decision: z.enum(['release', 'keep', 'move']),
    toInviteCode: z.string().trim().min(1).max(12).optional(),
    note: reason,
  })
  .refine((v) => v.decision !== 'move' || v.toInviteCode !== undefined, {
    message: 'move needs toInviteCode',
    path: ['toInviteCode'],
  });

export const livesQuery = tableQuery(['viewers', 'startedAt'], 'viewers').strict();

export const hostsQuery = tableQuery(['grantedAt'], 'grantedAt')
  .extend({ source: z.enum(['ADMIN', 'AGENCY', 'IDENTITY']).optional() })
  .strict();

export const hostBody = z.strictObject({ username: z.string().trim().min(1).max(31), reason });

const name = z.string().trim().min(1).max(60);
const assetKey = z.string().regex(GIFT_ASSET_KEY_PATTERN);
const giftFields = {
  category: z.enum(['POPULAR', 'EVENT', 'FUN', 'LUCKY', 'QUIPS']),
  nameAr: name,
  nameEn: name,
  priceCoins: z.number().int().min(0).max(1_000_000),
  assetKey,
  animationKey: assetKey.nullable(),
  sortOrder: z.number().int().min(-100_000).max(100_000),
  badge: z.enum(['NONE', 'NEW', 'EVENT']),
  tagCode: z
    .string()
    .regex(/^[a-z0-9][a-z0-9_]{0,39}$/)
    .nullable(),
  tagNameAr: z.string().trim().min(1).max(30).nullable(),
  tagNameEn: z.string().trim().min(1).max(30).nullable(),
  soundKey: assetKey.nullable(),
  soundMs: z.number().int().min(200).max(15_000).nullable(),
  quipText: z.string().trim().min(1).max(200).nullable(),
};

export const createGiftBody = z.strictObject({
  code: z.string().regex(GIFT_CODE_PATTERN),
  category: giftFields.category,
  nameAr: giftFields.nameAr,
  nameEn: giftFields.nameEn,
  priceCoins: giftFields.priceCoins,
  assetKey: giftFields.assetKey,
  animationKey: giftFields.animationKey.optional(),
  sortOrder: giftFields.sortOrder.optional(),
  badge: giftFields.badge.optional(),
  tagCode: giftFields.tagCode.optional(),
  tagNameAr: giftFields.tagNameAr.optional(),
  tagNameEn: giftFields.tagNameEn.optional(),
  soundKey: giftFields.soundKey.optional(),
  soundMs: giftFields.soundMs.optional(),
  quipText: giftFields.quipText.optional(),
  reason,
});

export const updateGiftBody = z
  .strictObject({
    category: giftFields.category.optional(),
    nameAr: giftFields.nameAr.optional(),
    nameEn: giftFields.nameEn.optional(),
    priceCoins: giftFields.priceCoins.optional(),
    assetKey: giftFields.assetKey.optional(),
    animationKey: giftFields.animationKey.optional(),
    sortOrder: giftFields.sortOrder.optional(),
    badge: giftFields.badge.optional(),
    tagCode: giftFields.tagCode.optional(),
    tagNameAr: giftFields.tagNameAr.optional(),
    tagNameEn: giftFields.tagNameEn.optional(),
    soundKey: giftFields.soundKey.optional(),
    soundMs: giftFields.soundMs.optional(),
    quipText: giftFields.quipText.optional(),
    reason,
  })
  .refine((v) => Object.keys(v).length > 1, { message: 'nothing to change', path: ['reason'] });

export const bagGrantBody = z.strictObject({
  code: z.string().trim().min(1).max(40),
  /** 1–3650 days, or null for ever. */
  days: z.number().int().min(1).max(3650).nullable(),
  reason,
});

export const bagRevokeBody = z.strictObject({ code: z.string().trim().min(1).max(40), reason });

const isoTime = z.string().datetime({ offset: true });
export const createEventBody = z.strictObject({
  titleAr: z.string().trim().min(1).max(120),
  titleEn: z.string().trim().min(1).max(120),
  rulesAr: z.string().trim().max(4000).optional(),
  rulesEn: z.string().trim().max(4000).optional(),
  startsAt: isoTime,
  endsAt: isoTime.nullable().optional(),
  permanent: z.boolean().optional(),
  metric: z.enum(EVENT_METRICS as unknown as [string, ...string[]]),
  audience: z.enum(['EVERYONE', 'HOSTS']).optional(),
  regions: z
    .array(z.string().regex(/^[A-Za-z]{2}$/))
    .max(50)
    .optional(),
  featured: z.boolean().optional(),
  bannerUrl: z
    .string()
    .regex(/^https:\/\/\S{1,2000}$/)
    .max(2048)
    .nullable()
    .optional(),
  prizes: z.string().trim().max(500).optional(),
  summaryAr: z.string().trim().max(80).nullable().optional(),
  summaryEn: z.string().trim().max(80).nullable().optional(),
  tone: z.enum(EVENT_TONES).nullable().optional(),
  reason,
});

export const rangeTableQuery = (sorts: readonly [string, ...string[]], def: string) =>
  tableQuery(sorts, def).extend(dayRange);

export const rechargeTopupsQuery = rangeTableQuery(['createdAt', 'paidMinor', 'coins'], 'createdAt').strict();

export const cardOrdersQuery = rangeTableQuery(['createdAt', 'amountMinor'], 'createdAt')
  .extend({ status: z.enum(['PENDING', 'AWAITING_FUNDS', 'PAID', 'EXPIRED', 'FAILED']).optional() })
  .strict();

export const casesQuery = tableQuery(['createdAt'], 'createdAt')
  .extend({ status: z.enum(['OPEN', 'CLOSED']).optional() })
  .strict();

export const refundBody = z.strictObject({ reason, totpCode });
export const closeCaseBody = z.strictObject({ note: reason });

export const reportQuery = z
  .strictObject({
    granularity: z.enum(['day', 'month']).default('day'),
    from: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
    to: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
    format: z.enum(['json', 'csv']).default('json'),
  })
  .refine((v) => v.from <= v.to, { message: 'from after to', path: ['from'] })
  .refine(
    (v) => {
      const days = (Date.parse(`${v.to}T00:00:00Z`) - Date.parse(`${v.from}T00:00:00Z`)) / 86_400_000;
      return days <= (v.granularity === 'day' ? 400 : 1100);
    },
    { message: 'range too long', path: ['to'] },
  );

export const auditQuery = rangeTableQuery(['createdAt'], 'createdAt')
  .extend({
    actor: z.string().trim().min(1).max(64).optional(),
    action: z.string().trim().min(1).max(64).optional(),
    targetType: z.string().trim().min(1).max(32).optional(),
    targetId: z.string().trim().min(1).max(64).optional(),
  })
  .strict();

const role = z.enum(PANEL_ROLES);
export const teamGrantBody = z.strictObject({
  email: z.string().trim().min(3).max(254),
  role,
  reason,
  totpCode,
});
export const teamRevokeBody = z.strictObject({ role, reason, totpCode });
export const teamResetBody = z.strictObject({ reason, totpCode });

export const specialUsernamesQuery = tableQuery(['grantedAt', 'username'], 'grantedAt')
  .extend({
    status: z.enum(['ACTIVE', 'GRACE', 'ENDED']).optional(),
    source: z.enum(['RECHARGE_AGENT', 'ADMIN_GIFT', 'PURCHASE', 'HOST_AGENT']).optional(),
  })
  .strict();

export const waitlistQuery = tableQuery(['createdAt'], 'createdAt')
  .extend({ locale: z.enum(['ar', 'en']).optional() })
  .strict();
