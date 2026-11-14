import { describe, expect, it } from 'vitest';
import { hostSources, seatPermission } from './live-seats.service.js';
import {
  DEFAULT_HOT_SEAT_SECONDS,
  PODCAST_GUEST_TITLE_MAX_CODE_POINTS,
  isVoiceMedia,
  isVoiceMode,
  liveSeatAcceptBodySchema,
  liveSeatInviteBodySchema,
  livePodcastControlBodySchema,
  livePodcastDirectorBodySchema,
  livePodcastOnScreenBodySchema,
  livePodcastSegmentsBodySchema,
  PODCAST_SEGMENTS_MAX,
  startLiveRoomSchema,
} from './live.schemas.js';
import { EMPTY_STUDIO, segmentsOf } from './live-podcast-studio.js';

// v1.114-live (D363, CONVENTIONS §10.157): video podcast rules that need no database.
describe('D363 video podcast schemas and media rules', () => {
  const issues = (r: {
    success: boolean;
    error?: { issues: { path: PropertyKey[]; params?: unknown }[] };
  }) =>
    r.success ? [] : r.error!.issues.map((i) => [i.path.join('.'), (i.params as { issue?: string })?.issue]);

  it('`podcast.video` is an optional boolean of the podcast setup', () => {
    const parsed = startLiveRoomSchema.parse({
      title: 'حلقة',
      mode: 'PODCAST',
      podcast: { topic: 'tech', video: true },
    });
    expect(parsed.podcast?.video).toBe(true);
    expect(
      startLiveRoomSchema.parse({ title: 'حلقة', mode: 'PODCAST', podcast: { topic: 'tech' } }).podcast
        ?.video,
    ).toBeUndefined();
    expect(
      startLiveRoomSchema.safeParse({
        title: 'حلقة',
        mode: 'PODCAST',
        podcast: { topic: 'tech', video: 'yes' },
      }).success,
    ).toBe(false);
  });

  it('a video podcast is on camera like a multi-guest live; an audio podcast stays voice only', () => {
    expect(isVoiceMode('PODCAST')).toBe(true); // still the podcast kind (lists, themes)
    expect(isVoiceMedia('PODCAST', true)).toBe(false);
    expect(isVoiceMedia('PODCAST', false)).toBe(true);
    expect(isVoiceMedia('AUDIO', true)).toBe(true); // the flag means nothing outside PODCAST
    expect(hostSources('PODCAST', true)).toEqual(['camera', 'microphone']);
    expect(hostSources('PODCAST', false)).toEqual(['microphone']);
    expect(hostSources('AUDIO', true)).toEqual(['microphone']);
    expect(seatPermission('PODCAST', false, true)).toEqual({
      visible: true,
      sources: ['camera', 'microphone'],
    });
    expect(seatPermission('PODCAST', true, true)).toEqual({ visible: true, sources: ['camera'] });
    expect(seatPermission('PODCAST', false, false)).toEqual({ visible: true, sources: ['microphone'] });
    expect(seatPermission('AUDIO', false, true)).toEqual({ visible: true, sources: ['microphone'] });
  });

  it('the guest title follows the chat text rules and is at most 40 code points', () => {
    expect(PODCAST_GUEST_TITLE_MAX_CODE_POINTS).toBe(40);
    expect(
      liveSeatInviteBodySchema.parse({ username: 'sara', guestTitle: '  خبيرة تقنية  ' }).guestTitle,
    ).toBe('خبيرة تقنية');
    expect(liveSeatInviteBodySchema.safeParse({ username: 'sara', guestTitle: 'ب'.repeat(40) }).success).toBe(
      true,
    );
    expect(liveSeatInviteBodySchema.safeParse({ username: 'sara', guestTitle: 'ب'.repeat(41) }).success).toBe(
      false,
    );
    expect(liveSeatInviteBodySchema.safeParse({ username: 'sara', guestTitle: '   ' }).success).toBe(false);
    expect(liveSeatInviteBodySchema.parse({ username: 'sara' }).guestTitle).toBeUndefined();
  });

  it('the hot seat: `hotSeatSeconds` only with `hotSeat`, from the question times', () => {
    expect(DEFAULT_HOT_SEAT_SECONDS).toBe(60);
    expect(liveSeatAcceptBodySchema.parse({ hotSeat: true })).toEqual({ hotSeat: true });
    expect(liveSeatAcceptBodySchema.parse({ hotSeat: true, hotSeatSeconds: 120 }).hotSeatSeconds).toBe(120);
    expect(issues(liveSeatAcceptBodySchema.safeParse({ hotSeat: true, hotSeatSeconds: 90 }))).toEqual([
      ['hotSeatSeconds', 'invalid_value'],
    ]);
    expect(issues(liveSeatAcceptBodySchema.safeParse({ hotSeatSeconds: 60 }))).toEqual([
      ['hotSeatSeconds', 'invalid_value'],
    ]);
    expect(liveSeatAcceptBodySchema.parse({})).toEqual({});
    expect(liveSeatAcceptBodySchema.safeParse({ seatIndex: 2 }).success).toBe(true);
  });

  it('the director shot: a known shot, 1–5 distinct people, a sequence number', () => {
    const a = '0192f1c2-0000-7000-8000-000000000001';
    const b = '0192f1c2-0000-7000-8000-000000000002';
    expect(
      livePodcastDirectorBodySchema.safeParse({ shot: 'SPLIT', userIds: [a, b], locked: false, seq: 3 })
        .success,
    ).toBe(true);
    expect(
      livePodcastDirectorBodySchema.safeParse({ shot: 'WIDE', userIds: [a], locked: false, seq: 0 }).success,
    ).toBe(false);
    expect(
      livePodcastDirectorBodySchema.safeParse({ shot: 'GRID', userIds: [], locked: false, seq: 0 }).success,
    ).toBe(false);
    expect(
      livePodcastDirectorBodySchema.safeParse({ shot: 'GRID', userIds: [a, a], locked: false, seq: 0 })
        .success,
    ).toBe(false);
    expect(
      livePodcastDirectorBodySchema.safeParse({ shot: 'SPEAKER', userIds: [a], locked: true, seq: -1 })
        .success,
    ).toBe(false);
  });
});

