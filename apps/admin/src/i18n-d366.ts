/**
 * D366 (owner approved «نعم موافق»; CONVENTIONS §10.159): WhatsApp departments and the transfer with a department, a
 * target and a note — the chat's transfer dialog, the inbox's department filter and chips, and the departments on the
 * staff card. Merged into i18n.ts.
 */
export const AR_D366 = {
  waDeptPAYMENTS: "الشحن والمدفوعات",
  waDeptAGENCIES: "الوكالات والمضيفون",
  waDeptTECHNICAL: "المشاكل التقنية",
  waDeptREPORTS: "البلاغات والحظر",
  waDeptGENERAL: "عام",
  waDeptAll: "كل الأقسام",
  waDeptFilter: "القسم",
  waTransferTitle: "تحويل المحادثة",
  waTransferDepartment: "القسم",
  waTransferWho: "إلى من",
  waTransferFirst: "أول متاح في القسم",
  waTransferFirstHint:
    "أقل موظف مناوب انشغالاً، أو قائمة القسم إن لم يكن أحد مناوباً",
  waTransferNoAgents: "لا يوجد موظفون في هذا القسم بعد.",
  waTransferNote: "ملاحظة داخلية (اختياري)",
  waTransferNoteHint: "تُحفظ مع التحويل ولا تُرسل للعميل أبداً",
  waTransferConfirm: "تحويل",
  waTransferDoneTo: "حُوّلت المحادثة إلى {name}",
  waTransferDoneQueue: "حُوّلت المحادثة إلى قائمة {department}",
  waAgentOpen: "{count} مفتوحة",
  waOnShift: "مناوب",
  waOffShift: "خارج المناوبة",
  waQueueOf: "قائمة {department}",
  waActTRANSFERDept: "حوّلها {by} إلى {to} — {department}",
  waActTRANSFERQueue: "حوّلها {by} إلى قائمة {department}",
  waHistoryNote: "ملاحظة: {note}",
  waDepartments: "أقسام واتساب",
  waDepartmentsDefaultTag: "افتراضي",
  waDepartmentsEdit: "تغيير الأقسام",
  waDepartmentsTitle: "أقسام واتساب — {name}",
  waDepartmentsIntro:
    "يستقبل الموظف التحويلات إلى هذه الأقسام، ومنها «أول متاح في القسم» أثناء مناوبته. بلا اختيار يكون في «عام». المحادثات المسندة إليه الآن تبقى معه.",
  waDepartmentsReplyOnly: "الأقسام لمن مستواه في واتساب «رد» أو «إدارة».",
};

export const EN_D366: Record<keyof typeof AR_D366, string> = {
  waDeptPAYMENTS: "Top-ups & payments",
  waDeptAGENCIES: "Agencies & hosts",
  waDeptTECHNICAL: "Technical issues",
  waDeptREPORTS: "Reports & bans",
  waDeptGENERAL: "General",
  waDeptAll: "All departments",
  waDeptFilter: "Department",
  waTransferTitle: "Transfer conversation",
  waTransferDepartment: "Department",
  waTransferWho: "To whom",
  waTransferFirst: "First available in the department",
  waTransferFirstHint:
    "The least busy agent on shift, or the department queue if nobody is on shift",
  waTransferNoAgents: "No agents in this department yet.",
  waTransferNote: "Internal note (optional)",
  waTransferNoteHint: "Kept with the transfer, never sent to the customer",
  waTransferConfirm: "Transfer",
  waTransferDoneTo: "Transferred to {name}",
  waTransferDoneQueue: "Transferred to the {department} queue",
  waAgentOpen: "{count} open",
  waOnShift: "On shift",
  waOffShift: "Off shift",
  waQueueOf: "{department} queue",
  waActTRANSFERDept: "{by} transferred it to {to} — {department}",
  waActTRANSFERQueue: "{by} transferred it to the {department} queue",
  waHistoryNote: "Note: {note}",
  waDepartments: "WhatsApp departments",
  waDepartmentsDefaultTag: "default",
  waDepartmentsEdit: "Change departments",
  waDepartmentsTitle: "WhatsApp departments — {name}",
  waDepartmentsIntro:
    "The staff member receives transfers to these departments, including «First available» while on shift. With none picked they are in General. Conversations assigned to them now stay with them.",
  waDepartmentsReplyOnly:
    "Departments are for staff whose WhatsApp level is Reply or Manage.",
};
