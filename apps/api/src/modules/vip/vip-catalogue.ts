/**
 * v1.129-social (D374, owner 2026-11-11, CONVENTIONS §10.166): the VIP perk catalogue — the one list of the perk codes a
 * tier may hold, each with its default titles and description (ar / en), its category, the shape of the value the
 * panel sets per tier and the art it takes, and whether the app really does it today (`built`). The panel ticks perks
 * from this list (a code outside it is refused); `VipPerk.available` is `built`. Pure (no Nest or database dependency;
 * unit-tested in `vip-catalogue.spec.ts`).
 *
 * The owner chose the set (D374): the eleven built perks kept, the thirty new perks registered not built («قريباً») —
 * each built by a later branch, which flips `built` and keeps the value shape (or widens it compatibly) — and
 * MONTHLY_GIFT kept from the earlier suggestions. The owner removed DAILY_COINS (2026-11-11, «ازلها»):
 * {@link VIP_RETIRED_PERKS}.
 */

/**
 * D374: perk codes the owner removed. Not in the catalogue (the panel cannot pick them, a save naming one is refused
 * `unknown_perk`); a tier row saved before keeps existing in the database but is ignored — never listed to the app,
 * never granted; the panel shows it as retired and drops it on the next save. DAILY_COINS (D258 phase 3): the claim
 * answers 409 `VIP_UNAVAILABLE` (`perk` `retired`); the `VIP_DAILY_COINS` ledger reason and past rows stay (history).
 */
export const VIP_RETIRED_PERKS: readonly string[] = ['DAILY_COINS'];

/** D374: [code] is a retired perk ({@link VIP_RETIRED_PERKS}). */
export function vipPerkRetired(code: string): boolean {
  return VIP_RETIRED_PERKS.includes(code);
}

/** The panel's groups (and the app's, when it groups). */
export const VIP_PERK_CATEGORIES = [
  'IDENTITY',
  'ENTRANCE',
  'CHAT',
  'ROOM',
  'PRIVACY',
  'GIFTS',
  'REWARDS',
  'SERVICE',
] as const;
export type VipPerkCategory = (typeof VIP_PERK_CATEGORIES)[number];

/** The unit of a whole-number value. */
export const VIP_PERK_UNITS = [
  'per_day',
  'per_month',
  'seconds',
  'minutes',
  'percent',
  'coins',
  'count',
] as const;
export type VipPerkUnit = (typeof VIP_PERK_UNITS)[number];

/** The file kinds a perk's art may be (each with its upload checks, {@link VIP_ART_LIMITS}). */
export const VIP_ART_KINDS = ['SVGA', 'PNG', 'WEBP', 'MP4'] as const;
export type VipArtKind = (typeof VIP_ART_KINDS)[number];

/** The upload limits of each art kind (`uploadAdminVipArt`): bytes, and for a video its length. */
export const VIP_ART_LIMITS: Readonly<
  Record<VipArtKind, { readonly maxBytes: number; readonly maxSeconds?: number }>
> = {
  SVGA: { maxBytes: 25 * 1024 * 1024 },
  PNG: { maxBytes: 2 * 1024 * 1024 },
  WEBP: { maxBytes: 2 * 1024 * 1024 },
  MP4: { maxBytes: 8 * 1024 * 1024, maxSeconds: 15 },
};

/** The lists an `enum` value picks from: the premium username medals, the rocket stages, the VIP tiers (their codes). */
export type VipEnumSource = 'PREMIUM_USERNAME_TIER' | 'ROCKET_STAGE' | 'VIP_TIER';

export interface VipIntSchema {
  readonly kind: 'int';
  readonly min: number;
  readonly max: number;
  readonly unit: VipPerkUnit;
}
export interface VipEnumSchema {
  readonly kind: 'enum';
  readonly source: VipEnumSource;
  /** The values allowed; empty for `VIP_TIER` (the tiers that exist, checked when saving). */
  readonly options: readonly string[];
}
export interface VipColorSchema {
  readonly kind: 'color';
}
/** A value of one field. */
export type VipScalarSchema = VipIntSchema | VipEnumSchema | VipColorSchema;

