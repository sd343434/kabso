/**
 * D295 (owner 2026-11-06, contract v1.82-live, CONVENTIONS §10.108): content creators go live «صانع محتوى», end to end
 * against PostgreSQL + Redis with the API as the DML-only runtime role:
 *
 *  - a creator-programme membership grants the hosting permission (`live_hosts` CREATOR, `Me.canHost`), the panel's
 *    revocation removes it (and ends the running live);
 *  - host and creator are exclusive on every path (creator application, host application and its approval, the
 *    panel's grant / revoke, the agency activation, the database trigger);
 *  - Popular / New / Nearby interleave one host's live and one creator's live with stable cursors (exhaustion
 *    included); Following and Featured keep their order;
 *  - `LiveRoomSummary.hostIsCreator`;
 *  - the creator share: 70 % stored per send and credited (1 000 000 coins → 7 000 000 cherries), quips 60 %, lucky
 *    unchanged, a send that also reaches a non-creator keeps the category share;
 *  - the agency owner's activation as host or creator (fields, the warning tick, audit, «فعّله وكيل»), the agency
 *    commission on a creator's gifts (on top of the 70 %), the D285 recruit commission of a creator;
 *  - «حظر الوكالة»: OWNER only, code + reason, the forfeit = the unwithdrawn agency commission, idempotent, withdrawn
 *    money and members' earnings untouched, the creator revoked, never reopened, no commission afterwards.
 */
import { createHmac, hkdfSync, randomUUID } from 'node:crypto';
import sharp from 'sharp';
import type request from 'supertest';
import { afterAll, beforeAll, describe, expect, it, vi } from 'vitest';
import { grantRoleIn } from '../src/modules/admin-panel/admin-roles.js';
import { totpCode } from '../src/modules/admin-panel/totp.js';
import { addGiftIn, type GiftFields } from '../src/modules/gifts/gift-catalogue.js';
import { LIVE_MEDIA_PROVIDER } from '../src/modules/live/media/live-media.provider.js';
import { OBJECT_STORAGE } from '../src/modules/media/object-storage.js';
import { commissionCherries, giftProfitUnits } from '../src/modules/recruits/recruit-math.js';
import { RecruitsService } from '../src/modules/recruits/recruits.service.js';
import { reverseGiftCherriesIn } from '../src/modules/economy/cherry-ledger.js';
import { qualifyingIn, thresholdsIn } from '../src/modules/verification/verification-badges.js';
import { creditIn } from '../src/modules/wallet/wallet-ledger.js';
import { TasksService } from '../src/modules/programs/tasks.service.js';
import { MemoryLiveMedia } from './helpers/memory-live-media.js';
import { MemoryObjectStorage } from './helpers/memory-storage.js';
import { expectContract, operations } from './helpers/openapi.js';
import {
  createTestApp,
  registerVerified,
  withMigrationClient,
  type TestContext,
} from './helpers/test-app.js';

const COOKIE = '__Host-kabso_admin';

interface TestUser {
  readonly id: string;
  readonly username: string;
  readonly email: string;
  readonly password: string;
  readonly token: string;
}
interface Admin extends TestUser {
  secret: string;
  cookie: string;
  csrf: string;
}

describe('D295 contract coverage', () => {
  it('openapi v1.82-live declares the creator-lives operations', () => {
    const ids = operations().map((o) => `${o.operationId} ${o.method.toUpperCase()} ${o.path}`);
    expect(ids).toEqual(
      expect.arrayContaining([
        'activateMyAgencyMember POST /api/v1/me/agency/hosts/{userId}/activate',
        'revokeAdminCreatorMember POST /api/v1/admin/creator-members/{userId}/revoke',
        'getAdminAgencyBan GET /api/v1/admin/agencies/{agencyId}/ban',
        'banAdminAgency POST /api/v1/admin/agencies/{agencyId}/ban',
      ]),
    );
  });
});

