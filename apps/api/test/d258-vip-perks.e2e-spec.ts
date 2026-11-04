/**
 * D258 (owner's VIP 1 perks; contract v1.83-social, CONVENTIONS §10.94): the perks the app really does
 * (`available`), a perk's number per tier (`amount`), the VIP art uploads from the panel and a member's active VIP on
 * every UserSummary. End to end against PostgreSQL + Redis with the API as the DML-only runtime role.
 */
import { randomUUID } from 'node:crypto';
import { deflateSync } from 'node:zlib';
import sharp from 'sharp';
import { afterAll, beforeAll, describe, expect, it, vi } from 'vitest';
import { OBJECT_STORAGE } from '../src/modules/media/object-storage.js';
import { creditIn } from '../src/modules/wallet/wallet-ledger.js';
import { panel, type Admin, type Person } from './helpers/admin-panel.js';
import { MemoryObjectStorage } from './helpers/memory-storage.js';
import { expectContract, operations } from './helpers/openapi.js';
import { createTestApp, withMigrationClient, type TestContext } from './helpers/test-app.js';

const ADMIN_KEY = 'admin-totp-test-key-0123456789-abcdefghijklmnop';
const BASE = 'https://media.example.test';
const DAY = 86_400_000;
const VIP1 = '01a25200-0000-7000-8000-000000000001';
const svga = () => deflateSync(Buffer.concat([Buffer.from([0x0a, 0x05]), Buffer.from('2.0.0')]));

describe('D258 contract coverage', () => {
  it('openapi v1.83-social declares the VIP art upload', () => {
    const ids = operations().map((o) => `${o.operationId} ${o.method.toUpperCase()} ${o.path}`);
    expect(ids).toContain('uploadAdminVipArt POST /api/v1/admin/vip/uploads');
  });
});

