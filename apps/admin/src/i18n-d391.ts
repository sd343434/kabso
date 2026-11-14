/**
 * D391 (v1.118-live, CONVENTIONS §10.180): a live in a 4-way PK «PK رباعي» on «البث الآن» — the badge, the two teams,
 * the four hosts with their scores and the moderator's end (void). Merged into i18n.ts. Arabic first; English has
 * the same keys.
 */
export const AR_D391 = {
  livePk4Badge: 'PK رباعي',
  livePk4Teams: '{a} ضد {b}',
  livePk4Hosts: 'المضيفون الأربعة',
  livePk4Team: 'فريق {team}',
  livePk4Out: 'غادر',
  livePk4Status: 'الحالة',
  livePk4StatusCONNECTED: 'متصل — لم يبدأ',
  livePk4StatusBATTLE: 'المعركة جارية',
  livePk4StatusRESULT: 'النتيجة',
  livePk4End: 'إنهاء PK الرباعي',
  livePk4EndIntro: 'تُنهى المعركة لاغيةً للمضيفين الأربعة (لا فائز ولا تُحتسب في السجلات)، ويبقى البث مستمراً.',
  livePk4Ended: 'أُنهي PK الرباعي',
  // D395 (v1.119-live, §10.181): FREE_FOR_ALL «الكل ضد الكل», places, «PK أحكام», two to four hosts.
  livePk4Ffa: 'الكل ضد الكل: {hosts}',
  livePk4Player: 'لاعب {seat}',
  livePk4Place: 'المركز {place}',
  livePk4Format: 'النوع',
  livePk4FormatTEAMS: '٢ ضد ٢',
  livePk4FormatFREE_FOR_ALL: 'الكل ضد الكل',
  livePk4Dares: 'PK أحكام',
  livePk4Players: '{count} مضيفين',
};

export const EN_D391: Record<keyof typeof AR_D391, string> = {
  livePk4Badge: '4-way PK',
  livePk4Teams: '{a} vs {b}',
  livePk4Hosts: 'The four hosts',
  livePk4Team: 'Team {team}',
  livePk4Out: 'Left',
  livePk4Status: 'Status',
  livePk4StatusCONNECTED: 'Connected — not started',
  livePk4StatusBATTLE: 'Battle on',
  livePk4StatusRESULT: 'Result',
  livePk4End: 'End the 4-way PK',
  livePk4EndIntro: 'The battle ends void for the four hosts (no winner, not counted in the records); the live goes on.',
  livePk4Ended: 'The 4-way PK was ended',
  livePk4Ffa: 'Free for all: {hosts}',
  livePk4Player: 'Player {seat}',
  livePk4Place: 'Place {place}',
  livePk4Format: 'Format',
  livePk4FormatTEAMS: '2 v 2',
  livePk4FormatFREE_FOR_ALL: 'Free for all',
  livePk4Dares: 'PK dares',
  livePk4Players: '{count} hosts',
};
