/**
 * KL-085 / CP-022 (D116, owner 2026-10-26: "the look + the missing basics"): families v2 (openapi
 * v1.25-live DRAFT, CONVENTIONS §10.25, §10.21, §11.1, §11.7, §4, §7), end to end against
 * PostgreSQL + Redis with the API as the DML-only runtime role: the family boards (prestige this
 * month, most active this week) and a family's standing, members by points with a search and this
 * month's points, contributions, presence with the privacy switch and blocks, the cover and the
 * tagline, the join requests count, and the family chat (members only, retry, text rules, blocked
 * words, delete and mute rules, blocks, reports, rate limit).
 *
 * Coins are granted straight through the ledger (`creditIn`, as `wallet-admin` does); family points
 * come from real wallet debits (`WalletService.debitIn`, as a bullet message). Family points rows
 * carry the database time, so "last month" is made by moving a row back with the migration role.
 * Presence follows a FakeClock.
 */
import { randomUUID } from 'node:crypto';
import sharp from 'sharp';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { Clock } from '../src/common/time/clock.js';
import { uuidv7 } from '../src/modules/levels/uuidv7.js';
import { OBJECT_STORAGE } from '../src/modules/media/object-storage.js';
import { creditIn } from '../src/modules/wallet/wallet-ledger.js';
import { WalletService } from '../src/modules/wallet/wallet.service.js';
import { MemoryObjectStorage } from './helpers/memory-storage.js';
import { expectContract, operations } from './helpers/openapi.js';
import {
  createTestApp,
  registerVerified,
  settle,
  withMigrationClient,
  type TestContext,
} from './helpers/test-app.js';

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

interface Member {
  user: { username: string };
  role: string;
  points: number;
  monthPoints: number;
  presence: { online: boolean; lastActiveAt: string | null } | null;
  chatMuted: boolean | null;
  rank?: number;
}

const MEDIA_ON = {
  MEDIA_UPLOADS_ENABLED: 'true',
  S3_BUCKET: 'kabso-media-test',
  S3_ACCESS_KEY_ID: 'test',
  S3_SECRET_ACCESS_KEY: 'test',
  MEDIA_PUBLIC_BASE_URL: 'https://media.example.test',
};

describe('CP-022 contract coverage', () => {
  it('openapi declares the families v2 operations', () => {
    const ids = operations().map((o) => `${o.operationId} ${o.method.toUpperCase()} ${o.path}`);
    for (const op of [
      'listFamilyRankings GET /api/v1/families/rankings',
      'getFamilyStanding GET /api/v1/families/{familyId}/rankings',
      'listFamilyContributions GET /api/v1/families/{familyId}/contributions',
      'listFamilyChat GET /api/v1/families/{familyId}/chat',
      'sendFamilyChatMessage POST /api/v1/families/{familyId}/chat',
      'deleteFamilyChatMessage DELETE /api/v1/families/{familyId}/chat/{messageId}',
      'muteFamilyChatMember PUT /api/v1/families/{familyId}/chat/mutes/{username}',
      'unmuteFamilyChatMember DELETE /api/v1/families/{familyId}/chat/mutes/{username}',
    ]) {
      expect(ids).toContain(op);
    }
  });
});

