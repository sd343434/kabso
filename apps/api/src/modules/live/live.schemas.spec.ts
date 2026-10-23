import { describe, expect, it } from 'vitest';
import { zodErrorToDetails } from '../../common/validation/zod-validation.pipe.js';
import { type Prisma } from '../../generated/prisma/client.js';
import { keysetAfter, orderBy } from './live-rooms.service.js';
import { isUuid, listLiveRoomsQuerySchema, liveTitleIssue, startLiveRoomSchema } from './live.schemas.js';

/** Builds strings from code points, so invisible characters stay visible in this file. */
const cp = (...points: number[]) => String.fromCodePoint(...points);
const ACUTE = cp(0x301); // combining acute accent
const ZWNJ = cp(0x200c);
const ZWJ = cp(0x200d);
const MIC = cp(0x1f3a4);
const THUMBS_MEDIUM = cp(0x1f44d, 0x1f3fd); // 1 grapheme, 2 code points

describe('live-room title (CONVENTIONS §10.3)', () => {
  it.each([
    'سهرة طرب',
    'Late night chat',
    'Kabso support Q&A', // reserved/brand rule does NOT apply to titles
    'admin',
    `K${cp(0x430)}bso`, // a mixed-script word (Cyrillic a) is allowed in titles
    'كابسو لايف',
    MIC,
    `${cp(0x1f468)}${ZWJ}${cp(0x1f469)}${ZWJ}${cp(0x1f467)} family`, // ZWJ emoji sequence
    `می${ZWNJ}خواهم`, // ZWNJ between letters
    'a',
    'x'.repeat(80),
    cp(0x663), // Arabic-Indic digit three
    `e${ACUTE.repeat(3)}`, // 3 combining marks
  ])('accepts %j', (title) => {
    expect(liveTitleIssue(title)).toBeNull();
  });

  it.each([
    ['empty', '', 'too_short'],
    ['whitespace only', '   ', 'invalid_format'],
    ['81 letters', 'x'.repeat(81), 'too_long'],
    ['81 emoji', MIC.repeat(81), 'too_long'],
    ['newline', 'line1\nline2', 'invalid_format'],
    ['tab', 'tab\there', 'invalid_format'],
    ['C1 NEL', `${cp(0x85)}next`, 'invalid_format'],
    ['RLO', `abc${cp(0x202e)}def`, 'invalid_format'],
    ['LRI', `abc${cp(0x2066)}def`, 'invalid_format'],
    ['LRM', `abc${cp(0x200e)}def`, 'invalid_format'],
    ['RLM', `abc${cp(0x200f)}def`, 'invalid_format'],
    ['ALM', `abc${cp(0x61c)}def`, 'invalid_format'],
    ['ZWSP', `abc${cp(0x200b)}def`, 'invalid_format'],
    ['word joiner', `abc${cp(0x2060)}def`, 'invalid_format'],
    ['inner BOM', `abc${cp(0xfeff)}def`, 'invalid_format'],
    ['leading ZWNJ', `${ZWNJ}abc`, 'invalid_format'],
    ['ZWJ next to spaces', `abc ${ZWJ} def`, 'invalid_format'],
    ['adjacent joiners', `ab${ZWNJ}${ZWJ}cd`, 'invalid_format'],
    ['4 combining marks', `e${ACUTE.repeat(4)}`, 'invalid_format'],
    ['symbols only', `!!! ${cp(0x2605)} ${cp(0xa9)}`, 'invalid_format'],
    ['punctuation only', '...', 'invalid_format'],
  ])('rejects %s as %s', (_name, title, issue) => {
    expect(liveTitleIssue(title)).toBe(issue);
  });

  it('limits code points to 160 independently of the 80-grapheme limit', () => {
    expect(liveTitleIssue(THUMBS_MEDIUM.repeat(80))).toBeNull(); // 80 graphemes, 160 code points
    // A combining mark adds a code point but no grapheme: 80 graphemes, 161 code points.
    expect(liveTitleIssue(`${THUMBS_MEDIUM.repeat(80)}${ACUTE}`)).toBe('too_long');
  });

  it('normalizes NFC, trims and strips an edge U+FEFF before storing', () => {
    const parsed = startLiveRoomSchema.parse({ title: `${cp(0xfeff)}  Cafe${ACUTE} night  ` });
    expect(parsed.title).toBe(`Caf${cp(0xe9)} night`);
  });

  // CP-011 (v1.7-live) added `mode`, `seatCount` and `theme`; the body stays strict.
  it('has a strict body', () => {
    const result = startLiveRoomSchema.safeParse({ title: 'ok', foo: 1 }, { reportInput: true });
    expect(result.success).toBe(false);
    if (!result.success) {
      expect(zodErrorToDetails(result.error)).toEqual([{ field: 'foo', issue: 'unknown_field' }]);
    }
  });

  it('CP-011: mode, seatCount (per mode, host tile included) and theme', () => {
    const details = (body: unknown) => {
      const result = startLiveRoomSchema.safeParse(body, { reportInput: true });
      return result.success ? [] : zodErrorToDetails(result.error);
    };
    for (const body of [
      { title: 'ok', mode: 'SOLO' },
      { title: 'ok', mode: 'MULTI', seatCount: 4 },
      { title: 'ok', mode: 'MULTI', seatCount: 12 },
      { title: 'ok', mode: 'AUDIO', seatCount: 5 },
      { title: 'ok', mode: 'AUDIO', seatCount: 13, theme: 'rose-garden' },
      { title: 'ok', theme: 'classic' },
    ]) {
      expect({ body, details: details(body) }).toEqual({ body, details: [] });
    }
    const cases: [unknown, { field: string; issue: string }[]][] = [
      [{ title: 'ok', mode: 'PK' }, [{ field: 'mode', issue: 'invalid_value' }]],
      [{ title: 'ok', mode: 'MULTI' }, [{ field: 'seatCount', issue: 'required' }]],
      [{ title: 'ok', mode: 'MULTI', seatCount: 5 }, [{ field: 'seatCount', issue: 'invalid_value' }]],
      [{ title: 'ok', mode: 'AUDIO', seatCount: 4 }, [{ field: 'seatCount', issue: 'invalid_value' }]],
      [{ title: 'ok', mode: 'AUDIO', seatCount: 7 }, [{ field: 'seatCount', issue: 'invalid_value' }]],
      [{ title: 'ok', seatCount: 4 }, [{ field: 'seatCount', issue: 'invalid_value' }]],
      [{ title: 'ok', mode: 'MULTI', seatCount: '4' }, [{ field: 'seatCount', issue: 'invalid_type' }]],
      [{ title: 'ok', theme: 'Bad Theme' }, [{ field: 'theme', issue: 'invalid_format' }]],
      [{ title: 'ok', theme: 'not-a-theme' }, [{ field: 'theme', issue: 'invalid_value' }]],
    ];
    for (const [body, expected] of cases) {
      expect({ body, details: details(body) }).toEqual({ body, details: expected });
    }
  });

  it('categorySlug must match ^[a-z0-9-]{2,32}$', () => {
    for (const slug of ['music', 'a1', 'live-music', 'x'.repeat(32)]) {
      expect(startLiveRoomSchema.safeParse({ title: 'ok', categorySlug: slug }).success).toBe(true);
    }
    for (const slug of ['M', 'Music', 'a', 'x'.repeat(33), 'a_b', 'a b', '']) {
      expect(startLiveRoomSchema.safeParse({ title: 'ok', categorySlug: slug }).success).toBe(false);
    }
  });
});

