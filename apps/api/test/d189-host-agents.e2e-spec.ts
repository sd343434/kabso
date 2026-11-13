/**
 * D189 (owner 2026-10-30; contract v1.58-social, CONVENTIONS §10.52, CP-032): host agents «وكيل مضيفين» get perks like
 * the recharge agents — at activation (`economy-admin agency-create`) the code `host` + a sequential number (≥ 2
 * digits) becomes their special username (§10.48.1, source HOST_AGENT, locked, never reused), and the frame, badge
 * and entrance follow `hostAgent` on the profile and every UserSummary while the agency is not suspended (any rank).
 * A suspension (of the host agent or of the account) gives the base username back and removes every perk at once.
 * A person who is also a recharge agent keeps the code activated first; the other stays reserved. End to end
 * against PostgreSQL + Redis.
 */
import { execFileSync } from 'node:child_process';
import { randomUUID } from 'node:crypto';
import { fileURLToPath } from 'node:url';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { createAgencyIn, HostAgentError } from '../src/modules/economy/host-agents.js';
import { dateValue } from '../src/modules/economy/economy-math.js';
import { LiveChatService } from '../src/modules/live/live-chat.service.js';
import { LiveMediaService } from '../src/modules/live/live-media.service.js';
import { LIVE_MEDIA_PROVIDER } from '../src/modules/live/media/live-media.provider.js';
import { OBJECT_STORAGE } from '../src/modules/media/object-storage.js';
import { approveApplicationIn, suspendIn, topUpIn } from '../src/modules/recharge/recharge-core.js';
import { AccountLifecycleService } from '../src/modules/users/profiles/account-lifecycle.service.js';
import { grantSpecialIn, SpecialUsernameError } from '../src/modules/users/special-usernames.js';
import { MemoryLiveMedia } from './helpers/memory-live-media.js';
import { MemoryObjectStorage } from './helpers/memory-storage.js';
import { expectContract, openapi } from './helpers/openapi.js';
import { createTestApp, registerVerified, type TestContext } from './helpers/test-app.js';

interface TestUser {
  readonly id: string;
  readonly username: string;
  readonly email: string;
  readonly password: string;
  readonly token: string;
}

/** Runs `pnpm economy:admin …` as on the server (migration role, a child process). */
function economyAdmin(...args: string[]): { status: number; out: string } {
  try {
    const out = execFileSync('pnpm', ['-s', 'economy:admin', ...args], {
      cwd: fileURLToPath(new URL('..', import.meta.url)),
      env: { ...process.env, LIVE_RANKINGS_TIME_ZONE: 'UTC' },
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'pipe'],
    });
    return { status: 0, out };
  } catch (err) {
    const e = err as { status: number; stderr: string };
    return { status: e.status, out: e.stderr };
  }
}

const RULES = {
  activationMinCoins: 30_000_000,
  priceTiers: [{ minCoins: 0, minorPerMillion: 1200 }],
  currency: 'USD',
};
const codeNumber = (code: string) => Number(code.slice(4));

describe('D189 contract coverage', () => {
  it('openapi v1.58-social declares the host-agent tag, the profile field and the dashboard part', () => {
    const schemas = (openapi.components as { schemas: Record<string, Record<string, unknown>> }).schemas;
    expect(schemas.HostAgentTag).toBeDefined();
    expect((schemas.HostAgentCode as { pattern: string }).pattern).toBe('^host[0-9]{2,}$');
    expect((schemas.PublicProfile as { required: string[] }).required).toContain('hostAgent');
    expect(Object.keys((schemas.UserSummary as { properties: object }).properties)).toContain('hostAgent');
    expect((schemas.OwnAgency as { required: string[] }).required).toContain('hostAgent');
    const source = (schemas.MeSpecialUsername as { properties: Record<string, { enum: string[] }> })
      .properties.source!;
    expect(source.enum).toContain('HOST_AGENT');
  });
});

