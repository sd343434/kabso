import { isValidUsername } from '../users/username.js';

/** At most this many distinct hashtags / mentions are linked per text (CONVENTIONS §11.6). */
export const MAX_HASHTAGS = 30;
export const MAX_MENTIONS = 20;
export const MAX_HASHTAG_LENGTH = 100;

// `#` not preceded by a letter, digit, mark or `_` (so `a#b` and URL fragments are no tags), then
// 1–100 letters, marks, digits or `_` of any script.
const HASHTAG = /(?<![\p{L}\p{M}\p{N}_&#])#([\p{L}\p{M}\p{N}_]{1,100})(?![\p{L}\p{M}\p{N}_])/gu;
// `@` not preceded by a letter, digit, `_`, `.` or `@` (so e-mail addresses are no mentions).
const MENTION = /(?<![\p{L}\p{N}_.@])@([A-Za-z0-9._]{3,30})(?![A-Za-z0-9_])/gu;

/** Normalizes a hashtag for storage and lookup: NFC, lower case, no `#`. */
export function normalizeHashtag(raw: string): string {
  return raw.replace(/^#/, '').normalize('NFC').toLowerCase();
}

/** A valid hashtag (path parameter or parsed tag): 1–100 letters, marks, digits or `_`. */
export function isValidHashtag(tag: string): boolean {
  return /^[\p{L}\p{M}\p{N}_]{1,100}$/u.test(tag) && /[\p{L}\p{N}]/u.test(tag);
}

/** Distinct hashtags in order of appearance (at most 30); a tag needs a letter or digit. */
export function parseHashtags(text: string): string[] {
  const out: string[] = [];
  for (const match of text.matchAll(HASHTAG)) {
    const tag = normalizeHashtag(match[1]!);
    if (!isValidHashtag(tag) || out.includes(tag)) continue;
    out.push(tag);
    if (out.length === MAX_HASHTAGS) break;
  }
  return out;
}

/** Distinct well-formed usernames mentioned (lower case, at most 20); existence is checked later. */
export function parseMentions(text: string): string[] {
  const out: string[] = [];
  for (const match of text.matchAll(MENTION)) {
    const username = match[1]!.toLowerCase().replace(/\.+$/, '');
    if (!isValidUsername(username) || out.includes(username)) continue;
    out.push(username);
    if (out.length === MAX_MENTIONS) break;
  }
  return out;
}