// v1.114-live (D363 scope extension, owner 2026-11-11): the studio's bodies and stored shape.
describe('D363 scope extension: the studio schemas', () => {
  it('segments: 0–8, a title of 1–40 code points (chat text rules), optional minutes 1–180', () => {
    expect(
      livePodcastSegmentsBodySchema.parse({
        segments: [{ title: '  مقدمة  ' }, { title: 'نقاش', minutes: 20 }],
      }),
    ).toEqual({ segments: [{ title: 'مقدمة' }, { title: 'نقاش', minutes: 20 }] });
    expect(livePodcastSegmentsBodySchema.parse({ segments: [] }).segments).toEqual([]);
    const nine = Array.from({ length: PODCAST_SEGMENTS_MAX + 1 }, () => ({ title: 'أ' }));
    expect(livePodcastSegmentsBodySchema.safeParse({ segments: nine }).success).toBe(false);
    expect(livePodcastSegmentsBodySchema.safeParse({ segments: [{ title: '   ' }] }).success).toBe(false);
    expect(livePodcastSegmentsBodySchema.safeParse({ segments: [{ title: 'ب'.repeat(41) }] }).success).toBe(
      false,
    );
    expect(livePodcastSegmentsBodySchema.safeParse({ segments: [{ title: 'أ', minutes: 0 }] }).success).toBe(
      false,
    );
    expect(
      livePodcastSegmentsBodySchema.safeParse({ segments: [{ title: 'أ', minutes: 181 }] }).success,
    ).toBe(false);
  });

  it('setup segments belong to a video podcast', () => {
    const base = { title: 'حلقة', mode: 'PODCAST' };
    expect(
      startLiveRoomSchema.safeParse({
        ...base,
        podcast: { topic: 'tech', video: true, segments: [{ title: 'أ' }] },
      }).success,
    ).toBe(true);
    const audio = startLiveRoomSchema.safeParse({ ...base, podcast: { topic: 'tech', segments: [] } });
    expect(audio.success).toBe(false);
  });

  it('control: a person and/or a layout (never GRID); both may be null', () => {
    expect(livePodcastControlBodySchema.parse({})).toEqual({});
    expect(livePodcastControlBodySchema.parse({ pinUserId: null, layout: 'SPLIT' })).toEqual({
      pinUserId: null,
      layout: 'SPLIT',
    });
    expect(livePodcastControlBodySchema.safeParse({ layout: 'GRID' }).success).toBe(false);
    expect(livePodcastControlBodySchema.safeParse({ pinUserId: 'x' }).success).toBe(false);
    expect(livePodcastControlBodySchema.safeParse({ extra: 1 }).success).toBe(false);
  });

  it('on screen: a request id, an optional answering person', () => {
    const id = '0190f5a2-7b1c-7d2e-8f3a-1b2c3d4e5f60';
    expect(livePodcastOnScreenBodySchema.parse({ requestId: id })).toEqual({ requestId: id });
    expect(livePodcastOnScreenBodySchema.safeParse({}).success).toBe(false);
    expect(livePodcastOnScreenBodySchema.safeParse({ requestId: id, answerUserId: 'x' }).success).toBe(false);
  });

  it('reads the stored segments, skipping anything malformed', () => {
    expect(segmentsOf([{ title: 'أ', minutes: 5 }, { title: 'ب' }, { minutes: 3 }, 'x', null])).toEqual([
      { title: 'أ', minutes: 5 },
      { title: 'ب', minutes: null },
    ]);
    expect(segmentsOf({})).toEqual([]);
    expect(EMPTY_STUDIO).toMatchObject({
      seq: 0,
      pinUserId: null,
      layout: null,
      closing: false,
      onScreen: null,
    });
  });
});
