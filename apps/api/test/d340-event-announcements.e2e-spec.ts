/**
 * D340 (owner 2026-11-09; contract v1.105-social, CONVENTIONS §10.134): an event's final result and its full-screen
 * announcements.
 * 1. A final board's `me` is the caller's final place whatever it is (beyond the frozen top 100 too), with its
 *    `prizeStatus`; not taking part reads rank null, score 0.
 * 2. `getEventAnnouncements` EVENT_START: once per person and event, only after the start notification, only with
 *    «إعلان بملء الشاشة» on (default on; the panel's switch, editable while running), only to the event's audience and
 *    regions, never once ended; `markEventAnnouncementSeen` idempotent, 404 outside the audience.
 * 3. EVENT_WIN: once per payout (PAID only — not while held, never forfeited), always on; someone else's → 404.
 * 4. An account that is not ACTIVE gets none.
 * End to end against PostgreSQL + Redis with the API as the DML-only runtime role.
 */
import { randomUUID } from 'node:crypto';
import { afterAll, beforeAll, describe, expect, it, vi } from 'vitest';
import { addGiftIn } from '../src/modules/gifts/gift-catalogue.js';
import { LIVE_MEDIA_PROVIDER } from '../src/modules/live/media/live-media.provider.js';
import { EventsService } from '../src/modules/programs/events.service.js';
import { creditIn } from '../src/modules/wallet/wallet-ledger.js';
import { panel, type Admin, type Person } from './helpers/admin-panel.js';
import { MemoryLiveMedia } from './helpers/memory-live-media.js';
import { expectContract } from './helpers/openapi.js';
import { createTestApp, withMigrationClient, type TestContext } from './helpers/test-app.js';

const HOUR_MS = 3_600_000;

