/**
 * D285 (owner, contract v1.75-live, CONVENTIONS §10.96.13): recruitment by staff «الاستقطاب», end to end against
 * PostgreSQL + Redis:
 *
 *  - the recruiter field's live check (staff ID in any form, username; only an ACTIVE MODERATION / BD staff member);
 *  - the four forms (host, agency, recharge agent, creator programme) refuse a bad recruiter and attribute the named
 *    one at the ACTIVATION (approval; the agency at its opening), audited; nothing without the field; HOST / CREATOR
 *    exclusive per person; a recruiter who lost the role attributes nothing;
 *  - BD is a limited staff account with a staff ID and NO moderation power (panel, app staff tools, going live);
 *  - the daily job credits each recruiter its share of the platform profit once per day (reruns and concurrent runs
 *    pay nothing twice), withdrawable; the OWNER's shares and reassignment (code + reason, audited);
 *  - staff see only their own recruits («استقطاباتي»), the OWNER sees everyone's; «أرباحي» and a withdrawal.
 */
import { randomUUID } from 'node:crypto';
import sharp from 'sharp';
import type request from 'supertest';
import { afterAll, beforeAll, describe, expect, it, vi } from 'vitest';
import { grantRoleIn, revokeRoleIn } from '../src/modules/admin-panel/admin-roles.js';
import { totpCode } from '../src/modules/admin-panel/totp.js';
import { addGiftIn } from '../src/modules/gifts/gift-catalogue.js';
import { LIVE_MEDIA_PROVIDER } from '../src/modules/live/media/live-media.provider.js';
import { OBJECT_STORAGE } from '../src/modules/media/object-storage.js';
import { topUpIn } from '../src/modules/recharge/recharge-core.js';
import {
  commissionCherries,
  giftProfitUnits,
  topupProfitUnits,
} from '../src/modules/recruits/recruit-math.js';
import { RecruitsService } from '../src/modules/recruits/recruits.service.js';
import { creditIn } from '../src/modules/wallet/wallet-ledger.js';
import { MemoryLiveMedia } from './helpers/memory-live-media.js';
import { MemoryObjectStorage } from './helpers/memory-storage.js';
import { expectContract, operations } from './helpers/openapi.js';
import { createTestApp, registerVerified, withMigrationClient, type TestContext } from './helpers/test-app.js';

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

describe('D285 contract coverage', () => {
  it('openapi v1.75-live declares the recruitment operations', () => {
    const ids = operations().map((o) => `${o.operationId} ${o.method.toUpperCase()} ${o.path}`);
    expect(ids).toEqual(
      expect.arrayContaining([
        'lookupStaffRecruiter GET /api/v1/staff-recruiters/lookup',
        'getMyStaffRecruits GET /api/v1/me/staff/recruits',
        'getMyStaffEarnings GET /api/v1/me/staff/earnings',
        'getMyCreatorApplication GET /api/v1/me/creator-application',
        'applyForCreatorProgramme POST /api/v1/me/creator-application',
        'cancelMyCreatorApplication POST /api/v1/me/creator-application/cancel',
        'getAdminMyRecruits GET /api/v1/admin/recruits/mine',
        'listAdminRecruits GET /api/v1/admin/recruits',
        'listAdminRecruitStaff GET /api/v1/admin/recruits/staff',
        'getAdminRecruitSettings GET /api/v1/admin/recruits/settings',
        'updateAdminRecruitSettings PUT /api/v1/admin/recruits/settings',
        'reassignAdminRecruit POST /api/v1/admin/recruits/{recruitmentId}/reassign',
        'listAdminCreatorApplications GET /api/v1/admin/creator-applications',
      ]),
    );
  });
});

