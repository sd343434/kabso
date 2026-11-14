/**
 * D273b (owner): «تحذير المضيف» in the panel — the same WARN as the staff tools in the app (D273): a written message
 * is required, it is audited, the live goes on and the host sees «تنبيه من فريق Kabso» (never a staff name). The live
 * moderation history names every kind («تحذير للمضيف» / "Host warned" …) instead of the raw kind. Merged into
 * i18n.ts. Arabic first; English has the same keys.
 */
export const AR_D273B = {
  modWarn: 'تحذير المضيف',
  modWarnIntro: 'يستمر البث، ويصل المضيف تنبيه برسالتك باسم «فريق Kabso» — لا يظهر اسمك. يُسجَّل في سجل التدقيق.',
  modWarnMessage: 'رسالة التحذير (تصل للمضيف)',
  modKindEND: 'إغلاق البث',
  modKindWARN: 'تحذير للمضيف',
  modKindNO_LIVE: 'منع من البث',
  modKindSUSPEND: 'تعليق الحساب',
  modKindDEVICE_BAN: 'حظر جهاز',
};

export const EN_D273B: Record<keyof typeof AR_D273B, string> = {
  modWarn: 'Warn the host',
  modWarnIntro:
    'The live goes on and the host gets your message as a warning from «the Kabso team» — your name is never shown. It is audited.',
  modWarnMessage: 'Warning message (sent to the host)',
  modKindEND: 'Live ended',
  modKindWARN: 'Host warned',
  modKindNO_LIVE: 'Banned from going live',
  modKindSUSPEND: 'Account suspended',
  modKindDEVICE_BAN: 'Device banned',
};
