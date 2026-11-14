/**
 * D338 (owner 2026-11-09: «أريد زر لإزالتهم وليس فقط إيقافهم»; contract v1.103-social, CONVENTIONS §10.131): «حذف» of a
 * gift in the panel and `gift-admin delete`. A gift nothing ever used is deleted for real (row and unused files); a
 * used one — sent, held in a bag, in a wish list, an event — is archived: out of the app's catalogue and the bag's send
 * choices, out of the panel's normal list and the event picker, never sent again, while history (sends, earnings)
 * keeps its name. «استعادة» brings it back. OWNER only (catalog.manage), CSRF, audited.
 */
import { execFile } from 'node:child_process';
import { randomUUID } from 'node:crypto';
import { promisify } from 'node:util';
import sharp from 'sharp';
import { afterAll, beforeAll, describe, expect, it, vi } from 'vitest';
import { Clock } from '../src/common/time/clock.js';
import { addGiftIn, grantStockIn, type GiftFields } from '../src/modules/gifts/gift-catalogue.js';
import { GiftFinishService } from '../src/modules/gifts/gift-finish.service.js';
import { LIVE_MEDIA_PROVIDER } from '../src/modules/live/media/live-media.provider.js';
import { OBJECT_STORAGE } from '../src/modules/media/object-storage.js';
import { creditIn } from '../src/modules/wallet/wallet-ledger.js';
import { panel, type Admin } from './helpers/admin-panel.js';
import { MemoryLiveMedia } from './helpers/memory-live-media.js';
import { MemoryObjectStorage } from './helpers/memory-storage.js';
import { expectContract } from './helpers/openapi.js';
import { createTestApp, registerVerified, type TestContext } from './helpers/test-app.js';

class RealClock extends Clock {
  now(): Date {
    return new Date();
  }
}

interface TestUser {
  id: string;
  username: string;
  token: string;
}

interface ListedGift {
  code: string;
  enabled: boolean;
  archivedAt: string | null;
  inUse: boolean;
  holders: number;
  pieces: number;
}

const run = promisify(execFile);
const cli = (args: string[]) =>
  run('node', ['--import', 'tsx', 'src/cli/gift-admin.ts', ...args], {
    env: { ...process.env, DOTENV_CONFIG_QUIET: 'true' },
  });

const png = (w: number, h: number) =>
  sharp({ create: { width: w, height: h, channels: 4, background: { r: 200, g: 40, b: 90, alpha: 1 } } })
    .png()
    .toBuffer();

