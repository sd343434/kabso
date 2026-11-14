/**
 * D192 (owner 2026-10-31; contract v1.61-social, CONVENTIONS §10.55, CP-035): the public website's API — the launch
 * waitlist `POST /waitlist` (public, non-enumerating, idempotent per email, per-IP limit, read only by the
 * `waitlist-admin` CLI) and the website's settings (`GET /site/settings` public; written only by the OWNER from the
 * admin panel, `PUT /admin/site-settings`, tested in d191-admin-panel). End to end against PostgreSQL + Redis.
 */
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { expectContract } from './helpers/openapi.js';
import {
  createTestApp,
  registerVerified,
  withMigrationClient,
  type TestContext,
} from './helpers/test-app.js';

/** Runs `pnpm waitlist:admin …` as on the server (migration role, a child process). */
function waitlistAdmin(...args: string[]): { status: number; out: string; err: string } {
  try {
    const out = execFileSync('pnpm', ['-s', 'waitlist:admin', ...args], {
      cwd: fileURLToPath(new URL('..', import.meta.url)),
      env: process.env,
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'pipe'],
    });
    return { status: 0, out, err: '' };
  } catch (err) {
    const e = err as { status: number; stdout: string; stderr: string };
    return { status: e.status, out: e.stdout, err: e.stderr };
  }
}

const GENEROUS = '10000/900';

