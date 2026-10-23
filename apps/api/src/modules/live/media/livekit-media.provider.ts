import { AccessToken, RoomServiceClient, TrackSource, WebhookReceiver } from 'livekit-server-sdk';
import type { LiveMediaEvent, LiveMediaProvider, LiveMediaTokenInput } from './live-media.provider.js';

/** LiveKit's "not found" from the room service (a room or participant already gone). */
function isNotFound(err: unknown): boolean {
  const e = err as { status?: unknown; code?: unknown; message?: unknown } | null;
  const message = typeof e?.message === 'string' ? e.message : '';
  return e?.status === 404 || e?.code === 'not_found' || /not.?found|does not exist/i.test(message);
}

/**
 * {@link LiveMediaProvider} on LiveKit (D3): a local `livekit-server --dev` in development, LiveKit
 * Cloud in production (B1). Tokens grant one room; hosts may publish camera and microphone only;
 * viewers subscribe only and are hidden participants, so large rooms carry no viewer roster.
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
    token.addGrant({
      roomJoin: true,
      room: input.room,
      canSubscribe: true,
      canPublish: input.publish,
      canPublishData: false,
      ...(input.publish
        ? { canPublishSources: [TrackSource.CAMERA, TrackSource.MICROPHONE] }
        : { hidden: true }),
    });
    return token.toJwt();
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
}