export interface VipCompositeField {
  readonly key: string;
  readonly labelAr: string;
  readonly labelEn: string;
  readonly schema: VipScalarSchema;
}

/**
 * What a perk's `value` is, per tier (`null` = not set: the perk gives nothing that needs a value until the owner sets
 * it):
 * - `none` — no value (the perk is on or off; its art, if any, is in the art fields);
 * - `int` — a whole number in `min … max` of `unit`;
 * - `enum` — one of `options` (from `source`);
 * - `color` — `#RRGGBB` (null = the tier's colour);
 * - `list` — distinct gift codes (that exist), at most `maxItems`;
 * - `art_list` — an art pack: distinct https URLs of uploaded files, at most `maxItems`;
 * - `composite` — an object with every field of `fields`.
 */
export type VipPerkValueSchema =
  | { readonly kind: 'none' }
  | VipScalarSchema
  | { readonly kind: 'list'; readonly item: 'GIFT_CODE'; readonly maxItems: number }
  | { readonly kind: 'art_list'; readonly kinds: readonly VipArtKind[]; readonly maxItems: number }
  | { readonly kind: 'composite'; readonly fields: readonly VipCompositeField[] };

/** The perk's own art: the kinds it takes (SVGA → `animation`, PNG / WebP → `still`, MP4 → `video`) and a size hint. */
export interface VipPerkArtSchema {
  readonly kinds: readonly VipArtKind[];
  /** The intended canvas in px (a hint for the owner's designer; any size within the upload limits is taken). */
  readonly width: number | null;
  readonly height: number | null;
}

export interface VipCatalogueEntry {
  readonly code: string;
  readonly category: VipPerkCategory;
  readonly titleAr: string;
  readonly titleEn: string;
  readonly descriptionAr: string;
  readonly descriptionEn: string;
  /** The app really does it today (`VipPerk.available`). */
  readonly built: boolean;
  readonly value: VipPerkValueSchema;
  /** Null: the perk takes no art of its own. */
  readonly art: VipPerkArtSchema | null;
  /**
   * D258: the value is also kept in `vip_tier_perks.amount` (DAILY_BULLET, LEVEL_SPEEDUP; DAILY_COINS was one until D374 removed it), which the
   * server's perk reads and older apps use.
   */
  readonly legacyAmount?: true;
}

const NONE = { kind: 'none' } as const;
const STILL_OR_SVGA: readonly VipArtKind[] = ['SVGA', 'PNG', 'WEBP'];
const art = (kinds: readonly VipArtKind[], width: number | null = null, height: number | null = null) => ({
  kinds,
  width,
  height,
});
const int = (min: number, max: number, unit: VipPerkUnit): VipIntSchema => ({ kind: 'int', min, max, unit });

/** v1.51-live (D233): the rocket stages «صاروخ 1 · 2 · 3 · 4» (`live_boosts.stage`, BOOST_STAGES). */
export const VIP_ROCKET_STAGES = ['STAGE_1', 'STAGE_2', 'STAGE_3', 'STAGE_4'] as const;
/** D146: the premium username medals (`premium_username_tier`). */
export const VIP_PREMIUM_USERNAME_TIERS = ['LEGEND', 'RUBY', 'GOLD', 'SILVER'] as const;

/** At most this many gift codes in EXCLUSIVE_GIFTS, and files in an art pack. */
export const VIP_LIST_MAX_ITEMS = 50;
export const VIP_ART_PACK_MAX_ITEMS = 24;

