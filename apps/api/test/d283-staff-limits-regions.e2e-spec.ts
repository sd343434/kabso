/**
 * D283 (owner 2026-11-05; contract v1.71-live, CONVENTIONS §10.96.10–11), end to end against PostgreSQL + Redis:
 *
 *  - a limited Kabso Team account (MODERATION / SUPPORT / FINANCE, not OWNER) cannot go live (every mode, a scheduled
 *    live), posts announcements only (users cannot post one), has no levels (`getUserLevels` empty), wears the fixed
 *    team picture (and gets the own photo back when the role goes), cannot change picture / cover / frame, join a
 *    family or buy VIP; the OWNER stays a normal account;
 *  - `Me.staff` / `PublicProfile.staff` carry the role and the regions (the profile line's data);
 *  - regions: OWNER only, the code again, audited; only for MODERATION / SUPPORT; the assignment prefers a staff
 *    member of the host's region and falls back by load; «البث الآن» / «بثوثي» filter by region.
 */
import { randomUUID } from 'node:crypto';
import type request from 'supertest';
import { afterAll, beforeAll, describe, expect, it, vi } from 'vitest';
import { grantRoleIn, revokeRoleIn } from '../src/modules/admin-panel/admin-roles.js';
import { totpCode } from '../src/modules/admin-panel/totp.js';
import { LIVE_MEDIA_PROVIDER } from '../src/modules/live/media/live-media.provider.js';
import { LiveStaffAssignmentService } from '../src/modules/live/live-staff-assignment.service.js';
import { isTeamAvatarUrl } from '../src/modules/live/staff-avatar.js';
import { MemoryLiveMedia } from './helpers/memory-live-media.js';
import { expectContract, operations } from './helpers/openapi.js';
import { createTestApp, newUser, withMigrationClient, type TestContext } from './helpers/test-app.js';

const COOKIE = '__Host-kabso_admin';

interface TestUser {
  readonly id: string;
  readonly username: string;
  readonly email: string;
  readonly password: string;
  token: string;
}
interface Admin extends TestUser {
  secret: string;
  cookie: string;
  csrf: string;
}

const D283_OPS = [
  'listAdminStaffRegions GET /api/v1/admin/team/regions',
  'setAdminTeamRegions PUT /api/v1/admin/team/{userId}/regions',
  'getKabsoTeamAvatar GET /api/v1/staff/team-avatar.png',
];

describe('D283 contract coverage', () => {
  it('openapi v1.71-live declares the regions and the team picture', () => {
    const ids = operations().map((o) => `${o.operationId} ${o.method.toUpperCase()} ${o.path}`);
    expect(ids).toEqual(expect.arrayContaining(D283_OPS));
  });
});

