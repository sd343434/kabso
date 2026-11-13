/**
 * v1.130-social (D376, CONVENTIONS §10.167): «الحالة» — the status emoji ids a person may wear over their picture.
 * The server's allow-list, mirrored from the app (`apps/mobile/lib/features/status/status_catalogue.dart`, which
 * builds the Kabso packs from `EmojiPack` in `kabi_emoji.dart`); a unit test keeps the two in step. An id is
 * `<pack>.<emoji>`; the pack is the part before the dot. Never rename an id once released (people wear them).
 */

/** The free packs: the owner's Kabso packs (D66, D102) and «عام» (Google Noto animated emoji, CC BY 4.0). */
export const FREE_STATUS_PACKS: Readonly<Record<string, readonly string[]>> = {
  kabi: [
    'hi',
    'love',
    'lol',
    'wow',
    'sad',
    'angry',
    'wink',
    'live',
    'cool',
    'dizzy',
    'sleepy',
    'silly',
    'shy',
    'think',
    'party',
    'dead',
    'melt',
    'kiss',
    'gift',
    'fire',
    'crown',
    'money',
    'sing',
    'star',
  ],
  kiki: [
    'hi',
    'love',
    'lol',
    'wow',
    'sad',
    'angry',
    'cool',
    'sleepy',
    'wink',
    'kiss',
    'sing',
    'shy',
    'think',
    'party',
    'clap',
    'fire',
    'ok',
    'dizzy',
  ],
  boo: ['boo', 'scared', 'fade', 'peek', 'spin', 'laugh', 'love', 'cry', 'sneaky', 'sleep', 'shock', 'party'],
  pipo: ['hi', 'chirp', 'hungry', 'cold', 'fly', 'love', 'cry', 'angry', 'sleepy', 'yay', 'shy', 'wow'],
  dubi: ['hug', 'thanks', 'strong', 'honey', 'sleep', 'grr', 'lol', 'love', 'cool', 'ok', 'sad', 'clap'],
  gogo: ['hi', 'roar', 'stomp', 'hatch', 'munch', 'dance', 'sneeze', 'cool', 'love', 'lol', 'cry', 'wow'],
  lulu: ['hi', 'sun', 'rain', 'thunder', 'rainbow', 'snow', 'wind', 'sleep', 'love', 'wow', 'lol', 'shy'],
  neno: [
    'hi',
    'love',
    'lol',
    'wow',
    'cry',
    'angry',
    'cool',
    'think',
    'wink',
    'sleepy',
    'money',
    'ok',
    'clap',
    'party',
    'kiss',
    'blush',
    'rose',
    'heartbeat',
    'flirt',
    'melt',
    'iloveu',
    'serenade',
  ],
  flags: [
    'jo',
    'ps',
    'sa',
    'eg',
    'iq',
    'sy',
    'ye',
    'ae',
    'kw',
    'qa',
    'bh',
    'om',
    'lb',
    'ma',
    'dz',
    'tn',
    'ly',
    'sd',
  ],
  noto: [
    'happy',
    'laugh',
    'love',
    'heart_eyes',
    'cool',
    'star_struck',
    'party',
    'innocent',
    'wink_tongue',
    'hug',
    'kiss',
    'thinking',
    'sleepy',
    'eye_roll',
    'sad',
    'crying',
    'angry',
    'shocked',
    'heart',
    'fire',
    'hundred',
    'thumbs_up',
    'congrats',
    'thanks',
  ],
};

/**
 * The packs sold in «متجر الحالة» (whole pack, for a time; `status_pack_offers` holds the price). «المميزة»: 27 Noto
 * animated emoji (birds and luxury symbols; the owner's list had 29 — `parrot` 1F99C and `money_bag` 1F4B0 are not in
 * Noto's animated set and were left out). The owner's own designs join this pack later (app folder
 * `assets/emojis/premium/`): add their ids here and in the app, never rename one.
 */
export const STORE_STATUS_PACKS: Readonly<Record<string, readonly string[]>> = {
  premium: [
    'bird',
    'dove',
    'eagle',
    'owl',
    'flamingo',
    'peacock',
    'penguin',
    'chick',
    'hatching',
    'crown',
    'diamond',
    'rocket',
    'lion',
    'rich',
    'trophy',
    'glow_star',
    'sparkles',
    'unicorn',
    'dragon',
    'rose',
    'gift',
    'fireworks',
    'rainbow',
    'sparkling_heart',
    'champagne',
    'cheers',
    'devil',
  ],
};

/** The longest id we store (`users.status_emoji_id` is VARCHAR(64)). */
export const STATUS_EMOJI_ID_MAX = 64;

const FREE_IDS = new Set(
  Object.entries(FREE_STATUS_PACKS).flatMap(([pack, ids]) => ids.map((id) => `${pack}.${id}`)),
);
const STORE_IDS = new Set(
  Object.entries(STORE_STATUS_PACKS).flatMap(([pack, ids]) => ids.map((id) => `${pack}.${id}`)),
);

/** The pack of a status id (the part before the dot), or null for a malformed one. */
export function statusPackOf(id: string): string | null {
  const dot = id.indexOf('.');
  return dot > 0 ? id.slice(0, dot) : null;
}

export type StatusEmojiKind = 'free' | 'store' | 'unknown';

/** Whether [id] is a free status, a store pack's status, or not one we know. */
export function statusEmojiKind(id: string): StatusEmojiKind {
  if (FREE_IDS.has(id)) return 'free';
  if (STORE_IDS.has(id)) return 'store';
  return 'unknown';
}

/** Whether [packId] is a pack sold in the status store. */
export function isStoreStatusPack(packId: string): boolean {
  return Object.hasOwn(STORE_STATUS_PACKS, packId);
}

/** Every known id (tests; the app's mirror check). */
export function allStatusEmojiIds(): { free: string[]; store: string[] } {
  return { free: [...FREE_IDS], store: [...STORE_IDS] };
}

/**
 * The status to show for a person, or null: a free one always; a store pack's only while the person holds the pack
 * (`packs`: their `user_status_packs` rows) — an expired pack's status is never shown (it is also cleared from the
 * row by the next write). An id we no longer know shows nothing.
 */
export function visibleStatusEmoji(
  id: string | null | undefined,
  packs: readonly { packId: string; expiresAt: Date }[] | undefined,
  now: Date,
): string | null {
  if (!id) return null;
  switch (statusEmojiKind(id)) {
    case 'free':
      return id;
    case 'store': {
      const pack = statusPackOf(id);
      return (packs ?? []).some((p) => p.packId === pack && p.expiresAt.getTime() > now.getTime())
        ? id
        : null;
    }
    default:
      return null;
  }
}
