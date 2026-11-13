/**
 * D381 (v1.134-social, CONVENTIONS §10.171.3): PRIORITY_SUPPORT — the badge on a VIP holder's report in the shared queue
 * and on a holder's WhatsApp conversation, merged into i18n.ts. Arabic first; English has the same keys.
 */
export const AR_D381 = {
  priorityVip: "أولوية VIP",
  prioritySafety: "عاجل",
};

export const EN_D381: Record<keyof typeof AR_D381, string> = {
  priorityVip: "VIP priority",
  prioritySafety: "Urgent",
};
