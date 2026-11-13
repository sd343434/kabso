/**
 * D341 (owner, contract v1.106-social, CONVENTIONS §10.140): the direct share «تفعّل من خلالنا دون وكيل», end to end
 * against PostgreSQL + Redis with the API as the DML-only runtime role:
 *
 *  - a direct host (the hosting permission, no ACTIVE agency membership) receives 70 % of a normal gift
 *    (1 000 000 coins → 7 000 000 cherries); a direct content creator in their own live 75 % (→ 7 500 000);
 *  - a host in an agency keeps 65 % (→ 6 500 000) and the agency's 15 % commission on top is unchanged (975 000);
 *    a creator in an agency keeps 70 % (→ 7 000 000, commission 1 050 000);
 *  - a host who left their agency is direct from then on; the rate is read at the send;
 *  - one share per send: a send that also reaches an agency member or a guest without the hosting permission keeps
 *    the ordinary share; a send to two direct hosts takes 70 %;
 *  - quips (50 %), lucky (the lucky share) and custom gifts (60 %) keep their own rules for a direct host.
 */
import { randomUUID } from 'node:crypto';
import sharp from 'sharp';
import { afterAll, beforeAll, describe, expect, it, vi } from 'vitest';
import { addGiftIn, type GiftFields } from '../src/modules/gifts/gift-catalogue.js';
import { activateCreatorIn } from '../src/modules/creator/creator-membership.js';
import { LIVE_MEDIA_PROVIDER } from '../src/modules/live/media/live-media.provider.js';
import { OBJECT_STORAGE } from '../src/modules/media/object-storage.js';
import { creditIn } from '../src/modules/wallet/wallet-ledger.js';
import { MemoryLiveMedia } from './helpers/memory-live-media.js';
import { MemoryObjectStorage } from './helpers/memory-storage.js';
import { createTestApp, registerVerified, type TestContext } from './helpers/test-app.js';

interface TestUser {
  readonly id: string;
  readonly username: string;
  readonly token: string;
}

