/**
 * D268 (owner: «ايقونة vip دائماً تأتي بعد الاسم وازل الميدالية التي قبل الاسم»): the BADGE perk's art is the badge shown
 * right after a VIP member's name; the tier's medal stays on the VIP page only. Merged into i18n.ts after D252 (it
 * replaces D252's badge labels). Arabic first; English has the same keys.
 */
export const AR_D268 = {
  vipBadgeStill: "الميدالية المركزية (صفحة VIP فقط) — صورة ثابتة (https)",
  vipBadgeAnimation: "الميدالية المركزية (صفحة VIP فقط) — حركة SVGA (https)",
  vipBadgeHint:
    "الميدالية المركزية تظهر في صفحة VIP فقط، ولا تظهر بجانب الاسم. الشارة التي تأتي بعد اسم العضو (الدردشة، البطاقة، الملف) تُرفع في ميزة BADGE «شارة بجانب الاسم» في قائمة الميزات أدناه.",
  vipNameBadgeTitle: "شارة بجانب الاسم",
  vipNameBadgeHint:
    "تظهر بعد اسم العضو مباشرة في كل مكان (الدردشة بكل أنواعها، بطاقة الشخص، الملف، قوائم المشاهدين والزوار، إعلان الدخول). ارفع صورة PNG شفافة عريضة (مثل 1943 × 634) بزر «رفع شارة بجانب الاسم»؛ تُعرض بارتفاع شارات المستوى وبنسبة عرضها الأصلية. بلا صورة: شارة «VIPn» صغيرة بلون المستوى.",
  vipNameBadgeUpload: "رفع شارة بجانب الاسم (PNG)",
} as const;

export const EN_D268: Record<keyof typeof AR_D268, string> = {
  vipBadgeStill: "Central medal (VIP page only) — still (https)",
  vipBadgeAnimation: "Central medal (VIP page only) — SVGA (https)",
  vipBadgeHint:
    "The central medal shows on the VIP page only, never beside the name. The badge after a member's name (chat, card, profile) is uploaded on the BADGE perk «Badge beside the name» in the perks below.",
  vipNameBadgeTitle: "Badge beside the name",
  vipNameBadgeHint:
    "Shown right after the member's name everywhere (every chat, the person card, the profile, viewer and visitor lists, the entry banner). Upload a wide transparent PNG (e.g. 1943 × 634) with «Upload the name badge»; it shows at the level badges' height at its own width. Without one: a small «VIPn» pill in the tier's colour.",
  vipNameBadgeUpload: "Upload the name badge (PNG)",
};
