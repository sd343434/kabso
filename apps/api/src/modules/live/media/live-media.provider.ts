/** Injection token of the {@link LiveMediaProvider} (CP-010, D3). */
export const LIVE_MEDIA_PROVIDER = Symbol('LIVE_MEDIA_PROVIDER');

/** What a media-session event tells the API (CONVENTIONS §10.8). */
export type LiveMediaEvent =
  | { readonly kind: 'joined' | 'left'; readonly room: string; readonly identity: string }
  | { readonly kind: 'room_finished'; readonly room: string }
  | { readonly kind: 'ignored' };

export interface LiveMediaTokenInput {
  /** The media room: the live room's id. */
  readonly room: string;
  /** A user id, or `guest:<guestId>`. */
  readonly identity: string;
  readonly name: string;
  /** Host: camera and microphone only. Otherwise watch only, hidden from other viewers. */
  readonly publish: boolean;
  readonly ttlSeconds: number;
}

/**
 * The live media server behind a port (CP-010, D3: LiveKit). Rooms are named by the live room
 * id. Calls that reach the server throw on failure; callers decide whether that is fatal.
 */
export interface LiveMediaProvider {
  /** The URL clients connect to (`ws(s)://`). */
  readonly url: string;
  issueToken(input: LiveMediaTokenInput): Promise<string>;
  /** Disconnects everyone and deletes the room; a missing room is not an error. */
  closeRoom(room: string): Promise<void>;
  /** Disconnects one participant; a missing participant or room is not an error. */
  removeParticipant(room: string, identity: string): Promise<void>;
  /** Names of the rooms the server has open. */
  listRooms(): Promise<string[]>;
  /** Identities connected to a room (hidden viewers included); [] when the room is gone. */
  listIdentities(room: string): Promise<string[]>;
  /** Verifies a signed webhook and maps it; throws when the signature or body is invalid. */
  parseWebhook(rawBody: string, authorization: string | undefined): Promise<LiveMediaEvent>;
}
