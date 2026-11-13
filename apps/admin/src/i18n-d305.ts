/** D305 «شريطا الهدايا والألعاب»: the thresholds of the global strips in every live, merged into i18n.ts. */
export const AR_D305 = {
  gsTitle: 'شريطا الهدايا والألعاب (كل البثوث)',
  gsIntro:
    'شريط الهدايا: «أرسل … إلى … هدية …» في كل البثوث المباشرة (والبث الذي أُرسلت فيه) عندما يكون سعر الهدية الواحدة بهذا القدر أو أكثر — العدد لا يُجمع (10 × 50 ألف لا تكفي). شريط الألعاب: «فاز … بجائزة قيمتها … تذكرة» عندما تكون الجائزة بهذا القدر من التذاكر أو أكثر (لا توجد ألعاب بعد). يسري التغيير خلال 30 ثانية دون إعادة تشغيل، ويُسجَّل في سجل التدقيق.',
  gsGiftMinCoins: 'سعر الهدية الواحدة (كوينز) من',
  gsGameMinTickets: 'قيمة الجائزة (تذاكر) من',
  gsHint: 'رقم صحيح من 1 فأكثر (الافتراضي: 500,000 كوينز و1,000,000 تذكرة).',
  gsInvalid: 'أدخل رقماً صحيحاً موجباً في الحقلين.',
  gsSave: 'حفظ الحدّين',
};

export const EN_D305: Record<keyof typeof AR_D305, string> = {
  gsTitle: 'Gifts and games strips (every live)',
  gsIntro:
    'Gifts strip: "… sent … to …" in every live (the one it was sent in too) when ONE gift costs at least this many coins — quantities are not added up (10 × 50,000 does not qualify). Games strip: "… won a prize worth … tickets" when a prize is at least this many tickets (no games yet). A change applies within 30 seconds without a restart and is kept in the audit log.',
  gsGiftMinCoins: 'One gift costs (coins) from',
  gsGameMinTickets: 'Prize worth (tickets) from',
  gsHint: 'A whole number from 1 up (default: 500,000 coins and 1,000,000 tickets).',
  gsInvalid: 'Enter a positive whole number in both fields.',
  gsSave: 'Save both thresholds',
};
