/**
 * The side panel's feeds (D247): the live chat (CONVENTIONS §10.11 — `GET …/chat` once, then the `chat` topic's
 * `chat`, `chat-delete`, `join` and `chat-state` messages) and the incoming gifts (§10.23 — the `gift` topic's
 * `{"type":"gift","gift":LiveGift}`). Pure functions over plain state, so the order rules are unit-tested.
 */
import type { LiveChatMessage, LiveGift, UserSummary } from './types';

export const CHAT_LIMIT = 200;
export const GIFT_LIMIT = 50;

export type ChatLine =
  | { kind: 'message'; id: string; message: LiveChatMessage; pending?: boolean; failed?: boolean }
  | { kind: 'join'; id: string; user: UserSummary; gender: 'MALE' | 'FEMALE' | null };

export interface ChatState {
  lines: ChatLine[];
  enabled: boolean;
}

export const EMPTY_CHAT: ChatState = { lines: [], enabled: true };

function cap<T>(list: T[], limit: number): T[] {
  return list.length > limit ? list.slice(list.length - limit) : list;
}

/** The first page (`GET …/chat`, oldest first), merged with lines that arrived meanwhile (no duplicates). */
export function chatLoaded(state: ChatState, messages: readonly LiveChatMessage[]): ChatState {
  const known = new Set(state.lines.map((l) => l.id));
  const older: ChatLine[] = messages.filter((m) => !known.has(m.id)).map((m) => ({ kind: 'message', id: m.id, message: m }));
  return { ...state, lines: cap([...older, ...state.lines], CHAT_LIMIT) };
}

/**
 * One data message of the `chat` topic. Unknown types change nothing. A `chat` whose id is already listed (the
 * host's own message: the POST's answer and the broadcast) replaces it in place.
 */
export function chatReceived(state: ChatState, payload: unknown, joinSeq = 0): ChatState {
  const msg = payload as { type?: string } | null;
  if (!msg || typeof msg !== 'object') return state;
  switch (msg.type) {
    case 'chat': {
      const m = (payload as { message?: LiveChatMessage }).message;
      if (!m || typeof m.id !== 'string') return state;
      return upsertMessage(state, m);
    }
    case 'chat-delete': {
      const id = (payload as { id?: string }).id;
      return { ...state, lines: state.lines.filter((l) => l.id !== id) };
    }
    case 'join': {
      const p = payload as { user?: UserSummary; gender?: 'MALE' | 'FEMALE' | null };
      if (!p.user?.id) return state;
      const line: ChatLine = { kind: 'join', id: `join:${p.user.id}:${joinSeq}`, user: p.user, gender: p.gender ?? null };
      return { ...state, lines: cap([...state.lines, line], CHAT_LIMIT) };
    }
    case 'chat-state': {
      const enabled = (payload as { enabled?: unknown }).enabled;
      return typeof enabled === 'boolean' ? { ...state, enabled } : state;
    }
    default:
      return state;
  }
}

/** The host's own message as sent (shown at once, greyed) under its `clientId`. */
export function chatPending(state: ChatState, clientId: string, message: LiveChatMessage): ChatState {
  return {
    ...state,
    lines: cap([...state.lines, { kind: 'message', id: clientId, message, pending: true }], CHAT_LIMIT),
  };
}

/** The server's answer for a pending line: it takes the stored id (a broadcast that came first is kept once). */
export function chatSent(state: ChatState, clientId: string, message: LiveChatMessage): ChatState {
  const already = state.lines.some((l) => l.id === message.id);
  const lines = already
    ? state.lines.filter((l) => l.id !== clientId)
    : state.lines.map((l): ChatLine => (l.id === clientId ? { kind: 'message', id: message.id, message } : l));
  return { ...state, lines };
}

export function chatFailed(state: ChatState, clientId: string): ChatState {
  return {
    ...state,
    lines: state.lines.map((l): ChatLine => (l.id === clientId && l.kind === 'message' ? { ...l, pending: false, failed: true } : l)),
  };
}

function upsertMessage(state: ChatState, m: LiveChatMessage): ChatState {
  const i = state.lines.findIndex((l) => l.id === m.id);
  if (i >= 0) {
    const lines = state.lines.slice();
    lines[i] = { kind: 'message', id: m.id, message: m };
    return { ...state, lines };
  }
  return { ...state, lines: cap([...state.lines, { kind: 'message', id: m.id, message: m }], CHAT_LIMIT) };
}

/** A `gift` data message's gift, or null. */
export function parseGift(payload: unknown): LiveGift | null {
  const p = payload as { type?: string; gift?: LiveGift } | null;
  if (!p || p.type !== 'gift' || !p.gift || typeof p.gift.id !== 'string') return null;
  return p.gift;
}

export interface GiftLine {
  id: string;
  gift: LiveGift;
}

/**
 * Newest first. A combo's next send (same `combo.id`) replaces its line, so a 30-tap combo is one line with the
 * running count, not thirty.
 */
export function giftReceived(lines: readonly GiftLine[], gift: LiveGift): GiftLine[] {
  const comboId = gift.combo?.id ?? gift.id;
  const rest = lines.filter((l) => (l.gift.combo?.id ?? l.gift.id) !== comboId && l.id !== gift.id);
  return [{ id: gift.id, gift }, ...rest].slice(0, GIFT_LIMIT);
}
