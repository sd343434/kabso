import { createHash } from 'node:crypto';
import type {
  LiveMediaEvent,
  LiveMediaProvider,
  LiveMediaTokenInput,
} from '../../src/modules/live/media/live-media.provider.js';

/**
 * An in-memory {@link LiveMediaProvider} (tests only): records issued tokens, open rooms and
 * connected identities, and accepts webhooks signed with `Bearer test:<sha256(body)>`, so specs
 * can drive joins and leaves as the media server would.
 */
export class MemoryLiveMedia implements LiveMediaProvider {
  readonly url = 'ws://media.test';
  readonly issued: LiveMediaTokenInput[] = [];
  readonly closed: string[] = [];
  readonly removed: { room: string; identity: string }[] = [];
  /** room → connected identities. */
  readonly rooms = new Map<string, Set<string>>();

  issueToken(input: LiveMediaTokenInput): Promise<string> {
    this.issued.push(input);
    return Promise.resolve(`token:${input.room}:${input.identity}:${input.publish ? 'pub' : 'sub'}`);
  }
  closeRoom(room: string): Promise<void> {
    this.closed.push(room);
    this.rooms.delete(room);
    return Promise.resolve();
  }
  removeParticipant(room: string, identity: string): Promise<void> {
    this.removed.push({ room, identity });
    this.rooms.get(room)?.delete(identity);
    return Promise.resolve();
  }
  listRooms(): Promise<string[]> {
    return Promise.resolve([...this.rooms.keys()]);
  }
  listIdentities(room: string): Promise<string[]> {
    return Promise.resolve([...(this.rooms.get(room) ?? [])]);
  }
  parseWebhook(rawBody: string, authorization: string | undefined): Promise<LiveMediaEvent> {
    const expected = `Bearer test:${createHash('sha256').update(rawBody).digest('hex')}`;
    if (authorization !== expected) return Promise.reject(new Error('bad signature'));
    const body = JSON.parse(rawBody) as {
      event: string;
      room?: { name?: string };
      participant?: { identity?: string };
    };
    const room = body.room?.name;
    if (!room) return Promise.resolve({ kind: 'ignored' });
    if (body.event === 'room_finished') return Promise.resolve({ kind: 'room_finished', room });
    const identity = body.participant?.identity;
    if ((body.event === 'participant_joined' || body.event === 'participant_left') && identity) {
      const set = this.rooms.get(room) ?? new Set<string>();
      if (body.event === 'participant_joined') set.add(identity);
      else set.delete(identity);
      this.rooms.set(room, set);
      return Promise.resolve({
        kind: body.event === 'participant_joined' ? 'joined' : 'left',
        room,
        identity,
      });
    }
    return Promise.resolve({ kind: 'ignored' });
  }

  /** The signature header for `rawBody`. */
  static sign(rawBody: string): string {
    return `Bearer test:${createHash('sha256').update(rawBody).digest('hex')}`;
  }
}