describe('CP-022 families v2', { timeout: 180_000 }, () => {
  const clock = new FakeClock();
  let storage: MemoryObjectStorage;
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
  /** A real spend that counts for the spender's family (as a bullet message). */
  const spend = async (u: TestUser, coins: number) => {
    await grant(u, coins);
    const wallet = ctx.app.get(WalletService);
    const done = await ctx.prisma.$transaction((tx) =>
      wallet.debitIn(tx, u.id, coins, 'BULLET_MESSAGE', uuidv7()),
    );
    expect(done).not.toBeNull();
  };
  const newFamily = async (leader: TestUser, name: string): Promise<string> => {
    await grant(leader, 500);
    const res = await ctx.http
      .post('/api/v1/families')
      .set(auth(leader))
      .send({ name, clientId: randomUUID() });
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    return res.body.family.id as string;
  };
  const join = async (leader: TestUser, u: TestUser, familyId: string) => {
    const asked = await ctx.http.post(`/api/v1/families/${familyId}/join-requests`).set(auth(u));
    expect(asked.status).toBe(201);
    const ok = await ctx.http
      .post(`/api/v1/families/${familyId}/join-requests/${asked.body.id as string}/accept`)
      .set(auth(leader));
    expect(ok.status).toBe(200);
    expectContract(ok, 'acceptFamilyJoinRequest');
  };
  const family = async (u: TestUser, familyId: string) => {
    const res = await ctx.http.get(`/api/v1/families/${familyId}`).set(auth(u));
    expect(res.status).toBe(200);
    expectContract(res, 'getFamily');
    return res.body as {
      coverUrl: string | null;
      tagline: string | null;
      pendingRequestCount: number | null;
      myRole: string | null;
    };
  };
  const members = async (u: TestUser, familyId: string, query: Record<string, string> = {}) => {
    const res = await ctx.http.get(`/api/v1/families/${familyId}/members`).query(query).set(auth(u));
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    expectContract(res, 'listFamilyMembers');
    return res.body as { data: Member[]; page: { hasMore: boolean; nextCursor: string | null } };
  };
  const memberOf = async (reader: TestUser, familyId: string, u: TestUser): Promise<Member> => {
    const page = await members(reader, familyId, { limit: '50' });
    const found = page.data.find((m) => m.user.username === u.username);
    expect(found).toBeDefined();
    return found!;
  };
  const block = async (by: TestUser, u: TestUser) =>
    expect((await ctx.http.put(`/api/v1/users/${u.username}/block`).set(auth(by))).status).toBe(200);
  const upload = async (u: TestUser, kind: string, w = 1600, h = 900) => {
    const bytes = await sharp({
      create: { width: w, height: h, channels: 3, background: { r: 200, g: 140, b: 40 } },
    })
      .jpeg()
      .toBuffer();
    const slot = await ctx.http
      .post('/api/v1/media/uploads')
      .set(auth(u))
      .send({ kind, contentType: 'image/jpeg', byteSize: bytes.length });
    expect(slot.status, JSON.stringify(slot.body)).toBe(201);
    storage.upload(slot.body.uploadUrl, bytes, 'image/jpeg');
    const done = await ctx.http.post(`/api/v1/media/uploads/${slot.body.uploadId}/complete`).set(auth(u));
    expect(done.status).toBe(200);
    return done.body as { id: string; url: string; width: number; height: number };
  };
  /** Moves every family points row of `familyId` back into the previous month. */
  const lastMonth = (familyId: string) =>
    withMigrationClient((c) =>
      c.$executeRawUnsafe(
        `UPDATE family_points_ledger SET created_at = date_trunc('month', now()) - interval '1 day' WHERE family_id = $1::uuid`,
        familyId,
      ),
    );

  beforeAll(async () => {
    storage = new MemoryObjectStorage();
    ctx = await createTestApp(MEDIA_ON, [
      { token: Clock, value: clock },
      { token: OBJECT_STORAGE, value: storage },
    ]);
  });
  afterAll(async () => ctx?.close());

  // ---- Boards -----------------------------------------------------------------------------------

  describe('the family boards', () => {
    it('PRESTIGE ranks by points gained this month, pages, and shows the caller’s family', async () => {
      const [a, b, c, d, loner] = [
        await signup(),
        await signup(),
        await signup(),
        await signup(),
        await signup(),
      ];
      const fa = await newFamily(a, 'Alpha house'); // 500 this month (creation)
      const fb = await newFamily(b, 'Beta house');
      const fc = await newFamily(c, 'Gamma house');
      await spend(b, 300); // Beta 800
      await lastMonth(fc); // Gamma: 500 points, none this month
      await join(a, d, fa);
      await spend(d, 100); // Alpha 600

      const board = async (u: TestUser, query: Record<string, string> = {}) => {
        const res = await ctx.http.get('/api/v1/families/rankings').query(query).set(auth(u));
        expect(res.status, JSON.stringify(res.body)).toBe(200);
        expectContract(res, 'listFamilyRankings');
        return res.body as {
          board: string;
          startsAt: string;
          endsAt: string;
          data: { rank: number; family: { id: string; points: number }; score: number }[];
          page: { hasMore: boolean; nextCursor: string | null };
          me: { family: { id: string }; rank: number | null; score: number } | null;
        };
      };
      const all = await board(a);
      expect(all.board).toBe('PRESTIGE');
      expect(all.data.map((e) => [e.rank, e.family.id, e.score])).toEqual([
        [1, fb, 800],
        [2, fa, 600],
      ]);
      expect(new Date(all.startsAt).getTime()).toBeLessThanOrEqual(Date.now());
      expect(new Date(all.endsAt).getTime()).toBeGreaterThan(Date.now());
      expect(all.me).toMatchObject({ family: { id: fa }, rank: 2, score: 600 });
      // Gamma has points, none this month: not listed, rank null.
      expect((await board(c)).me).toMatchObject({ family: { id: fc }, rank: null, score: 0 });
      expect((await board(loner)).me).toBeNull();

      const first = await board(a, { limit: '1' });
      expect(first.data.map((e) => e.family.id)).toEqual([fb]);
      expect(first.page.hasMore).toBe(true);
      const second = await board(a, { limit: '1', cursor: first.page.nextCursor! });
      expect(second.data.map((e) => [e.rank, e.family.id])).toEqual([[2, fa]]);
      expect(second.page.hasMore).toBe(false);
      const bad = await ctx.http.get('/api/v1/families/rankings').query({ cursor: 'nope' }).set(auth(a));
      expect(bad.status).toBe(400);
      expect(
        (await ctx.http.get('/api/v1/families/rankings').query({ board: 'BATTLE' }).set(auth(a))).status,
      ).toBe(400);
      // An ACTIVE cursor is not a PRESTIGE cursor.
      await settle(ctx);
      const active = await board(a, { board: 'ACTIVE', limit: '1' });
      expect(active.page.nextCursor).not.toBeNull();
      const crossed = await ctx.http
        .get('/api/v1/families/rankings')
        .query({ cursor: active.page.nextCursor!, limit: '1' })
        .set(auth(a));
      expect(crossed.status).toBe(400);

      // Standing on both boards.
      const standing = await ctx.http.get(`/api/v1/families/${fa}/rankings`).set(auth(loner));
      expect(standing.status).toBe(200);
      expectContract(standing, 'getFamilyStanding');
      expect(standing.body).toMatchObject({ familyId: fa, prestige: { rank: 2, score: 600 } });
      const gamma = await ctx.http.get(`/api/v1/families/${fc}/rankings`).set(auth(loner));
      expect(gamma.body.prestige).toMatchObject({ rank: null, score: 0 });
      expect((await ctx.http.get(`/api/v1/families/${randomUUID()}/rankings`).set(auth(loner))).status).toBe(
        404,
      );
      expect((await ctx.http.get('/api/v1/families/nope/rankings').set(auth(loner))).status).toBe(404);
    });

    it('ACTIVE counts members active this week, without those who hide their activity', async () => {
      const [a, m1, m2, b] = [await signup(), await signup(), await signup(), await signup()];
      const fa = await newFamily(a, 'Busy house');
      const fb = await newFamily(b, 'Quiet house');
      await join(a, m1, fa);
      await join(a, m2, fa);
      await settle(ctx);
      const board = async () => {
        const res = await ctx.http.get('/api/v1/families/rankings').query({ board: 'ACTIVE' }).set(auth(a));
        expect(res.status).toBe(200);
        expectContract(res, 'listFamilyRankings');
        await settle(ctx);
        return res.body as {
          data: { family: { id: string }; score: number }[];
          me: { rank: number | null; score: number };
        };
      };
      const before = await board();
      const scoreOf = (body: { data: { family: { id: string }; score: number }[] }, id: string) =>
        body.data.find((e) => e.family.id === id)?.score;
      expect(scoreOf(before, fa)).toBe(3);
      expect(scoreOf(before, fb)).toBe(1);
      expect(before.me.score).toBe(3);

      const hide = await ctx.http
        .patch('/api/v1/me/privacy')
        .set(auth(m2))
        .send({ showActivityStatus: false });
      expect(hide.status).toBe(200);
      expectContract(hide, 'updatePrivacy');
      expect(hide.body.showActivityStatus).toBe(false);
      expect(scoreOf(await board(), fa)).toBe(2);
      // Someone never seen this week does not count.
      await withMigrationClient((c) =>
        c.$executeRawUnsafe(
          `UPDATE users SET last_active_at = now() - interval '30 days' WHERE id = $1::uuid`,
          b.id,
        ),
      );
      expect(scoreOf(await board(), fb)).toBeUndefined();
    });
  });

  // ---- Members, contributions, presence ---------------------------------------------------------

  describe('members, contributions and presence', () => {
    it('sorts members by points with ranks, searches, and counts this month’s points', async () => {
      const [lead, x, y, outsider] = [await signup(), await signup(), await signup(), await signup()];
      const fid = await newFamily(lead, 'Points house');
      await join(lead, x, fid);
      await join(lead, y, fid);
      await spend(x, 700);
      await spend(y, 50);
      // A row of last month for y: in `points`, not in `monthPoints`.
      await spend(y, 40);
      await withMigrationClient((c) =>
        c.$executeRawUnsafe(
          `UPDATE family_points_ledger SET created_at = date_trunc('month', now()) - interval '1 day'
            WHERE user_id = $1::uuid AND points = 40`,
          y.id,
        ),
      );
      await withMigrationClient((c) =>
        c.$executeRawUnsafe(
          `UPDATE family_members SET joined_at = date_trunc('month', now()) - interval '10 days' WHERE user_id = $1::uuid`,
          y.id,
        ),
      );

      const byRole = await members(outsider, fid);
      // By role, then join time (y's join was moved back above).
      expect(byRole.data.map((m) => m.user.username)).toEqual([lead.username, y.username, x.username]);
      expect(byRole.data.every((m) => m.rank === undefined)).toBe(true);

      const byPoints = await members(outsider, fid, { sort: 'POINTS' });
      expect(byPoints.data.map((m) => [m.rank, m.user.username, m.points, m.monthPoints])).toEqual([
        [1, x.username, 700, 700],
        [2, lead.username, 500, 500],
        [3, y.username, 90, 50],
      ]);
      const paged = await members(outsider, fid, { sort: 'POINTS', limit: '2' });
      const rest = await members(outsider, fid, {
        sort: 'POINTS',
        limit: '2',
        cursor: paged.page.nextCursor!,
      });
      expect(rest.data.map((m) => [m.rank, m.user.username])).toEqual([[3, y.username]]);
      // A ROLE cursor is not a POINTS cursor.
      const rolePage = await members(outsider, fid, { limit: '1' });
      expect(
        (
          await ctx.http
            .get(`/api/v1/families/${fid}/members`)
            .query({ sort: 'POINTS', cursor: rolePage.page.nextCursor! })
            .set(auth(outsider))
        ).status,
      ).toBe(400);

      const found = await members(outsider, fid, { q: y.username.slice(-6).toUpperCase(), sort: 'POINTS' });
      expect(found.data.map((m) => [m.rank, m.user.username])).toEqual([[3, y.username]]);
      expect((await members(outsider, fid, { q: 'no-such-member-zz' })).data).toEqual([]);

      const contributions = await ctx.http.get(`/api/v1/families/${fid}/contributions`).set(auth(outsider));
      expect(contributions.status).toBe(200);
      expectContract(contributions, 'listFamilyContributions');
      expect(
        (
          contributions.body.data as {
            rank: number;
            user: { username: string };
            points: number;
            role: string;
          }[]
        ).map((c) => [c.rank, c.user.username, c.points, c.role]),
      ).toEqual([
        [1, x.username, 700, 'MEMBER'],
        [2, lead.username, 500, 'LEADER'],
        [3, y.username, 50, 'MEMBER'],
      ]);
      const one = await ctx.http
        .get(`/api/v1/families/${fid}/contributions`)
        .query({ limit: '1' })
        .set(auth(lead));
      const two = await ctx.http
        .get(`/api/v1/families/${fid}/contributions`)
        .query({ limit: '1', cursor: one.body.page.nextCursor as string })
        .set(auth(lead));
      expect(two.body.data[0]).toMatchObject({ rank: 2, user: { username: lead.username } });
      expect(
        (await ctx.http.get(`/api/v1/families/${randomUUID()}/contributions`).set(auth(lead))).status,
      ).toBe(404);
    });

    it('shows presence to members of the same family only, honours the privacy switch and blocks', async () => {
      const [lead, m, other, outsider] = [await signup(), await signup(), await signup(), await signup()];
      const fid = await newFamily(lead, 'Presence house');
      await join(lead, m, fid);
      await join(lead, other, fid);
      await settle(ctx);

      const seen = await memberOf(lead, fid, m);
      expect(seen.presence).toMatchObject({ online: true });
      expect(seen.presence!.lastActiveAt).not.toBeNull();
      // Someone outside the family sees nobody's presence.
      expect((await memberOf(outsider, fid, m)).presence).toBeNull();
      // The caller always sees their own.
      expect((await memberOf(m, fid, m)).presence).toMatchObject({ online: true });

      // Six minutes later without a request: last active, no longer online.
      clock.advance(6 * 60);
      const later = await memberOf(lead, fid, m);
      await settle(ctx);
      expect(later.presence).toMatchObject({ online: false, lastActiveAt: seen.presence!.lastActiveAt });

      // Privacy: hidden from others, still visible to oneself.
      const privacy = await ctx.http.get('/api/v1/me/privacy').set(auth(m));
      expect(privacy.status).toBe(200);
      expectContract(privacy, 'getPrivacy');
      expect(privacy.body.showActivityStatus).toBe(true);
      await ctx.http.patch('/api/v1/me/privacy').set(auth(m)).send({ showActivityStatus: false });
      await settle(ctx);
      expect((await memberOf(lead, fid, m)).presence).toBeNull();
      expect((await memberOf(m, fid, m)).presence).not.toBeNull();
      await ctx.http.patch('/api/v1/me/privacy').set(auth(m)).send({ showActivityStatus: true });
      expect((await memberOf(lead, fid, m)).presence).not.toBeNull();
      // A block either way hides it.
      await block(other, m);
      expect((await memberOf(other, fid, m)).presence).toBeNull();
      expect((await memberOf(m, fid, other)).presence).toBeNull();
      // chatMuted is for the leader and deputies only.
      expect((await memberOf(lead, fid, m)).chatMuted).toBe(false);
      expect((await memberOf(other, fid, m)).chatMuted).toBeNull();
    });
  });

  // ---- Cover, tagline, requests count ------------------------------------------------------------

  describe('cover, tagline and the requests count', () => {
    it('the leader sets and removes the cover and the tagline; others cannot', async () => {
      const [lead, m] = [await signup(), await signup()];
      const fid = await newFamily(lead, 'Cover house');
      await join(lead, m, fid);
      const patch = async (u: TestUser, body: object) => {
        const res = await ctx.http.patch(`/api/v1/families/${fid}`).set(auth(u)).send(body);
        expectContract(res, 'updateFamily');
        return res;
      };
      expect((await patch(lead, {})).status).toBe(400);
      expect((await patch(lead, { tagline: 'x'.repeat(61) })).status).toBe(400);
      expect((await patch(lead, { tagline: 'one\ntwo' })).status).toBe(400);
      expect((await patch(m, { tagline: 'nope' })).status).toBe(403);

      const tagged = await patch(lead, { tagline: '  عائلة عالمية · ترفيه · بث مباشر  ' });
      expect(tagged.status).toBe(200);
      expect(tagged.body.tagline).toBe('عائلة عالمية · ترفيه · بث مباشر');

      const cover = await upload(lead, 'FAMILY_COVER');
      expect(cover.width).toBe(1080);
      const emblemAsCover = await upload(lead, 'FAMILY_EMBLEM', 800, 800);
      expect((await patch(lead, { coverMediaId: emblemAsCover.id })).status).toBe(400);
      const covered = await patch(lead, { coverMediaId: cover.id });
      expect(covered.status).toBe(200);
      expect(covered.body.coverUrl).toBe(cover.url);
      expect(covered.body.tagline).toBe('عائلة عالمية · ترفيه · بث مباشر');
      expect((await family(m, fid)).coverUrl).toBe(cover.url);

      // Replacing it deletes the old asset.
      const next = await upload(lead, 'FAMILY_COVER');
      expect((await patch(lead, { coverMediaId: next.id })).body.coverUrl).toBe(next.url);
      expect(await ctx.prisma.mediaAsset.count({ where: { id: cover.id } })).toBe(0);

      const cleared = await patch(lead, { coverMediaId: null, tagline: '' });
      expect(cleared.body).toMatchObject({ coverUrl: null, tagline: null });
      expect(await ctx.prisma.mediaAsset.count({ where: { id: next.id } })).toBe(0);
    });

    it('pendingRequestCount is for the leader and deputies only', async () => {
      const [lead, deputy, m, asker, outsider] = [
        await signup(),
        await signup(),
        await signup(),
        await signup(),
        await signup(),
      ];
      const fid = await newFamily(lead, 'Requests house');
      await join(lead, deputy, fid);
      await join(lead, m, fid);
      expect(
        (
          await ctx.http
            .put(`/api/v1/families/${fid}/members/${deputy.username}/role`)
            .set(auth(lead))
            .send({ role: 'DEPUTY' })
        ).status,
      ).toBe(200);
      expect((await family(lead, fid)).pendingRequestCount).toBe(0);
      expect((await ctx.http.post(`/api/v1/families/${fid}/join-requests`).set(auth(asker))).status).toBe(
        201,
      );
      expect((await family(lead, fid)).pendingRequestCount).toBe(1);
      expect((await family(deputy, fid)).pendingRequestCount).toBe(1);
      expect((await family(m, fid)).pendingRequestCount).toBeNull();
      expect((await family(outsider, fid)).pendingRequestCount).toBeNull();
    });
  });

  // ---- Family chat ------------------------------------------------------------------------------

  describe('the family chat', () => {
    const send = (u: TestUser, familyId: string, body: object) =>
      ctx.http.post(`/api/v1/families/${familyId}/chat`).set(auth(u)).send(body);
    const page = async (u: TestUser, familyId: string, query: Record<string, string> = {}) => {
      const res = await ctx.http.get(`/api/v1/families/${familyId}/chat`).query(query).set(auth(u));
      expect(res.status, JSON.stringify(res.body)).toBe(200);
      expectContract(res, 'listFamilyChat');
      return res.body as {
        data: { id: string; text: string; author: { username: string }; authorRole: string | null }[];
        page: { hasMore: boolean; nextCursor: string | null };
        muted: boolean;
        canModerate: boolean;
      };
    };

    it('members only; retries, text rules, paging and the leader’s blocked words', async () => {
      const [lead, m, outsider] = [await signup(), await signup(), await signup()];
      const fid = await newFamily(lead, 'Chat house');
      await join(lead, m, fid);
      await ctx.prisma.liveHost.create({
        data: { userId: lead.id, source: 'ADMIN', blockedWords: ['secret'] },
      });

      expect((await ctx.http.get(`/api/v1/families/${fid}/chat`).set(auth(outsider))).status).toBe(403);
      const denied = await send(outsider, fid, { text: 'hi', clientId: randomUUID() });
      expect(denied.status).toBe(403);
      expectContract(denied, 'sendFamilyChatMessage');
      expect((await send(m, randomUUID(), { text: 'hi', clientId: randomUUID() })).status).toBe(404);
      expect((await send(m, fid, { text: '   ', clientId: randomUUID() })).status).toBe(400);
      expect((await send(m, fid, { text: 'a\nb', clientId: randomUUID() })).status).toBe(400);
      expect((await send(m, fid, { text: 'x'.repeat(201), clientId: randomUUID() })).status).toBe(400);
      expect((await send(m, fid, { text: 'hi', clientId: randomUUID(), extra: 1 })).status).toBe(400);

      const clientId = randomUUID();
      const first = await send(m, fid, { text: 'my secret plan', clientId });
      expect(first.status).toBe(201);
      expectContract(first, 'sendFamilyChatMessage');
      expect(first.body).toMatchObject({
        familyId: fid,
        text: 'my ****** plan',
        author: { username: m.username },
        authorRole: 'MEMBER',
      });
      const retry = await send(m, fid, { text: 'something else', clientId });
      expect(retry.status).toBe(200);
      expect(retry.body.id).toBe(first.body.id);
      clock.advance(1);
      for (const text of ['two', 'three']) {
        expect((await send(lead, fid, { text, clientId: randomUUID() })).status).toBe(201);
        clock.advance(1);
      }
      const newest = await page(m, fid, { limit: '2' });
      expect(newest.data.map((x) => x.text)).toEqual(['three', 'two']);
      expect(newest.data[0]!.authorRole).toBe('LEADER');
      expect(newest).toMatchObject({ muted: false, canModerate: false });
      const older = await page(m, fid, { limit: '2', cursor: newest.page.nextCursor! });
      expect(older.data.map((x) => x.text)).toEqual(['my ****** plan']);
      expect(older.page.hasMore).toBe(false);
      expect((await page(lead, fid)).canModerate).toBe(true);
    });

    it('delete and mute rules; blocks hide messages; reports', async () => {
      const [lead, d1, d2, m, other] = [
        await signup(),
        await signup(),
        await signup(),
        await signup(),
        await signup(),
      ];
      const fid = await newFamily(lead, 'Rules house');
      for (const u of [d1, d2, m, other]) await join(lead, u, fid);
      for (const u of [d1, d2]) {
        await ctx.http
          .put(`/api/v1/families/${fid}/members/${u.username}/role`)
          .set(auth(lead))
          .send({ role: 'DEPUTY' });
      }
      const say = async (u: TestUser, text: string) => {
        const res = await send(u, fid, { text, clientId: randomUUID() });
        expect(res.status).toBe(201);
        clock.advance(1);
        return res.body.id as string;
      };
      const del = (u: TestUser, id: string) =>
        ctx.http.delete(`/api/v1/families/${fid}/chat/${id}`).set(auth(u));
      const fromLead = await say(lead, 'lead says');
      const fromD2 = await say(d2, 'deputy says');
      const fromM = await say(m, 'member says');
      const fromOther = await say(other, 'other says');

      // A member deletes only their own; a deputy never the leader's or another deputy's.
      expect((await del(m, fromOther)).status).toBe(403);
      expect((await del(d1, fromLead)).status).toBe(403);
      expect((await del(d1, fromD2)).status).toBe(403);
      const gone = await del(d1, fromM);
      expect(gone.status).toBe(204);
      expectContract(gone, 'deleteFamilyChatMessage');
      expect((await del(m, fromM)).status).toBe(204); // already deleted
      expect((await del(lead, fromD2)).status).toBe(204);
      expect((await del(other, fromOther)).status).toBe(204);
      expect((await del(m, randomUUID())).status).toBe(404);
      expect((await page(m, fid)).data.map((x) => x.text)).toEqual(['lead says']);

      // Mutes.
      const mute = (by: TestUser, u: TestUser) =>
        ctx.http.put(`/api/v1/families/${fid}/chat/mutes/${u.username}`).set(auth(by));
      const unmute = (by: TestUser, u: TestUser) =>
        ctx.http.delete(`/api/v1/families/${fid}/chat/mutes/${u.username}`).set(auth(by));
      expect((await mute(m, other)).status).toBe(403);
      expect((await mute(d1, lead)).status).toBe(403);
      expect((await mute(d1, d2)).status).toBe(403);
      expect((await mute(d1, d1)).status).toBe(400);
      const outsider = await signup();
      expect((await mute(d1, outsider)).status).toBe(404);
      const muted = await mute(d1, m);
      expect(muted.status).toBe(204);
      expectContract(muted, 'muteFamilyChatMember');
      expect((await mute(d1, m)).status).toBe(204);
      const refused = await send(m, fid, { text: 'can I?', clientId: randomUUID() });
      expect(refused.status).toBe(403);
      expect(refused.body.error.code).toBe('FAMILY_CHAT_MUTED');
      expect((await page(m, fid)).muted).toBe(true);
      expect((await memberOf(lead, fid, m)).chatMuted).toBe(true);
      expect((await mute(lead, d2)).status).toBe(204); // the leader mutes a deputy
      const un = await unmute(lead, m);
      expect(un.status).toBe(204);
      expectContract(un, 'unmuteFamilyChatMember');
      expect((await send(m, fid, { text: 'back', clientId: randomUUID() })).status).toBe(201);
      clock.advance(1);

      // Blocks hide messages either way.
      const fromOther2 = await say(other, 'other again');
      await block(m, other);
      expect((await page(m, fid)).data.map((x) => x.text)).not.toContain('other again');
      expect((await page(other, fid)).data.map((x) => x.text)).not.toContain('back');
      expect((await page(lead, fid)).data.map((x) => x.text)).toContain('other again');

      // Reports: a member who can read it, not its author.
      const report = (u: TestUser, targetId: string) =>
        ctx.http
          .post('/api/v1/reports')
          .set(auth(u))
          .send({ targetType: 'FAMILY_CHAT_MESSAGE', targetId, reason: 'HARASSMENT' });
      expect((await report(other, fromOther2)).status).toBe(400);
      expect((await report(outsider, fromLead)).status).toBe(404);
      expect((await report(m, fromOther2)).status).toBe(404); // blocked: m cannot read it
      const filed = await report(d1, fromOther2);
      expect(filed.status).toBe(201);
      expectContract(filed, 'createReport');
      expect(filed.body).toMatchObject({ targetType: 'FAMILY_CHAT_MESSAGE', targetId: fromOther2 });
      expect((await report(d1, fromOther2)).status).toBe(200);

      const mod = await signup();
      await withMigrationClient(async (c) => {
        await c.user.update({ where: { id: mod.id }, data: { role: 'ADMIN' } });
        await c.userAdminPermission.create({ data: { userId: mod.id, permission: 'MODERATION' } });
      });
      const acted = await ctx.http
        .post(`/api/v1/admin/reports/${filed.body.id as string}/actions`)
        .set(auth(mod))
        .send({ action: 'REMOVE_TARGET' });
      expect(acted.status).toBe(200);
      expect(acted.body).toMatchObject({ status: 'ACTIONED', targetType: 'FAMILY_CHAT_MESSAGE' });
      expect((await page(lead, fid)).data.map((x) => x.text)).not.toContain('other again');
      const row = await ctx.prisma.familyChatMessage.findUniqueOrThrow({ where: { id: fromOther2 } });
      expect(row.deletedById).toBe(mod.id);

      // A member who left keeps their messages, without a role.
      expect((await ctx.http.post(`/api/v1/families/${fid}/leave`).set(auth(d1))).status).toBe(204);
      const after = await page(lead, fid);
      expect(after.data.find((x) => x.author.username === d1.username)).toBeUndefined();
      expect((await ctx.http.get(`/api/v1/families/${fid}/chat`).set(auth(d1))).status).toBe(403);
    });
  });
});

describe('CP-022 family chat rate limit', { timeout: 60_000 }, () => {
  let ctx: TestContext;
  beforeAll(async () => {
    ctx = await createTestApp({ RATE_LIMIT_FAMILY_CHAT_USER: '2/60' });
  });
  afterAll(async () => ctx?.close());

  it('30 a minute per user by default; here 2', async () => {
    const { res } = await registerVerified(ctx);
    const token = res.body.tokens.accessToken as string;
    const userId = res.body.user.id as string;
    await ctx.prisma.$transaction((tx) => creditIn(tx, userId, 500n, 'ADMIN_GRANT', uuidv7()));
    const created = await ctx.http
      .post('/api/v1/families')
      .set('Authorization', `Bearer ${token}`)
      .send({ name: 'Rate house', clientId: randomUUID() });
    const fid = created.body.family.id as string;
    const send = () =>
      ctx.http
        .post(`/api/v1/families/${fid}/chat`)
        .set('Authorization', `Bearer ${token}`)
        .send({ text: 'hi', clientId: randomUUID() });
    expect((await send()).status).toBe(201);
    expect((await send()).status).toBe(201);
    const limited = await send();
    expect(limited.status).toBe(429);
    expectContract(limited, 'sendFamilyChatMessage');
  });
});