describe('D192 waitlist', { timeout: 120_000 }, () => {
  let ctx: TestContext;

  beforeAll(async () => {
    ctx = await createTestApp({ RATE_LIMIT_WAITLIST_IP: GENEROUS });
  });
  afterAll(async () => {
    await ctx.close();
  });

  it('accepts a new email with 202 and the one constant body, stored normalized with its language', async () => {
    const res = await ctx.http
      .post('/api/v1/waitlist')
      .send({ email: '  Layla.K@Example.COM ', locale: 'ar' });
    expect(res.status).toBe(202);
    expectContract(res, 'joinWaitlist');
    expect(res.body).toEqual({ status: 'accepted' });
    const row = await ctx.prisma.waitlistSignup.findUniqueOrThrow({
      where: { email: 'layla.k@example.com' },
    });
    expect(row.locale).toBe('ar');
  });

  it('is idempotent per email and never says whether the email was already listed', async () => {
    const first = await ctx.http.post('/api/v1/waitlist').send({ email: 'omar@example.com', locale: 'en' });
    const again = await ctx.http.post('/api/v1/waitlist').send({ email: 'OMAR@example.com', locale: 'ar' });
    const fresh = await ctx.http.post('/api/v1/waitlist').send({ email: 'sara@example.com', locale: 'ar' });
    for (const res of [first, again, fresh]) {
      expect(res.status).toBe(202);
      expect(res.body).toEqual({ status: 'accepted' });
      expect(Object.keys(res.headers)).not.toContain('location');
    }
    // Same headers apart from the per-request ones (no hint in a length or an extra header).
    const shape = (h: Record<string, string>) =>
      Object.keys(h)
        .filter((k) => !['date', 'x-request-id', 'etag', 'ratelimit', 'ratelimit-policy'].includes(k))
        .sort();
    expect(shape(again.headers)).toEqual(shape(fresh.headers));
    expect(again.headers['content-length']).toBe(fresh.headers['content-length']);
    const rows = await ctx.prisma.waitlistSignup.findMany({ where: { email: 'omar@example.com' } });
    expect(rows).toHaveLength(1);
    expect(rows[0]!.locale).toBe('en'); // the first sign-up's language stays
  });

  it('also answers 202 for the email of an existing account (the waitlist knows nothing of accounts)', async () => {
    const { res: reg } = await registerVerified(ctx);
    const email = (await ctx.prisma.user.findUniqueOrThrow({ where: { id: reg.body.user.id as string } }))
      .email;
    const res = await ctx.http.post('/api/v1/waitlist').send({ email, locale: 'en' });
    expect(res.status).toBe(202);
    expect(res.body).toEqual({ status: 'accepted' });
  });

  it('refuses an invalid body with 400 and stores nothing', async () => {
    const before = await ctx.prisma.waitlistSignup.count();
    const cases: [unknown, string, string][] = [
      [{ email: 'not-an-email', locale: 'ar' }, 'email', 'invalid_email'],
      [{ email: `${'a'.repeat(250)}@x.co`, locale: 'ar' }, 'email', 'too_long'],
      [{ email: 'a@b.co', locale: 'fr' }, 'locale', 'invalid_value'],
      [{ email: 'a@b.co' }, 'locale', 'invalid_value'],
      [{ email: 'a@b.co', locale: 'ar', name: 'x' }, 'name', 'unknown_field'],
    ];
    for (const [body, field, issue] of cases) {
      const res = await ctx.http.post('/api/v1/waitlist').send(body as object);
      expect(res.status, JSON.stringify(body)).toBe(400);
      expectContract(res, 'joinWaitlist');
      expect(res.body.error.code).toBe('VALIDATION_FAILED');
      expect(res.body.error.details).toContainEqual({ field, issue });
    }
    expect(await ctx.prisma.waitlistSignup.count()).toBe(before);
  });

  it('waitlist-admin list and export read it, each run audited without the addresses', async () => {
    const list = waitlistAdmin('list', '--limit', '2');
    expect(list.status, list.err).toBe(0);
    expect(list.out).toMatch(/^\d+ on the waitlist \(/);
    expect(list.out.trim().split('\n')).toHaveLength(3);

    const csv = waitlistAdmin('export', '--locale', 'en');
    expect(csv.status, csv.err).toBe(0);
    const lines = csv.out.trim().split('\n');
    expect(lines[0]).toBe('email,locale,created_at');
    expect(lines.some((l) => l.startsWith('omar@example.com,en,'))).toBe(true);
    expect(lines.every((l, i) => i === 0 || l.split(',')[1] === 'en')).toBe(true);

    const audits = await ctx.prisma.auditLog.findMany({
      where: { action: 'waitlist.view' },
      orderBy: { createdAt: 'asc' },
    });
    expect(audits.map((a) => (a.metadata as { op: string }).op)).toEqual(['list', 'export']);
    expect(JSON.stringify(audits)).not.toContain('@');

    expect(waitlistAdmin('export', '--locale', 'fr').status).toBe(1);
    expect(waitlistAdmin('drop').status).toBe(1);
  });
});

describe('D192 waitlist rate limit', { timeout: 60_000 }, () => {
  let ctx: TestContext;

  beforeAll(async () => {
    ctx = await createTestApp({ RATE_LIMIT_WAITLIST_IP: '3/3600' });
  });
  afterAll(async () => {
    await ctx.close();
  });

  it('allows 3 an hour per IP (invalid bodies count), then 429 RATE_LIMITED with Retry-After', async () => {
    expect(
      (await ctx.http.post('/api/v1/waitlist').send({ email: 'r1@example.com', locale: 'ar' })).status,
    ).toBe(202);
    expect((await ctx.http.post('/api/v1/waitlist').send({ email: 'bad', locale: 'ar' })).status).toBe(400);
    expect(
      (await ctx.http.post('/api/v1/waitlist').send({ email: 'r1@example.com', locale: 'ar' })).status,
    ).toBe(202);
    const limited = await ctx.http.post('/api/v1/waitlist').send({ email: 'r2@example.com', locale: 'ar' });
    expect(limited.status).toBe(429);
    expectContract(limited, 'joinWaitlist');
    expect(limited.body.error.code).toBe('RATE_LIMITED');
    expect(Number(limited.headers['retry-after'])).toBeGreaterThan(0);
    expect(await ctx.prisma.waitlistSignup.count({ where: { email: 'r2@example.com' } })).toBe(0);
  });
});

describe(
  'D192 site settings (the website side; the OWNER edits them in the panel, d191-admin-panel)',
  { timeout: 120_000 },
  () => {
    let ctx: TestContext;
    let ownerToken: string;

    beforeAll(async () => {
      ctx = await createTestApp({ ADMIN_TOTP_KEY: 'admin-totp-test-key-0123456789-abcdefghijklmnop' });
      const owner = await registerVerified(ctx);
      const ownerId = owner.res.body.user.id as string;
      ownerToken = owner.res.body.tokens.accessToken as string;
      await ctx.prisma.user.update({ where: { id: ownerId }, data: { role: 'ADMIN' } });
      // The runtime role cannot grant admin permissions (SEC-011): as `admin-admin grant` does, with the migration role.
      await withMigrationClient((db) =>
        db.userAdminPermission.create({ data: { userId: ownerId, permission: 'OWNER' } }),
      );
    });
    afterAll(async () => {
      await ctx.close();
    });

    it('GET is public: defaults (no links, top-up off), cached 60 s', async () => {
      const res = await ctx.http.get('/api/v1/site/settings');
      expect(res.status).toBe(200);
      expectContract(res, 'getSiteSettings');
      expect(res.body).toEqual({
        socials: { instagram: null, tiktok: null, whatsapp: null },
        topupEnabled: false,
      });
      expect(res.headers['cache-control']).toBe('public, max-age=60');
    });

    it("there is one write route, the panel's: a bearer token (even the OWNER's) is not a panel session", async () => {
      const res = await ctx.http
        .put('/api/v1/admin/site-settings')
        .set('Authorization', `Bearer ${ownerToken}`)
        .send({ socials: { instagram: null, tiktok: null, whatsapp: null }, topupEnabled: true });
      expect(res.status).toBe(401);
      expectContract(res, 'updateAdminSiteSettings');
      expect((await ctx.http.get('/api/v1/site/settings')).body.topupEnabled).toBe(false);
    });

    it('serves the stored links in the one standard form the website accepts', async () => {
      await ctx.prisma.siteSetting.upsert({
        where: { key: 'socials' },
        create: {
          key: 'socials',
          value: {
            instagram: 'https://www.instagram.com/kabsolive',
            tiktok: 'https://www.tiktok.com/@kabsolive',
            whatsapp: 'https://wa.me/966500000000',
          },
        },
        update: {},
      });
      await ctx.prisma.siteSetting.upsert({
        where: { key: 'topupEnabled' },
        create: { key: 'topupEnabled', value: true },
        update: { value: true },
      });
      const res = await ctx.http.get('/api/v1/site/settings');
      expectContract(res, 'getSiteSettings');
      expect(res.body).toEqual({
        socials: {
          instagram: 'https://www.instagram.com/kabsolive',
          tiktok: 'https://www.tiktok.com/@kabsolive',
          whatsapp: 'https://wa.me/966500000000',
        },
        topupEnabled: true,
      });
      // The same patterns as infra/deploy/site/assets/common.js (HOSTS).
      expect(res.body.socials.instagram).toMatch(/^https:\/\/www\.instagram\.com\/[A-Za-z0-9._]{1,30}$/);
      expect(res.body.socials.tiktok).toMatch(/^https:\/\/www\.tiktok\.com\/@[A-Za-z0-9._]{2,24}$/);
      expect(res.body.socials.whatsapp).toMatch(/^https:\/\/wa\.me\/[1-9][0-9]{7,14}$/);
    });

    it('a stored value that no longer passes the rules is not shown', async () => {
      await ctx.prisma.siteSetting.update({
        where: { key: 'socials' },
        data: {
          value: {
            instagram: 'https://instagram.com/kabsolive',
            tiktok: 'https://evil.example/@x',
            whatsapp: 42,
          },
        },
      });
      const res = await ctx.http.get('/api/v1/site/settings');
      expect(res.body.socials).toEqual({
        instagram: 'https://www.instagram.com/kabsolive',
        tiktok: null,
        whatsapp: null,
      });
    });
  },
);
