import type { Prisma } from '../../generated/prisma/client.js';

/**
 * v1.140-social (D388, CONVENTIONS §10.177): «سؤال اللغة» — the WhatsApp language question and language routing.
 * Owner (2026-11-13): «اريد عندما يرسل الشخص يقوم تلقائي بسؤاله عن لغة التي يتحدثها عربي او انجليزي» — first time
 * only, a confirmation in the chosen language, the language shown to the staff, and the conversation routed to staff who
 * speak it. Plain functions (no Nest), shared by the webhook, the inbox and the team page.
 */
export const WA_LANGUAGES = ['AR', 'EN'] as const;
export type WaLanguage = (typeof WA_LANGUAGES)[number];

export function isWaLanguage(v: unknown): v is WaLanguage {
  return typeof v === 'string' && (WA_LANGUAGES as readonly string[]).includes(v);
}

/** The catalogue order, without duplicates. */
export function sortLanguages(list: readonly WaLanguage[]): WaLanguage[] {
  const set = new Set(list);
  return WA_LANGUAGES.filter((l) => set.has(l));
}

/** The reply-button ids of the question (§10.177.1); Meta echoes them back in `interactive.button_reply.id`. */
export const LANGUAGE_BUTTON_IDS: Readonly<Record<WaLanguage, string>> = {
  AR: 'kabso_lang_ar',
  EN: 'kabso_lang_en',
};

/** The question's text, both languages (it is stored as the outbound message's text for the inbox). */
export const LANGUAGE_QUESTION_TEXT =
  'مرحباً بك في Kabso Live 👋\nاختر لغتك للمتابعة\n\nWelcome to Kabso Live 👋\nPlease choose your language';

/** The confirmation after the choice, in the chosen language. */
export const LANGUAGE_CONFIRMATION: Readonly<Record<WaLanguage, string>> = {
  AR: 'شكراً لك! سيرد عليك فريق كابسو باللغة العربية في أقرب وقت.',
  EN: 'Thank you! The Kabso team will reply to you in English as soon as possible.',
};

/** Meta's reply-buttons payload of the question (each title ≤ 20 characters, each id ≤ 256). */
export function languageQuestionPayload(to: string): Record<string, unknown> {
  return {
    to,
    type: 'interactive',
    interactive: {
      type: 'button',
      body: { text: LANGUAGE_QUESTION_TEXT },
      action: {
        buttons: [
          { type: 'reply', reply: { id: LANGUAGE_BUTTON_IDS.AR, title: 'العربية' } },
          { type: 'reply', reply: { id: LANGUAGE_BUTTON_IDS.EN, title: 'English' } },
        ],
      },
    },
  };
}

/** Typed answers accepted as well as the buttons (trimmed, lower case, Arabic hamza / alef forms folded). */
const TYPED: Readonly<Record<string, WaLanguage>> = {
  العربية: 'AR',
  العربيه: 'AR',
  عربي: 'AR',
  عربى: 'AR',
  arabic: 'AR',
  english: 'EN',
  انجليزي: 'EN',
  انجليزى: 'EN',
  انكليزي: 'EN',
  الانجليزية: 'EN',
  الانجليزيه: 'EN',
};

function fold(text: string): string {
  return text.trim().toLowerCase().replace(/[إأآ]/g, 'ا').replace(/\s+/g, ' ');
}

/**
 * The language a customer's message chooses (§10.177.2): a reply button of the question (by its id), or a text or
 * button whose whole text is one of the accepted words; null otherwise. Only read while the conversation was asked
 * and has no language yet.
 */
export function languageOfAnswer(replyId: string | null, body: string | null): WaLanguage | null {
  if (replyId === LANGUAGE_BUTTON_IDS.AR) return 'AR';
  if (replyId === LANGUAGE_BUTTON_IDS.EN) return 'EN';
  if (!body || body.length > 40) return null;
  return TYPED[fold(body)] ?? null;
}

type Db = Pick<Prisma.TransactionClient, 'waStaffLanguage'>;

/** The languages SET for each person (absent: none set). */
export async function setLanguagesOf(db: Db, userIds: readonly string[]): Promise<Map<string, WaLanguage[]>> {
  if (userIds.length === 0) return new Map();
  const rows = await db.waStaffLanguage.findMany({
    where: { userId: { in: [...userIds] } },
    select: { userId: true, language: true },
  });
  const out = new Map<string, WaLanguage[]>();
  for (const r of rows) out.set(r.userId, [...(out.get(r.userId) ?? []), r.language]);
  for (const [k, v] of out) out.set(k, sortLanguages(v));
  return out;
}

/** The languages that apply: the ones set, else both. */
export function effectiveLanguages(set: readonly WaLanguage[] | undefined): WaLanguage[] {
  return set && set.length > 0 ? sortLanguages(set) : [...WA_LANGUAGES];
}

/** `AdminTeamWhatsAppLanguages`: the languages that apply and whether they are the default (none set: both). */
export function teamLanguagesOf(set: readonly WaLanguage[] | undefined) {
  return { languages: effectiveLanguages(set), isDefault: !set || set.length === 0 };
}

/** Whether a person with these languages set speaks [language] (none set: every language). */
export function speaks(set: readonly WaLanguage[] | undefined, language: WaLanguage): boolean {
  return effectiveLanguages(set).includes(language);
}
