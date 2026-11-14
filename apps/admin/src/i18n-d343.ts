/**
 * D343 (owner: «رمز الدعوة أو رمز المشرف» at sign-up, CONVENTIONS §10.142): the referral reasons «ليس شخصاً جديداً»
 * on «الدعوات», and the accounts created with a supervisor's staff ID on «الاستقطاب» — credited or withheld and why.
 * Merged into i18n.ts. Arabic first; English has the same keys.
 */
export const AR_D343 = {
  refReasonDEVICE_HAD_ACCOUNT: 'ليس جديداً: الجهاز عليه حساب سابق',
  refReasonEMAIL_HAD_ACCOUNT: 'ليس جديداً: البريد سُجّل من قبل',
  signupRecruitsTitle: 'التسجيل برمز المشرف',
  signupRecruitsIntro:
    'الحسابات التي أُنشئت برمز مشرف (Kabso07…). يُحتسب الاستقطاب للشخص الجديد فقط؛ يُنشأ الحساب دائماً لكن لا يُحتسب إن كان على الجهاز حساب سابق أو سُجّل البريد من قبل.',
  signupRecruitsNone: 'لا توجد تسجيلات برمز مشرف.',
  signupRecruitsUser: 'الحساب',
  signupRecruitsCode: 'الرمز',
  signupRecruitsCredit: 'الاحتساب',
  signupRecruitsAt: 'تاريخ التسجيل',
  signupCreditGRANTED: 'مُحتسب',
  signupCreditWITHHELD: 'غير مُحتسب',
  signupWithholdDEVICE_HAD_ACCOUNT: 'الجهاز عليه حساب سابق',
  signupWithholdEMAIL_HAD_ACCOUNT: 'البريد سُجّل من قبل',
  signupWithholdRECRUITER_INACTIVE: 'المشرف لم يعد يستقطب',
};

export const EN_D343: Record<keyof typeof AR_D343, string> = {
  refReasonDEVICE_HAD_ACCOUNT: 'Not new: the device had an account',
  refReasonEMAIL_HAD_ACCOUNT: 'Not new: the email was registered before',
  signupRecruitsTitle: 'Sign-ups with a supervisor code',
  signupRecruitsIntro:
    'Accounts created with a supervisor’s code (Kabso07…). A recruit counts only for a new person: the account is always created, but it is not counted when the device had an account or the email was registered before.',
  signupRecruitsNone: 'No sign-ups with a supervisor code yet.',
  signupRecruitsUser: 'Account',
  signupRecruitsCode: 'Code',
  signupRecruitsCredit: 'Credit',
  signupRecruitsAt: 'Signed up',
  signupCreditGRANTED: 'Counted',
  signupCreditWITHHELD: 'Not counted',
  signupWithholdDEVICE_HAD_ACCOUNT: 'The device had an account',
  signupWithholdEMAIL_HAD_ACCOUNT: 'The email was registered before',
  signupWithholdRECRUITER_INACTIVE: 'The supervisor no longer recruits',
};
