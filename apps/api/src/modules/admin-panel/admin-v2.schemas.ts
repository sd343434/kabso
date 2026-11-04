import { z } from 'zod';
import {
  GIFT_ANIMATION_OBJECT_KEY_PATTERN,
  GIFT_AUDIO_OBJECT_KEY_PATTERN,
  GIFT_IMAGE_OBJECT_KEY_PATTERN,
} from '../gifts/gift-art.js';
import {
  GIFT_ASSET_KEY_PATTERN,
  GIFT_CATEGORY_CODE_PATTERN,
  GIFT_CODE_PATTERN,
} from '../gifts/gift-catalogue.js';
import { GIFT_CATEGORY_ICON_KEY_PATTERN } from '../gifts/gift-categories.js';
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

/** v1.47-live (D212): `mode` filters the lives on air by mode (the app's five categories). v1.54-live (D241): `PK` = in an open
 * D195 match (or the legacy mode PK); `SOLO` = SOLO not in a PK. */
export const livesQuery = tableQuery(['viewers', 'startedAt'], 'viewers')
  .extend({
    mode: z.enum(['SOLO', 'PK', 'MULTI', 'AUDIO', 'PODCAST', 'STREAMER']).optional(),
    // v1.60-live (D250, §10.91.2): «لايفات مبلّغ عنها» — only the lives with open reports.
    reported: z
      .enum(['true', 'false'])
      .optional()
      .transform((v) => v === 'true'),
    // v1.64-live (D260, §10.96): «بثوثي» — only the lives assigned to the signed-in staff member.
    assigned: z.enum(['me']).optional(),
  })
  .strict();

export const hostsQuery = tableQuery(['grantedAt'], 'grantedAt')
  .extend({ source: z.enum(['ADMIN', 'AGENCY', 'IDENTITY']).optional() })
  .strict();

export const hostBody = z.strictObject({ username: z.string().trim().min(1).max(31), reason });

const name = z.string().trim().min(1).max(60);
const assetKey = z.string().regex(GIFT_ASSET_KEY_PATTERN);
const giftFields = {
  // v1.71-social (D207): any category code (gift_categories); the rule checks that it exists.
  category: z.string().regex(GIFT_CATEGORY_CODE_PATTERN),
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
  // v1.71-social (D207): files uploaded with `POST /admin/gift-uploads` (keys it answered), or null to remove.
  imageObjectKey: z.string().regex(GIFT_IMAGE_OBJECT_KEY_PATTERN).nullable(),
  animationObjectKey: z.string().regex(GIFT_ANIMATION_OBJECT_KEY_PATTERN).nullable(),
  animationAlpha: z.enum(['NONE', 'SIDE_BY_SIDE']),
  audioObjectKey: z.string().regex(GIFT_AUDIO_OBJECT_KEY_PATTERN).nullable(),
};

export const createGiftBody = z.strictObject({
  code: z.string().regex(GIFT_CODE_PATTERN),
  category: giftFields.category,
  nameAr: giftFields.nameAr,
  nameEn: giftFields.nameEn,
  priceCoins: giftFields.priceCoins,
  // v1.71-social (D207): the bundled image key is optional now (default: the gift's code); «صورة الهدية» is required.
  assetKey: giftFields.assetKey.optional(),
  imageObjectKey: giftFields.imageObjectKey.unwrap(),
  animationObjectKey: giftFields.animationObjectKey.optional(),
  animationAlpha: giftFields.animationAlpha.optional(),
  audioObjectKey: giftFields.audioObjectKey.optional(),
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
    imageObjectKey: giftFields.imageObjectKey.optional(),
    animationObjectKey: giftFields.animationObjectKey.optional(),
    animationAlpha: giftFields.animationAlpha.optional(),
    audioObjectKey: giftFields.audioObjectKey.optional(),
    reason,
  })
  .refine((v) => Object.keys(v).length > 1, { message: 'nothing to change', path: ['reason'] });

// ---- v1.71-social (D207, CONVENTIONS §10.66): gift categories and uploads -------------------------------------

const categoryName = z.string().trim().min(1).max(30);
const categorySort = z.number().int().min(0).max(1_000_000);
const categoryIcon = z.string().regex(GIFT_CATEGORY_ICON_KEY_PATTERN).nullable();