describe('D285 recruitment by staff', { timeout: 900_000 }, () => {
  const storage = new MemoryObjectStorage();
  let ctx: TestContext;
  let png: Buffer;
  // Thursday 2027-03-18 09:00 UTC (the programs' day is UTC here).
  let clock = Date.parse('2027-03-18T09:00:00.000Z');
  const setNow = (ms: number) => {
    clock = ms;
    vi.setSystemTime(clock);
  };
  const advance = (ms: number) => setNow(clock + ms);
  const auth = (u: { token: string }) => ({ Authorization: `Bearer ${u.token}` });

  const signup = async (): Promise<TestUser> => {
    const { res, payload } = await registerVerified(ctx);
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    return remember({
      id: res.body.user.id as string,
      username: res.body.user.username as string,
      email: String(payload.email).trim().toLowerCase(),
      password: payload.password,
      token: res.body.tokens.accessToken as string,
    });
  };
  const remember = (u: TestUser): TestUser => {
    people.set(u.id, u);
    return u;
  };
  /** Every person signed up here, by id (the recruits go live later with their own token). */
  const people = new Map<string, TestUser>();
  const upload = async (u: TestUser, kind: string): Promise<string> => {
    const slot = await ctx.http
      .post('/api/v1/media/uploads')
      .set(auth(u))
      .send({ kind, contentType: 'image/png', byteSize: png.length });
    expect(slot.status, JSON.stringify(slot.body)).toBe(201);
    expect(storage.upload(slot.body.uploadUrl as string, png, 'image/png')).toBe(true);
    return slot.body.uploadId as string;
  };
  const pictures = async (u: TestUser) => ({
    photoUploadId: await upload(u, 'RECHARGE_AGENT_PHOTO'),
    selfieUploadId: await upload(u, 'RECHARGE_AGENT_SELFIE'),
  });
  const issueOf = (res: request.Response) =>
    (res.body as { error: { details?: { field: string; issue: string }[] } }).error.details?.[0];

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
  const grant = (p: TestUser, role: string) =>
    withMigrationClient((db) => db.$transaction((tx) => grantRoleIn(tx, p.email, role as never)));
  const makeAdmin = async (roles: string[]): Promise<Admin> => {
    const p = await signup();
    for (const role of roles) await grant(p, role);
    const res = await ctx.http.post('/api/v1/admin/auth/login').send({ email: p.email, password: p.password });
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
  const aput = (a: Admin, path: string, body: object = {}) =>
    ctx.http.put(`/api/v1${path}`).set('Cookie', a.cookie).set('X-CSRF-Token', a.csrf).send(body);

  // ---- the forms ---------------------------------------------------------------------------------------------
  const lookup = async (u: TestUser, q: string) => {
    const res = await ctx.http.get('/api/v1/staff-recruiters/lookup').query({ q }).set(auth(u));
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    expectContract(res, 'lookupStaffRecruiter');
    return res.body as { found: boolean; recruiter: { staffId: string; role: string; displayName: string } | null };
  };
  const applyHost = async (u: TestUser, recruiter?: string) => {
    const pics = await pictures(u);
    return ctx.http
      .post('/api/v1/me/hosting-application')
      .set(auth(u))
      .set('Idempotency-Key', randomUUID())
      .send({
        displayName: 'مضيف جديد',
        country: 'SA',
        dateOfBirth: '1995-05-05',
        contact: { type: 'WHATSAPP', value: '+966511111111' },
        bio: 'أبث الطبخ والدردشة كل مساء',
        acceptRules: true,
        ...pics,
        ...(recruiter === undefined ? {} : { recruiter }),
      });
  };
  const openAgency = async (u: TestUser, recruiter?: string) => {
    const pics = await pictures(u);
    return ctx.http
      .post('/api/v1/me/agency/open')
      .set(auth(u))
      .set('Idempotency-Key', randomUUID())
      .send({
        name: `وكالة ${u.username.slice(0, 10)}`,
        country: 'SA',
        contact: { type: 'WHATSAPP', value: '+966500000001' },
        expectedHosts: 5,
        ...pics,
        ...(recruiter === undefined ? {} : { recruiter }),
      });
  };
  const applyRecharge = async (u: TestUser, recruiter?: string) => {
    const pics = await pictures(u);
    return ctx.http
      .post('/api/v1/me/recharge-agent/application')
      .set(auth(u))
      .send({
        fullName: 'محمد أحمد علي حسن',
        phone: '+201001234567',
        whatsapp: true,
        ...pics,
        locations: [{ country: 'EG', cities: ['Cairo'] }],
        paymentMethods: [{ country: 'EG', type: 'MOBILE_WALLET', details: 'Vodafone Cash' }],
        ...(recruiter === undefined ? {} : { recruiter }),
      });
  };
  const applyCreator = (u: TestUser, recruiter?: string) =>
    ctx.http
      .post('/api/v1/me/creator-application')
      .set(auth(u))
      .send({
        country: 'EG',
        category: 'COMEDY',
        links: ['https://www.tiktok.com/@creator'],
        bio: 'مقاطع كوميدية قصيرة',
        ...(recruiter === undefined ? {} : { recruiter }),
      });
  const recruitmentOf = (u: TestUser, type: string) =>
    ctx.prisma.staffRecruitment.findFirst({ where: { recruitUserId: u.id, type: type as never } });
  const audits = (action: string, targetId?: string) =>
    ctx.prisma.auditLog.findMany({ where: { action, ...(targetId ? { targetId } : {}) } });

  // ---- lives and gifts -----------------------------------------------------------------------------------------
  let giftCode = '';
  const join = async (roomId: string, u: TestUser) => {
    const raw = JSON.stringify({ event: 'participant_joined', room: { name: roomId }, participant: { identity: u.id } });
    const res = await ctx.http
      .post('/internal/livekit/webhook')
      .set('Content-Type', 'application/webhook+json')
      .set('Authorization', MemoryLiveMedia.sign(raw))
      .send(raw);
    expect(res.status).toBe(200);
  };
  const sendGifts = async (fan: TestUser, host: TestUser, quantity: number) => {
    let room = (await ctx.prisma.liveRoom.findFirst({ where: { hostUserId: host.id, status: 'LIVE' } }))?.id;
    if (!room) {
      const res = await ctx.http.post('/api/v1/live/rooms').set(auth(host)).send({ title: 'D285' });
      expect(res.status, JSON.stringify(res.body)).toBe(201);
      room = res.body.id as string;
      await join(room, fan);
    }
    const res = await ctx.http
      .post(`/api/v1/live/rooms/${room}/gifts`)
      .set(auth(fan))
      .send({ giftCode, quantity, recipients: [host.username], source: 'COINS', clientId: randomUUID() });
    expect(res.status, JSON.stringify(res.body)).toBe(201);
  };
  const recruits = () => ctx.app.get(RecruitsService);

  let owner: Admin;
  let support: Admin;
  let bd: Admin;
  let moderator: Admin;
  let financeStaff: Admin;
  let bdStaffId = '';
  let modStaffId = '';
  let fan: TestUser;

  beforeAll(async () => {
    png = await sharp({ create: { width: 64, height: 64, channels: 3, background: { r: 30, g: 120, b: 200 } } })
      .png()
      .toBuffer();
    vi.useFakeTimers({ toFake: ['Date'], now: clock });
    ctx = await createTestApp(
      {
        LIVE_HOSTING_ENABLED: 'true',
        LIVE_HEARTBEAT_STALE_SECONDS: '3600',
        LIVE_GIFT_QUANTITIES: '1,5,10',
        MEDIA_UPLOADS_ENABLED: 'true',
        S3_BUCKET: 'kabso-media-test',
        S3_ACCESS_KEY_ID: 'test',
        S3_SECRET_ACCESS_KEY: 'test',
        MEDIA_PUBLIC_BASE_URL: 'https://media.example.test',
        LIVE_RANKINGS_TIME_ZONE: 'UTC',
        RECHARGE_AGENT_SWEEP_INTERVAL_SECONDS: '0',
        SPECIAL_USERNAME_SWEEP_INTERVAL_SECONDS: '0',
        AGENCY_SWEEP_INTERVAL_SECONDS: '0',
        RATE_LIMIT_HOST_APPLY_USER: '1000/900',
        RATE_LIMIT_AGENCY_OPEN_USER: '1000/900',
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
    bd = await makeAdmin(['BD']);
    moderator = await makeAdmin(['MODERATION']);
    financeStaff = await makeAdmin(['FINANCE']);
    const ids = await ctx.prisma.staffId.findMany({ where: { userId: { in: [bd.id, moderator.id] } } });
    const fmt = (n: number) => `Kabso${String(n).padStart(2, '0')}`;
    bdStaffId = fmt(ids.find((i) => i.userId === bd.id)!.number);
    modStaffId = fmt(ids.find((i) => i.userId === moderator.id)!.number);
    fan = await signup();
    await ctx.prisma.$transaction((tx) => creditIn(tx, fan.id, 100_000_000n, 'ADMIN_GRANT', randomUUID()));
    giftCode = `d285_${randomUUID().slice(0, 6)}`;
    await ctx.prisma.$transaction((tx) =>
      addGiftIn(tx, giftCode, {
        category: 'POPULAR',
        nameAr: 'وردة',
        nameEn: 'Rose',
        priceCoins: 10_000,
        assetKey: `gift_${giftCode}`,
        animationKey: null,
        sortOrder: 1,
        badge: 'NONE',
        tagCode: null,
        tagNameAr: null,
        tagNameEn: null,
      }),
    );
  });
  afterAll(async () => {
    await ctx?.close();
    vi.useRealTimers();
  });

  it('BD: a limited staff account with a staff ID and the region line, NO moderation power', async () => {
    // The grant gave BD the next staff ID; its Me carries the identity with role BD.
    expect(bdStaffId).toMatch(/^Kabso\d{2}$/);
    const me = await ctx.http.get('/api/v1/me').set(auth(bd));
    expect(me.status).toBe(200);
    expectContract(me, 'getMe');
    expect(me.body.staffId).toBe(bdStaffId);
    expect(me.body.staff).toMatchObject({ role: 'BD', staffId: bdStaffId });
    // No live, no levels.
    const live = await ctx.http.post('/api/v1/live/rooms').set(auth(bd)).send({ title: 'x' });
    expect(live.status).toBe(403);
    expect(live.body.error.code).toBe('STAFF_ACCOUNT_LIMITED');
    // The app's staff tools: not «فريق كابسو» (no watch, no shift, no reports).
    const status = await ctx.http.get('/api/v1/staff/me').set(auth(bd));
    expect(status.status).toBe(200);
    expect(status.body.isStaff).toBe(false);
    expect((await ctx.http.get('/api/v1/staff/lives').set(auth(bd))).status).toBe(403);
    // The panel: only «استقطاباتي».
    const session = await aget(bd, '/admin/auth/session');
    expect(session.status).toBe(200);
    expect(session.body.capabilities).toEqual(['recruits.mine']);
    for (const path of ['/admin/moderation/reports', '/admin/lives', '/admin/recruits', '/admin/team', '/admin/users']) {
      expect((await aget(bd, path)).status, path).toBe(403);
    }
    expect((await aget(bd, '/admin/recruits/mine')).status).toBe(200);
    // Regions apply to BD (its line «تطوير الأعمال — الوطن العربي»).
    const regions = await aput(owner, `/admin/team/${bd.id}/regions`, {
      regions: ['ARAB_WORLD'],
      reason: 'BD region',
      totpCode: nextCode(owner.secret),
    });
    expect(regions.status, JSON.stringify(regions.body)).toBe(200);
    const again = await ctx.http.get('/api/v1/me').set(auth(bd));
    expect(again.body.staff).toMatchObject({ role: 'BD', regions: ['ARAB_WORLD'] });
  });

  it('the recruiter field: the live check finds only an ACTIVE MODERATION / BD staff member', async () => {
    const u = await signup();
    for (const q of [bdStaffId, bdStaffId.toLowerCase(), `@${bdStaffId}`, `kabso${String(Number(bdStaffId.slice(5)))}`]) {
      const r = await lookup(u, q);
      expect(r.found, q).toBe(true);
      expect(r.recruiter).toMatchObject({ staffId: bdStaffId, role: 'BD' });
    }
    expect((await lookup(u, modStaffId)).recruiter?.role).toBe('MODERATION');
    const modName = (await ctx.prisma.userProfile.findUniqueOrThrow({ where: { userId: moderator.id } })).username;
    expect((await lookup(u, `@${modName}`)).recruiter?.staffId).toBe(modStaffId);
    // SUPPORT, FINANCE, the OWNER, a normal user and nobody: «غير موجود» alike.
    const sup = await ctx.prisma.staffId.findUniqueOrThrow({ where: { userId: support.id } });
    for (const q of [`Kabso${String(sup.number).padStart(2, '0')}`, 'Kabso', fan.username, 'Kabso99', 'nobody_here']) {
      expect(await lookup(u, q), q).toEqual({ found: false, recruiter: null });
    }
    void financeStaff;
    const empty = await ctx.http.get('/api/v1/staff-recruiters/lookup').set(auth(u));
    expect(empty.status).toBe(400);
  });

  it('host: a bad recruiter is refused; the named one is attributed at the approval (audited); none without the field', async () => {
    const host = await signup();
    const bad = await applyHost(host, 'Kabso98');
    expect(bad.status).toBe(400);
    expect(issueOf(bad)).toEqual({ field: 'recruiter', issue: 'not_found' });
    const notRecruiter = await applyHost(host, fan.username);
    expect(issueOf(notRecruiter)).toEqual({ field: 'recruiter', issue: 'not_found' });
    const ok = await applyHost(host, bdStaffId.toLowerCase());
    expect(ok.status, JSON.stringify(ok.body)).toBe(201);
    const app = await ctx.prisma.hostApplication.findFirstOrThrow({ where: { userId: host.id } });
    expect(app.recruiterUserId).toBe(bd.id);
    // Not attributed before the activation.
    expect(await recruitmentOf(host, 'HOST')).toBeNull();
    const approve = await apost(support, `/admin/host-applications/${app.id}/approve`);
    expect(approve.status, JSON.stringify(approve.body)).toBe(200);
    const r = await recruitmentOf(host, 'HOST');
    expect(r).toMatchObject({ recruiterUserId: bd.id, applicationId: app.id });
    const audit = await audits('staff.recruit.attribute', r!.id);
    expect(audit).toHaveLength(1);
    expect(audit[0]!.metadata).toMatchObject({ type: 'HOST', recruiter: bd.id, recruit: host.id, via: 'panel' });

    // No field → no attribution.
    const plain = await signup();
    expect((await applyHost(plain)).status).toBe(201);
    const plainApp = await ctx.prisma.hostApplication.findFirstOrThrow({ where: { userId: plain.id } });
    expect((await apost(support, `/admin/host-applications/${plainApp.id}/approve`)).status).toBe(200);
    expect(await ctx.prisma.staffRecruitment.count({ where: { recruitUserId: plain.id } })).toBe(0);
  });

  it('agency: attributed at its opening (no approval); recharge agent at the approval', async () => {
    const agencyOwner = await signup();
    const res = await openAgency(agencyOwner, modStaffId);
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    const r = await recruitmentOf(agencyOwner, 'AGENCY');
    const agency = await ctx.prisma.agency.findUniqueOrThrow({ where: { ownerUserId: agencyOwner.id } });
    expect(r).toMatchObject({ recruiterUserId: moderator.id, agencyId: agency.id });
    expect((await audits('staff.recruit.attribute', r!.id))[0]!.metadata).toMatchObject({ via: 'app' });

    const agent = await signup();
    const bad = await applyRecharge(agent, 'Kabso97');
    expect(bad.status).toBe(400);
    expect(issueOf(bad)).toEqual({ field: 'recruiter', issue: 'not_found' });
    const ok = await applyRecharge(agent, `@${bdStaffId}`);
    expect(ok.status, JSON.stringify(ok.body)).toBe(201);
    const app = await ctx.prisma.rechargeAgentApplication.findFirstOrThrow({ where: { userId: agent.id } });
    expect(await recruitmentOf(agent, 'RECHARGE_AGENT')).toBeNull();
    const approve = await apost(support, `/admin/recharge/applications/${app.id}/approve`);
    expect(approve.status, JSON.stringify(approve.body)).toBe(200);
    expect(await recruitmentOf(agent, 'RECHARGE_AGENT')).toMatchObject({ recruiterUserId: bd.id });
  });

  it('creator programme: apply with a recruiter, approve in the panel → CREATOR; a HOST recruit is not attributed twice', async () => {
    const creator = await signup();
    const before = await ctx.http.get('/api/v1/me/creator-application').set(auth(creator));
    expectContract(before, 'getMyCreatorApplication');
    expect(before.body).toMatchObject({ member: null, application: null, rule: { canApply: true } });
    const bad = await applyCreator(creator, 'Kabso96');
    expect(issueOf(bad)).toEqual({ field: 'recruiter', issue: 'not_found' });
    const ok = await applyCreator(creator, bdStaffId);
    expect(ok.status, JSON.stringify(ok.body)).toBe(201);
    expectContract(ok, 'applyForCreatorProgramme');
    expect(ok.body.application).toMatchObject({ status: 'PENDING', recruiter: { staffId: bdStaffId } });
    const again = await applyCreator(creator);
    expect(again.status).toBe(409);
    expect(issueOf(again)).toEqual({ field: 'application', issue: 'PENDING' });
    // A staff account cannot apply.
    expect(issueOf(await applyCreator(bd))).toEqual({ field: 'application', issue: 'STAFF' });

    const list = await aget(support, '/admin/creator-applications?status=PENDING');
    expect(list.status).toBe(200);
    expectContract(list, 'listAdminCreatorApplications');
    const row = (list.body.data as { id: string; user: { id: string } }[]).find((a) => a.user.id === creator.id)!;
    expect((await apost(bd, `/admin/creator-applications/${row.id}/approve`)).status).toBe(403);
    const approve = await apost(support, `/admin/creator-applications/${row.id}/approve`);
    expect(approve.status, JSON.stringify(approve.body)).toBe(200);
    expect(approve.body.recruitmentId).toBeTruthy();
    expect(await recruitmentOf(creator, 'CREATOR')).toMatchObject({ recruiterUserId: bd.id });
    const member = await ctx.http.get('/api/v1/me/creator-application').set(auth(creator));
    expect(member.body).toMatchObject({ member: { activatedAt: expect.any(String) }, rule: { refusal: 'MEMBER' } });

    // A rejected one keeps the reason.
    const other = await signup();
    expect((await applyCreator(other)).status).toBe(201);
    const otherApp = await ctx.prisma.creatorApplication.findFirstOrThrow({ where: { userId: other.id } });
    expect((await apost(support, `/admin/creator-applications/${otherApp.id}/reject`, { reason: 'روابط غير صالحة' })).status).toBe(200);
    expect((await ctx.http.get('/api/v1/me/creator-application').set(auth(other))).body.application).toMatchObject({
      status: 'REJECTED',
      rejectReason: 'روابط غير صالحة',
    });

    // The host recruited by BD applies as a creator naming the moderator: the approval does not attribute again.
    const host = (await ctx.prisma.staffRecruitment.findFirstOrThrow({ where: { type: 'HOST' } })).recruitUserId;
    const hostUser = await ctx.prisma.user.findUniqueOrThrow({ where: { id: host } });
    const hostApp = await ctx.prisma.creatorApplication.create({
      data: {
        userId: hostUser.id,
        country: 'SA',
        category: 'VIDEO',
        links: ['https://x.example/a'],
        recruiterUserId: moderator.id,
      },
    });
    expect((await apost(support, `/admin/creator-applications/${hostApp.id}/approve`)).status).toBe(200);
    expect(await ctx.prisma.staffRecruitment.count({ where: { recruitUserId: host } })).toBe(1);
    const skip = await audits('staff.recruit.skip', host);
    expect(skip.map((s) => (s.metadata as { reason: string }).reason)).toContain('already_attributed');
  });

  it('a recruiter who lost the role before the activation attributes nothing (audited)', async () => {
    const temp = await makeAdmin(['MODERATION']);
    const tempId = (await ctx.prisma.staffId.findUniqueOrThrow({ where: { userId: temp.id } })).number;
    const host = await signup();
    expect((await applyHost(host, `Kabso${String(tempId).padStart(2, '0')}`)).status).toBe(201);
    await withMigrationClient((db) => db.$transaction((tx) => revokeRoleIn(tx, temp.email, 'MODERATION')));
    const app = await ctx.prisma.hostApplication.findFirstOrThrow({ where: { userId: host.id } });
    expect((await apost(support, `/admin/host-applications/${app.id}/approve`)).status).toBe(200);
    expect(await recruitmentOf(host, 'HOST')).toBeNull();
    const skip = await audits('staff.recruit.skip', host.id);
    expect((skip[0]!.metadata as { reason: string }).reason).toBe('recruiter_inactive');
  });

  it('the daily job: each recruiter gets its share of the ACTUAL profit once per day; withdrawable', async () => {
    const e = recruits().economy();
    const hostR = await ctx.prisma.staffRecruitment.findFirstOrThrow({
      where: { type: 'HOST', recruiterUserId: bd.id },
    });
    const host = people.get(hostR.recruitUserId)!;
    await sendGifts(fan, host, 10);
    // The agency's host: a gift to a host of the moderator's agency counts for the agency recruit.
    const agencyR = await ctx.prisma.staffRecruitment.findFirstOrThrow({ where: { type: 'AGENCY' } });
    const agency = await ctx.prisma.agency.findUniqueOrThrow({ where: { id: agencyR.agencyId! } });
    const agencyHost = await signup();
    const joinRes = await ctx.http
      .post('/api/v1/me/agency/join')
      .set(auth(agencyHost))
      .set('Idempotency-Key', randomUUID())
      .send({ inviteCode: agency.inviteCode });
    expect(joinRes.status, JSON.stringify(joinRes.body)).toBeLessThan(300);
    await ctx.prisma.liveHost.upsert({
      where: { userId: agencyHost.id },
      create: { userId: agencyHost.id, source: 'ADMIN' },
      update: {},
    });
    await sendGifts(fan, agencyHost, 5);
    // The recharge agent's wholesale top-up: 30 000 000 coins paid $360.
    const agentR = await ctx.prisma.staffRecruitment.findFirstOrThrow({ where: { type: 'RECHARGE_AGENT' } });
    await ctx.prisma.$transaction((tx) =>
      topUpIn(
        tx,
        agentR.recruitUserId,
        30_000_000n,
        36_000n,
        null,
        { activationMinCoins: 30_000_000, priceTiers: [{ minCoins: 0, minorPerMillion: 1200 }], currency: 'USD' },
        new Date(clock),
      ),
    );

    // Nothing is paid for today yet.
    expect((await recruits().sweep()).days).toBe(0);
    // The next day: yesterday is paid.
    setNow(Date.parse('2027-03-19T01:00:00.000Z'));
    const first = await recruits().sweep();
    expect(first.days).toBeGreaterThanOrEqual(4);

    const day = '2027-03-18';
    const row = (id: string) =>
      ctx.prisma.staffRecruitCommission.findUniqueOrThrow({
        where: { recruitmentId_day: { recruitmentId: id, day: new Date(`${day}T00:00:00Z`) } },
      });
    // HOST: 10 × 10 000 coins, the host's cherries from the ledger.
    const hostCherries = (
      await ctx.prisma.cherryLedgerEntry.aggregate({
        where: { userId: host.id, reason: 'GIFT_RECEIVED' },
        _sum: { delta: true },
      })
    )._sum.delta!;
    const hostProfit = giftProfitUnits(
      { charged: 100_000n, luckyCoins: 0n, cherries: hostCherries, commissions: 0n },
      e,
    );
    const h = await row(hostR.id);
    expect(h).toMatchObject({ bps: 100, recruiterUserId: bd.id, skipped: null });
    expect(BigInt(h.profitUnits.toString())).toBe(hostProfit);
    expect(h.cherries).toBe(commissionCherries(hostProfit, 100, e));
    expect(h.cherries > 0n).toBe(true);
    // AGENCY: its host's gifts less the agency's commission.
    const ag = await row(agencyR.id);
    const earning = await ctx.prisma.agencyEarning.findFirstOrThrow({ where: { hostUserId: agencyHost.id } });
    const agencyProfit = giftProfitUnits(
      {
        charged: 50_000n,
        luckyCoins: 0n,
        cherries: earning.hostCherries,
        commissions: earning.commission + earning.parentCommission,
      },
      e,
    );
    expect(BigInt(ag.profitUnits.toString())).toBe(agencyProfit);
    expect(ag).toMatchObject({ bps: 100, recruiterUserId: moderator.id });
    expect(ag.cherries).toBe(commissionCherries(agencyProfit, 100, e));
    // RECHARGE_AGENT: $360 − 195 000 000 cherries at $1.10 per million = $145.50 → 0.75 % = 992 045 cherries.
    const rc = await row(agentR.id);
    expect(BigInt(rc.profitUnits.toString())).toBe(topupProfitUnits({ paidMinor: 36_000n, coins: 30_000_000n }, e));
    expect(rc).toMatchObject({ bps: 75, cherries: 992_045n });
    // The ledger: one credit each, withdrawable reason.
    const ledger = await ctx.prisma.cherryLedgerEntry.findMany({
      where: { userId: bd.id, reason: 'STAFF_RECRUIT_COMMISSION' },
    });
    expect(ledger.map((l) => l.referenceId).sort()).toEqual(
      [`SR:${hostR.id}@${day}`, `SR:${agentR.id}@${day}`].sort(),
    );

    // Idempotent: a rerun and two concurrent runs pay nothing more.
    expect((await recruits().sweep()).days).toBe(0);
    const [a, b] = await Promise.all([recruits().sweep(), recruits().sweep()]);
    expect(a.days + b.days).toBe(0);
    expect(
      await ctx.prisma.cherryLedgerEntry.count({ where: { reason: 'STAFF_RECRUIT_COMMISSION' } }),
    ).toBe(ledger.length + (ag.cherries > 0n ? 1 : 0));
    // A day paid directly again is refused (null), the ledger unchanged.
    expect(await recruits().payDay(hostR.id, day, { HOST: 100, AGENCY: 100, RECHARGE_AGENT: 75, CREATOR: 100 })).toBeNull();

    // «أرباحي»: the balance, the breakdown and the history; withdrawable (not locked).
    const earnings = await ctx.http.get('/api/v1/me/staff/earnings').set(auth(bd));
    expect(earnings.status, JSON.stringify(earnings.body)).toBe(200);
    expectContract(earnings, 'getMyStaffEarnings');
    const total = Number(h.cherries + rc.cherries);
    expect(earnings.body.totalCherries).toBe(total);
    expect(earnings.body.wallet.cherries).toBe(total);
    expect(earnings.body.wallet.withdrawableCherries).toBe(total);
    expect(earnings.body.bps).toEqual({ HOST: 100, AGENCY: 100, RECHARGE_AGENT: 75, CREATOR: 100 });
    expect(earnings.body.history).toHaveLength(2);
    // The withdrawal: the existing flow, for the staff member's earnings.
    const w = await ctx.http
      .post('/api/v1/wallet/me/cherries/withdrawals')
      .set(auth(bd))
      .set('Idempotency-Key', randomUUID())
      .send({ amountMinor: 100, payoutDetails: 'Kabso staff payout' });
    expect(w.status, JSON.stringify(w.body)).toBe(201);
    expect((await ctx.http.get('/api/v1/me/staff/earnings').set(auth(bd))).body.wallet.pendingWithdrawal).toBeTruthy();
    // Not a recruiter → 403.
    expect((await ctx.http.get('/api/v1/me/staff/earnings').set(auth(fan))).status).toBe(403);
    expect((await ctx.http.get('/api/v1/me/staff/recruits').set(auth(support))).status).toBe(403);
  });

  it('staff see only their own recruits; the OWNER sees everyone and the team list counts them', async () => {
    const mineApp = await ctx.http.get('/api/v1/me/staff/recruits').set(auth(bd));
    expect(mineApp.status).toBe(200);
    expectContract(mineApp, 'getMyStaffRecruits');
    expect(mineApp.body.counts).toMatchObject({ HOST: 1, RECHARGE_AGENT: 1, CREATOR: 1, AGENCY: 0, total: 3 });
    const hostsOnly = await ctx.http.get('/api/v1/me/staff/recruits?type=HOST').set(auth(bd));
    expect(hostsOnly.body.data).toHaveLength(1);
    expect(hostsOnly.body.data[0]).toMatchObject({ type: 'HOST', status: 'ACTIVE' });
    const modApp = await ctx.http.get('/api/v1/me/staff/recruits').set(auth(moderator));
    expect(modApp.body.counts).toMatchObject({ AGENCY: 1, total: 1 });

    const panelMine = await aget(bd, '/admin/recruits/mine');
    expectContract(panelMine, 'getAdminMyRecruits');
    expect((panelMine.body.data as { recruit: { id: string } }[]).length).toBe(3);
    const modRecruit = await ctx.prisma.staffRecruitment.findFirstOrThrow({ where: { recruiterUserId: moderator.id } });
    expect((await aget(bd, `/admin/recruits/mine/${modRecruit.id}/commissions`)).status).toBe(404);
    expect((await aget(moderator, `/admin/recruits/mine/${modRecruit.id}/commissions`)).status).toBe(200);

    const all = await aget(owner, '/admin/recruits');
    expect(all.status).toBe(200);
    expectContract(all, 'listAdminRecruits');
    expect(all.body.data.length).toBeGreaterThanOrEqual(4);
    const staff = await aget(owner, '/admin/recruits/staff');
    expectContract(staff, 'listAdminRecruitStaff');
    const bdRow = (staff.body.data as { userId: string; roles: string[]; canRecruit: boolean; commissionCherries: number }[]).find(
      (s) => s.userId === bd.id,
    )!;
    expect(bdRow).toMatchObject({ roles: ['BD'], canRecruit: true });
    expect(bdRow.commissionCherries).toBeGreaterThan(0);
    const team = await aget(owner, '/admin/team');
    expect(team.status).toBe(200);
    expectContract(team, 'listAdminTeam');
    const bdTeam = (team.body.data as { id: string; roles: string[]; recruits: { total: number } }[]).find((t) => t.id === bd.id)!;
    expect(bdTeam.roles).toEqual(['BD']);
    expect(bdTeam.recruits.total).toBe(3);
    // MODERATION and SUPPORT cannot see the OWNER's views.
    expect((await aget(moderator, '/admin/recruits')).status).toBe(403);
    expect((await aget(support, '/admin/recruits/staff')).status).toBe(403);
  });

  it('the OWNER: the shares (code + reason, audited) and the reassignment; the next days go to the new recruiter', async () => {
    const settings = await aget(owner, '/admin/recruits/settings');
    expectContract(settings, 'getAdminRecruitSettings');
    expect(settings.body.bps).toEqual({ HOST: 100, AGENCY: 100, RECHARGE_AGENT: 75, CREATOR: 100 });
    expect(settings.body.defaults).toEqual({ HOST: 100, AGENCY: 100, RECHARGE_AGENT: 75, CREATOR: 100 });
    expect(
      (await aput(owner, '/admin/recruits/settings', { host: 2001, reason: 'x', totpCode: nextCode(owner.secret) })).status,
    ).toBe(400);
    expect((await aput(bd, '/admin/recruits/settings', { host: 150, reason: 'x', totpCode: '000000' })).status).toBe(403);
    const changed = await aput(owner, '/admin/recruits/settings', {
      host: 150,
      reason: 'حملة استقطاب',
      totpCode: nextCode(owner.secret),
    });
    expect(changed.status, JSON.stringify(changed.body)).toBe(200);
    expect(changed.body.bps.HOST).toBe(150);
    const audit = await audits('staff.recruit.settings.update');
    expect(audit.at(-1)!.metadata).toMatchObject({ before: { HOST: 100 }, after: { HOST: 150 }, reason: 'حملة استقطاب' });

    const hostR = await ctx.prisma.staffRecruitment.findFirstOrThrow({ where: { type: 'HOST', recruiterUserId: bd.id } });
    // Refusals: not a recruiter, the same one; MODERATION cannot reassign.
    const notRecruiter = await apost(owner, `/admin/recruits/${hostR.id}/reassign`, {
      recruiter: fan.username,
      reason: 'x',
      totpCode: nextCode(owner.secret),
    });
    expect(notRecruiter.status).toBe(409);
    expect(issueOf(notRecruiter)).toEqual({ field: 'recruiter', issue: 'recruiter_not_found' });
    const same = await apost(owner, `/admin/recruits/${hostR.id}/reassign`, {
      recruiter: bdStaffId,
      reason: 'x',
      totpCode: nextCode(owner.secret),
    });
    expect(issueOf(same)).toEqual({ field: 'recruiter', issue: 'recruiter_same' });
    expect(
      (await apost(moderator, `/admin/recruits/${hostR.id}/reassign`, { recruiter: modStaffId, reason: 'x', totpCode: '000000' }))
        .status,
    ).toBe(403);
    const ok = await apost(owner, `/admin/recruits/${hostR.id}/reassign`, {
      recruiter: modStaffId,
      reason: 'نقل إلى المشرف',
      totpCode: nextCode(owner.secret),
    });
    expect(ok.status, JSON.stringify(ok.body)).toBe(200);
    expectContract(ok, 'reassignAdminRecruit');
    expect(ok.body.recruiter.id).toBe(moderator.id);
    expect((await audits('staff.recruit.reassign', hostR.id))[0]!.metadata).toMatchObject({
      before: bd.id,
      after: moderator.id,
      reason: 'نقل إلى المشرف',
    });

    // A gift on 2027-03-19; the next day it is paid to the moderator at 1.5 %.
    // Yesterday's lives are over (their heartbeat went stale): the host goes live again.
    await ctx.prisma.liveRoom.updateMany({
      where: { status: 'LIVE' },
      data: { status: 'ENDED', endedAt: new Date(clock), endReason: 'HOST_ENDED' },
    });
    await sendGifts(fan, people.get(hostR.recruitUserId)!, 10);
    setNow(Date.parse('2027-03-20T01:00:00.000Z'));
    await recruits().sweep();
    const day19 = await ctx.prisma.staffRecruitCommission.findUniqueOrThrow({
      where: { recruitmentId_day: { recruitmentId: hostR.id, day: new Date('2027-03-19T00:00:00Z') } },
    });
    expect(day19).toMatchObject({ recruiterUserId: moderator.id, bps: 150 });
    expect(day19.cherries > 0n).toBe(true);
    // The day paid before stays with BD.
    const day18 = await ctx.prisma.staffRecruitCommission.findUniqueOrThrow({
      where: { recruitmentId_day: { recruitmentId: hostR.id, day: new Date('2027-03-18T00:00:00Z') } },
    });
    expect(day18.recruiterUserId).toBe(bd.id);
    // The commission rows are append-only for the runtime role.
    await expect(
      ctx.prisma.$executeRawUnsafe(`UPDATE staff_recruit_commissions SET cherries = cherries + 1 WHERE recruitment_id = '${hostR.id}'`),
    ).rejects.toThrow(/permission denied/);
  });

});
