/** D347: the global lucky banner «شريط المردود في كل اللايفات» (in «شريطا الهدايا والألعاب»), merged into i18n.ts. */
export const AR_D347 = {
  gsLuckyGlobal: 'شريط المردود في كل اللايفات: المضاعفات',
  gsLuckyGlobalHint:
    'مكسب الحظ بأحد هذه المضاعفات يظهر شريطه في كل اللايفات الأخرى، وبالضغط عليه ينتقل المشاهد إلى البث (الافتراضي ×250 و×500 و×1000). المكاسب الأخرى تبقى في غرفتها فقط.',
  gsLuckyGlobalInvalid: 'اختر مضاعفاً واحداً على الأقل.',
  gsLuckyGlobalGap: 'الحد الأدنى بين شريطين (ثوانٍ)',
  gsLuckyGlobalGapHint:
    'شريط واحد على الأكثر في هذه المدة لكل الخدمة (فلكل غرفة أيضاً)؛ من 1 إلى 600 (الافتراضي 10). يطبَّق خلال 30 ثانية دون إعادة تشغيل.',
  gsLuckyGlobalGapInvalid: 'رقم صحيح من 1 إلى 600.',
};

export const EN_D347: Record<keyof typeof AR_D347, string> = {
  gsLuckyGlobal: 'Lucky win banner in every live: multipliers',
  gsLuckyGlobalHint:
    'A lucky win of one of these multipliers shows its banner in every other live, and a tap takes the viewer there (default ×250, ×500 and ×1000). Other wins stay in their own room.',
  gsLuckyGlobalInvalid: 'Choose at least one multiplier.',
  gsLuckyGlobalGap: 'Minimum time between two banners (seconds)',
  gsLuckyGlobalGapHint:
    'At most one banner in this time for the whole service (so per room too); 1 to 600 (default 10). Applies within 30 seconds, no restart.',
  gsLuckyGlobalGapInvalid: 'A whole number from 1 to 600.',
};
