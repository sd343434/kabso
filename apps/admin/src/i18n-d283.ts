/**
 * D283 (owner: «قم بتجزئة الاشراف كل مشرف مسؤول عن دول معينة بما يناسب»): the staff regions — each MODERATION / SUPPORT
 * staff member's regions in «الموظفون والصلاحيات» (OWNER, the code again and a reason, audited), and the region filter
 * of «البث الآن». Merged into i18n.ts. Arabic first; English has the same keys.
 */
export const AR_D283 = {
  regionARAB_WORLD: "الوطن العربي",
  regionGREATER_CHINA: "الصين الكبرى",
  regionTURKEY: "تركيا",
  regionIRAN: "إيران",
  regionSOUTH_ASIA: "جنوب آسيا",
  regionSOUTHEAST_ASIA: "جنوب شرق آسيا",
  regionEAST_ASIA: "شرق آسيا",
  regionEUROPE: "أوروبا",
  regionNORTH_AMERICA: "أمريكا الشمالية",
  regionLATIN_AMERICA: "أمريكا اللاتينية",
  regionSUB_SAHARAN_AFRICA: "أفريقيا جنوب الصحراء",
  regionRUSSIA_CENTRAL_ASIA: "روسيا وآسيا الوسطى",
  regionOCEANIA: "أوقيانوسيا",
  staffRegions: "المناطق",
  staffRegionsNone: "بلا منطقة — يُسند إليه حسب الحمل",
  staffRegionsEdit: "المناطق",
  staffRegionsTitle: "مناطق {name}",
  staffRegionsIntro:
    "تُسند إليه أولاً البثوث التي دولة مضيفها ضمن مناطقه، وكذلك بلاغاتها؛ وإن لم يكن أحد من المنطقة في المناوبة فحسب الحمل. يظهر في ملفه «مشرف للوطن العربي» ونحوه.",
  staffRegionsSaved: "حُفظت المناطق",
  teamErrRegionsRole: "المناطق لأدوار الإشراف والدعم فقط.",
  liveRegionFilter: "المنطقة",
  liveRegionAll: "كل المناطق",
  liveRegionMine: "مناطقي",
} as const;

export const EN_D283: Record<keyof typeof AR_D283, string> = {
  regionARAB_WORLD: "Arab World",
  regionGREATER_CHINA: "Greater China",
  regionTURKEY: "Türkiye",
  regionIRAN: "Iran",
  regionSOUTH_ASIA: "South Asia",
  regionSOUTHEAST_ASIA: "Southeast Asia",
  regionEAST_ASIA: "East Asia",
  regionEUROPE: "Europe",
  regionNORTH_AMERICA: "North America",
  regionLATIN_AMERICA: "Latin America",
  regionSUB_SAHARAN_AFRICA: "Sub-Saharan Africa",
  regionRUSSIA_CENTRAL_ASIA: "Russia & Central Asia",
  regionOCEANIA: "Oceania",
  staffRegions: "Regions",
  staffRegionsNone: "No region — assigned by load",
  staffRegionsEdit: "Regions",
  staffRegionsTitle: "Regions of {name}",
  staffRegionsIntro:
    "Lives whose host is from these regions (and their reports) go to them first; with nobody of the region on shift, by load. Their profile reads “Moderator — Arab World” and so on.",
  staffRegionsSaved: "Regions saved",
  teamErrRegionsRole: "Regions are for moderation and support roles only.",
  liveRegionFilter: "Region",
  liveRegionAll: "All regions",
  liveRegionMine: "My regions",
};

/** The staff regions in the catalogue's order (the API's `StaffRegion`). */
export const STAFF_REGIONS = [
  'ARAB_WORLD',
  'GREATER_CHINA',
  'TURKEY',
  'IRAN',
  'SOUTH_ASIA',
  'SOUTHEAST_ASIA',
  'EAST_ASIA',
  'EUROPE',
  'NORTH_AMERICA',
  'LATIN_AMERICA',
  'SUB_SAHARAN_AFRICA',
  'RUSSIA_CENTRAL_ASIA',
  'OCEANIA',
] as const;
export type StaffRegion = (typeof STAFF_REGIONS)[number];
