/** D252 «VIP»: the VIP tiers, their order and their perks, merged into i18n.ts. Arabic first; English has the same keys. */
export const AR_D252 = {
  navVip: "VIP",
  vipTitle: "مستويات VIP",
  vipSubtitle:
    "المستويات التي تظهر في صفحة «شراء VIP» في التطبيق، بالترتيب: الأول في القائمة هو المستوى الأدنى. السعر بالعملات فقط؛ التجديد يدوي ولا يُخصم شيء تلقائياً.",
  vipAdd: "إضافة مستوى",
  vipEdit: "تعديل {code}",
  vipOrder: "الترتيب",
  vipCode: "الرمز",
  vipNameAr: "الاسم (عربي)",
  vipNameEn: "الاسم (إنجليزي)",
  vipColor: "اللون",
  vipBadgeStill: "رابط صورة البدج الثابتة (https)",
  vipBadgeAnimation: "رابط حركة البدج SVGA (https)",
  vipBadgeHint:
    "البدج هو الميدالية المركزية. رابط https مستضاف (ارفع الملف إلى مساحتك ثم ألصق الرابط). تُعرض الصورة الثابتة حتى تُحمَّل الحركة وفي الاختبارات. لا شيء مضمّن في التطبيق.",
  vipPerkStill: "صورة الميزة الثابتة",
  vipPerkAnimation: "حركة الميزة SVGA",
  vipArtW: "عرض الصورة",
  vipArtH: "ارتفاع الصورة",
  vipArtHint:
    "لكل ميزة فنّها الخاص (رابط https مستضاف) وأبعاده الأصلية؛ تُعرض الصورة الثابتة كمصغّرة في الشبكة.",
  vipPrice: "السعر (عملات)",
  vipDuration: "المدة (أيام)",
  vipDays: "{n} يوماً",
  vipMembers: "المشتركون الآن",
  vipPerks: "الميزات",
  vipPerksN: "{n} ميزة",
  vipPerkCode: "رمز الميزة",
  vipPerkTitleAr: "العنوان (عربي)",
  vipPerkTitleEn: "العنوان (إنجليزي)",
  vipPerkDescAr: "الوصف (عربي)",
  vipPerkDescEn: "الوصف (إنجليزي)",
  vipPerkShown: "ظاهرة في التطبيق",
  vipPerkAdd: "إضافة ميزة",
  vipPerkUp: "أعلى",
  vipPerkDown: "أسفل",
  vipPerkNotBuilt: "غير مفعّلة في التطبيق بعد — تظهر «قريباً»",
  vipPerkBuilt: "تعمل في التطبيق",
  vipPerksNote:
    "كل ميزة تظهر في التطبيق «قريباً» حتى تُبنى فعلاً؛ الخادم وحده يحدد الميزات التي تعمل، فلا تظهر ميزة غير موجودة على أنها مفعّلة.",
  vipStartOn: "تفعيل المستوى فور إضافته",
  vipMoveUp: "تحريك لأعلى",
  vipMoveDown: "تحريك لأسفل",
  vipReorderTitle: "تغيير الترتيب",
  vipReorderIntro:
    "الترتيب هو ما يراه الناس في التطبيق، وهو أيضاً الرتبة: الترقية تكون إلى مستوى يأتي بعده في هذه القائمة.",
  vipOffNote:
    "المستوى المتوقف لا يُعرض ولا يُشترى ولا يُجدَّد؛ من يملكه يحتفظ به حتى نهايته.",
  vipPriceNote:
    "السعر والمدة الجديدان يطبَّقان على المشتريات من الآن؛ الاشتراكات الحالية تبقى حتى نهايتها.",
  vipNone: "لا توجد مستويات بعد. أضف مستوى ثم فعّله ليظهر في التطبيق.",
  vipInvalid:
    "تحقق من الحقول: الرمز بأحرف إنجليزية كبيرة، اللون ‎#RRGGBB، السعر 1 أو أكثر، المدة 1–365 يوماً، ورموز الميزات غير مكررة.",
};

export const EN_D252: Record<keyof typeof AR_D252, string> = {
  navVip: "VIP",
  vipTitle: "VIP tiers",
  vipSubtitle:
    "The tiers of the app’s «Purchase VIP» page, in order: the first in the list is the lowest tier. Priced in coins only; renewal is manual and nothing is charged on its own.",
  vipAdd: "Add tier",
  vipEdit: "Edit {code}",
  vipOrder: "Order",
  vipCode: "Code",
  vipNameAr: "Name (Arabic)",
  vipNameEn: "Name (English)",
  vipColor: "Colour",
  vipBadgeStill: "Badge still URL (https)",
  vipBadgeAnimation: "Badge SVGA URL (https)",
  vipBadgeHint:
    "The badge is the central medallion. A hosted https URL (upload the file to your storage, then paste the URL). The still shows until the SVGA loads and in tests. Nothing is bundled in the app.",
  vipPerkStill: "Perk still",
  vipPerkAnimation: "Perk SVGA",
  vipArtW: "Art width",
  vipArtH: "Art height",
  vipArtHint:
    "Each perk has its own hosted art (https URL) and intrinsic size; the still is shown as the grid thumbnail.",
  vipPrice: "Price (coins)",
  vipDuration: "Length (days)",
  vipDays: "{n} days",
  vipMembers: "Members now",
  vipPerks: "Perks",
  vipPerksN: "{n} perks",
  vipPerkCode: "Perk code",
  vipPerkTitleAr: "Title (Arabic)",
  vipPerkTitleEn: "Title (English)",
  vipPerkDescAr: "Description (Arabic)",
  vipPerkDescEn: "Description (English)",
  vipPerkShown: "Shown in the app",
  vipPerkAdd: "Add perk",
  vipPerkUp: "Up",
  vipPerkDown: "Down",
  vipPerkNotBuilt: "Not working in the app yet — shown as «Soon»",
  vipPerkBuilt: "Works in the app",
  vipPerksNote:
    "Every perk shows as «Soon» in the app until it is really built; only the server decides which perks work, so a missing feature is never shown as active.",
  vipStartOn: "Put the tier on sale when added",
  vipMoveUp: "Move up",
  vipMoveDown: "Move down",
  vipReorderTitle: "Change the order",
  vipReorderIntro:
    "The order is what people see in the app, and also the rank: an upgrade goes to a tier further down this list.",
  vipOffNote:
    "A tier switched off is not listed, bought or renewed; people who hold it keep it to its end.",
  vipPriceNote:
    "A new price or length applies to purchases from now on; current memberships run to their end.",
  vipNone: "No tiers yet. Add a tier and switch it on to show it in the app.",
  vipInvalid:
    "Check the fields: the code in capital Latin letters, the colour #RRGGBB, a price of 1 or more, 1–365 days, and no repeated perk codes.",
};