describe('D341 the direct share', { timeout: 900_000 }, () => {
  const storage = new MemoryObjectStorage();
  let ctx: TestContext;
  let png: Buffer;
  const clock = Date.parse('2027-04-13T09:00:00.000Z');
  const auth = (u: { token: string }) => ({ Authorization: `Bearer ${u.token}` });

  const signup = async (): Promise<TestUser> => {
    const { res } = await registerVerified(ctx);
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    return {
      id: res.body.user.id as string,
      username: res.body.user.username as string,
      token: res.body.tokens.accessToken as string,
    };
  };
  const coins = (u: TestUser, amount: bigint) =>
    ctx.prisma.$transaction((tx) => creditIn(tx, u.id, amount, 'ADMIN_GRANT', randomUUID()));
  const received = async (u: TestUser, giftId: string) =>
    (
      await ctx.prisma.cherryLedgerEntry.findFirst({
        where: { userId: u.id, referenceId: giftId, reason: 'GIFT_RECEIVED' },
      })
    )?.delta ?? 0n;
  const commissionOf = async (u: TestUser, giftId: string) =>
    (
      await ctx.prisma.cherryLedgerEntry.findFirst({
        where: { userId: u.id, referenceId: giftId, reason: 'AGENCY_COMMISSION' },
      })
    )?.delta ?? 0n;

  // ---- hosts, creators, agencies ----------------------------------------------------------------------------
  const makeHost = (u: TestUser, source: 'ADMIN' | 'IDENTITY' | 'AGENCY' = 'ADMIN') =>
    ctx.prisma.liveHost.create({ data: { userId: u.id, source } });
  /** A creator approved by the team (APPLICATION) or activated by an agency (AGENCY). */
  const makeCreator = async (u: TestUser, agencyId: string | null = null) => {
    const applicationId = randomUUID();
    const now = new Date(clock);
    await ctx.prisma.$transaction(async (tx) => {
      await tx.creatorApplication.create({
        data: {
          id: applicationId,
          userId: u.id,
          status: 'APPROVED',
          source: agencyId === null ? 'APPLICATION' : 'AGENCY',
          agencyId,
          country: 'EG',
          category: 'COMEDY',
          links: ['https://www.tiktok.com/@creator'],
          createdAt: now,
          decidedAt: now,
        },
      });
      await activateCreatorIn(tx, {
        userId: u.id,
        applicationId,
        now,
        by: { via: 'cli', actorUserId: null },
      });
    });
  };
  const upload = async (u: TestUser, kind: string): Promise<string> => {
    const slot = await ctx.http
      .post('/api/v1/media/uploads')
      .set(auth(u))
      .send({ kind, contentType: 'image/png', byteSize: png.length });
    expect(slot.status, JSON.stringify(slot.body)).toBe(201);
    expect(storage.upload(slot.body.uploadUrl as string, png, 'image/png')).toBe(true);
    return slot.body.uploadId as string;
  };
  const openAgency = async (u: TestUser) => {
    const photoUploadId = await upload(u, 'RECHARGE_AGENT_PHOTO');
    const selfieUploadId = await upload(u, 'RECHARGE_AGENT_SELFIE');
    const res = await ctx.http
      .post('/api/v1/me/agency/open')
      .set(auth(u))
      .set('Idempotency-Key', randomUUID())
      .send({
        name: `وكالة ${u.username.slice(0, 10)}`,
        country: 'SA',
        contact: { type: 'WHATSAPP', value: '+966500000001' },
        expectedHosts: 5,
        photoUploadId,
        selfieUploadId,
      });
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    return ctx.prisma.agency.findUniqueOrThrow({ where: { ownerUserId: u.id } });
  };
  const joinAgency = async (u: TestUser, inviteCode: string) => {
    const res = await ctx.http
      .post('/api/v1/me/agency/join')
      .set(auth(u))
      .set('Idempotency-Key', randomUUID())
      .send({ inviteCode });
    expect(res.status, JSON.stringify(res.body)).toBeLessThan(300);
  };

  // ---- lives and gifts -----------------------------------------------------------------------------------------
  const gift = (code: string, fields: Partial<GiftFields>) =>
    ctx.prisma.$transaction((tx) =>
      addGiftIn(tx, code, {
        category: 'POPULAR',
        nameAr: 'هدية',
        nameEn: 'Gift',
        priceCoins: 10_000,
        assetKey: `gift_${code}`,
        animationKey: null,
        sortOrder: 0,
        badge: 'NONE',
        tagCode: null,
        tagNameAr: null,
        tagNameEn: null,
        ...fields,
      }),
    );
  const goLive = async (u: TestUser) => {
    const res = await ctx.http
      .post('/api/v1/live/rooms')
      .set(auth(u))
      .send({ title: 'D341', mode: 'AUDIO', seatCount: 10 });
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    return res.body.id as string;
  };
  const endLive = async (u: TestUser) => {
    await ctx.prisma.liveRoom.updateMany({
      where: { hostUserId: u.id, status: 'LIVE' },
      data: { status: 'ENDED', endedAt: new Date(clock), endReason: 'HOST_ENDED' },
    });
  };
  const enter = async (roomId: string, u: TestUser) => {
    const raw = JSON.stringify({
      event: 'participant_joined',
      room: { name: roomId },
      participant: { identity: u.id },
    });
    const res = await ctx.http
      .post('/internal/livekit/webhook')
      .set('Content-Type', 'application/webhook+json')
      .set('Authorization', MemoryLiveMedia.sign(raw))
      .send(raw);
    expect(res.status).toBe(200);
  };
  let seatIndex = 0;
  const seat = async (roomId: string, u: TestUser) => {
    await enter(roomId, u);
    seatIndex += 1;
    await ctx.prisma.liveRoomSeat.create({ data: { roomId, seatIndex: (seatIndex % 9) + 1, userId: u.id } });
  };
  const send = async (roomId: string, from: TestUser, to: TestUser[], code: string, quantity = 1) => {
    const clientId = randomUUID();
    const res = await ctx.http
      .post(`/api/v1/live/rooms/${roomId}/gifts`)
      .set(auth(from))
      .send({ giftCode: code, quantity, recipients: to.map((u) => u.username), source: 'COINS', clientId });
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    return ctx.prisma.liveGift.findFirstOrThrow({ where: { senderId: from.id, clientId } });
  };

  let fan: TestUser;
  let designer: TestUser;
  const ROSE = 'd341_rose';
  const FUN = 'd341_fun';
  const QUIP = 'd341_quip';
  const LUCKY = 'd341_lucky';
  const CUSTOM = 'd341_custom';

  beforeAll(async () => {
    png = await sharp({
      create: { width: 64, height: 64, channels: 3, background: { r: 30, g: 120, b: 200 } },
    })
      .png()
      .toBuffer();
    vi.useFakeTimers({ toFake: ['Date'], now: clock });
    ctx = await createTestApp(
      {
        LIVE_HOSTING_ENABLED: 'true',
        LIVE_HEARTBEAT_STALE_SECONDS: '3600',
        LIVE_GIFT_QUANTITIES: '1,5,10,100',
        LUCKY_GIFTS_ENABLED: 'true',
        MEDIA_UPLOADS_ENABLED: 'true',
        S3_BUCKET: 'kabso-media-test',
        S3_ACCESS_KEY_ID: 'test',
        S3_SECRET_ACCESS_KEY: 'test',
        MEDIA_PUBLIC_BASE_URL: 'https://media.example.test',
        LIVE_RANKINGS_TIME_ZONE: 'UTC',
        AGENCY_SWEEP_INTERVAL_SECONDS: '0',
        RECHARGE_AGENT_SWEEP_INTERVAL_SECONDS: '0',
        SPECIAL_USERNAME_SWEEP_INTERVAL_SECONDS: '0',
        RATE_LIMIT_AGENCY_OPEN_USER: '1000/900',
        RATE_LIMIT_LIVE_GIFT_USER: '10000/60',
        JWT_ACCESS_TTL_SECONDS: String(60 * 86_400),
        REFRESH_TTL_SECONDS: String(60 * 86_400),
        REFRESH_ABSOLUTE_TTL_SECONDS: String(60 * 86_400),
      },
      [
        { token: OBJECT_STORAGE, value: storage },
        { token: LIVE_MEDIA_PROVIDER, value: new MemoryLiveMedia() },
      ],
    );
    fan = await signup();
    designer = await signup();
    await coins(fan, 100_000_000n);
    const adult = await ctx.http
      .put('/api/v1/me/lucky-gifts/age-confirmation')
      .set(auth(fan))
      .send({ adult: true });
    expect(adult.status).toBe(200);
    await gift(ROSE, {});
    await gift(FUN, { category: 'FUN' });
    await gift(QUIP, {
      category: 'QUIPS',
      priceCoins: 100,
      soundKey: 'room/clap',
      soundMs: 500,
      quipText: null,
    });
    await gift(LUCKY, { category: 'LUCKY', priceCoins: 100 });
    await gift(CUSTOM, { category: 'CUSTOM', priceCoins: 10_000, ownerUserId: designer.id });
  });
  afterAll(async () => {
    await ctx?.close();
    vi.useRealTimers();
  });

  it('the configuration defaults to the owner’s 70 % (direct host) and 75 % (direct creator)', () => {
    expect(ctx.config.gifts.directHostShareBps).toBe(7_000);
    expect(ctx.config.gifts.directCreatorShareBps).toBe(7_500);
  });

  it('a direct host: 1 000 000 coins → 7 000 000 cherries (an admin’s grant or the team’s approval alike)', async () => {
    for (const source of ['ADMIN', 'IDENTITY'] as const) {
      const host = await signup();
      await makeHost(host, source);
      const room = await goLive(host);
      await enter(room, fan);
      const s = await send(room, fan, [host], ROSE, 100);
      expect(s.totalCoins).toBe(1_000_000n);
      expect(s.hostShareBps).toBe(7_000);
      expect(await received(host, s.id)).toBe(7_000_000n);
      // Every normal category (FUN too).
      const fun = await send(room, fan, [host], FUN, 100);
      expect(fun.hostShareBps).toBe(7_000);
      expect(await received(host, fun.id)).toBe(7_000_000n);
      // No agency: no commission rows.
      expect(await ctx.prisma.agencyEarning.count({ where: { giftId: s.id } })).toBe(0);
      await endLive(host);
    }
  });

  it('a direct content creator in their own live: 1 000 000 coins → 7 500 000 cherries', async () => {
    const creator = await signup();
    await makeCreator(creator);
    const room = await goLive(creator);
    await enter(room, fan);
    const s = await send(room, fan, [creator], ROSE, 100);
    expect(s.hostShareBps).toBe(7_500);
    expect(await received(creator, s.id)).toBe(7_500_000n);
    // Quips keep the creator quip share (60 %), lucky the lucky share.
    const quip = await send(room, fan, [creator], QUIP);
    expect(quip.hostShareBps).toBe(6_000);
    const lucky = await send(room, fan, [creator], LUCKY);
    expect(lucky.hostShareBps).toBe(ctx.config.lucky.table.hostShareBps);
    await endLive(creator);
  });

  it('a host in an agency keeps 65 % (→ 6 500 000) and the agency commission is unchanged; after leaving, 70 %', async () => {
    const agent = await signup();
    const agency = await openAgency(agent);
    const host = await signup();
    await makeHost(host, 'ADMIN');
    await joinAgency(host, agency.inviteCode);
    const room = await goLive(host);
    await enter(room, fan);
    const s = await send(room, fan, [host], ROSE, 100);
    expect(s.hostShareBps).toBe(6_500);
    expect(await received(host, s.id)).toBe(6_500_000n);
    // 15 % of the host's cherries, on top, from the platform's part.
    expect(await commissionOf(agent, s.id)).toBe(975_000n);
    const earning = await ctx.prisma.agencyEarning.findFirstOrThrow({ where: { giftId: s.id } });
    expect(earning).toMatchObject({ hostCherries: 6_500_000n, rateBps: 1_500, commission: 975_000n });

    // The host leaves the agency (within the leave window): direct from the next send on, no commission.
    const left = await ctx.http.post('/api/v1/me/agency/leave').set(auth(host));
    expect(left.status, JSON.stringify(left.body)).toBe(200);
    const after = await send(room, fan, [host], ROSE, 100);
    expect(after.hostShareBps).toBe(7_000);
    expect(await received(host, after.id)).toBe(7_000_000n);
    expect(await commissionOf(agent, after.id)).toBe(0n);
    // The earlier send keeps its stored share.
    expect((await ctx.prisma.liveGift.findUniqueOrThrow({ where: { id: s.id } })).hostShareBps).toBe(6_500);
    await endLive(host);
  });

  it('a creator in an agency keeps 70 % (→ 7 000 000) and its agency commission (1 050 000)', async () => {
    const agent = await signup();
    const agency = await openAgency(agent);
    const creator = await signup();
    await joinAgency(creator, agency.inviteCode);
    await makeCreator(creator, agency.id);
    const room = await goLive(creator);
    await enter(room, fan);
    const s = await send(room, fan, [creator], ROSE, 100);
    expect(s.hostShareBps).toBe(7_000);
    expect(await received(creator, s.id)).toBe(7_000_000n);
    expect(await commissionOf(agent, s.id)).toBe(1_050_000n);
    await endLive(creator);
  });

  it('one share per send: every recipient must be direct', async () => {
    const agent = await signup();
    const agency = await openAgency(agent);
    const host = await signup();
    await makeHost(host);
    const room = await goLive(host);
    await enter(room, fan);
    // Two direct hosts (the host and a seated direct host): 70 % each.
    const directGuest = await signup();
    await makeHost(directGuest);
    await seat(room, directGuest);
    const both = await send(room, fan, [host, directGuest], ROSE, 10);
    expect(both.hostShareBps).toBe(7_000);
    expect(await received(host, both.id)).toBe(700_000n);
    expect(await received(directGuest, both.id)).toBe(700_000n);
    // A seated agency host among the recipients: the ordinary 65 % for everyone, commission on the agency host's part.
    const agencyGuest = await signup();
    await makeHost(agencyGuest);
    await joinAgency(agencyGuest, agency.inviteCode);
    await seat(room, agencyGuest);
    const mixed = await send(room, fan, [host, agencyGuest], ROSE, 10);
    expect(mixed.hostShareBps).toBe(6_500);
    expect(await received(host, mixed.id)).toBe(650_000n);
    expect(await received(agencyGuest, mixed.id)).toBe(650_000n);
    expect(await commissionOf(agent, mixed.id)).toBe(97_500n);
    // A seated guest without the hosting permission: not a host, so the ordinary 65 %.
    const plain = await signup();
    await seat(room, plain);
    const withPlain = await send(room, fan, [host, plain], ROSE, 10);
    expect(withPlain.hostShareBps).toBe(6_500);
    const toPlain = await send(room, fan, [plain], ROSE, 10);
    expect(toPlain.hostShareBps).toBe(6_500);
    await endLive(host);
  });

  it('quips, lucky and custom gifts keep their own rules for a direct host', async () => {
    const host = await signup();
    await makeHost(host);
    const room = await goLive(host);
    await enter(room, fan);
    const quip = await send(room, fan, [host], QUIP);
    expect(quip.hostShareBps).toBe(5_000);
    expect(await received(host, quip.id)).toBe(500n);
    const lucky = await send(room, fan, [host], LUCKY);
    expect(lucky.hostShareBps).toBe(ctx.config.lucky.table.hostShareBps);
    const custom = await send(room, fan, [host], CUSTOM, 10);
    expect(custom.hostShareBps).toBe(6_000);
    expect(await received(host, custom.id)).toBe(600_000n);
    await endLive(host);
  });
});
