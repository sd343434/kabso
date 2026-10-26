/**
 * KL-079 / CP-018 (D106, owner 2026-10-26): families, CP couples and medals (openapi v1.21-live
 * DRAFT, CONVENTIONS §10.21, §10.5, §11.10, §4, §7), end to end against PostgreSQL + Redis with the
 * API as the DML-only runtime role.
 *
 * Coins are granted straight through the ledger (`creditIn`, as `wallet-admin` does; KL-077 runs the
 * CLI itself). Time comes from a FakeClock (7-day expiry, the bullet and tap rules). The medal
 * catalogue is re-seeded from `MEDAL_CATALOGUE` (the test database is truncated per suite).
 * `medals-admin backfill` runs as on the server: a child process with the migration role.
 */
import { execFileSync } from 'node:child_process';
import { randomUUID } from 'node:crypto';
import { fileURLToPath } from 'node:url';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { Clock } from '../src/common/time/clock.js';
import { CouplesService } from '../src/modules/couples/couples.service.js';
import { FamiliesService } from '../src/modules/families/families.service.js';
import { uuidv7 } from '../src/modules/levels/uuidv7.js';
import { LIVE_MEDIA_PROVIDER } from '../src/modules/live/media/live-media.provider.js';
import { MEDAL_CATALOGUE } from '../src/modules/medals/medals.catalogue.js';
import { creditIn } from '../src/modules/wallet/wallet-ledger.js';
import { MemoryLiveMedia } from './helpers/memory-live-media.js';
import { expectContract, operations } from './helpers/openapi.js';
import { createTestApp, registerVerified, settle, type TestContext } from './helpers/test-app.js';

class FakeClock extends Clock {
  private ms = Date.now();
  now(): Date {
    return new Date(this.ms);
  }
  advance(seconds: number): void {
    this.ms += Math.round(seconds * 1000);
  }
}

interface TestUser {
  readonly id: string;
  readonly username: string;
  readonly token: string;
}

const DAY = 24 * 3600;

/** Runs `pnpm medals:admin …` as on the server (migration role, a child process). */
function medalsAdmin(...args: string[]): { status: number; out: string } {
  try {
    const out = execFileSync('pnpm', ['-s', 'medals:admin', ...args], {
      cwd: fileURLToPath(new URL('..', import.meta.url)),
      env: process.env,
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'pipe'],
    });
    return { status: 0, out };
  } catch (err) {
    const e = err as { status: number; stderr: string };
    return { status: e.status, out: e.stderr };
  }
}

describe('CP-018 contract coverage', () => {
  it('openapi declares the family, CP and medal operations', () => {
    const ids = operations().map((o) => `${o.operationId} ${o.method.toUpperCase()} ${o.path}`);
    for (const op of [
      'getFamilyConfig GET /api/v1/families/config',
      'searchFamilies GET /api/v1/families',
      'createFamily POST /api/v1/families',
      'getMyFamily GET /api/v1/families/me',
      'getFamily GET /api/v1/families/{familyId}',
      'getFamilyByNumber GET /api/v1/family-numbers/{number}',
      'updateFamily PATCH /api/v1/families/{familyId}',
      'disbandFamily DELETE /api/v1/families/{familyId}',
      'listFamilyMembers GET /api/v1/families/{familyId}/members',
      'removeFamilyMember DELETE /api/v1/families/{familyId}/members/{username}',
      'setFamilyMemberRole PUT /api/v1/families/{familyId}/members/{username}/role',
      'transferFamily POST /api/v1/families/{familyId}/transfer',
      'leaveFamily POST /api/v1/families/{familyId}/leave',
      'requestToJoinFamily POST /api/v1/families/{familyId}/join-requests',
      'listFamilyJoinRequests GET /api/v1/families/{familyId}/join-requests',
      'acceptFamilyJoinRequest POST /api/v1/families/{familyId}/join-requests/{requestId}/accept',
      'declineFamilyJoinRequest POST /api/v1/families/{familyId}/join-requests/{requestId}/decline',
      'getMyFamilyJoinRequest GET /api/v1/me/family-join-request',
      'cancelFamilyJoinRequest DELETE /api/v1/me/family-join-request',
      'getCpConfig GET /api/v1/cp/config',
      'sendCpRequest POST /api/v1/cp/requests',
      'listCpRequests GET /api/v1/cp/requests',
      'cancelCpRequest DELETE /api/v1/cp/requests/{requestId}',
      'acceptCpRequest POST /api/v1/cp/requests/{requestId}/accept',
      'declineCpRequest POST /api/v1/cp/requests/{requestId}/decline',
      'getMyCp GET /api/v1/cp/me',
      'endCp DELETE /api/v1/cp/me',
      'sendCpGift POST /api/v1/cp/me/gifts',
      'listMedals GET /api/v1/medals',
      'listUserMedals GET /api/v1/users/{username}/medals',
      'getMyMedalShowcase GET /api/v1/me/medals/showcase',
      'setMyMedalShowcase PUT /api/v1/me/medals/showcase',
    ]) {
      expect(ids).toContain(op);
    }
  });
});

