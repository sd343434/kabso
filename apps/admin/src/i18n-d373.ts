/**
 * D373 (v1.128-social, CONVENTIONS §10.165; owner: «سيارات الدخول ستكون اما بشاشة كاملة او نصف الشاشة»): an entry car's
 * display «طريقة العرض» (owner corrections the same day: «من الاسفل وليس بالمنتصف … بل ٧٠٪ من شاشة من الاسفل للاعلى»:
 * HALF_SCREEN, the wire name kept, is labelled «الجزء السفلي (٧٠٪)») on the store item form, the items table and
 * the VIP ENTRY_EFFECT perk.
 */
export const AR_D373 = {
  entryDisplay: "طريقة العرض",
  entryDisplayFULL_SCREEN: "شاشة كاملة",
  entryDisplayHALF_SCREEN: "الجزء السفلي (٧٠٪)",
  entryDisplayHint:
    "شاشة كاملة: تغطي السيارة شاشة البث كلها مثل هدايا الشاشة الكاملة. الجزء السفلي (٧٠٪): تمر السيارة في ٧٠٪ من الشاشة من الأسفل إلى الأعلى بعرضها الكامل، ويظهر اسم الداخل فوقها.",
};

export const EN_D373: Record<keyof typeof AR_D373, string> = {
  entryDisplay: "Display",
  entryDisplayFULL_SCREEN: "Full screen",
  entryDisplayHALF_SCREEN: "Bottom (70%)",
  entryDisplayHint:
    "Full screen: the car covers the whole live screen, like the full-screen gifts. Bottom (70%): the car plays in the bottom 70% of the screen, measured up from its bottom edge, at its full width; the entrant's name shows above it.",
};
