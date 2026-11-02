import { describe, expect, it } from 'vitest';
import { EMPTY_CHAT, chatFailed, chatLoaded, chatPending, chatReceived, chatSent, giftReceived, parseGift } from '../src/feed';
import { initialLang, STRINGS, translate } from '../src/i18n';
import type { LiveChatMessage, LiveGift } from '../src/types';

const user = (id: string) => ({ id, username: id, displayName: id.toUpperCase(), avatarUrl: null });
const msg = (id: string, text = id): LiveChatMessage => ({
  id,
  roomId: 'r',
  author: user('u'),
  authorRole: 'VIEWER',
  kind: 'TEXT',
  text,
  expiresAt: null,
  createdAt: '2026-11-02T10:00:00.000Z',
});
const gift = (id: string, comboId: string, count: number, quantity: number): LiveGift => ({
  id,
  roomId: 'r',
  giftCode: 'rose',
  imageUrl: null,
  unitPrice: 1,
  quantity: 1,
  totalCoins: 1,
  sender: user('s'),
  recipients: [user('h')],
  combo: { id: comboId, count, quantity },
  createdAt: '2026-11-02T10:00:00.000Z',
});

describe('the chat feed (§10.11 data messages)', () => {
  it('the first page and live lines merge without duplicates', () => {
    let s = chatReceived(EMPTY_CHAT, { type: 'chat', message: msg('b') });
    s = chatLoaded(s, [msg('a'), msg('b')]);
    expect(s.lines.map((l) => l.id)).toEqual(['a', 'b']);
  });

  it('delete, join, chat-state; unknown types and junk change nothing', () => {
    let s = chatLoaded(EMPTY_CHAT, [msg('a'), msg('b')]);
    s = chatReceived(s, { type: 'chat-delete', id: 'a' });
    s = chatReceived(s, { type: 'join', user: user('v'), gender: 'FEMALE' }, 1);
    s = chatReceived(s, { type: 'chat-state', enabled: false });
    expect(s.lines.map((l) => l.kind)).toEqual(['message', 'join']);
    expect(s.enabled).toBe(false);
    expect(chatReceived(s, { type: 'sticker' })).toBe(s);
    expect(chatReceived(s, null)).toBe(s);
    expect(chatReceived(s, { type: 'chat' })).toBe(s);
  });

  it('the host\'s own message: shown at once, then the stored one (broadcast first or answer first)', () => {
    let s = chatPending(EMPTY_CHAT, 'c1', msg('c1', 'hi'));
    expect(s.lines[0]).toMatchObject({ pending: true });
    s = chatSent(s, 'c1', msg('m1', 'hi'));
    expect(s.lines.map((l) => l.id)).toEqual(['m1']);
    s = chatReceived(s, { type: 'chat', message: msg('m1', 'hi') });
    expect(s.lines).toHaveLength(1);
    // Broadcast before the POST answered.
    let t = chatPending(EMPTY_CHAT, 'c2', msg('c2'));
    t = chatReceived(t, { type: 'chat', message: msg('m2') });
    t = chatSent(t, 'c2', msg('m2'));
    expect(t.lines.map((l) => l.id)).toEqual(['m2']);
    expect(chatFailed(chatPending(EMPTY_CHAT, 'c3', msg('c3')), 'c3').lines[0]).toMatchObject({ failed: true, pending: false });
  });

  it('keeps the last 200 lines', () => {
    let s = EMPTY_CHAT;
    for (let i = 0; i < 230; i += 1) s = chatReceived(s, { type: 'chat', message: msg(`m${i}`) });
    expect(s.lines).toHaveLength(200);
    expect(s.lines[0]?.id).toBe('m30');
  });
});

describe('the gifts feed (§10.23 `gift` messages)', () => {
  it('parses only gift messages', () => {
    expect(parseGift({ type: 'gift', gift: gift('g1', 'g1', 1, 1) })?.id).toBe('g1');
    expect(parseGift({ type: 'lucky' })).toBeNull();
    expect(parseGift(null)).toBeNull();
  });

  it('newest first; a combo is one line with its running count', () => {
    let lines = giftReceived([], gift('g1', 'g1', 1, 1));
    lines = giftReceived(lines, gift('x1', 'x1', 1, 1));
    lines = giftReceived(lines, gift('g2', 'g1', 2, 2));
    lines = giftReceived(lines, gift('g3', 'g1', 3, 3));
    expect(lines.map((l) => [l.id, l.gift.combo.quantity])).toEqual([
      ['g3', 3],
      ['x1', 1],
    ]);
  });
});

describe('words', () => {
  it('every Arabic string has an English one; Arabic first unless the browser prefers English', () => {
    expect(Object.keys(STRINGS.en).sort()).toEqual(Object.keys(STRINGS.ar).sort());
    for (const v of Object.values(STRINGS.en)) expect(v.length).toBeGreaterThan(0);
    expect(initialLang(null, ['en-US', 'ar'])).toBe('en');
    expect(initialLang(null, ['fr-FR'])).toBe('ar');
    expect(initialLang('ar', ['en-US'])).toBe('ar');
    expect(translate('ar', 'obsHowTo')).toBe('في OBS اضغط Start Virtual Camera ثم اخترها هنا');
    expect(translate('en', 'statusRejoining', { n: 3 })).toContain('attempt 3');
  });
});