describe('GET /live/rooms query', () => {
  const parse = (query: Record<string, unknown>) =>
    listLiveRoomsQuerySchema.safeParse(query, { reportInput: true });
  const details = (query: Record<string, unknown>) => {
    const result = parse(query);
    return result.success ? [] : zodErrorToDetails(result.error);
  };

  it('defaults limit to 20 and accepts 1–50', () => {
    expect(parse({ tab: 'new' }).data).toEqual({ tab: 'new', limit: 20 });
    expect(parse({ tab: 'popular', limit: '1' }).data?.limit).toBe(1);
    expect(parse({ tab: 'following', limit: '50', category: 'music' }).data).toMatchObject({ limit: 50 });
  });

  it('reports field-level issues', () => {
    expect(details({})).toEqual([{ field: 'tab', issue: 'required' }]);
    expect(details({ tab: 'trending' })).toEqual([{ field: 'tab', issue: 'invalid_value' }]);
    expect(details({ tab: 'new', limit: '0' })).toEqual([{ field: 'limit', issue: 'too_small' }]);
    expect(details({ tab: 'new', limit: '51' })).toEqual([{ field: 'limit', issue: 'too_big' }]);
    expect(details({ tab: 'new', limit: 'ten' })).toEqual([{ field: 'limit', issue: 'invalid_format' }]);
    expect(details({ tab: 'new', limit: '1.5' })).toEqual([{ field: 'limit', issue: 'invalid_format' }]);
    expect(details({ tab: 'new', category: 'Bad Slug' })).toEqual([
      { field: 'category', issue: 'invalid_format' },
    ]);
    expect(details({ tab: 'new', cursor: 'x'.repeat(513) })).toEqual([
      { field: 'cursor', issue: 'too_long' },
    ]);
    expect(details({ tab: 'new', sort: 'asc' })).toEqual([{ field: 'sort', issue: 'unknown_field' }]);
    expect(details({ tab: ['new', 'popular'] })).toEqual([{ field: 'tab', issue: 'invalid_type' }]);
  });

  it('isUuid accepts any UUID and nothing else', () => {
    expect(isUuid('0192f1d0-1111-7aaa-8bbb-0c0d0e0f1011')).toBe(true);
    expect(isUuid('0192F1D0-1111-7AAA-8BBB-0C0D0E0F1011')).toBe(true);
    for (const id of [
      '',
      'abc',
      '0192f1d0-1111-7aaa-8bbb-0c0d0e0f101',
      "1' OR '1'='1",
      '0192f1d011117aaa8bbb0c0d0e0f1011',
    ]) {
      expect(isUuid(id)).toBe(false);
    }
  });
});

