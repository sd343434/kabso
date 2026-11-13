/**
 * D228 (owner 2026-11-01; contract v1.49-live, CONVENTIONS §10.79): the OWNER's switch of the app's camera effects
 * engine — DeepAR (default) or the free ML Kit + MediaPipe engine. `GET|PUT /admin/camera-fx` (panel session,
 * `site.settings`: OWNER only), audited; the app reads it in `LiveConfig.cameraFxEngine` (`GET /live/config`).
 * End to end against PostgreSQL + Redis.
 */
import { afterAll, beforeAll, describe, expect, it, vi } from 'vitest';
import { panel, type Admin, type Person } from './helpers/admin-panel.js';
import { expectContract } from './helpers/openapi.js';
import { createTestApp, type TestContext } from './helpers/test-app.js';

const ADMIN_KEY = 'admin-totp-test-key-0123456789-abcdefghijklmnop';

describe('D228 camera effects engine switch', { timeout: 180_000 }, () => {
  let ctx: TestContext;
  const p = panel(() => ctx);
  let owner: Admin;
  let moderator: Admin;
  let finance: Admin;
  let user: Person;

  beforeAll(async () => {
    vi.useFakeTimers({ toFake: ['Date'], now: p.start() });
    ctx = await createTestApp({
      ADMIN_TOTP_KEY: ADMIN_KEY,
      RATE_LIMIT_ADMIN_LOGIN_IP: '10000/900',
      RATE_LIMIT_ADMIN_IP: '10000/900',
    });
    owner = await p.makeAdmin(['OWNER']);
    moderator = await p.makeAdmin(['MODERATION']);
    finance = await p.makeAdmin(['FINANCE']);
    user = await p.signup();
  });
  afterAll(async () => {
    await ctx?.prisma.siteSetting.deleteMany({ where: { key: 'cameraFxEngine' } });
    await ctx?.close();
    vi.useRealTimers();
  });

  const liveConfig = async () => {
    const res = await ctx.http.get('/api/v1/live/config');
    expect(res.status).toBe(200);
    expectContract(res, 'getLiveConfig');
    return res.body as { cameraFxEngine: string };
  };

  it('DEEPAR by default, for guests and signed-in users alike', async () => {
    expect((await liveConfig()).cameraFxEngine).toBe('DEEPAR');
    const signedIn = await ctx.http.get('/api/v1/live/config').set('Authorization', `Bearer ${user.token}`);
    expect(signedIn.body.cameraFxEngine).toBe('DEEPAR');
    const res = await p.send(owner, 'get', '/admin/camera-fx');
    expect(res.status).toBe(200);
    expectContract(res, 'getAdminCameraFx');
    expect(res.body).toEqual({ cameraFxEngine: 'DEEPAR' });
  });

  it('OWNER only: other panel roles get 403, a bearer token (even a user) 401; nothing changes', async () => {
    for (const a of [moderator, finance]) {
      expect((await p.send(a, 'get', '/admin/camera-fx')).status).toBe(403);
      const put = await p.send(a, 'put', '/admin/camera-fx', { cameraFxEngine: 'FREE' });
      expect(put.status).toBe(403);
      expectContract(put, 'updateAdminCameraFx');
    }
    const bearer = await ctx.http
      .put('/api/v1/admin/camera-fx')
      .set('Authorization', `Bearer ${user.token}`)
      .send({ cameraFxEngine: 'FREE' });
    expect(bearer.status).toBe(401);
    // A session without its CSRF token is refused too.
    const noCsrf = await ctx.http
      .put('/api/v1/admin/camera-fx')
      .set('Cookie', owner.cookie)
      .send({ cameraFxEngine: 'FREE' });
    expect(noCsrf.status).toBe(403);
    expect((await liveConfig()).cameraFxEngine).toBe('DEEPAR');
  });

  it('the OWNER switches to FREE: the app sees it at once; audited with before and after', async () => {
    const res = await p.send(owner, 'put', '/admin/camera-fx', {
      cameraFxEngine: 'FREE',
      reason: 'compare on phone',
    });
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    expectContract(res, 'updateAdminCameraFx');
    expect(res.body).toEqual({ cameraFxEngine: 'FREE' });
    expect((await liveConfig()).cameraFxEngine).toBe('FREE');
    const audit = await ctx.prisma.auditLog.findMany({
      where: { action: 'site.settings.update', actorUserId: owner.id },
      orderBy: { createdAt: 'asc' },
    });
    expect(audit).toHaveLength(1);
    expect(audit[0]!.metadata).toMatchObject({
      key: 'cameraFxEngine',
      before: 'DEEPAR',
      after: 'FREE',
      reason: 'compare on phone',
      via: 'panel',
    });
  });

  it('and back to DEEPAR; anything else is 400 and changes nothing', async () => {
    for (const bad of [
      { cameraFxEngine: 'free' },
      { cameraFxEngine: 'BANUBA' },
      {},
      { cameraFxEngine: 'FREE', x: 1 },
    ]) {
      const res = await p.send(owner, 'put', '/admin/camera-fx', bad);
      expect(res.status, JSON.stringify(bad)).toBe(400);
      expectContract(res, 'updateAdminCameraFx');
      expect(res.body.error.code).toBe('VALIDATION_FAILED');
    }
    expect((await liveConfig()).cameraFxEngine).toBe('FREE');
    const back = await p.send(owner, 'put', '/admin/camera-fx', { cameraFxEngine: 'DEEPAR' });
    expect(back.status).toBe(200);
    expect((await liveConfig()).cameraFxEngine).toBe('DEEPAR');
  });

  it('a stored value that is not exactly FREE reads as DEEPAR; the website settings are untouched', async () => {
    await ctx.prisma.siteSetting.update({ where: { key: 'cameraFxEngine' }, data: { value: 'free' } });
    expect((await liveConfig()).cameraFxEngine).toBe('DEEPAR');
    const site = await ctx.http.get('/api/v1/site/settings');
    expectContract(site, 'getSiteSettings');
    expect(site.body).not.toHaveProperty('cameraFxEngine');
  });

  it('the table refuses any other key (the CHECK lists cameraFxEngine and nothing new)', async () => {
    await expect(
      ctx.prisma.siteSetting.create({ data: { key: 'somethingElse', value: true } }),
    ).rejects.toThrow();
  });
});
