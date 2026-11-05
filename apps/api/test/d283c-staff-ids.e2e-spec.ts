/**
 * D283c (owner 2026-11-05, «ايدي للمشرفين والادارة بحيث ايدي الموظفين يبدأ Kabso01»; contract v1.73-live, CONVENTIONS
 * §10.96.12) and D283d (owner: «المالك… لا، kabso»; v1.74-live: the primary OWNER is plain «Kabso»), end to end against
 * PostgreSQL + Redis:
 *
 *  - a panel grant gives the next staff ID («Kabso01», «Kabso02», …) in its transaction — the OWNER too; another role
 *    keeps it; concurrent grants never duplicate nor skip a number;
 *  - a revoke hides it (kept, never reused); a re-grant shows the same one; a newcomer after that gets the next one;
 *  - `Me.staffId` / `Me.staff.staffId`, `PublicProfile.staffId`, `UserSummary.staffId` (search, live viewers); the
 *    username is unchanged (login, links);
 *  - search «Kabso01» finds the account; the panel's team list and user search show / find it; the panel grants by it;
 *  - normal users cannot register a username that looks like a staff ID (any case, look-alikes);
 *  - the migration's backfill numbers today's holders in the order of their first grant; the runtime role cannot write
 *    `staff_ids`.
 */
import { readFileSync } from 'node:fs';
import type request from 'supertest';
import { afterAll, beforeAll, describe, expect, it, vi } from 'vitest';
import { grantRoleIn, revokeRoleIn } from '../src/modules/admin-panel/admin-roles.js';
import { totpCode } from '../src/modules/admin-panel/totp.js';
import { LIVE_MEDIA_PROVIDER } from '../src/modules/live/media/live-media.provider.js';
import { LiveMediaService } from '../src/modules/live/live-media.service.js';
import { MemoryLiveMedia } from './helpers/memory-live-media.js';
import { expectContract } from './helpers/openapi.js';
import { createTestApp, newUser, withMigrationClient, type TestContext } from './helpers/test-app.js';

const COOKIE = '__Host-kabso_admin';
const MIGRATION = new URL('../prisma/migrations/20270317090000_staff_ids/migration.sql', import.meta.url);
const RENUMBER = new URL(
  '../prisma/migrations/20270318090000_staff_ids_owner/migration.sql',
  import.meta.url,
);

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

