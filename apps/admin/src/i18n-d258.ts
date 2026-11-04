/** D258 (owner's VIP 1 perks): a perk's number per tier and the art uploads, merged into i18n.ts. */
export const AR_D258 = {
  vipPerkAmount: "العدد",
  vipPerkAmountHint:
    "للرسائل العامة المجانية: كم رسالة يومياً (1–100). للعملات اليومية: كم عملة يومياً. لتسريع المستوى: النسبة المئوية (1–100). اتركه فارغاً لباقي الامتيازات.",
  vipPerkAmountBad: "العدد غير صالح لهذه الميزة.",
  vipUploadStill: "رفع صورة",
  vipUploadAnimation: "رفع SVGA",
  vipUploading: "جارٍ الرفع…",
  vipUploadFailed: "تعذّر رفع الملف",
  vipNameColor: "لون الكتابة الخاص",
  vipRenewalDiscount: "خصم التجديد ٪",
  vipRenewalDiscountHint:
    "عند تجديد نفس المستوى (أثناء الاشتراك أو حتى ٧ أيام بعد انتهائه). من 0 إلى 90؛ 0 بلا خصم.",
  vipNameColorHint:
    "لون اسم العضو ورسائله وسطر دخوله. اتركه فارغاً بلا لون خاص.",
};

export const EN_D258: Record<keyof typeof AR_D258, string> = {
  vipPerkAmount: "Amount",
  vipPerkAmountHint:
    "Free public messages: how many a day (1–100). Daily coins: how many coins a day. Level speed-up: the percent (1–100). Leave empty for other perks.",
  vipPerkAmountBad: "The amount is not valid for this perk.",
  vipUploadStill: "Upload image",
  vipUploadAnimation: "Upload SVGA",
  vipUploading: "Uploading…",
  vipUploadFailed: "The file could not be uploaded",
  vipNameColor: "Special text colour",
  vipRenewalDiscount: "Renewal discount %",
  vipRenewalDiscountHint:
    "When the same tier is renewed (while active or up to 7 days after the end). 0 – 90; 0 = none.",
  vipNameColorHint:
    "The member's name, messages and entry line in this colour. Empty: none.",
};
