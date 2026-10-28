import { generateKeyPairSync, randomBytes } from 'node:crypto';
import { chmod, mkdir, mkdtemp, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { loadConfig } from '../../config/app-config.js';
import {
  CredentialsError,
  FirebasePushSender,
  isInvalidTokenCode,
  loadServiceAccount,
  type FcmMessaging,
} from './firebase-push-sender.js';
import { createPushSender } from './push.module.js';
import { DisabledPushSender } from './push-sender.js';
import { clip, notificationBody, who, type NotificationText } from './push-texts.js';

const base = {
  DATABASE_URL: 'postgresql://u:p@localhost:5432/db',
  REDIS_URL: 'redis://localhost:6379',
  // Generated per run: never commit a secret-like literal (gitleaks).
  JWT_ACCESS_SECRET: randomBytes(48).toString('base64url'),
  APP_PUBLIC_URL: 'https://kabso.example/',
};

/** A logger double that records what was logged (never the key). */
function recordingLogger() {
  const lines: { level: string; args: unknown[] }[] = [];
  return {
    lines,
    log: (...args: unknown[]) => lines.push({ level: 'log', args }),
    warn: (...args: unknown[]) => lines.push({ level: 'warn', args }),
    text: () => JSON.stringify(lines),
  };
}

let dir: string;
let privateKey: string;

beforeAll(async () => {
  dir = await mkdtemp(join(tmpdir(), 'kabso-push-'));
  // A throwaway key made for this run (the format of a service-account key; never a real one).
  privateKey = generateKeyPairSync('rsa', { modulusLength: 2048 }).privateKey.export({
    type: 'pkcs8',
    format: 'pem',
  }) as string;
});

afterAll(async () => {
  await rm(dir, { recursive: true, force: true });
});

async function keyFile(name: string, content: unknown): Promise<string> {
  const path = join(dir, name);
  await writeFile(path, typeof content === 'string' ? content : JSON.stringify(content));
  return path;
}

const account = () => ({
  type: 'service_account',
  project_id: 'kabso-test',
  client_email: 'push@kabso-test.iam.gserviceaccount.com',
  private_key: privateKey,
});

describe('D152 config', () => {
  it('defaults: push off (no key file), outbox every 2 s, gaps 5 s / 10 s', () => {
    const config = loadConfig(base);
    expect(config.push).toEqual({
      credentialsFile: null,
      dispatchIntervalMs: 2000,
      generalGapSeconds: 5,
      messagesGapSeconds: 10,
    });
  });

  it('reads FIREBASE_CREDENTIALS_FILE and the push settings', () => {
    const config = loadConfig({
      ...base,
      FIREBASE_CREDENTIALS_FILE: '/run/secrets/firebase-admin.json',
      PUSH_DISPATCH_INTERVAL_MS: '0',
      PUSH_GENERAL_GAP_SECONDS: '0',
      PUSH_MESSAGES_GAP_SECONDS: '30',
    });
    expect(config.push).toEqual({
      credentialsFile: '/run/secrets/firebase-admin.json',
      dispatchIntervalMs: 0,
      generalGapSeconds: 0,
      messagesGapSeconds: 30,
    });
  });
});

describe('loadServiceAccount', () => {
  it('reads a service-account key', async () => {
    const path = await keyFile('ok.json', account());
    await expect(loadServiceAccount(path)).resolves.toEqual({
      projectId: 'kabso-test',
      clientEmail: 'push@kabso-test.iam.gserviceaccount.com',
      privateKey,
    });
  });

  it.each([
    ['missing', async () => join(dir, 'nope.json')],
    // Docker creates an empty directory where a bind-mounted file is missing on the host.
    [
      'not_a_file',
      async () => {
        const path = join(dir, 'a-directory.json');
        await mkdir(path, { recursive: true });
        return path;
      },
    ],
    ['invalid', async () => keyFile('garbage.json', 'not json {')],
    ['invalid', async () => keyFile('user.json', { ...account(), type: 'authorized_user' })],
    ['invalid', async () => keyFile('nokey.json', { ...account(), private_key: '' })],
    ['too_large', async () => keyFile('big.json', 'x'.repeat(70_000))],
  ] as const)('%s', async (problem, make) => {
    const path = await make();
    const err = await loadServiceAccount(path).catch((e: unknown) => e);
    expect(err).toBeInstanceOf(CredentialsError);
    expect((err as CredentialsError).problem).toBe(problem);
    expect(String(err)).not.toContain('PRIVATE KEY');
  });

  it.skipIf(process.getuid?.() === 0)('unreadable (permissions)', async () => {
    const path = await keyFile('locked.json', account());
    await chmod(path, 0o000);
    const err = await loadServiceAccount(path).catch((e: unknown) => e);
    expect((err as CredentialsError).problem).toBe('unreadable');
  });
});

describe('createPushSender', () => {
  it('no FIREBASE_CREDENTIALS_FILE: off, one log line', async () => {
    const logger = recordingLogger();
    const sender = await createPushSender(loadConfig(base), logger as never);
    expect(sender).toBeInstanceOf(DisabledPushSender);
    expect(sender.enabled).toBe(false);
    expect(logger.lines).toHaveLength(1);
    expect(logger.text()).toContain('FIREBASE_CREDENTIALS_FILE is not set');
  });

  it('a missing key (a directory): off with the reason, never crashes', async () => {
    const path = join(dir, 'mounted-dir');
    await mkdir(path, { recursive: true });
    const logger = recordingLogger();
    const sender = await createPushSender(
      loadConfig({ ...base, FIREBASE_CREDENTIALS_FILE: path }),
      logger as never,
    );
    expect(sender.enabled).toBe(false);
    expect(logger.lines[0]?.level).toBe('warn');
    expect(logger.text()).toContain('not_a_file');
  });

  it('a valid key: on (firebase-admin starts offline), and the key is never logged', async () => {
    const path = await keyFile('valid.json', account());
    const logger = recordingLogger();
    const sender = await createPushSender(
      loadConfig({ ...base, FIREBASE_CREDENTIALS_FILE: path }),
      logger as never,
    );
    expect(sender).toBeInstanceOf(FirebasePushSender);
    expect(sender.enabled).toBe(true);
    expect(logger.text()).toContain('kabso-test');
    expect(logger.text()).not.toContain('PRIVATE KEY');
    expect(logger.text()).not.toContain(privateKey.slice(40, 80));
  });
});

describe('FirebasePushSender', () => {
  function fakeMessaging(fail: Record<string, string> = {}) {
    const calls: Parameters<FcmMessaging['sendEachForMulticast']>[0][] = [];
    const messaging: FcmMessaging = {
      sendEachForMulticast: (message) => {
        calls.push(message);
        const responses = message.tokens.map((t) =>
          fail[t] ? { success: false, error: { code: fail[t] } } : { success: true },
        );
        const failureCount = responses.filter((r) => !r.success).length;
        return Promise.resolve({ successCount: responses.length - failureCount, failureCount, responses });
      },
    };
    return { messaging, calls };
  }

  it('sends on the channel with the tag, in batches of 500, and reports invalid tokens', async () => {
    const tokens = Array.from({ length: 1001 }, (_, i) => `tok${i}`);
    const { messaging, calls } = fakeMessaging({
      tok3: 'messaging/registration-token-not-registered',
      tok600: 'messaging/invalid-registration-token',
      tok1000: 'messaging/internal-error',
    });
    const errors: Record<string, number>[] = [];
    const sender = new FirebasePushSender(messaging, (codes) => errors.push({ ...codes }));
    const res = await sender.send({
      tokens,
      channel: 'messages',
      title: 'Family',
      body: 'Sara: hi',
      tag: 'family:1',
      data: { kind: 'family_chat' },
    });
    expect(calls.map((c) => c.tokens.length)).toEqual([500, 500, 1]);
    expect(calls[0]!.android.notification).toEqual({ channelId: 'kabso_messages', tag: 'family:1' });
    expect(calls[0]!.android.collapseKey).toBe('family:1');
    expect(calls[0]!.android.priority).toBe('high');
    expect(calls[0]!.notification).toEqual({ title: 'Family', body: 'Sara: hi' });
    expect(calls[0]!.data).toEqual({ kind: 'family_chat' });
    expect(res).toEqual({ sent: 998, failed: 3, invalidTokens: ['tok3', 'tok600'] });
    // Codes and counts only, never a token.
    expect(errors).toEqual([
      {
        'messaging/registration-token-not-registered': 1,
        'messaging/invalid-registration-token': 1,
        'messaging/internal-error': 1,
      },
    ]);
  });

  it('general → kabso_general', async () => {
    const { messaging, calls } = fakeMessaging();
    await new FirebasePushSender(messaging).send({
      tokens: ['a'],
      channel: 'general',
      title: 't',
      body: 'b',
      tag: 'n:1',
      data: {},
    });
    expect(calls[0]!.android.notification.channelId).toBe('kabso_general');
  });

  it('only "not registered" and "invalid token" delete a token', () => {
    expect(isInvalidTokenCode('messaging/registration-token-not-registered')).toBe(true);
    expect(isInvalidTokenCode('messaging/invalid-registration-token')).toBe(true);
    expect(isInvalidTokenCode('messaging/internal-error')).toBe(false);
    expect(isInvalidTokenCode('messaging/quota-exceeded')).toBe(false);
    expect(isInvalidTokenCode(undefined)).toBe(false);
  });
});

describe('push texts', () => {
  const n = (over: Partial<NotificationText>): NotificationText => ({
    type: 'LIKE_POST',
    actorName: 'Sara',
    actorCount: 1,
    targetType: 'POST',
    targetId: 'p1',
    targetText: null,
    ...over,
  });

  it('the inbox sentences, en and ar', () => {
    expect(notificationBody(n({}), 'en')).toBe('Sara liked your post');
    expect(notificationBody(n({}), 'ar')).toBe('أعجب Sara بمنشورك');
    expect(notificationBody(n({ type: 'FOLLOW', targetType: 'USER' }), 'en')).toBe(
      'Sara started following you',
    );
    expect(notificationBody(n({ type: 'MENTION', targetType: 'STORY' }), 'ar')).toBe('أشار إليك Sara في قصة');
    expect(notificationBody(n({ type: 'MENTION', targetType: 'COMMENT' }), 'en')).toBe(
      'Sara mentioned you in a comment',
    );
    expect(
      notificationBody(n({ type: 'FAMILY_JOIN_ACCEPTED', targetType: 'FAMILY', targetText: 'Lions' }), 'en'),
    ).toBe("You're now a member of Lions");
    expect(notificationBody(n({ type: 'CONTENT_REMOVED', actorName: null, targetType: 'STORY' }), 'en')).toBe(
      'Your story was removed for breaking the community guidelines',
    );
    expect(
      notificationBody(
        n({
          type: 'PREMIUM_USERNAME_EXPIRING',
          actorName: null,
          targetType: 'PREMIUM_USERNAME',
          targetId: 'ace',
        }),
        'en',
      ),
    ).toBe('Your premium username @ace ends soon');
    expect(notificationBody(n({ type: 'MEDAL_AWARDED', actorName: null }), 'ar')).toBe(
      'حصلت على ميدالية جديدة',
    );
  });

  it('a group names the newest actor and counts the others (Arabic plural forms)', () => {
    expect(notificationBody(n({ actorCount: 2 }), 'en')).toBe('Sara and 1 other liked your post');
    expect(notificationBody(n({ actorCount: 5 }), 'en')).toBe('Sara and 4 others liked your post');
    expect(who('سارة', 1, 'ar')).toBe('سارة وشخص آخر');
    expect(who('سارة', 2, 'ar')).toBe('سارة وشخصان آخران');
    expect(who('سارة', 4, 'ar')).toBe('سارة و4 أشخاص آخرين');
    expect(who('سارة', 11, 'ar')).toBe('سارة و11 شخصًا آخر');
    expect(who('سارة', 100, 'ar')).toBe('سارة و100 شخص آخر');
  });

  it('an actor type without a visible actor, or an unknown type: nothing', () => {
    expect(notificationBody(n({ actorName: null }), 'en')).toBeNull();
    expect(notificationBody(n({ type: 'SOMETHING_NEW' }), 'en')).toBeNull();
  });

  it('a chat message is one line of at most 100 code points', () => {
    expect(clip('Sara:  hello\n\nthere')).toBe('Sara: hello there');
    const long = clip(`Sara: ${'😀'.repeat(200)}`);
    expect([...long]).toHaveLength(100);
    expect(long.endsWith('…')).toBe(true);
  });
});
