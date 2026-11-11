/**
 * D373 (v1.128-social, CONVENTIONS §10.165; owner: «سيارات الدخول ستكون اما بشاشة كاملة او نصف الشاشة»): an entry car's
 * display «طريقة العرض» on the store item form, the items table and the VIP ENTRY_EFFECT perk.
 */
export const AR_D373 = {
  entryDisplay: "طريقة العرض",
  entryDisplayFULL_SCREEN: "شاشة كاملة",
  entryDisplayHALF_SCREEN: "نصف الشاشة",
  entryDisplayHint:
    "شاشة كاملة: تغطي السيارة شاشة البث كلها مثل هدايا الشاشة الكاملة. نصف الشاشة: تمر السيارة في شريط بعرض الشاشة وبنصف ارتفاعها تقريباً، فوق الدردشة وتحت الشريط العلوي، ويبقى اسم الداخل مقروءاً.",
};

export const EN_D373: Record<keyof typeof AR_D373, string> = {
  entryDisplay: "Display",
  entryDisplayFULL_SCREEN: "Full screen",
  entryDisplayHALF_SCREEN: "Half screen",
  entryDisplayHint:
    "Full screen: the car covers the whole live screen, like the full-screen gifts. Half screen: the car plays in a full-width band about half the screen high, above the chat and below the top bar; the entrant's name stays readable.",
};
