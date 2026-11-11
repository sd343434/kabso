/** D370 (v1.126-social, CONVENTIONS §10.163): «نقاط الشحن» — the tier's points price, the user page and the adjustment. */
export const AR_D370 = {
  vipPointsPrice: 'سعر النقاط',
  vipPointsPriceHint:
    'نقاط الشحن اللازمة لشهر واحد من هذا المستوى (زر «استبدل بالنقاط» في التطبيق). اتركه فارغاً إن لم يكن قابلاً للاستبدال.',
  vipPointsPriceShort: '{n} نقطة',
  vipPointsPriceNone: 'لا يُستبدل بالنقاط',
  rechargePoints: 'نقاط الشحن',
  ledgerRechargePoints: 'سجل نقاط الشحن',
  ctRechargePointsNote: 'نقاط الشحن لا تُحتسب ضمن الحد اليومي للتعديل؛ كل تعديل يُسجَّل في سجل التدقيق.',
};

export const EN_D370: Record<keyof typeof AR_D370, string> = {
  vipPointsPrice: 'Points price',
  vipPointsPriceHint:
    'Recharge points for one period of this tier (the app\'s «Redeem with points»). Leave empty if it cannot be redeemed.',
  vipPointsPriceShort: '{n} points',
  vipPointsPriceNone: 'Not redeemable',
  rechargePoints: 'Recharge points',
  ledgerRechargePoints: 'Recharge points history',
  ctRechargePointsNote: 'Recharge points do not count toward the daily adjustment cap; every adjustment is audited.',
};
