/** D318: the lucky chat threshold «مكاسب الحظ في التكست» (in «شريطا الهدايا والألعاب»), merged into i18n.ts. */
export const AR_D318 = {
  gsLuckyChat: 'مكاسب الحظ في التكست: من المضاعف',
  gsLuckyChatHint:
    'لا يظهر سطر المكسب في دردشة البث إلا لمكسب بهذا المضاعف فأكثر (أحد مضاعفات الحظ؛ الافتراضي ×250: يظهر ×250 و×500 و×1000). المكاسب الأصغر تبقى كما هي: الكوينزات وإطار الفوز ونتيجة المرسل.',
  gsLuckyChatInvalid: 'اختر أحد مضاعفات الحظ.',
};

export const EN_D318: Record<keyof typeof AR_D318, string> = {
  gsLuckyChat: 'Lucky wins in the chat: from multiplier',
  gsLuckyChatHint:
    "A win's line shows in the live chat only from this multiplier (one of the lucky multipliers; default ×250: ×250, ×500 and ×1000 show). Smaller wins keep everything else: the coins, the win banner and the sender's result.",
  gsLuckyChatInvalid: 'Choose one of the lucky multipliers.',
};
