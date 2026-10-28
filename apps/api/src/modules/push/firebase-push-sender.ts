import { readFile, stat } from 'node:fs/promises';
import { ANDROID_CHANNEL_ID, type PushMessage, type PushSendResult, type PushSender } from './push-sender.js';

/** FCM accepts at most 500 tokens per multicast. */
const BATCH = 500;
/** A service-account key is a few KB; anything this large is not one. */
const MAX_KEY_BYTES = 64 * 1024;
/** Messages are useless after a while (a chat after a day, a like after a few hours). */
const TTL_MS: Readonly<Record<PushMessage['channel'], number>> = {
  general: 6 * 3600_000,
  messages: 24 * 3600_000,
};

/** The parts of a Firebase service-account key the Admin SDK needs. */
export interface FirebaseServiceAccount {
  readonly projectId: string;
  readonly clientEmail: string;
  readonly privateKey: string;
}

/** Why the key could not be used (logged; never the file's content). */
export type CredentialsProblem = 'missing' | 'not_a_file' | 'unreadable' | 'too_large' | 'invalid';

export class CredentialsError extends Error {
  constructor(readonly problem: CredentialsProblem) {
    super(`Firebase credentials ${problem}`);
    this.name = 'CredentialsError';
  }
}

/**
 * Reads the service-account key at `path` (D152). Docker creates an empty **directory** where a
 * bind-mounted file is missing on the host, so a directory is a normal "no key" case. Throws a
 * {@link CredentialsError}; the message never contains the file's content.
 */
export async function loadServiceAccount(path: string): Promise<FirebaseServiceAccount> {
  let info;
  try {
    info = await stat(path);
  } catch (err) {
    throw new CredentialsError((err as NodeJS.ErrnoException).code === 'EACCES' ? 'unreadable' : 'missing');
  }
  if (!info.isFile()) throw new CredentialsError('not_a_file');
  if (info.size > MAX_KEY_BYTES) throw new CredentialsError('too_large');
  let text: string;
  try {
    text = await readFile(path, 'utf8');
  } catch {
    throw new CredentialsError('unreadable');
  }
  let json: unknown;
  try {
    json = JSON.parse(text);
  } catch {
    throw new CredentialsError('invalid');
  }
  const key = json as Record<string, unknown> | null;
  const field = (name: string): string | null => {
    const v = key?.[name];
    return typeof v === 'string' && v.length > 0 ? v : null;
  };
  const projectId = field('project_id');
  const clientEmail = field('client_email');
  const privateKey = field('private_key');
  if (key?.type !== 'service_account' || !projectId || !clientEmail || !privateKey) {
    throw new CredentialsError('invalid');
  }
  return { projectId, clientEmail, privateKey };
}

/** The FCM error codes that mean "this token will never work again": delete it. */
export function isInvalidTokenCode(code: string | undefined): boolean {
  if (!code) return false;
  return code.endsWith('registration-token-not-registered') || code.endsWith('invalid-registration-token');
}

/** The slice of firebase-admin's Messaging this adapter uses (a seam for unit tests). */
export interface FcmMessaging {
  sendEachForMulticast(message: {
    tokens: string[];
    notification: { title: string; body: string };
    data: Record<string, string>;
    android: {
      priority: 'high';
      ttl: number;
      collapseKey: string;
      notification: { channelId: string; tag: string };
    };
  }): Promise<{
    successCount: number;
    failureCount: number;
    responses: { success: boolean; error?: { code: string } }[];
  }>;
}

/**
 * Firebase Cloud Messaging (firebase-admin, Apache-2.0; D152). One Android notification per
 * message on the app's channel (`kabso_general` / `kabso_messages`, whose sound the app set), with
 * the `tag` replacing an earlier one. Error codes are counted, never tokens or text.
 */
export class FirebasePushSender implements PushSender {
  readonly enabled = true;

  constructor(
    private readonly messaging: FcmMessaging,
    private readonly onErrors: (codes: Readonly<Record<string, number>>) => void = () => undefined,
  ) {}

  async send(message: PushMessage): Promise<PushSendResult> {
    let sent = 0;
    let failed = 0;
    const invalidTokens: string[] = [];
    const codes: Record<string, number> = {};
    for (let i = 0; i < message.tokens.length; i += BATCH) {
      const tokens = message.tokens.slice(i, i + BATCH);
      const res = await this.messaging.sendEachForMulticast({
        tokens,
        notification: { title: message.title, body: message.body },
        data: { ...message.data },
        android: {
          priority: 'high',
          ttl: TTL_MS[message.channel],
          collapseKey: message.tag,
          notification: { channelId: ANDROID_CHANNEL_ID[message.channel], tag: message.tag },
        },
      });
      sent += res.successCount;
      failed += res.failureCount;
      res.responses.forEach((r, index) => {
        if (r.success) return;
        const code = r.error?.code ?? 'unknown';
        codes[code] = (codes[code] ?? 0) + 1;
        const token = tokens[index];
        if (token !== undefined && isInvalidTokenCode(code)) invalidTokens.push(token);
      });
    }
    if (failed > 0) this.onErrors(codes);
    return { sent, failed, invalidTokens };
  }
}

/**
 * Starts firebase-admin with the key (loaded on demand, so a server without push never loads the
 * SDK). The app instance is named, so nothing else can pick it up as the default.
 */
export async function createFirebaseMessaging(account: FirebaseServiceAccount): Promise<FcmMessaging> {
  const { cert, initializeApp, getApps } = await import('firebase-admin/app');
  const { getMessaging } = await import('firebase-admin/messaging');
  const name = 'kabso-push';
  const app =
    getApps().find((a) => a.name === name) ??
    initializeApp(
      {
        credential: cert({
          projectId: account.projectId,
          clientEmail: account.clientEmail,
          privateKey: account.privateKey,
        }),
        projectId: account.projectId,
      },
      name,
    );
  return getMessaging(app);
}