describe('D189 host agents', { timeout: 300_000 }, () => {
  let ctx: TestContext;
  const media = new MemoryLiveMedia();
  const auth = (u: TestUser) => ({ Authorization: `Bearer ${u.token}` });
  const signup = async (): Promise<TestUser> => {
    const { res, payload } = await registerVerified(ctx);
    expect(res.status).toBe(201);
    return {
      id: res.body.user.id as string,
      username: res.body.user.username as string,
      email: payload.email,
      password: payload.password,
      token: res.body.tokens.accessToken as string,
    };
  };
  const shown = async (userId: string) =>
    (await ctx.prisma.userProfile.findUniqueOrThrow({ where: { userId } })).username;
  const me = async (u: TestUser) => {
    const res = await ctx.http.get('/api/v1/me').set(auth(u));
    expect(res.status).toBe(200);
    expectContract(res, 'getMe');
    return res.body as { username: string; specialUsername?: Record<string, unknown> };
  };
  const login = (identifier: string, password: string) =>
    ctx.http.post('/api/v1/auth/login').send({ identifier, password });
  const changeUsername = (u: TestUser, username: string) =>
    ctx.http.put('/api/v1/me/username').set(auth(u)).send({ username });
  const profile = async (viewer: TestUser, name: string) => {
    const res = await ctx.http.get(`/api/v1/users/${name}`).set(auth(viewer));
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    expectContract(res, 'getPublicProfile');
    return res.body as {
      id: string;
      username: string;
      hostAgent: { code: string } | null;
      rechargeAgent: { code: string } | null;
    };
  };
  const ownHostAgent = async (u: TestUser) => {
    const res = await ctx.http.get('/api/v1/me/agency').set(auth(u));
    expect(res.status).toBe(200);
    expectContract(res, 'getMyAgency');
    return (
      res.body as { ownAgency: { hostAgent: { code: string; active: boolean; usernameShown: boolean } } }
    ).ownAgency.hostAgent;
  };
  /** The CLI as on the server: the invite code and the host code it printed. */
  const createAgencyCli = (owner: TestUser) => {
    const r = economyAdmin('agency-create', owner.email);
    expect(r.status, r.out).toBe(0);
    const m = /invite code ([A-Z0-9]{8}), host code (host[0-9]+)/.exec(r.out);
    expect(m, r.out).not.toBeNull();
    return { inviteCode: m![1]!, hostCode: m![2]! };
  };
  /** The same core in-process (for concurrency). */
  let invite = 0;
  const createAgency = (owner: TestUser) =>
    ctx.prisma.$transaction((tx) =>
      createAgencyIn(
        tx,
        {
          ownerUserId: owner.id,
          inviteCode: `Q${String(++invite).padStart(3, '0')}${owner.id.slice(-4).toUpperCase()}`.replace(
            /[^A-HJ-NP-Z2-9]/g,
            'Q',
          ),
          parentAgencyId: null,
          evaluateFrom: dateValue('2099-01-01'),
        },
        new Date(),
        30,
      ),
    );
  const counter = async () =>
    (await ctx.prisma.hostAgentCounter.findUniqueOrThrow({ where: { id: 1 } })).lastNumber;
  const activateRecharge = async (u: TestUser): Promise<string> => {
    const id = `00000000-0000-7000-8000-${u.id.slice(-12)}`;
    await ctx.prisma.rechargeAgentApplication.create({
      data: {
        id,
        userId: u.id,
        fullName: 'Test Agent Name',
        phone: '+201001234567',
        locations: [{ country: 'EG', cities: ['Cairo'] }],
        paymentMethods: [{ country: 'EG', type: 'BANK_TRANSFER', details: 'x' }],
        photoKey: `private/recharge-agents/${id}/photo.webp`,
        selfieKey: `private/recharge-agents/${id}/selfie.webp`,
      },
    });
    await ctx.prisma.$transaction((tx) => approveApplicationIn(tx, id, new Date()));
    const r = await ctx.prisma.$transaction((tx) =>
      topUpIn(tx, u.id, 30_000_000n, 36_000n, null, RULES, new Date(), 30),
    );
    return r.code!;
  };

  beforeAll(async () => {
    ctx = await createTestApp(
      {
        LIVE_HOSTING_ENABLED: 'true',
        LIVE_HEARTBEAT_STALE_SECONDS: '3600',
        LIVE_RANKINGS_TIME_ZONE: 'UTC',
        RECHARGE_AGENT_SWEEP_INTERVAL_SECONDS: '0',
        SPECIAL_USERNAME_SWEEP_INTERVAL_SECONDS: '0',
        AGENCY_SWEEP_INTERVAL_SECONDS: '0',
      },
      [
        { token: OBJECT_STORAGE, value: new MemoryObjectStorage() },
        { token: LIVE_MEDIA_PROVIDER, value: media },
      ],
    );
  });
  afterAll(async () => ctx?.close());

  it('agency-create makes @hostNN the username, locked; base and code both sign in; the dashboard shows it', async () => {
    const agent = await signup();
    const base = agent.username;
    const { hostCode } = createAgencyCli(agent);
    expect(hostCode).toMatch(/^host[0-9]{2,}$/);
    expect(hostCode).toBe(`host${String(await counter()).padStart(2, '0')}`);
    expect(await shown(agent.id)).toBe(hostCode);

    const own = await me(agent);
    expect(own.username).toBe(hostCode);
    expect(own.specialUsername).toMatchObject({
      username: hostCode,
      baseUsername: base,
      source: 'HOST_AGENT',
      expiresAt: null,
      locked: true,
    });
    expect(await ownHostAgent(agent)).toEqual({ code: hostCode, active: true, usernameShown: true });

    const changed = await changeUsername(agent, `${base}x`);
    expect(changed.status).toBe(409);
    expect(changed.body.error.code).toBe('USERNAME_LOCKED');
    for (const id of [hostCode, base, base.toUpperCase(), agent.email]) {
      const res = await login(id, agent.password);
      expect(res.status, id).toBe(200);
      expect(res.body.user.id).toBe(agent.id);
      expect(res.body.user.username).toBe(hostCode);
    }
    expect(
      await ctx.prisma.auditLog.count({ where: { action: 'host_agent.activate', targetType: 'agency' } }),
    ).toBeGreaterThan(0);
  });

  it('codes are sequential, padded, skip names already taken, and stay distinct under concurrency', async () => {
    // Jump the counter to 98 (only forward): the next codes are host99, then host100.
    const start = Math.max(await counter(), 97);
    await ctx.prisma.hostAgentCounter.update({ where: { id: 1 }, data: { lastNumber: start } });
    // An older account already named like the code after next keeps its name; that number is skipped.
    const older = await signup();
    const taken = `host${String(start + 2).padStart(2, '0')}`;
    await ctx.prisma.userProfile.update({ where: { userId: older.id }, data: { username: taken } });

    const a = await signup();
    const b = await signup();
    const ca = (await createAgency(a)).hostCode;
    const cb = (await createAgency(b)).hostCode;
    expect(codeNumber(ca)).toBe(start + 1);
    expect(codeNumber(cb)).toBe(start + 3);
    expect(cb).not.toBe(taken);
    if (start === 97) expect([ca, cb]).toEqual(['host98', 'host100']);
    expect(await shown(older.id)).toBe(taken);
    // The older account still signs in with it and keeps its profile.
    expect((await login(taken, older.password)).status).toBe(200);

    // Six activations at once: six distinct consecutive numbers, each the owner's username.
    const users = await Promise.all(Array.from({ length: 6 }, () => signup()));
    const before = await counter();
    const codes = await Promise.all(users.map((u) => createAgency(u).then((r) => r.hostCode)));
    expect(new Set(codes).size).toBe(6);
    expect(codes.map(codeNumber).sort((x, y) => x - y)).toEqual([1, 2, 3, 4, 5, 6].map((i) => before + i));
    for (const [i, u] of users.entries()) expect(await shown(u.id)).toBe(codes[i]);
    // An owner has one agency (and one code).
    await expect(createAgency(users[0]!)).rejects.toThrow();
  });

  it('the base username never appears in what others read; hostAgent is on the profile and every summary', async () => {
    const agent = await signup();
    const base = agent.username;
    const { agencyId, hostCode } = await createAgency(agent);
    const viewer = await signup();
    const noBase = (body: unknown, what: string) => {
      const json = JSON.stringify(body);
      expect(json, what).not.toContain(base);
      expect(json, what).not.toContain('baseUsername');
      expect(json, what).not.toContain('specialUsername');
    };
    for (const name of [hostCode, base]) {
      const p = await profile(viewer, name);
      expect(p.username).toBe(hostCode);
      expect(p.hostAgent).toEqual({ code: hostCode });
      expect(p.rechargeAgent).toBeNull();
      noBase(p, `profile via ${name}`);
    }
    const post = await ctx.http
      .post('/api/v1/posts')
      .set(auth(agent))
      .set('Idempotency-Key', randomUUID())
      .send({ text: 'hello from a host agent' });
    expect(post.status).toBe(201);
    const read = await ctx.http.get(`/api/v1/posts/${post.body.id as string}`).set(auth(viewer));
    expect(read.body.author).toMatchObject({ username: hostCode, hostAgent: { code: hostCode } });
    noBase(read.body, 'post author');
    const search = await ctx.http.get('/api/v1/search').query({ q: base, type: 'users' }).set(auth(viewer));
    expect(JSON.stringify(search.body)).not.toContain(agent.id);

    // In a live room: the host's summary, a chat author, the join line (never dropped), the viewers list.
    await ctx.prisma.liveHost.create({ data: { userId: agent.id, source: 'ADMIN' } });
    const room = await ctx.http
      .post('/api/v1/live/rooms')
      .set(auth(agent))
      .send({ title: 'Host agent live' });
    expect(room.status, JSON.stringify(room.body)).toBe(201);
    const roomId = room.body.id as string;
    expect(room.body.host.hostAgent).toEqual({ code: hostCode });
    noBase(room.body, 'room');
    const msg = await ctx.http
      .post(`/api/v1/live/rooms/${roomId}/chat`)
      .set(auth(agent))
      .send({ text: 'hi', clientId: randomUUID() });
    expect(msg.status).toBe(201);
    expectContract(msg, 'sendLiveChatMessage');
    expect(msg.body.author.hostAgent).toEqual({ code: hostCode });

    const guest = await signup();
    const guestCode = (await createAgency(guest)).hostCode;
    const plain = await signup();
    const onJoined = (id: string) =>
      ctx.app
        .get<LiveMediaService, { onJoined(r: string, i: string): Promise<void> }>(LiveMediaService)
        .onJoined(roomId, id);
    await onJoined(plain.id);
    await onJoined(guest.id); // the same second: a host agent's join is never dropped
    const joins = media.broadcastsOf(roomId, 'join');
    expect(joins.map((j) => (j.user as { hostAgent?: unknown }).hostAgent)).toEqual([
      undefined,
      { code: guestCode },
    ]);
    expect((joins.at(-1)!.user as { username: string }).username).toBe(guestCode);
    const viewers = await ctx.http.get(`/api/v1/live/rooms/${roomId}/viewers`).set(auth(agent));
    expectContract(viewers, 'listLiveRoomViewers');
    const vrow = (viewers.body.data as { user?: { id: string; hostAgent?: unknown } }[]).find(
      (v) => v.user?.id === guest.id,
    );
    expect(vrow?.user?.hostAgent).toEqual({ code: guestCode });

    // LAPSED keeps every perk (D189 b).
    await ctx.prisma.agency.update({ where: { id: agencyId }, data: { rank: 'LAPSED' } });
    expect((await profile(viewer, hostCode)).hostAgent).toEqual({ code: hostCode });
    expect(await shown(agent.id)).toBe(hostCode);
  });

  it('suspension gives the base back and removes every perk; the code stays theirs; reinstating restores', async () => {
    const agent = await signup();
    const base = agent.username;
    const { inviteCode, hostCode } = createAgencyCli(agent);
    const viewer = await signup();

    expect(economyAdmin('agency-suspend', inviteCode).status).not.toBe(0); // --note is required
    const s = economyAdmin('agency-suspend', inviteCode, '--note', 'fraud check');
    expect(s.status, s.out).toBe(0);
    expect(economyAdmin('agency-suspend', inviteCode, '--note', 'again').status).toBe(1);
    expect(await shown(agent.id)).toBe(base);
    expect((await me(agent)).specialUsername).toBeUndefined();
    const p = await profile(viewer, base);
    expect(p.hostAgent).toBeNull();
    const post = await ctx.http
      .post('/api/v1/posts')
      .set(auth(agent))
      .set('Idempotency-Key', randomUUID())
      .send({ text: 'suspended' });
    expect(post.body.author.hostAgent).toBeUndefined();
    expect(await ownHostAgent(agent)).toEqual({ code: hostCode, active: false, usernameShown: false });
    const row = await ctx.prisma.specialUsername.findFirstOrThrow({ where: { userId: agent.id } });
    expect(row).toMatchObject({
      username: hostCode,
      status: 'GRACE',
      graceUntil: null,
      endReason: 'SUSPENDED',
    });
    // The code no longer signs in; an old link still leads to the person; nobody else can take it.
    expect((await login(hostCode, agent.password)).status).toBe(401);
    expect((await profile(viewer, hostCode)).id).toBe(agent.id);
    expect((await changeUsername(viewer, hostCode)).status).toBe(409);
    // While suspended the person may change the regular username (unlocked).
    expect((await changeUsername(agent, `${base}z`)).status).toBe(200);

    const r = economyAdmin('agency-reinstate', inviteCode);
    expect(r.status, r.out).toBe(0);
    expect(economyAdmin('agency-reinstate', inviteCode).status).toBe(1);
    expect(await shown(agent.id)).toBe(hostCode);
    expect((await me(agent)).specialUsername).toMatchObject({ username: hostCode, baseUsername: `${base}z` });
    expect((await profile(viewer, hostCode)).hostAgent).toEqual({ code: hostCode });
    for (const action of ['host_agent.suspend', 'host_agent.reinstate']) {
      expect(
        await ctx.prisma.auditLog.count({
          where: { action, metadata: { path: ['owner'], equals: agent.id } },
        }),
      ).toBe(1);
    }
    const list = economyAdmin('agency-list');
    expect(list.out).toContain(`host code ${hostCode}`);

    // An account suspension takes them all too (the base username is shown again).
    expect(await ctx.app.get(AccountLifecycleService).suspend(agent.id)).toBe(true);
    expect(await shown(agent.id)).toBe(`${base}z`);
  });

  it('host + digits is reserved: no registration, no username change, no gift', async () => {
    const u = await signup();
    for (const name of ['host123456', 'host0', 'host_77']) {
      const res = await changeUsername(u, name);
      expect([400, 409], name).toContain(res.status);
      const avail = await ctx.http.get('/api/v1/users/username-availability').query({ username: name });
      expect(avail.body.available, name).toBe(false);
    }
    expect((await changeUsername(u, 'host123456')).body.error.code).toBe('USERNAME_TAKEN');
    const reg = await ctx.http.post('/api/v1/auth/register').send({
      email: `h${Date.now().toString(36)}@example.com`,
      password: 'correct horse battery staple',
      username: 'host202468',
      displayName: 'Host',
      gender: 'UNDISCLOSED',
      locale: 'en',
    });
    expect(reg.status).toBe(409);
    const gift = await ctx.prisma
      .$transaction((tx) =>
        grantSpecialIn(
          tx,
          u.id,
          'host202468',
          { source: 'ADMIN_GIFT', expiresAt: null, reason: 'test', via: 'cli' },
          new Date(),
          30,
        ),
      )
      .then(
        () => 'granted',
        (err: unknown) => (err instanceof SpecialUsernameError ? err.reason : String(err)),
      );
    expect(gift).toBe('INVALID');
  });

  it('a recharge agent who becomes a host agent keeps coinNNNN; the host code is reserved and shown in the dashboard', async () => {
    const u = await signup();
    const viewer = await signup();
    const coin = await activateRecharge(u);
    const { hostCode, agencyId } = await createAgency(u);
    expect(await shown(u.id)).toBe(coin);
    expect(await ownHostAgent(u)).toEqual({ code: hostCode, active: true, usernameShown: false });
    const reserved = await ctx.prisma.specialUsername.findFirstOrThrow({
      where: { userId: u.id, username: hostCode },
    });
    expect(reserved).toMatchObject({ status: 'GRACE', source: 'HOST_AGENT', graceUntil: null });
    // Both badges.
    const p = await profile(viewer, coin);
    expect(p.rechargeAgent).toEqual({ code: coin });
    expect(p.hostAgent).toEqual({ code: hostCode });
    expect((await changeUsername(viewer, hostCode)).status).toBe(409);

    // The recharge agent suspended: the host code (still live) becomes the username.
    await ctx.prisma.$transaction((tx) => suspendIn(tx, u.id, 'test', new Date(), 30));
    expect(await shown(u.id)).toBe(hostCode);
    expect((await me(u)).specialUsername).toMatchObject({ source: 'HOST_AGENT' });
    // Both suspended: the base.
    await ctx.prisma.$transaction(async (tx) => {
      const { suspendHostAgentIn } = await import('../src/modules/economy/host-agents.js');
      await suspendHostAgentIn(tx, agencyId, 'test', new Date(), 30);
    });
    expect(await shown(u.id)).toBe(u.username);
  });

  it('a host agent who becomes a recharge agent keeps hostNN; the coin code is reserved', async () => {
    const u = await signup();
    const { hostCode } = await createAgency(u);
    const coin = await activateRecharge(u);
    expect(await shown(u.id)).toBe(hostCode);
    expect(
      await ctx.prisma.specialUsername.findFirstOrThrow({ where: { userId: u.id, username: coin } }),
    ).toMatchObject({
      status: 'GRACE',
      source: 'RECHARGE_AGENT',
      graceUntil: null,
    });
    expect(ctx.app.get(LiveChatService)).toBeDefined();
    expect(HostAgentError).toBeDefined();
  });

  it('the sweeper gives agencies made before D189 their code, oldest first', async () => {
    const old1 = await signup();
    const old2 = await signup();
    for (const [i, u] of [old1, old2].entries()) {
      await ctx.prisma.agency.create({
        data: {
          ownerUserId: u.id,
          inviteCode: `OLD${String(i + 2)}${u.id.slice(-4).toUpperCase()}`.replace(/[^A-HJ-NP-Z2-9]/g, 'Q'),
          evaluateFrom: dateValue('2099-01-01'),
          createdAt: new Date(Date.now() - (10 - i) * 86_400_000),
        },
      });
    }
    const { AgencyService } = await import('../src/modules/economy/agency.service.js');
    expect(await ctx.app.get(AgencyService).assignHostCodes()).toBeGreaterThanOrEqual(2);
    const c1 = await shown(old1.id);
    const c2 = await shown(old2.id);
    expect(c1).toMatch(/^host[0-9]{2,}$/);
    expect(codeNumber(c2)).toBeGreaterThan(codeNumber(c1));
    expect(await ctx.app.get(AgencyService).assignHostCodes()).toBe(0);
  });
});
