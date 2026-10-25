/**
 * KL-076 / owner D101: `levels:admin publish-charm` publishes the owner's ladder for the charm
 * (ATTRACTIVENESS) category and switches it on, so taps raise room levels (CONVENTIONS §10.18,
 * docs/DEPLOYMENT.md). Runs the command as the server does — the migration role, a child
 * process — against PostgreSQL, then reads the room level through the API.
 */
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { PRESET_LEVELS } from '../src/modules/levels/level-preset.js';
import { LIVE_MEDIA_PROVIDER } from '../src/modules/live/media/live-media.provider.js';
import { MemoryLiveMedia } from './helpers/memory-live-media.js';
import { createTestApp, registerVerified, type TestContext } from './helpers/test-app.js';

function levelsAdmin(...args: string[]): { status: number; out: string } {
  try {
    const out = execFileSync('pnpm', ['-s', 'levels:admin', ...args], {
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

describe('D101 levels:admin publish-charm', () => {
  let ctx: TestContext;

  const signup = async () => {
    const { res, payload } = await registerVerified(ctx);
    expect(res.status).toBe(201);
    return {
      id: res.body.user.id as string,
      email: payload.email,
      token: res.body.tokens.accessToken as string,
    };
  };

  beforeAll(async () => {
    ctx = await createTestApp({ LIVE_HOSTING_ENABLED: 'true' }, [
      { token: LIVE_MEDIA_PROVIDER, value: new MemoryLiveMedia() },
    ]);
    // The migration seeds the categories; the test database is truncated.
    await ctx.prisma.levelCategory.create({
      data: {
        code: 'ATTRACTIVENESS',
        nameAr: 'مستوى الجاذبية',
        nameEn: 'Attractiveness',
        descriptionAr: 'وصف',
        descriptionEn: 'About',
      },
    });
  });
  afterAll(async () => ctx?.close());

  it('refuses a user without role ADMIN', async () => {
    const u = await signup();
    const run = levelsAdmin('publish-charm', u.email);
    expect(run.status).toBe(1);
    expect(run.out).toContain('does not have role ADMIN');
    const category = await ctx.prisma.levelCategory.findUniqueOrThrow({ where: { code: 'ATTRACTIVENESS' } });
    expect(category.isEnabled).toBe(false);
  });

  it('publishes the owner ladder, switches it on, audits it; rooms then show level 1', async () => {
    const admin = await signup();
    await ctx.prisma.user.update({ where: { id: admin.id }, data: { role: 'ADMIN' } });
    const run = levelsAdmin('publish-charm', admin.email);
    expect(run).toEqual({ status: 0, out: 'ATTRACTIVENESS: v1 published and enabled.\n' });

    const category = await ctx.prisma.levelCategory.findUniqueOrThrow({
      where: { code: 'ATTRACTIVENESS' },
      include: { publishedVersion: { include: { levels: true } } },
    });
    expect(category.isEnabled).toBe(true);
    expect(category.publishedVersion?.status).toBe('PUBLISHED');
    expect(category.publishedVersion?.publishedById).toBe(admin.id);
    expect(category.publishedVersion?.levels).toHaveLength(PRESET_LEVELS);
    const audits = await ctx.prisma.auditLog.findMany({
      where: { actorUserId: admin.id, action: { startsWith: 'levels.' } },
      orderBy: { createdAt: 'asc' },
    });
    expect(audits.map((a) => a.action)).toEqual([
      'levels.version.create',
      'levels.version.publish',
      'levels.category.update',
    ]);

    // A host's room now has a level.
    const host = await signup();
    await ctx.prisma.liveHost.create({ data: { userId: host.id, source: 'ADMIN' } });
    const started = await ctx.http
      .post('/api/v1/live/rooms')
      .set({ Authorization: `Bearer ${host.token}` })
      .send({ title: 'Charm' });
    expect(started.status).toBe(201);
    expect(started.body.roomLevel).toBe(1);

    // Running it again changes nothing.
    expect(levelsAdmin('publish-charm', admin.email)).toEqual({
      status: 0,
      out: 'ATTRACTIVENESS is already published and enabled.\n',
    });
    expect(await ctx.prisma.levelCategoryVersion.count()).toBe(1);
  });
});
