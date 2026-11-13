/**
 * D387 follow-up (owner 2026-11-12, verbatim: «اي موظف لدينا لا يمكنه ارسال الهدايا — بالاضافة للموظفين الذين لديهم كرز
 * يسحب من خلالنا فقط»; contract v1.139-social, CONVENTIONS §10.176.8–9), end to end against PostgreSQL + Redis:
 *
 *  - an employee (any panel role except OWNER: VIP_CARE, COMMUNITY, FINANCE, …) sends no gift — a conversation gift, a
 *    live gift as a viewer, a bag item — 403 `STAFF_GIFT_REFUSED`, nothing charged; the OWNER (owner: «لا غير ممنوع»),
 *    also with another role, and a normal account still send; receiving is not blocked; a revoked role sends again;
 *  - a staff account's cherries are never sold to a recharge agent (403 `STAFF_WITHDRAWAL_COMPANY_ONLY`, also at the
 *    confirmation of a request made before the role); its withdrawal request to the company is marked `staffRequest`,
 *    listed and decided only by the OWNER (`withdrawals.staff`) — FINANCE neither sees nor decides it.
 */
import { randomUUID } from 'node:crypto';
import type request from 'supertest';
import { afterAll, beforeAll, describe, expect, it, vi } from 'vitest';
import { grantRoleIn, revokeRoleIn } from '../src/modules/admin-panel/admin-roles.js';
import { CAPABILITIES } from '../src/modules/admin-panel/admin-permissions.js';
import { totpCode } from '../src/modules/admin-panel/totp.js';
import { addGiftIn } from '../src/modules/gifts/gift-catalogue.js';
import { LIVE_MEDIA_PROVIDER } from '../src/modules/live/media/live-media.provider.js';
import { creditIn } from '../src/modules/wallet/wallet-ledger.js';
import { MemoryLiveMedia } from './helpers/memory-live-media.js';
import { expectContract } from './helpers/openapi.js';
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

