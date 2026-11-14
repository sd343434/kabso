/**
 * D264 (owner: «عند تفعيل VIP تظهر العناصر في الحقيبة … المدة تنقضي وتعد»; contract v1.65-live, CONVENTIONS §10.97):
 * a VIP member's wearable tier items in the bag — derived from the membership (its start and end), worn by default,
 * taken off and worn again from the bag (`UserVip.off` for everyone), extended by a renewal, the higher tier's on an
 * upgrade, gone when it ends. End to end against PostgreSQL + Redis with the API as the DML-only runtime role.
 */
import { randomUUID } from 'node:crypto';
import { afterAll, beforeAll, describe, expect, it, vi } from 'vitest';
import { BAG_CATALOGUE } from '../src/modules/bag/bag.catalogue.js';
import { creditIn } from '../src/modules/wallet/wallet-ledger.js';
import { panel, type Person } from './helpers/admin-panel.js';
import { expectContract } from './helpers/openapi.js';
import { createTestApp, withMigrationClient, type TestContext } from './helpers/test-app.js';

const DAY = 86_400_000;
const VIP1 = '01a25200-0000-7000-8000-000000000001';
const VIP2 = '01a26400-0000-7000-8000-000000000002';
const WEARABLE = ['PROFILE_CARD', 'AVATAR_FRAME', 'CHAT_BUBBLE', 'ENTRY_BANNER', 'ENTRY_EFFECT', 'MIC_WAVE'];

interface Item {
  code: string;
  category: string;
  name: string;
  source: string;
  equipped: boolean;
  acquiredAt: string;
  expiresAt: string | null;
  transferable: boolean;
  vip?: {
    tier: string;
    tierName: string;
    color: string;
    perk: string;
    animation: string | null;
    still: string | null;
  };
}

