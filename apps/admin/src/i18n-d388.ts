/**
 * D388 (owner 2026-11-13; CONVENTIONS §10.177): «سؤال اللغة» — the customer's language on each WhatsApp conversation
 * (the tag and the inbox filter) and the languages a staff member speaks on the staff card. Merged into i18n.ts.
 */
export const AR_D388 = {
  waLangAR: "عربي",
  waLangEN: "English",
  waLangAll: "كل اللغات",
  waLangFilter: "اللغة",
  waLanguages: "لغات واتساب",
  waLanguagesDefaultTag: "افتراضي",
  waLanguagesEdit: "تغيير اللغات",
  waLanguagesTitle: "لغات واتساب — {name}",
  waLanguagesIntro:
    "يصل الموظف إشعار المحادثات غير المسندة بهذه اللغات. بلا اختيار يتكلم اللغتين. المحادثات المسندة إليه الآن تبقى معه.",
  waLanguagesReplyOnly: "اللغات لمن مستواه في واتساب «رد» أو «إدارة».",
};

export const EN_D388: Record<keyof typeof AR_D388, string> = {
  waLangAR: "Arabic",
  waLangEN: "English",
  waLangAll: "All languages",
  waLangFilter: "Language",
  waLanguages: "WhatsApp languages",
  waLanguagesDefaultTag: "default",
  waLanguagesEdit: "Change languages",
  waLanguagesTitle: "WhatsApp languages — {name}",
  waLanguagesIntro:
    "The staff member is notified of unassigned conversations in these languages. With none picked they speak both. Conversations assigned to them now stay with them.",
  waLanguagesReplyOnly:
    "Languages are for staff whose WhatsApp level is Reply or Manage.",
};