describe('D258 VIP perks', { timeout: 180_000 }, () => {
  let ctx: TestContext;
  const p = panel(() => ctx);
  let owner: Admin;

  const auth = (u: Person) => ({ Authorization: `Bearer ${u.token}` });
  const usernameOf = async (u: Person) =>
    (await ctx.http.get('/api/v1/me').set(auth(u))).body.username as string;
  const listed = async (u: Person) => {
    const res = await ctx.http.get('/api/v1/vip/tiers').set(auth(u)).set('Accept-Language', 'ar');
    expect(res.status).toBe(200);
    expectContract(res, 'listVipTiers');
    return res.body.data as {
      code: string;
      perks: { code: string; available: boolean; amount: number | null; title: string }[];
    }[];
  };
  const upload = (kind: 'animation' | 'still', tier: string, body: Buffer) =>
    ctx.http
      .post(`/api/v1/admin/vip/uploads?kind=${kind}&tier=${tier}`)
      .set('Cookie', owner.cookie)
      .set('X-CSRF-Token', owner.csrf)
      .set('Content-Type', 'application/octet-stream')
      .send(body);

  beforeAll(async () => {
    vi.useFakeTimers({ toFake: ['Date'], now: p.start() });
    ctx = await createTestApp(
      {
        ADMIN_TOTP_KEY: ADMIN_KEY,
        ADMIN_SESSION_IDLE_SECONDS: '86400',
        ADMIN_SESSION_MAX_SECONDS: '604800',
        RATE_LIMIT_ADMIN_LOGIN_IP: '10000/900',
        RATE_LIMIT_ADMIN_IP: '10000/900',
        MEDIA_PUBLIC_BASE_URL: BASE,
      },
      [{ token: OBJECT_STORAGE, value: new MemoryObjectStorage() }],
    );
    owner = await p.makeAdmin(['OWNER']);
  });
  afterAll(async () => {
    await ctx?.close();
    vi.useRealTimers();
  });

  it("VIP 1 carries the owner's twelve perks; the built ones are available, amounts as chosen", async () => {
    const u = await p.signup();
    const vip1 = (await listed(u)).find((t) => t.code === 'VIP_1')!;
    const byCode = new Map(vip1.perks.map((pk) => [pk.code, pk]));
    expect(byCode.size).toBe(12);
    // VIP 1's special text colour: the owner's gold (§10.94.10).
    expect((vip1 as unknown as { nameColor: string | null }).nameColor).toBe('#FFC928');
    for (const code of [
      'BADGE',
      'AVATAR_FRAME',
      'CHAT_NAME_COLOR',
      'CHAT_BUBBLE',
      'PROFILE_CARD',
      'ENTRY_BANNER',
      'ENTRY_EFFECT',
      'MIC_WAVE',
      'PROFILE_VISITORS',
      'DAILY_BULLET',
      'DAILY_COINS',
      'LEVEL_SPEEDUP',
    ]) {
      expect(byCode.get(code)!.available, code).toBe(true);
    }
    expect(byCode.get('DAILY_BULLET')!.amount).toBe(3);
    expect(byCode.get('LEVEL_SPEEDUP')!.amount).toBe(1);
    expect(byCode.get('DAILY_COINS')!.amount).toBeNull();
    expect(byCode.get('BADGE')!.amount).toBeNull();
    expect(byCode.get('MIC_WAVE')!.title).toBe('موجة المايك');
  });

  it("the panel: a perk's amount is checked and audited; the art uploads (SVGA, still)", async () => {
    const list = await p.send(owner, 'get', '/admin/vip/tiers');
    expect(list.status).toBe(200);
    expectContract(list, 'listAdminVipTiers');
    const tier = (list.body.data as { id: string; code: string; perks: Record<string, unknown>[] }[]).find(
      (t) => t.code === 'VIP_1',
    )!;
    const perks = tier.perks.map((pk) => ({
      code: pk.code,
      titleAr: pk.titleAr,
      titleEn: pk.titleEn,
      enabled: pk.enabled,
      ...(pk.amount === null ? {} : { amount: pk.amount }),
    }));
    // An amount on a perk that takes none, or out of its range → 400.
    const bad = await p.send(owner, 'patch', `/admin/vip/tiers/${VIP1}`, {
      perks: perks.map((pk) => (pk.code === 'BADGE' ? { ...pk, amount: 2 } : pk)),
      reason: 'owner D258',
    });
    expect(bad.status).toBe(400);
    const tooMany = await p.send(owner, 'patch', `/admin/vip/tiers/${VIP1}`, {
      perks: perks.map((pk) => (pk.code === 'DAILY_BULLET' ? { ...pk, amount: 101 } : pk)),
      reason: 'owner D258',
    });
    expect(tooMany.status).toBe(400);

    // The art: an SVGA 2.x and a wide still; a zip (SVGA 1.x) refused.
    const anim = await upload('animation', 'VIP_1', svga());
    expect(anim.status, JSON.stringify(anim.body)).toBe(201);
    expectContract(anim, 'uploadAdminVipArt');
    expect(anim.body.url).toMatch(new RegExp(`^${BASE}/media/vip/VIP_1/[0-9a-f]{32}\\.svga$`));
    const still = await upload(
      'still',
      'VIP_1',
      await sharp({ create: { width: 660, height: 150, channels: 4, background: '#2e8b3d' } })
        .png()
        .toBuffer(),
    );
    expect(still.status).toBe(201);
    expect([still.body.width, still.body.height]).toEqual([660, 150]);
    const zip = await upload('animation', 'VIP_1', Buffer.from([0x50, 0x4b, 0x03, 0x04, 1, 2, 3]));
    expect(zip.status).toBe(409);

    // The daily coins set, the frame given its art: saved and audited.
    const ok = await p.send(owner, 'patch', `/admin/vip/tiers/${VIP1}`, {
      perks: perks.map((pk) =>
        pk.code === 'DAILY_COINS'
          ? { ...pk, amount: 5000 }
          : pk.code === 'AVATAR_FRAME'
            ? { ...pk, animation: anim.body.url as string }
            : pk,
      ),
      // The special text colour (§10.94.10), stored upper case.
      nameColor: '#ffcc00',
      reason: 'owner D258',
    });
    expect(ok.status, JSON.stringify(ok.body)).toBe(200);
    expectContract(ok, 'updateAdminVipTier');
    const saved = (ok.body.perks as { code: string; amount: number | null; animation: string | null }[]).find(
      (pk) => pk.code === 'DAILY_COINS',
    )!;
    expect(saved.amount).toBe(5000);
    expect(ok.body.nameColor).toBe('#FFCC00');
    const audit = await withMigrationClient((db) =>
      db.auditLog.findFirst({ where: { action: 'vip.tier.update' }, orderBy: { createdAt: 'desc' } }),
    );
    expect(JSON.stringify(audit?.metadata)).toContain('"amount":5000');
    expect(JSON.stringify(audit?.metadata)).toContain('"nameColor":"#FFCC00"');
  });

  it("a member's VIP shows on every UserSummary while active; gone once it ends", async () => {
    const member = await p.signup();
    const fan = await p.signup();
    const memberName = await usernameOf(member);
    const fanName = await usernameOf(fan);
    await ctx.prisma.$transaction((tx) => creditIn(tx, member.id, 2_000_000n, 'ADMIN_GRANT', randomUUID()));
    const buy = await ctx.http
      .post('/api/v1/me/vip/purchases')
      .set(auth(member))
      .set('Idempotency-Key', randomUUID())
      .send({ tierId: VIP1, priceCoins: 1_000_000 });
    expect(buy.status, JSON.stringify(buy.body)).toBe(201);
    // The member follows the fan: the fan's followers list carries the member's summary.
    expect((await ctx.http.put(`/api/v1/users/${fanName}/follow`).set(auth(member))).status).toBeLessThan(
      300,
    );
    const followers = async () => {
      const res = await ctx.http.get(`/api/v1/users/${fanName}/followers`).set(auth(fan));
      expect(res.status).toBe(200);
      expectContract(res, 'listUserFollowers');
      return (res.body.data as { username: string; vip?: unknown }[]).find((x) => x.username === memberName);
    };
    expect((await followers())?.vip).toEqual({ tier: 'VIP_1', rank: 1, color: '#2E8B3D' });
    const profile = await ctx.http.get(`/api/v1/users/${memberName}`).set(auth(fan));
    expect(profile.status).toBe(200);
    expectContract(profile, 'getPublicProfile');
    expect(profile.body.vip).toEqual({ tier: 'VIP_1', rank: 1, color: '#2E8B3D' });
    await withMigrationClient((db) =>
      db.vipMembership.update({
        where: { userId: member.id },
        data: { startedAt: new Date(Date.now() - 40 * DAY), expiresAt: new Date(Date.now() - 1000) },
      }),
    );
    expect((await followers())?.vip).toBeUndefined();
  });
});
