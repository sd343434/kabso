/** Injection token of the {@link LiveMediaProvider} (CP-010, D3). */
export const LIVE_MEDIA_PROVIDER = Symbol('LIVE_MEDIA_PROVIDER');

/** What a media-session event tells the API (CONVENTIONS §10.8). */
export type LiveMediaEvent =
  | { readonly kind: 'joined' | 'left'; readonly room: string; readonly identity: string }
  | { readonly kind: 'room_finished'; readonly room: string }
  | { readonly kind: 'ignored' };

/** A track source a participant may publish (CP-010 host, CP-011 seated guest). */
export type LiveMediaSource = 'camera' | 'microphone';

export interface LiveMediaTokenInput {
  /** The media room: the live room's id. */
  readonly room: string;
  /** A user id, or `guest:<guestId>`. */
  readonly identity: string;
  readonly name: string;
  /**
   * A publisher (host, or a seated guest): visible to the room. Otherwise watch only, hidden from
   * other viewers.
   */
  readonly publish: boolean;
  /**
   * CP-011: the sources a publisher may publish (default camera and microphone). Empty: visible
   * but publishing nothing (e.g. an AUDIO guest muted by the host).
   */
  readonly sources?: readonly LiveMediaSource[];
  readonly ttlSeconds: number;
}

/**
 * CP-011: what a joined participant may do now. `visible` false is a hidden viewer; `sources`
 * empty means no publishing at all.
 */
export interface LiveMediaPermission {
  readonly visible: boolean;
  readonly sources: readonly LiveMediaSource[];
}

/** CP-011: a connected participant and its current permission. */
export interface LiveMediaParticipant {
  readonly identity: string;
  readonly permission: LiveMediaPermission;
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

  // ---- CP-011 (seats) -------------------------------------------------------------------------

  /** Connected participants with their permissions; [] when the room is gone. */
  listParticipants(room: string): Promise<LiveMediaParticipant[]>;
  /**
   * Changes a joined participant's permission at once (no reconnect); a published track of a
   * source it may no longer publish is stopped (muted server-side). A missing participant or room
   * is not an error.
   */
  setPermission(room: string, identity: string, permission: LiveMediaPermission): Promise<void>;
  /** The room's metadata, or null when the room is not open. */
  roomMetadata(room: string): Promise<string | null>;
  /** Replaces the room's metadata; a room that is not open is not an error. */
  setRoomMetadata(room: string, metadata: string): Promise<void>;
  /**
   * Sends a reliable data message to one identity (best effort: LiveKit answers a room that is not
   * open with an error, which callers log and ignore).
   */
  sendData(room: string, identity: string, payload: string): Promise<void>;

  // ---- CP-013 (chat) --------------------------------------------------------------------------

  /**
   * Sends a reliable data message on `topic` to everyone in the room (no destination). Best effort
   * like {@link sendData}: a room that is not open answers with an error, which callers log and
   * ignore.
   */
  broadcastData(room: string, topic: string, payload: string): Promise<void>;
}
