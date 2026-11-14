/**
 * D334 (owner answers 2026-11-09; contract v1.102-social, CONVENTIONS §10.127.11): the events v2 follow-ups.
 * 1. Content creators count as hosts (HOSTS audience, the D166 HOSTS board) on the events made after it; hosts are not
 *    creators (CREATORS stays creator members only); an older event keeps D295's rule.
 * 2. An event of any audience may have its Live home banner, listed to that audience only (a guest: EVERYONE only).
 * 3. Free pieces of an event's own gift sent from the bag give the recipient nothing (no cherries, no agency
 *    commission) — in a live and in a conversation; other bag gifts and coin sends unchanged.
 * 4. «عدد المعروضين» per board (1–100, 20 by default, editable while running; D303-shaped boards included).
 * 5. The festival template: placeholder names, «شاشة كاملة» on the 1 000 000 and 3 000 000 gifts.
 * 6. Milestones are held with the payout and given at the release (also when no board line pays anything).
 * End to end against PostgreSQL + Redis with the API as the DML-only runtime role.
 */
import { randomUUID } from 'node:crypto';
import sharp from 'sharp';
import { afterAll, beforeAll, describe, expect, it, vi } from 'vitest';
import { addGiftIn, grantStockIn } from '../src/modules/gifts/gift-catalogue.js';
import { LIVE_MEDIA_PROVIDER } from '../src/modules/live/media/live-media.provider.js';
import { OBJECT_STORAGE } from '../src/modules/media/object-storage.js';
import { EventsService } from '../src/modules/programs/events.service.js';
import { creditIn } from '../src/modules/wallet/wallet-ledger.js';
import { panel, type Admin, type Person } from './helpers/admin-panel.js';
import { MemoryLiveMedia } from './helpers/memory-live-media.js';
import { MemoryObjectStorage } from './helpers/memory-storage.js';
import { expectContract } from './helpers/openapi.js';
import { createTestApp, withMigrationClient, type TestContext } from './helpers/test-app.js';

const HOUR_MS = 3_600_000;

const CONFIG = {
  LIVE_HOSTING_ENABLED: 'true',
  LIVE_HEARTBEAT_STALE_SECONDS: '3600',
  LIVE_GIFT_QUANTITIES: '1,2,3,5,10',
  MEDIA_UPLOADS_ENABLED: 'true',
  S3_BUCKET: 'kabso-media-test',
  S3_ACCESS_KEY_ID: 'test',
  S3_SECRET_ACCESS_KEY: 'test',
  MEDIA_PUBLIC_BASE_URL: 'https://media.example.test',
  ADMIN_TOTP_KEY: 'd334-admin-totp-test-key-0123456789-abcdefghijk',
  JWT_ACCESS_TTL_SECONDS: String(90 * 86_400),
  ADMIN_SESSION_IDLE_SECONDS: '86400',
  ADMIN_SESSION_MAX_SECONDS: '604800',
  RATE_LIMIT_ADMIN_LOGIN_IP: '10000/900',
  RATE_LIMIT_ADMIN_IP: '100000/900',
  RATE_LIMIT_LIVE_GIFT_USER: '10000/60',
  EVENTS_SWEEP_INTERVAL_SECONDS: '0',
};

interface User extends Person {
  readonly username: string;
}

