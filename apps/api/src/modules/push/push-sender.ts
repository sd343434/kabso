/**
 * v1.30-live (D152, CONVENTIONS §11.12): the port that delivers pushes. The real adapter is
 * Firebase Cloud Messaging ({@link FirebasePushSender}); without its key the {@link
 * DisabledPushSender} is used, and tests pass a fake. Nothing here ever logs a token or text.
 */

/** The Android notification channel (created by the app with the owner's sound). */
export type PushChannel = 'general' | 'messages';

/** The app's Android channel id for each push channel (CONVENTIONS §11.12). */
export const ANDROID_CHANNEL_ID: Readonly<Record<PushChannel, string>> = {
  general: 'kabso_general',
  messages: 'kabso_messages',
};

export interface PushMessage {
  /** FCM registration tokens (any number; the adapter sends in batches of 500). */
  readonly tokens: readonly string[];
  readonly channel: PushChannel;
  readonly title: string;
  readonly body: string;
  /** Android `tag`: a newer push with the same tag replaces the shown one. */
  readonly tag: string;
  /** String values only (FCM data). */
  readonly data: Readonly<Record<string, string>>;
}

export interface PushSendResult {
  readonly sent: number;
  readonly failed: number;
  /** Tokens Firebase answered as not registered or invalid: the caller deletes them. */
  readonly invalidTokens: readonly string[];
}

export interface PushSender {
  /** False when push is off (no key): callers skip all work. */
  readonly enabled: boolean;
  send(message: PushMessage): Promise<PushSendResult>;
}

export const PUSH_SENDER = Symbol('PUSH_SENDER');

/** Push is off: nothing is sent (no Firebase key on this server, or tests). */
export class DisabledPushSender implements PushSender {
  readonly enabled = false;

  send(message: PushMessage): Promise<PushSendResult> {
    return Promise.resolve({ sent: 0, failed: message.tokens.length, invalidTokens: [] });
  }
}
