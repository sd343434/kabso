import { createHash } from 'node:crypto';
import type {
  LiveMediaEvent,
  LiveMediaParticipant,
  LiveMediaPermission,
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
  /** CP-011: every permission change, in order. */
  readonly permissions: { room: string; identity: string; permission: LiveMediaPermission }[] = [];
  /** CP-011: room → current metadata. */
  readonly metadata = new Map<string, string>();
  /** CP-011: every metadata write, in order. */
  readonly metadataWrites: { room: string; metadata: string }[] = [];
  /** CP-011: data messages sent. */
  readonly data: { room: string; identity: string; payload: string }[] = [];
  /** CP-011: room → identity → current permission (unset: as the token granted, hidden viewer). */
  readonly current = new Map<string, Map<string, LiveMediaPermission>>();
  /** CP-011: when set, every seat-related call fails (best-effort paths must survive it). */
  failing = false;

  issueToken(input: LiveMediaTokenInput): Promise<string> {
    this.issued.push(input);
    return Promise.resolve(`token:${input.room}:${input.identity}:${input.publish ? 'pub' : 'sub'}`);
  }
  closeRoom(room: string): Promise<void> {
    this.closed.push(room);
    this.rooms.delete(room);
    this.metadata.delete(room);
    this.current.delete(room);
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

  listParticipants(room: string): Promise<LiveMediaParticipant[]> {
    if (this.failing) return Promise.reject(new Error('media server down'));
    return Promise.resolve(
      [...(this.rooms.get(room) ?? [])].map((identity) => ({
        identity,
        permission: this.current.get(room)?.get(identity) ?? { visible: false, sources: [] },
      })),
    );
  }
  setPermission(room: string, identity: string, permission: LiveMediaPermission): Promise<void> {
    if (this.failing) return Promise.reject(new Error('media server down'));
    this.permissions.push({ room, identity, permission });
    const map = this.current.get(room) ?? new Map<string, LiveMediaPermission>();
    map.set(identity, permission);
    this.current.set(room, map);
    return Promise.resolve();
  }
  roomMetadata(room: string): Promise<string | null> {
    if (this.failing) return Promise.reject(new Error('media server down'));
    return Promise.resolve(this.rooms.has(room) ? (this.metadata.get(room) ?? '') : null);
  }
  setRoomMetadata(room: string, metadata: string): Promise<void> {
    if (this.failing) return Promise.reject(new Error('media server down'));
    this.metadataWrites.push({ room, metadata });
    this.metadata.set(room, metadata);
    return Promise.resolve();
  }
  sendData(room: string, identity: string, payload: string): Promise<void> {
    if (this.failing) return Promise.reject(new Error('media server down'));
    this.data.push({ room, identity, payload });
    return Promise.resolve();
  }

  /** The last permission set for `identity` in `room`, if any. */
  lastPermission(room: string, identity: string): LiveMediaPermission | undefined {
    return this.permissions.filter((p) => p.room === room && p.identity === identity).at(-1)?.permission;
  }

  /** The signature header for `rawBody`. */
  static sign(rawBody: string): string {
    return `Bearer test:${createHash('sha256').update(rawBody).digest('hex')}`;
  }
}
