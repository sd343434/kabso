/** D233 «صواريخ الزيارات»: the rocket stages' prices in coins, merged into i18n.ts. Arabic first; English has the same keys. */
export const AR_D233 = {
  navBoostPrices: 'صواريخ الزيارات',
  bpTitle: 'صواريخ الزيارات',
  bpSubtitle: 'أربع مراحل تضع البث في أماكن «مميز» أعلى قائمة البث. السعر بالعملات فقط؛ المدة من إعدادات الخادم.',
  bpStage: 'صاروخ {n}',
  bpMinutes: '{n} دقيقة',
  bpPrice: 'السعر (عملات)',
  bpConfig: 'سعر الخادم: {coins}',
  bpCustom: 'محدَّد من اللوحة',
  bpReadOnly: 'للعرض فقط: تغيير الأسعار للمالك.',
  bpRising: 'كل مرحلة يجب أن تكون أغلى من التي قبلها.',
  bpSave: 'حفظ الأسعار',
  bpNoChange: 'لا تغيير',
  bpSaveIntro: 'تُطبَّق الأسعار الجديدة على المشتريات من الآن؛ البطاقات المشتراة تبقى بسعرها ويُسترد سعرها نفسه. يحتاج سبباً ورمز المصادقة، ويُسجَّل في سجل التدقيق.',
  bpSaved: 'حُفظت الأسعار',
};

export const EN_D233: Record<keyof typeof AR_D233, string> = {
  navBoostPrices: 'Visit rockets',
  bpTitle: 'Visit rockets',
  bpSubtitle: 'Four stages that put a live in the «Featured» places at the top of the live list. Priced in coins only; the length is the server setting.',
  bpStage: 'Rocket {n}',
  bpMinutes: '{n} min',
  bpPrice: 'Price (coins)',
  bpConfig: 'Server price: {coins}',
  bpCustom: 'Set in the panel',
  bpReadOnly: 'Read only: the owner changes the prices.',
  bpRising: 'Each stage must cost more than the one before.',
  bpSave: 'Save prices',
  bpNoChange: 'No change',
  bpSaveIntro: 'New prices apply to purchases from now on; cards already bought keep their price and refund it. Needs a reason and the authenticator code, and is kept in the audit log.',
  bpSaved: 'Prices saved',
};