export const createGiftCategoryBody = z.strictObject({
  code: z.string().regex(GIFT_CATEGORY_CODE_PATTERN),
  nameAr: categoryName,
  nameEn: categoryName,
  sortOrder: categorySort.optional(),
  enabled: z.boolean().optional(),
  iconObjectKey: categoryIcon.optional(),
  reason,
});

export const updateGiftCategoryBody = z
  .strictObject({
    nameAr: categoryName.optional(),
    nameEn: categoryName.optional(),
    sortOrder: categorySort.optional(),
    iconObjectKey: categoryIcon.optional(),
    reason,
  })
  .refine((v) => Object.keys(v).length > 1, { message: 'nothing to change', path: ['reason'] });

export const removeGiftCategoryBody = z.strictObject({
  /** Move the category's gifts to this NORMAL category first (required while it has gifts). */
  moveTo: z.string().regex(GIFT_CATEGORY_CODE_PATTERN).optional(),
  reason,
});

/** v1.71-social (D207): a stored gift file or category icon, read back for the panel's preview (same origin). */
export const giftFileQuery = z.strictObject({
  key: z
    .string()
    .max(200)
    .refine(
      (k) =>
        GIFT_IMAGE_OBJECT_KEY_PATTERN.test(k) ||
        GIFT_ANIMATION_OBJECT_KEY_PATTERN.test(k) ||
        GIFT_AUDIO_OBJECT_KEY_PATTERN.test(k) ||
        GIFT_CATEGORY_ICON_KEY_PATTERN.test(k),
      { message: 'not a gift file key' },
    ),
});

export const giftUploadQuery = z.strictObject({
  /** image: «صورة الهدية»; animation: SVGA or MP4 «ملف العرض»; sound: MP3; icon: a category's icon. */
  kind: z.enum(['image', 'animation', 'sound', 'icon']),
  /** The gift's code (image, animation, sound) or the category's (icon): the files' folder. */
  code: z.string().min(1).max(40),
});

export const bagGrantBody = z.strictObject({
  code: z.string().trim().min(1).max(40),
  /** 1–3650 days, or null for ever. */
  days: z.number().int().min(1).max(3650).nullable(),
  reason,
});

export const bagRevokeBody = z.strictObject({ code: z.string().trim().min(1).max(40), reason });

const isoTime = z.string().datetime({ offset: true });
/** v1.59-live (D248, §10.90): where a banner uploaded or added from the panel is shown (the picture's shape). */
export const bannerPlacementParam = z.enum(['home', 'room', 'tasks', 'wallet', 'hub_card']);
export type BannerPlacementParam = z.infer<typeof bannerPlacementParam>;

/** v1.59-live (D248): `POST /admin/banner-uploads?placement=`. */
export const bannerUploadQuery = z.strictObject({ placement: bannerPlacementParam });

/**
 * v1.59-live (D248): `POST /admin/banners` — a banner on a picture uploaded with `POST /admin/banner-uploads` for the
 * same placement in the last 24 hours (the CLI's `banner-admin add` rules: link allowlist, titles 1–40, window).
 */
export const createBannerBody = z.strictObject({
  mediaId: uuid,
  placement: bannerPlacementParam,
  link: z.string().trim().min(1).max(512),
  titleAr: z.string().trim().min(1).max(80).nullable().optional(),
  titleEn: z.string().trim().min(1).max(80).nullable().optional(),
  titleSide: z.enum(['LEFT', 'RIGHT']).optional(),
  startsAt: isoTime.optional(),
  endsAt: isoTime.nullable().optional(),
  sortOrder: z.number().int().min(0).max(1_000_000).optional(),
  enabled: z.boolean().optional(),
  reason,
});

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
/** D271: `account` (email or username, `@` optional); D197's `email` still accepted. Exactly one of the two. */
export const teamGrantBody = z
  .strictObject({
    account: z.string().trim().min(1).max(254).optional(),
    email: z.string().trim().min(3).max(254).optional(),
    role,
    reason,
    totpCode,
  })
  .refine((v) => (v.account === undefined) !== (v.email === undefined), {
    message: 'one of account or email',
    path: ['account'],
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