/** The catalogue, in the panel's order (by category, then as listed). */
export const VIP_PERK_CATALOGUE: readonly VipCatalogueEntry[] = [
  // ---- IDENTITY «الهوية والمظهر» ----
  {
    code: 'BADGE',
    category: 'IDENTITY',
    titleAr: 'شارة بجانب الاسم',
    titleEn: 'Name badge',
    descriptionAr: 'شارة VIP بعد الاسم في الدردشة والملف والقوائم.',
    descriptionEn: 'The VIP badge after the name in chat, the profile and lists.',
    built: true,
    value: NONE,
    art: art(STILL_OR_SVGA, 1943, 634),
  },
  {
    code: 'AVATAR_FRAME',
    category: 'IDENTITY',
    titleAr: 'إطار الصورة',
    titleEn: 'Avatar frame',
    descriptionAr: 'إطار متحرك حول الصورة على المقاعد والبطاقة والملف.',
    descriptionEn: 'An animated frame around the picture on seats, the card and the profile.',
    built: true,
    value: NONE,
    art: art(STILL_OR_SVGA, 600, 600),
  },
  {
    code: 'PROFILE_CARD',
    category: 'IDENTITY',
    titleAr: 'بطاقة تعريفية',
    titleEn: 'Profile card',
    descriptionAr: 'بطاقة الشخص مرسومة فوق فن المستوى.',
    descriptionEn: "The person card drawn over the tier's art.",
    built: true,
    value: NONE,
    art: art(STILL_OR_SVGA, 720, 1280),
  },
  {
    code: 'CHAT_NAME_COLOR',
    category: 'IDENTITY',
    titleAr: 'لون الاسم',
    titleEn: 'Name colour',
    descriptionAr: 'الاسم والرسائل بلون المستوى الخاص.',
    descriptionEn: "The name and messages in the tier's special colour.",
    built: true,
    value: NONE,
    art: null,
  },
  {
    code: 'GLOWING_NAME',
    category: 'IDENTITY',
    titleAr: 'اسم متوهج',
    titleEn: 'Glowing name',
    descriptionAr: 'توهج حول الاسم بلون المستوى.',
    descriptionEn: "A glow around the name in the tier's colour.",
    built: false,
    value: NONE,
    art: null,
  },
  {
    code: 'ANIMATED_COVER',
    category: 'IDENTITY',
    titleAr: 'غلاف متحرك',
    titleEn: 'Animated cover',
    descriptionAr: 'غلاف متحرك لصفحة الملف الشخصي.',
    descriptionEn: 'An animated cover on the profile page.',
    built: false,
    value: NONE,
    art: art(['SVGA', 'MP4', 'PNG', 'WEBP'], 1080, 720),
  },
  {
    code: 'PREMIUM_USERNAME',
    category: 'IDENTITY',
    titleAr: 'يوزر مميز',
    titleEn: 'Premium username',
    descriptionAr: 'يوزر مميز من الفئة المحددة طوال العضوية.',
    descriptionEn: 'A premium username of the set class for the membership.',
    built: false,
    value: { kind: 'enum', source: 'PREMIUM_USERNAME_TIER', options: VIP_PREMIUM_USERNAME_TIERS },
    art: null,
  },
  {
    code: 'GOLDEN_ID',
    category: 'IDENTITY',
    titleAr: 'آيدي ذهبي',
    titleEn: 'Golden ID',
    descriptionAr: 'رقم حساب مميز.',
    descriptionEn: 'A special account number.',
    built: false,
    // No short / special account number exists yet (only staff IDs «Kabso01», D283c): the branch that builds it adds
    // its classes as an `enum` value.
    value: NONE,
    art: null,
  },
  {
    code: 'ANIMATED_SIGNATURE',
    category: 'IDENTITY',
    titleAr: 'توقيع متحرك',
    titleEn: 'Animated signature',
    descriptionAr: 'توقيع متحرك في الملف الشخصي.',
    descriptionEn: 'An animated signature on the profile.',
    built: false,
    value: NONE,
    art: art(STILL_OR_SVGA, 750, 200),
  },
  {
    code: 'POST_BADGE',
    category: 'IDENTITY',
    titleAr: 'شارة على المنشورات',
    titleEn: 'Post badge',
    descriptionAr: 'شارة VIP على المنشورات والتعليقات.',
    descriptionEn: 'The VIP badge on posts and comments.',
    built: false,
    value: NONE,
    art: null,
  },
  {
    code: 'STORY_RING',
    category: 'IDENTITY',
    titleAr: 'حلقة القصص',
    titleEn: 'Story ring',
    descriptionAr: 'حلقة مميزة حول صورة القصص.',
    descriptionEn: 'A special ring around the story picture.',
    built: false,
    value: { kind: 'color' },
    art: art(STILL_OR_SVGA, 300, 300),
  },
  // ---- ENTRANCE «الدخول» ----
  {
    code: 'ENTRY_BANNER',
    category: 'ENTRANCE',
    titleAr: 'لافتة الدخول',
    titleEn: 'Entry banner',
    descriptionAr: 'لافتة باسمك عند دخول البث.',
    descriptionEn: 'A banner with your name when you join a live.',
    built: true,
    value: NONE,
    art: art(STILL_OR_SVGA, 660, 150),
  },
  {
    code: 'ENTRY_EFFECT',
    category: 'ENTRANCE',
    titleAr: 'مؤثر الدخول',
    titleEn: 'Entry effect',
    descriptionAr: 'مؤثر متحرك عند دخول البث.',
    descriptionEn: 'An animated effect when you join a live.',
    built: true,
    value: NONE,
    art: art(STILL_OR_SVGA, 750, 1334),
  },
  {
    code: 'HOST_GREETING',
    category: 'ENTRANCE',
    titleAr: 'تحية المضيف الآلية',
    titleEn: 'Host greeting',
    descriptionAr: 'عند دخولك يرى المضيف بطاقة «VIP دخل البث» ويرحّب بك بلمسة.',
    descriptionEn: 'When you join, the host sees a «VIP joined» card and greets you with one tap.',
    built: true, // D379 (§10.169)
    value: NONE,
    art: null,
  },
  // ---- CHAT «الدردشة والرسائل» ----
  {
    code: 'CHAT_BUBBLE',
    category: 'CHAT',
    titleAr: 'فقاعة الرسائل',
    titleEn: 'Chat bubble',
    descriptionAr: 'رسائلك في فقاعة المستوى.',
    descriptionEn: "Your messages in the tier's bubble.",
    built: true,
    value: NONE,
    art: art(STILL_OR_SVGA, 990, 720),
  },
  {
    code: 'DM_BUBBLE',
    category: 'CHAT',
    titleAr: 'فقاعة الرسائل الخاصة',
    titleEn: 'DM bubble',
    descriptionAr: 'فقاعة المستوى في الرسائل الخاصة (نفس فن فقاعة الدردشة).',
    descriptionEn: "The tier's bubble in direct messages (the chat bubble's art).",
    built: false,
    // Owner: «هي نفس فقاعة التكست» — it draws CHAT_BUBBLE's art.
    value: NONE,
    art: null,
  },
  {
    code: 'DAILY_BULLET',
    category: 'CHAT',
    titleAr: 'رسائل عامة مجانية',
    titleEn: 'Free public messages',
    descriptionAr: 'رسائل عامة مجانية كل يوم.',
    descriptionEn: 'Free public messages every day.',
    built: true,
    value: int(1, 100, 'per_day'),
    art: null,
    legacyAmount: true,
  },
  {
    code: 'PINNED_MESSAGE',
    category: 'CHAT',
    titleAr: 'تثبيت رسالتك أعلى الدردشة',
    titleEn: 'Pinned message',
    descriptionAr: 'ثبّت رسالتك أعلى دردشة البث لثوانٍ (مرات في اليوم).',
    descriptionEn: 'Pin your message at the top of the live chat for seconds (times a day).',
    built: true, // D379 (§10.169)
    value: {
      kind: 'composite',
      fields: [
        { key: 'count', labelAr: 'مرات يومياً', labelEn: 'Times a day', schema: int(1, 20, 'per_day') },
        { key: 'seconds', labelAr: 'مدة التثبيت', labelEn: 'Pinned for', schema: int(10, 600, 'seconds') },
      ],
    },
    art: null,
  },
  {
    code: 'TICKER_HOLD',
    category: 'CHAT',
    titleAr: 'إيقاف الشريط العام مؤقتاً',
    titleEn: 'Ticker hold',
    descriptionAr: 'تبقى هديتك على الشريط العام ثوانيَ إضافية.',
    descriptionEn: 'Your gift stays on the global ticker for extra seconds.',
    built: true, // D379 (§10.169)
    value: int(1, 60, 'seconds'),
    art: null,
  },
  {
    code: 'LONGER_VOICE',
    category: 'CHAT',
    titleAr: 'رسائل صوتية أطول',
    titleEn: 'Longer voice messages',
    descriptionAr: 'أقصى مدة للرسالة الصوتية.',
    descriptionEn: 'The longest voice message.',
    built: false,
    value: int(31, 600, 'seconds'),
    art: null,
  },
  // ---- ROOM «الغرفة والمقاعد» ----
  {
    code: 'MIC_WAVE',
    category: 'ROOM',
    titleAr: 'موجة المايك',
    titleEn: 'Mic wave',
    descriptionAr: 'موجة متحركة حول مقعدك أثناء الكلام.',
    descriptionEn: 'An animated wave around your seat while you speak.',
    built: true,
    value: NONE,
    art: art(STILL_OR_SVGA, 300, 300),
  },
  {
    code: 'SEAT_EMOJI',
    category: 'ROOM',
    titleAr: 'إيموجي VIP على المقعد',
    titleEn: 'VIP seat emoji',
    descriptionAr: 'حزمة إيموجي متحركة حصرية على مقعدك.',
    descriptionEn: 'An exclusive animated emoji pack on your seat.',
    built: true, // D379 (§10.169)
    value: { kind: 'art_list', kinds: STILL_OR_SVGA, maxItems: VIP_ART_PACK_MAX_ITEMS },
    art: null,
  },
  {
    code: 'SEAT_CROWN',
    category: 'ROOM',
    titleAr: 'تاج على المقعد',
    titleEn: 'Seat crown',
    descriptionAr: 'تاج متحرك فوق صورتك وأنت على المقعد.',
    descriptionEn: 'An animated crown over your picture while seated.',
    built: true, // D379 (§10.169)
    value: NONE,
    art: art(STILL_OR_SVGA, 300, 200),
  },
  {
    code: 'SEAT_REQUEST_PRIORITY',
    category: 'ROOM',
    titleAr: 'أولوية طلب المقعد عند المضيف',
    titleEn: 'Seat request priority',
    descriptionAr: 'طلبك للمقعد في أول قائمة المضيف (والقرار له).',
    descriptionEn: "Your seat request first in the host's list (the host decides).",
    built: true, // D379 (§10.169)
    value: NONE,
    art: null,
  },
  {
    code: 'SEAT_RESERVE',
    category: 'ROOM',
    titleAr: 'قفل المقعد لصديق',
    titleEn: 'Seat for a friend',
    descriptionAr: 'مضيف غرفة صوتية يحجز مقعداً لشخص لدقائق.',
    descriptionEn: "As an audio room's host, keep a seat for someone for minutes.",
    built: true, // D379 (§10.169)
    value: int(1, 60, 'minutes'),
    art: null,
  },
  {
    code: 'VIEWER_LIST_PRIORITY',
    category: 'ROOM',
    titleAr: 'اسمك أعلى قائمة المشاهدين',
    titleEn: 'Viewer list priority',
    descriptionAr: 'اسمك في أعلى قائمة المشاهدين.',
    descriptionEn: 'Your name at the top of the viewer list.',
    built: true, // D379 (§10.169)
    value: NONE,
    art: null,
  },
  {
    code: 'KICK_MUTE_SHIELD',
    category: 'ROOM',
    titleAr: 'حماية من الطرد والكتم',
    titleEn: 'Kick / mute shield',
    descriptionAr: 'لا يطردك أو يكتمك إلا المضيف.',
    descriptionEn: 'Only the host can kick or mute you.',
    built: false,
    value: NONE,
    art: null,
  },
  {
    code: 'VIP_ROOM',
    category: 'ROOM',
    titleAr: 'غرفة VIP خاصة',
    titleEn: 'VIP room',
    descriptionAr: 'غرفة صوتية يدخلها أعضاء VIP من المستوى الذي تختاره فما فوق.',
    descriptionEn: 'An audio room only VIP members of the tier you pick and above can enter.',
    built: true, // D379 (§10.169)
    value: { kind: 'enum', source: 'VIP_TIER', options: [] },
    art: null,
  },
  // ---- PRIVACY «الخصوصية» ----
  {
    code: 'PROFILE_VISITORS',
    category: 'PRIVACY',
    titleAr: 'من زار ملفي',
    titleEn: 'Profile visitors',
    descriptionAr: 'اعرف من زار ملفك.',
    descriptionEn: 'See who visited your profile.',
    built: true,
    value: NONE,
    art: null,
  },
  {
    code: 'HIDDEN_VISIT',
    category: 'PRIVACY',
    titleAr: 'زيارة مخفية',
    titleEn: 'Hidden visit',
    descriptionAr: 'زيارتك للملفات لا تظهر.',
    descriptionEn: 'Your profile visits are not shown.',
    built: false,
    value: NONE,
    art: null,
  },
  {
    code: 'RANKING_ANONYMOUS',
    category: 'PRIVACY',
    titleAr: 'مجهول في الترتيب',
    titleEn: 'Anonymous in rankings',
    descriptionAr: 'اسمك مخفي في قوائم الترتيب.',
    descriptionEn: 'Your name is hidden in the rankings.',
    built: false,
    value: NONE,
    art: null,
  },
  {
    code: 'HIDE_COINS_SENT',
    category: 'PRIVACY',
    titleAr: 'إخفاء الكوينز المرسلة',
    titleEn: 'Hide coins sent',
    descriptionAr: 'إخفاء مجموع ما أرسلته من كوينز.',
    descriptionEn: 'Hide the total coins you sent.',
    built: false,
    value: NONE,
    art: null,
  },
  {
    code: 'ANONYMOUS_GIFT',
    category: 'PRIVACY',
    titleAr: 'هدية مجهولة',
    titleEn: 'Anonymous gift',
    descriptionAr: 'أرسل هدية دون إظهار اسمك.',
    descriptionEn: 'Send a gift without your name.',
    built: false,
    value: NONE,
    art: null,
  },
  // ---- GIFTS «الهدايا» ----
  {
    code: 'EXCLUSIVE_GIFTS',
    category: 'GIFTS',
    titleAr: 'هدايا حصرية',
    titleEn: 'Exclusive gifts',
    descriptionAr: 'هدايا لا يرسلها إلا أعضاء المستوى.',
    descriptionEn: "Gifts only the tier's members can send.",
    built: false,
    value: { kind: 'list', item: 'GIFT_CODE', maxItems: VIP_LIST_MAX_ITEMS },
    art: null,
  },
  {
    code: 'BIG_GIFT_RAIN',
    category: 'GIFTS',
    titleAr: 'مطر عند الهدية الكبيرة',
    titleEn: 'Big gift rain',
    descriptionAr: 'مطر عملات يراه الجميع عند إرسالك هدية تبلغ الحد.',
    descriptionEn: 'A coin rain everyone sees when you send a gift at or above the threshold.',
    built: true, // D379 (§10.169)
    value: int(1, 1_000_000_000, 'coins'),
    art: art(['SVGA', 'MP4', 'PNG', 'WEBP'], 750, 1334),
  },
  {
    code: 'SCHEDULED_GIFT',
    category: 'GIFTS',
    titleAr: 'هدية مجدولة',
    titleEn: 'Scheduled gift',
    descriptionAr: 'جدولة إرسال هدية في وقت لاحق.',
    descriptionEn: 'Schedule a gift for later.',
    built: false,
    value: NONE,
    art: null,
  },
  {
    code: 'HIGHER_GIFT_QUANTITY',
    category: 'GIFTS',
    titleAr: 'كمية هدايا أكبر',
    titleEn: 'Higher gift quantity',
    descriptionAr: 'أقصى عدد للهدية في الإرسال الواحد.',
    descriptionEn: 'The largest quantity in one send.',
    built: false,
    value: int(1, 99_999, 'count'),
    art: null,
  },
  {
    code: 'MONTHLY_GIFT',
    category: 'GIFTS',
    titleAr: 'هدية شهرية',
    titleEn: 'Monthly gift',
    descriptionAr: 'هدية كل شهر.',
    descriptionEn: 'A gift every month.',
    built: false,
    value: NONE,
    art: null,
  },
  // ---- REWARDS «المكافآت» ----
  {
    code: 'LEVEL_SPEEDUP',
    category: 'REWARDS',
    titleAr: 'تسريع المستوى',
    titleEn: 'Level speed-up',
    descriptionAr: 'نقاط مستوى إضافية بالنسبة المحددة.',
    descriptionEn: 'Extra level points by the set percent.',
    built: true,
    value: int(1, 100, 'percent'),
    art: null,
    legacyAmount: true,
  },
  {
    code: 'MONTHLY_ROCKETS',
    category: 'REWARDS',
    titleAr: 'صواريخ شهرية',
    titleEn: 'Monthly rockets',
    descriptionAr: 'صواريخ دعم البث كل شهر.',
    descriptionEn: 'Live boost rockets every month.',
    built: false,
    value: {
      kind: 'composite',
      fields: [
        { key: 'count', labelAr: 'العدد شهرياً', labelEn: 'A month', schema: int(1, 30, 'per_month') },
        {
          key: 'stage',
          labelAr: 'نوع الصاروخ',
          labelEn: 'Rocket type',
          schema: { kind: 'enum', source: 'ROCKET_STAGE', options: VIP_ROCKET_STAGES },
        },
      ],
    },
    art: null,
  },
  {
    code: 'FREE_CP_REQUEST',
    category: 'REWARDS',
    titleAr: 'طلبات CP مجانية',
    titleEn: 'Free CP requests',
    descriptionAr: 'طلبات CP مجانية كل شهر.',
    descriptionEn: 'Free CP requests every month.',
    built: false,
    value: int(1, 30, 'per_month'),
    art: null,
  },
  // ---- SERVICE «الخدمة» ----
  {
    code: 'PRIORITY_SUPPORT',
    category: 'SERVICE',
    titleAr: 'دعم بأولوية',
    titleEn: 'Priority support',
    descriptionAr: 'طلباتك للدعم أولاً.',
    descriptionEn: 'Your support requests first.',
    built: false,
    value: NONE,
    art: null,
  },
];

