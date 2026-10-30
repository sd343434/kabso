/**
 * D186 (owner 2026-10-30; contract v1.55-social, CONVENTIONS §10.49): the active-host frame. An active
 * agency host (D179's test: ≥ 7 live days and ≥ 10 live hours in the last 30 days) owns a bag frame —
 * blue for a male host, pink for a female one, the one they choose otherwise — source HOST_ACTIVE, never
 * sent, worn or removed in the bag; the agency sweeper takes it back (unworn) when the host is no longer
 * active and gives it again when they are; a gender change swaps it. End to end against PostgreSQL +
 * Redis, with the `economy-admin` and `bag-admin` CLIs as on the server.
 */
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { AuditAction } from '../src/common/audit/audit.service.js';
import { BAG_CATALOGUE } from '../src/modules/bag/bag.catalogue.js';
import { AgencyService } from '../src/modules/economy/agency.service.js';
import { LIVE_MEDIA_PROVIDER } from '../src/modules/live/media/live-media.provider.js';
import { MemoryLiveMedia } from './helpers/memory-live-media.js';
import { expectContract, operations } from './helpers/openapi.js';
import { createTestApp, registerVerified, type TestContext } from './helpers/test-app.js';

/** Runs `pnpm <script> …` as on the server (migration role, a child process). */
function cli(script: string, ...args: string[]): { status: number; out: string } {
  try {
    const out = execFileSync('pnpm', ['-s', script, ...args], {
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

interface TestUser {
  readonly id: string;
  readonly username: string;
  readonly email: string;
  readonly token: string;
}

interface HostFrameBody {
  agencyHost: boolean;
  active: boolean;
  liveDays: number;
  liveSeconds: number;
  style: 'BLUE' | 'PINK' | null;
  styleFrom: 'GENDER' | 'CHOICE' | null;
  canChoose: boolean;
  frame: { code: string; assetKey: string; equipped: boolean } | null;
  rule: { minDays: number; minHours: number; windowDays: number };
}

const DAY_MS = 86_400_000;

describe('D186 contract coverage', () => {
  it('openapi v1.55-social declares the host-frame operations', () => {
    const ids = operations().map((o) => `${o.operationId} ${o.method.toUpperCase()} ${o.path}`);
    expect(ids).toEqual(
      expect.arrayContaining([
        'getMyHostFrame GET /api/v1/me/host-frame',
        'setMyHostFrameStyle PUT /api/v1/me/host-frame/style',
      ]),
    );
  });
});

describe('D186 active-host frames', { timeout: 300_000 }, () => {
  const media = new MemoryLiveMedia();
  let ctx: TestContext;
  let agencyCode = '';

  const auth = (u: TestUser) => ({ Authorization: `Bearer ${u.token}` });
  const signup = async (gender: 'MALE' | 'FEMALE' | 'UNDISCLOSED'): Promise<TestUser> => {
    const { res, payload } = await registerVerified(ctx, { gender });
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    return {
      id: res.body.user.id as string,
      username: res.body.user.username as string,
      email: String(payload.email).trim().toLowerCase(),
      token: res.body.tokens.accessToken as string,
    };
  };
  /** One ended live a day at 01:00 UTC on each of the `days` days before today, `hours` long. */
  const liveHistory = async (u: TestUser, days: number, hours: number) => {
    const now = new Date();
    const today = Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate());
    for (let d = 1; d <= days; d++) {
      const start = new Date(today - d * DAY_MS + 3_600_000);
      const end = new Date(start.getTime() + hours * 3_600_000);
      await ctx.prisma.liveRoom.create({
        data: {
          hostUserId: u.id,
          title: 'past live',
          status: 'ENDED',
          endReason: 'HOST_ENDED',
          startedAt: start,
          lastHeartbeatAt: end,
          endedAt: end,
        },
      });
    }
  };
  const forgetLives = (u: TestUser) => ctx.prisma.liveRoom.deleteMany({ where: { hostUserId: u.id } });
  const join = async (u: TestUser) => {
    const res = await ctx.http.post('/api/v1/me/agency/join').set(auth(u)).send({ inviteCode: agencyCode });
    expect(res.status, JSON.stringify(res.body)).toBe(201);
  };
  const hostFrame = async (u: TestUser): Promise<HostFrameBody> => {
    const res = await ctx.http.get('/api/v1/me/host-frame').set(auth(u));
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    expectContract(res, 'getMyHostFrame');
    return res.body as HostFrameBody;
  };
  const chooseStyle = (u: TestUser, style: string) =>
    ctx.http.put('/api/v1/me/host-frame/style').set(auth(u)).send({ style });
  const frames = async (u: TestUser) => {
    const res = await ctx.http.get('/api/v1/me/bag?category=AVATAR_FRAME').set(auth(u));
    expect(res.status).toBe(200);
    expectContract(res, 'getMyBag');
    return res.body.data as {
      code: string;
      source: string;
      equipped: boolean;
      expiresAt: string | null;
      transferable: boolean;
    }[];
  };
  const wear = (u: TestUser, code: string | null) =>
    ctx.http.put('/api/v1/me/bag/equipped').set(auth(u)).send({ category: 'AVATAR_FRAME', code });
  const profileFrame = async (viewer: TestUser, u: TestUser) => {
    const res = await ctx.http.get(`/api/v1/users/${u.username}`).set(auth(viewer));
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    expectContract(res, 'getPublicProfile');
    return res.body.avatarFrame as { code: string; assetKey: string } | null;
  };
  const audits = (u: TestUser, action: AuditAction) =>
    ctx.prisma.auditLog.findMany({
      where: { action, targetType: 'user', targetId: u.id },
      orderBy: { createdAt: 'asc' },
      select: { actorUserId: true, metadata: true },
    });
  const sweep = () => ctx.app.get(AgencyService).evaluate();

  let owner: TestUser;
  let viewer: TestUser;

  beforeAll(async () => {
    ctx = await createTestApp(
      { LIVE_HOSTING_ENABLED: 'true', LIVE_HEARTBEAT_STALE_SECONDS: '3600', LIVE_RANKINGS_TIME_ZONE: 'UTC' },
      [{ token: LIVE_MEDIA_PROVIDER, value: media }],
    );
    await ctx.prisma.bagItem.createMany({ data: BAG_CATALOGUE.map((i) => ({ ...i })) });
    owner = await signup('MALE');
    viewer = await signup('FEMALE');
    const r = cli('economy:admin', 'agency-create', owner.email);
    expect(r.status, r.out).toBe(0);
    agencyCode = /invite code ([A-Z0-9]{8})/.exec(r.out)![1]!;
  });
  afterAll(async () => ctx?.close());

  it('an active male host gets the blue frame on joining; not worn, permanent, never sendable', async () => {
    const host = await signup('MALE');
    await liveHistory(host, 7, 1.5); // 7 days, 10.5 hours: active
    expect((await hostFrame(host)).agencyHost).toBe(false);
    await join(host); // past live time counts: active at once
    const owned = await frames(host);
    expect(owned).toEqual([
      expect.objectContaining({
        code: 'host_frame_blue',
        source: 'HOST_ACTIVE',
        equipped: false,
        expiresAt: null,
        transferable: false,
      }),
    ]);
    const status = await hostFrame(host);
    expect(status).toMatchObject({
      agencyHost: true,
      active: true,
      liveDays: 7,
      liveSeconds: 7 * 1.5 * 3600,
      style: 'BLUE',
      styleFrom: 'GENDER',
      canChoose: false,
      frame: { code: 'host_frame_blue', assetKey: 'host_frame_blue', equipped: false },
      rule: { minDays: 7, minHours: 10, windowDays: 30 },
    });
    expect(await audits(host, AuditAction.HOST_FRAME_GRANT)).toEqual([
      { actorUserId: null, metadata: { item: 'host_frame_blue' } },
    ]);
    // Not sendable (the HOST_ACTIVE source), whole or in part.
    const send = await ctx.http
      .post('/api/v1/me/bag/transfers')
      .set(auth(host))
      .send({ code: 'host_frame_blue', username: viewer.username });
    expect(send.status).toBe(409);
    expect(send.body.error.code).toBe('BAG_ITEM_NOT_TRANSFERABLE');
    expectContract(send, 'sendMyBagItem');
    // The admin CLI cannot give or take a host frame either.
    const grant = cli('bag:admin', 'grant', viewer.email, 'host_frame_pink');
    expect(grant.status).toBe(1);
    expect(grant.out).toContain('follows the host');
    expect(
      await ctx.prisma.userBagItem.count({ where: { userId: viewer.id, itemCode: 'host_frame_pink' } }),
    ).toBe(0);
    // A male host cannot pick the colour.
    const pick = await chooseStyle(host, 'PINK');
    expect(pick.status).toBe(409);
    expect(pick.body.error.code).toBe('HOST_FRAME_STYLE_FROM_GENDER');
    expectContract(pick, 'setMyHostFrameStyle');
  });

  it('worn like any frame: shown on the profile, on the host of a live and in user summaries', async () => {
    const host = await signup('MALE');
    await liveHistory(host, 8, 2);
    await join(host);
    const put = await wear(host, 'host_frame_blue');
    expect(put.status, JSON.stringify(put.body)).toBe(200);
    expect(put.body.equipped.code).toBe('host_frame_blue');
    expect(await profileFrame(viewer, host)).toEqual({
      code: 'host_frame_blue',
      assetKey: 'host_frame_blue',
    });
    // The live room's host (the audio seat ring's first seat) carries it.
    await ctx.prisma.liveHost.upsert({
      where: { userId: host.id },
      create: { userId: host.id, source: 'ADMIN' },
      update: {},
    });
    const room = await ctx.http.post('/api/v1/live/rooms').set(auth(host)).send({ title: 'Frames' });
    expect(room.status, JSON.stringify(room.body)).toBe(201);
    const detail = await ctx.http.get(`/api/v1/live/rooms/${room.body.id as string}`).set(auth(viewer));
    expect(detail.status).toBe(200);
    expectContract(detail, 'getLiveRoom');
    expect(detail.body.host.avatarFrame).toEqual({ code: 'host_frame_blue', assetKey: 'host_frame_blue' });
    // A UserSummary list (the agent's hosts) carries it too; a user who wears nothing has none.
    const hosts = await ctx.http.get('/api/v1/me/agency/hosts').set(auth(owner));
    expect(hosts.status).toBe(200);
    expectContract(hosts, 'listMyAgencyHosts');
    const row = (hosts.body.data as { user: { id: string; avatarFrame?: unknown } }[]).find(
      (h) => h.user.id === host.id,
    );
    expect(row?.user.avatarFrame).toEqual({ code: 'host_frame_blue', assetKey: 'host_frame_blue' });
    expect(await profileFrame(host, viewer)).toBeNull();
    const end = await ctx.http.post(`/api/v1/live/rooms/${room.body.id as string}/end`).set(auth(host));
    expect([200, 204]).toContain(end.status);
  });

  it('no longer active: taken back and unworn by the sweeper; active again: given back, not worn', async () => {
    const host = await signup('FEMALE');
    await liveHistory(host, 7, 1.5);
    await join(host);
    expect((await frames(host)).map((f) => f.code)).toEqual(['host_frame_pink']);
    expect((await wear(host, 'host_frame_pink')).status).toBe(200);
    // Below the test: 6 days only.
    await forgetLives(host);
    await liveHistory(host, 6, 3);
    expect((await hostFrame(host)).active).toBe(false);
    const { frames: changes } = await sweep();
    expect(changes).toEqual(
      expect.arrayContaining([{ kind: 'revoked', userId: host.id, code: 'host_frame_pink', wasWorn: true }]),
    );
    expect(await frames(host)).toEqual([]);
    expect(
      await ctx.prisma.userBagItem.count({
        where: { userId: host.id, category: 'AVATAR_FRAME', equipped: true },
      }),
    ).toBe(0);
    expect(await profileFrame(viewer, host)).toBeNull();
    expect(await audits(host, AuditAction.HOST_FRAME_REVOKE)).toEqual([
      { actorUserId: null, metadata: { item: 'host_frame_pink', wasWorn: true, active: false } },
    ]);
    // Idempotent: nothing more to do.
    expect((await sweep()).frames.filter((c) => c.userId === host.id)).toEqual([]);
    // Active again (the CLI evaluation does what the sweeper does): given back, not worn.
    await liveHistory(host, 7, 1.5);
    const r = cli('economy:admin', 'agency-evaluate');
    expect(r.status, r.out).toBe(0);
    expect(r.out).toContain(`host frame ${host.id}: +host_frame_pink`);
    expect(await frames(host)).toEqual([
      expect.objectContaining({ code: 'host_frame_pink', source: 'HOST_ACTIVE', equipped: false }),
    ]);
    expect(await audits(host, AuditAction.HOST_FRAME_GRANT)).toHaveLength(2);
  });

  it('a gender change swaps the frame and keeps it worn', async () => {
    const host = await signup('MALE');
    await liveHistory(host, 7, 1.5);
    await join(host);
    expect((await wear(host, 'host_frame_blue')).status).toBe(200);
    const patch = await ctx.http.patch('/api/v1/me').set(auth(host)).send({ gender: 'FEMALE' });
    expect(patch.status, JSON.stringify(patch.body)).toBe(200);
    expect(await frames(host)).toEqual([
      expect.objectContaining({ code: 'host_frame_pink', source: 'HOST_ACTIVE', equipped: true }),
    ]);
    expect(await profileFrame(viewer, host)).toEqual({
      code: 'host_frame_pink',
      assetKey: 'host_frame_pink',
    });
    expect(await audits(host, AuditAction.HOST_FRAME_SWAP)).toEqual([
      { actorUserId: null, metadata: { from: 'host_frame_blue', to: 'host_frame_pink', worn: true } },
    ]);
    // «Prefer not to say» with no choice yet: the frame goes (nothing to show until the host picks).
    await ctx.http.patch('/api/v1/me').set(auth(host)).send({ gender: 'UNDISCLOSED' });
    expect(await frames(host)).toEqual([]);
    expect((await hostFrame(host)).canChoose).toBe(true);
  });

  it('prefer not to say, or no gender: the host picks a colour (once, changeable), applied at once', async () => {
    const host = await signup('UNDISCLOSED');
    await liveHistory(host, 7, 1.5);
    await join(host);
    expect(await frames(host)).toEqual([]);
    expect(await hostFrame(host)).toMatchObject({
      active: true,
      style: null,
      styleFrom: null,
      canChoose: true,
      frame: null,
    });
    const blue = await chooseStyle(host, 'BLUE');
    expect(blue.status, JSON.stringify(blue.body)).toBe(200);
    expectContract(blue, 'setMyHostFrameStyle');
    expect(blue.body).toMatchObject({
      style: 'BLUE',
      styleFrom: 'CHOICE',
      frame: { code: 'host_frame_blue', equipped: false },
    });
    expect((await wear(host, 'host_frame_blue')).status).toBe(200);
    // Changed later: swapped, still worn; the same choice again changes nothing.
    const pink = await chooseStyle(host, 'PINK');
    expect(pink.body).toMatchObject({ style: 'PINK', frame: { code: 'host_frame_pink', equipped: true } });
    expect((await chooseStyle(host, 'PINK')).status).toBe(200);
    const choices = await ctx.prisma.auditLog.findMany({
      where: { action: AuditAction.HOST_FRAME_CHOICE, actorUserId: host.id },
      orderBy: { createdAt: 'asc' },
      select: { metadata: true },
    });
    expect(choices.map((c) => c.metadata)).toEqual([
      { from: null, to: 'BLUE', item: 'host_frame_blue' },
      { from: 'BLUE', to: 'PINK', item: 'host_frame_pink' },
    ]);
    expect(await audits(host, AuditAction.HOST_FRAME_SWAP)).toHaveLength(1);
    // Bad bodies.
    expect((await chooseStyle(host, 'GREEN')).status).toBe(400);
    // No gender at all (accounts from before D175): the same choice applies.
    await ctx.prisma.userProfile.update({ where: { userId: host.id }, data: { gender: null } });
    expect(await hostFrame(host)).toMatchObject({ canChoose: true, style: 'PINK', styleFrom: 'CHOICE' });
    // A stated gender wins over the choice.
    await ctx.http.patch('/api/v1/me').set(auth(host)).send({ gender: 'MALE' });
    expect((await frames(host)).map((f) => [f.code, f.equipped])).toEqual([['host_frame_blue', true]]);
  });

  it('a choice before being active gives nothing yet; leaving the agency or a suspension takes it back', async () => {
    const host = await signup('UNDISCLOSED');
    const early = await chooseStyle(host, 'PINK');
    expect(early.status).toBe(200);
    expect(early.body).toMatchObject({ agencyHost: false, active: false, style: 'PINK', frame: null });
    expect(await frames(host)).toEqual([]);
    await liveHistory(host, 10, 2);
    await join(host);
    expect((await frames(host)).map((f) => f.code)).toEqual(['host_frame_pink']);
    const leave = await ctx.http.post('/api/v1/me/agency/leave').set(auth(host));
    expect(leave.status).toBe(200);
    expect(await frames(host)).toEqual([]);
    expect((await hostFrame(host)).agencyHost).toBe(false);

    const other = await signup('FEMALE');
    await liveHistory(other, 7, 2);
    await join(other);
    expect((await frames(other)).map((f) => f.code)).toEqual(['host_frame_pink']);
    await ctx.prisma.user.update({ where: { id: other.id }, data: { status: 'SUSPENDED' } });
    expect((await sweep()).frames).toEqual(
      expect.arrayContaining([
        { kind: 'revoked', userId: other.id, code: 'host_frame_pink', wasWorn: false },
      ]),
    );
    expect(await ctx.prisma.userBagItem.count({ where: { userId: other.id, source: 'HOST_ACTIVE' } })).toBe(
      0,
    );
  });
});
