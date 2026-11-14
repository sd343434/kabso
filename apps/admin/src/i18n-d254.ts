/** D254 «شريط ترقية المستويات»: the level from which a level-up is a banner in every live, merged into i18n.ts. */
export const AR_D254 = {
  lvTitle: 'شريط ترقية المستويات (كل البثوث)',
  lvIntro:
    'عندما يصل مستوى الدعم (مرسلو الهدايا) أو مستوى الجاذبية (المضيفون ومن على المقاعد) إلى هذا المستوى أو أعلى أثناء بث، يظهر شريط متحرك «تهانينا لـ … على الترقية إلى المستوى …» في كل البثوث المباشرة، ويُعلن كل مستوى بعده أيضاً. شريط واحد كل 8 ثوانٍ والباقي ينتظر دوره. يُسجَّل التغيير في سجل التدقيق.',
  lvMinLevel: 'من المستوى',
  lvHint: 'رقم صحيح من 1 إلى 100 (الافتراضي 30).',
  lvInvalid: 'أدخل رقماً صحيحاً من 1 إلى 100.',
  lvSave: 'حفظ المستوى',
};

export const EN_D254: Record<keyof typeof AR_D254, string> = {
  lvTitle: 'Level-up banner (every live)',
  lvIntro:
    'When a support level (gift senders) or a charm level (hosts and seated guests) reaches this level or higher during a live, a scrolling banner "Congratulations to … on reaching level …" shows in every live, and every level after it is announced too. One banner every 8 seconds; the others wait their turn. Kept in the audit log.',
  lvMinLevel: 'From level',
  lvHint: 'A whole number from 1 to 100 (default 30).',
  lvInvalid: 'Enter a whole number from 1 to 100.',
  lvSave: 'Save level',
};
