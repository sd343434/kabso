/**
 * D378 (owner 2026-11-11, CONVENTIONS §10.168.4): the golden ID stock «آيدي ذهبي» on the VIP page, merged into
 * i18n.ts. Arabic first; English has the same keys.
 */
export const AR_D378 = {
  vipGoldenTitle: "مخزون الآيدي الذهبي",
  vipGoldenIntro:
    "أرقام قصيرة مميزة يختار منها صاحب ميزة «آيدي ذهبي» رقماً من فئة مستواه. الفئة تُحسب من الأرقام نفسها. بعد انتهاء العضوية يُحفظ الرقم لصاحبه {days} أيام ثم يعود إلى المخزون.",
  vipGoldenAdd: "إضافة أرقام",
  vipGoldenNumbers: "الأرقام (مفصولة بفواصل أو مسافات)",
  vipGoldenNumbersHint:
    "من 2 إلى 8 أرقام، لا تبدأ بصفر: رقم مكرر (88، 8888) أو 3 أو 4 أو 5 أرقام.",
  vipGoldenEmpty: "لا توجد أرقام في المخزون بعد.",
  vipGoldenColNumber: "الرقم",
  vipGoldenColClass: "الفئة",
  vipGoldenColState: "الحالة",
  vipGoldenColHolder: "صاحبه",
  vipGoldenColUntil: "حتى",
  vipGoldenRemove: "إزالة",
  vipGoldenRemoveTitle: "إزالة {number} من المخزون",
  vipGoldenAllClasses: "كل الفئات",
  vipGoldenAllStates: "كل الحالات",
  vipGoldenClass_REPEATED: "مكرر",
  vipGoldenClass_THREE_DIGIT: "3 أرقام",
  vipGoldenClass_FOUR_DIGIT: "4 أرقام",
  vipGoldenClass_FIVE_DIGIT: "5 أرقام",
  vipGoldenState_FREE: "متاح",
  vipGoldenState_HELD: "مستخدم",
  vipGoldenState_GRACE: "محفوظ لصاحبه",
};

export const EN_D378: Record<keyof typeof AR_D378, string> = {
  vipGoldenTitle: "Golden ID stock",
  vipGoldenIntro:
    "Short special numbers a holder of «Golden ID» picks from, of their tier's class. The class comes from the digits. After the membership the number is kept for its holder {days} days, then returns to the stock.",
  vipGoldenAdd: "Add numbers",
  vipGoldenNumbers: "Numbers (separated by commas or spaces)",
  vipGoldenNumbersHint:
    "2 to 8 digits, no leading zero: one digit repeated (88, 8888), or 3, 4 or 5 digits.",
  vipGoldenEmpty: "No numbers in the stock yet.",
  vipGoldenColNumber: "Number",
  vipGoldenColClass: "Class",
  vipGoldenColState: "State",
  vipGoldenColHolder: "Holder",
  vipGoldenColUntil: "Until",
  vipGoldenRemove: "Remove",
  vipGoldenRemoveTitle: "Remove {number} from the stock",
  vipGoldenAllClasses: "All classes",
  vipGoldenAllStates: "All states",
  vipGoldenClass_REPEATED: "Repeated",
  vipGoldenClass_THREE_DIGIT: "3 digits",
  vipGoldenClass_FOUR_DIGIT: "4 digits",
  vipGoldenClass_FIVE_DIGIT: "5 digits",
  vipGoldenState_FREE: "Free",
  vipGoldenState_HELD: "In use",
  vipGoldenState_GRACE: "Kept for its holder",
};