const BY_CODE: ReadonlyMap<string, VipCatalogueEntry> = new Map(VIP_PERK_CATALOGUE.map((e) => [e.code, e]));

/** The catalogue entry of [code], or undefined for a code outside it. */
export function vipCatalogueEntry(code: string): VipCatalogueEntry | undefined {
  return BY_CODE.get(code);
}

/** The order of the catalogue (category first): perks are listed in it. */
export function vipCatalogueIndex(code: string): number {
  const i = VIP_PERK_CATALOGUE.findIndex((e) => e.code === code);
  return i < 0 ? VIP_PERK_CATALOGUE.length : i;
}

/** A stored perk value (JSON): a number, a string, a list of strings or an object of numbers / strings. */
export type VipPerkValue = number | string | readonly string[] | Readonly<Record<string, number | string>>;

/** One problem of a value: where under `value` (empty = the value itself) and the `issue`. */
export interface VipValueIssue {
  readonly path: readonly (string | number)[];
  readonly issue: string;
}

const COLOR = /^#[0-9A-F]{6}$/;
const HTTPS = /^https:\/\/\S{1,2040}$/;
const GIFT_CODE = /^[a-z0-9][a-z0-9_]{0,39}$/;
const TIER_CODE = /^[A-Z][A-Z0-9_]{0,39}$/;

