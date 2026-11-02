/** The API shapes the studio reads (docs/contracts/openapi.yaml; only the fields it uses). */

export interface UserSummary {
  id: string;
  username: string;
  displayName: string;
  avatarUrl: string | null;
}

export interface Me extends UserSummary {
  email: string;
  locale: 'ar' | 'en';
  canHost: boolean;
}

export interface AuthResponse {
  user: Me;
  tokens: import('./session').TokenPair;
}

export interface LiveConfig {
  hostingEnabled: boolean;
  heartbeatIntervalSeconds: number;
  heartbeatStaleAfterSeconds: number;
}

export type StreamerOrientation = 'PORTRAIT' | 'LANDSCAPE';
export type StreamerCorner = 'TOP_LEFT' | 'TOP_RIGHT' | 'BOTTOM_LEFT' | 'BOTTOM_RIGHT';
/** v1.57-live (D247, CONVENTIONS §10.88). */
export type StreamerMain = 'SCREEN' | 'CAMERA';

export interface LiveStreamer {
  orientation: StreamerOrientation;
  cameraOverlay: { visible: boolean; corner: StreamerCorner };
  main: StreamerMain;
  version: number;
}

export interface LiveRoom {
  id: string;
  title: string;
  mode: string;
  status?: 'LIVE' | 'ENDED';
  viewerCount: number;
  startedAt: string;
  host: UserSummary;
  chatEnabled?: boolean;
  endReason?: string | null;
  streamer: LiveStreamer | null;
}

export interface LiveMediaAccess {
  url: string;
  token: string;
  expiresAt: string;
  role: 'HOST' | 'VIEWER' | 'SPEAKER';
  identity: string;
}

export interface LiveChatMessage {
  id: string;
  roomId: string;
  author: UserSummary;
  authorRole: 'HOST' | 'MODERATOR' | 'SPEAKER' | 'VIEWER';
  kind: 'TEXT' | 'VOICE' | 'IMAGE';
  text: string;
  expiresAt: string | null;
  createdAt: string;
}

export interface LiveGift {
  id: string;
  roomId: string;
  giftCode: string;
  imageUrl: string | null;
  unitPrice: number;
  quantity: number;
  totalCoins: number;
  sender: UserSummary;
  recipients: UserSummary[];
  combo: { id: string; count: number; quantity: number };
  createdAt: string;
}

export interface GiftCatalogue {
  version: string;
  data: { code: string; name: string; imageUrl: string | null; priceCoins: number }[];
}

export interface PublicProfile {
  username: string;
  liveRoomId?: string | null;
}
