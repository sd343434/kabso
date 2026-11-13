/**
 * D344 (owner 2026-11-09: «اسعار الشحن من الموقع يجب اضافة عليها عمولة stripe»; CONVENTIONS §10.143.2): Stripe's fee
 * folded into the website top-up price, in «الدفع (Stripe)». Merged into i18n.ts.
 */
export const AR_D344 = {
  payFeeTitle: 'عمولة Stripe في سعر الموقع',
  payFeeIntro:
    'يُضاف رسم Stripe إلى سعر كل باقة على الموقع حتى يصلك سعر الباقة كاملاً. يُعرض للمشتري سعر واحد شامل؛ لا تُعرض العمولة كبند منفصل (يُمنع ذلك على بطاقات المستهلكين في الاتحاد الأوروبي والمملكة المتحدة). عدد العملات لا يتغير.',
  payFeeGrossUp: 'إضافة عمولة Stripe إلى السعر',
  payFeePercent: 'النسبة (٪)',
  payFeeFixed: 'الرسم الثابت ({currency})',
  payFeeAdjust: 'اضبطها حسب نسبة حسابك في Stripe',
  payFeeServer: 'فارغ = قيمة الخادم ({value})',
  payFeeExample: 'مثال: باقة سعرها {base} تُعرض بسعر {price}',
  payFeeExampleOff: 'العمولة غير مضافة: الباقة بسعرها {base}',
  payFeeInvalid: 'النسبة من 0 إلى 20 (منزلتان عشريتان على الأكثر)، والرسم الثابت من 0 إلى 100.',
};

export const EN_D344: Record<keyof typeof AR_D344, string> = {
  payFeeTitle: 'Stripe fee in the website price',
  payFeeIntro:
    "Stripe's fee is added to each package's price on the website so you receive the full package price. Buyers see one all-inclusive price; the fee is never shown as a separate line (surcharging consumer cards is forbidden in the EU and UK). The coins do not change.",
  payFeeGrossUp: 'Add the Stripe fee to the price',
  payFeePercent: 'Percent (%)',
  payFeeFixed: 'Fixed fee ({currency})',
  payFeeAdjust: "Set these to your Stripe account's rates",
  payFeeServer: 'Empty = the server value ({value})',
  payFeeExample: 'Example: a {base} package is sold at {price}',
  payFeeExampleOff: 'Fee not added: the package sells at {base}',
  payFeeInvalid: 'The percent is 0 to 20 (at most 2 decimals) and the fixed fee 0 to 100.',
};