const CONFIG = {
  LIVE_HOSTING_ENABLED: 'true',
  LIVE_HEARTBEAT_STALE_SECONDS: '3600',
  LIVE_GIFT_QUANTITIES: '1,2,3,5,10',
  ADMIN_TOTP_KEY: 'd340-admin-totp-test-key-0123456789-abcdefghijk',
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

interface Announcement {
  id: string;
  kind: 'EVENT_START' | 'EVENT_WIN';
  event: { id: string; title: string };
  prize: { type: string; amount: number | null }[];
  board: string | null;
  rank: number | null;
}

describe('D340 event results and full-screen announcements', { timeout: 900_000 }, () => {
  const media = new MemoryLiveMedia();
  let ctx: TestContext;
  const p = panel(() => ctx);
  let owner: Admin;
  let s1: User;
  let s2: User;
  let host: User;
  let viewer: User;
  let hostRoom: string;

  const auth = (u: { token: string }) => ({ Authorization: `Bearer ${u.token}` });
  const user = async (): Promise<User> => {
    const person = await p.signup();
    const profile = await ctx.prisma.userProfile.findUniqueOrThrow({ where: { userId: person.id } });
    return { ...person, username: profile.username };
  };
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
  const send = async (from: User, quantity: number) => {
    await withMigrationClient(
      (db) =>
        db.$executeRaw`UPDATE live_rooms SET last_heartbeat_at = ${new Date()} WHERE id = ${hostRoom}::uuid`,
    );
    const res = await ctx.http
      .post(`/api/v1/live/rooms/${hostRoom}/gifts`)
      .set(auth(from))
      .send({
        giftCode: 'd340_rose',
        quantity,
        recipients: [host.username],
        source: 'COINS',
        clientId: randomUUID(),
      });
    expect(res.status, JSON.stringify(res.body)).toBe(201);
  };
  const iso = (ms: number) => new Date(ms).toISOString();
  const sweeper = () => ctx.app.get(EventsService);
  const giftEvent = async (over: Record<string, unknown>) => {
    const res = await p.send(owner, 'post', '/admin/gift-events', {
      status: 'PUBLISHED',
      titleAr: 'فعالية',
      titleEn: 'Event',
      startsAt: iso(Date.now() - 60_000),
      endsAt: iso(Date.now() + 2 * HOUR_MS),
      scoring: 'COINS',
      gifts: [{ giftCode: 'd340_rose' }],
      boards: [{ kind: 'SENDERS' }],
      reason: 'D340 test',
      ...over,
    });
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    return res.body.id as string;
  };
  const pending = async (u: User): Promise<Announcement[]> => {
    const res = await ctx.http.get('/api/v1/events/announcements').set(auth(u));
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    expectContract(res, 'getEventAnnouncements');
    return res.body.data as Announcement[];
  };
  const starts = async (u: User, among: string[]) =>
    (await pending(u))
      .filter((a) => a.kind === 'EVENT_START' && among.includes(a.event.id))
      .map((a) => a.event.id);
  const seen = (u: User, id: string) => ctx.http.post(`/api/v1/events/announcements/${id}/seen`).set(auth(u));
  const board = async (u: User, id: string) => {
    const res = await ctx.http.get(`/api/v1/events/${id}/leaderboard`).set(auth(u));
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    expectContract(res, 'getEventLeaderboard');
    return res.body as {
      final: boolean;
      me: { rank: number | null; score: number; qualified: boolean; prizeStatus?: string; prize: unknown[] };
    };
  };

  beforeAll(async () => {
    vi.useFakeTimers({ toFake: ['Date'], now: p.start() });
    ctx = await createTestApp(CONFIG, [{ token: LIVE_MEDIA_PROVIDER, value: media }]);
    await ctx.prisma.$transaction((tx) =>
      addGiftIn(tx, 'd340_rose', {
        category: 'POPULAR',
        nameAr: 'وردة',
        nameEn: 'Rose',
        priceCoins: 100,
        assetKey: 'gift_d340_rose', // gitleaks:allow (an asset name)
        animationKey: null,
        sortOrder: 0,
        badge: 'NONE',
        tagCode: null,
        tagNameAr: null,
        tagNameEn: null,
      }),
    );
    owner = await p.makeAdmin(['OWNER']);
    [s1, s2, host, viewer] = (await Promise.all(Array.from({ length: 4 }, () => user()))) as [
      User,
      User,
      User,
      User,
    ];
    await ctx.prisma.liveHost.create({ data: { userId: host.id, source: 'ADMIN' } });
    const room = await ctx.http.post('/api/v1/live/rooms').set(auth(host)).send({ title: 'D340' });
    expect(room.status, JSON.stringify(room.body)).toBe(201);
    hostRoom = room.body.id as string;
    for (const u of [s1, s2]) {
      await ctx.prisma.$transaction((tx) => creditIn(tx, u.id, 1_000_000n, 'ADMIN_GRANT', randomUUID()));
      await join(u, hostRoom);
    }
  });
  afterAll(async () => {
    vi.useRealTimers();
    await ctx?.close();
  });

  it('the migration: announce_fullscreen true for new events (the older ones were written false)', async () => {
    const [col] = await ctx.prisma.$queryRaw<{ column_default: string; is_nullable: string }[]>`
      SELECT column_default, is_nullable FROM information_schema.columns
       WHERE table_name = 'events' AND column_name = 'announce_fullscreen'`;
    expect(col).toEqual({ column_default: 'true', is_nullable: 'NO' });
    const id = await giftEvent({ titleEn: 'Defaults' });
    expect((await ctx.prisma.event.findUniqueOrThrow({ where: { id } })).announceFullscreen).toBe(true);
    const form = await p.send(owner, 'get', `/admin/gift-events/${id}`);
    expect(form.status).toBe(200);
    expectContract(form, 'getAdminGiftEvent');
    expect(form.body.form.announceFullscreen).toBe(true);
  });

  it('EVENT_START: once per person, after the start notification, with the switch on, to the audience only', async () => {
    const everyone = await giftEvent({
      titleAr: 'ليلة الورد',
      titleEn: 'Rose night',
      boards: [
        { kind: 'SENDERS', prizes: [{ rankFrom: 1, rankTo: 1, items: [{ type: 'COINS', amount: 5000 }] }] },
      ],
    });
    const off = await giftEvent({ titleEn: 'Quiet', announceFullscreen: false });
    const hosts = await giftEvent({
      titleEn: 'Hosts only',
      audience: 'HOSTS',
      boards: [{ kind: 'RECEIVERS' }],
    });
    const egypt = await giftEvent({ titleEn: 'Egypt only', regions: ['EG'] });
    const couples = await giftEvent({ titleEn: 'Couples', audience: 'CP', boards: [{ kind: 'CP' }] });
    const later = await giftEvent({
      titleEn: 'Later',
      startsAt: iso(Date.now() + HOUR_MS),
      endsAt: iso(Date.now() + 2 * HOUR_MS),
    });
    const all = [everyone, off, hosts, egypt, couples, later];
    expect((await ctx.prisma.event.findUniqueOrThrow({ where: { id: off } })).announceFullscreen).toBe(false);
    // Before the sweeper announced the start (EVENT_STARTED): nothing yet.
    expect(await starts(viewer, all)).toEqual([]);
    await sweeper().sweepDetail();
    // The viewer: the EVERYONE event only (not the switched-off one, not another region's, not the couples', not one
    // that has not started, and not the hosts' — browsable by every non-creator under D295 but announced to its hosts
    // only, like its start notification). The host: the hosts' event too.
    expect(await starts(viewer, all)).toEqual([everyone]);
    expect((await starts(host, all)).sort()).toEqual([everyone, hosts].sort());
    const ar = await ctx.http
      .get('/api/v1/events/announcements')
      .set(auth(viewer))
      .set('Accept-Language', 'ar');
    expectContract(ar, 'getEventAnnouncements');
    const [shown] = (ar.body.data as Announcement[]).filter((a) => a.event.id === everyone);
    expect(shown).toMatchObject({
      id: `start_${everyone}`,
      kind: 'EVENT_START',
      event: { id: everyone, title: 'ليلة الورد' },
      board: null,
      rank: null,
      prize: [{ type: 'COINS', amount: 5000 }],
    });
    // In English with Accept-Language.
    const en = await ctx.http
      .get('/api/v1/events/announcements')
      .set(auth(viewer))
      .set('Accept-Language', 'en');
    expect(en.body.data.find((a: Announcement) => a.event.id === everyone).event.title).toBe('Rose night');

    // Seen: once; a second call is 204 and nothing changes; the host still has it.
    expect((await seen(viewer, `start_${everyone}`)).status).toBe(204);
    expect((await seen(viewer, `start_${everyone}`)).status).toBe(204);
    expect(await starts(viewer, all)).toEqual([]);
    expect(await ctx.prisma.eventStartAnnouncement.count({ where: { userId: viewer.id } })).toBe(1);
    expect((await starts(host, all)).sort()).toEqual([everyone, hosts].sort());
    // Outside the audience, unknown or malformed → 404.
    expect((await seen(viewer, `start_${couples}`)).status).toBe(404);
    expect((await seen(viewer, `start_${randomUUID()}`)).status).toBe(404);
    expect((await seen(viewer, 'start_nope')).status).toBe(404);
    expect((await seen(viewer, `other_${everyone}`)).status).toBe(404);

    // The panel's switch (a display setting): on while running → announced from then on; off → no longer listed.
    const form = (await p.send(owner, 'get', `/admin/gift-events/${off}`)).body.form;
    expect(form.announceFullscreen).toBe(false);
    const on = await p.send(owner, 'put', `/admin/gift-events/${off}`, {
      ...form,
      announceFullscreen: true,
      reason: 'announce it',
    });
    expect(on.status, JSON.stringify(on.body)).toBe(200);
    expect(await starts(viewer, all)).toEqual([off]);
    // Left out of an edit: kept.
    const { announceFullscreen: _a, ...rest } = form;
    const kept = await p.send(owner, 'put', `/admin/gift-events/${off}`, { ...rest, reason: 'kept' });
    expect(kept.status, JSON.stringify(kept.body)).toBe(200);
    expect((await ctx.prisma.event.findUniqueOrThrow({ where: { id: off } })).announceFullscreen).toBe(true);
    const audits = await ctx.prisma.auditLog.findMany({ where: { targetId: off, action: 'event.update' } });
    expect(
      audits.map((a) => (a.metadata as { announceFullscreen?: boolean }).announceFullscreen).sort(),
    ).toEqual([true, undefined]);
    const offAgain = await p.send(owner, 'put', `/admin/gift-events/${off}`, {
      ...form,
      announceFullscreen: false,
      reason: 'quiet again',
    });
    expect(offAgain.status).toBe(200);
    expect(await starts(viewer, all)).toEqual([]);

    // A person who joins the audience later (a new host) sees the hosts' event once it is theirs to see.
    await ctx.prisma.liveHost.create({ data: { userId: s2.id, source: 'ADMIN' } });
    expect(await starts(s2, all)).toContain(hosts);
    await ctx.prisma.liveHost.delete({ where: { userId: s2.id } });
    expect(await starts(s2, all)).not.toContain(hosts);

    // An account that is not ACTIVE gets none (whatever its token).
    await withMigrationClient(
      (db) => db.$executeRaw`UPDATE users SET status = 'SUSPENDED' WHERE id = ${host.id}::uuid`,
    );
    expect((await sweeper().announcements(host.id, 'ar')).data).toEqual([]);
    await withMigrationClient(
      (db) => db.$executeRaw`UPDATE users SET status = 'ACTIVE' WHERE id = ${host.id}::uuid`,
    );
    expect((await sweeper().announcements(host.id, 'ar')).data.length).toBeGreaterThan(0);
  });

  it('a final board shows the final place, the prize status, and «did not take part»; EVENT_WIN once per payout', async () => {
    p.advance(5 * 60_000);
    const id = await giftEvent({
      titleEn: 'Final',
      boards: [
        {
          kind: 'SENDERS',
          minPoints: 150,
          prizes: [{ rankFrom: 1, rankTo: 2, items: [{ type: 'COINS', amount: 11 }] }],
        },
      ],
    });
    const held = await giftEvent({
      titleEn: 'Held',
      boards: [
        { kind: 'SENDERS', prizes: [{ rankFrom: 1, rankTo: 1, items: [{ type: 'COINS', amount: 13 }] }] },
      ],
    });
    const hold = await p.send(owner, 'post', `/admin/events/${held}/hold`, { reason: 'review first' });
    expect(hold.status, JSON.stringify(hold.body)).toBe(200);
    await send(s1, 2); // 200 points: rank 1, qualified
    await send(s2, 1); // 100 points: rank 2, below the minimum of 150
    // Running: the live board (no prizeStatus).
    let b = await board(s2, id);
    expect(b.final).toBe(false);
    expect(b.me).toMatchObject({ rank: 2, score: 100, qualified: false });
    expect(b.me.prizeStatus).toBeUndefined();

    // Ended, frozen and paid in one pass.
    p.advance(3 * HOUR_MS);
    await sweeper().sweepDetail();
    b = await board(s1, id);
    expect(b.final).toBe(true);
    expect(b.me).toMatchObject({ rank: 1, score: 200, qualified: true, prizeStatus: 'PAID' });
    expect(b.me.prize).toHaveLength(1);
    b = await board(s2, id);
    expect(b.me).toMatchObject({ rank: 2, score: 100, qualified: false, prizeStatus: 'NONE', prize: [] });
    b = await board(viewer, id);
    expect(b.me).toMatchObject({ rank: null, score: 0, qualified: false, prizeStatus: 'NONE' });
    // Held: frozen, the prize PENDING.
    expect((await board(s1, held)).me).toMatchObject({ rank: 1, prizeStatus: 'PENDING' });

    // Below the frozen top 100 (simulated: s2's frozen row removed) the place is computed over the period's window.
    await withMigrationClient(
      (db) =>
        db.$executeRaw`DELETE FROM event_results WHERE event_id = ${id}::uuid AND user_id = ${s2.id}::uuid`,
    );
    b = await board(s2, id);
    expect(b.me).toMatchObject({ rank: 2, score: 100, qualified: false, prizeStatus: 'NONE', prize: [] });

    // EVENT_WIN: s1 once for the paid event; nothing for the held one until it is released; nothing for s2.
    const payout = await ctx.prisma.eventPrizePayout.findFirstOrThrow({
      where: { userId: s1.id, result: { eventId: id } },
    });
    // (The events of the test above ended too: s1 won the first one's 5 000 coins — only these two are looked at.)
    const wins = async (u: User) =>
      (await pending(u)).filter((a) => a.kind === 'EVENT_WIN' && [id, held].includes(a.event.id));
    expect(await wins(s1)).toEqual([
      expect.objectContaining({
        id: `win_${payout.id}`,
        event: expect.objectContaining({ id, title: 'Final' }),
        board: 'SENDERS',
        rank: 1,
        prize: [expect.objectContaining({ type: 'COINS', amount: 11 })],
      }),
    ]);
    expect(await wins(s2)).toEqual([]);
    // The ended events' starts are no longer announced.
    expect(await starts(s2, [id, held])).toEqual([]);
    // Someone else's payout → 404; the winner's own → 204, twice.
    expect((await seen(s2, `win_${payout.id}`)).status).toBe(404);
    expect((await seen(s1, `win_${randomUUID()}`)).status).toBe(404);
    expect((await seen(s1, `win_${payout.id}`)).status).toBe(204);
    const at = (await ctx.prisma.eventPrizePayout.findUniqueOrThrow({ where: { id: payout.id } }))
      .announcedAt;
    expect(at).not.toBeNull();
    p.advance(60_000);
    expect((await seen(s1, `win_${payout.id}`)).status).toBe(204);
    expect(
      (await ctx.prisma.eventPrizePayout.findUniqueOrThrow({ where: { id: payout.id } })).announcedAt,
    ).toEqual(at);
    expect(await wins(s1)).toEqual([]);

    // Released: paid, then announced once.
    const release = await p.send(owner, 'post', `/admin/events/${held}/release`, { reason: 'fine' });
    expect(release.status, JSON.stringify(release.body)).toBe(200);
    await sweeper().sweepDetail();
    expect((await board(s1, held)).me.prizeStatus).toBe('PAID');
    const heldWins = (await wins(s1)).filter((a) => a.event.id === held);
    expect(heldWins.map((a) => [a.rank, a.prize[0]?.amount])).toEqual([[1, 13]]);
    expect((await seen(s1, heldWins[0]!.id)).status).toBe(204);
    expect(await wins(s1)).toEqual([]);

    // A forfeited payout is never announced.
    const forfeited = await ctx.prisma.eventPrizePayout.update({
      where: { id: payout.id },
      data: { status: 'FORFEITED', announcedAt: null },
    });
    expect(await wins(s1)).toEqual([]);
    expect(forfeited.status).toBe('FORFEITED');
  });
});
