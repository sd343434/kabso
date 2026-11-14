/**
 * D350: the LiveKit provider sends its room-service calls to `apiUrl` (LIVEKIT_API_URL) while clients keep getting the
 * public `url`; without `apiUrl` both are the same URL, as before. A local HTTP server stands in for LiveKit's Twirp
 * endpoint and records the requests it gets.
 */
import { createServer, type IncomingMessage, type Server } from 'node:http';
import type { AddressInfo } from 'node:net';
import { AccessToken } from 'livekit-server-sdk';
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';
import { LiveKitMediaProvider } from './livekit-media.provider.js';

const KEY = 'APIunittest';
const SECRET = 'unit-test-secret-0123456789-abcdefghijklmnopqrstuvwxyz';

describe('LiveKitMediaProvider URLs and webhook check (D350)', () => {
  let server: Server;
  let base = '';
  let seen: { path: string; host: string; auth: string }[] = [];

  beforeAll(async () => {
    server = createServer((req: IncomingMessage, res) => {
      seen.push({ path: req.url ?? '', host: req.headers.host ?? '', auth: req.headers.authorization ?? '' });
      req.resume();
      res.setHeader('Content-Type', 'application/json');
      res.end('{}');
    });
    await new Promise<void>((resolve) => server.listen(0, '127.0.0.1', resolve));
    base = `127.0.0.1:${String((server.address() as AddressInfo).port)}`;
  });
  afterAll(async () => {
    await new Promise<void>((resolve) => server.close(() => resolve()));
  });
  beforeEach(() => {
    seen = [];
  });

  it('calls the room service on apiUrl and still hands clients the public url', async () => {
    const provider = new LiveKitMediaProvider('wss://media1.example.invalid', KEY, SECRET, `http://${base}`);
    expect(provider.url).toBe('wss://media1.example.invalid');
    expect(await provider.listIdentities('room-1')).toEqual([]);
    expect(seen).toHaveLength(1);
    expect(seen[0]?.host).toBe(base);
    expect(seen[0]?.path).toBe('/twirp/livekit.RoomService/ListParticipants');
    expect(seen[0]?.auth).toMatch(/^Bearer [\w-]+\.[\w-]+\.[\w-]+$/);
    provider.onModuleDestroy();
  });

  it('maps a ws:// apiUrl to http:// and, without apiUrl, uses the public url (the behaviour before D350)', async () => {
    const viaWs = new LiveKitMediaProvider('wss://media1.example.invalid', KEY, SECRET, `ws://${base}`);
    await viaWs.listIdentities('room-2');
    const same = new LiveKitMediaProvider(`ws://${base}`, KEY, SECRET);
    expect(same.url).toBe(`ws://${base}`);
    await same.listIdentities('room-3');
    expect(seen.map((s) => s.host)).toEqual([base, base]);
    viaWs.onModuleDestroy();
    same.onModuleDestroy();
  });

  it('accepts only a webhook signed with its own key pair over the exact body', async () => {
    const provider = new LiveKitMediaProvider('wss://media1.example.invalid', KEY, SECRET);
    const body = JSON.stringify({
      event: 'participant_joined',
      room: { name: 'r1' },
      participant: { identity: 'u1' },
    });
    const sign = async (key: string, secret: string, raw: string) => {
      const token = new AccessToken(key, secret, { ttl: 300 });
      const { createHash } = await import('node:crypto');
      token.sha256 = createHash('sha256').update(raw).digest('base64');
      return token.toJwt();
    };
    await expect(provider.parseWebhook(body, await sign(KEY, SECRET, body))).resolves.toEqual({
      kind: 'joined',
      room: 'r1',
      identity: 'u1',
    });
    await expect(provider.parseWebhook(body, await sign(KEY, `${SECRET}x`, body))).rejects.toThrow();
    await expect(provider.parseWebhook(body, await sign(`${KEY}x`, SECRET, body))).rejects.toThrow();
    await expect(provider.parseWebhook(`${body} `, await sign(KEY, SECRET, body))).rejects.toThrow();
    await expect(provider.parseWebhook(body, undefined)).rejects.toThrow();
    provider.onModuleDestroy();
  });
});