describe('D295 content creators go live', { timeout: 900_000 }, () => {
  const storage = new MemoryObjectStorage();
  let ctx: TestContext;
  let png: Buffer;
  let clock = Date.parse('2027-03-29T09:00:00.000Z');
  const setNow = (ms: number) => {
    clock = ms;
    vi.setSystemTime(clock);
  };
  const advance = (ms: number) => setNow(clock + ms);
  const auth = (u: { token: string }) => ({ Authorization: `Bearer ${u.token}` });
  const issueOf = (res: request.Response) =>
    (res.body as { error: { details?: { field: string; issue: string }[] } }).error.details?.[0];

  const signup = async (): Promise<TestUser> => {
    const { res, payload } = await registerVerified(ctx);
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    return {
      id: res.body.user.id as string,
      username: res.body.user.username as string,
      email: String(payload.email).trim().toLowerCase(),
      password: payload.password,
      token: res.body.tokens.accessToken as string,
    };
  };
  const coins = (u: TestUser, amount: bigint) =>
    ctx.prisma.$transaction((tx) => creditIn(tx, u.id, amount, 'ADMIN_GRANT', randomUUID()));
  const cherries = async (u: TestUser) =>
    (await ctx.prisma.cherryWallet.findUnique({ where: { userId: u.id } }))?.cherries ?? 0n;

  // ---- the panel ---------------------------------------------------------------------------------------------
  const cookieOf = (res: request.Response): string => {
    const raw = ([] as string[]).concat(res.headers['set-cookie'] ?? []);
    const line = raw.find((c) => c.startsWith(`${COOKIE}=`));
    if (!line) throw new Error(`no session cookie in ${JSON.stringify(raw)}`);
    return line.split(';')[0]!;
  };
  const nextCode = (secret: string) => {
    advance(30_000);
    return totpCode(secret, clock);
  };
  const makeAdmin = async (roles: string[]): Promise<Admin> => {
    const p = await signup();
    for (const role of roles)
      await withMigrationClient((db) => db.$transaction((tx) => grantRoleIn(tx, p.email, role as never)));
    const res = await ctx.http
      .post('/api/v1/admin/auth/login')
      .send({ email: p.email, password: p.password });
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    const pending = cookieOf(res);
    const csrf = res.body.csrfToken as string;
    const enrol = await ctx.http
      .post('/api/v1/admin/auth/totp/enrolment')
      .set('Cookie', pending)
      .set('X-CSRF-Token', csrf);
    const secret = enrol.body.secret as string;
    const confirm = await ctx.http
      .post('/api/v1/admin/auth/totp/enrolment/confirm')
      .set('Cookie', pending)
      .set('X-CSRF-Token', csrf)
      .send({ code: nextCode(secret) });
    expect(confirm.status, JSON.stringify(confirm.body)).toBe(200);
    return { ...p, secret, cookie: cookieOf(confirm), csrf: confirm.body.session.csrfToken as string };
  };
  const aget = (a: Admin, path: string) => ctx.http.get(`/api/v1${path}`).set('Cookie', a.cookie);
  const apost = (a: Admin, path: string, body: object = {}) =>
    ctx.http.post(`/api/v1${path}`).set('Cookie', a.cookie).set('X-CSRF-Token', a.csrf).send(body);

  // ---- creators, hosts, agencies ----------------------------------------------------------------------------
  const creatorForm = {
    country: 'EG',
    category: 'COMEDY',
    links: ['https://www.tiktok.com/@creator'],
    bio: 'مقاطع كوميدية قصيرة',
  };
  const applyCreator = (u: TestUser, recruiter?: string) =>
    ctx.http
      .post('/api/v1/me/creator-application')
      .set(auth(u))
      .send({ ...creatorForm, ...(recruiter === undefined ? {} : { recruiter }) });
  const makeCreator = async (u: TestUser, recruiter?: string) => {
    const res = await applyCreator(u, recruiter);
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    const app = await ctx.prisma.creatorApplication.findFirstOrThrow({
      where: { userId: u.id, status: 'PENDING' },
    });
    const ok = await apost(support, `/admin/creator-applications/${app.id}/approve`);
    expect(ok.status, JSON.stringify(ok.body)).toBe(200);
    return app.id;
  };
  const makeHost = (u: TestUser) => ctx.prisma.liveHost.create({ data: { userId: u.id, source: 'ADMIN' } });
  const canHost = async (u: TestUser) => {
    const me = await ctx.http.get('/api/v1/me').set(auth(u));
    expect(me.status).toBe(200);
    return me.body.canHost as boolean;
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
  const activate = (owner: TestUser, member: TestUser, body: object) =>
    ctx.http.post(`/api/v1/me/agency/hosts/${member.id}/activate`).set(auth(owner)).send(body);

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
  const goLive = async (u: TestUser, extra: object = {}) => {
    const res = await ctx.http
      .post('/api/v1/live/rooms')
      .set(auth(u))
      .send({ title: 'D295', ...extra });
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
  const send = async (roomId: string, from: TestUser, to: TestUser[], code: string, quantity = 1) => {
    const clientId = randomUUID();
    const res = await ctx.http
      .post(`/api/v1/live/rooms/${roomId}/gifts`)
      .set(auth(from))
      .send({ giftCode: code, quantity, recipients: to.map((u) => u.username), source: 'COINS', clientId });
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    return ctx.prisma.liveGift.findFirstOrThrow({ where: { senderId: from.id, clientId } });
  };
  const received = async (u: TestUser, giftId: string) =>
    (
      await ctx.prisma.cherryLedgerEntry.findFirst({
        where: { userId: u.id, referenceId: giftId, reason: 'GIFT_RECEIVED' },
      })
    )?.delta ?? 0n;

  let owner: Admin;
  let support: Admin;
  let bdStaffId = '';
  let fan: TestUser;
  const ROSE = 'd295_rose';
  const QUIP = 'd295_quip';
  const LUCKY = 'd295_lucky';

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
        RATE_LIMIT_HOST_APPLY_USER: '1000/900',
        RATE_LIMIT_LIVE_GIFT_USER: '10000/60',
        CHERRY_WITHDRAWAL_MIN_MINOR: '1',
        JWT_ACCESS_TTL_SECONDS: String(60 * 86_400),
        REFRESH_TTL_SECONDS: String(60 * 86_400),
        REFRESH_ABSOLUTE_TTL_SECONDS: String(60 * 86_400),
        ADMIN_TOTP_KEY: 'admin-totp-test-key-0123456789-abcdefghijklmnop',
        ADMIN_SESSION_IDLE_SECONDS: '86400',
        ADMIN_SESSION_MAX_SECONDS: '604800',
        RATE_LIMIT_ADMIN_LOGIN_IP: '10000/900',
        RATE_LIMIT_ADMIN_IP: '100000/900',
      },
      [
        { token: OBJECT_STORAGE, value: storage },
        { token: LIVE_MEDIA_PROVIDER, value: new MemoryLiveMedia() },
      ],
    );
    owner = await makeAdmin(['OWNER']);
    support = await makeAdmin(['SUPPORT']);
    const bd = await makeAdmin(['BD']);
    const sid = await ctx.prisma.staffId.findUniqueOrThrow({ where: { userId: bd.id } });
    bdStaffId = `Kabso${String(sid.number).padStart(2, '0')}`;
    fan = await signup();
    await coins(fan, 50_000_000n);
    const adult = await ctx.http
      .put('/api/v1/me/lucky-gifts/age-confirmation')
      .set(auth(fan))
      .send({ adult: true });
    expect(adult.status).toBe(200);
    await gift(ROSE, {});
    await gift(QUIP, {
      category: 'QUIPS',
      priceCoins: 100,
      soundKey: 'room/clap',
      soundMs: 500,
      quipText: null,
    });
    await gift(LUCKY, { category: 'LUCKY', priceCoins: 100 });
  });
  afterAll(async () => {
    await ctx?.close();
    vi.useRealTimers();
  });

  it('the live lists interleave hosts and creators 1 : 1 with stable cursors; Following and Featured keep their order', async () => {
    const viewer = await signup();
    const [h1, h2, h3, c1, c2] = [
      await signup(),
      await signup(),
      await signup(),
      await signup(),
      await signup(),
    ];
    for (const h of [h1, h2, h3]) await makeHost(h);
    for (const c of [c1, c2]) await makeCreator(c);
    // Start order (oldest first): h1, h2, h3, c1, c2.
    const rooms = new Map<string, string>();
    for (const u of [h1, h2, h3, c1, c2]) {
      advance(60_000);
      rooms.set(u.id, await goLive(u));
    }
    const name = (id: string) =>
      [h1, h2, h3, c1, c2].find((u) => rooms.get(u.id) === id)?.username ?? `?${id}`;
    const walk = async (query: Record<string, string | number>, as: TestUser = viewer) => {
      const seen: string[] = [];
      let cursor: string | undefined;
      for (let i = 0; i < 20; i++) {
        const res = await ctx.http
          .get('/api/v1/live/rooms')
          .query({ ...query, ...(cursor ? { cursor } : {}) })
          .set(auth(as));
        expect(res.status, JSON.stringify(res.body)).toBe(200);
        expectContract(res, 'listLiveRooms');
        for (const r of res.body.data as { id: string; hostIsCreator: boolean; host: { id: string } }[]) {
          expect(r.hostIsCreator).toBe([c1.id, c2.id].includes(r.host.id));
          seen.push(name(r.id));
        }
        cursor = res.body.page.nextCursor ?? undefined;
        if (!cursor) break;
      }
      return seen;
    };
    // New: host, creator, host, creator, then the hosts alone (the creators ran out) — page sizes 1, 2 and 50.
    const expected = [h3, c2, h2, c1, h1].map((u) => u.username);
    for (const limit of [1, 2, 3, 50])
      expect(await walk({ tab: 'new', limit }), `limit ${limit}`).toEqual(expected);
    // Popular (all cherries 0 → like new, per group) and a kind filter.
    expect(await walk({ tab: 'popular', limit: 2 })).toEqual(expected);
    expect(await walk({ tab: 'popular', kind: 'solo', limit: 2 })).toEqual(expected);
    // Popular orders by the room cherries within each group (v1.86-live, D310; was the score): they move h1 first among
    // the hosts and c1 among the creators.
    await ctx.prisma.liveRoom.update({ where: { id: rooms.get(h1.id)! }, data: { cherries: 500 } });
    await ctx.prisma.liveRoom.update({ where: { id: rooms.get(c1.id)! }, data: { cherries: 100 } });
    expect(await walk({ tab: 'popular', limit: 2 })).toEqual([h1, c1, h3, c2, h2].map((u) => u.username));
    // Nearby: the same interleave over the caller's country.
    await ctx.prisma.userProfile.updateMany({
      where: { userId: { in: [viewer, h1, h2, h3, c1, c2].map((u) => u.id) } },
      data: { countryCode: 'EG' },
    });
    expect(await walk({ tab: 'new', scope: 'nearby', limit: 2 })).toEqual(expected);
    // Following: one order (startedAt), not interleaved.
    for (const u of [h1, h2, h3, c1, c2]) {
      const f = await ctx.http.put(`/api/v1/users/${u.username}/follow`).set(auth(viewer));
      expect([200, 201, 204], JSON.stringify(f.body)).toContain(f.status);
    }
    expect(await walk({ tab: 'following', limit: 2 })).toEqual([c2, c1, h3, h2, h1].map((u) => u.username));
    // Featured: by rank (two hosts next to each other), not interleaved.
    await withMigrationClient((db) =>
      db.liveFeaturedHost.createMany({
        data: [
          { userId: h2.id, rank: 1 },
          { userId: h3.id, rank: 2 },
          { userId: c1.id, rank: 3 },
        ],
      }),
    );
    expect(await walk({ tab: 'new', featured: 'true', limit: 2 })).toEqual(
      [h2, h3, c1].map((u) => u.username),
    );
    // A cursor of the interleaved list is not a featured one (and the reverse).
    const page = await ctx.http.get('/api/v1/live/rooms').query({ tab: 'new', limit: 1 }).set(auth(viewer));
    const bad = await ctx.http
      .get('/api/v1/live/rooms')
      .query({ tab: 'new', limit: 1, featured: 'true', cursor: page.body.page.nextCursor })
      .set(auth(viewer));
    expect(bad.status).toBe(400);
    expect(issueOf(bad)).toMatchObject({ field: 'cursor' });
    // A cursor without the merge (issued before v1.82-live, the single order) stays valid on the interleaved lists and
    // continues both groups after its position: after h3 in New's single order (c2, c1, h3, h2, h1) come h2, h1.
    const h3Room = await ctx.prisma.liveRoom.findUniqueOrThrow({ where: { id: rooms.get(h3.id)! } });
    const key = Buffer.from(hkdfSync('sha256', ctx.config.live.cursorKey, 'kabso', 'live-cursor/v1', 32));
    const body = Buffer.from(
      // (format v3 since v1.86-live, D310; the merge-less shape is what this checks)
      JSON.stringify({ v: 3, t: 'new', c: null, u: null, n: 0, s: h3Room.startedAt.getTime(), i: h3Room.id }),
    ).toString('base64url');
    const tag = createHmac('sha256', key).update(`live-cursor\u0000${body}`).digest().subarray(0, 16);
    const legacy = await ctx.http
      .get('/api/v1/live/rooms')
      .query({ tab: 'new', limit: 50, cursor: `${body}.${tag.toString('base64url')}` })
      .set(auth(viewer));
    expect(legacy.status, JSON.stringify(legacy.body)).toBe(200);
    expectContract(legacy, 'listLiveRooms');
    expect(legacy.body.data.map((r: { id: string }) => name(r.id))).toEqual([h2, h1].map((u) => u.username));
    // The room detail carries the flag too.
    const detail = await ctx.http.get(`/api/v1/live/rooms/${rooms.get(c1.id)}`).set(auth(viewer));
    expectContract(detail, 'getLiveRoom');
    expect(detail.body.hostIsCreator).toBe(true);
    for (const u of [h1, h2, h3, c1, c2]) await endLive(u);
    await withMigrationClient((db) => db.liveFeaturedHost.deleteMany({}));
  });

  it('a creator membership grants the hosting permission; the panel revocation removes it and ends the live', async () => {
    const creator = await signup();
    expect(await canHost(creator)).toBe(false);
    expect((await ctx.http.post('/api/v1/live/rooms').set(auth(creator)).send({ title: 'x' })).status).toBe(
      403,
    );
    const appId = await makeCreator(creator);
    expect(await ctx.prisma.liveHost.findUnique({ where: { userId: creator.id } })).toMatchObject({
      source: 'CREATOR',
    });
    expect(await canHost(creator)).toBe(true);
    const grants = await ctx.prisma.auditLog.findMany({
      where: { action: 'live.host.grant', targetId: creator.id },
    });
    expect(grants.map((g) => (g.metadata as { source: string }).source)).toEqual(['CREATOR']);
    const roomId = await goLive(creator);
    // Only the creator's permission: the admin grant and revoke refuse a creator.
    const grant = await apost(owner, '/admin/live-hosts/grant', { username: creator.username, reason: 'x' });
    expect(grant.status, JSON.stringify(grant.body)).toBe(409);
    expect(issueOf(grant)).toEqual({ field: 'user', issue: 'CREATOR' });
    const revokeHost = await apost(owner, '/admin/live-hosts/revoke', {
      username: creator.username,
      reason: 'x',
    });
    expect(revokeHost.status).toBe(409);
    expect(issueOf(revokeHost)).toEqual({ field: 'user', issue: 'CREATOR' });

    // The team ends the membership: 403 without creators.decide, 400 without a reason, 404 not a member.
    const bdLike = await makeAdmin(['FINANCE']);
    expect((await apost(bdLike, `/admin/creator-members/${creator.id}/revoke`, { reason: 'x' })).status).toBe(
      403,
    );
    expect((await apost(support, `/admin/creator-members/${creator.id}/revoke`, {})).status).toBe(400);
    expect((await apost(support, `/admin/creator-members/${fan.id}/revoke`, { reason: 'x' })).status).toBe(
      404,
    );
    const revoked = await apost(support, `/admin/creator-members/${creator.id}/revoke`, {
      reason: 'روابط مزيفة',
    });
    expect(revoked.status, JSON.stringify(revoked.body)).toBe(200);
    expectContract(revoked, 'revokeAdminCreatorMember');
    expect(revoked.body).toEqual({
      status: 'REVOKED',
      applicationId: appId,
      hostingRemoved: true,
      endedRooms: 1,
    });
    expect(await canHost(creator)).toBe(false);
    expect((await ctx.prisma.liveRoom.findUniqueOrThrow({ where: { id: roomId } })).status).toBe('ENDED');
    expect(await ctx.prisma.liveHost.count({ where: { userId: creator.id } })).toBe(0);
    const mine = await ctx.http.get('/api/v1/me/creator-application').set(auth(creator));
    expectContract(mine, 'getMyCreatorApplication');
    expect(mine.body).toMatchObject({
      member: null,
      application: { status: 'REVOKED', source: 'APPLICATION', revokedAt: expect.any(String) },
      rule: { canApply: true, refusal: null },
    });
    const audit = await ctx.prisma.auditLog.findFirstOrThrow({
      where: { action: 'creator.member.revoke', targetId: creator.id },
    });
    expect(audit.metadata).toMatchObject({ reason: 'روابط مزيفة', hostingRemoved: true, after: 'REVOKED' });
    expect(
      await ctx.prisma.auditLog.count({ where: { action: 'live.host.revoke', targetId: creator.id } }),
    ).toBe(1);
    const list = await aget(support, '/admin/creator-applications?status=REVOKED');
    expectContract(list, 'listAdminCreatorApplications');
    expect(list.body.data[0]).toMatchObject({
      user: { id: creator.id },
      memberActive: false,
      activatedBy: null,
      revokeReason: 'روابط مزيفة',
    });
  });

  it('host and creator are mutually exclusive on every path', async () => {
    // A host cannot apply as a creator.
    const host = await signup();
    await makeHost(host);
    const asCreator = await applyCreator(host);
    expect(asCreator.status).toBe(409);
    expect(asCreator.body.error.code).toBe('CREATOR_APPLICATION_NOT_ALLOWED');
    expect(issueOf(asCreator)).toEqual({ field: 'application', issue: 'HOST' });
    const rule = await ctx.http.get('/api/v1/me/creator-application').set(auth(host));
    expect(rule.body.rule).toEqual({ canApply: false, refusal: 'HOST' });

    // A creator cannot apply to host.
    const creator = await signup();
    await makeCreator(creator);
    const hostRule = await ctx.http.get('/api/v1/me/hosting-application').set(auth(creator));
    expect(hostRule.status).toBe(200);
    expectContract(hostRule, 'getMyHostingApplication');
    expect(hostRule.body.rule).toMatchObject({ canApply: false, refusal: 'CREATOR' });
    expect(hostRule.body.host).toMatchObject({ source: 'CREATOR' });
    const creatorPics = {
      photoUploadId: await upload(creator, 'RECHARGE_AGENT_PHOTO'),
      selfieUploadId: await upload(creator, 'RECHARGE_AGENT_SELFIE'),
    };
    const asHost = await ctx.http
      .post('/api/v1/me/hosting-application')
      .set(auth(creator))
      .set('Idempotency-Key', randomUUID())
      .send({
        displayName: 'صانع',
        country: 'SA',
        dateOfBirth: '1995-05-05',
        contact: { type: 'WHATSAPP', value: '+966511111111' },
        bio: 'أبث الطبخ والدردشة كل مساء',
        acceptRules: true,
        ...creatorPics,
      });
    expect(asHost.status, JSON.stringify(asHost.body)).toBe(409);
    expect(asHost.body.error.code).toBe('HOST_APPLICATION_NOT_ALLOWED');
    expect(issueOf(asHost)).toEqual({ field: 'application', issue: 'CREATOR' });

    // A pending host application of someone who becomes a creator meanwhile is refused at the approval.
    const both = await signup();
    const bothPics = {
      photoUploadId: await upload(both, 'RECHARGE_AGENT_PHOTO'),
      selfieUploadId: await upload(both, 'RECHARGE_AGENT_SELFIE'),
    };
    const pendingHost = await ctx.http
      .post('/api/v1/me/hosting-application')
      .set(auth(both))
      .set('Idempotency-Key', randomUUID())
      .send({
        displayName: 'مضيف',
        country: 'SA',
        dateOfBirth: '1995-05-05',
        contact: { type: 'WHATSAPP', value: '+966511111112' },
        bio: 'أبث الطبخ والدردشة كل مساء',
        acceptRules: true,
        ...bothPics,
      });
    expect(pendingHost.status, JSON.stringify(pendingHost.body)).toBe(201);
    await makeCreator(both);
    const hostApp = await ctx.prisma.hostApplication.findFirstOrThrow({ where: { userId: both.id } });
    const approve = await apost(support, `/admin/host-applications/${hostApp.id}/approve`);
    expect(approve.status, JSON.stringify(approve.body)).toBe(409);
    expect(issueOf(approve)).toEqual({ field: 'application', issue: 'CREATOR' });
    expect((await ctx.prisma.liveHost.findUniqueOrThrow({ where: { userId: both.id } })).source).toBe(
      'CREATOR',
    );

    // A creator application of someone who becomes a host meanwhile is refused at the approval.
    const later = await signup();
    expect((await applyCreator(later)).status).toBe(201);
    await makeHost(later);
    const app = await ctx.prisma.creatorApplication.findFirstOrThrow({ where: { userId: later.id } });
    const approveCreator = await apost(support, `/admin/creator-applications/${app.id}/approve`);
    expect(approveCreator.status).toBe(409);
    expect(issueOf(approveCreator)).toEqual({ field: 'application', issue: 'HOST' });
    expect(await ctx.prisma.creatorMember.count({ where: { userId: later.id } })).toBe(0);

    // The database refuses both directly (the trigger), whatever the path.
    await expect(
      withMigrationClient((db) =>
        db.$executeRawUnsafe(`UPDATE live_hosts SET source = 'ADMIN' WHERE user_id = '${creator.id}'`),
      ),
    ).rejects.toThrow(/creator_host_exclusive|cannot also be a host/);
    await expect(
      withMigrationClient((db) =>
        db.$executeRawUnsafe(
          `INSERT INTO creator_members (user_id, application_id, activated_at) VALUES ('${host.id}', '${app.id}', now())`,
        ),
      ),
    ).rejects.toThrow(/creator_host_exclusive|cannot also be a content creator/);
  });

  it('a creator’s live pays the creator share (direct creator 75 % since D341), quips 60 %, lucky unchanged; a host keeps the host share', async () => {
    const creator = await signup();
    await makeCreator(creator);
    const roomId = await goLive(creator, { mode: 'AUDIO', seatCount: 10 });
    await enter(roomId, fan);
    // 100 × 10 000 coins = 1 000 000 coins. v1.106-social (D341): a creator approved by the team, in no agency, is a
    // direct creator — 75 % × 10 = 7 500 000 cherries (the 70 % creator share is an agency creator's: the D295 agency
    // test below and test/d341-direct-share.e2e-spec.ts).
    const big = await send(roomId, fan, [creator], ROSE, 100);
    expect(big.totalCoins).toBe(1_000_000n);
    expect(big.hostShareBps).toBe(7_500);
    expect(await received(creator, big.id)).toBe(7_500_000n);
    // A quip: 60 % (owner 2026-11-06).
    const quip = await send(roomId, fan, [creator], QUIP);
    expect(quip.hostShareBps).toBe(6_000);
    expect(await received(creator, quip.id)).toBe(600n);
    // Lucky keeps the lucky share.
    const lucky = await send(roomId, fan, [creator], LUCKY);
    expect(lucky.hostShareBps).toBe(ctx.config.lucky.table.hostShareBps);
    expect(lucky.hostShareBps).not.toBe(7_000);
    expect(lucky.hostShareBps).not.toBe(7_500);
    // A send that also reaches a seated non-creator keeps the category share (never the creator rate to a host).
    const guest = await signup();
    await enter(roomId, guest);
    await ctx.prisma.liveRoomSeat.create({ data: { roomId, seatIndex: 1, userId: guest.id } });
    const mixed = await send(roomId, fan, [creator, guest], ROSE);
    expect(mixed.hostShareBps).toBe(6_500);
    expect(await received(guest, mixed.id)).toBe(65_000n);
    // A host's live: the host share — v1.106-social (D341) a host in no agency is a direct host, 70 %.
    const host = await signup();
    await makeHost(host);
    const hostRoom = await goLive(host);
    await enter(hostRoom, fan);
    const toHost = await send(hostRoom, fan, [host], ROSE);
    expect(toHost.hostShareBps).toBe(7_000);
    expect(await received(host, toHost.id)).toBe(70_000n);
    // A creator seated in a host's live: the host's live, so 65 %.
    await endLive(host);
    await endLive(creator);
  });

  it('the agency owner activates a member as host or creator (fields, the warning tick, audit, «فعّله وكيل»)', async () => {
    const agent = await signup();
    const agency = await openAgency(agent);
    const [m1, m2, m3] = [await signup(), await signup(), await signup()];
    for (const m of [m1, m2, m3]) await joinAgency(m, agency.inviteCode);
    const outsider = await signup();

    const list = await ctx.http.get('/api/v1/me/agency/hosts').set(auth(agent));
    expectContract(list, 'listMyAgencyHosts');
    expect(list.body.data.map((r: { hosting: string }) => r.hosting)).toEqual(['NONE', 'NONE', 'NONE']);

    // 404: not the caller's member, or the caller has no agency.
    expect((await activate(agent, outsider, { as: 'HOST' })).status).toBe(404);
    expect((await activate(m1, m2, { as: 'HOST' })).status).toBe(404);
    // A creator needs the fields and the warning's tick.
    const noFields = await activate(agent, m1, { as: 'CREATOR', confirmCreator: true });
    expect(noFields.status).toBe(400);
    const noTick = await activate(agent, m1, { as: 'CREATOR', ...creatorForm });
    expect(noTick.status).toBe(400);
    expect(JSON.stringify(noTick.body)).toContain('confirmCreator');
    const falseTick = await activate(agent, m1, { as: 'CREATOR', ...creatorForm, confirmCreator: false });
    expect(falseTick.status).toBe(400);
    const sixLinks = await activate(agent, m1, {
      as: 'CREATOR',
      ...creatorForm,
      links: Array.from({ length: 6 }, (_, i) => `https://x.example/${i}`),
      confirmCreator: true,
    });
    expect(sixLinks.status).toBe(400);

    // m1 → creator.
    const asCreator = await activate(agent, m1, { as: 'CREATOR', ...creatorForm, confirmCreator: true });
    expect(asCreator.status, JSON.stringify(asCreator.body)).toBe(200);
    expectContract(asCreator, 'activateMyAgencyMember');
    expect(asCreator.body).toMatchObject({
      user: { id: m1.id },
      hosting: 'CREATOR',
      activatedByAgency: true,
    });
    expect(await canHost(m1)).toBe(true);
    const app = await ctx.prisma.creatorApplication.findFirstOrThrow({ where: { userId: m1.id } });
    expect(app).toMatchObject({
      status: 'APPROVED',
      source: 'AGENCY',
      agencyId: agency.id,
      decidedById: agent.id,
      country: 'EG',
      category: 'COMEDY',
    });
    const audit = await ctx.prisma.auditLog.findFirstOrThrow({
      where: { action: 'agency.member.activate', targetId: m1.id },
    });
    expect(audit).toMatchObject({ actorUserId: agent.id });
    expect(audit.metadata).toMatchObject({ agency: agency.id, as: 'CREATOR', warningConfirmed: true });
    // Again as creator: unchanged (200); as host: refused.
    expect((await activate(agent, m1, { as: 'CREATOR', ...creatorForm, confirmCreator: true })).status).toBe(
      200,
    );
    expect(await ctx.prisma.creatorApplication.count({ where: { userId: m1.id } })).toBe(1);
    const creatorAsHost = await activate(agent, m1, { as: 'HOST' });
    expect(creatorAsHost.status).toBe(409);
    expect(creatorAsHost.body.error.code).toBe('AGENCY_ACTIVATION_NOT_ALLOWED');
    expect(issueOf(creatorAsHost)).toEqual({ field: 'member', issue: 'CREATOR' });

    // m2 → host (source AGENCY).
    const asHost = await activate(agent, m2, { as: 'HOST' });
    expect(asHost.status, JSON.stringify(asHost.body)).toBe(200);
    expect(asHost.body).toMatchObject({ hosting: 'HOST', activatedByAgency: true });
    expect(await ctx.prisma.liveHost.findUniqueOrThrow({ where: { userId: m2.id } })).toMatchObject({
      source: 'AGENCY',
      grantedById: agent.id,
    });
    const hostAsCreator = await activate(agent, m2, { as: 'CREATOR', ...creatorForm, confirmCreator: true });
    expect(hostAsCreator.status).toBe(409);
    expect(issueOf(hostAsCreator)).toEqual({ field: 'member', issue: 'HOST' });
    expect(await ctx.prisma.creatorMember.count({ where: { userId: m2.id } })).toBe(0);

    // A member with a pending own creator application: the agency's activation replaces it.
    expect((await applyCreator(m3)).status).toBe(201);
    expect((await activate(agent, m3, { as: 'CREATOR', ...creatorForm, confirmCreator: true })).status).toBe(
      200,
    );
    const m3apps = await ctx.prisma.creatorApplication.findMany({
      where: { userId: m3.id },
      orderBy: { source: 'asc' },
    });
    expect(m3apps.map((a) => [a.source, a.status])).toEqual([
      ['APPLICATION', 'CANCELLED'],
      ['AGENCY', 'APPROVED'],
    ]);

    // The panel: «فعّله وكيل: …».
    const panel = await aget(support, '/admin/creator-applications?status=APPROVED');
    expectContract(panel, 'listAdminCreatorApplications');
    const row = (panel.body.data as { user: { id: string } }[]).find((r) => r.user.id === m1.id);
    expect(row).toMatchObject({
      source: 'AGENCY',
      memberActive: true,
      activatedBy: { agencyId: agency.id, inviteCode: agency.inviteCode, owner: { id: agent.id } },
    });
    // The list shows each member's kind.
    const after = await ctx.http.get('/api/v1/me/agency/hosts').set(auth(agent));
    const kinds = new Map(
      (after.body.data as { user: { id: string }; hosting: string }[]).map((r) => [r.user.id, r.hosting]),
    );
    expect([kinds.get(m1.id), kinds.get(m2.id), kinds.get(m3.id)]).toEqual(['CREATOR', 'HOST', 'CREATOR']);
  });

  it('the agency commission on a creator’s gifts (on top of the 70 %) and the D285 recruit commission of a creator', async () => {
    const agent = await signup();
    const agency = await openAgency(agent);
    const creator = await signup();
    await joinAgency(creator, agency.inviteCode);
    expect(
      (await activate(agent, creator, { as: 'CREATOR', ...creatorForm, confirmCreator: true })).status,
    ).toBe(200);
    const roomId = await goLive(creator);
    await enter(roomId, fan);
    const sendRow = await send(roomId, fan, [creator], ROSE, 100);
    // The creator's 70 % is whole; the agency earns 15 % of it ON TOP, from the platform's part.
    expect(await received(creator, sendRow.id)).toBe(7_000_000n);
    const commission = await ctx.prisma.cherryLedgerEntry.findFirstOrThrow({
      where: { userId: agent.id, referenceId: sendRow.id, reason: 'AGENCY_COMMISSION' },
    });
    expect(commission.delta).toBe(1_050_000n);
    const earning = await ctx.prisma.agencyEarning.findFirstOrThrow({ where: { giftId: sendRow.id } });
    expect(earning).toMatchObject({ hostCherries: 7_000_000n, rateBps: 1_500, commission: 1_050_000n });
    // One credit each: no double payment.
    expect(await ctx.prisma.cherryLedgerEntry.count({ where: { referenceId: sendRow.id } })).toBe(2);
    await endLive(creator);

    // D285: a creator recruited by BD — the recruiter's commission reads the share actually credited (in no agency:
    // a direct creator, 75 % since D341).
    const recruit = await signup();
    await makeCreator(recruit, bdStaffId);
    const rRoom = await goLive(recruit);
    await enter(rRoom, fan);
    const rs = await send(rRoom, fan, [recruit], ROSE, 100);
    expect(await received(recruit, rs.id)).toBe(7_500_000n);
    const recruitment = await ctx.prisma.staffRecruitment.findFirstOrThrow({
      where: { recruitUserId: recruit.id, type: 'CREATOR' },
    });
    const day = new Date(clock).toISOString().slice(0, 10);
    setNow(Date.parse(`${day}T00:00:00.000Z`) + 86_400_000 + 3_600_000);
    const svc = ctx.app.get(RecruitsService);
    await svc.sweep();
    const e = svc.economy();
    const row = await ctx.prisma.staffRecruitCommission.findUniqueOrThrow({
      where: { recruitmentId_day: { recruitmentId: recruitment.id, day: new Date(`${day}T00:00:00Z`) } },
    });
    const profit = giftProfitUnits(
      { charged: 1_000_000n, luckyCoins: 0n, cherries: 7_500_000n, commissions: 0n },
      e,
    );
    expect(BigInt(row.profitUnits.toFixed(0))).toBe(profit);
    expect(profit > 0n).toBe(true);
    expect(row.cherries).toBe(commissionCherries(profit, 100, e));
    await endLive(recruit);
  });

  it('«حظر الوكالة»: OWNER only, code + reason, the unwithdrawn commission forfeited once, members untouched, only the ticked fake creator revoked', async () => {
    const agent = await signup();
    const agency = await openAgency(agent);
    const creator = await signup();
    // A genuine creator of the same agency: not ticked, so kept (owner 2026-11-06).
    const genuine = await signup();
    const host = await signup();
    await joinAgency(creator, agency.inviteCode);
    await joinAgency(genuine, agency.inviteCode);
    await joinAgency(host, agency.inviteCode);
    for (const c of [creator, genuine]) {
      expect((await activate(agent, c, { as: 'CREATOR', ...creatorForm, confirmCreator: true })).status).toBe(
        200,
      );
    }
    expect((await activate(agent, host, { as: 'HOST' })).status).toBe(200);
    const cRoom = await goLive(creator);
    const hRoom = await goLive(host);
    await enter(cRoom, fan);
    await enter(hRoom, fan);
    const g1 = await send(cRoom, fan, [creator], ROSE, 100); // 7 000 000 → commission 1 050 000
    const g2 = await send(hRoom, fan, [host], ROSE, 10); // 650 000 → commission 97 500
    const commission = 1_050_000n + 97_500n;
    expect(await cherries(agent)).toBe(commission);
    const creatorBefore = await cherries(creator);
    const hostBefore = await cherries(host);
    expect(creatorBefore).toBe(7_000_000n);
    expect(hostBefore).toBe(650_000n);

    // The owner withdraws part of it (held by the pending withdrawal).
    const w = await ctx.http
      .post('/api/v1/wallet/me/cherries/withdrawals')
      .set(auth(agent))
      .set('Idempotency-Key', randomUUID())
      .send({ amountMinor: 100, payoutDetails: 'Agency payout' });
    expect(w.status, JSON.stringify(w.body)).toBe(201);
    const withdrawal = await ctx.prisma.cherryWithdrawal.findFirstOrThrow({ where: { userId: agent.id } });
    const unwithdrawn = commission - withdrawal.cherries;
    expect(await cherries(agent)).toBe(unwithdrawn);

    // Not OWNER → 403; the preview shows the amount.
    expect((await aget(support, `/admin/agencies/${agency.id}/ban`)).status).toBe(403);
    expect(
      (
        await apost(support, `/admin/agencies/${agency.id}/ban`, {
          reason: 'x',
          totpCode: nextCode(support.secret),
        })
      ).status,
    ).toBe(403);
    const preview = await aget(owner, `/admin/agencies/${agency.id}/ban`);
    expect(preview.status, JSON.stringify(preview.body)).toBe(200);
    expectContract(preview, 'getAdminAgencyBan');
    expect(preview.body).toMatchObject({
      ban: null,
      commissionCherries: Number(commission),
      heldCherries: Number(withdrawal.cherries),
      forfeitCherries: Number(unwithdrawn),
    });
    // Both creators listed for the OWNER to tick (none pre-selected in the panel).
    expect((preview.body.creators as { id: string }[]).map((c) => c.id).sort()).toEqual(
      [creator.id, genuine.id].sort(),
    );
    // A missing code, reason or list is refused; a wrong code too; a ticked id the agency did not activate → 409.
    const fake = [creator.id];
    expect(
      (await apost(owner, `/admin/agencies/${agency.id}/ban`, { reason: 'x', fakeCreatorUserIds: fake }))
        .status,
    ).toBe(400);
    expect(
      (
        await apost(owner, `/admin/agencies/${agency.id}/ban`, {
          totpCode: nextCode(owner.secret),
          fakeCreatorUserIds: fake,
        })
      ).status,
    ).toBe(400);
    expect(
      (
        await apost(owner, `/admin/agencies/${agency.id}/ban`, {
          reason: 'x',
          totpCode: nextCode(owner.secret),
        })
      ).status,
    ).toBe(400);
    expect(
      (
        await apost(owner, `/admin/agencies/${agency.id}/ban`, {
          reason: 'x',
          totpCode: '000000',
          fakeCreatorUserIds: fake,
        })
      ).status,
    ).toBeGreaterThanOrEqual(400);
    const foreign = await apost(owner, `/admin/agencies/${agency.id}/ban`, {
      reason: 'x',
      totpCode: nextCode(owner.secret),
      fakeCreatorUserIds: [host.id],
    });
    expect(foreign.status).toBe(409);
    expect(await ctx.prisma.agencyBan.count()).toBe(0);
    expect(await ctx.prisma.cherryLedgerEntry.count({ where: { reason: 'AGENCY_FORFEIT' } })).toBe(0);

    const ban = await apost(owner, `/admin/agencies/${agency.id}/ban`, {
      reason: 'تفعيل صانع محتوى وهمي',
      totpCode: nextCode(owner.secret),
      fakeCreatorUserIds: fake,
    });
    expect(ban.status, JSON.stringify(ban.body)).toBe(200);
    expectContract(ban, 'banAdminAgency');
    expect(ban.body).toMatchObject({
      status: 'BANNED',
      alreadyBanned: false,
      commissionCherries: Number(commission),
      forfeitedCherries: Number(unwithdrawn),
      revokedCreators: 1,
      releasedHosts: 3,
      endedRooms: 1,
    });
    // (b) The forfeit: one AGENCY_FORFEIT debit of exactly the unwithdrawn commission; the balance at 0.
    const forfeit = await ctx.prisma.cherryLedgerEntry.findMany({
      where: { userId: agent.id, reason: 'AGENCY_FORFEIT' },
    });
    expect(forfeit.map((f) => [f.delta, f.referenceId])).toEqual([[-unwithdrawn, agency.id]]);
    expect(await cherries(agent)).toBe(0n);
    // Withdrawn (held) money untouched.
    expect(
      await ctx.prisma.cherryWithdrawal.findUniqueOrThrow({ where: { id: withdrawal.id } }),
    ).toMatchObject({
      status: 'PENDING',
      cherries: withdrawal.cherries,
    });
    // The members' own earnings untouched.
    expect(await cherries(creator)).toBe(creatorBefore);
    expect(await cherries(host)).toBe(hostBefore);
    expect(await ctx.prisma.cherryLedgerEntry.count({ where: { referenceId: { in: [g1.id, g2.id] } } })).toBe(
      4,
    );
    // (c) The creator revoked with the hosting permission; the live ended.
    expect(await canHost(creator)).toBe(false);
    expect((await ctx.prisma.liveRoom.findUniqueOrThrow({ where: { id: cRoom } })).status).toBe('ENDED');
    expect(
      await ctx.prisma.creatorApplication.findFirstOrThrow({ where: { userId: creator.id } }),
    ).toMatchObject({
      status: 'REVOKED',
      revokeReason: 'تفعيل صانع محتوى وهمي',
    });
    // The genuine creator (not ticked) stays a creator with the hosting permission, released from the closed agency.
    expect(await canHost(genuine)).toBe(true);
    expect(await ctx.prisma.creatorMember.count({ where: { userId: genuine.id } })).toBe(1);
    expect(
      await ctx.prisma.creatorApplication.findFirstOrThrow({ where: { userId: genuine.id } }),
    ).toMatchObject({ status: 'APPROVED', revokedAt: null });
    expect(
      await ctx.prisma.agencyHost.findFirstOrThrow({
        where: { agencyId: agency.id, hostUserId: genuine.id },
      }),
    ).toMatchObject({ status: 'RELEASED' });
    // (a) Closed BANNED, members released; the owner sees it and cannot reopen; nor can the team.
    expect(await ctx.prisma.agency.findUniqueOrThrow({ where: { id: agency.id } })).toMatchObject({
      status: 'CLOSED',
      closeReason: 'BANNED',
    });
    expect(await ctx.prisma.agencyHost.count({ where: { agencyId: agency.id, status: 'ACTIVE' } })).toBe(0);
    const mine = await ctx.http.get('/api/v1/me/agency').set(auth(agent));
    expectContract(mine, 'getMyAgency');
    expect(mine.body.closedAgency).toMatchObject({ reason: 'BANNED' });
    expect(mine.body.openRule).toMatchObject({ canOpen: false, refusal: 'BANNED' });
    const reopen = await apost(owner, `/admin/agencies/${agency.id}/reopen`, {
      reason: 'x',
      totpCode: nextCode(owner.secret),
    });
    expect(reopen.status).toBe(409);
    // The audit links the creator activation concerned.
    const audit = await ctx.prisma.auditLog.findFirstOrThrow({
      where: { action: 'agency.ban', targetId: agency.id },
    });
    const creatorApp = await ctx.prisma.creatorApplication.findFirstOrThrow({
      where: { userId: creator.id },
    });
    expect(audit).toMatchObject({ actorUserId: owner.id });
    expect(audit.metadata).toMatchObject({
      reason: 'تفعيل صانع محتوى وهمي',
      forfeitedCherries: unwithdrawn.toString(),
      fakeCreators: [creator.id],
      applications: [creatorApp.id],
      keptCreators: [genuine.id],
    });

    // Idempotent: a second ban changes nothing.
    const again = await apost(owner, `/admin/agencies/${agency.id}/ban`, {
      reason: 'مرة ثانية',
      totpCode: nextCode(owner.secret),
      fakeCreatorUserIds: [genuine.id],
    });
    expect(again.status).toBe(200);
    expect(again.body).toMatchObject({ alreadyBanned: true, forfeitedCherries: Number(unwithdrawn) });
    expect(
      await ctx.prisma.cherryLedgerEntry.count({ where: { userId: agent.id, reason: 'AGENCY_FORFEIT' } }),
    ).toBe(1);
    expect(await cherries(agent)).toBe(0n);
    expect(await canHost(genuine)).toBe(true);
    // Nothing credits the agency again: a gift to its former host pays no commission.
    const after = await send(hRoom, fan, [host], ROSE);
    expect(
      await ctx.prisma.cherryLedgerEntry.count({
        where: { referenceId: after.id, reason: 'AGENCY_COMMISSION' },
      }),
    ).toBe(0);
    expect(await cherries(agent)).toBe(0n);
    // A reversal of an earlier send does not take the forfeited commission a second time (the host's own credit is
    // reversed as for any reversal).
    expect(
      (await ctx.prisma.agencyBan.findUniqueOrThrow({ where: { agencyId: agency.id } })).forfeitedCherries,
    ).toBe(unwithdrawn);
    const reversal = await ctx.prisma.$transaction((tx) => reverseGiftCherriesIn(tx, g2.id, new Date(clock)));
    expect(reversal.reversed).toBe(true);
    expect(
      await ctx.prisma.cherryLedgerEntry.count({
        where: { userId: agent.id, reason: 'AGENCY_COMMISSION_REVERSAL' },
      }),
    ).toBe(0);
    expect(await cherries(agent)).toBe(0n);
    expect(await cherries(host)).toBe(hostBefore - 650_000n + (await received(host, after.id)));
    await endLive(host);
  });

  it('«حظر الوكالة» with no creator ticked: banned and forfeited, its creators kept', async () => {
    const agent = await signup();
    const agency = await openAgency(agent);
    const creator = await signup();
    await joinAgency(creator, agency.inviteCode);
    expect(
      (await activate(agent, creator, { as: 'CREATOR', ...creatorForm, confirmCreator: true })).status,
    ).toBe(200);
    const room = await goLive(creator);
    await enter(room, fan);
    await send(room, fan, [creator], ROSE, 10); // 700 000 → commission 105 000
    const ban = await apost(owner, `/admin/agencies/${agency.id}/ban`, {
      reason: 'إغلاق دون صانع وهمي',
      totpCode: nextCode(owner.secret),
      fakeCreatorUserIds: [],
    });
    expect(ban.status, JSON.stringify(ban.body)).toBe(200);
    expect(ban.body).toMatchObject({ forfeitedCherries: 105_000, revokedCreators: 0, endedRooms: 0 });
    expect(await cherries(agent)).toBe(0n);
    expect(await canHost(creator)).toBe(true);
    expect((await ctx.prisma.liveRoom.findUniqueOrThrow({ where: { id: room } })).status).toBe('LIVE');
    const audit = await ctx.prisma.auditLog.findFirstOrThrow({
      where: { action: 'agency.ban', targetId: agency.id },
    });
    expect(audit.metadata).toMatchObject({ fakeCreators: [], keptCreators: [creator.id] });
    await endLive(creator);
  });

  it('a person with both roles from before D295 (left untouched by the migration) is resolved by revoking one role in the panel', async () => {
    const both = async () => {
      const u = await signup();
      await makeHost(u);
      // Only reachable from data written before D295: the trigger is bypassed to set it up.
      await withMigrationClient(async (db) => {
        const appId = randomUUID();
        await db.$executeRawUnsafe(
          `INSERT INTO creator_applications (id, user_id, status, country, category, links, created_at, decided_at)
           VALUES ('${appId}', '${u.id}', 'APPROVED', 'EG', 'VIDEO', ARRAY['https://x.example/a'], now(), now())`,
        );
        await db.$executeRawUnsafe(
          'ALTER TABLE creator_members DISABLE TRIGGER creator_members_host_exclusive',
        );
        try {
          await db.$executeRawUnsafe(
            `INSERT INTO creator_members (user_id, application_id, activated_at) VALUES ('${u.id}', '${appId}', now())`,
          );
        } finally {
          await db.$executeRawUnsafe(
            'ALTER TABLE creator_members ENABLE TRIGGER creator_members_host_exclusive',
          );
        }
      });
      return u;
    };
    // (1) The team revokes the HOST role: the person stays a creator (CREATOR permission given back at once).
    const a = await both();
    const revokeHost = await apost(owner, '/admin/live-hosts/revoke', {
      username: a.username,
      reason: 'creator',
    });
    expect(revokeHost.status, JSON.stringify(revokeHost.body)).toBe(200);
    expect(await ctx.prisma.liveHost.findUniqueOrThrow({ where: { userId: a.id } })).toMatchObject({
      source: 'CREATOR',
    });
    expect(await canHost(a)).toBe(true);
    // Now a creator only: the host revoke refuses as for any creator.
    const again = await apost(owner, '/admin/live-hosts/revoke', { username: a.username, reason: 'x' });
    expect(issueOf(again)).toEqual({ field: 'user', issue: 'CREATOR' });
    // (2) Or the team ends the creator membership: the person stays a host.
    const b = await both();
    const revokeCreator = await apost(support, `/admin/creator-members/${b.id}/revoke`, { reason: 'host' });
    expect(revokeCreator.status, JSON.stringify(revokeCreator.body)).toBe(200);
    expect(revokeCreator.body.hostingRemoved).toBe(false);
    expect(await ctx.prisma.liveHost.findUniqueOrThrow({ where: { userId: b.id } })).toMatchObject({
      source: 'ADMIN',
    });
    expect(await ctx.prisma.creatorMember.count({ where: { userId: b.id } })).toBe(0);
  });

  it('with D293: an agency-activated creator gets the purple seal at once and loses it on revoke or an agency ban; a creator — by its own permission or an agency link — is never blue, and gets no host task (D297)', async () => {
    const badge = async (u: TestUser) => {
      const res = await ctx.http.get('/api/v1/me').set(auth(u));
      expect(res.status).toBe(200);
      return res.body.verification as string | null;
    };
    const causes = async (u: TestUser) =>
      (
        await ctx.prisma.auditLog.findMany({
          where: { action: 'verification.badge.change', targetId: u.id },
        })
      ).map((a) => a.metadata as { before: string | null; after: string | null; cause: string });
    const approvedCheck = (u: TestUser) =>
      ctx.prisma.kycCheck.create({
        data: {
          userId: u.id,
          purpose: 'HOST_APPLICATION',
          status: 'APPROVED',
          sessionId: randomUUID(),
          workflowId: randomUUID(),
          providerStatus: 'Approved',
          dateOfBirth: new Date('1990-01-01T00:00:00Z'),
          decidedAt: new Date(),
        },
      });
    const tasksOf = async (u: TestUser) => {
      const res = await ctx.http.get('/api/v1/me/tasks').set(auth(u));
      expect(res.status).toBe(200);
      return res.body as { band: { host: boolean; creator: boolean }; tasks: { audience: string }[] };
    };

    // The agency activates a member as a creator: purple at once (the sweeper is off in the tests).
    const agent = await signup();
    const agency = await openAgency(agent);
    const [c1, c2, h1] = [await signup(), await signup(), await signup()];
    for (const m of [c1, c2, h1]) await joinAgency(m, agency.inviteCode);
    for (const m of [c1, c2]) {
      expect((await badge(m)) ?? null).toBeNull();
      const res = await activate(agent, m, { as: 'CREATOR', ...creatorForm, confirmCreator: true });
      expect(res.status, JSON.stringify(res.body)).toBe(200);
      expect(await badge(m)).toBe('CREATOR');
      expect(await causes(m)).toEqual([
        expect.objectContaining({ before: null, after: 'CREATOR', cause: 'creator' }),
      ]);
    }
    // D297: the Task Center reads the agency's creator (permission CREATOR) as a creator, never a host, and the
    // agency's host (permission AGENCY) as a host (the task lists themselves: d297-creator-tasks).
    expect((await activate(agent, h1, { as: 'HOST' })).status).toBe(200);
    const creatorTasks = await tasksOf(c1);
    expect(creatorTasks.band).toMatchObject({ host: false, creator: true });
    expect(creatorTasks.tasks.some((t) => t.audience === 'HOSTS')).toBe(false);
    expect((await tasksOf(h1)).band).toMatchObject({ host: true, creator: false });

    // A creator never qualifies for blue, not through the ACTIVE agency link either (owner: never both): an agency's
    // creator with an approved identity check qualifies for CREATOR only; the agency's host (AGENCY) for blue.
    const c3 = await signup();
    await joinAgency(c3, agency.inviteCode);
    expect((await activate(agent, c3, { as: 'CREATOR', ...creatorForm, confirmCreator: true })).status).toBe(
      200,
    );
    expect(
      await ctx.prisma.agencyHost.count({
        where: { agencyId: agency.id, hostUserId: c3.id, status: 'ACTIVE' },
      }),
    ).toBe(1);
    await approvedCheck(c3);
    await approvedCheck(h1);
    const linked = await qualifyingIn(ctx.prisma, new Date(), await thresholdsIn(ctx.prisma), [c3.id, h1.id]);
    expect([...(linked.get(c3.id) ?? [])]).toEqual(['CREATOR']);
    expect([...(linked.get(h1.id) ?? [])]).toEqual(['VERIFIED_HOST']);

    // The team revokes c1's membership: the purple seal goes at once.
    const revoked = await apost(support, `/admin/creator-members/${c1.id}/revoke`, { reason: 'روابط مزيفة' });
    expect(revoked.status, JSON.stringify(revoked.body)).toBe(200);
    expect(await badge(c1)).toBeNull();
    expect(await causes(c1)).toContainEqual(
      expect.objectContaining({ before: 'CREATOR', after: null, cause: 'creator' }),
    );

    // «حظر الوكالة» with c2 ticked as a fake creator: the purple seal goes at once too.
    const ban = await apost(owner, `/admin/agencies/${agency.id}/ban`, {
      reason: 'صانع محتوى وهمي',
      totpCode: nextCode(owner.secret),
      fakeCreatorUserIds: [c2.id],
    });
    expect(ban.status, JSON.stringify(ban.body)).toBe(200);
    expect(ban.body).toMatchObject({ revokedCreators: 1 });
    expect(await badge(c2)).toBeNull();
    expect(await causes(c2)).toContainEqual(
      expect.objectContaining({ before: 'CREATOR', after: null, cause: 'creator' }),
    );

    // The blue host rule leaves out the creator's own permission (source CREATOR): a creator with an approved
    // identity check qualifies for CREATOR only; a host (source ADMIN) with one qualifies for VERIFIED_HOST.
    const creator = await signup();
    await makeCreator(creator);
    expect(await ctx.prisma.liveHost.findUnique({ where: { userId: creator.id } })).toMatchObject({
      source: 'CREATOR',
    });
    await approvedCheck(creator);
    const host = await signup();
    await makeHost(host);
    await approvedCheck(host);
    const q = await qualifyingIn(ctx.prisma, new Date(), await thresholdsIn(ctx.prisma), [
      creator.id,
      host.id,
    ]);
    expect([...(q.get(creator.id) ?? [])]).toEqual(['CREATOR']);
    expect([...(q.get(host.id) ?? [])]).toEqual(['VERIFIED_HOST']);
    expect(await badge(creator)).toBe('CREATOR');
  });

  it('owner (int16): a creator is not a host for host-only events, the host targets or the «new host» gift task', async () => {
    const [host, creator, sender] = [await signup(), await signup(), await signup()];
    await makeHost(host);
    await makeCreator(creator);
    await coins(sender, 1_000_000n);
    const hRoom = await goLive(host);
    const cRoom = await goLive(creator);
    for (const r of [hRoom, cRoom]) await enter(r, sender);
    const started = new Date(Date.now() - 1000);
    const hostsEvent = await ctx.prisma.event.create({
      data: {
        titleAr: 'فعالية المضيفين',
        titleEn: 'Hosts only',
        rulesAr: '-',
        rulesEn: '-',
        startsAt: started,
        permanent: true,
        metric: 'GIFT_COINS_RECEIVED',
        audience: 'HOSTS',
        // An event of D295's time: v1.102-social (D334) keeps its rule for the events made before it (the events made
        // after it count creators as hosts — d334-events-v2-followups).
        creatorsAsHosts: false,
      },
    });
    advance(1000);
    await send(hRoom, sender, [host], ROSE);
    await send(cRoom, sender, [creator], ROSE);
    // The test clock is frozen: move past the sends (the board counts gifts before now).
    advance(1000);

    // Who sees it: a host (and anyone else, as before) — never a creator.
    const seen = async (u: TestUser) => {
      const res = await ctx.http.get('/api/v1/events?tab=PERMANENT').set(auth(u));
      expect(res.status, JSON.stringify(res.body)).toBe(200);
      expectContract(res, 'listEvents');
      return (res.body.data as { id: string }[]).some((e) => e.id === hostsEvent.id);
    };
    expect(await seen(host)).toBe(true);
    expect(await seen(sender)).toBe(true);
    expect(await seen(creator)).toBe(false);
    // Who is ranked: the host, not the creator (both received the same gift).
    const board = await ctx.http.get(`/api/v1/events/${hostsEvent.id}/leaderboard`).set(auth(host));
    expect(board.status).toBe(200);
    expectContract(board, 'getEventLeaderboard');
    const ranked = (board.body.data as { user: { id: string } }[]).map((r) => r.user.id);
    expect(ranked).toContain(host.id);
    expect(ranked).not.toContain(creator.id);
    const mine = await ctx.http.get(`/api/v1/events/${hostsEvent.id}/leaderboard`).set(auth(creator));
    expect(mine.body.me).toMatchObject({ rank: null });

    // The host targets are host tasks: a host has them, a creator does not (404, as for a non-host).
    expect((await ctx.http.get(`/api/v1/live/hosts/${host.username}/targets`).set(auth(sender))).status).toBe(
      200,
    );
    expect(
      (await ctx.http.get(`/api/v1/live/hosts/${creator.username}/targets`).set(auth(sender))).status,
    ).toBe(404);

    // NEW_HOST_GIFTS: the gift to the new host counts, the gift to the creator does not.
    const tasks = ctx.app.get(TasksService);
    const now = new Date();
    const progress = await (
      tasks['progressOf'] as (
        db: unknown,
        me: string,
        metric: string,
        w: { date: string; start: Date; end: Date },
        now: Date,
      ) => Promise<number>
    ).call(
      tasks,
      ctx.prisma,
      sender.id,
      'NEW_HOST_GIFTS',
      {
        date: now.toISOString().slice(0, 10),
        start: started,
        end: new Date(now.getTime() + 60_000),
      },
      now,
    );
    expect(progress).toBe(1);

    await ctx.prisma.event.delete({ where: { id: hostsEvent.id } });
    for (const u of [host, creator]) await endLive(u);
  });
});