describe('D283c the official staff IDs «Kabso01»', { timeout: 900_000 }, () => {
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
  let ipCounter = 70;
  const nextIp = () => {
    ipCounter += 1;
    return `198.51.${Math.floor(ipCounter / 250)}.${(ipCounter % 250) + 1}`;
  };
  const auth = (u: { token: string }) => ({ Authorization: `Bearer ${u.token}` });

  const signup = async (over: Record<string, unknown> = {}): Promise<TestUser> => {
    const payload = newUser(over);
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
  /** The CLI's way (the migration role), like the first OWNER's bootstrap. */
  const grant = (p: TestUser, role: string) =>
    withMigrationClient((db) => db.$transaction((tx) => grantRoleIn(tx, p.email, role as never)));
  const revoke = (p: TestUser, role: string) =>
    withMigrationClient((db) => db.$transaction((tx) => revokeRoleIn(tx, p.email, role as never)));
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
  const aget = (a: Admin, path: string) => ctx.http.get(`/api/v1${path}`).set('Cookie', a.cookie);
  const apost = (a: Admin, path: string, body: object = {}) =>
    ctx.http.post(`/api/v1${path}`).set('Cookie', a.cookie).set('X-CSRF-Token', a.csrf).send(body);
  const me = async (u: TestUser) => {
    const res = await ctx.http.get('/api/v1/me').set(auth(u));
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    expectContract(res, 'getMe');
    return res.body as { username: string; staffId?: string; staff?: { staffId?: string } };
  };
  const profile = async (viewer: TestUser, of: TestUser) => {
    const res = await ctx.http.get(`/api/v1/users/${of.username}`).set(auth(viewer));
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    expectContract(res, 'getPublicProfile');
    return res.body as { username: string; staffId?: string; staff?: { staffId?: string } };
  };
  const searchUsers = async (viewer: TestUser, q: string) => {
    const res = await ctx.http.get('/api/v1/search').query({ type: 'users', q }).set(auth(viewer));
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    expectContract(res, 'search');
    return res.body.data as { id: string; username: string; staffId?: string }[];
  };
  const numbers = () =>
    withMigrationClient((db) =>
      db.$queryRawUnsafe<{ number: number; user_id: string | null }[]>(
        'SELECT number, user_id::text AS user_id FROM staff_ids ORDER BY number',
      ),
    );

  const media = new MemoryLiveMedia();
  let owner: TestUser;
  let ownerAdmin: Admin;
  let sara: TestUser;
  let omar: TestUser;
  let viewer: TestUser;

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
        RATE_LIMIT_SEARCH_USER: '10000/60',
        API_PUBLIC_URL: 'https://api.test.example',
      },
      [{ token: LIVE_MEDIA_PROVIDER, value: media }],
    );
    owner = await signup();
    sara = await signup();
    omar = await signup();
    viewer = await signup();
  });

  afterAll(async () => {
    vi.useRealTimers();
    await ctx?.close();
  });

  it('the primary OWNER is «Kabso»; the staff number from Kabso01; another role keeps the number', async () => {
    expect((await grant(owner, 'OWNER')).staffId).toBe('Kabso');
    expect((await grant(sara, 'SUPPORT')).staffId).toBe('Kabso01');
    expect((await grant(omar, 'MODERATION')).staffId).toBe('Kabso02');
    const again = await grant(sara, 'FINANCE');
    expect(again.staffId).toBe('Kabso01');
    expect(await numbers()).toEqual([
      { number: 0, user_id: owner.id },
      { number: 1, user_id: sara.id },
      { number: 2, user_id: omar.id },
    ]);
    // The audit row names it.
    const audit = await ctx.prisma.auditLog.findFirst({
      where: { action: 'admin.role.grant', targetId: omar.id },
      select: { metadata: true },
    });
    expect(audit?.metadata).toMatchObject({ role: 'MODERATION', staffId: 'Kabso02' });
  });

  it('Me, the public profile and summaries carry it; the username stays the login name', async () => {
    const mine = await me(sara);
    expect(mine.staffId).toBe('Kabso01');
    expect(mine.staff?.staffId).toBe('Kabso01');
    expect(mine.username).toBe(sara.username);
    // The OWNER stays a normal account (no `staff`), but shows the staff ID.
    const own = await me(owner);
    expect(own.staffId).toBe('Kabso');
    expect(own.staff).toBeUndefined();
    const p = await profile(viewer, omar);
    expect(p.staffId).toBe('Kabso02');
    expect(p.staff?.staffId).toBe('Kabso02');
    expect(p.username).toBe(omar.username);
    // A normal account has none.
    expect((await me(viewer)).staffId).toBeUndefined();
    expect((await profile(sara, viewer)).staffId).toBeUndefined();
    // Login with the real username still works.
    const login = await ctx.http
      .post('/api/v1/auth/login')
      .set('X-Forwarded-For', nextIp())
      .send({
        identifier: sara.username,
        password: sara.password,
        device: { name: 'Pixel 9', platform: 'android', appVersion: '1.0.0' },
      });
    expect(login.status, JSON.stringify(login.body)).toBe(200);
  });

  it('search «Kabso01» (any case) finds the staff member first, with the staff ID on the summary', async () => {
    for (const q of ['Kabso01', 'kabso01', 'KABSO1', '@Kabso01']) {
      const hits = await searchUsers(viewer, q);
      expect(hits[0]?.id, q).toBe(sara.id);
      expect(hits[0]?.staffId).toBe('Kabso01');
      expect(hits[0]?.username).toBe(sara.username);
    }
    expect(await searchUsers(viewer, 'Kabso76')).toEqual([]);
    // Found by the username too, still with the staff ID.
    const byName = await searchUsers(viewer, omar.username);
    expect(byName.find((h) => h.id === omar.id)?.staffId).toBe('Kabso02');
  });

  it('concurrent grants never duplicate nor skip a number (the panel path, the runtime role)', async () => {
    const people = await Promise.all(Array.from({ length: 8 }, () => signup()));
    const results = await Promise.all(
      people.map((p) => ctx.prisma.$transaction((tx) => grantRoleIn(tx, p.email, 'SUPPORT'))),
    );
    const given = results.map((r) => r.staffId).sort();
    expect(new Set(given).size).toBe(8);
    expect(given).toEqual([
      'Kabso03',
      'Kabso04',
      'Kabso05',
      'Kabso06',
      'Kabso07',
      'Kabso08',
      'Kabso09',
      'Kabso10',
    ]);
    expect((await numbers()).map((r) => r.number)).toEqual([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
    // Two grants of the same new person at once: one number.
    const twice = await signup();
    const both = await Promise.all(
      ['MODERATION', 'FINANCE'].map((role) =>
        ctx.prisma.$transaction((tx) => grantRoleIn(tx, twice.email, role as never)),
      ),
    );
    expect(both[0]!.staffId).toBe('Kabso11');
    expect(both[1]!.staffId).toBe('Kabso11');
    // A refused grant (a banned account) gives nothing away.
    const banned = await signup();
    await withMigrationClient((db) =>
      db.$executeRawUnsafe(`UPDATE users SET status = 'SUSPENDED' WHERE id = '${banned.id}'`),
    );
    await expect(grant(banned, 'SUPPORT')).rejects.toThrow(/SUSPENDED/);
    expect((await numbers()).length).toBe(12);
  });

  it('a revoke hides it (kept, never reused); a re-grant gives the same one back; a newcomer gets the next', async () => {
    await revoke(sara, 'SUPPORT');
    expect((await me(sara)).staffId).toBe('Kabso01'); // FINANCE still held
    await revoke(sara, 'FINANCE');
    const after = await me(sara);
    expect(after.staffId).toBeUndefined();
    expect(after.staff).toBeUndefined();
    expect((await profile(viewer, sara)).staffId).toBeUndefined();
    expect(await searchUsers(viewer, 'Kabso01')).toEqual([]);
    expect((await numbers()).find((r) => r.number === 1)?.user_id).toBe(sara.id);
    const newcomer = await signup();
    expect((await grant(newcomer, 'SUPPORT')).staffId).toBe('Kabso12');
    expect((await grant(sara, 'MODERATION')).staffId).toBe('Kabso01');
    expect((await me(sara)).staffId).toBe('Kabso01');
    // A suspended staff account does not show it.
    await withMigrationClient((db) =>
      db.$executeRawUnsafe(`UPDATE users SET status = 'SUSPENDED' WHERE id = '${newcomer.id}'`),
    );
    expect(await searchUsers(viewer, 'Kabso12')).toEqual([]);
    await withMigrationClient((db) =>
      db.$executeRawUnsafe(`UPDATE users SET status = 'ACTIVE' WHERE id = '${newcomer.id}'`),
    );
  });

  it('D283d: a second OWNER gets the next number, never «Kabso»; «Kabso» finds the primary OWNER first', async () => {
    const second = await signup({ displayName: 'Second Owner' });
    expect((await grant(second, 'OWNER')).staffId).toBe('Kabso13');
    expect((await me(second)).staffId).toBe('Kabso13');
    const hits = await searchUsers(viewer, 'Kabso');
    expect(hits[0]?.id).toBe(owner.id);
    expect(hits[0]?.staffId).toBe('Kabso');
    expect((await searchUsers(viewer, '@kabso'))[0]?.id).toBe(owner.id);
    // Numbers are kept: a revoke and a re-grant give the second OWNER the same number back, never «Kabso».
    await revoke(second, 'OWNER');
    expect((await grant(second, 'OWNER')).staffId).toBe('Kabso13');
    await revoke(second, 'OWNER');
  });

  it('the panel: the team list shows it, the user search and a grant find a person by it', async () => {
    ownerAdmin = await panelSignIn(owner);
    const team = await aget(ownerAdmin, '/admin/team');
    expect(team.status, JSON.stringify(team.body)).toBe(200);
    expectContract(team, 'listAdminTeam');
    const rows = team.body.data as { id: string; staffId: string | null }[];
    expect(rows.find((r) => r.id === owner.id)?.staffId).toBe('Kabso');
    expect(rows.find((r) => r.id === omar.id)?.staffId).toBe('Kabso02');
    const found = await aget(ownerAdmin, '/admin/users?q=kabso02');
    expect(found.status, JSON.stringify(found.body)).toBe(200);
    expect((found.body.data as { id: string }[])[0]?.id).toBe(omar.id);
    // Revoke OMAR's role, then grant it back from the panel by his staff ID.
    await revoke(omar, 'MODERATION');
    const back = await apost(ownerAdmin, '/admin/team/grant', {
      account: 'Kabso02',
      role: 'SUPPORT',
      reason: 'back from leave',
      totpCode: nextCode(ownerAdmin.secret),
    });
    expect(back.status, JSON.stringify(back.body)).toBe(200);
    expectContract(back, 'grantAdminTeamRole');
    expect(back.body).toMatchObject({ userId: omar.id, staffId: 'Kabso02' });
  });

  it('live viewers and other summaries carry it', async () => {
    const host = await signup();
    await ctx.prisma.liveHost.create({ data: { userId: host.id, source: 'ADMIN' } });
    const room = await ctx.http.post('/api/v1/live/rooms').set(auth(host)).send({ title: 'On air' });
    expect(room.status, JSON.stringify(room.body)).toBe(201);
    const roomId = room.body.id as string;
    // FINANCE (not a watch role) joins as a normal viewer.
    const fin = await signup();
    await grant(fin, 'FINANCE');
    await ctx.app
      .get<LiveMediaService, { onJoined(r: string, i: string): Promise<void> }>(LiveMediaService)
      .onJoined(roomId, fin.id);
    const list = await ctx.http.get(`/api/v1/live/rooms/${roomId}/viewers`).set(auth(host));
    expect(list.status, JSON.stringify(list.body)).toBe(200);
    expectContract(list, 'listLiveRoomViewers');
    const finId = (await me(fin)).staffId;
    expect(finId).toMatch(/^Kabso\d{2,}$/);
    const row = (list.body.data as { user: { id: string; staffId?: string } | null }[]).find(
      (r) => r.user?.id === fin.id,
    );
    expect(row?.user?.staffId).toBe(finId);
    // The join broadcast's summary too.
    const joins = media.broadcastsOf(roomId, 'join');
    expect(joins.map((j) => (j.user as { id: string; staffId?: string }).staffId)).toContain(finId);
  });

  it('normal users cannot register or check out a staff-ID-like username (any case, look-alikes)', async () => {
    for (const username of ['kabso05', 'kabso100', 'kabs0o7', 'k4bso09', 'kabso_12']) {
      const avail = await ctx.http.get('/api/v1/users/username-availability').query({ username });
      expect(avail.status, JSON.stringify(avail.body)).toBe(200);
      expect(avail.body.available, username).toBe(false);
      const payload = newUser({ username });
      const res = await ctx.http.post('/api/v1/auth/register').set('X-Forwarded-For', nextIp()).send(payload);
      expect(res.status, `${username} ${JSON.stringify(res.body)}`).toBe(409);
      expect(res.body.error.code).toBe('USERNAME_TAKEN');
    }
    // D283d: «kabso» itself and its look-alikes (shorter than a new regular name, so registration refuses them anyway;
    // reserved for premium names and the panel's username change too — the unit tests cover isReservedUsername).
    for (const username of ['kabso', 'kabs0', 'k4b5o', 'ka.bs0']) {
      const avail = await ctx.http.get('/api/v1/users/username-availability').query({ username });
      expect(avail.status, JSON.stringify(avail.body)).toBe(200);
      expect(avail.body.available, username).toBe(false);
    }
  });

  it('the runtime role cannot write staff_ids; the backfill and the D283d renumber: primary OWNER «Kabso», then by first grant', async () => {
    await expect(
      ctx.prisma.$executeRawUnsafe(`INSERT INTO staff_ids (number, user_id) VALUES (999, '${viewer.id}')`),
    ).rejects.toThrow(/permission denied|42501/i);
    await expect(ctx.prisma.$executeRawUnsafe(`DELETE FROM staff_ids`)).rejects.toThrow(
      /permission denied|42501/i,
    );
    await expect(
      ctx.prisma.$executeRawUnsafe(`SELECT kabso_assign_staff_id('${viewer.id}'::uuid, true)`),
    ).rejects.toThrow(/permission denied|42501/i);
    // The backfill statement of the migration, on a database whose holders predate it.
    const sql = readFileSync(MIGRATION, 'utf8');
    const backfill =
      /INSERT INTO staff_ids \(number, user_id, assigned_at\)[\s\S]*?GROUP BY user_id\) AS holders;/.exec(
        sql,
      )?.[0];
    expect(backfill).toBeDefined();
    // D283d's renumber (the primary OWNER 0, the rest 1, 2, … in their order), statement by statement.
    const renumber = /CREATE TEMP TABLE staff_ids_renumber[\s\S]*?DROP TABLE staff_ids_renumber;/
      .exec(readFileSync(RENUMBER, 'utf8'))?.[0]
      .split(/;\s*\n/)
      .map((q) => q.trim().replace(/;$/, ''))
      .filter((q) => q.length > 0);
    expect(renumber).toHaveLength(4);
    const [a, b, c] = [await signup(), await signup(), await signup()];
    await withMigrationClient(async (db) => {
      await db.$executeRawUnsafe('DELETE FROM staff_ids');
      await db.$executeRawUnsafe('DELETE FROM user_admin_permissions');
      // c first (two roles: the earliest counts), then a, then b; a LEVELS_* permission alone gives none.
      const rows: [string, string, string][] = [
        [c.id, 'SUPPORT', '2026-01-01T00:00:00Z'],
        [c.id, 'FINANCE', '2026-03-01T00:00:00Z'],
        [a.id, 'OWNER', '2026-02-01T00:00:00Z'],
        [b.id, 'MODERATION', '2026-02-15T00:00:00Z'],
        [viewer.id, 'LEVELS_VIEW', '2025-01-01T00:00:00Z'],
      ];
      for (const [user, perm, at] of rows) {
        await db.$executeRawUnsafe(
          `INSERT INTO user_admin_permissions (user_id, permission, granted_at) VALUES ('${user}', '${perm}', '${at}')`,
        );
      }
      await db.$executeRawUnsafe(backfill!);
    });
    expect(await numbers()).toEqual([
      { number: 1, user_id: c.id },
      { number: 2, user_id: a.id },
      { number: 3, user_id: b.id },
    ]);
    // One connection (the temporary table), as the migration runs.
    await withMigrationClient((db) =>
      db.$transaction(async (tx) => {
        for (const q of renumber!) await tx.$executeRawUnsafe(q);
      }),
    );
    expect(await numbers()).toEqual([
      { number: 0, user_id: a.id },
      { number: 1, user_id: c.id },
      { number: 2, user_id: b.id },
    ]);
    // The next grant continues after it; another OWNER gets a number.
    expect((await grant(viewer, 'SUPPORT')).staffId).toBe('Kabso03');
    const d = await signup();
    expect((await grant(d, 'OWNER')).staffId).toBe('Kabso04');
  });
});
