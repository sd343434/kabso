/**
 * D374 (owner 2026-11-11: every VIP tier gets the perks the admin picks in the panel, with art where needed; contract
 * v1.129-social, CONVENTIONS §10.166): the perk catalogue to the panel, typed values per tier perk (checked, audited),
 * unknown / retired codes refused, more than 20 perks a tier, the MP4 art upload and a tier's effective perks
 * (inherited) to the app. End to end against PostgreSQL + Redis with the API as the DML-only runtime role.
 */
import { afterAll, beforeAll, describe, expect, it, vi } from 'vitest';
import { addGiftIn } from '../src/modules/gifts/gift-catalogue.js';
import { OBJECT_STORAGE } from '../src/modules/media/object-storage.js';
import { VIP_PERK_CATALOGUE } from '../src/modules/vip/vip-catalogue.js';
import { panel, type Admin, type Person } from './helpers/admin-panel.js';
import { MemoryObjectStorage } from './helpers/memory-storage.js';
import { mp4 } from './helpers/mp4.js';
import { expectContract } from './helpers/openapi.js';
import { createTestApp, withMigrationClient, type TestContext } from './helpers/test-app.js';

const ADMIN_KEY = 'admin-totp-test-key-0123456789-abcdefghijklmnop';
const BASE = 'https://media.example.test';
const VIP1 = '01a25200-0000-7000-8000-000000000001';

interface PerkOut {
  code: string;
  available: boolean;
  amount: number | null;
  value: unknown;
  video: string | null;
  category: string | null;
  fromTier?: string;
}

