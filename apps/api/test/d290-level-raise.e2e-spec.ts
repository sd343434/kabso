/**
 * D290 (owner, contract v1.89-social, CONVENTIONS §10.103): level-raise requests «طلب رفع ليفيل», end to end against
 * PostgreSQL + Redis:
 *
 *  - capabilities: `levels.raise.request` MODERATION / SUPPORT (app and panel), `levels.raise.decide` OWNER only;
 *    403 for FINANCE, BD and plain users;
 *  - creating with the video (`LEVEL_RAISE_VIDEO`, app presigned flow and the panel's raw upload), one PENDING per
 *    supporter, no Kabso Team target, the "other" app with its typed name, a video used once;
 *  - the eligibility threshold (≥ 1 000 000 coins recharged) blocks approval, not creation;
 *  - approval raises the SUPPORT level through the engine (one ADJUSTMENT entry, history, frames), never above the
 *    proposal or 40, never below the current level; rejection with a reason; every step audited;
 *  - notifications: the staff member on both results, the supporter only when the level rose;
 *  - the OWNER's source-app data and weights (audited), the video proxy with ranges.
 */
import { randomUUID } from 'node:crypto';
import sharp from 'sharp';
import type request from 'supertest';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { grantRoleIn } from '../src/modules/admin-panel/admin-roles.js';
import { BAG_CATALOGUE } from '../src/modules/bag/bag.catalogue.js';
import { presetLadder } from '../src/modules/levels/level-preset.js';
import { totpCode } from '../src/modules/admin-panel/totp.js';
import { loadCategory } from '../src/modules/levels/level-catalog.js';
import { LevelProgressService } from '../src/modules/levels/level-progress.service.js';
import { MediaService } from '../src/modules/media/media.service.js';
import { OBJECT_STORAGE } from '../src/modules/media/object-storage.js';
import { creditIn } from '../src/modules/wallet/wallet-ledger.js';
import { MemoryObjectStorage } from './helpers/memory-storage.js';
import { mp4 } from './helpers/mp4.js';
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

describe('D290 contract coverage', () => {
  it('openapi v1.89-social declares the level-raise operations', () => {
    const ids = operations().map((o) => `${o.operationId} ${o.method.toUpperCase()} ${o.path}`);
    expect(ids).toEqual(
      expect.arrayContaining([
        'listStaffLevelRaiseSourceApps GET /api/v1/staff/level-raises/source-apps',
        'checkStaffLevelRaise GET /api/v1/staff/level-raises/check',
        'listMyStaffLevelRaises GET /api/v1/staff/level-raises',
        'createStaffLevelRaise POST /api/v1/staff/level-raises',
        'listAdminLevelRaises GET /api/v1/admin/level-raises',
        'createAdminLevelRaise POST /api/v1/admin/level-raises',
        'checkAdminLevelRaise GET /api/v1/admin/level-raises/check',
        'listAdminLevelRaiseSourceAppOptions GET /api/v1/admin/level-raises/source-apps',
        'uploadAdminLevelRaiseVideo POST /api/v1/admin/level-raise-videos',
        'getAdminLevelRaise GET /api/v1/admin/level-raises/{requestId}',
        'getAdminLevelRaiseVideo GET /api/v1/admin/level-raises/{requestId}/video',
        'approveAdminLevelRaise POST /api/v1/admin/level-raises/{requestId}/approve',
        'rejectAdminLevelRaise POST /api/v1/admin/level-raises/{requestId}/reject',
        'listAdminLevelRaiseApps GET /api/v1/admin/level-raise/apps',
        'createAdminLevelRaiseApp POST /api/v1/admin/level-raise/apps',
        'updateAdminLevelRaiseApp PUT /api/v1/admin/level-raise/apps/{appId}',
        'getAdminLevelRaiseSettings GET /api/v1/admin/level-raise/settings',
        'updateAdminLevelRaiseSettings PUT /api/v1/admin/level-raise/settings',
      ]),
    );
  });
});

