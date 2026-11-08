/**
 * D291 (owner: «ما رأيك ان نصمم صفحة التي تعرض الميداليات بحيث يمكن ان يكون للميدالية ايضاً ليفيلات»; contract
 * v1.81-live DRAFT, CONVENTIONS §10.104): medal levels end to end against PostgreSQL + Redis, with the API as the
 * DML-only runtime role.
 *
 * - level-ups from real events (lives ended through the API: lives hosted and live hours), from the charm and bullet
 *   rules (their award functions in a real transaction), never lowered, notified (`NotificationTarget.medalLevel`)
 *   and audited (`medals.level_up`);
 * - the medals page's response (`GET /medals`: tab, levels, progress, worn position), the wear rules (≤ 5, owned
 *   only) and the level on other people's profiles and lists;
 * - `medals-admin backfill` (child process, migration role) raising medals held at level 1 after the migration;
 * - the panel: read with holders per level, the OWNER's edit with a reason and the code, its refusals, the audit.
 */
import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { randomUUID } from 'node:crypto';
import { fileURLToPath } from 'node:url';
import { afterAll, beforeAll, describe, expect, it, vi } from 'vitest';
import type { Prisma } from '../src/generated/prisma/client.js';
import { addGiftIn } from '../src/modules/gifts/gift-catalogue.js';
import { creditIn } from '../src/modules/wallet/wallet-ledger.js';
import { LIVE_MEDIA_PROVIDER } from '../src/modules/live/media/live-media.provider.js';
import {
  addGiftsSentIn,
  awardBulletMedalsIn,
  awardCharmMedalsIn,
  raiseMedalLevelsIn,
} from '../src/modules/medals/medal-awards.js';
import { MEDAL_CATALOGUE } from '../src/modules/medals/medals.catalogue.js';
import { panel, type Admin } from './helpers/admin-panel.js';
import { PRE_D313_RETIRED, seedMedalCatalogue } from './helpers/medals.js';
import { MemoryLiveMedia } from './helpers/memory-live-media.js';
import { expectContract, operations } from './helpers/openapi.js';
import {
  createTestApp,
  registerVerified,
  settle,
  withMigrationClient,
  type TestContext,
} from './helpers/test-app.js';

const ADMIN_KEY = 'admin-totp-test-key-0123456789-abcdefghijklmnop';

interface TestUser {
  readonly id: string;
  readonly username: string;
  readonly token: string;
}

interface MedalBody {
  code: string;
  category: string;
  level: number;
  maxLevel: number;
  levels: {
    level: number;
    threshold: number;
    name: string | null;
    iconUrl: string | null;
    iconAsset: string | null;
  }[];
  progress: { value: number; next: number | null };
  iconUrl: string | null;
  iconAsset: string | null;
  showcasePosition: number | null;
  awardedAt: string | null;
}

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

describe('D291 contract coverage', () => {
  it('openapi v1.81-live declares the panel medal operations', () => {
    const ids = operations().map((o) => `${o.operationId} ${o.method.toUpperCase()} ${o.path}`);
    expect(ids).toContain('listAdminMedals GET /api/v1/admin/medals');
    expect(ids).toContain('updateAdminMedal PUT /api/v1/admin/medals/{code}');
    expect(ids).toContain('listMedals GET /api/v1/medals');
  });
});

