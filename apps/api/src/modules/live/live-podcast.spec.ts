import { describe, expect, it } from 'vitest';
import { LIVE_KIND_MODES, LIVE_KINDS } from './live-cursor.js';
import { hostSources, seatPermission } from './live-seats.service.js';
import {
  DEFAULT_PODCAST_THEME,
  LIVE_THEMES,
  PODCAST_SEAT_COUNT,
  PODCAST_TOPICS,
  guestSeatCount,
  hasGuestSeats,
  isVoiceMode,
  liveSeatAskBodySchema,
  seatCountFits,
  startLiveRoomSchema,
  updateLiveRoomSchema,
} from './live.schemas.js';

// v1.47-live (D212, CONVENTIONS §10.69): podcast rules that need no database.
describe('D212 podcast schemas and rules', () => {
  const issues = (r: {
    success: boolean;
    error?: { issues: { path: PropertyKey[]; params?: unknown }[] };
  }) =>
    r.success ? [] : r.error!.issues.map((i) => [i.path.join('.'), (i.params as { issue?: string })?.issue]);

  it('a PODCAST start needs `podcast`, refuses `seatCount`; others refuse `podcast`', () => {
    expect(
      startLiveRoomSchema.safeParse({ title: 'حلقة', mode: 'PODCAST', podcast: { topic: 'tech' } }).success,
    ).toBe(true);
    expect(issues(startLiveRoomSchema.safeParse({ title: 'حلقة', mode: 'PODCAST' }))).toEqual([
      ['podcast', 'required'],
    ]);
    expect(
      issues(
        startLiveRoomSchema.safeParse({
          title: 'حلقة',
          mode: 'PODCAST',
          podcast: { topic: 'tech' },
          seatCount: 4,
        }),
      ),
    ).toEqual([['seatCount', 'invalid_value']]);
    expect(
      issues(
        startLiveRoomSchema.safeParse({
          title: 'x',
          mode: 'AUDIO',
          seatCount: 5,
          podcast: { topic: 'tech' },
        }),
      ),
    ).toEqual([['podcast', 'invalid_value']]);
  });

  it('topics and question times are the owner’s; null = no limit', () => {
    expect(PODCAST_TOPICS).toEqual([
      'business',
      'tech',
      'sports',
      'religion',
      'society',
      'entertainment',
      'other',
    ]);
    for (const s of [60, 120, 180, 300, null]) {
      expect(
        startLiveRoomSchema.safeParse({
          title: 'x',
          mode: 'PODCAST',
          podcast: { topic: 'other', questionSeconds: s },
        }).success,
      ).toBe(true);
    }
    for (const bad of [0, 90, 600]) {
      expect(
        startLiveRoomSchema.safeParse({
          title: 'x',
          mode: 'PODCAST',
          podcast: { topic: 'other', questionSeconds: bad },
        }).success,
      ).toBe(false);
    }
    expect(
      startLiveRoomSchema.safeParse({ title: 'x', mode: 'PODCAST', podcast: { topic: 'news' } }).success,
    ).toBe(false);
    expect(updateLiveRoomSchema.safeParse({ questionsOpen: false, questionSeconds: null }).success).toBe(
      true,
    );
  });

  it('a raised hand’s question: 1–80 code points after the chat rules, no line break', () => {
    expect(liveSeatAskBodySchema.parse({ question: '  كيف أبدأ؟  ' })).toEqual({ question: 'كيف أبدأ؟' });
    expect(liveSeatAskBodySchema.safeParse({ question: 'x'.repeat(81) }).success).toBe(false);
    expect(liveSeatAskBodySchema.safeParse({ question: 'a\nb' }).success).toBe(false);
    expect(liveSeatAskBodySchema.safeParse({ question: '   ' }).success).toBe(false);
    expect(liveSeatAskBodySchema.parse({})).toEqual({});
  });

  it('a podcast is voice only with the host and 3 speakers', () => {
    expect(hasGuestSeats('PODCAST')).toBe(true);
    expect(guestSeatCount('PODCAST', null)).toBe(PODCAST_SEAT_COUNT);
    expect(PODCAST_SEAT_COUNT).toBe(4);
    expect(seatCountFits('PODCAST', 4)).toBe(false); // the count is fixed, never chosen
    expect(isVoiceMode('PODCAST')).toBe(true);
    expect(hostSources('PODCAST')).toEqual(['microphone']);
    expect(seatPermission('PODCAST', false)).toEqual({ visible: true, sources: ['microphone'] });
    expect(seatPermission('PODCAST', true)).toEqual({ visible: true, sources: [] });
  });

  it('`kind=podcast` is PODCAST only; no other kind lists a podcast but D342’s `party_all`', () => {
    expect(LIVE_KINDS).toContain('podcast');
    expect(LIVE_KIND_MODES.podcast).toEqual(['PODCAST']);
    // v1.107-live (D342): the party page's one mixed list.
    expect(LIVE_KIND_MODES.party_all).toEqual(['AUDIO', 'PODCAST', 'MULTI']);
    for (const kind of LIVE_KINDS.filter((k) => k !== 'podcast' && k !== 'party_all')) {
      expect(LIVE_KIND_MODES[kind]).not.toContain('PODCAST');
    }
  });

  it('the owner’s podcast backgrounds are room themes; the studio is the default', () => {
    expect(LIVE_THEMES.slice(-3)).toEqual(['podcast-studio', 'podcast-majlis', 'podcast-library']);
    expect(DEFAULT_PODCAST_THEME).toBe('podcast-studio');
  });
});
