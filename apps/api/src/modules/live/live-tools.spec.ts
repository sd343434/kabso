import { randomBytes } from 'node:crypto';
import { describe, expect, it } from 'vitest';
import { loadConfig } from '../../config/app-config.js';
import { LiveKitMediaProvider } from './media/livekit-media.provider.js';
import {
  ATTR_MAIN_FEED,
  hostOfSecondCamera,
  musicRightsSchema,
  recordingSchema,
  redeemSecondCameraSchema,
  secondCameraIdentity,
  secondCameraMainSchema,
} from './live-tools.service.js';

const base = {
  DATABASE_URL: 'postgresql://u:p@localhost:5432/db',
  REDIS_URL: 'redis://localhost:6379',
  // Generated per run: never commit a secret-like literal (gitleaks).
  JWT_ACCESS_SECRET: randomBytes(48).toString('base64url'),
  APP_PUBLIC_URL: 'https://kabso.example/',
};

/** The JWT's claims (the signature is LiveKit's business; the grant is ours). */
function claims(jwt: string): Record<string, unknown> {
  const [, payload] = jwt.split('.');
  return JSON.parse(Buffer.from(payload!, 'base64url').toString('utf8')) as Record<string, unknown>;
}

describe('D201 live tools config (owner-confirmable defaults)', () => {
  it('codes last 120 s; 10 codes and 10 redemptions per 10 min; other tools 120 per 10 min', () => {
    const config = loadConfig(base);
    expect(config.live.secondCameraCodeSeconds).toBe(120);
    expect(config.rateLimits.liveSecondCameraCodeUser).toEqual({ max: 10, windowSeconds: 600 });
    expect(config.rateLimits.liveSecondCameraRedeemUser).toEqual({ max: 10, windowSeconds: 600 });
    expect(config.rateLimits.liveToolsUser).toEqual({ max: 120, windowSeconds: 600 });
  });

  it('LIVE_SECOND_CAMERA_CODE_SECONDS stays within 30–600', () => {
    expect(loadConfig({ ...base, LIVE_SECOND_CAMERA_CODE_SECONDS: '60' }).live.secondCameraCodeSeconds).toBe(
      60,
    );
    expect(() => loadConfig({ ...base, LIVE_SECOND_CAMERA_CODE_SECONDS: '5' })).toThrow();
    expect(() => loadConfig({ ...base, LIVE_SECOND_CAMERA_CODE_SECONDS: '3600' })).toThrow();
  });
});

describe('D201 second-camera identity', () => {
  const host = '0191f2a4-0000-7000-8000-00000000abcd';

  it('is cam2:<hostUserId> and maps back to the host only for a uuid', () => {
    expect(secondCameraIdentity(host)).toBe(`cam2:${host}`);
    expect(hostOfSecondCamera(`cam2:${host.toUpperCase()}`)).toBe(host);
    expect(hostOfSecondCamera(host)).toBeNull();
    expect(hostOfSecondCamera('cam2:not-a-user')).toBeNull();
    expect(hostOfSecondCamera(`pk:${host}:${host}`)).toBeNull();
    expect(hostOfSecondCamera(`guest:${host}`)).toBeNull();
  });
});

describe('D201 request bodies', () => {
  it('a code is exactly six digits; nothing else is accepted', () => {
    expect(redeemSecondCameraSchema.safeParse({ code: '012345' }).success).toBe(true);
    for (const code of ['12345', '1234567', '12a456', ' 123456', '١٢٣٤٥٦', 123456]) {
      expect(redeemSecondCameraSchema.safeParse({ code }).success).toBe(false);
    }
    expect(redeemSecondCameraSchema.safeParse({ code: '123456', roomId: 'x' }).success).toBe(false);
  });

  it('main is HOST or SECOND; recording is a boolean; the notice version is the current one', () => {
    expect(secondCameraMainSchema.safeParse({ main: 'SECOND' }).success).toBe(true);
    expect(secondCameraMainSchema.safeParse({ main: 'BOTH' }).success).toBe(false);
    expect(recordingSchema.safeParse({ active: true }).success).toBe(true);
    expect(recordingSchema.safeParse({ active: 'yes' }).success).toBe(false);
    expect(musicRightsSchema.safeParse({ noticeVersion: 1 }).success).toBe(true);
    expect(musicRightsSchema.safeParse({ noticeVersion: 2 }).success).toBe(false);
    expect(musicRightsSchema.safeParse({}).success).toBe(false);
  });
});

describe('D201 the second camera’s LiveKit token', () => {
  const provider = new LiveKitMediaProvider('ws://127.0.0.1:7880', 'devkey', randomBytes(32).toString('hex'));
  const room = '0191f2a4-0000-7000-8000-000000000001';

  it('joins that room only, publishes camera and microphone only, subscribes to nothing, no data', async () => {
    const jwt = await provider.issueToken({
      room,
      identity: 'cam2:0191f2a4-0000-7000-8000-00000000abcd',
      name: 'Host',
      publish: true,
      sources: ['camera', 'microphone'],
      subscribe: false,
      attributes: { [ATTR_MAIN_FEED]: 'HOST' },
      ttlSeconds: 600,
    });
    const c = claims(jwt);
    expect(c.sub).toBe('cam2:0191f2a4-0000-7000-8000-00000000abcd');
    expect(c.video).toEqual({
      roomJoin: true,
      room,
      canSubscribe: false,
      canPublish: true,
      canPublishData: false,
      canPublishSources: ['camera', 'microphone'],
    });
    expect(c.attributes).toEqual({ [ATTR_MAIN_FEED]: 'HOST' });
    expect((c.exp as number) - (c.nbf as number)).toBe(600);
  });

  it('other tokens keep subscribing (the default) and carry no attributes', async () => {
    const c = claims(
      await provider.issueToken({ room, identity: 'viewer', name: 'V', publish: false, ttlSeconds: 60 }),
    );
    expect(c.video).toMatchObject({ canSubscribe: true, canPublish: false, hidden: true });
    expect(c.attributes).toBeUndefined();
  });
});