describe('D264 VIP items in the bag', { timeout: 180_000 }, () => {
  let ctx: TestContext;
  const p = panel(() => ctx);

  const auth = (u: Person) => ({ Authorization: `Bearer ${u.token}` });
  const usernameOf = async (u: Person) =>
    (await ctx.http.get('/api/v1/me').set(auth(u))).body.username as string;
  const bag = async (u: Person, query = '', lang = 'ar') => {
    const res = await ctx.http.get(`/api/v1/me/bag${query}`).set(auth(u)).set('Accept-Language', lang);
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    expectContract(res, 'getMyBag');
    return res.body.data as Item[];
  };
  const vipItems = async (u: Person) => (await bag(u)).filter((i) => i.source === 'VIP');
  const wear = async (u: Person, category: string, code: string | null) => {
    const res = await ctx.http.put('/api/v1/me/bag/equipped').set(auth(u)).send({ category, code });
    if (res.status === 200) expectContract(res, 'setMyBagEquipped');
    return res;
  };
  const buy = async (u: Person, tierId: string, priceCoins: number) => {
    const res = await ctx.http
      .post('/api/v1/me/vip/purchases')
      .set(auth(u))
      .set('Idempotency-Key', randomUUID())
      .send({ tierId, priceCoins });
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    return res.body as { kind: string; membership: { startedAt: string; expiresAt: string } };
  };
  const member = async () => {
    const u = await p.signup();
    await ctx.prisma.$transaction((tx) => creditIn(tx, u.id, 10_000_000n, 'ADMIN_GRANT', randomUUID()));
    return u;
  };

  beforeAll(async () => {
    vi.useFakeTimers({ toFake: ['Date'], now: p.start() });
    ctx = await createTestApp();
    await ctx.prisma.bagItem.createMany({ data: BAG_CATALOGUE.map((i) => ({ ...i })) });
    // A higher tier with its own entry car (its other items inherited from VIP 1).
    await withMigrationClient(async (db) => {
      await db.vipTier.create({
        data: {
          id: VIP2,
          code: 'VIP_2',
          nameAr: 'في آي بي 2',
          nameEn: 'VIP 2',
          sortOrder: 2,
          color: '#1E5AA8',
          priceCoins: 2_000_000n,
          durationDays: 30,
          enabled: true,
          perks: {
            create: [
              {
                code: 'ENTRY_EFFECT',
                titleAr: 'سيارة الدخول',
                titleEn: 'Entry car',
                sortOrder: 0,
                still: 'https://media.example.test/media/vip/VIP_2/car.png',
              },
              { code: 'BADGE', titleAr: 'الشارة', titleEn: 'Badge', sortOrder: 1 },
            ],
          },
        },
      });
    });
  });
  afterAll(async () => {
    await ctx?.close();
    vi.useRealTimers();
  });

  it('a member sees the tier items in the bag, timed by the membership; nobody else does', async () => {
    const plain = await p.signup();
    expect(await vipItems(plain)).toEqual([]);

    const u = await member();
    const bought = await buy(u, VIP1, 1_000_000);
    const items = await vipItems(u);
    expect(items.map((i) => i.category)).toEqual(WEARABLE);
    for (const i of items) {
      expect(i.code).toBe(`vip:${i.vip!.perk}`);
      expect(i.equipped, i.code).toBe(true);
      expect(i.transferable).toBe(false);
      expect(i.acquiredAt).toBe(bought.membership.startedAt);
      expect(i.expiresAt).toBe(bought.membership.expiresAt);
      expect(i.vip).toMatchObject({ tier: 'VIP_1', tierName: 'في آي بي 1', color: '#2E8B3D' });
    }
    // The VIP card shares PROFILE_CARD with the bag's cards; the badge and the name colour are not bag items.
    expect(items.find((i) => i.category === 'PROFILE_CARD')!.vip!.perk).toBe('PROFILE_CARD');
    expect(items.find((i) => i.code === 'vip:CHAT_BUBBLE')!.name).toBe('إطار الرسائل');
    expect((await bag(u, '', 'en')).find((i) => i.code === 'vip:CHAT_BUBBLE')!.name).toBe('Message frame');
    // One worn item per kind: the VIP card replaced the free card (still owned, first after the VIP one).
    const all = await bag(u);
    expect(all.slice(0, 2).map((i) => [i.code, i.equipped])).toEqual([
      ['vip:PROFILE_CARD', true],
      ['bunny_royal', false],
    ]);
    // One category; the catalogue has none of them.
    expect((await bag(u, '?category=MIC_WAVE')).map((i) => i.code)).toEqual(['vip:MIC_WAVE']);
    const cat = await ctx.http.get('/api/v1/bag/catalogue?category=CHAT_BUBBLE').set(auth(u));
    expect(cat.status).toBe(200);
    expectContract(cat, 'listBagCatalogue');
    expect(cat.body.data).toEqual([]);

    // A renewal moves their end with the membership's.
    const renewed = await buy(u, VIP1, 850_000);
    expect(renewed.kind).toBe('RENEW');
    expect(new Date(renewed.membership.expiresAt).getTime()).toBe(
      new Date(bought.membership.expiresAt).getTime() + 30 * DAY,
    );
    for (const i of await vipItems(u)) expect(i.expiresAt).toBe(renewed.membership.expiresAt);

    // Never sent.
    const fanName = await usernameOf(await p.signup());
    const send = await ctx.http
      .post('/api/v1/me/bag/transfers')
      .set(auth(u))
      .send({ code: 'vip:CHAT_BUBBLE', username: fanName });
    expect(send.status).toBe(409);
    expect(send.body.error.code).toBe('BAG_ITEM_NOT_OWNED');
  });

  it('taken off and worn again from the bag; everyone sees the choice (UserVip.off)', async () => {
    const u = await member();
    await buy(u, VIP1, 1_000_000);
    const fan = await p.signup();
    const name = await usernameOf(u);
    const shown = async () => {
      const res = await ctx.http.get(`/api/v1/users/${name}`).set(auth(fan));
      expect(res.status).toBe(200);
      expectContract(res, 'getPublicProfile');
      return res.body.vip as { tier: string; off?: string[] };
    };
    expect((await shown()).off).toBeUndefined();

    const off = await wear(u, 'CHAT_BUBBLE', null);
    expect(off.status).toBe(200);
    expect(off.body).toEqual({ category: 'CHAT_BUBBLE', equipped: null });
    // Idempotent.
    expect((await wear(u, 'CHAT_BUBBLE', null)).status).toBe(200);
    expect((await wear(u, 'MIC_WAVE', null)).status).toBe(200);
    const items = await vipItems(u);
    expect(items.filter((i) => !i.equipped).map((i) => i.code)).toEqual(['vip:CHAT_BUBBLE', 'vip:MIC_WAVE']);
    // Still listed and still counting down while taken off.
    expect(items).toHaveLength(6);
    expect((await shown()).off).toEqual(['CHAT_BUBBLE', 'MIC_WAVE']);
    // The followers list (a UserSummary) carries it too.
    expect(
      (await ctx.http.put(`/api/v1/users/${await usernameOf(fan)}/follow`).set(auth(u))).status,
    ).toBeLessThan(300);
    const followers = await ctx.http.get(`/api/v1/users/${await usernameOf(fan)}/followers`).set(auth(fan));
    expectContract(followers, 'listUserFollowers');
    expect(
      (followers.body.data as { username: string; vip?: { off?: string[] } }[]).find(
        (x) => x.username === name,
      )!.vip!.off,
    ).toEqual(['CHAT_BUBBLE', 'MIC_WAVE']);

    const on = await wear(u, 'CHAT_BUBBLE', 'vip:CHAT_BUBBLE');
    expect(on.status).toBe(200);
    expect(on.body.equipped).toMatchObject({ code: 'vip:CHAT_BUBBLE', name: 'Message frame' });
    expect((await shown()).off).toEqual(['MIC_WAVE']);

    // One card: wearing the bag's card takes the VIP card off (for everyone), and the other way round.
    expect((await wear(u, 'PROFILE_CARD', 'bunny_royal')).body.equipped.code).toBe('bunny_royal');
    let profile = await ctx.http.get(`/api/v1/users/${name}`).set(auth(fan));
    expect(profile.body.profileCard).toEqual({ code: 'bunny_royal', assetKey: 'header_bunny_royal' });
    expect(profile.body.vip.off).toEqual(['PROFILE_CARD', 'MIC_WAVE']);
    expect((await vipItems(u)).find((i) => i.code === 'vip:PROFILE_CARD')!.equipped).toBe(false);
    expect((await wear(u, 'PROFILE_CARD', 'vip:PROFILE_CARD')).body.equipped.code).toBe('vip:PROFILE_CARD');
    profile = await ctx.http.get(`/api/v1/users/${name}`).set(auth(fan));
    expect(profile.body.profileCard).toBeNull();
    expect(profile.body.vip.off).toEqual(['MIC_WAVE']);
    expect((await bag(u, '?category=PROFILE_CARD')).map((i) => [i.code, i.equipped])).toEqual([
      ['vip:PROFILE_CARD', true],
      ['bunny_royal', false],
    ]);

    // A VIP code in the wrong category, an unknown perk, the badge: not owned.
    for (const [category, code] of [
      ['MIC_WAVE', 'vip:CHAT_BUBBLE'],
      ['AVATAR_FRAME', 'vip:PROFILE_CARD'],
      ['CHAT_BUBBLE', 'vip:BADGE'],
    ] as const) {
      const res = await wear(u, category, code);
      expect(res.status, `${category} ${code}`).toBe(409);
      expect(res.body.error.code).toBe('BAG_ITEM_NOT_OWNED');
    }
    // An unknown category stays 400.
    expect((await wear(u, 'BADGE', null)).status).toBe(400);
  });

  it('one frame is worn: VIP starts in place of the bag frame; each takes the other off; null takes both off', async () => {
    const u = await member();
    // A bag frame worn before VIP.
    await withMigrationClient((db) =>
      db.userBagItem.create({
        data: {
          userId: u.id,
          itemCode: 'support_frame_01',
          category: 'AVATAR_FRAME',
          source: 'ADMIN',
          equipped: true,
        },
      }),
    );
    await buy(u, VIP1, 1_000_000);
    const frames = async () =>
      Object.fromEntries((await bag(u, '?category=AVATAR_FRAME')).map((i) => [i.code, i.equipped]));
    expect(await frames()).toEqual({ 'vip:AVATAR_FRAME': true, support_frame_01: false });

    expect((await wear(u, 'AVATAR_FRAME', 'support_frame_01')).body.equipped.code).toBe('support_frame_01');
    expect(await frames()).toEqual({ 'vip:AVATAR_FRAME': false, support_frame_01: true });
    // A renewal keeps the member's choice.
    await buy(u, VIP1, 850_000);
    expect(await frames()).toEqual({ 'vip:AVATAR_FRAME': false, support_frame_01: true });

    const vip = await wear(u, 'AVATAR_FRAME', 'vip:AVATAR_FRAME');
    expect(vip.body.equipped.code).toBe('vip:AVATAR_FRAME');
    expect(await frames()).toEqual({ 'vip:AVATAR_FRAME': true, support_frame_01: false });

    const none = await wear(u, 'AVATAR_FRAME', null);
    expect(none.body.equipped).toBeNull();
    expect(await frames()).toEqual({ 'vip:AVATAR_FRAME': false, support_frame_01: false });
    const m = await withMigrationClient((db) =>
      db.vipMembership.findUniqueOrThrow({ where: { userId: u.id } }),
    );
    expect(m.offPerks).toEqual(['AVATAR_FRAME']);
  });

  it("an upgrade shows the higher tier's items; the end removes them; a new membership wears them all", async () => {
    const u = await member();
    await buy(u, VIP1, 1_000_000);
    expect((await wear(u, 'ENTRY_BANNER', null)).status).toBe(200);
    const up = await buy(u, VIP2, 2_000_000);
    expect(up.kind).toBe('UPGRADE');
    const items = await vipItems(u);
    expect(items.map((i) => i.category)).toEqual(WEARABLE);
    for (const i of items) {
      expect(i.vip!.tier).toBe('VIP_2');
      expect(i.acquiredAt).toBe(up.membership.startedAt);
      expect(i.expiresAt).toBe(up.membership.expiresAt);
    }
    // VIP 2's own car; the rest inherited from VIP 1. The member's choice is kept.
    const car = items.find((i) => i.code === 'vip:ENTRY_EFFECT')!;
    expect(car.name).toBe('سيارة الدخول');
    expect(car.vip!.still).toBe('https://media.example.test/media/vip/VIP_2/car.png');
    expect(items.find((i) => i.code === 'vip:ENTRY_BANNER')!.equipped).toBe(false);

    // It ends: the items leave the bag, and cannot be worn.
    await withMigrationClient((db) =>
      db.vipMembership.update({
        where: { userId: u.id },
        data: { startedAt: new Date(Date.now() - 40 * DAY), expiresAt: new Date(Date.now() - 1000) },
      }),
    );
    expect(await vipItems(u)).toEqual([]);
    // The slots are simply empty (the free card replaced at the start is not put back).
    expect((await bag(u)).filter((i) => i.equipped)).toEqual([]);
    const late = await wear(u, 'ENTRY_BANNER', 'vip:ENTRY_BANNER');
    expect(late.status).toBe(409);
    expect(late.body.error.code).toBe('BAG_ITEM_NOT_OWNED');
    // Taking off with no membership is harmless.
    expect((await wear(u, 'MIC_WAVE', null)).body).toEqual({ category: 'MIC_WAVE', equipped: null });

    // Bought again after the end (well past the renewal grace): every item worn again.
    await withMigrationClient((db) =>
      db.vipMembership.update({
        where: { userId: u.id },
        data: { startedAt: new Date(Date.now() - 40 * DAY), expiresAt: new Date(Date.now() - 10 * DAY) },
      }),
    );
    const again = await buy(u, VIP1, 1_000_000);
    expect(again.kind).toBe('NEW');
    const fresh = await vipItems(u);
    expect(fresh.every((i) => i.equipped && i.vip!.tier === 'VIP_1')).toBe(true);
    expect(fresh[0]!.acquiredAt).toBe(again.membership.startedAt);
  });
});