describe('CP-018 families, CP couples and medals', { timeout: 120_000 }, () => {
  const clock = new FakeClock();
  const media = new MemoryLiveMedia();
  let ctx: TestContext;

  const auth = (u: TestUser) => ({ Authorization: `Bearer ${u.token}` });
  const signup = async (): Promise<TestUser> => {
    const { res } = await registerVerified(ctx);
    expect(res.status).toBe(201);
    return {
      id: res.body.user.id as string,
      username: res.body.user.username as string,
      token: res.body.tokens.accessToken as string,
    };
  };
  const grant = (u: TestUser, coins: number) =>
    ctx.prisma.$transaction((tx) => creditIn(tx, u.id, BigInt(coins), 'ADMIN_GRANT', uuidv7()));
  const coins = async (u: TestUser): Promise<number> => {
    const res = await ctx.http.get('/api/v1/wallet/me').set(auth(u));
    expect(res.status).toBe(200);
    return res.body.coins as number;
  };
  const ledger = (u: TestUser) =>
    ctx.prisma.walletLedgerEntry.findMany({ where: { userId: u.id }, orderBy: { createdAt: 'asc' } });
  const notifications = async (u: TestUser) => {
    await settle(ctx);
    const res = await ctx.http.get('/api/v1/notifications').set(auth(u));
    expect(res.status).toBe(200);
    expectContract(res, 'listNotifications');
    return res.body.data as {
      type: string;
      actors: { username: string }[];
      target: { type: string; id: string; text: string | null } | null;
    }[];
  };
  const medalsOf = async (u: TestUser): Promise<string[]> =>
    (await ctx.prisma.userMedal.findMany({ where: { userId: u.id }, orderBy: { medalCode: 'asc' } })).map(
      (m) => m.medalCode,
    );
  const profile = async (reader: TestUser, u: TestUser, lang = 'en') => {
    const res = await ctx.http
      .get(`/api/v1/users/${u.username}`)
      .set(auth(reader))
      .set('Accept-Language', lang);
    expect(res.status).toBe(200);
    expectContract(res, 'getPublicProfile');
    return res.body as {
      family: { id: string; number: number; name: string; level: number; role: string } | null;
      cp: { partner: { username: string }; level: number; levelName: string; points: number } | null;
      medals: { owned: number; total: number; latest: { code: string }[]; showcase: { code: string }[] };
    };
  };

  // ---- Families ---------------------------------------------------------------------------------

  const createFamily = (u: TestUser, body: object) =>
    ctx.http.post('/api/v1/families').set(auth(u)).send(body);
  const newFamily = async (leader: TestUser, name: string): Promise<{ id: string; number: number }> => {
    await grant(leader, 500);
    const res = await createFamily(leader, { name, clientId: randomUUID() });
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    return res.body.family as { id: string; number: number };
  };
  const ask = (u: TestUser, familyId: string) =>
    ctx.http.post(`/api/v1/families/${familyId}/join-requests`).set(auth(u));
  const accept = (by: TestUser, familyId: string, requestId: string) =>
    ctx.http.post(`/api/v1/families/${familyId}/join-requests/${requestId}/accept`).set(auth(by));
  const join = async (leader: TestUser, u: TestUser, familyId: string) => {
    const asked = await ask(u, familyId);
    expect(asked.status).toBe(201);
    expect((await accept(leader, familyId, asked.body.id as string)).status).toBe(200);
  };
  const family = async (u: TestUser, familyId: string) => {
    const res = await ctx.http.get(`/api/v1/families/${familyId}`).set(auth(u));
    expect(res.status).toBe(200);
    expectContract(res, 'getFamily');
    return res.body as {
      points: number;
      level: number;
      memberCount: number;
      myRole: string | null;
      leader: { username: string };
    };
  };

  beforeAll(async () => {
    ctx = await createTestApp({ LIVE_HOSTING_ENABLED: 'true', LIVE_HEARTBEAT_STALE_SECONDS: '3600' }, [
      { token: Clock, value: clock },
      { token: LIVE_MEDIA_PROVIDER, value: media },
    ]);
    await ctx.prisma.medal.createMany({ data: MEDAL_CATALOGUE.map((m) => ({ ...m })) });
  });
  afterAll(async () => ctx?.close());

  describe('families', () => {
    it('create costs 500 coins in one transaction, is idempotent, and refuses short balances', async () => {
      const a = await signup();
      await grant(a, 499);
      const clientId = randomUUID();
      const short = await createFamily(a, { name: 'Lions', clientId });
      expect(short.status).toBe(409);
      expectContract(short, 'createFamily');
      expect(short.body.error.code).toBe('INSUFFICIENT_COINS');
      expect(await coins(a)).toBe(499);
      expect(await ctx.prisma.family.count({ where: { createdById: a.id } })).toBe(0);
      expect(await ctx.prisma.familyMember.count({ where: { userId: a.id } })).toBe(0);

      await grant(a, 101);
      const created = await createFamily(a, { name: '  Lions ', clientId });
      expect(created.status).toBe(201);
      expectContract(created, 'createFamily');
      expect(created.body.coins).toBe(100);
      const f = created.body.family;
      expect(f).toMatchObject({
        name: 'Lions',
        level: 1,
        points: 500,
        memberCount: 1,
        capacity: 500,
        myRole: 'LEADER',
      });
      expect(f.leader.username).toBe(a.username);
      expect(f.number).toBeGreaterThanOrEqual(10_000_000);
      expect(f.number).toBeLessThanOrEqual(99_999_999);

      const replay = await createFamily(a, { name: 'Other', clientId });
      expect(replay.status).toBe(200);
      expectContract(replay, 'createFamily');
      expect(replay.body.family.id).toBe(f.id);
      expect(replay.body.coins).toBe(100);
      const rows = (await ledger(a)).filter((r) => r.reason === 'FAMILY_CREATE');
      expect(rows.map((r) => [Number(r.delta), r.referenceId])).toEqual([[-500, f.id]]);

      const again = await createFamily(a, { name: 'Tigers', clientId: randomUUID() });
      expect(again.body.error.code).toBe('ALREADY_IN_FAMILY');

      // The name is unique ignoring case; nothing is charged for a taken name.
      const b = await signup();
      await grant(b, 500);
      const taken = await createFamily(b, { name: 'LIONS', clientId: randomUUID() });
      expect(taken.status).toBe(409);
      expect(taken.body.error.code).toBe('FAMILY_NAME_TAKEN');
      expect(await coins(b)).toBe(500);
      const bad = await createFamily(b, { name: 'L', clientId: randomUUID() });
      expect(bad.status).toBe(400);
      expect(bad.body.error.details).toEqual([{ field: 'name', issue: 'too_short' }]);

      // The creator earns FIRST_FAMILY with a notification; reads by number, search and "mine".
      expect(await medalsOf(a)).toEqual(['FIRST_FAMILY']);
      const inbox = await notifications(a);
      expect(inbox.find((n) => n.type === 'MEDAL_AWARDED')?.target).toMatchObject({
        type: 'MEDAL',
        id: 'FIRST_FAMILY',
      });
      const byNumber = await ctx.http.get(`/api/v1/family-numbers/${String(f.number)}`).set(auth(b));
      expect(byNumber.status).toBe(200);
      expectContract(byNumber, 'getFamilyByNumber');
      expect(byNumber.body.myRole).toBeNull();
      const search = await ctx.http.get('/api/v1/families').query({ q: 'lio' }).set(auth(b));
      expect(search.status).toBe(200);
      expectContract(search, 'searchFamilies');
      expect(search.body.data.map((x: { id: string }) => x.id)).toContain(f.id);
      const searchNumber = await ctx.http
        .get('/api/v1/families')
        .query({ q: String(f.number) })
        .set(auth(b));
      expect(searchNumber.body.data.map((x: { id: string }) => x.id)).toEqual([f.id]);
      const mine = await ctx.http.get('/api/v1/families/me').set(auth(a));
      expectContract(mine, 'getMyFamily');
      expect(mine.body.family.id).toBe(f.id);
      const none = await ctx.http.get('/api/v1/families/me').set(auth(b));
      expect(none.body).toEqual({ family: null });
      const config = await ctx.http.get('/api/v1/families/config').set(auth(b));
      expectContract(config, 'getFamilyConfig');
      expect(config.body).toMatchObject({ createCost: 500, capacity: 500, requestTtlDays: 7 });
    });

    it('join by request: accept, decline, pending rules, blocks, expiry and capacity', async () => {
      const [leader, b, c, d, e, other] = [
        await signup(),
        await signup(),
        await signup(),
        await signup(),
        await signup(),
        await signup(),
      ];
      const f = await newFamily(leader, 'Falcons');
      const g = await newFamily(other, 'Owls');

      const asked = await ask(b, f.id);
      expect(asked.status).toBe(201);
      expectContract(asked, 'requestToJoinFamily');
      expect(asked.body).toMatchObject({ status: 'PENDING', user: { username: b.username } });
      const again = await ask(b, f.id);
      expect(again.status).toBe(200);
      expect(again.body.id).toBe(asked.body.id);
      const elsewhere = await ask(b, g.id);
      expect(elsewhere.body.error.code).toBe('FAMILY_REQUEST_PENDING');
      const mineReq = await ctx.http.get('/api/v1/me/family-join-request').set(auth(b));
      expectContract(mineReq, 'getMyFamilyJoinRequest');
      expect(mineReq.body.request.id).toBe(asked.body.id);

      // Only the leader and deputies list and answer.
      const forbidden = await ctx.http.get(`/api/v1/families/${f.id}/join-requests`).set(auth(c));
      expect(forbidden.status).toBe(403);
      const list = await ctx.http.get(`/api/v1/families/${f.id}/join-requests`).set(auth(leader));
      expect(list.status).toBe(200);
      expectContract(list, 'listFamilyJoinRequests');
      expect(list.body.data.map((r: { id: string }) => r.id)).toEqual([asked.body.id]);
      expect((await accept(c, f.id, asked.body.id as string)).status).toBe(403);

      const accepted = await accept(leader, f.id, asked.body.id as string);
      expect(accepted.status).toBe(200);
      expectContract(accepted, 'acceptFamilyJoinRequest');
      expect(accepted.body).toMatchObject({ role: 'MEMBER', user: { username: b.username }, points: 0 });
      expect((await accept(leader, f.id, asked.body.id as string)).body.error.code).toBe(
        'FAMILY_REQUEST_NOT_PENDING',
      );
      expect((await family(leader, f.id)).memberCount).toBe(2);
      expect(await medalsOf(b)).toEqual(['FIRST_FAMILY']);
      const bInbox = await notifications(b);
      expect(bInbox.find((n) => n.type === 'FAMILY_JOIN_ACCEPTED')).toMatchObject({
        actors: [{ username: leader.username }],
        target: { type: 'FAMILY', id: f.id, text: 'Falcons' },
      });
      expect((await ask(b, g.id)).body.error.code).toBe('ALREADY_IN_FAMILY');
      expect((await profile(c, b)).family).toMatchObject({
        id: f.id,
        number: f.number,
        name: 'Falcons',
        role: 'MEMBER',
      });

      // Decline, with a notification.
      const cAsk = await ask(c, f.id);
      const declined = await ctx.http
        .post(`/api/v1/families/${f.id}/join-requests/${cAsk.body.id as string}/decline`)
        .set(auth(leader));
      expect(declined.status).toBe(204);
      expect((await notifications(c)).find((n) => n.type === 'FAMILY_JOIN_DECLINED')?.target).toMatchObject({
        type: 'FAMILY',
        id: f.id,
      });

      // A block either way between the requester and the leader refuses the request.
      await ctx.http.put(`/api/v1/users/${leader.username}/block`).set(auth(d)).expect(200);
      expect((await ask(d, f.id)).status).toBe(403);

      // A request expires after 7 days; cancelling one's own is idempotent.
      const eAsk = await ask(e, f.id);
      clock.advance(7 * DAY + 1);
      expect((await accept(leader, f.id, eAsk.body.id as string)).body.error.code).toBe(
        'FAMILY_REQUEST_NOT_PENDING',
      );
      const eAgain = await ask(e, f.id);
      expect(eAgain.status).toBe(201);
      expect((await ctx.http.delete('/api/v1/me/family-join-request').set(auth(e))).status).toBe(204);
      expect((await ctx.http.delete('/api/v1/me/family-join-request').set(auth(e))).status).toBe(204);
      const cancelled = await ctx.prisma.familyJoinRequest.findUniqueOrThrow({
        where: { id: eAgain.body.id as string },
      });
      expect(cancelled.status).toBe('CANCELLED');
      const stale = await ask(e, f.id);
      clock.advance(8 * DAY);
      expect(await ctx.app.get(FamiliesService).sweepExpired()).toBeGreaterThanOrEqual(1);
      expect(
        (await ctx.prisma.familyJoinRequest.findUniqueOrThrow({ where: { id: stale.body.id as string } }))
          .status,
      ).toBe('EXPIRED');

      // Capacity: 500 members (the count is the capacity check; set here instead of 498 sign-ups).
      const pending = await ask(e, f.id);
      await ctx.prisma.family.update({ where: { id: f.id }, data: { memberCount: 500 } });
      expect((await accept(leader, f.id, pending.body.id as string)).body.error.code).toBe('FAMILY_FULL');
      const x = await signup();
      expect((await ask(x, f.id)).body.error.code).toBe('FAMILY_FULL');
      await ctx.prisma.family.update({ where: { id: f.id }, data: { memberCount: 2 } });
    });

    it('roles, removing, leaving, transferring and disbanding', async () => {
      const [leader, b, c] = [await signup(), await signup(), await signup()];
      const f = await newFamily(leader, 'Wolves');
      await join(leader, b, f.id);
      await join(leader, c, f.id);

      const role = await ctx.http
        .put(`/api/v1/families/${f.id}/members/${b.username}/role`)
        .set(auth(leader))
        .send({ role: 'DEPUTY' });
      expect(role.status).toBe(200);
      expectContract(role, 'setFamilyMemberRole');
      expect(role.body.role).toBe('DEPUTY');
      expect(
        (
          await ctx.http
            .put(`/api/v1/families/${f.id}/members/${c.username}/role`)
            .set(auth(b))
            .send({ role: 'DEPUTY' })
        ).status,
      ).toBe(403);
      const members = await ctx.http.get(`/api/v1/families/${f.id}/members`).query({ limit: 2 }).set(auth(c));
      expect(members.status).toBe(200);
      expectContract(members, 'listFamilyMembers');
      expect(members.body.data.map((m: { role: string }) => m.role)).toEqual(['LEADER', 'DEPUTY']);
      const next = await ctx.http
        .get(`/api/v1/families/${f.id}/members`)
        .query({ limit: 2, cursor: members.body.page.nextCursor as string })
        .set(auth(c));
      expect(next.body.data.map((m: { user: { username: string } }) => m.user.username)).toEqual([
        c.username,
      ]);

      // A deputy accepts requests but cannot remove anyone.
      const d = await signup();
      const dAsk = await ask(d, f.id);
      expect((await accept(b, f.id, dAsk.body.id as string)).status).toBe(200);
      expect(
        (await ctx.http.delete(`/api/v1/families/${f.id}/members/${d.username}`).set(auth(b))).status,
      ).toBe(403);
      expect(
        (await ctx.http.delete(`/api/v1/families/${f.id}/members/${d.username}`).set(auth(leader))).status,
      ).toBe(204);
      expect((await family(leader, f.id)).memberCount).toBe(3);

      // The leader cannot leave; a member can.
      const leaderLeaves = await ctx.http.post(`/api/v1/families/${f.id}/leave`).set(auth(leader));
      expect(leaderLeaves.body.error.code).toBe('FAMILY_LEADER_CANNOT_LEAVE');
      expect((await ctx.http.post(`/api/v1/families/${f.id}/leave`).set(auth(c))).status).toBe(204);

      // Transfer: b leads, the old leader becomes a deputy.
      const transfer = await ctx.http
        .post(`/api/v1/families/${f.id}/transfer`)
        .set(auth(leader))
        .send({ username: b.username });
      expect(transfer.status).toBe(200);
      expectContract(transfer, 'transferFamily');
      expect(transfer.body).toMatchObject({ myRole: 'DEPUTY', leader: { username: b.username } });
      const audit = await ctx.prisma.auditLog.count({ where: { action: 'family.transfer', targetId: f.id } });
      expect(audit).toBe(1);

      // Disband only when the leader is alone; the name becomes free.
      expect((await ctx.http.delete(`/api/v1/families/${f.id}`).set(auth(b))).body.error.code).toBe(
        'FAMILY_NOT_EMPTY',
      );
      expect((await ctx.http.delete(`/api/v1/families/${f.id}`).set(auth(leader))).status).toBe(403);
      expect((await ctx.http.post(`/api/v1/families/${f.id}/leave`).set(auth(leader))).status).toBe(204);
      expect((await ctx.http.delete(`/api/v1/families/${f.id}`).set(auth(b))).status).toBe(204);
      expect((await ctx.http.get(`/api/v1/families/${f.id}`).set(auth(b))).status).toBe(404);
      expect((await profile(c, b)).family).toBeNull();
      const reuse = await newFamily(c, 'wolves');
      expect(reuse.id).not.toBe(f.id);
    });

    it("the family level comes from its members' spending while in the family", async () => {
      const [leader, member, host] = [await signup(), await signup(), await signup()];
      const f = await newFamily(leader, 'Eagles');
      await join(leader, member, f.id);
      // A bullet message (15 coins) by a member is 15 family points.
      await ctx.prisma.liveHost.create({ data: { userId: host.id, source: 'ADMIN' } });
      const started = await ctx.http.post('/api/v1/live/rooms').set(auth(host)).send({ title: 'Family' });
      expect(started.status).toBe(201);
      const roomId = started.body.id as string;
      const raw = JSON.stringify({
        event: 'participant_joined',
        room: { name: roomId },
        participant: { identity: member.id },
      });
      await ctx.http
        .post('/internal/livekit/webhook')
        .set('Content-Type', 'application/webhook+json')
        .set('Authorization', MemoryLiveMedia.sign(raw))
        .send(raw)
        .expect(200);
      await grant(member, 1000);
      const bullet = await ctx.http
        .post(`/api/v1/live/rooms/${roomId}/bullets`)
        .set(auth(member))
        .send({ text: 'hello family', clientId: randomUUID() });
      expect(bullet.status).toBe(201);
      expect((await family(member, f.id)).points).toBe(515);
      // The first bullet earns BULLET_FIRST.
      expect(await medalsOf(member)).toEqual(['BULLET_FIRST', 'FIRST_FAMILY']);

      // Crossing a threshold raises the level (points set near it instead of 33 more bullets).
      await ctx.prisma.family.update({ where: { id: f.id }, data: { points: 990n } });
      clock.advance(6);
      const second = await ctx.http
        .post(`/api/v1/live/rooms/${roomId}/bullets`)
        .set(auth(member))
        .send({ text: 'level up', clientId: randomUUID() });
      expect(second.status).toBe(201);
      expect(await family(member, f.id)).toMatchObject({ points: 1005, level: 2 });
      const entries = await ctx.prisma.familyPointsEntry.findMany({
        where: { familyId: f.id },
        orderBy: { createdAt: 'asc' },
      });
      expect(entries.map((e) => [e.userId, Number(e.points)])).toEqual([
        [leader.id, 500],
        [member.id, 15],
        [member.id, 15],
      ]);
      // A spender who is not in a family adds nothing anywhere; leaving keeps the points.
      expect((await ctx.http.post(`/api/v1/families/${f.id}/leave`).set(auth(member))).status).toBe(204);
      clock.advance(6);
      await ctx.http
        .post(`/api/v1/live/rooms/${roomId}/bullets`)
        .set(auth(member))
        .send({ text: 'outside', clientId: randomUUID() })
        .expect(201);
      expect((await family(leader, f.id)).points).toBe(1005);
      await ctx.http.post(`/api/v1/live/rooms/${roomId}/end`).set(auth(host)).expect(200);
    });
  });

  // ---- CP couples -------------------------------------------------------------------------------

  describe('CP couples', () => {
    const send = (from: TestUser, to: TestUser, clientId: string = randomUUID()) =>
      ctx.http.post('/api/v1/cp/requests').set(auth(from)).send({ username: to.username, clientId });
    const myCp = async (u: TestUser, lang = 'en') => {
      const res = await ctx.http.get('/api/v1/cp/me').set(auth(u)).set('Accept-Language', lang);
      expect(res.status).toBe(200);
      expectContract(res, 'getMyCp');
      return res.body.cp as {
        partner: { username: string };
        points: number;
        level: number;
        levelName: string;
        nextLevelName: string | null;
        pointsToNext: number | null;
        days: number;
      } | null;
    };
    const gift = (u: TestUser, amount: number, clientId: string = randomUUID()) =>
      ctx.http
        .post('/api/v1/cp/me/gifts')
        .set(auth(u))
        .set('Accept-Language', 'en')
        .send({ amount, clientId });

    it('a request costs 99 coins and is refunded when declined, cancelled or expired', async () => {
      const [a, b, c] = [await signup(), await signup(), await signup()];
      await grant(a, 150);
      const clientId = randomUUID();
      const sent = await send(a, b, clientId);
      expect(sent.status).toBe(201);
      expectContract(sent, 'sendCpRequest');
      expect(sent.body).toMatchObject({
        coins: 51,
        request: { status: 'PENDING', cost: 99, receiver: { username: b.username } },
      });
      const retry = await send(a, b, clientId);
      expect(retry.status).toBe(200);
      expect(retry.body.request.id).toBe(sent.body.request.id);
      expect(await coins(a)).toBe(51);
      expect((await send(a, c)).body.error.code).toBe('CP_REQUEST_PENDING');
      expect((await notifications(b)).find((n) => n.type === 'CP_REQUEST')).toMatchObject({
        actors: [{ username: a.username }],
        target: { type: 'USER', id: a.username },
      });
      const incoming = await ctx.http
        .get('/api/v1/cp/requests')
        .query({ direction: 'incoming' })
        .set(auth(b));
      expect(incoming.status).toBe(200);
      expectContract(incoming, 'listCpRequests');
      expect(incoming.body.data.map((r: { id: string }) => r.id)).toEqual([sent.body.request.id]);

      // Declined → refunded.
      const declined = await ctx.http
        .post(`/api/v1/cp/requests/${sent.body.request.id as string}/decline`)
        .set(auth(b));
      expect(declined.status).toBe(204);
      expect(await coins(a)).toBe(150);
      expect(
        (await ctx.http.post(`/api/v1/cp/requests/${sent.body.request.id as string}/accept`).set(auth(b)))
          .body.error.code,
      ).toBe('CP_REQUEST_NOT_PENDING');

      // Cancelled → refunded.
      const second = await send(a, b);
      expect(await coins(a)).toBe(51);
      expect(
        (await ctx.http.delete(`/api/v1/cp/requests/${second.body.request.id as string}`).set(auth(b)))
          .status,
      ).toBe(404);
      expect(
        (await ctx.http.delete(`/api/v1/cp/requests/${second.body.request.id as string}`).set(auth(a)))
          .status,
      ).toBe(204);
      expect(await coins(a)).toBe(150);

      // Expired after 7 days → refunded by the sweeper.
      const third = await send(a, b);
      expect(await coins(a)).toBe(51);
      clock.advance(7 * DAY + 1);
      expect(await ctx.app.get(CouplesService).sweepExpired()).toBeGreaterThanOrEqual(1);
      expect(await coins(a)).toBe(150);
      expect(
        (await ctx.prisma.cpRequest.findUniqueOrThrow({ where: { id: third.body.request.id as string } }))
          .status,
      ).toBe('EXPIRED');
      const reasons = (await ledger(a)).map((r) => [r.reason, Number(r.delta)]);
      expect(reasons.filter((r) => r[0] !== 'ADMIN_GRANT')).toEqual([
        ['CP_REQUEST', -99],
        ['CP_REFUND', 99],
        ['CP_REQUEST', -99],
        ['CP_REFUND', 99],
        ['CP_REQUEST', -99],
        ['CP_REFUND', 99],
      ]);

      // Short balance: nothing is created or charged.
      const poor = await signup();
      await grant(poor, 98);
      expect((await send(poor, c)).body.error.code).toBe('INSUFFICIENT_COINS');
      expect(await ctx.prisma.cpRequest.count({ where: { senderId: poor.id } })).toBe(0);
      expect(await coins(poor)).toBe(98);
    });

    it('accepting forms the couple; one partner each; gifts raise points and tier; ending', async () => {
      const [a, b, c, d] = [await signup(), await signup(), await signup(), await signup()];
      await grant(a, 5000);
      await grant(c, 200);
      await grant(d, 200);
      const leader = await signup();
      const f = await newFamily(leader, 'Doves');
      await join(leader, a, f.id);

      const sent = await send(a, b);
      // Other pending requests of either partner are closed and refunded when the couple forms.
      const fromC = await send(c, b);
      expect(fromC.status).toBe(201);
      const accepted = await ctx.http
        .post(`/api/v1/cp/requests/${sent.body.request.id as string}/accept`)
        .set(auth(b))
        .set('Accept-Language', 'ar');
      expect(accepted.status).toBe(200);
      expectContract(accepted, 'acceptCpRequest');
      expect(accepted.body).toMatchObject({
        partner: { username: a.username },
        points: 0,
        level: 1,
        levelName: 'ثنائي متحمّس',
        days: 1,
      });
      expect(await coins(c)).toBe(200);
      expect(
        (await ctx.prisma.cpRequest.findUniqueOrThrow({ where: { id: fromC.body.request.id as string } }))
          .status,
      ).toBe('CANCELLED');
      expect((await notifications(a)).find((n) => n.type === 'CP_ACCEPTED')).toMatchObject({
        actors: [{ username: b.username }],
      });
      expect(await medalsOf(a)).toContain('FIRST_CP');
      expect(await medalsOf(b)).toContain('FIRST_CP');
      // The accepted request's 99 coins count for the sender's family.
      expect((await family(a, f.id)).points).toBe(599);

      // One partner each.
      expect((await send(d, a)).body.error.code).toBe('CP_ALREADY_PAIRED');
      expect((await send(a, d)).body.error.code).toBe('CP_ALREADY_PAIRED');

      // Gifts: preset amounts only, CP points = coins, tiers by points, idempotent.
      expect((await gift(a, 7)).status).toBe(400);
      const clientId = randomUUID();
      const g1 = await gift(a, 520, clientId);
      expect(g1.status).toBe(201);
      expectContract(g1, 'sendCpGift');
      expect(g1.body).toMatchObject({
        gift: { amount: 520 },
        coins: 5000 - 99 - 520,
        cp: {
          points: 520,
          level: 2,
          levelName: 'Silver couple',
          nextLevelName: 'Gold couple',
          pointsToNext: 794,
        },
      });
      const g1retry = await gift(a, 520, clientId);
      expect(g1retry.status).toBe(200);
      expect(g1retry.body.gift.id).toBe(g1.body.gift.id);
      expect(await coins(a)).toBe(5000 - 99 - 520);
      expect((await gift(b, 1314)).body.error.code).toBe('INSUFFICIENT_COINS');
      await gift(a, 1314).expect(201);
      expect(await myCp(b, 'ar')).toMatchObject({
        points: 1834,
        level: 3,
        levelName: 'ثنائي ذهبي',
        partner: { username: a.username },
      });
      expect((await family(a, f.id)).points).toBe(599 + 520 + 1314);
      const config = await ctx.http.get('/api/v1/cp/config').set(auth(a)).set('Accept-Language', 'en');
      expectContract(config, 'getCpConfig');
      expect(config.body).toMatchObject({ requestCost: 99, giftAmounts: [10, 52, 99, 520, 1314] });

      // The couple on both profiles.
      expect((await profile(c, a)).cp).toMatchObject({
        partner: { username: b.username },
        level: 3,
        levelName: 'Gold couple',
        points: 1834,
      });
      expect((await profile(c, b, 'ar')).cp?.levelName).toBe('ثنائي ذهبي');

      // Ending: no refund; gifts then need a partner.
      expect((await ctx.http.delete('/api/v1/cp/me').set(auth(b))).status).toBe(204);
      expect(await myCp(a)).toBeNull();
      expect((await gift(a, 10)).body.error.code).toBe('CP_NOT_PAIRED');
      expect((await profile(c, a)).cp).toBeNull();
      expect((await ctx.http.delete('/api/v1/cp/me').set(auth(b))).status).toBe(204);
    });

    it('blocked users cannot send each other CP requests', async () => {
      const [x, y] = [await signup(), await signup()];
      await grant(y, 200);
      await ctx.http.put(`/api/v1/users/${y.username}/block`).set(auth(x)).expect(200);
      const res = await send(y, x);
      expect(res.status).toBe(404);
      expect(await coins(y)).toBe(200);
      expect((await send(x, y)).status).toBe(404);
    });
  });

  // ---- Medals -----------------------------------------------------------------------------------

  describe('medals', () => {
    const goLive = async (u: TestUser): Promise<string> => {
      const res = await ctx.http.post('/api/v1/live/rooms').set(auth(u)).send({ title: 'Medals' });
      expect(res.status, JSON.stringify(res.body)).toBe(201);
      return res.body.id as string;
    };
    const host = async () => {
      const u = await signup();
      await ctx.prisma.liveHost.create({ data: { userId: u.id, source: 'ADMIN' } });
      return u;
    };

    it('ending a live awards FIRST_LIVE and live hours once; catalogue and user lists', async () => {
      const h = await host();
      const first = await goLive(h);
      await ctx.prisma.liveRoom.update({
        where: { id: first },
        data: { startedAt: new Date(clock.now().getTime() - 11 * 3600_000) },
      });
      await ctx.http.post(`/api/v1/live/rooms/${first}/end`).set(auth(h)).expect(200);
      expect(await medalsOf(h)).toEqual(['FIRST_LIVE', 'LIVE_HOURS_10']);
      const second = await goLive(h);
      await ctx.http.post(`/api/v1/live/rooms/${second}/end`).set(auth(h)).expect(200);
      expect(await medalsOf(h)).toEqual(['FIRST_LIVE', 'LIVE_HOURS_10']);
      const awarded = (await notifications(h)).filter((n) => n.type === 'MEDAL_AWARDED');
      expect(awarded.map((n) => n.target?.id).sort()).toEqual(['FIRST_LIVE', 'LIVE_HOURS_10']);

      const catalogue = await ctx.http.get('/api/v1/medals').set(auth(h)).set('Accept-Language', 'ar');
      expect(catalogue.status).toBe(200);
      expectContract(catalogue, 'listMedals');
      expect(catalogue.body.total).toBe(MEDAL_CATALOGUE.length);
      expect(catalogue.body.owned).toBe(2);
      expect(catalogue.body.data[0]).toMatchObject({
        code: 'FIRST_LIVE',
        name: 'أول لايف',
        iconKey: 'medal_first_live',
      });
      expect(catalogue.body.data[0].awardedAt).not.toBeNull();
      expect(catalogue.body.data[3].awardedAt).toBeNull();

      const reader = await signup();
      const list = await ctx.http
        .get(`/api/v1/users/${h.username}/medals`)
        .set(auth(reader))
        .set('Accept-Language', 'en');
      expect(list.status).toBe(200);
      expectContract(list, 'listUserMedals');
      expect(list.body).toMatchObject({ owned: 2, total: MEDAL_CATALOGUE.length });
      expect(list.body.data[0].name).toBeDefined();
      expect((await ctx.http.get('/api/v1/users/nobody.here.x/medals').set(auth(reader))).status).toBe(404);
      const p = await profile(reader, h);
      expect(p.medals).toMatchObject({ owned: 2, total: MEDAL_CATALOGUE.length, showcase: [] });
      expect(p.medals.latest.map((m) => m.code).sort()).toEqual(['FIRST_LIVE', 'LIVE_HOURS_10']);
    });

    it('reaching charm level 10 awards CHARM_10', async () => {
      const category = await ctx.prisma.levelCategory.create({
        data: {
          code: 'ATTRACTIVENESS',
          nameAr: 'الجاذبية',
          nameEn: 'Charm',
          descriptionAr: 'وصف',
          descriptionEn: 'About',
        },
      });
      const version = await ctx.prisma.levelCategoryVersion.create({
        data: {
          categoryId: category.id,
          versionNumber: 1,
          status: 'PUBLISHED',
          multiplier: '0.1',
          valueUnit: 'COIN',
          publishedAt: clock.now(),
          levels: {
            create: Array.from({ length: 10 }, (_, i) => ({
              levelNumber: i + 1,
              nameAr: 'مستوى',
              nameEn: 'Level',
              requiredPoints: BigInt(i),
            })),
          },
        },
      });
      await ctx.prisma.levelCategory.update({
        where: { id: category.id },
        data: { isEnabled: true, publishedVersionId: version.id },
      });
      const [h, viewer] = [await host(), await signup()];
      const roomId = await goLive(h);
      for (let i = 0; i < 9; i++) {
        clock.advance(5);
        await ctx.http
          .post(`/api/v1/live/rooms/${roomId}/taps`)
          .set(auth(viewer))
          .send({ count: 10 })
          .expect(200);
      }
      expect(await medalsOf(h)).toEqual(['CHARM_10']);
      await ctx.http.post(`/api/v1/live/rooms/${roomId}/end`).set(auth(h)).expect(200);
    });

    it('the profile showcase: up to 6 unlocked medals, in order', async () => {
      const u = await signup();
      const reader = await signup();
      await ctx.prisma.userMedal.createMany({
        data: [
          'FIRST_LIVE',
          'FIRST_CP',
          'FIRST_FAMILY',
          'BULLET_FIRST',
          'CHARM_10',
          'CHARM_50',
          'CHARM_100',
        ].map((medalCode) => ({
          userId: u.id,
          medalCode,
        })),
      });
      const put = (medalCodes: unknown) =>
        ctx.http
          .put('/api/v1/me/medals/showcase')
          .set(auth(u))
          .set('Accept-Language', 'en')
          .send({ medalCodes });

      const tooMany = await put([
        'FIRST_LIVE',
        'FIRST_CP',
        'FIRST_FAMILY',
        'BULLET_FIRST',
        'CHARM_10',
        'CHARM_50',
        'CHARM_100',
      ]);
      expect(tooMany.status).toBe(400);
      expectContract(tooMany, 'setMyMedalShowcase');
      expect(tooMany.body.error.details).toEqual([{ field: 'medalCodes', issue: 'too_big' }]);
      expect((await put(['FIRST_CP', 'FIRST_CP'])).status).toBe(400);
      const locked = await put(['FIRST_CP', 'LIVE_HOURS_100']);
      expect(locked.status).toBe(409);
      expect(locked.body.error.code).toBe('MEDAL_NOT_UNLOCKED');
      expect((await put(['NO_SUCH_MEDAL'])).body.error.code).toBe('MEDAL_NOT_UNLOCKED');

      const ok = await put(['CHARM_100', 'FIRST_CP', 'FIRST_LIVE']);
      expect(ok.status).toBe(200);
      expectContract(ok, 'setMyMedalShowcase');
      expect(ok.body.showcase.map((m: { code: string }) => m.code)).toEqual([
        'CHARM_100',
        'FIRST_CP',
        'FIRST_LIVE',
      ]);
      expect((await profile(reader, u)).medals.showcase.map((m) => m.code)).toEqual([
        'CHARM_100',
        'FIRST_CP',
        'FIRST_LIVE',
      ]);
      // A refused change keeps the old showcase; a new order replaces it.
      await put(['FIRST_CP', 'LIVE_HOURS_100']);
      const reordered = await put(['FIRST_LIVE', 'CHARM_100']);
      expect(reordered.body.showcase.map((m: { code: string }) => m.code)).toEqual([
        'FIRST_LIVE',
        'CHARM_100',
      ]);
      const mine = await ctx.http.get('/api/v1/me/medals/showcase').set(auth(u));
      expectContract(mine, 'getMyMedalShowcase');
      expect(mine.body.showcase.map((m: { code: string }) => m.code)).toEqual(['FIRST_LIVE', 'CHARM_100']);
      const cleared = await put([]);
      expect(cleared.body).toEqual({ showcase: [] });
      expect((await profile(reader, u)).medals.showcase).toEqual([]);
    });

    it('medals-admin backfill awards past events once (child process, migration role)', async () => {
      const usersWithMedals = await ctx.prisma.userMedal.findMany({
        select: { userId: true, medalCode: true },
      });
      await ctx.prisma.userMedal.deleteMany({});
      const run = medalsAdmin('backfill');
      expect(run.status, run.out).toBe(0);
      const restored = await ctx.prisma.userMedal.findMany({ select: { userId: true, medalCode: true } });
      const key = (m: { userId: string; medalCode: string }) => `${m.userId}:${m.medalCode}`;
      // Medals earned by events come back (the showcase test's hand-made rows are not events).
      for (const m of restored) expect(usersWithMedals.map(key)).toContain(key(m));
      expect(restored.some((m) => m.medalCode === 'FIRST_LIVE')).toBe(true);
      expect(restored.some((m) => m.medalCode === 'LIVE_HOURS_10')).toBe(true);
      expect(restored.some((m) => m.medalCode === 'FIRST_FAMILY')).toBe(true);
      expect(restored.some((m) => m.medalCode === 'FIRST_CP')).toBe(true);
      expect(restored.some((m) => m.medalCode === 'BULLET_FIRST')).toBe(true);
      expect(restored.some((m) => m.medalCode === 'CHARM_10')).toBe(true);
      expect(run.out).toMatch(/^Awarded \d+ medals/);
      const again = medalsAdmin('backfill');
      expect(again).toEqual({ status: 0, out: 'Awarded 0 medals.\n' });
      expect(await ctx.prisma.auditLog.count({ where: { action: 'medals.backfill' } })).toBe(2);
      expect(medalsAdmin('nope').status).toBe(1);
    });
  });
});
