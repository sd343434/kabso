/**
 * D260 staff presence in lives: the shift «في المناوبة», «بثوثي» (the lives assigned to me), who is on shift (OWNER),
 * and the watch view's visible / hidden mode. Merged into i18n.ts. Arabic first; English has the same keys.
 */
export const AR_D260 = {
  shiftOn: "في المناوبة",
  shiftOff: "خارج المناوبة",
  shiftSwitch: "المناوبة",
  shiftHint:
    "في المناوبة تُوزَّع عليك البثوث الجديدة تلقائياً (البثوث المبلّغ عنها أولاً).",
  shiftMyLives: "{n} بث مسند إليك",
  shiftStartedToast: "أنت الآن في المناوبة.",
  shiftEndedToast: "انتهت مناوبتك؛ نُقلت بثوثك إلى الآخرين.",
  liveMine: "بثوثي",
  liveMineNone: "لا بثوث مسندة إليك الآن.",
  liveMineOffShift:
    "أنت خارج المناوبة — شغّل «في المناوبة» لتُسند إليك البثوث.",
  liveAssignedTo: "المراقب: {name}",
  liveUnassigned: "بلا مراقب",
  liveStaffWatching: "{n} من فريق كابسو",
  shiftsTitle: "من في المناوبة",
  shiftsOnCount: "{n} في المناوبة",
  shiftsUnassigned: "{n} بث بلا مراقب",
  shiftsNone: "لا أحد في المناوبة — البثوث الجديدة تنتظر.",
  shiftsColLives: "البثوث",
  shiftsColSince: "منذ",
  liveWatchVisible: "أنت ظاهر في البث بشارة «فريق كابسو» (لا تُحتسب مشاهداً).",
  liveWatchHiddenToggle: "مراقبة خفية",
  kabsoTeam: "فريق كابسو",
} as const;

export const EN_D260: Record<keyof typeof AR_D260, string> = {
  shiftOn: "On shift",
  shiftOff: "Off shift",
  shiftSwitch: "Shift",
  shiftHint:
    "On shift, new lives are assigned to you automatically (reported lives first).",
  shiftMyLives: "{n} lives assigned to you",
  shiftStartedToast: "You are on shift now.",
  shiftEndedToast: "Your shift ended; your lives moved to the others.",
  liveMine: "My lives",
  liveMineNone: "No lives are assigned to you now.",
  liveMineOffShift:
    "You are off shift — turn on «On shift» to be assigned lives.",
  liveAssignedTo: "Watched by {name}",
  liveUnassigned: "Nobody watching",
  liveStaffWatching: "{n} Kabso Team",
  shiftsTitle: "Who is on shift",
  shiftsOnCount: "{n} on shift",
  shiftsUnassigned: "{n} lives nobody watches",
  shiftsNone: "Nobody is on shift — new lives wait.",
  shiftsColLives: "Lives",
  shiftsColSince: "Since",
  liveWatchVisible:
    "You are shown in the live with the «Kabso Team» badge (not counted as a viewer).",
  liveWatchHiddenToggle: "Hidden watch",
  kabsoTeam: "Kabso Team",
};
