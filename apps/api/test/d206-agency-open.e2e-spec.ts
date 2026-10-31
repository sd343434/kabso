/**
 * D206 (owner 2026-10-31; contract v1.70-social, CONVENTIONS §10.65): «افتح وكالة» — a person in no agency opens a
 * host agency themselves, free, with an ID card and a selfie (the D185 private uploads); the agency exists at once
 * (the D179 shape: invite code, `hostNN`, NEW) with a 7-day probation; it passes once 3 hosts are activated (joined,
 * went live, received gifts) or closes itself at the end (hosts released, everyone notified). The deterministic
 * rule — the state at `probationEndsAt` — is tested at its boundaries. Also the panel (application view, extend /
 * close / reopen with TOTP) and the `economy-admin` commands. End to end against PostgreSQL + Redis.
 */
import { execFile } from 'node:child_process';
import { randomUUID } from 'node:crypto';
import { promisify } from 'node:util';
import sharp from 'sharp';
import type request from 'supertest';
import { afterAll, beforeAll, describe, expect, it, vi } from 'vitest';
import { grantRoleIn } from '../src/modules/admin-panel/admin-roles.js';
import { totpCode } from '../src/modules/admin-panel/totp.js';
import { AgencyService } from '../src/modules/economy/agency.service.js';
import { OBJECT_STORAGE } from '../src/modules/media/object-storage.js';
import { notificationBody } from '../src/modules/push/push-texts.js';
import { MemoryObjectStorage } from './helpers/memory-storage.js';
import { expectContract, openapi, operations } from './helpers/openapi.js';
import {
  createTestApp,
  registerVerified,
  withMigrationClient,
  type TestContext,
} from './helpers/test-app.js';

const run = promisify(execFile);
const DAY = 86_400_000;
const HOUR = 3_600_000;
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

describe('D206 contract coverage', () => {
  it('openapi v1.70-social declares «افتح وكالة», the probation and the panel actions', () => {
    const ids = operations().map((o) => `${o.operationId} ${o.method.toUpperCase()} ${o.path}`);
    expect(ids).toEqual(
      expect.arrayContaining([
        'openAgency POST /api/v1/me/agency/open',
        'getAdminAgencyApplication GET /api/v1/admin/agencies/{agencyId}/applications/{applicationId}',
        'getAdminAgencyApplicationPhoto GET /api/v1/admin/agencies/{agencyId}/applications/{applicationId}/photos/{which}',
        'extendAdminAgencyProbation POST /api/v1/admin/agencies/{agencyId}/probation/extend',
        'closeAdminAgency POST /api/v1/admin/agencies/{agencyId}/close',
        'reopenAdminAgency POST /api/v1/admin/agencies/{agencyId}/reopen',
      ]),
    );
    const schemas = (openapi.components as { schemas: Record<string, Record<string, unknown>> }).schemas;
    expect(schemas.MyAgency!.required).toEqual(expect.arrayContaining(['closedAgency', 'openRule']));
    expect(schemas.OwnAgency!.required).toEqual(expect.arrayContaining(['name', 'probation']));
    expect((schemas.NotificationType as { enum: string[] }).enum).toEqual(
      expect.arrayContaining([
        'AGENCY_OPENED',
        'AGENCY_PROBATION_REMINDER',
        'AGENCY_PROBATION_PASSED',
        'AGENCY_CLOSED',
        'AGENCY_HOST_RELEASED',
      ]),
    );
    for (const o of operations().filter((x) =>
      (typeof x.spec.description === 'string' ? x.spec.description : '').startsWith('(v1.70-social, D206)'),
    )) {
      expect(o.spec.security).toEqual([{ adminSession: [] }]);
      if (o.method !== 'get') expect(JSON.stringify(o.spec.parameters)).toContain('AdminCsrf');
    }
  });

  it('the push texts carry the owner sentence and the count', () => {
    const closed = notificationBody(
      {
        type: 'AGENCY_CLOSED',
        actorName: null,
        actorCount: 0,
        targetType: 'AGENCY',
        targetId: 'x',
        targetText: 'وكالة',
        activatedHosts: 2,
        requiredHosts: 3,
        probationDays: 7,
      },
      'ar',
    );
    expect(closed).toBe(
      'أُغلقت وكالتك لأنها لم تفعّل 3 مضيفين (بثّ واستلام هدايا) خلال 7 أيام — المفعّلون: 2',
    );
    for (const type of [
      'AGENCY_OPENED',
      'AGENCY_PROBATION_REMINDER',
      'AGENCY_PROBATION_PASSED',
      'AGENCY_HOST_RELEASED',
    ]) {
      const base = {
        type,
        actorName: null,
        actorCount: 0,
        targetType: 'AGENCY',
        targetId: 'x',
        targetText: null,
      };
      expect(notificationBody(base, 'ar')).toBeTruthy();
      expect(notificationBody(base, 'en')).toBeTruthy();
    }
  });
});

