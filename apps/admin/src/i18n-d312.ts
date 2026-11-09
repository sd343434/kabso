/** D312 «مُخصَّص» (custom gifts): the special category and the gift owner «صاحب الهدية», merged into i18n.ts. */
export const AR_D312 = {
  giftCatKindCUSTOM: 'مُخصَّص',
  giftCatCUSTOM: 'مُخصَّص',
  giftOwner: 'صاحب الهدية (Kabso ID)',
  giftOwnerHint:
    'اسم المستخدم لحساب نشط. يأخذ المستلم 60٪ من قيمة الهدية كرزاً، ويأخذ صاحب الهدية 3٪ من قيمتها كوينزات (للصرف فقط، لا تُسحب) — إلا إذا أرسلها بنفسه.',
  giftOwnerRequired: 'هدية «مُخصَّص» تحتاج صاحبها (Kabso ID).',
  giftOwnerBy: 'صاحب الهدية: \u2068@{username}\u2069',
  giftOwnerInactive: 'الحساب غير نشط — لا تظهر الهدية ولا تُرسل',
};

export const EN_D312: Record<keyof typeof AR_D312, string> = {
  giftCatKindCUSTOM: 'Custom',
  giftCatCUSTOM: 'Custom',
  giftOwner: 'Gift owner (Kabso ID)',
  giftOwnerHint:
    "An active account's username. Recipients get 60% of the gift's value as cherries; the owner gets 3% of it as coins (spendable only, never withdrawn) — unless they send it themselves.",
  giftOwnerRequired: 'A Custom gift needs its owner (Kabso ID).',
  giftOwnerBy: 'Owner: \u2068@{username}\u2069',
  giftOwnerInactive: 'The account is not active — the gift is hidden and cannot be sent',
};
