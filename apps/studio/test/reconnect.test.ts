import { describe, expect, it } from 'vitest';
import { backoffMs, connLabel, nextConnState, retryableApiFailure, type ConnEvent, type ConnState } from '../src/reconnect';

const run = (events: ConnEvent[], from: ConnState = { kind: 'idle' }) => events.reduce(nextConnState, from);

describe('the reconnect state machine', () => {
  it('connects; a blip livekit resumes stays the same session', () => {
    expect(run([{ type: 'connect' }, { type: 'connected' }])).toEqual({ kind: 'connected' });
    const s = run([{ type: 'connect' }, { type: 'connected' }, { type: 'resuming' }]);
    expect(s).toEqual({ kind: 'resuming' });
    expect(connLabel(s)).toBe('statusUnstable');
    expect(run([{ type: 'resumed' }], s)).toEqual({ kind: 'connected' });
  });

  it('a lost session rejoins with a growing wait until it is back', () => {
    let s = run([{ type: 'connect' }, { type: 'connected' }, { type: 'lost' }]);
    expect(s).toEqual({ kind: 'rejoining', attempt: 1, delayMs: 1000 });
    s = run([{ type: 'rejoin-failed', retryable: true }, { type: 'rejoin-failed', retryable: true }], s);
    expect(s).toEqual({ kind: 'rejoining', attempt: 3, delayMs: 4000 });
    expect(connLabel(s)).toBe('statusRejoining');
    expect(run([{ type: 'connected' }], s)).toEqual({ kind: 'connected' });
    expect([1, 2, 3, 4, 5, 9].map(backoffMs)).toEqual([1000, 2000, 4000, 8000, 15000, 15000]);
  });

  it('the first join failing is a lost session too (connecting → rejoining)', () => {
    expect(run([{ type: 'connect' }, { type: 'lost' }])).toMatchObject({ kind: 'rejoining', attempt: 1 });
  });

  it('ends for the host, the server, a refused session or hosting turned off — and stays ended', () => {
    const live = run([{ type: 'connect' }, { type: 'connected' }]);
    expect(run([{ type: 'host-ended' }], live)).toEqual({ kind: 'ended', reason: 'host' });
    expect(run([{ type: 'room-ended' }], live)).toEqual({ kind: 'ended', reason: 'server' });
    expect(run([{ type: 'signed-out' }], live)).toEqual({ kind: 'ended', reason: 'auth' });
    expect(run([{ type: 'hosting-off' }], live)).toEqual({ kind: 'ended', reason: 'hosting-off' });
    expect(run([{ type: 'lost' }, { type: 'rejoin-failed', retryable: false }], live)).toEqual({ kind: 'ended', reason: 'server' });
    const ended = run([{ type: 'host-ended' }], live);
    expect(run([{ type: 'lost' }, { type: 'connected' }], ended)).toBe(ended);
    expect(run([{ type: 'reset' }], ended)).toEqual({ kind: 'idle' });
    // `lost` before any join changes nothing.
    expect(run([{ type: 'lost' }])).toEqual({ kind: 'idle' });
  });

  it('which API failures are worth another try', () => {
    expect(retryableApiFailure(0, 'NETWORK')).toBe(true);
    expect(retryableApiFailure(503, 'SERVICE_UNAVAILABLE')).toBe(true);
    expect(retryableApiFailure(429, 'RATE_LIMITED')).toBe(true);
    expect(retryableApiFailure(503, 'LIVE_HOSTING_UNAVAILABLE')).toBe(false);
    expect(retryableApiFailure(409, 'LIVE_ROOM_ENDED')).toBe(false);
    expect(retryableApiFailure(403, 'LIVE_KICKED')).toBe(false);
  });
});
