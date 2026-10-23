import {
  AccessToken,
  DataPacket_Kind,
  RoomServiceClient,
  TrackSource,
  WebhookReceiver,
  type ParticipantInfo,
} from 'livekit-server-sdk';
import type {
  LiveMediaEvent,
  LiveMediaParticipant,
  LiveMediaPermission,
  LiveMediaProvider,
  LiveMediaSource,
  LiveMediaTokenInput,
} from './live-media.provider.js';

const ALL_SOURCES: readonly LiveMediaSource[] = ['camera', 'microphone'];

function toTrackSource(source: LiveMediaSource): TrackSource {
  return source === 'camera' ? TrackSource.CAMERA : TrackSource.MICROPHONE;
}

function fromTrackSource(source: TrackSource): LiveMediaSource | null {
  if (source === TrackSource.CAMERA) return 'camera';
  if (source === TrackSource.MICROPHONE) return 'microphone';
  return null;
}

/** The permission LiveKit reports, in the port's terms (an empty source list means "any"). */
function permissionOf(info: ParticipantInfo): LiveMediaPermission {
  const permission = info.permission;
  if (!permission) return { visible: true, sources: [] };
  const listed = permission.canPublishSources
    .map(fromTrackSource)
    .filter((s): s is LiveMediaSource => s !== null);
  return {
    visible: !permission.hidden,
    sources: permission.canPublish ? (permission.canPublishSources.length === 0 ? ALL_SOURCES : listed) : [],
  };
}

/** LiveKit's "not found" from the room service (a room or participant already gone). */
function isNotFound(err: unknown): boolean {
  const e = err as { status?: unknown; code?: unknown; message?: unknown } | null;
  const message = typeof e?.message === 'string' ? e.message : '';
  return e?.status === 404 || e?.code === 'not_found' || /not.?found|does not exist/i.test(message);
}

/**
 * {@link LiveMediaProvider} on LiveKit (D3): a local `livekit-server --dev` in development, LiveKit
 * Cloud in production (B1). Tokens grant one room; hosts may publish camera and microphone only
 * (an AUDIO host the microphone only, CP-011); viewers subscribe only and are hidden participants,
 * so large rooms carry no viewer roster. Seated guests (CP-011) get their permission changed in
 * place when they are seated, muted or taken off.
 */
export class LiveKitMediaProvider implements LiveMediaProvider {
  private readonly rooms: RoomServiceClient;
  private readonly webhooks: WebhookReceiver;

  constructor(
    readonly url: string,
    private readonly apiKey: string,
    private readonly apiSecret: string,
  ) {
    // The room service speaks HTTP(S) on the same host as the client WebSocket.
    this.rooms = new RoomServiceClient(url.replace(/^ws/, 'http'), apiKey, apiSecret);
    this.webhooks = new WebhookReceiver(apiKey, apiSecret);
  }

  async issueToken(input: LiveMediaTokenInput): Promise<string> {
    const token = new AccessToken(this.apiKey, this.apiSecret, {
      identity: input.identity,
      name: input.name,
      ttl: input.ttlSeconds,
    });
    // CP-011: a publisher with no source (an AUDIO guest muted by the host) is visible but may not
    // publish; LiveKit reads an empty source list as "any source", so it is never sent.
    const sources = input.publish ? (input.sources ?? ALL_SOURCES) : [];
    token.addGrant({
      roomJoin: true,
      room: input.room,
      canSubscribe: true,
      canPublish: sources.length > 0,
      canPublishData: false,
      ...(sources.length > 0 ? { canPublishSources: sources.map(toTrackSource) } : {}),
      ...(input.publish ? {} : { hidden: true }),
    });
    return token.toJwt();
  }

