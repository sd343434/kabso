/** D241: a live in a PK on «البث الآن» (the PK badge and the opponent), merged into i18n.ts. Arabic first; English has the same keys. */
export const AR_D241 = {
  livePkBadge: "PK",
  livePkVs: "ضد @{handle}",
  livePkOpponent: "الخصم",
  livePkLegacy: "PK (بلا خصم مسجَّل)",
};

export const EN_D241: Record<keyof typeof AR_D241, string> = {
  livePkBadge: "PK",
  livePkVs: "vs @{handle}",
  livePkOpponent: "Opponent",
  livePkLegacy: "PK (no opponent on record)",
};