describe('D291 medal levels', { timeout: 240_000 }, () => {
  const media = new MemoryLiveMedia();
  let ctx: TestContext;
  const p = panel(() => ctx);
  let owner: Admin;

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
  const host = async (): Promise<TestUser> => {
    const u = await signup();
    await ctx.prisma.liveHost.create({ data: { userId: u.id, source: 'ADMIN' } });
    return u;
  };
  /** One live through the API, `hours` long (its start moved back), ended by the host. */
  const live = async (u: TestUser, hours = 0): Promise<void> => {
    const res = await ctx.http.post('/api/v1/live/rooms').set(auth(u)).send({ title: 'Levels' });
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    const id = res.body.id as string;
    if (hours > 0) {
      await ctx.prisma.liveRoom.update({
        where: { id },
        data: { startedAt: new Date(Date.now() - hours * 3600_000) },
      });
    }
    await ctx.http.post(`/api/v1/live/rooms/${id}/end`).set(auth(u)).expect(200);
  };
  const levels = async (u: TestUser): Promise<Record<string, number>> =>
    Object.fromEntries(
      (await ctx.prisma.userMedal.findMany({ where: { userId: u.id } })).map((m) => [m.medalCode, m.level]),
    );
  const catalogue = async (u: TestUser, lang = 'en'): Promise<Record<string, MedalBody>> => {
    const res = await ctx.http.get('/api/v1/medals').set(auth(u)).set('Accept-Language', lang);
    expect(res.status).toBe(200);
    expectContract(res, 'listMedals');
    return Object.fromEntries((res.body.data as MedalBody[]).map((m) => [m.code, m]));
  };
  const medalNotes = async (u: TestUser) => {
    await settle(ctx);
    const res = await ctx.http.get('/api/v1/notifications').set(auth(u));
    expect(res.status).toBe(200);
    expectContract(res, 'listNotifications');
    return (res.body.data as { type: string; target: { id: string; medalLevel?: number } | null }[])
      .filter((n) => n.type === 'MEDAL_AWARDED')
      .map((n) => `${n.target!.id}:${String(n.target!.medalLevel)}`)
      .sort();
  };
  const tx = <T>(fn: (t: Prisma.TransactionClient) => Promise<T>): Promise<T> => ctx.prisma.$transaction(fn);

  beforeAll(async () => {
    vi.useFakeTimers({ toFake: ['Date'], now: p.start() });
    ctx = await createTestApp(
      {
        LIVE_HOSTING_ENABLED: 'true',
        LIVE_HEARTBEAT_STALE_SECONDS: '3600',
        ADMIN_TOTP_KEY: ADMIN_KEY,
        ADMIN_SESSION_IDLE_SECONDS: '86400',
        ADMIN_SESSION_MAX_SECONDS: '604800',
        RATE_LIMIT_ADMIN_LOGIN_IP: '10000/900',
        RATE_LIMIT_ADMIN_IP: '10000/900',
      },
      [{ token: LIVE_MEDIA_PROVIDER, value: media }],
    );
    await seedMedalCatalogue(ctx.prisma, { keepFirsts: true });
    owner = await p.makeAdmin(['OWNER']);
  });
  afterAll(async () => {
    await ctx?.close();
    vi.useRealTimers();
  });

  it('lives raise FIRST_LIVE level by level, notified and audited; never lowered; live hours are retired (D291)', async () => {
    const h = await host();
    await live(h, 12);
    // LIVE_HOURS_10 / _100 are name-side icons now, not medals (owner D291): never awarded.
    expect(await levels(h)).toEqual({ FIRST_LIVE: 1 });
    // 9 more lives (10 ended): FIRST_LIVE 2.
    for (let i = 0; i < 8; i++) await live(h);
    await live(h, 100);
    expect(await levels(h)).toEqual({ FIRST_LIVE: 2 });
    expect(await medalNotes(h)).toEqual(['FIRST_LIVE:1', 'FIRST_LIVE:2']);
    const audit = await ctx.prisma.auditLog.findMany({
      where: { action: 'medals.level_up', targetId: h.id },
    });
    expect(audit.map((a) => a.metadata)).toEqual([
      expect.objectContaining({
        medalCode: 'FIRST_LIVE',
        from: 1,
        to: 2,
        metric: 'LIVES_HOSTED',
        value: 10,
        via: 'event',
      }),
    ]);
    expect(audit.every((a) => a.actorUserId === null && a.targetType === 'user')).toBe(true);
    const level1 = await ctx.prisma.userMedal.findUniqueOrThrow({
      where: { userId_medalCode: { userId: h.id, medalCode: 'FIRST_LIVE' } },
    });
    expect(level1.levelReachedAt.getTime()).toBeGreaterThanOrEqual(level1.awardedAt.getTime());

    // Raising a threshold above what was reached keeps the level (levels are never taken away).
    await ctx.prisma.medalLevel.update({
      where: { medalCode_level: { medalCode: 'FIRST_LIVE', level: 2 } },
      data: { threshold: 40n },
    });
    await live(h);
    expect((await levels(h)).FIRST_LIVE).toBe(2);
    await ctx.prisma.medalLevel.update({
      where: { medalCode_level: { medalCode: 'FIRST_LIVE', level: 2 } },
      data: { threshold: 10n },
    });
    // The same totals again change nothing (no second notification).
    expect((await medalNotes(h)).length).toBe(2);
  });

  it('charm is retired (no medal, no notification); bullet levels skip at once; a lower value changes nothing', async () => {
    const u = await signup();
    await tx((t) => awardCharmMedalsIn(t, u.id, 72));
    expect(await levels(u)).toEqual({});
    expect(await medalNotes(u)).toEqual([]);

    // Bullets: the count of the sender's bullet messages (here given as a value), straight to level 3.
    const s = await signup();
    await tx((t) => raiseMedalLevelsIn(t, 'BULLETS_SENT', [{ userId: s.id, value: 150 }]));
    expect(await levels(s)).toEqual({ BULLET_FIRST: 3 });
    const bulletAudit = await ctx.prisma.auditLog.findMany({
      where: { action: 'medals.level_up', targetId: s.id },
    });
    expect(bulletAudit.map((a) => a.metadata)).toEqual([
      expect.objectContaining({ medalCode: 'BULLET_FIRST', from: null, to: 3, value: 150 }),
    ]);
    await tx((t) => raiseMedalLevelsIn(t, 'BULLETS_SENT', [{ userId: s.id, value: 10 }]));
    expect(await levels(s)).toEqual({ BULLET_FIRST: 3 });
    // The bullet rule counts real rows: none here, so nothing changes.
    await tx((t) => awardBulletMedalsIn(t, s.id));
    expect(await levels(s)).toEqual({ BULLET_FIRST: 3 });
    // A 0/1 metric gives level 1 only.
    await tx((t) => raiseMedalLevelsIn(t, 'FAMILY_JOINED', [{ userId: s.id, value: 1 }]));
    expect(await levels(s)).toEqual({ BULLET_FIRST: 3, FIRST_FAMILY: 1 });
  });

  it('the medals page: tabs, levels, progress, worn positions; wear rules; levels on profiles and lists', async () => {
    const u = await signup();
    const reader = await signup();
    await tx((t) => raiseMedalLevelsIn(t, 'LIVES_HOSTED', [{ userId: u.id, value: 12 }]));
    await tx((t) => raiseMedalLevelsIn(t, 'BULLETS_SENT', [{ userId: u.id, value: 120 }]));
    await tx((t) => raiseMedalLevelsIn(t, 'CP_FORMED', [{ userId: u.id, value: 1 }]));
    // An old CHARM_10 row from before its retirement stays as history but is never shown.
    await ctx.prisma.userMedal.create({ data: { userId: u.id, medalCode: 'CHARM_10', level: 2 } });

    const before = await catalogue(u, 'ar');
    // Only the wearable medals (the five retired name-side icons are left out).
    expect(Object.keys(before).sort()).toEqual(
      MEDAL_CATALOGUE.filter((m) => !PRE_D313_RETIRED.has(m.code))
        .map((m) => m.code)
        .sort(),
    );
    const raw = await ctx.http.get('/api/v1/medals').set(auth(u));
    expect(raw.body).toMatchObject({ total: MEDAL_CATALOGUE.length - PRE_D313_RETIRED.size, owned: 3 });
    // The live count is computed from real rooms (none here): the progress reads 0, the level stays 2.
    expect(before.FIRST_LIVE).toMatchObject({
      category: 'ACTIVITY',
      metric: 'LIVES_HOSTED',
      level: 2,
      maxLevel: 5,
      progress: { value: 0, next: 50 },
      iconUrl: null,
      showcasePosition: null,
    });
    expect(before.FIRST_LIVE!.levels.map((l) => l.threshold)).toEqual([1, 10, 50, 100, 500]);
    expect(before.BULLET_FIRST).toMatchObject({ category: 'ACTIVITY', level: 3, maxLevel: 4 });
    // D300: a single-metric medal's progress has no requirements.
    expect(before.BULLET_FIRST!.progress).toEqual({ value: 0, next: 1000, requirements: [] });
    expect(before.FIRST_CP).toMatchObject({ level: 1, maxLevel: 1, progress: { value: 0, next: null } });
    expect(before.WEALTH_KINGS).toMatchObject({
      level: 0,
      awardedAt: null,
      progress: { value: 0, next: 50_000_000 },
    });

    // Wear: owned only, ≤ 5, the order kept; a retired code → 400; the page shows the positions.
    const put = (medalCodes: unknown) =>
      ctx.http
        .put('/api/v1/me/medals/showcase')
        .set(auth(u))
        .set('Accept-Language', 'en')
        .send({ medalCodes });
    const locked = await put(['FIRST_LIVE', 'WEALTH_KINGS']);
    expect(locked.status).toBe(409);
    expect(locked.body.error.code).toBe('MEDAL_NOT_UNLOCKED');
    const retired = await put(['FIRST_LIVE', 'CHARM_10']);
    expect(retired.status).toBe(400);
    expectContract(retired, 'setMyMedalShowcase');
    expect(retired.body.error.details).toEqual([{ field: 'medalCodes', issue: 'invalid_value' }]);
    const tooMany = await put(['FIRST_LIVE', 'BULLET_FIRST', 'FIRST_CP', 'a', 'b', 'c']);
    expect(tooMany.status).toBe(400);
    const worn = await put(['BULLET_FIRST', 'FIRST_LIVE']);
    expect(worn.status).toBe(200);
    expectContract(worn, 'setMyMedalShowcase');
    expect(worn.body.showcase).toEqual([
      {
        code: 'BULLET_FIRST',
        name: 'First bullet message',
        iconKey: 'medal_bullet_first',
        level: 3,
        iconUrl: null,
        iconAsset: null,
      },
      {
        code: 'FIRST_LIVE',
        name: 'First live',
        iconKey: 'medal_first_live',
        level: 2,
        iconUrl: null,
        iconAsset: null,
      },
    ]);
    const page = await catalogue(u);
    expect(page.BULLET_FIRST!.showcasePosition).toBe(1);
    expect(page.FIRST_LIVE!.showcasePosition).toBe(2);
    expect(page.FIRST_CP!.showcasePosition).toBeNull();

    // Somebody else's profile and list carry the level, never the retired row.
    const prof = await ctx.http
      .get(`/api/v1/users/${u.username}`)
      .set(auth(reader))
      .set('Accept-Language', 'en');
    expect(prof.status).toBe(200);
    expectContract(prof, 'getPublicProfile');
    expect(
      (prof.body.medals.showcase as { code: string; level: number }[]).map((m) => [m.code, m.level]),
    ).toEqual([
      ['BULLET_FIRST', 3],
      ['FIRST_LIVE', 2],
    ]);
    expect(prof.body.medals).toMatchObject({
      owned: 3,
      total: MEDAL_CATALOGUE.length - PRE_D313_RETIRED.size,
    });
    expect((prof.body.medals.latest as { code: string }[]).map((m) => m.code)).not.toContain('CHARM_10');
    const list = await ctx.http.get(`/api/v1/users/${u.username}/medals`).set(auth(reader));
    expect(list.status).toBe(200);
    expectContract(list, 'listUserMedals');
    const byCode = Object.fromEntries(
      (list.body.data as { code: string; level: number; maxLevel: number; category: string }[]).map((m) => [
        m.code,
        m,
      ]),
    );
    expect(Object.keys(byCode).sort()).toEqual(['BULLET_FIRST', 'FIRST_CP', 'FIRST_LIVE']);
    expect(byCode.FIRST_LIVE).toMatchObject({ level: 2, maxLevel: 5, category: 'ACTIVITY' });
    expect(byCode.FIRST_CP).toMatchObject({ level: 1, maxLevel: 1 });
    expect(await ctx.prisma.userMedal.count({ where: { userId: u.id, medalCode: 'CHARM_10' } })).toBe(1);
  });

  it('the retirement migration strips retired codes from showcases and renumbers the rest (rows kept)', async () => {
    const u = await signup();
    await ctx.prisma.medal.update({ where: { code: 'CHARM_10' }, data: { retired: false } });
    await ctx.prisma.userMedal.createMany({
      data: [
        { userId: u.id, medalCode: 'CHARM_10', showcasePosition: 1 },
        { userId: u.id, medalCode: 'FIRST_CP', showcasePosition: 2 },
        { userId: u.id, medalCode: 'FIRST_FAMILY', showcasePosition: 3 },
      ],
    });
    const sql = readFileSync(
      fileURLToPath(
        new URL('../prisma/migrations/20270325090300_medal_retire_name_icons/migration.sql', import.meta.url),
      ),
      'utf8',
    );
    // Everything after the column (already added on this database), statement by statement.
    const body = sql.slice(sql.indexOf('UPDATE "medals" SET "retired" = true'));
    // One transaction: one connection, so the migration's temporary table is seen by every statement.
    await withMigrationClient((db) =>
      db.$transaction(async (t) => {
        for (const stmt of body
          .split(/;\s*\n/)
          .map((x) => x.trim())
          .filter((x) => x.length > 0)) {
          await t.$executeRawUnsafe(stmt.replace(/^(--[^\n]*\n)+/, ''));
        }
      }),
    );
    const rows = await ctx.prisma.userMedal.findMany({
      where: { userId: u.id },
      orderBy: { medalCode: 'asc' },
    });
    expect(rows.map((r) => [r.medalCode, r.showcasePosition])).toEqual([
      ['CHARM_10', null],
      ['FIRST_CP', 1],
      ['FIRST_FAMILY', 2],
    ]);
    expect((await ctx.prisma.medal.findUniqueOrThrow({ where: { code: 'CHARM_10' } })).retired).toBe(true);
  });

  it('medals-admin backfill raises medals held at level 1 (after the migration) once; notify off by default', async () => {
    const h = await host();
    for (let i = 0; i < 9; i++) await live(h);
    await live(h, 30);
    // As right after the migration: every medal held at level 1, no notifications.
    await ctx.prisma.userMedal.updateMany({ where: { userId: h.id }, data: { level: 1 } });
    await ctx.prisma.notification.deleteMany({ where: { recipientId: h.id } });
    expect(await levels(h)).toEqual({ FIRST_LIVE: 1 });

    const run = medalsAdmin('backfill');
    expect(run.status, run.out).toBe(0);
    expect(run.out).toMatch(/^Awarded \d+ medals.*\nRaised \d+ medal levels \(.*FIRST_LIVE \d+/s);
    // 30 hours of lives: no LIVE_HOURS medal (retired, D291).
    expect(await levels(h)).toEqual({ FIRST_LIVE: 2 });
    expect(await medalNotes(h)).toEqual([]);
    const audit = await ctx.prisma.auditLog.findMany({
      where: { action: 'medals.level_up', targetId: h.id },
    });
    expect(audit.map((a) => a.metadata)).toEqual(
      expect.arrayContaining([
        expect.objectContaining({ medalCode: 'FIRST_LIVE', from: 1, to: 2, via: 'backfill' }),
      ]),
    );
    const summary = await ctx.prisma.auditLog.findFirst({
      where: { action: 'medals.backfill' },
      orderBy: { createdAt: 'desc' },
    });
    expect(summary!.metadata).toMatchObject({
      levelUps: expect.objectContaining({ FIRST_LIVE: expect.any(Number) }),
    });
    expect(medalsAdmin('backfill')).toEqual({
      status: 0,
      out: 'Awarded 0 medals.\nRaised 0 medal levels.\n',
    });
  });

  it('the panel: holders per level; only the OWNER edits with a reason and the code; refusals; audited', async () => {
    const got = await p.send(owner, 'get', '/admin/medals');
    expect(got.status, JSON.stringify(got.body)).toBe(200);
    expectContract(got, 'listAdminMedals');
    type AdminMedal = {
      code: string;
      category: string;
      metric: string | null;
      retired: boolean;
      holders: number;
      levels: { level: number; threshold: number; holders: number }[];
    };
    const medals = Object.fromEntries((got.body.data as AdminMedal[]).map((m) => [m.code, m]));
    expect(Object.keys(medals)).toEqual(MEDAL_CATALOGUE.map((m) => m.code));
    const held = await ctx.prisma.userMedal.groupBy({
      by: ['level'],
      where: { medalCode: 'FIRST_LIVE' },
      _count: { _all: true },
    });
    expect(medals.FIRST_LIVE!.holders).toBe(held.reduce((a, b) => a + b._count._all, 0));
    expect(medals.FIRST_LIVE!.levels.map((l) => [l.level, l.threshold, l.holders])).toEqual(
      [1, 10, 50, 100, 500].map((t, i) => [i + 1, t, held.find((h) => h.level === i + 1)?._count._all ?? 0]),
    );
    expect(medals.FIRST_FAMILY).toMatchObject({
      metric: 'FAMILY_JOINED',
      category: 'ACHIEVEMENT',
      retired: false,
    });
    // The retired name-side icons are listed read-only.
    for (const code of PRE_D313_RETIRED) expect(medals[code]!.retired, code).toBe(true);

    const support = await p.makeAdmin(['SUPPORT']);
    expect((await p.send(support, 'get', '/admin/medals')).status).toBe(200);
    const body = (levelsIn: object[], category = 'ACTIVITY', admin: Admin = owner) => ({
      category,
      levels: levelsIn,
      reason: 'owner D291',
      totpCode: p.nextCode(admin.secret),
    });
    const t = (...ts: number[]) => ts.map((threshold) => ({ threshold }));
    expect(
      (await p.send(support, 'put', '/admin/medals/BULLET_FIRST', body(t(1, 5), 'ACTIVITY', support))).status,
    ).toBe(403);
    const falling = await p.send(owner, 'put', '/admin/medals/BULLET_FIRST', body(t(1, 50, 20)));
    expect(falling.status).toBe(400);
    expectContract(falling, 'updateAdminMedal');
    const binary = await p.send(owner, 'put', '/admin/medals/FIRST_CP', body(t(1, 2), 'ACHIEVEMENT'));
    expect(binary.status).toBe(400);
    expect(binary.body.error.details).toEqual([{ field: 'levels', issue: 'invalid_value' }]);
    // FIRST_LIVE level 2 is held (the lives test): a list of 1 would take it away.
    const dropping = await p.send(owner, 'put', '/admin/medals/FIRST_LIVE', body(t(1), 'ACTIVITY'));
    expect(dropping.status).toBe(400);
    expect(dropping.body.error.details).toEqual([{ field: 'levels', issue: 'invalid_value' }]);
    // A retired code is not a medal to edit.
    const retiredEdit = await p.send(owner, 'put', '/admin/medals/CHARM_10', body(t(10), 'ACHIEVEMENT'));
    expect(retiredEdit.status).toBe(409);
    expect(retiredEdit.body.error.code).toBe('ADMIN_ACTION_REFUSED');
    expect((await p.send(owner, 'put', '/admin/medals/NOPE', body(t(1)))).status).toBe(404);
    const http = await p.send(owner, 'put', '/admin/medals/BULLET_FIRST', {
      ...body(t(1, 5)),
      levels: [{ threshold: 1, iconUrl: 'http://x.test/a.png' }],
    });
    expect(http.status).toBe(400);
    const badCode = await p.send(owner, 'put', '/admin/medals/BULLET_FIRST', {
      ...body(t(1, 5)),
      totpCode: '000000',
    });
    expect(badCode.status).not.toBe(200);

    // Lower BULLET_FIRST level 2 to 5, add a named level with art, and move it to the other tab.
    const saved = await p.send(
      owner,
      'put',
      '/admin/medals/BULLET_FIRST',
      body(
        [
          { threshold: 1 },
          { threshold: 5 },
          { threshold: 100 },
          {
            threshold: 1000,
            nameAr: 'نجم الرسائل',
            nameEn: 'Bullet star',
            iconUrl: 'https://cdn.k.test/m/b4.png',
          },
          { threshold: 5000 },
        ],
        'ACHIEVEMENT',
      ),
    );
    expect(saved.status, JSON.stringify(saved.body)).toBe(200);
    expectContract(saved, 'updateAdminMedal');
    expect(saved.body).toMatchObject({ code: 'BULLET_FIRST', category: 'ACHIEVEMENT' });
    expect((saved.body as AdminMedal).levels.map((l) => l.threshold)).toEqual([1, 5, 100, 1000, 5000]);
    const audit = await ctx.prisma.auditLog.findMany({ where: { action: 'medals.levels.update' } });
    expect(audit).toHaveLength(1);
    expect(audit[0]).toMatchObject({ actorUserId: owner.id, targetType: 'medal', targetId: 'BULLET_FIRST' });
    expect(audit[0]!.metadata).toMatchObject({
      reason: 'owner D291',
      via: 'panel',
      before: {
        category: 'ACTIVITY',
        levels: expect.arrayContaining([expect.objectContaining({ threshold: 10 })]),
      },
      after: { category: 'ACHIEVEMENT' },
    });

    // The app sees the new tab, levels and names.
    const u = await signup();
    await tx((tt) => raiseMedalLevelsIn(tt, 'BULLETS_SENT', [{ userId: u.id, value: 7 }]));
    const page = await catalogue(u);
    expect(page.BULLET_FIRST).toMatchObject({ category: 'ACHIEVEMENT', level: 2, maxLevel: 5 });
    expect(page.BULLET_FIRST!.levels[3]).toEqual({
      level: 4,
      threshold: 1000,
      name: 'Bullet star',
      iconUrl: 'https://cdn.k.test/m/b4.png',
      iconAsset: null,
      requirements: [], // D300: a single-metric level has none
    });
    expect(page.BULLET_FIRST!.levels[1]!.name).toBeNull();
  });
});

/**
 * D291 «ملوك الثروة» / Wealth Kings (owner 2026-11-06: «اي هدية مرسلة لاي مستخدم الا هدايا فئة الحظ»): every gift sent
 * to anyone counts at its coin value — in a live (here an audio room: the host and a seat guest), in a direct
 * conversation and as a CP gift — lucky gifts excluded; once per send (a retry with the same clientId adds nothing);
 * 50 M → level 1 and one big send jumps straight to the level it reaches; the backfill recomputes the same total.
 */
describe('D291 Wealth Kings', { timeout: 240_000 }, () => {
  const media = new MemoryLiveMedia();
  let ctx: TestContext;
  let seq = 0;
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
  const coins = (u: TestUser, amount: bigint) =>
    ctx.prisma.$transaction((tx) => creditIn(tx, u.id, amount, 'ADMIN_GRANT', randomUUID()));
  const gift = async (category: string): Promise<string> => {
    seq += 1;
    const code = `w${String(seq)}_${randomUUID().slice(0, 6)}`;
    await ctx.prisma.$transaction((tx) =>
      addGiftIn(tx, code, {
        category,
        nameAr: `هدية ${String(seq)}`,
        nameEn: `Gift ${String(seq)}`,
        priceCoins: 1_000_000,
        assetKey: `gift_${code}`,
        animationKey: null,
        sortOrder: seq,
        badge: 'NONE',
        tagCode: null,
        tagNameAr: null,
        tagNameEn: null,
      }),
    );
    return code;
  };
  const join = async (roomId: string, u: TestUser) => {
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
  const total = async (u: TestUser) =>
    Number(
      (
        await ctx.prisma.medalMetricTotal.findUnique({
          where: { userId_metric: { userId: u.id, metric: 'GIFTS_SENT_COINS' } },
        })
      )?.value ?? 0n,
    );
  const level = async (u: TestUser) =>
    (
      await ctx.prisma.userMedal.findUnique({
        where: { userId_medalCode: { userId: u.id, medalCode: 'WEALTH_KINGS' } },
      })
    )?.level ?? 0;

  beforeAll(async () => {
    ctx = await createTestApp(
      {
        LIVE_HOSTING_ENABLED: 'true',
        LIVE_HEARTBEAT_STALE_SECONDS: '3600',
        LIVE_GIFT_QUANTITIES: '1,10,100,1000',
        LUCKY_GIFTS_ENABLED: 'true',
        LUCKY_GIFTS_COUNTRY_HEADER: 'CF-IPCountry',
        LUCKY_PITY_AFTER: '0',
      },
      [{ token: LIVE_MEDIA_PROVIDER, value: media }],
    );
    await seedMedalCatalogue(ctx.prisma, { keepFirsts: true });
  });
  afterAll(async () => ctx?.close());

  it('live (audio room, host and seat guest), DM and CP gifts count; lucky never; once per send; level jumps', async () => {
    const [h, guest, sender, friend] = [await signup(), await signup(), await signup(), await signup()];
    await ctx.prisma.liveHost.create({ data: { userId: h.id, source: 'ADMIN' } });
    const room = await ctx.http
      .post('/api/v1/live/rooms')
      .set(auth(h))
      .send({ title: 'Wealth', mode: 'AUDIO', seatCount: 10 });
    expect(room.status, JSON.stringify(room.body)).toBe(201);
    const roomId = room.body.id as string;
    await join(roomId, guest);
    await ctx.prisma.liveRoomSeat.create({ data: { roomId, seatIndex: 1, userId: guest.id } });
    await join(roomId, sender);
    await coins(sender, 5_000_000_000n);
    const normal = await gift('POPULAR');
    const lucky = await gift('LUCKY');
    const send = (code: string, quantity: number, to: TestUser[], clientId = randomUUID()) =>
      ctx.http
        .post(`/api/v1/live/rooms/${roomId}/gifts`)
        .set(auth(sender))
        .set('CF-IPCountry', 'SA')
        .send({ giftCode: code, quantity, recipients: to.map((u) => u.username), source: 'COINS', clientId });

    // 40 M to the host: counted, below level 1.
    const first = await send(normal, 10, [h]);
    expect(first.status, JSON.stringify(first.body)).toBe(201);
    const again = await send(normal, 10, [h]);
    expect(again.status).toBe(201);
    const id = randomUUID();
    expect((await send(normal, 10, [guest], id)).status).toBe(201);
    // The same send again (same clientId): answered once, counted once.
    expect([200, 201]).toContain((await send(normal, 10, [guest], id)).status);
    expect((await send(normal, 10, [h])).status).toBe(201);
    expect(await total(sender)).toBe(40_000_000);
    expect(await level(sender)).toBe(0);

    // A lucky gift: never counted.
    const age = await ctx.http
      .put('/api/v1/me/lucky-gifts/age-confirmation')
      .set(auth(sender))
      .send({ adult: true });
    expect(age.status, JSON.stringify(age.body)).toBe(200);
    const luckySend = await send(lucky, 100, [h]);
    expect(luckySend.status, JSON.stringify(luckySend.body)).toBe(201);
    expect(await total(sender)).toBe(40_000_000);
    expect(await level(sender)).toBe(0);

    // A direct-conversation gift (10 M): the total crosses 50 M → level 1.
    for (const [a, b] of [
      [sender, friend],
      [friend, sender],
    ] as const) {
      expect((await ctx.http.put(`/api/v1/users/${b.username}/follow`).set(auth(a))).status).toBeLessThan(
        300,
      );
    }
    const dm = await ctx.http
      .post('/api/v1/dm/gifts')
      .set(auth(sender))
      .send({ to: friend.username, giftCode: normal, quantity: 10, source: 'COINS', clientId: randomUUID() });
    expect(dm.status, JSON.stringify(dm.body)).toBe(201);
    expect(await total(sender)).toBe(50_000_000);
    expect(await level(sender)).toBe(1);

    // One big send to the host and the seat guest (2 × 1000 × 1 M = 2 B): straight from level 1 to level 5 (≥ 1 B,
    // < 3 B), audited from 1 to 5.
    const big = await send(normal, 1000, [h, guest]);
    expect(big.status, JSON.stringify(big.body)).toBe(201);
    expect(await total(sender)).toBe(2_050_000_000);
    expect(await level(sender)).toBe(5);
    const audit = await ctx.prisma.auditLog.findMany({
      where: { action: 'medals.level_up', targetId: sender.id },
    });
    expect(audit.map((a) => a.metadata)).toEqual(
      expect.arrayContaining([
        expect.objectContaining({ medalCode: 'WEALTH_KINGS', from: 1, to: 5, metric: 'GIFTS_SENT_COINS' }),
      ]),
    );

    // The medals page: level 5, its own art, progress toward 3 B.
    const page = await ctx.http.get('/api/v1/medals').set(auth(sender)).set('Accept-Language', 'ar');
    expect(page.status).toBe(200);
    expectContract(page, 'listMedals');
    const wk = (page.body.data as MedalBody[]).find((m) => m.code === 'WEALTH_KINGS')!;
    expect(wk).toMatchObject({
      level: 5,
      maxLevel: 6,
      iconAsset: 'medal_wealth_l5',
      progress: { value: 2_050_000_000, next: 3_000_000_000 },
    });
    expect(wk.levels.map((l) => [l.threshold, l.iconAsset])).toEqual([
      [50_000_000, 'medal_wealth_l1'],
      [150_000_000, 'medal_wealth_l2'],
      [300_000_000, 'medal_wealth_l3'],
      [500_000_000, 'medal_wealth_l4'],
      [1_000_000_000, 'medal_wealth_l5'],
      [3_000_000_000, 'medal_wealth_l6'],
    ]);

    // The backfill recomputes the same total from history (live and DM sends, lucky excluded) and changes nothing.
    await ctx.prisma.medalMetricTotal.update({
      where: { userId_metric: { userId: sender.id, metric: 'GIFTS_SENT_COINS' } },
      data: { value: 1n },
    });
    const run = medalsAdmin('backfill');
    expect(run.status, run.out).toBe(0);
    expect(await total(sender)).toBe(2_050_000_000);
    expect(await level(sender)).toBe(5);
  });

  it('one medal per category: a duplicate code is refused when wearing; a level-up while worn keeps the one slot', async () => {
    const u = await signup();
    const reader = await signup();
    await ctx.prisma.$transaction((tx) => addGiftsSentIn(tx, u.id, 50_000_000n));
    const put = (medalCodes: unknown) =>
      ctx.http
        .put('/api/v1/me/medals/showcase')
        .set(auth(u))
        .set('Accept-Language', 'en')
        .send({ medalCodes });
    const twice = await put(['WEALTH_KINGS', 'WEALTH_KINGS']);
    expect(twice.status).toBe(400);
    expectContract(twice, 'setMyMedalShowcase');
    expect(twice.body.error.details).toEqual([{ field: 'medalCodes', issue: 'invalid_value' }]);
    const worn = await put(['WEALTH_KINGS']);
    expect(worn.status).toBe(200);
    expect(worn.body.showcase).toEqual([
      expect.objectContaining({ code: 'WEALTH_KINGS', level: 1, iconAsset: 'medal_wealth_l1' }),
    ]);
    // 100 M more (150 M): level 2 replaces level 1 in the same slot, with level 2's art.
    await ctx.prisma.$transaction((tx) => addGiftsSentIn(tx, u.id, 100_000_000n));
    expect(await level(u)).toBe(2);
    const mine = await ctx.http.get('/api/v1/me/medals/showcase').set(auth(u));
    expectContract(mine, 'getMyMedalShowcase');
    expect(mine.body.showcase).toEqual([
      expect.objectContaining({ code: 'WEALTH_KINGS', level: 2, iconAsset: 'medal_wealth_l2' }),
    ]);
    const prof = await ctx.http.get(`/api/v1/users/${u.username}`).set(auth(reader));
    expectContract(prof, 'getPublicProfile');
    expect(
      (prof.body.medals.showcase as { code: string; level: number }[]).map((m) => [m.code, m.level]),
    ).toEqual([['WEALTH_KINGS', 2]]);
    const list = await ctx.http.get(`/api/v1/users/${u.username}/medals`).set(auth(reader));
    expectContract(list, 'listUserMedals');
    expect((list.body.data as { code: string }[]).filter((m) => m.code === 'WEALTH_KINGS')).toHaveLength(1);
    const page = await ctx.http.get('/api/v1/medals').set(auth(u));
    expect((page.body.data as { code: string }[]).filter((m) => m.code === 'WEALTH_KINGS')).toHaveLength(1);
    expect(await ctx.prisma.userMedal.count({ where: { userId: u.id, medalCode: 'WEALTH_KINGS' } })).toBe(1);
  });

  // D291 «سيد الحظ» (owner: «يتم احتساب من مجموع هدايا الحظ التي قام بإرسالها»): the mirror of Wealth Kings.
  it('Lucky Master: lucky sends count (normal ones only for Wealth Kings); 500 M → L1; jumps; 10 B exact; once per send; backfill', async () => {
    const [h, guest, sender] = [await signup(), await signup(), await signup()];
    await ctx.prisma.liveHost.create({ data: { userId: h.id, source: 'ADMIN' } });
    const room = await ctx.http
      .post('/api/v1/live/rooms')
      .set(auth(h))
      .send({ title: 'Luck', mode: 'AUDIO', seatCount: 10 });
    expect(room.status, JSON.stringify(room.body)).toBe(201);
    const roomId = room.body.id as string;
    await join(roomId, guest);
    await ctx.prisma.liveRoomSeat.create({ data: { roomId, seatIndex: 1, userId: guest.id } });
    await join(roomId, sender);
    await coins(sender, 30_000_000_000n);
    const age = await ctx.http
      .put('/api/v1/me/lucky-gifts/age-confirmation')
      .set(auth(sender))
      .send({ adult: true });
    expect(age.status).toBe(200);
    const normal = await gift('POPULAR');
    const lucky = await gift('LUCKY');
    const send = (code: string, quantity: number, to: TestUser[], clientId = randomUUID()) =>
      ctx.http
        .post(`/api/v1/live/rooms/${roomId}/gifts`)
        .set(auth(sender))
        .set('CF-IPCountry', 'SA')
        .send({ giftCode: code, quantity, recipients: to.map((u) => u.username), source: 'COINS', clientId });
    const totals = async () =>
      Object.fromEntries(
        (await ctx.prisma.medalMetricTotal.findMany({ where: { userId: sender.id } })).map((t) => [
          t.metric,
          t.value,
        ]),
      );
    const luckyLevel = async () =>
      (
        await ctx.prisma.userMedal.findUnique({
          where: { userId_medalCode: { userId: sender.id, medalCode: 'LUCKY_MASTER' } },
        })
      )?.level ?? 0;

    // A normal gift: Wealth Kings only.
    expect((await send(normal, 100, [h])).status).toBe(201);
    expect(await totals()).toEqual({ GIFTS_SENT_COINS: 100_000_000n });
    expect(await luckyLevel()).toBe(0);

    // 600 M of lucky gifts (one retried with the same clientId): Lucky Master only, crossing 500 M → L1.
    const id = randomUUID();
    const first = await send(lucky, 100, [h], id);
    expect(first.status, JSON.stringify(first.body)).toBe(201);
    expect([200, 201]).toContain((await send(lucky, 100, [h], id)).status);
    expect((await totals()).LUCKY_GIFTS_SENT_COINS).toBe(100_000_000n);
    expect((await send(lucky, 100, [h, guest])).status).toBe(201);
    expect((await send(lucky, 100, [h, guest])).status).toBe(201);
    expect((await send(lucky, 100, [guest])).status).toBe(201);
    expect(await totals()).toEqual({ GIFTS_SENT_COINS: 100_000_000n, LUCKY_GIFTS_SENT_COINS: 600_000_000n });
    expect(await luckyLevel()).toBe(1);

    // One big send (2 × 1000 × 1 M = 2 B; 2.6 B): straight from L1 to L2; then 1000 × 1 M more (3.6 B): L3.
    expect((await send(lucky, 1000, [h, guest])).status).toBe(201);
    expect(await luckyLevel()).toBe(2);
    expect((await send(lucky, 1000, [h])).status).toBe(201);
    expect(await luckyLevel()).toBe(3);
    // Past 2^32 and up to 10 B: L4, stored and returned exactly.
    for (let i = 0; i < 3; i++) expect((await send(lucky, 1000, [h, guest])).status).toBe(201);
    expect((await send(lucky, 100, [h, guest])).status).toBe(201);
    expect((await send(lucky, 100, [h])).status).toBe(201);
    expect((await send(lucky, 100, [h])).status).toBe(201);
    expect(await totals()).toEqual({
      GIFTS_SENT_COINS: 100_000_000n,
      LUCKY_GIFTS_SENT_COINS: 10_000_000_000n,
    });
    expect(await luckyLevel()).toBe(4);
    const audit = await ctx.prisma.auditLog.findMany({
      where: { action: 'medals.level_up', targetId: sender.id },
    });
    expect(audit.map((a) => a.metadata)).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          medalCode: 'LUCKY_MASTER',
          from: 1,
          to: 2,
          metric: 'LUCKY_GIFTS_SENT_COINS',
        }),
        expect.objectContaining({ medalCode: 'LUCKY_MASTER', from: 3, to: 4, value: 10_000_000_000 }),
      ]),
    );
    const page = await ctx.http.get('/api/v1/medals').set(auth(sender)).set('Accept-Language', 'ar');
    expect(page.status).toBe(200);
    expectContract(page, 'listMedals');
    const lm = (page.body.data as MedalBody[]).find((m) => m.code === 'LUCKY_MASTER')!;
    expect(lm).toMatchObject({
      level: 4,
      maxLevel: 4,
      iconAsset: 'medal_lucky_l4',
      progress: { value: 10_000_000_000, next: null },
    });
    expect(lm.levels.map((l) => [l.threshold, l.iconAsset])).toEqual([
      [500_000_000, 'medal_lucky_l1'],
      [1_500_000_000, 'medal_lucky_l2'],
      [3_000_000_000, 'medal_lucky_l3'],
      [10_000_000_000, 'medal_lucky_l4'],
    ]);
    // One category, one medal: wearing it twice is refused; worn once at L4.
    const wear = (codes: string[]) =>
      ctx.http.put('/api/v1/me/medals/showcase').set(auth(sender)).send({ medalCodes: codes });
    expect((await wear(['LUCKY_MASTER', 'LUCKY_MASTER'])).status).toBe(400);
    const worn = await wear(['LUCKY_MASTER']);
    expect(worn.body.showcase).toEqual([
      expect.objectContaining({ code: 'LUCKY_MASTER', level: 4, iconAsset: 'medal_lucky_l4' }),
    ]);

    // The backfill recomputes both totals exactly from the sends.
    await ctx.prisma.medalMetricTotal.updateMany({ where: { userId: sender.id }, data: { value: 1n } });
    const run = medalsAdmin('backfill');
    expect(run.status, run.out).toBe(0);
    expect(await totals()).toEqual({
      GIFTS_SENT_COINS: 100_000_000n,
      LUCKY_GIFTS_SENT_COINS: 10_000_000_000n,
    });
    expect(await luckyLevel()).toBe(4);
  });
});
