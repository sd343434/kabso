/**
 * v1.89-social (D290, CONVENTIONS §10.103.8): source-app names and account IDs as keys — the name suggestion
 * «هل تقصد: …؟» and the duplicate check. Pure.
 */

/** Arabic marks dropped by {@link nameKey}: tashkeel, superscript alef, tatweel, Quranic marks. */
const ARABIC_MARKS = /[ؐ-ًؚ-ٰٟۖ-ۭـ]/g;
/** Latin combining marks (after NFKD). */
const LATIN_MARKS = /[̀-ͯ]/g;
/** Everything that is neither a letter nor a digit (spaces, dots, dashes, emoji …). */
const NOT_LETTER_OR_DIGIT = /[^\p{L}\p{N}]/gu;

/**
 * A name as a comparison key: lower case, no Latin diacritics, no Arabic tashkeel or tatweel, the Arabic letters that
 * are often swapped unified (أ إ آ ٱ → ا, ى → ي, ة → ه, ؤ → و, ئ → ي; ك / ی Persian forms → ك / ي), Arabic-Indic
 * digits as Latin, and no spaces or punctuation. «زفة» and «زفه» → «زفه»; "Zafa Live" → "zafalive".
 */
export function nameKey(raw: string): string {
  return raw
    .normalize('NFKD')
    .replace(LATIN_MARKS, '')
    .replace(ARABIC_MARKS, '')
    .toLowerCase()
    .replace(/[أإآٱ]/g, 'ا')
    .replace(/ى/g, 'ي')
    .replace(/ی/g, 'ي')
    .replace(/ک/g, 'ك')
    .replace(/ة/g, 'ه')
    .replace(/ؤ/g, 'و')
    .replace(/ئ/g, 'ي')
    .replace(/[٠-٩]/g, (d) => String(d.charCodeAt(0) - 0x0660))
    .replace(/[۰-۹]/g, (d) => String(d.charCodeAt(0) - 0x06f0))
    .replace(NOT_LETTER_OR_DIGIT, '');
}

/** An account ID as typed in the app, trimmed and lower-cased (the duplicate check's key). */
export function accountKey(raw: string): string {
  return raw.trim().toLowerCase();
}

/** The canonical source of a request: a listed app by code, else the typed name's key. */
export function sourceAppKey(app: { code: string; isOther: boolean }, typedName: string | null): string {
  return app.isOther ? `NAME:${nameKey(typedName ?? '')}`.slice(0, 80) : `APP:${app.code}`;
}

export interface NamedApp {
  readonly code: string;
  readonly nameAr: string;
  readonly nameEn: string;
  readonly aliases: readonly string[];
  readonly isOther: boolean;
}

/** Every spelling of an app as keys (its code, both names and the aliases). */
export function appKeys(app: NamedApp): string[] {
  return [
    ...new Set([app.code, app.nameAr, app.nameEn, ...app.aliases].map(nameKey).filter((k) => k !== '')),
  ];
}

/** The listed app (never "other") that a typed name means exactly, or null. */
export function exactApp<A extends NamedApp>(apps: readonly A[], typed: string): A | null {
  const key = nameKey(typed);
  if (key === '') return null;
  return apps.find((a) => !a.isOther && appKeys(a).includes(key)) ?? null;
}

/**
 * How well `query` matches `candidate` (both keys): 3 equal, 2 a prefix, 1 contained (queries of 2+ letters), 0 not.
 */
export function matchScore(query: string, candidate: string): number {
  if (query === '' || candidate === '') return 0;
  if (candidate === query) return 3;
  if (candidate.startsWith(query) || query.startsWith(candidate)) return 2;
  if (query.length >= 2 && (candidate.includes(query) || query.includes(candidate))) return 1;
  return 0;
}

export type Suggestion<A extends NamedApp> =
  | { readonly kind: 'APP'; readonly app: A; readonly score: number }
  | { readonly kind: 'NAME'; readonly name: string; readonly count: number; readonly score: number };

/**
 * The suggestions for a typed name: listed apps (by any spelling) and the canonical names typed in earlier requests
 * («other» apps, one per key: the first spelling used), best first, at most `limit`. A typed name that is a listed
 * app's alias is never suggested again as a typed name.
 */
export function suggest<A extends NamedApp>(
  query: string,
  apps: readonly A[],
  earlier: readonly { readonly key: string; readonly name: string; readonly count: number }[],
  limit = 5,
): Suggestion<A>[] {
  const q = nameKey(query);
  if (q === '') return [];
  const out: Suggestion<A>[] = [];
  const appKeySet = new Set<string>();
  for (const app of apps) {
    if (app.isOther) continue;
    const keys = appKeys(app);
    keys.forEach((k) => appKeySet.add(k));
    const score = Math.max(...keys.map((k) => matchScore(q, k)));
    if (score > 0) out.push({ kind: 'APP', app, score });
  }
  for (const e of earlier) {
    if (appKeySet.has(e.key)) continue;
    const score = matchScore(q, e.key);
    if (score > 0) out.push({ kind: 'NAME', name: e.name, count: e.count, score });
  }
  return out
    .sort((a, b) => b.score - a.score || (a.kind === b.kind ? 0 : a.kind === 'APP' ? -1 : 1))
    .slice(0, limit);
}
