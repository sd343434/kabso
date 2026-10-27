/**
 * v1.27.5-live (D138, CONVENTIONS §10.30): the emojis someone seated may play on their own seat —
 * the owner's nine animated packs (D102). The token is `:<pack>_<id>:` (CP-003 shape). Keep in
 * step with `apps/mobile/lib/features/emoji/kabi_emoji.dart` (`EmojiPack`); an id the app does not
 * know is shown as nothing there, so the server accepts only these.
 */
export const SEAT_EMOJI_PACKS: Readonly<Record<string, readonly string[]>> = {
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
};

/** Every accepted token, `:<pack>_<id>:`. */
export const SEAT_EMOJI_TOKENS: ReadonlySet<string> = new Set(
  Object.entries(SEAT_EMOJI_PACKS).flatMap(([pack, ids]) => ids.map((id) => `:${pack}_${id}:`)),
);

/** True for a token of one of the owner's packs. */
export function isSeatEmojiToken(token: string): boolean {
  return SEAT_EMOJI_TOKENS.has(token);
}

/** Counting rule: one seat emoji every 2 seconds per user (CONVENTIONS §7, §10.30). */
export const SEAT_EMOJI_INTERVAL_MS = 2_000;

/** The media data topic of `seat-emoji` messages. */
export const SEAT_EMOJI_TOPIC = 'seat-emoji';

/** The room modes with seats (the host is tile 0). */
export const SEAT_EMOJI_MODES: ReadonlySet<string> = new Set(['AUDIO', 'MULTI']);
