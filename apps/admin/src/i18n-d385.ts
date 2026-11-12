/**
 * D385 (v1.137-social, CONVENTIONS §10.174.6): «دعم كابسو» — the in-app support threads in the WhatsApp inbox, marked
 * «داخل التطبيق», merged into i18n.ts. Arabic first; English has the same keys.
 */
export const AR_D385 = {
  waInApp: "داخل التطبيق",
  waInAppHint:
    "محادثة «دعم كابسو» من داخل التطبيق — بلا نافذة ٢٤ ساعة وبلا قوالب، والرد نصّي.",
};

export const EN_D385: Record<keyof typeof AR_D385, string> = {
  waInApp: "In app",
  waInAppHint:
    "A «Kabso Support» chat from inside the app — no 24-hour window, no templates; replies are text.",
};