describe('D387 staff money rules', { timeout: 900_000 }, () => {
  let ctx: TestContext;
  let clock = Date.parse('2027-03-18T09:00:00.000Z');
  const advance = (ms: number) => {
    clock += ms;
    vi.setSystemTime(clock);
  };
  const auth = (u: { token: string }) => ({ Authorization: `Bearer ${u.token}` });
  const media = new MemoryLiveMedia();

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
  const coins = (u: TestUser, amount: number) =>
    ctx.prisma.$transaction((tx) => creditIn(tx, u.id, BigInt(amount), 'ADMIN_GRANT', randomUUID()));
  const balance = async (u: TestUser) =>
    Number((await ctx.prisma.wallet.findUnique({ where: { userId: u.id } }))?.coins ?? 0n);
  const cherries = async (u: TestUser) =>
    Number((await ctx.prisma.cherryWallet.findUnique({ where: { userId: u.id } }))?.cherries ?? 0n);
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
  /** A staff account (the app account with a panel role); `panel` also signs in to the panel. */
  const makeStaff = async (role: string, panel = false): Promise<Admin> => {
    const p = await signup();
    await grant(p, role);
    if (!panel) return { ...p, secret: '', cookie: '', csrf: '' };
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
  const aget = (a: Admin, path: string) => ctx.http.get(`/api/v1/admin${path}`).set('Cookie', a.cookie);
  const apost = (a: Admin, path: string, body: object) =>
    ctx.http.post(`/api/v1/admin${path}`).set('Cookie', a.cookie).set('X-CSRF-Token', a.csrf).send(body);

  const followed = new Set<string>();
  const dmGift = async (from: TestUser, to: TestUser, giftCode = 'staff_rose') => {
    // The recipient follows the sender: a conversation, not a message request.
    if (!followed.has(`${to.id}>${from.id}`)) {
      const f = await ctx.http.put(`/api/v1/users/${from.username}/follow`).set(auth(to));
      expect(f.status).toBe(200);
      followed.add(`${to.id}>${from.id}`);
    }
    return ctx.http
      .post('/api/v1/dm/gifts')
      .set(auth(from))
      .send({ to: to.username, giftCode, quantity: 1, source: 'COINS', clientId: randomUUID() });
  };
  const startLive = async (host: TestUser) => {
    await ctx.prisma.liveHost.upsert({
      where: { userId: host.id },
      create: { userId: host.id, source: 'ADMIN' },
      update: {},
    });
    const room = await ctx.http.post('/api/v1/live/rooms').set(auth(host)).send({ title: 'D387' });
    expect(room.status, JSON.stringify(room.body)).toBe(201);
    return room.body.id as string;
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
  const liveGift = (roomId: string, from: TestUser, to: TestUser) =>
    ctx.http
      .post(`/api/v1/live/rooms/${roomId}/gifts`)
      .set(auth(from))
      .send({
        giftCode: 'staff_rose',
        quantity: 1,
        recipients: [to.username],
        source: 'COINS',
        clientId: randomUUID(),
      });
  const refusedGift = (res: request.Response) => {
    expect(res.status, JSON.stringify(res.body)).toBe(403);
    expect(res.body.error).toMatchObject({
      code: 'STAFF_GIFT_REFUSED',
      details: [{ field: 'staff', issue: 'gifts' }],
    });
  };

  let viewer: TestUser;
  let vip: Admin;

  beforeAll(async () => {
    vi.useFakeTimers({ toFake: ['Date'], now: clock });
    ctx = await createTestApp(
      {
        LIVE_HOSTING_ENABLED: 'true',
        LIVE_HEARTBEAT_STALE_SECONDS: '3600',
        ADMIN_TOTP_KEY: 'admin-totp-test-key-0123456789-abcdefghijklmnop',
        ADMIN_SESSION_IDLE_SECONDS: '86400',
        ADMIN_SESSION_MAX_SECONDS: '604800',
        RATE_LIMIT_ADMIN_LOGIN_IP: '10000/900',
        RATE_LIMIT_ADMIN_IP: '100000/900',
        JWT_ACCESS_TTL_SECONDS: String(60 * 86_400),
        // Small payout units so a test balance reaches the $10 minimum: 1 000 cherries = $1.10.
        CHERRY_PAYOUT_RATE: '1000:110',
      },
      [{ token: LIVE_MEDIA_PROVIDER, value: media }],
    );
    for (const [code, price] of [
      ['staff_rose', 100],
      ['staff_big', 1000],
    ] as const) {
      await ctx.prisma.$transaction((tx) =>
        addGiftIn(tx, code, {
          category: 'POPULAR',
          nameAr: 'هدية',
          nameEn: 'Gift',
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
    viewer = await signup();
    await coins(viewer, 1_000_000);
    vip = await makeStaff('VIP_CARE');
  });
  afterAll(async () => {
    await ctx?.close();
    vi.useRealTimers();
  });

  describe('no gift from a staff account (§10.176.8)', () => {
    it('every employee role is refused a conversation gift, with nothing charged; a normal account sends', async () => {
      const someone = await signup();
      for (const role of [
        'VIP_CARE',
        'COMMUNITY',
        'FINANCE',
        'MODERATION',
        'LIVE_OPS',
        'TALENT',
        'BD',
        'SUPPORT',
      ]) {
        const s = await makeStaff(role);
        await coins(s, 10_000);
        const res = await dmGift(s, someone);
        refusedGift(res);
        expectContract(res, 'sendDmGift');
        expect(await balance(s), role).toBe(10_000);
      }
      const ok = await dmGift(viewer, someone);
      expect(ok.status, JSON.stringify(ok.body)).toBe(201);
    });

    it('the OWNER is not blocked (owner: «لا غير ممنوع»), also while holding another role', async () => {
      const someone = await signup();
      const owner = await makeStaff('OWNER');
      await coins(owner, 10_000);
      const sent = await dmGift(owner, someone);
      expect(sent.status, JSON.stringify(sent.body)).toBe(201);
      expectContract(sent, 'sendDmGift');
      expect(await balance(owner)).toBe(9_900);
      // OWNER plus an employee role is still the owner.
      const both = await makeStaff('OWNER');
      await grant(both, 'VIP_CARE');
      await coins(both, 10_000);
      const again = await dmGift(both, someone);
      expect(again.status, JSON.stringify(again.body)).toBe(201);
    });

    it('receiving is not blocked: a staff account receives a gift and its cherries', async () => {
      const ok = await dmGift(viewer, vip, 'staff_big');
      expect(ok.status, JSON.stringify(ok.body)).toBe(201);
      expect(await cherries(vip)).toBeGreaterThan(0);
    });

    it('a live gift: a staff viewer and the OWNER as the host are refused; a viewer sends', async () => {
      const host = await signup();
      const roomId = await startLive(host);
      await coins(vip, 10_000);
      await enter(roomId, vip);
      await enter(roomId, viewer);
      refusedGift(await liveGift(roomId, vip, host));
      expect(await balance(vip)).toBe(10_000);
      const ok = await liveGift(roomId, viewer, host);
      expect([200, 201], JSON.stringify(ok.body)).toContain(ok.status);

      // The OWNER is not blocked: as the host of their own live (D128: a host may gift) the gift goes through. (As a
      // viewer the OWNER keeps D273's LIVE_STAFF_REFUSED, unchanged from staging.)
      const owner = await makeStaff('OWNER');
      await coins(owner, 10_000);
      const ownerRoom = await startLive(owner);
      const ownerGift = await liveGift(ownerRoom, owner, owner);
      expect([200, 201], JSON.stringify(ownerGift.body)).toContain(ownerGift.status);
      expect(await balance(owner)).toBe(9_900);
    });

    it('a bag item sent is a gift: refused for staff', async () => {
      const someone = await signup();
      const res = await ctx.http
        .post('/api/v1/me/bag/transfers')
        .set(auth(vip))
        .send({ code: 'frame_any', username: someone.username });
      refusedGift(res);
      expectContract(res, 'sendMyBagItem');
    });

    it('a revoked role sends again', async () => {
      const s = await makeStaff('COMMUNITY');
      await coins(s, 10_000);
      const someone = await signup();
      refusedGift(await dmGift(s, someone));
      await withMigrationClient((db) => db.$transaction((tx) => revokeRoleIn(tx, s.email, 'COMMUNITY')));
      const ok = await dmGift(s, someone);
      expect(ok.status, JSON.stringify(ok.body)).toBe(201);
    });
  });

  describe('staff cherries leave only through the company (§10.176.9)', () => {
    let agent: TestUser;
    const askHost = (host: TestUser) =>
      ctx.http
        .post('/api/v1/recharge-cherry-requests')
        .set(auth(agent))
        .set('Idempotency-Key', randomUUID())
        .send({ cherries: 1_000_000, host: host.username });

    beforeAll(async () => {
      agent = await signup();
      const app = await ctx.prisma.rechargeAgentApplication.create({
        data: {
          userId: agent.id,
          status: 'APPROVED',
          decidedAt: new Date(clock),
          fullName: 'Real Name',
          phone: '+962790000000',
          photoKey: `kyc/${agent.id}/photo.webp`,
          selfieKey: `kyc/${agent.id}/selfie.webp`,
          locations: [],
          paymentMethods: [],
        },
      });
      await ctx.prisma.rechargeAgent.create({
        data: {
          userId: agent.id,
          applicationId: app.id,
          status: 'ACTIVE',
          code: 'coin9387',
          codeNumber: 9387,
          activatedAt: new Date(clock),
          countries: [],
          locations: [],
          paymentTypes: [],
        },
      });
    });

    it('a recharge agent cannot buy a staff member’s cherries; a normal host is not refused by the rule', async () => {
      const refused = await askHost(vip);
      expect(refused.status, JSON.stringify(refused.body)).toBe(403);
      expect(refused.body.error).toMatchObject({
        code: 'STAFF_WITHDRAWAL_COMPANY_ONLY',
        details: [{ field: 'staff', issue: 'company_only' }],
      });
      expectContract(refused, 'createRechargeCherryRequest');
      const normal = await askHost(await signup());
      expect(normal.body?.error?.code).not.toBe('STAFF_WITHDRAWAL_COMPANY_ONLY');
    });

    it('a request made before the role is refused at its confirmation', async () => {
      const host = await signup();
      await dmGift(viewer, host, 'staff_big');
      // An open request the agent made while the host was not staff (written directly: the amounts do not matter).
      const row = await ctx.prisma.rechargeCherryRequest.create({
        data: {
          agentUserId: agent.id,
          hostUserId: host.id,
          createdBy: agent.id,
          clientId: randomUUID(),
          cherries: 1_000_000n,
          coins: 94_500n,
          payoutMinor: 110n,
          currency: 'USD',
          expiresAt: new Date(clock + 30 * 60_000),
          createdAt: new Date(clock),
        },
      });
      await grant(host, 'SUPPORT');
      const confirm = await ctx.http
        .post(`/api/v1/recharge-cherry-requests/${row.id}/confirm`)
        .set(auth(host))
        .send({});
      expect(confirm.status, JSON.stringify(confirm.body)).toBe(403);
      expect(confirm.body.error.code).toBe('STAFF_WITHDRAWAL_COMPANY_ONLY');
      expect(
        (await ctx.prisma.rechargeCherryRequest.findUniqueOrThrow({ where: { id: row.id } })).status,
      ).toBe('PENDING');
    });

    it('the company route: a staff request is the OWNER’s alone; FINANCE neither sees nor decides it', async () => {
      expect(CAPABILITIES['withdrawals.staff']).toEqual(['OWNER']);
      // VIP care received 10 000 cherries above (≈ $11 at the test rate); ask for $10.
      await dmGift(viewer, vip, 'staff_big');
      const req = await ctx.http
        .post('/api/v1/wallet/me/cherries/withdrawals')
        .set(auth(vip))
        .set('Idempotency-Key', randomUUID())
        .send({ amountMinor: 1000, payoutDetails: 'Bank: IBAN SA00 0000' });
      expect(req.status, JSON.stringify(req.body)).toBe(201);
      expectContract(req, 'requestCherryWithdrawal');
      const stored = await ctx.prisma.cherryWithdrawal.findUniqueOrThrow({ where: { id: req.body.id } });
      expect(stored.staffRequest).toBe(true);

      // A normal person's request, for comparison.
      const plain = await signup();
      await dmGift(viewer, plain, 'staff_big');
      await dmGift(viewer, plain, 'staff_big');
      const plainReq = await ctx.http
        .post('/api/v1/wallet/me/cherries/withdrawals')
        .set(auth(plain))
        .set('Idempotency-Key', randomUUID())
        .send({ amountMinor: 1000, payoutDetails: 'Bank: IBAN SA11 1111' });
      expect(plainReq.status, JSON.stringify(plainReq.body)).toBe(201);

      const owner = await makeStaff('OWNER', true);
      const finance = await makeStaff('FINANCE', true);
      const finList = await aget(finance, '/withdrawals?status=PENDING');
      expect(finList.status).toBe(200);
      expectContract(finList, 'listAdminWithdrawals');
      const finIds = (finList.body.data as { id: string }[]).map((w) => w.id);
      expect(finIds).toContain(plainReq.body.id);
      expect(finIds).not.toContain(req.body.id);
      const ownerList = await aget(owner, '/withdrawals?status=PENDING');
      const mine = (ownerList.body.data as { id: string; staffRequest: boolean }[]).find(
        (w) => w.id === req.body.id,
      );
      expect(mine?.staffRequest).toBe(true);
      expect(
        (ownerList.body.data as { id: string; staffRequest: boolean }[]).find(
          (w) => w.id === plainReq.body.id,
        )?.staffRequest,
      ).toBe(false);

      const finPay = await apost(finance, `/withdrawals/${req.body.id}/pay`, {
        reference: 'TX-1',
        totpCode: '000000',
      });
      expect(finPay.status).toBe(403);
      expect(finPay.body.error.code).toBe('AUTH_FORBIDDEN');
      const finReject = await apost(finance, `/withdrawals/${req.body.id}/reject`, {
        reason: 'no',
        totpCode: '000000',
      });
      expect(finReject.status).toBe(403);
      const before = await cherries(vip);
      const ownerReject = await apost(owner, `/withdrawals/${req.body.id}/reject`, {
        reason: 'Pay in the next cycle',
        totpCode: nextCode(owner.secret),
      });
      expect(ownerReject.status, JSON.stringify(ownerReject.body)).toBe(200);
      expect(await cherries(vip)).toBeGreaterThan(before);
      // FINANCE still handles a normal person's request.
      const finPlain = await apost(finance, `/withdrawals/${plainReq.body.id}/pay`, {
        reference: 'TX-2',
        totpCode: nextCode(finance.secret),
      });
      expect(finPlain.status, JSON.stringify(finPlain.body)).toBe(200);
    });
  });
});