describe('D334 events v2 follow-ups', { timeout: 900_000 }, () => {
  const media = new MemoryLiveMedia();
  const storage = new MemoryObjectStorage();
  let ctx: TestContext;
  const p = panel(() => ctx);
  let owner: Admin;
  let s1: User;
  let s2: User;
  let host: User;
  let creator: User;
  let viewer: User;
  let agencyOwner: User;
  let hostRoom: string;
  let creatorRoom: string;
  let dbNow: Date;

  const auth = (u: { token: string }) => ({ Authorization: `Bearer ${u.token}` });
  const user = async (): Promise<User> => {
    const person = await p.signup();
    const profile = await ctx.prisma.userProfile.findUniqueOrThrow({ where: { userId: person.id } });
    return { ...person, username: profile.username };
  };
  const fund = (u: User, coins: number) =>
    ctx.prisma.$transaction((tx) => creditIn(tx, u.id, BigInt(coins), 'ADMIN_GRANT', randomUUID()));
  const join = async (u: User, roomId: string) => {
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
  const fresh = () =>
    withMigrationClient(
      (db) =>
        db.$executeRaw`UPDATE live_rooms SET last_heartbeat_at = ${new Date()} WHERE id IN (${hostRoom}::uuid, ${creatorRoom}::uuid)`,
    );
  const send = async (
    from: User,
    to: User,
    giftCode: string,
    quantity = 1,
    source: 'COINS' | 'BAG' = 'COINS',
  ): Promise<string> => {
    await fresh();
    const roomId = to.id === creator.id ? creatorRoom : hostRoom;
    const res = await ctx.http
      .post(`/api/v1/live/rooms/${roomId}/gifts`)
      .set(auth(from))
      .send({ giftCode, quantity, recipients: [to.username], source, clientId: randomUUID() });
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    return res.body.gift.id as string;
  };
  const board = async (u: User, id: string, kind?: string) => {
    const res = await ctx.http
      .get(`/api/v1/events/${id}/leaderboard`)
      .query(kind ? { board: kind } : {})
      .set(auth(u));
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    expectContract(res, 'getEventLeaderboard');
    return res.body as {
      shown?: number;
      data: { rank: number; user: { id: string }; score: number }[];
      me: { rank: number | null; score: number };
    };
  };
  const ids = (b: { data: { user: { id: string }; score: number }[] }) =>
    b.data.map((r) => [r.user.id, r.score]);
  const sweeper = () => ctx.app.get(EventsService);
  const iso = (ms: number) => new Date(ms).toISOString();
  const giftEvent = async (over: Record<string, unknown>) => {
    const res = await p.send(owner, 'post', '/admin/gift-events', {
      status: 'PUBLISHED',
      titleAr: 'فعالية',
      titleEn: 'Event',
      startsAt: iso(Date.now() - 60_000),
      endsAt: iso(Date.now() + 2 * HOUR_MS),
      gifts: [{ giftCode: 'd334_rose' }],
      boards: [{ kind: 'SENDERS' }],
      reason: 'D334 test',
      ...over,
    });
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    return res.body.id as string;
  };
  const started = async (eventId: string) =>
    (await ctx.prisma.notification.findMany({ where: { eventId, type: 'EVENT_STARTED' } })).map(
      (n) => n.recipientId,
    );
  const sees = async (u: User, eventId: string) =>
    (await ctx.http.get(`/api/v1/events/${eventId}`).set(auth(u))).status;
  /** An older event (made before D334): D295's rule for its HOSTS audience. */
  const makeOld = (eventId: string) =>
    withMigrationClient(
      (db) => db.$executeRaw`UPDATE events SET creators_as_hosts = false WHERE id = ${eventId}::uuid`,
    );
  const picture = (w: number, h: number) =>
    sharp({ create: { width: w, height: h, channels: 3, background: { r: 229, g: 9, b: 20 } } })
      .png()
      .toBuffer();
  const uploadBanner = async () => {
    const res = await ctx.http
      .post('/api/v1/admin/event-uploads?kind=banner')
      .set('Cookie', owner.cookie)
      .set('X-CSRF-Token', owner.csrf)
      .set('Content-Type', 'application/octet-stream')
      .send(await picture(1500, 300));
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    return res.body.mediaId as string;
  };
  const bannerEvents = async (u: User | null, placement?: 'room') => {
    const req = ctx.http.get('/api/v1/home/banners').query(placement ? { placement } : {});
    const res = await (u ? req.set(auth(u)) : req);
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    expectContract(res, 'listHomeBanners');
    return (res.body.data as { eventId: string | null }[]).map((b) => b.eventId);
  };
  const cherriesOf = async (userId: string, referenceId?: string) =>
    (
      await ctx.prisma.cherryLedgerEntry.findMany({
        where: { userId, ...(referenceId ? { referenceId } : {}) },
      })
    ).reduce((sum, r) => sum + r.delta, 0n);

  beforeAll(async () => {
    vi.useFakeTimers({ toFake: ['Date'], now: p.start() });
    ctx = await createTestApp(CONFIG, [
      { token: LIVE_MEDIA_PROVIDER, value: media },
      { token: OBJECT_STORAGE, value: storage },
    ]);
    for (const [code, price] of [
      ['d334_rose', 100],
      ['d334_own', 1000],
    ] as const) {
      await ctx.prisma.$transaction((tx) =>
        addGiftIn(tx, code, {
          category: 'POPULAR',
          nameAr: code,
          nameEn: code,
          priceCoins: price,
          assetKey: `gift_${code}`,
          animationKey: null,
          sortOrder: 0,
          badge: 'NONE',
          tagCode: null,
          tagNameAr: null,
          tagNameEn: null,
        }),
      );
    }
    owner = await p.makeAdmin(['OWNER']);
    [s1, s2, host, creator, viewer, agencyOwner] = (await Promise.all(
      Array.from({ length: 6 }, () => user()),
    )) as [User, User, User, User, User, User];
    // The host: an approved host in an open agency (commission on its cherries).
    await ctx.prisma.liveHost.create({ data: { userId: host.id, source: 'ADMIN' } });
    const agency = await ctx.prisma.agency.create({
      data: {
        ownerUserId: agencyOwner.id,
        inviteCode: 'D334AGCY',
        evaluateFrom: new Date('2020-01-01T00:00:00Z'),
      },
    });
    await ctx.prisma.agencyHost.create({
      data: { agencyId: agency.id, hostUserId: host.id, commissionEligible: true, activatedAt: new Date() },
    });
    // The creator: an approved content-creator member with the creator's hosting permission (D295).
    const app = await ctx.prisma.creatorApplication.create({
      data: {
        userId: creator.id,
        status: 'APPROVED',
        country: 'EG',
        category: 'COMEDY',
        links: ['https://www.tiktok.com/@d334'],
        decidedAt: new Date(),
      },
    });
    await ctx.prisma.creatorMember.create({
      data: { userId: creator.id, applicationId: app.id, activatedAt: new Date() },
    });
    await ctx.prisma.liveHost.create({ data: { userId: creator.id, source: 'CREATOR' } });
    for (const [u, set] of [
      [host, (id: string) => (hostRoom = id)],
      [creator, (id: string) => (creatorRoom = id)],
    ] as const) {
      const room = await ctx.http.post('/api/v1/live/rooms').set(auth(u)).send({ title: 'D334' });
      expect(room.status, JSON.stringify(room.body)).toBe(201);
      set(room.body.id as string);
    }
    for (const u of [s1, s2]) {
      await fund(u, 1_000_000);
      await join(u, hostRoom);
      await join(u, creatorRoom);
    }
    const [row] = await ctx.prisma.$queryRaw<{ now: Date }[]>`SELECT now() AS now`;
    dbNow = row!.now;
  });
  afterAll(async () => {
    vi.useRealTimers();
    await ctx?.close();
  });

  it('the migration keeps D295 for the events that existed and gives the new rule to every later one', async () => {
    const [col] = await ctx.prisma.$queryRaw<{ column_default: string; is_nullable: string }[]>`
      SELECT column_default, is_nullable FROM information_schema.columns
       WHERE table_name = 'events' AND column_name = 'creators_as_hosts'`;
    expect(col).toEqual({ column_default: 'true', is_nullable: 'NO' });
    const [shown] = await ctx.prisma.$queryRaw<{ column_default: string }[]>`
      SELECT column_default FROM information_schema.columns
       WHERE table_name = 'event_boards' AND column_name = 'shown'`;
    expect(shown!.column_default).toBe('20');
    // 0 and 101 are refused by the database itself.
    const id = await giftEvent({ titleEn: 'Shape' });
    for (const bad of [0, 101]) {
      await expect(
        withMigrationClient(
          (db) => db.$executeRaw`UPDATE event_boards SET shown = ${bad} WHERE event_id = ${id}::uuid`,
        ),
      ).rejects.toThrow(/event_boards_shown/);
    }
  });

  it('content creators count as hosts on a new HOSTS event (seen, announced, ranked); hosts are not creators', async () => {
    const hosts = await giftEvent({
      titleEn: 'Hosts night',
      audience: 'HOSTS',
      boards: [{ kind: 'RECEIVERS' }, { kind: 'CREATORS' }],
    });
    const old = await giftEvent({
      titleEn: 'Old hosts night',
      audience: 'HOSTS',
      boards: [{ kind: 'RECEIVERS' }],
    });
    await makeOld(old);
    const creators = await giftEvent({
      titleEn: 'Creators night',
      audience: 'CREATORS',
      boards: [{ kind: 'CREATORS' }],
    });
    // A D166 HOSTS board made now (the new rule) and one made before (D295).
    const d166 = async (titleEn: string) => {
      const res = await p.send(owner, 'post', '/admin/events', {
        titleAr: 'قديم',
        titleEn,
        startsAt: iso(dbNow.getTime() - 10 * 60_000),
        endsAt: iso(Date.now() + HOUR_MS),
        metric: 'GIFT_COINS_RECEIVED',
        audience: 'HOSTS',
        prizes: '1:77',
        reason: 'D334 d166',
      });
      expect(res.status, JSON.stringify(res.body)).toBe(201);
      return res.body.id as string;
    };
    const d166New = await d166('D166 new');
    const d166Old = await d166('D166 old');
    await makeOld(d166Old);
    expect(
      (await ctx.prisma.event.findMany({ where: { id: { in: [hosts, creators, d166New] } } })).map(
        (e) => e.creatorsAsHosts,
      ),
    ).toEqual([true, true, true]);
    const form = await p.send(owner, 'get', `/admin/gift-events/${old}`);
    expect(form.status).toBe(200);
    expectContract(form, 'getAdminGiftEvent');
    expect(form.body.creatorsAsHosts).toBe(false);
    expect((await p.send(owner, 'get', `/admin/gift-events/${hosts}`)).body.creatorsAsHosts).toBe(true);

    // The start notification: the new HOSTS event reaches the host AND the creator; the old one the host only; the
    // creators' event the creator only.
    await sweeper().sweepDetail();
    expect((await started(hosts)).sort()).toEqual([host.id, creator.id].sort());
    expect(await started(old)).toEqual([host.id]);
    expect(await started(creators)).toEqual([creator.id]);
    for (const u of [s1, viewer, agencyOwner]) expect(await started(hosts)).not.toContain(u.id);

    // Seen (the Event Center list and the strip inside lives): the creator sees the new HOSTS event, not the old one;
    // the host never sees the creators' event. Everyone else still sees HOSTS events (D295 shows them to every
    // non-creator).
    const seen = async (u: User) => {
      const running = await ctx.http.get('/api/v1/events/running').set(auth(u));
      expect(running.status).toBe(200);
      expectContract(running, 'getRunningEvents');
      const list = await ctx.http.get('/api/v1/events').query({ tab: 'CALENDAR' }).set(auth(u));
      expect(list.status).toBe(200);
      expectContract(list, 'listEvents');
      const inList = (list.body.data as { id: string }[]).map((e) => e.id);
      const inRunning = (running.body.data as { id: string }[]).map((e) => e.id);
      // The two reads agree.
      expect([hosts, old, creators].filter((id) => inList.includes(id))).toEqual(
        [hosts, old, creators].filter((id) => inRunning.includes(id)),
      );
      return [hosts, old, creators].filter((id) => inList.includes(id));
    };
    expect(await seen(creator)).toEqual([hosts, creators]);
    expect(await seen(host)).toEqual([hosts, old]);
    expect(await seen(viewer)).toEqual([hosts, old]);
    // The event page itself opens by its id as before (a shared link), whatever the audience.
    expect(await sees(creator, old)).toBe(200);

    // Ranked: the creator on the hosts' board with the host; only the creator on the creators' board.
    await send(s1, host, 'd334_rose', 1);
    await send(s2, creator, 'd334_rose', 2);
    expect(ids(await board(creator, hosts, 'RECEIVERS'))).toEqual([
      [creator.id, 200],
      [host.id, 100],
    ]);
    expect(ids(await board(creator, hosts, 'CREATORS'))).toEqual([[creator.id, 200]]);
    expect(ids(await board(creator, creators, 'CREATORS'))).toEqual([[creator.id, 200]]);
    // (A D166 board counts up to now: the frozen test clock moves past the sends.)
    p.advance(60_000);
    // The D166 HOSTS board: the creator ranks on the new one, not on the old one (D295).
    expect(ids(await board(host, d166New))).toEqual([
      [creator.id, 200],
      [host.id, 100],
    ]);
    expect(ids(await board(host, d166Old))).toEqual([[host.id, 100]]);
  });

  it('an event of any audience has its Live home banner, listed to that audience only', async () => {
    const forCreators = await giftEvent({
      titleEn: 'Creators banner',
      audience: 'CREATORS',
      bannerMediaId: await uploadBanner(),
    });
    const forAgencies = await giftEvent({
      titleEn: 'Agencies banner',
      audience: 'AGENCIES',
      bannerMediaId: await uploadBanner(),
    });
    const forHosts = await giftEvent({
      titleEn: 'Hosts banner',
      audience: 'HOSTS',
      bannerMediaId: await uploadBanner(),
    });
    const oldHosts = await giftEvent({
      titleEn: 'Old hosts banner',
      audience: 'HOSTS',
      bannerMediaId: await uploadBanner(),
    });
    await makeOld(oldHosts);
    const forEveryone = await giftEvent({ titleEn: 'Everyone banner', bannerMediaId: await uploadBanner() });
    // Every one of them got its banner (not only EVERYONE events).
    expect(
      await ctx.prisma.homeBanner.count({
        where: {
          eventId: { in: [forCreators, forAgencies, forHosts, oldHosts, forEveryone] },
          placement: 'HOME',
        },
      }),
    ).toBe(5);
    const mine = async (u: User) =>
      (await bannerEvents(u)).filter((id) =>
        [forCreators, forAgencies, forHosts, oldHosts, forEveryone].includes(id!),
      );
    expect((await mine(creator)).sort()).toEqual([forCreators, forHosts, forEveryone].sort());
    expect((await mine(host)).sort()).toEqual([forAgencies, forHosts, oldHosts, forEveryone].sort());
    expect((await mine(agencyOwner)).sort()).toEqual([forAgencies, forHosts, oldHosts, forEveryone].sort());
    expect((await mine(viewer)).sort()).toEqual([forHosts, oldHosts, forEveryone].sort());
    // A banner without an event is everyone's.
    const plainMedia = await uploadBanner();
    await ctx.prisma.homeBanner.create({
      data: {
        mediaId: plainMedia,
        placement: 'HOME',
        link: '/families',
        startsAt: new Date(Date.now() - 60_000),
        enabled: true,
      },
    });
    expect((await bannerEvents(creator)).filter((id) => id === null)).toHaveLength(1);
    expect((await bannerEvents(viewer)).filter((id) => id === null)).toHaveLength(1);
    // A guest (the in-room slot, open without a token): EVERYONE events only.
    for (const eventId of [forCreators, forEveryone]) {
      await ctx.prisma.homeBanner.create({
        data: {
          mediaId: await uploadBanner(),
          placement: 'ROOM',
          link: `/events/${eventId}`,
          eventId,
          startsAt: new Date(Date.now() - 60_000),
          enabled: true,
        },
      });
    }
    const guest = await bannerEvents(null, 'room');
    expect(guest).toEqual([forEveryone]);
    expect(await bannerEvents(creator, 'room')).toEqual(expect.arrayContaining([forCreators]));
    expect(await bannerEvents(viewer, 'room')).not.toContain(forCreators);
  });

  it('free pieces of an event gift sent from the bag give the recipient nothing; other sends unchanged', async () => {
    // The event and its own gift (as uploaded inside it), a board paying 5 pieces to the first supporter.
    const made = await p.send(owner, 'post', '/admin/gift-events', {
      status: 'DRAFT',
      titleAr: 'قطع',
      titleEn: 'Pieces',
      startsAt: null,
      endsAt: null,
      reason: 'D334 pieces',
    });
    expect(made.status, JSON.stringify(made.body)).toBe(201);
    const id = made.body.id as string;
    await withMigrationClient(
      (db) => db.$executeRaw`UPDATE gifts SET event_id = ${id}::uuid WHERE code = 'd334_own'`,
    );
    const put = await p.send(owner, 'put', `/admin/gift-events/${id}`, {
      status: 'PUBLISHED',
      titleAr: 'قطع',
      titleEn: 'Pieces',
      startsAt: iso(Date.now() - 60_000),
      endsAt: iso(Date.now() + HOUR_MS),
      gifts: [{ giftCode: 'd334_own' }],
      boards: [
        {
          kind: 'SENDERS',
          prizes: [
            { rankFrom: 1, rankTo: 1, items: [{ type: 'GIFT_PIECES', giftCode: 'd334_own', count: 5 }] },
          ],
        },
      ],
      reason: 'D334 pieces',
    });
    expect(put.status, JSON.stringify(put.body)).toBe(200);
    // While it runs, a coin send of the event gift pays the host its share and the agency its commission (as before).
    const bought = await send(s1, host, 'd334_own', 1);
    const boughtRow = await ctx.prisma.liveGift.findUniqueOrThrow({ where: { id: bought } });
    expect(boughtRow.hostShareBps).toBeGreaterThan(0);
    expect(await cherriesOf(host.id, bought)).toBeGreaterThan(0n);
    expect(await ctx.prisma.agencyEarning.count({ where: { giftId: bought } })).toBe(1);
    // The end: the 5 pieces are paid into s1's bag.
    p.advance(2 * HOUR_MS);
    await sweeper().sweepDetail();
    const stock = async (u: User, code: string) =>
      (
        await ctx.prisma.userGiftStock.findUnique({
          where: { userId_giftCode: { userId: u.id, giftCode: code } },
        })
      )?.quantity ?? 0;
    expect(await stock(s1, 'd334_own')).toBe(5);

    // Sent from the bag: nothing for the host, the agency, the parent or the room's cherries.
    const hostBefore = await cherriesOf(host.id);
    const ownerBefore = await cherriesOf(agencyOwner.id);
    const roomBefore = await ctx.prisma.liveRoom.findUniqueOrThrow({ where: { id: hostRoom } });
    const scoreBefore = await ctx.prisma.liveRoomScore.findUnique({ where: { roomId: hostRoom } });
    const piece = await send(s1, host, 'd334_own', 2, 'BAG');
    expect(await stock(s1, 'd334_own')).toBe(3);
    const pieceRow = await ctx.prisma.liveGift.findUniqueOrThrow({ where: { id: piece } });
    expect([pieceRow.source, pieceRow.hostShareBps, Number(pieceRow.coinsCharged)]).toEqual(['BAG', 0, 0]);
    expect(await ctx.prisma.cherryLedgerEntry.count({ where: { referenceId: piece } })).toBe(0);
    expect(await ctx.prisma.agencyEarning.count({ where: { giftId: piece } })).toBe(0);
    expect(await cherriesOf(host.id)).toBe(hostBefore);
    expect(await cherriesOf(agencyOwner.id)).toBe(ownerBefore);
    const roomAfter = await ctx.prisma.liveRoom.findUniqueOrThrow({ where: { id: hostRoom } });
    expect(roomAfter.cherries).toBe(roomBefore.cherries);
    const scoreAfter = await ctx.prisma.liveRoomScore.findUnique({ where: { roomId: hostRoom } });
    expect(scoreAfter?.hostCherries).toBe(scoreBefore?.hostCherries);
    // Still a bag send like any other for the rest: the room's score moves (2 × 1000 coins counted).
    expect(scoreAfter!.supportPoints - scoreBefore!.supportPoints).toBe(2000n * 100n);

    // Another bag gift keeps its share: the host gets its cherries and the agency its commission.
    await ctx.prisma.$transaction((tx) => grantStockIn(tx, s1.id, 'd334_rose', 3));
    const other = await send(s1, host, 'd334_rose', 1, 'BAG');
    expect(
      (await ctx.prisma.liveGift.findUniqueOrThrow({ where: { id: other } })).hostShareBps,
    ).toBeGreaterThan(0);
    expect(await cherriesOf(host.id, other)).toBeGreaterThan(0n);
    expect(await ctx.prisma.agencyEarning.count({ where: { giftId: other } })).toBe(1);

    // In a conversation too: the pieces give the recipient nothing; the rose from the bag pays as before.
    for (const [a, b] of [
      [s1, host],
      [host, s1],
    ] as const) {
      const f = await ctx.http.put(`/api/v1/users/${b.username}/follow`).set(auth(a));
      expect(f.status, JSON.stringify(f.body)).toBeLessThan(300);
    }
    const dm = async (giftCode: string) => {
      const res = await ctx.http
        .post('/api/v1/dm/gifts')
        .set(auth(s1))
        .send({ to: host.username, giftCode, quantity: 1, source: 'BAG', clientId: randomUUID() });
      expect(res.status, JSON.stringify(res.body)).toBe(201);
      expectContract(res, 'sendDmGift');
      return ctx.prisma.liveGift.findFirstOrThrow({
        where: { senderId: s1.id, giftCode, dmConversationId: { not: null } },
        orderBy: { createdAt: 'desc' },
      });
    };
    const dmPiece = await dm('d334_own');
    expect([dmPiece.source, dmPiece.hostShareBps]).toEqual(['BAG', 0]);
    expect(await ctx.prisma.cherryLedgerEntry.count({ where: { referenceId: dmPiece.id } })).toBe(0);
    expect(await ctx.prisma.agencyEarning.count({ where: { giftId: dmPiece.id } })).toBe(0);
    const dmRose = await dm('d334_rose');
    expect(dmRose.hostShareBps).toBeGreaterThan(0);
    expect(await cherriesOf(host.id, dmRose.id)).toBeGreaterThan(0n);
    expect(await stock(s1, 'd334_own')).toBe(2);
  });

  it('«عدد المعروضين»: each board lists its own number (20 by default), editable while the event runs', async () => {
    // Past the sends above (the event below starts a minute before now).
    p.advance(5 * 60_000);
    const id = await giftEvent({
      titleEn: 'Places',
      scoring: 'COINS',
      boards: [{ kind: 'SENDERS', shown: 3 }, { kind: 'RECEIVERS' }],
    });
    const many = await Promise.all(Array.from({ length: 5 }, () => user()));
    for (const [i, u] of many.entries()) {
      await fund(u, 10_000);
      await join(u, hostRoom);
      await send(u, host, 'd334_rose', [10, 5, 3, 2, 1][i]);
    }
    const last = many[4]!;
    let b = await board(last, id, 'SENDERS');
    expect(b.shown).toBe(3);
    expect(b.data).toHaveLength(3);
    expect(b.me).toMatchObject({ rank: 5, score: 100 });
    // The other board keeps the default 20.
    expect((await board(last, id, 'RECEIVERS')).shown).toBe(20);
    const detail = await ctx.http.get(`/api/v1/events/${id}`).set(auth(last));
    expect(detail.status).toBe(200);
    expectContract(detail, 'getEvent');
    expect(detail.body.boards.map((x: { kind: string; shown: number }) => [x.kind, x.shown])).toEqual([
      ['SENDERS', 3],
      ['RECEIVERS', 20],
    ]);
    const form = await p.send(owner, 'get', `/admin/gift-events/${id}`);
    expect(form.body.structureLocked).toBe(true);
    expect(form.body.form.boards.map((x: { shown: number }) => x.shown)).toEqual([3, 20]);
    // Running: the number changes (a display setting); the boards themselves stay locked.
    const body = { ...form.body.form, reason: 'show more' };
    const more = await p.send(owner, 'put', `/admin/gift-events/${id}`, {
      ...body,
      boards: body.boards.map((x: Record<string, unknown>) =>
        x.kind === 'SENDERS' ? { ...x, shown: 4 } : x,
      ),
    });
    expect(more.status, JSON.stringify(more.body)).toBe(200);
    b = await board(last, id, 'SENDERS');
    expect([b.shown, b.data.length]).toEqual([4, 4]);
    // Left out of the body: kept.
    const kept = await p.send(owner, 'put', `/admin/gift-events/${id}`, {
      ...body,
      boards: body.boards.map(({ shown: _s, ...x }: Record<string, unknown>) => x),
    });
    expect(kept.status, JSON.stringify(kept.body)).toBe(200);
    expect((await board(last, id, 'SENDERS')).shown).toBe(4);
    // 1–100 only; a locked change is still refused.
    for (const shown of [0, 101, 2.5]) {
      const bad = await p.send(owner, 'put', `/admin/gift-events/${id}`, {
        ...body,
        boards: body.boards.map((x: Record<string, unknown>) => ({ ...x, shown })),
      });
      expect(bad.status).toBe(400);
    }
    const locked = await p.send(owner, 'put', `/admin/gift-events/${id}`, {
      ...body,
      boards: body.boards.map((x: Record<string, unknown>) => ({ ...x, minPoints: 5 })),
    });
    expect(locked.status).toBe(409);
    // A D303-shaped board (no `shown` sent) lists 20 and can be set like any other.
    const d303 = await giftEvent({
      titleEn: 'D303 shape',
      boards: [{ kind: 'SENDERS', minPoints: 0, prizes: [] }],
    });
    expect((await board(last, d303)).shown).toBe(20);
    const d303Form = (await p.send(owner, 'get', `/admin/gift-events/${d303}`)).body.form;
    const set = await p.send(owner, 'put', `/admin/gift-events/${d303}`, {
      ...d303Form,
      boards: [{ ...d303Form.boards[0], shown: 2 }],
      reason: 'two only',
    });
    expect(set.status, JSON.stringify(set.body)).toBe(200);
    b = await board(last, d303);
    expect([b.shown, b.data.length]).toEqual([2, 2]);
    expect(b.me.rank).toBeGreaterThan(2);
  });

  it('the festival template: placeholder names and «شاشة كاملة» on the 1 000 000 and 3 000 000 gifts', async () => {
    const made = await p.send(owner, 'post', '/admin/gift-events/launch-festival', { reason: 'prepare' });
    expect(made.status, JSON.stringify(made.body)).toBe(201);
    const gifts = await ctx.prisma.gift.findMany({
      where: { eventId: made.body.id as string },
      orderBy: { sortOrder: 'asc' },
    });
    expect(gifts.map((g) => [g.code, g.nameAr, g.nameEn, g.priceCoins, g.badges])).toEqual([
      ['kabso_festival_gift_1', 'هدية المهرجان 1', 'Festival gift 1', 50_000, []],
      ['kabso_festival_gift_2', 'هدية المهرجان 2', 'Festival gift 2', 250_000, []],
      ['kabso_festival_gift_3', 'هدية المهرجان 3', 'Festival gift 3', 1_000_000, ['FULLSCREEN']],
      ['kabso_festival_gift_4', 'هدية المهرجان 4', 'Festival gift 4', 3_000_000, ['FULLSCREEN']],
    ]);
    const form = await p.send(owner, 'get', `/admin/gift-events/${made.body.id as string}`);
    expect(form.body.ownGifts.map((g: { fullscreen: boolean }) => g.fullscreen)).toEqual([
      false,
      false,
      true,
      true,
    ]);
    // The prizes are still placeholders the owner edits (pieces of the festival's own gifts on every board).
    expect(form.body.form.boards).toHaveLength(3);
    expect(JSON.stringify(form.body.form)).not.toMatch(/شعلة|صاروخ|تاج الافتتاح|ليلة المهرجان/);
  });

  it('milestones are held with the payout and given at the release, once (also with no board prize)', async () => {
    // Past the sends above (the events below start a minute before now).
    p.advance(5 * 60_000);
    const make = async (titleEn: string, prizes: unknown[]) =>
      giftEvent({
        titleEn,
        scoring: 'COINS',
        boards: [{ kind: 'SENDERS', prizes }],
        milestones: [{ board: 'SENDERS', points: 100, prizes: [{ type: 'COINS', amount: 7 }] }],
      });
    const withPrize = await make('Held milestones', [
      { rankFrom: 1, rankTo: 1, items: [{ type: 'COINS', amount: 11 }] },
    ]);
    const noPrize = await make('Held milestones, no prize', []);
    for (const id of [withPrize, noPrize]) {
      const hold = await p.send(owner, 'post', `/admin/events/${id}/hold`, { reason: 'review first' });
      expect(hold.status, JSON.stringify(hold.body)).toBe(200);
    }
    await send(s2, host, 'd334_rose', 1); // 100 points: both milestones reached
    const grants = (id: string) =>
      ctx.prisma.eventMilestoneGrant.findMany({ where: { milestone: { eventId: id } } });
    const progress = await ctx.http.get(`/api/v1/events/${withPrize}/milestones`).set(auth(s2));
    expect(progress.status).toBe(200);
    expectContract(progress, 'getEventMilestones');
    expect(progress.body.data[0]).toMatchObject({ points: 100, score: 100, reached: true, granted: false });
    // Held while it runs: nothing given.
    await sweeper().sweepDetail();
    expect(await grants(withPrize)).toHaveLength(0);
    expect(await grants(noPrize)).toHaveLength(0);
    // Ended while held: frozen, still nothing given or paid (the one without a board prize is not settled either).
    p.advance(3 * HOUR_MS);
    await sweeper().sweepDetail();
    for (const id of [withPrize, noPrize]) {
      const e = await ctx.prisma.event.findUniqueOrThrow({ where: { id } });
      expect([e.frozenAt !== null, e.paidAt]).toEqual([true, null]);
      expect(await grants(id)).toHaveLength(0);
      expect((await p.send(owner, 'get', `/admin/gift-events/${id}`)).body.state).toBe('HELD');
    }
    const coins = async (reason: string) =>
      (
        await ctx.prisma.walletLedgerEntry.findMany({ where: { userId: s2.id, reason: reason as never } })
      ).map((r) => Number(r.delta));
    const before = await coins('EVENT_PRIZE');
    // Released: the next pass gives the milestones (once) and pays the board.
    for (const id of [withPrize, noPrize]) {
      const release = await p.send(owner, 'post', `/admin/events/${id}/release`, { reason: 'all good' });
      expect(release.status, JSON.stringify(release.body)).toBe(200);
    }
    await sweeper().sweepDetail();
    await sweeper().sweepDetail();
    for (const id of [withPrize, noPrize]) {
      const g = await grants(id);
      expect(g.map((x) => [x.userId, x.status])).toEqual([[s2.id, 'PAID']]);
      expect((await ctx.prisma.event.findUniqueOrThrow({ where: { id } })).paidAt).not.toBeNull();
    }
    const after = await coins('EVENT_PRIZE');
    // 7 + 7 for the two milestones and 11 for the board's first place.
    expect(after.slice(before.length).sort((a, b) => a - b)).toEqual([7, 7, 11]);
  });
});
