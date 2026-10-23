/**
 * KL-063 / CP-010: the LiveKit adapter against a real LiveKit server. Runs only when
 * LIVEKIT_TEST_URL (plus LIVEKIT_TEST_API_KEY / LIVEKIT_TEST_API_SECRET) is set, e.g. against
 * `livekit-server --dev` (ws://127.0.0.1:7880, devkey / secret); skipped otherwise, like the S3
 * storage suite.
 */
import { createHash, randomUUID } from 'node:crypto';
import { AccessToken, RoomServiceClient, TokenVerifier } from 'livekit-server-sdk';
import { describe, expect, it } from 'vitest';
import { LiveKitMediaProvider } from '../src/modules/live/media/livekit-media.provider.js';

const url = process.env.LIVEKIT_TEST_URL;
const key = process.env.LIVEKIT_TEST_API_KEY ?? 'devkey';
const secret = process.env.LIVEKIT_TEST_API_SECRET ?? 'secret';

describe.skipIf(!url)('CP-010 LiveKit adapter against a real server', () => {
  const provider = new LiveKitMediaProvider(url ?? '', key, secret);
  const rooms = new RoomServiceClient((url ?? '').replace(/^ws/, 'http'), key, secret);

  it('tokens grant one room: hosts publish camera and microphone; viewers only watch, hidden', async () => {
    const room = randomUUID();
    const verifier = new TokenVerifier(key, secret);
    const host = await verifier.verify(
      await provider.issueToken({ room, identity: 'h', name: 'Host', publish: true, ttlSeconds: 600 }),
    );
    expect(host.video).toMatchObject({
      roomJoin: true,
      room,
      canPublish: true,
      canSubscribe: true,
      canPublishData: false,
    });
    expect(host.video?.canPublishSources?.sort()).toEqual(['camera', 'microphone']);
    expect(host.video?.hidden).toBeFalsy();
    const viewer = await verifier.verify(
      await provider.issueToken({
        room,
        identity: 'guest:x',
        name: 'Guest 1234',
        publish: false,
        ttlSeconds: 600,
      }),
    );
    expect(viewer.video).toMatchObject({ room, canPublish: false, canSubscribe: true, hidden: true });
    expect(viewer.sub).toBe('guest:x');
    expect((viewer.exp ?? 0) - (viewer.nbf ?? viewer.iat ?? 0)).toBeLessThanOrEqual(600);
  });

  it('lists, closes (idempotently) and removes on the real server', async () => {
    const room = randomUUID();
    await rooms.createRoom({ name: room, emptyTimeout: 60 });
    expect(await provider.listRooms()).toContain(room);
    expect(await provider.listIdentities(room)).toEqual([]);
    await provider.removeParticipant(room, 'nobody');
    await provider.closeRoom(room);
    expect(await provider.listRooms()).not.toContain(room);
    await provider.closeRoom(room);
    expect(await provider.listIdentities(room)).toEqual([]);
  });

  it('accepts only webhooks signed with the server key over the exact body', async () => {
    const body = JSON.stringify({
      id: 'EV_1',
      event: 'participant_joined',
      createdAt: String(Math.floor(Date.now() / 1000)),
      room: { name: 'r1' },
      participant: { identity: 'u1' },
    });
    const sign = async (payload: string, signingSecret: string) => {
      const token = new AccessToken(key, signingSecret);
      token.sha256 = createHash('sha256').update(payload).digest('base64');
      return token.toJwt();
    };
    expect(await provider.parseWebhook(body, await sign(body, secret))).toEqual({
      kind: 'joined',
      room: 'r1',
      identity: 'u1',
    });
    await expect(provider.parseWebhook(body, await sign(body, 'wrong-secret'))).rejects.toThrow();
    await expect(provider.parseWebhook(body.replace('u1', 'u2'), await sign(body, secret))).rejects.toThrow();
  });
});