describe('D206 «افتح وكالة»', { timeout: 600_000 }, () => {
  const storage = new MemoryObjectStorage();
  let ctx: TestContext;
  let png: Buffer;
  let clock = Date.now();
  const setNow = (ms: number) => {
    clock = ms;
    vi.setSystemTime(clock);
  };
  const advance = (ms: number) => setNow(clock + ms);

  const auth = (u: TestUser) => ({ Authorization: `Bearer ${u.token}` });
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
  const upload = async (u: TestUser, kind: string): Promise<string> => {
    const slot = await ctx.http
      .post('/api/v1/media/uploads')
      .set(auth(u))
      .send({ kind, contentType: 'image/png', byteSize: png.length });
    expect(slot.status, JSON.stringify(slot.body)).toBe(201);
    expect(storage.upload(slot.body.uploadUrl as string, png, 'image/png')).toBe(true);
    return slot.body.uploadId as string;
  };
  const form = async (u: TestUser, extra: Record<string, unknown> = {}) => ({
    name: 'وكالة النجوم',
    country: 'sa',
    contact: { type: 'WHATSAPP', value: '+966500000000' },
    expectedHosts: 25,
    bio: 'نبحث عن مضيفين موهوبين',
    photoUploadId: await upload(u, 'RECHARGE_AGENT_PHOTO'),
    selfieUploadId: await upload(u, 'RECHARGE_AGENT_SELFIE'),
    ...extra,
  });
  const open = (u: TestUser, body: object, key: string | null = randomUUID()) => {
    const r = ctx.http.post('/api/v1/me/agency/open').set(auth(u));
    return (key === null ? r : r.set('Idempotency-Key', key)).send(body);
  };
  const mine = async (u: TestUser) => {
    const res = await ctx.http.get('/api/v1/me/agency').set(auth(u));
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    expectContract(res, 'getMyAgency');
    return res.body as {
      ownAgency: {
        inviteCode: string;
        name: string | null;
        rank: string;
        hostAgent: { code: string | null; active: boolean };
        probation: {
          status: string;
          endsAt: string;
          activatedHosts: number;
          requiredHosts: number;
          days: number;
          hosts: { user: { id: string }; wentLive: boolean; receivedGifts: boolean; activated: boolean }[];
        } | null;
      } | null;
      membership: { agency: { inviteCode: string } } | null;
      closedAgency: {
        reason: string;
        activatedHosts: number | null;
        requiredHosts: number | null;
        closedAt: string;
        reopenAt: string;
        inviteCode: string;
      } | null;
      openRule: {
        canOpen: boolean;
        refusal: string | null;
        free: boolean;
        probationDays: number;
        requiredHosts: number;
      };
    };
  };
  const join = async (u: TestUser, code: string) => {
    const res = await ctx.http.post('/api/v1/me/agency/join').set(auth(u)).send({ inviteCode: code });
    expect(res.status, JSON.stringify(res.body)).toBe(201);
  };
  const live = (u: TestUser, at: number) =>
    ctx.prisma.liveRoom.create({
      data: {
        hostUserId: u.id,
        title: 'live',
        status: 'ENDED',
        endReason: 'HOST_ENDED',
        startedAt: new Date(at),
        lastHeartbeatAt: new Date(at + 60_000),
        endedAt: new Date(at + 60_000),
      },
    });
  const gift = (u: TestUser, at: number, ref = randomUUID()) =>
    ctx.prisma.cherryLedgerEntry.create({
      data: {
        userId: u.id,
        delta: 100n,
        balanceAfter: 100n,
        reason: 'GIFT_RECEIVED',
        referenceId: ref,
        createdAt: new Date(at),
      },
    });
  const notifications = async (u: TestUser) => {
    const res = await ctx.http.get('/api/v1/notifications').set(auth(u));
    expect(res.status).toBe(200);
    expectContract(res, 'listNotifications');
    return res.body.data as {
      type: string;
      target: {
        type: string;
        id: string;
        text: string | null;
        activatedHosts?: number;
        requiredHosts?: number;
      };
    }[];
  };
  const service = () => ctx.app.get(AgencyService);
  const agencyOf = (u: TestUser) => ctx.prisma.agency.findUniqueOrThrow({ where: { ownerUserId: u.id } });
  /** An owner with an open agency, `opened` ms ago from now. */
  const openFor = async (u: TestUser) => {
    const res = await open(u, await form(u));
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    return res.body as Awaited<ReturnType<typeof mine>>;
  };

  beforeAll(async () => {
    png = await sharp({
      create: { width: 64, height: 64, channels: 3, background: { r: 200, g: 40, b: 40 } },
    })
      .png()
      .toBuffer();
    vi.useFakeTimers({ toFake: ['Date'], now: clock });
    ctx = await createTestApp(
      {
        MEDIA_UPLOADS_ENABLED: 'true',
        S3_BUCKET: 'kabso-media-test',
        S3_ACCESS_KEY_ID: 'test',
        S3_SECRET_ACCESS_KEY: 'test',
        MEDIA_PUBLIC_BASE_URL: 'https://media.example.test',
        LIVE_RANKINGS_TIME_ZONE: 'UTC',
        RECHARGE_AGENT_SWEEP_INTERVAL_SECONDS: '0',
        SPECIAL_USERNAME_SWEEP_INTERVAL_SECONDS: '0',
        RATE_LIMIT_AGENCY_OPEN_USER: '1000/900',
        // The probation's days pass on the fake clock: the people's tokens must outlive them.
        JWT_ACCESS_TTL_SECONDS: String(400 * 86_400),
        REFRESH_TTL_SECONDS: String(400 * 86_400),
        REFRESH_ABSOLUTE_TTL_SECONDS: String(400 * 86_400),
        ADMIN_TOTP_KEY: 'admin-totp-test-key-0123456789-abcdefghijklmnop',
        ADMIN_SESSION_IDLE_SECONDS: '3600',
        ADMIN_SESSION_MAX_SECONDS: '28800',
        RATE_LIMIT_ADMIN_LOGIN_IP: '10000/900',
        RATE_LIMIT_ADMIN_IP: '100000/900',
      },
      [{ token: OBJECT_STORAGE, value: storage }],
    );
  });
  afterAll(async () => {
    await ctx?.close();
    vi.useRealTimers();
  });

  it('opens at once for free: the D179 agency (invite code, hostNN, NEW) with a 7-day probation, notified, audited', async () => {
    const u = await signup();
    const before = await mine(u);
    expect(before.ownAgency).toBeNull();
    expect(before.closedAgency).toBeNull();
    expect(before.openRule).toEqual({
      canOpen: true,
      refusal: null,
      free: true,
      probationDays: 7,
      requiredHosts: 3,
      reopenCooldownDays: 30,
    });

    // 400s: the header, then the body.
    const body = await form(u);
    const noKey = await open(u, body, null);
    expect(noKey.status).toBe(400);
    expect(noKey.body.error.details).toEqual([{ field: 'Idempotency-Key', issue: 'required' }]);
    expectContract(noKey, 'openAgency');
    for (const bad of [
      { ...body, name: 'x' },
      { ...body, country: 'SAU' },
      { ...body, expectedHosts: 0 },
      { ...body, expectedHosts: 10_001 },
      { ...body, bio: 'x'.repeat(301) },
      { ...body, contact: { type: 'FAX', value: '123456' } },
      { ...body, name: 'bad\u0007name' },
      { ...body, extra: true },
    ]) {
      const res = await open(u, bad);
      expect(res.status, JSON.stringify(bad)).toBe(400);
    }
    // Someone else's upload is refused (and nothing is created).
    const thief = await signup();
    const stolen = await open(thief, { ...(await form(thief)), photoUploadId: body.photoUploadId });
    expect(stolen.status).toBe(400);
    expect(stolen.body.error.details).toEqual([{ field: 'photoUploadId', issue: 'invalid_value' }]);
    expect(await ctx.prisma.agency.count({ where: { ownerUserId: thief.id } })).toBe(0);

    const key = randomUUID();
    const t0 = clock;
    const res = await open(u, body, key);
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    expectContract(res, 'openAgency');
    const own = res.body.ownAgency;
    expect(own).toMatchObject({ name: 'وكالة النجوم', rank: 'NEW', hostAgent: { active: true } });
    expect(own.inviteCode).toMatch(/^[A-HJ-NP-Z2-9]{8}$/);
    expect(own.hostAgent.code).toMatch(/^host[0-9]{2,}$/);
    expect(own.probation).toMatchObject({
      status: 'RUNNING',
      requiredHosts: 3,
      activatedHosts: 0,
      days: 7,
      hosts: [],
    });
    expect(Date.parse(own.probation.endsAt)).toBe(t0 + 7 * DAY);
    expect(res.body.openRule).toMatchObject({ canOpen: false, refusal: 'OWNS_AGENCY' });
    const row = await agencyOf(u);
    expect(row).toMatchObject({ origin: 'SELF', status: 'OPEN', name: 'وكالة النجوم', parentAgencyId: null });
    // Identical to a team agency: the grace (evaluated from the month start two months later) and the code.
    const d = new Date(t0);
    expect(row.evaluateFrom.toISOString().slice(0, 10)).toBe(
      new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth() + 2, 1)).toISOString().slice(0, 10),
    );
    const profile = await ctx.prisma.userProfile.findUniqueOrThrow({ where: { userId: u.id } });
    expect(profile.username).toBe(own.hostAgent.code);

    // The application: private keys, never the raw uploads, stored with the agency.
    const app = await ctx.prisma.agencyApplication.findFirstOrThrow({ where: { userId: u.id } });
    expect(app).toMatchObject({
      agencyId: row.id,
      country: 'SA',
      contactType: 'WHATSAPP',
      contactValue: '+966500000000',
      expectedHosts: 25,
    });
    expect(app.photoKey).toBe(`private/agency-applications/${app.id}/photo.webp`);
    expect(app.selfieKey).toBe(`private/agency-applications/${app.id}/selfie.webp`);
    expect(await storage.head(app.photoKey!)).not.toBeNull();
    expect(await storage.head(app.selfieKey!)).not.toBeNull();
    expect(JSON.stringify(res.body)).not.toContain('private/');
    // The audit row has no private field.
    const audit = await ctx.prisma.auditLog.findFirstOrThrow({
      where: { action: 'agency.open', targetId: row.id },
    });
    expect(JSON.stringify(audit.metadata)).not.toContain('+966500000000');
    expect(JSON.stringify(audit.metadata)).not.toContain('نبحث');
    // Notified.
    const n = await notifications(u);
    expect(n.find((x) => x.type === 'AGENCY_OPENED')?.target).toMatchObject({
      type: 'AGENCY',
      id: row.id,
      text: 'وكالة النجوم',
    });

    // The same key again: 200 (nothing new); another body: 409; a new key: refused (an open agency).
    const again = await open(u, body, key);
    expect(again.status).toBe(200);
    expectContract(again, 'openAgency');
    expect(await ctx.prisma.agencyApplication.count({ where: { userId: u.id } })).toBe(1);
    const conflict = await open(u, { ...body, name: 'وكالة أخرى' }, key);
    expect(conflict.status).toBe(409);
    expect(conflict.body.error.code).toBe('IDEMPOTENCY_CONFLICT');
    const second = await open(u, await form(u));
    expect(second.status).toBe(409);
    expectContract(second, 'openAgency');
    expect(second.body.error).toMatchObject({
      code: 'AGENCY_OPEN_NOT_ALLOWED',
      details: [{ field: 'agency', issue: 'OWNS_AGENCY' }],
    });

    // A host of an agency may not open one; the invite code shows the agency (it is a normal agency).
    const host = await signup();
    await join(host, own.inviteCode);
    expect((await mine(host)).openRule).toMatchObject({ canOpen: false, refusal: 'HOST_OF_AGENCY' });
    const refused = await open(host, await form(host));
    expect(refused.status).toBe(409);
    expect(refused.body.error.details).toEqual([{ field: 'agency', issue: 'HOST_OF_AGENCY' }]);
    // The owner cannot join another agency as a host (D179 rule unchanged).
    const preview = await ctx.http.get(`/api/v1/agencies/${own.inviteCode}`).set(auth(thief));
    expect(preview.status).toBe(200);
  });

  it('counts a host only when joined, live and gifted after joining; passes as soon as 3 are, on a read', async () => {
    const owner = await signup();
    const opened = await openFor(owner);
    const code = opened.ownAgency!.inviteCode;
    const [h1, h2, h3] = [await signup(), await signup(), await signup()];
    // A live and a gift BEFORE joining do not count.
    await live(h1, clock - HOUR);
    await gift(h1, clock - HOUR);
    advance(1000);
    for (const h of [h1, h2, h3]) await join(h, code);
    advance(1000);
    await live(h1, clock);
    await gift(h1, clock);
    await live(h2, clock); // live, no gift
    await gift(h3, clock); // gift, no live
    // A reversed gift does not count.
    const ref = randomUUID();
    await live(h3, clock - 10);
    await ctx.prisma.cherryLedgerEntry.deleteMany({ where: { userId: h3.id } });
    await gift(h3, clock, ref);
    await ctx.prisma.cherryLedgerEntry.create({
      data: { userId: h3.id, delta: -100n, balanceAfter: 0n, reason: 'GIFT_REVERSAL', referenceId: ref },
    });
    advance(1000);
    let m = await mine(owner);
    const p = m.ownAgency!.probation!;
    expect(p.status).toBe('RUNNING');
    expect(p.activatedHosts).toBe(1);
    const byId = new Map(p.hosts.map((h) => [h.user.id, h]));
    expect(byId.get(h1.id)).toMatchObject({ wentLive: true, receivedGifts: true, activated: true });
    expect(byId.get(h2.id)).toMatchObject({ wentLive: true, receivedGifts: false, activated: false });
    expect(byId.get(h3.id)).toMatchObject({ wentLive: true, receivedGifts: false, activated: false });
    // The rank evaluation leaves a running probation alone (NEW).
    await service().evaluateRanks();
    expect((await agencyOf(owner)).rank).toBe('NEW');

    await gift(h2, clock);
    await gift(h3, clock);
    advance(1000);
    m = await mine(owner);
    expect(m.ownAgency!.probation).toMatchObject({ status: 'PASSED', activatedHosts: 3, hosts: [] });
    const row = await agencyOf(owner);
    expect(row.probationPassedAt).not.toBeNull();
    expect(row.status).toBe('OPEN');
    expect((await notifications(owner)).some((x) => x.type === 'AGENCY_PROBATION_PASSED')).toBe(true);
    // Passing is once: a sweep later changes nothing.
    advance(8 * DAY);
    const swept = await service().sweepProbations();
    expect(swept.passed).not.toContain(row.id);
    expect(swept.closed).not.toContain(row.id);
    expect((await agencyOf(owner)).status).toBe('OPEN');
    expect(
      await ctx.prisma.auditLog.count({ where: { action: 'agency.probation.pass', targetId: row.id } }),
    ).toBe(1);
  });

  it('decides by the state at probationEndsAt: a late sweep closes it, releases the hosts and tells everyone why', async () => {
    const owner = await signup();
    const opened = await openFor(owner);
    const code = opened.ownAgency!.inviteCode;
    const row0 = await agencyOf(owner);
    const T = row0.probationEndsAt!.getTime();
    const [h1, h2, h3, h4, h5] = [
      await signup(),
      await signup(),
      await signup(),
      await signup(),
      await signup(),
    ];
    for (const h of [h1, h2, h3]) await join(h, code);
    advance(1000);
    await live(h1, clock);
    await gift(h1, clock); // h1: counts
    await live(h2, clock);
    await live(h3, clock);
    await gift(h3, clock);
    // Commission earned during the probation stays with the owner.
    await ctx.prisma.agencyMonth.create({
      data: {
        agencyId: row0.id,
        month: new Date(Date.UTC(2020, 0, 1)),
        hostCherries: 1000n,
        commission: 150n,
      },
    });

    // The 24 h reminder: once.
    setNow(T - 23 * HOUR);
    let s = await service().sweepProbations();
    expect(s.reminded).toContain(row0.id);
    s = await service().sweepProbations();
    expect(s.reminded).not.toContain(row0.id);
    const reminder = (await notifications(owner)).filter((x) => x.type === 'AGENCY_PROBATION_REMINDER');
    expect(reminder).toHaveLength(1);
    expect(reminder[0]!.target).toMatchObject({ type: 'AGENCY', activatedHosts: 2, requiredHosts: 3 });

    // h3 leaves before the end (a member at T no more): their activity no longer counts.
    await ctx.http.post('/api/v1/me/agency/leave').set(auth(h3));
    // h4 joins one second before the end and does everything in time: counts.
    setNow(T - 1000);
    await join(h4, code);
    await live(h4, T - 500);
    await gift(h4, T - 1);
    // h2's gift at exactly T: does not count. h5 joins at T: does not count.
    setNow(T);
    await gift(h2, T);
    await join(h5, code);
    await live(h5, T);
    await gift(h5, T);
    // The sweep runs two days late; meanwhile everyone did more — none of it counts.
    setNow(T + 2 * DAY);
    await gift(h2, clock);
    await live(h5, clock);
    await gift(h5, clock);
    s = await service().sweepProbations();
    expect(s.closed).toContain(row0.id);

    const row = await agencyOf(owner);
    expect(row).toMatchObject({ status: 'CLOSED', closeReason: 'PROBATION_FAILED', probationActivated: 2 });
    expect(row.closedAt!.getTime()).toBe(T + 2 * DAY);
    const links = await ctx.prisma.agencyHost.findMany({ where: { agencyId: row0.id } });
    expect(links.filter((l) => l.status === 'ACTIVE')).toHaveLength(0);
    expect(
      links
        .filter((l) => l.status === 'RELEASED')
        .map((l) => l.hostUserId)
        .sort(),
    ).toEqual([h1.id, h2.id, h4.id, h5.id].sort());
    for (const h of [h1, h2, h4, h5]) {
      expect((await notifications(h)).some((x) => x.type === 'AGENCY_HOST_RELEASED')).toBe(true);
      expect((await mine(h)).membership).toBeNull();
    }
    const closed = (await notifications(owner)).find((x) => x.type === 'AGENCY_CLOSED');
    expect(closed?.target).toMatchObject({
      type: 'AGENCY',
      id: row0.id,
      activatedHosts: 2,
      requiredHosts: 3,
    });
    // The owner's page: closed, with the reason, the count and when they may open again.
    const m = await mine(owner);
    expect(m.ownAgency).toBeNull();
    expect(m.closedAgency).toMatchObject({
      reason: 'PROBATION_FAILED',
      activatedHosts: 2,
      requiredHosts: 3,
      inviteCode: code,
    });
    expect(Date.parse(m.closedAgency!.reopenAt)).toBe(T + 2 * DAY + 30 * DAY);
    expect(m.openRule).toMatchObject({ canOpen: false, refusal: 'REOPEN_COOLDOWN' });
    // Commission stays; the perks go (the username is no longer hostNN); the code cannot be found or joined.
    expect((await ctx.prisma.agencyMonth.findFirstOrThrow({ where: { agencyId: row0.id } })).commission).toBe(
      150n,
    );
    const profile = await ctx.prisma.userProfile.findUniqueOrThrow({ where: { userId: owner.id } });
    expect(profile.username).not.toBe(row.hostCode);
    expect((await ctx.http.get(`/api/v1/agencies/${code}`).set(auth(h1))).status).toBe(404);
    const rejoin = await ctx.http.post('/api/v1/me/agency/join').set(auth(h1)).send({ inviteCode: code });
    expect(rejoin.status).toBe(404);
    expect((await ctx.http.get('/api/v1/me/agency/hosts').set(auth(owner))).status).toBe(404);
    // A closed agency is never evaluated.
    await service().evaluateRanks();
    expect((await agencyOf(owner)).rankMonth).toBeNull();
    // Idempotent: another sweep and a read change nothing.
    s = await service().sweepProbations();
    expect(s.closed).not.toContain(row0.id);
    await mine(owner);
    expect(await ctx.prisma.auditLog.count({ where: { action: 'agency.close', targetId: row0.id } })).toBe(1);
    expect(
      await ctx.prisma.notification.count({ where: { recipientId: owner.id, type: 'AGENCY_CLOSED' } }),
    ).toBe(1);
    // The owner of a closed agency may be a host elsewhere (D179's owner rule counts open agencies only).
    const other = await signup();
    const otherAgency = await openFor(other);
    await join(owner, otherAgency.ownAgency!.inviteCode);
    await ctx.http.post('/api/v1/me/agency/leave').set(auth(owner));

    // After the cooldown: open again — the same row, invite code and host code, a new probation.
    setNow(T + 2 * DAY + 30 * DAY);
    expect((await mine(owner)).openRule).toMatchObject({ canOpen: true, refusal: null });
    const again = await open(owner, await form(owner, { name: 'وكالة جديدة' }));
    expect(again.status, JSON.stringify(again.body)).toBe(201);
    expect(again.body.ownAgency).toMatchObject({
      inviteCode: code,
      name: 'وكالة جديدة',
      rank: 'NEW',
      hostAgent: { code: row.hostCode, active: true },
      probation: { status: 'RUNNING', activatedHosts: 0 },
    });
    expect(again.body.closedAgency).toBeNull();
    expect(Date.parse(again.body.ownAgency.probation.endsAt)).toBe(clock + 7 * DAY);
    expect(await ctx.prisma.agency.count({ where: { ownerUserId: owner.id } })).toBe(1);
    expect(await ctx.prisma.agencyApplication.count({ where: { userId: owner.id } })).toBe(2);
    expect((await ctx.prisma.userProfile.findUniqueOrThrow({ where: { userId: owner.id } })).username).toBe(
      row.hostCode,
    );
  });

  it('exactly 3 by the end passes even when the sweep runs late', async () => {
    const owner = await signup();
    const opened = await openFor(owner);
    const T = Date.parse(opened.ownAgency!.probation!.endsAt);
    const hosts = [await signup(), await signup(), await signup()];
    for (const h of hosts) await join(h, opened.ownAgency!.inviteCode);
    for (const h of hosts) {
      await live(h, T - 2);
      await gift(h, T - 1);
    }
    setNow(T + 5 * HOUR);
    const s = await service().sweepProbations();
    const row = await agencyOf(owner);
    expect(s.passed).toContain(row.id);
    expect(row).toMatchObject({ status: 'OPEN', probationActivated: 3 });
  });

  describe('the panel and the CLI', () => {
    let clockAdmin: Admin;
    let support: Admin;
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
      await withMigrationClient(async (db) => {
        for (const role of roles) await db.$transaction((tx) => grantRoleIn(tx, p.email, role as never));
      });
      const res = await ctx.http
        .post('/api/v1/admin/auth/login')
        .send({ email: p.email, password: p.password });
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
    const get = (a: Admin, path: string) => ctx.http.get(`/api/v1${path}`).set('Cookie', a.cookie);
    const post = (a: Admin, path: string, body: object = {}) =>
      ctx.http.post(`/api/v1${path}`).set('Cookie', a.cookie).set('X-CSRF-Token', a.csrf).send(body);

    beforeAll(async () => {
      setNow(Date.now());
      clockAdmin = await makeAdmin(['OWNER']);
      support = await makeAdmin(['SUPPORT']);
    });

    it('shows the self-opened agency with its application (audited) and extends, closes, reopens with TOTP', async () => {
      const owner = await signup();
      const opened = await openFor(owner);
      const row = await agencyOf(owner);
      const host = await signup();
      await join(host, opened.ownAgency!.inviteCode);
      advance(1000);

      const list = await get(clockAdmin, '/admin/agencies?state=probation&origin=SELF');
      expect(list.status, JSON.stringify(list.body)).toBe(200);
      expectContract(list, 'listAdminAgencies');
      expect(list.body.data.find((r: { id: string }) => r.id === row.id)).toMatchObject({
        origin: 'SELF',
        status: 'OPEN',
        probation: 'RUNNING',
        name: 'وكالة النجوم',
      });
      const detail = await get(clockAdmin, `/admin/agencies/${row.id}`);
      expect(detail.status).toBe(200);
      expectContract(detail, 'getAdminAgency');
      expect(detail.body.probation).toMatchObject({ state: 'RUNNING', requiredHosts: 3, activatedHosts: 0 });
      expect(detail.body.probation.hosts).toHaveLength(1);
      const appId = detail.body.applications[0].id as string;
      // The detail itself carries no private field.
      expect(JSON.stringify(detail.body)).not.toContain('+966500000000');

      const app = await get(support, `/admin/agencies/${row.id}/applications/${appId}`);
      expect(app.status).toBe(200);
      expectContract(app, 'getAdminAgencyApplication');
      expect(app.body).toMatchObject({
        name: 'وكالة النجوم',
        country: 'SA',
        contact: { type: 'WHATSAPP', value: '+966500000000' },
        expectedHosts: 25,
        photos: { photo: true, selfie: true },
      });
      const photo = await get(support, `/admin/agencies/${row.id}/applications/${appId}/photos/selfie`);
      expect(photo.status).toBe(200);
      expect(photo.headers['cache-control']).toBe('private, no-store');
      expect(photo.headers['content-type']).toBe('image/webp');
      expect(
        await ctx.prisma.auditLog.count({ where: { action: 'agency.application.view', targetId: appId } }),
      ).toBe(1);
      expect(
        await ctx.prisma.auditLog.count({
          where: { action: 'agency.application.photo.view', targetId: appId },
        }),
      ).toBe(1);
      expect(
        (await get(support, `/admin/agencies/${row.id}/applications/${appId}/photos/other`)).status,
      ).toBe(404);

      // SUPPORT may not act on the probation (OWNER only).
      const denied = await post(support, `/admin/agencies/${row.id}/probation/extend`, {
        days: 3,
        reason: 'r',
        totpCode: nextCode(support.secret),
      });
      expect(denied.status).toBe(403);
      // A wrong code is refused; the right one extends from the end.
      const wrong = await post(clockAdmin, `/admin/agencies/${row.id}/probation/extend`, {
        days: 3,
        reason: 'needs time',
        totpCode: '000000',
      });
      expect(wrong.status).toBe(403);
      expect(wrong.body.error.code).toBe('ADMIN_TOTP_INVALID');
      const ext = await post(clockAdmin, `/admin/agencies/${row.id}/probation/extend`, {
        days: 3,
        reason: 'needs time',
        totpCode: nextCode(clockAdmin.secret),
      });
      expect(ext.status, JSON.stringify(ext.body)).toBe(200);
      expectContract(ext, 'extendAdminAgencyProbation');
      expect(Date.parse(ext.body.endsAt)).toBe(row.probationEndsAt!.getTime() + 3 * DAY);

      const close = await post(clockAdmin, `/admin/agencies/${row.id}/close`, {
        reason: 'fake documents',
        totpCode: nextCode(clockAdmin.secret),
      });
      expect(close.status, JSON.stringify(close.body)).toBe(200);
      expectContract(close, 'closeAdminAgency');
      expect(close.body).toEqual({ status: 'CLOSED', releasedHosts: 1 });
      expect((await agencyOf(owner)).closeReason).toBe('ADMIN');
      const closedNote = (await notifications(owner)).find((x) => x.type === 'AGENCY_CLOSED');
      expect(closedNote?.target.requiredHosts).toBeUndefined();
      const again = await post(clockAdmin, `/admin/agencies/${row.id}/close`, {
        reason: 'again',
        totpCode: nextCode(clockAdmin.secret),
      });
      expect(again.status).toBe(409);
      expect(again.body.error.code).toBe('ADMIN_ACTION_REFUSED');
      const audit = await ctx.prisma.auditLog.findFirstOrThrow({
        where: { action: 'agency.close', targetId: row.id },
      });
      expect(audit.actorUserId).toBe(clockAdmin.id);
      expect(audit.metadata).toMatchObject({ reason: 'ADMIN', note: 'fake documents', via: 'panel' });

      const reopen = await post(clockAdmin, `/admin/agencies/${row.id}/reopen`, {
        reason: 'documents checked',
        totpCode: nextCode(clockAdmin.secret),
      });
      expect(reopen.status, JSON.stringify(reopen.body)).toBe(200);
      expectContract(reopen, 'reopenAdminAgency');
      expect(Date.parse(reopen.body.probationEndsAt)).toBe(clock + 7 * DAY);
      const m = await mine(owner);
      expect(m.ownAgency?.probation).toMatchObject({ status: 'RUNNING' });
      expect((await mine(host)).membership).toBeNull(); // released hosts do not come back
    });

    it('economy-admin: agency-probation-extend, agency-close, agency-reopen, agency-probation-sweep', async () => {
      const owner = await signup();
      const opened = await openFor(owner);
      const code = opened.ownAgency!.inviteCode;
      const id = (await agencyOf(owner)).id;
      const env = { ...process.env, DOTENV_CONFIG_QUIET: 'true', LIVE_RANKINGS_TIME_ZONE: 'UTC' };
      const cli = (args: string[]) =>
        run('node', ['--import', 'tsx', 'src/cli/economy-admin.ts', ...args], { env });
      await expect(cli(['agency-close', code])).rejects.toMatchObject({ code: 1 });
      const before = (await agencyOf(owner)).probationEndsAt!.getTime();
      const ext = await cli(['agency-probation-extend', code, '2', '--note', 'cli extend']);
      expect(ext.stdout).toContain('probation now ends');
      expect((await agencyOf(owner)).probationEndsAt!.getTime()).toBe(before + 2 * DAY);
      const closed = await cli(['agency-close', code, '--note', 'cli close']);
      expect(closed.stdout).toContain('CLOSED');
      expect((await agencyOf(owner)).status).toBe('CLOSED');
      await expect(cli(['agency-close', code, '--note', 'twice'])).rejects.toMatchObject({ code: 1 });
      const reopened = await cli(['agency-reopen', code, '--note', 'cli reopen']);
      expect(reopened.stdout).toContain('OPEN');
      expect((await agencyOf(owner)).status).toBe('OPEN');
      const sweep = await cli(['agency-probation-sweep']);
      expect(sweep.stdout).toMatch(/Probations: \d+ passed, \d+ closed, \d+ reminded/);
      const list = await cli(['agency-list']);
      expect(list.stdout).toContain(code);
      const audits = await ctx.prisma.auditLog.findMany({
        where: { targetId: id, action: { in: ['agency.probation.extend', 'agency.close', 'agency.reopen'] } },
      });
      expect(audits.map((a) => (a.metadata as { via: string }).via)).toEqual(['cli', 'cli', 'cli']);
      // The team cannot make a second agency for the owner of a closed one.
      await cli(['agency-close', code, '--note', 'close for create']);
      await expect(cli(['agency-create', owner.email])).rejects.toMatchObject({
        stderr: expect.stringContaining('closed agency'),
      });
    });
  });
});