function scalarIssues(schema: VipScalarSchema, v: unknown, path: (string | number)[]): VipValueIssue[] {
  switch (schema.kind) {
    case 'int':
      if (typeof v !== 'number' || !Number.isInteger(v)) return [{ path, issue: 'invalid_type' }];
      return v < schema.min || v > schema.max ? [{ path, issue: 'out_of_range' }] : [];
    case 'enum':
      if (typeof v !== 'string') return [{ path, issue: 'invalid_type' }];
      if (schema.source === 'VIP_TIER') return TIER_CODE.test(v) ? [] : [{ path, issue: 'invalid_format' }];
      return schema.options.includes(v) ? [] : [{ path, issue: 'invalid_value' }];
    case 'color':
      if (typeof v !== 'string') return [{ path, issue: 'invalid_type' }];
      return COLOR.test(v) ? [] : [{ path, issue: 'invalid_format' }];
  }
}

function listIssues(v: unknown, maxItems: number, item: RegExp, path: (string | number)[]): VipValueIssue[] {
  if (!Array.isArray(v) || v.some((x) => typeof x !== 'string')) return [{ path, issue: 'invalid_type' }];
  const list = v as string[];
  if (list.length === 0) return [{ path, issue: 'too_few' }];
  if (list.length > maxItems) return [{ path, issue: 'too_many' }];
  const out: VipValueIssue[] = [];
  const seen = new Set<string>();
  list.forEach((x, i) => {
    if (!item.test(x)) out.push({ path: [...path, i], issue: 'invalid_format' });
    else if (seen.has(x)) out.push({ path: [...path, i], issue: 'duplicate_value' });
    seen.add(x);
  });
  return out;
}

