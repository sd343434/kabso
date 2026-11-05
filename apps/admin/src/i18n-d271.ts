/**
 * D271 «الموظفون والصلاحيات» (OWNER): the staff list with each one's shift, granting a role to an app account by email or
 * username, the step-up code, the next steps for a new staff member, and the rules' refusals in the panel's words.
 * Merged into i18n.ts. Arabic first; English has the same keys.
 */
export const AR_D271 = {
  staffTitle: "الموظفون والصلاحيات",
  staffSubtitle:
    "من يدخل لوحة الإدارة وبأي دور. كل منح أو سحب أو إعادة ضبط يحتاج سبباً ورمزاً جديداً من تطبيق المصادقة، ويُسجَّل باسمك.",
  staffAccount: "البريد أو اسم المستخدم",
  staffAccountHint:
    "حساب موجود في تطبيق كابسو، مثل name@example.com أو ‎@username.",
  staffCodeHint: "لتأكيد أنك أنت: أدخل رمزاً جديداً من تطبيق المصادقة.",
  staffOwnerWarning:
    "دور المالك يعطي صلاحية كاملة على اللوحة والفريق والإعدادات. امنحه لشخص تثق به فقط.",
  staffCount: "{n} في الفريق",
  staffOnShiftCount: "{n} في المناوبة الآن",
  staffShift: "المناوبة",
  staffShiftSince: "منذ {time}",
  staffNoShift: "لا مناوبة لهذا الدور",
  staffRevokeShiftNote:
    "إن لم يبقَ له دور مراقبة (مالك، مشرف، دعم) يخرج من المناوبة وتنتقل بثوثه إلى غيره فوراً.",
  staffNextTitle: "أُضيف {name} — الخطوات التالية",
  staffNextAlready: "الحساب يملك هذا الدور مسبقاً؛ لم يتغيّر شيء.",
  staffNextIntro: "أرسل هذه الخطوات إلى الموظف الجديد:",
  staffNextSignIn:
    "يسجّل الدخول في {url} ببريد حسابه في التطبيق ({email}) وكلمة مروره.",
  staffNextEnrol:
    "يُعدّ تطبيق المصادقة (Google Authenticator أو Microsoft Authenticator) عند أول دخول، ويحفظ رموز الاسترداد في مكان آمن.",
  staffNextEnrolled:
    "تطبيق المصادقة مُعدّ لهذا الحساب مسبقاً؛ يدخل بالرمز مباشرة.",
  staffNextShift:
    "تعمل «في المناوبة» تلقائياً عند دخوله بثاً أو استخدامه أدوات الفريق أو فتح «بثوثي» (من التطبيق أو اللوحة)، فتُسند إليه البثوث ويظهر فيها بشارة «فريق كابسو»؛ يوقفها بنفسه. لا يُطلب رمز المصادقة لأعمال الإشراف.",
  staffNextFinance: "دور المالية لا مناوبة له؛ يجد أقسام المال في القائمة.",
  staffNextDone: "تم",
  teamErrNoAccount: "لا يوجد حساب بهذا البريد أو اسم المستخدم.",
  teamErrNotActive: "الحساب محظور أو محذوف؛ لا يُمنح دوراً.",
  teamErrLocked: "الحساب مقفل الآن؛ لا يُمنح دوراً حتى ينتهي القفل.",
  teamErrSelfOwner: "لا يمكنك سحب دور المالك من حسابك.",
  teamErrLastOwner: "هذا آخر مالك؛ امنح دور المالك لشخص آخر أولاً.",
  teamErrNotHeld: "الحساب لا يملك هذا الدور.",
  teamErrSelfReset: "لا يمكنك إعادة ضبط مصادقتك من هنا.",
  teamErrNotMember: "الحساب ليس من الفريق.",
} as const;

export const EN_D271: Record<keyof typeof AR_D271, string> = {
  staffTitle: "Staff & permissions",
  staffSubtitle:
    "Who signs in to the admin panel and with which role. Every grant, revoke or reset needs a reason and a fresh authenticator code, and is logged under your name.",
  staffAccount: "Email or username",
  staffAccountHint:
    "An existing Kabso app account, e.g. name@example.com or @username.",
  staffCodeHint: "To confirm it is you: enter a fresh code from your authenticator.",
  staffOwnerWarning:
    "OWNER gives full control of the panel, the team and the settings. Grant it only to someone you trust.",
  staffCount: "{n} on the team",
  staffOnShiftCount: "{n} on shift now",
  staffShift: "Shift",
  staffShiftSince: "since {time}",
  staffNoShift: "No shift for this role",
  staffRevokeShiftNote:
    "With no watch role left (Owner, Moderator, Support) they go off shift and their lives move to the others at once.",
  staffNextTitle: "{name} added — next steps",
  staffNextAlready: "The account already holds this role; nothing changed.",
  staffNextIntro: "Send these steps to the new staff member:",
  staffNextSignIn:
    "Sign in at {url} with the app account's email ({email}) and password.",
  staffNextEnrol:
    "Set up the authenticator (Google Authenticator or Microsoft Authenticator) at the first sign-in and keep the recovery codes somewhere safe.",
  staffNextEnrolled:
    "The authenticator is already set up for this account; sign in with its code.",
  staffNextShift:
    "«On shift» turns on by itself when they enter a live, use the team tools or open «My lives» (app or panel): lives are assigned to them, shown with the «Kabso Team» badge; they turn it off. Moderation needs no authenticator code.",
  staffNextFinance: "Finance has no shift; the money sections are in the menu.",
  staffNextDone: "Done",
  teamErrNoAccount: "No account with this email or username.",
  teamErrNotActive: "The account is banned or deleted; it cannot be given a role.",
  teamErrLocked: "The account is locked now; it cannot be given a role until the lock ends.",
  teamErrSelfOwner: "You cannot take OWNER from your own account.",
  teamErrLastOwner: "This is the last OWNER; make someone else OWNER first.",
  teamErrNotHeld: "The account does not hold this role.",
  teamErrSelfReset: "You cannot reset your own authenticator here.",
  teamErrNotMember: "The account is not on the team.",
};