describe('D290 level-raise requests', { timeout: 900_000 }, () => {
  const storage = new MemoryObjectStorage();
  let ctx: TestContext;
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
  const cookieOf = (res: request.Response): string => {
    const raw = ([] as string[]).concat(res.headers['set-cookie'] ?? []);
    const line = raw.find((c) => c.startsWith(`${COOKIE}=`));
    if (!line) throw new Error(`no session cookie in ${JSON.stringify(raw)}`);
    return line.split(';')[0]!;
  };
  /** The real clock (the API checks the code against it; each admin has its own secret, used once). */
  const nextCode = (secret: string) => totpCode(secret, Date.now());
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
  const aput = (a: Admin, path: string, body: object = {}) =>
    ctx.http.put(`/api/v1${path}`).set('Cookie', a.cookie).set('X-CSRF-Token', a.csrf).send(body);

  /** The app flow: a poster, the video's presigned slot, complete with {posterId}. */
  const appVideo = async (u: TestUser): Promise<string> => {
    const jpg = await sharp({ create: { width: 540, height: 960, channels: 3, background: '#357' } })
      .jpeg()
      .toBuffer();
    const p = await ctx.http
      .post('/api/v1/media/uploads')
      .set(auth(u))
      .send({ kind: 'VIDEO_POSTER', contentType: 'image/jpeg', byteSize: jpg.length });
    expect(p.status, JSON.stringify(p.body)).toBe(201);
    expect(storage.upload(p.body.uploadUrl as string, jpg, 'image/jpeg')).toBe(true);
    const posterDone = await ctx.http
      .post(`/api/v1/media/uploads/${p.body.uploadId as string}/complete`)
      .set(auth(u));
    expect(posterDone.status).toBe(200);
    const bytes = mp4({ durationMs: 20_000, width: 1080, height: 1920 });
    const v = await ctx.http
      .post('/api/v1/media/uploads')
      .set(auth(u))
      .send({ kind: 'LEVEL_RAISE_VIDEO', contentType: 'video/mp4', byteSize: bytes.length });
    expect(v.status, JSON.stringify(v.body)).toBe(201);
    expect(storage.upload(v.body.uploadUrl as string, bytes, 'video/mp4')).toBe(true);
    const done = await ctx.http
      .post(`/api/v1/media/uploads/${v.body.uploadId as string}/complete`)
      .set(auth(u))
      .send({ posterId: posterDone.body.id as string });
    expect(done.status, JSON.stringify(done.body)).toBe(200);
    expect(done.body.type).toBe('VIDEO');
    return done.body.id as string;
  };
  const appCreate = (u: TestUser, body: object) =>
    ctx.http.post('/api/v1/staff/level-raises').set(auth(u)).send(body);
  const recharge = (
    u: TestUser,
    coins: bigint,
    reason: 'RECHARGE_PURCHASE' | 'CARD_TOPUP' = 'RECHARGE_PURCHASE',
  ) => ctx.prisma.$transaction((tx) => creditIn(tx, u.id, coins, reason, randomUUID()));
  const supportState = async (u: TestUser) => {
    const category = await loadCategory(ctx.prisma, 'SUPPORT');
    return ctx.prisma.userLevelState.findUnique({
      where: { userId_categoryId: { userId: u.id, categoryId: category.id } },
    });
  };
  const notes = (recipientId: string) =>
    ctx.prisma.notification.findMany({ where: { recipientId, levelRaiseRequestId: { not: null } } });
  const audits = (action: string, targetId?: string) =>
    ctx.prisma.auditLog.findMany({ where: { action, ...(targetId ? { targetId } : {}) } });

  let owner: Admin;
  let moderator: Admin;
  let support: Admin;
  let finance: Admin;
  let bd: Admin;
  let plain: TestUser;

  beforeAll(async () => {
    ctx = await createTestApp(
      {
        MEDIA_UPLOADS_ENABLED: 'true',
        S3_BUCKET: 'kabso-media-test',
        S3_ACCESS_KEY_ID: 'test',
        S3_SECRET_ACCESS_KEY: 'test',
        MEDIA_PUBLIC_BASE_URL: 'https://media.example.test',
        ADMIN_TOTP_KEY: 'admin-totp-test-key-0123456789-abcdefghijklmnop',
        ADMIN_SESSION_IDLE_SECONDS: '86400',
        ADMIN_SESSION_MAX_SECONDS: '604800',
        RATE_LIMIT_ADMIN_LOGIN_IP: '10000/900',
        RATE_LIMIT_ADMIN_IP: '100000/900',
        RATE_LIMIT_STAFF_APP_USER: '100000/900',
        RATE_LIMIT_MEDIA_UPLOAD_USER: '100000/900',
      },
      [{ token: OBJECT_STORAGE, value: storage }],
    );
    // The levels and the support frames as their migrations seed them (the e2e database is truncated, d169).
    await ctx.prisma.bagItem.createMany({ data: BAG_CATALOGUE.map((i) => ({ ...i })) });
    for (const [code, nameAr, nameEn] of [
      ['ATTRACTIVENESS', 'مستوى الجاذبية', 'Attractiveness'],
      ['WIZARD', 'مستوى الساحر', 'Wizard'],
      ['GAMING', 'مستوى اللعب', 'Gaming'],
    ] as const) {
      await ctx.prisma.levelCategory.create({
        data: { code, nameAr, nameEn, descriptionAr: `وصف ${nameAr}`, descriptionEn: `About ${nameEn}` },
      });
    }
    const category = await ctx.prisma.levelCategory.create({
      data: {
        code: 'SUPPORT',
        nameAr: 'مستوى الدعم',
        nameEn: 'Support',
        descriptionAr: 'الدعم',
        descriptionEn: 'Support',
      },
    });
    const version = await ctx.prisma.levelCategoryVersion.create({
      data: {
        categoryId: category.id,
        versionNumber: 1,
        status: 'PUBLISHED',
        multiplier: '0.1',
        valueUnit: 'COIN',
        publishedAt: new Date(),
        levels: { create: presetLadder() },
      },
    });
    await ctx.prisma.levelCategory.update({
      where: { id: category.id },
      data: { isEnabled: true, publishedVersionId: version.id },
    });
    owner = await makeAdmin(['OWNER']);
    moderator = await makeAdmin(['MODERATION']);
    support = await makeAdmin(['SUPPORT']);
    finance = await makeAdmin(['FINANCE']);
    bd = await makeAdmin(['BD']);
    plain = await signup();
  });
  afterAll(async () => ctx?.close());

  it('source apps: seeded, Zafa confirmed, the rest estimates, "other" last', async () => {
    const res = await ctx.http.get('/api/v1/staff/level-raises/source-apps').set(auth(moderator));
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    expectContract(res, 'listStaffLevelRaiseSourceApps');
    const data = res.body.data as { code: string; confidence: string; isOther: boolean }[];
    expect(data[0]).toMatchObject({ code: 'ZAFA', confidence: 'CONFIRMED' });
    expect(data.at(-1)).toMatchObject({ code: 'OTHER', isOther: true, confidence: 'ESTIMATE' });
    expect(data.filter((a) => a.confidence === 'CONFIRMED').map((a) => a.code)).toEqual(['ZAFA']);
  });

  it('capabilities: 403 for FINANCE, BD and plain users; SUPPORT cannot decide', async () => {
    for (const who of [finance, bd, plain]) {
      const app = await ctx.http.get('/api/v1/staff/level-raises').set(auth(who));
      expect(app.status).toBe(403);
      const post = await appCreate(who, {});
      expect(post.status).toBe(403);
    }
    for (const who of [finance, bd]) {
      expect((await aget(who, '/admin/level-raises')).status).toBe(403);
      expect((await aget(who, '/admin/level-raise/apps')).status).toBe(403);
    }
    expect((await aget(support, '/admin/level-raise/apps')).status).toBe(403);
    expect((await aget(support, '/admin/level-raise/settings')).status).toBe(403);
    expect((await aget(moderator, `/admin/level-raises/${randomUUID()}`)).status).toBe(403);
    expect((await apost(support, `/admin/level-raises/${randomUUID()}/approve`, { level: 5 })).status).toBe(
      403,
    );
    expect(
      (await apost(moderator, `/admin/level-raises/${randomUUID()}/reject`, { reason: 'x' })).status,
    ).toBe(403);
    expect((await aget(owner, `/admin/level-raises/${randomUUID()}`)).status).toBe(404);
  });

  let first = '';
  let supporter: TestUser;

  it('creates from the app with the video before the threshold; one open request; refusals', async () => {
    supporter = await signup();
    const check = await ctx.http
      .get('/api/v1/staff/level-raises/check')
      .query({ username: `@${supporter.username}` })
      .set(auth(moderator));
    expect(check.status, JSON.stringify(check.body)).toBe(200);
    expectContract(check, 'checkStaffLevelRaise');
    expect(check.body).toMatchObject({
      found: true,
      openRequest: false,
      staffAccount: false,
      evidence: {
        totalRechargeCoins: 0,
        firstDaysRechargeCoins: 0,
        eligible: false,
        minRechargeCoins: 1_000_000,
      },
    });
    const video = await appVideo(moderator);
    const base = {
      username: supporter.username,
      sourceApp: 'ZAFA',
      sourceAccountId: '88123456',
      sourceLevel: 32,
      videoId: video,
      note: 'داعم من زفة',
    };
    // Unknown username, unknown app, a Kabso Team target, the "other" app without its name.
    expect(issueOf(await appCreate(moderator, { ...base, username: 'nobody_here_x' }))).toEqual({
      field: 'username',
      issue: 'not_found',
    });
    expect(issueOf(await appCreate(moderator, { ...base, sourceApp: 'NOPE' }))?.field).toBe('sourceApp');
    const staffTarget = await appCreate(moderator, { ...base, username: support.username });
    expect(staffTarget.status).toBe(409);
    expect(issueOf(staffTarget)?.issue).toBe('level_raise_staff_account');
    expect(issueOf(await appCreate(moderator, { ...base, sourceApp: 'OTHER' }))).toEqual({
      field: 'sourceAppName',
      issue: 'required',
    });
    // Somebody else's video is not attachable.
    expect(issueOf(await appCreate(support, base))).toEqual({ field: 'videoId', issue: 'invalid_value' });

    const res = await appCreate(moderator, base);
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    expectContract(res, 'createStaffLevelRaise');
    expect(res.body).toMatchObject({
      status: 'PENDING',
      via: 'app',
      sourceApp: { code: 'ZAFA', confidence: 'CONFIRMED' },
      sourceAppName: 'Zafa',
      sourceAccountId: '88123456',
      sourceLevel: 32,
      supporter: { id: supporter.id },
      requestedBy: { id: moderator.id },
      video: { id: video, durationMs: 20_000 },
    });
    first = res.body.id as string;
    expect((await audits('level.raise.request', first))[0]?.metadata).toMatchObject({
      via: 'app',
      app: 'ZAFA',
    });

    // The same source account again (any supporter, any staff member, the ID in another case, the app by an
    // alias typed as "other") → 409 LEVEL_RAISE_DUPLICATE with the existing request's status, date and staff member.
    const again = await appVideo(moderator);
    const other = await signup();
    const modName = (await ctx.prisma.userProfile.findUniqueOrThrow({ where: { userId: moderator.id } }))
      .displayName;
    for (const body of [
      { ...base, videoId: again },
      { ...base, username: other.username, videoId: again, sourceAccountId: ' 88123456 ' },
      { ...base, username: other.username, videoId: again, sourceApp: 'OTHER', sourceAppName: 'زفه' },
    ]) {
      const dup = await appCreate(support, body);
      expect(dup.status, JSON.stringify(dup.body)).toBe(409);
      expect(dup.body.error.code).toBe('LEVEL_RAISE_DUPLICATE');
      expect(dup.body.error.details).toEqual([
        { field: 'status', issue: 'PENDING' },
        { field: 'createdAt', issue: res.body.createdAt },
        { field: 'requestedBy', issue: modName },
      ]);
    }
    // A second open request for the supporter (another source account).
    const open = await appCreate(moderator, { ...base, videoId: again, sourceAccountId: '777' });
    expect(open.status).toBe(409);
    expect(issueOf(open)?.issue).toBe('level_raise_open_exists');
    // The same video for someone else.
    expect(
      issueOf(await appCreate(moderator, { ...base, username: other.username, sourceAccountId: '778' })),
    ).toEqual({
      field: 'videoId',
      issue: 'invalid_value',
    });

    const mine = await ctx.http.get('/api/v1/staff/level-raises').set(auth(moderator));
    expect(mine.status).toBe(200);
    expectContract(mine, 'listMyStaffLevelRaises');
    expect((mine.body.data as { id: string }[]).map((r) => r.id)).toContain(first);
  });

  it('the OWNER sees the proposal; approval waits for 1 000 000 recharged', async () => {
    const detail = await aget(owner, `/admin/level-raises/${first}`);
    expect(detail.status, JSON.stringify(detail.body)).toBe(200);
    expectContract(detail, 'getAdminLevelRaise');
    expect(detail.body.proposal).toMatchObject({
      eligible: false,
      source: {
        mode: 'MONEY',
        level: 58,
        xp: 27_742_536,
        sourceCoins: 277_425_360,
        usd: 5548.5,
        kabsoCoins: 443_880_576,
        kabsoPoints: 44_388_057,
      },
      rechargeCap: 0,
    });
    const early = await apost(owner, `/admin/level-raises/${first}/approve`, { level: 1 });
    expect(early.status).toBe(409);
    expect(issueOf(early)?.issue).toBe('level_raise_not_eligible');
    expect((await supportState(supporter))?.currentLevel ?? null).toBeNull();
  });

  it('approves through the engine: never above the proposal, notifications, audit, replay refused', async () => {
    await recharge(supporter, 1_000_000n);
    const detail = await aget(owner, `/admin/level-raises/${first}`);
    expect(detail.body.proposal).toMatchObject({
      eligible: true,
      firstDaysCap: 20,
      totalCap: 15,
      rechargeCap: 20,
      proposedLevel: 20,
      limitedBy: 'RECHARGE',
      evidence: { totalRechargeCoins: 1_000_000, firstDaysRechargeCoins: 1_000_000 },
    });
    const above = await apost(owner, `/admin/level-raises/${first}/approve`, { level: 21 });
    expect(above.status).toBe(409);
    expect(issueOf(above)).toEqual({ field: 'level', issue: 'level_raise_above_proposal' });

    const ok = await apost(owner, `/admin/level-raises/${first}/approve`, { level: 20, reason: 'زفة 32' });
    expect(ok.status, JSON.stringify(ok.body)).toBe(200);
    expectContract(ok, 'approveAdminLevelRaise');
    expect(ok.body.request).toMatchObject({
      status: 'APPROVED',
      approvedLevel: 20,
      proposedLevel: 20,
      levelBefore: 0,
      levelAfter: 20,
      decidedBy: { id: owner.id },
    });
    const state = await supportState(supporter);
    expect(state?.currentLevel).toBe(20);
    const category = await loadCategory(ctx.prisma, 'SUPPORT');
    const l20 = category.version!.levels.find((l) => l.levelNumber === 20)!;
    expect((state?.totalPoints ?? 0n) + (state?.carriedPoints ?? 0n)).toBe(l20.requiredPoints);
    const entry = await ctx.prisma.pointsLedgerEntry.findUnique({
      where: { idempotencyKey: `level-raise:${first}` },
    });
    expect(entry).toMatchObject({ entryType: 'ADJUSTMENT', sourceType: 'ADMIN', createdById: owner.id });
    expect(
      await ctx.prisma.levelHistory.count({
        where: { userId: supporter.id, ledgerEntryId: entry!.id, newLevel: 20 },
      }),
    ).toBe(1);
    // The support frames of the tiers reached come with the engine (D169).
    const [frames] = await ctx.prisma.$queryRaw<{ n: bigint }[]>`
      SELECT count(*)::bigint AS n FROM user_bag_items
       WHERE user_id = ${supporter.id}::uuid AND source = 'LEVEL_REWARD'::bag_item_source`;
    expect(Number(frames?.n ?? 0n)).toBeGreaterThan(0);
    expect((await audits('level.raise.approve', first))[0]?.metadata).toMatchObject({
      approvedLevel: 20,
      proposedLevel: 20,
      before: 0,
      after: 20,
      ledgerEntry: entry!.id,
    });
    // The video is deleted after the decision: objects and asset row gone, the evidence kept (request + audit).
    const kept = await ctx.prisma.levelRaiseRequest.findUniqueOrThrow({ where: { id: first } });
    expect(kept.videoMediaId).toBeNull();
    expect(kept.videoDeletedAt).not.toBeNull();
    expect(kept).toMatchObject({ videoDurationMs: 20_000, videoWidth: 1080, videoHeight: 1920 });
    expect(await ctx.prisma.mediaAsset.count({ where: { id: kept.videoAssetId } })).toBe(0);
    expect([...storage.objects.keys()].filter((k) => k.includes(kept.videoAssetId))).toEqual([]);
    expect(ok.body.request.video).toMatchObject({
      id: kept.videoAssetId,
      posterUrl: null,
      durationMs: 20_000,
    });
    expect(ok.body.request.video.deletedAt).toBe(kept.videoDeletedAt!.toISOString());
    expect((await audits('level.raise.approve', first))[0]?.metadata).toMatchObject({
      video: { mediaId: kept.videoAssetId, durationMs: 20_000, byteSize: kept.videoByteSize, sha256: null },
    });
    expect((await aget(owner, `/admin/level-raises/${first}/video`)).status).toBe(404);
    expect((await notes(moderator.id)).map((n) => n.type)).toEqual(['LEVEL_RAISE_APPROVED']);
    expect((await notes(supporter.id)).map((n) => n.type)).toEqual(['LEVEL_RAISED']);
    const inbox = await ctx.http.get('/api/v1/notifications').set(auth(supporter));
    expect(inbox.status).toBe(200);
    expectContract(inbox, 'listNotifications');
    const raised = (
      inbox.body.data as { type: string; target: { type: string; level?: number } | null }[]
    ).find((n) => n.type === 'LEVEL_RAISED');
    expect(raised?.target).toMatchObject({ type: 'LEVEL_RAISE', level: 20 });

    const replay = await apost(owner, `/admin/level-raises/${first}/approve`, { level: 20 });
    expect(replay.status).toBe(409);
    expect(issueOf(replay)?.issue).toBe('level_raise_not_pending');
    expect((await supportState(supporter))?.currentLevel).toBe(20);
  });

  it('32 000 000 in the first week → 40; never above 40', async () => {
    const big = await signup();
    await recharge(big, 32_000_000n, 'CARD_TOPUP');
    const res = await appCreate(moderator, {
      username: big.username,
      sourceApp: 'ZAFA',
      sourceAccountId: 'z-999',
      sourceLevel: 32,
      videoId: await appVideo(moderator),
    });
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    const id = res.body.id as string;
    const detail = await aget(owner, `/admin/level-raises/${id}`);
    expect(detail.body.proposal).toMatchObject({ proposedLevel: 40, firstDaysCap: 40 });
    const tooHigh = await apost(owner, `/admin/level-raises/${id}/approve`, { level: 41 });
    expect(issueOf(tooHigh)?.issue).toBe('level_raise_above_max');
    const ok = await apost(owner, `/admin/level-raises/${id}/approve`, { level: 40 });
    expect(ok.status, JSON.stringify(ok.body)).toBe(200);
    expect((await supportState(big))?.currentLevel).toBe(40);
  });

  it('never below the current level; approving at the current level changes nothing', async () => {
    const high = await signup();
    await recharge(high, 1_000_000n);
    // Level 30 earned earlier (an admin adjustment through the engine).
    await ctx.prisma.$transaction(async (tx) => {
      const category = await loadCategory(tx, 'SUPPORT', 'share');
      const l30 = category.version!.levels.find((l) => l.levelNumber === 30)!;
      await ctx.app.get(LevelProgressService).apply(tx, category, {
        userId: high.id,
        entryType: 'ADJUSTMENT',
        sourceType: 'ADMIN',
        pointsDelta: l30.requiredPoints,
        idempotencyKey: `d290-test-${high.id}`,
        reason: 'test',
        createdById: owner.id,
      });
    });
    const res = await appCreate(moderator, {
      username: high.username,
      sourceApp: 'OTHER',
      sourceAppName: 'تطبيق صوتي',
      sourceAccountId: 'abc',
      sourceLevel: 50,
      videoId: await appVideo(moderator),
    });
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    expect(res.body).toMatchObject({
      sourceAppName: 'تطبيق صوتي',
      sourceApp: { code: 'OTHER', isOther: true },
    });
    const id = res.body.id as string;
    const detail = await aget(owner, `/admin/level-raises/${id}`);
    // factor 0.5 → 25, + support bonus 2 = 27; cap 20; current 30 wins.
    expect(detail.body.proposal).toMatchObject({
      source: { mode: 'FACTOR', level: 25, factor: 0.5 },
      proposedLevel: 30,
      limitedBy: 'CURRENT_LEVEL',
      evidence: { supportLevel: 30 },
    });
    const below = await apost(owner, `/admin/level-raises/${id}/approve`, { level: 29 });
    expect(issueOf(below)?.issue).toBe('level_raise_below_current');
    const before = await notes(high.id);
    const ok = await apost(owner, `/admin/level-raises/${id}/approve`, { level: 30 });
    expect(ok.status, JSON.stringify(ok.body)).toBe(200);
    expect(ok.body.request).toMatchObject({ levelBefore: 30, levelAfter: 30, approvedLevel: 30 });
    expect(await ctx.prisma.pointsLedgerEntry.count({ where: { idempotencyKey: `level-raise:${id}` } })).toBe(
      0,
    );
    expect((await notes(high.id)).length).toBe(before.length); // no LEVEL_RAISED: nothing rose
  });

  it('rejects with a reason: the staff member is told, the supporter is not', async () => {
    const s = await signup();
    const res = await appCreate(support, {
      username: s.username,
      sourceApp: 'BIGO_LIVE',
      sourceAccountId: '123',
      sourceLevel: 20,
      videoId: await appVideo(support),
    });
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    const id = res.body.id as string;
    expect((await apost(owner, `/admin/level-raises/${id}/reject`, {})).status).toBe(400);
    // The storage fails at the decision: the decision stands, the sweep deletes the video later.
    const realDelete = storage.delete.bind(storage);
    storage.delete = () => Promise.reject(new Error('storage down'));
    const no = await apost(owner, `/admin/level-raises/${id}/reject`, { reason: 'الفيديو لا يظهر الايدي' });
    storage.delete = realDelete;
    expect(no.status, JSON.stringify(no.body)).toBe(200);
    expectContract(no, 'rejectAdminLevelRaise');
    expect(no.body.request).toMatchObject({ status: 'REJECTED', rejectReason: 'الفيديو لا يظهر الايدي' });
    expect((await notes(support.id)).map((n) => n.type)).toEqual(['LEVEL_RAISE_REJECTED']);
    expect(await notes(s.id)).toEqual([]);
    expect((await audits('level.raise.reject', id)).length).toBe(1);
    // Rejected too: the video is marked deleted at once («حُذف الفيديو بعد القرار») …
    let row = await ctx.prisma.levelRaiseRequest.findUniqueOrThrow({ where: { id } });
    expect(row.videoDeletedAt).not.toBeNull();
    expect(no.body.request.video.deletedAt).toBe(row.videoDeletedAt!.toISOString());
    expect(row.videoMediaId).toBe(row.videoAssetId); // … but the storage refused: still there
    expect((await aget(owner, `/admin/level-raises/${id}/video`)).status).toBe(404);
    // … until the media sweep retries (idempotent: a second run finds nothing).
    const media = ctx.app.get(MediaService);
    expect(await media.purgeLevelRaiseVideos()).toBe(1);
    expect(await media.purgeLevelRaiseVideos()).toBe(0);
    row = await ctx.prisma.levelRaiseRequest.findUniqueOrThrow({ where: { id } });
    expect(row.videoMediaId).toBeNull();
    expect(await ctx.prisma.mediaAsset.count({ where: { id: row.videoAssetId } })).toBe(0);
    expect([...storage.objects.keys()].filter((k) => k.includes(row.videoAssetId))).toEqual([]);
    expect((await audits('level.raise.reject', id))[0]?.metadata).toMatchObject({
      video: { mediaId: row.videoAssetId, deletedAt: row.videoDeletedAt!.toISOString() },
    });
    const pushText = await ctx.http.get('/api/v1/notifications').set(auth(support));
    expectContract(pushText, 'listNotifications');
  });

  it('the panel: raw video upload and creation; staff see their own list, the OWNER all; the video proxy', async () => {
    const s = await signup();
    const bytes = mp4({ durationMs: 12_000, width: 720, height: 1280 });
    const up = await ctx.http
      .post('/api/v1/admin/level-raise-videos')
      .set('Cookie', support.cookie)
      .set('X-CSRF-Token', support.csrf)
      .set('Content-Type', 'application/octet-stream')
      .send(bytes);
    expect(up.status, JSON.stringify(up.body)).toBe(201);
    expectContract(up, 'uploadAdminLevelRaiseVideo');
    const bad = await ctx.http
      .post('/api/v1/admin/level-raise-videos')
      .set('Cookie', support.cookie)
      .set('X-CSRF-Token', support.csrf)
      .set('Content-Type', 'application/octet-stream')
      .send(Buffer.from('not a video at all'));
    expect(bad.status).toBe(422);
    expect(bad.body.error.code).toBe('MEDIA_INVALID');
    const created = await apost(support, '/admin/level-raises', {
      username: s.username,
      sourceApp: 'MICO',
      sourceAccountId: 'm-1',
      sourceLevel: 10,
      videoId: up.body.videoId as string,
    });
    expect(created.status, JSON.stringify(created.body)).toBe(201);
    expectContract(created, 'createAdminLevelRaise');
    expect(created.body).toMatchObject({ via: 'panel', video: { durationMs: 12_000, posterUrl: null } });
    const id = created.body.id as string;

    const own = await aget(support, '/admin/level-raises');
    expectContract(own, 'listAdminLevelRaises');
    expect(
      (own.body.data as { requestedBy: { id: string } }[]).every((r) => r.requestedBy.id === support.id),
    ).toBe(true);
    const all = await aget(owner, '/admin/level-raises?status=PENDING');
    expect((all.body.data as { id: string }[]).map((r) => r.id)).toContain(id);

    const range = await aget(owner, `/admin/level-raises/${id}/video`).set('Range', 'bytes=0-99');
    expect(range.status).toBe(206);
    expect(range.headers['content-range']).toBe(`bytes 0-99/${String(bytes.length)}`);
    expect(Buffer.compare(range.body as Buffer, bytes.subarray(0, 100))).toBe(0);
    expect((await aget(support, `/admin/level-raises/${id}/video`)).status).toBe(403);
  });

  it('the OWNER edits the source-app data and the weights (audited); the proposal follows', async () => {
    const list = await aget(owner, '/admin/level-raise/apps');
    expect(list.status).toBe(200);
    expectContract(list, 'listAdminLevelRaiseApps');
    const zafa = (list.body.data as { id: string; code: string; xpTable: unknown[] }[]).find(
      (a) => a.code === 'ZAFA',
    )!;
    expect(zafa).toMatchObject({ usdPerMillion: 20, coinsPerXp: 10, mode: 'MONEY', confidence: 'CONFIRMED' });

    // CONFIRMED needs a cited source; MONEY needs a table.
    const noSource = await apost(owner, '/admin/level-raise/apps', {
      code: 'TEST_APP',
      nameAr: 'تجربة',
      nameEn: 'Test',
      mode: 'FACTOR',
      factor: 0.4,
      confidence: 'CONFIRMED',
      reason: 'test',
    });
    expect(issueOf(noSource)).toEqual({ field: 'sourceNote', issue: 'required' });
    const noTable = await apost(owner, '/admin/level-raise/apps', {
      code: 'TEST_APP',
      nameAr: 'تجربة',
      nameEn: 'Test',
      mode: 'MONEY',
      usdPerMillion: 15,
      coinsPerXp: 1,
      confidence: 'ESTIMATE',
      reason: 'test',
    });
    expect(issueOf(noTable)).toEqual({ field: 'xpTable', issue: 'required' });
    const made = await apost(owner, '/admin/level-raise/apps', {
      code: 'TEST_APP',
      nameAr: 'تجربة',
      nameEn: 'Test',
      mode: 'MONEY',
      usdPerMillion: 15,
      coinsPerXp: 1,
      xpTable: [
        { level: 10, xp: 100_000, confidence: 'ESTIMATE' },
        { level: 20, xp: 10_000_000, confidence: 'ESTIMATE' },
      ],
      confidence: 'ESTIMATE',
      sourceNote: 'estimate for the test',
      reason: 'test',
    });
    expect(made.status, JSON.stringify(made.body)).toBe(201);
    expectContract(made, 'createAdminLevelRaiseApp');
    expect((await audits('level.raise.app.create', made.body.id as string)).length).toBe(1);
    const upd = await aput(owner, `/admin/level-raise/apps/${made.body.id as string}`, {
      nameAr: 'تجربة',
      nameEn: 'Test',
      mode: 'FACTOR',
      factor: 0.25,
      confidence: 'ESTIMATE',
      enabled: false,
      reason: 'switch to a factor',
    });
    expect(upd.status, JSON.stringify(upd.body)).toBe(200);
    expectContract(upd, 'updateAdminLevelRaiseApp');
    expect(upd.body).toMatchObject({ mode: 'FACTOR', factor: 0.25, enabled: false });
    const otherApp = (list.body.data as { id: string; isOther: boolean }[]).find((a) => a.isOther)!;
    const offOther = await aput(owner, `/admin/level-raise/apps/${otherApp.id}`, {
      nameAr: 'تطبيق آخر',
      nameEn: 'Other app',
      mode: 'FACTOR',
      factor: 0.5,
      confidence: 'ESTIMATE',
      enabled: false,
      reason: 'x',
    });
    expect(issueOf(offOther)?.issue).toBe('level_raise_other_app');

    const settings = await aget(owner, '/admin/level-raise/settings');
    expect(settings.status).toBe(200);
    expectContract(settings, 'getAdminLevelRaiseSettings');
    expect(settings.body.settings).toMatchObject({
      minRechargeCoins: 1_000_000,
      firstDays: 7,
      firstDaysBaseLevel: 20,
      totalBaseLevel: 15,
      levelsPerDoubling: 4,
      maxLevel: 40,
      kabsoUsdPerMillion: 12.5,
    });
    // A pending request's proposal follows the weights.
    const s = await signup();
    await recharge(s, 1_000_000n);
    const r = await appCreate(moderator, {
      username: s.username,
      sourceApp: 'ZAFA',
      sourceAccountId: 'z',
      sourceLevel: 32,
      videoId: await appVideo(moderator),
    });
    const id = r.body.id as string;
    expect((await aget(owner, `/admin/level-raises/${id}`)).body.proposal.proposedLevel).toBe(20);
    const put = await aput(owner, '/admin/level-raise/settings', {
      firstDaysBaseLevel: 18,
      reason: 'more careful',
    });
    expect(put.status, JSON.stringify(put.body)).toBe(200);
    expectContract(put, 'updateAdminLevelRaiseSettings');
    expect((await aget(owner, `/admin/level-raises/${id}`)).body.proposal.proposedLevel).toBe(18);
    expect((await audits('level.raise.settings.update'))[0]?.metadata).toMatchObject({
      before: { firstDaysBaseLevel: 20 },
      after: { firstDaysBaseLevel: 18 },
      reason: 'more careful',
    });
    expect((await aput(owner, '/admin/level-raise/settings', { reason: 'nothing' })).status).toBe(400);
    expect((await aput(support, '/admin/level-raise/settings', { firstDays: 3, reason: 'x' })).status).toBe(
      403,
    );
  });

  it('after a REJECTED request the same source account is allowed again, flagged with the earlier rejection', async () => {
    const rejected = await ctx.prisma.levelRaiseRequest.findFirstOrThrow({
      where: { sourceAppKey: 'APP:BIGO_LIVE', sourceAccountKey: '123', status: 'REJECTED' },
    });
    const s = await signup();
    const res = await appCreate(moderator, {
      username: s.username,
      sourceApp: 'OTHER',
      sourceAppName: 'بيغو', // an alias: the canonical app is Bigo Live
      sourceAccountId: '123',
      sourceLevel: 20,
      videoId: await appVideo(moderator),
    });
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    expectContract(res, 'createStaffLevelRaise');
    expect(res.body).toMatchObject({
      sourceApp: { code: 'BIGO_LIVE' },
      previousRejection: { id: rejected.id, rejectReason: 'الفيديو لا يظهر الايدي' },
    });
    const detail = await aget(owner, `/admin/level-raises/${res.body.id as string}`);
    expectContract(detail, 'getAdminLevelRaise');
    expect(detail.body.request.previousRejection.decidedAt).toBe(rejected.decidedAt!.toISOString());
    // The APPROVED Zafa account stays a duplicate.
    const t = await signup();
    const dup = await appCreate(support, {
      username: t.username,
      sourceApp: 'ZAFA',
      sourceAccountId: '88123456',
      sourceLevel: 30,
      videoId: await appVideo(support),
    });
    expect(dup.status).toBe(409);
    expectContract(dup, 'createStaffLevelRaise');
    expect(dup.body.error).toMatchObject({
      code: 'LEVEL_RAISE_DUPLICATE',
      details: [{ field: 'status', issue: 'APPROVED' }, {}, {}],
    });
  });

  it('two concurrent requests for one source account: the unique index lets one through', async () => {
    const [a, b] = [await signup(), await signup()];
    const [va, vb] = [await appVideo(moderator), await appVideo(support)];
    const send = (who: Admin, u: TestUser, videoId: string) =>
      appCreate(who, {
        username: u.username,
        sourceApp: 'OTHER',
        sourceAppName: 'Voice Y',
        sourceAccountId: 'V-1',
        sourceLevel: 12,
        videoId,
      });
    const results = await Promise.all([send(moderator, a, va), send(support, b, vb)]);
    expect(results.map((r) => r.status).sort()).toEqual([201, 409]);
    expect(results.find((r) => r.status === 409)!.body.error.code).toBe('LEVEL_RAISE_DUPLICATE');
    const [idx] = await ctx.prisma.$queryRaw<{ def: string }[]>`
      SELECT indexdef AS def FROM pg_indexes WHERE indexname = 'level_raise_requests_source_once'`;
    expect(idx?.def).toContain('UNIQUE');
    expect(idx?.def).toContain("'PENDING'");
    expect(idx?.def).toContain("'APPROVED'");
  });

  it('suggests the app names while typing an "other" app (Arabic / Latin, aliases, earlier names)', async () => {
    const q = (who: { token: string }, text: string) =>
      ctx.http.get('/api/v1/staff/level-raises/source-apps/suggest').query({ q: text }).set(auth(who));
    const zafa = await q(moderator, 'زفه');
    expect(zafa.status, JSON.stringify(zafa.body)).toBe(200);
    expectContract(zafa, 'suggestStaffLevelRaiseSourceApps');
    expect(zafa.body.data[0]).toMatchObject({ kind: 'APP', app: { code: 'ZAFA', confidence: 'CONFIRMED' } });
    expect((await q(moderator, 'zafa LIVE')).body.data[0]).toMatchObject({
      kind: 'APP',
      app: { code: 'ZAFA' },
    });
    expect((await q(moderator, 'بيجو')).body.data[0]).toMatchObject({
      kind: 'APP',
      app: { code: 'BIGO_LIVE' },
    });
    // The first spelling typed in an earlier request («تطبيق صوتي»), found with another spelling.
    expect((await q(support, 'تطبيق  صوتى')).body.data).toContainEqual({
      kind: 'NAME',
      app: null,
      name: 'تطبيق صوتي',
      count: 1,
    });
    expect((await q(moderator, 'voice y')).body.data[0]).toMatchObject({ kind: 'NAME', name: 'Voice Y' });
    expect((await q(moderator, 'qqqq')).body.data).toEqual([]);
    expect((await q(finance, 'زفه')).status).toBe(403);
    const panel = await aget(owner, '/admin/level-raises/source-apps/suggest?q=Zafa');
    expectContract(panel, 'suggestAdminLevelRaiseSourceApps');
    expect(panel.body.data[0].app.code).toBe('ZAFA');
    // Aliases are edited with the app (audited like the rest).
    const apps = (await aget(owner, '/admin/level-raise/apps')).body.data as {
      id: string;
      code: string;
      aliases: string[];
    }[];
    expect(apps.find((a) => a.code === 'ZAFA')!.aliases).toContain('Zafa Live');
  });
});