/**
 * The problems of [value] as the value of the perk [code] (empty = valid). Null is always valid (not set). A code
 * outside the catalogue → `unknown_perk` on the value's path's parent (the caller reports it on `code`). The
 * existence of gift codes and tier codes is the caller's check (it needs the database).
 */
export function vipPerkValueIssues(code: string, value: unknown): VipValueIssue[] {
  const entry = BY_CODE.get(code);
  if (!entry) return [{ path: [], issue: 'unknown_perk' }];
  if (value === null || value === undefined) return [];
  const schema = entry.value;
  switch (schema.kind) {
    case 'none':
      return [{ path: [], issue: 'not_allowed' }];
    case 'int':
    case 'enum':
    case 'color':
      return scalarIssues(schema, value, []);
    case 'list':
      return listIssues(value, schema.maxItems, GIFT_CODE, []);
    case 'art_list':
      return listIssues(value, schema.maxItems, HTTPS, []);
    case 'composite': {
      if (typeof value !== 'object' || Array.isArray(value)) return [{ path: [], issue: 'invalid_type' }];
      const obj = value as Record<string, unknown>;
      const keys = new Set(schema.fields.map((f) => f.key));
      const out: VipValueIssue[] = Object.keys(obj)
        .filter((k) => !keys.has(k))
        .map((k) => ({ path: [k], issue: 'unknown_field' }));
      for (const f of schema.fields) {
        if (obj[f.key] === undefined || obj[f.key] === null) out.push({ path: [f.key], issue: 'required' });
        else out.push(...scalarIssues(f.schema, obj[f.key], [f.key]));
      }
      return out;
    }
  }
}

/** The perk codes the app really does today (`VipPerk.available`). */
export const VIP_CATALOGUE_BUILT: readonly string[] = VIP_PERK_CATALOGUE.filter((e) => e.built).map(
  (e) => e.code,
);

/** D258: the perks whose value is also `vip_tier_perks.amount`, and its bounds (DAILY_BULLET, LEVEL_SPEEDUP). */
export const VIP_CATALOGUE_AMOUNTS: Readonly<Record<string, { readonly min: number; readonly max: number }>> =
  Object.fromEntries(
    VIP_PERK_CATALOGUE.filter((e) => e.legacyAmount && e.value.kind === 'int').map((e) => {
      const v = e.value as VipIntSchema;
      return [e.code, { min: v.min, max: v.max }];
    }),
  );