describe('list ordering (CONVENTIONS §10.4)', () => {
  const text = (sql: Prisma.Sql) => sql.sql.replace(/\s+/g, ' ').trim();
  const position = { score: 7, startedAt: new Date('2026-10-16T19:00:00.000Z'), id: 'room-id' };

  it('popular = score desc (CP-012), startedAt desc, id desc; new/following = startedAt desc, id desc', () => {
    expect(text(orderBy('popular'))).toBe('r.score DESC, r.started_at DESC, r.id DESC');
    expect(text(orderBy('new'))).toBe('r.started_at DESC, r.id DESC');
    expect(text(orderBy('following'))).toBe('r.started_at DESC, r.id DESC');
  });

  it('keyset continues strictly after the last row with the same key columns as the order', () => {
    const popular = keysetAfter('popular', position);
    expect(text(popular)).toBe('(r.score, r.started_at, r.id) < (?::bigint, ?::timestamptz, ?::uuid)');
    expect(popular.values).toEqual(['7', '2026-10-16T19:00:00.000Z', 'room-id']);
    for (const tab of ['new', 'following'] as const) {
      const sql = keysetAfter(tab, position);
      expect(text(sql)).toBe('(r.started_at, r.id) < (?::timestamptz, ?::uuid)');
      expect(sql.values).toEqual(['2026-10-16T19:00:00.000Z', 'room-id']);
    }
  });
});
