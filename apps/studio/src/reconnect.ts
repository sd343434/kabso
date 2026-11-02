/**
 * The studio's connection state machine (D247). livekit-client itself resumes short blips (ICE restart, signal
 * reconnect: `reconnecting` → `reconnected`). When it gives up (`disconnected` not asked for by the host), the studio
 * asks the API for a new host token and joins again, with a growing wait, for as long as the live is LIVE — the
 * heartbeat keeps the room alive in the meantime (CONVENTIONS §10.3: 45 s without one ends it). The live ends only
 * when the host ends it, or when the API says the room ended (409 `LIVE_ROOM_ENDED`, `HEARTBEAT_TIMEOUT`, an admin).
 */

export type ConnState =
  | { kind: 'idle' }
  | { kind: 'connecting' }
  | { kind: 'connected' }
  /** livekit-client is resuming the same session. */
  | { kind: 'resuming' }
  /** The session is gone; the studio rejoins after `delayMs` (attempt 1, 2, …). */
  | { kind: 'rejoining'; attempt: number; delayMs: number }
  | { kind: 'ended'; reason: EndReason };

export type EndReason = 'host' | 'server' | 'auth' | 'hosting-off';

export type ConnEvent =
  | { type: 'connect' }
  | { type: 'connected' }
  | { type: 'resuming' }
  | { type: 'resumed' }
  | { type: 'lost' }
  | { type: 'rejoin-failed'; retryable: boolean }
  | { type: 'room-ended' }
  | { type: 'host-ended' }
  | { type: 'signed-out' }
  | { type: 'hosting-off' }
  /** A new live from the studio (after an end). */
  | { type: 'reset' };

/** 1 s, 2 s, 4 s, 8 s, then every 15 s. */
export function backoffMs(attempt: number): number {
  return Math.min(15_000, 1000 * 2 ** Math.max(0, attempt - 1));
}

export function nextConnState(state: ConnState, event: ConnEvent): ConnState {
  if (event.type === 'reset') return { kind: 'idle' };
  if (state.kind === 'ended') return state;
  switch (event.type) {
    case 'host-ended':
      return { kind: 'ended', reason: 'host' };
    case 'room-ended':
      return { kind: 'ended', reason: 'server' };
    case 'signed-out':
      return { kind: 'ended', reason: 'auth' };
    case 'hosting-off':
      return { kind: 'ended', reason: 'hosting-off' };
    case 'connect':
      return { kind: 'connecting' };
    case 'connected':
    case 'resumed':
      return { kind: 'connected' };
    case 'resuming':
      return state.kind === 'connected' || state.kind === 'resuming' ? { kind: 'resuming' } : state;
    case 'lost': {
      if (state.kind === 'idle') return state;
      const attempt = state.kind === 'rejoining' ? state.attempt + 1 : 1;
      return { kind: 'rejoining', attempt, delayMs: backoffMs(attempt) };
    }
    case 'rejoin-failed': {
      if (!event.retryable) return { kind: 'ended', reason: 'server' };
      const attempt = state.kind === 'rejoining' ? state.attempt + 1 : 1;
      return { kind: 'rejoining', attempt, delayMs: backoffMs(attempt) };
    }
  }
}

/** The status the studio's top bar shows. */
export function connLabel(state: ConnState): 'statusLive' | 'statusConnecting' | 'statusUnstable' | 'statusRejoining' | 'statusEnded' | 'statusIdle' {
  switch (state.kind) {
    case 'connected':
      return 'statusLive';
    case 'connecting':
      return 'statusConnecting';
    case 'resuming':
      return 'statusUnstable';
    case 'rejoining':
      return 'statusRejoining';
    case 'ended':
      return 'statusEnded';
    default:
      return 'statusIdle';
  }
}

/** Whether an API failure while rejoining should be tried again (the network, the server busy) or ends the live. */
export function retryableApiFailure(status: number, code: string): boolean {
  if (status === 0 || status >= 500 || status === 429) return code !== 'LIVE_HOSTING_UNAVAILABLE';
  return false;
}