  /**
   * CP-011: the new permission applies at once. LiveKit stops a source that is no longer allowed;
   * a still-published track of such a source is also muted server-side, so a client that ignores
   * the change cannot keep sending it.
   */
  async setPermission(room: string, identity: string, permission: LiveMediaPermission): Promise<void> {
    let info: ParticipantInfo;
    try {
      info = await this.rooms.updateParticipant(room, identity, {
        permission: {
          canSubscribe: true,
          canPublish: permission.sources.length > 0,
          canPublishData: false,
          canPublishSources: permission.sources.map(toTrackSource),
          hidden: !permission.visible,
        },
      });
    } catch (err) {
      if (isNotFound(err)) return;
      throw err;
    }
    for (const track of info.tracks) {
      const source = fromTrackSource(track.source);
      if (track.muted || (source !== null && permission.sources.includes(source))) continue;
      try {
        await this.rooms.mutePublishedTrack(room, identity, track.sid, true);
      } catch (err) {
        if (!isNotFound(err)) throw err;
      }
    }
  }

  async listParticipants(room: string): Promise<LiveMediaParticipant[]> {
    try {
      return (await this.rooms.listParticipants(room)).map((p) => ({
        identity: p.identity,
        permission: permissionOf(p),
      }));
    } catch (err) {
      if (isNotFound(err)) return [];
      throw err;
    }
  }

  async roomMetadata(room: string): Promise<string | null> {
    const [found] = await this.rooms.listRooms([room]);
    return found ? found.metadata : null;
  }

  async setRoomMetadata(room: string, metadata: string): Promise<void> {
    try {
      await this.rooms.updateRoomMetadata(room, metadata);
    } catch (err) {
      if (!isNotFound(err)) throw err;
    }
  }

  async sendData(room: string, identity: string, payload: string): Promise<void> {
    await this.rooms.sendData(room, new TextEncoder().encode(payload), DataPacket_Kind.RELIABLE, {
      destinationIdentities: [identity],
    });
  }

  async closeRoom(room: string): Promise<void> {
    try {
      await this.rooms.deleteRoom(room);
    } catch (err) {
      if (!isNotFound(err)) throw err;
    }
  }

  async removeParticipant(room: string, identity: string): Promise<void> {
    try {
      await this.rooms.removeParticipant(room, identity);
    } catch (err) {
      if (!isNotFound(err)) throw err;
    }
  }

  async listRooms(): Promise<string[]> {
    return (await this.rooms.listRooms()).map((r) => r.name);
  }

  async listIdentities(room: string): Promise<string[]> {
    try {
      return (await this.rooms.listParticipants(room)).map((p) => p.identity);
    } catch (err) {
      if (isNotFound(err)) return [];
      throw err;
    }
  }

  async parseWebhook(rawBody: string, authorization: string | undefined): Promise<LiveMediaEvent> {
    const event = await this.webhooks.receive(rawBody, authorization);
    const room = event.room?.name;
    if (!room) return { kind: 'ignored' };
    switch (event.event) {
      case 'participant_joined':
      case 'participant_left': {
        const identity = event.participant?.identity;
        if (!identity) return { kind: 'ignored' };
        return { kind: event.event === 'participant_joined' ? 'joined' : 'left', room, identity };
      }
      case 'room_finished':
        return { kind: 'room_finished', room };
      default:
        return { kind: 'ignored' };
    }
  }
}

/** Used while LiveKit is not configured: hosting is off then, so nothing should reach it. */
export class UnconfiguredMediaProvider implements LiveMediaProvider {
  readonly url = '';
  private fail(): never {
    throw new Error('The live media server is not configured (LIVEKIT_*)');
  }
  issueToken(): Promise<string> {
    this.fail();
  }
  closeRoom(): Promise<void> {
    return Promise.resolve();
  }
  removeParticipant(): Promise<void> {
    return Promise.resolve();
  }
  listRooms(): Promise<string[]> {
    return Promise.resolve([]);
  }
  listIdentities(): Promise<string[]> {
    return Promise.resolve([]);
  }
  parseWebhook(): Promise<LiveMediaEvent> {
    this.fail();
  }
  listParticipants(): Promise<LiveMediaParticipant[]> {
    return Promise.resolve([]);
  }
  setPermission(): Promise<void> {
    return Promise.resolve();
  }
  roomMetadata(): Promise<string | null> {
    return Promise.resolve(null);
  }
  setRoomMetadata(): Promise<void> {
    return Promise.resolve();
  }
  sendData(): Promise<void> {
    return Promise.resolve();
  }
}