describe('D374 VIP perk catalogue', { timeout: 180_000 }, () => {
  let ctx: TestContext;
  const p = panel(() => ctx);
  let owner: Admin;

  const auth = (u: Person) => ({ Authorization: `Bearer ${u.token}` });
  const patchTier = (id: string, body: Record<string, unknown>) =>
    p.send(owner, 'patch', `/admin/vip/tiers/${id}`, { reason: 'owner D374', ...body });

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
    await ctx.prisma.$transaction((tx) =>
      addGiftIn(tx, 'd374_castle', {
        category: 'POPULAR',
        nameAr: 'قلعة',
        nameEn: 'Castle',
        priceCoins: 50_000,
        assetKey: 'gift_d374_castle', // gitleaks:allow (an asset name)
        animationKey: null,
        sortOrder: 0,
        badge: 'NONE',
        tagCode: null,
        tagNameAr: null,
        tagNameEn: null,
      }),
    );
  });
  afterAll(async () => {
    await ctx?.close();
    vi.useRealTimers();
  });

  it('the panel lists the catalogue (codes, titles, categories, value schemas, built), the limits and 64 perks', async () => {
    const list = await p.send(owner, 'get', '/admin/vip/tiers');
    expect(list.status).toBe(200);
    expectContract(list, 'listAdminVipTiers');
    const catalogue = list.body.catalogue as {
      code: string;
      built: boolean;
      category: string;
      value: { kind: string; options?: string[] };
      art: { kinds: string[] } | null;
    }[];
    expect(catalogue.map((e) => e.code)).toEqual(VIP_PERK_CATALOGUE.map((e) => e.code));
    expect(catalogue.some((e) => e.code === 'DAILY_COINS')).toBe(false);
    expect(list.body.maxPerks).toBe(64);
    expect(list.body.artLimits.MP4).toEqual({ maxBytes: 8 * 1024 * 1024, maxSeconds: 15 });
    const byCode = new Map(catalogue.map((e) => [e.code, e]));
    expect(byCode.get('MIC_WAVE')).toMatchObject({ built: true, category: 'ROOM' });
    // D381 (v1.134-social) built LONGER_VOICE.
    expect(byCode.get('LONGER_VOICE')).toMatchObject({
      built: true,
      value: { kind: 'int', min: 31, max: 600, unit: 'seconds' },
    });
    expect(byCode.get('ANIMATED_COVER')!.art!.kinds).toContain('MP4');
    // VIP_ROOM's options are the tiers that exist now.
    expect(byCode.get('VIP_ROOM')!.value.options).toContain('VIP_1');
    expect(list.body.suggestedPerks).toEqual(VIP_PERK_CATALOGUE.map((e) => e.code));
  });

  it('a tier takes every catalogue perk (> 20) with typed values, saved and audited; values reach the app', async () => {
    const perks = VIP_PERK_CATALOGUE.map((e) => {
      switch (e.code) {
        case 'DAILY_BULLET':
          return { code: e.code, amount: 5 };
        case 'LEVEL_SPEEDUP':
          return { code: e.code, value: 2 };
        case 'LONGER_VOICE':
          return { code: e.code, value: 180 };
        case 'PREMIUM_USERNAME':
          return { code: e.code, value: 'GOLD' };
        case 'STORY_RING':
          return { code: e.code, value: '#FFAA00' };
        case 'EXCLUSIVE_GIFTS':
          return { code: e.code, value: ['d374_castle'] };
        case 'SEAT_EMOJI':
          return { code: e.code, value: [`${BASE}/media/vip/VIP_1/a.png`, `${BASE}/media/vip/VIP_1/b.svga`] };
        case 'PINNED_MESSAGE':
          return { code: e.code, value: { count: 3, seconds: 60 } };
        case 'MONTHLY_ROCKETS':
          return { code: e.code, value: { count: 2, stage: 'STAGE_2' } };
        case 'VIP_ROOM':
          return { code: e.code, value: 'VIP_1' };
        case 'ANIMATED_COVER':
          return { code: e.code, video: `${BASE}/media/vip/VIP_1/cover.mp4` };
        default:
          return { code: e.code };
      }
    });
    expect(perks.length).toBeGreaterThan(20);
    const ok = await patchTier(VIP1, { perks });
    expect(ok.status, JSON.stringify(ok.body)).toBe(200);
    expectContract(ok, 'updateAdminVipTier');
    const saved = new Map((ok.body.perks as (PerkOut & { titleAr: string })[]).map((pk) => [pk.code, pk]));
    expect(saved.size).toBe(VIP_PERK_CATALOGUE.length);
    // Absent titles are the catalogue's.
    expect(saved.get('HIDDEN_VISIT')!.titleAr).toBe('زيارة مخفية');
    expect(saved.get('DAILY_BULLET')).toMatchObject({ amount: 5, value: 5 });
    expect(saved.get('LEVEL_SPEEDUP')).toMatchObject({ amount: 2, value: 2 });
    expect(saved.get('MONTHLY_ROCKETS')!.value).toEqual({ count: 2, stage: 'STAGE_2' });
    expect(saved.get('ANIMATED_COVER')!.video).toBe(`${BASE}/media/vip/VIP_1/cover.mp4`);
    const audit = await withMigrationClient((db) =>
      db.auditLog.findFirst({ where: { action: 'vip.tier.update' }, orderBy: { createdAt: 'desc' } }),
    );
    const meta = JSON.stringify(audit?.metadata);
    expect(meta).toContain('"value":{"count":2,"stage":"STAGE_2"}');
    expect(meta).toContain('d374_castle');

    const u = await p.signup();
    const res = await ctx.http.get('/api/v1/vip/tiers').set(auth(u)).set('Accept-Language', 'en');
    expect(res.status).toBe(200);
    expectContract(res, 'listVipTiers');
    const vip1 = (res.body.data as { code: string; perks: PerkOut[] }[]).find((t) => t.code === 'VIP_1')!;
    const app = new Map(vip1.perks.map((pk) => [pk.code, pk]));
    expect(app.get('LONGER_VOICE')).toMatchObject({ value: 180, available: true, category: 'CHAT' });
    expect(app.get('MIC_WAVE')).toMatchObject({ available: true, value: null });
  });

  it('values and codes are checked: unknown and retired codes, wrong shapes, missing gifts and tiers → 400, nothing saved', async () => {
    const before = await withMigrationClient((db) => db.vipTierPerk.count({ where: { tierId: VIP1 } }));
    const cases: [Record<string, unknown>, { field: string; issue: string }][] = [
      [{ code: 'MADE_UP' }, { field: 'perks.0.code', issue: 'unknown_perk' }],
      [
        { code: 'DAILY_COINS', amount: 100 },
        { field: 'perks.0.code', issue: 'unknown_perk' },
      ],
      [
        { code: 'BADGE', value: 3 },
        { field: 'perks.0.value', issue: 'not_allowed' },
      ],
      [
        { code: 'LONGER_VOICE', value: 5 },
        { field: 'perks.0.value', issue: 'out_of_range' },
      ],
      [
        { code: 'PREMIUM_USERNAME', value: 'DIAMOND' },
        { field: 'perks.0.value', issue: 'invalid_value' },
      ],
      [
        { code: 'STORY_RING', value: 'red' },
        { field: 'perks.0.value', issue: 'invalid_format' },
      ],
      [
        { code: 'PINNED_MESSAGE', value: { count: 3 } },
        { field: 'perks.0.value.seconds', issue: 'required' },
      ],
      [
        { code: 'EXCLUSIVE_GIFTS', value: ['no_such_gift'] },
        { field: 'perks.0.value.0', issue: 'not_found' },
      ],
      [
        { code: 'VIP_ROOM', value: 'VIP_77' },
        { field: 'perks.0.value', issue: 'not_found' },
      ],
      [
        { code: 'BADGE', video: `${BASE}/x.mp4` },
        { field: 'perks.0.video', issue: 'not_allowed' },
      ],
      [
        { code: 'DAILY_BULLET', amount: 4, value: 5 },
        { field: 'perks.0.value', issue: 'invalid_value' },
      ],
    ];
    for (const [perk, detail] of cases) {
      const res = await patchTier(VIP1, { perks: [perk] });
      expect(res.status, JSON.stringify(perk)).toBe(400);
      expectContract(res, 'updateAdminVipTier');
      expect(res.body.error.details, JSON.stringify(perk)).toContainEqual(detail);
    }
    const tooMany = await patchTier(VIP1, {
      perks: Array.from({ length: 65 }, () => ({ code: 'BADGE' })),
    });
    expect(tooMany.status).toBe(400);
    const after = await withMigrationClient((db) => db.vipTierPerk.count({ where: { tierId: VIP1 } }));
    expect(after).toBe(before);
  });

  it('the MP4 art upload (kind=video): checked and stored; a non-MP4 refused', async () => {
    const up = (body: Buffer) =>
      ctx.http
        .post('/api/v1/admin/vip/uploads?kind=video&tier=VIP_1')
        .set('Cookie', owner.cookie)
        .set('X-CSRF-Token', owner.csrf)
        .set('Content-Type', 'application/octet-stream')
        .send(body);
    const ok = await up(mp4({ durationMs: 5_000, width: 1080, height: 720 }));
    expect(ok.status, JSON.stringify(ok.body)).toBe(201);
    expectContract(ok, 'uploadAdminVipArt');
    expect(ok.body).toMatchObject({ kind: 'video', contentType: 'video/mp4', width: 1080, height: 720 });
    expect(ok.body.url).toMatch(new RegExp(`^${BASE}/media/vip/VIP_1/[0-9a-f]{32}\\.mp4$`));
    const tooLong = await up(mp4({ durationMs: 30_000 }));
    expect(tooLong.status).toBe(409);
    const notMp4 = await up(Buffer.from('not a video at all'));
    expect(notMp4.status).toBe(409);
  });

  it("the app gets each tier's effective perks: its own and the lower tiers' (on sale or not), `fromTier` on inherited ones", async () => {
    // VIP_1 (rank 1) holds a few perks; VIP_2 (rank 2) only two of its own, one overriding VIP_1's value.
    expect(
      (
        await patchTier(VIP1, {
          perks: [
            { code: 'BADGE' },
            { code: 'DAILY_BULLET', value: 3 },
            { code: 'SEAT_RESERVE', value: 5 },
            { code: 'HIDDEN_VISIT', enabled: false },
          ],
        })
      ).status,
    ).toBe(200);
    const vip2 = await p.send(owner, 'post', '/admin/vip/tiers', {
      code: 'VIP_2',
      nameAr: 'في آي بي 2',
      nameEn: 'VIP 2',
      color: '#3366CC',
      priceCoins: 2_000_000,
      durationDays: 30,
      enabled: true,
      // A tier may name itself for VIP_ROOM while being created.
      perks: [
        { code: 'DAILY_BULLET', value: 10 },
        { code: 'LONGER_VOICE', value: 240 },
        { code: 'VIP_ROOM', value: 'VIP_2' },
      ],
      reason: 'owner D374',
    });
    expect(vip2.status, JSON.stringify(vip2.body)).toBe(201);
    // VIP_1 off sale: VIP_2 still inherits its perks.
    expect((await p.send(owner, 'post', `/admin/vip/tiers/${VIP1}/disable`, { reason: 'D374' })).status).toBe(
      200,
    );

    const u = await p.signup();
    const res = await ctx.http.get('/api/v1/vip/tiers').set(auth(u)).set('Accept-Language', 'ar');
    expect(res.status).toBe(200);
    expectContract(res, 'listVipTiers');
    const tiers = res.body.data as { code: string; perks: PerkOut[]; effectivePerks: PerkOut[] }[];
    expect(tiers.map((t) => t.code)).toEqual(['VIP_2']);
    const t2 = tiers[0]!;
    expect(t2.perks.map((pk) => pk.code)).toEqual(['DAILY_BULLET', 'LONGER_VOICE', 'VIP_ROOM']);
    // In the catalogue's order; the disabled HIDDEN_VISIT is not passed up; DAILY_BULLET is VIP_2's own (10).
    expect(t2.effectivePerks.map((pk) => [pk.code, pk.fromTier ?? null, pk.value])).toEqual([
      ['BADGE', 'VIP_1', null],
      ['DAILY_BULLET', null, 10],
      ['LONGER_VOICE', null, 240],
      ['SEAT_RESERVE', 'VIP_1', 5],
      ['VIP_ROOM', null, 'VIP_2'],
    ]);
    expect(t2.effectivePerks.find((pk) => pk.code === 'BADGE')!.available).toBe(true);
    expect(t2.effectivePerks.find((pk) => pk.code === 'SEAT_RESERVE')!.available).toBe(false);
    expect((await p.send(owner, 'post', `/admin/vip/tiers/${VIP1}/enable`, { reason: 'D374' })).status).toBe(
      200,
    );
  });
});