describe('D338 «حذف» a gift: deleted when never used, archived otherwise', { timeout: 600_000 }, () => {
  const media = new MemoryLiveMedia();
  const storage = new MemoryObjectStorage();
  let ctx: TestContext;
  const p = panel(() => ctx);

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
  const gift = (code: string, fields: Partial<GiftFields> = {}) =>
    ctx.prisma.$transaction((tx) =>
      addGiftIn(tx, code, {
        category: 'POPULAR',
        nameAr: `هدية ${code}`,
        nameEn: `Gift ${code}`,
        priceCoins: 100,
        assetKey: `gift_${code}`,
        animationKey: null,
        sortOrder: 0,
        badge: 'NONE',
        tagCode: null,
        tagNameAr: null,
        tagNameEn: null,
        ...fields,
      }),
    );
  const goLive = async (host: TestUser) => {
    await ctx.prisma.liveHost.upsert({
      where: { userId: host.id },
      create: { userId: host.id, source: 'ADMIN' },
      update: {},
    });
    const res = await ctx.http
      .post('/api/v1/live/rooms')
      .set(auth(host))
      .send({ title: 'D338', mode: 'AUDIO', seatCount: 10 });
    expect(res.status, JSON.stringify(res.body)).toBe(201);
    return res.body.id as string;
  };
  const enter = async (roomId: string, u: TestUser) => {
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
  const send = (
    roomId: string,
    from: TestUser,
    to: TestUser,
    giftCode: string,
    source: 'COINS' | 'BAG' = 'COINS',
  ) =>
    ctx.http
      .post(`/api/v1/live/rooms/${roomId}/gifts`)
      .set(auth(from))
      .send({ giftCode, quantity: 1, recipients: [to.username], source, clientId: randomUUID() });
  const listed = async (): Promise<ListedGift[]> => {
    const res = await p.send(owner, 'get', '/admin/gifts');
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    expectContract(res, 'listAdminGifts');
    return res.body.data as ListedGift[];
  };
  const row = async (code: string) => (await listed()).find((g) => g.code === code);
  const catalogue = async (u: TestUser) => {
    const res = await ctx.http.get('/api/v1/gifts/catalogue').set(auth(u));
    expect(res.status).toBe(200);
    return (res.body.data as { code: string }[]).map((g) => g.code);
  };
  const bag = async (u: TestUser) => {
    const res = await ctx.http.get('/api/v1/me/gifts/bag').set(auth(u));
    expect(res.status).toBe(200);
    return (res.body.data as { code: string; quantity: number }[]).map((g) => g.code);
  };
  const audits = (code: string, action: string) =>
    ctx.prisma.auditLog.findMany({ where: { targetId: code, action }, orderBy: { createdAt: 'asc' } });

  let owner: Admin;
  let support: Admin;
  let host: TestUser;
  let fan: TestUser;
  let roomId: string;

  beforeAll(async () => {
    vi.useFakeTimers({ toFake: ['Date'], now: Date.now() });
    ctx = await createTestApp(
      {
        LIVE_HOSTING_ENABLED: 'true',
        LIVE_HEARTBEAT_STALE_SECONDS: '3600',
        LIVE_GIFT_QUANTITIES: '1,10,100',
        ADMIN_TOTP_KEY: 'admin-totp-test-key-0123456789-abcdefghijklmnop',
        ADMIN_SESSION_IDLE_SECONDS: '3600',
        RATE_LIMIT_ADMIN_LOGIN_IP: '10000/900',
        RATE_LIMIT_ADMIN_IP: '100000/900',
        MEDIA_PUBLIC_BASE_URL: 'https://media.example.test',
      },
      [
        { token: LIVE_MEDIA_PROVIDER, value: media },
        { token: Clock, value: new RealClock() },
        { token: OBJECT_STORAGE, value: storage },
      ],
    );
    owner = await p.makeAdmin(['OWNER']);
    support = await p.makeAdmin(['SUPPORT']);
    host = await signup();
    fan = await signup();
    await ctx.prisma.$transaction((tx) => creditIn(tx, fan.id, 1_000_000n, 'ADMIN_GRANT', randomUUID()));
    roomId = await goLive(host);
    await enter(roomId, fan);
  });
  afterAll(async () => {
    await ctx?.close();
    vi.useRealTimers();
  });

  it('a gift nothing ever used is deleted for real, with its uploaded files; audited gift.delete', async () => {
    const image = await ctx.http
      .post('/api/v1/admin/gift-uploads?kind=image&code=d338_fresh')
      .set('Cookie', owner.cookie)
      .set('X-CSRF-Token', owner.csrf)
      .set('Content-Type', 'application/octet-stream')
      .send(await png(256, 256));
    expect(image.status, JSON.stringify(image.body)).toBe(201);
    const key = image.body.key as string;
    const created = await p.send(owner, 'post', '/admin/gifts', {
      code: 'd338_fresh',
      category: 'POPULAR',
      nameAr: 'جديدة',
      nameEn: 'Fresh',
      priceCoins: 500,
      imageObjectKey: key,
      reason: 'new',
    });
    expect(created.status, JSON.stringify(created.body)).toBe(201);
    expect(storage.objects.has(key)).toBe(true);
    expect(await row('d338_fresh')).toMatchObject({
      archivedAt: null,
      inUse: false,
      holders: 0,
      enabled: true,
    });

    const del = await p.send(owner, 'delete', '/admin/gifts/d338_fresh', { reason: 'made by mistake' });
    expect(del.status, JSON.stringify(del.body)).toBe(200);
    expectContract(del, 'deleteAdminGift');
    expect(del.body).toMatchObject({ result: 'DELETED', code: 'd338_fresh', filesDeleted: 1 });
    expect(await ctx.prisma.gift.findUnique({ where: { code: 'd338_fresh' } })).toBeNull();
    expect(storage.objects.has(key)).toBe(false);
    expect(await row('d338_fresh')).toBeUndefined();
    const [audit] = await audits('d338_fresh', 'gift.delete');
    expect(audit?.metadata).toMatchObject({
      case: 'deleted',
      reason: 'made by mistake',
      via: 'panel',
      before: { nameEn: 'Fresh', priceCoins: 500, imageObjectKey: key },
    });
    expect(audit?.actorUserId).toBe(owner.id);

    // Gone: deleting again is 404; the code can be used again.
    const again = await p.send(owner, 'delete', '/admin/gifts/d338_fresh', { reason: 'again' });
    expect(again.status).toBe(404);
    expect(await gift('d338_fresh')).toBe(true);
  });

  it('a sent gift is archived: hidden from the catalogue and the lists, never sent again, history keeps its name', async () => {
    await gift('d338_sent', { nameEn: 'Rose of history', priceCoins: 1000 });
    const sent = await send(roomId, fan, host, 'd338_sent');
    expect([200, 201], JSON.stringify(sent.body)).toContain(sent.status);
    expect(await catalogue(fan)).toContain('d338_sent');
    expect(await row('d338_sent')).toMatchObject({ inUse: true, archivedAt: null });

    const del = await p.send(owner, 'delete', '/admin/gifts/d338_sent', { reason: 'retired' });
    expect(del.status, JSON.stringify(del.body)).toBe(200);
    expectContract(del, 'deleteAdminGift');
    expect(del.body).toMatchObject({ result: 'ARCHIVED', code: 'd338_sent', filesDeleted: 0 });
    expect(del.body.usage).toMatchObject({ sends: 1 });

    const stored = await ctx.prisma.gift.findUniqueOrThrow({ where: { code: 'd338_sent' } });
    expect(stored.enabled).toBe(false);
    expect(stored.archivedAt).not.toBeNull();
    expect(await ctx.prisma.liveGift.count({ where: { giftCode: 'd338_sent' } })).toBe(1);
    expect(await catalogue(fan)).not.toContain('d338_sent');
    // The panel lists it with its archive time (the «المحذوفة» filter shows it; the normal list hides it).
    expect((await row('d338_sent'))?.archivedAt).toBe(stored.archivedAt!.toISOString());
    const again = await send(roomId, fan, host, 'd338_sent');
    expect(again.status).toBe(409);
    expect(again.body.error.code).toBe('GIFT_UNAVAILABLE');

    // History: the host's earnings still name the gift.
    const earnings = await ctx.http.get('/api/v1/wallet/me/earnings/history').set(auth(host));
    expect(earnings.status, JSON.stringify(earnings.body)).toBe(200);
    expect(earnings.body.data).toEqual(
      expect.arrayContaining([
        expect.objectContaining({ giftCode: 'd338_sent', giftName: 'Rose of history' }),
      ]),
    );

    const [audit] = await audits('d338_sent', 'gift.archive');
    expect(audit?.metadata).toMatchObject({
      case: 'archived',
      wasEnabled: true,
      reason: 'retired',
      via: 'panel',
    });
    // Archived already: 200 ARCHIVED, nothing written.
    const twice = await p.send(owner, 'delete', '/admin/gifts/d338_sent', { reason: 'again' });
    expect(twice.body.result).toBe('ARCHIVED');
    expect(await audits('d338_sent', 'gift.archive')).toHaveLength(1);
  });

  it('enable refuses an archived gift; «استعادة» brings it back (switched on, sendable); audited gift.restore', async () => {
    const enable = await p.send(owner, 'post', '/admin/gifts/d338_sent/enable', { reason: 'back?' });
    expect(enable.status).toBe(409);
    expect(enable.body.error.code).toBe('ADMIN_ACTION_REFUSED');

    const back = await p.send(owner, 'post', '/admin/gifts/d338_sent/restore', {
      reason: 'owner changed his mind',
    });
    expect(back.status, JSON.stringify(back.body)).toBe(200);
    expectContract(back, 'restoreAdminGift');
    expect(back.body).toMatchObject({ code: 'd338_sent', restored: true, changed: true });
    const stored = await ctx.prisma.gift.findUniqueOrThrow({ where: { code: 'd338_sent' } });
    expect(stored).toMatchObject({ enabled: true, archivedAt: null });
    expect(await catalogue(fan)).toContain('d338_sent');
    const sent = await send(roomId, fan, host, 'd338_sent');
    expect([200, 201], JSON.stringify(sent.body)).toContain(sent.status);
    const [audit] = await audits('d338_sent', 'gift.restore');
    expect(audit?.metadata).toMatchObject({ reason: 'owner changed his mind', via: 'panel' });

    const twice = await p.send(owner, 'post', '/admin/gifts/d338_sent/restore', { reason: 'again' });
    expect(twice.body).toMatchObject({ restored: true, changed: false });
  });

  it('owner «مخفية الا ان تنتهي من حقيبة المستخدمين ثم تحذف»: bag pieces of an archived gift stay listed and sendable until used up; never bought; restore while archived', async () => {
    await gift('d338_bagged');
    await ctx.prisma.$transaction((tx) => grantStockIn(tx, fan.id, 'd338_bagged', 3));
    expect(await bag(fan)).toContain('d338_bagged');
    expect(await row('d338_bagged')).toMatchObject({ inUse: true, holders: 1, pieces: 3 });

    const del = await p.send(owner, 'delete', '/admin/gifts/d338_bagged', { reason: 'retired' });
    expect(del.body).toMatchObject({ result: 'ARCHIVED' });
    expect(del.body.usage).toMatchObject({ sends: 0, bagRows: 1, holders: 1, pieces: 3 });
    // Gone from the catalogue (never bought again), still in the holder's bag.
    expect(await catalogue(fan)).not.toContain('d338_bagged');
    expect(await bag(fan)).toContain('d338_bagged');
    const bought = await send(roomId, fan, host, 'd338_bagged', 'COINS');
    expect(bought.status).toBe(409);
    expect(bought.body.error.code).toBe('GIFT_UNAVAILABLE');
    const fromBag = await send(roomId, fan, host, 'd338_bagged', 'BAG');
    expect([200, 201], JSON.stringify(fromBag.body)).toContain(fromBag.status);
    expect(await row('d338_bagged')).toMatchObject({ holders: 1, pieces: 2 });

    // «استعادة» still works while pieces are out: back in the catalogue, pieces untouched.
    const back = await p.send(owner, 'post', '/admin/gifts/d338_bagged/restore', { reason: 'back' });
    expect(back.body).toMatchObject({ restored: true, changed: true });
    expect(await catalogue(fan)).toContain('d338_bagged');
    expect(await row('d338_bagged')).toMatchObject({ archivedAt: null, pieces: 2 });
  });

  it('the last bag piece sent finishes the archived gift: kept archived for history only (it has sends), gone from the bag', async () => {
    await gift('d338_last');
    await ctx.prisma.$transaction((tx) => grantStockIn(tx, fan.id, 'd338_last', 1));
    const del = await p.send(owner, 'delete', '/admin/gifts/d338_last', { reason: 'retired' });
    expect(del.body).toMatchObject({ result: 'ARCHIVED' });
    const last = await send(roomId, fan, host, 'd338_last', 'BAG');
    expect([200, 201], JSON.stringify(last.body)).toContain(last.status);
    expect(await bag(fan)).not.toContain('d338_last');
    const stored = await ctx.prisma.gift.findUnique({ where: { code: 'd338_last' } });
    expect(stored?.archivedAt).not.toBeNull();
    expect(await row('d338_last')).toMatchObject({ holders: 0, pieces: 0, inUse: true });
    const again = await send(roomId, fan, host, 'd338_last', 'BAG');
    expect(again.status).toBe(409);
    // History: the send is there and the host's earnings name it.
    expect(await ctx.prisma.liveGift.count({ where: { giftCode: 'd338_last' } })).toBe(1);
    expect(await audits('d338_last', 'gift.delete')).toHaveLength(0);
  });

  it('pieces gone without a send (an emptied bag): the sweeper deletes the archived gift for real, with its file', async () => {
    const image = await ctx.http
      .post('/api/v1/admin/gift-uploads?kind=image&code=d338_swept')
      .set('Cookie', owner.cookie)
      .set('X-CSRF-Token', owner.csrf)
      .set('Content-Type', 'application/octet-stream')
      .send(await png(256, 256));
    expect(image.status, JSON.stringify(image.body)).toBe(201);
    const key = image.body.key as string;
    const created = await p.send(owner, 'post', '/admin/gifts', {
      code: 'd338_swept',
      category: 'POPULAR',
      nameAr: 'مكنوسة',
      nameEn: 'Swept',
      priceCoins: 300,
      imageObjectKey: key,
      reason: 'new',
    });
    expect(created.status, JSON.stringify(created.body)).toBe(201);
    await ctx.prisma.$transaction((tx) => grantStockIn(tx, host.id, 'd338_swept', 2));
    const del = await p.send(owner, 'delete', '/admin/gifts/d338_swept', { reason: 'retired' });
    expect(del.body).toMatchObject({ result: 'ARCHIVED' });
    expect(del.body.usage).toMatchObject({ sends: 0, holders: 1, pieces: 2 });
    const finisher = ctx.app.get(GiftFinishService);
    // Pieces still held: nothing happens.
    expect(await finisher.finish('d338_swept')).toMatchObject({ result: 'HELD' });
    // The pieces leave without a send (as with a deleted account's bag).
    await ctx.prisma.userGiftStock.update({
      where: { userId_giftCode: { userId: host.id, giftCode: 'd338_swept' } },
      data: { quantity: 0 },
    });
    const swept = await finisher.sweep();
    expect(swept.deleted).toBeGreaterThanOrEqual(1);
    expect(await ctx.prisma.gift.findUnique({ where: { code: 'd338_swept' } })).toBeNull();
    expect(await ctx.prisma.userGiftStock.count({ where: { giftCode: 'd338_swept' } })).toBe(0);
    expect(storage.objects.has(key)).toBe(false);
    const [audit] = await audits('d338_swept', 'gift.delete');
    expect(audit?.metadata).toMatchObject({ case: 'finished', via: 'system' });
    // A gift with history stays: d338_last is still archived after a sweep.
    expect((await ctx.prisma.gift.findUnique({ where: { code: 'd338_last' } }))?.archivedAt).not.toBeNull();
  });

  it('a reference by code only (a wish list) is a use too: archived, not deleted', async () => {
    await gift('d338_wished');
    await ctx.prisma.liveRoom.update({ where: { id: roomId }, data: { wishGifts: ['d338_wished'] } });
    const del = await p.send(owner, 'delete', '/admin/gifts/d338_wished', { reason: 'x' });
    expect(del.body).toMatchObject({ result: 'ARCHIVED' });
    expect(del.body.usage).toMatchObject({ wishes: 1, sends: 0, bagRows: 0 });
    expect(await ctx.prisma.gift.findUnique({ where: { code: 'd338_wished' } })).not.toBeNull();
  });

  it('the event picker leaves archived gifts out', async () => {
    const res = await p.send(owner, 'get', '/admin/event-options');
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    const codes = (res.body.gifts as { code: string }[]).map((g) => g.code);
    expect(codes).toContain('d338_sent');
    expect(codes).not.toContain('d338_wished');
  });

  it('permissions: OWNER only (catalog.manage); CSRF; unknown gift 404', async () => {
    await gift('d338_guarded');
    const asSupport = await p.send(support, 'delete', '/admin/gifts/d338_guarded', { reason: 'x' });
    expect(asSupport.status).toBe(403);
    const restoreSupport = await p.send(support, 'post', '/admin/gifts/d338_wished/restore', { reason: 'x' });
    expect(restoreSupport.status).toBe(403);
    // SUPPORT still reads the list (catalog.view), with the archived ones.
    const list = await p.send(support, 'get', '/admin/gifts');
    expect(list.status).toBe(200);
    const noCsrf = await ctx.http
      .delete('/api/v1/admin/gifts/d338_guarded')
      .set('Cookie', owner.cookie)
      .send({ reason: 'x' });
    expect(noCsrf.status).toBe(403);
    const noReason = await p.send(owner, 'delete', '/admin/gifts/d338_guarded', {});
    expect(noReason.status).toBe(400);
    const unknown = await p.send(owner, 'delete', '/admin/gifts/d338_nothing', { reason: 'x' });
    expect(unknown.status).toBe(404);
    const unknownRestore = await p.send(owner, 'post', '/admin/gifts/d338_nothing/restore', { reason: 'x' });
    expect(unknownRestore.status).toBe(404);
    expect(await ctx.prisma.gift.findUnique({ where: { code: 'd338_guarded' } })).not.toBeNull();
    expect(await audits('d338_guarded', 'gift.delete')).toHaveLength(0);
  });

  it('CLI parity: gift-admin delete / restore follow the same rule and audit (via cli)', async () => {
    await gift('d338_cli_new');
    const deleted = await cli(['delete', 'd338_cli_new']);
    expect(deleted.stdout).toContain('d338_cli_new: deleted (never used).');
    expect(await ctx.prisma.gift.findUnique({ where: { code: 'd338_cli_new' } })).toBeNull();
    expect((await audits('d338_cli_new', 'gift.delete'))[0]?.metadata).toMatchObject({
      case: 'deleted',
      via: 'cli',
    });

    await gift('d338_cli_used');
    await ctx.prisma.$transaction((tx) => grantStockIn(tx, host.id, 'd338_cli_used', 1));
    const archived = await cli(['delete', 'd338_cli_used']);
    expect(archived.stdout).toContain('d338_cli_used: archived (in use: bagRows=1 holders=1 pieces=1)');
    expect(archived.stdout).toContain('1 piece(s) in 1 bag(s) are sent until they run out');
    expect((await audits('d338_cli_used', 'gift.archive'))[0]?.metadata).toMatchObject({ via: 'cli' });
    const list = await cli(['list']);
    expect(list.stdout).toMatch(/^x POPULAR 0 d338_cli_used /m);
    await expect(cli(['enable', 'd338_cli_used'])).rejects.toMatchObject({
      stderr: expect.stringContaining('restore it first'),
    });
    await expect(cli(['grant', owner.email, 'd338_cli_used', '1'])).rejects.toMatchObject({
      stderr: expect.stringContaining('d338_cli_used is deleted (archived); restore it first.'),
    });
    const restored = await cli(['restore', 'd338_cli_used']);
    expect(restored.stdout).toContain('d338_cli_used: restored and enabled.');
    expect(await ctx.prisma.gift.findUniqueOrThrow({ where: { code: 'd338_cli_used' } })).toMatchObject({
      enabled: true,
      archivedAt: null,
    });
    // `finish`: an archived gift whose pieces ran out without history is deleted (via cli).
    await gift('d338_cli_fin');
    await ctx.prisma.$transaction((tx) => grantStockIn(tx, host.id, 'd338_cli_fin', 1));
    await cli(['delete', 'd338_cli_fin']);
    const held = await cli(['finish', 'd338_cli_fin']);
    expect(held.stdout).toContain('d338_cli_fin: 1 piece(s) still in 1 bag(s).');
    await ctx.prisma.userGiftStock.update({
      where: { userId_giftCode: { userId: host.id, giftCode: 'd338_cli_fin' } },
      data: { quantity: 0 },
    });
    const finished = await cli(['finish']);
    expect(finished.stdout).toContain('d338_cli_fin: finished, deleted (no history).');
    expect((await audits('d338_cli_fin', 'gift.delete')).at(-1)?.metadata).toMatchObject({
      case: 'finished',
      via: 'cli',
    });
    await expect(cli(['delete', 'd338_cli_nothing'])).rejects.toMatchObject({
      stderr: expect.stringContaining('No gift d338_cli_nothing.'),
    });
  });
});