describe('D283 the Kabso Team accounts and regions', { timeout: 900_000 }, () => {
  let ctx: TestContext;
  let clock = Date.now();
  const advance = (ms: number) => {
    clock += ms;
    vi.setSystemTime(clock);
  };
  const nextCode = (secret: string) => {
    advance(30_000);
    return totpCode(secret, clock);
  };
  let ipCounter = 40;
  const nextIp = () => {
    ipCounter += 1;
    return `198.51.${Math.floor(ipCounter / 250)}.${(ipCounter % 250) + 1}`;
  };
  const auth = (u: { token: string }) => ({ Authorization: `Bearer ${u.token}` });
  const issue = (res: request.Response) =>
    (res.body as { error?: { details?: { issue: string }[] } }).error?.details?.[0]?.issue;
  const code = (res: request.Response) => (res.body as { error?: { code?: string } }).error?.code;

  const signup = async (): Promise<TestUser> => {
    const payload = newUser();
    const email = String(payload.email).trim().toLowerCase();
    const before = ctx.mail.sent.length;
    const ip = nextIp();
    const res = await ctx.http.post('/api/v1/auth/register').set('X-Forwarded-For', ip).send(payload);
    expect(res.status, JSON.stringify(res.body)).toBe(202);
    const mail = await ctx.mail.waitFor(email, 'code', before);
    const ok = await ctx.http
      .post('/api/v1/auth/register/verify')
      .set('X-Forwarded-For', ip)
      .send({ email, code: mail.code });
    expect(ok.status, JSON.stringify(ok.body)).toBe(201);
    return {
      id: ok.body.user.id as string,
      username: ok.body.user.username as string,
      email,
      password: String(payload.password),
      token: ok.body.tokens.accessToken as string,
    };
  };
  const cookieOf = (res: request.Response): string => {
    const raw = ([] as string[]).concat(res.headers['set-cookie'] ?? []);
    const line = raw.find((c) => c.startsWith(`${COOKIE}=`));
    if (!line) throw new Error(`no session cookie in ${JSON.stringify(raw)}`);
    return line.split(';')[0]!;
  };
  const grant = (p: TestUser, roles: string[]) =>
    withMigrationClient(async (db) => {
      for (const role of roles) await db.$transaction((tx) => grantRoleIn(tx, p.email, role as never));
    });
  const panelSignIn = async (p: TestUser): Promise<Admin> => {
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
  const makeAdmin = async (roles: string[]): Promise<Admin> => {
    const p = await signup();
    await grant(p, roles);
    return panelSignIn(p);
  };
  const aget = (a: Admin, path: string) => ctx.http.get(`/api/v1${path}`).set('Cookie', a.cookie);
  const aput = (a: Admin, path: string, body: object = {}) =>
    ctx.http.put(`/api/v1${path}`).set('Cookie', a.cookie).set('X-CSRF-Token', a.csrf).send(body);
  const setCountry = (u: TestUser, country: string | null) =>
    ctx.prisma.userProfile.update({ where: { userId: u.id }, data: { countryCode: country } });
  const host = async (country: string | null) => {
    const u = await signup();
    await ctx.prisma.liveHost.create({ data: { userId: u.id, source: 'ADMIN' } });
    await setCountry(u, country);
    return u;
  };
  const goLive = async (u: TestUser) => {
    advance(1000);
    const res = await ctx.http.post('/api/v1/live/rooms').set(auth(u)).send({ title: 'On air' });
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    return res.body.id as string;
  };
  const resetLives = () =>
    withMigrationClient(async (db) => {
      await db.$executeRawUnsafe(
        `UPDATE live_rooms SET status = 'ENDED', end_reason = 'HOST_ENDED', ended_at = last_heartbeat_at WHERE status = 'LIVE'`,
      );
      await db.$executeRawUnsafe(`DELETE FROM live_room_assignments`);
      await db.$executeRawUnsafe(`UPDATE admin_shifts SET on_shift = false`);
    });
  const setRegions = (by: Admin, target: TestUser, regions: string[]) =>
    aput(by, `/admin/team/${target.id}/regions`, {
      regions,
      reason: 'D283 test',
      totpCode: nextCode(by.secret),
    });
  const shiftOn = async (a: Admin) => {
    const res = await aput(a, '/admin/me/shift', { onShift: true });
    expect(res.status, JSON.stringify(res.body)).toBe(200);
  };
  const assignee = async (roomId: string) =>
    (await ctx.prisma.liveRoomAssignment.findUnique({ where: { roomId } }))?.adminId ?? null;

  const media = new MemoryLiveMedia();
  let owner: Admin;
  let moderator: Admin;
  let support: Admin;
  let finance: Admin;

  beforeAll(async () => {
    vi.useFakeTimers({ toFake: ['Date'], now: clock });
    ctx = await createTestApp(
      {
        LIVE_HOSTING_ENABLED: 'true',
        TRUST_PROXY: 'loopback',
        ADMIN_TOTP_KEY: 'admin-totp-test-key-0123456789-abcdefghijklmnop',
        JWT_ACCESS_TTL_SECONDS: String(60 * 86_400),
        ADMIN_SESSION_IDLE_SECONDS: '86400',
        ADMIN_SESSION_MAX_SECONDS: '604800',
        RATE_LIMIT_ADMIN_LOGIN_IP: '10000/900',
        RATE_LIMIT_ADMIN_IP: '100000/900',
        RATE_LIMIT_ADMIN_TEAM_IP: '1000/900',
        API_PUBLIC_URL: 'https://api.test.example',
      },
      [{ token: LIVE_MEDIA_PROVIDER, value: media }],
    );
    await resetLives();
    owner = await makeAdmin(['OWNER']);
    moderator = await makeAdmin(['MODERATION']);
    support = await makeAdmin(['SUPPORT']);
    finance = await makeAdmin(['FINANCE']);
  });

  afterAll(async () => {
    vi.useRealTimers();
    await ctx?.close();
  });

  it('a staff account never goes live (every mode); the OWNER does; a schedule is refused too', async () => {
    for (const s of [moderator, support, finance]) {
      await ctx.prisma.liveHost.upsert({
        where: { userId: s.id },
        create: { userId: s.id, source: 'ADMIN' },
        update: {},
      });
      for (const body of [
        { title: 'x' },
        { title: 'x', mode: 'AUDIO', seatCount: 9 },
        { title: 'x', mode: 'MULTI', seatCount: 4 },
        { title: 'x', mode: 'STREAMER' },
      ]) {
        const res = await ctx.http.post('/api/v1/live/rooms').set(auth(s)).send(body);
        expect(res.status, JSON.stringify(res.body)).toBe(403);
        expect(code(res)).toBe('STAFF_ACCOUNT_LIMITED');
        expect(issue(res)).toBe('live');
        expectContract(res, 'startLiveRoom');
      }
      const slot = await ctx.http
        .post('/api/v1/me/live-schedule')
        .set(auth(s))
        .send({ title: 'x', startsAt: new Date(clock + 86_400_000).toISOString() });
      expect(slot.status).toBe(403);
      expect(issue(slot)).toBe('live');
    }
    expect(
      await ctx.prisma.liveRoom.count({
        where: { hostUserId: { in: [moderator.id, support.id, finance.id] } },
      }),
    ).toBe(0);
    await ctx.prisma.liveHost.upsert({
      where: { userId: owner.id },
      create: { userId: owner.id, source: 'ADMIN' },
      update: {},
    });
    await goLive(owner);
    await resetLives();
  });

  it('staff post announcements only; users cannot post one; the OWNER may', async () => {
    const user = await signup();
    const plain = await ctx.http
      .post('/api/v1/posts')
      .set(auth(moderator))
      .set('Idempotency-Key', randomUUID())
      .send({ text: 'hi' });
    expect(plain.status).toBe(403);
    expect(issue(plain)).toBe('post_kind');
    expectContract(plain, 'createPost');
    const ann = await ctx.http
      .post('/api/v1/posts')
      .set(auth(moderator))
      .set('Idempotency-Key', randomUUID())
      .send({ text: 'صيانة الليلة', announcement: true });
    expect(ann.status, JSON.stringify(ann.body)).toBe(201);
    expect(ann.body.announcement).toBe(true);
    expectContract(ann, 'createPost');
    const byUser = await ctx.http
      .post('/api/v1/posts')
      .set(auth(user))
      .set('Idempotency-Key', randomUUID())
      .send({ text: 'fake', announcement: true });
    expect(byUser.status).toBe(403);
    expect(code(byUser)).toBe('STAFF_ACCOUNT_LIMITED');
    expect(issue(byUser)).toBe('announcement');
    const normal = await ctx.http
      .post('/api/v1/posts')
      .set(auth(user))
      .set('Idempotency-Key', randomUUID())
      .send({ text: 'ok' });
    expect(normal.status).toBe(201);
    expect(normal.body.announcement).toBe(false);
    const ownerAnn = await ctx.http
      .post('/api/v1/posts')
      .set(auth(owner))
      .set('Idempotency-Key', randomUUID())
      .send({ text: 'news', announcement: true });
    expect(ownerAnn.status).toBe(201);
    const ownerPlain = await ctx.http
      .post('/api/v1/posts')
      .set(auth(owner))
      .set('Idempotency-Key', randomUUID())
      .send({ text: 'me' });
    expect(ownerPlain.status).toBe(201);
    // No reposts and no stories for staff.
    const repost = await ctx.http
      .put(`/api/v1/posts/${normal.body.id as string}/repost`)
      .set(auth(support))
      .send({ reposted: true });
    expect(repost.status).toBe(403);
    expect(issue(repost)).toBe('repost');
  });

  it('no levels for staff (empty), four for the OWNER and users; the profile and Me carry the identity', async () => {
    const viewer = await signup();
    const staffLevels = await ctx.http.get(`/api/v1/users/${moderator.username}/levels`).set(auth(viewer));
    expect(staffLevels.status).toBe(200);
    expect(staffLevels.body.data).toEqual([]);
    expectContract(staffLevels, 'getUserLevels');
    // The OWNER's levels are a user's (whatever the published ladders give).
    const ownerLevels = await ctx.http.get(`/api/v1/users/${owner.username}/levels`).set(auth(viewer));
    const userLevels = await ctx.http.get(`/api/v1/users/${viewer.username}/levels`).set(auth(owner));
    expect(ownerLevels.body.data).toHaveLength((userLevels.body.data as unknown[]).length);

    const regions = await setRegions(owner, moderator, ['TURKEY', 'ARAB_WORLD']);
    expect(regions.status, JSON.stringify(regions.body)).toBe(200);
    const prof = await ctx.http.get(`/api/v1/users/${moderator.username}`).set(auth(viewer));
    expect(prof.status).toBe(200);
    expect(prof.body.staff).toEqual({ role: 'MODERATION', regions: ['ARAB_WORLD', 'TURKEY'] });
    expect(prof.body.kabsoTeam).toBe(true);
    expect(prof.body.coverUrl).toBeNull();
    expect(prof.body.avatarFrame).toBeNull();
    expect(isTeamAvatarUrl(prof.body.avatarUrl as string)).toBe(true);
    expectContract(prof, 'getPublicProfile');
    const fin = await ctx.http.get(`/api/v1/users/${finance.username}`).set(auth(viewer));
    expect(fin.body.staff).toEqual({ role: 'FINANCE', regions: [] });
    const ownerProf = await ctx.http.get(`/api/v1/users/${owner.username}`).set(auth(viewer));
    expect(ownerProf.body.staff).toBeUndefined();
    expect(ownerProf.body.avatarUrl).toBeNull();
    const me = await ctx.http.get('/api/v1/me').set(auth(support));
    expect(me.body.staff).toEqual({ role: 'SUPPORT', regions: [] });
    expectContract(me, 'getMe');
    const userMe = await ctx.http.get('/api/v1/me').set(auth(viewer));
    expect(userMe.body.staff).toBeUndefined();
  });

  it('the team picture is served; locked picture, cover, frame; no family, VIP or store; own photo back on revoke', async () => {
    const png = await ctx.http.get('/api/v1/staff/team-avatar.png');
    expect(png.status).toBe(200);
    expect(png.headers['content-type']).toContain('image/png');
    for (const [method, path, op] of [
      ['put', '/api/v1/me/avatar', 'setMyAvatar'],
      ['delete', '/api/v1/me/avatar', 'removeMyAvatar'],
      ['put', '/api/v1/me/cover', 'setMyCover'],
      ['delete', '/api/v1/me/cover', 'removeMyCover'],
    ] as const) {
      const res = await ctx.http[method](path).set(auth(support)).send({ mediaId: randomUUID() });
      expect(res.status, `${path} ${JSON.stringify(res.body)}`).toBe(403);
      expect(issue(res)).toBe(path.endsWith('avatar') ? 'avatar' : 'cover');
      expectContract(res, op);
    }
    const frame = await ctx.http
      .put('/api/v1/me/bag/equipped')
      .set(auth(support))
      .send({ category: 'AVATAR_FRAME', code: 'host_frame_blue' });
    expect(frame.status).toBe(403);
    expect(issue(frame)).toBe('frame');
    const fam = await ctx.http
      .post('/api/v1/families')
      .set(auth(support))
      .set('Idempotency-Key', randomUUID())
      .send({});
    expect(fam.status).toBe(403);
    expect(issue(fam)).toBe('family');
    const vip = await ctx.http
      .post('/api/v1/me/vip/purchases')
      .set(auth(support))
      .set('Idempotency-Key', randomUUID())
      .send({ tierId: randomUUID(), priceCoins: 1 });
    expect(vip.status).toBe(403);
    expect(issue(vip)).toBe('vip');

    // A user with a photo becomes SUPPORT → the team picture; the role goes → the photo again.
    const p = await signup();
    await ctx.prisma.userProfile.update({
      where: { userId: p.id },
      data: { avatarUrl: 'https://cdn.test.example/a/me.jpg' },
    });
    await grant(p, ['SUPPORT']);
    // (The grant ran in this process — the CLI's URL; the API rewrites it to its own at its start.)
    expect(
      isTeamAvatarUrl(
        (await ctx.prisma.userProfile.findUniqueOrThrow({ where: { userId: p.id } })).avatarUrl,
      ),
    ).toBe(true);
    await withMigrationClient((db) => db.$transaction((tx) => revokeRoleIn(tx, p.email, 'SUPPORT')));
    const back = await ctx.prisma.userProfile.findUniqueOrThrow({ where: { userId: p.id } });
    expect(back.avatarUrl).toBe('https://cdn.test.example/a/me.jpg');
    expect(back.staffAvatar).toBe(false);
  });

  it('regions: OWNER only, the code again, audited; only for MODERATION / SUPPORT; catalogue', async () => {
    const cat = await aget(owner, '/admin/team/regions');
    expect(cat.status).toBe(200);
    expect(cat.body.data).toHaveLength(13);
    expectContract(cat, 'listAdminStaffRegions');
    expect((await aget(moderator, '/admin/team/regions')).status).toBe(403);
    const byMod = await setRegions(moderator, support, ['EUROPE']);
    expect(byMod.status).toBe(403);
    const fin = await setRegions(owner, finance, ['EUROPE']);
    expect(fin.status).toBe(409);
    expect(issue(fin)).toBe('team_regions_role');
    const wrong = await aput(owner, `/admin/team/${support.id}/regions`, {
      regions: ['EUROPE'],
      reason: 'x',
      totpCode: '000000',
    });
    expect(wrong.status).toBe(403);
    const bad = await setRegions(owner, support, ['MARS']);
    expect(bad.status).toBe(400);
    const ok = await setRegions(owner, support, ['GREATER_CHINA']);
    expect(ok.status).toBe(200);
    expect(ok.body).toEqual({ userId: support.id, regions: ['GREATER_CHINA'], before: [] });
    expectContract(ok, 'setAdminTeamRegions');
    const audit = await ctx.prisma.auditLog.findFirst({
      where: { action: 'admin.team.regions', targetId: support.id },
      orderBy: { createdAt: 'desc' },
    });
    expect(audit?.actorUserId).toBe(owner.id);
    expect(audit?.metadata).toMatchObject({
      before: [],
      regions: ['GREATER_CHINA'],
      reason: 'D283 test',
      via: 'panel',
    });
    const team = await aget(owner, '/admin/team');
    const row = (team.body.data as { id: string; regions: string[] }[]).find((r) => r.id === support.id);
    expect(row?.regions).toEqual(['GREATER_CHINA']);
    expectContract(team, 'listAdminTeam');
  });

  it('a visible staff entry sends `staff-join` (the team entry car); a hidden watch and the OWNER do not', async () => {
    await resetLives();
    const roomId = await goLive(await host('SA'));
    const hook = (identity: string) => {
      const raw = JSON.stringify({
        event: 'participant_joined',
        room: { name: roomId },
        participant: { identity },
      });
      return ctx.http
        .post('/internal/livekit/webhook')
        .set('Content-Type', 'application/webhook+json')
        .set('Authorization', MemoryLiveMedia.sign(raw))
        .send(raw);
    };
    const staffJoins = () =>
      media.broadcasts.filter(
        (b) => b.room === roomId && b.topic === 'chat' && b.payload.includes('"type":"staff-join"'),
      );
    // MODERATION, visible (the default from the app).
    const visible = await ctx.http
      .post(`/api/v1/live/rooms/${roomId}/media-token`)
      .set(auth(moderator))
      .send({});
    expect(visible.status, JSON.stringify(visible.body)).toBe(200);
    expect(visible.body.staff).toBe('VISIBLE');
    expect((await hook(visible.body.identity as string)).status).toBe(200);
    const sent = staffJoins();
    expect(sent).toHaveLength(1);
    const payload = JSON.parse(sent[0]!.payload) as { user: { id: string; avatarUrl: string } };
    expect(payload.user.id).toBe(moderator.id);
    expect(isTeamAvatarUrl(payload.user.avatarUrl)).toBe(true);
    // The same identity again (a reconnect report): nothing more.
    expect((await hook(visible.body.identity as string)).status).toBe(200);
    expect(staffJoins()).toHaveLength(1);
    // Hidden «مراقبة خفية» (the step-up first): no staff-join.
    const step = await ctx.http
      .post('/api/v1/staff/step-up')
      .set(auth(moderator))
      .send({ code: nextCode(moderator.secret) });
    expect(step.status, JSON.stringify(step.body)).toBe(200);
    const hidden = await ctx.http
      .post(`/api/v1/live/rooms/${roomId}/media-token`)
      .set(auth(moderator))
      .send({ staffVisibility: 'HIDDEN' });
    expect(hidden.status, JSON.stringify(hidden.body)).toBe(200);
    expect(hidden.body.staff).toBe('HIDDEN');
    expect((await hook(hidden.body.identity as string)).status).toBe(200);
    // The OWNER visible: no team entry car (a normal account).
    const own = await ctx.http.post(`/api/v1/live/rooms/${roomId}/media-token`).set(auth(owner)).send({});
    expect(own.body.staff).toBe('VISIBLE');
    expect((await hook(own.body.identity as string)).status).toBe(200);
    expect(staffJoins()).toHaveLength(1);
    await resetLives();
  });

  it('assignment: the host’s region first, else by load; the panel and «بثوثي» filter by region', async () => {
    await resetLives();
    await setRegions(owner, moderator, ['ARAB_WORLD']);
    await setRegions(owner, support, ['GREATER_CHINA']);
    await shiftOn(moderator);
    await shiftOn(support);
    const assign = ctx.app.get(LiveStaffAssignmentService);
    // Load the moderator first: three lives from a country of no region go by load (one each, alternating).
    const sa1 = await goLive(await host('SA'));
    await assign.assignPending('sweep');
    expect(await assignee(sa1)).toBe(moderator.id);
    const sa2 = await goLive(await host('EG'));
    await assign.assignPending('sweep');
    // The moderator holds more lives, but Egypt is theirs.
    expect(await assignee(sa2)).toBe(moderator.id);
    const cn = await goLive(await host('CN'));
    await assign.assignPending('sweep');
    expect(await assignee(cn)).toBe(support.id);
    // Nobody of Europe on shift → by load: the support (1 live) before the moderator (2).
    const de = await goLive(await host('DE'));
    await assign.assignPending('sweep');
    expect(await assignee(de)).toBe(support.id);
    const none = await goLive(await host(null));
    await assign.assignPending('sweep');
    expect([moderator.id, support.id]).toContain(await assignee(none));

    const arab = await aget(owner, '/admin/lives?region=ARAB_WORLD');
    expect(arab.status, JSON.stringify(arab.body)).toBe(200);
    expect((arab.body.data as { id: string }[]).map((r) => r.id).sort()).toEqual([sa1, sa2].sort());
    expect(
      (arab.body.data as { region: string; hostCountry: string }[]).every((r) => r.region === 'ARAB_WORLD'),
    ).toBe(true);
    expectContract(arab, 'listAdminLives');
    const mine = await aget(support, '/admin/lives?region=mine');
    expect((mine.body.data as { id: string }[]).map((r) => r.id)).toEqual([cn]);
    const ownerMine = await aget(owner, '/admin/lives?region=mine');
    expect(ownerMine.body.data).toEqual([]);
    await resetLives();
  });
});
