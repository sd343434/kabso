/**
 * The CP space (CP-021, owner D112, CONVENTIONS §10.24). Every number here is a CTO default the
 * owner may change (named constants, recorded in the board row D112).
 */

/** A daily CP task code (stable; the app keys its icons and copy on it). */
export type CpTaskCode = 'CHECK_IN' | 'SEND_GIFT' | 'CHAT_TOGETHER';

export interface CpTaskDef {
  readonly code: CpTaskCode;
  /** CP points (intimacy) the claim adds, once per couple and CP day. */
  readonly reward: number;
  /** How many steps complete it (`progress` counts up to it). */
  readonly target: number;
  readonly nameAr: string;
  readonly nameEn: string;
  readonly descriptionAr: string;
  readonly descriptionEn: string;
}

/**
 * The daily tasks, in display order. Each is measured from data the server already keeps, and is
 * worth claiming once per couple and CP day, so it cannot be farmed:
 * - CHECK_IN: both partners opened the CP space today (`POST /cp/me/check-in`, once per partner).
 * - SEND_GIFT: either partner sent a CP gift today (`cp_gifts`; gifts cost coins).
 * - CHAT_TOGETHER: both partners wrote in the chat of the same live today (`live_chat_messages`,
 *   not deleted, sent since the couple formed). "Both in the same live ≥ 10 minutes" is not
 *   derivable: `live_room_viewers` holds only who is connected now, not a history of presence.
 */
export const CP_TASKS: readonly CpTaskDef[] = [
  {
    code: 'CHECK_IN',
    reward: 10,
    target: 2,
    nameAr: 'تسجيل الحضور معاً',
    nameEn: 'Check in together',
    descriptionAr: 'يفتح كلاكما مساحة CP اليوم.',
    descriptionEn: 'Both of you open the CP space today.',
  },
  {
    code: 'SEND_GIFT',
    reward: 20,
    target: 1,
    nameAr: 'أرسل هدية CP',
    nameEn: 'Send a CP gift',
    descriptionAr: 'يرسل أحدكما هدية CP اليوم.',
    descriptionEn: 'Either of you sends a CP gift today.',
  },
  {
    code: 'CHAT_TOGETHER',
    reward: 30,
    target: 1,
    nameAr: 'دردشا في لايف واحد',
    nameEn: 'Chat in the same live',
    descriptionAr: 'يكتب كلاكما في دردشة اللايف نفسه اليوم.',
    descriptionEn: 'Both of you write in the chat of the same live today.',
  },
];

/** A confession: 1–200 code points (the chat text rules). */
export const CP_CONFESSION_MAX_CODE_POINTS = 200;

/** The couples ranking shows at most this many couples. */
export const CP_RANKING_MAX = 100;

/** The ranking periods: the current CP week (Monday 00:00 in the CP zone) or all time. */
export const CP_RANKING_PERIODS = ['WEEK', 'ALL'] as const;
export type CpRankingPeriod = (typeof CP_RANKING_PERIODS)[number];
