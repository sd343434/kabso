import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { describe, expect, it } from 'vitest';
import { isSeatEmojiToken, SEAT_EMOJI_PACKS, SEAT_EMOJI_TOKENS } from './live-seat-emoji.js';
import { liveSeatEmojiSchema } from './live.schemas.js';

describe('D138 seat emoji tokens (CONVENTIONS §10.30)', () => {
  it('accepts the owner nine packs, 142 emojis (D102)', () => {
    expect(Object.keys(SEAT_EMOJI_PACKS)).toEqual([
      'kabi',
      'kiki',
      'boo',
      'pipo',
      'dubi',
      'gogo',
      'lulu',
      'neno',
      'flags',
    ]);
    expect(Object.values(SEAT_EMOJI_PACKS).map((ids) => ids.length)).toEqual([
      24, 18, 12, 12, 12, 12, 12, 22, 18,
    ]);
    expect(SEAT_EMOJI_TOKENS.size).toBe(142);
    expect(isSeatEmojiToken(':kabi_love:')).toBe(true);
    expect(isSeatEmojiToken(':flags_ps:')).toBe(true);
    expect(isSeatEmojiToken(':neno_serenade:')).toBe(true);
  });

  it('refuses anything else: unknown ids and packs, Unicode, a token inside text, case', () => {
    for (const t of [
      ':kabi_nope:',
      ':zed_hi:',
      '😀',
      'x :kabi_love:',
      ':kabi_love: ',
      ':KABI_LOVE:',
      'kabi_love',
      '',
    ]) {
      expect(isSeatEmojiToken(t), t).toBe(false);
    }
  });

  it('matches the app pack list (apps/mobile kabi_emoji.dart)', () => {
    const dart = readFileSync(
      fileURLToPath(new URL('../../../../mobile/lib/features/emoji/kabi_emoji.dart', import.meta.url)),
      'utf8',
    );
    for (const [pack, ids] of Object.entries(SEAT_EMOJI_PACKS)) {
      const block = new RegExp(`\\n  ${pack}\\('[a-z]+', \\[([^\\]]*)\\]`).exec(dart);
      expect(block, pack).not.toBeNull();
      const appIds = [...block![1]!.matchAll(/'([a-z]+)'/g)].map((m) => m[1]);
      expect(appIds, pack).toEqual(ids);
    }
  });

  it('LiveSeatEmojiRequest: required, invalid_value, strict', () => {
    expect(liveSeatEmojiSchema.safeParse({ token: ':dubi_hug:' }).success).toBe(true);
    const issue = (body: unknown) => {
      const r = liveSeatEmojiSchema.safeParse(body);
      return r.success ? null : r.error.issues[0];
    };
    expect(issue({})?.path).toEqual(['token']);
    expect(issue({ token: ':dubi_nope:' })?.code).toBe('custom');
    expect(issue({ token: 5 })?.path).toEqual(['token']);
    expect(issue({ token: ':dubi_hug:', seat: 1 })?.code).toBe('unrecognized_keys');
  });
});
